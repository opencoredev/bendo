import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { resolve } from "node:path";
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

/**
 * A `lean-toolchain` pin as elan reads it. Official names expand to
 * `leanprover/lean4:<name>`; a release carries the version Lean reports.
 * Anything else is a custom or linked toolchain, kept as written.
 */
type LeanPin =
  | { kind: "release"; name: string; version: string }
  | { kind: "official"; name: string }
  | { kind: "custom"; name: string }
  | { kind: "invalid"; text: string };

export function parseLeanPin(text: string): LeanPin {
  const release = /^(?:leanprover\/lean4:)?v?(\d+\.\d+\.\d+(?:-[0-9A-Za-z.]+)?)$/.exec(text);
  if (release?.[1] !== undefined)
    return { kind: "release", name: `leanprover/lean4:v${release[1]}`, version: release[1] };
  const channel = /^(?:leanprover\/lean4:)?((?:stable|beta|nightly)(?:-\d{4}-\d{2}-\d{2})?)$/.exec(
    text,
  );
  if (channel?.[1] !== undefined)
    return { kind: "official", name: `leanprover/lean4:${channel[1]}` };
  if (/^[0-9A-Za-z][0-9A-Za-z._+-]*$/.test(text)) return { kind: "custom", name: text };
  return { kind: "invalid", text };
}

export function doctor(): number {
  let problems = 0;
  const leanPin = parseLeanPin(pin("lean-toolchain"));
  let leanName: string;
  let leanVersion: string | null;
  switch (leanPin.kind) {
    case "release":
      leanName = leanPin.name;
      leanVersion = leanPin.version;
      break;
    case "official":
    case "custom":
      leanName = leanPin.name;
      leanVersion = null;
      break;
    case "invalid":
      console.log(`lean: unreadable lean-toolchain pin ${JSON.stringify(leanPin.text)}`);
      return 1;
  }
  // The name is validated above, so single quotes make it a literal shell word.
  const leanInstall = `elan toolchain install '${leanName}'`;
  // Resolve the installed binary directly: an elan proxy can install even for --version.
  const leanPath = resolve(
    process.env.ELAN_HOME ?? resolve(homedir(), ".elan"),
    "toolchains",
    leanName.replaceAll("/", "--").replace(":", "---"),
    "bin/lean",
  );
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
      path: Bun.which(leanPath),
      args: ["--version"],
      pattern: /^Lean \(version (\d+\.\d+\.\d+(?:-[\w.]+)?)/m,
      expected: leanVersion,
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
