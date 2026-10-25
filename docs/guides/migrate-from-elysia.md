---
title: Migrate from Elysia
description: Port an Elysia app to Bendo feature by feature, with side-by-side code for routing, lifecycle hooks, plugins, validation, WebSockets, Eden and testing.
---

# Migrate from Elysia

Bendo takes several ideas from Elysia: schemas declared on the route,
lifecycle hooks with the same stages, named plugins that apply once, and end
to end types for the client. The code looks different because Bend has no
closures you can store in a route table, so a route points at a tag and one
function answers every tag. This page maps each Elysia feature to its Bendo
form, using one small todo API written both ways.

The Elysia code is the starting point. It is checked against Elysia 1.4.30
with `@elysiajs/openapi` and `@elysiajs/eden`, but it is not compiled by
Bendo's CI. The Bendo code is checked in CI, and it is the same app the
[Hono guide](migrate-from-hono.md) ends with. Both [complete apps](#the-complete-apps)
are at the end of the page.

## What changes

| Concept | Elysia | Bendo |
|---|---|---|
| Handler | A closure passed to `.get` | A tag such as `ListTodos{}`, answered by one `handle` function |
| Hooks and middleware | Closures passed to `.onBeforeHandle` and friends | Tags registered for a stage, answered by one `middleware` function |
| Context | One object with `params`, `query`, `body`, `set`, `store` | An immutable `B.Context(Vars)` with accessor functions |
| `derive`, `resolve` | Values added to the context | A typed `Vars` record: `C.set` and `C.get` |
| `decorate` | Values added to the context | An `Env` record passed to every handler |
| `state` | A mutable store | A [store](../store.md), an actor that serializes updates |
| Method chaining | `.use(a).get(...)` | A route list, and plugin calls that nest |
| Runtime | Bun, or adapters | A native binary behind a reverse proxy |

A Bendo app is a route list, a handler and a middleware dispatcher:

```bend
case Done{table}: V.serve_with(~Vars, ~Tag, ~Env, ~handler, ~middleware, table, env, with_router(B.config(), B.trie()))
```

## Coverage

Every row of Bendo's parity table, with the section that covers it:

| Feature | Elysia | Section |
|---|---|---|
| Routing with params, wildcards, constraints | Yes | [Routes, params and wildcards](#routes-params-and-wildcards) |
| Multiple router engines | No | [Router engines](#router-engines) |
| 405 with `Allow` | No | [Method not allowed](#method-not-allowed) |
| Sub-apps, `basePath`, groups | Yes | [Prefixes, groups and guards](#prefixes-groups-and-guards) |
| Context helpers | Yes | [Requests and responses](#requests-and-responses) |
| Onion middleware | No | [Middleware and derive](#middleware-and-derive) |
| Lifecycle hooks | Yes | [Lifecycle hooks](#lifecycle-hooks) |
| Plugins | Yes | [Plugins](#plugins) |
| Validation | Built in | [Validation](#validation) |
| JSON, forms, multipart, cookies | Yes | [JSON, forms and cookies](#json-forms-and-cookies) |
| Built-in middleware | Plugins | [Built-in middleware](#built-in-middleware) |
| Streaming, SSE | Yes | [Streaming and Server-Sent Events](#streaming-and-server-sent-events) |
| WebSockets | Yes | [WebSockets](#websockets) |
| Typed client | Eden | [Typed client](#typed-client) |
| OpenAPI | Plugin | [OpenAPI](#openapi) |
| Testing without a network | `app.handle` | [Testing without a network](#testing-without-a-network) |
| Shared validators in the browser | No | [Shared validators](#shared-validators) |
| Proven core | No | [Proofs](#proofs) |
| Parallel and GPU handlers | No | [Parallel and GPU handlers](#parallel-and-gpu-handlers) |
| Runs on edge runtimes | Partly | [Edge runtimes](#edge-runtimes) |
| JSX rendering | Plugin | [JSX](#jsx) |
| TLS, HTTP/2 | Via runtime | [TLS and HTTP versions](#tls-and-http-versions) |

## Routes, params and wildcards

Elysia validates a param's type with a schema. Bendo can do that too (see
[validation](#validation)), but its patterns can also carry a constraint, so
`/todos/abc` never matches `/todos/:id{int}` at all:

::: code-group

```ts [Elysia]
.get("/todos/:id", ({ params, store, status }) => {
```

```bend [Bendo]
B.get(Tag, "/todos/:id{int}", GetTodo{}),
```

:::

Elysia's wildcard is `*`, read as `params["*"]`. Bendo's can have a name:

::: code-group

```ts [Elysia]
.get("/files/*", ({ params }) => `file ${params["*"]}`)
```

```bend [Bendo]
B.get(Tag, "/files/*path", File{}),
```

:::

```bend
case File{} _: IO.pure(B.Res, C.text(Vars, c, "file " ++ text_or(C.param(Vars, c, "path"), "")))
```

Optional segments (`/:id?`), `{uuid}`, `{slug}`, character classes such as
`{[0-9]+}` and multi-segment spans work too; [route patterns](../router-patterns.md)
lists them. The first registered route that matches wins, so put specific
routes before general ones.

## Router engines

Elysia has one router. Bendo has two: the spec router, a plain first-match
list that defines the behavior, and the trie router, which is the default and
is proven to return the same result for every table and path. The choice is a
config field:

```bend
def with_router(config: Config.Config, kind: B.RouterKind) -> Config.Config:
  Config.Config{host, port, limit, headers, idle, head, body, max, keep, old, mode, workers} = config
  Config.Config{host, port, limit, headers, idle, head, body, max, keep, kind, mode, workers}
```

There is no reason to pick `B.spec()` in production; it exists so the
[proofs](../router-trie.md#equivalence-proof) have something to compare.

## Method not allowed

Elysia answers 404 when a path exists but not for the request's method.
Bendo answers `405 Method Not Allowed` with an `Allow` header, adding `HEAD`
wherever `GET` exists, with no code. With the routes below, `PUT /api/todos`
gets `allow: GET, HEAD, POST`:

```bend
[B.get(Tag, "/todos", ListTodos{}),
B.with_schemas(Tag, B.post(Tag, "/todos", CreateTodo{}), B.schemas([B.body_schema(todo_input())])),
```

## Prefixes, groups and guards

An Elysia instance with a `prefix` becomes a route list mounted with
`B.route`. `.group(prefix, ...)` becomes `B.group`, which takes the hooks that
apply inside it, and `.guard(...)` becomes `B.guard`:

::: code-group

```ts [Elysia]
const api = new Elysia({ prefix: "/api" })
```

```bend [Bendo]
B.route(Tag, "/api", api()),
```

:::

::: code-group

```ts [Elysia]
const admin = new Elysia({ prefix: "/admin" })
  .onBeforeHandle(({ headers, status }) => {
    if (headers.authorization !== `Basic ${btoa("admin:change me")}`)
      return status(401, "Unauthorized");
  })
  .get("/stats", () => ({ admin: true }));
```

```bend [Bendo]
def admin() -> List<&2, B.Registration(Tag)>:
  B.group(Tag, "/admin", [B.hook(Tag, Table.BeforeHandle{}, Builtin{B.basic_auth("admin", [B.credential("admin", "change me")])})], [
    B.get(Tag, "/stats", Stats{})])
```

:::

::: code-group

```ts [Elysia]
.guard({ params: t.Object({ id: t.Numeric({ minimum: 1 }) }) }, (app) =>
```

```bend [Bendo]
def by_id() -> List<&2, B.Registration(Tag)>:
  B.guard(Tag, B.guard_schemas(Tag, [], B.schemas([B.params_schema(todo_id())])), [
    B.get(Tag, "/todos/:id{int}", GetTodo{}),
    B.delete(Tag, "/todos/:id{int}", DeleteTodo{})])
```

:::

`B.base_path` mounts a list under a prefix too, under Hono's name for it.
[Compose route lists](../router-compose.md) and
[hook scopes](../decisions/0011-hook-scopes.md) cover the rules.

## Requests and responses

Elysia hands a handler one context object. Bendo hands it an immutable
context and a function for each part, from `src/app/context.bend` imported as
`C`. Each takes the `Vars` type first:

| Elysia | Bendo |
|---|---|
| `params.id` | `C.param(Vars, c, "id")`, or the decoded `B.valid_params_in(Vars, c)` |
| `query.name` | `C.query(Vars, c, "name")` |
| `headers["x-user"]` | `C.request_header(Vars, c, "x-user")` |
| `body` | `B.valid_body_in(Vars, c)` with a body schema, or `C.raw_body(Vars, c)` |
| `set.status = 201` | `C.status(Vars, c, 201)` |
| `set.headers[name] = value` | `C.header(Vars, c, name, value)` |
| `status(404, "Not Found")` | `C.error(Vars, c, B.http_error(404, "Not Found"))`, or `C.not_found(Vars, c)` |
| `redirect(url)` | `C.redirect(Vars, c, url)` |
| Returning a string or an object | `C.text(Vars, c, text)` or `C.json(Vars, c, value)` |

::: code-group

```ts [Elysia]
.get("/hello", ({ query, user }) => `Hello, ${query.name ?? "world"} from ${user}`)
```

```bend [Bendo]
case Hello{} _: IO.pure(B.Res, C.text(Vars, c, "Hello, " ++ text_or(C.query(Vars, c, "name"), "world") ++ " from " ++ user_of(C.get(Vars, c))))
```

:::

A handler returns a `B.Res` built by one of those functions; Bendo does not
guess a content type from a returned value. A lookup returns a `Maybe`, so a
missing value is handled where it is read.

## Middleware and derive

Elysia adds values to the context with `derive`. Bendo passes a `Vars` record
down the middleware chain, set by an ordinary middleware tag:

::: code-group

```ts [Elysia]
.derive(({ headers }) => ({ user: headers["x-user"] ?? "guest" }))
```

```bend [Bendo]
def who(+c: B.Context(Vars), next: B.Context(Vars) -> IO(B.Res)) -> IO(B.Res):
  next(C.set(Vars, c, Vars{text_or(C.request_header(Vars, c, "x-user"), "guest")}))
```

:::

```bend
B.use(Tag, Who{}),
```

Bendo's middleware is an onion, as in Hono: each layer runs code before and
after the layers inside it by calling `next` and transforming the response it
returns. The first one registered is the outermost. `B.use_path` scopes a
layer to a path.

`decorate` values belong in `Env`, which every handler and middleware
receives:

```bend
type Env is Data:
  Env{todos: B.Store(Todos)}
```

## Lifecycle hooks

Bendo has Elysia's stages, in the same order, registered in the route list:

| Elysia | Bendo |
|---|---|
| `onRequest` | `B.on_request` |
| `onParse` | `B.on_parse` |
| `onTransform` | `B.on_transform` |
| `onBeforeHandle` | `B.before_handle` |
| `onAfterHandle` | `B.after_handle` |
| `mapResponse` | `B.map_response` |
| `onError` | `B.on_error` |
| `onAfterResponse` | `B.on_after_response` |

::: code-group

```ts [Elysia]
.onBeforeHandle(({ set }) => {
  set.headers["x-app"] = "todos";
})
```

```bend [Bendo]
B.before_handle(Tag, Stamp{}),
```

:::

```bend
case Stamp{}: next(C.header(Vars, c, "x-app", "todos"))
```

A hook is a middleware tag: it gets `next` and returns a response. A
pre-handler hook answers early by returning a response without calling `next`,
where an Elysia hook returns a value. Validation runs between `on_transform`
and `before_handle`, as in Elysia.

Elysia's `as: "local" | "scoped" | "global"` becomes a question of where the
hook is registered: at the top of the list it is global, inside `B.group` or
`B.guard` it covers that scope, and `B.route_hooks` attaches it to one route.
See [hooks](../concepts/hooks.md).

## Plugins

An Elysia plugin is an instance you `.use`. A Bendo plugin is a function from
builder to builder. Give it a name with `B.named` and it applies once, however
many times it is used, as Elysia's `name` does:

::: code-group

```ts [Elysia]
const health = new Elysia({ name: "health" }).get("/healthz", () => "ok");
```

```bend [Bendo]
def health(app: B.Builder(Tag)) -> B.Builder(Tag):
  B.named(Tag, B.plugin_id("health"), app, a => B.register(Tag, a, [B.get(Tag, "/healthz", Health{})]))
```

:::

```bend
health(B.app_from(Tag, entries()))
```

`B.plugin_seed(name, seed)` plays the role of Elysia's `seed`. Bend has no
method chaining, so plugin calls nest and the innermost applies first.
[Write a plugin](plugins.md) covers scopes.

## Validation

Elysia's `t` builders become schema values from `src/data/schema.bend`. They
attach to a route with `B.with_schemas`, and the handler reads the decoded
values instead of `body`:

::: code-group

```ts [Elysia]
body: t.Object({
  title: t.String({ minLength: 1, maxLength: 80 }),
  done: t.Optional(t.Boolean()),
}),
```

```bend [Bendo]
def todo_input() -> S.Schema:
  S.ObjectSchema{[
    S.Field{"title", S.StringSchema{1n, Some{80n}, None{}, S.Plain{}}, S.Required{}},
    S.Field{"done", S.BooleanSchema{}, S.Default{Json.JBool{False{}}}}], S.Strict{}}
```

:::

```bend
B.with_schemas(Tag, B.post(Tag, "/todos", CreateTodo{}), B.schemas([B.body_schema(todo_input())])),
```

```bend
+body = B.valid_body_in(Vars, c)
+title = string_field(B.field(body, "title"))
+done = bool_field(B.field(body, "done"))
```

| Elysia | Bendo |
|---|---|
| `t.String({ minLength, maxLength, pattern, format })` | `S.StringSchema{min, max, pattern, format}` |
| `t.Number`, `t.Integer`, `t.Numeric` | `S.NumberSchema`, `S.IntegerSchema`; path and query text is coerced |
| `t.Boolean`, `t.Literal`, `t.Union` | `S.BooleanSchema{}`, `S.LiteralSchema`, `S.UnionSchema` |
| `t.Object`, `t.Array`, `t.Nullable` | `S.ObjectSchema`, `S.ArraySchema`, `S.NullableSchema` |
| `t.Optional(x)`, `default` | `S.Optional{}` or `S.Default{value}` on the field |

A request that fails never reaches the handler. Bad params, query or headers
get 400, and a bad body gets 422, with every failing path in a JSON list:

```json
{"error":"Unprocessable Content","status":422,"errors":[{"path":["body","title"],"code":"constraint","message":"value does not satisfy scalar checks"}]}
```

Serve an app with schemas through `V.serve_with` from `src/validated.bend`;
`B.serve_with` refuses to start, so a schema is never silently ignored. See
[validation](../concepts/validation.md) and the [schema reference](../data/schema.md).

## JSON, forms and cookies

Elysia parses the body by content type before the handler. Bendo parses JSON
bodies for a body schema, and otherwise gives the handler the raw octets.
Elysia's reactive cookies become setter calls that return a `Result`:

::: code-group

```ts [Elysia]
.post("/theme", ({ query, cookie: { theme } }) => {
  theme.value = query.theme ?? "light";
  return "theme saved";
})
```

```bend [Bendo]
def theme(+c: B.Context(Vars)) -> B.Res:
  themed(c, C.set_cookie(Vars, c, "theme", text_or(C.query(Vars, c, "theme"), "light"), Cookie.defaults()))
```

:::

| Elysia | Bendo |
|---|---|
| `body` for JSON | A body schema, or `Json.parse(C.raw_body(Vars, c))` |
| `body` for a form, `t.File` | `Form.parse_body(content_type, C.raw_body(Vars, c))`; see the [uploads guide](uploads.md) |
| `cookie.name.value` | `C.cookie(Vars, c, name)`, `C.set_cookie`, `C.delete_cookie` |
| `cookie: { secrets }`, `sign` | `C.signed_cookie` and `C.set_signed_cookie`, in Hono's format |

## Built-in middleware

Elysia keeps most features in plugins. Bendo ships them as built-ins, wrapped
in one `Builtin{id: B.Builtin}` case of your middleware tag:

```bend
[B.use(Tag, Builtin{B.logger()}),
B.use(Tag, Builtin{B.secure_headers()}),
```

```bend
case Builtin{id}: B.builtin(Vars, id, c, next)
```

| Elysia plugin | Bendo |
|---|---|
| `@elysiajs/cors` | `B.cors` ([CORS guide](cors.md)) |
| `@elysiajs/bearer`, `@elysiajs/jwt` | `B.bearer_auth`, `B.jwt`, `B.jwt_with` ([auth guide](auth.md)) |
| `@elysiajs/static` | `B.serve_static` ([static files](../static.md)) |
| `@elysiajs/server-timing` | `B.server_timing` ([observability](../observability.md)) |
| `@elysiajs/openapi` | `bendo openapi` ([below](#openapi)) |
| `@elysiajs/html` | `C.html` ([below](#jsx)) |
| Community helmet, rate limit and logger plugins | `B.secure_headers`, `B.rate_limit`, `B.logger` |
| Not usually in Elysia | `B.basic_auth`, `B.csrf`, `B.etag`, `B.body_limit`, `B.timeout`, `B.ip_restriction`, `B.request_id` |

## Streaming and Server-Sent Events

An Elysia generator that yields `sse(...)` becomes a producer: a function from
state to the next step, which says whether to send a frame, wait or end.

::: code-group

```ts [Elysia]
.get("/events", async function* () {
  for (let left = 4; left >= 0; left--) {
    await Bun.sleep(1000);
    yield sse(`tick ${left}`);
  }
});
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

`B.stream` does the same for raw bytes. See [Server-Sent Events](../sse.md).

## WebSockets

`.ws(path, { open, message, close })` becomes `B.websocket_handlers` with three
templates and a state value per connection:

::: code-group

```ts [Elysia]
.ws("/ws", {
  message(ws, message) {
    ws.send(message);
  },
})
```

```bend [Bendo]
case Socket{} _: B.websocket_handlers(~Vars, ~Unit, ~opened, ~echoed, ~closed, c, Unit{}, B.websocket_config(), B.websocket_session_config())
```

:::

Topics work like Elysia's: `ws.subscribe` becomes `P.subscribe`, `ws.publish`
(everyone but the sender) becomes `P.publish_others`, and `server.publish`
becomes `P.publish` on a hub created at startup. These lines come from the
[WebSocket guide](websockets.md#put-connections-in-rooms):

::: code-group

```ts [Elysia]
open(ws) {
  ws.subscribe(ws.data.params.room);
},
message(ws, message) {
  ws.publish(ws.data.params.room, message);
},
```

<!-- source: docs/guides/websockets.md -->
```bend [Bendo]
def join(+room: String, peer: P.Peer) -> IO(String):
  do IO<String>:
    joined : Bool <- P.subscribe(peer, room)
    return room
```

:::

::: code-group

```ts [Elysia]
.post("/rooms/:room/announce", ({ params, body, server }) => {
  server?.publish(params.room, body);
```

<!-- source: docs/guides/websockets.md -->
```bend [Bendo]
result : Result<&2, &2, Store.Error, P.Delivery> <- P.publish(hub, room_name(C.param(Unit, c, "room")), body_text(Utf8.decode(C.raw_body(Unit, c))))
```

:::

A publication returns how many connections accepted, dropped or had already
left. A connection leaves every topic when it closes.

## Typed client

Eden reads types from the server's TypeScript. A Bendo server is not
TypeScript, so `bendo gen` asks the compiled app for its routes and schemas and
writes `.bendo/routes.ts`, and `createClient` reads that. Paths read like
Eden's:

::: code-group

```ts [Elysia · client.ts]
import { treaty } from "@elysiajs/eden";
import type { App } from "./server";

const api = treaty<App>("localhost:8787");

const { data, error } = await api.api.todos.post({ title: "Write docs" });
if (error) console.log(error.status, error.value);
else console.log(data.title);
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

The body goes in a `body` field, next to `query` and `headers`. Captures are
calls, as in Eden: `api.api.todos({ id: 1 }).get()`. The Bendo snippet uses
the routes generated for the [todo example](../examples.md#todo), which
declare response schemas; a route without one returns `unknown` data. The
client also checks responses against those schemas. See
[typed client](../client.md) and the [TanStack Query helpers](../query.md).

## OpenAPI

`@elysiajs/openapi` builds a document from the running app. `bendo openapi`
builds it from the compiled app's routes and schemas, and `src/api-docs.bend`
serves it with a Scalar reference page:

::: code-group

```ts [Elysia]
.use(openapi())
```

```sh [Bendo]
bendo openapi main.bend --bend openapi-doc.bend
bendo build
```

:::

<!-- source: tests/fixtures/openapi/app.bend -->
```bend
def spec(c: B.Ctx) -> IO(B.Res):
  IO.pure(B.Res, Docs.openapi(c, OpenApiDoc.json()))
```

Run `bendo openapi` again after changing a route. See
[OpenAPI and API docs](../openapi.md).

## Testing without a network

`app.handle(request)` becomes `B.handle`, which runs the app on a request
value and returns the response without opening a socket:

::: code-group

```ts [Elysia · server.test.ts]
import { expect, test } from "bun:test";
import { Elysia } from "elysia";

const app = new Elysia().get("/", () => "Hello from Elysia!");

test("GET / answers 200", async () => {
  const res = await app.handle(new Request("http://localhost/"));
  expect(res.status).toBe(200);
  expect(await res.text()).toBe("Hello from Elysia!");
});
```

<!-- source: docs/guides/migrate-from-hono.md -->
```bend [Bendo]
def check(result: Result<&2, &2, B.RouteError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "invalid routes")
    case Done{+table}:
      do IO<Unit>:
        home : B.Res <- B.handle(~Tag, ~Unit, ~dispatch, table, Unit{}, get("/"), [])
        expect(answered(home, 200, "Hello from Bendo!"), "GET / answers 200")
        missing : B.Res <- B.handle(~Tag, ~Unit, ~dispatch, table, Unit{}, get("/nope"), [])
        expect(answered(missing, 404, "Not Found"), "GET /nope answers 404")
```

:::

The whole test program is in the [Hono guide](migrate-from-hono.md#testing-without-a-network).
Build it with `bend test.bend -o test` and run `./test`. Use `B.handle_with`
for an app with middleware.

## Shared validators

A TypeBox schema is TypeScript, so a browser can import the same file as an
Elysia server. Bendo gets the same result the other way round:
`bendo build --shared` compiles the server's Bend schema module to JavaScript
with type declarations, and the browser imports that.

::: code-group

```ts [Elysia · shared.ts]
import { t } from "elysia";
import { Value } from "@sinclair/typebox/value";

// Imported by the server's route and by the browser's form.
export const todoInput = t.Object({
  title: t.String({ minLength: 1, maxLength: 80 }),
  done: t.Optional(t.Boolean()),
});

if (!Value.Check(todoInput, { title: "" })) console.log([...Value.Errors(todoInput, { title: "" })]);
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

The browser runs exactly the decoder the server runs. See
[share Bend code with JavaScript](../shared.md).

## Proofs

Elysia is tested; Bendo's core is also proven. Parsing, routing, middleware
order, JSON, cookies and validation are pure Bend functions with laws in
`LAWS.bend`, checked on every build:

```sh
bun run prove   # ALL PROOFS CHECK
```

There is nothing to port. [Proofs](../concepts/proofs.md) explains what the
laws cover.

## Parallel and GPU handlers

A Bend handler can split pure work across every core, and a `!` call hands it
to the GPU when one is present:

<!-- source: examples/mandelbrot/render.bend -->
```bend
def rows_gpu(+w: U32, +h: U32, +iter: U32) -> List<&2, List<&2, U32>>:
  rows_fork!(rows_depth(h), 0, 1, w, h, iter)
```

The [Mandelbrot example](../examples.md#mandelbrot) renders the same image on
one core, all cores or the GPU. For more requests per second, run several
[workers](../workers.md).

## Edge runtimes

Elysia 1.4 can target Cloudflare Workers through an adapter. Bendo compiles to
a native binary only. To serve from Cloudflare's edge, run the binary on a
server and put Cloudflare in front, as the
[deployment guide](deploy.md#put-cloudflare-in-front) shows.

::: code-group

```ts [Elysia · worker.ts]
import { Elysia } from "elysia";
import { CloudflareAdapter } from "elysia/adapter/cloudflare-worker";

export default new Elysia({ adapter: CloudflareAdapter })
  .get("/", () => "Hello from the edge")
  .compile();
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

```tsx [Elysia · page.tsx]
/** @jsxImportSource @kitajs/html */
import { Elysia } from "elysia";
import { html } from "@elysiajs/html";

new Elysia().use(html()).get("/", () => <h1>Todos</h1>);
```

```bend [Bendo]
case Home{} _: IO.pure(B.Res, C.html(Vars, c, "<h1>Todos</h1>"))
```

:::

`C.html` does not escape anything. Escape user input yourself.

## TLS and HTTP versions

Elysia passes TLS options to Bun. Bendo speaks HTTP/1.1 without TLS and
leaves TLS and HTTP/2 to a reverse proxy:

::: code-group

```ts [Elysia · tls.ts]
import { Elysia } from "elysia";

new Elysia()
  .get("/", () => "Hello over TLS")
  .listen({ port: 443, tls: { cert: Bun.file("cert.pem"), key: Bun.file("key.pem") } });
```

```text [Bendo · Caddyfile]
api.example.com {
	reverse_proxy 127.0.0.1:8787
}
```

:::

See [deploy behind Caddy or Cloudflare](deploy.md).

## Move traffic over

Port one group of routes at a time. Run the Bendo app next to the Elysia app
and let the proxy send it one path:

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

Compare status codes and bodies before moving the next group, especially 404
against 405 and the shape of validation errors, which differ from Elysia's. To
roll back, remove the `handle` block and reload the proxy. Shared state has to
live outside both processes while they run side by side.

## The complete apps

::: details Elysia: server.ts
```ts [Elysia · server.ts]
import { Elysia, sse, t } from "elysia";
import { openapi } from "@elysiajs/openapi";

type Todo = { id: number; title: string; done: boolean };

const health = new Elysia({ name: "health" }).get("/healthz", () => "ok");

const api = new Elysia({ prefix: "/api" })
  .state({ todos: [] as Todo[], nextId: 1 })
  .get("/todos", ({ store }) => store.todos)
  .post(
    "/todos",
    ({ body, store, status }) => {
      const todo = { id: store.nextId++, title: body.title, done: body.done ?? false };
      store.todos.unshift(todo);
      return status(201, todo);
    },
    {
      body: t.Object({
        title: t.String({ minLength: 1, maxLength: 80 }),
        done: t.Optional(t.Boolean()),
      }),
    },
  )
  .guard({ params: t.Object({ id: t.Numeric({ minimum: 1 }) }) }, (app) =>
    app
      .get("/todos/:id", ({ params, store, status }) => {
        const todo = store.todos.find((todo) => todo.id === params.id);
        return todo ?? status(404, "Not Found");
      })
      .delete("/todos/:id", ({ params, store, set }) => {
        store.todos = store.todos.filter((todo) => todo.id !== params.id);
        set.status = 204;
      }),
  )
  .get("/events", async function* () {
    for (let left = 4; left >= 0; left--) {
      await Bun.sleep(1000);
      yield sse(`tick ${left}`);
    }
  });

const admin = new Elysia({ prefix: "/admin" })
  .onBeforeHandle(({ headers, status }) => {
    if (headers.authorization !== `Basic ${btoa("admin:change me")}`)
      return status(401, "Unauthorized");
  })
  .get("/stats", () => ({ admin: true }));

const app = new Elysia()
  .use(openapi())
  .use(health)
  .derive(({ headers }) => ({ user: headers["x-user"] ?? "guest" }))
  .onBeforeHandle(({ set }) => {
    set.headers["x-app"] = "todos";
  })
  .get("/", () => new Response("<h1>Todos</h1>", { headers: { "content-type": "text/html" } }))
  .get("/hello", ({ query, user }) => `Hello, ${query.name ?? "world"} from ${user}`)
  .get("/files/*", ({ params }) => `file ${params["*"]}`)
  .post("/theme", ({ query, cookie: { theme } }) => {
    theme.value = query.theme ?? "light";
    return "theme saved";
  })
  .ws("/ws", {
    message(ws, message) {
      ws.send(message);
    },
  })
  .ws("/ws/rooms/:room", {
    open(ws) {
      ws.subscribe(ws.data.params.room);
    },
    message(ws, message) {
      ws.publish(ws.data.params.room, message);
    },
  })
  .post("/rooms/:room/announce", ({ params, body, server }) => {
    server?.publish(params.room, body);
    return "sent";
  }, { body: t.String() })
  .use(api)
  .use(admin)
  .listen(8787);

export type App = typeof app;
```
:::

::: details Bendo: main.bend
<!--@include: ./migrate-from-hono.md#todo-app-->
:::

## Read on

- [Migrate from Hono](migrate-from-hono.md) ports the same app from Hono.
- [How a request flows](../concepts/index.md) explains tags, dispatchers and
  the onion.
- [Hook scopes](../decisions/0011-hook-scopes.md) maps Elysia's `local`,
  `scoped` and `global` in detail.
