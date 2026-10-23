import Base
import ../app/context.bend as C
import ../app/observability.bend as Obs
import ../http/response.bend as Response
import ../http/request_id.bend as RequestId
import ../crypto/random.bend as Random
import ../data/json.bend as Json

def hex(bytes: List<&2, U32>) -> String:
  match bytes:
    case Nil{}: ""
    case +b <> t: SCon{Json.nibble(U32.div(b, 16)), SCon{Json.nibble(U32.mod(b, 16)), hex(t)}}

def run(-Vars: Data, +c: C.Ctx<Vars>, +id: String, next: C.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res):
  state = Obs.with_id(C.observation(Vars, c), id)
  do IO<Response.Res>:
    res : Response.Res <- next(C.with_observation(Vars, c, state))
    return Obs.header(res, "x-request-id", Some{id})

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
    case Some{+value}: selected(Vars, c, next, value, RequestId.valid_go(value, 200n, False{}))

def middleware(-Vars: Data, +c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res):
  incoming(Vars, c, next, C.request_header(Vars, c, "x-request-id"))
