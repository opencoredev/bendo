import { createHash } from "node:crypto";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, renameSync, rmSync } from "node:fs";
import { release } from "node:os";
import { dirname, extname, join, relative, resolve } from "node:path";
import { findBend } from "../packages/bendo/src/bend.ts";

const ROOT = resolve(import.meta.dir, "..");

/** Wall-clock budget for one `bend` compile. CI runners are slower than ms-a2. */
const BEND_COMPILE_TIMEOUT_MS = 180_000;
export const BEND_COMPILE_TIMEOUT = `${BEND_COMPILE_TIMEOUT_MS / 1000}s`;
/** Per-test timeout for a test whose body runs one `bend` compile. Above BEND_COMPILE_TIMEOUT. */
export const COMPILE_TEST_TIMEOUT_MS = 200_000;
/** Per-test timeout for tests that push megabyte inputs through `.mjs` builds. */
export const SLOW_TEST_TIMEOUT_MS = 120_000;

export type RunningServer = {
  url: string;
  pid: number;
  [Symbol.asyncDispose]: () => Promise<void>;
};

type Target = "native" | "mjs" | "js";

let compiler: ReturnType<typeof findBend> | undefined;
let nativePlatform: string | undefined;

function nativeIdentity(): string {
  if (nativePlatform !== undefined) return nativePlatform;
  const identity = [
    process.platform === "linux" ? readFileSync("/etc/os-release", "utf8") : release(),
  ];
  for (const command of [
    ["cc", "--version"],
    ["clang", "--version"],
    ...(process.platform === "linux" ? [["ldd", "--version"]] : []),
  ]) {
    const run = Bun.spawnSync(command, { stdout: "pipe", stderr: "pipe", timeout: 5000 });
    if (run.exitCode !== 0) throw new Error(`Cannot identify native toolchain: ${command[0]}`);
    identity.push(`${run.stdout}${run.stderr}`);
  }
  nativePlatform = identity.join("\n");
  return nativePlatform;
}

/** Cache a complete dependency graph, including foreign effects and their twins. */
export function compile(entry: string, target: Target): string {
  compiler ??= findBend();
  if (compiler.kind === "missing") throw new Error("bend is not installed");
  const pinned = readFileSync(join(ROOT, ".bend-version"), "utf8").trim();
  if (compiler.version !== pinned)
    throw new Error(`Expected Bend ${pinned}, found ${compiler.version}`);
  const source = resolve(ROOT, entry);
  const graph = new Map<string, Buffer>();
  function visit(path: string): void {
    if (graph.has(path)) return;
    const content = readFileSync(path);
    graph.set(path, content);
    if (extname(path) !== ".bend") return;
    for (const match of content
      .toString()
      .matchAll(/^\s*import\s+(?:"([^"\n]+)"|(\.{1,2}\/[^\s]+))/gm)) {
      const imported = match[1] ?? match[2];
      if (!imported) continue;
      const dependency = resolve(dirname(path), imported);
      visit(dependency);
      if (/\.(c|js)$/.test(dependency)) {
        const twin = dependency.replace(/\.(c|js)$/, dependency.endsWith(".c") ? ".js" : ".c");
        if (existsSync(twin)) visit(twin);
      }
    }
  }
  visit(source);
  // Normalize generated fixtures against their entry directory so unique temp
  // directories and separate checkouts can reuse identical graphs.
  const base = source.startsWith(`${ROOT}/`) ? ROOT : dirname(source);
  const hash = createHash("sha256");
  hash.update(
    JSON.stringify([
      "bendo-fixture-v1",
      pinned,
      target,
      process.platform,
      process.arch,
      relative(base, source),
      target === "native" ? `${nativeIdentity()}\nsequential-c-v1` : "",
    ]),
  );
  for (const [path, contents] of [...graph]
    .map(([path, contents]): [string, Buffer] => [relative(base, path), contents])
    .sort(([a], [b]) => a.localeCompare(b))) {
    hash.update(JSON.stringify([path, contents.length]));
    hash.update(contents);
  }
  const directory = join(ROOT, ".cache/bend", hash.digest("hex"));
  mkdirSync(directory, { recursive: true });
  const name = target === "native" ? "fixture" : `fixture.${target}`;
  const output = join(directory, name);
  if (existsSync(output)) return output;
  const temporary = mkdtempSync(join(directory, ".compile-"));
  try {
    // Bend otherwise retains its typechecker heap while clang runs. Emitting C
    // first releases that heap before the native backend needs memory. These are
    // the pinned Bend 2.0.38 native flags; both stages share the original budget.
    const deadline = performance.now() + BEND_COMPILE_TIMEOUT_MS;
    const run = (args: string[]): void => {
      const remaining = deadline - performance.now();
      if (remaining <= 0) throw new Error(`bend build timed out (${entry})`);
      const result = Bun.spawnSync(["timeout", "--foreground", `${remaining / 1000}s`, ...args], {
        stdout: "pipe",
        stderr: "pipe",
      });
      if (result.exitCode !== 0)
        throw new Error(
          `bend build failed (${entry}, exit ${result.exitCode}, signal ${result.signalCode}):\n${result.stdout}${result.stderr}`,
        );
    };
    if (target === "native") {
      const cSource = join(temporary, "fixture.c");
      run([compiler.path, source, "-o", cSource]);
      run(["clang", "-std=c11", "-O3", cSource, "-lpthread", "-lm", "-o", join(temporary, name)]);
    } else {
      run([compiler.path, source, "-o", join(temporary, name)]);
    }
    // Each writer publishes a complete file atomically. Another worker may have
    // published the same graph meanwhile; replacing it is safe on POSIX.
    if (!existsSync(output)) renameSync(join(temporary, name), output);
    return output;
  } finally {
    rmSync(temporary, { recursive: true, force: true });
  }
}

/** Compiles a Bend entry file to a cached native binary and returns its path. */
export function build(entry: string): string {
  return compile(entry, "native");
}

/** How long a compiled server may take to answer its first request. ms-a2 is shared and often loaded. */
const SERVER_START_TIMEOUT_MS = 20_000;
const START_ATTEMPTS = 3;

type StartAttempt =
  | { kind: "up"; server: RunningServer }
  | { kind: "exited"; url: string; stderr: string }
  | { kind: "timeout"; url: string };

async function attempt(
  binary: string,
  hostname: string,
  env: Readonly<Record<string, string>>,
): Promise<StartAttempt> {
  // Stay below Linux's default ephemeral range (32768–60999): outbound test
  // traffic can leave those ports in TIME_WAIT and prevent a listener binding.
  const port = 20000 + Math.floor(Math.random() * 10000);
  const proc = Bun.spawn([binary], {
    env: { ...process.env, ...env, PORT: String(port) },
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
          pid: proc.pid,
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
 * `env` adds variables to the inherited environment.
 */
export async function start(
  binary: string,
  hostname = "127.0.0.1",
  env: Readonly<Record<string, string>> = {},
): Promise<RunningServer> {
  const failures: string[] = [];
  for (let i = 0; i < START_ATTEMPTS; i++) {
    const result = await attempt(binary, hostname, env);
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
