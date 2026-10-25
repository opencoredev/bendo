---
title: Migrate from Hono
description: Port a Hono app to Bendo feature by feature, with side-by-side code for routing, middleware, validation, streaming, WebSockets, the typed client and testing.
---

# Migrate from Hono

Bendo borrows most of Hono's vocabulary: the same route patterns, the same
built-in middleware names, an onion of middleware around each handler. The
code looks different because Bend does not have closures you can store in a
table, so a route points at a tag and one function answers every tag. This
page maps each Hono feature to its Bendo form, using one small todo API
written both ways.

The Hono code is the starting point. It is checked against Hono 4.13.13 with
`@hono/zod-validator` and zod 4, but it is not compiled by Bendo's CI. The Bendo
code on this page is checked in CI. Both [complete apps](#the-complete-apps)
are at the end of the page.

## What changes

| Concept | Hono | Bendo |
|---|---|---|
| Handler | A closure passed to `app.get` | A tag such as `ListTodos{}`, answered by one `handle` function |
| Middleware | A closure passed to `app.use` | A tag, answered by one `middleware` function |
| Per-request values | `c.set` and `c.get` | A typed `Vars` record: `C.set` and `C.get` |
| Startup values | Module variables | An `Env` record passed to every handler |
| Mutable state | Module variables | A [store](../store.md), an actor that serializes updates |
| Runtime | Bun, Node, Deno, Workers | A native binary behind a reverse proxy |

A Bendo app is a route list, a handler and a middleware dispatcher:

```bend
case Done{table}: V.serve_with(~Vars, ~Tag, ~Env, ~handler, ~middleware, table, env, with_router(B.config(), B.trie()))
```

## Coverage

Every row of Bendo's parity table, with the section that covers it:

| Feature | Hono | Section |
|---|---|---|
| Routing with params, wildcards, constraints | Yes | [Routes, params and wildcards](#routes-params-and-wildcards) |
| Multiple router engines | Yes | [Router engines](#router-engines) |
| 405 with `Allow` | No | [Method not allowed](#method-not-allowed) |
| Sub-apps, `basePath`, groups | Yes | [Sub-apps, base paths and groups](#sub-apps-base-paths-and-groups) |
| Context helpers | Yes | [Requests and responses](#requests-and-responses) |
| Onion middleware | Yes | [Middleware](#middleware) |
| Lifecycle hooks | No | [Lifecycle hooks](#lifecycle-hooks) |
| Plugins | Partial | [Plugins](#plugins) |
| Validation | Middleware | [Validation](#validation) |
| JSON, forms, multipart, cookies | Yes | [JSON, forms and cookies](#json-forms-and-cookies) |
| Built-in middleware | About 25 | [Built-in middleware](#built-in-middleware) |
| Streaming, SSE | Yes | [Streaming and Server-Sent Events](#streaming-and-server-sent-events) |
| WebSockets | Per runtime | [WebSockets](#websockets) |
| Typed client | `hc` | [Typed client](#typed-client) |
| OpenAPI | Third party | [OpenAPI](#openapi) |
| Testing without a network | `app.request` | [Testing without a network](#testing-without-a-network) |
| Shared validators in the browser | No | [Shared validators](#shared-validators) |
| Proven core | No | [Proofs](#proofs) |
| Parallel and GPU handlers | No | [Parallel and GPU handlers](#parallel-and-gpu-handlers) |
| Runs on edge runtimes | Yes | [Edge runtimes](#edge-runtimes) |
| JSX rendering | Yes | [JSX](#jsx) |
| TLS, HTTP/2 | Via runtime | [TLS and HTTP versions](#tls-and-http-versions) |

## Routes, params and wildcards

Patterns use Hono's syntax, with two changes: a wildcard can have a name, and
`{int}` is a built-in constraint. Bendo also accepts Hono's character classes,
such as `{[0-9]+}`.

::: code-group

```ts [Hono]
.get("/todos/:id{[0-9]+}", (c) => {
```

```bend [Bendo]
B.get(Tag, "/todos/:id{int}", GetTodo{}),
```

:::

::: code-group

```ts [Hono]
app.get("/files/:path{.+}", (c) => c.text(`file ${c.req.param("path")}`));
```

```bend [Bendo]
B.get(Tag, "/files/*path", File{}),
```

:::

The handler reads the capture by name:

```bend
case File{} _: IO.pure(B.Res, C.text(Vars, c, "file " ++ text_or(C.param(Vars, c, "path"), "")))
```

Optional segments (`/:id?`), `{uuid}`, `{slug}` and multi-segment spans
(`/:prefix{.+}/contents`) work too; [route patterns](../router-patterns.md)
lists them. Two rules differ from Hono:

- The first registered route that matches wins, and only its handler runs.
  Hono can run several matching handlers in a row. Put specific routes first.
- A span such as `{.+}` must be followed by a static segment. Use `*path` for
  "the rest of the path".

[Decision 0008](../decisions/0008-router-differences.md) records every
difference, checked against Hono's own router tests.

## Router engines

Hono picks among `RegExpRouter`, `TrieRouter` and others. Bendo has two: the
spec router, a plain first-match list that defines the behavior, and the trie
router, which is the default and is proven to return the same result for
every table and path.

::: code-group

```ts [Hono]
const app = new Hono<Env>({ router: new RegExpRouter() });
```

```bend [Bendo]
def with_router(config: Config.Config, kind: B.RouterKind) -> Config.Config:
  Config.Config{host, port, limit, headers, idle, head, body, max, keep, old, mode, workers} = config
  Config.Config{host, port, limit, headers, idle, head, body, max, keep, kind, mode, workers}
```

:::

Pass `B.trie()` or `B.spec()`. There is no reason to pick the spec router in
production; the choice exists so the [proofs](../router-trie.md#equivalence-proof)
have something to compare.

## Method not allowed

Hono answers 404 when a path exists but not for the request's method. Bendo
answers `405 Method Not Allowed` with an `Allow` header listing the methods
that do exist, adding `HEAD` wherever `GET` exists. You write nothing:

::: code-group

```ts [Hono]
api.all("/todos", (c) => c.text("Method Not Allowed", 405, { Allow: "GET, POST" }));
```

```bend [Bendo]
[B.get(Tag, "/todos", ListTodos{}),
B.with_schemas(Tag, B.post(Tag, "/todos", CreateTodo{}), B.schemas([B.body_schema(todo_input())])),
```

:::

`PUT /api/todos` gets `405` with `allow: GET, HEAD, POST`. A `HEAD` request
runs the `GET` handler and drops the body.

## Sub-apps, base paths and groups

`app.route(prefix, subApp)` becomes `B.route(Tag, prefix, entries)`: a route
list is plain data, so a sub-app is a function that returns one.
`B.base_path` is the same operation under Hono's other name. `B.group` adds a
prefix and hooks that apply only inside it.

::: code-group

```ts [Hono]
app.route("/api", api);
app.route("/admin", admin);
```

```bend [Bendo]
B.route(Tag, "/api", api()),
admin()])
```

:::

::: code-group

```ts [Hono]
const admin = new Hono();
admin.use(basicAuth({ username: "admin", password: "change me" }));
admin.get("/stats", (c) => c.json({ admin: true }));
```

```bend [Bendo]
def admin() -> List<&2, B.Registration(Tag)>:
  B.group(Tag, "/admin", [B.hook(Tag, Table.BeforeHandle{}, Builtin{B.basic_auth("admin", [B.credential("admin", "change me")])})], [
    B.get(Tag, "/stats", Stats{})])
```

:::

Middleware registered inside a mounted list applies under its prefix, as in
Hono. [Compose route lists](../router-compose.md) covers the rules.

## Requests and responses

Every Hono context helper has a function in `src/app/context.bend`, imported
as `C`. Each takes the `Vars` type first, and setters return a new context
instead of changing it.

| Hono | Bendo |
|---|---|
| `c.req.param("id")` | `C.param(Vars, c, "id")` |
| `c.req.query("name")`, `c.req.queries("tag")` | `C.query(Vars, c, "name")`, `C.queries(Vars, c, "tag")` |
| `c.req.header("x-user")` | `C.request_header(Vars, c, "x-user")` |
| `c.req.method`, `c.req.path` | `C.method(Vars, c)`, `C.path(Vars, c)` |
| `await c.req.arrayBuffer()` | `C.raw_body(Vars, c)` |
| `c.text`, `c.html`, `c.json`, `c.body` | `C.text`, `C.html`, `C.json`, `C.body` |
| `c.status(201)`, `c.header(name, value)` | `C.status(Vars, c, 201)`, `C.header(Vars, c, name, value)` |
| `c.redirect(url)`, `c.notFound()` | `C.redirect(Vars, c, url)`, `C.not_found(Vars, c)` |
| `c.set(key, value)`, `c.get(key)` | `C.set(Vars, c, record)`, `C.get(Vars, c)` |

::: code-group

```ts [Hono]
app.get("/hello", (c) => c.text(`Hello, ${c.req.query("name") ?? "world"} from ${c.get("user")}`));
```

```bend [Bendo]
case Hello{} _: IO.pure(B.Res, C.text(Vars, c, "Hello, " ++ text_or(C.query(Vars, c, "name"), "world") ++ " from " ++ user_of(C.get(Vars, c))))
```

:::

A lookup returns a `Maybe`, so a missing value is handled where it is read.
Apps that need no `Vars` can use the shorter `B.param(c, name)` family on
`B.Ctx`.

## Middleware

A Hono middleware is a closure around `next`. A Bendo middleware is a tag in
the route list, and one dispatcher runs every tag with the same `next`:

::: code-group

```ts [Hono]
app.use(async (c, next) => {
  c.set("user", c.req.header("x-user") ?? "guest");
  await next();
});
```

```bend [Bendo]
def who(+c: B.Context(Vars), next: B.Context(Vars) -> IO(B.Res)) -> IO(B.Res):
  next(C.set(Vars, c, Vars{text_or(C.request_header(Vars, c, "x-user"), "guest")}))
```

:::

```bend
B.use(Tag, Who{}),
```

```bend
case Who{}: who(c, next)
```

`B.use_path(Tag, "/api/*", tag)` scopes a middleware to a path, like
`app.use("/api/*", ...)`. The first one registered is the outermost layer.
To change the response, call `next` inside a `do` block and transform the
`B.Res` it returns. `next` can be called at most once, which Bend checks at
compile time.

## Lifecycle hooks

Hono has no hooks. Bendo adds Elysia's lifecycle stages: `B.on_request`,
`B.on_parse`, `B.on_transform`, `B.before_handle`, `B.after_handle`,
`B.map_response`, `B.on_error` and `B.on_after_response`. A hook is a
middleware tag registered for a stage, so the same dispatcher runs it, and its
stage decides when it runs, wherever it sits in the list:

```bend
B.before_handle(Tag, Stamp{}),
```

```bend
case Stamp{}: next(C.header(Vars, c, "x-app", "todos"))
```

In Hono you would write this as one more middleware. Hooks matter when order
does: `before_handle` runs after validation, so it sees decoded values, and
`on_request` runs before routing, so it can rewrite the path. See
[hooks](../concepts/hooks.md).

## Plugins

Hono shares functionality as middleware factories and sub-apps. Bendo has
those, plus named plugins: a function from builder to builder that applies
once however many times it is used, like an Elysia plugin with a `name`.

::: code-group

```ts [Hono]
const health = new Hono().get("/healthz", (c) => c.text("ok"));
```

```bend [Bendo]
def health(app: B.Builder(Tag)) -> B.Builder(Tag):
  B.named(Tag, B.plugin_id("health"), app, a => B.register(Tag, a, [B.get(Tag, "/healthz", Health{})]))
```

:::

```bend
health(B.app_from(Tag, entries()))
```

[Write a plugin](plugins.md) covers scopes and seeds.

## Validation

Hono validates through middleware such as `zValidator`. In Bendo a route
declares schemas for its params, query, headers, body and response. A request
that fails never reaches the handler: it gets 400 for bad params, query or
headers and 422 for a bad body, with every failing path listed. A request that
passes reaches the handler with the decoded values:

::: code-group

```ts [Hono]
const todoInput = z.object({
  title: z.string().min(1).max(80),
  done: z.boolean().default(false),
});
```

```bend [Bendo]
def todo_input() -> S.Schema:
  S.ObjectSchema{[
    S.Field{"title", S.StringSchema{1n, Some{80n}, None{}, S.Plain{}}, S.Required{}},
    S.Field{"done", S.BooleanSchema{}, S.Default{Json.JBool{False{}}}}], S.Strict{}}
```

:::

::: code-group

```ts [Hono]
.post("/todos", zValidator("json", todoInput), (c) => {
  const { title, done } = c.req.valid("json");
```

```bend [Bendo]
B.with_schemas(Tag, B.post(Tag, "/todos", CreateTodo{}), B.schemas([B.body_schema(todo_input())])),
```

:::

```bend
+body = B.valid_body_in(Vars, c)
+title = string_field(B.field(body, "title"))
+done = bool_field(B.field(body, "done"))
```

Serve an app that declares schemas with `V.serve_with` from
`src/validated.bend`; `B.serve_with` refuses to start, so a schema is never
silently ignored. `B.guard` attaches schemas to several routes at once. See
[validation](../concepts/validation.md) and the [schema reference](../data/schema.md).

## JSON, forms and cookies

::: code-group

```ts [Hono]
app.post("/theme", (c) => {
  setCookie(c, "theme", c.req.query("theme") ?? "light");
  return c.text("theme saved");
});
```

```bend [Bendo]
def theme(+c: B.Context(Vars)) -> B.Res:
  themed(c, C.set_cookie(Vars, c, "theme", text_or(C.query(Vars, c, "theme"), "light"), Cookie.defaults()))
```

:::

`C.set_cookie` returns a `Result`, because a name or value can be invalid;
match on it before you answer. `C.cookie(Vars, c, name)` reads one, and
`C.set_signed_cookie` and `C.signed_cookie` follow Hono's signed-cookie format,
so cookies signed by either side verify on the other.

| Hono | Bendo |
|---|---|
| `await c.req.json()` | `Json.parse(C.raw_body(Vars, c))`, or a body schema |
| `await c.req.parseBody()` | `Form.parse_body(content_type, C.raw_body(Vars, c))` for URL-encoded and multipart forms |
| `getCookie`, `setCookie`, `deleteCookie` | `C.cookie`, `C.set_cookie`, `C.delete_cookie` |
| `getSignedCookie`, `setSignedCookie` | `C.signed_cookie`, `C.set_signed_cookie` |

The [uploads guide](uploads.md) parses files, and the [auth guide](auth.md)
signs session cookies.

## Built-in middleware

Most of Hono's middleware ships with Bendo under the same name. Wrap each in
one `Builtin{id: B.Builtin}` case of your middleware tag and dispatch it with
`B.builtin`:

::: code-group

```ts [Hono]
app.use(logger());
app.use(secureHeaders());
```

```bend [Bendo]
[B.use(Tag, Builtin{B.logger()}),
B.use(Tag, Builtin{B.secure_headers()}),
```

:::

```bend
case Builtin{id}: B.builtin(Vars, id, c, next)
```

| Hono | Bendo |
|---|---|
| `basicAuth`, `bearerAuth`, `jwt`, `csrf` | `B.basic_auth`, `B.bearer_auth`, `B.jwt`, `B.csrf` ([auth](../auth.md)) |
| `cors`, `secureHeaders`, `methodOverride` | `B.cors`, `B.secure_headers`, `B.method_override` ([web headers](../web-middleware.md)) |
| `trimTrailingSlash`, `appendTrailingSlash` | `B.trim_trailing_slash`, `B.append_trailing_slash` |
| `logger`, `requestId`, `timing`, `poweredBy`, `prettyJSON` | `B.logger`, `B.request_id`, `B.server_timing`, `B.powered_by`, `B.pretty_json` ([observability](../observability.md)) |
| `bodyLimit`, `timeout`, `etag` | `B.body_limit`, `B.timeout`, `B.etag` ([limits](../limits-cache.md)) |
| `cache` | `B.cache_control`, which sets `Cache-Control` only; there is no response cache |
| `ipRestriction`, `getConnInfo` | `B.ip_restriction`, `B.conn_info` ([connection info](../connection.md)) |
| `serveStatic` | `B.serve_static` ([static files](../static.md)) |
| `proxy` helper | `B.proxy` ([proxy](../proxy.md)) |
| Rate limiting (third party) | `B.rate_limit` |
| `compress` | None. Let the proxy compress, as in the [deployment guide](deploy.md#put-caddy-in-front) |
| `jsxRenderer`, `languageDetector`, `contextStorage` | None |

## Streaming and Server-Sent Events

`streamSSE` takes an async callback. Bendo's `B.stream_sse` pulls from a
producer instead: a function from state to the next step, which says whether
to send a frame, wait, or end. Backpressure and the write deadline come for
free.

::: code-group

```ts [Hono]
.get("/events", (c) =>
  streamSSE(c, async (stream) => {
    for (let left = 4; left >= 0; left--) {
      await stream.sleep(1000);
      await stream.writeSSE({ data: `tick ${left}` });
    }
  }),
);
```

```bend [Bendo]
def send(+left: Nat) -> IO(E.Step<Nat>):
  do IO<E.Step<Nat>>:
    IO.sleep(1000)
    return E.Send{B.sse_data("tick " ++ Nat.show(left)), left}

def tick(n: Nat) -> IO(E.Step<Nat>):
  match n:
    case 0n: IO.pure(E.Step<Nat>, E.End{0n})
    case 1n+left: send(left)
```

:::

```bend
case Events{} _: B.stream_sse(~Vars, ~Nat, ~tick, ~stopped, c, 5n, B.sse_config())
```

`B.stream` is the same for raw bytes, like Hono's `stream`. See
[Server-Sent Events](../sse.md) and [streaming](../streaming.md).

## WebSockets

Hono's `upgradeWebSocket` comes from a runtime adapter. Bendo's handlers work
the same everywhere it runs, with per-connection state instead of closures:

::: code-group

```ts [Hono]
app.get(
  "/ws",
  upgradeWebSocket(() => ({
    onMessage(event, ws) {
      ws.send(String(event.data));
    },
  })),
);
```

```bend [Bendo]
def echoed(state: Unit, socket: B.WebSocketHandle, message: M.Message) -> IO(Unit):
  match message:
    case M.TextMessage{text}:
      do IO<Unit>:
        sent : Bool <- B.websocket_send_text(socket, text)
        return state
    case _: IO.pure(Unit, state)
```

:::

```bend
case Socket{} _: B.websocket_handlers(~Vars, ~Unit, ~opened, ~echoed, ~closed, c, Unit{}, B.websocket_config(), B.websocket_session_config())
```

Bendo also has rooms, which Hono leaves to the runtime: see the
[WebSocket guide](websockets.md#put-connections-in-rooms).

## Typed client

`hc<AppType>` reads types from the server's TypeScript. A Bendo server is not
TypeScript, so `bendo gen` asks the compiled app for its routes and schemas and
writes `.bendo/routes.ts`. `createClient` reads that:

::: code-group

```ts [Hono · client.ts]
import { hc } from "hono/client";
import type { AppType } from "./server";

const api = hc<AppType>("http://localhost:8787/api");

const res = await api.todos.$post({ json: { title: "Write docs" } });
if (res.status === 201) {
  const todo = await res.json();
  console.log(todo.title);
}
```

```ts [Bendo]
import { createClient } from "bendo/client";
import type { Routes } from "./.bendo/routes";
import { schemas } from "./.bendo/routes.schemas";

const api = createClient<Routes>("http://localhost:8787", { schemas });

const created = await api.api.todos.post({ body: { title: "Write docs" } });
if (created.ok && created.kind === "data") console.log(created.data.title);
```

:::

The Bendo snippet uses the routes generated for the
[todo example](../examples.md#todo), which declare response schemas; a route
without one returns `unknown` data. Calls never throw: every result is a
value with `ok` and a `kind`. See [typed client](../client.md).

## OpenAPI

`@hono/zod-openapi` replaces your routes with OpenAPI route objects. Bendo
derives the document from the routes and schemas you already have:

::: code-group

```ts [Hono · openapi.ts]
import { OpenAPIHono, createRoute, z } from "@hono/zod-openapi";

const getTodo = createRoute({
  method: "get",
  path: "/todos/{id}",
  request: { params: z.object({ id: z.coerce.number().int().min(1) }) },
  responses: {
    200: {
      description: "One todo",
      content: { "application/json": { schema: z.object({ id: z.number(), title: z.string() }) } },
    },
  },
});

const app = new OpenAPIHono();
app.openapi(getTodo, (c) => c.json({ id: c.req.valid("param").id, title: "Write docs" }, 200));
app.doc("/openapi.json", { openapi: "3.1.0", info: { title: "Todos", version: "1.0.0" } });
```

```sh [Bendo]
bendo openapi main.bend --bend openapi-doc.bend
bendo build
```

:::

`bendo openapi` writes an OpenAPI 3.1 document, and `--bend` embeds it in a
module the app serves along with a Scalar reference page:

<!-- source: tests/fixtures/openapi/app.bend -->
```bend
def spec(c: B.Ctx) -> IO(B.Res):
  IO.pure(B.Res, Docs.openapi(c, OpenApiDoc.json()))
```

See [OpenAPI and API docs](../openapi.md).

## Testing without a network

`app.request` becomes `B.handle`, which runs the app on a request value and
returns the response without opening a socket:

::: code-group

```ts [Hono · server.test.ts]
import { expect, test } from "bun:test";
import { Hono } from "hono";

const app = new Hono().get("/", (c) => c.text("Hello from Hono!"));

test("GET / answers 200", async () => {
  const res = await app.request("/");
  expect(res.status).toBe(200);
  expect(await res.text()).toBe("Hello from Hono!");
});
```

```bend [Bendo]
import Base
import ./bendo/main.bend as B
import ./bendo/data/utf8.bend as Utf8
import ./bendo/http/request.bend as Request
import ./bendo/http/response.bend as Response

type Tag is Data:
  Hello{}

def dispatch(tag: Tag, c: B.Ctx, env: Unit) -> IO(B.Res):
  IO.pure(B.Res, B.text(c, "Hello from Bendo!"))

def get(path: String) -> B.Req:
  Request.Req{Request.Get{}, path, None{}, Request.Http11{}, []}

def answered(res: B.Res, status: U32, text: String) -> Bool:
  Response.Res{code, headers, body, representation} = res
  Bool.and(U32.is_eq(code, status), String.eq(Maybe.default(&2, String, Utf8.decode(body), ""), text))

def expect(ok: Bool, name: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ name)
    case False{}: IO.die(Unit, 1, "FAIL " ++ name)

def check(result: Result<&2, &2, B.RouteError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "invalid routes")
    case Done{+table}:
      do IO<Unit>:
        home : B.Res <- B.handle(~Tag, ~Unit, ~dispatch, table, Unit{}, get("/"), [])
        expect(answered(home, 200, "Hello from Bendo!"), "GET / answers 200")
        missing : B.Res <- B.handle(~Tag, ~Unit, ~dispatch, table, Unit{}, get("/nope"), [])
        expect(answered(missing, 404, "Not Found"), "GET /nope answers 404")

def main() -> IO(Unit):
  check(B.routes(Tag, [B.get(Tag, "/", Hello{})]))
```

:::

Build it with `bend test.bend -o test` and run `./test`; it prints a `PASS`
line per check and exits 1 on the first failure. Use `B.handle_with` for an
app with middleware. For full HTTP behavior, Bendo's own tests compile the
server and call it with `fetch` from `bun test`.

## Shared validators

A zod schema is TypeScript, so a browser can import the same file as a Hono
server. Bendo gets the same result the other way round: `bendo build --shared`
compiles the server's Bend schema module to JavaScript with type declarations,
and the browser imports that.

::: code-group

```ts [Hono · shared.ts]
import { z } from "zod";

// Imported by the server's zValidator and by the browser's form.
export const todoInput = z.object({
  title: z.string().min(1).max(80),
  done: z.boolean().default(false),
});

const checked = todoInput.safeParse({ title: "" });
if (!checked.success) console.log(checked.error.issues);
```

<!-- source: packages/bendo/shared/fixtures/signup/web/src/App.tsx -->
```ts [Bendo]
import {
  check,
  reply_text,
  type Checked,
  type Issue,
  type List,
} from "../../dist/shared/signup.mjs";
```

:::

The browser then runs exactly the decoder the server runs, so the two can
never disagree. See [share Bend code with JavaScript](../shared.md).

## Proofs

Hono is tested; Bendo's core is also proven. Parsing, routing, middleware
order, JSON, cookies and validation are pure Bend functions with laws in
`LAWS.bend`, and the build fails if a proof stops checking:

```sh
bun run prove   # ALL PROOFS CHECK
```

There is nothing to port. [Proofs](../concepts/proofs.md) explains what the
laws cover, and the [laws in plain words](../laws/README.md) lists them.

## Parallel and GPU handlers

JavaScript handlers run on one thread. A Bend handler can split pure work
across every core, and a `!` call hands it to the GPU when one is present:

<!-- source: examples/mandelbrot/render.bend -->
```bend
def rows_gpu(+w: U32, +h: U32, +iter: U32) -> List<&2, List<&2, U32>>:
  rows_fork!(rows_depth(h), 0, 1, w, h, iter)
```

The [Mandelbrot example](../examples.md#mandelbrot) renders the same image on
one core, all cores or the GPU. For more requests per second, run several
[workers](../workers.md).

## Edge runtimes

Hono runs on Cloudflare Workers, Deno and Lambda. Bendo compiles to a native
binary only. To serve from Cloudflare's edge, run the binary on a server and
put Cloudflare in front, as the [deployment guide](deploy.md#put-cloudflare-in-front)
shows.

::: code-group

```ts [Hono · worker.ts]
import { Hono } from "hono";

const app = new Hono().get("/", (c) => c.text("Hello from the edge"));

export default app;
```

```sh [Bendo]
bendo build
scp dist/server deploy@server.example:/opt/myapp/server
```

:::

## JSX

Bendo has no server-side JSX. Return HTML strings with `C.html`, or build the
interface in React and call the API with the typed client, as the
[todo example](../examples.md#todo) does.

::: code-group

```tsx [Hono · page.tsx]
/** @jsxImportSource hono/jsx */
import { Hono } from "hono";

const app = new Hono();
app.get("/", (c) => c.html(<h1>Todos</h1>));
```

```bend [Bendo]
case Home{} _: IO.pure(B.Res, C.html(Vars, c, "<h1>Todos</h1>"))
```

:::

`C.html` does not escape anything. Escape user input yourself before putting
it in a page.

## TLS and HTTP versions

Hono gets TLS and HTTP/2 from its runtime. Bendo speaks HTTP/1.1 without TLS
and leaves both to a reverse proxy, which also handles certificates:

::: code-group

```ts [Hono · tls.ts]
import { Hono } from "hono";

const app = new Hono().get("/", (c) => c.text("Hello over TLS"));

Bun.serve({
  port: 443,
  fetch: app.fetch,
  tls: { cert: Bun.file("cert.pem"), key: Bun.file("key.pem") },
});
```

```text [Bendo · Caddyfile]
api.example.com {
	reverse_proxy 127.0.0.1:8787
}
```

:::

See [deploy behind Caddy or Cloudflare](deploy.md).

## Move traffic over

You do not have to port everything at once. Run the Bendo app next to the
Hono app and let the proxy send it one path at a time:

```text
api.example.com {
	handle /api/todos* {
		reverse_proxy 127.0.0.1:8787
	}
	handle {
		reverse_proxy 127.0.0.1:3000
	}
}
```

1. Port one group of routes and its middleware, and run both apps.
2. Route that path to Bendo in the proxy. Compare status codes and bodies,
   especially 404 against 405 and the shape of validation errors, which differ
   from zod's.
3. Repeat for the next group. To roll back, remove the `handle` block and
   reload the proxy; the Hono app never stopped.

Shared state has to live outside both processes while they run side by side,
since a Bendo [store](../store.md) is in memory.

## The complete apps

::: details Hono: server.ts
```ts [Hono · server.ts]
import { Hono } from "hono";
import { basicAuth } from "hono/basic-auth";
import { upgradeWebSocket, websocket } from "hono/bun";
import { setCookie } from "hono/cookie";
import { logger } from "hono/logger";
import { RegExpRouter } from "hono/router/reg-exp-router";
import { secureHeaders } from "hono/secure-headers";
import { streamSSE } from "hono/streaming";
import { zValidator } from "@hono/zod-validator";
import { z } from "zod";

type Todo = { id: number; title: string; done: boolean };
type Env = { Variables: { user: string } };

const todos: Todo[] = [];
let nextId = 1;

const todoInput = z.object({
  title: z.string().min(1).max(80),
  done: z.boolean().default(false),
});

const api = new Hono<Env>()
  .get("/todos", (c) => c.json(todos))
  .get("/todos/:id{[0-9]+}", (c) => {
    const todo = todos.find((t) => t.id === Number(c.req.param("id")));
    return todo ? c.json(todo) : c.notFound();
  })
  .post("/todos", zValidator("json", todoInput), (c) => {
    const { title, done } = c.req.valid("json");
    const todo = { id: nextId++, title, done };
    todos.unshift(todo);
    return c.json(todo, 201);
  })
  .delete("/todos/:id{[0-9]+}", (c) => {
    const at = todos.findIndex((t) => t.id === Number(c.req.param("id")));
    if (at >= 0) todos.splice(at, 1);
    return c.body(null, 204);
  })
  .get("/events", (c) =>
    streamSSE(c, async (stream) => {
      for (let left = 4; left >= 0; left--) {
        await stream.sleep(1000);
        await stream.writeSSE({ data: `tick ${left}` });
      }
    }),
  );

// Hono answers 404 for a known path with the wrong method.
api.all("/todos", (c) => c.text("Method Not Allowed", 405, { Allow: "GET, POST" }));

const admin = new Hono();
admin.use(basicAuth({ username: "admin", password: "change me" }));
admin.get("/stats", (c) => c.json({ admin: true }));

const health = new Hono().get("/healthz", (c) => c.text("ok"));

const app = new Hono<Env>({ router: new RegExpRouter() });
app.use(logger());
app.use(secureHeaders());
app.use(async (c, next) => {
  c.set("user", c.req.header("x-user") ?? "guest");
  await next();
});
app.use(async (c, next) => {
  c.header("x-app", "todos");
  await next();
});
app.get("/", (c) => c.html("<h1>Todos</h1>"));
app.get("/hello", (c) => c.text(`Hello, ${c.req.query("name") ?? "world"} from ${c.get("user")}`));
app.get("/files/:path{.+}", (c) => c.text(`file ${c.req.param("path")}`));
app.post("/theme", (c) => {
  setCookie(c, "theme", c.req.query("theme") ?? "light");
  return c.text("theme saved");
});
app.get(
  "/ws",
  upgradeWebSocket(() => ({
    onMessage(event, ws) {
      ws.send(String(event.data));
    },
  })),
);
app.route("/api", api);
app.route("/admin", admin);
app.route("/", health);

export type AppType = typeof api;
export default { port: 8787, fetch: app.fetch, websocket };
```
:::

::: details Bendo: main.bend
<!-- #region todo-app -->
```bend
import Base
import ./bendo/main.bend as B
import ./bendo/validated.bend as V
import ./bendo/app/config.bend as Config
import ./bendo/app/context.bend as C
import ./bendo/app/store.bend as Store
import ./bendo/app/table.bend as Table
import ./bendo/data/cookie.bend as Cookie
import ./bendo/data/json.bend as Json
import ./bendo/data/schema.bend as S
import ./bendo/http/sse_types.bend as E
import ./bendo/ws/message.bend as M

# Per-request variables, like Hono's c.set or Elysia's derive.
type Vars is Data:
  Vars{user: String}

type Todo is Data:
  Todo{id: Nat, title: String, done: Bool}

type Todos is Data:
  Todos{next: Nat, items: List<&2, Todo>}

# Startup state, like Elysia's decorate and state.
type Env is Data:
  Env{todos: B.Store(Todos)}

type Tag is Data:
  Home{}
  Hello{}
  ListTodos{}
  GetTodo{}
  CreateTodo{}
  DeleteTodo{}
  File{}
  Events{}
  Socket{}
  Theme{}
  Stats{}
  Health{}
  Who{}
  Stamp{}
  Builtin{id: B.Builtin}

# --- JSON ---

def todo_json(todo: Todo) -> Json.Json:
  Todo{id, title, done} = todo
  Json.JObject{[
    Json.Field{"id", Json.JNumber{Nat.show(id)}},
    Json.Field{"title", Json.JString{title}},
    Json.Field{"done", Json.JBool{done}}]}

def todos_json(items: List<&2, Todo>) -> List<&2, Json.Json>:
  match items:
    case Nil{}: []
    case todo <> rest: todo_json(todo) <> todos_json(rest)

# --- Schemas ---

def todo_input() -> S.Schema:
  S.ObjectSchema{[
    S.Field{"title", S.StringSchema{1n, Some{80n}, None{}, S.Plain{}}, S.Required{}},
    S.Field{"done", S.BooleanSchema{}, S.Default{Json.JBool{False{}}}}], S.Strict{}}

def todo_id() -> S.Schema:
  S.ObjectSchema{[S.Field{"id", S.IntegerSchema{Some{"1"}, None{}}, S.Required{}}], S.Strict{}}

# --- Store updates ---

def added(todos: Todos, title: String, done: Bool) -> Todos:
  Todos{+next, items} = todos
  Todos{(next + 1n : Nat), Todo{next, title, done} <> items}

def kept(drop: Bool, todo: Todo, rest: List<&2, Todo>) -> List<&2, Todo>:
  match drop:
    case True{}: rest
    case False{}: todo <> rest

def without(items: List<&2, Todo>, +id: String) -> List<&2, Todo>:
  match items:
    case Nil{}: []
    case Todo{+n, title, done} <> rest: kept(String.eq(Nat.show(n), id), Todo{n, title, done}, without(rest, id))

def removed(todos: Todos, +id: String) -> Todos:
  Todos{next, items} = todos
  Todos{next, without(items, id)}

def find(items: List<&2, Todo>, +id: String) -> Maybe<&2, Todo>:
  match items:
    case Nil{}: None{}
    case Todo{+n, title, done} <> rest: Bool.pick(Maybe<&2, Todo>, String.eq(Nat.show(n), id), Some{Todo{n, title, done}}, find(rest, id))

# --- Values from the request ---

def text_or(value: Maybe<&2, String>, fallback: String) -> String:
  match value:
    case Some{s}: s
    case None{}: fallback

def string_field(value: Maybe<&2, S.Value>) -> String:
  match value:
    case Some{S.VString{s}}: s
    case _: ""

def bool_field(value: Maybe<&2, S.Value>) -> Bool:
  match value:
    case Some{S.VBool{b}}: b
    case _: False{}

def id_param(value: Maybe<&2, S.Value>) -> String:
  match value:
    case Some{S.VInteger{digits}}: digits
    case _: ""

def user_of(vars: Maybe<&2, Vars>) -> String:
  match vars:
    case Some{Vars{user}}: user
    case None{}: "guest"

# --- Handlers ---

def listed(+c: B.Context(Vars), got: Result<&2, &2, Store.Error, Todos>) -> B.Res:
  match got:
    case Fail{e}: C.error(Vars, c, B.http_error(503, "store unavailable"))
    case Done{Todos{next, items}}: C.json(Vars, c, Json.JArray{todos_json(items)})

def found(+c: B.Context(Vars), todo: Maybe<&2, Todo>) -> B.Res:
  match todo:
    case None{}: C.not_found(Vars, c)
    case Some{t}: C.json(Vars, c, todo_json(t))

def fetched(+c: B.Context(Vars), got: Result<&2, &2, Store.Error, Todos>, +id: String) -> B.Res:
  match got:
    case Fail{e}: C.error(Vars, c, B.http_error(503, "store unavailable"))
    case Done{Todos{next, items}}: found(c, find(items, id))

def created(+c: B.Context(Vars), got: Result<&2, &2, Store.Error, Todos>) -> B.Res:
  match got:
    case Done{Todos{next, t <> rest}}: C.json(Vars, C.status(Vars, c, 201), todo_json(t))
    case _: C.error(Vars, c, B.http_error(503, "store unavailable"))

def create(+c: B.Context(Vars), todos: B.Store(Todos)) -> IO(B.Res):
  +body = B.valid_body_in(Vars, c)
  +title = string_field(B.field(body, "title"))
  +done = bool_field(B.field(body, "done"))
  do IO<B.Res>:
    got : Result<&2, &2, Store.Error, Todos> <- Store.update(Todos, todos, s => added(s, title, done))
    return created(c, got)

def get_todo(+c: B.Context(Vars), todos: B.Store(Todos)) -> IO(B.Res):
  +id = id_param(B.field(B.valid_params_in(Vars, c), "id"))
  do IO<B.Res>:
    got : Result<&2, &2, Store.Error, Todos> <- Store.get(Todos, todos)
    return fetched(c, got, id)

def delete_todo(+c: B.Context(Vars), todos: B.Store(Todos)) -> IO(B.Res):
  +id = id_param(B.field(B.valid_params_in(Vars, c), "id"))
  do IO<B.Res>:
    got : Result<&2, &2, Store.Error, Todos> <- Store.update(Todos, todos, s => removed(s, id))
    return C.body(Vars, C.status(Vars, c, 204), [], None{})

def list_todos(+c: B.Context(Vars), todos: B.Store(Todos)) -> IO(B.Res):
  do IO<B.Res>:
    got : Result<&2, &2, Store.Error, Todos> <- Store.get(Todos, todos)
    return listed(c, got)

def themed(+c: B.Context(Vars), cookie: Result<&2, &2, Cookie.Error, B.Context(Vars)>) -> B.Res:
  match cookie:
    case Fail{e}: C.error(Vars, c, B.http_error(400, "invalid theme"))
    case Done{ctx}: C.text(Vars, ctx, "theme saved")

def theme(+c: B.Context(Vars)) -> B.Res:
  themed(c, C.set_cookie(Vars, c, "theme", text_or(C.query(Vars, c, "theme"), "light"), Cookie.defaults()))

# --- Server-Sent Events: five ticks, one a second ---

def send(+left: Nat) -> IO(E.Step<Nat>):
  do IO<E.Step<Nat>>:
    IO.sleep(1000)
    return E.Send{B.sse_data("tick " ++ Nat.show(left)), left}

def tick(n: Nat) -> IO(E.Step<Nat>):
  match n:
    case 0n: IO.pure(E.Step<Nat>, E.End{0n})
    case 1n+left: send(left)

def stopped(n: Nat) -> IO(Unit):
  IO.pure(Unit, Unit{})

# --- WebSocket echo ---

def opened(state: Unit, socket: B.WebSocketHandle) -> IO(Unit):
  IO.pure(Unit, state)

def echoed(state: Unit, socket: B.WebSocketHandle, message: M.Message) -> IO(Unit):
  match message:
    case M.TextMessage{text}:
      do IO<Unit>:
        sent : Bool <- B.websocket_send_text(socket, text)
        return state
    case _: IO.pure(Unit, state)

def closed(state: Unit, code: U32, reason: String) -> IO(Unit):
  IO.pure(Unit, state)

def handle(tag: Tag, +c: B.Context(Vars), env: Env) -> IO(B.Res):
  match tag env:
    case Home{} _: IO.pure(B.Res, C.html(Vars, c, "<h1>Todos</h1>"))
    case Hello{} _: IO.pure(B.Res, C.text(Vars, c, "Hello, " ++ text_or(C.query(Vars, c, "name"), "world") ++ " from " ++ user_of(C.get(Vars, c))))
    case ListTodos{} Env{todos}: list_todos(c, todos)
    case GetTodo{} Env{todos}: get_todo(c, todos)
    case CreateTodo{} Env{todos}: create(c, todos)
    case DeleteTodo{} Env{todos}: delete_todo(c, todos)
    case File{} _: IO.pure(B.Res, C.text(Vars, c, "file " ++ text_or(C.param(Vars, c, "path"), "")))
    case Events{} _: B.stream_sse(~Vars, ~Nat, ~tick, ~stopped, c, 5n, B.sse_config())
    case Socket{} _: B.websocket_handlers(~Vars, ~Unit, ~opened, ~echoed, ~closed, c, Unit{}, B.websocket_config(), B.websocket_session_config())
    case Theme{} _: IO.pure(B.Res, theme(c))
    case Stats{} _: IO.pure(B.Res, C.json(Vars, c, Json.JObject{[Json.Field{"admin", Json.JBool{True{}}}]}))
    case Health{} _: IO.pure(B.Res, C.text(Vars, c, "ok"))
    case _ _: IO.pure(B.Res, C.not_found(Vars, c))

def handler(tag: Tag, c: B.Context(Vars), env: Env) -> IO(B.Res):
  handle(tag, c, env)

# --- Middleware and hooks share one dispatcher ---

def who(+c: B.Context(Vars), next: B.Context(Vars) -> IO(B.Res)) -> IO(B.Res):
  next(C.set(Vars, c, Vars{text_or(C.request_header(Vars, c, "x-user"), "guest")}))

def middleware(tag: Tag, c: B.Context(Vars), env: Env, next: B.Context(Vars) -> IO(B.Res)) -> IO(B.Res):
  match tag:
    case Builtin{id}: B.builtin(Vars, id, c, next)
    case Who{}: who(c, next)
    case Stamp{}: next(C.header(Vars, c, "x-app", "todos"))
    case _: next(c)

# --- Routes ---

# Both routes share one params schema.
def by_id() -> List<&2, B.Registration(Tag)>:
  B.guard(Tag, B.guard_schemas(Tag, [], B.schemas([B.params_schema(todo_id())])), [
    B.get(Tag, "/todos/:id{int}", GetTodo{}),
    B.delete(Tag, "/todos/:id{int}", DeleteTodo{})])

def api() -> List<&2, B.Registration(Tag)>:
  List.concat(&2, B.Registration(Tag), [
    [B.get(Tag, "/todos", ListTodos{}),
     B.with_schemas(Tag, B.post(Tag, "/todos", CreateTodo{}), B.schemas([B.body_schema(todo_input())])),
     B.get(Tag, "/events", Events{})],
    by_id()])

def admin() -> List<&2, B.Registration(Tag)>:
  B.group(Tag, "/admin", [B.hook(Tag, Table.BeforeHandle{}, Builtin{B.basic_auth("admin", [B.credential("admin", "change me")])})], [
    B.get(Tag, "/stats", Stats{})])

# A named plugin applies once, however many times it is used.
def health(app: B.Builder(Tag)) -> B.Builder(Tag):
  B.named(Tag, B.plugin_id("health"), app, a => B.register(Tag, a, [B.get(Tag, "/healthz", Health{})]))

def entries() -> List<&2, B.Registration(Tag)>:
  List.concat(&2, B.Registration(Tag), [
    [B.use(Tag, Builtin{B.logger()}),
     B.use(Tag, Builtin{B.secure_headers()}),
     B.use(Tag, Who{}),
     B.before_handle(Tag, Stamp{}),
     B.get(Tag, "/", Home{}),
     B.get(Tag, "/hello", Hello{}),
     B.get(Tag, "/files/*path", File{}),
     B.post(Tag, "/theme", Theme{}),
     B.get(Tag, "/ws", Socket{})],
    B.route(Tag, "/api", api()),
    admin()])

def app() -> B.Builder(Tag):
  health(B.app_from(Tag, entries()))

def with_router(config: Config.Config, kind: B.RouterKind) -> Config.Config:
  Config.Config{host, port, limit, headers, idle, head, body, max, keep, old, mode, workers} = config
  Config.Config{host, port, limit, headers, idle, head, body, max, keep, kind, mode, workers}

def ready(env: Env, result: Result<&2, &2, B.RouteError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "invalid routes")
    case Done{table}: V.serve_with(~Vars, ~Tag, ~Env, ~handler, ~middleware, table, env, with_router(B.config(), B.trie()))

def main() -> IO(Unit):
  do IO<Unit>:
    todos : B.Store(Todos) <- B.store(Todos, Todos{1n, []})
    ready(Env{todos}, B.app_routes(Tag, app()))
```
<!-- #endregion todo-app -->
:::

## Read on

- [Migrate from Elysia](migrate-from-elysia.md) ports the same app from
  Elysia.
- [How a request flows](../concepts/index.md) explains tags, dispatchers and
  the onion.
- The [examples](../examples.md) are complete apps to copy from.
