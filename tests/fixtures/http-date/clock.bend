import Base
import ../../../src/effects/clock.bend as Clock

def print_sample(sample: Result<&1, &1, U32 & String, Nat>) -> IO(Unit):
  match sample:
    case Done{n}: IO.print(Nat.show(n))
    case Fail{error}: IO.die(Unit, 1, "wall clock unavailable")

def main() -> IO(Unit):
  do IO<Unit>:
    ms : Result<&1, &1, U32 & String, Nat> <- Clock.wall_millis()
    print_sample(ms)
    seconds : Result<&1, &1, U32 & String, Nat> <- Clock.wall_seconds()
    print_sample(seconds)

# Library exports require an argument; main is only the executable entrypoint.
def sample(unit: Unit) -> IO(Result<&1, &1, U32 & String, Nat>):
  Clock.wall_millis()
