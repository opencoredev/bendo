import { afterAll, expect, test } from "bun:test";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { connect } from "node:net";
import { build, start, SLOW_TEST_TIMEOUT_MS } from "./harness.ts";

// Compilation stays at module scope, so the harness's compile budget applies.
const connectBinary = build("tests/fixtures/stream/connect.bend");
const binary = build("tests/servers/stream.bend");
const clockDirectory = mkdtempSync(join(tmpdir(), "bendo-stream-clock-"));
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
const server = await start(binary);
afterAll(() => server[Symbol.asyncDispose]());

async function exchange(request: string): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    const socket = connect(Number(new URL(server.url).port), "127.0.0.1");
    const parts: Buffer[] = [];
    socket.setTimeout(5000, () => socket.destroy(new Error("stream socket timeout")));
    socket.on("connect", () => socket.write(request));
    socket.on("data", (part: Buffer) => parts.push(part));
    socket.on("end", () => {
      socket.destroy();
      resolve(Buffer.concat(parts));
    });
    socket.on("error", reject);
  });
}

const request = (path: string, method = "GET", version = "1.1", close = true) =>
  `${method} ${path} HTTP/${version}\r\nHost: test\r\n${close ? "Connection: close\r\n" : ""}\r\n`;

function head(wire: Buffer) {
  const at = wire.indexOf("\r\n\r\n");
  if (at < 0) throw new Error("missing response head");
  const lines = wire.subarray(0, at).toString("latin1").split("\r\n");
  const headers = new Headers();
  for (const line of lines.slice(1)) {
    const colon = line.indexOf(":");
    if (colon < 1) throw new Error("malformed header");
    headers.append(line.slice(0, colon), line.slice(colon + 1).trim());
  }
  return { status: Number(lines[0]?.split(" ")[1]), headers, rest: wire.subarray(at + 4) };
}

// Independent RFC 9112 decoder: require exact size/data CRLF and empty trailers.
function chunks(wire: Buffer) {
  const parts: Buffer[] = [];
  let rest = wire;
  while (true) {
    const at = rest.indexOf("\r\n");
    if (at < 1) throw new Error("missing chunk size");
    const line = rest.subarray(0, at).toString("ascii");
    if (!/^[0-9a-f]+$/i.test(line)) throw new Error("invalid hexadecimal size");
    const size = Number.parseInt(line, 16);
    rest = rest.subarray(at + 2);
    if (rest.length < size + 2 || rest.subarray(size, size + 2).toString() !== "\r\n")
      throw new Error("incomplete chunk");
    if (size === 0) return { body: Buffer.concat(parts), rest: rest.subarray(2) };
    parts.push(rest.subarray(0, size));
    rest = rest.subarray(size + 2);
  }
}

test("streams bytes with chunked framing and final Date/observability headers", async () => {
  const response = head(await exchange(request("/stream?chunks=4")));
  expect(response.status).toBe(200);
  expect(response.headers.get("transfer-encoding")).toBe("chunked");
  expect(response.headers.has("content-length")).toBe(false);
  expect(response.headers.has("x-bendo-stream-internal")).toBe(false);
  expect(response.headers.get("date")).toMatch(/GMT$/);
  expect(response.headers.get("x-request-id")).toMatch(/^[0-9a-f]{32}$/);
  expect(response.headers.get("server-timing")).toMatch(/^total;dur=/);
  const decoded = chunks(response.rest);
  expect(decoded.body).toEqual(Buffer.alloc(4 * 4096, 120));
  expect(decoded.rest.length).toBe(0);
});

for (const path of ["/policy/stream?chunks=1", "/policy/recovered"]) {
  test(`stream head retains CORS, security and observability after finalization: ${path}`, async () => {
    const response = head(
      await exchange(
        `GET ${path} HTTP/1.1\r\nHost: test\r\nOrigin: https://app.example\r\nX-Request-Id: stream-policy-id\r\nConnection: close\r\n\r\n`,
      ),
    );
    expect(response.status).toBe(200);
    expect(response.headers.get("transfer-encoding")).toBe("chunked");
    expect(response.headers.get("access-control-allow-origin")).toBe("https://app.example");
    expect(response.headers.get("access-control-allow-credentials")).toBe("true");
    expect(response.headers.get("vary")?.split(/,\s*/)).toContain("Origin");
    for (const [name, value] of new Map([
      ["cross-origin-resource-policy", "same-origin"],
      ["cross-origin-opener-policy", "same-origin"],
      ["origin-agent-cluster", "?1"],
      ["referrer-policy", "no-referrer"],
      ["strict-transport-security", "max-age=15552000; includeSubDomains"],
      ["x-content-type-options", "nosniff"],
      ["x-dns-prefetch-control", "off"],
      ["x-download-options", "noopen"],
      ["x-frame-options", "SAMEORIGIN"],
      ["x-permitted-cross-domain-policies", "none"],
      ["x-xss-protection", "0"],
    ])) {
      expect(response.headers.get(name)).toBe(value);
    }
    expect(response.headers.has("x-powered-by")).toBe(false);
    expect(response.headers.has("x-bendo-stream-internal")).toBe(false);
    expect(response.headers.get("x-request-id")).toBe("stream-policy-id");
    expect(response.headers.get("server-timing")).toMatch(/^total;dur=/);
    expect(response.headers.get("date")).toMatch(/GMT$/);
    const decoded = chunks(response.rest);
    expect(decoded.body).toEqual(
      path === "/policy/recovered" ? Buffer.from("abab") : Buffer.alloc(4096, 120),
    );
    expect(decoded.rest.length).toBe(0);
    if (path === "/policy/recovered") {
      expect(response.headers.get("vary")).toBe("Accept-Encoding, Origin");
    }
  });
}

test("skips empty chunks rather than ending the response", async () => {
  const response = head(await exchange(request("/empty")));
  expect(response.rest.toString()).toBe("2\r\nab\r\n2\r\nab\r\n0\r\n\r\n");
  expect(chunks(response.rest).body.toString()).toBe("abab");
});

test("aborts a failed producer without a terminal chunk or pipelined dispatch", async () => {
  const response = head(await exchange(request("/broken", "GET", "1.1", false) + request("/")));
  expect(response.status).toBe(200);
  expect(response.rest).toEqual(Buffer.from([51, 13, 10, 0, 128, 255, 13, 10]));
  expect(() => chunks(response.rest)).toThrow();
});

test("completed streams preserve a pipelined next request", async () => {
  const response = head(await exchange(request("/empty", "GET", "1.1", false) + request("/")));
  const decoded = chunks(response.rest);
  expect(decoded.body.toString()).toBe("abab");
  const next = head(decoded.rest);
  expect(next.status).toBe(200);
  expect(next.rest.toString()).toBe("hello");
});

test("buffered HEAD keeps the GET representation length after policy finalization", async () => {
  const response = head(await exchange(request("/", "HEAD")));
  expect(response.status).toBe(200);
  expect(response.headers.get("content-length")).toBe("5");
  expect(response.rest.length).toBe(0);
});

test("HEAD has neither a body nor a fabricated content length", async () => {
  const response = head(await exchange(request("/stream", "HEAD")));
  expect(response.status).toBe(200);
  expect(response.headers.has("content-length")).toBe(false);
  expect(response.headers.has("transfer-encoding")).toBe(false);
  expect(response.rest.length).toBe(0);
});

test("HTTP/1.0 streaming is rejected before sending the head", async () => {
  const response = head(await exchange(request("/stream", "GET", "1.0")));
  expect(response.status).toBe(505);
  expect(response.headers.has("transfer-encoding")).toBe(false);
  expect(response.rest.length).toBe(0);
});

for (const code of [103, 204, 205, 304]) {
  test(`status ${code} suppresses the producer and body`, async () => {
    const response = head(await exchange(request(`/status?code=${code}`)));
    expect(response.status).toBe(code);
    expect(response.headers.has("transfer-encoding")).toBe(false);
    expect(response.headers.get("content-length")).toBe(code === 205 ? "0" : null);
    expect(response.rest.length).toBe(0);
  });
}

test("middleware replacements discard the selected stream", async () => {
  const response = head(await exchange(request("/replace")));
  expect(response.headers.has("transfer-encoding")).toBe(false);
  expect(response.headers.has("x-bendo-stream-internal")).toBe(false);
  expect(response.rest.toString()).toBe("replacement");
});

for (const path of ["/invalid", "/oversize"]) {
  test(`${path} aborts before sending an invalid chunk`, async () => {
    const response = head(await exchange(request(path)));
    expect(response.status).toBe(200);
    expect(response.rest.length).toBe(0);
  });
}

test("duplicate registration fails without exposing either producer", async () => {
  const response = head(await exchange(request("/duplicate")));
  expect(response.status).toBe(500);
  expect(response.headers.has("transfer-encoding")).toBe(false);
  expect(response.rest.length).toBe(0);
});

test("sends a chunk before the producer finishes", async () => {
  const result = await new Promise<{ first: number; last: number; body: Buffer }>(
    (resolve, reject) => {
      const socket = connect(Number(new URL(server.url).port), "127.0.0.1");
      const parts: Buffer[] = [];
      let first = 0;
      socket.setTimeout(5000, () => socket.destroy(new Error("progressive stream timeout")));
      socket.on("connect", () => socket.write(request("/delayed")));
      socket.on("data", (part: Buffer) => {
        parts.push(part);
        const received = Buffer.concat(parts);
        const end = received.indexOf("\r\n\r\n");
        if (first === 0 && end >= 0 && received.length > end + 4) first = Date.now();
        if (
          end >= 0 &&
          received.length > end + 9 &&
          received.subarray(-5).toString() === "0\r\n\r\n"
        ) {
          socket.destroy();
          resolve({ first, last: Date.now(), body: head(received).rest });
        }
      });
      socket.on("error", reject);
    },
  );
  expect(chunks(result.body).body.toString()).toBe("xxxx");
  expect(result.first).toBeGreaterThan(0);
  expect(result.last - result.first).toBeGreaterThanOrEqual(200);
});

// This opt-in runs on Boat, never on the shared development server.
test.skipIf(process.env.BENDO_STREAM_MEMORY !== "1")(
  "bounded memory for 1/100 MiB output and paused readers (Boat)",
  async () => {
    const run = Bun.spawn(
      ["timeout", "--foreground", "90s", "python3", "tests/stream-memory.py", binary],
      {
        stdout: "pipe",
        stderr: "pipe",
      },
    );
    const [output, errors, code] = await Promise.all([
      new Response(run.stdout).text(),
      new Response(run.stderr).text(),
      run.exited,
    ]);
    process.stdout.write(output);
    expect(errors).toBe("");
    expect(code).toBe(0);
  },
  SLOW_TEST_TIMEOUT_MS,
);

test("cleanup and after_response run in order, including suppression and failure", async () => {
  const run = Bun.spawn(
    ["timeout", "--foreground", "25s", "python3", "tests/stream-memory.py", binary, "--small"],
    { stdout: "pipe", stderr: "pipe" },
  );
  const [output, errors, code] = await Promise.all([
    new Response(run.stdout).text(),
    new Response(run.stderr).text(),
    run.exited,
  ]);
  expect(errors).toBe("");
  expect(code).toBe(0);
  expect(output).toContain("cleanup and after_response exactly once");
});

test("successful CONNECT takes precedence over 205 length framing", async () => {
  const run = Bun.spawn(["timeout", "5s", connectBinary], { stdout: "pipe", stderr: "pipe" });
  const [output, errors, code] = await Promise.all([
    new Response(run.stdout).text(),
    new Response(run.stderr).text(),
    run.exited,
  ]);
  expect(errors).toBe("");
  expect(code).toBe(0);
  expect(output.trim()).toBe("connect205:");
});

test.skipIf(process.platform !== "linux")(
  "clock failure cancels the stream before sending a zero-length 500",
  async () => {
    const run = Bun.spawn(
      [
        "timeout",
        "--foreground",
        "10s",
        "python3",
        "tests/stream-memory.py",
        binary,
        "--clock-fail",
        clockShim,
      ],
      { stdout: "pipe", stderr: "pipe" },
    );
    const [output, errors, code] = await Promise.all([
      new Response(run.stdout).text(),
      new Response(run.stderr).text(),
      run.exited,
    ]);
    expect(errors).toBe("");
    expect(code).toBe(0);
    expect(output).toContain("stream cancelled before head, pipeline intact");
  },
);
