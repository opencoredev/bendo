# BND-25: an independent statement of the framework's public error response.
# Nothing here calls the Errors module or the context's rendering helpers.
import Base
import ../src/http/request.bend as Request
import ../src/http/response.bend as Response
import ../src/http/bytes.bend as Bytes
import ../src/data/json.bend as Json
import ../src/data/utf8.bend as Utf8

# The status is the code itself from 400 through 599, otherwise 500.
def status_pick(code: U32, in_range: Bool) -> U32:
  match in_range:
    case True{}: code
    case False{}: 500

def status(+code: U32) -> U32:
  status_pick(code, (code >= 400 : U32) && (code <= 599 : U32))

def content_type(json: Bool) -> Request.Header:
  match json:
    case True{}: Request.Header{"content-type", Bytes.encode("application/json; charset=utf-8")}
    case False{}: Request.Header{"content-type", Bytes.encode("text/plain; charset=utf-8")}

def vary() -> Request.Header:
  Request.Header{"vary", Bytes.encode("Accept")}

# The JSON text is UTF-8 encoded; the text body is exactly these ASCII bytes.
def private_body(json: Bool, +status: U32) -> List<&2, U32>:
  match json:
    case True{}: Response.utf8("{\"error\":\"Internal Server Error\",\"status\":" ++ Nat.show(U32.to_nat(status)) ++ "}")
    case False{}: Bytes.encode("Internal Server Error")

# The response Context.error returns for a private error, before app hooks.
def private(+json: Bool, +code: U32) -> Response.Res:
  +s = status(code)
  Response.Res{s, [content_type(json), vary()], private_body(json, s), None{}}

# Response validity is checked last; an invalid response becomes the empty 500.
def guard_pick(+r: Response.Res, valid: Bool) -> Response.Res:
  match valid:
    case True{}: r
    case False{}: Response.Res{500, [], [], None{}}

def guard(+r: Response.Res) -> Response.Res:
  guard_pick(r, Response.valid(r))

# JSON needs Unicode scalar text; anything else is the empty 500.
def json_pick(scalars: Bool, +r: Response.Res) -> Response.Res:
  match scalars:
    case True{}: guard(r)
    case False{}: Response.Res{500, [], [], None{}}

# An exposed message is public as configured; an empty one uses the reason phrase.
def public_text(m: String, +code: U32) -> String:
  match m:
    case SNil{}: Response.reason(code)
    case SCon{h, t}: SCon{h, t}

# The JSON writer's compact text for {"error": text, "status": code}.
def json_text(text: String, +code: U32) -> String:
  "{\"error\":" ++ Json.quote(text, False{}) ++ ",\"status\":" ++ Nat.show(U32.to_nat(code)) ++ "}"

def exposed_text(json: Bool, +code: U32, +text: String) -> Response.Res:
  match json:
    case True{}: json_pick(Utf8.valid(text), Response.Res{code, [content_type(True{}), vary()], Response.utf8(json_text(text, code)), None{}})
    case False{}: guard(Response.Res{code, [content_type(False{}), vary()], Response.utf8(text), None{}})

def exposed(json: Bool, +code: U32, m: String) -> Response.Res:
  exposed_text(json, code, public_text(m, code))

# Representative Accept fields and the representation the documented policy picks.
type Sample is Data:
  Absent{}
  JsonRange{}
  JsonParameters{}
  JsonZero{}
  JsonQuotedZero{}
  Wildcard{}
  TextRange{}

def sample_field(s: Sample) -> Maybe<&2, String>:
  match s:
    case Absent{}: None{}
    case JsonRange{}: Some{"application/json"}
    case JsonParameters{}: Some{"text/plain, Application/JSON; charset=utf-8; q=0.5"}
    case JsonZero{}: Some{"application/json;q=0"}
    case JsonQuotedZero{}: Some{"application/json;profile=\"a,b\";q=0"}
    case Wildcard{}: Some{"*/*"}
    case TextRange{}: Some{"text/plain"}

def sample_json(s: Sample) -> Bool:
  match s:
    case Absent{}: False{}
    case JsonRange{}: True{}
    case JsonParameters{}: True{}
    case JsonZero{}: False{}
    case JsonQuotedZero{}: False{}
    case Wildcard{}: False{}
    case TextRange{}: False{}

# http_error(418, "Tea only"), written out byte for byte.
def tea_only(json: Bool) -> Response.Res:
  match json:
    case True{}: Response.Res{418, [content_type(True{}), vary()], Bytes.encode("{\"error\":\"Tea only\",\"status\":418}"), None{}}
    case False{}: Response.Res{418, [content_type(False{}), vary()], Bytes.encode("Tea only"), None{}}
