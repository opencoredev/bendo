import Base
import ../app/context.bend as C
import ../app/observability.bend as Obs
import ../app/store.bend as Store
import ../http/response.bend as Response
import ../http/bytes.bend as Bytes
import ./common.bend as Common

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

def finish(res: Response.Res, ms: Nat, result: Result<&2, &2, Store.Error, List<&2, Obs.Mark>>) -> Response.Res:
  match result:
    case Fail{error}: Response.body(500, [], [])
    case Done{marks}: Common.header(res, "server-timing", "total;dur=" ++ Nat.show(ms) ++ fields(List.reverse(&2, Obs.Mark, marks)))

def close(store: Store.Store<List<&2, Obs.Mark>>) -> IO(Unit):
  Store.Store{requests, timeout_ms} = store
  Chan.close(Store.Message<List<&2, Obs.Mark>>, requests)

def run(-Vars: Data, c: C.Ctx<Vars>, id: Maybe<&2, String>, next: C.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res):
  do IO<Response.Res>:
    +store : Store.Store<List<&2, Obs.Mark>> <- Store.store(List<&2, Obs.Mark>, [])
    before : Nat <- IO.now()
    res : Response.Res <- next(C.with_observation(Vars, c, Obs.State{id, Some{store}}))
    after : Nat <- IO.now()
    marks : Result<&2, &2, Store.Error, List<&2, Obs.Mark>> <- Store.get(List<&2, Obs.Mark>, store)
    close(store)
    return finish(res, Nat.sub(after, before), marks)

# Nested registrations share the outer owner's collector and never close it.
def existing(-Vars: Data, c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res), state: Obs.State) -> IO(Response.Res):
  match state:
    case Obs.State{id, None{}}: run(Vars, c, id, next)
    case Obs.State{id, Some{store}}: next(c)

def middleware(-Vars: Data, +c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res):
  existing(Vars, c, next, C.observation(Vars, c))
