import Base
import ../../src/main.bend as B
import ../../src/app/config.bend as Config
import ../../src/router/methods.bend as Methods

type Tag is Data:
  Echo{}

def dispatch(tag: Tag, ctx: B.Ctx, env: Unit) -> IO(B.Res):
  +c = ctx
  IO.pure(B.Res, B.body(c, B.raw_body(c), None{}))

def ready(result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "invalid echo route")
    case Done{table}:
      B.serve(~Tag, ~Unit, ~dispatch, table, Unit{}, Config.Config{"127.0.0.2", 18712, 3, 65536, 5000, 10000, 30000, 100, True{}, B.spec()})

def main() -> IO(Unit):
  ready(B.routes(Tag, [B.post(Tag, "/", Echo{})]))
