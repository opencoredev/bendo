import { describe, expect, test } from "bun:test";
import { build, start } from "./harness.ts";

describe("public B entrypoint", () => {
  const driver = build("tests/handle-driver.bend");
  test("native B.handle checks status, headers, params, env, body, misses and HEAD without networking", () => {
    const result = Bun.spawnSync([driver], { stdout: "pipe", stderr: "pipe", timeout: 20_000 });
    expect(result.exitCode).toBe(0);
    const lines = result.stdout.toString().trim().split("\n");
    expect(lines.filter((line) => line.startsWith("PASS "))).toHaveLength(29);
    const manifest: unknown = JSON.parse(lines.at(-1) ?? "");
    expect(manifest).toEqual({
      bendo: 1,
      routes: [
        { method: "GET", path: "/todos/:id{int}", params: ["id"] },
        { method: "GET", path: "/broken", params: [] },
        { method: "X-TOKEN", path: "/escaped/%22", params: [] },
      ],
    });
  }, 30000);

  const binary = build("examples/hello/main.bend");

  test("compiled hello emits a versioned manifest and exits before listening", async () => {
    // An already occupied listening port must not affect manifest export.
    await using server = await start(binary);
    const result = Bun.spawnSync([binary, "--bendo-routes"], {
      env: { ...process.env, PORT: new URL(server.url).port },
      stdout: "pipe",
      stderr: "pipe",
      timeout: 5000,
    });
    expect(result.exitCode).toBe(0);
    expect(result.stderr.toString()).toBe("");
    const manifest: unknown = JSON.parse(result.stdout.toString());
    expect(manifest).toEqual({ bendo: 1, routes: [{ method: "GET", path: "/*", params: ["*"] }] });
  });

  test("new serve API preserves GET and suppresses HEAD body with GET content length", async () => {
    await using server = await start(binary);
    const get = await fetch(`${server.url}/todos/42`);
    const text = await get.text();
    const head = await fetch(`${server.url}/todos/42`, { method: "HEAD" });
    expect(head.status).toBe(200);
    expect(head.headers.get("content-length")).toBe(String(Buffer.byteLength(text)));
    expect(await head.text()).toBe("");
    const post = await fetch(`${server.url}/todos/42`, { method: "POST" });
    expect(post.status).toBe(405);
    expect(post.headers.get("allow")).toBe("GET, HEAD");
  });

  const echo = build("tests/servers/handle-config.bend");
  test("config binds a custom host, honors PORT and rejects bodies above its limit", async () => {
    await using server = await start(echo, "127.0.0.2");
    const accepted = await fetch(server.url, { method: "POST", body: "abc" });
    expect(accepted.status).toBe(200);
    expect(await accepted.text()).toBe("abc");
    const rejected = await fetch(server.url, { method: "POST", body: "abcd" });
    expect(rejected.status).toBe(413);
  }, 30000);
});
