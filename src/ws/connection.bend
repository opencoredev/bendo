# One computation owns the socket. A bounded mailbox admits external sends;
# timed reads provide the wakeup boundary because Base has no socket/Chan select.
import Base
import ./frame.bend as F
import ./message.bend as M
import ./session.bend as S
import ../stream.bend as Stream
import ../websocket.bend as Upgrade
import ../http/websocket.bend as Handshake
import ../app/context.bend as Context
import ../http/response.bend as Response

type Config is Data:
  Config{max_message: U32, mailbox_capacity: U32, poll_ms: U32, poll_max_ms: U32, idle_ms: U32, ping_ms: U32, close_ms: U32, write_ms: U32}

def defaults() -> Config: Config{1048576, 16, 10, 100, 60000, 0, 1000, 30000}

# `alive` has no room and no receiver, so a send to it never lands: it waits
# while the connection runs and fails once the connection closes `alive`
# together with its mailbox.
type Handle is Data:
  Handle{outbound: Chan(S.Command), max_message: U32, alive: Chan(Unit)}

def outbound(handle: Handle) -> Chan(S.Command):
  Handle{channel, max, alive} = handle
  channel

def max_message(handle: Handle) -> U32:
  Handle{channel, max, alive} = handle
  max

def running(result: Poll<&1, &1, Result<&1, &1, Unit, Unit>, Unit>) -> Bool:
  match result:
    case Ready{Fail{u}}: False{}
    case _: True{}

# Whether the connection is still open, without touching its mailbox. A
# publisher uses this when a command is too large to offer.
def live(handle: Handle) -> IO(Bool):
  Handle{channel, max, alive} = handle
  do IO<Bool>:
    result : Poll<&1, &1, Result<&1, &1, Unit, Unit>, Unit> <- Chan.try_send(Unit, alive, Unit{}, 0)
    return running(result)

def admitted(result: Poll<&1, &1, Result<&1, &1, S.Command, Unit>, S.Command>) -> Bool:
  match result:
    case Ready{Done{u}}: True{}
    case _: False{}

def enqueue_checked(ok: Bool, channel: Chan(S.Command), command: S.Command) -> IO(Bool):
  match ok:
    case False{}: IO.pure(Bool, False{})
    case True{}:
      do IO<Bool>:
        result : Poll<&1, &1, Result<&1, &1, S.Command, Unit>, S.Command> <- Chan.try_send(S.Command, channel, command, 0)
        return admitted(result)

# Nonblocking admission: False means full, closed, or invalid. Never spawn a
# waiting sender: a broadcast must be free to drop/disconnect a slow recipient.
def enqueue(handle: Handle, +command: S.Command) -> IO(Bool):
  Handle{channel, max, alive} = handle
  enqueue_checked(S.admissible(max, command), channel, command)

def text(handle: Handle, value: String) -> IO(Bool): enqueue(handle, S.SendText{value})
def binary(handle: Handle, bytes: List<&2, U32>) -> IO(Bool): enqueue(handle, S.SendBinary{bytes})
def ping(handle: Handle, bytes: List<&2, U32>) -> IO(Bool): enqueue(handle, S.SendPing{bytes})
def close(handle: Handle, code: U32, reason: String) -> IO(Bool): enqueue(handle, S.SendClose{code, reason})

# `wait` is the next socket read's wait before deadlines shorten it: 0 right
# after a mailbox command, otherwise between poll_ms and poll_max_ms.
type State<-User: Data> is Data:
  State{user: User, phase: S.Phase, assembly: M.State, pending: List<&2, U32>, body: Maybe<&2, F.Body>, received_at: Nat, ping_at: Nat, closing_at: Nat, wait: U32}

def session(-User: Data, state: State<User>) -> S.Session:
  State{user, phase, assembly, pending, body, received, ping, closing, wait} = state
  S.Session{phase, assembly}

def with_wait(-User: Data, state: State<User>, wait: U32) -> State<User>:
  State{user, phase, assembly, pending, body, received, ping, closing, old} = state
  State{user, phase, assembly, pending, body, received, ping, closing, wait}

type Continue is Data:
  ReadNext{}
  CycleNext{}
  MailboxNext{}

type DriveEvent<-User: Data> is Type:
  Cycle{socket: Socket, state: State<User>}
  PollMailbox{socket: Socket, state: State<User>}
  Mail{socket: Socket, state: State<User>, got: Poll<&1, &1, Maybe<&1, S.Command>, Unit>}
  Stepped{socket: Socket, state: State<User>, transition: S.Transition, next: Continue}
  Apply{socket: Socket, state: State<User>, action: S.Action, next: Continue}
  Encoded{socket: Socket, state: State<User>, phase: S.Phase, notice: S.Notice, bytes: Maybe<&2, List<&2, U32>>, next: Continue}
  Wrote{sent: Socket & Bool, state: State<User>, phase: S.Phase, notice: S.Notice, next: Continue}
  Notify{socket: Socket, state: State<User>, notice: S.Notice, next: Continue}
  Input{socket: Socket, state: State<User>}
  Decoded{socket: Socket, state: State<User>, decoded: F.Decoded}
  Read{socket: Socket, state: State<User>}
  Received{result: Socket & Poll<&1, &1, Result<&1, &1, U32 & String, Maybe<&1, List<&2, U32>>>, Unit>, state: State<User>}
  Clock{socket: Socket, state: State<User>, now: Nat}
  Timed{socket: Socket, state: State<User>, now: Nat, expired: Bool, idle: Bool, ping: Bool}

def expired(+now: Nat, since: Nat, +ms: U32) -> Bool:
  Bool.not(U32.is_eq(ms, 0)) && Nat.is_le(U32.to_nat(ms), Nat.sub(now, since))

def wait_ms(ms: U32) -> U32: U32.max(ms, 1)

def wait_cap(+poll: U32, poll_max: U32) -> U32: U32.max(wait_ms(poll), poll_max)

# Idle backoff: each empty read doubles the wait up to the cap. A busy wait
# (0) restarts at the base. `v + min(v, cap - v)` cannot overflow.
def grow(+base: U32, +cap: U32, w: U32) -> U32:
  +v = U32.min(w, cap)
  U32.min(cap, U32.max(base, U32.add(v, U32.min(v, U32.sub(cap, v)))))

def remaining(+now: Nat, since: Nat, ms: U32, budget: U32) -> U32:
  match ms:
    case 0: budget
    case n: U32.min(budget, U32.max(1, U32.from_nat(Nat.sub(U32.to_nat(n), Nat.sub(now, since)))))

def read_ms(-User: Data, cfg: Config, state: State<User>, +now: Nat) -> U32:
  Config{max, room, poll, poll_max, idle, ping, closing_ms, write} = cfg
  State{user, phase, assembly, pending, body, received, ping_at, closing, wait} = state
  match phase:
    case S.WsOpen{}: remaining(now, ping_at, ping, remaining(now, received, idle, wait))
    case S.WsClosing{}: remaining(now, closing, wait_ms(closing_ms), wait)
    case S.WsDone{}: 1

def send_ms(-User: Data, cfg: Config, state: State<User>, now: Nat) -> U32:
  Config{max, room, poll, poll_max, idle, ping, closing_ms, write} = cfg
  State{user, phase, assembly, pending, body, received, ping_at, closing, wait} = state
  match phase:
    case S.WsClosing{}: remaining(now, closing, wait_ms(closing_ms), wait_ms(write))
    case _: wait_ms(write)

def decode(max: U32, bytes: List<&2, U32>, body: Maybe<&2, F.Body>) -> F.Decoded:
  match body:
    case None{}: F.start(F.Config{F.Server{}, S.cap(max)}, bytes)
    case Some{b}: F.resume(b, bytes)

def writing(-User: Data, state: State<User>, phase: S.Phase, now: Nat) -> State<User>:
  State{user, old, assembly, pending, body, received, ping, closing, wait} = state
  match old phase:
    case S.WsOpen{} S.WsClosing{}: State{user, S.WsClosing{}, assembly, pending, body, received, ping, now, wait}
    case _ _: State{user, phase, assembly, pending, body, received, ping, closing, wait}

# Drops queued commands after the mailbox is closed, so a handle kept in a
# store or topic registry no longer holds their payloads. Closed admission
# bounds the queue by its capacity; `fuel` is one more than that.
def discard(+channel: Chan(S.Command), fuel: Nat, got: Poll<&1, &1, Maybe<&1, S.Command>, Unit>) -> IO(Unit):
  match fuel got:
    case 1n+n Ready{Some{command}}:
      do IO<Unit>:
        next : Poll<&1, &1, Maybe<&1, S.Command>, Unit> <- Chan.try_recv(S.Command, channel, 0)
        discard(channel, n, next)
    case _ _: IO.pure(Unit, Unit{})

def finished(~User: Data, ~on_close: User -> U32 -> String -> IO(Unit), s: Socket, state: State<User>, handle: Handle, room: U32, code: U32, reason: String) -> IO(Unit):
  State{user, phase, assembly, pending, body, received, ping, closing, wait} = state
  Handle{+channel, max, alive} = handle
  do IO<Unit>:
    Chan.close(S.Command, channel)
    Chan.close(Unit, alive)
    Socket.close(s)
    first : Poll<&1, &1, Maybe<&1, S.Command>, Unit> <- Chan.try_recv(S.Command, channel, 0)
    discard(channel, 1n+U32.to_nat(U32.max(room, 1)), first)
    on_close(user, code, reason)

# Each cycle consumes at most one queued command then one decoded frame/read.
# Buffered inbound frames cannot starve mailbox sends, and mailbox floods cannot
# starve peer close, ping, or deadlines. There are no socket-owning child tasks.
# Every transition goes through S.step; EOF, transport and write failures, and
# an expired close wait are its `Dropped` event.
@unsafe
def drive(~User: Data, ~on_message: User -> Handle -> M.Message -> IO(User), ~on_close: User -> U32 -> String -> IO(Unit), +handle: Handle, +cfg: Config, event: DriveEvent<User>) -> IO(Unit):
  Config{+max, +room, +poll, +poll_max, +idle_ms, +ping_ms, +close_ms, +write_ms} = cfg
  match event:
    case Cycle{s, state}:
      do IO<Unit>:
        now : Nat <- IO.now()
        drive(~User, ~on_message, ~on_close, handle, cfg, Clock{s, state, now})
    case PollMailbox{s, state}:
      do IO<Unit>:
        got : Poll<&1, &1, Maybe<&1, S.Command>, Unit> <- Chan.try_recv(S.Command, outbound(handle), 0)
        drive(~User, ~on_message, ~on_close, handle, cfg, Mail{s, state, got})
    # A command makes the next read nonblocking: a queued burst drains at write
    # speed while each cycle still checks deadlines and one inbound frame/read.
    case Mail{s, +state, Ready{Some{command}}}:
      drive(~User, ~on_message, ~on_close, handle, cfg, Stepped{s, with_wait(User, state, 0), S.step(max, session(User, state), S.Outbound{command}), ReadNext{}})
    case Mail{s, state, _}:
      drive(~User, ~on_message, ~on_close, handle, cfg, Input{s, state})
    case Stepped{s, State{user, phase, old, pending, body, received, ping, closing, wait}, S.Transition{assembly, action}, next}:
      drive(~User, ~on_message, ~on_close, handle, cfg, Apply{s, State{user, phase, assembly, pending, body, received, ping, closing, wait}, action, next})
    case Apply{s, state, S.Action{phase, None{}, notice}, next}:
      do IO<Unit>:
        now : Nat <- IO.now()
        drive(~User, ~on_message, ~on_close, handle, cfg, Notify{s, writing(User, state, phase, now), notice, next})
    case Apply{s, state, S.Action{phase, Some{frame}, notice}, next}:
      drive(~User, ~on_message, ~on_close, handle, cfg, Encoded{s, state, phase, notice, F.encode(S.cap(max), frame, None{}), next})
    case Encoded{s, +state, phase, notice, None{}, next}:
      drive(~User, ~on_message, ~on_close, handle, cfg, Stepped{s, state, S.step(max, session(User, state), S.Dropped{}), CycleNext{}})
    case Encoded{s, +state, phase, notice, Some{bytes}, next}:
      do IO<Unit>:
        now : Nat <- IO.now()
        sent : Socket & Bool <- Stream.send(s, bytes, send_ms(User, cfg, state, now))
        drive(~User, ~on_message, ~on_close, handle, cfg, Wrote{sent, state, phase, notice, next})
    case Wrote{(s, False{}), +state, phase, notice, next}:
      drive(~User, ~on_message, ~on_close, handle, cfg, Stepped{s, state, S.step(max, session(User, state), S.Dropped{}), CycleNext{}})
    case Wrote{(s, True{}), state, phase, notice, next}:
      do IO<Unit>:
        now : Nat <- IO.now()
        drive(~User, ~on_message, ~on_close, handle, cfg, Notify{s, writing(User, state, phase, now), notice, next})
    case Notify{s, state, S.WsFinished{code, reason}, next}:
      finished(~User, ~on_close, s, state, handle, room, code, reason)
    case Notify{s, State{user, phase, assembly, pending, body, received, ping, closing, wait}, S.WsMessage{message}, next}:
      do IO<Unit>:
        updated : User <- on_message(user, handle, message)
        drive(~User, ~on_message, ~on_close, handle, cfg, Cycle{s, State{updated, phase, assembly, pending, body, received, ping, closing, wait}})
    case Notify{s, state, S.WsSilent{}, MailboxNext{}}:
      drive(~User, ~on_message, ~on_close, handle, cfg, PollMailbox{s, state})
    case Notify{s, state, S.WsSilent{}, ReadNext{}}:
      drive(~User, ~on_message, ~on_close, handle, cfg, Input{s, state})
    case Notify{s, state, S.WsSilent{}, CycleNext{}}:
      drive(~User, ~on_message, ~on_close, handle, cfg, Cycle{s, state})
    case Clock{s, State{+user, +phase, +assembly, +pending, +body, +received, +ping, +closing, +wait}, +now}:
      drive(~User, ~on_message, ~on_close, handle, cfg, Timed{s, State{user, phase, assembly, pending, body, received, ping, closing, wait}, now, expired(now, closing, wait_ms(close_ms)), expired(now, received, idle_ms), expired(now, ping, ping_ms)})
    case Timed{s, State{user, S.WsClosing{}, +assembly, pending, body, received, ping, closing, wait}, now, True{}, idle, due}:
      drive(~User, ~on_message, ~on_close, handle, cfg, Stepped{s, State{user, S.WsClosing{}, assembly, pending, body, received, ping, closing, wait}, S.step(max, S.Session{S.WsClosing{}, assembly}, S.Dropped{}), CycleNext{}})
    case Timed{s, State{user, S.WsOpen{}, +assembly, pending, body, received, ping, closing, wait}, now, expired, True{}, due}:
      drive(~User, ~on_message, ~on_close, handle, cfg, Stepped{s, State{user, S.WsOpen{}, assembly, pending, body, received, ping, closing, wait}, S.step(max, S.Session{S.WsOpen{}, assembly}, S.Outbound{S.SendClose{1001, "idle timeout"}}), ReadNext{}})
    case Timed{s, State{user, S.WsOpen{}, +assembly, pending, body, received, ping, closing, wait}, now, expired, False{}, True{}}:
      drive(~User, ~on_message, ~on_close, handle, cfg, Stepped{s, State{user, S.WsOpen{}, assembly, pending, body, received, now, closing, wait}, S.step(max, S.Session{S.WsOpen{}, assembly}, S.Outbound{S.SendPing{[]}}), MailboxNext{}})
    case Timed{s, state, now, expired, idle, due}:
      drive(~User, ~on_message, ~on_close, handle, cfg, PollMailbox{s, state})
    case Input{s, State{user, phase, assembly, Nil{}, body, received, ping, closing, wait}}:
      drive(~User, ~on_message, ~on_close, handle, cfg, Read{s, State{user, phase, assembly, [], body, received, ping, closing, wait}})
    case Input{s, State{+user, +phase, +assembly, +pending, +body, +received, +ping, +closing, +wait}}:
      drive(~User, ~on_message, ~on_close, handle, cfg, Decoded{s, State{user, phase, assembly, pending, body, received, ping, closing, wait}, decode(max, pending, body)})
    case Decoded{s, State{user, phase, assembly, pending, body, received, ping, closing, wait}, F.NeedMore{n}}:
      drive(~User, ~on_message, ~on_close, handle, cfg, Read{s, State{user, phase, assembly, pending, None{}, received, ping, closing, wait}})
    case Decoded{s, State{user, phase, assembly, pending, body, received, ping, closing, wait}, F.Partial{b}}:
      drive(~User, ~on_message, ~on_close, handle, cfg, Read{s, State{user, phase, assembly, [], Some{b}, received, ping, closing, wait}})
    case Decoded{s, +state, F.Reject{code}}:
      drive(~User, ~on_message, ~on_close, handle, cfg, Stepped{s, state, S.step(max, session(User, state), S.Rejected{code}), CycleNext{}})
    case Decoded{s, State{user, +phase, assembly, pending, body, received, ping, closing, wait}, F.Got{frame, key, rest}}:
      drive(~User, ~on_message, ~on_close, handle, cfg, Stepped{s, State{user, phase, M.Idle{}, rest, None{}, received, ping, closing, wait}, S.step(max, S.Session{phase, assembly}, S.Inbound{frame}), CycleNext{}})
    case Read{s, +state}:
      do IO<Unit>:
        now : Nat <- IO.now()
        result : Socket & Poll<&1, &1, Result<&1, &1, U32 & String, Maybe<&1, List<&2, U32>>>, Unit> <- TCP.try_recv_bytes(s, 16384, read_ms(User, cfg, state, now))
        drive(~User, ~on_message, ~on_close, handle, cfg, Received{result, state})
    case Received{(s, Wait{u}), State{user, phase, assembly, pending, body, received, ping, closing, wait}}:
      drive(~User, ~on_message, ~on_close, handle, cfg, Cycle{s, State{user, phase, assembly, pending, body, received, ping, closing, grow(wait_ms(poll), wait_cap(poll, poll_max), wait)}})
    case Received{(s, Ready{Done{Some{bytes}}}), State{user, phase, assembly, pending, body, received, ping, closing, wait}}:
      do IO<Unit>:
        now : Nat <- IO.now()
        drive(~User, ~on_message, ~on_close, handle, cfg, Cycle{s, State{user, phase, assembly, List.append(&2, U32, pending, bytes), body, now, ping, closing, U32.min(wait, wait_ms(poll))}})
    case Received{(s, _), +state}:
      drive(~User, ~on_message, ~on_close, handle, cfg, Stepped{s, state, S.step(max, session(User, state), S.Dropped{}), CycleNext{}})

type Registration<-User: Data> is Data:
  Registration{user: User, handle: Handle, config: Config}

def cleanup(~User: Data, registration: Registration<User>) -> IO(Unit):
  Registration{user, Handle{channel, max, alive}, cfg} = registration
  do IO<Unit>:
    Chan.close(S.Command, channel)
    Chan.close(Unit, alive)

@unsafe
def start(~User: Data, ~on_open: User -> Handle -> IO(User), ~on_message: User -> Handle -> M.Message -> IO(User), ~on_close: User -> U32 -> String -> IO(Unit), registration: Registration<User>, s: Socket, rest: List<&2, U32>) -> IO(Unit):
  Registration{user, +handle, +cfg} = registration
  Config{max, room, poll, poll_max, idle, ping, closing, write} = cfg
  do IO<Unit>:
    +now : Nat <- IO.now()
    updated : User <- on_open(user, handle)
    drive(~User, ~on_message, ~on_close, handle, cfg, Cycle{s, State{updated, S.WsOpen{}, M.Idle{}, rest, None{}, now, now, now, wait_ms(poll)}})

@unsafe
def upgrade(~Vars: Data, ~User: Data, ~on_open: User -> Handle -> IO(User), ~on_message: User -> Handle -> M.Message -> IO(User), ~on_close: User -> U32 -> String -> IO(Unit), c: Context.Ctx<Vars>, user: User, handshake: Handshake.Config, +cfg: Config) -> IO(Response.Res):
  Config{+max, room, poll, poll_max, idle, ping, closing, write} = cfg
  do IO<Response.Res>:
    channel : Chan(S.Command) <- Chan.new(S.Command, U32.max(room, 1))
    alive : Chan(Unit) <- Chan.new(Unit, 0)
    Upgrade.respond(~Vars, ~(Registration<User>), ~(start(~User, ~on_open, ~on_message, ~on_close)), ~(cleanup(~User)), c, Registration{user, Handle{channel, max, alive}, cfg}, handshake)
