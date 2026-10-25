# BND-105 test server: pub/sub subscription limits. /ws/small joins a hub
# limited to 3 subscriptions per connection, 5 in all and 8-byte topics;
# /ws/default joins a hub with the default limits.
import Base
import ../../src/main.bend as B
import ../../src/ws/connection.bend as W
import ../../src/ws/message.bend as M
import ../../src/ws/pubsub.bend as P
import ../../src/app/store.bend as Store
import ../../src/router/methods.bend as Methods

type Route is Data:
  SocketRoute{}
  SizeRoute{}
  MembersRoute{}
  PublishRoute{}

type Hubs is Data:
  Hubs{small: P.Hub, normal: P.Hub}

def answer(s: P.Subscription) -> String:
  match s:
    case P.Subscribed{}: "subscribed"
    case P.Closed{}: "closed"
    case P.TopicTooLong{}: "topic-too-long"
    case P.PeerLimit{}: "peer-limit"
    case P.HubLimit{}: "hub-limit"
    case P.HubError{e}: "unavailable"

def flag(ok: Bool) -> String:
  match ok:
    case True{}: "yes"
    case False{}: "no"

# `sub <t>` answers `sub <t> <outcome>`, `unsub <t>` answers `unsub <t> <yes|no>`.
def run(+peer: P.Peer, verb: String, +topic: String) -> IO(Unit):
  match verb:
    case "sub":
      do IO<Unit>:
        got : P.Subscription <- P.subscribe_checked(peer, topic)
        sent : Bool <- W.text(P.handle(peer), "sub " ++ topic ++ " " ++ answer(got))
        return Unit{}
    case "unsub":
      do IO<Unit>:
        ok : Bool <- P.unsubscribe(peer, topic)
        sent : Bool <- W.text(P.handle(peer), "unsub " ++ topic ++ " " ++ flag(ok))
        return Unit{}
    case _: IO.pure(Unit, Unit{})

# The topic is everything after the verb, so it may hold spaces.
def command(+peer: P.Peer, words: List<&2, String>) -> IO(Unit):
  match words:
    case verb <> rest: run(peer, verb, String.join(rest, " "))
    case Nil{}: IO.pure(Unit, Unit{})

def opened_copy(state: Unit, +peer: P.Peer) -> IO(Unit):
  do IO<Unit>:
    sent : Bool <- W.text(P.handle(peer), "ready " ++ Nat.show(P.id(peer)))
    return state

def opened(state: Unit, peer: P.Peer) -> IO(Unit):
  opened_copy(state, peer)

def message_copy(state: Unit, +peer: P.Peer, message: M.Message) -> IO(Unit):
  match message:
    case M.TextMessage{text}:
      do IO<Unit>:
        command(peer, String.split(text, ' '))
        return state
    case _: IO.pure(Unit, state)

def message(state: Unit, peer: P.Peer, message: M.Message) -> IO(Unit):
  message_copy(state, peer, message)

def closed(state: Unit, code: U32, reason: String) -> IO(Unit):
  IO.pure(Unit, Unit{})

def pick(hubs: Hubs, name: Maybe<&2, String>) -> P.Hub:
  Hubs{small, normal} = hubs
  match name:
    case Some{"small"}: small
    case _: normal

def size_text(got: Result<&2, &2, Store.Error, Nat>) -> String:
  match got:
    case Done{n}: Nat.show(n)
    case Fail{e}: "unavailable"

def members_text(got: Result<&2, &2, Store.Error, List<&2, Nat>>) -> String:
  match got:
    case Done{ids}: Nat.show(List.length(&2, Nat, ids))
    case Fail{e}: "unavailable"

def delivery_text(got: Result<&2, &2, Store.Error, P.Delivery>) -> String:
  match got:
    case Done{P.Delivery{sent, dropped, gone}}: Nat.show(sent)
    case Fail{e}: "unavailable"

def topic_of(param: Maybe<&2, String>) -> String:
  match param:
    case Some{t}: t
    case None{}: ""

@unsafe
def handler(route: Route, +c: B.Context(Unit), +hubs: Hubs) -> IO(B.Res):
  match route:
    case SocketRoute{}:
      P.handlers(~Unit, ~Unit, ~opened, ~message, ~closed, c, pick(hubs, B.param(c, "hub")), Unit{}, B.websocket_config(), W.defaults())
    case SizeRoute{}:
      do IO<B.Res>:
        got : Result<&2, &2, Store.Error, Nat> <- P.size(pick(hubs, B.param(c, "hub")))
        return B.text(c, size_text(got))
    case MembersRoute{}:
      do IO<B.Res>:
        got : Result<&2, &2, Store.Error, List<&2, Nat>> <- P.members(pick(hubs, B.param(c, "hub")), topic_of(B.param(c, "topic")))
        return B.text(c, members_text(got))
    case PublishRoute{}:
      do IO<B.Res>:
        got : Result<&2, &2, Store.Error, P.Delivery> <- P.publish(pick(hubs, B.param(c, "hub")), topic_of(B.param(c, "topic")), "hello")
        return B.text(c, delivery_text(got))

@unsafe
def dispatch(route: Route, c: B.Context(Unit), hubs: Hubs) -> IO(B.Res):
  handler(route, c, hubs)

@unsafe
def ready(hubs: Hubs, result: Result<&2, &2, Methods.BuildError, B.Routes(Route)>) -> IO(Unit):
  match result:
    case Fail{e}: IO.die(Unit, 1, "routes")
    case Done{routes}: B.serve(~Route, ~Hubs, ~dispatch, routes, hubs, B.config())

@unsafe
def main() -> IO(Unit):
  do IO<Unit>:
    small : P.Hub <- P.hub_with(P.limits(3n, 5n, 8n), 5000)
    normal : P.Hub <- P.hub()
    ready(Hubs{small, normal}, B.routes(Route, [B.get(Route, "/ws/:hub", SocketRoute{}), B.get(Route, "/size/:hub", SizeRoute{}), B.get(Route, "/members/:hub/:topic", MembersRoute{}), B.post(Route, "/publish/:hub/:topic", PublishRoute{})]))
