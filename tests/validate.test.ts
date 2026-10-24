import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { parseManifest } from "../packages/bendo/src/manifest.ts";
import { build, start, type RunningServer } from "./harness.ts";

// BND-36: route schemas for params, query, headers, body and response.
const binary = build("tests/servers/validate.bend");
const unchecked = build("tests/servers/validate-unchecked.bend");
let server: RunningServer;
let production: RunningServer;
beforeAll(async () => {
  server = await start(binary);
  production = await start(binary, "127.0.0.1", { BENDO_ENV: "production" });
});
afterAll(async () => {
  await server?.[Symbol.asyncDispose]();
  await production?.[Symbol.asyncDispose]();
});

type Sent = { method?: string; headers?: Record<string, string>; body?: string };

async function send(path: string, init: Sent = {}, target = server): Promise<Response> {
  return fetch(target.url + path, { ...init, signal: AbortSignal.timeout(5000) });
}

function json(body: unknown): Sent {
  return {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
  };
}

type Issue = { path: (string | number)[]; code: string; message: string };

function issue(path: (string | number)[], code: string, message: string): Issue {
  return { path, code, message };
}

const MISSING = "missing required key";
const SCALAR = "value does not satisfy scalar checks";
const KIND = "expected schema scalar kind";

/** Waits for the production server to log a line containing `needle`. */
async function logged(needle: string): Promise<string | undefined> {
  const deadline = Date.now() + 2000;
  while (!production.stderr().includes(needle) && Date.now() < deadline) await Bun.sleep(10);
  return production
    .stderr()
    .split("\n")
    .find((l) => l.includes(needle));
}

/** The slot (first path part) of each error in a rejection body, in order. */
function errorSlots(body: unknown): unknown[] {
  if (typeof body !== "object" || body === null || !("errors" in body)) return [];
  const { errors } = body;
  if (!Array.isArray(errors)) return [];
  return errors.map((e: unknown) =>
    typeof e === "object" && e !== null && "path" in e && Array.isArray(e.path) ? e.path[0] : null,
  );
}

/** A rejection must be JSON naming its status and every failing path. */
async function rejected(response: Response, status: number, errors: Issue[]): Promise<void> {
  expect(response.status).toBe(status);
  expect(response.headers.get("content-type")).toBe("application/json; charset=utf-8");
  const body: unknown = await response.json();
  expect(body).toEqual({ error: expect.any(String), status, errors });
}

describe("params", () => {
  test("a valid param reaches the handler decoded", async () => {
    const response = await send("/items/42");
    expect(response.status).toBe(200);
    expect(await response.text()).toBe("id=42");
  });
  test("an invalid param is a 400 naming its path", async () => {
    await rejected(await send("/items/abc"), 400, [issue(["params", "id"], "type_mismatch", KIND)]);
    await rejected(await send("/items/0"), 400, [issue(["params", "id"], "constraint", SCALAR)]);
  });
});

describe("query", () => {
  test("a valid query is coerced, defaulted and stripped", async () => {
    const response = await send("/search?q=bend&tag=a&other=x&tag=b");
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ q: "bend", page: 1, tag: ["a", "b"] });
  });
  test("an invalid query lists every failing key", async () => {
    await rejected(await send("/search?page=0&tag=a&tag=b&tag=c&tag=d"), 400, [
      issue(["query", "q"], "constraint", MISSING),
      issue(["query", "page"], "constraint", SCALAR),
      issue(["query", "tag"], "constraint", "array length out of bounds"),
    ]);
    await rejected(await send("/search?q=x&page=two"), 400, [
      issue(["query", "page"], "type_mismatch", KIND),
    ]);
  });
});

describe("headers", () => {
  test("header names match case-insensitively and values are coerced", async () => {
    const response = await send("/whoami", {
      headers: { "X-Api-Key": "abcd1234efgh", "X-COUNT": "7" },
    });
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ "x-api-key": "abcd1234efgh", "x-count": 7 });
  });
  test("invalid headers are a 400 listing each header", async () => {
    await rejected(
      await send("/whoami", { headers: { "x-api-key": "Not-A-Key!", "x-count": "lots" } }),
      400,
      [
        issue(["headers", "x-api-key"], "constraint", SCALAR),
        issue(["headers", "x-count"], "type_mismatch", KIND),
      ],
    );
    await rejected(await send("/whoami"), 400, [
      issue(["headers", "x-api-key"], "constraint", MISSING),
    ]);
  });
});

describe("body", () => {
  test("a valid body arrives decoded, with defaults", async () => {
    const response = await send("/todos", json({ title: "Write docs", tags: ["a"] }));
    expect(response.status).toBe(201);
    expect(await response.json()).toEqual({
      id: 1,
      todo: { title: "Write docs", done: false, tags: ["a"] },
    });
  });
  test("any JSON media type is accepted", async () => {
    const response = await send("/todos", {
      method: "POST",
      headers: { "content-type": "Application/Vnd.Api+JSON; charset=utf-8" },
      body: JSON.stringify({ title: "x" }),
    });
    expect(response.status).toBe(201);
  });
  test("an invalid body is a 422 listing every failing path", async () => {
    await rejected(await send("/todos", json({ title: "", done: "yes", extra: 1 })), 422, [
      issue(["body", "extra"], "constraint", "object has an undeclared key"),
      issue(["body", "title"], "constraint", SCALAR),
      issue(["body", "done"], "type_mismatch", KIND),
    ]);
  });
  test("a JSON body is never coerced", async () => {
    await rejected(await send("/todos", json({ title: "x", done: "true" })), 422, [
      issue(["body", "done"], "type_mismatch", KIND),
    ]);
  });
  test("a non-JSON media type is a 415 and malformed JSON a 400", async () => {
    await rejected(
      await send("/todos", {
        method: "POST",
        headers: { "content-type": "text/plain" },
        body: "{}",
      }),
      415,
      [issue(["body"], "type_mismatch", "expected an application/json body")],
    );
    await rejected(await send("/todos", { method: "POST", body: "{}" }), 415, [
      issue(["body"], "type_mismatch", "expected an application/json body"),
    ]);
    await rejected(
      await send("/todos", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: "{",
      }),
      400,
      [issue(["body"], "type_mismatch", "body is not valid JSON")],
    );
  });
});

describe("every slot at once", () => {
  test("failures in every slot are listed together, slot by slot", async () => {
    await rejected(await send("/combo/abc?page=0", json({ done: 1 })), 400, [
      issue(["params", "id"], "type_mismatch", KIND),
      issue(["query", "q"], "constraint", MISSING),
      issue(["query", "page"], "constraint", SCALAR),
      issue(["headers", "x-api-key"], "constraint", MISSING),
      issue(["body", "title"], "constraint", MISSING),
      issue(["body", "done"], "type_mismatch", KIND),
    ]);
  });
  test("only the body failing is a 422; everything valid runs the handler", async () => {
    const headers = { "x-api-key": "abcd1234", "content-type": "application/json" };
    const bad = await send("/combo/1?q=a", { method: "POST", headers, body: "{}" });
    await rejected(bad, 422, [issue(["body", "title"], "constraint", MISSING)]);
    const good = await send("/combo/1?q=a", { method: "POST", headers, body: '{"title":"t"}' });
    expect(good.status).toBe(200);
    expect(await good.text()).toBe("combo");
  });
});

describe("response", () => {
  test("a conforming response is sent as is", async () => {
    const response = await send("/report");
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ count: 3 });
  });
  test("in development a violation is a 500 with the public error body", async () => {
    const asJson = await send("/report-bad", { headers: { accept: "application/json" } });
    expect(asJson.status).toBe(500);
    expect(await asJson.json()).toEqual({ error: "Internal Server Error", status: 500 });
    const asText = await send("/report-bad");
    expect(asText.status).toBe(500);
    expect(await asText.text()).toBe("Internal Server Error");
    const plain = await send("/report-text");
    expect(plain.status).toBe(500);
    expect(await plain.text()).not.toContain("count");
  });
  test("in production a violation is logged and the response sent unchanged", async () => {
    const response = await send("/report-bad", {}, production);
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ count: "three", secret: "internal" });
    expect(await logged("/report-bad")).toBe(
      'bendo: response schema violation: GET /report-bad [{"path":["body","secret"],"code":"constraint","message":"object has an undeclared key"},{"path":["body","count"],"code":"type_mismatch","message":"expected schema scalar kind"}]',
    );
    const good = await send("/report", {}, production);
    expect(good.status).toBe(200);
  });
});

describe("response after hooks", () => {
  test("a before_handle hook's own response is checked", async () => {
    const response = await send("/hooked/before");
    expect(response.status).toBe(500);
    expect(await response.text()).toBe("Internal Server Error");
  });
  test("a map_response hook that replaces a conforming response is checked", async () => {
    const response = await send("/hooked/map");
    expect(response.status).toBe(500);
    expect(await response.text()).not.toContain("mapped");
  });
  test("production logs the route pattern, never the captured values", async () => {
    const secret = "s3cr3t-reset-token-0123456789";
    const response = await send(`/leak/${secret}`, {}, production);
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ count: "three" });
    const line = await logged("/leak/");
    expect(line).toBe(
      'bendo: response schema violation: GET /leak/:token [{"path":["body","count"],"code":"type_mismatch","message":"expected schema scalar kind"}]',
    );
    expect(production.stderr()).not.toContain(secret);
  });
});

describe("streamed and upgraded responses", () => {
  const MARKER = "x-bendo-stream-internal";
  const KIND_ERROR =
    '[{"path":["body","count"],"code":"type_mismatch","message":"expected schema scalar kind"}]';

  test("a registered stream skips the response schema", async () => {
    const response = await send("/stream/report");
    expect(response.status).toBe(200);
    expect(response.headers.get("transfer-encoding")).toBe("chunked");
    expect(await response.text()).toBe("not json");
    expect(response.headers.has(MARKER)).toBe(false);
  });
  test("a marker header without a registration is checked as buffered", async () => {
    const response = await send("/forged");
    expect(response.status).toBe(500);
    expect(await response.text()).toBe("Internal Server Error");
    expect(response.headers.has(MARKER)).toBe(false);
    const sent = await send("/forged", {}, production);
    expect(sent.status).toBe(200);
    expect(await sent.json()).toEqual({ count: "three" });
    expect(sent.headers.has(MARKER)).toBe(false);
    expect(await logged("GET /forged ")).toBe(
      `bendo: response schema violation: GET /forged ${KIND_ERROR}`,
    );
  });
  test("a hook that replaces a registered stream with a forged marker is checked", async () => {
    const response = await send("/stream/forged");
    expect(response.status).toBe(500);
    expect(await response.text()).toBe("Internal Server Error");
    const sent = await send("/stream/forged", {}, production);
    expect(sent.status).toBe(200);
    expect(await sent.json()).toEqual({ count: "three" });
    expect(await logged("GET /stream/forged ")).toBe(
      `bendo: response schema violation: GET /stream/forged ${KIND_ERROR}`,
    );
  });
  test("a hook that replaces a registered stream with a buffered response is checked", async () => {
    const response = await send("/stream/mapped");
    expect(response.status).toBe(500);
    expect(await response.text()).not.toContain("mapped");
  });
  test("a WebSocket upgrade on a route with a response schema still opens", async () => {
    const opened = await new Promise<boolean>((resolve) => {
      const socket = new WebSocket(`${server.url.replace(/^http/, "ws")}/socket`);
      const timer = setTimeout(() => {
        socket.close();
        resolve(false);
      }, 5000);
      socket.addEventListener("open", () => {
        clearTimeout(timer);
        socket.close();
        resolve(true);
      });
      socket.addEventListener("error", () => {
        clearTimeout(timer);
        resolve(false);
      });
    });
    expect(opened).toBe(true);
  });
  test("a retained policy that replaces the marker cannot cancel a registered stream", async () => {
    // Security headers retain a policy that sets the marker; a later
    // map-response hook registers a real stream. Validation exempts the
    // stream, so finalization must keep its marker for transport to agree.
    for (const target of [server, production]) {
      const response = await send("/secured/stream", {}, target);
      expect(response.status).toBe(200);
      expect(response.headers.get("transfer-encoding")).toBe("chunked");
      expect(response.headers.get("x-frame-options")).toBe("SAMEORIGIN");
      expect(response.headers.has(MARKER)).toBe(false);
      expect(await response.text()).toBe("not json");
    }
  });
  test("a retained policy that sets the marker on a buffered response is checked", async () => {
    const response = await send("/secured/forged");
    expect(response.status).toBe(500);
    expect(await response.text()).toBe("Internal Server Error");
    expect(response.headers.get("x-frame-options")).toBe("SAMEORIGIN");
    expect(response.headers.has(MARKER)).toBe(false);
    const sent = await send("/secured/forged", {}, production);
    expect(sent.status).toBe(200);
    expect(await sent.json()).toEqual({ count: "three" });
    expect(sent.headers.has(MARKER)).toBe(false);
    expect(await logged("GET /secured/forged ")).toBe(
      `bendo: response schema violation: GET /secured/forged ${KIND_ERROR}`,
    );
  });
});

describe("error budget", () => {
  test("a request reports at most 100 errors across all its slots", async () => {
    // 60 missing query keys and 60 missing headers: 120 failures, 100 reported.
    const response = await send("/flood");
    expect(response.status).toBe(400);
    const body: unknown = await response.json();
    expect(body).toEqual({ error: "Bad Request", status: 400, errors: expect.any(Array) });
    const slots = errorSlots(body);
    expect(slots).toHaveLength(100);
    expect(slots.filter((s) => s === "query")).toHaveLength(60);
    expect(slots.filter((s) => s === "headers")).toHaveLength(40);
    expect(slots.indexOf("headers")).toBe(60);
  });
});

describe("manifest", () => {
  test("--bendo-routes prints every route's effective schemas", () => {
    const run = Bun.spawnSync([binary, "--bendo-routes"], {
      stdout: "pipe",
      stderr: "pipe",
      timeout: 20_000,
    });
    expect(run.stderr.toString()).toBe("");
    expect(run.exitCode).toBe(0);
    const manifest = parseManifest(run.stdout.toString());
    const slots = (path: string, method = "GET"): string[] => {
      const row = manifest.routes.find((r) => r.path === path && r.method === method);
      expect(row).toBeDefined();
      return Object.keys(row?.schemas ?? {}).sort();
    };
    expect(slots("/items/:id")).toEqual(["params"]);
    expect(slots("/todos", "POST")).toEqual(["body", "response"]);
    expect(slots("/report")).toEqual(["response"]);
    expect(slots("/plain")).toEqual([]);
    // A guard's schema reaches every member; a member's own schema wins.
    expect(slots("/guarded/a")).toEqual(["query"]);
    const guarded = (path: string) => manifest.routes.find((r) => r.path === path)?.schemas.query;
    expect(JSON.stringify(guarded("/guarded/a"))).toContain('"string"');
    expect(JSON.stringify(guarded("/guarded/b"))).toContain('"integer"');
    // A mounted sub-app keeps its schemas under the mount prefix.
    expect(slots("/api/thing/:n")).toEqual(["params"]);
  });
});

describe("scopes", () => {
  test("a guard's schemas apply to every member", async () => {
    const ok = await send("/guarded/a?token=abc");
    expect(ok.status).toBe(200);
    expect(await ok.json()).toEqual({ token: "abc" });
    await rejected(await send("/guarded/a"), 400, [
      issue(["query", "token"], "constraint", MISSING),
    ]);
  });
  test("a member's own schema replaces the guard's for that slot", async () => {
    await rejected(await send("/guarded/b?token=abc"), 400, [
      issue(["query", "token"], "type_mismatch", KIND),
    ]);
    const ok = await send("/guarded/b?token=12");
    expect(await ok.json()).toEqual({ token: 12 });
  });
  test("a mounted sub-app keeps its route schemas", async () => {
    const ok = await send("/api/thing/5");
    expect(await ok.text()).toBe("n=5");
    await rejected(await send("/api/thing/x"), 400, [
      issue(["params", "n"], "type_mismatch", KIND),
    ]);
  });
  test("a route without schemas sees no decoded values", async () => {
    expect(await (await send("/plain")).text()).toBe("none,none,none,none");
  });
});

describe("lifecycle", () => {
  test("validation runs after transform and before before_handle", async () => {
    const bad = await send("/ordered", json({ title: "" }));
    expect(bad.headers.get("x-stamp")).toBe("transform");
    await rejected(bad, 422, [issue(["body", "title"], "constraint", SCALAR)]);
    const good = await send("/ordered", json({ title: "t" }));
    expect(good.status).toBe(200);
    expect(good.headers.get("x-stamp")).toBe("transform");
    expect(await good.text()).toBe("before-handle:t");
  });
});

describe("prepared schemas", () => {
  // A wide pattern's table takes tens of milliseconds to build. It is built
  // once, with the route table, so a request costs about what a request
  // without the pattern costs. Compare medians rather than wall time.
  async function median(path: string, value: string): Promise<number> {
    const times: number[] = [];
    for (let i = 0; i < 15; i++) {
      const before = performance.now();
      const response = await send(path, {
        headers: { "x-wide": value, "x-wide-2": value, "x-wide-3": value },
      });
      expect(await response.text()).toBe(value);
      times.push(performance.now() - before);
    }
    times.sort((a, b) => a - b);
    return times[7] ?? 0;
  }
  test("a wide pattern adds no per-request table build", async () => {
    await median("/wide", "aaaa");
    const wide = await median("/wide", "aaaa");
    const narrow = await median("/narrow", "aaaa");
    expect(wide).toBeLessThan(narrow * 3 + 3);
    await rejected(
      await send("/wide", { headers: { "x-wide": "ab", "x-wide-2": "a", "x-wide-3": "b" } }),
      400,
      [
        issue(["headers", "x-wide"], "constraint", SCALAR),
        issue(["headers", "x-wide-3"], "constraint", SCALAR),
      ],
    );
  });
});

describe("plain entrypoints", () => {
  test("B.handle answers any schema route 500 and B.serve refuses to start", () => {
    const run = Bun.spawnSync([unchecked], {
      env: { ...process.env, PORT: "1" },
      stdout: "pipe",
      stderr: "pipe",
      timeout: 20_000,
    });
    expect(run.exitCode).toBe(1);
    const refusal =
      '500 {"error":"Internal Server Error","status":500,"errors":[{"path":[],"code":"invalid_schema","message":"route schemas need the validating entrypoints in src/validated.bend"}]}';
    // A route with only a response schema is refused too, before its handler
    // runs (the fixture's handler for it exits the process).
    expect(run.stdout.toString()).toBe(`handle ${refusal}\nresponse-only ${refusal}\n`);
    expect(run.stderr.toString()).toContain("serve it with the entrypoints in src/validated.bend");
  });
});
