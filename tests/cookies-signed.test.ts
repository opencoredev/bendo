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
const uncheckedSign = exported("unchecked_sign");
const sign = exported("sign");
const verify = exported("verify");
const read = exported("read");
const verifyDigest = exported("verify_digest");
const invalidSign = exported("invalid_sign");
const surrogateKeys = exported("surrogate_keys");
const configure = exported("configure");
const serialize = exported("serialize");
const invalidValue = exported("invalid_value");
function list(values: readonly (string | number)[]): unknown {
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
const values = [
  "",
  "hello",
  "a.b..",
  "%2E",
  "%",
  "+",
  "raw%20+",
  "a=b",
  "!\"'()*;,\\\r\n",
  "café 🍪",
];

describe("signed cookies on both compiled targets", () => {
  test(
    "handles long scalar values and UTF-8 or long rotation secrets",
    () => {
      const long = "x".repeat(32_000);
      for (const secret of ["clé 🍪", "k".repeat(131)]) {
        const rotation = { $: "Keys", first: secret, rest: list(["other"]) };
        expect(configure(list([secret]))).toEqual(
          some({ $: "Keys", first: secret, rest: list([]) }),
        );
        const result = serialize("session", long, rotation);
        if (
          typeof result !== "object" ||
          result === null ||
          !("value" in result) ||
          typeof result.value !== "string"
        ) {
          throw new Error("Missing serialized long cookie");
        }
        const wire = result.value.slice("session=".length);
        expect(honoVerify(secret, wire)).toBe(long);
        expect(verify(rotation, wire)).toEqual(some(long));
      }
    },
    SLOW_TEST_TIMEOUT_MS,
  );

  test("rejects empty key configuration and invalid Unicode scalar secrets/values", () => {
    expect(configure(list([]))).toEqual(none);
    expect(configure(list(["new-secret", "old-secret"]))).toEqual(some(keys));
    expect(configure(list(["\ud800"]))).toEqual(none);
    expect(configure(list(["new-secret", "\udfff"]))).toEqual(none);
    expect(invalidValue(keys)).toEqual({
      $: "Fail",
      error: { $: "InvalidValue" },
    });
    expect(invalidSign(keys)).toEqual(none);
    expect(serialize("bad;name", "ok", keys)).toEqual({
      $: "Fail",
      error: { $: "InvalidName" },
    });
  });

  test("rejects an empty secret in any rotation slot", () => {
    // Anyone can compute HMAC under the empty key, so it must never be configured.
    expect(configure(list([""]))).toEqual(none);
    expect(configure(list(["", "strong-current-secret"]))).toEqual(none);
    expect(configure(list(["strong-current-secret", ""]))).toEqual(none);
    expect(configure(list(["strong-current-secret", "previous", ""]))).toEqual(none);
    expect(configure(list(["strong-current-secret", "", "previous"]))).toEqual(none);
    const forged = honoWire("", "role=admin");
    const strong = configure(list(["strong-current-secret", "previous"]));
    if (typeof strong !== "object" || strong === null || !("value" in strong)) {
      throw new Error("Expected strong keys to configure");
    }
    expect(verify(strong.value, forged)).toEqual(none);
  });

  test("rejects directly built keys with an unusable slot at every entry point", () => {
    // Keys{...} is public, so configure can be bypassed. An empty secret lets
    // anyone forge, so the whole key set must accept and sign nothing.
    const value = "role=admin";
    const forged = honoWire("", value);
    const genuine = honoWire("strong-current-secret", value);
    const digest = (key: string) => list([...createHmac("sha256", key).update(value).digest()]);
    const unusable = [
      { $: "Keys", first: "", rest: list(["strong-current-secret"]) },
      { $: "Keys", first: "", rest: list([]) },
      { $: "Keys", first: "strong-current-secret", rest: list([""]) },
      { $: "Keys", first: "strong-current-secret", rest: list(["", "previous"]) },
      { $: "Keys", first: "strong-current-secret", rest: list(["previous", ""]) },
      surrogateKeys(true),
      surrogateKeys(false),
    ];
    for (const bad of unusable) {
      for (const wire of [forged, genuine]) {
        expect(verify(bad, wire)).toEqual(none);
        expect(read(bad, some(wire))).toEqual(none);
      }
      expect(read(bad, none)).toEqual(none);
      expect(verifyDigest(bad, value, digest(""))).toEqual(none);
      expect(verifyDigest(bad, value, digest("strong-current-secret"))).toEqual(none);
      expect(sign(bad, value)).toEqual(none);
      expect(invalidSign(bad)).toEqual(none);
      expect(serialize("session", value, bad)).toEqual({
        $: "Fail",
        error: { $: "InvalidSecret" },
      });
      expect(invalidValue(bad)).toEqual({ $: "Fail", error: { $: "InvalidValue" } });
    }
    // The same slots built through configure verify normally.
    const good = { $: "Keys", first: "strong-current-secret", rest: list(["previous"]) };
    expect(verify(good, genuine)).toEqual(some(value));
    expect(verifyDigest(good, value, digest("previous"))).toEqual(some(value));
    expect(verifyDigest(good, value, digest(""))).toEqual(none);
  });

  test(
    "Context helpers reject directly built keys with an empty slot",
    async () => {
      await using server = await start(binary);
      const genuine = uncheckedSign("new-secret", "role=admin");
      if (typeof genuine !== "string") throw new Error("Invalid signature wire");
      const forged = honoWire("", "role=admin");
      for (const slot of [0, 1, 2]) {
        for (const wire of [forged, genuine]) {
          const response = await fetch(`${server.url}/bad/${slot}/read`, {
            headers: { Cookie: `session=${wire}` },
          });
          expect(await response.text()).toBe("absent-or-invalid");
        }
        const write = await fetch(`${server.url}/bad/${slot}/write`);
        expect(write.status).toBe(500);
        expect(await write.text()).toBe("invalid-secret");
        expect(write.headers.getSetCookie()).toEqual([]);
      }
      // The well-configured route still reads the genuine cookie.
      const good = await fetch(`${server.url}/read`, { headers: { Cookie: `session=${genuine}` } });
      expect(await good.text()).toBe("role=admin");
    },
    SLOW_TEST_TIMEOUT_MS,
  );

  test(
    "roundtrips values, interoperates with Hono's exact algorithm and signs with first key",
    async () => {
      await using server = await start(binary);
      for (const value of values) {
        const wire = uncheckedSign("new-secret", value);
        expect(typeof wire).toBe("string");
        if (typeof wire !== "string") throw new Error("Invalid signature wire");
        expect(sign(keys, value)).toEqual(some(wire));
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
    },
    SLOW_TEST_TIMEOUT_MS,
  );

  test(
    "accepts an old key anywhere in the list, rejects removed keys and tampering",
    async () => {
      await using server = await start(binary);
      const old = honoWire("old-secret", "a.b%2E+");
      expect(verify(keys, old)).toEqual(some("a.b%2E+"));
      expect(verify({ $: "Keys", first: "old-secret", rest: list(["new-secret"]) }, old)).toEqual(
        some("a.b%2E+"),
      );
      expect(verify({ $: "Keys", first: "new-secret", rest: list([]) }, old)).toEqual(none);
      const raw = decodeURIComponent(old);
      const dot = raw.lastIndexOf(".");
      const badWires = [
        honoWire("unknown-secret", "a.b%2E+"),
        encodeURIComponent(`tampered${raw.slice(dot)}`),
        encodeURIComponent(`${raw.slice(0, dot + 1)}AAAA${raw.slice(dot + 5)}`),
        "unsigned",
        "",
        "%ZZ",
        "%FF",
        "a.",
        "a.AA==",
        "a.A===",
        "a.AA-_",
        old + "%3D",
      ];
      for (const wire of [old, ...badWires]) {
        const expected = wire === old ? "a.b%2E+" : "absent-or-invalid";
        expect(verify(keys, wire)).toEqual(wire === old ? some(expected) : none);
        const response = await fetch(`${server.url}/read`, {
          headers: { Cookie: `session=${wire}` },
        });
        expect(await response.text()).toBe(expected);
      }
      expect(await (await fetch(`${server.url}/read`)).text()).toBe("absent-or-invalid");
      // The first cookie wins even when it is invalid; never search duplicates for a valid signature.
      expect(
        await (
          await fetch(`${server.url}/read`, {
            headers: { Cookie: `session=bad; session=${old}` },
          })
        ).text(),
      ).toBe("absent-or-invalid");
    },
    SLOW_TEST_TIMEOUT_MS,
  );
});
