---
title: Add WebSockets
description: Serve WebSocket connections from Bendo with per-connection state, rooms through publish and subscribe, origin checks and keepalive settings.
---

# Add WebSockets

This guide adds two WebSocket routes to an app and an HTTP route that talks to
them:

| Route | What it does |
|---|---|
| `GET /ws/echo` | Echoes each message with a running count, kept per connection. |
| `GET /ws/rooms/:room` | Relays each message to everyone else in the same room. |
| `POST /rooms/:room/announce` | Sends the request body to everyone in a room. |

The snippets come from [the complete app](#the-complete-app) at the end of the
page. The reference pages for [handlers](../websocket-sessions.md),
[the handshake](../websocket.md) and [publish and subscribe](../websocket-pubsub.md)
cover every limit and close code.

## Handle one connection

`B.websocket_handlers` answers the upgrade and then calls three templates on
the connection: `open` once, `message` for every complete text or binary
message, and `close` once at the end. Each template takes the connection's
state and returns the next one. Bendo handles pings, fragmentation, masking
and close frames itself.

The echo route keeps a message count as its state. `open` greets the client:

```bend
def echo_opened(count: Nat, handle: B.WebSocketHandle) -> IO(Nat):
  do IO<Nat>:
    sent : Bool <- B.websocket_send_text(handle, "welcome")
    return count
```

`message` matches on the message kind, replies and returns the new count:

```bend
def echo_message(count: Nat, handle: B.WebSocketHandle, message: M.Message) -> IO(Nat):
  match message:
    case M.TextMessage{text}: echo_reply((count + 1n : Nat), handle, text)
```

`close` receives the final state and the close code:

```bend
def echo_closed(count: Nat, code: U32, reason: String) -> IO(Unit):
  IO.print("echo closed after " ++ Nat.show(count) ++ " messages, code " ++ U32.show(code))
```

The handler passes the templates with `~`, the starting state, and two
configurations:

```bend
case EchoSocket{} _: B.websocket_handlers(~Unit, ~Nat, ~echo_opened, ~echo_message, ~echo_closed, c, 0n, handshake(), session())
```

The send helpers return `IO(Bool)`. `True` means the message joined the
connection's outbound queue, not that the client has read it. `False` means the
queue was full or the connection is closing. `B.websocket_close` is the
exception: a valid close is admitted even when the queue is full, so a handler
can always end its connection. Every later send to that connection returns
`False`. The [handler reference](../websocket-sessions.md#send-from-a-handler-or-another-route)
gives the exact order.

## Put connections in rooms

`src/ws/pubsub.bend` adds topics. Create one hub at startup and keep it in
`env`:

```bend
hub : P.Hub <- P.hub()
```

Use `P.handlers` instead of `B.websocket_handlers`. It takes the hub, and its
`open` and `message` templates receive a `P.Peer`, which can subscribe and
publish. Here the state is the room name, taken from the path:

```bend
case RoomSocket{} Env{hub}: P.handlers(~Unit, ~String, ~room_opened, ~room_message, ~room_closed, c, hub, room_name(C.param(Unit, c, "room")), handshake(), session())
```

`open` subscribes the connection to its room, and `message` publishes to
everyone else in it:

```bend
joined : Bool <- P.subscribe(peer, room)
```

```bend
delivered : Result<&2, &2, Store.Error, P.Delivery> <- P.publish_others(peer, room, text)
```

A template cannot mark a parameter with `+`, which Bend needs to use the room
name twice. Each template therefore hands its state to a helper that can:

```bend
def room_opened(room: String, peer: P.Peer) -> IO(String):
  join(room, peer)
```

A connection leaves every topic when it closes, however it closes, so `close`
has nothing to clean up.

## Publish from an HTTP route

Any code that holds the hub can publish, including an ordinary route:

```bend
result : Result<&2, &2, Store.Error, P.Delivery> <- P.publish(hub, room_name(C.param(Unit, c, "room")), body_text(Utf8.decode(C.raw_body(Unit, c))))
```

`P.Delivery{sent, dropped, gone}` counts the connections that accepted the
message, those whose queue was full, and those that had already closed. This
route returns the counts as JSON.

## Check the origin

Any page can open a WebSocket to your server, and CORS does not apply to
WebSockets. The browser attaches your cookies when their `SameSite` setting
allows it, and the server sees only the page's `Origin`. If your sockets trust
cookies, list the origins that may open them; any other `Origin` gets 403
before the upgrade:

```bend
def handshake() -> B.WebSocketConfig:
  B.websocket_origins(B.websocket_config(), ["https://app.example", "http://localhost:5173"])
```

To authenticate a socket, check the cookie or a token in the handler before
calling `B.websocket_handlers`, and answer 401 instead of upgrading. The
[auth guide](auth.md#require-a-session) shows the session check.

## Keep connections alive

`W.Config` sets the per-connection limits. The fields are the largest
message, the outbound queue length, the socket poll interval and its idle
backoff cap, the idle timeout, the ping interval, the close wait and the write
deadline:

```bend
def session() -> W.Config:
  W.Config{65536, 16, 10, 100, 60000, 20000, 1000, 30000}
```

A connection that receives nothing for `idle_ms` (60 seconds) is closed with
1001. The default sends no pings, so an idle browser tab would be dropped.
This app pings every 20 seconds; browsers answer pings on their own, and the
answers reset the idle timer. Keep proxy timeouts longer than the ping
interval too: Cloudflare closes a WebSocket after 100 seconds without traffic.

## Try it

```sh
bendo build && ./dist/server
```

In a browser console on one of the listed origins:

```ts
const room = new WebSocket("ws://127.0.0.1:8787/ws/rooms/kitchen");
room.onmessage = (event) => console.log("room:", event.data);
room.onopen = () => room.send("pasta tonight?");
```

Open it in two tabs, and each tab sees the other's messages. Then announce to
both from a terminal:

```sh
curl -d 'dinner is ready' http://127.0.0.1:8787/rooms/kitchen/announce
```

```json
{"sent":2,"dropped":0,"gone":0}
```

## The complete app

::: details main.bend
```bend
import Base
import ./bendo/main.bend as B
import ./bendo/app/context.bend as C
import ./bendo/app/store.bend as Store
import ./bendo/data/json.bend as Json
import ./bendo/data/utf8.bend as Utf8
import ./bendo/ws/connection.bend as W
import ./bendo/ws/message.bend as M
import ./bendo/ws/pubsub.bend as P

type Env is Data:
  Env{hub: P.Hub}

type Tag is Data:
  EchoSocket{}
  RoomSocket{}
  Announce{}

# --- Echo: per-connection state ---

def echo_opened(count: Nat, handle: B.WebSocketHandle) -> IO(Nat):
  do IO<Nat>:
    sent : Bool <- B.websocket_send_text(handle, "welcome")
    return count

def echo_reply(+count: Nat, handle: B.WebSocketHandle, text: String) -> IO(Nat):
  do IO<Nat>:
    sent : Bool <- B.websocket_send_text(handle, "#" ++ Nat.show(count) ++ " " ++ text)
    return count

def echo_message(count: Nat, handle: B.WebSocketHandle, message: M.Message) -> IO(Nat):
  match message:
    case M.TextMessage{text}: echo_reply((count + 1n : Nat), handle, text)
    case M.BinaryMessage{bytes}:
      do IO<Nat>:
        sent : Bool <- B.websocket_send_binary(handle, bytes)
        return count
    case _: IO.pure(Nat, count)

def echo_closed(count: Nat, code: U32, reason: String) -> IO(Unit):
  IO.print("echo closed after " ++ Nat.show(count) ++ " messages, code " ++ U32.show(code))

# --- Rooms: publish and subscribe ---

# Templates cannot mark a parameter with +, so each one passes its state to a
# helper that can use it twice.
def join(+room: String, peer: P.Peer) -> IO(String):
  do IO<String>:
    joined : Bool <- P.subscribe(peer, room)
    return room

def relay(+room: String, peer: P.Peer, message: M.Message) -> IO(String):
  match message:
    case M.TextMessage{text}:
      do IO<String>:
        delivered : Result<&2, &2, Store.Error, P.Delivery> <- P.publish_others(peer, room, text)
        return room
    case _: IO.pure(String, room)

def room_opened(room: String, peer: P.Peer) -> IO(String):
  join(room, peer)

def room_message(room: String, peer: P.Peer, message: M.Message) -> IO(String):
  relay(room, peer, message)

def room_closed(room: String, code: U32, reason: String) -> IO(Unit):
  IO.pure(Unit, Unit{})

# --- Configuration ---

def handshake() -> B.WebSocketConfig:
  B.websocket_origins(B.websocket_config(), ["https://app.example", "http://localhost:5173"])

# Fields: max_message, mailbox_capacity, poll_ms, poll_max_ms, idle_ms,
# ping_ms, close_ms, write_ms. Messages up to 64 KiB, and a ping every
# 20 seconds keeps an open tab inside the 60-second idle limit.
def session() -> W.Config:
  W.Config{65536, 16, 10, 100, 60000, 20000, 1000, 30000}

# --- HTTP side ---

def room_name(param: Maybe<&2, String>) -> String:
  match param:
    case Some{room}: room
    case None{}: "lobby"

def body_text(decoded: Maybe<&2, String>) -> String:
  match decoded:
    case Some{text}: text
    case None{}: ""

def delivery_json(+c: B.Context(Unit), result: Result<&2, &2, Store.Error, P.Delivery>) -> B.Res:
  match result:
    case Fail{error}: C.error(Unit, c, B.http_error(503, "hub unavailable"))
    case Done{P.Delivery{sent, dropped, gone}}:
      C.json(Unit, c, Json.JObject{[
        Json.Field{"sent", Json.JNumber{Nat.show(sent)}},
        Json.Field{"dropped", Json.JNumber{Nat.show(dropped)}},
        Json.Field{"gone", Json.JNumber{Nat.show(gone)}}]})

def announce(+c: B.Context(Unit), hub: P.Hub) -> IO(B.Res):
  do IO<B.Res>:
    result : Result<&2, &2, Store.Error, P.Delivery> <- P.publish(hub, room_name(C.param(Unit, c, "room")), body_text(Utf8.decode(C.raw_body(Unit, c))))
    return delivery_json(c, result)

def handle(tag: Tag, +c: B.Context(Unit), env: Env) -> IO(B.Res):
  match tag env:
    case EchoSocket{} _: B.websocket_handlers(~Unit, ~Nat, ~echo_opened, ~echo_message, ~echo_closed, c, 0n, handshake(), session())
    case RoomSocket{} Env{hub}: P.handlers(~Unit, ~String, ~room_opened, ~room_message, ~room_closed, c, hub, room_name(C.param(Unit, c, "room")), handshake(), session())
    case Announce{} Env{hub}: announce(c, hub)

def handler(tag: Tag, c: B.Context(Unit), env: Env) -> IO(B.Res):
  handle(tag, c, env)

def ready(env: Env, result: Result<&2, &2, B.RouteError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "invalid routes")
    case Done{table}: B.serve(~Tag, ~Env, ~handler, table, env, B.config())

def main() -> IO(Unit):
  do IO<Unit>:
    hub : P.Hub <- P.hub()
    ready(Env{hub}, B.routes(Tag, [
      B.get(Tag, "/ws/echo", EchoSocket{}),
      B.get(Tag, "/ws/rooms/:room", RoomSocket{}),
      B.post(Tag, "/rooms/:room/announce", Announce{})]))
```
:::

## Read on

- The [chat example](../../examples/chat/README.md) is a full React app on top of
  publish and subscribe, with presence and history.
- [WebSocket handlers](../websocket-sessions.md) explains the outbound queue,
  timers and close codes.
- [Publish and subscribe](../websocket-pubsub.md) states what a publication
  guarantees.
