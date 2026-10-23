import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { connect } from "node:net";
import { findBend } from "../packages/bendo/src/bend.ts";
import { start, type RunningServer } from "./harness.ts";

type BendList<T> = { $: "Nil" } | { $: "Con"; head: T; tail: BendList<T> };
function list<T>(values: readonly T[]): BendList<T> {
  let result: BendList<T> = { $: "Nil" };
  for (const value of values.toReversed()) result = { $: "Con", head: value, tail: result };
  return result;
}
function bytes(value: unknown): Buffer {
  const result: number[] = [];
  let node = value;
  while (typeof node === "object" && node !== null && "$" in node) {
    if (node.$ === "Nil") return Buffer.from(result);
    if (
      node.$ !== "Con" ||
      !("head" in node) ||
      !("tail" in node) ||
      typeof node.head !== "number" ||
      !Number.isInteger(node.head) ||
      node.head < 0 ||
      node.head > 255
    )
      throw new Error("Invalid compiled Bend octet list");
    result.push(node.head);
    node = node.tail;
  }
  throw new Error("Invalid compiled Bend list");
}
const directory = mkdtempSync(join(tmpdir(), "bendo-http-response-"));
afterAll(() => rmSync(directory, { recursive: true, force: true }));
const output = join(directory, "response.mjs");
const bend = findBend();
if (bend.kind === "missing") throw new Error("bend is not installed");
const compilation = Bun.spawnSync(
  [
    "timeout",
    "--foreground",
    "30s",
    bend.path,
    join(import.meta.dir, "fixtures/http-response/consumer.bend"),
    "-o",
    output,
  ],
  { stdout: "pipe", stderr: "pipe" },
);
if (compilation.exitCode !== 0)
  throw new Error(`Bend compilation failed:\n${compilation.stdout}${compilation.stderr}`);
const module: unknown = await import(pathToFileURL(output).href);
if (typeof module !== "object" || module === null || !("default" in module))
  throw new Error("Missing Bend exports");
const api: unknown = module.default;
function exported(name: string): (...args: unknown[]) => unknown {
  if (typeof api !== "object" || api === null || !(name in api)) throw new Error(`Missing ${name}`);
  const fn: unknown = Reflect.get(api, name);
  if (typeof fn !== "function") throw new Error(`Not callable: ${name}`);
  return (...args) => fn(...args);
}
const write = exported("write");
const checked = exported("checked");
const utf8 = exported("utf8");
const text = exported("text");
const get = { $: "Get" };
const head = { $: "Head" };
function response(
  status: number,
  body: readonly number[] = [],
  headers: readonly { name: string; value: readonly number[] }[] = [],
  representation: readonly number[] | null = null,
) {
  return {
    $: "Res",
    status,
    headers: list(headers.map((h) => ({ $: "Header", name: h.name, value: list(h.value) }))),
    body: list(body),
    representation:
      representation === null ? { $: "None" } : { $: "Some", value: list(representation) },
  };
}
function wire(method: { $: string }, res: unknown): Buffer {
  return bytes(write(method, res));
}
function parts(raw: Buffer) {
  const delimiter = raw.indexOf("\r\n\r\n");
  if (delimiter < 0) throw new Error("No HTTP head delimiter");
  return { head: raw.subarray(0, delimiter).toString("latin1"), body: raw.subarray(delimiter + 4) };
}

// Independent expected phrases transcribed from the IANA registry. Lifecycle
// annotations for 104/510 are registry metadata, not reason-phrase text.
const reasons: Readonly<Record<number, string>> = {
  100: "Continue",
  101: "Switching Protocols",
  102: "Processing",
  103: "Early Hints",
  104: "Upload Resumption Supported",
  200: "OK",
  201: "Created",
  202: "Accepted",
  203: "Non-Authoritative Information",
  204: "No Content",
  205: "Reset Content",
  206: "Partial Content",
  207: "Multi-Status",
  208: "Already Reported",
  226: "IM Used",
  300: "Multiple Choices",
  301: "Moved Permanently",
  302: "Found",
  303: "See Other",
  304: "Not Modified",
  305: "Use Proxy",
  307: "Temporary Redirect",
  308: "Permanent Redirect",
  400: "Bad Request",
  401: "Unauthorized",
  402: "Payment Required",
  403: "Forbidden",
  404: "Not Found",
  405: "Method Not Allowed",
  406: "Not Acceptable",
  407: "Proxy Authentication Required",
  408: "Request Timeout",
  409: "Conflict",
  410: "Gone",
  411: "Length Required",
  412: "Precondition Failed",
  413: "Content Too Large",
  414: "URI Too Long",
  415: "Unsupported Media Type",
  416: "Range Not Satisfiable",
  417: "Expectation Failed",
  421: "Misdirected Request",
  422: "Unprocessable Content",
  423: "Locked",
  424: "Failed Dependency",
  425: "Too Early",
  426: "Upgrade Required",
  428: "Precondition Required",
  429: "Too Many Requests",
  431: "Request Header Fields Too Large",
  451: "Unavailable For Legal Reasons",
  500: "Internal Server Error",
  501: "Not Implemented",
  502: "Bad Gateway",
  503: "Service Unavailable",
  504: "Gateway Timeout",
  505: "HTTP Version Not Supported",
  506: "Variant Also Negotiates",
  507: "Insufficient Storage",
  508: "Loop Detected",
  510: "Not Extended",
  511: "Network Authentication Required",
};

describe("compiled buffered response writer", () => {
  test("every assigned status from 100 through 599 writes its standard reason phrase", () => {
    for (let status = 100; status <= 599; status++) {
      const firstLine = parts(wire(get, response(status))).head.split("\r\n")[0];
      expect(firstLine).toBe(`HTTP/1.1 ${status} ${reasons[status] ?? ""}`);
    }
  });
  test("UTF-8 encodes scalar boundaries once and lengths count octets", () => {
    for (const body of [
      "",
      "ASCII",
      "hé 🌍",
      "\0\u007f\u0080\u07ff\u0800\ud7ff\ue000\uffff\u{10000}\u{10ffff}",
      "\r\n\r\nbody",
    ]) {
      const expected = Buffer.from(body);
      expect(bytes(utf8(body))).toEqual(expected);
      const result = parts(wire(get, text(200, body)));
      expect(result.head).toBe(
        `HTTP/1.1 200 OK\r\ncontent-length: ${expected.length}\r\ncontent-type: text/plain; charset=utf-8`,
      );
      expect(result.body).toEqual(expected);
    }
  });
  test("binary bodies preserve all 256 octets and decimal length boundaries", () => {
    for (const n of [0, 1, 9, 10, 99, 100, 255, 256, 999, 1000]) {
      const body = Array.from({ length: n }, (_, i) => i % 256);
      const result = parts(wire(get, response(200, body)));
      expect(result.head).toBe(`HTTP/1.1 200 OK\r\ncontent-length: ${n}`);
      expect(result.body).toEqual(Buffer.from(body));
    }
  });
  test("HEAD has the GET head and no payload, across every status", () => {
    for (let status = 100; status <= 599; status++) {
      const res = response(status, [0, 255, 42], [], [1, 2, 3, 4]);
      expect(parts(wire(head, res))).toEqual({
        head: parts(wire(get, res)).head,
        body: Buffer.alloc(0),
      });
    }
  });
  test("1xx and 204 never carry content-length or content, even if supplied", () => {
    for (const status of [...Array.from({ length: 100 }, (_, i) => i + 100), 204]) {
      for (const method of [get, head, { $: "Post" }, { $: "Extension", token: "CUSTOM" }]) {
        const res = response(
          status,
          [1, 2],
          [
            { name: "content-length", value: [57] },
            { name: "transfer-encoding", value: Array.from(Buffer.from("chunked")) },
          ],
        );
        expect(parts(wire(method, res))).toEqual({
          head: `HTTP/1.1 ${status} ${reasons[status] ?? ""}`,
          body: Buffer.alloc(0),
        });
      }
    }
  });
  test("205 and successful CONNECT cannot carry an HTTP body", () => {
    expect(parts(wire(get, response(205, [42])))).toEqual({
      head: "HTTP/1.1 205 Reset Content\r\ncontent-length: 0",
      body: Buffer.alloc(0),
    });
    expect(parts(wire({ $: "Connect" }, response(200, [42])))).toEqual({
      head: "HTTP/1.1 200 OK",
      body: Buffer.alloc(0),
    });
    expect(parts(wire({ $: "Connect" }, response(404, [42]))).body).toEqual(Buffer.from([42]));
  });
  test("304 length is absent without a GET representation and exact with one", () => {
    expect(parts(wire(get, response(304, [42])))).toEqual({
      head: "HTTP/1.1 304 Not Modified",
      body: Buffer.alloc(0),
    });
    expect(parts(wire(get, response(304, [42], [], [1, 2, 3])))).toEqual({
      head: "HTTP/1.1 304 Not Modified\r\ncontent-length: 3",
      body: Buffer.alloc(0),
    });
  });
  test("writer owns framing and retains duplicate application headers in order", () => {
    const res = response(
      200,
      [120],
      [
        { name: "content-length", value: [57] },
        { name: "transfer-encoding", value: Array.from(Buffer.from("chunked")) },
        { name: "x-tag", value: [49] },
        { name: "x-tag", value: [50] },
      ],
    );
    expect(parts(wire(get, res)).head).toBe(
      "HTTP/1.1 200 OK\r\ncontent-length: 1\r\nx-tag: 1\r\nx-tag: 2",
    );
  });
  test("invalid responses are rejected; convenience fallback is method-aware", () => {
    const invalid = [
      response(99),
      response(600),
      response(200, [256]),
      response(304, [], [], [256]),
    ];
    for (const name of ["X-Tag", "", "x:y", "x\r\ny", "é"])
      invalid.push(response(200, [], [{ name, value: [] }]));
    for (const value of [[13], [10], [0], [127], [256]])
      invalid.push(response(200, [], [{ name: "x-tag", value }]));
    for (const res of invalid) {
      expect(checked(get, res)).toEqual({ $: "Fail", error: { $: "InvalidResponse" } });
      expect(wire(get, res).toString()).toBe(
        "HTTP/1.1 500 Internal Server Error\r\ncontent-length: 0\r\n\r\n",
      );
      expect(wire(head, res)).toEqual(wire(get, res));
    }
  });
});

let server: RunningServer;
beforeAll(async () => {
  const binary = join(directory, "server");
  const native = Bun.spawnSync(
    [
      "timeout",
      "--foreground",
      "30s",
      bend.path,
      join(import.meta.dir, "servers/response-server.bend"),
      "-o",
      binary,
    ],
    { stdout: "pipe", stderr: "pipe" },
  );
  if (native.exitCode !== 0)
    throw new Error(`Native Bend compilation failed:\n${native.stdout}${native.stderr}`);
  server = await start(binary);
});
afterAll(async () => {
  await server?.[Symbol.asyncDispose]();
});
async function raw(path: string, method = "GET"): Promise<Buffer> {
  const url = new URL(server.url);
  return new Promise((resolve, reject) => {
    const chunks: Buffer[] = [];
    const socket = connect({ host: url.hostname, port: Number(url.port) });
    socket.setTimeout(3000, () => socket.destroy(new Error("response timeout")));
    socket.on("connect", () => socket.write(`${method} ${path} HTTP/1.1\r\nHost: test\r\n\r\n`));
    socket.on("data", (chunk) =>
      chunks.push(typeof chunk === "string" ? Buffer.from(chunk) : chunk),
    );
    socket.on("end", () => resolve(Buffer.concat(chunks)));
    socket.on("error", reject);
  });
}
describe("native byte response server", () => {
  test("curl -i and raw sockets show exact 101/200/204/304/404 and HEAD heads", async () => {
    const cases = [
      {
        path: "/101",
        head: "HTTP/1.1 101 Switching Protocols\r\nupgrade: websocket\r\nconnection: Upgrade",
        body: "",
      },
      {
        path: "/200",
        head: "HTTP/1.1 200 OK\r\ncontent-length: 8\r\ncontent-type: text/plain; charset=utf-8",
        body: "hé 🌍",
      },
      {
        path: "/204",
        head: "HTTP/1.1 204 No Content\r\ncontent-type: text/plain; charset=utf-8",
        body: "",
      },
      { path: "/304", head: "HTTP/1.1 304 Not Modified", body: "" },
      { path: "/304-known", head: "HTTP/1.1 304 Not Modified\r\ncontent-length: 8", body: "" },
      {
        path: "/404",
        head: "HTTP/1.1 404 Not Found\r\ncontent-length: 9\r\ncontent-type: text/plain; charset=utf-8",
        body: "Not Found",
      },
    ];
    for (const c of cases) {
      expect(await raw(c.path)).toEqual(Buffer.from(`${c.head}\r\n\r\n${c.body}`));
      expect(await raw(c.path, "HEAD")).toEqual(Buffer.from(`${c.head}\r\n\r\n`));
      const curl = Bun.spawnSync([
        "curl",
        "--silent",
        "--show-error",
        "--max-time",
        "3",
        "-i",
        `${server.url}${c.path}`,
      ]);
      // curl treats a lone 101 followed by close as an empty final reply.
      expect(curl.exitCode).toBe(c.path === "/101" ? 52 : 0);
      expect(Buffer.from(curl.stdout)).toEqual(Buffer.from(`${c.head}\r\n\r\n${c.body}`));
    }
    const curl = Bun.spawnSync([
      "curl",
      "--silent",
      "--show-error",
      "--max-time",
      "3",
      "-I",
      `${server.url}/200`,
    ]);
    expect(curl.exitCode).toBe(0);
    expect(Buffer.from(curl.stdout).toString()).toBe(
      "HTTP/1.1 200 OK\r\ncontent-length: 8\r\ncontent-type: text/plain; charset=utf-8\r\n\r\n",
    );
  });
  test("raw wire preserves binary data and discards conflicting framing", async () => {
    expect(parts(await raw("/binary"))).toEqual({
      head: "HTTP/1.1 200 OK\r\ncontent-length: 8",
      body: Buffer.from([0, 255, 128, 13, 10, 13, 10, 42]),
    });
    expect(parts(await raw("/framing"))).toEqual({
      head: "HTTP/1.1 200 OK\r\ncontent-length: 1\r\nx-tag: one\r\nx-tag: two",
      body: Buffer.from("x"),
    });
    expect(parts(await raw("/invalid")).head).toBe(
      "HTTP/1.1 500 Internal Server Error\r\ncontent-length: 0",
    );
  });
});
