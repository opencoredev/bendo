import Base
import ../../src/main.bend as B
import ../../src/app/context.bend as C
import ../../src/app/errors.bend as Errors
import ../../src/http/response.bend as Response
import ../../src/router/methods.bend as Methods

type Tag is Data:
  Handler{}
  Missing{}
  Recover{}
  Builtin{id: B.Builtin}

type Env is Data:
  Env{entered: Chan(Unit), gate: Chan(Unit)}

def respond(+c: B.Ctx, path: String) -> B.Res:
  match path:
    case "/teapot": B.error(c, B.http_error(418, "tea \"only\"\n☕"))
    case "/vary": B.error(B.header(c, "vary", "Origin, Accept-Encoding"), B.http_error(400, "varied"))
    case "/vary-star": B.error(B.header(c, "vary", "*"), B.http_error(400, "varied"))
    case "/result": B.result(c, Fail{B.http_error(418, "result teapot")})
    case "/private": B.error(c, B.http_error(503, "database password=secret stack trace"))
    case "/exposed": B.error(c, Errors.HttpError{503, "Maintenance", True{}})
    case "/invalid": B.error(c, B.http_error(200, "invalid secret"))
    case "/recover": B.error(c, B.http_error(500, "private"))
    case "/handler404": B.error(c, B.http_error(404, "handler missing"))
    case _: B.text(c, "ok")

def handler_path(c: B.Ctx, entered: Chan(Unit), gate: Chan(Unit), path: String) -> IO(B.Res):
  match path:
    case "/crash": IO.die(B.Res, 23, "BND-25 deliberate crash")
    case "/pending":
      do IO<B.Res>:
        sent : Result<&1, &1, Unit, Unit> <- Chan.send(Unit, entered, Unit{})
        released : Maybe<&1, Unit> <- Chan.recv(Unit, gate)
        return B.text(c, "released")
    case "/entered":
      do IO<B.Res>:
        signal : Maybe<&1, Unit> <- Chan.recv(Unit, entered)
        return B.text(c, "entered")
    case _: IO.pure(B.Res, respond(c, path))

def handler_impl(tag: Tag, +c: B.Ctx, env: Env) -> IO(B.Res):
  match tag:
    case Handler{}:
      Env{entered, gate} = env
      handler_path(c, entered, gate, B.path(c))
    case _: IO.pure(B.Res, B.text(c, "unreachable"))

def recover(c: B.Ctx, next: B.Ctx -> IO(B.Res), path: String) -> IO(B.Res):
  match path:
    case "/context-missing": IO.pure(B.Res, B.text(B.status(c, 404), "context visible"))
    case "/recover": IO.pure(B.Res, B.text(B.status(c, 202), "recovered"))
    case _: next(c)

def missing(c: B.Ctx, next: B.Ctx -> IO(B.Res), path: String) -> IO(B.Res):
  match path:
    case "/context-missing": next(B.header(c, "x-context", "forwarded"))
    case "/custom-missing": IO.pure(B.Res, B.text(B.status(c, 404), "custom missing"))
    case _: next(c)

def middleware_impl(tag: Tag, +c: B.Ctx, env: Env, next: B.Ctx -> IO(B.Res)) -> IO(B.Res):
  match tag:
    case Missing{}: missing(c, next, B.path(c))
    case Recover{}: recover(c, next, B.path(c))
    case Builtin{id}: B.builtin(Unit, id, c, next)
    case _: next(c)

def handler(tag: Tag, c: B.Ctx, env: Env) -> IO(B.Res):
  handler_impl(tag, c, env)

def middleware(tag: Tag, c: B.Ctx, env: Env, next: B.Ctx -> IO(B.Res)) -> IO(B.Res):
  middleware_impl(tag, c, env, next)

def ready(result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{e}: IO.die(Unit, 1, "invalid routes")
    case Done{table}:
      do IO<Unit>:
        entered : Chan(Unit) <- Chan.new(Unit, 1)
        gate : Chan(Unit) <- Chan.new(Unit, 1)
        B.serve_with(~Unit, ~Tag, ~Env, ~handler, ~middleware, table, Env{entered, gate}, B.config())

def main() -> IO(Unit):
  ready(B.routes(Tag, [
    B.use(Tag, Builtin{B.request_id()}), B.use(Tag, Builtin{B.server_timing()}),
    B.on_error(Tag, Recover{}), B.on_not_found(Tag, Missing{}),
    B.get(Tag, "/vary", Handler{}), B.get(Tag, "/vary-star", Handler{}), B.get(Tag, "/", Handler{}), B.get(Tag, "/teapot", Handler{}),
    B.get(Tag, "/result", Handler{}), B.get(Tag, "/private", Handler{}),
    B.get(Tag, "/exposed", Handler{}), B.get(Tag, "/invalid", Handler{}),
    B.get(Tag, "/recover", Handler{}), B.get(Tag, "/handler404", Handler{}),
    B.get(Tag, "/crash", Handler{}), B.get(Tag, "/pending", Handler{}),
    B.get(Tag, "/entered", Handler{})
  ]))
