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

# Expanded size: the node count once every counted repetition is written out,
# r{m,n} as n copies of r and r{m,} as m + 1. It bounds the matcher's residual
# sets, so capping it bounds the work per scalar of text.
def limit() -> Nat:
  128n

def copies(m: Nat, n: Maybe<&2, Nat>) -> Nat:
  match n:
    case None{}: 1n+m
    case Some{k}: k

def size(p: Pattern) -> Nat:
  match p:
    case Literal{x}: 1n+String.length(x)
    case Class{rs}: 1n
    case Cat{a, b}: 1n+Nat.add(size(a), size(b))
    case Repeat{r, m, n}: 1n+Nat.mul(copies(m, n), size(r))

# Sized only once its parts are valid, so every product stays below 2^48.
def small(ok: Bool, p: Pattern) -> Bool:
  match ok:
    case False{}: False{}
    case True{}: Nat.is_le(size(p), limit())

# Class ranges are ASCII; literal text is any Unicode scalar text; m <= n; a
# repetition has at most `limit()` copies; every part stays within `limit()`.
def valid(p: Pattern) -> Bool:
  match p:
    case Literal{+x}: small(J.scalars(x), Literal{x})
    case Class{+rs}: small(ranges_valid(rs, True{}), Class{rs})
    case Cat{+a, +b}: small(valid(a) && valid(b), Cat{a, b})
    case Repeat{+r, +m, +n}: small(valid(r) && at_most(n, m) && Nat.is_le(copies(m, n), limit()), Repeat{r, m, n})

def in_ranges(rs: List<&2, Range>, +c: U32, found: Bool) -> Bool:
  match rs:
    case Nil{}: found
    case Range{lo, hi} <> t: in_ranges(t, c, found || ((c >= lo : U32) && (c <= hi : U32)))

# Matching uses Antimirov partial derivatives: the set of patterns that must
# match the rest of the text. Deduplicated sets stay bounded by the expanded
# size, so a scan is linear in the text with a constant `limit()` caps. Every
# text-length loop is a tail call.

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

# A set entry carries its pattern's hash, so telling residuals apart is
# usually one U32 comparison; only equal hashes fall back to `same`.
type Entry is Data:
  Entry{key: U32, pattern: Pattern}

def mix(h: U32, x: U32) -> U32:
  ((h * 31 : U32) + x : U32)

def text_hash(s: String, h: U32) -> U32:
  match s:
    case SNil{}: h
    case SCon{Chr{c}, t}: text_hash(t, mix(h, c))

def ranges_hash(rs: List<&2, Range>, h: U32) -> U32:
  match rs:
    case Nil{}: h
    case Range{lo, hi} <> t: ranges_hash(t, mix(mix(h, lo), hi))

def max_hash(n: Maybe<&2, Nat>) -> U32:
  match n:
    case None{}: 0
    case Some{k}: (U32.from_nat(k) + 1 : U32)

def hash(p: Pattern) -> U32:
  match p:
    case Literal{x}: text_hash(x, 1)
    case Class{rs}: ranges_hash(rs, 2)
    case Cat{a, b}: mix(mix(3, hash(a)), hash(b))
    case Repeat{r, m, n}: mix(mix(mix(4, hash(r)), U32.from_nat(m)), max_hash(n))

def gate(hit: Bool, p: Pattern, q: Pattern) -> Bool:
  match hit:
    case False{}: False{}
    case True{}: same(p, q)

def member(es: List<&2, Entry>, +k: U32, +q: Pattern, found: Bool) -> Bool:
  match es:
    case Nil{}: found
    case Entry{h, p} <> t:
      match found:
        case True{}: True{}
        case False{}: member(t, k, q, gate(U32.is_eq(h, k), p, q))

def insert(seen: Bool, k: U32, q: Pattern, acc: List<&2, Entry>) -> List<&2, Entry>:
  match seen:
    case True{}: acc
    case False{}: Entry{k, q} <> acc

def add_one(+k: U32, +q: Pattern, +acc: List<&2, Entry>) -> List<&2, Entry>:
  insert(member(acc, k, q, False{}), k, q, acc)

def add_all(xs: List<&2, Pattern>, acc: List<&2, Entry>) -> List<&2, Entry>:
  match xs:
    case Nil{}: acc
    case +q <> t: add_all(t, add_one(hash(q), q, acc))

def step(es: List<&2, Entry>, +c: U32, acc: List<&2, Entry>) -> List<&2, Entry>:
  match es:
    case Nil{}: acc
    case Entry{h, q} <> t: step(t, c, add_all(derive(c, q), acc))

def any_nullable(es: List<&2, Entry>, found: Bool) -> Bool:
  match es:
    case Nil{}: found
    case Entry{h, p} <> t: any_nullable(t, found || nullable(p))

def run(s: String, es: List<&2, Entry>) -> Bool:
  match s:
    case SNil{}: any_nullable(es, False{})
    case SCon{Chr{c}, t}: run(t, step(es, c, []))

# Whole-string match. Callers check `valid` first; invalid counts match nothing.
def matches(+p: Pattern, s: String) -> Bool:
  run(s, [Entry{hash(p), p}])

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
