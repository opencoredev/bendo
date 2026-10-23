# Pure IMF-fixdate, Unix seconds from 1970-01-01 through 9999-12-31.
#
# The calendar counts days from 1600-01-01, the first day of a 400-year
# Gregorian cycle. Each cycle splits into centuries, each century into
# four-year groups, each group into years and each year into months. A layer
# is a list of period lengths: decoding finds the period a day falls in and
# the offset into it, and encoding adds the earlier lengths back. Leap days
# fall in the first year of a group, so the lengths that vary come first.
# Only Nat arithmetic is used, so the laws in LAWS.bend can be proven.
import Base

# 253402300799, the last second of 9999-12-31.
def max_seconds() -> Nat:
  Nat.add(Nat.mul(253402300n, 1000n), 799n)

def is_zero(n: Nat) -> Bool:
  match n:
    case 0n:
      True{}
    case 1n+p:
      False{}

def rep(k: Nat, +l: Nat) -> List<&2, Nat>:
  match k:
    case 0n:
      []
    case 1n+p:
      l <> rep(p, l)

# A 400-year cycle has 146097 days. Only its first century, which starts on
# a year divisible by 400, keeps its centennial leap day.
def century_lengths() -> List<&2, Nat>:
  [36525n, 36524n, 36524n, 36524n]

def first_group(first_century: Bool) -> Nat:
  match first_century:
    case True{}:
      1461n
    case False{}:
      1460n

# The first group of a century lacks its leap day unless the century is the
# first of its cycle.
def group_lengths(first_century: Bool) -> List<&2, Nat>:
  first_group(first_century) <> rep(24n, 1461n)

def long_group(c: Nat, q: Nat) -> Bool:
  Bool.or(Bool.not(is_zero(q)), is_zero(c))

def first_year(long: Bool) -> Nat:
  match long:
    case True{}:
      366n
    case False{}:
      365n

def year_lengths(long: Bool) -> List<&2, Nat>:
  [first_year(long), 365n, 365n, 365n]

def leap(c: Nat, q: Nat, yq: Nat) -> Bool:
  Bool.and(is_zero(yq), long_group(c, q))

def february(leap: Bool) -> Nat:
  match leap:
    case True{}:
      29n
    case False{}:
      28n

def month_lengths(leap: Bool) -> List<&2, Nat>:
  [31n, february(leap), 31n, 30n, 31n, 30n, 31n, 31n, 30n, 31n, 30n, 31n]

def index_pick(here: Bool, later: Nat) -> Nat:
  match here:
    case True{}:
      0n
    case False{}:
      1n+later

# The period that day x falls in.
def index(lens: List<&2, Nat>, +x: Nat) -> Nat:
  match lens:
    case Nil{}:
      0n
    case +l <> t:
      index_pick(Nat.is_lt(x, l), index(t, Nat.sub(x, l)))

def offset_pick(x: Nat, here: Bool, later: Nat) -> Nat:
  match here:
    case True{}:
      x
    case False{}:
      later

# The offset of day x into its period.
def offset(lens: List<&2, Nat>, +x: Nat) -> Nat:
  match lens:
    case Nil{}:
      x
    case +l <> t:
      offset_pick(x, Nat.is_lt(x, l), offset(t, Nat.sub(x, l)))

# Inverse of index and offset: the first i periods, then r more days.
def before(i: Nat, lens: List<&2, Nat>, r: Nat) -> Nat:
  match i lens:
    case 0n _:
      r
    case 1n+j Nil{}:
      r
    case 1n+j l <> t:
      Nat.add(l, before(j, t, r))

# Decoding days since 1600-01-01 into (year, (month, day)).

def date_of(e: Nat, c: Nat, q: Nat, yq: Nat, m: Nat, r: Nat) -> Nat & (Nat & Nat):
  (Nat.add(1600n, Nat.add(Nat.mul(e, 400n), Nat.add(Nat.mul(c, 100n), Nat.add(Nat.mul(q, 4n), yq)))), (1n+m, 1n+r))

def civil_month(+e: Nat, +c: Nat, +q: Nat, +yq: Nat, +doy: Nat) -> Nat & (Nat & Nat):
  date_of(e, c, q, yq, index(month_lengths(leap(c, q, yq)), doy), offset(month_lengths(leap(c, q, yq)), doy))

def civil_year(+e: Nat, +c: Nat, +q: Nat, +doq: Nat) -> Nat & (Nat & Nat):
  civil_month(e, c, q, index(year_lengths(long_group(c, q)), doq), offset(year_lengths(long_group(c, q)), doq))

def civil_group(+e: Nat, +c: Nat, +doc: Nat) -> Nat & (Nat & Nat):
  civil_year(e, c, index(group_lengths(is_zero(c)), doc), offset(group_lengths(is_zero(c)), doc))

def civil_century(+e: Nat, +doe: Nat) -> Nat & (Nat & Nat):
  civil_group(e, index(century_lengths(), doe), offset(century_lengths(), doe))

def civil(+z: Nat) -> Nat & (Nat & Nat):
  civil_century(Nat.div(z, 146097n), Nat.mod(z, 146097n))

# Encoding (year, month, day) into days since 1600-01-01.

def days_of(+e: Nat, +c: Nat, +q: Nat, +yq: Nat, m: Nat, r: Nat) -> Nat:
  Nat.add(Nat.mul(e, 146097n), before(c, century_lengths(), before(q, group_lengths(is_zero(c)), before(yq, year_lengths(long_group(c, q)), before(m, month_lengths(leap(c, q, yq)), r)))))

def days_group(+e: Nat, +c: Nat, +a2: Nat, m: Nat, r: Nat) -> Nat:
  days_of(e, c, Nat.div(a2, 4n), Nat.mod(a2, 4n), m, r)

def days_century(+e: Nat, +a1: Nat, m: Nat, r: Nat) -> Nat:
  days_group(e, Nat.div(a1, 100n), Nat.mod(a1, 100n), m, r)

def days_from(year: Nat, month: Nat, day: Nat) -> Nat:
  +a = Nat.sub(year, 1600n)
  days_century(Nat.div(a, 400n), Nat.mod(a, 400n), Nat.sub(month, 1n), Nat.sub(day, 1n))

# Text.

def weekday_name(n: Nat) -> String:
  match n:
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

# 1 is January.
def month_name(n: Nat) -> String:
  match n:
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

def at0(s: String) -> Char:
  match s:
    case SCon{c, t}:
      c
    case SNil{}:
      ' '

def at1(s: String) -> Char:
  match s:
    case SCon{a, SCon{c, t}}:
      c
    case _:
      ' '

def at2(s: String) -> Char:
  match s:
    case SCon{a, SCon{b, SCon{c, t}}}:
      c
    case _:
      ' '

def digit(n: Nat) -> Char:
  match n:
    case 0n:
      '0'
    case 1n:
      '1'
    case 2n:
      '2'
    case 3n:
      '3'
    case 4n:
      '4'
    case 5n:
      '5'
    case 6n:
      '6'
    case 7n:
      '7'
    case 8n:
      '8'
    case _:
      '9'

def tens(+n: Nat) -> Char:
  digit(Nat.div(n, 10n))

def ones(+n: Nat) -> Char:
  digit(Nat.mod(n, 10n))

def thousands(+n: Nat) -> Char:
  digit(Nat.div(Nat.div(Nat.div(n, 10n), 10n), 10n))

def hundreds(+n: Nat) -> Char:
  digit(Nat.mod(Nat.div(Nat.div(n, 10n), 10n), 10n))

def decades(+n: Nat) -> Char:
  digit(Nat.mod(Nat.div(n, 10n), 10n))

def render(+wd: String, +year: Nat, +mon: String, +day: Nat, +hour: Nat, +minute: Nat, +second: Nat) -> String:
  SCon{at0(wd), SCon{at1(wd), SCon{at2(wd), SCon{',', SCon{' ', SCon{tens(day), SCon{ones(day), SCon{' ', SCon{at0(mon), SCon{at1(mon), SCon{at2(mon), SCon{' ', SCon{thousands(year), SCon{hundreds(year), SCon{decades(year), SCon{ones(year), SCon{' ', SCon{tens(hour), SCon{ones(hour), SCon{':', SCon{tens(minute), SCon{ones(minute), SCon{':', SCon{tens(second), SCon{ones(second), SCon{' ', SCon{'G', SCon{'M', SCon{'T', SNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}

def render_date(wd: Nat, date: Nat & (Nat & Nat), +rest: Nat) -> String:
  (year, md) = date
  (mon, day) = md
  render(weekday_name(wd), year, month_name(mon), day, Nat.div(rest, 3600n), Nat.div(Nat.mod(rest, 3600n), 60n), Nat.mod(Nat.mod(rest, 3600n), 60n))

# 1970-01-01 was a Thursday (0 is Sunday) and day 135140 after 1600-01-01.
def render_day(+n: Nat, +rest: Nat) -> String:
  render_date(Nat.mod(Nat.add(n, 4n), 7n), civil(Nat.add(n, 135140n)), rest)

def format_valid(+s: Nat, valid: Bool) -> String:
  match valid:
    case False{}:
      ""
    case True{}:
      render_day(Nat.div(s, 86400n), Nat.mod(s, 86400n))

# Unix days 0 through 2932896 run from 1970-01-01 to 9999-12-31: 10957 days
# to 2000-01-01, then twenty 400-year cycles of 146097 days. Later inputs have
# no IMF-fixdate and format as the empty string.
def format_imf(+s: Nat) -> String:
  format_valid(s, Nat.is_lt(Nat.div(Nat.sub(Nat.div(s, 86400n), 10957n), 146097n), 20n))

# Reading. Fields are decoded without validation; parse_imf accepts a value
# only when formatting it reproduces the input exactly.

def digit_value(c: Char) -> Nat:
  match c:
    case Chr{x}:
      Nat.sub(U32.to_nat(x), 48n)

def read2(a: Char, b: Char) -> Nat:
  Nat.add(Nat.mul(digit_value(a), 10n), digit_value(b))

def read4(a: Char, b: Char, c: Char, d: Char) -> Nat:
  Nat.add(Nat.mul(Nat.add(Nat.mul(Nat.add(Nat.mul(digit_value(a), 10n), digit_value(b)), 10n), digit_value(c)), 10n), digit_value(d))

def month_number(s: String) -> Nat:
  match s:
    case "Jan":
      1n
    case "Feb":
      2n
    case "Mar":
      3n
    case "Apr":
      4n
    case "May":
      5n
    case "Jun":
      6n
    case "Jul":
      7n
    case "Aug":
      8n
    case "Sep":
      9n
    case "Oct":
      10n
    case "Nov":
      11n
    case "Dec":
      12n
    case _:
      0n

def seconds_from(days: Nat, hour: Nat, minute: Nat, second: Nat) -> Nat:
  Nat.add(Nat.mul(days, 86400n), Nat.add(Nat.mul(hour, 3600n), Nat.add(Nat.mul(minute, 60n), second)))

def read_imf(s: String) -> Maybe<&2, Nat>:
  match s:
    case SCon{w0, SCon{w1, SCon{w2, SCon{',', SCon{' ', SCon{d0, SCon{d1, SCon{' ', SCon{m0, SCon{m1, SCon{m2, SCon{' ', SCon{y0, SCon{y1, SCon{y2, SCon{y3, SCon{' ', SCon{h0, SCon{h1, SCon{':', SCon{n0, SCon{n1, SCon{':', SCon{s0, SCon{s1, SCon{' ', SCon{'G', SCon{'M', SCon{'T', SNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      Some{seconds_from(Nat.sub(days_from(read4(y0, y1, y2, y3), month_number(SCon{m0, SCon{m1, SCon{m2, SNil{}}}}), read2(d0, d1)), 135140n), read2(h0, h1), read2(n0, n1), read2(s0, s1))}
    case _:
      None{}

def parsed(s: Nat, valid: Bool) -> Maybe<&2, Nat>:
  match valid:
    case True{}:
      Some{s}
    case False{}:
      None{}

def canonical(found: Maybe<&2, Nat>, original: String) -> Maybe<&2, Nat>:
  match found:
    case None{}:
      None{}
    case Some{+s}:
      parsed(s, String.eq(format_imf(s), original))

# Only exact IMF-fixdate is accepted; obsolete HTTP date forms are rejected.
def parse_imf(+s: String) -> Maybe<&2, Nat>:
  canonical(read_imf(s), s)
