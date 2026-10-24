# Thin IO shell. Producer state is affine; no producer task runs ahead of TCP.
import Base
import ./http/stream_marker.bend as Marker
import ./http/stream_types.bend as T
import ./http/websocket.bend as WebSocket
import ./http/stream_framing.bend as Frame
import ./http/response.bend as Response
import ./http/bytes.bend as Bytes
import ./http/request.bend as Request
import ./crypto/random.bend as Random
import ./data/hex.bend as Hex

def defaults() -> T.Config:
  T.Config{30000, 65536}

type SendEvent is Type:
  Sending{socket: Socket, bytes: List<&2, U32>}
  Timed{socket: Socket, bytes: List<&2, U32>, remaining: Nat}
  Polled{result: Socket & Poll<&1, &1, Result<&1, &1, (U32 & String) & List<&2, U32>, Unit>, List<&2, U32>>}

# A single absolute deadline includes retries of the unsent suffix. Never resend
# already accepted bytes, and never race a socket through IO.within.
@unsafe
def send_loop(event: SendEvent, +deadline: Nat) -> IO(Socket & Bool):
  match event:
    case Sending{s, bytes}:
      do IO<Socket & Bool>:
        now : Nat <- IO.now()
        send_loop(Timed{s, bytes, Nat.sub(deadline, now)}, deadline)
    case Timed{s, bytes, 0n}: IO.pure(Socket & Bool, (s, False{}))
    case Timed{s, bytes, 1n+remaining}:
      do IO<Socket & Bool>:
        result : Socket & Poll<&1, &1, Result<&1, &1, (U32 & String) & List<&2, U32>, Unit>, List<&2, U32>> <- TCP.try_send_bytes(s, bytes, U32.from_nat(1n+remaining))
        send_loop(Polled{result}, deadline)
    case Polled{(s, Ready{Done{u}})}: IO.pure(Socket & Bool, (s, True{}))
    case Polled{(s, Ready{Fail{error}})}: IO.pure(Socket & Bool, (s, False{}))
    case Polled{(s, Wait{rest})}: send_loop(Sending{s, rest}, deadline)

def send(s: Socket, bytes: List<&2, U32>, timeout: U32) -> IO(Socket & Bool):
  do IO<Socket & Bool>:
    now : Nat <- IO.now()
    send_loop(Sending{s, bytes}, Nat.add(now, U32.to_nat(timeout)))

# Validate/count without traversing more than the configured chunk budget.
def bounded(xs: List<&2, U32>, left: Nat) -> Bool:
  match xs left:
    case Nil{} _: True{}
    case _ 0n: False{}
    case +c <> tail 1n+n: (c <= 255 : U32) && bounded(tail, n)

type DriveEvent<-State: Type> is Type:
  Pull{socket: Socket, state: State, budget: Frame.Budget}
  Pulled{socket: Socket, step: T.Step<State>, budget: Frame.Budget}
  Checked{socket: Socket, bytes: List<&2, U32>, state: State, budget: Frame.Budget, valid: Bool}
  Wrote{result: Socket & Bool, state: State, budget: Frame.Budget}
  Ended{socket: Socket, last: Maybe<&2, List<&2, U32>>}
  Finished{result: Socket & Bool}

# The budget is Open for chunked streams. A sized stream checks each chunk
# against the octets still owed before sending it, and aborts at End unless
# it sent exactly its declared length.
@unsafe
def drive(~State: Type, ~step: State -> IO(T.Step<State>), ~cleanup: State -> IO(Unit), event: DriveEvent<State>, +timeout: U32, +limit: U32) -> IO(T.Outcome):
  match event:
    case Pull{s, state, budget}:
      do IO<T.Outcome>:
        next : T.Step<State> <- step(state)
        drive(~State, ~step, ~cleanup, Pulled{s, next, budget}, timeout, limit)
    case Pulled{s, T.Chunk{Nil{}, state}, budget}:
      drive(~State, ~step, ~cleanup, Pull{s, state, budget}, timeout, limit)
    case Pulled{s, T.Chunk{+bytes, state}, +budget}:
      +next = Frame.charge(bytes, budget)
      drive(~State, ~step, ~cleanup, Checked{s, bytes, state, next, bounded(bytes, U32.to_nat(limit)) && Frame.within(next)}, timeout, limit)
    case Checked{s, bytes, state, budget, False{}}:
      do IO<T.Outcome>:
        cleanup(state)
        return T.Written{s, False{}}
    # A valid chunk left the budget Open exactly when it started Open, so
    # the remaining budget picks the same framing.
    case Checked{s, bytes, state, +budget, True{}}:
      do IO<T.Outcome>:
        result : Socket & Bool <- send(s, Frame.encoded(bytes, budget), timeout)
        drive(~State, ~step, ~cleanup, Wrote{result, state, budget}, timeout, limit)
    case Wrote{(s, True{}), state, budget}:
      drive(~State, ~step, ~cleanup, Pull{s, state, budget}, timeout, limit)
    case Wrote{(s, False{}), state, budget}:
      do IO<T.Outcome>:
        cleanup(state)
        return T.Written{s, False{}}
    case Pulled{s, T.End{state}, budget}:
      do IO<T.Outcome>:
        cleanup(state)
        drive(~State, ~step, ~cleanup, Ended{s, Frame.last(budget)}, timeout, limit)
    case Ended{s, None{}}: IO.pure(T.Outcome, T.Written{s, False{}})
    case Ended{s, Some{Nil{}}}: IO.pure(T.Outcome, T.Written{s, True{}})
    case Ended{s, Some{bytes}}:
      do IO<T.Outcome>:
        result : Socket & Bool <- send(s, bytes, timeout)
        drive(~State, ~step, ~cleanup, Finished{result}, timeout, limit)
    case Pulled{s, T.Failed{state}, budget}:
      do IO<T.Outcome>:
        cleanup(state)
        return T.Written{s, False{}}
    case Finished{(s, complete)}: IO.pure(T.Outcome, T.Written{s, complete})

def command(~State: Type, ~step: State -> IO(T.Step<State>), ~cleanup: State -> IO(Unit), state: State, config: T.Config, length: Maybe<&2, Nat>, command: T.Command) -> IO(T.Outcome):
  match config command:
    case T.Config{timeout, limit} T.Cancel{}:
      do IO<T.Outcome>:
        cleanup(state)
        return T.Cancelled{}
    case T.Config{timeout, limit} T.Start{s}:
      drive(~State, ~step, ~cleanup, Pull{s, state, Frame.budget(length)}, timeout, limit)

def planned(~State: Type, ~step: State -> IO(T.Step<State>), ~cleanup: State -> IO(Unit), state: State, +config: T.Config, +length: Maybe<&2, Nat>) -> T.Plan:
  T.Config{timeout, limit} = config
  T.Plan{timeout, length, cmd => command(~State, ~step, ~cleanup, state, config, length, cmd)}

def plan(~State: Type, ~step: State -> IO(T.Step<State>), ~cleanup: State -> IO(Unit), state: State, config: T.Config) -> T.Plan:
  planned(~State, ~step, ~cleanup, state, config, None{})

# A producer that knows its body's exact length up front. The response
# carries Content-Length and no chunked framing, also over HTTP/1.0; a
# producer that sends more or fewer octets aborts the connection.
def plan_sized(~State: Type, ~step: State -> IO(T.Step<State>), ~cleanup: State -> IO(Unit), state: State, config: T.Config, length: Nat) -> T.Plan:
  planned(~State, ~step, ~cleanup, state, config, Some{length})

def cancel(plan: T.Plan) -> IO(Unit):
  T.Plan{timeout, length, action} = plan
  do IO<Unit>:
    outcome : T.Outcome <- action(T.Cancel{})
    return Unit{}

# The marker is request-private protocol metadata, never a wire header. Random
# identity prevents a second registration or stale response from selecting a plan.
def marker() -> String: Marker.marker()
def keep(h: Request.Header) -> Bool: Marker.keep(h)
def strip(res: Response.Res) -> Response.Res: Marker.strip(res)
def marked(hs: List<&2, Request.Header>, id: String) -> Bool: Marker.marked(hs, id)
def mark(res: Response.Res, id: String) -> Response.Res: Marker.mark(res, id)

# What a handler asks the transport to do with its response.
type Claim is Type:
  Body{plan: T.Plan}
  Handshake{config: WebSocket.Config, session: T.Session}

def abort(session: T.Session) -> IO(Unit):
  T.Session{timeout, action} = session
  action(T.Abort{})

def release(claim: Claim) -> IO(Unit):
  match claim:
    case Body{plan}: cancel(plan)
    case Handshake{config, session}: abort(session)

def released(registration: T.Registration) -> IO(Unit):
  match registration:
    case T.Registration{id, plan}: cancel(plan)
    case T.Upgrade{id, config, session}: abort(session)

def claimed(id: String, claim: Claim) -> T.Registration:
  match claim:
    case Body{plan}: T.Registration{id, plan}
    case Handshake{config, session}: T.Upgrade{id, config, session}

def refused(registration: T.Registration) -> IO(Response.Res):
  do IO<Response.Res>:
    released(registration)
    return Response.body(500, [], [])

def registered(res: Response.Res, id: String, result: Poll<&1, &1, Result<&1, &1, T.Registration, Unit>, T.Registration>) -> IO(Response.Res):
  match result:
    case Ready{Done{u}}:
      IO.pure(Response.Res, mark(res, id))
    case Ready{Fail{registration}}: refused(registration)
    case Wait{registration}: refused(registration)

def identified(slot: Chan(T.Registration), res: Response.Res, claim: Claim, entropy: Result<&1, &1, Random.RandomError(), List<&2, U32>>) -> IO(Response.Res):
  match entropy:
    case Fail{error}:
      do IO<Response.Res>:
        release(claim)
        return Response.body(500, [], [])
    case Done{bytes}:
      +id = Hex.encode(bytes)
      do IO<Response.Res>:
        result : Poll<&1, &1, Result<&1, &1, T.Registration, Unit>, T.Registration> <- Chan.try_send(T.Registration, slot, claimed(id, claim), 0)
        registered(res, id, result)

# The slot holds one registration per request; a second (or one after the
# handler finished) is released and answered with an empty 500.
def register_claim(slot: Maybe<&2, Chan(T.Registration)>, res: Response.Res, claim: Claim) -> IO(Response.Res):
  match slot:
    case None{}:
      do IO<Response.Res>:
        release(claim)
        return Response.body(500, [], [])
    case Some{channel}:
      do IO<Response.Res>:
        entropy : Result<&1, &1, Random.RandomError(), List<&2, U32>> <- Random.random_bytes(16n)
        identified(channel, strip(res), claim, entropy)

def register(slot: Maybe<&2, Chan(T.Registration)>, res: Response.Res, plan: T.Plan) -> IO(Response.Res):
  register_claim(slot, res, Body{plan})

def take(slot: Chan(T.Registration)) -> IO(Maybe<&1, T.Registration>):
  +channel = slot
  do IO<Maybe<&1, T.Registration>>:
    # Closed channels retain queued values; close first to exclude late sends.
    Chan.close(T.Registration, channel)
    Chan.recv(T.Registration, channel)
