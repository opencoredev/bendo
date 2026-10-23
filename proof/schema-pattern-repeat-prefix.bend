import Base
import ../src/data/schema-pattern.bend as P
import ../src/data/schema-spec.bend as Spec
import ./schema-pattern-split.bend as S
import ./schema-pattern-cat.bend as Cat
import ./schema-pattern-strings.bend as W

# A finite certificate holds the body induction fact for every prefix.
# Equality proofs and the dependent pair are copyable; no function is copied.
def Fact(+r: P.Pattern, +j: Nat, +c: U32, +t: String) -> Data:
  {Spec.matches(r, SCon{Chr{c}, String.take(t, j)}) == S.any_matches(P.derive(c, r), String.take(t, j)) : Bool}

def Facts(+r: P.Pattern, +j: Nat, +c: U32, +t: String) -> Data:
  match j:
    case 0n: Fact(r, 0n, c, t)
    case 1n+i: Sigma<&2, &2, Fact(r, 1n+i, c, t), _ => Facts(r, i, c, t)>

def zero(+r: P.Pattern, +c: U32, +t: String, e: Fact(r, 0n, c, t)) -> {Spec.matches(r, SCon{Chr{c}, ""}) == S.any_matches(P.derive(c, r), "") : Bool}:
  %S.take_zero(t) : {Spec.matches(r, SCon{Chr{c}, _}) == S.any_matches(P.derive(c, r), _) : Bool}
  e

def positive(+r: P.Pattern, +b: P.Pattern, +j: Nat, +c: U32, +t: String, +ej: {Nat.is_le(j, Spec.length(t)) == True{} : Bool}, +facts: Facts(r, j, c, t)) -> Cat.Positive(r, b, j, c, t):
  match j:
    case 0n:
      Cat.positive_zero(r, b, c, t, zero(r, c, t, facts))
    case 1n+i:
      (head, tail) = facts
      Cat.positive_next(r, b, i, c, t, ej, head, positive(r, b, i, c, t, W.le_previous(i, Spec.length(t), ej), tail))
