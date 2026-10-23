import Base
import ../app/context.bend as C
import ../http/request.bend as Request
import ../http/response.bend as Response

def header(res: Response.Res, +name: String, value: String) -> Response.Res:
  Response.Res{status, hs, body, rep} = res
  Response.Res{status, List.append(&2, Request.Header, C.without(hs, name), [Request.Header{name, Response.utf8(value)}]), body, rep}

def response_header(res: Response.Res, name: String) -> Maybe<&2, String>:
  Response.Res{s, hs, b, rep} = res
  C.first_text(Request.lookup(hs, name))
