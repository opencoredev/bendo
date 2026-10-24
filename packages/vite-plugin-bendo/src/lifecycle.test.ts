// BND-59: closing Vite stops Bend, and the plugin's own watches outside the
// root follow each entry's import graph instead of piling up.
import { expect, test } from "bun:test";
import {
  chmodSync,
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  renameSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { basename, dirname, join, relative } from "node:path";
import { createServer, type Plugin, type ViteDevServer } from "vite";
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

/** The scratch directory beside `app`, outside its Vite root. */
const outsideOf = (app: ReturnType<typeof copyFixture>) => `${app.root}-outside`;

function writeDep(dir: string, name: string): string {
  const file = join(dir, `${name}.bend`);
  writeFileSync(file, `def ${name}() -> Nat:\n  1n\n`);
  return file;
}

/** Writes a `.bend` entry that imports each of `deps`. */
function writeEntry(file: string, deps: string[]): void {
  const imports = deps.map((dep) => {
    const path = relative(dirname(file), dep);
    const name = basename(dep, ".bend").toUpperCase();
    return `import ${path.startsWith(".") ? path : `./${path}`} as ${name}\n`;
  });
  writeFileSync(file, imports.join(""));
}

/** A dev server whose fake compiles count themselves, plus scratch files outside its root. */
async function watchServer(
  app: ReturnType<typeof copyFixture>,
  plugins: Plugin[] = [],
): Promise<{
  dev: ViteDevServer;
  plugin: ReturnType<typeof bendo>;
  outside: string;
  compiles: () => number;
  dep: (name: string) => string;
  entry: (file: string, deps: string[]) => void;
  [Symbol.asyncDispose]: () => Promise<void>;
}> {
  const outside = outsideOf(app);
  mkdirSync(outside, { recursive: true });
  let compiles = 0;
  const plugin = bendo({
    diskCache: false,
    declarations: false,
    compile: async (entry) => {
      compiles++;
      return fake(entry);
    },
  });
  const dev = await createServer({
    root: app.root,
    configFile: false,
    logLevel: "silent",
    cacheDir: app.path(".vite"),
    server: { middlewareMode: true, ws: false },
    plugins: [...plugins, plugin],
  });
  return {
    dev,
    plugin,
    outside,
    compiles: () => compiles,
    dep: (name) => writeDep(outside, name),
    entry: writeEntry,
    async [Symbol.asyncDispose]() {
      await dev.close();
      rmSync(outside, { recursive: true, force: true });
    },
  };
}

async function expectWatched(plugin: ReturnType<typeof bendo>, files: string[]): Promise<void> {
  const expected = [...files].sort();
  await until(`the plugin watches ${JSON.stringify(expected)}`, () =>
    Bun.deepEquals(plugin.api.watchedFiles(), expected),
  ).catch(() => expect(plugin.api.watchedFiles()).toEqual(expected));
}

test("watches outside the root follow each entry's graph and leave Vite's watcher alone", async () => {
  using app = copyFixture("watch");
  // Another plugin watches c through Vite's shared watcher.
  const seen: string[] = [];
  const c = `${app.root}-outside/c.bend`;
  mkdirSync(dirname(c));
  writeFileSync(c, "def c() -> Nat:\n  1n\n");
  const other: Plugin = {
    name: "other-watcher",
    configureServer(dev) {
      dev.watcher.add(c);
      dev.watcher.on("change", (file) => seen.push(file));
    },
  };
  await using s = await watchServer(app, [other]);
  const [a, b] = [s.dep("a"), s.dep("b")];
  const viteWatches = (file: string) =>
    s.dev.watcher.getWatched()[dirname(file)]?.includes(basename(file)) ?? false;
  await until("Vite watches c for the other plugin", () => viteWatches(c));
  const one = app.path("shared/one.bend");
  const two = app.path("shared/two.bend");
  const load = (file: string) => s.dev.pluginContainer.load(file);

  s.entry(one, [a, c]);
  await load(one);
  s.entry(two, [a]);
  await load(two);
  await expectWatched(s.plugin, [a, c]);

  // one moves to b; two still needs a.
  s.entry(one, [b]);
  await load(one);
  await expectWatched(s.plugin, [a, b]);

  // two moves to b too, so nothing reaches a.
  s.entry(two, [b]);
  await load(two);
  await expectWatched(s.plugin, [b]);

  // And back again: a returns, b goes once neither entry reaches it.
  s.entry(one, [a, c]);
  await load(one);
  s.entry(two, [a]);
  await load(two);
  await expectWatched(s.plugin, [a, c]);

  // Editing c, which both watch, recompiles one through the plugin's watcher,
  // once, and still reaches the other plugin.
  const before = s.compiles();
  writeFileSync(c, "def c() -> Nat:\n  2n\n");
  await until("one recompiled", () => s.compiles() === before + 1);
  await until("the other plugin saw the edit", () => seen.includes(c));
  await Bun.sleep(200);
  expect(s.compiles()).toBe(before + 1);

  // Dropping c from every graph leaves Vite's watch, and the other plugin's events, alone.
  s.entry(one, [a]);
  await load(one);
  await expectWatched(s.plugin, [a]);
  expect(viteWatches(c)).toBe(true);
  seen.length = 0;
  writeFileSync(c, "def c() -> Nat:\n  3n\n");
  await until("the other plugin saw the edit after the plugin let go", () => seen.includes(c));
  expect(viteWatches(a) || viteWatches(b)).toBe(false);
});

test("an entry outside the root is watched, and deleting entries releases their imports", async () => {
  using app = copyFixture("restore");
  // Written before Vite starts: its watcher can miss a file created during its first scan.
  const outside = outsideOf(app);
  mkdirSync(outside);
  const [a, b] = [writeDep(outside, "a"), writeDep(outside, "b")];
  const inside = app.path("shared/inside.bend");
  const outer = join(outside, "outer.bend");
  writeEntry(inside, [a, b]);
  writeEntry(outer, [a]);
  await using s = await watchServer(app);
  await s.dev.pluginContainer.load(inside);
  await s.dev.pluginContainer.load(outer);
  await expectWatched(s.plugin, [a, b, outer]);

  // Editing the outside entry itself recompiles it.
  const before = s.compiles();
  s.entry(outer, [b]);
  await until("outer recompiled", () => s.compiles() === before + 1);
  await expectWatched(s.plugin, [a, b, outer]);

  // A file Vite's watcher never saw has no delete event.
  const viteKnows = () =>
    until(
      "Vite watches inside.bend",
      () => s.dev.watcher.getWatched()[dirname(inside)]?.includes(basename(inside)) ?? false,
    );
  for (let round = 0; round < 3; round++) {
    await viteKnows();
    // Vite's watcher reports the inside entry; only its own path stays in its graph.
    rmSync(inside);
    await expectWatched(s.plugin, [b, outer]);
    // The plugin's watcher reports the outside one, which it keeps watching for its return.
    rmSync(outer);
    await expectWatched(s.plugin, [outer]);
    expect(s.plugin.api.watchedFiles().length).toBeLessThanOrEqual(3);

    s.entry(inside, [a, b]);
    await expectWatched(s.plugin, [a, b, outer]);
    s.entry(outer, [b]);
    await expectWatched(s.plugin, [a, b, outer]);
  }
});

test("closing the dev server closes the plugin's watcher", async () => {
  using app = copyFixture("unwatch");
  const s = await watchServer(app);
  const a = s.dep("a");
  const inside = app.path("shared/inside.bend");
  s.entry(inside, [a]);
  await s.dev.pluginContainer.load(inside);
  await expectWatched(s.plugin, [a]);
  await s[Symbol.asyncDispose]();
  expect(s.plugin.api.watchedFiles()).toEqual([]);
});

test("an import in a missing directory is watched once the entry recompiles after it appears", async () => {
  using app = copyFixture("late-dir");
  await using s = await watchServer(app);
  const inside = app.path("shared/inside.bend");
  const late = join(s.outside, "later", "late.bend");
  s.entry(inside, [late]);
  await s.dev.pluginContainer.load(inside).catch(() => undefined);
  await expectWatched(s.plugin, [late]);

  mkdirSync(dirname(late));
  writeFileSync(late, "def late() -> Nat:\n  1n\n");
  // The next compile of the entry retries the directory.
  await s.dev.pluginContainer.load(inside);
  expect(s.compiles()).toBe(1);
  const before = s.compiles();
  writeFileSync(late, "def late() -> Nat:\n  2n\n");
  await until("the late import's edit recompiled inside", () => s.compiles() === before + 1);
});

test("a watched directory that is deleted or renamed, then recreated, is watched again", async () => {
  using app = copyFixture("replaced-dir");
  await using s = await watchServer(app);
  const lib = join(s.outside, "lib");
  mkdirSync(lib);
  const a = writeDep(lib, "a");
  const inside = app.path("shared/inside.bend");
  s.entry(inside, [a]);
  await s.dev.pluginContainer.load(inside);
  await expectWatched(s.plugin, [a]);

  /** Saves `a` with a new body and waits for the plugin's watcher to recompile `inside`. */
  let version = 1;
  const save = async (label: string) => {
    const before = s.compiles();
    writeFileSync(a, `def a() -> Nat:\n  ${++version}n\n`);
    await until(label, () => s.compiles() > before);
  };
  await save("the first save recompiled inside");

  const replacements: [string, () => void][] = [
    ["deleted", () => rmSync(lib, { recursive: true })],
    ["renamed", () => renameSync(lib, `${lib}-old`)],
  ];
  for (let round = 0; round < 2; round++) {
    for (const [how, replace] of replacements) {
      rmSync(`${lib}-old`, { recursive: true, force: true });
      replace();
      // Nothing reads the old directory any more; recreate it, then save.
      mkdirSync(lib);
      await save(`a save after lib was ${how} and recreated recompiled inside`);
      await save(`a second save after lib was ${how} recompiled inside`);
      await expectWatched(s.plugin, [a]);
    }
  }
});

test("restarting the dev server keeps the new server's watcher", async () => {
  using app = copyFixture("restart");
  await using s = await watchServer(app);
  const a = s.dep("a");
  const inside = app.path("shared/inside.bend");
  s.entry(inside, [a]);
  await s.dev.restart();
  await s.dev.pluginContainer.load(inside);
  await expectWatched(s.plugin, [a]);
  const before = s.compiles();
  writeFileSync(a, "def a() -> Nat:\n  2n\n");
  await until(
    "the restarted server's watcher recompiled inside",
    () => s.compiles() === before + 1,
  );
});
