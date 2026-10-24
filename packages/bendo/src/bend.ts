export type BendInstall = { kind: "found"; path: string; version: string } | { kind: "missing" };

const VERSION_LINE = /v?(\d+\.\d+\.\d+)/;

/** Locates the `bend` compiler on PATH or in ~/.bend/bin and reads its version. */
export function findBend(): BendInstall {
  const home = process.env.HOME ?? "";
  const path = Bun.which("bend") ?? Bun.which("bend", { PATH: `${home}/.bend/bin` });
  if (path === null) return { kind: "missing" };
  return { kind: "found", path, version: readVersion(path, 2) };
}

/**
 * `bend version` normally answers in well under a second, but its first run
 * on a freshly started machine has taken over 5 s. Allow 30 s and retry once
 * before reporting "unknown", which the test harness treats as a pin mismatch.
 */
function readVersion(path: string, attempts: number): string {
  const run = Bun.spawnSync([path, "version"], { stdout: "pipe", stderr: "pipe", timeout: 30_000 });
  const version = VERSION_LINE.exec(`${run.stdout.toString()}${run.stderr.toString()}`)?.[1];
  if (version !== undefined) return version;
  return attempts > 1 ? readVersion(path, attempts - 1) : "unknown";
}
