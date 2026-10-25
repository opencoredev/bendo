import { describe, expect, test } from "bun:test";
import {
  cpSync,
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  rmSync,
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
//   migration guide starts from. A complete module (one with imports) is
//   typechecked against the framework versions pinned in
//   tests/guide-frameworks, named after the file in its title (`Hono ·
//   client.ts`) so modules can import each other. A fragment must appear in a
//   complete module of the same framework on the page.
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

/** Nonblank lines, trimmed, since a fragment may be indented differently from its program. */
function significant(code: string): string[] {
  return code
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line !== "");
}

/**
 * Whether one line of a fragment matches a line of its program. A fragment
 * may show items of a list without the list's delimiters: its first line may
 * leave out the opening `[`, and its last line may leave out the `,` or `]`
 * that follow the item. Nothing else may differ, so a fragment that drops a
 * parenthesis does not match.
 */
function sameLine(whole: string, part: string, first: boolean, last: boolean): boolean {
  const opened = first && whole.startsWith("[") && !part.startsWith("[") ? whole.slice(1) : whole;
  if (opened === part) return true;
  return last && opened.startsWith(part) && /^[\],]+$/.test(opened.slice(part.length));
}

function contains(whole: string, part: string): boolean {
  const haystack = significant(whole);
  const needle = significant(part);
  if (needle.length === 0) return false;
  const last = needle.length - 1;
  for (let at = 0; at + needle.length <= haystack.length; at++)
    if (
      needle.every((line, offset) =>
        sameLine(haystack[at + offset] ?? "", line, offset === 0, offset === last),
      )
    )
      return true;
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
const FRAMEWORKS = ["Hono", "Elysia"] as const;
type Framework = (typeof FRAMEWORKS)[number];
const before = (block: Block): Framework | undefined =>
  FRAMEWORKS.find((framework) => new RegExp(`^${framework}\\b`).test(block.title));
const isTypeScript = (block: Block) => block.lang === "ts" || block.lang === "tsx";
const isModule = (block: Block) => /^import\s/m.test(block.code);
/** `client.ts` for a block titled `Hono · client.ts`. */
const moduleFile = (block: Block) => /·\s*(\S+\.tsx?)$/.exec(block.title)?.[1];
const GUIDE_FRAMEWORKS = join(ROOT, "tests/guide-frameworks");

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

/**
 * Writes `files` to a fresh `.cache/<name>` and typechecks them with the root
 * tsconfig plus `compilerOptions`. `setup` adds anything else the files
 * import before tsc runs.
 */
function typecheck({
  name,
  files,
  compilerOptions,
  setup,
}: {
  name: string;
  files: ReadonlyMap<string, string>;
  compilerOptions: Record<string, unknown>;
  setup: (directory: string) => void;
}): void {
  const directory = join(ROOT, ".cache", name);
  rmSync(directory, { recursive: true, force: true });
  mkdirSync(directory, { recursive: true });
  setup(directory);
  for (const [file, code] of files) writeFileSync(join(directory, file), code);
  writeFileSync(
    join(directory, "tsconfig.json"),
    JSON.stringify({
      extends: "../../tsconfig.json",
      compilerOptions: { noEmit: true, ...compilerOptions },
      include: [...files.keys()],
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
}

describe("guide code blocks", () => {
  test("every guide has code to check", () => {
    for (const page of pages.filter((path) => !path.endsWith("plugins.md")))
      expect(all.filter((block) => block.page === page && isProgram(block)).length).toBeGreaterThan(
        0,
      );
  });

  test("a fragment matches only when its syntax matches the program's", () => {
    const programs = all
      .filter((block) => block.page.endsWith("auth.md") && isProgram(block))
      .map((block) => block.code);
    const jwt = all.find(
      (block) =>
        block.page.endsWith("auth.md") && !isProgram(block) && block.code.includes("B.jwt_with"),
    );
    if (jwt === undefined) throw new Error("auth.md has no B.jwt_with fragment");
    const found = (code: string) => programs.some((whole) => contains(whole, code));
    expect(found(jwt.code)).toBe(true);
    expect(found(jwt.code.replace(/\)$/, ""))).toBe(false);
    expect(found(jwt.code.replace("next(C.set(", "next(C.set"))).toBe(false);
    // List delimiters are the only thing a fragment may leave out.
    const list = "def xs() -> List<&2, U32>:\n  [f(1),\n   g(2)]";
    expect(contains(list, "f(1),\ng(2)]")).toBe(true);
    expect(contains(list, "f(1)")).toBe(true);
    expect(contains(list, "g(2)")).toBe(true);
    expect(contains(list, "f(1)\ng(2)")).toBe(false);
    expect(contains(list, "f(1),\ng(2")).toBe(false);
    expect(contains(list, "f(1,\ng(2)]")).toBe(false);
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
    typecheck({
      name: "guides-ts",
      files: new Map(
        modules.map((block, index) => [
          `block-${index}.${block.lang}`,
          `// ${where(block)}\n${block.code}\nexport {};\n`,
        ]),
      ),
      setup: (directory) =>
        cpSync(join(ROOT, "examples/todo/.bendo"), join(directory, ".bendo"), { recursive: true }),
      compilerOptions: {
        lib: ["ES2023", "DOM", "DOM.Iterable"],
        paths: {
          "bendo/client": ["../../packages/bendo/client/index.ts"],
          "bendo/query": ["../../packages/bendo/query/index.ts"],
        },
      },
    });
  });

  // Each framework's modules get their own directory, so a page's `server.ts`
  // is the one its `client.ts` imports.
  for (const framework of FRAMEWORKS)
    test(`every ${framework} module typechecks against the pinned ${framework}`, () => {
      const install = Bun.spawnSync(
        ["timeout", "120s", "bun", "install", "--frozen-lockfile", "--no-summary"],
        { cwd: GUIDE_FRAMEWORKS, stdout: "pipe", stderr: "pipe" },
      );
      expect({ exitCode: install.exitCode, stderr: `${install.stderr}` }).toMatchObject({
        exitCode: 0,
      });
      const modules = all.filter(
        (block) => before(block) === framework && isTypeScript(block) && isModule(block),
      );
      expect(modules.length).toBeGreaterThan(0);
      const files = new Map(
        modules.map((block, index) => [
          moduleFile(block) ?? `block-${index}.${block.lang}`,
          `// ${where(block)}\n${block.code}\nexport {};\n`,
        ]),
      );
      expect(files.size).toBe(modules.length);
      typecheck({
        name: `guides-${framework.toLowerCase()}`,
        files,
        // Checked as a reader's project would be: strict, without this
        // repository's two extra flags, which idiomatic Elysia code such as
        // `cookie: { theme }` does not satisfy.
        compilerOptions: {
          jsx: "react-jsx",
          noUncheckedIndexedAccess: false,
          exactOptionalPropertyTypes: false,
        },
        setup: (directory) =>
          symlinkSync(join(GUIDE_FRAMEWORKS, "node_modules"), join(directory, "node_modules")),
      });
    }, 240_000);

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
