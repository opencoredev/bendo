export type BendInstall = { kind: "found"; path: string; version: string } | { kind: "missing" };

const VERSION_LINE = /v?(\d+\.\d+\.\d+)/;

/** Locates the `bend` compiler on PATH or in ~/.bend/bin and reads its version. */
export function findBend(): BendInstall {
  const home = process.env.HOME ?? "";
  const path = Bun.which("bend") ?? Bun.which("bend", { PATH: `${home}/.bend/bin` });
  if (path === null) return { kind: "missing" };
  const run = Bun.spawnSync([path, "version"], { stdout: "pipe", stderr: "pipe", timeout: 5000 });
  const text = `${run.stdout.toString()}${run.stderr.toString()}`;
  const version = VERSION_LINE.exec(text)?.[1] ?? "unknown";
  return { kind: "found", path, version };
}
