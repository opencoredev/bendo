// BND-63: the fullstack todo example. The compiled API serves CRUD from one
// B.Store, rejects bad input with route validation and the shared blank rule,
// answers CORS for the dev server's origin, and exports every route's full
// schemas. The browser's copy of shared/todo.bend must agree with the server
// on what it accepts, and the React app must build and typecheck.
import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { createClient } from "../packages/bendo/client/index.ts";
import { fetchManifest, type Route } from "../packages/bendo/src/manifest.ts";
import { emitResponseSchemas } from "../packages/bendo/src/response-schemas.ts";
import { emitRouteTypes } from "../packages/bendo/src/route-types.ts";
import { buildShared } from "../packages/bendo/src/shared.ts";
import type { Routes } from "../examples/todo/.bendo/routes.ts";
import { schemas } from "../examples/todo/.bendo/routes.schemas.ts";
import { build, start, type RunningServer } from "./harness.ts";

const APP = join(import.meta.dir, "../examples/todo");
const ORIGIN = "http://127.0.0.1:5173";

// Compile outside any test's timeout, through the shared fixture cache.
const binary = build("examples/todo/main.bend");
const out = mkdtempSync(join(tmpdir(), "bendo-todo-shared-"));
const [shared] = await buildShared(join(APP, "shared"), out);
if (shared === undefined) throw new Error("no shared module");
const sharedModule: unknown = await import(pathToFileURL(shared.module).href);

/** The verdict tag of a shared check: "Accepted" or "Rejected". */
function browserVerdict(name: "check_create" | "check_update", body: string): string {
  if (typeof sharedModule !== "object" || sharedModule === null) throw new Error("no module");
  const fn: unknown = Reflect.get(sharedModule, name);
  if (typeof fn !== "function") throw new Error(`missing export ${name}`);
  const checked: unknown = fn(body);
  if (typeof checked !== "object" || checked === null) throw new Error("bad verdict");
  const tag: unknown = Reflect.get(checked, "$");
  if (typeof tag !== "string") throw new Error("bad verdict");
  return tag;
}

let server: RunningServer;
beforeAll(async () => {
  server = await start(binary);
});
afterAll(async () => {
  await server[Symbol.asyncDispose]();
  rmSync(out, { recursive: true, force: true });
});

function client() {
  return createClient<Routes>(server.url, { schemas });
}

function send(method: string, path: string, body?: string, headers: Record<string, string> = {}) {
  return fetch(`${server.url}${path}`, {
    method,
    headers: {
      accept: "application/json",
      ...(body === undefined ? {} : { "content-type": "application/json" }),
      ...headers,
    },
    ...(body === undefined ? {} : { body }),
  });
}

describe("manifest", () => {
  const manifest = fetchManifest(binary);
  const slots = (route: Route) => Object.keys(route.schemas).sort();

  test("every route carries the schema of every slot it reads, and a response schema", () => {
    expect(manifest.routes.map((r) => [r.method, r.path, slots(r)])).toEqual([
      ["GET", "/api/todos", ["query", "response"]],
      ["POST", "/api/todos", ["body", "response"]],
      ["GET", "/api/todos/:id{int}", ["params", "response"]],
      ["PATCH", "/api/todos/:id{int}", ["body", "params", "response"]],
      ["DELETE", "/api/todos/:id{int}", ["params", "response"]],
    ]);
    for (const route of manifest.routes) {
      for (const [slot, schema] of Object.entries(route.schemas)) {
        expect(typeof schema === "object" && schema !== null, `${route.path} ${slot}`).toBe(true);
        expect(Reflect.get(Object(schema), "type"), `${route.path} ${slot}`).toBe("object");
      }
    }
  });

  test("the committed .bendo files match bendo gen's output", () => {
    expect(readFileSync(join(APP, ".bendo/routes.ts"), "utf8")).toBe(emitRouteTypes(manifest));
    expect(readFileSync(join(APP, ".bendo/routes.schemas.ts"), "utf8")).toBe(
      emitResponseSchemas(manifest),
    );
  });
});

describe("CRUD", () => {
  test("creates, reads, edits, completes and deletes a todo with the typed client", async () => {
    const api = client();
    const created = await api.api.todos.post({ body: { title: "Write the example" } });
    if (created.kind !== "data") throw new Error(`create failed: ${created.kind}`);
    expect(created.status).toBe(201);
    expect(created.data).toMatchObject({ title: "Write the example", done: false });
    const id = created.data.id;

    const read = await api.api.todos({ id }).get();
    expect(read.kind === "data" && read.data).toEqual(created.data);

    const renamed = await api.api.todos({ id }).patch({ body: { title: "Ship the example" } });
    expect(renamed.kind === "data" && renamed.data).toEqual({
      id,
      title: "Ship the example",
      done: false,
    });

    const completed = await api.api.todos({ id }).patch({ body: { done: true } });
    expect(completed.kind === "data" && completed.data).toEqual({
      id,
      title: "Ship the example",
      done: true,
    });

    const done = await api.api.todos.get({ query: { show: "done" } });
    if (done.kind !== "data") throw new Error(`list failed: ${done.kind}`);
    expect(done.data.todos.some((t) => t.id === id)).toBe(true);
    expect(done.data.todos.every((t) => t.done)).toBe(true);
    const active = await api.api.todos.get({ query: { show: "active" } });
    if (active.kind !== "data") throw new Error(`list failed: ${active.kind}`);
    expect(active.data.todos.some((t) => t.id === id)).toBe(false);
    expect(active.data.counts.all).toBe(active.data.counts.active + active.data.counts.done);

    const removed = await api.api.todos({ id }).delete();
    expect(removed.kind === "data" && removed.data).toEqual({
      id,
      title: "Ship the example",
      done: true,
    });
    const gone = await api.api.todos({ id }).get();
    expect(gone.kind === "http" && gone.status).toBe(404);
  });

  test("new todos come first and get increasing IDs", async () => {
    const api = client();
    const a = await api.api.todos.post({ body: { title: "first" } });
    const b = await api.api.todos.post({ body: { title: "second", done: true } });
    if (a.kind !== "data" || b.kind !== "data") throw new Error("create failed");
    expect(b.data.id).toBeGreaterThan(a.data.id);
    expect(b.data.done).toBe(true);
    const list = await api.api.todos.get();
    if (list.kind !== "data") throw new Error("list failed");
    expect(list.data.todos.slice(0, 2).map((t) => t.id)).toEqual([b.data.id, a.data.id]);
  });

  test("a missing todo is 404 for every single-todo method", async () => {
    for (const method of ["GET", "PATCH", "DELETE"]) {
      const response = await send(
        method,
        "/api/todos/999999",
        method === "PATCH" ? "{}" : undefined,
      );
      expect(response.status, method).toBe(404);
      expect(await response.json()).toEqual({ error: "Not Found", status: 404 });
    }
  });
});

describe("validation", () => {
  const long = "x".repeat(121);
  const rejected: {
    name: string;
    method: string;
    check: "check_create" | "check_update";
    body: string;
  }[] = [
    { name: "an empty title", method: "POST", check: "check_create", body: '{"title":""}' },
    { name: "a title of spaces", method: "POST", check: "check_create", body: '{"title":"   "}' },
    {
      name: "a 121-character title",
      method: "POST",
      check: "check_create",
      body: JSON.stringify({ title: long }),
    },
    { name: "no title", method: "POST", check: "check_create", body: "{}" },
    { name: "a number title", method: "POST", check: "check_create", body: '{"title":7}' },
    {
      name: "an undeclared key",
      method: "POST",
      check: "check_create",
      body: '{"title":"a","owner":"me"}',
    },
    { name: "a text done", method: "PATCH", check: "check_update", body: '{"done":"yes"}' },
    { name: "a blank rename", method: "PATCH", check: "check_update", body: '{"title":"\\t "}' },
  ];

  for (const c of rejected) {
    test(`${c.name} is rejected by the shared module and by the server`, async () => {
      expect(browserVerdict(c.check, c.body)).toBe("Rejected");
      const response = await send(
        c.method,
        c.method === "POST" ? "/api/todos" : "/api/todos/1",
        c.body,
      );
      expect(response.status).toBe(422);
      const body: unknown = await response.json();
      expect(body).toMatchObject({ error: "Unprocessable Content", status: 422 });
      expect(Reflect.get(Object(body), "errors")).toBeArray();
    });
  }

  test("the blank rule answers in route validation's shape", async () => {
    const response = await send("POST", "/api/todos", '{"title":"   "}');
    expect(await response.json()).toEqual({
      error: "Unprocessable Content",
      status: 422,
      errors: [{ path: ["body", "title"], code: "constraint", message: "title is blank" }],
    });
  });

  test("bodies the shared module accepts, the server accepts", async () => {
    const accepted: { method: string; check: "check_create" | "check_update"; body: string }[] = [
      { method: "POST", check: "check_create", body: JSON.stringify({ title: "x".repeat(120) }) },
      { method: "POST", check: "check_create", body: '{"title":"Café ☕ ünïcödé","done":true}' },
      { method: "PATCH", check: "check_update", body: "{}" },
      { method: "PATCH", check: "check_update", body: '{"title":" padded "}' },
    ];
    for (const c of accepted) {
      expect(browserVerdict(c.check, c.body), c.body).toBe("Accepted");
      const response = await send(
        c.method,
        c.method === "POST" ? "/api/todos" : "/api/todos/1",
        c.body,
      );
      expect(response.status, c.body).toBe(c.method === "POST" ? 201 : 200);
    }
  });

  test("bad captures and queries are 400, a non-JSON body is 415", async () => {
    expect((await send("GET", "/api/todos/0")).status).toBe(400);
    expect((await send("GET", "/api/todos/1000000000")).status).toBe(400);
    expect((await send("GET", "/api/todos/abc")).status).toBe(404);
    expect((await send("GET", "/api/todos?show=later")).status).toBe(400);
    const text = await fetch(`${server.url}/api/todos`, {
      method: "POST",
      headers: { "content-type": "text/plain" },
      body: "milk",
    });
    expect(text.status).toBe(415);
  });

  test("no rejected write changes the list", async () => {
    const api = client();
    const before = await api.api.todos.get();
    for (const c of rejected)
      await send(c.method, c.method === "POST" ? "/api/todos" : "/api/todos/1", c.body);
    const after = await api.api.todos.get();
    expect(after.kind === "data" && after.data).toEqual(before.kind === "data" && before.data);
  });
});

describe("CORS", () => {
  test("the dev server's origin gets a preflight grant for PATCH with a JSON body", async () => {
    const response = await fetch(`${server.url}/api/todos/1`, {
      method: "OPTIONS",
      headers: {
        origin: ORIGIN,
        "access-control-request-method": "PATCH",
        "access-control-request-headers": "content-type",
      },
    });
    expect(response.status).toBe(204);
    expect(response.headers.get("access-control-allow-origin")).toBe(ORIGIN);
    expect(response.headers.get("access-control-allow-methods")).toContain("PATCH");
    expect(response.headers.get("access-control-allow-headers")).toBe("content-type");
  });

  test("responses carry the grant, rejections included, and other origins get none", async () => {
    const ok = await send("GET", "/api/todos", undefined, { origin: ORIGIN });
    expect(ok.headers.get("access-control-allow-origin")).toBe(ORIGIN);
    const bad = await send("POST", "/api/todos", '{"title":""}', { origin: ORIGIN });
    expect(bad.status).toBe(422);
    expect(bad.headers.get("access-control-allow-origin")).toBe(ORIGIN);
    const other = await send("GET", "/api/todos", undefined, { origin: "https://evil.example" });
    expect(other.headers.get("access-control-allow-origin")).toBeNull();
  });
});

describe("web app", () => {
  test("builds with Vite and typechecks", () => {
    const dist = mkdtempSync(join(tmpdir(), "bendo-todo-web-"));
    try {
      const vite = Bun.spawnSync(
        [
          process.execPath,
          "x",
          "vite",
          "build",
          "--outDir",
          dist,
          "--emptyOutDir",
          "--logLevel",
          "warn",
        ],
        { cwd: APP, stdout: "pipe", stderr: "pipe", timeout: 60_000 },
      );
      expect(vite.exitCode, vite.stderr.toString()).toBe(0);
      expect(readFileSync(join(dist, "index.html"), "utf8")).toContain('<div id="root">');
      // Vite wrote shared/todo.d.bend.ts, which the app's types import.
      const tsc = Bun.spawnSync([process.execPath, "x", "tsc", "-p", "tsconfig.json"], {
        cwd: APP,
        stdout: "pipe",
        stderr: "pipe",
        timeout: 60_000,
      });
      expect(tsc.exitCode, tsc.stdout.toString()).toBe(0);
    } finally {
      rmSync(dist, { recursive: true, force: true });
    }
  }, 120_000);
});
