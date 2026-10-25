# Proofs of the BND-101 close-after-queue laws. Does not import LAWS.bend.
import Base
import ./ws-session-laws.bend as L
import ./ws-session-spec.bend as Spec
import ../src/ws/session.bend as S
import ../src/ws/message.bend as M

def cons_eq(-x: S.Action, -t1: List<&2, S.Action>, -t2: List<&2, S.Action>, e: {t1 == t2 : List<&2, S.Action>}) -> {x <> t1 == x <> t2 : List<&2, S.Action>}:
  %e : {x <> t1 == x <> _ : List<&2, S.Action>}
  {==}

def flush(+max: U32, +a: M.State, queue: List<&2, Spec.Queued>, +code: U32, +reason: String) -> {S.trace(max, Spec.drain(queue, code, reason), S.Session{S.WsOpen{}, a}) == Spec.drained(queue, code, reason) : List<&2, S.Action>}:
  match queue:
    case Nil{}: {==}
    case Spec.QueuedText{t} <> rest: cons_eq(S.Action{S.WsOpen{}, Some{Spec.queued_frame(Spec.QueuedText{t})}, S.WsSilent{}}, S.trace(max, Spec.drain(rest, code, reason), S.Session{S.WsOpen{}, a}), Spec.drained(rest, code, reason), flush(max, a, rest, code, reason))
    case Spec.QueuedBinary{b} <> rest: cons_eq(S.Action{S.WsOpen{}, Some{Spec.queued_frame(Spec.QueuedBinary{b})}, S.WsSilent{}}, S.trace(max, Spec.drain(rest, code, reason), S.Session{S.WsOpen{}, a}), Spec.drained(rest, code, reason), flush(max, a, rest, code, reason))
    case Spec.QueuedPing{b} <> rest: cons_eq(S.Action{S.WsOpen{}, Some{Spec.queued_frame(Spec.QueuedPing{b})}, S.WsSilent{}}, S.trace(max, Spec.drain(rest, code, reason), S.Session{S.WsOpen{}, a}), Spec.drained(rest, code, reason), flush(max, a, rest, code, reason))

def flushed(+max: U32, +a: M.State, queue: List<&2, Spec.Queued>, +code: U32, +reason: String) -> {S.settle(max, Spec.drain(queue, code, reason), S.Session{S.WsOpen{}, a}) == S.Session{S.WsClosing{}, a} : S.Session}:
  match queue:
    case Nil{}: {==}
    case Spec.QueuedText{t} <> rest: flushed(max, a, rest, code, reason)
    case Spec.QueuedBinary{b} <> rest: flushed(max, a, rest, code, reason)
    case Spec.QueuedPing{b} <> rest: flushed(max, a, rest, code, reason)

def L.ws_session_close_after_queue(max, assembly, queue, code, reason): flush(max, assembly, queue, code, reason)
def L.ws_session_close_after_queue_end(max, assembly, queue, code, reason): flushed(max, assembly, queue, code, reason)
