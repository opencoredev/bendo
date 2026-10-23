import { afterAll, expect, test } from "bun:test";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { build } from "./harness.ts";

type Case = { patterns: string[]; path: string };
type FilledPattern = { source: string; filled: string };

const SEED = 0xb0162026;
function random(seed: number) {
  let state = seed >>> 0;
  return (limit: number): number => {
    state = (Math.imul(state, 1664525) + 1013904223) >>> 0;
    return state % limit;
  };
}

function choose<T>(next: (limit: number) => number, values: readonly [T, ...T[]]): T {
  return values[next(values.length)] ?? values[0];
}

function generatedPattern(next: (limit: number) => number): FilledPattern {
  const prefix = choose(next, ["", "/a", "/b", "/same", "/a/", "/café", "/%2F"]);
  const encoded = (value: string) =>
    next(2) === 0
      ? encodeURIComponent(value)
      : Array.from(
          new TextEncoder().encode(value),
          (n) => `%${n.toString(16).padStart(2, "0")}`,
        ).join("");
  switch (next(9)) {
    case 0: {
      const source = `${prefix}/${choose(next, ["new", "fixed", "", "a", "%", "%2f", "é"])}`;
      return { source, filled: source };
    }
    case 1:
      return {
        source: `${prefix}/:a`,
        filled: `${prefix}/${encoded(choose(next, ["abc", "é", "a/b", "%2F", "😀", "a+b"]))}`,
      };
    case 2: {
      const suffix = choose(next, ["{int}", "{uuid}", "{slug}", "{[a-z0-9-]+}", "{[0-9]{4}}"]);
      const value =
        suffix === "{uuid}"
          ? "550e8400-e29b-41d4-a716-446655440000"
          : suffix === "{[0-9]{4}}"
            ? "2026"
            : suffix === "{int}"
              ? "-0042"
              : "abc-123";
      return { source: `${prefix}/:a${suffix}`, filled: `${prefix}/${encoded(value)}` };
    }
    case 3:
    case 4: {
      const constraint = next(2) === 0 ? "" : "{int}";
      return {
        source: `${prefix}/:a${constraint}?`,
        filled: next(2) === 0 ? prefix || "/" : `${prefix}/${encoded("42")}`,
      };
    }
    case 5:
    case 6:
      return {
        source: `${prefix}/${next(2) === 0 ? "*" : "*rest"}`,
        filled: choose(next, [
          prefix || "/",
          `${prefix}/`,
          `${prefix}/a//b/`,
          `${prefix}/a%2Fb`,
          `${prefix}/%F0%9F%98%80`,
        ]),
      };
    case 7:
      return {
        source: `${prefix}/:a/:b{int}`,
        filled: `${prefix}/${encoded("left/right")}/${encoded("42")}`,
      };
    default:
      return { source: `${prefix}/:a/end`, filled: `${prefix}/${encoded("x")}/end` };
  }
}

function generatedCases(count: number): Case[] {
  const next = random(SEED);
  return Array.from({ length: count }, () => {
    const routes: FilledPattern[] = [];
    const size = next(60) + 1;
    for (let i = 0; i < size; i++) {
      const prior = routes[next(Math.max(1, routes.length))];
      routes.push(prior && next(5) === 0 ? prior : generatedPattern(next));
    }
    const selected = routes[next(routes.length)];
    if (!selected) throw new Error("generator produced no routes");
    let path = selected.filled;
    const mode = next(10);
    if (mode === 0) path = `${path}/extra`;
    if (mode === 1)
      path = `${path.slice(0, Math.max(0, path.lastIndexOf("/")))}/${choose(next, ["%", "%GG", "%C0%AF", "%ED%A0%80", "%F4%90%80%80", "%2", "%00"])}`;
    if (mode === 2)
      path = choose(next, [
        "",
        "missing-slash",
        "/",
        "//",
        "/missing",
        "/a/",
        "/same/%252F",
        "/a/%34%32",
      ]);
    if (mode === 3) path = path.slice(next(path.length + 1));
    return { patterns: routes.map((route) => route.source), path };
  });
}

const binary = build("tests/router-trie-driver.bend");
const directory = mkdtempSync(join(tmpdir(), "bendo-trie-cases-"));
afterAll(() => {
  rmSync(directory, { recursive: true, force: true });
});

function run(cases: Case[]): string[][] {
  const file = join(directory, "cases.txt");
  const text = cases
    .map(({ path, patterns }) => [path, ...patterns].map(encodeURIComponent).join("\t"))
    .join("\n");
  if (Buffer.byteLength(text) >= 33554432) throw new Error("driver input exceeds read bound");
  writeFileSync(file, text);
  const result = Bun.spawnSync([binary, file, "+RTS", "--threads", "1"], {
    stdout: "pipe",
    stderr: "pipe",
    timeout: 15000,
  });
  expect(result.exitCode, result.stderr.toString()).toBe(0);
  const [header, ...lines] = result.stdout.toString().trimEnd().split("\n");
  expect(header).toBe("default=Spec");
  expect(lines).toHaveLength(cases.length);
  return lines.map((line) => {
    const fields = line.split("\t");
    expect(fields).toHaveLength(4);
    return fields;
  });
}

function disagrees(fields: string[]): boolean {
  return fields.some((field) => field !== fields[0]);
}

// Bounded deletion reduction keeps only changes that reproduce the disagreement.
function minimize(input: Case): Case {
  let current = input;
  let budget = 120;
  const fails = (candidate: Case) => budget-- > 0 && run([candidate]).some(disagrees);
  for (
    let width = Math.ceil(current.patterns.length / 2);
    width >= 1;
    width = Math.floor(width / 2)
  ) {
    for (let offset = 0; offset < current.patterns.length && budget > 0;) {
      const candidate = {
        ...current,
        patterns: current.patterns.filter((_, i) => i < offset || i >= offset + width),
      };
      if (fails(candidate)) current = candidate;
      else offset += width;
    }
  }
  for (let width = Math.ceil(current.path.length / 2); width >= 1; width = Math.floor(width / 2)) {
    for (let offset = 0; offset < current.path.length && budget > 0;) {
      const candidate = {
        ...current,
        path: current.path.slice(0, offset) + current.path.slice(offset + width),
      };
      if (fails(candidate)) current = candidate;
      else offset += width;
    }
  }
  return current;
}

test("trie and Spec-default config preserve first registration, tags, and decoded params", () => {
  const cases: (Case & { expected: string })[] = [
    { patterns: [], path: "/", expected: "none" },
    { patterns: ["/"], path: "/", expected: "0:1000" },
    {
      patterns: ["/files/*rest", "/files/new"],
      path: "/files/new",
      expected: "0:1000|%72%65%73%74=%6E%65%77",
    },
    { patterns: ["/files/new", "/files/*rest"], path: "/files/new", expected: "0:1000" },
    { patterns: ["/files/new", "/files/*rest"], path: "/files", expected: "1:1017|%72%65%73%74=" },
    { patterns: ["/files/*rest"], path: "/filesXYZ", expected: "none" },
    { patterns: ["/same/:a", "/same/:b"], path: "/same/%252F", expected: "0:1000|%61=%25%32%46" },
    { patterns: ["/a/:n{int}", "/a/:x"], path: "/a/%34%32", expected: "0:1000|%6E=%34%32" },
    { patterns: ["/a/:n{int}", "/a/:x"], path: "/a/abc", expected: "1:1017|%78=%61%62%63" },
    { patterns: ["/:id?"], path: "/", expected: "0:1000" },
    { patterns: ["//:id?"], path: "/", expected: "0:1000" },
    { patterns: ["/a//:id?"], path: "/a/", expected: "0:1000" },
    { patterns: ["/a/", "/a"], path: "/a", expected: "1:1017" },
    { patterns: ["/%2F", "/:id"], path: "/%2F", expected: "0:1000" },
    { patterns: ["/a/*rest", "/a/%"], path: "/a/%", expected: "1:1017" },
  ];
  for (const [i, fields] of run(cases).entries()) {
    expect(fields, JSON.stringify(cases[i])).toEqual(Array(4).fill(cases[i]?.expected));
  }
});

test("10,000 seeded generated table/path pairs have no disagreements", () => {
  const cases = generatedCases(10000);
  const start = performance.now();
  for (let offset = 0; offset < cases.length; offset += 250) {
    const batch = cases.slice(offset, offset + 250);
    for (const [index, fields] of run(batch).entries()) {
      const input = batch[index];
      if (input && disagrees(fields)) {
        throw new Error(
          JSON.stringify(
            {
              seed: SEED,
              pair: offset + index,
              input,
              results: fields,
              minimized: minimize(input),
            },
            null,
            2,
          ),
        );
      }
    }
  }
  console.log(
    `seed=0x${SEED.toString(16)} pairs=${cases.length} disagreements=0 elapsed_ms=${Math.round(performance.now() - start)}`,
  );
}, 60000);
