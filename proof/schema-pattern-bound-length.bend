# Length facts used by the bounded regular-language interpretation.
import Base

def absurd(-A: Type, e: Empty) -> A:
  match e:

def false_true(e: {False{} == True{} : Bool}) -> Empty:
  %e : Bool.pick(Type, _, Empty, Unit)
  Unit{}

def le_refl(+n: Nat) -> {Nat.is_le(n, n) == True{} : Bool}:
  match n:
    case 0n: {==}
    case 1n+i: le_refl(i)

def le_zero(+n: Nat) -> {Nat.is_le(0n, n) == True{} : Bool}:
  match n:
    case 0n: {==}
    case 1n+i: {==}

def le_trans(+a: Nat, +b: Nat, +c: Nat, ab: {Nat.is_le(a, b) == True{} : Bool}, bc: {Nat.is_le(b, c) == True{} : Bool}) -> {Nat.is_le(a, c) == True{} : Bool}:
  match a b c:
    case 0n _ _: le_zero(c)
    case 1n+i 0n _: absurd({Nat.is_le(1n+i, c) == True{} : Bool}, false_true(ab))
    case 1n+i 1n+j 0n: absurd({Nat.is_le(1n+i, 0n) == True{} : Bool}, false_true(bc))
    case 1n+i 1n+j 1n+k: le_trans(i, j, k, ab, bc)

def le_succ(+a: Nat, +b: Nat, e: {Nat.is_le(a, b) == True{} : Bool}) -> {Nat.is_le(a, 1n+b) == True{} : Bool}:
  match a b:
    case 0n _: {==}
    case 1n+i 0n: absurd({Nat.is_le(1n+i, 1n+0n) == True{} : Bool}, false_true(e))
    case 1n+i 1n+j: le_succ(i, j, e)

def lt_of_le_lt(+a: Nat, +b: Nat, +c: Nat, ab: {Nat.is_le(a, b) == True{} : Bool}, bc: {Nat.is_lt(b, c) == True{} : Bool}) -> {Nat.is_lt(a, c) == True{} : Bool}:
  match a b c:
    case _ 0n 0n: absurd({Nat.is_lt(a, 0n) == True{} : Bool}, false_true(bc))
    case _ 1n+j 0n: absurd({Nat.is_lt(a, 0n) == True{} : Bool}, false_true(bc))
    case 0n _ 1n+k: {==}
    case 1n+i 0n 1n+k: absurd({Nat.is_lt(1n+i, 1n+k) == True{} : Bool}, false_true(ab))
    case 1n+i 1n+j 1n+k: lt_of_le_lt(i, j, k, ab, bc)

def lt_succ_of_le(+a: Nat, +b: Nat, e: {Nat.is_le(a, b) == True{} : Bool}) -> {Nat.is_lt(a, 1n+b) == True{} : Bool}:
  match a b:
    case 0n _: {==}
    case 1n+i 0n: absurd({Nat.is_lt(1n+i, 1n+0n) == True{} : Bool}, false_true(e))
    case 1n+i 1n+j: lt_succ_of_le(i, j, e)

def take_le(+w: String, +k: Nat) -> {Nat.is_le(String.length(String.take(w, k)), String.length(w)) == True{} : Bool}:
  match w k:
    case SNil{} _: {==}
    case SCon{h, t} 0n: {==}
    case SCon{h, t} 1n+i: take_le(t, i)

def drop_le(+w: String, +k: Nat) -> {Nat.is_le(String.length(String.drop(w, k)), String.length(w)) == True{} : Bool}:
  match w k:
    case SNil{} _: {==}
    case SCon{h, t} 0n: le_refl(1n+String.length(t))
    case SCon{h, t} 1n+i: le_succ(String.length(String.drop(t, i)), String.length(t), drop_le(t, i))

def and_left(+a: Bool, -b: Bool, e: {(a && b) == True{} : Bool}) -> {a == True{} : Bool}:
  match a:
    case True{}: {==}
    case False{}: e

def and_right(+a: Bool, -b: Bool, e: {(a && b) == True{} : Bool}) -> {b == True{} : Bool}:
  match a:
    case True{}: e
    case False{}: absurd({b == True{} : Bool}, false_true(e))

def and_false(+a: Bool) -> {(a && False{}) == False{} : Bool}:
  match a:
    case True{}: {==}
    case False{}: {==}

def or_false(+a: Bool) -> {(a || False{}) == a : Bool}:
  match a:
    case True{}: {==}
    case False{}: {==}

def and_false_or(+a: Bool) -> {((a && False{}) || False{}) == False{} : Bool}:
  match a:
    case True{}: {==}
    case False{}: {==}

def add_succ(+a: Nat, -b: Nat) -> {Nat.add(a, 1n+b) == 1n+Nat.add(a, b) : Nat}:
  match a:
    case 0n: {==}
    case 1n+i:
      %add_succ(i, b) : {1n+Nat.add(i, 1n+b) == 1n+_ : Nat}
      {==}

def le_extra(+extra: Nat, +a: Nat) -> {Nat.is_le(a, Nat.add(extra, a)) == True{} : Bool}:
  match extra:
    case 0n: le_refl(a)
    case 1n+i: le_succ(a, Nat.add(i, a), le_extra(i, a))

def add_zero(+a: Nat) -> {Nat.add(a, 0n) == a : Nat}:
  match a:
    case 0n: {==}
    case 1n+i:
      %add_zero(i) : {1n+Nat.add(i, 0n) == 1n+_ : Nat}
      {==}

def sub_zero(+a: Nat) -> {Nat.sub(a, 0n) == a : Nat}:
  match a:
    case 0n: {==}
    case 1n+i: {==}

def decompose(+a: Nat, +b: Nat, e: {Nat.is_le(a, b) == True{} : Bool}) -> {b == Nat.add(Nat.sub(b, a), a) : Nat}:
  match a b:
    case 0n _:
      %Equal.sym(Nat, Nat.sub(b, 0n), b, sub_zero(b)) : {b == Nat.add(_, 0n) : Nat}
      Equal.sym(Nat, Nat.add(b, 0n), b, add_zero(b))
    case 1n+i 0n: absurd({0n == Nat.add(Nat.sub(0n, 1n+i), 1n+i) : Nat}, false_true(e))
    case 1n+i 1n+j:
      %Equal.sym(Nat, Nat.add(Nat.sub(j, i), 1n+i), 1n+Nat.add(Nat.sub(j, i), i), add_succ(Nat.sub(j, i), i)) : {1n+j == _ : Nat}
      %decompose(i, j, e) : {1n+j == 1n+_ : Nat}
      {==}
