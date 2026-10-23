import { afterAll, describe, expect, test } from "bun:test";
import { dirname } from "node:path";
import { rmSync } from "node:fs";
import rawFixtures from "./fixtures/router-patterns.json";
import { build } from "./harness.ts";

type Params = [string, string][];
type Fixture =
  | { kind: "match"; pattern: string; path: string; params: Params }
  | { kind: "miss"; pattern: string; path: string }
  | { kind: "error"; pattern: string; path: string; error: string }
  | { kind: "fill"; pattern: string; params: Params; filled: string }
  | { kind: "inadmissible"; pattern: string; params: Params };

function parseParams(input: unknown): Params {
  if (!Array.isArray(input)) throw new Error("expected params array");
  return input.map((pair: unknown) => {
    if (
      !Array.isArray(pair) ||
      pair.length !== 2 ||
      typeof pair[0] !== "string" ||
      typeof pair[1] !== "string"
    )
      throw new Error("expected name/value pair");
    return [pair[0], pair[1]];
  });
}

function parseFixture(input: unknown): Fixture {
  if (
    typeof input !== "object" ||
    input === null ||
    !("pattern" in input) ||
    typeof input.pattern !== "string" ||
    !("kind" in input)
  )
    throw new Error("invalid fixture");
  const pattern = input.pattern;
  const kind = input.kind;
  if (kind === "fill" || kind === "inadmissible") {
    if (!("params" in input)) throw new Error("missing params");
    const params = parseParams(input.params);
    if (kind === "inadmissible") return { kind, pattern, params };
    if (!("filled" in input) || typeof input.filled !== "string")
      throw new Error("missing filled path");
    return { kind, pattern, params, filled: input.filled };
  }
  if (!("path" in input) || typeof input.path !== "string") throw new Error("missing path");
  const path = input.path;
  if (kind === "match" && "params" in input)
    return { kind, pattern, path, params: parseParams(input.params) };
  if (kind === "miss") return { kind, pattern, path };
  if (kind === "error" && "error" in input && typeof input.error === "string")
    return { kind, pattern, path, error: input.error };
  throw new Error("unknown fixture kind");
}

const fixtures = rawFixtures.map(parseFixture);

function paramsLines(params: Params): string[] {
  return params.map(([name, value]) => `${name}=${value}`);
}

// Decode the driver's transport escaping only. Route decoding runs in Bend.
function decodeLines(lines: string[]): string[] {
  return lines.map((line) => {
    const separator = line.indexOf("=");
    if (separator < 0) return decodeURIComponent(line);
    return `${decodeURIComponent(line.slice(0, separator))}=${decodeURIComponent(line.slice(separator + 1))}`;
  });
}

describe("native Bend route patterns", () => {
  const binary = build("tests/router-pattern-driver.bend");
  afterAll(() => rmSync(dirname(binary), { recursive: true, force: true }));

  function run(pattern: string, args: string[]): string[] {
    const result = Bun.spawnSync([binary, pattern, ...args, "+RTS", "--threads", "1"], {
      stdout: "pipe",
      stderr: "pipe",
      timeout: 5000,
    });
    expect(result.exitCode, result.stderr.toString()).toBe(0);
    const output = result.stdout.toString();
    expect(output.endsWith("\n\n")).toBe(true);
    return output.slice(0, -2).split("\n");
  }

  test("has at least 60 pattern/path fixtures", () => {
    expect(fixtures.filter((fixture) => "path" in fixture).length).toBeGreaterThanOrEqual(60);
  });

  for (const [index, fixture] of fixtures.entries()) {
    test(`${index}: ${fixture.kind} ${fixture.pattern}`, () => {
      switch (fixture.kind) {
        case "match":
          expect(decodeLines(run(fixture.pattern, ["match", fixture.path]))).toEqual([
            "match",
            ...paramsLines(fixture.params),
          ]);
          break;
        case "miss":
          expect(run(fixture.pattern, ["match", fixture.path])).toEqual(["none"]);
          break;
        case "error": {
          const [status, kind, segment] = run(fixture.pattern, ["match", fixture.path]);
          expect(status).toBe("error");
          expect(kind).toBe(fixture.error);
          expect(typeof segment).toBe("string");
          break;
        }
        case "fill":
          expect(decodeLines(run(fixture.pattern, ["fill", ...fixture.params.flat()]))).toEqual([
            "fill",
            fixture.filled,
            "match",
            ...paramsLines(fixture.params),
          ]);
          break;
        case "inadmissible":
          expect(run(fixture.pattern, ["fill", ...fixture.params.flat()])).toEqual([
            "inadmissible",
          ]);
          break;
        default: {
          const exhaustive: never = fixture;
          throw new Error(`unknown fixture: ${exhaustive}`);
        }
      }
    });
  }
});
