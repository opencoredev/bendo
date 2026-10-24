# 0013: Where Bendo builds its OpenAPI document

Date: 2026-10-24. Issue: BND-62. Status: accepted for M7.

An app's routes and schemas already leave the binary as the `--bendo-routes`
manifest ([manifest](../manifest.md)), with one JSON Schema 2020-12 document
per slot. OpenAPI 3.1 uses that same dialect for its Schema Objects, so the
whole conversion is reshaping: patterns to path templates, slots to
parameters, bodies and responses. The question was where that reshaping runs.

## Options

1. **In the TypeScript toolkit.** `bendo openapi` builds the app, reads the
   manifest and writes `openapi.json`.
2. **In Bend at runtime.** The server builds the document from its own route
   table and serves it at `/openapi.json`.
3. **Both.** Generate in the toolkit, serve from Bend.

## Decision

Option 3, split by job. The toolkit generates; an opt-in Bend module serves.

- `packages/bendo/src/openapi.ts` turns a parsed manifest into the document.
  `bendo openapi` writes it as JSON, and with `--bend` also as a Bend module
  whose `json()` returns the text, so the binary can embed it.
- `src/api-docs.bend` serves a document string with `application/json` and
  the Scalar page with its own Content-Security-Policy. Only apps that import
  it compile it.

## Why

**Compile cost.** Every module `main.bend` imports is compiled into every app
and every test fixture, which is why the schema exporter is already opt-in
through `src/serve-schemas.bend`. Converting patterns, merging duplicate
templates and emitting OpenAPI in Bend would add a JSON-building module to
each app that wants docs. The serving module is about 100 lines of string
building, kept out of `main.bend`.

**One parser.** The manifest is already the boundary that BND-56 type
generation reads through `parseManifest`. Reading it again for OpenAPI keeps
both consumers on the same parsed value, and a manifest change shows up in
both test suites.

**Runtime generation buys little.** The document only changes when routes or
schemas change, and both are fixed at compile time. A server that rebuilt it
would produce the same text on every start.

**A large string literal is not free.** Bend's compiler overflows its stack on
one string literal of 26 KB. The generated module splits the document into
256-character literals, one def each, joined when `json()` runs. A 26 KB test module
compiled in under two seconds.

## Costs

- The embedded document can go stale. `bendo openapi --bend` must run after a
  route or schema change, as `bendo gen` must for types. The fixture's test
  regenerates the document from the compiled manifest and fails on a diff.
- Apps that would rather not embed can write `openapi.json` and serve it with
  `B.serve_static`; the docs page only needs a URL.
- OpenAPI 3.1 cannot express every Bendo route. Extension methods, optional
  captures, uncaptured wildcards and routes shadowed by an earlier one are
  mapped or left out as [OpenAPI](../openapi.md) describes, and the generator
  prints a warning for each route it drops.
