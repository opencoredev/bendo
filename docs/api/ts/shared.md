---
module: bendo/shared
---

# bendo/shared

The compiler behind `bendo build --shared` and
[vite-plugin-bendo](vite-plugin.md): it turns a pure Bend file into an ES
module and its TypeScript declarations. [Share Bend code with JavaScript](../../shared.md)
explains the exports, how values cross and what cannot be shared. Most apps
run the command or the plugin and never import this module.

## Compile

### `compileShared`

```ts signature
function compileShared(
  entry: string,
  bend: string,
  options?: CompileOptions,
): Promise<CompiledShared>;
```

Compiles one shared Bend file with the `bend` binary at `bend` and returns the
module and declarations as text. Nothing is written beside the source; Bend's
output goes to a temporary directory that is removed afterwards. It rejects
with a `BendCompileError` when Bend fails, a `SharedIoError` when a def of the
file returns IO, and a plain `Error` when the run is cancelled or times out.
Pass a path from `findBend` in [`bendo`](bendo.md#findbend).

```ts
import { findBend } from "bendo";
import { compileShared } from "bendo/shared";

const bend = findBend();
if (bend.kind === "missing") throw new Error("Install Bend from https://bend-lang.com");
const compiled = await compileShared("shared/signup.bend", bend.path, { timeoutMs: 60_000 });
await Bun.write("web/signup.mjs", compiled.module);
await Bun.write("web/signup.d.mts", compiled.declarations);
for (const warning of compiled.warnings) console.warn(warning);
```

### `buildSharedModule`

```ts signature
function buildSharedModule(entry: string, out: string): Promise<SharedModule>;
```

Compiles one file into `<out>/<name>.mjs` and `<out>/<name>.d.mts`, where
`<name>` is the file name without `.bend`. It finds Bend with `findBend`, so it
runs under Bun only, and throws when Bend is missing. `out` is created if
needed and both files are replaced by rename. A failed compile writes nothing.

```ts
import { buildSharedModule } from "bendo/shared";

const built = await buildSharedModule("shared/signup.bend", "dist/shared");
console.log(built.module, built.named); // ".../dist/shared/signup.mjs" ["check", ...]
```

### `buildShared`

```ts signature
function buildShared(dir: string, out: string): Promise<SharedModule[]>;
```

Runs `buildSharedModule` for every `*.bend` file directly inside `dir`, one at
a time in name order. It throws when `dir` does not exist or holds no `.bend`
files, and stops at the first failed compile. This is
`bendo build --shared [dir] --out <out>`.

```ts
import { buildShared } from "bendo/shared";

const modules = await buildShared("shared", "dist/shared");
console.log(modules.map((module) => module.module));
```

### `CompileOptions`

```ts signature
type CompileOptions = {
  generator?: string;
  signal?: AbortSignal;
  timeoutMs?: number;
  graceMs?: number;
};
```

Options for `compileShared`. `generator` is the tool named in the
declarations' header comment (default `` `bendo build --shared` ``).
Aborting `signal` stops the compile. `timeoutMs` limits one `bend` run (default
180,000). A stopped run gets `SIGTERM`, then `SIGKILL` after `graceMs` (default
2,000), and on POSIX the whole process group Bend started is killed.

```ts
import { compileShared, type CompileOptions } from "bendo/shared";

const controller = new AbortController();
const options: CompileOptions = { generator: "my-build", signal: controller.signal, timeoutMs: 120_000 };
const pending = compileShared("shared/signup.bend", "bend", options);
controller.abort(); // rejects with "shared/signup.bend: compile cancelled"
await pending.catch((error: unknown) => console.error(error));
```

## Results

### `CompiledShared`

```ts signature
type CompiledShared = {
  source: string;
  module: string;
  declarations: string;
  named: string[];
  warnings: string[];
};
```

What `compileShared` returns. `source` is the entry's absolute path, `module`
the `.mjs` text and `declarations` the `.d.mts` text. `named` lists the named
exports: the entry file's own pure defs. `warnings` names files that could not
be parsed for types and defs typed as `unknown`.

```ts
import { compileShared, type CompiledShared } from "bendo/shared";

const compiled: CompiledShared = await compileShared("shared/signup.bend", "bend");
console.log(`${compiled.source}: ${compiled.named.join(", ")}`);
```

### `SharedModule`

```ts signature
type SharedModule = {
  source: string;
  module: string;
  declarations: string;
  named: string[];
  warnings: string[];
};
```

What `buildSharedModule` and `buildShared` return. The fields match
`CompiledShared`, except that `module` and `declarations` are the paths of the
written files, not their text.

```ts
import { buildShared, type SharedModule } from "bendo/shared";

const built: SharedModule[] = await buildShared("shared", "dist/shared");
for (const module of built) console.log(module.declarations);
```

## Errors

### `BendCompileError`

```ts signature
class BendCompileError extends Error {
  readonly entry: string;
  readonly output: string;
  constructor(entry: string, output: string);
}
```

Bend exited with an error. `output` is Bend's diagnostic (its stdout and
stderr, trimmed) and `entry` the absolute path of the file compiled. The
message is `<entry>: Bend compilation failed` followed by the diagnostic.

```ts
import { BendCompileError, compileShared } from "bendo/shared";

try {
  await compileShared("shared/signup.bend", "bend");
} catch (error) {
  if (error instanceof BendCompileError) console.error(error.output);
  else throw error;
}
```

### `SharedIoError`

```ts signature
class SharedIoError extends Error {
  readonly defs: string[];
  constructor(entry: string, defs: string[]);
}
```

A def of the entry file returns `IO`, which shared code cannot run. `defs`
names them, and the message reads
``shared/x.bend: shared code must be pure, but `announce` returns IO``.
[What cannot be shared](../../shared.md#what-cannot-be-shared) explains the
rule.

```ts
import { SharedIoError, compileShared } from "bendo/shared";

const result = await compileShared("shared/signup.bend", "bend").catch((error: unknown) => {
  if (error instanceof SharedIoError) return `move ${error.defs.join(", ")} out of shared code`;
  throw error;
});
```

## Lower-level steps

`compileShared` is these steps in order: compile with Bend's JavaScript
backend, split the output with `parseExportTable`, render `declarations`, and
re-emit the module with `withNamedExports`.

### `ExportEntry`, `ExportTable`

```ts signature
type ExportEntry = { key: string; arity: number; value: string };
type ExportTable = { body: string; entries: ExportEntry[] };
```

Bend's `.mjs` output split in two: `body` is the program and `entries` its
default export table in order. An entry's `key` is a def name for the entry
file, or `<path from the entry's directory>:<name>` for an imported def.
`arity` is the compiled argument count and `value` the expression that builds
the function.

```ts
import { parseExportTable, type ExportEntry, type ExportTable } from "bendo/shared";

const table: ExportTable = parseExportTable(await Bun.file("out/signup.mjs").text());
const own: ExportEntry[] = table.entries.filter((entry) => !entry.key.includes(":"));
console.log(own.map((entry) => `${entry.key}/${entry.arity}`));
```

### `parseExportTable`

```ts signature
function parseExportTable(text: string): ExportTable;
```

Splits the text of a `.mjs` file that `bend file.bend -o file.mjs` wrote. It
throws when the text has no single `export default {` table, the table is not
closed, a row is not in the form Bend emits, or code follows the table.

```ts
import { parseExportTable } from "bendo/shared";

const { entries } = parseExportTable(await Bun.file("out/signup.mjs").text());
console.log(entries.length);
```

### `declarations`

```ts signature
function declarations(
  entry: string,
  table: ExportTable,
  generator?: string,
): { text: string; named: string[]; warnings: string[]; io: string[] };
```

Renders the `.d.mts` for a compiled module from the Bend sources of `entry` and
its imports. `entry` must be the absolute path with symlinks resolved, as
`sourceGraph` keys it; otherwise it throws. `named` lists the defs that get a
named export, `io` the entry's own defs that return `IO`, and `warnings` what
was typed as `unknown`. It does not refuse IO itself; `compileShared` does.

```ts
import { realpathSync } from "node:fs";
import { declarations, parseExportTable } from "bendo/shared";

const entry = realpathSync("shared/signup.bend");
const table = parseExportTable(await Bun.file("out/signup.mjs").text());
const typed = declarations(entry, table, "my-build");
if (typed.io.length > 0) throw new Error(`not pure: ${typed.io.join(", ")}`);
await Bun.write("out/signup.d.mts", typed.text);
```

### `withNamedExports`

```ts signature
function withNamedExports(table: ExportTable, names: readonly string[]): string;
```

Re-emits the module with the same default export plus one named export per
name in `names`, read from the default export by key. Pass
`declarations(...).named`: a name that is not a key exports `undefined`, and
one that is not a JavaScript identifier makes the module invalid.

```ts
import { realpathSync } from "node:fs";
import { declarations, parseExportTable, withNamedExports } from "bendo/shared";

const table = parseExportTable(await Bun.file("out/signup.mjs").text());
const { named } = declarations(realpathSync("shared/signup.bend"), table);
await Bun.write("out/signup.mjs", withNamedExports(table, named));
```

### `sourceGraph`

```ts signature
function sourceGraph(
  entry: string,
  onFile?: (file: string) => void,
): Map<string, Buffer>;
```

Reads `entry` and every file it imports, transitively, keyed by absolute path
with symlinks resolved. Imports of `.c` or `.js` effect files bring in their
twin with the other extension when it exists. `onFile` sees every path reached,
including one that is then missing; a missing file throws. The Vite plugin
hashes this graph to decide when to recompile.

```ts
import { sourceGraph } from "bendo/shared";

const seen: string[] = [];
const graph = sourceGraph("shared/signup.bend", (file) => seen.push(file));
console.log([...graph.keys()].filter((file) => file.endsWith(".bend")));
```
