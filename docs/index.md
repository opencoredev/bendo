---
layout: home
title: Bendo
titleTemplate: A web framework for Bend, with proofs

hero:
  name: Bendo
  text: A web framework for Bend, with proofs
  tagline: Hono-style routes and middleware, one native binary, and a typed TypeScript client. Parsing, routing and validation carry machine-checked laws.
  actions:
    - theme: brand
      text: Quick start
      link: /getting-started
    - theme: alt
      text: How a request flows
      link: /concepts/
    - theme: alt
      text: Read the laws
      link: /laws/
---

<div class="home-demo">
<div class="home-demo-pane">
<p class="home-demo-label">main.bend</p>

```python
type Tag is Data:
  Hello{}
  Greet{}

def greet(+c: B.Ctx) -> IO(B.Res):
  name = Maybe.default(&2, String, B.param(c, "name"), "stranger")
  IO.pure(B.Res, B.text(c, "Hello, " ++ name ++ "!"))

def main() -> IO(Unit):
  ready(B.routes(Tag, [
    B.get(Tag, "/", Hello{}),
    B.get(Tag, "/hello/:name", Greet{})]))
```

</div>
<div class="home-demo-pane">
<p class="home-demo-label">terminal</p>

```text{8}
$ bendo build
build: dist/server
$ ./dist/server &
bendo listening on http://127.0.0.1:8787
$ curl 127.0.0.1:8787/hello/Ada
Hello, Ada!
$ bun run prove
ALL PROOFS CHECK
```

</div>
</div>

<div class="home-section">

## Start here

| You want to | Read |
| --- | --- |
| Run a server in ten minutes | [Quick start](getting-started.md) |
| Understand routes, context and middleware | [How a request flows](concepts/index.md) |
| Know what is proven, in plain words | [The laws](laws/README.md) |
| Call the server from React with types | [Typed client](client.md) |
| See a whole app | [Examples](examples.md) |

## What the laws promise

A few of the guarantees, each one checked for every input:

- `router_first_match`: when a route matches and none before it does, the
  router returns exactly that route, its tag and its params.
- `trie_route_spec`: the fast trie router returns the same result as the
  simple first-match router, for every table and path.
- `route_admits_iff_slots_decode`: a request passes validation exactly when
  every schema its route declares decodes.
- `request_head_roundtrip`: every well-formed request survives being written
  and parsed again unchanged.

[Proofs](concepts/proofs.md) explains how a law is stated and checked.

</div>
