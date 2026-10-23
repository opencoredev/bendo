# The formatter's weekday, digits and time fields match the spec's.
import Base
import ../src/http/date.bend as D
import ./date-spec.bend as S
import ./date-arith.bend as A

def A_pred(n: Nat) -> Nat:
  match n:
    case 0n:
      0n
    case 1n+p:
      p

def next_weekday_succ(+m: Nat, h: {Nat.is_lt(1n+m, 7n) == True{} : Bool}) -> {S.next_weekday(m) == 1n+m : Nat}:
  match m:
    case 0n:
      {==}
    case 1n:
      {==}
    case 2n:
      {==}
    case 3n:
      {==}
    case 4n:
      {==}
    case 5n:
      {==}
    case 6n+p:
      A.absurd({S.next_weekday(6n+p) == 7n+p : Nat}, A.false_true(Equal.trans(Bool, False{}, Nat.is_lt(Nat.add(7n, p), 7n), True{}, Equal.sym(Bool, Nat.is_lt(Nat.add(7n, p), 7n), False{}, A.not_lt_add(7n, p)), h)))

def weekday_case(+a: Nat, r: Bool, +hr: {Nat.is_lt(1n+Nat.mod(a, 7n), 7n) == r : Bool}) -> {Nat.mod(1n+a, 7n) == S.next_weekday(Nat.mod(a, 7n)) : Nat}:
  match r:
    case True{}:
      %Equal.sym(Nat & Nat, Nat.divmod(1n+a, 7n), (Nat.div(a, 7n), 1n+Nat.mod(a, 7n)), A.div_succ_in(a, 7n, {==}, hr)) : {Pair.snd(Nat, Nat, _) == S.next_weekday(Nat.mod(a, 7n)) : Nat}
      Equal.sym(Nat, S.next_weekday(Nat.mod(a, 7n)), 1n+Nat.mod(a, 7n), next_weekday_succ(Nat.mod(a, 7n), hr))
    case False{}:
      %Equal.sym(Nat & Nat, Nat.divmod(1n+a, 7n), (1n+Nat.div(a, 7n), 0n), A.div_succ_wrap(a, 7n, {==}, hr)) : {Pair.snd(Nat, Nat, _) == S.next_weekday(Nat.mod(a, 7n)) : Nat}
      +six = Equal.cong(Nat, Nat, x => A_pred(x), 1n+Nat.mod(a, 7n), 7n, A.succ_eq_of_lt(Nat.mod(a, 7n), 7n, A.mod_lt(a, 7n, {==}), hr))
      %Equal.sym(Nat, Nat.mod(a, 7n), 6n, six) : {0n == S.next_weekday(_) : Nat}
      {==}

law weekday_eq:
  for +n: Nat
  {Nat.mod(Nat.add(n, 4n), 7n) == S.weekday(n) : Nat}

def weekday_eq(n):
  match n:
    case 0n:
      {==}
    case 1n+p:
      Equal.trans(Nat, Nat.mod(1n+Nat.add(p, 4n), 7n), S.next_weekday(Nat.mod(Nat.add(p, 4n), 7n)), S.next_weekday(S.weekday(p)), weekday_case(Nat.add(p, 4n), Nat.is_lt(1n+Nat.mod(Nat.add(p, 4n), 7n), 7n), {==}), Equal.cong(Nat, Nat, x => S.next_weekday(x), Nat.mod(Nat.add(p, 4n), 7n), S.weekday(p), weekday_eq(p)))

law digit_decimal:
  for +k: Nat
  for lt: {Nat.is_lt(k, 10n) == True{} : Bool}
  {S.decimal(D.digit(k)) == True{} : Bool}

def digit_decimal(k, lt):
  match k:
    case 0n:
      {==}
    case 1n:
      {==}
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
    case 10n+p:
      A.absurd({S.decimal(D.digit(10n+p)) == True{} : Bool}, A.false_true(Equal.trans(Bool, False{}, Nat.is_lt(Nat.add(10n, p), 10n), True{}, Equal.sym(Bool, Nat.is_lt(Nat.add(10n, p), 10n), False{}, A.not_lt_add(10n, p)), lt)))

law digit_value_spec:
  for +k: Nat
  for lt: {Nat.is_lt(k, 10n) == True{} : Bool}
  {S.value(D.digit(k)) == k : Nat}

def digit_value_spec(k, lt):
  match k:
    case 0n:
      {==}
    case 1n:
      {==}
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
    case 10n+p:
      A.absurd({S.value(D.digit(10n+p)) == 10n+p : Nat}, A.false_true(Equal.trans(Bool, False{}, Nat.is_lt(Nat.add(10n, p), 10n), True{}, Equal.sym(Bool, Nat.is_lt(Nat.add(10n, p), 10n), False{}, A.not_lt_add(10n, p)), lt)))

law digit_value_prod:
  for +k: Nat
  for lt: {Nat.is_lt(k, 10n) == True{} : Bool}
  {D.digit_value(D.digit(k)) == k : Nat}

def digit_value_prod(k, lt):
  match k:
    case 0n:
      {==}
    case 1n:
      {==}
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
    case 10n+p:
      A.absurd({D.digit_value(D.digit(10n+p)) == 10n+p : Nat}, A.false_true(Equal.trans(Bool, False{}, Nat.is_lt(Nat.add(10n, p), 10n), True{}, Equal.sym(Bool, Nat.is_lt(Nat.add(10n, p), 10n), False{}, A.not_lt_add(10n, p)), lt)))

law and_true:
  for +a: Bool
  for +b: Bool
  for ha: {a == True{} : Bool}
  for hb: {b == True{} : Bool}
  {Bool.and(a, b) == True{} : Bool}

def and_true(a, b, ha, hb):
  %Equal.sym(Bool, a, True{}, ha) : {Bool.and(_, b) == True{} : Bool}
  hb

law eq_refl:
  for +a: Nat
  {Nat.is_eq(a, a) == True{} : Bool}

def eq_refl(a):
  match a:
    case 0n:
      {==}
    case 1n+p:
      eq_refl(p)

def lt_to(+x: Nat, +a: Nat, +b: Nat, lt: {Nat.is_lt(x, a) == True{} : Bool}, e: {a == b : Nat}) -> {Nat.is_lt(x, b) == True{} : Bool}:
  %e : {Nat.is_lt(x, _) == True{} : Bool}
  lt

# Two decimal digits.

law two_hi:
  for +x: Nat
  for h: {Nat.is_lt(x, 100n) == True{} : Bool}
  {Nat.is_lt(Nat.div(x, 10n), 10n) == True{} : Bool}

def two_hi(x, h):
  A.div_lt_of_lt_mul(x, 10n, 10n, {==}, h)

law two_ok:
  for +x: Nat
  for h: {Nat.is_lt(x, 100n) == True{} : Bool}
  {S.two_digits(D.tens(x), D.ones(x)) == True{} : Bool}

def two_ok(x, h):
  and_true(S.decimal(D.tens(x)), S.decimal(D.ones(x)), digit_decimal(Nat.div(x, 10n), two_hi(x, h)), digit_decimal(Nat.mod(x, 10n), A.mod_lt(x, 10n, {==})))

law two_spec:
  for +x: Nat
  for h: {Nat.is_lt(x, 100n) == True{} : Bool}
  {S.number2(D.tens(x), D.ones(x)) == x : Nat}

def two_spec(x, h):
  %Equal.sym(Nat, S.value(D.digit(Nat.div(x, 10n))), Nat.div(x, 10n), digit_value_spec(Nat.div(x, 10n), two_hi(x, h))) : {Nat.add(Nat.mul(_, 10n), S.value(D.digit(Nat.mod(x, 10n)))) == x : Nat}
  %Equal.sym(Nat, S.value(D.digit(Nat.mod(x, 10n))), Nat.mod(x, 10n), digit_value_spec(Nat.mod(x, 10n), A.mod_lt(x, 10n, {==}))) : {Nat.add(Nat.mul(Nat.div(x, 10n), 10n), _) == x : Nat}
  A.div_mod_id(x, 10n, {==})

law two_prod:
  for +x: Nat
  for h: {Nat.is_lt(x, 100n) == True{} : Bool}
  {D.read2(D.tens(x), D.ones(x)) == x : Nat}

def two_prod(x, h):
  %Equal.sym(Nat, D.digit_value(D.digit(Nat.div(x, 10n))), Nat.div(x, 10n), digit_value_prod(Nat.div(x, 10n), two_hi(x, h))) : {Nat.add(Nat.mul(_, 10n), D.digit_value(D.digit(Nat.mod(x, 10n)))) == x : Nat}
  %Equal.sym(Nat, D.digit_value(D.digit(Nat.mod(x, 10n))), Nat.mod(x, 10n), digit_value_prod(Nat.mod(x, 10n), A.mod_lt(x, 10n, {==}))) : {Nat.add(Nat.mul(Nat.div(x, 10n), 10n), _) == x : Nat}
  A.div_mod_id(x, 10n, {==})

law day_ok:
  for +x: Nat
  for +h: {Nat.is_lt(x, 100n) == True{} : Bool}
  {S.day_ok(D.tens(x), D.ones(x), x) == True{} : Bool}

def day_ok(x, h):
  %Equal.sym(Nat, S.number2(D.tens(x), D.ones(x)), x, two_spec(x, h)) : {Bool.and(S.two_digits(D.tens(x), D.ones(x)), Nat.is_eq(_, x)) == True{} : Bool}
  and_true(S.two_digits(D.tens(x), D.ones(x)), Nat.is_eq(x, x), two_ok(x, h), eq_refl(x))

# Four decimal digits.

def year_d1(+y: Nat, h: {Nat.is_lt(y, 10000n) == True{} : Bool}) -> {Nat.is_lt(Nat.div(y, 10n), 1000n) == True{} : Bool}:
  A.div_lt_of_lt_mul(y, 1000n, 10n, {==}, lt_to(y, 10000n, Nat.mul(1000n, 10n), h, A.eq_of_is_eq(10000n, Nat.mul(1000n, 10n), {==})))

def year_d2(+y: Nat, h: {Nat.is_lt(y, 10000n) == True{} : Bool}) -> {Nat.is_lt(Nat.div(Nat.div(y, 10n), 10n), 100n) == True{} : Bool}:
  A.div_lt_of_lt_mul(Nat.div(y, 10n), 100n, 10n, {==}, lt_to(Nat.div(y, 10n), 1000n, Nat.mul(100n, 10n), year_d1(y, h), A.eq_of_is_eq(1000n, Nat.mul(100n, 10n), {==})))

def year_d3(+y: Nat, h: {Nat.is_lt(y, 10000n) == True{} : Bool}) -> {Nat.is_lt(Nat.div(Nat.div(Nat.div(y, 10n), 10n), 10n), 10n) == True{} : Bool}:
  two_hi(Nat.div(Nat.div(y, 10n), 10n), year_d2(y, h))

law four_spec:
  for +y: Nat
  for +h: {Nat.is_lt(y, 10000n) == True{} : Bool}
  {S.number4(D.thousands(y), D.hundreds(y), D.decades(y), D.ones(y)) == y : Nat}

def four_spec(y, h):
  %Equal.sym(Nat, S.value(D.digit(Nat.div(Nat.div(Nat.div(y, 10n), 10n), 10n))), Nat.div(Nat.div(Nat.div(y, 10n), 10n), 10n), digit_value_spec(Nat.div(Nat.div(Nat.div(y, 10n), 10n), 10n), year_d3(y, h))) : {Nat.add(Nat.mul(Nat.add(Nat.mul(Nat.add(Nat.mul(_, 10n), S.value(D.digit(Nat.mod(Nat.div(Nat.div(y, 10n), 10n), 10n)))), 10n), S.value(D.digit(Nat.mod(Nat.div(y, 10n), 10n)))), 10n), S.value(D.digit(Nat.mod(y, 10n)))) == y : Nat}
  %Equal.sym(Nat, S.value(D.digit(Nat.mod(Nat.div(Nat.div(y, 10n), 10n), 10n))), Nat.mod(Nat.div(Nat.div(y, 10n), 10n), 10n), digit_value_spec(Nat.mod(Nat.div(Nat.div(y, 10n), 10n), 10n), A.mod_lt(Nat.div(Nat.div(y, 10n), 10n), 10n, {==}))) : {Nat.add(Nat.mul(Nat.add(Nat.mul(Nat.add(Nat.mul(Nat.div(Nat.div(Nat.div(y, 10n), 10n), 10n), 10n), _), 10n), S.value(D.digit(Nat.mod(Nat.div(y, 10n), 10n)))), 10n), S.value(D.digit(Nat.mod(y, 10n)))) == y : Nat}
  %Equal.sym(Nat, S.value(D.digit(Nat.mod(Nat.div(y, 10n), 10n))), Nat.mod(Nat.div(y, 10n), 10n), digit_value_spec(Nat.mod(Nat.div(y, 10n), 10n), A.mod_lt(Nat.div(y, 10n), 10n, {==}))) : {Nat.add(Nat.mul(Nat.add(Nat.mul(Nat.add(Nat.mul(Nat.div(Nat.div(Nat.div(y, 10n), 10n), 10n), 10n), Nat.mod(Nat.div(Nat.div(y, 10n), 10n), 10n)), 10n), _), 10n), S.value(D.digit(Nat.mod(y, 10n)))) == y : Nat}
  %Equal.sym(Nat, S.value(D.digit(Nat.mod(y, 10n))), Nat.mod(y, 10n), digit_value_spec(Nat.mod(y, 10n), A.mod_lt(y, 10n, {==}))) : {Nat.add(Nat.mul(Nat.add(Nat.mul(Nat.add(Nat.mul(Nat.div(Nat.div(Nat.div(y, 10n), 10n), 10n), 10n), Nat.mod(Nat.div(Nat.div(y, 10n), 10n), 10n)), 10n), Nat.mod(Nat.div(y, 10n), 10n)), 10n), _) == y : Nat}
  %Equal.sym(Nat, Nat.add(Nat.mul(Nat.div(Nat.div(Nat.div(y, 10n), 10n), 10n), 10n), Nat.mod(Nat.div(Nat.div(y, 10n), 10n), 10n)), Nat.div(Nat.div(y, 10n), 10n), A.div_mod_id(Nat.div(Nat.div(y, 10n), 10n), 10n, {==})) : {Nat.add(Nat.mul(Nat.add(Nat.mul(_, 10n), Nat.mod(Nat.div(y, 10n), 10n)), 10n), Nat.mod(y, 10n)) == y : Nat}
  %Equal.sym(Nat, Nat.add(Nat.mul(Nat.div(Nat.div(y, 10n), 10n), 10n), Nat.mod(Nat.div(y, 10n), 10n)), Nat.div(y, 10n), A.div_mod_id(Nat.div(y, 10n), 10n, {==})) : {Nat.add(Nat.mul(_, 10n), Nat.mod(y, 10n)) == y : Nat}
  A.div_mod_id(y, 10n, {==})

law four_prod:
  for +y: Nat
  for +h: {Nat.is_lt(y, 10000n) == True{} : Bool}
  {D.read4(D.thousands(y), D.hundreds(y), D.decades(y), D.ones(y)) == y : Nat}

def four_prod(y, h):
  %Equal.sym(Nat, D.digit_value(D.digit(Nat.div(Nat.div(Nat.div(y, 10n), 10n), 10n))), Nat.div(Nat.div(Nat.div(y, 10n), 10n), 10n), digit_value_prod(Nat.div(Nat.div(Nat.div(y, 10n), 10n), 10n), year_d3(y, h))) : {Nat.add(Nat.mul(Nat.add(Nat.mul(Nat.add(Nat.mul(_, 10n), D.digit_value(D.digit(Nat.mod(Nat.div(Nat.div(y, 10n), 10n), 10n)))), 10n), D.digit_value(D.digit(Nat.mod(Nat.div(y, 10n), 10n)))), 10n), D.digit_value(D.digit(Nat.mod(y, 10n)))) == y : Nat}
  %Equal.sym(Nat, D.digit_value(D.digit(Nat.mod(Nat.div(Nat.div(y, 10n), 10n), 10n))), Nat.mod(Nat.div(Nat.div(y, 10n), 10n), 10n), digit_value_prod(Nat.mod(Nat.div(Nat.div(y, 10n), 10n), 10n), A.mod_lt(Nat.div(Nat.div(y, 10n), 10n), 10n, {==}))) : {Nat.add(Nat.mul(Nat.add(Nat.mul(Nat.add(Nat.mul(Nat.div(Nat.div(Nat.div(y, 10n), 10n), 10n), 10n), _), 10n), D.digit_value(D.digit(Nat.mod(Nat.div(y, 10n), 10n)))), 10n), D.digit_value(D.digit(Nat.mod(y, 10n)))) == y : Nat}
  %Equal.sym(Nat, D.digit_value(D.digit(Nat.mod(Nat.div(y, 10n), 10n))), Nat.mod(Nat.div(y, 10n), 10n), digit_value_prod(Nat.mod(Nat.div(y, 10n), 10n), A.mod_lt(Nat.div(y, 10n), 10n, {==}))) : {Nat.add(Nat.mul(Nat.add(Nat.mul(Nat.add(Nat.mul(Nat.div(Nat.div(Nat.div(y, 10n), 10n), 10n), 10n), Nat.mod(Nat.div(Nat.div(y, 10n), 10n), 10n)), 10n), _), 10n), D.digit_value(D.digit(Nat.mod(y, 10n)))) == y : Nat}
  %Equal.sym(Nat, D.digit_value(D.digit(Nat.mod(y, 10n))), Nat.mod(y, 10n), digit_value_prod(Nat.mod(y, 10n), A.mod_lt(y, 10n, {==}))) : {Nat.add(Nat.mul(Nat.add(Nat.mul(Nat.add(Nat.mul(Nat.div(Nat.div(Nat.div(y, 10n), 10n), 10n), 10n), Nat.mod(Nat.div(Nat.div(y, 10n), 10n), 10n)), 10n), Nat.mod(Nat.div(y, 10n), 10n)), 10n), _) == y : Nat}
  %Equal.sym(Nat, Nat.add(Nat.mul(Nat.div(Nat.div(Nat.div(y, 10n), 10n), 10n), 10n), Nat.mod(Nat.div(Nat.div(y, 10n), 10n), 10n)), Nat.div(Nat.div(y, 10n), 10n), A.div_mod_id(Nat.div(Nat.div(y, 10n), 10n), 10n, {==})) : {Nat.add(Nat.mul(Nat.add(Nat.mul(_, 10n), Nat.mod(Nat.div(y, 10n), 10n)), 10n), Nat.mod(y, 10n)) == y : Nat}
  %Equal.sym(Nat, Nat.add(Nat.mul(Nat.div(Nat.div(y, 10n), 10n), 10n), Nat.mod(Nat.div(y, 10n), 10n)), Nat.div(y, 10n), A.div_mod_id(Nat.div(y, 10n), 10n, {==})) : {Nat.add(Nat.mul(_, 10n), Nat.mod(y, 10n)) == y : Nat}
  A.div_mod_id(y, 10n, {==})

law year_ok:
  for +y: Nat
  for +h: {Nat.is_lt(y, 10000n) == True{} : Bool}
  {S.year_ok(D.thousands(y), D.hundreds(y), D.decades(y), D.ones(y), y) == True{} : Bool}

def year_ok(y, h):
  %Equal.sym(Nat, S.number4(D.thousands(y), D.hundreds(y), D.decades(y), D.ones(y)), y, four_spec(y, h)) : {Bool.and(Bool.and(S.two_digits(D.thousands(y), D.hundreds(y)), S.two_digits(D.decades(y), D.ones(y))), Nat.is_eq(_, y)) == True{} : Bool}
  and_true(Bool.and(S.two_digits(D.thousands(y), D.hundreds(y)), S.two_digits(D.decades(y), D.ones(y))), Nat.is_eq(y, y), and_true(S.two_digits(D.thousands(y), D.hundreds(y)), S.two_digits(D.decades(y), D.ones(y)), and_true(S.decimal(D.thousands(y)), S.decimal(D.hundreds(y)), digit_decimal(Nat.div(Nat.div(Nat.div(y, 10n), 10n), 10n), year_d3(y, h)), digit_decimal(Nat.mod(Nat.div(Nat.div(y, 10n), 10n), 10n), A.mod_lt(Nat.div(Nat.div(y, 10n), 10n), 10n, {==}))), and_true(S.decimal(D.decades(y)), S.decimal(D.ones(y)), digit_decimal(Nat.mod(Nat.div(y, 10n), 10n), A.mod_lt(Nat.div(y, 10n), 10n, {==})), digit_decimal(Nat.mod(y, 10n), A.mod_lt(y, 10n, {==})))), eq_refl(y))

# Day and month names.

law wd_ok:
  for +k: Nat
  for h: {Nat.is_lt(k, 7n) == True{} : Bool}
  {String.eq(S.three(D.at0(D.weekday_name(k)), D.at1(D.weekday_name(k)), D.at2(D.weekday_name(k))), S.day_name(k)) == True{} : Bool}

def wd_ok(k, h):
  match k:
    case 0n:
      {==}
    case 1n:
      {==}
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
    case 7n+p:
      A.absurd({String.eq(S.three(D.at0(D.weekday_name(7n+p)), D.at1(D.weekday_name(7n+p)), D.at2(D.weekday_name(7n+p))), S.day_name(7n+p)) == True{} : Bool}, A.false_true(Equal.trans(Bool, False{}, Nat.is_lt(Nat.add(7n, p), 7n), True{}, Equal.sym(Bool, Nat.is_lt(Nat.add(7n, p), 7n), False{}, A.not_lt_add(7n, p)), h)))

law mon_ok:
  for +m: Nat
  for h: {Nat.is_lt(m, 12n) == True{} : Bool}
  {String.eq(S.three(D.at0(D.month_name(1n+m)), D.at1(D.month_name(1n+m)), D.at2(D.month_name(1n+m))), S.month_name(1n+m)) == True{} : Bool}

def mon_ok(m, h):
  match m:
    case 0n:
      {==}
    case 1n:
      {==}
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
      A.absurd({String.eq(S.three(D.at0(D.month_name(1n+12n+p)), D.at1(D.month_name(1n+12n+p)), D.at2(D.month_name(1n+12n+p))), S.month_name(1n+12n+p)) == True{} : Bool}, A.false_true(Equal.trans(Bool, False{}, Nat.is_lt(Nat.add(12n, p), 12n), True{}, Equal.sym(Bool, Nat.is_lt(Nat.add(12n, p), 12n), False{}, A.not_lt_add(12n, p)), h)))

law mon_num:
  for +m: Nat
  for h: {Nat.is_lt(m, 12n) == True{} : Bool}
  {D.month_number(SCon{D.at0(D.month_name(1n+m)), SCon{D.at1(D.month_name(1n+m)), SCon{D.at2(D.month_name(1n+m)), SNil{}}}}) == 1n+m : Nat}

def mon_num(m, h):
  match m:
    case 0n:
      {==}
    case 1n:
      {==}
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
      A.absurd({D.month_number(SCon{D.at0(D.month_name(1n+12n+p)), SCon{D.at1(D.month_name(1n+12n+p)), SCon{D.at2(D.month_name(1n+12n+p)), SNil{}}}}) == 1n+12n+p : Nat}, A.false_true(Equal.trans(Bool, False{}, Nat.is_lt(Nat.add(12n, p), 12n), True{}, Equal.sym(Bool, Nat.is_lt(Nat.add(12n, p), 12n), False{}, A.not_lt_add(12n, p)), h)))

# Time of day.

def hour_lt(+t: Nat, h: {Nat.is_lt(t, 86400n) == True{} : Bool}) -> {Nat.is_lt(Nat.div(t, 3600n), 24n) == True{} : Bool}:
  A.div_lt_of_lt_mul(t, 24n, 3600n, {==}, lt_to(t, 86400n, Nat.mul(24n, 3600n), h, A.eq_of_is_eq(86400n, Nat.mul(24n, 3600n), {==})))

def minute_lt(+t: Nat) -> {Nat.is_lt(Nat.div(Nat.mod(t, 3600n), 60n), 60n) == True{} : Bool}:
  A.div_lt_of_lt_mul(Nat.mod(t, 3600n), 60n, 60n, {==}, lt_to(Nat.mod(t, 3600n), 3600n, Nat.mul(60n, 60n), A.mod_lt(t, 3600n, {==}), A.eq_of_is_eq(3600n, Nat.mul(60n, 60n), {==})))

def second_lt(+t: Nat) -> {Nat.is_lt(Nat.mod(Nat.mod(t, 3600n), 60n), 60n) == True{} : Bool}:
  A.mod_lt(Nat.mod(t, 3600n), 60n, {==})

def under100(+x: Nat, +k: Nat, lt: {Nat.is_lt(x, k) == True{} : Bool}, le: {Nat.is_le(k, 100n) == True{} : Bool}) -> {Nat.is_lt(x, 100n) == True{} : Bool}:
  A.lt_le_trans(x, k, 100n, lt, le)

law time_ok:
  for +t: Nat
  for +h: {Nat.is_lt(t, 86400n) == True{} : Bool}
  {S.time_ok(D.tens(Nat.div(t, 3600n)), D.ones(Nat.div(t, 3600n)), D.tens(Nat.div(Nat.mod(t, 3600n), 60n)), D.ones(Nat.div(Nat.mod(t, 3600n), 60n)), D.tens(Nat.mod(Nat.mod(t, 3600n), 60n)), D.ones(Nat.mod(Nat.mod(t, 3600n), 60n)), t) == True{} : Bool}

def time_ok(t, h):
  %Equal.sym(Nat, S.number2(D.tens(Nat.div(t, 3600n)), D.ones(Nat.div(t, 3600n))), Nat.div(t, 3600n), two_spec(Nat.div(t, 3600n), under100(Nat.div(t, 3600n), 24n, hour_lt(t, h), {==}))) : {Bool.and(Bool.and(S.two_digits(D.tens(Nat.div(t, 3600n)), D.ones(Nat.div(t, 3600n))), Bool.and(S.two_digits(D.tens(Nat.div(Nat.mod(t, 3600n), 60n)), D.ones(Nat.div(Nat.mod(t, 3600n), 60n))), S.two_digits(D.tens(Nat.mod(Nat.mod(t, 3600n), 60n)), D.ones(Nat.mod(Nat.mod(t, 3600n), 60n))))), Bool.and(Bool.and(Nat.is_lt(_, 24n), Bool.and(Nat.is_lt(S.number2(D.tens(Nat.div(Nat.mod(t, 3600n), 60n)), D.ones(Nat.div(Nat.mod(t, 3600n), 60n))), 60n), Nat.is_lt(S.number2(D.tens(Nat.mod(Nat.mod(t, 3600n), 60n)), D.ones(Nat.mod(Nat.mod(t, 3600n), 60n))), 60n))), Nat.is_eq(Nat.add(Nat.mul(_, 3600n), Nat.add(Nat.mul(S.number2(D.tens(Nat.div(Nat.mod(t, 3600n), 60n)), D.ones(Nat.div(Nat.mod(t, 3600n), 60n))), 60n), S.number2(D.tens(Nat.mod(Nat.mod(t, 3600n), 60n)), D.ones(Nat.mod(Nat.mod(t, 3600n), 60n))))), t))) == True{} : Bool}
  %Equal.sym(Nat, S.number2(D.tens(Nat.div(Nat.mod(t, 3600n), 60n)), D.ones(Nat.div(Nat.mod(t, 3600n), 60n))), Nat.div(Nat.mod(t, 3600n), 60n), two_spec(Nat.div(Nat.mod(t, 3600n), 60n), under100(Nat.div(Nat.mod(t, 3600n), 60n), 60n, minute_lt(t), {==}))) : {Bool.and(Bool.and(S.two_digits(D.tens(Nat.div(t, 3600n)), D.ones(Nat.div(t, 3600n))), Bool.and(S.two_digits(D.tens(Nat.div(Nat.mod(t, 3600n), 60n)), D.ones(Nat.div(Nat.mod(t, 3600n), 60n))), S.two_digits(D.tens(Nat.mod(Nat.mod(t, 3600n), 60n)), D.ones(Nat.mod(Nat.mod(t, 3600n), 60n))))), Bool.and(Bool.and(Nat.is_lt(Nat.div(t, 3600n), 24n), Bool.and(Nat.is_lt(_, 60n), Nat.is_lt(S.number2(D.tens(Nat.mod(Nat.mod(t, 3600n), 60n)), D.ones(Nat.mod(Nat.mod(t, 3600n), 60n))), 60n))), Nat.is_eq(Nat.add(Nat.mul(Nat.div(t, 3600n), 3600n), Nat.add(Nat.mul(_, 60n), S.number2(D.tens(Nat.mod(Nat.mod(t, 3600n), 60n)), D.ones(Nat.mod(Nat.mod(t, 3600n), 60n))))), t))) == True{} : Bool}
  %Equal.sym(Nat, S.number2(D.tens(Nat.mod(Nat.mod(t, 3600n), 60n)), D.ones(Nat.mod(Nat.mod(t, 3600n), 60n))), Nat.mod(Nat.mod(t, 3600n), 60n), two_spec(Nat.mod(Nat.mod(t, 3600n), 60n), under100(Nat.mod(Nat.mod(t, 3600n), 60n), 60n, second_lt(t), {==}))) : {Bool.and(Bool.and(S.two_digits(D.tens(Nat.div(t, 3600n)), D.ones(Nat.div(t, 3600n))), Bool.and(S.two_digits(D.tens(Nat.div(Nat.mod(t, 3600n), 60n)), D.ones(Nat.div(Nat.mod(t, 3600n), 60n))), S.two_digits(D.tens(Nat.mod(Nat.mod(t, 3600n), 60n)), D.ones(Nat.mod(Nat.mod(t, 3600n), 60n))))), Bool.and(Bool.and(Nat.is_lt(Nat.div(t, 3600n), 24n), Bool.and(Nat.is_lt(Nat.div(Nat.mod(t, 3600n), 60n), 60n), Nat.is_lt(_, 60n))), Nat.is_eq(Nat.add(Nat.mul(Nat.div(t, 3600n), 3600n), Nat.add(Nat.mul(Nat.div(Nat.mod(t, 3600n), 60n), 60n), _)), t))) == True{} : Bool}
  %Equal.sym(Nat, Nat.add(Nat.mul(Nat.div(Nat.mod(t, 3600n), 60n), 60n), Nat.mod(Nat.mod(t, 3600n), 60n)), Nat.mod(t, 3600n), A.div_mod_id(Nat.mod(t, 3600n), 60n, {==})) : {Bool.and(Bool.and(S.two_digits(D.tens(Nat.div(t, 3600n)), D.ones(Nat.div(t, 3600n))), Bool.and(S.two_digits(D.tens(Nat.div(Nat.mod(t, 3600n), 60n)), D.ones(Nat.div(Nat.mod(t, 3600n), 60n))), S.two_digits(D.tens(Nat.mod(Nat.mod(t, 3600n), 60n)), D.ones(Nat.mod(Nat.mod(t, 3600n), 60n))))), Bool.and(Bool.and(Nat.is_lt(Nat.div(t, 3600n), 24n), Bool.and(Nat.is_lt(Nat.div(Nat.mod(t, 3600n), 60n), 60n), Nat.is_lt(Nat.mod(Nat.mod(t, 3600n), 60n), 60n))), Nat.is_eq(Nat.add(Nat.mul(Nat.div(t, 3600n), 3600n), _), t))) == True{} : Bool}
  %Equal.sym(Nat, Nat.add(Nat.mul(Nat.div(t, 3600n), 3600n), Nat.mod(t, 3600n)), t, A.div_mod_id(t, 3600n, {==})) : {Bool.and(Bool.and(S.two_digits(D.tens(Nat.div(t, 3600n)), D.ones(Nat.div(t, 3600n))), Bool.and(S.two_digits(D.tens(Nat.div(Nat.mod(t, 3600n), 60n)), D.ones(Nat.div(Nat.mod(t, 3600n), 60n))), S.two_digits(D.tens(Nat.mod(Nat.mod(t, 3600n), 60n)), D.ones(Nat.mod(Nat.mod(t, 3600n), 60n))))), Bool.and(Bool.and(Nat.is_lt(Nat.div(t, 3600n), 24n), Bool.and(Nat.is_lt(Nat.div(Nat.mod(t, 3600n), 60n), 60n), Nat.is_lt(Nat.mod(Nat.mod(t, 3600n), 60n), 60n))), Nat.is_eq(_, t))) == True{} : Bool}
  and_true(Bool.and(S.two_digits(D.tens(Nat.div(t, 3600n)), D.ones(Nat.div(t, 3600n))), Bool.and(S.two_digits(D.tens(Nat.div(Nat.mod(t, 3600n), 60n)), D.ones(Nat.div(Nat.mod(t, 3600n), 60n))), S.two_digits(D.tens(Nat.mod(Nat.mod(t, 3600n), 60n)), D.ones(Nat.mod(Nat.mod(t, 3600n), 60n))))), Bool.and(Bool.and(Nat.is_lt(Nat.div(t, 3600n), 24n), Bool.and(Nat.is_lt(Nat.div(Nat.mod(t, 3600n), 60n), 60n), Nat.is_lt(Nat.mod(Nat.mod(t, 3600n), 60n), 60n))), Nat.is_eq(t, t)), and_true(S.two_digits(D.tens(Nat.div(t, 3600n)), D.ones(Nat.div(t, 3600n))), Bool.and(S.two_digits(D.tens(Nat.div(Nat.mod(t, 3600n), 60n)), D.ones(Nat.div(Nat.mod(t, 3600n), 60n))), S.two_digits(D.tens(Nat.mod(Nat.mod(t, 3600n), 60n)), D.ones(Nat.mod(Nat.mod(t, 3600n), 60n)))), two_ok(Nat.div(t, 3600n), under100(Nat.div(t, 3600n), 24n, hour_lt(t, h), {==})), and_true(S.two_digits(D.tens(Nat.div(Nat.mod(t, 3600n), 60n)), D.ones(Nat.div(Nat.mod(t, 3600n), 60n))), S.two_digits(D.tens(Nat.mod(Nat.mod(t, 3600n), 60n)), D.ones(Nat.mod(Nat.mod(t, 3600n), 60n))), two_ok(Nat.div(Nat.mod(t, 3600n), 60n), under100(Nat.div(Nat.mod(t, 3600n), 60n), 60n, minute_lt(t), {==})), two_ok(Nat.mod(Nat.mod(t, 3600n), 60n), under100(Nat.mod(Nat.mod(t, 3600n), 60n), 60n, second_lt(t), {==})))), and_true(Bool.and(Nat.is_lt(Nat.div(t, 3600n), 24n), Bool.and(Nat.is_lt(Nat.div(Nat.mod(t, 3600n), 60n), 60n), Nat.is_lt(Nat.mod(Nat.mod(t, 3600n), 60n), 60n))), Nat.is_eq(t, t), and_true(Nat.is_lt(Nat.div(t, 3600n), 24n), Bool.and(Nat.is_lt(Nat.div(Nat.mod(t, 3600n), 60n), 60n), Nat.is_lt(Nat.mod(Nat.mod(t, 3600n), 60n), 60n)), hour_lt(t, h), and_true(Nat.is_lt(Nat.div(Nat.mod(t, 3600n), 60n), 60n), Nat.is_lt(Nat.mod(Nat.mod(t, 3600n), 60n), 60n), minute_lt(t), second_lt(t))), eq_refl(t)))
