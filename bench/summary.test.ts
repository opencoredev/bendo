import { expect, test } from "bun:test";
import { summarize } from "./summary.ts";
import { parseOha } from "./oha.ts";

test("summaries keep the range and compute each metric's median independently", () => {
  expect(
    summarize([
      { requestsPerSecond: 9, p50Ms: 4, p99Ms: 7, errorCount: 0 },
      { requestsPerSecond: 3, p50Ms: 8, p99Ms: 2, errorCount: 1 },
      { requestsPerSecond: 6, p50Ms: 2, p99Ms: 9, errorCount: 2 },
    ]),
  ).toEqual({
    requestsPerSecond: { median: 6, min: 3, max: 9 },
    p50Ms: { median: 4, min: 2, max: 8 },
    p99Ms: { median: 7, min: 2, max: 9 },
    errorCount: 3,
  });
  expect(() => summarize([])).toThrow("empty");
});

test("oha seconds become milliseconds and transport/non-2xx failures are counted", () => {
  expect(
    parseOha({
      summary: { requestsPerSec: 120 },
      latencyPercentiles: { p50: 0.002, p99: 0.04 },
      errorDistribution: { timeout: 2 },
      statusCodeDistribution: { "200": 99, "503": 3 },
    }),
  ).toEqual({ requestsPerSecond: 120, p50Ms: 2, p99Ms: 40, errorCount: 5 });
});
