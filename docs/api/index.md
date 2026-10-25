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
| [Middleware](bend/middleware.md) | Built-in middleware: logging, auth, JWT, compression, CORS, security headers, caching, limits, IP rules, rate limits |
| [Streaming and real time](bend/streaming.md) | Streams, Server-Sent Events, WebSockets, pub/sub, static files, the reverse proxy |
| [Stores and the clock](bend/state.md) | Shared state actors and the wall clock |
| [Data and protocol modules](bend/modules.md) | Cookies and signing keys, forms, multipart, JSON Schema, hashing, comparison, random bytes, encodings, route patterns, WebSocket frames, raw requests and responses |

The examples and guides also import some modules beside `B`. The reference
writes their names with these aliases:

| Alias | Module | For |
| --- | --- | --- |
| `C` | `bendo/app/context.bend` | Middleware and handlers with typed request variables |
| `Clock` | `bendo/effects/clock.bend` | Wall-clock time |
| `Z` | `bendo/compress.bend` | Response compression |
| `Cors`, `CorsPolicy` | `bendo/mw/cors.bend`, `bendo/mw/cors_policy.bend` | CORS as a middleware call |
| `J` | `bendo/data/json.bend` | JSON values |
| `M` | `bendo/ws/message.bend` | WebSocket messages |
| `Methods` | `bendo/router/methods.bend` | The route table's build errors and the method router |
| `P` | `bendo/ws/pubsub.bend` | WebSocket publish and subscribe |
| `S` | `bendo/data/schema.bend` | Schemas and decoded values |
| `Store` | `bendo/app/store.bend` | Store errors and operations |
| `V` | `bendo/validated.bend` | Serving an app whose routes have schemas |
| `W` | `bendo/ws/connection.bend` | WebSocket connection handles |
| `Cookie` | `bendo/data/cookie.bend` | Cookie options |
| `Form`, `Multipart` | `bendo/data/form.bend`, `bendo/data/multipart.bend` | Request bodies from HTML forms |
| `JS` | `bendo/data/json-schema.bend` | JSON Schema export |
| `SchemaPattern` | `bendo/data/schema-pattern.bend` | String patterns for schemas |
| `SHA`, `Hex`, `Utf8` | `bendo/crypto/sha256.bend`, `bendo/data/hex.bend`, `bendo/data/utf8.bend` | Hashing and encodings |
| `Compare`, `Random` | `bendo/crypto/compare.bend`, `bendo/crypto/random.bend` | Comparing secrets and random bytes |
| `SignedCookie` | `bendo/data/signed-cookie.bend` | Signed-cookie keys |
| `Config` | `bendo/app/config.bend` | The server config record, to change a field |
| `Table` | `bendo/app/table.bend` | Hook stages for `B.hook` |
| `Request`, `Response` | `bendo/http/request.bend`, `bendo/http/response.bend` | HTTP methods and raw responses |
| `StreamTypes`, `SseTypes` | `bendo/http/stream_types.bend`, `bendo/http/sse_types.bend` | Stream and SSE step values |
| `RoutePattern` | `bendo/router/pattern.bend` | Compiling and matching route patterns |
| `Frame` | `bendo/ws/frame.bend` | Decoding WebSocket frames |

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
- Every name that a shipped example (`examples/`), a `create-bendo` template,
  or a published guide calls through another module, such as `J.Json` or
  `C.header`. A guide counts its Bend examples and its inline code, in prose
  and tables, under the aliases its examples import. A constructor counts as
  its type. Other defs in those modules
  are internal and can change without notice. The laws and design decisions
  name internals too; they do not make them public.
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

## Opt-in modules

| Page | Alias | Module | Covers |
| --- | --- | --- | --- |
| [SQLite](bend/sqlite.md) | `Sql` | `bendo/sqlite.bend` | Connections, statements with bound parameters, rows as JSON or schema values, transactions |

An opt-in module is not imported by `main.bend`, so an app that does not
import it does not compile it.
