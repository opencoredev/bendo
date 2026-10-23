import { afterAll, describe, expect, test } from "bun:test";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { findBend } from "../packages/bendo/src/bend.ts";

const dir = mkdtempSync(join(tmpdir(), "bendo-schema-"));
afterAll(() => rmSync(dir, { recursive: true, force: true }));
const bend = findBend();
if (bend.kind === "missing") throw new Error("Bend is not installed");
function compile(source: string, output: string) {
  if (bend.kind === "missing") throw new Error("Bend is not installed");
  const r = Bun.spawnSync(["timeout", "--foreground", "30s", bend.path, source, "-o", output]);
  if (r.exitCode !== 0) throw new Error(`${r.stdout}${r.stderr}`);
}
const nativePath = join(dir, "schema");
const modulePath = join(dir, "schema.mjs");
compile(join(import.meta.dir, "fixtures/schema/native.bend"), nativePath);
compile(join(import.meta.dir, "fixtures/schema/consumer.bend"), modulePath);
const imported: unknown = await import(pathToFileURL(modulePath).href);
if (typeof imported !== "object" || imported === null || !("default" in imported)) {
  throw new Error("Missing Bend exports");
}
const api: unknown = imported.default;
function call(name: string, ...args: unknown[]): unknown {
  if (typeof api !== "object" || api === null) throw new Error("Invalid module");
  const fn: unknown = Reflect.get(api, name);
  if (typeof fn !== "function") throw new Error(`Missing ${name}`);
  return fn(...args);
}
function value(r: unknown): unknown {
  if (typeof r !== "object" || r === null || !("$" in r) || r.$ !== "Done" || !("value" in r)) {
    throw new Error("Expected Done");
  }
  return r.value;
}
function native(schema: string, input: string): string {
  const r = Bun.spawnSync([
    "timeout",
    "--foreground",
    "5s",
    nativePath,
    schema,
    input,
    "+RTS",
    "--threads",
    "1",
    "-RTS",
  ]);
  expect(r.exitCode).toBe(0);
  return r.stdout.toString().trimEnd();
}
type Variant = "VString" | "VNumber" | "VInteger" | "VBool" | "VLiteral";
type Case = { schema: string; input: string; result: string };
const cases: Case[] = [];
function good(schema: string, variant: Variant, ...inputs: string[]) {
  for (const input of inputs) cases.push({ schema, input, result: `ok:${variant}:${input}` });
}
function bad(schema: string, ...inputs: string[]) {
  for (const input of inputs) cases.push({ schema, input, result: "error:Constraint" });
}
const text = (s: string) => JSON.stringify(s);
good("text", "VString", text(""), text("😀é"), text("a\n\u0000"));
good("length", "VString", text("a"), text("😀"), text("😀éa"));
bad("length", text(""), text("abcd"), text("😀😀😀😀"));
good("empty", "VString", text(""));
bad("empty", text("a"));
good("exact", "VString", text("😀a"));
bad("exact", text("😀"), text("abc"));
good("pattern", "VString", text("a"), text("0"), text("a0b9"));
bad("pattern", text(""), text("A"), text("aaaaa"), text("a\n"), text("😀"), text("é"));
good("star", "VString", text(""), text("aaa"));
bad("star", text("b"));
good("plus", "VString", text("a"), text("aaa"));
bad("plus", text(""), text("b"));
good("optional", "VString", text(""), text("a"));
bad("optional", text("aa"));
good("pattern-exact", "VString", text("aa"));
bad("pattern-exact", text("a"), text("aaa"));
good("no-ranges", "VString", text(""));
bad("no-ranges", text("a"));
good(
  "email",
  "VString",
  ...[
    "a@b",
    "first.last+tag@example.com",
    "a!#$%&'*+-/=?^_`{|}~@x-y.example",
    "a".repeat(64) + "@x",
  ].map(text),
);
bad(
  "email",
  ...[
    "",
    "a",
    "@b",
    "a@",
    ".a@b",
    "a.@b",
    "a..b@c",
    "a@@b",
    "a b@c",
    "é@b",
    "a@é",
    '"a"@b',
    "a@-b",
    "a@b-",
    "a@b..c",
    "a@b.",
    "a@[127.0.0.1]",
    "a@" + "b".repeat(64),
    "a".repeat(65) + "@b",
    "a@b\n",
  ].map(text),
);
good(
  "url",
  "VString",
  ...[
    "http://localhost",
    "https://example.com",
    "https://x-y.example:65535/a%20b?q=1#ok",
    "http://127.0.0.1:0/",
    "https://x:00080/?x=%F0%9F%98%80",
    "https://x?query",
    "http://x#frag",
  ].map(text),
);
bad(
  "url",
  ...[
    "",
    "https://",
    "ftp://x",
    "HTTP://x",
    "/relative",
    "https:x",
    "http://user@x",
    "http://[::1]",
    "http://-x",
    "http://x-",
    "http://x.",
    "http://x:65536",
    "http://x:",
    "http://x:123456",
    "http://x:abc",
    "http://x/a b",
    "http://x/é",
    "http://x/\\a",
    "http://x/%",
    "http://x/%0g",
    "http://x\n",
  ].map(text),
);
good(
  "number",
  "VNumber",
  "0",
  "-0",
  "0.0",
  "-0.00E+009",
  "1e9999999999999999999999999",
  "1e-99999999999999999999999",
);
good("range", "VNumber", "-125", "125.000", "-0", "0.125e3", "124.999999999999999999999999999");
bad("range", "-125.000000000000000000000000001", "125.000000000000000000000000001", "126");
good("equal", "VNumber", "1", "1.0000000000000", "100e-2");
bad("equal", "0.99999999999999999", "1.00000000000000001");
good(
  "huge",
  "VNumber",
  "90071992547409931234567890.123456789",
  "90071992547409931234567890.123456790",
  "90071992547409931234567890.123456791",
);
bad("huge", "90071992547409931234567890.123456788", "90071992547409931234567890.123456792");
good("tiny", "VNumber", "15e-1000000000000000000000000000000");
bad("tiny", "9e-1000000000000000000000000000000", "3e-999999999999999999999999999999");
good(
  "exponent",
  "VNumber",
  "10e999999999999999999999999999998",
  "2e999999999999999999999999999999",
);
bad("exponent", "9e999999999999999999999999999998", "3e999999999999999999999999999999");
good("integer", "VInteger", "0", "-0", "-1234567890123456789012345678901234567890");
bad("integer", "1.0", "1e0", "1.1", "-0.0");
good("int-range", "VInteger", "-3", "4", "-0");
bad("int-range", "-4", "5");
good("boolean", "VBool", "true", "false");
good("null", "VLiteral", "null");
bad("null", "false", "0");
good("literal", "VLiteral", text("yes"));
bad("literal", text("no"), "true");
good("numeric-literal", "VLiteral", "1", "1.0", "10e-1");
bad("numeric-literal", "1.0000000000000001");
good("zero-literal", "VLiteral", "0", "-0", "0.000E99", "-0e-999999999999999999999999");
good("enum", "VLiteral", text("yes"), "2", "2.00", "false", "null");
bad("enum", "true", text("no"), "3");
bad("empty-enum", "null", "false", text(""));
for (const schema of ["text", "number", "integer", "boolean"]) {
  for (const input of ["null", "[]", "{}", schema === "text" ? "42" : text("42")]) {
    cases.push({ schema, input, result: "error:TypeMismatch" });
  }
}
for (const schema of [
  "bad-length",
  "bad-range",
  "bad-bound",
  "bad-pattern",
  "bad-ascii",
  "bad-count",
  "bad-literal",
  "bad-enum",
]) {
  for (const input of ["true", text("a"), "1"])
    cases.push({ schema, input, result: "error:InvalidSchema" });
}

describe("scalar schemas through real native and .mjs consumers", () => {
  for (const c of cases)
    test(`${c.schema}: ${c.input} → ${c.result.startsWith("ok:") ? "accept" : "reject"}`, () => {
      expect(native(c.schema, c.input)).toBe(c.result);
      const parsed = call("parse", c.input);
      const tree = value(parsed);
      const schema = call("schema", c.schema);
      expect(call("run", c.schema, parsed)).toBe(c.result);
      expect(call("satisfies", schema, tree)).toBe(c.result.startsWith("ok:"));
      const decoded = call("decode", schema, tree);
      if (c.result.startsWith("ok:")) {
        const variant = c.result.split(":")[1];
        const payload: unknown =
          variant === "VLiteral"
            ? tree
            : variant === "VNumber" || variant === "VInteger"
              ? c.input
              : JSON.parse(c.input);
        expect(value(decoded)).toEqual({ $: variant, value: payload });
      } else {
        expect(decoded).toEqual({
          $: "Fail",
          error: {
            $: "Con",
            head: {
              $: "Error",
              code: { $: c.result.slice(6) },
              message:
                c.result === "error:InvalidSchema"
                  ? "invalid scalar schema"
                  : c.result === "error:TypeMismatch"
                    ? "expected schema scalar kind"
                    : "value does not satisfy scalar checks",
              path: { $: "Nil" },
            },
            tail: { $: "Nil" },
          },
        });
      }
    });
});

test("rejects invalid constructed JSON scalars and malformed literal metadata", () => {
  for (const input of ["", "NaN", "01", "+1", "1.", "1e", " 1"]) {
    const tree = { $: "JNumber", value: input };
    for (const name of ["number", "integer", "numeric-literal", "enum"]) {
      expect(call("satisfies", call("schema", name), tree)).toBe(false);
      expect(call("report", call("decode", call("schema", name), tree))).toBe("error:Constraint");
    }
  }
  for (const input of ["\ud800", "\udfff"]) {
    const tree = { $: "JString", value: input };
    expect(call("satisfies", call("schema", "text"), tree)).toBe(false);
    expect(call("report", call("decode", call("schema", "text"), tree))).toBe("error:Constraint");
    expect(call("report", call("decode", { $: "LiteralSchema", value: tree }, tree))).toBe(
      "error:InvalidSchema",
    );
  }
});

test("exact decimal ordering agrees with independently scaled BigInts", () => {
  // Decimal tokens and the oracle use integer coefficients and small scales.
  let seed = 33;
  const next = () => {
    seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
    return seed;
  };
  for (let i = 0; i < 500; i++) {
    const a = BigInt(next()) * 1000000000000000000000001n - 2000000000000000000000000000000000n;
    const b = BigInt(next()) * 1000000000000000000000003n - 2000000000000000000000000000000000n;
    const sa = next() % 20,
      sb = next() % 20;
    const left = a * 10n ** BigInt(sb),
      right = b * 10n ** BigInt(sa);
    expect(call("order", `${a}e-${sa}`, `${b}e-${sb}`)).toEqual({
      $: left < right ? "LT" : left > right ? "GT" : "EQ",
    });
  }
  for (const [a, b] of [
    ["-0", "0.00e99"],
    ["1.00", "10e-1"],
    ["1000", "0.1e4"],
    ["-120.000", "-12e1"],
  ]) {
    expect(call("order", a, b)).toEqual({ $: "EQ" });
  }
});

test(".mjs scalar checks stay stack safe for long strings, decimals, patterns and enums", () => {
  const long = "a".repeat(100000);
  for (const name of ["text", "star", "plus"]) {
    expect(value(call("decode", call("schema", name), { $: "JString", value: long }))).toEqual({
      $: "VString",
      value: long,
    });
  }
  expect(call("satisfies", call("schema", "star"), { $: "JString", value: long + "b" })).toBe(
    false,
  );
  for (const name of ["email", "url"]) {
    expect(call("satisfies", call("schema", name), { $: "JString", value: long })).toBe(false);
  }
  const digits = "9".repeat(100000);
  expect(value(call("decode", call("schema", "integer"), { $: "JNumber", value: digits }))).toEqual(
    { $: "VInteger", value: digits },
  );
  expect(call("order", "1e" + digits, "2e" + digits)).toEqual({ $: "LT" });
  expect(call("order", "1e-" + digits, "2e-" + digits)).toEqual({ $: "LT" });
});

test("structured patterns match their documented ECMAScript translation", () => {
  const pattern = {
    $: "Class",
    ranges: { $: "Con", head: { $: "Range", lo: 97, hi: 122 }, tail: { $: "Nil" } },
    min: 0,
    max: { $: "Some", value: 4 },
  };
  const schema = {
    $: "StringSchema",
    min_len: 0,
    max_len: { $: "None" },
    pattern: { $: "Some", value: pattern },
    format: { $: "Plain" },
  };
  const regex = /^[\x61-\x7a]{0,4}(?![\s\S])/;
  for (const input of [
    "",
    "a",
    "abcd",
    "abcde",
    "a\n",
    "a\r",
    "a\r\n",
    "a\u2028",
    "😀",
    ...Array.from({ length: 128 }, (_, i) => String.fromCharCode(i)),
  ]) {
    expect(call("satisfies", schema, { $: "JString", value: input })).toBe(regex.test(input));
  }
});

test("validates every enum member before matching and scans wide enums without recursion growth", () => {
  type Items = { $: "Nil" } | { $: "Con"; head: { $: "JNumber"; value: string }; tail: Items };
  let items: Items = { $: "Nil" };
  for (let i = 0; i < 20000; i++)
    items = { $: "Con", head: { $: "JNumber", value: String(i) }, tail: items };
  const schema = { $: "EnumSchema", values: items };
  const tree = { $: "JNumber", value: "0.0" };
  expect(value(call("decode", schema, tree))).toEqual({ $: "VLiteral", value: tree });
  expect(call("satisfies", schema, { $: "JNumber", value: "20000" })).toBe(false);
});
