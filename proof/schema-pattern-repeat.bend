# Repetition derivatives use the same finite body-prefix certificate for every
# remaining count. Only the count decreases after the pattern induction ends.
import Base
import ../src/data/schema-pattern.bend as P
import ../src/data/schema-spec.bend as Spec
import ./schema-pattern-split.bend as S
import ./schema-pattern-repeat-prefix.bend as F
import ./schema-pattern-repeat-bounded.bend as B
import ./schema-pattern-repeat-unbounded.bend as U
import ./schema-pattern-repeat-bridge.bend as Bridge

def unbounded(+m: Nat, +r: P.Pattern, +c: U32, +t: String, +facts: F.Facts(r, Spec.length(t), c, t), +empty: Bool, +en: {P.nullable(r) == empty : Bool}) -> {Spec.matches(P.Repeat{r, m, None{}}, SCon{Chr{c}, t}) == S.any_matches(P.repeat_step(empty, P.derive(c, r), r, m, None{}), t) : Bool}:
  match m:
    case 0n: Bridge.minimum_zero(r, c, t, facts, empty)
    case 1n+i:
      Bridge.next(i, r, c, t, empty, en, Bridge.head(i, r, c, t, facts, U.repeat_head(i, Spec.lang(r, 1n+Spec.length(t)), c, t)), unbounded(i, r, c, t, facts, empty, en))

def complete(+r: P.Pattern, +m: Nat, +n: Maybe<&2, Nat>, +c: U32, +t: String, +facts: F.Facts(r, Spec.length(t), c, t)) -> {Spec.matches(P.Repeat{r, m, n}, SCon{Chr{c}, t}) == S.any_matches(P.derive(c, P.Repeat{r, m, n}), t) : Bool}:
  match n:
    case Some{k}: B.bounded(k, m, r, c, t, facts, P.nullable(r), {==})
    case None{}: unbounded(m, r, c, t, facts, P.nullable(r), {==})
