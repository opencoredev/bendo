import { afterAll, describe, expect, test } from "bun:test";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";
import type {
  Todo,
  TodoInput,
  Validation,
} from "../prototypes/0003-typed-values/generated/validator.js";

const root = resolve(import.meta.dir, "..");
const source = join(root, "prototypes/0003-typed-values");
const out = mkdtempSync(join(tmpdir(), "bnd5-"));
afterAll(() => rmSync(out, { recursive: true, force: true }));

function run(args: string[]): string {
  const result = Bun.spawnSync(args, { stdout: "pipe", stderr: "pipe", timeout: 30000 });
  if (result.exitCode !== 0)
    throw new Error(`${args.join(" ")}\n${result.stdout}\n${result.stderr}`);
  return result.stdout.toString().trim();
}

// JSON fixtures become literal Bend trees, not a second native JSON parser.
function bendValue(value: unknown): string {
  if (value === null) return "V.JsonNull{}";
  if (typeof value === "string") return `V.JsonString{${JSON.stringify(value)}}`;
  if (typeof value === "boolean") return `V.JsonBool{${value ? "True{}" : "False{}"}}`;
  if (typeof value === "number") return `V.JsonNumber{${JSON.stringify(String(value))}}`;
  if (Array.isArray(value)) return "V.JsonArray{}";
  if (typeof value === "object") {
    return `V.JsonObject{[${Object.entries(value)
      .map(([name, field]) => `V.JsonField{${JSON.stringify(name)}, ${bendValue(field)}}`)
      .join(", ")}]}`;
  }
  throw new Error("fixture must be JSON");
}

type Mode = "body" | "query" | "response";
type Case = { name: string; input: unknown; mode: Mode; expected: Validation; report: string };
const error = (message: string): Validation => ({ kind: "error", error: message });
const ok = (value: Todo): Validation => ({ kind: "ok", value });
const body: TodoInput = { title: "Read" };
const cases: Case[] = [
  {
    name: "default done and absent optional due",
    input: body,
    mode: "body",
    expected: ok({ title: "Read", done: false }),
    report: "ok:Read:False:none",
  },
  {
    name: "present due",
    input: { title: "Read", done: true, due: "2026-10-22" },
    mode: "response",
    expected: ok({ title: "Read", done: true, due: "2026-10-22" }),
    report: "ok:Read:True:2026-10-22",
  },
  ...["true", "1", "false", "0"].map((value): Case => {
    const done = value === "true" || value === "1";
    return {
      name: `query ${value}`,
      input: { title: "Read", done: value },
      mode: "query",
      expected: ok({ title: "Read", done }),
      report: `ok:Read:${done ? "True" : "False"}:none`,
    };
  }),
  {
    name: "query default",
    input: body,
    mode: "query",
    expected: ok({ title: "Read", done: false }),
    report: "ok:Read:False:none",
  },
  {
    name: "strict body boolean",
    input: { title: "Read", done: "true" },
    mode: "body",
    expected: error("expected boolean"),
    report: "error:expected boolean",
  },
  {
    name: "malformed response title",
    input: { title: 42, done: false },
    mode: "response",
    expected: error("expected string"),
    report: "error:expected string",
  },
  {
    name: "response cannot fill default",
    input: body,
    mode: "response",
    expected: error("expected response boolean"),
    report: "error:expected response boolean",
  },
  {
    name: "response cannot coerce",
    input: { title: "Read", done: "1" },
    mode: "response",
    expected: error("expected boolean"),
    report: "error:expected boolean",
  },
  {
    name: "numeric boolean rejected",
    input: { title: "Read", done: 1 },
    mode: "query",
    expected: error("expected boolean"),
    report: "error:expected boolean",
  },
  {
    name: "unknown coercion rejected",
    input: { title: "Read", done: "yes" },
    mode: "query",
    expected: error("expected query boolean"),
    report: "error:expected query boolean",
  },
  {
    name: "optional does not mean nullable",
    input: { title: "Read", due: null },
    mode: "body",
    expected: error("expected optional string"),
    report: "error:expected optional string",
  },
  {
    name: "invalid optional type",
    input: { title: "Read", due: 5 },
    mode: "body",
    expected: error("expected optional string"),
    report: "error:expected optional string",
  },
  {
    name: "extra fields rejected",
    input: { title: "Read", admin: true },
    mode: "body",
    expected: error("unknown field"),
    report: "error:unknown field",
  },
  {
    name: "missing title",
    input: {},
    mode: "body",
    expected: error("expected string"),
    report: "error:expected string",
  },
  {
    name: "null object",
    input: null,
    mode: "body",
    expected: error("expected object"),
    report: "error:expected object",
  },
  {
    name: "array object",
    input: [],
    mode: "body",
    expected: error("expected object"),
    report: "error:expected object",
  },
  {
    name: "Unicode survives both targets",
    input: { title: "café 📝", done: false },
    mode: "response",
    expected: ok({ title: "café 📝", done: false }),
    report: "ok:café 📝:False:none",
  },
];
const modes = { body: "BodyMode", query: "QueryMode", response: "ResponseMode" } satisfies Record<
  Mode,
  string
>;

describe("typed-value research gate", () => {
  test("real native and mjs decoders agree on coercion, defaults and rejection", async () => {
    run(["bun", join(source, "generate.js"), out]);
    const fixture = `import Base\nimport ./app.bend as A\nimport ./value.bend as V\nimport ./schema.bend as S\n\ndef main() -> IO(Unit):\n  do IO<Unit>:\n${cases.map((c) => `    IO.print(A.dispatch(S.CreateTodo{}, ${bendValue(c.input)}, V.${modes[c.mode]}{}))`).join("\n")}\n`;
    writeFileSync(join(out, "fixtures.bend"), fixture);
    run(["bend", join(out, "fixtures.bend"), "-o", join(out, "native")]);
    run(["bend", join(out, "app.bend"), "-o", join(out, "app.mjs")]);
    const native = run([join(out, "native"), "+RTS", "--threads", "1"]).split("\n");
    const { validateTodo, toBend } = await import(pathToFileURL(join(out, "validator.js")).href);
    const { default: app } = await import(pathToFileURL(join(out, "app.mjs")).href);
    expect(native).toHaveLength(cases.length);
    for (const [i, c] of cases.entries()) {
      // The same JSON.parse boundary is used by the browser page.
      const input: unknown = JSON.parse(JSON.stringify(c.input));
      const validation: unknown = validateTodo(input, c.mode);
      const jsReport: unknown = app.dispatch({ $: "CreateTodo" }, toBend(input), {
        $: modes[c.mode],
      });
      expect(validation, c.name).toEqual(c.expected);
      expect(jsReport, c.name).toBe(c.report);
      expect(native[i], c.name).toBe(c.report);
    }
  }, 30000);

  test("generated manifest and declarations stay reproducible", () => {
    for (const file of [
      "manifest.json",
      "validator.d.ts",
      "todo.bend",
      "validator.js",
      "value.bend",
    ]) {
      expect(readFileSync(join(out, file), "utf8")).toBe(
        readFileSync(join(source, "generated", file), "utf8"),
      );
    }
    const manifest: unknown = JSON.parse(readFileSync(join(out, "manifest.json"), "utf8"));
    expect(manifest).toMatchObject({
      schemas: {
        Todo: {
          $schema: "https://json-schema.org/draft/2020-12/schema",
          required: ["title"],
          additionalProperties: false,
        },
        TodoResponse: { required: ["title", "done"] },
      },
      routes: [{ method: "POST", path: "/todos", handler: "CreateTodo" }],
    });
  });

  test("schema-indexed alternative really compiles to both targets", async () => {
    run(["bend", join(source, "indexed.bend"), "-o", join(out, "indexed")]);
    run(["bend", join(source, "indexed.bend"), "-o", join(out, "indexed.mjs")]);
    expect(run([join(out, "indexed"), "+RTS", "--threads", "1"])).toBe("typed");
    const { default: indexed } = await import(pathToFileURL(join(out, "indexed.mjs")).href);
    const title: unknown = indexed.title_of(indexed.example());
    expect(title).toBe("typed");
  });
});
