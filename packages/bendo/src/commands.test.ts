import { afterAll, expect, test } from "bun:test";
import {
  copyFileSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { parseElanState } from "./doctor.ts";

const cli = resolve(import.meta.dir, "cli.ts");
const root = mkdtempSync(join(tmpdir(), "bendo-commands-"));
const app = join(root, "app");
const hidden = { ...process.env, PATH: "/nonexistent", HOME: root };
function run(args: string[], cwd = app, env = process.env) {
  const child = Bun.spawnSync([process.execPath, cli, ...args], {
    cwd,
    env,
    stdout: "pipe",
    stderr: "pipe",
    timeout: 180_000,
  });
  return { code: child.exitCode, out: child.stdout.toString(), err: child.stderr.toString() };
}
// Build once at module scope, then exercise the same cache as build/dev.
const created = run(["new", app], root);
const routes = run(["routes"]);
afterAll(() => rmSync(root, { recursive: true, force: true }));

for (const command of ["routes", "prove", "gen", "doctor"]) {
  test(`${command} has CLI help without requiring tools`, () => {
    const result = run([command, "--help"], root, hidden);
    expect(result.code).toBe(0);
    expect(result.out).toContain(`bendo ${command}`);
  });
}

test("routes builds a real app and shares the build cache; gen validates without writing types", () => {
  expect(created.code).toBe(0);
  expect(routes.code).toBe(0);
  expect(routes.out).toContain("METHOD  PATH\nGET     /");
  expect(run(["routes"]).out).toContain("compile: cache hit");
  const gen = run(["gen"]);
  expect(gen.code).toBe(0);
  expect(gen.out).toContain("validated 1 routes; type generation lands in BND-56");
  expect(existsSync(join(app, ".bendo"))).toBe(false);
  expect(run(["build"]).out).toContain("compile: cache hit");
});

test("doctor lists every missing tool with its installation command outside a project", () => {
  const result = run(["doctor"], root, hidden);
  expect(result.code).toBe(1);
  for (const tool of ["bend", "elan", "lean", "clang", "bun"])
    expect(result.out).toContain(`${tool}: missing\n  Install:`);
  for (const command of [
    "https://bend-lang.com/install.sh",
    "https://elan.lean-lang.org/elan-init.sh",
    "elan toolchain install",
    "sudo apt-get install -y",
    "https://bun.sh/install",
  ])
    expect(result.out).toContain(command);
});

test("doctor never installs a missing pinned Lean toolchain", () => {
  const elan = Bun.which("elan");
  if (elan === null) throw new Error("elan required");
  const home = join(root, "empty-elan");
  const tools = join(home, "bin");
  mkdirSync(tools, { recursive: true });
  copyFileSync(elan, join(tools, "elan"));
  copyFileSync(elan, join(tools, "lean"));
  const result = run(["doctor"], root, {
    ...hidden,
    PATH: tools,
    ELAN_HOME: home,
    ELAN_DIST_SERVER: "http://127.0.0.1:9",
    HTTPS_PROXY: "http://127.0.0.1:9",
    HTTP_PROXY: "http://127.0.0.1:9",
    ALL_PROXY: "http://127.0.0.1:9",
    NO_PROXY: "",
  });
  expect(result.code).toBe(1);
  expect(existsSync(join(home, "toolchains"))).toBe(false);
  expect(result.out).toContain("lean: missing");
  const pin = readFileSync(resolve(import.meta.dir, "../../../lean-toolchain"), "utf8").trim();
  expect(result.out).toContain(`elan toolchain install '${pin}'`);
});

test("elan state parsing reads the resolved pin and installed toolchains", () => {
  const state = parseElanState(
    JSON.stringify({
      toolchains: {
        installed: [{ resolved_name: "leanprover/lean4:v4.34.0", path: "/e/toolchains/x" }],
        resolved_active: { live: { Err: "offline" }, cached: "leanprover/lean4:v4.34.0" },
      },
    }),
  );
  expect(state?.resolved).toBe("leanprover/lean4:v4.34.0");
  expect(state?.installed.get("leanprover/lean4:v4.34.0")).toBe("/e/toolchains/x");
  expect(parseElanState("elan 4.2.4")).toBeNull();
  expect(parseElanState("{}")).toEqual({ resolved: null, installed: new Map() });
});

/** A PATH directory holding the real elan, so pins resolve exactly as elan resolves them. */
function realElan(directory: string): void {
  const elan = Bun.which("elan");
  if (elan === null) throw new Error("elan required");
  copyFileSync(elan, join(directory, "elan"));
}

test("doctor resolves shorthand, custom-origin and linked Lean pins through elan", () => {
  for (const [text, directory, version] of [
    ["v4.99.0", "leanprover--lean4---v4.99.0", "4.99.0"],
    ["4.99.0", "leanprover--lean4---v4.99.0", "4.99.0"],
    ["myorg/lean4:custom", "myorg--lean4---custom", "4.34.0"],
    ["local-linked", "local-linked", "4.34.0"],
  ] as const) {
    const project = mkdtempSync(join(root, "pin-"));
    writeFileSync(join(project, ".bend-version"), "2.8.9\n");
    writeFileSync(join(project, "lean-toolchain"), `${text}\n`);
    fake(project, "bend", "bend 2.8.9");
    realElan(project);
    fake(project, "clang", "clang version 18.1.3");
    fake(project, "bun", "1.4.4");
    const home = join(project, ".elan");
    const bin = join(home, "toolchains", directory, "bin");
    if (directory === "local-linked") {
      // `elan toolchain link` stores a linked toolchain as a symlink; elan only resolves those by name.
      const target = join(project, "linked-build");
      mkdirSync(join(target, "bin"), { recursive: true });
      mkdirSync(join(home, "toolchains"), { recursive: true });
      symlinkSync(target, join(home, "toolchains", directory));
    } else mkdirSync(bin, { recursive: true });
    fake(bin, "lean", `Lean (version ${version}, x86_64)`);
    const result = run(["doctor"], project, { ...hidden, PATH: project, ELAN_HOME: home });
    expect({ text, code: result.code, out: result.out }).toMatchObject({ text, code: 0 });
    expect(result.out).toContain(`lean ${version} at ${bin}/lean: OK`);
  }
});

test("doctor reports an unresolved channel pin with its install command", () => {
  const project = mkdtempSync(join(root, "pin-"));
  writeFileSync(join(project, "lean-toolchain"), "stable\n");
  realElan(project);
  const home = join(project, ".elan");
  mkdirSync(home);
  const result = run(["doctor"], project, { ...hidden, PATH: project, ELAN_HOME: home });
  expect(result.code).toBe(1);
  expect(result.out).toContain("lean: missing");
  expect(result.out).toContain("elan toolchain install 'stable'");
  expect(existsSync(join(home, "toolchains"))).toBe(false);
});

test("doctor selects pinned Lean outside a project without a global default", () => {
  const tools = join(root, "outside-tools");
  mkdirSync(tools);
  const pin = readFileSync(resolve(import.meta.dir, "../../../lean-toolchain"), "utf8").trim();
  const bend = readFileSync(resolve(import.meta.dir, "../../../.bend-version"), "utf8").trim();
  fake(tools, "bend", `bend ${bend}`);
  realElan(tools);
  fake(tools, "clang", "clang version 18.1.3");
  fake(tools, "bun", "1.4.4");
  const home = join(root, "installed-elan");
  const bin = join(home, "toolchains", pin.replaceAll("/", "--").replace(":", "---"), "bin");
  mkdirSync(bin, { recursive: true });
  writeFileSync(
    join(bin, "lean"),
    `#!${process.execPath}
if (process.argv[2] !== '--version' || process.argv.length !== 3) process.exit(1);
console.log(${JSON.stringify(`Lean (version ${pin.replace("leanprover/lean4:v", "")}, x86_64)`)});
`,
    { mode: 0o755 },
  );
  const result = run(["doctor"], root, { ...hidden, PATH: tools, ELAN_HOME: home });
  expect(result.code).toBe(0);
  expect(result.out).toMatch(/lean [0-9.]+ .*: OK/);
});

function fake(directory: string, tool: string, output: string, code = 0) {
  writeFileSync(
    join(directory, tool),
    `#!${process.execPath}\nconsole.log(${JSON.stringify(output)}); process.exit(${code});\n`,
    { mode: 0o755 },
  );
}

test("doctor compares project pins and rejects failed or unparseable version probes", () => {
  const project = join(root, "doctor");
  mkdirSync(project);
  writeFileSync(join(project, ".bend-version"), "2.8.9\n");
  writeFileSync(join(project, "lean-toolchain"), "leanprover/lean4:v4.99.0\n");
  fake(project, "bend", "bend 2.0.1");
  const home = join(project, ".elan");
  const bin = join(home, "toolchains", "leanprover--lean4---v4.99.0", "bin");
  mkdirSync(bin, { recursive: true });
  fake(bin, "lean", "Lean (version 4.34.0, x86_64)");
  realElan(project);
  fake(project, "clang", "Ubuntu clang version 18.1.3");
  fake(project, "bun", "1.4.4");
  const env = { ...hidden, PATH: project, ELAN_HOME: home };
  const mismatch = run(["doctor"], project, env);
  expect(mismatch.code).toBe(1);
  expect(mismatch.out).toContain("mismatch (expected 2.8.9)");
  expect(mismatch.out).toContain("mismatch (expected 4.99.0)");
  fake(project, "bend", "bend 2.8.9");
  fake(bin, "lean", "Lean (version 4.99.0, x86_64)");
  expect(run(["doctor"], project, env).code).toBe(0);
  fake(project, "clang", "nonsense");
  expect(run(["doctor"], project, env).out).toContain("clang: cannot read version");
  fake(project, "clang", "clang version 18.1.3", 7);
  expect(run(["doctor"], project, env).code).toBe(1);
});

test("prove forwards the file/verdict, summarizes diagnostics, and preserves exit code", () => {
  const project = join(root, "proofs");
  mkdirSync(project);
  writeFileSync(
    join(project, "bend"),
    `#!${process.execPath}
if (process.argv[2] === 'version') console.log('bend 2.0.38');
else {
  if (process.argv[2] !== 'custom.bend' || process.argv[3] !== '--verdict') process.exit(9);
  console.error('SOME PROOFS FAIL\\nLaw: route_identity\\nLocation: custom.bend:12\\n    at internal.js:3');
  process.exit(7);
}
`,
    { mode: 0o755 },
  );
  const result = run(["prove", "custom.bend"], project, { ...hidden, PATH: project });
  expect(result.code).toBe(7);
  expect(result.err).toContain("route_identity");
  expect(result.err).toContain("custom.bend:12");
  expect(result.err).not.toContain(" at ");
  fake(project, "bend", "ALL PROOFS CHECK");
  expect(run(["prove"], project, { ...hidden, PATH: project }).out).toContain(
    "PROOF.bend: ALL PROOFS CHECK",
  );
});

test("routes and gen reject malformed manifest envelopes from compiled apps", () => {
  const project = join(root, "invalid");
  mkdirSync(project);
  writeFileSync(join(project, "main.bend"), "import Base\ndef main() -> U32: 1\n");
  const real = Bun.which("bend");
  if (!real) throw new Error("Bend required");
  writeFileSync(
    join(project, "bend"),
    `#!${process.execPath}
if (process.argv[2] === 'version') console.log('bend 2.0.38');
else { await Bun.write(process.argv[4], '#!${process.execPath}\\nconsole.log(process.env.MANIFEST);\\n'); const { chmodSync } = await import('node:fs'); chmodSync(process.argv[4], 0o755); }
`,
    { mode: 0o755 },
  );
  for (const manifest of [
    "bad JSON",
    '{"bendo":2,"routes":[]}',
    '{"bendo":1,"routes":[{"method":4,"path":"/"}]}',
    '{"bendo":1,"routes":[{"method":"GET","path":"bad"}]}',
  ]) {
    for (const command of ["routes", "gen"]) {
      const result = run([command], project, {
        ...process.env,
        PATH: `${project}:${process.env.PATH}`,
        MANIFEST: manifest,
      });
      // Native cache outputs need executable permission, just like real Bend outputs.
      expect(result.code).toBe(1);
      expect(result.err).toContain("Invalid route manifest");
    }
  }
  const extension = run(["routes"], project, {
    ...process.env,
    PATH: `${project}:${process.env.PATH}`,
    MANIFEST: '{"bendo":1,"routes":[{"method":"get","path":"/extension"}]}',
  });
  expect(extension.code).toBe(0);
  expect(extension.out).toContain("get     /extension");
  expect(readFileSync(join(project, "main.bend"), "utf8")).toContain("def main");
});
