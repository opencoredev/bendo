import { afterAll, beforeAll, expect, test } from "bun:test";
import { build, COMPILE_TEST_TIMEOUT_MS, start, type RunningServer } from "./harness.ts";

let server: RunningServer;
let binary: string;
beforeAll(async () => {
  binary = build("tests/servers/middleware.bend");
  server = await start(binary);
}, COMPILE_TEST_TIMEOUT_MS);
afterAll(async () => {
  await server?.[Symbol.asyncDispose]();
});

test("three middleware nest in registration order, including entries after a route", async () => {
  const res = await fetch(server.url + "/order");
  expect(res.status).toBe(200);
  expect(await res.text()).toBe("a-before,b-before,c-before,handler,c-after,b-after,a-after");
  expect(res.headers.get("x-order")).toBe(
    "a-before,b-before,c-before,handler,c-after,b-after,a-after",
  );
  expect(res.headers.get("x-handler")).toBe("ran");
});

test("short circuit skips the handler and downstream typed-variable middleware", async () => {
  const denied = await fetch(server.url + "/private/hello");
  expect(denied.status).toBe(401);
  expect(denied.headers.get("x-handler")).toBeNull();
  expect(await denied.text()).toBe("denied");
  const allowed = await fetch(server.url + "/private/hello", { headers: { "x-auth": "yes" } });
  expect(allowed.status).toBe(200);
  expect(allowed.headers.get("x-handler")).toBe("ran");
  expect(await allowed.text()).toBe("handler:Ada");
});

test("post-next middleware transforms status, headers and body before HEAD normalization", async () => {
  const res = await fetch(server.url + "/transform");
  expect(res.status).toBe(202);
  expect(res.headers.get("x-transformed")).toBe("yes");
  expect(await res.text()).toBe("handler:unset!");
  const head = await fetch(server.url + "/transform", { method: "HEAD" });
  expect(head.status).toBe(202);
  expect(head.headers.get("x-transformed")).toBe("yes");
  expect(head.headers.get("content-length")).toBe("14");
  expect(await head.text()).toBe("");
});

test.each([
  ["/users/42", "handler:Ada"],
  ["/users/no", "handler:unset"],
  ["/optional", "handler:Ada"],
  ["/optional/Leo", "handler:Ada"],
  ["/plain", "handler:unset"],
])("per-path middleware uses BND-14 patterns: %s", async (path, body) => {
  const res = await fetch(server.url + path);
  expect(res.status).toBe(200);
  expect(await res.text()).toBe(body);
});

test("global middleware covers 404 and 405, retaining Allow", async () => {
  const missing = await fetch(server.url + "/missing");
  expect(missing.status).toBe(404);
  expect(missing.headers.get("x-middleware")).toBe("yes");
  const wrongMethod = await fetch(server.url + "/plain", { method: "POST" });
  expect(wrongMethod.status).toBe(405);
  expect(wrongMethod.headers.get("x-middleware")).toBe("yes");
  expect(wrongMethod.headers.get("allow")).toBe("GET, HEAD");
});

test("final response validation rejects invalid post-next headers", async () => {
  const res = await fetch(server.url + "/bad");
  expect(res.status).toBe(500);
  expect(await res.text()).toBe("");
});

test("middleware registrations do not appear in the route manifest", () => {
  const proc = Bun.spawnSync([binary, "--bendo-routes"], { stdout: "pipe", stderr: "pipe" });
  expect(proc.exitCode).toBe(0);
  const manifest: unknown = JSON.parse(proc.stdout.toString());
  expect(manifest).toEqual({
    bendo: 1,
    routes: [
      { method: "GET", path: "/order" },
      { method: "GET", path: "/private/hello" },
      { method: "GET", path: "/transform" },
      { method: "GET", path: "/bad" },
      { method: "GET", path: "/users/:id" },
      { method: "GET", path: "/optional/*" },
      { method: "GET", path: "/plain" },
    ],
  });
});

test(
  "Bend rejects a middleware that calls its continuation twice",
  () => {
    expect(() => build("tests/fixtures/middleware/repeated-next.bend")).toThrow(
      "next (consumed more than once)",
    );
  },
  COMPILE_TEST_TIMEOUT_MS,
);

test(
  "network-free handle_with shares the onion and validates middleware patterns",
  () => {
    const driver = build("tests/middleware-driver.bend");
    const result = Bun.spawnSync(["timeout", "--foreground", "30s", driver], {
      stdout: "pipe",
      stderr: "pipe",
    });
    expect(result.exitCode).toBe(0);
    expect(result.stdout.toString()).toBe(
      "PASS invalid middleware pattern index\nPASS handle_with\nPASS handle_with\n",
    );
  },
  COMPILE_TEST_TIMEOUT_MS,
);
