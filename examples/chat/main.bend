# Chat rooms over WebSocket publish/subscribe. Each room is a topic on one
# P.Hub; a second topic carries the room counts to every connection. The
# lobby store keeps each room's recent lines and who is in it (chat.bend).
import Base
import ../../src/main.bend as B
import ../../src/ws/connection.bend as W
import ../../src/ws/message.bend as M
import ../../src/ws/pubsub.bend as P
import ../../src/app/store.bend as Store
import ../../src/effects/clock.bend as Clock
import ../../src/router/methods.bend as Methods
import ./chat.bend as Chat

type Route is Data:
  RoomsRoute{}
  SocketRoute{}

type Env is Data:
  Env{hub: P.Hub, lobby: Store.Store<Chat.Lobby>}

# One connection's state: its room, its name, and its hub ID once it has
# entered the lobby (0 before that, or if it never could).
type Seat is Data:
  Seat{room: String, name: String, id: Nat, env: Env}

def presence_topic() -> String:
  "presence"

def millis(got: Result<&1, &1, U32 & String, Nat>) -> Nat:
  match got:
    case Done{ms}: ms
    case Fail{e}: 0n

def now() -> IO(Nat):
  do IO<Nat>:
    got : Result<&1, &1, U32 & String, Nat> <- Clock.wall_millis()
    return millis(got)

def publish(hub: P.Hub, topic: String, text: String) -> IO(Unit):
  do IO<Unit>:
    got : Result<&2, &2, Store.Error, P.Delivery> <- P.publish(hub, topic, text)
    return Unit{}

# Tells the client why, then closes with 1011. Room traffic can fill the
# mailbox during the join and crowd out the error, but W.close is admitted
# even then. A seat with ID 0 never entered the lobby, so its close records
# nothing.
def refuse(+peer: P.Peer, seat: Seat, reason: String) -> IO(Seat):
  do IO<Seat>:
    told : Bool <- W.text(P.handle(peer), Chat.error(reason))
    closing : Bool <- W.close(P.handle(peer), 1011, "unavailable")
    return seat

# None once the welcome is queued, or why it could not be.
def offered(sent: Bool) -> Maybe<&2, String>:
  match sent:
    case True{}: None{}
    case False{}: Some{"Could not send the room. Try again."}

def offer(welcome: Maybe<&2, String>, +peer: P.Peer) -> IO(Maybe<&2, String>):
  match welcome:
    case None{}: IO.pure(Maybe<&2, String>, Some{"This room is full. Try another room."})
    case Some{text}:
      do IO<Maybe<&2, String>>:
        sent : Bool <- W.text(P.handle(peer), text)
        return offered(sent)

# The seat keeps its ID even when the welcome failed: the connection is in
# the lobby, so its close records the departure.
def greeted(problem: Maybe<&2, String>, +peer: P.Peer, seat: Seat) -> IO(Seat):
  match problem:
    case None{}: IO.pure(Seat, seat)
    case Some{reason}: refuse(peer, seat, reason)

# The welcome goes first, so no presence frame reaches the newcomer before
# the snapshot its counts would overwrite.
def welcomed(got: Result<&2, &2, Store.Error, Chat.Lobby>, +peer: P.Peer, room: String, name: String, env: Env) -> IO(Seat):
  match got:
    case Fail{e}: refuse(peer, Seat{room, name, 0n, env}, "The chat is busy. Try again.")
    case Done{+lobby}:
      Env{+hub, store} = env
      +r = room
      do IO<Seat>:
        problem : Maybe<&2, String> <- offer(Chat.welcome(lobby, r, P.id(peer)), peer)
        others : Result<&2, &2, Store.Error, P.Delivery> <- P.publish_others(peer, r, Chat.newest(lobby))
        publish(hub, presence_topic(), Chat.presence(lobby))
        greeted(problem, peer, Seat{r, name, P.id(peer), Env{hub, store}})

def entered(+peer: P.Peer, +room: String, +name: String, env: Env) -> IO(Seat):
  Env{hub, +store} = env
  do IO<Seat>:
    also : Bool <- P.subscribe(peer, presence_topic())
    at : Nat <- now()
    +id : Nat = P.id(peer)
    got : Result<&2, &2, Store.Error, Chat.Lobby> <- Store.update(Chat.Lobby, store, l => Chat.enter(l, id, room, name, at))
    welcomed(got, peer, room, name, Env{hub, store})

def seated(ok: Bool, +peer: P.Peer, room: String, name: String, env: Env) -> IO(Seat):
  match ok:
    case True{}: entered(peer, room, name, env)
    case False{}: refuse(peer, Seat{room, name, 0n, env}, "Could not join the room. Try again.")

# Subscribes to the room before reading the lobby, so a line recorded after
# the welcome snapshot is always delivered live.
def opened_copy(seat: Seat, +peer: P.Peer) -> IO(Seat):
  Seat{+room, name, id, env} = seat
  do IO<Seat>:
    ok : Bool <- P.subscribe(peer, room)
    seated(ok, peer, room, name, env)

def opened(seat: Seat, peer: P.Peer) -> IO(Seat):
  opened_copy(seat, peer)

def posted(got: Result<&2, &2, Store.Error, Chat.Lobby>, hub: P.Hub, room: String) -> IO(Unit):
  match got:
    case Done{lobby}: publish(hub, room, Chat.newest(lobby))
    case Fail{e}: IO.pure(Unit, Unit{})

# Records the line, then sends it to the whole room, the sender included,
# so every client shows the server's seq and time.
def say(text: Maybe<&2, String>, +seat: Seat, +peer: P.Peer) -> IO(Seat):
  match text:
    case None{}:
      do IO<Seat>:
        told : Bool <- W.text(P.handle(peer), Chat.error("Messages are 1 to 2000 characters."))
        return seat
    case Some{t}:
      Seat{+room, +name, +id, Env{+hub, +store}} = seat
      do IO<Seat>:
        at : Nat <- now()
        got : Result<&2, &2, Store.Error, Chat.Lobby> <- Store.update(Chat.Lobby, store, l => Chat.say(l, id, room, name, t, at))
        posted(got, hub, room)
        return seat

def seated_message(id: Nat, +seat: Seat, +peer: P.Peer, text: String) -> IO(Seat):
  match id:
    case 0n: IO.pure(Seat, seat)
    case 1n+k: say(Chat.clean_text(text), seat, peer)

def message_copy(message: M.Message, +seat: Seat, +peer: P.Peer) -> IO(Seat):
  match message:
    case M.TextMessage{text}:
      Seat{room, name, id, env} = seat
      seated_message(id, seat, peer, text)
    case _:
      do IO<Seat>:
        told : Bool <- W.text(P.handle(peer), Chat.error("Send text frames."))
        return seat

def message(seat: Seat, peer: P.Peer, message: M.Message) -> IO(Seat):
  message_copy(message, seat, peer)

def departed(got: Result<&2, &2, Store.Error, Chat.Lobby>, +hub: P.Hub, room: String) -> IO(Unit):
  match got:
    case Fail{e}: IO.pure(Unit, Unit{})
    case Done{+lobby}:
      do IO<Unit>:
        publish(hub, room, Chat.newest(lobby))
        publish(hub, presence_topic(), Chat.presence(lobby))

def leave(id: Nat, +room: String, name: String, env: Env) -> IO(Unit):
  match id:
    case 0n: IO.pure(Unit, Unit{})
    case 1n+k:
      Env{hub, store} = env
      do IO<Unit>:
        at : Nat <- now()
        got : Result<&2, &2, Store.Error, Chat.Lobby> <- Store.update(Chat.Lobby, store, l => Chat.exit(l, 1n+k, room, name, at))
        departed(got, hub, room)

# P.handlers has already removed the connection from every topic, so the
# departure goes to the others only.
def closed(seat: Seat, code: U32, reason: String) -> IO(Unit):
  Seat{room, name, id, env} = seat
  leave(id, room, name, env)

# Fields: max_message, mailbox_capacity, poll_ms, poll_max_ms, idle_ms,
# ping_ms, close_ms, write_ms. Chat.frame_limit() bounds frames both ways,
# and the welcome is cut to fit it. Pings every 20 s keep an open tab inside
# the 60 s idle limit; browsers answer them on their own.
def session() -> W.Config:
  W.Config{Chat.frame_limit(), 64, 10, 100, 60000, 20000, 1000, 30000}

def socket(known: Bool, name: Maybe<&2, String>, +c: B.Ctx, env: Env, room: String) -> IO(B.Res):
  match known name:
    case False{} _: IO.pure(B.Res, B.text(B.status(c, 404), "no such room"))
    case True{} None{}: IO.pure(B.Res, B.text(B.status(c, 400), "name must be 1 to 24 characters"))
    case True{} Some{n}:
      Env{+hub, store} = env
      P.handlers(~Unit, ~Seat, ~opened, ~message, ~closed, c, hub, Seat{room, n, 0n, Env{hub, store}}, B.websocket_config(), session())

def rooms(c: B.Ctx, got: Result<&2, &2, Store.Error, Chat.Lobby>) -> B.Res:
  match got:
    case Done{lobby}: B.json(c, Chat.rooms_json(lobby))
    case Fail{e}: B.text(B.status(c, 503), "unavailable")

def room_param(param: Maybe<&2, String>) -> String:
  match param:
    case Some{r}: r
    case None{}: ""

@unsafe
def respond(route: Route, +c: B.Ctx, env: Env) -> IO(B.Res):
  match route:
    case RoomsRoute{}:
      Env{hub, store} = env
      do IO<B.Res>:
        got : Result<&2, &2, Store.Error, Chat.Lobby> <- Store.get(Chat.Lobby, store)
        return rooms(c, got)
    case SocketRoute{}:
      +room = room_param(B.param(c, "room"))
      socket(Chat.known(room), Chat.clean_name(B.query(c, "name")), c, env, room)

@unsafe
def dispatch(route: Route, c: B.Ctx, env: Env) -> IO(B.Res):
  respond(route, c, env)

@unsafe
def ready(env: Env, result: Result<&2, &2, Methods.BuildError, B.Routes(Route)>) -> IO(Unit):
  match result:
    case Fail{e}: IO.die(Unit, 1, "bad chat routes")
    case Done{routes}: B.serve(~Route, ~Env, ~dispatch, routes, env, B.config())

@unsafe
def main() -> IO(Unit):
  do IO<Unit>:
    hub : P.Hub <- P.hub()
    lobby : Store.Store<Chat.Lobby> <- B.store(Chat.Lobby, Chat.lobby())
    ready(Env{hub, lobby}, B.routes(Route, [B.get(Route, "/api/rooms", RoomsRoute{}), B.get(Route, "/ws/:room", SocketRoute{})]))
