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


# What the request registered for its response, without the affine plan or
# session: nothing, a body stream, or a WebSocket upgrade, each under its id.
type Claim is Data:
  Unclaimed{}
  BodyClaim{id: String}
  UpgradeClaim{id: String}

# Whether transport hands the response to its registration. A body stream
# needs its own marker; an upgrade needs its own marker and a 101. A marker
# with no registration, or another registration's id, claims nothing.
# Transport selection and response validation both decide with this.
def eligible(claim: Claim, +code: U32, hs: List<&2, Request.Header>) -> Bool:
  match claim:
    case Unclaimed{}: False{}
    case BodyClaim{id}: marked(hs, id)
    case UpgradeClaim{id}: marked(hs, id) && U32.is_eq(code, 101)
