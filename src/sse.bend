# Thin IO shell: an SSE producer becomes a B.stream pull producer.
import Base
import ./http/sse.bend as Sse
import ./http/sse_types.bend as T
import ./http/stream_types.bend as S
import ./http/request.bend as Request
import ./http/bytes.bend as Bytes
import ./http/response.bend as Response
import ./app/context.bend as Context

def defaults() -> T.Config:
  T.Config{S.Config{30000, 65536}, 15000, 250, []}

def sent(-State: Type, frame: Maybe<&2, List<&2, U32>>, state: State, config: T.Config, last: Nat, now: Nat) -> S.Step<T.Pump<State>>:
  match frame:
    case None{}: S.Failed{T.Pump{state, config, last}}
    case Some{bytes}: S.Chunk{bytes, T.Pump{state, config, now}}

def wait(-State: Type, state: State, config: T.Config, last: Nat, ms: U32) -> IO(S.Step<T.Pump<State>>):
  do IO<S.Step<T.Pump<State>>>:
    IO.sleep(ms)
    return S.Chunk{[], T.Pump{state, config, last}}

def heartbeat_ms(config: T.Config) -> U32:
  T.Config{stream, heartbeat, idle, comment} = config
  heartbeat

def idle_ms(config: T.Config) -> U32:
  T.Config{stream, heartbeat, idle, comment} = config
  idle

def comment(config: T.Config) -> List<&2, U32>:
  T.Config{stream, heartbeat, idle, comment} = config
  comment

def beat(-State: Type, state: State, +config: T.Config, last: Nat, now: Nat, +left: Nat, due: Bool) -> IO(S.Step<T.Pump<State>>):
  match due:
    case True{}: IO.pure(S.Step<T.Pump<State>>, sent(State, Sse.encode(Sse.Comment{comment(config)}), state, config, last, now))
    case False{}: wait(State, state, config, last, U32.min(idle_ms(config), U32.from_nat(left)))

def beat_left(-State: Type, state: State, config: T.Config, last: Nat, now: Nat, +left: Nat) -> IO(S.Step<T.Pump<State>>):
  beat(State, state, config, last, now, left, Nat.is_eq(left, 0n))

# `left` is the time until the heartbeat is due, measured from the last write.
def heartbeat(-State: Type, state: State, +config: T.Config, +last: Nat, +now: Nat, off: Bool) -> IO(S.Step<T.Pump<State>>):
  match off:
    case True{}: wait(State, state, config, last, idle_ms(config))
    case False{}: beat_left(State, state, config, last, now, Nat.sub(Nat.add(last, U32.to_nat(heartbeat_ms(config))), now))

def idle(-State: Type, state: State, +config: T.Config, last: Nat, now: Nat) -> IO(S.Step<T.Pump<State>>):
  heartbeat(State, state, config, last, now, U32.is_eq(heartbeat_ms(config), 0))

def pulled(-State: Type, step: T.Step<State>, +config: T.Config, +last: Nat, +now: Nat) -> IO(S.Step<T.Pump<State>>):
  match step:
    case T.Send{frame, state}: IO.pure(S.Step<T.Pump<State>>, sent(State, Sse.encode(frame), state, config, last, now))
    case T.Idle{state}: idle(State, state, config, last, now)
    case T.End{state}: IO.pure(S.Step<T.Pump<State>>, S.End{T.Pump{state, config, last}})
    case T.Failed{state}: IO.pure(S.Step<T.Pump<State>>, S.Failed{T.Pump{state, config, last}})

def pull(~State: Type, ~step: State -> IO(T.Step<State>), pump: T.Pump<State>) -> IO(S.Step<T.Pump<State>>):
  T.Pump{state, config, last} = pump
  do IO<S.Step<T.Pump<State>>>:
    next : T.Step<State> <- step(state)
    now : Nat <- IO.now()
    pulled(State, next, config, last, now)

def release(~State: Type, ~cleanup: State -> IO(Unit), pump: T.Pump<State>) -> IO(Unit):
  T.Pump{state, config, last} = pump
  cleanup(state)

def stream_config(config: T.Config) -> S.Config:
  T.Config{stream, heartbeat, idle, comment} = config
  stream

def drop_encoding(h: Request.Header) -> Bool:
  Request.Header{name, value} = h
  Bool.not(String.eq(Bytes.fold(name), "content-encoding"))

# Event streams are never compressed or cached, and proxies must not buffer them.
def headers(-Vars: Data, c: Context.Ctx<Vars>) -> Context.Ctx<Vars>:
  Context.Ctx{r, p, b, q, s, hs, v, o} = c
  plain = {Context.Ctx{r, p, b, q, s, List.filter(~Request.Header, ~drop_encoding, hs), v, o} : Context.Ctx<Vars>}
  Context.header(Vars, Context.header(Vars, Context.header(Vars, plain, "content-type", "text/event-stream"), "cache-control", "no-cache"), "x-accel-buffering", "no")

# The value the browser sends when it reconnects: the last event id it saw.
def last_event_id(-Vars: Data, c: Context.Ctx<Vars>) -> Maybe<&2, String>:
  Context.request_header(Vars, c, "last-event-id")

def text(value: Maybe<&2, String>) -> Maybe<&2, List<&2, U32>>:
  match value:
    case None{}: None{}
    case Some{s}: Some{Response.utf8(s)}

# UTF-8 frames from Strings. Validity is checked when the frame is sent.
def message(event: Maybe<&2, String>, data: String, id: Maybe<&2, String>, retry: Maybe<&2, U32>) -> Sse.Frame:
  Sse.Message{text(event), Response.utf8(data), text(id), retry}

def comment_frame(value: String) -> Sse.Frame:
  Sse.Comment{Response.utf8(value)}
