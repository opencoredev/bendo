// `bendo openapi`: the file and flag boundary around the pure generator.
import { existsSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { fetchManifest, parseManifest, type Manifest } from "./manifest.ts";
import {
  bendModule,
  documentText,
  generateOpenApi,
  parseOpenApiConfig,
  type OpenApiConfig,
} from "./openapi.ts";

export const OPENAPI_USAGE = `Usage: bendo openapi [entry] [options]

Builds the app (default: main.bend), reads its --bendo-routes manifest and
writes an OpenAPI 3.1 document.

Options:
  --out <file>       JSON output (default: openapi.json)
  --bend <file>      also write a Bend module whose json() returns the document
  --config <file>    info, servers, tags and overrides (default: openapi.config.json if present)
  --manifest <file>  read a saved manifest instead of building the app`;

export type OpenApiArgs = {
  entry: string;
  out: string;
  bend: string | null;
  config: string | null;
  manifest: string | null;
};

const FLAGS = ["--out", "--bend", "--config", "--manifest"] as const;
type Flag = (typeof FLAGS)[number];

function isFlag(value: string): value is Flag {
  return FLAGS.some((flag) => flag === value);
}

export function parseOpenApiArgs(args: readonly string[]): OpenApiArgs {
  const values: Partial<Record<Flag, string>> = {};
  let entry: string | undefined;
  for (let i = 0; i < args.length; i++) {
    const arg = args[i] ?? "";
    if (isFlag(arg)) {
      const value = args[i + 1];
      if (value === undefined || value.startsWith("-"))
        throw new Error(`${arg} needs a value\n${OPENAPI_USAGE}`);
      if (values[arg] !== undefined) throw new Error(`${arg} given twice\n${OPENAPI_USAGE}`);
      values[arg] = value;
      i++;
    } else if (arg.startsWith("-") || entry !== undefined) {
      throw new Error(`Unexpected argument ${arg}\n${OPENAPI_USAGE}`);
    } else entry = arg;
  }
  if (entry !== undefined && values["--manifest"] !== undefined)
    throw new Error(`Pass an entry or --manifest, not both\n${OPENAPI_USAGE}`);
  return {
    entry: entry ?? "main.bend",
    out: values["--out"] ?? "openapi.json",
    bend: values["--bend"] ?? null,
    config: values["--config"] ?? null,
    manifest: values["--manifest"] ?? null,
  };
}

function readJson(path: string, what: string): unknown {
  try {
    return JSON.parse(readFileSync(path, "utf8"));
  } catch (error) {
    throw new Error(
      `Cannot read ${what} ${path}: ${error instanceof Error ? error.message : String(error)}`,
    );
  }
}

/** Title, version and description fall back to the app's package.json. */
function packageInfo(): OpenApiConfig["info"] {
  if (!existsSync("package.json")) return undefined;
  const value = readJson("package.json", "package file");
  if (typeof value !== "object" || value === null || Array.isArray(value)) return undefined;
  const text = (key: string): string | undefined => {
    const member: unknown = Object.getOwnPropertyDescriptor(value, key)?.value;
    return typeof member === "string" && member !== "" ? member : undefined;
  };
  return { title: text("name"), version: text("version"), description: text("description") };
}

function loadConfig(path: string | null): OpenApiConfig {
  const file = path ?? (existsSync("openapi.config.json") ? "openapi.config.json" : null);
  const config = file === null ? {} : parseOpenApiConfig(readJson(file, "OpenAPI config"));
  const fallback = packageInfo();
  if (fallback === undefined) return config;
  const info = { ...config.info };
  info.title ??= fallback.title;
  info.version ??= fallback.version;
  info.description ??= fallback.description;
  return { ...config, info };
}

function writeAtomically(path: string, text: string): void {
  const target = resolve(path);
  const temporary = `${target}.${process.pid}.tmp`;
  writeFileSync(temporary, text);
  renameSync(temporary, target);
}

export type OpenApiIo = {
  build: (entry: string) => Promise<string>;
  log: (line: string) => void;
  warn: (line: string) => void;
};

export async function runOpenApi(args: OpenApiArgs, io: OpenApiIo): Promise<number> {
  const config = loadConfig(args.config);
  const manifest: Manifest =
    args.manifest === null
      ? fetchManifest(await io.build(args.entry))
      : parseManifest(readFileSync(args.manifest, "utf8"));
  const { document, warnings } = generateOpenApi(manifest, config);
  for (const warning of warnings) io.warn(`openapi: warning: ${warning}`);
  const text = documentText(document);
  writeAtomically(args.out, text);
  if (args.bend !== null) writeAtomically(args.bend, bendModule(documentText(document, 0)));
  const operations = Object.values(document.paths).reduce(
    (n, item) => n + Object.keys(item).length,
    0,
  );
  io.log(
    `openapi: ${Object.keys(document.paths).length} paths, ${operations} operations; wrote ${[args.out, ...(args.bend === null ? [] : [args.bend])].join(" and ")}`,
  );
  return 0;
}
