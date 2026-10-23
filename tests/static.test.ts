import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { createHash } from "node:crypto";
import {
  mkdirSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  rmSync,
  statSync,
  symlinkSync,
  writeFileSync,
} from "node:fs";
import { connect } from "node:net";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { build, compile, start, type RunningServer } from "./harness.ts";

const binary = build("tests/servers/static.bend");
const openNative = compile("tests/fixtures/static/open.bend", "native");
const openJs = compile("tests/fixtures/static/open.bend", "js");

const APP = resolve(import.meta.dir, "fixtures/static/vite-app/build");
const base = mkdtempSync(join(tmpdir(), "bendo-static-"));
const root = join(base, "root");
const outside = join(base, "outside");

// 2000 bytes, every value distinct from its neighbours, so a wrong offset shows.
const data = Buffer.from(Array.from({ length: 2000 }, (_, i) => (i * 7 + 3) % 256));
// Larger than one 64 KiB read, smaller than the default cap.
const large = Buffer.from(Array.from({ length: 200_000 }, (_, i) => (i * 31 + (i >> 8)) % 256));

function setup(): void {
  mkdirSync(join(root, "dir"), { recursive: true });
  mkdirSync(join(root, "empty-dir"));
  mkdirSync(outside);
  writeFileSync(join(root, "hello.txt"), "hello world");
  writeFileSync(join(root, "index.html"), "<h1>root index</h1>");
  writeFileSync(join(root, "dir", "index.html"), "<p>dir index</p>");
  writeFileSync(join(root, "data.bin"), data);
  writeFileSync(join(root, "large.bin"), large);
  writeFileSync(join(root, "café.txt"), "unicode name");
  writeFileSync(join(root, ".env"), "SECRET=dotfile");
  writeFileSync(join(root, "%2e%2e"), "literal percent name");
  for (const name of [
    "style.css",
    "app.js",
    "module.mjs",
    "data.json",
    "logo.svg",
    "image.PNG",
    "font.woff2",
    "page.htm",
    "blob.xyz",
    "noext",
  ])
    writeFileSync(join(root, name), "x");
  writeFileSync(join(outside, "secret.txt"), "TOP SECRET");
  symlinkSync(join(outside, "secret.txt"), join(root, "leak.txt"));
  symlinkSync(outside, join(root, "leakdir"));
  symlinkSync("hello.txt", join(root, "inside-link.txt"));
  const fifo = Bun.spawnSync(["mkfifo", join(root, "fifo")], { timeout: 5000 });
  if (fifo.exitCode !== 0) throw new Error("mkfifo failed");
}
setup();

let server: RunningServer;
beforeAll(async () => {
  server = await start(binary, "127.0.0.1", { BENDO_STATIC_ROOT: root, BENDO_STATIC_APP: APP });
});
afterAll(async () => {
  await server[Symbol.asyncDispose]();
  rmSync(base, { recursive: true, force: true });
});

type RawResponse = { status: number; head: string; body: Buffer };

/** Sends a request target byte for byte; fetch would normalize dot segments. */
async function raw(target: string, method = "GET"): Promise<RawResponse> {
  const port = Number(new URL(server.url).port);
  const bytes = await new Promise<Buffer>((done, fail) => {
    const socket = connect(port, "127.0.0.1");
    const chunks: Buffer[] = [];
    socket.setTimeout(5000, () => socket.destroy(new Error("socket timeout")));
    socket.on("connect", () =>
      socket.write(
        Buffer.concat([
          Buffer.from(`${method} `, "latin1"),
          Buffer.from(target, "latin1"),
          Buffer.from(" HTTP/1.1\r\nHost: test\r\nConnection: close\r\n\r\n", "latin1"),
        ]),
      ),
    );
    socket.on("data", (chunk: Buffer) => chunks.push(chunk));
    socket.on("error", fail);
    socket.on("end", () => done(Buffer.concat(chunks)));
  });
  const split = bytes.indexOf("\r\n\r\n");
  const head = bytes.subarray(0, split).toString("latin1");
  const status = Number(/^HTTP\/1\.1 (\d{3})/.exec(head)?.[1] ?? Number.NaN);
  return { status, head, body: bytes.subarray(split + 4) };
}

async function get(path: string, headers: Record<string, string> = {}): Promise<Response> {
  return fetch(server.url + path, { headers, redirect: "manual" });
}

function tagOf(path: string): string {
  const st = statSync(path);
  return `W/"${st.size}-${Math.floor(st.mtimeMs / 1000)}"`;
}

function modifiedOf(path: string): string {
  return new Date(Math.floor(statSync(path).mtimeMs / 1000) * 1000).toUTCString();
}

describe("serving files", () => {
  test("a text file with validators and safety headers", async () => {
    const response = await get("/static/hello.txt");
    expect(response.status).toBe(200);
    expect(await response.text()).toBe("hello world");
    expect(response.headers.get("content-type")).toBe("text/plain; charset=utf-8");
    expect(response.headers.get("content-length")).toBe("11");
    expect(response.headers.get("x-content-type-options")).toBe("nosniff");
    expect(response.headers.get("accept-ranges")).toBe("bytes");
    expect(response.headers.get("cache-control")).toBe("public, max-age=60");
    expect(response.headers.get("etag")).toBe(tagOf(join(root, "hello.txt")));
    expect(response.headers.get("last-modified")).toBe(modifiedOf(join(root, "hello.txt")));
  });

  test("HEAD sends the GET length and no body", async () => {
    const response = await raw("/static/hello.txt", "HEAD");
    expect(response.status).toBe(200);
    expect(response.head).toContain("\r\ncontent-length: 11");
    expect(response.head).toContain("\r\netag: ");
    expect(response.body.length).toBe(0);
  });

  test("binary files arrive intact across several 64 KiB reads", async () => {
    const response = await get("/static/large.bin");
    expect(response.status).toBe(200);
    expect(response.headers.get("content-type")).toBe("application/octet-stream");
    const body = Buffer.from(await response.arrayBuffer());
    expect(body.length).toBe(large.length);
    expect(createHash("sha256").update(body).digest("hex")).toBe(
      createHash("sha256").update(large).digest("hex"),
    );
  });

  test("a percent-encoded UTF-8 name is decoded once", async () => {
    const response = await get("/static/caf%C3%A9.txt");
    expect(response.status).toBe(200);
    expect(await response.text()).toBe("unicode name");
  });

  test.each([
    ["style.css", "text/css; charset=utf-8"],
    ["app.js", "text/javascript; charset=utf-8"],
    ["module.mjs", "text/javascript; charset=utf-8"],
    ["data.json", "application/json; charset=utf-8"],
    ["logo.svg", "image/svg+xml; charset=utf-8"],
    ["image.PNG", "image/png"],
    ["font.woff2", "font/woff2"],
    ["page.htm", "text/html; charset=utf-8"],
    ["blob.xyz", "application/octet-stream"],
    ["noext", "application/octet-stream"],
  ])("Content-Type for %s", async (name, type) => {
    const response = await get(`/static/${name}`);
    expect(response.status).toBe(200);
    expect(response.headers.get("content-type")).toBe(type);
  });
});

describe("directories and index files", () => {
  test("a trailing slash serves index.html", async () => {
    const response = await get("/static/dir/");
    expect(response.status).toBe(200);
    expect(response.headers.get("content-type")).toBe("text/html; charset=utf-8");
    expect(await response.text()).toBe("<p>dir index</p>");
    expect(await (await get("/static/")).text()).toBe("<h1>root index</h1>");
  });

  test("a directory without its slash redirects, keeping the query", async () => {
    const response = await get("/static/dir?x=1");
    expect(response.status).toBe(301);
    expect(response.headers.get("location")).toBe("/static/dir/?x=1");
    const mount = await get("/static");
    expect(mount.status).toBe(301);
    expect(mount.headers.get("location")).toBe("/static/");
  });

  test("no index means 404, never a listing", async () => {
    expect((await get("/static/empty-dir/")).status).toBe(404);
    expect((await get("/noindex/")).status).toBe(404);
    expect((await get("/noindex/dir/")).status).toBe(404);
    expect((await get("/noindex/dir")).status).toBe(404);
    expect((await get("/static/missing.txt")).status).toBe(404);
  });
});

describe("conditional requests", () => {
  const file = (): string => join(root, "hello.txt");

  test("If-None-Match with the current tag gives 304 with validators and no body", async () => {
    const response = await raw("/static/hello.txt", "GET");
    expect(response.status).toBe(200);
    for (const value of [tagOf(file()), tagOf(file()).slice(2), `"other", ${tagOf(file())}`, "*"]) {
      const cached = await get("/static/hello.txt", { "if-none-match": value });
      expect(cached.status).toBe(304);
      expect(cached.headers.get("etag")).toBe(tagOf(file()));
      expect(cached.headers.get("last-modified")).toBe(modifiedOf(file()));
      expect(await cached.text()).toBe("");
    }
  });

  test("a different tag gives 200 even when If-Modified-Since would match", async () => {
    const response = await get("/static/hello.txt", {
      "if-none-match": 'W/"1-1"',
      "if-modified-since": modifiedOf(file()),
    });
    expect(response.status).toBe(200);
    expect(await response.text()).toBe("hello world");
  });

  test("If-Modified-Since at or after the file time gives 304", async () => {
    expect(
      (await get("/static/hello.txt", { "if-modified-since": modifiedOf(file()) })).status,
    ).toBe(304);
    const later = new Date(Date.parse(modifiedOf(file())) + 3_600_000).toUTCString();
    expect((await get("/static/hello.txt", { "if-modified-since": later })).status).toBe(304);
    const earlier = new Date(Date.parse(modifiedOf(file())) - 3_600_000).toUTCString();
    expect((await get("/static/hello.txt", { "if-modified-since": earlier })).status).toBe(200);
    expect((await get("/static/hello.txt", { "if-modified-since": "yesterday" })).status).toBe(200);
  });
});

describe("range requests", () => {
  async function range(value: string, extra: Record<string, string> = {}) {
    const response = await get("/static/data.bin", { range: value, ...extra });
    return {
      status: response.status,
      contentRange: response.headers.get("content-range"),
      length: response.headers.get("content-length"),
      body: Buffer.from(await response.arrayBuffer()),
    };
  }

  test.each([
    ["bytes=0-99", 0, 99],
    ["bytes=500-", 500, 1999],
    ["bytes=-500", 1500, 1999],
    ["bytes=1990-5000", 1990, 1999],
    ["bytes=-5000", 0, 1999],
    ["bytes=7-7", 7, 7],
    ["BYTES=10-19", 10, 19],
    ["bytes=99999999999999999999-", -1, -1],
  ])("%s", async (value, first, last) => {
    const result = await range(value);
    if (first < 0) {
      expect(result.status).toBe(416);
      expect(result.contentRange).toBe("bytes */2000");
      return;
    }
    expect(result.status).toBe(206);
    expect(result.contentRange).toBe(`bytes ${first}-${last}/2000`);
    expect(result.length).toBe(String(last - first + 1));
    expect(result.body.equals(data.subarray(first, last + 1))).toBe(true);
  });

  test("ranges crossing a 64 KiB read boundary", async () => {
    const response = await get("/static/large.bin", { range: "bytes=65530-131080" });
    expect(response.status).toBe(206);
    const body = Buffer.from(await response.arrayBuffer());
    expect(body.equals(large.subarray(65530, 131081))).toBe(true);
  });

  test.each(["bytes=2000-", "bytes=2000-2001", "bytes=-0"])(
    "unsatisfiable %s gives 416 with bytes */length",
    async (value) => {
      const result = await range(value);
      expect(result.status).toBe(416);
      expect(result.contentRange).toBe("bytes */2000");
    },
  );

  test("an empty file satisfies no range", async () => {
    writeFileSync(join(root, "empty.txt"), "");
    const response = await get("/static/empty.txt", { range: "bytes=0-" });
    expect(response.status).toBe(416);
    expect(response.headers.get("content-range")).toBe("bytes */0");
  });

  test.each([
    "bytes=0-1,5-6",
    "bytes=5-1",
    "bytes=abc",
    "items=0-1",
    "bytes=",
    "bytes=-",
    "bytes=1-2x",
  ])("multiple, reversed or malformed %s is ignored: 200 with the whole file", async (value) => {
    const result = await range(value);
    expect(result.status).toBe(200);
    expect(result.contentRange).toBeNull();
    expect(result.body.equals(data)).toBe(true);
  });

  test("If-Range keeps the range only for the exact Last-Modified date", async () => {
    const modified = modifiedOf(join(root, "data.bin"));
    expect((await range("bytes=0-9", { "if-range": modified })).status).toBe(206);
    const stale = new Date(Date.parse(modified) - 1000).toUTCString();
    const full = await range("bytes=0-9", { "if-range": stale });
    expect(full.status).toBe(200);
    expect(full.body.equals(data)).toBe(true);
    // Weak tags never pass the strong comparison If-Range requires.
    expect((await range("bytes=0-9", { "if-range": tagOf(join(root, "data.bin")) })).status).toBe(
      200,
    );
  });

  test("HEAD with a range sends 206 headers and no body", async () => {
    const response = await fetch(server.url + "/static/data.bin", {
      method: "HEAD",
      headers: { range: "bytes=0-9" },
    });
    expect(response.status).toBe(206);
    expect(response.headers.get("content-range")).toBe("bytes 0-9/2000");
    expect(response.headers.get("content-length")).toBe("10");
  });
});

describe("confinement", () => {
  // Each target tries to reach ../outside/secret.txt or a hidden file.
  test.each([
    "/static/../outside/secret.txt",
    "/static/%2e%2e/outside/secret.txt",
    "/static/%2E%2E/outside/secret.txt",
    "/static/%2e%2e%2foutside%2fsecret.txt",
    "/static/..%2foutside%2fsecret.txt",
    "/static/..%2Foutside/secret.txt",
    "/static/%252e%252e/outside/secret.txt",
    "/static/%252e%252e%252foutside%252fsecret.txt",
    "/static/%2e%2e",
    "/static/..%5coutside%5csecret.txt",
    "/static/..\\outside\\secret.txt",
    "/static/%c0%ae%c0%ae/outside/secret.txt",
    "/static/%c0%af",
    "/static/%e0%80%ae%e0%80%ae/outside/secret.txt",
    "/static/hello.txt%00",
    "/static/hello.txt%00.png",
    "/static/%00",
    "/static//outside/secret.txt",
    "/static/./hello.txt",
    "/static/dir/../hello.txt",
    "/static/.env",
    "/static/%2eenv",
    "/static/%2e",
    "/static/leak.txt",
    "/static/leakdir/secret.txt",
    "/static/leakdir/",
    "/staticx/hello.txt",
  ])("%s gets 400 or 404", async (target) => {
    const response = await raw(target);
    expect([400, 404]).toContain(response.status);
    expect(response.body.toString("latin1")).not.toContain("SECRET");
  });

  test("a symlink inside the root is refused even when its target is inside", async () => {
    expect((await get("/static/inside-link.txt")).status).toBe(404);
  });

  test("a FIFO is refused without blocking the server", async () => {
    expect((await get("/static/fifo")).status).toBe(404);
    expect((await get("/static/hello.txt")).status).toBe(200);
  });

  test("other methods get 405 with Allow", async () => {
    const response = await fetch(server.url + "/any/hello.txt", { method: "POST", body: "x" });
    expect(response.status).toBe(405);
    expect(response.headers.get("allow")).toBe("GET, HEAD");
  });

  test("a body over max_bytes is refused, and a range under it is served", async () => {
    expect((await get("/small/data.bin")).status).toBe(500);
    const part = await get("/small/data.bin", { range: "bytes=0-99" });
    expect(part.status).toBe(206);
    expect(Buffer.from(await part.arrayBuffer()).equals(data.subarray(0, 100))).toBe(true);
  });
});

describe("open effect twins", () => {
  function run(command: string[]): string[] {
    const result = Bun.spawnSync(command, { stdout: "pipe", stderr: "pipe", timeout: 20_000 });
    if (result.exitCode !== 0) throw new Error(`${command.join(" ")} failed: ${result.stderr}`);
    return result.stdout.toString().trim().split("\n");
  }

  test("native and JavaScript twins agree on every case", () => {
    const paths = [
      "hello.txt",
      "leak.txt",
      "leakdir/secret.txt",
      "inside-link.txt",
      "fifo",
      "dir",
      "dir/index.html",
      "missing",
      "../outside/secret.txt",
      "dir/./index.html",
      "",
      "hello.txt/x",
    ].map((rel) => `${root}/${rel}`);
    paths.push(`${outside}/secret.txt`, `${root}x/hello.txt`);
    const native = run([openNative, root, ...paths]);
    const js = run([process.execPath, openJs, root, ...paths]);
    expect(js).toEqual(native);
    expect(native[0]).toBe(`${root}/hello.txt file 11 hello world`);
    expect(native[5]).toBe(`${root}/dir fail 21`);
    expect(native[6]).toStartWith(`${root}/dir/index.html file 16`);
    for (const index of [1, 2, 3, 4, 7, 8, 9, 10, 11, 12, 13]) {
      expect(native[index]).toMatch(/ fail \d+$/);
    }
  });
});

describe("a Vite build", () => {
  test("index.html and its hashed assets are served with their types", async () => {
    const page = await get("/");
    expect(page.status).toBe(200);
    expect(page.headers.get("content-type")).toBe("text/html; charset=utf-8");
    const html = await page.text();
    const assets = readdirSync(join(APP, "assets"));
    expect(assets.length).toBeGreaterThanOrEqual(2);
    for (const asset of assets) {
      expect(html).toContain(`/assets/${asset}`);
      const response = await get(`/assets/${asset}`);
      expect(response.status).toBe(200);
      expect(response.headers.get("content-type")).toBe(
        asset.endsWith(".js") ? "text/javascript; charset=utf-8" : "text/css; charset=utf-8",
      );
      expect(
        Buffer.from(await response.arrayBuffer()).equals(readFileSync(join(APP, "assets", asset))),
      ).toBe(true);
    }
  });
});
