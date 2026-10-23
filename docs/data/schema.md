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

`P.source(p)` returns the ECMAScript source BND-37 should export as the JSON
Schema `pattern`. It means the same thing with or without the `u` flag, since
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
BND-37 should retain these precise restrictions as decoder policy rather than
assuming generic JSON Schema `format` implementations agree.

## Errors and extension points

Malformed bounds, reversed bounds, non-ASCII or reversed pattern ranges,
pattern literals with a lone surrogate, reversed counts anywhere in a pattern,
patterns over the size cap, and invalid literal or enum members return
`InvalidSchema` before examining input. `TypeMismatch` means the JSON category
differs from the schema. `Constraint` means a value fails a check, literal
membership, or scalar validity.
Even an otherwise matching enum rejects if another member is malformed.

There is no coercion, default insertion, or path accumulation yet (BND-35), and
no route validation (BND-36) or JSON Schema export (BND-37). Object, array,
optional, nullable, and union variants belong to BND-34. Defaults remain
annotations until consumers explicitly call a decoder implementing that policy.
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

The BND-33 laws quantify every schema and every JSON tree. The first equates
successful decoding with `SchemaSpec.satisfies`, proving both soundness and
completeness against that independent specification. The proof goes through
one equivalence lemma per check (`proof/schema-*.bend`). The second law
requires the correct typed constructor and exact input payload on every
successful decode.

Run `bun run prove` for the strict Lean-backed kernel and
`bun test --timeout 30000 tests/schema.test.ts` for real native and `.mjs`
consumers. Tests cover every kind and check, malformed schemas and input, exact
boundaries, Unicode scalar lengths, numerical const equality, huge decimal
orders, and long strings without JavaScript call-stack growth. For patterns
they compare the matcher with `new RegExp(P.source(p))` with and without the
`u` flag on every string up to length three over a mixed alphabet plus random
strings, and with the specification on short strings.
