# Byte range requests (RFC 9110 section 14). Pure. `select` reads one Range
# field value against a representation length. Only a single range is
# served; a list of ranges, another unit or a malformed value is ignored and
# the whole file is sent with 200, which RFC 9110 permits.
import Base
import ../router/encoding.bend as E
import ../http/text.bend as Text

type Range is Data:
  Whole{}
  # Inclusive byte positions, first <= last < length.
  Part{first: Nat, last: Nat}
  Unsatisfiable{}

type Spec is Data:
  Bounded{first: Nat, last: Nat}
  From{first: Nat}
  Suffix{length: Nat}
  Ignored{}

# Larger positions saturate here. Served files are below 4 GiB (the open
# effect refuses larger ones), so a saturated position compares the same.
def cap() -> Nat: 4294967295n

def saturate(+n: Nat) -> Nat:
  E.choose(Nat, Nat.is_lt(n, cap()), u => n, u => cap())

def push_digit(+acc: Nat, +code: U32) -> Nat:
  saturate(Nat.add(Nat.mul(acc, 10n), U32.to_nat(U32.sub(code, 48))))

type Num is Data:
  Num{value: Maybe<&2, Nat>, rest: String}

def seen_value(seen: Bool, acc: Nat) -> Maybe<&2, Nat>:
  match seen:
    case True{}: Some{acc}
    case False{}: None{}

def digits(s: String, +acc: Nat, +seen: Bool) -> Num:
  match s:
    case SNil{}: Num{seen_value(seen, acc), SNil{}}
    case SCon{+c, +t}:
      E.choose(Num, Char.is_digit(c), u => digits(t, push_digit(acc, Char.to_u32(c)), True{}), u => Num{seen_value(seen, acc), SCon{c, t}})

def is_dash(c: Char) -> Bool:
  Char.is_eq(c, '-')

def after_dash(first: Nat, n: Num) -> Spec:
  match n:
    case Num{None{}, SNil{}}: From{first}
    case Num{Some{last}, SNil{}}: Bounded{first, last}
    case _: Ignored{}

def dash_rest(first: Nat, s: String) -> Spec:
  match s:
    case SNil{}: Ignored{}
    case SCon{+c, t}:
      E.choose(Spec, is_dash(c), u => after_dash(first, digits(t, 0n, False{})), u => Ignored{})

def first_part(n: Num) -> Spec:
  match n:
    case Num{Some{first}, rest}: dash_rest(first, rest)
    case Num{None{}, rest}: Ignored{}

def suffix(n: Num) -> Spec:
  match n:
    case Num{Some{length}, SNil{}}: Suffix{length}
    case _: Ignored{}

def spec_lead(c: Char, t: String, dash: Bool) -> Spec:
  match dash:
    case True{}: suffix(digits(t, 0n, False{}))
    case False{}: first_part(digits(SCon{c, t}, 0n, False{}))

def spec(s: String) -> Spec:
  match s:
    case SNil{}: Ignored{}
    case SCon{+c, t}: spec_lead(c, t, is_dash(c))

def unit_rest(+lower: String, ok: Bool) -> Spec:
  match ok:
    case False{}: Ignored{}
    case True{}:
      +set = String.trim(String.drop(lower, 6n))
      E.choose(Spec, String.contains(set, ","), u => Ignored{}, u => spec(set))

# The unit is case-insensitive. Optional whitespace around the value is
# trimmed.
def parse(value: String) -> Spec:
  +lower = Text.lower(String.trim(value))
  unit_rest(lower, String.starts_with(lower, "bytes="))

def pick_last(+last: Nat, +length: Nat) -> Nat:
  E.choose(Nat, Nat.is_lt(last, length), u => last, u => Nat.sub(length, 1n))

def from_first(+first: Nat, +length: Nat) -> Range:
  E.choose(Range, Nat.is_lt(first, length), u => Part{first, Nat.sub(length, 1n)}, u => Unsatisfiable{})

def bounded(+first: Nat, +last: Nat, +length: Nat) -> Range:
  E.choose(Range, Nat.is_lt(last, first), u => Whole{}, u => (
    E.choose(Range, Nat.is_lt(first, length), u => Part{first, pick_last(last, length)}, u => Unsatisfiable{})
  ))

def suffix_range(+n: Nat, +length: Nat) -> Range:
  E.choose(Range, Nat.is_eq(n, 0n) || Nat.is_eq(length, 0n), u => Unsatisfiable{}, u => (
    E.choose(Range, Nat.is_lt(n, length), u => Part{Nat.sub(length, n), Nat.sub(length, 1n)}, u => Part{0n, Nat.sub(length, 1n)})
  ))

# What to send for a parsed range and a representation length.
def decide(s: Spec, +length: Nat) -> Range:
  match s:
    case Bounded{+first, +last}: bounded(first, last, length)
    case From{+first}: from_first(first, length)
    case Suffix{+n}: suffix_range(n, length)
    case Ignored{}: Whole{}

def select(value: Maybe<&2, String>, +length: Nat) -> Range:
  match value:
    case None{}: Whole{}
    case Some{v}: decide(parse(v), length)
