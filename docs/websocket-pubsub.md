# Publish and subscribe over WebSockets

`src/ws/pubsub.bend` adds topics to [WebSocket handlers](websocket-sessions.md).
A connection subscribes to topics by name. A publication to a topic is queued
on every subscriber's outbound mailbox, from a socket handler or from an HTTP
route. It works like Elysia's `ws.subscribe`, `ws.publish` and `server.publish`.

The module is opt-in: import it next to `src/main.bend`. Apps that don't use
it compile exactly as before.

## Set up a hub

A `P.Hub` is a [`B.Store`](store.md) actor that holds the topic registry.
Create one at startup and pass it to your handlers in `env`. Then use
`P.handlers` in place of `B.websocket_handlers`. It takes the same templates,
except that `open` and `message` receive a `P.Peer` instead of a bare handle.

```python
import Base
import ../src/main.bend as B
import ../src/ws/connection.bend as W
import ../src/ws/message.bend as M
import ../src/ws/pubsub.bend as P
import ../src/app/store.bend as Store

def opened(state: Unit, peer: P.Peer) -> IO(Unit):
  do IO<Unit>:
    ok : Bool <- P.subscribe(peer, "room")
    return state

def message(state: Unit, peer: P.Peer, message: M.Message) -> IO(Unit):
  match message:
    case M.TextMessage{text}:
      do IO<Unit>:
        got : Result<&2, &2, Store.Error, P.Delivery> <- P.publish_others(peer, "room", text)
        return state
    case _: IO.pure(Unit, state)

def closed(state: Unit, code: U32, reason: String) -> IO(Unit):
  IO.pure(Unit, state)

@unsafe
def room(c: B.Context(Unit), hub: P.Hub) -> IO(B.Res):
  P.handlers(~Unit, ~Unit, ~opened, ~message, ~closed, c, hub, Unit{}, B.websocket_config(), B.websocket_session_config())
```

Create the hub in `main` with `hub : P.Hub <- P.hub()`, or with
`P.hub_with_timeout(ms)` to change the 5,000 ms registry budget. Every
connection joins the hub when it opens and gets a fresh registry ID
(`P.id(peer)`). It leaves every topic when it closes, on any path: a peer
close, a server close, a protocol error, an idle timeout, or a dropped TCP
connection (1006). The same registry update revokes its ID, so a `P.Peer`
kept after the close can no longer subscribe. You don't need to unsubscribe in
`close`. If the hub doesn't acknowledge the join in time, `P.id(peer)` is 0
and `subscribe` returns `False`. The close still revokes the ID the hub
assigned, because each connection joins and leaves under its own random token.

The close's release is never dropped. Other hub requests give up when the
hub's 128-request queue stays full past the hub's timeout, but the release
waits for room as long as that takes, ahead of anyone who arrives later. So a
burst of traffic can delay a connection's cleanup, but cannot leave its ID
active or its subscriptions behind.

## Limits

Every hub caps subscriptions, so one connection cannot grow the registry
that each subscribe and publication scans. `P.hub()` and
`P.hub_with_timeout(ms)` use `P.limits_default()`:

| Limit | Default | Refusal |
| --- | --- | --- |
| Topics per connection | 128 | `P.PeerLimit{}` |
| Subscriptions per hub, across all connections | 65,536 | `P.HubLimit{}` |
| Topic name length, in UTF-8 bytes | 255 | `P.TopicTooLong{}` |

The per-connection and topic-length defaults match Centrifugo's
`channel_limit` (128) and `channel.max_length` (255). Bun and uWebSockets.js
set no limits, which is what let one peer register 256 topics in the launch
review. Neither has a hub-wide cap either. Bendo adds one because its registry
is a list that every subscribe and publication walks, so the cap bounds that
work and the hub's memory. 65,536 is 512 connections at the per-connection
limit. Raise it if more connections each hold many topics.

To change the limits, create the hub with
`P.hub_with(P.limits(per_peer, per_hub, topic_bytes), timeout_ms)`. The hub
checks them inside the same registry update that records the subscription,
so concurrent subscribes cannot overshoot. A refused subscribe changes
nothing. Subscribing again to a topic the connection already holds succeeds
and uses no extra slot. Unsubscribing frees a slot at once, and closing a
connection frees all of its slots.

`P.subscribe` returns `False` for a refusal. `P.subscribe_checked(peer,
topic)` returns a `P.Subscription` that says why: `P.Subscribed{}`,
`P.Closed{}`, `P.TopicTooLong{}`, `P.PeerLimit{}`, `P.HubLimit{}`, or
`P.HubError{error}` when the hub timed out or is unavailable.

To send to one connection, use `P.handle(peer)` with the usual
`B.websocket_send_text` helpers, or keep the handle to send from elsewhere.

For a complete app, see [the chat example](../examples/chat/README.md): one
topic per room, with arrivals, departures and room counts.

## Operations

| Call | Result | Behavior |
| --- | --- | --- |
| `P.subscribe(peer, topic)` | `IO(Bool)` | Adds the connection to `topic` within the hub's limits. Subscribing twice keeps one membership. |
| `P.subscribe_checked(peer, topic)` | `IO(P.Subscription)` | The same, with the reason for a refusal. |
| `P.unsubscribe(peer, topic)` | `IO(Bool)` | Removes it from `topic`. |
| `P.publish(hub, topic, text)` | `IO(Result<Store.Error, P.Delivery>)` | Text to every member. Use it from an HTTP route or anywhere else. |
| `P.publish_binary(hub, topic, bytes)` | same | Binary to every member. |
| `P.publish_others(peer, topic, text)` | same | Text to every member except the sending connection, like Elysia's `ws.publish`. |
| `P.publish_binary_others(peer, topic, bytes)` | same | Binary, sender excluded. |
| `P.members(hub, topic)` | `IO(Result<Store.Error, List<Nat>>)` | Registry IDs subscribed to `topic`. |
| `P.size(hub)` | `IO(Result<Store.Error, Nat>)` | Subscriptions across all topics. |
| `P.connections(hub)` | `IO(Result<Store.Error, Nat>)` | Connections that joined and have not closed. |

`subscribe` and `unsubscribe` return `True` once the registry has applied the
change. A publication that starts after that sees it. `False` from
`unsubscribe` means the hub timed out or is unavailable. `False` from
`subscribe` can also mean the connection has already closed or a limit
refused it, in which case the registry is unchanged.

A publication returns `P.Delivery{sent, dropped, gone}`:

- `sent`: mailboxes that accepted the message. As with the
  [send helpers](websocket-sessions.md#send-from-a-handler-or-another-route),
  acceptance does not mean the peer has read it.
- `dropped`: open subscribers whose mailbox was full, or whose `max_message`
  is smaller than the message. They miss this message and stay subscribed.
- `gone`: subscribers that had already closed, whatever the message size,
  including a connection whose close was admitted while its mailbox was full
  ([which shuts that mailbox](websocket-sessions.md#send-from-a-handler-or-another-route)). The
  publication removes them from the registry and forgets the token each one
  joined under, so the hub's state shrinks back even if that connection's own
  cleanup never ran.

`Fail{Store.Unavailable{}}` or `Fail{Store.TimedOut{}}` means the registry
couldn't be read, and nothing was sent.

## Delivery guarantees

A publication selects each subscribed connection exactly once: every
connection with a subscription to the topic, minus the sender for the
`_others` forms, gets one offer of the message on the mailbox it subscribed
with. A publication never waits for a subscriber. Each recipient gets one
nonblocking offer, so a slow or stalled subscriber cannot delay the publisher
or anyone else. When a subscriber's mailbox is full, that subscriber's copy
is dropped and counted in `dropped`. A reader that stops reading completely
hits its `write_ms` deadline, disconnects with 1006, and leaves the registry.

Messages from one publisher reach each subscriber in the order they were
published, with gaps where copies were dropped. Bendo does not guarantee:

- an order between two publishers. Their messages can interleave differently
  at different subscribers.
- that a subscription made while a publication is in flight receives it. A
  publication reaches the members present when it reads the registry.
- that an unsubscribe stops a publication already in flight.
- delivery across a restart. The registry lives in memory.

## Latency

A subscriber's connection checks its mailbox between socket reads. An idle
connection's read wait doubles from `poll_ms` (10 ms) up to `poll_max_ms`
(100 ms), so the first publication after a quiet period can wait up to
`poll_max_ms` before it is written. While a connection is active (bytes
arriving, or commands just sent), it sees `poll_ms` or better. Measured on a
Boat sandbox with `tests/ws-pubsub.test.ts`, from the HTTP publish request to
the frame arriving at a raw client:

| Subscriber | Samples (ms) | Median |
| --- | --- | --- |
| Idle for 600 ms or more | 49.7, 35.7, 24.8, 10.8, 98.8, 85.9, 72.8, 60.0 | 60.0 ms |
| Sending a frame every 5 ms | 5.0, 5.2, 2.7, 0.6, 3.3, 1.6, 0.6, 2.7 | 2.7 ms |

A publication cannot cut an idle wait short, because Bend has no way to wait
on a socket and a channel at once. See
[the decision](decisions/0018-websocket-pubsub.md). For lower idle latency,
lower `poll_max_ms` and accept more idle CPU, or have clients send periodic
pings.

## Verify

`bun test tests/ws-pubsub.test.ts --timeout 30000` runs the native fixture
`tests/servers/ws-pubsub.bend` against raw socket clients. It covers
publication to 50 subscribers with bystanders on other topics, sender
exclusion, HTTP publication, unsubscribe, 1,000 connect-and-disconnect cycles
that leave the registry empty, the slow-subscriber policy, per-publisher
ordering, a kept `P.Peer` subscribing after its connection closed (once in
order and 30 times racing the close), an oversized publication that still
prunes a closed subscriber and its claim, a join that times out after the hub
queued it, a close while the hub's queue is held full (its release waits and
lands once the queue drains), and the latency figures above.
`bun test tests/ws-pubsub-limits.test.ts --timeout 30000` drives real clients
past each limit on a small hub and on the defaults, including one peer asking
for 256 topics. The registry laws live in `proof/ws-topics-laws.bend` and the
limit laws in `proof/ws-limits-laws.bend`; `bun run prove` checks them.
