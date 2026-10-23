import { existsSync, readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { findBend } from "./bend.ts";

const bendInstall =
  "curl -fsSL https://bend-lang.com/install.sh -o /tmp/bendo-bend-install.sh && BEND_NO_TELEMETRY=1 sh /tmp/bendo-bend-install.sh";
const elanInstall =
  "curl -fsSL https://elan.lean-lang.org/elan-init.sh -o /tmp/bendo-elan-init.sh && sh /tmp/bendo-elan-init.sh -y --no-modify-path --default-toolchain none";

/** The project's pin file, or the one Bendo ships with when run outside a project. */
function pinFile(name: string): string {
  const local = resolve(name);
  return existsSync(local) ? local : resolve(import.meta.dir, "../../..", name);
}

function pin(name: string): string {
  return readFileSync(pinFile(name), "utf8").trim();
}

/**
 * What doctor reads from `elan dump-state`: the pin's resolved name, whether
 * elan read it as a filesystem path, and the installed toolchains.
 */
export type ElanState = { resolved: string | null; path: boolean; installed: Map<string, string> };

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
  const unresolved = member(member(toolchains, "active_override"), "unresolved");
  return {
    resolved: typeof live === "string" ? live : typeof cached === "string" ? cached : null,
    path: member(unresolved, "Path") !== undefined,
    installed,
  };
}

/**
 * Let elan resolve the pin the way `lake` would (shorthand, channels, custom
 * origins, linked and path toolchains), offline. `ELAN_TOOLCHAIN` has elan's
 * highest precedence, so the project pin wins over any inherited override, and
 * running from the pin file's directory resolves a relative path pin as the
 * file would. `dump-state --no-net` installs nothing and registers no project;
 * like any elan command it creates `settings.toml` in an empty `ELAN_HOME`.
 * Running the Lean proxy, even for `--version`, may install, so doctor never does.
 */
function leanToolchain(
  elan: string | null,
  text: string,
  directory: string,
): { path: string | null; expected: string | null } {
  if (elan === null) return { path: null, expected: null };
  const run = Bun.spawnSync([elan, "dump-state", "--no-net"], {
    cwd: directory,
    env: { ...process.env, ELAN_TOOLCHAIN: text },
    stdout: "pipe",
    stderr: "pipe",
    timeout: 5000,
  });
  const state = run.exitCode === 0 ? parseElanState(run.stdout.toString()) : null;
  if (state === null || state.resolved === null) return { path: null, expected: null };
  // Path toolchains are not listed as installed; elan resolves them to the directory itself.
  // A named toolchain must be installed: a same-named directory never stands in for it.
  const root = state.path ? state.resolved : state.installed.get(state.resolved);
  if (root === undefined) return { path: null, expected: null };
  // Only official releases have a version to compare; channels and custom builds just need to exist.
  const release = /^leanprover\/lean4:v(\d+\.\d+\.\d+(?:-[0-9A-Za-z.]+)?)$/.exec(state.resolved);
  return { path: Bun.which(resolve(directory, root, "bin/lean")), expected: release?.[1] ?? null };
}

function shellQuote(text: string): string {
  return `'${text.replaceAll("'", `'\\''`)}'`;
}

export function doctor(): number {
  let problems = 0;
  const leanPin = pin("lean-toolchain");
  const lean = leanToolchain(Bun.which("elan"), leanPin, dirname(pinFile("lean-toolchain")));
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
