# Nonempty-star peeling at the word bound used by the specification.
import Base
import ../src/data/schema-spec.bend as Spec
import ./schema-pattern-split.bend as S
import ./schema-pattern-cat.bend as Cat
import ./schema-pattern-strings.bend as W
import ./schema-pattern-bound-counts.bend as C
import ./schema-pattern-repeat-algebra.bend as A

def or_self(+b: Bool) -> {(b || b) == b : Bool}:
  match b:
    case True{}: {==}
    case False{}: {==}

# Even a partial outer split counter visits the empty prefix.
def cat_empty_left(+k: Nat, +l: Spec.Lang, +w: String) -> {Spec.mem(Spec.LCat{Spec.LEmpty{}, l}, k, w) == Spec.mem(l, Spec.length(w), w) : Bool}:
  match k:
    case 0n: {==}
    case 1n+j:
      match w:
        case SNil{}:
          %Equal.sym(Bool, Spec.mem(Spec.LCat{Spec.LEmpty{}, l}, j, ""), Spec.mem(l, 0n, ""), cat_empty_left(j, l, "")) : {(Spec.mem(l, 0n, "") || _) == Spec.mem(l, 0n, "") : Bool}
          or_self(Spec.mem(l, 0n, ""))
        case SCon{h, t}: cat_empty_left(j, l, SCon{h, t})

def star_tail(+l: Spec.Lang, +t: String, +w: String, +ew: {Nat.is_le(Spec.length(w), Spec.length(t)) == True{} : Bool}) -> {Spec.mem(Spec.counts(Spec.LNonEmpty{l}, 0n, Spec.length(t)), Spec.length(w), w) == Spec.mem(Spec.repeat(l, 0n, None{}, 1n+Spec.length(t)), Spec.length(w), w) : Bool}:
  %Equal.sym(Bool, Spec.mem(Spec.repeat(l, 0n, None{}, 1n+Spec.length(t)), Spec.length(w), w), Spec.mem(Spec.counts(Spec.LNonEmpty{l}, 0n, 1n+Spec.length(t)), Spec.length(w), w), cat_empty_left(Spec.length(w), Spec.counts(Spec.LNonEmpty{l}, 0n, 1n+Spec.length(t)), w)) : {Spec.mem(Spec.counts(Spec.LNonEmpty{l}, 0n, Spec.length(t)), Spec.length(w), w) == _ : Bool}
  C.counts_bound(l, 0n, Spec.length(t), 1n+Spec.length(t), Spec.length(w), w, Cat.length_bound(w, Spec.length(t), ew), Cat.length_bound(w, 1n+Spec.length(t), W.le_next(Spec.length(w), Spec.length(t), ew)))

def star_positive(+j: Nat, +l: Spec.Lang, +c: U32, +t: String) -> {S.positive(Spec.LNonEmpty{l}, Spec.counts(Spec.LNonEmpty{l}, 0n, Spec.length(t)), j, c, t) == S.positive(l, Spec.repeat(l, 0n, None{}, 1n+Spec.length(t)), j, c, t) : Bool}:
  match j:
    case 0n:
      %star_tail(l, t, t, W.le_self(Spec.length(t))) : {S.positive(Spec.LNonEmpty{l}, Spec.counts(Spec.LNonEmpty{l}, 0n, Spec.length(t)), 0n, c, t) == (Spec.mem(l, 1n, SCon{Chr{c}, ""}) && _) : Bool}
      {==}
    case 1n+i:
      %star_positive(i, l, c, t) : {S.positive(Spec.LNonEmpty{l}, Spec.counts(Spec.LNonEmpty{l}, 0n, Spec.length(t)), 1n+i, c, t) == ((Spec.mem(l, 1n+1n+i, SCon{Chr{c}, String.take(t, 1n+i)}) && Spec.mem(Spec.repeat(l, 0n, None{}, 1n+Spec.length(t)), Spec.length(String.drop(t, 1n+i)), String.drop(t, 1n+i))) || _) : Bool}
      %star_tail(l, t, String.drop(t, 1n+i), W.suffix_le(t, 1n+i)) : {S.positive(Spec.LNonEmpty{l}, Spec.counts(Spec.LNonEmpty{l}, 0n, Spec.length(t)), 1n+i, c, t) == ((Spec.mem(l, 1n+1n+i, SCon{Chr{c}, String.take(t, 1n+i)}) && _) || S.positive(Spec.LNonEmpty{l}, Spec.counts(Spec.LNonEmpty{l}, 0n, Spec.length(t)), i, c, t)) : Bool}
      {==}

def star_counts_head(+l: Spec.Lang, +c: U32, +t: String) -> {Spec.mem(Spec.counts(Spec.LNonEmpty{l}, 0n, 1n+Spec.length(t)), 1n+Spec.length(t), SCon{Chr{c}, t}) == S.positive(Spec.LNonEmpty{l}, Spec.counts(Spec.LNonEmpty{l}, 0n, Spec.length(t)), Spec.length(t), c, t) : Bool}:
  %S.or_zero(S.positive(Spec.LNonEmpty{l}, Spec.counts(Spec.LNonEmpty{l}, 0n, Spec.length(t)), Spec.length(t), c, t)) : {Spec.mem(Spec.counts(Spec.LNonEmpty{l}, 0n, 1n+Spec.length(t)), 1n+Spec.length(t), SCon{Chr{c}, t}) == _ : Bool}
  %Equal.sym(Bool, Spec.mem(Spec.counts(Spec.LNonEmpty{l}, 0n, 1n+Spec.length(t)), 1n+Spec.length(t), SCon{Chr{c}, t}), Spec.mem(Spec.LCat{Spec.LNonEmpty{l}, Spec.counts(Spec.LNonEmpty{l}, 0n, Spec.length(t))}, 1n+Spec.length(t), SCon{Chr{c}, t}), A.counts_head(0n, Spec.length(t), Spec.LNonEmpty{l}, 1n+Spec.length(t), c, t)) : {_ == (S.positive(Spec.LNonEmpty{l}, Spec.counts(Spec.LNonEmpty{l}, 0n, Spec.length(t)), Spec.length(t), c, t) || False{}) : Bool}
  S.cat_head(Spec.length(t), Spec.LNonEmpty{l}, Spec.counts(Spec.LNonEmpty{l}, 0n, Spec.length(t)), c, t)

def star_head(+l: Spec.Lang, +c: U32, +t: String) -> {Spec.mem(Spec.repeat(l, 0n, None{}, 1n+Spec.length(t)), 1n+Spec.length(t), SCon{Chr{c}, t}) == S.positive(l, Spec.repeat(l, 0n, None{}, 1n+Spec.length(t)), Spec.length(t), c, t) : Bool}:
  %star_positive(Spec.length(t), l, c, t) : {Spec.mem(Spec.repeat(l, 0n, None{}, 1n+Spec.length(t)), 1n+Spec.length(t), SCon{Chr{c}, t}) == _ : Bool}
  %Equal.sym(Bool, Spec.mem(Spec.repeat(l, 0n, None{}, 1n+Spec.length(t)), 1n+Spec.length(t), SCon{Chr{c}, t}), Spec.mem(Spec.counts(Spec.LNonEmpty{l}, 0n, 1n+Spec.length(t)), 1n+Spec.length(t), SCon{Chr{c}, t}), cat_empty_left(1n+Spec.length(t), Spec.counts(Spec.LNonEmpty{l}, 0n, 1n+Spec.length(t)), SCon{Chr{c}, t})) : {_ == S.positive(Spec.LNonEmpty{l}, Spec.counts(Spec.LNonEmpty{l}, 0n, Spec.length(t)), Spec.length(t), c, t) : Bool}
  star_counts_head(l, c, t)
