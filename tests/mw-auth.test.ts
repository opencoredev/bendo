import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { createHmac } from "node:crypto";
import { connect } from "node:net";
import { pathToFileURL } from "node:url";
import { SignJWT, UnsecuredJWT, decodeJwt, jwtVerify } from "jose";
import { build, compile, start, type RunningServer } from "./harness.ts";

// Test fixtures only. No secret here protects anything.
const SERVER_SECRET = "bendo-test-secret-not-real";
const binary = build("tests/servers/mw-auth.bend");
const modulePath = compile("tests/fixtures/jwt/consumer.bend", "mjs");

const loaded: unknown = await import(pathToFileURL(modulePath).href);
if (typeof loaded !== "object" || loaded === null || !("default" in loaded)) {
  throw new Error("Missing Bend module");
}
const exports: unknown = loaded.default;
function exported(name: string): (...args: unknown[]) => string {
  if (typeof exports !== "object" || exports === null || !(name in exports)) {
    throw new Error(`Missing export ${name}`);
  }
  const fn: unknown = Reflect.get(exports, name);
  if (typeof fn !== "function") throw new Error(`Not callable: ${name}`);
  return (...args) => {
    const result: unknown = fn(...args);
    if (typeof result !== "string") throw new Error(`${name} did not return a string`);
    return result;
  };
}
const bendSign = exported("sign");
const bendVerify = exported("verify");

type Outcome = { kind: "ok"; value: string } | { kind: "err"; reason: string };
function outcome(text: string): Outcome {
  if (text.startsWith("ok:")) return { kind: "ok", value: text.slice(3) };
  if (text.startsWith("err:")) return { kind: "err", reason: text.slice(4) };
  throw new Error(`Unexpected result ${text}`);
}
function signWithBendo(secret: Uint8Array, claims: unknown): string {
  const result = outcome(bendSign(Buffer.from(secret).toString("hex"), JSON.stringify(claims)));
  if (result.kind === "err") throw new Error(`Bendo refused to sign: ${result.reason}`);
  return result.value;
}
function verifyWithBendo(secret: Uint8Array, token: string, now: number, leeway = 0): Outcome {
  return outcome(bendVerify(Buffer.from(secret).toString("hex"), token, now, leeway));
}

// Deterministic generator, so a failing claim set can be reproduced.
function random(seed: number): () => number {
  let state = seed >>> 0;
  return () => {
    state = (Math.imul(state, 1664525) + 1013904223) >>> 0;
    return state / 2 ** 32;
  };
}
const ALPHABET = ["a", "Z", "0", " ", "é", "ß", "漢", "😀", '"', "\\", "/", "\n", "\t", "\u0001"];
function text(next: () => number): string {
  let out = "";
  const length = Math.floor(next() * 12);
  for (let i = 0; i < length; i++) out += ALPHABET[Math.floor(next() * ALPHABET.length)] ?? "a";
  return out;
}
function value(next: () => number, depth: number): unknown {
  const pick = Math.floor(next() * (depth > 2 ? 5 : 7));
  switch (pick) {
    case 0:
      return null;
    case 1:
      return next() < 0.5;
    case 2:
      return Math.floor(next() * 2 ** 40) - 2 ** 39;
    case 3:
      return Math.round(next() * 1e6) / 1000;
    case 4:
      return text(next);
    case 5:
      return Array.from({ length: Math.floor(next() * 4) }, () => value(next, depth + 1));
    default: {
      const object: Record<string, unknown> = {};
      for (let i = 0; i < Math.floor(next() * 4); i++)
        object[`k${i}${text(next)}`] = value(next, depth + 1);
      return object;
    }
  }
}
const NOW = 1_800_000_000;
function claimSet(seed: number): Record<string, unknown> {
  const next = random(seed);
  const claims: Record<string, unknown> = { sub: text(next), seed };
  for (let i = 0; i < Math.floor(next() * 5); i++) claims[`c${i}`] = value(next, 0);
  if (next() < 0.7) claims.exp = NOW + 1 + Math.floor(next() * 100_000);
  if (next() < 0.5) claims.nbf = NOW - Math.floor(next() * 100_000);
  if (next() < 0.5) claims.iat = NOW - Math.floor(next() * 100_000);
  if (next() < 0.2) claims.exp = NOW + 0.5;
  return claims;
}
function secretFor(seed: number): Uint8Array {
  const next = random(seed ^ 0x9e3779b9);
  // Lengths cover empty-ish, block-sized and longer-than-block HMAC keys.
  const length = [1, 16, 32, 64, 65, 100][seed % 6] ?? 32;
  return Uint8Array.from({ length }, () => Math.floor(next() * 256));
}
const SEEDS = Array.from({ length: 120 }, (_, i) => i + 1);

function b64url(input: string | Buffer): string {
  return Buffer.from(input).toString("base64url");
}
function hs256(secret: Uint8Array, input: string): string {
  return createHmac("sha256", secret).update(input).digest("base64url");
}
function forgeText(secret: Uint8Array, header: string, payload: string): string {
  const input = `${b64url(header)}.${b64url(payload)}`;
  return `${input}.${hs256(secret, input)}`;
}
function forge(secret: Uint8Array, header: unknown, payload: string): string {
  return forgeText(secret, JSON.stringify(header), payload);
}

describe("JWT interop with jose", () => {
  test("Bendo tokens verify with jose for many claim sets", async () => {
    for (const seed of SEEDS) {
      const secret = secretFor(seed);
      const claims = claimSet(seed);
      const token = signWithBendo(secret, claims);
      const { payload, protectedHeader } = await jwtVerify(token, secret, {
        currentDate: new Date(NOW * 1000),
        algorithms: ["HS256"],
      });
      expect(protectedHeader).toEqual({ alg: "HS256", typ: "JWT" });
      expect(payload).toEqual(claims);
    }
  });

  test("jose tokens verify with Bendo for many claim sets", async () => {
    for (const seed of SEEDS) {
      const secret = secretFor(seed);
      const claims = claimSet(seed);
      const token = await new SignJWT(claims).setProtectedHeader({ alg: "HS256" }).sign(secret);
      const result = verifyWithBendo(secret, token, NOW);
      expect(result.kind).toBe("ok");
      if (result.kind === "ok") expect(JSON.parse(result.value)).toEqual(claims);
    }
  });

  test("Bendo verifies its own tokens and jose's typ variants", async () => {
    const secret = secretFor(7);
    const own = signWithBendo(secret, { a: 1 });
    expect(verifyWithBendo(secret, own, NOW)).toEqual({
      kind: "ok",
      value: '{"a":1}',
    });
    const typed = await new SignJWT({ a: 2 })
      .setProtectedHeader({ alg: "HS256", typ: "JWT", kid: "k1" })
      .sign(secret);
    expect(verifyWithBendo(secret, typed, NOW)).toEqual({
      kind: "ok",
      value: '{"a":2}',
    });
  });
});

describe("JWT rejection", () => {
  const secret = secretFor(3);
  const base = { sub: "ada" };

  test("exp, nbf and iat use the supplied clock and leeway", () => {
    const at = (claims: object, now: number, leeway = 0) =>
      verifyWithBendo(secret, signWithBendo(secret, claims), now, leeway);
    expect(at({ exp: 1000 }, 999).kind).toBe("ok");
    expect(at({ exp: 1000 }, 1000)).toEqual({
      kind: "err",
      reason: "token expired",
    });
    expect(at({ exp: 1000 }, 1059, 60).kind).toBe("ok");
    expect(at({ exp: 1000 }, 1060, 60)).toEqual({
      kind: "err",
      reason: "token expired",
    });
    expect(at({ exp: 1000.5 }, 1000).kind).toBe("ok");
    expect(at({ exp: 1000.5 }, 1001).kind).toBe("err");
    expect(at({ exp: 0 }, 0, 0).kind).toBe("err");
    expect(at({ exp: -5 }, 0, 100).kind).toBe("err");
    expect(at({ nbf: 1000 }, 1000).kind).toBe("ok");
    expect(at({ nbf: 1000 }, 999)).toEqual({
      kind: "err",
      reason: "token not yet valid",
    });
    expect(at({ nbf: 1000 }, 940, 60).kind).toBe("ok");
    expect(at({ nbf: 1000.5 }, 1000).kind).toBe("err");
    expect(at({ nbf: -1 }, 0).kind).toBe("ok");
    expect(at({ iat: 1000 }, 999)).toEqual({
      kind: "err",
      reason: "token issued in the future",
    });
    expect(at({ iat: 1000 }, 1000).kind).toBe("ok");
    expect(at({ iat: 1e30 }, NOW).kind).toBe("err");
    expect(at({ exp: 1e30 }, NOW).kind).toBe("ok");
    expect(at({ exp: 1e-3 }, 0).kind).toBe("ok");
  });

  test("NumericDate spellings with exponents and fractions compare exactly", () => {
    const at = (payload: string, now: number) =>
      verifyWithBendo(secret, forge(secret, { alg: "HS256" }, payload), now).kind;
    expect(at('{"exp":1e3}', 999)).toBe("ok");
    expect(at('{"exp":1E3}', 1000)).toBe("err");
    expect(at('{"exp":10000e-1}', 999)).toBe("ok");
    expect(at('{"exp":10000e-1}', 1000)).toBe("err");
    expect(at('{"exp":1.0005E+3}', 1000)).toBe("ok");
    expect(at('{"exp":1.0005E+3}', 1001)).toBe("err");
    expect(at('{"exp":0.0}', 0)).toBe("err");
    expect(at('{"exp":12e2}', 1199)).toBe("ok");
    expect(at('{"nbf":-0}', 0)).toBe("ok");
    expect(at('{"nbf":1e99999}', NOW)).toBe("err");
    expect(at('{"nbf":1e-99999}', 0)).toBe("err");
    expect(at('{"nbf":1e-99999}', 1)).toBe("ok");
    expect(at('{"iat":999.9999}', 999)).toBe("err");
    expect(at('{"iat":999.0000}', 999)).toBe("ok");
  });

  test("Bendo's clock decisions match jose's at the boundaries", async () => {
    for (const [claims, now, leeway] of [
      [{ exp: 1000 }, 999, 0],
      [{ exp: 1000 }, 1000, 0],
      [{ exp: 1000 }, 1059, 60],
      [{ exp: 1000 }, 1060, 60],
      [{ nbf: 1000 }, 999, 0],
      [{ nbf: 1000 }, 1000, 0],
      [{ nbf: 1000 }, 940, 60],
      [{ nbf: 1000 }, 939, 60],
    ] as const) {
      const token = signWithBendo(secret, claims);
      const jose = await jwtVerify(token, secret, {
        currentDate: new Date(now * 1000),
        clockTolerance: leeway,
      }).then(
        (): Outcome["kind"] => "ok",
        (): Outcome["kind"] => "err",
      );
      expect(verifyWithBendo(secret, token, now, leeway).kind).toBe(jose);
    }
  });

  test("non-numeric time claims are rejected", () => {
    for (const [name, bad] of [
      ["exp", "9999999999"],
      ["exp", null],
      ["nbf", true],
      ["iat", [1]],
      ["exp", { n: 1 }],
    ] as const) {
      const token = forge(secret, { alg: "HS256" }, JSON.stringify({ ...base, [name]: bad }));
      expect(verifyWithBendo(secret, token, NOW)).toEqual({
        kind: "err",
        reason: `invalid ${name} claim`,
      });
    }
  });

  test("tampered tokens are rejected", () => {
    const token = signWithBendo(secret, { ...base, admin: false });
    const [h, p, s] = token.split(".");
    if (h === undefined || p === undefined || s === undefined) throw new Error("bad token");
    const forgedPayload = b64url(JSON.stringify({ ...base, admin: true }));
    const flipped = `${s.slice(0, -2)}${s.at(-2) === "A" ? "B" : "A"}${s.at(-1)}`;
    for (const tampered of [
      `${h}.${forgedPayload}.${s}`,
      `${h}.${p}.${flipped}`,
      `${h}.${p}.${s}x`,
      `${h}.${p}.${s.slice(1)}`,
      `${h}.${p}.`,
      `${b64url('{"alg":"HS256","typ":"JWT","x":1}')}.${p}.${s}`,
    ]) {
      expect(verifyWithBendo(secret, tampered, NOW)).toEqual({
        kind: "err",
        reason: "invalid signature",
      });
    }
    expect(verifyWithBendo(secretFor(4), token, NOW)).toEqual({
      kind: "err",
      reason: "invalid signature",
    });
  });

  test("wrong algorithms are rejected, including none and RS256 confusion", async () => {
    const payload = JSON.stringify(base);
    const unsecured = new UnsecuredJWT(base).encode();
    expect(decodeJwt(unsecured)).toEqual(base);
    expect(verifyWithBendo(secret, unsecured, NOW).kind).toBe("err");
    // A correctly keyed HMAC under a header that names another algorithm.
    for (const alg of ["none", "None", "RS256", "HS512", "hs256", "ES256", ""]) {
      expect(verifyWithBendo(secret, forge(secret, { alg }, payload), NOW)).toEqual({
        kind: "err",
        reason: "unsupported algorithm",
      });
    }
    expect(verifyWithBendo(secret, forge(secret, { typ: "JWT" }, payload), NOW).kind).toBe("err");
    expect(verifyWithBendo(secret, forge(secret, { alg: 256 }, payload), NOW).kind).toBe("err");
    expect(
      verifyWithBendo(secret, forge(secret, { alg: "HS256", crit: ["exp"] }, payload), NOW),
    ).toEqual({ kind: "err", reason: "invalid header" });
  });

  test("repeated member names are rejected in the header and the claims", async () => {
    const duplicate: Outcome = { kind: "err", reason: "duplicate member name" };
    const hs256Header = '{"alg":"HS256"}';
    const payload = JSON.stringify(base);
    // jose keeps the last copy, so it rejects these too: alg none, exp 1.
    const joseRejects: [string, string][] = [
      ['{"alg":"HS256","alg":"none"}', payload],
      [hs256Header, '{"exp":2000000000,"exp":1}'],
    ];
    for (const [header, body] of joseRejects) {
      const token = forgeText(secret, header, body);
      expect(verifyWithBendo(secret, token, NOW)).toEqual(duplicate);
      await expect(
        jwtVerify(token, secret, { currentDate: new Date(NOW * 1000) }),
      ).rejects.toThrow();
    }
    // Either copy taken alone would verify, so the first copy cannot decide.
    const ambiguous: [string, string][] = [
      ['{"alg":"none","alg":"HS256"}', payload],
      ['{"alg":"HS256","alg":"HS256"}', payload],
      ['{"alg":"HS256","typ":"JWT","typ":"JWT"}', payload],
      ['{"crit":["x"],"alg":"HS256","crit":["y"]}', payload],
      [hs256Header, '{"exp":1,"exp":2000000000}'],
      [hs256Header, '{"exp":2000000000,"exp":2000000000}'],
      [hs256Header, '{"nbf":1,"nbf":4000000000}'],
      [hs256Header, '{"nbf":4000000000,"nbf":1}'],
      [hs256Header, '{"iat":1,"iat":4000000000}'],
      [hs256Header, '{"iat":4000000000,"iat":1}'],
      [hs256Header, '{"sub":"ada","sub":"root"}'],
      [hs256Header, '{"sub":"ada","exp":2000000000,"sub":"ada"}'],
    ];
    for (const [header, body] of ambiguous) {
      expect(verifyWithBendo(secret, forgeText(secret, header, body), NOW)).toEqual(duplicate);
    }
    // Only top-level names count; nested objects are claim values.
    expect(
      verifyWithBendo(secret, forgeText(secret, hs256Header, '{"ctx":{"a":1,"a":2}}'), NOW).kind,
    ).toBe("ok");
    expect(
      verifyWithBendo(
        secret,
        forgeText(secret, '{"alg":"HS256","jwk":{"k":"a","k":"b"}}', payload),
        NOW,
      ).kind,
    ).toBe("ok");
    // Bendo refuses to sign a claim set it would reject.
    expect(outcome(bendSign(Buffer.from(secret).toString("hex"), '{"a":1,"a":2}'))).toEqual(
      duplicate,
    );
  });

  test("malformed tokens are rejected", () => {
    const token = signWithBendo(secret, base);
    const [h, p, s] = token.split(".");
    if (h === undefined || p === undefined || s === undefined) throw new Error("bad token");
    for (const bad of ["", ".", "...", h, `${h}.${p}`, `${token}.`, `${token}.${s}`]) {
      expect(verifyWithBendo(secret, bad, NOW)).toEqual({
        kind: "err",
        reason: "malformed token",
      });
    }
    // Three empty segments are well formed; the empty signature cannot match.
    expect(verifyWithBendo(secret, "..", NOW)).toEqual({
      kind: "err",
      reason: "invalid signature",
    });
    // Signed correctly over a signing input whose segments are not base64url.
    for (const [a, b] of [
      [`${h}=`, p],
      [h, `${p}=`],
      [`${h.slice(0, 4)}+${h.slice(5)}`, p],
      [h, `${p.slice(0, 3)}/${p.slice(4)}`],
      [h, `${p.slice(0, 2)}$`],
      [`${h}A`, p],
    ]) {
      const input = `${a}.${b}`;
      expect(verifyWithBendo(secret, `${input}.${hs256(secret, input)}`, NOW)).toEqual({
        kind: "err",
        reason: "invalid encoding",
      });
    }
    // Valid base64url, but not a JSON object.
    for (const [header, body] of [
      ['{"alg":"HS256"}', "[1,2]"],
      ['{"alg":"HS256"}', "not json"],
      ['["HS256"]', "{}"],
    ] as const) {
      const input = `${b64url(header)}.${b64url(body)}`;
      expect(verifyWithBendo(secret, `${input}.${hs256(secret, input)}`, NOW).kind).toBe("err");
    }
  });
});

let server: RunningServer;
beforeAll(async () => {
  server = await start(binary);
});
afterAll(async () => {
  await server[Symbol.asyncDispose]();
});

function basic(user: string, pass: string): string {
  return `Basic ${Buffer.from(`${user}:${pass}`, "utf8").toString("base64")}`;
}
async function get(path: string, headers: Record<string, string> = {}): Promise<Response> {
  return fetch(server.url + path, { headers });
}

describe("basic auth", () => {
  const realm = 'Basic realm="Bendo \\"test\\" \\\\ realm", charset="UTF-8"';

  test("accepts configured credentials, including a colon in the password and UTF-8", async () => {
    for (const [user, pass] of [
      ["ada", "pa:ss:word"],
      ["José", "pässwörd"],
    ] as const) {
      const res = await get("/basic/ok", { authorization: basic(user, pass) });
      expect(res.status).toBe(200);
      expect(await res.text()).toBe("ok:GET");
    }
    const lower = Buffer.from("ada:pa:ss:word").toString("base64");
    expect((await get("/basic/ok", { authorization: `bAsIc   ${lower}  ` })).status).toBe(200);
    const unpaddedGood = Buffer.from("José:pässwörd").toString("base64").replace(/=+$/, "");
    expect((await get("/basic/ok", { authorization: `Basic ${unpaddedGood}` })).status).toBe(200);
  });

  test("rejects with 401 and a quoted realm challenge", async () => {
    for (const authorization of [
      undefined,
      basic("ada", "pa:ss:wor"),
      basic("ada", "pa:ss:word "),
      basic("Ada", "pa:ss:word"),
      basic("José", "passwords"),
      basic("", ""),
      "Basic",
      "Basic ",
      "Basic !!!!",
      `Basic ${Buffer.from("no-colon").toString("base64")}`,
      `Basic ${Buffer.from([0x61, 0x3a, 0xff]).toString("base64")}`,
      `Bearer ${Buffer.from("ada:pa:ss:word").toString("base64")}`,
      `Basicx ${Buffer.from("ada:pa:ss:word").toString("base64")}`,
    ]) {
      const res = await get("/basic/ok", authorization === undefined ? {} : { authorization });
      expect(res.status).toBe(401);
      expect(res.headers.get("www-authenticate")).toBe(realm);
      expect(await res.text()).toBe("Unauthorized");
    }
  });

  test("leaves other paths alone", async () => {
    expect((await get("/")).status).toBe(200);
  });
});

describe("bearer auth", () => {
  test("accepts configured tokens in b64token syntax", async () => {
    for (const authorization of [
      "Bearer abc.DEF-123_~+/=",
      "bearer second-token",
      "BEARER   second-token  ",
    ]) {
      const res = await get("/bearer/ok", { authorization });
      expect(res.status).toBe(200);
    }
  });

  test("uses RFC 6750 status codes and error parameters", async () => {
    const missing = await get("/bearer/ok");
    expect(missing.status).toBe(401);
    expect(missing.headers.get("www-authenticate")).toBe('Bearer realm="api"');
    for (const authorization of ["Bearer second-tokeN", "Bearer second-token=", "Bearer abc"]) {
      const res = await get("/bearer/ok", { authorization });
      expect(res.status).toBe(401);
      expect(res.headers.get("www-authenticate")).toBe('Bearer realm="api", error="invalid_token"');
    }
    for (const authorization of [
      "Basic c2Vjb25kLXRva2Vu",
      "Bearer",
      "Bearer a b",
      "Bearer a$b",
      "Bearer =abc",
      "Bearer ab=c",
    ]) {
      const res = await get("/bearer/ok", { authorization });
      expect(res.status).toBe(400);
      expect(res.headers.get("www-authenticate")).toBe(
        'Bearer realm="api", error="invalid_request"',
      );
    }
  });
});

describe("JWT middleware", () => {
  const key = new TextEncoder().encode(SERVER_SECRET);
  const now = () => Math.floor(Date.now() / 1000);

  test("passes jose-signed claims to the handler through typed Vars", async () => {
    const claims = {
      sub: "ada",
      role: "admin",
      exp: now() + 600,
      iat: now() - 5,
    };
    const token = await new SignJWT(claims).setProtectedHeader({ alg: "HS256" }).sign(key);
    const res = await get("/jwt/me", { authorization: `Bearer ${token}` });
    expect(res.status).toBe(200);
    expect(JSON.parse(await res.text())).toEqual(claims);
    expect((await get("/jwt-plain/ok", { authorization: `Bearer ${token}` })).status).toBe(200);
  });

  test("server-signed tokens verify with jose", async () => {
    const claims = { sub: "José", exp: now() + 600 };
    const res = await fetch(`${server.url}/sign`, {
      method: "POST",
      body: JSON.stringify(claims),
    });
    expect(res.status).toBe(200);
    const { payload } = await jwtVerify(await res.text(), key, {
      algorithms: ["HS256"],
    });
    expect(payload).toEqual(claims);
  });

  test("rejects expired, future and tampered tokens with 401 invalid_token", async () => {
    const sign = (claims: object) =>
      new SignJWT({ sub: "ada", ...claims }).setProtectedHeader({ alg: "HS256" }).sign(key);
    const good = await sign({ exp: now() + 600 });
    const [h, p, s] = good.split(".");
    if (h === undefined || p === undefined || s === undefined) throw new Error("bad token");
    const cases: [string, string][] = [
      [await sign({ exp: now() - 10 }), "token expired"],
      [await sign({ nbf: now() + 600 }), "token not yet valid"],
      [await sign({ iat: now() + 600 }), "token issued in the future"],
      [`${h}.${b64url('{"sub":"root"}')}.${s}`, "invalid signature"],
      [
        await new SignJWT({ sub: "ada" })
          .setProtectedHeader({ alg: "HS256" })
          .sign(new TextEncoder().encode("other-test-secret")),
        "invalid signature",
      ],
      [new UnsecuredJWT({ sub: "ada" }).encode(), "invalid signature"],
      [forge(key, { alg: "RS256" }, '{"sub":"ada"}'), "unsupported algorithm"],
      [`${good}.extra`, "malformed token"],
      [`${h}.${p}`, "malformed token"],
      [`${h}.${p}$.${s}`, "invalid signature"],
      [forge(key, { alg: "HS256" }, '{"exp":"soon"}'), "invalid exp claim"],
      [forgeText(key, '{"alg":"HS256","alg":"none"}', '{"sub":"ada"}'), "duplicate member name"],
      [
        forgeText(key, '{"alg":"HS256"}', `{"exp":${now() + 600},"exp":1}`),
        "duplicate member name",
      ],
    ];
    for (const [token, reason] of cases) {
      const res = await get("/jwt/me", { authorization: `Bearer ${token}` });
      expect(res.status).toBe(401);
      expect(res.headers.get("www-authenticate")).toBe(
        `Bearer realm="jwt", error="invalid_token", error_description="${reason}"`,
      );
    }
  });

  test("missing or non-bearer credentials get a 401 challenge", async () => {
    const missing = await get("/jwt/me");
    expect(missing.status).toBe(401);
    expect(missing.headers.get("www-authenticate")).toBe('Bearer realm="jwt"');
    const other = await get("/jwt/me", { authorization: "Basic YTpi" });
    expect(other.status).toBe(401);
    expect(other.headers.get("www-authenticate")).toBe(
      'Bearer realm="jwt", error="invalid_request"',
    );
  });

  test("the leeway option tolerates clock skew", async () => {
    const token = await new SignJWT({ sub: "ada", exp: now() - 10 })
      .setProtectedHeader({ alg: "HS256" })
      .sign(key);
    expect((await get("/jwt/me", { authorization: `Bearer ${token}` })).status).toBe(401);
    expect((await get("/jwt-skew/me", { authorization: `Bearer ${token}` })).status).toBe(200);
  });
});

describe("CSRF", () => {
  type Unsafe = "POST" | "PUT" | "PATCH" | "DELETE";
  async function post(
    headers: Record<string, string>,
    method: Unsafe = "POST",
    path = "/csrf/form",
  ): Promise<number> {
    const res = await fetch(`${server.url}${path}`, {
      method,
      headers,
      body: "a=1",
    });
    return res.status;
  }
  const form = { "content-type": "application/x-www-form-urlencoded" };
  // A raw request, so the test controls the Host header.
  function rawStatus(path: string, fields: Record<string, string>): Promise<number> {
    const head = Object.entries({
      ...form,
      "content-length": "3",
      connection: "close",
      ...fields,
    })
      .map(([name, value]) => `${name}: ${value}\r\n`)
      .join("");
    return new Promise((resolve, reject) => {
      const target = new URL(server.url);
      const socket = connect({
        host: target.hostname,
        port: Number(target.port),
      });
      const chunks: Buffer[] = [];
      socket.setTimeout(5000, () => socket.destroy(new Error("CSRF socket timed out")));
      socket.on("connect", () => socket.end(`POST ${path} HTTP/1.1\r\n${head}\r\na=1`));
      socket.on("data", (chunk: Buffer) => chunks.push(chunk));
      socket.on("error", reject);
      socket.on("end", () => {
        const status = /^HTTP\/1\.1 (\d{3})/.exec(Buffer.concat(chunks).toString("latin1"));
        if (status?.[1] === undefined) reject(new Error("No status line"));
        else resolve(Number(status[1]));
      });
    });
  }

  test("a cross-origin form post is rejected with 403", async () => {
    for (const type of [
      "application/x-www-form-urlencoded",
      "multipart/form-data; boundary=x",
      "text/plain",
      "Text/Plain; charset=utf-8",
    ]) {
      expect(await post({ origin: "https://evil.example", "content-type": type })).toBe(403);
    }
    expect(await post({ origin: "https://evil.example" })).toBe(403);
    for (const method of ["PUT", "PATCH", "DELETE"] satisfies Unsafe[]) {
      expect(await post({ ...form, origin: "https://evil.example" }, method)).toBe(403);
    }
    const res = await fetch(`${server.url}/csrf/form`, {
      method: "POST",
      headers: { ...form, origin: "https://evil.example" },
      body: "a=1",
    });
    expect(await res.text()).toBe("Forbidden");
  });

  test("same-origin, configured and safe requests pass", async () => {
    const own = new URL(server.url);
    expect(await post({ ...form, origin: `http://${own.host}` })).toBe(200);
    expect(await post({ ...form, origin: `HTTP://${own.host.toUpperCase()}` })).toBe(200);
    expect(await post({ ...form, origin: "https://trusted.example" })).toBe(200);
    expect(await post({ ...form, "sec-fetch-site": "same-origin" })).toBe(200);
    expect(await post({ ...form, "sec-fetch-site": "Same-Origin" })).toBe(200);
    for (const method of ["GET", "HEAD"]) {
      const res = await fetch(`${server.url}/csrf/form`, {
        method,
        headers: { ...form, origin: "https://evil.example" },
      });
      expect(res.status).toBe(200);
    }
    // JSON cannot be sent cross-origin without a CORS preflight, as in Hono.
    expect(
      await post({
        "content-type": "application/json",
        origin: "https://evil.example",
      }),
    ).toBe(200);
  });

  test("the scheme is part of the origin", async () => {
    const own = new URL(server.url);
    // /csrf trusts http://Host; /csrf-https trusts https://Host.
    expect(await post({ ...form, origin: `https://${own.host}` })).toBe(403);
    expect(await post({ ...form, origin: `http://${own.host}` }, "POST", "/csrf-https/form")).toBe(
      403,
    );
    expect(await post({ ...form, origin: `https://${own.host}` }, "POST", "/csrf-https/form")).toBe(
      200,
    );
    expect(
      await post({ ...form, referer: `http://${own.host}/a` }, "POST", "/csrf-https/form"),
    ).toBe(403);
    // Configured origins compare by scheme too.
    for (const origin of ["http://trusted.example", "https://trusted.example:80"]) {
      expect(await post({ ...form, origin }, "POST", "/csrf-https/form")).toBe(403);
    }
  });

  test("ports, case and IPv6 hosts compare as serialized origins", async () => {
    // Configured as https://Trusted.Example:443/login and http://[::1]:8080.
    for (const origin of [
      "https://trusted.example",
      "https://trusted.example:443",
      "HTTPS://TRUSTED.EXAMPLE",
      "http://[::1]:8080",
    ]) {
      expect(await post({ ...form, origin }, "POST", "/csrf-https/form")).toBe(200);
    }
    for (const origin of [
      "https://trusted.example:8443",
      "http://[::1]",
      "http://[::1]:80",
      "http://[::2]:8080",
      "https://trusted.example/login",
    ]) {
      expect(await post({ ...form, origin }, "POST", "/csrf-https/form")).toBe(403);
    }
    // Host matching, with the Host header set directly.
    const cases: [string, string, number][] = [
      ["app.example", "https://app.example", 200],
      ["app.example:443", "https://app.example", 200],
      ["APP.example", "https://app.EXAMPLE:443", 200],
      ["app.example:8443", "https://app.example:8443", 200],
      ["app.example", "https://app.example:8443", 403],
      ["app.example:8443", "https://app.example", 403],
      ["app.example", "http://app.example", 403],
      ["[::1]:8443", "https://[::1]:8443", 200],
      ["[::1]", "https://[::1]:443", 200],
      ["[::1]", "https://[::2]", 403],
      ["user@app.example", "https://app.example", 403],
    ];
    for (const [host, origin, status] of cases) {
      expect(await rawStatus("/csrf-https/form", { host, origin })).toBe(status);
    }
    // Without a configured scheme, Host never vouches for an origin.
    expect(
      await rawStatus("/csrf-listed/form", {
        host: "app.example",
        origin: "http://app.example",
      }),
    ).toBe(403);
    expect(
      await rawStatus("/csrf-listed/form", {
        host: "app.example",
        origin: "https://app.example",
      }),
    ).toBe(403);
    expect(
      await rawStatus("/csrf-listed/form", {
        host: "app.example",
        origin: "https://trusted.example",
      }),
    ).toBe(200);
  });

  test("Sec-Fetch-Site: cross-site is never overridden by a Host match", async () => {
    const own = new URL(server.url);
    expect(
      await post({
        ...form,
        origin: `http://${own.host}`,
        "sec-fetch-site": "cross-site",
      }),
    ).toBe(403);
    expect(
      await post({
        ...form,
        referer: `http://${own.host}/`,
        "sec-fetch-site": "Cross-Site",
      }),
    ).toBe(403);
    expect(
      await rawStatus("/csrf-https/form", {
        host: "app.example",
        origin: "https://app.example",
        "sec-fetch-site": "cross-site",
      }),
    ).toBe(403);
    // A configured origin is trusted even when it is another site.
    expect(
      await post({
        ...form,
        origin: "https://trusted.example",
        "sec-fetch-site": "cross-site",
      }),
    ).toBe(200);
    // Other values leave the Origin check in charge.
    for (const site of ["same-site", "none", "bogus"]) {
      expect(
        await post({
          ...form,
          origin: `http://${own.host}`,
          "sec-fetch-site": site,
        }),
      ).toBe(200);
      expect(
        await post({
          ...form,
          origin: "https://evil.example",
          "sec-fetch-site": site,
        }),
      ).toBe(403);
    }
  });

  test("Referer is the fallback when Origin is absent", async () => {
    const own = new URL(server.url);
    expect(await post({ ...form, referer: `http://${own.host}/page?q=1` })).toBe(200);
    expect(await post({ ...form, referer: `http://${own.host}?q=1` })).toBe(200);
    expect(await post({ ...form, referer: "https://trusted.example/a/b" })).toBe(200);
    expect(await post({ ...form, referer: "https://evil.example/" })).toBe(403);
    expect(await post({ ...form, referer: `http://${own.host}.evil.example/` })).toBe(403);
    expect(await post({ ...form, referer: `http://evil@${own.host}/` })).toBe(403);
    expect(await post(form)).toBe(403);
    // Origin wins over Referer, whichever way they disagree.
    expect(
      await post({
        ...form,
        origin: "https://evil.example",
        referer: `http://${own.host}/`,
      }),
    ).toBe(403);
    expect(await post({ ...form, origin: "null", referer: `http://${own.host}/` })).toBe(403);
    expect(
      await post({
        ...form,
        origin: `http://${own.host}`,
        referer: "https://evil.example/",
      }),
    ).toBe(200);
  });

  test("suspicious origins are rejected", async () => {
    const own = new URL(server.url);
    for (const origin of [
      "null",
      `ftp://${own.host}`,
      `http://${own.hostname}:1`,
      `http://${own.host}.evil.example`,
      `http://${own.host}/`,
      `http://user@${own.host}`,
      "https://trusted.example.evil",
      "https://trusted.example/",
      "",
    ]) {
      expect(await post({ ...form, origin })).toBe(403);
    }
    expect(
      await post({
        ...form,
        origin: "https://evil.example",
        "sec-fetch-site": "cross-site",
      }),
    ).toBe(403);
    expect(
      await post({
        ...form,
        origin: "https://evil.example",
        "sec-fetch-site": "same-site",
      }),
    ).toBe(403);
  });
});
