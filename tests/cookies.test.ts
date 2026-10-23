import { describe, expect, test } from "bun:test";
import { pathToFileURL } from "node:url";
import { build, compile, start } from "./harness.ts";

const output = compile("tests/fixtures/cookies/consumer.bend", "mjs");
const binary = build("tests/servers/cookies.bend");
const module: unknown = await import(pathToFileURL(output).href);
if (typeof module !== "object" || module === null || !("default" in module)) {
  throw new Error("Missing Bend exports");
}
const exports: unknown = module.default;
function exported(name: string): (...args: unknown[]) => unknown {
  if (typeof exports !== "object" || exports === null || !(name in exports)) {
    throw new Error(`Missing cookie export ${name}`);
  }
  const fn: unknown = Reflect.get(exports, name);
  if (typeof fn !== "function") throw new Error(`Not callable: ${name}`);
  return (...args) => fn(...args);
}
const parse = exported("parse");
const serialize = exported("serialize");
const first = exported("first");
const expiresValid = exported("expires_valid");
const deletion = exported("deletion");
const defaults = exported("defaults");
const none = { $: "None" };
const some = (value: unknown) => ({ $: "Some", value });
const bool = (value: boolean) => value;
const entry = (name: string, value: string) => ({ $: "Entry", name, value });
const done = (value: unknown) => ({ $: "Done", value });
const fail = (name: string) => ({ $: "Fail", error: { $: name } });
function list(values: unknown[]): unknown {
  return values.reduceRight<unknown>((tail, head) => ({ $: "Con", head, tail }), { $: "Nil" });
}
function options(overrides: Record<string, unknown> = {}) {
  return {
    $: "Options",
    path: none,
    domain: none,
    max_age: none,
    expires: none,
    secure: bool(false),
    http_only: bool(false),
    same_site: none,
    partitioned: bool(false),
    ...overrides,
  };
}

describe("Cookie parsing", () => {
  test("retains duplicates, empty values, equals signs and raw escapes in order", () => {
    expect(parse(' \ta=1; a=2; empty=; quoted="abc=123"; raw=%20+; x== ')).toEqual(
      list([
        entry("a", "1"),
        entry("a", "2"),
        entry("empty", ""),
        entry("quoted", "abc=123"),
        entry("raw", "%20+"),
        entry("x", "="),
      ]),
    );
    expect(first(parse("a=1; a=2"), "a")).toEqual(some("1"));
    expect(first(parse("a=1"), "A")).toEqual(none);
  });

  test("skips malformed segments and continues at the next semicolon", () => {
    expect(
      parse(
        'missing; =empty; bad name=x; bad=white space; q="unclosed; z=good; e=""; bad=x\\y; cr=x\r\n; u=é; end=ok',
      ),
    ).toEqual(list([entry("z", "good"), entry("e", ""), entry("end", "ok")]));
    expect(parse(";; \t;")).toEqual(list([]));
  });

  test("roundtrips every admissible ASCII name character and value octet", () => {
    const nameChars =
      "!#$%&'*+-.^_`|~0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
    for (const c of nameChars) {
      expect(serialize(c, "", defaults())).toEqual(done(`${c}=`));
      expect(parse(`${c}=`)).toEqual(list([entry(c, "")]));
    }
    for (let n = 0; n < 256; n++) {
      const c = String.fromCharCode(n);
      const valid =
        n === 33 ||
        (n >= 35 && n <= 43) ||
        (n >= 45 && n <= 58) ||
        (n >= 60 && n <= 91) ||
        (n >= 93 && n <= 126);
      expect(serialize("name", c, defaults())).toEqual(
        valid ? done(`name=${c}`) : fail("InvalidValue"),
      );
      if (valid) expect(parse(`name=${c}`)).toEqual(list([entry("name", c)]));
    }
  });
});

describe("Set-Cookie validation and attributes", () => {
  test("validates names, attribute injection, domains and paths", () => {
    for (const name of ["", "bad name", "a=b", "a;", "a\r\nb", "é"]) {
      expect(serialize(name, "v", defaults())).toEqual(fail("InvalidName"));
    }
    for (const path of ["relative", "/; Secure", "/\r\nx: bad", "/\u007f", "/é", "/trailing "]) {
      expect(serialize("a", "b", options({ path: some(path) }))).toEqual(fail("InvalidPath"));
    }
    for (const domain of [
      "",
      "a..b",
      "a; Secure",
      "a/b",
      "-a.com",
      "a-.com",
      "a.com.",
      "é.com",
      "a".repeat(64),
    ]) {
      expect(serialize("a", "b", options({ domain: some(domain) }))).toEqual(fail("InvalidDomain"));
    }
    expect(serialize("a", "b", options({ domain: some(".example.com") }))).toEqual(
      done("a=b; Domain=.example.com"),
    );
  });

  test("requires Secure for SameSite=None and Partitioned", () => {
    expect(serialize("a", "b", options({ same_site: some({ $: "NoRestriction" }) }))).toEqual(
      fail("SameSiteRequiresSecure"),
    );
    expect(serialize("a", "b", options({ partitioned: bool(true) }))).toEqual(
      fail("PartitionedRequiresSecure"),
    );
    expect(serialize("a", "b", options({ secure: bool(true), partitioned: bool(true) }))).toEqual(
      done("a=b; Secure; Partitioned"),
    );
  });

  test("accepts only fixed IMF-fixdate with real calendar and time ranges", () => {
    for (const date of ["Wed, 21 Oct 2015 07:28:00 GMT", "Tue, 29 Feb 2000 00:00:00 GMT"]) {
      expect(expiresValid(date)).toEqual(bool(true));
      expect(serialize("a", "b", options({ expires: some(date) }))).toEqual(
        done(`a=b; Expires=${date}`),
      );
    }
    for (const date of [
      "Wed, 31 Apr 2015 07:28:00 GMT",
      "Mon, 29 Feb 1900 00:00:00 GMT",
      "Mon, 00 Jan 2024 00:00:00 GMT",
      "Bad, 21 Oct 2015 07:28:00 GMT",
      "Wed, 21 Oct 2015 24:00:00 GMT",
      "Wed, 21 Oct 2015 07:60:00 GMT",
      "Wed, 21 Oct 2015 07:28:60 GMT",
      "Wed, 21 Oct 2015 07:28:00 UTC",
      "Wed, 21 Oct 2015 07:28:00 GMT; Secure",
      "Wed, 21 Oct 2015 07:28:00 GMT\r\nx: bad",
      "Wed, 1 Oct 2015 07:28:00 GMT",
    ]) {
      expect(serialize("a", "b", options({ expires: some(date) }))).toEqual(fail("InvalidExpires"));
    }
  });

  test("deletion preserves scope and security while overriding persistence", () => {
    const original = options({
      path: some("/scope"),
      domain: some("example.com"),
      max_age: some({ $: "Seconds", seconds: 60n }),
      expires: some("invalid overridden expiry"),
      secure: bool(true),
      http_only: bool(true),
      same_site: some({ $: "Strict" }),
      partitioned: bool(true),
    });
    expect(serialize("a", "", deletion(original))).toEqual(
      done(
        "a=; Path=/scope; Domain=example.com; Max-Age=0; Secure; HttpOnly; SameSite=Strict; Partitioned",
      ),
    );
  });
});

async function curl(url: string, ...args: string[]): Promise<string> {
  const proc = Bun.spawn(
    ["curl", "--silent", "--show-error", "--max-time", "10", "-i", ...args, url],
    { stdout: "pipe", stderr: "pipe" },
  );
  const [output, error, exit] = await Promise.all([
    new Response(proc.stdout).text(),
    new Response(proc.stderr).text(),
    proc.exited,
  ]);
  expect(error).toBe("");
  expect(exit).toBe(0);
  return output;
}

describe("compiled native cookie server", () => {
  test("curl -i sees each cookie field with exact attributes and preserved response state", async () => {
    await using server = await start(binary);
    const raw = await curl(`${server.url}/?mode=all`);
    const headers = raw.split("\r\n").filter((line) => line.startsWith("set-cookie:"));
    expect(headers).toEqual([
      "set-cookie: session=abc=123; Path=/account; Domain=example.com; Max-Age=3600; Expires=Wed, 21 Oct 2015 07:28:00 GMT; Secure; HttpOnly; SameSite=None; Partitioned",
      "set-cookie: other=two; Max-Age=-1; SameSite=Lax",
      "set-cookie: old=; Path=/account; Domain=example.com; Max-Age=0; Secure; HttpOnly; SameSite=None; Partitioned",
    ]);
    expect(raw.startsWith("HTTP/1.1 201 Created\r\n")).toBe(true);
    expect(raw).toContain("\r\nx-kept: yes\r\n");
    console.info(headers.join("\n"));
  });

  test("emits absent defaults, Strict and secure None without unrelated attributes", async () => {
    await using server = await start(binary);
    for (const [mode, expected] of [
      ["default", "session=raw%20+"],
      ["strict", "session=strict; Path=/; HttpOnly; SameSite=Strict"],
      ["none", "session=none; Secure; SameSite=None"],
    ]) {
      const raw = await curl(`${server.url}/?mode=${mode}`);
      expect(raw.split("\r\n").filter((line) => line.startsWith("set-cookie:"))).toEqual([
        `set-cookie: ${expected}`,
      ]);
    }
  });

  test("reads repeated Cookie fields in order and first wins across fields", async () => {
    await using server = await start(binary);
    const args = ["-H", 'Cookie: a=1; a=2; quoted="x=y"; bad; z=', "-H", "Cookie: a=3; b=%20+"];
    expect((await curl(`${server.url}/read`, ...args)).split("\r\n\r\n")[1]).toBe(
      "a=1|a=2|quoted=x=y|z=|a=3|b=%20+",
    );
    expect((await curl(`${server.url}/first`, ...args)).split("\r\n\r\n")[1]).toBe("1");
    expect(await (await fetch(`${server.url}/first`)).text()).toBe("absent");
  });

  test("typed validation errors emit no cookie or injected header", async () => {
    await using server = await start(binary);
    for (const value of ["bad;value", "bad\r\nx-injected: yes", "bad\u0000", "bad value", "é"]) {
      const raw = await curl(`${server.url}/invalid?value=${encodeURIComponent(value)}`);
      expect(raw.startsWith("HTTP/1.1 400 Bad Request\r\n")).toBe(true);
      expect(raw).not.toContain("set-cookie:");
      expect(raw).not.toContain("x-injected:");
    }
  });
});
