# Word bounds do not affect pattern membership once they cover the word.
import Base
import ../src/data/schema-pattern.bend as P
import ../src/data/schema-spec.bend as Spec
import ./schema-pattern-bound-length.bend as L
import ./schema-pattern-bound-tree.bend as T

def repeat(+t: T.Tree, m: Nat, n: Maybe<&2, Nat>, +b1: Nat, +b2: Nat) -> T.Tree:
  match n:
    case Some{j}: T.counts(t, m, j)
    case None{}:
      T.Cat{T.power(t, m), T.Chain{T.counts(T.NonEmpty{t}, 0n, b1), T.Trim{T.right(t), 0n, b1, b2}, T.counts_right(b1, T.NonEmpty{t}, 0n)}}

def repeat_left(+t: T.Tree, +m: Nat, +n: Maybe<&2, Nat>, +b1: Nat, +b2: Nat) -> {T.left(repeat(t, m, n, b1, b2)) == Spec.repeat(T.left(t), m, n, b1) : Spec.Lang}:
  match n:
    case Some{j}: T.counts_left(j, t, m)
    case None{}:
      %T.power_left(m, t) : {T.left(repeat(t, m, None{}, b1, b2)) == Spec.LCat{_, Spec.counts(Spec.LNonEmpty{T.left(t)}, 0n, b1)} : Spec.Lang}
      %T.counts_left(b1, T.NonEmpty{t}, 0n) : {T.left(repeat(t, m, None{}, b1, b2)) == Spec.LCat{T.left(T.power(t, m)), _} : Spec.Lang}
      {==}

def repeat_right(+t: T.Tree, +m: Nat, +n: Maybe<&2, Nat>, +b1: Nat, +b2: Nat) -> {T.right(repeat(t, m, n, b1, b2)) == Spec.repeat(T.right(t), m, n, b2) : Spec.Lang}:
  match n:
    case Some{j}: T.counts_right(j, t, m)
    case None{}:
      %T.power_right(m, t) : {T.right(repeat(t, m, None{}, b1, b2)) == Spec.LCat{_, Spec.counts(Spec.LNonEmpty{T.right(t)}, 0n, b2)} : Spec.Lang}
      {==}

def repeat_valid(+t: T.Tree, +m: Nat, +n: Maybe<&2, Nat>, +b1: Nat, +b2: Nat, +limit: Nat, +v: {T.valid(t, limit) == True{} : Bool}, e1: {Nat.is_le(limit, b1) == True{} : Bool}, e2: {Nat.is_le(limit, b2) == True{} : Bool}) -> {T.valid(repeat(t, m, n, b1, b2), limit) == True{} : Bool}:
  match n:
    case Some{j}: T.counts_valid(j, t, m, limit, v)
    case None{}:
      %Equal.sym(Bool, T.valid(T.power(t, m), limit), True{}, T.power_valid(m, t, limit, v)) : {(_ && (T.valid(T.counts(T.NonEmpty{t}, 0n, b1), limit) && (Nat.is_le(limit, b1) && Nat.is_le(limit, b2)))) == True{} : Bool}
      %Equal.sym(Bool, T.valid(T.counts(T.NonEmpty{t}, 0n, b1), limit), True{}, T.counts_valid(b1, T.NonEmpty{t}, 0n, limit, v)) : {(_ && (Nat.is_le(limit, b1) && Nat.is_le(limit, b2))) == True{} : Bool}
      %Equal.sym(Bool, Nat.is_le(limit, b1), True{}, e1) : {(_ && Nat.is_le(limit, b2)) == True{} : Bool}
      e2

# A finite certificate mirrors the pattern structure. Only unbounded Repeat
# introduces a truncation step; Cat and finite Repeat use congruence alone.
def certificate(p: P.Pattern, +b1: Nat, +b2: Nat) -> T.Tree:
  match p:
    case P.Literal{x}: T.Same{Spec.LText{x}}
    case P.Class{rs}: T.Same{Spec.LOne{rs}}
    case P.Cat{a, b}: T.Cat{certificate(a, b1, b2), certificate(b, b1, b2)}
    case P.Repeat{r, m, n}: repeat(certificate(r, b1, b2), m, n, b1, b2)

def certificate_left(+p: P.Pattern, +b1: Nat, +b2: Nat) -> {T.left(certificate(p, b1, b2)) == Spec.lang(p, b1) : Spec.Lang}:
  match p:
    case P.Literal{x}: {==}
    case P.Class{rs}: {==}
    case P.Cat{a, b}:
      %certificate_left(a, b1, b2) : {T.left(certificate(P.Cat{a, b}, b1, b2)) == Spec.LCat{_, Spec.lang(b, b1)} : Spec.Lang}
      %certificate_left(b, b1, b2) : {T.left(certificate(P.Cat{a, b}, b1, b2)) == Spec.LCat{T.left(certificate(a, b1, b2)), _} : Spec.Lang}
      {==}
    case P.Repeat{r, m, n}:
      %certificate_left(r, b1, b2) : {T.left(certificate(P.Repeat{r, m, n}, b1, b2)) == Spec.repeat(_, m, n, b1) : Spec.Lang}
      repeat_left(certificate(r, b1, b2), m, n, b1, b2)

def certificate_right(+p: P.Pattern, +b1: Nat, +b2: Nat) -> {T.right(certificate(p, b1, b2)) == Spec.lang(p, b2) : Spec.Lang}:
  match p:
    case P.Literal{x}: {==}
    case P.Class{rs}: {==}
    case P.Cat{a, b}:
      %certificate_right(a, b1, b2) : {T.right(certificate(P.Cat{a, b}, b1, b2)) == Spec.LCat{_, Spec.lang(b, b2)} : Spec.Lang}
      %certificate_right(b, b1, b2) : {T.right(certificate(P.Cat{a, b}, b1, b2)) == Spec.LCat{T.right(certificate(a, b1, b2)), _} : Spec.Lang}
      {==}
    case P.Repeat{r, m, n}:
      %certificate_right(r, b1, b2) : {T.right(certificate(P.Repeat{r, m, n}, b1, b2)) == Spec.repeat(_, m, n, b2) : Spec.Lang}
      repeat_right(certificate(r, b1, b2), m, n, b1, b2)

def certificate_valid(+p: P.Pattern, +b1: Nat, +b2: Nat, +limit: Nat, +e1: {Nat.is_le(limit, b1) == True{} : Bool}, +e2: {Nat.is_le(limit, b2) == True{} : Bool}) -> {T.valid(certificate(p, b1, b2), limit) == True{} : Bool}:
  match p:
    case P.Literal{x}: {==}
    case P.Class{rs}: {==}
    case P.Cat{a, b}:
      %Equal.sym(Bool, T.valid(certificate(a, b1, b2), limit), True{}, certificate_valid(a, b1, b2, limit, e1, e2)) : {(_ && T.valid(certificate(b, b1, b2), limit)) == True{} : Bool}
      certificate_valid(b, b1, b2, limit, e1, e2)
    case P.Repeat{r, m, n}: repeat_valid(certificate(r, b1, b2), m, n, b1, b2, limit, certificate_valid(r, b1, b2, limit, e1, e2), e1, e2)

def bound_adequacy(+p: P.Pattern, +w: String, +k: Nat, +b1: Nat, +b2: Nat, e1: {Nat.is_le(String.length(w), b1) == True{} : Bool}, e2: {Nat.is_le(String.length(w), b2) == True{} : Bool}) -> {Spec.mem(Spec.lang(p, b1), k, w) == Spec.mem(Spec.lang(p, b2), k, w) : Bool}:
  %certificate_left(p, b1, b2) : {Spec.mem(_, k, w) == Spec.mem(Spec.lang(p, b2), k, w) : Bool}
  %certificate_right(p, b1, b2) : {Spec.mem(T.left(certificate(p, b1, b2)), k, w) == Spec.mem(_, k, w) : Bool}
  T.sound(certificate(p, b1, b2), k, w, String.length(w), certificate_valid(p, b1, b2, String.length(w), e1, e2), L.le_refl(String.length(w)))
