# Observability middleware

Wrap Bendo's built-in identifiers in your app's middleware tag, then delegate
that tag to `B.builtin`. Your own middleware and handlers keep their typed
variables and the same affine continuation. Built-ins are opt-in.

The complete runnable application is
[`tests/servers/mw-observability.bend`](../tests/servers/mw-observability.bend).
Here is a minimal app using the public entrypoint:

```python
import Base
import ../src/main.bend as B
import ../src/app/context.bend as C
import ../src/router/methods.bend as Methods

type Tag is Data:
  Hello{}
  Builtin{id: B.Builtin}

def handler(tag: Tag, c: B.Context(Unit), env: Unit) -> IO(B.Res):
  IO.pure(B.Res, C.text(Unit, c, "hello"))

def middleware(tag: Tag, c: B.Context(Unit), env: Unit, next: B.Context(Unit) -> IO(B.Res)) -> IO(B.Res):
  match tag:
    case Builtin{id}: B.builtin(Unit, id, c, next)
    case Hello{}: next(c)

def ready(result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "invalid routes")
    case Done{table}: B.serve_with(~Unit, ~Tag, ~Unit, ~handler, ~middleware, table, Unit{}, B.config())

def main() -> IO(Unit):
  ready(B.routes(Tag, [
    B.use(Tag, Builtin{B.logger()}),
    B.use(Tag, Builtin{B.request_id()}),
    B.use(Tag, Builtin{B.server_timing()}),
    B.use(Tag, Builtin{B.powered_by("Bendo")}),
    B.use(Tag, Builtin{B.pretty_json()}),
    B.get(Tag, "/", Hello{})
  ]))
```

Use `B.use_path` to restrict any built-in to matching paths. Register the logger
first so it observes all inner response transformations. The table still stores
only `Data`; no handlers or continuations are stored in reusable state.

## Lifecycle hooks

Built-ins use the same dispatcher with `B.use` and lifecycle registrations.
For hooks, start request IDs and timing in `on_request`, and log the final
response in `on_after_response`:

```python
B.on_request(Tag, Builtin{B.request_id()}),
B.on_request(Tag, Builtin{B.server_timing()}),
B.map_response(Tag, Builtin{B.pretty_json()}),
B.map_response(Tag, Builtin{B.powered_by("Bendo")}),
B.on_after_response(Tag, Builtin{B.logger()}),
```

These registrations replace the corresponding `B.use` entries in the app above.
Request IDs and timing collectors survive request rewrites, route capture
attachment and typed variable setters. Register request ID before other request
hooks so their handlers can read it. Timing in `on_request` measures its inner
request/routing/handler chain; it finishes before `after_handle`, `map_response`
and transport send. Marks added in those later stages are outside that collector.
The finalized ID and timing value remain in request metadata. After response
hooks, error recovery and final validation, Bendo fills missing `X-Request-Id`
and `Server-Timing` headers, including on replacement 404/405 recovery responses
and validation-generated 500s. An explicit `Server-Timing` header wins. An
explicit request ID wins only when it meets the request-ID validation rule below;
name matching ignores case and the final response contains at most one request ID.
If a hook replaces that response again, its missing headers receive the retained values.
Observers see these final headers.

An `on_after_response` logger sees the final normalized response after the send
attempt completes, including changes made by response hooks. It logs the latest
forwarded method/path, including request rewrites. Its duration measures the
observer's `next` call, which supplies an already-computed response; it is not
request latency. Use `server_timing` for request duration, or ordinary outer
logger middleware to measure its inner chain. With `B.handle_with`, observers run
before returning the normalized response, since there is no transport.

Keep request-ID and timing built-ins in `on_request` or ordinary middleware.
Registering them in a response stage cannot make their context metadata visible
to a handler that already ran. `pretty_json` and `powered_by` may use
`map_response` to change the outgoing response. Their returned response is
discarded in `on_after_response`, so that stage is suitable only for observers.

## Logger

`B.logger()` logs to **stderr** once after `next` returns. With ordinary
middleware, this happens before the server writes the response. The stable
format is:

```text
<METHOD> <PATH> <STATUS> <DURATION>ms[ id=<REQUEST_ID>]
```

For example, `GET /todos 200 12ms id=client-42`, followed by one newline.
`DURATION` is a nonnegative integer number of milliseconds measured with
`IO.now`, Bend's monotonic clock. There is no wall-clock timestamp. The optional
ID comes from the returned `x-request-id` header, so a logger outside request-ID
middleware sees generated IDs too. A logger inside request-ID middleware falls
back to the context ID. Unsafe response IDs are omitted from the log.
Queries, request headers and bodies are omitted. The logger reads the path from
its context, so request hooks may have rewritten it. Avoid putting secrets in
path segments. Invalid responses are converted to
500 before logging. Response changes made by outer middleware or later response
hooks happen afterward. Keep an ordinary logger outermost to observe its inner middleware;
use `on_after_response` to observe the final normalized response. A timeout
outside the logger may return before its inner computation finishes: timeouts
answer without cancelling, as described in design decision 9.

## Request ID

`B.request_id()` reuses the first incoming `X-Request-Id` when it contains 1–200
ASCII characters from `A–Z`, `a–z`, `0–9`, `.`, `_`, and `-`. Empty, undecodable,
overlong or unsafe values are replaced with 16 cryptographically random bytes,
encoded as 32 lowercase hex digits. Entropy failure returns an empty 500 and
skips the handler; there is no fallback identifier or process exit.

A valid explicit outgoing `x-request-id` takes precedence over the retained ID.
The same 1–200 character rule applies to incoming and outgoing IDs, including
headers set by handlers and response hooks. An invalid outgoing ID is replaced
with the retained ID, or dropped when no middleware assigned one. Finalization
matches header names without regard to case and emits at most one `x-request-id`.
Handlers read `C.request_id(Vars, c) -> Maybe<&2, String>` from
`src/app/context.bend`. This dedicated metadata survives context setters and
variable conversion without occupying app-owned `Vars`. The accessor returns
`None` before request-ID middleware runs. Do not treat an incoming ID as a trusted
identity or authorization value.

## Server timing

`B.server_timing()` emits `Server-Timing: total;dur=<ms>` using the monotonic
clock. Handlers and inner middleware add measured durations with:

```python
ok : Bool <- B.timing_mark(Vars, c, "db", 4n)
```

This IO operation returns `True` when the mark was recorded and `False` when no
timing middleware is active or the store operation fails or times out. A timed-out
write may still commit; the deadline does not cancel it. Durations are
nonnegative `Nat` milliseconds; take two `IO.now` readings and subtract to
measure a span. Marks appear in insertion order after `total`.

Names are encoded as HTTP tokens: each name starts with `mark_`, ASCII letters
and digits remain unchanged, and every other code point becomes `_<decimal>_`.
Thus `db` becomes `mark_db`, and `cache; hit` becomes `mark_cache_59__32_hit`.
Encoding underscores too avoids collisions. Empty names become `mark_`;
application marks cannot replace the reserved `total` metric. Duplicate names
remain separate metrics.

A request-local store actor makes marks visible across immutable context copies.
Nested registrations share the outer collector. Its owner reads and closes it
after `next`, including when the final read fails (which returns empty 500).
Late writes return a bounded failure after closure. Marks in work that continues
after the response are not included. Store operations use the normal 5-second
deadline; the middleware does not cancel background work.

## Powered by

`B.powered_by(name)` sets or replaces `X-Powered-By` with `name` after `next`.
There is no header by default. Toggle it off by omitting its registration; this
does not remove a header explicitly added by the app. An invalid header value
fails normal response validation as 500.

## Pretty JSON

`B.pretty_json()` checks for the decoded, case-sensitive query key `pretty`.
Its presence enables formatting, including `?pretty`, `?pretty=false` and
`?pretty=`. Without it, the response remains byte-for-byte unchanged.

The middleware parses `application/json` bodies with the shared strict JSON
parser, then uses the writer's two-space pretty mode, preserving Unicode and
number spellings with no trailing newline. Media-type matching is
case-insensitive and permits parameters. Non-JSON and invalid JSON stay unchanged.
Encoded responses, partial responses (206 or Content-Range), and bodyless statuses
are skipped. On a successful rewrite, ETag, Content-MD5, Digest, Content-Digest
and Repr-Digest are removed, and the representation witness is cleared.
Content-Length is recalculated by the HTTP writer, including for HEAD.

This buffers and reparses the body. Use it for debugging buffered JSON responses;
use [pull streaming](streaming.md) for incremental responses instead. Place it inside middleware that computes validators
when those validators should describe the formatted body.

Verify with `bun test --timeout 30000 tests/mw-observability.test.ts`.

Lifecycle observers registered through a group, guard or route options follow
that route's scope, just like the other lifecycle stages. Scoped response hooks
and observers use the actual routed registration after request-stage rewrites;
a rewrite during parse, transform or before-handle does not switch them to a
different route. A request-stage short circuit retains its provisional route's
scope. See [hook scopes and guards](decisions/0011-hook-scopes.md).
