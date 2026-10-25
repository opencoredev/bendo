import type { DefaultTheme } from "vitepress";

// One sidebar for the whole site. Every published page must appear here;
// `config.ts` fails the build when a page is missing.
//
// Planned section: BND-71 adds "API reference" after "TypeScript toolkit".
export const sidebar: DefaultTheme.SidebarItem[] = [
  {
    text: "Getting started",
    items: [
      { text: "Introduction", link: "/introduction" },
      { text: "Quick start", link: "/getting-started" },
      { text: "Examples", link: "/examples" },
    ],
  },
  {
    text: "Concepts",
    items: [
      { text: "How a request flows", link: "/concepts/" },
      { text: "Routing", link: "/concepts/routing" },
      { text: "Context", link: "/concepts/context" },
      { text: "Middleware", link: "/concepts/middleware" },
      { text: "Hooks", link: "/concepts/hooks" },
      { text: "Validation", link: "/concepts/validation" },
      { text: "Stores", link: "/concepts/stores" },
      { text: "Proofs", link: "/concepts/proofs" },
    ],
  },
  {
    text: "Guides",
    items: [
      { text: "Develop with the CLI", link: "/cli" },
      { text: "Write a plugin", link: "/guides/plugins" },
      { text: "Protect routes with auth", link: "/guides/auth" },
      { text: "Call your API from another origin", link: "/guides/cors" },
      { text: "Accept file uploads", link: "/guides/uploads" },
      { text: "Add WebSockets", link: "/guides/websockets" },
      { text: "Deploy behind Caddy or Cloudflare", link: "/guides/deploy" },
      { text: "Migrate from Hono", link: "/guides/migrate-from-hono" },
      { text: "Migrate from Elysia", link: "/guides/migrate-from-elysia" },
    ],
  },
  {
    text: "Routing",
    collapsed: true,
    items: [
      { text: "Route patterns", link: "/router-patterns" },
      { text: "Route by HTTP method", link: "/router-methods" },
      { text: "Compose route lists", link: "/router-compose" },
      { text: "Spec router", link: "/router-spec" },
      { text: "Trie router", link: "/router-trie" },
    ],
  },
  {
    text: "Requests and responses",
    collapsed: true,
    items: [
      { text: "Request context", link: "/context" },
      { text: "Cookies", link: "/cookies" },
      { text: "Static files", link: "/static" },
      { text: "Stream a response", link: "/streaming" },
      { text: "Limits and caching", link: "/limits-cache" },
      { text: "Connection info and rate limits", link: "/connection" },
      { text: "HTTP conformance", link: "/http-conformance" },
    ],
  },
  {
    text: "Data and validation",
    collapsed: true,
    items: [
      { text: "Route validation", link: "/validation" },
      { text: "Schemas", link: "/data/schema" },
      { text: "JSON", link: "/data/json" },
      { text: "JSON Schema export", link: "/data/json-schema" },
      { text: "Query strings and forms", link: "/data/urlencoded" },
      { text: "Multipart forms", link: "/data/multipart" },
    ],
  },
  {
    text: "Middleware",
    collapsed: true,
    items: [
      { text: "Middleware", link: "/middleware" },
      { text: "CORS and web headers", link: "/web-middleware" },
      { text: "Authentication and CSRF", link: "/auth" },
      { text: "Crypto and encoding", link: "/crypto" },
      { text: "Observability", link: "/observability" },
      { text: "Proxy", link: "/proxy" },
      { text: "Compression", link: "/compression" },
    ],
  },
  {
    text: "Real time",
    collapsed: true,
    items: [
      { text: "Server-Sent Events", link: "/sse" },
      { text: "WebSocket upgrades", link: "/websocket" },
      { text: "WebSocket handlers", link: "/websocket-sessions" },
      { text: "WebSocket frames", link: "/websocket-frames" },
      { text: "Publish and subscribe", link: "/websocket-pubsub" },
    ],
  },
  {
    text: "State and scale",
    collapsed: true,
    items: [
      { text: "Shared state", link: "/store" },
      { text: "Workers", link: "/workers" },
    ],
  },
  {
    text: "TypeScript toolkit",
    collapsed: true,
    items: [
      { text: "Route manifest", link: "/manifest" },
      { text: "Generated route types", link: "/route-types" },
      { text: "Typed client", link: "/client" },
      { text: "TanStack Query helpers", link: "/query" },
      { text: "Share Bend code with JS", link: "/shared" },
      { text: "Vite plugin", link: "/vite-plugin" },
      { text: "OpenAPI and API docs", link: "/openapi" },
    ],
  },
  {
    text: "Releases",
    collapsed: true,
    items: [
      { text: "Versioning", link: "/versioning" },
      { text: "Releasing", link: "/releasing" },
    ],
  },
  {
    text: "Laws",
    collapsed: true,
    items: [
      { text: "The laws in plain words", link: "/laws/" },
      { text: "HTTP", link: "/laws/http" },
      { text: "Routing", link: "/laws/routing" },
      { text: "Middleware", link: "/laws/middleware" },
      { text: "Data", link: "/laws/data" },
      { text: "Crypto and JWT", link: "/laws/crypto" },
      { text: "Streaming and static files", link: "/laws/streaming" },
      { text: "Equivalences", link: "/laws/equivalences" },
    ],
  },
  {
    text: "Design decisions",
    collapsed: true,
    items: [
      { text: "0001 Route table", link: "/decisions/0001-route-table" },
      { text: "0002 Bytes", link: "/decisions/0002-bytes" },
      { text: "0003 Typed values", link: "/decisions/0003-typed-values" },
      { text: "0004 Request parser", link: "/decisions/0004-request-parser" },
      { text: "0005 Body framing", link: "/decisions/0005-framing" },
      { text: "0006 Response framing", link: "/decisions/0006-response-framing" },
      { text: "0007 HTTP Date", link: "/decisions/0007-http-date" },
      { text: "0008 Hono router differences", link: "/decisions/0008-router-differences" },
      { text: "0009 Connections", link: "/decisions/0009-connections" },
      { text: "0010 Lifecycle hooks", link: "/decisions/0010-hooks" },
      { text: "0011 Errors and crashes", link: "/decisions/0011-crash" },
      { text: "0011 Hook scopes", link: "/decisions/0011-hook-scopes" },
      { text: "0012 Constant-time auth", link: "/decisions/0012-constant-time-auth" },
      { text: "0013 OpenAPI generation", link: "/decisions/0013-openapi-generation" },
      { text: "0014 Performance", link: "/decisions/0014-performance" },
      { text: "0015 WebSocket mailbox", link: "/decisions/0015-websocket-mailbox" },
      {
        text: "0016 Client response validation",
        link: "/decisions/0016-client-response-validation",
      },
      { text: "0017 Workers", link: "/decisions/0017-workers" },
      { text: "0018 WebSocket pub/sub", link: "/decisions/0018-websocket-pubsub" },
    ],
  },
];
