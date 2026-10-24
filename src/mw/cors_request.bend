# The CORS decision read from a request, as pure functions. src/mw/cors.bend
# runs it; LAWS.bend states what the finalized response is.
import Base
import ../http/request.bend as Request
import ../http/response.bend as Response
import ../data/utf8.bend as Utf8
import ../http/text.bend as Text
import ./cors_policy.bend as P
import ./response_policy.bend as Policy

def text(m: Maybe<&2, String>) -> String:
  match m:
    case None{}: ""
    case Some{s}: s

# Undecodable UTF-8 becomes "", which is not an origin and is denied.
def sent(values: List<&2, List<&2, U32>>) -> P.Sent:
  match values:
    case Nil{}: P.Absent{}
    case v <> Nil{}: P.Sent{text(Utf8.decode(v))}
    case _: P.Repeated{}

def some(values: List<&2, List<&2, U32>>) -> Bool:
  match values:
    case Nil{}: False{}
    case _: True{}

def texts_spec(values: List<&2, List<&2, U32>>) -> List<&2, String>:
  match values:
    case Nil{}: []
    case v <> t: text(Utf8.decode(v)) <> texts_spec(t)

# texts_spec as a tail loop over the reversed fields (BND-84).
def texts_go(rev: List<&2, List<&2, U32>>, acc: List<&2, String>) -> List<&2, String>:
  match rev:
    case Nil{}: acc
    case v <> r: texts_go(r, text(Utf8.decode(v)) <> acc)

def texts(values: List<&2, List<&2, U32>>) -> List<&2, String>:
  texts_go(List.reverse(&2, List<&2, U32>, values), [])

# Every Access-Control-Request-Headers field, combined as one comma list.
# An undecodable field contributes nothing.
def combined(values: List<&2, List<&2, U32>>) -> Maybe<&2, String>:
  match values:
    case Nil{}: None{}
    case v <> t: Some{Text.join(texts(v <> t), ",")}

def fields(xs: List<&2, P.Field>) -> List<&2, Request.Header>:
  match xs:
    case Nil{}: []
    case P.Field{n, v} <> t: Request.Header{n, Response.utf8(v)} <> fields(t)

def headers_of(req: Request.Req) -> List<&2, Request.Header>:
  match req:
    case Request.Req{m, p, q, v, hs}: hs

def method_of(req: Request.Req) -> Request.Method:
  match req:
    case Request.Req{m, p, q, v, hs}: m

def who(req: Request.Req) -> P.Sent:
  sent(Request.lookup(headers_of(req), "origin"))

def grant(config: P.Config, req: Request.Req) -> Maybe<&2, P.Grant>:
  P.grant(P.origins_of(config), who(req))

def requested(req: Request.Req) -> Maybe<&2, String>:
  combined(Request.lookup(headers_of(req), "access-control-request-headers"))

def preflight(+req: Request.Req) -> Bool:
  P.preflight(method_of(req), who(req), some(Request.lookup(headers_of(req), "access-control-request-method")))

def chosen(+config: P.Config, g: Maybe<&2, P.Grant>, requested: Maybe<&2, String>, +preflight: Bool) -> Policy.Policy:
  match preflight:
    case True{}: Policy.Policy{P.owned(), fields(P.preflight_fields(config, g, P.reflect(requested))), P.vary(config, preflight)}
    case False{}: Policy.Policy{P.owned(), fields(P.actual_fields(config, g)), P.vary(config, preflight)}

# The policy retained for finalization: the grant, preflight classification
# and requested headers all come from this request's own fields.
def policy(+config: P.Config, +req: Request.Req) -> Policy.Policy:
  chosen(config, grant(config, req), requested(req), preflight(req))
