import { expect, test } from "bun:test";
import { fuzz } from "../../scripts/fuzz-http.ts";
import type { Mode } from "./broken-server.ts";

// The fuzzer and its oracle must catch each kind of broken server, and must
// still pass one that answers well-framed responses, with or without a reset.
const server = (mode: Mode) => [process.execPath, `${import.meta.dir}/broken-server.ts`, mode];
const run = (mode: Mode) =>
  fuzz({
    seed: 7,
    cases: 40,
    concurrency: 4,
    healthEvery: 1000,
    caseDeadlineMs: 1000,
    startupMs: 5000,
    command: server(mode),
  });

test("a server sending well-framed responses passes, including before a reset", async () => {
  for (const mode of ["valid", "valid-then-reset"] as const) {
    const report = await run(mode);
    expect(report.failure).toBeUndefined();
    expect(report.cases).toBe(40);
    expect(report.outcomes[mode === "valid" ? "eof" : "reset"]).toBeGreaterThan(0);
  }
}, 15_000);

const broken: readonly (readonly [Mode, RegExp])[] = [
  ["hang", /^hang: no EOF within 1000 ms$/],
  ["missing-length", /^ill-framed response: missing Content-Length$/],
  ["extra-bytes", /^ill-framed response: /],
  ["bad-status", /^ill-framed response: invalid status line/],
  ["junk-then-reset", /^ill-framed response before reset: truncated response head$/],
  ["crash", /^server crashed: exit 3|ECONNREFUSED/],
];

for (const [mode, reason] of broken)
  test(`the fuzzer flags the ${mode} server`, async () => {
    const report = await run(mode);
    expect(report.failure?.reason).toMatch(reason);
  }, 10_000);

test("a server that accepts TCP but never answers fails startup within the deadline", async () => {
  const started = Date.now();
  await expect(
    fuzz({ seed: 7, cases: 1, startupMs: 1500, command: server("silent") }),
  ).rejects.toThrow("fuzz server did not answer within 1500 ms");
  expect(Date.now() - started).toBeLessThan(4000);
}, 10_000);
