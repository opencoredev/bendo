import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { findBend } from "./bend.ts";

const bendInstall =
  "curl -fsSL https://bend-lang.com/install.sh -o /tmp/bendo-bend-install.sh && BEND_NO_TELEMETRY=1 sh /tmp/bendo-bend-install.sh";
const elanInstall =
  "curl -fsSL https://elan.lean-lang.org/elan-init.sh -o /tmp/bendo-elan-init.sh && sh /tmp/bendo-elan-init.sh -y --no-modify-path --default-toolchain none";

function pin(name: string): string {
  const local = resolve(name);
  return readFileSync(
    existsSync(local) ? local : resolve(import.meta.dir, "../../..", name),
    "utf8",
  ).trim();
}

/** What doctor reads from `elan dump-state`: the pin's resolved name and installed toolchains. */
export type ElanState = { resolved: string | null; installed: Map<string, string> };

function member(value: unknown, key: string): unknown {
  return typeof value === "object" && value !== null && key in value
    ? Reflect.get(value, key)
    : undefined;
}

export function parseElanState(text: string): ElanState | null {
  let json: unknown;
  try {
    json = JSON.parse(text);
  } catch {
    return null;
  }
  const toolchains = member(json, "toolchains");
  const active = member(toolchains, "resolved_active");
  const live = member(member(active, "live"), "Ok");
  const cached = member(active, "cached");
  const installed = new Map<string, string>();
  const list = member(toolchains, "installed");
  if (Array.isArray(list))
    for (const entry of list) {
      const name = member(entry, "resolved_name");
      const path = member(entry, "path");
      if (typeof name === "string" && typeof path === "string") installed.set(name, path);
    }
  return {
    resolved: typeof live === "string" ? live : typeof cached === "string" ? cached : null,
    installed,
  };
}

/**
 * Let elan resolve the pin the way `lake` would (shorthand, channels, custom
 * origins, linked and path toolchains), offline. `dump-state --no-net` only
 * reads state; running the Lean proxy, even for `--version`, may install.
 */
function leanToolchain(
  elan: string | null,
  text: string,
): { path: string | null; expected: string | null } {
  if (elan === null) return { path: null, expected: null };
  const directory = mkdtempSync(join(tmpdir(), "bendo-doctor-"));
  try {
    writeFileSync(join(directory, "lean-toolchain"), `${text}\n`);
    const run = Bun.spawnSync([elan, "dump-state", "--no-net"], {
      cwd: directory,
      stdout: "pipe",
      stderr: "pipe",
      timeout: 5000,
    });
    const state = run.exitCode === 0 ? parseElanState(run.stdout.toString()) : null;
    if (state === null || state.resolved === null) return { path: null, expected: null };
    const root = state.installed.get(state.resolved);
    // Only official releases have a version to compare; channels and custom builds just need to exist.
    const release = /^leanprover\/lean4:v(\d+\.\d+\.\d+(?:-[0-9A-Za-z.]+)?)$/.exec(state.resolved);
    return {
      path: root === undefined ? null : Bun.which(resolve(root, "bin/lean")),
      expected: release?.[1] ?? null,
    };
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
}

function shellQuote(text: string): string {
  return `'${text.replaceAll("'", `'\\''`)}'`;
}

export function doctor(): number {
  let problems = 0;
  const leanPin = pin("lean-toolchain");
  const lean = leanToolchain(Bun.which("elan"), leanPin);
  const leanInstall = `elan toolchain install ${shellQuote(leanPin)}`;
  const bend = findBend();
  const tools = [
    {
      name: "bend",
      path: bend.kind === "found" ? bend.path : null,
      args: ["version"],
      pattern: /^bend (\d+\.\d+\.\d+)$/m,
      expected: pin(".bend-version"),
      install: bendInstall,
    },
    {
      name: "elan",
      path: Bun.which("elan"),
      args: ["--version"],
      pattern: /^elan (\d+\.\d+\.\d+)/m,
      expected: null,
      install: elanInstall,
    },
    {
      name: "lean",
      path: lean.path,
      args: ["--version"],
      pattern: /^Lean \(version (\d+\.\d+\.\d+(?:-[\w.]+)?)/m,
      expected: lean.expected,
      install: `${elanInstall} && ${leanInstall}`,
    },
    {
      name: "clang",
      path: Bun.which("clang"),
      args: ["--version"],
      pattern: /clang version (\d+\.\d+\.\d+)/,
      expected: null,
      install:
        "sudo apt-get update && sudo apt-get install -y ca-certificates curl git unzip build-essential clang",
    },
    {
      name: "bun",
      path: Bun.which("bun"),
      args: ["--version"],
      pattern: /^(\d+\.\d+\.\d+(?:-[\w.]+)?)$/m,
      expected: null,
      install:
        "curl -fsSL https://bun.sh/install -o /tmp/bendo-bun-install.sh && bash /tmp/bendo-bun-install.sh",
    },
  ];
  for (const tool of tools) {
    if (tool.path === null) {
      console.log(`${tool.name}: missing\n  Install: ${tool.install}`);
      problems++;
      continue;
    }
    const run = Bun.spawnSync([tool.path, ...tool.args], {
      stdout: "pipe",
      stderr: "pipe",
      timeout: 5000,
    });
    const version = tool.pattern.exec(`${run.stdout}${run.stderr}`)?.[1];
    if (run.exitCode !== 0 || version === undefined) {
      console.log(`${tool.name}: cannot read version at ${tool.path}\n  Install: ${tool.install}`);
      problems++;
    } else if (tool.expected !== null && version !== tool.expected) {
      console.log(
        `${tool.name} ${version} at ${tool.path}: mismatch (expected ${tool.expected})\n  Install: ${tool.install}`,
      );
      problems++;
    } else console.log(`${tool.name} ${version} at ${tool.path}: OK`);
  }
  return problems === 0 ? 0 : 1;
}
