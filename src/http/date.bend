# Pure IMF-fixdate, Unix seconds from 1970-01-01 through 9999-12-31.
import Base

def max_seconds() -> Nat:
  Nat.add(Nat.mul(253402300n, 1000n), 799n)

def choose(flag: Bool, yes: U32, no: U32) -> U32:
  match flag:
    case True{}: yes
    case False{}: no

def weekday(n: U32) -> String:
  match n:
    case 0: "Sun"
    case 1: "Mon"
    case 2: "Tue"
    case 3: "Wed"
    case 4: "Thu"
    case 5: "Fri"
    case _: "Sat"

def month(n: U32) -> String:
  match n:
    case 1: "Jan"
    case 2: "Feb"
    case 3: "Mar"
    case 4: "Apr"
    case 5: "May"
    case 6: "Jun"
    case 7: "Jul"
    case 8: "Aug"
    case 9: "Sep"
    case 10: "Oct"
    case 11: "Nov"
    case _: "Dec"

def digit(n: U32) -> Char:
  Chr{U32.add(48, n)}

def two(+n: U32) -> String:
  SCon{digit(U32.div(n, 10)), SCon{digit(U32.mod(n, 10)), SNil{}}}

def four(+n: U32) -> String:
  two(U32.div(n, 100)) ++ two(U32.mod(n, 100))

# Howard Hinnant's civil_from_days, with nonnegative March-based eras.
# The supported domain keeps every intermediate below 4 million.
def civil(days: U32) -> U32 & (U32 & U32):
  +z = U32.add(days, 719468)
  +era = U32.div(z, 146097)
  +doe = U32.mod(z, 146097)
  +yoe = U32.div(U32.sub(U32.add(U32.sub(doe, U32.div(doe, 1460)), U32.div(doe, 36524)), U32.div(doe, 146096)), 365)
  +year = U32.add(U32.mul(era, 400), yoe)
  +doy = U32.sub(doe, U32.sub(U32.add(U32.mul(365, yoe), U32.div(yoe, 4)), U32.div(yoe, 100)))
  +mp = U32.div(U32.add(U32.mul(5, doy), 2), 153)
  day = U32.add(U32.sub(doy, U32.div(U32.add(U32.mul(153, mp), 2), 5)), 1)
  +mon = choose(U32.is_lt(mp, 10), U32.add(mp, 3), U32.sub(mp, 9))
  (U32.add(year, choose(U32.is_le(mon, 2), 1, 0)), (mon, day))

def render_civil(ds: U32, +time: U32, fields: U32 & (U32 & U32)) -> String:
  (year, (mon, day)) = fields
  weekday(U32.mod(U32.add(ds, 4), 7)) ++ ", " ++ two(day) ++ " " ++ month(mon) ++ " " ++ four(year) ++ " " ++ two(U32.div(time, 3600)) ++ ":" ++ two(U32.mod(U32.div(time, 60), 60)) ++ ":" ++ two(U32.mod(time, 60)) ++ " GMT"

def render(+days: U32, time: U32) -> String:
  render_civil(days, time, civil(days))

def format_split(pair: Nat & Nat) -> String:
  (days, time) = pair
  render(U32.from_nat(days), U32.from_nat(time))

def format_valid(s: Nat, valid: Bool) -> String:
  match valid:
    case False{}: ""
    case True{}:
      format_split(Nat.divmod(s, 86400n))

# Out-of-range inputs have no IMF representation and format as the empty string.
def format_imf(+s: Nat) -> String:
  format_valid(s, Nat.is_le(s, max_seconds()))

# Inverse March-based civil algorithm. Call only after field validation.
def epoch_days(+year: U32, +mon: U32, day: U32) -> U32:
  +y = U32.sub(year, choose(U32.is_le(mon, 2), 1, 0))
  +era = U32.div(y, 400)
  +yoe = U32.mod(y, 400)
  mp = choose(U32.is_gt(mon, 2), U32.sub(mon, 3), U32.add(mon, 9))
  doy = U32.sub(U32.add(U32.div(U32.add(U32.mul(153, mp), 2), 5), day), 1)
  doe = U32.add(U32.sub(U32.add(U32.mul(365, yoe), U32.div(yoe, 4)), U32.div(yoe, 100)), doy)
  U32.sub(U32.add(U32.mul(era, 146097), doe), 719468)

def month_number(s: String) -> U32:
  match s:
    case "Jan": 1
    case "Feb": 2
    case "Mar": 3
    case "Apr": 4
    case "May": 5
    case "Jun": 6
    case "Jul": 7
    case "Aug": 8
    case "Sep": 9
    case "Oct": 10
    case "Nov": 11
    case "Dec": 12
    case _: 0

def read_two(a: Char, b: Char) -> U32:
  Chr{x} = a
  Chr{y} = b
  U32.add(U32.mul(U32.sub(x, 48), 10), U32.sub(y, 48))

def decimal(c: Char) -> Bool:
  Chr{+x} = c
  U32.is_ge(x, 48) && U32.is_le(x, 57)

def parsed(s: Nat, valid: Bool) -> Maybe<&2, Nat>:
  match valid:
    case True{}: Some{s}
    case False{}: None{}

def canonical(+s: Nat, original: String) -> Maybe<&2, Nat>:
  parsed(s, String.eq(format_imf(s), original))

def fields(original: String, year: U32, mon: U32, day: U32, hour: U32, minute: U32, second: U32, valid: Bool) -> Maybe<&2, Nat>:
  match valid:
    case False{}: None{}
    case True{}:
      seconds = Nat.add(Nat.mul(U32.to_nat(epoch_days(year, mon, day)), 86400n), U32.to_nat(U32.add(U32.add(U32.mul(hour, 3600), U32.mul(minute, 60)), second)))
      canonical(seconds, original)

# Only exact IMF-fixdate is accepted; obsolete HTTP date forms are rejected.
def parse_imf(+s: String) -> Maybe<&2, Nat>:
  match s:
    case SCon{w0, SCon{w1, SCon{w2, SCon{',', SCon{' ', SCon{+d0, SCon{+d1, SCon{' ', SCon{m0, SCon{m1, SCon{m2, SCon{' ', SCon{+y0, SCon{+y1, SCon{+y2, SCon{+y3, SCon{' ', SCon{+h0, SCon{+h1, SCon{':', SCon{+n0, SCon{+n1, SCon{':', SCon{+s0, SCon{+s1, SCon{' ', SCon{'G', SCon{'M', SCon{'T', SNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      +year = U32.add(U32.mul(read_two(y0, y1), 100), read_two(y2, y3))
      +mon = month_number(SCon{m0, SCon{m1, SCon{m2, SNil{}}}})
      +day = read_two(d0, d1)
      +hour = read_two(h0, h1)
      +minute = read_two(n0, n1)
      +second = read_two(s0, s1)
      fields(s, year, mon, day, hour, minute, second, decimal(d0) && decimal(d1) && decimal(y0) && decimal(y1) && decimal(y2) && decimal(y3) && decimal(h0) && decimal(h1) && decimal(n0) && decimal(n1) && decimal(s0) && decimal(s1) && U32.is_ge(year, 1970) && U32.is_le(year, 9999) && U32.is_ge(mon, 1) && U32.is_le(mon, 12) && U32.is_ge(day, 1) && U32.is_le(day, 31) && U32.is_lt(hour, 24) && U32.is_lt(minute, 60) && U32.is_lt(second, 60))
    case _: None{}
