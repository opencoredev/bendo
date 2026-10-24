# Proofs of the BND-52 laws on where a message leaves the session. Does not
# import LAWS.bend.
import Base
import ./ws-session-laws.bend as L
import ./ws-session-spec.bend as Spec
import ./ws-session-message.bend as MP
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

def some_none(-x: U32, e: {Some{x} == None{} : Maybe<&2, U32>}) -> Empty:
  %Equal.sym(Maybe<&2, U32>, Some{x}, None{}, e) : none_type(_)
  Unit{}

# ---- A done session stays done ----

def done_settle(+max: U32, es: List<&2, S.WsEvent>) -> {S.settle(max, es, Spec.ended()) == Spec.ended() : S.Session}:
  match es:
    case Nil{}: {==}
    case e <> +rest:
      match e:
        case S.Inbound{f}: done_settle(max, rest)
        case S.Outbound{c}: done_settle(max, rest)
        case S.Rejected{c}: done_settle(max, rest)
        case S.Dropped{}: done_settle(max, rest)

# ---- The final fragment ----

def td_end(m: Maybe<&2, String>) -> {S.after(S.assembled(S.WsOpen{}, M.text_done(m))) == Spec.text_end(m) : S.Session}:
  match m:
    case None{}: {==}
    case Some{t}: {==}

def delivered_end_eq(text: Bool, +d: List<&2, U32>) -> {S.after(S.assembled(S.WsOpen{}, M.complete(text, d))) == Spec.delivered_end(text, d) : S.Session}:
  match text:
    case True{}: td_end(Utf8.decode(d))
    case False{}: {==}

def final_be(+text: Bool, +last: List<&2, U32>, +seen: List<&2, U32>, +r: List<&2, U32>, +hr: {List.reverse(&2, U32, r) == seen : List<&2, U32>}, ok: Bool, +bud: Nat) -> {S.after(S.assembled(S.WsOpen{}, M.keep(ok, text, True{}, r, bud, F.length(last), last))) == Spec.choose(ok, Spec.delivered_end(text, List.append(&2, U32, seen, last)), Spec.ended()) : S.Session}:
  match ok:
    case False{}: {==}
    case True{}:
      %Equal.sym(List<&2, U32>, List.reverse(&2, U32, M.rev_onto(last, r)), List.append(&2, U32, seen, last), MP.rev_next(last, r, seen, hr)) : {S.after(S.assembled(S.WsOpen{}, M.complete(text, _))) == Spec.delivered_end(text, List.append(&2, U32, seen, last)) : S.Session}
      delivered_end_eq(text, List.append(&2, U32, seen, last))

def final_ae(+max: U32, +text: Bool, +last: List<&2, U32>, +seen: List<&2, U32>, +r: List<&2, U32>, +bud: Nat, +hr: {List.reverse(&2, U32, r) == seen : List<&2, U32>}, +hb: {bud == Nat.sub(U32.to_nat(max), List.length(&2, U32, seen)) : Nat}, +hf: {Nat.is_le(List.length(&2, U32, seen), U32.to_nat(max)) == True{} : Bool}) -> {S.after(S.assembled(S.WsOpen{}, M.keep(Nat.is_le(F.length(last), bud), text, True{}, r, bud, F.length(last), last))) == Spec.finale_end(max, text, List.append(&2, U32, seen, last)) : S.Session}:
  %MP.budget_fits(last, seen, bud, max, hb, hf) : {S.after(S.assembled(S.WsOpen{}, M.keep(Nat.is_le(F.length(last), bud), text, True{}, r, bud, F.length(last), last))) == Spec.choose(_, Spec.delivered_end(text, List.append(&2, U32, seen, last)), Spec.ended()) : S.Session}
  final_be(text, last, seen, r, hr, Nat.is_le(F.length(last), bud), bud)

# ---- Interleaved control frames ----

def ctl_be(ping: Bool, ok: Bool, +max: U32, +text: Bool, +b: List<&2, U32>, +rest: List<&2, Spec.Piece>, +last: List<&2, U32>, +seen: List<&2, U32>, +r: List<&2, U32>, +bud: Nat, ih: {S.settle(max, Spec.tail_events(rest, last), S.Session{S.WsOpen{}, M.Collecting{text, r, bud}}) == Spec.expect_end(max, text, rest, seen, last) : S.Session}) -> {S.settle(max, Spec.tail_events(rest, last), S.after(S.assembled(S.WsOpen{}, M.control_step(ok, M.Collecting{text, r, bud}, Spec.control_op(ping), b)))) == Spec.choose(ok, Spec.expect_end(max, text, rest, seen, last), Spec.ended()) : S.Session}:
  match ping:
    case True{}:
      match ok:
        case True{}: ih
        case False{}: done_settle(max, Spec.tail_events(rest, last))
    case False{}:
      match ok:
        case True{}: ih
        case False{}: done_settle(max, Spec.tail_events(rest, last))

def ctl_ae(+ping: Bool, +max: U32, +text: Bool, +b: List<&2, U32>, +rest: List<&2, Spec.Piece>, +last: List<&2, U32>, +seen: List<&2, U32>, +r: List<&2, U32>, +bud: Nat, ih: {S.settle(max, Spec.tail_events(rest, last), S.Session{S.WsOpen{}, M.Collecting{text, r, bud}}) == Spec.expect_end(max, text, rest, seen, last) : S.Session}) -> {S.settle(max, Spec.tail_events(rest, last), S.after(S.assembled(S.WsOpen{}, M.control_step(Nat.is_le(F.length(b), 125n), M.Collecting{text, r, bud}, Spec.control_op(ping), b)))) == Spec.choose(Spec.small(b), Spec.expect_end(max, text, rest, seen, last), Spec.ended()) : S.Session}:
  %MP.control_small(b) : {S.settle(max, Spec.tail_events(rest, last), S.after(S.assembled(S.WsOpen{}, M.control_step(Nat.is_le(F.length(b), 125n), M.Collecting{text, r, bud}, Spec.control_op(ping), b)))) == Spec.choose(_, Spec.expect_end(max, text, rest, seen, last), Spec.ended()) : S.Session}
  ctl_be(ping, Nat.is_le(F.length(b), 125n), max, text, b, rest, last, seen, r, bud, ih)

# ---- Non-final continuations ----

def mid_be(ok: Bool, +max: U32, +text: Bool, +b: List<&2, U32>, +rest: List<&2, Spec.Piece>, +last: List<&2, U32>, +seen: List<&2, U32>, +r: List<&2, U32>, +bud: Nat, +hr: {List.reverse(&2, U32, r) == seen : List<&2, U32>}, +hb: {bud == Nat.sub(U32.to_nat(max), List.length(&2, U32, seen)) : Nat}, fit: {Spec.fits(max, List.append(&2, U32, seen, b)) == ok : Bool}, ih: {List.reverse(&2, U32, M.rev_onto(b, r)) == List.append(&2, U32, seen, b) : List<&2, U32>} -> {Nat.sub(bud, F.length(b)) == Nat.sub(U32.to_nat(max), List.length(&2, U32, List.append(&2, U32, seen, b))) : Nat} -> {Nat.is_le(List.length(&2, U32, List.append(&2, U32, seen, b)), U32.to_nat(max)) == True{} : Bool} -> {S.settle(max, Spec.tail_events(rest, last), S.Session{S.WsOpen{}, M.Collecting{text, M.rev_onto(b, r), Nat.sub(bud, F.length(b))}}) == Spec.expect_end(max, text, rest, List.append(&2, U32, seen, b), last) : S.Session}) -> {S.settle(max, Spec.tail_events(rest, last), S.after(S.assembled(S.WsOpen{}, M.keep(ok, text, False{}, r, bud, F.length(b), b)))) == Spec.choose(ok, Spec.expect_end(max, text, rest, List.append(&2, U32, seen, b), last), Spec.ended()) : S.Session}:
  match ok:
    case True{}: ih(MP.rev_next(b, r, seen, hr), MP.budget_next(b, seen, bud, max, hb), fit)
    case False{}: done_settle(max, Spec.tail_events(rest, last))

def mid_ae(+max: U32, +text: Bool, +b: List<&2, U32>, +rest: List<&2, Spec.Piece>, +last: List<&2, U32>, +seen: List<&2, U32>, +r: List<&2, U32>, +bud: Nat, +hr: {List.reverse(&2, U32, r) == seen : List<&2, U32>}, +hb: {bud == Nat.sub(U32.to_nat(max), List.length(&2, U32, seen)) : Nat}, +hf: {Nat.is_le(List.length(&2, U32, seen), U32.to_nat(max)) == True{} : Bool}, ih: {List.reverse(&2, U32, M.rev_onto(b, r)) == List.append(&2, U32, seen, b) : List<&2, U32>} -> {Nat.sub(bud, F.length(b)) == Nat.sub(U32.to_nat(max), List.length(&2, U32, List.append(&2, U32, seen, b))) : Nat} -> {Nat.is_le(List.length(&2, U32, List.append(&2, U32, seen, b)), U32.to_nat(max)) == True{} : Bool} -> {S.settle(max, Spec.tail_events(rest, last), S.Session{S.WsOpen{}, M.Collecting{text, M.rev_onto(b, r), Nat.sub(bud, F.length(b))}}) == Spec.expect_end(max, text, rest, List.append(&2, U32, seen, b), last) : S.Session}) -> {S.settle(max, Spec.tail_events(rest, last), S.after(S.assembled(S.WsOpen{}, M.keep(Nat.is_le(F.length(b), bud), text, False{}, r, bud, F.length(b), b)))) == Spec.choose(Spec.fits(max, List.append(&2, U32, seen, b)), Spec.expect_end(max, text, rest, List.append(&2, U32, seen, b), last), Spec.ended()) : S.Session}:
  %MP.budget_fits(b, seen, bud, max, hb, hf) : {S.settle(max, Spec.tail_events(rest, last), S.after(S.assembled(S.WsOpen{}, M.keep(Nat.is_le(F.length(b), bud), text, False{}, r, bud, F.length(b), b)))) == Spec.choose(_, Spec.expect_end(max, text, rest, List.append(&2, U32, seen, b), last), Spec.ended()) : S.Session}
  mid_be(Nat.is_le(F.length(b), bud), max, text, b, rest, last, seen, r, bud, hr, hb, Equal.sym(Bool, Nat.is_le(F.length(b), bud), Spec.fits(max, List.append(&2, U32, seen, b)), MP.budget_fits(b, seen, bud, max, hb, hf)), ih)

# ---- The whole message, by induction on the pieces ----

def collecting_e(+max: U32, +text: Bool, pieces: List<&2, Spec.Piece>, +last: List<&2, U32>, +seen: List<&2, U32>, +r: List<&2, U32>, +bud: Nat, +hr: {List.reverse(&2, U32, r) == seen : List<&2, U32>}, +hb: {bud == Nat.sub(U32.to_nat(max), List.length(&2, U32, seen)) : Nat}, +hf: {Nat.is_le(List.length(&2, U32, seen), U32.to_nat(max)) == True{} : Bool}) -> {S.settle(max, Spec.tail_events(pieces, last), S.Session{S.WsOpen{}, M.Collecting{text, r, bud}}) == Spec.expect_end(max, text, pieces, seen, last) : S.Session}:
  match pieces:
    case Nil{}: final_ae(max, text, last, seen, r, bud, hr, hb, hf)
    case Spec.Interleaved{ping, +b} <> +rest:
      match ping:
        case True{}: ctl_ae(True{}, max, text, b, rest, last, seen, r, bud, collecting_e(max, text, rest, last, seen, r, bud, hr, hb, hf))
        case False{}: ctl_ae(False{}, max, text, b, rest, last, seen, r, bud, collecting_e(max, text, rest, last, seen, r, bud, hr, hb, hf))
    case Spec.Middle{+b} <> +rest:
      mid_ae(max, text, b, rest, last, seen, r, bud, hr, hb, hf, h1 => h2 => h3 => collecting_e(max, text, rest, last, List.append(&2, U32, seen, b), M.rev_onto(b, r), Nat.sub(bud, F.length(b)), h1, h2, h3))

def open_be(ok: Bool, +max: U32, +text: Bool, +first: List<&2, U32>, +pieces: List<&2, Spec.Piece>, +last: List<&2, U32>, fit: {Spec.fits(max, first) == ok : Bool}) -> {S.settle(max, Spec.tail_events(pieces, last), S.after(S.assembled(S.WsOpen{}, M.keep(ok, text, False{}, [], U32.to_nat(max), F.length(first), first)))) == Spec.choose(ok, Spec.expect_end(max, text, pieces, first, last), Spec.ended()) : S.Session}:
  match ok:
    case True{}: collecting_e(max, text, pieces, last, first, M.rev_onto(first, []), Nat.sub(U32.to_nat(max), F.length(first)), MP.rev_rev(first, []), MP.first_budget(first, max), fit)
    case False{}: done_settle(max, Spec.tail_events(pieces, last))

def open_ae(+max: U32, +text: Bool, +first: List<&2, U32>, +pieces: List<&2, Spec.Piece>, +last: List<&2, U32>) -> {S.settle(max, Spec.tail_events(pieces, last), S.after(S.assembled(S.WsOpen{}, M.keep(Nat.is_le(F.length(first), U32.to_nat(max)), text, False{}, [], U32.to_nat(max), F.length(first), first)))) == Spec.expected_end(max, text, first, pieces, last) : S.Session}:
  %MP.first_fits(first, max) : {S.settle(max, Spec.tail_events(pieces, last), S.after(S.assembled(S.WsOpen{}, M.keep(Nat.is_le(F.length(first), U32.to_nat(max)), text, False{}, [], U32.to_nat(max), F.length(first), first)))) == Spec.choose(_, Spec.expect_end(max, text, pieces, first, last), Spec.ended()) : S.Session}
  open_be(Nat.is_le(F.length(first), U32.to_nat(max)), max, text, first, pieces, last, Equal.sym(Bool, Nat.is_le(F.length(first), U32.to_nat(max)), Spec.fits(max, first), MP.first_fits(first, max)))

def L.ws_session_fragments_end(max, text, first, pieces, last):
  match text:
    case True{}: open_ae(max, True{}, first, pieces, last)
    case False{}: open_ae(max, False{}, first, pieces, last)

def single_ae(+max: U32, +text: Bool, +payload: List<&2, U32>) -> {S.after(S.assembled(S.WsOpen{}, M.keep(Nat.is_le(F.length(payload), U32.to_nat(max)), text, True{}, [], U32.to_nat(max), F.length(payload), payload))) == Spec.finale_end(max, text, payload) : S.Session}:
  %MP.first_fits(payload, max) : {S.after(S.assembled(S.WsOpen{}, M.keep(Nat.is_le(F.length(payload), U32.to_nat(max)), text, True{}, [], U32.to_nat(max), F.length(payload), payload))) == Spec.choose(_, Spec.delivered_end(text, payload), Spec.ended()) : S.Session}
  final_be(text, payload, [], [], {==}, Nat.is_le(F.length(payload), U32.to_nat(max)), U32.to_nat(max))

def L.ws_session_single_message_end(max, text, payload):
  match text:
    case True{}: single_ae(max, True{}, payload)
    case False{}: single_ae(max, False{}, payload)

# ---- A delivered message leaves the session ready ----

def td_ready(m: Maybe<&2, String>, ok: {Spec.utf8_result(m) == None{} : Maybe<&2, U32>}) -> {S.assembled(S.WsOpen{}, M.text_done(m)) == S.Transition{M.Idle{}, S.Action{S.WsOpen{}, None{}, S.WsMessage{M.TextMessage{Spec.text_or_empty(m)}}}} : S.Transition}:
  match m:
    case None{}: absurd({S.assembled(S.WsOpen{}, M.text_done(None{})) == S.Transition{M.Idle{}, S.Action{S.WsOpen{}, None{}, S.WsMessage{M.TextMessage{Spec.text_or_empty(None{})}}}} : S.Transition}, some_none(1007, ok))
    case Some{t}: {==}

def complete_ready(text: Bool, +payload: List<&2, U32>, ok: {Spec.utf8_fault(text, payload) == None{} : Maybe<&2, U32>}) -> {S.assembled(S.WsOpen{}, M.complete(text, payload)) == S.Transition{M.Idle{}, S.Action{S.WsOpen{}, None{}, S.WsMessage{Spec.message_of(text, payload)}}} : S.Transition}:
  match text:
    case True{}: td_ready(Utf8.decode(payload), ok)
    case False{}: {==}

def ready_b(ok: Bool, +text: Bool, +payload: List<&2, U32>, +max: U32, valid: {Spec.utf8_fault(text, payload) == None{} : Maybe<&2, U32>}, h: {ok == True{} : Bool}) -> {S.assembled(S.WsOpen{}, M.keep(ok, text, True{}, [], U32.to_nat(max), F.length(payload), payload)) == S.Transition{M.Idle{}, S.Action{S.WsOpen{}, None{}, S.WsMessage{Spec.message_of(text, payload)}}} : S.Transition}:
  match ok:
    case True{}:
      %Equal.sym(List<&2, U32>, List.reverse(&2, U32, M.rev_onto(payload, [])), payload, MP.rev_rev(payload, [])) : {S.assembled(S.WsOpen{}, M.complete(text, _)) == S.Transition{M.Idle{}, S.Action{S.WsOpen{}, None{}, S.WsMessage{Spec.message_of(text, payload)}}} : S.Transition}
      complete_ready(text, payload, valid)
    case False{}: absurd({S.assembled(S.WsOpen{}, M.keep(False{}, text, True{}, [], U32.to_nat(max), F.length(payload), payload)) == S.Transition{M.Idle{}, S.Action{S.WsOpen{}, None{}, S.WsMessage{Spec.message_of(text, payload)}}} : S.Transition}, MP.false_true(h))

def L.ws_session_message_ready(max, text, payload, fits, valid):
  match text:
    case True{}: ready_b(Nat.is_le(F.length(payload), U32.to_nat(max)), True{}, payload, max, valid, Equal.trans(Bool, Nat.is_le(F.length(payload), U32.to_nat(max)), Spec.fits(max, payload), True{}, MP.first_fits(payload, max), fits))
    case False{}: ready_b(Nat.is_le(F.length(payload), U32.to_nat(max)), False{}, payload, max, valid, Equal.trans(Bool, Nat.is_le(F.length(payload), U32.to_nat(max)), Spec.fits(max, payload), True{}, MP.first_fits(payload, max), fits))
