// BND-59: `vite build` bundles the fixture app with its Bend code, a library
// build of the same import runs, and the generated declarations typecheck the
// app's `.bend` import (and reject a wrong call).
import { afterAll, expect, test } from "bun:test";
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { build } from "vite";
import bendo from "./index.ts";
import { PACKAGE_DIR, copyFixture } from "./fixture.ts";

const app = copyFixture("build");
afterAll(() => app[Symbol.dispose]());

function field(value: unknown, key: string): unknown {
  return typeof value === "object" && value !== null ? Reflect.get(value, key) : undefined;
}

test("vite build bundles the app with its compiled Bend module", async () => {
  const outDir = app.path("dist");
  await build({
    root: app.root,
    configFile: false,
    logLevel: "silent",
    cacheDir: app.path(".vite"),
    plugins: [bendo()],
    build: { outDir },
  });
  const html = readFileSync(join(outDir, "index.html"), "utf8");
  const script = /<script type="module" crossorigin src="\/(assets\/[^"]+\.js)">/.exec(html)?.[1];
  expect(script).toBeDefined();
  const bundle = readFileSync(join(outDir, script ?? ""), "utf8");
  expect(bundle).toContain("Pick a handle");
  expect(bundle).toContain("is too short.");
  // The HMR branch is dropped from the production bundle.
  expect(bundle).not.toContain("hot-swapped");
  expect(readdirSync(join(outDir, "assets")).some((file) => file.endsWith(".css"))).toBe(true);
});

test("a library build of the same import runs the Bend functions", async () => {
  app.write("src/api.ts", 'export { check, headline, min_length } from "../shared/handle.bend";\n');
  const outDir = app.path("lib");
  await build({
    root: app.root,
    configFile: false,
    logLevel: "silent",
    cacheDir: app.path(".vite"),
    plugins: [bendo()],
    build: {
      outDir,
      minify: true,
      lib: { entry: app.path("src/api.ts"), formats: ["es"], fileName: "api" },
    },
  });
  const module: unknown = await import(pathToFileURL(join(outDir, "api.js")).href);
  const call = (name: string, ...args: unknown[]) => {
    const fn = field(module, name);
    if (typeof fn !== "function") throw new Error(`no export ${name}`);
    return Reflect.apply(fn, undefined, args);
  };
  expect(call("headline")).toBe("Pick a handle");
  expect(call("min_length")).toBe(3);
  expect(call("check", "ab")).toBe(false);
  expect(call("check", "ada")).toBe(true);
});

function tsc(): { code: number; output: string } {
  const run = Bun.spawnSync(
    [
      process.execPath,
      join(PACKAGE_DIR, "../../node_modules/typescript/bin/tsc"),
      "-p",
      app.path("tsconfig.json"),
    ],
    { stdout: "pipe", stderr: "pipe", timeout: 60_000 },
  );
  return { code: run.exitCode, output: `${run.stdout.toString()}${run.stderr.toString()}` };
}

test("the generated declarations typecheck the app's .bend import", () => {
  // The builds above wrote shared/handle.d.bend.ts beside the source.
  expect(app.read("shared/handle.d.bend.ts")).toContain(
    "export declare function check(name: string): boolean;",
  );
  const good = tsc();
  expect(good.output).toBe("");
  expect(good.code).toBe(0);
  app.write(
    "src/wrong.ts",
    'import { check } from "../shared/handle.bend";\nexport const result: string = check(5);\n',
  );
  const bad = tsc();
  expect(bad.code).not.toBe(0);
  expect(bad.output).toContain("src/wrong.ts");
  expect(bad.output).toContain(
    "Argument of type 'number' is not assignable to parameter of type 'string'.",
  );
});
