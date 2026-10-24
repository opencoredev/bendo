---
title: How a request flows
description: The three ideas behind a Bendo app, and the path one request takes through it.
---

# How a request flows

Every Bendo app rests on three ideas. Each one follows from how Bend works, and
together they explain why a Bendo app looks the way it does.

1. **Routes are data.** A route list maps patterns to tags, values of a type
   your app defines. The router returns a tag and the decoded params, never a
   function. [Routing](routing.md) explains why.
2. **The app is a template.** You pass your dispatcher to `B.serve` as
   `~dispatch`. Bend cannot copy a function at run time, so it inlines the
   template at compile time, and it may then run once per request.
3. **State arrives as an argument.** Anything created at startup, such as a
   [store](stores.md) handle or configuration, travels in an `env` value that
   `B.serve` passes to every handler call. There is no global mutable state.

## One request, start to finish

The HTTP shell reads bytes from the socket, frames and buffers the request,
and parses it. Malformed requests get a 400 here and go no further. A parsed
request then passes through these stages. Parsing, routing and validation are
pure functions, which is what the laws are about. Hooks, middleware and
handlers return `IO`, so they can read the clock or update a store:

| Stage | What happens | Concept |
| --- | --- | --- |
| `on_request` hooks | Run before routing and may rewrite the method or path. | [Hooks](hooks.md) |
| Routing | The first registration whose method and pattern match wins. No match gives 404 or 405. | [Routing](routing.md) |
| Middleware | `B.use` and `B.use_path` entries wrap everything below them, outermost first. | [Middleware](middleware.md) |
| `on_parse`, `on_transform` hooks | Decode or prepare values in the context. | [Hooks](hooks.md) |
| Validation | Declared schemas decode params, query, headers and body, or reject with 400, 415 or 422. | [Validation](validation.md) |
| `before_handle` hooks | See the decoded values; may answer early. | [Hooks](hooks.md) |
| Your dispatcher | Matches the tag and builds a response from the [context](context.md). | [Context](context.md) |
| `after_handle`, `map_response`, `on_error` hooks | Change or replace the response on its way out. | [Hooks](hooks.md) |
| Response writer | Sets `Content-Length` or chunked framing and drops the body for HEAD. | |
| `on_after_response` hooks | Observe the response after it is sent. | [Hooks](hooks.md) |

Stages you do not register cost nothing. The app from the
[quick start](../getting-started.md) has no middleware, hooks or schemas, so a
request goes from routing straight to `dispatch`.

## Pure core, thin IO shell

Parsing, routing, middleware composition, JSON and validation are pure Bend
functions. That is what makes them provable: `LAWS.bend` states what they must
do, and `PROOF.bend` proves it. See [proofs](proofs.md).

The accept loop, sockets and timers are IO. They stay in a thin shell that the
integration tests exercise against compiled servers. `B.handle` runs your app
on a request value without opening a socket, so you can test routing and
handlers without a network. [Public entrypoints](../manifest.md#public-entrypoints)
has its signature.

## Read on

- [Routing](routing.md): route lists, tags and the dispatcher.
- [Context](context.md): reading the request and building the response.
- [Proofs](proofs.md): what the laws promise and how to check them.
