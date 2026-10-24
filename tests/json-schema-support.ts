// Shared encoders for the JSON Schema export tests (BND-37): a TypeScript model
// of Bend schemas and JSON trees, their Bend `.mjs` encodings, and the
// exporter consumer compiled once per test file.
import Ajv2020 from "ajv/dist/2020.js";
import { pathToFileURL } from "node:url";
import { compile } from "./harness.ts";

export type Pattern =
  | { kind: "literal"; text: string }
  | { kind: "class"; ranges: [number, number][] }
  | { kind: "cat"; first: Pattern; second: Pattern }
  | { kind: "repeat"; body: Pattern; min: number; max: number | null };

export type Tree =
  | { kind: "null" }
  | { kind: "bool"; value: boolean }
  | { kind: "number"; token: string }
  | { kind: "string"; value: string }
  | { kind: "array"; items: Tree[] }
  | { kind: "object"; members: [string, Tree][] };

export type Presence =
  | { kind: "required" }
  | { kind: "optional" }
  | { kind: "default"; value: Tree };

export type Format = "plain" | "email" | "url";

export type Schema =
  | { kind: "string"; min: number; max: number | null; pattern: Pattern | null; format: Format }
  | { kind: "number"; min: string | null; max: string | null }
  | { kind: "integer"; min: string | null; max: string | null }
  | { kind: "boolean" }
  | { kind: "literal"; value: Tree }
  | { kind: "enum"; values: Tree[] }
  | { kind: "array"; items: Schema; min: number; max: number | null }
  | {
      kind: "object";
      fields: { key: string; schema: Schema; presence: Presence }[];
      strict: boolean;
    }
  | { kind: "nullable"; inner: Schema }
  | { kind: "union"; members: Schema[] };

type BendList = { $: "Nil" } | { $: "Con"; head: unknown; tail: BendList };

export function list(xs: unknown[]): BendList {
  return xs.reduceRight<BendList>((tail, head) => ({ $: "Con", head, tail }), { $: "Nil" });
}

function maybe(value: unknown): unknown {
  return value === null ? { $: "None" } : { $: "Some", value };
}

export function bendPattern(p: Pattern): unknown {
  switch (p.kind) {
    case "literal":
      return { $: "Literal", text: p.text };
    case "class":
      return { $: "Class", ranges: list(p.ranges.map(([lo, hi]) => ({ $: "Range", lo, hi }))) };
    case "cat":
      return { $: "Cat", first: bendPattern(p.first), second: bendPattern(p.second) };
    case "repeat":
      return { $: "Repeat", body: bendPattern(p.body), min: p.min, max: maybe(p.max) };
    default: {
      const exhaustive: never = p;
      return exhaustive;
    }
  }
}

export function bendTree(t: Tree): unknown {
  switch (t.kind) {
    case "null":
      return { $: "JNull" };
    case "bool":
      return { $: "JBool", value: t.value };
    case "number":
      return { $: "JNumber", value: t.token };
    case "string":
      return { $: "JString", value: t.value };
    case "array":
      return { $: "JArray", items: list(t.items.map(bendTree)) };
    case "object":
      return {
        $: "JObject",
        fields: list(
          t.members.map(([key, value]) => ({ $: "Field", key, value: bendTree(value) })),
        ),
      };
    default: {
      const exhaustive: never = t;
      return exhaustive;
    }
  }
}

function bendPresence(p: Presence): unknown {
  switch (p.kind) {
    case "required":
      return { $: "Required" };
    case "optional":
      return { $: "Optional" };
    case "default":
      return { $: "Default", value: bendTree(p.value) };
    default: {
      const exhaustive: never = p;
      return exhaustive;
    }
  }
}

const FORMATS = { plain: "Plain", email: "Email", url: "Url" } satisfies Record<Format, string>;

export function bendSchema(s: Schema): unknown {
  switch (s.kind) {
    case "string":
      return {
        $: "StringSchema",
        min_len: s.min,
        max_len: maybe(s.max),
        pattern: s.pattern === null ? { $: "None" } : { $: "Some", value: bendPattern(s.pattern) },
        format: { $: FORMATS[s.format] },
      };
    case "number":
      return { $: "NumberSchema", min: maybe(s.min), max: maybe(s.max) };
    case "integer":
      return { $: "IntegerSchema", min: maybe(s.min), max: maybe(s.max) };
    case "boolean":
      return { $: "BooleanSchema" };
    case "literal":
      return { $: "LiteralSchema", value: bendTree(s.value) };
    case "enum":
      return { $: "EnumSchema", values: list(s.values.map(bendTree)) };
    case "array":
      return {
        $: "ArraySchema",
        items: bendSchema(s.items),
        min_items: s.min,
        max_items: maybe(s.max),
      };
    case "object":
      return {
        $: "ObjectSchema",
        fields: list(
          s.fields.map((f) => ({
            $: "Field",
            key: f.key,
            schema: bendSchema(f.schema),
            presence: bendPresence(f.presence),
          })),
        ),
        unknown: { $: s.strict ? "Strict" : "Strip" },
      };
    case "nullable":
      return { $: "NullableSchema", inner: bendSchema(s.inner) };
    case "union":
      return { $: "UnionSchema", members: list(s.members.map(bendSchema)) };
    default: {
      const exhaustive: never = s;
      return exhaustive;
    }
  }
}

/** JSON text exactly as the tree spells it, duplicate keys included. */
export function write(t: Tree): string {
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

/** The exporter consumer, compiled to `.mjs` through the shared fixture cache. */
export async function loadConsumer() {
  const path = compile("tests/fixtures/json-schema/consumer.bend", "mjs");
  const imported: unknown = await import(pathToFileURL(path).href);
  if (typeof imported !== "object" || imported === null || !("default" in imported))
    throw new Error("Missing Bend exports");
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
  function yes(name: string, ...args: unknown[]): boolean {
    const out = text(name, ...args);
    if (out !== "yes" && out !== "no") throw new Error(`${name} returned ${out}`);
    return out === "yes";
  }
  return {
    document: (s: Schema): unknown => JSON.parse(text("document", bendSchema(s))),
    documentText: (s: Schema): string => text("document", bendSchema(s)),
    exported: (s: Schema): unknown => JSON.parse(text("exported", bendSchema(s))),
    invalid: (): unknown => JSON.parse(text("invalid")),
    never: (): unknown => JSON.parse(text("never")),
    valid: (s: Schema): boolean => yes("valid", bendSchema(s)),
    /** The decoder's verdict on a tree built directly, without the parser. */
    accepts: (s: Schema, t: Tree): boolean => yes("accepts", bendSchema(s), bendTree(t)),
    /** The decoder's verdict on JSON text read by Bendo's own parser. */
    acceptsText: (s: Schema, json: string): boolean | "unparsed" => {
      const parsed = call("parsed", json);
      if (typeof parsed !== "object" || parsed === null) throw new Error("bad parse result");
      if (Reflect.get(parsed, "$") !== "Done") return "unparsed";
      return yes("accepts", bendSchema(s), Reflect.get(parsed, "value"));
    },
    email: (s: string): boolean => yes("email", s),
    url: (s: string): boolean => yes("url", s),
    emailSource: (): string => text("email_source"),
    urlSource: (): string => text("url_source"),
    loneSource: (): string => text("lone_source"),
    patternSource: (p: Pattern): string => text("pattern_source", bendPattern(p)),
  };
}

/**
 * Both regular-expression modes. `ownProperties` makes Ajv read only an
 * object's own members, as JSON Schema requires; its default reads inherited
 * ones such as `constructor`.
 */
export function validators(): { mode: string; ajv: Ajv2020 }[] {
  return [
    { mode: "u", ajv: new Ajv2020({ strict: true, ownProperties: true }) },
    {
      mode: "no-u",
      ajv: new Ajv2020({ strict: true, ownProperties: true, unicodeRegExp: false }),
    },
  ];
}

export function random(seed: number): () => number {
  let a = seed;
  return () => {
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
