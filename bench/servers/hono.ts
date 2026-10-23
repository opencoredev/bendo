import { Hono, type Context } from "hono";
import { scenarios } from "../scenarios.ts";

const implementations = new Map([["hello", (context: Context) => context.text("Hello, world!")]]);

const app = new Hono();
for (const scenario of scenarios) {
  const handler = implementations.get(scenario.name);
  if (handler === undefined) throw new Error(`Missing Hono implementation: ${scenario.name}`);
  app.on(scenario.method, scenario.path, handler);
}
Bun.serve({ hostname: "127.0.0.1", port: 8787, fetch: app.fetch });
