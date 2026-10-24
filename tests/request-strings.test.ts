import { expect, test } from "bun:test";
import { pathToFileURL } from "node:url";
import { build, compile, SLOW_TEST_TIMEOUT_MS } from "./harness.ts";

const entry = "tests/fixtures/request-strings/consumer.bend";
const binary = build(entry);
const output = compile(entry, "mjs");
const module: unknown = await import(pathToFileURL(output).href);
if (typeof module !== "object" || module === null || !("default" in module)) {
  throw new Error("Missing request string exports");
}
const api: unknown = module.default;
function exported(name: string): (...args: unknown[]) => unknown {
  if (typeof api !== "object" || api === null) throw new Error("Invalid request string exports");
  const fn: unknown = Reflect.get(api, name);
  if (typeof fn !== "function") throw new Error(`Missing request string export: ${name}`);
  return (...args) => fn(...args);
}
const probe = exported("probe");
const size = 64 * 1024;
const ascii = "A".repeat(size);
const lower = "a".repeat(size);

type Vector = { name: string; mode: string; input: string; expected: number };
const vectors: Vector[] = [
  { name: "JSON scalar scan", mode: "json-scalars", input: ascii, expected: 1 },
  {
    name: "JSON quote expansion",
    mode: "json-quote",
    input: '"'.repeat(size),
    expected: size * 2 + 2,
  },
  { name: "JSON decode and parse", mode: "json-parse", input: `"${ascii}"`, expected: 1 },
  { name: "multipart token scan", mode: "multipart-token", input: ascii, expected: 1 },
  {
    name: "multipart oversized boundary rejection",
    mode: "multipart-boundary",
    input: `multipart/form-data;boundary=${ascii}`,
    expected: 0,
  },
  {
    name: "multipart dense parameters",
    mode: "multipart-boundary",
    input: `multipart/form-data${";x=y".repeat(size / 4)};boundary=z`,
    expected: 1,
  },
  {
    name: "multipart long media type",
    mode: "multipart-type",
    input: `text/${lower}`,
    expected: 1,
  },
  {
    name: "multipart dense charset parameters",
    mode: "multipart-type",
    input: `text/plain${";x=y".repeat(size / 4)}`,
    expected: 1,
  },
  {
    name: "retained request-line helper",
    mode: "legacy-path",
    input: `GET /${lower} HTTP/1.1\r\n\r\n`,
    expected: size + 1,
  },
  { name: "trailing slash trim", mode: "slash-trim", input: `/${lower}/`, expected: size + 1 },
  { name: "trailing slash append", mode: "slash-append", input: `/${lower}`, expected: size + 2 },
  {
    name: "trailing slash unsafe final character",
    mode: "slash-append",
    input: `/${lower}\\`,
    expected: 0,
  },
  { name: "CORS reflected long name", mode: "cors-reflect", input: ascii, expected: size },
  {
    name: "CORS reflected dense list",
    mode: "cors-reflect",
    input: "A,".repeat(size / 2),
    expected: size - 1,
  },
  { name: "CORS combined field", mode: "cors-combined", input: ascii, expected: size },
  {
    name: "CORS combined many fields",
    mode: "cors-combined-many",
    input: ",".repeat(size),
    expected: size,
  },
  {
    name: "forwarded address trim",
    mode: "forwarded-trim",
    input: ` \t${lower}\t `,
    expected: size,
  },
  {
    name: "forwarded address blank trim",
    mode: "forwarded-trim",
    input: " ".repeat(size),
    expected: 0,
  },
  {
    name: "forwarded address entries",
    mode: "forwarded-entries",
    input: ",".repeat(size),
    expected: size + 1,
  },
  {
    name: "forwarded client many hops",
    mode: "forwarded-client",
    input: "1.2.3.4,".repeat(size / 8),
    expected: 1,
  },
  { name: "ASCII uppercase", mode: "upper", input: lower, expected: size },
  { name: "method override extension", mode: "override", input: lower, expected: size },
  { name: "string split one part", mode: "split", input: lower, expected: 1 },
  { name: "string split many parts", mode: "split", input: ",".repeat(size), expected: size + 1 },
  {
    name: "conditional many member decisions",
    mode: "conditional-match",
    input: ",".repeat(size),
    expected: 0,
  },
  {
    name: "WebSocket list decisions",
    mode: "websocket-listed",
    input: ",".repeat(size),
    expected: 0,
  },
  {
    name: "WebSocket offer decisions",
    mode: "websocket-offered",
    input: ",".repeat(size),
    expected: 0,
  },
  {
    name: "WebSocket Content-Length zeros",
    mode: "websocket-zeros",
    input: "0".repeat(size),
    expected: 1,
  },
  {
    name: "WebSocket oversized key",
    mode: "websocket-key",
    input: "YWFh".repeat(size / 4),
    expected: 0,
  },
  { name: "oversized forwarded IPv6", mode: "ip-parse", input: `${lower}:`, expected: 0 },
  {
    name: "Content-Length zero digits",
    mode: "content-length",
    input: "0".repeat(size),
    expected: 0,
  },
  { name: "ASCII lowercase", mode: "lower", input: ascii, expected: size },
  { name: "octet append", mode: "append", input: ascii, expected: size + 1 },
  { name: "UTF-8 scalar validation", mode: "utf8-valid", input: ascii, expected: 1 },
  { name: "octet encode", mode: "encode", input: ascii, expected: size },
  { name: "octet to text", mode: "ascii", input: ascii, expected: size },
  { name: "token characters", mode: "token", input: ascii, expected: 1 },
  {
    name: "invalid final token character",
    mode: "token",
    input: `${ascii.slice(1)} `,
    expected: 0,
  },
  { name: "field value octets", mode: "value", input: ascii, expected: 1 },
  { name: "invalid final field octet", mode: "value", input: `${ascii.slice(1)}\r`, expected: 0 },
  { name: "URI characters", mode: "uri", input: ascii, expected: 1 },
  { name: "percent encoded URI", mode: "uri", input: `%41${ascii.slice(3)}`, expected: 1 },
  { name: "invalid final URI escape", mode: "uri", input: `${ascii.slice(1)}%`, expected: 0 },
  { name: "target before query", mode: "target", input: `${ascii}?q`, expected: size },
  { name: "target without query", mode: "target", input: ascii, expected: size },
  { name: "all whitespace trim", mode: "trim", input: " ".repeat(size), expected: 0 },
  { name: "trim preserves interior", mode: "trim", input: ` \t${ascii}\t `, expected: size },
  { name: "JWT first segment", mode: "jwt", input: `${lower}.payload.signature`, expected: size },
  { name: "JWT dot-free segment", mode: "jwt-dotfree", input: lower, expected: 1 },
  { name: "JWT invalid final dot", mode: "jwt-dotfree", input: `${lower.slice(1)}.`, expected: 0 },
  { name: "JWT missing separator", mode: "jwt", input: lower, expected: 0 },
  { name: "JWT octets", mode: "jwt-codes", input: lower, expected: size },
  { name: "Cookie value", mode: "cookie", input: `a=${lower}`, expected: 1 },
  { name: "Cookie name", mode: "cookie", input: `${lower}=a`, expected: 1 },
  {
    name: "many Cookie entries",
    mode: "cookie",
    input: "a=b;".repeat(size / 4),
    expected: size / 4,
  },
  { name: "header name", mode: "header", input: `${ascii}: value`, expected: 1 },
  { name: "header value", mode: "header", input: `X-Test: ${ascii}`, expected: 1 },
  { name: "invalid header value", mode: "header", input: `X-Test: ${ascii}\r`, expected: 0 },
  { name: "Accept unknown media", mode: "accept", input: ascii, expected: 0 },
  {
    name: "Accept JSON after long parameter",
    mode: "accept",
    input: `text/plain;x=${ascii},application/json`,
    expected: 1,
  },
  { name: "Accept many ranges", mode: "accept", input: ",".repeat(size), expected: 0 },
  {
    name: "Accept many parameters",
    mode: "accept",
    input: `application/json${";".repeat(size)}`,
    expected: 1,
  },
  { name: "Content-Type essence", mode: "media", input: ascii, expected: size },
  { name: "byte split one part", mode: "ip-split", input: lower, expected: 1 },
  { name: "byte split many parts", mode: "ip-split", input: ",".repeat(size), expected: size + 1 },
  { name: "base64 encode", mode: "base64-encode", input: lower, expected: 87384 },
  { name: "base64 decode", mode: "base64-decode", input: "YWFh".repeat(size / 4), expected: 49152 },
  { name: "hex encode", mode: "hex-encode", input: lower, expected: size * 2 },
  { name: "hex decode", mode: "hex-decode", input: "61".repeat(size / 2), expected: size / 2 },
  { name: "UTF-8 encode ASCII", mode: "utf8-encode", input: lower, expected: size },
  {
    name: "UTF-8 encode multibyte",
    mode: "utf8-encode",
    input: "é".repeat(size / 2),
    expected: size,
  },
  { name: "UTF-8 decode ASCII", mode: "utf8-decode", input: lower, expected: size },
  {
    name: "UTF-8 decode multibyte",
    mode: "utf8-decode",
    input: "é".repeat(size / 2),
    expected: size / 2,
  },
  {
    name: "complete request with long header",
    mode: "parse",
    input: `GET / HTTP/1.1\r\nX-Test: ${ascii}\r\n\r\n`,
    expected: 1,
  },
  {
    name: "complete request with dense header fields",
    mode: "wellformed",
    input: `GET / HTTP/1.1\r\n${"a:\r\n".repeat((size - 32) / 4)}\r\n`,
    expected: 1,
  },
  {
    name: "lookup dense header fields",
    mode: "lookup",
    input: `GET / HTTP/1.1\r\n${"a:\r\n".repeat((size - 32) / 4)}\r\n`,
    expected: (size - 32) / 4,
  },
  {
    name: "complete request with long header name",
    mode: "parse",
    input: `GET / HTTP/1.1\r\n${ascii}: value\r\n\r\n`,
    expected: 1,
  },
  {
    name: "complete request with long target",
    mode: "parse",
    input: `GET /${lower} HTTP/1.1\r\n\r\n`,
    expected: 1,
  },
  { name: "origin cut", mode: "origin-cut", input: `${lower}:b`, expected: size },
  { name: "origin authority", mode: "origin-authority", input: lower, expected: size },
  { name: "origin digits", mode: "origin-digits", input: "1".repeat(size), expected: 1 },
  { name: "origin hostname", mode: "origin-name", input: lower, expected: 1 },
  { name: "origin IPv6 characters", mode: "origin-ipv6", input: lower, expected: 1 },
  { name: "origin long host", mode: "origin-canonical", input: `http://${lower}`, expected: 0 },
  {
    name: "origin long port",
    mode: "origin-canonical",
    input: `http://a:${"1".repeat(size)}`,
    expected: 0,
  },
  {
    name: "origin long IPv6",
    mode: "origin-canonical",
    input: `http://[${"1:".repeat(size / 2)}]`,
    expected: 0,
  },
  { name: "origin long path", mode: "origin-url", input: `http://a/${lower}`, expected: 8 },
  { name: "text trim", mode: "trim-text", input: ` \t${ascii}\t `, expected: size },
  { name: "all whitespace text trim", mode: "trim-text", input: " ".repeat(size), expected: 0 },
  { name: "Connection token", mode: "connection", input: `${",".repeat(size)}close`, expected: 1 },
  { name: "router encode", mode: "router-encode", input: lower, expected: size * 3 },
  { name: "router decode", mode: "router-decode", input: lower, expected: size },
  { name: "URL encode", mode: "url-encode", input: lower, expected: size },
  { name: "URL decode", mode: "url-decode", input: lower, expected: size },
  {
    name: "URL query pairs",
    mode: "url-pairs",
    input: "a=b&".repeat(size / 4),
    expected: size / 4,
  },
  { name: "conditional entity", mode: "conditional-entity", input: `"${lower}"`, expected: size },
  { name: "conditional list", mode: "conditional-segments", input: lower, expected: 1 },
  {
    name: "conditional many elements",
    mode: "conditional-segments",
    input: ",".repeat(size),
    expected: size + 1,
  },
  { name: "Authorization separator", mode: "auth-cut", input: `${lower} b`, expected: size },
  { name: "Authorization escape", mode: "auth-escape", input: lower, expected: size },
  {
    name: "Authorization escape expansion",
    mode: "auth-escape",
    input: '"'.repeat(size),
    expected: size * 2,
  },
  { name: "bearer characters", mode: "bearer", input: lower, expected: 1 },
  { name: "MIME extension", mode: "mime", input: `${lower}.TXT`, expected: 3 },
];

// No --stack-size or NODE_OPTIONS: these run in Bun's default JS stack.
for (const vector of vectors) {
  test(
    `.mjs 64 KiB ${vector.name}`,
    () => {
      expect(probe(vector.mode, vector.input)).toBe(vector.expected);
    },
    SLOW_TEST_TIMEOUT_MS,
  );
  test(
    `native 64 KiB ${vector.name}`,
    () => {
      const run = Bun.spawnSync([binary, vector.mode, vector.input], {
        stdout: "pipe",
        stderr: "pipe",
        timeout: 30_000,
      });
      expect(run.exitCode, run.stderr.toString()).toBe(0);
      expect(run.stdout.toString().trim()).toBe(String(vector.expected));
    },
    SLOW_TEST_TIMEOUT_MS,
  );
}

test(
  ".mjs folding and octet conversion preserve exact 64 KiB contents",
  () => {
    const mixed = "AbC-09_é".repeat(size / 8);
    expect(exported("folded")(mixed)).toBe("abc-09_é".repeat(size / 8));
    expect(exported("roundtrip")(mixed)).toBe(mixed);
  },
  SLOW_TEST_TIMEOUT_MS,
);

test(
  ".mjs JWT split preserves the first separator and the entire remaining token",
  () => {
    const left = "a".repeat(size);
    const right = `b.${"c".repeat(size)}`;
    expect(exported("first_segment")(`${left}.${right}`)).toBe(left);
    expect(exported("rest_segments")(`${left}.${right}`)).toBe(right);
    expect(exported("first_segment")(".a.b")).toBe("");
    expect(exported("rest_segments")(".a.b")).toBe("a.b");
  },
  SLOW_TEST_TIMEOUT_MS,
);

function list(values: string[]): unknown {
  return values.reduceRight<unknown>((tail, head) => ({ $: "Con", head, tail }), { $: "Nil" });
}

test(".mjs transforms preserve asymmetric separators, escapes and multibyte contents", () => {
  expect(exported("uppercased")("AbC-é_09")).toBe("ABC-é_09");
  expect(exported("target_parts")("ab?cd?ef")).toEqual({
    $: "Tuple",
    fst: "ab",
    snd: { $: "Some", value: "cd?ef" },
  });
  expect(exported("target_parts")("ab?")).toEqual({
    $: "Tuple",
    fst: "ab",
    snd: { $: "Some", value: "" },
  });
  expect(exported("split_text")(",ab,C,,dé,")).toEqual(list(["", "ab", "C", "", "dé", ""]));
  expect(exported("escaped")('a"b\\c')).toBe('a\\"b\\\\c');
  expect(exported("router_encoded")("aé/ Z")).toBe("%61%C3%A9%2F%20%5A");
  expect(exported("router_decoded")("%61%C3%A9%2F%20%5A")).toEqual({ $: "Some", value: "aé/ Z" });
  expect(exported("conditional_parts")('"a,b", "c"')).toEqual(list(['"a,b"', ' "c"']));
  expect(exported("conditional_parts")('"a,b')).toEqual(list(['"a,b']));
});

const exactVectors = [
  { mode: "exact-lower", input: "AbC-é_09", expected: "abc-é_09" },
  { mode: "exact-upper", input: "AbC-é_09", expected: "ABC-é_09" },
  { mode: "exact-roundtrip", input: "AbC-é_09", expected: "AbC-é_09" },
  { mode: "exact-escape", input: 'a"b\\c', expected: 'a\\"b\\\\c' },
  { mode: "exact-router-encode", input: "aé/ Z", expected: "%61%C3%A9%2F%20%5A" },
  { mode: "exact-router-decode", input: "%61%C3%A9%2F%20%5A", expected: "aé/ Z" },
];
for (const vector of exactVectors) {
  test(`native ${vector.mode} preserves exact asymmetric contents`, () => {
    const run = Bun.spawnSync([binary, vector.mode, vector.input], {
      stdout: "pipe",
      stderr: "pipe",
      timeout: 30_000,
    });
    expect(run.exitCode, run.stderr.toString()).toBe(0);
    expect(run.stdout.toString().trim()).toBe(vector.expected);
  });
}

test(
  "native dense CORS joining grows with input size",
  () => {
    function sample(length: number): number {
      const input = "A,".repeat(length / 2);
      const started = performance.now();
      const run = Bun.spawnSync([binary, "cors-reflect", input], {
        stdout: "pipe",
        stderr: "pipe",
        timeout: 30000,
      });
      const elapsed = performance.now() - started;
      expect(run.exitCode).toBe(0);
      expect(run.stdout.toString().trim()).toBe(String(length - 1));
      return elapsed;
    }
    // Four times the input should stay well below quadratic (16x) growth.
    const small = Math.min(sample(size / 4), sample(size / 4));
    const large = Math.min(sample(size), sample(size));
    expect(large / small).toBeLessThan(8);
  },
  SLOW_TEST_TIMEOUT_MS,
);
