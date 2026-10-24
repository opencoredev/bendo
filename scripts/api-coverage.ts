import { existsSync, mkdirSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { dirname, join, relative, resolve } from "node:path";
import ts from "typescript";

// The API reference in docs/api must have an entry for every public API, and
// every entry must name one. docs/api/index.md explains the rules below to
// readers; keep the two in step.
//
// Bend. The public API is every top-level def in src/main.bend, written
// `B.name`, plus part of the companion modules: the src/ modules that a shipped
// example or create-bendo template imports, and src/app/context.bend, which the
// middleware guide imports for typed middleware. A companion module is public
// only in the names that an example, a template or a published docs page
// outside docs/api calls through it. A constructor counts as its type.
//
// TypeScript. The public API is every export of every `exports` entry point
// of packages/bendo and packages/vite-plugin-bendo, read with the TypeScript
// compiler. create-bendo has no entry points; its interface is the CLI.

const root = join(import.meta.dir, "..");
const apiDir = "docs/api";

// Each companion module's alias in the reference, which is the alias the
// examples use. A newly imported module fails until it is given one here.
export const companionAliases: ReadonlyMap<string, string> = new Map([
  ["src/app/context.bend", "C"],
  ["src/app/store.bend", "Store"],
  ["src/data/json.bend", "J"],
  ["src/data/schema.bend", "S"],
  ["src/effects/clock.bend", "Clock"],
  ["src/mw/cors.bend", "Cors"],
  ["src/mw/cors_policy.bend", "CorsPolicy"],
  ["src/router/methods.bend", "Methods"],
  ["src/validated.bend", "V"],
  ["src/ws/connection.bend", "W"],
  ["src/ws/message.bend", "M"],
  ["src/ws/pubsub.bend", "P"],
]);
const guideCompanions = ["src/app/context.bend"];

// Docs pages that do not teach the API: the reference itself, the laws (which
// name internals to state them) and the design records.
const nonGuidePages = [/^docs\/api\//, /^docs\/laws\//, /^docs\/decisions\//];
const unpublished = new Set(["docs/PLAN.md", "docs/RUNBOOK.md", "docs/SITE.md"]);

export const tsEntryPackages = ["packages/bendo", "packages/vite-plugin-bendo"];

export type PublicApi = {
  /** `B.param`, `J.Json`, or `bendo/client:createClient`. */
  readonly key: string;
  readonly language: "bend" | "ts";
  /** Where it is defined, as `file:line`, or what makes it public. */
  readonly source: string;
};

const read = (path: string) => readFileSync(join(root, path), "utf8");

function walk(dir: string, accept: (path: string) => boolean): string[] {
  if (!existsSync(join(root, dir))) return [];
  return readdirSync(join(root, dir), { withFileTypes: true })
    .flatMap((entry) => {
      const path = `${dir}/${entry.name}`;
      if (entry.name === "node_modules" || entry.name.startsWith(".")) return [];
      if (entry.isDirectory()) return walk(path, accept);
      return accept(path) ? [path] : [];
    })
    .sort();
}

// ---------------------------------------------------------------- Bend source

type BendModule = {
  readonly defs: ReadonlyMap<string, number>;
  readonly types: ReadonlyMap<string, number>;
  /** Constructor name to its type. */
  readonly constructors: ReadonlyMap<string, string>;
};

const moduleCache = new Map<string, BendModule>();

export function bendModule(path: string): BendModule {
  const cached = moduleCache.get(path);
  if (cached !== undefined) return cached;
  const defs = new Map<string, number>();
  const types = new Map<string, number>();
  const constructors = new Map<string, string>();
  let current: string | undefined;
  read(path)
    .split("\n")
    .forEach((line, index) => {
      const def = /^(?:def|type) ([A-Za-z_]\w*)/.exec(line);
      if (def?.[1] !== undefined) {
        current = line.startsWith("type ") ? def[1] : undefined;
        (line.startsWith("type ") ? types : defs).set(def[1], index + 1);
        return;
      }
      if (/^\S/.test(line)) current = undefined;
      const ctor = /^ {2}([A-Z]\w*)\s*\{/.exec(line);
      if (current !== undefined && ctor?.[1] !== undefined) constructors.set(ctor[1], current);
    });
  const parsed = { defs, types, constructors };
  moduleCache.set(path, parsed);
  return parsed;
}

/** Repo path of a `src/` module named by an import, or undefined for other files. */
function srcModule(from: string, target: string): string | undefined {
  // Templates and the quick start vendor the library as `./bendo/`.
  const vendored = /(?:^|\/)bendo\/(.+\.bend)$/.exec(target);
  const path = relative(root, resolve(root, dirname(from), target));
  if (path.startsWith("src/")) return path;
  if (vendored?.[1] !== undefined && existsSync(join(root, "src", vendored[1])))
    return `src/${vendored[1]}`;
  return undefined;
}

const importLine = /^import (\S+\.bend) as (\w+)\s*$/gm;

/** Alias to src/ module for each import in a Bend source text. */
function aliasesIn(from: string, text: string): Map<string, string> {
  const aliases = new Map<string, string>();
  for (const [, target, alias] of text.matchAll(importLine)) {
    if (target === undefined || alias === undefined) continue;
    const module = srcModule(from, target);
    if (module !== undefined) aliases.set(alias, module);
  }
  return aliases;
}

function bendCodeOf(page: string): string {
  return codeBlocks(read(page))
    .filter((block) => block.lang === "bend" || block.lang === "python")
    .map((block) => block.code)
    .join("\n");
}

/** Pages and programs that show users how to call Bendo. */
function teachingSources(): { readonly file: string; readonly text: string }[] {
  const programs = [
    ...walk("examples", (path) => path.endsWith(".bend")),
    ...walk("packages/create-bendo/templates", (path) => path.endsWith(".bend")),
  ].map((file) => ({ file, text: read(file) }));
  const pages = walk("docs", (path) => path.endsWith(".md"))
    .filter((page) => !unpublished.has(page) && !nonGuidePages.some((re) => re.test(page)))
    .map((file) => ({ file, text: bendCodeOf(file) }));
  return [...programs, ...pages];
}

export function companionModules(): string[] {
  const imported = [
    ...walk("examples", (path) => path.endsWith(".bend")),
    ...walk("packages/create-bendo/templates", (path) => path.endsWith(".bend")),
  ].flatMap((file) => [...aliasesIn(file, read(file)).values()]);
  return [...new Set([...imported, ...guideCompanions])]
    .filter((module) => module !== "src/main.bend")
    .sort();
}

export function bendPublicApi(): PublicApi[] {
  const main = bendModule("src/main.bend");
  const api: PublicApi[] = [...main.defs].map(([name, line]) => ({
    key: `B.${name}`,
    language: "bend",
    source: `src/main.bend:${line}`,
  }));
  const companions = companionModules();
  const unnamed = companions.filter((module) => !companionAliases.has(module));
  if (unnamed.length > 0)
    throw new Error(`give these companion modules an alias in companionAliases: ${unnamed}`);
  const found = new Map<string, PublicApi>();
  for (const { file, text } of teachingSources()) {
    for (const [alias, module] of aliasesIn(file, text)) {
      const canonical = companionAliases.get(module);
      if (canonical === undefined || !companions.includes(module)) continue;
      const parsed = bendModule(module);
      for (const match of text.matchAll(new RegExp(`(?<![\\w.])${alias}\\.([A-Za-z_]\\w*)`, "g"))) {
        const used = match[1] ?? "";
        const name = parsed.constructors.get(used) ?? used;
        const line = parsed.defs.get(name) ?? parsed.types.get(name);
        if (line === undefined) throw new Error(`${file} uses ${alias}.${used}, not in ${module}`);
        const key = `${canonical}.${name}`;
        if (!found.has(key))
          found.set(key, { key, language: "bend", source: `${module}:${line} (used in ${file})` });
      }
    }
  }
  return [...api, ...[...found.values()].sort((a, b) => a.key.localeCompare(b.key))];
}

// ----------------------------------------------------------------- TypeScript

/** `bendo/client` to its entry file, for every exported entry point. */
export function tsEntryPoints(): Map<string, string> {
  const entries = new Map<string, string>();
  for (const dir of tsEntryPackages) {
    const manifest: unknown = JSON.parse(read(`${dir}/package.json`));
    if (typeof manifest !== "object" || manifest === null) throw new Error(`${dir}: bad manifest`);
    const name = "name" in manifest ? manifest.name : undefined;
    const exports = "exports" in manifest ? manifest.exports : undefined;
    if (typeof name !== "string" || typeof exports !== "object" || exports === null)
      throw new Error(`${dir}/package.json needs a name and an exports map`);
    for (const [subpath, target] of Object.entries(exports)) {
      if (typeof target !== "string") throw new Error(`${dir}: export ${subpath} is not a path`);
      const specifier = subpath === "." ? name : `${name}/${subpath.replace(/^\.\//, "")}`;
      entries.set(specifier, join(dir, target));
    }
  }
  return entries;
}

function compilerOptions(): ts.CompilerOptions {
  const config = ts.readConfigFile(join(root, "tsconfig.json"), ts.sys.readFile);
  if (config.error !== undefined)
    throw new Error(ts.flattenDiagnosticMessageText(config.error.messageText, "\n"));
  return ts.parseJsonConfigFileContent(config.config, ts.sys, root).options;
}

export function tsPublicApi(): PublicApi[] {
  const entries = tsEntryPoints();
  const program = ts.createProgram(
    [...entries.values()].map((file) => join(root, file)),
    { ...compilerOptions(), noEmit: true },
  );
  const checker = program.getTypeChecker();
  return [...entries].flatMap(([specifier, file]) => {
    const source = program.getSourceFile(join(root, file));
    const symbol = source === undefined ? undefined : checker.getSymbolAtLocation(source);
    if (symbol === undefined) throw new Error(`cannot read the exports of ${file}`);
    return checker
      .getExportsOfModule(symbol)
      .map((exported) => exported.name)
      .sort()
      .map((name) => ({ key: `${specifier}:${name}`, language: "ts" as const, source: file }));
  });
}

// --------------------------------------------------------------- Reference

export type CodeBlock = {
  readonly lang: string;
  /** Words after the language in the fence's info string. */
  readonly meta: readonly string[];
  readonly code: string;
  /** 1-based line of the opening fence. */
  readonly line: number;
};

export function codeBlocks(markdown: string): CodeBlock[] {
  const blocks: CodeBlock[] = [];
  const lines = markdown.split("\n");
  for (let index = 0; index < lines.length; index++) {
    const open = /^(`{3,}|~{3,})\s*(\S*)\s*(.*)$/.exec(lines[index] ?? "");
    if (open === null) continue;
    const [, fence = "```", lang = "", meta = ""] = open;
    const start = index;
    const body: string[] = [];
    for (index++; index < lines.length && !(lines[index] ?? "").startsWith(fence); index++)
      body.push(lines[index] ?? "");
    blocks.push({
      lang,
      meta: meta.split(/\s+/).filter(Boolean),
      code: body.join("\n"),
      line: start + 1,
    });
  }
  return blocks;
}

export type Entry = {
  readonly page: string;
  readonly line: number;
  /** Keys in the same form as PublicApi.key. */
  readonly keys: readonly string[];
  /** The names as the heading writes them. */
  readonly names: readonly string[];
  readonly examples: readonly CodeBlock[];
};

export type Page = {
  readonly page: string;
  readonly language: "bend" | "ts";
  /** For TypeScript pages, the entry point the page documents. */
  readonly module: string | undefined;
  readonly text: string;
};

/** An example is a `bend`, `ts` or `tsx` fence. `signature` marks one that is only shown. */
export function isExample(block: CodeBlock, language: "bend" | "ts"): boolean {
  const langs = language === "bend" ? ["bend"] : ["ts", "tsx"];
  return langs.includes(block.lang) && !block.meta.includes("signature");
}

export function referencePages(): Page[] {
  return walk(apiDir, (path) => path.endsWith(".md"))
    .filter((page) => page !== `${apiDir}/index.md`)
    .map((page) => {
      const text = read(page);
      const front = /^---\n([\s\S]*?)\n---\n/.exec(text)?.[1] ?? "";
      const module = /^module:\s*(\S+)\s*$/m.exec(front)?.[1];
      const language = page.startsWith(`${apiDir}/ts/`) ? "ts" : "bend";
      if (language === "ts" && module === undefined)
        throw new Error(`${page}: a TypeScript page needs \`module:\` in its frontmatter`);
      return { page, language, module, text };
    });
}

const entryHeading = /^### (`[^`]+`(?:, `[^`]+`)*)\s*$/;

export function entries(pages = referencePages()): Entry[] {
  return pages.flatMap(({ page, language, module, text }) => {
    const lines = text.split("\n");
    const blocks = codeBlocks(text);
    const found: Entry[] = [];
    let inFence = false;
    lines.forEach((line, index) => {
      if (/^(`{3,}|~{3,})/.test(line)) inFence = !inFence;
      if (inFence) return;
      const heading = entryHeading.exec(line)?.[1];
      if (heading === undefined) return;
      const names = heading.split(", ").map((name) => name.slice(1, -1));
      const start = index + 1;
      const next = lines.findIndex((other, at) => at > index && /^#{1,3} /.test(other));
      const end = next === -1 ? lines.length + 1 : next + 1;
      found.push({
        page,
        line: start,
        names,
        keys: names.map((name) => (language === "ts" ? `${module}:${name}` : name)),
        examples: blocks.filter(
          (block) => block.line > start && block.line < end && isExample(block, language),
        ),
      });
    });
    return found;
  });
}

/** Whether an example's code uses a name. */
export function mentions(
  code: string,
  name: string,
  language: "bend" | "ts",
  module?: string,
): boolean {
  if (language === "ts" && name === "default")
    return new RegExp(`import\\s+\\w+\\s*(?:,\\s*\\{[^}]*\\})?\\s+from\\s+"${module}"`).test(code);
  const escaped = name.replace(/[.$]/g, (char) => `\\${char}`);
  return new RegExp(`(?<![\\w.$])${escaped}(?![\\w$])`).test(code);
}

export type Problem = string;

export function coverageProblems(
  pages = referencePages(),
  api: readonly PublicApi[] = [...bendPublicApi(), ...tsPublicApi()],
): Problem[] {
  const known = new Set(api.map((item) => item.key));
  const all = entries(pages);
  const documented = new Set(all.flatMap((entry) => entry.keys));
  const problems: Problem[] = [];
  for (const item of api)
    if (!documented.has(item.key)) problems.push(`no entry for ${item.key} (${item.source})`);
  const seen = new Map<string, string>();
  for (const entry of all) {
    const where = `${entry.page}:${entry.line}`;
    const language = entry.page.startsWith(`${apiDir}/ts/`) ? "ts" : "bend";
    const module = entry.keys[0]?.split(":")[0];
    entry.keys.forEach((key, index) => {
      const name = entry.names[index] ?? key;
      if (!known.has(key)) problems.push(`${where}: ${key} is not a public API`);
      const earlier = seen.get(key);
      if (earlier !== undefined)
        problems.push(`${where}: ${key} already has an entry at ${earlier}`);
      seen.set(key, where);
      if (entry.examples.length === 0) return;
      const code = entry.examples.map((block) => block.code).join("\n");
      if (!mentions(code, name, language, module))
        problems.push(`${where}: no example under this entry uses ${name}`);
    });
    if (entry.examples.length === 0)
      problems.push(`${where}: ${entry.names.join(", ")} has no example`);
  }
  return problems;
}

// ---------------------------------------------------------------- Examples

const examplesDir = join(root, ".cache/api-examples");

export type BendProgram = { readonly page: string; readonly file: string };

/**
 * Writes one Bend program per Bend reference page: every example on the page
 * in page order, with imports moved to the top and `./bendo/` pointed at src/.
 */
export function writeBendPrograms(pages = referencePages()): BendProgram[] {
  mkdirSync(join(examplesDir, "bend"), { recursive: true });
  return pages
    .filter((page) => page.language === "bend")
    .flatMap(({ page, text }) => {
      const blocks = codeBlocks(text).filter((block) => isExample(block, "bend"));
      if (blocks.length === 0) return [];
      const imports = new Map<string, string>();
      const bodies = blocks.map((block) => {
        const kept = block.code.split("\n").filter((line) => {
          const imported = /^import\s+(\S+)(?:\s+as\s+(\w+))?\s*$/.exec(line);
          if (imported === null) return true;
          const [, target = "", alias = target] = imported;
          const path = target.replace(/^\.\/bendo\//, "../../../src/");
          const earlier = imports.get(alias);
          if (earlier !== undefined && earlier !== path)
            throw new Error(
              `${page}:${block.line}: ${alias} imports ${target}, earlier ${earlier}`,
            );
          imports.set(alias, path);
          return false;
        });
        return `# ${page}:${block.line}\n${kept.join("\n").trim()}\n`;
      });
      const head = [...imports].map(([alias, path]) =>
        alias === path ? `import ${path}` : `import ${path} as ${alias}`,
      );
      const program = [...head, "", ...bodies];
      if (!bodies.some((body) => /^def main\(/m.test(body)))
        program.push("def main() -> IO(Unit):", '  IO.print("ok")', "");
      const file = join(
        examplesDir,
        "bend",
        `${page
          .slice(apiDir.length + 1)
          .replace(/\//g, "-")
          .replace(/\.md$/, "")}.bend`,
      );
      writeFileSync(file, program.join("\n"));
      return [{ page, file }];
    });
}

export type TsCheck = { readonly files: number; readonly problems: Problem[] };

/**
 * Writes every TypeScript example as its own module beside a copy of the
 * client fixture's generated `.bendo/` files, then typechecks them together
 * with the repo's compiler options. Package imports resolve to the workspace
 * sources through their `exports` maps.
 */
export function checkTsExamples(pages = referencePages()): TsCheck {
  const dir = join(examplesDir, "ts");
  mkdirSync(join(dir, ".bendo"), { recursive: true });
  for (const name of ["routes.ts", "routes.schemas.ts"])
    writeFileSync(join(dir, ".bendo", name), read(`packages/bendo/client/fixture/${name}`));
  const origins = new Map<string, string>();
  for (const { page, language, text } of pages) {
    if (language !== "ts") continue;
    for (const block of codeBlocks(text).filter((b) => isExample(b, "ts"))) {
      const base = page
        .slice(apiDir.length + 1)
        .replace(/\//g, "-")
        .replace(/\.md$/, "");
      const file = join(dir, `${base}-${block.line}.${block.lang}`);
      // `export {}` keeps each example its own module even without imports.
      writeFileSync(file, `${block.code}\nexport {};\n`);
      origins.set(file, `${page}:${block.line}`);
    }
  }
  const paths: Record<string, string[]> = {};
  for (const [specifier, file] of tsEntryPoints()) paths[specifier] = [join(root, file)];
  paths["*"] = tsEntryPackages.map((pkg) => join(root, pkg, "node_modules/*"));
  const program = ts.createProgram([...origins.keys()], {
    ...compilerOptions(),
    noEmit: true,
    jsx: ts.JsxEmit.ReactJSX,
    paths,
  });
  const problems = ts
    .getPreEmitDiagnostics(program)
    .filter((diagnostic) => diagnostic.file !== undefined && origins.has(diagnostic.file.fileName))
    .map((diagnostic) => {
      const file = diagnostic.file;
      const origin = file === undefined ? "?" : origins.get(file.fileName);
      const { line } =
        file === undefined
          ? { line: 0 }
          : file.getLineAndCharacterOfPosition(diagnostic.start ?? 0);
      const [page, fence] = (origin ?? "?:0").split(":");
      return `${page}:${Number(fence) + 1 + line}: ${ts.flattenDiagnosticMessageText(diagnostic.messageText, "\n")}`;
    });
  return { files: origins.size, problems };
}

if (import.meta.main) {
  const bend = bendPublicApi();
  const typescript = tsPublicApi();
  const all = entries();
  console.log(
    `Bend: ${bend.filter((item) => item.key.startsWith("B.")).length} B.* defs, ${bend.length} names with companions`,
  );
  console.log(`TypeScript: ${typescript.length} exports`);
  console.log(
    `Reference: ${all.length} entries naming ${all.flatMap((entry) => entry.keys).length} APIs`,
  );
  if (process.argv.includes("--list"))
    for (const item of [...bend, ...typescript]) console.log(`  ${item.key}\t${item.source}`);
  const problems = coverageProblems();
  for (const problem of problems) console.log(`  ${problem}`);
  if (problems.length > 0) process.exitCode = 1;
}
