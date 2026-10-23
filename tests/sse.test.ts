import { afterAll, expect, test } from "bun:test";
import { connect } from "node:net";
import { pathToFileURL } from "node:url";
import { build, compile, start } from "./harness.ts";

// Browser check (manual): build tests/servers/sse.bend, run it with
// HOST="$(tailscale ip -4)" PORT=24990, and open http://<tailscale-ip>:24990/.
// The page's EventSource must receive events 1 to 10 in order over two
// connections (the server ends the first after event 4; the browser resumes
// with Last-Event-ID 4; a reconnect after 10 gets 204) and show PASS, with
// document.body.dataset.result === "pass". See docs/sse.md.

// Compilation stays at module scope, so the harness's compile budget applies.
const binary = build("tests/servers/sse.bend");
const specModule = compile("proof/sse-spec.bend", "mjs");
const server = await start(binary);
afterAll(() => server[Symbol.asyncDispose]());

/** Socket budget for one exchange; every route finishes well inside it. */
const SOCKET_TIMEOUT_MS = 5000;
/** Heartbeat interval requested from /heartbeat, and how many the test reads. */
const HEARTBEAT_MS = 100;
const HEARTBEATS = 2;
/** The open-ended /heartbeat stays idle far past the socket budget. */
const HOLD_MS = 60_000;
/** The finite /heartbeat idles this long, then sends "ready" and ends. */
const READY_MS = 450;
/** /quiet idles this long with heartbeats disabled. */
const QUIET_MS = 300;
/** Timers may fire early relative to the client's clock by at most this share. */
const EARLY_FRACTION = 0.5;

type Dispatched = { type: string; data: string; lastEventId: string };
type Parsed = { events: Dispatched[]; retries: number[]; comments: string[] };

/**
 * Independent WHATWG "Interpreting an event stream" parser over decoded text:
 * CRLF, LF and CR end lines; one leading space after the colon is removed;
 * an id containing NUL is ignored; retry needs ASCII digits only; a pending
 * event at end of stream is discarded. Comments are recorded for the
 * heartbeat tests only.
 */
function parseEventStream(text: string): Parsed {
  const parsed: Parsed = { events: [], retries: [], comments: [] };
  let type = "";
  let data = "";
  let lastId = "";
  const body = text.startsWith("﻿") ? text.slice(1) : text;
  const lines = body.split(/\r\n|\r|\n/);
  // The final element follows the last line ending: it is incomplete.
  lines.pop();
  for (const line of lines) {
    if (line === "") {
      if (data === "") {
        type = "";
        continue;
      }
      parsed.events.push({
        type: type === "" ? "message" : type,
        data: data.endsWith("\n") ? data.slice(0, -1) : data,
        lastEventId: lastId,
      });
      type = "";
      data = "";
      continue;
    }
    if (line.startsWith(":")) {
      parsed.comments.push(line.slice(1));
      continue;
    }
    const colon = line.indexOf(":");
    const field = colon < 0 ? line : line.slice(0, colon);
    const raw = colon < 0 ? "" : line.slice(colon + 1);
    const value = raw.startsWith(" ") ? raw.slice(1) : raw;
    switch (field) {
      case "event":
        type = value;
        break;
      case "data":
        data += `${value}\n`;
        break;
      case "id":
        if (!value.includes("\0")) lastId = value;
        break;
      case "retry":
        if (/^[0-9]+$/.test(value)) parsed.retries.push(Number(value));
        break;
      default:
        break;
    }
  }
  return parsed;
}

type Arrival = { at: number; text: string };
type Received = { status: number; headers: Headers; arrivals: Arrival[]; text: string };

async function receive(path: string, headers: Record<string, string> = {}): Promise<Received> {
  const response = await fetch(`${server.url}${path}`, {
    headers,
    signal: AbortSignal.timeout(SOCKET_TIMEOUT_MS),
  });
  const arrivals: Arrival[] = [];
  const decoder = new TextDecoder();
  const reader = response.body?.getReader();
  if (reader === undefined) throw new Error("missing response body");
  while (true) {
    const part = await reader.read();
    if (part.done) break;
    arrivals.push({ at: performance.now(), text: decoder.decode(part.value, { stream: true }) });
  }
  return {
    status: response.status,
    headers: response.headers,
    arrivals,
    text: arrivals.map((arrival) => arrival.text).join(""),
  };
}

// Raw HTTP, for aborted streams and versions fetch cannot express.
async function exchange(request: string): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    const socket = connect(Number(new URL(server.url).port), "127.0.0.1");
    const parts: Buffer[] = [];
    socket.setTimeout(SOCKET_TIMEOUT_MS, () => socket.destroy(new Error("sse socket timeout")));
    socket.on("connect", () => socket.write(request));
    socket.on("data", (part: Buffer) => parts.push(part));
    socket.on("end", () => {
      socket.destroy();
      resolve(Buffer.concat(parts));
    });
    socket.on("error", reject);
  });
}

const request = (path: string, method = "GET", version = "1.1") =>
  `${method} ${path} HTTP/${version}\r\nHost: test\r\nConnection: close\r\n\r\n`;

function split(wire: Buffer): { status: number; rest: Buffer } {
  const at = wire.indexOf("\r\n\r\n");
  if (at < 0) throw new Error("missing response head");
  const status = Number(wire.subarray(0, at).toString("latin1").split(" ")[1]);
  return { status, rest: wire.subarray(at + 4) };
}

// Concatenated chunk payloads up to the last complete chunk, and whether a
// terminal zero chunk arrived.
function dechunk(body: Buffer): { payload: string; terminated: boolean } {
  const parts: Buffer[] = [];
  let rest = body;
  while (true) {
    const at = rest.indexOf("\r\n");
    if (at < 1) return { payload: Buffer.concat(parts).toString(), terminated: false };
    const size = Number.parseInt(rest.subarray(0, at).toString("ascii"), 16);
    if (size === 0) return { payload: Buffer.concat(parts).toString(), terminated: true };
    if (rest.length < at + 2 + size + 2)
      return { payload: Buffer.concat(parts).toString(), terminated: false };
    parts.push(rest.subarray(at + 2, at + 2 + size));
    rest = rest.subarray(at + 2 + size + 2);
  }
}

test("SSE responses are uncached, uncompressed text/event-stream chunks", async () => {
  const response = await receive("/frames");
  expect(response.status).toBe(200);
  expect(response.headers.get("content-type")).toBe("text/event-stream");
  expect(response.headers.get("cache-control")).toBe("no-cache");
  expect(response.headers.get("x-accel-buffering")).toBe("no");
  expect(response.headers.has("content-encoding")).toBe(false);
  expect(response.headers.has("content-length")).toBe(false);
});

test("application content-encoding and cache headers cannot leak into a stream", async () => {
  const response = await receive("/encoded");
  expect(response.headers.has("content-encoding")).toBe(false);
  expect(response.headers.get("cache-control")).toBe("no-cache");
  expect(parseEventStream(response.text).events).toEqual([
    { type: "message", data: "plain", lastEventId: "" },
  ]);
});

test("frames have the exact field layout, splitting CR, LF and CRLF into data lines", async () => {
  const response = await receive("/frames");
  expect(response.text).toBe(
    [
      ": hello",
      "event: update",
      "data: lf",
      "data: cr",
      "data: crlf",
      "data: end",
      "id: 7",
      "retry: 1500",
      "",
      "data:  lead: x",
      "",
      "data: ",
      "id: ",
      "retry: 0",
      "",
      "event: ",
      "data: ",
      "data: ",
      "data: ",
      "data: ",
      "retry: 4294967295",
      "",
      "event: ünï",
      "data: snow ☃ and 🎉",
      "id: id ✓",
      "",
      "",
    ].join("\n"),
  );
});

test("an independent parser recovers event, normalized data, id and retry", async () => {
  const parsed = parseEventStream((await receive("/frames")).text);
  expect(parsed.events).toEqual([
    { type: "update", data: "lf\ncr\ncrlf\nend", lastEventId: "7" },
    { type: "message", data: " lead: x", lastEventId: "7" },
    { type: "message", data: "", lastEventId: "" },
    { type: "message", data: "\n\n\n", lastEventId: "" },
    { type: "ünï", data: "snow ☃ and 🎉", lastEventId: "id ✓" },
  ]);
  expect(parsed.retries).toEqual([1500, 0, 4294967295]);
  expect(parsed.comments).toEqual([" hello"]);
});

// utf8 and overlong send octets a browser would decode with U+FFFD.
for (const field of ["event", "id", "nul", "comment", "utf8", "overlong"]) {
  test(`an unsafe ${field} aborts the stream instead of injecting fields`, async () => {
    const response = split(await exchange(request(`/reject?field=${field}`)));
    expect(response.status).toBe(200);
    const body = dechunk(response.rest);
    expect(body.terminated).toBe(false);
    expect(body.payload).toBe("data: before\n\n");
  });
}

test("the handler receives Last-Event-ID", async () => {
  const resumed = parseEventStream((await receive("/last", { "Last-Event-ID": "abc 42" })).text);
  expect(resumed.events.map((event) => event.data)).toEqual(["abc 42"]);
  const fresh = parseEventStream((await receive("/last")).text);
  expect(fresh.events.map((event) => event.data)).toEqual(["start"]);
});

test("a reconnect with Last-Event-ID resumes after the last delivered event", async () => {
  const first = parseEventStream((await receive("/events?count=10&drop=4")).text);
  expect(first.events.map((event) => event.lastEventId)).toEqual(["1", "2", "3", "4"]);
  expect(first.events.every((event) => event.type === "tick")).toBe(true);
  expect(first.retries).toEqual([250]);
  const second = parseEventStream(
    (await receive("/events?count=10&drop=4", { "Last-Event-ID": "4" })).text,
  );
  expect(second.events.map((event) => event.lastEventId)).toEqual(["5", "6", "7", "8", "9", "10"]);
  expect(second.events[0]?.data).toBe("event 5 after 4");
  const done = await fetch(`${server.url}/events?count=10&drop=4`, {
    headers: { "Last-Event-ID": "10" },
  });
  expect(done.status).toBe(204);
});

test("idle producers get comment heartbeats that parsers ignore", async () => {
  // The producer idles far longer than the test reads, so heartbeats are the
  // only output. Read until enough complete heartbeat lines arrive, then hang
  // up; lines are reassembled across any TCP partition of the writes.
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), SOCKET_TIMEOUT_MS);
  const response = await fetch(`${server.url}/heartbeat?every=${HEARTBEAT_MS}&wait=${HOLD_MS}`, {
    signal: controller.signal,
  });
  const reader = response.body?.getReader();
  if (reader === undefined) throw new Error("missing response body");
  const decoder = new TextDecoder();
  const beats: string[] = [];
  let text = "";
  let pending = "";
  try {
    while (beats.length < HEARTBEATS) {
      const part = await reader.read();
      if (part.done) break;
      const chunk = decoder.decode(part.value, { stream: true });
      text += chunk;
      const lines = (pending + chunk).split("\n");
      pending = lines.pop() ?? "";
      for (const line of lines) if (line.startsWith(":")) beats.push(line.slice(1));
    }
  } finally {
    clearTimeout(timer);
    controller.abort();
  }
  // A final read may hold more heartbeats than the test waited for.
  expect(beats.length).toBeGreaterThanOrEqual(HEARTBEATS);
  expect(beats.every((comment) => comment === " keepalive")).toBe(true);
  expect(parseEventStream(text).events).toEqual([]);
});

test("a heartbeating stream still delivers its final event and ends", async () => {
  const response = await receive(`/heartbeat?every=${HEARTBEAT_MS}&wait=${READY_MS}`);
  const parsed = parseEventStream(response.text);
  expect(parsed.events).toEqual([{ type: "message", data: "ready", lastEventId: "" }]);
  expect(parsed.comments.every((comment) => comment === " keepalive")).toBe(true);
});

test("a zero heartbeat interval disables heartbeats", async () => {
  const sent = performance.now();
  const response = await receive("/quiet");
  const parsed = parseEventStream(response.text);
  expect(parsed.comments).toEqual([]);
  expect(parsed.events.map((event) => event.data)).toEqual(["ready"]);
  const last = response.arrivals.at(-1);
  expect(last).toBeDefined();
  expect((last?.at ?? 0) - sent).toBeGreaterThanOrEqual(QUIET_MS * EARLY_FRACTION);
});

test("HEAD sends SSE headers without a body", async () => {
  const response = split(await exchange(request("/frames", "HEAD")));
  expect(response.status).toBe(200);
  expect(response.rest.length).toBe(0);
});

test("HTTP/1.0 event streams are rejected before the head", async () => {
  const response = split(await exchange(request("/frames", "GET", "1.0")));
  expect(response.status).toBe(505);
  expect(response.rest.length).toBe(0);
});

type BendList = { $: "Nil" } | { $: "Con"; head: unknown; tail: BendList };

function bendList(values: Iterable<number>): BendList {
  const items = [...values];
  let tail: BendList = { $: "Nil" };
  for (let i = items.length - 1; i >= 0; i--) tail = { $: "Con", head: items[i], tail };
  return tail;
}

function field(value: unknown, name: string): unknown {
  if (typeof value !== "object" || value === null || !(name in value)) {
    throw new Error(`missing ${name}`);
  }
  return Reflect.get(value, name);
}

function items(value: unknown): unknown[] {
  const out: unknown[] = [];
  let at = value;
  while (field(at, "$") === "Con") {
    out.push(field(at, "head"));
    at = field(at, "tail");
  }
  if (field(at, "$") !== "Nil") throw new Error("malformed Bend list");
  return out;
}

function octets(value: unknown): string {
  const bytes = items(value).map((byte) => {
    if (typeof byte !== "number") throw new Error("expected an octet");
    return byte;
  });
  return new TextDecoder().decode(new Uint8Array(bytes));
}

// The Bend specification parser from proof/sse-spec.bend, run as JavaScript.
async function bendSpecParse(): Promise<(text: string) => Parsed> {
  const imported: unknown = await import(pathToFileURL(specModule).href);
  const parse = field(field(imported, "default"), "parse");
  if (typeof parse !== "function") throw new Error("missing parse");
  return (text) => {
    const parsed: Parsed = { events: [], retries: [], comments: [] };
    const output: unknown = parse(bendList(new TextEncoder().encode(text)));
    for (const item of items(output)) {
      const tag = field(item, "$");
      if (tag === "Dispatched") {
        parsed.events.push({
          type: octets(field(item, "kind")),
          data: octets(field(item, "data")),
          lastEventId: octets(field(item, "id")),
        });
      } else if (tag === "Reconnect") {
        const ms = field(item, "ms");
        if (typeof ms !== "number") throw new Error("expected a Nat");
        parsed.retries.push(ms);
      } else {
        throw new Error(`unexpected observation ${String(tag)}`);
      }
    }
    return parsed;
  };
}

test("the proof's spec parser agrees with the reference parser on edge cases", async () => {
  const specParse = await bendSpecParse();
  const streams = [
    "data: a\r\ndata: b\r\n\r\n",
    "data:a\rdata: b\r\r",
    "data: a\n\r\ndata: b\n\n",
    "\uFEFFdata: bom\n\n",
    "\uFEFF\uFEFFdata: twice\n\n",
    "id: 1\0x\ndata: nul id ignored\n\n",
    "id: 7\ndata: a\n\ndata: b\n\nid\ndata: c\n\n",
    "retry: 12a\nretry: 0300\nretry:\nretry: 5\nretry: -1\n\n",
    "event: e\ndata\n\n",
    "data: pending at end of stream\n",
    "data: unterminated",
    ": c\nevent: up\n:\ndata:  two\n\n",
    "event: x\n\ndata: y\n\n",
    "data: \n\n",
    "field: z\ndata: q\nDATA: no\n\n",
    "dat\r\na: x\n\n",
    "data: ☃ 🎉\nevent: ünï\n\n",
    "data:\tx: y\n\n",
  ];
  // The spec reports events and reconnection times; comments are invisible.
  for (const stream of streams) {
    const reference = parseEventStream(stream);
    expect(specParse(stream)).toEqual({ ...reference, comments: [] });
  }
});
