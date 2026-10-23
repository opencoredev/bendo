export type Route = { method: string; path: string };
export type Manifest = { bendo: 1; routes: Route[] };

function object(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
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
      !route.path.startsWith("/") ||
      [...route.path].some(
        (character) => character.charCodeAt(0) < 32 || character.charCodeAt(0) === 127,
      )
    )
      throw new Error(
        `Invalid route manifest: route ${routes.length + 1} needs a method and /path`,
      );
    routes.push({ method: route.method, path: route.path });
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
  if (result.exitCode !== 0)
    throw new Error(
      `Route manifest command failed (exit ${result.exitCode}); check --bendo-routes support`,
    );
  return parseManifest(result.stdout.toString());
}
