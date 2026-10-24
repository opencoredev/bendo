import { afterAll, expect, test } from "bun:test";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { parseManifest } from "../src/manifest.ts";
import { emitResponseSchemas } from "../src/response-schemas.ts";
import { createClient, type ResponseSchemaTable } from "./index.ts";
import { pathOf, shapes, textEntries } from "./path.ts";
import { errorBody, isJson, responseSchemas } from "./response.ts";

test("route patterns become the step shapes the client tree uses", () => {
  expect(shapes("/")).toEqual([[]]);
  expect(shapes("/todos/:id{int}")).toEqual([["todos", ":id"]]);
  expect(shapes("/v1/:version?/:platform{[a-z?]+}?")).toEqual([
    ["v1"],
    ["v1", ":version"],
    ["v1", ":version", ":platform"],
  ]);
  expect(shapes("/files/*path")).toEqual([["files", ":path"]]);
  expect(shapes("/files/*")).toEqual([["files", ":*"]]);
  expect(shapes("*")).toEqual([[":*"]]);
  expect(shapes("/a/*/b")).toEqual([["a", "b"]]);
  expect(shapes("/assets*")).toEqual([["assets"]]);
  expect(shapes("/:prefix{.+}/contents")).toEqual([[":prefix", "contents"]]);
  expect(shapes("/a/")).toEqual([["a", ""]]);
});

test("paths encode captures and refuse dot segments", () => {
  expect(pathOf([])).toEqual({ ok: true, value: "/" });
  expect(
    pathOf([
      { kind: "static", name: "a" },
      { kind: "capture", name: "x", value: "é/ ?" },
      { kind: "capture", name: "n", value: -1 },
      { kind: "capture", name: "b", value: true },
    ]),
  ).toEqual({ ok: true, value: "/a/%C3%A9%2F%20%3F/-1/true" });
  expect(pathOf([{ kind: "capture", name: "x", value: "." }]).ok).toBe(false);
  expect(pathOf([{ kind: "capture", name: "x", value: {} }]).ok).toBe(false);
});

test("text entries repeat array keys and print numbers and booleans", () => {
  expect(textEntries({ a: [1, "2", true], b: 10n, c: undefined, d: [] }, "query")).toEqual({
    ok: true,
    value: [
      ["a", "1"],
      ["a", "2"],
      ["a", "true"],
      ["b", "10"],
    ],
  });
  expect(textEntries({ a: null }, "query").ok).toBe(false);
  expect(textEntries({ a: [{}] }, "query").ok).toBe(false);
  expect(textEntries("x=1", "query").ok).toBe(false);
});

test("error bodies parse only Bendo's whole shape", () => {
  expect(errorBody('{"error":"Tea only","status":418}')).toEqual({
    kind: "bendo",
    error: "Tea only",
    status: 418,
    errors: [],
  });
  expect(errorBody("Not Found")).toEqual({ kind: "text", text: "Not Found" });
  expect(errorBody('{"error":1,"status":418}')).toEqual({
    kind: "text",
    text: '{"error":1,"status":418}',
  });
  const badList = '{"error":"x","status":422,"errors":[{"path":[{}],"code":"c","message":"m"}]}';
  expect(errorBody(badList)).toEqual({ kind: "text", text: badList });
});

test("JSON media types", () => {
  expect(isJson("application/json; charset=utf-8")).toBe(true);
  expect(isJson("Application/Problem+JSON")).toBe(true);
  expect(isJson("text/plain")).toBe(false);
  expect(isJson(null)).toBe(false);
});

test("schema rows match by method, ALL and optional captures; a row without a schema accepts anything", () => {
  const table: ResponseSchemaTable = [
    { method: "GET", path: "/v1/:version?", all: false, response: { type: "string" } },
    { method: "ALL", path: "/v1", all: true, response: { type: "number" } },
    { method: "POST", path: "/v1/:other", all: false },
  ];
  const v1 = [{ kind: "static" as const, name: "v1" }];
  expect(responseSchemas(table, "GET", v1)).toEqual([{ type: "string" }, { type: "number" }]);
  expect(responseSchemas(table, "PUT", v1)).toEqual([{ type: "number" }]);
  expect(
    responseSchemas(table, "POST", [...v1, { kind: "capture", name: "other", value: 1 }]),
  ).toBe(undefined);
  expect(responseSchemas(table, "GET", [{ kind: "static", name: "v2" }])).toBe(undefined);
});

test("the emitted schema table keeps __proto__ as an own key and survives overflowing numbers", async () => {
  const manifest = parseManifest(
    JSON.stringify({ bendo: 1, routes: [{ method: "GET", path: "/" }] }).replace(
      '"path":"/"}',
      '"path":"/","schemas":{"response":{"type":"object","properties":{"__proto__":{"type":"number","maximum":1e400}},"required":["__proto__"]}}}',
    ),
  );
  const directory = mkdtempSync(join(tmpdir(), "bendo-schemas-"));
  try {
    const file = join(directory, "routes.schemas.ts");
    writeFileSync(file, emitResponseSchemas(manifest));
    const module: unknown = await import(file);
    // JSON.stringify prints own keys only, so this fails if __proto__ set the prototype.
    expect(JSON.stringify(module)).toContain(
      '"properties":{"__proto__":{"type":"number","maximum":null}}',
    );
    expect(module).toEqual({
      schemas: [
        {
          method: "GET",
          path: "/",
          all: false,
          response: JSON.parse(
            '{"type":"object","properties":{"__proto__":{"type":"number","maximum":1e400}},"required":["__proto__"]}',
          ),
        },
      ],
    });
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
  expect(emitResponseSchemas(parseManifest('{"bendo":1,"routes":[]}'))).toContain("> = [];");
});

type Routes =
  | {
      method: "GET";
      path: "/thing";
      all: false;
      captures: [];
      input: {
        params: unknown;
        query: unknown;
        headers: unknown;
        body: unknown;
        response: { n: number };
      };
      output: {
        params: unknown;
        query: unknown;
        headers: unknown;
        body: unknown;
        response: { n: number };
      };
    }
  | {
      method: "GET";
      path: "/";
      all: false;
      captures: [];
      input: {
        params: unknown;
        query: unknown;
        headers: unknown;
        body: unknown;
        response: unknown;
      };
      output: {
        params: unknown;
        query: unknown;
        headers: unknown;
        body: unknown;
        response: unknown;
      };
    };
const table: ResponseSchemaTable = [
  {
    method: "GET",
    path: "/thing",
    all: false,
    response: { type: "object", properties: { n: { type: "number" } }, required: ["n"] },
  },
  { method: "GET", path: "/", all: false },
];

// A real HTTP server for bodies the Bend fixture cannot produce.
const replies = new Map<string, () => Response>([
  ["/thing?mode=text", () => new Response("plain", { headers: { "content-type": "text/plain" } })],
  [
    "/thing?mode=bad-json",
    () => new Response("{", { headers: { "content-type": "application/json" } }),
  ],
  ["/thing?mode=text-error", () => new Response("teapot", { status: 418 })],
  ["/thing?mode=ok", () => Response.json({ n: 1 })],
  ["/?mode=text", () => new Response("hello")],
]);
const server = Bun.serve({
  port: 0,
  hostname: "127.0.0.1",
  fetch(request) {
    const url = new URL(request.url);
    const reply = replies.get(`${url.pathname}${url.search}`);
    return reply === undefined ? new Response("missing", { status: 500 }) : reply();
  },
});
afterAll(() => server.stop(true));
const api = createClient<Routes>(`http://127.0.0.1:${server.port}/`, { schemas: table });

test("non-JSON and malformed 2xx bodies are invalid-response when a schema applies", async () => {
  expect(await api.thing.get({ query: { mode: "text" } })).toMatchObject({
    ok: false,
    kind: "invalid-response",
    issues: [{ path: [], message: "expected a JSON response, got content-type text/plain" }],
  });
  const bad = await api.thing.get({ query: { mode: "bad-json" } });
  expect(bad).toMatchObject({ ok: false, kind: "invalid-response", status: 200 });
  expect(await api.thing.get({ query: { mode: "ok" } })).toMatchObject({
    ok: true,
    data: { n: 1 },
  });
});

test("a text error stays text and an unschematized text body is the data", async () => {
  expect(await api.thing.get({ query: { mode: "text-error" } })).toMatchObject({
    ok: false,
    kind: "http",
    status: 418,
    error: { kind: "text", text: "teapot" },
  });
  expect(await api.get({ query: { mode: "text" } })).toMatchObject({ ok: true, data: "hello" });
});

test("awaiting a node does not send a request, and a malformed call is a network result", async () => {
  const node: unknown = await api.thing;
  expect(typeof node).toBe("function");
  const call: unknown = Reflect.apply(api.thing.get, undefined, ["not an object"]);
  expect(await call).toMatchObject({ ok: false, kind: "network", cause: { name: "TypeError" } });
});
