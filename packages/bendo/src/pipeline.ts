import { createHash } from "node:crypto";
import {
  existsSync,
  mkdirSync,
  readFileSync,
  renameSync,
  rmSync,
  mkdtempSync,
  writeFileSync,
  realpathSync,
} from "node:fs";
import { extname, join, resolve } from "node:path";
import { spawn, type ChildProcess } from "node:child_process";
import { stripVTControlCharacters } from "node:util";
import { findBend } from "./bend.ts";
import { fetchManifest, type Manifest } from "./manifest.ts";
import { writeRouteTypes } from "./route-types.ts";
import { mapImports, sourceGraph } from "./sources.ts";

export type Target = "js" | "native";
export class BuildCancelled extends Error {
  constructor() {
    super("Build cancelled");
  }
}

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

export function launch(binary: string, env = process.env): ChildProcess {
  return spawn(
    binary.endsWith(".js") ? process.execPath : binary,
    binary.endsWith(".js") ? [binary] : [],
    { detached: true, stdio: "inherit", env },
  );
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
  // Prefer a compiler-supplied source path when available. Bend 2.0.38
  // often emits only an unqualified definition name and an excerpt.
  const located = [...files.keys()].filter((file) => plain.includes(file));
  const location =
    (located.length === 1 ? located[0] : undefined) ??
    (matches.length === 1 ? matches[0]?.[0] : undefined);
  const message = plain
    .split("Location:")[0]
    ?.replace(/^(?:ALL PROOFS CHECK|SOME PROOFS FAIL)\s*/g, "")
    .trim();
  if (location !== undefined) return `${location}:${line}: ${message || "Bend compilation failed"}`;
  const candidates = matches.map(([file]) => `${file}:${line}`).join(", ");
  return `${entry}: location ${matches.length > 1 ? `ambiguous (${candidates})` : "unavailable"}: ${plain || "Bend compilation failed"}`;
}

/** Precompile schema seam; the manifest phase runs only after an app exists. */
export async function generateSchemas(): Promise<void>;
export async function generateSchemas(binary: string): Promise<Manifest>;
export async function generateSchemas(binary?: string): Promise<void | Manifest> {
  if (binary === undefined) {
    log("generate: schema generation pending BND-34/35 (no production generator)");
    return;
  }
  const manifest = fetchManifest(binary);
  writeRouteTypes(manifest);
  log(`generate: wrote .bendo/routes.ts (${manifest.routes.length} routes)`);
  return manifest;
}

export class Pipeline {
  private child: ChildProcess | undefined;
  private cancelled = false;

  async cancelBuild(): Promise<void> {
    if (this.child) await stop(this.child);
  }

  async close(): Promise<void> {
    this.cancelled = true;
    await this.cancelBuild();
  }

  async build(entry: string, target: Target = "native"): Promise<string> {
    if (this.cancelled) throw new BuildCancelled();
    await generateSchemas();
    const bend = findBend();
    if (bend.kind === "missing")
      throw new Error("bend not found. Install Bend from https://bend-lang.com");
    const source = realpathSync(resolve(entry));
    const hash = createHash("sha256");
    // Include the native toolchain and foreign-effect twins, as in tests/harness.ts.
    hash.update(
      JSON.stringify([
        "bendo-cli-v3",
        target,
        bend.path,
        bend.version,
        process.platform,
        process.arch,
      ]),
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
    const graph = sourceGraph(source);
    for (const [file, content] of graph) {
      hash.update(JSON.stringify([file, content.length]));
      hash.update(content);
    }
    const cache = resolve(".cache/bendo", hash.digest("hex"));
    const binary = join(cache, target === "js" ? "app.js" : "server");
    if (existsSync(binary)) {
      log("compile: cache hit");
      return binary;
    }
    mkdirSync(cache, { recursive: true });
    const temporary = mkdtempSync(join(cache, ".compile-"));
    const output = join(temporary, target === "js" ? "app.js" : "server");
    // Compile an immutable tree. A save followed by an undo must never publish
    // a binary made from intermediate live contents under the original hash.
    // Flat canonical names also support app paths containing spaces, which Bend
    // does not allow in an unquoted module import. C/JS twins share a stem.
    const snapshotPath = (file: string): string =>
      join(
        temporary,
        "sources",
        "module_" +
          createHash("sha256")
            .update(file.slice(0, -extname(file).length))
            .digest("hex") +
          extname(file),
      );
    mkdirSync(join(temporary, "sources"));
    for (const [file, contents] of graph) {
      const snapshotContents =
        extname(file) === ".bend"
          ? mapImports(
              contents.toString(),
              (imported) =>
                `./${snapshotPath(realpathSync(resolve(file, "..", imported)))
                  .split("/")
                  .at(-1)}`,
            )
          : contents;
      writeFileSync(snapshotPath(file), snapshotContents);
    }
    const snapshotEntry = snapshotPath(source);
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
          else if (child.signalCode !== null || this.cancelled) reject(new BuildCancelled());
          else if (code === 0) done();
          else {
            for (const file of graph.keys()) text = text.replaceAll(snapshotPath(file), file);
            reject(new Error(compilerDiagnostic(text, entry, graph)));
          }
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
