import { Elysia } from "elysia";
import { customHeader, scenarioFromEnv, secureHeaders } from "../scenarios.ts";

// Elysia has no onion middleware, so each of the five maps to lifecycle hooks:
// timing wraps the handler with derive/onAfterHandle; CORS and request ID run
// on request; secure headers and the custom header run after the handler.
function middleware() {
  return new Elysia({ name: "bench-middleware" })
    .derive({ as: "global" }, () => ({ startedAt: performance.now() }))
    .onAfterHandle({ as: "global" }, ({ startedAt }) => {
      void (performance.now() - startedAt);
    })
    .onRequest(({ request, set }) => {
      set.headers["access-control-allow-origin"] = "*";
      if (request.method === "OPTIONS")
        return new Response(null, {
          status: 204,
          headers: {
            "access-control-allow-origin": "*",
            "access-control-allow-methods": "GET,HEAD,PUT,POST,DELETE,PATCH",
          },
        });
    })
    .onRequest(({ request, set }) => {
      // Reuse a well-formed incoming ID, as Hono's requestId() does.
      const incoming = request.headers.get("x-request-id");
      set.headers["x-request-id"] =
        incoming !== null && incoming.length <= 255 && /^[\w\-=]+$/.test(incoming)
          ? incoming
          : crypto.randomUUID();
    })
    .onAfterHandle({ as: "global" }, ({ set }) => {
      Object.assign(set.headers, secureHeaders);
      delete set.headers["x-powered-by"];
    })
    .onAfterHandle({ as: "global" }, ({ set }) => {
      set.headers[customHeader.name] = customHeader.value;
    });
}

const scenario = scenarioFromEnv(process.env.SCENARIO);
const app = new Elysia();
switch (scenario.name) {
  case "hello":
    app.get(scenario.routePath, () => "Hello, world!");
    break;
  case "json":
    app.get(scenario.routePath, () => ({ message: "Hello, world!" }));
    break;
  case "params": {
    // A literal pattern lets Elysia type `params.id`.
    const route = "/user/:id";
    if (scenario.routePath !== route) throw new Error(`Elysia params route is ${route}`);
    app.get(route, ({ params }) => `User ${params.id}`);
    break;
  }
  case "echo":
    app.post(scenario.routePath, ({ body }) => body);
    break;
  case "middleware":
    app.use(middleware()).get(scenario.routePath, () => "Hello, world!");
    break;
  default: {
    const exhaustive: never = scenario.name;
    throw new Error(`Missing Elysia implementation: ${exhaustive}`);
  }
}
app.listen({ hostname: "127.0.0.1", port: 8787 });
