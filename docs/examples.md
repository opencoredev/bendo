---
title: Examples
description: Runnable Bendo apps in the repository, simplest first.
---

# Examples

Each example is a runnable app in the repository's `examples/` folder. Run the
commands from the repository root after the [quick start](getting-started.md)
tools are installed.

## Hello

[`examples/hello`](../examples/hello/main.bend) is the smallest app: one
wildcard route that echoes the requested URL.

```sh
bend examples/hello/main.bend -o hello && ./hello
curl http://127.0.0.1:8787/todos/42
```

## Store

[`examples/store`](../examples/store/main.bend) keeps a counter and a todo list
in two [stores](concepts/stores.md) and updates them atomically from handlers.

```sh
bend examples/store/main.bend -o /tmp/bendo-store
PORT=8787 /tmp/bendo-store
```

`POST /counter` returns `1`, then `2`. [Shared state](store.md#reach-stores-from-handlers)
walks through the code.

## Todo

[`examples/todo`](../examples/todo/README.md) is a fullstack app: a Bend API
with validation, a store and CORS, and a React app that uses the
[typed client](client.md), the [TanStack Query helpers](query.md) and the
[shared validators](shared.md). Its README has the run steps and a map of the
files.

## Mandelbrot

[`examples/mandelbrot`](../examples/mandelbrot/README.md) renders the
Mandelbrot set inside a handler, on one core, on every core with Bend's
parallel calls, or on the GPU. The `Server-Timing` header reports how long each
render took.

```sh
bend examples/mandelbrot/main.bend -o mandelbrot
./mandelbrot
```

Open http://127.0.0.1:8787/ to see one image per mode.
