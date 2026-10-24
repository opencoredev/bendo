# GET / through the public router, context and server loop (BND-67).
import Base
import ../../src/main.bend as B
import ../../src/router/methods.bend as Methods

type Tag is Data:
  Hello{}

def dispatch(tag: Tag, c: B.Ctx, env: Unit) -> IO(B.Res):
  IO.pure(B.Res, B.text(c, "Hello, world!"))

def ready(result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "invalid routes")
    case Done{table}: B.serve(~Tag, ~Unit, ~dispatch, table, Unit{}, B.config())

def main() -> IO(Unit):
  ready(B.routes(Tag, [B.get(Tag, "/", Hello{})]))
