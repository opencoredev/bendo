# Empty acceptance is independent of the ambient bound, including inside star.
import Base
import ../src/data/schema-pattern.bend as P
import ../src/data/schema-spec.bend as Spec
import ./schema-pattern-empty.bend as Empty

def zero_le(+n: Nat) -> {Nat.is_le(0n, n) == True{} : Bool}:
  match n:
    case 0n: {==}
    case 1n+j: {==}

def star_nu(+l: Spec.Lang, +bound: Nat) -> {Empty.nu(Spec.counts(Spec.LNonEmpty{l}, 0n, bound)) == True{} : Bool}:
  %zero_le(bound) : {Empty.nu(Spec.counts(Spec.LNonEmpty{l}, 0n, bound)) == (_ && True{}) : Bool}
  Empty.counts_nu(bound, 0n, Spec.LNonEmpty{l})

def repeat_nu(+l: Spec.Lang, +m: Nat, +n: Maybe<&2, Nat>, +bound: Nat) -> {Empty.nu(Spec.repeat(l, m, n, bound)) == (P.at_most(n, m) && (Nat.is_eq(m, 0n) || Empty.nu(l))) : Bool}:
  match n:
    case Some{k}: Empty.counts_nu(k, m, l)
    case None{}:
      %Empty.power_nu(l, m) : {(Empty.nu(Spec.power(l, m)) && Empty.nu(Spec.counts(Spec.LNonEmpty{l}, 0n, bound))) == _ : Bool}
      %Equal.sym(Bool, Empty.nu(Spec.counts(Spec.LNonEmpty{l}, 0n, bound)), True{}, star_nu(l, bound)) : {(Empty.nu(Spec.power(l, m)) && _) == Empty.nu(Spec.power(l, m)) : Bool}
      Empty.and_true(Empty.nu(Spec.power(l, m)))

def nullable_lang(+p: P.Pattern, +bound: Nat) -> {P.nullable(p) == Empty.nu(Spec.lang(p, bound)) : Bool}:
  match p:
    case P.Literal{x}: {==}
    case P.Class{rs}: {==}
    case P.Cat{a, b}:
      %nullable_lang(a, bound) : {P.nullable(P.Cat{a, b}) == (_ && Empty.nu(Spec.lang(b, bound))) : Bool}
      %nullable_lang(b, bound) : {P.nullable(P.Cat{a, b}) == (P.nullable(a) && _) : Bool}
      {==}
    case P.Repeat{r, m, n}:
      %Equal.sym(Bool, Empty.nu(Spec.repeat(Spec.lang(r, bound), m, n, bound)), P.at_most(n, m) && (Nat.is_eq(m, 0n) || Empty.nu(Spec.lang(r, bound))), repeat_nu(Spec.lang(r, bound), m, n, bound)) : {P.nullable(P.Repeat{r, m, n}) == _ : Bool}
      %nullable_lang(r, bound) : {P.nullable(P.Repeat{r, m, n}) == (P.at_most(n, m) && (Nat.is_eq(m, 0n) || _)) : Bool}
      {==}

def nullable_mem(+p: P.Pattern, +bound: Nat) -> {P.nullable(p) == Spec.mem(Spec.lang(p, bound), 0n, "") : Bool}:
  %Equal.sym(Bool, Spec.mem(Spec.lang(p, bound), 0n, ""), Empty.nu(Spec.lang(p, bound)), Empty.mem_empty(Spec.lang(p, bound))) : {P.nullable(p) == _ : Bool}
  nullable_lang(p, bound)
