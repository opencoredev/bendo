import { afterAll, beforeAll, expect, test } from "bun:test";
import { connect, type Socket } from "node:net";
import { build, start, type RunningServer } from "./harness.ts";

const binary = build("tests/servers/ws-session.bend");
let server: RunningServer;
beforeAll(async () => {
  server = await start(binary);
});
afterAll(async () => server?.[Symbol.asyncDispose]());

async function until(check: () => boolean, ms = 5000): Promise<void> {
  const deadline = Date.now() + ms;
  while (!check()) {
    if (Date.now() >= deadline) throw new Error("WebSocket observation timed out");
    await Bun.sleep(5);
  }
}

function frame(opcode: number, payload: Buffer = Buffer.alloc(0), fin = true): Buffer {
  const key = Buffer.from([0x37, 0xfa, 0x21, 0x3d]);
  let head: Buffer;
  if (payload.length < 126) head = Buffer.from([(fin ? 128 : 0) | opcode, 128 | payload.length]);
  else if (payload.length <= 65535) {
    head = Buffer.alloc(4);
    head[0] = (fin ? 128 : 0) | opcode;
    head[1] = 254;
    head.writeUInt16BE(payload.length, 2);
  } else {
    head = Buffer.alloc(10);
    head[0] = (fin ? 128 : 0) | opcode;
    head[1] = 255;
    head.writeBigUInt64BE(BigInt(payload.length), 2);
  }
  const masked = Buffer.from(payload);
  for (let i = 0; i < masked.length; i++) masked[i] = (masked[i] ?? 0) ^ (key[i % 4] ?? 0);
  return Buffer.concat([head, key, masked]);
}

function closePayload(code: number, reason = ""): Buffer {
  const result = Buffer.alloc(2 + Buffer.byteLength(reason));
  result.writeUInt16BE(code);
  result.write(reason, 2);
  return result;
}

type WireFrame = { opcode: number; payload: Buffer };
type Parsed = { kind: "need" } | { kind: "got"; frame: WireFrame; used: number };
function parse(bytes: Buffer): Parsed {
  if (bytes.length < 2) return { kind: "need" };
  const first = bytes[0];
  const second = bytes[1];
  if (first === undefined || second === undefined) return { kind: "need" };
  expect(second & 128).toBe(0);
  let length = second & 127;
  let offset = 2;
  if (length === 126) {
    if (bytes.length < 4) return { kind: "need" };
    length = bytes.readUInt16BE(2);
    offset = 4;
  } else if (length === 127) {
    if (bytes.length < 10) return { kind: "need" };
    length = Number(bytes.readBigUInt64BE(2));
    offset = 10;
  }
  if (bytes.length < offset + length) return { kind: "need" };
  return {
    kind: "got",
    frame: { opcode: first & 15, payload: bytes.subarray(offset, offset + length) },
    used: offset + length,
  };
}

class Wire {
  bytes: Buffer = Buffer.alloc(0);
  ended = false;
  constructor(readonly socket: Socket) {
    socket.on("data", (chunk: Buffer) => {
      this.bytes = Buffer.concat([this.bytes, chunk]);
    });
    socket.on("close", () => {
      this.ended = true;
    });
    socket.on("error", () => {
      this.ended = true;
    });
  }
  async next(): Promise<WireFrame> {
    await until(() => parse(this.bytes).kind === "got" || this.ended);
    const result = parse(this.bytes);
    if (result.kind === "need") throw new Error("socket ended before frame");
    this.bytes = this.bytes.subarray(result.used);
    return result.frame;
  }
  [Symbol.dispose](): void {
    this.socket.destroy();
  }
}

async function raw(path = "/ws", suffix: Buffer = Buffer.alloc(0)): Promise<Wire> {
  const url = new URL(server.url);
  const socket = connect(Number(url.port), url.hostname);
  const wire = new Wire(socket);
  await new Promise<void>((resolve, reject) => {
    socket.once("connect", resolve);
    socket.once("error", reject);
  });
  socket.write(
    Buffer.concat([
      Buffer.from(
        `GET ${path} HTTP/1.1\r\nHost: bendo\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n\r\n`,
      ),
      suffix,
    ]),
  );
  await until(() => wire.bytes.includes("\r\n\r\n") || wire.ended);
  const end = wire.bytes.indexOf("\r\n\r\n");
  expect(wire.bytes.subarray(0, end).toString()).toStartWith("HTTP/1.1 101");
  wire.bytes = wire.bytes.subarray(end + 4);
  return wire;
}

async function closedLog(expected: string): Promise<void> {
  let actual = "";
  const deadline = Date.now() + 5000;
  while (Date.now() < deadline) {
    actual = await (await fetch(`${server.url}/closed`)).text();
    if (actual === expected) return;
    await Bun.sleep(10);
  }
  expect(actual).toBe(expected);
}

test("real Bun WebSocket echoes text and binary and completes peer close", async () => {
  const ws = new WebSocket(server.url.replace("http:", "ws:") + "/ws");
  ws.binaryType = "arraybuffer";
  const messages: (string | ArrayBuffer)[] = [];
  ws.onmessage = (event) => {
    const data: unknown = event.data;
    if (typeof data === "string" || data instanceof ArrayBuffer) messages.push(data);
  };
  const closed = new Promise<CloseEvent>((resolve) => {
    ws.onclose = resolve;
  });
  try {
    await until(() => ws.readyState === WebSocket.OPEN);
    ws.send("hello λ");
    ws.send(new Uint8Array([0, 128, 255]));
    await until(() => messages.length === 2);
    expect(messages[0]).toBe("hello λ");
    const binary = messages[1];
    expect(binary instanceof ArrayBuffer).toBe(true);
    if (binary instanceof ArrayBuffer) expect([...new Uint8Array(binary)]).toEqual([0, 128, 255]);
    ws.close(1000, "client bye");
    const event = await closed;
    expect(event.code).toBe(1000);
    expect(event.reason).toBe("client bye");
    expect(event.wasClean).toBe(true);
    await closedLog("1000:client bye");
  } finally {
    ws.close();
  }
});

test("fragmented text, interleaved ping, suffix and pipelined frames", async () => {
  using wire = await raw("/ws", frame(1, Buffer.from([0xe2]), false));
  wire.socket.write(
    Buffer.concat([
      frame(9, Buffer.from([0, 255, 1])),
      frame(0, Buffer.from([0x82, 0xac])),
      frame(2, Buffer.from([3, 0, 255])),
    ]),
  );
  expect(await wire.next()).toEqual({ opcode: 10, payload: Buffer.from([0, 255, 1]) });
  expect(await wire.next()).toEqual({ opcode: 1, payload: Buffer.from("€") });
  expect(await wire.next()).toEqual({ opcode: 2, payload: Buffer.from([3, 0, 255]) });
});

test("a byte-at-a-time masked frame resumes across header and payload reads", async () => {
  using wire = await raw();
  for (const byte of frame(1, Buffer.from("incremental"))) {
    wire.socket.write(Buffer.from([byte]));
    await Bun.sleep(6);
  }
  expect(await wire.next()).toEqual({ opcode: 1, payload: Buffer.from("incremental") });
});

test("each ping receives one identical pong and unsolicited pong is ignored", async () => {
  using wire = await raw();
  wire.socket.write(
    Buffer.concat([
      frame(9),
      frame(9, Buffer.from("ping")),
      frame(10),
      frame(1, Buffer.from("barrier")),
    ]),
  );
  expect(await wire.next()).toEqual({ opcode: 10, payload: Buffer.alloc(0) });
  expect(await wire.next()).toEqual({ opcode: 10, payload: Buffer.from("ping") });
  expect(await wire.next()).toEqual({ opcode: 1, payload: Buffer.from("barrier") });
  expect(wire.bytes.length).toBe(0);
});

for (const payload of [Buffer.alloc(0), closePayload(1000, "bye €")]) {
  test(`peer close echoes its exact ${payload.length}-byte payload once`, async () => {
    using wire = await raw();
    wire.socket.write(Buffer.concat([frame(8, payload), frame(8, payload)]));
    expect(await wire.next()).toEqual({ opcode: 8, payload });
    await until(() => wire.ended);
    expect(wire.bytes.length).toBe(0);
    await closedLog(payload.length === 0 ? "1005:" : "1000:bye €");
  });
}

test("server close waits for peer acknowledgment and sends no later data", async () => {
  using wire = await raw();
  wire.socket.write(frame(1, Buffer.from("server-close")));
  expect(await wire.next()).toEqual({ opcode: 8, payload: closePayload(1000, "server bye") });
  expect(wire.ended).toBe(false);
  wire.socket.write(
    Buffer.concat([frame(1, Buffer.from("ignored")), frame(8, closePayload(1000, "ack"))]),
  );
  await until(() => wire.ended);
  expect(wire.bytes.length).toBe(0);
  await closedLog("1000:ack");
});

test("server close expires if the peer never acknowledges", async () => {
  using wire = await raw();
  wire.socket.write(frame(1, Buffer.from("server-close")));
  expect((await wire.next()).opcode).toBe(8);
  await until(() => wire.ended, 2000);
  await closedLog("1006:");
});

test("a ping during the local close handshake still gets its pong", async () => {
  using wire = await raw();
  wire.socket.write(frame(1, Buffer.from("server-close")));
  expect((await wire.next()).opcode).toBe(8);
  wire.socket.write(frame(9, Buffer.from("closing ping")));
  expect(await wire.next()).toEqual({ opcode: 10, payload: Buffer.from("closing ping") });
  wire.socket.write(frame(8, closePayload(1000)));
  await until(() => wire.ended);
  expect(wire.bytes.length).toBe(0);
});

test("close deadline shortens a sixty-second mailbox polling interval", async () => {
  using wire = await raw("/slow-poll");
  const began = Date.now();
  wire.socket.write(frame(1, Buffer.from("server-close")));
  expect((await wire.next()).opcode).toBe(8);
  await until(() => wire.ended, 2000);
  expect(Date.now() - began).toBeLessThan(2500);
});

test("bounded mailbox rejects overflow immediately inside open", async () => {
  using wire = await raw("/burst");
  expect(await wire.next()).toEqual({ opcode: 1, payload: Buffer.from("one") });
  await closedLog("yes:no");
  expect(wire.bytes.length).toBe(0);
});

const invalid: [string, Buffer, number, string][] = [
  ["unmasked client", Buffer.from([0x81, 0]), 1002, "/ws"],
  ["reserved opcode", frame(3), 1002, "/ws"],
  ["unexpected continuation", frame(0), 1002, "/ws"],
  ["invalid UTF-8", frame(1, Buffer.from([0xff])), 1007, "/ws"],
  ["invalid close reason", frame(8, Buffer.from([3, 232, 255])), 1007, "/ws"],
  ["reserved close code", frame(8, closePayload(1006)), 1002, "/ws"],
  ["over max", frame(2, Buffer.alloc(9)), 1009, "/small"],
  [
    "over max across fragments",
    Buffer.concat([frame(2, Buffer.alloc(5), false), frame(0, Buffer.alloc(4))]),
    1009,
    "/small",
  ],
];
for (const [name, bytes, code, path] of invalid) {
  test(`${name} closes with ${code}`, async () => {
    using wire = await raw(path);
    wire.socket.write(bytes);
    expect(await wire.next()).toEqual({ opcode: 8, payload: closePayload(code) });
    await until(() => wire.ended);
    await closedLog(`${code}:`);
  });
}

test("abrupt EOF calls close with 1006 and sends nothing", async () => {
  using wire = await raw();
  wire.socket.end();
  await until(() => wire.ended);
  expect(wire.bytes.length).toBe(0);
  await closedLog("1006:");
});

test("one MiB within max_message echoes intact", async () => {
  using wire = await raw();
  const payload = Buffer.alloc(1024 * 1024, 0x61);
  wire.socket.write(frame(2, payload));
  expect(await wire.next()).toEqual({ opcode: 2, payload });
}, 30000);

test("declared frame over one MiB is refused before its body arrives", async () => {
  using wire = await raw();
  const header = Buffer.from([0x82, 0xff, 0, 0, 0, 0, 0, 0x10, 0, 1]);
  wire.socket.write(header);
  expect(await wire.next()).toEqual({ opcode: 8, payload: closePayload(1009) });
});

test("another HTTP request can send through the connection mailbox", async () => {
  using wire = await raw();
  // open has published the shared handle before the session starts polling.
  expect(await (await fetch(`${server.url}/push`)).text()).toBe("sent");
  expect(await wire.next()).toEqual({ opcode: 1, payload: Buffer.from("from HTTP") });
  wire.socket.write(frame(8, closePayload(1000)));
  expect((await wire.next()).opcode).toBe(8);
  await until(() => wire.ended);
  expect(await (await fetch(`${server.url}/push`)).text()).toBe("rejected");
});

test("a close is admitted when the mailbox is full and follows what was queued", async () => {
  // /crowded fills its 4-command mailbox inside open, then closes with 1011.
  using wire = await raw("/crowded");
  for (let i = 0; i < 4; i++) {
    expect(await wire.next()).toEqual({ opcode: 1, payload: Buffer.from("m") });
  }
  expect(await wire.next()).toEqual({ opcode: 8, payload: closePayload(1011, "crowded") });
  // Sends after the close, and a second close, were refused.
  await closedLog("4:no:yes:no:no");
  wire.socket.write(frame(8, closePayload(1011, "crowded")));
  await until(() => wire.ended);
  expect(wire.bytes.length).toBe(0);
  await closedLog("1011:crowded");
});

test("two closes racing a draining mailbox write the first admitted one, once", async () => {
  // /race-close fills the stored connection's 4-command mailbox from two
  // computations at once, each ending with its own close, while the
  // connection drains every 1 ms. Each computation first spends a random
  // number of effects, so rounds differ in where the scheduler switches.
  const codes: Record<string, number> = { first: 4001, second: 4002 };
  const tally = { yesNo: 0, noYes: 0, both: 0 };
  for (let round = 0; round < 40; round++) {
    using wire = await raw("/race");
    // An echo proves open has stored this connection's handle.
    wire.socket.write(frame(1, Buffer.from("sync")));
    expect(await wire.next()).toEqual({ opcode: 1, payload: Buffer.from("sync") });
    const answer = await (await fetch(`${server.url}/race-close`)).text();
    let close: WireFrame | undefined;
    while (close === undefined) {
      const next = await wire.next();
      if (next.opcode === 8) close = next;
      else expect(next).toEqual({ opcode: 1, payload: Buffer.from("m") });
    }
    // Only the first close goes out, and nothing follows it.
    const code = close.payload.readUInt16BE(0);
    const reason = close.payload.subarray(2).toString();
    expect(codes[reason]).toBe(code);
    wire.socket.write(frame(8, close.payload));
    await until(() => wire.ended);
    expect(wire.bytes.length).toBe(0);
    await closedLog(`${code}:${reason}`);
    // A close admitted behind the mailbox's own close is ignored, so both
    // may say yes, but the written one always said yes.
    if (answer === "yes:yes") tally.both++;
    else if (answer === "yes:no") {
      tally.yesNo++;
      expect(reason).toBe("first");
    } else if (answer === "no:yes") {
      tally.noYes++;
      expect(reason).toBe("second");
    } else throw new Error(`unexpected answer ${answer}`);
  }
  console.log(`racing closes: ${JSON.stringify(tally)}`);
}, 60000);

test("a queued burst drains without one poll wait per command", async () => {
  // /many polls every 250 ms with backoff off. When each queued send waited
  // for a timed socket read, 100 sends took about 99 poll intervals.
  const pollMs = 250;
  using wire = await raw("/many");
  const began = performance.now();
  wire.socket.write(frame(1, Buffer.from("many")));
  for (let i = 0; i < 100; i++) {
    expect(await wire.next()).toEqual({ opcode: 1, payload: Buffer.from("m") });
  }
  expect((performance.now() - began) / pollMs).toBeLessThan(2);
});

test("disconnect discards commands still queued behind a saved handle", async () => {
  using wire = await raw("/fill");
  // The handler queues eight texts; the close is already buffered behind them.
  wire.socket.write(Buffer.concat([frame(1, Buffer.from("fill")), frame(8, closePayload(1000))]));
  let texts = 0;
  let next = await wire.next();
  while (next.opcode === 1) {
    texts++;
    next = await wire.next();
  }
  expect(next.opcode).toBe(8);
  expect(texts).toBeLessThan(8);
  await until(() => wire.ended);
  await closedLog("1000:");
  expect(await (await fetch(`${server.url}/pending`)).text()).toBe("0");
});

test("idle backoff still delivers a mailbox push within its cap", async () => {
  // /backoff starts at 5 ms and doubles toward 200 ms while nothing happens.
  using wire = await raw("/backoff");
  await Bun.sleep(1500);
  const began = performance.now();
  expect(await (await fetch(`${server.url}/push`)).text()).toBe("sent");
  expect(await wire.next()).toEqual({ opcode: 1, payload: Buffer.from("from HTTP") });
  expect(performance.now() - began).toBeLessThan(1000);
});

test("idle timeout initiates close and bounded teardown", async () => {
  using wire = await raw("/idle");
  expect(await wire.next()).toEqual({ opcode: 8, payload: closePayload(1001, "idle timeout") });
  await until(() => wire.ended);
});

test("optional keepalive emits server ping", async () => {
  using wire = await raw("/ping");
  expect(await wire.next()).toEqual({ opcode: 9, payload: Buffer.alloc(0) });
  wire.socket.write(frame(10));
  wire.socket.write(frame(1, Buffer.from("still live")));
  let next = await wire.next();
  while (next.opcode === 9) next = await wire.next();
  expect(next).toEqual({ opcode: 1, payload: Buffer.from("still live") });
});

test("frequent keepalive permits both mailbox sends and incoming messages", async () => {
  using wire = await raw("/fast-ping");
  expect(await (await fetch(`${server.url}/push`)).text()).toBe("sent");
  wire.socket.write(frame(1, Buffer.from("echo under keepalive")));
  const text: string[] = [];
  const deadline = Date.now() + 2000;
  while (text.length < 2 && Date.now() < deadline) {
    const next = await wire.next();
    if (next.opcode === 1) text.push(next.payload.toString());
    else expect(next.opcode).toBe(9);
  }
  expect(text).toEqual(["from HTTP", "echo under keepalive"]);
});

test("a stalled reader reaches the write deadline while HTTP stays available", async () => {
  {
    using barrier = await raw();
    barrier.socket.write(frame(8, closePayload(1000, "before slow reader")));
    expect((await barrier.next()).opcode).toBe(8);
    await until(() => barrier.ended);
    await closedLog("1000:before slow reader");
  }
  using wire = await raw();
  wire.socket.pause();
  const message = frame(2, Buffer.alloc(1024 * 1024, 0x61));
  // A finite application exchange, larger than the OS send buffer. Stop
  // reading replies so one sequential write must eventually hit its budget.
  for (let i = 0; i < 12; i++) wire.socket.write(message);
  await closedLog("1006:");
  expect(await (await fetch(server.url)).text()).toBe("ok");
});
