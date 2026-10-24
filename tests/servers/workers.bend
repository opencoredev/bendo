# Three worker processes behind one port (BND-69). Each response carries the
# PID of the worker that served it. GET /spawn also starts a fresh copy of the
# binary from a worker and answers "<pid> <copy pid>" (copy 0 in the first
# process). Startup runs the stall test effect, which delays or fails workers
# when the test asks for it.
import Base
import ../../src/main.bend as B
import ../../src/router/methods.bend as Methods
import ./pid.bend as Pid
import ./spawn.bend as Spawn
import ./stall.bend as Stall

type Tag is Data:
  Who{}
  Copy{}

def dispatch(tag: Tag, c: B.Ctx, env: Unit) -> IO(B.Res):
  match tag:
    case Who{}:
      do IO<B.Res>:
        pid : U32 <- Pid.getpid()
        return B.text(c, U32.show(pid))
    case Copy{}:
      do IO<B.Res>:
        pid : U32 <- Pid.getpid()
        copy : U32 <- Spawn.spawn_copy()
        return B.text(c, U32.show(pid) ++ " " ++ U32.show(copy))

def ready(result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "invalid routes")
    case Done{table}: B.serve(~Tag, ~Unit, ~dispatch, table, Unit{}, B.workers(B.config(), 3))

def main() -> IO(Unit):
  do IO<Unit>:
    Stall.stall()
    ready(B.routes(Tag, [B.get(Tag, "/", Who{}), B.get(Tag, "/spawn", Copy{})]))
