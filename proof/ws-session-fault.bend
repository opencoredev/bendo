# Proofs of the BND-52 input-error laws. Does not import LAWS.bend.
import Base
import ./ws-session-laws.bend as L
import ./ws-session-spec.bend as Spec
import ./ws-session-message.bend as MP
import ./ws-frame.bend as WF
import ../src/ws/session.bend as S
import ../src/ws/frame.bend as F
import ../src/ws/message.bend as M
import ../src/data/utf8.bend as Utf8

def absurd(-A: Type, e: Empty) -> A:
  match e:

def none_type(m: Maybe<&2, U32>) -> Type:
  match m:
    case None{}: Unit
    case Some{x}: Empty

def none_some(-x: U32, e: {None{} == Some{x} : Maybe<&2, U32>}) -> Empty:
  %e : none_type(_)
  Unit{}

def unwrap(m: Maybe<&2, U32>) -> U32:
  match m:
    case None{}: 0
    case Some{x}: x

def td_f(m: Maybe<&2, String>) -> {Spec.failure_of(M.text_done(m)) == Spec.utf8_result(m) : Maybe<&2, U32>}:
  match m:
    case None{}: {==}
    case Some{t}: {==}

def keep_f(fits: Bool, fin: Bool, text: Bool, +rev: List<&2, U32>, +budget: Nat, +n: Nat, +payload: List<&2, U32>) -> {Spec.failure_of(M.keep(fits, text, fin, rev, budget, n, payload)) == Spec.when(Bool.not(fits), 1009, Spec.utf8_fault(text && fin, List.append(&2, U32, List.reverse(&2, U32, rev), payload))) : Maybe<&2, U32>}:
  match fits:
    case False{}: {==}
    case True{}:
      match fin:
        case False{}:
          match text:
            case True{}: {==}
            case False{}: {==}
        case True{}:
          match text:
            case True{}:
              %Equal.sym(List<&2, U32>, List.reverse(&2, U32, M.rev_onto(payload, rev)), List.append(&2, U32, List.reverse(&2, U32, rev), payload), MP.rev_rev(payload, rev)) : {Spec.failure_of(M.text_done(Utf8.decode(_))) == Spec.utf8_result(Utf8.decode(List.append(&2, U32, List.reverse(&2, U32, rev), payload))) : Maybe<&2, U32>}
              td_f(Utf8.decode(List.append(&2, U32, List.reverse(&2, U32, rev), payload)))
            case False{}: {==}

def reason_f(+code: U32, m: Maybe<&2, String>) -> {Spec.failure_of(M.close_reason(code, m)) == Spec.utf8_result(m) : Maybe<&2, U32>}:
  match m:
    case None{}: {==}
    case Some{t}: {==}

def coded_f(ok: Bool, +code: U32, +reason: List<&2, U32>) -> {Spec.failure_of(M.close_coded(ok, code, reason)) == Spec.when(Bool.not(ok), 1002, Spec.utf8_fault(True{}, reason)) : Maybe<&2, U32>}:
  match ok:
    case False{}: {==}
    case True{}: reason_f(code, Utf8.decode(reason))

def close_f(payload: List<&2, U32>) -> {Spec.failure_of(M.close(payload)) == Spec.close_fault(payload) : Maybe<&2, U32>}:
  match payload:
    case Nil{}: {==}
    case +x <> t:
      match t:
        case Nil{}: {==}
        case +y <> r: coded_f(F.is_octet(x) && F.is_octet(y) && M.code_ok((x * 256 + y : U32)), (x * 256 + y : U32), r)

def cs_close(ok: Bool, +s: M.State, +payload: List<&2, U32>) -> {Spec.failure_of(M.control_step(ok, s, F.OpClose{}, payload)) == Spec.when(Bool.not(ok), 1002, Spec.close_fault(payload)) : Maybe<&2, U32>}:
  match ok:
    case False{}: {==}
    case True{}: close_f(payload)

def cs_ping(ok: Bool, s: M.State, +payload: List<&2, U32>) -> {Spec.failure_of(M.control_step(ok, s, F.OpPing{}, payload)) == Spec.when(Bool.not(ok), 1002, None{}) : Maybe<&2, U32>}:
  match ok:
    case False{}: {==}
    case True{}:
      match s:
        case M.Idle{}: {==}
        case M.Collecting{t, r, b}: {==}
        case M.Ended{}: {==}

def cs_pong(ok: Bool, s: M.State, +payload: List<&2, U32>) -> {Spec.failure_of(M.control_step(ok, s, F.OpPong{}, payload)) == Spec.when(Bool.not(ok), 1002, None{}) : Maybe<&2, U32>}:
  match ok:
    case False{}: {==}
    case True{}:
      match s:
        case M.Idle{}: {==}
        case M.Collecting{t, r, b}: {==}
        case M.Ended{}: {==}

def ctl_close(+s: M.State, +fin: Bool, +payload: List<&2, U32>) -> {Spec.failure_of(M.control_step(fin && Nat.is_le(F.length(payload), 125n), s, F.OpClose{}, payload)) == Spec.control_fault(fin, payload, Spec.close_fault(payload)) : Maybe<&2, U32>}:
  %MP.control_small(payload) : {Spec.failure_of(M.control_step(fin && Nat.is_le(F.length(payload), 125n), s, F.OpClose{}, payload)) == Spec.when(Bool.not(fin && _), 1002, Spec.close_fault(payload)) : Maybe<&2, U32>}
  cs_close(fin && Nat.is_le(F.length(payload), 125n), s, payload)

def ctl_ping(+s: M.State, +fin: Bool, +payload: List<&2, U32>) -> {Spec.failure_of(M.control_step(fin && Nat.is_le(F.length(payload), 125n), s, F.OpPing{}, payload)) == Spec.control_fault(fin, payload, None{}) : Maybe<&2, U32>}:
  %MP.control_small(payload) : {Spec.failure_of(M.control_step(fin && Nat.is_le(F.length(payload), 125n), s, F.OpPing{}, payload)) == Spec.when(Bool.not(fin && _), 1002, None{}) : Maybe<&2, U32>}
  cs_ping(fin && Nat.is_le(F.length(payload), 125n), s, payload)

def ctl_pong(+s: M.State, +fin: Bool, +payload: List<&2, U32>) -> {Spec.failure_of(M.control_step(fin && Nat.is_le(F.length(payload), 125n), s, F.OpPong{}, payload)) == Spec.control_fault(fin, payload, None{}) : Maybe<&2, U32>}:
  %MP.control_small(payload) : {Spec.failure_of(M.control_step(fin && Nat.is_le(F.length(payload), 125n), s, F.OpPong{}, payload)) == Spec.when(Bool.not(fin && _), 1002, None{}) : Maybe<&2, U32>}
  cs_pong(fin && Nat.is_le(F.length(payload), 125n), s, payload)

def start_f(+max: U32, +text: Bool, +fin: Bool, +payload: List<&2, U32>) -> {Spec.failure_of(M.keep(Nat.is_le(F.length(payload), U32.to_nat(max)), text, fin, [], U32.to_nat(max), F.length(payload), payload)) == Spec.start_fault(M.Idle{}, text, fin, payload, max) : Maybe<&2, U32>}:
  %MP.first_fits(payload, max) : {Spec.failure_of(M.keep(Nat.is_le(F.length(payload), U32.to_nat(max)), text, fin, [], U32.to_nat(max), F.length(payload), payload)) == Spec.when(Bool.not(_), 1009, Spec.utf8_fault(text && fin, payload)) : Maybe<&2, U32>}
  keep_f(Nat.is_le(F.length(payload), U32.to_nat(max)), fin, text, [], U32.to_nat(max), F.length(payload), payload)

def cont_f(+t: Bool, +r: List<&2, U32>, +b: Nat, +fin: Bool, +payload: List<&2, U32>) -> {Spec.failure_of(M.keep(Nat.is_le(F.length(payload), b), t, fin, r, b, F.length(payload), payload)) == Spec.continue_fault(M.Collecting{t, r, b}, fin, payload) : Maybe<&2, U32>}:
  %WF.length_eq(payload) : {Spec.failure_of(M.keep(Nat.is_le(F.length(payload), b), t, fin, r, b, F.length(payload), payload)) == Spec.when(Bool.not(Nat.is_le(_, b)), 1009, Spec.utf8_fault(t && fin, List.append(&2, U32, List.reverse(&2, U32, r), payload))) : Maybe<&2, U32>}
  keep_f(Nat.is_le(F.length(payload), b), fin, t, r, b, F.length(payload), payload)

def idle_f(+max: U32, f: F.Frame) -> {Spec.failure_of(M.step(max, M.Idle{}, f)) == Spec.fault(max, M.Idle{}, f) : Maybe<&2, U32>}:
  match f:
    case F.Frame{+fin, op, +payload}:
      match op:
        case F.OpClose{}: ctl_close(M.Idle{}, fin, payload)
        case F.OpPing{}: ctl_ping(M.Idle{}, fin, payload)
        case F.OpPong{}: ctl_pong(M.Idle{}, fin, payload)
        case F.OpText{}: start_f(max, True{}, fin, payload)
        case F.OpBinary{}: start_f(max, False{}, fin, payload)
        case F.OpContinue{}: {==}

def coll_f(+max: U32, +t: Bool, +r: List<&2, U32>, +b: Nat, f: F.Frame) -> {Spec.failure_of(M.step(max, M.Collecting{t, r, b}, f)) == Spec.fault(max, M.Collecting{t, r, b}, f) : Maybe<&2, U32>}:
  match f:
    case F.Frame{+fin, op, +payload}:
      match op:
        case F.OpClose{}: ctl_close(M.Collecting{t, r, b}, fin, payload)
        case F.OpPing{}: ctl_ping(M.Collecting{t, r, b}, fin, payload)
        case F.OpPong{}: ctl_pong(M.Collecting{t, r, b}, fin, payload)
        case F.OpText{}: {==}
        case F.OpBinary{}: {==}
        case F.OpContinue{}: cont_f(t, r, b, fin, payload)

def L.ws_session_fault_classified(max, st, f):
  match st:
    case M.Ended{}: {==}
    case M.Idle{}: idle_f(max, f)
    case M.Collecting{t, r, b}: coll_f(max, t, r, b, f)

def fin_phase(p: S.Phase, +c: U32) -> {S.assembled(p, M.Advance{M.Ended{}, M.Failed{c}}) == S.Transition{M.Ended{}, Spec.failed_in(p, c)} : S.Transition}:
  match p:
    case S.WsOpen{}: {==}
    case S.WsClosing{}: {==}
    case S.WsDone{}: {==}

def inv(+p: S.Phase, r: M.Advance, +code: U32, e: {Spec.failure_of(r) == Some{code} : Maybe<&2, U32>}) -> {S.assembled(p, r) == S.Transition{M.Ended{}, Spec.failed_in(p, code)} : S.Transition}:
  match r:
    case M.Advance{a, outcome}:
      match a:
        case M.Ended{}:
          match outcome:
            case M.Failed{+c}:
              %Equal.cong(Maybe<&2, U32>, U32, unwrap, Some{c}, Some{code}, e) : {S.assembled(p, M.Advance{M.Ended{}, M.Failed{c}}) == S.Transition{M.Ended{}, Spec.failed_in(p, _)} : S.Transition}
              fin_phase(p, c)
            case M.Absorbed{}: absurd({S.assembled(p, M.Advance{M.Ended{}, M.Absorbed{}}) == S.Transition{M.Ended{}, Spec.failed_in(p, code)} : S.Transition}, none_some(code, e))
            case M.Deliver{m}: absurd({S.assembled(p, M.Advance{M.Ended{}, M.Deliver{m}}) == S.Transition{M.Ended{}, Spec.failed_in(p, code)} : S.Transition}, none_some(code, e))
        case M.Idle{}: absurd({S.assembled(p, M.Advance{M.Idle{}, outcome}) == S.Transition{M.Ended{}, Spec.failed_in(p, code)} : S.Transition}, none_some(code, e))
        case M.Collecting{t, rv, b}: absurd({S.assembled(p, M.Advance{M.Collecting{t, rv, b}, outcome}) == S.Transition{M.Ended{}, Spec.failed_in(p, code)} : S.Transition}, none_some(code, e))

def L.ws_session_fault_closes(max, phase, st, f, code, bad):
  inv(phase, M.step(max, st, f), code, Equal.trans(Maybe<&2, U32>, Spec.failure_of(M.step(max, st, f)), Spec.fault(max, st, f), Some{code}, L.ws_session_fault_classified(max, st, f), bad))

def L.ws_session_rejected(max, phase, st, code):
  match phase:
    case S.WsOpen{}: {==}
    case S.WsClosing{}: {==}
    case S.WsDone{}: {==}
