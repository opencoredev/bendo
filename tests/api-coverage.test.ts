import { expect, test } from "bun:test";
import {
  bendPublicApi,
  checkTsExamples,
  coverageProblems,
  referencePages,
  tsPublicApi,
  writeBendPrograms,
  type Page,
  type PublicApi,
} from "../scripts/api-coverage.ts";
import { compile } from "./harness.ts";

// docs/api is the API reference. Every public API needs an entry, every entry
// must name a public API, and every example on the pages must compile (Bend)
// or typecheck (TypeScript). docs/api/index.md describes the rules.

const bend = bendPublicApi();
const typescript = tsPublicApi();

test("the public API is main.bend, the companion names and the package exports", () => {
  const keys = new Set([...bend, ...typescript].map((item) => item.key));
  for (const key of ["B.serve", "B.get", "J.Json", "S.Schema", "C.header", "V.serve"])
    expect(keys).toContain(key);
  for (const key of [
    "bendo/client:createClient",
    "bendo/query:queryOptions",
    "vite-plugin-bendo:default",
  ])
    expect(keys).toContain(key);
  // Internals reached only through main.bend stay private.
  expect(keys).not.toContain("J.parse_go");
  expect(bend.filter((item) => item.key.startsWith("B.")).length).toBeGreaterThan(250);
  expect(typescript.length).toBeGreaterThan(70);
});

test("the check reports missing entries, unknown names and entries without examples", () => {
  const api: PublicApi[] = [
    { key: "B.text", language: "bend", source: "test" },
    { key: "B.html", language: "bend", source: "test" },
  ];
  const page: Page = {
    page: "docs/api/bend/test.md",
    language: "bend",
    module: undefined,
    text: [
      "### `B.text`",
      "```bend",
      "def ex(c: B.Ctx) -> B.Res:",
      "  B.json(c, J.JNull{})",
      "```",
      "### `B.nope`",
    ].join("\n"),
  };
  expect(coverageProblems([page], api)).toEqual([
    "no entry for B.html (test)",
    "docs/api/bend/test.md:1: no example under this entry uses B.text",
    "docs/api/bend/test.md:6: B.nope is not a public API",
    "docs/api/bend/test.md:6: B.nope has no example",
  ]);
});

test("fences follow CommonMark, and comments and strings do not count as uses", () => {
  const api: PublicApi[] = [
    { key: "B.text", language: "bend", source: "test" },
    { key: "B.html", language: "bend", source: "test" },
  ];
  const text = [
    "### `B.text`",
    "  ```bend",
    "  # B.text",
    '  def ex() -> String: "B.text"',
    "  ```",
    "````md",
    "```bend",
    "### `B.ghost`",
    "```",
    "````",
    "### `B.html` (old)",
  ].join("\n");
  const page: Page = { page: "docs/api/bend/t.md", language: "bend", module: undefined, text };
  expect(coverageProblems([page], api)).toEqual([
    "docs/api/bend/t.md:11: malformed entry heading: `B.html` (old)",
    "no entry for B.html (test)",
    "docs/api/bend/t.md:1: no example under this entry uses B.text",
  ]);
});

test("a TypeScript default export is used through a default import", () => {
  const api: PublicApi[] = [{ key: "vite-plugin-bendo:default", language: "ts", source: "test" }];
  const page = (code: string): Page => ({
    page: "docs/api/ts/t.md",
    language: "ts",
    module: "vite-plugin-bendo",
    text: ["### `default`", "```ts", code, "```"].join("\n"),
  });
  expect(coverageProblems([page("import bendo from 'vite-plugin-bendo';\nbendo();")], api)).toEqual(
    [],
  );
  expect(
    coverageProblems([page('import { locate } from "vite-plugin-bendo"; // default')], api),
  ).toEqual(["docs/api/ts/t.md:1: no example under this entry uses default"]);
});

test("a TypeScript use must import the export from the page's module", () => {
  const api: PublicApi[] = [{ key: "bendo/client:createClient", language: "ts", source: "test" }];
  const page = (code: string): Page => ({
    page: "docs/api/ts/t.md",
    language: "ts",
    module: "bendo/client",
    text: ["### `createClient`", "```ts", code, "```"].join("\n"),
  });
  const unused = ["docs/api/ts/t.md:1: no example under this entry uses createClient"];
  expect(coverageProblems([page("const createClient = 1;")], api)).toEqual(unused);
  expect(coverageProblems([page('import { createClient } from "bendo/query";')], api)).toEqual(
    unused,
  );
  expect(
    coverageProblems([page('import { createClient as make } from "bendo/client";')], api),
  ).toEqual([]);
  expect(
    coverageProblems(
      [page('import * as client from "bendo/client";\nclient.createClient("/");')],
      api,
    ),
  ).toEqual([]);
});

test("a fence inside a blockquote or list is reported, not skipped", () => {
  const api: PublicApi[] = [{ key: "B.text", language: "bend", source: "test" }];
  const text = [
    "### `B.text`",
    "```bend",
    'def ex(c: B.Ctx) -> B.Res: B.text(c, "")',
    "```",
    "> ```bend",
    '> def broken() -> U32: "x"',
    "> ```",
  ].join("\n");
  const page: Page = { page: "docs/api/bend/t.md", language: "bend", module: undefined, text };
  expect(coverageProblems([page], api)).toEqual([
    "docs/api/bend/t.md:5: a fence inside a blockquote, list or indented block is not checked; move it to the top level",
    "docs/api/bend/t.md:7: a fence inside a blockquote, list or indented block is not checked; move it to the top level",
  ]);
});

test("every public API has a reference entry with an example, and every entry names one", () => {
  expect(coverageProblems()).toEqual([]);
});

test("TypeScript examples typecheck", () => {
  const { files, problems } = checkTsExamples();
  expect(problems).toEqual([]);
  expect(files).toBeGreaterThan(0);
}, 120_000);

// One program per page keeps the Bend cost to one cached compile per page.
for (const program of writeBendPrograms(referencePages())) {
  test(`Bend examples compile: ${program.page}`, () => {
    expect(compile(program.file, "c")).toEndWith(".c");
  }, 400_000);
}
