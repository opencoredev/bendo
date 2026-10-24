# Schemas

Import `src/data/schema.bend` to describe the shape of JSON as copyable Bend
`Data` and decode a parsed `Json.Json`. Scalar schemas check one value; array,
object, nullable and union schemas compose them. The same pure decoder compiles
to native code and `.mjs`. This is the foundation for generated record decoders
in decision [0003](../decisions/0003-typed-values.md).

```python
import Base
import ../../src/data/schema.bend as S
import ../../src/data/json.bend as J

def title_schema() -> S.Schema:
  S.StringSchema{1n, Some{80n}, None{}, S.Plain{}}

def title() -> Result<&2, &2, S.Errors(), S.Value>:
  S.decode(title_schema(), J.JString{"Hello"})
```

The result is `Done{VString{"Hello"}}`. A generated record decoder can match
`VString` and pass its `String` field directly to a typed record constructor.

## Schema and value types

`Schema` contains six scalar constructors and four compound ones, described in
[Compound schemas](#compound-schemas):

```python
type Schema is Data:
  StringSchema{min_len: Nat, max_len: Maybe<&2, Nat>, pattern: Maybe<&2, Pattern>, format: Format}
  NumberSchema{min: Maybe<&2, String>, max: Maybe<&2, String>}
  IntegerSchema{min: Maybe<&2, String>, max: Maybe<&2, String>}
  BooleanSchema{}
  LiteralSchema{value: Json.Json}
  EnumSchema{values: List<&2, Json.Json>}
  ArraySchema{items: Schema, min_items: Nat, max_items: Maybe<&2, Nat>}
  ObjectSchema{fields: List<&2, Field>, unknown: Unknown}
  NullableSchema{inner: Schema}
  UnionSchema{members: List<&2, Schema>}
```

`decode(schema, json)` returns `Result<&2, &2, Errors(), Value>`.
`Errors()` is `List<&2, Error>`; each error has a `Code`, a message, and a
`List<&2, PathPart>` leading from the root to the failing location through
`PathKey{String}` (an object key) and `PathIndex{Nat}` (an array position). A
rejection lists every failing location, up to 100; see [Errors](#errors).
`decode_first` stops at the first failure and returns one error.

Successful scalar values are `VString{String}`, `VNumber{String}`,
`VInteger{String}`, `VBool{Bool}`, or `VLiteral{Json.Json}`. Numbers retain the
input spelling exactly. Integer values are validated decimals, rather than
bounded machine integers. `to_json(value)` reconstructs the input; for compound
values it omits absent fields and keys that `Strip{}` dropped.

All bounds are inclusive. `None{}` means no upper length or numeric bound.
Number bounds use valid JSON number tokens and exact decimal ordering; they
never convert to floats, round, or expand exponent-sized strings. Mantissas and
exponents may have arbitrarily many digits. Negative zero compares equal to zero.
The comparator works on coefficient digits and a signed decimal order; its work
and storage depend on the token lengths, rather than their numerical magnitude.

Integer tokens follow `-?(0|[1-9][0-9]*)`. Thus `-0` is accepted, while `1.0`
and `1e0` are rejected even though they are mathematically integral. Integer
bounds may be fractional: `min="-3.5"` permits `-3` and rejects `-4`.
This lexical integer policy is stricter than JSON Schema's mathematical
`integer`; the [JSON Schema export](json-schema.md#decoder-policy-and-validator-differences)
records it as decoder policy. Browser consumers must
preserve JSON numeric tokens, for example with the Bend JSON parser compiled to
`.mjs`. Passing numbers through `JSON.parse` loses precision and token spelling.

Literals and enum members are scalar JSON values, including null. Numbers use
exact numerical equality (`1`, `1.0`, and `1e0` match); strings and booleans use
value equality. The returned `VLiteral` holds the input, preserving its spelling.
An empty enum accepts nothing. Arrays and objects are invalid literal metadata.

String lengths count Unicode scalar values, so `"😀"` has length one. Lone
surrogates are rejected even without other string checks. Length zero and equal
minimum/maximum bounds are supported.

## Patterns

Patterns are Bend data from `src/data/schema-pattern.bend`; there is no regex
source parser. A pattern always matches the whole string.

```python
type Range is Data:
  Range{lo: U32, hi: U32}

type Pattern is Data:
  Literal{text: String}
  Class{ranges: List<&2, Range>}
  Cat{first: Pattern, second: Pattern}
  Repeat{body: Pattern, min: Nat, max: Maybe<&2, Nat>}
```

`Literal{x}` matches exactly the text `x`, which may hold any Unicode scalar
values. `Class{rs}` matches one scalar inside one of its inclusive ranges.
Ranges must satisfy `0 <= lo <= hi <= 127`, so classes are ASCII: a non-ASCII
scalar never matches a class, but a literal can match it. Ranges may overlap,
and an empty class matches nothing. `Cat{a, b}` matches `a` followed by `b`;
`P.seq([p1, p2, ...])` builds a sequence, and `seq([])` is `Literal{""}`.
`Repeat{p, m, Some{n}}` matches `p` between `m` and `n` times, and
`Repeat{p, m, None{}}` matches it at least `m` times. The body can be any
pattern, including a sequence, so repetition groups as well as quantifies.
Counts must satisfy `m <= n`.

These two patterns are a lowercase slug and a US ZIP code:

```python
import ../../src/data/schema-pattern.bend as P

def lower() -> P.Pattern:
  P.Class{[P.Range{97, 122}, P.Range{48, 57}]}

def digit() -> P.Pattern:
  P.Class{[P.Range{48, 57}]}

# [a-z0-9]+(-[a-z0-9]+)*
def slug() -> P.Pattern:
  P.seq([P.Repeat{lower(), 1n, None{}}, P.Repeat{P.Cat{P.Literal{"-"}, P.Repeat{lower(), 1n, None{}}}, 0n, None{}}])

# \d{5}(-\d{4})?
def zip() -> P.Pattern:
  P.seq([P.Repeat{digit(), 5n, Some{5n}}, P.Repeat{P.Cat{P.Literal{"-"}, P.Repeat{digit(), 4n, Some{4n}}}, 0n, Some{1n}}])
```

The decoder matches with `A.matches(p, s)` from
`src/data/schema-pattern-automaton.bend`. It first compiles the pattern into a
table of nodes. Each node is one arc: an atom (a literal scalar or a class) and
the residual pattern left to match after it, as Antimirov partial derivatives
give them. A follow set is four 32-bit words with one bit per node. For each
scalar, one pass over the nodes ORs the follow sets of the nodes that are set
in the current follow set and whose atom reads the scalar. The work per scalar
is proportional to the node count and never to the size of a residual pattern.
Once the follow set is empty, no longer text can match and the scan stops
without reading the rest. Whether the text matches is decided once, at the end,
from the nodes that read the last scalar. Every loop over the text is a tail
call in native code and `.mjs`. There are no alternations, captures,
backreferences, lookarounds, or negated classes.

The closure that builds the table is not trusted. Before the table is used, a
check confirms that it has at most four blocks of 32 nodes and that every arc
of every residual is one of its nodes. A table that fails the check is never
used: `P.matches`, the proven derivative matcher, runs instead. The closure
compares arcs by key and then structurally, so two different arcs with equal
keys both become nodes. No valid pattern is known to fail the check, but that
is tested, not proven. `tests/schema.test.ts` builds tables for 1,000
generated patterns, about a third of them near the size cap, and requires
every one to pass. A failing pattern would still match correctly, only slower.

### Size cap

Every part of a valid pattern has an expanded size of at most 128. The expanded
size counts nodes after each repetition is written out as copies of its body: a
literal counts 1 plus its scalars, a class 1, a `Cat` 1 plus both parts, and a
`Repeat` 1 plus the body's size times its copies. `{m,n}` makes `n` copies and
`{m,}` makes `m + 1`. A repetition may also have at most 128 copies. The size
depends on how the body is written: a one-scalar class counts 1, but a
one-scalar literal counts 2.

| Pattern | Expanded size | Valid |
| --- | --- | --- |
| `Repeat{Class{[Range{97, 97}]}, 0n, Some{127n}}`, `[a]{0,127}` | 1 + 127 × 1 = 128 | yes |
| `Repeat{Literal{"a"}, 0n, Some{127n}}`, `(?:a){0,127}` | 1 + 127 × 2 = 255 | no |
| `Repeat{Class{[Range{97, 97}]}, 0n, Some{128n}}`, `[a]{0,128}` | 129 | no |
| `[a]{0,10}` repeated `{0,11}` | 1 + 11 × (1 + 10 × 1) = 122 | yes |
| `[a]{0,10}` repeated `{0,10}`, then `{0,10}` again | 1 + 10 × (1 + 10 × 11) = 1111 | no |
| `[a-z]{1,64}` | 1 + 64 = 65 | yes |

The specification measures a pattern only after its parts and counts are valid,
so it never multiplies an unchecked count such as `{0,4294967295}`.

The cap bounds the table. The widest shapes found have 42 to 110 nodes. On a
Boat sandbox (4 vCPU, one runtime thread), native code scans a mebibyte of
`a` against them in 2.2 to 5.6 seconds, about 2 to 5.4 µs per scalar:

| Pattern | Nodes | 1 MiB, native |
| --- | --- | --- |
| `(?:[a-z]{0,1}){42}` starred | 42 | 2.2 s |
| `(?:[a-z]{0,2}){32}` starred | 64 | 3.4 s |
| `(?:[a-z]{0,6}){16}` starred | 96 | 5.0 s |
| `(?:(?:[a]{0,10}){0,11})*` | 110 | 5.6 s |

Over 300 scalars, the derivative matcher took 8 to 13 ms per scalar on the
starred sequences. `.mjs` is faster than native here: 0.9 to 2.8 seconds per
mebibyte on the same shapes, measured on ms-a2. Building the table costs up to
about 50 ms natively for the widest shapes and well under a millisecond for
patterns like the slug and the ZIP code. The decoder builds it on every match,
so a wide pattern costs that much per field per request even for a short text.

String checks run cheapest first, so a text over `max_len` is rejected before
the matcher starts. Express plain length limits with `min_len` and `max_len`,
which do not count toward the cap, and set `max_len` on any pattern field that
may receive long input.

### ECMAScript rendering

`P.source(p)` returns the ECMAScript source that the
[JSON Schema export](json-schema.md) uses as `pattern`. It means the same thing with or without the `u` flag, since
JSON Schema validators differ on that flag:

| Pattern | Source |
| --- | --- |
| `Literal{x}` | each scalar escaped: ASCII as `\xHH`, other BMP scalars as `\uHHHH`, astral scalars as a `\uHHHH\uHHHH` surrogate pair |
| `Class{rs}` | `[\xHH-\xHH...]`, or `[^\s\S]` when empty |
| `Cat{a, b}` | source of `a`, then source of `b` |
| `Repeat{p, m, n}` | `(?:p)` followed by `*`, `+`, `?`, `{m}`, `{m,}` or `{m,n}` |

The whole is `^(?:...)(?![\s\S])`. `(?![\s\S])` is the absolute end of input; a
bare `$` would also accept a final line terminator. JSON Schema's default is
substring matching, so both anchors are required. For the slug and ZIP above:

```text
^(?:(?:[\x61-\x7a\x30-\x39])+(?:\x2d(?:[\x61-\x7a\x30-\x39])+)*)(?![\s\S])
^(?:(?:[\x30-\x39]){5}(?:\x2d(?:[\x30-\x39]){4})?)(?![\s\S])
```

Escaping every scalar keeps punctuation such as `.`, `$`, or `{` literal.
Without the `u` flag a surrogate pair is two code units; a group always wraps a
repeated body, so a quantifier never splits one. Inputs are already well-formed
Unicode, so neither mode sees a lone surrogate. Only render valid patterns:
reversed counts are a syntax error in ECMAScript.

## Formats

`Plain{}` adds no format restriction. `Email{}` accepts an ASCII dot-atom local
part followed by exactly one `@` and a DNS-style hostname. Atom characters are
letters, digits, and `!#$%&'*+-/=?^_` followed by the backtick, braces, vertical
bar, and tilde. Dots separate nonempty atoms. The local part has at most 64
characters and the complete address at most 254.

Hostnames have one or more dot-separated labels, each 1–63 ASCII letters,
digits, or hyphens, with alphanumeric endpoints; the full hostname has at most
253 characters. Single-label hosts are allowed. Quoted local parts, comments,
Unicode domains, bracketed addresses, trailing dots, whitespace, and consecutive
local dots are rejected. This is a conservative application format, not a full
RFC 5322 parser or a deliverability check.

`Url{}` accepts lowercase `http://` or `https://` followed by a hostname using
those same rules, an optional colon and 1–5 decimal port digits in 0–65535, and
an optional path, query, or fragment starting with `/`, `?`, or `#`.
Leading zeroes in a port are accepted. Numeric dotted hostnames are checked as
DNS labels; this does not validate or normalize IPv4 addresses.

The suffix permits ASCII letters, digits, `-._~:/?#[]@!$&'()*+,;=`, and `%`
followed by exactly two hex digits. Encoded octets are not decoded or checked
for UTF-8. Userinfo, IPv6 brackets in the authority, backslashes, Unicode,
controls, spaces, malformed percent escapes, empty ports and trailing host dots
are rejected. This is a syntactic subset, not a WHATWG normalization algorithm;
it does not perform DNS, restrict destinations, or guarantee fetchability.
The [JSON Schema export](json-schema.md) writes these grammars as exact
patterns rather than relying on generic JSON Schema `format` implementations.

## Compound schemas

```python
type Unknown is Data:
  Strict{}
  Strip{}

type Presence is Data:
  Required{}
  Optional{}
  Default{value: Json.Json}

type Field is Data:
  Field{key: String, schema: Schema, presence: Presence}

type Value is Data:
  ...                                  # the scalar values above
  VNull{}
  VArray{items: List<&2, Value>}
  VObject{fields: List<&2, VField>}
  VUnion{index: Nat, value: Value}

type VField is Data:
  VField{key: String, value: Maybe<&2, Value>}
```

This user schema nests three objects:

```python
def text() -> S.Schema:
  S.StringSchema{1n, Some{80n}, None{}, S.Plain{}}

def geo() -> S.Schema:
  S.ObjectSchema{[S.Field{"lat", S.NumberSchema{None{}, None{}}, S.Required{}}, S.Field{"lng", S.NumberSchema{None{}, None{}}, S.Required{}}], S.Strict{}}

def user() -> S.Schema:
  S.ObjectSchema{[
    S.Field{"name", text(), S.Required{}},
    S.Field{"address", S.ObjectSchema{[S.Field{"city", text(), S.Required{}}, S.Field{"geo", geo(), S.Required{}}], S.Strict{}}, S.Required{}},
    S.Field{"nick", S.NullableSchema{text()}, S.Optional{}},
  ], S.Strict{}}
```

Decoding `{"address":{"geo":{"lng":2.35,"lat":48.85},"city":"Paris"},"name":"Ada"}`
gives fields in schema order, whatever the input order:

```python
VObject{[
  VField{"name", Some{VString{"Ada"}}},
  VField{"address", Some{VObject{[VField{"city", Some{VString{"Paris"}}}, VField{"geo", Some{VObject{[VField{"lat", Some{VNumber{"48.85"}}}, VField{"lng", Some{VNumber{"2.35"}}}]}}}]}}},
  VField{"nick", None{}},
]}
```

A typed record reads those fields by position and never compares a key; the
preservation law below fixes their order. `tests/fixtures/schema-compound/consumer.bend`
turns this value into `User{name, Address{city, Geo{lat, lng}, zip}, nick}`,
which is the shape decision 0003's generator will emit.

### Arrays

`ArraySchema{items, min_items, max_items}` accepts an array with `min_items` to
`max_items` items (`None{}`: no upper limit), each accepted by `items`. The count
is checked before any item is decoded, so an oversized body fails without
decoding its items. The value is `VArray` with each item's value in order. An
item's error path starts with its zero-based `PathIndex`.

### Objects

`ObjectSchema{fields, unknown}` accepts an object when:

- each declared key appears exactly once if `Required{}`, at most once if
  `Optional{}` or `Default{v}`, and its member is accepted by that field's
  schema;
- under `Strict{}`, every member's key is declared; under `Strip{}`, undeclared
  members are ignored and left out of the value, even when they repeat.

Bendo's JSON keeps duplicate keys, and parsers disagree about which duplicate
wins, so a declared key that appears twice rejects the object with
`duplicate key` under either policy. The value is `VObject` with one `VField`
per declared field in schema order, `None{}` for an absent optional field.
Errors for a member start with its `PathKey`; a missing required key, a
duplicate key and an undeclared key under `Strict{}` each name that key.

Optionality lives on the field, not on a schema: JSON has no undefined value,
so "may be absent" only means something for an object key. Use
`NullableSchema` for "may be null".

### Defaults

`Field{k, schema, Default{v}}` may be absent; then its `VField` holds `v`
decoded by `schema`, exactly as if the input had carried `v`. A defaulted
object fills its own defaults in turn. The default must satisfy its field's
schema: the decoder checks it with the rest of the schema before reading
input, and a schema with a bad default returns `InvalidSchema`.

```python
def query() -> S.Schema:
  S.ObjectSchema{[
    S.Field{"limit", S.IntegerSchema{Some{"1"}, Some{"100"}}, S.Default{J.JNumber{"10"}}},
    S.Field{"tag", S.ArraySchema{S.StringSchema{1n, None{}, None{}, S.Plain{}}, 0n, Some{5n}}, S.Optional{}},
  ], S.Strip{}}
```

Decoding `{}` against `query()` gives
`VObject{[VField{"limit", Some{VInteger{"10"}}}, VField{"tag", None{}}]}`.
The [JSON Schema export](json-schema.md) emits the value as a `default`
annotation.

### Nullable and union

`NullableSchema{inner}` accepts null, giving `VNull{}`, and otherwise whatever
`inner` accepts, giving `inner`'s value unchanged.

`UnionSchema{members}` tries members in order and returns `VUnion{i, value}` for
the first member `i` (zero-based) that accepts. An empty union accepts nothing.
When no member accepts, the error is `Constraint` with
`value matches no union member` and an empty path; member errors are discarded.

### Validity

A compound schema is valid when every part is: `min_items <= max_items`, declared
keys are well-formed Unicode and distinct within an object, every default
meets its field's schema, and every child schema is valid. The decoder checks the whole tree, including union members it
may never reach, before reading input, and an invalid tree returns
`InvalidSchema` with `invalid schema`.

### Cost under attacker input

Decoding never recurses deeper than the schema: an input nested deeper than the
schema fails at the schema's depth, and the parser already caps nesting at 512.
Every loop over an attacker-sized array or object is a tail call in native code
and `.mjs`, so wide bodies use no call stack. An object costs
O(members × declared fields) for its key checks; there is no per-pair
comparison between members, so a fixed schema costs time linear in the body.
A union tries each member on the same value, so a value under nested unions can
be decoded once per path through them; that factor depends on the schema, not
on the body.

A rejection decodes again to collect errors. The collector also walks lists
with tail calls and stops as soon as it holds 100 errors, so a body of a
million bad items or undeclared keys costs one pass to its hundredth error,
and each error's path is as long as the schema is deep. Coercion makes one
pass per declared field over an object's members, plus one to gather each
array field, so it is linear in the body for a fixed schema.
`tests/schema-errors.test.ts` times 256 KiB and 1 MiB bodies (capped error
lists, undeclared keys, a repeated text key) and requires the larger to cost
under 8 times the smaller. `tests/schema-compound.test.ts` measures 256 KiB and 1 MiB
bodies (integer arrays, unknown keys, one key repeated, oversized arrays) and
requires the larger to cost under 8 times the smaller.

## Coercion for text sources

Params, query strings, headers and forms carry only strings. Decode them with
`decode_from(TextSource{}, schema, json)`, which coerces before decoding;
`decode_from(JsonBody{}, ...)` and `decode` never coerce, so a JSON body that
sends `"10"` for an integer is a type mismatch. Build the input as an object
of `JString` members in arrival order, keeping repeated keys. `coerce(schema,
json)` returns the coerced value on its own. The rules:

- under `NumberSchema` and `IntegerSchema`, a string that is a valid JSON
  number token becomes that number. `"010"`, `"+1"`, `" 1"` and `"1."` stay
  strings. Integer schemas still apply the lexical integer rule afterwards, so
  `"1e2"` becomes a number and fails as a constraint;
- under `BooleanSchema`, exactly `"true"` and `"false"` become booleans;
- under `ArraySchema`, each item is coerced against the item schema;
- under `NullableSchema`, the value is coerced against the inner schema. The
  text `"null"` stays a string; leave the key out instead;
- under `ObjectSchema`, each member named by a declared field is coerced
  against that field's schema. For an array field, every member with that key
  is gathered, in order, into one array that takes the first member's place,
  so `?tag=a&tag=b` and `?tag=a` both give arrays. A key that is absent stays
  absent, so defaults and optional fields still apply. A non-array key that
  repeats is still a `duplicate key`;
- unions, literals, enums and undeclared members are left as they are, so a
  union member or enum that needs a number never matches a text value.

For example, coercing `{"limit":"20","tag":"a","x":"1","tag":"b"}` against
`query()` gives `{"limit":20,"tag":["a","b"],"x":"1"}`. Errors from a text
source name paths in the coerced value: the second `tag` is `["tag", 1]`.

## Errors

A rejection lists every location where a check fails, at most 100
(`error_cap()`). Arrays report every failing item and objects every failing
field. A location below a failed check is not examined: an array of the wrong
length or a value of the wrong kind reports one error and nothing inside it,
and a union that matches no member reports one error for the whole value,
whatever its members said. In each object, undeclared keys under `Strict{}`
come first in input order, then the declared fields in schema order.

| Location | Path | Code | Message |
| --- | --- | --- | --- |
| scalar of the wrong kind | the value | `TypeMismatch` | `expected schema scalar kind` |
| scalar failing a check, literal or enum | the value | `Constraint` | `value does not satisfy scalar checks` |
| array or object of the wrong kind | the value | `TypeMismatch` | `expected schema kind` |
| array length out of bounds | the array | `Constraint` | `array length out of bounds` |
| undeclared key under `Strict{}` | `[..., key]` | `Constraint` | `object has an undeclared key` |
| required key missing | `[..., key]` | `Constraint` | `missing required key` |
| declared key repeated | `[..., key]` | `Constraint` | `duplicate key` |
| no union member matches | the value | `Constraint` | `value matches no union member` |
| invalid schema | `[]` | `InvalidSchema` | `invalid schema` |

`errors_json(errors)` gives the list as JSON for responses (BND-36), one object
per error in this order with these keys:

```json
[{"path":["people",1,"name"],"code":"constraint","message":"missing required key"}]
```

Path segments are key strings and index numbers. Codes are `"invalid_schema"`,
`"type_mismatch"` and `"constraint"`. The shape is stable: new fields may be
added, but these keep their names and meanings.

## Errors and extension points

Malformed bounds, reversed bounds, non-ASCII or reversed pattern ranges,
pattern literals with a lone surrogate, reversed counts anywhere in a pattern,
patterns over the size cap, and invalid literal or enum members, and the compound
rules under [Validity](#validity) return `InvalidSchema` before examining input. `TypeMismatch` means the JSON category
differs from the schema. `Constraint` means a value fails a check, literal
membership, or scalar validity.
Even an otherwise matching enum rejects if another member is malformed.

There is no route validation yet (BND-36). [JSON Schema export](json-schema.md)
(BND-37) exports `Strict{}` as `additionalProperties: false`, `Optional{}` by
omission from `required`, and nullables and unions as `anyOf`. It records the
duplicate-key, first-match, lexical-integer, default and coercion rules as
decoder policy, since JSON Schema validators do not share them.
The prototype generator is unchanged; production record generation can call
this generic scalar decoder per field without duplicating scalar checks.

## Guarantees and verification

`src/data/schema-spec.bend` restates every rule on this page independently of
the decoder. It reads lengths as a structural count of scalars, numbers by the
RFC 8259 grammar, decimal values as exact natural numbers (`digits * 10^e`
compared by cross-multiplying), patterns as regular languages that try every
way to split the text, the pattern size cap in plain unbounded arithmetic, and
the email and URL formats as direct grammars. It imports the schema and pattern
modules only for their data types and calls none of their functions. It is a specification, not an implementation: it is
exponential on patterns and unary on numbers.

It states compound rules the same way: an array's item count and every item,
an object's key policy, the number of members named by each declared key and
every such member, null or the inner schema, and "some member" for a union.
The value side of the spec, `Schema.value_for`, builds the expected value tree
without checking any constraint; for a union it picks the first member that
`decode` accepts, which the first law ties to the specification.

These laws quantify every schema and every JSON tree, including malformed
schemas and constructed data:

- `schema_acceptance_iff` equates successful decoding with
  `SchemaSpec.satisfies`, proving soundness and completeness. BND-34 extended
  the `Schema` type without changing the statement; on scalar schemas both
  sides behave exactly as in BND-33.
- `schema_preserves_typed_value` requires every success to equal
  `value_for`: the right constructors, exact scalar payloads, items in order,
  declared fields in schema order, and the union member's index.
- `schema_children_satisfy` states the BND-34 guarantee directly: when
  decoding accepts, every array item, every member with a declared key, the
  inner value of a non-null nullable, and at least one union member satisfy
  their own schemas. It follows from the first law.
- `schema_errors_name_failing_paths` (BND-35): a rejection lists between one
  and 100 errors, and each error's path is a location where
  `SchemaSpec.error_at` finds a failing check.
- `schema_errors_complete` (BND-35): for every path `error_at` accepts, the
  decoder rejects and lists an error with exactly that path, unless it already
  lists 100.
- `schema_coerce_matches_spec` (BND-35): `coerce` equals
  `SchemaSpec.coerce_text`, which restates the coercion rules by plain
  recursion with the specification's own number grammar.
  `schema_coerced_acceptance_iff`, `schema_coerced_preserves_typed_value`,
  `schema_coerced_errors_name_failing_paths` and
  `schema_coerced_errors_complete` restate the four laws above for
  `decode_from(TextSource{}, ...)`, read against the coerced value.

Defaults are part of the first two laws: `SchemaSpec.schema_ok` requires every
default to meet its field's schema, `SchemaSpec.presence` lets a defaulted key
be absent, and `value_for` fills an absent defaulted field with its value.

`SchemaSpec.fault(s, v, path, Here{})` defines the locations. The empty path
fails when `v` fails a scalar schema, has the wrong kind or array length, or
matches no union member. `[i, ...rest]` leads into item `i` of an array of the
right length, `[k]` names a declared key present a number of times its
presence forbids or a key `Strict{}` does not declare, and `[k, ...rest]` leads
into the one member named by a declared key. A nullable reads a non-null value
against its inner schema.

The scalar proofs go through one equivalence lemma per check
(`proof/schema-*.bend`); the compound proofs (`proof/schema-compound.bend`)
follow the decoder's states by induction on the schema and on each list.
`proof/schema-errors.bend` follows the error collector's states the same way
(the errors a state starts with, the budget, an empty result, soundness and
completeness), and `proof/schema-coerce.bend` follows the coercion's states.
Both files are generated from per-state cases by the scripts in
`scripts/schema-proofs/`.

Run `bun run prove` for the strict Lean-backed kernel and
`bun test --timeout 30000 tests/schema.test.ts tests/schema-compound.test.ts tests/schema-errors.test.ts`
for real native and `.mjs` consumers. Tests cover every kind and check, malformed schemas and input, exact
boundaries, Unicode scalar lengths, numerical const equality, huge decimal
orders, and long strings without JavaScript call-stack growth. For patterns
they compare the matcher with `new RegExp(P.source(p))` with and without the
`u` flag on every string up to length three over a mixed alphabet plus random
strings, and with the specification on short strings. Compound tests decode
hand-checked cases in both targets, a three-level typed record, 3,000 seeded
random schemas and inputs (duplicate and unknown keys included) against an
independent TypeScript reading of this page and against the specification,
and megabyte bodies.

BND-35 tests decode defaults, coercion and error lists in both targets, run
2,100 seeded text inputs through both targets and an independent TypeScript
reading of the coercion rules, check the error laws on 600 seeded random
schemas with defaults through the specification, and time megabyte bodies.
