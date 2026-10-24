import { afterAll, expect, test } from "bun:test";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { parseManifest } from "../src/manifest.ts";
import { emitResponseSchemas } from "../src/response-schemas.ts";
import { createClient, type ResponseSchemaTable } from "./index.ts";
import { headerEntries, pathOf, shapes, textEntries } from "./path.ts";
import { errorBody, expected, isJson } from "./response.ts";

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

test("header entries take one value per name", () => {
  expect(headerEntries({ "x-a": ["1"], "x-b": 2, "x-c": [] })).toEqual({
    ok: true,
    value: [
      ["x-a", "1"],
      ["x-b", "2"],
    ],
  });
  expect(headerEntries({ "x-a": ["1", "2"] })).toEqual({
    ok: false,
    reason: "headers.x-a has more than one value; fetch would join them into one field",
  });
  expect(headerEntries({ "x-a": "1", "X-A": "2" }).ok).toBe(false);
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

test("schema rows match by method, ALL and optional captures; a row without a schema accepts anything", async () => {
  const table: ResponseSchemaTable = [
    { method: "GET", path: "/v1/:version?", all: false, response: { type: "string" } },
    { method: "ALL", path: "/v1", all: true, response: { type: "number" } },
    { method: "POST", path: "/v1/:other", all: false },
  ];
  const v1 = [{ kind: "static" as const, name: "v1" }];
  expect(await expected(table, "GET", v1)).toEqual({
    kind: "schemas",
    schemas: [{ type: "string" }, { type: "number" }],
  });
  expect(await expected(table, "PUT", v1)).toEqual({
    kind: "schemas",
    schemas: [{ type: "number" }],
  });
  expect(
    await expected(table, "POST", [...v1, { kind: "capture", name: "other", value: 1 }]),
  ).toEqual({ kind: "any" });
  expect(await expected(table, "GET", [{ kind: "static", name: "v2" }])).toEqual({ kind: "any" });
});

const item = (value: unknown) => [
  { kind: "static" as const, name: "items" },
  { kind: "capture" as const, name: "id", value },
];

test("a row whose params schema rejects the captures is not a candidate", async () => {
  const param = (schema: object) => ({
    type: "object",
    properties: { id: schema },
    required: ["id"],
    additionalProperties: false,
  });
  const table: ResponseSchemaTable = [
    // Excluded for "write", so its missing response schema does not switch validation off.
    { method: "GET", path: "/items/:id", all: false, params: param({ const: "read" }) },
    {
      method: "GET",
      path: "/items/:id",
      all: false,
      params: param({ const: "write" }),
      response: { const: "written" },
    },
    // Coercion as the server does it: "7" is the integer 7, "07" stays text.
    {
      method: "PUT",
      path: "/items/:id",
      all: false,
      params: param({ type: "integer", minimum: 5 }),
      response: { const: "int" },
    },
    {
      method: "PUT",
      path: "/items/:id",
      all: false,
      params: param({ type: "string", pattern: "^0" }),
      response: { const: "text" },
    },
    {
      method: "DELETE",
      path: "/items/:id",
      all: false,
      params: param({ anyOf: [{ type: "null" }, { type: "boolean" }] }),
      response: { const: "flag" },
    },
  ];
  expect(await expected(table, "GET", item("read"))).toEqual({ kind: "any" });
  expect(await expected(table, "GET", item("write"))).toEqual({
    kind: "schemas",
    schemas: [{ const: "written" }],
  });
  expect(await expected(table, "PUT", item(7))).toEqual({
    kind: "schemas",
    schemas: [{ const: "int" }],
  });
  expect(await expected(table, "PUT", item("07"))).toEqual({
    kind: "schemas",
    schemas: [{ const: "text" }],
  });
  expect(await expected(table, "DELETE", item(false))).toEqual({
    kind: "schemas",
    schemas: [{ const: "flag" }],
  });
  expect(await expected(table, "PUT", item(3))).toMatchObject({ kind: "unreachable" });
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

type Endpoint<P extends string, Params, Response> = {
  method: "GET";
  path: P;
  all: false;
  captures: P extends `/${string}/:${string}` ? ["id"] : [];
  input: { params: Params; query: unknown; headers: unknown; body: unknown; response: Response };
  output: { params: Params; query: unknown; headers: unknown; body: unknown; response: Response };
};

type Routes =
  | Endpoint<"/docs/:id", { id: "read" }, { title: string }>
  | Endpoint<"/docs/:id", { id: "write" }, { count: number }>
  | Endpoint<"/empty", unknown, { n: number }>
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
const docParams = (id: string) => ({
  type: "object",
  properties: { id: { const: id } },
  required: ["id"],
  additionalProperties: false,
});
const table: ResponseSchemaTable = [
  {
    method: "GET",
    path: "/docs/:id",
    all: false,
    params: docParams("read"),
    response: { type: "object", properties: { title: { type: "string" } }, required: ["title"] },
  },
  {
    method: "GET",
    path: "/docs/:id",
    all: false,
    params: docParams("write"),
    response: { type: "object", properties: { count: { type: "number" } }, required: ["count"] },
  },
  {
    method: "GET",
    path: "/empty",
    all: false,
    response: { type: "object", properties: { n: { type: "number" } }, required: ["n"] },
  },
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
  // The read handler answers with the write route's shape.
  ["/docs/read", () => Response.json({ count: 1 })],
  ["/docs/write", () => Response.json({ count: 1 })],
  [
    "/empty?mode=json",
    () => new Response(null, { status: 204, headers: { "content-type": "application/json" } }),
  ],
  ["/empty?mode=bare", () => new Response(null, { status: 204 })],
  ["/empty?mode=not-modified", () => new Response(null, { status: 304 })],
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

test("a narrowed route that returns its sibling's response shape is invalid-response", async () => {
  const read = await api.docs({ id: "read" }).get();
  expect(read).toMatchObject({
    ok: false,
    kind: "invalid-response",
    status: 200,
    issues: [{ path: [], message: "must have required property 'title' (required)" }],
  });
  expect(await api.docs({ id: "write" }).get()).toMatchObject({
    ok: true,
    kind: "data",
    data: { count: 1 },
  });
});

test("a 204 is no-content with or without a JSON content type; a 304 is http", async () => {
  for (const mode of ["json", "bare"]) {
    const result = await api.empty.get({ query: { mode } });
    expect(result).toMatchObject({ ok: true, kind: "no-content", status: 204 });
    if (result.ok) expect(result.data).toBeUndefined();
  }
  expect(await api.empty.get({ query: { mode: "not-modified" } })).toMatchObject({
    ok: false,
    kind: "http",
    status: 304,
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

test("awaiting a node does not send a request, and a malformed call is a request result", async () => {
  const node: unknown = await api.thing;
  expect(typeof node).toBe("function");
  const call: unknown = Reflect.apply(api.thing.get, undefined, ["not an object"]);
  expect(await call).toMatchObject({ ok: false, kind: "request", cause: { name: "TypeError" } });
});

test("requests that cannot be built are request results and never reach fetch", async () => {
  let calls = 0;
  const counting = createClient<Routes>(`http://127.0.0.1:${server.port}/`, {
    fetch: (input, init) => {
      calls += 1;
      return fetch(input, init);
    },
  });
  // The types already reject two items; Reflect.apply sends them anyway.
  const joined: unknown = Reflect.apply(counting.thing.get, undefined, [
    { headers: { "x-a": ["1", "2"] } },
  ]);
  const failures = [
    await joined,
    await counting.thing.get({ headers: { "bad name": "1" } }),
    await counting.thing.get({ headers: { "x-a": "line\nbreak" } }),
  ];
  for (const failure of failures)
    expect(failure).toMatchObject({ ok: false, kind: "request", cause: { name: "TypeError" } });
  expect(calls).toBe(0);
});
