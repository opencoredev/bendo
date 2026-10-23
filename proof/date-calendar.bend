# The production calendar in src/http/date.bend agrees with the Gregorian
# rules of proof/date-spec.bend.
import Base
import ../src/http/date.bend as D
import ./date-spec.bend as S
import ./date-arith.bend as A
import ./date-walk.bend as W

# Leap years. With a = year - 1600 split as 400e + 100c + 4q + yq, the
# production flag is "yq = 0, and q > 0 or c = 0".

law leap_logic:
  for +yq: Nat
  for +q: Nat
  for +c: Nat
  {Bool.or(Bool.and(Nat.is_eq(yq, 0n), Bool.not(Nat.is_eq(Nat.add(Nat.mul(q, 4n), yq), 0n))), Nat.is_eq(Nat.add(Nat.mul(c, 100n), Nat.add(Nat.mul(q, 4n), yq)), 0n)) == D.leap(c, q, yq) : Bool}

def leap_logic(yq, q, c):
  match yq:
    case 1n+p:
      %Equal.sym(Nat, Nat.add(Nat.mul(q, 4n), 1n+p), 1n+Nat.add(Nat.mul(q, 4n), p), A.add_succ_r(Nat.mul(q, 4n), p)) : {Nat.is_eq(Nat.add(Nat.mul(c, 100n), _), 0n) == False{} : Bool}
      %Equal.sym(Nat, Nat.add(Nat.mul(c, 100n), 1n+Nat.add(Nat.mul(q, 4n), p)), 1n+Nat.add(Nat.mul(c, 100n), Nat.add(Nat.mul(q, 4n), p)), A.add_succ_r(Nat.mul(c, 100n), Nat.add(Nat.mul(q, 4n), p))) : {Nat.is_eq(_, 0n) == False{} : Bool}
      {==}
    case 0n:
      match q:
        case 1n+qp:
          {==}
        case 0n:
          match c:
            case 0n:
              {==}
            case 1n+cp:
              {==}

# The year split used by D.days_from: a = year - 1600 = 400e + a1,
# a1 = 100c + a2, a2 = 4q + yq.
def ya(+y: Nat) -> Nat:
  Nat.sub(y, 1600n)

def ye(+y: Nat) -> Nat:
  Nat.div(Nat.sub(y, 1600n), 400n)

def ya1(+y: Nat) -> Nat:
  Nat.mod(Nat.sub(y, 1600n), 400n)

def yc(+y: Nat) -> Nat:
  Nat.div(Nat.mod(Nat.sub(y, 1600n), 400n), 100n)

def ya2(+y: Nat) -> Nat:
  Nat.mod(Nat.mod(Nat.sub(y, 1600n), 400n), 100n)

def yq(+y: Nat) -> Nat:
  Nat.div(Nat.mod(Nat.mod(Nat.sub(y, 1600n), 400n), 100n), 4n)

def yy(+y: Nat) -> Nat:
  Nat.mod(Nat.mod(Nat.mod(Nat.sub(y, 1600n), 400n), 100n), 4n)

law mod400_year:
  for +y: Nat
  for ge: {Nat.is_le(1600n, y) == True{} : Bool}
  {Nat.mod(y, 400n) == ya1(y) : Nat}

def mod400_year(y, ge):
  %A.add_sub_le(1600n, y, ge) : {Nat.mod(_, 400n) == ya1(y) : Nat}
  A.mod_add_mul(4n, ya(y), 400n, {==})

law mod100_year:
  for +y: Nat
  for ge: {Nat.is_le(1600n, y) == True{} : Bool}
  {Nat.mod(y, 100n) == ya2(y) : Nat}

def mod100_year(y, ge):
  %A.add_sub_le(1600n, y, ge) : {Nat.mod(_, 100n) == ya2(y) : Nat}
  Equal.trans(Nat, Nat.mod(Nat.add(1600n, ya(y)), 100n), Nat.mod(ya(y), 100n), ya2(y), A.mod_add_mul(16n, ya(y), 100n, {==}), Equal.sym(Nat, ya2(y), Nat.mod(ya(y), 100n), A.mod_mod_mul(ya(y), 4n, 100n, {==}, {==})))

law mod4_year:
  for +y: Nat
  for ge: {Nat.is_le(1600n, y) == True{} : Bool}
  {Nat.mod(y, 4n) == yy(y) : Nat}

def mod4_year(y, ge):
  %A.add_sub_le(1600n, y, ge) : {Nat.mod(_, 4n) == yy(y) : Nat}
  +step = Equal.trans(Nat, yy(y), Nat.mod(ya1(y), 4n), Nat.mod(ya(y), 4n), A.mod_mod_mul(ya1(y), 25n, 4n, {==}, {==}), A.mod_mod_mul(ya(y), 100n, 4n, {==}, {==}))
  Equal.trans(Nat, Nat.mod(Nat.add(1600n, ya(y)), 4n), Nat.mod(ya(y), 4n), yy(y), A.mod_add_mul(400n, ya(y), 4n, {==}), Equal.sym(Nat, yy(y), Nat.mod(ya(y), 4n), step))

law leap_agrees:
  for +y: Nat
  for +ge: {Nat.is_le(1600n, y) == True{} : Bool}
  {S.leap(y) == D.leap(yc(y), yq(y), yy(y)) : Bool}

def leap_agrees(y, ge):
  %Equal.sym(Nat, Nat.mod(y, 400n), ya1(y), mod400_year(y, ge)) : {Bool.or(Bool.and(Nat.is_eq(Nat.mod(y, 4n), 0n), Bool.not(Nat.is_eq(Nat.mod(y, 100n), 0n))), Nat.is_eq(_, 0n)) == D.leap(yc(y), yq(y), yy(y)) : Bool}
  %Equal.sym(Nat, Nat.mod(y, 100n), ya2(y), mod100_year(y, ge)) : {Bool.or(Bool.and(Nat.is_eq(Nat.mod(y, 4n), 0n), Bool.not(Nat.is_eq(_, 0n))), Nat.is_eq(ya1(y), 0n)) == D.leap(yc(y), yq(y), yy(y)) : Bool}
  %Equal.sym(Nat, Nat.mod(y, 4n), yy(y), mod4_year(y, ge)) : {Bool.or(Bool.and(Nat.is_eq(_, 0n), Bool.not(Nat.is_eq(ya2(y), 0n))), Nat.is_eq(ya1(y), 0n)) == D.leap(yc(y), yq(y), yy(y)) : Bool}
  %A.div_mod_id(ya1(y), 100n, {==}) : {Bool.or(Bool.and(Nat.is_eq(yy(y), 0n), Bool.not(Nat.is_eq(ya2(y), 0n))), Nat.is_eq(_, 0n)) == D.leap(yc(y), yq(y), yy(y)) : Bool}
  %A.div_mod_id(ya2(y), 4n, {==}) : {Bool.or(Bool.and(Nat.is_eq(yy(y), 0n), Bool.not(Nat.is_eq(_, 0n))), Nat.is_eq(Nat.add(Nat.mul(yc(y), 100n), _), 0n)) == D.leap(yc(y), yq(y), yy(y)) : Bool}
  leap_logic(yy(y), yq(y), yc(y))

# Encoding: D.days_of(e, c, q, yq, m, r) is outer(e, c, q, yq, days into the year).

def outer(+e: Nat, +c: Nat, +q: Nat, +yq: Nat, x: Nat) -> Nat:
  Nat.add(Nat.mul(e, 146097n), D.before(c, D.century_lengths(), D.before(q, D.group_lengths(D.is_zero(c)), D.before(yq, D.year_lengths(D.long_group(c, q)), x))))

law outer_succ:
  for +e: Nat
  for +c: Nat
  for +q: Nat
  for +yq: Nat
  for +x: Nat
  {outer(e, c, q, yq, 1n+x) == 1n+outer(e, c, q, yq, x) : Nat}

def outer_succ(e, c, q, yq, x):
  +mE = Nat.mul(e, 146097n)
  +cl = D.century_lengths()
  +gl = D.group_lengths(D.is_zero(c))
  +yl = D.year_lengths(D.long_group(c, q))
  +b1 = D.before(yq, yl, x)
  +b2 = D.before(q, gl, b1)
  +b3 = D.before(c, cl, b2)
  %Equal.sym(Nat, D.before(yq, yl, 1n+x), 1n+b1, W.before_succ(yq, yl, x)) : {Nat.add(mE, D.before(c, cl, D.before(q, gl, _))) == 1n+Nat.add(mE, b3) : Nat}
  %Equal.sym(Nat, D.before(q, gl, 1n+b1), 1n+b2, W.before_succ(q, gl, b1)) : {Nat.add(mE, D.before(c, cl, _)) == 1n+Nat.add(mE, b3) : Nat}
  %Equal.sym(Nat, D.before(c, cl, 1n+b2), 1n+b3, W.before_succ(c, cl, b2)) : {Nat.add(mE, _) == 1n+Nat.add(mE, b3) : Nat}
  A.add_succ_r(mE, b3)

law days_succ:
  for +e: Nat
  for +c: Nat
  for +q: Nat
  for +yq: Nat
  for +m: Nat
  for +r: Nat
  {D.days_of(e, c, q, yq, m, 1n+r) == 1n+D.days_of(e, c, q, yq, m, r) : Nat}

def days_succ(e, c, q, yq, m, r):
  +ml = D.month_lengths(D.leap(c, q, yq))
  %Equal.sym(Nat, D.before(m, ml, 1n+r), 1n+D.before(m, ml, r), W.before_succ(m, ml, r)) : {outer(e, c, q, yq, _) == 1n+D.days_of(e, c, q, yq, m, r) : Nat}
  outer_succ(e, c, q, yq, D.before(m, ml, r))

# The next month starts right after the last day of this one.
law days_month_next:
  for +e: Nat
  for +c: Nat
  for +q: Nat
  for +yq: Nat
  for +m: Nat
  for +r: Nat
  for lm: {Nat.is_lt(m, 12n) == True{} : Bool}
  for full: {1n+r == W.nth(m, D.month_lengths(D.leap(c, q, yq))) : Nat}
  {D.days_of(e, c, q, yq, 1n+m, 0n) == 1n+D.days_of(e, c, q, yq, m, r) : Nat}

def days_month_next(e, c, q, yq, m, r, lm, full):
  +ml = D.month_lengths(D.leap(c, q, yq))
  %Equal.sym(Nat, D.before(1n+m, ml, 0n), D.before(m, ml, W.nth(m, ml)), W.before_next(m, ml, lm)) : {outer(e, c, q, yq, _) == 1n+D.days_of(e, c, q, yq, m, r) : Nat}
  %full : {outer(e, c, q, yq, D.before(m, ml, _)) == 1n+D.days_of(e, c, q, yq, m, r) : Nat}
  days_succ(e, c, q, yq, m, r)

def feb_agrees(b: Bool) -> {S.february(b) == D.february(b) : Nat}:
  match b:
    case True{}:
      {==}
    case False{}:
      {==}

def lt_absurd_add(-A: Type, +k: Nat, +p: Nat, lt: {Nat.is_lt(Nat.add(k, p), k) == True{} : Bool}) -> A:
  A.absurd(A, A.false_true(Equal.trans(Bool, False{}, Nat.is_lt(Nat.add(k, p), k), True{}, Equal.sym(Bool, Nat.is_lt(Nat.add(k, p), k), False{}, A.not_lt_add(k, p)), lt)))

law month_table:
  for +y: Nat
  for +mp: Nat
  for +b: Bool
  for hb: {S.leap(y) == b : Bool}
  for lm: {Nat.is_lt(mp, 12n) == True{} : Bool}
  {S.month_days(y, 1n+mp) == W.nth(mp, D.month_lengths(b)) : Nat}

def month_table(y, mp, b, hb, lm):
  match mp:
    case 0n:
      {==}
    case 1n:
      %Equal.sym(Bool, S.leap(y), b, hb) : {S.february(_) == D.february(b) : Nat}
      feb_agrees(b)
    case 2n:
      {==}
    case 3n:
      {==}
    case 4n:
      {==}
    case 5n:
      {==}
    case 6n:
      {==}
    case 7n:
      {==}
    case 8n:
      {==}
    case 9n:
      {==}
    case 10n:
      {==}
    case 11n:
      {==}
    case 12n+p:
      lt_absurd_add({S.month_days(y, 13n+p) == W.nth(12n+p, D.month_lengths(b)) : Nat}, 12n, p, lm)

def pred(n: Nat) -> Nat:
  match n:
    case 0n:
      0n
    case 1n+p:
      p

# The last day of a period plus one is the period's length.

def year_full0(g: Bool) -> {D.before(11n, D.month_lengths(g), 31n) == W.nth(0n, D.year_lengths(g)) : Nat}:
  match g:
    case True{}:
      {==}
    case False{}:
      {==}

law year_full:
  for +c: Nat
  for +q: Nat
  for +yq: Nat
  for h: {Nat.is_lt(1n+yq, 4n) == True{} : Bool}
  {D.before(11n, D.month_lengths(D.leap(c, q, yq)), 31n) == W.nth(yq, D.year_lengths(D.long_group(c, q))) : Nat}

def year_full(c, q, yq, h):
  match yq:
    case 0n:
      year_full0(D.long_group(c, q))
    case 1n:
      {==}
    case 2n:
      {==}
    case 3n+p:
      lt_absurd_add({D.before(11n, D.month_lengths(D.leap(c, q, 3n+p)), 31n) == W.nth(3n+p, D.year_lengths(D.long_group(c, q))) : Nat}, 4n, p, h)

def group_full0(g: Bool) -> {1n+D.before(3n, D.year_lengths(g), D.before(11n, D.month_lengths(False{}), 30n)) == D.first_group(g) : Nat}:
  match g:
    case True{}:
      {==}
    case False{}:
      {==}

law group_full:
  for +c: Nat
  for +q: Nat
  for lq: {Nat.is_lt(q, 25n) == True{} : Bool}
  {1n+D.before(3n, D.year_lengths(D.long_group(c, q)), D.before(11n, D.month_lengths(D.leap(c, q, 3n)), 30n)) == W.nth(q, D.group_lengths(D.is_zero(c))) : Nat}

def group_full(c, q, lq):
  match q:
    case 0n:
      group_full0(D.is_zero(c))
    case 1n+qp:
      %Equal.sym(Nat, W.nth(qp, D.rep(24n, 1461n)), 1461n, W.nth_rep(qp, 24n, 1461n, lq)) : {1n+D.before(3n, D.year_lengths(True{}), D.before(11n, D.month_lengths(False{}), 30n)) == _ : Nat}
      {==}

# Year-end steps. A big period length is never exposed: the index that
# moves to the next century or cycle stays a variable with an equation.

law mul_succ_eq:
  for +e1: Nat
  for +e: Nat
  for +k: Nat
  for h: {e1 == 1n+e : Nat}
  {Nat.mul(e1, k) == Nat.add(k, Nat.mul(e, k)) : Nat}

def mul_succ_eq(e1, e, k, h):
  %Equal.sym(Nat, e1, 1n+e, h) : {Nat.mul(_, k) == Nat.add(k, Nat.mul(e, k)) : Nat}
  {==}

law before_next_eq:
  for +i1: Nat
  for +i: Nat
  for +lens: List<&2, Nat>
  for h: {i1 == 1n+i : Nat}
  for li: {Nat.is_lt(i, W.count(lens)) == True{} : Bool}
  {D.before(i1, lens, 0n) == D.before(i, lens, W.nth(i, lens)) : Nat}

def before_next_eq(i1, i, lens, h, li):
  %Equal.sym(Nat, i1, 1n+i, h) : {D.before(_, lens, 0n) == D.before(i, lens, W.nth(i, lens)) : Nat}
  W.before_next(i, lens, li)

law era_gen:
  for +k: Nat
  for +me1: Nat
  for +z: Nat
  for +me: Nat
  for +x: Nat
  for hm: {me1 == Nat.add(k, me) : Nat}
  for hz: {z == 0n : Nat}
  for hx: {1n+x == k : Nat}
  {Nat.add(me1, z) == 1n+Nat.add(me, x) : Nat}

def era_gen(k, me1, z, me, x, hm, hz, hx):
  %Equal.sym(Nat, me1, Nat.add(k, me), hm) : {Nat.add(_, z) == 1n+Nat.add(me, x) : Nat}
  %Equal.sym(Nat, z, 0n, hz) : {Nat.add(Nat.add(k, me), _) == 1n+Nat.add(me, x) : Nat}
  %A.add_succ_r(me, x) : {Nat.add(Nat.add(k, me), 0n) == _ : Nat}
  %Equal.sym(Nat, 1n+x, k, hx) : {Nat.add(Nat.add(k, me), 0n) == Nat.add(me, _) : Nat}
  %Equal.sym(Nat, Nat.add(Nat.add(k, me), 0n), Nat.add(k, me), A.add_zero_r(Nat.add(k, me))) : {_ == Nat.add(me, k) : Nat}
  A.add_comm(k, me)

# Days into a cycle for the split of a1 = year - 1600 mod 400.
def cycle_days(+a1: Nat, m: Nat, r: Nat) -> Nat:
  +c = Nat.div(a1, 100n)
  +a2 = Nat.mod(a1, 100n)
  +q = Nat.div(a2, 4n)
  +yq = Nat.mod(a2, 4n)
  D.before(c, D.century_lengths(), D.before(q, D.group_lengths(D.is_zero(c)), D.before(yq, D.year_lengths(D.long_group(c, q)), D.before(m, D.month_lengths(D.leap(c, q, yq)), r))))

law cycle_start:
  for +a1: Nat
  for h: {a1 == 0n : Nat}
  {cycle_days(a1, 0n, 0n) == 0n : Nat}

def cycle_start(a1, h):
  %Equal.sym(Nat, a1, 0n, h) : {cycle_days(_, 0n, 0n) == 0n : Nat}
  {==}

law cycle_end:
  for +a1: Nat
  for h: {a1 == 399n : Nat}
  {1n+cycle_days(a1, 11n, 30n) == 146097n : Nat}

def cycle_end(a1, h):
  %Equal.sym(Nat, a1, 399n, h) : {1n+cycle_days(_, 11n, 30n) == 146097n : Nat}
  A.eq_of_is_eq(1n+cycle_days(399n, 11n, 30n), 146097n, {==})

law step_cycle:
  for +e1: Nat
  for +e: Nat
  for +a1n: Nat
  for +a1: Nat
  for he: {e1 == 1n+e : Nat}
  for hn: {a1n == 0n : Nat}
  for h: {a1 == 399n : Nat}
  {D.days_century(e1, a1n, 0n, 0n) == 1n+D.days_century(e, a1, 11n, 30n) : Nat}

def step_cycle(e1, e, a1n, a1, he, hn, h):
  era_gen(146097n, Nat.mul(e1, 146097n), cycle_days(a1n, 0n, 0n), Nat.mul(e, 146097n), cycle_days(a1, 11n, 30n), mul_succ_eq(e1, e, 146097n, he), cycle_start(a1n, hn), cycle_end(a1, h))

# One layer: day 0 of period i + 1 follows the last day of period i.
law layer_next:
  for +i1: Nat
  for +i: Nat
  for +lens: List<&2, Nat>
  for +z: Nat
  for +x: Nat
  for hi: {i1 == 1n+i : Nat}
  for li: {Nat.is_lt(i, W.count(lens)) == True{} : Bool}
  for hz: {z == 0n : Nat}
  for hx: {1n+x == W.nth(i, lens) : Nat}
  {D.before(i1, lens, z) == 1n+D.before(i, lens, x) : Nat}

def layer_next(i1, i, lens, z, x, hi, li, hz, hx):
  %Equal.sym(Nat, z, 0n, hz) : {D.before(i1, lens, _) == 1n+D.before(i, lens, x) : Nat}
  %Equal.sym(Nat, D.before(i1, lens, 0n), D.before(i, lens, W.nth(i, lens)), before_next_eq(i1, i, lens, hi, li)) : {_ == 1n+D.before(i, lens, x) : Nat}
  %hx : {D.before(i, lens, _) == 1n+D.before(i, lens, x) : Nat}
  W.before_succ(i, lens, x)

# Outer layers pass a successor through.
law lift_before:
  for +i: Nat
  for +lens: List<&2, Nat>
  for +u: Nat
  for +v: Nat
  for h: {u == 1n+v : Nat}
  {D.before(i, lens, u) == 1n+D.before(i, lens, v) : Nat}

def lift_before(i, lens, u, v, h):
  %Equal.sym(Nat, u, 1n+v, h) : {D.before(i, lens, _) == 1n+D.before(i, lens, v) : Nat}
  W.before_succ(i, lens, v)

law lift_add:
  for +me: Nat
  for +u: Nat
  for +v: Nat
  for h: {u == 1n+v : Nat}
  {Nat.add(me, u) == 1n+Nat.add(me, v) : Nat}

def lift_add(me, u, v, h):
  %Equal.sym(Nat, u, 1n+v, h) : {Nat.add(me, _) == 1n+Nat.add(me, v) : Nat}
  A.add_succ_r(me, v)

# Days into a century for the split of a2 = year - 1600 mod 100.
def century_days(+c: Nat, +a2: Nat, m: Nat, r: Nat) -> Nat:
  +q = Nat.div(a2, 4n)
  +yq = Nat.mod(a2, 4n)
  D.before(q, D.group_lengths(D.is_zero(c)), D.before(yq, D.year_lengths(D.long_group(c, q)), D.before(m, D.month_lengths(D.leap(c, q, yq)), r)))

law century_start:
  for +c: Nat
  for +a2: Nat
  for h: {a2 == 0n : Nat}
  {century_days(c, a2, 0n, 0n) == 0n : Nat}

def century_start(c, a2, h):
  %Equal.sym(Nat, a2, 0n, h) : {century_days(c, _, 0n, 0n) == 0n : Nat}
  {==}

law century_end:
  for +c: Nat
  for +a2: Nat
  for h: {a2 == 99n : Nat}
  for lc: {Nat.is_lt(c, 4n) == True{} : Bool}
  {1n+century_days(c, a2, 11n, 30n) == W.nth(c, D.century_lengths()) : Nat}

def century_end(c, a2, h, lc):
  match c:
    case 0n:
      %Equal.sym(Nat, a2, 99n, h) : {1n+century_days(0n, _, 11n, 30n) == W.nth(0n, D.century_lengths()) : Nat}
      A.eq_of_is_eq(1n+century_days(0n, 99n, 11n, 30n), W.nth(0n, D.century_lengths()), {==})
    case 1n:
      %Equal.sym(Nat, a2, 99n, h) : {1n+century_days(1n, _, 11n, 30n) == W.nth(1n, D.century_lengths()) : Nat}
      A.eq_of_is_eq(1n+century_days(1n, 99n, 11n, 30n), W.nth(1n, D.century_lengths()), {==})
    case 2n:
      %Equal.sym(Nat, a2, 99n, h) : {1n+century_days(2n, _, 11n, 30n) == W.nth(2n, D.century_lengths()) : Nat}
      A.eq_of_is_eq(1n+century_days(2n, 99n, 11n, 30n), W.nth(2n, D.century_lengths()), {==})
    case 3n:
      %Equal.sym(Nat, a2, 99n, h) : {1n+century_days(3n, _, 11n, 30n) == W.nth(3n, D.century_lengths()) : Nat}
      A.eq_of_is_eq(1n+century_days(3n, 99n, 11n, 30n), W.nth(3n, D.century_lengths()), {==})
    case 4n+p:
      lt_absurd_add({1n+century_days(4n+p, a2, 11n, 30n) == W.nth(4n+p, D.century_lengths()) : Nat}, 4n, p, lc)

law step_century:
  for +e: Nat
  for +c1: Nat
  for +c: Nat
  for +a2n: Nat
  for +a2: Nat
  for hc: {c1 == 1n+c : Nat}
  for hn: {a2n == 0n : Nat}
  for h: {a2 == 99n : Nat}
  for +lc: {Nat.is_lt(c, 4n) == True{} : Bool}
  {D.days_group(e, c1, a2n, 0n, 0n) == 1n+D.days_group(e, c, a2, 11n, 30n) : Nat}

def step_century(e, c1, c, a2n, a2, hc, hn, h, lc):
  +cl = D.century_lengths()
  lift_add(Nat.mul(e, 146097n), D.before(c1, cl, century_days(c1, a2n, 0n, 0n)), D.before(c, cl, century_days(c, a2, 11n, 30n)), layer_next(c1, c, cl, century_days(c1, a2n, 0n, 0n), century_days(c, a2, 11n, 30n), hc, lc, century_start(c1, a2n, hn), century_end(c, a2, h, lc)))

law step_group:
  for +e: Nat
  for +c: Nat
  for +a2n: Nat
  for +a2: Nat
  for hq: {Nat.div(a2n, 4n) == 1n+Nat.div(a2, 4n) : Nat}
  for hy: {Nat.mod(a2n, 4n) == 0n : Nat}
  for h3: {Nat.mod(a2, 4n) == 3n : Nat}
  for +lq: {Nat.is_lt(Nat.div(a2, 4n), 25n) == True{} : Bool}
  {D.days_group(e, c, a2n, 0n, 0n) == 1n+D.days_group(e, c, a2, 11n, 30n) : Nat}

def step_group(e, c, a2n, a2, hq, hy, h3, lq):
  +cl = D.century_lengths()
  +gl = D.group_lengths(D.is_zero(c))
  +qn = Nat.div(a2n, 4n)
  +q = Nat.div(a2, 4n)
  +zg = D.before(Nat.mod(a2n, 4n), D.year_lengths(D.long_group(c, qn)), D.before(0n, D.month_lengths(D.leap(c, qn, Nat.mod(a2n, 4n))), 0n))
  +xg = D.before(Nat.mod(a2, 4n), D.year_lengths(D.long_group(c, q)), D.before(11n, D.month_lengths(D.leap(c, q, Nat.mod(a2, 4n))), 30n))
  +z0 = Equal.trans(Nat, zg, D.before(0n, D.year_lengths(D.long_group(c, qn)), D.before(0n, D.month_lengths(D.leap(c, qn, 0n)), 0n)), 0n, Equal.cong(Nat, Nat, y => D.before(y, D.year_lengths(D.long_group(c, qn)), D.before(0n, D.month_lengths(D.leap(c, qn, y)), 0n)), Nat.mod(a2n, 4n), 0n, hy), {==})
  +x1 = Equal.trans(Nat, 1n+xg, 1n+D.before(3n, D.year_lengths(D.long_group(c, q)), D.before(11n, D.month_lengths(D.leap(c, q, 3n)), 30n)), W.nth(q, gl), Equal.cong(Nat, Nat, y => 1n+D.before(y, D.year_lengths(D.long_group(c, q)), D.before(11n, D.month_lengths(D.leap(c, q, y)), 30n)), Nat.mod(a2, 4n), 3n, h3), group_full(c, q, lq))
  +inner = layer_next(qn, q, gl, zg, xg, hq, lq, z0, x1)
  lift_add(Nat.mul(e, 146097n), D.before(c, cl, D.before(qn, gl, zg)), D.before(c, cl, D.before(q, gl, xg)), lift_before(c, cl, D.before(qn, gl, zg), D.before(q, gl, xg), inner))

law step_year:
  for +e: Nat
  for +c: Nat
  for +a2n: Nat
  for +a2: Nat
  for hq: {Nat.div(a2n, 4n) == Nat.div(a2, 4n) : Nat}
  for hy: {Nat.mod(a2n, 4n) == 1n+Nat.mod(a2, 4n) : Nat}
  for +lt: {Nat.is_lt(1n+Nat.mod(a2, 4n), 4n) == True{} : Bool}
  {D.days_group(e, c, a2n, 0n, 0n) == 1n+D.days_group(e, c, a2, 11n, 30n) : Nat}

def step_year(e, c, a2n, a2, hq, hy, lt):
  +cl = D.century_lengths()
  +gl = D.group_lengths(D.is_zero(c))
  +q = Nat.div(a2, 4n)
  +yq = Nat.mod(a2, 4n)
  +yl = D.year_lengths(D.long_group(c, q))
  %Equal.sym(Nat, Nat.div(a2n, 4n), q, hq) : {Nat.add(Nat.mul(e, 146097n), D.before(c, cl, D.before(_, gl, D.before(Nat.mod(a2n, 4n), D.year_lengths(D.long_group(c, _)), D.before(0n, D.month_lengths(D.leap(c, _, Nat.mod(a2n, 4n))), 0n))))) == 1n+D.days_group(e, c, a2, 11n, 30n) : Nat}
  +zy = D.before(0n, D.month_lengths(D.leap(c, q, Nat.mod(a2n, 4n))), 0n)
  +xy = D.before(11n, D.month_lengths(D.leap(c, q, yq)), 30n)
  +x1 = Equal.trans(Nat, 1n+xy, D.before(11n, D.month_lengths(D.leap(c, q, yq)), 31n), W.nth(yq, yl), Equal.sym(Nat, D.before(11n, D.month_lengths(D.leap(c, q, yq)), 31n), 1n+xy, W.before_succ(11n, D.month_lengths(D.leap(c, q, yq)), 30n)), year_full(c, q, yq, lt))
  +inner = layer_next(Nat.mod(a2n, 4n), yq, yl, zy, xy, hy, A.lt_of_succ_lt(yq, 4n, lt), {==}, x1)
  +mid = lift_before(q, gl, D.before(Nat.mod(a2n, 4n), yl, zy), D.before(yq, yl, xy), inner)
  lift_add(Nat.mul(e, 146097n), D.before(c, cl, D.before(q, gl, D.before(Nat.mod(a2n, 4n), yl, zy))), D.before(c, cl, D.before(q, gl, D.before(yq, yl, xy))), lift_before(c, cl, D.before(q, gl, D.before(Nat.mod(a2n, 4n), yl, zy)), D.before(q, gl, D.before(yq, yl, xy)), mid))

# 1 + m = k with m < k gives m = k - 1, here for small k.
def pred_of(+m: Nat, +k: Nat, e: {1n+m == k : Nat}) -> {m == pred(k) : Nat}:
  Equal.cong(Nat, Nat, x => pred(x), 1n+m, k, e)

def fst_eq(-p: Nat & Nat, -a: Nat, -b: Nat, e: {p == (a, b) : Nat & Nat}) -> {Pair.fst(Nat, Nat, p) == a : Nat}:
  Equal.cong(Nat & Nat, Nat, x => Pair.fst(Nat, Nat, x), p, (a, b), e)

def snd_eq(-p: Nat & Nat, -a: Nat, -b: Nat, e: {p == (a, b) : Nat & Nat}) -> {Pair.snd(Nat, Nat, p) == b : Nat}:
  Equal.cong(Nat & Nat, Nat, x => Pair.snd(Nat, Nat, x), p, (a, b), e)

def group_carry_case(+e: Nat, +c: Nat, +a2: Nat, +h100: {Nat.is_lt(1n+a2, 100n) == True{} : Bool}, r: Bool, +hr: {Nat.is_lt(1n+Nat.mod(a2, 4n), 4n) == r : Bool}) -> {D.days_group(e, c, 1n+a2, 0n, 0n) == 1n+D.days_group(e, c, a2, 11n, 30n) : Nat}:
  match r:
    case True{}:
      +step = A.div_succ_in(a2, 4n, {==}, hr)
      step_year(e, c, 1n+a2, a2, fst_eq(Nat.divmod(1n+a2, 4n), Nat.div(a2, 4n), 1n+Nat.mod(a2, 4n), step), snd_eq(Nat.divmod(1n+a2, 4n), Nat.div(a2, 4n), 1n+Nat.mod(a2, 4n), step), hr)
    case False{}:
      +step = A.div_succ_wrap(a2, 4n, {==}, hr)
      +h3 = pred_of(Nat.mod(a2, 4n), 4n, A.succ_eq_of_lt(Nat.mod(a2, 4n), 4n, A.mod_lt(a2, 4n, {==}), hr))
      +lq = A.div_lt_of_lt_mul(a2, 25n, 4n, {==}, A.lt_of_succ_lt(a2, 100n, h100))
      step_group(e, c, 1n+a2, a2, fst_eq(Nat.divmod(1n+a2, 4n), 1n+Nat.div(a2, 4n), 0n, step), snd_eq(Nat.divmod(1n+a2, 4n), 1n+Nat.div(a2, 4n), 0n, step), h3, lq)

law group_carry:
  for +e: Nat
  for +c: Nat
  for +a2: Nat
  for +h100: {Nat.is_lt(1n+a2, 100n) == True{} : Bool}
  {D.days_group(e, c, 1n+a2, 0n, 0n) == 1n+D.days_group(e, c, a2, 11n, 30n) : Nat}

def group_carry(e, c, a2, h100):
  group_carry_case(e, c, a2, h100, Nat.is_lt(1n+Nat.mod(a2, 4n), 4n), {==})

def century_carry_case(+e: Nat, +a1: Nat, +h400: {Nat.is_lt(1n+a1, 400n) == True{} : Bool}, r: Bool, +hr: {Nat.is_lt(1n+Nat.mod(a1, 100n), 100n) == r : Bool}) -> {D.days_century(e, 1n+a1, 0n, 0n) == 1n+D.days_century(e, a1, 11n, 30n) : Nat}:
  match r:
    case True{}:
      +c = Nat.div(a1, 100n)
      +a2 = Nat.mod(a1, 100n)
      %Equal.sym(Nat & Nat, Nat.divmod(1n+a1, 100n), (c, 1n+a2), A.div_succ_in(a1, 100n, {==}, hr)) : {D.days_group(e, Pair.fst(Nat, Nat, _), Pair.snd(Nat, Nat, _), 0n, 0n) == 1n+D.days_century(e, a1, 11n, 30n) : Nat}
      group_carry(e, c, a2, hr)
    case False{}:
      +step = A.div_succ_wrap(a1, 100n, {==}, hr)
      +h99 = pred_of(Nat.mod(a1, 100n), 100n, A.succ_eq_of_lt(Nat.mod(a1, 100n), 100n, A.mod_lt(a1, 100n, {==}), hr))
      +lc = A.div_lt_of_lt_mul(a1, 4n, 100n, {==}, A.lt_of_succ_lt(a1, 400n, h400))
      step_century(e, Nat.div(1n+a1, 100n), Nat.div(a1, 100n), Nat.mod(1n+a1, 100n), Nat.mod(a1, 100n), fst_eq(Nat.divmod(1n+a1, 100n), 1n+Nat.div(a1, 100n), 0n, step), snd_eq(Nat.divmod(1n+a1, 100n), 1n+Nat.div(a1, 100n), 0n, step), h99, lc)

law century_carry:
  for +e: Nat
  for +a1: Nat
  for +h400: {Nat.is_lt(1n+a1, 400n) == True{} : Bool}
  {D.days_century(e, 1n+a1, 0n, 0n) == 1n+D.days_century(e, a1, 11n, 30n) : Nat}

def century_carry(e, a1, h400):
  century_carry_case(e, a1, h400, Nat.is_lt(1n+Nat.mod(a1, 100n), 100n), {==})

def year_carry_case(+a: Nat, r: Bool, +hr: {Nat.is_lt(1n+Nat.mod(a, 400n), 400n) == r : Bool}) -> {D.days_century(Nat.div(1n+a, 400n), Nat.mod(1n+a, 400n), 0n, 0n) == 1n+D.days_century(Nat.div(a, 400n), Nat.mod(a, 400n), 11n, 30n) : Nat}:
  match r:
    case True{}:
      +e = Nat.div(a, 400n)
      +a1 = Nat.mod(a, 400n)
      %Equal.sym(Nat & Nat, Nat.divmod(1n+a, 400n), (e, 1n+a1), A.div_succ_in(a, 400n, {==}, hr)) : {D.days_century(Pair.fst(Nat, Nat, _), Pair.snd(Nat, Nat, _), 0n, 0n) == 1n+D.days_century(e, a1, 11n, 30n) : Nat}
      century_carry(e, a1, hr)
    case False{}:
      +step = A.div_succ_wrap(a, 400n, {==}, hr)
      +h399 = pred_of(Nat.mod(a, 400n), 400n, A.succ_eq_of_lt(Nat.mod(a, 400n), 400n, A.mod_lt(a, 400n, {==}), hr))
      step_cycle(Nat.div(1n+a, 400n), Nat.div(a, 400n), Nat.mod(1n+a, 400n), Nat.mod(a, 400n), fst_eq(Nat.divmod(1n+a, 400n), 1n+Nat.div(a, 400n), 0n, step), snd_eq(Nat.divmod(1n+a, 400n), 1n+Nat.div(a, 400n), 0n, step), h399)

# The day after December 31 of any year from 1600 on.
law year_carry:
  for +a: Nat
  {D.days_century(Nat.div(1n+a, 400n), Nat.mod(1n+a, 400n), 0n, 0n) == 1n+D.days_century(Nat.div(a, 400n), Nat.mod(a, 400n), 11n, 30n) : Nat}

def year_carry(a):
  year_carry_case(a, Nat.is_lt(1n+Nat.mod(a, 400n), 400n), {==})
