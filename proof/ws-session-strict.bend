# Proofs of the BND-52 round 2 session laws: strict trace safety and closes
# from the peer. Does not import LAWS.bend.
import Base
import ./ws-session-laws.bend as L
import ./ws-session-spec.bend as Spec
import ./ws-session-trace.bend as TP
import ./ws-session-message.bend as MP
import ../src/ws/session.bend as S
import ../src/ws/frame.bend as F
import ../src/ws/message.bend as M
import ../src/data/utf8.bend as Utf8

def absurd(-A: Type, e: Empty) -> A:
  match e:

# ---- Strict trace safety: done, then closing, then open ----

def s_done_in(+max: U32, +rest: List<&2, S.WsEvent>, +c: Bool, r: M.Advance, ih: @st: M.State -> {Spec.strict_watch(S.trace(max, rest, S.Session{S.WsDone{}, st}), Bool.or(c, False{}), True{}) == True{} : Bool}) -> {Spec.strict_watch(S.action_of(S.assembled(S.WsDone{}, r)) <> S.trace(max, rest, S.after(S.assembled(S.WsDone{}, r))), c, True{}) == True{} : Bool}:
  match r:
    case M.Advance{st, M.Absorbed{}}: ih(st)
    case M.Advance{st, M.Deliver{m}}: ih(st)
    case M.Advance{st, M.Failed{code}}: ih(st)

def s_done_event(+max: U32, +a: M.State, e: S.WsEvent, +rest: List<&2, S.WsEvent>, +c: Bool, ih: @st: M.State -> {Spec.strict_watch(S.trace(max, rest, S.Session{S.WsDone{}, st}), Bool.or(c, False{}), True{}) == True{} : Bool}) -> {Spec.strict_watch(S.trace(max, e <> rest, S.Session{S.WsDone{}, a}), c, True{}) == True{} : Bool}:
  match e:
    case S.Inbound{f}: s_done_in(max, rest, c, M.step(max, a, f), ih)
    case S.Outbound{command}: ih(a)
    case S.Rejected{code}: ih(a)
    case S.Dropped{}: ih(a)

def s_done_safe(+max: U32, es: List<&2, S.WsEvent>, +a: M.State, +c: Bool) -> {Spec.strict_watch(S.trace(max, es, S.Session{S.WsDone{}, a}), c, True{}) == True{} : Bool}:
  match es:
    case Nil{}: {==}
    case +e <> +rest: s_done_event(max, a, e, rest, c, st => s_done_safe(max, rest, st, Bool.or(c, False{})))

def s_closing_deliver(+max: U32, +rest: List<&2, S.WsEvent>, +st: M.State, m: M.Message, ih: @st: M.State -> {Spec.strict_watch(S.trace(max, rest, S.Session{S.WsClosing{}, st}), True{}, False{}) == True{} : Bool}) -> {Spec.strict_watch(S.action_of(S.assembled(S.WsClosing{}, M.Advance{st, M.Deliver{m}})) <> S.trace(max, rest, S.after(S.assembled(S.WsClosing{}, M.Advance{st, M.Deliver{m}}))), True{}, False{}) == True{} : Bool}:
  match m:
    case M.CloseMessage{code, reason}: s_done_safe(max, rest, st, True{})
    case M.PingMessage{b}: ih(st)
    case M.PongMessage{b}: ih(st)
    case M.TextMessage{t}: ih(st)
    case M.BinaryMessage{b}: ih(st)

def s_closing_in(+max: U32, +rest: List<&2, S.WsEvent>, r: M.Advance, ih: @st: M.State -> {Spec.strict_watch(S.trace(max, rest, S.Session{S.WsClosing{}, st}), True{}, False{}) == True{} : Bool}) -> {Spec.strict_watch(S.action_of(S.assembled(S.WsClosing{}, r)) <> S.trace(max, rest, S.after(S.assembled(S.WsClosing{}, r))), True{}, False{}) == True{} : Bool}:
  match r:
    case M.Advance{st, M.Absorbed{}}: ih(st)
    case M.Advance{st, M.Deliver{m}}: s_closing_deliver(max, rest, st, m, ih)
    case M.Advance{st, M.Failed{code}}: s_done_safe(max, rest, st, True{})

def s_closing_event(+max: U32, +a: M.State, e: S.WsEvent, +rest: List<&2, S.WsEvent>, ih: @st: M.State -> {Spec.strict_watch(S.trace(max, rest, S.Session{S.WsClosing{}, st}), True{}, False{}) == True{} : Bool}) -> {Spec.strict_watch(S.trace(max, e <> rest, S.Session{S.WsClosing{}, a}), True{}, False{}) == True{} : Bool}:
  match e:
    case S.Inbound{f}: s_closing_in(max, rest, M.step(max, a, f), ih)
    case S.Outbound{command}: ih(a)
    case S.Rejected{code}: s_done_safe(max, rest, a, True{})
    case S.Dropped{}: s_done_safe(max, rest, a, True{})

def s_closing_safe(+max: U32, es: List<&2, S.WsEvent>, +a: M.State) -> {Spec.strict_watch(S.trace(max, es, S.Session{S.WsClosing{}, a}), True{}, False{}) == True{} : Bool}:
  match es:
    case Nil{}: {==}
    case +e <> +rest: s_closing_event(max, a, e, rest, st => s_closing_safe(max, rest, st))

def s_open_deliver(+max: U32, +rest: List<&2, S.WsEvent>, +st: M.State, m: M.Message, ih: @st: M.State -> {Spec.strict_watch(S.trace(max, rest, S.Session{S.WsOpen{}, st}), False{}, False{}) == True{} : Bool}) -> {Spec.strict_watch(S.action_of(S.assembled(S.WsOpen{}, M.Advance{st, M.Deliver{m}})) <> S.trace(max, rest, S.after(S.assembled(S.WsOpen{}, M.Advance{st, M.Deliver{m}}))), False{}, False{}) == True{} : Bool}:
  match m:
    case M.CloseMessage{code, reason}: s_done_safe(max, rest, st, True{})
    case M.PingMessage{b}: ih(st)
    case M.PongMessage{b}: ih(st)
    case M.TextMessage{t}: ih(st)
    case M.BinaryMessage{b}: ih(st)

def s_open_in(+max: U32, +rest: List<&2, S.WsEvent>, r: M.Advance, ih: @st: M.State -> {Spec.strict_watch(S.trace(max, rest, S.Session{S.WsOpen{}, st}), False{}, False{}) == True{} : Bool}) -> {Spec.strict_watch(S.action_of(S.assembled(S.WsOpen{}, r)) <> S.trace(max, rest, S.after(S.assembled(S.WsOpen{}, r))), False{}, False{}) == True{} : Bool}:
  match r:
    case M.Advance{st, M.Absorbed{}}: ih(st)
    case M.Advance{st, M.Deliver{m}}: s_open_deliver(max, rest, st, m, ih)
    case M.Advance{st, M.Failed{code}}: s_done_safe(max, rest, st, True{})

def s_open_command(+max: U32, +a: M.State, command: S.Command, +rest: List<&2, S.WsEvent>, ih: @st: M.State -> {Spec.strict_watch(S.trace(max, rest, S.Session{S.WsOpen{}, st}), False{}, False{}) == True{} : Bool}) -> {Spec.strict_watch(S.trace(max, S.Outbound{command} <> rest, S.Session{S.WsOpen{}, a}), False{}, False{}) == True{} : Bool}:
  match command:
    case S.SendText{t}: ih(a)
    case S.SendBinary{b}: ih(a)
    case S.SendPing{b}: ih(a)
    case S.SendClose{code, reason}: s_closing_safe(max, rest, a)

def s_open_event(+max: U32, +a: M.State, e: S.WsEvent, +rest: List<&2, S.WsEvent>, ih: @st: M.State -> {Spec.strict_watch(S.trace(max, rest, S.Session{S.WsOpen{}, st}), False{}, False{}) == True{} : Bool}) -> {Spec.strict_watch(S.trace(max, e <> rest, S.Session{S.WsOpen{}, a}), False{}, False{}) == True{} : Bool}:
  match e:
    case S.Inbound{f}: s_open_in(max, rest, M.step(max, a, f), ih)
    case S.Outbound{command}: s_open_command(max, a, command, rest, ih)
    case S.Rejected{code}: s_done_safe(max, rest, a, True{})
    case S.Dropped{}: s_done_safe(max, rest, a, False{})

def s_open_safe(+max: U32, es: List<&2, S.WsEvent>, +a: M.State) -> {Spec.strict_watch(S.trace(max, es, S.Session{S.WsOpen{}, a}), False{}, False{}) == True{} : Bool}:
  match es:
    case Nil{}: {==}
    case +e <> +rest: s_open_event(max, a, e, rest, st => s_open_safe(max, rest, st))

def L.ws_session_trace_strict(max, events):
  s_open_safe(max, events, M.Idle{})

# ---- A valid close from the peer ----

def none_type(m: Maybe<&2, U32>) -> Type:
  match m:
    case None{}: Unit
    case Some{x}: Empty

def none_some(-x: U32, e: {None{} == Some{x} : Maybe<&2, U32>}) -> Empty:
  %e : none_type(_)
  Unit{}

def some_none(-x: U32, e: {Some{x} == None{} : Maybe<&2, U32>}) -> Empty:
  none_some(x, Equal.sym(Maybe<&2, U32>, Some{x}, None{}, e))

def reason_c(m: Maybe<&2, String>, p: S.Phase, +code: U32, ok: {Spec.utf8_result(m) == None{} : Maybe<&2, U32>}) -> {S.assembled(p, M.close_reason(code, m)) == Spec.close_finish(p, Some{code}, Spec.text_or_empty(m)) : S.Transition}:
  match m:
    case None{}: absurd({S.assembled(p, M.close_reason(code, None{})) == Spec.close_finish(p, Some{code}, Spec.text_or_empty(None{})) : S.Transition}, some_none(1007, ok))
    case Some{t}:
      match p:
        case S.WsOpen{}: {==}
        case S.WsClosing{}: {==}
        case S.WsDone{}: {==}

def coded_c(ok: Bool, +p: S.Phase, +code: U32, +reason: List<&2, U32>, v: {Spec.when(Bool.not(ok), 1002, Spec.utf8_fault(True{}, reason)) == None{} : Maybe<&2, U32>}) -> {S.assembled(p, M.close_coded(ok, code, reason)) == Spec.close_finish(p, Some{code}, Spec.text_or_empty(Utf8.decode(reason))) : S.Transition}:
  match ok:
    case False{}: absurd({S.assembled(p, M.close_coded(False{}, code, reason)) == Spec.close_finish(p, Some{code}, Spec.text_or_empty(Utf8.decode(reason))) : S.Transition}, some_none(1002, v))
    case True{}: reason_c(Utf8.decode(reason), p, code, v)

def payload_c(payload: List<&2, U32>, +p: S.Phase, v: {Spec.close_fault(payload) == None{} : Maybe<&2, U32>}) -> {S.assembled(p, M.close(payload)) == Spec.close_finish(p, Spec.close_code_in(payload), Spec.close_reason_in(payload)) : S.Transition}:
  match payload:
    case Nil{}:
      match p:
        case S.WsOpen{}: {==}
        case S.WsClosing{}: {==}
        case S.WsDone{}: {==}
    case +x <> t:
      match t:
        case Nil{}: absurd({S.assembled(p, M.close([x])) == Spec.close_finish(p, Spec.close_code_in([x]), Spec.close_reason_in([x])) : S.Transition}, some_none(1002, v))
        case +y <> +r: coded_c(F.is_octet(x) && F.is_octet(y) && M.code_ok((x * 256 + y : U32)), p, (x * 256 + y : U32), r, v)

def ctl_c(small: Bool, +p: S.Phase, a: M.State, +payload: List<&2, U32>, v: {Spec.when(Bool.not(small), 1002, Spec.close_fault(payload)) == None{} : Maybe<&2, U32>}) -> {S.assembled(p, M.control_step(small, a, F.OpClose{}, payload)) == Spec.close_finish(p, Spec.close_code_in(payload), Spec.close_reason_in(payload)) : S.Transition}:
  match small:
    case True{}: payload_c(payload, p, v)
    case False{}: absurd({S.assembled(p, M.control_step(False{}, a, F.OpClose{}, payload)) == Spec.close_finish(p, Spec.close_code_in(payload), Spec.close_reason_in(payload)) : S.Transition}, some_none(1002, v))

def conv_v(+payload: List<&2, U32>, v: {Spec.control_fault(True{}, payload, Spec.close_fault(payload)) == None{} : Maybe<&2, U32>}) -> {Spec.when(Bool.not(Nat.is_le(F.length(payload), 125n)), 1002, Spec.close_fault(payload)) == None{} : Maybe<&2, U32>}:
  %Equal.sym(Bool, Nat.is_le(F.length(payload), 125n), Spec.small(payload), MP.control_small(payload)) : {Spec.when(Bool.not(_), 1002, Spec.close_fault(payload)) == None{} : Maybe<&2, U32>}
  v

def close_at(+max: U32, a: M.State, p: S.Phase, +payload: List<&2, U32>, +v: {Spec.control_fault(True{}, payload, Spec.close_fault(payload)) == None{} : Maybe<&2, U32>}, ok: {TP.live(S.Session{p, a}) == True{} : Bool}) -> {S.step(max, S.Session{p, a}, S.Inbound{F.Frame{True{}, F.OpClose{}, payload}}) == Spec.close_reply(S.Session{p, a}, payload) : S.Transition}:
  match a:
    case M.Idle{}: ctl_c(Nat.is_le(F.length(payload), 125n), p, M.Idle{}, payload, conv_v(payload, v))
    case M.Collecting{+t, +r, +b}: ctl_c(Nat.is_le(F.length(payload), 125n), p, M.Collecting{t, r, b}, payload, conv_v(payload, v))
    case M.Ended{}:
      match p:
        case S.WsDone{}: {==}
        case S.WsOpen{}: absurd({S.step(max, S.Session{S.WsOpen{}, M.Ended{}}, S.Inbound{F.Frame{True{}, F.OpClose{}, payload}}) == Spec.close_reply(S.Session{S.WsOpen{}, M.Ended{}}, payload) : S.Transition}, TP.false_true(ok))
        case S.WsClosing{}: absurd({S.step(max, S.Session{S.WsClosing{}, M.Ended{}}, S.Inbound{F.Frame{True{}, F.OpClose{}, payload}}) == Spec.close_reply(S.Session{S.WsClosing{}, M.Ended{}}, payload) : S.Transition}, TP.false_true(ok))

def close_live(+max: U32, s: S.Session, +payload: List<&2, U32>, +v: {Spec.control_fault(True{}, payload, Spec.close_fault(payload)) == None{} : Maybe<&2, U32>}, ok: {TP.live(s) == True{} : Bool}) -> {S.step(max, s, S.Inbound{F.Frame{True{}, F.OpClose{}, payload}}) == Spec.close_reply(s, payload) : S.Transition}:
  match s:
    case S.Session{p, a}: close_at(max, a, p, payload, v, ok)

def L.ws_session_trace_close(max, events, payload, valid):
  close_live(max, S.settle(max, events, S.opened()), payload, valid, TP.settle_live(max, events, S.opened(), {==}))

def L.ws_session_close_empty(max, events):
  L.ws_session_trace_close(max, events, [], {==})

def intr_b(ok: Bool, +text: Bool, +first: List<&2, U32>, +max: U32, +payload: List<&2, U32>, +valid: {Spec.control_fault(True{}, payload, Spec.close_fault(payload)) == None{} : Maybe<&2, U32>}, h: {ok == True{} : Bool}) -> {S.step(max, S.after(S.assembled(S.WsOpen{}, M.keep(ok, text, False{}, [], U32.to_nat(max), F.length(first), first))), S.Inbound{F.Frame{True{}, F.OpClose{}, payload}}) == Spec.close_finish(S.WsOpen{}, Spec.close_code_in(payload), Spec.close_reason_in(payload)) : S.Transition}:
  match ok:
    case True{}: close_at(max, M.Collecting{text, M.rev_onto(first, []), Nat.sub(U32.to_nat(max), F.length(first))}, S.WsOpen{}, payload, valid, {==})
    case False{}: absurd({S.step(max, S.after(S.assembled(S.WsOpen{}, M.keep(False{}, text, False{}, [], U32.to_nat(max), F.length(first), first))), S.Inbound{F.Frame{True{}, F.OpClose{}, payload}}) == Spec.close_finish(S.WsOpen{}, Spec.close_code_in(payload), Spec.close_reason_in(payload)) : S.Transition}, TP.false_true(h))

def L.ws_session_close_interrupts(max, text, first, fits, payload, valid):
  match text:
    case True{}: intr_b(Nat.is_le(F.length(first), U32.to_nat(max)), True{}, first, max, payload, valid, Equal.trans(Bool, Nat.is_le(F.length(first), U32.to_nat(max)), Spec.fits(max, first), True{}, MP.first_fits(first, max), fits))
    case False{}: intr_b(Nat.is_le(F.length(first), U32.to_nat(max)), False{}, first, max, payload, valid, Equal.trans(Bool, Nat.is_le(F.length(first), U32.to_nat(max)), Spec.fits(max, first), True{}, MP.first_fits(first, max), fits))
