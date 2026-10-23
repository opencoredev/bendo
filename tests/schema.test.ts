import { compile, SLOW_TEST_TIMEOUT_MS } from "./harness.ts";
import { describe, expect, test } from "bun:test";
import { pathToFileURL } from "node:url";

// Compile once, outside any test's timeout, through the shared fixture cache.
const nativePath = compile("tests/fixtures/schema/native.bend", "native");
const modulePath = compile("tests/fixtures/schema/consumer.bend", "mjs");
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
good("slug", "VString", ...["a", "a-b", "abc-def-g", "0-9", "ab-cd-ef12"].map(text));
bad("slug", ...["", "-", "-a", "a-", "a--b", "A", "a_b", "a b", "é", "a-b\n"].map(text));
good("zip", "VString", ...["12345", "12345-6789", "00000-0000"].map(text));
bad(
  "zip",
  ...["", "1234", "123456", "12345-", "12345-678", "12345-67890", "1234a", "12345 6789"].map(text),
);
good("nested", "VString", ...["", "<ab>", "<ab1>", "<ab12ab>", "<ab><ab99ab0>"].map(text));
bad("nested", ...["<>", "<ab123>", "<ababab>", "<ab", "ab>", "<aB>"].map(text));
good("empties", "VString", text(""));
bad("empties", text("a"));
good("nullable-body", "VString", ...["", "a", "aaa", "aaaaaaa"].map(text));
bad("nullable-body", text("b"));
good("bounds", "VString", ...["abab", "ababab"].map(text));
bad("bounds", ...["", "ab", "abababab", "aba", "abba"].map(text));
good("astral", "VString", ...["😀é", "😀é😀é"].map(text));
bad("astral", ...["", "😀", "é", "😀é😀é😀é", "é😀"].map(text));
good("slug-short", "VString", ...["abc", "a-b", "abcd-efg"].map(text));
bad("slug-short", ...["ab", "abcd-efgh", "a--"].map(text));
good(
  "punctuation",
  "VString",
  ...["^$\\.*+?()[]{}|/-", "^$\\.*+?()[]{}|/-\u0000", "^$\\.*+?()[]{}|/-\u007f"].map(text),
);
bad(
  "punctuation",
  ...[
    "",
    "^$\\.*+?()[]{}|/",
    "^$\\.*+?()[]{}|/-a",
    "^$\\.*+?()[]{}|/-\u0000\u0000",
    "a$\\.*+?()[]{}|/-",
  ].map(text),
);
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
  "bad-literal-pattern",
  "bad-nested-count",
]) {
  for (const input of ["true", text("a"), "1"])
    cases.push({ schema, input, result: "error:InvalidSchema" });
}

// The independent specification compares exact naturals and tries every split
// of a string, so it only runs on small numbers and short pattern inputs.
const costly = new Set([
  "range",
  "equal",
  "huge",
  "tiny",
  "exponent",
  "numeric-literal",
  "zero-literal",
  "bad-bound",
  "bad-enum",
]);
const patterns = new Set([
  "slug",
  "zip",
  "nested",
  "nullable-body",
  "bounds",
  "astral",
  "slug-short",
]);
function specCheap(c: Case): boolean {
  if (costly.has(c.schema)) return false;
  return !patterns.has(c.schema) || [...String(JSON.parse(c.input))].length <= 4;
}

describe("scalar schemas through real native and .mjs consumers", () => {
  for (const c of cases)
    test(`${c.schema}: ${c.input} → ${c.result.startsWith("ok:") ? "accept" : "reject"}`, () => {
      expect(native(c.schema, c.input)).toBe(c.result);
      const parsed = call("parse", c.input);
      const tree = value(parsed);
      const schema = call("schema", c.schema);
      expect(call("run", c.schema, parsed)).toBe(c.result);
      if (specCheap(c)) expect(call("satisfies", schema, tree)).toBe(c.result.startsWith("ok:"));
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
      if (name === "number" || name === "integer")
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

test(
  ".mjs scalar checks stay stack safe for long strings, decimals, patterns and enums",
  () => {
    const long = "a".repeat(100000);
    for (const name of ["text", "star", "plus"]) {
      expect(value(call("decode", call("schema", name), { $: "JString", value: long }))).toEqual({
        $: "VString",
        value: long,
      });
    }
    const rejected = (name: string, input: string) =>
      call("report", call("decode", call("schema", name), { $: "JString", value: input }));
    expect(rejected("star", long + "b")).toBe("error:Constraint");
    for (const name of ["email", "url"]) expect(rejected(name, long)).toBe("error:Constraint");
    const digits = "9".repeat(100000);
    expect(
      value(call("decode", call("schema", "integer"), { $: "JNumber", value: digits })),
    ).toEqual({ $: "VInteger", value: digits });
    expect(call("order", "1e" + digits, "2e" + digits)).toEqual({ $: "LT" });
    expect(call("order", "1e-" + digits, "2e-" + digits)).toEqual({ $: "LT" });
  },
  SLOW_TEST_TIMEOUT_MS,
);

const patternNames = [
  "pattern",
  "star",
  "plus",
  "optional",
  "pattern-exact",
  "no-ranges",
  "slug",
  "zip",
  "nested",
  "empties",
  "nullable-body",
  "bounds",
  "astral",
  "punctuation",
];

function patternSource(name: string): string {
  const source = call("source", call("pattern_of", name));
  if (typeof source !== "string") throw new Error("Expected a source string");
  return source;
}

// Every string over the alphabet up to the given length, shortest first.
function words(alphabet: string[], max: number): string[] {
  const out = [""];
  let layer = [""];
  for (let n = 0; n < max; n++) {
    layer = layer.flatMap((w) => alphabet.map((c) => w + c));
    out.push(...layer);
  }
  return out;
}

test("rendered ECMAScript sources are exact for slug and ZIP", () => {
  expect(patternSource("slug")).toBe(
    "^(?:(?:[\\x61-\\x7a\\x30-\\x39])+(?:\\x2d(?:[\\x61-\\x7a\\x30-\\x39])+)*)(?![\\s\\S])",
  );
  expect(patternSource("zip")).toBe(
    "^(?:(?:[\\x30-\\x39]){5}(?:\\x2d(?:[\\x30-\\x39]){4})?)(?![\\s\\S])",
  );
  expect(patternSource("astral")).toBe("^(?:(?:\\ud83d\\ude00\\u00e9){1,2})(?![\\s\\S])");
  expect(patternSource("no-ranges")).toBe("^(?:(?:[^\\s\\S])*)(?![\\s\\S])");
});

test(
  "the matcher, the specification and both ECMAScript flag modes agree",
  () => {
    const alphabet = ["a", "b", "0", "1", "-", "<", ">", "😀", "é", "\n", "^", "$", "\\", "\u0000"];
    const exhaustive = words(alphabet, 3);
    const generated: string[] = [];
    let seed = 37;
    const next = () => {
      seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
      return seed;
    };
    for (let i = 0; i < 400; i++) {
      let w = "";
      for (let n = next() % 16; n > 0; n--) w += alphabet[next() % alphabet.length];
      generated.push(w);
    }
    for (const name of patternNames) {
      const pattern = call("pattern_of", name);
      expect(call("pattern_valid", pattern)).toBe(true);
      const source = patternSource(name);
      const plain = new RegExp(source);
      const unicode = new RegExp(source, "u");
      const samples = [
        ...exhaustive,
        ...generated,
        "abc-def-g",
        "12345-6789",
        "<ab12ab><ab>",
        "aaaaaaa",
        "ababab",
        "😀é😀é",
        "^$\\.*+?()[]{}|/-\u007f",
        "a\n",
        "a\r\n",
        "a\u2028",
      ];
      for (const w of samples) {
        const got = call("matches", pattern, w);
        expect({ name, w, got }).toEqual({ name, w, got: plain.test(w) });
        expect({ name, w, got }).toEqual({ name, w, got: unicode.test(w) });
        if ([...w].length <= 2)
          expect({ name, w, spec: call("pattern_spec", pattern, w) }).toEqual({
            name,
            w,
            spec: got,
          });
      }
    }
  },
  SLOW_TEST_TIMEOUT_MS,
);

test(
  "long pattern inputs scan in linear time without stack growth",
  () => {
    const slug = call("pattern_of", "slug");
    const zip = call("pattern_of", "zip");
    const long = "ab-".repeat(40000) + "z9";
    const started = performance.now();
    expect(call("matches", slug, long)).toBe(true);
    expect(call("matches", slug, long + "-")).toBe(false);
    expect(call("matches", slug, "a" + "-".repeat(100000))).toBe(false);
    expect(call("matches", zip, "1".repeat(100000))).toBe(false);
    expect(performance.now() - started).toBeLessThan(10000);
    expect(native("slug", text(long))).toBe(`ok:VString:${text(long)}`);
    expect(native("slug", text(long + "-"))).toBe("error:Constraint");
  },
  SLOW_TEST_TIMEOUT_MS,
);

type RangeList =
  | { $: "Nil" }
  | { $: "Con"; head: { $: "Range"; lo: number; hi: number }; tail: RangeList };
type PatternData =
  | { $: "Literal"; text: string }
  | { $: "Class"; ranges: RangeList }
  | { $: "Cat"; first: PatternData; second: PatternData }
  | {
      $: "Repeat";
      body: PatternData;
      min: number;
      max: { $: "Some"; value: number } | { $: "None" };
    };
const letterA: PatternData = {
  $: "Class",
  ranges: { $: "Con", head: { $: "Range", lo: 97, hi: 97 }, tail: { $: "Nil" } },
};
const upTo = (body: PatternData, n: number): PatternData => ({
  $: "Repeat",
  body,
  min: 0,
  max: { $: "Some", value: n },
});
const anyCount = (body: PatternData): PatternData => ({
  $: "Repeat",
  body,
  min: 0,
  max: { $: "None" },
});
const patternSchema = (pattern: PatternData) => ({
  $: "StringSchema",
  min_len: 0,
  max_len: { $: "None" },
  pattern: { $: "Some", value: pattern },
  format: { $: "Plain" },
});
const decodeText = (pattern: PatternData, input: string) =>
  call("report", call("decode", patternSchema(pattern), { $: "JString", value: input }));

test("caps a pattern's expanded size at 128 nodes in the decoder and the specification", () => {
  // [a]{0,127} writes out 1 + 127 nodes; [a]{0,128} is one past the cap.
  for (const [pattern, ok] of [
    [upTo(letterA, 127), true],
    [upTo(letterA, 128), false],
    [upTo(upTo(letterA, 10), 11), true],
    [upTo(upTo(letterA, 10), 12), false],
  ] as const) {
    expect(call("pattern_valid", pattern)).toBe(ok);
    const tree = { $: "JString", value: "a" };
    expect(call("satisfies", patternSchema(pattern), tree)).toBe(ok);
    expect(decodeText(pattern, "a")).toBe(ok ? 'ok:VString:"a"' : "error:InvalidSchema");
  }
  // Huge counts are rejected before any size arithmetic could pass 2^48.
  // The specification is exponential in counts, so it is not run here.
  const huge = 4294967295;
  for (const pattern of [upTo(letterA, huge), upTo(upTo(upTo(letterA, huge), huge), huge)]) {
    expect(decodeText(pattern, "a")).toBe("error:InvalidSchema");
    // The specification checks counts before it measures, so it never
    // multiplies one past 2^48 either.
    expect(call("spec_pattern_ok", pattern)).toBe(false);
  }
});

test(
  "nested counted repetitions stay fast: over the cap they are rejected, under it they scan",
  () => {
    // (?:(?:(?:a){0,10}){0,10}){0,10} expands to 1111 nodes, so it is invalid.
    const over = upTo(upTo(upTo(letterA, 10), 10), 10);
    // (?:(?:a){0,10}){0,10} expands to 111 and (?:(?:(?:(?:a){0,2}){0,2}){0,2})* to 32.
    const under = upTo(upTo(letterA, 10), 10);
    const starred = anyCount(upTo(upTo(upTo(letterA, 2), 2), 2));
    for (const n of [30, 10000]) {
      const input = "a".repeat(n);
      let started = performance.now();
      expect(decodeText(over, input)).toBe("error:InvalidSchema");
      expect(performance.now() - started).toBeLessThan(1000);
      started = performance.now();
      expect(call("matches", under, input)).toBe(n <= 100);
      expect(performance.now() - started).toBeLessThan(1000);
      started = performance.now();
      expect(call("matches", starred, input)).toBe(true);
      expect(performance.now() - started).toBeLessThan(1000);
    }
    for (const pattern of [under, starred]) {
      const source = call("source", pattern);
      if (typeof source !== "string") throw new Error("Expected a source string");
      for (const n of [0, 1, 7, 99, 100, 101, 1000])
        expect(call("matches", pattern, "a".repeat(n))).toBe(
          new RegExp(source).test("a".repeat(n)),
        );
    }
  },
  SLOW_TEST_TIMEOUT_MS,
);

// The widest shapes the size cap admits: every scalar keeps most nodes live.
const worstNames = ["worst-2x32", "worst-6x16", "worst-1x42", "starred-nested"];

test(
  "the automaton agrees with the derivative matcher and the specification on the widest shapes",
  () => {
    const short = words(["a", "b", "A"], 4);
    for (const name of [...worstNames, "nested-10x11", ...patternNames]) {
      const pattern = call("pattern_of", name);
      expect(call("pattern_valid", pattern)).toBe(true);
      const long = ["a".repeat(99), "a".repeat(100), "a".repeat(111), "a".repeat(200) + "A"];
      for (const w of [...short, ...long]) {
        const got = call("matches", pattern, w);
        expect({ name, w, got }).toEqual({ name, w, got: call("derive_matches", pattern, w) });
        if ([...w].length <= 2)
          expect({ name, w, spec: call("pattern_spec", pattern, w) }).toEqual({
            name,
            w,
            spec: got,
          });
      }
    }
  },
  SLOW_TEST_TIMEOUT_MS,
);

function nativeTimed(schema: string, input: string): { out: string; ms: number } {
  const started = performance.now();
  const r = Bun.spawnSync([
    "timeout",
    "--foreground",
    "60s",
    nativePath,
    schema,
    input,
    "+RTS",
    "--threads",
    "1",
    "-RTS",
  ]);
  expect(r.exitCode).toBe(0);
  return { out: r.stdout.toString().trimEnd(), ms: performance.now() - started };
}

test(
  "the widest valid patterns scan 100k scalars in linear time, natively and in .mjs",
  () => {
    // About 2 µs per scalar on an idle machine; the derivative matcher took
    // 3.5 ms per scalar here, so 100k scalars would take minutes.
    const long = "a".repeat(100000);
    for (const name of worstNames) {
      const pass = nativeTimed(name, text(long));
      expect(pass.out).toBe(`ok:VString:${text(long)}`);
      expect(pass.ms).toBeLessThan(20000);
      const fail = nativeTimed(name, text(long + "A"));
      expect(fail.out).toBe("error:Constraint");
      expect(fail.ms).toBeLessThan(20000);
      const pattern = call("pattern_of", name);
      const started = performance.now();
      expect(call("matches", pattern, long)).toBe(true);
      expect(call("matches", pattern, long + "A")).toBe(false);
      expect(performance.now() - started).toBeLessThan(20000);
    }
  },
  SLOW_TEST_TIMEOUT_MS,
);

test(
  "arcs whose keys collide stay distinct, so the table is checked and scanned",
  () => {
    // The literal U+0000 U+0001 has two arcs with equal keys. Merging them by
    // key dropped one, failed the check and fell back to the derivative
    // matcher: 11 s natively to reject 1,000 scalars.
    expect(call("colliding_keys")).toBe(true);
    const pattern = call("pattern_of", "collision");
    expect(call("pattern_valid", pattern)).toBe(true);
    expect(call("table_ok", pattern)).toBe(true);
    const tail = "\u0000\u0001";
    for (const n of [1000, 100000]) {
      const long = "a".repeat(n);
      const reject = nativeTimed("collision", text(long));
      expect(reject.out).toBe("error:Constraint");
      expect(reject.ms).toBeLessThan(5000);
      const accept = nativeTimed("collision", text(long + tail));
      expect(accept.out).toBe(`ok:VString:${text(long + tail)}`);
      expect(accept.ms).toBeLessThan(5000);
      const started = performance.now();
      expect(call("matches", pattern, long)).toBe(false);
      expect(call("matches", pattern, long + tail)).toBe(true);
      expect(performance.now() - started).toBeLessThan(5000);
    }
    for (const w of ["", tail, "ab" + tail, "a" + tail + "a", "\u0000", "A" + tail]) {
      expect({ w, got: call("matches", pattern, w) }).toEqual({
        w,
        got: call("derive_matches", pattern, w),
      });
    }
  },
  SLOW_TEST_TIMEOUT_MS,
);

// Random patterns: small ones of every shape, and wide starred sequences near
// the size cap like the collision case.
function patternFuzz(seed: number): () => PatternData {
  let state = seed;
  const next = (n: number) => {
    state = (Math.imul(state, 1664525) + 1013904223) >>> 0;
    return state % n;
  };
  const scalars = ["a", "b", "z", "0", "-", "\u0000", "\u0001", "\u007f", "é", "😀"];
  const ranges: [number, number][] = [
    [97, 97],
    [97, 122],
    [48, 57],
    [0, 1],
    [98, 99],
    [0, 127],
  ];
  const literal = (): PatternData => {
    let value = "";
    for (let n = next(4); n > 0; n--) value += scalars[next(scalars.length)] ?? "";
    return { $: "Literal", text: value };
  };
  const pickRange = () => ranges[next(ranges.length)] ?? [97, 97];
  const rangeList = (n: number): RangeList => {
    if (n === 0) return { $: "Nil" };
    const [lo, hi] = pickRange();
    return { $: "Con", head: { $: "Range", lo, hi }, tail: rangeList(n - 1) };
  };
  const leaf = (): PatternData =>
    next(2) === 0 ? literal() : { $: "Class", ranges: rangeList(1 + next(2)) };
  const repeat = (body: PatternData): PatternData => {
    const min = next(3);
    const max: { $: "Some"; value: number } | { $: "None" } =
      next(3) === 0 ? { $: "None" } : { $: "Some", value: min + next(5) };
    return { $: "Repeat", body, min, max };
  };
  const small = (depth: number): PatternData => {
    if (depth === 0) return leaf();
    switch (next(3)) {
      case 0:
        return leaf();
      case 1:
        return { $: "Cat", first: small(depth - 1), second: small(depth - 1) };
      default:
        return repeat(small(depth - 1));
    }
  };
  const wide = (): PatternData => {
    // Sized to land at or just under the cap: each part adds n + 2 nodes.
    const n = 1 + next(6);
    const count = Math.max(1, Math.floor(124 / (n + 2)) - next(4));
    const part = upTo({ $: "Class", ranges: rangeList(1) }, n);
    let body: PatternData = part;
    for (let i = 1; i < count; i++) body = { $: "Cat", first: part, second: body };
    return { $: "Cat", first: anyCount(body), second: literal() };
  };
  return () => (next(3) === 0 ? wide() : small(1 + next(5)));
}

test(
  "every generated in-cap pattern builds a checked table that agrees with the derivative matcher",
  () => {
    const gen = patternFuzz(20261023);
    const words = ["", "a", "b", "ab", "aa", "a-", "\u0000\u0001", "zz0", "😀é", "aaaaaaa"];
    let valid = 0;
    let wide = 0;
    let most = 0;
    for (let i = 0; i < 1000; i++) {
      const pattern = gen();
      if (call("pattern_valid", pattern) !== true) continue;
      valid++;
      const size = call("pattern_size", pattern);
      if (typeof size === "number" && size >= 96) wide++;
      expect({ pattern, ok: call("table_ok", pattern) }).toEqual({ pattern, ok: true });
      const nodes = call("table_nodes", pattern);
      if (typeof nodes === "number") most = Math.max(most, nodes);
      for (const w of words) {
        expect({ pattern, w, got: call("matches", pattern, w) }).toEqual({
          pattern,
          w,
          got: call("derive_matches", pattern, w),
        });
      }
    }
    // The run covers many valid patterns, many near the cap, and wide tables.
    expect(valid).toBeGreaterThan(900);
    expect(wide).toBeGreaterThan(250);
    expect(most).toBeGreaterThan(64);
  },
  SLOW_TEST_TIMEOUT_MS,
);

test(
  "length limits reject a text before the pattern runs",
  () => {
    // Matching a million scalars against this pattern takes seconds in .mjs;
    // max_len 1 rejects it after counting.
    const huge = { $: "JString", value: "a".repeat(1000000) };
    const started = performance.now();
    expect(call("report", call("decode", call("schema", "worst-short"), huge))).toBe(
      "error:Constraint",
    );
    expect(performance.now() - started).toBeLessThan(1000);
    expect(nativeTimed("worst-short", text("a".repeat(100000))).out).toBe("error:Constraint");
    expect(nativeTimed("worst-short", text("a")).out).toBe('ok:VString:"a"');
  },
  SLOW_TEST_TIMEOUT_MS,
);

test(
  "validates every enum member before matching and scans wide enums without recursion growth",
  () => {
    type Items = { $: "Nil" } | { $: "Con"; head: { $: "JNumber"; value: string }; tail: Items };
    let items: Items = { $: "Nil" };
    for (let i = 0; i < 20000; i++)
      items = { $: "Con", head: { $: "JNumber", value: String(i) }, tail: items };
    const schema = { $: "EnumSchema", values: items };
    const tree = { $: "JNumber", value: "0.0" };
    expect(value(call("decode", schema, tree))).toEqual({ $: "VLiteral", value: tree });
    expect(call("report", call("decode", schema, { $: "JNumber", value: "20000" }))).toBe(
      "error:Constraint",
    );
  },
  SLOW_TEST_TIMEOUT_MS,
);
