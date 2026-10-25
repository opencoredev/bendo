import Base
import ../../src/main.bend as B
import ../../src/ws/connection.bend as W
import ../../src/ws/message.bend as M
import ../../src/ws/pubsub.bend as P
import ../../src/ws/session.bend as S
import ../../src/ws/topics.bend as T
import ../../src/app/store.bend as Store
import ../../src/app/context.bend as C
import ../../src/router/methods.bend as Methods

type Route is Data:
  SocketRoute{}
  PublishRoute{}
  SizeRoute{}
  MembersRoute{}
  HealthRoute{}
  KeepRoute{}
  LateRoute{}
  GhostRoute{}
  ShutRoute{}
  ConnectionsRoute{}
  DelayedRoute{}
  JammedRoute{}
  HoldRoute{}
  FillRoute{}
  FreeRoute{}
  ClaimsRoute{}

# `kept` holds the Peer of the latest /keep connection, so a request can
# subscribe it after that connection has closed. `slow` reaches the same
# registry through `relay`, and `jam` through `gate`, which holds requests
# while `held` is True.
type Shared is Data:
  Shared{hub: P.Hub, slow: P.Hub, jam: P.Hub, held: Store.Store<Bool>, kept: Store.Store<Maybe<&2, P.Peer>>}

def flag(ok: Bool) -> String:
  match ok:
    case True{}: "yes"
    case False{}: "no"

def topic_of(param: Maybe<&2, String>) -> String:
  match param:
    case Some{t}: t
    case None{}: "none"

def join_topic(+peer: P.Peer, topic: String) -> IO(Bool):
  match topic:
    case "none": IO.pure(Bool, True{})
    case _: P.subscribe(peer, topic)

# Subscribes to the route's topic ("none" skips it), then reports
# `ready <id> <yes|no>` so a client knows the registry has it.
def opened_copy(topic: String, +peer: P.Peer) -> IO(String):
  do IO<String>:
    +joined : String = topic
    ok : Bool <- join_topic(peer, joined)
    sent : Bool <- W.text(P.handle(peer), "ready " ++ Nat.show(P.id(peer)) ++ " " ++ flag(ok))
    return joined

def opened(topic: String, peer: P.Peer) -> IO(String):
  opened_copy(topic, peer)

def delivery_text(got: Result<&2, &2, Store.Error, P.Delivery>) -> String:
  match got:
    case Done{P.Delivery{sent, dropped, gone}}: Nat.show(sent) ++ " " ++ Nat.show(dropped) ++ " " ++ Nat.show(gone)
    case Fail{e}: "unavailable"

# Text commands: `sub <t>`, `unsub <t>` (both answer), `pub <t> <m>` publishes
# to everyone else on t, and `all <t> <m>` publishes to every member of t.
def run(+peer: P.Peer, verb: String, +topic: String, +body: String) -> IO(Unit):
  match verb:
    case "sub":
      do IO<Unit>:
        ok : Bool <- P.subscribe(peer, topic)
        sent : Bool <- W.text(P.handle(peer), "subscribed " ++ topic ++ " " ++ flag(ok))
        return Unit{}
    case "unsub":
      do IO<Unit>:
        ok : Bool <- P.unsubscribe(peer, topic)
        sent : Bool <- W.text(P.handle(peer), "unsubscribed " ++ topic ++ " " ++ flag(ok))
        return Unit{}
    case "pub":
      do IO<Unit>:
        got : Result<&2, &2, Store.Error, P.Delivery> <- P.publish_others(peer, topic, body)
        return Unit{}
    case "all":
      do IO<Unit>:
        got : Result<&2, &2, Store.Error, P.Delivery> <- P.publish(P.peer_hub(peer), topic, body)
        return Unit{}
    case _: IO.pure(Unit, Unit{})

def verb_args(+peer: P.Peer, verb: String, rest: List<&2, String>) -> IO(Unit):
  match rest:
    case topic <> more: run(peer, verb, topic, String.join(more, " "))
    case Nil{}: IO.pure(Unit, Unit{})

def words(+peer: P.Peer, ws: List<&2, String>) -> IO(Unit):
  match ws:
    case verb <> rest: verb_args(peer, verb, rest)
    case Nil{}: IO.pure(Unit, Unit{})

def message_copy(+topic: String, +peer: P.Peer, message: M.Message) -> IO(String):
  match message:
    case M.TextMessage{text}:
      do IO<String>:
        words(peer, String.split(text, ' '))
        return topic
    case M.BinaryMessage{bytes}:
      do IO<String>:
        got : Result<&2, &2, Store.Error, P.Delivery> <- P.publish_binary_others(peer, topic, bytes)
        return topic
    case _: IO.pure(String, topic)

def message(topic: String, peer: P.Peer, message: M.Message) -> IO(String):
  message_copy(topic, peer, message)

def closed(topic: String, code: U32, reason: String) -> IO(Unit):
  IO.pure(Unit, Unit{})

# /keep: retains the Peer without subscribing it, then reports `ready <id>`.
def kept_open_copy(+kept: Store.Store<Maybe<&2, P.Peer>>, +peer: P.Peer) -> IO(Store.Store<Maybe<&2, P.Peer>>):
  do IO<Store.Store<Maybe<&2, P.Peer>>>:
    got : Result<&2, &2, Store.Error, Maybe<&2, P.Peer>> <- Store.update(Maybe<&2, P.Peer>, kept, old => Some{peer})
    sent : Bool <- W.text(P.handle(peer), "ready " ++ Nat.show(P.id(peer)))
    return kept

def kept_open(kept: Store.Store<Maybe<&2, P.Peer>>, peer: P.Peer) -> IO(Store.Store<Maybe<&2, P.Peer>>):
  kept_open_copy(kept, peer)

def kept_message(kept: Store.Store<Maybe<&2, P.Peer>>, peer: P.Peer, message: M.Message) -> IO(Store.Store<Maybe<&2, P.Peer>>):
  IO.pure(Store.Store<Maybe<&2, P.Peer>>, kept)

def kept_closed(kept: Store.Store<Maybe<&2, P.Peer>>, code: U32, reason: String) -> IO(Unit):
  IO.pure(Unit, Unit{})

def late_peer(got: Result<&2, &2, Store.Error, Maybe<&2, P.Peer>>, topic: String) -> IO(Bool):
  match got:
    case Done{Some{peer}}: P.subscribe(peer, topic)
    case _: IO.pure(Bool, False{})

# Subscribes the retained /keep Peer to `topic`.
def late(kept: Store.Store<Maybe<&2, P.Peer>>, topic: String) -> IO(Bool):
  do IO<Bool>:
    got : Result<&2, &2, Store.Error, Maybe<&2, P.Peer>> <- Store.get(Maybe<&2, P.Peer>, kept)
    late_peer(got, topic)

# A subscriber whose connection has closed but is still registered, as when
# its close-path removal failed: a closed mailbox, liveness channel and close
# slot, and a `max_message` of 20 bytes.
def ghost(+hub: P.Hub, +topic: String) -> IO(Bool):
  do IO<Bool>:
    +outbound : Chan(S.Command) <- Chan.new(S.Command, 1)
    +alive : Chan(Unit) <- Chan.new(Unit, 0)
    +slot : Chan(S.Command) <- Chan.new(S.Command, 1)
    +claim : Chan(Unit) <- Chan.new(Unit, 1)
    Chan.close(S.Command, outbound)
    Chan.close(Unit, alive)
    Chan.close(S.Command, slot)
    id : Nat <- P.join(hub, "ghost:" ++ topic)
    P.subscribe(P.Peer{W.Handle{outbound, 20, alive, slot, claim}, id, hub}, topic)

# A subscriber whose close found its one-command mailbox full, so the close
# claimed the reserved slot and shut the mailbox. Nothing drains it, as when the
# connection is still inside `open`. `max_message` is 20 bytes.
def shut(+hub: P.Hub, +topic: String) -> IO(String):
  do IO<String>:
    +outbound : Chan(S.Command) <- Chan.new(S.Command, 1)
    +alive : Chan(Unit) <- Chan.new(Unit, 0)
    +slot : Chan(S.Command) <- Chan.new(S.Command, 1)
    +claim : Chan(Unit) <- Chan.new(Unit, 1)
    +handle : W.Handle = W.Handle{outbound, 20, alive, slot, claim}
    queued : Bool <- W.text(handle, "queued")
    closing : Bool <- W.close(handle, 1000, "bye")
    id : Nat <- P.join(hub, "shut:" ++ topic)
    joined : Bool <- P.subscribe(P.Peer{handle, id, hub}, topic)
    return flag(queued) ++ ":" ++ flag(closing) ++ ":" ++ flag(joined)

def Request() -> Type:
  Store.Message<T.Ledger<W.Handle>>

# Forwards each request to the hub's actor 400 ms late, in order. A request
# through `slow` times out after 100 ms, once it is queued, and still commits.
@unsafe
def relay(+from: Chan(Request()), +to: Chan(Request()), got: Maybe<&1, Request()>) -> IO(Unit):
  match got:
    case None{}: IO.pure(Unit, Unit{})
    case Some{message}:
      do IO<Unit>:
        IO.sleep(400)
        sent : Result<&1, &1, Request(), Unit> <- Chan.send(Request(), to, message)
        next : Maybe<&1, Request()> <- Chan.recv(Request(), from)
        relay(from, to, next)

@unsafe
def relay_start(+from: Chan(Request()), +to: Chan(Request())) -> IO(Unit):
  do IO<Unit>:
    first : Maybe<&1, Request()> <- Chan.recv(Request(), from)
    relay(from, to, first)

@unsafe
def delayed(hub: P.Hub) -> IO(P.Hub):
  P.Hub{Store.Store{to, ms}, limits} = hub
  do IO<P.Hub>:
    +from : Chan(Request()) <- Chan.new(Request(), 128)
    IO.spawn(Unit, relay_start(from, to))
    return P.Hub{Store.Store{from, 100}, limits}

# Waits while `held` is True.
@unsafe
def wait_free(+held: Store.Store<Bool>, flag: Result<&2, &2, Store.Error, Bool>) -> IO(Unit):
  match flag:
    case Done{True{}}:
      do IO<Unit>:
        IO.sleep(5)
        next : Result<&2, &2, Store.Error, Bool> <- Store.get(Bool, held)
        wait_free(held, next)
    case _: IO.pure(Unit, Unit{})

# Forwards each request to the hub's actor in order, but holds the next one
# while `held` is True, so the 128-slot queue in front fills up behind it.
@unsafe
def gate(+from: Chan(Request()), +to: Chan(Request()), +held: Store.Store<Bool>, got: Maybe<&1, Request()>) -> IO(Unit):
  match got:
    case None{}: IO.pure(Unit, Unit{})
    case Some{message}:
      do IO<Unit>:
        flag : Result<&2, &2, Store.Error, Bool> <- Store.get(Bool, held)
        wait_free(held, flag)
        sent : Result<&1, &1, Request(), Unit> <- Chan.send(Request(), to, message)
        next : Maybe<&1, Request()> <- Chan.recv(Request(), from)
        gate(from, to, held, next)

@unsafe
def gate_start(+from: Chan(Request()), +to: Chan(Request()), +held: Store.Store<Bool>) -> IO(Unit):
  do IO<Unit>:
    first : Maybe<&1, Request()> <- Chan.recv(Request(), from)
    gate(from, to, held, first)

# A hub over the same registry whose requests give up after 100 ms.
@unsafe
def jammed(hub: P.Hub, +held: Store.Store<Bool>) -> IO(P.Hub):
  P.Hub{Store.Store{to, ms}, limits} = hub
  do IO<P.Hub>:
    +from : Chan(Request()) <- Chan.new(Request(), 128)
    IO.spawn(Unit, gate_start(from, to, held))
    return P.Hub{Store.Store{from, 100}, limits}

def front_of(hub: P.Hub) -> Chan(Request()):
  P.Hub{Store.Store{front, ms}, limits} = hub
  front

# Offers throwaway reads to `front` without waiting until one is refused, and
# counts those accepted. `last` is the previous offer; the first call passes a
# stand-in, which `previous` takes back off the count.
def fill(+front: Chan(Request()), left: Nat, count: Nat, last: Poll<&1, &1, Result<&1, &1, Request(), Unit>, Request()>) -> IO(Nat):
  match left last:
    case 1n+k Ready{Done{u}}:
      do IO<Nat>:
        reply : Chan(T.Ledger<W.Handle>) <- Chan.new(T.Ledger<W.Handle>, 1)
        sent : Poll<&1, &1, Result<&1, &1, Request(), Unit>, Request()> <- Chan.try_send(Request(), front, Store.Get{reply}, 0)
        fill(front, k, 1n+count, sent)
    case _ _: IO.pure(Nat, T.previous(count))

def claims_text(got: Result<&2, &2, Store.Error, T.Ledger<W.Handle>>) -> String:
  match got:
    case Done{l}: Nat.show(List.length(&2, T.Claim, T.claims(W.Handle, l)))
    case Fail{e}: "unavailable"

def set_text(got: Result<&2, &2, Store.Error, Unit>, text: String) -> String:
  match got:
    case Done{u}: text
    case Fail{e}: "unavailable"

# Fields: max_message, mailbox_capacity, poll_ms, poll_max_ms, idle_ms,
# ping_ms, close_ms, write_ms. /slow holds one queued message and polls its
# mailbox only once a minute unless bytes arrive; /ws keeps the default
# 10 ms poll and 100 ms idle backoff, with room for a 64-message burst.
def session_config(path: String) -> W.Config:
  match path:
    case "slow": W.Config{1048576, 1, 60000, 60000, 0, 0, 100, 1000}
    case "small": W.Config{20, 64, 10, 100, 60000, 0, 200, 1000}
    case _: W.Config{1048576, 64, 10, 100, 60000, 0, 200, 1000}

def mode(param: Maybe<&2, String>) -> String:
  match param:
    case Some{m}: m
    case None{}: "ws"

def parsed(n: Maybe<&2, Nat>) -> Nat:
  match n:
    case Some{k}: k
    case None{}: 1n

def count_of(param: Maybe<&2, String>) -> Nat:
  match param:
    case Some{n}: parsed(Nat.read(n))
    case None{}: 1n

def add(a: P.Delivery, b: Result<&2, &2, Store.Error, P.Delivery>) -> P.Delivery:
  P.Delivery{s, d, g} = a
  match b:
    case Done{P.Delivery{s2, d2, g2}}: P.Delivery{Nat.add(s, s2), Nat.add(d, d2), Nat.add(g, g2)}
    case Fail{e}: P.Delivery{s, d, g}

# Publishes `<m>:1` through `<m>:<n>` one after another from this request.
def burst(+hub: P.Hub, +topic: String, +text: String, left: Nat, +i: Nat, total: P.Delivery) -> IO(P.Delivery):
  match left:
    case 0n: IO.pure(P.Delivery, total)
    case 1n+k:
      do IO<P.Delivery>:
        got : Result<&2, &2, Store.Error, P.Delivery> <- P.publish(hub, topic, text ++ ":" ++ Nat.show(1n+i))
        burst(hub, topic, text, k, 1n+i, add(total, got))

def shown(d: P.Delivery) -> String:
  P.Delivery{s, d2, g} = d
  Nat.show(s) ++ " " ++ Nat.show(d2) ++ " " ++ Nat.show(g)

def size_text(got: Result<&2, &2, Store.Error, Nat>) -> String:
  match got:
    case Done{n}: Nat.show(n)
    case Fail{e}: "unavailable"

def members_text(got: Result<&2, &2, Store.Error, List<&2, Nat>>) -> String:
  match got:
    case Done{ids}: Nat.show(List.length(&2, Nat, ids))
    case Fail{e}: "unavailable"

def text_param(param: Maybe<&2, String>) -> String:
  match param:
    case Some{m}: m
    case None{}: "m"

@unsafe
def handler(route: Route, +c: B.Context(Unit), +hub: P.Hub, slow: P.Hub, +jam: P.Hub, +held: Store.Store<Bool>, +kept: Store.Store<Maybe<&2, P.Peer>>) -> IO(B.Res):
  match route:
    case SocketRoute{}:
      P.handlers(~Unit, ~String, ~opened, ~message, ~closed, c, hub, topic_of(B.param(c, "topic")), B.websocket_config(), session_config(mode(B.query(c, "mode"))))
    case PublishRoute{}:
      do IO<B.Res>:
        total : P.Delivery <- burst(hub, topic_of(B.param(c, "topic")), text_param(B.query(c, "m")), count_of(B.query(c, "n")), 0n, P.Delivery{0n, 0n, 0n})
        return B.text(c, shown(total))
    case SizeRoute{}:
      do IO<B.Res>:
        got : Result<&2, &2, Store.Error, Nat> <- P.size(hub)
        return B.text(c, size_text(got))
    case MembersRoute{}:
      do IO<B.Res>:
        got : Result<&2, &2, Store.Error, List<&2, Nat>> <- P.members(hub, topic_of(B.param(c, "topic")))
        return B.text(c, members_text(got))
    case HealthRoute{}: IO.pure(B.Res, B.text(c, "ok"))
    case KeepRoute{}:
      P.handlers(~Unit, ~(Store.Store<Maybe<&2, P.Peer>>), ~kept_open, ~kept_message, ~kept_closed, c, hub, kept, B.websocket_config(), W.defaults())
    case LateRoute{}:
      do IO<B.Res>:
        ok : Bool <- late(kept, topic_of(B.param(c, "topic")))
        return B.text(c, flag(ok))
    case GhostRoute{}:
      do IO<B.Res>:
        ok : Bool <- ghost(hub, topic_of(B.param(c, "topic")))
        return B.text(c, flag(ok))
    case ShutRoute{}:
      do IO<B.Res>:
        answer : String <- shut(hub, topic_of(B.param(c, "topic")))
        return B.text(c, answer)
    case ConnectionsRoute{}:
      do IO<B.Res>:
        got : Result<&2, &2, Store.Error, Nat> <- P.connections(hub)
        return B.text(c, size_text(got))
    case DelayedRoute{}:
      P.handlers(~Unit, ~String, ~opened, ~message, ~closed, c, slow, "none", B.websocket_config(), W.defaults())
    case JammedRoute{}:
      P.handlers(~Unit, ~String, ~opened, ~message, ~closed, c, jam, "none", B.websocket_config(), W.defaults())
    case HoldRoute{}:
      do IO<B.Res>:
        got : Result<&2, &2, Store.Error, Unit> <- Store.set(Bool, held, True{})
        return B.text(c, set_text(got, "held"))
    case FillRoute{}:
      do IO<B.Res>:
        n : Nat <- fill(front_of(jam), 1000n, 0n, Ready{Done{Unit{}}})
        return B.text(c, Nat.show(n))
    case FreeRoute{}:
      do IO<B.Res>:
        got : Result<&2, &2, Store.Error, Unit> <- Store.set(Bool, held, False{})
        return B.text(c, set_text(got, "free"))
    case ClaimsRoute{}:
      do IO<B.Res>:
        got : Result<&2, &2, Store.Error, T.Ledger<W.Handle>> <- Store.get(T.Ledger<W.Handle>, P.registry(hub))
        return B.text(c, claims_text(got))

@unsafe
def dispatch(route: Route, c: B.Context(Unit), shared: Shared) -> IO(B.Res):
  Shared{hub, slow, jam, held, kept} = shared
  handler(route, c, hub, slow, jam, held, kept)

@unsafe
def ready(shared: Shared, result: Result<&2, &2, Methods.BuildError, B.Routes(Route)>) -> IO(Unit):
  match result:
    case Fail{e}: IO.die(Unit, 1, "routes")
    case Done{routes}: B.serve(~Route, ~Shared, ~dispatch, routes, shared, B.config())

@unsafe
def main() -> IO(Unit):
  do IO<Unit>:
    +hub : P.Hub <- P.hub()
    slow : P.Hub <- delayed(hub)
    +held : Store.Store<Bool> <- B.store(Bool, False{})
    jam : P.Hub <- jammed(hub, held)
    kept : Store.Store<Maybe<&2, P.Peer>> <- B.store(Maybe<&2, P.Peer>, None{})
    ready(Shared{hub, slow, jam, held, kept}, B.routes(Route, [B.get(Route, "/", HealthRoute{}), B.get(Route, "/ws/:topic", SocketRoute{}), B.post(Route, "/publish/:topic", PublishRoute{}), B.get(Route, "/size", SizeRoute{}), B.get(Route, "/members/:topic", MembersRoute{}), B.get(Route, "/keep", KeepRoute{}), B.post(Route, "/late/:topic", LateRoute{}), B.post(Route, "/ghost/:topic", GhostRoute{}), B.post(Route, "/shut/:topic", ShutRoute{}), B.get(Route, "/connections", ConnectionsRoute{}), B.get(Route, "/delayed", DelayedRoute{}), B.get(Route, "/jammed", JammedRoute{}), B.post(Route, "/jam/hold", HoldRoute{}), B.post(Route, "/jam/fill", FillRoute{}), B.post(Route, "/jam/free", FreeRoute{}), B.get(Route, "/claims", ClaimsRoute{})]))
