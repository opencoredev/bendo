# Immutable request state. Vars is app-owned copyable data, never a dynamic map.
import Base
import ../http/request.bend as Request
import ../http/response.bend as Response
import ../http/bytes.bend as Bytes
import ../router/pattern.bend as Pattern
import ../data/urlencoded.bend as Query
import ../data/utf8.bend as Utf8
import ../data/json.bend as Json

type Ctx<-Vars: Data> is Data:
  Ctx{req: Request.Req, params: Pattern.Params, body: List<&2, U32>, pairs: List<&2, Query.Entry>, code: U32, headers: List<&2, Request.Header>, vars: Maybe<&2, Vars>}

def query_pairs(q: Maybe<&2, String>) -> Result<&2, &2, Query.Error, List<&2, Query.Entry>>:
  match q:
    case None{}: Done{[]}
    case Some{s}: Query.parse_pairs(s)

def create(req: Request.Req, params: Pattern.Params, body: List<&2, U32>, pairs: List<&2, Query.Entry>) -> Ctx<Unit>:
  Ctx{req, params, body, pairs, 200, [], None{}}

def variables(-Vars: Data, c: Ctx<Unit>) -> Ctx<Vars>:
  Ctx{r, p, b, q, s, hs, v} = c
  Ctx{r, p, b, q, s, hs, None{}}

def set(-Vars: Data, c: Ctx<Vars>, value: Vars) -> Ctx<Vars>:
  Ctx{r, p, b, q, s, hs, v} = c
  Ctx{r, p, b, q, s, hs, Some{value}}

def get(-Vars: Data, c: Ctx<Vars>) -> Maybe<&2, Vars>:
  Ctx{r, p, b, q, s, hs, v} = c
  v

def request(-Vars: Data, c: Ctx<Vars>) -> Request.Req:
  Ctx{r, p, b, q, s, hs, v} = c
  r

# Request-stage rewrites preserve buffered body/query data; route captures are
# recomputed after the request hook chain has finished.
def rewrite(-Vars: Data, c: Ctx<Vars>, method: Request.Method, path: String) -> Ctx<Vars>:
  Ctx{Request.Req{old_method, old_path, query, version, hs}, ps, body, pairs, code, headers, vars} = c
  Ctx{Request.Req{method, path, query, version, hs}, [], body, pairs, code, headers, vars}

def raw_body(-Vars: Data, c: Ctx<Vars>) -> List<&2, U32>:
  Ctx{r, p, b, q, s, hs, v} = c
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
  Ctx{r, p, b, q, s, hs, v} = c
  param_go(p, name)

def query(-Vars: Data, c: Ctx<Vars>, name: String) -> Maybe<&2, String>:
  Ctx{r, p, b, q, s, hs, v} = c
  Query.query(q, name)

def queries(-Vars: Data, c: Ctx<Vars>, name: String) -> List<&2, String>:
  Ctx{r, p, b, q, s, hs, v} = c
  Query.queries(q, name)

def header_bytes(-Vars: Data, c: Ctx<Vars>, name: String) -> List<&2, List<&2, U32>>:
  Ctx{Request.Req{m, p, q, ver, hs}, ps, b, pairs, s, out, v} = c
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
  Ctx{Request.Req{m, p, q, ver, hs}, ps, b, pairs, s, out, v} = c
  m

def path(-Vars: Data, c: Ctx<Vars>) -> String:
  Ctx{Request.Req{m, p, q, ver, hs}, ps, b, pairs, s, out, v} = c
  p

def url(-Vars: Data, c: Ctx<Vars>) -> String:
  Request.target(request(Vars, c))

def status(-Vars: Data, c: Ctx<Vars>, code: U32) -> Ctx<Vars>:
  Ctx{r, p, b, q, s, hs, v} = c
  Ctx{r, p, b, q, code, hs, v}

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
  Ctx{r, p, b, q, s, hs, v} = c
  +key = Bytes.fold(name)
  Ctx{r, p, b, q, s, List.append(&2, Request.Header, without(hs, key), [Request.Header{key, Response.utf8(value)}]), v}

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
  Ctx{r, p, b, q, s, hs, v} = c
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
