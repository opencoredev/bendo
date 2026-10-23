# Develop a Bendo app

Use `bendo new`, `dev`, `build`, and `start` to scaffold and run a native Bend
server. You need Bun, Bend (the version in `.bend-version`), and clang. The CLI
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
- `bendo dev [entry]` watches `.bend` files below the current directory. The entry
  defaults to `main.bend`. Saves are debounced for 100 ms, including atomic editor
  saves. `.cache`, `dist`, `node_modules`, and `.git` are ignored.
- `bendo build [entry]` builds a native executable at `dist/server`. Run it from
  the app directory. The entry defaults to `main.bend`.
- `bendo start` runs `dist/server` without compiling or requiring Bend. It inherits
  your environment, including `PORT`. Run `build` first.
- `bendo doctor` reports the installed Bend version and path.
- `bendo --version` prints the toolkit version.

`dev` keeps the previous server serving while Bend builds its replacement. A
failed compile prints a `file:line: message` diagnostic without a JavaScript stack
trace; the next good save retries. A save during compilation queues another build.
Only a successful, current build replaces the server. There is a short port handoff
between stopping the old binary and starting the new one. `SIGINT` and `SIGTERM`
stop both the CLI's server and compiler process groups, including native compiler
children. A process that ignores termination is killed after 500 ms. Compilation
has a 180-second limit. An app that fails to start reports its exit and waits for
the next save.

Builds use `.cache/bendo/`, keyed by local transitive Bend imports, foreign effects
and their C/JS twins, Bend executable/version, native toolchain versions, platform,
and architecture. Successful binaries are published atomically. A failed build
preserves the last `dist/server`. Delete `.cache/bendo` to force a fresh compile.
A change in an effect file invalidates the next build's cache; automatic watching
currently triggers on `.bend` saves only. Imports outside the app directory also
invalidate the next build, but are not watched.

Native compilation can exceed two seconds, even for the template. `compile: ready`
reports compiler time; `restart: launched` reports the process handoff time, not HTTP
readiness. Measure the full save-to-response time with an HTTP request against your
app. Cached rebuilds skip native compilation, but a new source version still needs
a native build. The previous server remains available during that work.

A template measurement on 2026-10-23 took 16.780 seconds from save to the new HTTP
response on ms-a2: 16.557 seconds compiling and 1 ms handing off the process. A
Boat large VM took 18.083 seconds: 17.844 seconds compiling and 1 ms handing off.
Restoring a cached source version took 129 ms and 234 ms respectively. The cold
template therefore does **not** meet a two-second save-to-response target. The
HTTP probes received 650 and 697 old-server responses during compilation, with no
failed sampled requests. These are single-run observations, not latency guarantees.

## Schema generation and future commands

The build pipeline calls the clearly named `generateSchemas` stage before
compilation, including cache hits. There is no production schema generator on this
base revision. The stage currently reports that generation is pending BND-33–35;
it does not run the research generator in `prototypes/0003-typed-values` or claim
to check generated-file freshness. Schema-dependent applications must wait for the
production generator. The integration test checks that this stage precedes
compilation in both `build` and `dev`.

[Decision 0003](decisions/0003-typed-values.md) specifies the implementation this
stage will receive: evaluate schema metadata through `.mjs`, generate named Bend
records and decoders, then compile handlers. Manifest-to-TypeScript generation
(BND-56), `routes`/`prove`/`gen` (BND-55), and `build --shared` (BND-58) are separate
steps. Unsupported options fail explicitly.
