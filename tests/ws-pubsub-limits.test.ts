// BND-105: real WebSocket clients drive a hub past each subscription limit:
// per connection, per hub and topic length in UTF-8 bytes. A refusal leaves
// the registry as it was, a repeat uses no slot, and a close frees slots.
import { afterAll, beforeAll, expect, test } from "bun:test";
import { build, start, type RunningServer } from "./harness.ts";

const binary = build("tests/servers/ws-pubsub-limits.bend");
let server: RunningServer;
beforeAll(async () => {
  server = await start(binary);
});
afterAll(async () => server?.[Symbol.asyncDispose]());

async function until(label: string, check: () => boolean | Promise<boolean>, ms = 10_000) {
  const deadline = Date.now() + ms;
  while (!(await check())) {
    if (Date.now() >= deadline) throw new Error(`timed out waiting until ${label}`);
    await Bun.sleep(5);
  }
}

class Client {
  private readonly received: string[] = [];
  private read = 0;
  closed = false;
  private constructor(private readonly socket: WebSocket) {
    socket.addEventListener("message", (event) => this.received.push(String(event.data)));
    socket.addEventListener("close", () => {
      this.closed = true;
    });
  }
  static async open(hub: "small" | "default"): Promise<Client> {
    const url = new URL(server.url);
    const client = new Client(new WebSocket(`ws://${url.host}/ws/${hub}`));
    expect(await client.next()).toStartWith("ready ");
    return client;
  }
  async next(): Promise<string> {
    await until("a message arrives", () => this.received.length > this.read || this.closed);
    const message = this.received[this.read];
    if (message === undefined) throw new Error("socket closed before a message");
    this.read++;
    return message;
  }
  /** Sends `sub <topic>` and returns the outcome the server reported. */
  async sub(topic: string): Promise<string> {
    this.socket.send(`sub ${topic}`);
    const reply = await this.next();
    const prefix = `sub ${topic} `;
    expect(reply.startsWith(prefix)).toBe(true);
    return reply.slice(prefix.length);
  }
  async unsub(topic: string): Promise<string> {
    this.socket.send(`unsub ${topic}`);
    return await this.next();
  }
  /** Sends every subscribe at once, then reads the outcomes in order. */
  async subAll(topics: string[]): Promise<string[]> {
    for (const topic of topics) this.socket.send(`sub ${topic}`);
    const outcomes: string[] = [];
    for (const topic of topics) {
      const reply = await this.next();
      expect(reply.startsWith(`sub ${topic} `)).toBe(true);
      outcomes.push(reply.slice(`sub ${topic} `.length));
    }
    return outcomes;
  }
  close(): void {
    this.socket.close();
  }
}

async function get(path: string, method = "GET"): Promise<string> {
  const response = await fetch(`${server.url}${path}`, { method });
  expect(response.status).toBe(200);
  return await response.text();
}
const size = (hub: string) => get(`/size/${hub}`);
const members = (hub: string, topic: string) => get(`/members/${hub}/${encodeURIComponent(topic)}`);

test("a hub refuses past each limit, keeps its registry, and frees slots on close", async () => {
  // The fixture's small hub: 3 per connection, 5 in all, 8-byte topics.
  const a = await Client.open("small");
  expect(await a.subAll(["a1", "a2", "a3"])).toEqual(["subscribed", "subscribed", "subscribed"]);
  expect(await a.sub("a4")).toBe("peer-limit");
  expect(await members("small", "a4")).toBe("0");
  // A repeat uses no slot and succeeds even at the limit.
  expect(await a.sub("a1")).toBe("subscribed");
  expect(await size("small")).toBe("3");
  // Leaving a topic frees its slot.
  expect(await a.unsub("a3")).toBe("unsub a3 yes");
  expect(await a.sub("a4")).toBe("subscribed");
  expect(await size("small")).toBe("3");

  // Topic length counts UTF-8 bytes, not characters: "é" is two.
  const b = await Client.open("small");
  expect(await b.sub("éééé")).toBe("subscribed");
  expect(await b.sub("ééééé")).toBe("topic-too-long");
  expect(await b.sub("123456789")).toBe("topic-too-long");
  expect(await size("small")).toBe("4");
  expect(await b.sub("b2")).toBe("subscribed");
  expect(await size("small")).toBe("5");

  // The hub is full: a third connection is refused before anything changes.
  const c = await Client.open("small");
  expect(await c.sub("c1")).toBe("hub-limit");
  expect(await size("small")).toBe("5");
  expect(await members("small", "c1")).toBe("0");
  expect(await get("/publish/small/c1", "POST")).toBe("0");

  // Closing a connection frees every slot it held.
  a.close();
  await until("the closed connection's slots are free", async () => (await size("small")) === "2");
  expect(await c.sub("c1")).toBe("subscribed");
  expect(await size("small")).toBe("3");
  b.close();
  c.close();
  await until("the small hub is empty", async () => (await size("small")) === "0");
});

test("the default limits allow 128 subscriptions per connection and 255-byte topics", async () => {
  // The review's case: one peer asking for 256 distinct topics.
  const d = await Client.open("default");
  const topics = Array.from({ length: 256 }, (_, i) => `d${i}`);
  const outcomes = await d.subAll(topics);
  expect(outcomes.slice(0, 128).every((o) => o === "subscribed")).toBe(true);
  expect(outcomes.slice(128).every((o) => o === "peer-limit")).toBe(true);
  expect(await size("default")).toBe("128");

  const e = await Client.open("default");
  expect(await e.sub("a".repeat(255))).toBe("subscribed");
  expect(await e.sub("a".repeat(256))).toBe("topic-too-long");
  expect(await size("default")).toBe("129");

  d.close();
  await until("the closed peer's 128 slots are free", async () => (await size("default")) === "1");
  e.close();
  await until("the default hub is empty", async () => (await size("default")) === "0");
});
