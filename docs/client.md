# Typed client

`createClient<Routes>(baseUrl, options?)` from `bendo/client` calls a Bendo app
with types generated from its routes. Paths read like the URL, captures are
function calls, and every call resolves to a result value instead of throwing.

```ts
import { createClient } from "bendo/client";
import type { Routes } from "./.bendo/routes";
import { schemas } from "./.bendo/routes.schemas";

const api = createClient<Routes>("http://localhost:8787", { schemas });

const todo = await api.todos({ id: 1 }).get();
if (todo.ok) console.log(todo.data.title);
else if (todo.kind === "http") console.log(todo.status, todo.error);

await api.todos.post({ body: { title: "Write docs" } });
await api.todos.get({ query: { limit: 20, tag: ["home", "urgent"] } });
```

Run `bendo gen` first. It writes `.bendo/routes.ts` (the [route types](route-types.md))
and `.bendo/routes.schemas.ts` (the response schemas used for validation).
Rerun it after changing a route or schema.

## Building a path

Each `/`-separated part of a route path becomes one step:

| Pattern segment | Client |
| --- | --- |
| `todos` | property: `api.todos` |
| `:id`, `:id{int}` | call with an object holding that one key: `api.todos({ id: 1 })` |
| `:id?` (optional, trailing) | the call may be left out: `api.v1.get()` or `api.v1({ version: 2 }).get()` |
| `*path` (final wildcard) | call: `api.files({ path: "a/b.txt" })` |
| `*` (final) | call with the key `"*"` |
| interior `*` | no step; it matches zero segments |
| `assets*` (prefix wildcard) | property `assets` |
| `/` | methods on the client itself: `api.get()` |

A path ends with a method: `get`, `head`, `post`, `put`, `delete`, `options`
or `patch`. A route registered with `B.all` has all seven. Extension methods
(such as `PURGE`), lowercase method tokens, `CONNECT` and `TRACE` have no
method key: fetch refuses the last two and the others cannot be told apart
from path segments.

A capture value's type comes from the route's params schema, so
`api.todos({ id: true })` is a type error when `id` is an integer. Without a
params schema a capture takes `string | number`. Two routes that share a
capture position share one call, which takes any value either route accepts.
The value then picks the routes: if `GET /items/:id` takes `id: "read"` and
`PUT /items/:id` takes `id: "write"`, `api.items({ id: "write" })` has `put` but
no `get`, and the same holds for every route below the capture.

Captures are encoded with `encodeURIComponent`. A `/` inside a value travels as
`%2F`, which Bendo decodes back, so `{ path: "a/b" }` reaches a wildcard as
`a/b`. Values `.` and `..` cannot be sent, because the URL parser removes dot
segments; the call returns a `request` result without sending anything.
Static segments are sent as written. The URL parser percent-encodes spaces and
non-ASCII text in them, and Bendo compares static text without decoding, so a
route such as `/café` cannot be reached from `fetch`.

## Request input

A method takes one optional object:

| Field | Type | Sent as |
| --- | --- | --- |
| `query` | the route's query input type | the URL query |
| `headers` | the route's header input type | request headers, replacing defaults by name |
| `body` | the route's body input type | JSON with `content-type: application/json` |
| `signal` | `AbortSignal` | passed to `fetch` |

The argument and each field are required exactly when the route's schema has
a required field. Without a schema, `query` and `headers` accept any record of
text values and `body` accepts any JSON value.

Query and header values follow Bendo's [text coercion](data/schema.md#coercion-for-text-sources):
a string is sent as is, a number or bigint as its JavaScript string, a boolean
as `true` or `false`, and an array as the key repeated once per item.
`undefined` leaves the key out, so an empty array sends nothing. Headers take
one value per name: fetch joins repeated header values into one field (`a, b`),
which Bendo reads as a single value. So a header array has exactly one item
(`["v"]`, even when the schema allows more), and a call with two items, or with
two spellings of one name such as `X-A` and `x-a`, is a `request` result.

Every request sends `accept: application/json` unless a default or call header
sets another `accept`, because Bendo renders error bodies as JSON only for an
explicit JSON Accept ([decision 0011](decisions/0011-crash.md)).

## Results

Every call resolves to a `ClientResult<T>`, where `T` is the route's response
type, or `undefined` for `head`. The promise never rejects.

| Result | When |
| --- | --- |
| `{ ok: true, status, data, response }` | a 2xx response whose body passed validation |
| `{ ok: false, kind: "http", status, error, response }` | any status outside 200 to 299 |
| `{ ok: false, kind: "request", cause }` | the request could not be built, so nothing was sent |
| `{ ok: false, kind: "network", cause }` | no response: fetch rejected (refused connection, DNS, abort) or the body could not be read |
| `{ ok: false, kind: "invalid-response", status, issues, response }` | a 2xx body that is not valid JSON or fails the response schema |

`data` is parsed JSON when the response's content type is `application/json`
or `+json`, and the body text otherwise. A successful `HEAD` has `data:
undefined` whatever its content type says, since the response has no body.
`response` is the `Response` with its body already read.

`error` is Bendo's error JSON when the body has its whole shape:

```ts
{ kind: "bendo", error: "Unprocessable Content", status: 422,
  errors: [{ path: ["body", "title"], code: "constraint", message: "value does not satisfy scalar checks" }] }
```

`errors` is the [schema error list](data/schema.md#errors) and is empty when the
body has none. Any other body is kept as `{ kind: "text", text }`.

A request that cannot be built is a `request` result, kept apart from
`network` so a retry policy can skip it: retrying sends the same broken
request. Its `cause` is usually a `TypeError` naming the problem: a dot-segment
capture, a query or header value that is not text, a header with more than one
value, a header name or value HTTP cannot carry, a body without a JSON form, or
a capture call without exactly one key. The types reject most of these; they
cannot see dot segments, invalid header characters, or, for routes without a
body schema, bodies such as a function or a bigint.

`issues` lists `{ path, message }` per failure; `path` holds keys and array
indexes into `data`.

## Response validation

With `schemas`, a 2xx body is checked against the response schema of every
route the call could reach (several when duplicate or `B.all` routes share the
path). It passes when any of them accepts it. A route without a response schema
accepts any body. `HEAD` responses are never validated. A body that is not JSON fails
when a schema applies.

Pass `validate: false` to switch validation off, for example in production or
under a Content Security Policy without `unsafe-eval`. Then the body is
returned as `data` unchecked. Error responses are never validated.

The validator is Ajv, loaded on first use. [Decision 0014](decisions/0014-client-response-validation.md)
explains the choice and its limits, and
[the validator differences](data/json-schema.md#decoder-policy-and-validator-differences)
list where Ajv and Bendo's decoder disagree.

## Options

```ts
createClient<Routes>("https://api.example.com/v1", {
  fetch: (input, init) => fetch(input, init), // inject for auth, retries or tests
  headers: { authorization: `Bearer ${token}` }, // sent with every request
  schemas, // from .bendo/routes.schemas.ts
  validate: import.meta.env.DEV, // only with schemas
});
```

The base URL keeps its path prefix and drops its query and fragment. An invalid
base URL throws from `createClient`. That is the only throw.

## Limits

- A static segment named like a method key (`/files/get`) can be followed by
  other segments but not by a capture call: `api.files.get(...)` sends a
  request.
- A segment named `then` cannot be reached: nodes return `undefined` for
  `then` so that awaiting one does not send a request.
- Default headers do not relax types: a header the route's schema requires must
  still be passed in each call.

Type checking stays linear in the number of routes:
`timeout 60s bun scripts/client-types-bench.ts 400` checks 400 routes, each
called once, in about 0.55 s (0.22 s for 100, 0.32 s for 200), with the same
cost when every call passes a different capture literal (`--distinct`). The
exception is a capture whose routes disagree on its value type (`--mixed`): each
distinct literal type passed to it filters that capture's routes again, so 400
such routes called with 400 different literals take about 1.75 s. A value typed
`string` or `number` is one type however many calls pass it.

## Tests

`timeout 10m bun test --timeout 30000 packages/bendo/client` compiles
`tests/fixtures/client/app.bend`, checks that `bendo gen` output matches the
committed `packages/bendo/client/fixture`, and calls the server for typed data,
404 and validation 422 errors, invalid responses, HEAD on a JSON route,
encoding and serialization, a closed
port and an aborted signal. `packages/bendo/client/types.check.ts` holds the
type tests that `bun run typecheck` checks.
