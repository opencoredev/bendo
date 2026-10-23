import Base
import ./common.bend as C

# Measurement shell: a U32 countdown avoids allocating a Nat per input octet.
# main caps the count at 4 MiB. No production code imports this unsafe helper.
@unsafe
def build(+n: U32, acc: List<&2, U32>, done: Bool) -> List<&2, U32>:
  match done:
    case True{}: acc
    case False{}:
      build((n - 1 : U32), Con{U32.mod(n, 256), acc}, U32.is_eq(n, 1))

def count(xs: List<&2, U32>, acc: U32) -> U32:
  match xs:
    case Nil{}: acc
    case Con{h, t}: count(t, (acc + 1 : U32))

# The later traversal keeps every node reachable across the sleep effect.
def hold(body: List<&2, U32>) -> IO(Unit):
  do IO<Unit>:
    IO.print("body live")
    IO.sleep(1000)
    IO.print("octets=" ++ U32.show(count(body, 0)))

def size(r: Result<&1, &1, U32 & String, String>) -> U32:
  match r:
    case Fail{e}: 0
    case Done{s}: U32.min(C.length_or(U32.read(s), 0), 4194304)

def main() -> IO(Unit):
  do IO<Unit>:
    env : Result<&1, &1, U32 & String, String> <- IO.get_env("BODY_OCTETS")
    +n : U32 = size(env)
    hold(build(n, Nil{}, U32.is_zero(n)))
