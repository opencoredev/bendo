// CI performance budget for hello-world throughput (BND-68).
//
//   bun bench/budget.ts run --baseline BIN --candidate BIN [--out FILE]
//   bun bench/budget.ts pin [REF]
//
// `run` measures two native hello servers on the same machine in alternating
// order and fails when the candidate's median paired throughput ratio falls
// below the manifest threshold. `pin` records REF (default HEAD) as the new
// baseline commit after an intentional performance change.
import { readFileSync, writeFileSync, appendFileSync } from "node:fs";
import { cpus } from "node:os";
import { command } from "./process.ts";
import { parseOha } from "./oha.ts";
import { distribution } from "./summary.ts";

export const manifestPath = "bench/perf-baseline.json";

export type Manifest = {
  commit: string;
  fixture: string;
  threshold: number;
  pairs: number;
  warmupSeconds: number;
  sampleSeconds: number;
  connections: number;
};

function field(record: object, key: string): unknown {
  return Object.entries(record).find(([name]) => name === key)?.[1];
}

function positive(record: object, key: string, integer: boolean): number {
  const value = field(record, key);
  if (typeof value !== "number" || !Number.isFinite(value) || value <= 0)
    throw new Error(`${manifestPath}: ${key} must be a positive number`);
  if (integer && !Number.isInteger(value))
    throw new Error(`${manifestPath}: ${key} must be an integer`);
  return value;
}

export function parseManifest(input: unknown): Manifest {
  if (typeof input !== "object" || input === null || Array.isArray(input))
    throw new Error(`${manifestPath} must be a JSON object`);
  const commit = field(input, "commit");
  if (typeof commit !== "string" || !/^[0-9a-f]{40}$/.test(commit))
    throw new Error(`${manifestPath}: commit must be a full lowercase SHA`);
  const fixture = field(input, "fixture");
  if (typeof fixture !== "string" || !fixture.endsWith(".bend"))
    throw new Error(`${manifestPath}: fixture must be a .bend path`);
  const threshold = positive(input, "threshold", false);
  if (threshold >= 1) throw new Error(`${manifestPath}: threshold must be below 1`);
  return {
    commit,
    fixture,
    threshold,
    pairs: positive(input, "pairs", true),
    warmupSeconds: positive(input, "warmupSeconds", true),
    sampleSeconds: positive(input, "sampleSeconds", true),
    connections: positive(input, "connections", true),
  };
}

export type Server = "baseline" | "candidate";

// Pair i runs baseline first when i is even and candidate first when odd
// (AB BA AB ...), so slow drift on the runner affects both sides equally.
export function schedule(pairs: number): Server[][] {
  return Array.from({ length: pairs }, (_, i) =>
    i % 2 === 0 ? ["baseline", "candidate"] : ["candidate", "baseline"],
  );
}

export type Pair = { baseline: number; candidate: number };

export type Verdict =
  | { kind: "pass"; ratio: number; ratios: number[] }
  | { kind: "regressed"; ratio: number; ratios: number[] };

// The gate is the median of per-pair candidate/baseline throughput ratios.
export function verdict(pairs: Pair[], threshold: number): Verdict {
  const ratios = pairs.map((pair) => pair.candidate / pair.baseline);
  const { median } = distribution(ratios);
  return median < threshold
    ? { kind: "regressed", ratio: median, ratios }
    : { kind: "pass", ratio: median, ratios };
}

// Disjoint CPU sets for the server and oha, from what the runner offers.
export function cpuSplit(count: number): { server: string; client: string; clientThreads: number } {
  if (count < 2) throw new Error("The performance budget needs at least two CPUs");
  const half = Math.floor(count / 2);
  const range = (from: number, to: number) => (from === to ? `${from}` : `${from}-${to}`);
  return {
    server: range(0, half - 1),
    client: range(half, count - 1),
    clientThreads: Math.min(2, count - half),
  };
}

const port = 8788;
const expectedBody = "Hello, world!";

async function ready(server: Bun.Subprocess) {
  for (let attempt = 0; attempt < 200; attempt++) {
    if (server.exitCode !== null) throw new Error(`Server exited with ${server.exitCode}`);
    try {
      const response = await fetch(`http://127.0.0.1:${port}/`);
      const body = await response.text();
      if (response.status !== 200 || body !== expectedBody)
        throw new Error(`Wrong response: ${response.status} ${JSON.stringify(body)}`);
      return;
    } catch (error) {
      if (error instanceof Error && error.message.startsWith("Wrong response")) throw error;
      await Bun.sleep(100);
    }
  }
  throw new Error("Server readiness timed out");
}

async function measure(binary: string, manifest: Manifest, split: ReturnType<typeof cpuSplit>) {
  const server = Bun.spawn(["taskset", "-c", split.server, binary], {
    env: { ...process.env, PORT: `${port}` },
    stdout: "ignore",
    stderr: "ignore",
  });
  try {
    await ready(server);
    const oha = (seconds: number) =>
      command(
        [
          "taskset",
          "-c",
          split.client,
          "oha",
          "--no-tui",
          "--output-format",
          "json",
          "--http-version",
          "1.1",
          "-w",
          "-t",
          "5s",
          "--worker-threads",
          `${split.clientThreads}`,
          "-c",
          `${manifest.connections}`,
          "-z",
          `${seconds}s`,
          `http://127.0.0.1:${port}/`,
        ],
        { timeoutMs: (seconds + 20) * 1000 },
      );
    await oha(manifest.warmupSeconds);
    const metrics = parseOha(JSON.parse(await oha(manifest.sampleSeconds)));
    if (metrics.errorCount > 0) throw new Error(`${binary}: ${metrics.errorCount} failed requests`);
    return metrics;
  } finally {
    server.kill();
    await server.exited;
  }
}

async function round(binaries: Record<Server, string>, manifest: Manifest) {
  const split = cpuSplit(cpus().length);
  const pairs: Pair[] = [];
  const samples = [];
  for (const order of schedule(manifest.pairs)) {
    const pair: Pair = { baseline: 0, candidate: 0 };
    for (const server of order) {
      const metrics = await measure(binaries[server], manifest, split);
      pair[server] = metrics.requestsPerSecond;
      samples.push({ server, ...metrics });
      console.log(`${server}: ${metrics.requestsPerSecond.toFixed(0)} req/s`);
    }
    pairs.push(pair);
  }
  return { pairs, samples, split };
}

function option(args: string[], name: string): string | undefined {
  const index = args.indexOf(name);
  return index === -1 ? undefined : args[index + 1];
}

async function run(args: string[]) {
  const baseline = option(args, "--baseline");
  const candidate = option(args, "--candidate");
  if (baseline === undefined || candidate === undefined)
    throw new Error("Usage: bun bench/budget.ts run --baseline BIN --candidate BIN [--out FILE]");
  const manifest = parseManifest(JSON.parse(readFileSync(manifestPath, "utf8")));
  const binaries = { baseline, candidate };
  // A failed first round is confirmed by a second; only the median over both
  // rounds' pairs can fail the job, so one noisy round cannot.
  const first = await round(binaries, manifest);
  const rounds = [first];
  let result = verdict(first.pairs, manifest.threshold);
  if (result.kind === "regressed") {
    console.log(`Ratio ${result.ratio.toFixed(3)} is below ${manifest.threshold}; confirming`);
    const second = await round(binaries, manifest);
    rounds.push(second);
    result = verdict([...first.pairs, ...second.pairs], manifest.threshold);
  }
  const report = {
    baselineCommit: manifest.commit,
    threshold: manifest.threshold,
    cpuModel: cpus()[0]?.model ?? "unknown",
    cpuCount: cpus().length,
    ...result,
    rounds,
  };
  const out = option(args, "--out");
  if (out !== undefined) writeFileSync(out, `${JSON.stringify(report, null, 2)}\n`);
  const lines = [
    `### Hello-world performance budget`,
    ``,
    `Baseline \`${manifest.commit.slice(0, 12)}\`, ${report.cpuCount} CPUs (${report.cpuModel}).`,
    ``,
    `| Pair | Baseline req/s | Candidate req/s | Ratio |`,
    `|---:|---:|---:|---:|`,
    ...rounds
      .flatMap((r) => r.pairs)
      .map(
        (p, i) =>
          `| ${i + 1} | ${p.baseline.toFixed(0)} | ${p.candidate.toFixed(0)} | ${(p.candidate / p.baseline).toFixed(3)} |`,
      ),
    ``,
    `Median ratio **${result.ratio.toFixed(3)}** (fails below ${manifest.threshold}): **${result.kind}**.`,
  ];
  console.log(lines.join("\n"));
  const summary = process.env.GITHUB_STEP_SUMMARY;
  if (summary !== undefined) appendFileSync(summary, `${lines.join("\n")}\n`);
  if (result.kind === "regressed") process.exit(1);
}

async function pin(args: string[]) {
  const ref = args[0] ?? "HEAD";
  const commit = await command(["git", "rev-parse", "--verify", `${ref}^{commit}`]);
  await command(["git", "merge-base", "--is-ancestor", commit, "HEAD"]).catch(() => {
    throw new Error(`${ref} is not an ancestor of HEAD`);
  });
  const manifest = parseManifest(JSON.parse(readFileSync(manifestPath, "utf8")));
  writeFileSync(manifestPath, `${JSON.stringify({ ...manifest, commit }, null, 2)}\n`);
  console.log(`Pinned the performance baseline to ${commit}`);
}

if (import.meta.main) {
  const [mode, ...rest] = process.argv.slice(2);
  switch (mode) {
    case "run":
      await run(rest);
      break;
    case "pin":
      await pin(rest);
      break;
    default:
      throw new Error("Usage: bun bench/budget.ts run|pin ...");
  }
}
