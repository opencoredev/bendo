// BND-37: every schema kind exports JSON Schema 2020-12 that accepts exactly
// the JSON the Bend decoder accepts, apart from the documented decoder policy
// (docs/data/json-schema.md). The decoder is the real `.mjs` build; Ajv runs
// in strict mode with and without the `u` flag.
import { describe, expect, test } from "bun:test";
import {
  loadConsumer,
  random,
  validators,
  write,
  type Pattern,
  type Presence,
  type Schema,
  type Tree,
} from "./json-schema-support.ts";

// Compile once, outside any test's timeout, through the shared fixture cache.
const bend = await loadConsumer();
const SLICE_TIMEOUT_MS = 60_000;

type Verdict = { mode: string; ajv: boolean; bend: boolean };

/** Compiles the export in both modes and returns a checker for samples. */
function differential(schema: Schema) {
  const document = bend.document(schema);
  if (typeof document !== "object" || document === null) throw new Error("export is not an object");
  const checks = validators().map(({ mode, ajv }) => {
    expect(ajv.validateSchema(document)).toBe(true);
    return { mode, validate: ajv.compile(document) };
  });
  return {
    document,
    verdicts(tree: Tree): Verdict[] {
      const value: unknown = JSON.parse(write(tree));
      const decoded = bend.accepts(schema, tree);
      return checks.map(({ mode, validate }) => ({ mode, ajv: validate(value), bend: decoded }));
    },
  };
}

function agree(schema: Schema, trees: Tree[]): { accepted: number; rejected: number } {
  const check = differential(schema);
  let accepted = 0;
  let rejected = 0;
  for (const tree of trees) {
    for (const v of check.verdicts(tree)) {
      if (v.ajv !== v.bend)
        throw new Error(
          `disagree (${v.mode}): ajv=${v.ajv} bend=${v.bend}\nschema=${JSON.stringify(check.document)}\nvalue=${write(tree)}`,
        );
      if (v.bend) accepted++;
      else rejected++;
    }
  }
  return { accepted, rejected };
}

const str = (value: string): Tree => ({ kind: "string", value });
const num = (token: string): Tree => ({ kind: "number", token });
const bool = (value: boolean): Tree => ({ kind: "bool", value });
const NULL: Tree = { kind: "null" };
const arr = (...items: Tree[]): Tree => ({ kind: "array", items });
const obj = (...members: [string, Tree][]): Tree => ({ kind: "object", members });
const text = (min = 0, max: number | null = null): Schema => ({
  kind: "string",
  min,
  max,
  pattern: null,
  format: "plain",
});
const field = (key: string, schema: Schema, presence: Presence = { kind: "required" }) => ({
  key,
  schema,
  presence,
});

// Number tokens whose JavaScript values compare exactly like their decimals.
// Non-lexical integral tokens (`1.0`, `1e2`) differ on purpose for integer
// schemas and have their own test below.
const TOKENS = ["0", "-0", "1", "-1", "2", "3", "7", "10", "99", "100", "101", "-3", "-4"];
const FRACTIONS = ["1.5", "-3.5", "0.25", "2.5e-1", "-0.5", "12.75", "99.5", "100.5"];
const BOUNDS = ["0", "1", "-3.5", "2.5", "10", "1e2", "1E+1", "0.0", "-0", "100", "-100"];
const KEYS = ["a", "b", "c", "é", "constructor", "toString"];
const CHARS = ["a", "b", "z", "A", "0", "9", "-", ".", "@", " ", "é", "😀", "_"];

function generators(next: () => number) {
  const int = (n: number) => Math.floor(next() * n);
  const pick = <T>(xs: readonly T[], fallback: T): T => xs[int(xs.length)] ?? fallback;
  const chance = (p: number) => next() < p;
  const randomText = (n: number) => Array.from({ length: n }, () => pick(CHARS, "a")).join("");

  function pattern(depth: number): Pattern {
    const kind = depth <= 0 ? int(2) : int(4);
    switch (kind) {
      case 0:
        return { kind: "literal", text: randomText(int(3)) };
      case 1: {
        const ranges: [number, number][] = Array.from({ length: 1 + int(2) }, () => {
          if (chance(0.04)) return [97, 200];
          const lo = 45 + int(70);
          return [lo, Math.min(127, lo + int(6))];
        });
        return { kind: "class", ranges };
      }
      case 2:
        return { kind: "cat", first: pattern(depth - 1), second: pattern(depth - 1) };
      default: {
        const min = int(3);
        const max = chance(0.3) ? null : chance(0.04) ? Math.max(0, min - 1) : min + int(3);
        return { kind: "repeat", body: pattern(depth - 1), min, max };
      }
    }
  }

  function matching(p: Pattern): string {
    switch (p.kind) {
      case "literal":
        return p.text;
      case "class": {
        const [lo, hi] = pick(p.ranges, [97, 97]);
        return String.fromCodePoint(lo + int(Math.max(1, hi - lo + 1)));
      }
      case "cat":
        return matching(p.first) + matching(p.second);
      case "repeat": {
        const n = p.min + int((p.max ?? p.min + 2) - p.min + 1);
        return Array.from({ length: Math.max(0, n) }, () => matching(p.body)).join("");
      }
      default: {
        const exhaustive: never = p;
        return exhaustive;
      }
    }
  }

  function scalar(): Tree {
    switch (int(5)) {
      case 0:
        return NULL;
      case 1:
        return bool(chance(0.5));
      case 2:
        return num(pick(TOKENS, "0"));
      case 3:
        return num(pick(FRACTIONS, "1.5"));
      default:
        return str(randomText(int(4)));
    }
  }

  function tree(depth: number): Tree {
    if (depth <= 0 || chance(0.5)) return scalar();
    if (chance(0.5)) return arr(...Array.from({ length: int(4) }, () => tree(depth - 1)));
    const keys = [...new Set(Array.from({ length: int(4) }, () => pick(KEYS, "a")))];
    return obj(...keys.map((k): [string, Tree] => [k, tree(depth - 1)]));
  }

  const bound = () => (chance(0.4) ? null : chance(0.03) ? "01" : pick(BOUNDS, "0"));

  function schema(depth: number): Schema {
    const kind = depth <= 0 ? int(6) : int(10);
    switch (kind) {
      case 0: {
        const min = int(3);
        const max = chance(0.4) ? null : chance(0.04) ? Math.max(0, min - 1) : min + int(4);
        const format = chance(0.85) ? "plain" : chance(0.5) ? "email" : "url";
        return { kind: "string", min, max, pattern: chance(0.4) ? pattern(2) : null, format };
      }
      case 1:
        return { kind: "number", min: bound(), max: bound() };
      case 2:
        return { kind: "integer", min: bound(), max: bound() };
      case 3:
        return { kind: "boolean" };
      case 4:
        return { kind: "literal", value: chance(0.05) ? arr() : scalar() };
      case 5:
        return {
          kind: "enum",
          values: Array.from({ length: int(4) }, () => (chance(0.03) ? obj() : scalar())),
        };
      case 6: {
        const min = int(3);
        const max = chance(0.4) ? null : chance(0.04) ? Math.max(0, min - 1) : min + int(3);
        return { kind: "array", items: schema(depth - 1), min, max };
      }
      case 7: {
        const keys = Array.from({ length: int(4) }, () => pick(KEYS, "a"));
        return {
          kind: "object",
          strict: chance(0.5),
          fields: keys.map((key) => {
            const s = schema(depth - 1);
            const presence: Presence = chance(0.4)
              ? { kind: "required" }
              : chance(0.5)
                ? { kind: "optional" }
                : { kind: "default", value: sample(s, 1) };
            return field(key, s, presence);
          }),
        };
      }
      case 8:
        return { kind: "nullable", inner: schema(depth - 1) };
      default:
        return { kind: "union", members: Array.from({ length: int(4) }, () => schema(depth - 1)) };
    }
  }

  // Mostly near-misses and hits for the schema's own shape, sometimes noise.
  function sample(s: Schema, depth: number): Tree {
    if (chance(0.15)) return tree(2);
    switch (s.kind) {
      case "string": {
        if (s.format === "email") return str(pick(EMAILS, "a@b"));
        if (s.format === "url") return str(pick(URLS, "http://a"));
        if (s.pattern !== null && chance(0.6)) return str(matching(s.pattern));
        return str(randomText(Math.max(0, s.min - 1 + int(4))));
      }
      case "number":
      case "integer":
        return num(chance(0.7) ? pick(TOKENS, "0") : pick(FRACTIONS, "1.5"));
      case "boolean":
        return bool(chance(0.5));
      case "literal":
        return chance(0.6) ? s.value : scalar();
      case "enum":
        return chance(0.6) ? pick(s.values, NULL) : scalar();
      case "array": {
        const n = Math.max(0, s.min - 1 + int((s.max ?? s.min + 2) - s.min + 3));
        return arr(...Array.from({ length: n }, () => sample(s.items, depth - 1)));
      }
      case "object": {
        const members: [string, Tree][] = [];
        const seen = new Set<string>();
        for (const f of s.fields) {
          if (seen.has(f.key)) continue;
          seen.add(f.key);
          const keep = f.presence.kind === "required" ? chance(0.9) : chance(0.5);
          if (keep) members.push([f.key, sample(f.schema, depth - 1)]);
        }
        if (chance(0.25)) {
          const extra = pick(KEYS, "a");
          if (!seen.has(extra)) members.push([extra, scalar()]);
        }
        return obj(...members);
      }
      case "nullable":
        return chance(0.3) ? NULL : sample(s.inner, depth);
      case "union":
        return s.members.length > 0 && chance(0.8) ? sample(pick(s.members, s), depth) : scalar();
      default: {
        const exhaustive: never = s;
        return exhaustive;
      }
    }
  }

  return { schema, sample, tree, pattern, matching, int, pick, chance, randomText };
}

// Email and URL candidates around every boundary of the two grammars.
const label = (n: number, c = "a") => (n <= 1 ? c : `${c}${"b".repeat(n - 2)}${c}`.slice(0, n));
const longHost = (n: number) => {
  const parts: string[] = [];
  let left = n;
  while (left > 0) {
    const size = Math.min(63, left);
    parts.push(label(size, "h"));
    left -= size + 1;
  }
  return parts.join(".").slice(0, n);
};
const EMAILS = [
  "a@b",
  "a.b@c.d",
  "first.last+tag@example.com",
  "!#$%&'*+-/=?^_`{|}~@x",
  "a..b@c",
  ".a@b",
  "a.@b",
  "a@b.",
  "a@.b",
  "a@b..c",
  "a@@b",
  "a@b@c",
  "@b",
  "a@",
  "a",
  "",
  '"a"@b',
  "a b@c",
  "a@b c",
  "é@b",
  "a@é",
  "a@-b",
  "a@b-",
  "a@b-c",
  "a@1.2.3.4",
  "a@[1.2.3.4]",
  "a(b)@c",
  "A@B.COM",
  `${"x".repeat(64)}@b`,
  `${"x".repeat(65)}@b`,
  `a@${label(63)}`,
  `a@${label(64)}`,
  `a@${longHost(253)}`,
  `a@${longHost(254)}`,
  `${"x".repeat(64)}@${longHost(189)}`,
  `${"x".repeat(64)}@${longHost(190)}`,
  "a@b\n",
  "a\n@b",
  "😀@b",
];
const URLS = [
  "http://a",
  "https://a",
  "https://example.com/path?q=1#frag",
  "http://a:0",
  "http://a:80/",
  "http://a:00080",
  "http://a:65535",
  "http://a:65536",
  "http://a:99999",
  "http://a:123456",
  "http://a:",
  "http://a:8a",
  "http://a:80x",
  "HTTP://a",
  "Http://a",
  "ftp://a",
  "http:/a",
  "http//a",
  "http://",
  "http://a.",
  "http://.a",
  "http://-a",
  "http://a-",
  "http://user@a",
  "http://[::1]/",
  "http://a/[x]@!$&'()*+,;=",
  "http://a/%41%4a%4F",
  "http://a/%4",
  "http://a/%zz",
  "http://a/%",
  "http://a/ b",
  "http://a/\\b",
  "http://a/é",
  "http://a/<x>",
  'http://a/"',
  "http://a/{x}",
  "http://a/^",
  "http://a/`",
  "http://a/|",
  "http://a?x",
  "http://a#x",
  "http://a?",
  "http://a\n",
  "http://é",
  "http://a b",
  `http://${label(63)}`,
  `http://${label(64)}`,
  `http://${longHost(253)}`,
  `http://${longHost(254)}`,
  `http://${longHost(253)}:80/x`,
  `http://${longHost(254)}:80/x`,
];

function mutate(s: string, g: ReturnType<typeof generators>): string {
  const extras = [
    ".",
    "@",
    ":",
    "/",
    "?",
    "#",
    "%",
    "-",
    " ",
    "é",
    "😀",
    "A",
    "0",
    "[",
    "\\",
    "\n",
  ];
  const chars = [...s];
  const at = g.int(chars.length + 1);
  switch (g.int(3)) {
    case 0:
      chars.splice(at, 0, g.pick(extras, "."));
      break;
    case 1:
      chars.splice(at, 1);
      break;
    default:
      chars.splice(at, 1, g.pick(extras, "."));
  }
  return chars.join("");
}

describe("seeded random schemas of every kind agree with the decoder", () => {
  for (const seed of [37, 370, 3700, 37000]) {
    test(
      `slice ${seed}: 300 schemas, 12 samples each, both regex modes`,
      () => {
        const g = generators(random(seed));
        const kinds = new Map<string, { accepted: number; rejected: number; invalid: number }>();
        for (let i = 0; i < 300; i++) {
          const s = g.schema(2);
          const samples = Array.from({ length: 12 }, () => g.sample(s, 2));
          const { accepted, rejected } = agree(s, samples);
          const row = kinds.get(s.kind) ?? { accepted: 0, rejected: 0, invalid: 0 };
          row.accepted += accepted;
          row.rejected += rejected;
          if (!bend.valid(s)) row.invalid++;
          kinds.set(s.kind, row);
        }
        // Every kind is reached with accepted and rejected samples.
        for (const kind of [
          "string",
          "number",
          "integer",
          "boolean",
          "literal",
          "enum",
          "array",
          "object",
          "nullable",
          "union",
        ]) {
          const row = kinds.get(kind);
          expect(row?.accepted ?? 0).toBeGreaterThan(0);
          expect(row?.rejected ?? 0).toBeGreaterThan(0);
        }
      },
      SLICE_TIMEOUT_MS,
    );
  }
});

type Case = { name: string; schema: Schema; accept: string[]; reject: string[] };

// Hand-written cases per kind, read through Bendo's own JSON parser.
const CASES: Case[] = [
  {
    name: "string lengths count scalars",
    schema: text(1, 2),
    accept: ['"a"', '"😀😀"', '"é"'],
    reject: ['""', '"abc"', "1", "null"],
  },
  {
    name: "string pattern",
    schema: {
      kind: "string",
      min: 0,
      max: null,
      format: "plain",
      pattern: {
        kind: "repeat",
        body: { kind: "literal", text: "a.😀" },
        min: 1,
        max: 2,
      },
    },
    accept: ['"a.😀"', '"a.😀a.😀"'],
    reject: ['""', '"ab😀"', '"a.😀\\n"', '"a.😀a.😀a.😀"', '"xa.😀"'],
  },
  {
    name: "number bounds compare exactly",
    schema: { kind: "number", min: "-3.5", max: "1e2" },
    accept: ["-3.5", "100", "1e2", "0", "-0", "99.5"],
    reject: ["-3.6", "100.5", '"1"', "true"],
  },
  {
    name: "integer bounds may be fractional",
    schema: { kind: "integer", min: "-3.5", max: "2.5" },
    accept: ["-3", "2", "0", "-0"],
    reject: ["-4", "3", "1.5", '"1"'],
  },
  {
    name: "boolean",
    schema: { kind: "boolean" },
    accept: ["true", "false"],
    reject: ["0", "null"],
  },
  {
    name: "numeric literal compares by value",
    schema: { kind: "literal", value: num("1") },
    accept: ["1", "1.0", "1e0", "10e-1"],
    reject: ["2", '"1"', "true"],
  },
  {
    name: "null literal",
    schema: { kind: "literal", value: NULL },
    accept: ["null"],
    reject: ["0", '""', "false"],
  },
  {
    name: "enum with numeric duplicates",
    schema: {
      kind: "enum",
      values: [num("1"), num("1.0"), num("1e0"), str("1"), bool(true), NULL, NULL],
    },
    accept: ["1", "1.00", '"1"', "true", "null"],
    reject: ["2", "false", '"x"'],
  },
  {
    name: "empty enum",
    schema: { kind: "enum", values: [] },
    accept: [],
    reject: ["null", "1", '""'],
  },
  {
    name: "array counts and items",
    schema: { kind: "array", items: { kind: "boolean" }, min: 1, max: 2 },
    accept: ["[true]", "[true,false]"],
    reject: ["[]", "[true,true,true]", "[1]", "{}"],
  },
  {
    name: "strict object: required, optional, default, no undeclared keys",
    schema: {
      kind: "object",
      strict: true,
      fields: [
        field("id", { kind: "integer", min: null, max: null }),
        field("nick", text(1), { kind: "optional" }),
        field(
          "limit",
          { kind: "integer", min: "1", max: null },
          { kind: "default", value: num("10") },
        ),
      ],
    },
    accept: ['{"id":1}', '{"id":1,"nick":"a","limit":2}'],
    reject: ['{"nick":"a"}', '{"id":1,"x":0}', '{"id":1,"nick":null}', '{"id":1,"limit":0}', "[]"],
  },
  {
    name: "strip object ignores undeclared keys and their values",
    schema: { kind: "object", strict: false, fields: [field("a", { kind: "boolean" })] },
    accept: ['{"a":true}', '{"a":true,"b":{"deep":[1,"x"]}}', '{"b":1,"b":2,"a":false}'],
    reject: ['{"b":1}', '{"a":1}'],
  },
  {
    name: "object keys named like Object.prototype members",
    schema: {
      kind: "object",
      strict: true,
      fields: [
        field("constructor", { kind: "boolean" }),
        field("toString", text(), { kind: "optional" }),
      ],
    },
    accept: ['{"constructor":true}', '{"constructor":false,"toString":"x"}'],
    reject: ["{}", '{"toString":"x"}', '{"constructor":1}', '{"constructor":true,"valueOf":1}'],
  },
  {
    name: "optional is absent, nullable is null",
    schema: {
      kind: "object",
      strict: true,
      fields: [
        field("optional", text(), { kind: "optional" }),
        field("nullable", { kind: "nullable", inner: text() }),
      ],
    },
    accept: ['{"nullable":null}', '{"nullable":"x","optional":"y"}'],
    reject: ["{}", '{"nullable":null,"optional":null}'],
  },
  {
    name: "union of overlapping members accepts any member (anyOf)",
    schema: {
      kind: "union",
      members: [
        { kind: "integer", min: null, max: null },
        { kind: "number", min: "0", max: null },
      ],
    },
    accept: ["1", "-1", "0.5"],
    reject: ["-0.5", '"1"'],
  },
  {
    name: "empty union",
    schema: { kind: "union", members: [] },
    accept: [],
    reject: ["null", "{}"],
  },
  {
    name: "nested empty union",
    schema: {
      kind: "nullable",
      inner: { kind: "array", items: { kind: "union", members: [] }, min: 0, max: null },
    },
    accept: ["null", "[]"],
    reject: ["[1]", "1"],
  },
];

describe("hand-written cases for every kind", () => {
  for (const c of CASES) {
    test(c.name, () => {
      expect(bend.valid(c.schema)).toBe(true);
      const document = bend.document(c.schema);
      for (const { mode, ajv } of validators()) {
        const validate = ajv.compile(Object(document));
        for (const json of c.accept) {
          expect([mode, json, validate(JSON.parse(json))]).toEqual([mode, json, true]);
          expect([json, bend.acceptsText(c.schema, json)]).toEqual([json, true]);
        }
        for (const json of c.reject) {
          expect([mode, json, validate(JSON.parse(json))]).toEqual([mode, json, false]);
          expect([json, bend.acceptsText(c.schema, json)]).toEqual([json, false]);
        }
      }
    });
  }
});

test("exported keywords match the mapping table exactly", () => {
  const slug: Pattern = {
    kind: "repeat",
    body: { kind: "class", ranges: [[97, 122]] },
    min: 1,
    max: null,
  };
  expect(bend.document({ kind: "string", min: 1, max: 8, pattern: slug, format: "email" })).toEqual(
    {
      $schema: "https://json-schema.org/draft/2020-12/schema",
      type: "string",
      minLength: 1,
      maxLength: 8,
      pattern: bend.patternSource(slug),
      allOf: [
        {
          $comment: "Bendo email format: ASCII dot-atom local part, one @, DNS hostname",
          pattern: bend.emailSource(),
        },
      ],
      not: { pattern: bend.loneSource() },
    },
  );
  expect(bend.patternSource(slug)).toBe("^(?:(?:[\\x61-\\x7a])+)(?![\\s\\S])");
  // Bounds keep the token's spelling, numbers and all.
  expect(bend.documentText({ kind: "number", min: "-0", max: "1E+2" })).toBe(
    '{"$schema":"https://json-schema.org/draft/2020-12/schema","type":"number","minimum":-0,"maximum":1E+2}',
  );
  expect(bend.exported({ kind: "integer", min: "1", max: null })).toEqual({
    type: "integer",
    minimum: 1,
    $comment: "Bendo accepts only integer tokens -?(0|[1-9][0-9]*); 1.0 and 1e0 are rejected",
  });
  expect(bend.exported({ kind: "boolean" })).toEqual({ type: "boolean" });
  expect(bend.exported({ kind: "literal", value: str("x") })).toEqual({ const: "x" });
  expect(
    bend.exported({
      kind: "enum",
      values: [num("1"), num("1.0"), num("1e0"), str("1"), NULL, NULL],
    }),
  ).toEqual({ enum: [1, "1", null] });
  expect(bend.exported({ kind: "enum", values: [] })).toEqual({ not: {} });
  expect(bend.exported({ kind: "union", members: [] })).toEqual({ not: {} });
  expect(bend.never()).toEqual({ not: {} });
  expect(bend.exported({ kind: "array", items: { kind: "boolean" }, min: 0, max: 3 })).toEqual({
    type: "array",
    items: { type: "boolean" },
    minItems: 0,
    maxItems: 3,
  });
  expect(
    bend.exported({
      kind: "object",
      strict: true,
      fields: [
        field("a", { kind: "boolean" }),
        field("b", { kind: "boolean" }, { kind: "optional" }),
        field("c", { kind: "boolean" }, { kind: "default", value: bool(false) }),
      ],
    }),
  ).toEqual({
    type: "object",
    properties: {
      a: { type: "boolean" },
      b: { type: "boolean" },
      c: { type: "boolean", default: false },
    },
    required: ["a"],
    additionalProperties: false,
    $comment: "Bendo rejects an object that repeats a declared key",
  });
  expect(bend.exported({ kind: "object", strict: false, fields: [] })).toEqual({
    type: "object",
    properties: {},
    required: [],
    additionalProperties: true,
    $comment:
      "Bendo rejects an object that repeats a declared key and drops undeclared keys while decoding",
  });
  expect(bend.exported({ kind: "nullable", inner: { kind: "boolean" } })).toEqual({
    anyOf: [{ type: "null" }, { type: "boolean" }],
  });
  expect(
    bend.exported({
      kind: "union",
      members: [{ kind: "boolean" }, { kind: "literal", value: NULL }],
    }),
  ).toEqual({
    $comment: "Bendo decodes with the first matching member",
    anyOf: [{ type: "boolean" }, { const: null }],
  });
});

describe("invalid schemas export a schema that accepts nothing", () => {
  const bad = (min: number, max: number): Pattern => ({
    kind: "repeat",
    body: { kind: "class", ranges: [[97, 97]] },
    min,
    max,
  });
  const invalid: [string, Schema][] = [
    ["string min above max", text(3, 2)],
    [
      "non-ASCII class range",
      {
        kind: "string",
        min: 0,
        max: null,
        format: "plain",
        pattern: { kind: "class", ranges: [[97, 300]] },
      },
    ],
    [
      "reversed pattern counts",
      { kind: "string", min: 0, max: null, format: "plain", pattern: bad(2, 1) },
    ],
    [
      "pattern over the size cap",
      { kind: "string", min: 0, max: null, format: "plain", pattern: bad(0, 128) },
    ],
    ["malformed number bound", { kind: "number", min: "01", max: null }],
    ["reversed integer bounds", { kind: "integer", min: "2", max: "1" }],
    ["array literal", { kind: "literal", value: arr() }],
    ["object enum member", { kind: "enum", values: [num("1"), obj()] }],
    ["array min above max", { kind: "array", items: { kind: "boolean" }, min: 2, max: 1 }],
    [
      "duplicate declared key",
      {
        kind: "object",
        strict: true,
        fields: [field("a", { kind: "boolean" }), field("a", text())],
      },
    ],
    [
      "default outside its schema",
      {
        kind: "object",
        strict: true,
        fields: [field("a", text(2), { kind: "default", value: str("x") })],
      },
    ],
    [
      "invalid union member never reached",
      { kind: "union", members: [{ kind: "boolean" }, text(1, 0)] },
    ],
    [
      "invalid deep inside",
      {
        kind: "nullable",
        inner: {
          kind: "array",
          items: {
            kind: "object",
            strict: false,
            fields: [field("x", { kind: "integer", min: "x", max: null })],
          },
          min: 0,
          max: null,
        },
      },
    ],
  ];
  for (const [name, schema] of invalid) {
    test(name, () => {
      expect(bend.valid(schema)).toBe(false);
      expect(bend.exported(schema)).toEqual(bend.invalid());
      expect(bend.invalid()).toEqual({
        $comment: "invalid Bendo schema: the decoder rejects every value",
        not: {},
      });
      const g = generators(random(name.length));
      const samples = [
        NULL,
        bool(true),
        num("1"),
        str("aa"),
        arr(bool(true)),
        obj(["a", bool(true)]),
      ];
      for (let i = 0; i < 20; i++) samples.push(g.tree(2));
      const { accepted } = agree(schema, samples);
      expect(accepted).toBe(0);
    });
  }
});

describe("exported patterns match the decoder's matcher in both regex modes", () => {
  for (const seed of [11, 12]) {
    test(
      `slice ${seed}: 400 patterns`,
      () => {
        const g = generators(random(seed));
        let accepted = 0;
        for (let i = 0; i < 400; i++) {
          const p = g.pattern(3);
          const s: Schema = { kind: "string", min: 0, max: null, pattern: p, format: "plain" };
          const samples = Array.from({ length: 8 }, () =>
            str(g.chance(0.6) ? g.matching(p) : mutate(g.matching(p), g)),
          );
          accepted += agree(s, samples).accepted;
        }
        expect(accepted).toBeGreaterThan(400);
      },
      SLICE_TIMEOUT_MS,
    );
  }
});

describe("email and url patterns equal the decoder's grammars", () => {
  const sources = () => {
    const email = bend.emailSource();
    const url = bend.urlSource();
    return [
      { name: "email", check: bend.email, res: [new RegExp(email), new RegExp(email, "u")] },
      { name: "url", check: bend.url, res: [new RegExp(url), new RegExp(url, "u")] },
    ];
  };
  test("boundary candidates", () => {
    for (const { name, check, res } of sources()) {
      const list = name === "email" ? EMAILS : URLS;
      let accepted = 0;
      for (const s of list) {
        const want = check(s);
        if (want) accepted++;
        for (const re of res)
          expect([name, s, re.flags, re.test(s)]).toEqual([name, s, re.flags, want]);
      }
      expect(accepted).toBeGreaterThan(5);
      expect(accepted).toBeLessThan(list.length - 5);
    }
  });
  for (const seed of [21, 22]) {
    test(
      `slice ${seed}: 3,000 mutated candidates per format`,
      () => {
        const g = generators(random(seed));
        for (const { name, check, res } of sources()) {
          const list = name === "email" ? EMAILS : URLS;
          let accepted = 0;
          for (let i = 0; i < 3000; i++) {
            let s = g.pick(list, "a@b");
            for (let k = g.int(3); k > 0; k--) s = mutate(s, g);
            const want = check(s);
            if (want) accepted++;
            for (const re of res)
              expect([name, s, re.flags, re.test(s)]).toEqual([name, s, re.flags, want]);
          }
          expect(accepted).toBeGreaterThan(100);
        }
      },
      SLICE_TIMEOUT_MS,
    );
  }
});

// Every high surrogate is followed by a low one and every low one follows a high one.
function wellFormed(s: string): boolean {
  for (let i = 0; i < s.length; i++) {
    const c = s.charCodeAt(i);
    if (c >= 0xd800 && c <= 0xdbff) {
      const d = s.charCodeAt(i + 1);
      if (!(d >= 0xdc00 && d <= 0xdfff)) return false;
      i++;
    } else if (c >= 0xdc00 && c <= 0xdfff) return false;
  }
  return true;
}

test("the lone-surrogate guard rejects exactly the ill-formed strings in both modes", () => {
  const units = ["a", "\ud800", "\udbff", "\udc00", "\udfff", "\ud83d", "\ude00", "😀", "é"];
  // Every sequence of up to three units, then random longer ones.
  const all: string[] = [""];
  let layer = [""];
  for (let n = 1; n <= 3; n++) {
    layer = layer.flatMap((prefix) => units.map((u) => prefix + u));
    all.push(...layer);
  }
  const g = generators(random(5));
  for (let i = 0; i < 2000; i++)
    all.push(Array.from({ length: g.int(8) }, () => g.pick(units, "a")).join(""));
  const source = bend.loneSource();
  const schema = bend.document(text());
  const ajvs = validators().map(({ ajv }) => ajv.compile(Object(schema)));
  let ill = 0;
  for (const s of all) {
    const ok = wellFormed(s);
    if (!ok) ill++;
    expect([s, new RegExp(source).test(s)]).toEqual([s, !ok]);
    expect([s, new RegExp(source, "u").test(s)]).toEqual([s, !ok]);
    for (const validate of ajvs) expect([s, validate(s)]).toEqual([s, ok]);
  }
  expect(ill).toBeGreaterThan(500);
});

// Decoder policy that no JSON Schema validator can express. Each test pins
// the documented difference, so a change on either side shows up here.
describe("documented decoder policy beyond JSON Schema", () => {
  const anyInteger: Schema = { kind: "integer", min: null, max: null };
  test("integers are lexical: 1.0, 1e0 and 1e2 are integers to JSON Schema only", () => {
    const validate = validators()[0]?.ajv.compile(Object(bend.document(anyInteger)));
    for (const token of ["1.0", "1e0", "1e2", "-0.0", "1E+1"]) {
      expect(validate?.(JSON.parse(token))).toBe(true);
      expect(bend.acceptsText(anyInteger, token)).toBe(false);
    }
  });
  test("a repeated declared key is rejected; JSON.parse keeps the last", () => {
    const schema: Schema = {
      kind: "object",
      strict: false,
      fields: [field("a", { kind: "boolean" })],
    };
    const validate = validators()[0]?.ajv.compile(Object(bend.document(schema)));
    const json = '{"a":true,"a":false}';
    expect(validate?.(JSON.parse(json))).toBe(true);
    expect(bend.acceptsText(schema, json)).toBe(false);
  });
  test("numbers compare as exact decimals; JavaScript rounds the token first", () => {
    const schema: Schema = { kind: "number", min: null, max: "100" };
    const validate = validators()[0]?.ajv.compile(Object(bend.document(schema)));
    const json = "100.00000000000000001";
    expect(validate?.(JSON.parse(json))).toBe(true);
    expect(bend.acceptsText(schema, json)).toBe(false);
  });
  test("Ajv ignores a __proto__ property schema; the export states it in standard form", () => {
    const schema: Schema = {
      kind: "object",
      strict: true,
      fields: [field("__proto__", { kind: "boolean" })],
    };
    expect(bend.exported(schema)).toMatchObject({
      properties: { ["__proto__"]: { type: "boolean" } },
      required: ["__proto__"],
      additionalProperties: false,
    });
    expect(bend.acceptsText(schema, '{"__proto__":true}')).toBe(true);
    expect(bend.acceptsText(schema, '{"__proto__":1}')).toBe(false);
    expect(bend.acceptsText(schema, "{}")).toBe(false);
  });
  test("defaults are annotations: absent keys validate, only the decoder fills them", () => {
    const schema: Schema = {
      kind: "object",
      strict: true,
      fields: [field("limit", anyInteger, { kind: "default", value: num("10") })],
    };
    const validate = validators()[0]?.ajv.compile(Object(bend.document(schema)));
    const value: unknown = JSON.parse("{}");
    expect(validate?.(value)).toBe(true);
    expect(value).toEqual({});
    expect(bend.acceptsText(schema, "{}")).toBe(true);
  });
});
