import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { basename, dirname, isAbsolute, join, resolve } from "node:path";
import type { ErrorPayload, HmrContext, ModuleNode, Plugin } from "vite";
import { Compiler, canonical, findBendPath, type CompilerOptions } from "./compiler.ts";
import type { Diagnostic } from "./diagnostic.ts";

export { Compiler, Gate, type Outcome } from "./compiler.ts";
export { locate, type Diagnostic, type Location } from "./diagnostic.ts";

export type BendoPluginOptions = {
  /** Path to the `bend` compiler. Defaults to `bend` on PATH, then `~/.bend/bin/bend`. */
  bend?: string;
  /** Write `<name>.d.bend.ts` beside each imported `.bend` file. Default `true`. */
  declarations?: boolean;
  /** Bend processes allowed at once. Default 1: one compile can use gigabytes. */
  concurrency?: number;
  /** Keep compiled modules in Vite's `cacheDir` across runs. Default `true`. */
  diskCache?: boolean;
  /** Replaces the Bend compile, for tests. */
  compile?: CompilerOptions["compile"];
};

const NAME = "vite-plugin-bendo";
// `?raw`, `?url` and friends ask Vite for the file itself, not its module.
const ASSET_QUERY = /(?:^|&)(?:raw|url|inline|worker|sharedworker)(?:[&=]|$)/;

/** Splits a Vite id into its file and query, or `undefined` if it is not a Bend module. */
export function bendFile(id: string): string | undefined {
  const question = id.indexOf("?");
  const path = question < 0 ? id : id.slice(0, question);
  const query = question < 0 ? "" : id.slice(question + 1);
  if (!path.endsWith(".bend") || ASSET_QUERY.test(query)) return undefined;
  return path;
}

/** Where the declarations for `file` go: TypeScript reads `x.d.bend.ts` for `import "./x.bend"`. */
export function declarationPath(file: string): string {
  return join(dirname(file), `${basename(file, ".bend")}.d.bend.ts`);
}

/** Resolves a `.bend` import to its absolute path, or `undefined` to leave it to Vite. */
export function resolveBend(
  source: string,
  importer: string | undefined,
  root: string,
): string | undefined {
  const file = bendFile(source);
  if (file === undefined) return undefined;
  const candidates: string[] = [];
  if (file.startsWith("./") || file.startsWith("../")) {
    if (importer === undefined) candidates.push(resolve(root, file));
    else
      candidates.push(
        resolve(dirname(bendFile(importer) ?? importer.split("?")[0] ?? importer), file),
      );
  } else if (isAbsolute(file)) {
    // `/shared/x.bend` is root-relative unless it already names a file under the root.
    if (file.startsWith(`${root}/`)) candidates.push(file);
    candidates.push(join(root, file), file);
  } else return undefined;
  const found = candidates.find((candidate) => existsSync(candidate));
  return found === undefined ? undefined : canonical(found);
}

function writeIfChanged(file: string, text: string): void {
  if (existsSync(file) && readFileSync(file, "utf8") === text) return;
  writeFileSync(file, text);
}

/** The error Vite shows in its overlay: message, `file:line:column` and the frame. */
export function overlayError(diagnostic: Diagnostic): ErrorPayload["err"] {
  return {
    message: diagnostic.message,
    stack: "",
    id: diagnostic.loc.file,
    frame: diagnostic.frame,
    plugin: NAME,
    loc: diagnostic.loc,
  };
}

function thrown(diagnostic: Diagnostic): Error {
  return Object.assign(new Error(diagnostic.message), overlayError(diagnostic));
}

/**
 * Lets a Vite app `import { check } from "./shared/signup.bend"`. Each import
 * compiles with Bend's JavaScript backend on demand. In dev, editing the file
 * or anything it imports recompiles it and sends an HMR update to its
 * importers; a compile error goes to the overlay and the page keeps running
 * the last good build.
 */
export default function bendo(options: BendoPluginOptions = {}): Plugin {
  let compiler: Compiler | undefined;
  let root = process.cwd();
  const writeDeclarations = options.declarations ?? true;

  const ready = (): Compiler => {
    if (compiler === undefined) throw new Error(`${NAME}: used before Vite resolved its config`);
    return compiler;
  };

  return {
    name: NAME,
    enforce: "pre",

    configResolved(config) {
      root = config.root;
      const bend = options.bend ?? findBendPath();
      if (bend === undefined)
        throw new Error(`${NAME}: bend not found. Install Bend from https://bend-lang.com`);
      compiler = new Compiler({
        bend,
        cacheDir: (options.diskCache ?? true) ? join(config.cacheDir, "bendo") : undefined,
        concurrency: options.concurrency ?? 1,
        ...(options.compile === undefined ? {} : { compile: options.compile }),
      });
    },

    resolveId(source, importer) {
      return resolveBend(source, importer, root) ?? null;
    },

    async load(id) {
      const file = bendFile(id);
      if (file === undefined || !existsSync(file)) return null;
      const outcome = await ready().compile(file);
      for (const dependency of outcome.files) this.addWatchFile(dependency);
      if (outcome.kind === "failed") throw thrown(outcome.diagnostic);
      if (outcome.fresh) for (const warning of outcome.compiled.warnings) this.warn(warning);
      if (writeDeclarations) writeIfChanged(declarationPath(file), outcome.compiled.declarations);
      // Bend emits no source map; an empty one stops Vite inventing one from the JS.
      return { code: outcome.compiled.module, map: { mappings: "" } };
    },

    async handleHotUpdate(context: HmrContext): Promise<ModuleNode[] | undefined> {
      const entries = ready().importersOf(context.file);
      if (entries.length === 0) return undefined;
      const graph = context.server.moduleGraph;
      const updated = new Set(context.modules);
      let failure: Diagnostic | undefined;
      for (const entry of entries) {
        const outcome = await ready().compile(entry);
        const modules = graph.getModulesByFile(entry) ?? new Set<ModuleNode>();
        // A reload must recompile, not reuse the last transform, even after a failure.
        for (const module of modules) graph.invalidateModule(module);
        if (outcome.kind === "failed") {
          failure ??= outcome.diagnostic;
          continue;
        }
        if (writeDeclarations)
          writeIfChanged(declarationPath(entry), outcome.compiled.declarations);
        for (const module of modules) updated.add(module);
      }
      if (failure !== undefined) {
        // Keep the page on its last good build; the next good save clears the overlay.
        context.server.ws.send({ type: "error", err: overlayError(failure) });
        return [];
      }
      return [...updated];
    },
  };
}
