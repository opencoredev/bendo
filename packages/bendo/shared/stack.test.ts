// BND-58: every pure helper the shared schema/validator path reaches stays
// stack safe in the `.mjs` build on 64 KiB inputs, on Bun's and Node's
// default stacks (docs/shared.md). The module comes from the real
// `bendo build --shared` pipeline, named exports included.
import { afterAll, expect, test } from "bun:test";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { SLOW_TEST_TIMEOUT_MS } from "../../../tests/harness.ts";
import { buildSharedModule } from "../src/shared.ts";

const here = import.meta.dir;
const out = mkdtempSync(join(tmpdir(), "bendo-shared-stack-"));
afterAll(() => rmSync(out, { recursive: true, force: true }));
const built = await buildSharedModule(join(here, "fixtures/stack/stack.bend"), out);
const imported: unknown = await import(pathToFileURL(built.module).href);
if (typeof imported !== "object" || imported === null || !("probe" in imported))
  throw new Error("The shared build has no named probe export");
const exported: unknown = imported.probe;
if (typeof exported !== "function") throw new Error("probe is not a function");
const probe = (kind: string, schema: string, input: string): unknown =>
  exported(kind, schema, input);

const N = 64 * 1024;
const quoted = (s: string): string => JSON.stringify(s);
const repeat = (part: string, total: number): string =>
  part.repeat(Math.floor(total / part.length));
/** A JSON array or object of about N bytes. */
const array = (item: string): string =>
  `[${Array(Math.floor((N - 2) / (item.length + 1)))
    .fill(item)
    .join(",")}]`;
const object = (member: string): string =>
  `{${Array(Math.floor((N - 2) / (member.length + 1)))
    .fill(member)
    .join(",")}}`;
/** About N bytes of UTF-8: each "é😀" is six bytes. */
const multibyte = repeat("é😀", N / 2);
const longKey = `{"${"k".repeat(N - 8)}":1}`;
const deep = `${"[".repeat(512)}${"]".repeat(512)}`;

type Vector = { name: string; kind: string; schema: string; input: string; expected: string };
const vectors: Vector[] = [
  {
    name: "long string",
    kind: "decode",
    schema: "string",
    input: quoted("a".repeat(N - 2)),
    expected: "ok",
  },
  {
    name: "multibyte string",
    kind: "decode",
    schema: "string",
    input: quoted(multibyte),
    expected: "ok",
  },
  {
    name: "Unicode escapes",
    kind: "decode",
    schema: "string",
    input: `"${repeat("\\u00e9", N - 2)}"`,
    expected: "ok",
  },
  {
    name: "pattern accepts",
    kind: "decode",
    schema: "pattern",
    input: quoted("a".repeat(N - 2)),
    expected: "ok",
  },
  {
    name: "pattern rejects the last scalar",
    kind: "decode",
    schema: "pattern",
    input: quoted(`${"a".repeat(N - 3)}1`),
    expected: "fail:1",
  },
  {
    name: "email with a long dotted local part",
    kind: "decode",
    schema: "email",
    input: quoted(`${repeat("a.", N - 8)}a@b.co`),
    expected: "fail:1",
  },
  {
    name: "email with many domain labels",
    kind: "decode",
    schema: "email",
    input: quoted(`a@${repeat("b.", N - 8)}co`),
    expected: "fail:1",
  },
  {
    name: "URL with many labels and segments",
    kind: "decode",
    schema: "url",
    input: quoted(`https://${repeat("a.", N / 2)}com/${repeat("x/", N / 2 - 16)}`),
    expected: "fail:1",
  },
  {
    name: "maximum length",
    kind: "decode",
    schema: "bounded",
    input: quoted("a".repeat(N - 2)),
    expected: "fail:1",
  },
  {
    name: "long integer with a bound",
    kind: "decode",
    schema: "integer",
    input: "9".repeat(N),
    expected: "ok",
  },
  {
    name: "many array items",
    kind: "decode",
    schema: "numbers",
    input: array("1"),
    expected: "ok",
  },
  {
    name: "many failing items, capped",
    kind: "decode",
    schema: "strings",
    input: array("1"),
    expected: "fail:100",
  },
  {
    name: "many undeclared keys, strict",
    kind: "decode",
    schema: "strict",
    input: object('"z":1'),
    expected: "fail:100",
  },
  {
    name: "many undeclared keys, stripped",
    kind: "decode",
    schema: "strip",
    input: object('"z":1').replace("{", '{"a":1,'),
    expected: "ok",
  },
  {
    name: "many duplicate keys",
    kind: "decode",
    schema: "strict",
    input: object('"a":1'),
    expected: "fail:1",
  },
  {
    name: "many failing records",
    kind: "decode",
    schema: "records",
    input: array('{"a":1}'),
    expected: "fail:100",
  },
  {
    name: "union over a long array",
    kind: "decode",
    schema: "union",
    input: array("1"),
    expected: "ok",
  },
  {
    name: "nullable long array",
    kind: "decode",
    schema: "nullable",
    input: array("1"),
    expected: "ok",
  },
  {
    name: "one long undeclared key",
    kind: "decode",
    schema: "any-key",
    input: longKey,
    expected: "ok",
  },
  {
    name: "deepest accepted nesting",
    kind: "decode",
    schema: "numbers",
    input: deep,
    expected: "fail:1",
  },
  {
    name: "text source gathers a repeated key",
    kind: "text",
    schema: "ids",
    input: object('"ids":"7"'),
    expected: "ok",
  },
  {
    name: "decoded value back to JSON",
    kind: "report",
    schema: "numbers",
    input: array("1"),
    expected: array("1"),
  },
  {
    name: "error report for capped errors",
    kind: "report",
    schema: "strings",
    input: array("1"),
    expected: "7691",
  },
  {
    name: "error report with a long key path",
    kind: "report",
    schema: "strict",
    input: longKey,
    expected: "65672",
  },
  {
    name: "parse and stringify escapes",
    kind: "roundtrip",
    schema: "",
    input: quoted(repeat('é"\n', N - 2)),
    expected: quoted(repeat('é"\n', N - 2)),
  },
  {
    name: "parse and stringify an array",
    kind: "roundtrip",
    schema: "",
    input: array("1"),
    expected: array("1"),
  },
  {
    name: "parse and stringify an object",
    kind: "roundtrip",
    schema: "",
    input: object('"a":0'),
    expected: object('"a":0'),
  },
  {
    name: "parse and stringify the deepest nesting",
    kind: "roundtrip",
    schema: "",
    input: deep,
    expected: deep,
  },
  {
    name: "pretty writer",
    kind: "pretty",
    schema: "",
    input: array("1"),
    expected: String(JSON.stringify(JSON.parse(array("1")), null, 2).length),
  },
  {
    name: "UTF-8 bytes to ASCII-escaped JSON",
    kind: "bytes",
    schema: "",
    input: quoted(repeat("é", N / 2)),
    expected: `"${"\\u00e9".repeat(N / 2)}"`,
  },
  {
    name: "UTF-8 encode and decode",
    kind: "utf8",
    schema: "",
    input: multibyte,
    expected: multibyte,
  },
  { name: "UTF-8 scalar check", kind: "valid", schema: "", input: multibyte, expected: "true" },
  {
    name: "automaton matcher accepts",
    kind: "matches",
    schema: "",
    input: "a".repeat(N),
    expected: "true",
  },
  {
    name: "automaton matcher rejects the last scalar",
    kind: "matches",
    schema: "",
    input: `${"a".repeat(N - 1)}1`,
    expected: "false",
  },
  {
    name: "derivative matcher",
    kind: "derivative",
    schema: "",
    input: "a".repeat(N),
    expected: "true",
  },
  // `\x61` per scalar plus `^(?:` and `)(?![\s\S])`.
  {
    name: "ECMAScript source of a long literal",
    kind: "source",
    schema: "",
    input: "a".repeat(N),
    expected: String(4 * N + 15),
  },
];

test("the 64 KiB vectors are at least 64 KiB of UTF-8", () => {
  for (const vector of vectors.filter((v) => !v.name.includes("nesting")))
    expect(Buffer.byteLength(vector.input), vector.name).toBeGreaterThanOrEqual(N - 8);
});

// No --stack-size or NODE_OPTIONS: Bun's default JS stack.
for (const vector of vectors)
  test(
    `Bun .mjs 64 KiB ${vector.name}`,
    () => {
      expect(probe(vector.kind, vector.schema, vector.input)).toBe(vector.expected);
    },
    SLOW_TEST_TIMEOUT_MS,
  );

test(
  "Node .mjs at its default stack runs every 64 KiB vector",
  () => {
    const run = Bun.spawnSync(
      ["node", join(here, "fixtures/stack/run.mjs"), pathToFileURL(built.module).href],
      {
        stdin: Buffer.from(JSON.stringify(vectors.map((v) => [v.kind, v.schema, v.input]))),
        stdout: "pipe",
        stderr: "pipe",
        env: { ...process.env, NODE_OPTIONS: "" },
        timeout: 90_000,
      },
    );
    expect(run.exitCode, run.stderr.toString()).toBe(0);
    const results: unknown = JSON.parse(run.stdout.toString());
    expect(results).toEqual(vectors.map((v) => v.expected));
  },
  SLOW_TEST_TIMEOUT_MS,
);

/**
 * Functions in the emitted JavaScript that still call themselves. Bend turns
 * self tail calls into loops, so each name here recurses on the JS stack.
 */
function selfRecursive(text: string): string[] {
  const names = new Map<string, string>();
  for (const m of text.matchAll(
    /^ {2}"([^"]+)": run_lib\(\([^)]*\) => (?:str_out\()?run_loop\((\$[A-Za-z0-9_$]+)\(/gm,
  ))
    if (m[1] !== undefined && m[2] !== undefined) names.set(m[2], m[1].replace(/^(\.\.\/)+/, ""));
  const parts = text.split(/^function (\$[A-Za-z0-9_$]+)\(/m);
  const found: string[] = [];
  for (let i = 1; i < parts.length; i += 2) {
    const name = parts[i] ?? "";
    if ((parts[i + 1] ?? "").includes(`${name}(`)) found.push(names.get(name) ?? `Base ${name}`);
  }
  return found.sort();
}

// Why each remaining recursion is safe: its depth is bounded by something
// other than the input's length. A new entry fails this test until someone
// classifies it here or rewrites it as a tail loop.
const SPEC = "reference definition kept for the laws; no runtime caller";
const PATTERN = "walks the pattern or its automaton, capped at 128 nodes";
const SCHEMA_DEPTH = "descends one schema level per call; loops over input items are tail calls";
const FIELDS = "one call per field the schema declares, not per input member";
const bounded: Record<string, string> = {
  "Base $List_append": "appends at most four UTF-8 bytes or a pattern-capped list",
  "Base $Word_zero": "one call per bit of a fixed-width word",
  "src/data/json:scan": "one call per nesting level, which stops at 512",
  "src/data/schema-pattern-automaton:accept": PATTERN,
  "src/data/schema-pattern-automaton:accept_block": PATTERN,
  "src/data/schema-pattern-automaton:all_found": PATTERN,
  "src/data/schema-pattern-automaton:attach": PATTERN,
  "src/data/schema-pattern-automaton:attach_block": PATTERN,
  "src/data/schema-pattern-automaton:behind": PATTERN,
  "src/data/schema-pattern-automaton:blocks_go": PATTERN,
  "src/data/schema-pattern-automaton:check": PATTERN,
  "src/data/schema-pattern-automaton:check_block": PATTERN,
  "src/data/schema-pattern-automaton:find": PATTERN,
  "src/data/schema-pattern-automaton:find_word": PATTERN,
  "src/data/schema-pattern-automaton:follow_of": PATTERN,
  "src/data/schema-pattern-automaton:found": PATTERN,
  "src/data/schema-pattern-automaton:found_word": PATTERN,
  "src/data/schema-pattern-automaton:keep": PATTERN,
  "src/data/schema-pattern-automaton:keep_block": PATTERN,
  "src/data/schema-pattern-automaton:linear": PATTERN,
  "src/data/schema-pattern-automaton:or_words": PATTERN,
  "src/data/schema-pattern-automaton:repeat_empty": PATTERN,
  "src/data/schema-pattern:behind": PATTERN,
  "src/data/schema-pattern:derive": PATTERN,
  "src/data/schema-pattern:hash": PATTERN,
  "src/data/schema-pattern:nullable": PATTERN,
  "src/data/schema-pattern:ranges_same": PATTERN,
  "src/data/schema-pattern:repeat_empty": PATTERN,
  "src/data/schema-pattern:same": PATTERN,
  "src/data/schema-pattern:seq": PATTERN,
  "src/data/schema-pattern:size": PATTERN,
  "src/data/schema-pattern:source_go": PATTERN,
  "src/data/schema-pattern:valid": PATTERN,
  "src/data/schema-text:one_of": "scans a fixed character set",
  "src/data/schema:collect_go": SCHEMA_DEPTH,
  "src/data/schema:coerce_go": SCHEMA_DEPTH,
  "src/data/schema:decode_go": SCHEMA_DEPTH,
  "src/data/schema:to_json_go": SCHEMA_DEPTH,
  "src/data/schema:declared": FIELDS,
  "src/data/schema:slots": FIELDS,
  "src/data/schema:valid": FIELDS,
  "src/data/schema:prefix": "maps over one child's errors, at most error_cap() of them",
  "src/data/schema:prefix_onto": "maps over one child's errors, at most error_cap() of them",
  "src/data/schema:first": SPEC,
  "src/data/schema:value_for": SPEC,
  "src/data/utf8:encode_spec": SPEC,
  "src/data/utf8:valid_spec": SPEC,
  "src/data/utf8:join": "one call per bit of a 32-bit word",
  "src/data/utf8:low": "one call per bit of a 32-bit word",
  "src/http/bytes:ascii_spec": SPEC,
  "src/http/bytes:encode_spec": SPEC,
  "src/http/bytes:split_target_spec": SPEC,
  "src/http/bytes:token_tail_spec": SPEC,
  "src/http/bytes:uri_spec": SPEC,
  "src/http/bytes:value_spec": SPEC,
  "src/http/text:cut_spec": SPEC,
};

test("every non-tail recursion left in the shared build is classified", () => {
  expect(selfRecursive(readFileSync(built.module, "utf8"))).toEqual(Object.keys(bounded).sort());
});

// The FIELDS recursions are the only ones a schema can deepen. A schema
// declaring a thousand fields per object, far past any form, still decodes
// a 64 KiB body on Node's default stack. docs/shared.md records the measured
// limit of roughly 3,000 fields there.
test(
  "a 1,000-field object schema decodes on Node's default stack",
  () => {
    const run = Bun.spawnSync(
      ["node", join(here, "fixtures/stack/fields.mjs"), pathToFileURL(built.module).href, "1000"],
      {
        stdout: "pipe",
        stderr: "pipe",
        env: { ...process.env, NODE_OPTIONS: "" },
        timeout: 60_000,
      },
    );
    expect(run.exitCode, run.stderr.toString()).toBe(0);
    expect(run.stdout.toString()).toBe("Done Fail\n");
  },
  SLOW_TEST_TIMEOUT_MS,
);
