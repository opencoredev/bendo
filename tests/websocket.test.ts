import { afterAll, expect, test } from "bun:test";
import { createHash } from "node:crypto";
import { mkdtempSync, rmSync } from "node:fs";
import { connect, type Socket } from "node:net";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { build } from "./harness.ts";

// Compilation stays at module scope, so the harness's compile budget applies.
const binary = build("tests/servers/websocket.bend");

// Test-only clock fault (LD_PRELOAD): the wall clock fails, monotonic time works.
const clockDirectory = mkdtempSync(join(tmpdir(), "bendo-websocket-clock-"));
const clockShim = join(clockDirectory, "clock-fail.so");
if (process.platform === "linux") {
  const run = Bun.spawnSync(
    [
      "timeout",
      "10s",
      "cc",
      "-shared",
      "-fPIC",
      "tests/fixtures/stream/clock-fail.c",
      "-o",
      clockShim,
      "-ldl",
    ],
    { stdout: "pipe", stderr: "pipe" },
  );
  if (run.exitCode !== 0) throw new Error(`clock fault fixture compile failed: ${run.stderr}`);
}
afterAll(() => rmSync(clockDirectory, { recursive: true, force: true }));

type Logged = {
  url: string;
  port: number;
  log: () => string;
  accessLog: () => string;
  stop: () => Promise<void>;
};

// The harness's start() discards stdout; these tests read the fixture's
// session, cleanup and observer lines, so they collect it themselves.
async function startLogged(env: Readonly<Record<string, string>> = {}): Promise<Logged> {
  for (let attempt = 0; attempt < 3; attempt++) {
    const port = 20000 + Math.floor(Math.random() * 10000);
    const proc = Bun.spawn([binary], {
      env: { ...process.env, ...env, PORT: String(port) },
      stdout: "pipe",
      stderr: "pipe",
    });
    let output = "";
    let accessOutput = "";
    void (async () => {
      const decoder = new TextDecoder();
      for await (const part of proc.stdout) output += decoder.decode(part, { stream: true });
    })();
    void (async () => {
      const decoder = new TextDecoder();
      for await (const part of proc.stderr) accessOutput += decoder.decode(part, { stream: true });
    })();
    const url = `http://127.0.0.1:${port}`;
    const deadline = Date.now() + 20_000;
    while (Date.now() < deadline && proc.exitCode === null) {
      const up = await fetch(`${url}/ws`, { signal: AbortSignal.timeout(1000) }).then(
        () => true,
        () => false,
      );
      if (up)
        return {
          url,
          port,
          log: () => output,
          accessLog: () => accessOutput,
          stop: async () => {
            proc.kill();
            await proc.exited;
          },
        };
      await Bun.sleep(50);
    }
    proc.kill();
    await proc.exited;
  }
  throw new Error("websocket fixture did not start");
}

const server = await startLogged();
afterAll(() => server.stop());

async function waitForLog(text: string, timeoutMs = 3000, read = server.log): Promise<string> {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (read().includes(text)) return read();
    await Bun.sleep(20);
  }
  throw new Error(`log never contained ${JSON.stringify(text)}:\n${read()}`);
}

const count = (text: string) =>
  server
    .log()
    .split("\n")
    .filter((line) => line === text).length;

// One raw connection: everything the server sends, collected in order.
type Wire = {
  socket: Socket;
  received: () => Buffer;
  closed: () => boolean;
  waitFor: (done: (wire: Buffer) => boolean) => Promise<Buffer>;
};

const hasHead = (wire: Buffer) => wire.includes("\r\n\r\n");

function open(payload: string | Buffer, target: Logged = server): Promise<Wire> {
  return new Promise((resolve, reject) => {
    const socket = connect(target.port, "127.0.0.1");
    const parts: Buffer[] = [];
    let ended = false;
    let wake = () => {};
    const changed = () => wake();
    socket.setTimeout(8000, () => socket.destroy(new Error("websocket socket timeout")));
    socket.on("data", (part: Buffer) => {
      parts.push(part);
      changed();
    });
    socket.on("close", () => {
      ended = true;
      changed();
    });
    socket.on("error", reject);
    socket.on("connect", () => {
      socket.write(payload);
      resolve({
        socket,
        received: () => Buffer.concat(parts),
        closed: () => ended,
        // Resolve once done holds or the peer closes; fail after five seconds.
        waitFor: (done) =>
          new Promise((settle, fail) => {
            const timer = setTimeout(() => fail(new Error("websocket wire wait timed out")), 5000);
            const check = () => {
              const wire = Buffer.concat(parts);
              if (done(wire) || ended) {
                clearTimeout(timer);
                wake = () => {};
                settle(wire);
              }
            };
            wake = check;
            check();
          }),
      });
    });
  });
}

const atLeast = (n: number) => (wire: Buffer) => wire.length >= n;

// The complete response: its head, then exactly Content-Length body octets.
function complete(wire: Buffer): boolean {
  const at = wire.indexOf("\r\n\r\n");
  if (at < 0) return false;
  const match = /\r\ncontent-length:\s*(\d+)/i.exec(wire.subarray(0, at).toString("latin1"));
  return match !== null && wire.length >= at + 4 + Number(match[1]);
}

// Send a request and read one complete response (or until the server closes).
async function exchange(payload: string | Buffer, target: Logged = server): Promise<Buffer> {
  const wire = await open(payload, target);
  const response = await wire.waitFor(complete);
  wire.socket.destroy();
  return response;
}

type Head = { status: number; headers: Headers; names: string[]; rest: Buffer };

function head(wire: Buffer): Head {
  const at = wire.indexOf("\r\n\r\n");
  if (at < 0) throw new Error(`missing response head: ${JSON.stringify(wire.toString("latin1"))}`);
  const lines = wire.subarray(0, at).toString("latin1").split("\r\n");
  const headers = new Headers();
  const names: string[] = [];
  for (const line of lines.slice(1)) {
    const colon = line.indexOf(":");
    if (colon < 1) throw new Error("malformed header");
    names.push(line.slice(0, colon).toLowerCase());
    headers.append(line.slice(0, colon), line.slice(colon + 1).trim());
  }
  return { status: Number(lines[0]?.split(" ")[1]), headers, names, rest: wire.subarray(at + 4) };
}

const RFC_KEY = "dGhlIHNhbXBsZSBub25jZQ==";
const RFC_ACCEPT = "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=";
const expectedAccept = (key: string) =>
  createHash("sha1").update(`${key}258EAFA5-E914-47DA-95CA-C5AB0DC85B11`).digest("base64");

type Handshake = {
  path?: string;
  method?: string;
  version?: string;
  // Fields replace the defaults by name (case-insensitive); null removes one.
  fields?: Record<string, string | string[] | null>;
};

function handshake({ path = "/ws", method = "GET", version = "1.1", fields = {} }: Handshake = {}) {
  const defaults: Record<string, string | string[] | null> = {
    host: "test",
    upgrade: "websocket",
    connection: "Upgrade",
    "sec-websocket-key": RFC_KEY,
    "sec-websocket-version": "13",
  };
  const merged = { ...defaults, ...fields };
  const lines = [`${method} ${path} HTTP/${version}`];
  for (const [name, value] of Object.entries(merged)) {
    if (value === null) continue;
    for (const v of Array.isArray(value) ? value : [value]) lines.push(`${name}: ${v}`);
  }
  return `${lines.join("\r\n")}\r\n\r\n`;
}

test("RFC 6455 key yields the RFC accept value on the wire", async () => {
  expect(expectedAccept(RFC_KEY)).toBe(RFC_ACCEPT);
  const wire = await open(handshake());
  const response = head(await wire.waitFor(hasHead));
  wire.socket.destroy();
  expect(response.status).toBe(101);
  expect(response.headers.get("sec-websocket-accept")).toBe(RFC_ACCEPT);
  expect(response.headers.get("upgrade")).toBe("websocket");
  expect(response.headers.get("connection")).toBe("Upgrade");
  for (const name of ["content-length", "transfer-encoding", "sec-websocket-extensions"])
    expect(response.headers.has(name)).toBe(false);
  expect(response.rest.length).toBe(0);
});

test("a real Bun WebSocket client opens and negotiates a subprotocol", async () => {
  const url = `ws://127.0.0.1:${server.port}/subprotocol`;
  const result = await new Promise<{ protocol: string; extensions: string }>((resolve, reject) => {
    const socket = new WebSocket(url, ["chat", "chat.v2"]);
    const timer = setTimeout(() => reject(new Error("WebSocket did not open")), 5000);
    socket.addEventListener("open", () => {
      clearTimeout(timer);
      resolve({ protocol: socket.protocol, extensions: socket.extensions });
      socket.close();
    });
    socket.addEventListener("error", () => reject(new Error("WebSocket error before open")));
  });
  // The server prefers chat.v2; Bun offers permessage-deflate, which is ignored.
  expect(result.protocol).toBe("chat.v2");
  expect(result.extensions).toBe("");
  await waitForLog("open:subprotocol:0");
});

test("HTTP parsing stops after 101: buffered and later octets reach the session raw", async () => {
  const pipelined = "GET /ws HTTP/1.1\r\nHost: test\r\n\r\n";
  const wire = await open(Buffer.concat([Buffer.from(handshake()), Buffer.from(pipelined)]));
  const first = await wire.waitFor(hasHead);
  const response = head(first);
  expect(response.status).toBe(101);
  const headLength = first.length - response.rest.length;
  // The pipelined request is echoed as bytes, never answered as HTTP.
  const echoed = await wire.waitFor(atLeast(headLength + pipelined.length));
  expect(echoed.subarray(headLength).toString("latin1")).toBe(pipelined);
  const binary = Buffer.from([0, 13, 10, 255, 128, 0x81]);
  wire.socket.write(binary);
  const more = await wire.waitFor(atLeast(headLength + pipelined.length + binary.length));
  expect(more.subarray(headLength + pipelined.length).equals(binary)).toBe(true);
  wire.socket.destroy();
  await waitForLog(`open:/ws:${pipelined.length}`);
  expect(more.toString("latin1")).not.toContain("HTTP/1.1 200");
});

test("observers run once for the 101, before the session starts", async () => {
  const before = count("open:/ws:0");
  const wire = await open(handshake({ path: "/ws?observe=1" }));
  await wire.waitFor(hasHead);
  const deadline = Date.now() + 3000;
  while (count("open:/ws:0") === before && Date.now() < deadline) await Bun.sleep(20);
  wire.socket.destroy();
  const lines = server.log().split("\n");
  const opened = lines.lastIndexOf("open:/ws:0");
  expect(opened).toBeGreaterThan(0);
  expect(lines[opened - 1]).toBe("after:/ws");
});

function reason(status: number): string {
  switch (status) {
    case 403:
      return "Forbidden";
    case 426:
      return "Upgrade Required";
    default:
      return "Bad Request";
  }
}

const refusals: [string, Handshake, number][] = [
  ["missing key", { fields: { "sec-websocket-key": null } }, 400],
  [
    "key with a non-base64 character",
    { fields: { "sec-websocket-key": "dGhlIHNhbXBsZSBub25jZQ!=" } },
    400,
  ],
  [
    "noncanonical key (nonzero unused bits)",
    { fields: { "sec-websocket-key": "dGhlIHNhbXBsZSBub25jZR==" } },
    400,
  ],
  ["unpadded key", { fields: { "sec-websocket-key": "dGhlIHNhbXBsZSBub25jZQ" } }, 400],
  [
    "key of 15 octets",
    { fields: { "sec-websocket-key": Buffer.alloc(15, 7).toString("base64") } },
    400,
  ],
  [
    "key of 17 octets",
    { fields: { "sec-websocket-key": Buffer.alloc(17, 7).toString("base64") } },
    400,
  ],
  ["repeated key", { fields: { "sec-websocket-key": [RFC_KEY, RFC_KEY] } }, 400],
  ["POST", { method: "POST" }, 400],
  ["HEAD", { method: "HEAD" }, 400],
  ["HTTP/1.0", { version: "1.0" }, 400],
  ["missing Connection", { fields: { connection: null } }, 400],
  ["Connection without upgrade", { fields: { connection: "keep-alive" } }, 400],
  ["Connection with a longer token", { fields: { connection: "upgrades" } }, 400],
  ["missing Upgrade", { fields: { upgrade: null } }, 400],
  ["Upgrade for another protocol", { fields: { upgrade: "h2c" } }, 400],
  ["nonzero Content-Length", { fields: { "content-length": "1" } }, 400],
  ["missing version", { fields: { "sec-websocket-version": null } }, 400],
  ["repeated version", { fields: { "sec-websocket-version": ["13", "13"] } }, 400],
  ["version 8", { fields: { "sec-websocket-version": "8" } }, 426],
  ["version list", { fields: { "sec-websocket-version": "13, 8" } }, 426],
  ["unlisted origin", { path: "/chat", fields: { origin: "https://evil.example" } }, 403],
  ["missing origin under a listed policy", { path: "/chat" }, 403],
  [
    "repeated origin",
    { path: "/chat", fields: { origin: ["https://app.example", "https://app.example"] } },
    403,
  ],
];

for (const [name, request, status] of refusals)
  test(`refuses ${name} with ${status} and an ordinary error body`, async () => {
    const body = name === "nonzero Content-Length" ? "x" : "";
    const response = head(await exchange(handshake(request) + body));
    expect(response.status).toBe(status);
    expect(response.headers.has("sec-websocket-accept")).toBe(false);
    expect(response.headers.get("upgrade")).toBeNull();
    // HEAD keeps the status and length but never carries the payload.
    expect(response.rest.toString()).toBe(request.method === "HEAD" ? "" : reason(status));
    expect(response.headers.get("sec-websocket-version")).toBe(status === 426 ? "13" : null);
  });

test("JSON clients get the ordinary JSON error for a refused handshake", async () => {
  const response = head(
    await exchange(
      handshake({ fields: { "sec-websocket-version": "8", accept: "application/json" } }),
    ),
  );
  expect(response.status).toBe(426);
  expect(JSON.parse(response.rest.toString())).toEqual({ error: "Upgrade Required", status: 426 });
});

test("a chunked request body is refused even when empty", async () => {
  const response = head(
    await exchange(handshake({ fields: { "transfer-encoding": "chunked" } }) + "0\r\n\r\n"),
  );
  expect(response.status).toBe(400);
  await Bun.sleep(100);
  expect(server.log()).not.toContain("open:/ws:5");
});

const accepted: [string, Handshake][] = [
  ["Content-Length: 0", { fields: { "content-length": "0" } }],
  ["Content-Length: 000", { fields: { "content-length": "000" } }],
  [
    "mixed-case tokens in lists",
    { fields: { upgrade: "foo/1, WebSocket", connection: "keep-alive,  UPGRADE" } },
  ],
  ["repeated Connection fields", { fields: { connection: ["keep-alive", "upgrade"] } }],
  [
    "an extension offer",
    { fields: { "sec-websocket-extensions": "permessage-deflate; client_max_window_bits" } },
  ],
];

for (const [name, request] of accepted)
  test(`accepts ${name}`, async () => {
    const wire = await open(handshake(request));
    const response = head(await wire.waitFor(hasHead));
    wire.socket.destroy();
    expect(response.status).toBe(101);
    expect(response.headers.get("sec-websocket-accept")).toBe(RFC_ACCEPT);
    expect(response.headers.has("sec-websocket-extensions")).toBe(false);
  });

test("a different valid key gets its own accept value", async () => {
  const key = Buffer.from("0123456789abcdef").toString("base64");
  const wire = await open(handshake({ fields: { "sec-websocket-key": key } }));
  const response = head(await wire.waitFor(hasHead));
  wire.socket.destroy();
  expect(response.headers.get("sec-websocket-accept")).toBe(expectedAccept(key));
});

const protocols: [string, string | null, string | null][] = [
  ["server preference wins", "chat, chat.v2", "chat.v2"],
  ["the only shared protocol", "other, chat", "chat"],
  ["no shared protocol omits the field", "other", null],
  ["matching is exact", "CHAT", null],
  ["no offer", null, null],
  ["a configured invalid token is never chosen", "bad token", null],
];

for (const [name, offer, chosen] of protocols)
  test(`subprotocol: ${name}`, async () => {
    const wire = await open(
      handshake({
        path: "/chat",
        fields: { origin: "https://app.example", "sec-websocket-protocol": offer },
      }),
    );
    const response = head(await wire.waitFor(hasHead));
    wire.socket.destroy();
    expect(response.status).toBe(101);
    expect(response.headers.get("sec-websocket-protocol")).toBe(chosen);
  });

test("security and CORS middleware decorate the 101 without breaking it", async () => {
  const wire = await open(
    handshake({ path: "/policy/ws", fields: { origin: "https://app.example" } }),
  );
  const response = head(await wire.waitFor(hasHead));
  wire.socket.destroy();
  expect(response.status).toBe(101);
  expect(response.headers.get("sec-websocket-accept")).toBe(RFC_ACCEPT);
  expect(response.headers.get("access-control-allow-origin")).toBe("https://app.example");
  expect(response.headers.get("x-content-type-options")).toBe("nosniff");
  expect(response.headers.get("x-request-id")).toMatch(/^[0-9a-f]{32}$/);
  expect(response.names).not.toContain("x-bendo-stream-internal");
  expect(response.headers.has("content-length")).toBe(false);
  expect(response.rest.length).toBe(0);
});

test("middleware that garbles handshake fields and framing gets them rebuilt", async () => {
  const wire = await open(handshake({ path: "/garble" }));
  const first = await wire.waitFor(hasHead);
  const response = head(first);
  expect(response.status).toBe(101);
  expect(response.headers.get("sec-websocket-accept")).toBe(RFC_ACCEPT);
  expect(response.headers.get("connection")).toBe("Upgrade");
  expect(response.headers.get("upgrade")).toBe("websocket");
  expect(response.headers.has("content-length")).toBe(false);
  // The garbled body "hi" was dropped: the next octets are the session's echo.
  expect(response.rest.length).toBe(0);
  wire.socket.write("ping");
  const echoed = await wire.waitFor(atLeast(first.length + 4));
  wire.socket.destroy();
  expect(echoed.subarray(first.length).toString()).toBe("ping");
});

test("a replaced response cancels the session", async () => {
  const response = head(await exchange(handshake({ path: "/replace" })));
  expect(response.status).toBe(200);
  expect(response.rest.toString()).toBe("replacement");
  expect(response.headers.has("sec-websocket-accept")).toBe(false);
  await waitForLog("cleanup:/replace");
  expect(server.log()).not.toContain("open:/replace");
});

test("a hook that changes only the status keeps it and cancels the session", async () => {
  const response = head(await exchange(handshake({ path: "/forbid" })));
  expect(response.status).toBe(403);
  for (const name of ["upgrade", "sec-websocket-accept", "x-bendo-stream-internal"])
    expect(response.names).not.toContain(name);
  expect(response.headers.get("connection")).not.toBe("Upgrade");
  await waitForLog("cleanup:/forbid");
  expect(server.log()).not.toContain("open:/forbid");
});

test("a duplicate registration answers 500 and releases both sessions", async () => {
  const response = head(await exchange(handshake({ path: "/duplicate" })));
  expect(response.status).toBe(500);
  await waitForLog("cleanup:first");
  await waitForLog("cleanup:second");
  expect(count("cleanup:first")).toBe(1);
  expect(count("cleanup:second")).toBe(1);
  expect(server.log()).not.toContain("open:first");
});

test("a registration after handling has finished is released", async () => {
  const response = head(await exchange(handshake({ path: "/late" })));
  expect(response.status).toBe(504);
  await waitForLog("cleanup:late");
  expect(server.log()).not.toContain("open:late");
});

test("the wire method is re-checked after a rewrite, keeping finalized fields", async () => {
  const response = head(
    await exchange(
      handshake({
        path: "/policy/ws",
        method: "POST",
        fields: { "x-rewrite-get": "1", origin: "https://app.example" },
      }),
    ),
  );
  expect(response.status).toBe(400);
  expect(response.rest.toString()).toBe("Bad Request");
  expect(response.headers.get("x-content-type-options")).toBe("nosniff");
  expect(response.headers.get("access-control-allow-origin")).toBe("https://app.example");
  expect(response.headers.get("x-request-id")).toMatch(/^[0-9a-f]{32}$/);
  expect(response.headers.get("content-length")).toBe("11");
  expect(response.headers.get("date")).toMatch(/ GMT$/);
  for (const name of ["upgrade", "sec-websocket-accept", "x-bendo-stream-internal"])
    expect(response.names).not.toContain(name);
  await waitForLog("cleanup:/policy/ws");
});

// BND-94: the refusal is dated before the access log records it, so a clock
// failure's 500 is the status logged, and it keeps the refusal's fields.
test.skipIf(process.platform !== "linux")(
  "a clock failure after a wire refusal sends and logs one finalized 500",
  async () => {
    const failing = await startLogged({ LD_PRELOAD: clockShim });
    try {
      const id = "clock-refusal";
      const response = head(
        await exchange(
          handshake({
            path: "/policy/ws",
            method: "POST",
            fields: { "x-rewrite-get": "1", origin: "https://app.example", "x-request-id": id },
          }),
          failing,
        ),
      );
      expect(response.status).toBe(500);
      expect(response.rest.length).toBe(0);
      expect(response.headers.get("content-length")).toBe("0");
      expect(response.headers.get("x-content-type-options")).toBe("nosniff");
      expect(response.headers.get("access-control-allow-origin")).toBe("https://app.example");
      expect(response.headers.get("x-request-id")).toBe(id);
      expect(response.headers.has("server-timing")).toBe(true);
      for (const name of [
        "date",
        "content-type",
        "upgrade",
        "sec-websocket-accept",
        "x-bendo-stream-internal",
      ])
        expect(response.names).not.toContain(name);
      const deadline = Date.now() + 3000;
      const entries = () =>
        failing
          .accessLog()
          .split("\n")
          .filter((entry) => entry.includes(`id=${id}`));
      while (Date.now() < deadline && entries().length < 2) await Bun.sleep(20);
      expect(entries()).toHaveLength(2);
      for (const entry of entries()) expect(entry.split(" ")[2]).toBe("500");
      await waitForLog("cleanup:/policy/ws", 3000, failing.log);
    } finally {
      await failing.stop();
    }
  },
);

test("method override cannot turn a POST into an upgrade", async () => {
  const override = head(
    await exchange(
      handshake({ path: "/override", method: "POST", fields: { "x-http-method-override": "GET" } }),
    ),
  );
  expect(override.status).toBe(400);
  const put = head(
    await exchange(
      handshake({ path: "/override", method: "POST", fields: { "x-http-method-override": "PUT" } }),
    ),
  );
  expect(put.status).toBe(400);
  expect(put.headers.has("sec-websocket-accept")).toBe(false);
  expect(server.log()).not.toContain("open:/override");
});

test("the server keeps serving after upgrades and refusals", async () => {
  const response = await fetch(`${server.url}/ws`);
  expect(response.status).toBe(400);
  expect(await response.text()).toBe("Bad Request");
});

for (const method of ["GET", "POST"]) {
  test(`access log status matches the wire for ${method} upgrade`, async () => {
    const id = `logged-${method}`;
    const wire = await open(
      handshake({ method, fields: { "x-rewrite-get": "1", "x-request-id": id } }),
    );
    const response = head(await wire.waitFor(hasHead));
    wire.socket.destroy();
    expect(response.status).toBe(method === "GET" ? 101 : 400);
    const log = await waitForLog(`id=${id}`, 3000, server.accessLog);
    const line = log.split("\n").find((entry) => entry.includes(`id=${id}`));
    expect(line?.split(" ")[2]).toBe(String(response.status));
    const deadline = Date.now() + 3000;
    while (
      Date.now() < deadline &&
      server
        .accessLog()
        .split("\n")
        .filter((entry) => entry.includes(`id=${id}`)).length < 2
    )
      await Bun.sleep(20);
    const entries = server
      .accessLog()
      .split("\n")
      .filter((entry) => entry.includes(`id=${id}`));
    expect(entries).toHaveLength(2);
    for (const entry of entries) expect(entry.split(" ")[2]).toBe(String(response.status));
  });
}

test("cache middleware skips the informational upgrade response", async () => {
  const wire = await open(handshake({ path: "/cache" }));
  const response = head(await wire.waitFor(hasHead));
  wire.socket.destroy();
  expect(response.status).toBe(101);
  expect(response.headers.has("cache-control")).toBe(false);
});

test("websocket_origins_checked reports each dropped allow-list entry once at startup", async () => {
  const lines = server
    .accessLog()
    .split("\n")
    .filter((line) => line.startsWith("bendo: websocket:"));
  expect(lines).toEqual([
    'bendo: websocket: ignoring allowed origin "not an origin": not an http or https URL',
  ]);
});
