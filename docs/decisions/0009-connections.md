# 0009: Persistent connections with bounded reads

BND-11 makes `B.serve` reuse HTTP/1.1 connections. Each spawned connection
processes one request and response at a time. The pure `http/connection.bend`
module holds the incremental body/parser state, answered-request count, current
phase deadline, and timestamp of the last received bytes. Its actions tell the
IO shell to read, respond, reject, or close. The shell owns the socket throughout;
it never races an affine socket through `IO.within`.

After a response, the connection feeds the body reader's unused suffix directly
into a fresh request state. Buffered requests run before another receive. A
partial next head retains the timestamp of the receive containing its first
bytes, so handler time does not restart that head's deadline. Responses and
handler side effects occur in request order.

## Persistence and closure

HTTP/1.1 persists unless the request or response has a `close` Connection token,
`keep_alive` is False, or the response reaches `max_requests`. All repeated
Connection fields and comma-separated tokens are checked case-insensitively.
`max_requests` zero still allows the first request, then closes. HTTP/1.0 always
closes, even with `Connection: keep-alive`; HTTP/1.0 persistence is unsupported.

400, 413, 417, and 431 responses close, including those returned by handlers.
Read timeouts during an incomplete request return 408 and close. Informational
handler responses close, including a bare 101. An accepted `B.websocket` 101
instead hands the socket and every buffered octet to its session, and HTTP
parsing stops ([the WebSocket guide](../websocket.md)). Buffered
requests after a closing response are discarded without dispatch.

Every intentional final close replaces all application Connection fields with
one `connection: close`. `B.handle` has already applied the response writer's
framing, so the shell preserves its headers and payload, including HEAD's GET
length and empty payload. Transport errors close immediately. After a successful
closing send, teardown retains [0005](0005-framing.md)'s bounded drain: at most
4 MiB and one second, using timed receives. A peer can read the response before
that drain ends. Base has no write-side shutdown, so EOF may follow later.

The legacy `Serve.serve` and two-field `Serve.Config` byte-handler API remains
single-request. Its bounded head transformation replaces Connection fields with
`close`, preserving the status, other headers and payload. New applications use
`B.serve` for persistence and the full config.

## Limits and deadlines

The default head budget is 65536 octets, including request line, discarded
leading CRLFs, header lines, and terminating blank line. Exactly the budget fits;
the next head octet returns 431. Coalesced body and next-request bytes do not
count toward that request's head budget. Malformed syntax returns 400.

The idle deadline starts on accept and after each completed response with no
buffered next request. It defaults to 5000 ms. With no next-request bytes, expiry
or EOF closes silently. The first octet starts the absolute head deadline,
including a discarded CRLF; the default is 10000 ms. Framing a pending body
starts its separate absolute deadline, default 30000 ms. Progress never restarts
either deadline. EOF in an incomplete head or body returns 400.

Each receive uses `TCP.try_recv_bytes` with the remaining monotonic deadline.
`IO.spawn` lets a slow reader yield while other clients run. This bounds socket
reads; it does not cancel handlers or preempt pure computation (plan decision 9).
The default body budget remains 1 MiB and max requests remains 100.

## Verification

`bun test --timeout 30000 tests/http-connection.test.ts` drives compiled servers
through raw sockets, including a client sending one byte per 100 ms while a
second client completes requests. It checks sequential reuse, ordered pipelines,
partial suffixes, fixed/chunked body boundaries, HEAD framing, exact head limits,
leading CRLFs, absolute head/body deadlines, idle EOF, max requests, HTTP/1.0,
request/response close tokens, and rejection in a pipeline. The suite also
compiles the pure state machine to JavaScript to check every split of a request
and its suffix, absolute deadlines, and buffered-head timestamps. A legacy byte
fixture checks mixed-case repeated Connection fields and binary payloads.

The test-only fetch preload and its `bunfig.toml` entry are removed. The ordinary
suite exercises Bun's pooled fetch against the actual server behavior.
