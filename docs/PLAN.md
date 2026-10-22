# Bendo plan

Bendo is a Hono-style web framework for the [Bend](https://bend-lang.com) language, with a TypeScript toolkit that lets a React app call it with full types. The server compiles to one native binary. Its core (parsing, routing, JSON, validation) carries machine-checked proofs in `LAWS.bend`, and the same Bend validation code runs in the browser.

The target is near parity with Hono, borrowing Elysia's best ideas (route-level schemas, lifecycle hooks, end-to-end types), done the Bend way. Features that only make sense on edge runtimes or in browsers are left out. Bend-only features are added on top.

Linear: team **BND**, project **Bendo v1**. Every section below maps to a milestone, and every numbered item to one ticket.

## Definition of done for v1

The program is done when all of these hold on `main`:

1. `bend PROOF.bend --verdict` prints `ALL PROOFS CHECK`, and every law listed in this plan exists.
2. `bun run check` passes: proofs, typecheck, lint, and every integration test against real compiled servers.
3. The todo example runs end to end: a Bend API and a React app, using the typed client and shared validators, checked in a real browser at desktop and phone widths.
4. The benchmark suite has published results against Hono and Elysia on Bun, run on a Boat sandbox.
5. The docs site builds and covers every public API.
6. Publishing to npm and BendHub is ready behind one command each, and waits for Leo's go.

## What the spike proved

Run on ms-a2 with Bend 2.0.38 on 2026-10-22. The scratch code is in `~/scratch-bendo-spike` and is throwaway.

| Question | Result |
|---|---|
| Can Bend serve HTTP? | Yes. Bend's own `demos/io_http_server` compiles in 0.7 s to a 68 KB binary and answers curl. |
| How fast, roughly? | About 50,000 req/s for hello world against 55,000 for `Bun.serve`, with 32 concurrent fetch loops from Bun. The load generator was likely the limit, so this is a floor, not a ceiling. |
| Does parsing each request in pure Bend hurt? | No measurable cost: about 52,000 req/s while splitting the request line on every request. |
| Can TypeScript call Bend code? | Yes. `bend x.bend -o x.mjs` exports pure defs, and Bun called `path_of` with a plain JS string. |
| Can the app be passed to the server loop? | Yes, as a template (`~app`). Bend cannot copy functions, so a handler closure cannot be reused across requests; a template is inlined at compile time and may run any number of times. |
| Can modules import across folders? | Yes. `import ../../src/http.bend as Http` works. |

## Design decisions

These hold for every ticket. Changing one needs a written reason in `docs/decisions/`.

1. **The app is a template.** `Serve.serve(~app, config)` takes the app as compile-time syntax. Handlers are top-level defs. How a route table of many handlers is expressed is the first prototype (BND M0, "Choose the route-table shape").
2. **Parse bytes, not strings.** Bend's `String` is a list of characters, and `Content-Length` counts bytes. The HTTP layer works on `TCP.recv_bytes` and UTF-8 encodes bodies itself, unless the M0 prototype shows a better path.
3. **Pure core, thin IO shell.** Parsing, routing, middleware composition, JSON and validation are pure functions with laws. The accept loop and connection handling are `@unsafe` IO and are covered by integration tests instead of proofs.
4. **One event loop for IO, all cores for compute.** Each connection runs in its own `IO.spawn` computation. Heavy handler work uses Bend's parallel calls, and `!` calls can move it to the GPU.
5. **Shared state lives in an actor.** Bend has no global mutable state. Counters, caches, sessions, rate limits and in-memory stores run as a spawned computation that owns the state and answers over a `Chan`.
6. **Bendo may ship its own effects.** Bend effects are a `.c` file plus a `.js` twin. Bendo adds the ones Base lacks (peer address, fast hashing, gzip, SQLite) the same way, and each one lists what it does outside the proofs.
7. **Types flow from Bend to TypeScript.** A compiled app prints a route manifest (`--bendo-routes`) with schemas as JSON Schema. `bendo gen` turns it into TypeScript types for the client. Nobody writes route types twice.
8. **Laws are human-owned.** Agents may add laws. They never delete or weaken one without a written reason in the commit and a Linear comment.

## Architecture

```
bendo/
  src/            Bend library (published to BendHub as bendo@x.y/main.bend)
    main.bend       public entry, re-exports the API
    http/           request, response, parser, writer, connection loop
    router/         patterns, spec router, trie router
    app/            app builder, context, middleware, hooks, errors, plugins
    data/           json, forms, multipart, cookies, schema
    mw/             built-in middleware
    stream/         chunked, SSE, WebSocket
    effects/        Bendo's own C and JS effects
  LAWS.bend       every law
  PROOF.bend      every proof
  packages/
    bendo/          npm "bendo": CLI, typed client, codegen, query helpers
    create-bendo/   npm "create-bendo": project scaffolder
    vite-plugin-bendo/  import .bend files from a Vite app
  examples/       hello, todo (fullstack), chat (WebSocket), mandelbrot (parallel)
  tests/          integration tests against compiled servers (bun test)
  bench/          load-test harness and results
  docs/           this plan, decisions, docs site
```

## API sketch

The final shape depends on the M0 route-table prototype. This is the target feel.

```python
import Base
import bendo@0.1/main.bend as B

def list_todos(c: B.Ctx) -> IO(B.Res):
  B.json(c, Todos.to_json(Todos.all()))

def get_todo(c: B.Ctx) -> IO(B.Res):
  B.json(c, Todo.to_json(Todos.find(B.param(c, "id"))))

def app(req: B.Req) -> IO(B.Res):
  B.app(~[
    B.use(~B.logger),
    B.use(~B.cors(B.cors_defaults)),
    B.get("/todos", ~list_todos),
    B.get("/todos/:id{int}", ~get_todo),
    B.post("/todos", ~create_todo, B.body(TodoInput.schema)),
  ], req)

def main() -> IO(Unit):
  B.serve(~app, B.config_defaults)
```

```ts
import { createClient } from "bendo/client";
import type { Routes } from "./.bendo/routes";

const api = createClient<Routes>("http://localhost:8787");
const todo = await api.todos({ id: 42 }).get(); // typed from the Bend schema
```

## M0. Foundation

Ready the toolchain and settle the open design questions before feature work.

- **0.1 Pin the toolchain and enable the strict proof check.** Pin Bend 2.0.38 in one place, install Lean through elan so `bend PROOF.bend --verdict` runs locally and in CI, and document setup in `AGENTS.md`.
- **0.2 Make CI the full gate.** Proofs with `--verdict`, typecheck, oxlint and oxfmt, integration tests. A failing law blocks merge.
- **0.3 Choose the route-table shape.** Prototype at least three ways to express many routes with template handlers (a template list, a data table plus generated dispatch, a template chain). Measure per-request overhead at 5, 50 and 500 routes. Record the choice in `docs/decisions/0001-route-table.md`.
- **0.4 Choose bytes or strings for HTTP parsing.** Prototype both on a realistic request with headers and a JSON body. Measure throughput and correctness on UTF-8 bodies. Record the choice in `docs/decisions/0002-bytes.md`.
- **0.5 Build the benchmark harness early.** A script that boots a Boat sandbox, runs `oha` against Bendo, Hono on Bun and Elysia on Bun for hello, JSON and path-param routes, writes results to `bench/results/*.json`, and deletes the sandbox.

## M1. HTTP core

A correct HTTP/1.1 server under the router.

- **1.1 Parse requests.** Request line, method (all standard methods plus extension tokens), target split into path and query, HTTP/1.0 and 1.1, headers with case-insensitive lookup and repeated headers kept. Laws: writing a request then parsing it gives it back; header lookup ignores case.
- **1.2 Read bodies.** `Content-Length` across many reads, chunked transfer decoding, `Expect: 100-continue`, a configurable body limit answered with 413.
- **1.3 Write responses.** Status codes with reason phrases, headers, `Content-Length` in UTF-8 bytes, a `Date` header from `IO.now`, no body for HEAD, 204 and 304. Laws: the written body follows the first blank line; `Content-Length` equals the body's byte length.
- **1.4 Manage connections.** Keep-alive with a per-connection loop, pipelined requests answered in order, idle and read timeouts with `TCP.try_recv`, header size limit answered with 431, malformed input answered with 400 and a closed socket, a max-requests-per-connection setting.
- **1.5 Add the pure entrypoint and server config.** `B.handle(app, request)` runs the app with no network, for tests. `B.config` covers host, port (with `$PORT`), limits and timeouts. The binary prints its route manifest when run with `--bendo-routes`.
- **1.6 Prove conformance and robustness.** Integration tests over raw sockets: split reads, pipelining, slow clients, oversized headers, bad request lines, binary bodies. A TypeScript fuzz test throws random and mutated requests at the server and checks it never crashes or hangs.

## M2. Routing

Hono's routing power, with a proof that the fast router is right.

- **2.1 Compile path patterns.** Static segments, `:param`, optional `:param?`, wildcard `*` and named wildcards, constraints such as `{int}`, `{uuid}`, `{slug}` and simple character classes (Bend has no regex). Percent-decoded params. Laws: filling a pattern with params and matching the result gives back the same params.
- **2.2 Build a spec router and a trie router, and prove them equal.** The spec router scans routes in order, first match wins. The trie router is fast. Law: for every route table and path, the two give the same answer. This is Bendo's headline proof.
- **2.3 Handle methods and misses.** `get`, `post`, `put`, `patch`, `delete`, `options`, `head`, `all` and `on(methods, path)`. HEAD answered from GET. 404 for no path match, 405 with an `Allow` header for a wrong method. Strict or lenient trailing slashes and case.
- **2.4 Compose apps.** `basePath`, mounting a sub-app with `route(prefix, sub)`, Elysia-style `group(prefix, routes)`, `show_routes` printing a table, and the route manifest as JSON.
- **2.5 Port Hono's router tests.** Turn Hono's router test cases (MIT) into a fixture table and run every case against both routers.

## M3. App, context and middleware

The developer-facing API.

- **3.1 Build the context.** Request accessors: `param`, `query`, `queries`, `header`, `method`, `path`, `url`. Response helpers: `text`, `json`, `html`, `body`, `redirect`, `not_found`, `status`, `header`. Typed per-request variables (`set`, `get`), in the spirit of Elysia's `derive` and `decorate`.
- **3.2 Add onion-model middleware.** Middleware runs code before and after `next`, in registration order, like Hono. Laws: the identity middleware changes nothing; composing middleware is associative.
- **3.3 Add Elysia-style lifecycle hooks.** `on_request`, `on_parse`, `on_transform`, `before_handle`, `after_handle`, `map_response`, `on_error`, `on_after_response`, each scoped globally, to a group, or to one route, plus `guard` for shared hooks and schemas.
- **3.4 Handle errors.** An `HttpError` type with status and message, `on_error` and `not_found` handlers, JSON or text error bodies by `Accept`, no internals leaked. Find out what a handler crash (`IO.die`) does to other connections, and contain it if possible.
- **3.5 Add plugins.** A plugin is a function from app to app, applied with `use`. Named plugins apply once even if used twice, like Elysia. Include a plugin-authoring guide.
- **3.6 Add the state actor.** `B.Store` runs a computation that owns a value and answers get, set and update messages over a `Chan`. Backs counters, caches, sessions, rate limits and the todo example.

## M4. Data and validation

JSON, forms and schemas, with laws.

- **4.1 Parse and write JSON.** A JSON value type, a parser that terminates by construction (one def with a mode argument instead of mutual recursion), a writer with correct escaping and Unicode, and pretty printing. `req_json` and `json`. Law: parsing written JSON gives the same value.
- **4.2 Parse query strings and URL-encoded forms.** Percent encoding and decoding, repeated keys, `parse_body` for forms. Law: decoding an encoded string gives it back.
- **4.3 Parse multipart form data.** Fields and in-memory files with size limits.
- **4.4 Read and write cookies.** Parse `Cookie`, write `Set-Cookie` with every attribute, and signed cookies with HMAC-SHA256 (needs 5.4).
- **4.5 Build the schema language.** Like Elysia's `t`: string, number, integer, boolean, literal, enum, object, array, optional, nullable, union, with min and max, length, simple patterns, email and URL checks, and defaults. Coerces strings for params and query. Decodes into typed values with a list of errors, each with a path. Laws: an accepted value satisfies the schema's predicate; a rejected value names the failing path.
- **4.6 Validate at the route.** Per-route schemas for params, query, headers, body and response. Bad input answers 400 or 422 with the error list. Handlers receive already-validated values.
- **4.7 Export schemas as JSON Schema.** Feeds OpenAPI (7.7) and TypeScript generation (7.2).
- **4.8 Add a SQLite effect.** Stretch. A Bendo effect wrapping SQLite: open, prepared statements, typed rows through schemas, transactions. Gives Bendo apps a real database.

## M5. Built-in middleware

Hono's middleware list, minus what does not fit a native server.

- **5.1 Logging and timing.** Logger, request ID, `Server-Timing`, `X-Powered-By` toggle, pretty JSON.
- **5.2 CORS and header hygiene.** CORS with preflight, secure headers (Helmet-style), method override, trailing-slash redirect or trim.
- **5.3 Limits and caching.** Body limit, request timeout, ETag with 304, `Cache-Control` helpers.
- **5.4 Add crypto and encoding.** Base64 and base64url, hex, SHA-1, SHA-256, HMAC-SHA256, secure random bytes. Write them in pure Bend with test vectors and laws for the encodings, and use a C effect only if benchmarks demand it.
- **5.5 Authentication.** Basic auth, bearer auth, JWT sign and verify (HS256), and CSRF protection by origin check.
- **5.6 Connection info and rate limiting.** A peer-address effect (`getpeername`), IP allow and deny lists, and a rate limiter on `B.Store` (fixed window and token bucket) with `RateLimit` headers.
- **5.7 Serve static files.** MIME types, index files, ETag and `Last-Modified`, range requests. Law: no request path resolves outside the static root.
- **5.8 Compress responses.** Stretch. gzip and deflate through a zlib effect, chosen by `Accept-Encoding`, skipped for small or already-compressed bodies.
- **5.9 Proxy requests.** Forward a request to an upstream over `TCP.connect` and stream the answer back.

## M6. Streaming and realtime

- **6.1 Stream responses.** Chunked transfer encoding and a `stream` helper with backpressure through `TCP.try_send`.
- **6.2 Server-Sent Events.** `stream_sse` with event, id and retry fields, heartbeats, and `Last-Event-ID`.
- **6.3 WebSockets.** The upgrade handshake, frame parsing and writing (masking, fragments, ping, pong, close) with roundtrip laws, an `open`/`message`/`close` handler API, and Elysia-style publish and subscribe on top of `B.Store`.

## M7. TypeScript toolkit

What makes Bendo feel like Hono plus Elysia from a React app.

- **7.1 Build the CLI.** `bendo new`, `dev` (watch `.bend` files, rebuild, restart, readable compiler errors), `build`, `start`, `routes`, `prove`, `gen`, `doctor`.
- **7.2 Generate route types.** `bendo gen` reads the route manifest and writes TypeScript types for every route's params, query, body and responses.
- **7.3 Build the typed client.** Eden Treaty-style calls (`api.todos({ id }).get()`) on `fetch`, typed errors, and validation of responses through the generated types. Tested against a real compiled server.
- **7.4 Share Bend code with the browser.** `bendo build --shared` compiles `shared/*.bend` to `.mjs` with generated `.d.ts` files, and `vite-plugin-bendo` lets a Vite app import `.bend` files directly.
- **7.5 Add TanStack Query helpers.** `bendo/query` builds `queryOptions` and `mutationOptions` from the client.
- **7.6 Build `create-bendo`.** `bun create bendo` with an API-only template and a fullstack React template.
- **7.7 Generate OpenAPI.** OpenAPI 3.1 from the manifest, and a `/docs` route that serves Scalar.

## M8. Examples and showcases

- **8.1 Build the todo app.** A Bend API (CRUD, validation, `B.Store`, CORS) and a React app on Vite, TanStack Router and TanStack Query, using the typed client and shared validators. Checked in a real browser at desktop and phone widths.
- **8.2 Show off parallel compute.** A route that renders a Mandelbrot image as BMP on every CPU core, and on the GPU where present, with single-thread timing next to it.
- **8.3 Build a realtime chat.** WebSockets with publish and subscribe, and a small React client.
- **8.4 Explain the proofs.** A docs page listing every law in plain words and what it guarantees.

## M9. Performance

- **9.1 Run the full benchmark suite.** Hello, JSON, params, body echo and a five-middleware stack, against Hono on Bun and Elysia on Bun, on a Boat sandbox with `oha`. Record method and hardware with results.
- **9.2 Optimize the hot paths.** Parser, header lookup, router and writer, guided by profiles. Add a performance smoke test to CI with a budget.
- **9.3 Use every core.** Measure `+RTS --threads` and, if it helps, an `SO_REUSEPORT` effect for several accept loops.

## M10. Docs and release

- **10.1 Build the docs site.** Getting started, concepts, API reference, guides modeled on Hono's docs, and migration guides from Hono and Elysia.
- **10.2 Write the repo docs.** README with the benchmark chart, examples index, CONTRIBUTING, and an up-to-date `AGENTS.md`.
- **10.3 Prepare releases.** Changesets for the npm packages, a BendHub publish script, and a versioning policy. Publishing waits for Leo's go.
- **10.4 Run the launch review.** A security review of parsing and middleware, a final fuzz run, `--verdict` on every proof, and a check that every API in the docs exists.

## Parity with Hono and Elysia

| Feature | Hono | Elysia | Bendo |
|---|---|---|---|
| Routing with params, wildcards, constraints | Yes | Yes | 2.1 |
| Multiple router engines | Yes | No | 2.2, with a proof they agree |
| 405 with `Allow` | No | No | 2.3 |
| Sub-apps, `basePath`, groups | Yes | Yes | 2.4 |
| Context helpers | Yes | Yes | 3.1 |
| Onion middleware | Yes | No | 3.2 |
| Lifecycle hooks | No | Yes | 3.3 |
| Plugins | Partial | Yes | 3.5 |
| Validation | Middleware | Built in | 4.5, 4.6, with laws |
| JSON, forms, multipart, cookies | Yes | Yes | M4 |
| Built-in middleware | About 25 | Plugins | M5 |
| Streaming, SSE | Yes | Yes | 6.1, 6.2 |
| WebSockets | Per runtime | Yes | 6.3 |
| Typed client | `hc` | Eden | 7.3 |
| OpenAPI | Third party | Plugin | 7.7 |
| Testing without a network | `app.request` | `app.handle` | 1.5 |
| Shared validators in the browser | No | No | 7.4 |
| Proven core | No | No | `LAWS.bend` |
| Parallel and GPU handlers | No | No | 8.2 |
| Runs on edge runtimes | Yes | Partly | No, native binary only |
| JSX rendering | Yes | Plugin | No, React owns the UI |
| TLS, HTTP/2 | Via runtime | Via runtime | No, use a proxy in front |

## Out of scope for v1

- Adapters for Cloudflare Workers, Deno, Lambda or other runtimes.
- Server-side JSX or HTML templating beyond a simple `html` helper.
- TLS, HTTP/2 and HTTP/3. Put Caddy or Cloudflare in front.
- A Bend-written React. The browser side is ordinary React.
- Publishing to npm or BendHub without Leo's go.

## Risks

| Risk | Where it bites | What to do |
|---|---|---|
| Bend is young and changes fast | Everywhere | Pin the version. Upgrade on purpose in its own ticket. |
| The route table cannot be both ergonomic and fast with templates | M0, M2, M3 | Settle it in 0.3 before M2 starts. |
| Proving the trie router equal to the spec router is very hard | 2.2 | Ship the spec router first; the trie lands only with its proof. |
| Termination rules make the JSON and multipart parsers awkward | M4 | Use fuel tied to input length, as the guide recommends. |
| A handler crash takes down the whole process | 3.4 | Measure early, document, contain if Bend allows. |
| Custom C effects break the JS target or hub publishing | 5.4, 5.6, 4.8 | Test publish and the `.mjs` build in the ticket that adds each effect. |
| Agents do not know Bend v2 | Everywhere | `AGENTS.md` points to the guide, Base and these decisions. Reviewers check Bend idioms. |

## How the agents build it

An Opus 5.5 orchestrator runs the program from the Linear project, milestone by milestone, taking the next unblocked tickets.

- **Implementers.** GPT-6.1 Sol at medium effort for Bend and TypeScript library work. Opus 5.5 at medium effort for the React examples and the docs site. Each ticket runs in its own git worktree, one writer per checkout.
- **Review.** An independent GPT-6.1 Sol agent reviews every ticket's diff before it lands. Findings get fixed, then reviewed again.
- **Gates.** A ticket lands only when `bun run check` passes, new laws are proven, and the ticket's "How to verify" steps were run with evidence in a Linear comment. UI tickets also need desktop and phone screenshots.
- **Heavy work.** Benchmarks and long fuzz runs go to Boat sandboxes. Tests on ms-a2 stay bounded.
- **Landing.** Branches named after the Linear issue, merged into `main` locally after review, pushed to GitHub. No PRs unless Leo asks for them.
- **Reporting.** The orchestrator posts milestone updates on the Linear project and stops at anything that needs Leo, such as publishing.
