# GET /middleware behind five onion middleware, outermost first (BND-67):
# a pass-through timer, CORS, secure headers, request ID and a custom header.
import Base
import ../../src/main.bend as B
import ../../src/app/context.bend as C
import ../../src/mw/common.bend as Common
import ../../src/router/methods.bend as Methods

type Tag is Data:
  Hello{}
  Timing{}
  Custom{}
  Builtin{id: B.Builtin}

def dispatch(tag: Tag, c: B.Context(Unit), env: Unit) -> IO(B.Res):
  IO.pure(B.Res, C.text(Unit, c, "Hello, world!"))

# Reads the monotonic clock around the rest of the chain and records nothing.
def timing(c: B.Context(Unit), next: B.Context(Unit) -> IO(B.Res)) -> IO(B.Res):
  do IO<B.Res>:
    start : Nat <- IO.now()
    res : B.Res <- next(c)
    stop : Nat <- IO.now()
    return res

def custom(c: B.Context(Unit), next: B.Context(Unit) -> IO(B.Res)) -> IO(B.Res):
  do IO<B.Res>:
    res : B.Res <- next(c)
    return Common.header(res, "x-bench", "middleware")

def middleware(tag: Tag, c: B.Context(Unit), env: Unit, next: B.Context(Unit) -> IO(B.Res)) -> IO(B.Res):
  match tag:
    case Timing{}: timing(c, next)
    case Custom{}: custom(c, next)
    case Builtin{id}: B.builtin(Unit, id, c, next)
    case _: next(c)

def ready(result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "invalid routes")
    case Done{table}: B.serve_with(~Unit, ~Tag, ~Unit, ~dispatch, ~middleware, table, Unit{}, B.config())

def main() -> IO(Unit):
  ready(B.routes(Tag, [
    B.use(Tag, Timing{}),
    B.use(Tag, Builtin{B.cors(B.cors_defaults())}),
    B.use(Tag, Builtin{B.secure_headers()}),
    B.use(Tag, Builtin{B.request_id()}),
    B.use(Tag, Custom{}),
    B.get(Tag, "/middleware", Hello{})
  ]))
