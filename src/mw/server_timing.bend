import Base
import ../net/conn_info.bend as Conn
import ./response_policy.bend as Policy
import ../http/stream_types.bend as StreamTypes
import ../app/context.bend as C
import ../app/observability.bend as Obs
import ../app/validate.bend as V
import ../app/store.bend as Store
import ../app/store_actor.bend as StoreActor
import ../http/response.bend as Response
import ../http/bytes.bend as Bytes

# Encode each non-alphanumeric UTF-32 code point as _<decimal>_. Encode the
# underscore too, so distinct names never collide with this escape syntax.
def char_name(c: U32, safe: Bool) -> String:
  match safe:
    case True{}: Char.show(Chr{c})
    case False{}: "_" ++ U32.show(c) ++ "_"

def name_go(s: String, rev: String) -> String:
  match s:
    case SNil{}: "mark_" ++ String.reverse(rev)
    case SCon{Chr{+c}, t}:
      part = char_name(c, ((c >= 48 : U32) && (c <= 57 : U32)) || ((c >= 65 : U32) && (c <= 90 : U32)) || ((c >= 97 : U32) && (c <= 122 : U32)))
      name_go(t, String.reverse(part) ++ rev)

def name(s: String) -> String: name_go(s, "")

def added(result: Result<&2, &2, Store.Error, List<&2, Obs.Mark>>) -> Bool:
  match result:
    case Fail{e}: False{}
    case Done{marks}: True{}

def add_to(handle: Maybe<&2, Store.Store<List<&2, Obs.Mark>>>, label: String, ms: Nat) -> IO(Bool):
  match handle:
    case None{}: IO.pure(Bool, False{})
    case Some{store}:
      do IO<Bool>:
        result : Result<&2, &2, Store.Error, List<&2, Obs.Mark>> <- Store.update(List<&2, Obs.Mark>, store, marks => Obs.Mark{name(label), ms} <> marks)
        return added(result)

def mark(-Vars: Data, c: C.Ctx<Vars>, label: String, ms: Nat) -> IO(Bool):
  add_to(Obs.timing(C.observation(Vars, c)), label, ms)

def fields(marks: List<&2, Obs.Mark>) -> String:
  match marks:
    case Nil{}: ""
    case Obs.Mark{label, ms} <> t: ", " ++ label ++ ";dur=" ++ Nat.show(ms) ++ fields(t)

def final_value(ms: Nat, result: Result<&2, &2, Store.Error, List<&2, Obs.Mark>>) -> Maybe<&2, String>:
  match result:
    case Fail{error}: None{}
    case Done{marks}: Some{"total;dur=" ++ Nat.show(ms) ++ fields(List.reverse(&2, Obs.Mark, marks))}

def finished(res: Response.Res, value: Maybe<&2, String>) -> Response.Res:
  match value:
    case None{}: Response.body(500, [], [])
    case Some{text}: Obs.header(res, "server-timing", Some{text})

def close(store: Store.Store<List<&2, Obs.Mark>>) -> IO(Unit):
  Store.Store{requests, timeout_ms} = store
  Chan.close(Store.Message<List<&2, Obs.Mark>>, requests)

def run(-Vars: Data, c: C.Ctx<Vars>, id: Maybe<&2, String>, stream: Maybe<&2, Chan(StreamTypes.Registration)>, policies: Maybe<&2, Chan(List<&2, Policy.Policy>)>, peer: Maybe<&2, Conn.ConnInfo>, access: Maybe<&2, Chan(List<&2, Obs.Access>)>, valid: Maybe<&2, V.Values>, next: C.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res):
  do IO<Response.Res>:
    +store : Store.Store<List<&2, Obs.Mark>> <- StoreActor.store(List<&2, Obs.Mark>, [])
    +finalized : Chan(Maybe<&2, String>) <- Chan.new(Maybe<&2, String>, 1)
    before : Nat <- IO.now()
    res : Response.Res <- next(C.with_observation(Vars, c, Obs.State{id, Some{store}, Some{finalized}, policies, stream, peer, access, valid}))
    after : Nat <- IO.now()
    marks : Result<&2, &2, Store.Error, List<&2, Obs.Mark>> <- Store.get(List<&2, Obs.Mark>, store)
    close(store)
    +value : Maybe<&2, String> = final_value(Nat.sub(after, before), marks)
    sent : Result<&1, &1, Maybe<&2, String>, Unit> <- Chan.send(Maybe<&2, String>, finalized, value)
    return finished(res, value)

# Nested registrations share the outer owner's collector and never close it.
def existing(-Vars: Data, c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res), state: Obs.State) -> IO(Response.Res):
  match state:
    case Obs.State{id, None{}, finalized, policies, stream, peer, access, valid}: run(Vars, c, id, stream, policies, peer, access, valid, next)
    case Obs.State{id, Some{store}, finalized, policies, stream, peer, access, valid}: next(c)

def middleware(-Vars: Data, +c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res):
  existing(Vars, c, next, C.observation(Vars, c))
