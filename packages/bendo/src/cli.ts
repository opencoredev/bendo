#!/usr/bin/env bun
import { copyFileSync, existsSync, mkdirSync, renameSync, watch, type FSWatcher } from "node:fs";
import { dirname, resolve } from "node:path";
import type { ChildProcess } from "node:child_process";
import pkg from "../package.json" with { type: "json" };
import { findBend } from "./bend.ts";
import {
  Pipeline,
  BuildCancelled,
  generateSchemas,
  launch,
  log,
  stop,
  type Target,
} from "./pipeline.ts";
import { doctor } from "./doctor.ts";
import { prove } from "./prove.ts";
import { fetchManifest } from "./manifest.ts";
import { scaffold } from "./scaffold.ts";
import { sourceGraph } from "./sources.ts";
import { devProxy, privatePort, waitForServer } from "./dev-server.ts";

const USAGE = `bendo ${pkg.version}

Usage:
  bendo new <dir>       create a minimal app
  bendo dev [entry] [--native]  watch and restart with Bun JS (or native) (default: main.bend)
  bendo build [entry]   build dist/server (default: main.bend)
  bendo start          run dist/server; honors PORT (default: 8787)
  bendo routes [entry] print the method/path table (default: main.bend)
  bendo prove [file]   check proofs (default: PROOF.bend)
  bendo gen [entry]    write .bendo/routes.ts from the manifest
  bendo doctor         check Bend, Lean/elan, clang and Bun versions
  bendo --version      print the version

Each command accepts --help. Requires Bun and Bend on PATH (or ~/.bend/bin).`;

function report(error: unknown): void {
  process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
}

async function serve(binary: string): Promise<number> {
  const child = launch(binary);
  const shutdown = (): void => {
    void stop(child);
  };
  process.once("SIGINT", shutdown);
  process.once("SIGTERM", shutdown);
  try {
    return await new Promise<number>((done, reject) => {
      child.once("error", reject);
      child.once("exit", (code, signal) => done(code ?? (signal ? 0 : 1)));
    });
  } finally {
    process.removeListener("SIGINT", shutdown);
    process.removeListener("SIGTERM", shutdown);
    await stop(child);
  }
}

async function dev(entry: string, target: Target): Promise<number> {
  const pipeline = new Pipeline();
  const proxy = await devProxy();
  let candidate: ChildProcess | undefined;
  let buildSignal = new AbortController();
  let server: ChildProcess | undefined;
  let closing = false;
  let revision = 0;
  let building = false;
  let timer: ReturnType<typeof setTimeout> | undefined;
  let release: () => void = () => {};
  const finished = new Promise<void>((done) => {
    release = done;
  });
  const rebuild = async (): Promise<void> => {
    if (building || closing) return;
    building = true;
    const current = revision;
    buildSignal = new AbortController();
    try {
      refreshImports();
      const binary = await pipeline.build(entry, target);
      // Skip intermediate builds when a save arrived while Bend was compiling.
      if (closing || current !== revision) return;
      const started = performance.now();
      const port = await privatePort();
      if (closing || current !== revision) return;
      candidate = launch(binary, { ...process.env, PORT: String(port) });
      candidate.once("error", report);
      await waitForServer(candidate, port, buildSignal.signal);
      if (closing || current !== revision) return;
      const previous = server;
      server = candidate;
      candidate = undefined;
      server.once("exit", (code, signal) => {
        if (!closing && code !== 0 && signal === null)
          report(new Error(`server exited (${code}); waiting for a .bend change`));
      });
      proxy.activate(port);
      if (previous) await stop(previous);
      log(`restart: launched pid ${server.pid} in ${Math.round(performance.now() - started)}ms`);
    } catch (error) {
      if (!closing && current === revision && !(error instanceof BuildCancelled)) report(error);
    } finally {
      if (candidate) {
        await stop(candidate);
        candidate = undefined;
      }
      building = false;
      if (!closing && current !== revision && timer === undefined) void rebuild();
    }
  };
  const imports = new Map<string, FSWatcher>();
  const changed = (_event: string, name: string | Buffer | null): void => {
    if (name === null) return;
    const segments = name.toString().split(/[\\/]/);
    if (segments.some((part) => [".cache", "dist", "node_modules", ".git"].includes(part))) return;
    if (!name.toString().endsWith(".bend")) return;
    revision++;
    buildSignal.abort();
    // Kill the obsolete process group immediately, without closing the pipeline.
    void pipeline.cancelBuild().catch(report);
    if (timer) clearTimeout(timer);
    timer = setTimeout(() => {
      timer = undefined;
      void rebuild();
    }, 100);
  };
  const refreshImports = (): void => {
    const directories = new Set<string>();
    try {
      sourceGraph(entry, (file) => directories.add(dirname(file)));
    } catch {
      /* compiler reports missing imports */
    }
    for (const directory of directories) {
      if (imports.has(directory) || !existsSync(directory)) continue;
      imports.set(directory, watch(directory, changed));
    }
    for (const [directory, watcher] of imports) {
      if (!directories.has(directory)) {
        watcher.close();
        imports.delete(directory);
      }
    }
  };
  const watcher = watch(process.cwd(), { recursive: true }, changed);
  const shutdown = (): void => {
    if (closing) return;
    closing = true;
    watcher.close();
    for (const watcher of imports.values()) watcher.close();
    proxy.close();
    buildSignal.abort();
    if (timer) clearTimeout(timer);
    void Promise.all([
      pipeline.close(),
      server ? stop(server) : Promise.resolve(),
      candidate ? stop(candidate) : Promise.resolve(),
    ]).then(release, (error) => {
      report(error);
      release();
    });
  };
  process.once("SIGINT", shutdown);
  process.once("SIGTERM", shutdown);
  log(`watch: ${entry} (.bend files, debounce 100ms)`);
  void rebuild();
  await finished;
  process.removeListener("SIGINT", shutdown);
  process.removeListener("SIGTERM", shutdown);
  return 0;
}

type Command = "new" | "dev" | "build" | "start" | "doctor" | "routes" | "prove" | "gen";
function parseCommand(value: string): Command {
  switch (value) {
    case "new":
    case "dev":
    case "build":
    case "start":
    case "doctor":
    case "routes":
    case "prove":
    case "gen":
      return value;
    default:
      throw new Error(`Unknown command: ${value}\n${USAGE}`);
  }
}

async function main(args: string[]): Promise<number> {
  const native = args[0] === "dev" && args.includes("--native");
  const [rawCommand, argument, ...extra] = native ? args.filter((arg) => arg !== "--native") : args;
  const command = rawCommand;
  if (command === undefined || command === "--help" || command === "-h") {
    log(USAGE);
    return 0;
  }
  if (command === "--version" || command === "-v") {
    log(pkg.version);
    return 0;
  }
  const parsed = parseCommand(command);
  if (argument === "--help" || argument === "-h") {
    log(USAGE);
    return 0;
  }
  if (
    extra.length ||
    argument?.startsWith("-") ||
    ((command === "start" || command === "doctor") && argument)
  )
    throw new Error(`Unexpected arguments\n${USAGE}`);
  switch (parsed) {
    case "new":
      if (!argument) throw new Error("Usage: bendo new <dir>");
      scaffold(argument);
      log(`Created ${argument}. Run bendo dev in that directory.`);
      return 0;
    case "doctor":
      return doctor();
    case "prove":
      return prove(argument ?? "PROOF.bend");
    case "routes":
    case "gen": {
      const pipeline = new Pipeline();
      const cancel = (): void => {
        void pipeline.close();
      };
      process.once("SIGINT", cancel);
      process.once("SIGTERM", cancel);
      try {
        const binary = await pipeline.build(argument ?? "main.bend");
        if (parsed === "gen") await generateSchemas(binary);
        else {
          const manifest = fetchManifest(binary);
          const width = Math.max(6, ...manifest.routes.map((route) => route.method.length));
          log(`${"METHOD".padEnd(width)}  PATH`);
          for (const route of manifest.routes) log(`${route.method.padEnd(width)}  ${route.path}`);
        }
        return 0;
      } finally {
        process.removeListener("SIGINT", cancel);
        process.removeListener("SIGTERM", cancel);
        await pipeline.close();
      }
    }
    case "build": {
      const pipeline = new Pipeline();
      const cancel = (): void => {
        void pipeline.close();
      };
      process.once("SIGINT", cancel);
      process.once("SIGTERM", cancel);
      try {
        const binary = await pipeline.build(argument ?? "main.bend");
        mkdirSync("dist", { recursive: true });
        const temporary = resolve(`dist/.server-${process.pid}`);
        copyFileSync(binary, temporary);
        renameSync(temporary, resolve("dist/server"));
        log("build: dist/server");
        return 0;
      } finally {
        process.removeListener("SIGINT", cancel);
        process.removeListener("SIGTERM", cancel);
        await pipeline.close();
      }
    }
    case "start": {
      const binary = resolve("dist/server");
      if (!existsSync(binary)) throw new Error("dist/server not found. Run bendo build first.");
      return serve(binary);
    }
    case "dev":
      if (findBend().kind === "missing")
        throw new Error("bend not found. Install Bend from https://bend-lang.com");
      return dev(argument ?? "main.bend", native ? "native" : "js");
    default: {
      const exhaustive: never = parsed;
      return exhaustive;
    }
  }
}

try {
  process.exitCode = await main(process.argv.slice(2));
} catch (error) {
  report(error);
  process.exitCode = 1;
}
