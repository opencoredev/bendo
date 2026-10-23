# Independent specification of IMF-fixdate text (RFC 9110 section 5.6.7),
# written without the production codec in src/http/date.bend.
#
# denotes(text, s) holds when text is exactly
#   day-name "," SP 2DIGIT SP month SP 4DIGIT SP 2DIGIT ":" 2DIGIT ":" 2DIGIT SP "GMT"
# with English day and month names, and its fields are the UTC civil date
# and time of Unix second s. The date comes from counting days forward from
# 1970-01-01 under the Gregorian rules, and the weekday from counting forward
# from Thursday.
import Base

# Divisible by 4, except century years not divisible by 400.
def leap(+y: Nat) -> Bool:
  Bool.or(Bool.and(Nat.is_eq(Nat.mod(y, 4n), 0n), Bool.not(Nat.is_eq(Nat.mod(y, 100n), 0n))), Nat.is_eq(Nat.mod(y, 400n), 0n))

def february(leap: Bool) -> Nat:
  match leap:
    case True{}:
      29n
    case False{}:
      28n

# Month 1 is January.
def month_days(+y: Nat, m: Nat) -> Nat:
  match m:
    case 1n:
      31n
    case 2n:
      february(leap(y))
    case 3n:
      31n
    case 4n:
      30n
    case 5n:
      31n
    case 6n:
      30n
    case 7n:
      31n
    case 8n:
      31n
    case 9n:
      30n
    case 10n:
      31n
    case 11n:
      30n
    case _:
      31n

# Dates are (year, (month, day)).

def next_month(+y: Nat, m: Nat, more: Bool) -> Nat & (Nat & Nat):
  match more:
    case True{}:
      (y, (1n+m, 1n))
    case False{}:
      (1n+y, (1n, 1n))

def next_in_month(+y: Nat, +m: Nat, d: Nat, more: Bool) -> Nat & (Nat & Nat):
  match more:
    case True{}:
      (y, (m, 1n+d))
    case False{}:
      next_month(y, m, Nat.is_lt(m, 12n))

def next_from(+y: Nat, +m: Nat, +d: Nat) -> Nat & (Nat & Nat):
  next_in_month(y, m, d, Nat.is_lt(d, month_days(y, m)))

def next_day(date: Nat & (Nat & Nat)) -> Nat & (Nat & Nat):
  (y, md) = date
  (m, d) = md
  next_from(y, m, d)

# The civil date n days after 1970-01-01.
def civil(n: Nat) -> Nat & (Nat & Nat):
  match n:
    case 0n:
      (1970n, (1n, 1n))
    case 1n+p:
      next_day(civil(p))

# 0 is Sunday.
def next_weekday(w: Nat) -> Nat:
  match w:
    case 0n:
      1n
    case 1n:
      2n
    case 2n:
      3n
    case 3n:
      4n
    case 4n:
      5n
    case 5n:
      6n
    case _:
      0n

# 1970-01-01 was a Thursday.
def weekday(n: Nat) -> Nat:
  match n:
    case 0n:
      4n
    case 1n+p:
      next_weekday(weekday(p))

def day_name(w: Nat) -> String:
  match w:
    case 0n:
      "Sun"
    case 1n:
      "Mon"
    case 2n:
      "Tue"
    case 3n:
      "Wed"
    case 4n:
      "Thu"
    case 5n:
      "Fri"
    case _:
      "Sat"

def month_name(m: Nat) -> String:
  match m:
    case 1n:
      "Jan"
    case 2n:
      "Feb"
    case 3n:
      "Mar"
    case 4n:
      "Apr"
    case 5n:
      "May"
    case 6n:
      "Jun"
    case 7n:
      "Jul"
    case 8n:
      "Aug"
    case 9n:
      "Sep"
    case 10n:
      "Oct"
    case 11n:
      "Nov"
    case _:
      "Dec"

def decimal(c: Char) -> Bool:
  match c:
    case Chr{+x}:
      Bool.and(U32.is_ge(x, 48), U32.is_le(x, 57))

def value(c: Char) -> Nat:
  match c:
    case Chr{x}:
      Nat.sub(U32.to_nat(x), 48n)

def two_digits(+a: Char, +b: Char) -> Bool:
  Bool.and(decimal(a), decimal(b))

def number2(a: Char, b: Char) -> Nat:
  Nat.add(Nat.mul(value(a), 10n), value(b))

def number4(a: Char, b: Char, c: Char, d: Char) -> Nat:
  Nat.add(Nat.mul(Nat.add(Nat.mul(Nat.add(Nat.mul(value(a), 10n), value(b)), 10n), value(c)), 10n), value(d))

def three(a: Char, b: Char, c: Char) -> String:
  SCon{a, SCon{b, SCon{c, SNil{}}}}

def day_ok(+d0: Char, +d1: Char, d: Nat) -> Bool:
  Bool.and(two_digits(d0, d1), Nat.is_eq(number2(d0, d1), d))

def year_ok(+y0: Char, +y1: Char, +y2: Char, +y3: Char, y: Nat) -> Bool:
  Bool.and(Bool.and(two_digits(y0, y1), two_digits(y2, y3)), Nat.is_eq(number4(y0, y1, y2, y3), y))

# Hours 00-23, minutes and seconds 00-59, together the second of the day.
def time_ok(+h0: Char, +h1: Char, +n0: Char, +n1: Char, +s0: Char, +s1: Char, t: Nat) -> Bool:
  +h = number2(h0, h1)
  +n = number2(n0, n1)
  +s = number2(s0, s1)
  Bool.and(Bool.and(two_digits(h0, h1), Bool.and(two_digits(n0, n1), two_digits(s0, s1))), Bool.and(Bool.and(Nat.is_lt(h, 24n), Bool.and(Nat.is_lt(n, 60n), Nat.is_lt(s, 60n))), Nat.is_eq(Nat.add(Nat.mul(h, 3600n), Nat.add(Nat.mul(n, 60n), s)), t)))

def fields_ok(date: Nat & (Nat & Nat), w: Nat, t: Nat, wd: String, d0: Char, d1: Char, mon: String, y0: Char, y1: Char, y2: Char, y3: Char, h0: Char, h1: Char, n0: Char, n1: Char, s0: Char, s1: Char) -> Bool:
  (y, md) = date
  (m, d) = md
  Bool.and(String.eq(wd, day_name(w)), Bool.and(day_ok(d0, d1, d), Bool.and(String.eq(mon, month_name(m)), Bool.and(year_ok(y0, y1, y2, y3, y), time_ok(h0, h1, n0, n1, s0, s1, t)))))

def denotes(text: String, +s: Nat) -> Bool:
  match text:
    case SCon{w0, SCon{w1, SCon{w2, SCon{',', SCon{' ', SCon{d0, SCon{d1, SCon{' ', SCon{m0, SCon{m1, SCon{m2, SCon{' ', SCon{y0, SCon{y1, SCon{y2, SCon{y3, SCon{' ', SCon{h0, SCon{h1, SCon{':', SCon{n0, SCon{n1, SCon{':', SCon{s0, SCon{s1, SCon{' ', SCon{'G', SCon{'M', SCon{'T', SNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      +days = Nat.div(s, 86400n)
      fields_ok(civil(days), weekday(days), Nat.mod(s, 86400n), three(w0, w1, w2), d0, d1, three(m0, m1, m2), y0, y1, y2, y3, h0, h1, n0, n1, s0, s1)
    case _:
      False{}
