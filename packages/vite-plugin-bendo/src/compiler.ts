import { createHash } from "node:crypto";
import {
  accessSync,
  constants,
  existsSync,
  mkdirSync,
  readFileSync,
  realpathSync,
  statSync,
} from "node:fs";
import { rename, rm, writeFile } from "node:fs/promises";
import { execFileSync } from "node:child_process";
import { delimiter, join, resolve } from "node:path";
import {
  BendCompileError,
  SharedIoError,
  compileShared,
  sourceGraph,
  type CompiledShared,
} from "bendo/shared";
import { at, ioDiagnostic, locate, type Diagnostic } from "./diagnostic.ts";

/** Bump when the cached shape or the generated code changes. */
const CACHE_FORMAT = "vite-plugin-bendo/1";
const GENERATOR = "vite-plugin-bendo";
/** Compiles of one entry whose files kept changing before the plugin gives up. */
const ATTEMPTS = 3;

export type Outcome =
  | { kind: "compiled"; compiled: CompiledShared; files: string[]; fresh: boolean }
  | { kind: "failed"; diagnostic: Diagnostic; files: string[] }
  /** The compiler was disposed first; nothing was cached. */
  | { kind: "cancelled" };

/** One compile attempt; `stale` means a file changed while Bend read it. */
type Attempt = Outcome | { kind: "stale" };

type Snapshot = { files: string[]; hash: string };

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
  compile?: (entry: string, signal: AbortSignal) => Promise<CompiledShared>;
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
  private readonly pending = new Map<string, Promise<Attempt>>();
  /** Every file each compiled entry read, including the entry itself. */
  private readonly graphs = new Map<string, string[]>();
  /** The hash of each entry's newest snapshot, so a slower older compile cannot replace it. */
  private readonly wanted = new Map<string, string>();
  /** `bend version`, rerun when the binary's mtime or size changes. */
  private bendVersion: { stamp: string; version: string } | undefined;
  /** Aborted by `dispose`, which kills the running Bend process. */
  private readonly lifetime = new AbortController();
  compiles = 0;

  constructor(options: CompilerOptions) {
    this.options = options;
    this.gate = new Gate(options.concurrency);
  }

  get peakConcurrency(): number {
    return this.gate.peak;
  }

  get disposed(): boolean {
    return this.lifetime.signal.aborted;
  }

  /**
   * Stops for good: queued compiles never start, the running Bend process and
   * its children are killed, and nothing more is written to the cache.
   * Resolves once every compile in flight has settled.
   */
  async dispose(): Promise<void> {
    this.lifetime.abort();
    await Promise.allSettled(this.pending.values());
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
    let stamp = "missing";
    try {
      const stat = statSync(this.options.bend);
      stamp = `${stat.mtimeMs}:${stat.size}`;
    } catch {
      // Hash as "unknown" below; the compile itself reports the missing binary.
    }
    if (this.bendVersion?.stamp !== stamp) {
      let version = "unknown";
      try {
        version = execFileSync(this.options.bend, ["version"], {
          encoding: "utf8",
          timeout: 5000,
        }).trim();
      } catch {
        // An unreadable version still hashes consistently.
      }
      this.bendVersion = { stamp, version };
    }
    return this.bendVersion.version;
  }

  /**
   * Hashes every file in the entry's import graph. A missing import throws;
   * by then `onFile` has seen every path reached, the missing one included.
   */
  private snapshot(entry: string, onFile?: (file: string) => void): Snapshot {
    const hash = createHash("sha256").update(`${CACHE_FORMAT}\0${this.version()}\0`);
    const graph = sourceGraph(entry, onFile);
    for (const [file, content] of [...graph].sort(([a], [b]) => a.localeCompare(b)))
      hash.update(`${file}\0${content.length}\0`).update(content);
    return { files: [...graph.keys()], hash: hash.digest("hex") };
  }

  /** Compiles `file`, or returns the result for its unchanged import graph. */
  async compile(file: string): Promise<Outcome> {
    const entry = canonical(file);
    for (let attempt = 1; ; attempt++) {
      if (this.disposed) return { kind: "cancelled" };
      const outcome = await this.attempt(entry);
      if (outcome.kind !== "stale") return outcome;
      if (attempt === ATTEMPTS)
        return {
          kind: "failed",
          diagnostic: at(
            `${entry}: its files changed during each of ${ATTEMPTS} compiles; save again to retry`,
            entry,
          ),
          files: this.graphs.get(entry) ?? [entry],
        };
    }
  }

  private async attempt(entry: string): Promise<Attempt> {
    let snapshot: Snapshot;
    const reached = new Set<string>();
    try {
      snapshot = this.snapshot(entry, (file) => reached.add(file));
    } catch (error) {
      // A missing file: report it at the entry and watch every file reached,
      // the missing one too, so creating it recompiles the entry. Files the
      // last graph reached past it cannot fix the error, so they are dropped;
      // a deleted entry keeps only itself.
      const message = error instanceof Error ? error.message : String(error);
      const files = [...new Set([entry, ...reached])];
      this.graphs.set(entry, files);
      return { kind: "failed", diagnostic: at(message, entry), files };
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

  /** Whether the graph still hashes to `hash`, after Bend read the live files. */
  private unchanged(entry: string, hash: string): boolean {
    try {
      return this.snapshot(entry).hash === hash;
    } catch {
      return false;
    }
  }

  private async build(entry: string, snapshot: Snapshot): Promise<Attempt> {
    // Queued behind a compile that `dispose` stopped.
    if (this.disposed) return { kind: "cancelled" };
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
    const signal = this.lifetime.signal;
    try {
      const compiled = await (
        this.options.compile ??
        ((path, stop) =>
          compileShared(path, this.options.bend, { generator: GENERATOR, signal: stop }))
      )(entry, signal);
      outcome = { kind: "compiled", compiled, files: snapshot.files, fresh: true };
    } catch (error) {
      if (signal.aborted) return { kind: "cancelled" };
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
    if (signal.aborted) return { kind: "cancelled" };
    // Bend read the files after the snapshot. If one changed meanwhile, this
    // result may belong to newer text than `snapshot.hash` names: drop it.
    if (!this.unchanged(entry, snapshot.hash)) return { kind: "stale" };
    if (outcome.kind === "compiled") await this.writeDisk(snapshot.hash, outcome.compiled);
    if (signal.aborted) return { kind: "cancelled" };
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
    if (dir === undefined || this.disposed) return;
    mkdirSync(dir, { recursive: true });
    const target = join(dir, `${hash}.json`);
    const temporary = `${target}.${process.pid}.tmp`;
    await writeFile(temporary, JSON.stringify(compiled));
    if (this.disposed) await rm(temporary, { force: true });
    else await rename(temporary, target);
  }
}
