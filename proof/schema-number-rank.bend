# Exact natural sums represented by the runtime's decimal digit ranks.
import Base
import ../src/data/decimal.bend as D
import ../src/data/decimal-natural.bend as N
import ../src/data/decimal-coefficient.bend as Co
import ../src/data/schema-spec.bend as Spec
import ./schema-number-parts.bend as P
import ./schema-number-natural.bend as A
import ./schema-number-natural-cmp.bend as C
import ./schema-number-natural-valid.bend as V
import ./schema-number-coefficient.bend as K
import ./schema-number-arith.bend as R

def up_value(+p: Spec.Parts) -> {C.value(D.up(P.convert(p))) == Spec.up(p) : Nat}:
  match p:
    case Spec.Parts{n, d, s, False{}, x}: K.read_value(x)
    case Spec.Parts{n, d, s, True{}, x}: {==}

def down_value(+p: Spec.Parts) -> {C.value(D.down(P.convert(p))) == Spec.down(p) : Nat}:
  match p:
    case Spec.Parts{n, d, s, False{}, x}: {==}
    case Spec.Parts{n, d, s, True{}, x}: K.read_value(x)

def exponent_valid(p: Spec.Parts) -> Data:
  Spec.Parts{n, d, s, en, x} = p
  {Spec.digits(x) == True{} : Bool}

def up_valid(+p: Spec.Parts, e: exponent_valid(p)) -> C.valid(D.up(P.convert(p))):
  match p:
    case Spec.Parts{n, d, s, False{}, x}: K.read_valid(x, e)
    case Spec.Parts{n, d, s, True{}, x}: Unit{}

def down_valid(+p: Spec.Parts, e: exponent_valid(p)) -> C.valid(D.down(P.convert(p))):
  match p:
    case Spec.Parts{n, d, s, False{}, x}: Unit{}
    case Spec.Parts{n, d, s, True{}, x}: K.read_valid(x, e)

def scale(+p: Spec.Parts) -> {D.scale(P.convert(p)) == Spec.scale(p) : Nat}:
  match p:
    case Spec.Parts{n, d, s, en, x}: {==}

def shift(+a: Spec.Parts, +b: Spec.Parts) -> Nat:
  Nat.add(Nat.add(Spec.up(a), Spec.scale(b)), Spec.down(b))

def shift_value(+a: Spec.Parts, +b: Spec.Parts) -> {C.value(N.add(N.count(D.scale(P.convert(b)), D.up(P.convert(a))), D.down(P.convert(b)))) == shift(a, b) : Nat}:
  %Equal.sym(Nat, C.value(N.add(N.count(D.scale(P.convert(b)), D.up(P.convert(a))), D.down(P.convert(b)))), Nat.add(C.value(N.count(D.scale(P.convert(b)), D.up(P.convert(a)))), C.value(D.down(P.convert(b)))), A.add_value(N.count(D.scale(P.convert(b)), D.up(P.convert(a))), D.down(P.convert(b)))) : {_ == shift(a, b) : Nat}
  %Equal.sym(Nat, C.value(N.count(D.scale(P.convert(b)), D.up(P.convert(a)))), Nat.add(D.scale(P.convert(b)), C.value(D.up(P.convert(a)))), A.count_value(D.scale(P.convert(b)), D.up(P.convert(a)))) : {Nat.add(_, C.value(D.down(P.convert(b)))) == shift(a, b) : Nat}
  %Equal.sym(Nat, D.scale(P.convert(b)), Spec.scale(b), scale(b)) : {Nat.add(Nat.add(_, C.value(D.up(P.convert(a)))), C.value(D.down(P.convert(b)))) == shift(a, b) : Nat}
  %Equal.sym(Nat, C.value(D.up(P.convert(a))), Spec.up(a), up_value(a)) : {Nat.add(Nat.add(Spec.scale(b), _), C.value(D.down(P.convert(b)))) == shift(a, b) : Nat}
  %Equal.sym(Nat, C.value(D.down(P.convert(b))), Spec.down(b), down_value(b)) : {Nat.add(Nat.add(Spec.scale(b), Spec.up(a)), _) == shift(a, b) : Nat}
  Equal.cong(Nat, Nat, x => Nat.add(x, Spec.down(b)), Nat.add(Spec.scale(b), Spec.up(a)), Nat.add(Spec.up(a), Spec.scale(b)), R.add_comm(Spec.scale(b), Spec.up(a)))

def rank_value(+a: Spec.Parts, +b: Spec.Parts, +x: N.Digits) -> {C.value(D.rank(P.convert(a), P.convert(b), x)) == Nat.add(Co.length(x), shift(a, b)) : Nat}:
  Equal.trans(Nat,
    C.value(D.rank(P.convert(a), P.convert(b), x)),
    Nat.add(Co.length(x), C.value(N.add(N.count(D.scale(P.convert(b)), D.up(P.convert(a))), D.down(P.convert(b))))),
    Nat.add(Co.length(x), shift(a, b)),
    A.count_value(Co.length(x), N.add(N.count(D.scale(P.convert(b)), D.up(P.convert(a))), D.down(P.convert(b)))),
    Equal.cong(Nat, Nat, n => Nat.add(Co.length(x), n), C.value(N.add(N.count(D.scale(P.convert(b)), D.up(P.convert(a))), D.down(P.convert(b)))), shift(a, b), shift_value(a, b)))

def rank_valid(+a: Spec.Parts, +b: Spec.Parts, +x: N.Digits, ea: exponent_valid(a), eb: exponent_valid(b)) -> C.valid(D.rank(P.convert(a), P.convert(b), x)):
  V.count(Co.length(x), N.add(N.count(D.scale(P.convert(b)), D.up(P.convert(a))), D.down(P.convert(b))), V.add(N.count(D.scale(P.convert(b)), D.up(P.convert(a))), D.down(P.convert(b)), V.count(D.scale(P.convert(b)), D.up(P.convert(a)), up_valid(a, ea)), down_valid(b, eb)))

def rank_cmp(+a: Spec.Parts, +b: Spec.Parts, +x: N.Digits, +y: N.Digits, +ea: exponent_valid(a), +eb: exponent_valid(b)) -> {N.cmp(D.rank(P.convert(a), P.convert(b), x), D.rank(P.convert(b), P.convert(a), y)) == Nat.cmp(Nat.add(Co.length(x), shift(a, b)), Nat.add(Co.length(y), shift(b, a))) : Cmp}:
  %Equal.sym(Cmp, N.cmp(D.rank(P.convert(a), P.convert(b), x), D.rank(P.convert(b), P.convert(a), y)), Nat.cmp(C.value(D.rank(P.convert(a), P.convert(b), x)), C.value(D.rank(P.convert(b), P.convert(a), y))), C.cmp(D.rank(P.convert(a), P.convert(b), x), D.rank(P.convert(b), P.convert(a), y), rank_valid(a, b, x, ea, eb), rank_valid(b, a, y, eb, ea))) : {_ == Nat.cmp(Nat.add(Co.length(x), shift(a, b)), Nat.add(Co.length(y), shift(b, a))) : Cmp}
  %Equal.sym(Nat, C.value(D.rank(P.convert(a), P.convert(b), x)), Nat.add(Co.length(x), shift(a, b)), rank_value(a, b, x)) : {Nat.cmp(_, C.value(D.rank(P.convert(b), P.convert(a), y))) == Nat.cmp(Nat.add(Co.length(x), shift(a, b)), Nat.add(Co.length(y), shift(b, a))) : Cmp}
  Equal.cong(Nat, Cmp, n => Nat.cmp(Nat.add(Co.length(x), shift(a, b)), n), C.value(D.rank(P.convert(b), P.convert(a), y)), Nat.add(Co.length(y), shift(b, a)), rank_value(b, a, y))
