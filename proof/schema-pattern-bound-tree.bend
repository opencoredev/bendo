# Finite certificates lift language equivalence without copying functions.
import Base
import ../src/data/schema-spec.bend as Spec
import ./schema-pattern-bound-length.bend as L
import ./schema-pattern-bound-counts.bend as C

type Tree is Data:
  Same{language: Spec.Lang}
  Cat{first: Tree, second: Tree}
  Or{first: Tree, second: Tree}
  NonEmpty{body: Tree}
  Trim{language: Spec.Lang, min: Nat, bound1: Nat, bound2: Nat}
  Chain{first: Tree, second: Tree, link: {right(first) == left(second) : Spec.Lang}}

def left(t: Tree) -> Spec.Lang:
  match t:
    case Same{l}: l
    case Cat{a, b}: Spec.LCat{left(a), left(b)}
    case Or{a, b}: Spec.LOr{left(a), left(b)}
    case NonEmpty{a}: Spec.LNonEmpty{left(a)}
    case Trim{l, m, b1, b2}: Spec.counts(Spec.LNonEmpty{l}, m, b1)
    case Chain{a, b, e}: left(a)

def right(t: Tree) -> Spec.Lang:
  match t:
    case Same{l}: l
    case Cat{a, b}: Spec.LCat{right(a), right(b)}
    case Or{a, b}: Spec.LOr{right(a), right(b)}
    case NonEmpty{a}: Spec.LNonEmpty{right(a)}
    case Trim{l, m, b1, b2}: Spec.counts(Spec.LNonEmpty{l}, m, b2)
    case Chain{a, b, e}: right(b)

# Every truncation appearing in the certificate must cover this limit.
def valid(t: Tree, +n: Nat) -> Bool:
  match t:
    case Same{l}: True{}
    case Cat{a, b}: valid(a, n) && valid(b, n)
    case Or{a, b}: valid(a, n) && valid(b, n)
    case NonEmpty{a}: valid(a, n)
    case Trim{l, m, b1, b2}: Nat.is_le(n, b1) && Nat.is_le(n, b2)
    case Chain{a, b, e}: valid(a, n) && valid(b, n)

def sound(+t: Tree, +k: Nat, +w: String, +n: Nat, +v: {valid(t, n) == True{} : Bool}, +e: {Nat.is_le(String.length(w), n) == True{} : Bool}) -> {Spec.mem(left(t), k, w) == Spec.mem(right(t), k, w) : Bool}:
  match t:
    case Same{l}: {==}
    case NonEmpty{a}:
      %sound(a, k, w, n, v, e) : {Spec.mem(left(NonEmpty{a}), k, w) == (Bool.not(String.is_empty(w)) && _) : Bool}
      {==}
    case Or{a, b}:
      %sound(a, k, w, n, L.and_left(valid(a, n), valid(b, n), v), e) : {Spec.mem(left(Or{a, b}), k, w) == (_ || Spec.mem(right(b), k, w)) : Bool}
      %sound(b, k, w, n, L.and_right(valid(a, n), valid(b, n), v), e) : {Spec.mem(left(Or{a, b}), k, w) == (Spec.mem(left(a), k, w) || _) : Bool}
      {==}
    case Trim{l, m, b1, b2}:
      C.counts_bound(l, m, b1, b2, k, w, L.le_trans(String.length(w), n, b1, e, L.and_left(Nat.is_le(n, b1), Nat.is_le(n, b2), v)), L.le_trans(String.length(w), n, b2, e, L.and_right(Nat.is_le(n, b1), Nat.is_le(n, b2), v)))
    case Chain{a, b, link}:
      Equal.trans(Bool, Spec.mem(left(a), k, w), Spec.mem(right(a), k, w), Spec.mem(right(b), k, w), sound(a, k, w, n, L.and_left(valid(a, n), valid(b, n), v), e), Equal.trans(Bool, Spec.mem(right(a), k, w), Spec.mem(left(b), k, w), Spec.mem(right(b), k, w), Equal.cong(Spec.Lang, Bool, l => Spec.mem(l, k, w), right(a), left(b), link), sound(b, k, w, n, L.and_right(valid(a, n), valid(b, n), v), e)))
    case Cat{a, b}:
      match k:
        case 0n:
          %sound(a, 0n, "", n, L.and_left(valid(a, n), valid(b, n), v), L.le_zero(n)) : {Spec.mem(left(Cat{a, b}), 0n, w) == (_ && Spec.mem(right(b), Spec.length(w), w)) : Bool}
          %sound(b, Spec.length(w), w, n, L.and_right(valid(a, n), valid(b, n), v), e) : {Spec.mem(left(Cat{a, b}), 0n, w) == (Spec.mem(left(a), 0n, "") && _) : Bool}
          {==}
        case 1n+i:
          %sound(a, 1n+i, String.take(w, 1n+i), n, L.and_left(valid(a, n), valid(b, n), v), L.le_trans(String.length(String.take(w, 1n+i)), String.length(w), n, L.take_le(w, 1n+i), e)) : {Spec.mem(left(Cat{a, b}), 1n+i, w) == ((_ && Spec.mem(right(b), Spec.length(String.drop(w, 1n+i)), String.drop(w, 1n+i))) || Spec.mem(right(Cat{a, b}), i, w)) : Bool}
          %sound(b, Spec.length(String.drop(w, 1n+i)), String.drop(w, 1n+i), n, L.and_right(valid(a, n), valid(b, n), v), L.le_trans(String.length(String.drop(w, 1n+i)), String.length(w), n, L.drop_le(w, 1n+i), e)) : {Spec.mem(left(Cat{a, b}), 1n+i, w) == ((Spec.mem(left(a), 1n+i, String.take(w, 1n+i)) && _) || Spec.mem(right(Cat{a, b}), i, w)) : Bool}
          %sound(Cat{a, b}, i, w, n, v, e) : {Spec.mem(left(Cat{a, b}), 1n+i, w) == ((Spec.mem(left(a), 1n+i, String.take(w, 1n+i)) && Spec.mem(left(b), Spec.length(String.drop(w, 1n+i)), String.drop(w, 1n+i))) || _) : Bool}
          {==}

def power(+t: Tree, j: Nat) -> Tree:
  match j:
    case 0n: Same{Spec.LEmpty{}}
    case 1n+i: Cat{t, power(t, i)}

def power_left(+j: Nat, +t: Tree) -> {left(power(t, j)) == Spec.power(left(t), j) : Spec.Lang}:
  match j:
    case 0n: {==}
    case 1n+i:
      %power_left(i, t) : {left(power(t, 1n+i)) == Spec.LCat{left(t), _} : Spec.Lang}
      {==}

def power_right(+j: Nat, +t: Tree) -> {right(power(t, j)) == Spec.power(right(t), j) : Spec.Lang}:
  match j:
    case 0n: {==}
    case 1n+i:
      %power_right(i, t) : {right(power(t, 1n+i)) == Spec.LCat{right(t), _} : Spec.Lang}
      {==}

def power_valid(+j: Nat, +t: Tree, +n: Nat, +v: {valid(t, n) == True{} : Bool}) -> {valid(power(t, j), n) == True{} : Bool}:
  match j:
    case 0n: {==}
    case 1n+i:
      %Equal.sym(Bool, valid(t, n), True{}, v) : {(_ && valid(power(t, i), n)) == True{} : Bool}
      power_valid(i, t, n, v)

def pick(b: Bool, t: Tree) -> Tree:
  match b:
    case True{}: t
    case False{}: Same{Spec.LNone{}}

def pick_left(+b: Bool, +t: Tree) -> {left(pick(b, t)) == Bool.pick(Spec.Lang, b, left(t), Spec.LNone{}) : Spec.Lang}:
  match b:
    case True{}: {==}
    case False{}: {==}

def pick_right(+b: Bool, +t: Tree) -> {right(pick(b, t)) == Bool.pick(Spec.Lang, b, right(t), Spec.LNone{}) : Spec.Lang}:
  match b:
    case True{}: {==}
    case False{}: {==}

def pick_valid(+b: Bool, +t: Tree, +n: Nat, v: {valid(t, n) == True{} : Bool}) -> {valid(pick(b, t), n) == True{} : Bool}:
  match b:
    case True{}: v
    case False{}: {==}

def counts(+t: Tree, +m: Nat, n: Nat) -> Tree:
  match n:
    case 0n: Same{Bool.pick(Spec.Lang, Nat.is_eq(m, 0n), Spec.LEmpty{}, Spec.LNone{})}
    case 1n+(+i): Or{counts(t, m, i), pick(Nat.is_le(m, 1n+i), power(t, 1n+i))}

def counts_left(+n: Nat, +t: Tree, +m: Nat) -> {left(counts(t, m, n)) == Spec.counts(left(t), m, n) : Spec.Lang}:
  match n:
    case 0n: {==}
    case 1n+i:
      %counts_left(i, t, m) : {left(counts(t, m, 1n+i)) == Spec.LOr{_, Bool.pick(Spec.Lang, Nat.is_le(m, 1n+i), Spec.power(left(t), 1n+i), Spec.LNone{})} : Spec.Lang}
      %power_left(1n+i, t) : {left(counts(t, m, 1n+i)) == Spec.LOr{left(counts(t, m, i)), Bool.pick(Spec.Lang, Nat.is_le(m, 1n+i), _, Spec.LNone{})} : Spec.Lang}
      %pick_left(Nat.is_le(m, 1n+i), power(t, 1n+i)) : {left(counts(t, m, 1n+i)) == Spec.LOr{left(counts(t, m, i)), _} : Spec.Lang}
      {==}

def counts_right(+n: Nat, +t: Tree, +m: Nat) -> {right(counts(t, m, n)) == Spec.counts(right(t), m, n) : Spec.Lang}:
  match n:
    case 0n: {==}
    case 1n+i:
      %counts_right(i, t, m) : {right(counts(t, m, 1n+i)) == Spec.LOr{_, Bool.pick(Spec.Lang, Nat.is_le(m, 1n+i), Spec.power(right(t), 1n+i), Spec.LNone{})} : Spec.Lang}
      %power_right(1n+i, t) : {right(counts(t, m, 1n+i)) == Spec.LOr{right(counts(t, m, i)), Bool.pick(Spec.Lang, Nat.is_le(m, 1n+i), _, Spec.LNone{})} : Spec.Lang}
      %pick_right(Nat.is_le(m, 1n+i), power(t, 1n+i)) : {right(counts(t, m, 1n+i)) == Spec.LOr{right(counts(t, m, i)), _} : Spec.Lang}
      {==}

def counts_valid(+j: Nat, +t: Tree, +m: Nat, +n: Nat, +v: {valid(t, n) == True{} : Bool}) -> {valid(counts(t, m, j), n) == True{} : Bool}:
  match j:
    case 0n: {==}
    case 1n+i:
      %Equal.sym(Bool, valid(counts(t, m, i), n), True{}, counts_valid(i, t, m, n, v)) : {(_ && valid(pick(Nat.is_le(m, 1n+i), power(t, 1n+i)), n)) == True{} : Bool}
      pick_valid(Nat.is_le(m, 1n+i), power(t, 1n+i), n, power_valid(1n+i, t, n, v))
