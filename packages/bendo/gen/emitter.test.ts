import { expect, test } from "bun:test";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import manifestData from "./manifest.json" with { type: "json" };
import { parseManifest } from "../src/manifest.ts";
import { emitRouteTypes, writeRouteTypes } from "../src/route-types.ts";

const manifest = parseManifest(JSON.stringify(manifestData));
const source = emitRouteTypes(manifest);
const golden = readFileSync(join(import.meta.dir, "routes.ts.txt"), "utf8");

test("the complete supported vocabulary has stable golden output with no any", () => {
  expect(source).toBe(golden);
  expect(source).not.toMatch(/\bany\b/);
  expect(emitRouteTypes(manifest)).toBe(source);
  expect(emitRouteTypes({ bendo: 1, routes: [] })).toContain("export type Routes = never;");
});

test("ordering keeps registrations, duplicates and unions but sorts object keys", () => {
  const rows = manifest.routes;
  const first = rows[0];
  if (first === undefined) throw new Error("fixture must have a route");
  expect(
    emitRouteTypes({ bendo: 1, routes: [first, first] }).match(/method: "POST"/g),
  ).toHaveLength(2);
  const reversed = JSON.stringify(manifestData, (_key, value: unknown) => {
    if (typeof value === "object" && value !== null && !Array.isArray(value))
      return Object.fromEntries(Object.entries(value).reverse());
    return value;
  });
  expect(emitRouteTypes(parseManifest(reversed))).toBe(source);
});

for (const schema of [
  { $ref: "#/x" },
  { type: "array", items: { surprise: 1 } },
  { type: "string", not: { surprise: 1 } },
  { type: "string", allOf: [{ surprise: 1 }] },
  { anyOf: [{ type: "boolean" }, { surprise: 1 }] },
  { type: "object", properties: { x: { surprise: 1 } }, required: [], additionalProperties: false },
]) {
  test(`unknown keywords fail with route and slot: ${JSON.stringify(schema)}`, () => {
    const input = parseManifest(
      JSON.stringify({
        bendo: 1,
        routes: [{ method: "PATCH", path: "/bad", schemas: { body: schema } }],
      }),
    );
    expect(() => emitRouteTypes(input)).toThrow(
      /route 1 PATCH \/bad body.*keyword "(?:\$ref|surprise)"/,
    );
  });
}

for (const schema of [
  { type: "something" },
  { enum: [] },
  { anyOf: [] },
  { type: "array" },
  { type: "object", properties: {}, required: ["missing"], additionalProperties: false },
  { type: "object", properties: {}, required: [], additionalProperties: {} },
  { type: "string", not: { type: "number" } },
  { pattern: 1 },
  { minItems: -1 },
  { $schema: "old" },
]) {
  test(`malformed supported vocabulary fails loudly: ${JSON.stringify(schema)}`, () => {
    const input = parseManifest(
      JSON.stringify({
        bendo: 1,
        routes: [{ method: "GET", path: "/bad", schemas: { response: schema } }],
      }),
    );
    expect(() => emitRouteTypes(input)).toThrow("route 1 GET /bad response");
  });
}

test("failed generation preserves the last complete output", () => {
  const directory = mkdtempSync(join(tmpdir(), "bendo-types-"));
  try {
    const output = join(directory, "routes.ts");
    writeRouteTypes(manifest, output);
    const invalid = parseManifest(
      '{"bendo":1,"routes":[{"method":"GET","path":"/bad","schemas":{"body":{"oops":true}}}]}',
    );
    expect(() => writeRouteTypes(invalid, output)).toThrow("oops");
    expect(readFileSync(output, "utf8")).toBe(source);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

test("generated types satisfy strict positive and negative consumer assertions", () => {
  const directory = mkdtempSync(join(tmpdir(), "bendo-types-tsc-"));
  try {
    writeFileSync(join(directory, "routes.ts"), source);
    writeFileSync(
      join(directory, "consumer.ts"),
      readFileSync(join(import.meta.dir, "consumer.ts.txt")),
    );
    writeFileSync(
      join(directory, "tsconfig.json"),
      JSON.stringify({
        compilerOptions: {
          strict: true,
          noEmit: true,
          exactOptionalPropertyTypes: true,
          types: [],
          target: "ES2023",
          module: "Preserve",
          moduleResolution: "bundler",
        },
        files: ["routes.ts", "consumer.ts"],
      }),
    );
    const result = Bun.spawnSync(
      [
        process.execPath,
        resolve(import.meta.dir, "../../../node_modules/typescript/bin/tsc"),
        "-p",
        directory,
      ],
      { stdout: "pipe", stderr: "pipe", timeout: 20_000 },
    );
    expect(`${result.stdout}${result.stderr}`).toBe("");
    expect(result.exitCode).toBe(0);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

// The exact-decimal Bend exporter can print valid JSON numbers beyond doubles.
test("overflowing numeric annotations still generate number types", () => {
  const input = parseManifest(
    '{"bendo":1,"routes":[{"method":"POST","path":"/huge","schemas":{"body":{"type":"object","properties":{"value":{"type":"number","maximum":1e400,"default":1e400}},"required":[],"additionalProperties":false},"headers":{"type":"string","minLength":1e400},"response":{"const":1e400}}}]}',
  );
  const result = emitRouteTypes(input);
  expect(result).toContain('body: { "value"?: number; };');
  expect(result).toContain('body: { "value": number; };');
  expect(result).toContain("response: number;");
  expect(result).not.toContain("Infinity");
});
