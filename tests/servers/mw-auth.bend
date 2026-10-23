# BND-43 test server: basic auth, bearer auth, JWT and CSRF built-ins.
# Every secret here is a test fixture, not a real credential.
import Base
import ../../src/main.bend as B
import ../../src/app/context.bend as C
import ../../src/data/json.bend as Json
import ../../src/http/response.bend as Response
import ../../src/http/request.bend as Request
import ../../src/router/methods.bend as Methods

type Vars is Data:
  Vars{claims: String}

type Tag is Data:
  Hello{}
  Me{}
  Sign{}
  Claims{}
  Skewed{}
  Builtin{id: B.Builtin}

def secret() -> String: "bendo-test-secret-not-real"

def claims_text(result: Result<&2, &2, Json.Error, String>) -> String:
  match result:
    case Fail{e}: ""
    case Done{s}: s

def signed(c: B.Context(Vars), result: Result<&2, &2, B.JwtError, String>) -> B.Res:
  match result:
    case Fail{e}: Response.text(400, "cannot sign")
    case Done{token}: C.text(Vars, c, token)

def sign_body(c: B.Context(Vars), parsed: Result<&2, &2, Json.Error, Json.Json>) -> B.Res:
  match parsed:
    case Fail{e}: Response.text(400, "bad json")
    case Done{claims}: signed(c, B.jwt_sign(secret(), claims))

def stored(v: Maybe<&2, Vars>) -> String:
  match v:
    case None{}: "none"
    case Some{Vars{claims}}: claims

def handle(tag: Tag, +c: B.Context(Vars)) -> IO(B.Res):
  match tag:
    case Me{}: IO.pure(B.Res, C.text(Vars, c, stored(C.get(Vars, c))))
    case Sign{}: IO.pure(B.Res, sign_body(c, Json.parse(C.raw_body(Vars, c))))
    case _: IO.pure(B.Res, C.text(Vars, c, "ok:" ++ Request.method_text(C.method(Vars, c))))

def handler(tag: Tag, c: B.Context(Vars), env: Unit) -> IO(B.Res):
  handle(tag, c)

def claims(c: B.Context(Vars), next: B.Context(Vars) -> IO(B.Res), leeway: Nat) -> IO(B.Res):
  B.jwt_with(Vars, B.jwt_config(secret(), leeway, "jwt"), c, value => ctx => next(C.set(Vars, ctx, Vars{claims_text(Json.stringify(value))})))

def middleware(tag: Tag, c: B.Context(Vars), env: Unit, next: B.Context(Vars) -> IO(B.Res)) -> IO(B.Res):
  match tag:
    case Builtin{id}: B.builtin(Vars, id, c, next)
    case Claims{}: claims(c, next, 0n)
    case Skewed{}: claims(c, next, 60n)
    case _: next(c)

def ready(result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "invalid routes")
    case Done{table}: B.serve_with(~Vars, ~Tag, ~Unit, ~handler, ~middleware, table, Unit{}, B.config())

def main() -> IO(Unit):
  ready(B.routes(Tag, [
    B.use_path(Tag, "/basic/*", Builtin{B.basic_auth("Bendo \"test\" \\ realm", [B.credential("ada", "pa:ss:word"), B.credential("José", "pässwörd")])}),
    B.use_path(Tag, "/bearer/*", Builtin{B.bearer_auth("api", ["abc.DEF-123_~+/=", "second-token"])}),
    B.use_path(Tag, "/jwt/*", Claims{}),
    B.use_path(Tag, "/jwt-plain/*", Builtin{B.jwt(B.jwt_config(secret(), 0n, "plain"))}),
    B.use_path(Tag, "/jwt-skew/*", Skewed{}),
    B.use_path(Tag, "/csrf/*", Builtin{B.csrf_host("http", ["https://trusted.example"])}),
    B.use_path(Tag, "/csrf-https/*", Builtin{B.csrf_host("HTTPS", ["https://Trusted.Example:443/login", "http://[::1]:8080", "not an origin"])}),
    B.use_path(Tag, "/csrf-listed/*", Builtin{B.csrf(["https://trusted.example"])}),
    B.get(Tag, "/", Hello{}),
    B.get(Tag, "/basic/ok", Hello{}),
    B.get(Tag, "/bearer/ok", Hello{}),
    B.get(Tag, "/jwt/me", Me{}),
    B.get(Tag, "/jwt-plain/ok", Hello{}),
    B.get(Tag, "/jwt-skew/me", Me{}),
    B.post(Tag, "/sign", Sign{}),
    B.all(Tag, "/csrf/form", Hello{}),
    B.all(Tag, "/csrf-https/form", Hello{}),
    B.all(Tag, "/csrf-listed/form", Hello{})
  ]))
