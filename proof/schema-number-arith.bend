# Exact positional values used by the independent decimal specification.
# These are proof-only naturals; runtime decimal code never expands an exponent.
import Base
import ../src/data/schema-spec.bend as Spec
import ./chunked-arith.bend as A
import ./utf8.bend as UP
import ../src/data/decimal.bend as D

def add_assoc(+a: Nat, +b: Nat, +c: Nat) -> {Nat.add(Nat.add(a, b), c) == Nat.add(a, Nat.add(b, c)) : Nat}:
  match a:
    case 0n: {==}
    case 1n+p: Equal.cong(Nat, Nat, x => 1n+x, Nat.add(Nat.add(p, b), c), Nat.add(p, Nat.add(b, c)), add_assoc(p, b, c))

def add_comm(+a: Nat, +b: Nat) -> {Nat.add(a, b) == Nat.add(b, a) : Nat}:
  match a:
    case 0n: Equal.sym(Nat, Nat.add(b, 0n), b, A.add_zero_r(b))
    case 1n+p:
      %Equal.sym(Nat, Nat.add(b, 1n+p), 1n+Nat.add(b, p), A.add_succ_r(b, p)) : {1n+Nat.add(p, b) == _ : Nat}
      Equal.cong(Nat, Nat, x => 1n+x, Nat.add(p, b), Nat.add(b, p), add_comm(p, b))

def mul_add(+a: Nat, +b: Nat, +c: Nat) -> {Nat.mul(Nat.add(a, b), c) == Nat.add(Nat.mul(a, c), Nat.mul(b, c)) : Nat}:
  match a:
    case 0n: {==}
    case 1n+p:
      %Equal.sym(Nat, Nat.add(Nat.add(c, Nat.mul(p, c)), Nat.mul(b, c)), Nat.add(c, Nat.add(Nat.mul(p, c), Nat.mul(b, c))), add_assoc(c, Nat.mul(p, c), Nat.mul(b, c))) : {Nat.add(c, Nat.mul(Nat.add(p, b), c)) == _ : Nat}
      Equal.cong(Nat, Nat, x => Nat.add(c, x), Nat.mul(Nat.add(p, b), c), Nat.add(Nat.mul(p, c), Nat.mul(b, c)), mul_add(p, b, c))

def mul_assoc(+a: Nat, +b: Nat, +c: Nat) -> {Nat.mul(Nat.mul(a, b), c) == Nat.mul(a, Nat.mul(b, c)) : Nat}:
  match a:
    case 0n: {==}
    case 1n+p:
      %Equal.sym(Nat, Nat.mul(Nat.add(b, Nat.mul(p, b)), c), Nat.add(Nat.mul(b, c), Nat.mul(Nat.mul(p, b), c)), mul_add(b, Nat.mul(p, b), c)) : {_ == Nat.add(Nat.mul(b, c), Nat.mul(p, Nat.mul(b, c))) : Nat}
      Equal.cong(Nat, Nat, x => Nat.add(Nat.mul(b, c), x), Nat.mul(Nat.mul(p, b), c), Nat.mul(p, Nat.mul(b, c)), mul_assoc(p, b, c))

def mul_one(+a: Nat) -> {Nat.mul(a, 1n) == a : Nat}:
  match a:
    case 0n: {==}
    case 1n+p: Equal.cong(Nat, Nat, x => 1n+x, Nat.mul(p, 1n), p, mul_one(p))

def mul_zero(+a: Nat) -> {Nat.mul(a, 0n) == 0n : Nat}:
  match a:
    case 0n: {==}
    case 1n+p: mul_zero(p)

def power_add(+base: Nat, +a: Nat, +b: Nat) -> {Nat.pow(base, Nat.add(a, b)) == Nat.mul(Nat.pow(base, a), Nat.pow(base, b)) : Nat}:
  match a:
    case 0n: Equal.sym(Nat, Nat.add(Nat.pow(base, b), 0n), Nat.pow(base, b), A.add_zero_r(Nat.pow(base, b)))
    case 1n+p:
      %Equal.sym(Nat, Nat.mul(Nat.mul(base, Nat.pow(base, p)), Nat.pow(base, b)), Nat.mul(base, Nat.mul(Nat.pow(base, p), Nat.pow(base, b))), mul_assoc(base, Nat.pow(base, p), Nat.pow(base, b))) : {Nat.mul(base, Nat.pow(base, Nat.add(p, b))) == _ : Nat}
      Equal.cong(Nat, Nat, x => Nat.mul(base, x), Nat.pow(base, Nat.add(p, b)), Nat.mul(Nat.pow(base, p), Nat.pow(base, b)), power_add(base, p, b))

# Reading concatenated digit text is composition of the two prefix folds.
def value_append(+s: String, +t: String, +acc: Nat) -> {Spec.value(s ++ t, acc) == Spec.value(t, Spec.value(s, acc)) : Nat}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{c}, tail}: value_append(tail, t, Nat.add(Nat.mul(acc, 10n), Spec.digit_value(c)))

# Horner's step, isolated so the string induction only needs its hypothesis.
def positional_step(+a: Nat, +d: Nat, +p: Nat, +v: Nat) -> {Nat.add(Nat.mul(Nat.add(Nat.mul(a, 10n), d), p), v) == Nat.add(Nat.mul(a, Nat.mul(10n, p)), Nat.add(Nat.mul(d, p), v)) : Nat}:
  %Equal.sym(Nat, Nat.mul(Nat.add(Nat.mul(a, 10n), d), p), Nat.add(Nat.mul(Nat.mul(a, 10n), p), Nat.mul(d, p)), mul_add(Nat.mul(a, 10n), d, p)) : {Nat.add(_, v) == Nat.add(Nat.mul(a, Nat.mul(10n, p)), Nat.add(Nat.mul(d, p), v)) : Nat}
  %Equal.sym(Nat, Nat.add(Nat.add(Nat.mul(Nat.mul(a, 10n), p), Nat.mul(d, p)), v), Nat.add(Nat.mul(Nat.mul(a, 10n), p), Nat.add(Nat.mul(d, p), v)), add_assoc(Nat.mul(Nat.mul(a, 10n), p), Nat.mul(d, p), v)) : {_ == Nat.add(Nat.mul(a, Nat.mul(10n, p)), Nat.add(Nat.mul(d, p), v)) : Nat}
  Equal.cong(Nat, Nat, x => Nat.add(x, Nat.add(Nat.mul(d, p), v)), Nat.mul(Nat.mul(a, 10n), p), Nat.mul(a, Nat.mul(10n, p)), mul_assoc(a, 10n, p))

def value_positional(+s: String, +acc: Nat) -> {Spec.value(s, acc) == Nat.add(Nat.mul(acc, Nat.pow(10n, Spec.length(s))), Spec.value(s, 0n)) : Nat}:
  match s:
    case SNil{}:
      %Equal.sym(Nat, Nat.add(Nat.mul(acc, 1n), 0n), Nat.mul(acc, 1n), A.add_zero_r(Nat.mul(acc, 1n))) : {acc == _ : Nat}
      Equal.sym(Nat, Nat.mul(acc, 1n), acc, mul_one(acc))
    case SCon{Chr{+c}, +t}:
      %Equal.sym(Nat, Spec.value(t, Nat.add(Nat.mul(acc, 10n), Spec.digit_value(c))), Nat.add(Nat.mul(Nat.add(Nat.mul(acc, 10n), Spec.digit_value(c)), Nat.pow(10n, Spec.length(t))), Spec.value(t, 0n)), value_positional(t, Nat.add(Nat.mul(acc, 10n), Spec.digit_value(c)))) : {_ == Nat.add(Nat.mul(acc, Nat.pow(10n, 1n+Spec.length(t))), Spec.value(t, Spec.digit_value(c))) : Nat}
      %Equal.sym(Nat, Spec.value(t, Spec.digit_value(c)), Nat.add(Nat.mul(Spec.digit_value(c), Nat.pow(10n, Spec.length(t))), Spec.value(t, 0n)), value_positional(t, Spec.digit_value(c))) : {Nat.add(Nat.mul(Nat.add(Nat.mul(acc, 10n), Spec.digit_value(c)), Nat.pow(10n, Spec.length(t))), Spec.value(t, 0n)) == Nat.add(Nat.mul(acc, Nat.pow(10n, 1n+Spec.length(t))), _) : Nat}
      positional_step(acc, Spec.digit_value(c), Nat.pow(10n, Spec.length(t)), Spec.value(t, 0n))

def value_concat(+s: String, +t: String) -> {Spec.value(s ++ t, 0n) == Nat.add(Nat.mul(Spec.value(s, 0n), Nat.pow(10n, Spec.length(t))), Spec.value(t, 0n)) : Nat}:
  Equal.trans(Nat, Spec.value(s ++ t, 0n), Spec.value(t, Spec.value(s, 0n)), Nat.add(Nat.mul(Spec.value(s, 0n), Nat.pow(10n, Spec.length(t))), Spec.value(t, 0n)), value_append(s, t, 0n), value_positional(t, Spec.value(s, 0n)))

# Multiplication by a positive common denominator preserves all three outcomes.
def cmp_mul_positive(+a: Nat, +b: Nat, +k: Nat) -> {Nat.cmp(Nat.mul(a, 1n+k), Nat.mul(b, 1n+k)) == Nat.cmp(a, b) : Cmp}:
  match a b:
    case 0n 0n: {==}
    case 0n 1n+q: {==}
    case 1n+p 0n: {==}
    case 1n+p 1n+q:
      Equal.trans(Cmp, Nat.cmp(Nat.add(1n+k, Nat.mul(p, 1n+k)), Nat.add(1n+k, Nat.mul(q, 1n+k))), Nat.cmp(Nat.mul(p, 1n+k), Nat.mul(q, 1n+k)), Nat.cmp(p, q), A.cmp_add_cancel(1n+k, Nat.mul(p, 1n+k), Nat.mul(q, 1n+k)), cmp_mul_positive(p, q, k))

def add_swap(+a: Nat, +b: Nat, +c: Nat) -> {Nat.add(a, Nat.add(b, c)) == Nat.add(b, Nat.add(a, c)) : Nat}:
  %add_assoc(a, b, c) : {_ == Nat.add(b, Nat.add(a, c)) : Nat}
  %add_assoc(b, a, c) : {Nat.add(Nat.add(a, b), c) == _ : Nat}
  Equal.cong(Nat, Nat, x => Nat.add(x, c), Nat.add(a, b), Nat.add(b, a), add_comm(a, b))

def mul_succ_r(+a: Nat, +b: Nat) -> {Nat.mul(a, 1n+b) == Nat.add(a, Nat.mul(a, b)) : Nat}:
  match a:
    case 0n: {==}
    case 1n+p:
      %Equal.sym(Nat, Nat.mul(p, 1n+b), Nat.add(p, Nat.mul(p, b)), mul_succ_r(p, b)) : {1n+Nat.add(b, _) == 1n+Nat.add(p, Nat.add(b, Nat.mul(p, b))) : Nat}
      Equal.cong(Nat, Nat, x => 1n+x, Nat.add(b, Nat.add(p, Nat.mul(p, b))), Nat.add(p, Nat.add(b, Nat.mul(p, b))), add_swap(b, p, Nat.mul(p, b)))

def mul_comm(+a: Nat, +b: Nat) -> {Nat.mul(a, b) == Nat.mul(b, a) : Nat}:
  match a:
    case 0n: Equal.sym(Nat, Nat.mul(b, 0n), 0n, mul_zero(b))
    case 1n+p:
      %Equal.sym(Nat, Nat.mul(b, 1n+p), Nat.add(b, Nat.mul(b, p)), mul_succ_r(b, p)) : {Nat.add(b, Nat.mul(p, b)) == _ : Nat}
      Equal.cong(Nat, Nat, x => Nat.add(b, x), Nat.mul(p, b), Nat.mul(b, p), mul_comm(p, b))

# Reassociate a power-of-ten step so common scaling can be cancelled.
def mul_swap(+a: Nat, +b: Nat, +c: Nat) -> {Nat.mul(a, Nat.mul(b, c)) == Nat.mul(Nat.mul(a, c), b) : Nat}:
  %Equal.sym(Nat, Nat.mul(Nat.mul(a, c), b), Nat.mul(a, Nat.mul(c, b)), mul_assoc(a, c, b)) : {Nat.mul(a, Nat.mul(b, c)) == _ : Nat}
  Equal.cong(Nat, Nat, x => Nat.mul(a, x), Nat.mul(b, c), Nat.mul(c, b), mul_comm(b, c))

def cmp_power_scale(+a: Nat, +b: Nat, +n: Nat) -> {Nat.cmp(Nat.mul(a, Nat.pow(10n, n)), Nat.mul(b, Nat.pow(10n, n))) == Nat.cmp(a, b) : Cmp}:
  match n:
    case 0n:
      %Equal.sym(Nat, Nat.mul(a, 1n), a, mul_one(a)) : {Nat.cmp(_, Nat.mul(b, 1n)) == Nat.cmp(a, b) : Cmp}
      %Equal.sym(Nat, Nat.mul(b, 1n), b, mul_one(b)) : {Nat.cmp(a, _) == Nat.cmp(a, b) : Cmp}
      {==}
    case 1n+k:
      %Equal.sym(Nat, Nat.mul(a, Nat.mul(10n, Nat.pow(10n, k))), Nat.mul(Nat.mul(a, Nat.pow(10n, k)), 10n), mul_swap(a, 10n, Nat.pow(10n, k))) : {Nat.cmp(_, Nat.mul(b, Nat.mul(10n, Nat.pow(10n, k)))) == Nat.cmp(a, b) : Cmp}
      %Equal.sym(Nat, Nat.mul(b, Nat.mul(10n, Nat.pow(10n, k))), Nat.mul(Nat.mul(b, Nat.pow(10n, k)), 10n), mul_swap(b, 10n, Nat.pow(10n, k))) : {Nat.cmp(Nat.mul(Nat.mul(a, Nat.pow(10n, k)), 10n), _) == Nat.cmp(a, b) : Cmp}
      Equal.trans(Cmp, Nat.cmp(Nat.mul(Nat.mul(a, Nat.pow(10n, k)), 10n), Nat.mul(Nat.mul(b, Nat.pow(10n, k)), 10n)), Nat.cmp(Nat.mul(a, Nat.pow(10n, k)), Nat.mul(b, Nat.pow(10n, k))), Nat.cmp(a, b), cmp_mul_positive(Nat.mul(a, Nat.pow(10n, k)), Nat.mul(b, Nat.pow(10n, k)), 9n), cmp_power_scale(a, b, k))

# Dropping a fixed lower offset preserves the remaining upper bound.
def sub_bound(+x: Nat, +lo: Nat, +span: Nat, e: {Nat.is_le(x, Nat.add(lo, span)) == True{} : Bool}) -> {Nat.is_le(Nat.sub(x, lo), span) == True{} : Bool}:
  match x lo:
    case 0n 0n: A.zero_le(span)
    case 0n 1n+k: A.zero_le(span)
    case 1n+p 0n: e
    case 1n+p 1n+k: sub_bound(p, k, span, e)

def digit_upper(+c: U32, e: {Spec.digit(c) == True{} : Bool}) -> {U32.is_le(c, 57) == True{} : Bool}:
  UP.and_right(U32.is_ge(c, 48), U32.is_le(c, 57), e)

# The specification's digit subtraction never underflows on a valid digit.
def digit_bound(+c: U32, e: {Spec.digit(c) == True{} : Bool}) -> {Nat.is_le(Spec.digit_value(c), 9n) == True{} : Bool}:
  +hi = A.u32_nat_le(c, 57)
  +upper = Equal.trans(Bool, Nat.is_le(U32.to_nat(c), 57n), U32.is_le(c, 57), True{}, Equal.sym(Bool, U32.is_le(c, 57), Nat.is_le(U32.to_nat(c), 57n), hi), digit_upper(c, e))
  sub_bound(U32.to_nat(c), 48n, 9n, upper)

# The runtime length accumulator agrees with the independent recursive length.
def runtime_length_go(+s: String, +n: Nat) -> {D.length_go(s, n) == Nat.add(Spec.length(s), n) : Nat}:
  match s:
    case SNil{}: {==}
    case SCon{h, +t}:
      Equal.trans(Nat, D.length_go(t, 1n+n), Nat.add(Spec.length(t), 1n+n), 1n+Nat.add(Spec.length(t), n), runtime_length_go(t, 1n+n), A.add_succ_r(Spec.length(t), n))

def runtime_length(+s: String) -> {D.length(s) == Spec.length(s) : Nat}:
  Equal.trans(Nat, D.length(s), Nat.add(Spec.length(s), 0n), Spec.length(s), runtime_length_go(s, 0n), A.add_zero_r(Spec.length(s)))

# Symmetry of comparison handles the negative/negative branch of decimal order.
def cmp_flip(+a: Nat, +b: Nat) -> {D.flip(Nat.cmp(a, b)) == Nat.cmp(b, a) : Cmp}:
  match a b:
    case 0n 0n: {==}
    case 0n 1n+q: {==}
    case 1n+p 0n: {==}
    case 1n+p 1n+q: cmp_flip(p, q)


# Separate a shared exponent shift before cancelling the common denominator.
def scale_sum(+a: Nat, +x: Nat, +k: Nat) -> {Nat.mul(a, Nat.pow(10n, Nat.add(x, k))) == Nat.mul(Nat.mul(a, Nat.pow(10n, x)), Nat.pow(10n, k)) : Nat}:
  %Equal.sym(Nat, Nat.pow(10n, Nat.add(x, k)), Nat.mul(Nat.pow(10n, x), Nat.pow(10n, k)), power_add(10n, x, k)) : {Nat.mul(a, _) == Nat.mul(Nat.mul(a, Nat.pow(10n, x)), Nat.pow(10n, k)) : Nat}
  Equal.sym(Nat, Nat.mul(Nat.mul(a, Nat.pow(10n, x)), Nat.pow(10n, k)), Nat.mul(a, Nat.mul(Nat.pow(10n, x), Nat.pow(10n, k))), mul_assoc(a, Nat.pow(10n, x), Nat.pow(10n, k)))

def compare_shifted(+a: Nat, +b: Nat, +x: Nat, +y: Nat, +k: Nat) -> {Nat.cmp(Nat.mul(a, Nat.pow(10n, Nat.add(x, k))), Nat.mul(b, Nat.pow(10n, Nat.add(y, k)))) == Nat.cmp(Nat.mul(a, Nat.pow(10n, x)), Nat.mul(b, Nat.pow(10n, y))) : Cmp}:
  %Equal.sym(Nat, Nat.mul(a, Nat.pow(10n, Nat.add(x, k))), Nat.mul(Nat.mul(a, Nat.pow(10n, x)), Nat.pow(10n, k)), scale_sum(a, x, k)) : {Nat.cmp(_, Nat.mul(b, Nat.pow(10n, Nat.add(y, k)))) == Nat.cmp(Nat.mul(a, Nat.pow(10n, x)), Nat.mul(b, Nat.pow(10n, y))) : Cmp}
  %Equal.sym(Nat, Nat.mul(b, Nat.pow(10n, Nat.add(y, k))), Nat.mul(Nat.mul(b, Nat.pow(10n, y)), Nat.pow(10n, k)), scale_sum(b, y, k)) : {Nat.cmp(Nat.mul(Nat.mul(a, Nat.pow(10n, x)), Nat.pow(10n, k)), _) == Nat.cmp(Nat.mul(a, Nat.pow(10n, x)), Nat.mul(b, Nat.pow(10n, y))) : Cmp}
  cmp_power_scale(Nat.mul(a, Nat.pow(10n, x)), Nat.mul(b, Nat.pow(10n, y)), k)
