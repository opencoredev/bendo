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
  SecureFirst{}
  SecureLast{}
  Recover{}
  Map{}
  Error{code: U32}
  Invalid{}
  Star{}
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
    Request.Header{"Vary", Response.utf8("Accept")},
    Request.Header{"access-control-allow-origin", Response.utf8("https://evil.example")},
    Request.Header{"Access-Control-Allow-Origin", Response.utf8("https://other.example")},
    Request.Header{"Access-Control-Allow-Methods", Response.utf8("DELETE")},
    Request.Header{"access-control-allow-headers", Response.utf8("x-secret")},
    Request.Header{"access-control-max-age", Response.utf8("999")},
    Request.Header{"access-control-expose-headers", Response.utf8("x-secret")},
    Request.Header{"vary", Response.utf8("accept-encoding, origin")},
    Request.Header{"access-control-allow-credentials", Response.utf8("true")},
    Request.Header{"content-type", Response.utf8("text/plain; charset=utf-8")}
  ], Response.utf8("conflict"))

def handle(tag: Tag, +c: B.Context(Unit)) -> B.Res:
  match tag:
    case Error{code}: C.error(Unit, c, B.http_error(code, "handler error"))
    case Invalid{}: Response.body(200, [Request.Header{"x-invalid", [10]}], [])
    case Star{}: C.text(Unit, C.header(Unit, c, "vary", "*"), "star")
    case Conflict{}: conflict()
    case AppOptions{}: C.text(Unit, c, "app options")
    case Method{}: C.text(Unit, c, "method:" ++ Request.method_text(C.method(Unit, c)) ++ " body:" ++ text(Utf8.decode(C.raw_body(Unit, c)), "?"))
    case Browser{}: C.text(Unit, c, "browser " ++ Request.method_text(C.method(Unit, c)) ++ " cookie=" ++ text(C.cookie(Unit, c, "bnd40"), "none"))
    case Powered{}: C.text(Unit, C.header(Unit, c, "x-frame-options", "ALLOWALL"), "powered")
    case _: C.text(Unit, c, "ok")

def handler(tag: Tag, c: B.Context(Unit), env: Unit) -> IO(B.Res):
  IO.pure(B.Res, handle(tag, c))

def recovery(+c: B.Context(Unit), next: B.Context(Unit) -> IO(B.Res), path: String) -> IO(B.Res):
  match path:
    case "/final/error4": IO.pure(B.Res, C.error(Unit, c, B.http_error(422, "rendered error")))
    case "/final/error5": IO.pure(B.Res, C.error(Unit, c, B.http_error(503, "hidden diagnostic")))
    case "/browser/error": IO.pure(B.Res, C.error(Unit, c, B.http_error(422, "readable error")))
    case "/final/missing": IO.pure(B.Res, C.error(Unit, c, B.http_error(404, "rendered miss")))
    case "/final/method": IO.pure(B.Res, C.error(Unit, c, B.http_error(405, "rendered method")))
    case "/final/invalid-recovery": IO.pure(B.Res, Response.body(200, [Request.Header{"x-invalid", [10]}], []))
    case _: next(c)

def mapped(+c: B.Context(Unit), next: B.Context(Unit) -> IO(B.Res), path: String) -> IO(B.Res):
  match path:
    case "/final/map": IO.pure(B.Res, C.text(Unit, c, "replacement"))
    case _: next(c)

def recover_for(+c: B.Context(Unit), next: B.Context(Unit) -> IO(B.Res)) -> IO(B.Res):
  recovery(c, next, C.path(Unit, c))

def map_for(+c: B.Context(Unit), next: B.Context(Unit) -> IO(B.Res)) -> IO(B.Res):
  mapped(c, next, C.path(Unit, c))

def secure_hook(c: B.Context(Unit), next: B.Context(Unit) -> IO(B.Res), value: String, here: Bool) -> IO(B.Res):
  match here:
    case False{}: next(c)
    case True{}: B.builtin(Unit, B.secure_headers_with(B.secure_set(B.secure_defaults(), "x-frame-options", value)), c, next)

def secure_hook_for(+c: B.Context(Unit), next: B.Context(Unit) -> IO(B.Res), value: String) -> IO(B.Res):
  secure_hook(c, next, value, String.eq(C.path(Unit, c), "/final/hook-order"))

def middleware(tag: Tag, c: B.Context(Unit), env: Unit, next: B.Context(Unit) -> IO(B.Res)) -> IO(B.Res):
  match tag:
    case SecureFirst{}: secure_hook_for(c, next, "SAMEORIGIN")
    case SecureLast{}: secure_hook_for(c, next, "DENY")
    case Recover{}: recover_for(c, next)
    case Map{}: map_for(c, next)
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

def app(checked: B.CorsConfig) -> IO(Unit):
  ready(B.routes(Tag, [
    B.use_path(Tag, "/checked/*", Builtin{B.cors(checked)}),
    B.get(Tag, "/checked/data", Hello{}),
    B.on_error(Tag, Recover{}),
    B.map_response(Tag, Map{}),
    B.map_response(Tag, SecureFirst{}),
    B.map_response(Tag, SecureLast{}),
    B.use_path(Tag, "/final/*", Builtin{B.cors(api())}),
    B.use_path(Tag, "/final/*", Builtin{B.secure_headers()}),
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
    B.use_path(Tag, "/final/bad-config", Builtin{B.request_id()}),
    B.use_path(Tag, "/final/bad-config", Builtin{B.server_timing()}),
    B.use_path(Tag, "/final/bad-config", Builtin{B.secure_headers_with(B.secure_set(B.secure_defaults(), "x-test", "a\nb"))}),
    B.get(Tag, "/final/bad-config", Hello{}),
    B.get(Tag, "/final/hook-order", Hello{}),
    B.use_path(Tag, "/powered-remove", Builtin{B.secure_headers_with(B.secure_set(B.secure_defaults(), "X-Powered-By", "secret"))}),
    B.get(Tag, "/powered-remove", Hello{}),
    B.get(Tag, "/final/error4", Error{422}),
    B.get(Tag, "/final/error5", Error{503}),
    B.get(Tag, "/final/method", Hello{}),
    B.get(Tag, "/final/map", Hello{}),
    B.get(Tag, "/final/invalid", Invalid{}),
    B.get(Tag, "/final/invalid-recovery", Error{500}),
    B.get(Tag, "/final/star", Star{}),
    B.get(Tag, "/browser/error", Error{422}),
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

# The checked builder reports the two entries it drops on stderr at startup.
def main() -> IO(Unit):
  do IO<Unit>:
    checked : B.CorsConfig <- B.cors_allow_checked([B.cors_origin("https://checked.example"), B.cors_origin("null"), B.cors_origin("checked.example")])
    app(checked)
