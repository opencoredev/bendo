# Turns decoded frames into messages. Pure, one frame per step.
#
# Control frames may arrive between the fragments of a message and never
# disturb it. A continuation with no message open, or a new data frame while one
# is open, is a protocol error. Text is checked as UTF-8 once the final
# fragment arrives (a non-strict, fail-at-completion policy): a message that
# fails is never delivered. Each data frame's size is checked against the bytes
# left in the message budget before it is kept. After a close or an error the
# state is Ended and every later frame is ignored.
import Base
import ./frame.bend as F
import ../data/utf8.bend as Utf8

type Message is Data:
  TextMessage{text: String}
  BinaryMessage{data: List<&2, U32>}
  PingMessage{data: List<&2, U32>}
  PongMessage{data: List<&2, U32>}
  # `code` is None when the close frame had no payload.
  CloseMessage{code: Maybe<&2, U32>, reason: String}

type Outcome is Data:
  Absorbed{}
  Deliver{message: Message}
  Failed{code: U32}

# `rev` holds the message bytes so far, last byte first; `budget` is how many
# more bytes the message may carry.
type State is Data:
  Idle{}
  Collecting{text: Bool, rev: List<&2, U32>, budget: Nat}
  Ended{}

type Advance is Data:
  Advance{state: State, event: Outcome}

def invalid_payload() -> U32:
  1007

def fail(code: U32) -> Advance:
  Advance{Ended{}, Failed{code}}

def between(+c: U32, lo: U32, hi: U32) -> Bool:
  (c >= lo : U32) && (c <= hi : U32)

# Codes a peer may send (RFC 6455 section 7.4 and the IANA registry): 1000 to
# 1003, 1007 to 1014, and 3000 to 4999. 1004 to 1006 and 1015 are reserved or
# never sent; 1016 to 2999 are unassigned.
def code_ok(+c: U32) -> Bool:
  between(c, 1000, 1003) || between(c, 1007, 1014) || between(c, 3000, 4999)

def close_reason(code: U32, reason: Maybe<&2, String>) -> Advance:
  match reason:
    case None{}:
      fail(invalid_payload())
    case Some{text}:
      Advance{Ended{}, Deliver{CloseMessage{Some{code}, text}}}

def close_coded(ok: Bool, +code: U32, reason: List<&2, U32>) -> Advance:
  match ok:
    case False{}:
      fail(F.protocol_error())
    case True{}:
      close_reason(code, Utf8.decode(reason))

# A close payload is empty, or a two-byte big-endian code then UTF-8 text.
def close(payload: List<&2, U32>) -> Advance:
  match payload:
    case Nil{}:
      Advance{Ended{}, Deliver{CloseMessage{None{}, ""}}}
    case _ <> Nil{}:
      fail(F.protocol_error())
    case +hi <> +lo <> reason:
      +code = (hi * 256 + lo : U32)
      close_coded(F.is_octet(hi) && F.is_octet(lo) && code_ok(code), code, reason)

# The payload of a close frame this endpoint sends. A reason longer than 123
# UTF-8 bytes makes the frame invalid, which F.encode refuses.
def close_payload(+code: U32, reason: String) -> List<&2, U32>:
  U32.shrn(code, 8n) <> U32.and(code, 255) <> Utf8.encode(reason)

def control(op: F.Opcode, payload: List<&2, U32>) -> Outcome:
  match op:
    case F.OpPing{}:
      Deliver{PingMessage{payload}}
    case F.OpPong{}:
      Deliver{PongMessage{payload}}
    case _:
      Absorbed{}

def rev_onto(xs: List<&2, U32>, acc: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}:
      acc
    case x <> t:
      rev_onto(t, x <> acc)

def text_done(s: Maybe<&2, String>) -> Advance:
  match s:
    case None{}:
      fail(invalid_payload())
    case Some{text}:
      Advance{Idle{}, Deliver{TextMessage{text}}}

def complete(text: Bool, data: List<&2, U32>) -> Advance:
  match text:
    case True{}:
      text_done(Utf8.decode(data))
    case False{}:
      Advance{Idle{}, Deliver{BinaryMessage{data}}}

# Keep a fragment only when it fits the remaining budget.
def keep(fits: Bool, text: Bool, fin: Bool, rev: List<&2, U32>, budget: Nat, +n: Nat, payload: List<&2, U32>) -> Advance:
  match fits:
    case False{}:
      fail(F.too_big())
    case True{}:
      match fin:
        case True{}:
          complete(text, List.reverse(&2, U32, rev_onto(payload, rev)))
        case False{}:
          Advance{Collecting{text, rev_onto(payload, rev), Nat.sub(budget, n)}, Absorbed{}}

def fragment(text: Bool, fin: Bool, rev: List<&2, U32>, +budget: Nat, +payload: List<&2, U32>) -> Advance:
  +n = F.length(payload)
  keep(Nat.is_le(n, budget), text, fin, rev, budget, n, payload)

def data_kind(op: F.Opcode) -> Maybe<&2, Bool>:
  match op:
    case F.OpText{}:
      Some{True{}}
    case F.OpBinary{}:
      Some{False{}}
    case _:
      None{}

# A data frame: `kind` is Some{text?} for a new message, None for a
# continuation.
def data(max: U32, s: State, kind: Maybe<&2, Bool>, fin: Bool, payload: List<&2, U32>) -> Advance:
  match s kind:
    case Idle{} Some{text}:
      fragment(text, fin, [], U32.to_nat(max), payload)
    case Idle{} None{}:
      fail(F.protocol_error())
    case Collecting{_, _, _} Some{_}:
      fail(F.protocol_error())
    case Collecting{text, rev, budget} None{}:
      fragment(text, fin, rev, budget, payload)
    case Ended{} _:
      Advance{Ended{}, Absorbed{}}

def control_step(ok: Bool, s: State, +op: F.Opcode, payload: List<&2, U32>) -> Advance:
  match ok:
    case False{}:
      fail(F.protocol_error())
    case True{}:
      match op:
        case F.OpClose{}:
          close(payload)
        case _:
          Advance{s, control(op, payload)}

# Frame constructors are public, so a control frame is re-checked here.
def by_kind(control: Bool, max: U32, s: State, +op: F.Opcode, fin: Bool, +payload: List<&2, U32>) -> Advance:
  match control:
    case True{}:
      control_step(fin && Nat.is_le(F.length(payload), 125n), s, op, payload)
    case False{}:
      data(max, s, data_kind(op), fin, payload)

def live(max: U32, s: State, f: F.Frame) -> Advance:
  match f:
    case F.Frame{fin, +op, payload}:
      by_kind(F.is_control(op), max, s, op, fin, payload)

# `max` caps a whole message, summed over its fragments. Preconditions: frames
# come from F.decode (or are otherwise valid octet frames), every call uses the
# same `max`, and a Collecting state is one that `step` returned.
def step(max: U32, s: State, f: F.Frame) -> Advance:
  match s:
    case Ended{}:
      Advance{Ended{}, Absorbed{}}
    case Idle{}:
      live(max, Idle{}, f)
    case Collecting{text, rev, budget}:
      live(max, Collecting{text, rev, budget}, f)
