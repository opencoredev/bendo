# Middleware

Register middleware with `B.use(Tag, id)` or
`B.use_path(Tag, pattern, id)` in the same list as your routes. The identifiers
are application-owned `Data`, resolved by a closed top-level dispatcher.
Middleware runs in registration order; the first registered middleware is the
outermost layer. Entries apply to all matching requests, including routes
registered before them.

Use `B.serve_with` or the network-free `B.handle_with` to supply a middleware
dispatcher and the app's typed `Vars`. Every middleware and handler receives the
same `Context.Ctx<Vars>` type. Use `Unit` when your app needs no variables.
The complete compiled example is
[`tests/servers/middleware.bend`](../tests/servers/middleware.bend).

This minimal application adds a header before the handler and changes its
response status afterward:

```python
import Base
import ../src/main.bend as B
import ../src/app/context.bend as C
import ../src/http/response.bend as Response
import ../src/router/methods.bend as Methods

type Tag is Data:
  Hello{}
  Decorate{}

def handler(tag: Tag, c: B.Context(Unit), env: Unit) -> IO(B.Res):
  IO.pure(B.Res, C.text(Unit, c, "hello"))

def accepted(res: B.Res) -> B.Res:
  Response.Res{code, headers, body, representation} = res
  Response.Res{202, headers, body, representation}

def middleware(id: Tag, c: B.Context(Unit), env: Unit, next: B.Context(Unit) -> IO(B.Res)) -> IO(B.Res):
  match id:
    case Decorate{}:
      do IO<B.Res>:
        res : B.Res <- next(C.header(Unit, c, "x-middleware", "yes"))
        return accepted(res)
    case Hello{}: next(c)

def ready(result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "invalid routes")
    case Done{table}:
      B.serve_with(~Unit, ~Tag, ~Unit, ~handler, ~middleware, table, Unit{}, B.config())

def main() -> IO(Unit):
  ready(B.routes(Tag, [B.use(Tag, Decorate{}), B.get(Tag, "/", Hello{})]))
```

A GET to `/` returns status 202, header `x-middleware: yes`, and body `hello`.

## Context and continuation

The middleware dispatcher has this shape:

```text
Tag -> Ctx<Vars> -> Env -> (Ctx<Vars> -> IO(Res)) -> IO(Res)
```

`next` is an affine function value created for one request. Bend rejects a
middleware that calls it twice, including two sequential calls. A middleware
may omit it and return a response immediately. To change the context for
subsequent layers, pass the changed context to `next`. For example,
`next(C.set(Vars, c, Vars{...}))` passes an app-owned typed record to the handler.
Context changes are immutable; outer layers retain their own original context.
After `next` returns, change the returned `Res` to affect the outgoing response.

The reusable table stores only ordered identifiers and compiled patterns.
It stores no closures. Startup values such as channels travel in `Env`, which
is passed to both dispatchers. Final response validation, framing and HEAD body
suppression happen after the entire onion returns. A post-next transformation
therefore sees the full HEAD representation and can change its length.

## Path matching and errors

`use_path` accepts the same [patterns](router-patterns.md) as routes, including
constrained captures, optional segments and wildcards. Matching uses the request
path without the query, with strict slash and case sensitivity. Middleware
patterns select layers; handler route params remain the params in the context.
Invalid patterns fail `B.routes` atomically with `Methods.InvalidPattern` and
the position in the mixed registration list.

Global middleware runs for 404 and 405 responses. Matching per-path middleware
also runs on those responses and may short-circuit them. A 405 terminal retains
its `Allow` header. Malformed requests rejected by HTTP parsing or query decoding
do not enter middleware.

## Registration types and existing apps

`B.get`, `B.post`, and the other public route helpers now return
`B.Registration(Tag)`, a union of route and middleware entries. Existing
`B.routes(Tag, [B.get(...)])` calls keep working. Explicitly typed app registration
lists should use `List<&2, B.Registration(Tag)>`. Wrap low-level registrations
with `B.route(Tag, Methods.get(...))` before passing them to `B.routes`.
`Methods.Registration(Tag)` itself is unchanged for low-level router consumers.

`B.handle` and `B.serve` keep their existing signatures for apps without
middleware. Switch to `handle_with` or `serve_with` when registering middleware;
the compatibility dispatcher exits with an explanatory error if it encounters a
middleware identifier. Middleware entries are omitted from `--bendo-routes`.

## Laws and verification

`LAWS.bend` contains the BND-22 application, left/right identity, identity
insertion, and associativity laws. They quantify over arbitrary middleware
function values, contexts, continuations and result types. Identity can be
inserted between any aggregate prefix and suffix. Associativity equates
`(a compose b) compose c` with `a compose (b compose c)` at every context and
continuation. The application law fixes the outer-to-inner order.

The laws prove the pure composition primitive used by the chain interpreter.
Its result type is `Type`, admitting both pure results and `IO(Res)`. They do
not assume equality of external effects or prove HTTP selection. Integration
tests exercise selection and execution against compiled native servers.

```sh
bun run prove
bun test --timeout 30000 tests/middleware.test.ts
```

## Lifecycle placements

[Lifecycle hooks](decisions/0010-hooks.md) register stage-tagged middleware ids
with the same dispatcher. Their order is request, parse, transform,
before-handle, handler, after-handle, map-response, conditional error, then
after-response. Only request hooks run before routing; ordinary middleware
still receives route params and now selects paths after request-hook rewrites.
Response hooks run even when pre-stage middleware short-circuits. See the
decision for callback forms, error semantics and the transport boundary.

## Built-in middleware

[Observability middleware](observability.md) provides logger, request ID,
Server-Timing, powered-by and pretty JSON identifiers.
[Authentication middleware](auth.md) provides basic auth, bearer auth, JWT and
CSRF identifiers. Wrap `B.Builtin` in your
app's tag and delegate that case to `B.builtin(Vars, id, c, next)` alongside your
own middleware cases.
