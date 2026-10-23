import { readFile } from "node:fs/promises";
import { cpus, totalmem } from "node:os";
import { command } from "./process.ts";
import { parseOha } from "./oha.ts";
import { method, order, scenarios } from "./scenarios.ts";
import hono from "./servers/node_modules/hono/package.json";
import elysia from "./servers/node_modules/elysia/package.json";

async function ready(server: ReturnType<typeof Bun.spawn>, scenario: (typeof scenarios)[number]) {
  for (let attempt = 0; attempt < 100; attempt++) {
    if (server.exitCode !== null) throw new Error(`Server exited ${server.exitCode}`);
    try {
      const response = await fetch(`http://127.0.0.1:8787${scenario.path}`, {
        method: scenario.method,
        ...(scenario.body === undefined ? {} : { body: scenario.body }),
        headers: { connection: "close" },
        signal: AbortSignal.timeout(500),
      });
      if (response.status !== 200 || (await response.text()) !== scenario.expectedBody) {
        throw new Error(`Wrong response for ${scenario.name}`);
      }
      return;
    } catch (error) {
      if (error instanceof Error && error.message.startsWith("Wrong response")) throw error;
      await Bun.sleep(100);
    }
  }
  throw new Error("Server readiness timed out");
}

const results = [];
for (const scenario of scenarios) {
  await command(["bend", scenario.bendoSource, "-o", "/tmp/bendo-bench"]);
  for (const framework of order) {
    const args =
      framework === "bendo" ? ["/tmp/bendo-bench"] : ["bun", `bench/servers/${framework}.ts`];
    const server = Bun.spawn(args, {
      stdout: "inherit",
      stderr: "inherit",
      env: { ...process.env, PORT: "8787" },
    });
    try {
      await ready(server, scenario);
      const common = [
        "oha",
        "--output-format",
        "json",
        "--no-tui",
        "-w",
        "-t",
        "5s",
        "--worker-threads",
        String(method.loadGeneratorThreads),
        "--disable-keepalive",
        "--http-version",
        "1.1",
        "-c",
        String(method.connections),
        "-m",
        scenario.method,
      ];
      if (scenario.body !== undefined) common.push("-d", scenario.body);
      const url = `http://127.0.0.1:8787${scenario.path}`;
      await command([...common, "-z", `${method.warmupSeconds}s`, url]);
      const raw = await command([...common, "-z", `${method.durationSeconds}s`, url]);
      const input: unknown = JSON.parse(raw);
      results.push({ framework, scenario: scenario.name, ...parseOha(input) });
      await Bun.write(`/tmp/oha-${scenario.name}-${framework}.json`, raw);
    } finally {
      server.kill("SIGTERM");
      await server.exited;
    }
  }
}
const hardware = {
  cpuModel: cpus()[0]?.model ?? "unknown",
  cores: cpus().length,
  ramBytes: totalmem(),
  architecture: process.arch,
  platform: process.platform,
  kernel: await command(["uname", "-r"]),
  cpuQuota: (await readFile("/sys/fs/cgroup/cpu.max", "utf8").catch(() => "unavailable")).trim(),
};
await Bun.write(
  "/tmp/bendo-results.json",
  JSON.stringify(
    {
      schemaVersion: 1,
      measuredAt: new Date().toISOString(),
      hardware,
      versions: {
        bend: await command(["bend", "version"]),
        bun: Bun.version,
        oha: await command(["oha", "--version"]),
        hono: hono.version,
        elysia: elysia.version,
      },
      method,
      scenarios,
      results,
    },
    null,
    2,
  ) + "\n",
);
