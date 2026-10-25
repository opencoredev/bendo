---
module: vite-plugin-bendo
---

# vite-plugin-bendo

The Vite plugin that lets browser code import `.bend` files, plus the pieces it
is built from. [Import Bend files in a Vite app](../../vite-plugin.md) covers
the tsconfig, hot reload, compile errors and caching. Apps need only the
default export; the named exports are for tests, tooling and other plugins.

```sh
bun add -d vite-plugin-bendo
```

## The plugin

### `default`

```ts signature
function bendo(options?: BendoPluginOptions): Plugin & { api: BendoApi };
```

Returns the plugin. It runs before Vite's own plugins (`enforce: "pre"`),
resolves `.bend` imports, compiles each with Bend's JavaScript backend on
demand, and writes declarations beside the source. Vite's `configResolved` hook
throws when no `bend` binary is found. Supports Vite 7 and 8, under Node 24 or
Bun.

```ts
// vite.config.ts
import { defineConfig } from "vite";
import bendo from "vite-plugin-bendo";

export default defineConfig({
  plugins: [bendo({ concurrency: 2 })],
});
```

### `BendoPluginOptions`

```ts signature
type BendoPluginOptions = {
  bend?: string;
  declarations?: boolean;
  concurrency?: number;
  diskCache?: boolean;
  compile?: (entry: string, signal: AbortSignal) => Promise<CompiledShared>;
};
```

| Option | Default | Meaning |
| --- | --- | --- |
| `bend` | `bend` on `PATH`, then `~/.bend/bin/bend` | Compiler path |
| `declarations` | `true` | Write `x.d.bend.ts` beside each imported file |
| `concurrency` | `1` | Bend processes allowed at once; one compile can use gigabytes |
| `diskCache` | `true` | Keep compiled modules in `<cacheDir>/bendo` across runs |
| `compile` | Bend | Replaces the compile, for tests |

A `concurrency` that is not a positive integer throws when Vite resolves its
config.

```ts
import { defineConfig } from "vite";
import bendo, { type BendoPluginOptions } from "vite-plugin-bendo";

const options: BendoPluginOptions = {
  bend: "/opt/bend/bin/bend",
  declarations: process.env.CI === undefined,
  diskCache: false,
};
export default defineConfig({ plugins: [bendo(options)] });
```

### `BendoApi`

```ts signature
type BendoApi = {
  watchedFiles(): string[];
};
```

The plugin's `api` property, for tests and debugging. `watchedFiles()` lists
the files outside Vite's root that the plugin's own watcher holds, sorted. It
is empty outside the dev server, and when `server.watch` is `null`.

```ts
import bendo, { type BendoApi } from "vite-plugin-bendo";

const plugin = bendo();
const api: BendoApi = plugin.api;
// Pass `plugin` to Vite's createServer, then after a .bend import from outside the root:
console.log(api.watchedFiles());
```

## Paths

### `bendFile`

```ts signature
function bendFile(id: string): string | undefined;
```

The file path of a Vite module id, or `undefined` when the id is not a Bend
module. An id is one when its path ends in `.bend` and its query asks for no
asset form: `?raw`, `?url`, `?inline`, `?worker` and `?sharedworker` are left
to Vite.

```ts
import { bendFile } from "vite-plugin-bendo";

bendFile("/app/shared/signup.bend?v=3"); // "/app/shared/signup.bend"
bendFile("/app/shared/signup.bend?raw"); // undefined
```

### `resolveBend`

```ts signature
function resolveBend(source: string, importer: string | undefined, root: string): string | undefined;
```

Resolves a `.bend` import to an absolute path with symlinks resolved. A
`./` or `../` import is relative to the importer, or to `root` without one. An
absolute import is tried as a path under `root` first, unless it already names
a file there, then as written. Bare specifiers, missing files and non-Bend ids
give `undefined`, which leaves them to Vite.

```ts
import { resolveBend } from "vite-plugin-bendo";

const root = process.cwd();
const file = resolveBend("../shared/signup.bend", `${root}/src/form.ts`, root);
const rooted = resolveBend("/shared/signup.bend", undefined, root);
```

### `declarationPath`

```ts signature
function declarationPath(file: string): string;
```

Where the plugin writes the declarations for `file`: `x.d.bend.ts` in the same
directory as `x.bend`. TypeScript reads that file for `import "./x.bend"` when
`allowArbitraryExtensions` is on.

```ts
import { declarationPath } from "vite-plugin-bendo";

declarationPath("/app/shared/signup.bend"); // "/app/shared/signup.d.bend.ts"
```

## Compiling

### `Compiler`

```ts signature
class Compiler {
  constructor(options: {
    bend: string;
    cacheDir: string | undefined;
    concurrency: number;
    compile?: (entry: string, signal: AbortSignal) => Promise<CompiledShared>;
  });
  compile(file: string): Promise<Outcome>;
  importersOf(file: string): string[];
  dispose(): Promise<void>;
  readonly disposed: boolean;
  readonly peakConcurrency: number;
  compiles: number;
}
```

Compiles `.bend` entries on demand, one plugin instance's worth. Results are
keyed by a hash of every file in the entry's import graph plus the Bend version,
so an unchanged graph is never recompiled, and with `cacheDir` they persist as
`<hash>.json` files. If a file changes while Bend reads it, the compile is
retried, up to three times. `importersOf` lists the compiled entries whose
graph contains a file. `dispose` kills the running Bend process, cancels queued
compiles and resolves once all have settled. `compiles` counts Bend runs and
`peakConcurrency` the most that ran at once.

```ts
import { Compiler } from "vite-plugin-bendo";

const compiler = new Compiler({ bend: "bend", cacheDir: ".cache/bendo", concurrency: 1 });
const outcome = await compiler.compile("shared/signup.bend");
if (outcome.kind === "compiled") console.log(outcome.compiled.named, outcome.fresh);
console.log(compiler.importersOf("shared/rules.bend"));
await compiler.dispose();
```

### `Outcome`

```ts signature
type Outcome =
  | { kind: "compiled"; compiled: CompiledShared; files: string[]; fresh: boolean }
  | { kind: "failed"; diagnostic: Diagnostic; files: string[] }
  | { kind: "cancelled" };
```

The result of `Compiler.compile`. `files` lists every file the entry's graph
read, including a missing import, which the plugin watches. `fresh` is `true`
only when Bend ran for this call; a result from memory or the disk cache has
`false`. `cancelled` means the compiler was disposed first.
[`CompiledShared`](shared.md#compiledshared) comes from `bendo/shared`.

```ts
import type { Outcome } from "vite-plugin-bendo";

function moduleCode(outcome: Outcome): string {
  switch (outcome.kind) {
    case "compiled":
      return outcome.compiled.module;
    case "failed":
      throw new Error(outcome.diagnostic.message);
    case "cancelled":
      throw new Error("compiler closed");
    default: {
      const exhaustive: never = outcome;
      return exhaustive;
    }
  }
}
```

### `Gate`

```ts signature
class Gate {
  constructor(limit: number);
  run<T>(task: () => Promise<T>): Promise<T>;
  peak: number;
}
```

Runs at most `limit` tasks at once, starting waiting tasks in arrival order.
`peak` is the most that ran together. The constructor throws when `limit` is
not a positive integer. The `Compiler` uses one to cap Bend processes.

```ts
import { Gate } from "vite-plugin-bendo";

const gate = new Gate(2);
const sizes = await Promise.all(
  ["a.bend", "b.bend", "c.bend"].map((file) => gate.run(async () => (await Bun.file(file).text()).length)),
);
console.log(sizes, gate.peak); // peak is at most 2
```

## Diagnostics

### `Diagnostic`, `Place`, `Location`

```ts signature
type Location = { file: string; line: number; column: number };
type Place =
  | { kind: "located"; loc: Location }
  | { kind: "ambiguous"; entry: string; candidates: [string, string, ...string[]] }
  | { kind: "unknown"; entry: string };
type Diagnostic = { message: string; frame: string; place: Place };
```

A compile failure. `message` is Bend's message, `frame` its code frame (empty
when it printed none) and `place` where the error is. `Location` is 1-based.
Bend names no file, so a frame that matches several files of the import graph
is `ambiguous`, with at least two candidates, and one that matches none is
`unknown`; neither guesses a line.

```ts
import type { Diagnostic, Location, Place } from "vite-plugin-bendo";

function where(place: Place): string {
  switch (place.kind) {
    case "located": {
      const loc: Location = place.loc;
      return `${loc.file}:${loc.line}:${loc.column}`;
    }
    case "ambiguous":
      return `one of ${place.candidates.join(", ")}`;
    case "unknown":
      return `somewhere under ${place.entry}`;
    default: {
      const exhaustive: never = place;
      return exhaustive;
    }
  }
}
const printed = (diagnostic: Diagnostic) => `${where(diagnostic.place)}: ${diagnostic.message}`;
```

### `locate`

```ts signature
function locate(output: string, entry: string, files: readonly string[]): Diagnostic;
```

Turns Bend's diagnostic text into a `Diagnostic`. The file is the one among
`files` whose lines match every line of the first code frame, narrowed by the
def name Bend reports for type errors when several match. The message drops
the frame and Bend's `Error:` and `SOME PROOFS FAIL` lines.

```ts
import { BendCompileError, compileShared } from "bendo/shared";
import { locate } from "vite-plugin-bendo";

const entry = `${process.cwd()}/shared/signup.bend`;
try {
  await compileShared(entry, "bend");
} catch (error) {
  if (!(error instanceof BendCompileError)) throw error;
  console.error(locate(error.output, entry, [entry, `${process.cwd()}/shared/rules.bend`]));
}
```

### `overlayError`

```ts signature
function overlayError(diagnostic: Diagnostic): ErrorPayload["err"];
```

The error object Vite's overlay shows: the message, the code frame, and `id`
and `loc` when the place is known. For an ambiguous or unknown place the
message gains a note saying so, listing the candidate files, and `id` is the
entry. Send it with `server.hot.send({ type: "error", err })`.

```ts
import type { ViteDevServer } from "vite";
import { overlayError, type Diagnostic } from "vite-plugin-bendo";

function showError(server: ViteDevServer, diagnostic: Diagnostic): void {
  server.hot.send({ type: "error", err: overlayError(diagnostic) });
}
```
