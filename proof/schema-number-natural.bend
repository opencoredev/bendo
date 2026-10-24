# Positional meaning of the tail-recursive decimal carry adder.
import Base
import ../src/data/decimal-natural.bend as D
import ./schema-number-arith.bend as A
import ./chunked-arith.bend as N

import ./schema-number-natural-cmp.bend as C

# An already emitted reversed prefix wraps the remaining higher digits.
def finish(ds: D.Digits, n: Nat) -> Nat:
  match ds:
    case D.End{}: n
    case D.Digit{d, t}: finish(t, Nat.add(d, Nat.mul(10n, n)))

def reverse_value(+ds: D.Digits, +acc: D.Digits) -> {C.value(D.reverse_go(ds, acc)) == finish(ds, C.value(acc)) : Nat}:
  match ds:
    case D.End{}: {==}
    case D.Digit{d, t}: reverse_value(t, D.Digit{d, acc})

def last_value(+c: Nat) -> {C.value(D.last(c)) == c : Nat}:
  match c:
    case 0n: {==}
    case 1n+k: N.add_zero_r(1n+k)

# Splitting at ten is exact even before the digit/carry bounds are used.
def split(+n: Nat) -> {Nat.add(D.low(n), Nat.mul(10n, D.carry(n))) == n : Nat}:
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
    case 10n+k: A.add_comm(k, 10n)

def ten_add(+a: Nat, +b: Nat) -> {Nat.mul(10n, Nat.add(a, b)) == Nat.add(Nat.mul(10n, a), Nat.mul(10n, b)) : Nat}:
  %A.mul_comm(Nat.add(a, b), 10n) : {_ == Nat.add(Nat.mul(10n, a), Nat.mul(10n, b)) : Nat}
  %A.mul_comm(a, 10n) : {Nat.mul(Nat.add(a, b), 10n) == Nat.add(_, Nat.mul(10n, b)) : Nat}
  %A.mul_comm(b, 10n) : {Nat.mul(Nat.add(a, b), 10n) == Nat.add(Nat.mul(a, 10n), _) : Nat}
  A.mul_add(a, b, 10n)

def carry_step(+n: Nat, +rest: Nat) -> {Nat.add(D.low(n), Nat.mul(10n, Nat.add(D.carry(n), rest))) == Nat.add(n, Nat.mul(10n, rest)) : Nat}:
  %Equal.sym(Nat, Nat.mul(10n, Nat.add(D.carry(n), rest)), Nat.add(Nat.mul(10n, D.carry(n)), Nat.mul(10n, rest)), ten_add(D.carry(n), rest)) : {Nat.add(D.low(n), _) == Nat.add(n, Nat.mul(10n, rest)) : Nat}
  %A.add_assoc(D.low(n), Nat.mul(10n, D.carry(n)), Nat.mul(10n, rest)) : {_ == Nat.add(n, Nat.mul(10n, rest)) : Nat}
  Equal.cong(Nat, Nat, x => Nat.add(x, Nat.mul(10n, rest)), Nat.add(D.low(n), Nat.mul(10n, D.carry(n))), n, split(n))

def pair_sum(+a: Nat, +b: Nat, +c: Nat, +d: Nat) -> {Nat.add(Nat.add(a, b), Nat.add(c, d)) == Nat.add(Nat.add(a, c), Nat.add(b, d)) : Nat}:
  %Equal.sym(Nat, Nat.add(Nat.add(a, c), Nat.add(b, d)), Nat.add(a, Nat.add(c, Nat.add(b, d))), A.add_assoc(a, c, Nat.add(b, d))) : {Nat.add(Nat.add(a, b), Nat.add(c, d)) == _ : Nat}
  %Equal.sym(Nat, Nat.add(Nat.add(a, b), Nat.add(c, d)), Nat.add(a, Nat.add(b, Nat.add(c, d))), A.add_assoc(a, b, Nat.add(c, d))) : {_ == Nat.add(a, Nat.add(c, Nat.add(b, d))) : Nat}
  Equal.cong(Nat, Nat, x => Nat.add(a, x), Nat.add(b, Nat.add(c, d)), Nat.add(c, Nat.add(b, d)), A.add_swap(b, c, d))

def add_column(+c: Nat, +d: Nat, +e: Nat, +x: Nat, +y: Nat) -> {Nat.add(D.low(Nat.add(c, Nat.add(d, e))), Nat.mul(10n, Nat.add(D.carry(Nat.add(c, Nat.add(d, e))), Nat.add(x, y)))) == Nat.add(c, Nat.add(Nat.add(d, Nat.mul(10n, x)), Nat.add(e, Nat.mul(10n, y)))) : Nat}:
  %Equal.sym(Nat, Nat.add(D.low(Nat.add(c, Nat.add(d, e))), Nat.mul(10n, Nat.add(D.carry(Nat.add(c, Nat.add(d, e))), Nat.add(x, y)))), Nat.add(Nat.add(c, Nat.add(d, e)), Nat.mul(10n, Nat.add(x, y))), carry_step(Nat.add(c, Nat.add(d, e)), Nat.add(x, y))) : {_ == Nat.add(c, Nat.add(Nat.add(d, Nat.mul(10n, x)), Nat.add(e, Nat.mul(10n, y)))) : Nat}
  %Equal.sym(Nat, Nat.add(Nat.add(d, Nat.mul(10n, x)), Nat.add(e, Nat.mul(10n, y))), Nat.add(Nat.add(d, e), Nat.add(Nat.mul(10n, x), Nat.mul(10n, y))), pair_sum(d, Nat.mul(10n, x), e, Nat.mul(10n, y))) : {Nat.add(Nat.add(c, Nat.add(d, e)), Nat.mul(10n, Nat.add(x, y))) == Nat.add(c, _) : Nat}
  %Equal.sym(Nat, Nat.mul(10n, Nat.add(x, y)), Nat.add(Nat.mul(10n, x), Nat.mul(10n, y)), ten_add(x, y)) : {Nat.add(Nat.add(c, Nat.add(d, e)), _) == Nat.add(c, Nat.add(Nat.add(d, e), Nat.add(Nat.mul(10n, x), Nat.mul(10n, y)))) : Nat}
  A.add_assoc(c, Nat.add(d, e), Nat.add(Nat.mul(10n, x), Nat.mul(10n, y)))

def one_column(+c: Nat, +d: Nat, +x: Nat) -> {Nat.add(D.low(Nat.add(c, d)), Nat.mul(10n, Nat.add(D.carry(Nat.add(c, d)), x))) == Nat.add(c, Nat.add(d, Nat.mul(10n, x))) : Nat}:
  Equal.trans(Nat, Nat.add(D.low(Nat.add(c, d)), Nat.mul(10n, Nat.add(D.carry(Nat.add(c, d)), x))), Nat.add(Nat.add(c, d), Nat.mul(10n, x)), Nat.add(c, Nat.add(d, Nat.mul(10n, x))), carry_step(Nat.add(c, d), x), A.add_assoc(c, d, Nat.mul(10n, x)))

def add_value_go(+a: D.Digits, +b: D.Digits, +c: Nat, +acc: D.Digits) -> {C.value(D.add_go(a, b, c, acc)) == finish(acc, Nat.add(c, Nat.add(C.value(a), C.value(b)))) : Nat}:
  match a b:
    case D.End{} D.End{}:
      %Equal.sym(Nat, Nat.add(c, 0n), c, N.add_zero_r(c)) : {C.value(D.reverse_go(acc, D.last(c))) == finish(acc, _) : Nat}
      Equal.trans(Nat, C.value(D.reverse_go(acc, D.last(c))), finish(acc, C.value(D.last(c))), finish(acc, c), reverse_value(acc, D.last(c)), Equal.cong(Nat, Nat, n => finish(acc, n), C.value(D.last(c)), c, last_value(c)))
    case D.Digit{+d, +t} D.End{}:
      +n = Nat.add(c, Nat.add(d, 0n))
      Equal.trans(Nat, C.value(D.add_go(t, D.End{}, D.carry(n), D.Digit{D.low(n), acc})), finish(D.Digit{D.low(n), acc}, Nat.add(D.carry(n), Nat.add(C.value(t), 0n))), finish(acc, Nat.add(c, Nat.add(C.value(D.Digit{d, t}), 0n))), add_value_go(t, D.End{}, D.carry(n), D.Digit{D.low(n), acc}), Equal.cong(Nat, Nat, z => finish(acc, z), Nat.add(D.low(n), Nat.mul(10n, Nat.add(D.carry(n), Nat.add(C.value(t), 0n)))), Nat.add(c, Nat.add(C.value(D.Digit{d, t}), 0n)), add_column(c, d, 0n, C.value(t), 0n)))
    case D.End{} D.Digit{+e, +u}:
      +n = Nat.add(c, e)
      Equal.trans(Nat, C.value(D.add_go(D.End{}, u, D.carry(n), D.Digit{D.low(n), acc})), finish(D.Digit{D.low(n), acc}, Nat.add(D.carry(n), C.value(u))), finish(acc, Nat.add(c, C.value(D.Digit{e, u}))), add_value_go(D.End{}, u, D.carry(n), D.Digit{D.low(n), acc}), Equal.cong(Nat, Nat, z => finish(acc, z), Nat.add(D.low(n), Nat.mul(10n, Nat.add(D.carry(n), C.value(u)))), Nat.add(c, C.value(D.Digit{e, u})), add_column(c, 0n, e, 0n, C.value(u))))
    case D.Digit{+d, +t} D.Digit{+e, +u}:
      +n = Nat.add(c, Nat.add(d, e))
      Equal.trans(Nat, C.value(D.add_go(t, u, D.carry(n), D.Digit{D.low(n), acc})), finish(D.Digit{D.low(n), acc}, Nat.add(D.carry(n), Nat.add(C.value(t), C.value(u)))), finish(acc, Nat.add(c, Nat.add(C.value(D.Digit{d, t}), C.value(D.Digit{e, u})))), add_value_go(t, u, D.carry(n), D.Digit{D.low(n), acc}), Equal.cong(Nat, Nat, z => finish(acc, z), Nat.add(D.low(n), Nat.mul(10n, Nat.add(D.carry(n), Nat.add(C.value(t), C.value(u))))), Nat.add(c, Nat.add(C.value(D.Digit{d, t}), C.value(D.Digit{e, u}))), add_column(c, d, e, C.value(t), C.value(u))))

def add_value(+a: D.Digits, +b: D.Digits) -> {C.value(D.add(a, b)) == Nat.add(C.value(a), C.value(b)) : Nat}:
  add_value_go(a, b, 0n, D.End{})

def ten_succ(+n: Nat) -> {Nat.mul(10n, 1n+n) == 10n+Nat.mul(10n, n) : Nat}:
  A.mul_succ_r(10n, n)

def increment_value_go(+ds: D.Digits, +acc: D.Digits) -> {C.value(D.increment_go(ds, acc)) == finish(acc, 1n+C.value(ds)) : Nat}:
  match ds:
    case D.End{}: reverse_value(acc, D.Digit{1n, D.End{}})
    case D.Digit{9n, +t}:
      Equal.trans(Nat,
        C.value(D.increment_go(t, D.Digit{0n, acc})),
        finish(D.Digit{0n, acc}, 1n+C.value(t)),
        finish(acc, 10n+Nat.mul(10n, C.value(t))),
        increment_value_go(t, D.Digit{0n, acc}),
        Equal.cong(Nat, Nat, n => finish(acc, n), Nat.mul(10n, 1n+C.value(t)), 10n+Nat.mul(10n, C.value(t)), ten_succ(C.value(t))))
    case D.Digit{0n, t}: reverse_value(acc, D.Digit{1n, t})
    case D.Digit{1n, t}: reverse_value(acc, D.Digit{2n, t})
    case D.Digit{2n, t}: reverse_value(acc, D.Digit{3n, t})
    case D.Digit{3n, t}: reverse_value(acc, D.Digit{4n, t})
    case D.Digit{4n, t}: reverse_value(acc, D.Digit{5n, t})
    case D.Digit{5n, t}: reverse_value(acc, D.Digit{6n, t})
    case D.Digit{6n, t}: reverse_value(acc, D.Digit{7n, t})
    case D.Digit{7n, t}: reverse_value(acc, D.Digit{8n, t})
    case D.Digit{8n, t}: reverse_value(acc, D.Digit{9n, t})
    case D.Digit{10n+k, t}: reverse_value(acc, D.Digit{11n+k, t})

def increment_value(+ds: D.Digits) -> {C.value(D.increment(ds)) == 1n+C.value(ds) : Nat}:
  increment_value_go(ds, D.End{})

def count_value(+n: Nat, +acc: D.Digits) -> {C.value(D.count(n, acc)) == Nat.add(n, C.value(acc)) : Nat}:
  match n:
    case 0n: {==}
    case 1n+k:
      Equal.trans(Nat,
        C.value(D.count(k, D.increment(acc))),
        Nat.add(k, C.value(D.increment(acc))),
        1n+Nat.add(k, C.value(acc)),
        count_value(k, D.increment(acc)),
        Equal.trans(Nat, Nat.add(k, C.value(D.increment(acc))), Nat.add(k, 1n+C.value(acc)), 1n+Nat.add(k, C.value(acc)), Equal.cong(Nat, Nat, x => Nat.add(k, x), C.value(D.increment(acc)), 1n+C.value(acc), increment_value(acc)), N.add_succ_r(k, C.value(acc))))
