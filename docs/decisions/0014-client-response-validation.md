# 0014: How response schemas reach the typed client

Date: 2026-10-24. Issue: BND-57. Status: accepted for M7.

The typed client validates 2xx response bodies against each route's response
JSON Schema. Types are erased at runtime, so the schemas need their own path
from the manifest to the browser.

## Decision

`bendo gen` writes two files from the same manifest:

- `.bendo/routes.ts`: the `Routes` type union from BND-56, unchanged.
- `.bendo/routes.schemas.ts`: `export const schemas`, one row per route in
  registration order with `method`, `path`, `all` and, when the route has
  one, the `response` schema as a plain object literal.

An app opts in to validation by importing the second file and passing it to
`createClient<Routes>(baseUrl, { schemas })`. `validate: false` switches it
off while keeping the import. Without `schemas`, nothing is validated.

The client validates with Ajv 8's `Ajv2020`, using the settings the schema
export is tested with (`strict: true`, `ownProperties: true`, see
[validator settings](../data/json-schema.md#validator-settings)), plus
`allErrors: true` to report every issue. Ajv is a dependency of the `bendo`
package and is loaded with a dynamic `import()` on the first validation, so a
client that never validates does not load it.

## Why

- **Always write the schemas file.** The ticket suggested an opt-in flag. A flag
  lets the two files drift: run `bendo gen --schemas` once and plain
  `bendo gen` later, and the client validates against stale schemas. Writing
  both every time costs one unused file for apps that do not validate. The
  opt-in is the import.
- **A table, not code.** The file holds data only and imports nothing, like
  `routes.ts`. It works without the `bendo` package on the import path, and
  `__proto__` keys are written as computed keys so they stay own properties.
- **Ajv over the BND-58 decoder.** BND-58 (shared Bend code compiled to
  JavaScript) has not landed. Ajv is already the validator the export is
  tested against, so the documented
  [differences from the decoder](../data/json-schema.md#decoder-policy-and-validator-differences)
  apply unchanged. Response bodies are not coerced or defaulted by the server,
  which is the case where a JSON Schema validator and the decoder agree best.
- **Not Standard Schema yet.** A pluggable validator interface would add API
  surface without a second implementation to test it. When BND-58 lands, a
  decoder-backed validator can be added behind the same `schemas` option.

## Costs

- Ajv compiles schemas with `new Function`. A page with a Content Security
  Policy that forbids `unsafe-eval` cannot validate; pass `validate: false`.
- Ajv 2020 adds about 134 KB minified (40 KB gzipped) to the chunk that
  validates, measured with `bun build --minify --target=browser`.
- Validation inherits Ajv's limits: lossy numbers, lexical integers, and the
  ignored `__proto__` property schema.
