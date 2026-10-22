# Bendo plan

Bendo is a Hono-style web framework for the [Bend](https://bend-lang.com) language, with a TypeScript toolkit that lets a React app call it with full types. The server compiles to one native binary. Its core (parsing, routing, JSON, validation) carries machine-checked proofs in `LAWS.bend`, and the same Bend validation code runs in the browser.

The target is near parity with Hono, borrowing Elysia's best ideas (route-level schemas, lifecycle hooks, end-to-end types), done the Bend way. Features that only make sense on edge runtimes or in browsers are left out. Bend-only features are added on top.

Linear: team **BND**, project [**Bendo v1**](https://linear.app/opencoredev/project/bendo-v1-8d5602229caa). Each milestone below is a Linear milestone, and each numbered item is one ticket.

## Definition of done for v1

The program is done when all of these hold on `main`:

1. Every ticket in the Bendo v1 Linear project is Done, except those marked stretch.
2. `bend PROOF.bend --verdict` prints `ALL PROOFS CHECK`, and every law named in a ticket exists. Each law was reviewed on its own for whether it states the promised guarantee, separately from reviewing its proof.
3. `bun run check` passes: proofs, typecheck, lint, and every integration test against real compiled servers.
4. The todo example runs end to end: a Bend API and a React app, using the typed client and shared validators, checked in a real browser at desktop and phone widths.
5. The benchmark suite has published results against Hono and Elysia on Bun, run on a Boat sandbox.
6. The docs site builds and covers every public API.
7. Publishing to npm and BendHub is ready behind one command each, and waits for Leo's go.

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

1. **The app is a template, and state reaches it as an argument.** `Serve.serve(~app, env, config)` takes the app as compile-time syntax. Handlers are top-level defs. Templates must be closed, so anything created at startup (store channels, config) travels in a runtime `env` argument; `Chan` is `Data`, so every connection gets its own copy. How a route table of many handlers is expressed is the first prototype (0.3).
2. **Parse bytes, not strings.** Bend's `String` is a list of characters, and `Content-Length` counts bytes. The HTTP layer works on `TCP.recv_bytes` and UTF-8 encodes bodies itself, unless the M0 prototype shows a better path.
3. **Pure core, thin IO shell.** Parsing, routing, middleware composition, JSON and validation are pure functions with laws. The accept loop and connection handling are `@unsafe` IO and are covered by integration tests instead of proofs.
4. **One event loop for IO, all cores for compute.** Each connection runs in its own `IO.spawn` computation. Heavy handler work uses Bend's parallel calls, and `!` calls can move it to the GPU.
5. **Shared state lives in an actor.** Bend has no global mutable state. Counters, caches, sessions, rate limits and in-memory stores run as a spawned computation that owns the state and answers over a `Chan`.
6. **Bendo may ship its own effects.** Bend effects are a `.c` file plus a `.js` twin. Bendo adds the ones Base lacks (wall clock, peer address, gzip, SQLite) the same way, and each one lists what it does outside the proofs.
7. **Types flow from Bend to TypeScript.** A compiled app prints a route manifest (`--bendo-routes`) with schemas as JSON Schema. `bendo gen` turns it into TypeScript types for the client. Nobody writes route types twice.
8. **Time comes from two clocks.** `IO.now` is a monotonic tick, right for durations and timeouts. Wall-clock time (the `Date` header, JWT expiry, cookie expiry) comes from Bendo's own effect (1.7).
9. **Timeouts answer, they do not cancel.** `IO.within` does not stop the losing computation, and pure code runs until its next effect. A timeout guarantees the client a response, not that the handler stops.
10. **Laws are human-owned.** Agents may add laws. They never delete or weaken one without a written reason in the commit and a Linear comment.

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
  B.serve(~app, B.env_empty, B.config_defaults)
```

```ts
import { createClient } from "bendo/client";
import type { Routes } from "./.bendo/routes";

const api = createClient<Routes>("http://localhost:8787");
const todo = await api.todos({ id: 42 }).get(); // typed from the Bend schema
```

## Milestones and tickets

Milestones group the work. The dependency graph, recorded as blocked-by relations in Linear, decides the order, so a ticket may start before its whole milestone is done. Tickets marked stretch are not required for v1. Each item shows its plan number and its Linear key; the Linear issue holds the full acceptance criteria and verify steps.

### M0. Foundation

Toolchain, CI gate, and the two design prototypes that shape everything else.

- **0.1 Pin the Bend toolchain and enable the strict proof check** (BND-1). One file pins Bend 2.0.38. Lean is installed through elan at the version Bend asks for. `bend PROOF.bend --verdict` prints `ALL PROOFS CHECK` locally. `AGENTS.md` documents setup from a clean machine.
- **0.2 Make CI the full quality gate** (BND-2). GitHub Actions runs `bend PROOF.bend --verdict`, oxlint with warnings as errors, an oxfmt check, typecheck and integration tests on every push and pull request. `bun run check` runs the same steps locally. Blocked by 0.1.
- **0.3 Choose the route-table shape for template handlers** (BND-3). At least three prototypes compared: a template list of routes, a data route table plus dispatch on a route tag, and a template chain. Each measured for per-request overhead at 5, 50 and 500 routes, and for how the user code reads. The chosen shape is recorded with numbers. The chosen shape also passes a runtime environment (a record holding `Chan`s created at startup) to every handler next to the closed handler templates. Blocked by 0.1.
- **0.4 Choose bytes or strings for HTTP parsing** (BND-4). Both approaches prototyped on a realistic request (headers plus a UTF-8 JSON body plus a binary body), measured for throughput and checked for correctness. The decision is recorded. Blocked by 0.1.
- **0.6 Prototype the typed-value contract from Bend schema to TypeScript** (BND-5). One object schema (for example a todo with title, done and optional due date) carried end to end: a Bend handler receives a typed record, the manifest carries its JSON Schema, generated `.d.ts` declares the TypeScript type, and a browser runtime validator (the Bend decoder compiled to `.mjs`, or a generated validator) rejects bad data. The mechanism is recorded as a decision. Blocked by 0.3.
- **0.5 Build the benchmark harness on Boat sandboxes** (BND-6). `bun bench/run.ts` creates a Boat sandbox, installs Bend, Bun and oha, starts Bendo, Hono on Bun and Elysia on Bun with the same hello-world route (more scenarios join as features land, in 9.1), runs oha against each in turn, writes `bench/results/<date>.json` with hardware and method, and deletes the sandbox even on failure. Blocked by 0.1.

### M1. HTTP core

A correct HTTP/1.1 server under the router.

- **1.1 Parse HTTP requests into a typed request** (BND-7). A pure parser turns raw request bytes into a `Req` with method (standard methods plus extension tokens), target split into path and raw query, HTTP version (1.0 or 1.1), and headers with case-insensitive lookup that keeps repeated headers in order. Malformed input returns a typed error, never a crash. Blocked by 0.4.
- **1.2 Read request bodies with Content-Length and chunked encoding** (BND-8). The connection layer reads a full body by `Content-Length` across many reads, decodes chunked transfer encoding, answers `Expect: 100-continue`, and enforces a configurable body limit with 413. Framing follows a written decision table: conflicting `Content-Length` values, `Transfer-Encoding` together with `Content-Length`, unknown transfer codings, invalid chunk sizes and oversized trailers are rejected with 400 and the connection closed, because these ambiguities enable request smuggling behind a proxy. Blocked by 1.1.
- **1.3 Write HTTP responses with correct lengths and headers** (BND-9). A `Res` model (status, headers, body) and a writer that emits the status line with its reason phrase and headers, following a written framing table by method and status: normal responses carry `Content-Length` equal to the body's UTF-8 byte length; HEAD carries the length the matching GET would send and no body; 1xx (including 101 for WebSocket upgrades) and 204 carry no `Content-Length` and no body; 304 carries no body and a `Content-Length` only when it matches the representation, per RFC 9110. Blocked by 1.1.
- **1.7 Add a wall-clock effect and the HTTP Date header** (BND-10). A Bendo effect returning Unix time in seconds and milliseconds (C file plus JS twin), an IMF-fixdate formatter and parser, and a `Date` header on every response. `IO.now` stays in use for durations and timeouts. Blocked by 1.3.
- **1.4 Keep connections alive and enforce limits and timeouts** (BND-11). Each connection loops over requests with keep-alive, answers pipelined requests in order, closes idle connections after a timeout using `TCP.try_recv`, answers oversized headers with 431 and malformed requests with 400 before closing, and honors `Connection: close` and a max-requests-per-connection setting. Blocked by 1.2, 1.3.
- **1.5 Add the pure handle entrypoint and server config** (BND-12). `B.handle(app, req)` runs an app on a `Req` and returns its `Res` with no network. `B.config` covers host, port (with `$PORT` override), body and header limits, timeouts and keep-alive. Running a compiled app with `--bendo-routes` prints a route manifest envelope as JSON (version, routes with method and path) and exits. Schemas are added to the manifest in 4.7. Blocked by 1.3.
- **1.6 Prove HTTP conformance and fuzz the parser** (BND-13). A conformance suite over raw sockets covering split reads at every byte boundary, pipelining, slow clients, oversized headers, bad request lines and binary bodies, plus a TypeScript fuzz test that sends random and mutated requests and checks the server never crashes or hangs. Fuzzing supplements the deterministic framing tests from 1.2; it does not replace them. Blocked by 1.4.

### M2. Routing

Hono's routing power, with a proof that the fast router is right.

- **2.1 Compile path patterns with params, wildcards and constraints** (BND-14). Patterns support static segments, `:param`, optional `:param?`, `*` and named wildcards, and constraints `{int}`, `{uuid}`, `{slug}` and simple character classes. Params are percent-decoded. Invalid patterns are rejected with a clear error. Blocked by 0.3.
- **2.2 Build the spec router: first match wins** (BND-15). A linear router that tries routes in registration order and returns the first match with its params. It is the reference every faster router must agree with. Blocked by 2.1.
- **2.3 Build the trie router and check it against the spec router** (BND-16). A trie router behind a config flag, checked against the spec router by differential tests on generated route tables and paths. The spec router stays the default until 2.3b lands its proof. Blocked by 2.2.
- **2.3b Prove the trie router equals the spec router** (BND-17). Law in `LAWS.bend`: for every route table and path, the trie router and the spec router return the same match. Once it checks with `--verdict`, the trie becomes the default. Treat this as a research gate: if it stalls after two sessions, write up where it stands, move the issue to Needs Leo, and leave the spec router as the default. Blocked by 2.3.
- **2.4 Handle HTTP methods, HEAD, 404 and 405** (BND-18). `get`, `post`, `put`, `patch`, `delete`, `options`, `head`, `all` and `on(methods, path)`. HEAD is answered from GET without a body. No path match gives 404. A path match with the wrong method gives 405 with an `Allow` header. Strict or lenient trailing slash and case sensitivity are options. Blocked by 2.2.
- **2.5 Compose apps with basePath, mounting and groups** (BND-19). `base_path(prefix)`, mounting a sub-app with `route(prefix, sub)`, Elysia-style `group(prefix, routes)`, `show_routes` printing a method and path table, and the full route manifest from `--bendo-routes`. Blocked by 2.4.
- **2.6 Port Hono's router test cases** (BND-20). Hono's router test cases (MIT licensed) turned into a fixture table, run against both Bendo routers. Cases that differ on purpose are listed with the reason. Blocked by 2.3.

### M3. App, context and middleware

The developer-facing API.

- **3.1 Build the context with request accessors and response helpers** (BND-21). Request accessors `param`, `query`, `queries`, `header`, `method`, `path`, `url`. Response helpers `text`, `json`, `html`, `body`, `redirect`, `not_found`, `status`, `header`. Typed per-request variables with `set` and `get`, like Elysia's `derive` and `decorate`. Blocked by 2.4, 1.5.
- **3.2 Add onion-model middleware** (BND-22). `use(mw)` globally or per path pattern. Middleware gets the context and `next`, may short-circuit, and may change the response after `next` returns. Order is registration order. Blocked by 3.1.
- **3.3 Run Elysia-style lifecycle hooks** (BND-23). `on_request`, `on_parse`, `on_transform`, `before_handle`, `after_handle`, `map_response`, `on_error` and `on_after_response`, registered globally and run in a fixed, documented order. Hooks are built on middleware, not a second system. Blocked by 3.2.
- **3.3b Scope hooks to groups and routes, and add guards** (BND-24). Hooks scoped globally, to a group, or to one route, and `guard` to share hooks and schemas across a set of routes. Blocked by 3.3.
- **3.4 Handle errors without leaking internals or killing the server** (BND-25). An `HttpError` with status and message, `on_error` and `not_found` handlers, error bodies as JSON or text by `Accept`, and no stack traces or internals in responses. Measure what `IO.die` in one handler does to other connections, and contain it if Bend allows. Blocked by 3.2.
- **3.5 Add plugins** (BND-26). A plugin is a function from app to app, applied with `use`. A named plugin applies once even when used twice. A guide shows how to write one. Blocked by 3.3b.
- **3.6 Add the state actor for shared mutable state** (BND-27). `B.Store` spawns a computation that owns a value and answers get, set and update messages over a `Chan`. Handlers reach it through the context. Updates are serialized so concurrent requests never lose a write. Blocked by 3.1.

### M4. Data and validation

JSON, forms, cookies and schemas, with laws.

- **4.1 Parse and write JSON with a roundtrip law** (BND-28). A JSON value type, a parser that terminates by construction (one def with a mode argument and fuel tied to input length), a writer with correct escaping and Unicode escapes, and pretty printing. `req_json` and `json` helpers use it. Blocked by 1.3.
- **4.2 Parse query strings and URL-encoded forms** (BND-29). Percent encoding and decoding, `+` as space in forms, repeated keys kept in order, and `parse_body` for `application/x-www-form-urlencoded`. Blocked by 1.1.
- **4.3 Parse multipart form data** (BND-30). `parse_body` handles `multipart/form-data`: fields and in-memory files with name, filename, content type and bytes, with per-file and total size limits. Blocked by 1.2, 4.2.
- **4.4 Read and write cookies** (BND-31). Parse `Cookie` and write `Set-Cookie` with every attribute (Path, Domain, Max-Age, Expires, Secure, HttpOnly, SameSite, Partitioned). Blocked by 3.1.
- **4.4b Sign and verify cookies** (BND-32). Signed cookies with HMAC-SHA256 and key rotation (verify with any of several keys, sign with the first). Blocked by 4.4, 5.4.
- **4.5 Build the schema language: scalar schemas** (BND-33). Using the mechanism chosen in 0.6: string, number, integer, boolean, literal and enum schemas with min and max, length, simple patterns, and email and URL checks. Decoding returns a typed value or errors. Blocked by 4.1, 0.6.
- **4.5b Build the schema language: objects, arrays, optionals and unions** (BND-34). Object, array, optional, nullable and union schemas composing the scalar ones, decoding into typed values. Blocked by 4.5.
- **4.5c Add coercion, defaults and error paths to schemas** (BND-35). String coercion for params and query, default values, and a list of errors each naming its path. Blocked by 4.5b.
- **4.6 Validate params, query, headers, body and response at the route** (BND-36). Per-route schemas for params, query, headers, body and response. Bad input gets 400 for params and query, 422 for bodies, with the error list as JSON. A response that breaks its schema is a server error in development and logged in production. Blocked by 4.5c, 3.3b.
- **4.7 Export schemas as JSON Schema in the route manifest** (BND-37). Every schema converts to JSON Schema (2020-12). The `--bendo-routes` manifest includes each route's schemas. Blocked by 4.5c, 2.5.
- **4.8 Add a SQLite effect (stretch)** (BND-38). A Bendo effect (C file plus JS twin) wrapping SQLite: open, prepared statements with bound parameters, rows decoded through schemas, and transactions. Blocked by 4.5.

### M5. Built-in middleware

Hono's middleware list, minus what does not fit a native server.

- **5.1 Add logger, request ID, Server-Timing and pretty JSON middleware** (BND-39). A logger (method, path, status, duration), request ID (reuse incoming `X-Request-Id` or generate), `Server-Timing` with named marks, an `X-Powered-By` toggle, and pretty JSON on `?pretty`. Blocked by 3.2.
- **5.2 Add CORS, secure headers, method override and trailing-slash middleware** (BND-40). CORS with preflight handling and per-origin config, Helmet-style secure headers, method override from a form field or header, and trailing-slash redirect or trim. Blocked by 3.2.
- **5.3 Add body limit, timeout, ETag and cache middleware** (BND-41). Per-route body limit, a cooperative request timeout using `IO.within` answering 504. `IO.within` does not cancel the losing computation and pure code runs until its next effect, so the timeout guarantees the client an answer, not that the handler stops. The ticket documents this: a late response from the timed-out handler is discarded, while its store updates and other side effects may still happen. A deadline cannot interrupt uninterrupted pure computation, because the event loop only advances at the next effect. Cancellation is never promised, ETag with `If-None-Match` answered by 304, and `Cache-Control` helpers. Blocked by 3.2, 5.4.
- **5.4 Add crypto and encoding primitives** (BND-42). Base64 and base64url, hex, SHA-1, SHA-256 and HMAC-SHA256 as pure Bend, checked against standard test vectors. Secure random bytes built on Base's `IO.random_u32` (backed by `getrandom` or `arc4random_buf`), with failures propagated, never silently replaced. A C effect for hashing only if a benchmark shows pure Bend is too slow, recorded as a decision. Blocked by 1.3.
- **5.5 Add basic auth, bearer auth, JWT and CSRF middleware** (BND-43). Basic auth with constant-time comparison, bearer auth, JWT sign and verify (HS256) with `exp`, `nbf` and `iat` checks, and CSRF protection by origin check. Blocked by 5.4, 3.2, 1.7.
- **5.6 Add connection info, IP restriction and rate limiting** (BND-44). A Bendo effect returning the peer address (`getpeername`), a `conn_info` accessor, IP allow and deny lists with CIDR ranges, and a rate limiter on `B.Store` (fixed window and token bucket) that sets `RateLimit` headers and answers 429. Blocked by 3.6.
- **5.7 Serve static files safely** (BND-45). `serve_static(root)` with a MIME table, index files, ETag and `Last-Modified`, range requests, and path normalization that can never escape the root. Symlinks are not followed outside the root: confinement is enforced when the file is opened, not only by normalizing the path. Blocked by 3.1, 1.7.
- **5.8 Compress responses with gzip (stretch)** (BND-46). A zlib effect for gzip and deflate, chosen by `Accept-Encoding`, skipped for small or already-compressed types. Blocked by 3.2.
- **5.9 Proxy requests to an upstream** (BND-47). A `proxy(upstream)` helper that forwards method, path, headers and body over `TCP.connect` and streams the answer back, removing hop-by-hop headers. Blocked by 6.1.

### M6. Streaming and realtime

Chunked streaming, SSE and WebSockets.

- **6.1 Stream responses with chunked encoding and backpressure** (BND-48). A `stream` helper that writes chunked responses as the handler produces them, using `TCP.try_send` for backpressure. Blocked by 1.4.
- **6.2 Add Server-Sent Events** (BND-49). `stream_sse` with event, data, id and retry fields, heartbeats, and `Last-Event-ID` passed to the handler. Blocked by 6.1.
- **6.3 Add the WebSocket upgrade handshake** (BND-50). Detect upgrade requests, validate the headers, and answer 101 with `Sec-WebSocket-Accept` computed from SHA-1 and base64. Blocked by 5.4, 1.4.
- **6.3b Encode and decode WebSocket frames** (BND-51). A pure frame codec: masking, 7, 16 and 64-bit lengths, fragmentation, ping, pong and close with codes. Blocked by 6.3.
- **6.3c Run WebSocket connections with open, message and close handlers** (BND-52). An `open`, `message` and `close` handler API per route, automatic pong replies, close handshakes and idle timeouts. Blocked by 6.3b.
- **6.4 Add WebSocket publish and subscribe** (BND-53). Elysia-style `subscribe(topic)`, `unsubscribe` and `publish(topic, msg)` on top of `B.Store`. Blocked by 6.3c, 3.6.

### M7. TypeScript toolkit

CLI, codegen, typed client, shared validators, TanStack Query helpers.

- **7.1 Build the bendo CLI dev loop** (BND-54). `bendo new`, `dev` (watch `.bend` files, rebuild, restart, show compiler errors readably), `build` and `start`. Blocked by 1.5.
- **7.1b Add the bendo routes, prove, gen and doctor commands** (BND-55). `bendo routes` (table from the manifest), `prove` (runs the proof check with readable output), `gen` (entry point for 7.2) and `doctor` (checks Bend, Lean, clang and Bun versions). Blocked by 7.1.
- **7.2 Generate TypeScript route types from the manifest** (BND-56). `bendo gen` runs the app with `--bendo-routes` and writes `.bendo/routes.ts` with params, query, body and response types per route, derived from the JSON Schemas. Blocked by 4.7, 7.1b.
- **7.3 Build the typed client** (BND-57). `createClient<Routes>(baseUrl)` with Eden Treaty-style calls (`api.todos({ id }).get()`), typed success and error results as a discriminated union, and runtime validation of responses. Blocked by 7.2.
- **7.4 Compile shared Bend code to JavaScript with type declarations** (BND-58). `bendo build --shared` compiles `shared/*.bend` to `.mjs` with generated `.d.ts` files that match Bend's JS ABI (constructors as `{$: "Name", ...}`, `Nat` as number). Blocked by 4.5c, 7.1.
- **7.4b Add vite-plugin-bendo for importing .bend files** (BND-59). `vite-plugin-bendo` compiles imported `.bend` files on demand with hot reload. Blocked by 7.4.
- **7.5 Add TanStack Query helpers** (BND-60). `bendo/query` builds typed `queryOptions` and `mutationOptions` from the client, with stable query keys. Blocked by 7.3.
- **7.6 Build create-bendo** (BND-61). `bun create bendo` with an API-only template and a fullstack React template (Vite, TanStack Router and Query, typed client wired up). Blocked by 7.1, 7.5.
- **7.7 Generate OpenAPI and serve API docs** (BND-62). OpenAPI 3.1 generated from the manifest and a `/docs` route serving Scalar. Blocked by 4.7.

### M8. Examples and showcases

Fullstack todo, parallel compute, realtime chat, proofs page.

- **8.1 Build the fullstack todo example** (BND-63). `examples/todo`: a Bend API (CRUD, validation, `B.Store`, CORS) and a React app on Vite, TanStack Router and TanStack Query using the typed client and shared validators. Polished UI. Blocked by 4.6, 3.6, 5.2, 7.4b, 7.5.
- **8.2 Show off parallel and GPU compute in a handler** (BND-64). `examples/mandelbrot`: a route that renders a Mandelbrot image as BMP using Bend's parallel calls, with `?mode=single|cpu|gpu` and timing in a `Server-Timing` header. Blocked by 3.1.
- **8.3 Build a realtime chat example** (BND-65). `examples/chat`: rooms over WebSocket publish and subscribe, and a small React client. Blocked by 6.4.
- **8.4 Explain every law in plain words** (BND-66). A docs page that lists every law with a plain-English statement and what it guarantees for users. Blocked by 2.3, 4.5c.

### M9. Performance

Benchmarks against Hono and Elysia, hot-path work, multi-core.

- **9.1 Run the full benchmark suite against Hono and Elysia** (BND-67). Hello, JSON, params, body echo and a five-middleware stack, Bendo against Hono on Bun and Elysia on Bun, on a Boat sandbox with oha. Results with method and hardware in `bench/results/`. Blocked by 0.5, 4.6, 5.1.
- **9.2 Optimize the hot paths and add a performance budget to CI** (BND-68). Profile-guided work on the parser, header lookup, router and writer, and a CI smoke benchmark that fails on a large regression. Blocked by 9.1.
- **9.3 Use every CPU core for serving** (BND-69). Measure `+RTS --threads` settings and, if it helps, an `SO_REUSEPORT` effect that runs one accept loop per core. Blocked by 9.1.

### M10. Docs and release

Docs site, repo docs, release tooling, launch review.

- **10.1 Set up the docs site with getting started and concepts** (BND-70). A docs site with build and deploy config, getting started, and concept pages (routing, context, middleware, hooks, validation, stores, proofs). Blocked by 7.3, 8.1.
- **10.1b Write the API reference** (BND-71). API reference pages for the Bend library and the TypeScript packages, with a script that fails when a public API has no entry. Blocked by 10.1.
- **10.1c Write guides and migration guides from Hono and Elysia** (BND-72). Task guides modeled on Hono's docs (auth, CORS, uploads, WebSockets, deployment behind Caddy or Cloudflare) and migration guides from Hono and Elysia with side-by-side code. Blocked by 10.1.
- **10.2 Write the README, examples index, CONTRIBUTING and agent guide** (BND-73). README with a quick start, the benchmark chart and the proof story; an examples index; CONTRIBUTING; and an up-to-date `AGENTS.md`. Blocked by 9.1.
- **10.3 Prepare npm and BendHub releases** (BND-74). Changesets for `bendo`, `create-bendo` and `vite-plugin-bendo`; a BendHub publish script with a dry-run mode; a versioning policy. Nothing is published without Leo's go. Blocked by 7.6.
- **10.4 Run the v0.1 launch review** (BND-75). A security review of parsing and middleware, a final fuzz run, `--verdict` on every proof, and a check that every documented API exists. Blocked by 10.1b, 10.1c, 10.3, 1.6.

## Parity with Hono and Elysia

| Feature | Hono | Elysia | Bendo |
|---|---|---|---|
| Routing with params, wildcards, constraints | Yes | Yes | 2.1 |
| Multiple router engines | Yes | No | 2.2 and 2.3, with a proof they agree (2.3b) |
| 405 with `Allow` | No | No | 2.3 |
| Sub-apps, `basePath`, groups | Yes | Yes | 2.4 |
| Context helpers | Yes | Yes | 3.1 |
| Onion middleware | Yes | No | 3.2 |
| Lifecycle hooks | No | Yes | 3.3 |
| Plugins | Partial | Yes | 3.5 |
| Validation | Middleware | Built in | 4.5 to 4.6, with laws |
| JSON, forms, multipart, cookies | Yes | Yes | M4 |
| Built-in middleware | About 25 | Plugins | M5 |
| Streaming, SSE | Yes | Yes | 6.1, 6.2 |
| WebSockets | Per runtime | Yes | 6.3 to 6.4 |
| Typed client | `hc` | Eden | 7.3 |
| OpenAPI | Third party | Plugin | 7.7 |
| Testing without a network | `app.request` | `app.handle` | 1.5 |
| Shared validators in the browser | No | No | 7.4, 7.4b |
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
| Proving the trie router equal to the spec router is very hard | 2.3b | Ship the spec router first; the trie lands only with its proof. |
| Termination rules make the JSON and multipart parsers awkward | M4 | Use fuel tied to input length, as the guide recommends. |
| A handler crash takes down the whole process | 3.4 | Measure early, document, contain if Bend allows. |
| Request smuggling through ambiguous framing | 1.2, 1.4 | A written framing table with a deterministic test per row. |
| A law passes but guarantees less than it claims | Every law | Separate law-statement review, counterexample tests. |
| Timeouts leave handlers running | 5.3 | Document cooperative timeouts; never promise cancellation. |
| Custom C effects break the JS target or hub publishing | 5.4, 5.6, 4.8 | Test publish and the `.mjs` build in the ticket that adds each effect. |
| Agents do not know Bend v2 | Everywhere | `AGENTS.md` points to the guide, Base and these decisions. Reviewers check Bend idioms. |

## How the agents build it

An Opus 5.5 orchestrator runs the program from the Linear project, milestone by milestone, taking the next unblocked tickets.

- **Implementers.** GPT-6.1 Sol at medium effort for Bend and TypeScript library work. Opus 5.5 at medium effort for the React examples and the docs site. Each ticket runs in its own git worktree, one writer per checkout.
- **Review.** An independent GPT-6.1 Sol agent reviews every ticket's diff before it lands. Findings get fixed, then reviewed again. When a ticket adds a law, the review also checks the law itself: does it state the guarantee the ticket promises, over every admissible input, rather than one example or a weaker claim?
- **Ready to start.** A ticket is dispatched only when its acceptance criteria and "How to verify" steps are executable as written. The orchestrator fixes the ticket first if they are not.
- **Gates.** A ticket lands only when `bun run check` passes, new laws are proven, and the ticket's "How to verify" steps were run with evidence in a Linear comment. UI tickets also need desktop and phone screenshots.
- **Heavy work.** Benchmarks and long fuzz runs go to Boat sandboxes. Tests on ms-a2 stay bounded.
- **Landing.** Branches named after the Linear issue, merged into `main` locally after review, pushed to GitHub. No PRs unless Leo asks for them.
- **Reporting.** The orchestrator posts milestone updates on the Linear project and stops at anything that needs Leo, such as publishing.
