import { afterAll, expect, test } from "bun:test";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import fixture from "./fixtures/hono-router-cases.json";
import { compile } from "./harness.ts";

const directory = mkdtempSync(join(tmpdir(), "bendo-hono-cases-"));
afterAll(() => {
  rmSync(directory, { recursive: true, force: true });
});

const binary = compile("tests/router-hono-driver.bend", "native");

const decisions = readFileSync(
  new URL("../docs/decisions/0008-router-differences.md", import.meta.url),
  "utf8",
);

test("Hono fixture provenance and every difference remain documented", () => {
  expect(fixture._header.credit).toContain("Hono");
  expect(fixture._header.license).toContain("Permission is hereby granted");
  expect(fixture._header.commit).toMatch(/^[a-f0-9]{40}$/);
  expect(
    fixture.cases.filter(
      ({ origin }) =>
        origin === "verbatim upstream request" ||
        origin === "upstream registration rejection; Bendo probe request added",
    ).length,
  ).toBeGreaterThanOrEqual(150);
  expect(new Set(fixture.cases.map(({ id }) => id)).size).toBe(fixture.cases.length);
  // Repeated executions of Hono's shared tests must not inflate coverage.
  expect(
    new Set(
      fixture.cases.map(({ routes, request, hono, honoError }) =>
        JSON.stringify({
          routes,
          request,
          hono: hono.map(({ handler, params }) => ({
            handler,
            params: [...params].sort(([a], [b]) => (a ?? "").localeCompare(b ?? "")),
          })),
          honoError,
        }),
      ),
    ).size,
  ).toBe(fixture.cases.length);
  for (const entry of fixture.cases) {
    expect(entry.routes.length, entry.id).toBeGreaterThan(0);
    expect(entry.source, entry.id).toStartWith("src/router/");
    expect([
      "verbatim upstream request",
      "upstream registration rejection; Bendo probe request added",
      "ALL method matrix from this upstream registration table",
    ]).toContain(entry.origin);
    if (entry.honoError) {
      expect(entry.honoError, entry.id).toBe("UnsupportedPathError");
      expect(entry.hono, entry.id).toEqual([]);
      expect(entry.differences, entry.id).toContain("registration-rejection");
    }
    expect("gap" in entry || "gapKinds" in entry, entry.id).toBe(false);
    for (const difference of entry.differences) {
      const row = decisions.split("\n").find((line) => line.startsWith(`| ${difference} |`));
      expect(row, `${entry.id}: missing decision group ${difference}`).toBeDefined();
      expect(row, `${entry.id}: not listed in ${difference}`).toContain(entry.id);
    }
  }
});

test("Valid Hono tables exercise both engines; invalid tables assert construction errors", () => {
  const start = performance.now();
  // Bounded native batches amortize startup while keeping failure output small.
  for (let offset = 0; offset < fixture.cases.length; offset += 60) {
    const batch = fixture.cases.slice(offset, offset + 60);
    const file = join(directory, "cases.txt");
    const input = batch
      .map(({ request, routes }) =>
        [
          request.path,
          request.method,
          ...routes.flatMap(({ method, pattern }) => [method, pattern]),
        ]
          .map(encodeURIComponent)
          .join("\t"),
      )
      .join("\n");
    if (Buffer.byteLength(input) >= 33554432) throw new Error("driver input exceeds read bound");
    writeFileSync(file, input);
    const result = Bun.spawnSync([binary, file, "+RTS", "--threads", "1"], {
      stdout: "pipe",
      stderr: "pipe",
      timeout: 15000,
    });
    expect(result.exitCode, result.stderr.toString()).toBe(0);
    const lines = result.stdout.toString().trimEnd().split("\n");
    expect(lines).toHaveLength(batch.length);
    for (const [index, entry] of batch.entries()) {
      const fields = lines[index]?.split("\t");
      const context = JSON.stringify(entry);
      expect(fields, context).toHaveLength(3);
      expect(fields?.[0], `${entry.id} Spec/Trie disagree: ${context}`).toBe(fields?.[1]);
      expect(fields?.[0], `Spec: ${context}`).toBe(entry.expected.path);
      expect(fields?.[1], `Trie: ${context}`).toBe(entry.expected.path);
      expect(fields?.[2], `Methods.resolve: ${context}`).toBe(entry.expected.method);
    }
  }
  const gaps = fixture.cases.filter((entry) => "gap" in entry).length;
  const principled = fixture.cases.filter(
    (entry) => entry.differences.length > 0 && !("gap" in entry),
  ).length;
  const rejected = fixture.cases.filter((entry) => entry.expected.path.startsWith("error:")).length;
  console.log(
    `Hono cases=${fixture.cases.length} identical=${fixture.cases.length - principled - gaps} principled=${principled} gap=${gaps} rejected=${rejected} valid=${fixture.cases.length - rejected} valid_engine_disagreements=0 elapsed_ms=${Math.round(performance.now() - start)}`,
  );
}, 30000);
