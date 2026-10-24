import { Hono, type Context, type MiddlewareHandler } from "hono";
import { cors } from "hono/cors";
import { requestId } from "hono/request-id";
import { secureHeaders } from "hono/secure-headers";
import { customHeader, scenarioFromEnv, type ScenarioName } from "../scenarios.ts";

// A pass-through timer: measures the downstream call and records nothing.
const timing: MiddlewareHandler = async (_context, next) => {
  const start = performance.now();
  await next();
  void (performance.now() - start);
};

const custom: MiddlewareHandler = async (context, next) => {
  await next();
  context.header(customHeader.name, customHeader.value);
};

const handlers: Record<ScenarioName, (context: Context) => Response | Promise<Response>> = {
  hello: (context) => context.text("Hello, world!"),
  json: (context) => context.json({ message: "Hello, world!" }),
  params: (context) => context.text(`User ${context.req.param("id")}`),
  echo: async (context) => context.json(await context.req.json()),
  middleware: (context) => context.text("Hello, world!"),
};

const scenario = scenarioFromEnv(process.env.SCENARIO);
const app = new Hono();
if (scenario.name === "middleware") {
  app.use(timing, cors(), secureHeaders(), requestId(), custom);
}
app.on(scenario.method, scenario.routePath, handlers[scenario.name]);
Bun.serve({ hostname: "127.0.0.1", port: 8787, fetch: app.fetch });
