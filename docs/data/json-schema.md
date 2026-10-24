# JSON Schema export

`src/data/json-schema.bend` turns any [schema](schema.md) into a JSON Schema
(draft 2020-12) document. The [route manifest](../manifest.md) prints these
documents for each route, and BND-56 and BND-62 build TypeScript types and
OpenAPI from them.

```python
import ../../src/data/json-schema.bend as JS

JS.export(s)     # the JSON Schema as a Json.Json value, without $schema
JS.document(s)   # the same with "$schema": "https://json-schema.org/draft/2020-12/schema"
```

Both are total. `BS.json_schema(s)` in `src/serve-schemas.bend` is `JS.document(s)`.

The export accepts the same JSON as the decoder for JSON text that standard
parsers read the same way, apart from the differences listed under
[Decoder policy and validator differences](#decoder-policy-and-validator-differences). That
equivalence is tested, not proven: `tests/json-schema.test.ts` checks it in
both regular-expression modes. The laws prove structural facts about the
output (see [Laws](#laws)).

## Mapping

| Schema | JSON Schema |
| --- | --- |
| `StringSchema{min, max, p, f}` | `type: "string"`, `minLength: min`, `maxLength: max` when set, `pattern` when `p` is set, the format check under `allOf` when `f` is `Email{}` or `Url{}`, and `not: {pattern: LONE}` |
| `NumberSchema{min, max}` | `type: "number"`, `minimum` and `maximum` when set |
| `IntegerSchema{min, max}` | `type: "integer"`, `minimum`, `maximum`, and a `$comment` stating the lexical integer rule |
| `BooleanSchema{}` | `type: "boolean"` |
| `LiteralSchema{v}` | `const: v` |
| `EnumSchema{xs}` | `enum` with repeated members removed, or `not: {}` when empty |
| `ArraySchema{i, min, max}` | `type: "array"`, `items`, `minItems`, `maxItems` when set |
| `ObjectSchema{fs, u}` | `type: "object"`, `properties` in field order, `required`, `additionalProperties`, and a `$comment` on duplicate keys |
| `NullableSchema{i}` | `anyOf: [{type: "null"}, i]` |
| `UnionSchema{ms}` | `anyOf` in member order with a first-match `$comment`, or `not: {}` when empty |
| any invalid schema | `{"$comment": "invalid Bendo schema: the decoder rejects every value", "not": {}}` |

The details:

- **Numbers are written as their tokens.** Bounds and enum, literal and
  default values keep their spelling. `NumberSchema{Some{"-0"}, Some{"1E+2"}}`
  exports `"minimum":-0,"maximum":1E+2`.
- **Strings reject lone surrogates.** `LONE` is
  `[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]`. It
  matches exactly the strings that are not well-formed Unicode, with or
  without the `u` flag. The decoder rejects those strings, and the Bend JSON
  parser never produces them. `minLength` and `maxLength` count code points,
  as the decoder does.
- **`pattern`** is `P.source(p)` from [Patterns](schema.md#ecmascript-rendering).
  It is anchored at both ends and means the same thing in either regex mode.
- **Email and URL** export as hand-written patterns equal to the grammars in
  `src/data/schema-text.bend`, inside `allOf` with a `$comment`. They do not
  use the `format` keyword, because validators disagree on what `email` and
  `uri` accept and many treat `format` as an annotation only. Every class is
  ASCII and written with `\xHH` escapes, so the patterns mean the same thing
  in either mode. Lookaheads enforce the 64-character local part, the
  253-character hostname and the 254-character address. The port pattern
  accepts 1 to 5 digits with a value of 65535 or less, leading zeroes
  included. `JS.email()` and `JS.url()` return the sources.
- **Enums** keep the first of each group of equal members: `1`, `1.0` and `1e0`
  keep only `1`. This satisfies the `uniqueItems` rule, which compares
  numbers by value.
- **Empty enums and unions** become `not: {}`, because `enum: []` and
  `anyOf: []` are not valid JSON Schema.
- **Unions use `anyOf`, not `oneOf`.** Members may overlap, and the decoder
  accepts a value that matches several members by picking the first.
- **Objects.** `Strict{}` exports `additionalProperties: false` and `Strip{}`
  exports `true`. Strip accepts undeclared keys with any value and drops them
  from the decoded value. `required` lists the `Required{}` keys in field order.
- **Optional is not nullable.** `Optional{}` and `Default{v}` fields are left
  out of `required`, so the key may be absent. A key that is present must
  satisfy its field's schema, `null` included. `NullableSchema` is one way to
  permit `null`; a null literal, an enum containing `null`, or a union with
  such a member also accept it.
- **Defaults are annotations.** `Default{v}` adds `"default": v` to the field's
  property schema. JSON Schema validators do not insert it. Only the decoder
  fills an absent defaulted field, as described in [Defaults](schema.md#defaults).

Here is the query schema from [Defaults](schema.md#defaults) as
`JS.document` prints it, without the `not` guard and `$comment` text:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "properties": {
    "limit": { "type": "integer", "minimum": 1, "maximum": 100, "default": 10 },
    "tag": { "type": "array", "items": { "type": "string", "minLength": 1 }, "minItems": 0, "maxItems": 5 }
  },
  "required": [],
  "additionalProperties": true
}
```

## Decoder policy and validator differences

The decoder and a JSON Schema validator differ in three ways. They can accept
different JSON text, the decoder normalizes the value it returns, and
JavaScript validators read numbers through a lossy numeric model. Each row is
pinned by a test in `tests/json-schema.test.ts` or covered in
[Schemas](schema.md).

Acceptance of the same JSON text:

| Policy | Bendo decoder | JSON Schema validator |
| --- | --- | --- |
| Lexical integers | accepts only `-?(0\|[1-9][0-9]*)`; rejects `1.0`, `1e0`, `1e2` | `type: integer` accepts any mathematically integral number |
| Duplicate keys | rejects an object that repeats a declared key | sees the object after the parser has kept one member (the last, in `JSON.parse`) |

No JSON Schema keyword expresses either rule, so a validator accepts more here.

Normalization, which changes the decoded value but not what is accepted:

| Policy | Bendo decoder | JSON Schema validator |
| --- | --- | --- |
| First-match unions | returns the first matching member's index | `anyOf` only says that some member matches |
| Defaults | fills absent defaulted fields | treats `default` as an annotation |
| Strip | drops undeclared keys from the value | accepts them and keeps them |

Coercion is decoder input policy. `decode_from(TextSource{}, ...)` turns query,
param and header text into numbers, booleans and arrays before decoding, so it
accepts text such as `"10"` that the exported `integer` schema rejects.
Validators never coerce, so validate the coerced value, not the raw text.

Number representation. The export writes each bound as its exact token, and
the decoder compares tokens as exact decimals. A validator built on JavaScript
numbers sees the value only after `JSON.parse` has rounded it to a double:
`100.00000000000000001` passes `maximum: 100`, and `1e400` becomes `Infinity`.
This is a limit of the JavaScript numeric model, not of JSON Schema. A
validator with arbitrary-precision numbers can apply `minimum` and `maximum`
exactly.

### Validator settings

The tests use Ajv 8's `Ajv2020` with `strict: true`, once with the default
`u` flag and once with `unicodeRegExp: false`. They also set
`ownProperties: true`. Without it, Ajv reads inherited members, so
`required: ["constructor"]` is satisfied by `{}`. One Ajv limitation remains
even with that option: it ignores a property schema named `__proto__`. The
export still states such a field in standard form (`properties.__proto__` and
`required: ["__proto__"]`), and the decoder enforces it. The tests pin this
case rather than claiming Ajv agrees.

## Laws

The laws in `LAWS.bend` are structural guarantees about the exported JSON.
They do not prove that a JSON Schema validator and the decoder accept the
same values; the tests cover that. `JsonSchemaSpec.keyword(j, k)` in
`proof/json-schema-spec.bend` reads the first member `k` of an exported
object. `JsonSchema.go(s, JsonSchema.start(s))` is the node exporter used for
`s` and for every child at any depth.

- `json_schema_invalid_rejects_all`: when `Schema.valid(s)` is false, the
  export's `not` keyword is `{}`, so it accepts nothing, as the decoder does.
- `json_schema_valid_exports_node`: when `s` is valid, the export is its node,
  so the node laws hold for the root and for every child.
- `json_schema_type_keyword`: every node's `type` is the JSON type its kind
  requires (`string`, `number`, `integer`, `boolean`, `array` or `object`).
  Literal, enum, nullable and union nodes have no `type`.
- `json_schema_required_keys`: an object node's `required` lists exactly the
  keys of its `Required{}` fields, in order.
- `json_schema_unknown_keys`: `additionalProperties` is `false` for `Strict{}`
  and `true` for `Strip{}`.
- `json_schema_string_pattern`, `json_schema_string_max_length`: a string
  node's top-level `pattern` is `P.source` of its own pattern, and its
  `maxLength` is its upper bound. Each is absent when the schema has none.
- `json_schema_string_wellformed`: every string node carries the lone-surrogate
  guard.
- `json_schema_empty_enum`, `json_schema_empty_union`: both export `not: {}`.

Run `bun test --timeout 60000 tests/json-schema.test.ts` for the
differential tests. They cover 1,200 seeded random schemas of every
kind with 12 samples each, hand-written cases per kind, invalid schemas,
800 random patterns, 12,000 mutated email and URL candidates against the
Bend grammars, every string of up to three code units around the surrogate
boundaries, and the decoder policy above.
