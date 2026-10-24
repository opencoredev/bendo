import { describe, expect, test } from "bun:test";
import { build, start } from "./harness.ts";

// Literal expectations come from registration order, independently of the router.
const paths: readonly (readonly [string, string])[] = [
  ["/", "Root:0"],
  ["/health", "Health:1"],
  ["/about", "About:2"],
  ["/users/new", "NewUser:3"],
  ["/users/42", "UserInt:4|id=42"],
  ["/users/-7", "UserInt:4|id=-7"],
  ["/users/000", "UserInt:4|id=000"],
  ["/users/alice", "UserName:5|name=alice"],
  ["/users/a%2Fb", "UserName:5|name=a/b"],
  ["/users/%34%32", "UserInt:4|id=42"],
  ["/posts/hello-world", "Post:6|slug=hello-world"],
  ["/posts/ABC", "PostRest:7|rest=ABC"],
  ["/posts/a/b", "PostRest:7|rest=a/b"],
  ["/posts/", "PostRest:7|rest="],
  ["/posts", "PostRest:7|rest="],
  ["/files", "Files:8|path="],
  ["/files/", "Files:8|path="],
  ["/files/a/b", "Files:8|path=a/b"],
  ["/files/a//b/", "Files:8|path=a//b/"],
  ["/files/a%2Fb", "Files:8|path=a/b"],
  ["/opt", "Optional:9"],
  ["/opt/a", "Optional:9|value=a"],
  ["/opt/%F0%9F%98%80", "Optional:9|value=😀"],
  ["/opt/a+b", "Optional:9|value=a+b"],
  ["/opt/%252F", "Optional:9|value=%2F"],
  ["/year/2026", "Year:10|year=2026"],
  ["/year/0000", "Year:10|year=0000"],
  ["/uuid/550e8400-e29b-41d4-a716-446655440000", "Uuid:11|id=550e8400-e29b-41d4-a716-446655440000"],
  ["/pair/a/b", "Pair:12|left=a|right=b"],
  ["/pair/a%2Fb/c%20d", "Pair:12|left=a/b|right=c d"],
  ["/same/x", "First:13|first=x"],
  ["/same/%78", "First:13|first=x"],
  ["/encoded/%252F", "Encoded:15|value=%2F"],
  ["/encoded/%C3%A9", "Encoded:15|value=é"],
  ["/encoded/%2f", "Encoded:15|value=/"],
  ["/static/end", "StaticEnd:16"],
  ["/tail/a/b", "Tail:17|*=a/b"],
  ["/tail", "Tail:17|*="],
  ["/class/abc", "Class:18|value=abc"],
  ["/fallback/a", "Fallback:19|path=a"],
];

// Sixty further distinct paths exercise the overlaps and each decoded assignment.
const numberedPaths = Array.from({ length: 20 }, (_, n): readonly [string, string] => [
  `/users/${n}`,
  `UserInt:4|id=${n}`,
]);
const overlappingPaths = Array.from({ length: 20 }, (_, n): readonly [string, string] => [
  `/same/item${n}`,
  `First:13|first=item${n}`,
]);
const wildcardPaths = Array.from({ length: 20 }, (_, n): readonly [string, string] => [
  `/files/dir${n}/a%20b`,
  `Files:8|path=dir${n}/a b`,
]);

describe("spec router", () => {
  const binary = build("tests/servers/router-spec.bend");

  test("20 app-owned route tags dispatch 100 distinct paths with decoded params", async () => {
    const cases = [...paths, ...numberedPaths, ...overlappingPaths, ...wildcardPaths];
    expect(cases).toHaveLength(100);
    expect(new Set(cases.map(([path]) => path)).size).toBe(100);
    await using server = await start(binary);
    for (const [path, body] of cases) {
      const response = await fetch(`${server.url}${path}`);
      expect(response.status, path).toBe(200);
      expect(await response.text(), path).toBe(body);
    }
  });

  test("misses, rejected constraints, and invalid encodings return no match", async () => {
    await using server = await start(binary);
    for (const path of [
      "/absent",
      "/health/",
      "/opt/",
      "/opt/a/b",
      "/year/123",
      "/year/abcd",
      "/uuid/no",
      "/class/ABC",
      "/encoded/%",
      "/encoded/%C0%AF",
      "/files/%ED%A0%80",
    ]) {
      expect(await (await fetch(`${server.url}${path}`)).text(), path).toBe("miss");
    }
  });
});

const binary = build("tests/router-spec-driver.bend");
test("table construction fails atomically at the original index and preserves tags", () => {
  const result = Bun.spawnSync([binary], { stdout: "pipe", stderr: "pipe" });
  expect(result.exitCode).toBe(0);
  expect(result.stdout.toString().trim().split("\n")).toEqual([
    "ok:0",
    "1:bad:MissingSlash: bad",
    "0:/:x{nope}:UnknownConstraint: nope",
    "0:11,2:33",
    "none",
    "0:parameter:71,2:wildcard:73,0:parameter:71",
  ]);
});
