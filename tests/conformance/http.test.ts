import { afterAll, expect, test } from "bun:test";
import { build, start } from "../harness.ts";
import { closed, exchange, request, responses } from "./wire.ts";

const server = await start(build("tests/fixtures/http-conformance/server.bend"));
afterAll(() => server[Symbol.asyncDispose]());
const allOctets = Buffer.from(Array.from({ length: 256 }, (_, i) => i));
const fixed = (body: Buffer, close = true) => Buffer.concat([
  request({ path: "/echo", method: "POST", close, headers: `Content-Length: ${body.length}\r\n` }), body,
]);
const chunked = (body: Buffer, close = true) => Buffer.concat([
  request({ path: "/chunked", method: "POST", close, headers: "Transfer-Encoding: chunked\r\n" }),
  Buffer.from(`${body.length.toString(16)};foo="bar"\r\n`), body,
  Buffer.from("\r\n0\r\nX-Trailer: ignored\r\n\r\n"),
]);

test("every byte split of representative requests preserves framing and content", async () => {
  const cases = [
    { wire: request(), method: "GET", body: Buffer.from("conformance") },
    { wire: request({ method: "HEAD" }), method: "HEAD", body: Buffer.alloc(0) },
    { wire: fixed(Buffer.from("a\0\r\n\xff", "latin1")), method: "POST", body: Buffer.from("a\0\r\n\xff", "latin1") },
    { wire: chunked(Buffer.from("a\0\r\n\xff", "latin1")), method: "POST", body: Buffer.from("a\0\r\n\xff", "latin1") },
    { wire: request({ headers: "X-One: a\r\nX-One: b\r\nX-Obs: \xff\r\n" }), method: "GET", body: Buffer.from("conformance") },
  ];
  let splits = 0;
  for (const item of cases) {
    for (let split = 0; split <= item.wire.length; split++) {
      const parsed = responses(await exchange({ url: server.url, parts: [item.wire.subarray(0, split), item.wire.subarray(split)], pauseMs: 2 }), [item.method]);
      expect(parsed).toHaveLength(1);
      expect(parsed[0]?.status).toBe(200);
      expect(parsed[0]?.body).toEqual(item.body);
      expect(parsed[0]?.headers.get("connection")).toBe("close");
      splits++;
    }
  }
  console.info(`conformance: ${splits} timed TCP split positions`);
}, 30000);

test("all 256 body octets survive fixed/chunked framing and sampled large-body splits", async () => {
  for (const encode of [fixed, chunked]) {
    const body = Buffer.concat(Array.from({ length: 16 }, () => allOctets));
    const wire = encode(body);
    const headEnd = wire.indexOf("\r\n\r\n") + 4;
    const boundaries = new Set([0, wire.length, headEnd, headEnd + 1, headEnd + 255, headEnd + 256, headEnd + 2048, headEnd + 4095]);
    for (const split of boundaries) {
      const parsed = responses(await exchange({ url: server.url, parts: [wire.subarray(0, split), wire.subarray(split)], pauseMs: 2 }));
      expect(parsed).toHaveLength(1);
      expect(parsed[0]?.body).toEqual(body);
    }
  }
});

test("3 through 10 mixed requests per pipeline retain order and HEAD representation length", async () => {
  for (let count = 3; count <= 10; count++) {
    const wires: Buffer[] = [];
    const methods: string[] = [];
    const expected: Buffer[] = [];
    for (let i = 0; i < count; i++) {
      const close = i === count - 1;
      switch (i % 4) {
        case 0: wires.push(fixed(allOctets, close)); methods.push("POST"); expected.push(allOctets); break;
        case 1: wires.push(chunked(Buffer.from(`chunk-${i}`), close)); methods.push("POST"); expected.push(Buffer.from(`chunk-${i}`)); break;
        case 2: wires.push(request({ method: "HEAD", close })); methods.push("HEAD"); expected.push(Buffer.alloc(0)); break;
        case 3: wires.push(request({ close })); methods.push("GET"); expected.push(Buffer.from("conformance")); break;
      }
    }
    const parsed = await closed(server.url, Buffer.concat(wires), methods);
    expect(parsed.map((r) => r.body)).toEqual(expected);
    expect(parsed.map((r) => r.status)).toEqual(Array.from({ length: count }, () => 200));
    for (const [index, response] of parsed.entries()) {
      if (methods[index] === "HEAD") expect(response.headers.get("content-length")).toBe("11");
      if (index < count - 1) expect(response.headers.has("connection")).toBe(false);
    }
  }
});

const invalid = [
  "garbage\r\n\r\n", "GET / HTTP/2.0\r\n\r\n", "GET  / HTTP/1.1\r\n\r\n",
  "G(ET / HTTP/1.1\r\n\r\n", " / HTTP/1.1\r\n\r\n", "GET /%GG HTTP/1.1\r\n\r\n",
  "GET / HTTP/1.1\nHost: x\n\n", "GET / HTTP/1.1\rX", "GET /\0 HTTP/1.1\r\n\r\n",
  "GET / HTTP/1.1\r\nX: a\r\n folded\r\n\r\n",
  "GET / HTTP/1.1\r\nX : a\r\n\r\n",
];
const smuggling = [
  "Content-Length: 5\r\nTransfer-Encoding: chunked\r\n",
  "Transfer-Encoding: chunked\r\nContent-Length: 5\r\n",
  "Transfer-Encoding: chunked, chunked\r\n",
  "Transfer-Encoding: xchunked\r\n",
  "Transfer-Encoding: chunked\r\nTransfer-Encoding: chunked\r\n",
  "Transfer-Encoding : chunked\r\n", "Transfer-Encoding:\tchunked\r\nContent-Length: 0\r\n",
  "Transfer-Encoding: chunked\r\n Transfer-Encoding: chunked\r\n",
  "Content-Length: 1\r\nContent-Length: 2\r\n",
];
test("malformed heads and smuggling attempts reject and close before a queued request", async () => {
  for (const bad of [...invalid.map((s) => Buffer.from(s)), ...smuggling.map((headers) => Buffer.concat([
    request({ path: "/echo", method: "POST", headers, close: false }), Buffer.from("0\r\n\r\n"),
  ]))]) {
    const result = await closed(server.url, Buffer.concat([bad, request()]));
    expect(result).toHaveLength(1);
    expect(result[0]?.status).toBe(400);
    expect(result[0]?.body.length).toBe(0);
  }
});

test("exact head budget, one byte over, leading CRLF and many short headers", async () => {
  const base = request({ headers: "X-Pad: \r\n" });
  for (const size of [8192, 8193]) {
    const wire = request({ headers: `X-Pad: ${"a".repeat(size - base.length)}\r\n` });
    expect(wire.length).toBe(size);
    expect((await closed(server.url, wire))[0]?.status).toBe(size === 8192 ? 200 : 431);
  }
  const many = request({ path: "/summary", method: "POST", headers: "X: a\r\n".repeat(300) });
  const summary = (await closed(server.url, many))[0];
  expect(summary?.status).toBe(200);
  expect(summary?.headers.get("x-header-count")).toBe("302");
  for (const wire of [request({ headers: "X: a\r\n".repeat(1400) }), Buffer.concat([Buffer.from("\r\n".repeat(4097)), request()])])
    expect((await closed(server.url, wire))[0]?.status).toBe(431);
});

test("one byte per 100 ms cannot extend head/body deadlines or block fast clients", async () => {
  const slowHead = exchange({ url: server.url, parts: Array.from(Buffer.from("GET / HTTP/1.1"), (n) => Buffer.from([n])), pauseMs: 100, halfClose: false });
  const slowBody = exchange({ url: server.url, parts: [request({ path: "/echo", method: "POST", headers: "Content-Length: 100\r\n" }), ...Array.from({ length: 14 }, () => Buffer.from("x"))], pauseMs: 100, halfClose: false });
  const fast = await closed(server.url, request());
  expect(fast[0]?.body.toString()).toBe("conformance");
  for (const wire of await Promise.all([slowHead, slowBody])) {
    const parsed = responses(wire);
    expect(parsed).toHaveLength(1);
    expect(parsed[0]?.status).toBe(408);
    expect(parsed[0]?.headers.get("connection")).toBe("close");
  }
});

test("incomplete head, fixed body and chunks at EOF reject with framed 400", async () => {
  for (const wire of [Buffer.from("GET / HTTP/1.1\r"), fixed(allOctets).subarray(0, -1), chunked(allOctets).subarray(0, -1)])
    expect((await closed(server.url, wire))[0]?.status).toBe(400);
});

test("independent response oracle rejects ambiguous and truncated responses", () => {
  for (const wire of ["HTTP/1.1 200 OK\r\n\r\n", "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\na", "HTTP/1.1 200 OK\r\nContent-Length: 0\r\nContent-Length: 0\r\n\r\n", "HTTP/1.1 204 No Content\r\nContent-Length: 0\r\n\r\n", "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\nextra"])
    expect(() => responses(Buffer.from(wire))).toThrow();
});
