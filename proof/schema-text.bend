# Scalar validity and scalar counts agree with the specification.
import Base
import ../src/data/json.bend as J
import ../src/data/utf8.bend as U
import ../src/data/decimal.bend as D
import ../src/data/schema-spec.bend as Spec
import ./chunked-arith.bend as A

def scalars_go(+s: String, +ok: Bool) -> {J.scalar_go(s, ok) == (ok && Spec.scalars(s)) : Bool}:
  match s ok:
    case SNil{} False{}: {==}
    case SNil{} True{}: {==}
    case SCon{Chr{c}, t} False{}: {==}
    case SCon{Chr{c}, t} True{}: scalars_go(t, U.scalar(c))

def scalars_equiv(+s: String) -> {J.scalars(s) == Spec.scalars(s) : Bool}:
  scalars_go(s, True{})

def length_go(+s: String, +n: Nat) -> {D.length_go(s, n) == Nat.add(Spec.length(s), n) : Nat}:
  match s:
    case SNil{}: {==}
    case SCon{h, t}:
      %A.add_succ_r(Spec.length(t), n) : {D.length_go(t, 1n+n) == _ : Nat}
      length_go(t, 1n+n)

def length_equiv(+s: String) -> {D.length(s) == Spec.length(s) : Nat}:
  %A.add_zero_r(Spec.length(s)) : {D.length(s) == _ : Nat}
  length_go(s, 0n)
