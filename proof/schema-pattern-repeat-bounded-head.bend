import Base
import ../src/data/schema-spec.bend as Spec
import ./schema-pattern-split.bend as S
import ./schema-pattern-empty.bend as E
import ./schema-pattern-repeat-algebra.bend as A

# A positive split distributes over the union of possible remainder counts.
def positive_or(+j: Nat, +l: Spec.Lang, +b: Spec.Lang, +d: Spec.Lang, +c: U32, +t: String) -> {S.positive(l, Spec.LOr{b, d}, j, c, t) == (S.positive(l, b, j, c, t) || S.positive(l, d, j, c, t)) : Bool}:
  match j:
    case 0n: S.or_and(Spec.mem(l, 1n, SCon{Chr{c}, ""}), Spec.mem(b, Spec.length(t), t), Spec.mem(d, Spec.length(t), t))
    case 1n+i:
      %S.or_swap(Spec.mem(l, 1n+1n+i, SCon{Chr{c}, String.take(t, 1n+i)}) && Spec.mem(b, Spec.length(String.drop(t, 1n+i)), String.drop(t, 1n+i)), S.positive(l, b, i, c, t), Spec.mem(l, 1n+1n+i, SCon{Chr{c}, String.take(t, 1n+i)}) && Spec.mem(d, Spec.length(String.drop(t, 1n+i)), String.drop(t, 1n+i)), S.positive(l, d, i, c, t)) : {S.positive(l, Spec.LOr{b, d}, 1n+i, c, t) == _ : Bool}
      %positive_or(i, l, b, d, c, t) : {S.positive(l, Spec.LOr{b, d}, 1n+i, c, t) == (((Spec.mem(l, 1n+1n+i, SCon{Chr{c}, String.take(t, 1n+i)}) && Spec.mem(b, Spec.length(String.drop(t, 1n+i)), String.drop(t, 1n+i))) || (Spec.mem(l, 1n+1n+i, SCon{Chr{c}, String.take(t, 1n+i)}) && Spec.mem(d, Spec.length(String.drop(t, 1n+i)), String.drop(t, 1n+i)))) || _) : Bool}
      %S.or_and(Spec.mem(l, 1n+1n+i, SCon{Chr{c}, String.take(t, 1n+i)}), Spec.mem(b, Spec.length(String.drop(t, 1n+i)), String.drop(t, 1n+i)), Spec.mem(d, Spec.length(String.drop(t, 1n+i)), String.drop(t, 1n+i))) : {S.positive(l, Spec.LOr{b, d}, 1n+i, c, t) == (_ || S.positive(l, Spec.LOr{b, d}, i, c, t)) : Bool}
      {==}

def or_again(+a: Bool, +b: Bool) -> {((a || b) || a) == (a || b) : Bool}:
  match a b:
    case True{} _: {==}
    case False{} True{}: {==}
    case False{} False{}: {==}

def positive_counts_absorb(+j: Nat, +l: Spec.Lang, +n: Nat, +c: U32, +t: String) -> {(S.positive(l, Spec.counts(l, 0n, 1n+n), j, c, t) || S.positive(l, Spec.counts(l, 0n, n), j, c, t)) == S.positive(l, Spec.counts(l, 0n, 1n+n), j, c, t) : Bool}:
  %Equal.sym(Bool, S.positive(l, Spec.counts(l, 0n, 1n+n), j, c, t), S.positive(l, Spec.counts(l, 0n, n), j, c, t) || S.positive(l, Bool.pick(Spec.Lang, Nat.is_le(0n, 1n+n), Spec.power(l, 1n+n), Spec.LNone{}), j, c, t), positive_or(j, l, Spec.counts(l, 0n, n), Bool.pick(Spec.Lang, Nat.is_le(0n, 1n+n), Spec.power(l, 1n+n), Spec.LNone{}), c, t)) : {(_ || S.positive(l, Spec.counts(l, 0n, n), j, c, t)) == _ : Bool}
  or_again(S.positive(l, Spec.counts(l, 0n, n), j, c, t), S.positive(l, Bool.pick(Spec.Lang, Nat.is_le(0n, 1n+n), Spec.power(l, 1n+n), Spec.LNone{}), j, c, t))

def absorb_guard(+a: Bool, +b: Bool, +x: Bool, e: {(a || b) == a : Bool}) -> {(a || (x && b)) == a : Bool}:
  match a b x:
    case True{} _ _: {==}
    case False{} False{} False{}: {==}
    case False{} False{} True{}: {==}
    case False{} True{} False{}: {==}
    case False{} True{} True{}: e

# For minimum zero, skipping an empty body adds only smaller trailing counts.
def zero_head(+n: Nat, +l: Spec.Lang, +c: U32, +t: String) -> {Spec.mem(Spec.counts(l, 0n, 1n+n), 1n+Spec.length(t), SCon{Chr{c}, t}) == S.positive(l, Spec.counts(l, 0n, n), Spec.length(t), c, t) : Bool}:
  match n:
    case 0n:
      %S.or_zero(S.positive(l, Spec.LEmpty{}, Spec.length(t), c, t)) : {Spec.mem(Spec.counts(l, 0n, 1n), 1n+Spec.length(t), SCon{Chr{c}, t}) == _ : Bool}
      %S.and_zero(E.nu(l)) : {Spec.mem(Spec.counts(l, 0n, 1n), 1n+Spec.length(t), SCon{Chr{c}, t}) == (S.positive(l, Spec.LEmpty{}, Spec.length(t), c, t) || _) : Bool}
      %S.cat_head(Spec.length(t), l, Spec.LEmpty{}, c, t) : {Spec.mem(Spec.counts(l, 0n, 1n), 1n+Spec.length(t), SCon{Chr{c}, t}) == _ : Bool}
      A.counts_head(0n, 0n, l, 1n+Spec.length(t), c, t)
    case 1n+i:
      %absorb_guard(S.positive(l, Spec.counts(l, 0n, 1n+i), Spec.length(t), c, t), S.positive(l, Spec.counts(l, 0n, i), Spec.length(t), c, t), E.nu(l), positive_counts_absorb(Spec.length(t), l, i, c, t)) : {Spec.mem(Spec.counts(l, 0n, 1n+1n+i), 1n+Spec.length(t), SCon{Chr{c}, t}) == _ : Bool}
      %zero_head(i, l, c, t) : {Spec.mem(Spec.counts(l, 0n, 1n+1n+i), 1n+Spec.length(t), SCon{Chr{c}, t}) == (S.positive(l, Spec.counts(l, 0n, 1n+i), Spec.length(t), c, t) || (E.nu(l) && _)) : Bool}
      %S.cat_head(Spec.length(t), l, Spec.counts(l, 0n, 1n+i), c, t) : {Spec.mem(Spec.counts(l, 0n, 1n+1n+i), 1n+Spec.length(t), SCon{Chr{c}, t}) == _ : Bool}
      A.counts_head(0n, 1n+i, l, 1n+Spec.length(t), c, t)
