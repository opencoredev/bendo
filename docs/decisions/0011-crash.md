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
- `http_error_private_with_headers` and `http_error_exposed_with_headers`: the
  same two results for a context with any accumulated response headers. The
  spec lists the rendered response's headers before wire framing
  (`Spec.headers`; the writer then sets `Content-Length` and drops
  `Transfer-Encoding` as for any response): the negotiated
  `Content-Type` first, every other accumulated header except `Content-Type`
  and `Vary` in its original order, then one `Vary` field. That field copies
  the existing `Vary` values byte for byte, separated by `, `, and appends
  `Accept`. If any existing value is `*` once SP and HTAB are removed, the
  field is just `*`.
- `http_error_inadmissible_fallback`: validation applies to that effective
  list, after the Vary merge and the Content-Type replacement. If any header
  in it is not admissible, every error renders the empty 500, whatever its
  code, message or exposure. `Spec.admissible` restates RFC 9110 field syntax:
  a nonempty token name in ASCII lowercase, and a value of field octets (HTAB,
  SP, visible ASCII, obs-text) that neither starts nor ends with SP or HTAB.
  It shares only the token and field-octet character classes with `Bytes`.
  `http_error_validity_spec` proves `Response.valid` equals the spec's check,
  so no header byte the spec rejects reaches the wire.
  `http_error_invalid_header_fallback` is the instance with an `x-note` value
  containing a line feed.
- `http_error_head_no_payload`: a HEAD request's error response is written with
  no payload.

Because validation reads the effective headers, an accumulated `Content-Type`
that the error replaces cannot fail the response. An accumulated Vary value of
`Origin` plus a trailing space is accepted, because the merged field is
`Origin , Accept`; the same value with a leading space still fails. `c.text`, `c.json` and the other
body helpers keep their stricter rule: they reject any invalid accumulated
header, including one they replace.

- `http_error_accept_policy`: `Errors.accepts_json` equals the Accept policy
  in `proof/accept-spec.bend` for every field value, absent or present. The
  spec restates the policy below without calling the Errors module: its own
  quote-aware segmenter, the RFC 9110 qvalue grammar, and the range and
  parameter rules. It shares the byte tests for `0`, `1`, digits, `.`, `"`,
  `\` and the delimiter, plus the shared SP/HTAB trimmer and ASCII lowercasing.
  `http_error_accept_field` proves the field read is the request's first
  `accept` field decoded as UTF-8, and none when it is absent or invalid.
- `http_error_private_negotiated` and `http_error_exposed_negotiated` combine
  these: for any request and any accumulated headers, with no hypothesis on
  negotiation, the error renders `Spec.private_with` or `Spec.exposed_with`
  in the representation the spec's policy picks from that request.

The earlier laws take the JSON-or-text choice as a hypothesis on
`Errors.accepts_json`, or use the listed samples. With
`http_error_accept_policy` that hypothesis is the spec's policy. The spec also
pins 24 example fields and the absent field, including every Accept value
the integration tests send.

These laws cover `C.error` and everything built on it: `B.error`,
`B.result` on `Fail`, and the default 404 from `B.not_found` and route misses.
Three framework responses do not go through it and are not covered: the 405
for a method mismatch (built with `Context.body` and an `Allow` header), the
`400 Bad Request` text for a malformed query string, and transport-level
rejections from the HTTP parser.

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
field opts into JSON, provided its quality is positive. Elements are split at
commas and parameters at semicolons, outside quoted strings; a backslash
inside a quoted string escapes the next character. Each parameter is a name
or a single `name=value`; names are not checked further, so an empty
parameter (`application/json;`) or an empty name (`application/json;=x`) is
ignored rather than rejected. The choice only selects JSON or text, never what
a private error reveals. The `q` parameter must match HTTP's qvalue grammar
(`0` or `1`, then optionally a dot and at most three digits, only zeros after
`1`). A zero quality, a malformed quality, a bare `q`, or a parameter with two
`=` signs excludes that range, and an unterminated quoted string excludes the
whole field. Wildcards (`*/*`, `application/*`), missing Accept, invalid
UTF-8, and other media types use `text/plain; charset=utf-8`.
This is an explicit JSON opt-in, not a full preference ranking: a positive JSON
range selects JSON even if text has higher quality. Repeated Accept fields
follow the context accessor's first-field policy.

JSON uses `application/json; charset=utf-8` and the shared writer's escaping:
`{"error":"Tea only","status":418}`. Text contains just the message. Rendering
merges existing Vary fields into one, appends Accept, and preserves `Vary: *`. HEAD uses the
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
