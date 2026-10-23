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

# Responses built on a context that already holds response headers.
#
# Header admissibility, from RFC 9110 field syntax: the name is a nonempty
# token in ASCII lowercase; the value has only field octets (HTAB, SP, visible
# ASCII and obs-text) and neither starts nor ends with SP or HTAB. The token
# and field-octet character classes are the shared ones in Bytes.
def token_rest(s: String) -> Bool:
  match s:
    case SNil{}: True{}
    case SCon{Chr{+c}, t}: Bytes.tchar(c) && token_rest(t)

def token(s: String) -> Bool:
  match s:
    case SNil{}: False{}
    case SCon{Chr{+c}, t}: Bytes.tchar(c) && token_rest(t)

def blank(+c: U32) -> Bool:
  U32.is_eq(c, 32) || U32.is_eq(c, 9)

def field_octets(xs: List<&2, U32>) -> Bool:
  match xs:
    case Nil{}: True{}
    case c <> t: Bytes.value_octet(c) && field_octets(t)

def first_clear(xs: List<&2, U32>) -> Bool:
  match xs:
    case Nil{}: True{}
    case c <> t: Bool.not(blank(c))

# clear records whether the most recent byte so far was not SP or HTAB.
def last_clear(xs: List<&2, U32>, clear: Bool) -> Bool:
  match xs:
    case Nil{}: clear
    case c <> t: last_clear(t, Bool.not(blank(c)))

def header_ok(h: Request.Header) -> Bool:
  match h:
    case Request.Header{+n, +v}: token(n) && String.eq(n, Bytes.fold(n)) && field_octets(v) && first_clear(v) && last_clear(v, True{})

def admissible(hs: List<&2, Request.Header>) -> Bool:
  match hs:
    case Nil{}: True{}
    case h <> t: header_ok(h) && admissible(t)

def octets(xs: List<&2, U32>) -> Bool:
  match xs:
    case Nil{}: True{}
    case c <> t: (c <= 255 : U32) && octets(t)

def witness_ok(w: Maybe<&2, List<&2, U32>>) -> Bool:
  match w:
    case None{}: True{}
    case Some{xs}: octets(xs)

# A response reaches the client when its status is 100..599, every header is
# admissible, and the body and any witness hold octets. Otherwise the client
# gets the empty 500.
def res_ok(r: Response.Res) -> Bool:
  match r:
    case Response.Res{+s, hs, b, w}: (s >= 100 : U32) && (s <= 599 : U32) && admissible(hs) && octets(b) && witness_ok(w)

def deliver_pick(+r: Response.Res, ok: Bool) -> Response.Res:
  match ok:
    case True{}: r
    case False{}: Response.Res{500, [], [], None{}}

def deliver(+r: Response.Res) -> Response.Res:
  deliver_pick(r, res_ok(r))

# Accumulated headers other than Content-Type and Vary, in their order.
def keep_pick(h: Request.Header, rest: List<&2, Request.Header>, drop: Bool) -> List<&2, Request.Header>:
  match drop:
    case True{}: rest
    case False{}: h <> rest

def kept(hs: List<&2, Request.Header>) -> List<&2, Request.Header>:
  match hs:
    case Nil{}: []
    case Request.Header{+n, v} <> t: keep_pick(Request.Header{n, v}, kept(t), String.eq(n, "content-type") || String.eq(n, "vary"))

# The values of accumulated fields named vary, in their order.
def vary_pick(v: List<&2, U32>, rest: List<&2, List<&2, U32>>, same: Bool) -> List<&2, List<&2, U32>>:
  match same:
    case True{}: v <> rest
    case False{}: rest

def vary_fields(hs: List<&2, Request.Header>) -> List<&2, List<&2, U32>>:
  match hs:
    case Nil{}: []
    case Request.Header{+n, v} <> t: vary_pick(v, vary_fields(t), String.eq(n, "vary"))

# A wildcard Vary value: with SP and HTAB removed, exactly "*".
def drop_pick(+c: U32, rest: List<&2, U32>, drop: Bool) -> List<&2, U32>:
  match drop:
    case True{}: rest
    case False{}: c <> rest

def unblank(xs: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}: []
    case +c <> t: drop_pick(c, unblank(t), blank(c))

def nil(xs: List<&2, U32>) -> Bool:
  match xs:
    case Nil{}: True{}
    case c <> t: False{}

def only_star(xs: List<&2, U32>) -> Bool:
  match xs:
    case Nil{}: False{}
    case c <> t: U32.is_eq(c, 42) && nil(t)

def wildcard(v: List<&2, U32>) -> Bool:
  only_star(unblank(v))

def any_wildcard(vs: List<&2, List<&2, U32>>) -> Bool:
  match vs:
    case Nil{}: False{}
    case v <> t: wildcard(v) || any_wildcard(t)

# Items separated by ", ".
def separated(xs: List<&2, List<&2, U32>>) -> List<&2, U32>:
  match xs:
    case Nil{}: []
    case x <> Nil{}: x
    case x <> t: List.append(&2, U32, x, List.append(&2, U32, Bytes.encode(", "), separated(t)))

# The one Vary field: * if any existing value is a wildcard, otherwise the
# existing values byte for byte followed by Accept.
def merged_pick(vs: List<&2, List<&2, U32>>, star: Bool) -> List<&2, U32>:
  match star:
    case True{}: Bytes.encode("*")
    case False{}: separated(List.append(&2, List<&2, U32>, vs, [Bytes.encode("Accept")]))

def merged_vary(+vs: List<&2, List<&2, U32>>) -> List<&2, U32>:
  merged_pick(vs, any_wildcard(vs))

# Negotiated Content-Type first, the kept headers, then the merged Vary field.
def headers(json: Bool, +hs: List<&2, Request.Header>) -> List<&2, Request.Header>:
  content_type(json) <> List.append(&2, Request.Header, kept(hs), [Request.Header{"vary", merged_vary(vary_fields(hs))}])

def private_with(+json: Bool, +code: U32, +hs: List<&2, Request.Header>) -> Response.Res:
  +s = status(code)
  deliver(Response.Res{s, headers(json, hs), private_body(json, s), None{}})

# A JSON message must be Unicode scalar text; otherwise the empty 500.
def scalar_pick(scalars: Bool, +r: Response.Res) -> Response.Res:
  match scalars:
    case True{}: r
    case False{}: Response.Res{500, [], [], None{}}

def render(json: Bool, +code: U32, +text: String, +hs: List<&2, Request.Header>) -> Response.Res:
  match json:
    case True{}: scalar_pick(Utf8.valid(text), deliver(Response.Res{code, headers(True{}, hs), Response.utf8(json_text(text, code)), None{}}))
    case False{}: deliver(Response.Res{code, headers(False{}, hs), Response.utf8(text), None{}})

def exposed_with(json: Bool, +code: U32, m: String, +hs: List<&2, Request.Header>) -> Response.Res:
  render(json, code, public_text(m, code), hs)
