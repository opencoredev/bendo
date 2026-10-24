---
title: Context
description: The immutable per-request context, how handlers read from it and build responses, and where typed variables fit.
---

# Context

Every handler receives a `B.Ctx` for its request. It holds the parsed request,
the route params, and the response you are building. A handler reads from the
context and finishes by turning it into a `B.Res`.

```python
def greet(+c: B.Ctx) -> B.Res:
  name = Maybe.default(&2, String, B.query(c, "name"), "world")
  B.text(B.header(B.status(c, 201), "x-greeting", "hello"), "Hello, " ++ name)
```

`GET /?name=Ada` gets status 201, the header `x-greeting: hello` and the body
`Hello, Ada`.

## Immutable, one request at a time

A context is a value, not an object you mutate. `B.status` and `B.header`
return a new context with the change, and the old one is untouched. That is
why the example nests the calls: each setter feeds the next, and `B.text`
consumes the result.

Bend values are used once unless marked otherwise. The `+` in `+c` marks the
context as copyable, so `greet` can read the query from `c` and then respond
with it. Without the `+`, Bend rejects the second use.

## Read the request

Accessors return `Maybe` when a value can be absent:

| Accessor | Returns |
| --- | --- |
| `B.param(c, name)` | A decoded route capture |
| `B.query(c, name)` | The first decoded query value |
| `B.request_header(c, name)` | The first header value, matched case-insensitively |
| `B.cookie(c, name)` | The first valid cookie with that name |
| `B.method(c)`, `B.path(c)`, `B.url(c)` | The method, the path, and the path with its query |
| `B.raw_body(c)` | The buffered body bytes |

The request header accessor is `request_header` because `header` sets a
response header, and Bend has no overloading.

## Build the response

A response starts at status 200 with no headers. Setters change it, and a final
helper produces the `B.Res`:

- `B.text`, `B.html` and `B.json` set the body and its `Content-Type`.
- `B.body` sends exact bytes.
- `B.redirect` answers 302 with a `Location`.
- `B.not_found` answers 404.

Invalid output, such as a header value with a newline, fails closed as an
empty 500 instead of reaching the wire. The response writer always owns
`Content-Length` and chunked framing.

## Typed variables

Middleware often computes something the handler needs, such as the current
user. Bendo passes it in typed variables: a record type your app defines,
carried in a `Ctx<Vars>`. `C.set(Vars, c, value)` stores the record and
`C.get(Vars, c)` reads it back as a `Maybe`. There is no string-keyed map, so
Bend checks every field access.

Variables start empty on each request. State that outlives a request, such as
a counter, belongs in a [store](stores.md) that reaches the handler through
`env`.

## Read on

- [Request context](../context.md) is the full reference: every accessor and
  helper, query parsing rules and typed variables.
- [Middleware](middleware.md) shows how a context passes through layers.
- [Cookies](../cookies.md) covers `set_cookie` and signed cookies.
