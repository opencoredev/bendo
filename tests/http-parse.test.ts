import { BEND_COMPILE_TIMEOUT } from "./harness.ts";
import { afterAll, describe, expect, test } from "bun:test";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { findBend } from "../packages/bendo/src/bend.ts";
import valid from "./fixtures/http-parse/valid.json";
import invalid from "./fixtures/http-parse/invalid.json";

type BendList<T> = { $: "Nil" } | { $: "Con"; head: T; tail: BendList<T> };

function list<T>(values: readonly T[]): BendList<T> {
  let result: BendList<T> = { $: "Nil" };
  for (let i = values.length - 1; i >= 0; i--) {
    const value = values[i];
    if (value === undefined) throw new Error("Missing fixture element");
    result = { $: "Con", head: value, tail: result };
  }
  return result;
}

// Fixtures are Latin-1 wire strings, not UTF-8 decoded network payloads.
// U+0100 deliberately represents an invalid U32 element in two fixtures.
function octets(raw: string): BendList<number> {
  return list(Array.from(raw, (c) => c.charCodeAt(0)));
}

const standardMethods: Readonly<Record<string, string>> = {
  GET: "Get",
  HEAD: "Head",
  POST: "Post",
  PUT: "Put",
  DELETE: "Delete",
  CONNECT: "Connect",
  OPTIONS: "Options",
  TRACE: "Trace",
  PATCH: "Patch",
};

function expectedRequest(fixture: (typeof valid)[number]["expected"]) {
  const tag = standardMethods[fixture.method];
  return {
    $: "Req",
    method: tag === undefined ? { $: "Extension", token: fixture.method } : { $: tag },
    path: fixture.path,
    query: fixture.query === null ? { $: "None" } : { $: "Some", value: fixture.query },
    version: { $: fixture.version === "1.0" ? "Http10" : "Http11" },
    headers: list(
      fixture.headers.map((h) => ({ $: "Header", name: h.name, value: octets(h.value) })),
    ),
  };
}

const directory = mkdtempSync(join(tmpdir(), "bendo-http-parse-"));
afterAll(() => rmSync(directory, { recursive: true, force: true }));
const output = join(directory, "parser.mjs");
const bend = findBend();
if (bend.kind === "missing") throw new Error("bend is not installed");
const compilation = Bun.spawnSync(
  [
    "timeout",
    "--foreground",
    BEND_COMPILE_TIMEOUT,
    bend.path,
    join(import.meta.dir, "fixtures/http-parse/consumer.bend"),
    "-o",
    output,
  ],
  { stdout: "pipe", stderr: "pipe" },
);
if (compilation.exitCode !== 0) {
  throw new Error(`Bend parser compilation failed:\n${compilation.stdout}${compilation.stderr}`);
}

// The generated module has no TS declarations. Validate exports at this
// boundary and compare results with independent constructor-shaped literals.
const module: unknown = await import(pathToFileURL(output).href);
if (typeof module !== "object" || module === null || !("default" in module)) {
  throw new Error("Missing compiled Bend default export");
}
const exports: unknown = module.default;
function exported(name: string): (...args: unknown[]) => unknown {
  if (typeof exports !== "object" || exports === null || !(name in exports)) {
    throw new Error(`Missing Bend export: ${name}`);
  }
  const fn: unknown = Reflect.get(exports, name);
  if (typeof fn !== "function") throw new Error(`Bend export is not callable: ${name}`);
  return (...args) => fn(...args);
}
const parse = exported("parse");
const write = exported("write");
const lookup = exported("lookup");
const wellFormed = exported("well_formed");
const initial = exported("initial");
const feed = exported("feed");

function pair(value: unknown): { fst: unknown; snd: unknown } {
  if (typeof value === "object" && value !== null && "fst" in value && "snd" in value) {
    return { fst: value.fst, snd: value.snd };
  }
  throw new Error("Expected a Bend pair");
}

describe("real compiled Bend HTTP request parser", () => {
  test("fixture coverage includes at least 30 valid and 30 invalid requests", () => {
    expect(valid.length).toBeGreaterThanOrEqual(30);
    expect(invalid.length).toBeGreaterThanOrEqual(30);
  });

  for (const fixture of valid) {
    test(fixture.name, () => {
      const req = expectedRequest(fixture.expected);
      expect(parse(octets(fixture.raw))).toEqual({
        $: "Parsed",
        req,
        rest: octets(fixture.expected.rest),
      });
      expect(wellFormed(req)).toBe(true);
      expect(parse(write(req))).toEqual({ $: "Parsed", req, rest: { $: "Nil" } });
      for (const h of fixture.expected.headers) {
        const values = list(
          fixture.expected.headers.filter((x) => x.name === h.name).map((x) => octets(x.value)),
        );
        expect(lookup(req.headers, h.name.toUpperCase())).toEqual(values);
        expect(lookup(req.headers, h.name)).toEqual(values);
      }
    });
  }

  for (const fixture of invalid) {
    test(`rejects ${fixture.name}`, () => {
      expect(parse(octets(fixture.raw))).toEqual({ $: "Rejected", error: { $: fixture.error } });
    });
  }

  test("every ASCII case variant keeps repeated values in arrival order", () => {
    const hs = list([
      { $: "Header", name: "x-tag", value: octets("first") },
      { $: "Header", name: "other", value: octets("middle") },
      { $: "Header", name: "x-tag", value: octets("last") },
    ]);
    const expected = list([octets("first"), octets("last")]);
    let variants = [""];
    for (const char of "x-tag") {
      variants = variants.flatMap((prefix) =>
        char === "-" ? [prefix + char] : [prefix + char, prefix + char.toUpperCase()],
      );
    }
    for (const name of variants) expect(lookup(hs, name)).toEqual(expected);
    expect(lookup(hs, "absent")).toEqual({ $: "Nil" });
  });

  for (const fixture of valid.filter((f) => f.name.endsWith("leading CRLF"))) {
    test(`${fixture.name} across every split and one-byte reads`, () => {
      const expected = {
        $: "Parsed",
        req: expectedRequest(fixture.expected),
        rest: octets(fixture.expected.rest),
      };
      for (let split = 0; split < fixture.raw.length; split++) {
        const first = pair(feed(octets(fixture.raw.slice(0, split)), initial()));
        expect(first.snd).toEqual({ $: "NeedMore" });
        expect(pair(feed(octets(fixture.raw.slice(split)), first.fst)).snd).toEqual(expected);
      }
      let state = initial();
      let result: unknown;
      for (const c of fixture.raw) {
        const step = pair(feed(octets(c), state));
        state = step.fst;
        result = step.snd;
      }
      expect(result).toEqual(expected);
    });
  }

  test("incomplete prefixes return NeedMore, including a trailing CR", () => {
    for (const raw of [
      "",
      "G",
      "\r",
      "\r\n",
      "\r\n\r",
      "\r\n\r\n",
      "GET / HTTP/1.1\r",
      "GET / HTTP/1.1\r\n",
      "GET / HTTP/1.1\r\nX: a",
      "GET / HTTP/1.1\r\n\r",
    ]) {
      expect(parse(octets(raw))).toEqual({ $: "NeedMore" });
    }
  });

  test("malformed completed lines fail before the end of the header block", () => {
    expect(parse(octets("GET / HTTP/2.0\r\n"))).toEqual({
      $: "Rejected",
      error: { $: "InvalidVersion" },
    });
    expect(parse(octets("GET / HTTP/1.1\r\nBad\r\n"))).toEqual({
      $: "Rejected",
      error: { $: "InvalidHeaderName" },
    });
  });

  test("retained scanner state accepts every split and one-byte reads", () => {
    const raw = "POST /a?x?? HTTP/1.1\r\nX-Tag:\t first \t\r\nx-TAG: second\r\n\r\n";
    const expected = parse(octets(raw));
    for (let split = 0; split < raw.length; split++) {
      const first = pair(feed(octets(raw.slice(0, split)), initial()));
      expect(first.snd).toEqual({ $: "NeedMore" });
      expect(pair(feed(octets(raw.slice(split)), first.fst)).snd).toEqual(expected);
    }
    let state = initial();
    let result: unknown;
    for (const c of raw) {
      const step = pair(feed(octets(c), state));
      state = step.fst;
      result = step.snd;
    }
    expect(result).toEqual(expected);
  });
});
