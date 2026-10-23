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

import ../data/cookie.bend as Cookie

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

def text(-Vars: Data, c: Ctx<Vars>, value: String) -> Response.Res:
  body(Vars, c, Response.utf8(value), Some{"text/plain; charset=utf-8"})

def html(-Vars: Data, c: Ctx<Vars>, value: String) -> Response.Res:
  body(Vars, c, Response.utf8(value), Some{"text/html; charset=utf-8"})

def json_result(-Vars: Data, c: Ctx<Vars>, result: Result<&2, &2, Json.Error, String>) -> Response.Res:
  match result:
    case Fail{error}: Response.body(500, [], [])
    case Done{s}: body(Vars, c, Response.utf8(s), Some{"application/json; charset=utf-8"})

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

def not_found(-Vars: Data, c: Ctx<Vars>) -> Response.Res:
  text(Vars, status(Vars, c, 404), "Not Found")

# Framework metadata is independent of the app-owned Vars record.
def observation(-Vars: Data, c: Ctx<Vars>) -> Obs.State:
  Ctx{r, p, b, q, s, hs, v, o} = c
  o

def with_observation(-Vars: Data, c: Ctx<Vars>, o: Obs.State) -> Ctx<Vars>:
  Ctx{r, p, b, q, s, hs, v, old} = c
  Ctx{r, p, b, q, s, hs, v, o}

def request_id(-Vars: Data, c: Ctx<Vars>) -> Maybe<&2, String>:
  Obs.id(observation(Vars, c))

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
