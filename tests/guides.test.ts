import { describe, expect, test } from "bun:test";
import {
  cpSync,
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  symlinkSync,
  writeFileSync,
} from "node:fs";
import { createHash } from "node:crypto";
import { dirname, join, resolve } from "node:path";
import { checkOnly, COMPILE_TEST_TIMEOUT_MS } from "./harness.ts";

// Every code block in docs/guides is checked here (BND-72).
//
// - A ```bend block that starts with `import Base` is a complete program. It is
//   typechecked with `bend --check-only`, laid out like a `bendo new` app with
//   the library in `bendo/`.
// - Any other ```bend block is a fragment. Its lines must appear, in order and
//   next to each other, in a complete program on the same page, or in the file
//   named by a `<!-- source: path -->` comment right above it.
// - A ```ts or ```tsx block titled [Hono ...] or [Elysia ...] is the code a
//   migration guide starts from. It is not compiled here, but a fragment must
//   appear in a complete module (one with imports) of the same framework on
//   the page.
// - Any other ```ts block is Bendo or browser code. It is typechecked against
//   the todo example's generated routes, unless a source comment names the
//   file it was taken from.
// - The migration guides must cover every row of the parity table in
//   docs/PLAN.md.

const ROOT = resolve(import.meta.dir, "..");
const GUIDES = join(ROOT, "docs/guides");

type Block = {
  page: string;
  line: number;
  lang: string;
  title: string;
  source: string | undefined;
  code: string;
};

/** Expands `<!--@include: file#region-->` the way VitePress does. */
function expand(page: string, text: string): string {
  return text.replace(
    /<!--\s*@include:\s*([^#\s]+)(?:#([\w-]+))?\s*-->/g,
    (_directive: string, file: string, region: string | undefined) => {
      const included = readFileSync(resolve(dirname(page), file), "utf8");
      if (region === undefined) return included;
      const start = included.indexOf(`<!-- #region ${region} -->`);
      const end = included.indexOf(`<!-- #endregion ${region} -->`);
      if (start < 0 || end < start) throw new Error(`${page}: no region ${region} in ${file}`);
      return included.slice(included.indexOf("\n", start) + 1, end);
    },
  );
}

function blocks(page: string): Block[] {
  const lines = expand(page, readFileSync(page, "utf8")).split("\n");
  const found: Block[] = [];
  let open: { line: number; lang: string; title: string; source: string | undefined } | undefined;
  let body: string[] = [];
  let previous = "";
  lines.forEach((text, index) => {
    if (open === undefined) {
      const fence = /^```(\w+)(?:\s*\[([^\]]*)\])?/.exec(text);
      if (fence !== null) {
        const source = /^<!--\s*source:\s*(\S+)\s*-->$/.exec(previous.trim())?.[1];
        open = { line: index + 1, lang: fence[1] ?? "", title: fence[2] ?? "", source };
        body = [];
      } else if (text.trim() !== "") previous = text;
      return;
    }
    if (text.startsWith("```")) {
      found.push({ page, ...open, code: body.join("\n") });
      open = undefined;
      previous = "";
      return;
    }
    body.push(text);
  });
  if (open !== undefined) throw new Error(`${page}:${open.line}: unclosed code block`);
  return found;
}

/**
 * Nonblank lines, trimmed. A fragment may be indented differently from its
 * program, and may show one item of a list without the list's opening `[` or
 * its closing brackets and commas.
 */
function significant(code: string): string[] {
  return code
    .split("\n")
    .map((line) =>
      line
        .trim()
        .replace(/^\[/, "")
        .replace(/[\]),]+$/, ""),
    )
    .filter((line) => line !== "");
}

function contains(whole: string, part: string): boolean {
  const haystack = significant(whole);
  const needle = significant(part);
  if (needle.length === 0) return false;
  for (let at = 0; at + needle.length <= haystack.length; at++)
    if (needle.every((line, offset) => haystack[at + offset] === line)) return true;
  return false;
}

const pages = readdirSync(GUIDES)
  .filter((name) => name.endsWith(".md"))
  .sort()
  .map((name) => join(GUIDES, name));
const all = pages.flatMap(blocks);
const relativePath = (path: string) => path.slice(ROOT.length + 1);
const where = (block: Block) => `${relativePath(block.page)}:${block.line}`;

const isProgram = (block: Block) => block.lang === "bend" && block.code.startsWith("import Base\n");
const before = (block: Block) => /^(Hono|Elysia)\b/.exec(block.title)?.[1];
const isTypeScript = (block: Block) => block.lang === "ts" || block.lang === "tsx";
const isModule = (block: Block) => /^import\s/m.test(block.code);

/** The text a fragment is checked against: a named source, or the page's own blocks. */
function sources(block: Block, wanted: (candidate: Block) => boolean): string[] {
  if (block.source === undefined)
    return all
      .filter((other) => other.page === block.page && wanted(other))
      .map((other) => other.code);
  const path = resolve(ROOT, block.source);
  if (!existsSync(path)) throw new Error(`${where(block)}: source ${block.source} does not exist`);
  if (path.endsWith(".md"))
    return blocks(path)
      .filter(wanted)
      .map((other) => other.code);
  return [readFileSync(path, "utf8")];
}

describe("guide code blocks", () => {
  test("every guide has code to check", () => {
    for (const page of pages.filter((path) => !path.endsWith("plugins.md")))
      expect(all.filter((block) => block.page === page && isProgram(block)).length).toBeGreaterThan(
        0,
      );
  });

  test("every Bend fragment comes from a checked program or a named source", () => {
    const orphans = all
      .filter((block) => block.lang === "bend" && !isProgram(block))
      .filter((block) => !sources(block, isProgram).some((whole) => contains(whole, block.code)))
      .map(where);
    expect(orphans).toEqual([]);
  });

  test("every Hono and Elysia fragment comes from a complete module of that framework", () => {
    const orphans = all
      .filter((block) => before(block) !== undefined && isTypeScript(block) && !isModule(block))
      .filter(
        (block) =>
          !sources(block, (other) => before(other) === before(block) && isModule(other)).some(
            (whole) => contains(whole, block.code),
          ),
      )
      .map(where);
    expect(orphans).toEqual([]);
  });

  test("every Bendo TypeScript block typechecks", () => {
    const bendo = all.filter((block) => isTypeScript(block) && before(block) === undefined);
    const orphans = bendo
      .filter((block) => block.source !== undefined)
      .filter((block) => !sources(block, () => false).some((whole) => contains(whole, block.code)))
      .map(where);
    expect(orphans).toEqual([]);
    const modules = bendo.filter((block) => block.source === undefined);
    if (modules.length === 0) return;
    const directory = join(ROOT, ".cache/guides-ts");
    mkdirSync(directory, { recursive: true });
    cpSync(join(ROOT, "examples/todo/.bendo"), join(directory, ".bendo"), { recursive: true });
    const files = modules.map((block, index) => {
      const name = `block-${index}.${block.lang}`;
      writeFileSync(join(directory, name), `// ${where(block)}\n${block.code}\nexport {};\n`);
      return name;
    });
    writeFileSync(
      join(directory, "tsconfig.json"),
      JSON.stringify({
        extends: "../../tsconfig.json",
        compilerOptions: {
          noEmit: true,
          lib: ["ES2023", "DOM", "DOM.Iterable"],
          paths: {
            "bendo/client": ["../../packages/bendo/client/index.ts"],
            "bendo/query": ["../../packages/bendo/query/index.ts"],
          },
        },
        include: files,
      }),
    );
    const tsc = Bun.spawnSync(
      [
        "timeout",
        "120s",
        join(ROOT, "node_modules/.bin/tsc"),
        "-p",
        join(directory, "tsconfig.json"),
      ],
      { stdout: "pipe", stderr: "pipe" },
    );
    expect(`${tsc.stdout}${tsc.stderr}`).toBe("");
    expect(tsc.exitCode).toBe(0);
  });

  // Identical programs (a shared app included on two pages) are checked once.
  const programs = new Map<string, Block>();
  for (const block of all.filter(isProgram))
    if (![...programs.values()].some((other) => other.code === block.code))
      programs.set(where(block), block);
  for (const [name, block] of programs)
    test(
      `${name} passes bend --check-only`,
      () => {
        const digest = createHash("sha256").update(block.code).digest("hex").slice(0, 16);
        const directory = join(ROOT, ".cache/guides", digest);
        mkdirSync(directory, { recursive: true });
        if (!existsSync(join(directory, "bendo")))
          symlinkSync(join(ROOT, "src"), join(directory, "bendo"));
        writeFileSync(join(directory, "main.bend"), `${block.code}\n`);
        checkOnly(join(directory, "main.bend"));
      },
      COMPILE_TEST_TIMEOUT_MS,
    );
});

describe("migration guides", () => {
  const plan = readFileSync(join(ROOT, "docs/PLAN.md"), "utf8");
  const section = plan.slice(plan.indexOf("## Parity with Hono and Elysia")).split("\n");
  const first = section.findIndex((line) => line.startsWith("|"));
  const end = section.findIndex((line, index) => index > first && !line.startsWith("|"));
  const features = section
    .slice(first + 2, end)
    .map((line) => line.split("|")[1]?.trim() ?? "")
    .filter((feature) => feature !== "");

  test("the parity table is readable", () => {
    expect(features.length).toBeGreaterThan(20);
    expect(features).toContain("Typed client");
  });

  for (const guide of ["migrate-from-hono.md", "migrate-from-elysia.md"])
    test(`${guide} covers every parity table row with a section`, () => {
      const text = readFileSync(join(GUIDES, guide), "utf8");
      const headings = new Set(
        [...text.matchAll(/^#{2,3}\s+(.+)$/gm)].map((match) =>
          (match[1] ?? "")
            .toLowerCase()
            .replace(/[^\p{L}\p{N}\s-]/gu, "")
            .trim()
            .replace(/\s+/g, "-"),
        ),
      );
      const missing = features.filter((feature) => {
        const row = text.split("\n").find((line) => line.startsWith(`| ${feature} |`));
        const anchor = row === undefined ? undefined : /\]\(#([\w-]+)\)/.exec(row)?.[1];
        return anchor === undefined || !headings.has(anchor);
      });
      expect(missing).toEqual([]);
    });
});
