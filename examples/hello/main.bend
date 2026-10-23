# Hello from Bendo. Run: bend examples/hello/main.bend -o hello && ./hello
import Base
import ../../src/main.bend as B
import ../../src/app/handle.bend as Context
import ../../src/router/methods.bend as Methods
import ../../src/http/request.bend as Request

type Tag is Data:
  Hello{}

def dispatch(tag: Tag, ctx: B.Ctx, env: Unit) -> IO(B.Res):
  Context.Ctx{req, params, body} = ctx
  IO.pure(B.Res, B.text(200, "Hello from Bendo! You asked for " ++ Request.target(req)))

def ready(result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Done{table}:
      B.serve(~Tag, ~Unit, ~dispatch, table, Unit{}, B.config())
    case Fail{error}:
      IO.die(Unit, 1, "invalid hello route")

def main() -> IO(Unit):
  ready(B.routes(Tag, [B.get(Tag, "/*", Hello{})]))
