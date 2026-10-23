# Scalar schemas

Import `src/data/schema.bend` to describe scalar constraints as copyable Bend
`Data` and decode a parsed `Json.Json`. The same pure decoder compiles to native
code and `.mjs`. This is the scalar foundation for generated record decoders in
decision [0003](../decisions/0003-typed-values.md).

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

`Schema` contains these scalar constructors:

```python
type Schema is Data:
  StringSchema{min_len: Nat, max_len: Maybe<&2, Nat>, pattern: Maybe<&2, Pattern>, format: Format}
  NumberSchema{min: Maybe<&2, String>, max: Maybe<&2, String>}
  IntegerSchema{min: Maybe<&2, String>, max: Maybe<&2, String>}
  BooleanSchema{}
  LiteralSchema{value: Json.Json}
  EnumSchema{values: List<&2, Json.Json>}
```

`decode(schema, json)` returns `Result<&2, &2, Errors(), Value>`.
`Errors()` is `List<&2, Error>`; each error has a `Code`, a message, and a
`List<&2, PathPart>`. Scalar errors contain one item with an empty path.
`PathKey{String}` and `PathIndex{Nat}` reserve the shape for BND-35.

Successful values are `VString{String}`, `VNumber{String}`,
`VInteger{String}`, `VBool{Bool}`, or `VLiteral{Json.Json}`. Numbers retain the
input spelling exactly. Integer values are validated decimals, rather than
bounded machine integers. `to_json(value)` reconstructs the original input.

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
`integer`; BND-37 must record it as decoder policy. Browser consumers must
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

Patterns are structured data, without a regex source parser:

```python
S.Class{[S.Range{97, 122}, S.Range{48, 57}], 1n, Some{8n}}
```

This accepts one through eight lowercase ASCII letters or digits. Each range is
inclusive and must satisfy `0 <= lo <= hi <= 127`. A pattern is one character
class repeated between its minimum and optional maximum count, matching the
entire string. Classes may contain any ASCII code point; ranges may overlap.
An empty class accepts only the empty string when its minimum is zero.

`min=0,max=None` is `*`; `min=1,max=None` is `+`;
`min=0,max=Some{1}` is `?`; equal bounds are `{n}`; other bounds are `{n,m}`.
There are no sequences, alternations, captures, lookarounds, or negated classes.
Matching scans text once and checks class membership for each scalar, taking
O(text length × number of ranges), linear in text length for a fixed schema.
The scans use tail recursion on both targets.

For BND-37, emit an ECMAScript class using escaped ASCII ranges such as
`[\x61-\x7a\x30-\x39]`, followed by its quantifier. Prefix `^` and end with
`(?![\s\S])`, without flags, to require absolute end of input. A bare `$` also
matches before a final line terminator and would change these semantics. Encode
an empty class as `[^\s\S]` before quantifying it. JSON Schema `pattern` must
use these anchors because its default is substring matching.

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
BND-37 should retain these precise restrictions as decoder policy rather than
assuming generic JSON Schema `format` implementations agree.

## Errors and extension points

Malformed bounds, reversed bounds, non-ASCII/reversed pattern ranges, reversed
pattern counts, and invalid literal/enum members return `InvalidSchema` before
examining input. `TypeMismatch` means the JSON category differs from the schema.
`Constraint` means a value fails a check, literal membership, or scalar validity.
Even an otherwise matching enum rejects if another member is malformed.

There is no coercion, default insertion, or path accumulation yet (BND-35), and
no route validation (BND-36) or JSON Schema export (BND-37). Object, array,
optional, nullable, and union variants belong to BND-34. Defaults remain
annotations until consumers explicitly call a decoder implementing that policy.
The prototype generator is unchanged; production record generation can call
this generic scalar decoder per field without duplicating scalar checks.

## Guarantees and verification

The BND-33 laws quantify every schema and every JSON tree. The first equates
successful decoding with the independent `satisfies` predicate, proving both
soundness and completeness. The second requires the correct typed constructor
and exact input payload on every successful decode. The predicate states checks
directly and shares semantic primitives such as decimal ordering and character
membership; it never calls the decoder or inspects its result.

Run `bun run prove` for the strict Lean-backed kernel and
`bun test --timeout 30000 tests/schema.test.ts` for real native and `.mjs`
consumers. Tests cover every kind/check, malformed schemas and input, exact
boundaries, Unicode scalar lengths, numerical const equality, huge decimal
orders, and long strings without JavaScript call-stack growth.
