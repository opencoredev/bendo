---
module: bendo/query
---

# bendo/query

Options for TanStack Query v5, built from methods of the
[typed client](client.md). [TanStack Query helpers](../../query.md) explains
keys, errors and invalidation in depth. Install `@tanstack/react-query` 5.89 or
later next to `bendo`; only this entry point imports it.

Keys hold the path and the request, not the client, so the base URL and the
client's default headers are not part of any key. Give each server and each
signed-in user its own `QueryClient`.

## Queries

### `queryOptions`

```ts signature
function queryOptions<E extends AnyEndpoint, TData = QueryData<E>>(
  endpoint: E,
  ...args: QueryArgs<E, TData>
): BendoQueryOptions<E, TData>;

// Not exported. `Optional<E>` is true when the endpoint can be called
// without input, so `input` is required exactly when the method requires it.
type QueryArgs<E, TData> =
  Optional<E> extends true
    ? [input?: InputOf<E>, options?: QueryExtras<E, TData>]
    : [input: InputOf<E>, options?: QueryExtras<E, TData>];
```

Typed `useQuery` options for one call of `endpoint`, a client method such as
`api.todos({ id }).get`. `input` is what you would pass to the method, minus
`signal`, and is required exactly when the method requires it. The query
function passes TanStack's `signal` to `fetch` and throws every failed result
as a `BendoQueryError`. A 204 or 205 to anything but `HEAD` is thrown as
`no-content`. A value that is not a client method throws a `TypeError`.

```ts
import { useQuery } from "@tanstack/react-query";
import { createClient } from "bendo/client";
import { queryOptions } from "bendo/query";
import type { Routes } from "./.bendo/routes";

const api = createClient<Routes>("http://localhost:8787");

export function useTodoTitle(id: number): string {
  const todo = useQuery(queryOptions(api.todos({ id }).get, undefined, { staleTime: 30_000 }));
  if (todo.isPending) return "Loading";
  if (todo.isError) return todo.error.kind === "http" ? `HTTP ${todo.error.status}` : "Offline";
  return todo.data.title;
}
```

### `BendoQueryOptions`, `QueryExtras`

```ts signature
type QueryExtras<E extends AnyEndpoint, TData> = Omit<
  UseQueryOptions<QueryData<E>, BendoQueryError, TData, BendoQueryKey>,
  "queryKey" | "queryFn"
>;
type BendoQueryOptions<E extends AnyEndpoint, TData> = UnusedSkipTokenOptions<
  QueryData<E>, BendoQueryError, TData, BendoQueryKey
> & { queryKey: DataTag<BendoQueryKey, QueryData<E>, BendoQueryError> };
```

`QueryExtras` is every `useQuery` option except the key and function, such as
`select`, `staleTime` or `retry`. `BendoQueryOptions` is what `queryOptions`
returns: the same overload as TanStack's own `queryOptions` without
`initialData` or `skipToken`, so it also suits `useSuspenseQuery`,
`fetchQuery` and `prefetchQuery`. Its key is tagged with the data type, so
`getQueryData` with it is typed.

```ts
import { createClient } from "bendo/client";
import { queryOptions, type BendoQueryOptions, type QueryExtras } from "bendo/query";
import type { Routes } from "./.bendo/routes";

const api = createClient<Routes>("http://localhost:8787");
const getTodo = api.todos({ id: 1 }).get;

const extras: QueryExtras<typeof getTodo, string> = { select: (todo) => todo.title };
const options: BendoQueryOptions<typeof getTodo, string> = queryOptions(getTodo, undefined, extras);
```

### `QueryData`

```ts signature
type QueryData<E extends AnyEndpoint> =
  undefined extends ResponseOf<E>
    ? unknown extends ResponseOf<E> ? unknown : Exclude<ResponseOf<E>, undefined> | null
    : ResponseOf<E>;
```

What a query for `E` resolves to: the route's response type. TanStack refuses
`undefined` as query data, so a response type that includes `undefined`, such
as a `HEAD`'s, has it replaced by `null`.

```ts
import { QueryClient } from "@tanstack/react-query";
import { createClient } from "bendo/client";
import { queryKey, type QueryData } from "bendo/query";
import type { Routes } from "./.bendo/routes";

const api = createClient<Routes>("http://localhost:8787");
const queryClient = new QueryClient();
const getTodo = api.todos({ id: 1 }).get;

const cached: QueryData<typeof getTodo> | undefined = queryClient.getQueryData(queryKey(getTodo));
if (cached !== undefined) console.log(cached.title);
```

## Mutations

### `mutationOptions`

```ts signature
function mutationOptions<E extends AnyEndpoint, TOnMutateResult = unknown>(
  endpoint: E,
  options?: MutationExtras<E, TOnMutateResult>,
): BendoMutationOptions<E, TOnMutateResult>;
```

Typed `useMutation` options for a client method. The variables are the
method's input, so `mutate({ body })` sends the body, and they may carry a
`signal`. A mutation resolves to the response, or to `undefined` for a 204 or
205. Its `mutationKey` is `["bendo", ...path, { method }]`. Captures are part
of the method, so build the options per item.

```ts
import { useMutation } from "@tanstack/react-query";
import { createClient } from "bendo/client";
import { mutationOptions } from "bendo/query";
import type { Routes } from "./.bendo/routes";

const api = createClient<Routes>("http://localhost:8787");

export function useAddTodo(): (title: string) => void {
  const add = useMutation(mutationOptions(api.todos.post, { invalidates: [api.todos] }));
  return (title) => add.mutate({ body: { title } });
}
```

### `BendoMutationOptions`, `MutationExtras`

```ts signature
type MutationExtras<E extends AnyEndpoint, TOnMutateResult> = Omit<
  UseMutationOptions<MutationData<E>, BendoMutationError, MutationVariables<E>, TOnMutateResult>,
  "mutationFn" | "mutationKey"
> & { invalidates?: Invalidates<E> };
type BendoMutationOptions<E extends AnyEndpoint, TOnMutateResult> = UseMutationOptions<
  MutationData<E>, BendoMutationError, MutationVariables<E>, TOnMutateResult
> & { mutationKey: BendoQueryKey };
```

`MutationExtras` is every `useMutation` option except the function and key,
plus `invalidates`. Your `onSuccess` runs first, then the invalidation, and the
mutation stays pending until the active queries have refetched.
`BendoMutationOptions` is what `mutationOptions` returns.

```ts
import { createClient } from "bendo/client";
import { mutationOptions, type BendoMutationOptions, type MutationExtras } from "bendo/query";
import type { Routes } from "./.bendo/routes";

const api = createClient<Routes>("http://localhost:8787");
const create = api.todos.post;

const extras: MutationExtras<typeof create, unknown> = {
  onSuccess: (todo) => console.log("created", todo?.id),
  invalidates: [api.todos],
};
const options: BendoMutationOptions<typeof create, unknown> = mutationOptions(create, extras);
```

### `MutationData`, `MutationVariables`

```ts signature
type MutationData<E extends AnyEndpoint> = ResponseOf<E> | undefined;
type MutationVariables<E extends AnyEndpoint> =
  [] extends Parameters<E> ? CallInput<E> | void : CallInput<E>;
```

A mutation's data and variables. `MutationData` is the response or
`undefined`, for a 204 or 205. `MutationVariables` is the method's full input,
`signal` included; when the method has no required input it also admits
`void`, so `mutate()` takes no argument.

```ts
import { createClient } from "bendo/client";
import type { MutationData, MutationVariables } from "bendo/query";
import type { Routes } from "./.bendo/routes";

const api = createClient<Routes>("http://localhost:8787");
type Create = typeof api.todos.post;

const variables: MutationVariables<Create> = { body: { title: "Write docs" }, signal: AbortSignal.timeout(5_000) };
function onCreated(todo: MutationData<Create>): string {
  return todo === undefined ? "created" : `created #${todo.id}`;
}
```

### `Invalidates`

```ts signature
type Invalidates<E extends AnyEndpoint> =
  | readonly object[]
  | ((data: MutationData<E>, variables: MutationVariables<E>) => readonly object[]);
```

The `invalidates` option: client nodes or methods whose queries go stale when
the mutation succeeds, or a function that picks them from the response and
variables. Each target is matched with `routeKey`.

```ts
import { createClient } from "bendo/client";
import { mutationOptions, type Invalidates } from "bendo/query";
import type { Routes } from "./.bendo/routes";

const api = createClient<Routes>("http://localhost:8787");

const stale: Invalidates<typeof api.todos.post> = (todo) =>
  todo === undefined ? [api.todos] : [api.todos, api.todos({ id: todo.id })];
const options = mutationOptions(api.todos.post, { invalidates: stale });
```

### `invalidate`

```ts signature
function invalidate(client: QueryClient, ...targets: readonly object[]): Promise<void>;
```

Calls `client.invalidateQueries` with `routeKey(target)` for each target, in
parallel, and resolves once they finish. This is what `invalidates` does inside
a mutation, for use outside one.

```ts
import { QueryClient } from "@tanstack/react-query";
import { createClient } from "bendo/client";
import { invalidate } from "bendo/query";
import type { Routes } from "./.bendo/routes";

const api = createClient<Routes>("http://localhost:8787");
const queryClient = new QueryClient();

await invalidate(queryClient, api.todos, api.echo);
```

## Keys

### `queryKey`

```ts signature
function queryKey<E extends AnyEndpoint>(
  endpoint: E,
  ...args: QueryArgs<E, QueryData<E>>
): BendoQueryOptions<E, QueryData<E>>["queryKey"];
```

The exact key `queryOptions` gives the same call:
`["bendo", ...path, { method, query?, headers?, body? }]`. Values are keyed as
the text they are sent as, query and header names are sorted, header names are
lowercased and the body is its JSON text with sorted keys, so equal requests
have equal keys. [Query keys](../../query.md#query-keys) lists every rule.

```ts
import { createClient } from "bendo/client";
import { queryKey } from "bendo/query";
import type { Routes } from "./.bendo/routes";

const api = createClient<Routes>("http://localhost:8787");

const key = queryKey(api.todos({ id: 1 }).get);
// ["bendo", "todos", { ":id": "1" }, { method: "GET" }]
```

### `routeKey`, `RouteKey`

```ts signature
type RouteKey = BendoQueryKey;
function routeKey(target: object): RouteKey;
```

The prefix key for everything below a client node, or for one method of it,
for `invalidateQueries`, `cancelQueries` and other filters. `routeKey(api)`
matches every Bendo query; `routeKey(api.todos({ id: 1 }).get)` matches every
GET of `/todos/1`, whatever its input. A value that did not come from
`createClient` throws a `TypeError`.

```ts
import { QueryClient } from "@tanstack/react-query";
import { createClient } from "bendo/client";
import { routeKey, type RouteKey } from "bendo/query";
import type { Routes } from "./.bendo/routes";

const api = createClient<Routes>("http://localhost:8787");
const queryClient = new QueryClient();

const todos: RouteKey = routeKey(api.todos);
await queryClient.cancelQueries({ queryKey: todos });
```

### `BendoQueryKey`, `KeyPart`

```ts signature
type BendoQueryKey = readonly ["bendo", ...KeyPart[]];
type KeyPart = string | { readonly [name: string]: unknown };
```

The shape of every key this module builds. A static segment is its text, a
capture is `{ ":name": "value" }`, and the last part of a query key is the
request object. Input the client would refuse becomes `{ "!": reason }`.

```ts
import type { BendoQueryKey, KeyPart } from "bendo/query";

const capture: KeyPart = { ":id": "1" };
const key: BendoQueryKey = ["bendo", "todos", capture, { method: "GET" }];
```

## Errors

### `BendoQueryError`, `BendoMutationError`

```ts signature
type BendoQueryError = Error & Failure;
type BendoMutationError = Exclude<BendoQueryError, { kind: "no-content" }>;
```

What queries and mutations throw: an `Error` named `BendoQueryError` that also
carries the failed client result's fields, so `kind` narrows it. The message
names the request, such as `GET /todos/7: 404 Not Found`. A query's `error` is
`BendoQueryError | null`; a mutation's is `BendoMutationError | null`, which
has no `no-content`. The [errors table](../../query.md#errors) lists each kind.

```ts
import { createClient } from "bendo/client";
import { queryOptions, type BendoMutationError, type BendoQueryError } from "bendo/query";
import type { Routes } from "./.bendo/routes";

const api = createClient<Routes>("http://localhost:8787");

function worthRetrying(count: number, error: BendoQueryError): boolean {
  return count < 3 && (error.kind === "network" || (error.kind === "http" && error.status >= 500));
}
const options = queryOptions(api.todos({ id: 1 }).get, undefined, { retry: worthRetrying });

function statusOf(error: BendoMutationError): number | undefined {
  return error.kind === "http" || error.kind === "invalid-response" ? error.status : undefined;
}
```

### `Failure`

```ts signature
type Failure =
  | Extract<ClientResult<unknown>, { ok: false }>
  | { ok: false; kind: "no-content"; status: 204 | 205; response: Response };
```

The result fields a `BendoQueryError` carries: any failed
[client result](client.md#clientresult), plus the 204 or 205 a query cannot
cache.

```ts
import type { Failure } from "bendo/query";

function summary(failure: Failure): string {
  switch (failure.kind) {
    case "http":
    case "invalid-response":
    case "no-content":
      return `status ${failure.status}`;
    case "network":
    case "request":
      return String(failure.cause);
    default: {
      const exhaustive: never = failure;
      return exhaustive;
    }
  }
}
```

### `isBendoQueryError`

```ts signature
function isBendoQueryError(value: unknown): value is BendoQueryError;
```

Whether a caught value was thrown by this module's query or mutation
functions. Use it around `fetchQuery` or `mutateAsync`, where the error is
`unknown`.

```ts
import { QueryClient } from "@tanstack/react-query";
import { createClient } from "bendo/client";
import { isBendoQueryError, queryOptions } from "bendo/query";
import type { Routes } from "./.bendo/routes";

const api = createClient<Routes>("http://localhost:8787");
const queryClient = new QueryClient();

try {
  await queryClient.fetchQuery(queryOptions(api.todos({ id: 1 }).get));
} catch (error) {
  if (isBendoQueryError(error) && error.kind === "http" && error.status === 404) console.log("no such todo");
  else throw error;
}
```

## Endpoint types

### `AnyEndpoint`, `ResponseOf`, `InputOf`

```ts signature
type AnyEndpoint = (...args: never[]) => Promise<ClientResult<unknown>>;
type ResponseOf<E extends AnyEndpoint> = Extract<Awaited<ReturnType<E>>, { kind: "data" }>["data"];
type InputOf<E extends AnyEndpoint> = Omit<CallInput<E>, "signal">;
```

Types read from a client method. `AnyEndpoint` admits every method of every
node. `ResponseOf` is the `data` of its `kind: "data"` result, and `InputOf`
its input without `signal`, as `queryOptions` takes it. Use them to write your
own helpers over client methods.

```ts
import { createClient } from "bendo/client";
import type { AnyEndpoint, InputOf, ResponseOf } from "bendo/query";
import type { Routes } from "./.bendo/routes";

const api = createClient<Routes>("http://localhost:8787");

type Todo = ResponseOf<typeof api.todos.post>; // { done: boolean; id: number; title: string }
const input: InputOf<typeof api.todos.post> = { body: { title: "Write docs" } };
const watched: AnyEndpoint[] = [api.todos.post, api.todos({ id: 1 }).get];
```
