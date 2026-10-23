import { afterAll, expect, test } from "bun:test";
import { connect } from "node:net";
import { pathToFileURL } from "node:url";
import { build, compile, start } from "./harness.ts";

const binary = build("tests/fixtures/http-connection/server.bend");
const standard = await start(binary);
async function configured(mode: string) {
  const prior = process.env.CONNECTION_MODE;
  process.env.CONNECTION_MODE = mode;
  try {
    return await start(binary);
  } finally {
    if (prior === undefined) delete process.env.CONNECTION_MODE;
    else process.env.CONNECTION_MODE = prior;
  }
}
const short = await configured("short");
const disabled = await configured("disabled");
const zero = await configured("zero");
const legacy = await start(build("tests/fixtures/http-connection/legacy.bend"));
afterAll(async () => {
  await Promise.all([standard, short, disabled, zero, legacy].map((s) => s[Symbol.asyncDispose]()));
});

const request = (path: string, headers = "", method = "GET", version = "1.1") =>
  `${method} ${path} HTTP/${version}\r\nHost: x\r\n${headers}\r\n`;

class Peer {
  readonly socket;
  data = Buffer.alloc(0);
  ended = false;
  error: Error | undefined;
  wake: (() => void) | undefined;
  constructor(url = standard.url) {
    this.socket = connect(Number(new URL(url).port), "127.0.0.1");
    this.socket.setNoDelay(true);
    this.socket.setTimeout(5000, () => this.socket.destroy(new Error("socket timeout")));
    this.socket.on("data", (bytes: Buffer) => {
      this.data = Buffer.concat([this.data, bytes]);
      this.wake?.();
    });
    this.socket.on("end", () => {
      this.ended = true;
      this.wake?.();
    });
    this.socket.on("error", (error: Error) => {
      this.error = error;
      this.wake?.();
    });
  }
  async changed() {
    if (this.error) throw this.error;
    await new Promise<void>((resolve) => {
      this.wake = resolve;
    });
    this.wake = undefined;
    if (this.error) throw this.error;
  }
  async response(head = false) {
    while (this.data.indexOf("\r\n\r\n") < 0) {
      if (this.ended) throw new Error(`EOF before response: ${this.data}`);
      await this.changed();
    }
    const end = this.data.indexOf("\r\n\r\n");
    const lines = this.data.subarray(0, end).toString("latin1");
    const status = Number(lines.split(" ")[1]);
    const headers = new Headers();
    for (const line of lines.split("\r\n").slice(1)) {
      const colon = line.indexOf(":");
      if (colon < 1) throw new Error(`invalid header ${line}`);
      headers.append(line.slice(0, colon), line.slice(colon + 1).trim());
    }
    const length =
      head || status < 200 || status === 204 || status === 304
        ? 0
        : Number(headers.get("content-length"));
    if (!Number.isSafeInteger(length) || length < 0) throw new Error("invalid length");
    while (this.data.length < end + 4 + length) {
      if (this.ended) throw new Error("EOF during body");
      await this.changed();
    }
    const body = this.data.subarray(end + 4, end + 4 + length).toString("latin1");
    this.data = this.data.subarray(end + 4 + length);
    return { status, headers, body, rawHead: lines };
  }
  async eof() {
    while (!this.ended) await this.changed();
    expect(this.data.length).toBe(0);
  }
  [Symbol.dispose]() {
    this.socket.destroy();
  }
}

async function closed(wire: string, status: number, url = standard.url) {
  using peer = new Peer(url);
  peer.socket.write(wire);
  const result = await peer.response();
  expect(result.status).toBe(status);
  expect(result.headers.get("connection")).toBe("close");
  await peer.eof();
}

test("100 sequential requests on one connection; last advertises close", async () => {
  using peer = new Peer();
  for (let i = 0; i < 100; i++) {
    peer.socket.write(request(`/${i}`));
    const res = await peer.response();
    expect(res.status).toBe(200);
    expect(res.body).toBe(`/${i}`);
    expect(res.headers.get("connection")).toBe(i === 99 ? "close" : null);
  }
  await peer.eof();
});

test("three pipelined requests in one write arrive in order", async () => {
  using peer = new Peer();
  peer.socket.write(request("/one") + request("/two") + request("/three", "Connection: close\r\n"));
  for (const body of ["/one", "/two", "/three"]) expect((await peer.response()).body).toBe(body);
  await peer.eof();
});

test("request and half the next head retain every suffix byte", async () => {
  using peer = new Peer();
  const second = request("/second", "Connection: close\r\n");
  peer.socket.write(request("/first") + second.slice(0, 13));
  expect((await peer.response()).body).toBe("/first");
  peer.socket.write(second.slice(13));
  expect((await peer.response()).body).toBe("/second");
  await peer.eof();
});

test("fixed and chunked bodies retain following requests", async () => {
  using peer = new Peer();
  peer.socket.write(
    request("/fixed", "Content-Length: 3\r\n", "POST") +
      "abc" +
      request("/chunked", "Transfer-Encoding: chunked\r\n", "POST") +
      "2\r\nxy\r\n0\r\n\r\n" +
      request("/last", "Connection: close\r\n"),
  );
  for (const body of ["abc", "xy", "/last"]) expect((await peer.response()).body).toBe(body);
  await peer.eof();
});

test("idle connection closes silently after configured timeout", async () => {
  using peer = new Peer(short.url);
  const before = performance.now();
  await peer.eof();
  expect(performance.now() - before).toBeGreaterThanOrEqual(100);
  expect(performance.now() - before).toBeLessThan(2000);
});

test("idle deadline restarts after a successful request", async () => {
  using peer = new Peer(short.url);
  peer.socket.write(request("/ok"));
  expect((await peer.response()).status).toBe(200);
  await peer.eof();
});

test("64 KiB header value plus head gets 431", () =>
  closed(request("/", `X-Pad: ${"a".repeat(65536)}\r\n`), 431));
test("garbage request line gets 400", () => closed("garbage\r\n\r\n", 400));
test("leading CRLFs count toward configured header limit", () =>
  closed("\r\n".repeat(65) + request("/"), 431, short.url));
test("header limit accepts exactly the limit and rejects one more", async () => {
  const base = request("/", "Connection: close\r\nX-Pad: \r\n");
  await closed(
    request("/", `Connection: close\r\nX-Pad: ${"a".repeat(128 - Buffer.byteLength(base))}\r\n`),
    200,
    short.url,
  );
  await closed(
    request("/", `Connection: close\r\nX-Pad: ${"a".repeat(129 - Buffer.byteLength(base))}\r\n`),
    431,
    short.url,
  );
});
test("Connection close token across repeated case-insensitive fields stops pipeline", () =>
  closed(
    request("/", "Connection: keep-alive\r\nConnection: x, ClOsE\r\n") + request("/ignored"),
    200,
  ));
test("max requests advertises close and ignores extra pipeline request", async () => {
  using peer = new Peer(short.url);
  peer.socket.write(["/1", "/2", "/3", "/4"].map((p) => request(p)).join(""));
  for (let i = 1; i <= 3; i++) {
    const res = await peer.response();
    expect(res.body).toBe(`/${i}`);
    expect(res.headers.get("connection")).toBe(i === 3 ? "close" : null);
  }
  await peer.eof();
});
test("HTTP/1.0 closes even when keep-alive is requested", () =>
  closed(request("/", "Connection: keep-alive\r\n", "GET", "1.0") + request("/ignored"), 200));
test("keep_alive False closes", () =>
  closed(request("/") + request("/ignored"), 200, disabled.url));
test("response Connection close is honored and normalized", () =>
  closed(request("/close") + request("/ignored"), 200));
test("application 413 closes before later pipelined dispatch", () =>
  closed(request("/bad") + request("/ignored"), 413));
test("HEAD in a pipeline preserves length and has no body", async () => {
  using peer = new Peer();
  peer.socket.write(request("/head", "", "HEAD") + request("/get", "Connection: close\r\n"));
  const head = await peer.response(true);
  expect(head.status).toBe(200);
  expect(head.headers.get("content-length")).toBe("5");
  expect(head.body).toBe("");
  expect((await peer.response()).body).toBe("/get");
  await peer.eof();
});
test("413 mid-pipeline closes without answering following requests", async () => {
  using peer = new Peer();
  peer.socket.write(
    request("/ok") +
      request("/big", "Content-Length: 9\r\n", "POST") +
      "123456789" +
      request("/ignored"),
  );
  expect((await peer.response()).body).toBe("/ok");
  const error = await peer.response();
  expect(error.status).toBe(413);
  expect(error.headers.get("connection")).toBe("close");
  await peer.eof();
});
test("100 continue still permits later requests", async () => {
  using peer = new Peer();
  peer.socket.write(request("/body", "Content-Length: 3\r\nExpect: 100-continue\r\n", "POST"));
  expect((await peer.response()).status).toBe(100);
  peer.socket.write("abc" + request("/last", "Connection: close\r\n"));
  expect((await peer.response()).body).toBe("abc");
  expect((await peer.response()).body).toBe("/last");
  await peer.eof();
});
test("head deadline includes leading CRLF and does not restart per byte", async () => {
  using peer = new Peer(short.url);
  peer.socket.write("\r\n");
  for (let i = 0; i < 3; i++) {
    await Bun.sleep(100);
    peer.socket.write("\r\n");
  }
  const res = await peer.response();
  expect(res.status).toBe(408);
  expect(res.headers.get("connection")).toBe("close");
  await peer.eof();
});
test("body deadline does not restart when progress arrives", async () => {
  using peer = new Peer(short.url);
  peer.socket.write(request("/", "Content-Length: 8\r\n", "POST"));
  for (let i = 0; i < 3; i++) {
    await Bun.sleep(100);
    peer.socket.write("x");
  }
  expect((await peer.response()).status).toBe(408);
  await peer.eof();
});
test("one byte per 100ms does not block another client", async () => {
  using slow = new Peer();
  // Both sockets remain active while the fast client sends requests.
  let slowFinished = false;
  const sending = (async () => {
    for (const byte of "GET /") {
      slow.socket.write(byte);
      await Bun.sleep(100);
    }
    slowFinished = true;
  })();
  using fast = new Peer();
  const before = performance.now();
  for (let i = 0; i < 5; i++) {
    fast.socket.write(request(`/${i}`, i === 4 ? "Connection: close\r\n" : ""));
    expect((await fast.response()).body).toBe(`/${i}`);
  }
  expect(performance.now() - before).toBeLessThan(900);
  expect(slowFinished).toBe(false);
  await fast.eof();
  await sending;
  expect(slow.ended).toBe(false);
});
test("partial request EOF gets 400; clean idle EOF is silent", async () => {
  using peer = new Peer();
  peer.socket.end("GET / HTTP/1.1\r\n");
  expect((await peer.response()).status).toBe(400);
  await peer.eof();
  using idle = new Peer();
  idle.socket.end();
  await idle.eof();
});

test("101 closes until upgrade handoff is implemented", () =>
  closed(request("/upgrade") + request("/ignored"), 101));
test("417 in pipeline closes before next dispatch", () =>
  closed(request("/", "Expect: kittens\r\n") + request("/ignored"), 417));

const pureOutput = compile("tests/fixtures/http-connection/consumer.bend", "mjs");
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
type Octets = { $: "Nil" } | { $: "Con"; head: number; tail: Octets };
function octets(raw: string): Octets {
  let result: Octets = { $: "Nil" };
  for (let i = raw.length - 1; i >= 0; i--)
    result = { $: "Con", head: raw.charCodeAt(i), tail: result };
  return result;
}
test("pure state consumes each pipeline byte once across every split", () => {
  const suffix = request("/next");
  const wire = request("/body", "Content-Length: 3\r\n", "POST") + "abc";
  const expected = pure("action", pure("feed", octets(wire + suffix), pure("initial"), 10), 10);
  expect(expected).toMatchObject({
    $: "Respond",
    req: { path: "/body" },
    body: octets("abc"),
    rest: octets(suffix),
  });
  for (let i = 0; i < wire.length; i++) {
    const first = pure("feed", octets(wire.slice(0, i)), pure("initial"), 5);
    const second = pure("feed", octets(wire.slice(i) + suffix), first, 10);
    expect(pure("action", second, 10)).toEqual(expected);
  }
});
test("pure deadlines use absolute monotonic times for idle, head and body", () => {
  expect(pure("action", pure("initial"), 4999)).toEqual({ $: "Read", milliseconds: 1 });
  expect(pure("action", pure("initial"), 5000)).toEqual({ $: "Stop" });
  const head = pure("feed", octets("\r\n"), pure("initial"), 100);
  const progress = pure("feed", octets("G"), head, 9000);
  expect(pure("action", progress, 10099)).toEqual({ $: "Read", milliseconds: 1 });
  expect(pure("action", progress, 10100)).toEqual({ $: "Reject", status: 408 });
  const body = pure(
    "feed",
    octets(request("/", "Content-Length: 3\r\n", "POST")),
    pure("initial"),
    200,
  );
  const bodyProgress = pure("feed", octets("a"), body, 29000);
  expect(pure("action", bodyProgress, 30199)).toEqual({ $: "Read", milliseconds: 1 });
  expect(pure("action", bodyProgress, 30200)).toEqual({ $: "Reject", status: 408 });
});
test("buffered partial next head retains its original receive timestamp", () => {
  const complete = pure("feed", octets(request("/first") + "G"), pure("initial"), 100);
  const next = pure("next", complete, octets("G"), 9000);
  expect(pure("action", next, 10100)).toEqual({ $: "Reject", status: 408 });
});

test("max_requests zero closes after the first response", () =>
  closed(request("/first") + request("/ignored"), 200, zero.url));
test("legacy byte responses replace Connection fields and preserve binary framing", async () => {
  using peer = new Peer(legacy.url);
  peer.socket.write(request("/"));
  const res = await peer.response();
  const date = res.headers.get("date") ?? "";
  expect(Math.abs(Date.parse(date) - Date.now())).toBeLessThanOrEqual(2000);
  expect(res.rawHead).toBe(
    "HTTP/1.1 200 Custom\r\nX-Custom: untouched\r\nX-Dup: one\r\nX-Dup: two\r\nContent-Length: 7\r\nconnection: close\r\ndate: " +
      date,
  );
  expect(res.body).toBe("\x00\xff\r\n\r\n*");
  expect(res.headers.get("connection")).toBe("close");
  await peer.eof();
});
