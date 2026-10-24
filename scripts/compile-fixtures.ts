import { copyFileSync, existsSync, mkdirSync } from "node:fs";
import { compile } from "../tests/harness.ts";

// Multipart's typechecking peaks above 6 GiB. Warm it before the test workers
// start so several compilers cannot force it into swap on a cold CI runner.
// Both calls are cheap cache lookups on subsequent runs.
compile("tests/servers/multipart.bend", "native");
compile("tests/fixtures/multipart/consumer.bend", "mjs");
// The WebSocket fixture's typechecking also peaks above the per-worker budget.
compile("tests/servers/websocket.bend", "native");

// Keep measured scheduling data outside tracked files. Seed a fresh checkout
// with the recorded cold-run costs, then let Bun update it after every run.
mkdirSync(".cache", { recursive: true });
if (!existsSync(".cache/test-timings.json")) {
  copyFileSync("scripts/test-timings.json", ".cache/test-timings.json");
}
