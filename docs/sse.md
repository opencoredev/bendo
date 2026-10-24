# Send Server-Sent Events

Use `B.stream_sse` to send an `EventSource` stream from a route. It runs on
[`B.stream`](streaming.md), so it keeps the same backpressure, write deadline,
cleanup and middleware behavior. The complete native example is
[the SSE fixture](../tests/servers/sse.bend).

## Write a producer

An SSE producer owns its state, like a `B.stream` producer, and returns one of
these values from `src/http/sse_types.bend`:

- `Send{frame, state}` writes one frame.
- `Idle{state}` means nothing is ready yet. Bendo may write a heartbeat, waits
  `idle_ms`, then pulls again with the returned state.
- `End{state}` completes the response.
- `Failed{state}` aborts the connection without a terminating chunk.

This handler sends numbered events and resumes after the id the browser last
saw:

```python
import Base
import ../src/main.bend as B
import ../src/http/sse_types.bend as E

def cleanup(next: U32) -> IO(Unit):
  IO.pure(Unit, Unit{})

def send(+next: U32, done: Bool) -> IO(E.Step<U32>):
  match done:
    case True{}: IO.pure(E.Step<U32>, E.End{next})
    case False{}:
      do IO<E.Step<U32>>:
        IO.sleep(1000)
        return E.Send{B.sse_message(Some{"tick"}, "event " ++ U32.show(next), Some{U32.show(next)}, None{}), (next + 1 : U32)}

def tick(next: U32) -> IO(E.Step<U32>):
  +n = next
  send(n, U32.is_lt(10, n))

def after(last: Maybe<&2, String>) -> U32:
  match last:
    case None{}: 1
    case Some{id}: (Maybe.default(&2, U32, U32.read(id), 0) + 1 : U32)

def handler(+c: B.Context(Unit)) -> IO(B.Res):
  B.stream_sse(~Unit, ~U32, ~tick, ~cleanup, c, after(B.last_event_id(Unit, c)), B.sse_config())
```

`B.last_event_id(Vars, c)` returns the request's `Last-Event-ID` header, which
a browser sends when it reconnects. It is `None{}` on the first connection or
when the value is not valid UTF-8. Call it in the handler and build the initial
state from it. The browser reconnects whenever a stream ends. Answer 204 with
an ordinary response when there is nothing left to send, which tells
`EventSource` to stop.

## Frames

`B.sse_message(event, data, id, retry)` builds a message from Strings, encoded
as UTF-8. `B.sse_data(data)` is a message with only data. `B.sse_comment(text)`
is a comment line, which receivers ignore. Lower-level frames are in
`src/http/sse.bend`, with octet fields:

```python
type Frame is Data:
  Message{event: Maybe<&2, List<&2, U32>>, data: List<&2, U32>, id: Maybe<&2, List<&2, U32>>, retry: Maybe<&2, U32>}
  Comment{text: List<&2, U32>}
```

A message is written as these lines, then an empty line:

| Field | Written | Omitted when |
| --- | --- | --- |
| `event` | `event: <name>` | `None{}` |
| `data` | one `data: <line>` per line | never; empty data writes `data: ` |
| `id` | `id: <id>` | `None{}` |
| `retry` | `retry: <decimal ms>` | `None{}` |

Data may contain any text. Each CR, LF or CRLF in data starts a new `data:`
line, so the browser's `MessageEvent.data` has an LF there. A CR followed by an
LF counts as one line break. An empty event name means `message`, as it does
in a browser. `Some{""}` as the id resets the browser's last event id.

Bendo checks each frame when it is sent. It rejects an event name, id or
comment that contains CR or LF, an id that contains NUL, and any field whose
octets are not exactly the UTF-8 encoding of Unicode scalar values. The whole
frame is refused and the stream aborts as if the producer returned `Failed`;
Bendo never strips, escapes, replaces or truncates the value. Earlier frames
have already been sent. Without this check, a line break in an id such as
`"1\ndata: x"` would end the id early and inject a field, and a stray octet
such as `0xFF` would reach the browser as U+FFFD. Strings passed to
`B.sse_message`, `B.sse_data` and `B.sse_comment` always pass the UTF-8 check.

## Configuration

`B.sse_config()` returns `SseTypes.Config{StreamTypes.Config{30000, 65536}, 15000, 250, []}`:

| Field | Default | Meaning |
| --- | --- | --- |
| `stream` | `{30000, 65536}` | The [`B.stream` config](streaming.md#register-a-producer): write budget and maximum frame size in octets. A frame over the maximum aborts the stream. |
| `heartbeat_ms` | `15000` | After this long without a write, the next `Idle` writes a heartbeat. `0` disables heartbeats. |
| `idle_ms` | `250` | How long Bendo waits after `Idle` before pulling again. It waits less when a heartbeat is due sooner. |
| `comment` | `[]` | Heartbeat text, sent as `:` text LF. The default sends `:` and LF. |

Heartbeats keep proxies and load balancers from closing a quiet connection.
They come only from `Idle`, so return `Idle` instead of blocking in the
producer for longer than the heartbeat interval. A producer that sleeps for a
minute sends nothing during that minute. A heartbeat comment containing CR or
LF aborts the stream when the first heartbeat is due.

## Headers

`B.stream_sse` sets `content-type: text/event-stream`,
`cache-control: no-cache` and `x-accel-buffering: no`, the last of which stops
nginx from buffering the stream. It replaces any `content-type` or
`cache-control` the handler set and removes `content-encoding`, so the stream
is never sent compressed. Other headers and the status pass through. HEAD,
bodyless statuses and HTTP/1.0 behave as they do for
[`B.stream`](streaming.md#http-and-lifecycle-behavior).

## Proofs

The laws in `LAWS.bend` check the encoder against an independent parser in
[`proof/sse-spec.bend`](../proof/sse-spec.bend). That parser imports only Base
and follows WHATWG HTML section 9.2.6, "Interpreting an event stream":
CRLF, LF and CR line endings, comments, one optional space after the colon,
the persistent last event id, ids with NUL ignored, digit-only retry values
read in base ten, and incomplete events discarded at the end of the stream. It
parses octets. A browser first decodes the stream as UTF-8, replacing invalid
sequences with U+FFFD. Admissible frames contain only exact UTF-8 encodings of
Unicode scalar values, which that decoding leaves unchanged, and CR, LF, colon,
space and NUL are ASCII. So for admissible frames the parsed octets are the
UTF-8 encoding of the text the browser sees. That last step is the standard
property of UTF-8, stated here rather than proven; the laws do not model the
replacement decoder.

- `sse_roundtrip`: for every list of admissible frames with arbitrary text
  data, the parser reports each message's retry value, then one event with its
  type, its data with line breaks read as LF, and the id in force. Comments
  report nothing.
- `sse_encode_rejects_unsafe`: the runtime sends exactly the admissible frames,
  unchanged, and nothing for the rest.
- `sse_sent_frame_exact`: for any frame, whatever the runtime sends parses as
  exactly that frame's observations, so no input can inject a field or event.
- `sse_text_utf8`: every String of Unicode scalar values, as `B.sse_message`
  encodes it, passes the UTF-8 check, so admissibility excludes no text.
- `sse_heartbeat_ignored`: a heartbeat at any line start leaves the parser's
  state unchanged.
- `sse_retry_decimal` and `sse_retry_value`: retry is written as ASCII digits
  whose base-ten value is the number sent.

The laws cover the octets of each frame. Admissible means every field is
exactly the UTF-8 encoding of Unicode scalar values, an event name, id or
comment has no CR or LF, and an id has no NUL. Transport behavior, timing and
headers are covered by `tests/sse.test.ts`, which also runs the Bend spec
parser as JavaScript against a separate TypeScript parser on edge-case
streams.

## Verify

Run `bun test tests/sse.test.ts --timeout 30000`. For a real browser, start
the fixture on this machine's Tailscale address:

```sh
bend tests/servers/sse.bend -o /tmp/bendo-sse
HOST="$(tailscale ip -4)" PORT=24990 /tmp/bendo-sse
```

Open `http://<tailscale-ip>:24990/`. The page receives events 1 to 10 over
two connections: the server ends the first after event 4, and the browser
reconnects with `Last-Event-ID: 4`. A final reconnect after event 10 gets 204.
The page shows PASS and sets `document.body.dataset.result` to `pass` when the
ids arrive in order, there were two connections and the resumed event says
`event 5 after 4`.
