import { readFile } from "node:fs/promises";
import { cpus, totalmem } from "node:os";
import { createHash } from "node:crypto";
import { command } from "./process.ts";
import { parseOha } from "./oha.ts";
import { summarize } from "./summary.ts";
import { method, requestHeaders, scenarios } from "./scenarios.ts";
import hono from "./servers/node_modules/hono/package.json";
import elysia from "./servers/node_modules/elysia/package.json";

const serverCpus = "0-3";
const loadCpus = "4-7";
const variants = [
  { framework: "bendo", variant: "default", args: ["/tmp/bendo-bench"] },
  { framework: "hono", variant: "single-process", args: ["bun", "bench/servers/hono.ts"] },
  { framework: "elysia", variant: "single-process", args: ["bun", "bench/servers/elysia.ts"] },
  {
    framework: "bendo",
    variant: "threads-1",
    args: ["/tmp/bendo-bench", "+RTS", "--threads", "1"],
  },
];

async function ready(server: ReturnType<typeof Bun.spawn>, scenario: (typeof scenarios)[number]) {
  for (let attempt = 0; attempt < 100; attempt++) {
    if (server.exitCode !== null) throw new Error(`Server exited ${server.exitCode}`);
    try {
      const response = await fetch(`http://127.0.0.1:8787${scenario.path}`, {
        method: scenario.method,
        ...(scenario.body === undefined ? {} : { body: scenario.body }),
        headers: {
          ...requestHeaders,
          connection: "keep-alive",
        },
        signal: AbortSignal.timeout(5000),
      });
      const body = await response.text();
      if (response.status !== 200 || body !== scenario.expectedBody)
        throw new Error(`Wrong response for ${scenario.name}: ${response.status} ${body}`);
      const expectedType =
        scenario.name === "json" || scenario.name === "echo" ? "application/json" : "text/plain";
      if (response.headers.get("content-type")?.split(";")[0] !== expectedType)
        throw new Error(`Wrong response content type: ${response.headers.get("content-type")}`);
      for (const name of scenario.presentHeaders) {
        if (!response.headers.get(name)) throw new Error(`Wrong response: missing ${name}`);
      }
      for (const [name, value] of Object.entries(scenario.expectedHeaders)) {
        if (response.headers.get(name) !== value)
          throw new Error(
            `Wrong response header ${name}: ${response.headers.get(name)} expected ${value}`,
          );
      }
      return { status: response.status, body, headers: Object.fromEntries(response.headers) };
    } catch (error) {
      if (error instanceof Error && error.message.startsWith("Wrong response")) throw error;
      await Bun.sleep(100);
    }
  }
  throw new Error("Server readiness timed out");
}

if (process.env.BENDO_BENCH_BOAT !== "1")
  throw new Error("Load generation is Boat-only; use bun bench/run.ts");
if (cpus().length < 8) throw new Error("This benchmark requires a large (8 vCPU) Boat sandbox");
const results = [];
const rawRuns = [];
const binaries = [];
for (const scenario of scenarios) {
  // Match the pinned Bend native release build, with compiler processes separated
  // to release Bend's heap before clang's optimizer starts.
  await command(["bend", scenario.bendoSource, "-o", "/tmp/bendo-bench.c"]);
  await command([
    "clang",
    "-std=c11",
    "-O3",
    "/tmp/bendo-bench.c",
    "-o",
    "/tmp/bendo-bench",
    "-lpthread",
    "-lm",
  ]);
  binaries.push({
    scenario: scenario.name,
    sha256: createHash("sha256")
      .update(await readFile("/tmp/bendo-bench"))
      .digest("hex"),
  });
  // Rotate the starting framework each repetition to spread fixed-order drift.
  const samples = variants.map((variant) => ({
    ...variant,
    samples: new Array<ReturnType<typeof parseOha>>(),
    verification: new Array<Awaited<ReturnType<typeof ready>>>(),
  }));
  for (let repetition = 0; repetition < method.repetitions; repetition++) {
    const rotated = [
      ...samples.slice(repetition % samples.length),
      ...samples.slice(0, repetition % samples.length),
    ];
    for (const variant of rotated) {
      process.stderr.write(
        `${scenario.name} ${variant.framework} ${variant.variant} repetition ${repetition + 1}\n`,
      );
      const server = Bun.spawn(["taskset", "-c", serverCpus, ...variant.args], {
        stdout: "inherit",
        stderr: "inherit",
        env: { ...process.env, PORT: "8787", SCENARIO: scenario.name },
      });
      try {
        variant.verification.push(await ready(server, scenario));
        const common = [
          "taskset",
          "-c",
          loadCpus,
          "oha",
          "--output-format",
          "json",
          "--no-tui",
          "-w",
          "-t",
          "5s",
          "--worker-threads",
          String(method.loadGeneratorThreads),
          "--http-version",
          "1.1",
          "-c",
          String(method.connections),
          "-m",
          scenario.method,
          ...Object.entries(requestHeaders).flatMap(([name, value]) => ["-H", `${name}: ${value}`]),
        ];
        if (scenario.body !== undefined) common.push("-d", scenario.body);
        const url = `http://127.0.0.1:8787${scenario.path}`;
        await command([...common, "-z", `${method.warmupSeconds}s`, url]);
        const raw: unknown = JSON.parse(
          await command([...common, "-z", `${method.durationSeconds}s`, url]),
        );
        const metrics = parseOha(raw);
        if (metrics.errorCount > 0)
          process.stderr.write(`INVALID sample: ${metrics.errorCount} errors\n`);
        variant.samples.push(metrics);
        rawRuns.push({
          scenario: scenario.name,
          framework: variant.framework,
          variant: variant.variant,
          repetition: repetition + 1,
          oha: raw,
        });
      } finally {
        server.kill("SIGTERM");
        await server.exited;
      }
    }
  }
  for (const variant of samples) {
    results.push({
      scenario: scenario.name,
      framework: variant.framework,
      variant: variant.variant,
      samples: variant.samples,
      summary: summarize(variant.samples),
      verification: variant.verification,
    });
  }
}
await Bun.write(
  "/tmp/bendo-results.json",
  JSON.stringify(
    {
      schemaVersion: 2,
      measuredAt: new Date().toISOString(),
      hardware: {
        cpuModel: cpus()[0]?.model ?? "unknown",
        cores: cpus().length,
        ramBytes: totalmem(),
        architecture: process.arch,
        platform: process.platform,
        kernel: await command(["uname", "-r"]),
        cpuQuota: (
          await readFile("/sys/fs/cgroup/cpu.max", "utf8").catch(() => "unavailable")
        ).trim(),
        lscpu: await command(["lscpu"]),
      },
      versions: {
        bend: await command(["bend", "version"]),
        bendToolchainSha256: createHash("sha256")
          .update(await readFile("/tmp/bend-local.tar.gz"))
          .digest("hex"),
        bun: Bun.version,
        oha: await command(["oha", "--version"]),
        hono: hono.version,
        elysia: elysia.version,
        clang: await command(["clang", "--version"]),
      },
      method: {
        ...method,
        serverCpus,
        loadCpus,
        variants,
        order: "rotate variant start by repetition; restart and warm every sample",
        compilation:
          "bend source -o /tmp/bendo-bench.c; clang -std=c11 -O3 /tmp/bendo-bench.c -o /tmp/bendo-bench -lpthread -lm",
        network: "loopback in one large Boat sandbox; disjoint CPU sets",
      },
      scenarios,
      binaries,
      results,
      rawRuns,
    },
    null,
    2,
  ) + "\n",
);
