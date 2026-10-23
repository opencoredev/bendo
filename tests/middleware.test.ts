import { connect } from "node:net";
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

async function handlerCount(): Promise<number> {
  const res = await fetch(server.url + "/__count");
  expect(res.status).toBe(200);
  return Number(await res.text());
}

function headBytes(): Promise<Buffer> {
  const address = new URL(server.url);
  return new Promise((resolve, reject) => {
    const chunks: Buffer[] = [];
    const socket = connect(Number(address.port), address.hostname, () => {
      socket.write("HEAD /transform HTTP/1.1\r\nHost: test\r\nConnection: close\r\n\r\n");
    });
    socket.setTimeout(5000, () => socket.destroy(new Error("HEAD exchange timed out")));
    socket.on("data", (chunk: Buffer) => chunks.push(chunk));
    socket.on("end", () => resolve(Buffer.concat(chunks)));
    socket.on("error", reject);
  });
}

test("short circuit skips the handler and downstream typed-variable middleware", async () => {
  const before = await handlerCount();
  const denied = await fetch(server.url + "/private/hello");
  expect(denied.status).toBe(401);
  expect(denied.headers.get("x-handler")).toBeNull();
  expect(await denied.text()).toBe("denied");
  expect(await handlerCount()).toBe(before);
  const allowed = await fetch(server.url + "/private/hello", { headers: { "x-auth": "yes" } });
  expect(allowed.status).toBe(200);
  expect(allowed.headers.get("x-handler")).toBe("ran");
  expect(await allowed.text()).toBe("handler:Ada");
  expect(await handlerCount()).toBe(before + 1);
});

test("post-next middleware transforms status, headers and body before HEAD normalization", async () => {
  const res = await fetch(server.url + "/transform");
  expect(res.status).toBe(202);
  expect(res.headers.get("x-transformed")).toBe("yes");
  expect(await res.text()).toBe("handler:unset!");
  const wire = await headBytes();
  const boundary = wire.indexOf("\r\n\r\n");
  expect(boundary).toBeGreaterThan(0);
  const head = wire.subarray(0, boundary).toString("latin1").toLowerCase();
  expect(head).toStartWith("http/1.1 202 ");
  expect(head).toContain("\r\nx-transformed: yes");
  expect(head.split("\r\n")).toContain(`content-length: ${res.headers.get("content-length")}`);
  expect(res.headers.get("content-length")).toBe("14");
  expect(wire.subarray(boundary + 4)).toHaveLength(0);
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
      { method: "GET", path: "/__count", params: [] },
      { method: "GET", path: "/order", params: [] },
      { method: "GET", path: "/private/hello", params: [] },
      { method: "GET", path: "/transform", params: [] },
      { method: "GET", path: "/bad", params: [] },
      { method: "GET", path: "/users/:id", params: ["id"] },
      { method: "GET", path: "/optional/*", params: ["*"] },
      { method: "GET", path: "/plain", params: [] },
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
