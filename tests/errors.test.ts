import { afterAll, beforeAll, expect, test } from "bun:test";
import { Agent, get } from "node:http";
import { build, start, type RunningServer } from "./harness.ts";

const binary = build("tests/servers/errors.bend");
let server: RunningServer;
beforeAll(async () => {
  server = await start(binary);
});
afterAll(async () => {
  await server?.[Symbol.asyncDispose]();
});

function request(path: string, accept = "text/plain", method = "GET") {
  return fetch(server.url + path, {
    method,
    headers: { accept },
    signal: AbortSignal.timeout(5000),
  });
}

test("HttpError and Result failures return the configured 418 without killing the server", async () => {
  const tea = await request("/teapot", "application/json");
  expect(tea.status).toBe(418);
  expect(tea.headers.get("content-type")).toStartWith("application/json");
  expect(await tea.text()).toBe('{"error":"tea \\"only\\"\\n☕","status":418}');
  const result = await request("/result");
  expect(result.status).toBe(418);
  expect(await result.text()).toBe("result teapot");
  expect(await (await request("/")).text()).toBe("ok");
});

test.each(["text/plain", "application/json"])(
  "private 5xx and invalid statuses conceal internals (%s)",
  async (accept) => {
    for (const path of ["/private", "/invalid"]) {
      const res = await request(path, accept);
      const status = path === "/private" ? 503 : 500;
      expect(res.status).toBe(status);
      expect(res.headers.get("vary")).toBe("Accept");
      expect(res.headers.get("x-request-id")).toBeTruthy();
      expect(res.headers.get("server-timing")).toContain("total;dur=");
      if (accept === "application/json")
        expect(await res.text()).toBe(`{"error":"Internal Server Error","status":${status}}`);
      else expect(await res.text()).toBe("Internal Server Error");
    }
  },
);

test("explicit exposure and existing on_error recovery remain available", async () => {
  expect(await (await request("/exposed")).text()).toBe("Maintenance");
  const res = await request("/recover");
  expect(res.status).toBe(202);
  expect(await res.text()).toBe("recovered");
  expect(res.headers.get("x-request-id")).toBeTruthy();
  expect(res.headers.get("server-timing")).toContain("total;dur=");
});

test("custom not-found replaces route misses only, with negotiated fallback and HEAD framing", async () => {
  const custom = await request("/custom-missing");
  expect(custom.status).toBe(404);
  expect(await custom.text()).toBe("custom missing");
  const fallback = await request("/missing", "application/json");
  expect(fallback.status).toBe(404);
  expect(await fallback.text()).toBe('{"error":"Not Found","status":404}');
  expect(await (await request("/handler404")).text()).toBe("handler missing");
  const method = await request("/teapot", "application/json", "POST");
  expect(method.status).toBe(405);
  expect(method.headers.get("allow")).toContain("GET");
  const head = await request("/teapot", "application/json", "HEAD");
  expect(head.status).toBe(418);
  expect(Number(head.headers.get("content-length"))).toBeGreaterThan(0);
  expect(await head.text()).toBe("");
});

test.each([
  ["application/json;q=1, text/plain;q=0", true],
  ["text/plain, Application/JSON; charset=utf-8; q=0.5", true],
  ["application/json;q=0", false],
  ["application/json;q=0.000", false],
  ["application/json;q=1.001", false],
  ["application/json;q=0.1234", false],
  ['application/json;profile="a,b";q=0', false],
  ['application/json;profile="a;b";q=0', false],
  ['application/json;profile="a,b;c";q=0.5', true],
  ['application/json;profile="a\\\"b,c";q=0', false],
  ['application/json;profile="unclosed', false],
  ["*/*", false],
])("error negotiation honors explicit JSON ranges: %s", async (accept, json) => {
  const res = await request("/private", accept);
  expect(res.headers.get("content-type")).toStartWith(json ? "application/json" : "text/plain");
});

test("error conversion preserves Vary and not-found forwarded context reaches error hooks", async () => {
  expect((await request("/vary")).headers.get("vary")).toBe("Origin, Accept-Encoding, Accept");
  expect((await request("/vary-star")).headers.get("vary")).toBe("*");
  const res = await request("/context-missing");
  expect(res.status).toBe(404);
  expect(res.headers.get("x-context")).toBe("forwarded");
  expect(await res.text()).toBe("context visible");
});

// Raw header bytes, decoded one byte per char, so obs-text is visible.
function rawHeaders(path: string): Promise<{ status: number; headers: string[] }> {
  return new Promise((resolve, reject) => {
    const req = get(server.url + path, { timeout: 5000, headers: { accept: "text/plain" } }, (res) => {
      res.resume();
      res.on("end", () => resolve({ status: res.statusCode ?? 0, headers: res.rawHeaders }));
    });
    req.on("timeout", () => req.destroy(new Error("timeout")));
    req.on("error", reject);
  });
}

function rawValues(headers: string[], name: string): string[] {
  const values: string[] = [];
  for (let i = 0; i + 1 < headers.length; i += 2) {
    const key = headers[i];
    const value = headers[i + 1];
    if (key !== undefined && value !== undefined && key.toLowerCase() === name) values.push(value);
  }
  return values;
}

test("errors validate the headers the client receives, after the Vary merge", async () => {
  // A trailing space becomes interior once Accept is appended, so it is valid.
  const trailing = await request("/vary-trailing");
  expect(trailing.status).toBe(400);
  expect(trailing.headers.get("vary")).toBe("Origin , Accept");
  // A leading space stays leading, so the effective field is invalid.
  const leading = await request("/vary-leading");
  expect(leading.status).toBe(500);
  expect(leading.headers.get("vary")).toBeNull();
  expect(await leading.text()).toBe("");
  // Existing Vary bytes are copied, not re-encoded: x-é stays C3 A9.
  const obs = await rawHeaders("/vary-obs");
  expect(obs.status).toBe(400);
  expect(rawValues(obs.headers, "vary").map((v) => Buffer.from(v, "latin1").toString("hex"))).toEqual([
    Buffer.from("x-\u00c3\u00a9, Accept", "latin1").toString("hex"),
  ]);
  // Other headers keep their order; the merged Vary field comes last.
  const kept = await rawHeaders("/vary-kept");
  expect(kept.status).toBe(400);
  const names = kept.headers.filter((_, i) => i % 2 === 0).map((n) => n.toLowerCase());
  expect(names.indexOf("x-a")).toBeLessThan(names.indexOf("x-b"));
  expect(names.indexOf("x-b")).toBeLessThan(names.indexOf("vary"));
  expect(rawValues(kept.headers, "vary")).toEqual(["Origin, Accept"]);
  // A replaced Content-Type never reaches the client, so it cannot fail it.
  const typed = await request("/replaced-type");
  expect(typed.status).toBe(400);
  expect(typed.headers.get("content-type")).toBe("text/plain; charset=utf-8");
  expect(await typed.text()).toBe("typed");
  // An invalid header that would be sent turns the error into the empty 500.
  const bad = await request("/bad-kept");
  expect(bad.status).toBe(500);
  expect(bad.headers.get("x-note")).toBeNull();
  expect(await bad.text()).toBe("");
});

// Resolve on either a response or a socket error, so the pending request never
// creates an unhandled rejection when the process dies.
function onConnection(url: string, agent: Agent): Promise<string> {
  return new Promise((resolve) => {
    const req = get(url, { agent, timeout: 5000 }, (res) => {
      let body = "";
      res.setEncoding("utf8");
      res.on("data", (chunk) => {
        body += chunk;
      });
      res.on("end", () => resolve(body));
      res.on("error", () => resolve("socket error"));
    });
    req.on("error", () => resolve("socket error"));
    req.on("timeout", () => {
      resolve("timeout");
      req.destroy();
    });
  });
}

test("IO.die exits the whole process, dropping a gated request on another keep-alive connection", async () => {
  const port = 20000 + Math.floor(Math.random() * 20000);
  const url = `http://127.0.0.1:${port}`;
  const proc = Bun.spawn([binary], {
    env: { ...process.env, PORT: String(port) },
    stdout: "ignore",
    stderr: "pipe",
  });
  const agent = new Agent({ keepAlive: true, maxSockets: 1 });
  try {
    const deadline = Date.now() + 20000;
    let ready = false;
    while (Date.now() < deadline && proc.exitCode === null) {
      ready = await fetch(url, { signal: AbortSignal.timeout(1000) }).then(
        (r) => r.ok,
        () => false,
      );
      if (ready) break;
      await Bun.sleep(50);
    }
    expect(ready).toBe(true);
    expect(await onConnection(url + "/", agent)).toBe("ok");
    const pending = onConnection(url + "/pending", agent);
    // This rendezvous proves /pending reached its gate before /crash is sent.
    expect(
      await (await fetch(url + "/entered", { signal: AbortSignal.timeout(5000) })).text(),
    ).toBe("entered");
    const crash = fetch(url + "/crash", { signal: AbortSignal.timeout(5000) }).then(
      () => "response",
      (error: unknown) =>
        error instanceof Error && error.name === "TimeoutError" ? "timeout" : "socket error",
    );
    expect(await Promise.race([proc.exited, Bun.sleep(5000).then(() => "timeout")])).toBe(23);
    expect(await crash).toBe("socket error");
    expect(await pending).toBe("socket error");
    expect(await new Response(proc.stderr).text()).toContain("BND-25 deliberate crash");
    expect(
      await fetch(url, { signal: AbortSignal.timeout(1000) }).then(
        () => true,
        () => false,
      ),
    ).toBe(false);
  } finally {
    agent.destroy();
    if (proc.exitCode === null) proc.kill();
    await proc.exited;
  }
});
