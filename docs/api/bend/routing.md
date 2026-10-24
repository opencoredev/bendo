# Routing

A route list is a plain Bend list of registrations: routes, middleware and
lifecycle hooks, each carrying a tag your app defines. `B.routes` builds it
into the table that `B.serve` runs. [Routing](../../concepts/routing.md)
explains tags and first-match order; [App and server](app.md) covers the
types and serving.

Examples on this page are one Bend program and share this setup. Hook stage
constructors such as `Table.BeforeHandle{}` come from `app/table.bend`, and
method constructors such as `Request.Post{}` from `http/request.bend`:

```bend
import Base
import ./bendo/main.bend as B
import ./bendo/router/methods.bend as Methods
import ./bendo/app/table.bend as Table
import ./bendo/http/request.bend as Request

type Tag is Data:
  Home{}
  ListTodos{}
  GetTodo{}
  SaveTodo{}
  Purge{}
  Auth{}
  Log{}
  Missing{}
```

## Register routes

### `B.get`, `B.head`, `B.post`, `B.put`, `B.patch`, `B.delete`, `B.options`, `B.all`

```bend signature
def get(-Tag: Data, path: String, tag: Tag) -> B.Registration(Tag)
def head(-Tag: Data, path: String, tag: Tag) -> B.Registration(Tag)
def post(-Tag: Data, path: String, tag: Tag) -> B.Registration(Tag)
def put(-Tag: Data, path: String, tag: Tag) -> B.Registration(Tag)
def patch(-Tag: Data, path: String, tag: Tag) -> B.Registration(Tag)
def delete(-Tag: Data, path: String, tag: Tag) -> B.Registration(Tag)
def options(-Tag: Data, path: String, tag: Tag) -> B.Registration(Tag)
def all(-Tag: Data, path: String, tag: Tag) -> B.Registration(Tag)
```

Registers `path` for one method, or for every method with `B.all`, including
extension methods. `path` uses the [route pattern](../../router-patterns.md)
syntax and is compiled when the table is built. A GET route also answers HEAD
when no HEAD route matches. OPTIONS gets no automatic answer. A `B.all` route
never adds to a 405's `Allow` header.

```bend
def ex_todo_routes() -> List<&2, B.Registration(Tag)>:
  [
    B.get(Tag, "/todos", ListTodos{}),
    B.get(Tag, "/todos/:id{int}", GetTodo{}),
    B.head(Tag, "/todos/:id{int}", GetTodo{}),
    B.post(Tag, "/todos", SaveTodo{}),
    B.put(Tag, "/todos/:id{int}", SaveTodo{}),
    B.patch(Tag, "/todos/:id{int}", SaveTodo{}),
    B.delete(Tag, "/todos/:id{int}", SaveTodo{}),
    B.options(Tag, "/todos", Home{}),
    B.all(Tag, "/cache/*path", Purge{})
  ]
```

### `B.on`

```bend signature
def on(-Tag: Data, methods: List<&2, Request.Method>, path: String, tag: Tag) -> B.Registration(Tag)
```

Registers `path` for a list of methods. Use the standard constructors or
`Request.Extension{token}`; `Extension{"GET"}` is the same as `Get{}`, but
tokens are case-sensitive, so `Extension{"get"}` is a different method. An
empty, spaced or otherwise invalid token fails `B.routes` with
`Methods.InvalidMethod`. An empty list registers a path that accepts no
method. See [route by HTTP method](../../router-methods.md).

```bend
def ex_on() -> B.Registration(Tag):
  B.on(Tag, [Request.Put{}, Request.Extension{"PURGE"}], "/cache/:key", Purge{})
```

### `B.registration`

```bend signature
def registration(-Tag: Data, entry: Methods.Registration(Tag)) -> B.Registration(Tag)
```

Wraps a low-level `Methods.Registration(Tag)` as a route entry, for code that
builds registrations with `Methods.get` or `Methods.on`.

```bend
def ex_wrapped() -> B.Registration(Tag):
  B.registration(Tag, Methods.get(Tag, "/", Home{}))
```

## Build the table

### `B.routes`

```bend signature
def routes(-Tag: Data, entries: List<&2, B.Registration(Tag)>) -> Result<&2, &2, B.RouteError, B.Routes(Tag)>
```

Compiles every pattern and builds the table, once, at startup. It fails at
the first invalid entry with a `Methods.BuildError` that holds the entry's
index in the flattened list and its source; within a route, methods are
checked before the pattern. Routes are tried in list order and the first
match wins, so put a specific route before a capture that would cover it.

```bend
def ex_build() -> Result<&2, &2, B.RouteError, B.Routes(Tag)>:
  B.routes(Tag, ex_todo_routes())
```

## Middleware and hooks

These entries go in the same list as routes and hold a tag for the app's
middleware dispatcher, which `B.serve_with` takes. A top-level entry applies
to every route, including routes registered before it. Inside `B.group` or
`B.guard`, a hook entry applies only to that scope's routes.

### `B.use`, `B.use_path`

```bend signature
def use(-Tag: Data, id: Tag) -> B.Registration(Tag)
def use_path(-Tag: Data, pattern: String, id: Tag) -> B.Registration(Tag)
```

Ordinary middleware. `B.use` runs for every request, 404 and 405 included.
`B.use_path` runs when the request path, without its query, matches
`pattern`, which uses the route pattern syntax; an invalid pattern fails
`B.routes`. Middleware runs in list order, the first registered outermost,
after routing and around the pre-handler hooks and the handler. See
[middleware](../../middleware.md).

```bend
def ex_middleware() -> List<&2, B.Registration(Tag)>:
  [B.use(Tag, Log{}), B.use_path(Tag, "/admin/*", Auth{}), B.get(Tag, "/admin/stats", Home{})]
```

### `B.on_request`, `B.on_parse`, `B.on_transform`, `B.before_handle`, `B.after_handle`, `B.map_response`, `B.on_error`, `B.on_after_response`

```bend signature
def on_request(-Tag: Data, id: Tag) -> B.Registration(Tag)
def on_parse(-Tag: Data, id: Tag) -> B.Registration(Tag)
def on_transform(-Tag: Data, id: Tag) -> B.Registration(Tag)
def before_handle(-Tag: Data, id: Tag) -> B.Registration(Tag)
def after_handle(-Tag: Data, id: Tag) -> B.Registration(Tag)
def map_response(-Tag: Data, id: Tag) -> B.Registration(Tag)
def on_error(-Tag: Data, id: Tag) -> B.Registration(Tag)
def on_after_response(-Tag: Data, id: Tag) -> B.Registration(Tag)
```

Lifecycle hooks. Each stage runs at a fixed point, whatever its place in the
list, and hooks of one stage run in list order. `on_request` runs before
routing and can rewrite the method or path. The three stages after it and
before the handler can answer early. `after_handle` and `map_response` call
`next` for the response so far and return a replacement; `on_error` does the
same only for a status of 400 or higher; `on_after_response` observes the
sent response. [Hooks](../../concepts/hooks.md) has the stage table.

```bend
def ex_hooks() -> List<&2, B.Registration(Tag)>:
  [
    B.on_request(Tag, Log{}),
    B.on_parse(Tag, Log{}),
    B.on_transform(Tag, Log{}),
    B.before_handle(Tag, Auth{}),
    B.after_handle(Tag, Log{}),
    B.map_response(Tag, Log{}),
    B.on_error(Tag, Log{}),
    B.on_after_response(Tag, Log{}),
    B.get(Tag, "/account", Home{})
  ]
```

### `B.on_not_found`

```bend signature
def on_not_found(-Tag: Data, id: Tag) -> B.Registration(Tag)
```

A handler for requests that match no route. Its middleware call can answer,
or call `next` to reach the next not-found handler and finally the default
404. It does not run for a 405 or for a handler that returns 404. A
not-found handler inside a mounted sub-app does not handle misses under its
prefix; the top-level list owns them. See
[custom not-found handling](../../decisions/0011-crash.md#custom-not-found-handling).

```bend
def ex_not_found() -> List<&2, B.Registration(Tag)>:
  [B.on_not_found(Tag, Missing{}), B.get(Tag, "/", Home{})]
```

## Scopes

### `B.Hook`, `B.hook`

```bend signature
def Hook(-Tag: Data) -> Data
def hook(-Tag: Data, stage: Table.Stage, id: Tag) -> B.Hook(Tag)
```

A hook given as an option to `B.group`, `B.guard_options` or `B.route_hooks`,
rather than as an entry in the list. `stage` is one of `Table.Request{}`,
`Table.Parse{}`, `Table.Transform{}`, `Table.BeforeHandle{}`,
`Table.AfterHandle{}`, `Table.MapResponse{}`, `Table.Error{}` and
`Table.AfterResponse{}`, from `app/table.bend`.

```bend
def ex_auth_hooks() -> List<&2, B.Hook(Tag)>:
  [B.hook(Tag, Table.BeforeHandle{}, Auth{})]
```

### `B.group`

```bend signature
def group(-Tag: Data, prefix: String, hooks: List<&2, B.Hook(Tag)>, entries: List<&2, B.Registration(Tag)>) -> List<&2, B.Registration(Tag)>
```

Prefixes every route in `entries` with `prefix` and attaches `hooks` to those
routes only. `hooks` may be empty. An empty or `/` prefix changes no path;
otherwise one trailing `/` is removed before joining, so a member `/` under
`/api` becomes `/api/`. Prefixes can contain captures. A route outside the
group gets none of its hooks, even under the same path. See
[compose route lists](../../router-compose.md).

```bend
def ex_admin() -> List<&2, B.Registration(Tag)>:
  B.group(Tag, "/admin", ex_auth_hooks(), [
    B.get(Tag, "/stats", Home{}),
    B.delete(Tag, "/todos/:id{int}", SaveTodo{})])
```

### `B.GuardOptions`, `B.guard_options`

```bend signature
def GuardOptions(-Tag: Data) -> Data
def guard_options(-Tag: Data, hooks: List<&2, B.Hook(Tag)>) -> B.GuardOptions(Tag)
```

What a guard attaches to its routes: hooks, and with `B.guard_schemas` route
schemas as well. `B.guard_options` gives hooks only.

```bend
def ex_guard_options() -> B.GuardOptions(Tag):
  B.guard_options(Tag, ex_auth_hooks())
```

### `B.guard`

```bend signature
def guard(-Tag: Data, options: B.GuardOptions(Tag), entries: List<&2, B.Registration(Tag)>) -> List<&2, B.Registration(Tag)>
```

Attaches `options` to every route in `entries` without changing their paths.
Membership follows the route registration that wins, not the request path, so
guarding `GET /items/:id` does not guard `POST /items/:id`.

```bend
def ex_private() -> List<&2, B.Registration(Tag)>:
  B.guard(Tag, ex_guard_options(), [
    B.get(Tag, "/account", Home{}),
    B.get(Tag, "/settings", Home{})])
```

### `B.route_hooks`

```bend signature
def route_hooks(-Tag: Data, registration: Methods.Registration(Tag), hooks: List<&2, B.Hook(Tag)>) -> B.Registration(Tag)
```

Attaches `hooks` to one route, given as a `Methods.Registration`. Within a
stage, global hooks run first, then group and guard hooks from outermost to
innermost, then the route's own. See
[hook scopes](../../decisions/0011-hook-scopes.md).

```bend
def ex_one_route() -> B.Registration(Tag):
  B.route_hooks(Tag, Methods.get(Tag, "/account", Home{}), ex_auth_hooks())
```

### `B.route`, `B.base_path`

```bend signature
def route(-Tag: Data, prefix: String, sub: List<&2, B.Registration(Tag)>) -> List<&2, B.Registration(Tag)>
def base_path(-Tag: Data, prefix: String, entries: List<&2, B.Registration(Tag)>) -> List<&2, B.Registration(Tag)>
```

Mounts a sub-app's registration list under `prefix`; the two are the same
function. Paths join as in `B.group`. Hooks keep their scopes, and a `B.use`
in the sub-app becomes path middleware under the prefix. Sub-apps share the
parent's tag type and dispatchers. Combine lists with `List.concat` before
`B.routes`.

```bend
def ex_items() -> List<&2, B.Registration(Tag)>:
  [B.get(Tag, "/", ListTodos{}), B.get(Tag, "/:id{int}", GetTodo{})]

def ex_mounted() -> List<&2, B.Registration(Tag)>:
  List.concat(&2, B.Registration(Tag), [
    B.route(Tag, "/api/v1/todos", ex_items()),
    B.base_path(Tag, "/v2", ex_admin())])
```

## The method router

`router/methods.bend`, imported as `Methods`, is the router under `B.routes`.
Apps need it for `Methods.BuildError` and for registrations passed to
`B.route_hooks` or `B.registration`; the rest is for code that resolves paths
itself.

### `Methods.BuildError`

```bend signature
type BuildError is Data:
  InvalidPattern{index: Nat, source: String, error: P.PatternError}
  InvalidMethod{index: Nat, source: String, token: String}
```

Why a table build failed, the same type as `B.RouteError`. `index` is the
entry's position in the list, `source` its path pattern, and `token` the
rejected method. `error` is the pattern compiler's reason.

```bend
def ex_explain(e: Methods.BuildError) -> String:
  match e:
    case Methods.InvalidPattern{index, source, error}: "bad pattern " ++ source ++ " at " ++ Nat.show(index)
    case Methods.InvalidMethod{index, source, token}: "bad method " ++ token ++ " for " ++ source
```

### `Methods.get`, `Methods.on`

```bend signature
def get(-T: Data, path: String, tag: T) -> Methods.Registration(T)
def on(-T: Data, methods: List<&2, Request.Method>, path: String, tag: T) -> Methods.Registration(T)
```

A route registration on its own, without the middleware and hook cases of
`B.Registration`. `Methods` also has `head`, `post`, `put`, `patch`,
`delete`, `options` and `all`, with the same arguments. Methods are
normalized and checked when the table is built.

```bend
def ex_low_routes() -> List<&2, Methods.Registration(Tag)>:
  [Methods.get(Tag, "/todos/:id", GetTodo{}), Methods.on(Tag, [Request.Post{}, Request.Put{}], "/todos/:id", SaveTodo{})]
```

### `Methods.build_table`, `Methods.Valid`

```bend signature
def build_table(-T: Data, +entries: List<&2, Methods.Registration(T)>) -> Result<&2, &2, Methods.BuildError, Methods.Valid<T>>

type Valid<-T: Data> is Data:
  Valid{table: Table(T), ok: {TableValid(T, table) == True{} : Bool}}
```

Compiles the registrations into a table, failing at the first invalid one as
`B.routes` does. `Valid<T>` holds the table with a proof that every method in
it is valid, so a table with a bad method token cannot be resolved.

```bend
def ex_low_table() -> Result<&2, &2, Methods.BuildError, Methods.Valid<Tag>>:
  Methods.build_table(Tag, ex_low_routes())
```

### `Methods.defaults`

```bend signature
def defaults() -> Options

type Options is Data:
  Options{strict_trailing_slash: Bool, case_sensitive: Bool}
```

Matching options with both fields `True{}`: `/a` and `/a/` differ, and
static segments compare case-sensitively. These are the options the server
uses. The trie prefilters only under these defaults; other options scan every
route.

```bend
def ex_options() -> Methods.Options:
  Methods.defaults()
```

### `Methods.prepare`, `Methods.resolve_with`

```bend signature
def prepare(-T: Data, +valid: Methods.Valid<T>) -> Index<T>
def resolve_with(-T: Data, kind: B.RouterKind, index: Index<T>, +path: String, +method: Request.Method, +opts: Methods.Options) -> Resolution<T>
```

`Methods.prepare` builds the trie for a validated table, once.
`Methods.resolve_with` resolves a path, without its query, and a method
through `B.trie()` or `B.spec()`. It returns `Found{hit, head_from_get}`,
`MethodNotAllowed{allow}` or `NotFound{}`. The two router kinds are proven to
give the same result. See [router selection](../../router-methods.md#router-selection).

```bend
def ex_resolved(r: Methods.Resolution<Tag>) -> String:
  match r:
    case Methods.Found{hit, head_from_get}: "found"
    case Methods.MethodNotAllowed{allow}: "allow: " ++ Methods.allow_text(allow)
    case Methods.NotFound{}: "not found"

def ex_resolve(valid: Methods.Valid<Tag>) -> String:
  ex_resolved(Methods.resolve_with(Tag, B.trie(), Methods.prepare(Tag, valid), "/todos/7", Request.Get{}, Methods.defaults()))
```
