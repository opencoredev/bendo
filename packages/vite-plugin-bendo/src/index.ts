import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { basename, dirname, isAbsolute, join, resolve } from "node:path";
import type {
  DevEnvironment,
  EnvironmentModuleNode,
  ErrorPayload,
  HotUpdateOptions,
  Plugin,
  ViteDevServer,
} from "vite";
import { Compiler, canonical, findBendPath, type CompilerOptions } from "./compiler.ts";
import type { Diagnostic } from "./diagnostic.ts";
import { FileWatcher } from "./watch.ts";

export { Compiler, Gate, type Outcome } from "./compiler.ts";
export { locate, type Diagnostic, type Location, type Place } from "./diagnostic.ts";

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

/** For tests and debugging: what the plugin itself watches. */
export type BendoApi = {
  /** Files outside Vite's root the plugin watches, sorted. Empty outside dev. */
  watchedFiles(): string[];
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

/**
 * Whether the plugin compiles `module`. Vite loads every other module for a
 * `.bend` file, such as `?raw`, so it watches the file and updates those.
 */
function managed(module: EnvironmentModuleNode): boolean {
  return bendFile(module.id ?? module.url) !== undefined;
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
  const base = { stack: "", frame: diagnostic.frame, plugin: NAME };
  const place = diagnostic.place;
  switch (place.kind) {
    case "located":
      return { ...base, message: diagnostic.message, id: place.loc.file, loc: place.loc };
    case "ambiguous":
      return {
        ...base,
        id: place.entry,
        message: [
          diagnostic.message,
          "",
          `Location ambiguous: Bend names no file, and its code frame matches ${place.candidates.length} files:`,
          ...place.candidates.map((file) => `  ${file}`),
        ].join("\n"),
      };
    case "unknown":
      return {
        ...base,
        id: place.entry,
        message: `${diagnostic.message}\n\nLocation unknown: Bend names no file, and its code frame matches none in the import graph.`,
      };
    default: {
      const _exhaustive: never = place;
      return _exhaustive;
    }
  }
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
export default function bendo(options: BendoPluginOptions = {}): Plugin & { api: BendoApi } {
  let settings: CompilerOptions | undefined;
  let compiler: Compiler | undefined;
  let server: ViteDevServer | undefined;
  let root = process.cwd();
  const writeDeclarations = options.declarations ?? true;

  const ready = (): Compiler => {
    if (compiler === undefined) throw new Error(`${NAME}: used before Vite resolved its config`);
    return compiler;
  };

  const dispose = async (): Promise<void> => {
    await compiler?.dispose();
  };

  /** Writes declarations unless Vite closed while the compile ran. */
  const declare = (file: string, text: string): void => {
    if (writeDeclarations && !ready().disposed) writeIfChanged(declarationPath(file), text);
  };

  // Vite watches the root. Every file outside it that a graph reaches, the
  // entry and missing files included, gets a watch in the plugin's own
  // watcher, counted per entry so it is dropped once no graph reaches it.
  // Vite's watcher is shared with other plugins, so the plugin never adds
  // or removes those paths there.
  let watcher: FileWatcher | undefined;
  const external = new Map<string, Set<string>>();
  const outsideRoot = (file: string) => !file.startsWith(`${root}/`);

  const watchExternal = (entry: string, files: readonly string[]): void => {
    if (watcher === undefined) return;
    watcher.reopen();
    const next = new Set(files.filter(outsideRoot));
    const previous = external.get(entry) ?? new Set<string>();
    if (next.size > 0) external.set(entry, next);
    else external.delete(entry);
    for (const file of next) if (!previous.has(file)) watcher.add(file);
    for (const file of previous) if (!next.has(file)) watcher.remove(file);
  };

  /** Recompiles the entries that read `file`, and finds the modules to update in `environment`. */
  const refresh = async (
    environment: DevEnvironment,
    file: string,
  ): Promise<
    | { kind: "updated"; modules: EnvironmentModuleNode[] }
    | { kind: "failed"; diagnostic: Diagnostic }
    | { kind: "cancelled" }
  > => {
    const { moduleGraph } = environment;
    const updated: EnvironmentModuleNode[] = [];
    let failure: Diagnostic | undefined;
    for (const entry of ready().importersOf(file)) {
      const outcome = await ready().compile(entry);
      if (outcome.kind === "cancelled") return outcome;
      watchExternal(entry, outcome.files);
      const modules = [...(moduleGraph.getModulesByFile(entry) ?? [])].filter(managed);
      // A reload must recompile, not reuse the last transform, even after a failure.
      for (const module of modules) moduleGraph.invalidateModule(module);
      if (outcome.kind === "failed") {
        // Only an environment that loaded the entry shows its error.
        if (modules.length > 0) failure ??= outcome.diagnostic;
        continue;
      }
      declare(entry, outcome.compiled.declarations);
      updated.push(...modules);
    }
    return failure === undefined
      ? { kind: "updated", modules: updated }
      : { kind: "failed", diagnostic: failure };
  };

  /** The plugin's watcher saw `file` change: the same update `hotUpdate` makes, in every environment. */
  const externalChange = async (dev: ViteDevServer, file: string): Promise<void> => {
    for (const environment of Object.values(dev.environments)) {
      const result = await refresh(environment, file);
      switch (result.kind) {
        case "cancelled":
          return;
        case "failed":
          environment.hot.send({ type: "error", err: overlayError(result.diagnostic) });
          break;
        case "updated":
          for (const module of result.modules) await environment.reloadModule(module);
          break;
        default: {
          const _exhaustive: never = result;
          return _exhaustive;
        }
      }
    }
  };

  const closeWatcher = (): void => {
    watcher?.close();
    watcher = undefined;
    external.clear();
  };

  /**
   * Stops what `configureServer` started for one server. A restart configures
   * the new server before the old one's HTTP server closes, so leave the new
   * server's compiler and watcher running.
   */
  const stopServer = async (mine: {
    compiler: Compiler | undefined;
    watcher: FileWatcher | undefined;
  }) => {
    if (mine.watcher !== undefined && watcher === mine.watcher) closeWatcher();
    await mine.compiler?.dispose();
  };

  return {
    name: NAME,
    enforce: "pre",

    configResolved(config) {
      root = config.root;
      const bend = options.bend ?? findBendPath();
      if (bend === undefined)
        throw new Error(`${NAME}: bend not found. Install Bend from https://bend-lang.com`);
      // A restarted dev server resolves its config again; stop the old compiler.
      void dispose();
      settings = {
        bend,
        cacheDir: (options.diskCache ?? true) ? join(config.cacheDir, "bendo") : undefined,
        concurrency: options.concurrency ?? 1,
        ...(options.compile === undefined ? {} : { compile: options.compile }),
      };
      compiler = new Compiler(settings);
    },

    configureServer(dev) {
      server = dev;
      closeWatcher();
      // `server.watch: null` turns file watching off.
      if (dev.config.server.watch !== null) {
        // One change at a time, in the order the files changed.
        let queue = Promise.resolve();
        watcher = new FileWatcher((file) => {
          queue = queue
            .then(() => externalChange(dev, file))
            .catch((error: unknown) =>
              dev.config.logger.error(`${NAME}: updating after ${file} changed failed: ${error}`),
            );
        });
      }
      const mine = { compiler, watcher };
      // Stop Bend before Vite's close, which also waits for requests in flight.
      const close = dev.close.bind(dev);
      dev.close = async () => {
        await stopServer(mine);
        await close();
      };
      dev.httpServer?.once("close", () => void stopServer(mine));
    },

    // A watch-mode build closes its bundle after every run; start afresh.
    buildStart() {
      if (settings !== undefined && compiler?.disposed === true) compiler = new Compiler(settings);
    },

    async closeBundle() {
      // A dev server stops Bend in its own close. A restart closes the old
      // server's bundle after the new server started, so leave its compiler be.
      if (server === undefined) await dispose();
    },

    resolveId(source, importer) {
      return resolveBend(source, importer, root) ?? null;
    },

    async load(id) {
      const file = bendFile(id);
      if (file === undefined || !existsSync(file)) return null;
      const outcome = await ready().compile(file);
      if (outcome.kind === "cancelled")
        throw new Error(`${NAME}: Vite closed while ${file} compiled`);
      // In dev, a file outside the root goes to the plugin's own watcher instead.
      for (const dependency of outcome.files)
        if (server === undefined || !outsideRoot(dependency)) this.addWatchFile(dependency);
      watchExternal(canonical(file), outcome.files);
      if (outcome.kind === "failed") throw thrown(outcome.diagnostic);
      if (outcome.fresh) for (const warning of outcome.compiled.warnings) this.warn(warning);
      declare(file, outcome.compiled.declarations);
      // Bend emits no source map; an empty one stops Vite inventing one from the JS.
      return { code: outcome.compiled.module, map: { mappings: "" } };
    },

    // `hotUpdate` (Vite 6+) also fires on create and delete, which
    // `handleHotUpdate` does not see in Vite 8. It runs once per environment.
    async hotUpdate(update: HotUpdateOptions): Promise<EnvironmentModuleNode[] | undefined> {
      // Vite reports a file outside the root only when another plugin watches
      // it; the plugin's own watcher already handles it, and sends the Bend
      // modules' update once their compile succeeds. Vite must not update
      // them first, or a broken save would reach the browser before its
      // error. Other modules for the file, such as `?raw`, keep Vite's update.
      if (watcher !== undefined && outsideRoot(update.file)) {
        const others = update.modules.filter((module) => !managed(module));
        return others.length === update.modules.length ? undefined : others;
      }
      if (ready().importersOf(update.file).length === 0) return undefined;
      const result = await refresh(this.environment, update.file);
      switch (result.kind) {
        case "cancelled":
          return [];
        case "failed":
          // Keep the page on its last good build; the next good save clears the overlay.
          this.environment.hot.send({ type: "error", err: overlayError(result.diagnostic) });
          return [];
        case "updated":
          return [...new Set([...update.modules, ...result.modules])];
        default: {
          const _exhaustive: never = result;
          return _exhaustive;
        }
      }
    },

    api: {
      watchedFiles: () => watcher?.files ?? [],
    },
  };
}
