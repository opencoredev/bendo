# Write a plugin

A plugin packages routes, middleware and lifecycle hooks so several apps can
share them. In Bendo a plugin is an ordinary Bend function from a
`B.Builder(Tag)` to a `B.Builder(Tag)`. A named plugin applies once per app,
however many times it is used, including through other plugins.

This guide builds a small app with two plugins, applies them, and then
explains identity, order and scope. It assumes you know the
[middleware](../middleware.md) and [hook scope](../decisions/0011-hook-scopes.md)
dispatchers. A larger compiled example that covers every rule below is
[`tests/servers/plugins.bend`](../../tests/servers/plugins.bend).

## What a builder holds

A builder is plain data: the registration list built so far, plus the
identities of the named plugins already applied. A plugin reads and returns it,
so nothing about plugins reaches the route table. `B.app_routes` builds that
table from the entries exactly as `B.routes` does, and the same dispatchers
serve it.

| Function | What it does |
|---|---|
| `B.app(Tag)` | An empty builder. |
| `B.app_from(Tag, entries)` | A builder that starts from an existing registration list. |
| `B.register(Tag, app, entries)` | Appends registrations at the end. |
| `B.use_plugin(Tag, app, plugin)` | Applies `plugin(app)`. Use it for anonymous plugins, which apply every time. |
| `B.named(Tag, id, app, body)` | Applies `body` unless `id` was already applied to this app. |
| `B.plugin_id(name)` | An identity made of the name alone. |
| `B.plugin_seed(name, seed)` | An identity made of a name and a seed string. |
| `B.use_route(Tag, app, prefix, body)` | Runs `body` and mounts its contribution under `prefix`, like `B.route`. |
| `B.use_group(Tag, app, prefix, hooks, body)` | Runs `body` and wraps its contribution in `B.group`. |
| `B.use_guard(Tag, app, options, body)` | Runs `body` and wraps its contribution in `B.guard`. |
| `B.app_entries(Tag, app)` | The assembled registration list. |
| `B.app_routes(Tag, app)` | `B.routes` over the assembled list. |

## Write and apply plugins

This complete program lives at
[`tests/servers/plugins-guide.bend`](../../tests/servers/plugins-guide.bend),
which imports from `../../src/`. From an app one level below the repo root,
import `../src/main.bend` as shown here.

```python
import Base
import ../src/main.bend as B
import ../src/app/context.bend as C
import ../src/router/methods.bend as M

type Tag is Data:
  Home{}
  Say{word: String}
  Stamp{name: String, value: String}

def handler(tag: Tag, c: B.Context(Unit), env: Unit) -> IO(B.Res):
  match tag:
    case Say{word}: IO.pure(B.Res, C.text(Unit, c, word))
    case _: IO.pure(B.Res, C.text(Unit, c, "home"))

def middleware(tag: Tag, c: B.Context(Unit), env: Unit, next: B.Context(Unit) -> IO(B.Res)) -> IO(B.Res):
  match tag:
    case Stamp{name, value}: next(C.header(Unit, c, name, value))
    case _: next(c)

# A configurable named plugin: a route and a global before-handle hook.
def greeting(word: String, app: B.Builder(Tag)) -> B.Builder(Tag):
  B.named(Tag, B.plugin_id("greeting"), app, a => B.register(Tag, a, [
    B.get(Tag, "/hello", Say{word}),
    B.before_handle(Tag, Stamp{"x-greeting", "yes"})]))

# A named plugin that depends on greeting and adds middleware.
def health(app: B.Builder(Tag)) -> B.Builder(Tag):
  B.named(Tag, B.plugin_id("health"), app, a => B.register(Tag, greeting("hi", a), [
    B.get(Tag, "/health", Say{"ok"}),
    B.use(Tag, Stamp{"x-health", "yes"})]))

def assembled() -> B.Builder(Tag):
  greeting("again", B.use_plugin(Tag, B.use_plugin(Tag, B.app_from(Tag, [B.get(Tag, "/", Home{})]), health), health))

def ready(result: Result<&2, &2, M.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "invalid routes")
    case Done{table}:
      B.serve_with(~Unit, ~Tag, ~Unit, ~handler, ~middleware, table, Unit{}, B.config())

def main() -> IO(Unit):
  ready(B.app_routes(Tag, assembled()))
```

Each plugin is a top-level def that takes its configuration first and the
builder last. `B.named` wraps the body, a function that receives the builder
with the plugin's identity already recorded. The body adds the plugin's own
entries with `B.register`, and depends on another plugin by calling it, as
`health` calls `greeting("hi", a)`.

Bend has no method chaining, so plugin calls nest and the innermost applies
first. `assembled` starts from a builder holding `/`, applies `health` twice
through `B.use_plugin`, then applies `greeting("again")`:

- The first `health` applies `greeting("hi")`, then registers `/health` and the
  `x-health` middleware.
- The second `health` finds `"health"` already applied and adds nothing.
- `greeting("again")` finds `"greeting"` already applied and adds nothing.

The routes are `/`, `/hello` and `/health`, once each. `/hello` answers `hi`.
Every route gets the `x-greeting` and `x-health` headers, because both
plugins were used at the top level, so their hook and middleware are global.

Bend functions can be called only once, so `B.named` either runs a body once or
drops it. `B.app_routes` builds the table from the assembled entries exactly as
`B.routes` does.

## Identity and configuration

An identity is a name and a seed, and two identities are equal when both
strings are equal. `B.plugin_id(name)` uses an empty seed. The first use of an
identity wins, along with its configuration and the scope it was used in. Any
later use is skipped entirely: its body never runs, so plugins it would have
used are not reserved either.

Identities are global to the app, so two unrelated plugins that pick the same
name and seed collide: the second one is silently dropped, routes and hooks
included. Give published plugins a package-qualified name, such as
`@acme/auth`, and keep short names like `health` for plugins private to one
app.

To apply the same plugin once per configuration, put the configuration in the
seed. This is the role of `seed` in Elysia. Added to the program above, this
plugin reuses its `Say` tag (the larger example's `plugin_seeded` has the same
shape):

```python
def tenant(+name: String, app: B.Builder(Tag)) -> B.Builder(Tag):
  B.named(Tag, B.plugin_seed("tenant", name), app, a => B.register(Tag, a, [
    B.get(Tag, "/tenants/" ++ name, Say{name})]))
```

`tenant("one", tenant("two", tenant("one", app)))` registers `/tenants/one` and
`/tenants/two`, once each.

The identity is recorded before the body runs, so a plugin that uses itself
inside its own body skips the inner use. Anonymous plugins have no identity and
apply on every use: two `B.use_plugin` calls with the same function register
its entries twice.

Each builder value has its own identity set. Building a sub-app as a separate
builder and mounting its `B.app_entries` with `B.route` shares nothing. Use
`B.use_route` instead when nested plugins should share identities with the app.

## Order

A plugin's entries are appended where the plugin is first used, in the order
its body produces them. A plugin used inside another plugin's body sits at that
position inside the outer plugin's contribution. Everything after that follows
the existing rules for a registration list:

- Routes keep first-match priority in final list order, so an earlier plugin's
  route wins over a later duplicate.
- Middleware registered with `B.use` runs in final list order, outermost first.
- Within each lifecycle stage, global hooks run in final list order, then
  inherited group and guard hooks, then route-local hooks. Response hooks use
  the same order.

## Scope

Where a plugin's hooks apply depends on where the plugin is used, not on a mode
flag:

- **Used at the top level of the app.** Its top-level `B.on_*` hooks and `B.use`
  middleware are global. They apply to every route, including routes registered
  before the plugin. This matches Elysia's `global`.
- **Used inside `B.use_group` or `B.use_guard`.** Its top-level hook declarations
  become that scope's inherited hooks. They apply to every route in the scope's
  contribution and to no route outside it. This is how Elysia's `scoped` hooks
  reach the instance that uses the plugin.
- **Used inside `B.use_route`.** The contribution is mounted. Ordinary `B.use`
  middleware becomes path middleware under the prefix, as in any
  [mount](../router-compose.md), and hook declarations become group hooks.
- **Hooks for the plugin's own routes only.** Wrap those routes in `B.guard`,
  `B.group` or `B.route_hooks` inside the plugin's body. This matches Elysia's
  default `local`.

A scope combinator runs its body on an empty registration list with the app's
shared identities. It applies its prefix or hooks once, after the body returns,
to exactly what the body added. Identities applied inside the scope then count
for the rest of the app.

So a named plugin used under `/a` and then under `/b` registers its routes and
hooks under `/a` only. The `/b` scope gets nothing from it, and its own routes
do not inherit the plugin's hooks. To mount a plugin in both places, give each
use its own seed. In this example `scoped` is a named plugin that registers
`/thing` and a top-level before-handle hook:

```python
def scopes(app: B.Builder(Tag)) -> B.Builder(Tag):
  B.use_group(Tag, B.use_group(Tag, app,
    "/a", [], a => scoped(B.register(Tag, a, [B.get(Tag, "/other", Handler{})]))),
    "/b", [], b => scoped(B.register(Tag, b, [B.get(Tag, "/sibling", Handler{})])))
```

Here `/a/thing` and `/a/other` run `scoped`'s hook. `/b/thing` is a 404, and
`/b/sibling` runs only the app's global hooks.

## Compared with Elysia and Hono

| | Elysia | Hono | Bendo |
|---|---|---|---|
| Plugin shape | An instance or `(app) => app` | A sub-app passed to `app.route` | A function from builder to builder |
| Deduplication | `name`, with an optional `seed` | None | `B.named` with a name and an optional seed |
| Hook reach | `as: 'local' \| 'scoped' \| 'global'` | Middleware by path | Where the plugin is used: top level, `use_group`/`use_guard`, or `use_route` |

## Guarantees

The laws in [`proof/plugin-laws.bend`](../../proof/plugin-laws.bend) describe
plugin programs as data: added entries, anonymous or named plugins, and
mount, group or guard scopes, nested to any depth. An interpreter runs each
program through the public combinators. The laws compare the result against an
independent specification that decides membership itself and uses the source
specifications of mount, group and guard:

- `plugin_first_use_assembly`: for every program and starting builder, the
  result equals the first-use assembly. That covers the identities and every
  entry, with its order, duplicates, prefixes and hook provenance.
- `plugin_named_repeat`: a second use of an identity changes nothing, whatever
  its body and whatever the first body did.
- `plugin_anonymous_flatten`: without identities, plugins compose as plain list
  concatenation, with each scope applied to its own body.

The laws cover plugins built from these combinators. A hand-written function
that rebuilds a `Builder` record directly can drop identities, so the guarantee
does not extend to it. Route and hook behavior after assembly follows from the
existing table, composition and scope laws.

Run the HTTP tests with:

```sh
bun test --timeout 30000 tests/plugins.test.ts
```
