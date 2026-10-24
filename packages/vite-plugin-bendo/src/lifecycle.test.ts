// BND-59: closing Vite stops Bend, and the plugin's watches outside the root
// follow each entry's import graph instead of piling up.
import { expect, test } from "bun:test";
import {
  chmodSync,
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { basename, dirname, join } from "node:path";
import { createServer, type ViteDevServer } from "vite";
import type { CompiledShared } from "bendo/shared";
import bendo from "./index.ts";
import { copyFixture } from "./fixture.ts";

/** Whether `pid` runs; a zombie waiting for its reaper counts as gone. */
function running(pid: number): boolean {
  try {
    process.kill(pid, 0);
  } catch {
    return false;
  }
  try {
    return !/^\d+ \(.*\) Z /.test(readFileSync(`/proc/${pid}/stat`, "utf8"));
  } catch {
    return true;
  }
}

async function until(label: string, done: () => boolean): Promise<void> {
  for (let i = 0; !done(); i++) {
    if (i === 300) throw new Error(`timed out waiting until ${label}`);
    await Bun.sleep(10);
  }
}

test("closing the dev server mid-compile kills Bend and writes nothing", async () => {
  using app = copyFixture("close");
  const pidFile = app.path("bend-pids");
  // Answers `bend version`; a compile records its pid and a child's, then hangs.
  const bend = app.path("fake-bend");
  writeFileSync(
    bend,
    [
      "#!/bin/sh",
      'if [ "$1" = version ]; then echo fake; exit 0; fi',
      `echo $$ >> "${pidFile}"`,
      "sleep 60 &",
      `echo $! >> "${pidFile}"`,
      "wait",
      "",
    ].join("\n"),
  );
  chmodSync(bend, 0o755);
  const pids = () =>
    existsSync(pidFile)
      ? readFileSync(pidFile, "utf8").trim().split("\n").filter(Boolean).map(Number)
      : [];
  const server = await createServer({
    root: app.root,
    configFile: false,
    logLevel: "silent",
    cacheDir: app.path(".vite"),
    server: { middlewareMode: true, ws: false, watch: null },
    plugins: [bendo({ bend })],
  });
  // A request as the browser makes it; Vite's close waits for these.
  const settled = (url: string) =>
    server.environments.client.transformRequest(url).then(
      () => "loaded",
      (error: unknown) => String(error),
    );
  const handle = settled("/shared/handle.bend");
  // Queued behind `handle`, since one Bend runs at a time.
  const rules = settled("/shared/rules.bend");
  await until("fake bend started", () => pids().length === 2);
  await server.close();
  expect(await handle).toContain("Vite closed while");
  expect(await rules).toContain("Vite closed while");
  // Only the first compile ever started.
  expect(pids()).toHaveLength(2);
  await until("bend and its child exited", () => !pids().some(running));
  expect(existsSync(app.path("shared/handle.d.bend.ts"))).toBe(false);
  expect(existsSync(app.path("shared/rules.d.bend.ts"))).toBe(false);
  const cache = app.path(".vite/bendo");
  expect(existsSync(cache) ? readdirSync(cache) : []).toEqual([]);
});

function fake(entry: string): CompiledShared {
  return { source: entry, module: "export default {};", declarations: "", named: [], warnings: [] };
}

test("watches outside the root follow each entry's graph and spare other watchers", async () => {
  using app = copyFixture("watch");
  const outside = `${app.root}-outside`;
  mkdirSync(outside);
  let server: ViteDevServer | undefined;
  try {
    const dep = (name: string) => {
      const file = join(outside, `${name}.bend`);
      writeFileSync(file, `def ${name}() -> Nat:\n  1n\n`);
      return file;
    };
    const [a, b, c] = [dep("a"), dep("b"), dep("c")];
    const entry = (name: string, deps: string[]) => {
      const imports = deps.map(
        (file) =>
          `import ../../${basename(outside)}/${basename(file)} as ${basename(file, ".bend").toUpperCase()}\n`,
      );
      app.write(`shared/${name}.bend`, imports.join(""));
    };
    const dev = await createServer({
      root: app.root,
      configFile: false,
      logLevel: "silent",
      cacheDir: app.path(".vite"),
      server: { middlewareMode: true, ws: false },
      plugins: [bendo({ diskCache: false, declarations: false, compile: async (e) => fake(e) })],
    });
    server = dev;
    const watched = (file: string) =>
      dev.watcher.getWatched()[dirname(file)]?.includes(basename(file)) ?? false;
    const load = (name: string) => dev.pluginContainer.load(app.path(`shared/${name}.bend`));
    const expectWatched = async (expected: Record<string, boolean>) => {
      const files: Record<string, string> = { a, b, c };
      const actual = () =>
        Object.fromEntries(Object.keys(expected).map((key) => [key, watched(files[key] ?? "")]));
      await until(`watched is ${JSON.stringify(expected)}`, () =>
        Object.entries(expected).every(([key, value]) => actual()[key] === value),
      ).catch(() => expect(actual()).toEqual(expected));
    };

    // Another consumer already watches c.
    dev.watcher.add(c);
    await expectWatched({ a: false, b: false, c: true });

    entry("one", [a, c]);
    await load("one");
    entry("two", [a]);
    await load("two");
    await expectWatched({ a: true, b: false, c: true });

    // one moves to b; two still needs a; c was never the plugin's to drop.
    entry("one", [b]);
    await load("one");
    await expectWatched({ a: true, b: true, c: true });

    // two moves to b too, so nothing reaches a.
    entry("two", [b]);
    await load("two");
    await expectWatched({ a: false, b: true, c: true });

    // And back again: a returns, b goes once neither entry reaches it.
    entry("one", [a]);
    await load("one");
    await expectWatched({ a: true, b: true, c: true });
    entry("two", [a]);
    await load("two");
    await expectWatched({ a: true, b: false, c: true });
  } finally {
    await server?.close();
    rmSync(outside, { recursive: true, force: true });
  }
});
