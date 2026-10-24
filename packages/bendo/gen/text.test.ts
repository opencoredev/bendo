import { expect, test } from "bun:test";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { build, start } from "../../../tests/harness.ts";
import { fetchManifest } from "../src/manifest.ts";
import { emitRouteTypes } from "../src/route-types.ts";

const binary = build("tests/fixtures/gen-text/app.bend");
const repo = resolve(import.meta.dir, "../../..");

test("generated text inputs survive client serialization and native route validation", async () => {
  const directory = mkdtempSync(join(tmpdir(), "bendo-gen-text-"));
  try {
    writeFileSync(join(directory, "routes.ts"), emitRouteTypes(fetchManifest(binary)));
    writeFileSync(
      join(directory, "consumer.ts"),
      readFileSync(join(import.meta.dir, "text-consumer.ts.txt")),
    );
    const checked = Bun.spawnSync(
      [
        process.execPath,
        join(repo, "node_modules/typescript/bin/tsc"),
        "--strict",
        "--exactOptionalPropertyTypes",
        "--noEmit",
        "--skipLibCheck",
        "--target",
        "ES2023",
        "--module",
        "Preserve",
        "--moduleResolution",
        "bundler",
        join(directory, "consumer.ts"),
      ],
      { stdout: "pipe", stderr: "pipe", timeout: 20_000 },
    );
    expect(`${checked.stdout}${checked.stderr}`).toBe("");
    expect(checked.exitCode).toBe(0);
    // Execute the same consumer that tsc checked, keeping the generated type at
    // the serialization boundary rather than duplicating it in the test.
    const consumer = await import(join(directory, "consumer.ts"));
    await using server = await start(binary);
    expect(consumer.requests).toHaveLength(2);
    for (const input of consumer.requests) {
      const query = new URLSearchParams(input.query);
      const response = await fetch(`${server.url}${input.path}?${query}`, {
        headers: input.headers,
      });
      expect(response.status).toBe(200);
      expect(await response.json()).toEqual({
        params: { id: "word" },
        query: {
          choice: "word",
          enum: "one",
          literal: "yes",
          integer: 10,
          number: 1.5,
          boolean: query.get("boolean") === "true",
          ...(query.has("nullable") ? { nullable: 12 } : {}),
          ...(query.has("tags") ? { tags: query.getAll("tags") } : {}),
          ids: query.getAll("ids").map(Number),
          limits: query.has("limits") ? query.getAll("limits").map(Number) : [7],
        },
        headers: { "x-choice": "word", "x-enum": "one", "x-literal": "yes" },
      });
      for (const [key, value] of [
        ["choice", "10"],
        ["choice", "true"],
        ["enum", "1"],
        ["enum", "true"],
        ["numeric-enum", "1"],
        ["numeric-literal", "1"],
        ["boolean-literal", "true"],
        ["numeric-union", "10"],
        ["nullable", "null"],
        ["tags", "10"],
        ["ids", "x"],
      ] satisfies [string, string][]) {
        const invalid = new URLSearchParams(query);
        invalid.delete(key);
        invalid.append(key, value);
        const rejected = await fetch(`${server.url}/text/word?${invalid}`, {
          headers: input.headers,
        });
        expect(rejected.status).toBe(422);
        await rejected.arrayBuffer();
      }
      // An empty array would serialize to no key; the required field then fails.
      const missing = new URLSearchParams(query);
      missing.delete("ids");
      const absent = await fetch(`${server.url}/text/word?${missing}`, {
        headers: input.headers,
      });
      expect(absent.status).toBe(422);
      await absent.arrayBuffer();
    }
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
}, 60_000);
