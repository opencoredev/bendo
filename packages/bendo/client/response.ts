import type { ErrorObject, ValidateFunction } from "ajv";
import { chainShape, shapes, text, type Step } from "./path.ts";
import type { BendoFieldError, HttpErrorBody, ResponseIssue } from "./types.ts";

/** A JSON Schema (draft 2020-12) as `bendo gen` prints it. */
export type JsonSchema = boolean | { readonly [keyword: string]: unknown };
/** One row of the generated `routes.schemas.ts`. */
export type ResponseSchemaRow = {
  readonly method: string;
  readonly path: string;
  readonly all: boolean;
  readonly params?: JsonSchema;
  readonly response?: JsonSchema;
};
export type ResponseSchemaTable = ReadonlyArray<ResponseSchemaRow>;

export type Parsed = { ok: true; value: unknown } | { ok: false; issue: ResponseIssue };

function record(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

export function parseJson(text: string): Parsed {
  try {
    const value: unknown = JSON.parse(text);
    return { ok: true, value };
  } catch (error) {
    return {
      ok: false,
      issue: {
        path: [],
        message: `body is not valid JSON: ${error instanceof Error ? error.message : String(error)}`,
      },
    };
  }
}

/** `application/json` or any `+json` media type, ignoring parameters and case. */
export function isJson(contentType: string | null): boolean {
  const media = contentType?.split(";")[0]?.trim().toLowerCase() ?? "";
  return (
    media === "application/json" || /^[a-z0-9!#$&^_.+-]+\/[a-z0-9!#$&^_.+-]+\+json$/.test(media)
  );
}

function fieldError(value: unknown): BendoFieldError | undefined {
  if (
    !record(value) ||
    typeof value.code !== "string" ||
    typeof value.message !== "string" ||
    !Array.isArray(value.path)
  )
    return undefined;
  const path: (string | number)[] = [];
  for (const segment of value.path) {
    if (typeof segment !== "string" && typeof segment !== "number") return undefined;
    path.push(segment);
  }
  return { path, code: value.code, message: value.message };
}

/** Bendo's `{error, status, errors?}` when the whole shape matches; otherwise the text. */
export function errorBody(text: string): HttpErrorBody {
  const parsed = parseJson(text);
  if (!parsed.ok) return { kind: "text", text };
  const value = parsed.value;
  if (!record(value) || typeof value.error !== "string" || typeof value.status !== "number")
    return { kind: "text", text };
  if (value.errors === undefined)
    return { kind: "bendo", error: value.error, status: value.status, errors: [] };
  if (!Array.isArray(value.errors)) return { kind: "text", text };
  const errors: BendoFieldError[] = [];
  for (const item of value.errors) {
    const error = fieldError(item);
    if (error === undefined) return { kind: "text", text };
    errors.push(error);
  }
  return { kind: "bendo", error: value.error, status: value.status, errors };
}

/** What a 2xx body is checked against. */
export type Expected =
  | { kind: "any" }
  | { kind: "schemas"; schemas: readonly JsonSchema[] }
  | { kind: "unreachable"; issue: ResponseIssue };

// A JSON number token; Bendo coerces only these (docs/data/schema.md#coercion-for-text-sources).
const NUMBER = /^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?$/;
const FIRST_MATCH = "Bendo decodes with the first matching member";

/** Bendo's text coercion of one scalar, read from the exported schema like `route-schema.ts` does. */
function coerceScalar(schema: unknown, value: string): unknown {
  if (!record(schema)) return value;
  switch (schema.type) {
    case "number":
    case "integer":
      return NUMBER.test(value) ? Number(value) : value;
    case "boolean":
      return value === "true" ? true : value === "false" ? false : value;
  }
  // A nullable coerces its inner schema; a union never coerces.
  const members: unknown = schema.anyOf;
  if (
    Array.isArray(members) &&
    members.length === 2 &&
    record(members[0]) &&
    members[0].type === "null" &&
    schema.$comment !== FIRST_MATCH
  )
    return coerceScalar(members[1], value);
  const parts: unknown = schema.allOf;
  if (Array.isArray(parts))
    for (const part of parts) {
      const coerced = coerceScalar(part, value);
      if (coerced !== value) return coerced;
    }
  return value;
}

/** The params object the server decodes: each capture's text, coerced by its field schema. */
function paramsOf(schema: JsonSchema, steps: readonly Step[]): Record<string, unknown> {
  const fields: unknown = record(schema) ? schema.properties : undefined;
  const params: Record<string, unknown> = {};
  for (const step of steps) {
    if (step.kind !== "capture") continue;
    const value = text(step.value) ?? "";
    const field =
      record(fields) && Object.hasOwn(fields, step.name) ? fields[step.name] : undefined;
    // Only a direct array field gathers its key into an array.
    params[step.name] =
      record(field) && field.type === "array"
        ? [coerceScalar(field.items, value)]
        : coerceScalar(field, value);
  }
  return params;
}

/**
 * The response schemas of every row that could have answered: the method and
 * step shape match, and the row's params schema accepts the call's captures.
 * `any` means one of them has no response schema, or no row describes the
 * chain at all.
 */
export async function expected(
  table: ResponseSchemaTable,
  method: string,
  steps: readonly Step[],
): Promise<Expected> {
  const shape = chainShape(steps).join("/");
  const schemas: JsonSchema[] = [];
  let shaped = false;
  for (const row of table) {
    if (!row.all && row.method !== method) continue;
    if (!shapes(row.path).some((candidate) => candidate.join("/") === shape)) continue;
    shaped = true;
    if (
      row.params !== undefined &&
      (await check(row.params, paramsOf(row.params, steps))).length > 0
    )
      continue;
    if (row.response === undefined) return { kind: "any" };
    schemas.push(row.response);
  }
  if (schemas.length > 0) return { kind: "schemas", schemas };
  if (!shaped) return { kind: "any" };
  return {
    kind: "unreachable",
    issue: { path: [], message: "no route at this path accepts the call's captures" },
  };
}

// Ajv generates code, so load it only when a client validates.
let ajv: Promise<{ compile: (schema: object) => ValidateFunction }> | undefined;
const compiled = new WeakMap<object, ValidateFunction>();

function load(): Promise<{ compile: (schema: object) => ValidateFunction }> {
  ajv ??= import("ajv/dist/2020.js").then(
    // The validator settings of docs/data/json-schema.md#validator-settings.
    ({ default: Ajv2020 }) => new Ajv2020({ strict: true, ownProperties: true, allErrors: true }),
  );
  return ajv;
}

/** Turns Ajv's JSON Pointer into keys and array indexes by walking the data. */
function pathOf(data: unknown, pointer: string): (string | number)[] {
  if (pointer === "") return [];
  const path: (string | number)[] = [];
  let node = data;
  for (const raw of pointer.slice(1).split("/")) {
    const key = raw.replaceAll("~1", "/").replaceAll("~0", "~");
    if (Array.isArray(node)) {
      const index = Number(key);
      path.push(index);
      node = node[index];
    } else {
      path.push(key);
      node = record(node) ? node[key] : undefined;
    }
  }
  return path;
}

function issues(data: unknown, errors: ErrorObject[]): ResponseIssue[] {
  return errors.map((error) => ({
    path: pathOf(data, error.instancePath),
    message: `${error.message ?? "is invalid"} (${error.keyword})`,
  }));
}

/** Issues against the first schema when no schema accepts the data. */
export async function validate(
  schemas: readonly JsonSchema[],
  data: unknown,
): Promise<ResponseIssue[]> {
  let first: ResponseIssue[] | undefined;
  for (const schema of schemas) {
    const found = await check(schema, data);
    if (found.length === 0) return [];
    first ??= found;
  }
  return first ?? [];
}

async function check(schema: JsonSchema, data: unknown): Promise<ResponseIssue[]> {
  if (schema === true) return [];
  if (schema === false) return [{ path: [], message: "the route's schema accepts nothing" }];
  let validator = compiled.get(schema);
  if (validator === undefined) {
    try {
      validator = (await load()).compile(schema);
    } catch (error) {
      return [
        {
          path: [],
          message: `the route's schema did not compile: ${error instanceof Error ? error.message : String(error)}`,
        },
      ];
    }
    compiled.set(schema, validator);
  }
  return validator(data) ? [] : issues(data, validator.errors ?? []);
}
