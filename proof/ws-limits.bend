# BND-105: proofs of the subscription limit laws. Does not import LAWS.bend.
# Each proof destructures the limits and the registry, then splits on the
# five checks T.verdict reads, passed in as Bool parameters with their
# defining equations where a leaf needs them.
import Base
import ./ws-limits-laws.bend as L
import ./ws-topics.bend as WT
import ./ws-topics-spec.bend as Spec
import ./ws-limits-spec.bend as LS
import ../src/ws/topics.bend as T

# ---- Nat facts ----

def lt_succ_le(+n: Nat, +p: Nat) -> {Nat.is_lt(n, p) == Nat.is_le(1n+n, p) : Bool}:
  match n p:
    case 0n 0n: {==}
    case 0n 1n+q:
      match q:
        case 0n: {==}
        case 1n+r: {==}
    case 1n+m 0n: {==}
    case 1n+m 1n+q: lt_succ_le(m, q)

def succ_within(+n: Nat, +p: Nat, e: {Nat.is_lt(n, p) == True{} : Bool}) -> {Nat.is_le(1n+n, p) == True{} : Bool}:
  Equal.trans(Bool, Nat.is_le(1n+n, p), Nat.is_lt(n, p), True{}, Equal.sym(Bool, Nat.is_lt(n, p), Nat.is_le(1n+n, p), lt_succ_le(n, p)), e)

def add_succ(+a: Nat, +b: Nat) -> {Nat.add(a, 1n+b) == 1n+Nat.add(a, b) : Nat}:
  match a:
    case 0n: {==}
    case 1n+m: Equal.cong(Nat, Nat, y => 1n+y, Nat.add(m, 1n+b), 1n+Nat.add(m, b), add_succ(m, b))

# ---- without on a list that lacks the pair ----

def absent_step(-A: Data, +topic: String, +id: Nat, +x: A, +rest: List<&2, T.Sub<A>>, +c: Nat, +t: String, k: Bool, e: {(k || T.has_sub(A, rest, c, t)) == False{} : Bool}, ih: {T.has_sub(A, rest, c, t) == False{} : Bool} -> {T.without(A, rest, c, t) == rest : List<&2, T.Sub<A>>}) -> {T.keep(A, T.Sub{topic, id, x}, T.without(A, rest, c, t), k) == T.Sub{topic, id, x} <> rest : List<&2, T.Sub<A>>}:
  match k:
    case True{}: WT.absurd({T.without(A, rest, c, t) == T.Sub{topic, id, x} <> rest : List<&2, T.Sub<A>>}, WT.false_true(Equal.sym(Bool, True{}, False{}, e)))
    case False{}:
      %Equal.sym(List<&2, T.Sub<A>>, T.without(A, rest, c, t), rest, ih(e)) : {T.Sub{topic, id, x} <> _ == T.Sub{topic, id, x} <> rest : List<&2, T.Sub<A>>}
      {==}

def without_absent(-A: Data, +xs: List<&2, T.Sub<A>>, +c: Nat, +t: String, e: {T.has_sub(A, xs, c, t) == False{} : Bool}) -> {T.without(A, xs, c, t) == xs : List<&2, T.Sub<A>>}:
  match xs:
    case Nil{}: {==}
    case T.Sub{topic, id, x} <> rest: absent_step(A, topic, id, x, rest, c, t, String.eq(topic, t) && Nat.is_eq(id, c), e, f => without_absent(A, rest, c, t, f))

# ---- Refusal and admission ----

def refusal(-A: Data, +R: T.Registry<A>, +c: Nat, +t: String, +x: A, va: Bool, vs: Bool, vm: Bool, vp: Bool, vh: Bool, e: {T.admitted(T.verdict(va, vs, vm, vp, vh)) == False{} : Bool}) -> {T.granted(A, R, c, t, x, T.verdict(va, vs, vm, vp, vh)) == R : T.Registry<A>}:
  match va:
    case False{}: {==}
    case True{}:
      match vs:
        case False{}: {==}
        case True{}:
          match vm:
            case True{}: {==}
            case False{}:
              match vp:
                case False{}: {==}
                case True{}:
                  match vh:
                    case False{}: {==}
                    case True{}: WT.absurd({T.subscribe(A, R, c, t, x) == R : T.Registry<A>}, WT.false_true(Equal.sym(Bool, True{}, False{}, e)))

def L.ws_limits_refusal_unchanged(A, l, r, c, t, x, refused):
  match l:
    case T.Limits{p, h, b}:
      match r:
        case T.Registry{n, live, s}: refusal(A, T.Registry{n, live, s}, c, t, x, T.holds(live, c), Nat.is_le(T.bytes_of(t), b), T.has_sub(A, s, c, t), Nat.is_lt(T.owned_count(A, s, c), p), Nat.is_lt(List.length(&2, T.Sub<A>, s), h), refused)

def admission(-A: Data, +R: T.Registry<A>, +c: Nat, +t: String, +x: A, va: Bool, vs: Bool, vm: Bool, vp: Bool, vh: Bool, e: {T.admitted(T.verdict(va, vs, vm, vp, vh)) == True{} : Bool}) -> {T.granted(A, R, c, t, x, T.verdict(va, vs, vm, vp, vh)) == T.admit_if(A, R, c, t, x, va) : T.Registry<A>}:
  match va:
    case False{}: {==}
    case True{}:
      match vs:
        case False{}: WT.absurd({R == T.subscribe(A, R, c, t, x) : T.Registry<A>}, WT.false_true(e))
        case True{}:
          match vm:
            case True{}: WT.absurd({R == T.subscribe(A, R, c, t, x) : T.Registry<A>}, WT.false_true(e))
            case False{}:
              match vp:
                case False{}: WT.absurd({R == T.subscribe(A, R, c, t, x) : T.Registry<A>}, WT.false_true(e))
                case True{}:
                  match vh:
                    case False{}: WT.absurd({R == T.subscribe(A, R, c, t, x) : T.Registry<A>}, WT.false_true(e))
                    case True{}: {==}

def L.ws_limits_admitted_is_admit(A, l, r, c, t, x, ok):
  match l:
    case T.Limits{p, h, b}:
      match r:
        case T.Registry{n, live, s}: admission(A, T.Registry{n, live, s}, c, t, x, T.holds(live, c), Nat.is_le(T.bytes_of(t), b), T.has_sub(A, s, c, t), Nat.is_lt(T.owned_count(A, s, c), p), Nat.is_lt(List.length(&2, T.Sub<A>, s), h), ok)

# ---- Bounds ----

def bump_bound(-A: Data, +s: List<&2, T.Sub<A>>, +c: Nat, +d: Nat, +p: Nat, k: Bool, ek: {Nat.is_eq(c, d) == k : Bool}, room: {Nat.is_lt(T.owned_count(A, s, c), p) == True{} : Bool}, within: {Nat.is_le(T.owned_count(A, s, d), p) == True{} : Bool}) -> {Nat.is_le(T.bump(k, T.owned_count(A, s, d)), p) == True{} : Bool}:
  match k:
    case False{}: within
    case True{}:
      %WT.nat_sound(c, d, ek) : {Nat.is_le(1n+T.owned_count(A, s, _), p) == True{} : Bool}
      succ_within(T.owned_count(A, s, c), p, room)

def peer_step(-A: Data, +p: Nat, +n: Nat, +live: List<&2, Nat>, +s: List<&2, T.Sub<A>>, +c: Nat, +t: String, +x: A, +d: Nat, va: Bool, vs: Bool, vm: Bool, em: {T.has_sub(A, s, c, t) == vm : Bool}, vp: Bool, ep: {Nat.is_lt(T.owned_count(A, s, c), p) == vp : Bool}, vh: Bool, within: {Nat.is_le(T.owned_count(A, s, d), p) == True{} : Bool}) -> {Nat.is_le(T.owned_count(A, T.subs(A, T.granted(A, T.Registry{n, live, s}, c, t, x, T.verdict(va, vs, vm, vp, vh))), d), p) == True{} : Bool}:
  match va:
    case False{}: within
    case True{}:
      match vs:
        case False{}: within
        case True{}:
          match vm:
            case True{}: within
            case False{}:
              match vp:
                case False{}: within
                case True{}:
                  match vh:
                    case False{}: within
                    case True{}:
                      %Equal.sym(List<&2, T.Sub<A>>, T.without(A, s, c, t), s, without_absent(A, s, c, t, em)) : {Nat.is_le(T.bump(Nat.is_eq(c, d), T.owned_count(A, _, d)), p) == True{} : Bool}
                      bump_bound(A, s, c, d, p, Nat.is_eq(c, d), {==}, ep, within)

def L.ws_limits_peer_bound(A, l, r, c, t, x, d, within):
  match l:
    case T.Limits{p, h, b}:
      match r:
        case T.Registry{n, live, s}: peer_step(A, p, n, live, s, c, t, x, d, T.holds(live, c), Nat.is_le(T.bytes_of(t), b), T.has_sub(A, s, c, t), {==}, Nat.is_lt(T.owned_count(A, s, c), p), {==}, Nat.is_lt(List.length(&2, T.Sub<A>, s), h), within)

def hub_step(-A: Data, +h: Nat, +n: Nat, +live: List<&2, Nat>, +s: List<&2, T.Sub<A>>, +c: Nat, +t: String, +x: A, va: Bool, vs: Bool, vm: Bool, em: {T.has_sub(A, s, c, t) == vm : Bool}, vp: Bool, vh: Bool, eh: {Nat.is_lt(List.length(&2, T.Sub<A>, s), h) == vh : Bool}, within: {Nat.is_le(List.length(&2, T.Sub<A>, s), h) == True{} : Bool}) -> {Nat.is_le(T.size(A, T.granted(A, T.Registry{n, live, s}, c, t, x, T.verdict(va, vs, vm, vp, vh))), h) == True{} : Bool}:
  match va:
    case False{}: within
    case True{}:
      match vs:
        case False{}: within
        case True{}:
          match vm:
            case True{}: within
            case False{}:
              match vp:
                case False{}: within
                case True{}:
                  match vh:
                    case False{}: within
                    case True{}:
                      %Equal.sym(List<&2, T.Sub<A>>, T.without(A, s, c, t), s, without_absent(A, s, c, t, em)) : {Nat.is_le(1n+List.length(&2, T.Sub<A>, _), h) == True{} : Bool}
                      succ_within(List.length(&2, T.Sub<A>, s), h, eh)

def L.ws_limits_hub_bound(A, l, r, c, t, x, within):
  match l:
    case T.Limits{p, h, b}:
      match r:
        case T.Registry{n, live, s}: hub_step(A, h, n, live, s, c, t, x, T.holds(live, c), Nat.is_le(T.bytes_of(t), b), T.has_sub(A, s, c, t), {==}, Nat.is_lt(T.owned_count(A, s, c), p), Nat.is_lt(List.length(&2, T.Sub<A>, s), h), {==}, within)

# ---- Long topics and repeats are refusals ----

def long_refused(va: Bool, vs: Bool, vm: Bool, vp: Bool, vh: Bool, es: {vs == False{} : Bool}) -> {T.admitted(T.verdict(va, vs, vm, vp, vh)) == False{} : Bool}:
  match va:
    case False{}: {==}
    case True{}:
      match vs:
        case False{}: {==}
        case True{}: WT.absurd({T.admitted(T.verdict(True{}, True{}, vm, vp, vh)) == False{} : Bool}, WT.false_true(Equal.sym(Bool, True{}, False{}, es)))

def L.ws_limits_long_topic_unchanged(A, l, r, c, t, x, long):
  match l:
    case T.Limits{p, h, b}:
      match r:
        case T.Registry{n, live, s}: refusal(A, T.Registry{n, live, s}, c, t, x, T.holds(live, c), Nat.is_le(T.bytes_of(t), b), T.has_sub(A, s, c, t), Nat.is_lt(T.owned_count(A, s, c), p), Nat.is_lt(List.length(&2, T.Sub<A>, s), h), long_refused(T.holds(live, c), Nat.is_le(T.bytes_of(t), b), T.has_sub(A, s, c, t), Nat.is_lt(T.owned_count(A, s, c), p), Nat.is_lt(List.length(&2, T.Sub<A>, s), h), long))

def repeat_refused(va: Bool, vs: Bool, vm: Bool, vp: Bool, vh: Bool, em: {vm == True{} : Bool}) -> {T.admitted(T.verdict(va, vs, vm, vp, vh)) == False{} : Bool}:
  match va:
    case False{}: {==}
    case True{}:
      match vs:
        case False{}: {==}
        case True{}:
          match vm:
            case True{}: {==}
            case False{}: WT.absurd({T.admitted(T.verdict(True{}, True{}, False{}, vp, vh)) == False{} : Bool}, WT.false_true(em))

def L.ws_limits_repeat_unchanged(A, l, r, c, t, x, member):
  match l:
    case T.Limits{p, h, b}:
      match r:
        case T.Registry{n, live, s}: refusal(A, T.Registry{n, live, s}, c, t, x, T.holds(live, c), Nat.is_le(T.bytes_of(t), b), T.has_sub(A, s, c, t), Nat.is_lt(T.owned_count(A, s, c), p), Nat.is_lt(List.length(&2, T.Sub<A>, s), h), repeat_refused(T.holds(live, c), Nat.is_le(T.bytes_of(t), b), T.has_sub(A, s, c, t), Nat.is_lt(T.owned_count(A, s, c), p), Nat.is_lt(List.length(&2, T.Sub<A>, s), h), member))

# ---- Closing frees slots ----

def frees_step(-A: Data, +topic: String, +id: Nat, +x: A, +rest: List<&2, T.Sub<A>>, +c: Nat, k: Bool, ek: {Nat.is_eq(id, c) == k : Bool}, ih: {T.owned_count(A, T.dropped(A, rest, c), c) == 0n : Nat}) -> {T.owned_count(A, T.keep(A, T.Sub{topic, id, x}, T.dropped(A, rest, c), k), c) == 0n : Nat}:
  match k:
    case True{}: ih
    case False{}:
      %Equal.sym(Bool, Nat.is_eq(id, c), False{}, ek) : {T.bump(_, T.owned_count(A, T.dropped(A, rest, c), c)) == 0n : Nat}
      ih

def frees(-A: Data, +xs: List<&2, T.Sub<A>>, +c: Nat) -> {T.owned_count(A, T.dropped(A, xs, c), c) == 0n : Nat}:
  match xs:
    case Nil{}: {==}
    case T.Sub{topic, id, x} <> rest: frees_step(A, topic, id, x, rest, c, Nat.is_eq(id, c), {==}, frees(A, rest, c))

def L.ws_limits_remove_frees(A, r, c):
  match r:
    case T.Registry{n, live, s}: frees(A, s, c)

def returns_step(-A: Data, +topic: String, +id: Nat, +x: A, +rest: List<&2, T.Sub<A>>, +c: Nat, k: Bool, ih: {Nat.add(T.owned_count(A, rest, c), List.length(&2, T.Sub<A>, T.dropped(A, rest, c))) == List.length(&2, T.Sub<A>, rest) : Nat}) -> {Nat.add(T.bump(k, T.owned_count(A, rest, c)), List.length(&2, T.Sub<A>, T.keep(A, T.Sub{topic, id, x}, T.dropped(A, rest, c), k))) == 1n+List.length(&2, T.Sub<A>, rest) : Nat}:
  match k:
    case True{}: Equal.cong(Nat, Nat, y => 1n+y, Nat.add(T.owned_count(A, rest, c), List.length(&2, T.Sub<A>, T.dropped(A, rest, c))), List.length(&2, T.Sub<A>, rest), ih)
    case False{}:
      %Equal.sym(Nat, Nat.add(T.owned_count(A, rest, c), 1n+List.length(&2, T.Sub<A>, T.dropped(A, rest, c))), 1n+Nat.add(T.owned_count(A, rest, c), List.length(&2, T.Sub<A>, T.dropped(A, rest, c))), add_succ(T.owned_count(A, rest, c), List.length(&2, T.Sub<A>, T.dropped(A, rest, c)))) : {_ == 1n+List.length(&2, T.Sub<A>, rest) : Nat}
      Equal.cong(Nat, Nat, y => 1n+y, Nat.add(T.owned_count(A, rest, c), List.length(&2, T.Sub<A>, T.dropped(A, rest, c))), List.length(&2, T.Sub<A>, rest), ih)

def returns(-A: Data, +xs: List<&2, T.Sub<A>>, +c: Nat) -> {Nat.add(T.owned_count(A, xs, c), List.length(&2, T.Sub<A>, T.dropped(A, xs, c))) == List.length(&2, T.Sub<A>, xs) : Nat}:
  match xs:
    case Nil{}: {==}
    case T.Sub{topic, id, x} <> rest: returns_step(A, topic, id, x, rest, c, Nat.is_eq(id, c), returns(A, rest, c))

def L.ws_limits_remove_returns_slots(A, r, c):
  match r:
    case T.Registry{n, live, s}: returns(A, s, c)

# ---- The reported verdict ----

def not_admitted(a: T.Admission, e: {a == T.Admitted{} : T.Admission}) -> {T.admitted(a) == True{} : Bool}:
  %Equal.sym(T.Admission, a, T.Admitted{}, e) : {T.admitted(_) == True{} : Bool}
  {==}

# An Admitted verdict passed the activity and length checks.
def admitted_active(va: Bool, vs: Bool, vm: Bool, vp: Bool, vh: Bool, e: {T.verdict(va, vs, vm, vp, vh) == T.Admitted{} : T.Admission}) -> {va == True{} : Bool}:
  match va:
    case False{}: WT.absurd({False{} == True{} : Bool}, WT.false_true(not_admitted(T.NotActive{}, e)))
    case True{}: {==}

def admitted_short(va: Bool, vs: Bool, vm: Bool, vp: Bool, vh: Bool, e: {T.verdict(va, vs, vm, vp, vh) == T.Admitted{} : T.Admission}) -> {vs == True{} : Bool}:
  match va:
    case False{}: WT.absurd({vs == True{} : Bool}, WT.false_true(not_admitted(T.NotActive{}, e)))
    case True{}:
      match vs:
        case False{}: WT.absurd({False{} == True{} : Bool}, WT.false_true(not_admitted(T.TopicTooLong{}, e)))
        case True{}: {==}

def already(va: Bool, vs: Bool, vm: Bool, vp: Bool, vh: Bool, ea: {va == True{} : Bool}, es: {vs == True{} : Bool}, em: {vm == True{} : Bool}) -> {T.verdict(va, vs, vm, vp, vh) == T.AlreadyMember{} : T.Admission}:
  match va:
    case False{}: WT.absurd({T.NotActive{} == T.AlreadyMember{} : T.Admission}, WT.false_true(ea))
    case True{}:
      match vs:
        case False{}: WT.absurd({T.TopicTooLong{} == T.AlreadyMember{} : T.Admission}, WT.false_true(es))
        case True{}:
          match vm:
            case True{}: {==}
            case False{}: WT.absurd({T.verdict(True{}, True{}, False{}, vp, vh) == T.AlreadyMember{} : T.Admission}, WT.false_true(em))

# A fresh record for (t, c) makes c a member of t.
def member_now(-A: Data, +s: List<&2, T.Sub<A>>, +c: Nat, +t: String, +x: A) -> {T.has_sub(A, T.Sub{t, c, x} <> s, c, t) == True{} : Bool}:
  WT.or_left(String.eq(t, t) && Nat.is_eq(c, c), T.has_sub(A, s, c, t), WT.and_true(String.eq(t, t), Nat.is_eq(c, c), WT.string_refl(t), WT.nat_refl(c)))

def reported(-A: Data, +p: Nat, +h: Nat, +b: Nat, +n: Nat, +live: List<&2, Nat>, +s: List<&2, T.Sub<A>>, +c: Nat, +t: String, +x: A, a: T.Admission, +ea: {T.decide(A, T.Limits{p, h, b}, T.Registry{n, live, s}, c, t) == a : T.Admission}) -> {T.decide(A, T.Limits{p, h, b}, T.granted(A, T.Registry{n, live, s}, c, t, x, a), c, t) == T.settled(a) : T.Admission}:
  match a:
    case T.Admitted{}:
      already(T.holds(live, c), Nat.is_le(T.bytes_of(t), b), T.has_sub(A, T.Sub{t, c, x} <> T.without(A, s, c, t), c, t), Nat.is_lt(T.owned_count(A, T.Sub{t, c, x} <> T.without(A, s, c, t), c), p), Nat.is_lt(List.length(&2, T.Sub<A>, T.Sub{t, c, x} <> T.without(A, s, c, t)), h), admitted_active(T.holds(live, c), Nat.is_le(T.bytes_of(t), b), T.has_sub(A, s, c, t), Nat.is_lt(T.owned_count(A, s, c), p), Nat.is_lt(List.length(&2, T.Sub<A>, s), h), ea), admitted_short(T.holds(live, c), Nat.is_le(T.bytes_of(t), b), T.has_sub(A, s, c, t), Nat.is_lt(T.owned_count(A, s, c), p), Nat.is_lt(List.length(&2, T.Sub<A>, s), h), ea), member_now(A, T.without(A, s, c, t), c, t, x))
    case T.AlreadyMember{}: ea
    case T.NotActive{}: ea
    case T.TopicTooLong{}: ea
    case T.PeerFull{}: ea
    case T.HubFull{}: ea

def L.ws_limits_reported(A, l, r, c, t, x):
  match l:
    case T.Limits{p, h, b}:
      match r:
        case T.Registry{n, live, s}: reported(A, p, h, b, n, live, s, c, t, x, T.decide(A, T.Limits{p, h, b}, T.Registry{n, live, s}, c, t), {==})

# ---- The decision against the independent table ----

# The impl's checks read the same facts as the spec's.
def holds_has(+ids: List<&2, Nat>, +c: Nat) -> {T.holds(ids, c) == Spec.has(ids, c) : Bool}:
  match ids:
    case Nil{}: {==}
    case +h <> t: Equal.cong(Bool, Bool, y => Nat.is_eq(h, c) || y, T.holds(t, c), Spec.has(t, c), holds_has(t, c))

def sub_paired(-A: Data, +xs: List<&2, T.Sub<A>>, +c: Nat, +t: String) -> {T.has_sub(A, xs, c, t) == Spec.paired(A, xs, c, t) : Bool}:
  match xs:
    case Nil{}: {==}
    case T.Sub{+topic, +id, x} <> rest: Equal.cong(Bool, Bool, y => (String.eq(topic, t) && Nat.is_eq(id, c)) || y, T.has_sub(A, rest, c, t), Spec.paired(A, rest, c, t), sub_paired(A, rest, c, t))

def bump_tick(k: Bool, +a: Nat, +z: Nat, e: {a == z : Nat}) -> {T.bump(k, a) == Spec.tick(k, z) : Nat}:
  match k:
    case True{}: Equal.cong(Nat, Nat, y => 1n+y, a, z, e)
    case False{}: e

def owned_ids(-A: Data, +xs: List<&2, T.Sub<A>>, +c: Nat) -> {T.owned_count(A, xs, c) == Spec.count(Spec.ids(A, xs), c) : Nat}:
  match xs:
    case Nil{}: {==}
    case T.Sub{topic, id, x} <> rest: bump_tick(Nat.is_eq(id, c), T.owned_count(A, rest, c), Spec.count(Spec.ids(A, rest), c), owned_ids(A, rest, c))

def room_count(-A: Data, +s: List<&2, T.Sub<A>>, +c: Nat, +p: Nat) -> {Nat.is_lt(T.owned_count(A, s, c), p) == Nat.is_lt(Spec.count(Spec.ids(A, s), c), p) : Bool}:
  Equal.cong(Nat, Bool, z => Nat.is_lt(z, p), T.owned_count(A, s, c), Spec.count(Spec.ids(A, s), c), owned_ids(A, s, c))

# T.verdict is the table read top to bottom.
def table(va: Bool, vs: Bool, vm: Bool, vp: Bool, vh: Bool) -> {T.verdict(va, vs, vm, vp, vh) == LS.on_fail(va, T.NotActive{}, LS.on_fail(vs, T.TopicTooLong{}, LS.on_fail(Bool.not(vm), T.AlreadyMember{}, LS.on_fail(vp, T.PeerFull{}, LS.on_fail(vh, T.HubFull{}, T.Admitted{}))))) : T.Admission}:
  match va:
    case False{}: {==}
    case True{}:
      match vs:
        case False{}: {==}
        case True{}:
          match vm:
            case True{}: {==}
            case False{}:
              match vp:
                case False{}: {==}
                case True{}:
                  match vh:
                    case False{}: {==}
                    case True{}: {==}

def table_open(va: Bool, vs: Bool, vm: Bool, vp: Bool, vh: Bool) -> {T.admitted(T.verdict(va, vs, vm, vp, vh)) == (va && (vs && (Bool.not(vm) && (vp && (vh && True{}))))) : Bool}:
  match va:
    case False{}: {==}
    case True{}:
      match vs:
        case False{}: {==}
        case True{}:
          match vm:
            case True{}: {==}
            case False{}:
              match vp:
                case False{}: {==}
                case True{}:
                  match vh:
                    case False{}: {==}
                    case True{}: {==}

# The same with the spec's three facts in place of the impl's.
def bridged(va: Bool, wa: Bool, ea: {va == wa : Bool}, vs: Bool, vm: Bool, wm: Bool, em: {vm == wm : Bool}, vp: Bool, wp: Bool, ep: {vp == wp : Bool}, vh: Bool) -> {T.verdict(va, vs, vm, vp, vh) == LS.on_fail(wa, T.NotActive{}, LS.on_fail(vs, T.TopicTooLong{}, LS.on_fail(Bool.not(wm), T.AlreadyMember{}, LS.on_fail(wp, T.PeerFull{}, LS.on_fail(vh, T.HubFull{}, T.Admitted{}))))) : T.Admission}:
  %ea : {T.verdict(va, vs, vm, vp, vh) == LS.on_fail(_, T.NotActive{}, LS.on_fail(vs, T.TopicTooLong{}, LS.on_fail(Bool.not(wm), T.AlreadyMember{}, LS.on_fail(wp, T.PeerFull{}, LS.on_fail(vh, T.HubFull{}, T.Admitted{}))))) : T.Admission}
  %em : {T.verdict(va, vs, vm, vp, vh) == LS.on_fail(va, T.NotActive{}, LS.on_fail(vs, T.TopicTooLong{}, LS.on_fail(Bool.not(_), T.AlreadyMember{}, LS.on_fail(wp, T.PeerFull{}, LS.on_fail(vh, T.HubFull{}, T.Admitted{}))))) : T.Admission}
  %ep : {T.verdict(va, vs, vm, vp, vh) == LS.on_fail(va, T.NotActive{}, LS.on_fail(vs, T.TopicTooLong{}, LS.on_fail(Bool.not(vm), T.AlreadyMember{}, LS.on_fail(_, T.PeerFull{}, LS.on_fail(vh, T.HubFull{}, T.Admitted{}))))) : T.Admission}
  table(va, vs, vm, vp, vh)

def bridged_open(va: Bool, wa: Bool, ea: {va == wa : Bool}, vs: Bool, vm: Bool, wm: Bool, em: {vm == wm : Bool}, vp: Bool, wp: Bool, ep: {vp == wp : Bool}, vh: Bool) -> {T.admitted(T.verdict(va, vs, vm, vp, vh)) == (wa && (vs && (Bool.not(wm) && (wp && (vh && True{}))))) : Bool}:
  %ea : {T.admitted(T.verdict(va, vs, vm, vp, vh)) == (_ && (vs && (Bool.not(wm) && (wp && (vh && True{}))))) : Bool}
  %em : {T.admitted(T.verdict(va, vs, vm, vp, vh)) == (va && (vs && (Bool.not(_) && (wp && (vh && True{}))))) : Bool}
  %ep : {T.admitted(T.verdict(va, vs, vm, vp, vh)) == (va && (vs && (Bool.not(vm) && (_ && (vh && True{}))))) : Bool}
  table_open(va, vs, vm, vp, vh)

def L.ws_limits_decide_exact(A, l, r, c, t):
  match l:
    case T.Limits{p, h, b}:
      match r:
        case T.Registry{n, live, s}: bridged(T.holds(live, c), Spec.has(live, c), holds_has(live, c), Nat.is_le(T.bytes_of(t), b), T.has_sub(A, s, c, t), Spec.paired(A, s, c, t), sub_paired(A, s, c, t), Nat.is_lt(T.owned_count(A, s, c), p), Nat.is_lt(Spec.count(Spec.ids(A, s), c), p), room_count(A, s, c, p), Nat.is_lt(List.length(&2, T.Sub<A>, s), h))

def L.ws_limits_admitted_iff(A, l, r, c, t):
  match l:
    case T.Limits{p, h, b}:
      match r:
        case T.Registry{n, live, s}: bridged_open(T.holds(live, c), Spec.has(live, c), holds_has(live, c), Nat.is_le(T.bytes_of(t), b), T.has_sub(A, s, c, t), Spec.paired(A, s, c, t), sub_paired(A, s, c, t), Nat.is_lt(T.owned_count(A, s, c), p), Nat.is_lt(Spec.count(Spec.ids(A, s), c), p), room_count(A, s, c, p), Nat.is_lt(List.length(&2, T.Sub<A>, s), h))

# ---- Admission when every check passes ----

def admits_leaf(-A: Data, +R: T.Registry<A>, +c: Nat, +t: String, +x: A, va: Bool, vs: Bool, vm: Bool, vp: Bool, vh: Bool, ea: {va == True{} : Bool}, es: {vs == True{} : Bool}, em: {vm == False{} : Bool}, ep: {vp == True{} : Bool}, eh: {vh == True{} : Bool}) -> {T.granted(A, R, c, t, x, T.verdict(va, vs, vm, vp, vh)) == T.subscribe(A, R, c, t, x) : T.Registry<A>}:
  match va:
    case False{}: WT.absurd({R == T.subscribe(A, R, c, t, x) : T.Registry<A>}, WT.false_true(ea))
    case True{}:
      match vs:
        case False{}: WT.absurd({R == T.subscribe(A, R, c, t, x) : T.Registry<A>}, WT.false_true(es))
        case True{}:
          match vm:
            case True{}: WT.absurd({R == T.subscribe(A, R, c, t, x) : T.Registry<A>}, WT.false_true(Equal.sym(Bool, True{}, False{}, em)))
            case False{}:
              match vp:
                case False{}: WT.absurd({R == T.subscribe(A, R, c, t, x) : T.Registry<A>}, WT.false_true(ep))
                case True{}:
                  match vh:
                    case False{}: WT.absurd({R == T.subscribe(A, R, c, t, x) : T.Registry<A>}, WT.false_true(eh))
                    case True{}: {==}

def L.ws_limits_admits(A, l, r, c, t, x, active, short, fresh, peer_room, hub_room):
  match l:
    case T.Limits{p, h, b}:
      match r:
        case T.Registry{n, live, s}: admits_leaf(A, T.Registry{n, live, s}, c, t, x, T.holds(live, c), Nat.is_le(T.bytes_of(t), b), T.has_sub(A, s, c, t), Nat.is_lt(T.owned_count(A, s, c), p), Nat.is_lt(List.length(&2, T.Sub<A>, s), h), Equal.trans(Bool, T.holds(live, c), Spec.has(live, c), True{}, holds_has(live, c), active), short, Equal.trans(Bool, T.has_sub(A, s, c, t), Spec.paired(A, s, c, t), False{}, sub_paired(A, s, c, t), fresh), Equal.trans(Bool, Nat.is_lt(T.owned_count(A, s, c), p), Nat.is_lt(Spec.count(Spec.ids(A, s), c), p), True{}, room_count(A, s, c, p), peer_room), hub_room)
