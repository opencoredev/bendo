# 0016: WebSocket topics in a store actor, with drop-on-full fan-out

BND-53 adds publish and subscribe on top of the BND-52 session layer
([0015](0015-websocket-mailbox.md)). Three questions shaped it: where
membership lives, what a publisher does when a subscriber can't keep up, and
whether a publication can wake an idle subscriber.

## One registry, one actor

The registry is the pure `src/ws/topics.bend`: a list of `Sub{topic, id,
target}` entries plus the next connection ID. A `B.Store` actor owns it, so
subscribe, unsubscribe, join and remove are serialized as store updates.
`src/ws/pubsub.bend` is the IO shell around it.

Connections need an identity to unsubscribe and to exclude a sender. Channels
can't be compared, so each connection joins the hub when it opens and receives
a counter ID from the registry. `P.handlers` wraps the application's
templates. Its state holds the user's state, the ID and the hub, and its
`close` wrapper removes the ID from every topic before calling the user's
`close`. BND-52 runs `close` exactly once on every session end, including EOF
and transport failure (1006), so cleanup needs no separate path.

The removal is a store update with the hub's timeout. If it fails, the dead
entry is still harmless: its mailbox is already closed, so the next
publication to that topic gets a closed result, counts it as `gone`, and
removes it.

The list representation keeps the laws simple and costs O(subscriptions) per
operation. A publication reads a snapshot of the whole registry with
`Store.get`. That is fine for the chat-sized registries BND-65 needs. A large
deployment would want a map keyed by topic, with the same laws.

The module is opt-in: `src/main.bend` doesn't import it, so apps without
topics don't pay its compile cost.

## Slow subscribers: drop that copy

A publication makes one `Chan.try_send(..., 0)` per target, in registry order.
When a subscriber's mailbox is full, its copy is dropped and counted in
`Delivery.dropped`. The publisher never waits, and neither does any other
subscriber.

We considered closing a slow subscriber with 1008 or 1013 instead. The close
command would have to go through the same full mailbox, so it can't be
delivered without an out-of-band path into the connection loop. That path
doesn't exist without a select primitive. Applications that need every
message can add sequence numbers and resynchronize. A subscriber that stops
reading completely is still disconnected: its writes hit `write_ms`, the
session ends with 1006, and the close wrapper removes it.

## Ordering

One publication finishes all its offers before the publishing computation can
start the next one. Each mailbox is a FIFO channel drained in order by its
connection. So messages from one publisher reach each subscriber in
publication order, possibly with gaps from drops. Two publishers interleave
arbitrarily, and different subscribers may see different interleavings. A
publication reaches the members in its snapshot: a subscribe acknowledged
before the publication starts is included, and a later one is not.

`publish_others` (sender excluded) matches Elysia's `ws.publish`, and
`publish` (everyone) matches `server.publish`. The sender-excluding form is
the default for socket handlers because chat-style rooms usually echo locally.

## Idle subscribers are not woken

A connection waits on its socket for up to the current backoff and checks its
mailbox between waits (0015). A publisher can't cut that wait short, because
Bend 2.0.38 can't wait on a socket and a channel at the same time, and the
backoff value lives in the connection's own state. Resetting it from outside
would only help the second message, and the existing loop already does that:
a mailbox command sets the next wait to zero. So the first publication after
an idle period costs up to `poll_max_ms` (100 ms by default). Measured on a
Boat sandbox, idle subscribers received an HTTP publication in 10.8 to 98.8 ms
(median 60.0 ms over eight samples), and active subscribers in 0.6 to 5.2 ms
(median 2.7 ms). Waking would need a runtime select or a wakeup socket per
connection. Neither is cheap enough here.

## Laws

`proof/ws-topics-laws.bend` states the registry's contract against an
independent model in `proof/ws-topics-spec.bend`. In that model, a
connection's membership in a topic is decided by the last operation that names
the pair. The laws cover subscribe and unsubscribe membership, remove leaving
every topic, independence of other topics, publication targets equal to
members minus the sender, and, over any history of operations, agreement with
the model and exactly-once targeting. `proof/ws-topics.bend` proves them.
