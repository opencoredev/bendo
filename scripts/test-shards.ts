import { readFileSync } from "node:fs";

// Use committed costs only: restored, partially updated timings must never move
// a file between matrix jobs. Bun can still use its local timings within a job.
export const SHARD_COUNT = 4;
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
    throw new Error("Shard assignment must contain four nonempty shards");
}

export function selectedTestFiles(): string[] {
  const files = testFiles();
  const shards = shardPlan(files);
  guardAssignment(files, shards);
  const value = process.env.BENDO_TEST_SHARD;
  if (value === undefined) return files;
  if (!/^[1-4]$/.test(value)) throw new Error("BENDO_TEST_SHARD must be 1, 2, 3, or 4");
  const selected = shards[Number(value) - 1];
  if (selected === undefined) throw new Error("Missing shard");
  return selected;
}

if (import.meta.main) {
  const files = testFiles();
  const shards = shardPlan(files);
  guardAssignment(files, shards);
  for (const [index, shard] of shards.entries()) {
    console.log(`Shard ${index + 1}: ${shard.length} files\n${shard.join("\n")}\n`);
  }
  console.log(
    `PASS: ${files.length} test files assigned exactly once across ${SHARD_COUNT} shards`,
  );
}
