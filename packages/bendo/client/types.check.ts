// Type tests for the client tree, checked by `bun run typecheck`. Each
// `@ts-expect-error` must fail to compile; the other lines must compile.
import { createClient, type ClientResult } from "./index.ts";

type Equal<A, B> =
  (<T>() => T extends A ? 1 : 2) extends <T>() => T extends B ? 1 : 2 ? true : false;
function expectType<T extends true>(value: T): T {
  return value;
}

type Untyped = {
  params: unknown;
  query: unknown;
  headers: unknown;
  body: unknown;
  response: unknown;
};
type Row<Method extends string, Path extends string, Input, Output, All extends boolean = false> = {
  method: Method;
  path: Path;
  all: All;
  captures: string[];
  input: Untyped & Input;
  output: Untyped & Output;
};
type Todo = { id: number; title: string };

type Routes =
  | Row<"GET", "/", {}, { response: "root" }>
  | Row<
      "GET",
      "/todos",
      { query: { limit?: number | string; tag?: [string, ...string[]] } },
      { response: Todo[] }
    >
  | Row<
      "POST",
      "/todos",
      {
        headers: { "x-key": string; [key: string]: unknown };
        body: { title: string; done?: boolean };
      },
      { response: Todo }
    >
  | Row<"GET", "/todos/:id{int}", { params: { id: number | string } }, { response: Todo }>
  | Row<"DELETE", "/todos/:id{int}", {}, { response: null }>
  | Row<"GET", "/v1/:version?/:platform?", {}, { response: "v1" }>
  | Row<"GET", "/files/*path", {}, { response: "file" }>
  | Row<"GET", "/a/*/b", {}, { response: "interior" }>
  | Row<"GET", "/assets*", {}, { response: "prefix" }>
  | Row<"GET", "/flag/:on", { params: { on: boolean | "true" | "false" } }, { response: "flag" }>
  | Row<"ALL", "/any", {}, { response: "any" }, true>
  | Row<"PURGE", "/cache", {}, { response: "purged" }>
  | Row<"get", "/lower", {}, { response: "lower" }>;

const api = createClient<Routes>("http://127.0.0.1:1");

export async function checks(): Promise<void> {
  expectType<Equal<Awaited<ReturnType<typeof api.get>>, ClientResult<"root">>>(true);
  expectType<Equal<Awaited<ReturnType<typeof api.todos.get>>, ClientResult<Todo[]>>>(true);

  const one = await api.todos({ id: 1 }).get();
  if (one.ok) expectType<Equal<typeof one.data, Todo>>(true);
  else if (one.kind === "http") expectType<Equal<typeof one.status, number>>(true);
  await api.todos({ id: "1" }).delete();
  await api.todos.get();
  await api.todos.get({ query: { limit: 5, tag: ["a", "b"], extra: true } });
  await api.todos.post({
    headers: { "x-key": "k" },
    body: { title: "t" },
    signal: AbortSignal.timeout(1000),
  });
  await api.v1.get();
  await api.v1({ version: "2" }).get();
  await api.v1({ version: "2" })({ platform: "linux" }).get();
  await api.files({ path: "a/b" }).get();
  await api.a.b.get();
  await api.assets.get();
  await api.flag({ on: true }).get();
  await api.any.get();
  await api.any.patch();

  // @ts-expect-error a capture value of the wrong type
  api.todos({ id: true });
  // @ts-expect-error the wrong capture name
  api.todos({ key: 1 });
  // @ts-expect-error a capture value outside the params schema
  api.flag({ on: "yes" });
  // @ts-expect-error a required header is missing
  await api.todos.post({ body: { title: "t" } });
  // @ts-expect-error the body is required
  await api.todos.post({ headers: { "x-key": "k" } });
  // @ts-expect-error a body field of the wrong type
  await api.todos.post({ headers: { "x-key": "k" }, body: { title: 1 } });
  // @ts-expect-error a query value of the wrong type
  await api.todos.get({ query: { limit: true } });
  // @ts-expect-error an empty array for a repeated key
  await api.todos.get({ query: { tag: [] } });
  // @ts-expect-error an extra query value that is not text
  await api.todos.get({ query: { extra: { nested: 1 } } });
  // @ts-expect-error no PUT route at this path
  await api.todos({ id: 1 }).put();
  // @ts-expect-error no such path
  await api.missing.get();
  // @ts-expect-error optional captures cannot skip the earlier one
  await api.v1({ platform: "linux" }).get();
  // @ts-expect-error extension methods have no key
  await api.cache.purge();
  // @ts-expect-error lowercase method tokens are not GET
  await api.lower.get();
  if (one.ok) {
    // @ts-expect-error data is typed
    const title: number = one.data.title;
    void title;
  }
}
