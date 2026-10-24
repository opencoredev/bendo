/** A JSON Schema (draft 2020-12) document as the manifest carries it. */
export type JsonSchema = boolean | { readonly [keyword: string]: unknown };
export const SCHEMA_SLOTS = ["params", "query", "headers", "body", "response"] as const;
export type SchemaSlot = (typeof SCHEMA_SLOTS)[number];
/** Only the slots a route sets; BND-56 derives TypeScript types from them. */
export type RouteSchemas = Partial<Record<SchemaSlot, JsonSchema>>;
export type Route = {
  method: string;
  path: string;
  params: string[];
  all: boolean;
  schemas: RouteSchemas;
};
export type Manifest = { bendo: 1; routes: Route[] };

function object(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function parseParams(value: unknown): string[] | undefined {
  if (value === undefined) return [];
  if (!Array.isArray(value)) return undefined;
  const names: string[] = [];
  for (const name of value) {
    if (typeof name !== "string") return undefined;
    names.push(name);
  }
  return names;
}

/** Unknown slot names are ignored, so later versions may add slots. */
function parseSchemas(value: unknown): RouteSchemas | undefined {
  if (value === undefined) return {};
  if (!object(value)) return undefined;
  const schemas: RouteSchemas = {};
  for (const slot of SCHEMA_SLOTS) {
    const schema = value[slot];
    if (schema === undefined) continue;
    if (typeof schema !== "boolean" && !object(schema)) return undefined;
    schemas[slot] = schema;
  }
  return schemas;
}

/** The versioned envelope is the boundary shared by routes and type generation. */
export function parseManifest(text: string): Manifest {
  let value: unknown;
  try {
    value = JSON.parse(text);
  } catch {
    throw new Error("Invalid route manifest: expected JSON from --bendo-routes");
  }
  if (!object(value) || value.bendo !== 1 || !Array.isArray(value.routes))
    throw new Error("Invalid route manifest: expected { bendo: 1, routes: [...] }");
  const routes: Route[] = [];
  for (const item of value.routes) {
    const route: unknown = item;
    if (
      !object(route) ||
      typeof route.method !== "string" ||
      !/^[!#$%&'*+.^_`|~0-9A-Za-z-]+$/.test(route.method) ||
      typeof route.path !== "string" ||
      !(route.path.startsWith("/") || route.path === "*") ||
      [...route.path].some(
        (character) => character.charCodeAt(0) < 32 || character.charCodeAt(0) === 127,
      )
    )
      throw new Error(
        `Invalid route manifest: route ${routes.length + 1} needs a method and /path`,
      );
    const params = parseParams(route.params);
    if (params === undefined)
      throw new Error(`Invalid route manifest: route ${routes.length + 1} has malformed params`);
    if (route.all !== undefined && typeof route.all !== "boolean")
      throw new Error(
        `Invalid route manifest: route ${routes.length + 1} has a malformed all flag`,
      );
    const schemas = parseSchemas(route.schemas);
    if (schemas === undefined)
      throw new Error(
        `Invalid route manifest: route ${routes.length + 1} has malformed schemas (each slot must be a JSON Schema object or boolean)`,
      );
    routes.push({
      method: route.method,
      path: route.path,
      params,
      all: route.all === true,
      schemas,
    });
  }
  return { bendo: 1, routes };
}

export function fetchManifest(binary: string): Manifest {
  const result = Bun.spawnSync([binary, "--bendo-routes"], {
    stdout: "pipe",
    stderr: "pipe",
    timeout: 10_000,
    maxBuffer: 8 * 1024 * 1024,
  });
  if (result.exitCode !== 0) {
    const detail = result.stderr.toString().trim();
    throw new Error(
      `Route manifest command failed (exit ${result.exitCode}); check --bendo-routes support${detail === "" ? "" : `: ${detail}`}`,
    );
  }
  return parseManifest(result.stdout.toString());
}
