import Base
import ../app/context.bend as C
import ../http/request.bend as Request
import ../http/response.bend as Response
import ./common.bend as Common
import ../http/request_id.bend as RequestId

def suffix(id: Maybe<&2, String>) -> String:
  match id:
    case None{}: ""
    case Some{value}: " id=" ++ value

def safe_suffix(value: String, safe: Bool) -> String:
  match safe:
    case True{}: " id=" ++ value
    case False{}: ""

def chosen(response_id: Maybe<&2, String>, context_id: Maybe<&2, String>) -> String:
  match response_id:
    case None{}: suffix(context_id)
    case Some{+value}: safe_suffix(value, RequestId.valid_go(value, 200n, False{}))

def line(-Vars: Data, +c: C.Ctx<Vars>, +res: Response.Res, elapsed: Nat) -> String:
  Response.Res{status, hs, body, rep} = res
  Request.method_text(C.method(Vars, c)) ++ " " ++ C.path(Vars, c) ++ " " ++ U32.show(status) ++ " " ++ Nat.show(elapsed) ++ "ms" ++ chosen(Common.response_header(res, "x-request-id"), C.request_id(Vars, c))

def middleware(-Vars: Data, +c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res):
  do IO<Response.Res>:
    before : Nat <- IO.now()
    raw : Response.Res <- next(c)
    after : Nat <- IO.now()
    +res : Response.Res = C.finalize(raw)
    IO.print_err(line(Vars, c, res, Nat.sub(after, before)))
    return res
