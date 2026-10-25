# Independent specification of schema acceptance (BND-33 scalars, BND-34
# arrays, objects, nullables and unions, BND-35 defaults, error locations and
# coercion).
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

# A pattern is measured only once its parts and counts are valid, so the
# expansion never multiplies an unchecked count.
def sized(ok: Bool, p: P.Pattern) -> Bool:
  match ok:
    case False{}: False{}
    case True{}: fits(p)

def pattern_ok(p: P.Pattern) -> Bool:
  match p:
    case P.Literal{+x}: sized(scalars(x), P.Literal{x})
    case P.Class{+rs}: sized(ascii_ranges(rs), P.Class{rs})
    case P.Cat{+a, +b}: sized(pattern_ok(a) && pattern_ok(b), P.Cat{a, b})
    case P.Repeat{+r, +m, +n}: sized(pattern_ok(r) && at_most(n, m) && Nat.is_le(copies(m, n), pattern_limit()), P.Repeat{r, m, n})

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

def declares(fs: List<&2, S.Field>, +k: String) -> Bool:
  match fs:
    case Nil{}: False{}
    case S.Field{key, c, p} <> t: String.eq(key, k) || declares(t, k)

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

# Compound schemas (BND-34).

def size(xs: List<&2, J.Json>) -> Nat:
  match xs:
    case Nil{}: 0n
    case h <> t: 1n+size(t)

def bump(same: Bool, n: Nat) -> Nat:
  match same:
    case True{}: 1n+n
    case False{}: n

# How many members of an object have this key. Bendo's JSON keeps duplicates.
def named(input: List<&2, J.Field>, +k: String) -> Nat:
  match input:
    case Nil{}: 0n
    case J.Field{key, v} <> t: bump(String.eq(key, k), named(t, k))

# A required key appears exactly once, an optional or defaulted key at most
# once. An absent Default field stands for its value, which schema_ok checks.
def presence(p: S.Presence, +n: Nat) -> Bool:
  match p:
    case S.Required{}: Nat.is_eq(n, 1n)
    case S.Optional{}: Nat.is_le(n, 1n)
    case S.Default{d}: Nat.is_le(n, 1n)

def all_declared(input: List<&2, J.Field>, +fs: List<&2, S.Field>) -> Bool:
  match input:
    case Nil{}: True{}
    case J.Field{k, v} <> t: declares(fs, k) && all_declared(t, fs)

# Strict objects have no undeclared key; Strip ignores undeclared keys,
# including repeated ones.
def allowed(u: S.Unknown, +fs: List<&2, S.Field>, input: List<&2, J.Field>) -> Bool:
  match u:
    case S.Strict{}: all_declared(input, fs)
    case S.Strip{}: True{}

# What `meets(s, ask, v)` asks of the value v against the schema s.
type Ask is Data:
  # v satisfies s.
  Holds{}
  # v is an array and every item meets `ask` against s.
  EveryItem{ask: Ask}
  # v is an object and every member named `key` meets `ask` against s.
  EveryNamed{key: String, ask: Ask}
  # v is an object meeting every declared field of the object schema s.
  EveryField{}

# A value satisfies:
# - a scalar schema when `accepts` says so;
# - ArraySchema{i, min, max} when it is an array of min to max items (max
#   None: no limit), each satisfying i;
# - ObjectSchema{fs, u} when it is an object whose keys `allowed` permits and,
#   for each declared Field{k, c, p}, the members named k number as `presence`
#   requires and each satisfies c;
# - NullableSchema{i} when it is null or satisfies i;
# - UnionSchema{ms} when it satisfies at least one member.
# The object rule checks its first field in the Holds case so that every
# recursive call is on a smaller schema or a shorter list.
def meets(s: S.Schema, ask: Ask, v: J.Json) -> Bool:
  match s ask v:
    case S.StringSchema{a, b, c, d} Holds{} x: accepts(S.StringSchema{a, b, c, d}, x)
    case S.NumberSchema{a, b} Holds{} x: accepts(S.NumberSchema{a, b}, x)
    case S.IntegerSchema{a, b} Holds{} x: accepts(S.IntegerSchema{a, b}, x)
    case S.BooleanSchema{} Holds{} x: accepts(S.BooleanSchema{}, x)
    case S.LiteralSchema{a} Holds{} x: accepts(S.LiteralSchema{a}, x)
    case S.EnumSchema{a} Holds{} x: accepts(S.EnumSchema{a}, x)
    case S.ArraySchema{i, +min, max} Holds{} J.JArray{+xs}: Nat.is_le(min, size(xs)) && at_most(max, size(xs)) && meets(i, EveryItem{Holds{}}, J.JArray{xs})
    case S.ObjectSchema{Nil{}, u} Holds{} J.JObject{input}: allowed(u, [], input)
    case S.ObjectSchema{S.Field{+k, +c, +p} <> +t, +u} Holds{} J.JObject{+input}: allowed(u, S.Field{k, c, p} <> t, input) && (presence(p, named(input, k)) && meets(c, EveryNamed{k, Holds{}}, J.JObject{input}) && meets(S.ObjectSchema{t, u}, EveryField{}, J.JObject{input}))
    case S.ObjectSchema{Nil{}, u} EveryField{} J.JObject{input}: True{}
    case S.ObjectSchema{S.Field{+k, c, p} <> t, u} EveryField{} J.JObject{+input}: presence(p, named(input, k)) && meets(c, EveryNamed{k, Holds{}}, J.JObject{input}) && meets(S.ObjectSchema{t, u}, EveryField{}, J.JObject{input})
    case S.NullableSchema{i} Holds{} J.JNull{}: True{}
    case S.NullableSchema{i} Holds{} x: meets(i, Holds{}, x)
    case S.UnionSchema{Nil{}} Holds{} x: False{}
    case S.UnionSchema{m <> t} Holds{} +x: meets(m, Holds{}, x) || meets(S.UnionSchema{t}, Holds{}, x)
    case i EveryItem{a} J.JArray{Nil{}}: True{}
    case +i EveryItem{+a} J.JArray{h <> t}: meets(i, a, h) && meets(i, EveryItem{a}, J.JArray{t})
    case c EveryNamed{k, a} J.JObject{Nil{}}: True{}
    case +c EveryNamed{+k, +a} J.JObject{J.Field{key, x} <> t}: (Bool.not(String.eq(key, k)) || meets(c, a, x)) && meets(c, EveryNamed{k, a}, J.JObject{t})
    case _ _ _: False{}

# A Default field's value meets the field's schema.
def default_fits(c: S.Schema, p: S.Presence) -> Bool:
  match p:
    case S.Required{}: True{}
    case S.Optional{}: True{}
    case S.Default{d}: meets(c, Holds{}, d)

# Every part is well formed. Declared keys are well-formed text and distinct,
# and every default meets its field's schema.
def schema_ok(s: S.Schema) -> Bool:
  match s:
    case S.StringSchema{+min, max, p, f}: at_most(max, min) && optional_pattern_ok(p)
    case S.NumberSchema{+min, +max}: bound(min) && bound(max) && ordered(min, max)
    case S.IntegerSchema{+min, +max}: bound(min) && bound(max) && ordered(min, max)
    case S.BooleanSchema{}: True{}
    case S.LiteralSchema{v}: literal_value(v)
    case S.EnumSchema{xs}: literal_values(xs)
    case S.ArraySchema{i, +min, max}: at_most(max, min) && schema_ok(i)
    case S.ObjectSchema{Nil{}, u}: True{}
    case S.ObjectSchema{S.Field{+k, +c, p} <> +t, u}: scalars(k) && Bool.not(declares(t, k)) && schema_ok(c) && default_fits(c, p) && schema_ok(S.ObjectSchema{t, u})
    case S.NullableSchema{i}: schema_ok(i)
    case S.UnionSchema{Nil{}}: True{}
    case S.UnionSchema{m <> t}: schema_ok(m) && schema_ok(S.UnionSchema{t})

# A schema accepts a value when the schema is well formed and the value meets it.
def satisfies(+s: S.Schema, v: J.Json) -> Bool:
  schema_ok(s) && meets(s, Holds{}, v)

# The immediate children of a value, each against its own schema: every
# array item against the item schema, every object member with a declared key
# against that field's schema, a non-null value against a nullable's inner
# schema, and the value against at least one union member. Scalars and
# mismatched kinds have no children here.
def all_items(+i: S.Schema, xs: List<&2, J.Json>) -> Bool:
  match xs:
    case Nil{}: True{}
    case h <> t: satisfies(i, h) && all_items(i, t)

def all_named(+c: S.Schema, +k: String, input: List<&2, J.Field>) -> Bool:
  match input:
    case Nil{}: True{}
    case J.Field{key, x} <> t: (Bool.not(String.eq(key, k)) || satisfies(c, x)) && all_named(c, k, t)

def all_fields(fs: List<&2, S.Field>, +input: List<&2, J.Field>) -> Bool:
  match fs:
    case Nil{}: True{}
    case S.Field{k, c, p} <> t: all_named(c, k, input) && all_fields(t, input)

def some_member(ms: List<&2, S.Schema>, +v: J.Json) -> Bool:
  match ms:
    case Nil{}: False{}
    case m <> t: satisfies(m, v) || some_member(t, v)

def children(s: S.Schema, v: J.Json) -> Bool:
  match s v:
    case S.ArraySchema{i, m, n} J.JArray{xs}: all_items(i, xs)
    case S.ObjectSchema{fs, u} J.JObject{input}: all_fields(fs, input)
    case S.NullableSchema{i} J.JNull{}: True{}
    case S.NullableSchema{i} x: satisfies(i, x)
    case S.UnionSchema{ms} x: some_member(ms, x)
    case _ _: True{}

# Error locations (BND-35).
#
# fault(s, v, path, Here{}) says that the specification finds a failing check
# at `path` inside v, read against s:
# - the empty path when v fails a scalar schema, when an array has the wrong
#   kind or item count, when an object has the wrong kind, and when no union
#   member accepts v;
# - [i, ...rest] inside an array of the right count, at item i;
# - [k] for a member named k under Strict when no field declares k;
# - [k] for a declared key k that appears a number of times its presence
#   forbids (a required key missing, any declared key repeated);
# - [k, ...rest] for a declared key k that appears exactly once, inside that
#   member.
# A nullable reads a non-null value against its inner schema. Nothing below a
# failed kind or count check, and nothing inside a union, is a location.

def ends(p: List<&2, S.PathPart>) -> Bool:
  match p:
    case Nil{}: True{}
    case h <> t: False{}

# The value of the first member named k, or null when there is none.
def member(input: List<&2, J.Field>, +k: String) -> J.Json:
  match input:
    case Nil{}: J.JNull{}
    case J.Field{key, y} <> t: Bool.pick(J.Json, String.eq(key, k), y, member(t, k))

# Under Strict, a member named k that no field declares.
def stray(u: S.Unknown, fs: List<&2, S.Field>, input: List<&2, J.Field>, +k: String, p: List<&2, S.PathPart>) -> Bool:
  match u:
    case S.Strict{}: Bool.not(declares(fs, k)) && Bool.not(Nat.is_eq(named(input, k), 0n)) && ends(p)
    case S.Strip{}: False{}

# A declared key appearing a number of times its presence forbids.
def miscount(pr: S.Presence, +n: Nat, p: List<&2, S.PathPart>) -> Bool:
  Bool.not(presence(pr, n)) && ends(p)

type Look is Data:
  # The path leads into v, read against s.
  Here{}
  # v is a suffix of an array whose first item has this index; s is the item schema.
  From{index: Nat}
  # v is an object; s holds the declared fields not yet looked at.
  Keyed{}

def fault(s: S.Schema, v: J.Json, path: List<&2, S.PathPart>, look: Look) -> Bool:
  match s v path look:
    case S.StringSchema{a, b, c, d} x Nil{} Here{}: Bool.not(accepts(S.StringSchema{a, b, c, d}, x))
    case S.NumberSchema{a, b} x Nil{} Here{}: Bool.not(accepts(S.NumberSchema{a, b}, x))
    case S.IntegerSchema{a, b} x Nil{} Here{}: Bool.not(accepts(S.IntegerSchema{a, b}, x))
    case S.BooleanSchema{} x Nil{} Here{}: Bool.not(accepts(S.BooleanSchema{}, x))
    case S.LiteralSchema{a} x Nil{} Here{}: Bool.not(accepts(S.LiteralSchema{a}, x))
    case S.EnumSchema{a} x Nil{} Here{}: Bool.not(accepts(S.EnumSchema{a}, x))
    case S.ArraySchema{i, +min, max} J.JArray{+xs} Nil{} Here{}: Bool.not(Nat.is_le(min, size(xs)) && at_most(max, size(xs)))
    case S.ArraySchema{i, min, max} x Nil{} Here{}: True{}
    case S.ArraySchema{i, +min, max} J.JArray{+xs} S.PathIndex{n} <> p Here{}: (Nat.is_le(min, size(xs)) && at_most(max, size(xs))) && fault(i, J.JArray{xs}, S.PathIndex{n} <> p, From{0n})
    case +i J.JArray{h <> t} S.PathIndex{+n} <> +p From{+k}: (Nat.is_eq(n, k) && fault(i, h, p, Here{})) || fault(i, J.JArray{t}, S.PathIndex{n} <> p, From{1n+k})
    case S.ObjectSchema{fs, u} J.JObject{input} Nil{} Here{}: False{}
    case S.ObjectSchema{fs, u} x Nil{} Here{}: True{}
    case S.ObjectSchema{Nil{}, u} J.JObject{input} S.PathKey{k} <> p Here{}: stray(u, [], input, k, p)
    case S.ObjectSchema{S.Field{+key, +c, +pr} <> +t, +u} J.JObject{+input} S.PathKey{+k} <> +p Here{}: stray(u, S.Field{key, c, pr} <> t, input, k, p) || (String.eq(key, k) && (miscount(pr, named(input, key), p) || (Nat.is_eq(named(input, key), 1n) && fault(c, member(input, key), p, Here{})))) || fault(S.ObjectSchema{t, u}, J.JObject{input}, S.PathKey{k} <> p, Keyed{})
    case S.ObjectSchema{S.Field{+key, c, pr} <> t, u} J.JObject{+input} S.PathKey{+k} <> +p Keyed{}: (String.eq(key, k) && (miscount(pr, named(input, key), p) || (Nat.is_eq(named(input, key), 1n) && fault(c, member(input, key), p, Here{})))) || fault(S.ObjectSchema{t, u}, J.JObject{input}, S.PathKey{k} <> p, Keyed{})
    case S.NullableSchema{i} J.JNull{} p Here{}: False{}
    case S.NullableSchema{i} x p Here{}: fault(i, x, p, Here{})
    case S.UnionSchema{ms} x Nil{} Here{}: Bool.not(meets(S.UnionSchema{ms}, Holds{}, x))
    case _ _ _ _: False{}

# An invalid schema is reported once, at the root.
def located(ok: Bool, s: S.Schema, v: J.Json, path: List<&2, S.PathPart>) -> Bool:
  match ok:
    case True{}: fault(s, v, path, Here{})
    case False{}: ends(path)

def error_at(+s: S.Schema, v: J.Json, path: List<&2, S.PathPart>) -> Bool:
  located(schema_ok(s), s, v, path)

# The most errors a report lists.
def error_cap() -> Nat:
  100n

def error_count(es: List<&2, S.Error>) -> Nat:
  match es:
    case Nil{}: 0n
    case e <> t: 1n+error_count(t)

def all_located(es: List<&2, S.Error>, +s: S.Schema, +v: J.Json) -> Bool:
  match es:
    case Nil{}: True{}
    case S.Error{c, m, p} <> t: error_at(s, v, p) && all_located(t, s, v)

# A rejection lists at least one error and at most error_cap(), and every one
# names a location where the specification finds a failing check.
def rejection_located(es: List<&2, S.Error>, +s: S.Schema, +v: J.Json) -> Bool:
  match es:
    case Nil{}: False{}
    case +e <> +t: Nat.is_le(error_count(e <> t), error_cap()) && all_located(e <> t, s, v)

def located_errors(+s: S.Schema, +v: J.Json, r: Result<&2, &2, S.Errors(), S.Value>) -> Bool:
  match r:
    case Done{x}: True{}
    case Fail{es}: rejection_located(es, s, v)

def same_path(a: List<&2, S.PathPart>, b: List<&2, S.PathPart>) -> Bool:
  match a b:
    case Nil{} Nil{}: True{}
    case S.PathKey{x} <> t S.PathKey{y} <> w: String.eq(x, y) && same_path(t, w)
    case S.PathIndex{x} <> t S.PathIndex{y} <> w: Nat.is_eq(x, y) && same_path(t, w)
    case _ _: False{}

def names(es: List<&2, S.Error>, +path: List<&2, S.PathPart>) -> Bool:
  match es:
    case Nil{}: False{}
    case S.Error{c, m, p} <> t: same_path(p, path) || names(t, path)

# A location is reported when the decoder rejects and lists an error with
# exactly that path, or has already listed error_cap() errors.
def reported(r: Result<&2, &2, S.Errors(), S.Value>, +path: List<&2, S.PathPart>) -> Bool:
  match r:
    case Done{x}: False{}
    case Fail{+es}: Nat.is_le(error_cap(), error_count(es)) || names(es, path)

# The exact error list (BND-89).
#
# failures(s, v, Node{}) lists every failure occurrence, in the order
# docs/data/schema.md documents, by its path:
# - one at the value itself when it fails a scalar schema, has the wrong kind
#   or array length, or matches no union member; nothing below such a value;
# - each array item's failures in item order, under the item's index;
# - in an object, under Strict, one per member whose key no field declares, in
#   input order, so a repeated undeclared key appears once per member; then
#   for each declared field in schema order: one at [k] when the key appears a
#   number of times its presence forbids, or the failures of its one member
#   under k;
# - a non-null value under a nullable, against the inner schema.
# The decoder reports the first error_cap() of them, or one error at the root
# for an invalid schema.

type Visit is Data:
  # v against s.
  Node{}
  # v is a suffix of an array whose first item has this index; s is the item schema.
  Items{index: Nat}
  # v is an object; s holds the declared fields not yet visited.
  Fields{}

def join(a: List<&2, List<&2, S.PathPart>>, b: List<&2, List<&2, S.PathPart>>) -> List<&2, List<&2, S.PathPart>>:
  match a:
    case Nil{}: b
    case p <> t: p <> join(t, b)

def under(+part: S.PathPart, ps: List<&2, List<&2, S.PathPart>>) -> List<&2, List<&2, S.PathPart>>:
  match ps:
    case Nil{}: []
    case p <> t: (part <> p) <> under(part, t)

# One failure at p unless the check passed.
def flag(ok: Bool, p: List<&2, S.PathPart>) -> List<&2, List<&2, S.PathPart>>:
  match ok:
    case True{}: []
    case False{}: [p]

# What lies below a container check: nothing when it fails, which counts as
# one failure at the container.
def below(ok: Bool, rest: List<&2, List<&2, S.PathPart>>) -> List<&2, List<&2, S.PathPart>>:
  match ok:
    case True{}: rest
    case False{}: [[]]

def undeclared(+fs: List<&2, S.Field>, input: List<&2, J.Field>) -> List<&2, List<&2, S.PathPart>>:
  match input:
    case Nil{}: []
    case J.Field{+k, v} <> t: join(flag(declares(fs, k), [S.PathKey{k}]), undeclared(fs, t))

def strays(u: S.Unknown, +fs: List<&2, S.Field>, input: List<&2, J.Field>) -> List<&2, List<&2, S.PathPart>>:
  match u:
    case S.Strict{}: undeclared(fs, input)
    case S.Strip{}: []

# A declared key k: its one member's failures, or one failure at [k] when it
# appears a number of times its presence forbids.
def field_failures(once: Bool, ok: Bool, k: String, inner: List<&2, List<&2, S.PathPart>>) -> List<&2, List<&2, S.PathPart>>:
  match once ok:
    case True{} b: inner
    case False{} True{}: []
    case False{} False{}: [[S.PathKey{k}]]

def failures(s: S.Schema, v: J.Json, visit: Visit) -> List<&2, List<&2, S.PathPart>>:
  match s v visit:
    case S.StringSchema{a, b, c, d} x Node{}: flag(accepts(S.StringSchema{a, b, c, d}, x), [])
    case S.NumberSchema{a, b} x Node{}: flag(accepts(S.NumberSchema{a, b}, x), [])
    case S.IntegerSchema{a, b} x Node{}: flag(accepts(S.IntegerSchema{a, b}, x), [])
    case S.BooleanSchema{} x Node{}: flag(accepts(S.BooleanSchema{}, x), [])
    case S.LiteralSchema{a} x Node{}: flag(accepts(S.LiteralSchema{a}, x), [])
    case S.EnumSchema{a} x Node{}: flag(accepts(S.EnumSchema{a}, x), [])
    case S.ArraySchema{i, +min, max} J.JArray{+xs} Node{}: below(Nat.is_le(min, size(xs)) && at_most(max, size(xs)), failures(i, J.JArray{xs}, Items{0n}))
    case S.ArraySchema{i, min, max} x Node{}: [[]]
    case i J.JArray{Nil{}} Items{k}: []
    case +i J.JArray{h <> t} Items{+k}: join(under(S.PathIndex{k}, failures(i, h, Node{})), failures(i, J.JArray{t}, Items{1n+k}))
    case S.ObjectSchema{Nil{}, u} J.JObject{input} Node{}: strays(u, [], input)
    case S.ObjectSchema{S.Field{+k, +c, +p} <> +t, +u} J.JObject{+input} Node{}: join(strays(u, S.Field{k, c, p} <> t, input), join(field_failures(Nat.is_eq(named(input, k), 1n), presence(p, named(input, k)), k, under(S.PathKey{k}, failures(c, member(input, k), Node{}))), failures(S.ObjectSchema{t, u}, J.JObject{input}, Fields{})))
    case S.ObjectSchema{fs, u} x Node{}: [[]]
    case S.ObjectSchema{Nil{}, u} J.JObject{input} Fields{}: []
    case S.ObjectSchema{S.Field{+k, +c, +p} <> t, u} J.JObject{+input} Fields{}: join(field_failures(Nat.is_eq(named(input, k), 1n), presence(p, named(input, k)), k, under(S.PathKey{k}, failures(c, member(input, k), Node{}))), failures(S.ObjectSchema{t, u}, J.JObject{input}, Fields{}))
    case S.NullableSchema{i} J.JNull{} Node{}: []
    case S.NullableSchema{i} x Node{}: failures(i, x, Node{})
    case S.UnionSchema{ms} x Node{}: flag(meets(S.UnionSchema{ms}, Holds{}, x), [])
    case _ _ _: []

# The first n entries.
def first_paths(ps: List<&2, List<&2, S.PathPart>>, n: Nat) -> List<&2, List<&2, S.PathPart>>:
  match ps n:
    case Nil{} k: []
    case p <> t 0n: []
    case p <> t 1n+k: p <> first_paths(t, k)

def located_paths(ok: Bool, +s: S.Schema, v: J.Json) -> List<&2, List<&2, S.PathPart>>:
  match ok:
    case True{}: first_paths(failures(s, v, Node{}), error_cap())
    case False{}: [[]]

# The paths the decoder must list, in order: the first error_cap() failures,
# or the root alone for an invalid schema. Empty exactly when v satisfies s.
def error_paths(+s: S.Schema, v: J.Json) -> List<&2, List<&2, S.PathPart>>:
  located_paths(schema_ok(s), s, v)

def paths(es: List<&2, S.Error>) -> List<&2, List<&2, S.PathPart>>:
  match es:
    case Nil{}: []
    case S.Error{c, m, p} <> t: p <> paths(t)

# The paths a result lists: none for a success.
def listed_paths(r: Result<&2, &2, S.Errors(), S.Value>) -> List<&2, List<&2, S.PathPart>>:
  match r:
    case Done{x}: []
    case Fail{es}: paths(es)

# Coercion for text sources (BND-35), restated: a string under a number or
# integer schema that is an RFC 8259 number token becomes that number; "true"
# and "false" under a boolean schema become booleans; arrays coerce each item
# against the item schema, nullables against the inner schema; an object keeps
# its members in order, coerces each member named by a declared field against
# that field's schema, and for an array field replaces the first member with
# that key by an array of every such member's value (coerced as items) and
# drops the others. Everything else stays as it is.

type Coercing is Data:
  # v against s.
  Whole{}
  # v is an array; each item against s.
  Each{}
  # v is an object; members named key against s.
  Members{key: String}
  # v is an object; the first member named key becomes merged, later ones go.
  Merged{key: String, merged: J.Json, first: Bool}

def number_or_text(ok: Bool, x: String) -> J.Json:
  match ok:
    case True{}: J.JNumber{x}
    case False{}: J.JString{x}

def bool_or_text(yes: Bool, no: Bool, x: String) -> J.Json:
  match yes no:
    case True{} _: J.JBool{True{}}
    case False{} True{}: J.JBool{False{}}
    case False{} False{}: J.JString{x}

def with_value(same: Bool, y: J.Json, rest: List<&2, J.Json>) -> List<&2, J.Json>:
  match same:
    case True{}: y <> rest
    case False{}: rest

def values_named(input: List<&2, J.Field>, +k: String) -> List<&2, J.Json>:
  match input:
    case Nil{}: []
    case J.Field{key, y} <> t: with_value(String.eq(key, k), y, values_named(t, k))

def cons_item(x: J.Json, rest: J.Json) -> J.Json:
  match rest:
    case J.JArray{xs}: J.JArray{x <> xs}
    case other: other

def cons_member(f: J.Field, rest: J.Json) -> J.Json:
  match rest:
    case J.JObject{fs}: J.JObject{f <> fs}
    case other: other

def merged_member(same: Bool, first: Bool, key: String, y: J.Json, g: J.Json, rest: J.Json) -> J.Json:
  match same first:
    case True{} True{}: cons_member(J.Field{key, g}, rest)
    case True{} False{}: rest
    case False{} f: cons_member(J.Field{key, y}, rest)

def coerced(s: S.Schema, v: J.Json, how: Coercing) -> J.Json:
  match s v how:
    case S.NumberSchema{a, b} J.JString{+x} Whole{}: number_or_text(number(x), x)
    case S.IntegerSchema{a, b} J.JString{+x} Whole{}: number_or_text(number(x), x)
    case S.BooleanSchema{} J.JString{+x} Whole{}: bool_or_text(String.eq(x, "true"), String.eq(x, "false"), x)
    case S.NullableSchema{i} x Whole{}: coerced(i, x, Whole{})
    case S.ArraySchema{i, m, n} J.JArray{xs} Whole{}: coerced(i, J.JArray{xs}, Each{})
    case S.ObjectSchema{S.Field{+k, S.ArraySchema{+i, m, n}, p} <> t, u} J.JObject{+input} Whole{}: coerced(S.ObjectSchema{t, u}, coerced(i, J.JObject{input}, Merged{k, coerced(i, J.JArray{values_named(input, k)}, Each{}), True{}}), Whole{})
    case S.ObjectSchema{S.Field{+k, +c, p} <> t, u} J.JObject{+input} Whole{}: coerced(S.ObjectSchema{t, u}, coerced(c, J.JObject{input}, Members{k}), Whole{})
    case i J.JArray{Nil{}} Each{}: J.JArray{[]}
    case +i J.JArray{h <> t} Each{}: cons_item(coerced(i, h, Whole{}), coerced(i, J.JArray{t}, Each{}))
    case c J.JObject{Nil{}} Members{k}: J.JObject{[]}
    case +c J.JObject{J.Field{+key, +y} <> t} Members{+k}: cons_member(Bool.pick(J.Field, String.eq(key, k), J.Field{key, coerced(c, y, Whole{})}, J.Field{key, y}), coerced(c, J.JObject{t}, Members{k}))
    case c J.JObject{Nil{}} Merged{k, g, f}: J.JObject{[]}
    case c J.JObject{J.Field{+key, y} <> t} Merged{+k, +g, +f}: merged_member(String.eq(key, k), f, key, y, g, coerced(c, J.JObject{t}, Merged{k, g, f && Bool.not(String.eq(key, k))}))
    case _ x _: x

def coerce_text(+s: S.Schema, v: J.Json) -> J.Json:
  coerced(s, v, Whole{})
