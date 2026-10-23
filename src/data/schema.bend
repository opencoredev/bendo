# Copyable scalar schema metadata and pure native/browser decoder (decision 0003).
import Base
import ./json.bend as J
import ./decimal.bend as D
import ./schema-text.bend as T
import ./schema-pattern.bend as P
import ./schema-pattern-automaton.bend as A

type Format is Data:
  Plain{}
  Email{}
  Url{}

# Composite variants join this same data type in BND-34.
type Schema is Data:
  StringSchema{min_len: Nat, max_len: Maybe<&2, Nat>, pattern: Maybe<&2, P.Pattern>, format: Format}
  NumberSchema{min: Maybe<&2, String>, max: Maybe<&2, String>}
  IntegerSchema{min: Maybe<&2, String>, max: Maybe<&2, String>}
  BooleanSchema{}
  LiteralSchema{value: J.Json}
  EnumSchema{values: List<&2, J.Json>}

type Value is Data:
  VString{value: String}
  VNumber{value: String}
  VInteger{value: String}
  VBool{value: Bool}
  VLiteral{value: J.Json}

type PathPart is Data:
  PathKey{value: String}
  PathIndex{value: Nat}

type Code is Data:
  InvalidSchema{}
  TypeMismatch{}
  Constraint{}

type Error is Data:
  Error{code: Code, message: String, path: List<&2, PathPart>}

def Errors() -> Data:
  List<&2, Error>

def max_length(limit: Maybe<&2, Nat>, n: Nat) -> Bool:
  match limit:
    case None{}: True{}
    case Some{k}: Nat.is_le(n, k)

def pattern_check(p: Maybe<&2, P.Pattern>, s: String) -> Bool:
  match p:
    case None{}: True{}
    case Some{x}: A.matches(x, s)

def optional_pattern_valid(p: Maybe<&2, P.Pattern>) -> Bool:
  match p:
    case None{}: True{}
    case Some{x}: P.valid(x)

def format_check(f: Format, s: String) -> Bool:
  match f:
    case Plain{}: True{}
    case Email{}: T.email(s)
    case Url{}: T.url(s)

def format_after(ok: Bool, f: Format, s: String) -> Bool:
  match ok:
    case False{}: False{}
    case True{}: format_check(f, s)

def pattern_after(ok: Bool, p: Maybe<&2, P.Pattern>, f: Format, +s: String) -> Bool:
  match ok:
    case False{}: False{}
    case True{}: format_after(pattern_check(p, s), f, s)

# Cheapest first, each step only after the last passed: a text that fails
# its counts never reaches the matcher, and one that fails the pattern never
# reaches the format grammar.
def string_check(min: Nat, max: Maybe<&2, Nat>, p: Maybe<&2, P.Pattern>, f: Format, +s: String) -> Bool:
  pattern_after(J.scalars(s) && Nat.is_le(min, D.length(s)) && max_length(max, D.length(s)), p, f, s)

def bound_valid(b: Maybe<&2, String>) -> Bool:
  match b:
    case None{}: True{}
    case Some{s}: J.number_valid(s)

def lower(b: Maybe<&2, String>, s: String) -> Bool:
  match b:
    case None{}: True{}
    case Some{v}: Cmp.is_ge(D.order(s, v))

def upper(b: Maybe<&2, String>, s: String) -> Bool:
  match b:
    case None{}: True{}
    case Some{v}: Cmp.is_le(D.order(s, v))

def bounds_order(min: Maybe<&2, String>, max: Maybe<&2, String>) -> Bool:
  match min max:
    case Some{a} Some{b}: Cmp.is_le(D.order(a, b))
    case _ _: True{}

def bounds_valid(+min: Maybe<&2, String>, +max: Maybe<&2, String>) -> Bool:
  bound_valid(min) && bound_valid(max) && bounds_order(min, max)

def number_check(min: Maybe<&2, String>, max: Maybe<&2, String>, +s: String) -> Bool:
  J.number_valid(s) && lower(min, s) && upper(max, s)

def scalar(v: J.Json) -> Bool:
  match v:
    case J.JNull{}: True{}
    case J.JBool{b}: True{}
    case J.JString{s}: J.scalars(s)
    case J.JNumber{s}: J.number_valid(s)
    case _: False{}

def literals_valid(xs: List<&2, J.Json>, ok: Bool) -> Bool:
  match xs:
    case Nil{}: ok
    case h <> t: literals_valid(t, ok && scalar(h))

# JSON const/enum equality: exact numerical equality, lexical text equality.
def same(a: J.Json, b: J.Json) -> Bool:
  match a b:
    case J.JNull{} J.JNull{}: True{}
    case J.JBool{True{}} J.JBool{y}: y
    case J.JBool{False{}} J.JBool{y}: Bool.not(y)
    case J.JString{x} J.JString{y}: String.eq(x, y)
    case J.JNumber{x} J.JNumber{y}: Cmp.is_eq(D.order(x, y))
    case _ _: False{}

def one_of(xs: List<&2, J.Json>, +v: J.Json, found: Bool) -> Bool:
  match xs:
    case Nil{}: found
    case h <> t: one_of(t, v, found || same(h, v))

def valid(s: Schema) -> Bool:
  match s:
    case StringSchema{min, max, p, f}: max_length(max, min) && optional_pattern_valid(p)
    case NumberSchema{min, max}: bounds_valid(min, max)
    case IntegerSchema{min, max}: bounds_valid(min, max)
    case BooleanSchema{}: True{}
    case LiteralSchema{v}: scalar(v)
    case EnumSchema{xs}: literals_valid(xs, True{})

def failure(code: Code, message: String) -> Result<&2, &2, Errors(), Value>:
  Fail{[Error{code, message, []}]}

def finish(v: Value, accepted: Bool) -> Result<&2, &2, Errors(), Value>:
  match accepted:
    case True{}: Done{v}
    case False{}: failure(Constraint{}, "value does not satisfy scalar checks")

def decode_scalar(s: Schema, v: J.Json) -> Result<&2, &2, Errors(), Value>:
  match s v:
    case StringSchema{min, max, p, f} J.JString{+x}: finish(VString{x}, string_check(min, max, p, f, x))
    case NumberSchema{min, max} J.JNumber{+x}: finish(VNumber{x}, number_check(min, max, x))
    case IntegerSchema{min, max} J.JNumber{+x}: finish(VInteger{x}, D.is_integer(x) && number_check(min, max, x))
    case BooleanSchema{} J.JBool{x}: Done{VBool{x}}
    case LiteralSchema{x} +y: finish(VLiteral{y}, scalar(y) && same(x, y))
    case EnumSchema{xs} +y: finish(VLiteral{y}, scalar(y) && one_of(xs, y, False{}))
    case _ _: failure(TypeMismatch{}, "expected schema scalar kind")

def decode_valid(s: Schema, v: J.Json, schema_ok: Bool) -> Result<&2, &2, Errors(), Value>:
  match schema_ok:
    case True{}: decode_scalar(s, v)
    case False{}: failure(InvalidSchema{}, "invalid scalar schema")

def decode(+s: Schema, v: J.Json) -> Result<&2, &2, Errors(), Value>:
  decode_valid(s, v, valid(s))

def accepted(r: Result<&2, &2, Errors(), Value>) -> Bool:
  match r:
    case Fail{e}: False{}
    case Done{x}: True{}

def to_json(v: Value) -> J.Json:
  match v:
    case VString{x}: J.JString{x}
    case VNumber{x}: J.JNumber{x}
    case VInteger{x}: J.JNumber{x}
    case VBool{x}: J.JBool{x}
    case VLiteral{x}: x

# Independent shape/payload contract used by the preservation law.
def value_for(s: Schema, v: J.Json) -> Maybe<&2, Value>:
  match s v:
    case StringSchema{a, b, c, d} J.JString{x}: Some{VString{x}}
    case NumberSchema{a, b} J.JNumber{x}: Some{VNumber{x}}
    case IntegerSchema{a, b} J.JNumber{x}: Some{VInteger{x}}
    case BooleanSchema{} J.JBool{x}: Some{VBool{x}}
    case LiteralSchema{x} y: Some{VLiteral{y}}
    case EnumSchema{xs} y: Some{VLiteral{y}}
    case _ _: None{}

def Preserves(expected: Maybe<&2, Value>, r: Result<&2, &2, Errors(), Value>) -> Type:
  match r:
    case Fail{e}: Unit
    case Done{x}: {Some{x} == expected : Maybe<&2, Value>}
