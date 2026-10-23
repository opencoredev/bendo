import { describe, expect, test } from "bun:test";
import { createHmac } from "node:crypto";
import { pathToFileURL } from "node:url";
import { build, compile, start, SLOW_TEST_TIMEOUT_MS } from "./harness.ts";

const binary = build("tests/servers/cookies-signed.bend");
const output = compile("tests/fixtures/cookies/signed-consumer.bend", "mjs");
const module: unknown = await import(pathToFileURL(output).href);
if (typeof module !== "object" || module === null || !("default" in module)) {
  throw new Error("Missing signed-cookie exports");
}
const exports: unknown = module.default;
function exported(name: string): (...args: unknown[]) => unknown {
  if (typeof exports !== "object" || exports === null || !(name in exports)) {
    throw new Error(`Missing signed-cookie export ${name}`);
  }
  const fn: unknown = Reflect.get(exports, name);
  if (typeof fn !== "function") throw new Error(`Not callable: ${name}`);
  return (...args) => fn(...args);
}
const sign = exported("sign");
const verify = exported("verify");
const configure = exported("configure");
const serialize = exported("serialize");
function list(values: string[]): unknown {
  return values.reduceRight<unknown>((tail, head) => ({ $: "Con", head, tail }), { $: "Nil" });
}
const keys = { $: "Keys", first: "new-secret", rest: list(["old-secret"]) };
const some = (value: unknown) => ({ $: "Some", value });
const none = { $: "None" };
// Hono utils/cookie.ts: HMAC over the original UTF-8 value, padded standard
// base64, last-dot separation, then encodeURIComponent of the whole payload.
function honoWire(key: string, value: string): string {
  return encodeURIComponent(`${value}.${createHmac("sha256", key).update(value).digest("base64")}`);
}
function honoVerify(key: string, wire: string): string | undefined {
  const decoded = decodeURIComponent(wire);
  const dot = decoded.lastIndexOf(".");
  if (dot < 0) return undefined;
  const value = decoded.slice(0, dot);
  return decoded.slice(dot + 1) === createHmac("sha256", key).update(value).digest("base64")
    ? value
    : undefined;
}
const values = ["", "hello", "a.b..", "%2E", "%", "+", "raw%20+", "a=b", "!\"'()*;,\\\r\n", "café 🍪"];

describe("signed cookies on both compiled targets", () => {
  test("rejects empty key configuration and invalid Unicode scalar secrets/values", () => {
    expect(configure(list([]))).toEqual(none);
    expect(configure(list(["new-secret", "old-secret"]))).toEqual(some(keys));
    expect(configure(list(["\ud800"]))).toEqual(none);
    expect(configure(list(["new-secret", "\udfff"]))).toEqual(none);
    expect(serialize("session", "\ud800", keys)).toEqual({
      $: "Fail", error: { $: "InvalidValue" },
    });
    expect(serialize("bad;name", "ok", keys)).toEqual({
      $: "Fail", error: { $: "InvalidName" },
    });
  });

  test("roundtrips values, interoperates with Hono's exact algorithm and signs with first key", async () => {
    await using server = await start(binary);
    for (const value of values) {
      const wire = sign("new-secret", value);
      expect(typeof wire).toBe("string");
      if (typeof wire !== "string") throw new Error("Invalid signature wire");
      expect(honoVerify("new-secret", wire)).toBe(value);
      expect(verify(keys, honoWire("new-secret", value))).toEqual(some(value));
      expect(verify(keys, wire)).toEqual(some(value));
      const response = await fetch(`${server.url}/?value=${encodeURIComponent(value)}`);
      expect(response.status).toBe(201);
      expect(response.headers.get("x-kept")).toBe("yes");
      const cookies = response.headers.getSetCookie();
      expect(cookies).toHaveLength(2);
      const pair = cookies[0]?.split(";")[0];
      if (!pair?.startsWith("session=")) throw new Error("Missing session cookie");
      expect(honoVerify("new-secret", pair.slice(8))).toBe(value);
      expect(cookies[0]).toEndWith("; Path=/; Secure; HttpOnly; SameSite=Lax");
      expect(honoVerify("old-secret", pair.slice(8))).toBeUndefined();
      const read = await fetch(`${server.url}/read`, { headers: { Cookie: pair } });
      expect(await read.text()).toBe(value);
    }
  }, SLOW_TEST_TIMEOUT_MS);

  test("accepts an old key anywhere in the list, rejects removed keys and tampering", async () => {
    await using server = await start(binary);
    const old = honoWire("old-secret", "a.b%2E+");
    expect(verify(keys, old)).toEqual(some("a.b%2E+"));
    expect(verify({ $: "Keys", first: "old-secret", rest: list(["new-secret"]) }, old)).toEqual(some("a.b%2E+"));
    expect(verify({ $: "Keys", first: "new-secret", rest: list([]) }, old)).toEqual(none);
    const raw = decodeURIComponent(old);
    const dot = raw.lastIndexOf(".");
    const badWires = [
      honoWire("unknown-secret", "a.b%2E+"),
      encodeURIComponent(`tampered${raw.slice(dot)}`),
      encodeURIComponent(`${raw.slice(0, dot + 1)}AAAA${raw.slice(dot + 5)}`),
      "unsigned", "", "%ZZ", "%FF", "a.", "a.AA==", "a.A===", "a.AA-_", old + "%3D",
    ];
    for (const wire of [old, ...badWires]) {
      const expected = wire === old ? "a.b%2E+" : "absent-or-invalid";
      expect(verify(keys, wire)).toEqual(wire === old ? some(expected) : none);
      const response = await fetch(`${server.url}/read`, { headers: { Cookie: `session=${wire}` } });
      expect(await response.text()).toBe(expected);
    }
    expect(await (await fetch(`${server.url}/read`)).text()).toBe("absent-or-invalid");
    // The first cookie wins even when it is invalid; never search duplicates for a valid signature.
    expect(await (await fetch(`${server.url}/read`, {
      headers: { Cookie: `session=bad; session=${old}` },
    })).text()).toBe("absent-or-invalid");
  }, SLOW_TEST_TIMEOUT_MS);
});
