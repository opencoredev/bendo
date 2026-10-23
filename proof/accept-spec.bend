# BND-25: the documented Accept policy for error bodies, stated without the
# Errors module. Docs: docs/decisions/0011-crash.md, "Body negotiation".
#
# The first Accept field, decoded as UTF-8, selects JSON when one of its
# comma-separated elements is a JSON range:
# - the media range, without surrounding SP/HTAB and compared after ASCII
#   lowercasing, is exactly application/json (wildcards never select JSON);
# - every parameter is `name` or `name=value`, with exactly one `=` outside
#   quoted strings, and a parameter named q has a positive qvalue;
# - commas, semicolons and equals signs inside a quoted string do not
#   separate anything, a backslash inside a quoted string escapes the next
#   character, and an unterminated quoted string makes the field select text.
# Otherwise (no field, invalid UTF-8, no JSON range) the body is text.
import Base
import ../src/http/request.bend as Request
import ../src/http/bytes.bend as Bytes
import ../src/data/utf8.bend as Utf8

# Character classes. Each byte test is the obvious one; the grammar is below.
type Q is Data:
  AZero{}
  AOne{}
  ADigit{}
  ADot{}
  AOther{}

def qkind(zero: Bool, one: Bool, digit: Bool, dot: Bool) -> Q:
  match zero one digit dot:
    case True{} _ _ _: AZero{}
    case False{} True{} _ _: AOne{}
    case False{} False{} True{} _: ADigit{}
    case False{} False{} False{} True{}: ADot{}
    case False{} False{} False{} False{}: AOther{}

def qclass(+c: U32) -> Q:
  qkind(U32.is_eq(c, 48), U32.is_eq(c, 49), (c >= 48 : U32) && (c <= 57 : U32), U32.is_eq(c, 46))

type S is Data:
  AQuote{}
  AEscape{}
  ADelimiter{}
  APlain{}

def skind(quote: Bool, escape: Bool, cut: Bool) -> S:
  match quote escape cut:
    case True{} _ _: AQuote{}
    case False{} True{} _: AEscape{}
    case False{} False{} True{}: ADelimiter{}
    case False{} False{} False{}: APlain{}

def sclass(c: Char, d: Char) -> S:
  match c d:
    case Chr{+x} Chr{y}: skind(U32.is_eq(x, 34), U32.is_eq(x, 92), U32.is_eq(x, y))

# Segments of s at the delimiter d, outside quoted strings. Read right to
# left: a character either extends the first segment of what follows it or,
# for a delimiter outside quotes, starts a new empty one in front. The state
# is whether the character is inside a quoted string, and whether a backslash
# inside one escapes it. An unterminated quoted string yields no segments.
def extend(c: Char, xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}: []
    case h <> t: SCon{c, h} <> t

def start(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}: []
    case h <> t: "" <> h <> t

def finish(quoted: Bool) -> List<&2, String>:
  match quoted:
    case True{}: []
    case False{}: [""]

def starts(quoted: Bool, k: S) -> Bool:
  match quoted k:
    case False{} ADelimiter{}: True{}
    case _ _: False{}

def apply(starting: Bool, c: Char, xs: List<&2, String>) -> List<&2, String>:
  match starting:
    case True{}: start(xs)
    case False{}: extend(c, xs)

# Inside quotes an escaped character never closes them; an unescaped quote does.
# Outside quotes a quote opens them.
def next_quoted(quoted: Bool, escaped: Bool, k: S) -> Bool:
  match quoted escaped k:
    case True{} True{} _: True{}
    case True{} False{} AQuote{}: False{}
    case True{} False{} _: True{}
    case False{} _ AQuote{}: True{}
    case False{} _ _: False{}

def next_escaped(quoted: Bool, escaped: Bool, k: S) -> Bool:
  match quoted escaped k:
    case True{} False{} AEscape{}: True{}
    case _ _ _: False{}

def segments(s: String, +d: Char, +quoted: Bool, +escaped: Bool) -> List<&2, String>:
  match s:
    case SNil{}: finish(quoted)
    case SCon{+c, t}:
      +k = sclass(c, d)
      apply(starts(quoted, k), c, segments(t, d, next_quoted(quoted, escaped, k), next_escaped(quoted, escaped, k)))

def pieces(s: String, d: Char) -> List<&2, String>:
  segments(s, d, False{}, False{})

# Surrounding SP and HTAB removed.
def strip(s: String) -> String:
  Bytes.ascii(Bytes.trim(Bytes.encode(s)))

# RFC 9110 12.4.2: qvalue = ( "0" [ "." 0*3DIGIT ] ) / ( "1" [ "." 0*3("0") ] ).
# Only a positive value selects JSON.
def at_most(s: String, n: Nat) -> Bool:
  match s n:
    case SNil{} _: True{}
    case SCon{h, t} 1n+m: at_most(t, m)
    case _ 0n: False{}

# A digit, or only a zero when zeros_only.
def digit_ok(k: Q, zeros_only: Bool) -> Bool:
  match k zeros_only:
    case AZero{} _: True{}
    case AOne{} False{}: True{}
    case ADigit{} False{}: True{}
    case _ _: False{}

def digits(s: String, +zeros_only: Bool) -> Bool:
  match s:
    case SNil{}: True{}
    case SCon{Chr{+c}, t}: digit_ok(qclass(c), zeros_only) && digits(t, zeros_only)

def is_dot(k: Q) -> Bool:
  match k:
    case ADot{}: True{}
    case _: False{}

def nonzero(k: Q) -> Bool:
  match k:
    case AOne{}: True{}
    case ADigit{}: True{}
    case _: False{}

def any_nonzero(s: String) -> Bool:
  match s:
    case SNil{}: False{}
    case SCon{Chr{+c}, t}: nonzero(qclass(c)) || any_nonzero(t)

# After the integer digit: nothing, or a dot and at most three digits.
def decimals(rest: String, zeros_only: Bool) -> Bool:
  match rest:
    case SNil{}: True{}
    case SCon{Chr{+c}, +f}: is_dot(qclass(c)) && at_most(f, 3n) && digits(f, zeros_only)

def qvalue_lead(k: Q, +rest: String) -> Bool:
  match k:
    case AOne{}: decimals(rest, True{})
    case AZero{}: decimals(rest, False{}) && any_nonzero(rest)
    case _: False{}

def positive_qvalue(s: String) -> Bool:
  match s:
    case SNil{}: False{}
    case SCon{Chr{+c}, rest}: qvalue_lead(qclass(c), rest)

# A parameter's pieces at "=": a name, or a name and a value.
def parameter(parts: List<&2, String>) -> Bool:
  match parts:
    case Nil{}: False{}
    case name <> Nil{}: Bool.not(String.eq(strip(name), "q"))
    case name <> value <> Nil{}: Bool.not(String.eq(strip(name), "q")) || positive_qvalue(strip(value))
    case name <> value <> more: False{}

def parameters(ps: List<&2, String>) -> Bool:
  match ps:
    case Nil{}: True{}
    case p <> t: parameter(pieces(strip(p), '=')) && parameters(t)

# An element's pieces at ";": the media range, then its parameters.
def json_range(parts: List<&2, String>) -> Bool:
  match parts:
    case Nil{}: False{}
    case range <> ps: String.eq(strip(range), "application/json") && parameters(ps)

def any_json(elements: List<&2, String>) -> Bool:
  match elements:
    case Nil{}: False{}
    case e <> t: json_range(pieces(Bytes.fold(e), ';')) || any_json(t)

def accepts_json(field: Maybe<&2, String>) -> Bool:
  match field:
    case None{}: False{}
    case Some{s}: any_json(pieces(s, ','))

# The Accept field the policy reads: the first request field named accept,
# decoded as UTF-8; none when absent or not valid UTF-8.
def accept_pick(v: List<&2, U32>, rest: List<&2, List<&2, U32>>, same: Bool) -> List<&2, List<&2, U32>>:
  match same:
    case True{}: v <> rest
    case False{}: rest

def accept_values(hs: List<&2, Request.Header>) -> List<&2, List<&2, U32>>:
  match hs:
    case Nil{}: []
    case Request.Header{+n, v} <> t: accept_pick(v, accept_values(t), String.eq(n, "accept"))

def first_utf8(values: List<&2, List<&2, U32>>) -> Maybe<&2, String>:
  match values:
    case Nil{}: None{}
    case v <> t: Utf8.decode(v)

def accept_field(req: Request.Req) -> Maybe<&2, String>:
  match req:
    case Request.Req{m, p, q, v, hs}: first_utf8(accept_values(hs))

# Examples from the documented policy and the integration tests.
def example(field: String, json: Bool) -> Type:
  {accepts_json(Some{field}) == json : Bool}

def example_0() -> example("application/json", True{}):
  {==}

def example_1() -> example("application/json;q=1, text/plain;q=0", True{}):
  {==}

def example_2() -> example("text/plain, Application/JSON; charset=utf-8; q=0.5", True{}):
  {==}

def example_3() -> example(" application/json ;q=0.9 ", True{}):
  {==}

def example_4() -> example("application/json; Q=0.5", True{}):
  {==}

def example_5() -> example("application/json;q=1.000", True{}):
  {==}

def example_6() -> example("application/json;q=1.", True{}):
  {==}

def example_7() -> example("application/json;q=0.001", True{}):
  {==}

def example_8() -> example("application/json;flag", True{}):
  {==}

def example_9() -> example("application/json;profile=\"a,b;c\";q=0.5", True{}):
  {==}

def example_10() -> example("application/json;q=0", False{}):
  {==}

def example_11() -> example("application/json;q=0.", False{}):
  {==}

def example_12() -> example("application/json;q=0.000", False{}):
  {==}

def example_13() -> example("application/json;q=1.001", False{}):
  {==}

def example_14() -> example("application/json;q=0.1234", False{}):
  {==}

def example_15() -> example("application/json;q", False{}):
  {==}

def example_16() -> example("application/json;a=b=c", False{}):
  {==}

def example_17() -> example("application/json;profile=\"a,b\";q=0", False{}):
  {==}

def example_18() -> example("application/json;profile=\"a;b\";q=0", False{}):
  {==}

def example_19() -> example("application/json;profile=\"a\\\"b,c\";q=0", False{}):
  {==}

def example_20() -> example("application/json;profile=\"unclosed", False{}):
  {==}

def example_21() -> example("*/*", False{}):
  {==}

def example_22() -> example("application/*", False{}):
  {==}

def example_23() -> example("text/plain", False{}):
  {==}

def absent_example() -> {accepts_json(None{}) == False{} : Bool}:
  {==}
