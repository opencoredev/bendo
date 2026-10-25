# App and server

An app is a route table of tags, one dispatcher that turns a tag into a
response, and an `env` value that every request receives. This page lists the
core types, the calls that serve a table or run it without a socket, the
server config, and the plugin builder. The
[quick start](../../getting-started.md#3-create-an-app) shows a whole app;
[Routing](routing.md) lists the calls that build the table.

Examples on this page are one Bend program and share this setup:

```bend
import Base
import ./bendo/main.bend as B
import ./bendo/validated.bend as V
import ./bendo/app/context.bend as C
import ./bendo/app/config.bend as Config
import ./bendo/app/table.bend as Table
import ./bendo/http/request.bend as Request

type Tag is Data:
  Home{}
  Hello{}
  Stamp{}
  Limit{id: B.Builtin}

type Env is Data:
  Env{greeting: String}

def dispatch(tag: Tag, c: B.Ctx, env: Env) -> IO(B.Res):
  Env{greeting} = env
  IO.pure(B.Res, B.text(c, greeting))

def handler(tag: Tag, c: B.Context(Unit), env: Env) -> IO(B.Res):
  IO.pure(B.Res, C.text(Unit, c, "hello"))

def middleware(tag: Tag, c: B.Context(Unit), env: Env, next: B.Context(Unit) -> IO(B.Res)) -> IO(B.Res):
  match tag:
    case Stamp{}: next(C.header(Unit, c, "x-app", "bendo"))
    case Limit{id}: B.builtin(Unit, id, c, next)
    case _: next(c)
```

## Types

### `B.Req`

```bend signature
def Req() -> Data

type Req is Data:
  Req{method: Method, path: String, query: Maybe<&2, String>, version: Version, headers: List<&2, Header>}
```

A parsed request head, defined in `http/request.bend`. The server builds it
for you; you construct one only to call `B.handle`. `path` excludes the query,
which is the raw text after `?`. Handlers read requests through the
[context](context.md) instead.

```bend
def ex_request() -> B.Req:
  Request.Req{Request.Get{}, "/hello", None{}, Request.Http11{}, []}
```

### `B.Res`

```bend signature
def Res() -> Data
```

A response: status, headers and body octets. Handlers and middleware return
`IO(B.Res)`. Build one with the response helpers on the
[context page](context.md), such as `B.text` and `B.json`.

```bend
def ex_ok(c: B.Ctx) -> B.Res:
  B.text(c, "ok")
```

### `B.Ctx`, `B.Context`

```bend signature
def Ctx() -> Data
def Context(-Vars: Data) -> Data
```

The per-request context: the request, its route params and body, and the
response status and headers set so far. `B.Context(Vars)` also carries a
typed value of the app's `Vars` type, which middleware sets for the handlers
after it. `B.Ctx` is `B.Context(Unit)`, the context `B.serve` dispatchers
receive. [Context](../../concepts/context.md) explains the model.

```bend
def ex_same_ctx(c: B.Ctx) -> B.Context(Unit):
  c
```

### `B.Registration`

```bend signature
def Registration(-Tag: Data) -> Data
```

One entry in a route list: a route, a middleware, or a lifecycle hook. Every
registration call on the [Routing](routing.md) page returns one, and route
lists are `List<&2, B.Registration(Tag)>`. Like the table, it holds only data.

```bend
def ex_entries() -> List<&2, B.Registration(Tag)>:
  [B.use(Tag, Stamp{}), B.get(Tag, "/", Home{}), B.get(Tag, "/hello", Hello{})]
```

### `B.Routes`, `B.RouteError`

```bend signature
def Routes(-Tag: Data) -> Data
def RouteError() -> Data
```

`B.Routes(Tag)` is a built route table: the validated routes, their compiled
index, and the middleware and hooks. It is copyable `Data`; build it once in
`main` with `B.routes` or `B.app_routes` and pass it to `B.serve`.
`B.RouteError` is the reason a build failed, the same type as
`Methods.BuildError`, which names the constructors.

```bend
def ex_built(result: Result<&2, &2, B.RouteError, B.Routes(Tag)>) -> String:
  match result:
    case Done{table}: "built"
    case Fail{error}: "invalid routes"
```

## Serve an app

### `B.serve`

```bend signature
def serve(~Tag: Data, ~Env: Data, ~dispatch: Tag -> B.Ctx -> Env -> IO(B.Res), table: B.Routes(Tag), env: Env, config: B.ServerConfig) -> IO(Unit)
```

Starts the HTTP server and runs until the process stops. `dispatch` is a
top-level def passed as a template, so it can run for every request. Run with
`--bendo-routes`, the binary prints the [route manifest](../../manifest.md)
and exits instead. At startup it reads `PORT`, `BENDO_ENV` and
`BENDO_WORKERS`, then prints `bendo listening on http://<host>:<port>`. It
exits with an error if the table declares route schemas (use `V.serve`), and
a middleware or hook entry stops the process when a request reaches it (use
`B.serve_with`).

```bend
def ex_ready(result: Result<&2, &2, B.RouteError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Done{table}: B.serve(~Tag, ~Env, ~dispatch, table, Env{"hi"}, B.config())
    case Fail{error}: IO.die(Unit, 1, "invalid routes")

def ex_main() -> IO(Unit):
  ex_ready(B.routes(Tag, [B.get(Tag, "/", Home{})]))
```

### `B.serve_with`

```bend signature
def serve_with(~Vars: Data, ~Tag: Data, ~Env: Data, ~dispatch: Tag -> B.Context(Vars) -> Env -> IO(B.Res), ~middleware: Tag -> B.Context(Vars) -> Env -> (B.Context(Vars) -> IO(B.Res)) -> IO(B.Res), table: B.Routes(Tag), env: Env, config: B.ServerConfig) -> IO(Unit)
```

`B.serve` with a middleware dispatcher and a `Vars` type for the context.
Use it whenever the table has `B.use`, `B.use_path` or hook entries. Every
handler and middleware in the app sees the same `B.Context(Vars)`; pass `Unit`
when the app needs no variables. `next` can be called at most once. See
[middleware](../../middleware.md).

```bend
def ex_serve_with(table: B.Routes(Tag)) -> IO(Unit):
  B.serve_with(~Unit, ~Tag, ~Env, ~handler, ~middleware, table, Env{"hi"}, B.config())
```

### `B.serve_limits_with`

```bend signature
def serve_limits_with(~Vars: Data, ~Tag: Data, ~select: Tag -> Maybe<&2, U32>, ~Env: Data, ~dispatch: Tag -> B.Context(Vars) -> Env -> IO(B.Res), ~middleware: Tag -> B.Context(Vars) -> Env -> (B.Context(Vars) -> IO(B.Res)) -> IO(B.Res), table: B.Routes(Tag), env: Env, config: B.ServerConfig) -> IO(Unit)
```

`B.serve_with` that rejects an oversized body before reading it. `select`
returns the body limit a middleware tag enforces, or `None{}`. For each
request the server takes the smallest of the config's `body_limit` and every
limit selected from the middleware and pre-handler hooks of the route it
resolves. `select` must return the same limits the middleware enforces. See
[request limits](../../limits-cache.md).

```bend
def ex_limit(tag: Tag) -> Maybe<&2, U32>:
  match tag:
    case Limit{id}: B.builtin_body_limit(id)
    case _: None{}

def ex_serve_limited(table: B.Routes(Tag)) -> IO(Unit):
  B.serve_limits_with(~Unit, ~Tag, ~ex_limit, ~Env, ~handler, ~middleware, table, Env{"hi"}, B.config())
```

### `V.serve`, `V.serve_with`

```bend signature
import ./bendo/validated.bend as V

def serve(~Tag: Data, ~Env: Data, ~dispatch: Tag -> B.Ctx -> Env -> IO(B.Res), table: B.Routes(Tag), env: Env, config: B.ServerConfig) -> IO(Unit)
def serve_with(~Vars: Data, ~Tag: Data, ~Env: Data, ~dispatch: Tag -> B.Context(Vars) -> Env -> IO(B.Res), ~middleware: Tag -> B.Context(Vars) -> Env -> (B.Context(Vars) -> IO(B.Res)) -> IO(B.Res), table: B.Routes(Tag), env: Env, config: B.ServerConfig) -> IO(Unit)
```

`B.serve` and `B.serve_with` with the schema decoder linked in, for apps whose
routes declare schemas. Requests are checked against their route's schemas
before `before_handle`, and `--bendo-routes` prints each route's schemas too.
The `B.` versions leave the decoder out, which keeps apps without schemas
smaller. See [route validation](../../validation.md#serve-with-validation).

```bend
def ex_serve_validated(+table: B.Routes(Tag)) -> IO(Unit):
  do IO<Unit>:
    V.serve(~Tag, ~Env, ~dispatch, table, Env{"hi"}, B.config())
    V.serve_with(~Unit, ~Tag, ~Env, ~handler, ~middleware, table, Env{"hi"}, B.config())
```

### `V.serve_limits_with`

```bend signature
def serve_limits_with(~Vars: Data, ~Tag: Data, ~select: Tag -> Maybe<&2, U32>, ~Env: Data, ~dispatch: Tag -> B.Context(Vars) -> Env -> IO(B.Res), ~middleware: Tag -> B.Context(Vars) -> Env -> (B.Context(Vars) -> IO(B.Res)) -> IO(B.Res), table: B.Routes(Tag), env: Env, config: B.ServerConfig) -> IO(Unit)
```

`B.serve_limits_with` with the schema decoder linked in: oversized bodies are
rejected before they are read, and every request is checked against its
route's schemas.

```bend
def ex_serve_validated_limited(table: B.Routes(Tag)) -> IO(Unit):
  V.serve_limits_with(~Unit, ~Tag, ~ex_limit, ~Env, ~handler, ~middleware, table, Env{"hi"}, B.config())
```

### `B.handle`, `B.handle_with`

```bend signature
def handle(~Tag: Data, ~Env: Data, ~dispatch: Tag -> B.Ctx -> Env -> IO(B.Res), table: B.Routes(Tag), env: Env, req: B.Req, body: List<&2, U32>) -> IO(B.Res)
def handle_with(~Vars: Data, ~Tag: Data, ~Env: Data, ~dispatch: Tag -> B.Context(Vars) -> Env -> IO(B.Res), ~middleware: Tag -> B.Context(Vars) -> Env -> (B.Context(Vars) -> IO(B.Res)) -> IO(B.Res), table: B.Routes(Tag), env: Env, req: B.Req, body: List<&2, U32>) -> IO(B.Res)
```

Runs one request through the app without a socket and returns the response,
for tests and embedding. `body` is the request body as octets. Routing,
middleware and hooks run as they do under `B.serve`, with the trie router;
the response has its framing headers and, for HEAD, an empty body. A route
with schemas answers 500 here; `V.handle` validates.

```bend
def ex_in_memory(+table: B.Routes(Tag)) -> IO(B.Res):
  do IO<B.Res>:
    plain : B.Res <- B.handle(~Tag, ~Env, ~dispatch, table, Env{"hi"}, ex_request(), [])
    wrapped : B.Res <- B.handle_with(~Unit, ~Tag, ~Env, ~handler, ~middleware, table, Env{"hi"}, ex_request(), [])
    return wrapped
```

### `V.handle`, `V.handle_with`

```bend signature
import ./bendo/validated.bend as V

def handle(~Tag: Data, ~Env: Data, ~dispatch: Tag -> B.Ctx -> Env -> IO(B.Res), table: B.Routes(Tag), env: Env, req: B.Req, body: List<&2, U32>) -> IO(B.Res)
def handle_with(~Vars: Data, ~Tag: Data, ~Env: Data, ~dispatch: Tag -> B.Context(Vars) -> Env -> IO(B.Res), ~middleware: Tag -> B.Context(Vars) -> Env -> (B.Context(Vars) -> IO(B.Res)) -> IO(B.Res), table: B.Routes(Tag), env: Env, req: B.Req, body: List<&2, U32>) -> IO(B.Res)
```

`B.handle` and `B.handle_with` with validation, for testing an app whose
routes declare schemas. A request that fails its schemas gets the same 400 or
422 it would get from `V.serve`. They always run in development mode.

```bend
def ex_in_memory_validated(+table: B.Routes(Tag)) -> IO(B.Res):
  do IO<B.Res>:
    plain : B.Res <- V.handle(~Tag, ~Env, ~dispatch, table, Env{"hi"}, ex_request(), [])
    wrapped : B.Res <- V.handle_with(~Unit, ~Tag, ~Env, ~handler, ~middleware, table, Env{"hi"}, ex_request(), [])
    return wrapped
```

### `B.show_routes`

```bend signature
def show_routes(-Tag: Data, table: B.Routes(Tag)) -> IO(Unit)
```

Prints one tab-separated `METHOD` and `PATH` line per route, in registration
order. A `B.all` route prints `ALL`. It adds no rows for implicit HEAD,
middleware or hooks. For JSON, run the binary with `--bendo-routes`.

```bend
def ex_print_routes(table: B.Routes(Tag)) -> IO(Unit):
  B.show_routes(Tag, table)
```

## Server config

### `B.ServerConfig`

```bend signature
def ServerConfig() -> Data

type Config is Data:
  Config{host: String, port: U32, body_limit: U32, header_limit: U32, idle_timeout_ms: U32, head_timeout_ms: U32, body_timeout_ms: U32, max_requests: U32, keep_alive: Bool, router: B.RouterKind, mode: Mode, workers: U32}
```

Startup settings for `B.serve` and its variants, defined in
`app/config.bend`. `host` must be an IPv4 literal. `body_limit` and
`header_limit` count bytes, the timeouts are milliseconds, and `max_requests`
caps the requests on one connection. To change a field with no helper here,
import `app/config.bend` and rebuild the record.

```bend
def ex_public(config: B.ServerConfig) -> B.ServerConfig:
  Config.Config{host, port, body, header, idle, head, read, max, keep_alive, router, mode, workers} = config
  Config.Config{"0.0.0.0", 3000, body, header, idle, head, read, max, keep_alive, router, mode, workers}
```

### `B.config`

```bend signature
def config() -> B.ServerConfig
```

The default config: host `127.0.0.1`, port 8787, a 1 MiB body limit, a
64 KiB header limit, 5,000 ms idle, 10,000 ms to read the head and 30,000 ms
to read the body, 100 requests per connection, keep-alive on, the trie
router, development mode and one worker. A decimal `PORT` from 1 to 65535
overrides the port at startup.

```bend
def ex_defaults() -> B.ServerConfig:
  B.config()
```

### `B.RouterKind`, `B.spec`, `B.trie`

```bend signature
def RouterKind() -> Data
def spec() -> B.RouterKind
def trie() -> B.RouterKind
```

Which router resolves requests. `B.trie()` is the default; `B.spec()` is the
simple first-match reference router. Both are proven to return the same
route for every table and path, so the choice affects speed only. Set it in
the config's `router` field. See the [trie router](../../router-trie.md).

```bend
def ex_with_router(config: B.ServerConfig, kind: B.RouterKind) -> B.ServerConfig:
  Config.Config{host, port, body, header, idle, head, read, max, keep_alive, router, mode, workers} = config
  Config.Config{host, port, body, header, idle, head, read, max, keep_alive, kind, mode, workers}

def ex_reference() -> B.ServerConfig:
  ex_with_router(B.config(), B.spec())

def ex_kinds() -> List<&2, B.RouterKind>:
  [B.spec(), B.trie()]
```

### `B.production`

```bend signature
def production(config: B.ServerConfig) -> B.ServerConfig
```

Selects production mode. It changes how a response that breaks its route's
response schema is handled: development answers 500, production logs the
violation to stderr and sends the response unchanged. Setting
`BENDO_ENV=production` at startup does the same. See
[response schemas](../../validation.md#response-schemas).

```bend
def ex_production() -> B.ServerConfig:
  B.production(B.config())
```

### `B.workers`

```bend signature
def workers(config: B.ServerConfig, count: U32) -> B.ServerConfig
```

Sets how many worker processes serve the same port. `0` means one per CPU the
process may run on; the default is 1. Workers share no memory, so each has its
own stores and rate limits. `BENDO_WORKERS` overrides the count at startup,
several workers need a fixed port rather than 0, and a count above 256 stops
startup. See [workers](../../workers.md).

```bend
def ex_workers() -> B.ServerConfig:
  B.workers(B.config(), 4)
```

## Plugins

A plugin is a function from a `B.Builder(Tag)` to a `B.Builder(Tag)` that adds
routes, middleware and hooks. [Write a plugin](../../guides/plugins.md)
explains identity, order and scope.

### `B.Builder`

```bend signature
def Builder(-Tag: Data) -> Data
```

An app being assembled: the registration list so far and the identities of
the named plugins already applied. It is plain data and never reaches the
route table. Plugins take their configuration first and the builder last.

```bend
def greeting(word: String, app: B.Builder(Tag)) -> B.Builder(Tag):
  B.named(Tag, B.plugin_id("greeting"), app, a => B.register(Tag, a, [
    B.get(Tag, "/hello", Hello{}),
    B.before_handle(Tag, Stamp{})]))
```

### `B.app`, `B.app_from`

```bend signature
def app(-Tag: Data) -> B.Builder(Tag)
def app_from(-Tag: Data, entries: List<&2, B.Registration(Tag)>) -> B.Builder(Tag)
```

A builder to start from: empty, or holding an existing registration list. No
plugin identity is applied yet in either.

```bend
def ex_start() -> B.Builder(Tag):
  greeting("hi", B.app_from(Tag, [B.get(Tag, "/", Home{})]))

def ex_empty() -> B.Builder(Tag):
  greeting("hi", B.app(Tag))
```

### `B.register`

```bend signature
def register(-Tag: Data, app: B.Builder(Tag), entries: List<&2, B.Registration(Tag)>) -> B.Builder(Tag)
```

Appends registrations to the end of the builder's list. Registrations keep
their usual meaning: a route registered earlier wins a duplicate path, and a
top-level hook or `B.use` is global.

```bend
def ex_register(app: B.Builder(Tag)) -> B.Builder(Tag):
  B.register(Tag, app, [B.get(Tag, "/health", Home{})])
```

### `B.use_plugin`

```bend signature
def use_plugin(-Tag: Data, app: B.Builder(Tag), plugin: B.Builder(Tag) -> B.Builder(Tag)) -> B.Builder(Tag)
```

Applies `plugin` to `app`. A plugin without a `B.named` identity is applied
on every use, so using it twice registers its entries twice.

```bend
def ex_health(app: B.Builder(Tag)) -> B.Builder(Tag):
  B.register(Tag, app, [B.get(Tag, "/health", Home{})])

def ex_apply() -> B.Builder(Tag):
  B.use_plugin(Tag, B.app(Tag), ex_health)
```

### `B.named`

```bend signature
def named(-Tag: Data, id: B.PluginId, app: B.Builder(Tag), body: B.Builder(Tag) -> B.Builder(Tag)) -> B.Builder(Tag)
```

Runs `body` unless `id` was already applied to this app, and records `id`
before `body` runs. The first use wins with its configuration and scope; a
later use is skipped entirely, including the plugins its body would have
used. Identities are global to the app, so two plugins with the same name and
seed collide.

```bend
def ex_admin(app: B.Builder(Tag)) -> B.Builder(Tag):
  B.named(Tag, B.plugin_id("admin"), app, a => B.register(Tag, greeting("hi", a), [
    B.get(Tag, "/admin", Home{})]))

def ex_once() -> B.Builder(Tag):
  greeting("again", ex_admin(ex_admin(B.app(Tag))))
```

`ex_admin` applies `greeting("hi")` as a dependency. The second `ex_admin`
and `greeting("again")` add nothing, so the app has `/hello` and `/admin`
once each.

### `B.PluginId`, `B.plugin_id`, `B.plugin_seed`

```bend signature
def PluginId() -> Data
def plugin_id(name: String) -> B.PluginId
def plugin_seed(name: String, seed: String) -> B.PluginId
```

A named plugin's identity: a name and a seed. Two identities are equal when
both strings are. `B.plugin_id` uses an empty seed. Put the configuration in
the seed to apply a plugin once per configuration. Give published plugins a
package-qualified name such as `@acme/auth`.

```bend
def ex_tenant(+name: String, app: B.Builder(Tag)) -> B.Builder(Tag):
  B.named(Tag, B.plugin_seed("tenant", name), app, a => B.register(Tag, a, [
    B.get(Tag, "/tenants/" ++ name, Hello{})]))

def ex_ids() -> List<&2, B.PluginId>:
  [B.plugin_id("@acme/auth"), B.plugin_seed("tenant", "one")]
```

### `B.use_route`, `B.use_group`, `B.use_guard`

```bend signature
def use_route(-Tag: Data, app: B.Builder(Tag), prefix: String, body: B.Builder(Tag) -> B.Builder(Tag)) -> B.Builder(Tag)
def use_group(-Tag: Data, app: B.Builder(Tag), prefix: String, hooks: List<&2, B.Hook(Tag)>, body: B.Builder(Tag) -> B.Builder(Tag)) -> B.Builder(Tag)
def use_guard(-Tag: Data, app: B.Builder(Tag), options: B.GuardOptions(Tag), body: B.Builder(Tag) -> B.Builder(Tag)) -> B.Builder(Tag)
```

Run `body` on an empty list that shares the app's plugin identities, then
wrap what it added in `B.route`, `B.group` or `B.guard`. Top-level hooks a
plugin declares inside the body apply only to the routes the body added. A
named plugin first used inside one scope is skipped in every later scope;
give each use its own seed to apply it in several.

```bend
def ex_scoped(app: B.Builder(Tag)) -> B.Builder(Tag):
  B.use_guard(Tag, B.use_group(Tag, B.use_route(Tag, app,
    "/v1", a => greeting("v1", a)),
    "/admin", [B.hook(Tag, Table.BeforeHandle{}, Stamp{})], a => ex_tenant("admin", a)),
    B.guard_options(Tag, [B.hook(Tag, Table.BeforeHandle{}, Stamp{})]), a => ex_tenant("guarded", a))
```

### `B.app_entries`, `B.app_routes`

```bend signature
def app_entries(-Tag: Data, app: B.Builder(Tag)) -> List<&2, B.Registration(Tag)>
def app_routes(-Tag: Data, app: B.Builder(Tag)) -> Result<&2, &2, B.RouteError, B.Routes(Tag)>
```

`B.app_entries` returns the assembled registration list. `B.app_routes` builds
the table from it, exactly as `B.routes` does.

```bend
def ex_assembled() -> List<&2, B.Registration(Tag)>:
  B.app_entries(Tag, ex_start())

def ex_plugin_main() -> IO(Unit):
  ex_ready(B.app_routes(Tag, ex_start()))
```
