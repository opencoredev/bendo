import { selectedTestFiles } from "./test-shards.ts";
import { availableParallelism } from "node:os";
import { availableMemory, testWorkers } from "./test-memory.ts";

const serialFiles = [
  "tests/json.test.ts",
  "tests/multipart.test.ts",
  "tests/schema-compound.test.ts",
];
const selected = selectedTestFiles();
const serial = serialFiles.filter((path) => selected.includes(path));
const override = process.env.BENDO_TEST_WORKERS;
const cores = availableParallelism();
// Validate the override before doing any expensive work; sample memory again
// after the large processes exit, immediately before selecting the main pool.
testWorkers({ memory: availableMemory(), cores, override });

async function run(paths: string[], workers: number): Promise<void> {
  if (paths.length === 0) return;
  const child = Bun.spawn(
    [
      process.execPath,
      "test",
      `--parallel=${workers}`,
      "--timeout",
      "30000",
      "--timings=.cache/test-timings.json",
      "--update-timings",
      ...paths,
    ],
    { stdin: "inherit", stdout: "inherit", stderr: "inherit" },
  );
  const code = await child.exited;
  if (code !== 0) process.exit(code);
}

// A fresh process per file releases JSC's allocator as well as its live heap.
// These megabyte traversals must not overlap one another or cold compilers.
for (const path of serial) {
  console.log(`Serial memory slice: ${path}`);
  await run([`./${path}`], 1);
}

const memory = availableMemory();
const workers = testWorkers({ memory, cores, override });
console.log(`Test workers: ${workers} (available memory: ${(memory / 1024 ** 3).toFixed(2)} GiB)`);
// Explicit file paths prevent Bun from discovering files owned by other shards.
await run(
  selected.filter((path) => !serial.includes(path)).map((path) => `./${path}`),
  workers,
);
