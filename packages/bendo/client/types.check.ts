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
  | Row<"GET", "/items/:id", { params: { id: "read" } }, { response: "read" }>
  | Row<"PUT", "/items/:id", { params: { id: "write" } }, { response: "written" }>
  | Row<"POST", "/items/:id/notes", { params: { id: "write" } }, { response: "noted" }>
  | Row<"GET", "/items/:id/notes", { params: { id: "read" } }, { response: "notes" }>
  | Row<"GET", "/keys/:key", { params: { key: number } }, { response: "key" }>
  | Row<"GET", "/keys/:name", { params: { name: string } }, { response: "name" }>
  | Row<
      "GET",
      "/signed",
      { headers: { "x-sig": [string, ...string[]]; "x-n"?: number; [key: string]: unknown } },
      { response: "signed" }
    >
  | Row<"PURGE", "/cache", {}, { response: "purged" }>
  | Row<"get", "/lower", {}, { response: "lower" }>;

const api = createClient<Routes>("http://127.0.0.1:1");

export async function checks(): Promise<void> {
  expectType<Equal<Awaited<ReturnType<typeof api.get>>, ClientResult<"root">>>(true);
  expectType<Equal<Awaited<ReturnType<typeof api.todos.get>>, ClientResult<Todo[]>>>(true);

  const one = await api.todos({ id: 1 }).get();
  if (one.ok) expectType<Equal<typeof one.data, Todo | undefined>>(true);
  else if (one.kind === "http") expectType<Equal<typeof one.status, number>>(true);
  // Any route may answer 204, so `data` is the response type only under `kind: "data"`.
  if (one.ok && one.kind === "data") expectType<Equal<typeof one.data, Todo>>(true);
  if (one.ok && one.kind === "no-content") expectType<Equal<typeof one.status, 204>>(true);
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
  expectType<Equal<Awaited<ReturnType<typeof api.any.head>>, ClientResult<undefined>>>(true);

  // A capture value keeps only the routes it can reach, here and below.
  const read = await api.items({ id: "read" }).get();
  if (read.ok && read.kind === "data") expectType<Equal<typeof read.data, "read">>(true);
  await api.items({ id: "write" }).put();
  await api.items({ id: "write" }).notes.post();
  await api.items({ id: "read" }).notes.get();
  const key = await api.keys({ key: 1 }).get();
  if (key.ok && key.kind === "data") expectType<Equal<typeof key.data, "key">>(true);
  const name = await api.keys({ name: "n" }).get();
  if (name.ok && name.kind === "data") expectType<Equal<typeof name.data, "name">>(true);
  await api.signed.get({ headers: { "x-sig": ["s"], "x-n": 1, "x-other": ["o"] } });

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
  // @ts-expect-error GET needs "read"
  await api.items({ id: "write" }).get();
  // @ts-expect-error PUT needs "write"
  await api.items({ id: "read" }).put();
  // @ts-expect-error the descendant POST needs "write"
  await api.items({ id: "read" }).notes.post();
  // @ts-expect-error the descendant GET needs "read"
  await api.items({ id: "write" }).notes.get();
  // @ts-expect-error no route takes this value
  api.items({ id: "other" });
  const either: "read" | "write" = Math.random() > 0.5 ? "read" : "write";
  // @ts-expect-error a value that may be "write" cannot reach the GET
  await api.items({ id: either }).get();
  // @ts-expect-error :key takes a number
  api.keys({ key: "k" });
  // @ts-expect-error a header array holds one item; fetch would join the rest
  await api.signed.get({ headers: { "x-sig": ["a", "b"] } });
  // @ts-expect-error an extra header array holds one item too
  await api.signed.get({ headers: { "x-sig": ["s"], "x-other": ["a", "b"] } });
  // @ts-expect-error an empty header array sends no required header
  await api.signed.get({ headers: { "x-sig": [] } });
  // @ts-expect-error a header array without a schema holds one item
  await api.any.get({ headers: { "x-a": ["a", "b"] } });
  // @ts-expect-error extension methods have no key
  await api.cache.purge();
  // @ts-expect-error lowercase method tokens are not GET
  await api.lower.get();
  if (one.ok && one.kind === "data") {
    // @ts-expect-error data is typed
    const title: number = one.data.title;
    void title;
  }
}
