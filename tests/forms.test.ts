import { compile } from "./harness.ts";
import { describe, expect, test } from "bun:test";
import { pathToFileURL } from "node:url";

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

const output = compile("tests/fixtures/forms/consumer.bend", "mjs");
const nativeOutput = compile("tests/fixtures/forms/native.bend", "native");
function native(...args: string[]): string {
  const result = Bun.spawnSync(["timeout", "--foreground", "30s", nativeOutput, ...args], {
    stdout: "pipe",
    stderr: "pipe",
  });
  expect(result.exitCode).toBe(0);
  // IO.print appends exactly one protocol newline; preserve payload whitespace.
  const text = result.stdout.toString();
  expect(text.endsWith("\n")).toBe(true);
  return text.slice(0, -1);
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
const encode = exported("encode");
const encodeForm = exported("encode_form");
const decode = exported("decode");
const decodeForm = exported("decode_form");
const parsePairs = exported("parse_pairs");
const parseBody = exported("parse_body");
const queries = exported("queries");
const query = exported("query");
const serialize = exported("serialize");
const utf8Encode = exported("utf8_encode");
const utf8Decode = exported("utf8_decode");
const done = (value: unknown) => ({ $: "Done", value });
const fail = (error: string) => ({ $: "Fail", error: { $: error } });
const entry = (key: string, value: string) => ({ $: "Entry", key, value });
function serializeResult(result: unknown): unknown {
  if (
    typeof result !== "object" ||
    result === null ||
    !("$" in result) ||
    result.$ !== "Done" ||
    !("value" in result)
  ) {
    throw new Error("Expected successful form parse");
  }
  return serialize(result.value);
}
const bytes = (text: string) => list([...new TextEncoder().encode(text)]);

describe("real compiled Bend URL-encoded components and forms", () => {
  const strings = [
    "",
    "a",
    "a b",
    "+",
    "%",
    "a&b=c;d",
    "!*'()~-._",
    "é",
    "日本語",
    "😀",
    "\0",
    "\u007f\u0080\u07ff\u0800\ud7ff\ue000\uffff\u{10000}\u{10ffff}",
  ];
  for (const s of strings) {
    test(`component round trips and WHATWG parity: ${JSON.stringify(s)}`, () => {
      const form = new URLSearchParams([["x", s]]).toString().slice(2);
      const component = encodeURIComponent(s).replace(
        /[!'()*]/g,
        (c) => `%${c.charCodeAt(0).toString(16).toUpperCase()}`,
      );
      expect(encodeForm(s)).toBe(form);
      expect(encode(s)).toBe(component);
      expect(decode(encode(s))).toEqual(done(s));
      expect(decodeForm(form)).toEqual(done(s));
      expect(utf8Encode(s)).toEqual(bytes(s));
      expect(utf8Decode(bytes(s))).toEqual({ $: "Some", value: s });
    });
  }

  for (const raw of [
    "",
    "&&",
    "a",
    "a=",
    "=b",
    "=",
    "a=1&a=2&z=x&a=3",
    "&&a&&b=&=c&&",
    "x=a=b=c",
    "a;b=c;d",
    "x=+&x=%2B",
    "a%26b=c%3Dd",
    "é=😀&é=日本語",
    "x=%e2%82%ac",
    "x=%00&x=%EF%BB%BF",
    "?a=b",
    "a=1&%61=2&A=3",
  ]) {
    test(`pair order, empty pieces, and URLSearchParams parity: ${JSON.stringify(raw)}`, () => {
      // URLSearchParams strips a leading '?' when given a string; our API
      // consumes the raw query after '?' and treats any subsequent '?' literally.
      const expected = [...new URLSearchParams(raw.startsWith("?") ? `x=${raw}` : raw)].map(
        ([k, v]) => entry(k, v),
      );
      if (raw.startsWith("?")) {
        expect(parsePairs(raw)).toEqual(done(list([entry("?a", "b")])));
      } else {
        expect(parsePairs(raw)).toEqual(done(list(expected)));
        expect(parseBody("application/x-www-form-urlencoded", bytes(raw))).toEqual(
          done(list(expected)),
        );
        expect(parsePairs(serialize(list(expected)))).toEqual(done(list(expected)));
      }
    });
  }

  test("query returns the first value; queries returns all values in arrival order", () => {
    const pairs = list([
      entry("x", "first"),
      entry("y", "other"),
      entry("x", ""),
      entry("x", "last"),
    ]);
    expect(queries(pairs, "x")).toEqual(list(["first", "", "last"]));
    expect(query(pairs, "x")).toEqual({ $: "Some", value: "first" });
    expect(queries(pairs, "X")).toEqual(list([]));
    expect(query(pairs, "missing")).toEqual({ $: "None" });
  });

  test("plus has distinct component and form meanings", () => {
    expect(decode("+%2B%20")).toEqual(done("++ "));
    expect(decodeForm("+%2B%20")).toEqual(done(" + "));
  });

  for (const raw of ["%", "%G1", "%1", "%1G", "%GG", "ok%20bad%", "%+1"]) {
    test(`rejects malformed percent escape ${raw}`, () => {
      expect(decode(raw)).toEqual(fail("InvalidPercent"));
      expect(decodeForm(raw)).toEqual(fail("InvalidPercent"));
      expect(parsePairs(`x=${raw}`)).toEqual(fail("InvalidPercent"));
      expect(parseBody("application/x-www-form-urlencoded", bytes(`x=${raw}`))).toEqual(
        fail("InvalidPercent"),
      );
    });
  }

  const invalidUtf8 = [
    [0x80],
    [0xc0, 0xaf],
    [0xc1, 0xbf],
    [0xc2],
    [0xc2, 0x20],
    [0xe2, 0x82],
    [0xe0, 0x80, 0x80],
    [0xed, 0xa0, 0x80],
    [0xf0, 0x80, 0x80, 0x80],
    [0xf4, 0x90, 0x80, 0x80],
    [0xf5, 0x80, 0x80, 0x80],
    [0xff],
    [256],
    [0xffffffff],
  ];
  for (const octets of invalidUtf8) {
    test(`rejects invalid UTF-8 ${octets.join(",")}`, () => {
      expect(utf8Decode(list(octets))).toEqual({ $: "None" });
      expect(parseBody("application/x-www-form-urlencoded", list([120, 61, ...octets]))).toEqual(
        fail("InvalidUtf8"),
      );
      if (octets.every((b) => b <= 255)) {
        const escaped = octets.map((b) => `%${b.toString(16).padStart(2, "0")}`).join("");
        expect(decode(escaped)).toEqual(fail("InvalidUtf8"));
        expect(decodeForm(escaped)).toEqual(fail("InvalidUtf8"));
      }
    });
  }

  test("body decoding combines raw and escaped UTF-8 octets before validation", () => {
    expect(
      parseBody("application/x-www-form-urlencoded", list([120, 61, 0xe2, 37, 56, 50, 37, 65, 67])),
    ).toEqual(done(list([entry("x", "€")])));
  });

  test("quoted parameter semicolons and escapes do not introduce charset declarations", () => {
    for (const ct of [
      'application/x-www-form-urlencoded; ignored="a;charset=latin1"; charset=utf-8',
      'application/x-www-form-urlencoded; ignored="a;\\\";charset=latin1"; charset=utf-8',
      'application/x-www-form-urlencoded; charset="utf\\-8"',
    ])
      expect(parseBody(ct, bytes("x=1"))).toEqual(done(list([entry("x", "1")])));
  });

  test("content type matching and UTF-8 charset policy", () => {
    for (const ct of [
      "application/x-www-form-urlencoded",
      " Application/X-WWW-Form-Urlencoded ; Charset = UTF-8 ",
      'application/x-www-form-urlencoded; charset="UTF-8"',
      "application/x-www-form-urlencoded; ignored=yes; charset=utf-8; charset=UTF-8",
    ])
      expect(parseBody(ct, bytes("x=%C3%A9"))).toEqual(done(list([entry("x", "é")])));
    for (const suffix of [
      "charset=latin1",
      "charset",
      "charset=",
      "charset=utf-8; charset=ascii",
    ]) {
      expect(parseBody(`application/x-www-form-urlencoded; ${suffix}`, bytes("x=1"))).toEqual(
        fail("UnsupportedCharset"),
      );
    }
    for (const ct of [
      "",
      "text/plain",
      "application/json",
      "application/x-www-form-urlencoded-x",
    ]) {
      expect(parseBody(ct, bytes("x=1"))).toEqual(fail("UnsupportedMediaType"));
    }
  });

  test("64 KiB Content-Type parameters stay within the JavaScript stack", () => {
    const long = "a".repeat(65536);
    for (const suffix of [`ignored=${long}`, `${long}=ignored`, `ignored="${long}"`]) {
      expect(parseBody(`application/x-www-form-urlencoded; ${suffix}`, bytes("x=1"))).toEqual(
        done(list([entry("x", "1")])),
      );
    }
    for (const value of [long, `"${long}"`]) {
      expect(
        parseBody(`application/x-www-form-urlencoded; charset=${value}`, bytes("x=1")),
      ).toEqual(fail("UnsupportedCharset"));
    }
    expect(
      parseBody(`application/x-www-form-urlencoded${";x".repeat(32768)}`, bytes("x=1")),
    ).toEqual(done(list([entry("x", "1")])));
    expect(parseBody(long, bytes("x=1"))).toEqual(fail("UnsupportedMediaType"));
  });

  test("native decoding handles 64 KiB Content-Type parameters and charsets", () => {
    const long = "a".repeat(65536);
    for (const suffix of [`ignored=${long}`, `${long}=ignored`, `ignored="${long}"`]) {
      expect(native("body", `application/x-www-form-urlencoded; ${suffix}`, "x=1")).toBe("x=1");
    }
    for (const value of [long, `"${long}"`]) {
      expect(native("body", `application/x-www-form-urlencoded; charset=${value}`, "x=1")).toBe(
        "unsupported-charset",
      );
    }
    expect(native("body", `application/x-www-form-urlencoded${";x".repeat(32768)}`, "x=1")).toBe(
      "x=1",
    );
    expect(native("body", long, "x=1")).toBe("unsupported-media-type");
  });

  test("native components, UTF-8, and bodies handle 64 KiB inputs", () => {
    const value = "a".repeat(65536);
    for (const text of [value, "é +&".repeat(16384)]) {
      expect(native("component", text)).toBe(text);
      expect(native("form", text)).toBe(text);
      expect(native("utf8", text)).toBe(text);
    }
    expect(native("body", "application/x-www-form-urlencoded", `x=${value}`)).toBe(`x=${value}`);
    expect(native("pairs", `${value}=v`)).toBe(`${value}=v`);
    const repeated = Array.from({ length: 16384 }, (_, i) => `x=${i % 10}`).join("&");
    expect(native("pairs", repeated)).toBe(repeated);
    expect(native("body", "application/x-www-form-urlencoded", repeated)).toBe(repeated);
  });

  test("64 KiB components and form bodies stay within the JavaScript stack", () => {
    const value = "a".repeat(65536);
    for (const text of [value, "é +&".repeat(16384)]) {
      const escaped = new URLSearchParams([["", text]]).toString().slice(1);
      expect(encodeForm(text)).toBe(escaped);
      expect(decodeForm(escaped)).toEqual(done(text));
      expect(decode(encode(text))).toEqual(done(text));
      expect(utf8Decode(utf8Encode(text))).toEqual({ $: "Some", value: text });
    }
    expect(parseBody("application/x-www-form-urlencoded", bytes(`x=${value}`))).toEqual(
      done(list([entry("x", value)])),
    );
    expect(parsePairs(`${value}=v`)).toEqual(done(list([entry(value, "v")])));
    expect(serialize(list([entry("x", value)]))).toBe(`x=${value}`);
  });

  test("64 KiB repeated pairs preserve lookup and serialization order", () => {
    const count = 16384;
    const text = Array.from({ length: count }, (_, i) => `x=${i % 10}`).join("&");
    const pairs = list(Array.from({ length: count }, (_, i) => entry("x", String(i % 10))));
    expect(serialize(pairs)).toBe(text);
    expect(query(pairs, "x")).toEqual({ $: "Some", value: "0" });
    // Serialize the result so the assertion framework does not recurse through
    // the deeply nested Bend list while reporting a mismatch.
    const parsed = parsePairs(text);
    expect(serializeResult(parsed)).toBe(text);
    expect(serializeResult(parseBody("application/x-www-form-urlencoded", bytes(text)))).toBe(text);
    const selected = queries(pairs, "x");
    let cursor: unknown = selected;
    let seen = 0;
    while (typeof cursor === "object" && cursor !== null && "head" in cursor && "tail" in cursor) {
      expect(cursor.head).toBe(String(seen % 10));
      cursor = cursor.tail;
      seen++;
    }
    expect(seen).toBe(count);
    expect(cursor).toEqual({ $: "Nil" });
  });

  test("deterministic Unicode samples agree with JS encoders", () => {
    for (let i = 0; i < 128; i++) {
      const cp = (i * 7919) % 0x110000;
      if (cp >= 0xd800 && cp <= 0xdfff) continue;
      const s = `key ${String.fromCodePoint(cp)}+é`;
      expect(encodeForm(s)).toBe(new URLSearchParams([["", s]]).toString().slice(1));
      expect(decodeForm(encodeForm(s))).toEqual(done(s));
      expect(decode(encode(s))).toEqual(done(s));
    }
  });
});
