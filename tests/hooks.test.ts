import { afterAll, beforeAll, expect, test } from "bun:test";
import { build, start, type RunningServer } from "./harness.ts";

const binary = build("tests/servers/hooks.bend");
const timeoutBinary = build("tests/servers/hooks-timeout.bend");
let server: RunningServer;
beforeAll(async () => {
  server = await start(binary);
});
afterAll(async () => {
  await server?.[Symbol.asyncDispose]();
});

const full = "request1,request2,parse,transform,before,handler,after1,after2,map1,map2";
test("all stages have fixed order, with registration order within each stage", async () => {
  const res = await fetch(server.url + "/order", { method: "POST", body: "raw" });
  expect(res.status).toBe(200);
  expect(res.headers.get("x-parsed")).toBe("raw");
  expect(res.headers.get("x-transformed")).toBe("raw!");
  expect(res.headers.get("content-type")).toBe("application/x-hooks");
  expect(await res.text()).toBe(full);
});
test("request hooks rewrite method and path before routing and path middleware selection", async () => {
  const res = await fetch(server.url + "/rewrite");
  expect(res.status).toBe(200);
  expect(res.headers.get("x-path-middleware")).toBe("yes");
  expect(await res.text()).toBe(full);
});
test("routing rewrites preserve the original HEAD wire semantics", async () => {
  const res = await fetch(server.url + "/rewrite", { method: "HEAD" });
  expect(res.status).toBe(200);
  expect(res.headers.get("content-length")).toBe(String(full.length));
  expect(await res.text()).toBe("");
});

test.each([
  ["/request-stop", "request1,after1,after2,map1,map2"],
  ["/before-stop", "request1,request2,parse,transform,before,after1,after2,map1,map2"],
])("%s short circuits but final response hooks run", async (path, trace) => {
  const res = await fetch(server.url + path);
  expect(res.status).toBe(200);
  expect(await res.text()).toBe(trace);
});
test.each(["/error", "/request-error", "/before-error", "/map-error"])(
  "on_error recovers an error response from %s",
  async (path) => {
    const res = await fetch(server.url + path);
    expect(res.status).toBe(202);
    expect(await res.text()).toEndWith(",error1,error2");
  },
);
test("on_after_response cannot alter sent bytes and runs after send, including errors", async () => {
  // The hook blocks on a release message. Receiving the response before releasing
  // it proves that the bytes are sent before the hook completes.
  for (const path of ["/after-gate", "/after-error-gate"]) {
    const res = await fetch(server.url + path, {
      headers: { connection: "close" },
      signal: AbortSignal.timeout(5000),
    });
    const body = await res.text();
    expect(res.status).toBe(path === "/after-gate" ? 200 : 202);
    expect(body).toBe(path === "/after-gate" ? full : full + ",error1,error2");
    const release = await fetch(server.url + "/release", {
      headers: { connection: "close" },
      signal: AbortSignal.timeout(5000),
    });
    expect(await release.text()).toBe("released");
    const count = await fetch(server.url + "/completed", {
      headers: { connection: "close" },
      signal: AbortSignal.timeout(5000),
    });
    expect(await count.text()).toBe("after-response1,after-response2");
  }
});

test("a timed-out middleware continuation can finish after the response without crashing", async () => {
  await using lateServer = await start(timeoutBinary);
  const response = await fetch(lateServer.url + "/late", { headers: { connection: "close" } });
  expect(response.status).toBe(504);
  expect(await response.text()).toContain("timed-out");
  const completed = await fetch(lateServer.url + "/late-done", {
    headers: { connection: "close" },
    signal: AbortSignal.timeout(5000),
  });
  expect(await completed.text()).toBe("late completed");
  expect((await fetch(lateServer.url + "/")).status).toBe(200);
});
