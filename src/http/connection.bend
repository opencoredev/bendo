# Pure connection policy. The shell supplies monotonic timestamps and octets.
import Base
import ./body.bend as Body
import ./request.bend as R
import ./bytes.bend as Bytes
import ./response.bend as Response
import ../app/config.bend as Config

type Phase is Data:
  Idle{deadline: Nat}
  Head{deadline: Nat}
  Body{deadline: Nat}

type State is Data:
  State{input: Body.State, answered: U32, phase: Phase, received_at: Nat}

type Action is Data:
  Read{milliseconds: U32}
  Respond{req: R.Req, body: List<&2, U32>, rest: List<&2, U32>}
  Reject{status: U32}
  Stop{}

def initial(+now: Nat, config: Config.Config) -> State:
  Config.Config{host, port, limit, headers, idle, head, body, max, keep, router} = config
  State{Body.initial(), 0, Idle{Nat.add(now, U32.to_nat(idle))}, now}

def deadline(phase: Phase) -> Nat:
  match phase:
    case Idle{d}: d
    case Head{d}: d
    case Body{d}: d

def timeout(phase: Phase) -> Action:
  match phase:
    case Idle{d}: Stop{}
    case _: Reject{408}

def waiting(phase: Phase, left: Nat) -> Action:
  match left:
    case 0n: timeout(phase)
    case 1n+n: Read{U32.from_nat(1n+n)}

def action(state: State, now: Nat) -> Action:
  match state:
    case State{Body.Complete{req, body, trailers, rest}, count, phase, at}:
      Respond{req, body, rest}
    case State{Body.Bad{status}, count, phase, at}:
      Reject{status}
    case State{input, count, +phase, at}:
      waiting(phase, Nat.sub(deadline(phase), now))

def started(phase: Phase, now: Nat, head: U32) -> Phase:
  match phase:
    case Idle{d}: Head{Nat.add(now, U32.to_nat(head))}
    case p: p

def body_phase(phase: Phase, +now: Nat, body: U32) -> Phase:
  match phase:
    case Body{d}: Body{d}
    case _: Body{Nat.add(now, U32.to_nat(body))}

def phase_for(input: Body.State, phase: Phase, +now: Nat, body: U32) -> Phase:
  match input:
    case Body.Fixed{r, n, rev}: body_phase(phase, now, body)
    case Body.Chunks{r, decoder}: body_phase(phase, now, body)
    case _: phase

def fed(pair: Body.State & Bool, count: U32, phase: Phase, +now: Nat, body: U32) -> State & Bool:
  (+input, interim) = pair
  (State{input, count, phase_for(input, phase, now, body), now}, interim)

def feed_nonempty(xs: List<&2, U32>, state: State, +now: Nat, config: Config.Config) -> State & Bool:
  State{input, count, phase, at} = state
  Config.Config{host, port, limit, headers, idle, head, body, max, keep, router} = config
  fed(Body.feed_limits(xs, input, limit, headers), count, started(phase, now, head), now, body)

def feed(xs: List<&2, U32>, state: State, now: Nat, config: Config.Config) -> State & Bool:
  match xs:
    case Nil{}: (state, False{})
    case c <> t: feed_nonempty(c <> t, state, now, config)

def next_rest(rest: List<&2, U32>, count: U32, +at: Nat, +now: Nat, +config: Config.Config) -> State & Bool:
  match rest:
    case Nil{}:
      Config.Config{host, port, limit, headers, idle, head, body, max, keep, router} = config
      (State{Body.initial(), (count + 1 : U32), Idle{Nat.add(now, U32.to_nat(idle))}, now}, False{})
    case c <> t:
      Config.Config{host, port, limit, headers, idle, head, body, max, keep, router} = config
      feed(c <> t, State{Body.initial(), (count + 1 : U32), Idle{now}, at}, at, config)

def next(state: State, rest: List<&2, U32>, now: Nat, config: Config.Config) -> State & Bool:
  State{input, count, phase, at} = state
  next_rest(rest, count, at, now, config)

# Connection options are comma-separated, case-insensitive tokens across fields.
def tokens(parts: List<&2, String>, +wanted: String) -> Bool:
  match parts:
    case Nil{}: False{}
    case p <> t:
      String.eq(Bytes.fold(Bytes.ascii(Bytes.trim(Bytes.encode(p)))), wanted) || tokens(t, wanted)

def has_token(hs: List<&2, R.Header>, +wanted: String) -> Bool:
  match hs:
    case Nil{}: False{}
    case R.Header{n, v} <> t:
      (String.eq(Bytes.fold(n), "connection") && tokens(String.split(Bytes.ascii(v), ','), wanted)) || has_token(t, wanted)

def closing(req: R.Req, count: U32, config: Config.Config) -> Bool:
  match req:
    case R.Req{m, p, q, R.Http10{}, hs}: True{}
    case R.Req{m, p, q, R.Http11{}, hs}:
      Config.Config{host, port, limit, headers, idle, head, body, +max, keep, router} = config
      Bool.not(keep) || U32.is_eq(max, 0) || (count >= U32.sub(max, 1) : U32) || has_token(hs, "close")

def eof(state: State) -> Action:
  match state:
    case State{input, count, Idle{d}, at}: Stop{}
    case _: Reject{400}

def retain(h: R.Header) -> Bool:
  R.Header{n, v} = h
  Bool.not(String.eq(Bytes.fold(n), "connection"))

def without_connection(hs: List<&2, R.Header>) -> List<&2, R.Header>:
  List.filter(~R.Header, ~retain, hs)

def headers(hs: List<&2, R.Header>, close: Bool) -> List<&2, R.Header>:
  match close:
    case True{}: R.Header{"connection", Bytes.encode("close")} <> without_connection(hs)
    case False{}: hs

# Closing response policy is independent of socket ownership and serialization.
def response_closing(res: Response.Res, close: Bool) -> Bool:
  Response.Res{+status, hs, body, rep} = res
  close || has_token(hs, "close") || (status < 200 : U32) || U32.is_eq(status, 400) || U32.is_eq(status, 413) || U32.is_eq(status, 417) || U32.is_eq(status, 431)
