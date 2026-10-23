# Decimal digit bounds survive the tail-recursive arithmetic operations.
import Base
import ../src/data/decimal-natural.bend as D
import ./schema-number-natural-cmp.bend as C
import ./chunked-arith.bend as A
import ../src/router/codec-bits.bend as Bits

def le_prefix(+x: Nat, +b: Nat, +y: Nat, bound: {Nat.is_le(b, y) == True{} : Bool}) -> {Nat.is_le(b, Nat.add(x, y)) == True{} : Bool}:
  match x:
    case 0n: bound
    case 1n+p: A.le_succ_r(b, Nat.add(p, y), le_prefix(p, b, y, bound))

def add_le(+a: Nat, +b: Nat, +x: Nat, +y: Nat, ba: {Nat.is_le(a, x) == True{} : Bool}, bb: {Nat.is_le(b, y) == True{} : Bool}) -> {Nat.is_le(Nat.add(a, b), Nat.add(x, y)) == True{} : Bool}:
  match a x:
    case 0n x: le_prefix(x, b, y, bb)
    case 1n+p 0n:
      Bits.absurd({Nat.is_le(Nat.add(1n+p, b), y) == True{} : Bool}, Bits.false_true(ba))
    case 1n+p 1n+q: add_le(p, b, q, y, ba, bb)

# Two decimal digits and a one-bit carry sum to at most nineteen.
def sum_bound(+c: Nat, +d: Nat, +e: Nat, bc: {Nat.is_le(c, 1n) == True{} : Bool}, bd: {Nat.is_le(d, 9n) == True{} : Bool}, be: {Nat.is_le(e, 9n) == True{} : Bool}) -> {Nat.is_le(Nat.add(c, Nat.add(d, e)), 19n) == True{} : Bool}:
  add_le(c, Nat.add(d, e), 1n, 18n, bc, add_le(d, e, 9n, 9n, bd, be))

def low(+n: Nat, bound: {Nat.is_le(n, 19n) == True{} : Bool}) -> {Nat.is_le(D.low(n), 9n) == True{} : Bool}:
  match n:
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
    case 10n+k: bound

def carry(+n: Nat) -> {Nat.is_le(D.carry(n), 1n) == True{} : Bool}:
  match n:
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
    case 10n+k: {==}

def last(+c: Nat, bound: {Nat.is_le(c, 1n) == True{} : Bool}) -> C.valid(D.last(c)):
  match c:
    case 0n: Unit{}
    case 1n: ({==}, Unit{})
    case 2n+k: Bits.absurd(C.valid(D.last(2n+k)), Bits.false_true(bound))

def reverse_go(+ds: D.Digits, +acc: D.Digits, vd: C.valid(ds), va: C.valid(acc)) -> C.valid(D.reverse_go(ds, acc)):
  match ds:
    case D.End{}: va
    case D.Digit{+d, +t}:
      (bd, vt) = vd
      reverse_go(t, D.Digit{d, acc}, vt, (bd, va))

def reverse(+ds: D.Digits, vd: C.valid(ds)) -> C.valid(D.reverse(ds)):
  reverse_go(ds, D.End{}, vd, Unit{})

def add_go(+a: D.Digits, +b: D.Digits, +c: Nat, +acc: D.Digits, va: C.valid(a), vb: C.valid(b), bc: {Nat.is_le(c, 1n) == True{} : Bool}, vacc: C.valid(acc)) -> C.valid(D.add_go(a, b, c, acc)):
  match a b:
    case D.End{} D.End{}: reverse_go(acc, D.last(c), vacc, last(c, bc))
    case D.Digit{+d, +t} D.End{}:
      (bd, vt) = va
      +n = Nat.add(c, Nat.add(d, 0n))
      add_go(t, D.End{}, D.carry(n), D.Digit{D.low(n), acc}, vt, Unit{}, carry(n), (low(n, sum_bound(c, d, 0n, bc, bd, {==})), vacc))
    case D.End{} D.Digit{+e, +u}:
      (be, vu) = vb
      +n = Nat.add(c, e)
      add_go(D.End{}, u, D.carry(n), D.Digit{D.low(n), acc}, Unit{}, vu, carry(n), (low(n, sum_bound(c, 0n, e, bc, {==}, be)), vacc))
    case D.Digit{+d, +t} D.Digit{+e, +u}:
      (bd, vt) = va
      (be, vu) = vb
      +n = Nat.add(c, Nat.add(d, e))
      add_go(t, u, D.carry(n), D.Digit{D.low(n), acc}, vt, vu, carry(n), (low(n, sum_bound(c, d, e, bc, bd, be)), vacc))

def add(+a: D.Digits, +b: D.Digits, va: C.valid(a), vb: C.valid(b)) -> C.valid(D.add(a, b)):
  add_go(a, b, 0n, D.End{}, va, vb, {==}, Unit{})

def increment_go(+ds: D.Digits, +acc: D.Digits, vd: C.valid(ds), va: C.valid(acc)) -> C.valid(D.increment_go(ds, acc)):
  match ds:
    case D.End{}: reverse_go(acc, D.Digit{1n, D.End{}}, va, ({==}, Unit{}))
    case D.Digit{0n, +t}:
      (bd, vt) = vd
      reverse_go(acc, D.Digit{1n, t}, va, ({==}, vt))
    case D.Digit{1n, +t}:
      (bd, vt) = vd
      reverse_go(acc, D.Digit{2n, t}, va, ({==}, vt))
    case D.Digit{2n, +t}:
      (bd, vt) = vd
      reverse_go(acc, D.Digit{3n, t}, va, ({==}, vt))
    case D.Digit{3n, +t}:
      (bd, vt) = vd
      reverse_go(acc, D.Digit{4n, t}, va, ({==}, vt))
    case D.Digit{4n, +t}:
      (bd, vt) = vd
      reverse_go(acc, D.Digit{5n, t}, va, ({==}, vt))
    case D.Digit{5n, +t}:
      (bd, vt) = vd
      reverse_go(acc, D.Digit{6n, t}, va, ({==}, vt))
    case D.Digit{6n, +t}:
      (bd, vt) = vd
      reverse_go(acc, D.Digit{7n, t}, va, ({==}, vt))
    case D.Digit{7n, +t}:
      (bd, vt) = vd
      reverse_go(acc, D.Digit{8n, t}, va, ({==}, vt))
    case D.Digit{8n, +t}:
      (bd, vt) = vd
      reverse_go(acc, D.Digit{9n, t}, va, ({==}, vt))
    case D.Digit{9n, +t}:
      (bd, vt) = vd
      increment_go(t, D.Digit{0n, acc}, vt, ({==}, va))
    case D.Digit{10n+k, +t}:
      (bd, vt) = vd
      Bits.absurd(C.valid(D.increment_go(D.Digit{10n+k, t}, acc)), Bits.false_true(bd))

def increment(+ds: D.Digits, vd: C.valid(ds)) -> C.valid(D.increment(ds)):
  increment_go(ds, D.End{}, vd, Unit{})

def count(+n: Nat, +acc: D.Digits, va: C.valid(acc)) -> C.valid(D.count(n, acc)):
  match n:
    case 0n: va
    case 1n+k: count(k, D.increment(acc), increment(acc, va))
