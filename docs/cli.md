# Develop a Bendo app

Use `bendo new` and `dev` to scaffold and develop a Bend server with Bun.
Use `build` and `start` for a native executable. You need Bun and Bend (the
version in `.bend-version`); native builds also need clang. The CLI
finds Bend on `PATH`, then in `~/.bend/bin`. Run `bendo doctor` to check it.

Until the toolkit is published, run it from a checkout:

```sh
export PATH="$HOME/.bend/bin:$HOME/.elan/bin:$HOME/.bun/bin:$PATH"
bun /path/to/bendo/packages/bendo/src/cli.ts new my-app
cd my-app
bun /path/to/bendo/packages/bendo/src/cli.ts dev
```

The template serves `Hello from Bendo!` at `/` on port 8787. Set `PORT` to use a
different port. It imports only `bendo/main.bend`, the public Bend entrypoint.
`new` copies the framework into the app's `bendo/` directory so the app works
before a BendHub release exists. Keep that directory with your app. The generated
package scripts assume `bendo` is available on `PATH`; the toolkit itself is not
yet available from npm. An existing destination is refused without overwriting it.

## Commands

Every command supports `--help`.

- `bendo new <dir>` creates a minimal app, a package file, and `.gitignore`.
- `bendo dev [entry] [--native]` watches `.bend` files below the current directory
  and resolved local import directories, including targets outside the app reached
  through symlinks. The entry defaults to `main.bend`. By default, Bend emits
  JavaScript and Bun runs it; `--native` compiles a native executable instead.
  Saves are debounced for 100 ms, including atomic editor saves. `.cache`, `dist`, `node_modules`, and `.git` are ignored.
- `bendo build [entry]` builds a native executable at `dist/server`. Run it from
  the app directory. The entry defaults to `main.bend`.
- `bendo start` runs `dist/server` without compiling or requiring Bend. It inherits
  your environment, including `PORT`. Run `build` first.
- `bendo doctor` reports the installed Bend version and path.
- `bendo --version` prints the toolkit version.

`dev` keeps the previous server serving while Bend builds its replacement. A
failed compile prints a `file:line: message` diagnostic without a JavaScript stack
trace; the next good save retries. If the compiler supplies only an excerpt that
matches multiple files, the CLI reports an ambiguous location, lists the candidate
files and retains the excerpt. It does not guess an entry-file line number.

A new save cancels the obsolete compiler process group and starts the latest
revision after the debounce. `SIGINT` and `SIGTERM` stop the server, candidate and
compiler process groups, including native compiler children. A process that
ignores termination is killed after 500 ms. Compilation has a 180-second limit.

The dev loop owns the public loopback port (`PORT`, default 8787) and forwards TCP
connections to the current server. Candidates receive a private `PORT`; apps must
honor it and listen on `127.0.0.1`, as the template does through
`B.config_defaults`. A candidate must accept
TCP connections within ten seconds before it replaces the old server. Failed
startup leaves the old server available. The framework's listening message shows
the candidate's private port; use the public port for requests. On replacement,
existing connections to the old process close, and new connections reach the new
server. `build` and `start` run directly without the dev proxy.

Builds use `.cache/bendo/`, keyed by target, canonical transitive Bend imports,
foreign effects and their C/JS twins, Bend executable/version, native toolchain
versions, platform, and architecture. Canonical paths prevent symlink cycles in
the import scan. Successful outputs are published atomically from immutable
source snapshots. A failed build preserves the last `dist/server`. Delete
`.cache/bendo` to force a fresh compile. Effect changes invalidate the next build;
automatic watching currently triggers on `.bend` saves only.

## Rebuild time

Use the JavaScript default for development. Bend's TCP JavaScript effects use
`bun:ffi`, so this mode requires Bun. Native mode exercises the production runtime
but also pays for C generation and clang on every uncached source revision.
`build` and `start` remain native regardless of the dev mode.

Bend 2.0.38 checks the whole imported program on every compilation. Its `--help`
and guide expose no incremental checker, imported-module cache, or flag that
skips checking unchanged imports. Checking the template alone costs about six
seconds on ms-a2; `--check-only` still traverses the whole framework. Reaching the
two-second fresh-save target requires incremental checking upstream. Cached source
revisions skip compilation, but a fresh save still needs that whole-program check.

`compile: ready` reports compiler time. `restart: launched` includes waiting for
the candidate to listen and stopping the old process. Measure save-to-new-response
time with HTTP against the public port. The following measurements use three
fresh template response edits per mode on 2026-10-23, with Bend 2.0.38. They are
observations, not latency guarantees.

| Host | JavaScript dev median | Native dev median |
| --- | ---: | ---: |
| ms-a2 (shared server) | 5.829 s | 18.564 s |
| Boat large | 11.823 s | 29.363 s |

All sampled requests during those six ms-a2 rebuilds received the old or new
response, with no failures. The remaining delay is compiler work; the old server
continues answering during it.

## Schema generation and future commands

The build pipeline calls the clearly named `generateSchemas` stage before
compilation, including cache hits. There is no production schema generator on this
base revision. BND-34 supplies object/array/optional/union schemas, BND-35 adds
coercion, defaults and error paths, and BND-55 wires the production `gen` command
into this seam. The stage reports that it is pending BND-34/35/55;
it does not run the research generator in `prototypes/0003-typed-values` or claim
to check generated-file freshness. Schema-dependent applications must wait for the
production generator. The integration test checks that this stage precedes
compilation in both `build` and `dev`.

[Decision 0003](decisions/0003-typed-values.md) specifies the implementation this
stage will receive: evaluate schema metadata through `.mjs`, generate named Bend
records and decoders, then compile handlers. Manifest-to-TypeScript generation
(BND-56), `routes`/`prove`/`gen` (BND-55), and `build --shared` (BND-58) are separate
steps. Unsupported options fail explicitly.
