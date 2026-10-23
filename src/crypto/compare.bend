import Base

# Best effort only: visits every element of both lists, without an early
# mismatch exit. Bend's compiler/runtime gives no constant-time guarantee;
# list lengths and allocations remain observable. Inputs must be octets.
def compare_go(xs: List<&2, U32>, ys: List<&2, U32>, diff: U32) -> Bool:
  match xs ys:
    case Nil{} Nil{}:
      U32.is_zero(diff)
    case x <> xt y <> yt:
      compare_go(xt, yt, U32.or(diff, U32.xor(x, y)))
    case x <> xt Nil{}:
      compare_go(xt, [], U32.or(diff, 1))
    case Nil{} y <> yt:
      compare_go([], yt, U32.or(diff, 1))

def ct_equal(xs: List<&2, U32>, ys: List<&2, U32>) -> Bool:
  compare_go(xs, ys, 0)
