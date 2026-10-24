---
title: Middleware
description: Middleware as tags in the route list, the onion order, and the one-shot next continuation.
---

# Middleware

Middleware is code that runs around your handlers: logging, CORS, auth,
headers. In Bendo it follows the same rule as routes. You register a tag in the
route list, and a second dispatcher, your middleware dispatcher, says what that
tag does.

```python
def middleware(id: Tag, c: B.Context(Unit), env: Unit, next: B.Context(Unit) -> IO(B.Res)) -> IO(B.Res):
  match id:
    case Decorate{}:
      do IO<B.Res>:
        res : B.Res <- next(C.header(Unit, c, "x-middleware", "yes"))
        return accepted(res)
    case Hello{}: next(c)

def main() -> IO(Unit):
  ready(B.routes(Tag, [B.use(Tag, Decorate{}), B.get(Tag, "/", Hello{})]))
```

`Decorate{}` sets a response header on the context, calls `next` with it to
run the rest of the app, then changes the returned response's status to 202
with `accepted`. Serve the
app with `B.serve_with`, which takes both dispatchers. The complete program is
on the [middleware page](../middleware.md).

## The onion

Middleware runs in registration order, and the first registered layer is the
outermost. Each layer sees the request on the way in and the response on the
way out:

```text
B.use(A)  B.use(B)  route
A in -> B in -> handler -> B out -> A out
```

`B.use(Tag, id)` applies to every request, including requests for routes
registered before it, and including 404 and 405 answers. `B.use_path(Tag,
pattern, id)` applies only where the pattern matches, using the same
[pattern syntax](routing.md#patterns) as routes.

## `next` runs once

`next` is the rest of the app for this request. A layer may call it once, or
not at all to answer early, for example with a 401. Bend's type checker rejects
a layer that calls `next` twice, so a double dispatch cannot compile.

A layer passes information inward by changing the context it hands to `next`,
for example with [typed variables](context.md#typed-variables). It changes the
outgoing response by transforming what `next` returns. Contexts are immutable,
so an outer layer still holds its own original context.

## Built-in middleware

Bendo ships middleware for CORS, secure headers, logging, request IDs, body
limits, timeouts, ETags, basic and bearer auth, JWT, CSRF, IP restriction and
rate limiting. You wrap `B.Builtin` in a case of your own tag and hand that case
to `B.builtin`. [Middleware](../middleware.md#built-in-middleware) links each
one.

## Guarantees

The middleware laws prove that composition is associative and has an identity,
and that the composed chain runs layers in registration order. They hold for
every middleware function, context and continuation. See the
[middleware laws](../laws/middleware.md).

## Read on

- [Hooks](hooks.md) are middleware placed at fixed lifecycle stages.
- [Middleware](../middleware.md) is the full reference.
- [Write a plugin](../guides/plugins.md) packages routes and middleware for reuse.
