import { expect, test } from "bun:test";
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { allLaws, lawFiles } from "../scripts/laws-index.ts";

// docs/laws explains every law in LAWS.bend and the law modules it imports.
// An entry is a list item that opens with one or more backticked law names
// and a colon: "- `name`: ..." or "- `a`, `b`, `c`: ...".

const docsDir = join(import.meta.dir, "..", "docs", "laws");
const entryNames = /^(`[a-z0-9_]+`(?:, `[a-z0-9_]+`)*):/;
const snakeMention = /`([a-z][a-z0-9]*(?:_[a-z0-9]+)+)`/g;

type Page = { readonly file: string; readonly text: string };

function pages(): Page[] {
  return readdirSync(docsDir)
    .filter((file) => file.endsWith(".md"))
    .sort()
    .map((file) => ({ file, text: readFileSync(join(docsDir, file), "utf8") }));
}

function listItems(text: string): string[] {
  const items: string[] = [];
  for (const line of text.split("\n")) {
    if (line.startsWith("- ")) items.push(line.slice(2));
    else if (line.startsWith("  ") && items.length > 0 && line.trim() !== "")
      items[items.length - 1] += ` ${line.trim()}`;
  }
  return items;
}

function entries(): { readonly name: string; readonly file: string }[] {
  return pages().flatMap(({ file, text }) =>
    listItems(text).flatMap((item) => {
      const names = entryNames.exec(item)?.[1];
      if (names === undefined) return [];
      return names.split(", ").map((name) => ({ name: name.slice(1, -1), file }));
    }),
  );
}

const laws = allLaws();
const lawNames = new Set(laws.map((law) => law.name));

test("the law index follows LAWS.bend imports and finds the stated laws", () => {
  expect(lawFiles()[0]).toBe("LAWS.bend");
  expect(lawFiles()).toContain("proof/ws-session-laws.bend");
  expect(laws.length).toBeGreaterThan(500);
  expect(lawNames.size).toBe(laws.length);
});

test("every law has an entry in docs/laws", () => {
  const documented = new Set(entries().map((entry) => entry.name));
  const missing = laws
    .filter((law) => !documented.has(law.name))
    .map((law) => `${law.name} (${law.file}:${law.line})`);
  expect(missing).toEqual([]);
});

test("every docs/laws entry names a current law, once", () => {
  const all = entries();
  const unknown = all
    .filter((entry) => !lawNames.has(entry.name))
    .map((e) => `${e.name} (${e.file})`);
  expect(unknown).toEqual([]);
  const seen = new Map<string, string>();
  const repeated = all.flatMap((entry) => {
    const earlier = seen.get(entry.name);
    seen.set(entry.name, entry.file);
    return earlier === undefined ? [] : [`${entry.name} (${earlier}, ${entry.file})`];
  });
  expect(repeated).toEqual([]);
});

test("docs/laws mentions no law name that no longer exists", () => {
  const stale = pages().flatMap(({ file, text }) =>
    Array.from(text.matchAll(snakeMention), (match) => match[1] ?? "")
      .filter((name) => !lawNames.has(name))
      .map((name) => `${name} (${file})`),
  );
  expect([...new Set(stale)]).toEqual([]);
});
