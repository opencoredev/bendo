import { createHash } from "node:crypto";
import {
  existsSync,
  mkdirSync,
  readFileSync,
  renameSync,
  rmSync,
  mkdtempSync,
  writeFileSync,
} from "node:fs";
import { dirname, extname, join, resolve } from "node:path";
import { spawn, type ChildProcess } from "node:child_process";
import { stripVTControlCharacters } from "node:util";
import { findBend } from "./bend.ts";

export const log = (message: string): void => {
  process.stdout.write(`${message}\n`);
};

/** Kill the whole compiler/server group, including native toolchain descendants. */
export async function stop(child: ChildProcess): Promise<void> {
  const pid = child.pid;
  if (pid === undefined) return;
  const signal = (value: NodeJS.Signals): void => {
    try {
      process.kill(-pid, value);
    } catch (error) {
      if (!(error instanceof Error && "code" in error && error.code === "ESRCH")) throw error;
    }
  };
  const exited = (): boolean => child.exitCode !== null || child.signalCode !== null;
  const wait = (timeout: number): Promise<void> =>
    new Promise((done) => {
      if (exited()) return done();
      const finish = (): void => {
        clearTimeout(timer);
        child.removeListener("exit", finish);
        done();
      };
      const timer = setTimeout(finish, timeout);
      child.once("exit", finish);
    });
  signal("SIGTERM");
  await wait(500);
  signal("SIGKILL");
  await wait(2000);
  if (!exited()) throw new Error(`Process ${pid} did not exit after SIGKILL`);
}

export function launch(binary: string): ChildProcess {
  return spawn(binary, [], { detached: true, stdio: "inherit" });
}

/** Parse Bend's source excerpt diagnostics before presenting them to CLI users. */
export function compilerDiagnostic(
  output: string,
  entry: string,
  files: ReadonlyMap<string, Buffer>,
): string {
  const plain = stripVTControlCharacters(output).trim();
  const line = /^\s*(\d+)>\|/m.exec(plain)?.[1] ?? "1";
  const excerpt = /^\s*\d+>\| ?(.*)$/m.exec(plain)?.[1];
  const matches =
    excerpt === undefined
      ? []
      : [...files].filter(([file, content]) => {
          if (extname(file) !== ".bend") return false;
          return content.toString().split("\n")[Number(line) - 1] === excerpt;
        });
  const location =
    /([^\s"']+\.bend)(?::\d+)?/.exec(plain)?.[1] ??
    (matches.length === 1 ? matches[0]?.[0] : entry);
  const message = plain
    .split("Location:")[0]
    ?.replace(/^(?:ALL PROOFS CHECK|SOME PROOFS FAIL)\s*/g, "")
    .trim();
  return `${location}:${line}: ${message || "Bend compilation failed"}`;
}

/** Decision 0003 integration point. Replace this stage when BND-33–35 codegen lands. */
export async function generateSchemas(): Promise<void> {
  log("generate: schema generation pending BND-33–35 (no production generator)");
}

export class Pipeline {
  private child: ChildProcess | undefined;
  private cancelled = false;

  async close(): Promise<void> {
    this.cancelled = true;
    if (this.child) await stop(this.child);
  }

  async build(entry: string): Promise<string> {
    if (this.cancelled) throw new Error("Build cancelled");
    await generateSchemas();
    const bend = findBend();
    if (bend.kind === "missing")
      throw new Error("bend not found. Install Bend from https://bend-lang.com");
    const source = resolve(entry);
    const hash = createHash("sha256");
    // Include the native toolchain and foreign-effect twins, as in tests/harness.ts.
    hash.update(
      JSON.stringify(["bendo-cli-v2", bend.path, bend.version, process.platform, process.arch]),
    );
    for (const command of [
      [bend.path, "version"],
      ["cc", "--version"],
      ["clang", "--version"],
      ["ldd", "--version"],
    ]) {
      const run = Bun.spawnSync(command, { stdout: "pipe", stderr: "pipe", timeout: 5000 });
      hash.update(`${run.stdout}${run.stderr}`);
    }
    hash.update(readFileSync(bend.path));
    const graph = new Map<string, Buffer>();
    const visit = (file: string): void => {
      if (graph.has(file)) return;
      const content = readFileSync(file);
      graph.set(file, content);
      hash.update(JSON.stringify([file, content.length]));
      hash.update(content);
      if (extname(file) !== ".bend") return;
      for (const match of content
        .toString()
        .matchAll(/^\s*import\s+(?:"([^"\n]+)"|(\.{1,2}\/[^\s]+))/gm)) {
        const imported = match[1] ?? match[2];
        if (!imported) continue;
        const dependency = resolve(dirname(file), imported);
        visit(dependency);
        if (/\.(c|js)$/.test(dependency)) {
          const twin = dependency.replace(/\.(c|js)$/, dependency.endsWith(".c") ? ".js" : ".c");
          if (existsSync(twin)) visit(twin);
        }
      }
    };
    visit(source);
    const cache = resolve(".cache/bendo", hash.digest("hex"));
    const binary = join(cache, "server");
    if (existsSync(binary)) {
      log("compile: cache hit");
      return binary;
    }
    mkdirSync(cache, { recursive: true });
    const temporary = mkdtempSync(join(cache, ".compile-"));
    const output = join(temporary, "server");
    // Compile an immutable tree. A save followed by an undo must never publish
    // a binary made from intermediate live contents under the original hash.
    for (const [file, contents] of graph) {
      const snapshot = join(temporary, "sources", file);
      mkdirSync(dirname(snapshot), { recursive: true });
      const snapshotContents =
        extname(file) === ".bend"
          ? contents
              .toString()
              .replace(
                /(^\s*import\s+")(\/[^"\n]+)"/gm,
                (_match, prefix: string, imported: string) =>
                  `${prefix}${join(temporary, "sources", imported)}"`,
              )
          : contents;
      writeFileSync(snapshot, snapshotContents);
    }
    const snapshotEntry = join(temporary, "sources", source);
    const started = performance.now();
    log(`compile: ${entry}`);
    try {
      await new Promise<void>((done, reject) => {
        const child = spawn(bend.path, [snapshotEntry, "-o", output], {
          detached: true,
          stdio: ["ignore", "pipe", "pipe"],
        });
        this.child = child;
        let text = "";
        let timedOut = false;
        child.stdout?.on("data", (data: Buffer) => {
          text += data.toString();
        });
        child.stderr?.on("data", (data: Buffer) => {
          text += data.toString();
        });
        const timer = setTimeout(() => {
          timedOut = true;
          void stop(child).then(
            () => reject(new Error(`${entry}:1: compiler timed out after 180s`)),
            reject,
          );
        }, 180_000);
        child.once("error", (error) => {
          clearTimeout(timer);
          reject(error);
        });
        child.once("close", (code) => {
          clearTimeout(timer);
          if (timedOut) reject(new Error(`${entry}:1: compiler timed out after 180s`));
          else if (code === 0 && !this.cancelled) done();
          else reject(new Error(compilerDiagnostic(text, entry, graph)));
        });
      });
      renameSync(output, binary);
      log(`compile: ready in ${Math.round(performance.now() - started)}ms`);
      return binary;
    } finally {
      this.child = undefined;
      rmSync(temporary, { recursive: true, force: true });
    }
  }
}
