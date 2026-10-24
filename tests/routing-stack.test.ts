// BND-84: every request-path helper in the router and the static resolver
// handles 65536-character input on both targets. Before BND-84 each of these
// overflowed the JavaScript stack in the .mjs build.
import { compile, SLOW_TEST_TIMEOUT_MS } from "./harness.ts";
import { describe, expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { pathToFileURL } from "node:url";

const N = 65536;
const HALF = N / 2;
const a = "a".repeat(N);
const slashed = "a/".repeat(HALF);

const output = compile("tests/fixtures/routing-stack/consumer.bend", "mjs");
const nativeOutput = compile("tests/fixtures/routing-stack/native.bend", "native");

// The generated module has no TS declarations. Validate each export and each
// result at this boundary; every export renders its result as a string.
const module: unknown = await import(pathToFileURL(output).href);
if (typeof module !== "object" || module === null || !("default" in module)) {
  throw new Error("Missing compiled Bend default export");
}
const exports: unknown = module.default;
function exported(name: string): (...args: string[]) => string {
  if (typeof exports !== "object" || exports === null || !(name in exports)) {
    throw new Error(`Missing Bend export: ${name}`);
  }
  const fn: unknown = Reflect.get(exports, name);
  if (typeof fn !== "function") throw new Error(`Bend export is not callable: ${name}`);
  return (...args) => {
    const result: unknown = fn(...args);
    if (typeof result !== "string")
      throw new Error(`Bend export ${name} returned ${typeof result}`);
    return result;
  };
}
const encode = exported("encode");
const decode = exported("decode");
const scalars = exported("scalars");
const digits = exported("digits");
const slug = exported("slug");
const uuid = exported("uuid");
const letters = exported("letters");
const segments = exported("segments");
const wildcard = exported("wildcard");
const route = exported("route");
const routeOptions = exported("route_options");
const resolve = exported("resolve");

function native(mode: string, count: number): string {
  const result = Bun.spawnSync(
    ["timeout", "--foreground", "30s", nativeOutput, mode, String(count)],
    {
      stdout: "pipe",
      stderr: "pipe",
    },
  );
  expect(result.exitCode).toBe(0);
  // IO.print appends exactly one protocol newline.
  const text = result.stdout.toString();
  expect(text.endsWith("\n")).toBe(true);
  return text.slice(0, -1);
}

describe("request-path helpers at 65536 characters (.mjs)", () => {
  test(
    "percent codec",
    () => {
      expect(encode("é".repeat(N))).toBe("%C3%A9".repeat(N));
      expect(decode("%41".repeat(N))).toBe(`some:${"A".repeat(N)}`);
      expect(decode(a)).toBe(`some:${a}`);
      expect(decode(`${a}%zz`)).toBe("none");
      expect(scalars(a)).toBe("true");
    },
    SLOW_TEST_TIMEOUT_MS,
  );

  test(
    "capture constraints",
    () => {
      expect(digits("1".repeat(N))).toBe("true");
      expect(digits(`${"1".repeat(N)}x`)).toBe("false");
      expect(slug(a)).toBe("true");
      expect(uuid(a)).toBe("false");
      expect(letters(a)).toBe("true");
      expect(letters(`${a}A`)).toBe("false");
    },
    SLOW_TEST_TIMEOUT_MS,
  );

  test(
    "path splitting and wildcard decoding",
    () => {
      expect(segments(slashed)).toBe(String(HALF + 1));
      expect(wildcard(slashed)).toBe(`some:${slashed}`);
      expect(wildcard(`${slashed}%zz`)).toBe("none");
    },
    SLOW_TEST_TIMEOUT_MS,
  );

  test(
    "matching",
    () => {
      expect(route("/:id", `/${a}`)).toBe(`match:id=${a}`);
      expect(route("/:id{int}", `/${"1".repeat(N)}`)).toBe(`match:id=${"1".repeat(N)}`);
      expect(route("/:id{uuid}", `/${a}`)).toBe("none");
      expect(route("/:id{slug}", `/${a}`)).toBe(`match:id=${a}`);
      expect(route("/:id{[a-z]+}", `/${a}`)).toBe(`match:id=${a}`);
      expect(route("/:id{[a-z]{3}}", `/${a}`)).toBe("none");
      expect(route("/*", `/${slashed}`)).toBe(`match:*=${slashed}`);
      expect(route("/*rest", `/${slashed}`)).toBe(`match:rest=${slashed}`);
      expect(route("/*/x", `/${slashed}x`)).toBe("match:");
      expect(route("/*/x", `/${slashed}`)).toBe("none");
      expect(route("/a*", `/${slashed}`)).toBe("match:");
      expect(route("/:p{.+}/x", `/${slashed}x`)).toBe(`match:p=${slashed.slice(0, -1)}`);
      expect(route("/x", `/${a}`)).toBe("none");
      expect(route("/x", `/${slashed}`)).toBe("none");
    },
    SLOW_TEST_TIMEOUT_MS,
  );

  test(
    "non-default routing options preserve dense paths",
    () => {
      expect(routeOptions("/*rest", `/${slashed}`)).toBe(`match:rest=${slashed.slice(0, -1)}`);
      expect(routeOptions("/ABC/:id", `/abc/${a}`)).toBe(`match:id=${a}`);
    },
    SLOW_TEST_TIMEOUT_MS,
  );

  test(
    "static resolution stays confined",
    () => {
      expect(resolve(`/${slashed}b`)).toBe(`some:${slashed}b`);
      expect(resolve(`/${"%61".repeat(HALF)}`)).toBe(`some:${"a".repeat(HALF)}`);
      expect(resolve(`/${slashed}`)).toBe(`some:${slashed}index.html`);
      expect(resolve(`/${slashed}..`)).toBe("none");
      expect(resolve(`/${slashed}a%2Fb`)).toBe("none");
      expect(resolve(`/${slashed}.env`)).toBe("none");
    },
    SLOW_TEST_TIMEOUT_MS,
  );
});

describe("request-path helpers at 65536 characters (native)", () => {
  test("percent codec and constraints", () => {
    expect(native("encode", N)).toBe("%C3%A9".repeat(N));
    expect(native("decode", N)).toBe(`some:${"A".repeat(N)}`);
    expect(native("scalars", N)).toBe("true");
    expect(native("digits", N)).toBe("true");
    expect(native("slug", N)).toBe("true");
    expect(native("uuid", N)).toBe("false");
    expect(native("letters", N)).toBe("true");
  });

  test("splitting, matching and static resolution", () => {
    expect(native("segments", HALF)).toBe(String(HALF + 1));
    expect(native("wildcard", HALF)).toBe(`some:${slashed}`);
    expect(native("capture", N)).toBe(`match:id=${a}`);
    expect(native("int", N)).toBe(`match:id=${"1".repeat(N)}`);
    expect(native("named-wildcard", HALF)).toBe(`match:rest=${slashed}`);
    expect(native("options", HALF)).toBe(`match:rest=${slashed.slice(0, -1)}`);
    expect(native("interior-wildcard", HALF)).toBe("match:");
    expect(native("span", HALF)).toBe(`match:p=${slashed.slice(0, -1)}`);
    expect(native("resolve", HALF)).toBe(`some:${slashed}b`);
    expect(native("resolve-escaped", HALF)).toBe(`some:${"a".repeat(HALF)}`);
  });
});

// Each rewritten helper must compile to a loop that never calls itself.
// Names are module-qualified in the bundle, e.g. `$__src_router_encoding_encode_go`.
describe("emitted .mjs loops", () => {
  const source = readFileSync(output, "utf8");
  const loops = [
    "src_router_utf8_code_run",
    "src_router_encoding_scalars_go",
    "src_router_encoding_encode_go",
    "src_router_encoding_unescape_go",
    "src_router_constraint_digits_go",
    "src_router_constraint_slug_go",
    "src_router_constraint_uuid_go",
    "src_router_constraint_class_chars_go",
    "src_router_pattern_join_rev",
    "src_router_pattern_decoded_go",
    "src_router_pattern_empty_rows_go",
    "src_router_pattern_span_candidates",
    "src_router_pattern_span_pick",
    "src_router_pattern_rows_plan",
    "src_router_pattern_rows_build",
    "src_http_text_split_go",
    "src_http_text_join_rev_go",
    "src_static_path_chars_go",
    "src_static_path_segments_go",
    "src_static_path_slashes_go",
    "src_static_path_count_go",
    "src_static_path_join_go",
    "src_static_path_plain_go",
    "src_static_path_decode_go_loop",
  ];
  for (const loop of loops) {
    test(loop, () => {
      // A template instance carries a numeric suffix, such as rows_plan_0.
      const header = new RegExp(`^function (\\$_+${loop}(?:_\\d+)?)\\(`, "m");
      const found = header.exec(source);
      expect(found).not.toBeNull();
      const name = found?.[1] ?? "";
      const start = found?.index ?? 0;
      const end = source.indexOf("\n}\n", start);
      const body = source.slice(source.indexOf("{", start), end);
      expect(body).toContain("for (;;)");
      expect(body.includes(`${name}(`)).toBe(false);
    });
  }
});
