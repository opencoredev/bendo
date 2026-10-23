# Stream a response

Use `B.stream` to send response chunks as a pull producer supplies them. It works
with ordinary routes, middleware, response hooks, request IDs and server timing.
The complete native example is [the streaming fixture](../tests/servers/stream.bend).

A producer owns its state and returns one of these values from
`src/http/stream_types.bend`:

- `Chunk{bytes, state}` supplies octets and the next state.
- `End{state}` completes the response.
- `Failed{state}` aborts the connection without a terminating chunk.

The state may be affine, so a later proxy producer can own an upstream socket.
[Server-Sent Events](sse.md) use the same transport.
The cleanup template receives the final state exactly once, including when the
client disconnects, a write times out, middleware replaces the response, or a
bodyless response suppresses the producer. Cleanup must release any resources
the producer owns. Bendo does not pull a suppressed producer.

## Register a producer

`B.stream(~Vars, ~State, ~step, ~cleanup, context, initial, config)` returns
`IO(B.Res)`. Set status and headers on `context` before calling it. The producer
has type `State -> IO(StreamTypes.Step<State>)`; cleanup has type
`State -> IO(Unit)`. For example:

```python
import Base
import ../src/main.bend as B
import ../src/http/stream_types.bend as S

def step(state: Nat) -> IO(S.Step<Nat>):
  match state:
    case 0n: IO.pure(S.Step<Nat>, S.End{0n})
    case 1n+n: IO.pure(S.Step<Nat>, S.Chunk{[104, 105, 10], n})

def cleanup(state: Nat) -> IO(Unit):
  IO.pure(Unit, Unit{})

def handler(c: B.Context(Unit)) -> IO(B.Res):
  B.stream(~Unit, ~Nat, ~step, ~cleanup, B.header(c, "content-type", "text/plain"), 3n, B.stream_config())
```

The response contains three `hi` lines. Return this response from a route
handler served by `B.serve` or `B.serve_with`. Network-free `B.handle` and the
older buffered pending adapters cancel streams and return an empty 500.
They cannot represent an affine transport body. Their observers see that 500.

`B.stream_config()` returns `StreamTypes.Config{30000, 65536}`:
`write_timeout_ms` is the absolute budget for each response-head or encoded-chunk
write, and `max_chunk_bytes` is the maximum payload in one producer chunk.
Use a positive write budget. Bendo rejects an oversized or non-octet chunk by
aborting the connection; it does not truncate it. Empty chunks are skipped.
Only `End` emits `0\r\n\r\n`. No trailers are sent.

## Backpressure and resource limits

The server sends the head first, then pulls one chunk. It validates and frames
that chunk, sends it with `TCP.try_send_bytes`, and only then pulls again.
This is Base's byte-preserving form of `TCP.try_send`. A timed send returns the
unsent suffix; retrying that suffix uses the remaining absolute write budget.
A full socket parks the computation rather than spinning or starting a producer
task. On deadline expiry, Bendo closes the connection and drops pipelined input.
A peer making tiny progress still cannot restart the current chunk's deadline.

Bendo holds at most the current producer state and one chunk/frame plus bounded
runtime/socket buffers. Keep producer state bounded too: do not accumulate all
previous chunks or prebuild the complete response. A producer allocates a chunk
before Bendo can validate its size, so the configured maximum is a rejection
boundary, not a limit on arbitrary application allocation. Octet lists use much
more memory than their wire size; see [the byte decision](decisions/0002-bytes.md).

The write deadline bounds socket backpressure. It does not cancel arbitrary
producer or cleanup IO, preempt pure computation, or bound an infinite sequence
of empty chunks. Producers must use bounded upstream IO and terminate or yield
useful chunks; do not wrap socket-owning work in `IO.within`, which leaves its
losing computation alive. There is no total stream lifetime limit, so an SSE
connection may stay open while each write completes within its budget.

## HTTP and lifecycle behavior

Streams use HTTP/1.1 chunked encoding. Bendo removes application Content-Length
and Transfer-Encoding fields before setting `transfer-encoding: chunked`.
HEAD, informational responses, 204, 205, 304 and successful CONNECT responses
never send a body. HEAD has no fabricated representation length; 205 has
`content-length: 0` except for successful CONNECT. Successful CONNECT always
omits both framing fields, as do other bodyless streaming responses.
HTTP/1.0 streaming is rejected with an empty 505 before sending the head.

Response hooks run before transport. Bendo finalizes request ID and server timing,
selects the stream, and applies Date before sending the head. A private response
marker ties a registered producer to the response returned by middleware; it is
removed before sending or returning a response. A replacement that drops that
marker cancels the producer. Duplicate or late registrations fail as empty 500s
and clean up their rejected producer. Registration closes when handling finishes,
including after timeout middleware has returned.

After a successful stream, the normal connection policy handles keep-alive and
pipelined requests in order. An explicit `Failed`, invalid chunk, timeout or send
error aborts the connection. The status has already been sent, so Bendo cannot
replace it with a 500. `on_after_response` runs after the completed or failed send
attempt, after producer cleanup; it runs once for the selected response.

## Verify

Run `bun test tests/stream.test.ts --timeout 30000` for small socket tests.
The universal `stream_rfc_roundtrip` law checks successful finite body-bearing
streams against a separate RFC 9112 section 7.1 parser in
[`proof/stream-rfc-spec.bend`](../proof/stream-rfc-spec.bend). That module imports
only Base and calls no Bendo encoder or decoder helpers. It checks lowercase
hexadecimal sizes, CRLF after each size and payload, a zero last-chunk, and an
empty trailer section. For every admissible octet partition, including empty
producer chunks, it returns exactly the concatenated payload and untouched
suffix. `stream_rfc_last_chunk` also proves that the first zero last-chunk ends
parsing: subsequent bytes cannot become more chunks in the same body.

The proof's configured U32 limit bounds the **total** payload, at most
4,294,967,295 bytes. The runtime's default 65,536-byte limit applies to **each
producer chunk**; it does not cap the total response. The runtime can send longer
or infinite streams, but those are outside this finite round-trip law. Bodyless
responses and aborted streams are also outside it and have socket tests instead.
The existing `stream_roundtrip`, `stream_chunk_tail` and `stream_empty_chunk`
laws remain unchanged.

Run the memory test only on an isolated Boat VM with the pinned toolchain:

```sh
BENDO_STREAM_MEMORY=1 bun test tests/stream.test.ts --timeout 30000
```

It downloads and checks 1 MiB and 100 MiB without retaining the whole response,
reports server peak RSS from `/proc/<pid>/status`, then compares paused 4 MiB
and 100 MiB requests. The paused peer advertises a small receive buffer and
never reads until after the write deadline. Samples report RSS, kernel send
queue bytes and producer pulls; the test checks that pulls stop, queued data
stays bounded across sizes, cleanup/observers run once, and the aborted stream
ends without a terminal chunk. Assertions compare growth between sizes rather
than imposing a runner-specific absolute RSS threshold.
