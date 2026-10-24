import { statSync, watch, type FSWatcher } from "node:fs";
import { basename, dirname, join } from "node:path";

/** Events for one file closer together than this arrive as one change. */
const SETTLE_MS = 30;

/** An `fs.watch` handle and the directory it is attached to. */
type Handle = { watcher: FSWatcher; identity: string };

type Directory = {
  /** `undefined` while the directory does not exist or cannot be watched. */
  own: Handle | undefined;
  /** Watches the parent, which sees the directory removed, renamed or created. */
  parent: Handle | undefined;
  /** Each watched file's name and how many holders want it. */
  files: Map<string, number>;
  /** Whether `check` has run, so the first attach reports nothing. */
  checked: boolean;
};

/**
 * Tells one directory at `path` from another that replaced it, or returns
 * `undefined` if `path` is not a directory. Filesystems such as ext4 hand a
 * recreated directory its predecessor's inode at once; the birth time differs.
 */
function identity(path: string): string | undefined {
  try {
    const stats = statSync(path);
    return stats.isDirectory() ? `${stats.dev}:${stats.ino}:${stats.birthtimeMs}` : undefined;
  } catch {
    return undefined;
  }
}

/**
 * Watches files, missing ones included, with one `fs.watch` per directory.
 * The plugin uses it for paths outside Vite's root, so it never adds to or
 * removes from the watcher Vite shares with other plugins. Each `add` needs a
 * matching `remove`; a file stays watched while anyone holds it.
 *
 * A watch follows the directory's inode, so a directory that is deleted or
 * renamed and then recreated would go quiet. A second watch on the parent
 * sees the directory leave or return, and `reopen` checks each directory is
 * still the one watched. Either way the stale watch is replaced and every file
 * held in the directory counts as changed.
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
      directory = { own: undefined, parent: undefined, files: new Map(), checked: false };
      this.directories.set(dir, directory);
    }
    directory.files.set(name, (directory.files.get(name) ?? 0) + 1);
    this.check(dir, false);
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
    directory.own?.watcher.close();
    directory.parent?.watcher.close();
    this.directories.delete(dir);
  }

  /** Reattaches every directory that was missing, failed, or was replaced since it was watched. */
  reopen(): void {
    if (this.closed) return;
    for (const dir of this.directories.keys()) this.check(dir, false);
  }

  close(): void {
    this.closed = true;
    for (const { own, parent } of this.directories.values()) {
      own?.watcher.close();
      parent?.watcher.close();
    }
    this.directories.clear();
    for (const timer of this.timers.values()) clearTimeout(timer);
    this.timers.clear();
  }

  /**
   * Brings `dir`'s watches up to date with the disk; `moved` reattaches even
   * if the directory looks the same, because an event said it was renamed.
   * If the directory came, went or was replaced, its files may have changed
   * without an event, so each one held there is reported.
   */
  private check(dir: string, moved: boolean): void {
    const directory = this.directories.get(dir);
    if (directory === undefined || this.closed) return;
    const parent = dirname(dir);
    if (directory.parent?.identity !== identity(parent)) {
      directory.parent?.watcher.close();
      const handle = this.open(parent, (event, name) => {
        if (this.directories.get(dir)?.parent !== handle) return;
        if (name === null || name === basename(dir)) this.check(dir, event === "rename");
      });
      directory.parent = handle;
    }
    const current = identity(dir);
    if (!moved && directory.own !== undefined && directory.own.identity === current) return;
    const report = directory.checked && (directory.own !== undefined || current !== undefined);
    directory.checked = true;
    directory.own?.watcher.close();
    const handle = this.open(dir, (event, name) => {
      const now = this.directories.get(dir);
      // A closed watch can still deliver events it queued.
      if (now === undefined || now.own !== handle) return;
      if (name !== null && now.files.has(name)) this.changed(join(dir, name));
      // A watch reports its own directory's deletion or move under the directory's name.
      else this.check(dir, event === "rename" && name === basename(dir));
    });
    directory.own = handle;
    if (report) for (const name of directory.files.keys()) this.changed(join(dir, name));
  }

  /** Watches `dir`, or returns `undefined` if it cannot be watched, such as when it is missing. */
  private open(
    dir: string,
    listener: (event: string, name: string | null) => void,
  ): Handle | undefined {
    const id = identity(dir);
    if (id === undefined) return undefined;
    let watcher: FSWatcher;
    try {
      watcher = watch(dir, { persistent: false }, listener);
    } catch {
      return undefined;
    }
    // The directory was deleted or became unreadable: recheck it, which keeps
    // its holders and reattaches once it returns.
    watcher.on("error", () => {
      watcher.close();
      for (const [path, directory] of this.directories) {
        const own = directory.own?.watcher === watcher;
        const parent = directory.parent?.watcher === watcher;
        if (own) directory.own = undefined;
        if (parent) directory.parent = undefined;
        if (own || parent) this.check(path, false);
      }
    });
    return { watcher, identity: id };
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
