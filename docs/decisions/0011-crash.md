# 0011: Recoverable HTTP errors and process-fatal crashes

Date: 2026-10-23. Issue: BND-25. Status: accepted for Bend 2.0.38.

Return typed HTTP errors as values. `IO.die` is process-fatal, including when
called by a handler spawned for one connection. Bendo cannot catch it at a
request boundary in Bend 2.0.38. Run the binary under a supervisor and reserve
runtime termination for failures that really require restarting the process.

## Typed errors preserve the closed dispatcher

The data route table and closed `dispatch(tag, ctx, env) -> IO(Res)` from
[0001](0001-route-table.md) remain the runtime contract. `B.HttpError` aliases
`Errors.HttpError{status, message, expose}`. `B.http_error(status, message)`
constructs one; `B.error(ctx, error)` converts it into a response. Bend has no
exception syntax. A handler returns `IO.pure(B.Res, B.error(...))` rather than
throwing. Fallible application functions can return
`Result<&2, &2, B.HttpError, B.Res>`; `B.result(ctx, result)` passes through
`Done{res}` and renders `Fail{error}`. Typed-variable apps use
`C.error(Vars, ctx, error)` and `C.result(Vars, ctx, result)`.

```python
B.error(c, B.http_error(418, "Tea only"))
B.result(c, Fail{B.http_error(418, "Tea only")})
```

Both produce status 418 and the configured message. Only codes 400–599 are
accepted; other codes become 500. The smart constructor exposes 4xx messages
and hides 5xx messages. Hidden messages render as `Internal Server Error`,
including for 503. No stack or runtime diagnostic is added. Applications can
explicitly opt into a public 5xx message with
`Errors.HttpError{503, "Maintenance", True{}}`; this is a deliberate disclosure.
An empty exposed message uses the response module's reason phrase (empty for
unassigned codes).

## What the laws prove

The laws cover the `Res` that `error` returns, before app hooks run.
`http_error_private_message` only fixes the public message helper. The laws in
`proof/error-laws.bend` cover rendering itself:

- `http_error_private_independent` and `http_error_private_wire_independent`:
  for any context, method and code, two unexposed errors with different
  messages render the same `Res` and the same written bytes.
- `http_error_private_rendered`: from a context with no accumulated response
  headers and any request, an unexposed error renders exactly the response in
  `proof/error-spec.bend`. That is status `code` for 400–599 and 500 otherwise,
  `Content-Type` for the negotiated representation, `Vary: Accept`, and a body
  of exactly `Internal Server Error` or
  `{"error":"Internal Server Error","status":<status>}`.
- `http_error_private_accept_samples`: the same response, chosen from the first
  Accept field for seven sample values (absent, `application/json`, a
  parameterized JSON range, `q=0`, `q=0` after a quoted comma, `*/*`,
  `text/plain`). The spec lists the expected representation for each sample.
- `http_error_exposed_rendered`: an exposed error with a 400–599 code renders
  its message's UTF-8 bytes, or the JSON writer's escaping of it, with the reason
  phrase for an empty message. If the response fails `Response.valid`, or a
  JSON message is not Unicode scalar text, the result is the empty 500.
  `http_error_tea_only_rendered` pins `http_error(418, "Tea only")` byte for byte.
- `http_error_invalid_header_fallback`: an invalid accumulated header (a value
  containing a line feed) turns any error into the empty 500.
- `http_error_head_no_payload`: a HEAD request's error response is written with
  no payload.

The laws decide JSON-or-text with `Errors.accepts_json` as a hypothesis, or
with the listed samples. No law states the full Accept grammar. Integration
tests cover the rest of that policy, plus responses built on a context that
already has headers.

Errors become ordinary responses before the existing lifecycle response
stages. There is no parallel error callback or second dispatcher. `after_handle`
and `map_response` still run, then the existing conditional `on_error` chain
can recover or replace the response. It sees the safe rendered response, not
the private diagnostic. Apps needing logs should record private errors before
conversion. Raw `Res` bodies and custom hooks remain application-owned;
Bendo does not scan arbitrary response bodies for secrets. Request-ID and
Server-Timing finalization remains after error recovery and validation.

## Body negotiation

An explicit, case-insensitive `application/json` range in the first Accept
field opts into JSON, provided its quality is positive. Parameters are allowed;
`q` accepts HTTP's zero-to-one grammar with up to three decimal places. A
zero or malformed quality excludes that range. Wildcards, missing Accept,
invalid UTF-8, and other media types use `text/plain; charset=utf-8`.
This is an explicit JSON opt-in, not a full preference ranking: a positive JSON
range selects JSON even if text has higher quality. Repeated Accept fields
follow the context accessor's first-field policy.

JSON uses `application/json; charset=utf-8` and the shared writer's escaping:
`{"error":"Tea only","status":418}`. Text contains just the message. Rendering
adds Accept to existing Vary fields and preserves `Vary: *`. HEAD uses the
same representation length but sends no body, through the normal writer.

## Custom not-found handling

Register `B.on_not_found(Tag, id)` beside routes. It stores a new stage-tagged
identifier and uses the same middleware dispatcher and affine `next` contract
as other hooks. The registration does not appear in the manifest. Selected
handlers form a registration-ordered terminal onion on `Methods.NotFound`,
after ordinary middleware and pre-handler hooks. A handler may return its own
response or call `next(ctx)` to reach the next handler and finally the negotiated
default 404. Forwarded context changes reach later response hooks and observers.
`after_handle`, `map_response`, and conditional `on_error` run normally afterward.

This callback runs for a route miss, not a handler returning 404 or a 405 method
mismatch. The latter retains its Allow header. `B.not_found(ctx)` still explicitly
builds the default 404 response; it now uses the same error negotiation.

## Crash experiment and limit

`tests/servers/errors.bend` includes a deliberate `/crash` route calling
`IO.die(B.Res, 23, "BND-25 deliberate crash")`. `tests/errors.test.ts` starts a
fresh compiled native process, opens a keep-alive connection, gets a successful
response, then sends `/pending` on that connection. The pending handler sends
a channel signal and blocks on a different channel. A request to `/entered`
on another connection waits for that signal, proving the pending handler reached
its gate. Only then does a third request call `/crash`. There is no synthetic
load and no timing-based assumption about whether the pending handler started.

Observed on Linux with Bend 2.0.38:

- The process exits with code 23. Stderr contains the deliberate diagnostic.
- Neither the crash request nor the suspended request receives an HTTP response;
  both clients report socket errors.
- A new connection fails because the listener is gone.

The test asserts all three outcomes with bounded waits and always tears down
its process and client agent. It also verifies that recoverable typed failures
leave the server usable. Run `bun test --timeout 30000 tests/errors.test.ts`.
This measures `IO.die`, not every native panic or OS signal. It makes no claim
that unrelated crash primitives have a narrower scope.

Base defines `IO.die` as an `IO.OP.Halt`, `IO.exit` as `IO.OP.Exit`, and
`IO.try` unwraps a failed effect by calling `IO.die`. There is no supported
request-local exception catcher. Bendo runs handlers in one process;
`Process.run` can isolate a separate worker executable, but cannot move a
handler closure and its channel environment into that worker. An additional
probe evaluated an action into `IO.OP` and matched its Halt constructor: this
caught an immediate pure halt, but adding `IO.sleep(10)` before the halt made
the native executable exit 1 with `bend: runtime fail-stop`. Inspecting an IO
value this way therefore cannot wrap a general asynchronous request handler. Spawning an
IO task is concurrency within this process, not isolation. A timer race also
does not contain termination or cancel its losing action. Catch fallible
effects by matching their `Result`, map expected failures to `HttpError`, and
avoid `IO.try` on request effects that can fail.

For production, install the compiled binary at the path you configure and use
a process supervisor. For example, this systemd service restarts on termination:

```ini
[Unit]
Description=Bendo API
After=network.target
StartLimitIntervalSec=60
StartLimitBurst=10

[Service]
Type=simple
User=bendo
WorkingDirectory=/opt/bendo
ExecStart=/opt/bendo/server
Environment=PORT=3000
Restart=always
RestartSec=1

[Install]
WantedBy=multi-user.target
```

Create the service user and install the binary before enabling this unit.
`Restart=always` also handles explicit successful termination. A restart does
not save in-flight connections or in-memory state. Use durable storage for data
that must survive it; clients should retry only operations safe to repeat.
