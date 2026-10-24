import type { ErrorObject, ValidateFunction } from "ajv";
import { chainShape, shapes, type Step } from "./path.ts";
import type { BendoFieldError, HttpErrorBody, ResponseIssue } from "./types.ts";

/** One row of the generated `routes.schemas.ts`. */
export type ResponseSchema = boolean | { readonly [keyword: string]: unknown };
export type ResponseSchemaRow = {
  readonly method: string;
  readonly path: string;
  readonly all: boolean;
  readonly response?: ResponseSchema;
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

/**
 * The response schemas of every row the call could have reached. `undefined`
 * means at least one of them has no schema, so any body is acceptable.
 */
export function responseSchemas(
  table: ResponseSchemaTable,
  method: string,
  steps: readonly Step[],
): ResponseSchema[] | undefined {
  const shape = chainShape(steps).join("/");
  const schemas: ResponseSchema[] = [];
  for (const row of table) {
    if (!row.all && row.method !== method) continue;
    if (!shapes(row.path).some((candidate) => candidate.join("/") === shape)) continue;
    if (row.response === undefined) return undefined;
    schemas.push(row.response);
  }
  return schemas.length === 0 ? undefined : schemas;
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
  schemas: readonly ResponseSchema[],
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

async function check(schema: ResponseSchema, data: unknown): Promise<ResponseIssue[]> {
  if (schema === true) return [];
  if (schema === false)
    return [{ path: [], message: "the route's response schema accepts nothing" }];
  let validator = compiled.get(schema);
  if (validator === undefined) {
    try {
      validator = (await load()).compile(schema);
    } catch (error) {
      return [
        {
          path: [],
          message: `the response schema did not compile: ${error instanceof Error ? error.message : String(error)}`,
        },
      ];
    }
    compiled.set(schema, validator);
  }
  return validator(data) ? [] : issues(data, validator.errors ?? []);
}
