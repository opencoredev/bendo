export type Scenario = {
  name: string;
  path: string;
  method: "GET" | "POST";
  body?: string;
  expectedBody: string;
  bendoSource: string;
};

export const scenarios: readonly Scenario[] = [
  {
    name: "hello",
    path: "/",
    method: "GET",
    expectedBody: "Hello, world!",
    bendoSource: "bench/servers/hello.bend",
  },
];

export type Framework = "bendo" | "hono" | "elysia";
export const order: readonly Framework[] = ["bendo", "hono", "elysia"];
export const method = {
  connections: 32,
  durationSeconds: 10,
  warmupSeconds: 3,
  keepAlive: false,
  waitForOngoingRequests: true,
  requestTimeoutSeconds: 5,
  loadGeneratorThreads: 2,
  httpVersion: "1.1",
  order,
  scenarioOrder: scenarios.map((scenario) => scenario.name),
  loadGenerator: "oha and server share the same sandbox; sequential runs",
};
