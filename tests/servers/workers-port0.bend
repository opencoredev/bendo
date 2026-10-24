# Several workers with config port 0 (BND-69). Startup must refuse, because
# each worker would get its own ephemeral port.
import Base
import ../../src/main.bend as B
import ../../src/app/config.bend as Config
import ../../src/router/methods.bend as Methods

type Tag is Data:
  Root{}

def dispatch(tag: Tag, c: B.Ctx, env: Unit) -> IO(B.Res):
  IO.pure(B.Res, B.text(c, "never"))

def any_port(c: Config.Config) -> Config.Config:
  Config.Config{host, port, limit, headers, idle, head, body, max, keep, router, mode, workers} = c
  Config.Config{host, 0, limit, headers, idle, head, body, max, keep, router, mode, 2}

def ready(result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "invalid routes")
    case Done{table}: B.serve(~Tag, ~Unit, ~dispatch, table, Unit{}, any_port(Config.defaults()))

def main() -> IO(Unit):
  ready(B.routes(Tag, [B.get(Tag, "/", Root{})]))
