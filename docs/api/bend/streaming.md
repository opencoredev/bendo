# Streaming and real time

Responses that outlive one buffered body: pull-based streams, Server-Sent
Events, WebSockets with publish and subscribe, static files and the reverse
proxy. The guides explain each transport in depth:
[streaming](../../streaming.md), [Server-Sent Events](../../sse.md),
[the WebSocket handshake](../../websocket.md),
[WebSocket handlers](../../websocket-sessions.md),
[publish and subscribe](../../websocket-pubsub.md),
[static files](../../static.md) and [the proxy](../../proxy.md).

Examples on this page are one Bend program and share this setup. The
constructors of `B.StreamStep` and `B.SseStep` live in
`src/http/stream_types.bend` and `src/http/sse_types.bend`, so producers import
those modules too.

```bend
import Base
import ./bendo/main.bend as B
import ./bendo/http/stream_types.bend as StreamTypes
import ./bendo/http/sse_types.bend as SseTypes
import ./bendo/ws/connection.bend as W
import ./bendo/ws/message.bend as M
import ./bendo/ws/pubsub.bend as P

type ExUser is Data:
  ExUser{name: String}

def ex_release_nat(state: Nat) -> IO(Unit):
  IO.pure(Unit, Unit{})

def ex_release_u32(state: U32) -> IO(Unit):
  IO.pure(Unit, Unit{})

def ex_release_unit(state: Unit) -> IO(Unit):
  IO.pure(Unit, Unit{})
```

## Streams

### `B.StreamConfig`

```bend signature
def StreamConfig() -> Data

type Config is Data:
  Config{write_timeout_ms: U32, max_chunk_bytes: U32}
```

Settings for a streamed response, the same type as `StreamTypes.Config`.
`write_timeout_ms` is the absolute budget for writing the head and for each
encoded chunk; use a positive value. `max_chunk_bytes` is the largest payload
one producer chunk may carry: a larger chunk aborts the connection rather than
being truncated.

```bend
def ex_quick_writes() -> B.StreamConfig:
  StreamTypes.Config{5000, 16384}
```

### `B.StreamStep`

```bend signature
def StreamStep(-State: Type) -> Type

type Step<-State: Type> is Type:
  Chunk{bytes: List<&2, U32>, state: State}
  End{state: State}
  Failed{state: State}
```

What a producer returns from each pull. `Chunk` sends octets (0 to 255) and
carries the next state; an empty chunk is skipped. `End` completes the body.
`Failed` aborts the connection without a terminating chunk. `State` is a
`Type`, so a producer can own a socket or a file.

```bend
def ex_countdown(left: Nat) -> IO(B.StreamStep(Nat)):
  match left:
    case 0n: IO.pure(B.StreamStep(Nat), StreamTypes.End{0n})
    case 1n+n: IO.pure(B.StreamStep(Nat), StreamTypes.Chunk{[104, 105, 10], n})
```

### `B.stream_config`

```bend signature
def stream_config() -> B.StreamConfig
```

The default stream settings, `StreamTypes.Config{30000, 65536}`: a 30-second
write budget and chunks of at most 64 KiB. The limit applies to each chunk,
not to the whole response.

```bend
def ex_default_stream() -> B.StreamConfig:
  B.stream_config()
```

### `B.stream`

```bend signature
def stream(~Vars: Data, ~State: Type, ~step: State -> IO(B.StreamStep(State)), ~cleanup: State -> IO(Unit), +c: B.Context(Vars), state: State, config: B.StreamConfig) -> IO(B.Res)
```

Returns a response whose body `step` produces, starting from `state`. Set the
status and headers on `c` first. Bendo sends the head, then pulls one chunk
at a time with chunked encoding, pulling again only after the previous chunk
is written; HTTP/1.0 clients get an empty 505. `cleanup` receives the final
state exactly once, also when the client disconnects, a write times out,
middleware replaces the response, or a HEAD or bodyless status means the
producer is never pulled. Network-free `B.handle` cannot carry a stream and
returns an empty 500.

```bend
def ex_hi_lines(c: B.Ctx) -> IO(B.Res):
  B.stream(~Unit, ~Nat, ~ex_countdown, ~ex_release_nat, B.header(c, "content-type", "text/plain"), 3n, B.stream_config())
```

### `B.stream_sized`

```bend signature
def stream_sized(~Vars: Data, ~State: Type, ~step: State -> IO(B.StreamStep(State)), ~cleanup: State -> IO(Unit), +c: B.Context(Vars), state: State, config: B.StreamConfig, length: Nat) -> IO(B.Res)
```

`B.stream` for a body of exactly `length` octets. The response carries
`content-length: <length>` and raw octets with no chunked framing, so
HTTP/1.0 clients can receive it, and HEAD gets the same head fields as GET.
A chunk that would pass `length` aborts the connection unsent, and so does an
`End` before `length` octets, so the client sees a short body rather than a
wrong one.

```bend
def ex_sized_lines(c: B.Ctx) -> IO(B.Res):
  B.stream_sized(~Unit, ~Nat, ~ex_countdown, ~ex_release_nat, c, 3n, B.stream_config(), 9n)
```

## Server-Sent Events

### `B.SseConfig`

```bend signature
def SseConfig() -> Data

type Config is Data:
  Config{stream: B.StreamConfig, heartbeat_ms: U32, idle_ms: U32, comment: List<&2, U32>}
```

Settings for `B.stream_sse`, the same type as `SseTypes.Config`. `stream` is
the write budget and the largest frame in octets; a larger frame aborts the
stream. After `heartbeat_ms` without a write, the next `Idle` step writes the
heartbeat `:` `comment` LF (`0` disables heartbeats), and `idle_ms` is how
long Bendo waits after `Idle` before pulling again. A `comment` containing CR
or LF aborts the stream when the first heartbeat is due.

```bend
def ex_chatty_sse() -> B.SseConfig:
  SseTypes.Config{B.stream_config(), 5000, 100, [112, 105, 110, 103]}
```

### `B.SseFrame`

```bend signature
def SseFrame() -> Data

type Frame is Data:
  Message{event: Maybe<&2, List<&2, U32>>, data: List<&2, U32>, id: Maybe<&2, List<&2, U32>>, retry: Maybe<&2, U32>}
  Comment{text: List<&2, U32>}
```

One event-stream frame, with octet fields, from `src/http/sse.bend`. Build
frames with `B.sse_message`, `B.sse_data` and `B.sse_comment`, which encode
Strings as UTF-8. Bendo checks each frame as it is sent and aborts the stream,
as if the producer returned `Failed`, when an event name, id or comment
contains CR or LF, an id contains NUL, or a field is not valid UTF-8.
[Frames](../../sse.md#frames) shows how each field is written.

```bend
type ExFeed is Data:
  ExFeed{frames: List<&2, B.SseFrame>}
```

### `B.SseStep`

```bend signature
def SseStep(-State: Type) -> Type

type Step<-State: Type> is Type:
  Send{frame: B.SseFrame, state: State}
  Idle{state: State}
  End{state: State}
  Failed{state: State}
```

What an SSE producer returns from each pull. `Send` writes one frame. `Idle`
means nothing is ready: Bendo may write a heartbeat, waits `idle_ms`, then
pulls again with the returned state. Heartbeats come only from `Idle`, so
return it rather than block for longer than the heartbeat interval. `End` and
`Failed` work as they do for `B.StreamStep`.

```bend
def ex_feed(state: ExFeed) -> IO(B.SseStep(ExFeed)):
  match state:
    case ExFeed{Nil{}}: IO.pure(B.SseStep(ExFeed), SseTypes.End{ExFeed{[]}})
    case ExFeed{f <> rest}: IO.pure(B.SseStep(ExFeed), SseTypes.Send{f, ExFeed{rest}})
```

### `B.sse_config`

```bend signature
def sse_config() -> B.SseConfig
```

The default SSE settings, `SseTypes.Config{StreamTypes.Config{30000, 65536}, 15000, 250, []}`:
the default stream settings, a heartbeat after 15 seconds without a write, a
250 ms wait after `Idle`, and an empty heartbeat comment, which sends `:` and
LF.

```bend
def ex_default_sse() -> B.SseConfig:
  B.sse_config()
```

### `B.sse_message`

```bend signature
def sse_message(event: Maybe<&2, String>, data: String, id: Maybe<&2, String>, retry: Maybe<&2, U32>) -> B.SseFrame
```

A message frame. `None{}` omits the event name, id or retry field. Each CR, LF
or CRLF in `data` starts a new `data:` line, which the browser reads back as
LF. `Some{""}` as the id resets the browser's last event id, and `retry` is
the reconnection delay in milliseconds.

```bend
def ex_update(seq: U32, text: String) -> B.SseFrame:
  B.sse_message(Some{"update"}, text, Some{U32.show(seq)}, Some{3000})
```

### `B.sse_data`, `B.sse_comment`

```bend signature
def sse_data(data: String) -> B.SseFrame
def sse_comment(text: String) -> B.SseFrame
```

`B.sse_data(data)` is a message with only data, which a browser delivers as a
`message` event. `B.sse_comment(text)` is a comment line, written as `:` text
LF, which receivers ignore.

```bend
def ex_greeting() -> ExFeed:
  ExFeed{[B.sse_comment("connected"), B.sse_data("hello")]}
```

### `B.last_event_id`

```bend signature
def last_event_id(-Vars: Data, c: B.Context(Vars)) -> Maybe<&2, String>
```

The request's `Last-Event-ID` header, which a browser sends when it
reconnects. It is `None{}` on the first connection or when the value is not
valid UTF-8. Build the producer's initial state from it.

```bend
def ex_resume_after(last: Maybe<&2, String>) -> U32:
  match last:
    case None{}: 1
    case Some{id}: (Maybe.default(&2, U32, U32.read(id), 0) + 1 : U32)

def ex_first_event(c: B.Ctx) -> U32:
  ex_resume_after(B.last_event_id(Unit, c))
```

### `B.stream_sse`

```bend signature
def stream_sse(~Vars: Data, ~State: Type, ~step: State -> IO(B.SseStep(State)), ~cleanup: State -> IO(Unit), c: B.Context(Vars), state: State, +config: B.SseConfig) -> IO(B.Res)
```

Returns an event-stream response whose frames `step` produces. It runs on
`B.stream`, so backpressure, the write deadline and `cleanup` behave the same.
It sets `content-type: text/event-stream`, `cache-control: no-cache` and
`x-accel-buffering: no`, replacing any `content-type` or `cache-control` the
handler set and removing `content-encoding`. The browser reconnects whenever
the stream ends; answer an ordinary 204 when there is nothing left to send.

```bend
def ex_tick_send(+next: U32, done: Bool) -> IO(B.SseStep(U32)):
  match done:
    case True{}: IO.pure(B.SseStep(U32), SseTypes.End{next})
    case False{}:
      do IO<B.SseStep(U32)>:
        IO.sleep(1000)
        return SseTypes.Send{B.sse_message(None{}, "event " ++ U32.show(next), Some{U32.show(next)}, None{}), (next + 1 : U32)}

def ex_tick(next: U32) -> IO(B.SseStep(U32)):
  +n = next
  ex_tick_send(n, U32.is_lt(10, n))

def ex_ticks(+c: B.Ctx) -> IO(B.Res):
  B.stream_sse(~Unit, ~U32, ~ex_tick, ~ex_release_u32, c, ex_resume_after(B.last_event_id(Unit, c)), B.sse_config())
```

## WebSocket handshake

### `B.WebSocketConfig`

```bend signature
def WebSocketConfig() -> Data
```

The opening-handshake settings: allowed origins, offered subprotocols and the
write budget for the 101. Its fields are internal; start from
`B.websocket_config` and change it with the setters below.

```bend
type ExSockets is Data:
  ExSockets{handshake: B.WebSocketConfig}
```

### `B.websocket_config`

```bend signature
def websocket_config() -> B.WebSocketConfig
```

Accepts every `Origin`, offers no subprotocol, and gives the 101 head a
30-second write budget. Restrict the origins whenever a session trusts
cookies.

```bend
def ex_any_origin() -> B.WebSocketConfig:
  B.websocket_config()
```

### `B.websocket_origins`

```bend signature
def websocket_origins(config: B.WebSocketConfig, origins: List<&2, String>) -> B.WebSocketConfig
```

Requires exactly one `Origin` field whose serialized origin is in `origins`;
a missing, repeated or unlisted Origin gets 403. Entries are serialized as
CORS serializes them: a path is ignored, and entries that are not http or
https URLs are dropped, so a list where every entry is dropped refuses every
handshake. Each call replaces the earlier list. CORS does not protect
WebSockets, so set this even when CORS is enabled.

```bend
def ex_app_only() -> B.WebSocketConfig:
  B.websocket_origins(B.websocket_config(), ["https://app.example", "http://localhost:5173"])
```

### `B.websocket_origins_checked`

```bend signature
def websocket_origins_checked(config: B.WebSocketConfig, +origins: List<&2, String>) -> IO(B.WebSocketConfig)
```

`B.websocket_origins` in `IO`, which also prints one stderr line per dropped
entry: `bendo: websocket: ignoring allowed origin "..."`. Call it once at
startup and keep the result in `env`.

```bend
def ex_checked_origins() -> IO(B.WebSocketConfig):
  B.websocket_origins_checked(B.websocket_config(), ["https://app.example"])
```

### `B.websocket_protocols`

```bend signature
def websocket_protocols(config: B.WebSocketConfig, protocols: List<&2, String>) -> B.WebSocketConfig
```

The subprotocols the server speaks, most preferred first. Bendo answers with
the first listed protocol that the client offered, compared exactly,
including case. With no match the 101 has no `Sec-WebSocket-Protocol` field
and the client decides whether to continue. Entries that are not HTTP tokens
are dropped.

```bend
def ex_chat_protocols() -> B.WebSocketConfig:
  B.websocket_protocols(B.websocket_config(), ["chat.v2", "chat"])
```

### `B.websocket_timeout`

```bend signature
def websocket_timeout(config: B.WebSocketConfig, milliseconds: U32) -> B.WebSocketConfig
```

Sets the write budget for sending the 101 head, in milliseconds. The default
is 30,000.

```bend
def ex_quick_upgrade() -> B.WebSocketConfig:
  B.websocket_timeout(B.websocket_config(), 5000)
```

### `B.websocket`

```bend signature
def websocket(~Vars: Data, ~State: Type, ~session: State -> Socket -> List<&2, U32> -> IO(Unit), ~cleanup: State -> IO(Unit), +c: B.Context(Vars), state: State, config: B.WebSocketConfig) -> IO(B.Res)
```

Checks the opening handshake and returns the 101, or a 400, 426 or 403
refusal ([handshake rules](../../websocket.md#handshake-rules)). After the 101
is sent, `session` receives the state, the raw socket and any octets already
read past the handshake; it owns the socket and must close it. `cleanup`
receives the state instead when the handshake is refused, middleware replaces
the response, or the 101 cannot be sent. For framed messages use
`B.websocket_handlers`; register the route with `B.all` if other methods
should get 400 rather than the router's 405.

```bend
def ex_hang_up(sent: Socket & Result<&1, &1, (U32 & String) & List<&2, U32>, Unit>) -> IO(Unit):
  (s, result) = sent
  Socket.close(s)

# Sends one unmasked text frame, "hi", then closes the socket.
def ex_raw_session(state: Unit, s: Socket, rest: List<&2, U32>) -> IO(Unit):
  do IO<Unit>:
    sent : Socket & Result<&1, &1, (U32 & String) & List<&2, U32>, Unit> <- TCP.send_bytes(s, [129, 2, 104, 105])
    ex_hang_up(sent)

def ex_raw_socket(c: B.Ctx) -> IO(B.Res):
  B.websocket(~Unit, ~Unit, ~ex_raw_session, ~ex_release_unit, c, Unit{}, B.websocket_config())
```

## WebSocket handlers

### `B.WebSocketHandle`

```bend signature
def WebSocketHandle() -> Data
```

A copyable handle to one connection's bounded outbound mailbox, passed to the
`on_open` and `on_message` templates of `B.websocket_handlers`. Keep it in a
store to send to that connection from another route. Sends through a handle
whose connection has closed return `False`.

```bend
def ex_remember(saved: B.Store(Maybe<&2, B.WebSocketHandle>), handle: B.WebSocketHandle) -> IO(Result<&2, &2, B.StoreError, Unit>):
  B.store_set(Maybe<&2, B.WebSocketHandle>, saved, Some{handle})
```

### `B.WebSocketSessionConfig`, `W.Config`

```bend signature
def WebSocketSessionConfig() -> Data

type Config is Data:
  Config{max_message: U32, mailbox_capacity: U32, poll_ms: U32, poll_max_ms: U32, idle_ms: U32, ping_ms: U32, close_ms: U32, write_ms: U32}
```

Limits and timers for a `B.websocket_handlers` connection. A message larger
than `max_message` closes with 1009, `idle_ms` without received bytes closes
with 1001, and a nonzero `ping_ms` sends automatic pings. Build one with
`W.Config{...}`; [limits and timers](../../websocket-sessions.md#limits-and-timers)
describes every field.

```bend
def ex_small_messages() -> B.WebSocketSessionConfig:
  W.Config{65536, 64, 10, 100, 60000, 20000, 1000, 30000}
```

### `B.websocket_session_config`

```bend signature
def websocket_session_config() -> B.WebSocketSessionConfig
```

The default limits, `W.Config{1048576, 16, 10, 100, 60000, 0, 1000, 30000}`:
1 MiB messages, 16 queued outbound commands, a socket poll that backs off from
10 to 100 ms when idle, a 60-second idle close, no automatic pings, 1 second
to wait for the peer's close, and a 30-second budget per frame write.

```bend
def ex_default_session() -> B.WebSocketSessionConfig:
  B.websocket_session_config()
```

### `B.WebSocketMessage`, `M.Message`

```bend signature
def WebSocketMessage() -> Data

type Message is Data:
  TextMessage{text: String}
  BinaryMessage{data: List<&2, U32>}
  PingMessage{data: List<&2, U32>}
  PongMessage{data: List<&2, U32>}
  CloseMessage{code: Maybe<&2, U32>, reason: String}
```

A complete message. `on_message` receives only `M.TextMessage`, whose text
has been checked as UTF-8 across fragments, and `M.BinaryMessage`; Bendo
answers control frames itself. Match through `M`, with a final `case _`.

```bend
def ex_describe(message: B.WebSocketMessage) -> String:
  match message:
    case M.TextMessage{text}: "text: " ++ text
    case M.BinaryMessage{bytes}: "binary"
    case _: "control"

def ex_same_message(message: M.Message) -> B.WebSocketMessage:
  message
```

### `B.websocket_send_text`, `W.text`

```bend signature
def websocket_send_text(handle: B.WebSocketHandle, text: String) -> IO(Bool)
```

Queues a UTF-8 text message on the connection's mailbox. `True` means the
mailbox accepted it, not that the peer received it; `False` means the mailbox
is full, the connection is closed, or the message is larger than the
connection's `max_message`. `W.text` is the same function.

```bend
def ex_welcome(handle: B.WebSocketHandle) -> IO(Bool):
  B.websocket_send_text(handle, "welcome")

def ex_welcome_direct(handle: B.WebSocketHandle) -> IO(Bool):
  W.text(handle, "welcome")
```

### `B.websocket_send_binary`

```bend signature
def websocket_send_binary(handle: B.WebSocketHandle, bytes: List<&2, U32>) -> IO(Bool)
```

Queues a binary message with `bytes` unchanged. The result means what it does
for `B.websocket_send_text`.

```bend
def ex_send_bytes(handle: B.WebSocketHandle) -> IO(Bool):
  B.websocket_send_binary(handle, [0, 1, 2, 255])
```

### `B.websocket_ping`

```bend signature
def websocket_ping(handle: B.WebSocketHandle, bytes: List<&2, U32>) -> IO(Bool)
```

Queues a ping with at most 125 payload bytes; a longer payload returns
`False`. Received pongs reset the idle timer. For regular pings, set `ping_ms`
in `B.WebSocketSessionConfig` instead.

```bend
def ex_ping(handle: B.WebSocketHandle) -> IO(Bool):
  B.websocket_ping(handle, [])
```

### `B.websocket_close`, `W.close`

```bend signature
def websocket_close(handle: B.WebSocketHandle, code: U32, reason: String) -> IO(Bool)
```

Begins the close handshake. `code` must be a sendable RFC 6455 or IANA code
and `reason` must fit in 123 UTF-8 bytes, or the call returns `False`.
Commands queued behind the close are discarded. `on_close` later reports the
peer's code and reason, or 1006 when the peer does not answer within
`close_ms`. `W.close` is the same function.

```bend
def ex_goodbye(handle: B.WebSocketHandle) -> IO(Bool):
  B.websocket_close(handle, 1000, "done")

def ex_goodbye_direct(handle: B.WebSocketHandle) -> IO(Bool):
  W.close(handle, 1011, "unavailable")
```

### `B.websocket_handlers`

```bend signature
def websocket_handlers(~Vars: Data, ~User: Data, ~on_open: User -> B.WebSocketHandle -> IO(User), ~on_message: User -> B.WebSocketHandle -> B.WebSocketMessage -> IO(User), ~on_close: User -> U32 -> String -> IO(Unit), c: B.Context(Vars), user: User, handshake: B.WebSocketConfig, config: B.WebSocketSessionConfig) -> IO(B.Res)
```

Accepts the handshake as `B.websocket` does, then runs the connection for you:
masking, fragmentation, ping and pong, close frames and the limits in
`config`. `on_open` and `on_message` receive the per-connection state `user`
and return the next one; `on_close` receives the final state, the close code
and the reason once the socket has closed. None of them runs for a refused or
replaced handshake. [WebSocket handlers](../../websocket-sessions.md#closure)
lists the codes each closing path reports.

```bend
def ex_opened(state: Unit, handle: B.WebSocketHandle) -> IO(Unit):
  IO.pure(Unit, state)

def ex_echo(state: Unit, handle: B.WebSocketHandle, message: B.WebSocketMessage) -> IO(Unit):
  match message:
    case M.TextMessage{text}:
      do IO<Unit>:
        accepted : Bool <- B.websocket_send_text(handle, text)
        return state
    case _: IO.pure(Unit, state)

def ex_closed(state: Unit, code: U32, reason: String) -> IO(Unit):
  IO.print("closed: " ++ U32.show(code) ++ " " ++ reason)

def ex_echo_socket(c: B.Ctx) -> IO(B.Res):
  B.websocket_handlers(~Unit, ~Unit, ~ex_opened, ~ex_echo, ~ex_closed, c, Unit{}, B.websocket_config(), B.websocket_session_config())
```

## Publish and subscribe

### `P.Hub`

```bend signature
type Hub is Data:
  Hub{registry: B.Store(Ledger<B.WebSocketHandle>)}
```

The topic registry for `P.handlers`, held by a store actor. It is copyable
`Data`: create one at startup and keep it in `env`. Its fields are internal.

```bend
type ExEnv is Data:
  ExEnv{hub: P.Hub}
```

### `P.hub`

```bend signature
def hub() -> IO(P.Hub)
```

Spawns the registry actor and returns its hub. Each registry operation waits
at most 5,000 milliseconds.

```bend
def ex_startup() -> IO(ExEnv):
  do IO<ExEnv>:
    hub : P.Hub <- P.hub()
    return ExEnv{hub}
```

### `P.hub_with_timeout`

```bend signature
def hub_with_timeout(timeout_ms: U32) -> IO(P.Hub)
```

`P.hub` with a different budget: each registry operation waits at most
`timeout_ms` milliseconds for the hub before it fails.

```bend
def ex_patient_startup() -> IO(ExEnv):
  do IO<ExEnv>:
    hub : P.Hub <- P.hub_with_timeout(15000)
    return ExEnv{hub}
```

### `P.Peer`

```bend signature
type Peer is Data:
  Peer{handle: B.WebSocketHandle, id: Nat, hub: P.Hub}
```

What `P.handlers` passes to `on_open` and `on_message` in place of a bare
handle. Read it with `P.handle` and `P.id`. A peer kept after its connection
closes can no longer subscribe.

```bend
def ex_join(state: Unit, peer: P.Peer) -> IO(Unit):
  do IO<Unit>:
    ok : Bool <- P.subscribe(peer, "room")
    return state
```

### `P.handle`, `P.id`

```bend signature
def handle(peer: P.Peer) -> B.WebSocketHandle
def id(peer: P.Peer) -> Nat
```

`P.handle` returns the connection's handle, for sending to that connection
alone with `B.websocket_send_text` and the other send helpers. `P.id` returns
the registry ID the hub gave the connection when it opened, or 0 when the hub
did not acknowledge the join in time.

```bend
def ex_whoami(+peer: P.Peer) -> IO(Bool):
  B.websocket_send_text(P.handle(peer), "you are " ++ Nat.show(P.id(peer)))
```

### `P.subscribe`

```bend signature
def subscribe(peer: P.Peer, topic: String) -> IO(Bool)
```

Adds the connection to `topic` and returns `True` once the registry has
applied it, so a publication that starts afterwards reaches it. Subscribing
twice keeps one membership. `False` means the hub timed out or is
unavailable, or the connection has already closed. The connection leaves
every topic when it closes, so `on_close` need not unsubscribe.

```bend
def ex_follow(peer: P.Peer, topic: String) -> IO(Bool):
  P.subscribe(peer, topic)
```

### `P.unsubscribe`

```bend signature
def unsubscribe(peer: P.Peer, topic: String) -> IO(Bool)
```

Removes the connection from `topic` and returns `True` once the registry has
applied it. Leaving a topic the connection is not in also returns `True`.
`False` means the hub timed out or is unavailable.

```bend
def ex_unfollow(peer: P.Peer, topic: String) -> IO(Bool):
  P.unsubscribe(peer, topic)
```

### `P.Delivery`

```bend signature
type Delivery is Data:
  Delivery{sent: Nat, dropped: Nat, gone: Nat}
```

What a publication did. `sent` counts mailboxes that accepted the message.
`dropped` counts open subscribers whose mailbox was full or whose
`max_message` is smaller than the message; they miss it and stay subscribed.
`gone` counts subscribers that had already closed, which the publication
removes from the registry.

```bend
def ex_report(got: Result<&2, &2, B.StoreError, P.Delivery>) -> String:
  match got:
    case Done{P.Delivery{sent, dropped, gone}}: Nat.show(sent) ++ " sent, " ++ Nat.show(dropped) ++ " dropped"
    case Fail{e}: "hub unavailable"
```

### `P.publish`, `P.publish_others`

```bend signature
def publish(hub: P.Hub, topic: String, text: String) -> IO(Result<&2, &2, B.StoreError, P.Delivery>)
def publish_others(peer: P.Peer, topic: String, text: String) -> IO(Result<&2, &2, B.StoreError, P.Delivery>)
```

Offers a text message once to the mailbox of every connection subscribed to
`topic` when the registry is read, never waiting for a slow subscriber.
`P.publish` reaches every member and works from an HTTP route;
`P.publish_others` skips the sending connection. `Fail` means the registry
could not be read and nothing was sent. Messages from one publisher arrive in
order; see [delivery guarantees](../../websocket-pubsub.md#delivery-guarantees).

```bend
def ex_announce(hub: P.Hub, text: String) -> IO(String):
  do IO<String>:
    got : Result<&2, &2, B.StoreError, P.Delivery> <- P.publish(hub, "room", text)
    return ex_report(got)

def ex_relay(state: Unit, peer: P.Peer, message: B.WebSocketMessage) -> IO(Unit):
  match message:
    case M.TextMessage{text}:
      do IO<Unit>:
        got : Result<&2, &2, B.StoreError, P.Delivery> <- P.publish_others(peer, "room", text)
        return state
    case _: IO.pure(Unit, state)
```

### `P.publish_binary`, `P.publish_binary_others`

```bend signature
def publish_binary(hub: P.Hub, topic: String, bytes: List<&2, U32>) -> IO(Result<&2, &2, B.StoreError, P.Delivery>)
def publish_binary_others(peer: P.Peer, topic: String, bytes: List<&2, U32>) -> IO(Result<&2, &2, B.StoreError, P.Delivery>)
```

`P.publish` and `P.publish_others` for a binary message, sent with `bytes`
unchanged.

```bend
def ex_announce_bytes(hub: P.Hub) -> IO(String):
  do IO<String>:
    got : Result<&2, &2, B.StoreError, P.Delivery> <- P.publish_binary(hub, "room", [1, 2, 3])
    return ex_report(got)

def ex_relay_bytes(state: Unit, peer: P.Peer, message: B.WebSocketMessage) -> IO(Unit):
  match message:
    case M.BinaryMessage{bytes}:
      do IO<Unit>:
        got : Result<&2, &2, B.StoreError, P.Delivery> <- P.publish_binary_others(peer, "room", bytes)
        return state
    case _: IO.pure(Unit, state)
```

### `P.members`, `P.size`, `P.connections`

```bend signature
def members(hub: P.Hub, topic: String) -> IO(Result<&2, &2, B.StoreError, List<&2, Nat>>)
def size(hub: P.Hub) -> IO(Result<&2, &2, B.StoreError, Nat>)
def connections(hub: P.Hub) -> IO(Result<&2, &2, B.StoreError, Nat>)
```

Read the registry. `P.members` returns the registry IDs subscribed to `topic`,
the IDs `P.id` gives. `P.size` counts subscriptions across all topics, so a
connection in two topics counts twice; it is zero once every connection has
gone. `P.connections` counts connections that joined and have not closed.
`Fail` means the registry could not be read.

```bend
def ex_count(got: Result<&2, &2, B.StoreError, Nat>) -> Nat:
  match got:
    case Done{n}: n
    case Fail{e}: 0n

def ex_in_room(got: Result<&2, &2, B.StoreError, List<&2, Nat>>) -> Nat:
  match got:
    case Done{ids}: List.length(&2, Nat, ids)
    case Fail{e}: 0n

def ex_stats(+hub: P.Hub) -> IO(String):
  do IO<String>:
    room : Result<&2, &2, B.StoreError, List<&2, Nat>> <- P.members(hub, "room")
    subs : Result<&2, &2, B.StoreError, Nat> <- P.size(hub)
    open : Result<&2, &2, B.StoreError, Nat> <- P.connections(hub)
    return Nat.show(ex_in_room(room)) ++ " in the room, " ++ Nat.show(ex_count(subs)) ++ " subscriptions, " ++ Nat.show(ex_count(open)) ++ " connections"
```

### `P.handlers`

```bend signature
def handlers(~Vars: Data, ~User: Data, ~on_open: User -> P.Peer -> IO(User), ~on_message: User -> P.Peer -> B.WebSocketMessage -> IO(User), ~on_close: User -> U32 -> String -> IO(Unit), c: B.Context(Vars), hub: P.Hub, user: User, handshake: B.WebSocketConfig, config: B.WebSocketSessionConfig) -> IO(B.Res)
```

`B.websocket_handlers` with topics: the connection joins `hub` when it opens,
and `on_open` and `on_message` receive a `P.Peer`. On every close path,
including a dropped TCP connection, it leaves every topic and its ID is
revoked before `on_close` runs.

```bend
def ex_left(state: Unit, code: U32, reason: String) -> IO(Unit):
  IO.pure(Unit, state)

def ex_room(c: B.Ctx, env: ExEnv) -> IO(B.Res):
  ExEnv{hub} = env
  P.handlers(~Unit, ~Unit, ~ex_join, ~ex_relay, ~ex_left, c, hub, Unit{}, B.websocket_config(), B.websocket_session_config())
```

## Static files

### `B.StaticOptions`

```bend signature
def StaticOptions() -> Data
```

Where `B.serve_static` finds files and how it answers. Its fields are
internal; start from `B.static_options` and change it with the setters below.

```bend
type ExSite is Data:
  ExSite{assets: B.StaticOptions}
```

### `B.static_options`

```bend signature
def static_options(root: String) -> B.StaticOptions
```

Serves the directory `root`, absolute or relative to the working directory;
the root itself may be a symlink. The defaults are no prefix, `index.html` as
the index, a 1 MiB buffer and no `Cache-Control`.

```bend
def ex_dist() -> B.StaticOptions:
  B.static_options("dist")
```

### `B.static_mounted`

```bend signature
def static_mounted(options: B.StaticOptions, prefix: String) -> B.StaticOptions
```

Removes the route prefix `prefix` from the request path before looking up the
file. A path outside the prefix gets 404.

```bend
def ex_assets() -> B.StaticOptions:
  B.static_mounted(B.static_options("public"), "/assets")
```

### `B.static_index`

```bend signature
def static_index(options: B.StaticOptions, index: String) -> B.StaticOptions
```

The file served for a path ending in `/`, `index.html` by default. `""`
turns index files off, so such a path gets 404. There is never a directory
listing.

```bend
def ex_docs_index() -> B.StaticOptions:
  B.static_index(B.static_options("site"), "README.html")
```

### `B.static_buffer_bytes`

```bend signature
def static_buffer_bytes(options: B.StaticOptions, max: Nat) -> B.StaticOptions
```

The largest body, in octets, read into memory before sending; the default is
1,048,576. A longer body streams 64 KiB at a time as a stream of known
length, like `B.stream_sized`. Both carry `Content-Length`.

```bend
def ex_stream_early() -> B.StaticOptions:
  B.static_buffer_bytes(B.static_options("media"), 65536n)
```

### `B.static_cache_control`

```bend signature
def static_cache_control(options: B.StaticOptions, value: String) -> B.StaticOptions
```

Sets the `Cache-Control` value sent with served files and with 304
responses. By default there is none.

```bend
def ex_immutable() -> B.StaticOptions:
  B.static_cache_control(ex_assets(), "public, max-age=31536000, immutable")
```

### `B.serve_static`, `B.serve_static_with`

```bend signature
def serve_static(c: B.Ctx, options: B.StaticOptions) -> IO(B.Res)
def serve_static_with(-Vars: Data, c: B.Context(Vars), options: B.StaticOptions) -> IO(B.Res)
```

Answers with the file named by the raw request path after the prefix.
Register it on a GET wildcard route; HEAD follows GET, and other methods get
405 with `Allow: GET, HEAD`. Paths that escape the root, dotfiles, symlinks
below the root and missing files get 404. `B.serve_static_with` is the form
for handlers with typed context variables; [static files](../../static.md)
covers caching, ranges and content types.

```bend
type ExFiles is Data:
  ExAssetsRoute{}
  ExAppRoute{}

def ex_files(route: ExFiles, c: B.Ctx, env: Unit) -> IO(B.Res):
  match route:
    case ExAssetsRoute{}: B.serve_static(c, ex_immutable())
    case ExAppRoute{}: B.serve_static(c, ex_dist())

def ex_private_files(c: B.Context(ExUser)) -> IO(B.Res):
  B.serve_static_with(ExUser, c, B.static_options("private"))
```

## Reverse proxy

### `B.ProxyOptions`

```bend signature
def ProxyOptions() -> Data
```

The upstream and the settings `B.proxy` uses. Its fields are internal; start
from `B.proxy_options` and change it with the setters below.

```bend
type ExGateway is Data:
  ExGateway{api: B.ProxyOptions}
```

### `B.proxy_options`

```bend signature
def proxy_options(upstream: String) -> B.ProxyOptions
```

Proxies to `upstream`, written `http://host[:port][/base]`, where `host` is a
DNS name, a dotted-quad IPv4 address or a bracketed IPv6 address and the port
defaults to 80. `base` is prefixed to every forwarded path. The URL is checked
per request: any other URL, including `https`, answers 500
`Proxy upstream misconfigured`. The defaults keep forwarding headers off,
rewrite nothing, and use the timeouts and stream settings described below.

```bend
def ex_backend() -> B.ProxyOptions:
  B.proxy_options("http://127.0.0.1:3000")
```

### `B.proxy_preserve_host`

```bend signature
def proxy_preserve_host(options: B.ProxyOptions, on: Bool) -> B.ProxyOptions
```

With `on`, sends the client's `Host` instead of the upstream's authority.
Off by default.

```bend
def ex_same_host() -> B.ProxyOptions:
  B.proxy_preserve_host(ex_backend(), True{})
```

### `B.proxy_trust_forwarded`

```bend signature
def proxy_trust_forwarded(options: B.ProxyOptions, on: Bool) -> B.ProxyOptions
```

With `on`, appends to the incoming `X-Forwarded-For`, `X-Forwarded-Proto`,
`X-Forwarded-Host` and `Forwarded` values instead of replacing them. Turn it
on only when every client reaches Bendo through a proxy you control;
otherwise clients can forge the chain.

```bend
def ex_behind_balancer() -> B.ProxyOptions:
  B.proxy_trust_forwarded(ex_backend(), True{})
```

### `B.proxy_forwarded`

```bend signature
def proxy_forwarded(options: B.ProxyOptions, on: Bool) -> B.ProxyOptions
```

With `on`, also sends an RFC 7239 field,
`forwarded: for=<peer>;host="<client host>";proto=http`. The `X-Forwarded-*`
fields are sent either way.

```bend
def ex_rfc_forwarded() -> B.ProxyOptions:
  B.proxy_forwarded(ex_backend(), True{})
```

### `B.proxy_rewrite`

```bend signature
def proxy_rewrite(options: B.ProxyOptions, from: String, to: String) -> B.ProxyOptions
```

Replaces a leading `from` in the request path with `to`; a later call
replaces the rule. A result that is not an origin-form path answers 500
`Proxy rewrite produced an invalid target` and sends nothing upstream. Dot
segments are forwarded as sent, so a rewrite is not an access boundary.

```bend
def ex_strip_api() -> B.ProxyOptions:
  B.proxy_rewrite(ex_backend(), "/api", "")
```

### `B.proxy_timeouts`

```bend signature
def proxy_timeouts(options: B.ProxyOptions, connect_ms: U32, send_ms: U32, head_ms: U32, read_ms: U32) -> B.ProxyOptions
```

Budgets in milliseconds for resolving and connecting, sending the request,
receiving the whole response head, and each body receive. The defaults are
5,000, 30,000, 30,000 and 30,000. Running out before the head gives 504; a
read timeout after the head aborts the client connection.

```bend
def ex_impatient() -> B.ProxyOptions:
  B.proxy_timeouts(ex_backend(), 1000, 5000, 5000, 60000)
```

### `B.proxy_stream_config`

```bend signature
def proxy_stream_config(options: B.ProxyOptions, config: B.StreamConfig) -> B.ProxyOptions
```

The stream settings for the response sent to the client, `B.stream_config()`
by default. Each pull reads at most `min(max_chunk_bytes, 65536)` octets from
the upstream.

```bend
def ex_proxy_quick_writes() -> B.ProxyOptions:
  B.proxy_stream_config(ex_backend(), ex_quick_writes())
```

### `B.proxy`, `B.proxy_with`

```bend signature
def proxy(c: B.Ctx, options: B.ProxyOptions) -> IO(B.Res)
def proxy_with(-Vars: Data, c: B.Context(Vars), options: B.ProxyOptions) -> IO(B.Res)
```

Forwards the request's method, path, query, end-to-end headers and body over
a new upstream connection, then streams the upstream's status, headers and
body back through `B.stream`. Hop-by-hop headers are removed both ways. The
request body is the one already read under the server's body limit. Failures
before the response head give 502 or 504, as listed in
[failures](../../proxy.md#failures); `B.proxy_with` is the form for handlers
with typed context variables.

```bend
type ExApi is Data:
  ExApiRoute{}

def ex_api(route: ExApi, c: B.Ctx, env: Unit) -> IO(B.Res):
  B.proxy(c, ex_strip_api())

def ex_api_for(c: B.Context(ExUser)) -> IO(B.Res):
  B.proxy_with(ExUser, c, ex_strip_api())
```
