// BND-103: with `server.fs.strict` and an allow list, the dev server refuses
// a `.bend` file outside the list the way Vite refuses any other file, and
// compiles nothing for it. Files in the root and in an allowed directory still
// compile and hot-reload. Uses the real Bend compiler.
import { afterAll, beforeAll, expect, test } from "bun:test";
import { existsSync, mkdirSync, rmSync, writeFileSync } from "node:fs";
import { basename, join } from "node:path";
import { createServer, type ViteDevServer } from "vite";
import bendo, { declarationPath } from "./index.ts";
import { copyFixture } from "./fixture.ts";

const app = copyFixture("fs-allow");
// Two directories beside the root: one on the allow list, one not.
const allowed = `${app.root}-allowed`;
const denied = `${app.root}-denied`;
mkdirSync(allowed);
mkdirSync(denied);
const secret = join(denied, "secret.bend");
writeFileSync(secret, 'import Base\n\ndef marker() -> String:\n  "outside-marker-7f3a"\n');
const word = join(allowed, "word.bend");
const wordSource = (text: string) => `import Base\n\ndef word() -> String:\n  "${text}"\n`;
writeFileSync(word, wordSource("first"));

let server: ViteDevServer;
let base = "";
let socket: WebSocket;
const messages: unknown[] = [];

function field(value: unknown, key: string): unknown {
  return typeof value === "object" && value !== null ? Reflect.get(value, key) : undefined;
}

async function until(label: string, done: () => boolean, timeout = 60_000): Promise<void> {
  const deadline = Date.now() + timeout;
  while (!done()) {
    if (Date.now() > deadline) throw new Error(`timed out waiting until ${label}`);
    await Bun.sleep(10);
  }
}

async function get(path: string): Promise<{ status: number; text: string }> {
  const response = await fetch(`${base}${path}`);
  return { status: response.status, text: await response.text() };
}

beforeAll(async () => {
  server = await createServer({
    root: app.root,
    configFile: false,
    logLevel: "silent",
    cacheDir: app.path(".vite"),
    server: {
      host: "127.0.0.1",
      port: 0,
      strictPort: true,
      fs: { strict: true, allow: [app.root, allowed] },
    },
    plugins: [bendo({ diskCache: false })],
  });
  await server.listen();
  const address = server.httpServer?.address();
  if (typeof address !== "object" || address === null) throw new Error("no dev server address");
  base = `http://127.0.0.1:${address.port}`;
  socket = new WebSocket(
    `ws://127.0.0.1:${address.port}/?token=${server.config.webSocketToken}`,
    "vite-hmr",
  );
  socket.addEventListener("message", (event) => messages.push(JSON.parse(String(event.data))));
  await until("the HMR socket connects", () =>
    messages.some((message) => field(message, "type") === "connected"),
  );
});

afterAll(async () => {
  socket.close();
  await server.close();
  app[Symbol.dispose]();
  rmSync(allowed, { recursive: true, force: true });
  rmSync(denied, { recursive: true, force: true });
});

test("a .bend file outside fs.allow is refused like any other file, and nothing is written", async () => {
  // Vite's own answer for the same file, as the reviewer saw it.
  expect((await get(`/@fs${secret}?raw&import`)).status).toBe(403);
  for (const query of ["?import", "", "?import&t=1"]) {
    const response = await get(`/@fs${secret}${query}`);
    expect(response.status).toBe(403);
    expect(response.text).not.toContain("outside-marker-7f3a");
  }
  expect(existsSync(declarationPath(secret))).toBe(false);
  expect(server.environments.client.moduleGraph.getModulesByFile(secret)).toBeUndefined();
});

test("a .bend file in the root still compiles", async () => {
  const response = await get("/shared/handle.bend?import");
  expect(response.status).toBe(200);
  expect(response.text).toContain("Pick a handle");
  expect(existsSync(declarationPath(app.path("shared/handle.bend")))).toBe(true);
});

test("a .bend file in an allowed directory compiles and hot-reloads", async () => {
  const specifier = `../../${basename(allowed)}/word.bend`;
  app.write(
    "src/word.ts",
    [
      `import { word } from "${specifier}";`,
      "export const text = word();",
      `import.meta.hot?.accept("${specifier}", () => {});`,
      "",
    ].join("\n"),
  );
  expect((await get("/src/word.ts")).status).toBe(200);
  const url = `/@fs${word}`;
  const first = await get(`${url}?import`);
  expect(first.status).toBe(200);
  expect(first.text).toContain("first");
  expect(existsSync(declarationPath(word))).toBe(true);

  const from = messages.length;
  writeFileSync(word, wordSource("second"));
  const isUpdate = (message: unknown) => {
    const updates = field(message, "updates");
    return (
      Array.isArray(updates) && updates.some((update) => field(update, "acceptedPath") === url)
    );
  };
  await until("the HMR update for the allowed file arrives", () =>
    messages.slice(from).some(isUpdate),
  );
  const second = await get(`${url}?import&t=${Date.now()}`);
  expect(second.status).toBe(200);
  expect(second.text).toContain("second");
});
