# JSON Schema (draft 2020-12) export of schemas (BND-37). docs/data/json-schema.md
# lists what the exported documents mean and where the decoder's policy is
# stricter than any JSON Schema validator can be.
import Base
import ./json.bend as J
import ./schema.bend as S
import ./schema-pattern.bend as P

def dialect() -> String:
  "https://json-schema.org/draft/2020-12/schema"

def count(n: Nat) -> J.Json:
  J.JNumber{Nat.show(n)}

def kind(name: String) -> J.Field:
  J.Field{"type", J.JString{name}}

# Accepts no value. Empty enums and unions use it, because `enum: []` and
# `anyOf: []` are not valid JSON Schema.
def never() -> J.Json:
  J.JObject{[J.Field{"not", J.JObject{[]}}]}

# The decoder rejects every input when any part of a schema is invalid, so the
# export of an invalid schema accepts nothing either.
def invalid() -> J.Json:
  J.JObject{[J.Field{"$comment", J.JString{"invalid Bendo schema: the decoder rejects every value"}}, J.Field{"not", J.JObject{[]}}]}

# A string holding a lone surrogate. With or without the `u` flag this matches
# exactly the strings that are not well-formed Unicode, which every string
# schema rejects (the Bend JSON parser never produces them).
def lone() -> String:
  "[\\uD800-\\uDBFF](?![\\uDC00-\\uDFFF])|(?<![\\uD800-\\uDBFF])[\\uDC00-\\uDFFF]"

# The email and URL grammars of src/data/schema-text.bend as ECMAScript
# patterns. Every class is ASCII and written with \xHH escapes, so the
# patterns mean the same thing with or without the `u` flag.
def alnum() -> String:
  "[\\x30-\\x39\\x41-\\x5a\\x61-\\x7a]"

def label() -> String:
  alnum() ++ "(?:[\\x2d\\x30-\\x39\\x41-\\x5a\\x61-\\x7a]{0,61}" ++ alnum() ++ ")?"

def hostname() -> String:
  label() ++ "(?:\\x2e" ++ label() ++ ")*"

def atom() -> String:
  "[\\x21\\x23-\\x27\\x2a\\x2b\\x2d\\x2f-\\x39\\x3d\\x3f\\x41-\\x5a\\x5e-\\x7e]+"

# At most 254 in all, a dot-atom local part of at most 64 before the only @,
# then a hostname of at most 253.
def email() -> String:
  "^(?=[\\s\\S]{0,254}(?![\\s\\S]))(?=[^\\x40]{1,64}\\x40)" ++ atom() ++ "(?:\\x2e" ++ atom() ++ ")*\\x40(?=[\\s\\S]{1,253}(?![\\s\\S]))" ++ hostname() ++ "(?![\\s\\S])"

# Decimal 0 to 65535 in one to five digits, leading zeroes allowed.
def port() -> String:
  "(?:[\\x30-\\x39]{1,4}|[\\x30-\\x35][\\x30-\\x39]{4}|\\x36[\\x30-\\x34][\\x30-\\x39]{3}|\\x36\\x35[\\x30-\\x34][\\x30-\\x39]{2}|\\x36\\x35\\x35[\\x30-\\x32][\\x30-\\x39]|\\x36\\x35\\x35\\x33[\\x30-\\x35])"

# Lowercase http or https, a hostname of at most 253 before the first of
# `:/?#`, an optional port, and an optional suffix starting with `/`, `?` or `#`
# made of URI characters and %HH escapes.
def url() -> String:
  "^\\x68\\x74\\x74\\x70\\x73?\\x3a\\x2f\\x2f(?=[^\\x3a\\x2f\\x3f\\x23]{1,253}(?:[\\x3a\\x2f\\x3f\\x23]|(?![\\s\\S])))" ++ hostname() ++ "(?:\\x3a" ++ port() ++ ")?(?:[\\x2f\\x3f\\x23](?:[\\x21\\x23\\x24\\x26-\\x3b\\x3d\\x3f-\\x5b\\x5d\\x5f\\x61-\\x7a\\x7e]|\\x25[\\x30-\\x39\\x41-\\x46\\x61-\\x66]{2})*)?(?![\\s\\S])"

def upper(key: String, n: Maybe<&2, Nat>) -> List<&2, J.Field>:
  match n:
    case None{}: []
    case Some{k}: [J.Field{key, count(k)}]

def bound(key: String, b: Maybe<&2, String>) -> List<&2, J.Field>:
  match b:
    case None{}: []
    case Some{v}: [J.Field{key, J.JNumber{v}}]

def pattern(p: Maybe<&2, P.Pattern>) -> List<&2, J.Field>:
  match p:
    case None{}: []
    case Some{x}: [J.Field{"pattern", J.JString{P.source(x)}}]

def format_check(comment: String, source: String) -> List<&2, J.Field>:
  [J.Field{"allOf", J.JArray{[J.JObject{[J.Field{"$comment", J.JString{comment}}, J.Field{"pattern", J.JString{source}}]}]}}]

def format(f: S.Format) -> List<&2, J.Field>:
  match f:
    case S.Plain{}: []
    case S.Email{}: format_check("Bendo email format: ASCII dot-atom local part, one @, DNS hostname", email())
    case S.Url{}: format_check("Bendo url format: http or https, DNS hostname, optional port and suffix", url())

def string_json(min: Nat, max: Maybe<&2, Nat>, p: Maybe<&2, P.Pattern>, f: S.Format) -> J.Json:
  J.JObject{kind("string") <> J.Field{"minLength", count(min)} <> List.concat(&2, J.Field, [upper("maxLength", max), pattern(p), format(f), [J.Field{"not", J.JObject{[J.Field{"pattern", J.JString{lone()}}]}}]])}

def number_json(min: Maybe<&2, String>, max: Maybe<&2, String>) -> J.Json:
  J.JObject{kind("number") <> List.append(&2, J.Field, bound("minimum", min), bound("maximum", max))}

def integer_json(min: Maybe<&2, String>, max: Maybe<&2, String>) -> J.Json:
  J.JObject{kind("integer") <> List.concat(&2, J.Field, [bound("minimum", min), bound("maximum", max), [J.Field{"$comment", J.JString{"Bendo accepts only integer tokens -?(0|[1-9][0-9]*); 1.0 and 1e0 are rejected"}}]])}

def keep(dup: Bool, x: J.Json, rev: List<&2, J.Json>) -> List<&2, J.Json>:
  match dup:
    case True{}: rev
    case False{}: x <> rev

# Enum members without repeats, first occurrence kept. Numbers compare by
# value, so `1`, `1.0` and `1e0` keep only the first, as `uniqueItems` asks.
def distinct_go(xs: List<&2, J.Json>, +rev: List<&2, J.Json>) -> List<&2, J.Json>:
  match xs:
    case Nil{}: List.reverse(&2, J.Json, rev)
    case +h <> t: distinct_go(t, keep(S.one_of(rev, h, False{}), h, rev))

def distinct(xs: List<&2, J.Json>) -> List<&2, J.Json>:
  distinct_go(xs, [])

def enum_json(xs: List<&2, J.Json>) -> J.Json:
  match xs:
    case Nil{}: never()
    case h <> t: J.JObject{[J.Field{"enum", J.JArray{h <> t}}]}

def array_json(items: J.Json, min: Nat, max: Maybe<&2, Nat>) -> J.Json:
  J.JObject{kind("array") <> J.Field{"items", items} <> J.Field{"minItems", count(min)} <> upper("maxItems", max)}

def required_one(k: String, p: S.Presence, rest: List<&2, J.Json>) -> List<&2, J.Json>:
  match p:
    case S.Required{}: J.JString{k} <> rest
    case S.Optional{}: rest
    case S.Default{d}: rest

def required(fs: List<&2, S.Field>) -> List<&2, J.Json>:
  match fs:
    case Nil{}: []
    case S.Field{k, c, p} <> t: required_one(k, p, required(t))

def open(u: S.Unknown) -> Bool:
  match u:
    case S.Strict{}: False{}
    case S.Strip{}: True{}

def unknown_comment(u: S.Unknown) -> String:
  match u:
    case S.Strict{}: "Bendo rejects an object that repeats a declared key"
    case S.Strip{}: "Bendo rejects an object that repeats a declared key and drops undeclared keys while decoding"

def object_json(props: List<&2, J.Field>, req: List<&2, J.Json>, +u: S.Unknown) -> J.Json:
  J.JObject{[kind("object"), J.Field{"properties", J.JObject{props}}, J.Field{"required", J.JArray{req}}, J.Field{"additionalProperties", J.JBool{open(u)}}, J.Field{"$comment", J.JString{unknown_comment(u)}}]}

# Defaults are annotations: only the Bendo decoder fills them in.
def with_default(j: J.Json, p: S.Presence) -> J.Json:
  match j p:
    case J.JObject{fs} S.Default{d}: J.JObject{List.append(&2, J.Field, fs, [J.Field{"default", d}])}
    case j _: j

def nullable_json(inner: J.Json) -> J.Json:
  J.JObject{[J.Field{"anyOf", J.JArray{[J.JObject{[kind("null")]}, inner]}}]}

def union_json(xs: List<&2, J.Json>) -> J.Json:
  match xs:
    case Nil{}: never()
    case h <> t: J.JObject{[J.Field{"$comment", J.JString{"Bendo decodes with the first matching member"}}, J.Field{"anyOf", J.JArray{h <> t}}]}

# Progress through an object's fields or a union's members.
type Acc is Data:
  AHere{}
  AProps{rev: List<&2, J.Field>, required: List<&2, J.Json>}
  AMembers{rev: List<&2, J.Json>}

def start(s: S.Schema) -> Acc:
  match s:
    case S.ObjectSchema{fs, u}: AProps{[], required(fs)}
    case S.UnionSchema{ms}: AMembers{[]}
    case _: AHere{}

# One def walks the schema, like the decoder: every call descends into a child
# schema or continues the same object or union on a shorter list.
def go(s: S.Schema, acc: Acc) -> J.Json:
  match s acc:
    case S.StringSchema{min, max, p, f} _: string_json(min, max, p, f)
    case S.NumberSchema{min, max} _: number_json(min, max)
    case S.IntegerSchema{min, max} _: integer_json(min, max)
    case S.BooleanSchema{} _: J.JObject{[kind("boolean")]}
    case S.LiteralSchema{v} _: J.JObject{[J.Field{"const", v}]}
    case S.EnumSchema{xs} _: enum_json(distinct(xs))
    case S.ArraySchema{+i, min, max} _: array_json(go(i, start(i)), min, max)
    case S.ObjectSchema{Nil{}, +u} AProps{rev, req}: object_json(List.reverse(&2, J.Field, rev), req, u)
    case S.ObjectSchema{S.Field{k, +c, p} <> t, u} AProps{rev, req}: go(S.ObjectSchema{t, u}, AProps{J.Field{k, with_default(go(c, start(c)), p)} <> rev, req})
    case S.NullableSchema{+i} _: nullable_json(go(i, start(i)))
    case S.UnionSchema{Nil{}} AMembers{rev}: union_json(List.reverse(&2, J.Json, rev))
    case S.UnionSchema{+m <> t} AMembers{rev}: go(S.UnionSchema{t}, AMembers{go(m, start(m)) <> rev})
    case _ _: invalid()

def gated(+s: S.Schema, ok: Bool) -> J.Json:
  match ok:
    case True{}: go(s, start(s))
    case False{}: invalid()

# The JSON Schema for a schema, without `$schema`. Total: an invalid schema
# exports `invalid()`.
def export(+s: S.Schema) -> J.Json:
  gated(s, S.valid(s))

def with_dialect(j: J.Json) -> J.Json:
  match j:
    case J.JObject{fs}: J.JObject{J.Field{"$schema", J.JString{dialect()}} <> fs}
    case j: j

# A standalone document: the export with its `$schema` dialect.
def document(+s: S.Schema) -> J.Json:
  with_dialect(export(s))
