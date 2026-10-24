import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { parseManifest } from "../packages/bendo/src/manifest.ts";
import { emitRouteTypes } from "../packages/bendo/src/route-types.ts";

// Run with: timeout 60s bun scripts/client-types-bench.ts [routes] [--distinct] [--mixed] [--query]
// BND-56's routes (100 by default), called through the real createClient types
// (BND-57). Every leaf is accessed and called, so tsc instantiates the whole
// tree. --distinct passes a different capture literal per call, so each call
// would re-filter the capture's routes if they disagreed. --mixed makes them
// disagree (odd routes take an integer team), the case that filters per value.
// --query also passes every leaf through bendo/query (BND-60): queryOptions
// with a select into useQuery, and mutationOptions with invalidation into
// useMutation, checking the data types each hook returns.
const count = Number(process.argv.find((arg) => /^\d+$/.test(arg)) ?? 100);
const distinct = process.argv.includes("--distinct");
const mixed = process.argv.includes("--mixed");
const query = process.argv.includes("--query");
const clientEntry = resolve(import.meta.dir, "../packages/bendo/client/index.ts");
const queryEntry = resolve(import.meta.dir, "../packages/bendo/query/index.ts");
// The consumer lives in a temporary directory, so name the package's own copy.
const reactQuery = Bun.resolveSync("@tanstack/react-query", dirname(queryEntry));
function queryCalls(routes: number): string {
  const team = (index: number) => (distinct ? `demo${index}` : "demo");
  return `import { useMutation, useQuery } from "${reactQuery}";
import { mutationOptions, queryOptions } from "${queryEntry}";
export function hooks(): void {
${Array.from(
  { length: routes },
  (
    _,
    index,
  ) => `  const title${index}: string | undefined = useQuery(queryOptions(api.teams({ team: "${team(index)}" }).items.item${index}.post, { body: { title: "hello" } }, { select: (item) => item.title })).data;
  const created${index}: { id: number; title: string } | undefined = useMutation(mutationOptions(api.teams({ team: "${team(index)}" }).items.item${index}.post, { invalidates: [api.teams({ team: "${team(index)}" }).items] })).data;
  void [title${index}, created${index}];`,
).join("\n")}
  // @ts-expect-error select reads a missing field
  queryOptions(api.teams({ team: "demo" }).items.item0.post, { body: { title: "hello" } }, { select: (item) => item.name });
  // @ts-expect-error the body is required
  useMutation(mutationOptions(api.teams({ team: "demo" }).items.item0.post)).mutate();
}
`;
}

const directory = mkdtempSync(join(tmpdir(), "bendo-client-bench-"));
try {
  const routes = Array.from({ length: count }, (_, index) => ({
    method: "POST",
    path: `/teams/:team/items/item${index}`,
    params: ["team"],
    schemas: {
      params: {
        type: "object",
        properties: { team: { type: mixed && index % 2 === 1 ? "integer" : "string" } },
        required: ["team"],
        additionalProperties: false,
      },
      body: {
        type: "object",
        properties: { title: { type: "string" }, done: { type: "boolean", default: false } },
        required: ["title"],
        additionalProperties: false,
      },
      response: {
        type: "object",
        properties: { id: { type: "integer" }, title: { type: "string" } },
        required: ["id", "title"],
        additionalProperties: false,
      },
    },
  }));
  writeFileSync(
    join(directory, "routes.ts"),
    emitRouteTypes(parseManifest(JSON.stringify({ bendo: 1, routes }))),
  );
  writeFileSync(
    join(directory, "consumer.ts"),
    `import type { Routes } from "./routes";
import { createClient, type ClientResult } from "${clientEntry}";
const api = createClient<Routes>("http://127.0.0.1:8787");
type Item = ClientResult<{ id: number; title: string }>;
${routes.map((_, index) => `const response${index}: Promise<Item> = api.teams({ team: "${distinct ? `demo${index}` : "demo"}" }).items.item${index}.post({ body: { title: "hello" } });`).join("\n")}
// @ts-expect-error unknown route
api.teams({ team: "demo" }).items.missing.post({ body: { title: "hello" } });
// @ts-expect-error wrong body field
api.teams({ team: "demo" }).items.item0.post({ body: { title: 1 } });
// @ts-expect-error wrong capture type
api.teams({ team: 1 }).items.item0.post({ body: { title: "hello" } });
${query ? queryCalls(routes.length) : ""}`,
  );
  writeFileSync(
    join(directory, "tsconfig.json"),
    JSON.stringify({
      compilerOptions: {
        strict: true,
        noEmit: true,
        types: [],
        target: "ES2023",
        module: "Preserve",
        moduleResolution: "bundler",
        allowImportingTsExtensions: true,
        exactOptionalPropertyTypes: true,
        lib: ["ES2023", "DOM"],
        skipLibCheck: true,
      },
      files: ["consumer.ts"],
    }),
  );
  const result = Bun.spawnSync(
    [
      "/usr/bin/time",
      "-f",
      "wall_seconds=%e max_rss_kib=%M",
      process.execPath,
      resolve(import.meta.dir, "../node_modules/typescript/bin/tsc"),
      "-p",
      directory,
      "--extendedDiagnostics",
    ],
    { stdout: "pipe", stderr: "pipe", timeout: 50_000 },
  );
  console.log(
    `${count} routes, ${readFileSync(join(directory, "routes.ts")).length} generated bytes, ${count} client calls${query ? `, ${count} queries and ${count} mutations` : ""}${distinct ? ", distinct capture values" : ""}${mixed ? ", mixed param types" : ""}`,
  );
  console.log(result.stdout.toString());
  console.log(result.stderr.toString());
  if (result.exitCode !== 0) process.exitCode = result.exitCode ?? 1;
} finally {
  rmSync(directory, { recursive: true, force: true });
}
