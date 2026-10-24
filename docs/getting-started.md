---
title: Quick start
description: Install Bun and Bend, create a Bendo app, run it, add a route and build a native binary.
---

# Quick start

By the end of this page you have a Bendo server answering HTTP on your machine,
first in the development loop and then as a native binary. Most of the time
goes into installing Bend.

::: warning Before the first release
Bendo is not on npm or BendHub yet, so this guide runs the `bendo` CLI from a
clone of the repository. [After the first release](#after-the-first-release)
lists what replaces those steps.
:::

## 1. Install the tools

You need git, [Bun](https://bun.sh) and [Bend](https://bend-lang.com) 2.0.38.
Native builds also need clang. The steps below are tested on Ubuntu 24.04 on
x64.

```sh
sudo apt-get install -y git curl unzip build-essential clang
curl -fsSL https://bun.sh/install | bash
mkdir -p ~/.bend
curl -fsSL https://github.com/bendlang/bend/releases/download/v2.0.38/bend-2.0.38-linux-x64.tar.gz \
  | tar -xz -C ~/.bend --strip-components=1
export PATH="$HOME/.bun/bin:$HOME/.bend/bin:$PATH"
bend version
```

`bend version` prints `bend 2.0.38`. Bendo pins that release: `bendo doctor`
reports any other version as a mismatch, and other versions are untested. The
script at bend-lang.com installs the newest release instead, so this page
downloads the pinned one from the
[Bend releases page](https://github.com/bendlang/bend/releases/tag/v2.0.38).

Add the `export PATH=...` line to your shell profile so new terminals find
`bun` and `bend`.

## 2. Get the CLI

Clone Bendo, install its dependencies and point a `bendo` alias at the CLI:

```sh
git clone https://github.com/opencoredev/bendo ~/bendo
(cd ~/bendo && bun install)
alias bendo="bun ~/bendo/packages/bendo/src/cli.ts"
bendo doctor
```

`bendo doctor` prints one line per tool. Bend, clang and Bun must say `OK`.
The elan and Lean lines matter only when you check Bendo's proofs, so a
missing Lean is fine for this guide; doctor still exits nonzero for it.

## 3. Create an app

```sh
cd ~
bendo new my-app
cd my-app
```

`new` prints `Created my-app. Run bendo dev in that directory.` For an app
with typed routes or a React front end, start from
[create-bendo](../packages/create-bendo/README.md) instead. This page stays
with the smallest app.

The app holds:

| File | What it is |
| --- | --- |
| `main.bend` | Your server. |
| `bendo/` | A copy of the Bendo library that `main.bend` imports. Keep it with the app. |
| `.bend-version` | The Bend version the app builds with. |
| `package.json` | `dev`, `build` and `start` scripts that call `bendo`. |
| `.gitignore` | Ignores `.cache/`, `dist/` and `node_modules/`. |

`main.bend` is the whole app:

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

`main` registers one route, `GET /`, under the tag `Hello{}`. `B.routes`
compiles the route list once and returns `Done{table}`, or `Fail{error}` for an
invalid pattern. `B.serve` answers every request by calling `dispatch` with the
matched tag. [Routing](concepts/routing.md) explains why routes carry tags instead
of handler functions.

## 4. Run it

```sh
bendo dev
```

The first compile takes several seconds. When the server is up, the log ends
like this (the private port differs):

```text
compile: ready in 6775ms
bendo listening on http://127.0.0.1:42751
restart: launched pid 3007373 in 43ms
```

Call it from a second terminal on port 8787, which `bendo dev` owns:

```sh
curl -i http://127.0.0.1:8787/
```

```text
HTTP/1.1 200 OK
content-length: 17
date: Sat, 24 Oct 2026 21:16:24 GMT
content-type: text/plain; charset=utf-8

Hello from Bendo!
```

A path with no route, such as `/nope`, answers `404 Not Found`. A `POST /`
answers `405 Method Not Allowed`, because `/` exists for GET only. If port 8787
is taken, run `PORT=3000 bendo dev` and call that port instead.

## 5. Add a route

Leave `bendo dev` running and replace `main.bend` with this version, which adds
`GET /hello/:name`:

```python
import Base
import ./bendo/main.bend as B

type Tag is Data:
  Hello{}
  Greet{}

def hello(c: B.Ctx) -> IO(B.Res):
  IO.pure(B.Res, B.text(c, "Hello from Bendo!"))

def greet(+c: B.Ctx) -> IO(B.Res):
  name = Maybe.default(&2, String, B.param(c, "name"), "stranger")
  IO.pure(B.Res, B.text(c, "Hello, " ++ name ++ "!"))

def dispatch(tag: Tag, ctx: B.Ctx, env: Unit) -> IO(B.Res):
  match tag:
    case Hello{}:
      hello(ctx)
    case Greet{}:
      greet(ctx)

def ready(result: Result<&2, &2, B.RouteError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Done{table}:
      B.serve(~Tag, ~Unit, ~dispatch, table, Unit{}, B.config())
    case Fail{error}:
      IO.die(Unit, 1, "invalid routes")

def main() -> IO(Unit):
  ready(B.routes(Tag, [
    B.get(Tag, "/", Hello{}),
    B.get(Tag, "/hello/:name", Greet{})]))
```

Three things changed: the `Greet{}` tag, its case in `dispatch`, and its
registration in `main`. `greet` reads the `name` capture with `B.param`, which
returns a `Maybe`. The `+` on `+c` lets `greet` use the context twice, once to
read and once to respond.

When you save, the dev loop prints `compile: ready` again and swaps in the new
server. The old one keeps answering while Bend compiles.

```sh
curl http://127.0.0.1:8787/hello/Ada
```

```text
Hello, Ada!
```

::: tip If the compile fails
The dev loop prints the error as `main.bend:line: message` and keeps the last
good server running. Bend only lets `match` look at a function parameter, so
`dispatch` matches `tag` first and leaves the rest to `hello` and `greet`.
:::

## 6. Build a native binary

Stop `bendo dev` with Ctrl-C, then build and start the production server:

```sh
bendo build
bendo start
```

`bendo build` compiles `main.bend` through C with clang and writes
`dist/server`, a single executable of about 3 MB. It takes longer than a dev
compile. `bendo start` runs it on port 8787, or on `$PORT`. You can also run
`./dist/server` directly; it needs neither Bun nor Bend.

The server listens on `127.0.0.1` only. Put Caddy or another reverse proxy in
front of it for TLS and public traffic.

## After the first release

Once Bendo is published, two steps get shorter. Nothing else on this page
changes.

| Now | After the release |
| --- | --- |
| Clone the repo and alias `bendo` (step 2), then `bendo new my-app` | `bun create bendo my-app --template api`, from the `create-bendo` package |
| Run `bendo dev` through the alias | `bun run dev`, because the app's `package.json` scripts call the `bendo` package |

The app will also be able to import Bendo from BendHub (`import bendo@0.1/main.bend as B`)
instead of keeping its own `bendo/` copy.

## Next steps

- [How a request flows](concepts/index.md) walks one request through the concepts.
- [Develop with the CLI](cli.md) covers every `bendo` command.
- The [todo example](examples.md#todo) adds a React app with a typed client.
