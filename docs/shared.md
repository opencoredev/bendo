# Share Bend code with JavaScript

`bendo build --shared` compiles pure Bend files to ES modules with TypeScript
declarations, so a browser or a Bun/Node process runs the same code as the
native server. The typical use is validation: a form checks its input with the
schema its API route decodes with ([decision 0003](decisions/0003-typed-values.md)).

```sh
bendo build --shared            # shared/*.bend into dist/shared
bendo build --shared lib --out web/src/bend
```

Each `*.bend` file directly inside the directory becomes two files:

- `<name>.mjs`: Bend's ES module output, plus a named export for each pure def
  in that file.
- `<name>.d.mts`: its declarations. TypeScript pairs `import "./x.mjs"` with
  `x.d.mts`, never with `x.d.ts`, so this is the name it looks for.

Imported modules are compiled into the same `.mjs`. The output directory is
created if needed and both files are replaced atomically. A failed compile
prints Bend's diagnostic and writes nothing.

```ts
import { check, type Checked } from "./dist/shared/signup.mjs";

const result: Checked = check(JSON.stringify(form));
if (result.$ === "Rejected") showErrors(result.issues);
```

The working example is the signup fixture in
`packages/bendo/shared/fixtures/signup`: `shared/signup.bend` holds the schema,
`main.bend` serves it from a native route, and `web/` is a React form that
imports the compiled module.

## Exports

| Export | Contains | Typed as |
| --- | --- | --- |
| Named, such as `check` | Each def of the file itself that returns a value | Its Bend signature |
| `default["check"]` | The same function object | `typeof check` |
| `default["../src/data/json:parse"]` | Every def of every imported module, keyed by its path from the file's directory without `.bend`, a colon and its name | Its Bend signature |

Some defs keep only their `default` entry, typed `(...args: unknown[]) => unknown`:
type-level defs (`def Errors() -> Data`), defs that fill a law, names that are
not JavaScript identifiers or are reserved words, and any def whose compiled
argument count disagrees with its parsed signature. The build prints a warning
for the last case, naming the def.

Types declared in the file are top-level exports. Types of imported modules sit
in a namespace named after the file, so `src/data/schema.bend`'s `Schema` is
`schema.Schema`. A file named after a reserved word gets a trailing underscore:
`default.bend` becomes `default_`. A type-level def with only erased type parameters and a type
body becomes a type alias: `def Errors() -> Data: List<&2, Error>` gives
`schema.Errors`.

## How values cross

These mappings were read from Bend 2.0.38's compiled output and are checked by
`packages/bendo/shared/abi.test.ts`.

| Bend | JavaScript and TypeScript |
| --- | --- |
| `Nat`, `U32`, `F32` | `number` |
| `Bool` | `boolean` |
| `String`, `Char` | `string` (a `Char` is one code point) |
| `List<A>` | `{ $: "Nil" }` or `{ $: "Con"; head: A; tail: List<A> }`, not an array |
| `Maybe<A>` | `{ $: "None" }` or `{ $: "Some"; value: A }` |
| `Result<E, A>` | `{ $: "Fail"; error: E }` or `{ $: "Done"; value: A }` |
| `Either<A, B>`, `A \| B` | `{ $: "Inl"; value: A }` or `{ $: "Inr"; value: B }` |
| `A & B`, `Pair(A, B)` | `{ $: "Tuple"; fst: A; snd: B }` |
| `Cmp`, `Unit` | `{ $: "LT" }`, `{ $: "EQ" }`, `{ $: "GT" }`; `{ $: "Unit" }` |
| `Array<T>` | `T[]`, passed by reference and updated in place |
| `Map<V>` | `BendMap<V>`: `MTip`, `MLeaf{key, val}`, `MNode{pos, lo, hi}` |
| `Word(n)` | `Word`: bits as `WCon{head, tail}` ending in `WNil`, least significant first |
| A user type | A union of `{ $: "Constructor"; field: ... }` objects |
| `type Box<-A: Data>` | `Box<A>`; quantities such as `&2` and index parameters disappear |
| `List<U32>`, `List<&2, U32>` | `List<number>`; omitting the quantities gives the same type |
| `A -> B` parameter | `(arg: A) => B`; a plain JavaScript function works |
| `def f(x: A) -> B -> C` | `(x: A, arg1: B) => C`; Bend uncurries a function-typed result |
| Proofs `{a == b}`, value-indexed types | `unknown` |

Erased parameters (`-A: Data`) are not passed; type parameters become TypeScript
generics. The compiled functions also accept fewer arguments and return a
function for the rest, but the declarations describe only the full call.

Bend checks a few values at the boundary and nothing else:

- A `Nat` argument must be an integer from 0 to 2^53, or the call throws. A
  `Nat` result above 2^48 − 1 throws.
- A top-level `String` argument has lone UTF-16 surrogates replaced with U+FFFD.
  Strings nested inside data are passed as they are.
- `U32` and `F32` arguments are not checked. `F32` rounds to single precision.

## What cannot be shared

- **IO.** A file whose own def returns `IO(...)`, directly or through a
  type-level alias such as `def Action() -> Type: IO(Unit)`, is refused:
  `shared code must be pure, but \`announce\` returns IO`. Effects need Bend's
  event loop, which the module does not include. An imported module's IO defs
  still appear on `default`, typed as `unknown`; do not call them.
- **Templates.** Defs with a `~` parameter inline at compile time and are not
  exported.
- **Laws.** Proof defs are exported by Bend but carry no meaning in JavaScript.

## Stack safety

Bend compiles a self tail call to a loop. Any other recursion uses the
JavaScript stack, which overflows after a few thousand to tens of thousands of
calls, long before native code would. Code meant for the browser should therefore loop over input
with tail calls and accumulators, as `src/http/text.bend` does (BND-84).

The shared schema path is checked on 64 KiB inputs in Bun and in Node at its
default stack (`packages/bendo/shared/stack.test.ts`): `Schema.decode` and its
error report, text coercion, JSON parsing and writing, UTF-8, and both pattern
matchers. The same test lists every function in the compiled module that still
recurses outside a loop, with the reason its depth is bounded. A new one fails
the test until it is classified or rewritten. What remains is bounded by:

- nesting, which the JSON parser caps at 512 levels;
- the schema's own depth;
- the pattern size cap of 128 nodes;
- at most `error_cap()` (100) errors per child;
- the number of fields an object schema declares.

The last one depends on the schema, not the input. In Node 24 at its default
stack, an object schema with 3,000 declared fields decodes and one with 3,500
overflows; Bun handled 16,384. The test pins 1,000 fields on Node. Split larger
objects into nested schemas.

## Limits

- The declarations come from reading Bend source headers, cross-checked against
  the compiled argument counts. A signature the reader cannot express becomes
  `unknown` rather than a guess.
- Bend 2.0.38 has no `I32` or `F64`; Base numbers are `Nat`, `U32` and `F32`.
- `bendo dev` does not rebuild shared modules. Run `bendo build --shared` after
  editing them, or import the `.bend` file through
  [vite-plugin-bendo](vite-plugin.md), which recompiles it on save.
