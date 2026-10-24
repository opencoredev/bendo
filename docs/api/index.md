# API reference

One entry per public function, type and export, with its signature, what it
does, and an example. The guides explain how the pieces fit together; come here
for exact names and arguments.

## Bend library

Import the library once, as `B`. Most apps need nothing else:

```bend signature
import Base
import ./bendo/main.bend as B
```

| Page | Covers |
| --- | --- |
| [App and server](bend/app.md) | Core types, `B.serve` and its variants, server config, plugins |
| [Routing](bend/routing.md) | Route registration, middleware and hook entries, groups, guards, `Methods` |
| [Context and responses](bend/context.md) | Reading the request, building responses, errors, cookies, connection info, `C` |
| [Validation and JSON](bend/validation.md) | Route schemas, validated values, `S` schemas and decoding, `J` JSON values |
| [Middleware](bend/middleware.md) | Built-in middleware: logging, auth, JWT, CORS, security headers, caching, limits, IP rules, rate limits |
| [Streaming and real time](bend/streaming.md) | Streams, Server-Sent Events, WebSockets, pub/sub, static files, the reverse proxy |
| [Stores and the clock](bend/state.md) | Shared state actors and the wall clock |

A few modules are imported beside `B` by the examples and templates, under
these names:

| Alias | Module | For |
| --- | --- | --- |
| `C` | `bendo/app/context.bend` | Middleware and handlers with typed request variables |
| `Clock` | `bendo/effects/clock.bend` | Wall-clock time |
| `Cors`, `CorsPolicy` | `bendo/mw/cors.bend`, `bendo/mw/cors_policy.bend` | CORS as a middleware call |
| `J` | `bendo/data/json.bend` | JSON values |
| `M` | `bendo/ws/message.bend` | WebSocket messages |
| `Methods` | `bendo/router/methods.bend` | The route table's build errors and the method router |
| `P` | `bendo/ws/pubsub.bend` | WebSocket publish and subscribe |
| `S` | `bendo/data/schema.bend` | Schemas and decoded values |
| `Store` | `bendo/app/store.bend` | Store errors and operations |
| `V` | `bendo/validated.bend` | Serving an app whose routes have schemas |
| `W` | `bendo/ws/connection.bend` | WebSocket connection handles |

## TypeScript packages

| Page | Import |
| --- | --- |
| [bendo](ts/bendo.md) | `bendo`: OpenAPI generation and locating Bend |
| [bendo/shared](ts/shared.md) | `bendo/shared`: compile shared Bend modules to JavaScript |
| [bendo/client](ts/client.md) | `bendo/client`: the typed client |
| [bendo/query](ts/query.md) | `bendo/query`: TanStack Query options |
| [vite-plugin-bendo](ts/vite-plugin.md) | `vite-plugin-bendo`: import `.bend` files from a Vite app |

The `bendo` and `create-bendo` command lines are covered in
[Develop with the CLI](../cli.md) and the
[create-bendo README](../../packages/create-bendo/README.md). `create-bendo`
exports no modules.

## What counts as public

A test, `tests/api-coverage.test.ts`, fails when a public API has no entry
here or an entry names something that is not public. Public means:

- Every top-level def in `src/main.bend`, written `B.name`.
- In the modules in the alias table above, the names that a shipped example
  (`examples/`), a `create-bendo` template, or a published guide calls. A
  constructor counts as its type. Other defs in those modules are internal
  and can change without notice. The modules are the ones those examples and
  templates import, plus `app/context.bend`, which the
  [middleware guide](../middleware.md) imports for typed middleware.
- Every export of each entry point in the `exports` map of `bendo` and
  `vite-plugin-bendo`, read with the TypeScript compiler.

`bun scripts/api-coverage.ts --list` prints the current list.

## How the examples are checked

Every example on these pages is compiled as part of the test above.

- Bend: the Bend examples on one page form a single program, in page order.
  Each page's first example holds the setup the rest of the page uses. Imports
  are moved to the top, `./bendo/` points at `src/`, and a `main` is added. The
  program is compiled to C with the pinned Bend, which typechecks every def.
  Builds are cached by content, so an unchanged page is not compiled again.
- TypeScript: each example is its own module, typechecked with the repository's
  compiler options. `./.bendo/routes` and `./.bendo/routes.schemas` are the
  files `bendo gen` writes for the client's test app.

Blocks that show a signature are not compiled. They use the
library's public names (`B.Ctx`, `B.Res`) where the source uses internal
module names.
