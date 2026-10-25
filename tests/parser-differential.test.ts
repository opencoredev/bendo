// BND-92: seeded differential tests for the parsers route validation shares
// with its specification.
//
// J.parse has no universal law against a grammar (docs/laws/data.md says
// why). Here it is compared, on generated and mutated inputs, with an
// independent recursive-descent RFC 8259 parser written below from the
// grammar and Bendo's policy: strict UTF-8, lexical numbers, ordered
// members with duplicates, no lone surrogate escapes, at most 512 nested
// containers. That reference is itself checked against Bun's JSON.parse
// through a strictness shim, so a bug has to fool two parsers to pass.
//
// Url.parse_pairs is proven equal to proof/query-spec.bend for every input
// (query_parse_matches_spec). This file checks that specification against
// the WHATWG parser Bun ships as URLSearchParams.
import { compile } from "./harness.ts";
import { describe, expect, test } from "bun:test";
import { pathToFileURL } from "node:url";

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

async function load(entry: string): Promise<(name: string, ...args: unknown[]) => unknown> {
  const imported: unknown = await import(pathToFileURL(compile(entry, "mjs")).href);
  if (typeof imported !== "object" || imported === null || !("default" in imported)) {
    throw new Error(`Missing module default: ${entry}`);
  }
  const exported: unknown = imported.default;
  return (name, ...args) => {
    if (typeof exported !== "object" || exported === null) throw new Error("Invalid Bend module");
    const fn: unknown = Reflect.get(exported, name);
    if (typeof fn !== "function") throw new Error(`Missing callable ${name}`);
    return fn(...args);
  };
}

const json = await load("tests/fixtures/json/consumer.bend");
const forms = await load("tests/fixtures/forms/consumer.bend");

// ---- seeded generation ----

function prng(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

type Rand = { next: () => number; int: (n: number) => number; pick: <T>(xs: readonly T[]) => T };
function rand(seed: number): Rand {
  const next = prng(seed);
  const int = (n: number): number => Math.floor(next() * n);
  return {
    next,
    int,
    pick: <T>(xs: readonly T[]): T => {
      const x = xs[int(xs.length)];
      if (x === undefined) throw new Error("Empty choice");
      return x;
    },
  };
}

// ---- the JSON tree both sides are compared in ----

type Tree =
  | { readonly kind: "null" }
  | { readonly kind: "bool"; readonly value: boolean }
  | { readonly kind: "number"; readonly text: string }
  | { readonly kind: "string"; readonly text: string }
  | { readonly kind: "array"; readonly items: readonly Tree[] }
  | { readonly kind: "object"; readonly fields: readonly (readonly [string, Tree])[] };

type Outcome =
  | { readonly kind: "done"; readonly value: Tree }
  | { readonly kind: "fail"; readonly error: "Syntax" | "InvalidUtf8" | "DepthLimit" };

// ---- the independent reference parser ----

const MAX_DEPTH = 512;

class Reject extends Error {
  readonly error: "Syntax" | "DepthLimit";
  constructor(error: "Syntax" | "DepthLimit") {
    super(error);
    this.error = error;
  }
}

// RFC 8259 over code points, written from the grammar. Errors are found in
// input order, as a streaming parser finds them.
function reference(bytes: Uint8Array): Outcome {
  let text: string;
  try {
    text = new TextDecoder("utf-8", { fatal: true, ignoreBOM: true }).decode(bytes);
  } catch {
    return { kind: "fail", error: "InvalidUtf8" };
  }
  const cps = Array.from(text, (c) => c.codePointAt(0) ?? 0);
  let i = 0;
  const peek = (): number | undefined => cps[i];
  const syntax = (): never => {
    throw new Reject("Syntax");
  };
  const ws = (): void => {
    for (let c = peek(); c === 0x20 || c === 0x09 || c === 0x0a || c === 0x0d; c = peek()) i++;
  };
  const expect = (c: number): void => {
    if (peek() !== c) syntax();
    i++;
  };
  const isDigit = (c: number | undefined): c is number => c !== undefined && c >= 0x30 && c <= 0x39;
  const hex = (): number => {
    const c = peek();
    if (c === undefined) return syntax();
    i++;
    if (c >= 0x30 && c <= 0x39) return c - 0x30;
    if (c >= 0x41 && c <= 0x46) return c - 0x37;
    if (c >= 0x61 && c <= 0x66) return c - 0x57;
    return syntax();
  };
  const quad = (): number => hex() * 4096 + hex() * 256 + hex() * 16 + hex();
  const string = (): string => {
    expect(0x22);
    let out = "";
    for (;;) {
      const c = peek();
      if (c === undefined) return syntax();
      i++;
      if (c === 0x22) return out;
      if (c < 0x20) return syntax();
      if (c !== 0x5c) {
        out += String.fromCodePoint(c);
        continue;
      }
      const e = peek();
      i++;
      const short: Record<number, string> = {
        0x22: '"',
        0x5c: "\\",
        0x2f: "/",
        0x62: "\b",
        0x66: "\f",
        0x6e: "\n",
        0x72: "\r",
        0x74: "\t",
      };
      if (e === undefined) return syntax();
      const s = short[e];
      if (s !== undefined) {
        out += s;
        continue;
      }
      if (e !== 0x75) return syntax();
      const code = quad();
      if (code >= 0xdc00 && code <= 0xdfff) return syntax();
      if (code < 0xd800 || code > 0xdbff) {
        out += String.fromCodePoint(code);
        continue;
      }
      expect(0x5c);
      expect(0x75);
      const low = quad();
      if (low < 0xdc00 || low > 0xdfff) return syntax();
      out += String.fromCodePoint(0x10000 + (code - 0xd800) * 1024 + (low - 0xdc00));
    }
  };
  const number = (): string => {
    const start = i;
    if (peek() === 0x2d) i++;
    if (peek() === 0x30) i++;
    else if (isDigit(peek()) && peek() !== 0x30) while (isDigit(peek())) i++;
    else syntax();
    if (peek() === 0x2e) {
      i++;
      if (!isDigit(peek())) syntax();
      while (isDigit(peek())) i++;
    }
    if (peek() === 0x65 || peek() === 0x45) {
      i++;
      if (peek() === 0x2b || peek() === 0x2d) i++;
      if (!isDigit(peek())) syntax();
      while (isDigit(peek())) i++;
    }
    return String.fromCodePoint(...cps.slice(start, i));
  };
  const literal = (word: string, tree: Tree): Tree => {
    for (const ch of word) expect(ch.charCodeAt(0));
    return tree;
  };
  const value = (depth: number): Tree => {
    ws();
    const c = peek();
    if (c === 0x7b || c === 0x5b) {
      if (depth >= MAX_DEPTH) throw new Reject("DepthLimit");
      i++;
      ws();
      if (c === 0x5b) {
        const items: Tree[] = [];
        if (peek() === 0x5d) {
          i++;
          return { kind: "array", items };
        }
        for (;;) {
          items.push(value(depth + 1));
          ws();
          if (peek() === 0x2c) i++;
          else {
            expect(0x5d);
            return { kind: "array", items };
          }
        }
      }
      const fields: (readonly [string, Tree])[] = [];
      if (peek() === 0x7d) {
        i++;
        return { kind: "object", fields };
      }
      for (;;) {
        ws();
        const key = string();
        ws();
        expect(0x3a);
        fields.push([key, value(depth + 1)]);
        ws();
        if (peek() === 0x2c) i++;
        else {
          expect(0x7d);
          return { kind: "object", fields };
        }
      }
    }
    if (c === 0x22) return { kind: "string", text: string() };
    if (c === 0x74) return literal("true", { kind: "bool", value: true });
    if (c === 0x66) return literal("false", { kind: "bool", value: false });
    if (c === 0x6e) return literal("null", { kind: "null" });
    return { kind: "number", text: number() };
  };
  try {
    const v = value(0);
    ws();
    if (i !== cps.length) syntax();
    return { kind: "done", value: v };
  } catch (e) {
    if (e instanceof Reject) return { kind: "fail", error: e.error };
    throw e;
  }
}

// ---- Bun's JSON.parse, made strict ----

// JSON.parse accepts lone surrogate escapes and any depth; Bendo does not.
// A duplicate key's earlier value is gone from JSON.parse's result, so both
// checks read the accepted text instead. In valid JSON every backslash is
// inside a string, so escapes scan left to right without a lexer.
function loneSurrogateEscape(text: string): boolean {
  const escapes = [...text.matchAll(/\\(u[0-9a-fA-F]{4}|[^u])/g)];
  let pendingHigh = false;
  let end = -1;
  for (const m of escapes) {
    const unit = m[1]?.startsWith("u") ? parseInt(m[1].slice(1), 16) : -1;
    const adjacent = m.index === end;
    if (pendingHigh && !(adjacent && unit >= 0xdc00 && unit <= 0xdfff)) return true;
    if (!pendingHigh && unit >= 0xdc00 && unit <= 0xdfff) return true;
    pendingHigh = !pendingHigh && unit >= 0xd800 && unit <= 0xdbff;
    end = m.index + m[0].length;
  }
  return pendingHigh;
}

function nesting(text: string): number {
  let depth = 0;
  let deepest = 0;
  for (const c of text.replaceAll(/"(?:[^"\\]|\\.)*"/g, "")) {
    if (c === "[" || c === "{") deepest = Math.max(deepest, ++depth);
    else if (c === "]" || c === "}") depth--;
  }
  return deepest;
}

function strictAccepts(bytes: Uint8Array): boolean {
  let text: string;
  try {
    text = strictText(bytes);
    JSON.parse(text);
  } catch {
    return false;
  }
  return !loneSurrogateEscape(text) && nesting(text) <= MAX_DEPTH;
}

// What JSON.parse makes of a tree: numbers as doubles, a repeated key's
// last value.
function plain(t: Tree): unknown {
  switch (t.kind) {
    case "null":
      return null;
    case "bool":
      return t.value;
    case "number":
      return Number(t.text);
    case "string":
      return t.text;
    case "array":
      return t.items.map(plain);
    case "object": {
      const o: Record<string, unknown> = {};
      for (const [k, v] of t.fields)
        Object.defineProperty(o, k, {
          value: plain(v),
          enumerable: true,
          writable: true,
          configurable: true,
        });
      return o;
    }
  }
}

// ---- reading Bend's result ----

function record(x: unknown): Record<string, unknown> {
  if (typeof x !== "object" || x === null) throw new Error(`Expected a Bend value: ${String(x)}`);
  return Object.fromEntries(Object.entries(x));
}
function items(x: unknown): unknown[] {
  const out: unknown[] = [];
  for (let r = record(x); r.$ === "Con"; r = record(r.tail)) out.push(r.head);
  return out;
}
function text(x: unknown): string {
  if (typeof x !== "string") throw new Error("Expected a Bend string");
  return x;
}
function tree(x: unknown): Tree {
  const r = record(x);
  switch (r.$) {
    case "JNull":
      return { kind: "null" };
    case "JBool":
      return { kind: "bool", value: r.value === true };
    case "JNumber":
      return { kind: "number", text: text(r.value) };
    case "JString":
      return { kind: "string", text: text(r.value) };
    case "JArray":
      return { kind: "array", items: items(r.items).map(tree) };
    case "JObject":
      return {
        kind: "object",
        fields: items(r.fields).map((f): readonly [string, Tree] => {
          const field = record(f);
          return [text(field.key), tree(field.value)];
        }),
      };
    default:
      throw new Error(`Unknown JSON constructor ${String(r.$)}`);
  }
}
function bendParse(bytes: Uint8Array): Outcome | { readonly kind: "other"; readonly what: string } {
  const r = record(json("parse", list([...bytes])));
  if (r.$ === "Done") return { kind: "done", value: tree(r.value) };
  const error = record(r.error).$;
  if (error === "Syntax" || error === "InvalidUtf8" || error === "DepthLimit")
    return { kind: "fail", error };
  return { kind: "other", what: String(error) };
}

// ---- generating JSON text ----

const keyPool = ["a", "b", "a", "", "é", "😀", "__proto__", "1", "\\", '"', " "];
const charPool = [
  ..."azAZ09 _-/~{}[]:,",
  '"',
  "\\",
  "\u0000",
  "\u0008",
  "\u001f",
  "\u007f",
  "é",
  "߿",
  "ࠀ",
  " ",
  "퟿",
  "",
  "﻿",
  "￿",
  "😀",
  "\u{10ffff}",
];
const wildEscapes = [
  "\\ud800",
  "\\uDBFF",
  "\\udc00",
  "\\uDFFF",
  "\\ud7ff",
  "\\ue000",
  "\\uD83D\\uDE00",
  "\\udbff\\udfff",
  "\\ud800\\udbff",
  "\\ud800\\ue000",
  "\\ud83d\\u0041",
  "\\ud83dx",
  "\\ud83d\\",
  "\\u12G4",
  "\\u00",
  "\\x41",
  "\\U00e9",
  "\\u0000",
  "\\u001F",
];
const space = ["", "", "", " ", "\t", "\n", "\r", " \n\t"];

function hex4(r: Rand, n: number): string {
  const h = n.toString(16).padStart(4, "0");
  return [...h].map((c) => (r.int(2) === 0 ? c : c.toUpperCase())).join("");
}

function spell(r: Rand, s: string): string {
  let out = '"';
  for (const ch of s) {
    const cp = ch.codePointAt(0) ?? 0;
    const short: Record<string, string> = {
      '"': '\\"',
      "\\": "\\\\",
      "/": "\\/",
      "\b": "\\b",
      "\f": "\\f",
      "\n": "\\n",
      "\r": "\\r",
      "\t": "\\t",
    };
    const forced = cp < 0x20 || ch === '"' || ch === "\\";
    const choice = r.int(4);
    if (!forced && choice < 2) out += ch;
    else if (short[ch] !== undefined && choice !== 3) out += short[ch];
    else if (cp > 0xffff) {
      const v = cp - 0x10000;
      out += `\\u${hex4(r, 0xd800 + (v >> 10))}\\u${hex4(r, 0xdc00 + (v & 0x3ff))}`;
    } else out += `\\u${hex4(r, cp)}`;
  }
  return out + '"';
}

function numberText(r: Rand): string {
  const digits = (n: number, lead: boolean): string =>
    Array.from({ length: n }, (_, k) => String(k === 0 && lead ? 1 + r.int(9) : r.int(10))).join(
      "",
    );
  let s = r.int(3) === 0 ? "-" : "";
  s += r.int(3) === 0 ? "0" : digits(1 + r.int(4), true);
  if (r.int(3) === 0) s += "." + digits(1 + r.int(3), false);
  if (r.int(3) === 0)
    s += r.pick(["e", "E"]) + r.pick(["", "+", "-"]) + digits(1 + r.int(3), false);
  return s;
}

function generate(r: Rand, depth: number): string {
  const w = (): string => r.pick(space);
  const kind = depth > 4 ? r.int(5) : r.int(7);
  switch (kind) {
    case 0:
      return r.pick(["null", "true", "false"]);
    case 1:
    case 2:
      return numberText(r);
    case 3: {
      const n = r.int(5);
      return spell(r, Array.from({ length: n }, () => r.pick(charPool)).join(""));
    }
    case 4: {
      // Escapes at the edges of the surrogate ranges and malformed ones.
      const n = 1 + r.int(3);
      const parts = Array.from({ length: n }, () => r.pick(wildEscapes));
      return spell(r, r.pick(charPool)).slice(0, -1) + parts.join("") + '"';
    }
    case 5: {
      const n = r.int(4);
      const parts = Array.from({ length: n }, () => w() + generate(r, depth + 1) + w());
      return "[" + (n === 0 ? w() : parts.join(",")) + "]";
    }
    default: {
      const n = r.int(4);
      const parts = Array.from(
        { length: n },
        () => w() + spell(r, r.pick(keyPool)) + w() + ":" + w() + generate(r, depth + 1) + w(),
      );
      return "{" + (n === 0 ? w() : parts.join(",")) + "}";
    }
  }
}

const mutationBytes = [
  ...'{}[]:,"\\0123456789-+.eEtrufalsn \t\n\r/xDd8'.split("").map((c) => c.charCodeAt(0)),
  0x00,
  0x1f,
  0x7f,
  0x80,
  0xa9,
  0xc3,
  0xc0,
  0xed,
  0xa0,
  0xf4,
  0x90,
  0xfe,
  0xff,
];

function mutate(r: Rand, input: Uint8Array): Uint8Array {
  const bytes = [...input];
  for (let n = 1 + r.int(3); n > 0; n--) {
    const at = r.int(bytes.length + 1);
    switch (r.int(5)) {
      case 0:
        bytes.splice(at, 1);
        break;
      case 1:
        bytes.splice(at, 0, r.pick(mutationBytes));
        break;
      case 2:
        bytes.splice(at, 1, r.pick(mutationBytes));
        break;
      case 3:
        bytes.splice(at, 0, ...bytes.slice(at, at + 1 + r.int(4)));
        break;
      default:
        bytes.length = Math.min(bytes.length, at);
    }
  }
  return Uint8Array.from(bytes);
}

function nest(r: Rand, depth: number): string {
  let s = generate(r, 5);
  for (let k = 0; k < depth; k++) s = r.int(2) === 0 ? `[${s}]` : `{"k":${s}}`;
  return s;
}

const utf8 = (s: string): Uint8Array => new TextEncoder().encode(s);
const strictText = (bytes: Uint8Array): string =>
  new TextDecoder("utf-8", { fatal: true, ignoreBOM: true }).decode(bytes);

function cases(seed: number, count: number): Uint8Array[] {
  const r = rand(seed);
  const out: Uint8Array[] = [];
  for (let k = 0; k < count; k++) {
    const valid = utf8(r.pick(space) + generate(r, 0) + r.pick(space));
    out.push(valid, mutate(r, valid));
  }
  for (const depth of [510, 511, 512, 513, 514]) {
    const deep = utf8(nest(r, depth));
    out.push(deep, mutate(r, deep));
  }
  return out;
}

const show = (bytes: Uint8Array): string =>
  JSON.stringify([...bytes].map((b) => b.toString(16)).join(" "));

describe("J.parse against an independent RFC 8259 reference", () => {
  for (const seed of [92, 4242, 20261024]) {
    test(`seed ${seed}: same verdict, error kind and value`, () => {
      let accepted = 0;
      const errors = { Syntax: 0, InvalidUtf8: 0, DepthLimit: 0 };
      for (const bytes of cases(seed, 1500)) {
        const want = reference(bytes);
        // The reference agrees with Bun's JSON.parse, made strict.
        expect(want.kind === "done", show(bytes)).toBe(strictAccepts(bytes));
        if (want.kind === "done") expect(JSON.parse(strictText(bytes))).toEqual(plain(want.value));
        expect(bendParse(bytes), show(bytes)).toEqual(want);
        if (want.kind === "done") accepted++;
        else errors[want.error]++;
      }
      // Acceptance and every error kind are well represented.
      expect(accepted).toBeGreaterThan(1000);
      expect(errors.Syntax).toBeGreaterThan(500);
      expect(errors.InvalidUtf8).toBeGreaterThan(20);
      expect(errors.DepthLimit).toBeGreaterThan(0);
    }, 60_000);
  }
});

// ---- the query specification against URLSearchParams ----

type Pairs =
  | { readonly kind: "done"; readonly pairs: readonly (readonly [string, string])[] }
  | {
      readonly kind: "fail";
      readonly error: string;
    };

function bendPairs(s: string): Pairs {
  const r = record(forms("parse_pairs", s));
  if (r.$ === "Done")
    return {
      kind: "done",
      pairs: items(r.value).map((e): readonly [string, string] => {
        const entry = record(e);
        return [text(entry.key), text(entry.value)];
      }),
    };
  return { kind: "fail", error: String(record(r.error).$) };
}

// Bendo refuses where the standard falls back: a "%" without two hex digits
// (kept literally by the standard) and octets that are not UTF-8 (replaced
// by U+FFFD). Without either, the two must agree exactly.
function strictQuery(s: string): Pairs {
  const hexdig = (c: number | undefined): boolean =>
    c !== undefined && /[0-9a-fA-F]/.test(String.fromCharCode(c));
  for (const piece of s.split("&").filter((p) => p !== "")) {
    const eq = piece.indexOf("=");
    for (const part of eq < 0 ? [piece] : [piece.slice(0, eq), piece.slice(eq + 1)]) {
      const bytes = utf8(part.replaceAll("+", " "));
      const out: number[] = [];
      for (let k = 0; k < bytes.length; k++) {
        const b = bytes[k] ?? 0;
        if (b !== 0x25) out.push(b);
        else if (!hexdig(bytes[k + 1]) || !hexdig(bytes[k + 2]))
          return { kind: "fail", error: "InvalidPercent" };
        else {
          out.push(parseInt(String.fromCharCode(bytes[k + 1] ?? 0, bytes[k + 2] ?? 0), 16));
          k += 2;
        }
      }
      try {
        new TextDecoder("utf-8", { fatal: true }).decode(Uint8Array.from(out));
      } catch {
        return { kind: "fail", error: "InvalidUtf8" };
      }
    }
  }
  return { kind: "done", pairs: [...new URLSearchParams(s)] };
}

describe("the raw query specification against URLSearchParams", () => {
  const pool = [
    ..."ab=&+%2B4Fz09 ",
    "%",
    "%41",
    "%2B",
    "%26",
    "%3D",
    "%C3%A9",
    "%e2%82%ac",
    "%FF",
    "%C3",
    "é",
    "😀",
    "%F0%9F%98%80",
    "%4",
    "%G1",
  ];
  for (const seed of [92, 2026]) {
    test(`seed ${seed}: same entries, or the documented refusal`, () => {
      const r = rand(seed);
      for (let k = 0; k < 3000; k++) {
        const s = Array.from({ length: r.int(10) }, () => r.pick(pool)).join("");
        expect(bendPairs(s), JSON.stringify(s)).toEqual(strictQuery(s));
      }
    }, 60_000);
  }
});
