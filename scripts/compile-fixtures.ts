import { copyFileSync, existsSync, mkdirSync } from "node:fs";
import { compile } from "../tests/harness.ts";

// Multipart's typechecking peaks above 6 GiB. Warm it before the test workers
// start so several compilers cannot force it into swap on a cold CI runner.
// These calls are cheap cache lookups on subsequent runs.
// Keep this phase serial. run-tests.ts also budgets the workers because other
// fixtures (including generated ones) compile inside the test processes.
compile("tests/servers/multipart.bend", "native");
compile("tests/fixtures/multipart/consumer.bend", "mjs");
// Observability peaks above 3 GiB. Keep it out of the
// smaller workers' budget too, using the same cache entry as its test.
compile("tests/servers/mw-observability.bend", "native");
// Errors reached 5.28 GiB in a cold worker, despite lower peaks in other runs.
// Prewarm its exact native cache entry rather than budgeting for the average.
compile("tests/servers/errors.bend", "native");
// Stream reached 2.08 GiB, above the remaining workers' compiler allowance.
compile("tests/servers/stream.bend", "native");

// Keep measured scheduling data outside tracked files. Seed a fresh checkout
// with the recorded cold-run costs, then let Bun update it after every run.
mkdirSync(".cache", { recursive: true });
if (!existsSync(".cache/test-timings.json")) {
  copyFileSync("scripts/test-timings.json", ".cache/test-timings.json");
}
