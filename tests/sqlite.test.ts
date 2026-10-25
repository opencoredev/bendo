import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { build, compile, start, type RunningServer } from "./harness.ts";

// The SQLite effect (BND-38). tests/servers/sqlite.bend does CRUD over HTTP;
// tests/fixtures/sqlite/parity.bend runs the same operations in the native
// and JS builds so their output can be compared line by line.
const binary = build("tests/servers/sqlite.bend");
const parityNative = compile("tests/fixtures/sqlite/parity.bend", "native");
const parityJs = compile("tests/fixtures/sqlite/parity.bend", "js");

const scratch = mkdtempSync(join(tmpdir(), "bendo-sqlite-"));

let server: RunningServer;
beforeAll(async () => {
  server = await start(binary, "127.0.0.1", { BENDO_SQLITE_DB: join(scratch, "app.db") });
});
afterAll(async () => {
  await server[Symbol.asyncDispose]();
  rmSync(scratch, { recursive: true, force: true });
});

type Reply = { status: number; body: unknown };

async function call(method: string, path: string, query: Record<string, string> = {}): Promise<Reply> {
  const url = new URL(path, server.url);
  for (const [key, value] of Object.entries(query)) url.searchParams.set(key, value);
  const res = await fetch(url, { method });
  const text = await res.text();
  const type = res.headers.get("content-type") ?? "";
  const body: unknown = type.includes("json") ? JSON.parse(text) : text;
  return { status: res.status, body };
}

describe("CRUD through prepared statements in a compiled server", () => {
  test("create, read, update, list and delete", async () => {
    const ann = await call("POST", "/users", { name: "ann", email: "ann@example.com" });
    expect(ann).toEqual({ status: 200, body: { changes: 1, rowid: 1 } });
    const bob = await call("POST", "/users", { name: "bob" });
    expect(bob).toEqual({ status: 200, body: { changes: 1, rowid: 2 } });

    expect(await call("GET", "/users/1")).toEqual({
      status: 200,
      body: { id: 1, name: "ann", email: "ann@example.com" },
    });
    expect(await call("GET", "/users/2")).toEqual({
      status: 200,
      body: { id: 2, name: "bob", email: null },
    });
    expect((await call("GET", "/users/99")).status).toBe(404);

    expect(await call("PUT", "/users/2", { name: "robert" })).toEqual({
      status: 200,
      body: { changes: 1, rowid: 2 },
    });
    expect((await call("PUT", "/users/99", { name: "nobody" })).status).toBe(404);

    expect((await call("GET", "/users")).body).toEqual([
      { id: 1, name: "ann", email: "ann@example.com" },
      { id: 2, name: "robert", email: null },
    ]);
    expect((await call("GET", "/search", { name: "robert" })).body).toEqual([{ id: 2, name: "robert" }]);

    expect((await call("DELETE", "/users/1")).body).toEqual({ changes: 1, rowid: 2 });
    expect((await call("DELETE", "/users/1")).status).toBe(404);
    expect((await call("GET", "/users")).body).toEqual([{ id: 2, name: "robert", email: null }]);
  });

  test("a constraint violation is a typed error with SQLite's extended code", async () => {
    expect((await call("POST", "/users", { name: "a", email: "same@example.com" })).status).toBe(200);
    expect(await call("POST", "/users", { name: "b", email: "same@example.com" })).toEqual({
      status: 409,
      body: { code: 2067, message: "UNIQUE constraint failed: users.email" },
    });
  });

  test("a row that does not match its schema is a typed error naming the row", async () => {
    const res = await call("GET", "/mismatch");
    expect(res).toEqual({
      status: 500,
      body: {
        row: 0,
        errors: [{ path: ["name"], code: "type_mismatch", message: "expected schema scalar kind" }],
      },
    });
  });
});

describe("bound parameters", () => {
  test("SQL injection through a bound parameter is stored and returned literally", async () => {
    const attacks = ["'; DROP TABLE users; --", "1 OR 1=1", "x' OR '1'='1", 'a"; DELETE FROM users; --'];
    for (const name of attacks) {
      const created = await call("POST", "/users", { name });
      expect(created.status).toBe(200);
      const found = await call("GET", "/search", { name });
      expect(found.status).toBe(200);
      expect(found.body).toEqual([{ id: expect.any(Number), name }]);
    }
    // The table survives and holds every attack as a plain value.
    const all = await call("GET", "/users");
    expect(all.status).toBe(200);
    const names = Array.isArray(all.body) ? all.body.map((row: { name: string }) => row.name) : [];
    for (const name of attacks) expect(names).toContain(name);
    // "1 OR 1=1" as text matches no integer id; as an integer it is refused.
    expect((await call("GET", "/find-text", { id: "1 OR 1=1" })).body).toEqual([]);
    expect(await call("GET", "/find-integer", { id: "1 OR 1=1" })).toEqual({
      status: 400,
      body: {
        code: 20,
        message: "parameter 1: an integer must be canonical decimal text in the signed 64-bit range",
      },
    });
  });

  test("NULL, blobs, reals and 64-bit integers round trip exactly", async () => {
    const cases: [string, string, string, unknown][] = [
      ["null", "null", "", null],
      ["blob", "blob", "00ff3b5c0a", "AP87XAo="],
      ["empty-blob", "blob", "", ""],
      ["max", "int", "9223372036854775807", 9223372036854775807n],
      ["min", "int", "-9223372036854775808", -9223372036854775808n],
      ["real", "real", "0.1", 0.1],
      ["text", "text", "héllo 🎉 ; \\ '", "héllo 🎉 ; \\ '"],
    ];
    for (const [key, kind, value] of cases)
      expect((await call("POST", "/kv", { key, kind, value })).status).toBe(200);
    for (const [key, kind, , expected] of cases) {
      const res = await fetch(new URL(`/kv/${key}`, server.url));
      const text = await res.text();
      // JSON.parse would round a 64-bit integer, so the exact digits are read
      // from the text.
      if (typeof expected === "bigint") {
        expect(text).toBe(`{"key":"${key}","type":"integer","v":${expected}}`);
        continue;
      }
      const type = kind === "int" ? "integer" : kind === "null" ? "null" : kind;
      expect(JSON.parse(text)).toEqual({ key, type, v: expected });
    }
  });
});

describe("transactions", () => {
  async function balances(): Promise<unknown> {
    return (await call("GET", "/accounts")).body;
  }

  test("commit, and rollback when the body fails, aborts or breaks a constraint", async () => {
    const start = [
      { name: "alice", balance: 100 },
      { name: "bob", balance: 0 },
    ];
    expect(await balances()).toEqual(start);
    expect(await call("POST", "/transfer", { from: "alice", to: "bob", amount: "30" })).toEqual({
      status: 200,
      body: "ok",
    });
    const moved = [
      { name: "alice", balance: 70 },
      { name: "bob", balance: 30 },
    ];
    expect(await balances()).toEqual(moved);

    // Each of these debits alice first, then fails; the debit is rolled back.
    expect(await call("POST", "/transfer", { from: "alice", to: "bob", amount: "30", fail: "abort" })).toEqual(
      { status: 422, body: "transfer aborted" },
    );
    expect(await balances()).toEqual(moved);
    expect(
      await call("POST", "/transfer", { from: "alice", to: "bob", amount: "30", fail: "constraint" }),
    ).toEqual({ status: 409, body: { code: 1555, message: "UNIQUE constraint failed: accounts.name" } });
    expect(await balances()).toEqual(moved);
    expect(await call("POST", "/transfer", { from: "alice", to: "bob", amount: "1000" })).toEqual({
      status: 409,
      body: { code: 275, message: "CHECK constraint failed: balance >= 0" },
    });
    expect(await balances()).toEqual(moved);
  });

  test("a statement from another request waits for an open transaction and sees its commit", async () => {
    const before = await balances();
    const bob = Array.isArray(before) ? before.find((row: { name: string }) => row.name === "bob") : undefined;
    const slow = call("POST", "/slow", { ms: "600" });
    await Bun.sleep(150);
    const began = performance.now();
    const during = await balances();
    const waited = performance.now() - began;
    expect((await slow).status).toBe(200);
    // The read could not run inside the open transaction, so it waited for
    // the commit and saw the committed balance.
    expect(waited).toBeGreaterThan(250);
    expect(during).toContainEqual({ name: "bob", balance: (bob?.balance ?? 0) + 1000 });
  });
});

describe("workers", () => {
  test("worker processes each open their own connection and share the file", async () => {
    const db = join(scratch, "workers.db");
    const many = await start(binary, "127.0.0.1", { BENDO_SQLITE_DB: db, BENDO_WORKERS: "3" });
    try {
      const writes = await Promise.all(
        Array.from({ length: 30 }, (_, i) =>
          fetch(new URL(`/users?name=w${i}`, many.url), { method: "POST" }).then((res) => res.status),
        ),
      );
      expect(writes).toEqual(Array.from({ length: 30 }, () => 200));
      const rows = await fetch(new URL("/users", many.url)).then((res) => res.json());
      expect(Array.isArray(rows) ? rows.length : 0).toBe(30);
    } finally {
      await many[Symbol.asyncDispose]();
    }
  });
});

describe("the JS twin", () => {
  function runParity(file: string, js: boolean, env: Record<string, string> = {}, arg?: string): string {
    const dir = mkdtempSync(join(scratch, js ? "js-" : "native-"));
    const command = js ? [process.execPath, file, arg ?? dir] : [file, arg ?? dir];
    const result = Bun.spawnSync(command, { env: { ...process.env, ...env }, timeout: 60_000 });
    if (result.exitCode !== 0)
      throw new Error(`parity exited ${result.exitCode}: ${result.stdout}${result.stderr}`);
    return result.stdout.toString();
  }

  test("gives the native build's output for every operation", () => {
    const native = runParity(parityNative, false);
    const js = runParity(parityJs, true);
    expect(js).toBe(native);
    const lines = native.trim().split("\n");
    expect(lines.length).toBeGreaterThan(60);
    const expected = [
      "select: rows id,i,r,s,b,typeof(b) [i:1|i:9223372036854775807|r:0.1|t:héllo 🎉 a;b\\c'd|b:00ff3b5c0a|t:blob] [i:2|i:-9223372036854775808|r:-1.5e+300|t:|b:|t:blob] [i:3|null|null|null|null|t:null] changes 0",
      "reals: rows 2.0,1e308 * 10,-0.0,0.1,123456789012345680000.0,1e21,5e-7,1e-7,0.000001,1234.5678,3e-310,-1e21,1.0 / 3,100.0 [r:2|r:Infinity|r:0|r:0.1|r:123456789012345680000|r:1e+21|r:5e-7|r:1e-7|r:0.000001|r:1234.5678|r:3e-310|r:-1e+21|r:0.3333333333333333|r:100] changes 0",
      "not json: not json 0 big",
      "inject read: rows s [t:'; DROP TABLE t; --] changes 0",
      "table survives: rows count(*) [i:4] changes 0",
      "unique second: error 2067 UNIQUE constraint failed: u.name",
      "named missing: error 25 parameter :b is not bound",
      "two statements: error 21 bendo sqlite: one statement per call; run scripts with Sql.exec",
      "sql begin: error 21 bendo sqlite: a statement may not begin a transaction; use Sql.begin",
      "tx abort: abort stop",
      "after tx: rows name [t:kept] [t:x] changes 0",
      "stale tx: error 21 bendo sqlite: no open transaction for this handle",
      "finalized use: error 21 bendo sqlite: the statement is finalized or belongs to another connection",
      "three rows: error 18 bendo sqlite: the query returned more than 2 rows",
      "closed use: error 21 bendo sqlite: the connection is closed",
      "read-only write: error 8 attempt to write a readonly database",
    ];
    for (const line of expected) expect(lines).toContain(line);
  });

  test("both builds name the missing library when libsqlite3 is not installed", () => {
    if (process.platform !== "linux") return;
    const shim = join(mkdtempSync(join(scratch, "shim-")), "no_sqlite.so");
    const source = resolve(import.meta.dir, "fixtures/sqlite/no_sqlite.c");
    const cc = Bun.spawnSync(["cc", "-shared", "-fPIC", "-O1", "-o", shim, source, "-ldl"]);
    if (cc.exitCode !== 0) throw new Error(`no_sqlite.c did not build: ${cc.stderr.toString()}`);
    const message =
      "open: error 14 bendo sqlite: libsqlite3 was not found (tried libsqlite3.so.0, libsqlite3.so); install it, for example with apt-get install libsqlite3-0\n";
    expect(runParity(parityNative, false, { LD_PRELOAD: shim }, "--open")).toBe(message);
    expect(runParity(parityJs, true, { LD_PRELOAD: shim }, "--open")).toBe(message);
    expect(runParity(parityNative, false, {}, "--open")).toBe("open: opened\n");
  });
});

describe("opt-in", () => {
  // Bend splices an effect's C and JS only into programs that import it, so an
  // app pays for SQLite exactly when its import graph reaches the module.
  function importGraph(entry: string): Set<string> {
    const seen = new Set<string>();
    const visit = (file: string): void => {
      if (seen.has(file)) return;
      seen.add(file);
      for (const [, target] of readFileSync(file, "utf8").matchAll(/^import (\S+\.bend) as \w+/gm))
        if (target !== undefined) visit(resolve(dirname(file), target));
    };
    visit(resolve(import.meta.dir, "..", entry));
    return seen;
  }

  test("main.bend and the serving modules do not reach the SQLite effect", () => {
    const effect = resolve(import.meta.dir, "../src/effects/sqlite.bend");
    for (const entry of ["src/main.bend", "src/validated.bend", "src/serve-schemas.bend"])
      expect(importGraph(entry).has(effect)).toBe(false);
    expect(importGraph("src/sqlite.bend").has(effect)).toBe(true);
  });
});
