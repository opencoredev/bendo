# TanStack Query helpers

`bendo/query` turns a method of the [typed client](client.md) into options for
TanStack Query v5. Data types come from the route, query keys come from the
request, and failed results are thrown as typed errors so TanStack's error state
works.

```ts
import { useMutation, useQuery } from "@tanstack/react-query";
import { createClient } from "bendo/client";
import { mutationOptions, queryOptions } from "bendo/query";
import type { Routes } from "./.bendo/routes";
import { schemas } from "./.bendo/routes.schemas";

const api = createClient<Routes>("http://localhost:8787", { schemas });

function Todo({ id }: { id: number }) {
  const todo = useQuery(queryOptions(api.todos({ id }).get));
  const rename = useMutation(
    mutationOptions(api.todos({ id }).patch, { invalidates: [api.todos] }),
  );
  if (todo.isPending) return "Loading";
  if (todo.isError) return todo.error.kind === "http" ? `${todo.error.status}` : "Offline";
  return <button onClick={() => rename.mutate({ body: { title: "Renamed" } })}>{todo.data.title}</button>;
}
```

Install `@tanstack/react-query` 5.89 or later next to `bendo`. It is an optional
peer dependency: only `bendo/query` imports it.

> [!WARNING]
> Keys hold the path and the request, not the client. The base URL and the
> headers set in `createClient`, such as an `Authorization` header, are not part
> of any key. Give each server, and each signed-in user, its own `QueryClient`,
> or clear the cache (`queryClient.clear()`) when the user changes. Otherwise
> one client's queries can return data cached by another.

## Queries

`queryOptions(endpoint, input?, options?)` takes a client method, the input you
would pass to it, and any other `useQuery` options except `queryKey` and
`queryFn`:

```ts
queryOptions(api.todos.get, { query: { tag: ["home"] } }, { select: (todos) => todos.length, staleTime: 30_000 });
```

`input` is required exactly when the client call requires it, and it has no
`signal`: the query function passes TanStack's `signal` to `fetch`, so
`queryClient.cancelQueries` and unmounting abort the request. The result works
with `useQuery`, `useSuspenseQuery`, `queryClient.fetchQuery` and
`prefetchQuery`. Its `queryKey` carries the data type, so
`queryClient.getQueryData(queryKey(api.todos({ id }).get))` returns the todo
type.

A query resolves to the response of a `kind: "data"` result. Two results have no
data to cache, since TanStack refuses `undefined` as query data:

- A successful `HEAD` resolves to `null`, whether the server answered 200, 204
  or 205.
- Any other 204 or 205 is thrown as a `no-content` error. The route's response
  type promised a body, and resolving `null` instead would add `null` to the
  data of every query. Retrying will not change the answer, so leave
  `no-content` out of your `retry` policy (see [Errors](#errors)). Use a
  mutation for a request that may answer 204.

## Mutations

`mutationOptions(endpoint, options?)` takes a client method and any other
`useMutation` options except `mutationFn` and `mutationKey`. The variables are
the method's input, so `mutate({ body })` sends the body. A method without
required input takes `mutate()`. TanStack gives mutations no abort signal, so
the variables may carry one: `mutate({ body, signal })` passes it to `fetch`,
and aborting it fails the mutation with a `network` error. Captures are part of the endpoint, so build
the options per item: `mutationOptions(api.todos({ id }).delete)`.

A mutation resolves to the response, or to `undefined` when the server answered
204 or 205; the request succeeded either way. Its `mutationKey` is
`["bendo", ...path, { method }]`, for `useIsMutating` and `useMutationState`.

`invalidates` lists the nodes whose queries go stale on success, or computes
them from the response and variables:

```ts
mutationOptions(api.todos.post, {
  invalidates: (todo) => (todo === undefined ? [api.todos] : [api.todos, api.users({ id: todo.owner })]),
});
```

It runs after your own `onSuccess`, and the mutation stays pending until the
active queries have refetched, so `mutateAsync` resolves with fresh data on
screen. It needs the `QueryClient` that TanStack 5.89 passes to mutation
callbacks. Outside a mutation, `invalidate(queryClient, api.todos)` does the
same.

## Errors

Every failed result is thrown as a `BendoQueryError`: an `Error` named
`BendoQueryError` that also carries the client's result fields, so `kind`
narrows it like a [client result](client.md#results). The message names the
request, such as `GET /todos/7: 404 Not Found`.

| `kind` | Fields | When |
| --- | --- | --- |
| `http` | `status`, `error`, `response` | a status outside 200 to 299 |
| `invalid-response` | `status`, `issues`, `response` | a 2xx body that failed validation |
| `network` | `cause` | no response, including an abort |
| `request` | `cause` | the request could not be built, so nothing was sent |
| `no-content` | `status` (204 or 205), `response` | a query got no body; mutations never throw this |

A query's `error` is `BendoQueryError | null`. A mutation's is
`BendoMutationError | null`, the same type without `no-content`.
`isBendoQueryError(value)` checks a caught value. TanStack retries a failed
query three times by default; a request or 4xx error will fail again, so you may
want to retry only the others:

```ts
retry: (count, error) => count < 3 && (error.kind === "network" || (error.kind === "http" && error.status >= 500)),
```

## Query keys

A key is `"bendo"`, one part per path step, then the request:

```ts
queryKey(api.todos({ id: 1 }).get, { query: { tag: ["a", "b"], limit: 20 } });
// ["bendo", "todos", { ":id": "1" }, { method: "GET", query: [["limit", "20"], ["tag", ["a", "b"]]] }]
```

Static segments stay as text and each capture becomes `{ ":name": value }`. The
last part holds the method and whichever of `query`, `headers` and `body` the
request sends. Query and headers are `[name, value]` pairs and the body is JSON
text, never objects keyed by your field names: TanStack hashes keys by copying
object fields, which would drop a name like `__proto__` and let two requests
share a cache entry. Keys are built from what goes on the wire, so equal requests get
equal keys however their objects were built:

- Capture, query and header values are compared as the text they are sent as,
  so `{ id: 1 }` and `{ id: "1" }`, or `{ limit: 20 }` and `{ limit: "20" }`, share a key.
- Query and header names are sorted, header names are lowercased, and fields
  set to `undefined` or an empty array are left out.
- A one-item array and its single value share a key; items keep their order.
- The body is compared as its JSON text, with object keys sorted.
- Input the client refuses, such as a BigInt in the body, becomes
  `{ "!": reason }`. The request then fails with that reason either way.

A new input object on every render therefore keeps the same query and does not
refetch. Per-call headers are part of the key, so never pass a secret there that
should not sit in the cache; set it in `createClient` and follow the warning at
the top of this page.

`routeKey(node)` is the prefix key for everything below a node, for
`invalidateQueries`, `cancelQueries` and other filters:

| Call | Matches |
| --- | --- |
| `routeKey(api)` | every Bendo query |
| `routeKey(api.todos)` | every query under `/todos`, whatever its method, captures or input |
| `routeKey(api.todos({ id: 1 }))` | every query under `/todos/1` |
| `routeKey(api.todos({ id: 1 }).get)` | every GET of `/todos/1`, whatever its query |

A capture's object part keeps `/todos/:id` apart from a static `/todos/new`.
A value that did not come from `createClient` throws a `TypeError`.

## Types and tests

The helpers infer everything from the client method's type, so they add a
constant cost per call: `timeout 60s bun scripts/client-types-bench.ts 400 --query`
passes 400 routes through `queryOptions` with a `select` into `useQuery` and
through `mutationOptions` into `useMutation`. It checks in about 2.3 s (0.9 s for
100, 1.3 s for 200), against 0.76 s for the client calls alone. That works out
to about 2,640 type instantiations per route.

`packages/bendo/query/types.check.ts` holds the type tests that
`bun run typecheck` checks. `timeout 5m bun test --timeout 30000 packages/bendo/query`
renders the hooks in Happy DOM against the compiled client fixture. It checks
stable keys across re-renders, keys for names such as `__proto__`, thrown
errors, HEAD with 200, 204 and 205, signal pass-through for queries and
mutations, cancellation, and mutation invalidation.
