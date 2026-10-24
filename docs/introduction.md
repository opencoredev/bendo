---
title: Introduction
description: What Bendo is, what it gives you, and what it leaves out.
---

# Introduction

Bendo is a web framework for the [Bend](https://bend-lang.com) language, shaped
like [Hono](https://hono.dev), with a TypeScript toolkit for calling a Bendo
server from a React app with full types.

- Start a server in a few minutes with the [quick start](getting-started.md).
- Learn the model behind it in [how a request flows](concepts/index.md).
- See a full app in the [todo example](examples.md#todo).

## What it gives you

- **One native binary.** Bend compiles the server through C into a single
  executable. It needs neither Bun nor Bend at run time.
- **Proofs for the core.** Request parsing, routing, middleware composition,
  JSON and validation are pure Bend functions. Their guarantees are written
  down as laws and checked by Bend's Lean-backed proof kernel. See
  [proofs](concepts/proofs.md).
- **One validator, two places.** A route's schemas decode requests on the
  server, and the same Bend code compiles to JavaScript so a browser can run it
  before sending. See [validation](concepts/validation.md).
- **Types without writing them twice.** A compiled app prints its routes and
  schemas, and `bendo gen` turns them into TypeScript types for the
  [typed client](client.md).
- **Every core.** A handler can spread work across CPU cores with Bend's
  parallel calls, and the server can run one worker process per core. See
  [workers](workers.md).

## What it looks like

A Bendo app is a list of routes and a function that answers them:

```python
import Base
import ./bendo/main.bend as B

type Tag is Data:
  Hello{}

def dispatch(tag: Tag, ctx: B.Ctx, env: Unit) -> IO(B.Res):
  IO.pure(B.Res, B.text(ctx, "Hello from Bendo!"))

def ready(result: Result<&2, &2, B.RouteError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Done{table}:
      B.serve(~Tag, ~Unit, ~dispatch, table, Unit{}, B.config())
    case Fail{error}:
      IO.die(Unit, 1, "invalid routes")

def main() -> IO(Unit):
  ready(B.routes(Tag, [B.get(Tag, "/", Hello{})]))
```

This is the app `bendo new` creates. It answers `GET /` with
`Hello from Bendo!` on port 8787.

## Packages

| Package | What it gives you |
| --- | --- |
| `bendo/main.bend` (Bend) | The framework: routing, context, middleware, hooks, validation, stores, streaming and WebSockets. |
| `bendo` (npm) | The `bendo` CLI, the [typed client](client.md), [TanStack Query helpers](query.md) and [shared validators](shared.md). |
| `vite-plugin-bendo` (npm) | [Import `.bend` files](vite-plugin.md) from a Vite app. |

None of these is published yet. The [quick start](getting-started.md#after-the-first-release)
says how to use them from a clone until they are.

## Scope

Bendo is pre-alpha. APIs still change between commits.

It serves HTTP/1.1 on `127.0.0.1` and leaves TLS, HTTP/2 and HTTP/3 to a
reverse proxy such as Caddy or Cloudflare. It runs as a native process only:
there are no adapters for Cloudflare Workers, Deno or AWS Lambda.

The laws cover pure code. The parts that do IO (the accept loop, sockets,
timers) are tested against compiled servers instead of proven.
[What the laws do not cover](laws/README.md#what-the-laws-do-not-cover) lists
the gaps.

## Next steps

- [Quick start](getting-started.md)
- [How a request flows](concepts/index.md)
- [Examples](examples.md)
