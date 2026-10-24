import { mkdir, readFile, rm } from "node:fs/promises";
import { resolve } from "node:path";
import { command } from "./process.ts";
import { snapshot, sourceDirectory } from "./source.ts";

const root = resolve(import.meta.dir, "..");
const label = `bendo-bench-${Date.now()}-${process.pid}`;
const sandboxType = "large";
let interrupted = false;
const controller = new AbortController();
const onSignal = () => {
  interrupted = true;
  controller.abort(new Error("Benchmark interrupted"));
};
process.on("SIGINT", onSignal);
process.on("SIGTERM", onSignal);
function checkSignal() {
  if (interrupted) throw new Error("Benchmark interrupted; cleaning up sandbox");
}

async function main() {
  const directory = await sourceDirectory();
  try {
    const source = await snapshot(root, directory);
    checkSignal();
    process.stderr.write(`Creating ${sandboxType} sandbox; label=${label}\n`);
    const id = await command([
      "boat-sbx",
      "new",
      "--type",
      sandboxType,
      "--ttl",
      "7200",
      "--label",
      label,
    ]);
    checkSignal();
    process.stderr.write(`Sandbox ${id}\n`);
    if (process.env.BENCH_FAIL_AFTER_CREATE === "1")
      throw new Error("Injected failure after sandbox creation");
    process.stderr.write("Uploading source snapshot\n");
    await command(["boat", "push", id, directory, "--to", "/home/user/bendo"], {
      signal: controller.signal,
    });
    const toolchain = resolve(directory, "bend-local.tar.gz");
    await command([
      "tar",
      "-czf",
      toolchain,
      "-C",
      process.env.HOME ?? "",
      ".bend/bin",
      ".bend/bend2",
      ".bend/guide",
    ]);
    await command(["boat", "scp", toolchain, `${id}:/tmp/bend-local.tar.gz`], {
      signal: controller.signal,
    });
    checkSignal();
    process.stderr.write("Installing tools and checking benchmark TypeScript\n");
    await command(
      [
        "boat-sbx",
        "exec",
        id,
        "--timeout",
        "900",
        "--cwd",
        "/home/user/bendo",
        "--",
        "bash bench/setup.sh",
      ],
      { timeoutMs: 960_000, signal: controller.signal },
    );
    checkSignal();
    process.stderr.write("Running warmups and measurements\n");
    await command(
      [
        "boat-sbx",
        "exec",
        id,
        "--timeout",
        "2400",
        "--cwd",
        "/home/user/bendo",
        "--",
        'export PATH="$HOME/.bend/bin:$HOME/.bun/bin:$PATH"; sudo systemd-run --uid=user --collect --wait --pipe -p WorkingDirectory=/home/user/bendo -E PATH="$PATH" -E BEND_NO_TELEMETRY=1 -E BENDO_BENCH_BOAT=1 timeout 39m bun bench/remote.ts',
      ],
      { timeoutMs: 2460_000, signal: controller.signal },
    );
    checkSignal();
    const resultsDirectory = resolve(root, "bench/results");
    await mkdir(resultsDirectory, { recursive: true });
    const temporary = resolve(resultsDirectory, `.${label}.json`);
    try {
      await command(["boat", "scp", `${id}:/tmp/bendo-results.json`, temporary], {
        signal: controller.signal,
      });
      const raw: unknown = JSON.parse(await readFile(temporary, "utf8"));
      if (
        typeof raw !== "object" ||
        raw === null ||
        !("results" in raw) ||
        !Array.isArray(raw.results) ||
        raw.results.length === 0
      ) {
        throw new Error("Sandbox produced an invalid results file");
      }
      checkSignal();
      const destination = resolve(
        resultsDirectory,
        `${new Date().toISOString().replaceAll(":", "-")}.json`,
      );
      await Bun.write(
        destination,
        JSON.stringify(
          { ...raw, sandbox: { provider: "boat", type: sandboxType, id, label }, source },
          null,
          2,
        ) + "\n",
      );
      await command(["bun", "bench/chart.ts", destination], { cwd: root });
      process.stdout.write(`${destination}\n`);
    } finally {
      await rm(temporary, { force: true });
    }
  } finally {
    await cleanup(directory);
  }
}

async function cleanup(directory: string) {
  // The label also covers a creation interrupted before its ID was returned.
  try {
    await command(["boat-sbx", "gc", "--label", label]);
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
  const remaining = await command(["boat-sbx", "ls", "--label", label]);
  if (remaining !== "") throw new Error(`Sandbox cleanup incomplete: ${remaining}`);
  process.stderr.write(`Cleanup verified: boat-sbx ls --label ${label} is empty\n`);
  process.off("SIGINT", onSignal);
  process.off("SIGTERM", onSignal);
}

main().catch((error: unknown) => {
  process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
  process.exitCode = interrupted ? 130 : 1;
});
