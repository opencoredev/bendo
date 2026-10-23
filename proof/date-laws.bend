# Assembly of the BND-80 date laws from the calendar, text and bound lemmas.
import Base
import ../src/http/date.bend as D
import ./date-spec.bend as S
import ./date-arith.bend as A
import ./date-walk.bend as W
import ./date-calendar.bend as C
import ./date-days.bend as Days
import ./date-decode.bend as Dec
import ./date-text.bend as Tx
import ../src/router/equality-proofs.bend as Eq

# A day count below 10957 + 20 * 146097 is a date before 10000-01-01.

def le_eq_r(+a: Nat, +b: Nat, +c: Nat, le: {Nat.is_le(a, b) == True{} : Bool}, e: {b == c : Nat}) -> {Nat.is_le(a, c) == True{} : Bool}:
  %e : {Nat.is_le(a, _) == True{} : Bool}
  le

def le_eq_l(+a: Nat, +b: Nat, +c: Nat, le: {Nat.is_le(a, c) == True{} : Bool}, e: {a == b : Nat}) -> {Nat.is_le(b, c) == True{} : Bool}:
  %e : {Nat.is_le(_, c) == True{} : Bool}
  le

def cycles_le_days(+y: Nat, +m: Nat, +d: Nat) -> {Nat.is_le(Nat.mul(C.ye(y), 146097n), D.days_from(y, m, d)) == True{} : Bool}:
  A.le_add_self(Nat.mul(C.ye(y), 146097n), D.before(C.yc(y), D.century_lengths(), D.before(C.yq(y), D.group_lengths(D.is_zero(C.yc(y))), D.before(C.yy(y), D.year_lengths(D.long_group(C.yc(y), C.yq(y))), D.before(Nat.sub(m, 1n), D.month_lengths(D.leap(C.yc(y), C.yq(y), C.yy(y))), Nat.sub(d, 1n))))))

def mul_succ(+b: Nat, +k: Nat) -> {Nat.mul(1n+b, k) == Nat.add(k, Nat.mul(b, k)) : Nat}:
  {==}

def year_case(+y: Nat, +m: Nat, +d: Nat, +n: Nat, +hd: {D.days_from(y, m, d) == Nat.add(n, 135140n) : Nat}, +hn: {Nat.is_lt(n, Nat.add(10957n, Nat.mul(20n, 146097n))) == True{} : Bool}, r: Bool, e: {Nat.is_lt(y, 10000n) == r : Bool}) -> {Nat.is_lt(y, 10000n) == True{} : Bool}:
  match r:
    case True{}:
      e
    case False{}:
      +ge = A.not_lt_le(y, 10000n, e)
      +a8400 = A.le_trans(Nat.mul(21n, 400n), Nat.sub(10000n, 1600n), C.ya(y), {==}, A.le_sub_mono(10000n, y, 1600n, ge))
      +e21 = A.le_div_of_mul_le(21n, C.ya(y), 400n, {==}, a8400)
      +low = A.le_trans(Nat.mul(1n+20n, 146097n), Nat.mul(C.ye(y), 146097n), Nat.add(n, 135140n), A.le_mul_mono(1n+20n, C.ye(y), 146097n, e21), le_eq_r(Nat.mul(C.ye(y), 146097n), D.days_from(y, m, d), Nat.add(n, 135140n), cycles_le_days(y, m, d), hd))
      +low2 = le_eq_l(Nat.mul(1n+20n, 146097n), Nat.add(146097n, Nat.mul(20n, 146097n)), Nat.add(n, 135140n), low, mul_succ(20n, 146097n))
      +k1 = le_eq_l(Nat.add(146097n, Nat.mul(20n, 146097n)), Nat.add(Nat.add(135140n, 10957n), Nat.mul(20n, 146097n)), Nat.add(n, 135140n), low2, Equal.cong(Nat, Nat, z => Nat.add(z, Nat.mul(20n, 146097n)), 146097n, Nat.add(135140n, 10957n), A.eq_of_is_eq(146097n, Nat.add(135140n, 10957n), {==})))
      +k2 = le_eq_l(Nat.add(Nat.add(135140n, 10957n), Nat.mul(20n, 146097n)), Nat.add(135140n, Nat.add(10957n, Nat.mul(20n, 146097n))), Nat.add(n, 135140n), k1, A.add_assoc(135140n, 10957n, Nat.mul(20n, 146097n)))
      +k3 = le_eq_r(Nat.add(135140n, Nat.add(10957n, Nat.mul(20n, 146097n))), Nat.add(n, 135140n), Nat.add(135140n, n), k2, A.add_comm(n, 135140n))
      A.absurd({Nat.is_lt(y, 10000n) == True{} : Bool}, A.lt_le_absurd(n, Nat.add(10957n, Nat.mul(20n, 146097n)), hn, A.le_add_cancel(135140n, Nat.add(10957n, Nat.mul(20n, 146097n)), n, k3)))

law year_lt:
  for +y: Nat
  for +m: Nat
  for +d: Nat
  for +n: Nat
  for +hd: {D.days_from(y, m, d) == Nat.add(n, 135140n) : Nat}
  for +hn: {Nat.is_lt(n, Nat.add(10957n, Nat.mul(20n, 146097n))) == True{} : Bool}
  {Nat.is_lt(y, 10000n) == True{} : Bool}

def year_lt(y, m, d, n, hd, hn):
  year_case(y, m, d, n, hd, hn, Nat.is_lt(y, 10000n), {==})

def days_sub(+x: Nat, +k: Nat) -> {Nat.sub(Nat.add(x, k), k) == x : Nat}:
  %A.add_comm(k, x) : {Nat.sub(_, k) == x : Nat}
  A.sub_add_cancel(k, x)

def feb_le(b: Bool) -> {Nat.is_le(S.february(b), 31n) == True{} : Bool}:
  match b:
    case True{}:
      {==}
    case False{}:
      {==}

law month_le:
  for +y: Nat
  for +m: Nat
  {Nat.is_le(S.month_days(y, m), 31n) == True{} : Bool}

def month_le(y, m):
  match m:
    case 0n:
      {==}
    case 1n:
      {==}
    case 2n:
      feb_le(S.leap(y))
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

def day_lt(+y: Nat, +mp: Nat, +dp: Nat, +v: {Days.valid3(y, 1n+mp, 1n+dp) == True{} : Bool}) -> {Nat.is_lt(1n+dp, 100n) == True{} : Bool}:
  A.lt_le_trans(1n+dp, 32n, 100n, A.lt_succ_of_le(1n+dp, 31n, A.le_trans(1n+dp, S.month_days(y, 1n+mp), 31n, Days.valid_dayn(y, 1n+mp, 1n+dp, v), month_le(y, 1n+mp))), {==})

# Fewer than twenty 400-year cycles after 2000-01-01.
law limit_of:
  for +n: Nat
  for +h: {Nat.is_lt(Nat.div(Nat.sub(n, 10957n), 146097n), 20n) == True{} : Bool}
  {Nat.is_lt(n, Nat.add(10957n, Nat.mul(20n, 146097n))) == True{} : Bool}

def limit_of(n, h):
  A.lt_of_sub_lt(n, 10957n, Nat.mul(20n, 146097n), A.lt_mul_of_div_lt(Nat.sub(n, 10957n), 20n, 146097n, {==}, h))

# The formatted text in range.
law fmt_eq:
  for +s: Nat
  for bound: {Nat.is_lt(Nat.div(Nat.sub(Nat.div(s, 86400n), 10957n), 146097n), 20n) == True{} : Bool}
  {D.format_imf(s) == D.render_date(Nat.mod(Nat.add(Nat.div(s, 86400n), 4n), 7n), S.civil(Nat.div(s, 86400n)), Nat.mod(s, 86400n)) : String}

def fmt_eq(s, bound):
  %Equal.sym(Bool, Nat.is_lt(Nat.div(Nat.sub(Nat.div(s, 86400n), 10957n), 146097n), 20n), True{}, bound) : {D.format_valid(s, _) == D.render_date(Nat.mod(Nat.add(Nat.div(s, 86400n), 4n), 7n), S.civil(Nat.div(s, 86400n)), Nat.mod(s, 86400n)) : String}
  Equal.cong(Nat & (Nat & Nat), String, z => D.render_date(Nat.mod(Nat.add(Nat.div(s, 86400n), 4n), 7n), z, Nat.mod(s, 86400n)), D.civil(Nat.add(Nat.div(s, 86400n), 135140n)), S.civil(Nat.div(s, 86400n)), Dec.civil_day(Nat.div(s, 86400n)))

def spec_from(+s: Nat, +y: Nat, +m: Nat, +d: Nat, +hdt: {S.civil(Nat.div(s, 86400n)) == (y, (m, d)) : Nat & (Nat & Nat)}, +v: {Days.valid3(y, m, d) == True{} : Bool}, +hd: {D.days_from(y, m, d) == Nat.add(Nat.div(s, 86400n), 135140n) : Nat}, +bound: {Nat.is_lt(Nat.div(Nat.sub(Nat.div(s, 86400n), 10957n), 146097n), 20n) == True{} : Bool}) -> {S.denotes(D.render_date(Nat.mod(Nat.add(Nat.div(s, 86400n), 4n), 7n), (y, (m, d)), Nat.mod(s, 86400n)), s) == True{} : Bool}:
  match m d:
    case 0n d:
      A.absurd({S.denotes(D.render_date(Nat.mod(Nat.add(Nat.div(s, 86400n), 4n), 7n), (y, (0n, d)), Nat.mod(s, 86400n)), s) == True{} : Bool}, A.false_true(Days.valid_mon1(y, 0n, d, v)))
    case 1n+mp 0n:
      A.absurd({S.denotes(D.render_date(Nat.mod(Nat.add(Nat.div(s, 86400n), 4n), 7n), (y, (1n+mp, 0n)), Nat.mod(s, 86400n)), s) == True{} : Bool}, A.false_true(Days.valid_day1(y, 1n+mp, 0n, v)))
    case 1n+mp 1n+dp:
      %Equal.sym(Nat & (Nat & Nat), S.civil(Nat.div(s, 86400n)), (y, (1n+mp, 1n+dp)), hdt) : {S.fields_ok(_, S.weekday(Nat.div(s, 86400n)), Nat.mod(s, 86400n), S.three(D.at0(D.weekday_name(Nat.mod(Nat.add(Nat.div(s, 86400n), 4n), 7n))), D.at1(D.weekday_name(Nat.mod(Nat.add(Nat.div(s, 86400n), 4n), 7n))), D.at2(D.weekday_name(Nat.mod(Nat.add(Nat.div(s, 86400n), 4n), 7n)))), D.tens(1n+dp), D.ones(1n+dp), S.three(D.at0(D.month_name(1n+mp)), D.at1(D.month_name(1n+mp)), D.at2(D.month_name(1n+mp))), D.thousands(y), D.hundreds(y), D.decades(y), D.ones(y), D.tens(Nat.div(Nat.mod(s, 86400n), 3600n)), D.ones(Nat.div(Nat.mod(s, 86400n), 3600n)), D.tens(Nat.div(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n)), D.ones(Nat.div(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n)), D.tens(Nat.mod(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n)), D.ones(Nat.mod(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n))) == True{} : Bool}
      %Tx.weekday_eq(Nat.div(s, 86400n)) : {S.fields_ok((y, (1n+mp, 1n+dp)), _, Nat.mod(s, 86400n), S.three(D.at0(D.weekday_name(Nat.mod(Nat.add(Nat.div(s, 86400n), 4n), 7n))), D.at1(D.weekday_name(Nat.mod(Nat.add(Nat.div(s, 86400n), 4n), 7n))), D.at2(D.weekday_name(Nat.mod(Nat.add(Nat.div(s, 86400n), 4n), 7n)))), D.tens(1n+dp), D.ones(1n+dp), S.three(D.at0(D.month_name(1n+mp)), D.at1(D.month_name(1n+mp)), D.at2(D.month_name(1n+mp))), D.thousands(y), D.hundreds(y), D.decades(y), D.ones(y), D.tens(Nat.div(Nat.mod(s, 86400n), 3600n)), D.ones(Nat.div(Nat.mod(s, 86400n), 3600n)), D.tens(Nat.div(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n)), D.ones(Nat.div(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n)), D.tens(Nat.mod(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n)), D.ones(Nat.mod(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n))) == True{} : Bool}
      Tx.and_true(String.eq(S.three(D.at0(D.weekday_name(Nat.mod(Nat.add(Nat.div(s, 86400n), 4n), 7n))), D.at1(D.weekday_name(Nat.mod(Nat.add(Nat.div(s, 86400n), 4n), 7n))), D.at2(D.weekday_name(Nat.mod(Nat.add(Nat.div(s, 86400n), 4n), 7n)))), S.day_name(Nat.mod(Nat.add(Nat.div(s, 86400n), 4n), 7n))), Bool.and(S.day_ok(D.tens(1n+dp), D.ones(1n+dp), 1n+dp), Bool.and(String.eq(S.three(D.at0(D.month_name(1n+mp)), D.at1(D.month_name(1n+mp)), D.at2(D.month_name(1n+mp))), S.month_name(1n+mp)), Bool.and(S.year_ok(D.thousands(y), D.hundreds(y), D.decades(y), D.ones(y), y), S.time_ok(D.tens(Nat.div(Nat.mod(s, 86400n), 3600n)), D.ones(Nat.div(Nat.mod(s, 86400n), 3600n)), D.tens(Nat.div(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n)), D.ones(Nat.div(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n)), D.tens(Nat.mod(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n)), D.ones(Nat.mod(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n)), Nat.mod(s, 86400n))))), Tx.wd_ok(Nat.mod(Nat.add(Nat.div(s, 86400n), 4n), 7n), A.mod_lt(Nat.add(Nat.div(s, 86400n), 4n), 7n, {==})), Tx.and_true(S.day_ok(D.tens(1n+dp), D.ones(1n+dp), 1n+dp), Bool.and(String.eq(S.three(D.at0(D.month_name(1n+mp)), D.at1(D.month_name(1n+mp)), D.at2(D.month_name(1n+mp))), S.month_name(1n+mp)), Bool.and(S.year_ok(D.thousands(y), D.hundreds(y), D.decades(y), D.ones(y), y), S.time_ok(D.tens(Nat.div(Nat.mod(s, 86400n), 3600n)), D.ones(Nat.div(Nat.mod(s, 86400n), 3600n)), D.tens(Nat.div(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n)), D.ones(Nat.div(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n)), D.tens(Nat.mod(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n)), D.ones(Nat.mod(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n)), Nat.mod(s, 86400n)))), Tx.day_ok(1n+dp, day_lt(y, mp, dp, v)), Tx.and_true(String.eq(S.three(D.at0(D.month_name(1n+mp)), D.at1(D.month_name(1n+mp)), D.at2(D.month_name(1n+mp))), S.month_name(1n+mp)), Bool.and(S.year_ok(D.thousands(y), D.hundreds(y), D.decades(y), D.ones(y), y), S.time_ok(D.tens(Nat.div(Nat.mod(s, 86400n), 3600n)), D.ones(Nat.div(Nat.mod(s, 86400n), 3600n)), D.tens(Nat.div(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n)), D.ones(Nat.div(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n)), D.tens(Nat.mod(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n)), D.ones(Nat.mod(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n)), Nat.mod(s, 86400n))), Tx.mon_ok(mp, A.lt_of_succ_le(mp, 12n, Days.valid_mon12(y, 1n+mp, 1n+dp, v))), Tx.and_true(S.year_ok(D.thousands(y), D.hundreds(y), D.decades(y), D.ones(y), y), S.time_ok(D.tens(Nat.div(Nat.mod(s, 86400n), 3600n)), D.ones(Nat.div(Nat.mod(s, 86400n), 3600n)), D.tens(Nat.div(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n)), D.ones(Nat.div(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n)), D.tens(Nat.mod(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n)), D.ones(Nat.mod(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n)), Nat.mod(s, 86400n)), Tx.year_ok(y, year_lt(y, 1n+mp, 1n+dp, Nat.div(s, 86400n), hd, limit_of(Nat.div(s, 86400n), bound))), Tx.time_ok(Nat.mod(s, 86400n), A.mod_lt(s, 86400n, {==}))))))

def rt_from(+s: Nat, +y: Nat, +m: Nat, +d: Nat, +v: {Days.valid3(y, m, d) == True{} : Bool}, +hd: {D.days_from(y, m, d) == Nat.add(Nat.div(s, 86400n), 135140n) : Nat}, +bound: {Nat.is_lt(Nat.div(Nat.sub(Nat.div(s, 86400n), 10957n), 146097n), 20n) == True{} : Bool}) -> {D.read_imf(D.render_date(Nat.mod(Nat.add(Nat.div(s, 86400n), 4n), 7n), (y, (m, d)), Nat.mod(s, 86400n))) == Some{s} : Maybe<&2, Nat>}:
  match m d:
    case 0n d:
      A.absurd({D.read_imf(D.render_date(Nat.mod(Nat.add(Nat.div(s, 86400n), 4n), 7n), (y, (0n, d)), Nat.mod(s, 86400n))) == Some{s} : Maybe<&2, Nat>}, A.false_true(Days.valid_mon1(y, 0n, d, v)))
    case 1n+mp 0n:
      A.absurd({D.read_imf(D.render_date(Nat.mod(Nat.add(Nat.div(s, 86400n), 4n), 7n), (y, (1n+mp, 0n)), Nat.mod(s, 86400n))) == Some{s} : Maybe<&2, Nat>}, A.false_true(Days.valid_day1(y, 1n+mp, 0n, v)))
    case 1n+mp 1n+dp:
      %Equal.sym(Nat, D.read4(D.thousands(y), D.hundreds(y), D.decades(y), D.ones(y)), y, Tx.four_prod(y, year_lt(y, 1n+mp, 1n+dp, Nat.div(s, 86400n), hd, limit_of(Nat.div(s, 86400n), bound)))) : {Some{D.seconds_from(Nat.sub(D.days_from(_, D.month_number(SCon{D.at0(D.month_name(1n+mp)), SCon{D.at1(D.month_name(1n+mp)), SCon{D.at2(D.month_name(1n+mp)), SNil{}}}}), D.read2(D.tens(1n+dp), D.ones(1n+dp))), 135140n), D.read2(D.tens(Nat.div(Nat.mod(s, 86400n), 3600n)), D.ones(Nat.div(Nat.mod(s, 86400n), 3600n))), D.read2(D.tens(Nat.div(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n)), D.ones(Nat.div(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n))), D.read2(D.tens(Nat.mod(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n)), D.ones(Nat.mod(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n))))} == Some{s} : Maybe<&2, Nat>}
      %Equal.sym(Nat, D.month_number(SCon{D.at0(D.month_name(1n+mp)), SCon{D.at1(D.month_name(1n+mp)), SCon{D.at2(D.month_name(1n+mp)), SNil{}}}}), 1n+mp, Tx.mon_num(mp, A.lt_of_succ_le(mp, 12n, Days.valid_mon12(y, 1n+mp, 1n+dp, v)))) : {Some{D.seconds_from(Nat.sub(D.days_from(y, _, D.read2(D.tens(1n+dp), D.ones(1n+dp))), 135140n), D.read2(D.tens(Nat.div(Nat.mod(s, 86400n), 3600n)), D.ones(Nat.div(Nat.mod(s, 86400n), 3600n))), D.read2(D.tens(Nat.div(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n)), D.ones(Nat.div(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n))), D.read2(D.tens(Nat.mod(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n)), D.ones(Nat.mod(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n))))} == Some{s} : Maybe<&2, Nat>}
      %Equal.sym(Nat, D.read2(D.tens(1n+dp), D.ones(1n+dp)), 1n+dp, Tx.two_prod(1n+dp, day_lt(y, mp, dp, v))) : {Some{D.seconds_from(Nat.sub(D.days_from(y, 1n+mp, _), 135140n), D.read2(D.tens(Nat.div(Nat.mod(s, 86400n), 3600n)), D.ones(Nat.div(Nat.mod(s, 86400n), 3600n))), D.read2(D.tens(Nat.div(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n)), D.ones(Nat.div(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n))), D.read2(D.tens(Nat.mod(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n)), D.ones(Nat.mod(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n))))} == Some{s} : Maybe<&2, Nat>}
      %Equal.sym(Nat, D.read2(D.tens(Nat.div(Nat.mod(s, 86400n), 3600n)), D.ones(Nat.div(Nat.mod(s, 86400n), 3600n))), Nat.div(Nat.mod(s, 86400n), 3600n), Tx.two_prod(Nat.div(Nat.mod(s, 86400n), 3600n), Tx.under100(Nat.div(Nat.mod(s, 86400n), 3600n), 24n, Tx.hour_lt(Nat.mod(s, 86400n), A.mod_lt(s, 86400n, {==})), {==}))) : {Some{D.seconds_from(Nat.sub(D.days_from(y, 1n+mp, 1n+dp), 135140n), _, D.read2(D.tens(Nat.div(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n)), D.ones(Nat.div(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n))), D.read2(D.tens(Nat.mod(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n)), D.ones(Nat.mod(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n))))} == Some{s} : Maybe<&2, Nat>}
      %Equal.sym(Nat, D.read2(D.tens(Nat.div(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n)), D.ones(Nat.div(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n))), Nat.div(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n), Tx.two_prod(Nat.div(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n), Tx.under100(Nat.div(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n), 60n, Tx.minute_lt(Nat.mod(s, 86400n)), {==}))) : {Some{D.seconds_from(Nat.sub(D.days_from(y, 1n+mp, 1n+dp), 135140n), Nat.div(Nat.mod(s, 86400n), 3600n), _, D.read2(D.tens(Nat.mod(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n)), D.ones(Nat.mod(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n))))} == Some{s} : Maybe<&2, Nat>}
      %Equal.sym(Nat, D.read2(D.tens(Nat.mod(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n)), D.ones(Nat.mod(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n))), Nat.mod(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n), Tx.two_prod(Nat.mod(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n), Tx.under100(Nat.mod(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n), 60n, Tx.second_lt(Nat.mod(s, 86400n)), {==}))) : {Some{D.seconds_from(Nat.sub(D.days_from(y, 1n+mp, 1n+dp), 135140n), Nat.div(Nat.mod(s, 86400n), 3600n), Nat.div(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n), _)} == Some{s} : Maybe<&2, Nat>}
      %Equal.sym(Nat, D.days_from(y, 1n+mp, 1n+dp), Nat.add(Nat.div(s, 86400n), 135140n), hd) : {Some{D.seconds_from(Nat.sub(_, 135140n), Nat.div(Nat.mod(s, 86400n), 3600n), Nat.div(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n), Nat.mod(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n))} == Some{s} : Maybe<&2, Nat>}
      %Equal.sym(Nat, Nat.sub(Nat.add(Nat.div(s, 86400n), 135140n), 135140n), Nat.div(s, 86400n), days_sub(Nat.div(s, 86400n), 135140n)) : {Some{D.seconds_from(_, Nat.div(Nat.mod(s, 86400n), 3600n), Nat.div(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n), Nat.mod(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n))} == Some{s} : Maybe<&2, Nat>}
      %Equal.sym(Nat, Nat.add(Nat.mul(Nat.div(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n), 60n), Nat.mod(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n)), Nat.mod(Nat.mod(s, 86400n), 3600n), A.div_mod_id(Nat.mod(Nat.mod(s, 86400n), 3600n), 60n, {==})) : {Some{Nat.add(Nat.mul(Nat.div(s, 86400n), 86400n), Nat.add(Nat.mul(Nat.div(Nat.mod(s, 86400n), 3600n), 3600n), _))} == Some{s} : Maybe<&2, Nat>}
      %Equal.sym(Nat, Nat.add(Nat.mul(Nat.div(Nat.mod(s, 86400n), 3600n), 3600n), Nat.mod(Nat.mod(s, 86400n), 3600n)), Nat.mod(s, 86400n), A.div_mod_id(Nat.mod(s, 86400n), 3600n, {==})) : {Some{Nat.add(Nat.mul(Nat.div(s, 86400n), 86400n), _)} == Some{s} : Maybe<&2, Nat>}
      Equal.cong(Nat, Maybe<&2, Nat>, z => Some{z}, Nat.add(Nat.mul(Nat.div(s, 86400n), 86400n), Nat.mod(s, 86400n)), s, A.div_mod_id(s, 86400n, {==}))

law spec_dt:
  for +s: Nat
  for date: Nat & (Nat & Nat)
  for hdt: {S.civil(Nat.div(s, 86400n)) == date : Nat & (Nat & Nat)}
  for v: {Days.valid(date) == True{} : Bool}
  for hd: {Days.date_days(date) == Nat.add(Nat.div(s, 86400n), 135140n) : Nat}
  for +bound: {Nat.is_lt(Nat.div(Nat.sub(Nat.div(s, 86400n), 10957n), 146097n), 20n) == True{} : Bool}
  {S.denotes(D.render_date(Nat.mod(Nat.add(Nat.div(s, 86400n), 4n), 7n), date, Nat.mod(s, 86400n)), s) == True{} : Bool}

def spec_dt(s, date, hdt, v, hd, bound):
  match date:
    case (y, md):
      match md:
        case (m, d):
          spec_from(s, y, m, d, hdt, v, hd, bound)

law rt_dt:
  for +s: Nat
  for date: Nat & (Nat & Nat)
  for v: {Days.valid(date) == True{} : Bool}
  for hd: {Days.date_days(date) == Nat.add(Nat.div(s, 86400n), 135140n) : Nat}
  for +bound: {Nat.is_lt(Nat.div(Nat.sub(Nat.div(s, 86400n), 10957n), 146097n), 20n) == True{} : Bool}
  {D.read_imf(D.render_date(Nat.mod(Nat.add(Nat.div(s, 86400n), 4n), 7n), date, Nat.mod(s, 86400n))) == Some{s} : Maybe<&2, Nat>}

def rt_dt(s, date, v, hd, bound):
  match date:
    case (y, md):
      match md:
        case (m, d):
          rt_from(s, y, m, d, v, hd, bound)

# BND-80 law proofs.

law imf_spec:
  for +s: Nat
  for +bound: {Nat.is_lt(Nat.div(Nat.sub(Nat.div(s, 86400n), 10957n), 146097n), 20n) == True{} : Bool}
  {S.denotes(D.format_imf(s), s) == True{} : Bool}

def imf_spec(s, bound):
  Equal.trans(Bool, S.denotes(D.format_imf(s), s), S.denotes(D.render_date(Nat.mod(Nat.add(Nat.div(s, 86400n), 4n), 7n), S.civil(Nat.div(s, 86400n)), Nat.mod(s, 86400n)), s), True{}, Equal.cong(String, Bool, x => S.denotes(x, s), D.format_imf(s), D.render_date(Nat.mod(Nat.add(Nat.div(s, 86400n), 4n), 7n), S.civil(Nat.div(s, 86400n)), Nat.mod(s, 86400n)), fmt_eq(s, bound)), spec_dt(s, S.civil(Nat.div(s, 86400n)), {==}, Days.civil_valid(Nat.div(s, 86400n)), Days.days_civil(Nat.div(s, 86400n)), bound))

law roundtrip:
  for +s: Nat
  for +bound: {Nat.is_lt(Nat.div(Nat.sub(Nat.div(s, 86400n), 10957n), 146097n), 20n) == True{} : Bool}
  {D.parse_imf(D.format_imf(s)) == Some{s} : Maybe<&2, Nat>}

def roundtrip(s, bound):
  +e1 = Equal.cong(String, Maybe<&2, Nat>, x => D.parse_imf(x), D.format_imf(s), D.render_date(Nat.mod(Nat.add(Nat.div(s, 86400n), 4n), 7n), S.civil(Nat.div(s, 86400n)), Nat.mod(s, 86400n)), fmt_eq(s, bound))
  +e2 = Equal.trans(Maybe<&2, Nat>, D.parse_imf(D.render_date(Nat.mod(Nat.add(Nat.div(s, 86400n), 4n), 7n), S.civil(Nat.div(s, 86400n)), Nat.mod(s, 86400n))), D.canonical(D.read_imf(D.render_date(Nat.mod(Nat.add(Nat.div(s, 86400n), 4n), 7n), S.civil(Nat.div(s, 86400n)), Nat.mod(s, 86400n))), D.render_date(Nat.mod(Nat.add(Nat.div(s, 86400n), 4n), 7n), S.civil(Nat.div(s, 86400n)), Nat.mod(s, 86400n))), D.canonical(Some{s}, D.render_date(Nat.mod(Nat.add(Nat.div(s, 86400n), 4n), 7n), S.civil(Nat.div(s, 86400n)), Nat.mod(s, 86400n))), {==}, Equal.cong(Maybe<&2, Nat>, Maybe<&2, Nat>, x => D.canonical(x, D.render_date(Nat.mod(Nat.add(Nat.div(s, 86400n), 4n), 7n), S.civil(Nat.div(s, 86400n)), Nat.mod(s, 86400n))), D.read_imf(D.render_date(Nat.mod(Nat.add(Nat.div(s, 86400n), 4n), 7n), S.civil(Nat.div(s, 86400n)), Nat.mod(s, 86400n))), Some{s}, rt_dt(s, S.civil(Nat.div(s, 86400n)), Days.civil_valid(Nat.div(s, 86400n)), Days.days_civil(Nat.div(s, 86400n)), bound)))
  +e4 = Equal.cong(String, Maybe<&2, Nat>, x => D.parsed(s, String.eq(x, D.render_date(Nat.mod(Nat.add(Nat.div(s, 86400n), 4n), 7n), S.civil(Nat.div(s, 86400n)), Nat.mod(s, 86400n)))), D.format_imf(s), D.render_date(Nat.mod(Nat.add(Nat.div(s, 86400n), 4n), 7n), S.civil(Nat.div(s, 86400n)), Nat.mod(s, 86400n)), fmt_eq(s, bound))
  +e5 = Equal.cong(Bool, Maybe<&2, Nat>, b => D.parsed(s, b), String.eq(D.render_date(Nat.mod(Nat.add(Nat.div(s, 86400n), 4n), 7n), S.civil(Nat.div(s, 86400n)), Nat.mod(s, 86400n)), D.render_date(Nat.mod(Nat.add(Nat.div(s, 86400n), 4n), 7n), S.civil(Nat.div(s, 86400n)), Nat.mod(s, 86400n))), True{}, Eq.string_eq_refl(D.render_date(Nat.mod(Nat.add(Nat.div(s, 86400n), 4n), 7n), S.civil(Nat.div(s, 86400n)), Nat.mod(s, 86400n))))
  Equal.trans(Maybe<&2, Nat>, D.parse_imf(D.format_imf(s)), D.parse_imf(D.render_date(Nat.mod(Nat.add(Nat.div(s, 86400n), 4n), 7n), S.civil(Nat.div(s, 86400n)), Nat.mod(s, 86400n))), Some{s}, e1, Equal.trans(Maybe<&2, Nat>, D.parse_imf(D.render_date(Nat.mod(Nat.add(Nat.div(s, 86400n), 4n), 7n), S.civil(Nat.div(s, 86400n)), Nat.mod(s, 86400n))), D.canonical(Some{s}, D.render_date(Nat.mod(Nat.add(Nat.div(s, 86400n), 4n), 7n), S.civil(Nat.div(s, 86400n)), Nat.mod(s, 86400n))), Some{s}, e2, Equal.trans(Maybe<&2, Nat>, D.canonical(Some{s}, D.render_date(Nat.mod(Nat.add(Nat.div(s, 86400n), 4n), 7n), S.civil(Nat.div(s, 86400n)), Nat.mod(s, 86400n))), D.parsed(s, String.eq(D.format_imf(s), D.render_date(Nat.mod(Nat.add(Nat.div(s, 86400n), 4n), 7n), S.civil(Nat.div(s, 86400n)), Nat.mod(s, 86400n)))), Some{s}, {==}, Equal.trans(Maybe<&2, Nat>, D.parsed(s, String.eq(D.format_imf(s), D.render_date(Nat.mod(Nat.add(Nat.div(s, 86400n), 4n), 7n), S.civil(Nat.div(s, 86400n)), Nat.mod(s, 86400n)))), D.parsed(s, String.eq(D.render_date(Nat.mod(Nat.add(Nat.div(s, 86400n), 4n), 7n), S.civil(Nat.div(s, 86400n)), Nat.mod(s, 86400n)), D.render_date(Nat.mod(Nat.add(Nat.div(s, 86400n), 4n), 7n), S.civil(Nat.div(s, 86400n)), Nat.mod(s, 86400n)))), Some{s}, e4, Equal.trans(Maybe<&2, Nat>, D.parsed(s, String.eq(D.render_date(Nat.mod(Nat.add(Nat.div(s, 86400n), 4n), 7n), S.civil(Nat.div(s, 86400n)), Nat.mod(s, 86400n)), D.render_date(Nat.mod(Nat.add(Nat.div(s, 86400n), 4n), 7n), S.civil(Nat.div(s, 86400n)), Nat.mod(s, 86400n)))), D.parsed(s, True{}), Some{s}, e5, {==})))))

