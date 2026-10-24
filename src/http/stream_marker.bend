# Pure request-private registration marker fields.
import Base
import ./request.bend as Request
import ./response.bend as Response
import ./bytes.bend as Bytes

def marker() -> String: "x-bendo-stream-internal"

# Whether a field name is the marker, in any case: the specification of
# `named`, and the test every function here used before BND-96.
def named_spec(name: String) -> Bool:
  String.eq(Bytes.fold(name), marker())

# Char.to_lower's code point.
def lower_code(c: Char) -> U32:
  match c:
    case Chr{+x}: U32.add(x, U32.mul(Bool.to_u32(Char.is_upper(Chr{x})), 32))

# String.order over the lowered name, without building it: each character is
# lowered as it is compared, and the walk stops at the first difference.
def named_go(name: String, lit: String, c: Cmp) -> Bool:
  match name lit c:
    case SCon{h, t} SCon{Chr{y}, u} EQ{}: named_go(t, u, U32.cmp(lower_code(h), y))
    case SNil{} SNil{} EQ{}: True{}
    case _ _ _: False{}

# BND-96: every response runs this test on each field several times
# (finalization reserves the marker, transport strips it), and lowering a
# whole name first allocated two strings per field. Law hot_marker_named
# states named == named_spec for every name.
def named(name: String) -> Bool:
  named_go(name, marker(), EQ{})

def keep(h: Request.Header) -> Bool:
  Request.Header{name, value} = h
  Bool.not(named(name))

def strip(res: Response.Res) -> Response.Res:
  Response.Res{status, hs, body, rep} = res
  Response.Res{status, List.filter(~Request.Header, ~keep, hs), body, rep}

def marked(hs: List<&2, Request.Header>, +id: String) -> Bool:
  match hs:
    case Nil{}: False{}
    case Request.Header{name, value} <> rest:
      (named(name) && String.eq(Bytes.ascii(value), id)) || marked(rest, id)

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
    case Request.Header{+name, value} <> rest: claim_field(Request.Header{name, value}, claims(rest), named(name))

def other_field(h: Request.Header, tail: List<&2, Request.Header>, same: Bool) -> List<&2, Request.Header>:
  match same:
    case True{}: tail
    case False{}: h <> tail

def unclaimed(hs: List<&2, Request.Header>) -> List<&2, Request.Header>:
  match hs:
    case Nil{}: []
    case Request.Header{+name, value} <> rest: other_field(Request.Header{name, value}, unclaimed(rest), named(name))

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
