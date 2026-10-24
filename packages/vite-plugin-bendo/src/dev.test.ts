// BND-59: a real Vite dev server on a port serves the fixture app. The test
// listens on Vite's HMR WebSocket like the browser client does, edits the
// .bend files and checks the updates, the error payload and the recovery.
import { afterAll, beforeAll, expect, test } from "bun:test";
import { mkdirSync, rmSync, writeFileSync } from "node:fs";
import { basename, dirname, join } from "node:path";
import { pathToFileURL } from "node:url";
import { createServer, type Plugin, type ViteDevServer } from "vite";
import bendo from "./index.ts";
import { copyFixture } from "./fixture.ts";

const app = copyFixture("dev");
// A directory beside the app, outside Vite's root and so outside its watcher.
const outside = `${app.root}-outside`;
mkdirSync(outside);
// An entry outside the root that another plugin also watches through Vite's
// watcher. Written before Vite starts, which can miss files created during its
// first scan. Its own directory keeps Vite's watcher off `outside`.
const sharedDir = `${app.root}-shared`;
mkdirSync(sharedDir);
const shared = join(sharedDir, "shared-entry.bend");
const sharedSource = (text: string) => `import Base\n\ndef word() -> String:\n  ${text}\n`;
writeFileSync(shared, sharedSource('"one"'));
/**
 * For each client save of `shared`: the module ids Vite will update after
 * every plugin's `hotUpdate`, and `messages.length` when the last hook returned.
 * Vite's own update arrives after that index.
 */
type ViteUpdate = { ids: string[]; returnedAt: number | undefined };
const viteUpdates: ViteUpdate[] = [];
/** `messages.length` when the test last saved `shared`. */
let savedAt = 0;
/** What the plugin sends once its own compile of `shared` ends: an update or an error. */
let pluginAnswered: (message: unknown) => boolean = () => false;
const other: Plugin = {
  name: "other-watcher",
  configureServer(dev) {
    dev.watcher.add(shared);
  },
  // Holds Vite's own update until the plugin has answered, so an update Vite
  // sent for the Bend module would arrive after the plugin's, never hidden by it.
  async hotUpdate({ file, modules }) {
    if (file !== shared || this.environment.name !== "client") return;
    const record: ViteUpdate = {
      ids: modules.map((module) => module.id ?? module.url),
      returnedAt: undefined,
    };
    viteUpdates.push(record);
    await nextMessage(savedAt, pluginAnswered);
    record.returnedAt = messages.length;
  },
};
const plugin = bendo({ diskCache: false });
let server: ViteDevServer;
let base = "";
let socket: WebSocket;
const messages: unknown[] = [];
const waiters = new Set<() => void>();

function field(value: unknown, key: string): unknown {
  return typeof value === "object" && value !== null ? Reflect.get(value, key) : undefined;
}

/** Waits for the first HMR message after `from` that satisfies `match`. */
async function nextMessage(
  from: number,
  match: (message: unknown) => boolean,
  timeout = 20_000,
): Promise<unknown> {
  const deadline = Date.now() + timeout;
  for (;;) {
    const found = messages.slice(from).find(match);
    if (found !== undefined) return found;
    const left = deadline - Date.now();
    if (left <= 0)
      throw new Error(`no matching HMR message; saw ${JSON.stringify(messages.slice(from))}`);
    await new Promise<void>((wake) => {
      const timer = setTimeout(wake, left);
      waiters.add(() => {
        clearTimeout(timer);
        wake();
      });
    });
  }
}

async function until(label: string, done: () => boolean, timeout = 20_000): Promise<void> {
  const deadline = Date.now() + timeout;
  while (!done()) {
    if (Date.now() > deadline) throw new Error(`timed out waiting until ${label}`);
    await Bun.sleep(10);
  }
}

const save = (file: string, text: string) => {
  savedAt = messages.length;
  writeFileSync(file, text);
};

const isType = (type: string) => (message: unknown) => field(message, "type") === type;

/** Each update as `boundary <- changed module`, the way the Vite client applies it. */
function updatePaths(message: unknown): string[] {
  const updates = field(message, "updates");
  return Array.isArray(updates)
    ? updates.map(
        (update) => `${String(field(update, "path"))} <- ${String(field(update, "acceptedPath"))}`,
      )
    : [];
}

/** What the browser fetches after an update: the module at its new timestamp. */
async function fetchModule(path: string): Promise<{ status: number; text: string }> {
  const response = await fetch(`${base}${path}?import&t=${Date.now()}`);
  return { status: response.status, text: await response.text() };
}

/** Imports a served module from disk and calls one of its exports. */
async function run(text: string, name: string): Promise<unknown> {
  const file = app.path(`.vite/served-${Date.now()}.mjs`);
  mkdirSync(dirname(file), { recursive: true });
  writeFileSync(file, text);
  const module: unknown = await import(pathToFileURL(file).href);
  const fn: unknown = field(module, name);
  if (typeof fn !== "function") throw new Error(`no export ${name}`);
  return Reflect.apply(fn, undefined, []);
}

beforeAll(async () => {
  server = await createServer({
    root: app.root,
    configFile: false,
    logLevel: "silent",
    cacheDir: app.path(".vite"),
    server: { host: "127.0.0.1", port: 0, strictPort: true },
    plugins: [plugin, other],
  });
  await server.listen();
  const address = server.httpServer?.address();
  if (typeof address !== "object" || address === null) throw new Error("no dev server address");
  base = `http://127.0.0.1:${address.port}`;
  socket = new WebSocket(
    `ws://127.0.0.1:${address.port}/?token=${server.config.webSocketToken}`,
    "vite-hmr",
  );
  socket.addEventListener("message", (event) => {
    messages.push(JSON.parse(String(event.data)));
    for (const wake of waiters) wake();
    waiters.clear();
  });
  await nextMessage(0, isType("connected"));
  // Load the page's modules as the browser would, so the module graph knows
  // that main.ts accepts updates to handle.bend.
  const page = await fetch(`${base}/`);
  expect(page.status).toBe(200);
  expect((await fetch(`${base}/src/main.ts`)).status).toBe(200);
  expect((await fetchModule("/shared/handle.bend")).text).toContain("Pick a handle");
});

afterAll(async () => {
  socket.close();
  await server.close();
  app[Symbol.dispose]();
  rmSync(outside, { recursive: true, force: true });
  rmSync(sharedDir, { recursive: true, force: true });
});

test("editing the imported .bend file sends an HMR update its importer accepts", async () => {
  const from = messages.length;
  app.edit("shared/handle.bend", "def long_enough", "# edited\ndef long_enough");
  const update = await nextMessage(from, isType("update"));
  expect(updatePaths(update)).toEqual(["/src/main.ts <- /shared/handle.bend"]);
  expect(field(field(update, "updates"), "0")).toMatchObject({ type: "js-update" });
  expect(messages.slice(from).some(isType("full-reload"))).toBe(false);
});

test("editing a .bend dependency updates the module that imports it", async () => {
  const from = messages.length;
  app.edit("shared/rules.bend", '"Pick a handle"', '"Choose your handle"');
  const update = await nextMessage(from, isType("update"));
  expect(updatePaths(update)).toEqual(["/src/main.ts <- /shared/handle.bend"]);
  const module = await fetchModule("/shared/handle.bend");
  expect(module.status).toBe(200);
  expect(module.text).toContain("Choose your handle");
  expect(module.text).not.toContain("Pick a handle");
});

test("a compile error reaches the overlay with its file, line and message, then clears", async () => {
  const from = messages.length;
  app.edit("shared/rules.bend", "  3n", "  three");
  const error = await nextMessage(from, isType("error"));
  expect(field(error, "err")).toMatchObject({
    plugin: "vite-plugin-bendo",
    id: app.path("shared/rules.bend"),
    loc: { file: app.path("shared/rules.bend"), line: 6, column: 3 },
  });
  expect(String(field(field(error, "err"), "message"))).toContain("three");
  expect(String(field(field(error, "err"), "frame"))).toContain("6>|   three");
  // The page keeps its last good build: no update or reload was sent.
  expect(
    messages
      .slice(from)
      .some((message) => isType("update")(message) || isType("full-reload")(message)),
  ).toBe(false);
  // A reload while broken shows the same error instead of the stale module.
  const broken = await fetchModule("/shared/handle.bend");
  expect(broken.status).toBe(500);
  expect(broken.text).toContain("rules.bend");

  const fixed = messages.length;
  app.edit("shared/rules.bend", "  three", "  4n");
  // The Vite client clears its overlay when this update arrives.
  const update = await nextMessage(fixed, isType("update"));
  expect(updatePaths(update)).toEqual(["/src/main.ts <- /shared/handle.bend"]);
  const module = await fetchModule("/shared/handle.bend");
  expect(module.status).toBe(200);
  expect(await run(module.text, "min_length")).toBe(4);
});

const errorMessage = (message: unknown) => String(field(field(message, "err"), "message"));

test("a broken import outside the root recovers once it is created and fixed", async () => {
  const extra = join(outside, "extra.bend");
  const missing = messages.length;
  app.edit(
    "shared/handle.bend",
    "import ./rules.bend as Rules\n",
    `import ./rules.bend as Rules\nimport ../../${basename(outside)}/extra.bend as Extra\n`,
  );
  app.write(
    "shared/handle.bend",
    `${app.read("shared/handle.bend")}\ndef extra() -> Nat:\n  Extra.seven()\n`,
  );
  expect(errorMessage(await nextMessage(missing, isType("error")))).toContain(extra);
  // The plugin's own watcher holds the missing path; Vite's never sees it.
  expect(plugin.api.watchedFiles()).toContain(extra);
  expect(server.watcher.getWatched()[outside]).toBeUndefined();

  // Creating it fires a create event; its type error must reach the overlay.
  const created = messages.length;
  writeFileSync(extra, 'import Base\n\ndef seven() -> Nat:\n  "seven"\n');
  const error = await nextMessage(created, isType("error"));
  expect(field(error, "err")).toMatchObject({ id: extra, loc: { file: extra, line: 4 } });

  const fixed = messages.length;
  writeFileSync(extra, "import Base\n\ndef seven() -> Nat:\n  7n\n");
  const update = await nextMessage(fixed, isType("update"));
  expect(updatePaths(update)).toEqual(["/src/main.ts <- /shared/handle.bend"]);
  const module = await fetchModule("/shared/handle.bend");
  expect(module.status).toBe(200);
  expect(await run(module.text, "extra")).toBe(7);
});

test("deleting an imported file shows the error, and restoring it sends the update", async () => {
  const source = app.read("shared/rules.bend");
  const deleted = messages.length;
  rmSync(app.path("shared/rules.bend"));
  expect(errorMessage(await nextMessage(deleted, isType("error")))).toContain("rules.bend");
  expect((await fetchModule("/shared/handle.bend")).status).toBe(500);

  const restored = messages.length;
  app.write("shared/rules.bend", source);
  const update = await nextMessage(restored, isType("update"));
  expect(updatePaths(update)).toEqual(["/src/main.ts <- /shared/handle.bend"]);
  const module = await fetchModule("/shared/handle.bend");
  expect(module.status).toBe(200);
  expect(await run(module.text, "min_length")).toBe(4);
});

test("editing an entry outside the root sends the update its importer accepts", async () => {
  const entry = join(outside, "greeting.bend");
  writeFileSync(entry, 'import Base\n\ndef greeting() -> String:\n  "hello"\n');
  const specifier = `../../${basename(outside)}/greeting.bend`;
  app.write(
    "src/greeting.ts",
    [
      `import { greeting } from "${specifier}";`,
      "export const text = greeting();",
      `import.meta.hot?.accept("${specifier}", () => {});`,
      "",
    ].join("\n"),
  );
  expect((await fetch(`${base}/src/greeting.ts`)).status).toBe(200);
  const url = `/@fs${entry}`;
  expect((await fetchModule(url)).status).toBe(200);
  expect(plugin.api.watchedFiles()).toContain(entry);

  const from = messages.length;
  writeFileSync(entry, 'import Base\n\ndef greeting() -> String:\n  "hi there"\n');
  const update = await nextMessage(from, isType("update"));
  expect(updatePaths(update)).toEqual([`/src/greeting.ts <- ${url}`]);
  const module = await fetchModule(url);
  expect(module.status).toBe(200);
  expect(await run(module.text, "greeting")).toBe("hi there");
});

test("an entry outside the root that another plugin watches updates only after its compile succeeds", async () => {
  const specifier = `../../${basename(sharedDir)}/shared-entry.bend`;
  app.write(
    "src/shared.ts",
    [
      `import { word } from "${specifier}";`,
      `import source from "${specifier}?raw";`,
      "export const text = `${word()} ${source.length}`;",
      `import.meta.hot?.accept(["${specifier}", "${specifier}?raw"], () => {});`,
      "",
    ].join("\n"),
  );
  expect((await fetch(`${base}/src/shared.ts`)).status).toBe(200);
  const url = `/@fs${shared}`;
  expect((await fetchModule(url)).status).toBe(200);
  expect((await fetch(`${base}${url}?raw&import`)).status).toBe(200);
  await until(
    "Vite watches the shared entry for the other plugin",
    () => server.watcher.getWatched()[sharedDir]?.includes(basename(shared)) === true,
  );
  const bendUpdate = `/src/shared.ts <- ${url}`;
  const rawUpdate = `/src/shared.ts <- ${url}?raw`;
  const updatesSince = (from: number) => messages.slice(from).flatMap(updatePaths);
  /** Saves `shared`, then waits for Vite's own update, which follows the plugin's answer. */
  const saveAndWait = async (text: string) => {
    const n = viteUpdates.length + 1;
    save(shared, text);
    await until(
      `Vite's hotUpdate hooks returned for save ${n}`,
      () => viteUpdates[n - 1]?.returnedAt !== undefined,
    );
    const record = viteUpdates[n - 1];
    if (record?.returnedAt === undefined) throw new Error("unreachable");
    await nextMessage(record.returnedAt, (message) => updatePaths(message).includes(rawUpdate));
    return record.ids;
  };
  pluginAnswered = (message) =>
    isType("error")(message) || updatePaths(message).includes(bendUpdate);

  // A good save: Vite updates the `?raw` module itself, and the Bend module
  // only through the plugin, once.
  const good = messages.length;
  expect(await saveAndWait(sharedSource('"two"'))).toEqual([`${shared}?raw`]);
  expect(updatesSince(good).filter((path) => path === bendUpdate)).toHaveLength(1);
  expect(await run((await fetchModule(url)).text, "word")).toBe("two");

  // A broken save shows the error, and the Bend module gets no update.
  const broken = messages.length;
  expect(await saveAndWait(sharedSource("2n"))).toEqual([`${shared}?raw`]);
  expect(field(messages.slice(broken).find(isType("error")), "err")).toMatchObject({ id: shared });
  expect(updatesSince(broken)).not.toContain(bendUpdate);

  // Fixing it sends one update.
  const fixed = messages.length;
  expect(await saveAndWait(sharedSource('"three"'))).toEqual([`${shared}?raw`]);
  expect(updatesSince(fixed).filter((path) => path === bendUpdate)).toHaveLength(1);
  expect(await run((await fetchModule(url)).text, "word")).toBe("three");
});
