# Proofs of the BND-52 trace laws over S.step. Does not import LAWS.bend.
import Base
import ./ws-session-laws.bend as L
import ./ws-session-spec.bend as Spec
import ./ws-frame.bend as WF
import ../src/ws/session.bend as S
import ../src/ws/frame.bend as F
import ../src/ws/message.bend as M
import ../src/data/utf8.bend as Utf8

def absurd(-A: Type, e: Empty) -> A:
  match e:

def false_true(e: {False{} == True{} : Bool}) -> Empty:
  %e : Bool.pick(Type, _, Empty, Unit)
  Unit{}

def L.ws_session_abrupt_closing(): {==}
def L.ws_session_abrupt_done(): {==}

def L.ws_session_abrupt_any(max, phase, assembly):
  match phase:
    case S.WsOpen{}: {==}
    case S.WsClosing{}: {==}
    case S.WsDone{}: {==}

# ---- Trace safety: done, then closing, then open ----

def done_in(+max: U32, +rest: List<&2, S.WsEvent>, +c: Bool, r: M.Advance, ih: @st: M.State -> {Spec.watch(S.trace(max, rest, S.Session{S.WsDone{}, st}), Bool.or(c, False{}), True{}) == True{} : Bool}) -> {Spec.watch(S.action_of(S.assembled(S.WsDone{}, r)) <> S.trace(max, rest, S.after(S.assembled(S.WsDone{}, r))), c, True{}) == True{} : Bool}:
  match r:
    case M.Advance{st, M.Absorbed{}}: ih(st)
    case M.Advance{st, M.Deliver{m}}: ih(st)
    case M.Advance{st, M.Failed{code}}: ih(st)

def done_event(+max: U32, +a: M.State, e: S.WsEvent, +rest: List<&2, S.WsEvent>, +c: Bool, ih: @st: M.State -> {Spec.watch(S.trace(max, rest, S.Session{S.WsDone{}, st}), Bool.or(c, False{}), True{}) == True{} : Bool}) -> {Spec.watch(S.trace(max, e <> rest, S.Session{S.WsDone{}, a}), c, True{}) == True{} : Bool}:
  match e:
    case S.Inbound{f}: done_in(max, rest, c, M.step(max, a, f), ih)
    case S.Outbound{command}: ih(a)
    case S.Rejected{code}: ih(a)
    case S.Dropped{}: ih(a)

def done_safe(+max: U32, es: List<&2, S.WsEvent>, +a: M.State, +c: Bool) -> {Spec.watch(S.trace(max, es, S.Session{S.WsDone{}, a}), c, True{}) == True{} : Bool}:
  match es:
    case Nil{}: {==}
    case +e <> +rest: done_event(max, a, e, rest, c, st => done_safe(max, rest, st, Bool.or(c, False{})))

def closing_deliver(+max: U32, +rest: List<&2, S.WsEvent>, +st: M.State, m: M.Message, ih: @st: M.State -> {Spec.watch(S.trace(max, rest, S.Session{S.WsClosing{}, st}), True{}, False{}) == True{} : Bool}) -> {Spec.watch(S.action_of(S.assembled(S.WsClosing{}, M.Advance{st, M.Deliver{m}})) <> S.trace(max, rest, S.after(S.assembled(S.WsClosing{}, M.Advance{st, M.Deliver{m}}))), True{}, False{}) == True{} : Bool}:
  match m:
    case M.CloseMessage{code, reason}: done_safe(max, rest, st, True{})
    case M.PingMessage{b}: ih(st)
    case M.PongMessage{b}: ih(st)
    case M.TextMessage{t}: ih(st)
    case M.BinaryMessage{b}: ih(st)

def closing_in(+max: U32, +rest: List<&2, S.WsEvent>, r: M.Advance, ih: @st: M.State -> {Spec.watch(S.trace(max, rest, S.Session{S.WsClosing{}, st}), True{}, False{}) == True{} : Bool}) -> {Spec.watch(S.action_of(S.assembled(S.WsClosing{}, r)) <> S.trace(max, rest, S.after(S.assembled(S.WsClosing{}, r))), True{}, False{}) == True{} : Bool}:
  match r:
    case M.Advance{st, M.Absorbed{}}: ih(st)
    case M.Advance{st, M.Deliver{m}}: closing_deliver(max, rest, st, m, ih)
    case M.Advance{st, M.Failed{code}}: done_safe(max, rest, st, True{})

def closing_event(+max: U32, +a: M.State, e: S.WsEvent, +rest: List<&2, S.WsEvent>, ih: @st: M.State -> {Spec.watch(S.trace(max, rest, S.Session{S.WsClosing{}, st}), True{}, False{}) == True{} : Bool}) -> {Spec.watch(S.trace(max, e <> rest, S.Session{S.WsClosing{}, a}), True{}, False{}) == True{} : Bool}:
  match e:
    case S.Inbound{f}: closing_in(max, rest, M.step(max, a, f), ih)
    case S.Outbound{command}: ih(a)
    case S.Rejected{code}: done_safe(max, rest, a, True{})
    case S.Dropped{}: done_safe(max, rest, a, True{})

def closing_safe(+max: U32, es: List<&2, S.WsEvent>, +a: M.State) -> {Spec.watch(S.trace(max, es, S.Session{S.WsClosing{}, a}), True{}, False{}) == True{} : Bool}:
  match es:
    case Nil{}: {==}
    case +e <> +rest: closing_event(max, a, e, rest, st => closing_safe(max, rest, st))

def open_deliver(+max: U32, +rest: List<&2, S.WsEvent>, +st: M.State, m: M.Message, ih: @st: M.State -> {Spec.watch(S.trace(max, rest, S.Session{S.WsOpen{}, st}), False{}, False{}) == True{} : Bool}) -> {Spec.watch(S.action_of(S.assembled(S.WsOpen{}, M.Advance{st, M.Deliver{m}})) <> S.trace(max, rest, S.after(S.assembled(S.WsOpen{}, M.Advance{st, M.Deliver{m}}))), False{}, False{}) == True{} : Bool}:
  match m:
    case M.CloseMessage{code, reason}: done_safe(max, rest, st, True{})
    case M.PingMessage{b}: ih(st)
    case M.PongMessage{b}: ih(st)
    case M.TextMessage{t}: ih(st)
    case M.BinaryMessage{b}: ih(st)

def open_in(+max: U32, +rest: List<&2, S.WsEvent>, r: M.Advance, ih: @st: M.State -> {Spec.watch(S.trace(max, rest, S.Session{S.WsOpen{}, st}), False{}, False{}) == True{} : Bool}) -> {Spec.watch(S.action_of(S.assembled(S.WsOpen{}, r)) <> S.trace(max, rest, S.after(S.assembled(S.WsOpen{}, r))), False{}, False{}) == True{} : Bool}:
  match r:
    case M.Advance{st, M.Absorbed{}}: ih(st)
    case M.Advance{st, M.Deliver{m}}: open_deliver(max, rest, st, m, ih)
    case M.Advance{st, M.Failed{code}}: done_safe(max, rest, st, True{})

def open_command(+max: U32, +a: M.State, command: S.Command, +rest: List<&2, S.WsEvent>, ih: @st: M.State -> {Spec.watch(S.trace(max, rest, S.Session{S.WsOpen{}, st}), False{}, False{}) == True{} : Bool}) -> {Spec.watch(S.trace(max, S.Outbound{command} <> rest, S.Session{S.WsOpen{}, a}), False{}, False{}) == True{} : Bool}:
  match command:
    case S.SendText{t}: ih(a)
    case S.SendBinary{b}: ih(a)
    case S.SendPing{b}: ih(a)
    case S.SendClose{code, reason}: closing_safe(max, rest, a)

def open_event(+max: U32, +a: M.State, e: S.WsEvent, +rest: List<&2, S.WsEvent>, ih: @st: M.State -> {Spec.watch(S.trace(max, rest, S.Session{S.WsOpen{}, st}), False{}, False{}) == True{} : Bool}) -> {Spec.watch(S.trace(max, e <> rest, S.Session{S.WsOpen{}, a}), False{}, False{}) == True{} : Bool}:
  match e:
    case S.Inbound{f}: open_in(max, rest, M.step(max, a, f), ih)
    case S.Outbound{command}: open_command(max, a, command, rest, ih)
    case S.Rejected{code}: done_safe(max, rest, a, True{})
    case S.Dropped{}: done_safe(max, rest, a, False{})

def open_safe(+max: U32, es: List<&2, S.WsEvent>, +a: M.State) -> {Spec.watch(S.trace(max, es, S.Session{S.WsOpen{}, a}), False{}, False{}) == True{} : Bool}:
  match es:
    case Nil{}: {==}
    case +e <> +rest: open_event(max, a, e, rest, st => open_safe(max, rest, st))

def L.ws_session_trace_safe(max, events):
  open_safe(max, events, M.Idle{})

# ---- Reachable sessions: the assembler ends only when the session does ----

def is_done(p: S.Phase) -> Bool:
  match p:
    case S.WsDone{}: True{}
    case S.WsOpen{}: False{}
    case S.WsClosing{}: False{}

def live_go(a: M.State, p: S.Phase) -> Bool:
  match a:
    case M.Ended{}: is_done(p)
    case M.Idle{}: True{}
    case M.Collecting{t, r, b}: True{}

def live(s: S.Session) -> Bool:
  match s:
    case S.Session{p, a}: live_go(a, p)

def fail_live(p: S.Phase, +code: U32) -> {live(S.after(S.assembled(p, M.fail(code)))) == True{} : Bool}:
  match p:
    case S.WsOpen{}: {==}
    case S.WsClosing{}: {==}
    case S.WsDone{}: {==}

def text_done_live(+p: S.Phase, m: Maybe<&2, String>) -> {live(S.after(S.assembled(p, M.text_done(m)))) == True{} : Bool}:
  match m:
    case None{}: fail_live(p, M.invalid_payload())
    case Some{t}: {==}

def complete_live(+p: S.Phase, text: Bool, +data: List<&2, U32>) -> {live(S.after(S.assembled(p, M.complete(text, data)))) == True{} : Bool}:
  match text:
    case True{}: text_done_live(p, Utf8.decode(data))
    case False{}: {==}

def keep_live(+p: S.Phase, fits: Bool, +text: Bool, fin: Bool, +rev: List<&2, U32>, +budget: Nat, +n: Nat, +payload: List<&2, U32>) -> {live(S.after(S.assembled(p, M.keep(fits, text, fin, rev, budget, n, payload)))) == True{} : Bool}:
  match fits:
    case False{}: fail_live(p, F.too_big())
    case True{}:
      match fin:
        case True{}: complete_live(p, text, List.reverse(&2, U32, M.rev_onto(payload, rev)))
        case False{}: {==}

def close_reason_live(p: S.Phase, +code: U32, reason: Maybe<&2, String>) -> {live(S.after(S.assembled(p, M.close_reason(code, reason)))) == True{} : Bool}:
  match p:
    case S.WsOpen{}:
      match reason:
        case None{}: fail_live(S.WsOpen{}, M.invalid_payload())
        case Some{text}: {==}
    case S.WsClosing{}:
      match reason:
        case None{}: fail_live(S.WsClosing{}, M.invalid_payload())
        case Some{text}: {==}
    case S.WsDone{}:
      match reason:
        case None{}: fail_live(S.WsDone{}, M.invalid_payload())
        case Some{text}: {==}

def close_coded_live(+p: S.Phase, ok: Bool, +code: U32, +reason: List<&2, U32>) -> {live(S.after(S.assembled(p, M.close_coded(ok, code, reason)))) == True{} : Bool}:
  match ok:
    case False{}: fail_live(p, F.protocol_error())
    case True{}: close_reason_live(p, code, Utf8.decode(reason))

def close_live(p: S.Phase, payload: List<&2, U32>) -> {live(S.after(S.assembled(p, M.close(payload)))) == True{} : Bool}:
  match p:
    case S.WsOpen{}:
      match payload:
        case Nil{}: {==}
        case +x <> t:
          match t:
            case Nil{}: fail_live(S.WsOpen{}, F.protocol_error())
            case +y <> r: close_coded_live(S.WsOpen{}, F.is_octet(x) && F.is_octet(y) && M.code_ok((x * 256 + y : U32)), (x * 256 + y : U32), r)
    case S.WsClosing{}:
      match payload:
        case Nil{}: {==}
        case +x <> t:
          match t:
            case Nil{}: fail_live(S.WsClosing{}, F.protocol_error())
            case +y <> r: close_coded_live(S.WsClosing{}, F.is_octet(x) && F.is_octet(y) && M.code_ok((x * 256 + y : U32)), (x * 256 + y : U32), r)
    case S.WsDone{}:
      match payload:
        case Nil{}: {==}
        case +x <> t:
          match t:
            case Nil{}: fail_live(S.WsDone{}, F.protocol_error())
            case +y <> r: close_coded_live(S.WsDone{}, F.is_octet(x) && F.is_octet(y) && M.code_ok((x * 256 + y : U32)), (x * 256 + y : U32), r)

def cs_idle_live(+p: S.Phase, ok: Bool, op: F.Opcode, +payload: List<&2, U32>) -> {live(S.after(S.assembled(p, M.control_step(ok, M.Idle{}, op, payload)))) == True{} : Bool}:
  match ok:
    case False{}: fail_live(p, F.protocol_error())
    case True{}:
      match op:
        case F.OpClose{}: close_live(p, payload)
        case F.OpPing{}: {==}
        case F.OpPong{}: {==}
        case F.OpContinue{}: {==}
        case F.OpText{}: {==}
        case F.OpBinary{}: {==}

def cs_coll_live(+p: S.Phase, ok: Bool, +t: Bool, +r: List<&2, U32>, +b: Nat, op: F.Opcode, +payload: List<&2, U32>) -> {live(S.after(S.assembled(p, M.control_step(ok, M.Collecting{t, r, b}, op, payload)))) == True{} : Bool}:
  match ok:
    case False{}: fail_live(p, F.protocol_error())
    case True{}:
      match op:
        case F.OpClose{}: close_live(p, payload)
        case F.OpPing{}: {==}
        case F.OpPong{}: {==}
        case F.OpContinue{}: {==}
        case F.OpText{}: {==}
        case F.OpBinary{}: {==}

def data_idle_live(+p: S.Phase, +max: U32, kind: Maybe<&2, Bool>, +fin: Bool, +payload: List<&2, U32>) -> {live(S.after(S.assembled(p, M.data(max, M.Idle{}, kind, fin, payload)))) == True{} : Bool}:
  match kind:
    case Some{text}: keep_live(p, Nat.is_le(F.length(payload), U32.to_nat(max)), text, fin, [], U32.to_nat(max), F.length(payload), payload)
    case None{}: fail_live(p, F.protocol_error())

def data_coll_live(+p: S.Phase, +max: U32, +t: Bool, +r: List<&2, U32>, +b: Nat, kind: Maybe<&2, Bool>, +fin: Bool, +payload: List<&2, U32>) -> {live(S.after(S.assembled(p, M.data(max, M.Collecting{t, r, b}, kind, fin, payload)))) == True{} : Bool}:
  match kind:
    case Some{x}: fail_live(p, F.protocol_error())
    case None{}: keep_live(p, Nat.is_le(F.length(payload), b), t, fin, r, b, F.length(payload), payload)

def bk_idle_live(+p: S.Phase, control: Bool, +max: U32, +op: F.Opcode, +fin: Bool, +payload: List<&2, U32>) -> {live(S.after(S.assembled(p, M.by_kind(control, max, M.Idle{}, op, fin, payload)))) == True{} : Bool}:
  match control:
    case True{}: cs_idle_live(p, fin && Nat.is_le(F.length(payload), 125n), op, payload)
    case False{}: data_idle_live(p, max, M.data_kind(op), fin, payload)

def bk_coll_live(+p: S.Phase, control: Bool, +max: U32, +t: Bool, +r: List<&2, U32>, +b: Nat, +op: F.Opcode, +fin: Bool, +payload: List<&2, U32>) -> {live(S.after(S.assembled(p, M.by_kind(control, max, M.Collecting{t, r, b}, op, fin, payload)))) == True{} : Bool}:
  match control:
    case True{}: cs_coll_live(p, fin && Nat.is_le(F.length(payload), 125n), t, r, b, op, payload)
    case False{}: data_coll_live(p, max, t, r, b, M.data_kind(op), fin, payload)

def inb_idle_live(+p: S.Phase, +max: U32, f: F.Frame) -> {live(S.after(S.assembled(p, M.step(max, M.Idle{}, f)))) == True{} : Bool}:
  match f:
    case F.Frame{fin, +op, payload}: bk_idle_live(p, F.is_control(op), max, op, fin, payload)

def inb_coll_live(+p: S.Phase, +max: U32, +t: Bool, +r: List<&2, U32>, +b: Nat, f: F.Frame) -> {live(S.after(S.assembled(p, M.step(max, M.Collecting{t, r, b}, f)))) == True{} : Bool}:
  match f:
    case F.Frame{fin, +op, payload}: bk_coll_live(p, F.is_control(op), max, t, r, b, op, fin, payload)

def step_at(+max: U32, a: M.State, p: S.Phase, e: S.WsEvent, ok: {live(S.Session{p, a}) == True{} : Bool}) -> {live(S.after(S.step(max, S.Session{p, a}, e))) == True{} : Bool}:
  match a:
    case M.Idle{}:
      match e:
        case S.Inbound{f}: inb_idle_live(p, max, f)
        case S.Outbound{c}: {==}
        case S.Rejected{c}: {==}
        case S.Dropped{}: {==}
    case M.Collecting{t, r, b}:
      match e:
        case S.Inbound{f}: inb_coll_live(p, max, t, r, b, f)
        case S.Outbound{c}: {==}
        case S.Rejected{c}: {==}
        case S.Dropped{}: {==}
    case M.Ended{}:
      match p:
        case S.WsDone{}:
          match e:
            case S.Inbound{f}: {==}
            case S.Outbound{c}: {==}
            case S.Rejected{c}: {==}
            case S.Dropped{}: {==}
        case S.WsOpen{}: absurd({live(S.after(S.step(max, S.Session{S.WsOpen{}, M.Ended{}}, e))) == True{} : Bool}, false_true(ok))
        case S.WsClosing{}: absurd({live(S.after(S.step(max, S.Session{S.WsClosing{}, M.Ended{}}, e))) == True{} : Bool}, false_true(ok))

def step_live(+max: U32, s: S.Session, e: S.WsEvent, ok: {live(s) == True{} : Bool}) -> {live(S.after(S.step(max, s, e))) == True{} : Bool}:
  match s:
    case S.Session{p, a}: step_at(max, a, p, e, ok)

def settle_live(+max: U32, es: List<&2, S.WsEvent>, +s: S.Session, ok: {live(s) == True{} : Bool}) -> {live(S.settle(max, es, s)) == True{} : Bool}:
  match es:
    case Nil{}: ok
    case +e <> +rest: settle_live(max, rest, S.after(S.step(max, s, e)), step_live(max, s, e, ok))

def small_f(+payload: List<&2, U32>, small: {Nat.is_le(List.length(&2, U32, payload), 125n) == True{} : Bool}) -> {Nat.is_le(F.length(payload), 125n) == True{} : Bool}:
  %Equal.sym(Nat, F.length(payload), List.length(&2, U32, payload), WF.length_eq(payload)) : {Nat.is_le(_, 125n) == True{} : Bool}
  small

def ping_in(+p: S.Phase, +a: M.State, +payload: List<&2, U32>, ok: {Nat.is_le(F.length(payload), 125n) == True{} : Bool}) -> {S.assembled(p, M.control_step(Nat.is_le(F.length(payload), 125n), a, F.OpPing{}, payload)) == S.assembled(p, M.Advance{a, M.Deliver{M.PingMessage{payload}}}) : S.Transition}:
  %Equal.sym(Bool, Nat.is_le(F.length(payload), 125n), True{}, ok) : {S.assembled(p, M.control_step(_, a, F.OpPing{}, payload)) == S.assembled(p, M.Advance{a, M.Deliver{M.PingMessage{payload}}}) : S.Transition}
  {==}

def ping_at(+max: U32, a: M.State, p: S.Phase, +payload: List<&2, U32>, +small: {Nat.is_le(List.length(&2, U32, payload), 125n) == True{} : Bool}, ok: {live(S.Session{p, a}) == True{} : Bool}) -> {S.step(max, S.Session{p, a}, S.Inbound{F.Frame{True{}, F.OpPing{}, payload}}) == Spec.ping_reply(S.Session{p, a}, payload) : S.Transition}:
  match a:
    case M.Idle{}:
      match p:
        case S.WsOpen{}: ping_in(S.WsOpen{}, M.Idle{}, payload, small_f(payload, small))
        case S.WsClosing{}: ping_in(S.WsClosing{}, M.Idle{}, payload, small_f(payload, small))
        case S.WsDone{}: ping_in(S.WsDone{}, M.Idle{}, payload, small_f(payload, small))
    case M.Collecting{+t, +r, +b}:
      match p:
        case S.WsOpen{}: ping_in(S.WsOpen{}, M.Collecting{t, r, b}, payload, small_f(payload, small))
        case S.WsClosing{}: ping_in(S.WsClosing{}, M.Collecting{t, r, b}, payload, small_f(payload, small))
        case S.WsDone{}: ping_in(S.WsDone{}, M.Collecting{t, r, b}, payload, small_f(payload, small))
    case M.Ended{}:
      match p:
        case S.WsDone{}: {==}
        case S.WsOpen{}: absurd({S.step(max, S.Session{S.WsOpen{}, M.Ended{}}, S.Inbound{F.Frame{True{}, F.OpPing{}, payload}}) == Spec.ping_reply(S.Session{S.WsOpen{}, M.Ended{}}, payload) : S.Transition}, false_true(ok))
        case S.WsClosing{}: absurd({S.step(max, S.Session{S.WsClosing{}, M.Ended{}}, S.Inbound{F.Frame{True{}, F.OpPing{}, payload}}) == Spec.ping_reply(S.Session{S.WsClosing{}, M.Ended{}}, payload) : S.Transition}, false_true(ok))

def ping_live(+max: U32, s: S.Session, +payload: List<&2, U32>, +small: {Nat.is_le(List.length(&2, U32, payload), 125n) == True{} : Bool}, ok: {live(s) == True{} : Bool}) -> {S.step(max, s, S.Inbound{F.Frame{True{}, F.OpPing{}, payload}}) == Spec.ping_reply(s, payload) : S.Transition}:
  match s:
    case S.Session{p, a}: ping_at(max, a, p, payload, small, ok)

def L.ws_session_trace_ping(max, events, payload, small):
  ping_live(max, S.settle(max, events, S.opened()), payload, small, settle_live(max, events, S.opened(), {==}))
