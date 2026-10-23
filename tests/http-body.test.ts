import { afterAll, describe, expect, test } from "bun:test";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { findBend } from "../packages/bendo/src/bend.ts";
import { connect } from "node:net";
import { build, start } from "./harness.ts";

const binary = build("tests/fixtures/http-body/server.bend");
const server = await start(binary);
afterAll(() => server[Symbol.asyncDispose]());

// The promise resolves only on EOF, so every status assertion also establishes
// connection closure. Timeouts and reset-before-EOF are failures.
function exchange(
  parts: readonly (string | Uint8Array)[],
  url = server.url,
  expectContinue = false,
  halfClose = false,
): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    const received: Buffer[] = [];
    const socket = connect(Number(new URL(url).port), "127.0.0.1");
    socket.setNoDelay(true);
    socket.setTimeout(25000, () => socket.destroy(new Error("response did not reach EOF")));
    socket.on("error", reject);
    socket.on("data", (data: Buffer) => {
      received.push(data);
      if (expectContinue && Buffer.concat(received).includes("HTTP/1.1 100 Continue\r\n\r\n")) {
        expectContinue = false;
        for (const part of parts.slice(1)) socket.write(part);
      }
    });
    socket.on("end", () => {
      resolve(Buffer.concat(received));
      socket.destroy();
    });
    socket.on("connect", () => {
      if (expectContinue) {
        socket.write(parts[0] ?? "");
        return;
      }
      for (const part of parts) socket.write(part);
      if (halfClose) socket.end();
    });
  });
}
const head = (headers: string, version = "1.1") =>
  `POST / HTTP/${version}\r\nHost: x\r\n${headers}\r\n`;
function status(response: Buffer, code: number): void {
  expect(response.toString("latin1").split("\r\n")[0]).toBe(
    `HTTP/1.1 ${code} ${code === 200 ? "OK" : code === 413 ? "Content Too Large" : code === 417 ? "Expectation Failed" : "Bad Request"}`,
  );
  expect(response.toString("latin1").toLowerCase()).toContain("connection: close\r\n");
}
function body(response: Buffer): Buffer {
  return response.subarray(response.indexOf("\r\n\r\n") + 4);
}

describe("request body framing over real TCP", () => {
  const cases: readonly [string, string, number][] = [
    ["no framing has no body", head(""), 200],
    ["Content-Length only", head("Content-Length: 3\r\n") + "abc", 200],
    ["chunked only", head("Transfer-Encoding: chunked\r\n") + "3\r\nabc\r\n0\r\n\r\n", 200],
    ["TE plus CL", head("Transfer-Encoding: chunked\r\nContent-Length: 0\r\n"), 400],
    ["conflicting CL", head("Content-Length: 3\r\nContent-Length: 4\r\n"), 400],
    ["identical repeated CL", head("Content-Length: 3\r\nContent-Length: 3\r\n"), 400],
    ["comma CL", head("Content-Length: 3, 3\r\n"), 400],
    ["empty CL", head("Content-Length:\r\n"), 400],
    ["non-digit CL", head("Content-Length: 3x\r\n"), 400],
    ["negative CL", head("Content-Length: -1\r\n"), 400],
    ["plus CL", head("Content-Length: +3\r\n"), 400],
    ["internal whitespace CL", head("Content-Length: 1 2\r\n"), 400],
    ["surrounding OWS CL", head("Content-Length: \t3 \t\r\n") + "abc", 200],
    ["CL overflow", head("Content-Length: 4294967296\r\n"), 400],
    ["unknown TE", head("Transfer-Encoding: gzip\r\n"), 400],
    ["coding before chunked", head("Transfer-Encoding: gzip, chunked\r\n"), 400],
    ["chunked not last", head("Transfer-Encoding: chunked, gzip\r\n"), 400],
    ["repeated chunked", head("Transfer-Encoding: chunked, chunked\r\n"), 400],
    [
      "repeated TE fields",
      head("Transfer-Encoding: chunked\r\nTransfer-Encoding: chunked\r\n"),
      400,
    ],
    ["TE HTTP/1.0", head("Transfer-Encoding: chunked\r\n", "1.0"), 400],
    ["invalid hex", head("Transfer-Encoding: chunked\r\n") + "g\r\n", 400],
    ["empty size", head("Transfer-Encoding: chunked\r\n") + "\r\n", 400],
    ["size overflow", head("Transfer-Encoding: chunked\r\n") + "100000000\r\n", 400],
    ["size missing CRLF", head("Transfer-Encoding: chunked\r\n") + "1\nx", 400],
    ["data missing CRLF", head("Transfer-Encoding: chunked\r\n") + "1\r\nx!", 400],
    [
      "extension too long",
      head("Transfer-Encoding: chunked\r\n") + "1;" + "a".repeat(8193) + "\r\n",
      400,
    ],
    [
      "trailers too large",
      head("Transfer-Encoding: chunked\r\n") + "0\r\nX: " + "a".repeat(8193) + "\r\n\r\n",
      400,
    ],
    [
      "forbidden trailer",
      head("Transfer-Encoding: chunked\r\n") + "0\r\nContent-Length: 0\r\n\r\n",
      400,
    ],
    ["malformed trailer", head("Transfer-Encoding: chunked\r\n") + "0\r\nBad\r\n\r\n", 400],
    ["CL over default limit", head("Content-Length: 1048577\r\n"), 413],
    ["chunk exceeds limit before data", head("Transfer-Encoding: chunked\r\n") + "100001\r\n", 413],
    ["invalid extension", head("Transfer-Encoding: chunked\r\n") + "1;=oops\r\n", 400],
    [
      "repeated Expect",
      head("Expect: 100-continue\r\nExpect: 100-continue\r\nContent-Length: 3\r\n"),
      417,
    ],
    [
      "oversized Expect rejected without interim",
      head("Expect: 100-continue\r\nContent-Length: 1048577\r\n"),
      413,
    ],
    ["unknown Expect", head("Expect: kittens\r\nContent-Length: 3\r\n"), 417],
    [
      "HTTP/1.0 ignores Expect",
      head("Expect: kittens\r\nContent-Length: 3\r\n", "1.0") + "abc",
      200,
    ],
    ["zero body Expect", head("Expect: 100-continue\r\nContent-Length: 0\r\n"), 200],
  ];
  for (const [name, raw, code] of cases)
    test(name, async () => status(await exchange([raw]), code));
  const queuedRejections: readonly [string, string, number][] = [
    ["413 with 32 KiB queued", head("Content-Length: 1048577\r\n") + "x".repeat(32768), 413],
    ["413 with 2 MiB queued", head("Content-Length: 2097152\r\n") + "x".repeat(2097152), 413],
    [
      "TE plus CL with queued body",
      head("Transfer-Encoding: chunked\r\nContent-Length: 32768\r\n") + "x".repeat(32768),
      400,
    ],
    [
      "chunked oversize mid-stream with queued body",
      head("Transfer-Encoding: chunked\r\n") +
        "80000\r\n" +
        "x".repeat(524288) +
        "\r\n80001\r\n" +
        "x".repeat(32768),
      413,
    ],
  ];
  for (const [name, raw, code] of queuedRejections) {
    test(`queued rejection: ${name}`, async () => {
      // One write puts payload behind the rejected head/chunk size. Keep the
      // write side open: the server must bound teardown without client EOF.
      const response = await exchange([raw]);
      status(response, code);
      expect(response.toString("latin1").toLowerCase()).toContain("content-length: 0\r\n");
      expect(body(response)).toHaveLength(0);
    });
  }
  test("CL preserves all 256 octets", async () => {
    const bytes = Buffer.from(Array.from({ length: 256 }, (_, n) => n));
    const response = await exchange([head("Content-Length: 256\r\n"), bytes]);
    status(response, 200);
    expect(body(response)).toEqual(bytes);
  });
  test("chunk extensions and trailers decode", async () => {
    const response = await exchange([
      head("Transfer-Encoding: chunked\r\n") +
        '3;name=value;quoted="a b"\r\nabc\r\n2\r\nde\r\n0\r\nX-Checksum: ok\r\n\r\n',
    ]);
    status(response, 200);
    expect(body(response).toString()).toBe("abcde");
  });
  test("Expect waits for interim response before sending body", async () => {
    const response = await exchange(
      [head("Expect: 100-continue\r\nContent-Length: 3\r\n"), "abc"],
      server.url,
      true,
    );
    expect(response.toString()).toStartWith("HTTP/1.1 100 Continue\r\n\r\n");
    const final = response.subarray(25);
    status(final, 200);
    expect(body(final).toString()).toBe("abc");
  });
  test("body already received omits interim response", async () => {
    const response = await exchange([
      head("Expect: 100-continue\r\nContent-Length: 3\r\n") + "abc",
    ]);
    status(response, 200);
    expect(body(response).toString()).toBe("abc");
  });
  for (const truncated of [
    "POST / HTTP/1.1\r\n",
    head("Content-Length: 4\r\n") + "abc",
    head("Transfer-Encoding: chunked\r\n") + "1\r\nx\r",
    head("Transfer-Encoding: chunked\r\n") + "0\r\nX: y\r\n",
  ]) {
    test(`premature EOF ${JSON.stringify(truncated)}`, async () =>
      status(await exchange([truncated], server.url, false, true), 400));
  }
  test("cumulative decoded chunks cannot cross body limit", async () => {
    const response = await exchange([
      head("Transfer-Encoding: chunked\r\n"),
      "100000\r\n",
      Buffer.alloc(1048576, 120),
      "\r\n1\r\n",
    ]);
    status(response, 413);
  });
  test("chunked binary octets arrive intact", async () => {
    const bytes = Buffer.from(Array.from({ length: 256 }, (_, n) => n));
    const response = await exchange([
      head("Transfer-Encoding: chunked\r\n"),
      "100\r\n",
      bytes,
      "\r\n0\r\n\r\n",
    ]);
    status(response, 200);
    expect(body(response)).toEqual(bytes);
  });
  test("coalesced body does not count toward head limit", async () => {
    const prefix = head(`Content-Length: 100\r\nX-Pad: ${"a".repeat(65470)}\r\n`);
    expect(Buffer.byteLength(prefix)).toBeLessThanOrEqual(65536);
    const response = await exchange([prefix + "z".repeat(100)]);
    status(response, 200);
    expect(body(response).toString()).toBe("z".repeat(100));
  });
  test("5 MB in 1 KB writes arrives intact with larger limit", async () => {
    // Separate configured server, one connection, no load test.
    const prior = process.env.BODY_LIMIT;
    process.env.BODY_LIMIT = "6000000";
    let large;
    try {
      large = await start(binary);
    } finally {
      if (prior === undefined) delete process.env.BODY_LIMIT;
      else process.env.BODY_LIMIT = prior;
    }
    await using configured = large;
    const bytes = Buffer.alloc(5_000_000);
    for (let i = 0; i < bytes.length; i++) bytes[i] = i % 256;
    const parts: (string | Uint8Array)[] = [head(`Content-Length: ${bytes.length}\r\n`)];
    for (let i = 0; i < bytes.length; i += 1024) parts.push(bytes.subarray(i, i + 1024));
    const response = await exchange(parts, configured.url);
    status(response, 200);
    expect(body(response)).toEqual(bytes);
  }, 30000);
});

// A native TCP write can be coalesced. Feed the real compiled pure decoder
// at every boundary as well, including size digits, CRLF, data and trailers.
const directory = mkdtempSync(join(tmpdir(), "bendo-body-pure-"));
afterAll(() => rmSync(directory, { recursive: true, force: true }));
const output = join(directory, "body.mjs");
const bend = findBend();
if (bend.kind === "missing") throw new Error("bend is not installed");
const compiled = Bun.spawnSync(
  [bend.path, join(import.meta.dir, "fixtures/http-body/consumer.bend"), "-o", output],
  { stdout: "pipe", stderr: "pipe", timeout: 30000 },
);
if (compiled.exitCode !== 0)
  throw new Error(`decoder compilation failed: ${compiled.stdout}${compiled.stderr}`);
const loaded: unknown = await import(pathToFileURL(output).href);
if (typeof loaded !== "object" || loaded === null || !("default" in loaded))
  throw new Error("missing Bend module");
const api: unknown = loaded.default;
function exported(name: string): (...args: unknown[]) => unknown {
  if (typeof api !== "object" || api === null || !(name in api)) throw new Error(`missing ${name}`);
  const fn: unknown = Reflect.get(api, name);
  if (typeof fn !== "function") throw new Error(`invalid ${name}`);
  return (...args) => fn(...args);
}
type Octets = { $: "Nil" } | { $: "Con"; head: number; tail: Octets };
function octets(raw: string): Octets {
  let list: Octets = { $: "Nil" };
  for (let i = raw.length - 1; i >= 0; i--)
    list = { $: "Con", head: raw.charCodeAt(i), tail: list };
  return list;
}
function pair(value: unknown): { fst: unknown; snd: unknown } {
  if (typeof value !== "object" || value === null || !("fst" in value) || !("snd" in value))
    throw new Error("not a Bend pair");
  return { fst: value.fst, snd: value.snd };
}
const initial = exported("initial");
const feed = exported("feed");
const decode = exported("decode");
test("chunk decoder is independent of every split before completion", () => {
  const wire = '2;a="x y"\r\n\x00\xff\r\n3\r\nabc\r\n0\r\nX-Tag: ok\r\n\r\n';
  const expected = {
    $: "Decoded",
    body: octets("\x00\xffabc"),
    trailers: {
      $: "Con",
      head: { $: "Header", name: "x-tag", value: octets("ok") },
      tail: { $: "Nil" },
    },
    rest: octets("NEXT"),
  };
  expect(decode(octets(wire + "NEXT"), 5)).toEqual(expected);
  for (let split = 0; split < wire.length; split++) {
    const first = pair(feed(octets(wire.slice(0, split)), initial(5)));
    expect(first.snd).toEqual({ $: "NeedMore" });
    expect(pair(feed(octets(wire.slice(split) + "NEXT"), first.fst)).snd).toEqual(expected);
  }
  let state = initial(5);
  for (const c of wire.slice(0, -1)) {
    const next = pair(feed(octets(c), state));
    expect(next.snd).toEqual({ $: "NeedMore" });
    state = next.fst;
  }
  expect(pair(feed(octets("\nNEXT"), state)).snd).toEqual(expected);
});
