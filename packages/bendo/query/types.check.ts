// Type tests for bendo/query, checked by `bun run typecheck`. Each
// `@ts-expect-error` must fail to compile; the other lines must compile.
// Nothing here runs: the hooks are only called inside uncalled functions.
import { QueryClient, useMutation, useQuery, useSuspenseQuery } from "@tanstack/react-query";
import { createClient } from "../client/index.ts";
import type { Routes } from "../client/fixture/routes.ts";
import {
  invalidate,
  isBendoQueryError,
  mutationOptions,
  queryKey,
  queryOptions,
  routeKey,
  type BendoMutationError,
  type BendoQueryError,
  type BendoQueryKey,
} from "./index.ts";

type Equal<A, B> =
  (<T>() => T extends A ? 1 : 2) extends <T>() => T extends B ? 1 : 2 ? true : false;
function expectType<T extends true>(value: T): T {
  return value;
}

type Todo = { done: boolean; id: number; title: string };
const api = createClient<Routes>("http://127.0.0.1:8787");
const client = new QueryClient();

export function queries(): void {
  // The response type flows into `data`, which is undefined until the query resolves.
  const todo = useQuery(queryOptions(api.todos({ id: 1 }).get));
  expectType<Equal<typeof todo.data, Todo | undefined>>(true);
  if (todo.isSuccess) expectType<Equal<typeof todo.data, Todo>>(true);
  // @ts-expect-error data may be undefined before success
  void todo.data.title;

  // `select` receives the response and decides `data`.
  const title = useQuery(
    queryOptions(api.todos({ id: 1 }).get, undefined, {
      select: (data) => {
        expectType<Equal<typeof data, Todo>>(true);
        return data.title;
      },
      staleTime: 1000,
    }),
  );
  expectType<Equal<typeof title.data, string | undefined>>(true);
  queryOptions(api.todos({ id: 1 }).get, undefined, {
    // @ts-expect-error the response has no `name`
    select: (data) => data.name,
  });

  // The error is the client's failure, narrowed by `kind`.
  expectType<Equal<typeof todo.error, BendoQueryError | null>>(true);
  const error = todo.error;
  if (error !== null) {
    const message: string = error.message;
    switch (error.kind) {
      case "http": {
        const status: number = error.status;
        if (error.error.kind === "bendo") error.error.errors.map((item) => item.path);
        void [message, status];
        break;
      }
      case "invalid-response":
        error.issues.map((issue) => issue.message);
        break;
      case "no-content": {
        const status: 204 | 205 = error.status;
        void status;
        break;
      }
      case "network":
      case "request":
        void error.cause;
        // @ts-expect-error only http and invalid-response carry a response
        void error.response;
        break;
      default: {
        const exhaustive: never = error;
        void exhaustive;
      }
    }
  }

  // Required input stays required, and its fields are checked.
  const echo = api.echo({ name: "a" })({ rest: "b/c" }).get;
  const echoed = useQuery(queryOptions(echo, { headers: { "x-token": "t" }, query: { n: 2 } }));
  expectType<
    Equal<
      typeof echoed.data,
      | { extra: string; name: string; rest: string; tags: string[]; token: string; url: string }
      | undefined
    >
  >(true);
  // @ts-expect-error x-token is required
  queryOptions(echo);
  // @ts-expect-error x-token is required
  queryOptions(echo, {});
  // @ts-expect-error n must be a number
  queryOptions(echo, { headers: { "x-token": "t" }, query: { n: true } });
  // @ts-expect-error TanStack supplies the signal
  queryOptions(api.todos({ id: 1 }).get, { signal: new AbortController().signal });

  // A HEAD has no body; TanStack refuses undefined data, so it resolves to null.
  const head = useQuery(queryOptions(api.any.head));
  expectType<Equal<typeof head.data, null | undefined>>(true);
  // A route without a response schema has unknown data.
  const untyped = useQuery(queryOptions(api.int({ i: 1 }).get));
  expectType<Equal<typeof untyped.data, unknown>>(true);

  // docs/query.md's retry policy reads the typed error.
  queryOptions(api.todos({ id: 1 }).get, undefined, {
    retry: (count, error) =>
      count < 3 && (error.kind === "network" || (error.kind === "http" && error.status >= 500)),
  });

  // The same options work with suspense, where data is always defined.
  const suspended = useSuspenseQuery(queryOptions(api.todos({ id: 1 }).get));
  expectType<Equal<typeof suspended.data, Todo>>(true);

  // The key carries the data type into the cache API.
  const key = queryKey(api.todos({ id: 1 }).get);
  expectType<Equal<ReturnType<typeof client.getQueryData<Todo, typeof key>>, Todo | undefined>>(
    true,
  );
  const cached = client.getQueryData(key);
  expectType<Equal<typeof cached, Todo | undefined>>(true);
  client.setQueryData(key, { done: true, id: 1, title: "x" });
  // @ts-expect-error the cache holds todos under this key
  client.setQueryData(key, { id: "1" });
  const keyed: BendoQueryKey = queryOptions(api.todos({ id: 1 }).get).queryKey;
  void keyed;
}

export function mutations(): void {
  const create = useMutation(
    mutationOptions(api.todos.post, {
      invalidates: (data, variables) => {
        expectType<Equal<typeof data, Todo | undefined>>(true);
        expectType<Equal<typeof variables.body, { done?: boolean; title: string }>>(true);
        return data === undefined ? [api.todos] : [api.todos, api.todos({ id: data.id })];
      },
      onSuccess: (data) => {
        expectType<Equal<typeof data, Todo | undefined>>(true);
      },
      onError: (error) => {
        expectType<Equal<typeof error, BendoMutationError>>(true);
      },
    }),
  );
  create.mutate({ body: { title: "write docs" } });
  // TanStack gives a mutation no signal, so the variables may carry one.
  create.mutate({ body: { title: "write docs" }, signal: new AbortController().signal });
  // @ts-expect-error the signal must be an AbortSignal
  create.mutate({ body: { title: "write docs" }, signal: "stop" });
  // @ts-expect-error the body needs a title
  create.mutate({ body: {} });
  // @ts-expect-error the body is required
  create.mutate();
  expectType<Equal<typeof create.data, Todo | undefined>>(true);
  expectType<Equal<typeof create.error, BendoMutationError | null>>(true);
  const failure = create.error;
  // @ts-expect-error a mutation resolves a 204 to undefined instead of throwing
  if (failure !== null && failure.kind === "no-content") void failure;

  // A route without required input takes no variables.
  const remove = useMutation(mutationOptions(api.any.delete, { invalidates: [api] }));
  remove.mutate();
  remove.mutate({ query: { force: "yes" } });
  expectType<Equal<typeof remove.data, { method: string } | undefined>>(true);

  // @ts-expect-error invalidates takes nodes, not strings
  mutationOptions(api.todos.post, { invalidates: ["todos"] });
}

export async function keys(): Promise<void> {
  const prefix: BendoQueryKey = routeKey(api.todos);
  await client.invalidateQueries({ queryKey: prefix });
  await client.invalidateQueries({ queryKey: routeKey(api.todos({ id: 1 }).get) });
  await invalidate(client, api.todos, api.echo({ name: "a" }));
  const caught: unknown = new Error("x");
  if (isBendoQueryError(caught) && caught.kind === "http") void caught.status;
}
