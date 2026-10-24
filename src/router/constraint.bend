import Base
import ./encoding.bend as E

type Split is Data:
  Split{body: String, suffix: String}

type Range is Data:
  Range{lo: U32, hi: U32}

type Constraint is Data:
  Any{}
  Int{}
  Uuid{}
  Slug{}
  Class{ranges: List<&2, Range>, count: Maybe<&2, Nat>}

def in_range(+n: U32, lo: U32, hi: U32) -> Bool:
  (n >= lo : U32) && (n <= hi : U32)

def digit(n: U32) -> Bool:
  in_range(n, 48, 57)

def lower(n: U32) -> Bool:
  in_range(n, 97, 122)

def alpha(+n: U32) -> Bool:
  lower(n) || in_range(n, 65, 90)

def hex(+n: U32) -> Bool:
  digit(n) || in_range(n, 97, 102) || in_range(n, 65, 70)

# Capture values come from the request, so each loop over one is a tail call
# (BND-84). The `_spec` defs keep the recursive originals;
# constraint-proofs.bend proves each loop equal to its spec.
def digits_spec(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{n}, t}:
      digit(n) && digits_spec(t)

def digits_go(s: String, ok: Bool) -> Bool:
  match s:
    case SNil{}:
      ok
    case SCon{Chr{n}, t}:
      digits_go(t, ok && digit(n))

def digits(s: String) -> Bool:
  digits_go(s, True{})

def integer(s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{'-', +t}:
      Bool.not(String.is_empty(t)) && digits(t)
    case SCon{Chr{n}, t}:
      digit(n) && digits(t)

def slug_char(+n: U32) -> Bool:
  lower(n) || digit(n) || U32.is_eq(n, 45)

def slug_spec(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{+n}, t}:
      (lower(n) || digit(n) || U32.is_eq(n, 45)) && slug_spec(t)

def slug_go(s: String, ok: Bool) -> Bool:
  match s:
    case SNil{}:
      ok
    case SCon{Chr{+n}, t}:
      slug_go(t, ok && slug_char(n))

def slug(s: String) -> Bool:
  slug_go(s, True{})

def dash_at(+pos: Nat) -> Bool:
  Nat.is_eq(pos, 8n) || Nat.is_eq(pos, 13n) || Nat.is_eq(pos, 18n) || Nat.is_eq(pos, 23n)

def uuid_spec(s: String, +pos: Nat) -> Bool:
  match s:
    case SNil{}:
      Nat.is_eq(pos, 36n)
    case SCon{Chr{+n}, +t}:
      E.choose(Bool, Nat.is_eq(pos, 8n) || Nat.is_eq(pos, 13n) || Nat.is_eq(pos, 18n) || Nat.is_eq(pos, 23n), u => (
        U32.is_eq(n, 45) && uuid_spec(t, 1n+pos)
      ), u => (
        hex(n) && uuid_spec(t, 1n+pos)
      ))

def uuid_char(+n: U32, dash: Bool) -> Bool:
  E.choose(Bool, dash, u => U32.is_eq(n, 45), u => hex(n))

def uuid_go(s: String, +pos: Nat, ok: Bool) -> Bool:
  match s:
    case SNil{}:
      ok && Nat.is_eq(pos, 36n)
    case SCon{Chr{+n}, t}:
      uuid_go(t, 1n+pos, ok && uuid_char(n, dash_at(pos)))

def uuid(s: String, +pos: Nat) -> Bool:
  uuid_go(s, pos, True{})

def member(ranges: List<&2, Range>, +n: U32) -> Bool:
  match ranges:
    case Nil{}:
      False{}
    case Range{lo, hi} <> t:
      in_range(n, lo, hi) || member(t, n)

def class_chars_spec(s: String, +ranges: List<&2, Range>) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{n}, t}:
      member(ranges, n) && class_chars_spec(t, ranges)

def class_chars_go(s: String, +ranges: List<&2, Range>, ok: Bool) -> Bool:
  match s:
    case SNil{}:
      ok
    case SCon{Chr{n}, t}:
      class_chars_go(t, ranges, ok && member(ranges, n))

def class_chars(s: String, +ranges: List<&2, Range>) -> Bool:
  class_chars_go(s, ranges, True{})

def count_ok(count: Maybe<&2, Nat>, n: Nat) -> Bool:
  match count:
    case None{}:
      True{}
    case Some{k}:
      Nat.is_eq(k, n)

def accepts(c: Constraint, +value: String) -> Bool:
  match c:
    case Any{}:
      True{}
    case Int{}:
      integer(value)
    case Uuid{}:
      uuid(value, 0n)
    case Slug{}:
      Bool.not(String.is_empty(value)) && slug(value)
    case Class{ranges, count}:
      Bool.not(String.is_empty(value)) && class_chars(value, ranges) && count_ok(count, String.length(value))

# ASCII literals and ascending ranges only. '-' is literal at either end;
# backslash, brackets, braces and '^' are not class literals.
def class_literal(+n: U32) -> Bool:
  in_range(n, 32, 126) && Bool.not(U32.is_eq(n, 91) || U32.is_eq(n, 92) || U32.is_eq(n, 93) || U32.is_eq(n, 94) || U32.is_eq(n, 123) || U32.is_eq(n, 125))

def ranges_go(s: String, +first: Bool) -> Maybe<&2, List<&2, Range>>:
  match s:
    case SNil{}:
      Some{Nil{}}
    case SCon{Chr{+a}, SCon{'-', SCon{Chr{+b}, t}}}:
      E.choose(Maybe<&2, List<&2, Range>>, class_literal(a) && class_literal(b) && Bool.not(U32.is_eq(a, 45)) && Bool.not(U32.is_eq(b, 45)) && (a <= b : U32), u => (
        do Maybe<&2, List<&2, Range>>:
          rest : List<&2, Range> <- ranges_go(t, False{})
          return Range{a, b} <> rest
      ), u => (None{}))
    case SCon{Chr{+a}, +t}:
      E.choose(Maybe<&2, List<&2, Range>>, class_literal(a) && (Bool.not(U32.is_eq(a, 45)) || first || String.is_empty(t)), u => (
        do Maybe<&2, List<&2, Range>>:
          rest : List<&2, Range> <- ranges_go(t, False{})
          return Range{a, a} <> rest
      ), u => (None{}))

def ranges(s: String) -> Maybe<&2, List<&2, Range>>:
  ranges_go(s, True{})

def split_cons(h: Char, pair: Split) -> Split:
  Split{body, suffix} = pair
  Split{SCon{h, body}, suffix}

def class_split(s: String) -> Maybe<&2, Split>:
  match s:
    case SNil{}:
      None{}
    case SCon{']', t}:
      Some{Split{"", t}}
    case SCon{h, t}:
      do Maybe<&2, Split>:
        pair : Split <- class_split(t)
        return split_cons(h, pair)

def repetition(+s: String) -> Maybe<&2, Maybe<&2, Nat>>:
  match s:
    case SCon{'+', SNil{}}:
      Some{None{}}
    case SCon{'{', +t}:
      E.choose(Maybe<&2, Maybe<&2, Nat>>, String.ends_with(t, "}"), u => (
        +number = String.take(t, Nat.sub(String.length(t), 1n))
        E.choose(Maybe<&2, Maybe<&2, Nat>>, Bool.not(String.is_empty(number)) && digits(number), u => (
          do Maybe<&2, Maybe<&2, Nat>>:
            +n : U32 <- U32.read(number)
            E.choose(Maybe<&2, Maybe<&2, Nat>>, U32.is_gt(n, 0), u => (Some{Some{U32.to_nat(n)}}), u => (None{}))
        ), u => (None{}))
      ), u => (None{}))
    case _:
      None{}

def compile_class(pair: Split) -> Maybe<&2, Constraint>:
  Split{+body, suffix} = pair
  do Maybe<&2, Constraint>:
    rs : List<&2, Range> <- ranges(body)
    count : Maybe<&2, Nat> <- repetition(suffix)
    E.choose(Maybe<&2, Constraint>, Bool.not(String.is_empty(body)), u => (Some{Class{rs, count}}), u => (None{}))

def compile(s: String) -> Maybe<&2, Constraint>:
  match s:
    case "int":
      Some{Int{}}
    case "uuid":
      Some{Uuid{}}
    case "slug":
      Some{Slug{}}
    case SCon{'[', t}:
      do Maybe<&2, Constraint>:
        pair : Split <- class_split(t)
        compile_class(pair)
    case _:
      None{}
