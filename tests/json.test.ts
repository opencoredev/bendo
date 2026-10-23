import { afterAll, describe, expect, test } from "bun:test";
import { mkdtempSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { findBend } from "../packages/bendo/src/bend.ts";

type BendList<T> = { $: "Nil" } | { $: "Con"; head: T; tail: BendList<T> };
function list<T>(xs: readonly T[]): BendList<T> {
  let tail: BendList<T> = { $: "Nil" };
  for (let i = xs.length - 1; i >= 0; i--) {
    const head = xs[i];
    if (head === undefined) throw new Error("Missing list item");
    tail = { $: "Con", head, tail };
  }
  return tail;
}
const bytes = (s: string) => list([...new TextEncoder().encode(s)]);
const done = (value: unknown) => ({ $: "Done", value });
const fail = (error: string) => ({ $: "Fail", error: { $: error } });
const string = (value: string) => ({ $: "JString", value });
const number = (value: string) => ({ $: "JNumber", value });
const array = (items: readonly unknown[]) => ({ $: "JArray", items: list(items) });
const field = (key: string, value: unknown) => ({ $: "Field", key, value });
const object = (fields: readonly unknown[]) => ({ $: "JObject", fields: list(fields) });
const dir = mkdtempSync(join(tmpdir(), "bendo-json-"));
afterAll(() => rmSync(dir, { recursive: true, force: true }));
const bend = findBend();
if (bend.kind === "missing") throw new Error("Bend is not installed");
function compile(source: string, output: string) {
  if (bend.kind === "missing") throw new Error("Bend is not installed");
  const result = Bun.spawnSync(["timeout", "--foreground", "30s", bend.path, source, "-o", output]);
  if (result.exitCode !== 0) throw new Error(`${result.stdout}${result.stderr}`);
}
const nativePath = join(dir, "json-native");
const modulePath = join(dir, "json.mjs");
compile(join(import.meta.dir, "fixtures/json/native.bend"), nativePath);
compile(join(import.meta.dir, "fixtures/json/consumer.bend"), modulePath);
const imported: unknown = await import(pathToFileURL(modulePath).href);
if (typeof imported !== "object" || imported === null || !("default" in imported)) {
  throw new Error("Missing module default");
}
const exported: unknown = imported.default;
function call(name: string, ...args: unknown[]): unknown {
  if (typeof exported !== "object" || exported === null) throw new Error("Invalid Bend module");
  const fn: unknown = Reflect.get(exported, name);
  if (typeof fn !== "function") throw new Error(`Missing callable ${name}`);
  return fn(...args);
}
function value(result: unknown): unknown {
  if (
    typeof result !== "object" ||
    result === null ||
    !("$" in result) ||
    result.$ !== "Done" ||
    !("value" in result)
  ) {
    throw new Error(`Expected Done: ${JSON.stringify(result)}`);
  }
  return result.value;
}
function text(result: unknown): string {
  const output = value(result);
  if (typeof output !== "string") throw new Error("Expected written text");
  return output;
}
function native(mode: string, path: string): string {
  const result = Bun.spawnSync([
    "timeout",
    "--foreground",
    "10s",
    nativePath,
    mode,
    path,
    "+RTS",
    "--threads",
    "1",
    "-RTS",
  ]);
  expect(result.exitCode).toBe(0);
  return result.stdout.toString().slice(0, -1);
}
const fixtures = join(import.meta.dir, "fixtures/JSONTestSuite/test_parsing");

describe("JSONTestSuite pinned raw-byte corpus, native and .mjs", () => {
  const counts = { y: 0, n: 0, iAccepted: 0, iRejected: 0 };
  test("all 318 fixtures obey the documented policy on both targets", () => {
    for (const name of readdirSync(fixtures).sort()) {
      const path = join(fixtures, name);
      const accepted = native("parse", path) === "accept";
      const result = call("parse", list([...readFileSync(path)]));
      const expected =
        name.startsWith("y_") ||
        (name.startsWith("i_") &&
          (name.startsWith("i_number_") || name === "i_structure_500_nested_arrays.json"));
      expect(accepted, name).toBe(expected);
      expect(
        typeof result === "object" && result !== null && "$" in result && result.$ === "Done",
        name,
      ).toBe(expected);
      if (name.startsWith("y_")) counts.y++;
      else if (name.startsWith("n_")) counts.n++;
      else if (expected) counts.iAccepted++;
      else counts.iRejected++;
    }
    expect(counts).toEqual({ y: 95, n: 188, iAccepted: 11, iRejected: 24 });
  }, 30000);
});

test("preserves lexical numbers, member order, and duplicate keys in every writer mode", () => {
  const tree = object([
    field("a", number("-0.00E+009")),
    field("a", string('é😀\u0000\b\f\n\r\t"\\/')),
    field("list", array([{ $: "JNull" }, { $: "JBool", value: false }])),
  ]);
  for (const pretty of [false, true])
    for (const ascii of [false, true]) {
      const output = text(call("write", tree, pretty, ascii));
      expect(call("parse", bytes(output))).toEqual(done(tree));
      expect(JSON.parse(output)).toEqual({ a: 'é😀\u0000\b\f\n\r\t"\\/', list: [null, false] });
      if (ascii) expect([...output].every((c) => c.charCodeAt(0) < 128)).toBe(true);
      if (pretty) expect(output).toContain('\n  "a": ');
      const path = join(dir, "roundtrip.json");
      writeFileSync(path, output);
      expect(native("write", path)).toBe(text(call("write", tree, false, false)));
    }
  expect(call("lookup", list([field("a", number("1")), field("a", number("2"))]), "a")).toEqual({
    $: "Some",
    value: number("1"),
  });
});

test("escapes every control character, scalar boundary, and supplementary plane", () => {
  const s =
    Array.from({ length: 32 }, (_, i) => String.fromCharCode(i)).join("") +
    "\u007f\u0080\u07ff\u0800\ud7ff\ue000\uffff\u{10000}\u{10ffff}";
  for (const ascii of [false, true]) {
    const output = text(call("write", string(s), false, ascii));
    expect(JSON.parse(output)).toBe(s);
    expect(call("parse", bytes(output))).toEqual(done(string(s)));
  }
});

test("rejects malformed constructed values and non-octets", () => {
  for (const n of ["", "01", "+1", "1.", "1e", "NaN", "Infinity", " 1", "1\n"]) {
    expect(call("write", number(n), false, false)).toEqual(fail("InvalidValue"));
  }
  for (const s of ["\ud800", "\udfff"])
    expect(call("write", string(s), false, false)).toEqual(fail("InvalidValue"));
  expect(call("parse", list([34, 256, 34]))).toEqual(fail("InvalidUtf8"));
});

for (const depth of [511, 512, 513])
  test(`container depth ${depth} has the same parser and writer boundary`, () => {
    const input = "[".repeat(depth) + "0" + "]".repeat(depth);
    let tree: unknown = number("0");
    for (let i = 0; i < depth; i++) tree = array([tree]);
    if (depth > 512) {
      expect(call("parse_string", input)).toEqual(fail("DepthLimit"));
      expect(call("write", tree, true, true)).toEqual(fail("InvalidValue"));
    } else {
      // Compare output rather than deeply recursive JavaScript assertion helpers.
      expect(text(call("write", value(call("parse_string", input)), false, false))).toBe(input);
      expect(text(call("write", tree, false, false))).toBe(input);
      expect(
        text(
          call(
            "write",
            value(call("parse_string", text(call("write", tree, true, true)))),
            false,
            false,
          ),
        ),
      ).toBe(input);
    }
    const path = join(dir, `depth-${depth}.json`);
    writeFileSync(path, input);
    expect(native("parse", path)).toBe(depth <= 512 ? "accept" : "reject");
  });

const largeShapes = ["string", "number", "array", "object"];
for (const size of [65536, 1048576])
  for (const shape of largeShapes)
    test(
      `.mjs ${shape} traversals are stack safe at ${size} bytes`,
      () => {
        let input: string;
        switch (shape) {
          case "string":
            input = '"' + "a".repeat(size - 2) + '"';
            break;
          case "number":
            input = "1".repeat(size);
            break;
          case "array":
            input = "[" + "0,".repeat(Math.floor((size - 3) / 2)) + "0]";
            break;
          case "object":
            input = "{" + '"a":0,'.repeat(Math.floor((size - 7) / 6)) + '"a":0}';
            break;
          default:
            throw new Error("Unknown fixture shape");
        }
        const parsed = value(call("parse", bytes(input)));
        expect(text(call("write", parsed, false, false))).toBe(input);
      },
      shape === "array" && size === 1048576 ? 60000 : 30000,
    );

test("native 1 MiB byte parsing is below 200 ms, including UTF-8 decoding", () => {
  const path = join(dir, "megabyte.json");
  writeFileSync(path, '"' + "a".repeat(1048574) + '"');
  const result = native("bench", path);
  expect(result).toMatch(/^accept:\d+$/);
  const elapsed = Number(result.split(":")[1]);
  console.log(`BND-28 native 1048576-byte parse: ${elapsed} ms (IO.now, one runtime thread)`);
  expect(elapsed).toBeLessThan(200);
});

test("pure HTTP helpers preserve typed errors and emit JSON UTF-8 octets", () => {
  const tree = string("é😀");
  expect(call("request", bytes('"é😀"'))).toEqual(done(tree));
  expect(call("request", bytes("{"))).toEqual(fail("Syntax"));
  expect(call("response", 201, tree)).toEqual(
    done({
      $: "Res",
      status: 201,
      headers: list([
        { $: "Header", name: "content-type", value: bytes("application/json; charset=utf-8") },
      ]),
      body: bytes('"é😀"'),
      representation: { $: "None" },
    }),
  );
  expect(call("response", 200, number("NaN"))).toEqual(fail("InvalidValue"));
});

test("unsigned integer conversion checks grammar and overflow without rounding on both targets", () => {
  const path = join(dir, "unsigned.txt");
  for (const n of ["0", "42", "4294967295"]) {
    expect(call("to_u32", number(n))).toEqual({ $: "Some", value: Number(n) });
    writeFileSync(path, n);
    expect(native("u32", path)).toBe(n);
  }
  for (const n of ["-0", "-1", "1.0", "1e2", "4294967296", "01", ""]) {
    expect(call("to_u32", number(n))).toEqual({ $: "None" });
    writeFileSync(path, n);
    expect(native("u32", path)).toBe("none");
  }
});
