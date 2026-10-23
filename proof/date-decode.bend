# Decoding inverts encoding for every valid spec date.
import Base
import ../src/http/date.bend as D
import ./date-spec.bend as S
import ./date-arith.bend as A
import ./date-walk.bend as W
import ./date-calendar.bend as C
import ./date-days.bend as Days

# Period totals.

def months_total(g: Bool) -> {W.total(D.month_lengths(g)) == W.nth(0n, D.year_lengths(g)) : Nat}:
  match g:
    case True{}:
      {==}
    case False{}:
      {==}

law year_total:
  for +c: Nat
  for +q: Nat
  for +yq: Nat
  for ly: {Nat.is_lt(yq, 4n) == True{} : Bool}
  {W.total(D.month_lengths(D.leap(c, q, yq))) == W.nth(yq, D.year_lengths(D.long_group(c, q))) : Nat}

def year_total(c, q, yq, ly):
  match yq:
    case 0n:
      months_total(D.long_group(c, q))
    case 1n:
      {==}
    case 2n:
      {==}
    case 3n:
      {==}
    case 4n+p:
      C.lt_absurd_add({W.total(D.month_lengths(D.leap(c, q, 4n+p))) == W.nth(4n+p, D.year_lengths(D.long_group(c, q))) : Nat}, 4n, p, ly)

def years_total(b: Bool) -> {W.total(D.year_lengths(b)) == D.first_group(b) : Nat}:
  match b:
    case True{}:
      {==}
    case False{}:
      {==}

law group_total:
  for +c: Nat
  for +q: Nat
  for lq: {Nat.is_lt(q, 25n) == True{} : Bool}
  {W.total(D.year_lengths(D.long_group(c, q))) == W.nth(q, D.group_lengths(D.is_zero(c))) : Nat}

def group_total(c, q, lq):
  match q:
    case 0n:
      years_total(D.is_zero(c))
    case 1n+qp:
      Equal.sym(Nat, W.nth(qp, D.rep(24n, 1461n)), 1461n, W.nth_rep(qp, 24n, 1461n, lq))

law century_total:
  for +c: Nat
  for lc: {Nat.is_lt(c, 4n) == True{} : Bool}
  {W.total(D.group_lengths(D.is_zero(c))) == W.nth(c, D.century_lengths()) : Nat}

def century_total(c, lc):
  match c:
    case 0n:
      A.eq_of_is_eq(W.total(D.group_lengths(D.is_zero(0n))), W.nth(0n, D.century_lengths()), {==})
    case 1n:
      A.eq_of_is_eq(W.total(D.group_lengths(D.is_zero(1n))), W.nth(1n, D.century_lengths()), {==})
    case 2n:
      A.eq_of_is_eq(W.total(D.group_lengths(D.is_zero(2n))), W.nth(2n, D.century_lengths()), {==})
    case 3n:
      A.eq_of_is_eq(W.total(D.group_lengths(D.is_zero(3n))), W.nth(3n, D.century_lengths()), {==})
    case 4n+p:
      C.lt_absurd_add({W.total(D.group_lengths(D.is_zero(4n+p))) == W.nth(4n+p, D.century_lengths()) : Nat}, 4n, p, lc)

law cycle_total:
  {W.total(D.century_lengths()) == 146097n : Nat}

def cycle_total():
  A.eq_of_is_eq(W.total(D.century_lengths()), 146097n, {==})

# x < total and total = t give x < t.
def lt_total(+x: Nat, +tot: Nat, +t: Nat, lt: {Nat.is_lt(x, tot) == True{} : Bool}, e: {tot == t : Nat}) -> {Nat.is_lt(x, t) == True{} : Bool}:
  %e : {Nat.is_lt(x, _) == True{} : Bool}
  lt

# One decoding layer at a time.

law dec_month:
  for +e: Nat
  for +c: Nat
  for +q: Nat
  for +yq: Nat
  for +m: Nat
  for +r: Nat
  for +lm: {Nat.is_lt(m, 12n) == True{} : Bool}
  for +lr: {Nat.is_lt(r, W.nth(m, D.month_lengths(D.leap(c, q, yq)))) == True{} : Bool}
  {D.civil_month(e, c, q, yq, D.before(m, D.month_lengths(D.leap(c, q, yq)), r)) == D.date_of(e, c, q, yq, m, r) : Nat & (Nat & Nat)}

def dec_month(e, c, q, yq, m, r, lm, lr):
  +ml = D.month_lengths(D.leap(c, q, yq))
  %Equal.sym(Nat, D.index(ml, D.before(m, ml, r)), m, W.index_before(m, ml, r, lm, lr)) : {D.date_of(e, c, q, yq, _, D.offset(ml, D.before(m, ml, r))) == D.date_of(e, c, q, yq, m, r) : Nat & (Nat & Nat)}
  %Equal.sym(Nat, D.offset(ml, D.before(m, ml, r)), r, W.offset_before(m, ml, r, lm, lr)) : {D.date_of(e, c, q, yq, m, _) == D.date_of(e, c, q, yq, m, r) : Nat & (Nat & Nat)}
  {==}

law dec_year:
  for +e: Nat
  for +c: Nat
  for +q: Nat
  for +yq: Nat
  for +x: Nat
  for +ly: {Nat.is_lt(yq, 4n) == True{} : Bool}
  for +lx: {Nat.is_lt(x, W.nth(yq, D.year_lengths(D.long_group(c, q)))) == True{} : Bool}
  {D.civil_year(e, c, q, D.before(yq, D.year_lengths(D.long_group(c, q)), x)) == D.civil_month(e, c, q, yq, x) : Nat & (Nat & Nat)}

def dec_year(e, c, q, yq, x, ly, lx):
  +yl = D.year_lengths(D.long_group(c, q))
  %Equal.sym(Nat, D.index(yl, D.before(yq, yl, x)), yq, W.index_before(yq, yl, x, ly, lx)) : {D.civil_month(e, c, q, _, D.offset(yl, D.before(yq, yl, x))) == D.civil_month(e, c, q, yq, x) : Nat & (Nat & Nat)}
  %Equal.sym(Nat, D.offset(yl, D.before(yq, yl, x)), x, W.offset_before(yq, yl, x, ly, lx)) : {D.civil_month(e, c, q, yq, _) == D.civil_month(e, c, q, yq, x) : Nat & (Nat & Nat)}
  {==}

law dec_group:
  for +e: Nat
  for +c: Nat
  for +q: Nat
  for +x: Nat
  for +lq: {Nat.is_lt(q, 25n) == True{} : Bool}
  for +lx: {Nat.is_lt(x, W.nth(q, D.group_lengths(D.is_zero(c)))) == True{} : Bool}
  {D.civil_group(e, c, D.before(q, D.group_lengths(D.is_zero(c)), x)) == D.civil_year(e, c, q, x) : Nat & (Nat & Nat)}

def dec_group(e, c, q, x, lq, lx):
  +gl = D.group_lengths(D.is_zero(c))
  %Equal.sym(Nat, D.index(gl, D.before(q, gl, x)), q, W.index_before(q, gl, x, lq, lx)) : {D.civil_year(e, c, _, D.offset(gl, D.before(q, gl, x))) == D.civil_year(e, c, q, x) : Nat & (Nat & Nat)}
  %Equal.sym(Nat, D.offset(gl, D.before(q, gl, x)), x, W.offset_before(q, gl, x, lq, lx)) : {D.civil_year(e, c, q, _) == D.civil_year(e, c, q, x) : Nat & (Nat & Nat)}
  {==}

law dec_century:
  for +e: Nat
  for +c: Nat
  for +x: Nat
  for +lc: {Nat.is_lt(c, 4n) == True{} : Bool}
  for +lx: {Nat.is_lt(x, W.nth(c, D.century_lengths())) == True{} : Bool}
  {D.civil_century(e, D.before(c, D.century_lengths(), x)) == D.civil_group(e, c, x) : Nat & (Nat & Nat)}

def dec_century(e, c, x, lc, lx):
  +cl = D.century_lengths()
  %Equal.sym(Nat, D.index(cl, D.before(c, cl, x)), c, W.index_before(c, cl, x, lc, lx)) : {D.civil_group(e, _, D.offset(cl, D.before(c, cl, x))) == D.civil_group(e, c, x) : Nat & (Nat & Nat)}
  %Equal.sym(Nat, D.offset(cl, D.before(c, cl, x)), x, W.offset_before(c, cl, x, lc, lx)) : {D.civil_group(e, c, _) == D.civil_group(e, c, x) : Nat & (Nat & Nat)}
  {==}

law dec_cycle:
  for +e: Nat
  for +x: Nat
  for +lx: {Nat.is_lt(x, 146097n) == True{} : Bool}
  {D.civil(Nat.add(Nat.mul(e, 146097n), x)) == D.civil_century(e, x) : Nat & (Nat & Nat)}

def dec_cycle(e, x, lx):
  %Equal.sym(Nat, Nat.div(Nat.add(Nat.mul(e, 146097n), x), 146097n), e, A.div_unique(e, x, 146097n, lx)) : {D.civil_century(_, Nat.mod(Nat.add(Nat.mul(e, 146097n), x), 146097n)) == D.civil_century(e, x) : Nat & (Nat & Nat)}
  %Equal.sym(Nat, Nat.mod(Nat.add(Nat.mul(e, 146097n), x), 146097n), x, A.mod_unique(e, x, 146097n, lx)) : {D.civil_century(e, _) == D.civil_century(e, x) : Nat & (Nat & Nat)}
  {==}

# The days into each period stay below its length.

law bound4:
  for +c: Nat
  for +q: Nat
  for +yq: Nat
  for +m: Nat
  for +r: Nat
  for +lc: {Nat.is_lt(c, 4n) == True{} : Bool}
  for +lq: {Nat.is_lt(q, 25n) == True{} : Bool}
  for +ly: {Nat.is_lt(yq, 4n) == True{} : Bool}
  for +lm: {Nat.is_lt(m, 12n) == True{} : Bool}
  for +lr: {Nat.is_lt(r, W.nth(m, D.month_lengths(D.leap(c, q, yq)))) == True{} : Bool}
  {Nat.is_lt(D.before(m, D.month_lengths(D.leap(c, q, yq)), r), W.nth(yq, D.year_lengths(D.long_group(c, q)))) == True{} : Bool}

def bound4(c, q, yq, m, r, lc, lq, ly, lm, lr):
  lt_total(D.before(m, D.month_lengths(D.leap(c, q, yq)), r), W.total(D.month_lengths(D.leap(c, q, yq))), W.nth(yq, D.year_lengths(D.long_group(c, q))), W.before_lt(m, D.month_lengths(D.leap(c, q, yq)), r, lm, lr), year_total(c, q, yq, ly))

law bound3:
  for +c: Nat
  for +q: Nat
  for +yq: Nat
  for +m: Nat
  for +r: Nat
  for +lc: {Nat.is_lt(c, 4n) == True{} : Bool}
  for +lq: {Nat.is_lt(q, 25n) == True{} : Bool}
  for +ly: {Nat.is_lt(yq, 4n) == True{} : Bool}
  for +lm: {Nat.is_lt(m, 12n) == True{} : Bool}
  for +lr: {Nat.is_lt(r, W.nth(m, D.month_lengths(D.leap(c, q, yq)))) == True{} : Bool}
  {Nat.is_lt(D.before(yq, D.year_lengths(D.long_group(c, q)), D.before(m, D.month_lengths(D.leap(c, q, yq)), r)), W.nth(q, D.group_lengths(D.is_zero(c)))) == True{} : Bool}

def bound3(c, q, yq, m, r, lc, lq, ly, lm, lr):
  lt_total(D.before(yq, D.year_lengths(D.long_group(c, q)), D.before(m, D.month_lengths(D.leap(c, q, yq)), r)), W.total(D.year_lengths(D.long_group(c, q))), W.nth(q, D.group_lengths(D.is_zero(c))), W.before_lt(yq, D.year_lengths(D.long_group(c, q)), D.before(m, D.month_lengths(D.leap(c, q, yq)), r), ly, bound4(c, q, yq, m, r, lc, lq, ly, lm, lr)), group_total(c, q, lq))

law bound2:
  for +c: Nat
  for +q: Nat
  for +yq: Nat
  for +m: Nat
  for +r: Nat
  for +lc: {Nat.is_lt(c, 4n) == True{} : Bool}
  for +lq: {Nat.is_lt(q, 25n) == True{} : Bool}
  for +ly: {Nat.is_lt(yq, 4n) == True{} : Bool}
  for +lm: {Nat.is_lt(m, 12n) == True{} : Bool}
  for +lr: {Nat.is_lt(r, W.nth(m, D.month_lengths(D.leap(c, q, yq)))) == True{} : Bool}
  {Nat.is_lt(D.before(q, D.group_lengths(D.is_zero(c)), D.before(yq, D.year_lengths(D.long_group(c, q)), D.before(m, D.month_lengths(D.leap(c, q, yq)), r))), W.nth(c, D.century_lengths())) == True{} : Bool}

def bound2(c, q, yq, m, r, lc, lq, ly, lm, lr):
  lt_total(D.before(q, D.group_lengths(D.is_zero(c)), D.before(yq, D.year_lengths(D.long_group(c, q)), D.before(m, D.month_lengths(D.leap(c, q, yq)), r))), W.total(D.group_lengths(D.is_zero(c))), W.nth(c, D.century_lengths()), W.before_lt(q, D.group_lengths(D.is_zero(c)), D.before(yq, D.year_lengths(D.long_group(c, q)), D.before(m, D.month_lengths(D.leap(c, q, yq)), r)), lq, bound3(c, q, yq, m, r, lc, lq, ly, lm, lr)), century_total(c, lc))

law bound1:
  for +c: Nat
  for +q: Nat
  for +yq: Nat
  for +m: Nat
  for +r: Nat
  for +lc: {Nat.is_lt(c, 4n) == True{} : Bool}
  for +lq: {Nat.is_lt(q, 25n) == True{} : Bool}
  for +ly: {Nat.is_lt(yq, 4n) == True{} : Bool}
  for +lm: {Nat.is_lt(m, 12n) == True{} : Bool}
  for +lr: {Nat.is_lt(r, W.nth(m, D.month_lengths(D.leap(c, q, yq)))) == True{} : Bool}
  {Nat.is_lt(D.before(c, D.century_lengths(), D.before(q, D.group_lengths(D.is_zero(c)), D.before(yq, D.year_lengths(D.long_group(c, q)), D.before(m, D.month_lengths(D.leap(c, q, yq)), r)))), 146097n) == True{} : Bool}

def bound1(c, q, yq, m, r, lc, lq, ly, lm, lr):
  lt_total(D.before(c, D.century_lengths(), D.before(q, D.group_lengths(D.is_zero(c)), D.before(yq, D.year_lengths(D.long_group(c, q)), D.before(m, D.month_lengths(D.leap(c, q, yq)), r)))), W.total(D.century_lengths()), 146097n, W.before_lt(c, D.century_lengths(), D.before(q, D.group_lengths(D.is_zero(c)), D.before(yq, D.year_lengths(D.long_group(c, q)), D.before(m, D.month_lengths(D.leap(c, q, yq)), r))), lc, bound2(c, q, yq, m, r, lc, lq, ly, lm, lr)), cycle_total())

law decode_add:
  for +e: Nat
  for +c: Nat
  for +q: Nat
  for +yq: Nat
  for +m: Nat
  for +r: Nat
  for +lc: {Nat.is_lt(c, 4n) == True{} : Bool}
  for +lq: {Nat.is_lt(q, 25n) == True{} : Bool}
  for +ly: {Nat.is_lt(yq, 4n) == True{} : Bool}
  for +lm: {Nat.is_lt(m, 12n) == True{} : Bool}
  for +lr: {Nat.is_lt(r, W.nth(m, D.month_lengths(D.leap(c, q, yq)))) == True{} : Bool}
  {D.civil(Nat.add(Nat.mul(e, 146097n), D.before(c, D.century_lengths(), D.before(q, D.group_lengths(D.is_zero(c)), D.before(yq, D.year_lengths(D.long_group(c, q)), D.before(m, D.month_lengths(D.leap(c, q, yq)), r)))))) == D.date_of(e, c, q, yq, m, r) : Nat & (Nat & Nat)}

def decode_add(e, c, q, yq, m, r, lc, lq, ly, lm, lr):
  Equal.trans(Nat & (Nat & Nat), D.civil(Nat.add(Nat.mul(e, 146097n), D.before(c, D.century_lengths(), D.before(q, D.group_lengths(D.is_zero(c)), D.before(yq, D.year_lengths(D.long_group(c, q)), D.before(m, D.month_lengths(D.leap(c, q, yq)), r)))))), D.civil_century(e, D.before(c, D.century_lengths(), D.before(q, D.group_lengths(D.is_zero(c)), D.before(yq, D.year_lengths(D.long_group(c, q)), D.before(m, D.month_lengths(D.leap(c, q, yq)), r))))), D.date_of(e, c, q, yq, m, r), dec_cycle(e, D.before(c, D.century_lengths(), D.before(q, D.group_lengths(D.is_zero(c)), D.before(yq, D.year_lengths(D.long_group(c, q)), D.before(m, D.month_lengths(D.leap(c, q, yq)), r)))), bound1(c, q, yq, m, r, lc, lq, ly, lm, lr)), Equal.trans(Nat & (Nat & Nat), D.civil_century(e, D.before(c, D.century_lengths(), D.before(q, D.group_lengths(D.is_zero(c)), D.before(yq, D.year_lengths(D.long_group(c, q)), D.before(m, D.month_lengths(D.leap(c, q, yq)), r))))), D.civil_group(e, c, D.before(q, D.group_lengths(D.is_zero(c)), D.before(yq, D.year_lengths(D.long_group(c, q)), D.before(m, D.month_lengths(D.leap(c, q, yq)), r)))), D.date_of(e, c, q, yq, m, r), dec_century(e, c, D.before(q, D.group_lengths(D.is_zero(c)), D.before(yq, D.year_lengths(D.long_group(c, q)), D.before(m, D.month_lengths(D.leap(c, q, yq)), r))), lc, bound2(c, q, yq, m, r, lc, lq, ly, lm, lr)), Equal.trans(Nat & (Nat & Nat), D.civil_group(e, c, D.before(q, D.group_lengths(D.is_zero(c)), D.before(yq, D.year_lengths(D.long_group(c, q)), D.before(m, D.month_lengths(D.leap(c, q, yq)), r)))), D.civil_year(e, c, q, D.before(yq, D.year_lengths(D.long_group(c, q)), D.before(m, D.month_lengths(D.leap(c, q, yq)), r))), D.date_of(e, c, q, yq, m, r), dec_group(e, c, q, D.before(yq, D.year_lengths(D.long_group(c, q)), D.before(m, D.month_lengths(D.leap(c, q, yq)), r)), lq, bound3(c, q, yq, m, r, lc, lq, ly, lm, lr)), Equal.trans(Nat & (Nat & Nat), D.civil_year(e, c, q, D.before(yq, D.year_lengths(D.long_group(c, q)), D.before(m, D.month_lengths(D.leap(c, q, yq)), r))), D.civil_month(e, c, q, yq, D.before(m, D.month_lengths(D.leap(c, q, yq)), r)), D.date_of(e, c, q, yq, m, r), dec_year(e, c, q, yq, D.before(m, D.month_lengths(D.leap(c, q, yq)), r), ly, bound4(c, q, yq, m, r, lc, lq, ly, lm, lr)), dec_month(e, c, q, yq, m, r, lm, lr)))))

law decode_of:
  for +e: Nat
  for +c: Nat
  for +q: Nat
  for +yq: Nat
  for +m: Nat
  for +r: Nat
  for +lc: {Nat.is_lt(c, 4n) == True{} : Bool}
  for +lq: {Nat.is_lt(q, 25n) == True{} : Bool}
  for +ly: {Nat.is_lt(yq, 4n) == True{} : Bool}
  for +lm: {Nat.is_lt(m, 12n) == True{} : Bool}
  for +lr: {Nat.is_lt(r, W.nth(m, D.month_lengths(D.leap(c, q, yq)))) == True{} : Bool}
  {D.civil(D.days_of(e, c, q, yq, m, r)) == D.date_of(e, c, q, yq, m, r) : Nat & (Nat & Nat)}

def decode_of(e, c, q, yq, m, r, lc, lq, ly, lm, lr):
  Equal.trans(Nat & (Nat & Nat), D.civil(D.days_of(e, c, q, yq, m, r)), D.civil(Nat.add(Nat.mul(e, 146097n), D.before(c, D.century_lengths(), D.before(q, D.group_lengths(D.is_zero(c)), D.before(yq, D.year_lengths(D.long_group(c, q)), D.before(m, D.month_lengths(D.leap(c, q, yq)), r)))))), D.date_of(e, c, q, yq, m, r), Equal.cong(Nat, Nat & (Nat & Nat), z => D.civil(z), D.days_of(e, c, q, yq, m, r), Nat.add(Nat.mul(e, 146097n), D.before(c, D.century_lengths(), D.before(q, D.group_lengths(D.is_zero(c)), D.before(yq, D.year_lengths(D.long_group(c, q)), D.before(m, D.month_lengths(D.leap(c, q, yq)), r))))), {==}), decode_add(e, c, q, yq, m, r, lc, lq, ly, lm, lr))

law year_back:
  for +y: Nat
  for ge: {Nat.is_le(1600n, y) == True{} : Bool}
  {Nat.add(1600n, Nat.add(Nat.mul(C.ye(y), 400n), Nat.add(Nat.mul(C.yc(y), 100n), Nat.add(Nat.mul(C.yq(y), 4n), C.yy(y))))) == y : Nat}

def year_back(y, ge):
  %Equal.sym(Nat, Nat.add(Nat.mul(C.yq(y), 4n), C.yy(y)), C.ya2(y), A.div_mod_id(C.ya2(y), 4n, {==})) : {Nat.add(1600n, Nat.add(Nat.mul(C.ye(y), 400n), Nat.add(Nat.mul(C.yc(y), 100n), _))) == y : Nat}
  %Equal.sym(Nat, Nat.add(Nat.mul(C.yc(y), 100n), C.ya2(y)), C.ya1(y), A.div_mod_id(C.ya1(y), 100n, {==})) : {Nat.add(1600n, Nat.add(Nat.mul(C.ye(y), 400n), _)) == y : Nat}
  %Equal.sym(Nat, Nat.add(Nat.mul(C.ye(y), 400n), C.ya1(y)), C.ya(y), A.div_mod_id(C.ya(y), 400n, {==})) : {Nat.add(1600n, _) == y : Nat}
  A.add_sub_le(1600n, y, ge)

def year_lc(+y: Nat) -> {Nat.is_lt(C.yc(y), 4n) == True{} : Bool}:
  A.div_lt_of_lt_mul(C.ya1(y), 4n, 100n, {==}, A.mod_lt(C.ya(y), 400n, {==}))

def year_lq(+y: Nat) -> {Nat.is_lt(C.yq(y), 25n) == True{} : Bool}:
  A.div_lt_of_lt_mul(C.ya2(y), 25n, 4n, {==}, A.mod_lt(C.ya1(y), 100n, {==}))

def year_ly(+y: Nat) -> {Nat.is_lt(C.yy(y), 4n) == True{} : Bool}:
  A.mod_lt(C.ya2(y), 4n, {==})

def day_lr(+y: Nat, +mp: Nat, +dp: Nat, +ge: {Nat.is_le(1600n, y) == True{} : Bool}, +lm: {Nat.is_lt(mp, 12n) == True{} : Bool}, +ld: {Nat.is_le(1n+dp, S.month_days(y, 1n+mp)) == True{} : Bool}) -> {Nat.is_lt(dp, W.nth(mp, D.month_lengths(D.leap(C.yc(y), C.yq(y), C.yy(y))))) == True{} : Bool}:
  lt_total(dp, S.month_days(y, 1n+mp), W.nth(mp, D.month_lengths(D.leap(C.yc(y), C.yq(y), C.yy(y)))), A.lt_of_succ_le(dp, S.month_days(y, 1n+mp), ld), C.month_table(y, mp, D.leap(C.yc(y), C.yq(y), C.yy(y)), C.leap_agrees(y, ge), lm))

def days_split(+y: Nat, +mp: Nat, +dp: Nat) -> {D.days_from(y, 1n+mp, 1n+dp) == D.days_of(C.ye(y), C.yc(y), C.yq(y), C.yy(y), mp, dp) : Nat}:
  %Equal.sym(Nat, Nat.sub(mp, 0n), mp, A.sub_zero_r(mp)) : {D.days_century(Nat.div(Nat.sub(y, 1600n), 400n), Nat.mod(Nat.sub(y, 1600n), 400n), _, Nat.sub(dp, 0n)) == D.days_of(C.ye(y), C.yc(y), C.yq(y), C.yy(y), mp, dp) : Nat}
  %Equal.sym(Nat, Nat.sub(dp, 0n), dp, A.sub_zero_r(dp)) : {D.days_century(Nat.div(Nat.sub(y, 1600n), 400n), Nat.mod(Nat.sub(y, 1600n), 400n), mp, _) == D.days_of(C.ye(y), C.yc(y), C.yq(y), C.yy(y), mp, dp) : Nat}
  {==}

law decode_date:
  for +y: Nat
  for +mp: Nat
  for +dp: Nat
  for +ge: {Nat.is_le(1600n, y) == True{} : Bool}
  for +lm: {Nat.is_lt(mp, 12n) == True{} : Bool}
  for +ld: {Nat.is_le(1n+dp, S.month_days(y, 1n+mp)) == True{} : Bool}
  {D.civil(D.days_from(y, 1n+mp, 1n+dp)) == (y, (1n+mp, 1n+dp)) : Nat & (Nat & Nat)}

def decode_date(y, mp, dp, ge, lm, ld):
  Equal.trans(Nat & (Nat & Nat), D.civil(D.days_from(y, 1n+mp, 1n+dp)), D.civil(D.days_of(C.ye(y), C.yc(y), C.yq(y), C.yy(y), mp, dp)), (y, (1n+mp, 1n+dp)), Equal.cong(Nat, Nat & (Nat & Nat), z => D.civil(z), D.days_from(y, 1n+mp, 1n+dp), D.days_of(C.ye(y), C.yc(y), C.yq(y), C.yy(y), mp, dp), days_split(y, mp, dp)), Equal.trans(Nat & (Nat & Nat), D.civil(D.days_of(C.ye(y), C.yc(y), C.yq(y), C.yy(y), mp, dp)), D.date_of(C.ye(y), C.yc(y), C.yq(y), C.yy(y), mp, dp), (y, (1n+mp, 1n+dp)), decode_of(C.ye(y), C.yc(y), C.yq(y), C.yy(y), mp, dp, year_lc(y), year_lq(y), year_ly(y), lm, day_lr(y, mp, dp, ge, lm, ld)), Equal.cong(Nat, Nat & (Nat & Nat), x => (x, (1n+mp, 1n+dp)), Nat.add(1600n, Nat.add(Nat.mul(C.ye(y), 400n), Nat.add(Nat.mul(C.yc(y), 100n), Nat.add(Nat.mul(C.yq(y), 4n), C.yy(y))))), y, year_back(y, ge))))

def decode_from(+y: Nat, +m: Nat, +d: Nat, +v: {Days.valid3(y, m, d) == True{} : Bool}) -> {D.civil(Days.date_days((y, (m, d)))) == (y, (m, d)) : Nat & (Nat & Nat)}:
  match m d:
    case 0n d:
      A.absurd({D.civil(Days.date_days((y, (0n, d)))) == (y, (0n, d)) : Nat & (Nat & Nat)}, A.false_true(Days.valid_mon1(y, 0n, d, v)))
    case 1n+mp 0n:
      A.absurd({D.civil(Days.date_days((y, (1n+mp, 0n)))) == (y, (1n+mp, 0n)) : Nat & (Nat & Nat)}, A.false_true(Days.valid_day1(y, 1n+mp, 0n, v)))
    case 1n+mp 1n+dp:
      Equal.trans(Nat & (Nat & Nat), D.civil(Days.date_days((y, (1n+mp, 1n+dp)))), D.civil(D.days_from(y, 1n+mp, 1n+dp)), (y, (1n+mp, 1n+dp)), Equal.cong(Nat, Nat & (Nat & Nat), z => D.civil(z), Days.date_days((y, (1n+mp, 1n+dp))), D.days_from(y, 1n+mp, 1n+dp), {==}), decode_date(y, mp, dp, A.le_trans(1600n, 1970n, y, {==}, Days.valid_year(y, 1n+mp, 1n+dp, v)), A.lt_of_succ_le(mp, 12n, Days.valid_mon12(y, 1n+mp, 1n+dp, v)), Days.valid_dayn(y, 1n+mp, 1n+dp, v)))

law decode_valid:
  for date: Nat & (Nat & Nat)
  for v: {Days.valid(date) == True{} : Bool}
  {D.civil(Days.date_days(date)) == date : Nat & (Nat & Nat)}

def decode_valid(date, v):
  match date:
    case (y, md):
      match md:
        case (m, d):
          decode_from(y, m, d, v)

# The production calendar of Unix day n is the spec's.
law civil_day:
  for +n: Nat
  {D.civil(Nat.add(n, 135140n)) == S.civil(n) : Nat & (Nat & Nat)}

def civil_day(n):
  Equal.trans(Nat & (Nat & Nat), D.civil(Nat.add(n, 135140n)), D.civil(Days.date_days(S.civil(n))), S.civil(n), Equal.cong(Nat, Nat & (Nat & Nat), z => D.civil(z), Nat.add(n, 135140n), Days.date_days(S.civil(n)), Equal.sym(Nat, Days.date_days(S.civil(n)), Nat.add(n, 135140n), Days.days_civil(n))), decode_valid(S.civil(n), Days.civil_valid(n)))
