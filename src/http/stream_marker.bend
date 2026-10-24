# Pure request-private registration marker fields.
import Base
import ./request.bend as Request
import ./response.bend as Response
import ./bytes.bend as Bytes

def marker() -> String: "x-bendo-stream-internal"

def keep(h: Request.Header) -> Bool:
  Request.Header{name, value} = h
  Bool.not(String.eq(Bytes.fold(name), marker()))

def strip(res: Response.Res) -> Response.Res:
  Response.Res{status, hs, body, rep} = res
  Response.Res{status, List.filter(~Request.Header, ~keep, hs), body, rep}

def marked(hs: List<&2, Request.Header>, +id: String) -> Bool:
  match hs:
    case Nil{}: False{}
    case Request.Header{name, value} <> rest:
      (String.eq(Bytes.fold(name), marker()) && String.eq(Bytes.ascii(value), id)) || marked(rest, id)

def mark(res: Response.Res, id: String) -> Response.Res:
  Response.Res{code, hs, body, rep} = res
  Response.Res{code, Request.Header{marker(), Bytes.encode(id)} <> hs, [], None{}}

