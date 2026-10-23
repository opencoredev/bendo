import { describe, expect, test } from "bun:test";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { findBend } from "../packages/bendo/src/bend.ts";
import { connect } from "node:net";
import { BEND_COMPILE_TIMEOUT, build, COMPILE_TEST_TIMEOUT_MS, start } from "./harness.ts";

function exchange(url: string, method: string, target: string): Promise<string> {
  const address = new URL(url);
  return new Promise((resolve, reject) => {
    const chunks: Buffer[] = [];
    const socket = connect(Number(address.port), address.hostname, () => {
      socket.write(`${method} ${target} HTTP/1.1\r\nHost: test\r\nConnection: close\r\n\r\n`);
    });
    socket.setTimeout(5000, () => socket.destroy(new Error("HTTP exchange timed out")));
    socket.on("data", (chunk: Buffer) => chunks.push(chunk));
    socket.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
    socket.on("error", reject);
  });
}

function splitResponse(wire: string): { head: string; body: string } {
  const boundary = wire.indexOf("\r\n\r\n");
  if (boundary < 0) throw new Error("Missing HTTP head delimiter");
  return { head: wire.slice(0, boundary), body: wire.slice(boundary + 4) };
}

const standardAllow = "GET, HEAD, POST, PUT, DELETE, CONNECT, OPTIONS, TRACE, PATCH";

describe("method-aware router", () => {
  const binary = build("tests/servers/router-methods.bend");

  test("each constructor and on choose the method without earlier path shadowing", async () => {
    await using server = await start(binary);
    const constructors: readonly (readonly [string, string])[] = [
      ["GET", "get:0"],
      ["POST", "post:1"],
      ["PUT", "put:2"],
      ["PATCH", "patch:3"],
      ["DELETE", "delete:4"],
      ["OPTIONS", "options:5"],
    ];
    for (const [method, body] of constructors) {
      const response = await fetch(`${server.url}/resource`, { method });
      expect(response.status, method).toBe(200);
      expect(await response.text(), method).toBe(body);
    }
    for (const method of ["POST", "PATCH"]) {
      expect(await (await fetch(`${server.url}/multi`, { method })).text()).toBe("multi:9");
    }
    const extension = splitResponse(await exchange(server.url, "PROPFIND", "/extension"));
    expect(extension.head).toStartWith("HTTP/1.1 200 ");
    expect(extension.body).toBe("extension:10");
    const wrongCase = splitResponse(await exchange(server.url, "propfind", "/extension"));
    expect(wrongCase.head).toStartWith("HTTP/1.1 405 ");
  });

  test("HEAD fallback preserves every GET header, including octet Content-Length, without bytes", async () => {
    await using server = await start(binary);
    const get = splitResponse(await exchange(server.url, "GET", "/resource"));
    const head = splitResponse(await exchange(server.url, "HEAD", "/resource"));
    expect(head.head).toBe(get.head);
    expect(get.body).toBe("get:0");
    expect(head.head).toContain("content-length: 5\r\n");
    expect(head.body).toBe("");
    const unicodeGet = splitResponse(await exchange(server.url, "GET", "/unicode"));
    const unicodeHead = splitResponse(await exchange(server.url, "HEAD", "/unicode"));
    expect(unicodeGet.body).toBe("hé 🌍:19");
    expect(unicodeHead.head).toBe(unicodeGet.head);
    expect(unicodeHead.head).toContain("content-length: 11\r\n");
    expect(unicodeHead.body).toBe("");
  });

  test("an explicit HEAD registered after GET wins across overlapping patterns", async () => {
    await using server = await start(binary);
    const get = splitResponse(await exchange(server.url, "GET", "/explicit/ABC"));
    const head = splitResponse(await exchange(server.url, "HEAD", "/explicit/ABC"));
    expect(get.body).toBe("get-explicit:6|id=ABC");
    expect(head.head).toContain("x-route: head-explicit:7|name=ABC");
    expect(head.body).toBe("");
  });

  test("all registers nine standard methods and excludes extension methods", async () => {
    await using server = await start(binary);
    for (const method of ["GET", "POST", "PUT", "DELETE", "OPTIONS", "TRACE", "PATCH"]) {
      expect(splitResponse(await exchange(server.url, method, "/all")).body).toBe("all:8");
    }
    expect(splitResponse(await exchange(server.url, "HEAD", "/all")).body).toBe("");
    const denied = splitResponse(await exchange(server.url, "PROPFIND", "/all"));
    expect(denied.head).toStartWith("HTTP/1.1 405 ");
    expect(denied.head.split("\r\n")).toContain(`allow: ${standardAllow}`);
  });

  test("405 lists exactly the union of matching routes, canonical, deduplicated and HEAD-inclusive", async () => {
    await using server = await start(binary);
    const denied = await fetch(`${server.url}/resource`, { method: "TRACE" });
    expect(denied.status).toBe(405);
    expect(denied.headers.get("allow")).toBe("GET, HEAD, POST, PUT, DELETE, OPTIONS, PATCH");
    const extension = splitResponse(await exchange(server.url, "GET", "/extension"));
    expect(extension.head.split("\r\n")).toContain("allow: PROPFIND, REPORT, ZETA");
    const overlap = await fetch(`${server.url}/overlap/new`, { method: "DELETE" });
    expect(overlap.status).toBe(405);
    expect(overlap.headers.get("allow")).toBe("GET, HEAD, POST");
  });

  test("404 means no path match; empty on still creates a path and OPTIONS is not automatic", async () => {
    await using server = await start(binary);
    const absent = await fetch(`${server.url}/missing`);
    expect(absent.status).toBe(404);
    expect(absent.headers.get("allow")).toBeNull();
    const empty = await fetch(`${server.url}/empty`);
    expect(empty.status).toBe(405);
    expect(empty.headers.get("allow")).toBe("");
    const options = await fetch(`${server.url}/unicode`, { method: "OPTIONS" });
    expect(options.status).toBe(405);
    expect(options.headers.get("allow")).toBe("GET, HEAD");
  });

  test("strict/case defaults and all four option combinations retain capture case and constraints", async () => {
    await using server = await start(binary);
    const cases: readonly (readonly [string, number, string])[] = [
      ["/Mixed/AbC", 200, "mixed:11|Value=AbC"],
      ["/mixed/AbC", 404, "Not Found"],
      ["/Mixed/AbC/", 404, "Not Found"],
      ["/Mixed/AbC/?lenient", 200, "mixed:11|Value=AbC"],
      ["/mixed/AbC?lenient", 404, "Not Found"],
      ["/Mixed//AbC?lenient", 404, "Not Found"],
      ["/mIxEd/AbC?case", 200, "mixed:11|Value=AbC"],
      ["/mIxEd/AbC/?case", 404, "Not Found"],
      ["/mIxEd/AbC///?relaxed", 200, "mixed:11|Value=AbC"],
      ["/SLASH?relaxed", 200, "slash:12"],
      ["/Slash/?lenient", 200, "slash:12"],
      ["/Slash", 404, "Not Found"],
      ["/Slash/", 200, "slash:12"],
      ["/?lenient", 200, "root:13"],
      ["////?lenient", 200, "root:13"],
      ["/wild/AbC/XyZ?case", 200, "wild:14|Tail=AbC/XyZ"],
      ["/Wild/AbC//", 200, "wild:14|Tail=AbC//"],
      ["/Wild/AbC//?lenient", 200, "wild:14|Tail=AbC"],
      ["/lower/ABC?case", 404, "Not Found"],
      ["/lower/abc?case", 200, "lower:15|Value=abc"],
      ["/mIxEd/%41bC?case", 200, "mixed:11|Value=AbC"],
    ];
    for (const [path, status, body] of cases) {
      const response = await fetch(`${server.url}${path}`);
      expect(response.status, path).toBe(status);
      expect(await response.text(), path).toBe(body);
    }
    const denied = await fetch(`${server.url}/MIXED/AbC///?relaxed`, { method: "POST" });
    expect(denied.status).toBe(405);
    expect(denied.headers.get("allow")).toBe("GET, HEAD");
  });
});

const binary = build("tests/router-methods-driver.bend");
test("public construction normalizes standards, rejects invalid tokens atomically and preserves extension case", () => {
  const result = Bun.spawnSync(["timeout", "--foreground", "10s", binary], {
    stdout: "pipe",
    stderr: "pipe",
  });
  expect(result.exitCode).toBe(0);
  expect(result.stdout.toString().trim().split("\n")).toEqual([
    "first:0:direct",
    "first:1:direct",
    "later:3:direct",
    "first:4:fallback",
    "405:HEAD",
    "first:0:direct",
    `405:${standardAllow}`,
    "1:bad:MissingSlash: bad",
    "405:GET, HEAD",
    "first:0:direct",
    "first:0:fallback",
    "405:GET, HEAD",
    "405:GET, HEAD",
    "first:0:direct",
    "first:0:fallback",
    "405:GET, HEAD",
    "405:GET, HEAD",
    "405:get",
    "405:get",
    "405:get",
    "first:0:direct",
    "1:/a:InvalidMethod:",
    "1:/a:InvalidMethod:BAD TOKEN",
    "first:0:direct",
    "first:0:fallback",
    "405:GET, HEAD, get",
    "first:0:direct",
    "0:/a:InvalidMethod:BAD TOKEN",
  ]);
}, 30000);

for (const fixture of ["raw-table", "forged-none", "forged-valid", "forged-checked-none"]) {
  test(
    `the compiler rejects the ${fixture} validation bypass`,
    () => {
      const bend = findBend();
      if (bend.kind === "missing") throw new Error("bend is not installed");
      const directory = mkdtempSync(join(tmpdir(), "bendo-method-bypass-"));
      try {
        const result = Bun.spawnSync(
          [
            "timeout",
            "--foreground",
            BEND_COMPILE_TIMEOUT,
            bend.path,
            join(import.meta.dir, "fixtures/router-methods", `${fixture}.bend`),
            "-o",
            join(directory, "bypass.mjs"),
          ],
          { stdout: "pipe", stderr: "pipe" },
        );
        expect(result.exitCode).toBe(1);
        const diagnostic = result.stdout.toString() + result.stderr.toString();
        expect(diagnostic).toContain("SOME PROOFS FAIL");
        expect(diagnostic).toContain("expected :");
        expect(diagnostic).toContain("observed :");
        expect(diagnostic).toContain("Location: main");
      } finally {
        rmSync(directory, { recursive: true, force: true });
      }
    },
    COMPILE_TEST_TIMEOUT_MS,
  );
}
