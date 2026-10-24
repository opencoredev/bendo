import type { parseOha } from "./oha.ts";

type Metrics = ReturnType<typeof parseOha>;
export function distribution(values: number[]) {
  const sorted = [...values].sort((a, b) => a - b);
  const min = sorted[0];
  const max = sorted.at(-1);
  const middle = sorted[Math.floor(sorted.length / 2)];
  if (min === undefined || max === undefined || middle === undefined)
    throw new Error("Cannot summarize empty measurements");
  const median =
    sorted.length % 2 ? middle : ((sorted[sorted.length / 2 - 1] ?? middle) + middle) / 2;
  return { median, min, max };
}
export function summarize(samples: Metrics[]) {
  return {
    requestsPerSecond: distribution(samples.map((s) => s.requestsPerSecond)),
    p50Ms: distribution(samples.map((s) => s.p50Ms)),
    p99Ms: distribution(samples.map((s) => s.p99Ms)),
    errorCount: samples.reduce((sum, s) => sum + s.errorCount, 0),
  };
}
