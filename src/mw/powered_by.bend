import Base
import ../app/context.bend as C
import ../http/response.bend as Response
import ./common.bend as Common

def middleware(-Vars: Data, name: String, c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res):
  do IO<Response.Res>:
    res : Response.Res <- next(c)
    return Common.header(res, "x-powered-by", name)
