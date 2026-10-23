import { Elysia } from "elysia";
import { scenarios } from "../scenarios.ts";

const implementations = new Map([
  [
    "hello",
    () =>
      new Response("Hello, world!", { headers: { "content-type": "text/plain; charset=utf-8" } }),
  ],
]);

const app = new Elysia();
for (const scenario of scenarios) {
  const handler = implementations.get(scenario.name);
  if (handler === undefined) throw new Error(`Missing Elysia implementation: ${scenario.name}`);
  app.route(scenario.method, scenario.path, handler);
}
app.listen({ hostname: "127.0.0.1", port: 8787 });
