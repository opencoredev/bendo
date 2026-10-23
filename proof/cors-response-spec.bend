# BND-40: the response a request leaves after CORS finalization, read from
# the request itself. Request field lookup, UTF-8 decoding, origin
# serialization, string splitting and trimming, case folding and the token
# test are shared primitives.
import Base
import ../src/http/request.bend as Request
import ../src/http/response.bend as Response
import ../src/data/utf8.bend as Utf8
import ../src/http/bytes.bend as Bytes
import ../src/mw/cors_policy.bend as P
import ./cors-spec.bend as CorsSpec
import ./response-policy-spec.bend as RS

def decoded(m: Maybe<&2, String>) -> String:
  match m:
    case None{}: ""
    case Some{s}: s

# The Origin field: absent, exactly one (undecodable text is ""), or repeated.
def origin_field(values: List<&2, List<&2, U32>>) -> P.Sent:
  match values:
    case Nil{}: P.Absent{}
    case v <> Nil{}: P.Sent{decoded(Utf8.decode(v))}
    case v <> w <> t: P.Repeated{}

def decoded_all(values: List<&2, List<&2, U32>>) -> List<&2, String>:
  match values:
    case Nil{}: []
    case v <> t: decoded(Utf8.decode(v)) <> decoded_all(t)

# Every Access-Control-Request-Headers field as one comma list.
def requested_list(values: List<&2, List<&2, U32>>) -> Maybe<&2, String>:
  match values:
    case Nil{}: None{}
    case v <> t: Some{String.join(decoded_all(v <> t), ",")}

def any_field(values: List<&2, List<&2, U32>>) -> Bool:
  match values:
    case Nil{}: False{}
    case v <> t: True{}

def named(+name: String, rest: List<&2, String>, ok: Bool) -> List<&2, String>:
  match ok:
    case True{}: name <> rest
    case False{}: rest

# The listed names that are tokens, trimmed and lowercased, in order.
def requested_names(parts: List<&2, String>) -> List<&2, String>:
  match parts:
    case Nil{}: []
    case x <> t:
      +name = Bytes.fold(String.trim(x))
      named(name, requested_names(t), Bytes.token(name))

def comma_list(names: List<&2, String>) -> Maybe<&2, String>:
  match names:
    case Nil{}: None{}
    case x <> t: Some{String.join(x <> t, ",")}

# The headers a reflecting preflight allows: the requested names that are
# tokens, lowercased, as one comma list; none when no name survives.
def reflected(r: Maybe<&2, String>) -> Maybe<&2, String>:
  match r:
    case None{}: None{}
    case Some{v}: comma_list(requested_names(String.split(v, ',')))

def request_headers(req: Request.Req) -> List<&2, Request.Header>:
  match req:
    case Request.Req{m, p, q, v, hs}: hs

def request_method(req: Request.Req) -> Request.Method:
  match req:
    case Request.Req{m, p, q, v, hs}: m

def sent(req: Request.Req) -> P.Sent:
  origin_field(Request.lookup(request_headers(req), "origin"))

def config_origins(config: P.Config) -> P.Origins:
  match config:
    case P.Config{o, m, h, e, a}: o

def grant(config: P.Config, req: Request.Req) -> Maybe<&2, P.Grant>:
  CorsSpec.grant(config_origins(config), sent(req))

def requested(req: Request.Req) -> Maybe<&2, String>:
  requested_list(Request.lookup(request_headers(req), "access-control-request-headers"))

def preflight(+req: Request.Req) -> Bool:
  CorsSpec.preflight(request_method(req), sent(req), any_field(Request.lookup(request_headers(req), "access-control-request-method")))

def as_headers(fs: List<&2, P.Field>) -> List<&2, Request.Header>:
  match fs:
    case Nil{}: []
    case P.Field{n, v} <> t: Request.Header{n, Response.utf8(v)} <> as_headers(t)

# Every CORS response field. A downstream copy of any of them, in any case,
# is dropped, so no stale or conflicting grant survives.
def cors_names() -> List<&2, String>:
  ["access-control-allow-origin", "access-control-allow-credentials", "access-control-expose-headers", "access-control-allow-methods", "access-control-allow-headers", "access-control-max-age"]

def origin_names(o: P.Origins) -> List<&2, String>:
  match o:
    case P.Any{}: []
    case P.Listed{es}: ["Origin"]

def request_header_names(preflight: Bool, headers: List<&2, String>) -> List<&2, String>:
  match preflight:
    case True{}:
      match headers:
        case Nil{}: ["Access-Control-Request-Headers"]
        case x <> t: []
    case False{}: []

# A listed policy's answer depends on Origin; a preflight reflecting the
# requested headers depends on Access-Control-Request-Headers.
def vary_names(config: P.Config, preflight: Bool) -> List<&2, String>:
  match config:
    case P.Config{o, m, h, e, a}: List.append(&2, String, origin_names(o), request_header_names(preflight, h))

def added(+config: P.Config, g: Maybe<&2, P.Grant>, r: Maybe<&2, String>, preflight: Bool) -> List<&2, Request.Header>:
  match preflight:
    case True{}: as_headers(CorsSpec.preflight_fields(config, g, reflected(r)))
    case False{}: as_headers(CorsSpec.actual_fields(config, g))

def built(+config: P.Config, g: Maybe<&2, P.Grant>, r: Maybe<&2, String>, +preflight: Bool, res: Response.Res) -> Response.Res:
  match res:
    case Response.Res{s, hs, b, rep}: Response.Res{s, RS.varied(List.append(&2, Request.Header, RS.unrelated(hs, cors_names()), added(config, g, r, preflight)), vary_names(config, preflight)), b, rep}

# The finalized response: status, body, representation and every unrelated
# field as downstream left them; every downstream CORS field gone; then the
# preflight or actual CORS fields for the grant this request earns; then the
# Vary merge for the names this policy depends on.
def response(+config: P.Config, +req: Request.Req, res: Response.Res) -> Response.Res:
  built(config, grant(config, req), requested(req), preflight(req), res)
