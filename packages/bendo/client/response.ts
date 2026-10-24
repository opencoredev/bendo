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
export type Expected = { kind: "any" } | { kind: "schemas"; schemas: readonly JsonSchema[] };

// A JSON number token; Bendo coerces only these (docs/data/schema.md#coercion-for-text-sources).
const NUMBER = /^(-?)([0-9]+)(?:\.([0-9]+))?(?:[eE]([+-]?[0-9]+))?$/;
const STRICT_NUMBER = /^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?$/;
// Bendo's lexical integer rule (`D.is_integer`): no fraction and no exponent.
const INTEGER = /^-?(0|[1-9][0-9]*)$/;
const FIRST_MATCH = "Bendo decodes with the first matching member";

/** An exact decimal: `0.digits × 10^exponent`, with `digits` free of leading and trailing zeros. */
type Decimal = { sign: -1 | 0 | 1; digits: string; exponent: bigint };

/** Index of the first character that is not "0" (a linear scan; a `/0+$/` regex backtracks quadratically). */
function firstNonZero(text: string): number {
  let i = 0;
  while (i < text.length && text[i] === "0") i++;
  return i;
}

/** One past the last character that is not "0". */
function lastNonZero(text: string): number {
  let i = text.length;
  while (i > 0 && text[i - 1] === "0") i--;
  return i;
}

function decimal(token: string): Decimal {
  const parts = NUMBER.exec(token);
  if (parts === null) return { sign: 0, digits: "", exponent: 0n };
  const whole = parts[2] ?? "";
  const all = whole + (parts[3] ?? "");
  const leading = firstNonZero(all);
  const digits = all.slice(leading, Math.max(leading, lastNonZero(all)));
  if (digits === "") return { sign: 0, digits, exponent: 0n };
  // BigInt keeps exponents such as 1e400 and 1e-99999999999999999999 exact.
  const exponent = BigInt(parts[4] ?? "0") + BigInt(whole.length - leading);
  return { sign: parts[1] === "-" ? -1 : 1, digits, exponent };
}

/** Compares two number tokens by exact value, as Bendo's `D.order` does. */
export function compareDecimal(a: string, b: string): -1 | 0 | 1 {
  const x = decimal(a);
  const y = decimal(b);
  if (x.sign !== y.sign) return x.sign < y.sign ? -1 : 1;
  if (x.sign === 0) return 0;
  let magnitude: -1 | 0 | 1 = 0;
  if (x.exponent !== y.exponent) magnitude = x.exponent < y.exponent ? -1 : 1;
  else {
    const width = Math.max(x.digits.length, y.digits.length);
    const p = x.digits.padEnd(width, "0");
    const q = y.digits.padEnd(width, "0");
    magnitude = p === q ? 0 : p < q ? -1 : 1;
  }
  const order = x.sign * magnitude;
  return order < 0 ? -1 : order > 0 ? 1 : 0;
}

/**
 * The exported bound as a token. The table holds it as a double, so a bound
 * beyond the double range is `Infinity` and leaves that side open, whatever
 * its sign: the client can't know the exact bound, and narrowing must not
 * exclude a row the server would admit.
 */
function within(token: string, bound: unknown, side: "minimum" | "maximum"): boolean {
  if (typeof bound !== "number" || !Number.isFinite(bound)) return true;
  const order = compareDecimal(token, String(bound));
  return side === "minimum" ? order >= 0 : order <= 0;
}

type Coerced = { ok: true; value: unknown } | { ok: false };

/**
 * Bendo's admission of a number capture: a JSON number token, lexical for an
 * integer schema, within the bounds by exact decimal order. The server keeps
 * the token, so this decides alone; the value returned for Ajv is only a
 * stand-in that passes the same numeric schema (`1e400` would be Infinity).
 */
function coerceNumber(schema: Record<string, unknown>, token: string): Coerced {
  const admitted =
    STRICT_NUMBER.test(token) &&
    (schema.type !== "integer" || INTEGER.test(token)) &&
    within(token, schema.minimum, "minimum") &&
    within(token, schema.maximum, "maximum");
  if (!admitted) return { ok: false };
  let value = Number(token);
  if (!Number.isFinite(value)) value = value > 0 ? Number.MAX_VALUE : -Number.MAX_VALUE;
  if (typeof schema.minimum === "number" && Number.isFinite(schema.minimum))
    value = Math.max(value, schema.minimum);
  if (typeof schema.maximum === "number" && Number.isFinite(schema.maximum))
    value = Math.min(value, schema.maximum);
  return { ok: true, value };
}

/** Bendo's text coercion of one scalar, read from the exported schema like `route-schema.ts` does. */
function coerceScalar(schema: unknown, value: string): Coerced {
  if (!record(schema)) return { ok: true, value };
  switch (schema.type) {
    case "number":
    case "integer":
      return coerceNumber(schema, value);
    case "boolean":
      return { ok: true, value: value === "true" ? true : value === "false" ? false : value };
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
  return { ok: true, value };
}

/** The params object the server decodes: each capture's text, coerced by its field schema. */
function paramsOf(
  schema: JsonSchema,
  steps: readonly Step[],
): { ok: true; params: Record<string, unknown> } | { ok: false } {
  const fields: unknown = record(schema) ? schema.properties : undefined;
  const entries: [string, unknown][] = [];
  for (const step of steps) {
    if (step.kind !== "capture") continue;
    const value = text(step.value) ?? "";
    const field =
      record(fields) && Object.hasOwn(fields, step.name) ? fields[step.name] : undefined;
    // Only a direct array field gathers its key into an array.
    const array = record(field) && field.type === "array";
    const coerced = coerceScalar(array ? field.items : field, value);
    if (!coerced.ok) return { ok: false };
    entries.push([step.name, array ? [coerced.value] : coerced.value]);
  }
  // fromEntries defines own properties, so a `__proto__` capture stays a key.
  return { ok: true, params: Object.fromEntries(entries) };
}

const BOUNDS = new Set(["minimum", "maximum", "exclusiveMinimum", "exclusiveMaximum"]);

/** A copy of `value` without numeric bounds that overflowed to ±Infinity, which leave their side open. */
function withoutOpenBounds(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(withoutOpenBounds);
  if (!record(value)) return value;
  return Object.fromEntries(
    Object.entries(value)
      .filter(
        ([key, item]) => !(BOUNDS.has(key) && typeof item === "number" && !Number.isFinite(item)),
      )
      .map(([key, item]) => [key, withoutOpenBounds(item)]),
  );
}

const opened = new WeakMap<object, JsonSchema>();

function openBounds(schema: JsonSchema): JsonSchema {
  if (!record(schema)) return schema;
  const cached = opened.get(schema);
  if (cached !== undefined) return cached;
  const copy = withoutOpenBounds(schema);
  const result: JsonSchema = record(copy) ? copy : schema;
  opened.set(schema, result);
  return result;
}

/** Whether the server's params check would admit the call's captures under `schema`. */
export async function admits(schema: JsonSchema, steps: readonly Step[]): Promise<boolean> {
  const params = paramsOf(schema, steps);
  return params.ok && (await check(openBounds(schema), params.params)).length === 0;
}

/**
 * The response schemas of every row that could have answered: the method and
 * step shape match. Params schemas only narrow: when some of those rows accept
 * the call's captures, only they count; when none do, all of them count,
 * because the server may not enforce the exported params schema (a separately
 * supplied export, `Validate.skip`, or middleware that answers first). `any`
 * means a counted row has no response schema, or no row describes the chain.
 */
export async function expected(
  table: ResponseSchemaTable,
  method: string,
  steps: readonly Step[],
): Promise<Expected> {
  const shape = chainShape(steps).join("/");
  const shaped: ResponseSchemaRow[] = [];
  const accepting: ResponseSchemaRow[] = [];
  for (const row of table) {
    if (!row.all && row.method !== method) continue;
    if (!shapes(row.path).some((candidate) => candidate.join("/") === shape)) continue;
    shaped.push(row);
    if (row.params === undefined || (await admits(row.params, steps))) accepting.push(row);
  }
  const candidates = accepting.length > 0 ? accepting : shaped;
  if (candidates.length === 0) return { kind: "any" };
  const schemas: JsonSchema[] = [];
  for (const row of candidates) {
    if (row.response === undefined) return { kind: "any" };
    schemas.push(row.response);
  }
  return { kind: "schemas", schemas };
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
