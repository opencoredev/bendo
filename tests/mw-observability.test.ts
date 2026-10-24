import { afterAll, beforeAll, expect, test } from "bun:test";
import { build } from "./harness.ts";

const binary = build("tests/servers/mw-observability.bend");
const failures = build("tests/observability-failures.bend");
const logs: string[] = [];
let url = "";
let proc: Bun.Subprocess<"ignore", "ignore", "pipe"> | undefined;
let captured: Promise<void> = Promise.resolve();

/** Starts the server on a random port and captures stderr lines. Resolves false if it exits first. */
async function launch(): Promise<boolean> {
  const port = 20000 + Math.floor(Math.random() * 20000);
  url = `http://127.0.0.1:${port}`;
  logs.length = 0;
  const child = Bun.spawn([binary], {
    env: { ...process.env, PORT: String(port) },
    stdout: "ignore",
    stderr: "pipe",
  });
  proc = child;
  let pending = "";
  captured = (async () => {
    const decoder = new TextDecoder();
    for await (const chunk of child.stderr) {
      pending += decoder.decode(chunk, { stream: true });
      const lines = pending.split("\n");
      pending = lines.pop() ?? "";
      logs.push(...lines);
    }
  })();
  const deadline = Date.now() + 20_000;
  while (Date.now() < deadline) {
    if (child.exitCode !== null) {
      await captured;
      return false;
    }
    if (
      await fetch(url).then(
        () => true,
        () => false,
      )
    )
      return true;
    await Bun.sleep(50);
  }
  throw new Error("Observability server did not start");
}

// A random port can already be taken; a server that exits before answering is retried on a new one.
beforeAll(async () => {
  const failures: string[] = [];
  for (let attempt = 0; attempt < 3; attempt++) {
    if (await launch()) return;
    failures.push(`${url}: ${logs.join("\n")}`);
  }
  throw new Error(`Server exited before answering:\n${failures.join("\n")}`);
}, 65_000);
afterAll(async () => {
  proc?.kill();
  await proc?.exited;
  await captured;
});

async function lineFor(path: string): Promise<string> {
  const deadline = Date.now() + 2000;
  while (Date.now() < deadline) {
    const line = logs.find((line) => line.startsWith(`GET ${path} `));
    if (line) return line;
    await Bun.sleep(10);
  }
  throw new Error(`No log for ${path}: ${logs.join("\n")}`);
}

test("logger writes the stable stderr format without query strings and logs validated status", async () => {
  const res = await fetch(url + "/missing?secret=hidden");
  expect(res.status).toBe(404);
  expect(await lineFor("/missing")).toMatch(/^GET \/missing 404 \d+ms$/);
  expect(logs.join("\n")).not.toContain("secret");
  expect((await fetch(url + "/broken")).status).toBe(500);
  expect(await lineFor("/broken")).toMatch(/^GET \/broken 500 \d+ms$/);
});

test("request ID reuses safe incoming IDs and is readable by a typed handler", async () => {
  const res = await fetch(url + "/id", { headers: { "X-Request-Id": "client.A_9-1" } });
  expect(res.headers.get("x-request-id")).toBe("client.A_9-1");
  expect(await res.text()).toBe("client.A_9-1");
  expect(res.headers.get("x-custom")).toBe("yes");
  expect(await lineFor("/id")).toMatch(/^GET \/id 200 \d+ms id=client\.A_9-1$/);
});

test.each([undefined, "", "unsafe value", "bad;id", "x".repeat(201)])(
  "request ID generates 16 random hex bytes for missing/invalid input: %s",
  async (id) => {
    const res = await fetch(url + "/id", {
      headers: id === undefined ? {} : { "x-request-id": id },
    });
    const generated = res.headers.get("x-request-id") ?? "";
    expect(generated ?? "").toMatch(/^[0-9a-f]{32}$/);
    expect(await res.text()).toBe(generated);
  },
);

test("request IDs accept the 200-character boundary and generated values differ", async () => {
  const id = "a".repeat(200);
  const res = await fetch(url + "/id", { headers: { "x-request-id": id } });
  expect(await res.text()).toBe(id);
  const a = await fetch(url + "/id");
  const b = await fetch(url + "/id");
  expect(a.headers.get("x-request-id")).not.toBe(b.headers.get("x-request-id"));
});

test("logger includes the response ID with request-ID middleware outside it too", async () => {
  const res = await fetch(url + "/reverse", { headers: { "x-request-id": "reverse" } });
  expect(await res.text()).toBe("reverse");
  expect(await lineFor("/reverse")).toMatch(/^GET \/reverse 200 \d+ms id=reverse$/);
});

test("Server-Timing includes total, ordered named marks and escaped names through nested middleware", async () => {
  const res = await fetch(url + "/json");
  expect(res.headers.get("server-timing")).toMatch(
    /^total;dur=\d+, mark_db;dur=4, mark_cache_59__32_hit_13__10_;dur=2$/,
  );
});

test("powered-by is opt-in and uses the configured name", async () => {
  expect((await fetch(url)).headers.get("x-powered-by")).toBeNull();
  expect((await fetch(url + "/powered")).headers.get("x-powered-by")).toBe("Bendo");
});

const compact = '{"a":[1,true],"b":"é"}';
const pretty = '{\n  "a": [\n    1,\n    true\n  ],\n  "b": "é"\n}';
test("pretty JSON is byte-exact on key presence and removes stale validators", async () => {
  const plain = await fetch(url + "/json");
  expect(await plain.text()).toBe(compact);
  expect(plain.headers.get("etag")).toBe("old");
  for (const query of ["?pretty", "?pretty=false", "?%70retty="]) {
    const res = await fetch(url + "/json" + query);
    expect(await res.text()).toBe(pretty);
    expect(res.headers.get("content-length")).toBe(String(Buffer.byteLength(pretty)));
    expect(res.headers.get("etag")).toBeNull();
  }
  const head = await fetch(url + "/json?pretty", { method: "HEAD" });
  expect(await head.text()).toBe("");
  expect(head.headers.get("content-length")).toBe(String(Buffer.byteLength(pretty)));
});

test.each([
  ["/invalid", "{bad}"],
  ["/text", '{"a":1}'],
  ["/partial", '{"a":1}'],
  ["/encoded", '{"a":1}'],
])("pretty JSON preserves ineligible responses: %s", async (path, body) => {
  const res = await fetch(url + path + "?pretty");
  expect(await res.text()).toBe(body);
});

test("entropy and timing collector failures are bounded and fail closed", () => {
  const result = Bun.spawnSync(["timeout", "--foreground", "10s", failures], {
    stdout: "pipe",
    stderr: "pipe",
  });
  expect(result.exitCode).toBe(0);
  expect(result.stdout.toString()).toBe(
    "PASS mixed-case explicit ID wins without duplicates\n" +
      "PASS entropy failure returns empty 500\n" +
      "PASS inactive timing returns false\n" +
      "PASS late timing write returns false\n" +
      "PASS collector read failure returns empty 500\n",
  );
});

test("request hooks preserve IDs and timing through method/path rewrites and route captures", async () => {
  const res = await fetch(url + "/hook-id", {
    method: "POST",
    headers: { "x-request-id": "hook-42" },
  });
  expect(res.status).toBe(202);
  expect(await res.text()).toBe("hook-42:42");
  expect(res.headers.get("x-request-id")).toBe("hook-42");
  expect(res.headers.get("server-timing")).toMatch(/^total;dur=\d+$/);
  const deadline = Date.now() + 2000;
  while (
    Date.now() < deadline &&
    !logs.some((line) => /^GET \/hook-target\/42 202 \d+ms id=hook-42$/.test(line))
  ) {
    await Bun.sleep(10);
  }
  expect(logs.some((line) => /^GET \/hook-target\/42 202 \d+ms id=hook-42$/.test(line))).toBe(true);
});

test("timing started in on_request retains handler marks after routing and rewriting", async () => {
  const res = await fetch(url + "/hook-json?pretty", {
    headers: { "x-request-id": "hook-json" },
  });
  expect(await res.text()).toBe(pretty);
  expect(res.headers.get("x-request-id")).toBe("hook-json");
  expect(res.headers.get("server-timing")).toMatch(
    /^total;dur=\d+, mark_db;dur=4, mark_cache_59__32_hit_13__10_;dur=2$/,
  );
});

test.each([
  ["/hook-missing", "GET", 503, "recovered"],
  ["/hook-method", "POST", 503, "recovered"],
  ["/hook-handler-error", "GET", 503, "recovered"],
  ["/hook-map", "GET", 201, "mapped"],
  ["/hook-after", "GET", 202, "after"],
  ["/hook-invalid", "GET", 500, ""],
  ["/hook-invalid-map", "GET", 500, ""],
  ["/hook-invalid-recovery", "GET", 500, ""],
])(
  "final observability survives response replacement: %s %s",
  async (path, method, status, body) => {
    const res = await fetch(url + path, { method, headers: { "x-request-id": "final-42" } });
    expect(res.status).toBe(status);
    expect(await res.text()).toBe(body);
    expect(res.headers.get("x-request-id")).toBe("final-42");
    expect(res.headers.get("server-timing")).toMatch(/^total;dur=\d+$/);
  },
);

test("explicit final response headers take precedence without duplicates", async () => {
  const res = await fetch(url + "/hook-explicit", { headers: { "x-request-id": "incoming" } });
  expect(res.status).toBe(200);
  expect(res.headers.get("x-request-id")).toBe("explicit");
  expect(res.headers.get("server-timing")).toBe("custom;dur=7");
});

test.each(["/hook-outgoing", "/hook-outgoing-handler"])(
  "outgoing IDs use incoming validation and case-insensitive precedence: %s",
  async (path) => {
    for (const outgoing of [
      "explicit.A_9-1",
      "a".repeat(200),
      "a".repeat(201),
      "unsafe value",
      'unsafe"value',
      "é",
      "",
    ]) {
      const res = await fetch(url + path, {
        headers: {
          "x-request-id": "retained-42",
          "x-outgoing-id": outgoing === "é" ? "non-ascii" : outgoing,
        },
      });
      expect(res.status).toBe(200);
      const expected =
        outgoing === "explicit.A_9-1" || outgoing === "a".repeat(200) ? outgoing : "retained-42";
      // Fetch combines duplicate fields with commas, so equality also checks uniqueness.
      expect(res.headers.get("x-request-id")).toBe(expected);
    }
  },
);

test.each(["a".repeat(201), "unsafe value", 'unsafe"value', "é", ""])(
  "invalid explicit ID is dropped when no middleware assigned an ID: %s",
  async (outgoing) => {
    const res = await fetch(url + "/outgoing", {
      headers: { "x-outgoing-id": outgoing === "é" ? "non-ascii" : outgoing },
    });
    expect(res.status).toBe(200);
    expect(res.headers.get("x-request-id")).toBeNull();
  },
);

test("echoing an unsafe incoming ID cannot bypass generated request-ID validation", async () => {
  const res = await fetch(url + "/id-echo", { headers: { "x-request-id": "unsafe value" } });
  const retained = await res.text();
  expect(retained).toMatch(/^[0-9a-f]{32}$/);
  expect(res.headers.get("x-request-id")).toBe(retained);
});

for (const path of ["/timeout-outer", "/timeout-inner"]) {
  test(`logger emits exactly once with the wire status for ${path}`, async () => {
    const res = await fetch(url + path);
    expect(res.status).toBe(504);
    await res.text();
    const line = await lineFor(path);
    expect(line).toMatch(new RegExp(`^GET ${path} ${res.status} \\d+ms$`));
    const duration = / (\d+)ms$/.exec(line);
    expect(Number(duration?.[1])).toBeGreaterThanOrEqual(30);
    const deadline = Date.now() + 3000;
    while (!logs.includes(`late-handler-finished ${path}`) && Date.now() < deadline) {
      await Bun.sleep(10);
    }
    expect(logs).toContain(`late-handler-finished ${path}`);
    // A further request lets the losing onion resume through its logger.
    await (await fetch(url + "/")).text();
    expect(logs.filter((entry) => entry.startsWith(`GET ${path} `))).toEqual([line]);
  });
}

test("completed logger layers keep their own onion duration", async () => {
  const res = await fetch(url + "/duration");
  expect(res.status).toBe(200);
  await res.text();
  const deadline = Date.now() + 3000;
  let entries: string[] = [];
  while (Date.now() < deadline) {
    entries = logs.filter((line) => line.startsWith("GET /duration "));
    if (entries.length === 2) break;
    await Bun.sleep(10);
  }
  expect(entries).toHaveLength(2);
  const durations = entries.map((line) => {
    expect(line).toMatch(/^GET \/duration 200 \d+ms$/);
    return Number(/ (\d+)ms$/.exec(line)?.[1]);
  });
  expect(Math.max(...durations) - Math.min(...durations)).toBeGreaterThanOrEqual(100);
});
