import { afterAll, describe, expect, test } from "bun:test";
import { build, start } from "../harness.ts";
import { closed, exchange, framedResponses, request, responses } from "./wire.ts";

// One server for the whole suite. Its limits (tests/fixtures/http-conformance)
// are 16 KiB bodies, 8 KiB heads, 500 ms idle and 700 ms head/body deadlines.
const server = await start(build("tests/fixtures/http-conformance/server.bend"));
afterAll(() => server[Symbol.asyncDispose]());

const allOctets = Buffer.from(Array.from({ length: 256 }, (_, i) => i));
const tricky = Buffer.from("a\0\r\n\n\r\xff", "latin1");
const fixed = (body: Buffer, close = true) =>
  Buffer.concat([
    request({
      path: "/echo",
      method: "POST",
      close,
      headers: `Content-Length: ${body.length}\r\n`,
    }),
    body,
  ]);
const chunked = (body: Buffer, close = true) =>
  Buffer.concat([
    request({ path: "/chunked", method: "POST", close, headers: "Transfer-Encoding: chunked\r\n" }),
    Buffer.from(`${body.length.toString(16)};foo="bar"\r\n`),
    body,
    Buffer.from("\r\n0\r\nX-Trailer: ignored\r\n\r\n"),
  ]);
const bytewise = (wire: Buffer) => Array.from(wire, (octet) => Buffer.from([octet]));

const representative = [
  { name: "GET", wire: request(), method: "GET", body: Buffer.from("conformance") },
  { name: "HEAD", wire: request({ method: "HEAD" }), method: "HEAD", body: Buffer.alloc(0) },
  { name: "Content-Length", wire: fixed(tricky), method: "POST", body: tricky },
  { name: "chunked", wire: chunked(tricky), method: "POST", body: tricky },
  {
    name: "repeated and obs-text headers",
    wire: request({ headers: "X-One: a\r\nX-One: b\r\nX-Obs: \xff\r\n" }),
    method: "GET",
    body: Buffer.from("conformance"),
  },
  {
    name: "leading CRLF",
    wire: Buffer.concat([Buffer.from("\r\n\r\n"), request()]),
    method: "GET",
    body: Buffer.from("conformance"),
  },
];

describe("split reads", () => {
  for (const item of representative)
    test(`${item.name}: every two-part split and one write per byte`, async () => {
      const writes = [
        ...Array.from({ length: item.wire.length + 1 }, (_, split) => [
          item.wire.subarray(0, split),
          item.wire.subarray(split),
        ]),
        bytewise(item.wire),
      ];
      const outputs = await Promise.all(
        writes.map((parts) => exchange({ url: server.url, parts, pauseMs: 2, deadlineMs: 10_000 })),
      );
      for (const output of outputs) {
        const parsed = responses(output, [item.method]);
        expect(parsed).toHaveLength(1);
        expect(parsed[0]?.status).toBe(200);
        expect(parsed[0]?.body).toEqual(item.body);
        expect(parsed[0]?.headers.get("connection")).toBe("close");
      }
    });

  test("4 KiB bodies of all 256 octets at sampled splits", async () => {
    const body = Buffer.concat(Array.from({ length: 16 }, () => allOctets));
    for (const encode of [fixed, chunked]) {
      const wire = encode(body);
      const headEnd = wire.indexOf("\r\n\r\n") + 4;
      const splits = new Set([0, headEnd - 1, headEnd, headEnd + 1, headEnd + 255]);
      for (const split of [headEnd + 256, headEnd + 2048, headEnd + 4095, wire.length - 1])
        splits.add(split);
      for (const split of splits) {
        const parsed = responses(
          await exchange({
            url: server.url,
            parts: [wire.subarray(0, split), wire.subarray(split)],
            pauseMs: 2,
          }),
        );
        expect(parsed).toHaveLength(1);
        expect(parsed[0]?.body).toEqual(body);
      }
    }
  });
});

describe("binary bodies", () => {
  test("every octet, CR, LF and CRLF CRLF inside bodies echo exactly", async () => {
    const bodies = [
      allOctets,
      Buffer.from("\r\n\r\nGET / HTTP/1.1\r\n\r\n"),
      Buffer.from("\n\n\r\r"),
    ];
    for (const body of bodies)
      for (const wire of [fixed(body), chunked(body)]) {
        const parsed = await closed(server.url, wire);
        expect(parsed).toHaveLength(1);
        expect(parsed[0]?.body).toEqual(body);
      }
  });

  test("several chunks rebuild the body and trailers never become headers", async () => {
    const wire = Buffer.concat([
      request({ path: "/summary", method: "POST", headers: "Transfer-Encoding: chunked\r\n" }),
      Buffer.from('1\r\n\0\r\n2;a=b;c="d"\r\n\r\n\r\nFF\r\n'),
      allOctets.subarray(0, 255),
      Buffer.from("\r\n0\r\nX-Smuggled: 1\r\nX-Other: 2\r\n\r\n"),
    ]);
    const parsed = await closed(server.url, wire);
    expect(parsed[0]?.body).toEqual(
      Buffer.concat([Buffer.from("\0\r\n"), allOctets.subarray(0, 255)]),
    );
    expect(parsed[0]?.headers.get("x-header-count")).toBe("3");
  });

  test("bodies above the 16 KiB limit get 413 and close", async () => {
    const over = Buffer.alloc(16385, 7);
    for (const wire of [fixed(over), chunked(over)]) {
      const parsed = await closed(server.url, Buffer.concat([wire, request()]));
      expect(parsed.map((r) => r.status)).toEqual([413]);
    }
    expect((await closed(server.url, fixed(Buffer.alloc(16384, 7))))[0]?.status).toBe(200);
  });
});

describe("pipelining", () => {
  test("3 through 10 mixed requests per write keep order and HEAD lengths", async () => {
    for (let count = 3; count <= 10; count++) {
      const wires: Buffer[] = [];
      const methods: string[] = [];
      const expected: Buffer[] = [];
      for (let i = 0; i < count; i++) {
        const close = i === count - 1;
        const body = Buffer.from(`chunk-${count}-${i}`);
        switch (i % 4) {
          case 0:
            wires.push(fixed(allOctets, close));
            methods.push("POST");
            expected.push(allOctets);
            break;
          case 1:
            wires.push(chunked(body, close));
            methods.push("POST");
            expected.push(body);
            break;
          case 2:
            wires.push(request({ method: "HEAD", close }));
            methods.push("HEAD");
            expected.push(Buffer.alloc(0));
            break;
          default:
            wires.push(request({ close }));
            methods.push("GET");
            expected.push(Buffer.from("conformance"));
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

  test("a pipeline split at every request boundary and mid-head answers in order", async () => {
    const wire = Buffer.concat([
      fixed(Buffer.from("one"), false),
      chunked(Buffer.from("two"), false),
      request({ method: "HEAD", close: false }),
      request(),
    ]);
    const outputs = await Promise.all(
      Array.from({ length: wire.length + 1 }, (_, split) =>
        exchange({
          url: server.url,
          parts: [wire.subarray(0, split), wire.subarray(split)],
          pauseMs: 2,
          deadlineMs: 10_000,
        }),
      ),
    );
    for (const output of outputs) {
      const parsed = responses(output, ["POST", "POST", "HEAD", "GET"]);
      expect(parsed.map((r) => r.body.toString())).toEqual(["one", "two", "", "conformance"]);
    }
  });

  test("an error mid-pipeline answers earlier requests, then closes without dispatching later ones", async () => {
    const wire = Buffer.concat([
      request({ close: false }),
      fixed(Buffer.from("ok"), false),
      Buffer.from("GET /bad\0 HTTP/1.1\r\nHost: x\r\n\r\n"),
      request(),
    ]);
    const parsed = await closed(server.url, wire, ["GET", "POST", "GET"]);
    expect(parsed.map((r) => r.status)).toEqual([200, 200, 400]);
  });

  test("the 100th pipelined request closes and later requests are never answered", async () => {
    const wire = Buffer.concat(Array.from({ length: 105 }, () => request({ close: false })));
    const parsed = await closed(server.url, wire);
    expect(parsed).toHaveLength(100);
    expect(parsed.slice(0, 99).every((r) => !r.headers.has("connection"))).toBe(true);
  });

  test("a body and the next head in one write do not count toward the next head budget", async () => {
    const body = Buffer.alloc(8000, "b");
    const next = request({ headers: `X-Pad: ${"a".repeat(8100)}\r\n` }).subarray(0, 8192);
    const wire = Buffer.concat([
      fixed(body, false),
      next.subarray(0, next.length - 4),
      Buffer.from("\r\n\r\n"),
    ]);
    const parsed = await closed(server.url, wire, ["POST", "GET"]);
    expect(parsed.map((r) => r.status)).toEqual([200, 200]);
  });
});

describe("slow clients", () => {
  test("one byte per 100 ms cannot extend head or body deadlines or block fast clients", async () => {
    const started = Date.now();
    const slowHead = exchange({
      url: server.url,
      parts: bytewise(Buffer.from("GET / HTTP/1.1\r\nHost: x\r\n")),
      pauseMs: 100,
      halfClose: false,
    });
    const slowBody = exchange({
      url: server.url,
      parts: [
        request({ path: "/echo", method: "POST", headers: "Content-Length: 100\r\n" }),
        ...bytewise(Buffer.alloc(14, "x")),
      ],
      pauseMs: 100,
      halfClose: false,
    });
    for (let i = 0; i < 5; i++) {
      const fast = await closed(server.url, request());
      expect(fast[0]?.body.toString()).toBe("conformance");
    }
    const fastDone = Date.now() - started;
    for (const wire of await Promise.all([slowHead, slowBody])) {
      const parsed = responses(wire);
      expect(parsed.map((r) => r.status)).toEqual([408]);
    }
    // The slow clients take at least the 700 ms deadline; five fast requests finish first.
    expect(fastDone).toBeLessThan(Date.now() - started);
  });

  test("an idle keep-alive connection closes silently after its response", async () => {
    const output = await exchange({
      url: server.url,
      parts: [request({ close: false })],
      halfClose: false,
    });
    expect(responses(output).map((r) => r.status)).toEqual([200]);
  });
});

describe("oversized heads", () => {
  test("exactly the 8 KiB head budget passes and one more octet is 431", async () => {
    const base = request({ headers: "X-Pad: \r\n" });
    for (const size of [8192, 8193]) {
      const wire = request({ headers: `X-Pad: ${"a".repeat(size - base.length)}\r\n` });
      expect(wire.length).toBe(size);
      expect((await closed(server.url, wire))[0]?.status).toBe(size === 8192 ? 200 : 431);
    }
  });

  test("many short headers count toward the budget and are all kept", async () => {
    const many = request({ path: "/summary", method: "POST", headers: "X: a\r\n".repeat(300) });
    const summary = (await closed(server.url, many))[0];
    expect(summary?.status).toBe(200);
    expect(summary?.headers.get("x-header-count")).toBe("302");
    expect(
      (await closed(server.url, request({ headers: "X: a\r\n".repeat(1400) })))[0]?.status,
    ).toBe(431);
  });

  test("leading CRLFs, a long request line and one huge field all count", async () => {
    for (const wire of [
      Buffer.concat([Buffer.from("\r\n".repeat(4097)), request()]),
      request({ path: `/${"a".repeat(9000)}` }),
      request({ headers: `X: ${"a".repeat(9000)}\r\n` }),
    ]) {
      const parsed = await closed(server.url, Buffer.concat([wire, request()]));
      expect(parsed.map((r) => r.status)).toEqual([431]);
    }
  });
});

// Each malformed head is followed by a valid request in the same write. The
// server must answer 400, close, and never dispatch the queued request.
const malformed: readonly (readonly [string, string])[] = [
  ["garbage", "garbage\r\n\r\n"],
  ["HTTP/2.0", "GET / HTTP/2.0\r\n\r\n"],
  ["HTTP/1.2", "GET / HTTP/1.2\r\n\r\n"],
  ["lowercase version", "GET / http/1.1\r\n\r\n"],
  ["missing version", "GET /\r\n\r\n"],
  ["double space", "GET  / HTTP/1.1\r\n\r\n"],
  ["trailing space", "GET / HTTP/1.1 \r\n\r\n"],
  ["tab separator", "GET\t/ HTTP/1.1\r\n\r\n"],
  ["empty method", " / HTTP/1.1\r\n\r\n"],
  ["method with (", "G(ET / HTTP/1.1\r\n\r\n"],
  ["method with obs-text", "G\xc9T / HTTP/1.1\r\n\r\n"],
  ["method with DEL", "GE\x7fT / HTTP/1.1\r\n\r\n"],
  ["bad percent escape", "GET /%GG HTTP/1.1\r\n\r\n"],
  ["fragment", "GET /a#b HTTP/1.1\r\n\r\n"],
  ["backslash", "GET /a\\b HTTP/1.1\r\n\r\n"],
  ["raw non-ASCII target", "GET /\xe9 HTTP/1.1\r\n\r\n"],
  ["NUL in target", "GET /\0 HTTP/1.1\r\n\r\n"],
  ["bare LF", "GET / HTTP/1.1\nHost: x\n\n"],
  ["bare LF after a header", "GET / HTTP/1.1\r\nHost: x\n\r\n"],
  ["CR without LF", "GET / HTTP/1.1\rX\r\n\r\n"],
  ["obs-fold", "GET / HTTP/1.1\r\nX: a\r\n folded\r\n\r\n"],
  ["tab obs-fold", "GET / HTTP/1.1\r\nX: a\r\n\tfolded\r\n\r\n"],
  ["space before colon", "GET / HTTP/1.1\r\nX : a\r\n\r\n"],
  ["empty field name", "GET / HTTP/1.1\r\n: a\r\n\r\n"],
  ["no colon", "GET / HTTP/1.1\r\nHost\r\n\r\n"],
  ["NUL in value", "GET / HTTP/1.1\r\nX: a\0b\r\n\r\n"],
  ["DEL in value", "GET / HTTP/1.1\r\nX: a\x7fb\r\n\r\n"],
  ["CR in value", "GET / HTTP/1.1\r\nX: a\rb\r\n\r\n"],
  ["space in field name", "GET / HTTP/1.1\r\nX Y: a\r\n\r\n"],
];

// Ambiguous framing from decision 0005. Each is a smuggling vector behind a
// proxy that picks the other interpretation.
const ambiguous: readonly (readonly [string, string, string])[] = [
  ["CL then TE", "Content-Length: 5\r\nTransfer-Encoding: chunked\r\n", "0\r\n\r\n"],
  ["TE then CL", "Transfer-Encoding: chunked\r\nContent-Length: 5\r\n", "0\r\n\r\n"],
  ["TE with CL zero", "Transfer-Encoding: chunked\r\nContent-Length: 0\r\n", "0\r\n\r\n"],
  ["conflicting CL", "Content-Length: 1\r\nContent-Length: 2\r\n", "ab"],
  ["identical repeated CL", "Content-Length: 2\r\nContent-Length: 2\r\n", "ab"],
  ["comma CL", "Content-Length: 2, 2\r\n", "ab"],
  ["signed CL", "Content-Length: +2\r\n", "ab"],
  ["negative CL", "Content-Length: -1\r\n", "ab"],
  ["hex CL", "Content-Length: 0x2\r\n", "ab"],
  ["spaced CL", "Content-Length: 1 1\r\n", "ab"],
  ["empty CL", "Content-Length: \r\n", "ab"],
  ["CL above U32", "Content-Length: 4294967298\r\n", "ab"],
  ["CL 2^64 + 2", "Content-Length: 18446744073709551618\r\n", "ab"],
  ["chunked chunked", "Transfer-Encoding: chunked, chunked\r\n", "0\r\n\r\n"],
  ["repeated TE", "Transfer-Encoding: chunked\r\nTransfer-Encoding: chunked\r\n", "0\r\n\r\n"],
  ["unknown coding", "Transfer-Encoding: xchunked\r\n", "0\r\n\r\n"],
  ["gzip then chunked", "Transfer-Encoding: gzip, chunked\r\n", "0\r\n\r\n"],
  ["chunked not last", "Transfer-Encoding: chunked, gzip\r\n", "0\r\n\r\n"],
  ["identity coding", "Transfer-Encoding: identity\r\n", "0\r\n\r\n"],
  ["empty TE", "Transfer-Encoding: \r\n", "0\r\n\r\n"],
  ["space before colon", "Transfer-Encoding : chunked\r\n", "0\r\n\r\n"],
  ["folded TE", "Transfer-Encoding: chunked\r\n Transfer-Encoding: chunked\r\n", "0\r\n\r\n"],
  ["vertical tab", "Transfer-Encoding: \x0bchunked\r\n", "0\r\n\r\n"],
  ["invalid chunk size", "Transfer-Encoding: chunked\r\n", "g\r\n\r\n"],
  ["0x chunk size", "Transfer-Encoding: chunked\r\n", "0x1\r\na\r\n0\r\n\r\n"],
  ["empty chunk size", "Transfer-Encoding: chunked\r\n", "\r\n\r\n"],
  ["chunk size above U32", "Transfer-Encoding: chunked\r\n", "100000000\r\n"],
  ["chunk size with space", "Transfer-Encoding: chunked\r\n", "1 1\r\n"],
  ["bare LF after size", "Transfer-Encoding: chunked\r\n", "1\na\r\n0\r\n\r\n"],
  ["data longer than size", "Transfer-Encoding: chunked\r\n", "1\r\nab\r\n0\r\n\r\n"],
  ["bad extension", "Transfer-Encoding: chunked\r\n", "1;=x\r\na\r\n0\r\n\r\n"],
  ["Content-Length trailer", "Transfer-Encoding: chunked\r\n", "0\r\nContent-Length: 5\r\n\r\n"],
  ["folded trailer", "Transfer-Encoding: chunked\r\n", "0\r\nX: a\r\n b\r\n\r\n"],
];

describe("rejection", () => {
  for (const [name, wire] of malformed)
    test(`malformed: ${name}`, async () => {
      const parsed = await closed(
        server.url,
        Buffer.concat([Buffer.from(wire, "latin1"), request()]),
      );
      expect(parsed.map((r) => r.status)).toEqual([400]);
      expect(parsed[0]?.body.length).toBe(0);
    });

  for (const [name, headers, body] of ambiguous)
    test(`ambiguous framing: ${name}`, async () => {
      const wire = Buffer.concat([
        request({ path: "/echo", method: "POST", headers, close: false }),
        Buffer.from(body, "latin1"),
        request(),
      ]);
      const parsed = await closed(server.url, wire);
      expect(parsed.map((r) => r.status)).toEqual([400]);
      expect(parsed[0]?.body.length).toBe(0);
    });

  test("any Transfer-Encoding in HTTP/1.0 is rejected", async () => {
    const wire = Buffer.from(
      "POST /echo HTTP/1.0\r\nTransfer-Encoding: chunked\r\n\r\n0\r\n\r\n",
      "latin1",
    );
    expect((await closed(server.url, Buffer.concat([wire, request()])))[0]?.status).toBe(400);
  });

  test("an incomplete head, fixed body or chunk at EOF gets a framed 400", async () => {
    for (const wire of [
      Buffer.from("GET / HTTP/1.1\r"),
      Buffer.from("GET / HTTP/1.1\r\nHost: x\r\n"),
      fixed(allOctets).subarray(0, -1),
      chunked(allOctets).subarray(0, -1),
    ])
      expect((await closed(server.url, wire))[0]?.status).toBe(400);
  });
});

describe("response oracle", () => {
  test("rejects ambiguous, truncated and unclosed responses", () => {
    for (const wire of [
      "HTTP/1.1 200 OK\r\n\r\n",
      "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\na",
      "HTTP/1.1 200 OK\r\nContent-Length: 0\r\nContent-Length: 0\r\n\r\n",
      "HTTP/1.1 204 No Content\r\nContent-Length: 0\r\n\r\n",
      "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\nextra",
      "HTTP/1.1 200 OK\r\nContent-Length: 0\r\nTransfer-Encoding: chunked\r\n\r\n",
      "HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\n\r\n",
      "HTTP/1.1 200 OK\r\nContent-Length: 0\r\nConnection: close\r\n\r\nHTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n",
    ]) {
      expect(() => responses(Buffer.from(wire))).toThrow();
      expect(() => framedResponses(Buffer.from(wire))).toThrow();
    }
  });

  test("the method-blind oracle resolves HEAD and GET framings", () => {
    const get = "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nhi";
    const head = "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\n";
    expect(framedResponses(Buffer.from(head + get + head)).map((r) => r.body.toString())).toEqual([
      "",
      "hi",
      "",
    ]);
  });
});
