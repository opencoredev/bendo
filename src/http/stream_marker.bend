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


# Response policies (CORS, secure headers) cannot set, replace or remove the
# marker: `claims` keeps a header list's marker fields, `unclaimed` the rest,
# and `reserved` puts the original's status and marker fields on a changed
# response in place of whatever the change left there. Validation and
# transport then read the same claim.
def claim_field(h: Request.Header, tail: List<&2, Request.Header>, same: Bool) -> List<&2, Request.Header>:
  match same:
    case True{}: h <> tail
    case False{}: tail

def claims(hs: List<&2, Request.Header>) -> List<&2, Request.Header>:
  match hs:
    case Nil{}: []
    case Request.Header{+name, value} <> rest: claim_field(Request.Header{name, value}, claims(rest), String.eq(Bytes.fold(name), marker()))

def other_field(h: Request.Header, tail: List<&2, Request.Header>, same: Bool) -> List<&2, Request.Header>:
  match same:
    case True{}: tail
    case False{}: h <> tail

def unclaimed(hs: List<&2, Request.Header>) -> List<&2, Request.Header>:
  match hs:
    case Nil{}: []
    case Request.Header{+name, value} <> rest: other_field(Request.Header{name, value}, unclaimed(rest), String.eq(Bytes.fold(name), marker()))

def reserved(original: Response.Res, changed: Response.Res) -> Response.Res:
  Response.Res{code, hs, b, r} = original
  Response.Res{old, fields, body, rep} = changed
  Response.Res{code, List.append(&2, Request.Header, claims(hs), unclaimed(fields)), body, rep}

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

# Whether transport hands this response to the registration `claim` names.
def delivers(claim: Claim, res: Response.Res) -> Bool:
  Response.Res{code, hs, body, rep} = res
  eligible(claim, code, hs)
