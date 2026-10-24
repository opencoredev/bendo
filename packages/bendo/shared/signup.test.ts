// BND-58: the signup fixture's server route and its browser module run the
// same Bend schema. For each body, the compiled server's status and JSON text
// must equal what the shared `.mjs` computes from the same text.
import { afterAll, beforeAll, expect, test } from "bun:test";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { build, start, type RunningServer, SLOW_TEST_TIMEOUT_MS } from "../../../tests/harness.ts";
import { buildShared } from "../src/shared.ts";

const fixture = join(import.meta.dir, "fixtures/signup");
const out = mkdtempSync(join(tmpdir(), "bendo-shared-signup-"));
const [built] = await buildShared(join(fixture, "shared"), out);
if (built === undefined) throw new Error("no shared module");
const imported: unknown = await import(pathToFileURL(built.module).href);
const binary = build("packages/bendo/shared/fixtures/signup/main.bend");

function exported(name: string): (...args: unknown[]) => unknown {
  if (typeof imported !== "object" || imported === null) throw new Error("no module");
  const fn: unknown = Reflect.get(imported, name);
  if (typeof fn !== "function") throw new Error(`missing export ${name}`);
  return (...args) => fn(...args);
}
const check = exported("check");
const replyText = exported("reply_text");
const status = exported("status");

/** What the browser shows for a body: the shared module's status and reply. */
function browser(body: string): { status: unknown; text: unknown } {
  const checked = check(body);
  return { status: status(checked), text: replyText(checked) };
}

let server: RunningServer;
beforeAll(async () => {
  server = await start(binary);
});
afterAll(async () => {
  await server[Symbol.asyncDispose]();
  rmSync(out, { recursive: true, force: true });
});

const valid = {
  name: "Ada Lovelace",
  email: "ada@example.com",
  username: "ada_l",
  age: 36,
  plan: "pro",
};
const big = "a".repeat(64 * 1024);
const bodies: { name: string; body: string; status: number }[] = [
  { name: "a complete signup", body: JSON.stringify(valid), status: 201 },
  {
    name: "the default plan",
    body: JSON.stringify({ name: "Ada", email: "a@b.co", username: "ada" }),
    status: 201,
  },
  {
    name: "multibyte names",
    body: JSON.stringify({ ...valid, name: "Åda 😀 Lovelace" }),
    status: 201,
  },
  { name: "an empty object", body: "{}", status: 422 },
  {
    name: "every field wrong",
    body: JSON.stringify({
      name: "",
      email: "nope",
      username: "Ada!",
      age: 7,
      plan: "gold",
      extra: 1,
    }),
    status: 422,
  },
  { name: "age as text", body: JSON.stringify({ ...valid, age: "36" }), status: 422 },
  { name: "age with a fraction", body: JSON.stringify({ ...valid, age: 36.5 }), status: 422 },
  {
    name: "a repeated key",
    body: '{"name":"a","name":"b","email":"a@b.co","username":"ada"}',
    status: 422,
  },
  { name: "not JSON", body: "{oops", status: 422 },
  { name: "not an object", body: "[1,2]", status: 422 },
  { name: "a 64 KiB name", body: JSON.stringify({ ...valid, name: big }), status: 422 },
  { name: "a 64 KiB username", body: JSON.stringify({ ...valid, username: big }), status: 422 },
  {
    name: "64 KiB of unknown keys",
    body: JSON.stringify({ ...valid, junk: big, [big]: 1 }),
    status: 422,
  },
];

for (const vector of bodies)
  test(
    `server and browser agree on ${vector.name}`,
    async () => {
      const expected = browser(vector.body);
      expect(expected.status).toBe(vector.status);
      const response = await fetch(`${server.url}/api/signup`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: vector.body,
      });
      expect(response.status).toBe(vector.status);
      expect(response.headers.get("content-type")).toContain("application/json");
      expect(await response.text()).toBe(String(expected.text));
    },
    SLOW_TEST_TIMEOUT_MS,
  );

test("field errors carry the form's own messages", () => {
  const reply: unknown = JSON.parse(String(browser("{}").text));
  expect(reply).toEqual({
    ok: false,
    issues: [
      { field: "name", message: "Name is required." },
      { field: "email", message: "Email is required." },
      { field: "username", message: "Username is required." },
    ],
  });
});
