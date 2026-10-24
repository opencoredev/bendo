import {
  mkdirSync,
  mkdtempSync,
  readdirSync,
  readFileSync,
  renameSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { spawn } from "node:child_process";
import { tmpdir } from "node:os";
import { basename, dirname, join, relative, resolve } from "node:path";
import { findBend } from "./bend.ts";
import { sourceGraph } from "./sources.ts";

export { sourceGraph };
import {
  BendSyntaxError,
  PRELUDE,
  PRELUDE_NAMES,
  identifier,
  isExportName,
  isTypeLevel,
  parseModule,
  renderSignature,
  renderTypes,
  type Module,
  type Naming,
  type Signature,
} from "./bend-types.ts";

/** One entry of the default export object that Bend writes into an `.mjs`. */
export type ExportEntry = { key: string; arity: number; value: string };

/** Bend's `.mjs` body and its default export table, in order. */
export type ExportTable = { body: string; entries: ExportEntry[] };

// Bend may emit the table on the same line as a preceding statement.
const TABLE_START = "export default {\n";
const ENTRY = /^ {2}("(?:[^"\\]|\\.)*"): (run_lib\(.*, (\d+)\)),$/;

/** Splits Bend's `.mjs` output into its program and its export table. */
export function parseExportTable(text: string): ExportTable {
  const start = text.lastIndexOf(TABLE_START);
  if (start < 0 || text.indexOf(TABLE_START) !== start)
    throw new Error("Bend .mjs output has no single default export table");
  const lines = text.slice(start + TABLE_START.length).split("\n");
  const entries: ExportEntry[] = [];
  let closed = false;
  for (const line of lines) {
    if (line === "};") {
      closed = true;
      continue;
    }
    if (closed) {
      if (line.trim() !== "") throw new Error("Bend .mjs output continues after its exports");
      continue;
    }
    const match = ENTRY.exec(line);
    if (!match) throw new Error(`Unrecognized Bend .mjs export: ${line}`);
    const key: unknown = JSON.parse(match[1] ?? "");
    if (typeof key !== "string") throw new Error(`Unrecognized Bend .mjs export: ${line}`);
    entries.push({ key, value: match[2] ?? "", arity: Number(match[3]) });
  }
  if (!closed) throw new Error("Bend .mjs export table is not closed");
  return { body: text.slice(0, start), entries };
}

const TABLE = "$0bendo";

/** Re-emits Bend's module with the same default export plus named exports. */
export function withNamedExports(table: ExportTable, names: readonly string[]): string {
  const rows = table.entries.map((entry) => `  ${JSON.stringify(entry.key)}: ${entry.value},`);
  // `$0…` names cannot collide with Bend's `$name` defs or its runtime helpers.
  const locals = names.map((name, i) => `const $0n${i} = ${TABLE}[${JSON.stringify(name)}];`);
  const exported = names.map((name, i) => `$0n${i} as ${name}`).join(", ");
  return [
    `${table.body}\nconst ${TABLE} = {`,
    ...rows,
    "};",
    `export default ${TABLE};`,
    ...locals,
    names.length === 0 ? "" : `export { ${exported} };`,
    "",
  ].join("\n");
}

export type SharedModule = {
  source: string;
  module: string;
  declarations: string;
  /** Named exports: the entry file's own pure defs. */
  named: string[];
  warnings: string[];
};

type Graph = { entry: string; modules: Map<string, Module>; failed: Map<string, string> };

function readGraph(entry: string): Graph {
  const modules = new Map<string, Module>();
  const failed = new Map<string, string>();
  for (const [file, content] of sourceGraph(entry)) {
    if (!file.endsWith(".bend")) continue;
    try {
      modules.set(
        file,
        parseModule(file, content.toString(), (path) => resolve(dirname(file), path)),
      );
    } catch (error) {
      if (!(error instanceof BendSyntaxError)) throw error;
      failed.set(file, error.message);
    }
  }
  return { entry, modules, failed };
}

/** A TypeScript namespace per imported module, named after its file. */
function namespaces(graph: Graph): Map<string, string> {
  const taken = new Set<string>([...PRELUDE_NAMES, "bendo"]);
  for (const decl of graph.modules.get(graph.entry)?.types.values() ?? []) taken.add(decl.name);
  // A types-only namespace may share a function's name, but not a type's.
  for (const def of graph.modules.get(graph.entry)?.defs.values() ?? [])
    if (isTypeLevel(def)) taken.add(def.name);
  const names = new Map<string, string>();
  for (const file of [...graph.modules.keys(), ...graph.failed.keys()].sort()) {
    if (file === graph.entry) continue;
    // `default.bend` becomes `default_`, then `default_2` on a collision.
    const stem = identifier(basename(file, ".bend"));
    const glue = stem.endsWith("_") ? "" : "_";
    let name = stem;
    for (let i = 2; taken.has(name); i++) name = `${stem}${glue}${i}`;
    taken.add(name);
    names.set(file, name);
  }
  return names;
}

/** Bend names an imported def `<path from the entry's directory, no .bend>:<name>`. */
function exportPrefix(entry: string, file: string): string {
  return relative(dirname(entry), file).replace(/\.bend$/, "");
}

function signatureType(signature: Signature): string {
  return signature.kind === "function" ? signature.text : "(...args: unknown[]) => unknown";
}

/** Renders the `.d.mts` for one compiled shared module. */
export function declarations(
  entry: string,
  table: ExportTable,
  generator = "`bendo build --shared`",
): { text: string; named: string[]; warnings: string[]; io: string[] } {
  const graph = readGraph(entry);
  const ns = namespaces(graph);
  const naming: Naming = {
    prefix: (file) => (file === entry ? "" : `${ns.get(file) ?? "unknown"}.`),
    module: (file) => graph.modules.get(file),
  };
  const warnings = [...graph.failed].map(
    ([file, message]) => `${relative(dirname(entry), file)}: not parsed (${message})`,
  );
  const owners = new Map<string, string>();
  for (const file of graph.modules.keys())
    if (file !== entry) owners.set(exportPrefix(entry, file), file);
  const out: string[] = [
    `// Generated by ${generator} from ${basename(entry)}. Do not edit.`,
    "// Values follow Bend's .mjs ABI; see docs/shared.md.",
    PRELUDE,
  ];
  const self = graph.modules.get(entry);
  if (self === undefined) throw new Error(`${entry}: ${graph.failed.get(entry) ?? "not parsed"}`);
  out.push(...renderTypes(self, naming), "");
  for (const [file, name] of [...ns].sort(([, a], [, b]) => a.localeCompare(b))) {
    const module = graph.modules.get(file);
    const body = module === undefined ? [] : renderTypes(module, naming);
    out.push(`export declare namespace ${name} {`, ...body.map((line) => `  ${line}`), "}", "");
  }
  const named: string[] = [];
  const io: string[] = [];
  const members: string[] = [];
  let untyped = 0;
  for (const entryRow of table.entries) {
    const colon = entryRow.key.lastIndexOf(":");
    const file = colon < 0 ? entry : owners.get(entryRow.key.slice(0, colon));
    const name = colon < 0 ? entryRow.key : entryRow.key.slice(colon + 1);
    const module = file === undefined ? undefined : graph.modules.get(file);
    const def = module?.defs.get(name);
    const signature: Signature =
      module === undefined || def === undefined
        ? { kind: "mismatch", expected: entryRow.arity, found: -1 }
        : renderSignature(def, module, naming, entryRow.arity);
    const key = JSON.stringify(entryRow.key);
    if (colon < 0 && signature.kind === "io") io.push(name);
    if (colon < 0 && signature.kind === "mismatch")
      warnings.push(
        `${name}: compiled with ${signature.expected} arguments, but its Bend signature reads as ${signature.found}; typed as unknown`,
      );
    if (colon >= 0 && signature.kind !== "function" && signature.kind !== "type-level") untyped++;
    if (colon < 0 && signature.kind === "function" && isExportName(name) && def !== undefined) {
      named.push(name);
      out.push(
        `/** Bend: ${def.header} */`,
        `export declare function ${name}${signature.generics}(${signature.params}): ${signature.result};`,
      );
      members.push(`  readonly ${key}: typeof ${name};`);
    } else members.push(`  readonly ${key}: ${signatureType(signature)};`);
  }
  if (untyped > 0) warnings.push(`${untyped} imported defs are typed as unknown`);
  out.push("declare const bendo: {", ...members, "};", "export default bendo;", "");
  return { text: out.join("\n"), named, warnings, io };
}

const COMPILE_TIMEOUT_MS = 180_000;

// node:child_process rather than Bun.spawn, so vite-plugin-bendo runs under Node.
// Output is streamed into memory with no cap, so a long diagnostic arrives whole.
function compileModule(bend: string, entry: string, output: string): Promise<string> {
  return new Promise((done, fail) => {
    const child = spawn(bend, [entry, "-o", output], {
      env: { ...process.env, BEND_NO_TELEMETRY: "1" },
      stdio: ["ignore", "pipe", "pipe"],
    });
    const stdout: Buffer[] = [];
    const stderr: Buffer[] = [];
    child.stdout.on("data", (chunk: Buffer) => stdout.push(chunk));
    child.stderr.on("data", (chunk: Buffer) => stderr.push(chunk));
    let settled = false;
    const settle = (finish: () => void) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      finish();
    };
    const timer = setTimeout(() => child.kill("SIGTERM"), COMPILE_TIMEOUT_MS);
    child.on("error", (error) => settle(() => fail(error)));
    child.on("close", (code, signal) =>
      settle(() => {
        if (signal !== null) {
          fail(new Error(`${entry}: bend stopped (${signal}) after at most 180s`));
          return;
        }
        if (code !== 0) {
          const text = `${Buffer.concat(stdout).toString()}${Buffer.concat(stderr).toString()}`;
          fail(new BendCompileError(entry, text.trim()));
          return;
        }
        try {
          done(readFileSync(output, "utf8"));
        } catch (error) {
          fail(error);
        }
      }),
    );
  });
}

/** Bend rejected the program; `output` is its diagnostic. */
export class BendCompileError extends Error {
  readonly entry: string;
  readonly output: string;
  constructor(entry: string, output: string) {
    super(`${entry}: Bend compilation failed\n${output}`.trim());
    this.entry = entry;
    this.output = output;
  }
}

/** The file returns IO, which shared code cannot run. */
export class SharedIoError extends Error {
  readonly defs: string[];
  constructor(entry: string, defs: string[]) {
    super(
      `${entry}: shared code must be pure, but ${defs.map((d) => `\`${d}\``).join(", ")} return${defs.length === 1 ? "s" : ""} IO`,
    );
    this.defs = defs;
  }
}

/** One shared module as text: its `.mjs` source and its `.d.mts` declarations. */
export type CompiledShared = {
  source: string;
  module: string;
  declarations: string;
  named: string[];
  warnings: string[];
};

/** Compiles one shared Bend file to text without writing next to it. */
export async function compileShared(
  entry: string,
  bend: string,
  generator?: string,
): Promise<CompiledShared> {
  const source = resolve(entry);
  const temporary = mkdtempSync(join(tmpdir(), "bendo-shared-"));
  try {
    const table = parseExportTable(await compileModule(bend, source, join(temporary, "bend.mjs")));
    const typed = declarations(source, table, generator);
    if (typed.io.length > 0) throw new SharedIoError(entry, typed.io);
    return {
      source,
      module: withNamedExports(table, typed.named),
      declarations: typed.text,
      named: typed.named,
      warnings: typed.warnings,
    };
  } finally {
    rmSync(temporary, { recursive: true, force: true });
  }
}

/** Compiles one shared Bend file into `<out>/<name>.mjs` and `<out>/<name>.d.mts`. */
export async function buildSharedModule(entry: string, out: string): Promise<SharedModule> {
  const bend = findBend();
  if (bend.kind === "missing")
    throw new Error("bend not found. Install Bend from https://bend-lang.com");
  const compiled = await compileShared(entry, bend.path);
  const name = basename(compiled.source, ".bend");
  mkdirSync(out, { recursive: true });
  const temporary = mkdtempSync(join(out, ".shared-"));
  try {
    const module = join(out, `${name}.mjs`);
    const types = join(out, `${name}.d.mts`);
    writeFileSync(join(temporary, "module.mjs"), compiled.module);
    writeFileSync(join(temporary, "module.d.mts"), compiled.declarations);
    renameSync(join(temporary, "module.d.mts"), types);
    renameSync(join(temporary, "module.mjs"), module);
    return {
      source: compiled.source,
      module,
      declarations: types,
      named: compiled.named,
      warnings: compiled.warnings,
    };
  } finally {
    rmSync(temporary, { recursive: true, force: true });
  }
}

/** Builds every `*.bend` file directly inside `dir`. */
export async function buildShared(dir: string, out: string): Promise<SharedModule[]> {
  let files: string[];
  try {
    files = readdirSync(dir)
      .filter((file) => file.endsWith(".bend"))
      .sort();
  } catch (error) {
    if (error instanceof Error && "code" in error && error.code === "ENOENT")
      throw new Error(`${dir}: no such directory. Shared Bend code lives in ${dir}/*.bend`);
    throw error;
  }
  if (files.length === 0) throw new Error(`${dir}: no .bend files to build`);
  const built: SharedModule[] = [];
  for (const file of files) built.push(await buildSharedModule(join(dir, file), out));
  return built;
}
