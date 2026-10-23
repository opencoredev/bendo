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
  utimesSync,
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
// Larger than one 64 KiB read, smaller than the default 1 MiB buffer.
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
const setupDone = Date.now();

/** Files get validators only once their mtime and ctime are two seconds old. */
const SETTLE_MS = 2200;

let server: RunningServer;
beforeAll(async () => {
  server = await start(binary, "127.0.0.1", { BENDO_STATIC_ROOT: root, BENDO_STATIC_APP: APP });
  await Bun.sleep(Math.max(0, setupDone + SETTLE_MS - Date.now()));
});
afterAll(async () => {
  await server[Symbol.asyncDispose]();
  rmSync(base, { recursive: true, force: true });
});

type RawResponse = { status: number; head: string; body: Buffer };

/** Sends a request target byte for byte; fetch would normalize dot segments. */
async function raw(target: string, method = "GET", version = "1.1"): Promise<RawResponse> {
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
          Buffer.from(` HTTP/${version}\r\nHost: test\r\nConnection: close\r\n\r\n`, "latin1"),
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

/** The strong tag static_file.c builds: dev, inode, size, mtime and ctime in hex. */
function tagOf(path: string): string {
  const st = statSync(path, { bigint: true });
  const time = (ns: bigint): string =>
    `${(ns / 1_000_000_000n).toString(16)}.${(ns % 1_000_000_000n).toString(16)}`;
  const ids = [st.dev, st.ino, st.size].map((n) => n.toString(16)).join("-");
  return `"${ids}-${time(st.mtimeNs)}-${time(st.ctimeNs)}"`;
}

/** Open descriptors of the server process, or undefined off Linux. */
function openFds(): number | undefined {
  if (process.platform !== "linux") return undefined;
  return readdirSync(`/proc/${server.pid}/fd`).length;
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

  test("HEAD sends the GET validators and no body, without reading the file", async () => {
    const response = await raw("/static/hello.txt", "HEAD");
    expect(response.status).toBe(200);
    expect(response.head).toContain(`\r\netag: ${tagOf(join(root, "hello.txt"))}`);
    expect(response.head).toContain("\r\ncontent-type: text/plain; charset=utf-8");
    // The transport derives Content-Length from a body; HEAD never reads one.
    expect(response.head).not.toContain("content-length");
    expect(response.head).not.toContain("transfer-encoding");
    expect(response.body.length).toBe(0);
  });

  test("HTTP/1.0 HEAD reads a buffered body to send its length", async () => {
    const response = await raw("/static/hello.txt", "HEAD", "1.0");
    expect(response.status).toBe(200);
    expect(response.head).toContain("\r\ncontent-length: 11");
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
    for (const value of [tagOf(file()), `W/${tagOf(file())}`, `"other", ${tagOf(file())}`, "*"]) {
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

describe("validators follow content", () => {
  test("a file changed in the last two seconds has no validators and ignores conditionals", async () => {
    const path = join(root, "fresh.txt");
    writeFileSync(path, "fresh");
    const response = await get("/static/fresh.txt", {
      "if-none-match": "*",
      "if-modified-since": new Date(Date.now() + 3_600_000).toUTCString(),
    });
    expect(response.status).toBe(200);
    expect(await response.text()).toBe("fresh");
    expect(response.headers.get("etag")).toBeNull();
    expect(response.headers.get("last-modified")).toBeNull();
  });

  test("a same-size rewrite that restores mtime still changes the tag", async () => {
    const path = join(root, "swap.txt");
    writeFileSync(path, "hello world");
    const old = statSync(path);
    await Bun.sleep(SETTLE_MS);
    const first = await get("/static/swap.txt");
    const tag = first.headers.get("etag");
    const modified = first.headers.get("last-modified");
    expect(tag).toBe(tagOf(path));
    expect(modified).not.toBeNull();
    // Same size, same mtime: only ctime records the change.
    writeFileSync(path, "other bytes");
    utimesSync(path, old.atime, old.mtime);
    const soon = await get("/static/swap.txt", { "if-none-match": tag ?? "" });
    expect(soon.status).toBe(200);
    expect(await soon.text()).toBe("other bytes");
    await Bun.sleep(SETTLE_MS);
    const later = await get("/static/swap.txt", { "if-none-match": tag ?? "" });
    expect(later.status).toBe(200);
    expect(await later.text()).toBe("other bytes");
    expect(later.headers.get("etag")).not.toBe(tag);
    expect(later.headers.get("last-modified")).toBe(modified);
    // The restored mtime matches, but ctime is newer, so not 304.
    expect((await get("/static/swap.txt", { "if-modified-since": modified ?? "" })).status).toBe(
      200,
    );
    expect(
      (await get("/static/swap.txt", { "if-none-match": later.headers.get("etag") ?? "" })).status,
    ).toBe(304);
  }, 30_000);
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
    // The tags are strong, so the current tag keeps the range too.
    expect((await range("bytes=0-9", { "if-range": tagOf(join(root, "data.bin")) })).status).toBe(
      206,
    );
    expect(
      (await range("bytes=0-9", { "if-range": `W/${tagOf(join(root, "data.bin"))}` })).status,
    ).toBe(200);
    expect((await range("bytes=0-9", { "if-range": '"other"' })).status).toBe(200);
  });

  test("HEAD with a range sends 206 headers and no body", async () => {
    const response = await fetch(server.url + "/static/data.bin", {
      method: "HEAD",
      headers: { range: "bytes=0-9" },
    });
    expect(response.status).toBe(206);
    expect(response.headers.get("content-range")).toBe("bytes 0-9/2000");
    expect(await response.text()).toBe("");
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
});

describe("streaming bodies above buffer_bytes", () => {
  test("a body over buffer_bytes streams chunked; a range under it is buffered", async () => {
    const whole = await raw("/small/data.bin");
    expect(whole.status).toBe(200);
    expect(whole.head).toContain("\r\ntransfer-encoding: chunked");
    expect(whole.head).not.toContain("content-length");
    expect(whole.head).toContain(`\r\netag: ${tagOf(join(root, "data.bin"))}`);
    const streamed = await get("/small/data.bin");
    expect(Buffer.from(await streamed.arrayBuffer()).equals(data)).toBe(true);
    const part = await get("/small/data.bin", { range: "bytes=0-99" });
    expect(part.status).toBe(206);
    expect(part.headers.get("content-length")).toBe("100");
    expect(Buffer.from(await part.arrayBuffer()).equals(data.subarray(0, 100))).toBe(true);
  });

  test("a long range streams across 64 KiB reads", async () => {
    const response = await get("/small/large.bin", { range: "bytes=1000-150000" });
    expect(response.status).toBe(206);
    expect(response.headers.get("content-range")).toBe(`bytes 1000-150000/${large.length}`);
    expect(response.headers.get("content-length")).toBeNull();
    expect(Buffer.from(await response.arrayBuffer()).equals(large.subarray(1000, 150001))).toBe(
      true,
    );
    const whole = await get("/small/large.bin");
    expect(
      createHash("sha256")
        .update(Buffer.from(await whole.arrayBuffer()))
        .digest("hex"),
    ).toBe(createHash("sha256").update(large).digest("hex"));
  });

  test("HTTP/1.0 cannot carry a stream and gets 505", async () => {
    expect((await raw("/small/data.bin", "GET", "1.0")).status).toBe(505);
    expect((await raw("/small/data.bin", "HEAD", "1.0")).status).toBe(505);
    expect((await raw("/static/data.bin", "GET", "1.0")).status).toBe(200);
  });

  test("streams, HEADs and aborted downloads leave no descriptor open", async () => {
    const before = openFds();
    for (let i = 0; i < 20; i++) {
      await (await get("/small/large.bin")).arrayBuffer();
      await raw("/small/large.bin", "HEAD");
      await raw("/static/hello.txt", "HEAD");
      // Read the first chunk, then drop the download mid-stream.
      const reader = (await get("/small/large.bin")).body?.getReader();
      await reader?.read();
      await reader?.cancel();
    }
    await Bun.sleep(500);
    const after = openFds();
    if (before !== undefined && after !== undefined) expect(after).toBeLessThanOrEqual(before + 2);
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
    const hello = statSync(join(root, "hello.txt"));
    const seconds = Math.floor(hello.mtimeMs / 1000);
    const changed = Math.max(seconds, Math.floor(hello.ctimeMs / 1000));
    const stamp = tagOf(join(root, "hello.txt")).slice(1, -1);
    expect(native[0]).toBe(
      `${root}/hello.txt file 11 ${seconds} ${changed} [${stamp}] hello world`,
    );
    expect(native[5]).toBe(`${root}/dir fail 21`);
    expect(native[6]).toStartWith(`${root}/dir/index.html file 16 `);
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

  test("the bundle names its third-party licenses and their texts are served", async () => {
    const notices = await get("/THIRD_PARTY_LICENSES.txt");
    expect(notices.status).toBe(200);
    const text = await notices.text();
    for (const name of ["react@", "react-dom@", "scheduler@"]) expect(text).toContain(name);
    expect(text).toContain("Permission is hereby granted");
    for (const asset of readdirSync(join(APP, "assets")).filter((a) => a.endsWith(".js"))) {
      const code = readFileSync(join(APP, "assets", asset), "utf8");
      expect(code).toStartWith("/*! Bundles react@");
      expect(code).toContain("/THIRD_PARTY_LICENSES.txt");
    }
  });
});
