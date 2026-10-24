// BND-96: the plain and validating pipelines repeat the request lifecycle's
// setup on purpose (see parsed_plain in src/app/handle.bend). This test keeps
// them from drifting apart: one app without route schemas, served through
// each pipeline, must answer the same bytes and leave the same hook and log
// traces for buffered responses, errors, rewrites, a stream and an upgrade.
import { afterAll, expect, test } from "bun:test";
import { mkdtempSync, rmSync } from "node:fs";
import { connect } from "node:net";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { build, start, type RunningServer } from "./harness.ts";

const binary = build("tests/servers/pipelines.bend");

// A fixed wall clock makes every Date header the same. Durations come from
// the monotonic clock, so the comparison masks them.
const clockDirectory = mkdtempSync(join(tmpdir(), "bendo-pipelines-clock-"));
afterAll(() => rmSync(clockDirectory, { recursive: true, force: true }));
const clockShim = join(clockDirectory, "clock-fixed.so");
const fixedClock = process.platform === "linux";
if (fixedClock) {
  const run = Bun.spawnSync(
    [
      "timeout",
      "10s",
      "cc",
      "-shared",
      "-fPIC",
      "tests/fixtures/pipelines/clock-fixed.c",
      "-o",
      clockShim,
      "-ldl",
    ],
    { stdout: "pipe", stderr: "pipe" },
  );
  if (run.exitCode !== 0) throw new Error(`fixed clock fixture compile failed: ${run.stderr}`);
}
const clockEnv: Record<string, string> = fixedClock ? { LD_PRELOAD: clockShim } : {};

type Pipeline = "plain" | "checked";

async function serve(pipeline: Pipeline): Promise<RunningServer> {
  return start(binary, "127.0.0.1", { ...clockEnv, BENDO_TEST_PIPELINE: pipeline });
}

async function exchange(server: RunningServer, request: string): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    const socket = connect(Number(new URL(server.url).port), "127.0.0.1");
    const parts: Buffer[] = [];
    socket.setTimeout(5000, () => socket.destroy(new Error("pipelines socket timeout")));
    socket.on("connect", () => socket.write(request));
    socket.on("data", (part: Buffer) => parts.push(part));
    socket.on("end", () => {
      socket.destroy();
      resolve(Buffer.concat(parts));
    });
    socket.on("error", reject);
  });
}

// Every request names its X-Request-ID, so generated IDs never differ.
function request(
  index: number,
  line: string,
  fields: Readonly<Record<string, string>> = {},
): string {
  const lines = [line, "Host: test", `X-Request-ID: diff-${index}`, "Connection: close"];
  for (const [name, value] of Object.entries(fields)) lines.push(`${name}: ${value}`);
  return `${lines.join("\r\n")}\r\n\r\n`;
}

const upgrade = {
  Upgrade: "websocket",
  Connection: "Upgrade",
  "Sec-WebSocket-Key": "dGhlIHNhbXBsZSBub25jZQ==",
  "Sec-WebSocket-Version": "13",
};

const cases: readonly { name: string; line: string; fields?: Record<string, string> }[] = [
  { name: "buffered text", line: "GET / HTTP/1.1" },
  { name: "buffered JSON with a timing mark", line: "GET /json HTTP/1.1" },
  { name: "HEAD", line: "HEAD /json HTTP/1.1" },
  { name: "handler 500", line: "GET /failing HTTP/1.1" },
  { name: "on_error replacement", line: "GET /recover HTTP/1.1" },
  { name: "thrown HTTP error", line: "GET /thrown HTTP/1.1" },
  { name: "map_response replacement", line: "GET /mapped HTTP/1.1" },
  { name: "on_request rewrite", line: "GET /rewrite HTTP/1.1" },
  { name: "not found", line: "GET /missing HTTP/1.1" },
  { name: "method not allowed", line: "GET /only-post HTTP/1.1" },
  { name: "malformed query", line: "GET /?a=%zz HTTP/1.1" },
  {
    name: "CORS and secure headers",
    line: "GET /policy/hello HTTP/1.1",
    fields: { Origin: "https://app.example" },
  },
  {
    name: "CORS preflight",
    line: "OPTIONS /policy/hello HTTP/1.1",
    fields: { Origin: "https://app.example", "Access-Control-Request-Method": "GET" },
  },
  // Hooks that replace the response get the retained policies again.
  {
    name: "map_response replacement with retained policies",
    line: "GET /policy/mapped HTTP/1.1",
    fields: { Origin: "https://app.example" },
  },
  {
    name: "on_error replacement with retained policies",
    line: "GET /policy/recover HTTP/1.1",
    fields: { Origin: "https://app.example" },
  },
  { name: "stream", line: "GET /stream HTTP/1.1" },
  {
    name: "stream with retained policies",
    line: "GET /policy/stream HTTP/1.1",
    fields: { Origin: "https://app.example" },
  },
  { name: "WebSocket upgrade", line: "GET /ws HTTP/1.1", fields: upgrade },
  {
    name: "WebSocket upgrade with retained policies",
    line: "GET /policy/ws HTTP/1.1",
    fields: { ...upgrade, Origin: "https://app.example" },
  },
];

// Mask only what the monotonic clock measures.
function masked(text: string): string {
  return text.replace(/dur=\d+(\.\d+)?/g, "dur=#").replace(/ \d+ms\b/g, " #ms");
}

// The traces are complete once stderr stops growing.
async function settled(server: RunningServer): Promise<string> {
  let last = server.stderr();
  let stable = 0;
  for (let waited = 0; waited < 5000 && stable < 4; waited += 100) {
    await Bun.sleep(100);
    const now = server.stderr();
    stable = now === last ? stable + 1 : 0;
    last = now;
  }
  return last;
}

type Run = { responses: string[]; traces: string };

async function drive(pipeline: Pipeline): Promise<Run> {
  await using server = await serve(pipeline);
  // Skip the traces of the harness's readiness probe.
  const before = (await settled(server)).length;
  const responses: string[] = [];
  for (const [index, entry] of cases.entries()) {
    const wire = await exchange(server, request(index, entry.line, entry.fields));
    responses.push(`${entry.name}\n${masked(wire.toString("latin1"))}`);
  }
  return { responses, traces: masked((await settled(server)).slice(before)) };
}

test(
  "an app without schemas answers and traces the same through both pipelines",
  async () => {
    const [plain, checked] = await Promise.all([drive("plain"), drive("checked")]);
    expect(checked.responses).toEqual(plain.responses);
    expect(checked.traces).toEqual(plain.traces);

    // The cases reached what they name, so equal output is not equal silence.
    const wire = new Map(cases.map((entry, index) => [entry.name, plain.responses[index] ?? ""]));
    expect(wire.get("on_error replacement")).toContain("HTTP/1.1 503");
    expect(wire.get("thrown HTTP error")).toContain("HTTP/1.1 418");
    expect(wire.get("map_response replacement")).toContain("HTTP/1.1 201");
    expect(wire.get("on_request rewrite")).toContain("target:7");
    expect(wire.get("not found")).toContain("HTTP/1.1 404");
    expect(wire.get("method not allowed")).toContain("HTTP/1.1 405");
    expect(wire.get("malformed query")).toContain("HTTP/1.1 400");
    expect(wire.get("CORS and secure headers")).toContain(
      "access-control-allow-origin: https://app.example",
    );
    for (const name of [
      "map_response replacement with retained policies",
      "on_error replacement with retained policies",
    ])
      expect(wire.get(name)).toContain("access-control-allow-origin: https://app.example");
    expect(wire.get("stream")).toContain("transfer-encoding: chunked");
    expect(wire.get("stream with retained policies")).toContain(
      "access-control-allow-origin: https://app.example",
    );
    expect(wire.get("WebSocket upgrade")).toContain("HTTP/1.1 101");
    expect(wire.get("WebSocket upgrade with retained policies")).toContain("HTTP/1.1 101");
    if (fixedClock)
      // A 101 carries no Date.
      for (const response of plain.responses.filter((r) => !r.includes("HTTP/1.1 101")))
        expect(response).toContain("date: Thu, 01 Jan 2026 00:00:00 GMT");
    for (const trace of [
      "before:/json",
      "after:/json",
      "map:/json",
      "error:/recover",
      "not-found:/missing",
      "observed:/target/7",
      "pull:0",
      "stream-cleanup",
      "ws-open:ws:0",
      "GET /rewrite 200 #ms id=diff-7",
    ])
      expect(plain.traces).toContain(trace);
  },
  60_000,
);
