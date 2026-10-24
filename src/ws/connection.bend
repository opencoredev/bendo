# One computation owns the socket. A bounded mailbox admits external sends;
# timed reads provide the wakeup boundary because Base has no socket/Chan select.
import Base
import ./frame.bend as F
import ./message.bend as M
import ./session.bend as S
import ../data/utf8.bend as Utf8
import ../stream.bend as Stream
import ../websocket.bend as Upgrade
import ../http/websocket.bend as Handshake
import ../app/context.bend as Context
import ../http/response.bend as Response

type Config is Data:
  Config{max_message: U32, mailbox_capacity: U32, poll_ms: U32, idle_ms: U32, ping_ms: U32, close_ms: U32, write_ms: U32}

def defaults() -> Config: Config{1048576, 16, 10, 60000, 0, 1000, 30000}

type Handle is Data:
  Handle{outbound: Chan(S.Command), max_message: U32}

def outbound(handle: Handle) -> Chan(S.Command):
  Handle{channel, max} = handle
  channel

def cap(+n: U32) -> U32: U32.max(n, 125)

def valid_close(command: S.Command) -> Bool:
  match command:
    case S.SendClose{code, reason}: M.code_ok(code)
    case _: True{}

def data_fits(max: U32, command: S.Command) -> Bool:
  match command:
    case S.SendText{text}: Nat.is_le(F.length(Utf8.encode(text)), U32.to_nat(max))
    case S.SendBinary{bytes}: Nat.is_le(F.length(bytes), U32.to_nat(max))
    case _: True{}

def valid(+max: U32, +command: S.Command) -> Bool:
  F.valid(cap(max), S.command_frame(command), None{}) && valid_close(command) && data_fits(max, command)

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
  Handle{channel, max} = handle
  enqueue_checked(valid(max, command), channel, command)

def text(handle: Handle, value: String) -> IO(Bool): enqueue(handle, S.SendText{value})
def binary(handle: Handle, bytes: List<&2, U32>) -> IO(Bool): enqueue(handle, S.SendBinary{bytes})
def ping(handle: Handle, bytes: List<&2, U32>) -> IO(Bool): enqueue(handle, S.SendPing{bytes})
def close(handle: Handle, code: U32, reason: String) -> IO(Bool): enqueue(handle, S.SendClose{code, reason})

type State<-User: Data> is Data:
  State{user: User, phase: S.Phase, assembly: M.State, pending: List<&2, U32>, body: Maybe<&2, F.Body>, received_at: Nat, ping_at: Nat, closing_at: Nat}

def phase(-User: Data, state: State<User>) -> S.Phase:
  State{user, p, assembly, pending, body, received, ping, closing} = state
  p

type Continue is Data:
  ReadNext{}
  CycleNext{}
  MailboxNext{}

type DriveEvent<-User: Data> is Type:
  Cycle{socket: Socket, state: State<User>}
  PollMailbox{socket: Socket, state: State<User>}
  Mail{socket: Socket, state: State<User>, got: Poll<&1, &1, Maybe<&1, S.Command>, Unit>}
  Apply{socket: Socket, state: State<User>, action: S.Action, next: Continue}
  Encoded{socket: Socket, state: State<User>, phase: S.Phase, notice: S.Notice, bytes: Maybe<&2, List<&2, U32>>, next: Continue}
  Wrote{sent: Socket & Bool, state: State<User>, phase: S.Phase, notice: S.Notice, next: Continue}
  Notify{socket: Socket, state: State<User>, notice: S.Notice, next: Continue}
  Input{socket: Socket, state: State<User>}
  Decoded{socket: Socket, state: State<User>, decoded: F.Decoded}
  Assembled{socket: Socket, state: State<User>, transition: S.Transition}
  Read{socket: Socket, state: State<User>}
  Received{result: Socket & Poll<&1, &1, Result<&1, &1, U32 & String, Maybe<&1, List<&2, U32>>>, Unit>, state: State<User>}
  Clock{socket: Socket, state: State<User>, now: Nat}
  Timed{socket: Socket, state: State<User>, now: Nat, expired: Bool, idle: Bool, ping: Bool}

def expired(+now: Nat, since: Nat, +ms: U32) -> Bool:
  Bool.not(U32.is_eq(ms, 0)) && Nat.is_le(U32.to_nat(ms), Nat.sub(now, since))

def wait_ms(ms: U32) -> U32: U32.max(ms, 1)

def remaining(+now: Nat, since: Nat, ms: U32, budget: U32) -> U32:
  match ms:
    case 0: budget
    case n: U32.min(budget, U32.max(1, U32.from_nat(Nat.sub(U32.to_nat(n), Nat.sub(now, since)))))

def read_ms(-User: Data, cfg: Config, state: State<User>, +now: Nat) -> U32:
  Config{max, room, poll, idle, ping, closing_ms, write} = cfg
  State{user, phase, assembly, pending, body, received, ping_at, closing} = state
  match phase:
    case S.WsOpen{}: remaining(now, ping_at, ping, remaining(now, received, idle, wait_ms(poll)))
    case S.WsClosing{}: remaining(now, closing, wait_ms(closing_ms), wait_ms(poll))
    case S.WsDone{}: 1

def send_ms(-User: Data, cfg: Config, state: State<User>, now: Nat) -> U32:
  Config{max, room, poll, idle, ping, closing_ms, write} = cfg
  State{user, phase, assembly, pending, body, received, ping_at, closing} = state
  match phase:
    case S.WsClosing{}: remaining(now, closing, wait_ms(closing_ms), wait_ms(write))
    case _: wait_ms(write)

def decode(max: U32, bytes: List<&2, U32>, body: Maybe<&2, F.Body>) -> F.Decoded:
  match body:
    case None{}: F.start(F.Config{F.Server{}, cap(max)}, bytes)
    case Some{b}: F.resume(b, bytes)

def writing(-User: Data, state: State<User>, phase: S.Phase, now: Nat) -> State<User>:
  State{user, old, assembly, pending, body, received, ping, closing} = state
  match old phase:
    case S.WsOpen{} S.WsClosing{}: State{user, S.WsClosing{}, assembly, pending, body, received, ping, now}
    case _ _: State{user, phase, assembly, pending, body, received, ping, closing}

def finished(~User: Data, ~on_close: User -> U32 -> String -> IO(Unit), s: Socket, state: State<User>, handle: Handle, code: U32, reason: String) -> IO(Unit):
  State{user, phase, assembly, pending, body, received, ping, closing} = state
  Handle{channel, max} = handle
  do IO<Unit>:
    Chan.close(S.Command, channel)
    Socket.close(s)
    on_close(user, code, reason)

# Each cycle consumes at most one queued command then one decoded frame/read.
# Buffered inbound frames cannot starve mailbox sends, and mailbox floods cannot
# starve peer close, ping, or deadlines. There are no socket-owning child tasks.
@unsafe
def drive(~User: Data, ~on_message: User -> Handle -> M.Message -> IO(User), ~on_close: User -> U32 -> String -> IO(Unit), +handle: Handle, +cfg: Config, event: DriveEvent<User>) -> IO(Unit):
  Config{+max, room, +poll, +idle_ms, +ping_ms, +close_ms, +write_ms} = cfg
  match event:
    case Cycle{s, state}:
      do IO<Unit>:
        now : Nat <- IO.now()
        drive(~User, ~on_message, ~on_close, handle, cfg, Clock{s, state, now})
    case PollMailbox{s, state}:
      do IO<Unit>:
        got : Poll<&1, &1, Maybe<&1, S.Command>, Unit> <- Chan.try_recv(S.Command, outbound(handle), 0)
        drive(~User, ~on_message, ~on_close, handle, cfg, Mail{s, state, got})
    case Mail{s, +state, Ready{Some{command}}}:
      drive(~User, ~on_message, ~on_close, handle, cfg, Apply{s, state, S.outgoing(phase(User, state), command), ReadNext{}})
    case Mail{s, state, _}:
      drive(~User, ~on_message, ~on_close, handle, cfg, Input{s, state})
    case Apply{s, state, S.Action{phase, None{}, notice}, next}:
      do IO<Unit>:
        now : Nat <- IO.now()
        drive(~User, ~on_message, ~on_close, handle, cfg, Notify{s, writing(User, state, phase, now), notice, next})
    case Apply{s, state, S.Action{phase, Some{frame}, notice}, next}:
      drive(~User, ~on_message, ~on_close, handle, cfg, Encoded{s, state, phase, notice, F.encode(cap(max), frame, None{}), next})
    case Encoded{s, state, phase, notice, None{}, next}:
      finished(~User, ~on_close, s, state, handle, 1006, "")
    case Encoded{s, +state, phase, notice, Some{bytes}, next}:
      do IO<Unit>:
        now : Nat <- IO.now()
        sent : Socket & Bool <- Stream.send(s, bytes, send_ms(User, cfg, state, now))
        drive(~User, ~on_message, ~on_close, handle, cfg, Wrote{sent, state, phase, notice, next})
    case Wrote{(s, False{}), state, phase, notice, next}:
      finished(~User, ~on_close, s, state, handle, 1006, "")
    case Wrote{(s, True{}), state, phase, notice, next}:
      do IO<Unit>:
        now : Nat <- IO.now()
        drive(~User, ~on_message, ~on_close, handle, cfg, Notify{s, writing(User, state, phase, now), notice, next})
    case Notify{s, state, S.WsFinished{code, reason}, next}:
      finished(~User, ~on_close, s, state, handle, code, reason)
    case Notify{s, State{user, phase, assembly, pending, body, received, ping, closing}, S.WsMessage{message}, next}:
      do IO<Unit>:
        updated : User <- on_message(user, handle, message)
        drive(~User, ~on_message, ~on_close, handle, cfg, Cycle{s, State{updated, phase, assembly, pending, body, received, ping, closing}})
    case Notify{s, state, S.WsSilent{}, MailboxNext{}}:
      drive(~User, ~on_message, ~on_close, handle, cfg, PollMailbox{s, state})
    case Notify{s, state, S.WsSilent{}, ReadNext{}}:
      drive(~User, ~on_message, ~on_close, handle, cfg, Input{s, state})
    case Notify{s, state, S.WsSilent{}, CycleNext{}}:
      drive(~User, ~on_message, ~on_close, handle, cfg, Cycle{s, state})
    case Clock{s, State{+user, +phase, +assembly, +pending, +body, +received, +ping, +closing}, +now}:
      drive(~User, ~on_message, ~on_close, handle, cfg, Timed{s, State{user, phase, assembly, pending, body, received, ping, closing}, now, expired(now, closing, wait_ms(close_ms)), expired(now, received, idle_ms), expired(now, ping, ping_ms)})
    case Timed{s, State{user, S.WsClosing{}, assembly, pending, body, received, ping, closing}, now, True{}, idle, due}:
      finished(~User, ~on_close, s, State{user, S.WsClosing{}, assembly, pending, body, received, ping, closing}, handle, 1006, "")
    case Timed{s, State{user, S.WsOpen{}, assembly, pending, body, received, ping, closing}, now, expired, True{}, due}:
      drive(~User, ~on_message, ~on_close, handle, cfg, Apply{s, State{user, S.WsOpen{}, assembly, pending, body, received, ping, closing}, S.outgoing(S.WsOpen{}, S.SendClose{1001, "idle timeout"}), ReadNext{}})
    case Timed{s, State{user, S.WsOpen{}, assembly, pending, body, received, ping, closing}, now, expired, False{}, True{}}:
      drive(~User, ~on_message, ~on_close, handle, cfg, Apply{s, State{user, S.WsOpen{}, assembly, pending, body, received, now, closing}, S.outgoing(S.WsOpen{}, S.SendPing{[]}), MailboxNext{}})
    case Timed{s, state, now, expired, idle, due}:
      drive(~User, ~on_message, ~on_close, handle, cfg, PollMailbox{s, state})
    case Input{s, State{user, phase, assembly, Nil{}, body, received, ping, closing}}:
      drive(~User, ~on_message, ~on_close, handle, cfg, Read{s, State{user, phase, assembly, [], body, received, ping, closing}})
    case Input{s, State{+user, +phase, +assembly, +pending, +body, +received, +ping, +closing}}:
      drive(~User, ~on_message, ~on_close, handle, cfg, Decoded{s, State{user, phase, assembly, pending, body, received, ping, closing}, decode(max, pending, body)})
    case Decoded{s, State{user, phase, assembly, pending, body, received, ping, closing}, F.NeedMore{n}}:
      drive(~User, ~on_message, ~on_close, handle, cfg, Read{s, State{user, phase, assembly, pending, None{}, received, ping, closing}})
    case Decoded{s, State{user, phase, assembly, pending, body, received, ping, closing}, F.Partial{b}}:
      drive(~User, ~on_message, ~on_close, handle, cfg, Read{s, State{user, phase, assembly, [], Some{b}, received, ping, closing}})
    case Decoded{s, +state, F.Reject{code}}:
      drive(~User, ~on_message, ~on_close, handle, cfg, Apply{s, state, S.failure(phase(User, state), code), CycleNext{}})
    case Decoded{s, State{user, +phase, assembly, pending, body, received, ping, closing}, F.Got{frame, key, rest}}:
      drive(~User, ~on_message, ~on_close, handle, cfg, Assembled{s, State{user, phase, M.Idle{}, rest, None{}, received, ping, closing}, S.receive(max, phase, assembly, frame)})
    case Assembled{s, State{user, phase, old, pending, body, received, ping, closing}, S.Transition{assembly, action}}:
      drive(~User, ~on_message, ~on_close, handle, cfg, Apply{s, State{user, phase, assembly, pending, body, received, ping, closing}, action, CycleNext{}})
    case Read{s, +state}:
      do IO<Unit>:
        now : Nat <- IO.now()
        result : Socket & Poll<&1, &1, Result<&1, &1, U32 & String, Maybe<&1, List<&2, U32>>>, Unit> <- TCP.try_recv_bytes(s, 16384, read_ms(User, cfg, state, now))
        drive(~User, ~on_message, ~on_close, handle, cfg, Received{result, state})
    case Received{(s, Wait{u}), state}:
      drive(~User, ~on_message, ~on_close, handle, cfg, Cycle{s, state})
    case Received{(s, Ready{Done{Some{bytes}}}), State{user, phase, assembly, pending, body, received, ping, closing}}:
      do IO<Unit>:
        now : Nat <- IO.now()
        drive(~User, ~on_message, ~on_close, handle, cfg, Cycle{s, State{user, phase, assembly, List.append(&2, U32, pending, bytes), body, now, ping, closing}})
    case Received{(s, _), state}:
      finished(~User, ~on_close, s, state, handle, 1006, "")

type Registration<-User: Data> is Data:
  Registration{user: User, handle: Handle, config: Config}

def cleanup(~User: Data, registration: Registration<User>) -> IO(Unit):
  Registration{user, Handle{channel, max}, cfg} = registration
  Chan.close(S.Command, channel)

@unsafe
def start(~User: Data, ~on_open: User -> Handle -> IO(User), ~on_message: User -> Handle -> M.Message -> IO(User), ~on_close: User -> U32 -> String -> IO(Unit), registration: Registration<User>, s: Socket, rest: List<&2, U32>) -> IO(Unit):
  Registration{user, +handle, cfg} = registration
  do IO<Unit>:
    +now : Nat <- IO.now()
    updated : User <- on_open(user, handle)
    drive(~User, ~on_message, ~on_close, handle, cfg, Cycle{s, State{updated, S.WsOpen{}, M.Idle{}, rest, None{}, now, now, now}})

@unsafe
def upgrade(~Vars: Data, ~User: Data, ~on_open: User -> Handle -> IO(User), ~on_message: User -> Handle -> M.Message -> IO(User), ~on_close: User -> U32 -> String -> IO(Unit), c: Context.Ctx<Vars>, user: User, handshake: Handshake.Config, +cfg: Config) -> IO(Response.Res):
  Config{+max, room, poll, idle, ping, closing, write} = cfg
  do IO<Response.Res>:
    channel : Chan(S.Command) <- Chan.new(S.Command, U32.max(room, 1))
    Upgrade.respond(~Vars, ~(Registration<User>), ~(start(~User, ~on_open, ~on_message, ~on_close)), ~(cleanup(~User)), c, Registration{user, Handle{channel, max}, cfg}, handshake)
