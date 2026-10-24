# Immutable request state. Vars is app-owned copyable data, never a dynamic map.
import Base
import ../http/request.bend as Request
import ../http/response.bend as Response
import ../http/bytes.bend as Bytes
import ../router/pattern.bend as Pattern
import ../data/urlencoded.bend as Query
import ../data/utf8.bend as Utf8
import ../data/json.bend as Json
import ./observability.bend as Obs
import ./errors.bend as Errors
import ./validate.bend as V
import ../data/schema.bend as Schema
import ../net/conn_info.bend as Conn

import ../data/cookie.bend as Cookie
import ../data/signed-cookie.bend as SignedCookie

type Ctx<-Vars: Data> is Data:
  Ctx{req: Request.Req, params: Pattern.Params, body: List<&2, U32>, pairs: List<&2, Query.Entry>, code: U32, headers: List<&2, Request.Header>, vars: Maybe<&2, Vars>, observation: Obs.State}

def query_pairs(q: Maybe<&2, String>) -> Result<&2, &2, Query.Error, List<&2, Query.Entry>>:
  match q:
    case None{}: Done{[]}
    case Some{s}: Query.parse_pairs(s)

def create(req: Request.Req, params: Pattern.Params, body: List<&2, U32>, pairs: List<&2, Query.Entry>) -> Ctx<Unit>:
  Ctx{req, params, body, pairs, 200, [], None{}, Obs.empty()}

def variables(-Vars: Data, c: Ctx<Unit>) -> Ctx<Vars>:
  Ctx{r, p, b, q, s, hs, v, o} = c
  Ctx{r, p, b, q, s, hs, None{}, o}

def set(-Vars: Data, c: Ctx<Vars>, value: Vars) -> Ctx<Vars>:
  Ctx{r, p, b, q, s, hs, v, o} = c
  Ctx{r, p, b, q, s, hs, Some{value}, o}

def get(-Vars: Data, c: Ctx<Vars>) -> Maybe<&2, Vars>:
  Ctx{r, p, b, q, s, hs, v, o} = c
  v

def request(-Vars: Data, c: Ctx<Vars>) -> Request.Req:
  Ctx{r, p, b, q, s, hs, v, o} = c
  r

# Request-stage rewrites preserve buffered body/query data; route captures are
# recomputed after the request hook chain has finished.
def rewrite(-Vars: Data, c: Ctx<Vars>, method: Request.Method, path: String) -> Ctx<Vars>:
  Ctx{Request.Req{old_method, old_path, query, version, hs}, ps, body, pairs, code, headers, vars, observation} = c
  Ctx{Request.Req{method, path, query, version, hs}, [], body, pairs, code, headers, vars, observation}

def raw_body(-Vars: Data, c: Ctx<Vars>) -> List<&2, U32>:
  Ctx{r, p, b, q, s, hs, v, o} = c
  b

def param_pick(value: String, rest: Maybe<&2, String>, same: Bool) -> Maybe<&2, String>:
  match same:
    case True{}: Some{value}
    case False{}: rest

def param_go(ps: Pattern.Params, +name: String) -> Maybe<&2, String>:
  match ps:
    case Nil{}: None{}
    case Pattern.Param{k, v} <> t:
      param_pick(v, param_go(t, name), String.eq(k, name))

def param(-Vars: Data, c: Ctx<Vars>, name: String) -> Maybe<&2, String>:
  Ctx{r, p, b, q, s, hs, v, o} = c
  param_go(p, name)

def query(-Vars: Data, c: Ctx<Vars>, name: String) -> Maybe<&2, String>:
  Ctx{r, p, b, q, s, hs, v, o} = c
  Query.query(q, name)

def queries(-Vars: Data, c: Ctx<Vars>, name: String) -> List<&2, String>:
  Ctx{r, p, b, q, s, hs, v, o} = c
  Query.queries(q, name)

def header_bytes(-Vars: Data, c: Ctx<Vars>, name: String) -> List<&2, List<&2, U32>>:
  Ctx{Request.Req{m, p, q, ver, hs}, ps, b, pairs, s, out, v, o} = c
  Request.lookup(hs, name)

def first_text(values: List<&2, List<&2, U32>>) -> Maybe<&2, String>:
  match values:
    case Nil{}: None{}
    case v <> t: Utf8.decode(v)

# First occurrence only; None means absent or invalid UTF-8. header_bytes
# preserves all occurrences and distinguishes those cases without data loss.
def request_header(-Vars: Data, c: Ctx<Vars>, name: String) -> Maybe<&2, String>:
  first_text(header_bytes(Vars, c, name))

def method(-Vars: Data, c: Ctx<Vars>) -> Request.Method:
  Ctx{Request.Req{m, p, q, ver, hs}, ps, b, pairs, s, out, v, o} = c
  m

def path(-Vars: Data, c: Ctx<Vars>) -> String:
  Ctx{Request.Req{m, p, q, ver, hs}, ps, b, pairs, s, out, v, o} = c
  p

def url(-Vars: Data, c: Ctx<Vars>) -> String:
  Request.target(request(Vars, c))

def status(-Vars: Data, c: Ctx<Vars>, code: U32) -> Ctx<Vars>:
  Ctx{r, p, b, q, s, hs, v, o} = c
  Ctx{r, p, b, q, code, hs, v, o}

def keep_header(h: Request.Header, tail: List<&2, Request.Header>, same: Bool) -> List<&2, Request.Header>:
  match same:
    case True{}: tail
    case False{}: h <> tail

def without(hs: List<&2, Request.Header>, +name: String) -> List<&2, Request.Header>:
  match hs:
    case Nil{}: []
    case Request.Header{+k, v} <> t:
      keep_header(Request.Header{k, v}, without(t, name), String.eq(k, name))

# Invalid fields remain in the accumulator; finalization rejects them as 500.
def header(-Vars: Data, c: Ctx<Vars>, name: String, value: String) -> Ctx<Vars>:
  Ctx{r, p, b, q, s, hs, v, o} = c
  +key = Bytes.fold(name)
  Ctx{r, p, b, q, s, List.append(&2, Request.Header, without(hs, key), [Request.Header{key, Response.utf8(value)}]), v, o}

def checked(res: Response.Res, valid: Bool) -> Response.Res:
  match valid:
    case True{}: res
    case False{}: Response.body(500, [], [])

def finalize(+res: Response.Res) -> Response.Res:
  checked(res, Response.valid(res))

def type_headers(hs: List<&2, Request.Header>, content_type: Maybe<&2, String>) -> List<&2, Request.Header>:
  match content_type:
    case None{}: hs
    case Some{value}:
      Request.Header{"content-type", Response.utf8(value)} <> without(hs, "content-type")

def body(-Vars: Data, c: Ctx<Vars>, bytes: List<&2, U32>, content_type: Maybe<&2, String>) -> Response.Res:
  Ctx{r, p, b, q, s, hs, v, o} = c
  +original = hs
  +res = Response.body(s, type_headers(original, content_type), bytes)
  checked(res, Request.headers_valid(original) && Response.valid(res))

# Like type_headers, with the Content-Type value already encoded.
def typed_headers(hs: List<&2, Request.Header>, content_type: List<&2, U32>) -> List<&2, Request.Header>:
  Request.Header{"content-type", content_type} <> without(hs, "content-type")

# Like body, for the framework's fixed Content-Type values. Laws
# hot_context_text, hot_context_html and hot_context_json_result equate each
# caller with the earlier body call that encoded the value per response.
def body_typed(-Vars: Data, c: Ctx<Vars>, bytes: List<&2, U32>, content_type: List<&2, U32>) -> Response.Res:
  Ctx{r, p, b, q, s, hs, v, o} = c
  +original = hs
  +res = Response.body(s, typed_headers(original, content_type), bytes)
  checked(res, Request.headers_valid(original) && Response.valid(res))

# "text/plain; charset=utf-8", "text/html; charset=utf-8" and
# "application/json; charset=utf-8" as bytes.
def text_type() -> List<&2, U32>:
  [116, 101, 120, 116, 47, 112, 108, 97, 105, 110, 59, 32, 99, 104, 97, 114, 115, 101, 116, 61, 117, 116, 102, 45, 56]

def html_type() -> List<&2, U32>:
  [116, 101, 120, 116, 47, 104, 116, 109, 108, 59, 32, 99, 104, 97, 114, 115, 101, 116, 61, 117, 116, 102, 45, 56]

def json_type() -> List<&2, U32>:
  [97, 112, 112, 108, 105, 99, 97, 116, 105, 111, 110, 47, 106, 115, 111, 110, 59, 32, 99, 104, 97, 114, 115, 101, 116, 61, 117, 116, 102, 45, 56]

def text_spec(-Vars: Data, c: Ctx<Vars>, value: String) -> Response.Res:
  body(Vars, c, Response.utf8(value), Some{"text/plain; charset=utf-8"})

def text(-Vars: Data, c: Ctx<Vars>, value: String) -> Response.Res:
  body_typed(Vars, c, Response.utf8(value), text_type())

def html_spec(-Vars: Data, c: Ctx<Vars>, value: String) -> Response.Res:
  body(Vars, c, Response.utf8(value), Some{"text/html; charset=utf-8"})

def html(-Vars: Data, c: Ctx<Vars>, value: String) -> Response.Res:
  body_typed(Vars, c, Response.utf8(value), html_type())

def json_result_spec(-Vars: Data, c: Ctx<Vars>, result: Result<&2, &2, Json.Error, String>) -> Response.Res:
  match result:
    case Fail{error}: Response.body(500, [], [])
    case Done{s}: body(Vars, c, Response.utf8(s), Some{"application/json; charset=utf-8"})

def json_result(-Vars: Data, c: Ctx<Vars>, result: Result<&2, &2, Json.Error, String>) -> Response.Res:
  match result:
    case Fail{error}: Response.body(500, [], [])
    case Done{s}: body_typed(Vars, c, Response.utf8(s), json_type())

def json(-Vars: Data, c: Ctx<Vars>, value: Json.Json) -> Response.Res:
  json_result(Vars, c, Json.stringify(value))

def redirect_valid(-Vars: Data, c: Ctx<Vars>, location: String, code: U32, valid: Bool) -> Response.Res:
  match valid:
    case False{}: Response.body(500, [], [])
    case True{}: body(Vars, header(Vars, status(Vars, c, code), "location", location), [], None{})

def redirect_status(-Vars: Data, c: Ctx<Vars>, location: String, +code: U32) -> Response.Res:
  redirect_valid(Vars, c, location, code, U32.is_eq(code, 301) || U32.is_eq(code, 302) || U32.is_eq(code, 303) || U32.is_eq(code, 307) || U32.is_eq(code, 308))

def redirect(-Vars: Data, c: Ctx<Vars>, location: String) -> Response.Res:
  redirect_status(Vars, c, location, 302)

# The exact text Json.stringify writes for {"error": message, "status": code},
# with the writer's own escaping. The status digits match the status line.
def error_json(message: String, code: U32) -> String:
  "{\"error\":" ++ Json.quote(message, False{}) ++ ",\"status\":" ++ Nat.show(U32.to_nat(code)) ++ "}"

# Errors validate the headers the client receives: the accumulated headers
# after the Vary merge, with the negotiated Content-Type in place of any other.
def respond(-Vars: Data, c: Ctx<Vars>, bytes: List<&2, U32>, content_type: String) -> Response.Res:
  Ctx{r, p, b, q, s, hs, v, o} = c
  finalize(Response.body(s, type_headers(hs, Some{content_type}), bytes))

# Like Json.stringify, a message with a non-scalar Char renders the empty 500.
def error_json_body(-Vars: Data, c: Ctx<Vars>, +code: U32, +message: String, scalars: Bool) -> Response.Res:
  match scalars:
    case True{}:
      respond(Vars, status(Vars, c, code), Response.utf8(error_json(message, code)), "application/json; charset=utf-8")
    case False{}: Response.body(500, [], [])

def error_body(-Vars: Data, c: Ctx<Vars>, +code: U32, +message: String, json_body: Bool) -> Response.Res:
  match json_body:
    case True{}: error_json_body(Vars, c, code, message, Json.scalars(message))
    case False{}: respond(Vars, status(Vars, c, code), Response.utf8(message), "text/plain; charset=utf-8")

# Existing Vary values are copied byte for byte, then Accept is appended.
def vary_join(values: List<&2, List<&2, U32>>) -> List<&2, U32>:
  match values:
    case Nil{}: Bytes.encode("Accept")
    case value <> tail: List.append(&2, U32, value, List.append(&2, U32, Bytes.encode(", "), vary_join(tail)))

# Scan a Vary value: only whitespace so far, exactly one * among whitespace,
# or anything else.
type Wild is Data:
  Blank{}
  Star{}
  Other{}

def wild_char(blank: Bool, star: Bool, state: Wild) -> Wild:
  match blank star state:
    case True{} _ s: s
    case False{} True{} Blank{}: Star{}
    case False{} _ _: Other{}

def wild_go(xs: List<&2, U32>, state: Wild) -> Wild:
  match xs:
    case Nil{}: state
    case +c <> t: wild_go(t, wild_char(Bytes.ows(c), U32.is_eq(c, 42), state))

def wild_end(state: Wild) -> Bool:
  match state:
    case Star{}: True{}
    case _: False{}

def vary_wild(xs: List<&2, U32>) -> Bool:
  wild_end(wild_go(xs, Blank{}))

def vary_star(values: List<&2, List<&2, U32>>) -> Bool:
  match values:
    case Nil{}: False{}
    case value <> tail: vary_wild(value) || vary_star(tail)

def vary_value(values: List<&2, List<&2, U32>>, star: Bool) -> List<&2, U32>:
  match star:
    case True{}: Bytes.encode("*")
    case False{}: vary_join(values)

# Every Vary field becomes one field at the end; Vary: * stays *.
def vary_accept(-Vars: Data, c: Ctx<Vars>) -> Ctx<Vars>:
  Ctx{r, p, b, q, s, +hs, v, o} = c
  +values = Request.lookup(hs, "vary")
  Ctx{r, p, b, q, s, List.append(&2, Request.Header, without(hs, "vary"), [Request.Header{"vary", vary_value(values, vary_star(values))}]), v, o}

def error(-Vars: Data, +c: Ctx<Vars>, +failure: Errors.HttpError) -> Response.Res:
  Errors.HttpError{code, internal, expose} = failure
  error_body(Vars, vary_accept(Vars, c), Errors.status(code), Errors.message(failure), Errors.accepts_json(request_header(Vars, c, "accept")))

def result(-Vars: Data, c: Ctx<Vars>, value: Result<&2, &2, Errors.HttpError, Response.Res>) -> Response.Res:
  match value:
    case Done{res}: res
    case Fail{failure}: error(Vars, c, failure)

def not_found(-Vars: Data, c: Ctx<Vars>) -> Response.Res:
  error(Vars, c, Errors.http_error(404, "Not Found"))

# Framework metadata is independent of the app-owned Vars record.
def observation(-Vars: Data, c: Ctx<Vars>) -> Obs.State:
  Ctx{r, p, b, q, s, hs, v, o} = c
  o

def with_observation(-Vars: Data, c: Ctx<Vars>, o: Obs.State) -> Ctx<Vars>:
  Ctx{r, p, b, q, s, hs, v, old} = c
  Ctx{r, p, b, q, s, hs, v, o}

def request_id(-Vars: Data, c: Ctx<Vars>) -> Maybe<&2, String>:
  Obs.id(observation(Vars, c))

# The socket peer (getpeername), never a client-supplied header. None when the
# request did not arrive over a socket (B.handle_with) or the lookup failed.
def conn_info(-Vars: Data, c: Ctx<Vars>) -> Maybe<&2, Conn.ConnInfo>:
  Obs.peer(observation(Vars, c))

# Cookie fields are parsed separately, in arrival order, without comma joining.
def cookie_ascii_go(bytes: List<&2, U32>, acc: String) -> String:
  match bytes:
    case Nil{}: String.reverse(acc)
    case h <> t: cookie_ascii_go(t, SCon{Chr{h}, acc})

def cookie_fields_go(fields: List<&2, List<&2, U32>>, acc: List<&2, Cookie.Entry>) -> List<&2, Cookie.Entry>:
  match fields:
    case Nil{}: List.reverse(&2, Cookie.Entry, acc)
    case bytes <> tail:
      cookie_fields_go(tail, List.reverse.go(&2, Cookie.Entry, Cookie.parse(cookie_ascii_go(bytes, "")), acc))

def cookie_fields(fields: List<&2, List<&2, U32>>) -> List<&2, Cookie.Entry>:
  cookie_fields_go(fields, [])

def cookie_headers_go(headers: List<&2, Request.Header>, acc: List<&2, List<&2, U32>>) -> List<&2, List<&2, U32>>:
  match headers:
    case Nil{}: List.reverse(&2, List<&2, U32>, acc)
    case Request.Header{name, value} <> tail:
      cookie_headers_go(tail, Request.lookup_step(value, acc, String.eq(name, "cookie")))

def cookies(-Vars: Data, c: Ctx<Vars>) -> List<&2, Cookie.Entry>:
  Ctx{Request.Req{m, p, q, ver, hs}, ps, b, pairs, s, out, v, o} = c
  cookie_fields(cookie_headers_go(hs, []))

def cookie(-Vars: Data, c: Ctx<Vars>, name: String) -> Maybe<&2, String>:
  Cookie.first(cookies(Vars, c), name)

def cookie_result(-Vars: Data, c: Ctx<Vars>, result: Result<&2, &2, Cookie.Error, String>) -> Result<&2, &2, Cookie.Error, Ctx<Vars>>:
  Ctx{r, p, b, q, s, hs, v, o} = c
  match result:
    case Fail{error}: Fail{error}
    case Done{value}:
      Done{Ctx{r, p, b, q, s, List.append(&2, Request.Header, hs, [Request.Header{"set-cookie", Response.utf8(value)}]), v, o}}

def set_cookie(-Vars: Data, c: Ctx<Vars>, name: String, value: String, options: Cookie.Options) -> Result<&2, &2, Cookie.Error, Ctx<Vars>>:
  cookie_result(Vars, c, Cookie.serialize(name, value, options))

def delete_cookie(-Vars: Data, c: Ctx<Vars>, name: String, options: Cookie.Options) -> Result<&2, &2, Cookie.Error, Ctx<Vars>>:
  set_cookie(Vars, c, name, "", Cookie.deletion(options))

# Signed-cookie setters share the ordinary cookie response/error path.
def set_signed_cookie(-Vars: Data, c: Ctx<Vars>, name: String, value: String, keys: SignedCookie.Keys, options: Cookie.Options) -> Result<&2, &2, Cookie.Error, Ctx<Vars>>:
  cookie_result(Vars, c, SignedCookie.serialize(name, value, keys, options))

def signed_cookie(-Vars: Data, c: Ctx<Vars>, name: String, keys: SignedCookie.Keys) -> Maybe<&2, String>:
  SignedCookie.read(keys, cookie(Vars, c, name))

# Values the route's schemas decoded (BND-36), read without parsing again.
# Each is None when the route declares no schema for that slot.
def values_of(found: Maybe<&2, V.Values>) -> V.Values:
  match found:
    case None{}: V.no_values()
    case Some{v}: v

def values(-Vars: Data, c: Ctx<Vars>) -> V.Values:
  values_of(Obs.valid(observation(Vars, c)))

def with_values(-Vars: Data, c: Ctx<Vars>, v: V.Values) -> Ctx<Vars>:
  Ctx{r, p, b, q, s, hs, vars, o} = c
  Ctx{r, p, b, q, s, hs, vars, Obs.with_valid(o, v)}

def valid_params(-Vars: Data, c: Ctx<Vars>) -> Maybe<&2, Schema.Value>:
  V.params_value(values(Vars, c))

def valid_query(-Vars: Data, c: Ctx<Vars>) -> Maybe<&2, Schema.Value>:
  V.query_value(values(Vars, c))

def valid_headers(-Vars: Data, c: Ctx<Vars>) -> Maybe<&2, Schema.Value>:
  V.headers_value(values(Vars, c))

def valid_body(-Vars: Data, c: Ctx<Vars>) -> Maybe<&2, Schema.Value>:
  V.body_value(values(Vars, c))

def json_rejected(-Vars: Data, c: Ctx<Vars>, +code: U32, text: Result<&2, &2, Json.Error, String>) -> Response.Res:
  match text:
    case Done{s}: respond(Vars, status(Vars, c, code), Response.utf8(s), "application/json; charset=utf-8")
    case Fail{e}: error(Vars, c, Errors.http_error(code, ""))

# What validation reads: route params, query pairs, headers and the raw body.
def validation_input(-Vars: Data, c: Ctx<Vars>) -> V.Input:
  Ctx{Request.Req{m, p, q, ver, hs}, ps, b, pairs, s, out, v, o} = c
  V.Input{ps, pairs, hs, b}

# The request validation failed: a JSON list of every failing path.
def rejected(-Vars: Data, c: Ctx<Vars>, +code: U32, errors: List<&2, Schema.Error>) -> Response.Res:
  json_rejected(Vars, c, code, Json.stringify(V.rejection(code, Response.reason(code), errors)))

# How a request enters its handler (BND-36). A valid verdict dispatches with
# exactly the verdict's values in the context; an invalid one answers the
# rejection, and nothing is dispatched.
type Entry<-Vars: Data> is Data:
  EnterHandler{ctx: Ctx<Vars>}
  RejectRequest{res: Response.Res}

def entry(-Vars: Data, +c: Ctx<Vars>, verdict: V.Verdict) -> Entry<Vars>:
  match verdict:
    case V.Valid{values}: EnterHandler{with_values(Vars, c, values)}
    case V.Invalid{code, errors}: RejectRequest{rejected(Vars, c, code, errors)}

def enters(-Vars: Data, e: Entry<Vars>) -> Bool:
  match e:
    case EnterHandler{c}: True{}
    case RejectRequest{res}: False{}
