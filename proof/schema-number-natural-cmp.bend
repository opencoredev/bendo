# Numeric meaning of least-significant-first decimal digits.
import Base
import ../src/data/decimal-natural.bend as D
import ./schema-number-arith.bend as Arith
import ./chunked-arith.bend as A
import ../src/router/codec-bits.bend as Bits

def value(ds: D.Digits) -> Nat:
  match ds:
    case D.End{}: 0n
    case D.Digit{d, t}: Nat.add(d, Nat.mul(10n, value(t)))

def valid(+ds: D.Digits) -> Type:
  match ds:
    case D.End{}: Unit
    case D.Digit{d, t}: {Nat.is_le(d, 9n) == True{} : Bool} & valid(t)

# Moving to the next high digit adds a common block of ten.
def digit_succ(+d: Nat, +x: Nat) -> {Nat.add(d, Nat.mul(10n, 1n+x)) == 10n+Nat.add(d, Nat.mul(10n, x)) : Nat}:
  %Equal.sym(Nat, Nat.mul(10n, 1n+x), Nat.add(10n, Nat.mul(10n, x)), Arith.mul_succ_r(10n, x)) : {Nat.add(d, _) == 10n+Nat.add(d, Nat.mul(10n, x)) : Nat}
  Arith.add_swap(d, 10n, Nat.mul(10n, x))

def small_big(+d: Nat, +z: Nat, bound: {Nat.is_le(d, 9n) == True{} : Bool}) -> {Nat.cmp(d, 10n+z) == LT{} : Cmp}:
  match d:
    case 0n: {==}
    case 1n: {==}
    case 2n: {==}
    case 3n: {==}
    case 4n: {==}
    case 5n: {==}
    case 6n: {==}
    case 7n: {==}
    case 8n: {==}
    case 9n: {==}
    case 10n+k: Bits.absurd({Nat.cmp(10n+k, 10n+z) == LT{} : Cmp}, Bits.false_true(bound))

def big_small(+d: Nat, +z: Nat, bound: {Nat.is_le(d, 9n) == True{} : Bool}) -> {Nat.cmp(10n+z, d) == GT{} : Cmp}:
  match d:
    case 0n: {==}
    case 1n: {==}
    case 2n: {==}
    case 3n: {==}
    case 4n: {==}
    case 5n: {==}
    case 6n: {==}
    case 7n: {==}
    case 8n: {==}
    case 9n: {==}
    case 10n+k: Bits.absurd({Nat.cmp(10n+z, 10n+k) == GT{} : Cmp}, Bits.false_true(bound))

def digit_priority(+x: Nat, +y: Nat, +d: Nat, +e: Nat, bd: {Nat.is_le(d, 9n) == True{} : Bool}, be: {Nat.is_le(e, 9n) == True{} : Bool}) -> {Nat.cmp(Nat.add(d, Nat.mul(10n, x)), Nat.add(e, Nat.mul(10n, y))) == D.choose(Nat.cmp(x, y), Nat.cmp(d, e)) : Cmp}:
  match x y:
    case 0n 0n:
      %Equal.sym(Nat, Nat.add(d, 0n), d, A.add_zero_r(d)) : {Nat.cmp(_, Nat.add(e, 0n)) == Nat.cmp(d, e) : Cmp}
      %Equal.sym(Nat, Nat.add(e, 0n), e, A.add_zero_r(e)) : {Nat.cmp(d, _) == Nat.cmp(d, e) : Cmp}
      {==}
    case 0n 1n+q:
      %Equal.sym(Nat, Nat.add(d, 0n), d, A.add_zero_r(d)) : {Nat.cmp(_, Nat.add(e, Nat.mul(10n, 1n+q))) == LT{} : Cmp}
      %Equal.sym(Nat, Nat.add(e, Nat.mul(10n, 1n+q)), 10n+Nat.add(e, Nat.mul(10n, q)), digit_succ(e, q)) : {Nat.cmp(d, _) == LT{} : Cmp}
      small_big(d, Nat.add(e, Nat.mul(10n, q)), bd)
    case 1n+p 0n:
      %Equal.sym(Nat, Nat.add(e, 0n), e, A.add_zero_r(e)) : {Nat.cmp(Nat.add(d, Nat.mul(10n, 1n+p)), _) == GT{} : Cmp}
      %Equal.sym(Nat, Nat.add(d, Nat.mul(10n, 1n+p)), 10n+Nat.add(d, Nat.mul(10n, p)), digit_succ(d, p)) : {Nat.cmp(_, e) == GT{} : Cmp}
      big_small(e, Nat.add(d, Nat.mul(10n, p)), be)
    case 1n+p 1n+q:
      %Equal.sym(Nat, Nat.add(d, Nat.mul(10n, 1n+p)), 10n+Nat.add(d, Nat.mul(10n, p)), digit_succ(d, p)) : {Nat.cmp(_, Nat.add(e, Nat.mul(10n, 1n+q))) == D.choose(Nat.cmp(p, q), Nat.cmp(d, e)) : Cmp}
      %Equal.sym(Nat, Nat.add(e, Nat.mul(10n, 1n+q)), 10n+Nat.add(e, Nat.mul(10n, q)), digit_succ(e, q)) : {Nat.cmp(10n+Nat.add(d, Nat.mul(10n, p)), _) == D.choose(Nat.cmp(p, q), Nat.cmp(d, e)) : Cmp}
      digit_priority(p, q, d, e, bd, be)

def choose_assoc(+a: Cmp, +b: Cmp, +c: Cmp) -> {D.choose(a, D.choose(b, c)) == D.choose(D.choose(a, b), c) : Cmp}:
  match a:
    case LT{}: {==}
    case EQ{}: {==}
    case GT{}: {==}

def choose_eq(+c: Cmp) -> {D.choose(c, EQ{}) == c : Cmp}:
  match c:
    case LT{}: {==}
    case EQ{}: {==}
    case GT{}: {==}

# A more significant comparison overrides the accumulated lower positions.
def combine(+x: Nat, +y: Nat, +d: Nat, +e: Nat, +c: Cmp, bd: {Nat.is_le(d, 9n) == True{} : Bool}, be: {Nat.is_le(e, 9n) == True{} : Bool}) -> {D.choose(Nat.cmp(x, y), D.choose(Nat.cmp(d, e), c)) == D.choose(Nat.cmp(Nat.add(d, Nat.mul(10n, x)), Nat.add(e, Nat.mul(10n, y))), c) : Cmp}:
  Equal.trans(Cmp,
    D.choose(Nat.cmp(x, y), D.choose(Nat.cmp(d, e), c)),
    D.choose(D.choose(Nat.cmp(x, y), Nat.cmp(d, e)), c),
    D.choose(Nat.cmp(Nat.add(d, Nat.mul(10n, x)), Nat.add(e, Nat.mul(10n, y))), c),
    choose_assoc(Nat.cmp(x, y), Nat.cmp(d, e), c),
    Equal.cong(Cmp, Cmp, k => D.choose(k, c),
      D.choose(Nat.cmp(x, y), Nat.cmp(d, e)),
      Nat.cmp(Nat.add(d, Nat.mul(10n, x)), Nat.add(e, Nat.mul(10n, y))),
      Equal.sym(Cmp,
        Nat.cmp(Nat.add(d, Nat.mul(10n, x)), Nat.add(e, Nat.mul(10n, y))),
        D.choose(Nat.cmp(x, y), Nat.cmp(d, e)),
        digit_priority(x, y, d, e, bd, be))))

def cmp_go(+a: D.Digits, +b: D.Digits, +c: Cmp, va: valid(a), vb: valid(b)) -> {D.cmp_go(a, b, c) == D.choose(Nat.cmp(value(a), value(b)), c) : Cmp}:
  match a b:
    case D.End{} D.End{}: {==}
    case D.Digit{+d, +t} D.End{}:
      (bd, vt) = va
      Equal.trans(Cmp,
        D.cmp_go(t, D.End{}, D.choose(Nat.cmp(d, 0n), c)),
        D.choose(Nat.cmp(value(t), 0n), D.choose(Nat.cmp(d, 0n), c)),
        D.choose(Nat.cmp(value(D.Digit{d, t}), 0n), c),
        cmp_go(t, D.End{}, D.choose(Nat.cmp(d, 0n), c), vt, Unit{}),
        combine(value(t), 0n, d, 0n, c, bd, {==}))
    case D.End{} D.Digit{+e, +u}:
      (be, vu) = vb
      Equal.trans(Cmp,
        D.cmp_go(D.End{}, u, D.choose(Nat.cmp(0n, e), c)),
        D.choose(Nat.cmp(0n, value(u)), D.choose(Nat.cmp(0n, e), c)),
        D.choose(Nat.cmp(0n, value(D.Digit{e, u})), c),
        cmp_go(D.End{}, u, D.choose(Nat.cmp(0n, e), c), Unit{}, vu),
        combine(0n, value(u), 0n, e, c, {==}, be))
    case D.Digit{+d, +t} D.Digit{+e, +u}:
      (bd, vt) = va
      (be, vu) = vb
      Equal.trans(Cmp,
        D.cmp_go(t, u, D.choose(Nat.cmp(d, e), c)),
        D.choose(Nat.cmp(value(t), value(u)), D.choose(Nat.cmp(d, e), c)),
        D.choose(Nat.cmp(value(D.Digit{d, t}), value(D.Digit{e, u})), c),
        cmp_go(t, u, D.choose(Nat.cmp(d, e), c), vt, vu),
        combine(value(t), value(u), d, e, c, bd, be))

def cmp(+a: D.Digits, +b: D.Digits, va: valid(a), vb: valid(b)) -> {D.cmp(a, b) == Nat.cmp(value(a), value(b)) : Cmp}:
  Equal.trans(Cmp, D.cmp(a, b), D.choose(Nat.cmp(value(a), value(b)), EQ{}), Nat.cmp(value(a), value(b)),
    cmp_go(a, b, EQ{}, va, vb), choose_eq(Nat.cmp(value(a), value(b))))
