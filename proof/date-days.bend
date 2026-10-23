# The production encoder counts the spec's civil days: day n of the spec
# encodes as n + 135140 days after 1600-01-01.
import Base
import ../src/http/date.bend as D
import ./date-spec.bend as S
import ./date-arith.bend as A
import ./date-walk.bend as W
import ./date-calendar.bend as C

def date_days(date: Nat & (Nat & Nat)) -> Nat:
  (y, md) = date
  (m, d) = md
  D.days_from(y, m, d)

def next_case(+y: Nat, +mp: Nat, +dp: Nat, +ge: {Nat.is_le(1600n, y) == True{} : Bool}, +lm: {Nat.is_lt(mp, 12n) == True{} : Bool}, +ld: {Nat.is_le(1n+dp, S.month_days(y, 1n+mp)) == True{} : Bool}, +full: {1n+dp == S.month_days(y, 1n+mp) : Nat}, r: Bool, +hr: {Nat.is_lt(1n+mp, 12n) == r : Bool}) -> {date_days(S.next_month(y, 1n+mp, r)) == 1n+D.days_from(y, 1n+mp, 1n+dp) : Nat}:
  match r:
    case True{}:
      +a = Nat.sub(y, 1600n)
      %Equal.sym(Nat, Nat.sub(dp, 0n), dp, A.sub_zero_r(dp)) : {D.days_from(y, 2n+mp, 1n) == 1n+D.days_century(Nat.div(a, 400n), Nat.mod(a, 400n), Nat.sub(mp, 0n), _) : Nat}
      %Equal.sym(Nat, Nat.sub(mp, 0n), mp, A.sub_zero_r(mp)) : {D.days_from(y, 2n+mp, 1n) == 1n+D.days_century(Nat.div(a, 400n), Nat.mod(a, 400n), _, dp) : Nat}
      +lp = D.leap(C.yc(y), C.yq(y), C.yy(y))
      C.days_month_next(C.ye(y), C.yc(y), C.yq(y), C.yy(y), mp, dp, lm, Equal.trans(Nat, 1n+dp, S.month_days(y, 1n+mp), W.nth(mp, D.month_lengths(lp)), full, C.month_table(y, mp, lp, C.leap_agrees(y, ge), lm)))
    case False{}:
      +h11 = C.pred_of(mp, 12n, A.succ_eq_of_lt(mp, 12n, lm, hr))
      +h31 = Equal.trans(Nat, 1n+dp, S.month_days(y, 1n+mp), S.month_days(y, 12n), full, Equal.cong(Nat, Nat, x => S.month_days(y, 1n+x), mp, 11n, h11))
      +h30 = C.pred_of(dp, 31n, h31)
      %Equal.sym(Nat, mp, 11n, h11) : {date_days(S.next_month(y, 1n+mp, False{})) == 1n+D.days_from(y, 1n+_, 1n+dp) : Nat}
      %Equal.sym(Nat, dp, 30n, h30) : {date_days(S.next_month(y, 1n+mp, False{})) == 1n+D.days_from(y, 12n, 1n+_) : Nat}
      %Equal.sym(Nat, Nat.sub(1n+y, 1600n), 1n+Nat.sub(y, 1600n), A.sub_succ_l(1600n, y, ge)) : {D.days_century(Nat.div(_, 400n), Nat.mod(_, 400n), 0n, 0n) == 1n+D.days_from(y, 12n, 31n) : Nat}
      C.year_carry(Nat.sub(y, 1600n))

def day_case(+y: Nat, +mp: Nat, +dp: Nat, +ge: {Nat.is_le(1600n, y) == True{} : Bool}, +lm: {Nat.is_lt(mp, 12n) == True{} : Bool}, +ld: {Nat.is_le(1n+dp, S.month_days(y, 1n+mp)) == True{} : Bool}, r: Bool, +hr: {Nat.is_lt(1n+dp, S.month_days(y, 1n+mp)) == r : Bool}) -> {date_days(S.next_in_month(y, 1n+mp, 1n+dp, r)) == 1n+D.days_from(y, 1n+mp, 1n+dp) : Nat}:
  match r:
    case True{}:
      +a = Nat.sub(y, 1600n)
      %Equal.sym(Nat, Nat.sub(dp, 0n), dp, A.sub_zero_r(dp)) : {D.days_from(y, 1n+mp, 2n+dp) == 1n+D.days_century(Nat.div(a, 400n), Nat.mod(a, 400n), Nat.sub(mp, 0n), _) : Nat}
      C.days_succ(C.ye(y), C.yc(y), C.yq(y), C.yy(y), Nat.sub(mp, 0n), dp)
    case False{}:
      next_case(y, mp, dp, ge, lm, ld, A.le_not_lt_eq(1n+dp, S.month_days(y, 1n+mp), ld, hr), Nat.is_lt(1n+mp, 12n), {==})

law enc_next:
  for +y: Nat
  for +mp: Nat
  for +dp: Nat
  for +ge: {Nat.is_le(1600n, y) == True{} : Bool}
  for +lm: {Nat.is_lt(mp, 12n) == True{} : Bool}
  for +ld: {Nat.is_le(1n+dp, S.month_days(y, 1n+mp)) == True{} : Bool}
  {date_days(S.next_day((y, (1n+mp, 1n+dp)))) == 1n+date_days((y, (1n+mp, 1n+dp))) : Nat}

def enc_next(y, mp, dp, ge, lm, ld):
  day_case(y, mp, dp, ge, lm, ld, Nat.is_lt(1n+dp, S.month_days(y, 1n+mp)), {==})

# Valid spec dates.

def valid3(+y: Nat, +m: Nat, +d: Nat) -> Bool:
  Bool.and(Nat.is_le(1970n, y), Bool.and(Nat.is_le(1n, m), Bool.and(Nat.is_le(m, 12n), Bool.and(Nat.is_le(1n, d), Nat.is_le(d, S.month_days(y, m))))))

def valid(date: Nat & (Nat & Nat)) -> Bool:
  (y, md) = date
  (m, d) = md
  valid3(y, m, d)

def feb_pos(b: Bool) -> {Nat.is_le(1n, S.february(b)) == True{} : Bool}:
  match b:
    case True{}:
      {==}
    case False{}:
      {==}

law month_pos:
  for +y: Nat
  for +m: Nat
  {Nat.is_le(1n, S.month_days(y, m)) == True{} : Bool}

def month_pos(y, m):
  match m:
    case 0n:
      {==}
    case 1n:
      {==}
    case 2n:
      feb_pos(S.leap(y))
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
      {==}

law and_intro:
  for +a: Bool
  for +b: Bool
  for ha: {a == True{} : Bool}
  for hb: {b == True{} : Bool}
  {Bool.and(a, b) == True{} : Bool}

def and_intro(a, b, ha, hb):
  %Equal.sym(Bool, a, True{}, ha) : {Bool.and(_, b) == True{} : Bool}
  hb

def valid_month(+y: Nat, +mp: Nat, +v1: {Nat.is_le(1970n, y) == True{} : Bool}, r: Bool, +hr: {Nat.is_lt(1n+mp, 12n) == r : Bool}) -> {valid(S.next_month(y, 1n+mp, r)) == True{} : Bool}:
  match r:
    case True{}:
      and_intro(Nat.is_le(1970n, y), Bool.and(Nat.is_le(1n, 2n+mp), Bool.and(Nat.is_le(2n+mp, 12n), Bool.and(Nat.is_le(1n, 1n), Nat.is_le(1n, S.month_days(y, 2n+mp))))), v1, and_intro(Nat.is_le(1n, 2n+mp), Bool.and(Nat.is_le(2n+mp, 12n), Bool.and(Nat.is_le(1n, 1n), Nat.is_le(1n, S.month_days(y, 2n+mp)))), {==}, and_intro(Nat.is_le(2n+mp, 12n), Bool.and(Nat.is_le(1n, 1n), Nat.is_le(1n, S.month_days(y, 2n+mp))), A.succ_le_of_lt(1n+mp, 12n, hr), month_pos(y, 2n+mp))))
    case False{}:
      and_intro(Nat.is_le(1970n, 1n+y), Bool.and(Nat.is_le(1n, 1n), Bool.and(Nat.is_le(1n, 12n), Bool.and(Nat.is_le(1n, 1n), Nat.is_le(1n, S.month_days(1n+y, 1n))))), A.le_succ_r(1970n, y, v1), {==})

def valid_day(+y: Nat, +mp: Nat, +dp: Nat, +v1: {Nat.is_le(1970n, y) == True{} : Bool}, +v3: {Nat.is_le(1n+mp, 12n) == True{} : Bool}, +v5: {Nat.is_le(1n+dp, S.month_days(y, 1n+mp)) == True{} : Bool}, r: Bool, +hr: {Nat.is_lt(1n+dp, S.month_days(y, 1n+mp)) == r : Bool}) -> {valid(S.next_in_month(y, 1n+mp, 1n+dp, r)) == True{} : Bool}:
  match r:
    case True{}:
      and_intro(Nat.is_le(1970n, y), Bool.and(Nat.is_le(1n, 1n+mp), Bool.and(Nat.is_le(1n+mp, 12n), Bool.and(Nat.is_le(1n, 2n+dp), Nat.is_le(2n+dp, S.month_days(y, 1n+mp))))), v1, and_intro(Nat.is_le(1n, 1n+mp), Bool.and(Nat.is_le(1n+mp, 12n), Bool.and(Nat.is_le(1n, 2n+dp), Nat.is_le(2n+dp, S.month_days(y, 1n+mp)))), A.zero_le(mp), and_intro(Nat.is_le(1n+mp, 12n), Bool.and(Nat.is_le(1n, 2n+dp), Nat.is_le(2n+dp, S.month_days(y, 1n+mp))), v3, and_intro(Nat.is_le(1n, 2n+dp), Nat.is_le(2n+dp, S.month_days(y, 1n+mp)), {==}, A.succ_le_of_lt(1n+dp, S.month_days(y, 1n+mp), hr)))))
    case False{}:
      valid_month(y, mp, v1, Nat.is_lt(1n+mp, 12n), {==})

def vrest1(+y: Nat, +m: Nat, +d: Nat, +v: {valid3(y, m, d) == True{} : Bool}) -> {Bool.and(Nat.is_le(1n, m), Bool.and(Nat.is_le(m, 12n), Bool.and(Nat.is_le(1n, d), Nat.is_le(d, S.month_days(y, m))))) == True{} : Bool}:
  A.and_right(Nat.is_le(1970n, y), Bool.and(Nat.is_le(1n, m), Bool.and(Nat.is_le(m, 12n), Bool.and(Nat.is_le(1n, d), Nat.is_le(d, S.month_days(y, m))))), v)

def vrest2(+y: Nat, +m: Nat, +d: Nat, +v: {valid3(y, m, d) == True{} : Bool}) -> {Bool.and(Nat.is_le(m, 12n), Bool.and(Nat.is_le(1n, d), Nat.is_le(d, S.month_days(y, m)))) == True{} : Bool}:
  A.and_right(Nat.is_le(1n, m), Bool.and(Nat.is_le(m, 12n), Bool.and(Nat.is_le(1n, d), Nat.is_le(d, S.month_days(y, m)))), vrest1(y, m, d, v))

def vrest3(+y: Nat, +m: Nat, +d: Nat, +v: {valid3(y, m, d) == True{} : Bool}) -> {Bool.and(Nat.is_le(1n, d), Nat.is_le(d, S.month_days(y, m))) == True{} : Bool}:
  A.and_right(Nat.is_le(m, 12n), Bool.and(Nat.is_le(1n, d), Nat.is_le(d, S.month_days(y, m))), vrest2(y, m, d, v))

def valid_year(+y: Nat, +m: Nat, +d: Nat, +v: {valid3(y, m, d) == True{} : Bool}) -> {Nat.is_le(1970n, y) == True{} : Bool}:
  A.and_left(Nat.is_le(1970n, y), Bool.and(Nat.is_le(1n, m), Bool.and(Nat.is_le(m, 12n), Bool.and(Nat.is_le(1n, d), Nat.is_le(d, S.month_days(y, m))))), v)

def valid_mon1(+y: Nat, +m: Nat, +d: Nat, +v: {valid3(y, m, d) == True{} : Bool}) -> {Nat.is_le(1n, m) == True{} : Bool}:
  A.and_left(Nat.is_le(1n, m), Bool.and(Nat.is_le(m, 12n), Bool.and(Nat.is_le(1n, d), Nat.is_le(d, S.month_days(y, m)))), vrest1(y, m, d, v))

def valid_mon12(+y: Nat, +m: Nat, +d: Nat, +v: {valid3(y, m, d) == True{} : Bool}) -> {Nat.is_le(m, 12n) == True{} : Bool}:
  A.and_left(Nat.is_le(m, 12n), Bool.and(Nat.is_le(1n, d), Nat.is_le(d, S.month_days(y, m))), vrest2(y, m, d, v))

def valid_day1(+y: Nat, +m: Nat, +d: Nat, +v: {valid3(y, m, d) == True{} : Bool}) -> {Nat.is_le(1n, d) == True{} : Bool}:
  A.and_left(Nat.is_le(1n, d), Nat.is_le(d, S.month_days(y, m)), vrest3(y, m, d, v))

def valid_dayn(+y: Nat, +m: Nat, +d: Nat, +v: {valid3(y, m, d) == True{} : Bool}) -> {Nat.is_le(d, S.month_days(y, m)) == True{} : Bool}:
  A.and_right(Nat.is_le(1n, d), Nat.is_le(d, S.month_days(y, m)), vrest3(y, m, d, v))

def valid_from(+y: Nat, +m: Nat, +d: Nat, +v: {valid3(y, m, d) == True{} : Bool}) -> {valid(S.next_day((y, (m, d)))) == True{} : Bool}:
  match m d:
    case 0n d:
      A.absurd({valid(S.next_day((y, (0n, d)))) == True{} : Bool}, A.false_true(valid_mon1(y, 0n, d, v)))
    case 1n+mp 0n:
      A.absurd({valid(S.next_day((y, (1n+mp, 0n)))) == True{} : Bool}, A.false_true(valid_day1(y, 1n+mp, 0n, v)))
    case 1n+mp 1n+dp:
      valid_day(y, mp, dp, valid_year(y, 1n+mp, 1n+dp, v), valid_mon12(y, 1n+mp, 1n+dp, v), valid_dayn(y, 1n+mp, 1n+dp, v), Nat.is_lt(1n+dp, S.month_days(y, 1n+mp)), {==})

law valid_next:
  for date: Nat & (Nat & Nat)
  for v: {valid(date) == True{} : Bool}
  {valid(S.next_day(date)) == True{} : Bool}

def valid_next(date, v):
  match date:
    case (y, md):
      match md:
        case (m, d):
          valid_from(y, m, d, v)

law civil_valid:
  for +n: Nat
  {valid(S.civil(n)) == True{} : Bool}

def civil_valid(n):
  match n:
    case 0n:
      {==}
    case 1n+p:
      valid_next(S.civil(p), civil_valid(p))

def enc_from(+y: Nat, +m: Nat, +d: Nat, +v: {valid3(y, m, d) == True{} : Bool}) -> {date_days(S.next_day((y, (m, d)))) == 1n+date_days((y, (m, d))) : Nat}:
  match m d:
    case 0n d:
      A.absurd({date_days(S.next_day((y, (0n, d)))) == 1n+date_days((y, (0n, d))) : Nat}, A.false_true(valid_mon1(y, 0n, d, v)))
    case 1n+mp 0n:
      A.absurd({date_days(S.next_day((y, (1n+mp, 0n)))) == 1n+date_days((y, (1n+mp, 0n))) : Nat}, A.false_true(valid_day1(y, 1n+mp, 0n, v)))
    case 1n+mp 1n+dp:
      enc_next(y, mp, dp, A.le_trans(1600n, 1970n, y, {==}, valid_year(y, 1n+mp, 1n+dp, v)), A.lt_of_succ_le(mp, 12n, valid_mon12(y, 1n+mp, 1n+dp, v)), valid_dayn(y, 1n+mp, 1n+dp, v))

law enc_step:
  for date: Nat & (Nat & Nat)
  for v: {valid(date) == True{} : Bool}
  {date_days(S.next_day(date)) == 1n+date_days(date) : Nat}

def enc_step(date, v):
  match date:
    case (y, md):
      match md:
        case (m, d):
          enc_from(y, m, d, v)

# Day n of the spec encodes as n days after 1970-01-01, day 135140 after
# 1600-01-01.
law days_civil:
  for +n: Nat
  {date_days(S.civil(n)) == Nat.add(n, 135140n) : Nat}

def days_civil(n):
  match n:
    case 0n:
      A.eq_of_is_eq(date_days(S.civil(0n)), Nat.add(0n, 135140n), {==})
    case 1n+p:
      Equal.trans(Nat, date_days(S.next_day(S.civil(p))), 1n+date_days(S.civil(p)), 1n+Nat.add(p, 135140n), enc_step(S.civil(p), civil_valid(p)), Equal.cong(Nat, Nat, x => 1n+x, date_days(S.civil(p)), Nat.add(p, 135140n), days_civil(p)))
