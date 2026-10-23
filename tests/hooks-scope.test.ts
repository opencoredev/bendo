import { afterAll, beforeAll, expect, test } from "bun:test";
import { build, start, type RunningServer } from "./harness.ts";

const binary = build("tests/servers/hooks-scope.bend");
let server: RunningServer;
beforeAll(async () => {
  server = await start(binary);
});
afterAll(async () => {
  await server?.[Symbol.asyncDispose]();
});

async function body(path: string, method = "GET"): Promise<string> {
  const response = await fetch(server.url + path, {
    method,
    signal: AbortSignal.timeout(5000),
  });
  expect(response.status).toBe(200);
  return response.text();
}

test.each(["/g/a", "/g/b"])("group hooks apply to %s", async (path) => {
  expect(await body(path)).toBe("group-request,global1,global2,group,handler,group-after");
});
test.each(["/outside", "/g-prefix", "/duplicate"])(
  "group and guard hooks do not escape to %s",
  async (path) => {
    expect(await body(path)).toBe("global1,global2,handler");
  },
);
test.each(["/members/42", "/other"])("guard hooks apply to every member %s", async (path) => {
  expect(await body(path)).toBe("global1,global2,root-guard,handler");
});
test("guard membership uses the selected registration, including the method", async () => {
  expect(await body("/members/42", "POST")).toBe("global1,global2,handler");
  expect(await body("/g/guard-a", "POST")).toBe(
    "group-request,global1,global2,group,handler,group-after",
  );
});
test("group, guard and exact-route inheritance preserves order and duplicates", async () => {
  expect(await body("/g/guard-a")).toBe(
    "group-request,global1,global2,group,guard,handler,group-after",
  );
  expect(await body("/g/guard-b")).toBe(
    "group-request,global1,global2,group,guard,local,local,handler,group-after",
  );
});
test("nested groups compose prefixes and hooks", async () => {
  expect(await body("/nested/inner/item")).toBe("global1,global2,outer,inner,handler");
  expect(await body("/declared/item")).toBe("global1,global2,declared,handler");
});
test("request rewrites reselect pre and response scopes", async () => {
  expect(await body("/rewrite-in")).toBe("global1,global2,group,handler,group-after");
  expect(await body("/g/rewrite-out")).toBe("group-request,global1,global2,handler");
});
test("a pre-stage rewrite cannot switch the selected route's response hooks", async () => {
  expect(await body("/g/late")).toBe(
    "group-request,global1,global2,group,guard,handler,group-after",
  );
});
test("scoped response hooks still run after a scoped early return", async () => {
  expect(await body("/g/stop")).toBe(
    "group-request,global1,global2,group,guard,stopped,group-after",
  );
});
test("HEAD fallback selects the GET route's scope and keeps the wire body empty", async () => {
  const response = await fetch(server.url + "/g/guard-b", { method: "HEAD" });
  expect(response.status).toBe(200);
  expect(response.headers.get("content-length")).toBe(
    String("group-request,global1,global2,group,guard,local,local,handler,group-after".length),
  );
  expect(await response.text()).toBe("");
});
test("misses and method failures cannot inherit a nearby scope", async () => {
  for (const [path, method, status] of [
    ["/g/missing", "GET", 404],
    ["/g/a", "DELETE", 405],
  ] satisfies [string, string, number][]) {
    const response = await fetch(server.url + path, { method });
    expect(response.status).toBe(status);
    expect(await response.text()).not.toContain("group-after");
  }
});

test("every lifecycle stage, error hook and deferred observer respects guard membership", async () => {
  expect(await body("/outside")).toBe("global1,global2,handler");
  expect(await body("/stages")).toBe(
    "request,parse,transform,global1,global2,before,handler,after,map",
  );
  expect(await body("/events")).toBe("/stages");
  const failure = await fetch(server.url + "/stages-error", {
    signal: AbortSignal.timeout(5000),
  });
  expect(failure.status).toBe(403);
  expect(await failure.text()).toBe(
    "request,parse,transform,global1,global2,before,handler,after,map,error",
  );
  expect(await body("/events")).toBe("/stages-error");
});

test("a scoped request short circuit keeps its provisional scope for response hooks", async () => {
  expect(await body("/g/request-stop")).toBe("group-request,stopped,group-after");
});
