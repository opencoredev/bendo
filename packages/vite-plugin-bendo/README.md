# vite-plugin-bendo

Import `.bend` files from a Vite app. Each import compiles with Bend's
JavaScript backend on demand, reloads when you save it or anything it imports,
shows compile errors in Vite's overlay and writes `x.d.bend.ts` declarations
beside the source.

```ts
import { defineConfig } from "vite";
import bendo from "vite-plugin-bendo";

export default defineConfig({ plugins: [bendo()] });
```

See [docs/vite-plugin.md](../../docs/vite-plugin.md) for the tsconfig, the hot
reload rules, caching and options. `fixtures/app` is a working example.
