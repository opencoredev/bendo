import { afterAll, expect, test } from "bun:test";
import { createHash } from "node:crypto";
import { connect } from "node:net";
import { Agent, request } from "node:http";
import { build, compile, start, SLOW_TEST_TIMEOUT_MS } from "./harness.ts";
import { pathToFileURL } from "node:url";

const binary = build("tests/servers/mw-limits.bend");
const conditionalModule = compile("tests/fixtures/limits/conditional.bend", "mjs");
const loaded: unknown = await import(pathToFileURL(conditionalModule).href);
if (typeof loaded !== "object" || loaded === null || !("default" in loaded))
  throw new Error("Missing Bend module");
const exports: unknown = loaded.default;
function exported(name: string): (...args: unknown[]) => unknown {
  if (typeof exports !== "object" || exports === null || !(name in exports))
    throw new Error(`Missing export ${name}`);
  const fn: unknown = Reflect.get(exports, name);
  if (typeof fn !== "function") throw new Error(`Not callable: ${name}`);
  return (...args) => fn(...args);
}
const matchText = exported("match_text");
const cacheValues = exported("cache_values");
const server = await start(binary);
afterAll(() => server[Symbol.asyncDispose]());
const get = (path: string, init?: RequestInit) => fetch(server.url + path, init);

// Stop on the framed response, not staged-close EOF. No body bytes beyond the
// admission limit are sent, so accepting these requests would hang the client.
function early(raw: string): Promise<string> {
  return new Promise((resolve, reject) => {
    const socket = connect(Number(new URL(server.url).port), "127.0.0.1");
    let received = "";
    const timer = setTimeout(() => socket.destroy(new Error("no early response")), 5000);
    socket.on("error", reject);
    socket.on("close", () => clearTimeout(timer));
    socket.on("connect", () => socket.write(raw));
    socket.on("data", (chunk: Buffer) => {
      received += chunk.toString("latin1");
      if (received.includes("\r\n\r\n")) {
        resolve(received);
        socket.destroy();
      }
    });
  });
}

test("sleeping handler times out with a negotiated 504; server remains available", async () => {
  const res = await get("/slow", {
    headers: { accept: "application/json", "x-request-id": "timeout-41" },
  });
  expect(res.status).toBe(504);
  expect(await res.json()).toEqual({ error: "Gateway Timeout", status: 504 });
  expect(res.headers.get("x-request-id")).toBe("timeout-41");
  expect(res.headers.get("server-timing")).toMatch(/^total;dur=\d+$/);
  expect((await get("/")).status).toBe(200);
});

test("late store mutation commits after 504 while late handler response is discarded", async () => {
  const agent = new Agent({ keepAlive: true, maxSockets: 1 });
  function persistent(path: string): Promise<{ status: number; body: string; reused: boolean }> {
    return new Promise((resolve, reject) => {
      const req = request(server.url + path, { agent }, (res) => {
        let body = "";
        res.setEncoding("utf8");
        res.on("data", (chunk: string) => {
          body += chunk;
        });
        res.on("error", reject);
        res.on("end", () =>
          resolve({ status: res.statusCode ?? 0, body, reused: req.reusedSocket }),
        );
      });
      req.setTimeout(5000, () => req.destroy(new Error("persistent request timed out")));
      req.on("error", reject);
      req.end();
    });
  }
  try {
    const response = await persistent("/late");
    expect(response.status).toBe(504);
    expect(response.body).toBe("Gateway Timeout");
    const deadline = Date.now() + 5000;
    let value = "0";
    while (Date.now() < deadline && value === "0") {
      const count = await persistent("/count");
      expect(count.status).toBe(200);
      expect(count.reused).toBe(true);
      value = count.body;
      if (value === "0") await Bun.sleep(10);
    }
    expect(value).toBe("1");
    // No late response may become a second response on this same socket.
    expect((await persistent("/count")).body).toBe("1");
  } finally {
    agent.destroy();
  }
});

test(
  "pure work delays the deadline until an effect; elapsed time grows with the work",
  async () => {
    async function sample(path: string) {
      const begin = performance.now();
      const res = await get(path);
      expect(res.status).toBe(504);
      expect(await res.text()).toBe("Gateway Timeout");
      const elapsed = performance.now() - begin;
      // The sample is saved by the continuing handler at its first effects.
      await Bun.sleep(150);
      const work = Number(await (await get("/work")).text());
      expect(Number.isFinite(work)).toBe(true);
      expect(elapsed + 1).toBeGreaterThanOrEqual(work);
      return { elapsed, work };
    }
    const small = await sample("/cpu/small");
    const large = await sample("/cpu/large");
    expect(large.work).toBeGreaterThan(small.work);
    expect(large.elapsed).toBeGreaterThan(small.elapsed);
    console.error("cooperative timeout samples", { small, large });
  },
  SLOW_TEST_TIMEOUT_MS,
);

test("strong SHA-256 base64url validator; weak list and wildcard yield bodyless 304", async () => {
  const first = await get("/");
  const bytes = new Uint8Array(await first.arrayBuffer());
  const tag = `"${createHash("sha256").update(bytes).digest("base64url")}"`;
  expect(first.headers.get("etag")).toBe(tag);
  for (const value of [tag, `W/${tag}`, `"other,tag", W/${tag}`, "*", `, , ${tag},`]) {
    const res = await get("/", { headers: { "if-none-match": value } });
    expect(res.status).toBe(304);
    expect(await res.text()).toBe("");
    for (const name of ["etag", "cache-control", "vary", "date", "content-location", "expires"])
      expect(res.headers.get(name)).toBe(first.headers.get(name));
    for (const name of ["content-type", "content-length", "content-encoding", "x-drop"])
      expect(res.headers.get(name)).toBeNull();
  }
  const head = await get("/", { method: "HEAD" });
  expect(head.headers.get("etag")).toBe(tag);
  expect(head.headers.get("content-length")).toBe(String(bytes.length));
  expect(await head.text()).toBe("");
  const head304 = await get("/", { method: "HEAD", headers: { "if-none-match": `W/${tag}` } });
  expect(head304.status).toBe(304);
  expect(head304.headers.get("content-length")).toBeNull();
  expect(await head304.text()).toBe("");
});

test("conditional parser follows entity-tag grammar, including literal slash, comma and backslash", () => {
  const cases: readonly [string, string, boolean][] = [
    ['W/"abc"', '"abc"', true],
    ['"abc"', 'W/"abc"', true],
    ['"a,b", "c"', '"a,b"', true],
    ['"a\\", "b"', '"a\\"', true],
    ['w/"abc"', '"abc"', false],
    ['"abc", garbage', '"abc"', false],
    ['*, "abc"', '"abc"', false],
    ['"abc" trailing', '"abc"', false],
    ['"a b"', '"a b"', false],
    ['"abc', '"abc"', false],
    ['"abc"', '"ABC"', false],
    ["*", "invalid", false],
    [",,", '"abc"', false],
  ];
  for (const [field, tag, expected] of cases) expect(matchText(field, tag)).toBe(expected);
});

test("ETag skips non-200 and unsafe methods; cache helpers emit stable values", async () => {
  for (const [path, method] of [
    ["/absent", "GET"],
    ["/small", "POST"],
  ] satisfies [string, string][]) {
    const res = await get(path, { method });
    expect(res.headers.get("etag")).toBeNull();
  }
  expect((await get("/")).headers.get("cache-control")).toBe("public, max-age=60, immutable");
  expect(cacheValues()).toBe("no-store|no-cache|private, max-age=7|public, max-age=8");
});

test("route and guard byte limits accept the boundary and reject before receiving the body", async () => {
  for (const [path, size] of [
    ["/small", 4],
    ["/large", 8],
    ["/guard", 2],
  ] satisfies [string, number][]) {
    const accepted = await get(path, { method: "POST", body: "a".repeat(size) });
    expect(accepted.status).toBe(200);
    expect(await accepted.text()).toBe("a".repeat(size));
    const rejected = await early(
      `POST ${path} HTTP/1.1\r\nHost: x\r\nContent-Length: ${size + 1}\r\nExpect: 100-continue\r\n\r\n`,
    );
    expect(rejected).toStartWith("HTTP/1.1 413 ");
    expect(rejected).not.toContain("100 Continue");
    const chunked = await early(
      `POST ${path} HTTP/1.1\r\nHost: x\r\nTransfer-Encoding: chunked\r\n\r\n1\r\na\r\n${size.toString(16)}\r\n`,
    );
    expect(chunked).toStartWith("HTTP/1.1 413 ");
  }
});

test("transport uses original-route admission; rewrites also enforce the destination limit", async () => {
  expect((await get("/to-small", { method: "POST", body: "12345" })).status).toBe(413);
  expect((await get("/to-large", { method: "POST", body: "12345" })).status).toBe(413);
  const allowed = await get("/to-large", { method: "POST", body: "1234" });
  expect(allowed.status).toBe(200);
  expect(await allowed.text()).toBe("1234");
});

test("early negotiated 413 respects HEAD and returns no payload", async () => {
  const bytes = await new Promise<Buffer>((resolve, reject) => {
    const chunks: Buffer[] = [];
    const socket = connect(Number(new URL(server.url).port), "127.0.0.1");
    socket.setTimeout(5000, () => socket.destroy(new Error("HEAD rejection did not close")));
    socket.on("error", reject);
    socket.on("data", (chunk: Buffer) => chunks.push(chunk));
    socket.on("end", () => {
      resolve(Buffer.concat(chunks));
      socket.destroy();
    });
    socket.on("connect", () =>
      socket.end(
        "HEAD /head-limit HTTP/1.1\r\nHost: x\r\nAccept: application/json\r\nContent-Length: 5\r\n\r\n",
      ),
    );
  });
  const raw = bytes.toString("latin1");
  expect(raw).toStartWith("HTTP/1.1 413 ");
  expect(raw).toContain("content-type: application/json; charset=utf-8\r\n");
  expect(bytes.subarray(bytes.indexOf("\r\n\r\n") + 4).length).toBe(0);
});

test("early route-limit errors negotiate JSON through C.error", async () => {
  const res = await get("/small", {
    method: "POST",
    headers: { accept: "application/json" },
    body: "12345",
  });
  expect(res.status).toBe(413);
  expect(await res.json()).toEqual({ error: "Content Too Large", status: 413 });
});
