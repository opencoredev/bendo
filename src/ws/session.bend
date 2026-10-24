# Pure connection policy. Frame decoding and message assembly remain BND-51's.
import Base
import ./frame.bend as F
import ./message.bend as M
import ../data/utf8.bend as Utf8

type Phase is Data:
  WsOpen{}
  WsClosing{}
  WsDone{}

type Command is Data:
  SendText{text: String}
  SendBinary{bytes: List<&2, U32>}
  SendPing{bytes: List<&2, U32>}
  SendClose{code: U32, reason: String}

type Notice is Data:
  WsSilent{}
  WsMessage{message: M.Message}
  WsFinished{code: U32, reason: String}

type Action is Data:
  Action{phase: Phase, frame: Maybe<&2, F.Frame>, notice: Notice}

def quiet(phase: Phase) -> Action:
  Action{phase, None{}, WsSilent{}}

def wire(op: F.Opcode, payload: List<&2, U32>) -> F.Frame:
  F.Frame{True{}, op, payload}

def command_frame(command: Command) -> F.Frame:
  match command:
    case SendText{text}: wire(F.OpText{}, Utf8.encode(text))
    case SendBinary{bytes}: wire(F.OpBinary{}, bytes)
    case SendPing{bytes}: wire(F.OpPing{}, bytes)
    case SendClose{code, reason}: wire(F.OpClose{}, M.close_payload(code, reason))

# Largest frame payload the server sends: data up to `max_message`, and
# control frames up to 125 bytes even when `max_message` is smaller.
def cap(+n: U32) -> U32: U32.max(n, 125)

def valid_close(command: Command) -> Bool:
  match command:
    case SendClose{code, reason}: M.code_ok(code)
    case _: True{}

def data_fits(max: U32, command: Command) -> Bool:
  match command:
    case SendText{text}: Nat.is_le(F.length(Utf8.encode(text)), U32.to_nat(max))
    case SendBinary{bytes}: Nat.is_le(F.length(bytes), U32.to_nat(max))
    case _: True{}

# Whether a send helper admits a command into the mailbox.
def admissible(+max: U32, +command: Command) -> Bool:
  F.valid(cap(max), command_frame(command), None{}) && valid_close(command) && data_fits(max, command)

def close_code(code: Maybe<&2, U32>) -> U32:
  match code:
    case None{}: 1005
    case Some{c}: c

def close_bytes(code: Maybe<&2, U32>, reason: String) -> List<&2, U32>:
  match code:
    case None{}: []
    case Some{c}: M.close_payload(c, reason)

# Peer close is echoed exactly once, including the empty payload spelling.
def incoming(phase: Phase, message: M.Message) -> Action:
  match phase message:
    case WsDone{} _: quiet(WsDone{})
    case WsOpen{} M.CloseMessage{+code, +reason}:
      Action{WsDone{}, Some{wire(F.OpClose{}, close_bytes(code, reason))}, WsFinished{close_code(code), reason}}
    case WsClosing{} M.CloseMessage{code, reason}:
      Action{WsDone{}, None{}, WsFinished{close_code(code), reason}}
    case WsClosing{} M.PingMessage{bytes}:
      Action{WsClosing{}, Some{wire(F.OpPong{}, bytes)}, WsSilent{}}
    case WsOpen{} M.PingMessage{bytes}:
      Action{WsOpen{}, Some{wire(F.OpPong{}, bytes)}, WsSilent{}}
    case WsOpen{} M.PongMessage{bytes}: quiet(WsOpen{})
    case WsOpen{} M.TextMessage{text}:
      Action{WsOpen{}, None{}, WsMessage{M.TextMessage{text}}}
    case WsOpen{} M.BinaryMessage{bytes}:
      Action{WsOpen{}, None{}, WsMessage{M.BinaryMessage{bytes}}}
    case WsClosing{} _: quiet(WsClosing{})

def outgoing(phase: Phase, command: Command) -> Action:
  match phase command:
    case WsClosing{} _: quiet(WsClosing{})
    case WsDone{} _: quiet(WsDone{})
    case WsOpen{} SendClose{code, reason}:
      Action{WsClosing{}, Some{command_frame(SendClose{code, reason})}, WsSilent{}}
    case WsOpen{} SendText{text}:
      Action{WsOpen{}, Some{command_frame(SendText{text})}, WsSilent{}}
    case WsOpen{} SendBinary{bytes}:
      Action{WsOpen{}, Some{command_frame(SendBinary{bytes})}, WsSilent{}}
    case WsOpen{} SendPing{bytes}:
      Action{WsOpen{}, Some{command_frame(SendPing{bytes})}, WsSilent{}}

def failure(phase: Phase, +code: U32) -> Action:
  match phase:
    case WsOpen{}:
      Action{WsDone{}, Some{wire(F.OpClose{}, M.close_payload(code, ""))}, WsFinished{code, ""}}
    case WsClosing{}: Action{WsDone{}, None{}, WsFinished{code, ""}}
    case WsDone{}: quiet(WsDone{})

def disconnected(phase: Phase) -> Action:
  match phase:
    case WsOpen{}: Action{WsDone{}, None{}, WsFinished{1006, ""}}
    case WsClosing{}: Action{WsDone{}, None{}, WsFinished{1006, ""}}
    case WsDone{}: quiet(WsDone{})

type Transition is Data:
  Transition{assembly: M.State, action: Action}

def assembled(phase: Phase, result: M.Advance) -> Transition:
  match result:
    case M.Advance{state, M.Absorbed{}}: Transition{state, quiet(phase)}
    case M.Advance{state, M.Deliver{message}}: Transition{state, incoming(phase, message)}
    case M.Advance{state, M.Failed{code}}: Transition{state, failure(phase, code)}

def receive(max: U32, phase: Phase, state: M.State, frame: F.Frame) -> Transition:
  assembled(phase, M.step(max, state, frame))

# The connection's whole pure state between socket events.
type Session is Data:
  Session{phase: Phase, assembly: M.State}

# Everything the connection feeds the policy. `Rejected` is a decoder error;
# `Dropped` is EOF, a transport or write failure, or an expired close wait.
type WsEvent is Data:
  Inbound{frame: F.Frame}
  Outbound{command: Command}
  Rejected{code: U32}
  Dropped{}

# The one reducer src/ws/connection.bend applies to every event. A frame in the
# action is written before its notice is delivered and the phase advances only
# after that write succeeds. A failed write is fed back as `Dropped` from the
# session the action started in.
def step(max: U32, session: Session, event: WsEvent) -> Transition:
  match session event:
    case Session{phase, assembly} Inbound{frame}: receive(max, phase, assembly, frame)
    case Session{phase, assembly} Outbound{command}: Transition{assembly, outgoing(phase, command)}
    case Session{phase, assembly} Rejected{code}: Transition{assembly, failure(phase, code)}
    case Session{phase, assembly} Dropped{}: Transition{assembly, disconnected(phase)}

def action_of(t: Transition) -> Action:
  match t:
    case Transition{assembly, action}: action

def after(t: Transition) -> Session:
  match t:
    case Transition{assembly, Action{phase, frame, notice}}: Session{phase, assembly}

# Folds of `step` over an event history, for the trace laws.
def trace(+max: U32, events: List<&2, WsEvent>, +session: Session) -> List<&2, Action>:
  match events:
    case Nil{}: []
    case +event <> rest: action_of(step(max, session, event)) <> trace(max, rest, after(step(max, session, event)))

def settle(+max: U32, events: List<&2, WsEvent>, +session: Session) -> Session:
  match events:
    case Nil{}: session
    case +event <> rest: settle(max, rest, after(step(max, session, event)))

def opened() -> Session:
  Session{WsOpen{}, M.Idle{}}
