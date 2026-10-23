# BND-40 test server: CORS, secure headers, method override and trailing
# slash built-ins. PORT=18440 ./fixture serves the /browser routes for the
# manual browser check described in tests/mw-cors.test.ts.
import Base
import ../../src/main.bend as B
import ../../src/app/context.bend as C
import ../../src/data/utf8.bend as Utf8
import ../../src/http/response.bend as Response
import ../../src/http/request.bend as Request
import ../../src/router/methods.bend as Methods

type Tag is Data:
  Hello{}
  Conflict{}
  AppOptions{}
  Method{}
  Browser{}
  Powered{}
  Builtin{id: B.Builtin}

def text(m: Maybe<&2, String>, fallback: String) -> String:
  match m:
    case None{}: fallback
    case Some{s}: s

# Fields a handler might set that the CORS middleware owns or merges.
def conflict() -> B.Res:
  Response.body(200, [
    Request.Header{"vary", Response.utf8("Accept")},
    Request.Header{"access-control-allow-origin", Response.utf8("https://evil.example")},
    Request.Header{"vary", Response.utf8("accept-encoding, origin")},
    Request.Header{"access-control-allow-credentials", Response.utf8("true")},
    Request.Header{"content-type", Response.utf8("text/plain; charset=utf-8")}
  ], Response.utf8("conflict"))

def handle(tag: Tag, +c: B.Context(Unit)) -> B.Res:
  match tag:
    case Conflict{}: conflict()
    case AppOptions{}: C.text(Unit, c, "app options")
    case Method{}: C.text(Unit, c, "method:" ++ Request.method_text(C.method(Unit, c)) ++ " body:" ++ text(Utf8.decode(C.raw_body(Unit, c)), "?"))
    case Browser{}: C.text(Unit, c, "browser " ++ Request.method_text(C.method(Unit, c)) ++ " cookie=" ++ text(C.cookie(Unit, c, "bnd40"), "none"))
    case Powered{}: C.text(Unit, C.header(Unit, c, "x-frame-options", "ALLOWALL"), "powered")
    case _: C.text(Unit, c, "ok")

def handler(tag: Tag, c: B.Context(Unit), env: Unit) -> IO(B.Res):
  IO.pure(B.Res, handle(tag, c))

def middleware(tag: Tag, c: B.Context(Unit), env: Unit, next: B.Context(Unit) -> IO(B.Res)) -> IO(B.Res):
  match tag:
    case Builtin{id}: B.builtin(Unit, id, c, next)
    case _: next(c)

def api() -> B.CorsConfig:
  B.cors_max_age(B.cors_expose(B.cors_headers(B.cors_methods(B.cors_allow([B.cors_origin("https://App.Example:443/login"), B.cors_origin_credentials("http://cred.example:8443"), B.cors_origin("null"), B.cors_origin("*")]), ["GET", "POST", "PUT"]), ["X-Custom", "Content-Type"]), ["X-Total"]), 600n)

def browser() -> B.CorsConfig:
  B.cors_headers(B.cors_methods(B.cors_allow([B.cors_origin_credentials("http://127.0.0.1:18441")]), ["GET", "POST", "PUT"]), ["x-bnd40", "content-type"])

def custom_secure() -> B.SecureConfig:
  B.secure_keep_powered_by(B.secure_unset(B.secure_set(B.secure_set(B.secure_defaults(), "Content-Security-Policy", "default-src 'self'"), "Strict-Transport-Security", "max-age=63072000"), "X-Frame-Options"))

def ready(result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "invalid routes")
    case Done{table}: B.serve_with(~Unit, ~Tag, ~Unit, ~handler, ~middleware, table, Unit{}, B.config())

def main() -> IO(Unit):
  ready(B.routes(Tag, [
    B.on_request(Tag, Builtin{B.method_override()}),
    B.on_request(Tag, Builtin{B.method_override_header("X-HTTP-Method-Override", ["put", "DELETE", "GET", "HEAD", "PURGE"])}),
    B.use(Tag, Builtin{B.trim_trailing_slash()}),
    B.use_path(Tag, "/any/*", Builtin{B.cors(B.cors_defaults())}),
    B.use_path(Tag, "/api/*", Builtin{B.cors(api())}),
    B.use_path(Tag, "/reflect/*", Builtin{B.cors(B.cors_allow([B.cors_origin("https://app.example")]))}),
    B.use_path(Tag, "/browser", Builtin{B.cors(browser())}),
    B.use_path(Tag, "/browser/*", Builtin{B.cors(browser())}),
    B.use_path(Tag, "/secure/*", Builtin{B.secure_headers()}),
    B.use_path(Tag, "/secure/*", Builtin{B.powered_by("Bendo")}),
    B.use_path(Tag, "/secure-custom/*", Builtin{B.secure_headers_with(custom_secure())}),
    B.use_path(Tag, "/secure-custom/*", Builtin{B.powered_by("Bendo")}),
    B.use_path(Tag, "/csrf/*", Builtin{B.csrf(["https://trusted.example"])}),
    B.use_path(Tag, "/append/*", Builtin{B.append_trailing_slash()}),
    B.use_path(Tag, "/append-always/*", Builtin{B.append_trailing_slash_always()}),
    B.use_path(Tag, "/trim-always/*", Builtin{B.trim_trailing_slash_always()}),
    B.get(Tag, "/", Hello{}),
    B.get(Tag, "/any/data", Hello{}),
    B.all(Tag, "/api/data", Hello{}),
    B.get(Tag, "/api/conflict", Conflict{}),
    B.options(Tag, "/api/options", AppOptions{}),
    B.get(Tag, "/reflect/data", Hello{}),
    B.get(Tag, "/browser", Browser{}),
    B.post(Tag, "/browser", Browser{}),
    B.put(Tag, "/browser", Browser{}),
    B.get(Tag, "/secure/page", Hello{}),
    B.get(Tag, "/secure-custom/page", Powered{}),
    B.all(Tag, "/items", Method{}),
    B.put(Tag, "/override-target", Method{}),
    B.all(Tag, "/csrf/items", Method{}),
    B.get(Tag, "/trim/page", Hello{}),
    B.get(Tag, "/append/page/", Hello{}),
    B.get(Tag, "/append-always/page/", Hello{}),
    B.get(Tag, "/trim-always/page", Hello{}),
    B.get(Tag, "/trim-always/page/", Hello{})
  ]))
