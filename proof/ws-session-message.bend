# Proofs of the BND-52 message-assembly trace laws. Does not import LAWS.bend.
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

def cons_eq(-x: S.Action, -t1: List<&2, S.Action>, -t2: List<&2, S.Action>, e: {t1 == t2 : List<&2, S.Action>}) -> {x <> t1 == x <> t2 : List<&2, S.Action>}:
  %e : {x <> t1 == x <> _ : List<&2, S.Action>}
  {==}

# ---- Lists ----

def append_nil(+xs: List<&2, U32>) -> {List.append(&2, U32, xs, []) == xs : List<&2, U32>}:
  match xs:
    case Nil{}: {==}
    case +h <> +t:
      %append_nil(t) : {h <> List.append(&2, U32, t, []) == h <> _ : List<&2, U32>}
      {==}

def append_assoc(+xs: List<&2, U32>, +ys: List<&2, U32>, +zs: List<&2, U32>) -> {List.append(&2, U32, List.append(&2, U32, xs, ys), zs) == List.append(&2, U32, xs, List.append(&2, U32, ys, zs)) : List<&2, U32>}:
  match xs:
    case Nil{}: {==}
    case +h <> +t:
      %append_assoc(t, ys, zs) : {h <> List.append(&2, U32, List.append(&2, U32, t, ys), zs) == h <> _ : List<&2, U32>}
      {==}

def rgo(+r: List<&2, U32>, +acc: List<&2, U32>) -> {List.reverse.go(&2, U32, r, acc) == List.append(&2, U32, List.reverse(&2, U32, r), acc) : List<&2, U32>}:
  match r:
    case Nil{}: {==}
    case +h <> +t:
      %Equal.sym(List<&2, U32>, List.reverse.go(&2, U32, t, [h]), List.append(&2, U32, List.reverse(&2, U32, t), [h]), rgo(t, [h])) : {List.reverse.go(&2, U32, t, h <> acc) == List.append(&2, U32, _, acc) : List<&2, U32>}
      %Equal.sym(List<&2, U32>, List.append(&2, U32, List.append(&2, U32, List.reverse(&2, U32, t), [h]), acc), List.append(&2, U32, List.reverse(&2, U32, t), h <> acc), append_assoc(List.reverse(&2, U32, t), [h], acc)) : {List.reverse.go(&2, U32, t, h <> acc) == _ : List<&2, U32>}
      rgo(t, h <> acc)

# The assembler's reversed buffer, read back, is the message bytes in order.
def rev_rev(+b: List<&2, U32>, +r: List<&2, U32>) -> {List.reverse(&2, U32, M.rev_onto(b, r)) == List.append(&2, U32, List.reverse(&2, U32, r), b) : List<&2, U32>}:
  match b:
    case Nil{}: Equal.sym(List<&2, U32>, List.append(&2, U32, List.reverse(&2, U32, r), []), List.reverse(&2, U32, r), append_nil(List.reverse(&2, U32, r)))
    case +x <> +t:
      %append_assoc(List.reverse(&2, U32, r), [x], t) : {List.reverse(&2, U32, M.rev_onto(t, x <> r)) == _ : List<&2, U32>}
      %rgo(r, [x]) : {List.reverse(&2, U32, M.rev_onto(t, x <> r)) == List.append(&2, U32, _, t) : List<&2, U32>}
      rev_rev(t, x <> r)

def rev_next(+b: List<&2, U32>, +r: List<&2, U32>, +seen: List<&2, U32>, hr: {List.reverse(&2, U32, r) == seen : List<&2, U32>}) -> {List.reverse(&2, U32, M.rev_onto(b, r)) == List.append(&2, U32, seen, b) : List<&2, U32>}:
  %hr : {List.reverse(&2, U32, M.rev_onto(b, r)) == List.append(&2, U32, _, b) : List<&2, U32>}
  rev_rev(b, r)

# ---- The message budget ----

def sub_zero(+m: Nat) -> {Nat.sub(m, 0n) == m : Nat}:
  match m:
    case 0n: {==}
    case 1n+k: {==}

def sub_sub(l: Nat, +m: Nat, +n: Nat) -> {Nat.sub(Nat.sub(m, l), n) == Nat.sub(m, Nat.add(l, n)) : Nat}:
  match l:
    case 0n:
      %Equal.sym(Nat, Nat.sub(m, 0n), m, sub_zero(m)) : {Nat.sub(_, n) == Nat.sub(m, n) : Nat}
      {==}
    case 1n+k:
      match m:
        case 0n: {==}
        case 1n+j: sub_sub(k, j, n)

def le_sub(l: Nat, +m: Nat, +n: Nat, h: {Nat.is_le(l, m) == True{} : Bool}) -> {Nat.is_le(n, Nat.sub(m, l)) == Nat.is_le(Nat.add(l, n), m) : Bool}:
  match l:
    case 0n:
      %Equal.sym(Nat, Nat.sub(m, 0n), m, sub_zero(m)) : {Nat.is_le(n, _) == Nat.is_le(n, m) : Bool}
      {==}
    case 1n+k:
      match m:
        case 0n: absurd({Nat.is_le(n, Nat.sub(0n, 1n+k)) == Nat.is_le(Nat.add(1n+k, n), 0n) : Bool}, false_true(h))
        case 1n+j: le_sub(k, j, n, h)

# With `bud` bytes left of the message budget, a fragment fits exactly when the
# whole message so far, plus that fragment, fits max.
def budget_fits(+b: List<&2, U32>, +seen: List<&2, U32>, +bud: Nat, +max: U32, hb: {bud == Nat.sub(U32.to_nat(max), List.length(&2, U32, seen)) : Nat}, hf: {Nat.is_le(List.length(&2, U32, seen), U32.to_nat(max)) == True{} : Bool}) -> {Nat.is_le(F.length(b), bud) == Spec.fits(max, List.append(&2, U32, seen, b)) : Bool}:
  %Equal.sym(Nat, bud, Nat.sub(U32.to_nat(max), List.length(&2, U32, seen)), hb) : {Nat.is_le(F.length(b), _) == Spec.fits(max, List.append(&2, U32, seen, b)) : Bool}
  %Equal.sym(Nat, F.length(b), List.length(&2, U32, b), WF.length_eq(b)) : {Nat.is_le(_, Nat.sub(U32.to_nat(max), List.length(&2, U32, seen))) == Spec.fits(max, List.append(&2, U32, seen, b)) : Bool}
  %Equal.sym(Nat, List.length(&2, U32, List.append(&2, U32, seen, b)), Nat.add(List.length(&2, U32, seen), List.length(&2, U32, b)), WF.length_append(seen, b)) : {Nat.is_le(List.length(&2, U32, b), Nat.sub(U32.to_nat(max), List.length(&2, U32, seen))) == Nat.is_le(_, U32.to_nat(max)) : Bool}
  le_sub(List.length(&2, U32, seen), U32.to_nat(max), List.length(&2, U32, b), hf)

def budget_next(+b: List<&2, U32>, +seen: List<&2, U32>, +bud: Nat, +max: U32, hb: {bud == Nat.sub(U32.to_nat(max), List.length(&2, U32, seen)) : Nat}) -> {Nat.sub(bud, F.length(b)) == Nat.sub(U32.to_nat(max), List.length(&2, U32, List.append(&2, U32, seen, b))) : Nat}:
  %Equal.sym(Nat, bud, Nat.sub(U32.to_nat(max), List.length(&2, U32, seen)), hb) : {Nat.sub(_, F.length(b)) == Nat.sub(U32.to_nat(max), List.length(&2, U32, List.append(&2, U32, seen, b))) : Nat}
  %Equal.sym(Nat, F.length(b), List.length(&2, U32, b), WF.length_eq(b)) : {Nat.sub(Nat.sub(U32.to_nat(max), List.length(&2, U32, seen)), _) == Nat.sub(U32.to_nat(max), List.length(&2, U32, List.append(&2, U32, seen, b))) : Nat}
  %Equal.sym(Nat, List.length(&2, U32, List.append(&2, U32, seen, b)), Nat.add(List.length(&2, U32, seen), List.length(&2, U32, b)), WF.length_append(seen, b)) : {Nat.sub(Nat.sub(U32.to_nat(max), List.length(&2, U32, seen)), List.length(&2, U32, b)) == Nat.sub(U32.to_nat(max), _) : Nat}
  sub_sub(List.length(&2, U32, seen), U32.to_nat(max), List.length(&2, U32, b))

def first_fits(+b: List<&2, U32>, +max: U32) -> {Nat.is_le(F.length(b), U32.to_nat(max)) == Spec.fits(max, b) : Bool}:
  %Equal.sym(Nat, F.length(b), List.length(&2, U32, b), WF.length_eq(b)) : {Nat.is_le(_, U32.to_nat(max)) == Spec.fits(max, b) : Bool}
  {==}

def first_budget(+b: List<&2, U32>, +max: U32) -> {Nat.sub(U32.to_nat(max), F.length(b)) == Nat.sub(U32.to_nat(max), List.length(&2, U32, b)) : Nat}:
  %Equal.sym(Nat, F.length(b), List.length(&2, U32, b), WF.length_eq(b)) : {Nat.sub(U32.to_nat(max), _) == Nat.sub(U32.to_nat(max), List.length(&2, U32, b)) : Nat}
  {==}

def control_small(+b: List<&2, U32>) -> {Nat.is_le(F.length(b), 125n) == Spec.small(b) : Bool}:
  %Equal.sym(Nat, F.length(b), List.length(&2, U32, b), WF.length_eq(b)) : {Nat.is_le(_, 125n) == Spec.small(b) : Bool}
  {==}

# ---- A done session ignores everything ----

def done_in_q(+max: U32, +rest: List<&2, S.WsEvent>, r: M.Advance, ih: @st: M.State -> {S.trace(max, rest, S.Session{S.WsDone{}, st}) == Spec.quiets(rest) : List<&2, S.Action>}) -> {S.action_of(S.assembled(S.WsDone{}, r)) <> S.trace(max, rest, S.after(S.assembled(S.WsDone{}, r))) == Spec.quiet(S.WsDone{}) <> Spec.quiets(rest) : List<&2, S.Action>}:
  match r:
    case M.Advance{+st, M.Absorbed{}}: cons_eq(Spec.quiet(S.WsDone{}), S.trace(max, rest, S.Session{S.WsDone{}, st}), Spec.quiets(rest), ih(st))
    case M.Advance{+st, M.Deliver{m}}: cons_eq(Spec.quiet(S.WsDone{}), S.trace(max, rest, S.Session{S.WsDone{}, st}), Spec.quiets(rest), ih(st))
    case M.Advance{+st, M.Failed{code}}: cons_eq(Spec.quiet(S.WsDone{}), S.trace(max, rest, S.Session{S.WsDone{}, st}), Spec.quiets(rest), ih(st))

def done_event_q(+max: U32, +a: M.State, e: S.WsEvent, +rest: List<&2, S.WsEvent>, ih: @st: M.State -> {S.trace(max, rest, S.Session{S.WsDone{}, st}) == Spec.quiets(rest) : List<&2, S.Action>}) -> {S.trace(max, e <> rest, S.Session{S.WsDone{}, a}) == Spec.quiets(e <> rest) : List<&2, S.Action>}:
  match e:
    case S.Inbound{f}: done_in_q(max, rest, M.step(max, a, f), ih)
    case S.Outbound{command}: cons_eq(Spec.quiet(S.WsDone{}), S.trace(max, rest, S.Session{S.WsDone{}, a}), Spec.quiets(rest), ih(a))
    case S.Rejected{code}: cons_eq(Spec.quiet(S.WsDone{}), S.trace(max, rest, S.Session{S.WsDone{}, a}), Spec.quiets(rest), ih(a))
    case S.Dropped{}: cons_eq(Spec.quiet(S.WsDone{}), S.trace(max, rest, S.Session{S.WsDone{}, a}), Spec.quiets(rest), ih(a))

def done_quiet(+max: U32, es: List<&2, S.WsEvent>, +a: M.State) -> {S.trace(max, es, S.Session{S.WsDone{}, a}) == Spec.quiets(es) : List<&2, S.Action>}:
  match es:
    case Nil{}: {==}
    case +e <> +rest: done_event_q(max, a, e, rest, st => done_quiet(max, rest, st))

# ---- Delivery at the final fragment ----

def td_eq(m: Maybe<&2, String>) -> {[S.action_of(S.assembled(S.WsOpen{}, M.text_done(m)))] == [Spec.text_delivered(m)] : List<&2, S.Action>}:
  match m:
    case None{}: {==}
    case Some{t}: {==}

def delivered_eq(text: Bool, +d: List<&2, U32>) -> {[S.action_of(S.assembled(S.WsOpen{}, M.complete(text, d)))] == [Spec.delivered(text, d)] : List<&2, S.Action>}:
  match text:
    case True{}: td_eq(Utf8.decode(d))
    case False{}: {==}

def final_b(+text: Bool, +last: List<&2, U32>, +seen: List<&2, U32>, +r: List<&2, U32>, +hr: {List.reverse(&2, U32, r) == seen : List<&2, U32>}, ok: Bool, +bud: Nat) -> {[S.action_of(S.assembled(S.WsOpen{}, M.keep(ok, text, True{}, r, bud, F.length(last), last)))] == [Spec.pick(ok, Spec.delivered(text, List.append(&2, U32, seen, last)), Spec.failed(1009))] : List<&2, S.Action>}:
  match ok:
    case False{}: {==}
    case True{}:
      %Equal.sym(List<&2, U32>, List.reverse(&2, U32, M.rev_onto(last, r)), List.append(&2, U32, seen, last), rev_next(last, r, seen, hr)) : {[S.action_of(S.assembled(S.WsOpen{}, M.complete(text, _)))] == [Spec.delivered(text, List.append(&2, U32, seen, last))] : List<&2, S.Action>}
      delivered_eq(text, List.append(&2, U32, seen, last))

def final_a(+max: U32, +text: Bool, +last: List<&2, U32>, +seen: List<&2, U32>, +r: List<&2, U32>, +bud: Nat, +hr: {List.reverse(&2, U32, r) == seen : List<&2, U32>}, +hb: {bud == Nat.sub(U32.to_nat(max), List.length(&2, U32, seen)) : Nat}, +hf: {Nat.is_le(List.length(&2, U32, seen), U32.to_nat(max)) == True{} : Bool}) -> {[S.action_of(S.assembled(S.WsOpen{}, M.keep(Nat.is_le(F.length(last), bud), text, True{}, r, bud, F.length(last), last)))] == [Spec.finale(max, text, List.append(&2, U32, seen, last))] : List<&2, S.Action>}:
  %budget_fits(last, seen, bud, max, hb, hf) : {[S.action_of(S.assembled(S.WsOpen{}, M.keep(Nat.is_le(F.length(last), bud), text, True{}, r, bud, F.length(last), last)))] == [Spec.pick(_, Spec.delivered(text, List.append(&2, U32, seen, last)), Spec.failed(1009))] : List<&2, S.Action>}
  final_b(text, last, seen, r, hr, Nat.is_le(F.length(last), bud), bud)

# ---- Interleaved control frames ----

def ctl_b(ping: Bool, ok: Bool, +max: U32, +text: Bool, +b: List<&2, U32>, +rest: List<&2, Spec.Piece>, +last: List<&2, U32>, +seen: List<&2, U32>, +r: List<&2, U32>, +bud: Nat, ih: {S.trace(max, Spec.tail_events(rest, last), S.Session{S.WsOpen{}, M.Collecting{text, r, bud}}) == Spec.expect(max, text, rest, seen, last) : List<&2, S.Action>}) -> {S.action_of(S.assembled(S.WsOpen{}, M.control_step(ok, M.Collecting{text, r, bud}, Spec.control_op(ping), b))) <> S.trace(max, Spec.tail_events(rest, last), S.after(S.assembled(S.WsOpen{}, M.control_step(ok, M.Collecting{text, r, bud}, Spec.control_op(ping), b)))) == Spec.pick(ok, Spec.reply(ping, b), Spec.failed(1002)) <> Spec.select(ok, Spec.expect(max, text, rest, seen, last), Spec.quiets(Spec.tail_events(rest, last))) : List<&2, S.Action>}:
  match ping:
    case True{}:
      match ok:
        case True{}: cons_eq(Spec.reply(True{}, b), S.trace(max, Spec.tail_events(rest, last), S.Session{S.WsOpen{}, M.Collecting{text, r, bud}}), Spec.expect(max, text, rest, seen, last), ih)
        case False{}: cons_eq(Spec.failed(1002), S.trace(max, Spec.tail_events(rest, last), S.Session{S.WsDone{}, M.Ended{}}), Spec.quiets(Spec.tail_events(rest, last)), done_quiet(max, Spec.tail_events(rest, last), M.Ended{}))
    case False{}:
      match ok:
        case True{}: cons_eq(Spec.reply(False{}, b), S.trace(max, Spec.tail_events(rest, last), S.Session{S.WsOpen{}, M.Collecting{text, r, bud}}), Spec.expect(max, text, rest, seen, last), ih)
        case False{}: cons_eq(Spec.failed(1002), S.trace(max, Spec.tail_events(rest, last), S.Session{S.WsDone{}, M.Ended{}}), Spec.quiets(Spec.tail_events(rest, last)), done_quiet(max, Spec.tail_events(rest, last), M.Ended{}))

def ctl_a(+ping: Bool, +max: U32, +text: Bool, +b: List<&2, U32>, +rest: List<&2, Spec.Piece>, +last: List<&2, U32>, +seen: List<&2, U32>, +r: List<&2, U32>, +bud: Nat, ih: {S.trace(max, Spec.tail_events(rest, last), S.Session{S.WsOpen{}, M.Collecting{text, r, bud}}) == Spec.expect(max, text, rest, seen, last) : List<&2, S.Action>}) -> {S.action_of(S.assembled(S.WsOpen{}, M.control_step(Nat.is_le(F.length(b), 125n), M.Collecting{text, r, bud}, Spec.control_op(ping), b))) <> S.trace(max, Spec.tail_events(rest, last), S.after(S.assembled(S.WsOpen{}, M.control_step(Nat.is_le(F.length(b), 125n), M.Collecting{text, r, bud}, Spec.control_op(ping), b)))) == Spec.pick(Spec.small(b), Spec.reply(ping, b), Spec.failed(1002)) <> Spec.select(Spec.small(b), Spec.expect(max, text, rest, seen, last), Spec.quiets(Spec.tail_events(rest, last))) : List<&2, S.Action>}:
  %control_small(b) : {S.action_of(S.assembled(S.WsOpen{}, M.control_step(Nat.is_le(F.length(b), 125n), M.Collecting{text, r, bud}, Spec.control_op(ping), b))) <> S.trace(max, Spec.tail_events(rest, last), S.after(S.assembled(S.WsOpen{}, M.control_step(Nat.is_le(F.length(b), 125n), M.Collecting{text, r, bud}, Spec.control_op(ping), b)))) == Spec.pick(_, Spec.reply(ping, b), Spec.failed(1002)) <> Spec.select(_, Spec.expect(max, text, rest, seen, last), Spec.quiets(Spec.tail_events(rest, last))) : List<&2, S.Action>}
  ctl_b(ping, Nat.is_le(F.length(b), 125n), max, text, b, rest, last, seen, r, bud, ih)

# ---- Non-final continuations ----

def mid_b(ok: Bool, +max: U32, +text: Bool, +b: List<&2, U32>, +rest: List<&2, Spec.Piece>, +last: List<&2, U32>, +seen: List<&2, U32>, +r: List<&2, U32>, +bud: Nat, +hr: {List.reverse(&2, U32, r) == seen : List<&2, U32>}, +hb: {bud == Nat.sub(U32.to_nat(max), List.length(&2, U32, seen)) : Nat}, fit: {Spec.fits(max, List.append(&2, U32, seen, b)) == ok : Bool}, ih: {List.reverse(&2, U32, M.rev_onto(b, r)) == List.append(&2, U32, seen, b) : List<&2, U32>} -> {Nat.sub(bud, F.length(b)) == Nat.sub(U32.to_nat(max), List.length(&2, U32, List.append(&2, U32, seen, b))) : Nat} -> {Nat.is_le(List.length(&2, U32, List.append(&2, U32, seen, b)), U32.to_nat(max)) == True{} : Bool} -> {S.trace(max, Spec.tail_events(rest, last), S.Session{S.WsOpen{}, M.Collecting{text, M.rev_onto(b, r), Nat.sub(bud, F.length(b))}}) == Spec.expect(max, text, rest, List.append(&2, U32, seen, b), last) : List<&2, S.Action>}) -> {S.action_of(S.assembled(S.WsOpen{}, M.keep(ok, text, False{}, r, bud, F.length(b), b))) <> S.trace(max, Spec.tail_events(rest, last), S.after(S.assembled(S.WsOpen{}, M.keep(ok, text, False{}, r, bud, F.length(b), b)))) == Spec.pick(ok, Spec.quiet(S.WsOpen{}), Spec.failed(1009)) <> Spec.select(ok, Spec.expect(max, text, rest, List.append(&2, U32, seen, b), last), Spec.quiets(Spec.tail_events(rest, last))) : List<&2, S.Action>}:
  match ok:
    case True{}: cons_eq(Spec.quiet(S.WsOpen{}), S.trace(max, Spec.tail_events(rest, last), S.Session{S.WsOpen{}, M.Collecting{text, M.rev_onto(b, r), Nat.sub(bud, F.length(b))}}), Spec.expect(max, text, rest, List.append(&2, U32, seen, b), last), ih(rev_next(b, r, seen, hr), budget_next(b, seen, bud, max, hb), fit))
    case False{}: cons_eq(Spec.failed(1009), S.trace(max, Spec.tail_events(rest, last), S.Session{S.WsDone{}, M.Ended{}}), Spec.quiets(Spec.tail_events(rest, last)), done_quiet(max, Spec.tail_events(rest, last), M.Ended{}))

def mid_a(+max: U32, +text: Bool, +b: List<&2, U32>, +rest: List<&2, Spec.Piece>, +last: List<&2, U32>, +seen: List<&2, U32>, +r: List<&2, U32>, +bud: Nat, +hr: {List.reverse(&2, U32, r) == seen : List<&2, U32>}, +hb: {bud == Nat.sub(U32.to_nat(max), List.length(&2, U32, seen)) : Nat}, +hf: {Nat.is_le(List.length(&2, U32, seen), U32.to_nat(max)) == True{} : Bool}, ih: {List.reverse(&2, U32, M.rev_onto(b, r)) == List.append(&2, U32, seen, b) : List<&2, U32>} -> {Nat.sub(bud, F.length(b)) == Nat.sub(U32.to_nat(max), List.length(&2, U32, List.append(&2, U32, seen, b))) : Nat} -> {Nat.is_le(List.length(&2, U32, List.append(&2, U32, seen, b)), U32.to_nat(max)) == True{} : Bool} -> {S.trace(max, Spec.tail_events(rest, last), S.Session{S.WsOpen{}, M.Collecting{text, M.rev_onto(b, r), Nat.sub(bud, F.length(b))}}) == Spec.expect(max, text, rest, List.append(&2, U32, seen, b), last) : List<&2, S.Action>}) -> {S.action_of(S.assembled(S.WsOpen{}, M.keep(Nat.is_le(F.length(b), bud), text, False{}, r, bud, F.length(b), b))) <> S.trace(max, Spec.tail_events(rest, last), S.after(S.assembled(S.WsOpen{}, M.keep(Nat.is_le(F.length(b), bud), text, False{}, r, bud, F.length(b), b)))) == Spec.pick(Spec.fits(max, List.append(&2, U32, seen, b)), Spec.quiet(S.WsOpen{}), Spec.failed(1009)) <> Spec.select(Spec.fits(max, List.append(&2, U32, seen, b)), Spec.expect(max, text, rest, List.append(&2, U32, seen, b), last), Spec.quiets(Spec.tail_events(rest, last))) : List<&2, S.Action>}:
  %budget_fits(b, seen, bud, max, hb, hf) : {S.action_of(S.assembled(S.WsOpen{}, M.keep(Nat.is_le(F.length(b), bud), text, False{}, r, bud, F.length(b), b))) <> S.trace(max, Spec.tail_events(rest, last), S.after(S.assembled(S.WsOpen{}, M.keep(Nat.is_le(F.length(b), bud), text, False{}, r, bud, F.length(b), b)))) == Spec.pick(_, Spec.quiet(S.WsOpen{}), Spec.failed(1009)) <> Spec.select(_, Spec.expect(max, text, rest, List.append(&2, U32, seen, b), last), Spec.quiets(Spec.tail_events(rest, last))) : List<&2, S.Action>}
  mid_b(Nat.is_le(F.length(b), bud), max, text, b, rest, last, seen, r, bud, hr, hb, Equal.sym(Bool, Nat.is_le(F.length(b), bud), Spec.fits(max, List.append(&2, U32, seen, b)), budget_fits(b, seen, bud, max, hb, hf)), ih)

# ---- The whole message, by induction on the pieces ----

# `r` is the assembler's reversed buffer for `seen`, and `bud` is what is left
# of the budget.
def collecting(+max: U32, +text: Bool, pieces: List<&2, Spec.Piece>, +last: List<&2, U32>, +seen: List<&2, U32>, +r: List<&2, U32>, +bud: Nat, +hr: {List.reverse(&2, U32, r) == seen : List<&2, U32>}, +hb: {bud == Nat.sub(U32.to_nat(max), List.length(&2, U32, seen)) : Nat}, +hf: {Nat.is_le(List.length(&2, U32, seen), U32.to_nat(max)) == True{} : Bool}) -> {S.trace(max, Spec.tail_events(pieces, last), S.Session{S.WsOpen{}, M.Collecting{text, r, bud}}) == Spec.expect(max, text, pieces, seen, last) : List<&2, S.Action>}:
  match pieces:
    case Nil{}: final_a(max, text, last, seen, r, bud, hr, hb, hf)
    case Spec.Interleaved{ping, +b} <> +rest:
      match ping:
        case True{}: ctl_a(True{}, max, text, b, rest, last, seen, r, bud, collecting(max, text, rest, last, seen, r, bud, hr, hb, hf))
        case False{}: ctl_a(False{}, max, text, b, rest, last, seen, r, bud, collecting(max, text, rest, last, seen, r, bud, hr, hb, hf))
    case Spec.Middle{+b} <> +rest:
      mid_a(max, text, b, rest, last, seen, r, bud, hr, hb, hf, h1 => h2 => h3 => collecting(max, text, rest, last, List.append(&2, U32, seen, b), M.rev_onto(b, r), Nat.sub(bud, F.length(b)), h1, h2, h3))

def open_b(ok: Bool, +max: U32, +text: Bool, +first: List<&2, U32>, +pieces: List<&2, Spec.Piece>, +last: List<&2, U32>, fit: {Spec.fits(max, first) == ok : Bool}) -> {S.action_of(S.assembled(S.WsOpen{}, M.keep(ok, text, False{}, [], U32.to_nat(max), F.length(first), first))) <> S.trace(max, Spec.tail_events(pieces, last), S.after(S.assembled(S.WsOpen{}, M.keep(ok, text, False{}, [], U32.to_nat(max), F.length(first), first)))) == Spec.pick(ok, Spec.quiet(S.WsOpen{}), Spec.failed(1009)) <> Spec.select(ok, Spec.expect(max, text, pieces, first, last), Spec.quiets(Spec.tail_events(pieces, last))) : List<&2, S.Action>}:
  match ok:
    case True{}: cons_eq(Spec.quiet(S.WsOpen{}), S.trace(max, Spec.tail_events(pieces, last), S.Session{S.WsOpen{}, M.Collecting{text, M.rev_onto(first, []), Nat.sub(U32.to_nat(max), F.length(first))}}), Spec.expect(max, text, pieces, first, last), collecting(max, text, pieces, last, first, M.rev_onto(first, []), Nat.sub(U32.to_nat(max), F.length(first)), rev_rev(first, []), first_budget(first, max), fit))
    case False{}: cons_eq(Spec.failed(1009), S.trace(max, Spec.tail_events(pieces, last), S.Session{S.WsDone{}, M.Ended{}}), Spec.quiets(Spec.tail_events(pieces, last)), done_quiet(max, Spec.tail_events(pieces, last), M.Ended{}))

def open_a(+max: U32, +text: Bool, +first: List<&2, U32>, +pieces: List<&2, Spec.Piece>, +last: List<&2, U32>) -> {S.action_of(S.assembled(S.WsOpen{}, M.keep(Nat.is_le(F.length(first), U32.to_nat(max)), text, False{}, [], U32.to_nat(max), F.length(first), first))) <> S.trace(max, Spec.tail_events(pieces, last), S.after(S.assembled(S.WsOpen{}, M.keep(Nat.is_le(F.length(first), U32.to_nat(max)), text, False{}, [], U32.to_nat(max), F.length(first), first)))) == Spec.expected(max, text, first, pieces, last) : List<&2, S.Action>}:
  %first_fits(first, max) : {S.action_of(S.assembled(S.WsOpen{}, M.keep(Nat.is_le(F.length(first), U32.to_nat(max)), text, False{}, [], U32.to_nat(max), F.length(first), first))) <> S.trace(max, Spec.tail_events(pieces, last), S.after(S.assembled(S.WsOpen{}, M.keep(Nat.is_le(F.length(first), U32.to_nat(max)), text, False{}, [], U32.to_nat(max), F.length(first), first)))) == Spec.pick(_, Spec.quiet(S.WsOpen{}), Spec.failed(1009)) <> Spec.select(_, Spec.expect(max, text, pieces, first, last), Spec.quiets(Spec.tail_events(pieces, last))) : List<&2, S.Action>}
  open_b(Nat.is_le(F.length(first), U32.to_nat(max)), max, text, first, pieces, last, Equal.sym(Bool, Nat.is_le(F.length(first), U32.to_nat(max)), Spec.fits(max, first), first_fits(first, max)))

def L.ws_session_fragments(max, text, first, pieces, last):
  match text:
    case True{}: open_a(max, True{}, first, pieces, last)
    case False{}: open_a(max, False{}, first, pieces, last)

def single_a(+max: U32, +text: Bool, +payload: List<&2, U32>) -> {[S.action_of(S.assembled(S.WsOpen{}, M.keep(Nat.is_le(F.length(payload), U32.to_nat(max)), text, True{}, [], U32.to_nat(max), F.length(payload), payload)))] == [Spec.finale(max, text, payload)] : List<&2, S.Action>}:
  %first_fits(payload, max) : {[S.action_of(S.assembled(S.WsOpen{}, M.keep(Nat.is_le(F.length(payload), U32.to_nat(max)), text, True{}, [], U32.to_nat(max), F.length(payload), payload)))] == [Spec.pick(_, Spec.delivered(text, payload), Spec.failed(1009))] : List<&2, S.Action>}
  final_b(text, payload, [], [], {==}, Nat.is_le(F.length(payload), U32.to_nat(max)), U32.to_nat(max))

def L.ws_session_single_message(max, text, payload):
  match text:
    case True{}: single_a(max, True{}, payload)
    case False{}: single_a(max, False{}, payload)

# ---- Without the final fragment nothing is delivered ----

def nm_fail(p: S.Phase, +code: U32, +xs: List<&2, S.Action>) -> {Spec.messages(S.action_of(S.assembled(p, M.fail(code))) <> xs) == Spec.messages(xs) : Nat}:
  match p:
    case S.WsOpen{}: {==}
    case S.WsClosing{}: {==}
    case S.WsDone{}: {==}

def nm_keep(+p: S.Phase, fits: Bool, +text: Bool, +rev: List<&2, U32>, +budget: Nat, +n: Nat, +payload: List<&2, U32>, +xs: List<&2, S.Action>) -> {Spec.messages(S.action_of(S.assembled(p, M.keep(fits, text, False{}, rev, budget, n, payload))) <> xs) == Spec.messages(xs) : Nat}:
  match fits:
    case False{}: nm_fail(p, F.too_big(), xs)
    case True{}: {==}

def nm_ctl(ping: Bool, ok: Bool, p: S.Phase, +a: M.State, +b: List<&2, U32>, +xs: List<&2, S.Action>) -> {Spec.messages(S.action_of(S.assembled(p, M.control_step(ok, a, Spec.control_op(ping), b))) <> xs) == Spec.messages(xs) : Nat}:
  match ping:
    case True{}:
      match ok:
        case False{}: nm_fail(p, F.protocol_error(), xs)
        case True{}:
          match p:
            case S.WsOpen{}: {==}
            case S.WsClosing{}: {==}
            case S.WsDone{}: {==}
    case False{}:
      match ok:
        case False{}: nm_fail(p, F.protocol_error(), xs)
        case True{}:
          match p:
            case S.WsOpen{}: {==}
            case S.WsClosing{}: {==}
            case S.WsDone{}: {==}

def nm_nf_idle(op: F.Opcode, +p: S.Phase, +max: U32, +b: List<&2, U32>, +xs: List<&2, S.Action>) -> {Spec.messages(S.action_of(S.assembled(p, M.step(max, M.Idle{}, F.Frame{False{}, op, b}))) <> xs) == Spec.messages(xs) : Nat}:
  match op:
    case F.OpContinue{}: nm_fail(p, F.protocol_error(), xs)
    case F.OpText{}: nm_keep(p, Nat.is_le(F.length(b), U32.to_nat(max)), True{}, [], U32.to_nat(max), F.length(b), b, xs)
    case F.OpBinary{}: nm_keep(p, Nat.is_le(F.length(b), U32.to_nat(max)), False{}, [], U32.to_nat(max), F.length(b), b, xs)
    case F.OpClose{}: nm_fail(p, F.protocol_error(), xs)
    case F.OpPing{}: nm_fail(p, F.protocol_error(), xs)
    case F.OpPong{}: nm_fail(p, F.protocol_error(), xs)

def nm_nf_coll(op: F.Opcode, +p: S.Phase, +max: U32, +t: Bool, +r: List<&2, U32>, +bud: Nat, +b: List<&2, U32>, +xs: List<&2, S.Action>) -> {Spec.messages(S.action_of(S.assembled(p, M.step(max, M.Collecting{t, r, bud}, F.Frame{False{}, op, b}))) <> xs) == Spec.messages(xs) : Nat}:
  match op:
    case F.OpContinue{}: nm_keep(p, Nat.is_le(F.length(b), bud), t, r, bud, F.length(b), b, xs)
    case F.OpText{}: nm_fail(p, F.protocol_error(), xs)
    case F.OpBinary{}: nm_fail(p, F.protocol_error(), xs)
    case F.OpClose{}: nm_fail(p, F.protocol_error(), xs)
    case F.OpPing{}: nm_fail(p, F.protocol_error(), xs)
    case F.OpPong{}: nm_fail(p, F.protocol_error(), xs)

def nm_nonfinal(a: M.State, +p: S.Phase, +max: U32, +op: F.Opcode, +b: List<&2, U32>, +xs: List<&2, S.Action>) -> {Spec.messages(S.action_of(S.assembled(p, M.step(max, a, F.Frame{False{}, op, b}))) <> xs) == Spec.messages(xs) : Nat}:
  match a:
    case M.Ended{}: {==}
    case M.Idle{}: nm_nf_idle(op, p, max, b, xs)
    case M.Collecting{t, r, bud}: nm_nf_coll(op, p, max, t, r, bud, b, xs)

def nm_control(a: M.State, +p: S.Phase, +max: U32, ping: Bool, +b: List<&2, U32>, +xs: List<&2, S.Action>) -> {Spec.messages(S.action_of(S.assembled(p, M.step(max, a, F.Frame{True{}, Spec.control_op(ping), b}))) <> xs) == Spec.messages(xs) : Nat}:
  match a:
    case M.Ended{}: {==}
    case M.Idle{}:
      match ping:
        case True{}: nm_ctl(True{}, Nat.is_le(F.length(b), 125n), p, M.Idle{}, b, xs)
        case False{}: nm_ctl(False{}, Nat.is_le(F.length(b), 125n), p, M.Idle{}, b, xs)
    case M.Collecting{+t, +r, +bud}:
      match ping:
        case True{}: nm_ctl(True{}, Nat.is_le(F.length(b), 125n), p, M.Collecting{t, r, bud}, b, xs)
        case False{}: nm_ctl(False{}, Nat.is_le(F.length(b), 125n), p, M.Collecting{t, r, bud}, b, xs)

def nm_piece(s: S.Session, +max: U32, piece: Spec.Piece, +xs: List<&2, S.Action>) -> {Spec.messages(S.action_of(S.step(max, s, S.Inbound{Spec.piece_frame(piece)})) <> xs) == Spec.messages(xs) : Nat}:
  match s:
    case S.Session{p, a}:
      match piece:
        case Spec.Interleaved{ping, b}: nm_control(a, p, max, ping, b, xs)
        case Spec.Middle{b}: nm_nonfinal(a, p, max, F.OpContinue{}, b, xs)

def nm_open(+max: U32, pieces: List<&2, Spec.Piece>, +s: S.Session) -> {Spec.messages(S.trace(max, Spec.open_events(pieces), s)) == 0n : Nat}:
  match pieces:
    case Nil{}: {==}
    case +piece <> +rest:
      Equal.trans(Nat, Spec.messages(S.action_of(S.step(max, s, S.Inbound{Spec.piece_frame(piece)})) <> S.trace(max, Spec.open_events(rest), S.after(S.step(max, s, S.Inbound{Spec.piece_frame(piece)})))), Spec.messages(S.trace(max, Spec.open_events(rest), S.after(S.step(max, s, S.Inbound{Spec.piece_frame(piece)})))), 0n, nm_piece(s, max, piece, S.trace(max, Spec.open_events(rest), S.after(S.step(max, s, S.Inbound{Spec.piece_frame(piece)})))), nm_open(max, rest, S.after(S.step(max, s, S.Inbound{Spec.piece_frame(piece)}))))

def L.ws_session_incomplete(max, text, first, pieces):
  Equal.trans(Nat, Spec.messages(S.action_of(S.step(max, S.opened(), Spec.opening(text, first))) <> S.trace(max, Spec.open_events(pieces), S.after(S.step(max, S.opened(), Spec.opening(text, first))))), Spec.messages(S.trace(max, Spec.open_events(pieces), S.after(S.step(max, S.opened(), Spec.opening(text, first))))), 0n, nm_nonfinal(M.Idle{}, S.WsOpen{}, max, Spec.data_op(text), first, S.trace(max, Spec.open_events(pieces), S.after(S.step(max, S.opened(), Spec.opening(text, first))))), nm_open(max, pieces, S.after(S.step(max, S.opened(), Spec.opening(text, first)))))
