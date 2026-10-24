# Generated route types

Run `bendo gen [entry]` from the app directory to write `.bendo/routes.ts`.
The entry defaults to `main.bend`. The CLI builds the app through its normal
cache, runs the binary with `--bendo-routes`, and derives the types from the
manifest's JSON Schema documents. Rerun it after changing a schema.

The file exports one type, `Routes`. It contains no runtime code or imports.
It is a union with one member per manifest row, in registration order:

```ts
// Example row from an app whose GET /todos/:id{int} has a params schema.
type Route = {
  method: "GET";
  path: "/todos/:id{int}";
  all: false;
  captures: ["id"];
  input: {
    params: { id: number | string };
    query: unknown;
    headers: unknown;
    body: unknown;
    response: unknown;
  };
  output: {
    params: { id: number };
    query: unknown;
    headers: unknown;
    body: unknown;
    response: unknown;
  };
};
```

`method` is the case-sensitive HTTP token. `path` keeps the entire pattern,
including constraints and optional captures. `all` distinguishes `B.all` from an
extension method literally named `ALL`. `captures` lists the manifest's capture
names in segment order. Missing schemas produce `unknown`, even for a path
whose captures are known. An empty manifest exports `Routes = never`.
Duplicates remain union members; generation does not choose between registrations.

A typed client can distribute over the union, split `path` into segments for
Eden-style access, select the method, accept `input` request slots, and return
`output.response`. The future BND-57 `createClient<Routes>(baseUrl)` consumes
this contract; the generator itself does not implement the client. A consumer
can already select a route with
`Extract<Routes, { method: "GET"; path: "/todos/:id{int}" }>`.

## Input, decoded values and responses

`input.params`, `input.query` and `input.headers` accept coerced values for
client serialization as well as text for numeric and boolean schemas. Numbers
accept `number | string`; booleans accept `boolean | "true" | "false"`.
Arrays retain their item type and represent repeated text keys. Numeric text
syntax, bounds and integer spelling remain runtime checks. Nullable schemas
coerce their inner node, but unions, literals and enums do not coerce their
members, matching Bend's [text-source policy](data/schema.md#coercion-for-text-sources).
BND-37 marks unions with its first-match `$comment`; generation uses that marker
to distinguish a union of null and another node from a nullable schema.

`input.body` uses JSON types without text coercion. A defaulted field is optional
in every input object. The four request slots in `output` describe decoded
values: defaults become required properties, and strip objects lose undeclared
keys. These rules apply recursively inside arrays and objects. An optional field
without a default stays optional; nullability never makes a field optional.

Both `input.response` and `output.response` describe the JSON response on the
wire. Defaults stay optional and open objects stay open, including nested ones:
main does not decode or normalize responses. These are schema contracts, not a
promise that main validates responses at runtime. Route validation is BND-36.

## JSON Schema mapping

- `const` and `enum` become literal types; `anyOf` becomes a union in member
  order. Null branches contribute `null`. `allOf` becomes an intersection.
- Objects keep required and optional keys. `additionalProperties: false` emits
  only declared properties. An empty closed object uses `Record<string, never>`
  so primitives and extra named properties are rejected. TypeScript is structural:
  nonempty closed objects reject extra keys in fresh object literals, but cannot
  reject every previously assigned object with additional keys. The server decoder
  remains responsible for exactness.
- `additionalProperties: true` accepts undeclared input and response keys through
  `[key: string]: unknown`. Decoded request types remove that index signature,
  matching strip behavior.
- Arrays become `Array<Item>`. Integers and numbers both become `number`.
  JavaScript doubles cannot preserve all Bend integers or exact decimals; numeric
  literals parsed from the manifest can round. A literal whose valid JSON token
  overflows a double (for example `1e400`) widens to `number`; numeric bounds
  and defaults can also exceed the double range. See [numeric limits](data/json-schema.md#decoder-policy-and-validator-differences).
- Strings, including formatted strings, become unbranded `string`. Lengths,
  patterns, bounds, formats and Bendo's lone-surrogate guard remain runtime
  constraints. They do not narrow a TypeScript primitive.
- `not: {}` and the boolean schema `false` become `never`; `true` becomes
  `unknown`. Other `not` forms are rejected except Bendo's string pattern guard.
- `$schema`, `$comment` and `default` annotations are checked at the boundary.
  Unknown keywords fail with the keyword, route ordinal, method, path and slot,
  including keywords nested inside constraints.

Output is deterministic: no timestamps, registration and union order preserved,
object keys sorted by UTF-16 code unit order, and a generated-file header.
Generation completes before replacing the previous file, so an invalid manifest
leaves the last successful types intact.

Run `bun test packages/bendo/gen --timeout 30000` for emitter goldens, strict
TypeScript consumers with positive and negative assertions, and the compiled
BND-37 fixture. The end-to-end test changes its Bend ID schema from integer to
string, rebuilds through the fixture cache, reruns the real CLI, and checks the
changed type with `tsc --noEmit`. Each compile and subprocess has a deadline.
