# Natural-number comparison of coefficients with independent decimal shifts.
import Base
import ./schema-number-arith.bend as Arith
import ./chunked-arith.bend as A

def choose(rank: Cmp, coefficient: Cmp) -> Cmp:
  match rank:
    case LT{}: LT{}
    case EQ{}: coefficient
    case GT{}: GT{}

def false_type(b: Bool) -> Type:
  match b:
    case False{}: Unit
    case True{}: Empty

def false_true(e: {False{} == True{} : Bool}) -> Empty:
  %e : false_type(_)
  Unit{}

def absurd(-T: Type, e: Empty) -> T:
  match e:

def cmp_eq(+a: Nat, +b: Nat, e: {Nat.cmp(a, b) == EQ{} : Cmp}) -> {a == b : Nat}:
  match a b:
    case 0n 0n: {==}
    case 0n 1n+q:
      absurd({0n == 1n+q : Nat}, false_true(Equal.cong(Cmp, Bool, x => Cmp.is_eq(x), LT{}, EQ{}, e)))
    case 1n+p 0n:
      absurd({1n+p == 0n : Nat}, false_true(Equal.cong(Cmp, Bool, x => Cmp.is_eq(x), GT{}, EQ{}, e)))
    case 1n+p 1n+q:
      Equal.cong(Nat, Nat, x => 1n+x, p, q, cmp_eq(p, q, e))

# Move a common extra shift across the coefficient's fixed digit length.
def scale_reorder(+a: Nat, +s: Nat, +l: Nat, +r: Nat) -> {Nat.mul(Nat.mul(a, Nat.pow(10n, s)), Nat.pow(10n, Nat.add(l, r))) == Nat.mul(Nat.mul(a, Nat.pow(10n, r)), Nat.pow(10n, Nat.add(l, s))) : Nat}:
  %Arith.scale_sum(a, s, Nat.add(l, r)) : {_ == Nat.mul(Nat.mul(a, Nat.pow(10n, r)), Nat.pow(10n, Nat.add(l, s))) : Nat}
  %Arith.scale_sum(a, r, Nat.add(l, s)) : {Nat.mul(a, Nat.pow(10n, Nat.add(s, Nat.add(l, r)))) == _ : Nat}
  Equal.cong(Nat, Nat, x => Nat.mul(a, Nat.pow(10n, x)), Nat.add(s, Nat.add(l, r)), Nat.add(r, Nat.add(l, s)),
    Equal.trans(Nat, Nat.add(s, Nat.add(l, r)), Nat.add(l, Nat.add(s, r)), Nat.add(r, Nat.add(l, s)), Arith.add_swap(s, l, r),
      Equal.trans(Nat, Nat.add(l, Nat.add(s, r)), Nat.add(l, Nat.add(r, s)), Nat.add(r, Nat.add(l, s)), Equal.cong(Nat, Nat, x => Nat.add(l, x), Nat.add(s, r), Nat.add(r, s), Arith.add_comm(s, r)), Arith.add_swap(l, r, s))))

def equal_rank(+a: Nat, +b: Nat, +l: Nat, +r: Nat, +s: Nat, +t: Nat, e: {Nat.add(l, s) == Nat.add(r, t) : Nat}) -> {Nat.cmp(Nat.mul(a, Nat.pow(10n, s)), Nat.mul(b, Nat.pow(10n, t))) == Nat.cmp(Nat.mul(a, Nat.pow(10n, r)), Nat.mul(b, Nat.pow(10n, l))) : Cmp}:
  %Arith.cmp_power_scale(Nat.mul(a, Nat.pow(10n, s)), Nat.mul(b, Nat.pow(10n, t)), Nat.add(l, r)) : {_ == Nat.cmp(Nat.mul(a, Nat.pow(10n, r)), Nat.mul(b, Nat.pow(10n, l))) : Cmp}
  %Equal.sym(Nat, Nat.mul(Nat.mul(a, Nat.pow(10n, s)), Nat.pow(10n, Nat.add(l, r))), Nat.mul(Nat.mul(a, Nat.pow(10n, r)), Nat.pow(10n, Nat.add(l, s))), scale_reorder(a, s, l, r)) : {Nat.cmp(_, Nat.mul(Nat.mul(b, Nat.pow(10n, t)), Nat.pow(10n, Nat.add(l, r)))) == Nat.cmp(Nat.mul(a, Nat.pow(10n, r)), Nat.mul(b, Nat.pow(10n, l))) : Cmp}
  %Arith.add_comm(r, l) : {Nat.cmp(Nat.mul(Nat.mul(a, Nat.pow(10n, r)), Nat.pow(10n, Nat.add(l, s))), Nat.mul(Nat.mul(b, Nat.pow(10n, t)), Nat.pow(10n, _))) == Nat.cmp(Nat.mul(a, Nat.pow(10n, r)), Nat.mul(b, Nat.pow(10n, l))) : Cmp}
  %Equal.sym(Nat, Nat.mul(Nat.mul(b, Nat.pow(10n, t)), Nat.pow(10n, Nat.add(r, l))), Nat.mul(Nat.mul(b, Nat.pow(10n, l)), Nat.pow(10n, Nat.add(r, t))), scale_reorder(b, t, r, l)) : {Nat.cmp(Nat.mul(Nat.mul(a, Nat.pow(10n, r)), Nat.pow(10n, Nat.add(l, s))), _) == Nat.cmp(Nat.mul(a, Nat.pow(10n, r)), Nat.mul(b, Nat.pow(10n, l))) : Cmp}
  %Equal.sym(Nat, Nat.add(l, s), Nat.add(r, t), e) : {Nat.cmp(Nat.mul(Nat.mul(a, Nat.pow(10n, r)), Nat.pow(10n, _)), Nat.mul(Nat.mul(b, Nat.pow(10n, l)), Nat.pow(10n, Nat.add(r, t)))) == Nat.cmp(Nat.mul(a, Nat.pow(10n, r)), Nat.mul(b, Nat.pow(10n, l))) : Cmp}
  Arith.cmp_power_scale(Nat.mul(a, Nat.pow(10n, r)), Nat.mul(b, Nat.pow(10n, l)), Nat.add(r, t))

def le_trans(+a: Nat, +b: Nat, +c: Nat, ab: {Nat.is_le(a, b) == True{} : Bool}, bc: {Nat.is_le(b, c) == True{} : Bool}) -> {Nat.is_le(a, c) == True{} : Bool}:
  match a b c:
    case 0n b c: A.zero_le(c)
    case 1n+p 0n c: absurd({Nat.is_le(1n+p, c) == True{} : Bool}, false_true(ab))
    case 1n+p 1n+q 0n: absurd({Nat.is_le(1n+p, 0n) == True{} : Bool}, false_true(bc))
    case 1n+p 1n+q 1n+r: le_trans(p, q, r, ab, bc)

def le_add(+a: Nat, +b: Nat) -> {Nat.is_le(a, Nat.add(a, b)) == True{} : Bool}:
  match a:
    case 0n: A.zero_le(b)
    case 1n+p: le_add(p, b)

def le_mul10(+a: Nat, +b: Nat, e: {Nat.is_le(a, b) == True{} : Bool}) -> {Nat.is_le(Nat.mul(10n, a), Nat.mul(10n, b)) == True{} : Bool}:
  %Arith.mul_comm(a, 10n) : {Nat.is_le(_, Nat.mul(10n, b)) == True{} : Bool}
  %Arith.mul_comm(b, 10n) : {Nat.is_le(Nat.mul(a, 10n), _) == True{} : Bool}
  %Equal.sym(Cmp, Nat.cmp(Nat.mul(a, 10n), Nat.mul(b, 10n)), Nat.cmp(a, b), Arith.cmp_mul_positive(a, b, 9n)) : {Cmp.is_le(_) == True{} : Bool}
  e

def power_positive(+n: Nat) -> {Nat.is_le(1n, Nat.pow(10n, n)) == True{} : Bool}:
  match n:
    case 0n: {==}
    case 1n+p:
      le_trans(1n, Nat.pow(10n, p), Nat.pow(10n, 1n+p), power_positive(p), le_add(Nat.pow(10n, p), Nat.mul(9n, Nat.pow(10n, p))))

def power_le(+n: Nat, +m: Nat, e: {Nat.is_le(n, m) == True{} : Bool}) -> {Nat.is_le(Nat.pow(10n, n), Nat.pow(10n, m)) == True{} : Bool}:
  match n m:
    case 0n m: power_positive(m)
    case 1n+p 0n: absurd({Nat.is_le(Nat.pow(10n, 1n+p), 1n) == True{} : Bool}, false_true(e))
    case 1n+p 1n+q: le_mul10(Nat.pow(10n, p), Nat.pow(10n, q), power_le(p, q, e))

def lt_to_le_succ(+a: Nat, +b: Nat, e: {Nat.is_lt(a, b) == True{} : Bool}) -> {Nat.is_le(1n+a, b) == True{} : Bool}:
  match a b:
    case a 0n:
      absurd({Nat.is_le(1n+a, 0n) == True{} : Bool}, false_true(e))
    case 0n 1n+q: A.zero_le(q)
    case 1n+p 1n+q: lt_to_le_succ(p, q, e)

def lt_le_trans(+a: Nat, +b: Nat, +c: Nat, ab: {Nat.is_lt(a, b) == True{} : Bool}, bc: {Nat.is_le(b, c) == True{} : Bool}) -> {Nat.cmp(a, c) == LT{} : Cmp}:
  A.succ_le_lt(a, c, le_trans(1n+a, b, c, lt_to_le_succ(a, b, ab), bc))

def le_scale(+a: Nat, +b: Nat, +s: Nat, e: {Nat.is_le(a, b) == True{} : Bool}) -> {Nat.is_le(Nat.mul(a, Nat.pow(10n, s)), Nat.mul(b, Nat.pow(10n, s))) == True{} : Bool}:
  %Equal.sym(Cmp, Nat.cmp(Nat.mul(a, Nat.pow(10n, s)), Nat.mul(b, Nat.pow(10n, s))), Nat.cmp(a, b), Arith.cmp_power_scale(a, b, s)) : {Cmp.is_le(_) == True{} : Bool}
  e

def lt_scale(+a: Nat, +b: Nat, +s: Nat, e: {Nat.is_lt(a, b) == True{} : Bool}) -> {Nat.is_lt(Nat.mul(a, Nat.pow(10n, s)), Nat.mul(b, Nat.pow(10n, s))) == True{} : Bool}:
  %Equal.sym(Cmp, Nat.cmp(Nat.mul(a, Nat.pow(10n, s)), Nat.mul(b, Nat.pow(10n, s))), Nat.cmp(a, b), Arith.cmp_power_scale(a, b, s)) : {Cmp.is_lt(_) == True{} : Bool}
  e

# Scaled coefficients retain their lower and upper decimal-magnitude bounds.
def scaled_lower(+a: Nat, +n: Nat, +s: Nat, e: {Nat.is_le(Nat.pow(10n, n), a) == True{} : Bool}) -> {Nat.is_le(Nat.pow(10n, Nat.add(n, s)), Nat.mul(a, Nat.pow(10n, s))) == True{} : Bool}:
  %Equal.sym(Nat, Nat.pow(10n, Nat.add(n, s)), Nat.mul(Nat.pow(10n, n), Nat.pow(10n, s)), Arith.power_add(10n, n, s)) : {Nat.is_le(_, Nat.mul(a, Nat.pow(10n, s))) == True{} : Bool}
  le_scale(Nat.pow(10n, n), a, s, e)

def scaled_upper(+a: Nat, +n: Nat, +s: Nat, e: {Nat.is_lt(a, Nat.pow(10n, 1n+n)) == True{} : Bool}) -> {Nat.is_lt(Nat.mul(a, Nat.pow(10n, s)), Nat.pow(10n, 1n+Nat.add(n, s))) == True{} : Bool}:
  %Equal.sym(Nat, Nat.pow(10n, Nat.add(1n+n, s)), Nat.mul(Nat.pow(10n, 1n+n), Nat.pow(10n, s)), Arith.power_add(10n, 1n+n, s)) : {Nat.is_lt(Nat.mul(a, Nat.pow(10n, s)), _) == True{} : Bool}
  lt_scale(a, Nat.pow(10n, 1n+n), s, e)

def rank_lt(+a: Nat, +b: Nat, +n: Nat, +m: Nat, +s: Nat, +t: Nat,
    upper: {Nat.is_lt(a, Nat.pow(10n, 1n+n)) == True{} : Bool},
    lower: {Nat.is_le(Nat.pow(10n, m), b) == True{} : Bool},
    rank: {Nat.is_lt(Nat.add(n, s), Nat.add(m, t)) == True{} : Bool}) -> {Nat.cmp(Nat.mul(a, Nat.pow(10n, s)), Nat.mul(b, Nat.pow(10n, t))) == LT{} : Cmp}:
  lt_le_trans(Nat.mul(a, Nat.pow(10n, s)), Nat.pow(10n, 1n+Nat.add(n, s)), Nat.mul(b, Nat.pow(10n, t)), scaled_upper(a, n, s, upper),
    le_trans(Nat.pow(10n, 1n+Nat.add(n, s)), Nat.pow(10n, Nat.add(m, t)), Nat.mul(b, Nat.pow(10n, t)), power_le(1n+Nat.add(n, s), Nat.add(m, t), lt_to_le_succ(Nat.add(n, s), Nat.add(m, t), rank)), scaled_lower(b, m, t, lower)))

def flip(c: Cmp) -> Cmp:
  match c:
    case LT{}: GT{}
    case EQ{}: EQ{}
    case GT{}: LT{}

def cmp_reverse(+a: Nat, +b: Nat) -> {flip(Nat.cmp(a, b)) == Nat.cmp(b, a) : Cmp}:
  match a b:
    case 0n 0n: {==}
    case 0n 1n+q: {==}
    case 1n+p 0n: {==}
    case 1n+p 1n+q: cmp_reverse(p, q)

def rank_gt(+a: Nat, +b: Nat, +n: Nat, +m: Nat, +s: Nat, +t: Nat,
    lower: {Nat.is_le(Nat.pow(10n, n), a) == True{} : Bool},
    upper: {Nat.is_lt(b, Nat.pow(10n, 1n+m)) == True{} : Bool},
    rank: {Nat.cmp(Nat.add(n, s), Nat.add(m, t)) == GT{} : Cmp}) -> {Nat.cmp(Nat.mul(a, Nat.pow(10n, s)), Nat.mul(b, Nat.pow(10n, t))) == GT{} : Cmp}:
  back = Equal.trans(Cmp, Nat.cmp(Nat.add(m, t), Nat.add(n, s)), flip(Nat.cmp(Nat.add(n, s), Nat.add(m, t))), LT{},
    Equal.sym(Cmp, flip(Nat.cmp(Nat.add(n, s), Nat.add(m, t))), Nat.cmp(Nat.add(m, t), Nat.add(n, s)), cmp_reverse(Nat.add(n, s), Nat.add(m, t))),
    Equal.cong(Cmp, Cmp, x => flip(x), Nat.cmp(Nat.add(n, s), Nat.add(m, t)), GT{}, rank))
  lt = rank_lt(b, a, m, n, t, s, upper, lower, Equal.cong(Cmp, Bool, x => Cmp.is_lt(x), Nat.cmp(Nat.add(m, t), Nat.add(n, s)), LT{}, back))
  Equal.trans(Cmp, Nat.cmp(Nat.mul(a, Nat.pow(10n, s)), Nat.mul(b, Nat.pow(10n, t))), flip(Nat.cmp(Nat.mul(b, Nat.pow(10n, t)), Nat.mul(a, Nat.pow(10n, s)))), GT{},
    Equal.sym(Cmp, flip(Nat.cmp(Nat.mul(b, Nat.pow(10n, t)), Nat.mul(a, Nat.pow(10n, s)))), Nat.cmp(Nat.mul(a, Nat.pow(10n, s)), Nat.mul(b, Nat.pow(10n, t))), cmp_reverse(Nat.mul(b, Nat.pow(10n, t)), Nat.mul(a, Nat.pow(10n, s)))),
    Equal.cong(Cmp, Cmp, x => flip(x), Nat.cmp(Nat.mul(b, Nat.pow(10n, t)), Nat.mul(a, Nat.pow(10n, s))), LT{}, lt))

def scaled_by_rank(+rank: Cmp, +a: Nat, +b: Nat, +n: Nat, +m: Nat, +s: Nat, +t: Nat,
    alo: {Nat.is_le(Nat.pow(10n, n), a) == True{} : Bool},
    ahi: {Nat.is_lt(a, Nat.pow(10n, 1n+n)) == True{} : Bool},
    blo: {Nat.is_le(Nat.pow(10n, m), b) == True{} : Bool},
    bhi: {Nat.is_lt(b, Nat.pow(10n, 1n+m)) == True{} : Bool},
    e: {Nat.cmp(Nat.add(n, s), Nat.add(m, t)) == rank : Cmp}) ->
    {Nat.cmp(Nat.mul(a, Nat.pow(10n, s)), Nat.mul(b, Nat.pow(10n, t))) == choose(rank, Nat.cmp(Nat.mul(a, Nat.pow(10n, 1n+m)), Nat.mul(b, Nat.pow(10n, 1n+n)))) : Cmp}:
  match rank:
    case LT{}:
      rank_lt(a, b, n, m, s, t, ahi, blo, Equal.cong(Cmp, Bool, x => Cmp.is_lt(x), Nat.cmp(Nat.add(n, s), Nat.add(m, t)), LT{}, e))
    case EQ{}:
      equal_rank(a, b, 1n+n, 1n+m, s, t, Equal.cong(Nat, Nat, x => 1n+x, Nat.add(n, s), Nat.add(m, t), cmp_eq(Nat.add(n, s), Nat.add(m, t), e)))
    case GT{}:
      rank_gt(a, b, n, m, s, t, alo, bhi, e)

# Each coefficient has a nonzero decimal length (1+n or 1+m). The bounds
# imply nonzero coefficients, so no separate nonzero premise is needed.
def scaled_coefficients(+a: Nat, +b: Nat, +n: Nat, +m: Nat, +s: Nat, +t: Nat,
    alo: {Nat.is_le(Nat.pow(10n, n), a) == True{} : Bool},
    ahi: {Nat.is_lt(a, Nat.pow(10n, 1n+n)) == True{} : Bool},
    blo: {Nat.is_le(Nat.pow(10n, m), b) == True{} : Bool},
    bhi: {Nat.is_lt(b, Nat.pow(10n, 1n+m)) == True{} : Bool}) ->
    {Nat.cmp(Nat.mul(a, Nat.pow(10n, s)), Nat.mul(b, Nat.pow(10n, t))) == choose(Nat.cmp(Nat.add(1n+n, s), Nat.add(1n+m, t)), Nat.cmp(Nat.mul(a, Nat.pow(10n, 1n+m)), Nat.mul(b, Nat.pow(10n, 1n+n)))) : Cmp}:
  scaled_by_rank(Nat.cmp(Nat.add(n, s), Nat.add(m, t)), a, b, n, m, s, t, alo, ahi, blo, bhi, {==})
