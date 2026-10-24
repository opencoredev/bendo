// BND-37: a compiled app prints its route schemas with --bendo-routes, and the
// CLI's manifest parser keeps them for type generation (BND-56).
import { describe, expect, test } from "bun:test";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fetchManifest, parseManifest } from "../packages/bendo/src/manifest.ts";
import { build, start } from "./harness.ts";
import { loadConsumer, validators, type Schema } from "./json-schema-support.ts";

// Compile once, outside any test's timeout, through the shared fixture cache.
const binary = build("tests/fixtures/json-schema/app.bend");
const bend = await loadConsumer();

function run(mode: string) {
  const r = Bun.spawnSync([binary, "--bendo-routes"], {
    env: { ...process.env, BENDO_FIXTURE_SCHEMAS: mode },
    stdout: "pipe",
    stderr: "pipe",
    timeout: 10_000,
  });
  return { code: r.exitCode, out: r.stdout.toString(), err: r.stderr.toString() };
}

const printed = run("");

// The fixture's query schema, rebuilt here to compare both targets' output.
const listQuery: Schema = {
  kind: "object",
  strict: false,
  fields: [
    {
      key: "limit",
      schema: { kind: "integer", min: "1", max: "100" },
      presence: { kind: "default", value: { kind: "number", token: "10" } },
    },
    {
      key: "tag",
      schema: {
        kind: "array",
        items: { kind: "string", min: 1, max: 40, pattern: null, format: "plain" },
        min: 0,
        max: null,
      },
      presence: { kind: "optional" },
    },
  ],
};

describe("--bendo-routes with schemas", () => {
  test("exits 0 and keeps the version-1 rows in registration order", () => {
    expect(printed.code).toBe(0);
    expect(printed.err).toBe("");
    const manifest = parseManifest(printed.out);
    expect(manifest.routes.map((r) => [r.method, r.path, r.params, r.all])).toEqual([
      ["GET", "/todos", [], false],
      ["GET", "/todos/:id{int}", ["id"], false],
      ["POST", "/todos", [], false],
      ["PUT", "/todos/:id{int}", ["id"], false],
      ["PATCH", "/todos/:id{int}", ["id"], false],
      ["GET", "/dup", [], false],
      ["GET", "/dup", [], false],
      ["GET", "/health", [], false],
      ["ALL", "/status", [], true],
    ]);
    expect(manifest.routes.map((r) => Object.keys(r.schemas))).toEqual([
      ["query", "response"],
      ["params", "response"],
      ["headers", "body", "response"],
      ["params", "body"],
      ["params", "body"],
      ["response"],
      ["response"],
      [],
      ["response"],
    ]);
  });

  test("rows without schemas print exactly as before", () => {
    const text = printed.out;
    expect(text).toContain('{"method":"GET","path":"/health","params":[]}');
    expect(text.startsWith('{"bendo":1,"routes":[')).toBe(true);
  });

  test("schemas are positional: duplicates keep their own, methods of one registration share", () => {
    const manifest = parseManifest(printed.out);
    const [, , , put, patch, first, second] = manifest.routes;
    expect(first?.schemas.response).toMatchObject({ const: "first" });
    expect(second?.schemas.response).toMatchObject({ const: "second" });
    expect(put?.schemas).toEqual(patch?.schemas ?? {});
  });

  test("the native binary prints the same documents as the .mjs exporter", () => {
    const manifest = parseManifest(printed.out);
    expect(manifest.routes[0]?.schemas.query).toEqual(Object(bend.document(listQuery)));
  });

  test("every slot is a valid 2020-12 schema that validates like the decoder", () => {
    const manifest = parseManifest(printed.out);
    for (const { ajv } of validators()) {
      for (const route of manifest.routes)
        for (const schema of Object.values(route.schemas))
          expect(ajv.validateSchema(schema)).toBe(true);
      const body = ajv.compile(Object(manifest.routes[3]?.schemas.body));
      expect(body({ title: "x" })).toBe(true);
      expect(body({ title: "x", priority: 3, tags: ["a-1"] })).toBe(true);
      expect(body({ title: "x", extra: 1 })).toBe(false);
      expect(body({ title: "x", tags: ["A"] })).toBe(false);
      expect(body({ title: "x", priority: 4 })).toBe(false);
      expect(body({})).toBe(false);
      const status = ajv.compile(Object(manifest.routes[8]?.schemas.response));
      for (const ok of ["ok", null, 0, 100]) expect(status(ok)).toBe(true);
      for (const bad of ["no", 101, -1, true]) expect(status(bad)).toBe(false);
      const todos = ajv.compile(Object(manifest.routes[0]?.schemas.response));
      expect(todos([{ id: 1, title: "t", done: false, link: "https://a.b/c", owner: "a@b" }])).toBe(
        true,
      );
      expect(todos([{ id: 1, title: "t", done: false, link: "ftp://a" }])).toBe(false);
      expect(todos([{ id: 1, title: "t", done: false, owner: "a@@b" }])).toBe(false);
    }
    const body = manifest.routes[3]?.schemas.body;
    expect(body).toMatchObject({
      required: ["title"],
      additionalProperties: false,
      properties: {
        done: { type: "boolean", default: false },
        priority: { enum: [1, 2, 3], default: 2 },
      },
    });
    expect(manifest.routes[8]?.schemas.response).toMatchObject({ anyOf: [{}, {}, { not: {} }] });
  });

  test("a schema count that misses a registration fails without printing a manifest", () => {
    const short = run("short");
    expect(short).toEqual({
      code: 1,
      out: "",
      err: "bendo: route schemas: 8 route registrations but 7 schema entries\n",
    });
    expect(() => fetchManifest(binary)).not.toThrow();
  });

  test("an invalid schema fails and names its route and slot", () => {
    expect(run("invalid")).toEqual({
      code: 1,
      out: "",
      err: "bendo: route schemas: route 2 has an invalid body schema\n",
    });
  });

  test("the app still serves normally", async () => {
    await using server = await start(binary);
    const res = await fetch(`${server.url}/health`);
    expect(res.status).toBe(200);
    expect(await res.text()).toBe("ok");
  });
});

describe("the CLI manifest parser", () => {
  test("keeps params, all and schemas, and ignores unknown slots and fields", () => {
    expect(
      parseManifest(
        '{"bendo":1,"x":1,"routes":[{"method":"ALL","all":true,"path":"/a/:id","params":["id"],"schemas":{"body":{"type":"string"},"response":false,"later":{}},"extra":2},{"method":"GET","path":"/b"}]}',
      ),
    ).toEqual({
      bendo: 1,
      routes: [
        {
          method: "ALL",
          path: "/a/:id",
          params: ["id"],
          all: true,
          schemas: { body: { type: "string" }, response: false },
        },
        { method: "GET", path: "/b", params: [], all: false, schemas: {} },
      ],
    });
  });

  test("rejects malformed params, flags and schema slots", () => {
    for (const route of [
      '{"method":"GET","path":"/","params":"id"}',
      '{"method":"GET","path":"/","params":[1]}',
      '{"method":"GET","path":"/","all":"yes"}',
      '{"method":"GET","path":"/","schemas":[]}',
      '{"method":"GET","path":"/","schemas":{"body":"string"}}',
      '{"method":"GET","path":"/","schemas":{"query":null}}',
    ])
      expect(() => parseManifest(`{"bendo":1,"routes":[${route}]}`)).toThrow(
        "Invalid route manifest",
      );
  });

  test("fetchManifest reports the app's own error", () => {
    const dir = mkdtempSync(join(tmpdir(), "bendo-json-schema-"));
    try {
      const wrapper = join(dir, "app");
      writeFileSync(wrapper, `#!/bin/sh\nBENDO_FIXTURE_SCHEMAS=invalid exec '${binary}' "$@"\n`, {
        mode: 0o755,
      });
      expect(() => fetchManifest(wrapper)).toThrow("route 2 has an invalid body schema");
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });
});
