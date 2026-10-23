import { afterAll, beforeAll, expect, test } from "bun:test";
import { build, start, type RunningServer } from "./harness.ts";

const binary = build("tests/servers/plugins.bend");
const guideBinary = build("tests/servers/plugins-guide.bend");
let server: RunningServer;
beforeAll(async () => {
  server = await start(binary);
});
afterAll(async () => {
  await server?.[Symbol.asyncDispose]();
});

async function get(path: string): Promise<Response> {
  return fetch(server.url + path, { signal: AbortSignal.timeout(5000) });
}

async function body(path: string): Promise<string> {
  const response = await get(path);
  expect(response.status, path).toBe(200);
  return response.text();
}

// Global layers every route sees: A's middleware, B's hook once, the anonymous
// plugin's hook twice, then the route's scoped hooks, the handler and A's
// after-handle hook.
const pre = "a-mw,b,anon,anon,";
const post = ",a-after";

test("the manifest registers each named plugin once and each anonymous use every time", () => {
  const run = Bun.spawnSync([binary, "--bendo-routes"], {
    stdout: "pipe",
    stderr: "pipe",
    timeout: 5000,
  });
  expect(run.exitCode).toBe(0);
  expect(run.stderr.toString()).toBe("");
  const manifest: unknown = JSON.parse(run.stdout.toString());
  const paths = [
    "/root",
    "/b",
    "/a",
    "/anon",
    "/anon",
    "/self",
    "/config",
    "/seeded/one",
    "/seeded/two",
    "/a/other",
    "/a/thing",
    "/b/sibling",
    "/m/x",
    "/guarded",
  ];
  expect(manifest).toEqual({
    bendo: 1,
    routes: paths.map((path) => ({ method: "GET", path, params: [] })),
  });
});

test("A uses B, then the app uses B: B's routes and hook apply once, in A's position", async () => {
  expect(await body("/root")).toBe(`${pre}handler${post}`);
  expect(await body("/a")).toBe(`${pre}handler${post}`);
  expect(await body("/b")).toBe(`${pre}handler${post}`);
});

test("a plugin that uses itself inside its own body skips the inner use", async () => {
  expect(await body("/self")).toBe(`${pre}outer${post}`);
});

test("name-only identity keeps the first configuration; seeds make separate identities", async () => {
  expect(await body("/config")).toBe(`${pre}first${post}`);
  expect(await body("/seeded/one")).toBe(`${pre}one${post}`);
  expect(await body("/seeded/two")).toBe(`${pre}two${post}`);
});

test("a named plugin used under /a and then /b keeps only its /a contribution and scope", async () => {
  expect(await body("/a/thing")).toBe(`${pre}scoped-hook,scoped${post}`);
  expect(await body("/a/other")).toBe(`${pre}scoped-hook,handler${post}`);
  expect((await get("/b/thing")).status).toBe(404);
  expect(await body("/b/sibling")).toBe(`${pre}handler${post}`);
  expect(await body("/root")).not.toContain("scoped-hook");
});

test("a mounted plugin's middleware applies under its prefix only", async () => {
  expect(await body("/m/x")).toBe(`a-mw,mount-mw,b,anon,anon,handler${post}`);
  expect(await body("/guarded")).toBe(`${pre}guard,handler${post}`);
  expect(await body("/anon")).not.toContain("mount-mw");
  expect(await body("/anon")).not.toContain("guard");
});

test("the guide's program applies greeting and health once and keeps the first configuration", async () => {
  const run = Bun.spawnSync([guideBinary, "--bendo-routes"], {
    stdout: "pipe",
    stderr: "pipe",
    timeout: 5000,
  });
  expect(run.exitCode).toBe(0);
  const manifest: unknown = JSON.parse(run.stdout.toString());
  expect(manifest).toEqual({
    bendo: 1,
    routes: ["/", "/hello", "/health"].map((path) => ({ method: "GET", path, params: [] })),
  });
  await using guide = await start(guideBinary);
  const hello = await fetch(guide.url + "/hello", { signal: AbortSignal.timeout(5000) });
  expect(await hello.text()).toBe("hi");
  expect(hello.headers.get("x-greeting")).toBe("yes");
  expect(hello.headers.get("x-health")).toBe("yes");
  const home = await fetch(guide.url + "/", { signal: AbortSignal.timeout(5000) });
  expect(await home.text()).toBe("home");
  expect(home.headers.get("x-greeting")).toBe("yes");
  const health = await fetch(guide.url + "/health", { signal: AbortSignal.timeout(5000) });
  expect(await health.text()).toBe("ok");
});
