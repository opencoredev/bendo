# Run WebSocket handlers

Use `B.websocket_handlers` in a route to receive complete text or binary
messages. Bendo validates the [opening handshake](websocket.md), then calls your
`open`, `message`, and `close` templates on that connection. It handles masking,
fragmentation, ping/pong, close frames, and message limits.

Handlers are top-level definitions passed with `~`. Per-connection state is
`Data`. `open` and `message` return the next state; `close` receives the final
state once the socket has closed. For a complete native server including a
handle shared with an HTTP route, see
[`tests/servers/ws-session.bend`](../tests/servers/ws-session.bend).

```python
import Base
import ../src/main.bend as B
import ../src/ws/message.bend as M

def opened(state: Unit, handle: B.WebSocketHandle) -> IO(Unit):
  IO.pure(Unit, state)

def message(state: Unit, handle: B.WebSocketHandle, message: M.Message) -> IO(Unit):
  match message:
    case M.TextMessage{text}:
      do IO<Unit>:
        accepted : Bool <- B.websocket_send_text(handle, text)
        return state
    case M.BinaryMessage{bytes}:
      do IO<Unit>:
        accepted : Bool <- B.websocket_send_binary(handle, bytes)
        return state
    case _: IO.pure(Unit, state)

def closed(state: Unit, code: U32, reason: String) -> IO(Unit):
  IO.print("closed: " ++ U32.show(code) ++ " " ++ reason)

def handler(c: B.Context(Unit)) -> IO(B.Res):
  B.websocket_handlers(~Unit, ~Unit, ~opened, ~message, ~closed, c, Unit{}, B.websocket_config(), B.websocket_session_config())
```

`message` receives only `M.TextMessage` and `M.BinaryMessage`. Control frames
are handled by the framework. Ping gets exactly one pong with the same payload
until a peer close is received, including while waiting for a local close to
be acknowledged; unsolicited pong is ignored. Fragmented text is validated as UTF-8
when complete, including a code point split across fragments.

## Send from a handler or another route

The following helpers return `IO(Bool)`:

- `B.websocket_send_text(handle, text)` sends a UTF-8 text message. A
  surrogate or a value above U+10FFFF in `text` is sent as U+FFFD, so the
  frame is always valid UTF-8.
- `B.websocket_send_binary(handle, bytes)` sends octets unchanged.
- `B.websocket_ping(handle, bytes)` sends at most 125 payload bytes.
- `B.websocket_close(handle, code, reason)` begins a close handshake. Codes must
  be sendable RFC 6455/IANA codes and the UTF-8 reason must fit 123 bytes.

`True` means the bounded outbound mailbox accepted the command. It does not
mean the peer received it. `False` means full, closed, or invalid. A command
accepted behind a close is discarded after that close; no data is written
after closing begins. Check admission when delivery matters.

A valid close is never refused for a full mailbox. When the mailbox is full,
`B.websocket_close` shuts it, then puts the close in a reserved slot: it
returns `True`, every later send to the connection returns `False`, and the
connection writes the commands already queued (at most `mailbox_capacity`),
then the close. So a handler can always end its connection, even while
publications crowd its mailbox during `open`. Closes take effect in the order
they were admitted, and only the first is written: a close queued behind
another returns `True` but is ignored, and when two closes find the mailbox
full at once, one takes the slot and the other returns `False`. `False` from
`B.websocket_close` means the code or reason is invalid, or the connection is
already closing or closed.

Store the copyable handle in application state to send from another route or
connection. Bendo polls it alongside timed socket reads. Queued commands go out
back to back; a command sent to an idle connection waits at most `poll_max_ms`
(below). When the connection ends, commands still queued are discarded, so a
saved handle does not keep their payloads alive. Do not wait inside a
handler for an enqueued frame to be delivered: delivery resumes when the handler
returns. To send to every connection subscribed to a topic, see
[publish and subscribe](websocket-pubsub.md).

## Limits and timers

`B.websocket_session_config()` returns `WsConnection.Config` from
`src/ws/connection.bend`. Import that module to construct a configuration:

| Field | Default | Behavior |
| --- | --- | --- |
| `max_message` | 1048576 | Maximum total bytes in a text or binary message, across fragments. Exceeding it closes with 1009. |
| `mailbox_capacity` | 16 | Maximum queued outbound commands; zero is normalized to one. |
| `poll_ms` | 10 | Socket wait before polling outbound commands again, while the connection is active; zero becomes one. |
| `poll_max_ms` | 100 | Cap for the idle backoff: each empty wait doubles toward it, and received bytes or a queued command reset it. Set it to `poll_ms` to disable backoff. |
| `idle_ms` | 60000 | Time without received socket bytes before initiating close 1001, reason `idle timeout`. Zero disables it. |
| `ping_ms` | 0 | Optional interval for automatic empty server pings. Zero disables it. |
| `close_ms` | 1000 | Wait after sending a local close for the peer's close; zero becomes one. |
| `write_ms` | 30000 | Absolute budget per frame write, including partial-send retries; zero becomes one. |

An idle connection backs off its socket wait from `poll_ms` to `poll_max_ms`,
trading up to `poll_max_ms` of latency on the first command after a quiet
period for less CPU. With the defaults, 1,000 idle connections used about 10%
of a core on our test server, against 83% for a fixed 5 ms poll. See
[the concurrency decision](decisions/0015-websocket-mailbox.md) for details.

Keepalive pings alone do not reset the idle timer. Received pong bytes do. This
is an inbound-idle policy, not a matching-pong watchdog. Deadline checks run at
IO boundaries and cannot interrupt user code. Socket read waits are shortened
to the next timer deadline.

Writes are sequential. The default mailbox admits at most 16 MiB of queued
message payload, plus the current frame, receive/assembly state, and codec
temporaries. A slow reader reaches the frame write deadline instead of growing
an unbounded output queue. The decision above gives the exact bound and its
application-allocation caveat.

## Closure

A peer close gets one identical echo and one `close(code, reason)` callback.
A close that arrives between a message's fragments discards the partial
message.
An empty peer close reports 1005 with an empty reason. A server close waits for
the peer's close, then reports that peer's code and reason. If the peer never
acknowledges, the callback reports 1006. Abrupt EOF and transport failures also
report 1006, without putting that reserved code on the wire.

Malformed frames and sequences close with 1002; invalid text or close-reason
UTF-8 closes with 1007; an excessive frame or assembled message closes with
1009. These failures send one close and end immediately. If that write fails,
the callback reports 1006. `open` and `close` never run for a refused or replaced
handshake. Request response observers and access logging still report the 101
before the session starts.

## Verify

`bun test tests/ws-session.test.ts --timeout 30000` runs a real Bun client and
raw masked-frame clients against the compiled native server. The pure policy's
laws and independent receive table live in `proof/ws-session-laws.bend` and
`proof/ws-session-spec.bend`; `bun run prove` checks them with Lean.
