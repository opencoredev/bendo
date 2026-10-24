import Base
import ../../../src/data/schema.bend as S
import ../../../src/data/json.bend as J
import ../../../src/data/decimal.bend as D
import ../../../src/data/schema-pattern.bend as P
import ../../../src/data/schema-pattern-automaton.bend as A
import ../../../src/data/schema-spec.bend as Spec

def lower() -> P.Pattern:
  P.Class{[P.Range{97, 122}, P.Range{48, 57}]}

def digit() -> P.Pattern:
  P.Class{[P.Range{48, 57}]}

def a() -> P.Pattern:
  P.Class{[P.Range{97, 97}]}

def slug() -> P.Pattern:
  P.seq([P.Repeat{lower(), 1n, None{}}, P.Repeat{P.Cat{P.Literal{"-"}, P.Repeat{lower(), 1n, None{}}}, 0n, None{}}])

def zip() -> P.Pattern:
  P.seq([P.Repeat{digit(), 5n, Some{5n}}, P.Repeat{P.Cat{P.Literal{"-"}, P.Repeat{digit(), 4n, Some{4n}}}, 0n, Some{1n}}])

# k copies of r in sequence, all repeated: the worst shapes the size cap admits.
def copies(k: Nat, +r: P.Pattern) -> List<&2, P.Pattern>:
  match k:
    case 0n: []
    case 1n+j: r <> copies(j, r)

def worst(k: Nat, n: Nat) -> P.Pattern:
  P.Repeat{P.seq(copies(k, P.Repeat{P.Class{[P.Range{97, 122}]}, 0n, Some{n}})), 0n, None{}}

# A star over 30 copies of [a-z]{0,2}, then U+0000 U+0001. The literal's two
# arcs have equal keys, so a table that merged arcs by key alone lost one.
def collision() -> P.Pattern:
  P.Cat{P.Repeat{P.seq(copies(30n, P.Repeat{P.Class{[P.Range{97, 122}]}, 0n, Some{2n}})), 0n, None{}}, P.Literal{SCon{Chr{0}, SCon{Chr{1}, ""}}}}

def text(p: P.Pattern) -> S.Schema:
  S.StringSchema{0n, None{}, Some{p}, S.Plain{}}

def pattern_of(name: String) -> P.Pattern:
  match name:
    case "pattern": P.Repeat{lower(), 1n, Some{4n}}
    case "star": P.Repeat{a(), 0n, None{}}
    case "plus": P.Repeat{a(), 1n, None{}}
    case "optional": P.Repeat{a(), 0n, Some{1n}}
    case "pattern-exact": P.Repeat{a(), 2n, Some{2n}}
    case "no-ranges": P.Repeat{P.Class{[]}, 0n, None{}}
    case "slug": slug()
    case "zip": zip()
    case "nested": P.Repeat{P.seq([P.Literal{"<"}, P.Repeat{P.Cat{P.Literal{"ab"}, P.Repeat{digit(), 0n, Some{2n}}}, 1n, Some{2n}}, P.Literal{">"}]), 0n, None{}}
    case "empties": P.Repeat{P.Repeat{P.Literal{""}, 0n, None{}}, 2n, Some{3n}}
    case "nullable-body": P.Repeat{P.Repeat{a(), 0n, Some{1n}}, 3n, None{}}
    case "bounds": P.Repeat{P.Cat{a(), P.Literal{"b"}}, 2n, Some{3n}}
    case "astral": P.Repeat{P.Literal{"😀é"}, 1n, Some{2n}}
    case "punctuation": P.seq([P.Literal{"^$\\.*+?()[]{}|/-"}, P.Repeat{P.Class{[P.Range{0, 31}, P.Range{127, 127}]}, 0n, Some{1n}}])
    case "worst-2x32": worst(32n, 2n)
    case "worst-6x16": worst(16n, 6n)
    case "worst-1x42": worst(42n, 1n)
    case "nested-10x11": P.Repeat{P.Repeat{a(), 0n, Some{10n}}, 0n, Some{11n}}
    case "starred-nested": P.Repeat{P.Repeat{P.Repeat{a(), 0n, Some{10n}}, 0n, Some{11n}}, 0n, None{}}
    case "collision": collision()
    case "bad-pattern": P.Repeat{P.Class{[P.Range{122, 97}]}, 0n, None{}}
    case "bad-ascii": P.Repeat{P.Class{[P.Range{0, 128}]}, 0n, None{}}
    case "bad-count": P.Repeat{a(), 2n, Some{1n}}
    case "bad-literal-pattern": P.Literal{SCon{Chr{55296}, ""}}
    case "bad-nested-count": P.Cat{P.Literal{"a"}, P.Repeat{a(), 3n, Some{2n}}}
    case _: P.Literal{""}

def schema(name: String) -> S.Schema:
  match name:
    case "text": S.StringSchema{0n, None{}, None{}, S.Plain{}}
    case "length": S.StringSchema{1n, Some{3n}, None{}, S.Plain{}}
    case "empty": S.StringSchema{0n, Some{0n}, None{}, S.Plain{}}
    case "exact": S.StringSchema{2n, Some{2n}, None{}, S.Plain{}}
    case "pattern": text(pattern_of("pattern"))
    case "star": text(pattern_of("star"))
    case "plus": text(pattern_of("plus"))
    case "optional": text(pattern_of("optional"))
    case "pattern-exact": text(pattern_of("pattern-exact"))
    case "no-ranges": text(pattern_of("no-ranges"))
    case "slug": text(pattern_of("slug"))
    case "zip": text(pattern_of("zip"))
    case "nested": text(pattern_of("nested"))
    case "empties": text(pattern_of("empties"))
    case "nullable-body": text(pattern_of("nullable-body"))
    case "bounds": text(pattern_of("bounds"))
    case "astral": text(pattern_of("astral"))
    case "slug-short": S.StringSchema{3n, Some{8n}, Some{slug()}, S.Plain{}}
    case "worst-2x32": text(pattern_of("worst-2x32"))
    case "worst-6x16": text(pattern_of("worst-6x16"))
    case "worst-1x42": text(pattern_of("worst-1x42"))
    case "starred-nested": text(pattern_of("starred-nested"))
    case "collision": text(pattern_of("collision"))
    case "worst-short": S.StringSchema{0n, Some{1n}, Some{pattern_of("worst-6x16")}, S.Plain{}}
    case "bad-literal-pattern": text(pattern_of("bad-literal-pattern"))
    case "bad-nested-count": text(pattern_of("bad-nested-count"))
    case "punctuation": text(pattern_of("punctuation"))
    case "email": S.StringSchema{0n, None{}, None{}, S.Email{}}
    case "url": S.StringSchema{0n, None{}, None{}, S.Url{}}
    case "number": S.NumberSchema{None{}, None{}}
    case "range": S.NumberSchema{Some{"-1.25e2"}, Some{"0.125E+3"}}
    case "equal": S.NumberSchema{Some{"1.00"}, Some{"10e-1"}}
    case "huge": S.NumberSchema{Some{"90071992547409931234567890.123456789"}, Some{"90071992547409931234567890.123456791"}}
    case "tiny": S.NumberSchema{Some{"1e-999999999999999999999999999999"}, Some{"2e-999999999999999999999999999999"}}
    case "exponent": S.NumberSchema{Some{"1e999999999999999999999999999999"}, Some{"2e999999999999999999999999999999"}}
    case "integer": S.IntegerSchema{None{}, None{}}
    case "int-range": S.IntegerSchema{Some{"-3.5"}, Some{"4e0"}}
    case "boolean": S.BooleanSchema{}
    case "null": S.LiteralSchema{J.JNull{}}
    case "literal": S.LiteralSchema{J.JString{"yes"}}
    case "numeric-literal": S.LiteralSchema{J.JNumber{"1.00"}}
    case "zero-literal": S.LiteralSchema{J.JNumber{"-0"}}
    case "enum": S.EnumSchema{[J.JString{"yes"}, J.JNumber{"2"}, J.JBool{False{}}, J.JNull{}]}
    case "empty-enum": S.EnumSchema{[]}
    case "bad-length": S.StringSchema{2n, Some{1n}, None{}, S.Plain{}}
    case "bad-range": S.NumberSchema{Some{"2"}, Some{"1"}}
    case "bad-bound": S.NumberSchema{Some{"NaN"}, None{}}
    case "bad-pattern": text(pattern_of("bad-pattern"))
    case "bad-ascii": text(pattern_of("bad-ascii"))
    case "bad-count": text(pattern_of("bad-count"))
    case "bad-literal": S.LiteralSchema{J.JArray{[]}}
    case "bad-enum": S.EnumSchema{[J.JBool{True{}}, J.JNumber{"NaN"}]}
    case _: S.BooleanSchema{}

def decode(s: S.Schema, v: J.Json) -> Result<&2, &2, S.Errors(), S.Value>: S.decode(s, v)
def satisfies(s: S.Schema, v: J.Json) -> Bool: Spec.satisfies(s, v)
def matches(p: P.Pattern, s: String) -> Bool: A.matches(p, s)
def derive_matches(p: P.Pattern, s: String) -> Bool: P.matches(p, s)
def pattern_size(p: P.Pattern) -> Nat: P.size(p)

# Whether the automaton's table passes its check, so `A.matches` scans it
# rather than falling back to the derivative matcher.
def table_ok(+p: P.Pattern) -> Bool:
  +bs = A.table_blocks(p)
  A.fits4(bs) && A.check(bs, bs) && A.all_found(bs, A.linear(p))

def table_nodes(p: P.Pattern) -> Nat:
  List.length(&2, A.Node, List.concat(&2, A.Node, A.table_blocks(p)))

# The two arcs of `collision()`'s literal: distinct, with equal keys.
def distinct_equal_keys(+x: A.Arc, +y: A.Arc) -> Bool:
  U32.is_eq(A.arc_hash(x), A.arc_hash(y)) && Bool.not(A.same_arc(x, y))

def colliding_keys() -> Bool:
  distinct_equal_keys(A.Arc{A.AChar{0}, P.Literal{SCon{Chr{1}, ""}}}, A.Arc{A.AChar{1}, P.Literal{""}})
def pattern_spec(p: P.Pattern, s: String) -> Bool: Spec.matches(p, s)
def source(p: P.Pattern) -> String: P.source(p)
def pattern_valid(p: P.Pattern) -> Bool: P.valid(p)
def spec_pattern_ok(p: P.Pattern) -> Bool: Spec.pattern_ok(p)
def spec_order(a: String, b: String) -> Cmp: Spec.order(a, b)
def spec_number(s: String) -> Bool: Spec.number(s)
def spec_integer(s: String) -> Bool: Spec.integer(s)
def parse(s: String) -> Result<&2, &2, J.Error, J.Json>: J.parse_string(s)
def order(a: String, b: String) -> Cmp: D.order(a, b)

def kind(v: S.Value) -> String:
  match v:
    case S.VString{x}: "VString"
    case S.VNumber{x}: "VNumber"
    case S.VInteger{x}: "VInteger"
    case S.VBool{x}: "VBool"
    case S.VLiteral{x}: "VLiteral"
    case S.VNull{}: "VNull"
    case S.VArray{x}: "VArray"
    case S.VObject{x}: "VObject"
    case S.VUnion{i, x}: "VUnion"

def code(c: S.Code) -> String:
  match c:
    case S.InvalidSchema{}: "InvalidSchema"
    case S.TypeMismatch{}: "TypeMismatch"
    case S.Constraint{}: "Constraint"

def written(r: Result<&2, &2, J.Error, String>) -> String:
  match r:
    case Done{s}: s
    case Fail{e}: "write-error"

def report(r: Result<&2, &2, S.Errors(), S.Value>) -> String:
  match r:
    case Done{+v}: "ok:" ++ kind(v) ++ ":" ++ written(J.stringify(S.to_json(v)))
    case Fail{S.Error{c, message, path} <> t}: "error:" ++ code(c)
    case Fail{Nil{}}: "empty-errors"

def run(name: String, parsed: Result<&2, &2, J.Error, J.Json>) -> String:
  match parsed:
    case Fail{e}: "parse-error"
    case Done{v}: report(S.decode(schema(name), v))
