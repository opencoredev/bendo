import { afterAll, expect, test } from "bun:test";
import { randomBytes } from "node:crypto";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { findBend } from "../packages/bendo/src/bend.ts";
import { BEND_COMPILE_TIMEOUT, start } from "./harness.ts";

type BendList<T> = { $: "Nil" } | { $: "Con"; head: T; tail: BendList<T> };
function list(values: Uint8Array | readonly number[]): BendList<number> {
  let result: BendList<number> = { $: "Nil" };
  for (let i = values.length - 1; i >= 0; i--) {
    const value = values[i];
    if (value === undefined) throw new Error("Missing octet");
    result = { $: "Con", head: value, tail: result };
  }
  return result;
}
const directory = mkdtempSync(join(tmpdir(), "bendo-multipart-"));
afterAll(() => rmSync(directory, { recursive: true, force: true }));
function compile(entry: string, output: string): string {
  const bend = findBend();
  if (bend.kind === "missing") throw new Error("bend is not installed");
  const path = join(directory, output);
  const run = Bun.spawnSync(
    [
      "timeout",
      "--foreground",
      BEND_COMPILE_TIMEOUT,
      bend.path,
      join(import.meta.dir, entry),
      "-o",
      path,
    ],
    { stdout: "pipe", stderr: "pipe" },
  );
  if (run.exitCode !== 0) throw new Error(`Bend compilation failed:\n${run.stdout}${run.stderr}`);
  return path;
}
const binary = compile("servers/multipart.bend", "server");
const module: unknown = await import(
  pathToFileURL(compile("fixtures/multipart/consumer.bend", "consumer.mjs")).href
);
if (typeof module !== "object" || module === null || !("default" in module)) {
  throw new Error("Missing Bend exports");
}
const exports: unknown = module.default;
if (typeof exports !== "object" || exports === null || !("parse" in exports)) {
  throw new Error("Missing parse export");
}
function callable(value: unknown): (...args: unknown[]) => unknown {
  if (typeof value !== "function") throw new Error("parse is not callable");
  return (...args) => value(...args);
}
const parseFunction = callable(exports.parse);
const limits = {
  $: "Limits",
  file_size: 3 * 1024 * 1024,
  total_size: 4 * 1024 * 1024,
  parts: 128,
  header_size: 8192,
};
function parse(
  body: string | Uint8Array,
  options = limits,
  ct = "multipart/form-data; boundary=abc",
): unknown {
  return parseFunction(
    ct,
    list(typeof body === "string" ? new TextEncoder().encode(body) : body),
    options,
  );
}
const fail = (error: string) => ({ $: "Fail", error: { $: error } });
const done = (value: unknown) => ({ $: "Done", value });
function parts(values: readonly unknown[]): unknown {
  let result: unknown = { $: "Nil" };
  for (const value of values.toReversed()) result = { $: "Con", head: value, tail: result };
  return done(result);
}
const field = (name: string, value: string) => ({ $: "Field", name, value });
const file = (
  name: string,
  filename: string,
  bytes: readonly number[],
  content_type = "application/octet-stream",
) => ({ $: "File", name, filename, content_type, bytes: list(bytes) });
function body(value: string, disposition = 'form-data; name="x"', extra = ""): string {
  return `--abc\r\nContent-Disposition: ${disposition}\r\n${extra}\r\n${value}\r\n--abc--`;
}
const sha256 = (bytes: Uint8Array) => new Bun.CryptoHasher("sha256").update(bytes).digest("hex");

test("fetch FormData preserves 2 MiB binary bytes, repeated fields and Unicode metadata", async () => {
  await using server = await start(binary);
  const bytes = randomBytes(2 * 1024 * 1024);
  const form = new FormData();
  form.append("tag", "first");
  form.append("tag", "é 日本語 😀");
  form.append("upload", new Blob([bytes], { type: "application/octet-stream" }), "café-😀.bin");
  const response = await fetch(server.url, { method: "POST", body: form });
  expect(response.status).toBe(200);
  const hash = sha256(bytes);
  const lines = (await response.text())
    .trimEnd()
    .split("\n")
    .map((line) => line.split("\t").map(decodeURIComponent));
  expect(lines).toEqual([
    ["field", "tag", "first"],
    ["field", "tag", "é 日本語 😀"],
    ["file", "upload", "café-😀.bin", "application/octet-stream", "2097152", hash],
  ]);
  console.log(`2 MiB SHA-256 equality: ${hash}`);
});

test("HTTP maps parser file/total limits to 413 and malformed bodies to 400", async () => {
  await using server = await start(binary);
  for (const [route, value] of [
    ["/file", body("123456789", 'form-data; name="f"; filename="x"')],
    ["/total", body("a".repeat(256))],
  ] satisfies [string, string][]) {
    const response = await fetch(`${server.url}${route}`, {
      method: "POST",
      headers: { "content-type": "multipart/form-data; boundary=abc" },
      body: value,
    });
    expect(response.status).toBe(413);
  }
  for (const [ct, value] of [
    ["multipart/form-data", body("x")],
    ["multipart/form-data; boundary=wrong", body("x")],
    ["multipart/form-data; boundary=abc", body("x").slice(0, -2)],
    ["multipart/form-data; boundary=abc", body("x", "form-data")],
  ] satisfies [string, string][]) {
    const response = await fetch(server.url, {
      method: "POST",
      headers: { "content-type": ct },
      body: value,
    });
    expect(response.status).toBe(400);
  }
});

test("ordered fields/files, empty values, empty filename, strict UTF-8 and default media", () => {
  expect(parse(body(""))).toEqual(parts([field("x", "")]));
  expect(parse(body("", 'form-data; name="x"; filename=""'))).toEqual(parts([file("x", "", [])]));
  expect(parse(body("é😀", 'form-data; name="日本語"'))).toEqual(parts([field("日本語", "é😀")]));
  expect(parse(body("", 'form-data; name="x"', "Content-Type: text/plain\r\n"))).toEqual(
    parts([field("x", "")]),
  );
  const invalid = new TextEncoder().encode(body("!"));
  const index = invalid.indexOf(33);
  invalid[index] = 255;
  expect(parse(invalid)).toEqual(fail("Malformed"));
  const invalidFile = new TextEncoder().encode(body("!", 'form-data; name="x"; filename="binary"'));
  invalidFile[invalidFile.indexOf(33)] = 255;
  expect(parse(invalidFile)).toEqual(parts([file("x", "binary", [255])]));
});

test("preamble/epilogue, closing at EOF, padding, quoted and case-sensitive boundaries", () => {
  expect(parse("--abc--")).toEqual(parts([]));
  expect(parse("ignored\r\n--abc--\r\nepilogue")).toEqual(parts([]));
  expect(
    parse(
      body("x").replace("--abc\r\n", "--abc \t\r\n").replace("--abc--", "--abc-- \t\r\nignored"),
    ),
  ).toEqual(parts([field("x", "x")]));
  for (const ct of [
    ' Multipart/Form-Data ; boundary="abc"',
    'multipart/form-data; ignored="x;y"; boundary="a\\bc"',
  ])
    expect(parse(body("x"), limits, ct)).toEqual(parts([field("x", "x")]));
  expect(parse("--a b--", limits, 'multipart/form-data; boundary="a b"')).toEqual(parts([]));
  expect(parse("--ABC--")).toEqual(fail("Malformed"));
});

test("boundary prefixes and invalid delimiter suffixes remain identical file bytes", () => {
  for (const value of [
    "--abc",
    "\r\n--ab",
    "\r\n--abcX",
    "\r\n--abc--X",
    "\r\n--abc \tX",
    "\r\n\r\n",
    "\n--abc\n",
    "\r\n--ab\r\n--abcX\r\n--abc--X",
  ]) {
    expect(parse(body(value, 'form-data; name="x"; filename="binary"'))).toEqual(
      parts([file("x", "binary", [...new TextEncoder().encode(value)])]),
    );
  }
});

test("rejects malformed boundaries and headers without partial results", () => {
  for (const boundary of [
    "",
    "a".repeat(71),
    '"abc "',
    '"a@b"',
    '"abc',
    "abc; boundary=abc",
    '"a\r\nb"',
  ]) {
    expect(parse(body("x"), limits, `multipart/form-data; boundary=${boundary}`)).toEqual(
      fail("Malformed"),
    );
  }
  expect(
    parse(`--${"a".repeat(70)}--`, limits, `multipart/form-data; boundary=${"a".repeat(70)}`),
  ).toEqual(parts([]));
  for (const malformed of [
    body("x").replaceAll("\r\n", "\n"),
    body("x").slice(0, -1),
    body("x", "form-data"),
    body("x", 'attachment; name="x"'),
    body("x", 'form-data; name="x"; name="y"'),
    body("x", "form-data; name=\"x\"; filename*=UTF-8''x"),
    body("x", 'form-data; name="x"', "Content-Disposition: form-data; name=y\r\n"),
    body("x", 'form-data; name="x"', " Content-Type: text/plain\r\n"),
    body("x", 'form-data; name="x"', "Content-Type : text/plain\r\n"),
    body("x", 'form-data; name="x"', "Bad-Header\r\n"),
    body("x", 'form-data; name="x"', "Content-Type: text/plain; charset=latin1\r\n"),
    body("x", 'form-data; name="x"', "Content-Transfer-Encoding: base64\r\n"),
    body("x", 'form-data; name="x"', "X-Test: nul\0\r\n"),
  ]) {
    expect(parse(malformed)).toEqual(fail("Malformed"));
  }
  expect(parseFunction("multipart/form-data; boundary=abc", list([256]), limits)).toEqual(
    fail("Malformed"),
  );
});

test("exact file, total, header and part-count limits accept; one below rejects", () => {
  const value = body("12345678", 'form-data; name="x"; filename="f"');
  expect(parse(value, { ...limits, file_size: 8 })).toEqual(
    parts([file("x", "f", [...new TextEncoder().encode("12345678")])]),
  );
  expect(parse(value, { ...limits, file_size: 7 })).toEqual(fail("TooLarge"));
  const length = new TextEncoder().encode(value).length;
  expect(parse(value, { ...limits, total_size: length })).toEqual(
    parts([file("x", "f", [...new TextEncoder().encode("12345678")])]),
  );
  expect(parse(value, { ...limits, total_size: length - 1 })).toEqual(fail("TooLarge"));
  const headerSize = 'Content-Disposition: form-data; name="x"; filename="f"\r\n\r\n'.length;
  expect(parse(value, { ...limits, header_size: headerSize })).toEqual(
    parts([file("x", "f", [...new TextEncoder().encode("12345678")])]),
  );
  expect(parse(value, { ...limits, header_size: headerSize - 1 })).toEqual(fail("TooLarge"));
  expect(parse(body("x"), { ...limits, parts: 1 })).toEqual(parts([field("x", "x")]));
  expect(parse(body("x"), { ...limits, parts: 0 })).toEqual(fail("TooLarge"));
  expect(parse("--abc--", { ...limits, parts: 0 })).toEqual(parts([]));
  expect(parse(`preamble\r\n${value}\r\nepilogue`, { ...limits, total_size: length })).toEqual(
    fail("TooLarge"),
  );
});

function successfulPart(result: unknown): unknown {
  if (
    typeof result !== "object" ||
    result === null ||
    !("$" in result) ||
    result.$ !== "Done" ||
    !("value" in result)
  )
    throw new Error("Expected Done");
  const xs: unknown = result.value;
  if (typeof xs !== "object" || xs === null || !("head" in xs)) throw new Error("Expected part");
  return xs.head;
}

test(".mjs 2 MiB file and field, many parts and late failure stay stack-safe", () => {
  const value = "z".repeat(2 * 1024 * 1024);
  const result = successfulPart(parse(body(value, 'form-data; name="x"; filename="f"')));
  if (typeof result !== "object" || result === null || !("bytes" in result))
    throw new Error("Expected file");
  let cursor: unknown = result.bytes;
  let count = 0;
  while (typeof cursor === "object" && cursor !== null && "head" in cursor && "tail" in cursor) {
    if (cursor.head !== 122) throw new Error(`Wrong byte at ${count}`);
    cursor = cursor.tail;
    count++;
  }
  expect(count).toBe(2097152);
  expect(cursor).toEqual({ $: "Nil" });
  expect(successfulPart(parse(body(value)))).toEqual(field("x", value));
  expect(parse(body(value).slice(0, -1))).toEqual(fail("Malformed"));
  const many = `${Array.from({ length: 128 }, () => '--abc\r\nContent-Disposition: form-data; name="x"\r\n\r\nx\r\n').join("")}--abc--`;
  expect(parse(many)).toEqual(parts(Array.from({ length: 128 }, () => field("x", "x"))));
  expect(parse(many, { ...limits, parts: 127 })).toEqual(fail("TooLarge"));
  console.log(".mjs: 2 MiB file bytes and field, 128 parts, late malformed closure PASS");
});

test("unified dispatcher preserves URL-encoded results and wraps original errors", () => {
  expect(parse("x=%C3%A9&x=2", limits, "application/x-www-form-urlencoded")).toEqual(
    parts([field("x", "é"), field("x", "2")]),
  );
  expect(parse("x=%", limits, "application/x-www-form-urlencoded")).toEqual({
    $: "Fail",
    error: { $: "Urlencoded", error: { $: "InvalidPercent" } },
  });
});

test("outer Content-Type rejects controls even in ignored quoted parameters", () => {
  for (const control of ["\r", "\n", "\0", "\x01", "\x7f"]) {
    expect(
      parse(body("x"), limits, `multipart/form-data; boundary=abc; ignored="a${control}b"`),
    ).toEqual(fail("Malformed"));
  }
});
