// BND-58: `bendo build --shared` declarations match Bend's JS ABI. tsc checks
// typed usage (fixtures/abi/usage.ts) against the real compiled output, and
// the same file's checks compare every declared shape with the runtime value.
import { expect, test } from "bun:test";
import { deepStrictEqual } from "node:assert";
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { COMPILE_TEST_TIMEOUT_MS } from "../../../tests/harness.ts";
import { declarations, parseExportTable } from "../src/shared.ts";

const here = import.meta.dir;
const root = resolve(here, "../../..");
const cli = resolve(here, "../src/cli.ts");
const abi = join(here, "fixtures/abi");
const tsc = join(root, "node_modules/.bin/tsc");

function bendo(args: string[], cwd: string): { code: number | null; output: string } {
  const run = Bun.spawnSync([process.execPath, cli, ...args], {
    cwd,
    stdout: "pipe",
    stderr: "pipe",
    timeout: 180_000,
  });
  return { code: run.exitCode, output: `${run.stdout}${run.stderr}` };
}

function typecheck(args: string[]): { code: number | null; output: string } {
  const run = Bun.spawnSync([tsc, ...args], { stdout: "pipe", stderr: "pipe", timeout: 60_000 });
  return { code: run.exitCode, output: `${run.stdout}${run.stderr}` };
}

// Build once, outside any test's timeout, through the CLI itself.
const build = bendo(["build", "--shared", "shared", "--out", "dist"], abi);
const moduleFile = join(abi, "dist/abi.mjs");
const typesFile = join(abi, "dist/abi.d.mts");

test("bendo build --shared writes the module and its declarations", () => {
  expect(build.code, build.output).toBe(0);
  expect(build.output).toContain("build: dist/abi.mjs (38 named exports) and dist/abi.d.mts");
  expect(build.output).not.toContain("warning");
  expect(existsSync(moduleFile)).toBe(true);
  expect(existsSync(typesFile)).toBe(true);
});

test("every compiled export is declared, and named exports match the module", async () => {
  const types = readFileSync(typesFile, "utf8");
  const imported: unknown = await import(pathToFileURL(moduleFile).href);
  if (typeof imported !== "object" || imported === null) throw new Error("no module");
  const runtime = Object.keys(imported).filter((name) => name !== "default");
  const declared = [...types.matchAll(/^export declare function (\w+)/gm)].map((m) => m[1] ?? "");
  expect(runtime.sort()).toEqual(declared.sort());
  const table: unknown = Reflect.get(imported, "default");
  if (typeof table !== "object" || table === null) throw new Error("no default export");
  const keys = [...types.matchAll(/^ {2}readonly ("[^"]+"):/gm)].map((m): string => {
    const key: unknown = JSON.parse(m[1] ?? "");
    if (typeof key !== "string") throw new Error(`invalid key ${m[1]}`);
    return key;
  });
  expect(Object.keys(table)).toEqual(keys);
  // A named export is the default export's own function, not a copy.
  for (const name of runtime) expect(Reflect.get(imported, name)).toBe(Reflect.get(table, name));
});

for (const resolution of ["bundler", "nodenext"])
  test(
    `tsc accepts typed usage and every @ts-expect-error case is an error (${resolution})`,
    () => {
      const flags =
        resolution === "bundler" ? [] : ["--module", "nodenext", "--moduleResolution", "nodenext"];
      const run = typecheck(["-p", join(abi, "tsconfig.json"), ...flags]);
      expect(run.code, run.output).toBe(0);
    },
    COMPILE_TEST_TIMEOUT_MS,
  );

test(
  "tsc reports each negative case once its @ts-expect-error is removed",
  () => {
    const dir = mkdtempSync(join(abi, ".negative-"));
    try {
      const lines = readFileSync(join(abi, "usage.ts"), "utf8").split("\n");
      const directive = (line: string): boolean => line.trim().startsWith("// @ts-expect-error");
      const cases = lines.filter(directive).length;
      const stripped = lines
        .filter((line) => !directive(line))
        .join("\n")
        .replaceAll('"./dist/abi.mjs"', '"../dist/abi.mjs"');
      writeFileSync(join(dir, "usage.ts"), stripped);
      writeFileSync(join(dir, "tsconfig.json"), readFileSync(join(abi, "tsconfig.json")));
      const run = typecheck(["-p", join(dir, "tsconfig.json")]);
      const errors = run.output.match(/^\S+\(\d+,\d+\): error TS\d+/gm) ?? [];
      expect(cases).toBe(18);
      expect(errors.length, run.output).toBe(cases);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  },
  COMPILE_TEST_TIMEOUT_MS,
);

test("runtime values have the declared shapes", async () => {
  const usage: unknown = await import(pathToFileURL(join(abi, "usage.ts")).href);
  if (typeof usage !== "object" || usage === null || !("checks" in usage))
    throw new Error("no checks");
  const checks: unknown = usage.checks;
  if (!Array.isArray(checks)) throw new Error("checks is not an array");
  expect(checks.length).toBe(45);
  for (const check of checks) {
    if (typeof check !== "object" || check === null) throw new Error("invalid check");
    const name: unknown = Reflect.get(check, "name");
    expect(
      () => deepStrictEqual(Reflect.get(check, "actual"), Reflect.get(check, "expected")),
      String(name),
    ).not.toThrow();
  }
});

test("an arity that disagrees with the Bend signature is typed as unknown, with a warning", () => {
  const text = readFileSync(moduleFile, "utf8");
  // Rebuild Bend's table from the emitted module, then claim a wrong arity.
  const rows = [...text.matchAll(/^ {2}("[^"]+"): (run_lib\(.*, \d+\)),$/gm)].map(
    (m) => `  ${m[1]}: ${m[1] === '"greet"' ? m[2]?.replace(/, 1\)$/, ", 2)") : m[2]},`,
  );
  const table = parseExportTable(`function x() {}\nexport default {\n${rows.join("\n")}\n};\n`);
  const typed = declarations(join(abi, "shared/abi.bend"), table);
  expect(typed.warnings).toEqual([
    "greet: compiled with 2 arguments, but its Bend signature reads as 1; typed as unknown",
  ]);
  expect(typed.named).not.toContain("greet");
  expect(typed.text).toContain('readonly "greet": (...args: unknown[]) => unknown;');
});

test(
  "shared code that returns IO, directly or through an alias, is refused",
  () => {
    const out = mkdtempSync(join(tmpdir(), "bendo-impure-"));
    try {
      const run = bendo(
        ["build", "--shared", "shared", "--out", out],
        join(here, "fixtures/impure"),
      );
      expect(run.code).toBe(1);
      expect(run.output).toContain(
        "shared code must be pure, but `announce`, `shout`, `later`, `remote` return IO",
      );
      expect(existsSync(join(out, "impure.mjs"))).toBe(false);
    } finally {
      rmSync(out, { recursive: true, force: true });
    }
  },
  COMPILE_TEST_TIMEOUT_MS,
);

test("bendo build --shared reports a missing directory and bad arguments", () => {
  const missing = bendo(["build", "--shared", "nowhere"], abi);
  expect(missing.code).toBe(1);
  expect(missing.output).toContain("nowhere: no such directory");
  const out = bendo(["build", "--shared", "--out"], abi);
  expect(out.code).toBe(1);
  expect(out.output).toContain("--out needs a directory");
  const extra = bendo(["build", "--shared", "a", "b"], abi);
  expect(extra.code).toBe(1);
  expect(extra.output).toContain("Unexpected arguments");
});
