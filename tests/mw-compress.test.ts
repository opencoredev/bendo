// BND-46: gzip and deflate response compression, tested against the
// compiled tests/servers/compress.bend over real HTTP, and the zlib effect's
// native and JavaScript twins through tests/fixtures/compress/run.bend.
//
// Requests go through node:http, which neither adds Accept-Encoding nor
// decodes bodies, so every test sees the octets the server sent.
import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { request as httpRequest } from "node:http";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { gunzipSync, inflateSync } from "node:zlib";
import { build, compile, start, type RunningServer } from "./harness.ts";

const binary = build("tests/servers/compress.bend");
const runNative = compile("tests/fixtures/compress/run.bend", "native");
const runJs = compile("tests/fixtures/compress/run.bend", "js");

let server: RunningServer;
const scratch = mkdtempSync(join(tmpdir(), "bendo-compress-"));
beforeAll(async () => {
  server = await start(binary);
});
afterAll(async () => {
  await server[Symbol.asyncDispose]();
  rmSync(scratch, { recursive: true, force: true });
});

type Reply = { status: number; fields: Map<string, string>; body: Buffer };

function get({
  path,
  encoding,
  method = "GET",
  headers = {},
}: {
  path: string;
  encoding?: string;
  method?: "GET" | "HEAD";
  headers?: Record<string, string>;
}): Promise<Reply> {
  const url = new URL(path, server.url);
  const sent = encoding === undefined ? headers : { ...headers, "accept-encoding": encoding };
  return new Promise((resolve, reject) => {
    const req = httpRequest(url, { method, headers: sent, agent: false }, (res) => {
      const chunks: Buffer[] = [];
      res.on("data", (chunk: Buffer) => chunks.push(chunk));
      res.on("error", reject);
      res.on("end", () => {
        const fields = new Map<string, string>();
        for (const [name, value] of Object.entries(res.headers)) {
          if (value !== undefined)
            fields.set(name, Array.isArray(value) ? value.join(", ") : value);
        }
        resolve({ status: res.statusCode ?? 0, fields, body: Buffer.concat(chunks) });
      });
    });
    req.setTimeout(10_000, () => req.destroy(new Error(`request for ${path} timed out`)));
    req.on("error", reject);
    req.end();
  });
}

function decoded(reply: Reply): Buffer {
  const coding = reply.fields.get("content-encoding");
  switch (coding) {
    case undefined:
      return reply.body;
    case "gzip":
      return gunzipSync(reply.body);
    case "deflate":
      return inflateSync(reply.body);
    default:
      throw new Error(`unexpected content-encoding ${coding}`);
  }
}

function expectCompressed(reply: Reply, coding: "gzip" | "deflate"): void {
  expect(reply.status).toBe(200);
  expect(reply.fields.get("content-encoding")).toBe(coding);
  expect(reply.fields.get("vary")).toBe("Accept-Encoding");
  expect(reply.fields.get("content-length")).toBe(String(reply.body.length));
}

function expectIdentity(reply: Reply, { varied }: { varied: boolean }): void {
  expect(reply.fields.has("content-encoding")).toBe(false);
  expect(reply.fields.has("vary")).toBe(varied);
}

describe("negotiation", () => {
  test("curl --compressed decodes a gzip response", async () => {
    const identity = await get({ path: "/z/json" });
    const result = Bun.spawnSync(
      ["curl", "-sS", "--compressed", "-D", "-", `${server.url}/z/json`],
      {
        stdout: "pipe",
        stderr: "pipe",
        timeout: 20_000,
      },
    );
    expect(result.exitCode).toBe(0);
    const text = result.stdout.toString();
    const split = text.indexOf("\r\n\r\n");
    const head = text.slice(0, split).toLowerCase();
    expect(head).toContain("content-encoding: gzip");
    expect(head).toContain("vary: accept-encoding");
    expect(text.slice(split + 4)).toBe(identity.body.toString());
    expect(JSON.parse(text.slice(split + 4)).items.length).toBe(301);
  });

  test("gzip and deflate decode to the identity JSON and HTML bodies", async () => {
    for (const path of ["/z/json", "/z/html"]) {
      const identity = await get({ path });
      expect(identity.body.length).toBeGreaterThan(10_000);
      const gzip = await get({ path, encoding: "gzip" });
      expectCompressed(gzip, "gzip");
      expect(gzip.body.length).toBeLessThan(identity.body.length / 10);
      expect(gunzipSync(gzip.body).equals(identity.body)).toBe(true);
      const deflate = await get({ path, encoding: "deflate" });
      expectCompressed(deflate, "deflate");
      expect(inflateSync(deflate.body).equals(identity.body)).toBe(true);
      expect(deflate.fields.get("content-type")).toBe(identity.fields.get("content-type"));
    }
  });

  test("deflate is the zlib format, not raw deflate", async () => {
    const reply = await get({ path: "/z/html", encoding: "deflate" });
    const [cmf = 0, flg = 0] = reply.body;
    expect(cmf & 0x0f).toBe(8);
    expect((cmf * 256 + flg) % 31).toBe(0);
  });

  test("q-values, identity, wildcards and aliases", async () => {
    const cases: [string, "gzip" | "deflate" | "identity"][] = [
      ["gzip, deflate", "gzip"],
      ["deflate, gzip", "gzip"],
      ["deflate;q=0.9, gzip;q=0.8", "deflate"],
      ["gzip;q=0.5, deflate;q=0.5", "gzip"],
      ["gzip;q=0", "identity"],
      ["gzip;q=0, deflate", "deflate"],
      ["gzip;q=0.000, deflate;q=0", "identity"],
      ["*", "gzip"],
      ["*;q=0", "identity"],
      ["*;q=0.5, gzip;q=0", "deflate"],
      ["identity", "identity"],
      ["gzip;q=0.5, identity", "identity"],
      ["identity;q=0, gzip;q=0.1", "gzip"],
      ["x-gzip", "gzip"],
      ["GZIP;Q=1.000", "gzip"],
      ["gzip;q=1.5", "identity"],
      ["gzip;q=0.0001", "identity"],
      ["br, zstd", "identity"],
      ["", "identity"],
      [" gzip ; q=0.2 ,, deflate;q=0.1", "gzip"],
    ];
    for (const [encoding, expected] of cases) {
      const reply = await get({ path: "/z/html", encoding });
      const got = reply.fields.get("content-encoding") ?? "identity";
      expect(`${encoding} -> ${got}`).toBe(`${encoding} -> ${expected}`);
      expect(reply.fields.get("vary")).toBe("Accept-Encoding");
      expect(decoded(reply).toString()).toContain("Hello from Bendo");
    }
  });

  test("no Accept-Encoding gets identity with Vary", async () => {
    const reply = await get({ path: "/z/html" });
    expect(reply.status).toBe(200);
    expectIdentity(reply, { varied: true });
    expect(reply.fields.get("content-length")).toBe(String(reply.body.length));
  });

  test("repeated Accept-Encoding fields are read together", async () => {
    const raw = await rawRequest("/z/html", ["accept-encoding: br", "accept-encoding: deflate"]);
    expect(raw).toContain("content-encoding: deflate\r\n");
    expect(raw).toContain("vary: accept-encoding\r\n");
  });
});

describe("eligibility", () => {
  test("the threshold boundary: threshold-1 is identity, threshold is compressed", async () => {
    const below = await get({ path: "/z/size?n=1023", encoding: "gzip" });
    expectIdentity(below, { varied: false });
    expect(below.body.length).toBe(1023);
    const at = await get({ path: "/z/size?n=1024", encoding: "gzip" });
    expectCompressed(at, "gzip");
    expect(gunzipSync(at.body).toString()).toBe("a".repeat(1024));
  });

  test("a configured threshold and limit", async () => {
    expectIdentity(await get({ path: "/low/size?n=99", encoding: "gzip" }), { varied: false });
    expectCompressed(await get({ path: "/low/size?n=100", encoding: "gzip" }), "gzip");
    expectCompressed(await get({ path: "/tiny/size?n=2048", encoding: "gzip" }), "gzip");
    const over = await get({ path: "/tiny/size?n=2049", encoding: "gzip" });
    expectIdentity(over, { varied: false });
    expect(over.body.length).toBe(2049);
  });

  test("a level outside 1 to 9 is clamped and still decodes", async () => {
    const reply = await get({ path: "/fast/html", encoding: "gzip" });
    expectCompressed(reply, "gzip");
    expect(gunzipSync(reply.body).toString()).toContain("Hello from Bendo");
  });

  test("already-compressed media types are skipped, SVG is not", async () => {
    const png = await get({ path: "/z/png", encoding: "gzip" });
    expectIdentity(png, { varied: false });
    expect(png.body.length).toBe(4096);
    expectCompressed(await get({ path: "/z/svg", encoding: "gzip" }), "gzip");
  });

  test("an existing Content-Encoding is never encoded again", async () => {
    const reply = await get({ path: "/z/encoded", encoding: "gzip, br" });
    expect(reply.fields.get("content-encoding")).toBe("br");
    expect(reply.fields.has("vary")).toBe(false);
    expect(reply.body.length).toBe(4096);
  });

  test("HEAD sends the fields the same GET would, with no body", async () => {
    // RFC 9110 section 8.6: HEAD's Content-Length is the length GET sends.
    const offers: ReadonlyArray<{ encoding?: string }> = [
      { encoding: "gzip" },
      { encoding: "deflate" },
      {},
    ];
    for (const offer of offers) {
      const getReply = await get({ path: "/z/html", ...offer });
      const head = await get({ path: "/z/html", ...offer, method: "HEAD" });
      expect(head.status).toBe(200);
      expect(head.body.length).toBe(0);
      expect(head.fields.get("content-encoding")).toBe(getReply.fields.get("content-encoding"));
      expect(head.fields.get("vary")).toBe("Accept-Encoding");
      expect(head.fields.get("content-length")).toBe(String(getReply.body.length));
    }
    const coded = await get({ path: "/z/html", encoding: "gzip", method: "HEAD" });
    expect(coded.fields.get("content-encoding")).toBe("gzip");
    expect(Number(coded.fields.get("content-length"))).toBeLessThan(1000);
    const tagged = await get({ path: "/etagged/html", encoding: "gzip" });
    const taggedHead = await get({ path: "/etagged/html", encoding: "gzip", method: "HEAD" });
    expect(taggedHead.fields.get("etag")).toBe(tagged.fields.get("etag"));
    expect(taggedHead.fields.get("content-length")).toBe(String(tagged.body.length));
  });

  test("204, 206, no-transform and streamed responses are left alone", async () => {
    const empty = await get({ path: "/z/nocontent", encoding: "gzip" });
    expect(empty.status).toBe(204);
    expectIdentity(empty, { varied: false });
    const partial = await get({ path: "/z/partial", encoding: "gzip" });
    expect(partial.status).toBe(206);
    expectIdentity(partial, { varied: false });
    expect(partial.body.length).toBe(4096);
    const kept = await get({ path: "/z/notransform", encoding: "gzip" });
    expectIdentity(kept, { varied: false });
    const stream = await get({ path: "/z/stream", encoding: "gzip" });
    expect(stream.fields.get("transfer-encoding")).toBe("chunked");
    expectIdentity(stream, { varied: false });
    expect(stream.body.toString()).toBe("stream ".repeat(400).repeat(3));
  });

  test("a body zlib cannot shrink is sent as identity with Vary", async () => {
    const reply = await get({ path: "/z/random", encoding: "gzip" });
    expectIdentity(reply, { varied: true });
    expect(reply.body.length).toBe(4096);
  });

  test("routes without the middleware are untouched", async () => {
    expectIdentity(await get({ path: "/plain/html", encoding: "gzip" }), { varied: false });
  });
});

describe("headers", () => {
  test("Vary merges with an existing field", async () => {
    const reply = await get({ path: "/z/varied", encoding: "gzip" });
    expect(reply.fields.get("vary")).toBe("Origin, Accept-Encoding");
    expect(reply.fields.get("content-encoding")).toBe("gzip");
  });

  test("a strong ETag becomes weak, a weak one stays", async () => {
    expect((await get({ path: "/z/strong", encoding: "gzip" })).fields.get("etag")).toBe('W/"v1"');
    expect((await get({ path: "/z/strong" })).fields.get("etag")).toBe('"v1"');
    expect((await get({ path: "/z/weak", encoding: "gzip" })).fields.get("etag")).toBe('W/"v1"');
  });

  test("B.etag outside compression tags each coding and keeps Vary on 304", async () => {
    const gzip = await get({ path: "/etagged/html", encoding: "gzip" });
    expectCompressed(gzip, "gzip");
    const identity = await get({ path: "/etagged/html" });
    expectIdentity(identity, { varied: true });
    const tag = gzip.fields.get("etag") ?? "";
    expect(tag).toMatch(/^"/);
    expect(identity.fields.get("etag")).not.toBe(tag);
    const again = await get({
      path: "/etagged/html",
      encoding: "gzip",
      headers: { "if-none-match": tag },
    });
    expect(again.status).toBe(304);
    expect(again.body.length).toBe(0);
    expect(again.fields.get("vary")).toBe("Accept-Encoding");
    expect(again.fields.get("etag")).toBe(tag);
  });
});

describe("zlib effect twins", () => {
  function run(command: string[]): string {
    const result = Bun.spawnSync(command, { stdout: "pipe", stderr: "pipe", timeout: 30_000 });
    if (result.exitCode !== 0) throw new Error(`${command.join(" ")} failed: ${result.stderr}`);
    return result.stdout.toString().trim();
  }

  test("native and JavaScript output decode to the same input", async () => {
    const json = (await get({ path: "/z/json" })).body;
    const html = (await get({ path: "/z/html" })).body;
    const mixed = Buffer.from(Array.from({ length: 70_000 }, (_, i) => (i * 7 + (i >> 9)) % 256));
    for (const [name, input] of [
      ["json", json],
      ["html", html],
      ["mixed", mixed],
      ["empty", Buffer.alloc(0)],
    ] as const) {
      const file = join(scratch, name);
      writeFileSync(file, input);
      for (const [format, decode] of [
        ["1", gunzipSync],
        ["2", inflateSync],
      ] as const) {
        const native = `${file}.${format}.native`;
        const js = `${file}.${format}.js`;
        expect(run([runNative, format, "6", "1000000", file, native])).toBe("ok");
        expect(run([process.execPath, runJs, format, "6", "1000000", file, js])).toBe("ok");
        expect(decode(readFileSync(native)).equals(input)).toBe(true);
        expect(decode(readFileSync(js)).equals(input)).toBe(true);
      }
    }
  });

  test("both twins refuse an input over the limit and an unknown format", () => {
    const file = join(scratch, "limit");
    writeFileSync(file, "x".repeat(101));
    for (const command of [[runNative], [process.execPath, runJs]]) {
      expect(run([...command, "1", "6", "100", file, `${file}.out`])).toBe("fail 27");
      expect(run([...command, "3", "6", "1000", file, `${file}.out`])).toBe("fail 22");
      expect(run([...command, "1", "6", "101", file, `${file}.out`])).toBe("ok");
    }
  });
});

// A raw request, so a test can send the same field twice.
function rawRequest(path: string, fields: string[]): Promise<string> {
  const url = new URL(server.url);
  const chunks: Buffer[] = [];
  return new Promise((resolve, reject) => {
    const socket = Bun.connect({
      hostname: url.hostname,
      port: Number(url.port),
      socket: {
        open(s) {
          s.write(
            `GET ${path} HTTP/1.1\r\nhost: ${url.host}\r\n${fields.map((f) => `${f}\r\n`).join("")}connection: close\r\n\r\n`,
          );
        },
        data(_s, chunk) {
          chunks.push(Buffer.from(chunk));
        },
        close() {
          resolve(Buffer.concat(chunks).toString("latin1").toLowerCase());
        },
        error(_s, error) {
          reject(error);
        },
      },
    });
    socket.catch(reject);
  });
}
