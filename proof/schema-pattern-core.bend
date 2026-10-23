# The two facts the derivative matcher rests on: a pattern accepts the empty
# string exactly when `nullable` says so, and it accepts c followed by t
# exactly when one of its derivatives by c accepts t. Both are stated against
# the split-based specification (src/data/schema-spec.bend).
import Base
import ../src/data/schema-pattern.bend as P
import ../src/data/schema-spec.bend as Spec

# Some pattern in the list accepts w, per the specification.
def any_matches(ps: List<&2, P.Pattern>, +w: String) -> Bool:
  match ps:
    case Nil{}: False{}
    case p <> t: Spec.matches(p, w) || any_matches(t, w)

def nullable_equiv(+p: P.Pattern) -> {P.nullable(p) == Spec.matches(p, "") : Bool}:
  ?TODO

def derive_equiv(+c: U32, +p: P.Pattern, +t: String) -> {Spec.matches(p, SCon{Chr{c}, t}) == any_matches(P.derive(c, p), t) : Bool}:
  ?TODO
