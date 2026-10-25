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
length and empty payload. Transport errors close immediately.

After a successful closing send, the shell calls `shutdown(SHUT_WR)` through
the `effects/shutdown_write` effect, then runs [0005](0005-framing.md)'s bounded
drain: at most 4 MiB and one second, using timed receives, ending early at the
peer's EOF. The FIN follows the response bytes, so a client waiting for EOF sees
it right after the last response byte. This is the lingering close: closing a
socket with unread request bytes (a rejected body, a discarded pipelined
request) makes the kernel send an RST, which can destroy response bytes the
client has not read yet. The drain reads those bytes away until the client
closes its side.

Until BND-90, base had no write-side shutdown, so the FIN waited for the drain.
A client that kept its side open, which is what any HTTP client waiting for EOF
does, saw EOF about one second after the response, for every `Connection:
close` response, HTTP/1.0 request, and max-requests cap. The drain keeps its
one-second bound rather than a shorter one: it no longer delays the client,
and a shorter window would let request bytes still in flight on a slow link
arrive after the close and reset the connection. A peer that never closes holds
a descriptor for at most one second. Idle-timeout and EOF closes have no
response to protect and call `Socket.close` at once.

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

## Write deadline

BND-106 bounds the send of a buffered response. Before it, the shell called
`TCP.send_bytes`, which in Bend 2.0.38 waits for the socket to become writable
with no deadline. A client that asked for a large response and stopped reading
held the connection, the unsent bytes and the response's after-response hooks
forever. Streaming responses already used the bounded `Stream.send`.

The shell now sends with `TCP.try_send_bytes`, the deadline-aware send that
`Stream.send` uses, so no new effect is needed and the C and JavaScript builds
behave alike. The first call has a zero deadline: it takes what the socket
accepts at once and returns at once, so a response that fits in the socket
buffer, which is nearly every response, costs nothing extra. Whatever is left
goes out in windows of `write_timeout_ms` (default 30000 ms). After each window
that ends with bytes unsent, the pure `http/write_progress.bend` decides: if
the window shrank the unsent suffix, send another; if not, run the
after-response hooks and close the socket. The hooks also run exactly once when
the send completes or fails.

The deadline is idle progress, not a total. The read deadlines above are
absolute because the head and body limits bound what they read. Response size
has no such limit: a handler may send a 100 MB download, and a total deadline
would cut it off on any link slower than the size divided by the deadline.
Measured per window, a client that reads slowly but steadily gets the whole
body, while one that stops reading is closed between one and two windows after
its last read (the window in which it stopped still counts as progress). The
default matches the 30000 ms body deadline and the default stream write
timeout. A client that accepts a few bytes every window can still hold a
connection for as long as the transfer takes; that is the cost of not capping
download time.

The close is `Socket.close`, not the lingering close: there is no request to
protect, and the client is not reading. The window only measures bytes the
kernel accepted, so a client's own socket buffers absorb part of a response
before its first window stalls. `tests/write-deadline.test.ts` serves an
8 MiB buffered body with a 1000 ms window: a client that never reads is closed
within two windows plus slack while other clients are served, the hooks run
once, and a client reading 512 KiB every 200 ms gets the whole body.

## Verification

`bun test --timeout 30000 tests/http-connection.test.ts` drives compiled servers
through raw sockets, including a client sending one byte per 100 ms while a
second client completes requests. It checks sequential reuse, ordered pipelines,
partial suffixes, fixed/chunked body boundaries, HEAD framing, exact head limits,
leading CRLFs, absolute head/body deadlines, idle EOF, max requests, HTTP/1.0,
request/response close tokens, and rejection in a pipeline. For `Connection:
close`, HTTP/1.0, the max-requests cap, and a 400 with 32 KiB of unread request
bytes, it checks that EOF follows the last response byte within 400 ms or four
times the request's response latency, whichever is larger, while the client's
write side stays open. The suite also
compiles the pure state machine to JavaScript to check every split of a request
and its suffix, absolute deadlines, and buffered-head timestamps. A legacy byte
fixture checks mixed-case repeated Connection fields and binary payloads.

The test-only fetch preload and its `bunfig.toml` entry are removed. The ordinary
suite exercises Bun's pooled fetch against the actual server behavior.
