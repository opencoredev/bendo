# Import Bend files in a Vite app

`vite-plugin-bendo` lets browser code import a `.bend` file directly. Vite
compiles it with Bend's JavaScript backend when the file is first requested,
reloads it when you edit it, and writes TypeScript declarations beside it. The
compiled module is the same one `bendo build --shared` writes, so the exports,
the value mapping and the purity rule in [shared.md](shared.md) apply unchanged.

```ts
// vite.config.ts
import { defineConfig } from "vite";
import bendo from "vite-plugin-bendo";

export default defineConfig({
  plugins: [bendo()],
});
```

```ts
// src/form.ts
import { check, type Checked } from "../shared/signup.bend";

const result: Checked = check(JSON.stringify(form));
```

The plugin supports Vite 7 and 8 and runs under Node 24 or Bun. It needs
`bend` on `PATH` or in `~/.bend/bin`. The working example is
`packages/vite-plugin-bendo/fixtures/app`: run `bunx vite` there.

## TypeScript

For each imported `x.bend` the plugin writes `x.d.bend.ts` in the same
directory. TypeScript reads that file for `import "./x.bend"` once
`allowArbitraryExtensions` is on:

```json
{
  "compilerOptions": {
    "module": "Preserve",
    "moduleResolution": "bundler",
    "allowArbitraryExtensions": true
  },
  "include": ["src", "shared"]
}
```

The declarations are generated, so ignore them in git with `*.d.bend.ts`. They
are written whenever Vite compiles the file, in `vite` and `vite build`. A fresh checkout has none until then, so run
`vite build` before `tsc` in CI. A file is rewritten only when its text changes.

Pass `declarations: false` to skip them.

## Hot reload

Saving a `.bend` file, or any `.bend`, `.c` or `.js` file it imports, recompiles
that entry and sends Vite an HMR update for it. The plugin records every file
each compile read, so an edit to `shared/rules.bend` updates
`shared/signup.bend`'s importers even though no JavaScript imports `rules.bend`.

The plugin uses Vite's normal update propagation rather than forcing a full
reload. What happens next depends on the importer:

- A module that accepts the `.bend` import keeps its state.
  `import.meta.hot.accept("../shared/signup.bend", (next) => { ... })` receives
  the new exports. The fixture app keeps the typed text and counts the swaps
  this way.
- With React, a component file that imports the `.bend` module is a Fast
  Refresh boundary, so component state survives.
- If no importer accepts the update, Vite reloads the page.

A compiled `.bend` module never accepts itself: its exports are plain values,
and an importer that captured the old functions would keep calling them.

## Compile errors

A failed compile appears in Vite's error overlay with the file, line and
column, Bend's message and its code frame. The file is the one that holds the
error, which may be an import of the file you saved. Bend's diagnostic does not
name the file, so the plugin picks the file in the import graph whose lines
match the code frame.

While a file is broken the page keeps running its last good build; the plugin
sends the error and no update. Reloading the page shows the same error. The
next good save sends an update, which clears the overlay. One exception comes
from Vite's client: if the error was the first HMR event since the page loaded,
the fix reloads the page instead of patching it.

Shared code that returns IO is refused here too, with the overlay pointing at
the offending def.

## Caching and compile load

A compile's result is keyed by a hash of every file it read plus the Bend
version. An unchanged import graph is never recompiled. Results also go to
`<cacheDir>/bendo/<hash>.json` (by default `node_modules/.vite/bendo`), so a
restarted dev server or a second `vite build` reuses them. Pass
`diskCache: false` to keep results in memory only.

Bend compiles can take seconds and gigabytes, so the plugin runs one at a time
by default. Requests for the same graph while it compiles share that compile.
Raise `concurrency` on a machine with memory to spare.

## Options

| Option | Default | Meaning |
| --- | --- | --- |
| `bend` | `bend` on `PATH`, then `~/.bend/bin/bend` | Compiler path |
| `declarations` | `true` | Write `x.d.bend.ts` beside each imported file |
| `concurrency` | `1` | Bend processes allowed at once |
| `diskCache` | `true` | Keep compiled modules in Vite's `cacheDir` |

`?raw` and `?url` imports of a `.bend` file are left to Vite and return the
source text or its URL.
