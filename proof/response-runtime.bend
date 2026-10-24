# Equivalence of stack-safe response operations to their structural specs.
import Base
import ../src/http/response.bend as R
import ../src/data/utf8.bend as U
import ./utf8.bend as Utf8Proof
import ./hot-path.bend as HP

def add_zero(+n: Nat) -> {Nat.add(n, 0n) == n : Nat}:
  match n:
    case 0n:
      {==}
    case 1n+p:
      %add_zero(p) : {1n+Nat.add(p, 0n) == 1n+_ : Nat}
      {==}

def add_succ(+a: Nat, +b: Nat) -> {Nat.add(a, 1n+b) == 1n+Nat.add(a, b) : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+p:
      %add_succ(p, b) : {1n+Nat.add(p, 1n+b) == 1n+_ : Nat}
      {==}

def length_go(+xs: List<&2, U32>, +n: Nat) -> {R.length_go(xs, n) == Nat.add(List.length(&2, U32, xs), n) : Nat}:
  match xs:
    case Nil{}:
      {==}
    case c <> t:
      Equal.trans(Nat, R.length_go(t, 1n+n), Nat.add(List.length(&2, U32, t), 1n+n), 1n+Nat.add(List.length(&2, U32, t), n), length_go(t, 1n+n), add_succ(List.length(&2, U32, t), n))

def length(+xs: List<&2, U32>) -> {R.length(xs) == List.length(&2, U32, xs) : Nat}:
  Equal.trans(Nat, R.length(xs), Nat.add(List.length(&2, U32, xs), 0n), List.length(&2, U32, xs), length_go(xs, 0n), add_zero(List.length(&2, U32, xs)))

def scalar(+c: U32, ok: {U.scalar(c) == True{} : Bool}) -> {R.scalar(c) == c : U32}:
  %Equal.sym(Bool, U.scalar(c), True{}, ok) : {R.scalar_valid(c, _) == c : U32}
  {==}

def scalars_go(+s: String, +acc: String, +ok: {U.valid_spec(s) == True{} : Bool}) -> {R.scalars_go(s, acc) == String.reverse.go(acc, s) : String}:
  match s:
    case SNil{}:
      {==}
    case SCon{Chr{c}, t}:
      %Equal.sym(U32, R.scalar(c), c, scalar(c, Utf8Proof.and_left(U.scalar(c), U.valid_spec(t), ok))) : {R.scalars_go(t, SCon{Chr{_}, acc}) == String.reverse.go(acc, SCon{Chr{c}, t}) : String}
      scalars_go(t, SCon{Chr{c}, acc}, Utf8Proof.and_right(U.scalar(c), U.valid_spec(t), ok))

def scalars(+s: String, ok: {U.valid(s) == True{} : Bool}) -> {R.scalars(s) == s : String}:
  scalars_go(s, "", Utf8Proof.valid_spec_of(s, ok))

def utf8(+s: String, +ok: {U.valid(s) == True{} : Bool}) -> {U.decode(R.utf8(s)) == Some{s} : Maybe<&2, String>}:
  %HP.utf8_spec_equiv(s) : {U.decode(_) == Some{s} : Maybe<&2, String>}
  %Equal.sym(String, R.scalars(s), s, scalars(s, ok)) : {U.decode(U.encode(_)) == Some{s} : Maybe<&2, String>}
  Utf8Proof.roundtrip(s, ok)
