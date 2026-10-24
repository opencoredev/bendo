import { watch, type FSWatcher } from "node:fs";
import { basename, dirname, join } from "node:path";

/** Events for one file closer together than this arrive as one change. */
const SETTLE_MS = 30;

type Directory = {
  /** `undefined` while the directory does not exist. */
  watcher: FSWatcher | undefined;
  /** Each watched file's name and how many holders want it. */
  files: Map<string, number>;
};

/**
 * Watches files, missing ones included, with one `fs.watch` per directory.
 * The plugin uses it for paths outside Vite's root, so it never adds to or
 * removes from the watcher Vite shares with other plugins. Each `add` needs a
 * matching `remove`; a file stays watched while anyone holds it.
 */
export class FileWatcher {
  private readonly directories = new Map<string, Directory>();
  private readonly timers = new Map<string, ReturnType<typeof setTimeout>>();
  private readonly onChange: (file: string) => void;
  private closed = false;

  constructor(onChange: (file: string) => void) {
    this.onChange = onChange;
  }

  /** Every file held, sorted. */
  get files(): string[] {
    return [...this.directories]
      .flatMap(([dir, { files }]) => [...files.keys()].map((name) => join(dir, name)))
      .sort();
  }

  add(file: string): void {
    if (this.closed) return;
    const dir = dirname(file);
    const name = basename(file);
    let directory = this.directories.get(dir);
    if (directory === undefined) {
      directory = { watcher: undefined, files: new Map() };
      this.directories.set(dir, directory);
    }
    // Retry a directory that was missing or failed before.
    directory.watcher ??= this.open(dir);
    directory.files.set(name, (directory.files.get(name) ?? 0) + 1);
  }

  remove(file: string): void {
    const dir = dirname(file);
    const name = basename(file);
    const directory = this.directories.get(dir);
    const count = directory?.files.get(name);
    if (directory === undefined || count === undefined) return;
    if (count > 1) {
      directory.files.set(name, count - 1);
      return;
    }
    directory.files.delete(name);
    this.settle(file);
    if (directory.files.size > 0) return;
    directory.watcher?.close();
    this.directories.delete(dir);
  }

  /** Retries every directory that was missing or failed. */
  reopen(): void {
    if (this.closed) return;
    for (const [dir, directory] of this.directories) directory.watcher ??= this.open(dir);
  }

  close(): void {
    this.closed = true;
    for (const { watcher } of this.directories.values()) watcher?.close();
    this.directories.clear();
    for (const timer of this.timers.values()) clearTimeout(timer);
    this.timers.clear();
  }

  /** Watches `dir`, or returns `undefined` if it cannot be watched, such as when it is missing. */
  private open(dir: string): FSWatcher | undefined {
    let watcher: FSWatcher;
    try {
      watcher = watch(dir, { persistent: false }, (_event, name) => {
        if (name !== null && this.directories.get(dir)?.files.has(name) === true)
          this.changed(join(dir, name));
      });
    } catch {
      return undefined;
    }
    // The directory was deleted or became unreadable: keep its holders, and
    // let a later `add` reopen it.
    watcher.on("error", () => {
      watcher.close();
      const directory = this.directories.get(dir);
      if (directory?.watcher === watcher) directory.watcher = undefined;
    });
    return watcher;
  }

  /** Coalesces the burst of events one save produces. */
  private changed(file: string): void {
    this.settle(file);
    this.timers.set(
      file,
      setTimeout(() => {
        this.timers.delete(file);
        if (!this.closed) this.onChange(file);
      }, SETTLE_MS),
    );
  }

  private settle(file: string): void {
    const timer = this.timers.get(file);
    if (timer === undefined) return;
    clearTimeout(timer);
    this.timers.delete(file);
  }
}
