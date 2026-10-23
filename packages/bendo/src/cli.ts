#!/usr/bin/env bun
import { copyFileSync, existsSync, mkdirSync, renameSync, watch } from "node:fs";
import { resolve } from "node:path";
import type { ChildProcess } from "node:child_process";
import pkg from "../package.json" with { type: "json" };
import { findBend } from "./bend.ts";
import { Pipeline, launch, log, stop } from "./pipeline.ts";
import { scaffold } from "./scaffold.ts";

const USAGE = `bendo ${pkg.version}

Usage:
  bendo new <dir>       create a minimal app
  bendo dev [entry]     watch and restart (default: main.bend)
  bendo build [entry]   build dist/server (default: main.bend)
  bendo start          run dist/server; honors PORT (default: 8787)
  bendo doctor         check that Bend is installed
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

async function dev(entry: string): Promise<number> {
  const pipeline = new Pipeline();
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
    try {
      const binary = await pipeline.build(entry);
      // Skip intermediate builds when a save arrived while Bend was compiling.
      if (closing || current !== revision) return;
      const started = performance.now();
      if (server) await stop(server);
      if (closing) return;
      server = launch(binary);
      server.once("error", report);
      server.once("exit", (code, signal) => {
        if (!closing && code !== 0 && signal === null)
          report(new Error(`server exited (${code}); waiting for a .bend change`));
      });
      log(`restart: launched pid ${server.pid} in ${Math.round(performance.now() - started)}ms`);
    } catch (error) {
      if (!closing) report(error);
    } finally {
      building = false;
      if (!closing && current !== revision) void rebuild();
    }
  };
  const watcher = watch(process.cwd(), { recursive: true }, (_event, name) => {
    if (name === null) return;
    const segments = name.toString().split(/[\\/]/);
    if (segments.some((part) => [".cache", "dist", "node_modules", ".git"].includes(part))) return;
    if (!name.toString().endsWith(".bend")) return;
    revision++;
    if (timer) clearTimeout(timer);
    timer = setTimeout(() => {
      void rebuild();
    }, 100);
  });
  const shutdown = (): void => {
    if (closing) return;
    closing = true;
    watcher.close();
    if (timer) clearTimeout(timer);
    void Promise.all([pipeline.close(), server ? stop(server) : Promise.resolve()]).then(
      release,
      (error) => {
        report(error);
        release();
      },
    );
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

type Command = "new" | "dev" | "build" | "start" | "doctor";
function parseCommand(value: string): Command {
  switch (value) {
    case "new":
    case "dev":
    case "build":
    case "start":
    case "doctor":
      return value;
    default:
      throw new Error(`Unknown command: ${value}\n${USAGE}`);
  }
}

async function main(args: string[]): Promise<number> {
  const [rawCommand, argument, ...extra] = args;
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
    case "doctor": {
      const bend = findBend();
      switch (bend.kind) {
        case "found":
          log(`bend ${bend.version} at ${bend.path}`);
          return 0;
        case "missing":
          throw new Error("bend not found. Install Bend from https://bend-lang.com");
        default: {
          const exhaustive: never = bend;
          return exhaustive;
        }
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
      return dev(argument ?? "main.bend");
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
