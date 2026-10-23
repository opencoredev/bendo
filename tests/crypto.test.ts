import { afterAll, describe, expect, test } from "bun:test";
import { createHash, createHmac } from "node:crypto";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { findBend } from "../packages/bendo/src/bend.ts";
import hashes from "./fixtures/crypto/hash-vectors.json";
import macs from "./fixtures/crypto/hmac-vectors.json";

type List = { $: "Nil" } | { $: "Con"; head: number; tail: List };
function list(bytes: Uint8Array): List {
  let tail: List = { $: "Nil" };
  for (let i = bytes.length - 1; i >= 0; i--) {
    const head = bytes[i];
    if (head === undefined) throw new Error("Missing byte");
    tail = { $: "Con", head, tail };
  }
  return tail;
}
const dir = mkdtempSync(join(tmpdir(), "bendo-crypto-"));
afterAll(() => rmSync(dir, { recursive: true, force: true }));
const bend = findBend();
if (bend.kind === "missing") throw new Error("bend is not installed");
function command(args: string[], env = process.env): string {
  const result = Bun.spawnSync(["timeout", "--foreground", "30s", ...args], {
    env,
    stdout: "pipe",
    stderr: "pipe",
  });
  if (result.exitCode !== 0) throw new Error(`${args[0]} failed: ${result.stdout}${result.stderr}`);
  return result.stdout.toString();
}
const entry = join(import.meta.dir, "fixtures/crypto");
const modulePath = join(dir, "crypto.mjs");
const nativePath = join(dir, "crypto-native");
command([bend.path, join(entry, "consumer.bend"), "-o", modulePath]);
command([bend.path, join(entry, "native.bend"), "-o", nativePath]);
const loaded: unknown = await import(pathToFileURL(modulePath).href);
if (typeof loaded !== "object" || loaded === null || !("default" in loaded)) {
  throw new Error("Missing Bend module");
}
const exports: unknown = loaded.default;
function exported(name: string): (...args: unknown[]) => unknown {
  if (typeof exports !== "object" || exports === null || !(name in exports)) {
    throw new Error(`Missing export ${name}`);
  }
  const fn: unknown = Reflect.get(exports, name);
  if (typeof fn !== "function") throw new Error(`Not callable: ${name}`);
  return (...args) => fn(...args);
}
const sha1 = exported("sha1");
const sha256 = exported("sha256");
const hmac = exported("hmac");
const hex = exported("hex");
const unhex = exported("unhex");
const base64 = exported("base64");
const unbase64 = exported("unbase64");
const ctEqual = exported("ct_equal");
const utf8 = exported("utf8");
const yes = true;
const no = false;
const some = (value: List) => ({ $: "Some", value });
const none = { $: "None" };

describe("BND-42 crypto", () => {
  for (const vector of hashes) {
    test(`FIPS 180-4 ${vector.name}, native and mjs`, () => {
      const input = Buffer.from(vector.message.repeat(vector.repeat));
      expect(sha1(list(input))).toBe(vector.sha1);
      expect(sha256(list(input))).toBe(vector.sha256);
      if (vector.repeat === 1) {
        expect(command([nativePath, "sha1", input.toString("hex")]).trim()).toBe(vector.sha1);
        expect(command([nativePath, "sha256", input.toString("hex")]).trim()).toBe(vector.sha256);
      } else {
        expect(command([nativePath, "million"]).trim().split("\n")).toEqual([
          vector.sha1,
          vector.sha256,
        ]);
      }
    });
  }
  for (const algorithm of ["SHA1", "SHA256"]) {
    for (const size of ["ShortMsg", "LongMsg"]) {
      test(`NIST CAVP ${algorithm}${size}, every byte-oriented vector`, () => {
        const text = readFileSync(join(entry, `${algorithm}${size}.rsp`), "utf8");
        let count = 0;
        for (const match of text.matchAll(/Len = (\d+)\s+Msg = ([0-9a-f]+)\s+MD = ([0-9a-f]+)/g)) {
          const [, bits, message, digest] = match;
          if (bits === undefined || message === undefined || digest === undefined)
            throw new Error("Malformed CAVP vector");
          const input = Number(bits) === 0 ? Buffer.alloc(0) : Buffer.from(message, "hex");
          expect(input.length * 8).toBe(Number(bits));
          expect((algorithm === "SHA1" ? sha1 : sha256)(list(input))).toBe(digest);
          expect(command([nativePath, algorithm.toLowerCase(), input.toString("hex")]).trim()).toBe(
            digest,
          );
          count++;
        }
        expect(count).toBe(size === "LongMsg" ? 64 : 65);
      });
    }
  }
  for (const vector of macs) {
    test(`RFC 4231 case ${vector.case}, native and mjs`, () => {
      const key = Buffer.from(vector.key, "hex");
      const message = Buffer.from(vector.message, "hex");
      const tag = hmac(list(key), list(message));
      expect(typeof tag).toBe("string");
      if (typeof tag !== "string") throw new Error("Non-string tag");
      expect(tag.slice(0, vector.expected.length)).toBe(vector.expected);
      expect(
        command([nativePath, "hmac", vector.key, vector.message])
          .trim()
          .slice(0, vector.expected.length),
      ).toBe(vector.expected);
    });
  }
  test("RFC 4648 section 10 and hex vectors", () => {
    const vectors = [
      ["", ""],
      ["f", "Zg=="],
      ["fo", "Zm8="],
      ["foo", "Zm9v"],
      ["foob", "Zm9vYg=="],
      ["fooba", "Zm9vYmE="],
      ["foobar", "Zm9vYmFy"],
    ];
    for (const [plain, encoded] of vectors) {
      if (plain === undefined || encoded === undefined) throw new Error("Bad vector");
      const bytes = Buffer.from(plain);
      expect(hex(list(bytes))).toBe(bytes.toString("hex"));
      expect(unhex(bytes.toString("hex"))).toEqual(some(list(bytes)));
      for (const url of [no, yes]) {
        expect(base64(list(bytes), url, yes)).toBe(encoded);
        expect(unbase64(encoded, url, yes)).toEqual(some(list(bytes)));
        expect(base64(list(bytes), url, no)).toBe(encoded.replace(/=+$/, ""));
        expect(unbase64(encoded.replace(/=+$/, ""), url, no)).toEqual(some(list(bytes)));
      }
    }
    const all = Buffer.from(Array.from({ length: 256 }, (_, i) => i));
    expect(hex(list(all))).toBe(all.toString("hex"));
    expect(unhex(all.toString("hex").toUpperCase())).toEqual(some(list(all)));
  });
  test("strict decoders reject malformed and noncanonical encodings", () => {
    for (const s of ["a", "0x00", "gg", "00 ", "０0", "\n00"]) expect(unhex(s)).toEqual(none);
    for (const url of [no, yes]) {
      for (const s of [
        "A",
        "A===",
        "=AAA",
        "AA=A",
        "AA==AAAA",
        "AA===",
        "AB==",
        "AAB=",
        "Z g==",
        "Zg==\n",
      ]) {
        expect(unbase64(s, url, yes)).toEqual(none);
      }
      for (const s of ["A", "AB", "AAB", "Zg==", "AA=", "AA\n"])
        expect(unbase64(s, url, no)).toEqual(none);
      expect(unbase64("Zg", url, yes)).toEqual(none);
      expect(unbase64("Zm8", url, yes)).toEqual(none);
    }
    expect(unbase64("-_8=", no, yes)).toEqual(none);
    expect(unbase64("+/8=", yes, yes)).toEqual(none);
  });
  test("seeded differential octet inputs agree with Bun crypto and encoders", () => {
    let seed = 0x42be0d;
    const next = () => {
      seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
      return seed >>> 24;
    };
    for (const length of [
      0,
      1,
      2,
      3,
      4,
      55,
      56,
      57,
      63,
      64,
      65,
      111,
      112,
      127,
      128,
      129,
      ...Array.from({ length: 48 }, (_, i) => i * 13),
    ]) {
      const bytes = Buffer.from(Array.from({ length }, next));
      const key = Buffer.from(Array.from({ length: length % 160 }, next));
      const xs = list(bytes);
      expect(sha1(xs)).toBe(createHash("sha1").update(bytes).digest("hex"));
      expect(sha256(xs)).toBe(createHash("sha256").update(bytes).digest("hex"));
      expect(hmac(list(key), xs)).toBe(createHmac("sha256", key).update(bytes).digest("hex"));
      expect(hex(xs)).toBe(bytes.toString("hex"));
      expect(unhex(bytes.toString("hex"))).toEqual(some(xs));
      for (const [url, format] of [
        [no, "base64"],
        [yes, "base64url"],
      ] satisfies [boolean, "base64" | "base64url"][]) {
        const raw = bytes.toString(format).replace(/=+$/, "");
        const padded = raw + "=".repeat((4 - (raw.length % 4)) % 4);
        expect(base64(xs, url, no)).toBe(raw);
        expect(base64(xs, url, yes)).toBe(padded);
        expect(unbase64(raw, url, no)).toEqual(some(xs));
        expect(unbase64(padded, url, yes)).toEqual(some(xs));
      }
    }
  });
  test("UTF-8 helper supplies octets for hashing", () => {
    const text = "Bendo € 😀";
    expect(sha256(utf8(text))).toBe(createHash("sha256").update(text).digest("hex"));
  });
  test("best-effort comparison includes length and every byte", () => {
    for (const [a, b, same] of [
      [[], [], true],
      [[0], [], false],
      [[], [0], false],
      [[1, 2], [1, 2], true],
      [[1, 2], [1, 3], false],
      [[1, 2], [0, 2], false],
    ] satisfies [number[], number[], boolean][]) {
      expect(ctEqual(list(Uint8Array.from(a)), list(Uint8Array.from(b)))).toEqual(same ? yes : no);
    }
  });
  test("native secure randomness returns the requested length and distinct outputs", () => {
    const [empty, a, b] = command([nativePath, "random"]).split("\n");
    expect(empty).toBe("");
    expect(a).toMatch(/^[0-9a-f]{64}$/);
    expect(b).toMatch(/^[0-9a-f]{64}$/);
    expect(a).not.toBe(b);
  });
  test("native entropy failures propagate unchanged without fallback", () => {
    const library = join(dir, "entropy-fail.so");
    command(["cc", "-shared", "-fPIC", join(entry, "entropy-fail.c"), "-o", library]);
    const [empty, a, b] = command([nativePath, "random"], {
      ...process.env,
      LD_PRELOAD: library,
    }).split("\n");
    expect(empty).toBe("");
    expect(a).toBe("error:5:Input/output error");
    expect(b).toBe(a);
  });
});
