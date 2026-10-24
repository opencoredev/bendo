import Base
import ../../src/main.bend as B
import ../../src/ws/connection.bend as W
import ../../src/ws/message.bend as M
import ../../src/ws/pubsub.bend as P
import ../../src/app/store.bend as Store
import ../../src/app/context.bend as C
import ../../src/router/methods.bend as Methods

type Route is Data:
  SocketRoute{}
  PublishRoute{}
  SizeRoute{}
  MembersRoute{}
  HealthRoute{}

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

# Fields: max_message, mailbox_capacity, poll_ms, poll_max_ms, idle_ms,
# ping_ms, close_ms, write_ms. /slow holds one queued message and polls its
# mailbox only once a minute unless bytes arrive; /ws keeps the default
# 10 ms poll and 100 ms idle backoff, with room for a 64-message burst.
def session_config(path: String) -> W.Config:
  match path:
    case "slow": W.Config{1048576, 1, 60000, 60000, 0, 0, 100, 1000}
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
def handler(route: Route, +c: B.Context(Unit), +hub: P.Hub) -> IO(B.Res):
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

@unsafe
def dispatch(route: Route, c: B.Context(Unit), hub: P.Hub) -> IO(B.Res):
  handler(route, c, hub)

@unsafe
def ready(hub: P.Hub, result: Result<&2, &2, Methods.BuildError, B.Routes(Route)>) -> IO(Unit):
  match result:
    case Fail{e}: IO.die(Unit, 1, "routes")
    case Done{routes}: B.serve(~Route, ~P.Hub, ~dispatch, routes, hub, B.config())

@unsafe
def main() -> IO(Unit):
  do IO<Unit>:
    hub : P.Hub <- P.hub()
    ready(hub, B.routes(Route, [B.get(Route, "/", HealthRoute{}), B.get(Route, "/ws/:topic", SocketRoute{}), B.post(Route, "/publish/:topic", PublishRoute{}), B.get(Route, "/size", SizeRoute{}), B.get(Route, "/members/:topic", MembersRoute{})]))
