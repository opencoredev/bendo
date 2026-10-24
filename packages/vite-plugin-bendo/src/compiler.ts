import { createHash } from "node:crypto";
import { accessSync, constants, existsSync, mkdirSync, readFileSync, realpathSync } from "node:fs";
import { writeFile, rename } from "node:fs/promises";
import { execFileSync } from "node:child_process";
import { delimiter, join, resolve } from "node:path";
import {
  BendCompileError,
  SharedIoError,
  compileShared,
  sourceGraph,
  type CompiledShared,
} from "bendo/shared";
import { ioDiagnostic, locate, type Diagnostic } from "./diagnostic.ts";

/** Bump when the cached shape or the generated code changes. */
const CACHE_FORMAT = "vite-plugin-bendo/1";
const GENERATOR = "vite-plugin-bendo";

export type Outcome =
  | { kind: "compiled"; compiled: CompiledShared; files: string[]; fresh: boolean }
  | { kind: "failed"; diagnostic: Diagnostic; files: string[] };

/** Canonical path, so watcher paths and import-graph paths compare equal. */
export function canonical(file: string): string {
  return existsSync(file) ? realpathSync(file) : resolve(file);
}

/** Finds `bend` on PATH or in ~/.bend/bin without Bun APIs, so Vite can run under Node. */
export function findBendPath(): string | undefined {
  const dirs = [
    ...(process.env.PATH ?? "").split(delimiter),
    join(process.env.HOME ?? "", ".bend/bin"),
  ];
  for (const dir of dirs) {
    if (dir === "") continue;
    const candidate = join(dir, "bend");
    try {
      accessSync(candidate, constants.X_OK);
      return candidate;
    } catch {
      continue;
    }
  }
  return undefined;
}

/** Runs at most `limit` tasks at once, in arrival order. */
export class Gate {
  private active = 0;
  private readonly waiting: (() => void)[] = [];
  private readonly limit: number;
  peak = 0;

  constructor(limit: number) {
    if (!Number.isInteger(limit) || limit < 1)
      throw new Error(`vite-plugin-bendo: concurrency must be a positive integer, got ${limit}`);
    this.limit = limit;
  }

  async run<T>(task: () => Promise<T>): Promise<T> {
    if (this.active >= this.limit) await new Promise<void>((go) => this.waiting.push(go));
    this.active++;
    this.peak = Math.max(this.peak, this.active);
    try {
      return await task();
    } finally {
      this.active--;
      this.waiting.shift()?.();
    }
  }
}

function isCompiledShared(value: unknown): value is CompiledShared {
  if (typeof value !== "object" || value === null) return false;
  const strings = (key: string) => typeof Reflect.get(value, key) === "string";
  const list = (key: string) => {
    const field: unknown = Reflect.get(value, key);
    return Array.isArray(field) && field.every((item) => typeof item === "string");
  };
  return (
    strings("source") &&
    strings("module") &&
    strings("declarations") &&
    list("named") &&
    list("warnings")
  );
}

export type CompilerOptions = {
  bend: string;
  /** Directory for compiled modules keyed by source hash; `undefined` keeps them in memory. */
  cacheDir: string | undefined;
  concurrency: number;
  /** Replaces the Bend compile, for tests of the queue and cache. */
  compile?: (entry: string) => Promise<CompiledShared>;
};

/**
 * Compiles `.bend` entries on demand. Results are keyed by a hash of every file
 * in the entry's import graph, so an unchanged graph is never recompiled, and
 * at most `concurrency` Bend processes run at once.
 */
export class Compiler {
  private readonly options: CompilerOptions;
  private readonly gate: Gate;
  /** The latest result per entry; older ones live only in the disk cache. */
  private readonly results = new Map<string, { hash: string; outcome: Outcome }>();
  private readonly pending = new Map<string, Promise<Outcome>>();
  /** Every file each compiled entry read, including the entry itself. */
  private readonly graphs = new Map<string, string[]>();
  /** The hash of each entry's newest snapshot, so a slower older compile cannot replace it. */
  private readonly wanted = new Map<string, string>();
  private bendVersion: string | undefined;
  compiles = 0;

  constructor(options: CompilerOptions) {
    this.options = options;
    this.gate = new Gate(options.concurrency);
  }

  get peakConcurrency(): number {
    return this.gate.peak;
  }

  /** Entries whose import graph contains `file`. */
  importersOf(file: string): string[] {
    const target = canonical(file);
    return [...this.graphs]
      .filter(([, files]) => files.includes(target))
      .map(([entry]) => entry)
      .sort();
  }

  private version(): string {
    if (this.bendVersion === undefined) {
      try {
        this.bendVersion = execFileSync(this.options.bend, ["version"], {
          encoding: "utf8",
          timeout: 5000,
        }).trim();
      } catch {
        this.bendVersion = "unknown";
      }
    }
    return this.bendVersion;
  }

  private snapshot(entry: string): { files: string[]; hash: string } {
    const hash = createHash("sha256").update(`${CACHE_FORMAT}\0${this.version()}\0`);
    const graph = sourceGraph(entry);
    for (const [file, content] of [...graph].sort(([a], [b]) => a.localeCompare(b)))
      hash.update(`${file}\0${content.length}\0`).update(content);
    return { files: [...graph.keys()], hash: hash.digest("hex") };
  }

  /** Compiles `file`, or returns the result for its unchanged import graph. */
  async compile(file: string): Promise<Outcome> {
    const entry = canonical(file);
    let snapshot: { files: string[]; hash: string };
    try {
      snapshot = this.snapshot(entry);
    } catch (error) {
      // A missing import: report it at the entry and keep watching what was read.
      const message = error instanceof Error ? error.message : String(error);
      const files = this.graphs.get(entry) ?? [entry];
      return {
        kind: "failed",
        diagnostic: { message, frame: "", loc: { file: entry, line: 1, column: 1 } },
        files,
      };
    }
    this.graphs.set(entry, snapshot.files);
    this.wanted.set(entry, snapshot.hash);
    const latest = this.results.get(entry);
    if (latest?.hash === snapshot.hash) {
      const known = latest.outcome;
      return known.kind === "compiled" ? { ...known, fresh: false } : known;
    }
    const running = this.pending.get(snapshot.hash);
    if (running !== undefined) return running;
    const work = this.gate
      .run(() => this.build(entry, snapshot))
      .finally(() => this.pending.delete(snapshot.hash));
    this.pending.set(snapshot.hash, work);
    return work;
  }

  private async build(
    entry: string,
    snapshot: { files: string[]; hash: string },
  ): Promise<Outcome> {
    const cached = this.readDisk(snapshot.hash);
    if (cached !== undefined) {
      const outcome: Outcome = {
        kind: "compiled",
        compiled: cached,
        files: snapshot.files,
        fresh: false,
      };
      this.remember(entry, snapshot.hash, outcome);
      return outcome;
    }
    this.compiles++;
    let outcome: Outcome;
    try {
      const compiled = await (
        this.options.compile ?? ((path) => compileShared(path, this.options.bend, GENERATOR))
      )(entry);
      outcome = { kind: "compiled", compiled, files: snapshot.files, fresh: true };
      await this.writeDisk(snapshot.hash, compiled);
    } catch (error) {
      if (error instanceof BendCompileError)
        outcome = {
          kind: "failed",
          diagnostic: locate(error.output, entry, snapshot.files),
          files: snapshot.files,
        };
      else if (error instanceof SharedIoError)
        outcome = {
          kind: "failed",
          diagnostic: ioDiagnostic(error.message, entry, error.defs),
          files: snapshot.files,
        };
      else throw error;
    }
    this.remember(entry, snapshot.hash, outcome);
    return outcome;
  }

  private remember(entry: string, hash: string, outcome: Outcome): void {
    if (this.wanted.get(entry) === hash) this.results.set(entry, { hash, outcome });
  }

  private readDisk(hash: string): CompiledShared | undefined {
    if (this.options.cacheDir === undefined) return undefined;
    try {
      const value: unknown = JSON.parse(
        readFileSync(join(this.options.cacheDir, `${hash}.json`), "utf8"),
      );
      return isCompiledShared(value) ? value : undefined;
    } catch {
      return undefined;
    }
  }

  private async writeDisk(hash: string, compiled: CompiledShared): Promise<void> {
    const dir = this.options.cacheDir;
    if (dir === undefined) return;
    mkdirSync(dir, { recursive: true });
    const target = join(dir, `${hash}.json`);
    const temporary = `${target}.${process.pid}.tmp`;
    await writeFile(temporary, JSON.stringify(compiled));
    await rename(temporary, target);
  }
}
