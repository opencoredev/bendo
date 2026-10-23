import Base

# Accumulate before the recursive call so JavaScript emits a loop.
def valid_acc(xs: List<&2, U32>, ok: Bool) -> Bool:
  match xs:
    case Nil{}:
      ok
    case +x <> t:
      valid_acc(t, ok && (x <= 255 : U32))

# The admissible domain for all byte-oriented primitives, stated numerically.
def valid(xs: List<&2, U32>) -> Bool:
  valid_acc(xs, True{})
