import Base
import ../../../src/data/schema.bend as S
import ../../../src/data/json.bend as J
import ../../../src/data/decimal.bend as D

def schema(name: String) -> S.Schema:
  match name:
    case "text": S.StringSchema{0n, None{}, None{}, S.Plain{}}
    case "length": S.StringSchema{1n, Some{3n}, None{}, S.Plain{}}
    case "empty": S.StringSchema{0n, Some{0n}, None{}, S.Plain{}}
    case "exact": S.StringSchema{2n, Some{2n}, None{}, S.Plain{}}
    case "pattern": S.StringSchema{0n, None{}, Some{S.Class{[S.Range{97, 122}, S.Range{48, 57}], 1n, Some{4n}}}, S.Plain{}}
    case "star": S.StringSchema{0n, None{}, Some{S.Class{[S.Range{97, 97}], 0n, None{}}}, S.Plain{}}
    case "plus": S.StringSchema{0n, None{}, Some{S.Class{[S.Range{97, 97}], 1n, None{}}}, S.Plain{}}
    case "optional": S.StringSchema{0n, None{}, Some{S.Class{[S.Range{97, 97}], 0n, Some{1n}}}, S.Plain{}}
    case "pattern-exact": S.StringSchema{0n, None{}, Some{S.Class{[S.Range{97, 97}], 2n, Some{2n}}}, S.Plain{}}
    case "no-ranges": S.StringSchema{0n, None{}, Some{S.Class{[], 0n, None{}}}, S.Plain{}}
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
    case "bad-pattern": S.StringSchema{0n, None{}, Some{S.Class{[S.Range{122, 97}], 0n, None{}}}, S.Plain{}}
    case "bad-ascii": S.StringSchema{0n, None{}, Some{S.Class{[S.Range{0, 128}], 0n, None{}}}, S.Plain{}}
    case "bad-count": S.StringSchema{0n, None{}, Some{S.Class{[S.Range{97, 97}], 2n, Some{1n}}}, S.Plain{}}
    case "bad-literal": S.LiteralSchema{J.JArray{[]}}
    case "bad-enum": S.EnumSchema{[J.JBool{True{}}, J.JNumber{"NaN"}]}
    case _: S.BooleanSchema{}

def decode(s: S.Schema, v: J.Json) -> Result<&2, &2, S.Errors(), S.Value>: S.decode(s, v)
def satisfies(s: S.Schema, v: J.Json) -> Bool: S.satisfies(s, v)
def parse(s: String) -> Result<&2, &2, J.Error, J.Json>: J.parse_string(s)
def order(a: String, b: String) -> Cmp: D.order(a, b)

def kind(v: S.Value) -> String:
  match v:
    case S.VString{x}: "VString"
    case S.VNumber{x}: "VNumber"
    case S.VInteger{x}: "VInteger"
    case S.VBool{x}: "VBool"
    case S.VLiteral{x}: "VLiteral"

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
