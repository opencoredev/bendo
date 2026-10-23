import Base
import ../src/main.bend as B
import ../src/app/context.bend as Context
import ../src/app/manifest.bend as Manifest
import ../src/app/config.bend as Config
import ../src/router/methods.bend as Methods
import ../src/router/router.bend as Router
import ../src/router/pattern.bend as Pattern
import ../src/http/request.bend as Request
import ../src/http/response.bend as Response
import ../src/http/bytes.bend as Bytes

type Tag is Data:
  Todo{}
  Broken{}

type Env is Data:
  Env{prefix: String}

def params(xs: Pattern.Params) -> String:
  match xs:
    case Nil{}: ""
    case Pattern.Param{name, value} <> tail: name ++ "=" ++ value ++ params(tail)

def dispatch(tag: Tag, ctx: B.Ctx, env: Env) -> IO(B.Res):
  match tag ctx env:
    case Todo{} Context.Ctx{req, ps, body, pairs, code, headers, vars} Env{prefix}:
      IO.pure(B.Res, Response.text(200, prefix ++ params(ps) ++ ":" ++ Bytes.ascii(body)))
    case Broken{} _ _:
      IO.pure(B.Res, Response.body(200, [Request.Header{"bad", [13, 10]}], []))

def assert(ok: Bool, message: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ message)
    case False{}: IO.die(Unit, 1, message)

def one_value(xs: List<&2, List<&2, U32>>, expected: String) -> Bool:
  match xs:
    case value <> Nil{}: String.eq(Bytes.ascii(value), expected)
    case _: False{}

def check(res: B.Res, expected_status: U32, expected_body: String, expected_length: String, allow: String) -> IO(Unit):
  Response.Res{status, +hs, body, rep} = res
  do IO<Unit>:
    assert(U32.is_eq(status, expected_status), "status")
    assert(String.eq(Bytes.ascii(body), expected_body), "body")
    assert(one_value(Request.lookup(hs, "content-length"), expected_length), "content-length")
    assert(String.eq(Bytes.ascii(List.concat(&2, U32, Request.lookup(hs, "allow"))), allow), "allow")

def request(method: Request.Method, path: String) -> B.Req:
  Request.Req{method, path, None{}, Request.Http11{}, []}

def run_case(table: B.Routes(Tag), method: Request.Method, path: String, status: U32, body: String, length: String, allow: String) -> IO(Unit):
  do IO<Unit>:
    response : B.Res <- B.handle(~Tag, ~Env, ~dispatch, table, Env{"env:"}, request(method, path), Bytes.encode("input"))
    check(response, status, body, length, allow)

def ready(result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "table build failed")
    case Done{+table}:
      do IO<Unit>:
        run_case(table, Request.Get{}, "/todos/42", 200, "env:id=42:input", "15", "")
        run_case(table, Request.Get{}, "/missing", 404, "Not Found", "9", "")
        run_case(table, Request.Post{}, "/todos/42", 405, "", "0", "GET, HEAD")
        run_case(table, Request.Head{}, "/todos/42", 200, "", "15", "")
        run_case(table, Request.Head{}, "/missing", 404, "", "9", "")
        run_case(table, Request.Get{}, "/broken", 500, "", "0", "")
        IO.print(Manifest.json(Tag, table))

def trie_kind(kind: B.RouterKind) -> Bool:
  match kind:
    case Router.Trie{}: True{}
    case Router.Spec{}: False{}

def defaults(config: B.ServerConfig) -> IO(Unit):
  Config.Config{host, port, body, header, idle, head, read_body, max_requests, alive, router} = config
  assert(String.eq(host, "127.0.0.1") && U32.is_eq(port, 8787) && U32.is_eq(body, 1048576) && U32.is_eq(header, 65536) && U32.is_eq(idle, 5000) && U32.is_eq(head, 10000) && U32.is_eq(read_body, 30000) && U32.is_eq(max_requests, 100) && alive && trie_kind(router), "config defaults")

def main() -> IO(Unit):
  do IO<Unit>:
    defaults(B.config())
    assert(U32.is_eq(Config.port("12345", 8787), 12345) && U32.is_eq(Config.port("00080", 8787), 80) && U32.is_eq(Config.port("65535", 8787), 65535), "PORT valid overrides")
    assert(U32.is_eq(Config.port("0", 8787), 8787) && U32.is_eq(Config.port("65536", 8787), 8787) && U32.is_eq(Config.port("4294967296", 8787), 8787) && U32.is_eq(Config.port("1:", 8787), 8787) && U32.is_eq(Config.port("-1", 8787), 8787) && U32.is_eq(Config.port("", 8787), 8787), "PORT invalid falls back")
    assert(String.eq(Manifest.quote("\"\\\n\t"), "\"\\\"\\\\\\u000a\\u0009\""), "JSON escaping")
    assert(Result.is_fail(&2, &2, Methods.BuildError, B.Routes(Tag), B.routes(Tag, [B.on(Tag, [Request.Extension{"BAD TOKEN"}], "/invalid", Todo{})])), "invalid method rejected")
    ready(B.routes(Tag, [B.on(Tag, [Request.Extension{"GET"}], "/todos/:id{int}", Todo{}), B.get(Tag, "/broken", Broken{}), B.on(Tag, [Request.Extension{"X-TOKEN"}], "/escaped/%22", Todo{})]))
