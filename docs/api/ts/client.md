---
module: bendo/client
---

# bendo/client

The typed client: `createClient` and the types that describe its calls and
results. The [typed client guide](../../client.md) covers path building,
request input, results and response validation in depth. Run `bendo gen` first;
it writes `.bendo/routes.ts` and `.bendo/routes.schemas.ts`, which the examples
below import.

## Create a client

### `createClient`

```ts signature
function createClient<Routes extends RouteRecord>(
  baseUrl: string | URL,
  options?: ClientOptions,
): Client<Routes>;
```

Returns a client for the generated `Routes` union: properties are static path
segments, calls fill captures, and a method key such as `get` sends the
request. The base URL keeps its path prefix and drops its query and fragment.
An invalid base URL throws here; every request resolves to a `ClientResult`
and never rejects.

```ts
import { createClient } from "bendo/client";
import type { Routes } from "./.bendo/routes";
import { schemas } from "./.bendo/routes.schemas";

const api = createClient<Routes>("http://localhost:8787", { schemas });

const todo = await api.todos({ id: 1 }).get();
if (todo.ok && todo.kind === "data") console.log(todo.data.title);
await api.todos.post({ body: { title: "Write docs" } });
```

### `ClientOptions`, `Validation`

```ts signature
type ClientOptions = {
  fetch?: Fetch;
  headers?: HeadersInit;
} & Validation;

type Validation =
  | { schemas: ResponseSchemaTable; validate?: boolean }
  | { schemas?: never; validate?: never };
```

`fetch` replaces the global `fetch`. `headers` are sent with every request;
a call's own headers replace them by name. With `schemas`, 2xx bodies are
checked against the routes' response schemas; `validate: false` turns the check
off while keeping the option in place. `validate` is accepted only together
with `schemas`. [Response validation](../../client.md#response-validation)
describes which schemas apply.

```ts
import { createClient, type ClientOptions, type Validation } from "bendo/client";
import type { Routes } from "./.bendo/routes";
import { schemas } from "./.bendo/routes.schemas";

const validation: Validation = { schemas, validate: process.env.NODE_ENV !== "production" };
const options: ClientOptions = { headers: { authorization: "Bearer abc123" }, ...validation };
const api = createClient<Routes>("https://api.example.com/v1", options);
```

### `Fetch`

```ts signature
type Fetch = (input: string, init: RequestInit) => Promise<Response>;
```

The part of `fetch` the client calls, always with a full URL string and an
init holding the method, headers and, when present, the body and signal.
Inject one to add auth, retries or a test transport. A rejection becomes a
`network` result.

```ts
import { createClient, type Fetch } from "bendo/client";
import type { Routes } from "./.bendo/routes";

const logged: Fetch = async (input, init) => {
  const response = await fetch(input, init);
  console.log(init.method, input, response.status);
  return response;
};
const api = createClient<Routes>("http://localhost:8787", { fetch: logged });
```

## Routes and calls

### `Client`, `RouteRecord`

```ts signature
type RouteRecord = {
  method: string;
  path: string;
  all: boolean;
  captures: readonly string[];
  input: Slots;
  output: Slots;
};
type Client<Routes extends RouteRecord> = Node<Entries<Routes>>;
```

`RouteRecord` is the shape of one member of the generated `Routes` union;
`Slots` holds the `params`, `query`, `headers`, `body` and `response` types.
`Client<Routes>` is the tree `createClient` returns, built from the routes'
paths. [Building a path](../../client.md#building-a-path) maps each pattern
segment to a client step.

```ts
import { createClient, type Client, type RouteRecord } from "bendo/client";
import type { Routes } from "./.bendo/routes";

// A factory shared by several apps, each with its own generated Routes.
function appClient<R extends RouteRecord>(baseUrl: string): Client<R> {
  return createClient<R>(baseUrl, { headers: { "x-client": "web" } });
}

const api = appClient<Routes>("http://localhost:8787");
const todo = await api.todos({ id: 1 }).get();
```

### `Endpoint`, `RequestInput`

```ts signature
type RequestInput<R extends RouteRecord> = { query?: ...; headers?: ...; body?: ...; signal?: AbortSignal };
type Endpoint<R extends RouteRecord, M extends MethodKey> = (
  ...args: [input?: RequestInput<R>] | [input: RequestInput<R>]
) => Promise<ClientResult<M extends "head" ? undefined : R["output"]["response"]>>;
```

`Endpoint` is the type of one method on a client node, such as
`api.todos.post`. `RequestInput` is its argument: `query`, `headers` and `body`
take the route's input types, and each field, and the argument itself, is
required exactly when the route's schema has a required field. Without a
schema, `query` and `headers` take any record of text values and `body` any
value. [Request input](../../client.md#request-input) describes how each field
is sent.

```ts
import { createClient, type Endpoint, type RequestInput } from "bendo/client";
import type { Routes } from "./.bendo/routes";

type PostTodo = Extract<Routes, { method: "POST"; path: "/todos" }>;
const api = createClient<Routes>("http://localhost:8787");

const create: Endpoint<PostTodo, "post"> = api.todos.post;
const input: RequestInput<PostTodo> = { body: { title: "Write docs" } };
const created = await create(input);
```

### `Method`, `MethodKey`

```ts signature
type Method = "GET" | "HEAD" | "POST" | "PUT" | "DELETE" | "OPTIONS" | "PATCH";
type MethodKey = Lowercase<Method>;
```

The methods a client node can send, and their keys on the node. `CONNECT` and
`TRACE` are missing because `fetch` refuses them; extension methods and
lowercase method tokens have no key. A route registered with `B.all` has all
seven keys.

```ts
import type { Method, MethodKey } from "bendo/client";

const key: MethodKey = "patch";
const method: Method = "PATCH";
console.log(key.toUpperCase() === method);
```

### `TextValue`, `TextField`, `TextRecord`

```ts signature
type TextValue = string | number | bigint | boolean;
type TextField = TextValue | readonly TextValue[] | undefined;
type TextRecord = { readonly [key: string]: TextField };
```

Query values as Bendo's [text coercion](../../data/schema.md#coercion-for-text-sources)
reads them. Numbers and bigints are sent as their JavaScript string, booleans
as `true` or `false`, and an array as the key repeated once per item.
`undefined`, or an empty array, leaves the key out. A route without a query
schema takes any `TextRecord`.

```ts
import type { TextField, TextRecord, TextValue } from "bendo/client";

const limit: TextValue = 20;
const tags: TextField = ["home", "urgent"];
const query: TextRecord = { limit, tag: tags, after: undefined };
console.log(query);
```

### `HeaderField`, `HeaderRecord`

```ts signature
type HeaderField = TextValue | readonly [TextValue] | undefined;
type HeaderRecord = { readonly [key: string]: HeaderField };
```

Header values. `fetch` joins repeated header values into one field, which Bendo
reads as a single value, so a header array holds exactly one item. Two items,
or two spellings of one name such as `X-A` and `x-a`, give a `request` result.

```ts
import type { HeaderField, HeaderRecord } from "bendo/client";

const token: HeaderField = ["abc123"];
const headers: HeaderRecord = { "x-token": token, "x-retry": 2 };
console.log(headers);
```

## Results

### `ClientResult`

```ts signature
type ClientResult<T> =
  | { ok: true; kind: "data"; status: number; data: T; response: Response }
  | { ok: true; kind: "no-content"; status: 204 | 205; data: undefined; response: Response }
  | { ok: false; kind: "http"; status: number; error: HttpErrorBody; response: Response }
  | { ok: false; kind: "request"; cause: unknown }
  | { ok: false; kind: "network"; cause: unknown }
  | { ok: false; kind: "invalid-response"; status: number; issues: readonly ResponseIssue[]; response: Response };
```

What every call resolves to. `T` is the route's response type, or `undefined`
for `head`. Narrow on `kind: "data"` before reading `data` as `T`, since any
route can answer 204 or 205. `request` means nothing was sent, so retrying it
cannot help; `network` means no response arrived. `response` has its body
already read. The [results table](../../client.md#results) lists when each
kind occurs.

```ts
import { createClient, type ClientResult } from "bendo/client";
import type { Routes } from "./.bendo/routes";

const api = createClient<Routes>("http://localhost:8787");

function titleOf(result: ClientResult<{ title: string }>): string {
  switch (result.kind) {
    case "data":
      return result.data.title;
    case "no-content":
      return "(empty)";
    case "http":
      return `HTTP ${result.status}`;
    case "invalid-response":
      return result.issues.map((issue) => issue.message).join("; ");
    case "request":
    case "network":
      return String(result.cause);
    default: {
      const exhaustive: never = result;
      return exhaustive;
    }
  }
}
console.log(titleOf(await api.todos({ id: 1 }).get()));
```

### `HttpErrorBody`, `BendoFieldError`

```ts signature
type HttpErrorBody =
  | { kind: "bendo"; error: string; status: number; errors: readonly BendoFieldError[] }
  | { kind: "text"; text: string };
type BendoFieldError = { path: readonly (string | number)[]; code: string; message: string };
```

The `error` of an `http` result. It is `kind: "bendo"` when the body has the
whole shape of Bendo's error JSON, with `errors` holding the
[schema error list](../../data/schema.md#errors) (empty when the body has
none). Any other body is kept as text.

```ts
import type { BendoFieldError, HttpErrorBody } from "bendo/client";

function fieldMessages(error: HttpErrorBody): string[] {
  if (error.kind === "text") return [error.text];
  return error.errors.map((field: BendoFieldError) => `${field.path.join(".")}: ${field.message}`);
}
```

### `ResponseIssue`

```ts signature
type ResponseIssue = { path: readonly (string | number)[]; message: string };
```

One reason an `invalid-response` result failed: a body that is not JSON, a
non-JSON content type where a schema applies, or a schema failure. `path` holds
keys and array indexes into the body.

```ts
import type { ResponseIssue } from "bendo/client";

function report(issues: readonly ResponseIssue[]): string {
  return issues.map((issue) => `/${issue.path.join("/")}: ${issue.message}`).join("\n");
}
```

## Response schemas

### `JsonSchema`, `ResponseSchemaRow`, `ResponseSchemaTable`

```ts signature
type JsonSchema = boolean | { readonly [keyword: string]: unknown };
type ResponseSchemaRow = {
  readonly method: string;
  readonly path: string;
  readonly all: boolean;
  readonly params?: JsonSchema;
  readonly response?: JsonSchema;
};
type ResponseSchemaTable = ReadonlyArray<ResponseSchemaRow>;
```

The shape of `schemas` in the generated `routes.schemas.ts`: one row per route
with its JSON Schema 2020-12 `params` and `response` slots. Pass it as the
`schemas` option. The client uses `params` only to narrow which routes could
have answered a call.

```ts
import { createClient, type JsonSchema, type ResponseSchemaRow, type ResponseSchemaTable } from "bendo/client";
import type { Routes } from "./.bendo/routes";
import { schemas } from "./.bendo/routes.schemas";

const health: JsonSchema = { type: "object", properties: { ok: { type: "boolean" } } };
const extra: ResponseSchemaRow = { method: "GET", path: "/health", all: false, response: health };
const table: ResponseSchemaTable = [...schemas, extra];
const api = createClient<Routes>("http://localhost:8787", { schemas: table });
```
