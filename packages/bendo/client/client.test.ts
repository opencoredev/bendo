import { afterAll, beforeAll, expect, test } from "bun:test";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { build, start, type RunningServer } from "../../../tests/harness.ts";
import { fetchManifest } from "../src/manifest.ts";
import { writeRouteTypes } from "../src/route-types.ts";
import { createClient, type Fetch } from "./index.ts";
import type { Routes } from "./fixture/routes.ts";
import { schemas } from "./fixture/routes.schemas.ts";

// Compile outside the test timeout; the harness gives each compile 180 s.
const binary = build("tests/fixtures/client/app.bend");
// Production sends a response that breaks its schema; development answers 500.
let server: RunningServer;
let development: RunningServer;
beforeAll(async () => {
  server = await start(binary, "127.0.0.1", { BENDO_ENV: "production" });
  development = await start(binary);
});
afterAll(async () => {
  await server[Symbol.asyncDispose]();
  await development[Symbol.asyncDispose]();
});

const client = (options: Parameters<typeof createClient>[1] = { schemas }) =>
  createClient<Routes>(server.url, options);

test("bendo gen output for the compiled fixture matches the committed client fixture", () => {
  const directory = mkdtempSync(join(tmpdir(), "bendo-client-gen-"));
  try {
    writeRouteTypes(fetchManifest(binary), join(directory, "routes.ts"));
    for (const name of ["routes.ts", "routes.schemas.ts"])
      expect(readFileSync(join(directory, name), "utf8")).toBe(
        readFileSync(join(import.meta.dir, "fixture", name), "utf8"),
      );
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

test("a capture call returns the typed, validated todo", async () => {
  const result = await client().todos({ id: 1 }).get();
  if (!result.ok || result.kind !== "data")
    throw new Error(`expected data, got ${JSON.stringify(result)}`);
  const title: string = result.data.title;
  expect(result.status).toBe(200);
  expect(result.data).toEqual({ id: 1, title: "write the client", done: false });
  expect(title).toBe("write the client");
  expect(result.response.headers.get("content-type")).toContain("application/json");
});

test("a JSON body round-trips through POST", async () => {
  const result = await client().todos.post({ body: { title: "ship it" } });
  expect(result).toMatchObject({
    ok: true,
    status: 201,
    data: { id: 2, title: "ship it", done: false },
  });
});

test("a 404 is a typed http result with Bendo's error body", async () => {
  const result = await client().todos({ id: 7 }).get();
  expect(result).toMatchObject({
    ok: false,
    kind: "http",
    status: 404,
    error: { kind: "bendo", error: "Not Found", status: 404, errors: [] },
  });
});

test("a 422 from route validation carries Bendo's error list", async () => {
  const result = await client().todos.post({ body: { title: "" } });
  if (result.ok || result.kind !== "http")
    throw new Error(`expected http, got ${JSON.stringify(result)}`);
  expect(result.status).toBe(422);
  expect(result.error).toEqual({
    kind: "bendo",
    error: "Unprocessable Content",
    status: 422,
    errors: [
      {
        path: ["body", "title"],
        code: "constraint",
        message: "value does not satisfy scalar checks",
      },
    ],
  });
});

test("a body that breaks the response schema is invalid-response, unless validation is off", async () => {
  const result = await client().broken.get();
  if (result.ok || result.kind !== "invalid-response")
    throw new Error(`expected invalid-response, got ${JSON.stringify(result)}`);
  expect(result.status).toBe(200);
  expect(result.issues).toEqual(
    expect.arrayContaining([
      { path: [], message: "must have required property 'title' (required)" },
      { path: ["id"], message: "must be integer (type)" },
    ]),
  );
  const unchecked = await client({ schemas, validate: false }).broken.get();
  expect(unchecked).toMatchObject({ ok: true, data: { id: "one", done: true } });
  expect(await client({}).broken.get()).toMatchObject({ ok: true });
});

test("in development the server's own response check is a 500 http result", async () => {
  const result = await createClient<Routes>(development.url, { schemas }).broken.get();
  if (result.ok || result.kind !== "http")
    throw new Error(`expected http, got ${JSON.stringify(result)}`);
  expect(result.status).toBe(500);
  expect(result.error).toEqual({
    kind: "bendo",
    error: "Internal Server Error",
    status: 500,
    errors: [],
  });
});

test("HEAD on a JSON route succeeds with no data, though Content-Type names JSON", async () => {
  const head = await client().any.head();
  if (!head.ok || head.kind !== "data")
    throw new Error(`expected data, got ${JSON.stringify(head)}`);
  const data: undefined = head.data;
  expect(data).toBeUndefined();
  expect(head.status).toBe(200);
  expect(head.response.headers.get("content-type")).toContain("application/json");
  expect(await client().any.get()).toMatchObject({ ok: true, data: { method: "GET" } });
});

test("captures are percent-encoded; query and headers follow Bendo's text coercion", async () => {
  const seen: string[] = [];
  const recording: Fetch = (input, init) => {
    seen.push(input);
    return fetch(input, init);
  };
  const api = client({
    schemas,
    fetch: recording,
    headers: { "x-extra": "default", "x-token": "old" },
  });
  const result = await api
    .echo({ name: "a b/ç?#%" })({ rest: "x/y z" })
    .get({
      query: { n: 1.5, flag: false, tag: ["p", "q r&"], skipped: undefined },
      headers: { "x-token": "t" },
    });
  if (!result.ok || result.kind !== "data")
    throw new Error(`expected data, got ${JSON.stringify(result)}`);
  const url = "/echo/a%20b%2F%C3%A7%3F%23%25/x%2Fy%20z?n=1.5&flag=false&tag=p&tag=q+r%26";
  expect(seen).toEqual([`${server.url}${url}`]);
  expect(result.data).toEqual({
    url,
    name: "a b/ç?#%",
    rest: "x/y z",
    tags: ["p", "q r&"],
    token: "t",
    extra: "default",
  });
});

test("a closed port is a network result, not an exception", async () => {
  const listener = Bun.serve({ port: 0, hostname: "127.0.0.1", fetch: () => new Response() });
  const port = listener.port;
  await listener.stop(true);
  const result = await createClient<Routes>(`http://127.0.0.1:${port}`).todos({ id: 1 }).get();
  if (result.ok || result.kind !== "network")
    throw new Error(`expected network, got ${JSON.stringify(result)}`);
  expect(result.cause).toBeInstanceOf(Error);
});

test("an aborted signal is a network result; an unsendable capture is a request result", async () => {
  const aborted = await client().todos({ id: 1 }).get({ signal: AbortSignal.abort() });
  expect(aborted).toMatchObject({ ok: false, kind: "network", cause: { name: "AbortError" } });
  let calls = 0;
  const counting: Fetch = (input, init) => {
    calls += 1;
    return fetch(input, init);
  };
  const dot = await client({ fetch: counting })
    .echo({ name: ".." })({ rest: "" })
    .get({ headers: { "x-token": "t" } });
  expect(dot).toMatchObject({ ok: false, kind: "request", cause: { name: "TypeError" } });
  expect(calls).toBe(0);
});

// Compile-time only: each line must be a type error against the generated Routes.
export function rejected(): void {
  const api = client();
  // @ts-expect-error id is number | string
  void api.todos({ id: false }).get();
  // @ts-expect-error x-token is required
  void api.echo({ name: "n" })({ rest: "r" }).get();
  // @ts-expect-error title must be a string
  void api.todos.post({ body: { title: 1 } });
  const echo = api.echo({ name: "n" })({ rest: "r" });
  // @ts-expect-error flag is boolean text
  void echo.get({ query: { flag: "yes" }, headers: { "x-token": "t" } });
}
