import { beforeAll, afterAll, describe, expect, test } from "bun:test";
import { connect } from "node:net";
import { build, start, type RunningServer } from "./harness.ts";

const binary = build("tests/servers/context.bend");
let server: RunningServer;
beforeAll(async () => {
  server = await start(binary);
});
afterAll(async () => {
  await server[Symbol.asyncDispose]();
});

async function raw(path: string, fields: Buffer): Promise<string> {
  return new Promise((resolve, reject) => {
    const socket = connect(Number(new URL(server.url).port), "127.0.0.1");
    const chunks: Buffer[] = [];
    socket.setTimeout(5000, () => socket.destroy(new Error("socket timeout")));
    socket.on("connect", () =>
      socket.write(
        Buffer.concat([
          Buffer.from(`GET ${path} HTTP/1.1\r\nHost: test\r\n`),
          fields,
          Buffer.from("\r\n"),
        ]),
      ),
    );
    socket.on("data", (chunk: Buffer) => chunks.push(chunk));
    socket.on("error", reject);
    socket.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
  });
}

describe("context request accessors through native HTTP", () => {
  test.each([
    ["/param/caf%C3%A9", "café|<none>"],
    ["/query?q=first&q=second", "first|<none>"],
    ["/query?q=", "|<none>"],
    ["/query", "<none>|<none>"],
    ["/queries?q=one+two&q=%E4%B8%96%E7%95%8C&q=&other=x&q=last", "one two|世界||last"],
    ["/queries", ""],
    ["/path?raw=%2F", "/path"],
    ["/url?raw=%2f&x=+", "/url?raw=%2f&x=+"],
    ["/url?", "/url?"],
  ])("%s", async (path, expected) => {
    const response = await fetch(server.url + path);
    expect(response.status).toBe(200);
    expect(await response.text()).toBe(expected);
  });
  test("method preserves the parsed method", async () => {
    const response = await fetch(server.url + "/method", { method: "PATCH" });
    expect(await response.text()).toBe("PATCH");
  });
  test("headers use first occurrence, case-insensitive lookup, strict UTF-8 and raw bytes", async () => {
    expect(await raw("/header", Buffer.from("X-VALUE: café\r\nx-value: second\r\n"))).toEndWith(
      "café",
    );
    expect(
      await raw("/header", Buffer.from([88, 45, 86, 65, 76, 85, 69, 58, 32, 255, 13, 10])),
    ).toEndWith("<none>");
    expect(await raw("/header", Buffer.alloc(0))).toEndWith("<none>");
    expect(
      await raw("/header-bytes", Buffer.from([88, 45, 86, 65, 76, 85, 69, 58, 32, 255, 13, 10])),
    ).toEndWith("255");
    expect(await raw("/header-bytes", Buffer.alloc(0))).toEndWith("absent");
  });
  test.each(["/query?good=yes&bad=%FF", "/query?q=%FF", "/no-route?x=%FF", "/echo?x=%C0%80"])(
    "malformed query rejects before dispatch: %s",
    async (path) => {
      const response = await fetch(server.url + path);
      expect(response.status).toBe(400);
      expect(await response.text()).toBe("Bad Request");
    },
  );
});

test.each(["/query?good=yes&bad=%GG", "/no-route?x=%"])(
  "HTTP parser rejects malformed percent syntax: %s",
  async (path) => {
    const response = await fetch(server.url + path);
    expect(response.status).toBe(400);
    expect(await response.text()).toBe("");
  },
);

describe("context response helpers through native HTTP", () => {
  test.each([
    ["/text", 200, "text/plain; charset=utf-8", "héllo 🌍"],
    ["/html", 200, "text/html; charset=utf-8", "<p>héllo</p>"],
    ["/json", 200, "application/json; charset=utf-8", '{"hello":"世界","ok":true}'],
    ["/missing", 404, "text/plain; charset=utf-8", "Not Found"],
    ["/state", 201, "text/plain; charset=utf-8", "created"],
    ["/set-var", 201, "text/plain; charset=utf-8", "Ada:42"],
    ["/unset-var", 200, "text/plain; charset=utf-8", "unset"],
  ])("%s", async (path, status, contentType, body) => {
    const response = await fetch(server.url + path);
    expect(response.status).toBe(status);
    expect(response.headers.get("content-type")).toBe(contentType);
    expect(await response.text()).toBe(body);
    if (path === "/set-var") expect(response.headers.get("x-vars")).toBe("kept");
    if (path === "/state") expect(response.headers.get("x-state")).toBe("new");
    if (path === "/missing") expect(response.headers.get("x-state")).toBe("kept");
  });
  test("body preserves octets, explicit media type, and optional absent media type", async () => {
    const response = await fetch(server.url + "/body");
    expect(response.headers.get("content-type")).toBe("application/octet-stream");
    expect(new Uint8Array(await response.arrayBuffer())).toEqual(new Uint8Array([0, 255, 65]));
    const untyped = await fetch(server.url + "/untyped-body");
    expect(untyped.headers.get("content-type")).toBeNull();
    expect(await untyped.text()).toBe("A");
    const echo = await fetch(server.url + "/echo", {
      method: "POST",
      body: new Uint8Array([255, 0, 65]),
    });
    expect(new Uint8Array(await echo.arrayBuffer())).toEqual(new Uint8Array([255, 0, 65]));
  });
  test("redirect defaults to 302 and retains headers", async () => {
    const response = await fetch(server.url + "/redirect", { redirect: "manual" });
    expect(response.status).toBe(302);
    expect(response.headers.get("location")).toBe("/next?q=1");
    expect(response.headers.get("x-state")).toBe("kept");
    expect(response.headers.get("content-type")).toBeNull();
    expect(await response.text()).toBe("");
  });
  test.each([301, 302, 303, 307, 308])("redirect permits %s", async (code) => {
    const response = await fetch(`${server.url}/redirect-code?code=${code}`, {
      redirect: "manual",
    });
    expect(response.status).toBe(code);
    expect(response.headers.get("location")).toBe("/next");
  });
  test.each([
    "/bad-location",
    "/bad-redirect",
    "/bad-header",
    "/bad-name",
    "/bad-status",
    "/invalid-json",
  ])("invalid response fails closed: %s", async (path) => {
    const response = await fetch(server.url + path, { redirect: "manual" });
    expect(response.status).toBe(500);
    expect(response.headers.get("x-injected")).toBeNull();
    expect(await response.text()).toBe("");
  });
  test("HEAD suppresses the helper body while retaining UTF-8 representation length", async () => {
    const response = await fetch(server.url + "/text", { method: "HEAD" });
    expect(response.headers.get("content-type")).toBe("text/plain; charset=utf-8");
    expect(response.headers.get("content-length")).toBe(String(Buffer.byteLength("héllo 🌍")));
    expect(await response.text()).toBe("");
  });
  test("variables are per request", async () => {
    await fetch(server.url + "/set-var");
    expect(await (await fetch(server.url + "/unset-var")).text()).toBe("unset");
  });
});
