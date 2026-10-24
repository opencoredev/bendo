// TanStack Query helpers for the typed client (BND-60). Usage: docs/query.md.
import type {
  DataTag,
  MutationFunctionContext,
  QueryClient,
  UnusedSkipTokenOptions,
  UseMutationOptions,
  UseQueryOptions,
} from "@tanstack/react-query";
import { chainOf } from "../client/chain.ts";
import { headerEntries, methodOf, pathOf, text, textEntries, type Step } from "../client/path.ts";
import type { ClientResult, Method } from "../client/types.ts";

/** Any method of a client node, such as `api.todos({ id }).get`. */
// `never[]` parameters admit every endpoint, whatever its input.
export type AnyEndpoint = (...args: never[]) => Promise<ClientResult<unknown>>;

type Result<E extends AnyEndpoint> = Awaited<ReturnType<E>>;
/** The response type of a `kind: "data"` result. */
export type ResponseOf<E extends AnyEndpoint> = Extract<Result<E>, { kind: "data" }>["data"];
/** The endpoint's input, as a mutation's variables, `signal` included. */
type CallInput<E extends AnyEndpoint> = Parameters<E> extends [input?: infer I] ? I : never;
/** A query's input: the endpoint's without `signal`, which TanStack supplies. */
export type InputOf<E extends AnyEndpoint> = Omit<CallInput<E>, "signal">;
type Optional<E extends AnyEndpoint> = [] extends Parameters<E> ? true : false;

/**
 * What a query resolves to. TanStack refuses `undefined` as query data, so the
 * body-less success of a HEAD becomes `null`.
 */
export type QueryData<E extends AnyEndpoint> =
  undefined extends ResponseOf<E>
    ? unknown extends ResponseOf<E>
      ? unknown
      : Exclude<ResponseOf<E>, undefined> | null
    : ResponseOf<E>;
/** What a mutation resolves to: `undefined` when the server answered 204 or 205. */
export type MutationData<E extends AnyEndpoint> = ResponseOf<E> | undefined;
/**
 * `mutate()` takes no argument when the route has no required input. TanStack
 * gives a mutation no signal, so `mutate({ body, signal })` passes one to `fetch`.
 */
export type MutationVariables<E extends AnyEndpoint> =
  Optional<E> extends true ? CallInput<E> | void : CallInput<E>;

/** A failed client result, plus the 204 or 205 a query cannot cache. */
export type Failure =
  | Extract<ClientResult<unknown>, { ok: false }>
  | { ok: false; kind: "no-content"; status: 204 | 205; response: Response };

class BendoError extends Error {
  override name = "BendoQueryError";
}

/**
 * What a query or mutation throws: an `Error` carrying the client's failure,
 * so `error.kind` narrows to `http`, `network`, `request`, `invalid-response`
 * or, for queries, `no-content`.
 */
export type BendoQueryError = BendoError & Failure;
/** Mutations resolve a 204 or 205 to `undefined`, so they never throw `no-content`. */
export type BendoMutationError = Exclude<BendoQueryError, { kind: "no-content" }>;

export function isBendoQueryError(value: unknown): value is BendoQueryError {
  // Only `failure` below constructs a BendoError, and it always assigns one.
  return value instanceof BendoError;
}

/** A query key: `"bendo"`, one part per path step, then the request. */
export type BendoQueryKey = readonly ["bendo", ...KeyPart[]];
/** A static segment as text, a capture as `{ ":name": "value" }`, the request as `{ method, ... }`. */
export type KeyPart = string | { readonly [name: string]: unknown };

/** A key for a whole subtree or one endpoint: everything `invalidateQueries` should match. */
export type RouteKey = BendoQueryKey;

type Chain = { method: Method | undefined; path: readonly Step[] };

function chain(value: unknown): Chain {
  const steps = chainOf(value);
  if (steps === undefined)
    throw new TypeError("bendo/query takes a node or method of a client from createClient");
  const last = steps.at(-1);
  const method = last?.kind === "static" ? methodOf(last.name) : undefined;
  return { method, path: method === undefined ? steps : steps.slice(0, -1) };
}

function pathParts(steps: readonly Step[]): KeyPart[] {
  return steps.map((step) => {
    switch (step.kind) {
      case "static":
        return step.name;
      // `1` and `"1"` send the same URL, so they share a key.
      case "capture":
        return { [`:${step.name}`]: text(step.value) ?? step.value };
      case "invalid":
        return { "!": step.reason };
      default: {
        const exhaustive: never = step;
        return exhaustive;
      }
    }
  });
}

/**
 * Query and header entries as the client sends them, sorted by name. One value
 * stays text and several stay an array in order, so `{ tag: ["a"] }` and
 * `{ tag: "a" }` share a key. Entries are `[name, value]` pairs, not object
 * fields: TanStack's `hashKey` copies object fields into `{}`, where a name such
 * as `__proto__` would vanish and two different requests would share a key.
 */
function textKey(entries: readonly [string, string][]): [string, string | string[]][] {
  const grouped = new Map<string, string[]>();
  for (const [name, value] of entries) grouped.set(name, [...(grouped.get(name) ?? []), value]);
  return [...grouped.keys()].sort().map((name) => {
    const values = grouped.get(name) ?? [];
    return [name, values.length === 1 ? (values[0] ?? "") : values];
  });
}

/** JSON text with object keys sorted at every level. */
function canonicalText(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(canonicalText).join(",")}]`;
  if (typeof value !== "object" || value === null) return JSON.stringify(value);
  const fields = Object.keys(value)
    .sort()
    .map((name) => `${JSON.stringify(name)}:${canonicalText(Reflect.get(value, name))}`);
  return `{${fields.join(",")}}`;
}

/** The body as the client sends it: its JSON text, with object keys sorted. */
function bodyKey(body: unknown): string | { "!": string } {
  try {
    const json = JSON.stringify(body);
    // JSON.parse keeps `__proto__` as an own field, so the sort sees every name.
    if (typeof json === "string") return canonicalText(JSON.parse(json));
    return { "!": "body has no JSON form" };
  } catch (cause) {
    // BigInt values and cycles throw; the client refuses them the same way.
    return { "!": `body has no JSON form: ${String(cause)}` };
  }
}

function field(input: unknown, name: string): unknown {
  return typeof input === "object" && input !== null && name in input
    ? Reflect.get(input, name)
    : undefined;
}

/**
 * Input the client would refuse becomes `{ "!": reason }`. Such a request fails
 * with that same `request` error, so inputs with one reason may share a key.
 */
function requestPart(method: Method, input: unknown): KeyPart {
  const part: Record<string, unknown> = { method };
  const query = textEntries(field(input, "query"), "query");
  if (!query.ok) part.query = { "!": query.reason };
  else if (query.value.length > 0) part.query = textKey(query.value);
  const headers = headerEntries(field(input, "headers"));
  if (!headers.ok) part.headers = { "!": headers.reason };
  else if (headers.value.length > 0)
    part.headers = textKey(headers.value.map(([name, value]) => [name.toLowerCase(), value]));
  const body = field(input, "body");
  if (body !== undefined) part.body = bodyKey(body);
  return part;
}

function endpointChain(endpoint: unknown): { method: Method; path: readonly Step[] } {
  const { method, path } = chain(endpoint);
  if (method === undefined)
    throw new TypeError("bendo/query needs a method such as api.todos.get, not a path node");
  return { method, path };
}

function keyOf(endpoint: unknown, input: unknown): BendoQueryKey {
  const { method, path } = endpointChain(endpoint);
  return ["bendo", ...pathParts(path), requestPart(method, input)];
}

/**
 * The prefix key for everything below a node, or for one method of it:
 * `routeKey(api.todos)` matches every `/todos...` query and
 * `routeKey(api.todos({ id: 1 }).get)` every GET of that todo, whatever its query.
 */
export function routeKey(target: object): RouteKey {
  const { method, path } = chain(target);
  const parts = pathParts(path);
  return method === undefined ? ["bendo", ...parts] : ["bendo", ...parts, { method }];
}

function describe(failure: Failure): string {
  switch (failure.kind) {
    case "http":
      return failure.error.kind === "bendo"
        ? `${failure.status} ${failure.error.error}`
        : `HTTP ${failure.status}`;
    case "network":
      return `network error: ${String(failure.cause)}`;
    case "request":
      return `request not sent: ${String(failure.cause)}`;
    case "invalid-response":
      return `invalid response: ${failure.issues.map((issue) => issue.message).join("; ")}`;
    case "no-content":
      return `${failure.status} has no body to use as query data`;
    default: {
      const exhaustive: never = failure;
      return exhaustive;
    }
  }
}

function thrown(endpoint: unknown, failure: Failure): BendoQueryError {
  const { method, path } = endpointChain(endpoint);
  const url = pathOf(path);
  const where = `${method} ${url.ok ? url.value : "(invalid path)"}`;
  return Object.assign(new BendoError(`${where}: ${describe(failure)}`), failure);
}

type Fn = (input?: unknown) => Promise<ClientResult<unknown>>;

// Implementation signatures see each callback as a method. Method parameters
// compare bivariantly, so every typed overload stays compatible with them.
type Bivariant<T> = {
  [K in keyof T]: AsMethod<T[K]>;
};
type AsMethod<V> = V extends (...args: infer A) => infer R
  ? { method(...args: A): R }["method"]
  : V;

async function runQuery(
  endpoint: Fn,
  method: Method,
  input: unknown,
  signal: AbortSignal,
): Promise<unknown> {
  const result = await endpoint({ ...(typeof input === "object" ? input : {}), signal });
  if (!result.ok) throw thrown(endpoint, result);
  // A HEAD has no body, so a 204 or 205 is as good as a 200.
  if (method === "HEAD") return null;
  switch (result.kind) {
    case "data":
      return result.data === undefined ? null : result.data;
    case "no-content":
      throw thrown(endpoint, { ...result, ok: false });
    default: {
      const exhaustive: never = result;
      return exhaustive;
    }
  }
}

async function runMutation(endpoint: Fn, variables: unknown): Promise<unknown> {
  const result = await endpoint(variables ?? undefined);
  if (!result.ok) throw thrown(endpoint, result);
  return result.data;
}

/** Everything `useQuery` takes except the key and function this module derives. */
export type QueryExtras<E extends AnyEndpoint, TData> = Omit<
  UseQueryOptions<QueryData<E>, BendoQueryError, TData, BendoQueryKey>,
  "queryKey" | "queryFn"
>;
type QueryArgs<E extends AnyEndpoint, TData> =
  Optional<E> extends true
    ? [input?: InputOf<E>, options?: QueryExtras<E, TData>]
    : [input: InputOf<E>, options?: QueryExtras<E, TData>];
/** Query options with a key tagged with the data and error types, as TanStack's `queryOptions` returns. */
// This is the overload of TanStack's `queryOptions` without `initialData` or
// `skipToken`, so the result also suits `useSuspenseQuery`.
export type BendoQueryOptions<E extends AnyEndpoint, TData> = UnusedSkipTokenOptions<
  QueryData<E>,
  BendoQueryError,
  TData,
  BendoQueryKey
> & { queryKey: DataTag<BendoQueryKey, QueryData<E>, BendoQueryError> };

/**
 * Typed `useQuery` options for one endpoint call:
 * `useQuery(queryOptions(api.todos({ id }).get, { query }, { select }))`.
 * The key comes from the path and the request (see `queryKey`), TanStack's
 * `signal` reaches `fetch`, and every non-2xx or invalid result is thrown
 * as a `BendoQueryError`.
 */
export function queryOptions<E extends AnyEndpoint, TData = QueryData<E>>(
  endpoint: E,
  ...args: QueryArgs<E, TData>
): BendoQueryOptions<E, TData>;
export function queryOptions(
  endpoint: Fn,
  input?: unknown,
  options?: Omit<
    UseQueryOptions<unknown, BendoQueryError, unknown, BendoQueryKey>,
    "queryKey" | "queryFn"
  >,
): unknown {
  const { method } = endpointChain(endpoint);
  return {
    ...options,
    queryKey: keyOf(endpoint, input),
    queryFn: ({ signal }: { signal: AbortSignal }) => runQuery(endpoint, method, input, signal),
  };
}

/**
 * The exact key `queryOptions` uses: `["bendo", ...path, { method, query, headers, body }]`.
 * Capture, query and header values are compared as the text they are sent as,
 * query and header names are sorted, and header names are lowercased, so equal
 * requests have equal keys however their objects were built.
 */
export function queryKey<E extends AnyEndpoint>(
  endpoint: E,
  ...args: QueryArgs<E, QueryData<E>>
): BendoQueryOptions<E, QueryData<E>>["queryKey"];
export function queryKey(endpoint: Fn, input?: unknown): unknown {
  return keyOf(endpoint, input);
}

/** Nodes or methods whose queries a mutation refetches when it succeeds. */
export type Invalidates<E extends AnyEndpoint> =
  | readonly object[]
  | ((data: MutationData<E>, variables: MutationVariables<E>) => readonly object[]);

/** Refetch, or mark stale, every query below each target: `invalidate(client, api.todos)`. */
export async function invalidate(
  client: QueryClient,
  ...targets: readonly object[]
): Promise<void> {
  await Promise.all(
    targets.map((target) => client.invalidateQueries({ queryKey: routeKey(target) })),
  );
}

/** Everything `useMutation` takes except the function and key this module derives. */
export type MutationExtras<E extends AnyEndpoint, TOnMutateResult> = Omit<
  UseMutationOptions<MutationData<E>, BendoMutationError, MutationVariables<E>, TOnMutateResult>,
  "mutationFn" | "mutationKey"
> & {
  /** Queries to invalidate after success, once `onSuccess` has run. The mutation stays pending until they refetch. */
  invalidates?: Invalidates<E>;
};
export type BendoMutationOptions<E extends AnyEndpoint, TOnMutateResult> = UseMutationOptions<
  MutationData<E>,
  BendoMutationError,
  MutationVariables<E>,
  TOnMutateResult
> & { mutationKey: BendoQueryKey };

/**
 * Typed `useMutation` options for one endpoint: the variables are the call's
 * input (`{ body }`, `{ query }`, ...), `data` is the response or `undefined`
 * for a 204 or 205, and `invalidates` refetches the listed nodes on success:
 * `useMutation(mutationOptions(api.todos.post, { invalidates: [api.todos] }))`.
 */
export function mutationOptions<E extends AnyEndpoint, TOnMutateResult = unknown>(
  endpoint: E,
  options?: MutationExtras<E, TOnMutateResult>,
): BendoMutationOptions<E, TOnMutateResult>;
export function mutationOptions(
  endpoint: Fn,
  options?: Bivariant<MutationExtras<Fn, unknown>>,
): unknown {
  const { method, path } = endpointChain(endpoint);
  const { invalidates, onSuccess, ...rest } = options ?? {};
  return {
    ...rest,
    mutationKey: ["bendo", ...pathParts(path), { method }],
    mutationFn: (variables: MutationVariables<Fn>) => runMutation(endpoint, variables),
    onSuccess: async (
      data: unknown,
      variables: MutationVariables<Fn>,
      onMutateResult: unknown,
      context: MutationFunctionContext,
    ) => {
      await onSuccess?.(data, variables, onMutateResult, context);
      const targets =
        typeof invalidates === "function" ? invalidates(data, variables) : invalidates;
      if (targets !== undefined) await invalidate(context.client, ...targets);
    },
  };
}
