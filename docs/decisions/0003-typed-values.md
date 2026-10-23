# 0003: Generate typed record decoders from copyable Bend schemas

BND-5, 2026-10-22, Bend 2.0.38. Selected mechanism for M4 and M7; the code under
[`prototypes/0003-typed-values`](../../prototypes/0003-typed-values/) is a research
instrument, not a public schema API.

Author one copyable Bend schema value. At build time, evaluate it through Bend's
`.mjs` export and generate a named Bend record, a top-level typed decoder, JSON
Schema in the route manifest, TypeScript declarations from those JSON Schemas,
and a small JavaScript ABI adapter. Compile the generated decoder to both native
Bend and `.mjs`; those two targets own validation, coercion and default insertion.
The JavaScript adapter converts values and projects records; it contains no
independent field-validation rules.

This fits [0001](0001-route-table.md): routes remain data containing app-owned
`Data` tags and copyable schemas. The closed dispatcher selects a typed decoder
and its matching typed handler. A schema value does not magically change the
static type of an existing Bend definition. Generation happens before compiling
the app, so the handler can import the generated record type.

## Alternatives tested

### Generated records from schema data, selected

The application owns this declaration in [`schema.bend`](../../prototypes/0003-typed-values/schema.bend):

```python
def todo_schema() -> ObjectSchema:
  ObjectSchema{"Todo", [
    Field{"title", StringField{}, RequiredField{}},
    Field{"done", BooleanField{}, DefaultFalse{}},
    Field{"due", StringField{}, OptionalField{}},
  ]}

def routes() -> List<&2, Route>:
  [Route{"POST", "/todos", CreateTodo{}, todo_schema()}]
```

`ObjectSchema`, `Field`, `Presence`, `Scalar`, `HandlerTag` and `Route` are all
`Data`. The schema module imports no generated code. This prevents a generation
cycle: compile schema metadata first, generate records second, compile handlers
last. The generator inspects compiler-produced constructor objects rather than
parsing Bend source text.

The generated [`todo.bend`](../../prototypes/0003-typed-values/generated/todo.bend)
contains:

```python
type Todo is Data:
  Todo{title: String, done: Bool, due: Maybe<&2, String>}

def decode_object(+fields: List<&2, V.JsonField>, +mode: V.DecodeMode) -> Result<&2, &2, String, Todo>:
  do Result<&2, &2, String, Todo>:
    _ : Unit <- V.require_known(known_fields(fields))
    title : String <- V.read_string(V.lookup(fields, "title"))
    done : Bool <- V.read_flag(V.lookup(fields, "done"), mode)
    due : Maybe<&2, String> <- V.read_optional_string(V.lookup(fields, "due"))
    return Todo{title, done, due}
```

`decode` first requires `JsonObject`, then calls `decode_object`. The generic
`JsonValue` tree stops at that boundary. No handler reads a dictionary and
asserts it is a record. The full top-level handler and closed dispatcher are in
[`app.bend`](../../prototypes/0003-typed-values/app.bend):

```python
def create_todo(todo: T.Todo) -> String:
  T.Todo{title, done, due} = todo
  "ok:" ++ title ++ ":" ++ Bool.show(done) ++ ":" ++ due_text(due)

def dispatch(tag: S.HandlerTag, value: V.JsonValue, mode: V.DecodeMode) -> String:
  match tag:
    case S.CreateTodo{}:
      decoded(T.decode(value, mode))
```

`decoded` matches `Done{todo}` before calling `create_todo`; `Fail` produces an
error report. This report is a parity-test observation, not an HTTP response
serializer. A second route with another schema would select another generated
decoder and record in its own tag branch, preserving heterogeneous handler types.
The spike executes one route and one schema only.

### Schema-indexed values, compiled alternative

Bend supports type-level functions. [`indexed.bend`](../../prototypes/0003-typed-values/indexed.bend)
compiles this alternative to native code and `.mjs`:

```python
type Shape is Data:
  SchemaText{}
  SchemaFlag{}
  SchemaPair{left: Shape, right: Shape}

type Fields<-A: Data, -B: Data> is Data:
  Fields{left: A, right: B}

def Value(s: Shape) -> Data:
  match s:
    case SchemaText{}:
      String
    case SchemaFlag{}:
      Bool
    case SchemaPair{a, b}:
      Fields<Value(a), Value(b)>

def example() -> Value(SchemaPair{SchemaText{}, SchemaFlag{}}):
  Fields{"typed", False{}}
```

The consuming function takes that exact indexed type and extracts `left`. The
native program prints `typed`; Bun imports `.mjs` and observes the same value.
This tests type computation and consumption, not a complete indexed decoder.
An ordinary `A & B` pair is `Type` in this compiler, so the experiment uses an
explicit `Data` product instead of claiming such pairs are copyable.

For a todo, user code would consume nested `Fields` with positional `left/right`
fields, or need another generator to turn field-name strings into named Bend
record fields. A runtime schema chosen after routing also cannot give an
unrelated handler a new static record type without an index or an existential
wrapper. Indexing is viable for homogeneous generic validators, but generated
records give application handlers ordinary named fields and keep 0001's dispatcher
simple. We choose generation for that ergonomic and integration benefit, not
because Bend lacks dependent types.

A generic decoder returning `JsonValue` plus a hand-written `Todo` decoder also
works, but repeats the field contract in the schema and decoder. The selected
generator automates that second step. Generating from a Bend type declaration
instead would still need a separate place for defaults and coercion rules; the
schema data already holds presence policy and can grow those rules in M4.

## Manifest and TypeScript

[`generate.js`](../../prototypes/0003-typed-values/generate.js) loads `todo_schema()`
and `routes()` from compiled schema metadata. The manifest's body JSON Schema
is exactly:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "properties": {
    "title": { "type": "string" },
    "done": { "type": "boolean", "default": false },
    "due": { "type": "string" }
  },
  "required": ["title"],
  "additionalProperties": false
}
```

The response schema has the same properties but `required: ["title", "done"]`.
The entire [`manifest.json`](../../prototypes/0003-typed-values/generated/manifest.json)
includes `POST /todos`, handler `CreateTodo`, both schemas, decoder identities
`Todo:body` and `Todo:response`, and validator module/export/ABI and mode policies.
These identifiers are prototype spellings, not the final manifest format.

JSON Schema's `default` is an annotation; it does not insert a value. Its boolean
type does not express query coercion. The manifest therefore also records decoder
policy and points to the shared runtime. Consumers must call the decoder for
normalization, rather than treating a generic JSON Schema check as equivalent.

The generator derives this complete [`validator.d.ts`](../../prototypes/0003-typed-values/generated/validator.d.ts)
from the two manifest JSON Schemas and adds the adapter's callable contract:

```ts
export interface TodoInput {
  title: string;
  done?: boolean;
  due?: string;
}
export interface Todo {
  title: string;
  done: boolean;
  due?: string;
}
export type Validation = { kind: "ok"; value: Todo } | { kind: "error"; error: string };
export function validateTodo(input: unknown, mode?: "body" | "query" | "response"): Validation;
```

The default mode is `response`. A browser or Bun consumer calls:

```js
import { validateTodo } from "./generated/validator.js";
const result = validateTodo(JSON.parse('{"title":42,"done":false}'));
// { kind: "error", error: "expected string" }
```

The generated adapter turns a JSON value into Bend's `JsonValue` ABI and calls
`TodoDecoder.decode(tree, {$: "ResponseMode"})`. Custom constructors use
`{$: "Name", field: value}`; lists use `Con/head/tail` and `Nil`, optionals use
`Some/value` and `None`. Base booleans cross this compiler's ABI as JavaScript
booleans, strings as JavaScript strings, and `Nat` as numbers. The adapter projects
`Done{Todo{...}}` to the plain TypeScript object; absent `due` is omitted, not
`null` or a Bend `None` object. The `.d.ts` describes this public adapter, not the
raw default-exported Bend module. M7.4 must generate raw ABI declarations
separately when exposing arbitrary shared Bend definitions.

## Decoding rules and scope

Body and query modes insert `done=false` when it is missing. Query mode alone
accepts the exact strings `"true"`, `"1"`, `"false"`, `"0"`. Body mode rejects
string booleans. Response mode requires an actual boolean and never coerces or
inserts a missing default, so malformed server responses cannot become valid
through normalization. All modes reject unknown fields, non-objects, invalid
title/due types, and explicit `null` for optional `due`. `due` is an opaque string
in this spike, not a validated calendar date. Errors stop at the first failure;
error lists and paths remain BND-35 work.

There is no native JSON parser here. Bun and the browser use `JSON.parse`, then
an adapter builds the small Bend tree. The parity test constructs native Bend
literal trees from those same JSON fixtures and uses the same pure decoder and
typed handler. Numbers retain their category through `JsonNumber`; arrays are
represented only by a rejecting `JsonArray` marker because no schema accepts
them. This is deliberately sufficient for the todo, not a general JSON model.
`JSON.parse` resolves duplicate object keys before validation. Duplicate-key
syntax and JSON text parsing are outside this test.

This respects [0002](0002-bytes.md): HTTP bodies remain octets until strict UTF-8
and JSON decoding. The spike starts after that boundary and does not implement
or change it. BND-28 must supply the real parser and writer before production
schema validation consumes HTTP bodies.

M4 should keep pure scalar/presence decoders and a copyable schema description,
then generate named object records and top-level decoders. M7.2 should consume
manifest JSON Schemas for wire and response types; M7.3 should invoke the emitted
response validator on unknown fetch results. M7.4 and 7.4b should compile and
bundle those same pure decoders and their ABI adapters. The separate metadata
module and generated-artifact freshness check are part of this contract.

The bounded generator supports only required strings, optional strings and
booleans defaulting to false. It is fixed to one `Todo` schema and route family;
it is not an implementation of unions, arrays, refinements, the M4 API, the full
manifest CLI, typed fetch client or Vite plugin. No production files or laws change.

## Reproduce and verify

From the repo root, with the pinned Bend/Lean and Bun on PATH:

```sh
export PATH="$HOME/.bend/bin:$HOME/.elan/bin:$HOME/.bun/bin:$PATH"
bun install --frozen-lockfile
bun prototypes/0003-typed-values/generate.js
# The prototype's test script; compiles real Bend both ways in a disposable directory.
timeout --foreground 1m bun test --timeout 30000 tests/typed-values-prototype.test.ts
timeout --foreground 10m bun run check
```

The test covers 20 inputs, independently expected native and `.mjs` reports,
Bun runtime validation including malformed responses, reproducible generated
artifacts, manifest shape, TypeScript usage, and the compiled indexed alternative.
Each subprocess has a 30-second bound. The generated `.mjs` files are build
outputs ignored by Git. The checked-in generated sources make the chosen
contract reviewable and fail the test when they drift from the schema.

For the browser, generate into a temporary output directory and serve only
`page.html`, `validator.js` and `todo.mjs` from it with a temporary loopback
server. Open `page.html` using `agent-browser --session bnd-5 --profile
~/.agent-browser/profiles/bnd-5`, wait for `body[data-passed="3"]`, and screenshot
at desktop and mobile widths. The page must show an accepted valid response,
`expected string` for a numeric title, and `expected response boolean` for a
missing `done`. Stop the server afterward. This is a local verification page,
not a published preview or a laptop/phone access check.

Observed on ms-a2: the targeted test passed all 3 tests and 69 assertions; the
full gate printed `ALL PROOFS CHECK` and passed all 6 tests and 76 assertions.
Headless Chromium showed `3/3 response checks passed` at 1440×1200 and 390×1100,
with no JavaScript errors or horizontal overflow at mobile width. Evidence is
stored outside the repo at
`/home/leo/.agents/verify-notes/opencoredev__bendo/evidence/2026-10-22-bnd-5/`
(`check.log`, `browser.json`, `desktop.png`, `mobile.png`). Only this server's
browser was tested, not a physical phone or laptop. The temporary loopback
server and browser session were stopped. Independent GPT-6.1 Sol review found
no concrete defects in the candidate.
