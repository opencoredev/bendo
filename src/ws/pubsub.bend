# WebSocket publish/subscribe (BND-53). A Hub is a B.Store actor holding the
# pure topics.bend registry; each connection joins it on open and leaves it on
# every close path. Publication never waits on a recipient: a full mailbox
# drops that recipient's copy (decision 0016).
import Base
import ./topics.bend as T
import ./connection.bend as W
import ./message.bend as M
import ./session.bend as S
import ../app/store.bend as Store
import ../app/store_actor.bend as StoreActor
import ../app/context.bend as Context
import ../http/websocket.bend as Handshake
import ../http/response.bend as Response

type Hub is Data:
  Hub{registry: Store.Store<T.Registry<W.Handle>>}

# What a pub/sub handler receives in place of the bare handle: the
# connection's mailbox, its registry ID, and the hub it joined.
type Peer is Data:
  Peer{handle: W.Handle, id: Nat, hub: Hub}

# How one publication went. `sent` mailboxes accepted it; `dropped` were full
# or the message exceeded that open connection's `max_message`; `gone` had
# already closed, whatever the message size, and are removed from the
# registry.
type Delivery is Data:
  Delivery{sent: Nat, dropped: Nat, gone: Nat}

def hub_with_timeout(timeout_ms: U32) -> IO(Hub):
  do IO<Hub>:
    registry : Store.Store<T.Registry<W.Handle>> <- StoreActor.store_with_timeout(T.Registry<W.Handle>, T.empty(W.Handle), timeout_ms)
    return Hub{registry}

def hub() -> IO(Hub):
  hub_with_timeout(5000)

def registry(hub: Hub) -> Store.Store<T.Registry<W.Handle>>:
  Hub{r} = hub
  r

def handle(peer: Peer) -> W.Handle:
  Peer{h, id, hub} = peer
  h

def id(peer: Peer) -> Nat:
  Peer{h, n, hub} = peer
  n

def peer_hub(peer: Peer) -> Hub:
  Peer{h, n, hub} = peer
  hub

def acknowledged(got: Result<&2, &2, Store.Error, T.Registry<W.Handle>>) -> Bool:
  match got:
    case Done{r}: True{}
    case Fail{e}: False{}

def joined_id(got: Result<&2, &2, Store.Error, T.Registry<W.Handle>>) -> Nat:
  match got:
    case Done{r}: T.joined(W.Handle, r)
    case Fail{e}: 0n

# Hands out a fresh connection ID and marks it active; 0 if the hub failed.
# P.handlers joins on open, so call this only for a handle built by hand.
def join(hub: Hub) -> IO(Nat):
  do IO<Nat>:
    got : Result<&2, &2, Store.Error, T.Registry<W.Handle>> <- Store.update(T.Registry<W.Handle>, registry(hub), r => T.join(W.Handle, r))
    return joined_id(got)

def change(hub: Hub, update: T.Registry<W.Handle> -> T.Registry<W.Handle>) -> IO(Bool):
  do IO<Bool>:
    got : Result<&2, &2, Store.Error, T.Registry<W.Handle>> <- Store.update(T.Registry<W.Handle>, registry(hub), update)
    return acknowledged(got)

def subscribed(got: Result<&2, &2, Store.Error, T.Registry<W.Handle>>, +id: Nat) -> Bool:
  match got:
    case Done{r}: T.active(W.Handle, r, id)
    case Fail{e}: False{}

def subscribe_active(+id: Nat, hub: Hub, topic: String, +handle: W.Handle) -> IO(Bool):
  do IO<Bool>:
    got : Result<&2, &2, Store.Error, T.Registry<W.Handle>> <- Store.update(T.Registry<W.Handle>, registry(hub), r => T.admit(W.Handle, r, id, topic, handle))
    return subscribed(got, id)

def subscribe_id(id: Nat, hub: Hub, topic: String, +handle: W.Handle) -> IO(Bool):
  match id:
    case 0n: IO.pure(Bool, False{})
    case 1n+n: subscribe_active(1n+n, hub, topic, handle)

# True once the registry has recorded the subscription. A publication that
# starts after this returns reaches the connection. False means the hub
# timed out or is unavailable, or the connection never joined or has already
# closed: the close path revokes the ID in the same registry update that
# removes its subscriptions, so a Peer kept after close cannot re-register.
def subscribe(peer: Peer, topic: String) -> IO(Bool):
  Peer{+h, id, hub} = peer
  subscribe_id(id, hub, topic, h)

def unsubscribe(peer: Peer, topic: String) -> IO(Bool):
  Peer{h, id, hub} = peer
  change(hub, r => T.unsubscribe(W.Handle, r, id, topic))

def leave(hub: Hub, id: Nat) -> IO(Bool):
  change(hub, r => T.remove(W.Handle, r, id))

type Offer is Data:
  Accepted{}
  Full{}
  Oversized{}
  Gone{}

def offered(result: Poll<&1, &1, Result<&1, &1, S.Command, Unit>, S.Command>) -> Offer:
  match result:
    case Ready{Done{u}}: Accepted{}
    case Ready{Fail{command}}: Gone{}
    case Wait{command}: Full{}

def refused(live: Bool) -> Offer:
  match live:
    case True{}: Oversized{}
    case False{}: Gone{}

def offer_checked(ok: Bool, +handle: W.Handle, command: S.Command) -> IO(Offer):
  match ok:
    case False{}:
      do IO<Offer>:
        live : Bool <- W.live(handle)
        return refused(live)
    case True{}:
      do IO<Offer>:
        result : Poll<&1, &1, Result<&1, &1, S.Command, Unit>, S.Command> <- Chan.try_send(S.Command, W.outbound(handle), command, 0)
        return offered(result)

# Same admission as W.enqueue, but tells a full mailbox from a closed one. A
# command too large for the connection is never offered; the connection's
# liveness is checked on its own, so a closed one is still pruned.
def offer(+handle: W.Handle, +command: S.Command) -> IO(Offer):
  offer_checked(S.admissible(W.max_message(handle), command), handle, command)

type Tally is Data:
  Tally{delivery: Delivery, gone: List<&2, Nat>}

def counted(tally: Tally, id: Nat, result: Offer) -> Tally:
  Tally{Delivery{sent, dropped, n}, ids} = tally
  match result:
    case Accepted{}: Tally{Delivery{1n+sent, dropped, n}, ids}
    case Full{}: Tally{Delivery{sent, 1n+dropped, n}, ids}
    case Oversized{}: Tally{Delivery{sent, 1n+dropped, n}, ids}
    case Gone{}: Tally{Delivery{sent, dropped, 1n+n}, id <> ids}

# One nonblocking offer per target, in registry order. Each publication
# finishes its offers before the publisher can start another, so one
# publisher's messages reach each recipient's FIFO mailbox in order.
def deliver(+command: S.Command, xs: List<&2, T.Sub<W.Handle>>, tally: Tally) -> IO(Tally):
  match xs:
    case Nil{}: IO.pure(Tally, tally)
    case T.Sub{topic, +sid, handle} <> rest:
      do IO<Tally>:
        result : Offer <- offer(handle, command)
        deliver(command, rest, counted(tally, sid, result))

def pruned(tally: Tally, hub: Hub) -> IO(Delivery):
  Tally{delivery, ids} = tally
  match ids:
    case Nil{}: IO.pure(Delivery, delivery)
    case +first <> rest:
      do IO<Delivery>:
        ok : Bool <- change(hub, r => T.remove_all(W.Handle, first <> rest, r))
        return delivery

def fan_out(+hub: Hub, +topic: String, +sender: Maybe<&2, Nat>, +command: S.Command, got: Result<&2, &2, Store.Error, T.Registry<W.Handle>>) -> IO(Result<&2, &2, Store.Error, Delivery>):
  match got:
    case Fail{e}: IO.pure(Result<&2, &2, Store.Error, Delivery>, Fail{e})
    case Done{r}:
      do IO<Result<&2, &2, Store.Error, Delivery>>:
        tally : Tally <- deliver(command, T.targets(W.Handle, r, topic, sender), Tally{Delivery{0n, 0n, 0n}, []})
        delivery : Delivery <- pruned(tally, hub)
        return Done{delivery}

# Reaches the members subscribed when the registry snapshot is taken.
def publish_command(+hub: Hub, topic: String, sender: Maybe<&2, Nat>, command: S.Command) -> IO(Result<&2, &2, Store.Error, Delivery>):
  do IO<Result<&2, &2, Store.Error, Delivery>>:
    got : Result<&2, &2, Store.Error, T.Registry<W.Handle>> <- Store.get(T.Registry<W.Handle>, registry(hub))
    fan_out(hub, topic, sender, command, got)

# Server-side publication, for an HTTP route or any other computation: every
# member of the topic.
def publish(hub: Hub, topic: String, text: String) -> IO(Result<&2, &2, Store.Error, Delivery>):
  publish_command(hub, topic, None{}, S.SendText{text})

def publish_binary(hub: Hub, topic: String, bytes: List<&2, U32>) -> IO(Result<&2, &2, Store.Error, Delivery>):
  publish_command(hub, topic, None{}, S.SendBinary{bytes})

# Publication from a connection, like Elysia's `ws.publish`: every member of
# the topic except the sender.
def publish_others(peer: Peer, topic: String, text: String) -> IO(Result<&2, &2, Store.Error, Delivery>):
  Peer{h, id, hub} = peer
  publish_command(hub, topic, Some{id}, S.SendText{text})

def publish_binary_others(peer: Peer, topic: String, bytes: List<&2, U32>) -> IO(Result<&2, &2, Store.Error, Delivery>):
  Peer{h, id, hub} = peer
  publish_command(hub, topic, Some{id}, S.SendBinary{bytes})

def registered(got: Result<&2, &2, Store.Error, T.Registry<W.Handle>>, +topic: String) -> Result<&2, &2, Store.Error, List<&2, Nat>>:
  match got:
    case Done{r}: Done{T.members(W.Handle, r, topic)}
    case Fail{e}: Fail{e}

def members(hub: Hub, topic: String) -> IO(Result<&2, &2, Store.Error, List<&2, Nat>>):
  do IO<Result<&2, &2, Store.Error, List<&2, Nat>>>:
    got : Result<&2, &2, Store.Error, T.Registry<W.Handle>> <- Store.get(T.Registry<W.Handle>, registry(hub))
    return registered(got, topic)

def counted_subs(got: Result<&2, &2, Store.Error, T.Registry<W.Handle>>) -> Result<&2, &2, Store.Error, Nat>:
  match got:
    case Done{r}: Done{T.size(W.Handle, r)}
    case Fail{e}: Fail{e}

# Subscriptions held across all topics; zero once every connection is gone.
def size(hub: Hub) -> IO(Result<&2, &2, Store.Error, Nat>):
  do IO<Result<&2, &2, Store.Error, Nat>>:
    got : Result<&2, &2, Store.Error, T.Registry<W.Handle>> <- Store.get(T.Registry<W.Handle>, registry(hub))
    return counted_subs(got)

def counted_connections(got: Result<&2, &2, Store.Error, T.Registry<W.Handle>>) -> Result<&2, &2, Store.Error, Nat>:
  match got:
    case Done{r}: Done{T.connections(W.Handle, r)}
    case Fail{e}: Fail{e}

# Connections that joined and have not closed.
def connections(hub: Hub) -> IO(Result<&2, &2, Store.Error, Nat>):
  do IO<Result<&2, &2, Store.Error, Nat>>:
    got : Result<&2, &2, Store.Error, T.Registry<W.Handle>> <- Store.get(T.Registry<W.Handle>, registry(hub))
    return counted_connections(got)

# The connection's state while it runs: the application's state, plus its
# registry ID (0 until it joins) and hub.
type Joined<-User: Data> is Data:
  Joined{user: User, id: Nat, hub: Hub}

def joined_open(~User: Data, ~on_open: User -> Peer -> IO(User), state: Joined<User>, handle: W.Handle) -> IO(Joined<User>):
  Joined{user, old, +hub} = state
  do IO<Joined<User>>:
    +id : Nat <- join(hub)
    updated : User <- on_open(user, Peer{handle, id, hub})
    return Joined{updated, id, hub}

def joined_message(~User: Data, ~on_message: User -> Peer -> M.Message -> IO(User), state: Joined<User>, handle: W.Handle, message: M.Message) -> IO(Joined<User>):
  Joined{user, +id, +hub} = state
  do IO<Joined<User>>:
    updated : User <- on_message(user, Peer{handle, id, hub}, message)
    return Joined{updated, id, hub}

# Runs on every close path, 1006 included. The mailbox is already closed, so
# a publication that races this removal is refused, not queued. One registry
# update drops the subscriptions and revokes the ID.
def joined_close(~User: Data, ~on_close: User -> U32 -> String -> IO(Unit), state: Joined<User>, code: U32, reason: String) -> IO(Unit):
  Joined{user, id, hub} = state
  do IO<Unit>:
    left : Bool <- leave(hub, id)
    on_close(user, code, reason)

# B.websocket_handlers with pub/sub: the templates receive a Peer.
@unsafe
def handlers(~Vars: Data, ~User: Data, ~on_open: User -> Peer -> IO(User), ~on_message: User -> Peer -> M.Message -> IO(User), ~on_close: User -> U32 -> String -> IO(Unit), c: Context.Ctx<Vars>, hub: Hub, user: User, handshake: Handshake.Config, config: W.Config) -> IO(Response.Res):
  W.upgrade(~Vars, ~(Joined<User>), ~(joined_open(~User, ~on_open)), ~(joined_message(~User, ~on_message)), ~(joined_close(~User, ~on_close)), c, Joined{user, 0n, hub}, handshake, config)
