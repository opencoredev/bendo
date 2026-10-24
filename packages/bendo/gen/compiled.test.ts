import { expect, test } from "bun:test";
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { join, relative, resolve } from "node:path";
import { build } from "../../../tests/harness.ts";
import { fetchManifest } from "../src/manifest.ts";
import { emitRouteTypes } from "../src/route-types.ts";

const repo = resolve(import.meta.dir, "../../..");
const cli = join(repo, "packages/bendo/src/cli.ts");

// All real compilation uses the harness cache's 180s per-target budget. Build
// outside the test timeout; the CLI separately exercises its production cache.
const binary = build("tests/fixtures/json-schema/app.bend");
const fixtureTypes = emitRouteTypes(fetchManifest(binary));

test("BND-37's compiled manifest produces the pinned route types", () => {
  expect(fixtureTypes).toBe(readFileSync(join(import.meta.dir, "compiled.ts.txt"), "utf8"));
  expect(fixtureTypes).toContain('"id": number;');
  expect(fixtureTypes).toContain('"limit"?: (number | string);');
  expect(fixtureTypes).toContain('"limit": number;');
});

test("changing a real Bend schema and rerunning bendo gen changes the TypeScript type", () => {
  const directory = mkdtempSync(join(repo, "tests/fixtures/gen-schema-"));
  try {
    const entry = join(directory, "main.bend");
    const original = readFileSync(
      join(repo, "tests/fixtures/json-schema/app.bend"),
      "utf8",
    ).replaceAll("../../../src/", `${repo}/src/`);
    // Imports must remain local relative paths for both dependency graph caches.
    const source = original.replaceAll(`import ${repo}/src/`, `import ${relativeSrc(directory)}/`);
    writeFileSync(entry, source);
    const run = () =>
      Bun.spawnSync([process.execPath, cli, "gen", entry], {
        cwd: directory,
        stdout: "pipe",
        stderr: "pipe",
        timeout: 200_000,
      });
    const first = run();
    expect(`${first.stdout}${first.stderr}`).toContain("wrote .bendo/routes.ts (9 routes)");
    expect(first.exitCode).toBe(0);
    const output = join(directory, ".bendo/routes.ts");
    expect(existsSync(output)).toBe(true);
    expect(readFileSync(output, "utf8")).toBe(fixtureTypes);
    const mutated = source.replace(
      'S.IntegerSchema{Some{"1"}, None{}}',
      "S.StringSchema{1n, None{}, None{}, S.Plain{}}",
    );
    expect(mutated).not.toBe(source);
    writeFileSync(entry, mutated);
    // This same changed source is a genuine native fixture cached by the harness.
    const changedBinary = build(entry);
    expect(changedBinary).not.toBe(binary);
    const changedTypes = emitRouteTypes(fetchManifest(changedBinary));
    const second = run();
    expect(second.exitCode).toBe(0);
    expect(`${second.stdout}${second.stderr}`).toContain("wrote .bendo/routes.ts (9 routes)");
    const changed = readFileSync(output, "utf8");
    expect(changed).toBe(changedTypes);
    expect(changed).not.toBe(fixtureTypes);
    expect(changed).toContain('"id": string;');
    expect(changed).not.toContain('"id": number;');
    // A consumer of the changed type accepts strings and rejects the old number.
    writeFileSync(
      join(directory, "consumer.ts"),
      `import type { Routes } from "./.bendo/routes";\ntype Params = Extract<Routes, { method: "GET"; path: "/todos/:id{int}" }>["output"]["params"];\nconst id: Params = { id: "one" };\n// @ts-expect-error the schema changed from integer to string\nconst old: Params = { id: 1 };\n`,
    );
    writeFileSync(
      join(directory, "tsconfig.json"),
      JSON.stringify({
        compilerOptions: {
          strict: true,
          noEmit: true,
          types: [],
          target: "ES2023",
          module: "Preserve",
          moduleResolution: "bundler",
        },
        files: ["consumer.ts"],
      }),
    );
    const checked = Bun.spawnSync(
      [process.execPath, join(repo, "node_modules/typescript/bin/tsc"), "-p", directory],
      { stdout: "pipe", stderr: "pipe", timeout: 20_000 },
    );
    expect(`${checked.stdout}${checked.stderr}`).toBe("");
    expect(checked.exitCode).toBe(0);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
}, 600_000);

function relativeSrc(directory: string): string {
  const path = relative(directory, join(repo, "src"));
  return path.startsWith(".") ? path : `./${path}`;
}
