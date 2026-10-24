import { compile, SLOW_TEST_TIMEOUT_MS } from "./harness.ts";
import { afterAll, describe, expect, test } from "bun:test";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

// BND-35: defaults, coercion for text sources and error lists. Compile once,
// outside any test's timeout, through the shared fixture cache.
const nativePath = compile("tests/fixtures/schema-errors/native.bend", "native");
const modulePath = compile("tests/fixtures/schema-errors/consumer.bend", "mjs");
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
function text(name: string, ...args: unknown[]): string {
  const out = call(name, ...args);
  if (typeof out !== "string") throw new Error(`${name} did not return a string`);
  return out;
}
function flag(name: string, ...args: unknown[]): boolean {
  const out = call(name, ...args);
  if (typeof out !== "boolean") throw new Error(`${name} did not return a boolean`);
  return out;
}

const scratch = mkdtempSync(join(tmpdir(), "bendo-schema-errors-"));
afterAll(() => rmSync(scratch, { recursive: true, force: true }));
let files = 0;

type Mode = "json" | "text" | "coerce" | "spec-coerce" | "count-json" | "count-text";
const mjsName = {
  json: "run",
  text: "run_text",
  coerce: "run_coerce",
  "spec-coerce": "run_spec_coerce",
  "count-json": "run_count_json",
  "count-text": "run_count_text",
} satisfies Record<Mode, string>;

/** Runs every input through one native process, one input per line. */
function nativeLines(mode: Mode, schema: string, inputs: string[]): string[] {
  for (const input of inputs) if (input.includes("\n")) throw new Error("inputs are single lines");
  const path = join(scratch, `${files++}.txt`);
  writeFileSync(path, inputs.join("\n"));
  const r = Bun.spawnSync([
    "timeout",
    "--foreground",
    "60s",
    nativePath,
    mode,
    schema,
    path,
    "+RTS",
    "--threads",
    "1",
    "-RTS",
  ]);
  expect(r.exitCode).toBe(0);
  const out = r.stdout.toString().trimEnd().split("\n");
  expect(out.length).toBe(inputs.length);
  return out;
}
function mjs(mode: Mode, schema: string, input: string): string {
  return text(mjsName[mode], schema, input);
}
function both(mode: Mode, schema: string, input: string): string {
  const [fromNative] = nativeLines(mode, schema, [input]);
  if (fromNative === undefined) throw new Error("no native output");
  expect(mjs(mode, schema, input)).toBe(fromNative);
  return fromNative;
}

type ErrorJson = { path: (string | number)[]; code: string; message: string };
function errorsOf(result: string): ErrorJson[] {
  if (!result.startsWith("errors:")) throw new Error(`expected errors, got ${result}`);
  const parsed: unknown = JSON.parse(result.slice("errors:".length));
  if (!Array.isArray(parsed)) throw new Error("errors are not an array");
  return parsed.map((e: unknown): ErrorJson => {
    if (typeof e !== "object" || e === null) throw new Error("error is not an object");
    const path: unknown = Reflect.get(e, "path");
    const code: unknown = Reflect.get(e, "code");
    const message: unknown = Reflect.get(e, "message");
    if (!Array.isArray(path) || typeof code !== "string" || typeof message !== "string")
      throw new Error("malformed error");
    const parts = path.map((p: unknown) => {
      if (typeof p === "string" || typeof p === "number") return p;
      throw new Error("malformed path segment");
    });
    return { path: parts, code, message };
  });
}
function paths(result: string): string[] {
  return errorsOf(result).map((e) => `/${e.path.join("/")}`);
}

const QUERY_DEFAULTS = "limit=i10,page=-,tag=-,flag=False,ratio=-,mode=-,maybe=-,pick=-,ids=-";

describe("defaults fill absent fields", () => {
  test("an empty query takes every default", () => {
    expect(both("text", "query", "{}")).toBe(`ok:{${QUERY_DEFAULTS}}`);
    expect(both("json", "query", "{}")).toBe(`ok:{${QUERY_DEFAULTS}}`);
  });
  test("a present value replaces the default", () => {
    expect(both("json", "query", '{"limit":3,"flag":true}')).toBe(
      "ok:{limit=i3,page=-,tag=-,flag=True,ratio=-,mode=-,maybe=-,pick=-,ids=-}",
    );
  });
  test("a default object is decoded, and its own defaults fill in", () => {
    expect(both("json", "nested-default", "{}")).toBe('ok:{p={name="anon",age=-,role=lit:"user"}}');
    expect(both("json", "nested-default", '{"p":{"name":"Ada","role":"admin"}}')).toBe(
      'ok:{p={name="Ada",age=-,role=lit:"admin"}}',
    );
  });
  test("a default its field's schema rejects makes the schema invalid", () => {
    expect(both("json", "bad-default", "{}")).toBe(
      'errors:[{"path":[],"code":"invalid_schema","message":"invalid schema"}]',
    );
    expect(both("json", "bad-default", '{"n":1}')).toBe(
      'errors:[{"path":[],"code":"invalid_schema","message":"invalid schema"}]',
    );
  });
});

describe("text sources coerce, JSON bodies do not", () => {
  test("numbers, booleans and repeated keys", () => {
    expect(
      both(
        "text",
        "query",
        '{"limit":"20","tag":"a","tag":"b","flag":"true","ratio":"1.5e3","page":"-0"}',
      ),
    ).toBe(
      'ok:{limit=i20,page=i-0,tag=["a","b"],flag=True,ratio=n1.5e3,mode=-,maybe=-,pick=-,ids=-}',
    );
    expect(both("text", "query", '{"tag":"a"}')).toBe(
      'ok:{limit=i10,page=-,tag=["a"],flag=False,ratio=-,mode=-,maybe=-,pick=-,ids=-}',
    );
    expect(both("text", "query", '{"ids":"1","x":"y","ids":"2"}')).toBe(
      "ok:{limit=i10,page=-,tag=-,flag=False,ratio=-,mode=-,maybe=-,pick=-,ids=[i1,i2]}",
    );
    expect(both("text", "query", '{"maybe":"7","mode":"b","flag":"false"}')).toBe(
      'ok:{limit=i10,page=-,tag=-,flag=False,ratio=-,mode=lit:"b",maybe=i7,pick=-,ids=-}',
    );
  });
  test("the coerced value keeps member order and merges at the first occurrence", () => {
    const input = '{"x":"1","ids":"1","limit":"5","ids":"z","tag":"t","flag":"no"}';
    const want = '{"x":"1","ids":[1,"z"],"limit":5,"tag":["t"],"flag":"no"}';
    expect(both("coerce", "query", input)).toBe(want);
    expect(both("spec-coerce", "query", input)).toBe(want);
  });
  test("only exact lexical forms coerce", () => {
    // A leading zero, a plus sign, a space or capitals leave the string alone,
    // so the schema reports a type mismatch at that key.
    const unchanged: [string, string][] = [
      ["limit", "010"],
      ["limit", "+1"],
      ["page", " 1"],
      ["flag", "TRUE"],
      ["flag", "1"],
      ["maybe", "null"],
    ];
    for (const [key, value] of unchanged) {
      const result = both("text", "query", JSON.stringify({ [key]: value }));
      expect(errorsOf(result)).toEqual([
        { path: [key], code: "type_mismatch", message: "expected schema scalar kind" },
      ]);
    }
    // A number token that is not a lexical integer is a constraint failure.
    expect(errorsOf(both("text", "query", '{"limit":"1e2"}'))).toEqual([
      { path: ["limit"], code: "constraint", message: "value does not satisfy scalar checks" },
    ]);
    // Unions and enums see the raw string.
    expect(both("text", "query", '{"pick":"12"}')).toBe(
      'ok:{limit=i10,page=-,tag=-,flag=False,ratio=-,mode=-,maybe=-,pick=#1:"12",ids=-}',
    );
  });
  test("a JSON body is decoded exactly as sent", () => {
    expect(errorsOf(both("json", "query", '{"limit":"20"}'))).toEqual([
      { path: ["limit"], code: "type_mismatch", message: "expected schema scalar kind" },
    ]);
    expect(both("json", "query", '{"limit":20,"tag":["a"]}')).toBe(
      'ok:{limit=i20,page=-,tag=["a"],flag=False,ratio=-,mode=-,maybe=-,pick=-,ids=-}',
    );
  });
  test("a non-array key repeated in a text source is a duplicate", () => {
    expect(errorsOf(both("text", "query", '{"page":"1","page":"2"}'))).toEqual([
      { path: ["page"], code: "constraint", message: "duplicate key" },
    ]);
  });
});

describe("every failing location is listed with its path", () => {
  test("errors from every field and item, in a stable JSON shape", () => {
    const result = both(
      "text",
      "strict-query",
      '{"limit":"0","extra":"1","tag":"","flag":"yes","page":"1.5","ratio":"x","mode":"c","ids":"1","ids":"q"}',
    );
    expect(result).toBe(
      "errors:" +
        JSON.stringify([
          { path: ["extra"], code: "constraint", message: "object has an undeclared key" },
          { path: ["limit"], code: "constraint", message: "value does not satisfy scalar checks" },
          { path: ["page"], code: "constraint", message: "value does not satisfy scalar checks" },
          { path: ["tag", 0], code: "constraint", message: "value does not satisfy scalar checks" },
          { path: ["flag"], code: "type_mismatch", message: "expected schema scalar kind" },
          { path: ["ratio"], code: "type_mismatch", message: "expected schema scalar kind" },
          { path: ["mode"], code: "constraint", message: "value does not satisfy scalar checks" },
          { path: ["ids", 1], code: "type_mismatch", message: "expected schema scalar kind" },
        ]),
    );
  });
  test("nested objects and arrays", () => {
    const input =
      '{"id":"x","people":[{"name":"","age":200,"extra":1},{"age":-1},{"name":"Bob","role":"root"}],"more":true}';
    expect(paths(both("json", "people", input))).toEqual([
      "/more",
      "/id",
      "/people/0/extra",
      "/people/0/name",
      "/people/0/age",
      "/people/1/name",
      "/people/1/age",
      "/people/2/role",
    ]);
    expect(errorsOf(both("json", "people", input))[5]).toEqual({
      path: ["people", 1, "name"],
      code: "constraint",
      message: "missing required key",
    });
  });
  test("nothing is listed below a failed length or kind check, or inside a union", () => {
    expect(
      paths(both("json", "people", `{"id":1,"people":[${Array(51).fill("{}").join(",")}]}`)),
    ).toEqual(["/people"]);
    expect(paths(both("json", "people", '{"id":1,"people":{"0":{}}}'))).toEqual(["/people"]);
    expect(errorsOf(both("json", "union", '"abc"'))).toEqual([
      { path: [], code: "constraint", message: "value matches no union member" },
    ]);
  });
  test("the list stops at 100 errors", () => {
    const strings = `[${Array(1000).fill('"x"').join(",")}]`;
    const listed = paths(both("json", "ints", strings));
    expect(listed).toEqual(Array.from({ length: 100 }, (_, i) => `/${i}`));
    const keys = `{${Array.from({ length: 1000 }, (_, i) => `"k${i}":1`).join(",")}}`;
    expect(paths(both("json", "wide", keys))).toEqual(
      Array.from({ length: 100 }, (_, i) => `/k${i}`),
    );
  });
});

// Seeded inputs for the differential tests.
function random(seed: number): () => number {
  let a = seed;
  return () => {
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
function picker(next: () => number) {
  const int = (n: number) => Math.floor(next() * n);
  const pick = <T>(xs: readonly [T, ...T[]]): T => xs[int(xs.length)] ?? xs[0];
  return { int, pick };
}

const QUERY_KEYS = [
  "limit",
  "page",
  "tag",
  "flag",
  "ratio",
  "mode",
  "maybe",
  "pick",
  "ids",
  "extra",
  "z",
] as const;
const QUERY_VALUES = [
  "",
  "0",
  "-0",
  "1",
  "10",
  "100",
  "101",
  "010",
  "1.5",
  "1e2",
  "2E-1",
  "-3",
  "+1",
  " 1",
  "1.",
  ".5",
  "true",
  "false",
  "TRUE",
  "null",
  "a",
  "b",
  "ab",
  "abc",
  "x y",
] as const;
type Member = [string, string];
function queryInputs(seed: number, count: number): Member[][] {
  const { int, pick } = picker(random(seed));
  return Array.from({ length: count }, () =>
    Array.from({ length: int(9) }, (): Member => [pick(QUERY_KEYS), pick(QUERY_VALUES)]),
  );
}
function objectText(members: Member[]): string {
  return `{${members.map(([k, v]) => `${JSON.stringify(k)}:${JSON.stringify(v)}`).join(",")}}`;
}

// An independent reading of the coercion rules in docs/data/schema.md for the
// query schema: number tokens under number and integer fields (and the
// nullable integer), "true"/"false" under the boolean, members of array
// fields gathered at the first one, everything else unchanged.
const NUMBER = /^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?$/;
function asNumber(v: string): string {
  return NUMBER.test(v) ? v : JSON.stringify(v);
}
function coerceValue(key: string, v: string): string {
  switch (key) {
    case "limit":
    case "page":
    case "ratio":
    case "maybe":
      return asNumber(v);
    case "flag":
      return v === "true" || v === "false" ? v : JSON.stringify(v);
    default:
      return JSON.stringify(v);
  }
}
function coerceQuery(members: Member[]): string {
  const out: string[] = [];
  const gathered = new Set<string>();
  for (const [k, v] of members) {
    if (k === "tag" || k === "ids") {
      if (gathered.has(k)) continue;
      gathered.add(k);
      const items = members
        .filter(([key]) => key === k)
        .map(([, value]) => (k === "ids" ? asNumber(value) : JSON.stringify(value)));
      out.push(`${JSON.stringify(k)}:[${items.join(",")}]`);
      continue;
    }
    out.push(`${JSON.stringify(k)}:${coerceValue(k, v)}`);
  }
  return `{${out.join(",")}}`;
}

// Each slice runs one native process and the same inputs through .mjs.
const SLICES = [1, 2, 3];
describe("coercion and defaults agree natively and in .mjs over seeded text inputs", () => {
  for (const slice of SLICES)
    test(
      `slice ${slice}`,
      () => {
        const members = queryInputs(350 + slice, 700);
        const inputs = members.map(objectText);
        const coerced = nativeLines("coerce", "query", inputs);
        const specCoerced = nativeLines("spec-coerce", "query", inputs);
        const decoded = nativeLines("text", "query", inputs);
        const strict = nativeLines("text", "strict-query", inputs);
        let accepted = 0;
        for (const [i, input] of inputs.entries()) {
          const row = members[i];
          if (row === undefined) throw new Error("missing row");
          const want = coerceQuery(row);
          expect({ input, coerced: coerced[i] }).toEqual({ input, coerced: want });
          expect(specCoerced[i]).toBe(want);
          expect(mjs("coerce", "query", input)).toBe(want);
          expect(mjs("spec-coerce", "query", input)).toBe(want);
          expect(mjs("text", "query", input)).toBe(decoded[i] ?? "");
          expect(mjs("text", "strict-query", input)).toBe(strict[i] ?? "");
          if (decoded[i]?.startsWith("ok:")) accepted++;
        }
        // Both outcomes occur in earnest.
        expect(accepted).toBeGreaterThan(inputs.length / 10);
        expect(accepted).toBeLessThan(inputs.length * 0.9);
      },
      SLOW_TEST_TIMEOUT_MS,
    );
});

// Random schemas, including defaults, checked against the specification's
// error laws through the .mjs build.
type Tree =
  | { kind: "null" }
  | { kind: "bool"; value: boolean }
  | { kind: "number"; token: string }
  | { kind: "string"; value: string }
  | { kind: "array"; items: Tree[] }
  | { kind: "object"; members: [string, Tree][] };
type Presence = { kind: "required" } | { kind: "optional" } | { kind: "default"; value: Tree };
type Shape =
  | { kind: "boolean" }
  | { kind: "integer"; min: string | null }
  | { kind: "string"; max: number | null }
  | { kind: "array"; items: Shape; max: number | null }
  | { kind: "object"; fields: { key: string; shape: Shape; presence: Presence }[]; strict: boolean }
  | { kind: "nullable"; inner: Shape }
  | { kind: "union"; members: Shape[] };
type Part = { kind: "key"; key: string } | { kind: "index"; index: number };

function list(xs: unknown[]): unknown {
  return xs.reduceRight<unknown>((tail, head) => ({ $: "Con", head, tail }), { $: "Nil" });
}
function maybe<T>(x: T | null): unknown {
  return x === null ? { $: "None" } : { $: "Some", value: x };
}
function write(t: Tree): string {
  switch (t.kind) {
    case "null":
      return "null";
    case "bool":
      return String(t.value);
    case "number":
      return t.token;
    case "string":
      return JSON.stringify(t.value);
    case "array":
      return `[${t.items.map(write).join(",")}]`;
    case "object":
      return `{${t.members.map(([k, v]) => `${JSON.stringify(k)}:${write(v)}`).join(",")}}`;
    default: {
      const exhaustive: never = t;
      return exhaustive;
    }
  }
}
// Values come from the Bend parser, so they have the module's own encoding.
function json(t: Tree): unknown {
  const parsed = call("parse", write(t));
  if (Reflect.get(Object(parsed), "$") !== "Done") throw new Error(`unparsable ${write(t)}`);
  return Reflect.get(Object(parsed), "value");
}
function presence(p: Presence): unknown {
  switch (p.kind) {
    case "required":
      return { $: "Required" };
    case "optional":
      return { $: "Optional" };
    case "default":
      return { $: "Default", value: json(p.value) };
    default: {
      const exhaustive: never = p;
      return exhaustive;
    }
  }
}
function bend(s: Shape): unknown {
  switch (s.kind) {
    case "boolean":
      return { $: "BooleanSchema" };
    case "integer":
      return { $: "IntegerSchema", min: maybe(s.min), max: { $: "None" } };
    case "string":
      return {
        $: "StringSchema",
        min_len: 0,
        max_len: maybe(s.max),
        pattern: { $: "None" },
        format: { $: "Plain" },
      };
    case "array":
      return { $: "ArraySchema", items: bend(s.items), min_items: 0, max_items: maybe(s.max) };
    case "object":
      return {
        $: "ObjectSchema",
        fields: list(
          s.fields.map((f) => ({
            $: "Field",
            key: f.key,
            schema: bend(f.shape),
            presence: presence(f.presence),
          })),
        ),
        unknown: { $: s.strict ? "Strict" : "Strip" },
      };
    case "nullable":
      return { $: "NullableSchema", inner: bend(s.inner) };
    case "union":
      return { $: "UnionSchema", members: list(s.members.map(bend)) };
    default: {
      const exhaustive: never = s;
      return exhaustive;
    }
  }
}
function bendPath(parts: Part[]): unknown {
  return list(
    parts.map((p) =>
      p.kind === "key" ? { $: "PathKey", value: p.key } : { $: "PathIndex", value: p.index },
    ),
  );
}

const KEYS = ["a", "b", "c"] as const;
function generators(next: () => number) {
  const { int, pick } = picker(next);
  function leaf(): Tree {
    return pick<Tree>([
      { kind: "null" },
      { kind: "bool", value: next() < 0.5 },
      { kind: "number", token: pick(["0", "7", "-3", "1.5"]) },
      { kind: "string", value: pick(["", "x", "abc"]) },
    ]);
  }
  function tree(depth: number): Tree {
    if (depth === 0 || next() < 0.4) return leaf();
    return next() < 0.5
      ? { kind: "array", items: Array.from({ length: int(4) }, () => tree(depth - 1)) }
      : {
          kind: "object",
          members: Array.from({ length: int(4) }, (): [string, Tree] => [
            pick([...KEYS, "z"] as const),
            tree(depth - 1),
          ]),
        };
  }
  function shape(depth: number): Shape {
    if (depth === 0 || next() < 0.35)
      return pick<Shape>([
        { kind: "boolean" },
        { kind: "integer", min: next() < 0.5 ? null : "0" },
        { kind: "string", max: next() < 0.5 ? null : 2 },
      ]);
    switch (int(4)) {
      case 0:
        return { kind: "array", items: shape(depth - 1), max: next() < 0.6 ? null : 2 };
      case 1:
        return {
          kind: "object",
          fields: KEYS.filter(() => next() < 0.6).map((key) => {
            const r = next();
            const p: Presence =
              r < 0.4
                ? { kind: "required" }
                : r < 0.75
                  ? { kind: "optional" }
                  : { kind: "default", value: tree(1) };
            return { key, shape: shape(depth - 1), presence: p };
          }),
          strict: next() < 0.5,
        };
      case 2:
        return { kind: "nullable", inner: shape(depth - 1) };
      default:
        return {
          kind: "union",
          members: Array.from({ length: 1 + int(2) }, () => shape(depth - 1)),
        };
    }
  }
  return { shape, tree };
}
// Every path into the value, each key at every object, and one index past the end.
function candidates(t: Tree, prefix: Part[], out: Part[][]): void {
  out.push(prefix);
  switch (t.kind) {
    case "array":
      t.items.forEach((item, index) =>
        candidates(item, [...prefix, { kind: "index", index }], out),
      );
      out.push([...prefix, { kind: "index", index: t.items.length }]);
      return;
    case "object":
      for (const key of [...KEYS, "z"]) {
        const member = t.members.find(([k]) => k === key);
        if (member === undefined) out.push([...prefix, { kind: "key", key }]);
        else candidates(member[1], [...prefix, { kind: "key", key }], out);
      }
      return;
    case "null":
    case "bool":
    case "number":
    case "string":
      return;
    default: {
      const exhaustive: never = t;
      return exhaustive;
    }
  }
}

test(
  "seeded random schemas: errors name failing paths and every failing path is named",
  () => {
    const g = generators(random(35));
    let rejected = 0;
    let faults = 0;
    for (let i = 0; i < 600; i++) {
      const s = bend(g.shape(3));
      const t = g.tree(3);
      const v = json(t);
      const decoded = call("decode", s, v);
      expect(flag("located", s, v, decoded)).toBe(true);
      const ok = Reflect.get(Object(decoded), "$") === "Done";
      if (!ok) rejected++;
      const all: Part[][] = [];
      candidates(t, [], all);
      for (const p of all) {
        const path = bendPath(p);
        if (!flag("error_at", s, v, path)) continue;
        faults++;
        expect({ i, p, reported: flag("reported", decoded, path) }).toEqual({
          i,
          p,
          reported: true,
        });
      }
    }
    expect(rejected).toBeGreaterThan(100);
    expect(faults).toBeGreaterThan(rejected);
  },
  SLOW_TEST_TIMEOUT_MS,
);

// Request-time cost under attacker-sized inputs: ratios between 256 KiB and
// 1 MiB, not wall time. Linear work is about 4 times, quadratic about 16.
const MiB = 1 << 20;
function repeated(bytes: number, member: string): string {
  return `{${Array(Math.floor(bytes / (member.length + 1)))
    .fill(member)
    .join(",")}}`;
}
function timed(mode: Mode, schema: string, input: string): { result: string; ms: number } {
  const path = join(scratch, `${files++}.txt`);
  writeFileSync(path, input);
  const r = Bun.spawnSync([
    "timeout",
    "--foreground",
    "60s",
    nativePath,
    "bench",
    mode,
    schema,
    path,
    "+RTS",
    "--threads",
    "1",
    "-RTS",
  ]);
  expect(r.exitCode).toBe(0);
  const out = r.stdout.toString().trimEnd();
  const at = out.lastIndexOf(":");
  return { result: out.slice(0, at), ms: Number(out.slice(at + 1)) };
}
type Body = {
  label: string;
  mode: Mode;
  schema: string;
  make: (bytes: number) => string;
  result: (bytes: number) => string;
};
const bodies: Body[] = [
  {
    label: "array of wrong items, errors capped",
    mode: "count-json",
    schema: "ints",
    make: (n) =>
      `[${Array(Math.floor((n - 1) / 4))
        .fill('"x"')
        .join(",")}]`,
    result: () => "errors:100",
  },
  {
    label: "undeclared keys under Strict, errors capped",
    mode: "count-json",
    schema: "wide",
    make: (n) => {
      const parts: string[] = [];
      let size = 2;
      for (let i = 0; size < n; i++) {
        const part = `"k${i}":1`;
        parts.push(part);
        size += part.length + 1;
      }
      return `{${parts.join(",")}}`;
    },
    result: () => "errors:100",
  },
  {
    label: "a repeated text key gathered into one array",
    mode: "count-text",
    schema: "query",
    make: (n) => repeated(n, '"ids":"7"'),
    result: () => "ok:9",
  },
];
describe("error collection and coercion cost time linear in the input, natively", () => {
  for (const body of bodies)
    test(
      body.label,
      () => {
        const quarter = timed(body.mode, body.schema, body.make(MiB / 4));
        const full = timed(body.mode, body.schema, body.make(MiB));
        expect(quarter.result).toBe(body.result(MiB / 4));
        expect(full.result).toBe(body.result(MiB));
        console.log(
          `BND-35 native, ${body.label}: 256 KiB ${quarter.ms} ms, 1 MiB ${full.ms} ms (one runtime thread)`,
        );
        expect(full.ms).toBeLessThan(Math.max(8 * quarter.ms, 50));
      },
      SLOW_TEST_TIMEOUT_MS,
    );
});

test(
  "the .mjs build gathers a half-megabyte repeated text key without growing the call stack",
  () => {
    expect(mjs("count-text", "query", repeated(MiB / 2, '"ids":"7"'))).toBe("ok:9");
  },
  SLOW_TEST_TIMEOUT_MS,
);

test(
  "the .mjs build collects errors from a 131,071-item array without growing the call stack",
  () => {
    const items = Array<string>(131_071).fill("1");
    items[items.length - 1] = '"x"';
    expect(mjs("count-json", "ints", `[${items.join(",")}]`)).toBe("errors:1");
    expect(paths(mjs("json", "ints", `[${items.join(",")}]`))).toEqual(["/131070"]);
  },
  SLOW_TEST_TIMEOUT_MS,
);
