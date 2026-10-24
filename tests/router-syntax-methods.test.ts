import { expect, test } from "bun:test";
import { build } from "./harness.ts";

const binary = build("tests/router-syntax-methods-driver.bend");
const cases = [
  { pattern: "/Assets*", path: "/ASSETS-v2", expected: "found" },
  { pattern: "/A/*/End/:id", path: "/a/Some/END/MiXeD", expected: "found|id=MiXeD" },
  {
    pattern: "/:prefix{.+}/Contents/:id?",
    path: "/MiXeD/Path/CONTENTS/AbC",
    expected: "found|prefix=MiXeD/Path|id=AbC",
  },
  { pattern: "/V1/:a?/:b?", path: "/v1/MiXeD", expected: "found|a=MiXeD" },
  { pattern: "/Name:Activate", path: "/NAME:ACTIVATE", expected: "found" },
];

function run(
  pattern: string,
  path: string,
  strict: boolean,
  sensitive: boolean,
  method = "GET",
  all = false,
) {
  const result = Bun.spawnSync(
    [
      binary,
      pattern,
      path,
      method,
      String(strict),
      String(sensitive),
      all ? "all" : "get",
      "+RTS",
      "--threads",
      "1",
    ],
    { stdout: "pipe", stderr: "pipe", timeout: 5000 },
  );
  expect(result.exitCode, result.stderr.toString()).toBe(0);
  return result.stdout.toString().trimEnd().split("\t").map(decodeURIComponent);
}

for (const entry of cases) {
  test(`case options preserve captures in ${entry.pattern} on both engines`, () => {
    expect(run(entry.pattern, entry.path, true, false)).toEqual([entry.expected, entry.expected]);
    expect(run(entry.pattern, `${entry.path}/`, false, false)).toEqual([
      entry.expected,
      entry.expected,
    ]);
    expect(run(entry.pattern, entry.path, true, true)).toEqual(["404", "404"]);
  });
}

test("ALL accepts extension methods on extended patterns and finite Allow stays exact", () => {
  expect(run("/Assets*", "/ASSETS-v2", true, false, "PURGE", true)).toEqual(["found", "found"]);
  expect(run("/A/*/End/:id", "/a/x/END/MiXeD", true, false, "PURGE")).toEqual([
    "405:GET, HEAD",
    "405:GET, HEAD",
  ]);
});
