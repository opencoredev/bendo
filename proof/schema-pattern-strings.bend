# Bounds for the prefixes and suffixes visited by a split proof.
import Base
import ../src/data/schema-spec.bend as Spec

def contradiction(b: Bool) -> Type:
  match b:
    case False{}: Unit
    case True{}: Empty

def false_true(e: {False{} == True{} : Bool}) -> Empty:
  %e : contradiction(_)
  Unit{}

def absurd(-A: Type, e: Empty) -> A:
  match e:

def le_self(+n: Nat) -> {Nat.is_le(n, n) == True{} : Bool}:
  match n:
    case 0n: {==}
    case 1n+i: le_self(i)

def zero_le(+n: Nat) -> {Nat.is_le(0n, n) == True{} : Bool}:
  match n:
    case 0n: {==}
    case 1n+i: {==}

def le_next(+a: Nat, +b: Nat, e: {Nat.is_le(a, b) == True{} : Bool}) -> {Nat.is_le(a, 1n+b) == True{} : Bool}:
  match a b:
    case 0n 0n: {==}
    case 0n 1n+j: {==}
    case 1n+i 0n: absurd({Nat.is_le(1n+i, 1n) == True{} : Bool}, false_true(e))
    case 1n+i 1n+j: le_next(i, j, e)

def le_trans(+a: Nat, +b: Nat, +c: Nat, ab: {Nat.is_le(a, b) == True{} : Bool}, bc: {Nat.is_le(b, c) == True{} : Bool}) -> {Nat.is_le(a, c) == True{} : Bool}:
  match a b c:
    case 0n _ _: zero_le(c)
    case 1n+i 0n _: absurd({Nat.is_le(1n+i, c) == True{} : Bool}, false_true(ab))
    case 1n+i 1n+j 0n: absurd({Nat.is_le(1n+i, 0n) == True{} : Bool}, false_true(bc))
    case 1n+i 1n+j 1n+k: le_trans(i, j, k, ab, bc)

def prefix_length(+w: String, +j: Nat, e: {Nat.is_le(j, Spec.length(w)) == True{} : Bool}) -> {Spec.length(String.take(w, j)) == j : Nat}:
  match w j:
    case SNil{} 0n: {==}
    case SNil{} 1n+i: absurd({0n == 1n+i : Nat}, false_true(e))
    case SCon{h, t} 0n: {==}
    case SCon{h, t} 1n+i:
      %prefix_length(t, i, e) : {1n+Spec.length(String.take(t, i)) == 1n+_ : Nat}
      {==}

def prefix_le(+w: String, +j: Nat) -> {Nat.is_le(Spec.length(String.take(w, j)), Spec.length(w)) == True{} : Bool}:
  match w j:
    case SNil{} _: {==}
    case SCon{h, t} 0n: {==}
    case SCon{h, t} 1n+i: prefix_le(t, i)

def suffix_le(+w: String, +j: Nat) -> {Nat.is_le(Spec.length(String.drop(w, j)), Spec.length(w)) == True{} : Bool}:
  match w j:
    case SNil{} _: {==}
    case SCon{h, t} 0n: le_self(1n+Spec.length(t))
    case SCon{h, t} 1n+i: le_next(Spec.length(String.drop(t, i)), Spec.length(t), suffix_le(t, i))

def le_previous(+a: Nat, +b: Nat, e: {Nat.is_le(1n+a, b) == True{} : Bool}) -> {Nat.is_le(a, b) == True{} : Bool}:
  match a b:
    case 0n _: zero_le(b)
    case 1n+i 0n: absurd({Nat.is_le(1n+i, 0n) == True{} : Bool}, false_true(e))
    case 1n+i 1n+j: le_previous(i, j, e)

def take_full(+w: String) -> {String.take(w, Spec.length(w)) == w : String}:
  match w:
    case SNil{}: {==}
    case SCon{h, t}:
      %take_full(t) : {SCon{h, String.take(t, Spec.length(t))} == SCon{h, _} : String}
      {==}

def length_eq(+w: String) -> {String.length(w) == Spec.length(w) : Nat}:
  match w:
    case SNil{}: {==}
    case SCon{h, t}:
      %length_eq(t) : {1n+String.length(t) == 1n+_ : Nat}
      {==}
