// The typed client (BND-57). Usage and result kinds: docs/client.md.
import { captureStep, headerEntries, pathOf, textEntries, type Built, type Step } from "./path.ts";
import {
  errorBody,
  expected,
  isJson,
  parseJson,
  validate,
  type Expected,
  type ResponseSchemaTable,
} from "./response.ts";
import type { Client, ClientResult, Method, MethodKey, RouteRecord } from "./types.ts";

export type {
  BendoFieldError,
  Client,
  ClientResult,
  Endpoint,
  HeaderField,
  HeaderRecord,
  HttpErrorBody,
  Method,
  MethodKey,
  RequestInput,
  ResponseIssue,
  RouteRecord,
  TextField,
  TextRecord,
  TextValue,
} from "./types.ts";
export type { JsonSchema, ResponseSchemaRow, ResponseSchemaTable } from "./response.ts";

/** The part of `fetch` the client calls; inject one to add auth, retries or a test transport. */
export type Fetch = (input: string, init: RequestInit) => Promise<Response>;

/** Pass the generated `schemas` to validate 2xx bodies; `validate: false` switches it off. */
export type Validation =
  | { schemas: ResponseSchemaTable; validate?: boolean }
  | { schemas?: never; validate?: never };

export type ClientOptions = {
  fetch?: Fetch;
  /** Sent with every request; a call's own headers replace these by name. */
  headers?: HeadersInit;
} & Validation;

const METHODS: Record<MethodKey, Method> = {
  get: "GET",
  head: "HEAD",
  post: "POST",
  put: "PUT",
  delete: "DELETE",
  options: "OPTIONS",
  patch: "PATCH",
};

function methodOf(name: string): Method | undefined {
  for (const [key, method] of Object.entries(METHODS)) if (key === name) return method;
  return undefined;
}

type Settings = {
  base: string;
  fetch: Fetch;
  headers: HeadersInit | undefined;
  schemas: ResponseSchemaTable | undefined;
};

type Input = {
  query: unknown;
  headers: unknown;
  body: unknown;
  signal: AbortSignal | undefined;
};

/** The call's argument as the types describe it; anything else is a request error. */
function inputOf(value: unknown): Built<Input> {
  if (value === undefined)
    return {
      ok: true,
      value: { query: undefined, headers: undefined, body: undefined, signal: undefined },
    };
  if (typeof value !== "object" || value === null || Array.isArray(value))
    return { ok: false, reason: "a method call takes { query, headers, body, signal }" };
  const signal = "signal" in value ? value.signal : undefined;
  if (signal !== undefined && !(signal instanceof AbortSignal))
    return { ok: false, reason: "signal must be an AbortSignal" };
  return {
    ok: true,
    value: {
      query: "query" in value ? value.query : undefined,
      headers: "headers" in value ? value.headers : undefined,
      body: "body" in value ? value.body : undefined,
      signal,
    },
  };
}

function jsonText(value: unknown): Built<string> {
  try {
    const body: unknown = JSON.stringify(value);
    return typeof body === "string"
      ? { ok: true, value: body }
      : { ok: false, reason: "body has no JSON form" };
  } catch (cause) {
    // BigInt values and cycles throw.
    return { ok: false, reason: `body has no JSON form: ${String(cause)}` };
  }
}

function requestOf(
  settings: Settings,
  method: Method,
  steps: readonly Step[],
  input: Input,
): Built<[string, RequestInit]> {
  const path = pathOf(steps);
  if (!path.ok) return path;
  const query = textEntries(input.query, "query");
  if (!query.ok) return query;
  const fields = headerEntries(input.headers);
  if (!fields.ok) return fields;
  const headers = new Headers(settings.headers);
  // Bendo renders errors as JSON only for an explicit JSON Accept (BND-25).
  if (!headers.has("accept")) headers.set("accept", "application/json");
  for (const [name] of fields.value) headers.delete(name);
  for (const [name, value] of fields.value) headers.append(name, value);
  const init: RequestInit = { method, headers };
  if (input.signal !== undefined) init.signal = input.signal;
  if (input.body !== undefined) {
    const body = jsonText(input.body);
    if (!body.ok) return body;
    init.body = body.value;
    if (!headers.has("content-type")) headers.set("content-type", "application/json");
  }
  const search = new URLSearchParams(query.value).toString();
  return {
    ok: true,
    value: [`${settings.base}${path.value}${search === "" ? "" : `?${search}`}`, init],
  };
}

async function request(
  settings: Settings,
  method: Method,
  steps: readonly Step[],
  argument: unknown,
): Promise<ClientResult<unknown>> {
  let built: Built<[string, RequestInit]>;
  try {
    const input = inputOf(argument);
    built = input.ok ? requestOf(settings, method, steps, input.value) : input;
  } catch (cause) {
    // new Headers throws on a name or value that HTTP cannot carry.
    return { ok: false, kind: "request", cause };
  }
  if (!built.ok) return { ok: false, kind: "request", cause: new TypeError(built.reason) };
  try {
    const response = await settings.fetch(...built.value);
    const status = response.status;
    const text = await response.text();
    if (!response.ok) return { ok: false, kind: "http", status, error: errorBody(text), response };
    // 204 has no body whatever its Content-Type says, and Bendo never checks it.
    if (status === 204) return { ok: true, kind: "no-content", status, data: undefined, response };
    // Neither has a HEAD response.
    if (method === "HEAD") return { ok: true, kind: "data", status, data: undefined, response };
    const json = isJson(response.headers.get("content-type"));
    const parsed = json ? parseJson(text) : { ok: true as const, value: text };
    if (!parsed.ok)
      return { ok: false, kind: "invalid-response", status, issues: [parsed.issue], response };
    const expect: Expected =
      settings.schemas === undefined
        ? { kind: "any" }
        : await expected(settings.schemas, method, steps);
    switch (expect.kind) {
      case "any":
        break;
      case "unreachable":
        return { ok: false, kind: "invalid-response", status, issues: [expect.issue], response };
      case "schemas": {
        if (!json) {
          const type = response.headers.get("content-type") ?? "none";
          return {
            ok: false,
            kind: "invalid-response",
            status,
            issues: [{ path: [], message: `expected a JSON response, got content-type ${type}` }],
            response,
          };
        }
        const issues = await validate(expect.schemas, parsed.value);
        if (issues.length > 0)
          return { ok: false, kind: "invalid-response", status, issues, response };
        break;
      }
      default: {
        const exhaustive: never = expect;
        return exhaustive;
      }
    }
    return { ok: true, kind: "data", status, data: parsed.value, response };
  } catch (cause) {
    return { ok: false, kind: "network", cause };
  }
}

function node(settings: Settings, steps: readonly Step[]): unknown {
  return new Proxy(() => undefined, {
    get(_target, property) {
      // `then` would make every node look like a promise to `await`.
      if (typeof property === "symbol" || property === "then") return undefined;
      return node(settings, [...steps, { kind: "static", name: property }]);
    },
    apply(_target, _this, args: unknown[]) {
      const last = steps.at(-1);
      const method = last?.kind === "static" ? methodOf(last.name) : undefined;
      if (method !== undefined) return request(settings, method, steps.slice(0, -1), args[0]);
      return node(settings, [...steps, captureStep(args[0])]);
    },
  });
}

/**
 * A client for a generated `Routes` union: `api.todos({ id }).get()`.
 * Calls resolve to a `ClientResult` and never reject.
 */
export function createClient<Routes extends RouteRecord>(
  baseUrl: string | URL,
  options?: ClientOptions,
): Client<Routes>;
// The proxy accepts every chain; the overload is the one place its type is stated.
export function createClient(baseUrl: string | URL, options: ClientOptions = {}): unknown {
  // Query and fragment are dropped; a path prefix such as /api is kept.
  const url = new URL(baseUrl);
  return node(
    {
      base: `${url.origin}${url.pathname.replace(/\/+$/, "")}`,
      fetch: options.fetch ?? ((input, init) => fetch(input, init)),
      headers: options.headers,
      schemas: options.validate === false ? undefined : options.schemas,
    },
    [],
  );
}
