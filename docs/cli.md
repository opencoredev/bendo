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
- `bendo routes [entry]` builds the app if needed, runs it with `--bendo-routes`,
  validates its versioned JSON envelope, and prints a method/path table. The entry
  defaults to `main.bend`. It reuses the `build` cache without publishing `dist/server`.
- `bendo prove [file]` runs `bend <file> --verdict`, defaulting to `PROOF.bend`.
  It prints `ALL PROOFS CHECK` on success, preserves Bend's failure exit code,
  and shows law diagnostics and source locations without JavaScript stack traces.
  Proof checks have a ten-minute limit.
- `bendo gen [entry]` uses the same cached build and manifest validation as `routes`.
  It reports the number of routes. Type generation lands in BND-56; this command
  currently writes no type files or placeholders.
- `bendo doctor` checks Bend, elan, Lean, clang, and Bun, printing versions and
  paths. Bend must match `.bend-version`; Lean must match `lean-toolchain`. A
  versioned pin (`leanprover/lean4:v4.34.0`, `v4.34.0`) is compared with the
  version Lean reports; a channel (`nightly`) or custom/linked toolchain only has
  to be installed. Doctor reads the installed toolchain directly, so it never
  downloads one.
  Pins come from the current directory when present, otherwise the toolkit checkout.
  Lean is selected explicitly from that pin, so no global elan default is needed.
  Lean is selected explicitly from that pin, so no global elan default is needed.
  Missing tools, failed version probes, and mismatches return a nonzero exit code
  with installation commands from the agent guide. Add `~/.bend/bin`, `~/.elan/bin`,
  and `~/.bun/bin` to `PATH`. Version probes have five-second limits.
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

## Generation stages

The build pipeline calls `generateSchemas` before compilation, including cache
hits. Its precompile phase reports that production schema generation is pending
BND-34/35. It does not run the research generator in `prototypes/0003-typed-values`
or check generated-file freshness. Schema-dependent applications must wait for
the production generator.

`gen` builds the app, then calls the manifest phase of that same seam. A manifest
requires an executable, so this phase runs after compilation. Both `routes` and
`gen` require `{ "bendo": 1, "routes": [...] }` with a method and absolute path
for every route. Invalid JSON, unsupported versions, and malformed routes fail
with a readable error. Manifest export has a ten-second limit and an 8 MiB output
limit. The app must exit without starting a server when passed `--bendo-routes`.

[Decision 0003](decisions/0003-typed-values.md) specifies the precompile stage:
evaluate schema metadata through `.mjs`, generate named Bend records and
decoders, then compile handlers. BND-56 will use the validated manifest to write
TypeScript route types. `build --shared` remains a separate step (BND-58).
Unsupported options fail explicitly.

Run the CLI integration tests with `bun test packages/bendo --timeout 30000`
from the repository root. The ticket's `packages/bendo/cli` path corresponds to
`packages/bendo/src/*test.ts` in this checkout.
