import { copyFileSync, existsSync, mkdirSync } from "node:fs";
import { compile } from "../tests/harness.ts";

import { selectedTestFiles } from "./test-shards.ts";

// Only prewarm heavy fixtures used by this shard. All other fixtures compile
// lazily through the harness. Keep these compilers out of the worker pool.
const selected = new Set(selectedTestFiles());
const heavyFixtures = [
  { test: "tests/ws-session.test.ts", entry: "tests/servers/ws-session.bend", target: "native" },
  { test: "tests/websocket.test.ts", entry: "tests/servers/websocket.bend", target: "native" },
  { test: "tests/multipart.test.ts", entry: "tests/servers/multipart.bend", target: "native" },
  {
    test: "tests/multipart.test.ts",
    entry: "tests/fixtures/multipart/consumer.bend",
    target: "mjs",
  },
  {
    test: "tests/mw-observability.test.ts",
    entry: "tests/servers/mw-observability.bend",
    target: "native",
  },
  { test: "tests/errors.test.ts", entry: "tests/servers/errors.bend", target: "native" },
  { test: "tests/stream.test.ts", entry: "tests/servers/stream.bend", target: "native" },
  { test: "tests/mw-cors.test.ts", entry: "tests/servers/mw-cors.bend", target: "native" },
] satisfies { test: string; entry: string; target: Parameters<typeof compile>[1] }[];
for (const fixture of heavyFixtures) {
  if (!selected.has(fixture.test)) continue;
  console.log(`Prewarm: ${fixture.entry} (${fixture.target})`);
  compile(fixture.entry, fixture.target);
}

// Keep measured scheduling data outside tracked files. Seed a fresh checkout
// with the recorded cold-run costs, then let Bun update it after every run.
mkdirSync(".cache", { recursive: true });
if (!existsSync(".cache/test-timings.json")) {
  copyFileSync("scripts/test-timings.json", ".cache/test-timings.json");
}
