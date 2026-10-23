# Scalar text checks. Every text-width traversal is tail recursive.
import Base
import ./decimal.bend as D

def between(+c: U32, lo: U32, hi: U32) -> Bool:
  (c >= lo : U32) && (c <= hi : U32)

def digit(c: U32) -> Bool:
  between(c, 48, 57)

def alpha(+c: U32) -> Bool:
  between(c, 65, 90) || between(c, 97, 122)

def alnum(+c: U32) -> Bool:
  alpha(c) || digit(c)

def hex(+c: U32) -> Bool:
  digit(c) || between(c, 65, 70) || between(c, 97, 102)

# The character sets are fixed size, independent of input text length.
def one_of(+c: U32, codes: List<&2, U32>) -> Bool:
  match codes:
    case Nil{}: False{}
    case x <> t: U32.is_eq(c, x) || one_of(c, t)

def atom(c: U32) -> Bool:
  +c = c
  alnum(c) || one_of(c, [33, 35, 36, 37, 38, 39, 42, 43, 45, 47, 61, 63, 94, 95, 96, 123, 124, 125, 126])

def uri_char(+c: U32) -> Bool:
  alnum(c) || one_of(c, [45, 46, 95, 126, 58, 47, 63, 35, 91, 93, 64, 33, 36, 38, 39, 40, 41, 42, 43, 44, 59, 61])

# Read backwards so each character can be prepended without a continuation.
def push(c: U32, pieces: List<&2, String>) -> List<&2, String>:
  match pieces:
    case Nil{}: [SCon{Chr{c}, ""}]
    case h <> t: SCon{Chr{c}, h} <> t

def cut(here: Bool, c: U32, pieces: List<&2, String>) -> List<&2, String>:
  match here:
    case True{}: "" <> pieces
    case False{}: push(c, pieces)

def split_go(s: String, +sep: U32, pieces: List<&2, String>) -> List<&2, String>:
  match s:
    case SNil{}: pieces
    case SCon{Chr{+c}, t}: split_go(t, sep, cut(U32.is_eq(c, sep), c, pieces))

def split(s: String, sep: U32) -> List<&2, String>:
  split_go(String.reverse(s), sep, [""])

# One tail fold covers the three all-character predicates.
type Chars is Data:
  LabelChars{}
  AtomChars{}
  Digits{}

def char_ok(mode: Chars, +c: U32) -> Bool:
  match mode:
    case LabelChars{}: alnum(c) || U32.is_eq(c, 45)
    case AtomChars{}: atom(c)
    case Digits{}: digit(c)

def chars(s: String, +mode: Chars, ok: Bool) -> Bool:
  match s:
    case SNil{}: ok
    case SCon{Chr{c}, t}: chars(t, mode, ok && char_ok(mode, c))

def first_alnum(s: String) -> Bool:
  match s:
    case SNil{}: False{}
    case SCon{Chr{c}, t}: alnum(c)

def last_alnum(s: String, last: Bool) -> Bool:
  match s:
    case SNil{}: last
    case SCon{Chr{c}, t}: last_alnum(t, alnum(c))

def label(+s: String) -> Bool:
  Nat.is_le(1n, D.length(s)) && Nat.is_le(D.length(s), 63n) && chars(s, LabelChars{}, True{}) && first_alnum(s) && last_alnum(s, False{})

def labels(ls: List<&2, String>, ok: Bool) -> Bool:
  match ls:
    case Nil{}: ok
    case h <> t: labels(t, ok && label(h))

def host(+s: String) -> Bool:
  Nat.is_le(D.length(s), 253n) && labels(split(s, 46), True{})

def atoms(ps: List<&2, String>, ok: Bool) -> Bool:
  match ps:
    case Nil{}: ok
    case +p <> t: atoms(t, ok && Bool.not(String.is_empty(p)) && chars(p, AtomChars{}, True{}))

def dot_atom(+s: String) -> Bool:
  Nat.is_le(D.length(s), 64n) && atoms(split(s, 46), True{})

def before_rev(here: Bool, c: U32, rev: String) -> String:
  match here:
    case True{}: rev
    case False{}: SCon{Chr{c}, rev}

def before_go(s: String, +codes: List<&2, U32>, rev: String, stop: Bool) -> String:
  match s stop:
    case _ True{}: String.reverse(rev)
    case SNil{} False{}: String.reverse(rev)
    case SCon{Chr{+c}, t} False{}:
      +here = one_of(c, codes)
      before_go(t, codes, before_rev(here, c, rev), here)

def before(s: String, codes: List<&2, U32>) -> String:
  before_go(s, codes, "", False{})

def from_go(s: String, +codes: List<&2, U32>, rest: String, stop: Bool) -> String:
  match s stop:
    case _ True{}: rest
    case SNil{} False{}: ""
    case SCon{Chr{+c}, +t} False{}: from_go(t, codes, SCon{Chr{c}, t}, one_of(c, codes))

def from(s: String, codes: List<&2, U32>) -> String:
  from_go(s, codes, "", False{})

def email_domain(local: String, rest: String) -> Bool:
  match rest:
    case SNil{}: False{}
    case SCon{at, domain}: dot_atom(local) && host(domain)

def email(+s: String) -> Bool:
  Nat.is_le(D.length(s), 254n) && email_domain(before(s, [64]), from(s, [64]))

def strip_go(prefix: String, s: String, ok: Bool) -> Maybe<&2, String>:
  match prefix s:
    case SNil{} s: Bool.pick(Maybe<&2, String>, ok, Some{s}, None{})
    case SCon{Chr{x}, p} SCon{Chr{y}, t}: strip_go(p, t, ok && U32.is_eq(x, y))
    case _ _: None{}

def strip(prefix: String, s: String) -> Maybe<&2, String>:
  strip_go(prefix, s, True{})

def suffix_due(due: Nat, c: U32) -> Nat:
  match due:
    case 0n: Bool.pick(Nat, U32.is_eq(c, 37), 2n, 0n)
    case 1n+k: k

def suffix_ok(due: Nat, +c: U32) -> Bool:
  match due:
    case 0n: U32.is_eq(c, 37) || uri_char(c)
    case 1n+k: hex(c)

def suffix(s: String, +due: Nat, ok: Bool) -> Bool:
  match s:
    case SNil{}: ok && Nat.is_eq(due, 0n)
    case SCon{Chr{+c}, t}: suffix(t, suffix_due(due, c), ok && suffix_ok(due, c))

# Only evaluate unary arithmetic after checking the five-digit bound and alphabet.
# The loop is tail recursive and its numeric work has a constant upper bound.
def value(s: String, acc: Nat) -> Nat:
  match s:
    case SNil{}: acc
    case SCon{Chr{c}, t}: value(t, Nat.add(Nat.mul(acc, 10n), Nat.sub(U32.to_nat(c), 48n)))

def port_gate(+p: String, valid: Bool) -> Bool:
  match valid:
    case False{}: False{}
    case True{}: Nat.is_le(value(p, 0n), 65535n)

def port(+p: String) -> Bool:
  port_gate(p, Nat.is_le(1n, D.length(p)) && Nat.is_le(D.length(p), 5n) && chars(p, Digits{}, True{}))

def after_host(s: String) -> Bool:
  match s:
    case SNil{}: True{}
    case SCon{Chr{+c}, +t}: Bool.pick(Bool, U32.is_eq(c, 58), port(before(t, [47, 63, 35])) && suffix(from(t, [47, 63, 35]), 0n, True{}), suffix(SCon{Chr{c}, t}, 0n, True{}))

def authority(rest: Maybe<&2, String>) -> Bool:
  match rest:
    case None{}: False{}
    case Some{+x}: host(before(x, [58, 47, 63, 35])) && after_host(from(x, [58, 47, 63, 35]))

def url(+s: String) -> Bool:
  authority(strip("http://", s)) || authority(strip("https://", s))
