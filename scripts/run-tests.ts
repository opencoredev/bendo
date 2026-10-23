import { availableParallelism } from "node:os";
import { availableMemory, testWorkers } from "./test-memory.ts";

const serialFiles = [
  "tests/json.test.ts",
  "tests/multipart.test.ts",
  "tests/schema-compound.test.ts",
];
const override = process.env.BENDO_TEST_WORKERS;
const cores = availableParallelism();
// Validate the override before doing any expensive work; sample memory again
// after the large processes exit, immediately before selecting the main pool.
testWorkers({ memory: availableMemory(), cores, override });

async function run(paths: string[], workers: number, ignored: string[] = []): Promise<void> {
  const child = Bun.spawn(
    [
      process.execPath,
      "test",
      `--parallel=${workers}`,
      "--timeout",
      "30000",
      "--timings=.cache/test-timings.json",
      "--update-timings",
      ...ignored.map((path) => `--path-ignore-patterns=${path}`),
      ...paths,
    ],
    { stdin: "inherit", stdout: "inherit", stderr: "inherit" },
  );
  const code = await child.exited;
  if (code !== 0) process.exit(code);
}

// A fresh process per file releases JSC's allocator as well as its live heap.
// These megabyte traversals must not overlap one another or cold compilers.
for (const path of serialFiles) {
  console.log(`Serial memory slice: ${path}`);
  await run([`./${path}`], 1);
}

const memory = availableMemory();
const workers = testWorkers({ memory, cores, override });
console.log(`Test workers: ${workers} (available memory: ${(memory / 1024 ** 3).toFixed(2)} GiB)`);
// Keep Bun's native discovery, including future .spec/.tsx files. Ignore only
// the exact paths already executed above; test timings merge across slices.
await run(["tests", "bench", "packages/bendo"], workers, serialFiles);
