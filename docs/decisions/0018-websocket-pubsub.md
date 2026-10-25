# 0018: WebSocket topics in a store actor, with drop-on-full fan-out

BND-53 adds publish and subscribe on top of the BND-52 session layer
([0015](0015-websocket-mailbox.md)). Three questions shaped it: where
membership lives, what a publisher does when a subscriber can't keep up, and
whether a publication can wake an idle subscriber.

## One registry, one actor

The registry is the pure `src/ws/topics.bend`: a list of `Sub{topic, id,
target}` entries, the next connection ID, and the IDs of connections that
joined and have not closed. A `B.Store` actor owns it, so
subscribe, unsubscribe, join and remove are serialized as store updates.
`src/ws/pubsub.bend` is the IO shell around it.

Connections need an identity to unsubscribe and to exclude a sender. Channels
can't be compared, so each connection joins the hub when it opens and receives
a counter ID from the registry, which also marks the ID active.
`P.handlers` wraps the application's templates. Its state holds the user's
state, the ID and the hub, and its `close` wrapper removes the ID from every
topic and revokes it in one store update before calling the user's `close`.
BND-52 runs `close` exactly once on every session end, including EOF and
transport failure (1006), so cleanup needs no separate path.

A join is a store update, and it can time out after the actor has queued it.
The actor still commits it, so the session would hold ID 0 while a real ID
sat in the active set with nothing to revoke it. Each connection therefore
joins under a token of 128 random bits, and the actor holds a `T.Ledger`: the
registry plus the `(token, id)` claims. Close releases by token, which
revokes every ID the token claimed. The release is queued behind the join in
the actor's mailbox, so it finds the claim even when the session never
learned its ID. A session whose join timed out has ID 0 and cannot
subscribe. If the system has no entropy, the connection does not join at
all. We considered having the close path wait again for the join's reply,
but that wait can time out too.

A `P.Peer` is ordinary data, so an application can keep one after its
connection closes. `P.subscribe` goes through `T.admit_within`, which records
the subscription only for an active ID and within the hub's limits (below).
When it admits a new subscription, the result is exactly `T.admit`. A repeat
subscription leaves the registry unchanged, where `T.admit` would replace the
existing record. A subscribe that
the actor serializes after the close cleanup leaves the registry unchanged and
returns `False`, so it cannot re-register a dead connection.

The release must reach the actor, or the ID stays active and its claim stays
in the ledger forever (BND-98). A store update with the hub's timeout gives up
when the actor's 128-request queue stays full past it, so the release instead
goes through `Store.update_queued`: a blocking `Chan.send` that parks until
there is room, then a bounded wait for the reply. Parked senders form a FIFO
ring in the channel, and each slot the actor frees goes to the oldest one, so
the release cannot be starved by later requests. We considered retrying a
bounded update with backoff instead. Each retry after a reply timeout would
queue a duplicate release (harmless, since a second release of a token is a
no-op), adding load to the queue that was already full.

A publication's pruning is a bounded update. If it fails, the dead entry is
still harmless: its connection is closed, so the next publication to that
topic counts it as `gone` and prunes it again. Pruning goes through
`T.prune`, which also forgets the claims of the pruned IDs, so the claims
list does not grow with connections whose own release never ran. Liveness is checked apart from
the message: when a message is too large for the subscriber's `max_message`,
the publisher does not offer it, and instead probes the handle's `alive`
channel. That channel has no room and no receiver, so a send to it never
lands. It waits while the connection runs and fails once the connection
closes it together with the mailbox. An oversized message therefore still
counts an open subscriber as `dropped` and a closed one as `gone`.

The list representation keeps the laws simple and costs O(subscriptions) per
operation. A publication reads a snapshot of the whole registry with
`Store.get`. That is fine for the chat-sized registries BND-65 needs, and the
per-hub limit caps the length. A large deployment would want a map keyed by
topic, with the same laws.

The module is opt-in: `src/main.bend` doesn't import it, so apps without
topics don't pay its compile cost.

## Subscription limits

BND-105 caps the registry, because the launch review had one peer register
256 topics and nothing stopped it from registering more. Every subscribe and
publication walks the list, so an unbounded registry is unbounded work and
memory for the hub. Each hub carries a `T.Limits`, and `T.admit_within`
checks it inside the same store update that records the subscription, so
concurrent subscribes cannot overshoot. `T.decide` runs the checks in order
and the first one that fails names the refusal: the connection is not active
(`NotActive`), the topic is longer than `topic_bytes` in UTF-8 (`TopicTooLong`),
the connection already holds the topic (`AlreadyMember`, which uses no slot),
the connection holds `per_peer` topics (`PeerFull`), or the hub holds
`per_hub` subscriptions (`HubFull`). Only `Admitted` changes the registry.

The defaults are 128 topics per connection and 255-byte topic names,
Centrifugo's `channel_limit` and `channel.max_length`. Bun and uWebSockets.js
set no limits, which is how the launch review's peer got its 256 topics.
Neither has a hub-wide cap either. We add one, 65,536 subscriptions, because
the per-connection cap alone does not bound the list: it grows with the number
of connections. 65,536 is 512 connections at the per-connection limit.
`P.hub_with(P.limits(per_peer, per_hub, topic_bytes), timeout_ms)` changes
them.

`Store.update` returns the new state but no result, so the shell cannot learn
the verdict from the update itself. `P.subscribe_checked` instead decides
again on the registry it gets back. A refusal left the registry unchanged, so
the same check fails the same way, and an admission now finds the connection
in the topic and reads as `AlreadyMember`. Both map to `P.Subscribed{}`. We
considered a store update that returns a value, but `B.Store` has none, and
the second decision is a pure function of the reply.

Unsubscribing frees a slot at once, and closing a connection frees all of
them, so a closed connection cannot hold slots against the hub.

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
the pair. The first laws cover subscribe and unsubscribe membership, remove
leaving every topic, independence of other topics, publication targets equal
to members minus the sender, and, over any history of subscribe, unsubscribe
and remove, agreement with the model and exactly-once targeting.

Review round 1 added laws over complete records, so a swapped mailbox handle
would fail them. A publication selects exactly the spec's filter of the
records (topic, sender excluded, targets included). Subscribing stores its
target and replaces the earlier record for the pair. Unsubscribe, remove and
the independence laws are stated over whole records too, and remove keeps
`next`. `admit` is `subscribe` for an active ID and a no-op otherwise, and an
admit after `remove(c)` changes nothing. The allocator laws say `join`
increments `next`, returns the old value, keeps every record, and adds only
the new ID to the active set.

They also define `Spec.wf`: no pair recorded twice, every record's ID active,
every active ID below `next`, and `next` positive. The empty registry is
well-formed, and `join`, `admit`, `unsubscribe`, `remove` and `remove_all`
preserve it, so every registry reachable through the shell's operations is
well-formed (`ws_topics_history_wf`, over histories with a target on each
subscribe plus joins, closes and prunes). In a well-formed registry, a newly
joined ID is nonzero and differs from every active and subscribed ID, and a
publication selects each subscribed connection exactly once, minus the sender.

Review round 2 added the ledger laws. `claim(k)` is `join` on the registry
and records the new ID under `k`. Registry changes keep every claim.
`release(k)` revokes and unsubscribes every ID claimed under `k` and forgets
those claims. So a claim followed by any registry changes and then a release
of the same token leaves the claimed ID inactive (`ws_topics_late_join_released`).
`claim` and `release` preserve `Spec.wf`, and so does every ledger history
(`ws_topics_ledger_history_wf`).

BND-98 added laws about other connections' claims. A claim or release under
one token keeps every other token's claims. A prune changes the registry as
`remove_all` does and keeps exactly the claims of the IDs it did not prune.
Over any ledger history after a claim, including other tokens' claims and
releases, prunes, and the same token's earlier claims and releases, a release
of the token leaves the claimed ID inactive and in no topic
(`ws_topics_history_release_revokes`, `ws_topics_history_release_leaves`). The
proof carries one invariant through each step: the ID is below `next`, and
either still claimed under the token or inactive and unsubscribed.
`proof/ws-topics.bend` proves all of them.

BND-105 added the limit laws in `proof/ws-limits-laws.bend`. A refused
subscribe leaves the registry unchanged, and an admitted one is exactly
`T.admit`, so the laws above cover it. No subscribe takes a connection past
`per_peer` or the registry past `per_hub`, a topic longer than `topic_bytes`
is never recorded, and a repeat changes nothing. Closing a connection leaves
it no slots and returns every one of them to the hub. Deciding again on the
updated registry gives the verdict the subscribe got, which is how the shell
reports it. These bounds would hold for a hub that refused everything, so
review round 1 added the converse: the decision equals an independent table
in `proof/ws-limits-spec.bend`, stated over the membership model, with the
refusal order above, and `T.admit_within` subscribes whenever every check
passes. `proof/ws-limits.bend` proves them.
