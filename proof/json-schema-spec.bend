# What the JSON Schema export must contain, read from schemas alone (BND-37).
# It never calls the exporter's own helpers: it looks a keyword up in an
# exported object and states, kind by kind, what that keyword holds.
import Base
import ../src/data/decimal.bend as D
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

# Specification-owned ECMAScript source.
def lone() -> String:
  "[\\uD800-\\uDBFF](?![\\uDC00-\\uDFFF])|(?<![\\uD800-\\uDBFF])[\\uDC00-\\uDFFF]"

# Specification-owned ECMAScript source.
def email() -> String:
  "^(?=[\\s\\S]{0,254}(?![\\s\\S]))(?=[^\\x40]{1,64}\\x40)[\\x21\\x23-\\x27\\x2a\\x2b\\x2d\\x2f-\\x39\\x3d\\x3f\\x41-\\x5a\\x5e-\\x7e]+(?:\\x2e[\\x21\\x23-\\x27\\x2a\\x2b\\x2d\\x2f-\\x39\\x3d\\x3f\\x41-\\x5a\\x5e-\\x7e]+)*\\x40(?=[\\s\\S]{1,253}(?![\\s\\S]))[\\x30-\\x39\\x41-\\x5a\\x61-\\x7a](?:[\\x2d\\x30-\\x39\\x41-\\x5a\\x61-\\x7a]{0,61}[\\x30-\\x39\\x41-\\x5a\\x61-\\x7a])?(?:\\x2e[\\x30-\\x39\\x41-\\x5a\\x61-\\x7a](?:[\\x2d\\x30-\\x39\\x41-\\x5a\\x61-\\x7a]{0,61}[\\x30-\\x39\\x41-\\x5a\\x61-\\x7a])?)*(?![\\s\\S])"

# Specification-owned ECMAScript source.
def url() -> String:
  "^\\x68\\x74\\x74\\x70\\x73?\\x3a\\x2f\\x2f(?=[^\\x3a\\x2f\\x3f\\x23]{1,253}(?:[\\x3a\\x2f\\x3f\\x23]|(?![\\s\\S])))[\\x30-\\x39\\x41-\\x5a\\x61-\\x7a](?:[\\x2d\\x30-\\x39\\x41-\\x5a\\x61-\\x7a]{0,61}[\\x30-\\x39\\x41-\\x5a\\x61-\\x7a])?(?:\\x2e[\\x30-\\x39\\x41-\\x5a\\x61-\\x7a](?:[\\x2d\\x30-\\x39\\x41-\\x5a\\x61-\\x7a]{0,61}[\\x30-\\x39\\x41-\\x5a\\x61-\\x7a])?)*(?:\\x3a(?:[\\x30-\\x39]{1,4}|[\\x30-\\x35][\\x30-\\x39]{4}|\\x36[\\x30-\\x34][\\x30-\\x39]{3}|\\x36\\x35[\\x30-\\x34][\\x30-\\x39]{2}|\\x36\\x35\\x35[\\x30-\\x32][\\x30-\\x39]|\\x36\\x35\\x35\\x33[\\x30-\\x35]))?(?:[\\x2f\\x3f\\x23](?:[\\x21\\x23\\x24\\x26-\\x3b\\x3d\\x3f-\\x5b\\x5d\\x5f\\x61-\\x7a\\x7e]|\\x25[\\x30-\\x39\\x41-\\x46\\x61-\\x66]{2})*)?(?![\\s\\S])"

# Add an annotation only to a defaulted field, preserving the child node.
def annotate(j: J.Json, p: S.Presence) -> J.Json:
  match j p:
    case J.JObject{fs} S.Default{d}: J.JObject{List.append(&2, J.Field, fs, [J.Field{"default", d}])}
    case j _: j

# Forward order is the declared order, including the exact child export.
# The caller supplies the child operation; this module never imports X.
def properties(~node: S.Schema -> J.Json, fs: List<&2, S.Field>) -> List<&2, J.Field>:
  match fs:
    case Nil{}: []
    case S.Field{k, c, p} <> t: J.Field{k, annotate(node(c), p)} <> properties(~node, t)

def nodes(~node: S.Schema -> J.Json, ms: List<&2, S.Schema>) -> List<&2, J.Json>:
  match ms:
    case Nil{}: []
    case m <> t: node(m) <> nodes(~node, t)

def nullable(inner: J.Json) -> J.Json:
  J.JObject{[J.Field{"anyOf", J.JArray{[J.JObject{[J.Field{"type", J.JString{"null"}}]}, inner]}}]}

def union(ms: List<&2, J.Json>) -> J.Json:
  match ms:
    case Nil{}: J.JObject{[J.Field{"not", J.JObject{[]}}]}
    case h <> t: J.JObject{[J.Field{"$comment", J.JString{"Bendo decodes with the first matching member"}}, J.Field{"anyOf", J.JArray{h <> t}}]}

def bound(key: String, n: Maybe<&2, String>) -> List<&2, J.Field>:
  match n:
    case None{}: []
    case Some{v}: [J.Field{key, J.JNumber{v}}]

def count_bound(key: String, n: Maybe<&2, Nat>) -> List<&2, J.Field>:
  match n:
    case None{}: []
    case Some{v}: [J.Field{key, J.JNumber{Nat.show(v)}}]

def number(kind: String, min: Maybe<&2, String>, max: Maybe<&2, String>, tail: List<&2, J.Field>) -> J.Json:
  J.JObject{J.Field{"type", J.JString{kind}} <> List.concat(&2, J.Field, [bound("minimum", min), bound("maximum", max), tail])}

def array(inner: J.Json, min: Nat, max: Maybe<&2, Nat>) -> J.Json:
  J.JObject{J.Field{"type", J.JString{"array"}} <> J.Field{"items", inner} <> J.Field{"minItems", J.JNumber{Nat.show(min)}} <> count_bound("maxItems", max)}

def format(f: S.Format) -> Maybe<&2, J.Json>:
  match f:
    case S.Plain{}: None{}
    case S.Email{}: Some{J.JArray{[J.JObject{[J.Field{"$comment", J.JString{"Bendo email format: ASCII dot-atom local part, one @, DNS hostname"}}, J.Field{"pattern", J.JString{email()}}]}]}}
    case S.Url{}: Some{J.JArray{[J.JObject{[J.Field{"$comment", J.JString{"Bendo url format: http or https, DNS hostname, optional port and suffix"}}, J.Field{"pattern", J.JString{url()}}]}]}}

# JSON scalar equality, independently stated. Arrays/objects cannot be
# enum members of a valid schema. Decimal spelling does not affect equality.
def same(a: J.Json, b: J.Json) -> Bool:
  match a b:
    case J.JNull{} J.JNull{}: True{}
    case J.JBool{True{}} J.JBool{y}: y
    case J.JBool{False{}} J.JBool{y}: Bool.not(y)
    case J.JString{x} J.JString{y}: String.eq(x, y)
    case J.JNumber{x} J.JNumber{y}: Cmp.is_eq(D.order(x, y))
    case _ _: False{}

def contains(xs: List<&2, J.Json>, +v: J.Json, found: Bool) -> Bool:
  match xs:
    case Nil{}: found
    case h <> t: contains(t, v, found || same(h, v))

def unseen(seen: Bool, x: J.Json, rev: List<&2, J.Json>) -> List<&2, J.Json>:
  match seen:
    case True{}: rev
    case False{}: x <> rev

# Scan left to right, retaining the first representative of each value.
def unique(xs: List<&2, J.Json>, +rev: List<&2, J.Json>) -> List<&2, J.Json>:
  match xs:
    case Nil{}: List.reverse(&2, J.Json, rev)
    case +h <> t: unique(t, unseen(contains(rev, h, False{}), h, rev))

def enum(xs: List<&2, J.Json>) -> J.Json:
  match xs:
    case Nil{}: J.JObject{[J.Field{"not", J.JObject{[]}}]}
    case h <> t: J.JObject{[J.Field{"enum", J.JArray{h <> t}}]}

# Standalone documents use the specified dialect, independently of X.dialect.
def document(j: J.Json) -> J.Json:
  match j:
    case J.JObject{fs}: J.JObject{J.Field{"$schema", J.JString{"https://json-schema.org/draft/2020-12/schema"}} <> fs}
    case j: j

# Exact outer fields: no extra or duplicate keyword can narrow a node.
def pattern_members(p: Maybe<&2, P.Pattern>) -> List<&2, J.Field>:
  match p:
    case None{}: []
    case Some{x}: [J.Field{"pattern", J.JString{P.source(x)}}]

def format_members(f: S.Format) -> List<&2, J.Field>:
  match f:
    case S.Plain{}: []
    case S.Email{}: [J.Field{"allOf", J.JArray{[J.JObject{[J.Field{"$comment", J.JString{"Bendo email format: ASCII dot-atom local part, one @, DNS hostname"}}, J.Field{"pattern", J.JString{email()}}]}]}}]
    case S.Url{}: [J.Field{"allOf", J.JArray{[J.JObject{[J.Field{"$comment", J.JString{"Bendo url format: http or https, DNS hostname, optional port and suffix"}}, J.Field{"pattern", J.JString{url()}}]}]}}]

def string(min: Nat, max: Maybe<&2, Nat>, p: Maybe<&2, P.Pattern>, f: S.Format) -> J.Json:
  J.JObject{J.Field{"type", J.JString{"string"}} <> J.Field{"minLength", J.JNumber{Nat.show(min)}} <> List.concat(&2, J.Field, [count_bound("maxLength", max), pattern_members(p), format_members(f), [J.Field{"not", J.JObject{[J.Field{"pattern", J.JString{lone()}}]}}]])}

def unknown_comment(u: S.Unknown) -> String:
  match u:
    case S.Strict{}: "Bendo rejects an object that repeats a declared key"
    case S.Strip{}: "Bendo rejects an object that repeats a declared key and drops undeclared keys while decoding"

def object(props: List<&2, J.Field>, req: List<&2, J.Json>, +u: S.Unknown) -> J.Json:
  J.JObject{[J.Field{"type", J.JString{"object"}}, J.Field{"properties", J.JObject{props}}, J.Field{"required", J.JArray{req}}, J.Field{"additionalProperties", J.JBool{allows_unknown(u)}}, J.Field{"$comment", J.JString{unknown_comment(u)}}]}
