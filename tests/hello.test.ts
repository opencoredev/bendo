import { describe, expect, test } from "bun:test";
import { build, start } from "./harness.ts";

describe("examples/hello", () => {
  const binary = build("examples/hello/main.bend");

  test("answers with the requested path", async () => {
    await using server = await start(binary);
    const res = await fetch(`${server.url}/todos/42`);
    expect(res.status).toBe(200);
    expect(res.headers.get("content-type")).toBe("text/plain; charset=utf-8");
    expect(await res.text()).toBe("Hello from Bendo! You asked for /todos/42");
  });
});
