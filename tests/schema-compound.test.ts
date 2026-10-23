import { compile, SLOW_TEST_TIMEOUT_MS } from "./harness.ts";
import { afterAll, describe, expect, test } from "bun:test";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

// Compile once, outside any test's timeout, through the shared fixture cache.
const nativePath = compile("tests/fixtures/schema-compound/native.bend", "native");
const modulePath = compile("tests/fixtures/schema-compound/consumer.bend", "mjs");
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

const scratch = mkdtempSync(join(tmpdir(), "bendo-schema-compound-"));
afterAll(() => rmSync(scratch, { recursive: true, force: true }));
let files = 0;

type Mode = "run" | "typed" | "count" | "bench";
function native(mode: Mode, schema: string, input: string): string {
  const path = join(scratch, `${files++}.json`);
  writeFileSync(path, input);
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
  return r.stdout.toString().trimEnd();
}
function mjs(mode: Exclude<Mode, "bench">, schema: string, input: string): string {
  switch (mode) {
    case "run":
      return text("run", schema, input);
    case "typed":
      return text("run_typed", input);
    case "count":
      return text("run_count", schema, input);
    default: {
      const exhaustive: never = mode;
      return exhaustive;
    }
  }
}
function both(mode: Exclude<Mode, "bench">, schema: string, input: string): string {
  const fromNative = native(mode, schema, input);
  expect(mjs(mode, schema, input)).toBe(fromNative);
  return fromNative;
}

const paris = '{"city":"Paris","geo":{"lat":48.85,"lng":2.35}}';
const ada = `{"name":"Ada","address":${paris}}`;
const adaValue =
  'ok:{name="Ada",age=-,address={city="Paris",geo={lat=n48.85,lng=n2.35},zip=-},tags=-,nick=-}';

type Case = { schema: string; input: string; result: string };
const cases: Case[] = [
  // Three nested objects, optional fields absent and present, schema order kept.
  { schema: "user", input: ada, result: adaValue },
  {
    schema: "user",
    input:
      '{"nick":null,"tags":["a","b"],"address":{"zip":"75001","geo":{"lng":2.35,"lat":48.85},"city":"Paris"},"age":36,"name":"Ada"}',
    result:
      'ok:{name="Ada",age=i36,address={city="Paris",geo={lat=n48.85,lng=n2.35},zip="75001"},tags=["a","b"],nick=null}',
  },
  {
    schema: "user",
    input: `{"name":"Ada","address":${paris},"nick":"ad"}`,
    result:
      'ok:{name="Ada",age=-,address={city="Paris",geo={lat=n48.85,lng=n2.35},zip=-},tags=-,nick="ad"}',
  },
  // Errors name the path to the first failing child.
  {
    schema: "user",
    input: '{"name":"Ada","address":{"city":"Paris","geo":{"lat":48.85,"lng":"x"}}}',
    result: "error:TypeMismatch:/address/geo/lng:expected schema scalar kind",
  },
  {
    schema: "user",
    input: '{"name":"Ada","address":{"city":"Paris","geo":{"lat":48.85}}}',
    result: "error:Constraint:/address/geo/lng:missing required key",
  },
  {
    schema: "user",
    input: `{"name":"Ada","address":${paris},"tags":["a",1]}`,
    result: "error:TypeMismatch:/tags/1:expected schema scalar kind",
  },
  {
    schema: "user",
    input: `{"name":"Ada","address":${paris},"tags":["a","b","c","d"]}`,
    result: "error:Constraint:/tags:array length out of bounds",
  },
  {
    schema: "user",
    input: `{"name":"","address":${paris}}`,
    result: "error:Constraint:/name:value does not satisfy scalar checks",
  },
  {
    schema: "user",
    input: `{"name":"Ada","address":${paris},"age":151}`,
    result: "error:Constraint:/age:value does not satisfy scalar checks",
  },
  {
    schema: "user",
    input: `{"name":"Ada","address":${paris},"nick":1}`,
    result: "error:TypeMismatch:/nick:expected schema scalar kind",
  },
  {
    schema: "user",
    input: `{"address":${paris}}`,
    result: "error:Constraint:/name:missing required key",
  },
  {
    schema: "user",
    input: '{"name":"Ada","address":{"city":"Paris","geo":{"lat":1,"lng":2},"zip":"7500"}}',
    result: "error:Constraint:/address/zip:value does not satisfy scalar checks",
  },
  { schema: "user", input: "[]", result: "error:TypeMismatch::expected schema kind" },
  // Strict objects reject undeclared keys; Strip drops them, repeats included.
  {
    schema: "user",
    input: `{"name":"Ada","address":${paris},"admin":true}`,
    result: "error:Constraint::object has an undeclared key",
  },
  {
    schema: "strip",
    input: `{"admin":true,"name":"Ada","admin":false,"address":${paris}}`,
    result: adaValue,
  },
  // A declared key may appear once, under either policy.
  {
    schema: "user",
    input: `{"name":"Ada","name":"Eve","address":${paris}}`,
    result: "error:Constraint:/name:duplicate key",
  },
  {
    schema: "strip",
    input: `{"name":"Ada","address":${paris},"name":"Ada"}`,
    result: "error:Constraint:/name:duplicate key",
  },
  { schema: "empty-object", input: "{}", result: "ok:{}" },
  {
    schema: "empty-object",
    input: '{"a":1}',
    result: "error:Constraint::object has an undeclared key",
  },
  // Arrays: bounds are checked before any item, items in order with indices.
  { schema: "items", input: "[1]", result: "ok:[i1]" },
  { schema: "items", input: "[1,-0,3]", result: "ok:[i1,i-0,i3]" },
  { schema: "items", input: "[]", result: "error:Constraint::array length out of bounds" },
  { schema: "items", input: '[1,2,3,"x"]', result: "error:Constraint::array length out of bounds" },
  {
    schema: "items",
    input: "[1,2.5]",
    result: "error:Constraint:/1:value does not satisfy scalar checks",
  },
  { schema: "items", input: '{"0":1}', result: "error:TypeMismatch::expected schema kind" },
  { schema: "matrix", input: "[[true],[],[false,true]]", result: "ok:[[True],[],[False,True]]" },
  {
    schema: "matrix",
    input: "[[true],[null]]",
    result: "error:TypeMismatch:/1/0:expected schema scalar kind",
  },
  { schema: "deep", input: "[[[1]],[[2,3],[]]]", result: "ok:[[[i1]],[[i2,i3],[]]]" },
  {
    schema: "deep",
    input: "[[[[1]]]]",
    result: "error:TypeMismatch:/0/0/0:expected schema scalar kind",
  },
  // Nullable: null itself, otherwise the inner schema.
  { schema: "nullable", input: "null", result: "ok:null" },
  { schema: "nullable", input: "7", result: "ok:i7" },
  { schema: "nullable", input: '"7"', result: "error:TypeMismatch::expected schema scalar kind" },
  // Unions: the first member that accepts, with its position.
  { schema: "union", input: "12", result: "ok:#0:i12" },
  { schema: "union", input: '"ab"', result: 'ok:#1:"ab"' },
  { schema: "union", input: "null", result: "ok:#2:lit:null" },
  { schema: "union", input: '{"kind":"x"}', result: 'ok:#3:{kind=lit:"x"}' },
  { schema: "union", input: '"abc"', result: "error:Constraint::value matches no union member" },
  { schema: "union", input: "1.5", result: "error:Constraint::value matches no union member" },
  {
    schema: "union",
    input: '{"kind":"x","more":1}',
    result: "error:Constraint::value matches no union member",
  },
  { schema: "union-objects", input: '{"a":1}', result: "ok:#0:{a=i1}" },
  { schema: "union-objects", input: '{"a":"1","b":2}', result: 'ok:#1:{a="1"}' },
  {
    schema: "union-objects",
    input: '{"a":1,"b":2}',
    result: "error:Constraint::value matches no union member",
  },
  { schema: "nullable-union", input: "null", result: "ok:null" },
  { schema: "nullable-union", input: "3", result: "ok:#0:i3" },
  { schema: "nullable-union", input: '"x"', result: 'ok:#1:"x"' },
  {
    schema: "empty-union",
    input: "null",
    result: "error:Constraint::value matches no union member",
  },
  // A malformed part anywhere invalidates the whole schema before input is read.
  { schema: "invalid-duplicate", input: '{"a":1}', result: "error:InvalidSchema::invalid schema" },
  { schema: "invalid-nested", input: "[]", result: "error:InvalidSchema::invalid schema" },
  { schema: "invalid-items", input: "[1,2]", result: "error:InvalidSchema::invalid schema" },
  { schema: "invalid-key", input: "{}", result: "error:InvalidSchema::invalid schema" },
  { schema: "invalid-member", input: "1", result: "error:InvalidSchema::invalid schema" },
];

describe("compound schemas decode the same natively and in .mjs", () => {
  for (const c of cases)
    test(`${c.schema}: ${c.input.slice(0, 60)}`, () => {
      expect(both("run", c.schema, c.input)).toBe(c.result);
    });
});

test("a nested object three levels deep decodes into a typed record", () => {
  expect(both("typed", "user", ada)).toBe(
    'User{"Ada" in "Paris" at 48.85,2.35 zip none nick absent}',
  );
  expect(
    both(
      "typed",
      "user",
      '{"nick":"ad","address":{"zip":"75001","city":"Paris","geo":{"lng":2.35,"lat":48.85}},"name":"Ada"}',
    ),
  ).toBe('User{"Ada" in "Paris" at 48.85,2.35 zip "75001" nick "ad"}');
  expect(both("typed", "user", `{"name":"Ada","address":${paris},"nick":null}`)).toBe(
    'User{"Ada" in "Paris" at 48.85,2.35 zip none nick none}',
  );
  expect(both("typed", "user", '{"name":"Ada","address":{"city":"Paris"}}')).toBe("untyped");
  // The .mjs build returns the same record as a plain object.
  const parsed = call("parse", ada);
  const decoded = call("decode", call("schema", "user"), Reflect.get(Object(parsed), "value"));
  expect(call("typed", decoded)).toEqual({
    $: "Some",
    value: {
      $: "User",
      name: "Ada",
      address: {
        $: "Address",
        city: "Paris",
        geo: { $: "Geo", lat: "48.85", lng: "2.35" },
        zip: { $: "None" },
      },
      nick: { $: "None" },
    },
  });
});

test("to_json rebuilds accepted input without absent fields or stripped keys", () => {
  const input = `{"admin":1,"name":"Ada","address":${paris},"nick":null}`;
  const parsed = call("parse", input);
  const decoded = call("decode", call("schema", "strip"), Reflect.get(Object(parsed), "value"));
  const value = Reflect.get(Object(decoded), "value");
  expect(text("stringify", call("to_json", value))).toBe(
    `{"name":"Ada","address":${paris},"nick":null}`,
  );
});

// An independent reading of docs/data/schema.md for a scalar subset, used as an
// oracle on seeded random schemas and inputs, including duplicate keys.
type Tree =
  | { kind: "null" }
  | { kind: "bool"; value: boolean }
  | { kind: "number"; token: string }
  | { kind: "string"; value: string }
  | { kind: "array"; items: Tree[] }
  | { kind: "object"; members: [string, Tree][] };
type Shape =
  | { kind: "boolean" }
  | { kind: "integer" }
  | { kind: "null" }
  | { kind: "string"; min: number; max: number | null }
  | { kind: "array"; items: Shape; min: number; max: number | null }
  | { kind: "object"; fields: { key: string; shape: Shape; required: boolean }[]; strict: boolean }
  | { kind: "nullable"; inner: Shape }
  | { kind: "union"; members: Shape[] };
type Outcome = { kind: "ok"; shown: string } | { kind: "error" };

function list(xs: unknown[]): unknown {
  return xs.reduceRight<unknown>((tail, head) => ({ $: "Con", head, tail }), { $: "Nil" });
}
function maybe(n: number | null): unknown {
  return n === null ? { $: "None" } : { $: "Some", value: n };
}
function bend(s: Shape): unknown {
  switch (s.kind) {
    case "boolean":
      return { $: "BooleanSchema" };
    case "integer":
      return { $: "IntegerSchema", min: { $: "None" }, max: { $: "None" } };
    case "null":
      return { $: "LiteralSchema", value: { $: "JNull" } };
    case "string":
      return {
        $: "StringSchema",
        min_len: s.min,
        max_len: maybe(s.max),
        pattern: { $: "None" },
        format: { $: "Plain" },
      };
    case "array":
      return { $: "ArraySchema", items: bend(s.items), min_items: s.min, max_items: maybe(s.max) };
    case "object":
      return {
        $: "ObjectSchema",
        fields: list(
          s.fields.map((f) => ({
            $: "Field",
            key: f.key,
            schema: bend(f.shape),
            presence: { $: f.required ? "Required" : "Optional" },
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
function wellFormed(s: Shape): boolean {
  switch (s.kind) {
    case "boolean":
    case "integer":
    case "null":
      return true;
    case "string":
      return s.max === null || s.min <= s.max;
    case "array":
      return (s.max === null || s.min <= s.max) && wellFormed(s.items);
    case "object":
      return (
        new Set(s.fields.map((f) => f.key)).size === s.fields.length &&
        s.fields.every((f) => wellFormed(f.shape))
      );
    case "nullable":
      return wellFormed(s.inner);
    case "union":
      return s.members.every(wellFormed);
    default: {
      const exhaustive: never = s;
      return exhaustive;
    }
  }
}
function within(n: number, min: number, max: number | null): boolean {
  return n >= min && (max === null || n <= max);
}
function oracle(s: Shape, t: Tree): Outcome {
  switch (s.kind) {
    case "boolean":
      return t.kind === "bool"
        ? { kind: "ok", shown: t.value ? "True" : "False" }
        : { kind: "error" };
    case "integer":
      return t.kind === "number" && /^-?(0|[1-9][0-9]*)$/.test(t.token)
        ? { kind: "ok", shown: `i${t.token}` }
        : { kind: "error" };
    case "null":
      return t.kind === "null" ? { kind: "ok", shown: "lit:null" } : { kind: "error" };
    case "string":
      return t.kind === "string" && within([...t.value].length, s.min, s.max)
        ? { kind: "ok", shown: JSON.stringify(t.value) }
        : { kind: "error" };
    case "array": {
      if (t.kind !== "array" || !within(t.items.length, s.min, s.max)) return { kind: "error" };
      const shown: string[] = [];
      for (const item of t.items) {
        const r = oracle(s.items, item);
        if (r.kind === "error") return r;
        shown.push(r.shown);
      }
      return { kind: "ok", shown: `[${shown.join(",")}]` };
    }
    case "object": {
      if (t.kind !== "object") return { kind: "error" };
      const declared = new Set(s.fields.map((f) => f.key));
      if (s.strict && t.members.some(([k]) => !declared.has(k))) return { kind: "error" };
      const shown: string[] = [];
      for (const f of s.fields) {
        const named = t.members.filter(([k]) => k === f.key);
        const [first, ...more] = named;
        if (more.length > 0) return { kind: "error" };
        if (first === undefined) {
          if (f.required) return { kind: "error" };
          shown.push(`${f.key}=-`);
          continue;
        }
        const r = oracle(f.shape, first[1]);
        if (r.kind === "error") return r;
        shown.push(`${f.key}=${r.shown}`);
      }
      return { kind: "ok", shown: `{${shown.join(",")}}` };
    }
    case "nullable":
      return t.kind === "null" ? { kind: "ok", shown: "null" } : oracle(s.inner, t);
    case "union": {
      for (const [i, m] of s.members.entries()) {
        const r = oracle(m, t);
        if (r.kind === "ok") return { kind: "ok", shown: `#${i}:${r.shown}` };
      }
      return { kind: "error" };
    }
    default: {
      const exhaustive: never = s;
      return exhaustive;
    }
  }
}

function random(seed: number): () => number {
  let a = seed;
  return () => {
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const KEYS = ["a", "b", "c", "d"];
function generators(next: () => number) {
  const int = (n: number) => Math.floor(next() * n);
  const pick = <T>(xs: readonly [T, ...T[]]): T => xs[int(xs.length)] ?? xs[0];
  const bound = (): number | null => (next() < 0.4 ? null : int(4));
  function shape(depth: number): Shape {
    const leaf = depth === 0 || next() < 0.35;
    if (leaf)
      return pick<Shape>([
        { kind: "boolean" },
        { kind: "integer" },
        { kind: "null" },
        { kind: "string", min: int(2), max: bound() },
      ]);
    switch (int(4)) {
      case 0:
        return { kind: "array", items: shape(depth - 1), min: int(2), max: bound() };
      case 1: {
        const keys = KEYS.filter(() => next() < 0.5);
        // Sometimes declare a key twice: the whole schema is then invalid.
        if (next() < 0.05) keys.push(pick(["a", "b"]));
        return {
          kind: "object",
          fields: keys.map((key) => ({ key, shape: shape(depth - 1), required: next() < 0.5 })),
          strict: next() < 0.5,
        };
      }
      case 2:
        return { kind: "nullable", inner: shape(depth - 1) };
      default:
        return { kind: "union", members: Array.from({ length: int(4) }, () => shape(depth - 1)) };
    }
  }
  function any(depth: number): Tree {
    const leaf = depth === 0 || next() < 0.5;
    if (leaf)
      return pick<Tree>([
        { kind: "null" },
        { kind: "bool", value: next() < 0.5 },
        { kind: "number", token: pick(["0", "7", "-3", "12", "1.5", "2e1", "-0"]) },
        { kind: "string", value: pick(["", "x", "ab", "abc"]) },
      ]);
    return next() < 0.5
      ? { kind: "array", items: Array.from({ length: int(4) }, () => any(depth - 1)) }
      : {
          kind: "object",
          members: Array.from({ length: int(4) }, (): [string, Tree] => [
            pick(["a", "b", "z"]),
            any(depth - 1),
          ]),
        };
  }
  // Mostly shaped like the schema, so a good share of inputs is accepted.
  function near(s: Shape, depth: number): Tree {
    if (next() < 0.1) return any(depth);
    switch (s.kind) {
      case "boolean":
        return { kind: "bool", value: next() < 0.5 };
      case "integer":
        return { kind: "number", token: pick(["0", "7", "-3", "12", "-0", "1.5"]) };
      case "null":
        return { kind: "null" };
      case "string":
        return { kind: "string", value: pick(["", "x", "ab", "abc", "abcd"]) };
      case "array":
        return { kind: "array", items: Array.from({ length: int(5) }, () => near(s.items, depth)) };
      case "object": {
        const members: [string, Tree][] = [];
        for (const f of s.fields) {
          if (next() < 0.8) members.push([f.key, near(f.shape, depth)]);
          if (next() < 0.05) members.push([f.key, near(f.shape, depth)]);
        }
        if (next() < 0.2) members.push(["z", any(1)]);
        if (next() < 0.1) members.push(["z", any(1)]);
        return { kind: "object", members: members.sort(() => next() - 0.5) };
      }
      case "nullable":
        return next() < 0.3 ? { kind: "null" } : near(s.inner, depth);
      case "union": {
        const [first, ...rest] = s.members;
        return first === undefined ? any(depth) : near(pick([first, ...rest]), depth);
      }
      default: {
        const exhaustive: never = s;
        return exhaustive;
      }
    }
  }
  return { shape, near };
}

function expected(s: Shape, t: Tree): string {
  if (!wellFormed(s)) return "error";
  const r = oracle(s, t);
  return r.kind === "ok" ? `ok:${r.shown}` : "error";
}
function observed(report: string): string {
  return report.startsWith("error:") ? "error" : report;
}

test(
  "seeded random schemas and inputs agree with an independent oracle and the specification",
  () => {
    const g = generators(random(34));
    let accepted = 0;
    const total = 3000;
    for (let i = 0; i < total; i++) {
      const s = g.shape(3);
      const t = g.near(s, 2);
      const input = write(t);
      const parsed = call("parse", input);
      const tree = Reflect.get(Object(parsed), "value");
      const decoded = call("decode", bend(s), tree);
      const report = text("report", decoded);
      const want = expected(s, t);
      expect({ input, got: observed(report) }).toEqual({ input, got: want });
      expect(call("satisfies", bend(s), tree)).toBe(want !== "error");
      if (want !== "error") accepted++;
    }
    // The generator must exercise both outcomes in earnest.
    expect(accepted).toBeGreaterThan(total / 5);
    expect(accepted).toBeLessThan((total * 4) / 5);
  },
  SLOW_TEST_TIMEOUT_MS,
);

// Request-time cost under attacker-sized bodies. The parser caps nesting at 512
// containers; the decoder's own depth is the schema's, and each list is walked
// by tail calls, so width costs linear time and no stack in either target.
const MiB = 1 << 20;
function ints(bytes: number): string {
  return `[${Array(Math.floor((bytes - 1) / 2))
    .fill("1")
    .join(",")}]`;
}
function members(bytes: number, key: (i: number) => string): string {
  const parts: string[] = [];
  let size = 2;
  for (let i = 0; size < bytes; i++) {
    const part = `"${key(i)}":1`;
    parts.push(part);
    size += part.length + 1;
  }
  return `{${parts.join(",")}}`;
}
function timed(schema: string, input: string): { result: string; ms: number } {
  const out = native("bench", schema, input);
  const at = out.lastIndexOf(":");
  return { result: out.slice(0, at), ms: Number(out.slice(at + 1)) };
}

type Body = { label: string; schema: string; make: (bytes: number) => string; result: string };
const bodies: Body[] = [
  { label: "array of integers", schema: "ints", make: ints, result: "ok" },
  {
    label: "unknown keys, Strip",
    schema: "wide-strip",
    make: (n) => members(n, (i) => `k${i}`),
    result: "ok:26",
  },
  {
    label: "one declared key repeated",
    schema: "wide",
    make: (n) => members(n, () => "z"),
    result: "error:Constraint:/z:duplicate key",
  },
  {
    label: "unknown keys, Strict",
    schema: "wide",
    make: (n) => members(n, (i) => `k${i}`),
    result: "error:Constraint::object has an undeclared key",
  },
  {
    label: "array over max_items",
    schema: "items",
    make: ints,
    result: "error:Constraint::array length out of bounds",
  },
];

// Ratios, not wall time: linear work makes 1 MiB about 4 times 256 KiB, and
// quadratic work about 16 times. Sub-50 ms timings are noise, so they pass.
describe("megabyte bodies decode in time linear in their size, natively", () => {
  for (const body of bodies)
    test(
      body.label,
      () => {
        const quarter = timed(body.schema, body.make(MiB / 4));
        const full = timed(body.schema, body.make(MiB));
        const want = (bytes: number) =>
          body.result === "ok" ? `ok:${Math.floor((bytes - 1) / 2)}` : body.result;
        expect(quarter.result).toBe(want(MiB / 4));
        expect(full.result).toBe(want(MiB));
        console.log(
          `BND-34 native decode, ${body.label}: 256 KiB ${quarter.ms} ms, 1 MiB ${full.ms} ms (one runtime thread)`,
        );
        expect(full.ms).toBeLessThan(Math.max(8 * quarter.ms, 50));
      },
      SLOW_TEST_TIMEOUT_MS,
    );
});

// Non-tail recursion overflows .mjs near 10,000 items. Most of the time here is
// the JSON parser in .mjs, so each slice stays well under a minute.
test(
  "the .mjs build decodes a 262,143-item array without growing the call stack",
  () => {
    expect(mjs("count", "ints", ints(MiB / 2))).toBe(`ok:${(MiB / 2 - 2) / 2}`);
  },
  SLOW_TEST_TIMEOUT_MS,
);

test(
  "the .mjs build decodes a megabyte object without growing the call stack",
  () => {
    expect(
      mjs(
        "count",
        "wide",
        members(MiB, () => "z"),
      ),
    ).toBe("error:Constraint:/z:duplicate key");
  },
  SLOW_TEST_TIMEOUT_MS,
);

test("nesting past the schema's depth fails at that depth, and the parser caps it at 512", () => {
  const nested = (n: number) => `${"[".repeat(n)}${"]".repeat(n)}`;
  expect(both("run", "deep", nested(512))).toBe(
    "error:TypeMismatch:/0/0/0:expected schema scalar kind",
  );
  expect(both("run", "deep", nested(513))).toBe("error:none");
});
