# Independent RFC session table: writes, delivery, terminal notification.
import Base
import ../src/ws/session.bend as S
import ../src/ws/frame.bend as F
import ../src/ws/message.bend as M
import ../src/data/utf8.bend as Utf8

def code(c: Maybe<&2, U32>) -> U32:
  match c:
    case None{}: 1005
    case Some{x}: x

def payload(c: Maybe<&2, U32>, reason: String) -> List<&2, U32>:
  match c:
    case None{}: []
    case Some{+x}: U32.shrn(x, 8n) <> U32.and(x, 255) <> Utf8.encode(reason)

def receive(p: S.Phase, m: M.Message) -> S.Action:
  match p m:
    case S.WsOpen{} M.TextMessage{t}: S.Action{S.WsOpen{}, None{}, S.WsMessage{M.TextMessage{t}}}
    case S.WsOpen{} M.BinaryMessage{b}: S.Action{S.WsOpen{}, None{}, S.WsMessage{M.BinaryMessage{b}}}
    case S.WsOpen{} M.PingMessage{b}: S.Action{S.WsOpen{}, Some{F.Frame{True{}, F.OpPong{}, b}}, S.WsSilent{}}
    case S.WsOpen{} M.PongMessage{b}: S.Action{S.WsOpen{}, None{}, S.WsSilent{}}
    case S.WsOpen{} M.CloseMessage{+c, +r}: S.Action{S.WsDone{}, Some{F.Frame{True{}, F.OpClose{}, payload(c, r)}}, S.WsFinished{code(c), r}}
    case S.WsClosing{} M.CloseMessage{c, r}: S.Action{S.WsDone{}, None{}, S.WsFinished{code(c), r}}
    case S.WsClosing{} M.PingMessage{b}: S.Action{S.WsClosing{}, Some{F.Frame{True{}, F.OpPong{}, b}}, S.WsSilent{}}
    case S.WsClosing{} _: S.Action{S.WsClosing{}, None{}, S.WsSilent{}}
    case S.WsDone{} _: S.Action{S.WsDone{}, None{}, S.WsSilent{}}

def quiet(p: S.Phase) -> S.Action:
  S.Action{p, None{}, S.WsSilent{}}

# A drop ends a live session without writing a frame; a finished one ignores it.
def dropped(p: S.Phase) -> S.Action:
  match p:
    case S.WsOpen{}: S.Action{S.WsDone{}, None{}, S.WsFinished{1006, ""}}
    case S.WsClosing{}: S.Action{S.WsDone{}, None{}, S.WsFinished{1006, ""}}
    case S.WsDone{}: S.Action{S.WsDone{}, None{}, S.WsSilent{}}

# A phase-free monitor of what a trace writes and delivers.

def opcode_closes(op: F.Opcode) -> Bool:
  match op:
    case F.OpClose{}: True{}
    case F.OpContinue{}: False{}
    case F.OpText{}: False{}
    case F.OpBinary{}: False{}
    case F.OpPing{}: False{}
    case F.OpPong{}: False{}

def opcode_pongs(op: F.Opcode) -> Bool:
  match op:
    case F.OpPong{}: True{}
    case F.OpContinue{}: False{}
    case F.OpText{}: False{}
    case F.OpBinary{}: False{}
    case F.OpClose{}: False{}
    case F.OpPing{}: False{}

def writes_close(frame: Maybe<&2, F.Frame>) -> Bool:
  match frame:
    case None{}: False{}
    case Some{F.Frame{fin, op, payload}}: opcode_closes(op)

def pong_or_nothing(frame: Maybe<&2, F.Frame>) -> Bool:
  match frame:
    case None{}: True{}
    case Some{F.Frame{fin, op, payload}}: opcode_pongs(op)

def nothing(frame: Maybe<&2, F.Frame>) -> Bool:
  match frame:
    case None{}: True{}
    case Some{f}: False{}

def finishes(n: S.Notice) -> Bool:
  match n:
    case S.WsFinished{code, reason}: True{}
    case S.WsSilent{}: False{}
    case S.WsMessage{m}: False{}

def delivers(n: S.Notice) -> Bool:
  match n:
    case S.WsMessage{m}: True{}
    case S.WsSilent{}: False{}
    case S.WsFinished{code, reason}: False{}

def silent(n: S.Notice) -> Bool:
  match n:
    case S.WsSilent{}: True{}
    case S.WsMessage{m}: False{}
    case S.WsFinished{code, reason}: False{}

# `closed`: a close frame was written earlier. `finished`: the finish notice
# was delivered earlier. After a close only pongs are written and no message
# is delivered; after the finish nothing is written or delivered.
def allowed(finished: Bool, closed: Bool, frame: Maybe<&2, F.Frame>, notice: S.Notice) -> Bool:
  match finished:
    case True{}: nothing(frame) && silent(notice)
    case False{}:
      match closed:
        case True{}: pong_or_nothing(frame) && Bool.not(delivers(notice))
        case False{}: True{}

def watch(actions: List<&2, S.Action>, +closed: Bool, +finished: Bool) -> Bool:
  match actions:
    case Nil{}: True{}
    case S.Action{phase, +frame, +notice} <> rest:
      allowed(finished, closed, frame, notice) && watch(rest, closed || writes_close(frame), finished || finishes(notice))

# The answer to a valid ping: one identical pong while the session is live,
# nothing once it is done. Either way the session is unchanged.
def ping_reply(s: S.Session, payload: List<&2, U32>) -> S.Transition:
  match s:
    case S.Session{S.WsDone{}, a}: S.Transition{a, quiet(S.WsDone{})}
    case S.Session{S.WsOpen{}, a}: S.Transition{a, S.Action{S.WsOpen{}, Some{F.Frame{True{}, F.OpPong{}, payload}}, S.WsSilent{}}}
    case S.Session{S.WsClosing{}, a}: S.Transition{a, S.Action{S.WsClosing{}, Some{F.Frame{True{}, F.OpPong{}, payload}}, S.WsSilent{}}}

# ---- Messages assembled from frames ----

# What may arrive between a message's first and last fragment: a control frame
# (a ping when `ping`, else a pong) or a non-final continuation.
type Piece is Data:
  Interleaved{ping: Bool, payload: List<&2, U32>}
  Middle{payload: List<&2, U32>}

def data_op(text: Bool) -> F.Opcode:
  match text:
    case True{}: F.OpText{}
    case False{}: F.OpBinary{}

def control_op(ping: Bool) -> F.Opcode:
  match ping:
    case True{}: F.OpPing{}
    case False{}: F.OpPong{}

def piece_frame(p: Piece) -> F.Frame:
  match p:
    case Interleaved{ping, b}: F.Frame{True{}, control_op(ping), b}
    case Middle{b}: F.Frame{False{}, F.OpContinue{}, b}

# The first fragment of a message that continues.
def opening(text: Bool, first: List<&2, U32>) -> S.WsEvent:
  S.Inbound{F.Frame{False{}, data_op(text), first}}

def open_events(pieces: List<&2, Piece>) -> List<&2, S.WsEvent>:
  match pieces:
    case Nil{}: []
    case p <> rest: S.Inbound{piece_frame(p)} <> open_events(rest)

# The pieces, then the final continuation.
def tail_events(pieces: List<&2, Piece>, last: List<&2, U32>) -> List<&2, S.WsEvent>:
  match pieces:
    case Nil{}: [S.Inbound{F.Frame{True{}, F.OpContinue{}, last}}]
    case p <> rest: S.Inbound{piece_frame(p)} <> tail_events(rest, last)

def fits(max: U32, bytes: List<&2, U32>) -> Bool:
  Nat.is_le(List.length(&2, U32, bytes), U32.to_nat(max))

def small(bytes: List<&2, U32>) -> Bool:
  Nat.is_le(List.length(&2, U32, bytes), 125n)

def failed(+code: U32) -> S.Action:
  S.Action{S.WsDone{}, Some{F.Frame{True{}, F.OpClose{}, payload(Some{code}, "")}}, S.WsFinished{code, ""}}

def pick(b: Bool, x: S.Action, y: S.Action) -> S.Action:
  match b:
    case True{}: x
    case False{}: y

def select(b: Bool, x: List<&2, S.Action>, y: List<&2, S.Action>) -> List<&2, S.Action>:
  match b:
    case True{}: x
    case False{}: y

# Once a session is done, every later event is ignored.
def quiets(events: List<&2, S.WsEvent>) -> List<&2, S.Action>:
  match events:
    case Nil{}: []
    case e <> rest: quiet(S.WsDone{}) <> quiets(rest)

def reply(ping: Bool, b: List<&2, U32>) -> S.Action:
  match ping:
    case True{}: S.Action{S.WsOpen{}, Some{F.Frame{True{}, F.OpPong{}, b}}, S.WsSilent{}}
    case False{}: quiet(S.WsOpen{})

def text_delivered(m: Maybe<&2, String>) -> S.Action:
  match m:
    case None{}: failed(1007)
    case Some{t}: S.Action{S.WsOpen{}, None{}, S.WsMessage{M.TextMessage{t}}}

def delivered(text: Bool, bytes: List<&2, U32>) -> S.Action:
  match text:
    case True{}: text_delivered(Utf8.decode(bytes))
    case False{}: S.Action{S.WsOpen{}, None{}, S.WsMessage{M.BinaryMessage{bytes}}}

# The final fragment: the whole message, if it fits.
def finale(+max: U32, +text: Bool, +whole: List<&2, U32>) -> S.Action:
  pick(fits(max, whole), delivered(text, whole), failed(1009))

# `seen` is the message so far. A continuation must keep the whole message
# within max (else 1009) and a control frame within 125 bytes (else 1002).
def expect(+max: U32, +text: Bool, pieces: List<&2, Piece>, +seen: List<&2, U32>, +last: List<&2, U32>) -> List<&2, S.Action>:
  match pieces:
    case Nil{}: [finale(max, text, List.append(&2, U32, seen, last))]
    case Interleaved{+ping, +b} <> +rest:
      pick(small(b), reply(ping, b), failed(1002)) <> select(small(b), expect(max, text, rest, seen, last), quiets(tail_events(rest, last)))
    case Middle{+b} <> +rest:
      pick(fits(max, List.append(&2, U32, seen, b)), quiet(S.WsOpen{}), failed(1009)) <> select(fits(max, List.append(&2, U32, seen, b)), expect(max, text, rest, List.append(&2, U32, seen, b), last), quiets(tail_events(rest, last)))

def expected(+max: U32, +text: Bool, +first: List<&2, U32>, +pieces: List<&2, Piece>, +last: List<&2, U32>) -> List<&2, S.Action>:
  pick(fits(max, first), quiet(S.WsOpen{}), failed(1009)) <> select(fits(max, first), expect(max, text, pieces, first, last), quiets(tail_events(pieces, last)))

def bump(n: S.Notice, k: Nat) -> Nat:
  match n:
    case S.WsMessage{m}: 1n+k
    case S.WsSilent{}: k
    case S.WsFinished{code, reason}: k

# How many message notices a trace delivers.
def messages(actions: List<&2, S.Action>) -> Nat:
  match actions:
    case Nil{}: 0n
    case S.Action{p, f, n} <> rest: bump(n, messages(rest))

# ---- Input errors ----

def when(bad: Bool, code: U32, otherwise: Maybe<&2, U32>) -> Maybe<&2, U32>:
  match bad:
    case True{}: Some{code}
    case False{}: otherwise

def in_range(+c: U32, lo: U32, hi: U32) -> Bool:
  U32.is_ge(c, lo) && U32.is_le(c, hi)

# Close codes a peer may send (RFC 6455 7.4.1 and the IANA registry).
def peer_code(+c: U32) -> Bool:
  in_range(c, 1000, 1003) || in_range(c, 1007, 1014) || in_range(c, 3000, 4999)

def utf8_result(m: Maybe<&2, String>) -> Maybe<&2, U32>:
  match m:
    case None{}: Some{1007}
    case Some{t}: None{}

# Text that must be UTF-8 and is not fails with 1007.
def utf8_fault(check: Bool, bytes: List<&2, U32>) -> Maybe<&2, U32>:
  match check:
    case True{}: utf8_result(Utf8.decode(bytes))
    case False{}: None{}

# A close payload is empty, or a code a peer may send then a UTF-8 reason.
def close_fault(payload: List<&2, U32>) -> Maybe<&2, U32>:
  match payload:
    case Nil{}: None{}
    case _ <> Nil{}: Some{1002}
    case +hi <> +lo <> reason:
      when(Bool.not(F.is_octet(hi) && F.is_octet(lo) && peer_code((hi * 256 + lo : U32))), 1002, utf8_fault(True{}, reason))

# A control frame must be final and at most 125 bytes.
def control_fault(fin: Bool, +payload: List<&2, U32>, inner: Maybe<&2, U32>) -> Maybe<&2, U32>:
  when(Bool.not(fin && small(payload)), 1002, inner)

# A text or binary frame starts a message, so none may be open. The message
# must fit max, and a final text frame must be UTF-8.
def start_fault(st: M.State, text: Bool, fin: Bool, +payload: List<&2, U32>, +max: U32) -> Maybe<&2, U32>:
  match st:
    case M.Idle{}: when(Bool.not(fits(max, payload)), 1009, utf8_fault(text && fin, payload))
    case M.Collecting{t, r, b}: Some{1002}
    case M.Ended{}: None{}

# A continuation needs an open message and must fit what is left of its budget.
# The final one completes the message, which must be UTF-8 if it is text.
def continue_fault(st: M.State, fin: Bool, +payload: List<&2, U32>) -> Maybe<&2, U32>:
  match st:
    case M.Idle{}: Some{1002}
    case M.Collecting{t, rev, +budget}: when(Bool.not(Nat.is_le(List.length(&2, U32, payload), budget)), 1009, utf8_fault(t && fin, List.append(&2, U32, List.reverse(&2, U32, rev), payload)))
    case M.Ended{}: None{}

def frame_fault(+max: U32, +st: M.State, f: F.Frame) -> Maybe<&2, U32>:
  match f:
    case F.Frame{fin, op, +payload}:
      match op:
        case F.OpClose{}: control_fault(fin, payload, close_fault(payload))
        case F.OpPing{}: control_fault(fin, payload, None{})
        case F.OpPong{}: control_fault(fin, payload, None{})
        case F.OpText{}: start_fault(st, True{}, fin, payload, max)
        case F.OpBinary{}: start_fault(st, False{}, fin, payload, max)
        case F.OpContinue{}: continue_fault(st, fin, payload)

# The close code an input error in one decoded frame calls for, given the
# message being assembled; None when the frame is acceptable. After a close or
# an earlier error (Ended) every frame is ignored.
def fault(+max: U32, st: M.State, f: F.Frame) -> Maybe<&2, U32>:
  match st:
    case M.Ended{}: None{}
    case M.Idle{}: frame_fault(max, M.Idle{}, f)
    case M.Collecting{+t, +r, +b}: frame_fault(max, M.Collecting{t, r, b}, f)

# The code with which one assembler step ends the message, if it does.
def failure_of(r: M.Advance) -> Maybe<&2, U32>:
  match r:
    case M.Advance{M.Ended{}, M.Failed{code}}: Some{code}
    case M.Advance{st, outcome}: None{}

# How a session ends on an input error: one close frame while open; while
# closing the close was already sent; once done, nothing.
def failed_in(p: S.Phase, +code: U32) -> S.Action:
  match p:
    case S.WsOpen{}: failed(code)
    case S.WsClosing{}: S.Action{S.WsDone{}, None{}, S.WsFinished{code, ""}}
    case S.WsDone{}: quiet(S.WsDone{})
