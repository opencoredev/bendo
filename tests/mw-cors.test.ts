// BND-40: CORS, secure headers, method override and trailing-slash built-ins,
// tested against the compiled tests/servers/mw-cors.bend.
//
// Manual browser check (credentialed CORS needs a real browser to prove the
// cookie travels and that a denied origin cannot read the answer):
//   1. Build the fixture: bend tests/servers/mw-cors.bend -o /tmp/mw-cors
//      and run it with PORT=18440 /tmp/mw-cors (it binds 127.0.0.1).
//   2. Seed a cookie for 127.0.0.1: open http://127.0.0.1:18440/ and run
//      document.cookie = "bnd40=credential-present; path=/".
//   3. Serve any page from http://127.0.0.1:18441 and run, from its console:
//        await (await fetch("http://127.0.0.1:18440/browser", { credentials: "include" })).text()
//        await (await fetch("http://127.0.0.1:18440/browser", { method: "PUT",
//          credentials: "include", headers: { "X-Bnd40": "browser" } })).text()
//      Both must answer "browser GET cookie=credential-present" or
//      "browser PUT cookie=credential-present". The second needs a preflight
//      that allows x-bnd40 with credentials.
//   4. Repeat from a page on http://127.0.0.1:18442. Both fetches must reject
//      with "TypeError: Failed to fetch": that origin is not listed.
import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { connect } from "node:net";
import { build, start, type RunningServer } from "./harness.ts";

const binary = build("tests/servers/mw-cors.bend");

let server: RunningServer;
beforeAll(async () => {
  server = await start(binary);
});
afterAll(async () => {
  await server[Symbol.asyncDispose]();
});

function request(
  path: string,
  init: { method?: string; headers?: Record<string, string>; body?: string | FormData } = {},
): Promise<Response> {
  return fetch(server.url + path, { redirect: "manual", ...init });
}

type Raw = { status: number; fields: [string, string][]; body: string };

// A raw request, so a test can repeat fields and send targets fetch rewrites.
function raw(target: string, fields: [string, string][], method = "GET", body = ""): Promise<Raw> {
  const head = [
    ...fields,
    ["content-length", String(Buffer.byteLength(body))],
    ["connection", "close"],
  ]
    .map(([name, value]) => `${name}: ${value}\r\n`)
    .join("");
  return new Promise((resolve, reject) => {
    const url = new URL(server.url);
    const socket = connect({ host: url.hostname, port: Number(url.port) });
    const chunks: Buffer[] = [];
    socket.setTimeout(5000, () => socket.destroy(new Error("raw socket timed out")));
    socket.on("connect", () =>
      socket.end(`${method} ${target} HTTP/1.1\r\nhost: ${url.host}\r\n${head}\r\n${body}`),
    );
    socket.on("data", (chunk: Buffer) => chunks.push(chunk));
    socket.on("error", reject);
    socket.on("end", () => {
      const text = Buffer.concat(chunks).toString("latin1");
      const split = text.indexOf("\r\n\r\n");
      const lines = text.slice(0, split).split("\r\n");
      const status = /^HTTP\/1\.1 (\d{3})/.exec(lines[0] ?? "");
      if (status?.[1] === undefined) {
        reject(new Error(`No status line in ${JSON.stringify(text.slice(0, 80))}`));
        return;
      }
      const parsed: [string, string][] = [];
      for (const line of lines.slice(1)) {
        const colon = line.indexOf(":");
        parsed.push([line.slice(0, colon).toLowerCase(), line.slice(colon + 1).trim()]);
      }
      resolve({ status: Number(status[1]), fields: parsed, body: text.slice(split + 4) });
    });
  });
}

function values(r: Raw, name: string): string[] {
  return r.fields.filter(([n]) => n === name).map(([, v]) => v);
}

const CORS_FIELDS = [
  "access-control-allow-origin",
  "access-control-allow-credentials",
  "access-control-allow-methods",
  "access-control-allow-headers",
  "access-control-expose-headers",
  "access-control-max-age",
];

function corsFields(headers: Headers): Record<string, string | null> {
  return Object.fromEntries(CORS_FIELDS.map((name) => [name, headers.get(name)]));
}

describe("CORS with the wildcard defaults", () => {
  test("every origin gets * without credentials or Vary", async () => {
    for (const origin of ["https://a.example", "null", "not an origin"]) {
      const res = await request("/any/data", { headers: { origin } });
      expect(res.status).toBe(200);
      expect(res.headers.get("access-control-allow-origin")).toBe("*");
      expect(res.headers.get("access-control-allow-credentials")).toBeNull();
      expect(res.headers.get("vary")).toBeNull();
    }
    const plain = await request("/any/data");
    expect(plain.headers.get("access-control-allow-origin")).toBe("*");
  });

  test("a preflight gets Hono's default methods", async () => {
    const res = await request("/any/data", {
      method: "OPTIONS",
      headers: { origin: "https://a.example", "access-control-request-method": "PUT" },
    });
    expect(res.status).toBe(204);
    expect(corsFields(res.headers)).toEqual({
      "access-control-allow-origin": "*",
      "access-control-allow-credentials": null,
      "access-control-allow-methods": "GET,HEAD,PUT,POST,DELETE,PATCH,QUERY",
      "access-control-allow-headers": null,
      "access-control-expose-headers": null,
      "access-control-max-age": null,
    });
    expect(res.headers.get("vary")).toBe("Access-Control-Request-Headers");
  });
});

describe("CORS with listed origins", () => {
  test("a listed origin is echoed in serialized form, with its own credentials flag", async () => {
    const plain = await request("/api/data", { headers: { origin: "https://APP.example:443" } });
    expect(plain.status).toBe(200);
    expect(plain.headers.get("access-control-allow-origin")).toBe("https://app.example");
    expect(plain.headers.get("access-control-allow-credentials")).toBeNull();
    expect(plain.headers.get("access-control-expose-headers")).toBe("X-Total");
    expect(plain.headers.get("vary")).toBe("Origin");

    const cred = await request("/api/data", { headers: { origin: "http://cred.example:8443" } });
    expect(cred.headers.get("access-control-allow-origin")).toBe("http://cred.example:8443");
    expect(cred.headers.get("access-control-allow-credentials")).toBe("true");
  });

  test("denied, absent, null and malformed origins get no grant but still Vary: Origin", async () => {
    const cases: Record<string, string>[] = [
      { origin: "https://evil.example" },
      { origin: "http://app.example" },
      { origin: "https://app.example:8443" },
      { origin: "http://cred.example" },
      { origin: "null" },
      { origin: "*" },
      { origin: "https://app.example/path" },
      { origin: "https://user@app.example" },
      {},
    ];
    for (const headers of cases) {
      const res = await request("/api/data", { headers });
      expect(res.status).toBe(200);
      expect(corsFields(res.headers)).toEqual(
        Object.fromEntries(CORS_FIELDS.map((n) => [n, null])),
      );
      expect(res.headers.get("vary")).toBe("Origin");
    }
  });

  test("a repeated Origin is denied, even when one copy is listed", async () => {
    const res = await raw("/api/data", [
      ["origin", "https://app.example"],
      ["origin", "https://evil.example"],
    ]);
    expect(res.status).toBe(200);
    expect(values(res, "access-control-allow-origin")).toEqual([]);
    expect(values(res, "vary")).toEqual(["Origin"]);
  });

  test("a granted preflight carries exactly the configured values and skips the app", async () => {
    const res = await request("/api/data", {
      method: "OPTIONS",
      headers: {
        origin: "http://cred.example:8443",
        "access-control-request-method": "PUT",
        "access-control-request-headers": "x-other",
      },
    });
    expect(res.status).toBe(204);
    expect(await res.text()).toBe("");
    expect(corsFields(res.headers)).toEqual({
      "access-control-allow-origin": "http://cred.example:8443",
      "access-control-allow-credentials": "true",
      "access-control-allow-methods": "GET,POST,PUT",
      "access-control-allow-headers": "X-Custom,Content-Type",
      "access-control-expose-headers": null,
      "access-control-max-age": "600",
    });
    expect(res.headers.get("vary")).toBe("Origin");
  });

  test("a denied preflight is answered with no CORS field", async () => {
    for (const origin of ["https://evil.example", "null"]) {
      const res = await request("/api/data", {
        method: "OPTIONS",
        headers: { origin, "access-control-request-method": "PUT" },
      });
      expect(res.status).toBe(204);
      expect(corsFields(res.headers)).toEqual(
        Object.fromEntries(CORS_FIELDS.map((n) => [n, null])),
      );
      expect(res.headers.get("vary")).toBe("Origin");
    }
  });

  test("OPTIONS without Origin or Access-Control-Request-Method reaches the app", async () => {
    const noMethod = await request("/api/options", {
      method: "OPTIONS",
      headers: { origin: "https://app.example" },
    });
    expect(noMethod.status).toBe(200);
    expect(await noMethod.text()).toBe("app options");
    expect(noMethod.headers.get("access-control-allow-origin")).toBe("https://app.example");

    const noOrigin = await request("/api/options", {
      method: "OPTIONS",
      headers: { "access-control-request-method": "GET" },
    });
    expect(noOrigin.status).toBe(200);
    expect(await noOrigin.text()).toBe("app options");
    expect(noOrigin.headers.get("access-control-allow-origin")).toBeNull();
  });

  test("app-set CORS fields are replaced and every Vary field is merged", async () => {
    const granted = await raw("/api/conflict", [["origin", "https://app.example"]]);
    expect(values(granted, "access-control-allow-origin")).toEqual(["https://app.example"]);
    expect(values(granted, "access-control-allow-credentials")).toEqual([]);
    expect(values(granted, "vary")).toEqual(["Accept, accept-encoding, origin"]);

    const denied = await raw("/api/conflict", [["origin", "https://evil.example"]]);
    expect(values(denied, "access-control-allow-origin")).toEqual([]);
    expect(values(denied, "access-control-allow-credentials")).toEqual([]);
    expect(values(denied, "vary")).toEqual(["Accept, accept-encoding, origin"]);
    for (const field of CORS_FIELDS) expect(values(denied, field)).toEqual([]);
    for (const field of [
      "access-control-allow-methods",
      "access-control-allow-headers",
      "access-control-max-age",
    ]) {
      expect(values(granted, field)).toEqual([]);
    }
    expect(values(granted, "access-control-expose-headers")).toEqual(["X-Total"]);
  });

  test("reflected request headers combine every field, keep tokens and vary", async () => {
    const res = await raw(
      "/reflect/data",
      [
        ["origin", "https://app.example"],
        ["access-control-request-method", "GET"],
        ["access-control-request-headers", "X-One"],
        ["access-control-request-headers", "X-Two , bad header,"],
      ],
      "OPTIONS",
    );
    expect(res.status).toBe(204);
    expect(values(res, "access-control-allow-headers")).toEqual(["x-one,x-two"]);
    expect(values(res, "vary")).toEqual(["Origin, Access-Control-Request-Headers"]);
  });

  test("the browser route allows only its listed origin, with credentials", async () => {
    const allowed = await request("/browser", {
      headers: { origin: "http://127.0.0.1:18441", cookie: "bnd40=credential-present" },
    });
    expect(await allowed.text()).toBe("browser GET cookie=credential-present");
    expect(allowed.headers.get("access-control-allow-origin")).toBe("http://127.0.0.1:18441");
    expect(allowed.headers.get("access-control-allow-credentials")).toBe("true");

    const preflight = await request("/browser", {
      method: "OPTIONS",
      headers: {
        origin: "http://127.0.0.1:18441",
        "access-control-request-method": "PUT",
        "access-control-request-headers": "x-bnd40",
      },
    });
    expect(preflight.status).toBe(204);
    expect(preflight.headers.get("access-control-allow-headers")).toBe("x-bnd40,content-type");
    expect(preflight.headers.get("access-control-allow-credentials")).toBe("true");

    const denied = await request("/browser", { headers: { origin: "http://127.0.0.1:18442" } });
    expect(denied.headers.get("access-control-allow-origin")).toBeNull();
    expect(denied.headers.get("access-control-allow-credentials")).toBeNull();
  });
});

describe("secure headers", () => {
  test("the defaults match Hono and remove X-Powered-By", async () => {
    const res = await request("/secure/page");
    expect(res.status).toBe(200);
    expect(
      Object.fromEntries(
        [...res.headers].filter(
          ([name]) => name !== "date" && name !== "content-length" && name !== "content-type",
        ),
      ),
    ).toEqual({
      "cross-origin-resource-policy": "same-origin",
      "cross-origin-opener-policy": "same-origin",
      "origin-agent-cluster": "?1",
      "referrer-policy": "no-referrer",
      "strict-transport-security": "max-age=15552000; includeSubDomains",
      "x-content-type-options": "nosniff",
      "x-dns-prefetch-control": "off",
      "x-download-options": "noopen",
      "x-frame-options": "SAMEORIGIN",
      "x-permitted-cross-domain-policies": "none",
      "x-xss-protection": "0",
    });
    expect(res.headers.get("cross-origin-embedder-policy")).toBeNull();
  });

  test("custom settings add, replace and drop headers", async () => {
    const res = await request("/secure-custom/page");
    expect(res.headers.get("content-security-policy")).toBe("default-src 'self'");
    expect(res.headers.get("strict-transport-security")).toBe("max-age=63072000");
    expect(res.headers.get("x-frame-options")).toBe("ALLOWALL");
    expect(res.headers.get("x-powered-by")).toBe("Bendo");
    expect(res.headers.get("x-content-type-options")).toBe("nosniff");
  });

  test("a 404 inside the layer gets the headers too", async () => {
    const res = await request("/secure/missing");
    expect(res.status).toBe(404);
    expect(res.headers.get("x-content-type-options")).toBe("nosniff");
  });
});

describe("method override", () => {
  const form = { "content-type": "application/x-www-form-urlencoded" };

  test("a form field rewrites a POST and keeps the body", async () => {
    const res = await request("/items", { method: "POST", headers: form, body: "_method=put&x=1" });
    expect(await res.text()).toBe("method:PUT body:_method=put&x=1");
    const del = await request("/items", {
      method: "POST",
      headers: form,
      body: "_method=%20Delete%20",
    });
    expect(await del.text()).toBe("method:DELETE body:_method=%20Delete%20");
  });

  test("the override runs before routing and selects the PUT-only route", async () => {
    const put = await request("/override-target", {
      method: "POST",
      headers: form,
      body: "_method=PUT",
    });
    expect(put.status).toBe(200);
    expect(await put.text()).toBe("method:PUT body:_method=PUT");
    const header = await request("/override-target", {
      method: "POST",
      headers: { "x-http-method-override": "PUT" },
    });
    expect(await header.text()).toBe("method:PUT body:");
    const post = await request("/override-target", { method: "POST", headers: form, body: "x=1" });
    expect(post.status).toBe(405);
    expect(post.headers.get("allow")).toContain("PUT");
    const get = await request("/override-target", { headers: { "x-http-method-override": "PUT" } });
    expect(get.status).toBe(405);
  });

  test("a multipart field rewrites a POST", async () => {
    const body = new FormData();
    body.set("_method", "PATCH");
    body.set("name", "x");
    const res = await request("/items", { method: "POST", body });
    expect((await res.text()).startsWith("method:PATCH body:")).toBe(true);
  });

  test("no field, an empty field or POST keeps POST", async () => {
    for (const body of ["x=1", "_method=", "_method=post"]) {
      const res = await request("/items", { method: "POST", headers: form, body });
      expect(await res.text()).toBe(`method:POST body:${body}`);
    }
  });

  test("safe, unlisted, repeated and malformed values answer 400", async () => {
    for (const body of [
      "_method=GET",
      "_method=HEAD",
      "_method=OPTIONS",
      "_method=PURGE",
      "_method=PUT&_method=PUT",
      "_method=%zz",
    ]) {
      const res = await request("/items", { method: "POST", headers: form, body });
      expect(res.status).toBe(400);
      expect(await res.text()).toBe("Bad Request");
    }
  });

  test("other content types and other methods are left alone", async () => {
    const json = await request("/items", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: '{"_method":"PUT"}',
    });
    expect(await json.text()).toBe('method:POST body:{"_method":"PUT"}');
    const put = await request("/items", { method: "PATCH", headers: form, body: "_method=DELETE" });
    expect(await put.text()).toBe("method:PATCH body:_method=DELETE");
  });

  test("a header override follows its allowlist and drops safe methods", async () => {
    const put = await request("/items", {
      method: "POST",
      headers: { "x-http-method-override": "put" },
    });
    expect(await put.text()).toBe("method:PUT body:");
    const purge = await request("/items", {
      method: "POST",
      headers: { "x-http-method-override": "purge" },
    });
    expect(await purge.text()).toBe("method:PURGE body:");
    for (const value of ["GET", "HEAD", "PATCH"]) {
      const res = await request("/items", {
        method: "POST",
        headers: { "x-http-method-override": value },
      });
      expect(res.status).toBe(400);
    }
  });

  test("a repeated override header answers 400", async () => {
    const res = await raw(
      "/items",
      [
        ["x-http-method-override", "PUT"],
        ["x-http-method-override", "PUT"],
      ],
      "POST",
    );
    expect(res.status).toBe(400);
  });

  test("CSRF still inspects an overridden cross-site form", async () => {
    const res = await request("/csrf/items", {
      method: "POST",
      headers: { ...form, origin: "https://evil.example" },
      body: "_method=put",
    });
    expect(res.status).toBe(403);
    const trusted = await request("/csrf/items", {
      method: "POST",
      headers: { ...form, origin: "https://trusted.example" },
      body: "_method=put",
    });
    expect(await trusted.text()).toBe("method:PUT body:_method=put");
  });
});

describe("trailing slash", () => {
  test("trim redirects a missing GET or HEAD route and keeps the raw query", async () => {
    const res = await request("/trim/page/?a=1&b=%20x");
    expect(res.status).toBe(301);
    expect(res.headers.get("location")).toBe("/trim/page?a=1&b=%20x");
    const head = await request("/trim/page/", { method: "HEAD" });
    expect(head.status).toBe(301);
    expect(head.headers.get("location")).toBe("/trim/page");
    const post = await request("/trim/page/", { method: "POST" });
    expect(post.status).toBe(404);
  });

  test("trim leaves the root, matched routes and open-redirect targets alone", async () => {
    expect((await request("/")).status).toBe(200);
    for (const target of [
      "//evil.example/",
      "//evil.example/x/",
      "///evil.example/",
      "/\\evil.example/",
    ]) {
      const res = await raw(target, []);
      expect(res.status === 404 || res.status === 400).toBe(true);
      expect(values(res, "location")).toEqual([]);
    }
    const options = await raw("*", [], "OPTIONS");
    expect(values(options, "location")).toEqual([]);
  });

  test("always mode trims before routing", async () => {
    const res = await request("/trim-always/page/");
    expect(res.status).toBe(301);
    expect(res.headers.get("location")).toBe("/trim-always/page");
  });

  test("append redirects a missing route and keeps the query", async () => {
    const res = await request("/append/page?x=1");
    expect(res.status).toBe(301);
    expect(res.headers.get("location")).toBe("/append/page/?x=1");
    expect((await request("/append/page/")).status).toBe(200);
    const always = await request("/append-always/page");
    expect(always.status).toBe(301);
    expect(always.headers.get("location")).toBe("/append-always/page/");
  });
});

const SECURITY_DEFAULTS: Record<string, string> = {
  "cross-origin-resource-policy": "same-origin",
  "cross-origin-opener-policy": "same-origin",
  "origin-agent-cluster": "?1",
  "referrer-policy": "no-referrer",
  "strict-transport-security": "max-age=15552000; includeSubDomains",
  "x-content-type-options": "nosniff",
  "x-dns-prefetch-control": "off",
  "x-download-options": "noopen",
  "x-frame-options": "SAMEORIGIN",
  "x-permitted-cross-domain-policies": "none",
  "x-xss-protection": "0",
};

describe("finalized response policies", () => {
  for (const [path, method, status] of [
    ["/final/error4", "GET", 422],
    ["/final/error5", "GET", 503],
    ["/final/missing", "GET", 404],
    ["/final/method", "POST", 405],
    ["/final/map", "GET", 200],
    ["/final/invalid", "GET", 500],
    ["/final/invalid-recovery", "GET", 500],
  ] satisfies [string, string, number][]) {
    test(`${method} ${path} keeps CORS and all security defaults after hooks`, async () => {
      const res = await request(path, { method, headers: { origin: "http://cred.example:8443" } });
      expect(res.status).toBe(status);
      expect(res.headers.get("access-control-allow-origin")).toBe("http://cred.example:8443");
      expect(res.headers.get("access-control-allow-credentials")).toBe("true");
      expect(res.headers.get("vary")?.toLowerCase().split(/,\s*/)).toContain("origin");
      for (const [name, value] of Object.entries(SECURITY_DEFAULTS)) {
        expect(res.headers.get(name)).toBe(value);
      }
      expect(res.headers.get("x-powered-by")).toBeNull();
      if (path === "/final/error4") {
        expect(res.headers.get("vary")).toBe("Accept, Origin");
        expect(await res.text()).toBe("rendered error");
      } else if (path === "/final/error5") {
        expect(await res.text()).toBe("Internal Server Error");
      } else if (path === "/final/map") {
        expect(await res.text()).toBe("replacement");
      }
    });
  }

  test("finalization preserves Vary star", async () => {
    const res = await request("/final/star", { headers: { origin: "http://cred.example:8443" } });
    expect(res.headers.get("vary")).toBe("*");
  });

  test("denied final errors have no grant", async () => {
    const res = await request("/final/error4", { headers: { origin: "https://evil.example" } });
    expect(res.status).toBe(422);
    expect(corsFields(res.headers)).toEqual(
      Object.fromEntries(CORS_FIELDS.map((name) => [name, null])),
    );
    expect(res.headers.get("vary")).toBe("Accept, Origin");
    for (const [name, value] of Object.entries(SECURITY_DEFAULTS))
      expect(res.headers.get(name)).toBe(value);
  });
});

test("later security response hooks win over earlier hooks and ordinary middleware", async () => {
  const res = await request("/final/hook-order");
  expect(res.headers.get("x-frame-options")).toBe("DENY");
});

test("security removal wins over a configured X-Powered-By field", async () => {
  const res = await request("/powered-remove");
  expect(res.status).toBe(200);
  expect(res.headers.get("x-powered-by")).toBeNull();
});

test("invalid retained fields yield 500 without erasing valid policies or observability", async () => {
  const res = await request("/final/bad-config", {
    headers: { origin: "http://cred.example:8443", "x-request-id": "bad-config-42" },
  });
  expect(res.status).toBe(500);
  expect(res.headers.get("x-test")).toBeNull();
  expect(res.headers.get("x-request-id")).toBe("bad-config-42");
  expect(res.headers.get("server-timing")).toMatch(/^total;dur=\d+$/);
  expect(res.headers.get("access-control-allow-origin")).toBe("http://cred.example:8443");
  expect(res.headers.get("access-control-allow-credentials")).toBe("true");
  expect(res.headers.get("vary")).toBe("Origin");
  for (const [name, value] of Object.entries(SECURITY_DEFAULTS))
    expect(res.headers.get(name)).toBe(value);
});

test("cors_allow_checked reports each dropped allow-list entry once at startup", async () => {
  const lines = server
    .stderr()
    .split("\n")
    .filter((line) => line.startsWith("bendo: cors:"));
  expect(lines).toEqual([
    'bendo: cors: ignoring allowed origin "null": not an http or https URL',
    'bendo: cors: ignoring allowed origin "checked.example": not an http or https URL',
  ]);
  // The kept entry still works, and requests print nothing more.
  const res = await request("/checked/data", { headers: { origin: "https://checked.example" } });
  expect(res.headers.get("access-control-allow-origin")).toBe("https://checked.example");
  const denied = await request("/checked/data", { headers: { origin: "null" } });
  expect(denied.headers.get("access-control-allow-origin")).toBeNull();
  expect(
    server
      .stderr()
      .split("\n")
      .filter((line) => line.startsWith("bendo: cors:")),
  ).toHaveLength(2);
});
