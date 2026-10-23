# Structured string patterns for scalar schemas: the data, a polynomial matcher,
# and the ECMAScript source that means the same thing (docs/data/schema.md).
import Base
import ./json.bend as J

# Inclusive ASCII code point range of a character class.
type Range is Data:
  Range{lo: U32, hi: U32}

# Literal text, one scalar from a class, a sequence, or a counted repetition.
# `Repeat{p, m, None{}}` repeats at least m times; `Some{n}` caps the count at n.
type Pattern is Data:
  Literal{text: String}
  Class{ranges: List<&2, Range>}
  Cat{first: Pattern, second: Pattern}
  Repeat{body: Pattern, min: Nat, max: Maybe<&2, Nat>}

# Sequence of patterns; the empty sequence matches only the empty string.
def seq(ps: List<&2, Pattern>) -> Pattern:
  match ps:
    case Nil{}: Literal{""}
    case p <> Nil{}: p
    case p <> t: Cat{p, seq(t)}

def at_most(limit: Maybe<&2, Nat>, n: Nat) -> Bool:
  match limit:
    case None{}: True{}
    case Some{k}: Nat.is_le(n, k)

def ranges_valid(rs: List<&2, Range>, ok: Bool) -> Bool:
  match rs:
    case Nil{}: ok
    case Range{+lo, +hi} <> t: ranges_valid(t, ok && (lo <= hi : U32) && (hi <= 127 : U32))

# Class ranges are ASCII; literal text is any Unicode scalar text; m <= n.
def valid(p: Pattern) -> Bool:
  match p:
    case Literal{x}: J.scalars(x)
    case Class{rs}: ranges_valid(rs, True{})
    case Cat{a, b}: valid(a) && valid(b)
    case Repeat{r, +m, n}: valid(r) && at_most(n, m)

def in_ranges(rs: List<&2, Range>, +c: U32, found: Bool) -> Bool:
  match rs:
    case Nil{}: found
    case Range{lo, hi} <> t: in_ranges(t, c, found || ((c >= lo : U32) && (c <= hi : U32)))

# Matching uses Antimirov partial derivatives: the set of patterns that must
# match the rest of the text. Deduplicated sets stay bounded by the pattern's
# size (counted repetitions count once per remaining count), so a scan is
# linear in the text for a fixed pattern. Every text-length loop is a tail call.

def nullable(p: Pattern) -> Bool:
  match p:
    case Literal{x}: String.is_empty(x)
    case Class{rs}: False{}
    case Cat{a, b}: nullable(a) && nullable(b)
    case Repeat{r, +m, n}: at_most(n, m) && (Nat.is_eq(m, 0n) || nullable(r))

def behind(ds: List<&2, Pattern>, +rest: Pattern) -> List<&2, Pattern>:
  match ds:
    case Nil{}: []
    case d <> t: Cat{d, rest} <> behind(t, rest)

def literal_step(same: Bool, t: String) -> List<&2, Pattern>:
  match same:
    case True{}: [Literal{t}]
    case False{}: []

def class_step(hit: Bool) -> List<&2, Pattern>:
  match hit:
    case True{}: [Literal{""}]
    case False{}: []

def cat_step(left: List<&2, Pattern>, empty_first: Bool, right: List<&2, Pattern>) -> List<&2, Pattern>:
  match empty_first:
    case True{}: List.append(&2, Pattern, left, right)
    case False{}: left

def less(n: Maybe<&2, Nat>) -> Maybe<&2, Nat>:
  match n:
    case None{}: None{}
    case Some{0n}: Some{0n}
    case Some{1n+k}: Some{k}

def open(n: Maybe<&2, Nat>) -> Bool:
  match n:
    case None{}: True{}
    case Some{0n}: False{}
    case Some{1n+k}: True{}

def pred(n: Nat) -> Nat:
  match n:
    case 0n: 0n
    case 1n+k: k

# One more body word, then the remaining counts: the derivative of r{m,n} is
# d(r)·r{m-1,n-1}, plus d(r{m-1,n-1}) when r accepts the empty word.
def repeat_once(go: Bool, ds: List<&2, Pattern>, r: Pattern, m: Nat, n: Maybe<&2, Nat>) -> List<&2, Pattern>:
  match go:
    case True{}: behind(ds, Repeat{r, pred(m), less(n)})
    case False{}: []

def repeat_empty(+ds: List<&2, Pattern>, +r: Pattern, m: Nat, +n: Maybe<&2, Nat>) -> List<&2, Pattern>:
  match m:
    case 0n: repeat_once(open(n), ds, r, 0n, n)
    case 1n+(+k): List.append(&2, Pattern, repeat_once(open(n), ds, r, 1n+k, n), repeat_empty(ds, r, k, less(n)))

def repeat_step(empty: Bool, +ds: List<&2, Pattern>, +r: Pattern, +m: Nat, +n: Maybe<&2, Nat>) -> List<&2, Pattern>:
  match empty:
    case True{}: repeat_empty(ds, r, m, n)
    case False{}: repeat_once(open(n), ds, r, m, n)

def derive(+c: U32, p: Pattern) -> List<&2, Pattern>:
  match p:
    case Literal{SNil{}}: []
    case Literal{SCon{Chr{d}, t}}: literal_step(U32.is_eq(c, d), t)
    case Class{rs}: class_step(in_ranges(rs, c, False{}))
    case Cat{+a, +b}: cat_step(behind(derive(c, a), b), nullable(a), derive(c, b))
    case Repeat{+r, m, n}: repeat_step(nullable(r), derive(c, r), r, m, n)

def ranges_same(a: List<&2, Range>, b: List<&2, Range>) -> Bool:
  match a b:
    case Nil{} Nil{}: True{}
    case Range{x, y} <> s Range{u, v} <> t: U32.is_eq(x, u) && U32.is_eq(y, v) && ranges_same(s, t)
    case _ _: False{}

def max_same(a: Maybe<&2, Nat>, b: Maybe<&2, Nat>) -> Bool:
  match a b:
    case None{} None{}: True{}
    case Some{x} Some{y}: Nat.is_eq(x, y)
    case _ _: False{}

def same(p: Pattern, q: Pattern) -> Bool:
  match p q:
    case Literal{x} Literal{y}: String.eq(x, y)
    case Class{x} Class{y}: ranges_same(x, y)
    case Cat{a, b} Cat{c, d}: same(a, c) && same(b, d)
    case Repeat{r, m, n} Repeat{s, k, l}: same(r, s) && Nat.is_eq(m, k) && max_same(n, l)
    case _ _: False{}

def member(ps: List<&2, Pattern>, +q: Pattern, found: Bool) -> Bool:
  match ps:
    case Nil{}: found
    case p <> t: member(t, q, found || same(p, q))

def insert(seen: Bool, q: Pattern, acc: List<&2, Pattern>) -> List<&2, Pattern>:
  match seen:
    case True{}: acc
    case False{}: q <> acc

def add_all(xs: List<&2, Pattern>, +acc: List<&2, Pattern>) -> List<&2, Pattern>:
  match xs:
    case Nil{}: acc
    case +q <> t: add_all(t, insert(member(acc, q, False{}), q, acc))

def step(ps: List<&2, Pattern>, +c: U32, acc: List<&2, Pattern>) -> List<&2, Pattern>:
  match ps:
    case Nil{}: acc
    case q <> t: step(t, c, add_all(derive(c, q), acc))

def any_nullable(ps: List<&2, Pattern>, found: Bool) -> Bool:
  match ps:
    case Nil{}: found
    case p <> t: any_nullable(t, found || nullable(p))

def run(s: String, ps: List<&2, Pattern>) -> Bool:
  match s:
    case SNil{}: any_nullable(ps, False{})
    case SCon{Chr{c}, t}: run(t, step(ps, c, []))

# Whole-string match. Callers check `valid` first; invalid counts match nothing.
def matches(p: Pattern, s: String) -> Bool:
  run(s, [p])

# ECMAScript source. Every scalar is escaped, so the source means the same with
# or without the `u` flag: ASCII as \xHH, other BMP scalars as \uHHHH, and
# astral scalars as a \uHHHH\uHHHH surrogate pair inside a group.

def hex_char(letter: Bool, n: U32) -> Char:
  match letter:
    case False{}: Chr{(n + 48 : U32)}
    case True{}: Chr{(n + 87 : U32)}

def nibble(+n: U32) -> Char:
  hex_char((n >= 10 : U32), n)

def hex_go(width: Nat, +n: U32, acc: String) -> String:
  match width:
    case 0n: acc
    case 1n+w: hex_go(w, (n >> 4n : U32), SCon{nibble((n .&. 15 : U32)), acc})

def escape_go(ascii: Bool, bmp: Bool, +c: U32) -> String:
  match ascii bmp:
    case True{} _: "\\x" ++ hex_go(2n, c, "")
    case False{} True{}: "\\u" ++ hex_go(4n, c, "")
    case False{} False{}: "\\u" ++ hex_go(4n, (55296 + ((c - 65536 : U32) >> 10n) : U32), "") ++ "\\u" ++ hex_go(4n, (56320 + ((c - 65536 : U32) .&. 1023) : U32), "")

def escapes(s: String, acc: String) -> String:
  match s:
    case SNil{}: String.reverse(acc)
    case SCon{Chr{+c}, t}: escapes(t, String.reverse(escape_go((c < 128 : U32), (c < 65536 : U32), c)) ++ acc)

def ranges_source(rs: List<&2, Range>, acc: String) -> String:
  match rs:
    case Nil{}: acc
    case Range{lo, hi} <> t: ranges_source(t, acc ++ "\\x" ++ hex_go(2n, lo, "") ++ "-\\x" ++ hex_go(2n, hi, ""))

def class_source(rs: List<&2, Range>) -> String:
  match rs:
    case Nil{}: "[^\\s\\S]"
    case +r <> t: "[" ++ ranges_source(r <> t, "") ++ "]"

def counts_bounded(equal: Bool, k: Nat, j: Nat) -> String:
  match equal:
    case True{}: "{" ++ Nat.show(k) ++ "}"
    case False{}: "{" ++ Nat.show(k) ++ "," ++ Nat.show(j) ++ "}"

def counts(m: Nat, n: Maybe<&2, Nat>) -> String:
  match m n:
    case 0n None{}: "*"
    case 1n None{}: "+"
    case +k None{}: "{" ++ Nat.show(k) ++ ",}"
    case 0n Some{1n}: "?"
    case +k Some{+j}: counts_bounded(Nat.is_eq(k, j), k, j)

def source_go(p: Pattern) -> String:
  match p:
    case Literal{x}: escapes(x, "")
    case Class{rs}: class_source(rs)
    case Cat{a, b}: source_go(a) ++ source_go(b)
    case Repeat{r, m, n}: "(?:" ++ source_go(r) ++ ")" ++ counts(m, n)

# Anchored at both ends. `(?![\s\S])` is the absolute end of input; a bare `$`
# would also accept a final line terminator.
def source(p: Pattern) -> String:
  "^(?:" ++ source_go(p) ++ ")(?![\\s\\S])"
