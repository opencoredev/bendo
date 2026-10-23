import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { findBend } from "../packages/bendo/src/bend.ts";

const ROOT = resolve(import.meta.dir, "..");

export type RunningServer = { url: string; [Symbol.asyncDispose]: () => Promise<void> };

/** Compiles a Bend entry file to a native binary and returns its path. */
export function build(entry: string): string {
  const bend = findBend();
  if (bend.kind === "missing") throw new Error("bend is not installed");
  const out = join(mkdtempSync(join(tmpdir(), "bendo-test-")), "server");
  const run = Bun.spawnSync([bend.path, join(ROOT, entry), "-o", out], {
    stdout: "pipe",
    stderr: "pipe",
  });
  if (run.exitCode !== 0) throw new Error(`bend build failed:\n${run.stdout}${run.stderr}`);
  return out;
}

/** Starts a compiled server on a free port and waits until it answers. */
export async function start(binary: string, hostname = "127.0.0.1"): Promise<RunningServer> {
  const port = 20000 + Math.floor(Math.random() * 20000);
  const proc = Bun.spawn([binary], {
    env: { ...process.env, PORT: String(port) },
    stdout: "pipe",
    stderr: "pipe",
  });
  const url = `http://${hostname}:${port}`;
  const deadline = Date.now() + 5000;
  while (Date.now() < deadline) {
    const up = await fetch(url).then(
      () => true,
      () => false,
    );
    if (up)
      return {
        url,
        [Symbol.asyncDispose]: async () => {
          proc.kill();
          await proc.exited;
        },
      };
    await Bun.sleep(50);
  }
  proc.kill();
  throw new Error(`server did not start on ${url}`);
}
