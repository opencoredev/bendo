# Three worker processes behind one port (BND-69). Each response carries the
# PID of the worker that served it.
import Base
import ../../src/main.bend as B
import ../../src/router/methods.bend as Methods
import ./pid.bend as Pid

type Tag is Data:
  Who{}

def dispatch(tag: Tag, c: B.Ctx, env: Unit) -> IO(B.Res):
  do IO<B.Res>:
    pid : U32 <- Pid.getpid()
    return B.text(c, U32.show(pid))

def ready(result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "invalid routes")
    case Done{table}: B.serve(~Tag, ~Unit, ~dispatch, table, Unit{}, B.workers(B.config(), 3))

def main() -> IO(Unit):
  ready(B.routes(Tag, [B.get(Tag, "/", Who{})]))
