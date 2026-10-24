// Shared steps for the create-bendo integration tests: run the CLI into a
// directory outside the checkout, install, build with the app's own scripts and
// start the built server from the app directory.
import { createHash } from "node:crypto";
import { cpSync, existsSync, mkdirSync, readdirSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { BEND_COMPILE_TIMEOUT } from "./harness.ts";

const ROOT = resolve(import.meta.dir, "..");
const CLI = join(ROOT, "packages/create-bendo/src/index.ts");

/** `bun install` from the registry, with Bun's cache warm or cold. */
const INSTALL_TIMEOUT_MS = 180_000;
/** Vite build and tsc for the fullstack template. */
const WEB_BUILD_TIMEOUT_MS = 120_000;
const COMPILE_TIMEOUT_MS = Number.parseInt(BEND_COMPILE_TIMEOUT) * 1000;
/** Per-test budget for scaffold, install and a cold native build. */
export const CREATE_TEST_TIMEOUT_MS =
  INSTALL_TIMEOUT_MS + COMPILE_TIMEOUT_MS + WEB_BUILD_TIMEOUT_MS + 30_000;

export type Template = "api" | "fullstack";

/**
 * The app lives at a fixed path per checkout because `bendo build` keys its
 * cache on absolute source paths. Its `.cache/bendo` is kept under the
 * checkout's `.cache/bend`, which CI restores between runs, so a warm run
 * skips the Bend compile while still running the app's real build script.
 */
function workspace(template: Template): { work: string; app: string; saved: string } {
  const checkout = createHash("sha256").update(ROOT).digest("hex").slice(0, 12);
  const work = join(tmpdir(), "bendo-create-test", checkout, template);
  return {
    work,
    app: join(work, "app"),
    saved: join(ROOT, ".cache/bend/create-bendo", template),
  };
}

export type Run = { exitCode: number; output: string };

export function run(
  command: string[],
  cwd: string,
  timeoutMs: number,
  env: Record<string, string> = {},
): Run {
  const result = Bun.spawnSync(command, {
    cwd,
    env: { ...process.env, ...env },
    stdin: "ignore",
    stdout: "pipe",
    stderr: "pipe",
    timeout: timeoutMs,
  });
  return {
    exitCode: result.exitCode ?? -1,
    output: `${result.stdout.toString()}${result.stderr.toString()}`,
  };
}

function succeed(command: string[], cwd: string, timeoutMs: number): string {
  const result = run(command, cwd, timeoutMs);
  if (result.exitCode !== 0)
    throw new Error(
      `${command.join(" ")} failed (${result.exitCode}) in ${cwd}:\n${result.output}`,
    );
  return result.output;
}

export type Built = { app: string; scaffold: string; build: string };

/** Scaffolds, installs and builds a fresh app from `template`. */
export function scaffoldAndBuild(template: Template): Built {
  const { work, app, saved } = workspace(template);
  rmSync(work, { recursive: true, force: true });
  mkdirSync(work, { recursive: true });
  const scaffold = succeed([process.execPath, CLI, "app", "--template", template], work, 30_000);
  if (existsSync(saved)) cpSync(saved, join(app, ".cache/bendo"), { recursive: true });
  succeed([process.execPath, "install"], app, INSTALL_TIMEOUT_MS);
  const build = succeed(
    [process.execPath, "run", "build"],
    app,
    COMPILE_TIMEOUT_MS + WEB_BUILD_TIMEOUT_MS,
  );
  // Keep only the entry this build published, so old compiles never pile up.
  rmSync(saved, { recursive: true, force: true });
  mkdirSync(saved, { recursive: true });
  const server = readFileSync(join(app, "dist/server"));
  const cache = join(app, ".cache/bendo");
  for (const entry of readdirSync(cache)) {
    const binary = join(cache, entry, "server");
    if (existsSync(binary) && readFileSync(binary).equals(server))
      cpSync(join(cache, entry), join(saved, entry), { recursive: true });
  }
  return { app, scaffold, build };
}

export type Served = { url: string; [Symbol.asyncDispose]: () => Promise<void> };

/** Runs `dist/server` from the app directory, as `bun run start` does. */
export async function serve(app: string): Promise<Served> {
  for (let attempt = 0; attempt < 3; attempt++) {
    // Below Linux's default ephemeral range, as in harness.ts.
    const port = 20000 + Math.floor(Math.random() * 10000);
    const proc = Bun.spawn([join(app, "dist/server")], {
      cwd: app,
      env: { ...process.env, PORT: String(port) },
      stdout: "ignore",
      stderr: "pipe",
    });
    const url = `http://127.0.0.1:${port}`;
    const deadline = Date.now() + 20_000;
    let exited = false;
    void proc.exited.then(() => {
      exited = true;
    });
    while (!exited && Date.now() < deadline) {
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
    await proc.exited;
    if (!exited) throw new Error(`${app}/dist/server did not answer on ${url}`);
  }
  throw new Error(`${app}/dist/server exited before answering three times`);
}
