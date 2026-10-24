// BND-85: origin, media-type and trim parsing on concrete vectors, through the
// compiled .mjs build. The laws in proof/origin-laws.bend, media-laws.bend and
// trim-laws.bend cover every input; these vectors pin the decisions they encode.
import { describe, expect, test } from "bun:test";
import { pathToFileURL } from "node:url";
import { compile } from "./harness.ts";

const output = compile("tests/fixtures/origin/consumer.bend", "mjs");
const module: unknown = await import(pathToFileURL(output).href);
if (typeof module !== "object" || module === null || !("default" in module)) {
  throw new Error("Missing origin exports");
}
const api: unknown = module.default;

function exported(name: string): (...args: string[]) => string {
  if (typeof api !== "object" || api === null) throw new Error("Invalid origin exports");
  const fn: unknown = Reflect.get(api, name);
  if (typeof fn !== "function") throw new Error(`Missing origin export: ${name}`);
  return (...args) => {
    const result: unknown = fn(...args);
    if (typeof result !== "string") throw new Error(`${name} returned ${typeof result}`);
    return result;
  };
}

// The fixture answers "" for a rejected value.
const canonical = exported("canonical");
const ofUrl = exported("of_url");
const ofHost = exported("of_host");
const essence = exported("essence");
const trimText = exported("trim_text");

describe("Origin hosts are accepted only in the form browsers send", () => {
  test.each([
    ["http://127.0.0.1", "http://127.0.0.1"],
    ["http://255.255.255.255", "http://255.255.255.255"],
    ["https://[::1]", "https://[::1]"],
    ["https://[::]", "https://[::]"],
    ["https://[2001:db8::1]", "https://[2001:db8::1]"],
    ["https://[2001:db8::1:0:0:1]", "https://[2001:db8::1:0:0:1]"],
    ["https://[1:2:3:4:5:6:7:8]", "https://[1:2:3:4:5:6:7:8]"],
    ["https://[1:2:3:4:5:6:7:0]", "https://[1:2:3:4:5:6:7:0]"],
    ["https://[::A]", "https://[::a]"],
    ["HTTPS://App.Example", "https://app.example"],
    ["http://example.com.", "http://example.com."],
    ["http://a.1b", "http://a.1b"],
    ["http://_x.y-z", "http://_x.y-z"],
  ])("%s serializes as %s", (input, expected) => {
    expect(canonical(input)).toBe(expected);
    expect(ofUrl(input)).toBe(expected);
  });

  test.each([
    "https://[:::]:443",
    "https://[:::]",
    "https://[abc]",
    "https://[0::1]",
    "https://[2001:db8:0:0:1:0:0:1]",
    "https://[2001:db8:0:0:1::1]",
    "https://[1:2:3:4:5:6:7::]",
    "https://[::ffff:1.2.3.4]",
    "https://[0:0:0:0:0:0:0:1]",
    "https://[::01]",
    "https://[::12345]",
    "http://[::1",
    "http://[::1]x",
    "http://127.1",
    "http://0x7f.1",
    "http://0x",
    "http://01.2.3.4",
    "http://256.0.0.1",
    "http://1.2.3",
    "http://1.2.3.4.",
    "http://a.b.1",
    `http://${"a".repeat(254)}`,
  ])("%s is rejected", (input) => {
    expect(canonical(input)).toBe("");
    expect(ofUrl(input)).toBe("");
  });

  test("the longest DNS name is accepted", () => {
    const host = "a".repeat(253);
    expect(canonical(`http://${host}`)).toBe(`http://${host}`);
  });
});

describe("Origins keep scheme and effective port apart", () => {
  test.each([
    ["https://a:443", "https://a"],
    ["http://a:80", "http://a"],
    ["http://a:00080", "http://a"],
    ["http://a:", "http://a"],
    ["https://a:8443", "https://a:8443"],
    ["http://a:443", "http://a:443"],
    ["https://a:80", "https://a:80"],
    ["http://a:65535", "http://a:65535"],
    ["http://[::1]:8080", "http://[::1]:8080"],
  ])("%s serializes as %s", (input, expected) => {
    expect(canonical(input)).toBe(expected);
  });

  test("an out-of-range or malformed port is rejected", () => {
    for (const input of ["http://a:65536", "http://a:123456", "http://a:8x", "http://a:-1"]) {
      expect(canonical(input)).toBe("");
    }
  });

  test("Origin values carry no path; URLs may", () => {
    expect(canonical("http://a/path")).toBe("");
    expect(ofUrl("http://a/path?q#f")).toBe("http://a");
    for (const input of ["null", "http://user@a", "ftp://a", "http:a"]) {
      expect(canonical(input)).toBe("");
    }
  });
});

describe("Values are trimmed of SP and HTAB only", () => {
  test("origins", () => {
    expect(canonical(" \thttps://a\t ")).toBe("https://a");
    expect(canonical("\u000bhttps://a")).toBe("");
    expect(canonical("https://a\n")).toBe("");
  });

  test("Host values", () => {
    expect(ofHost("https", "app.example:443")).toBe("https://app.example");
    expect(ofHost("https", " [::1]:8443 ")).toBe("https://[::1]:8443");
    expect(ofHost("http", "127.1")).toBe("");
    expect(ofHost("http", "[0::1]")).toBe("");
  });

  test("text", () => {
    expect(trimText(" \t a b \t ")).toBe("a b");
    expect(trimText("\n a \n")).toBe("\n a \n");
    expect(trimText(" \t ")).toBe("");
  });
});

describe("Media-type essence", () => {
  test.each([
    ["Text/Plain; charset=utf-8", "text/plain"],
    [" \tapplication/JSON \t;x", "application/json"],
    ["a;b;c", "a"],
    ["", ""],
    ["\u000bapplication/json", "\u000bapplication/json"],
  ])("%j has essence %j", (input, expected) => {
    expect(essence(input)).toBe(expected);
  });
});
