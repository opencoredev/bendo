# What the JSON Schema export must contain, read from schemas alone (BND-37).
# It never calls the exporter's own helpers: it looks a keyword up in an
# exported object and states, kind by kind, what that keyword holds.
import Base
import ../src/data/json.bend as J
import ../src/data/schema.bend as S
import ../src/data/schema-pattern.bend as P

def pick(same: Bool, v: J.Json, rest: Maybe<&2, J.Json>) -> Maybe<&2, J.Json>:
  match same:
    case True{}: Some{v}
    case False{}: rest

def first(fs: List<&2, J.Field>, +name: String) -> Maybe<&2, J.Json>:
  match fs:
    case Nil{}: None{}
    case J.Field{k, v} <> t: pick(String.eq(k, name), v, first(t, name))

# The first member named `name` of a JSON object; None for any other value.
def keyword(j: J.Json, name: String) -> Maybe<&2, J.Json>:
  match j:
    case J.JNull{}: None{}
    case J.JBool{b}: None{}
    case J.JNumber{n}: None{}
    case J.JString{s}: None{}
    case J.JArray{xs}: None{}
    case J.JObject{fs}: first(fs, name)

# The JSON type each kind requires. Literals, enums, nullables and unions
# allow several types, so their nodes carry no `type`.
def type_of(s: S.Schema) -> Maybe<&2, J.Json>:
  match s:
    case S.StringSchema{a, b, c, d}: Some{J.JString{"string"}}
    case S.NumberSchema{a, b}: Some{J.JString{"number"}}
    case S.IntegerSchema{a, b}: Some{J.JString{"integer"}}
    case S.BooleanSchema{}: Some{J.JString{"boolean"}}
    case S.LiteralSchema{v}: None{}
    case S.EnumSchema{xs}: None{}
    case S.ArraySchema{i, a, b}: Some{J.JString{"array"}}
    case S.ObjectSchema{fs, u}: Some{J.JString{"object"}}
    case S.NullableSchema{i}: None{}
    case S.UnionSchema{ms}: None{}

def is_required(p: S.Presence) -> Bool:
  match p:
    case S.Required{}: True{}
    case S.Optional{}: False{}
    case S.Default{d}: False{}

def keep(yes: Bool, x: J.Json, rest: List<&2, J.Json>) -> List<&2, J.Json>:
  match yes:
    case True{}: x <> rest
    case False{}: rest

# The keys of the Required fields, in schema order. Optional and defaulted
# fields may be absent, so they are never required.
def required(fs: List<&2, S.Field>) -> List<&2, J.Json>:
  match fs:
    case Nil{}: []
    case S.Field{k, c, p} <> t: keep(is_required(p), J.JString{k}, required(t))

# Whether undeclared keys are allowed: Strip ignores them, Strict rejects them.
def allows_unknown(u: S.Unknown) -> Bool:
  match u:
    case S.Strict{}: False{}
    case S.Strip{}: True{}

# The top-level `pattern`: exactly the ECMAScript source of the schema's own
# pattern, and none without one (format checks live under `allOf`).
def pattern_of(p: Maybe<&2, P.Pattern>) -> Maybe<&2, J.Json>:
  match p:
    case None{}: None{}
    case Some{x}: Some{J.JString{P.source(x)}}

def upper_of(n: Maybe<&2, Nat>) -> Maybe<&2, J.Json>:
  match n:
    case None{}: None{}
    case Some{k}: Some{J.JNumber{Nat.show(k)}}
