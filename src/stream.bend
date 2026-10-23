# Thin IO shell. Producer state is affine; no producer task runs ahead of TCP.
import Base
import ./http/stream_types.bend as T
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
  Pull{socket: Socket, state: State}
  Pulled{socket: Socket, step: T.Step<State>}
  Checked{socket: Socket, bytes: List<&2, U32>, state: State, valid: Bool}
  Wrote{result: Socket & Bool, state: State}
  Finished{result: Socket & Bool}

@unsafe
def drive(~State: Type, ~step: State -> IO(T.Step<State>), ~cleanup: State -> IO(Unit), event: DriveEvent<State>, +timeout: U32, +limit: U32) -> IO(T.Outcome):
  match event:
    case Pull{s, state}:
      do IO<T.Outcome>:
        next : T.Step<State> <- step(state)
        drive(~State, ~step, ~cleanup, Pulled{s, next}, timeout, limit)
    case Pulled{s, T.Chunk{Nil{}, state}}:
      drive(~State, ~step, ~cleanup, Pull{s, state}, timeout, limit)
    case Pulled{s, T.Chunk{+bytes, state}}:
      drive(~State, ~step, ~cleanup, Checked{s, bytes, state, bounded(bytes, U32.to_nat(limit))}, timeout, limit)
    case Checked{s, bytes, state, False{}}:
      do IO<T.Outcome>:
        cleanup(state)
        return T.Written{s, False{}}
    case Checked{s, bytes, state, True{}}:
      do IO<T.Outcome>:
        result : Socket & Bool <- send(s, Frame.chunk(bytes), timeout)
        drive(~State, ~step, ~cleanup, Wrote{result, state}, timeout, limit)
    case Wrote{(s, True{}), state}:
      drive(~State, ~step, ~cleanup, Pull{s, state}, timeout, limit)
    case Wrote{(s, False{}), state}:
      do IO<T.Outcome>:
        cleanup(state)
        return T.Written{s, False{}}
    case Pulled{s, T.End{state}}:
      do IO<T.Outcome>:
        cleanup(state)
        result : Socket & Bool <- send(s, Frame.end(), timeout)
        drive(~State, ~step, ~cleanup, Finished{result}, timeout, limit)
    case Pulled{s, T.Failed{state}}:
      do IO<T.Outcome>:
        cleanup(state)
        return T.Written{s, False{}}
    case Finished{(s, complete)}: IO.pure(T.Outcome, T.Written{s, complete})

def command(~State: Type, ~step: State -> IO(T.Step<State>), ~cleanup: State -> IO(Unit), state: State, config: T.Config, command: T.Command) -> IO(T.Outcome):
  match config command:
    case T.Config{timeout, limit} T.Cancel{}:
      do IO<T.Outcome>:
        cleanup(state)
        return T.Cancelled{}
    case T.Config{timeout, limit} T.Start{s}:
      drive(~State, ~step, ~cleanup, Pull{s, state}, timeout, limit)

def plan(~State: Type, ~step: State -> IO(T.Step<State>), ~cleanup: State -> IO(Unit), state: State, +config: T.Config) -> T.Plan:
  T.Config{timeout, limit} = config
  T.Plan{timeout, cmd => command(~State, ~step, ~cleanup, state, config, cmd)}

def cancel(plan: T.Plan) -> IO(Unit):
  T.Plan{timeout, action} = plan
  do IO<Unit>:
    outcome : T.Outcome <- action(T.Cancel{})
    return Unit{}

# The marker is request-private protocol metadata, never a wire header. Random
# identity prevents a second registration or stale response from selecting a plan.
def marker() -> String: "x-bendo-stream-internal"

def keep(h: Request.Header) -> Bool:
  Request.Header{name, value} = h
  Bool.not(String.eq(Bytes.fold(name), marker()))

def strip(res: Response.Res) -> Response.Res:
  Response.Res{status, hs, body, rep} = res
  Response.Res{status, List.filter(~Request.Header, ~keep, hs), body, rep}

def marked(hs: List<&2, Request.Header>, +id: String) -> Bool:
  match hs:
    case Nil{}: False{}
    case Request.Header{name, value} <> rest:
      (String.eq(Bytes.fold(name), marker()) && String.eq(Bytes.ascii(value), id)) || marked(rest, id)

def mark(res: Response.Res, id: String) -> Response.Res:
  Response.Res{code, hs, body, rep} = res
  Response.Res{code, Request.Header{marker(), Bytes.encode(id)} <> hs, [], None{}}

def registered(res: Response.Res, id: String, result: Poll<&1, &1, Result<&1, &1, T.Registration, Unit>, T.Registration>) -> IO(Response.Res):
  match result:
    case Ready{Done{u}}:
      IO.pure(Response.Res, mark(res, id))
    case Ready{Fail{T.Registration{old, plan}}}:
      do IO<Response.Res>:
        cancel(plan)
        return Response.body(500, [], [])
    case Wait{T.Registration{old, plan}}:
      do IO<Response.Res>:
        cancel(plan)
        return Response.body(500, [], [])

def identified(slot: Chan(T.Registration), res: Response.Res, plan: T.Plan, entropy: Result<&1, &1, Random.RandomError(), List<&2, U32>>) -> IO(Response.Res):
  match entropy:
    case Fail{error}:
      do IO<Response.Res>:
        cancel(plan)
        return Response.body(500, [], [])
    case Done{bytes}:
      +id = Hex.encode(bytes)
      do IO<Response.Res>:
        result : Poll<&1, &1, Result<&1, &1, T.Registration, Unit>, T.Registration> <- Chan.try_send(T.Registration, slot, T.Registration{id, plan}, 0)
        registered(res, id, result)

def register(slot: Maybe<&2, Chan(T.Registration)>, res: Response.Res, plan: T.Plan) -> IO(Response.Res):
  match slot:
    case None{}:
      do IO<Response.Res>:
        cancel(plan)
        return Response.body(500, [], [])
    case Some{channel}:
      do IO<Response.Res>:
        entropy : Result<&1, &1, Random.RandomError(), List<&2, U32>> <- Random.random_bytes(16n)
        identified(channel, strip(res), plan, entropy)

def take(slot: Chan(T.Registration)) -> IO(Maybe<&1, T.Registration>):
  +channel = slot
  do IO<Maybe<&1, T.Registration>>:
    # Closed channels retain queued values; close first to exclude late sends.
    Chan.close(T.Registration, channel)
    Chan.recv(T.Registration, channel)
