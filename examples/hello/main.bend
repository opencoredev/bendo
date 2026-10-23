# Hello from Bendo. Run: bend examples/hello/main.bend -o hello && ./hello
import Base
import ../../src/main.bend as B
import ../../src/router/methods.bend as Methods

type Tag is Data:
  Hello{}

def dispatch(tag: Tag, ctx: B.Ctx, env: Unit) -> IO(B.Res):
  +c = ctx
  IO.pure(B.Res, B.text(c, "Hello from Bendo! You asked for " ++ B.url(c)))

def ready(result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Done{table}:
      B.serve(~Tag, ~Unit, ~dispatch, table, Unit{}, B.config())
    case Fail{error}:
      IO.die(Unit, 1, "invalid hello route")

def main() -> IO(Unit):
  ready(B.routes(Tag, [B.get(Tag, "/*", Hello{})]))
