import Base
import ../src/data/schema.bend as S
import ../src/data/json.bend as J
import ../src/data/decimal.bend as D

def finish_accept(v: S.Value, c: Bool) -> {S.accepted(S.finish(v, c)) == c : Bool}:
  match c:
    case True{}: {==}
    case False{}: {==}

def scalar_accept(+s: S.Schema, +v: J.Json) -> {S.accepted(S.decode_scalar(s, v)) == S.predicate(s, v) : Bool}:
  match s v:
    case S.StringSchema{a, b, c, d} J.JString{x}: finish_accept(S.VString{x}, S.string_check(a, b, c, d, x))
    case S.NumberSchema{a, b} J.JNumber{x}: finish_accept(S.VNumber{x}, S.number_check(a, b, x))
    case S.IntegerSchema{a, b} J.JNumber{x}: finish_accept(S.VInteger{x}, D.is_integer(x) && S.number_check(a, b, x))
    case S.BooleanSchema{} J.JBool{x}: {==}
    case S.LiteralSchema{x} y: finish_accept(S.VLiteral{y}, S.scalar(y) && S.same(x, y))
    case S.EnumSchema{xs} y: finish_accept(S.VLiteral{y}, S.scalar(y) && S.one_of(xs, y, False{}))
    case S.StringSchema{a, b, c, d} J.JNull{}: {==}
    case S.StringSchema{a, b, c, d} J.JBool{x}: {==}
    case S.StringSchema{a, b, c, d} J.JNumber{x}: {==}
    case S.StringSchema{a, b, c, d} J.JArray{xs}: {==}
    case S.StringSchema{a, b, c, d} J.JObject{fs}: {==}
    case S.NumberSchema{a, b} J.JNull{}: {==}
    case S.NumberSchema{a, b} J.JBool{x}: {==}
    case S.NumberSchema{a, b} J.JString{x}: {==}
    case S.NumberSchema{a, b} J.JArray{xs}: {==}
    case S.NumberSchema{a, b} J.JObject{fs}: {==}
    case S.IntegerSchema{a, b} J.JNull{}: {==}
    case S.IntegerSchema{a, b} J.JBool{x}: {==}
    case S.IntegerSchema{a, b} J.JString{x}: {==}
    case S.IntegerSchema{a, b} J.JArray{xs}: {==}
    case S.IntegerSchema{a, b} J.JObject{fs}: {==}
    case S.BooleanSchema{} J.JNull{}: {==}
    case S.BooleanSchema{} J.JNumber{x}: {==}
    case S.BooleanSchema{} J.JString{x}: {==}
    case S.BooleanSchema{} J.JArray{xs}: {==}
    case S.BooleanSchema{} J.JObject{fs}: {==}

def acceptance(+s: S.Schema, +v: J.Json, c: Bool) -> {S.accepted(S.decode_valid(s, v, c)) == (c && S.predicate(s, v)) : Bool}:
  match c:
    case True{}: scalar_accept(s, v)
    case False{}: {==}

def finish_preserves(+v: S.Value, c: Bool) -> S.Preserves(Some{v}, S.finish(v, c)):
  match c:
    case True{}: {==}
    case False{}: Unit{}

def scalar_preserves(+s: S.Schema, +v: J.Json) -> S.Preserves(S.value_for(s, v), S.decode_scalar(s, v)):
  match s v:
    case S.StringSchema{a, b, c, d} J.JString{x}: finish_preserves(S.VString{x}, S.string_check(a, b, c, d, x))
    case S.NumberSchema{a, b} J.JNumber{x}: finish_preserves(S.VNumber{x}, S.number_check(a, b, x))
    case S.IntegerSchema{a, b} J.JNumber{x}: finish_preserves(S.VInteger{x}, D.is_integer(x) && S.number_check(a, b, x))
    case S.BooleanSchema{} J.JBool{x}: {==}
    case S.LiteralSchema{x} y: finish_preserves(S.VLiteral{y}, S.scalar(y) && S.same(x, y))
    case S.EnumSchema{xs} y: finish_preserves(S.VLiteral{y}, S.scalar(y) && S.one_of(xs, y, False{}))
    case S.StringSchema{a, b, c, d} J.JNull{}: Unit{}
    case S.StringSchema{a, b, c, d} J.JBool{x}: Unit{}
    case S.StringSchema{a, b, c, d} J.JNumber{x}: Unit{}
    case S.StringSchema{a, b, c, d} J.JArray{xs}: Unit{}
    case S.StringSchema{a, b, c, d} J.JObject{fs}: Unit{}
    case S.NumberSchema{a, b} J.JNull{}: Unit{}
    case S.NumberSchema{a, b} J.JBool{x}: Unit{}
    case S.NumberSchema{a, b} J.JString{x}: Unit{}
    case S.NumberSchema{a, b} J.JArray{xs}: Unit{}
    case S.NumberSchema{a, b} J.JObject{fs}: Unit{}
    case S.IntegerSchema{a, b} J.JNull{}: Unit{}
    case S.IntegerSchema{a, b} J.JBool{x}: Unit{}
    case S.IntegerSchema{a, b} J.JString{x}: Unit{}
    case S.IntegerSchema{a, b} J.JArray{xs}: Unit{}
    case S.IntegerSchema{a, b} J.JObject{fs}: Unit{}
    case S.BooleanSchema{} J.JNull{}: Unit{}
    case S.BooleanSchema{} J.JNumber{x}: Unit{}
    case S.BooleanSchema{} J.JString{x}: Unit{}
    case S.BooleanSchema{} J.JArray{xs}: Unit{}
    case S.BooleanSchema{} J.JObject{fs}: Unit{}

def preservation(+s: S.Schema, +v: J.Json, c: Bool) -> S.Preserves(S.value_for(s, v), S.decode_valid(s, v, c)):
  match c:
    case True{}: scalar_preserves(s, v)
    case False{}: Unit{}
