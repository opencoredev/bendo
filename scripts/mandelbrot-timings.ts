// Times examples/mandelbrot per mode from its Server-Timing header.
// Usage: bun scripts/mandelbrot-timings.ts [runs] [query]
// Example: bun scripts/mandelbrot-timings.ts 7 "w=1024&h=1024&iter=1024"
import { availableParallelism } from "node:os";
import { build, start } from "../tests/harness.ts";

const MODES = ["single", "cpu", "gpu"] as const;
type Mode = (typeof MODES)[number];
type Sample = { compute: number; encode: number };

function parseRuns(text: string | undefined): number {
  if (text === undefined) return 7;
  const runs = Number(text);
  if (!Number.isInteger(runs) || runs < 1 || runs > 50) throw new Error("runs must be 1-50");
  return runs;
}

function parseTiming(header: string | null): Sample {
  const match = header?.match(/^compute;dur=(\d+);desc="[a-z]+", encode;dur=(\d+)$/);
  if (!match?.[1] || !match[2]) throw new Error(`unexpected Server-Timing: ${header}`);
  return { compute: Number(match[1]), encode: Number(match[2]) };
}

function median(values: number[]): number {
  const sorted = values.toSorted((a, b) => a - b);
  return sorted[Math.floor(sorted.length / 2)] ?? Number.NaN;
}

const runs = parseRuns(process.argv[2]);
const query = process.argv[3] ?? "w=512&h=512&iter=256";
await using server = await start(build("examples/mandelbrot/main.bend"));

async function sample(mode: Mode): Promise<Sample> {
  const response = await fetch(`${server.url}/mandelbrot.bmp?mode=${mode}&${query}`, {
    signal: AbortSignal.timeout(120_000),
  });
  if (response.status !== 200) throw new Error(`${mode}: HTTP ${response.status}`);
  await response.arrayBuffer();
  return parseTiming(response.headers.get("server-timing"));
}

const samples = new Map<Mode, Sample[]>(MODES.map((mode) => [mode, []]));
for (const mode of MODES) await sample(mode);
// Interleave modes so load changes on a shared machine hit each one alike.
for (let i = 0; i < runs; i++) {
  for (const mode of MODES) samples.get(mode)?.push(await sample(mode));
}

const single = median((samples.get("single") ?? []).map((s) => s.compute));
console.log(`${query}, ${runs} runs, ${availableParallelism()} cores`);
console.log("| mode | compute median (ms) | compute min (ms) | encode median (ms) | vs single |");
console.log("| --- | ---: | ---: | ---: | ---: |");
for (const mode of MODES) {
  const list = samples.get(mode) ?? [];
  const compute = median(list.map((s) => s.compute));
  const min = Math.min(...list.map((s) => s.compute));
  const encode = median(list.map((s) => s.encode));
  const speedup = compute > 0 ? `${(single / compute).toFixed(1)}x` : "n/a";
  console.log(`| ${mode} | ${compute} | ${min} | ${encode} | ${speedup} |`);
}
