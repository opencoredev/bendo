// BND-106: a buffered response's write deadline. The fixture serves an 8 MiB
// buffered body with write_timeout_ms 1000 and counts its after-response runs.
import { afterAll, beforeAll, expect, test } from "bun:test";
import { mkdtempSync, rmSync } from "node:fs";
import { connect, type Socket } from "node:net";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { build, start, type RunningServer } from "./harness.ts";

const binary = build("tests/servers/write-deadline.bend");
const BODY = 8 * 1024 * 1024;
const WRITE_TIMEOUT_MS = 1000;

// Test-only send fault (LD_PRELOAD, native only): a parser reply always finds
// its socket's send buffer full, as an earlier response leaves it when the
// client stops reading.
const shimDirectory = mkdtempSync(join(tmpdir(), "bendo-write-deadline-"));
const fullSocketShim = join(shimDirectory, "full-socket.so");
const compiled = Bun.spawnSync(
  [
    "timeout",
    "10s",
    "cc",
    "-shared",
    "-fPIC",
    "tests/fixtures/write-deadline/full-socket.c",
    "-o",
    fullSocketShim,
    "-ldl",
  ],
  { stdout: "pipe", stderr: "pipe" },
);
if (compiled.exitCode !== 0)
  throw new Error(`send fault fixture compile failed: ${compiled.stderr}`);

let server: RunningServer;
let full: RunningServer;
beforeAll(async () => {
  server = await start(binary);
  full = await start(binary, "127.0.0.1", { LD_PRELOAD: fullSocketShim });
});
afterAll(async () => {
  await server?.[Symbol.asyncDispose]();
  await full?.[Symbol.asyncDispose]();
  rmSync(shimDirectory, { recursive: true, force: true });
});

/** After-response runs recorded since the last call. */
async function runs(): Promise<number> {
  const res = await fetch(server.url + "/count");
  expect(res.status).toBe(200);
  return Number(await res.text());
}

function open(path: string): Socket {
  const socket = connect(Number(new URL(server.url).port), "127.0.0.1");
  // Paused from the start, so nothing is read until the test resumes it.
  socket.pause();
  socket.write(`GET ${path} HTTP/1.1\r\nHost: x\r\n\r\n`);
  return socket;
}

/** Resumes a socket and resolves with every byte it receives until EOF or reset. */
function drain(socket: Socket): Promise<number> {
  return new Promise((resolve) => {
    let received = 0;
    socket.on("data", (bytes: Buffer) => {
      received += bytes.length;
    });
    socket.on("close", () => resolve(received));
    socket.on("error", () => {});
    socket.resume();
  });
}

test("a client that never reads is disconnected and after-response runs once", async () => {
  await runs();
  const socket = open("/big");
  // Take the first chunk, which shows the server has started writing, then
  // stop reading. Building the 8 MiB body takes the server a while.
  const started = await new Promise<number>((resolve) => {
    socket.once("data", () => {
      socket.pause();
      resolve(Date.now());
    });
    socket.resume();
  });
  let total = 0;
  while (total === 0 && Date.now() - started < 8000) {
    await Bun.sleep(100);
    // The server keeps answering other clients while that write is stalled.
    const ping = await fetch(server.url + "/ping");
    expect(await ping.text()).toBe("pong");
    total += await runs();
  }
  const elapsed = Date.now() - started;
  expect(total).toBe(1);
  // The window in which the socket buffers fill makes progress; the next one
  // makes none and closes the connection: at most twice the timeout, plus slack.
  expect(elapsed).toBeGreaterThanOrEqual(WRITE_TIMEOUT_MS - 100);
  expect(elapsed).toBeLessThan(2 * WRITE_TIMEOUT_MS + 1500);
  await Bun.sleep(WRITE_TIMEOUT_MS);
  expect(await runs()).toBe(0);
  // The connection was closed before the body finished.
  const received = await drain(socket);
  expect(received).toBeLessThan(BODY);
  expect(await runs()).toBe(0);
}, 20_000);

test("a client that reads slowly but steadily gets the whole body", async () => {
  await runs();
  const started = Date.now();
  const socket = open("/slow");
  const chunks: Buffer[] = [];
  let tick = 0;
  socket.on("data", (bytes: Buffer) => {
    chunks.push(bytes);
    tick += bytes.length;
    // Take about 512 KiB, then wait for the next tick.
    if (tick >= 512 * 1024) socket.pause();
  });
  const timer = setInterval(() => {
    tick = 0;
    socket.resume();
  }, 200);
  const closed = new Promise<void>((resolve, reject) => {
    socket.on("error", reject);
    const check = () => {
      const data = Buffer.concat(chunks);
      const end = data.indexOf("\r\n\r\n");
      if (end >= 0 && data.length >= end + 4 + BODY) resolve();
    };
    socket.on("data", check);
    socket.on("close", check);
  });
  try {
    await closed;
  } finally {
    clearInterval(timer);
    socket.destroy();
  }
  const data = Buffer.concat(chunks);
  const end = data.indexOf("\r\n\r\n");
  const head = data.subarray(0, end).toString("latin1");
  expect(head).toStartWith("HTTP/1.1 200");
  expect(head.toLowerCase()).toContain(`content-length: ${BODY}`);
  expect(data.length).toBe(end + 4 + BODY);
  // Slower than one window, so a total deadline would have cut it off.
  expect(Date.now() - started).toBeGreaterThan(2 * WRITE_TIMEOUT_MS);
  await Bun.sleep(200);
  expect(await runs()).toBe(1);
}, 30_000);

/** Resumes a socket and collects what it receives until it closes or `ms` passes. */
function collect(socket: Socket, ms: number): Promise<{ text: string; closed: boolean }> {
  return new Promise((resolve) => {
    const chunks: Buffer[] = [];
    const finish = (closed: boolean) => {
      clearTimeout(timer);
      socket.destroy();
      resolve({ text: Buffer.concat(chunks).toString("latin1"), closed });
    };
    const timer = setTimeout(() => finish(false), ms);
    socket.on("data", (bytes: Buffer) => chunks.push(bytes));
    socket.on("close", () => finish(true));
    socket.on("error", () => {});
    socket.resume();
  });
}

// A keep-alive connection answers its first pipelined request, then a second
// request draws a parser reply while the client has stopped reading. The
// reply must give up within the write deadline like any response, so by the
// time the client reads again the server has closed the connection without
// sending it. A server still holding the socket never closes it.
const parserReplies: ReadonlyArray<readonly [string, string, string]> = [
  [
    "431",
    "an oversized head",
    `GET /ping HTTP/1.1\r\nHost: x\r\nX-Big: ${"a".repeat(70_000)}\r\n\r\n`,
  ],
  [
    "413",
    "a body over the limit",
    "POST /ping HTTP/1.1\r\nHost: x\r\nContent-Length: 2000000\r\n\r\n",
  ],
  [
    "100",
    "100 Continue",
    "POST /ping HTTP/1.1\r\nHost: x\r\nContent-Length: 4\r\nExpect: 100-continue\r\n\r\n",
  ],
];

for (const [status, label, second] of parserReplies) {
  test(`${label} on a full socket is dropped within the write deadline`, async () => {
    const socket = connect(Number(new URL(full.url).port), "127.0.0.1");
    socket.pause();
    socket.write(`GET /ping HTTP/1.1\r\nHost: x\r\n\r\n${second}`);
    // Two windows plus slack, while the server keeps answering others.
    const until = Date.now() + 2 * WRITE_TIMEOUT_MS + 1500;
    while (Date.now() < until) {
      const ping = await fetch(full.url + "/ping");
      expect(await ping.text()).toBe("pong");
      await Bun.sleep(200);
    }
    const { text, closed } = await collect(socket, 3000);
    expect(closed).toBe(true);
    // A boolean, so a failure does not print megabytes of filler.
    expect(text.includes(`HTTP/1.1 ${status} `)).toBe(false);
  }, 20_000);
}
