// BND-62: OpenAPI 3.1 from the route manifest. OpenAPI 3.1 schema objects are
// JSON Schema 2020-12, so the manifest's slot documents embed unchanged apart
// from their `$schema` member. docs/openapi.md describes the mapping.
import type { JsonSchema, Manifest, Route, RouteSchemas } from "./manifest.ts";

export const OPENAPI_VERSION = "3.1.1";

/** OpenAPI's fixed Path Item operations; other methods cannot be expressed. */
const OPERATION_METHODS = [
  "get",
  "put",
  "post",
  "delete",
  "options",
  "head",
  "patch",
  "trace",
] as const;
export type OperationMethod = (typeof OPERATION_METHODS)[number];
const DEFAULT_ALL_METHODS: readonly OperationMethod[] = ["get", "post", "put", "patch", "delete"];

/** OpenAPI ignores header parameters with these names (OAS 3.1 §4.8.12.1). */
const IGNORED_HEADERS = new Set(["accept", "content-type", "authorization"]);

// ---------------------------------------------------------------------------
// Bendo route patterns (docs/router-patterns.md)

export type Constraint =
  | { kind: "int" }
  | { kind: "uuid" }
  | { kind: "slug" }
  | {
      kind: "class";
      members: string;
      repeat: { kind: "plus" } | { kind: "exactly"; count: string };
    };

export type Segment =
  | { kind: "static"; text: string }
  | { kind: "param"; name: string; constraint: Constraint | null; optional: boolean }
  | { kind: "span"; name: string }
  | { kind: "wildcard"; name: string | null; final: boolean }
  | { kind: "prefix"; text: string };

const NAME = /^[A-Za-z_][A-Za-z0-9_]*$/;

function parseConstraint(text: string, pattern: string): Constraint {
  switch (text) {
    case "int":
    case "uuid":
    case "slug":
      return { kind: text };
  }
  const match = /^\[([^\]]+)\](?:(\+)|\{([0-9]+)\})$/.exec(text);
  if (match?.[1] === undefined) throw new Error(`Unsupported constraint {${text}} in ${pattern}`);
  return {
    kind: "class",
    members: match[1],
    repeat:
      match[2] === "+" ? { kind: "plus" } : { kind: "exactly", count: String(Number(match[3])) },
  };
}

function parseSegment(raw: string, final: boolean, pattern: string): Segment {
  if (raw.startsWith(":")) {
    const optional = raw.endsWith("?");
    const body = optional ? raw.slice(1, -1) : raw.slice(1);
    const brace = body.indexOf("{");
    const name = brace === -1 ? body : body.slice(0, brace);
    if (!NAME.test(name)) throw new Error(`Invalid capture ${raw} in ${pattern}`);
    if (brace === -1) return { kind: "param", name, constraint: null, optional };
    if (!body.endsWith("}")) throw new Error(`Invalid capture ${raw} in ${pattern}`);
    const constraint = body.slice(brace + 1, -1);
    if (constraint === ".+") return { kind: "span", name };
    return { kind: "param", name, constraint: parseConstraint(constraint, pattern), optional };
  }
  if (raw === "*") return { kind: "wildcard", name: final ? "*" : null, final };
  if (raw.startsWith("*")) {
    const name = raw.slice(1);
    if (!NAME.test(name)) throw new Error(`Invalid wildcard ${raw} in ${pattern}`);
    return { kind: "wildcard", name, final };
  }
  if (raw.endsWith("*")) return { kind: "prefix", text: raw.slice(0, -1) };
  return { kind: "static", text: raw };
}

/** Splits a compiled pattern such as `/todos/:id{int}` into its segments. */
export function parsePattern(pattern: string): Segment[] {
  const path = pattern === "*" ? "/*" : pattern;
  if (!path.startsWith("/")) throw new Error(`Route pattern must start with /: ${pattern}`);
  const raws = path.slice(1).split("/");
  return raws.map((raw, index) => parseSegment(raw, index === raws.length - 1, pattern));
}

// ---------------------------------------------------------------------------
// Configuration (the boundary: `bendo openapi --config` reads it from JSON)

export type Contact = {
  name?: string | undefined;
  url?: string | undefined;
  email?: string | undefined;
};
/** OpenAPI 3.1 allows an SPDX `identifier` or a `url` for a license, never both. */
export type License =
  | { name: string }
  | { name: string; identifier: string }
  | { name: string; url: string };
export type Info = {
  title: string;
  version: string;
  summary?: string | undefined;
  description?: string | undefined;
  termsOfService?: string | undefined;
  contact?: Contact | undefined;
  license?: License | undefined;
};
/** `info` in the config: every field optional; title and version get defaults. */
export type InfoConfig = { [K in keyof Info]?: Info[K] | undefined };
export type Server = { url: string; description?: string | undefined };
export type Tag = { name: string; description?: string | undefined };
export type OperationOverride = {
  summary?: string | undefined;
  description?: string | undefined;
  operationId?: string | undefined;
  tags?: string[] | undefined;
  deprecated?: boolean | undefined;
};
export type OpenApiConfig = {
  info?: InfoConfig | undefined;
  servers?: Server[] | undefined;
  tags?: Tag[] | undefined;
  /** Tag each operation with its path's first static segment. Default true. */
  autoTags?: boolean | undefined;
  /** Methods an `all` route documents. Default get, post, put, patch, delete. */
  allMethods?: OperationMethod[] | undefined;
  /** Manifest paths to leave out, such as `/docs` and `/openapi.json`. */
  exclude?: string[] | undefined;
  /** Keyed by `METHOD /manifest/path`, for example `GET /todos/:id{int}`. */
  operations?: Record<string, OperationOverride> | undefined;
};

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function optionalString(
  object: Record<string, unknown>,
  key: string,
  where: string,
): string | undefined {
  const value = object[key];
  if (value === undefined) return undefined;
  if (typeof value !== "string")
    throw new Error(`OpenAPI config: ${where}.${key} must be a string`);
  return value;
}

function strings(value: unknown, where: string): string[] | undefined {
  if (value === undefined) return undefined;
  if (!Array.isArray(value) || !value.every((item) => typeof item === "string"))
    throw new Error(`OpenAPI config: ${where} must be an array of strings`);
  return value.filter((item) => typeof item === "string");
}

function parseContact(value: unknown): Contact | undefined {
  if (value === undefined) return undefined;
  if (!isRecord(value)) throw new Error("OpenAPI config: info.contact must be an object");
  return {
    name: optionalString(value, "name", "info.contact"),
    url: optionalString(value, "url", "info.contact"),
    email: optionalString(value, "email", "info.contact"),
  };
}

function parseLicense(value: unknown): License | undefined {
  if (value === undefined) return undefined;
  if (!isRecord(value) || typeof value.name !== "string")
    throw new Error("OpenAPI config: info.license needs a name");
  const identifier = optionalString(value, "identifier", "info.license");
  const url = optionalString(value, "url", "info.license");
  if (identifier !== undefined && url !== undefined)
    throw new Error("OpenAPI config: info.license takes an identifier or a url, not both");
  if (identifier !== undefined) return { name: value.name, identifier };
  if (url !== undefined) return { name: value.name, url };
  return { name: value.name };
}

function parseInfo(value: unknown): InfoConfig | undefined {
  if (value === undefined) return undefined;
  if (!isRecord(value)) throw new Error("OpenAPI config: info must be an object");
  return {
    title: optionalString(value, "title", "info"),
    version: optionalString(value, "version", "info"),
    summary: optionalString(value, "summary", "info"),
    description: optionalString(value, "description", "info"),
    termsOfService: optionalString(value, "termsOfService", "info"),
    contact: parseContact(value.contact),
    license: parseLicense(value.license),
  };
}

function parseNamed<T>(
  value: unknown,
  where: string,
  key: string,
  read: (item: Record<string, unknown>, at: string) => T,
): T[] | undefined {
  if (value === undefined) return undefined;
  if (!Array.isArray(value)) throw new Error(`OpenAPI config: ${where} must be an array`);
  return value.map((item: unknown, index) => {
    const at = `${where}[${index}]`;
    if (!isRecord(item) || typeof item[key] !== "string")
      throw new Error(`OpenAPI config: ${at} needs a ${key}`);
    return read(item, at);
  });
}

function isOperationMethod(value: string): value is OperationMethod {
  return OPERATION_METHODS.some((method) => method === value);
}

function parseOverride(value: unknown, key: string): OperationOverride {
  const where = `operations["${key}"]`;
  if (!isRecord(value)) throw new Error(`OpenAPI config: ${where} must be an object`);
  const deprecated = value.deprecated;
  if (deprecated !== undefined && typeof deprecated !== "boolean")
    throw new Error(`OpenAPI config: ${where}.deprecated must be a boolean`);
  return {
    summary: optionalString(value, "summary", where),
    description: optionalString(value, "description", where),
    operationId: optionalString(value, "operationId", where),
    tags: strings(value.tags, `${where}.tags`),
    deprecated,
  };
}

/** Parses an `openapi.config.json` value. Unknown members are rejected. */
export function parseOpenApiConfig(value: unknown): OpenApiConfig {
  if (!isRecord(value)) throw new Error("OpenAPI config must be a JSON object");
  const known = ["info", "servers", "tags", "autoTags", "allMethods", "exclude", "operations"];
  for (const key of Object.keys(value))
    if (!known.includes(key)) throw new Error(`OpenAPI config: unknown member ${key}`);
  if (value.autoTags !== undefined && typeof value.autoTags !== "boolean")
    throw new Error("OpenAPI config: autoTags must be a boolean");
  const allMethods = strings(value.allMethods, "allMethods")?.map((method) => {
    if (!isOperationMethod(method))
      throw new Error(
        `OpenAPI config: allMethods has ${method}; use ${OPERATION_METHODS.join(", ")}`,
      );
    return method;
  });
  let operations: Record<string, OperationOverride> | undefined;
  if (value.operations !== undefined) {
    if (!isRecord(value.operations))
      throw new Error("OpenAPI config: operations must be an object");
    operations = {};
    for (const [key, override] of Object.entries(value.operations))
      operations[key] = parseOverride(override, key);
  }
  return {
    info: parseInfo(value.info),
    servers: parseNamed(value.servers, "servers", "url", (item, at) => ({
      url: String(item.url),
      description: optionalString(item, "description", at),
    })),
    tags: parseNamed(value.tags, "tags", "name", (item, at) => ({
      name: String(item.name),
      description: optionalString(item, "description", at),
    })),
    autoTags: value.autoTags,
    allMethods,
    exclude: strings(value.exclude, "exclude"),
    operations,
  };
}

// ---------------------------------------------------------------------------
// Generation

type Schema = JsonSchema;
type Parameter = {
  name: string;
  in: "path" | "query" | "header";
  required: boolean;
  description?: string;
  schema: Schema;
};
type MediaType = { schema: Schema };
type Operation = {
  tags?: string[];
  summary?: string;
  description?: string;
  operationId?: string;
  parameters?: Parameter[];
  requestBody?: { required: true; content: { "application/json": MediaType } };
  responses: Record<string, { description: string; content?: { "application/json": MediaType } }>;
  deprecated?: boolean;
  "x-bendo-route": string;
  "x-bendo-all"?: true;
};
type PathItem = Partial<Record<OperationMethod, Operation>>;
export type OpenApiDocument = {
  openapi: typeof OPENAPI_VERSION;
  info: Info;
  servers?: Server[];
  tags?: Tag[];
  paths: Record<string, PathItem>;
};
export type OpenApiResult = { document: OpenApiDocument; warnings: string[] };

/** One OpenAPI path for one expansion of a pattern's optional captures. */
type Template = { path: string; key: string; parameters: Parameter[] };

/** Strips `$schema`: OpenAPI 3.1 already uses the 2020-12 vocabulary. */
function embedded(schema: Schema): Schema {
  if (typeof schema === "boolean") return schema;
  const { $schema: _dialect, ...rest } = schema;
  return rest;
}

/** The property schemas and required list of an object slot, if it has that form. */
function objectMembers(
  schema: Schema | undefined,
): { properties: Record<string, Schema>; required: string[] } | null {
  if (schema === undefined || typeof schema === "boolean") return null;
  const properties = schema.properties;
  if (!isRecord(properties)) return null;
  const members: Record<string, Schema> = {};
  for (const [name, value] of Object.entries(properties))
    if (typeof value === "boolean" || isRecord(value)) members[name] = value;
  const required = Array.isArray(schema.required)
    ? schema.required.filter((item) => typeof item === "string")
    : [];
  return { properties: members, required };
}

const UUID = "^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$";

function constraintSchema(constraint: Constraint | null): Schema {
  if (constraint === null) return { type: "string", minLength: 1 };
  switch (constraint.kind) {
    case "int":
      return { type: "string", pattern: "^-?[0-9]+$" };
    case "uuid":
      return { type: "string", format: "uuid", pattern: UUID };
    case "slug":
      return { type: "string", pattern: "^[a-z0-9-]+$" };
    case "class": {
      const repeat = constraint.repeat.kind === "plus" ? "+" : `{${constraint.repeat.count}}`;
      return { type: "string", pattern: `^[${constraint.members}]${repeat}$` };
    }
    default: {
      const exhaustive: never = constraint;
      return exhaustive;
    }
  }
}

function uniqueName(base: string, used: Set<string>): string {
  let name = base;
  for (let n = 2; used.has(name); n++) name = `${base}${n}`;
  used.add(name);
  return name;
}

/**
 * Expands a pattern into OpenAPI templates. A chain of k optional captures
 * gives k + 1 paths, shortest first, because OpenAPI path parameters are
 * always required. `key` replaces every parameter name with `{}` so templates
 * that differ only in names are recognized as the same OpenAPI path.
 */
function templates(pattern: string, slot: RouteSchemas["params"]): Template[] {
  const segments = parsePattern(pattern);
  const members = objectMembers(slot);
  const used = new Set(
    segments.flatMap((s) =>
      s.kind === "param" || s.kind === "span"
        ? [s.name]
        : s.kind === "wildcard" && s.name !== null && s.name !== "*"
          ? [s.name]
          : [],
    ),
  );
  const fixed: { text: string; key: string; parameter: Parameter | null }[] = [];
  const optional: { text: string; key: string; parameter: Parameter }[] = [];
  const declared = (name: string, fallback: Schema): Schema => {
    const schema = members?.properties[name];
    return schema === undefined ? fallback : embedded(schema);
  };
  for (const segment of segments) {
    switch (segment.kind) {
      case "static":
        fixed.push({ text: segment.text, key: segment.text, parameter: null });
        break;
      case "param": {
        const parameter: Parameter = {
          name: segment.name,
          in: "path",
          required: true,
          schema: declared(segment.name, constraintSchema(segment.constraint)),
        };
        if (segment.optional)
          optional.push({
            text: `{${segment.name}}`,
            key: "{}",
            parameter: {
              ...parameter,
              description: "Optional in the route; this path is the form that includes it.",
            },
          });
        else fixed.push({ text: `{${segment.name}}`, key: "{}", parameter });
        break;
      }
      case "span":
        fixed.push({
          text: `{${segment.name}}`,
          key: "{}",
          parameter: {
            name: segment.name,
            in: "path",
            required: true,
            description: "Spans one or more path segments, so the value may contain `/`.",
            schema: declared(segment.name, { type: "string", minLength: 1 }),
          },
        });
        break;
      case "wildcard": {
        const captured = segment.name !== null;
        const name =
          segment.name === null || segment.name === "*"
            ? uniqueName("wildcard", used)
            : segment.name;
        fixed.push({
          text: `{${name}}`,
          key: "{}",
          parameter: {
            name,
            in: "path",
            required: true,
            description: captured
              ? `The rest of the path${segment.name === "*" ? " (captured as `*`)" : ""}; may be empty or contain \`/\`.`
              : "Zero or more whole path segments; the route does not capture them.",
            schema: declared(segment.name ?? name, { type: "string" }),
          },
        });
        break;
      }
      case "prefix": {
        const name = uniqueName("suffix", used);
        fixed.push({
          text: `${segment.text}{${name}}`,
          key: `${segment.text}{}`,
          parameter: {
            name,
            in: "path",
            required: true,
            description: `Any text after \`${segment.text}\`, including \`/\`; the route does not capture it.`,
            schema: { type: "string" },
          },
        });
        break;
      }
      default: {
        const exhaustive: never = segment;
        return exhaustive;
      }
    }
  }
  const result: Template[] = [];
  for (let present = 0; present <= optional.length; present++) {
    const parts = [...fixed, ...optional.slice(0, present)];
    const path = `/${parts.map((p) => p.text).join("/")}`;
    const key = `/${parts.map((p) => p.key).join("/")}`;
    result.push({
      path,
      key,
      parameters: parts.flatMap((p) => (p.parameter === null ? [] : [p.parameter])),
    });
  }
  return result;
}

function objectParameters(
  slot: Schema | undefined,
  location: "query" | "header",
  route: string,
  warnings: string[],
): Parameter[] {
  if (slot === undefined) return [];
  const members = objectMembers(slot);
  if (members === null) {
    warnings.push(
      `${route}: the ${location === "query" ? "query" : "headers"} schema is not an object with properties, so it has no parameters`,
    );
    return [];
  }
  const parameters: Parameter[] = [];
  for (const [name, schema] of Object.entries(members.properties)) {
    if (location === "header" && IGNORED_HEADERS.has(name.toLowerCase())) {
      warnings.push(`${route}: OpenAPI ignores a header parameter named ${name}; it is left out`);
      continue;
    }
    parameters.push({
      name,
      in: location,
      required: members.required.includes(name),
      schema: embedded(schema),
    });
  }
  return parameters;
}

function words(text: string): string[] {
  return text.split(/[^\p{L}\p{N}]+/u).filter((word) => word !== "");
}

function camel(parts: string[]): string {
  return parts
    .map((part, index) =>
      index === 0 ? part.toLowerCase() : part.charAt(0).toUpperCase() + part.slice(1),
    )
    .join("");
}

/** `get` + `/todos/{id}` gives `getTodosById`; `/` gives `getRoot`. */
function operationName(method: OperationMethod, template: Template): string {
  const parts: string[] = [method];
  for (const raw of template.path.split("/")) {
    const param = /^\{(.+)\}$/.exec(raw);
    if (param?.[1] !== undefined) parts.push("by", ...words(param[1]));
    else parts.push(...words(raw));
  }
  return camel(parts.length === 1 ? [method, "root"] : parts);
}

function firstStatic(pattern: string): string | null {
  const first = parsePattern(pattern)[0];
  if (first === undefined || first.kind !== "static" || first.text === "") return null;
  return first.text;
}

function operationMethods(
  route: Route,
  allMethods: readonly OperationMethod[],
): OperationMethod[] | null {
  if (route.all) return [...allMethods];
  const method = route.method.toLowerCase();
  if (route.method !== route.method.toUpperCase() || !isOperationMethod(method)) return null;
  return [method];
}

/**
 * Builds an OpenAPI 3.1 document. Routes keep manifest order; where two
 * routes give the same method on the same OpenAPI path, the first registered
 * wins, as it does in the router, and a warning names the later one.
 */
export function generateOpenApi(manifest: Manifest, options: OpenApiConfig = {}): OpenApiResult {
  const warnings: string[] = [];
  const paths: Record<string, PathItem> = {};
  // OpenAPI treats /a/{x} and /a/{y} as the same path; the first spelling wins.
  const spelling = new Map<string, string>();
  const operationIds = new Set<string>();
  const tagOrder: string[] = [];
  const exclude = new Set(options.exclude ?? []);
  const allMethods = options.allMethods ?? DEFAULT_ALL_METHODS;
  const overrides = options.operations ?? {};
  const unusedOverrides = new Set(Object.keys(overrides));

  for (const route of manifest.routes) {
    if (exclude.has(route.path)) continue;
    const label = `${route.method} ${route.path}`;
    const methods = operationMethods(route, allMethods);
    if (methods === null) {
      warnings.push(
        `${label}: OpenAPI 3.1 has no operation for the ${route.method} method; it is left out`,
      );
      continue;
    }
    const override = overrides[label];
    unusedOverrides.delete(label);
    const query = objectParameters(route.schemas.query, "query", label, warnings);
    const headers = objectParameters(route.schemas.headers, "header", label, warnings);
    const tag = options.autoTags === false ? null : firstStatic(route.path);
    const tags = override?.tags ?? (tag === null ? undefined : [tag]);
    for (const name of tags ?? []) if (!tagOrder.includes(name)) tagOrder.push(name);
    const expansions = templates(route.path, route.schemas.params);
    for (const template of expansions) {
      const known = spelling.get(template.key);
      const path = known ?? template.path;
      if (known === undefined) spelling.set(template.key, template.path);
      const renamed = renameParameters(template, path);
      const item = (paths[path] ??= {});
      for (const method of methods) {
        if (item[method] !== undefined) {
          warnings.push(
            `${label}: ${method.toUpperCase()} ${path} is already documented by an earlier route, which the router tries first; it is left out`,
          );
          continue;
        }
        const operation: Operation = {
          ...(tags === undefined ? {} : { tags }),
          ...(override?.summary === undefined ? {} : { summary: override.summary }),
          ...(override?.description === undefined ? {} : { description: override.description }),
          operationId: uniqueName(
            override?.operationId !== undefined && expansions.length === 1 && methods.length === 1
              ? override.operationId
              : operationName(method, template),
            operationIds,
          ),
          responses: {},
          "x-bendo-route": label,
        };
        const parameters = [...renamed, ...query, ...headers];
        if (parameters.length > 0) operation.parameters = parameters;
        const body = route.schemas.body;
        if (body !== undefined)
          operation.requestBody = {
            required: true,
            content: { "application/json": { schema: embedded(body) } },
          };
        const response = route.schemas.response;
        operation.responses =
          response === undefined
            ? { default: { description: "Response" } }
            : {
                "200": {
                  description: "Successful response",
                  content: { "application/json": { schema: embedded(response) } },
                },
              };
        if (override?.deprecated === true) operation.deprecated = true;
        if (route.all) operation["x-bendo-all"] = true;
        item[method] = operation;
      }
    }
  }
  for (const key of unusedOverrides)
    warnings.push(`operations["${key}"] matches no documented route`);

  const configured = options.tags ?? [];
  const tags: Tag[] = [...configured];
  for (const name of tagOrder)
    if (!configured.some((tag) => tag.name === name)) tags.push({ name });
  const info: Info = {
    ...options.info,
    title: options.info?.title ?? "Bendo API",
    version: options.info?.version ?? "0.0.0",
  };
  const document: OpenApiDocument = {
    openapi: OPENAPI_VERSION,
    info,
    ...(options.servers === undefined || options.servers.length === 0
      ? {}
      : { servers: options.servers }),
    ...(tags.length === 0 ? {} : { tags }),
    paths,
  };
  return { document, warnings };
}

/** Gives a template the parameter names of the path spelling already in the document. */
function renameParameters(template: Template, path: string): Parameter[] {
  if (path === template.path) return template.parameters;
  const names = [...path.matchAll(/\{([^}]+)\}/g)].map((m) => m[1] ?? "");
  return template.parameters.map((parameter, index) => {
    const name = names[index];
    return name === undefined || name === parameter.name ? parameter : { ...parameter, name };
  });
}

// ---------------------------------------------------------------------------
// Output

/** Stable JSON text; non-ASCII is escaped so the Bend module stays ASCII. */
export function documentText(document: OpenApiDocument, indent = 2): string {
  return `${JSON.stringify(document, null, indent).replace(/[\u007f-￿]/g, (c) => `\\u${c.charCodeAt(0).toString(16).padStart(4, "0")}`)}\n`;
}

/**
 * A Bend module whose `json()` returns the document. Bend overflows its stack
 * on one large string literal, so the text is split into 256-character
 * literals, one def each, joined at startup.
 */
export function bendModule(text: string): string {
  const compact = text.trimEnd();
  const chunks: string[] = [];
  for (let i = 0; i < compact.length; i += 256) chunks.push(compact.slice(i, i + 256));
  const literal = (chunk: string): string =>
    `"${chunk.replace(/\\/g, "\\\\").replace(/"/g, '\\"')}"`;
  const lines = [
    "# Generated by `bendo openapi --bend`. Do not edit; regenerate after route changes.",
    "import Base",
    "",
    ...chunks.flatMap((chunk, index) => [
      `def part${index}() -> String:`,
      `  ${literal(chunk)}`,
      "",
    ]),
    "def parts() -> List<&2, String>:",
    "  [",
    ...chunks.map((_, index) => `    part${index}(),`),
    "  ]",
    "",
    "def join(xs: List<&2, String>) -> String:",
    "  match xs:",
    '    case Nil{}: ""',
    "    case h <> t: h ++ join(t)",
    "",
    "# The OpenAPI document as JSON text.",
    "def json() -> String:",
    "  join(parts())",
    "",
  ];
  return lines.join("\n");
}
