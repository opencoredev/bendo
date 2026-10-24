---
title: Hooks
description: Elysia-style lifecycle hooks in Bendo, their fixed order, and how they relate to middleware.
---

# Hooks

Some work belongs at a fixed point in a request's life rather than at a place
in the middleware list: decode a custom body before validation, check auth just
before the handler, set a `Content-Type` after it. Bendo has Elysia's lifecycle
hooks for that.

A hook is not a second system. It is a middleware tag registered for a
**stage**, and the same middleware dispatcher runs it:

```python
B.routes(Tag, [
  B.before_handle(Tag, Auth{}),
  B.map_response(Tag, Json{}),
  B.get(Tag, "/account", Show{})])
```

Your middleware dispatcher handles `Auth{}` and `Json{}` with the same
signature as any other middleware, `Tag -> Ctx<Vars> -> Env -> next -> IO(Res)`,
and you serve the app with `B.serve_with`.

## The stages run in a fixed order

Where a hook sits in the route list does not matter. Its stage decides when it
runs, and hooks of the same stage run in registration order. This table comes
from [decision 0010](../decisions/0010-hooks.md):

<!--@include: ../decisions/0010-hooks.md#stage-order-->

Ordinary `B.use` middleware enters after routing, wraps stages 2 to 5, and
unwinds before `after_handle`. [Validation](validation.md) runs between
`on_transform` and `before_handle`, so a `before_handle` hook already sees the
decoded values.

## Pre-stage and response-stage hooks

The four stages before the handler do their work and then call `next`. Any of
them can answer early instead, which skips the stages after it and the handler.
An early answer still passes through the response stages.

The response stages call `next` first to get the response so far, then return
a replacement. Every registered response hook runs, so a `map_response` hook
sees what `after_handle` produced. `on_error` runs only when the response is an
error, status 400 or higher, and `on_after_response` observes the sent
response without changing it.

## Scope a hook to some routes

Registered at the top level, a hook is global. To attach hooks to part of the
app, use `B.group` (a path prefix plus hooks), `B.guard` (hooks for a set of
routes, without a prefix) or `B.route_hooks` (hooks for one route). Within a
stage, global hooks run first, then outer scopes, then the route's own.
[Decision 0011](../decisions/0011-hook-scopes.md) has the API and the rules.

## Guarantees

The middleware laws cover the hook placements, scopes and plugins as well as
plain composition. See the [middleware laws](../laws/middleware.md).

## Read on

- [Middleware](middleware.md) explains the onion that hooks are placed in.
- [Write a plugin](../guides/plugins.md) bundles routes and hooks for reuse.
- [Errors and crashes](../decisions/0011-crash.md) covers typed HTTP errors and what `on_error` can catch.
