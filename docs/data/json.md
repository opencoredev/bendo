# JSON values and bodies

Import `src/data/json.bend` to parse UTF-8 body octets into a copyable value
tree or serialize that tree. Both operations are pure and compile to native
code and `.mjs`. BND-28 is implementation progress: its universal roundtrip law
is stated but not yet proved, so the repository proof gate does not pass.

## Values and precision

`Json` has six constructors:

```python
type Json is Data:
  JNull{}
  JBool{value: Bool}
  JNumber{value: String}
  JString{value: String}
  JArray{items: List<&2, Json>}
  JObject{fields: List<&2, Field>}

type Field is Data:
  Field{key: String, value: Json}
```

A number stores its complete JSON decimal spelling. For example, `-0.00E+009`
survives parsing and writing unchanged. The grammar is
`-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?`. There is no magnitude,
precision, or exponent limit. No arithmetic conversion occurs during parsing.
`NaN`, infinity, leading zeroes, and leading plus signs are rejected.

`to_u32(value)` returns `Some` only for an unsigned integer spelling in
0–4,294,967,295. It rejects negatives (including `-0`), fractions, exponent
spellings, overflow, and non-numbers, with `None`. It never rounds or wraps.
There is no floating-point conversion helper yet. Bend 2.0.38 provides F32 but
no F64; callers needing approximate arithmetic must explicitly choose a
conversion and its precision policy rather than silently changing the tree.

Objects keep every member in its original order, including duplicates.
`lookup(fields, key)` returns the **first** member with that case-sensitive key.
Serialization preserves every duplicate; converting through JavaScript's
`JSON.parse` can discard duplicates and lose decimal precision.

This replaces the sketch from decision [0003](../decisions/0003-typed-values.md):
`JsonValue` becomes `Json`; `JsonNull`, `JsonBool`, `JsonNumber`, `JsonString`,
`JsonArray`, and `JsonObject` become the corresponding `J*` constructors;
`JsonField{name, value}` becomes `Field{key, value}`. Numbers still store strings
and objects still use ordered field records and first-match lookup. Arrays now
carry their actual items. The prototype remains unchanged as a research fixture;
production schema decoders must import this module and use the new names.

## Parse and write

`parse(body: List<&2, U32>)` returns `Result<&2, &2, Error, Json>`. Each input
must be an octet in 0–255. The decoder rejects malformed UTF-8, overlong
sequences, UTF-8 surrogate encodings, and code points above U+10FFFF.
`parse_string(text)` accepts an already decoded Bend String; it rejects
non-scalar characters inside JSON strings. Neither entry point accepts a BOM.
Only space, tab, LF, and CR are JSON whitespace.

Strings support all JSON escapes and four-digit Unicode escapes. A high
surrogate must immediately precede a second `\uXXXX` escape containing a low
surrogate; the pair becomes one scalar. Lone, reversed, or incomplete surrogates
are rejected. Unescaped characters below U+0020 are rejected.

The parser has one recursive driver, `parse_go`, whose first argument counts
down from `4 × scalar input length + 16`. A finite-state mode and explicit
container stack replace mutual recursion. Token completion and delimiter
reprocessing can take transitions without consuming a character; the multiplier
and EOF slack cover those transitions. At most 512 arrays/objects may be open
at once. The 513th opening delimiter returns `Fail{DepthLimit{}}`.

`write(value, pretty, ascii)` returns `Result<&2, &2, Error, String>`.
`stringify(value)` selects compact UTF-8 output, equivalent to
`write(value, False{}, False{})`. Pretty output uses two spaces per level.
ASCII mode escapes non-ASCII scalars, using surrogate pairs above U+FFFF.
Every mode escapes quotes, backslashes, and controls; it uses short escapes
where JSON defines them and `\u00xx` otherwise. Slash remains unescaped.

Constructed values must have scalar strings/keys, valid decimal spellings,
and at most 512 nested containers. The independent `admissible` predicate
checks precisely those conditions. The writer returns `InvalidValue` for
inadmissible trees. It uses an explicit work stack with fuel derived from a
bounded-depth structural scan; all traversals proportional to input width or
text length are tail recursive. Structural recursion in the scan is bounded
by the 512-container limit.

Other errors are `Syntax`, `InvalidUtf8`, and `FuelExhausted`. The latter is an
internal sufficiency failure, not a configurable document size limit. Errors
do not yet include byte offsets or paths. Apply body-size limits before parsing.
The ASCII decoder fast path directly constructs scalar characters below 128;
other bytes and non-ready decoder states use the shared strict UTF-8 machine.
Its equivalence to the shared codec is not yet proved.

## Pure HTTP helpers

`src/data/json_http.bend` exports `req_json(body)` and `json(status, value)`.
`req_json` decodes complete body octets and returns the parser's typed result.
It does not validate Content-Type. `json` returns a typed result containing a
`Response.Res` with compact JSON encoded as UTF-8 and
`content-type: application/json; charset=utf-8`. Invalid constructed values
propagate `InvalidValue`; the helper never emits malformed JSON.

Bodies are supplied separately because the current `Req` describes the request
head. These helpers perform no IO and do not require a context. BND-21 can wrap
them with context-level accessors.

## Verification and remaining proof

The vendored [JSONTestSuite](../../tests/fixtures/JSONTestSuite/) is pinned to
`1ef36fa01286573e846ac449e8683f8833c5b26a`. Both native and `.mjs` consumers
accept all 95 `y_` cases and reject all 188 `n_` cases. Of 35 `i_` cases, 11
are accepted: the ten number cases and the 500-nested-array case. The other
24 are rejected for invalid Unicode, malformed UTF-8/UTF-16, or a BOM. Tests
read the original raw fixture bytes.

Run `bun test tests/json.test.ts` for the corpus, independent JavaScript grammar
checks of written output, all writer option combinations, duplicate preservation,
unsigned conversion, pure HTTP helpers, 511/512/513 depth boundaries, and
64 KiB/1 MiB strings, numbers, wide arrays, and wide objects in `.mjs`.
Large-input assertions compare serialized output rather than recursively walking
the tree in the JavaScript assertion library.

On ms-a2, 2026-10-22, Bend 2.0.38, one native runtime thread, the focused test
measured **90 ms** to parse a 1,048,576-byte JSON string containing ASCII `a`.
Earlier post-optimization runs measured 75 and 79 ms; the original shared-codec path
measured 1,435 ms. This is one bounded parse per invocation, not a throughput
load test. `IO.now` brackets the public byte parser, including strict UTF-8
decoding, input-length counting, allocation, and tree construction. File IO,
compilation, and writing are outside the timed region. The result constructor
is forced before the ending clock read. These figures describe this input on
this machine, not a promise for every document shape or server load.

The test compiles `tests/fixtures/json/native.bend`; reproduce the measurement
with its `bench <path>` arguments and `+RTS --threads 1 -RTS`. It prints
`accept:<milliseconds>`. The test enforces the issue's 200 ms threshold.

The contiguous BND-28 block in `LAWS.bend` states:

```python
law json_roundtrip:
  for +value: Json.Json
  for +pretty: Bool
  for +ascii: Bool
  for +valid: {Json.admissible(value) == True{} : Bool}
  exs output: String
  {Json.write(value, pretty, ascii) == Done{output} : Result<&2, &2, Json.Error, String>} &
  {Json.parse(Utf8.encode(output)) == Done{value} : Result<&2, &2, Json.Error, Json.Json>}
```

`proof/json.bend` contains checked scalar-predicate, parser continuation,
writer continuation, and primitive/empty-container lemmas. The universal law
remains open: recursive string escaping/unescaping, lexical-number parsing,
nonempty array/object continuation invariants, sufficient fuel, depth bounds,
and the optimized decoder's equivalence still need proofs. `bun run prove`
and consequently `bun run check` fail on that open law. No existing law was
removed or weakened. BND-28 must stay open until the strict gate passes.
