import Base
import ../app/context.bend as C
import ../app/observability.bend as Obs
import ../http/response.bend as Response
import ../crypto/random.bend as Random
import ../data/json.bend as Json
import ./common.bend as Common

def safe_char(+c: U32) -> Bool:
  ((c >= 48 : U32) && (c <= 57 : U32)) || ((c >= 65 : U32) && (c <= 90 : U32)) || ((c >= 97 : U32) && (c <= 122 : U32)) || String.contains("._-", Char.show(Chr{c}))

def valid_go(s: String, fuel: Nat, nonempty: Bool) -> Bool:
  match s fuel:
    case SNil{} _: nonempty
    case SCon{Chr{c}, t} 0n: False{}
    case SCon{Chr{c}, t} 1n+p: safe_char(c) && valid_go(t, p, True{})

def hex(bytes: List<&2, U32>) -> String:
  match bytes:
    case Nil{}: ""
    case +b <> t: SCon{Json.nibble(U32.div(b, 16)), SCon{Json.nibble(U32.mod(b, 16)), hex(t)}}

def run(-Vars: Data, +c: C.Ctx<Vars>, +id: String, next: C.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res):
  timing = Obs.timing(C.observation(Vars, c))
  do IO<Response.Res>:
    res : Response.Res <- next(C.with_observation(Vars, c, Obs.State{Some{id}, timing}))
    return Common.header(res, "x-request-id", id)

def generated(-Vars: Data, c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res), result: Result<&1, &1, Random.RandomError(), List<&2, U32>>) -> IO(Response.Res):
  match result:
    case Fail{error}: IO.pure(Response.Res, Response.body(500, [], []))
    case Done{bytes}: run(Vars, c, hex(bytes), next)

def selected(-Vars: Data, c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res), id: String, valid: Bool) -> IO(Response.Res):
  match valid:
    case True{}: run(Vars, c, id, next)
    case False{}:
      do IO<Response.Res>:
        result : Result<&1, &1, Random.RandomError(), List<&2, U32>> <- Random.random_bytes(16n)
        generated(Vars, c, next, result)

def incoming(-Vars: Data, c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res), id: Maybe<&2, String>) -> IO(Response.Res):
  match id:
    case None{}: selected(Vars, c, next, "", False{})
    case Some{+value}: selected(Vars, c, next, value, valid_go(value, 200n, False{}))

def middleware(-Vars: Data, +c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res):
  incoming(Vars, c, next, C.request_header(Vars, c, "x-request-id"))
