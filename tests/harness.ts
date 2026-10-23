import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { findBend } from "../packages/bendo/src/bend.ts";

const ROOT = resolve(import.meta.dir, "..");

/** Wall-clock budget for one `bend` compile. CI runners are slower than ms-a2. */
export const BEND_COMPILE_TIMEOUT = "180s";
/** Per-test timeout for a test whose body runs one `bend` compile. Above BEND_COMPILE_TIMEOUT. */
export const COMPILE_TEST_TIMEOUT_MS = 200_000;
/** Per-test timeout for tests that push megabyte inputs through `.mjs` builds. */
export const SLOW_TEST_TIMEOUT_MS = 120_000;

export type RunningServer = { url: string; [Symbol.asyncDispose]: () => Promise<void> };

/** Compiles a Bend entry file to a native binary and returns its path. */
export function build(entry: string): string {
  const bend = findBend();
  if (bend.kind === "missing") throw new Error("bend is not installed");
  const out = join(mkdtempSync(join(tmpdir(), "bendo-test-")), "server");
  const run = Bun.spawnSync(
    ["timeout", "--foreground", BEND_COMPILE_TIMEOUT, bend.path, join(ROOT, entry), "-o", out],
    {
      stdout: "pipe",
      stderr: "pipe",
    },
  );
  if (run.exitCode !== 0) throw new Error(`bend build failed:\n${run.stdout}${run.stderr}`);
  return out;
}

/** How long a compiled server may take to answer its first request. ms-a2 is shared and often loaded. */
const SERVER_START_TIMEOUT_MS = 20_000;
const START_ATTEMPTS = 3;

type StartAttempt =
  | { kind: "up"; server: RunningServer }
  | { kind: "exited"; url: string; stderr: string }
  | { kind: "timeout"; url: string };

async function attempt(binary: string, hostname: string): Promise<StartAttempt> {
  const port = 20000 + Math.floor(Math.random() * 20000);
  const proc = Bun.spawn([binary], {
    env: { ...process.env, PORT: String(port) },
    stdout: "pipe",
    stderr: "pipe",
  });
  const url = `http://${hostname}:${port}`;
  let exited = false;
  void proc.exited.then(() => {
    exited = true;
  });
  const deadline = Date.now() + SERVER_START_TIMEOUT_MS;
  while (Date.now() < deadline) {
    if (exited) return { kind: "exited", url, stderr: await new Response(proc.stderr).text() };
    const up = await fetch(url).then(
      () => true,
      () => false,
    );
    if (up)
      return {
        kind: "up",
        server: {
          url,
          [Symbol.asyncDispose]: async () => {
            proc.kill();
            await proc.exited;
          },
        },
      };
    await Bun.sleep(50);
  }
  proc.kill();
  await proc.exited;
  return { kind: "timeout", url };
}

/**
 * Starts a compiled server on a random port and waits until it answers.
 * A server that exits before answering (for example on a port collision) is retried on a new port.
 */
export async function start(binary: string, hostname = "127.0.0.1"): Promise<RunningServer> {
  const failures: string[] = [];
  for (let i = 0; i < START_ATTEMPTS; i++) {
    const result = await attempt(binary, hostname);
    switch (result.kind) {
      case "up":
        return result.server;
      case "exited":
        failures.push(`${result.url}: exited before answering: ${result.stderr.trim()}`);
        break;
      case "timeout":
        throw new Error(
          `server did not answer on ${result.url} within ${SERVER_START_TIMEOUT_MS} ms`,
        );
    }
  }
  throw new Error(`server did not start after ${START_ATTEMPTS} attempts:\n${failures.join("\n")}`);
}
