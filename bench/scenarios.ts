export type ScenarioName = "hello" | "json" | "params" | "echo" | "middleware";

type Common = {
  name: ScenarioName;
  // Route pattern each framework registers; `path` is the URL oha requests.
  routePath: string;
  path: string;
  expectedBody: string;
  // Lowercase names. Every framework must answer exactly these values.
  expectedHeaders: Readonly<Record<string, string>>;
  // Lowercase names whose values vary per response, such as generated IDs.
  presentHeaders: readonly string[];
  bendoSource: string;
};

export type Scenario =
  | (Common & { method: "GET"; body?: never })
  | (Common & { method: "POST"; body: string });

// Sent on every request, readiness check and load run alike.
export const requestHeaders = {
  "content-type": "application/json",
  origin: "https://bench.example",
} as const;

// A deterministic 1024-byte JSON document that survives JSON.parse and
// JSON.stringify byte-for-byte: ASCII strings without escapes, integers only.
function echoDocument() {
  const items = [];
  for (let id = 1; id <= 12; id++)
    items.push({
      id,
      sku: `SKU-${String(id).padStart(4, "0")}`,
      qty: id * 3,
      active: id % 2 === 0,
    });
  const base = JSON.stringify({ order: 42, customer: "bench", items, note: "" });
  const document = JSON.stringify({
    order: 42,
    customer: "bench",
    items,
    note: "x".repeat(1024 - base.length),
  });
  if (document.length !== 1024) throw new Error(`Echo document is ${document.length} bytes`);
  return document;
}
const echoBody = echoDocument();

export const customHeader = { name: "x-bench", value: "middleware" } as const;
// Hono 4 secureHeaders() defaults; Bendo's B.secure_headers() mirrors them.
export const secureHeaders = {
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
} as const;

export const scenarios: readonly Scenario[] = [
  {
    name: "hello",
    method: "GET",
    routePath: "/",
    path: "/",
    expectedBody: "Hello, world!",
    expectedHeaders: {},
    presentHeaders: [],
    bendoSource: "bench/servers/hello.bend",
  },
  {
    name: "json",
    method: "GET",
    routePath: "/json",
    path: "/json",
    expectedBody: JSON.stringify({ message: "Hello, world!" }),
    expectedHeaders: {},
    presentHeaders: [],
    bendoSource: "bench/servers/json.bend",
  },
  {
    name: "params",
    method: "GET",
    routePath: "/user/:id",
    path: "/user/42",
    expectedBody: "User 42",
    expectedHeaders: {},
    presentHeaders: [],
    bendoSource: "bench/servers/params.bend",
  },
  {
    name: "echo",
    method: "POST",
    routePath: "/echo",
    path: "/echo",
    body: echoBody,
    expectedBody: echoBody,
    expectedHeaders: {},
    presentHeaders: [],
    bendoSource: "bench/servers/echo.bend",
  },
  {
    name: "middleware",
    method: "GET",
    routePath: "/middleware",
    path: "/middleware",
    expectedBody: "Hello, world!",
    expectedHeaders: {
      "access-control-allow-origin": "*",
      ...secureHeaders,
      [customHeader.name]: customHeader.value,
    },
    presentHeaders: ["x-request-id"],
    bendoSource: "bench/servers/middleware.bend",
  },
];

// Servers read SCENARIO at startup so each process registers one route and,
// for the middleware scenario only, its middleware stack.
export function scenarioFromEnv(value: string | undefined): Scenario {
  const scenario = scenarios.find((candidate) => candidate.name === value);
  if (scenario === undefined)
    throw new Error(
      `SCENARIO must be one of ${scenarios.map((s) => s.name).join(", ")}; got ${value}`,
    );
  return scenario;
}

export type Framework = "bendo" | "hono" | "elysia";
export const order: readonly Framework[] = ["bendo", "hono", "elysia"];
export const method = {
  connections: 64,
  durationSeconds: 15,
  warmupSeconds: 3,
  repetitions: 3,
  keepAlive: true,
  waitForOngoingRequests: true,
  requestTimeoutSeconds: 5,
  loadGeneratorThreads: 2,
  httpVersion: "1.1",
  requestHeaders,
  order,
  scenarioOrder: scenarios.map((scenario) => scenario.name),
  loadGenerator: "oha in the same sandbox as the server; one server at a time",
};
