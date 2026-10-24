// BND-62: OpenAPI 3.1 from the route manifest, and the /docs page that renders
// it with Scalar. Goldens update with BENDO_UPDATE_GOLDEN=1.
import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { Validator } from "@seriousme/openapi-schema-validator";
import Ajv2020 from "ajv/dist/2020";
import { fetchManifest, parseManifest } from "../packages/bendo/src/manifest.ts";
import { parseOpenApiArgs } from "../packages/bendo/src/openapi-command.ts";
import {
  bendModule,
  documentText,
  generateOpenApi,
  parseOpenApiConfig,
  parsePattern,
  type License,
} from "../packages/bendo/src/openapi.ts";
import { build, start, type RunningServer } from "./harness.ts";

const ROOT = resolve(import.meta.dir, "..");
const FIXTURE = join(ROOT, "tests/fixtures/openapi");
const CLI = join(ROOT, "packages/bendo/src/cli.ts");
const UPDATE = process.env.BENDO_UPDATE_GOLDEN === "1";

// Compile once, outside any test's timeout, through the shared fixture cache.
const binary = build("tests/fixtures/openapi/app.bend");
const manifest = fetchManifest(binary);
const config = parseOpenApiConfig(
  JSON.parse(readFileSync(join(FIXTURE, "openapi.config.json"), "utf8")),
);
const fixture = generateOpenApi(manifest, config);

function golden(path: string, actual: string): void {
  if (UPDATE) writeFileSync(path, actual);
  expect(actual).toBe(readFileSync(path, "utf8"));
}

async function validate(document: unknown): Promise<{ valid: boolean; errors?: unknown }> {
  const parsed: unknown = JSON.parse(JSON.stringify(document));
  if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed))
    throw new Error("not a JSON object");
  return new Validator().validate(Object.fromEntries(Object.entries(parsed)));
}

/** Every Schema Object in a document, with its JSON pointer. */
function schemas(document: unknown): { at: string; schema: unknown }[] {
  const found: { at: string; schema: unknown }[] = [];
  const walk = (value: unknown, at: string): void => {
    if (Array.isArray(value)) value.forEach((item, i) => walk(item, `${at}/${i}`));
    else if (typeof value === "object" && value !== null)
      for (const [key, member] of Object.entries(value)) {
        if (key === "schema") found.push({ at: `${at}/schema`, schema: member });
        else walk(member, `${at}/${key}`);
      }
  };
  walk(document, "");
  return found;
}

describe("patterns", () => {
  test("every segment form parses", () => {
    expect(parsePattern("/a/:id{int}/:s{slug}/:u{uuid}/:c{[a-z-]+}/:y{[0-9]{04}}/:o?")).toEqual([
      { kind: "static", text: "a" },
      { kind: "param", name: "id", constraint: { kind: "int" }, optional: false },
      { kind: "param", name: "s", constraint: { kind: "slug" }, optional: false },
      { kind: "param", name: "u", constraint: { kind: "uuid" }, optional: false },
      {
        kind: "param",
        name: "c",
        constraint: { kind: "class", members: "a-z-", repeat: { kind: "plus" } },
        optional: false,
      },
      {
        kind: "param",
        name: "y",
        constraint: { kind: "class", members: "0-9", repeat: { kind: "exactly", count: "4" } },
        optional: false,
      },
      { kind: "param", name: "o", constraint: null, optional: true },
    ]);
    expect(parsePattern("*")).toEqual([{ kind: "wildcard", name: "*", final: true }]);
    expect(parsePattern("/a/*/b/*rest")).toEqual([
      { kind: "static", text: "a" },
      { kind: "wildcard", name: null, final: false },
      { kind: "static", text: "b" },
      { kind: "wildcard", name: "rest", final: true },
    ]);
    expect(parsePattern("/:p{.+}/x/assets*")).toEqual([
      { kind: "span", name: "p" },
      { kind: "static", text: "x" },
      { kind: "prefix", text: "assets" },
    ]);
    expect(parsePattern("/v1/name:activate//")).toEqual([
      { kind: "static", text: "v1" },
      { kind: "static", text: "name:activate" },
      { kind: "static", text: "" },
      { kind: "static", text: "" },
    ]);
    expect(() => parsePattern("/:x{float}")).toThrow("Unsupported constraint {float}");
  });
});

describe("golden documents", () => {
  test("defaults: no config, every fallback and warning", () => {
    const input = parseManifest(
      readFileSync(join(FIXTURE, "golden/defaults.manifest.json"), "utf8"),
    );
    const { document, warnings } = generateOpenApi(input);
    golden(join(FIXTURE, "golden/defaults.openapi.json"), documentText(document));
    expect(warnings).toEqual([
      "GET /users/:name{slug}: GET /users/{id} is already documented by an earlier route, which the router tries first; it is left out",
      "GET /search: the query schema is not an object with properties, so it has no parameters",
      "GET /search: OpenAPI ignores a header parameter named Accept; it is left out",
      "GET /any: GET /any is already documented by an earlier route, which the router tries first; it is left out",
      "QUERY /any: OpenAPI 3.1 has no operation for the QUERY method; it is left out",
      "get /lower: OpenAPI 3.1 has no operation for the get method; it is left out",
    ]);
    expect(document.info).toEqual({ title: "Bendo API", version: "0.0.0" });
    expect(document.servers).toBeUndefined();
    // An optional chain gives one path per prefix of the chain.
    expect(Object.keys(document.paths)).toContain("/{a}/{b}");
    expect(document.paths["/"]?.options?.["x-bendo-route"]).toBe("OPTIONS /:a?/:b?");
  });

  test("the fixture's committed document and Bend module match its compiled manifest", () => {
    golden(join(FIXTURE, "openapi.json"), documentText(fixture.document));
    golden(join(FIXTURE, "openapi-doc.bend"), bendModule(documentText(fixture.document, 0)));
    expect(fixture.warnings).toEqual([
      "POST /todos: OpenAPI ignores a header parameter named authorization; it is left out",
      "GET /dup: GET /dup is already documented by an earlier route, which the router tries first; it is left out",
      "PURGE /cache: OpenAPI 3.1 has no operation for the PURGE method; it is left out",
    ]);
  });

  test("route patterns become OpenAPI templates", () => {
    const paths = fixture.document.paths;
    expect(Object.keys(paths)).toEqual([
      "/todos",
      "/todos/{id}",
      "/dup",
      "/users/{user}",
      "/posts/{slug}",
      "/tags/{name}",
      "/archive/{year}",
      "/archive/{year}/{month}",
      "/v1",
      "/v1/{version}",
      "/v1/{version}/{platform}",
      "/files/{path}",
      "/a/{wildcard}/b",
      "/assets{suffix}",
      "/{prefix}/contents",
      "/{prefix}/contents/{id}",
      "/status",
      "/kinds",
      "/{wildcard}",
    ]);
    const param = (path: string, method: "get" | "delete", name: string) =>
      paths[path]?.[method]?.parameters?.find((p) => p.name === name);
    // The params slot wins over the constraint; constraints fill in otherwise.
    expect(param("/todos/{id}", "get", "id")?.schema).toEqual({
      type: "integer",
      minimum: 1,
      $comment: "Bendo accepts only integer tokens -?(0|[1-9][0-9]*); 1.0 and 1e0 are rejected",
    });
    expect(param("/users/{user}", "get", "user")?.schema).toMatchObject({
      type: "string",
      format: "uuid",
    });
    expect(param("/posts/{slug}", "get", "slug")?.schema).toEqual({
      type: "string",
      pattern: "^[a-z0-9-]+$",
    });
    expect(param("/tags/{name}", "get", "name")?.schema).toEqual({
      type: "string",
      pattern: "^[a-z0-9-]+$",
    });
    expect(param("/archive/{year}/{month}", "get", "year")?.schema).toEqual({
      type: "string",
      pattern: "^[0-9]{4}$",
    });
    expect(param("/archive/{year}/{month}", "get", "month")?.schema).toEqual({
      type: "string",
      pattern: "^-?[0-9]+$",
    });
    expect(param("/v1/{version}", "get", "version")?.schema).toEqual({ enum: ["1", "2"] });
    expect(param("/{prefix}/contents", "get", "prefix")?.description).toContain("may contain `/`");
    // DELETE /todos/:todo_id shares /todos/{id}, so it takes that spelling.
    expect(param("/todos/{id}", "delete", "id")).toMatchObject({ in: "path", required: true });
    expect(paths["/todos/{id}"]?.delete?.["x-bendo-route"]).toBe("DELETE /todos/:todo_id");
    expect(Object.keys(paths["/todos/{id}"] ?? {})).toEqual(["get", "put", "patch", "delete"]);
    // `all` documents the configured methods; the duplicate /dup keeps the first.
    expect(Object.keys(paths["/status"] ?? {})).toEqual(["get", "post", "put", "patch", "delete"]);
    expect(paths["/status"]?.put?.["x-bendo-all"]).toBe(true);
    expect(paths["/dup"]?.get?.responses["200"]?.content?.["application/json"].schema).toEqual({
      const: "first",
    });
    for (const item of Object.values(paths))
      for (const operation of Object.values(item))
        for (const p of operation.parameters ?? [])
          if (p.in === "path") expect(p.required).toBe(true);
  });

  test("slots become parameters, bodies and responses", () => {
    const list = fixture.document.paths["/todos"]?.get;
    expect(list?.parameters?.map((p) => [p.name, p.in, p.required])).toEqual([
      ["limit", "query", false],
      ["tag", "query", false],
      ["done", "query", false],
    ]);
    const create = fixture.document.paths["/todos"]?.post;
    expect(create?.parameters).toEqual([
      {
        name: "x-api-key",
        in: "header",
        required: true,
        schema: expect.objectContaining({ type: "string" }),
      },
    ]);
    expect(create?.requestBody?.required).toBe(true);
    expect(create?.requestBody?.content["application/json"].schema).toMatchObject({
      type: "object",
      required: ["title"],
      additionalProperties: false,
    });
    expect(create?.summary).toBe("Create a todo");
    expect(fixture.document.paths["/todos/{id}"]?.get?.operationId).toBe("getTodo");
    expect(fixture.document.paths["/todos/{id}"]?.put?.responses).toEqual({
      default: { description: "Response" },
    });
    expect(fixture.document.paths["/kinds"]?.get).toMatchObject({
      deprecated: true,
      tags: ["schemas"],
    });
    // OpenAPI 3.1 schemas are 2020-12; the slot's $schema member is dropped.
    expect(JSON.stringify(fixture.document)).not.toContain("$schema");
    expect(fixture.document.tags?.[0]).toEqual({
      name: "todos",
      description: "A todo list with validated bodies.",
    });
    const ids = Object.values(fixture.document.paths).flatMap((item) =>
      Object.values(item).map((o) => o.operationId),
    );
    expect(new Set(ids).size).toBe(ids.length);
  });
});

describe("validation", () => {
  test("the fixture document passes the OpenAPI 3.1 schema validator", async () => {
    const result = await validate(fixture.document);
    expect(result.errors).toBeUndefined();
    expect(result.valid).toBe(true);
  });

  test("the defaults golden passes too", async () => {
    const input = parseManifest(
      readFileSync(join(FIXTURE, "golden/defaults.manifest.json"), "utf8"),
    );
    expect((await validate(generateOpenApi(input).document)).valid).toBe(true);
  });

  test("the validator rejects a broken document", async () => {
    const broken = structuredClone(fixture.document);
    Object.assign(broken.paths, {
      "/x/{id}": { get: { responses: {}, parameters: [{ name: "id", in: "path" }] } },
    });
    expect((await validate(broken)).valid).toBe(false);
  });

  test("every embedded Schema Object compiles under JSON Schema 2020-12", () => {
    const ajv = new Ajv2020({ strict: true, allErrors: true });
    const found = schemas(fixture.document);
    expect(found.length).toBe(37);
    for (const { at, schema } of found) {
      const ok = ajv.validateSchema(Object(schema));
      if (!ok) throw new Error(`${at}: ${ajv.errorsText()}`);
    }
  });
});

describe("config and CLI", () => {
  test("config parsing rejects unknown and mistyped members", () => {
    expect(() => parseOpenApiConfig({ title: "x" })).toThrow("unknown member title");
    expect(() => parseOpenApiConfig({ info: { title: 1 } })).toThrow("info.title must be a string");
    expect(() => parseOpenApiConfig({ servers: [{}] })).toThrow("servers[0] needs a url");
    expect(() => parseOpenApiConfig({ allMethods: ["GET"] })).toThrow("allMethods has GET");
    expect(() =>
      parseOpenApiConfig({
        info: {
          license: { name: "MIT", identifier: "MIT", url: "https://opensource.org/license/mit" },
        },
      }),
    ).toThrow("info.license takes an identifier or a url, not both");
    const named: License = { name: "MIT" };
    const spdx: License = { name: "MIT", identifier: "MIT" };
    const linked: License = { name: "MIT", url: "https://opensource.org/license/mit" };
    // @ts-expect-error OpenAPI 3.1 forbids a license with both an identifier and a url.
    const both: License = {
      name: "MIT",
      identifier: "MIT",
      url: "https://opensource.org/license/mit",
    };
    expect([named, spdx, linked, both]).toHaveLength(4);
    expect(
      parseOpenApiConfig({ info: { license: { name: "MIT", identifier: "MIT" } } }).info?.license,
    ).toEqual({
      name: "MIT",
      identifier: "MIT",
    });
    expect(
      parseOpenApiConfig({ servers: [{ url: "https://api.example.com" }], autoTags: false }),
    ).toEqual({
      servers: [{ url: "https://api.example.com", description: undefined }],
      autoTags: false,
      info: undefined,
      tags: undefined,
      allMethods: undefined,
      exclude: undefined,
      operations: undefined,
    });
  });

  test("argument parsing", () => {
    expect(parseOpenApiArgs([])).toEqual({
      entry: "main.bend",
      out: "openapi.json",
      bend: null,
      config: null,
      manifest: null,
    });
    expect(parseOpenApiArgs(["app.bend", "--bend", "doc.bend", "--out", "api.json"])).toMatchObject(
      {
        entry: "app.bend",
        bend: "doc.bend",
        out: "api.json",
      },
    );
    expect(() => parseOpenApiArgs(["--out"])).toThrow("--out needs a value");
    expect(() => parseOpenApiArgs(["a.bend", "--manifest", "m.json"])).toThrow("not both");
    expect(() => parseOpenApiArgs(["--nope"])).toThrow("Unexpected argument --nope");
  });

  test("bendo openapi writes the document and module, using package.json and config", () => {
    const dir = mkdtempSync(join(tmpdir(), "bendo-openapi-"));
    try {
      writeFileSync(
        join(dir, "manifest.json"),
        JSON.stringify({ bendo: 1, routes: manifest.routes }),
      );
      writeFileSync(
        join(dir, "package.json"),
        JSON.stringify({ name: "my-api", version: "2.3.4" }),
      );
      writeFileSync(
        join(dir, "openapi.config.json"),
        JSON.stringify({ servers: [{ url: "https://api.example.com" }] }),
      );
      const run = Bun.spawnSync(
        ["bun", CLI, "openapi", "--manifest", "manifest.json", "--bend", "doc.bend"],
        {
          cwd: dir,
          stdout: "pipe",
          stderr: "pipe",
          timeout: 30_000,
        },
      );
      expect(run.exitCode).toBe(0);
      expect(run.stdout.toString()).toBe(
        "openapi: 23 paths, 31 operations; wrote openapi.json and doc.bend\n",
      );
      expect(run.stderr.toString()).toContain("openapi: warning: PURGE /cache");
      const written = JSON.parse(readFileSync(join(dir, "openapi.json"), "utf8"));
      expect(written.info).toEqual({ title: "my-api", version: "2.3.4" });
      expect(written.servers).toEqual([{ url: "https://api.example.com" }]);
      expect(readFileSync(join(dir, "doc.bend"), "utf8")).toStartWith(
        "# Generated by `bendo openapi --bend`",
      );

      writeFileSync(join(dir, "openapi.config.json"), JSON.stringify({ info: { title: 3 } }));
      const bad = Bun.spawnSync(["bun", CLI, "openapi", "--manifest", "manifest.json"], {
        cwd: dir,
        stdout: "pipe",
        stderr: "pipe",
        timeout: 30_000,
      });
      expect(bad.exitCode).toBe(1);
      expect(bad.stderr.toString()).toBe("OpenAPI config: info.title must be a string\n");
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });
});

describe("compiled server", () => {
  let server: RunningServer;
  beforeAll(async () => {
    server = await start(binary);
  });
  afterAll(async () => {
    await server?.[Symbol.asyncDispose]();
  });

  test("GET /openapi.json serves the embedded document", async () => {
    const res = await fetch(`${server.url}/openapi.json`);
    expect(res.status).toBe(200);
    expect(res.headers.get("content-type")).toBe("application/json; charset=utf-8");
    const text = await res.text();
    expect(text).toBe(documentText(fixture.document, 0).trimEnd());
    const served: unknown = JSON.parse(text);
    expect(served).toEqual(JSON.parse(JSON.stringify(fixture.document)));
    expect((await validate(served)).valid).toBe(true);
  });

  test("GET /docs serves the Scalar page with its own CSP", async () => {
    const res = await fetch(`${server.url}/docs`);
    expect(res.status).toBe(200);
    expect(res.headers.get("content-type")).toBe("text/html; charset=utf-8");
    const csp = res.headers.get("content-security-policy") ?? "";
    expect(csp).toContain("script-src https://cdn.jsdelivr.net;");
    expect(csp).toContain("connect-src 'self'");
    const html = await res.text();
    expect(html).toContain("<title>Bendo &lt;fixture&gt; API</title>");
    expect(html).toContain('<script id="api-reference" data-url="/openapi.json"></script>');
    expect(html).toContain(
      '<script src="https://cdn.jsdelivr.net/npm/@scalar/api-reference@1.75.1/dist/browser/standalone.js" integrity="sha384-G+2Q2i9l3PPfmYkk0b4BAIUrs7xb/DNaTL1wCYYab4c9dIKlCyiqzC0Qx3eq9Wf6" crossorigin="anonymous"></script>',
    );
    // No inline script, so the policy needs no hash or nonce.
    expect(html.match(/<script[^>]*>[^<]+<\/script>/g)).toBeNull();
    const head = await fetch(`${server.url}/docs`, { method: "HEAD" });
    expect(head.status).toBe(200);
    expect(head.headers.get("content-security-policy")).toBe(csp);
  });

  test("the self-hosted and no-CSP variants", async () => {
    const offline = await fetch(`${server.url}/docs/offline`);
    expect(offline.headers.get("content-security-policy")).toStartWith(
      "default-src 'none'; script-src 'self';",
    );
    const html = await offline.text();
    expect(html).toContain('<script src="/scalar/standalone.js"></script>');
    expect(html).toContain('data-configuration="{&quot;withDefaultFonts&quot;:false}"');
    expect(html).not.toContain("jsdelivr");
    const bare = await fetch(`${server.url}/docs/bare`);
    expect(bare.status).toBe(200);
    expect(bare.headers.get("content-security-policy")).toBeNull();
  });

  test("the other routes still answer", async () => {
    for (const path of [
      "/todos",
      "/v1/2/linux",
      "/files/a/b",
      "/assets-v2",
      "/x/y/contents/1",
      "/anything",
    ]) {
      const res = await fetch(`${server.url}${path}`);
      expect([path, res.status, await res.text()]).toEqual([path, 200, "ok"]);
    }
  });
});
