import Base
import ../../src/main.bend as B
import ../../src/app/context.bend as C
import ../../src/router/methods.bend as M

type Tag is Data:
  Home{}
  Say{word: String}
  Stamp{name: String, value: String}

def handler(tag: Tag, c: B.Context(Unit), env: Unit) -> IO(B.Res):
  match tag:
    case Say{word}: IO.pure(B.Res, C.text(Unit, c, word))
    case _: IO.pure(B.Res, C.text(Unit, c, "home"))

def middleware(tag: Tag, c: B.Context(Unit), env: Unit, next: B.Context(Unit) -> IO(B.Res)) -> IO(B.Res):
  match tag:
    case Stamp{name, value}: next(C.header(Unit, c, name, value))
    case _: next(c)

# A configurable named plugin: a route and a global before-handle hook.
def greeting(word: String, app: B.Builder(Tag)) -> B.Builder(Tag):
  B.named(Tag, B.plugin_id("greeting"), app, a => B.register(Tag, a, [
    B.get(Tag, "/hello", Say{word}),
    B.before_handle(Tag, Stamp{"x-greeting", "yes"})]))

# A named plugin that depends on greeting and adds middleware.
def health(app: B.Builder(Tag)) -> B.Builder(Tag):
  B.named(Tag, B.plugin_id("health"), app, a => B.register(Tag, greeting("hi", a), [
    B.get(Tag, "/health", Say{"ok"}),
    B.use(Tag, Stamp{"x-health", "yes"})]))

def assembled() -> B.Builder(Tag):
  greeting("again", B.use_plugin(Tag, B.use_plugin(Tag, B.app_from(Tag, [B.get(Tag, "/", Home{})]), health), health))

def ready(result: Result<&2, &2, M.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "invalid routes")
    case Done{table}:
      B.serve_with(~Unit, ~Tag, ~Unit, ~handler, ~middleware, table, Unit{}, B.config())

def main() -> IO(Unit):
  ready(B.app_routes(Tag, assembled()))
