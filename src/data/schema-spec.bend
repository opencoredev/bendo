# Independent specification of scalar schema acceptance (BND-33).
#
# Every rule here is restated from docs/data/schema.md. The module imports Base,
# the JSON value type, and the schema and pattern modules for their data types
# only. It calls none of their functions, so the law equating `Schema.decode`
# with `satisfies` checks the decoder against these definitions rather than
# against itself. Nothing here is meant to be fast: numbers compare as exact
# natural numbers and patterns try every way to split the text.
import Base
import ./json.bend as J
import ./schema.bend as S
import ./schema-pattern.bend as P

# Characters and text.

def same(+c: U32, x: U32) -> Bool:
  U32.is_eq(c, x)

def within(+c: U32, lo: U32, hi: U32) -> Bool:
  (c >= lo : U32) && (c <= hi : U32)

def one_of(+c: U32, codes: List<&2, U32>) -> Bool:
  match codes:
    case Nil{}: False{}
    case x <> t: same(c, x) || one_of(c, t)

def digit(+c: U32) -> Bool:
  within(c, 48, 57)

def letter(+c: U32) -> Bool:
  within(c, 65, 90) || within(c, 97, 122)

def alnum(+c: U32) -> Bool:
  letter(c) || digit(c)

def hex(+c: U32) -> Bool:
  digit(c) || within(c, 65, 70) || within(c, 97, 102)

# A Unicode scalar value is at most U+10FFFF and is not a surrogate.
def scalar(+c: U32) -> Bool:
  (c <= 1114111 : U32) && Bool.not(within(c, 55296, 57343))

def scalars(s: String) -> Bool:
  match s:
    case SNil{}: True{}
    case SCon{Chr{c}, t}: scalar(c) && scalars(t)

# Bend strings hold one Char per Unicode scalar, so this counts scalars.
def length(s: String) -> Nat:
  match s:
    case SNil{}: 0n
    case SCon{c, t}: 1n+length(t)

def digits(s: String) -> Bool:
  match s:
    case SNil{}: True{}
    case SCon{Chr{c}, t}: digit(c) && digits(t)

def at_most(limit: Maybe<&2, Nat>, n: Nat) -> Bool:
  match limit:
    case None{}: True{}
    case Some{k}: Nat.is_le(n, k)

# RFC 8259 numbers:
#   number = [ "-" ] int [ frac ] [ exp ]
#   int    = "0" / digit1-9 *DIGIT
#   frac   = "." 1*DIGIT
#   exp    = ( "e" / "E" ) [ "-" / "+" ] 1*DIGIT
# Each recognizer reads its part at the front of the text, then what follows.

def skip_digits(s: String) -> String:
  match s:
    case SNil{}: ""
    case SCon{Chr{+c}, +t}: Bool.pick(String, digit(c), skip_digits(t), SCon{Chr{c}, t})

# 1*DIGIT, then the end.
def exponent_digits(s: String) -> Bool:
  match s:
    case SNil{}: False{}
    case SCon{Chr{c}, t}: digit(c) && digits(t)

# [ "-" / "+" ] 1*DIGIT, then the end.
def exponent_body(s: String) -> Bool:
  match s:
    case SNil{}: False{}
    case SCon{Chr{+c}, +t}: Bool.pick(Bool, same(c, 45) || same(c, 43), exponent_digits(t), exponent_digits(SCon{Chr{c}, t}))

# [ exp ], then the end.
def optional_exponent(s: String) -> Bool:
  match s:
    case SNil{}: True{}
    case SCon{Chr{+c}, t}: (same(c, 101) || same(c, 69)) && exponent_body(t)

# What follows ".": 1*DIGIT [ exp ].
def fraction(s: String) -> Bool:
  match s:
    case SNil{}: False{}
    case SCon{Chr{c}, t}: digit(c) && optional_exponent(skip_digits(t))

# What follows int: [ frac ] [ exp ].
def after_int(s: String) -> Bool:
  match s:
    case SNil{}: True{}
    case SCon{Chr{+c}, +t}: Bool.pick(Bool, same(c, 46), fraction(t), optional_exponent(SCon{Chr{c}, t}))

# int [ frac ] [ exp ].
def unsigned(s: String) -> Bool:
  match s:
    case SNil{}: False{}
    case SCon{Chr{+c}, +t}: Bool.pick(Bool, same(c, 48), after_int(t), within(c, 49, 57) && after_int(skip_digits(t)))

def number(s: String) -> Bool:
  match s:
    case SNil{}: False{}
    case SCon{Chr{+c}, +t}: Bool.pick(Bool, same(c, 45), unsigned(t), unsigned(SCon{Chr{c}, t}))

# Integer tokens are lexical: [ "-" ] int with no fraction or exponent.
def unsigned_integer(s: String) -> Bool:
  match s:
    case SNil{}: False{}
    case SCon{Chr{+c}, +t}: Bool.pick(Bool, same(c, 48), String.is_empty(t), within(c, 49, 57) && digits(t))

def integer(s: String) -> Bool:
  match s:
    case SNil{}: False{}
    case SCon{Chr{+c}, +t}: Bool.pick(Bool, same(c, 45), unsigned_integer(t), unsigned_integer(SCon{Chr{c}, t}))

# Exact decimal values. A number token denotes
#   (-1)^negative * digits * 10^(+exponent) / 10^scale       or
#   (-1)^negative * digits * 10^0 / 10^(scale + exponent)    with a negative exponent,
# where digits are the integer and fraction digits read as one natural number
# and scale is the number of fraction digits.

type Parts is Data:
  Parts{negative: Bool, digits: String, scale: Nat, exponent_negative: Bool, exponent: String}

type Exponent is Data:
  Exponent{negative: Bool, digits: String}

def take_digits(s: String) -> String:
  match s:
    case SNil{}: ""
    case SCon{Chr{+c}, +t}: Bool.pick(String, digit(c), SCon{Chr{c}, take_digits(t)}, "")

# Text after the integer digits: the fraction digits, if any.
def fraction_digits(s: String) -> String:
  match s:
    case SNil{}: ""
    case SCon{Chr{+c}, +t}: Bool.pick(String, same(c, 46), take_digits(t), "")

# Text after the integer digits: what follows the fraction, if any.
def after_fraction(s: String) -> String:
  match s:
    case SNil{}: ""
    case SCon{Chr{+c}, +t}: Bool.pick(String, same(c, 46), skip_digits(t), SCon{Chr{c}, t})

# What follows "e" or "E".
def signed_exponent(s: String) -> Exponent:
  match s:
    case SNil{}: Exponent{False{}, ""}
    case SCon{Chr{+c}, +t}: Bool.pick(Exponent, same(c, 45), Exponent{True{}, t}, Bool.pick(Exponent, same(c, 43), Exponent{False{}, t}, Exponent{False{}, SCon{Chr{c}, t}}))

# Text after the fraction: nothing, or "e"/"E" and the exponent.
def exponent(s: String) -> Exponent:
  match s:
    case SNil{}: Exponent{False{}, ""}
    case SCon{c, t}: signed_exponent(t)

def assemble(negative: Bool, whole: String, +frac: String, e: Exponent) -> Parts:
  Exponent{en, x} = e
  Parts{negative, whole ++ frac, length(frac), en, x}

def unsigned_parts(negative: Bool, +s: String) -> Parts:
  +rest = skip_digits(s)
  assemble(negative, take_digits(s), fraction_digits(rest), exponent(after_fraction(rest)))

def parts(s: String) -> Parts:
  match s:
    case SNil{}: unsigned_parts(False{}, "")
    case SCon{Chr{+c}, +t}: Bool.pick(Parts, same(c, 45), unsigned_parts(True{}, t), unsigned_parts(False{}, SCon{Chr{c}, t}))

def digit_value(c: U32) -> Nat:
  Nat.sub(U32.to_nat(c), 48n)

# Decimal digits read most significant first, after an accumulated prefix.
def value(s: String, acc: Nat) -> Nat:
  match s:
    case SNil{}: acc
    case SCon{Chr{c}, t}: value(t, Nat.add(Nat.mul(acc, 10n), digit_value(c)))

def up(p: Parts) -> Nat:
  Parts{n, d, k, e, x} = p
  Bool.pick(Nat, e, 0n, value(x, 0n))

def down(p: Parts) -> Nat:
  Parts{n, d, k, e, x} = p
  Bool.pick(Nat, e, value(x, 0n), 0n)

def scale(p: Parts) -> Nat:
  Parts{n, d, k, e, x} = p
  k

def magnitude(p: Parts) -> Nat:
  Parts{n, d, k, e, x} = p
  value(d, 0n)

# |a| = Ma * 10^up(a) / 10^(scale(a) + down(a)), likewise for b. Multiplying
# both by both denominators compares naturals.
def magnitude_cmp(+a: Parts, +b: Parts) -> Cmp:
  Nat.cmp(Nat.mul(magnitude(a), Nat.pow(10n, (up(a) + scale(b) + down(b) : Nat))), Nat.mul(magnitude(b), Nat.pow(10n, (up(b) + scale(a) + down(a) : Nat))))

# Negative zero is zero.
def below_zero(+p: Parts) -> Bool:
  Parts{n, d, k, e, x} = p
  n && Bool.not(Nat.is_eq(magnitude(p), 0n))

def signed_cmp(+a: Parts, +b: Parts, sa: Bool, sb: Bool) -> Cmp:
  match sa sb:
    case False{} False{}: magnitude_cmp(a, b)
    case True{} True{}: magnitude_cmp(b, a)
    case True{} False{}: LT{}
    case False{} True{}: GT{}

# Numerical order of two valid number tokens.
def order(x: String, y: String) -> Cmp:
  +a = parts(x)
  +b = parts(y)
  signed_cmp(a, b, below_zero(a), below_zero(b))

# Patterns denote regular languages over Unicode scalars.

def in_class(rs: List<&2, P.Range>, +c: U32) -> Bool:
  match rs:
    case Nil{}: False{}
    case P.Range{lo, hi} <> t: within(c, lo, hi) || in_class(t, c)

def ascii_ranges(rs: List<&2, P.Range>) -> Bool:
  match rs:
    case Nil{}: True{}
    case P.Range{+lo, +hi} <> t: (lo <= hi : U32) && (hi <= 127 : U32) && ascii_ranges(t)

# How many copies of its body a repetition writes out: r{m,n} is n copies and
# r{m,} is m copies plus the one that repeats.
def copies(m: Nat, n: Maybe<&2, Nat>) -> Nat:
  match n:
    case None{}: 1n+m
    case Some{k}: k

# The node count once every repetition is written out as its copies.
def expanded(p: P.Pattern) -> Nat:
  match p:
    case P.Literal{x}: 1n+length(x)
    case P.Class{rs}: 1n
    case P.Cat{a, b}: 1n+Nat.add(expanded(a), expanded(b))
    case P.Repeat{r, m, n}: 1n+Nat.mul(copies(m, n), expanded(r))

# The largest expanded size and copy count a valid pattern may have anywhere.
def pattern_limit() -> Nat:
  128n

def fits(p: P.Pattern) -> Bool:
  Nat.is_le(expanded(p), pattern_limit())

def pattern_ok(p: P.Pattern) -> Bool:
  match p:
    case P.Literal{+x}: scalars(x) && fits(P.Literal{x})
    case P.Class{+rs}: ascii_ranges(rs) && fits(P.Class{rs})
    case P.Cat{+a, +b}: pattern_ok(a) && pattern_ok(b) && fits(P.Cat{a, b})
    case P.Repeat{+r, +m, +n}: pattern_ok(r) && at_most(n, m) && Nat.is_le(copies(m, n), pattern_limit()) && fits(P.Repeat{r, m, n})

type Lang is Data:
  LNone{}
  LEmpty{}
  LText{text: String}
  LOne{ranges: List<&2, P.Range>}
  LNonEmpty{body: Lang}
  LCat{first: Lang, second: Lang}
  LOr{left: Lang, right: Lang}

# l repeated exactly j times.
def power(+l: Lang, j: Nat) -> Lang:
  match j:
    case 0n: LEmpty{}
    case 1n+i: LCat{l, power(l, i)}

# l repeated j times, for every j with m <= j <= n.
def counts(+l: Lang, +m: Nat, n: Nat) -> Lang:
  match n:
    case 0n: Bool.pick(Lang, Nat.is_eq(m, 0n), LEmpty{}, LNone{})
    case 1n+(+k): LOr{counts(l, m, k), Bool.pick(Lang, Nat.is_le(m, 1n+k), power(l, 1n+k), LNone{})}

def repeat(+l: Lang, m: Nat, n: Maybe<&2, Nat>, bound: Nat) -> Lang:
  match n:
    case Some{k}: counts(l, m, k)
    case None{}: LCat{power(l, m), counts(LNonEmpty{l}, 0n, bound)}

# The language of a pattern, for words of at most `bound` scalars.
# r{m,n} is the union of r^j for m <= j <= n. r{m,} is r^m followed by any
# number of nonempty r-words; each consumes a scalar, so a word of at most
# `bound` scalars needs at most `bound` of them.
def lang(p: P.Pattern, +bound: Nat) -> Lang:
  match p:
    case P.Literal{x}: LText{x}
    case P.Class{rs}: LOne{rs}
    case P.Cat{a, b}: LCat{lang(a, bound), lang(b, bound)}
    case P.Repeat{r, m, n}: repeat(lang(r, bound), m, n, bound)

def one(rs: List<&2, P.Range>, w: String) -> Bool:
  match w:
    case SCon{Chr{c}, SNil{}}: in_class(rs, c)
    case _: False{}

# Does w belong to l? In a sequence, k is the last split point still to try,
# so callers pass the length of w and every split w = take(k) ++ drop(k) is tried.
def mem(+l: Lang, +k: Nat, +w: String) -> Bool:
  match l:
    case LNone{}: False{}
    case LEmpty{}: String.is_empty(w)
    case LText{x}: String.eq(x, w)
    case LOne{rs}: one(rs, w)
    case LNonEmpty{a}: Bool.not(String.is_empty(w)) && mem(a, k, w)
    case LOr{a, b}: mem(a, k, w) || mem(b, k, w)
    case LCat{+a, +b}:
      match k:
        case 0n: mem(a, 0n, "") && mem(b, length(w), w)
        case 1n+(+i): (mem(a, 1n+i, String.take(w, 1n+i)) && mem(b, length(String.drop(w, 1n+i)), String.drop(w, 1n+i))) || mem(LCat{a, b}, i, w)

# The whole of w matches p.
def matches(p: P.Pattern, +w: String) -> Bool:
  mem(lang(p, length(w)), length(w), w)

# Formats.

def push(c: U32, pieces: List<&2, String>) -> List<&2, String>:
  match pieces:
    case Nil{}: [SCon{Chr{c}, ""}]
    case h <> t: SCon{Chr{c}, h} <> t

def cut(here: Bool, c: U32, pieces: List<&2, String>) -> List<&2, String>:
  match here:
    case True{}: "" <> pieces
    case False{}: push(c, pieces)

# The pieces between separators: "a.b" is ["a", "b"], "" is [""], "." is ["", ""].
def split(s: String, +sep: U32) -> List<&2, String>:
  match s:
    case SNil{}: [""]
    case SCon{Chr{+c}, t}: cut(same(c, sep), c, split(t, sep))

def label_chars(s: String) -> Bool:
  match s:
    case SNil{}: True{}
    case SCon{Chr{+c}, t}: (alnum(c) || same(c, 45)) && label_chars(t)

def first_alnum(s: String) -> Bool:
  match s:
    case SNil{}: False{}
    case SCon{Chr{c}, t}: alnum(c)

def last_alnum(s: String) -> Bool:
  match s:
    case SNil{}: False{}
    case SCon{Chr{c}, SNil{}}: alnum(c)
    case SCon{c, t}: last_alnum(t)

# A DNS label: 1 to 63 letters, digits or hyphens, starting and ending alphanumeric.
def label(+l: String) -> Bool:
  Nat.is_le(1n, length(l)) && Nat.is_le(length(l), 63n) && label_chars(l) && first_alnum(l) && last_alnum(l)

def labels(ls: List<&2, String>) -> Bool:
  match ls:
    case Nil{}: True{}
    case l <> t: label(l) && labels(t)

# One or more dot-separated labels, at most 253 scalars in all.
def hostname(+h: String) -> Bool:
  Nat.is_le(length(h), 253n) && labels(split(h, 46))

# Letters, digits, and !#$%&'*+-/=?^_`{|}~
def atom_char(+c: U32) -> Bool:
  alnum(c) || one_of(c, [33, 35, 36, 37, 38, 39, 42, 43, 45, 47, 61, 63, 94, 95, 96, 123, 124, 125, 126])

def atom(s: String) -> Bool:
  match s:
    case SNil{}: True{}
    case SCon{Chr{c}, t}: atom_char(c) && atom(t)

def atoms(ps: List<&2, String>) -> Bool:
  match ps:
    case Nil{}: True{}
    case +p <> t: Bool.not(String.is_empty(p)) && atom(p) && atoms(t)

# Nonempty atoms separated by single dots, at most 64 scalars.
def dot_atom(+s: String) -> Bool:
  Nat.is_le(length(s), 64n) && atoms(split(s, 46))

# Text before the first scalar in codes (all of s if there is none).
def before(s: String, +codes: List<&2, U32>) -> String:
  match s:
    case SNil{}: ""
    case SCon{Chr{+c}, t}: Bool.pick(String, one_of(c, codes), "", SCon{Chr{c}, before(t, codes)})

# The first scalar in codes and everything after it ("" if there is none).
def from(s: String, +codes: List<&2, U32>) -> String:
  match s:
    case SNil{}: ""
    case SCon{Chr{+c}, +t}: Bool.pick(String, one_of(c, codes), SCon{Chr{c}, t}, from(t, codes))

def email_domain(local: String, rest: String) -> Bool:
  match rest:
    case SNil{}: False{}
    case SCon{at, domain}: dot_atom(local) && hostname(domain)

# local "@" hostname, where local is the text before the first "@".
def email(+s: String) -> Bool:
  Nat.is_le(length(s), 254n) && email_domain(before(s, [64]), from(s, [64]))

def strip(prefix: String, s: String) -> Maybe<&2, String>:
  match prefix s:
    case SNil{} s: Some{s}
    case SCon{Chr{x}, p} SCon{Chr{y}, t}: Bool.pick(Maybe<&2, String>, same(x, y), strip(p, t), None{})
    case _ _: None{}

# Letters, digits, and -._~:/?#[]@!$&'()*+,;=
def uri_char(+c: U32) -> Bool:
  alnum(c) || one_of(c, [45, 46, 95, 126, 58, 47, 63, 35, 91, 93, 64, 33, 36, 38, 39, 40, 41, 42, 43, 44, 59, 61])

# URI characters and "%" with two hex digits. `due` counts hex digits owed.
def suffix(s: String, due: Nat) -> Bool:
  match s:
    case SNil{}: Nat.is_eq(due, 0n)
    case SCon{Chr{+c}, +t}:
      match due:
        case 0n: Bool.pick(Bool, same(c, 37), suffix(t, 2n), uri_char(c) && suffix(t, 0n))
        case 1n+k: hex(c) && suffix(t, k)

# 1 to 5 digits with a value of at most 65535.
def port(+p: String) -> Bool:
  Nat.is_le(1n, length(p)) && Nat.is_le(length(p), 5n) && digits(p) && Nat.is_le(value(p, 0n), 65535n)

# After the host: nothing, ":" port, or a path, query or fragment.
def after_host(s: String) -> Bool:
  match s:
    case SNil{}: True{}
    case SCon{Chr{+c}, +t}: Bool.pick(Bool, same(c, 58), port(before(t, [47, 63, 35])) && suffix(from(t, [47, 63, 35]), 0n), suffix(SCon{Chr{c}, t}, 0n))

def authority(rest: Maybe<&2, String>) -> Bool:
  match rest:
    case None{}: False{}
    case Some{+x}: hostname(before(x, [58, 47, 63, 35])) && after_host(from(x, [58, 47, 63, 35]))

def url(+s: String) -> Bool:
  authority(strip("http://", s)) || authority(strip("https://", s))

def format(f: S.Format, +s: String) -> Bool:
  match f:
    case S.Plain{}: True{}
    case S.Email{}: email(s)
    case S.Url{}: url(s)

def pattern(p: Maybe<&2, P.Pattern>, +s: String) -> Bool:
  match p:
    case None{}: True{}
    case Some{x}: matches(x, s)

# Schemas and values.

def bound(b: Maybe<&2, String>) -> Bool:
  match b:
    case None{}: True{}
    case Some{x}: number(x)

def ordered(min: Maybe<&2, String>, max: Maybe<&2, String>) -> Bool:
  match min max:
    case Some{a} Some{b}: Cmp.is_le(order(a, b))
    case _ _: True{}

def at_least_number(min: Maybe<&2, String>, x: String) -> Bool:
  match min:
    case None{}: True{}
    case Some{m}: Cmp.is_ge(order(x, m))

def at_most_number(max: Maybe<&2, String>, x: String) -> Bool:
  match max:
    case None{}: True{}
    case Some{m}: Cmp.is_le(order(x, m))

# Literal and enum members are JSON scalars: null, booleans, well-formed
# strings and valid number tokens.
def literal_value(v: J.Json) -> Bool:
  match v:
    case J.JNull{}: True{}
    case J.JBool{b}: True{}
    case J.JString{x}: scalars(x)
    case J.JNumber{x}: number(x)
    case _: False{}

def literal_values(xs: List<&2, J.Json>) -> Bool:
  match xs:
    case Nil{}: True{}
    case h <> t: literal_value(h) && literal_values(t)

def optional_pattern_ok(p: Maybe<&2, P.Pattern>) -> Bool:
  match p:
    case None{}: True{}
    case Some{x}: pattern_ok(x)

def schema_ok(s: S.Schema) -> Bool:
  match s:
    case S.StringSchema{+min, max, p, f}: at_most(max, min) && optional_pattern_ok(p)
    case S.NumberSchema{+min, +max}: bound(min) && bound(max) && ordered(min, max)
    case S.IntegerSchema{+min, +max}: bound(min) && bound(max) && ordered(min, max)
    case S.BooleanSchema{}: True{}
    case S.LiteralSchema{v}: literal_value(v)
    case S.EnumSchema{xs}: literal_values(xs)

# Strings and booleans compare by value, numbers numerically.
def equal(a: J.Json, b: J.Json) -> Bool:
  match a b:
    case J.JNull{} J.JNull{}: True{}
    case J.JBool{True{}} J.JBool{True{}}: True{}
    case J.JBool{False{}} J.JBool{False{}}: True{}
    case J.JString{x} J.JString{y}: String.eq(x, y)
    case J.JNumber{x} J.JNumber{y}: Cmp.is_eq(order(x, y))
    case _ _: False{}

def any_equal(xs: List<&2, J.Json>, +v: J.Json) -> Bool:
  match xs:
    case Nil{}: False{}
    case h <> t: equal(h, v) || any_equal(t, v)

def accepts(s: S.Schema, v: J.Json) -> Bool:
  match s v:
    case S.StringSchema{min, max, p, f} J.JString{+x}: scalars(x) && Nat.is_le(min, length(x)) && at_most(max, length(x)) && pattern(p, x) && format(f, x)
    case S.NumberSchema{min, max} J.JNumber{+x}: number(x) && at_least_number(min, x) && at_most_number(max, x)
    case S.IntegerSchema{min, max} J.JNumber{+x}: integer(x) && at_least_number(min, x) && at_most_number(max, x)
    case S.BooleanSchema{} J.JBool{b}: True{}
    case S.LiteralSchema{l} +v: literal_value(v) && equal(l, v)
    case S.EnumSchema{xs} +v: literal_value(v) && any_equal(xs, v)
    case _ _: False{}

# A schema accepts a value when the schema is well formed and the value meets it.
def satisfies(+s: S.Schema, v: J.Json) -> Bool:
  schema_ok(s) && accepts(s, v)
