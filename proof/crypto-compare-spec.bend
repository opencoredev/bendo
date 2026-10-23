# BND-43: specification for constant-time comparison.
import Base

# Independent specification: same length and equal elements, compared in order.
def equal(xs: List<&2, U32>, ys: List<&2, U32>) -> Bool:
  match xs ys:
    case Nil{} Nil{}:
      True{}
    case x <> xt y <> yt:
      U32.is_eq(x, y) && equal(xt, yt)
    case x <> xt Nil{}:
      False{}
    case Nil{} y <> yt:
      False{}
