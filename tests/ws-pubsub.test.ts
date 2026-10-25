import { afterAll, beforeAll, expect, test } from "bun:test";
import { connect, type Socket } from "node:net";
import { build, start, type RunningServer } from "./harness.ts";

const binary = build("tests/servers/ws-pubsub.bend");
let server: RunningServer;
beforeAll(async () => {
  server = await start(binary);
});
afterAll(async () => server?.[Symbol.asyncDispose]());

async function until(check: () => boolean, ms = 5000): Promise<void> {
  const deadline = Date.now() + ms;
  while (!check()) {
    if (Date.now() >= deadline) throw new Error("WebSocket observation timed out");
    await Bun.sleep(2);
  }
}

const KEY = Buffer.from([0x37, 0xfa, 0x21, 0x3d]);

function frame(opcode: number, payload: Buffer = Buffer.alloc(0)): Buffer {
  if (payload.length >= 126) throw new Error("test frames stay under 126 bytes");
  const masked = Buffer.from(payload);
  for (let i = 0; i < masked.length; i++) masked[i] = (masked[i] ?? 0) ^ (KEY[i % 4] ?? 0);
  return Buffer.concat([Buffer.from([128 | opcode, 128 | payload.length]), KEY, masked]);
}

function closePayload(code: number): Buffer {
  const result = Buffer.alloc(2);
  result.writeUInt16BE(code);
  return result;
}

type WireFrame = { opcode: number; payload: Buffer };

// Server frames are unmasked; every frame the fixture sends is short.
class Wire {
  private bytes: Buffer = Buffer.alloc(0);
  readonly frames: WireFrame[] = [];
  readonly arrivals: number[] = [];
  private read = 0;
  ended = false;
  constructor(readonly socket: Socket) {
    socket.on("data", (chunk: Buffer) => {
      this.bytes = Buffer.concat([this.bytes, chunk]);
      this.drain();
    });
    socket.on("close", () => {
      this.ended = true;
    });
    socket.on("error", () => {
      this.ended = true;
    });
  }
  handshake = false;
  private drain(): void {
    if (!this.handshake) {
      const end = this.bytes.indexOf("\r\n\r\n");
      if (end < 0) return;
      expect(this.bytes.subarray(0, end).toString()).toStartWith("HTTP/1.1 101");
      this.bytes = this.bytes.subarray(end + 4);
      this.handshake = true;
    }
    for (;;) {
      const first = this.bytes[0];
      const second = this.bytes[1];
      if (first === undefined || second === undefined) return;
      let length = second & 127;
      let offset = 2;
      if (length === 126) {
        if (this.bytes.length < 4) return;
        length = this.bytes.readUInt16BE(2);
        offset = 4;
      }
      if (this.bytes.length < offset + length) return;
      this.frames.push({
        opcode: first & 15,
        payload: this.bytes.subarray(offset, offset + length),
      });
      this.arrivals.push(performance.now());
      this.bytes = this.bytes.subarray(offset + length);
    }
  }
  async next(ms = 5000): Promise<WireFrame> {
    await until(() => this.frames.length > this.read || this.ended, ms);
    const frame = this.frames[this.read];
    if (frame === undefined) throw new Error("socket ended before frame");
    this.read++;
    return frame;
  }
  async text(ms = 5000): Promise<string> {
    const next = await this.next(ms);
    expect(next.opcode).toBe(1);
    return next.payload.toString();
  }
  texts(): string[] {
    return this.frames.filter((f) => f.opcode === 1).map((f) => f.payload.toString());
  }
  send(text: string): void {
    this.socket.write(frame(1, Buffer.from(text)));
  }
  [Symbol.dispose](): void {
    this.socket.destroy();
  }
}

async function open(path: string): Promise<Wire> {
  const url = new URL(server.url);
  const socket = connect(Number(url.port), url.hostname);
  const wire = new Wire(socket);
  await new Promise<void>((resolve, reject) => {
    socket.once("connect", resolve);
    socket.once("error", reject);
  });
  socket.write(
    `GET ${path} HTTP/1.1\r\nHost: bendo\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n\r\n`,
  );
  return wire;
}

// Opens a connection and waits until the registry holds its subscription.
async function subscriber(path: string): Promise<Wire> {
  const wire = await open(path);
  expect(await wire.text()).toMatch(/^ready \d+ yes$/);
  return wire;
}

async function publish(topic: string, m: string, n = 1): Promise<string> {
  return (await fetch(`${server.url}/publish/${topic}?m=${m}&n=${n}`, { method: "POST" })).text();
}

async function get(path: string): Promise<string> {
  return (await fetch(`${server.url}${path}`)).text();
}

async function post(path: string): Promise<string> {
  return (await fetch(`${server.url}${path}`, { method: "POST" })).text();
}

async function eventually(path: string, expected: string, ms = 10000): Promise<void> {
  const deadline = Date.now() + ms;
  let actual = await get(path);
  while (actual !== expected && Date.now() < deadline) {
    await Bun.sleep(20);
    actual = await get(path);
  }
  expect(actual).toBe(expected);
}

function closeAll(wires: Wire[]): void {
  for (const wire of wires) wire.socket.destroy();
}

test("a publication reaches all 50 subscribers of its topic and no one else", async () => {
  const members = await Promise.all(Array.from({ length: 50 }, () => subscriber("/ws/a")));
  const idle = await Promise.all(Array.from({ length: 10 }, () => subscriber("/ws/none")));
  const elsewhere = await Promise.all(Array.from({ length: 10 }, () => subscriber("/ws/b")));
  try {
    expect(await get("/members/a")).toBe("50");
    expect(await get("/members/b")).toBe("10");
    expect(await publish("a", "hello")).toBe("50 0 0");
    await Promise.all(members.map(async (wire) => expect(await wire.text()).toBe("hello:1")));
    // Longer than the 100 ms idle backoff: nothing else is on its way.
    await Bun.sleep(400);
    for (const wire of members) expect(wire.texts()).toHaveLength(2);
    for (const wire of [...idle, ...elsewhere]) expect(wire.texts()).toHaveLength(1);
  } finally {
    closeAll([...members, ...idle, ...elsewhere]);
  }
}, 30000);

test("a socket publication skips its sender; a server publication does not", async () => {
  const wires = await Promise.all(Array.from({ length: 3 }, () => subscriber("/ws/c")));
  const [sender, ...rest] = wires;
  if (sender === undefined) throw new Error("no sender");
  try {
    sender.send("pub c from-socket");
    for (const wire of rest) expect(await wire.text()).toBe("from-socket");
    sender.send("all c to-all");
    for (const wire of wires) expect(await wire.text()).toBe("to-all");
    expect(await publish("c", "from-http")).toBe("3 0 0");
    for (const wire of wires) expect(await wire.text()).toBe("from-http:1");
    await Bun.sleep(300);
    expect(sender.texts().slice(1)).toEqual(["to-all", "from-http:1"]);
  } finally {
    closeAll(wires);
  }
}, 30000);

test("unsubscribe stops delivery and subscribing twice delivers once", async () => {
  using wire = await subscriber("/ws/d");
  using other = await subscriber("/ws/d");
  wire.send("unsub d");
  expect(await wire.text()).toBe("unsubscribed d yes");
  expect(await get("/members/d")).toBe("1");
  expect(await publish("d", "after")).toBe("1 0 0");
  expect(await other.text()).toBe("after:1");
  wire.send("sub d");
  expect(await wire.text()).toBe("subscribed d yes");
  wire.send("sub d");
  expect(await wire.text()).toBe("subscribed d yes");
  expect(await get("/members/d")).toBe("2");
  expect(await publish("d", "again")).toBe("2 0 0");
  expect(await wire.text()).toBe("again:1");
  expect(await other.text()).toBe("again:1");
  await Bun.sleep(300);
  expect(wire.texts()).toHaveLength(5);
}, 30000);

test("1,000 subscribe-and-disconnect cycles leave the registry empty", async () => {
  await eventually("/size", "0");
  const batch = 50;
  for (let round = 0; round < 1000 / batch; round++) {
    const wires = await Promise.all(Array.from({ length: batch }, () => subscriber("/ws/e")));
    if (round === 0) expect(await get("/members/e")).toBe(String(batch));
    // Half close cleanly; half drop the TCP connection (close code 1006).
    wires.forEach((wire, i) => {
      if (i % 2 === 0) wire.socket.write(frame(8, closePayload(1000)));
      else wire.socket.destroy();
    });
    await until(() =>
      wires.every((wire, i) => i % 2 === 1 || wire.frames.some((f) => f.opcode === 8)),
    );
    closeAll(wires);
  }
  await eventually("/size", "0");
  expect(await get("/members/e")).toBe("0");
  // Every close path also revoked its connection's ID and forgot its claim.
  await eventually("/connections", "0");
  await eventually("/claims", "0");
}, 60000);

test("a full mailbox drops that subscriber's copy without blocking anyone", async () => {
  using fast = await subscriber("/ws/f");
  // One mailbox slot, and a socket wait of a minute unless bytes arrive.
  using slow = await subscriber("/ws/f?mode=slow");
  await Bun.sleep(300);
  const began = performance.now();
  expect(await publish("f", "s", 20)).toBe("21 19 0");
  expect(performance.now() - began).toBeLessThan(2000);
  for (let i = 1; i <= 20; i++) expect(await fast.text()).toBe(`s:${i}`);
  await Bun.sleep(300);
  expect(slow.texts()).toHaveLength(1);
  // Bytes from the peer end the slow wait; only the one queued copy is left.
  slow.socket.write(frame(9));
  await until(() => slow.texts().length === 2 && slow.frames.some((f) => f.opcode === 10));
  expect(slow.texts()[1]).toBe("s:1");
  // Still subscribed and open: the next publication gets through.
  expect(await publish("f", "later")).toBe("2 0 0");
  slow.socket.write(frame(9));
  await until(() => slow.texts().length === 3);
  expect(slow.texts()[2]).toBe("later:1");
  expect(await fast.text()).toBe("later:1");
}, 30000);

test("each publisher's messages arrive in order at every subscriber", async () => {
  const wires = await Promise.all(Array.from({ length: 5 }, () => subscriber("/ws/g")));
  using sender = await subscriber("/ws/none");
  try {
    sender.send("sub g");
    expect(await sender.text()).toBe("subscribed g yes");
    const http = publish("g", "p", 40);
    for (let i = 1; i <= 20; i++) sender.send(`pub g q:${i}`);
    // Five subscribers plus the sender, which a server publication includes.
    expect(await http).toBe("240 0 0");
    await Promise.all(wires.map((wire) => until(() => wire.texts().length === 61)));
    for (const wire of wires) {
      const texts = wire.texts().slice(1);
      expect(texts.filter((t) => t.startsWith("p:"))).toEqual(
        Array.from({ length: 40 }, (_, i) => `p:${i + 1}`),
      );
      expect(texts.filter((t) => t.startsWith("q:"))).toEqual(
        Array.from({ length: 20 }, (_, i) => `q:${i + 1}`),
      );
    }
  } finally {
    closeAll(wires);
  }
}, 30000);

test("a Peer kept after its connection closed cannot subscribe again", async () => {
  const wire = await open("/keep");
  expect(await wire.text()).toMatch(/^ready \d+$/);
  // While the connection is open, the kept Peer subscribes as usual.
  expect(await post("/late/k")).toBe("yes");
  expect(await get("/members/k")).toBe("1");
  wire.socket.destroy();
  // The close cleanup drops the subscription and revokes the ID together.
  await eventually("/members/k", "0");
  expect(await post("/late/k")).toBe("no");
  expect(await get("/members/k")).toBe("0");
  expect(await publish("k", "late")).toBe("0 0 0");
}, 30000);

test("subscribes racing their connection's close never leave a registration", async () => {
  let accepted = 0;
  let refused = 0;
  for (let round = 0; round < 30; round++) {
    const wire = await open("/keep");
    expect(await wire.text()).toMatch(/^ready \d+$/);
    const before = Array.from({ length: 4 }, () => post("/late/race"));
    wire.socket.destroy();
    const after = Array.from({ length: 4 }, () => post("/late/race"));
    for (const answer of await Promise.all([...before, ...after])) {
      if (answer === "yes") accepted++;
      else if (answer === "no") refused++;
      else throw new Error(`unexpected answer ${answer}`);
    }
    await eventually("/members/race", "0");
    // Long after the close, the kept Peer is still refused.
    expect(await post("/late/race")).toBe("no");
  }
  console.log(`racing subscribes: ${accepted} accepted, ${refused} refused`);
  expect(accepted + refused).toBe(30 * 8);
  expect(await get("/members/race")).toBe("0");
}, 60000);

test("an oversized publication still prunes a closed subscriber and its claim", async () => {
  await eventually("/claims", "0");
  // `max_message` is 20 bytes for both subscribers.
  using small = await subscriber("/ws/o?mode=small");
  expect(await post("/ghost/o")).toBe("yes");
  expect(await get("/members/o")).toBe("2");
  // Each joined under its own token.
  expect(await get("/claims")).toBe("2");
  const big = "x".repeat(24);
  // The open subscriber refuses the copy; the closed one is gone and pruned.
  expect(await publish("o", big)).toBe("0 1 1");
  expect(await get("/members/o")).toBe("1");
  // The ghost never closes through the hub, so only the prune can forget its claim.
  expect(await get("/claims")).toBe("1");
  expect(await publish("o", big)).toBe("0 1 0");
  expect(await get("/members/o")).toBe("1");
  expect(await publish("o", "ok")).toBe("1 0 0");
  expect(await small.text()).toBe("ok:1");
}, 30000);

test("a subscriber whose close shut its full mailbox is gone for any size", async () => {
  await eventually("/claims", "0");
  using small = await subscriber("/ws/s?mode=small");
  // The shut subscriber queued one command, then its close found the
  // mailbox full and shut it.
  expect(await post("/shut/s")).toBe("yes:yes:yes");
  expect(await get("/members/s")).toBe("2");
  expect(await get("/claims")).toBe("2");
  // Too big for both: the open one drops it, the shut one is gone and pruned.
  expect(await publish("s", "x".repeat(24))).toBe("0 1 1");
  expect(await get("/members/s")).toBe("1");
  expect(await get("/claims")).toBe("1");
  expect(await publish("s", "ok")).toBe("1 0 0");
  expect(await small.text()).toBe("ok:1");
}, 30000);

test("a join that times out after it is queued is still revoked on close", async () => {
  await eventually("/connections", "0");
  // /delayed's hub forwards each request 400 ms late and gives up after 100.
  const wire = await open("/delayed");
  // The session stopped waiting before the join committed, so it has no ID.
  expect(await wire.text()).toBe("ready 0 yes");
  // The join still committed.
  await eventually("/connections", "1");
  wire.socket.destroy();
  // The close revokes it by token.
  await eventually("/connections", "0");
  await eventually("/claims", "0");
}, 30000);

test("a close while the hub's queue stays full still releases its connection", async () => {
  await eventually("/connections", "0");
  await eventually("/claims", "0");
  // /jammed's hub reaches the same registry through a gate that can hold every
  // request, and gives up on an ordinary request after 100 ms.
  const wire = await open("/jammed");
  expect(await wire.text()).toMatch(/^ready [1-9]\d* yes$/);
  expect(await get("/connections")).toBe("1");
  expect(await get("/claims")).toBe("1");
  expect(await post("/jam/hold")).toBe("held");
  try {
    // The gate holds one request and the 128-slot queue behind it fills up.
    expect(Number(await post("/jam/fill"))).toBeGreaterThanOrEqual(128);
    wire.socket.destroy();
    // Ten times the 100 ms an ordinary request waits for room before it gives up.
    await Bun.sleep(1000);
    expect(await post("/jam/fill")).toBe("0");
    expect(await get("/connections")).toBe("1");
  } finally {
    expect(await post("/jam/free")).toBe("free");
  }
  // The release waited for room instead of giving up, and lands once the queue drains.
  await eventually("/connections", "0");
  await eventually("/claims", "0");
}, 30000);

function median(values: number[]): number {
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.floor(sorted.length / 2)] ?? Number.NaN;
}

async function latency(wire: Wire, topic: string): Promise<number> {
  const before = wire.texts().length;
  const began = performance.now();
  expect(await publish(topic, "t")).toBe("1 0 0");
  await until(() => wire.texts().length > before);
  const index = wire.frames.findLastIndex((f) => f.opcode === 1);
  return (wire.arrivals[index] ?? Number.NaN) - began;
}

test("publish-to-receive latency for idle and active subscribers", async () => {
  using idle = await subscriber("/ws/h");
  const idleMs: number[] = [];
  for (let i = 0; i < 8; i++) {
    // Long enough for the wait to double from 10 ms to its 100 ms cap.
    await Bun.sleep(600 + i * 13);
    idleMs.push(await latency(idle, "h"));
  }
  using active = await subscriber("/ws/i");
  const activeMs: number[] = [];
  const pinger = setInterval(() => active.socket.write(frame(10)), 5);
  try {
    await Bun.sleep(100);
    for (let i = 0; i < 8; i++) {
      await Bun.sleep(17 + i * 7);
      activeMs.push(await latency(active, "i"));
    }
  } finally {
    clearInterval(pinger);
  }
  const fmt = (xs: number[]) => xs.map((x) => x.toFixed(1)).join(", ");
  console.log(`idle publish-to-receive ms: ${fmt(idleMs)} (median ${median(idleMs).toFixed(1)})`);
  console.log(
    `active publish-to-receive ms: ${fmt(activeMs)} (median ${median(activeMs).toFixed(1)})`,
  );
  // An idle wait never exceeds poll_max_ms; allow generous scheduling slack.
  expect(Math.max(...idleMs)).toBeLessThan(600);
  expect(median(activeMs)).toBeLessThan(median(idleMs));
}, 30000);
