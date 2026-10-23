import { beforeEach, afterEach, expect, test } from "bun:test";
import { Agent, request } from "node:http";
import type { Socket } from "node:net";
import { build, start, type RunningServer } from "./harness.ts";

const binary = build("tests/servers/store.bend");
const example = build("examples/store/main.bend");
let server: RunningServer;
beforeEach(async () => {
  server = await start(binary);
});
afterEach(async () => {
  await server[Symbol.asyncDispose]();
});

async function call(path: string, method = "GET"): Promise<string> {
  const response = await fetch(server.url + path, { method, signal: AbortSignal.timeout(5000) });
  expect(response.status).toBe(200);
  return response.text();
}

function increment(agent: Agent, sockets: Set<Socket>): Promise<number> {
  return new Promise((resolve, reject) => {
    const req = request(server.url + "/counter", { method: "POST", agent }, (response) => {
      const chunks: Buffer[] = [];
      response.on("data", (chunk: Buffer) => chunks.push(chunk));
      response.on("error", reject);
      response.on("end", () => {
        const text = Buffer.concat(chunks).toString("utf8");
        if (response.statusCode !== 200 || !/^[0-9]+$/.test(text)) {
          reject(new Error(`increment failed: ${response.statusCode} ${text}`));
          return;
        }
        resolve(Number(text));
      });
    });
    req.on("socket", (socket) => sockets.add(socket));
    req.on("error", reject);
    req.setTimeout(5000, () => req.destroy(new Error("increment timeout")));
    req.end();
  });
}

test("1,000 increments on 50 unchanged keep-alive connections never lose a write", async () => {
  const agents = Array.from({ length: 50 }, () => new Agent({ keepAlive: true, maxSockets: 1 }));
  const sockets = new Set<Socket>();
  try {
    const replies = await Promise.all(
      agents.map(async (agent) => {
        const values: number[] = [];
        for (let i = 0; i < 20; i++) values.push(await increment(agent, sockets));
        return values;
      }),
    );
    expect(sockets.size).toBe(50);
    expect(replies.flat().sort((a, b) => a - b)).toEqual(
      Array.from({ length: 1000 }, (_, i) => i + 1),
    );
    expect(await call("/counter")).toBe("1000");
  } finally {
    for (const agent of agents) agent.destroy();
  }
});

test("get and set acknowledge state; update returns the atomic new value", async () => {
  expect(await call("/counter")).toBe("0");
  expect(await call("/counter?n=41", "PUT")).toBe("set");
  expect(await call("/counter")).toBe("41");
  expect(await call("/counter", "POST")).toBe("42");
  expect(await call("/counter")).toBe("42");
});

test("two stores with different state types stay independent", async () => {
  expect(await call("/todos")).toBe("");
  expect(await call("/counter?n=9", "PUT")).toBe("set");
  expect(await call("/todos?title=buy+milk", "POST")).toBe("1");
  expect(await call("/todos")).toBe("1:buy milk");
  expect(await call("/todos?title=done", "POST")).toBe("1");
  expect(await call("/todos")).toBe("1:done");
  expect(await call("/counter")).toBe("9");
  expect(await call("/todos", "DELETE")).toBe("set");
  expect(await call("/todos")).toBe("");
  expect(await call("/counter", "POST")).toBe("10");
});

test("state survives connection closure and a handler's 500 response", async () => {
  const first = await fetch(server.url + "/counter", {
    method: "POST",
    headers: { connection: "close" },
  });
  expect(await first.text()).toBe("1");
  const failed = await fetch(server.url + "/error", { headers: { connection: "close" } });
  expect(failed.status).toBe(500);
  expect(await failed.text()).toBe("handler failed");
  expect(await call("/counter")).toBe("2");
  expect(await call("/counter", "POST")).toBe("3");
});

test.each([
  ["/dead", "unavailable"],
  ["/closed-reply", "unavailable"],
  ["/silent", "timed out"],
  ["/full", "timed out"],
])("%s becomes a bounded 503", async (path, message) => {
  const response = await fetch(server.url + path, { signal: AbortSignal.timeout(5000) });
  expect(response.status).toBe(503);
  expect(await response.text()).toBe(message);
  expect(await call("/counter", "POST")).toBe("1");
});

test("a timed-out mutation commits once; its closed reply does not kill the real actor", async () => {
  const timedOut = await fetch(server.url + "/late", {
    method: "POST",
    signal: AbortSignal.timeout(5000),
  });
  expect(timedOut.status).toBe(503);
  expect(await timedOut.text()).toBe("timed out");
  expect(await call("/release", "POST")).toBe("released");
  expect(await call("/late")).toBe("1");
  expect(await call("/late", "POST")).toBe("2");
  expect(await call("/late")).toBe("2");
});

test("mailbox and reply waits share one operation deadline", async () => {
  const elapsed = Number(await call("/budget"));
  expect(elapsed).toBeGreaterThanOrEqual(1400);
  // A fresh 1500ms reply budget after the 1000ms send would take >=2500ms.
  expect(elapsed).toBeLessThan(2200);
});

test("documented counter and todo example serves the public store API", async () => {
  await using app = await start(example);
  const incremented = await fetch(app.url + "/counter", { method: "POST" });
  expect(incremented.status).toBe(200);
  expect(await incremented.text()).toBe("1");
  const todo = await fetch(app.url + "/todos?title=buy+milk", { method: "POST" });
  expect(todo.status).toBe(200);
  expect(await todo.text()).toBe("1");
  const read = await fetch(app.url + "/todos");
  expect(await read.text()).toBe("1:buy milk");
  const counter = await fetch(app.url + "/counter");
  expect(await counter.text()).toBe("1");
});
