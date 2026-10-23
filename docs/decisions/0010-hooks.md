# 0010: Lifecycle hooks are middleware placements

Date: 2026-10-23. Issue: BND-23. Status: accepted for M3.

Register global hooks in the route list with `B.on_request(Tag, id)`,
`B.on_parse`, `B.on_transform`, `B.before_handle`, `B.after_handle`,
`B.map_response`, `B.on_error` and `B.on_after_response`. Each takes the same
application-owned `Data` tag as `B.use`. Supply the existing middleware
dispatcher to `B.serve_with` or `B.handle_with`.

A hook registration stores an identifier and a `Table.Stage` tag. The table
contains no functions. `Middleware.chain`, the same affine onion primitive as
ordinary middleware, interprets the selected identifiers. Hook registrations
are excluded from the route manifest. There is one callback contract:

```text
Tag -> Ctx<Vars> -> Env -> (Ctx<Vars> -> IO(Res)) -> IO(Res)
```

## Fixed order

Stage order is independent of placement in the registration list. Within each
stage, hooks run in registration order, including duplicate identifiers.
Pre-stage hooks perform their work before `next`. Response-stage hooks call
`next(c)` to obtain the preceding response, then return their replacement.
Each response hook wraps that value in a one-layer onion; this preserves
registration order for both effects and response changes.

| Order | Hook | Middleware form | Can short-circuit? | Sees what |
| --- | --- | --- | --- | --- |
| 1 | `on_request` | Outer pre-next chain, before route resolution | Yes: skip routing and remaining pre stages | Buffered request/body and decoded query; no route params |
| 2 | `on_parse` | Pre-next layer after routing and ordinary middleware entry | Yes | Raw body, route params, typed variables; may decode into `Vars` |
| 3 | `on_transform` | Pre-next layer after parse | Yes | Context forwarded by parse; prepare values for future validation |
| 4 | `before_handle` | Innermost pre-next chain | Yes: skip handler | Parsed/transformed context and route params |
| 5 | handler | Onion terminal | Returns `Res` | Final forwarded context |
| 6 | `after_handle` | One-layer post-next response middleware | May replace the response; later response hooks still run | Latest forwarded context and response after the pre-stage onion unwinds |
| 7 | `map_response` | One-layer post-next response middleware | May replace the response; later response hooks still run | Response from `after_handle`; may set Content-Type or encode a body |
| 8 | `on_error` | Conditional one-layer post-next response middleware | May recover; all registered error hooks run | Current error response, after mapping and response validation |
| 9 | `on_after_response` | One-layer observer after transport send completes | No: returned responses are discarded | Latest forwarded context and final normalized response |

Ordinary `use`/`use_path` middleware keeps its registration-ordered onion. It
enters after routing, wraps parse/transform/before/handler, then unwinds before
`after_handle`. An ordinary or pre-stage short-circuit still goes through
`after_handle`, `map_response`, conditional `on_error` and `on_after_response`.
Pre-stage middleware can run code after `next`, just as ordinary middleware can;
that code runs while its onion unwinds, before the response stages. Use the
response-stage registrations when work must follow their fixed order.

## Routing, parsing and context

Only `on_request` runs before routing. Pass
`C.rewrite(Vars, c, method, path)` to `next` to change route selection;
`B.rewrite` is the `Unit`-variables spelling. Rewrites preserve the buffered
body, query and request headers. Route params are recomputed afterward.
`use_path` selection uses the rewritten path. Routing remains fixed once the
request-stage chain calls its terminal. The original wire method still controls
HEAD framing, even if the routing method changes.

The HTTP shell has already framed and buffered the body before any app hook.
`on_parse` is the application decoding placement, not a second HTTP framing
parser. A custom parser reads `C.raw_body` and passes a context with its typed
parsed value in `C.set(Vars, c, value)` to `next`. There is no automatic body
decoder in this issue. M4.6 validation can attach after parse/transform and before
the handler without adding another callback mechanism.

Immutable middleware retains its original context after `next`, as before.
A request-local channel records the latest context forwarded to a continuation,
including route captures. Response hooks and observers receive that snapshot.
Local changes in a hook that returns without forwarding cannot be recovered
from its `Res`; put response changes in that response. Post-stage `next` supplies
a response value, so passing another context to it does not rerun the handler or
change the snapshot for subsequent post hooks. The channel closes before the
response stages and never stores closures. A continuation that outlives a
middleware timeout can still finish: updates to the closed slot are discarded.
They cannot change the response or observer snapshot already selected.

## Errors and transport boundary

Until BND-25 introduces typed HTTP errors, an error is a returned `Res` with
status 400 or higher. Invalid responses produced before `on_error` become an
empty 500 first. All error hooks then run once in registration order, even if
an earlier one changes the status to success. Their output is validated again;
an invalid recovery response fails closed to 500 without recursively calling
`on_error`. Request-ID and Server-Timing middleware retain their finalized
values in framework metadata. After this final validation, missing observability
headers are restored before observers and transport. Explicit final response
headers take precedence, with case-insensitive name matching. A mapper that
replaces an error with a success response has already recovered it, so error
hooks do not run.

This covers handler and middleware error responses, short-circuit errors,
404/405 terminals, and response validation errors. It does not catch `IO.die`,
`IO.exit`, native crashes or failed effects unwrapped with `IO.try`. Malformed
HTTP framing and invalid query encoding remain transport/input rejections that
do not enter the app lifecycle, matching the middleware contract.

The server carries an affine deferred `IO(Unit)` alongside its response bytes.
It executes that action once after `TCP.send_bytes` returns, on either success
or failure, before reusing or closing the socket. Completion means the transport
accepted the bytes, not that the peer acknowledged them. Observer return values
cannot change those bytes or the response seen by another observer. Slow
observers delay the next request on the same connection; other connections can
continue. Use a separate connection for requests that release a blocked observer.

`handle_with` has no socket. Its equivalent boundary is response normalization:
it runs observers before returning that normalized response to the caller. The
network shell uses the internal deferred entrypoint instead, so it never runs
an observer before sending.

Hooks are global in this issue. Groups, route scopes and `guard` belong to
M3.3b; plugins belong to M3.5. They can lower into the same stage-tagged
registrations without changing the dispatcher contract.

## Verification

`tests/servers/hooks.bend` is a complete native consumer. Its registrations mix
stages deliberately. `bun test --timeout 30000 tests/hooks.test.ts` checks the
stage trace, custom parsing and transformation, path/method rewrites,
short-circuits, error recovery, content-type mapping and gated post-send
observers on success and error paths. The gate requires receiving the response
before a follow-up request releases the observer, then reads the completed
observer trace. Existing middleware selection proofs cover the extended
registration sum, with hooks excluded from ordinary middleware selection.
