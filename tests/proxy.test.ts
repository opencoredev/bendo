import { afterAll, describe, expect, test } from "bun:test";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { connect, createServer, type Server, type Socket } from "node:net";
import { pathToFileURL } from "node:url";
import { build, compile, start, SLOW_TEST_TIMEOUT_MS } from "./harness.ts";

// Compilation stays at module scope, so the harness's compile budget applies.
const binary = build("tests/servers/proxy.bend");
const pureOutput = compile("tests/fixtures/proxy/pure.bend", "mjs");

const sha = (data: Uint8Array) => createHash("sha256").update(data).digest("hex");
// Deterministic octets, every value distinct from its neighbours.
const pattern = (size: number) => {
  const out = new Uint8Array(size);
  for (let i = 0; i < size; i++) out[i] = (i * 31 + (i >> 9)) % 251;
  return out;
};

// ---------------------------------------------------------------- Bun upstream

const bun = Bun.serve({
  hostname: "127.0.0.1",
  port: 0,
  async fetch(request) {
    const url = new URL(request.url);
    const status = /^\/status\/(\d{3})$/.exec(url.pathname);
    if (status) return new Response(`status ${status[1]}`, { status: Number(status[1]) });
    if (url.pathname === "/echo" || url.pathname === "/x/echo") {
      const body = new Uint8Array(await request.arrayBuffer());
      return Response.json({
        method: request.method,
        path: url.pathname,
        search: url.search,
        headers: [...request.headers.entries()],
        length: body.length,
        sha: sha(body),
      });
    }
    if (url.pathname === "/cookies") {
      const headers = new Headers({ "x-first": "1" });
      headers.append("set-cookie", "a=1");
      headers.append("set-cookie", "b=2");
      return new Response("cookies", { headers });
    }
    if (url.pathname === "/fixed") return new Response(pattern(Number(url.searchParams.get("n"))));
    if (url.pathname === "/chunked") {
      const total = Number(url.searchParams.get("n"));
      const data = pattern(total);
      let at = 0;
      // A ReadableStream without a length makes Bun send chunked encoding.
      return new Response(
        new ReadableStream({
          pull(controller) {
            if (at >= total) return controller.close();
            controller.enqueue(data.subarray(at, Math.min(total, at + 50_000)));
            at += 50_000;
          },
        }),
      );
    }
    return new Response("not found upstream", { status: 404 });
  },
});
afterAll(() => bun.stop(true));

// ---------------------------------------------------------------- scripted upstream

type Script = (socket: Socket, head: string) => void;
const closed = new Map<string, number>();
const seen = new Map<string, string>();

function waitClosed(path: string, timeoutMs = 5000): Promise<number> {
  const deadline = Date.now() + timeoutMs;
  return new Promise((resolve, reject) => {
    const poll = () => {
      const at = closed.get(path);
      if (at !== undefined) return resolve(at);
      if (Date.now() > deadline) return reject(new Error(`upstream socket for ${path} not closed`));
      setTimeout(poll, 20);
    };
    poll();
  });
}

const respond =
  (wire: string): Script =>
  (socket) =>
    socket.end(wire, "latin1");

const scripts = new Map<string, Script>([
  ["/cl-conflict", respond("HTTP/1.1 200 OK\r\nContent-Length: 3\r\nContent-Length: 4\r\n\r\nabc")],
  ["/cl-list", respond("HTTP/1.1 200 OK\r\nContent-Length: 3, 3\r\n\r\nabc")],
  ["/cl-bad", respond("HTTP/1.1 200 OK\r\nContent-Length: 3x\r\n\r\nabc")],
  [
    "/te-cl",
    respond(
      "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nContent-Length: 3\r\n\r\n3\r\nabc\r\n0\r\n\r\n",
    ),
  ],
  ["/te-gzip", respond("HTTP/1.1 200 OK\r\nTransfer-Encoding: gzip, chunked\r\n\r\n0\r\n\r\n")],
  ["/te-http10", respond("HTTP/1.0 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n0\r\n\r\n")],
  ["/bad-status", respond("HTTP/1.1 2000 OK\r\nContent-Length: 0\r\n\r\n")],
  ["/no-sp", respond("HTTP/1.1 200\r\nContent-Length: 0\r\n\r\n")],
  ["/empty-reason", respond("HTTP/1.1 200 \r\nContent-Length: 2\r\n\r\nok")],
  ["/lf-only", respond("HTTP/1.1 200 OK\nContent-Length: 0\n\n")],
  ["/obs-fold", respond("HTTP/1.1 200 OK\r\nX-A: 1\r\n continued\r\nContent-Length: 0\r\n\r\n")],
  ["/eof-head", respond("HTTP/1.1 200 OK\r\nContent-Le")],
  ["/switch", respond("HTTP/1.1 101 Switching Protocols\r\nUpgrade: x\r\n\r\n")],
  [
    "/interim",
    respond(
      "HTTP/1.1 100 Continue\r\n\r\nHTTP/1.1 103 Early Hints\r\nLink: </a>\r\n\r\nHTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok",
    ),
  ],
  ["/close-delimited", respond("HTTP/1.1 200 OK\r\nX-Kind: close\r\n\r\nall of this until EOF")],
  [
    "/chunked",
    respond(
      "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nTrailer: x-sum\r\n\r\n5;ext=1\r\nhello\r\n1\r\n \r\n5\r\nworld\r\n0\r\nx-sum: 1\r\n\r\nGARBAGE",
    ),
  ],
  ["/fixed-extra", respond("HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nhelloEXTRA")],
  ["/no-content", respond("HTTP/1.1 204 No Content\r\nContent-Length: 0\r\n\r\n")],
  [
    "/bad-chunk",
    respond("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nhello\r\nzz\r\n"),
  ],
  ["/truncated", respond("HTTP/1.1 200 OK\r\nContent-Length: 10\r\n\r\nhello")],
  [
    "/hop",
    respond(
      "HTTP/1.1 200 OK\r\nConnection: X-Secret, close\r\nconnection: x-other\r\nX-Secret: 1\r\nX-Other: 2\r\nKeep-Alive: timeout=5\r\nProxy-Connection: keep-alive\r\nProxy-Authenticate: Basic\r\nUpgrade: h2c\r\nTrailer: x-t\r\nX-Keep: yes\r\nSet-Cookie: a=1\r\nSet-Cookie: b=2\r\nContent-Length: 2\r\n\r\nok",
    ),
  ],
  ["/silent", () => undefined],
  [
    "/stall",
    (socket) =>
      socket.write("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n3\r\nabc\r\n", "latin1"),
  ],
  [
    "/coalesced",
    (socket) => {
      const body = Buffer.from(pattern(4096));
      socket.end(
        Buffer.concat([Buffer.from("HTTP/1.1 200 OK\r\nContent-Length: 4096\r\n\r\n"), body]),
      );
    },
  ],
  [
    "/echo-raw",
    (socket, head) =>
      socket.end(
        `HTTP/1.1 200 OK\r\nContent-Length: ${Buffer.byteLength(head, "latin1")}\r\n\r\n${head}`,
        "latin1",
      ),
  ],
  [
    "/drip",
    (socket) => {
      socket.write("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n", "latin1");
      const timer = setInterval(() => {
        if (socket.destroyed || !socket.writable) return clearInterval(timer);
        socket.write("2\r\nhi\r\n", "latin1");
      }, 50);
      socket.on("close", () => clearInterval(timer));
    },
  ],
]);

// Reads one request (head plus Content-Length body) and runs its script.
const open = new Set<Socket>();
const raw: Server = createServer((socket) => {
  open.add(socket);
  socket.on("close", () => open.delete(socket));
  let buffer = Buffer.alloc(0);
  let path = "";
  let started = false;
  socket.on("error", () => undefined);
  socket.on("close", () => {
    if (path) closed.set(path, Date.now());
  });
  socket.on("data", (part: Buffer) => {
    if (started) return;
    buffer = Buffer.concat([buffer, part]);
    const end = buffer.indexOf("\r\n\r\n");
    if (end < 0) return;
    const head = buffer.subarray(0, end + 4).toString("latin1");
    const length = /\r\ncontent-length: (\d+)\r\n/i.exec(head);
    if (buffer.length < end + 4 + (length ? Number(length[1]) : 0)) return;
    started = true;
    const target = head.split(" ")[1] ?? "/";
    path = target.split("?")[0] ?? target;
    closed.delete(path);
    seen.set(path, head);
    const script = scripts.get(path);
    if (script) script(socket, head);
    else socket.end("HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n");
  });
});
await new Promise<void>((resolve) => raw.listen(0, "127.0.0.1", resolve));
afterAll(
  () =>
    new Promise<void>((resolve) => {
      for (const socket of open) socket.destroy();
      raw.close(() => resolve());
    }),
);
const rawAddress = raw.address();
if (rawAddress === null || typeof rawAddress === "string") throw new Error("raw upstream address");

const server = await start(binary, "127.0.0.1", {
  BENDO_UPSTREAM: `http://127.0.0.1:${bun.port}`,
  BENDO_RAW_UPSTREAM: `http://127.0.0.1:${rawAddress.port}`,
});
afterAll(() => server[Symbol.asyncDispose]());
const port = Number(new URL(server.url).port);

// ---------------------------------------------------------------- client helpers

type Exchange = { wire: Buffer; ended: boolean };

// Sends raw bytes and collects the answer until the server closes or the
// quiet timeout passes.
function exchange(
  request: string | Buffer,
  quietMs = 3000,
  onHead?: (s: Socket) => void,
): Promise<Exchange> {
  return new Promise((resolve, reject) => {
    const socket = connect(port, "127.0.0.1");
    const parts: Buffer[] = [];
    let headSeen = false;
    socket.setTimeout(quietMs, () => {
      socket.destroy();
      resolve({ wire: Buffer.concat(parts), ended: false });
    });
    socket.on("connect", () => socket.write(request));
    socket.on("data", (part: Buffer) => {
      parts.push(part);
      if (!headSeen && Buffer.concat(parts).includes("\r\n\r\n")) {
        headSeen = true;
        onHead?.(socket);
      }
    });
    socket.on("end", () => {
      socket.destroy();
      resolve({ wire: Buffer.concat(parts), ended: true });
    });
    socket.on("close", () => resolve({ wire: Buffer.concat(parts), ended: true }));
    socket.on("error", reject);
  });
}

const get = (path: string, extra = "", method = "GET") =>
  `${method} ${path} HTTP/1.1\r\nHost: client.example\r\n${extra}Connection: close\r\n\r\n`;

type Parsed = { status: number; headers: [string, string][]; body: Buffer; terminated: boolean };

// Splits a response and decodes a chunked body, recording whether the last
// chunk arrived.
function parse(wire: Buffer): Parsed {
  const at = wire.indexOf("\r\n\r\n");
  if (at < 0) throw new Error(`missing head in ${JSON.stringify(wire.toString("latin1"))}`);
  const lines = wire.subarray(0, at).toString("latin1").split("\r\n");
  const status = Number(lines[0]?.split(" ")[1]);
  const headers: [string, string][] = lines.slice(1).map((line) => {
    const colon = line.indexOf(":");
    return [line.slice(0, colon).toLowerCase(), line.slice(colon + 1).trim()];
  });
  const rest = wire.subarray(at + 4);
  const chunked = headers.some(([n, v]) => n === "transfer-encoding" && v === "chunked");
  if (!chunked) return { status, headers, body: rest, terminated: true };
  const parts: Buffer[] = [];
  let i = 0;
  for (;;) {
    const eol = rest.indexOf("\r\n", i);
    if (eol < 0) return { status, headers, body: Buffer.concat(parts), terminated: false };
    const line = rest.subarray(i, eol).toString("latin1");
    if (!/^[0-9a-f]{1,8}$/.test(line))
      throw new Error(`malformed chunk size ${JSON.stringify(line)}`);
    const size = parseInt(line, 16);
    if (size === 0) return { status, headers, body: Buffer.concat(parts), terminated: true };
    if (rest.length < eol + 2 + size + 2)
      return {
        status,
        headers,
        body: Buffer.concat([...parts, rest.subarray(eol + 2)]),
        terminated: false,
      };
    if (rest.subarray(eol + 2 + size, eol + 4 + size).toString("latin1") !== "\r\n")
      throw new Error("missing CRLF after chunk payload");
    parts.push(rest.subarray(eol + 2, eol + 2 + size));
    i = eol + 2 + size + 2;
  }
}

const names = (p: Parsed) => p.headers.map(([n]) => n);
const values = (p: Parsed, name: string) => p.headers.filter(([n]) => n === name).map(([, v]) => v);

async function rawGet(
  path: string,
  extra = "",
  method = "GET",
): Promise<Parsed & { ended: boolean }> {
  const { wire, ended } = await exchange(get(path, extra, method));
  return { ...parse(wire), ended };
}

function upstreamHead(path: string): string {
  const head = seen.get(path);
  if (head === undefined) throw new Error(`upstream never saw ${path}`);
  return head;
}

// ---------------------------------------------------------------- Bun upstream tests

describe("forwarding to a Bun upstream", () => {
  test("status codes, bodies and repeated headers pass through", async () => {
    for (const code of [200, 404, 500]) {
      const res = await fetch(`${server.url}/status/${code}`);
      expect(res.status).toBe(code);
      expect(await res.text()).toBe(`status ${code}`);
    }
    const cookies = await fetch(`${server.url}/cookies`);
    expect(cookies.headers.getSetCookie()).toEqual(["a=1", "b=2"]);
    expect(cookies.headers.get("x-first")).toBe("1");
  });

  test("method, path, query, headers and body reach the upstream", async () => {
    const res = await fetch(`${server.url}/echo?a=1&b=%20x`, {
      method: "PUT",
      headers: { "x-custom": "v1", "content-type": "text/plain" },
      body: "hello",
    });
    expect(res.status).toBe(200);
    const echo: unknown = await res.json();
    expect(echo).toMatchObject({
      method: "PUT",
      path: "/echo",
      search: "?a=1&b=%20x",
      length: 5,
      sha: sha(new TextEncoder().encode("hello")),
    });
    if (
      typeof echo !== "object" ||
      echo === null ||
      !("headers" in echo) ||
      !Array.isArray(echo.headers)
    )
      throw new Error("echo");
    const headers = new Map<string, string>(echo.headers);
    expect(headers.get("x-custom")).toBe("v1");
    expect(headers.get("host")).toBe(`127.0.0.1:${bun.port}`);
    expect(headers.get("x-forwarded-for")).toBe("127.0.0.1");
    expect(headers.get("x-forwarded-proto")).toBe("http");
    expect(headers.get("x-forwarded-host")).toBe(`127.0.0.1:${port}`);
    expect(headers.get("content-length")).toBe("5");
  });

  test("a chunked upstream response streams back intact", async () => {
    const res = await fetch(`${server.url}/chunked?n=300000`);
    expect(res.status).toBe(200);
    expect(sha(new Uint8Array(await res.arrayBuffer()))).toBe(sha(pattern(300000)));
  });

  test(
    "1 MiB and 3 MiB uploads arrive intact under the configured body limit",
    async () => {
      for (const size of [1 << 20, 3 << 20]) {
        const body = pattern(size);
        const res = await fetch(`${server.url}/echo`, { method: "POST", body });
        expect(res.status).toBe(200);
        expect(await res.json()).toMatchObject({ length: size, sha: sha(body) });
      }
    },
    SLOW_TEST_TIMEOUT_MS,
  );

  test("an upload over the server body limit is refused with 413 before proxying", async () => {
    const { wire } = await exchange(
      `POST /echo HTTP/1.1\r\nHost: x\r\nContent-Length: ${5 << 20}\r\n\r\nabc`,
    );
    expect(parse(wire).status).toBe(413);
  });

  test(
    "1 MiB and 16 MiB downloads arrive intact; server memory does not grow with size",
    async () => {
      const hwm = () => {
        const line = readFileSync(`/proc/${server.pid}/status`, "utf8")
          .split("\n")
          .find((l) => l.startsWith("VmHWM:"));
        return Number(line?.split(/\s+/)[1] ?? NaN) * 1024;
      };
      const before = hwm();
      const small = await fetch(`${server.url}/fixed?n=${1 << 20}`);
      expect(sha(new Uint8Array(await small.arrayBuffer()))).toBe(sha(pattern(1 << 20)));
      const afterSmall = hwm();
      const big = await fetch(`${server.url}/chunked?n=${16 << 20}`);
      const reader = big.body?.getReader();
      if (reader === undefined) throw new Error("no body");
      const hash = createHash("sha256");
      for (;;) {
        const { done, value } = await reader.read();
        if (done) break;
        hash.update(value);
      }
      expect(hash.digest("hex")).toBe(sha(pattern(16 << 20)));
      const afterBig = hwm();
      const smallGrowth = Math.max(afterSmall - before, 8 << 20);
      // 16x the bytes; a buffered body would grow memory by about 16x too.
      expect(afterBig - before).toBeLessThan(smallGrowth * 4);
    },
    SLOW_TEST_TIMEOUT_MS,
  );
});

// ---------------------------------------------------------------- headers

describe("hop-by-hop fields", () => {
  test("request: hop-by-hop, Connection-listed, proxy credentials and framing are not forwarded", async () => {
    const res = await rawGet(
      "/raw/echo-raw",
      "CONNECTION: X-Listed, keep-alive\r\nconnection: X-Second, host\r\nX-Listed: 1\r\nx-second: 2\r\nKeep-Alive: 5\r\nTE: trailers\r\nUpgrade: websocket\r\nProxy-Connection: keep-alive\r\nTrailer: x\r\nProxy-Authorization: Basic x\r\nX-Forwarded-For: 6.6.6.6\r\nForwarded: for=6.6.6.6\r\nExpect: 100-continue\r\nX-Kept: yes\r\nAccept: a\r\nAccept: b\r\n",
    );
    expect(res.status).toBe(200);
    const head = upstreamHead("/echo-raw");
    const lines = head.split("\r\n");
    expect(lines[0]).toBe("GET /echo-raw HTTP/1.1");
    const fields = lines
      .slice(1)
      .filter((l) => l !== "")
      .map((l) => l.split(":")[0]?.toLowerCase());
    for (const gone of [
      "x-listed",
      "x-second",
      "keep-alive",
      "te",
      "upgrade",
      "proxy-connection",
      "trailer",
      "proxy-authorization",
      "forwarded",
      "expect",
      "transfer-encoding",
      "content-length",
    ])
      expect(fields).not.toContain(gone);
    // Host was named in Connection, yet the regenerated Host stays.
    expect(head).toContain(`\r\nhost: 127.0.0.1:${rawAddress.port}\r\n`);
    expect(head).toContain("\r\nx-kept: yes\r\naccept: a\r\naccept: b\r\n");
    expect(head).toContain("\r\nx-forwarded-for: 127.0.0.1\r\n");
    expect(head.endsWith("connection: close\r\n\r\n")).toBe(true);
    expect(fields.filter((f) => f === "connection")).toHaveLength(1);
  });

  test("request framing is recomputed: chunked in, content-length out", async () => {
    const { wire } = await exchange(
      "POST /raw/echo-raw HTTP/1.1\r\nHost: x\r\nTransfer-Encoding: chunked\r\nConnection: close\r\n\r\n3\r\nabc\r\n0\r\n\r\n",
    );
    expect(parse(wire).status).toBe(200);
    const head = upstreamHead("/echo-raw");
    expect(head).toContain("\r\ncontent-length: 3\r\n");
    expect(head.toLowerCase()).not.toContain("transfer-encoding");
  });

  test("response: hop-by-hop and every Connection-listed field are removed, others kept in order", async () => {
    const res = await rawGet("/raw/hop");
    expect(res.status).toBe(200);
    expect(res.body.toString()).toBe("ok");
    const n = names(res);
    for (const gone of [
      "x-secret",
      "x-other",
      "keep-alive",
      "proxy-connection",
      "proxy-authenticate",
      "upgrade",
      "trailer",
      "content-length",
    ])
      expect(n).not.toContain(gone);
    expect(values(res, "set-cookie")).toEqual(["a=1", "b=2"]);
    expect(n.indexOf("x-keep")).toBeLessThan(n.indexOf("set-cookie"));
  });

  test("preserve_host keeps the client's Host; rewrite maps the path", async () => {
    const res = await fetch(`${server.url}/preserve/echo?q=1`, {
      headers: { host: "front.example" },
    });
    const echo: unknown = await res.json();
    expect(echo).toMatchObject({ path: "/echo", search: "?q=1" });
    if (
      typeof echo !== "object" ||
      echo === null ||
      !("headers" in echo) ||
      !Array.isArray(echo.headers)
    )
      throw new Error("echo");
    expect(new Map<string, string>(echo.headers).get("host")).toBe("front.example");
  });

  test("trusted chains are appended; Forwarded quotes the host", async () => {
    await rawGet(
      "/raw/echo-raw",
      "X-Forwarded-For: 10.1.1.1\r\nX-Forwarded-Proto: https\r\nX-Forwarded-Host: edge\r\nForwarded: for=10.1.1.1\r\n",
    );
    const untrusted = upstreamHead("/echo-raw");
    expect(untrusted).toContain("\r\nx-forwarded-for: 127.0.0.1\r\n");
    expect(untrusted).not.toContain("10.1.1.1");
    expect(untrusted).not.toContain("forwarded:");
    const res = await fetch(`${server.url}/trust/echo`, {
      headers: {
        "x-forwarded-for": "10.1.1.1",
        "x-forwarded-proto": "https",
        "x-forwarded-host": "edge",
        forwarded: "for=10.1.1.1",
        host: 'we"ird',
      },
    });
    const echo: unknown = await res.json();
    if (
      typeof echo !== "object" ||
      echo === null ||
      !("headers" in echo) ||
      !Array.isArray(echo.headers)
    )
      throw new Error("echo");
    const h = new Map<string, string>(echo.headers);
    expect(h.get("x-forwarded-for")).toBe("10.1.1.1, 127.0.0.1");
    expect(h.get("x-forwarded-proto")).toBe("https, http");
    expect(h.get("x-forwarded-host")).toBe('edge, we"ird');
    expect(h.get("forwarded")).toBe('for=10.1.1.1, for=127.0.0.1;host="we\\"ird";proto=http');
  });
});

// ---------------------------------------------------------------- upstream framing

describe("upstream response framing", () => {
  for (const path of [
    "/cl-conflict",
    "/cl-bad",
    "/te-cl",
    "/te-gzip",
    "/te-http10",
    "/bad-status",
    "/no-sp",
    "/lf-only",
    "/obs-fold",
    "/eof-head",
    "/switch",
  ])
    test(`${path} is a 502 and the upstream socket is closed`, async () => {
      const res = await rawGet(`/raw${path}`);
      expect(res.status).toBe(502);
      expect(res.body.toString()).toBe("Bad Gateway: invalid upstream response");
      await waitClosed(path);
    });

  test("identical Content-Length list, empty reason, interim responses and extra bytes", async () => {
    expect((await rawGet("/raw/cl-list")).body.toString()).toBe("abc");
    expect((await rawGet("/raw/empty-reason")).body.toString()).toBe("ok");
    const interim = await rawGet("/raw/interim");
    expect(interim.status).toBe(200);
    expect(interim.body.toString()).toBe("ok");
    expect(names(interim)).not.toContain("link");
    const extra = await rawGet("/raw/fixed-extra");
    expect(extra.body.toString()).toBe("hello");
    expect(extra.terminated).toBe(true);
  });

  test("close-delimited and chunked upstream bodies complete; trailers are dropped", async () => {
    const close = await rawGet("/raw/close-delimited");
    expect(close.body.toString()).toBe("all of this until EOF");
    expect(close.terminated).toBe(true);
    const chunked = await rawGet("/raw/chunked");
    expect(chunked.body.toString()).toBe("hello world");
    expect(chunked.terminated).toBe(true);
  });

  test("204 from upstream has no body", async () => {
    const res = await rawGet("/raw/no-content");
    expect(res.status).toBe(204);
    expect(res.body.length).toBe(0);
  });

  for (const path of ["/bad-chunk", "/truncated"])
    test(`${path} after the head aborts the client stream without a last chunk`, async () => {
      const res = await rawGet(`/raw${path}`);
      expect(res.status).toBe(200);
      expect(res.terminated).toBe(false);
      expect(res.ended).toBe(true);
      // Octets already decoded may arrive before the abort; nothing else does.
      expect("hello".startsWith(res.body.toString())).toBe(true);
      await waitClosed(path);
    });

  test("a coalesced head and 4 KiB body respect a 1 KiB chunk limit", async () => {
    const res = await rawGet("/small/coalesced");
    expect(res.status).toBe(200);
    expect(res.terminated).toBe(true);
    expect(sha(res.body)).toBe(sha(pattern(4096)));
  });
});

// ---------------------------------------------------------------- failures and cleanup

describe("failures and cleanup", () => {
  test("connection refused is a 502", async () => {
    const res = await fetch(`${server.url}/refused`);
    expect(res.status).toBe(502);
    expect(await res.text()).toBe("Bad Gateway: upstream connection failed");
  });

  test("an unreachable upstream times out with 504 within the connect budget", async () => {
    const started = Date.now();
    const res = await fetch(`${server.url}/blackhole`);
    expect(res.status).toBe(504);
    expect(await res.text()).toBe("Gateway Timeout: upstream did not answer in time");
    expect(Date.now() - started).toBeLessThan(3000);
  });

  test("a silent upstream is a 504 after the head budget and its socket is closed", async () => {
    const res = await rawGet("/slow/silent");
    expect(res.status).toBe(504);
    await waitClosed("/silent");
  });

  test("a stalled body aborts after the read budget and closes the upstream", async () => {
    const res = await rawGet("/slow/stall");
    expect(res.status).toBe(200);
    expect(res.body.toString()).toBe("abc");
    expect(res.terminated).toBe(false);
    await waitClosed("/stall");
  });

  test("unsupported upstream URLs and invalid rewrites are 500s", async () => {
    expect((await fetch(`${server.url}/misconfigured`)).status).toBe(500);
    expect((await fetch(`${server.url}/bad/x`)).status).toBe(500);
  });

  test("a client that disconnects mid-stream closes the upstream socket", async () => {
    await exchange(get("/raw/drip"), 3000, (socket) => setTimeout(() => socket.destroy(), 100));
    await waitClosed("/drip");
  });

  test("middleware replacing the response cancels the stream and closes the upstream", async () => {
    const res = await rawGet("/replaced/drip");
    expect(res.status).toBe(200);
    expect(res.body.toString()).toBe("replacement");
    await waitClosed("/drip");
  });

  test("HEAD suppresses the body and closes the upstream", async () => {
    const res = await rawGet("/raw/drip", "", "HEAD");
    expect(res.status).toBe(200);
    expect(res.body.length).toBe(0);
    await waitClosed("/drip");
  });

  test("the server keeps serving after every failure", async () => {
    const res = await fetch(`${server.url}/status/200`);
    expect(res.status).toBe(200);
  });
});

// ---------------------------------------------------------------- pure helpers

const loaded: unknown = await import(pathToFileURL(pureOutput).href);
if (typeof loaded !== "object" || loaded === null || !("default" in loaded))
  throw new Error("missing module");
const api: unknown = loaded.default;
function pure(name: string, ...args: unknown[]): unknown {
  if (typeof api !== "object" || api === null || !(name in api)) throw new Error(`missing ${name}`);
  const fn: unknown = Reflect.get(api, name);
  if (typeof fn !== "function") throw new Error(`invalid ${name}`);
  return fn(...args);
}

describe("upstream URLs", () => {
  test("only http with a numeric IPv4 host or localhost is accepted", () => {
    expect(pure("parse_url", "http://127.0.0.1:3000")).toMatchObject({
      $: "Some",
      value: { host: "127.0.0.1", port: 3000, base: "" },
    });
    expect(pure("parse_url", "HTTP://localhost/api/")).toMatchObject({
      $: "Some",
      value: { host: "127.0.0.1", port: 80, base: "/api" },
    });
    for (const bad of [
      "https://1.2.3.4",
      "http://user@1.2.3.4",
      "http://example.com",
      "http://1.2.3.4:0",
      "http://1.2.3.4:65536",
      "http://[::1]:80",
      "http://1.2.3.4/x?y",
      "http://1.2.3.4/#f",
      "http://01.2.3.4",
      "http://1.2.3.4/a b",
      "http://1.2.3.4/a\r\nx",
      "http://",
      "1.2.3.4",
    ])
      expect(pure("parse_url", bad)).toEqual({ $: "None" });
  });

  test("rewritten targets must stay valid origin-form paths", () => {
    expect(pure("target", "/api/x", "", "/api", "/v2", { $: "Some", value: "a=1" })).toEqual({
      $: "Some",
      value: "/v2/x?a=1",
    });
    expect(pure("target", "/x", "/base", "", "", { $: "None" })).toEqual({
      $: "Some",
      value: "/base/x",
    });
    expect(pure("target", "*", "/base", "", "", { $: "None" })).toEqual({ $: "Some", value: "*" });
    for (const to of ["nope", "/a\r\nx", "/a b", '/a"'])
      expect(pure("target", "/api/x", "", "/api", to, { $: "None" })).toEqual({ $: "None" });
  });
});

describe("hop-by-hop filter", () => {
  type Octets = { $: "Nil" } | { $: "Con"; head: number; tail: Octets };
  type Header = { $: "Header"; name: string; value: Octets };
  type Headers = { $: "Nil" } | { $: "Con"; head: Header; tail: Headers };
  const octets = (raw: string): Octets => {
    let out: Octets = { $: "Nil" };
    for (let i = raw.length - 1; i >= 0; i--)
      out = { $: "Con", head: raw.charCodeAt(i), tail: out };
    return out;
  };
  const list = (pairs: [string, string][]): Headers => {
    let out: Headers = { $: "Nil" };
    for (let i = pairs.length - 1; i >= 0; i--) {
      const pair = pairs[i];
      if (pair === undefined) continue;
      out = { $: "Con", head: { $: "Header", name: pair[0], value: octets(pair[1]) }, tail: out };
    }
    return out;
  };
  test("empty Connection elements name no field", () => {
    expect(
      pure(
        "forward",
        list([
          ["connection", ""],
          ["", "x"],
        ]),
      ),
    ).toEqual(list([["", "x"]]));
    expect(
      pure(
        "forward",
        list([
          ["Connection", " , X-A ,,"],
          ["x-a", "1"],
          ["x-b", "2"],
        ]),
      ),
    ).toEqual(list([["x-b", "2"]]));
  });
});
