import Base

# The admissible domain for all byte-oriented primitives, stated numerically.
def valid(xs: List<&2, U32>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case +x <> t:
      (x <= 255 : U32) && valid(t)
