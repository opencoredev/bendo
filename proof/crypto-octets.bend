import Base
import ../src/crypto/octets.bend as O

# Independent specification: each element is at most 255.
def spec(xs: List<&2, U32>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case +x <> t:
      (x <= 255 : U32) && spec(t)

def and_true(+b: Bool) -> {b && True{} == b : Bool}:
  match b:
    case False{}:
      {==}
    case True{}:
      {==}

def and_assoc(+a: Bool, +b: Bool, +c: Bool) -> {(a && b) && c == a && (b && c) : Bool}:
  match a:
    case False{}:
      {==}
    case True{}:
      {==}

def valid_acc(+xs: List<&2, U32>, +ok: Bool) -> {O.valid_acc(xs, ok) == ok && spec(xs) : Bool}:
  match xs:
    case Nil{}:
      Equal.sym(Bool, ok && True{}, ok, and_true(ok))
    case +x <> +t:
      Equal.trans(Bool, O.valid_acc(t, ok && (x <= 255 : U32)), (ok && (x <= 255 : U32)) && spec(t), ok && ((x <= 255 : U32) && spec(t)), valid_acc(t, ok && (x <= 255 : U32)), and_assoc(ok, (x <= 255 : U32), spec(t)))

def valid(+xs: List<&2, U32>, ok: {O.valid(xs) == True{} : Bool}) -> {spec(xs) == True{} : Bool}:
  Equal.trans(Bool, spec(xs), O.valid(xs), True{}, Equal.sym(Bool, O.valid(xs), spec(xs), valid_acc(xs, True{})), ok)
