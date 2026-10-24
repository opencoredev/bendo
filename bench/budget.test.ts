import { expect, test } from "bun:test";
import { cpuSplit, parseManifest, schedule, verdict } from "./budget.ts";

const manifest = {
  commit: "0123456789abcdef0123456789abcdef01234567",
  fixture: "bench/servers/hello.bend",
  threshold: 0.75,
  pairs: 3,
  warmupSeconds: 2,
  sampleSeconds: 5,
  connections: 64,
};

test("pairs alternate which server runs first", () => {
  expect(schedule(3)).toEqual([
    ["baseline", "candidate"],
    ["candidate", "baseline"],
    ["baseline", "candidate"],
  ]);
});

test("the gate is the median paired ratio, failing only below the threshold", () => {
  const pairs = (ratios: number[]) => ratios.map((r) => ({ baseline: 1000, candidate: 1000 * r }));
  expect(verdict(pairs([0.5, 1.0, 1.1]), 0.75)).toEqual({
    kind: "pass",
    ratio: 1,
    ratios: [0.5, 1, 1.1],
  });
  expect(verdict(pairs([0.7, 0.74, 1.2]), 0.75).kind).toBe("regressed");
  expect(verdict(pairs([0.75, 0.75, 0.75]), 0.75).kind).toBe("pass");
  expect(() => verdict([], 0.75)).toThrow("empty");
});

test("server and load generator get disjoint CPU sets", () => {
  expect(cpuSplit(4)).toEqual({ server: "0-1", client: "2-3", clientThreads: 2 });
  expect(cpuSplit(2)).toEqual({ server: "0", client: "1", clientThreads: 1 });
  expect(cpuSplit(8)).toEqual({ server: "0-3", client: "4-7", clientThreads: 2 });
  expect(() => cpuSplit(1)).toThrow("two CPUs");
});

test("the manifest is validated at the boundary", () => {
  expect(parseManifest(manifest)).toEqual(manifest);
  expect(() => parseManifest({ ...manifest, commit: "HEAD" })).toThrow("full lowercase SHA");
  expect(() => parseManifest({ ...manifest, threshold: 1 })).toThrow("below 1");
  expect(() => parseManifest({ ...manifest, pairs: 2.5 })).toThrow("integer");
  expect(() => parseManifest([])).toThrow("JSON object");
});
