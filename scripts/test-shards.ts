import { readFileSync } from "node:fs";

// Use committed costs only: restored, partially updated timings must never move
// a file between matrix jobs. Bun can still use its local timings within a job.
// Six shards keep a cold run (fixture cache invalidated) inside test:ci's
// 20-minute budget on GitHub's runners; four came within minutes of it (BND-102).
export const SHARD_COUNT = 6;
const roots = [
  "tests",
  "bench",
  "packages/bendo",
  "packages/vite-plugin-bendo",
  "packages/create-bendo",
];

export function testFiles(): string[] {
  return roots
    .flatMap((root) =>
      Array.from(
        new Bun.Glob("**/*.{js,jsx,ts,tsx}").scanSync({ cwd: root }),
        (path) => `${root}/${path}`,
      ),
    )
    .filter(
      (path) => !path.split("/").includes("node_modules") && /[._](test|spec)\.[jt]sx?$/.test(path),
    )
    .sort();
}

function timingCosts(): Map<string, number> {
  const data: unknown = JSON.parse(readFileSync("scripts/test-timings.json", "utf8"));
  if (typeof data !== "object" || data === null || !("files" in data))
    throw new Error("Invalid committed test timings");
  const files = data.files;
  if (typeof files !== "object" || files === null) throw new Error("Invalid timing files");
  return new Map(
    Object.entries(files).map(([path, cost]) => {
      if (typeof cost !== "number" || !Number.isFinite(cost) || cost <= 0)
        throw new Error(`Invalid timing for ${path}`);
      return [path, cost];
    }),
  );
}

/** A file's committed cost in milliseconds, or 90 s for one not yet measured. */
export function estimatedCost(path: string): number {
  return timingCosts().get(path) ?? 90_000;
}

export function shardPlan(files = testFiles()): string[][] {
  const costs = timingCosts();
  const cost = (path: string) => costs.get(path) ?? 90_000;
  const shards = Array.from({ length: SHARD_COUNT }, () => ({
    files: new Array<string>(),
    cost: 0,
  }));
  for (const path of [...files].sort((a, b) => cost(b) - cost(a) || a.localeCompare(b))) {
    // Stable ties go to the lowest shard ID.
    const shard = shards.reduce((best, next) => (next.cost < best.cost ? next : best));
    shard.files.push(path);
    shard.cost += cost(path);
  }
  return shards.map((shard) => shard.files.sort());
}

export function guardAssignment(files: string[], shards: string[][]): void {
  const assigned = shards.flat();
  const expected = new Set(files);
  if (
    expected.size !== files.length ||
    assigned.length !== files.length ||
    new Set(assigned).size !== assigned.length ||
    assigned.some((path) => !expected.has(path))
  ) {
    throw new Error("Shard assignment has missing, duplicate, or unknown test files");
  }
  if (shards.length !== SHARD_COUNT || shards.some((shard) => shard.length === 0))
    throw new Error(`Shard assignment must contain ${SHARD_COUNT} nonempty shards`);
}

export function selectedTestFiles(): string[] {
  const files = testFiles();
  const shards = shardPlan(files);
  guardAssignment(files, shards);
  const value = process.env.BENDO_TEST_SHARD;
  if (value === undefined) return files;
  const index = /^[0-9]+$/.test(value) ? Number(value) : 0;
  if (index < 1 || index > SHARD_COUNT)
    throw new Error(`BENDO_TEST_SHARD must be a number from 1 to ${SHARD_COUNT}`);
  const selected = shards[index - 1];
  if (selected === undefined) throw new Error("Missing shard");
  return selected;
}

if (import.meta.main) {
  const files = testFiles();
  const shards = shardPlan(files);
  guardAssignment(files, shards);
  for (const [index, shard] of shards.entries()) {
    const seconds = Math.round(shard.reduce((sum, path) => sum + estimatedCost(path), 0) / 1000);
    console.log(
      `Shard ${index + 1}: ${shard.length} files, about ${seconds} s estimated\n${shard.join("\n")}\n`,
    );
  }
  console.log(
    `PASS: ${files.length} test files assigned exactly once across ${SHARD_COUNT} shards`,
  );
}
