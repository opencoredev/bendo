import { unregisterDom } from "./dom.ts";
import { afterAll, afterEach, beforeAll, expect, test } from "bun:test";
import {
  QueryClient,
  QueryClientProvider,
  hashKey,
  partialMatchKey,
  useMutation,
  useQuery,
} from "@tanstack/react-query";
import { act, cleanup, renderHook, waitFor } from "@testing-library/react";
import { createElement, type ReactNode } from "react";
import { build, start, type RunningServer } from "../../../tests/harness.ts";
import { createClient, type Fetch } from "../client/index.ts";
import type { Routes } from "../client/fixture/routes.ts";
import { schemas } from "../client/fixture/routes.schemas.ts";
import {
  invalidate,
  isBendoQueryError,
  mutationOptions,
  queryKey,
  queryOptions,
  routeKey,
  type BendoQueryError,
} from "./index.ts";

// The BND-57 client fixture; compile outside the test timeout.
const binary = build("tests/fixtures/client/app.bend");
let server: RunningServer;
beforeAll(async () => {
  server = await start(binary, "127.0.0.1", { BENDO_ENV: "production" });
});
afterAll(async () => {
  await server[Symbol.asyncDispose]();
  await unregisterDom();
});
afterEach(cleanup);

type Sent = { method: string; path: string; signal: AbortSignal | undefined };

/** A client whose transport records every request it sends to the fixture server. */
function recordingClient(delay = 0) {
  const sent: Sent[] = [];
  const transport: Fetch = async (input, init) => {
    const url = new URL(input);
    sent.push({
      method: init.method ?? "GET",
      path: `${url.pathname}${url.search}`,
      signal: init.signal ?? undefined,
    });
    if (delay > 0) await new Promise((resolve) => setTimeout(resolve, delay));
    return fetch(input, init);
  };
  const api = createClient<Routes>(server.url, { schemas, fetch: transport });
  return { api, sent };
}

function harness() {
  const client = new QueryClient({
    defaultOptions: { queries: { retry: false }, mutations: { retry: false } },
  });
  const wrapper = ({ children }: { children: ReactNode }) =>
    createElement(QueryClientProvider, { client }, children);
  return { client, wrapper };
}

function count(sent: readonly Sent[], method: string, path: string): number {
  return sent.filter((request) => request.method === method && request.path === path).length;
}

test("equal requests get equal keys whatever their objects look like", () => {
  const api = createClient<Routes>("http://127.0.0.1:1");
  const echo = (name: string) => api.echo({ name })({ rest: "a/b" }).get;
  const one = queryKey(echo("1"), {
    headers: { "x-token": "t", "X-Extra": "e" },
    query: { tag: ["x", "y"], n: 2, flag: true, empty: undefined },
  });
  const same = queryKey(echo("1"), {
    query: { flag: "true", n: "2", tag: ["x", "y"] },
    headers: { "x-extra": "e", "x-token": "t" },
  });
  expect(same).toEqual(one);
  expect(hashKey(same)).toBe(hashKey(one));
  const plain: readonly unknown[] = one;
  expect(plain).toEqual([
    "bendo",
    "echo",
    { ":name": "1" },
    { ":rest": "a/b" },
    {
      method: "GET",
      query: [
        ["flag", "true"],
        ["n", "2"],
        ["tag", ["x", "y"]],
      ],
      headers: [
        ["x-extra", "e"],
        ["x-token", "t"],
      ],
    },
  ]);
  // One value and a one-item array send the same query; order within an array does not.
  expect(queryKey(api.todos({ id: 1 }).get, { query: { tag: ["a"] } })).toEqual(
    queryKey(api.todos({ id: 1 }).get, { query: { tag: "a" } }),
  );
  expect(
    queryKey(echo("1"), { headers: { "x-token": "t" }, query: { tag: ["y", "x"] } }),
  ).not.toEqual(queryKey(echo("1"), { headers: { "x-token": "t" }, query: { tag: ["x", "y"] } }));
  // Body keys are sorted at every level.
  expect(hashKey(queryKey(api.todos.post, { body: { title: "a", done: false } }))).toBe(
    hashKey(queryKey(api.todos.post, { body: { done: false, title: "a" } })),
  );
  expect(queryKey(api.todos.post, { body: { title: "a" } })).not.toEqual(
    queryKey(api.todos.post, { body: { title: "b" } }),
  );
  // A capture is compared as the text it is sent as.
  expect(queryKey(api.todos({ id: 1 }).get)).toEqual(queryKey(api.todos({ id: "1" }).get));
  // Methods and captures separate keys.
  expect(queryKey(api.any.get)).not.toEqual(queryKey(api.any.put));
  expect(queryKey(api.todos({ id: 1 }).get)).not.toEqual(queryKey(api.todos({ id: 2 }).get));
});

test("names such as __proto__ and constructor keep requests apart", () => {
  const api = createClient<Routes>("http://127.0.0.1:1");
  const hash = (input: {
    query?: Record<string, string | number | string[]>;
    headers?: Record<string, string>;
    body?: unknown;
  }) => hashKey(queryKey(api.any.put, input));
  for (const name of ["__proto__", "constructor", "toString", "hasOwnProperty", "valueOf"]) {
    const a = { [name]: "a", x: "1" };
    const b = { [name]: "b", x: "1" };
    expect(Object.keys(a)).toContain(name);
    expect(hash({ query: a })).not.toBe(hash({ query: b }));
    expect(hash({ body: a })).not.toBe(hash({ body: b }));
    expect(hash({ body: { nested: [a] } })).not.toBe(hash({ body: { nested: [b] } }));
    expect(hash({ body: a })).not.toBe(hash({ body: { x: "1" } }));
    // Equal requests still share a key, whatever the field order.
    expect(hash({ query: a })).toBe(hash({ query: { x: 1, [name]: ["a"] } }));
    expect(hash({ body: { nested: [a] } })).toBe(
      hash({ body: { nested: [{ x: "1", [name]: "a" }] } }),
    );
  }
  // `__proto__` is not a header name fetch accepts, but the others are.
  expect(hash({ headers: { constructor: "a" } })).not.toBe(hash({ headers: { constructor: "b" } }));
  // A body the client refuses keys by its reason instead of making hashKey throw.
  expect(hash({ body: { n: 1n } })).toBe(hash({ body: { m: 2n } }));
});

test("a QueryClient reuses data only for the same __proto__ field", async () => {
  let calls = 0;
  const counting: Fetch = async () => {
    calls += 1;
    return Response.json({ method: "PUT" });
  };
  const api = createClient<Routes>("http://127.0.0.1:1", { fetch: counting });
  const { client } = harness();
  const fetchWith = (query: Record<string, string | number>, body: unknown) =>
    client.fetchQuery({ ...queryOptions(api.any.put, { query, body }), staleTime: Infinity });
  await fetchWith({ ["__proto__"]: "a", x: 1 }, { ["__proto__"]: { deep: 1 } });
  await fetchWith({ x: "1", ["__proto__"]: "a" }, { ["__proto__"]: { deep: 1 } });
  expect(calls).toBe(1);
  await fetchWith({ ["__proto__"]: "b", x: 1 }, { ["__proto__"]: { deep: 1 } });
  await fetchWith({ ["__proto__"]: "a", x: 1 }, { ["__proto__"]: { deep: 2 } });
  await fetchWith({ constructor: "a", x: 1 }, { ["__proto__"]: { deep: 1 } });
  expect(calls).toBe(4);
  expect(client.getQueryCache().getAll()).toHaveLength(4);
});

/** A body nested `depth` arrays deep around `leaf`, built without recursion. */
function nested(depth: number, leaf: string): unknown {
  let value: unknown = leaf;
  for (let i = 0; i < depth; i++) value = [value];
  return value;
}

test("a body nested deeper than the call stack still keys by its content", async () => {
  let calls = 0;
  const counting: Fetch = async () => {
    calls += 1;
    return Response.json({ method: "PUT" });
  };
  const api = createClient<Routes>("http://127.0.0.1:1", { fetch: counting });
  const { client } = harness();
  const fetchWith = (body: unknown) =>
    client.fetchQuery({ ...queryOptions(api.any.put, { body }), staleTime: Infinity });
  // Deep enough to overflow a recursive walk, shallow enough for JSON.stringify,
  // so the client sends these bodies.
  const depth = 30_000;
  expect(typeof JSON.stringify(nested(depth, "a"))).toBe("string");
  expect(hashKey(queryKey(api.any.put, { body: nested(depth, "a") }))).not.toBe(
    hashKey(queryKey(api.any.put, { body: nested(depth, "b") })),
  );
  await fetchWith(nested(depth, "a"));
  await fetchWith(nested(depth, "b"));
  await fetchWith(nested(depth, "a"));
  expect(calls).toBe(2);
});

test("bodies key by their exact JSON tokens, not parsed numbers", async () => {
  let calls = 0;
  const counting: Fetch = async () => {
    calls += 1;
    return Response.json({ method: "PUT" });
  };
  const api = createClient<Routes>("http://127.0.0.1:1", { fetch: counting });
  const { client } = harness();
  // JSON.rawJSON (ES2025) is in Bun but not yet in TypeScript's lib.
  const rawJSON: unknown = Reflect.get(JSON, "rawJSON");
  if (typeof rawJSON !== "function") throw new Error("this runtime lacks JSON.rawJSON");
  const body = (raw: string) => ({ n: Reflect.apply(rawJSON, JSON, [raw]), s: 'a"b' });
  const hash = (raw: string) => hashKey(queryKey(api.any.put, { body: body(raw) }));
  // JSON.parse rounds both to 9007199254740992 and reads 1e400 as Infinity.
  expect(hash("9007199254740992")).not.toBe(hash("9007199254740993"));
  expect(hash("1e400")).not.toBe(hashKey(queryKey(api.any.put, { body: { n: null, s: 'a"b' } })));
  const fetchWith = (raw: string) =>
    client.fetchQuery({ ...queryOptions(api.any.put, { body: body(raw) }), staleTime: Infinity });
  await fetchWith("9007199254740992");
  await fetchWith("9007199254740993");
  expect(calls).toBe(2);
  // Key order still does not matter.
  expect(hashKey(queryKey(api.any.put, { body: { b: [1, {}], a: { y: [], x: "" } } }))).toBe(
    hashKey(queryKey(api.any.put, { body: { a: { x: "", y: [] }, b: [1, {}] } })),
  );
});

test("header values key as fetch sends them, without surrounding whitespace", () => {
  const api = createClient<Routes>("http://127.0.0.1:1");
  const hash = (value: string) => hashKey(queryKey(api.any.get, { headers: { "x-test": value } }));
  expect(hash(" value\t")).toBe(hash("value"));
  expect(hash("a  b")).not.toBe(hash("a b"));
});

test("route keys are prefixes of exactly the queries below them", () => {
  const api = createClient<Routes>("http://127.0.0.1:1");
  const one = queryKey(api.todos({ id: 1 }).get, { query: { page: 2 } });
  const two = queryKey(api.todos({ id: 2 }).get);
  const created = queryKey(api.todos.post, { body: { title: "x" } });
  const echo = queryKey(api.echo({ name: "a" })({ rest: "b" }).get, {
    headers: { "x-token": "t" },
  });
  const matches = (prefix: readonly unknown[]) =>
    [one, two, created, echo].map((key) => partialMatchKey(key, prefix));
  expect(matches(routeKey(api))).toEqual([true, true, true, true]);
  expect(matches(routeKey(api.todos))).toEqual([true, true, true, false]);
  expect(matches(routeKey(api.todos({ id: 1 })))).toEqual([true, false, false, false]);
  expect(matches(routeKey(api.todos({ id: "1" }).get))).toEqual([true, false, false, false]);
  expect(matches(routeKey(api.todos.post))).toEqual([false, false, true, false]);
  expect(routeKey(api.todos({ id: 1 }).get)).toEqual([
    "bendo",
    "todos",
    { ":id": "1" },
    { method: "GET" },
  ]);
  expect(() => routeKey({})).toThrow(TypeError);
});

test("re-renders with equal inputs reuse one query and do not refetch", async () => {
  const { api, sent } = recordingClient();
  const { client, wrapper } = harness();
  const { result, rerender } = renderHook(
    ({ order }: { order: "ab" | "ba" }) =>
      useQuery(
        queryOptions(
          api.todos({ id: order === "ab" ? 1 : "1" }).get,
          { query: order === "ab" ? { a: "1", b: [2] } : { b: "2", a: 1 } },
          { select: (todo) => todo.title, staleTime: 60_000 },
        ),
      ),
    { wrapper, initialProps: { order: "ab" } },
  );
  await waitFor(() => expect(result.current.isSuccess).toBe(true));
  expect(result.current.data).toBe("write the client");
  const key = client.getQueryCache().getAll()[0]?.queryKey;
  for (let i = 0; i < 5; i++) rerender({ order: i % 2 === 0 ? "ba" : "ab" });
  // Give a refetch, if one were scheduled, time to reach the transport.
  await act(() => new Promise((resolve) => setTimeout(resolve, 50)));
  expect(result.current.data).toBe("write the client");
  expect(count(sent, "GET", "/todos/1?a=1&b=2")).toBe(1);
  expect(sent).toHaveLength(1);
  expect(client.getQueryCache().getAll()).toHaveLength(1);
  expect(client.getQueryCache().getAll()[0]?.queryKey).toEqual(key);
  expect(
    client.getQueryData(queryKey(api.todos({ id: 1 }).get, { query: { b: 2, a: 1 } })),
  ).toEqual({
    id: 1,
    title: "write the client",
    done: false,
  });
});

test("failed results are thrown as typed BendoQueryErrors", async () => {
  const { api } = recordingClient();
  const { wrapper } = harness();
  const missing = renderHook(() => useQuery(queryOptions(api.todos({ id: 7 }).get)), { wrapper });
  const broken = renderHook(() => useQuery(queryOptions(api.broken.get)), { wrapper });
  await waitFor(() => expect(missing.result.current.isError).toBe(true));
  await waitFor(() => expect(broken.result.current.isError).toBe(true));
  const notFound = missing.result.current.error;
  expect(notFound).toBeInstanceOf(Error);
  expect(isBendoQueryError(notFound)).toBe(true);
  expect(notFound).toMatchObject({
    name: "BendoQueryError",
    message: "GET /todos/7: 404 Not Found",
    ok: false,
    kind: "http",
    status: 404,
    error: { kind: "bendo", error: "Not Found", status: 404, errors: [] },
  });
  const invalid = broken.result.current.error;
  expect(invalid?.kind).toBe("invalid-response");
  if (invalid?.kind === "invalid-response")
    expect(invalid.issues).toContainEqual({ path: ["id"], message: "must be integer (type)" });
});

test("a HEAD query resolves to null", async () => {
  const { api } = recordingClient();
  const { wrapper } = harness();
  const { result } = renderHook(() => useQuery(queryOptions(api.any.head)), { wrapper });
  await waitFor(() => expect(result.current.isSuccess).toBe(true));
  expect(result.current.data).toBeNull();
});

test("a successful HEAD resolves to null whatever its 2xx status", async () => {
  for (const status of [200, 204, 205]) {
    const empty: Fetch = async () => new Response(null, { status });
    const api = createClient<Routes>("http://127.0.0.1:1", { fetch: empty });
    const { client } = harness();
    expect(await client.fetchQuery(queryOptions(api.any.head))).toBeNull();
  }
  const missing: Fetch = async () => new Response(null, { status: 404 });
  const api = createClient<Routes>("http://127.0.0.1:1", { fetch: missing });
  const error: unknown = await harness()
    .client.fetchQuery(queryOptions(api.any.head))
    .catch((caught: unknown) => caught);
  expect(error).toMatchObject({ kind: "http", status: 404 });
});

test("TanStack's signal reaches fetch, and cancelling aborts the request", async () => {
  const { api, sent } = recordingClient(200);
  const { client, wrapper } = harness();
  const { result } = renderHook(() => useQuery(queryOptions(api.todos({ id: 1 }).get)), {
    wrapper,
  });
  await waitFor(() => expect(sent).toHaveLength(1));
  const signal = sent[0]?.signal;
  expect(signal).toBeInstanceOf(AbortSignal);
  expect(signal?.aborted).toBe(false);
  await act(() => client.cancelQueries({ queryKey: routeKey(api.todos) }));
  expect(signal?.aborted).toBe(true);
  await act(() => new Promise((resolve) => setTimeout(resolve, 250)));
  // A cancelled first fetch returns the query to pending without an error.
  expect(result.current.status).toBe("pending");
  expect(result.current.fetchStatus).toBe("idle");
  expect(result.current.error).toBeNull();
});

test("a mutation forwards the signal in its variables, so aborting cancels the fetch", async () => {
  const { api, sent } = recordingClient(200);
  const { client } = harness();
  const controller = new AbortController();
  const mutation = client.getMutationCache().build(client, mutationOptions(api.todos.post));
  const pending = mutation
    .execute({ body: { title: "never sent" }, signal: controller.signal })
    .catch((caught: unknown) => caught);
  await waitFor(() => expect(sent).toHaveLength(1));
  expect(sent[0]?.signal).toBe(controller.signal);
  controller.abort();
  const error = await pending;
  expect(isBendoQueryError(error)).toBe(true);
  expect(error).toMatchObject({ kind: "network" });
});

test("a mutation sends its variables, returns typed data and invalidates its targets", async () => {
  const { api, sent } = recordingClient();
  const { client, wrapper } = harness();
  const { result } = renderHook(
    () => ({
      todo: useQuery(queryOptions(api.todos({ id: 1 }).get)),
      echo: useQuery(
        queryOptions(api.echo({ name: "n" })({ rest: "r" }).get, { headers: { "x-token": "t" } }),
      ),
      create: useMutation(
        mutationOptions(api.todos.post, {
          invalidates: (todo) => (todo === undefined ? [] : [api.todos]),
        }),
      ),
    }),
    { wrapper },
  );
  await waitFor(() =>
    expect(result.current.todo.isSuccess && result.current.echo.isSuccess).toBe(true),
  );
  const created = await act(() =>
    result.current.create.mutateAsync({ body: { title: "ship it" } }),
  );
  expect(created).toEqual({ id: 2, title: "ship it", done: false });
  // The todo was refetched before mutateAsync resolved; the echo was not.
  expect(count(sent, "GET", "/todos/1")).toBe(2);
  expect(count(sent, "GET", "/echo/n/r")).toBe(1);
  expect(count(sent, "POST", "/todos")).toBe(1);
  expect(client.getMutationCache().getAll()[0]?.options.mutationKey).toEqual([
    "bendo",
    "todos",
    { method: "POST" },
  ]);

  const rejected = await act(() =>
    result.current.create.mutateAsync({ body: { title: "" } }).then(
      () => undefined,
      (error: unknown) => error,
    ),
  );
  expect(isBendoQueryError(rejected)).toBe(true);
  expect(rejected).toMatchObject({
    kind: "http",
    status: 422,
    error: { errors: [{ path: ["body", "title"], code: "constraint" }] },
  });
  expect(count(sent, "GET", "/todos/1")).toBe(2);

  await act(() => invalidate(client, api.echo));
  expect(count(sent, "GET", "/echo/n/r")).toBe(2);
});

test("no-content fails a query, resolves a mutation to undefined, and request errors are thrown", async () => {
  const empty: Fetch = async () => new Response(null, { status: 204 });
  const api = createClient<Routes>("http://127.0.0.1:1", { fetch: empty });
  const { client } = harness();
  const error: unknown = await client
    .fetchQuery(queryOptions(api.todos({ id: 1 }).get))
    .catch((caught: unknown) => caught);
  expect(isBendoQueryError(error)).toBe(true);
  expect(error).toMatchObject({ kind: "no-content", status: 204 });
  const removed = await client
    .getMutationCache()
    .build(client, mutationOptions(api.any.delete))
    .execute(undefined);
  expect(removed).toBeUndefined();

  const dots = createClient<Routes>("http://127.0.0.1:1");
  const refused: BendoQueryError | undefined = await client
    .fetchQuery(queryOptions(dots.int({ i: ".." }).get))
    .then(
      () => undefined,
      (caught: unknown) => (isBendoQueryError(caught) ? caught : undefined),
    );
  expect(refused?.kind).toBe("request");
  expect(refused?.message).toStartWith("GET (invalid path): request not sent");
});
