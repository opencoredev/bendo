# Proofs of the BND-53 topic registry laws. Does not import LAWS.bend.
import Base
import ./ws-topics-laws.bend as L
import ./ws-topics-spec.bend as Spec
import ./jwt-structure.bend as JS
import ./crypto-compare.bend as CC
import ../src/ws/topics.bend as T

def absurd(-X: Type, e: Empty) -> X:
  match e:

def false_true(e: {False{} == True{} : Bool}) -> Empty:
  %e : Bool.pick(Type, _, Empty, Unit)
  Unit{}

# ---- Equality facts ----

def nat_refl(+n: Nat) -> {Nat.is_eq(n, n) == True{} : Bool}:
  match n:
    case 0n: {==}
    case 1n+m: nat_refl(m)

def nat_sound(+a: Nat, +b: Nat, e: {Nat.is_eq(a, b) == True{} : Bool}) -> {a == b : Nat}:
  match a b:
    case 0n 0n: {==}
    case 0n 1n+q: absurd({0n == 1n+q : Nat}, false_true(e))
    case 1n+p 0n: absurd({1n+p == 0n : Nat}, false_true(e))
    case 1n+p 1n+q: Equal.cong(Nat, Nat, y => 1n+y, p, q, nat_sound(p, q, e))

def nat_sym(+a: Nat, +b: Nat) -> {Nat.is_eq(a, b) == Nat.is_eq(b, a) : Bool}:
  match a b:
    case 0n 0n: {==}
    case 0n 1n+q: {==}
    case 1n+p 0n: {==}
    case 1n+p 1n+q: nat_sym(p, q)

def cmp_eq_sound(+o: Cmp, e: {Cmp.is_eq(o) == True{} : Bool}) -> {o == EQ{} : Cmp}:
  match o:
    case LT{}: absurd({LT{} == EQ{} : Cmp}, false_true(e))
    case EQ{}: {==}
    case GT{}: absurd({GT{} == EQ{} : Cmp}, false_true(e))

def u32_self(+x: U32) -> {U32.cmp(x, x) == EQ{} : Cmp}:
  match x:
    case U32{w}: cmp_eq_sound(Word.cmp(32n, w, w), CC.word_self(32n, w))

def order_self(+s: String) -> {String.order.go(s, s, EQ{}) == EQ{} : Cmp}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{x}, t}:
      %Equal.sym(Cmp, U32.cmp(x, x), EQ{}, u32_self(x)) : {String.order.go(t, t, _) == EQ{} : Cmp}
      order_self(t)

def string_refl(+s: String) -> {String.eq(s, s) == True{} : Bool}:
  %Equal.sym(Cmp, String.order.go(s, s, EQ{}), EQ{}, order_self(s)) : {Cmp.is_eq(_) == True{} : Bool}
  {==}

# ---- Bool facts ----

def and_l(+a: Bool, -b: Bool, e: {(a && b) == True{} : Bool}) -> {a == True{} : Bool}:
  match a:
    case True{}: {==}
    case False{}: e

def and_r(+a: Bool, -b: Bool, e: {(a && b) == True{} : Bool}) -> {b == True{} : Bool}:
  match a:
    case True{}: e
    case False{}: absurd({b == True{} : Bool}, false_true(e))

def and_true(+a: Bool, -b: Bool, ea: {a == True{} : Bool}, eb: {b == True{} : Bool}) -> {(a && b) == True{} : Bool}:
  match a:
    case True{}: eb
    case False{}: absurd({(False{} && b) == True{} : Bool}, false_true(ea))

def and_false_r(+a: Bool, -b: Bool, eb: {b == False{} : Bool}) -> {(a && b) == False{} : Bool}:
  match a:
    case True{}: eb
    case False{}: {==}

def or_left(+a: Bool, -b: Bool, ea: {a == True{} : Bool}) -> {(a || b) == True{} : Bool}:
  match a:
    case True{}: {==}
    case False{}: absurd({(False{} || b) == True{} : Bool}, false_true(ea))

def or_false(+a: Bool, -b: Bool, ea: {a == False{} : Bool}, eb: {b == False{} : Bool}) -> {(a || b) == False{} : Bool}:
  match a:
    case False{}: eb
    case True{}: absurd({(True{} || b) == False{} : Bool}, false_true(Equal.sym(Bool, True{}, False{}, ea)))

# String.eq(a, t) && Nat.is_eq(i, c) after replacing equal arguments.
def swap_left(+a: String, +b: String, +i: Nat, +j: Nat, +t: String, +c: Nat, ea: {a == b : String}, ei: {i == j : Nat}) -> {(String.eq(a, t) && Nat.is_eq(i, c)) == (String.eq(b, t) && Nat.is_eq(j, c)) : Bool}:
  %ea : {(String.eq(a, t) && Nat.is_eq(i, c)) == (String.eq(_, t) && Nat.is_eq(j, c)) : Bool}
  %ei : {(String.eq(a, t) && Nat.is_eq(i, c)) == (String.eq(a, t) && Nat.is_eq(_, c)) : Bool}
  {==}

def swap_right(+a: String, +i: Nat, +t: String, +u: String, +c: Nat, +d: Nat, et: {u == t : String}, ec: {d == c : Nat}) -> {(String.eq(a, t) && Nat.is_eq(i, c)) == (String.eq(a, u) && Nat.is_eq(i, d)) : Bool}:
  %et : {(String.eq(a, _) && Nat.is_eq(i, c)) == (String.eq(a, u) && Nat.is_eq(i, d)) : Bool}
  %ec : {(String.eq(a, u) && Nat.is_eq(i, _)) == (String.eq(a, u) && Nat.is_eq(i, d)) : Bool}
  {==}

# ---- Counting helpers ----

def set_if(b: Bool, v: Nat, n: Nat) -> Nat:
  match b:
    case True{}: v
    case False{}: n

def count_nil(+b: Bool) -> {0n == set_if(b, 0n, 0n) : Nat}:
  match b:
    case True{}: {==}
    case False{}: {==}

def positive(n: Nat) -> Bool:
  match n:
    case 0n: False{}
    case 1n+m: True{}

def tick_false(+b: Bool, +n: Nat, e: {b == False{} : Bool}) -> {Spec.tick(b, n) == n : Nat}:
  match b:
    case False{}: {==}
    case True{}: absurd({Spec.tick(True{}, n) == n : Nat}, false_true(Equal.sym(Bool, True{}, False{}, e)))

def tick_set(+h: Bool, +n: Nat) -> {Spec.tick(h, set_if(h, 0n, n)) == set_if(h, 1n, n) : Nat}:
  match h:
    case True{}: {==}
    case False{}: {==}

def pick_false(+id: Nat, +m: List<&2, Nat>, +b: Bool, e: {b == False{} : Bool}) -> {T.pick(id, m, b) == m : List<&2, Nat>}:
  match b:
    case False{}: {==}
    case True{}: absurd({T.pick(id, m, True{}) == m : List<&2, Nat>}, false_true(Equal.sym(Bool, True{}, False{}, e)))

def has_pick(+id: Nat, +m: List<&2, Nat>, +b: Bool, +c: Nat) -> {Spec.has(T.pick(id, m, b), c) == ((b && Nat.is_eq(id, c)) || Spec.has(m, c)) : Bool}:
  match b:
    case True{}: {==}
    case False{}: {==}

def count_pick(+id: Nat, +m: List<&2, Nat>, +b: Bool, +c: Nat) -> {Spec.count(T.pick(id, m, b), c) == Spec.tick(b && Nat.is_eq(id, c), Spec.count(m, c)) : Nat}:
  match b:
    case True{}: {==}
    case False{}: {==}

# ---- Subscribe, unsubscribe and remove ----

def L.ws_topics_subscribe_member(A, r, c, t, x):
  match r:
    case T.Registry{next, s}:
      Equal.trans(Bool, Spec.has(T.pick(c, T.members_of(A, T.without(A, s, c, t), t), String.eq(t, t)), c), (String.eq(t, t) && Nat.is_eq(c, c)) || Spec.has(T.members_of(A, T.without(A, s, c, t), t), c), True{}, has_pick(c, T.members_of(A, T.without(A, s, c, t), t), String.eq(t, t), c), or_left(String.eq(t, t) && Nat.is_eq(c, c), Spec.has(T.members_of(A, T.without(A, s, c, t), t), c), and_true(String.eq(t, t), Nat.is_eq(c, c), string_refl(t), nat_refl(c))))

def unsub_step(-A: Data, +topic: String, +id: Nat, +x: A, +rest: List<&2, T.Sub<A>>, +c: Nat, +t: String, b: Bool, eb: {(String.eq(topic, t) && Nat.is_eq(id, c)) == b : Bool}, ih: {Spec.has(T.members_of(A, T.without(A, rest, c, t), t), c) == False{} : Bool}) -> {Spec.has(T.members_of(A, T.keep(A, T.Sub{topic, id, x}, T.without(A, rest, c, t), b), t), c) == False{} : Bool}:
  match b:
    case True{}: ih
    case False{}:
      Equal.trans(Bool, Spec.has(T.pick(id, T.members_of(A, T.without(A, rest, c, t), t), String.eq(topic, t)), c), (String.eq(topic, t) && Nat.is_eq(id, c)) || Spec.has(T.members_of(A, T.without(A, rest, c, t), t), c), False{}, has_pick(id, T.members_of(A, T.without(A, rest, c, t), t), String.eq(topic, t), c), or_false(String.eq(topic, t) && Nat.is_eq(id, c), Spec.has(T.members_of(A, T.without(A, rest, c, t), t), c), eb, ih))

def unsub_gone(-A: Data, +s: List<&2, T.Sub<A>>, +c: Nat, +t: String) -> {Spec.has(T.members_of(A, T.without(A, s, c, t), t), c) == False{} : Bool}:
  match s:
    case Nil{}: {==}
    case T.Sub{topic, id, x} <> rest:
      unsub_step(A, topic, id, x, rest, c, t, String.eq(topic, t) && Nat.is_eq(id, c), {==}, unsub_gone(A, rest, c, t))

def L.ws_topics_unsubscribe_leaves(A, r, c, t):
  match r:
    case T.Registry{next, s}: unsub_gone(A, s, c, t)

def drop_step(-A: Data, +topic: String, +id: Nat, +x: A, +rest: List<&2, T.Sub<A>>, +c: Nat, +t: String, b: Bool, eb: {Nat.is_eq(id, c) == b : Bool}, ih: {Spec.has(T.members_of(A, T.dropped(A, rest, c), t), c) == False{} : Bool}) -> {Spec.has(T.members_of(A, T.keep(A, T.Sub{topic, id, x}, T.dropped(A, rest, c), b), t), c) == False{} : Bool}:
  match b:
    case True{}: ih
    case False{}:
      Equal.trans(Bool, Spec.has(T.pick(id, T.members_of(A, T.dropped(A, rest, c), t), String.eq(topic, t)), c), (String.eq(topic, t) && Nat.is_eq(id, c)) || Spec.has(T.members_of(A, T.dropped(A, rest, c), t), c), False{}, has_pick(id, T.members_of(A, T.dropped(A, rest, c), t), String.eq(topic, t), c), or_false(String.eq(topic, t) && Nat.is_eq(id, c), Spec.has(T.members_of(A, T.dropped(A, rest, c), t), c), and_false_r(String.eq(topic, t), Nat.is_eq(id, c), eb), ih))

def drop_gone(-A: Data, +s: List<&2, T.Sub<A>>, +c: Nat, +t: String) -> {Spec.has(T.members_of(A, T.dropped(A, s, c), t), c) == False{} : Bool}:
  match s:
    case Nil{}: {==}
    case T.Sub{topic, id, x} <> rest:
      drop_step(A, topic, id, x, rest, c, t, Nat.is_eq(id, c), {==}, drop_gone(A, rest, c, t))

def L.ws_topics_remove_leaves(A, r, c, t):
  match r:
    case T.Registry{next, s}: drop_gone(A, s, c, t)

# ---- Independent topics ----

def other_step(-A: Data, +topic: String, +id: Nat, +x: A, +rest: List<&2, T.Sub<A>>, +c: Nat, +t: String, +u: String, +other: {String.eq(t, u) == False{} : Bool}, b: Bool, eb: {(String.eq(topic, t) && Nat.is_eq(id, c)) == b : Bool}, ih: {T.members_of(A, T.without(A, rest, c, t), u) == T.members_of(A, rest, u) : List<&2, Nat>}) -> {T.members_of(A, T.keep(A, T.Sub{topic, id, x}, T.without(A, rest, c, t), b), u) == T.pick(id, T.members_of(A, rest, u), String.eq(topic, u)) : List<&2, Nat>}:
  match b:
    case False{}:
      Equal.cong(List<&2, Nat>, List<&2, Nat>, m => T.pick(id, m, String.eq(topic, u)), T.members_of(A, T.without(A, rest, c, t), u), T.members_of(A, rest, u), ih)
    case True{}:
      +same = JS.string_sound(topic, t, and_l(String.eq(topic, t), Nat.is_eq(id, c), eb))
      +ne = Equal.trans(Bool, String.eq(topic, u), String.eq(t, u), False{}, Equal.cong(String, Bool, v => String.eq(v, u), topic, t, same), other)
      Equal.trans(List<&2, Nat>, T.members_of(A, T.without(A, rest, c, t), u), T.members_of(A, rest, u), T.pick(id, T.members_of(A, rest, u), String.eq(topic, u)), ih, Equal.sym(List<&2, Nat>, T.pick(id, T.members_of(A, rest, u), String.eq(topic, u)), T.members_of(A, rest, u), pick_false(id, T.members_of(A, rest, u), String.eq(topic, u), ne)))

def without_other(-A: Data, +s: List<&2, T.Sub<A>>, +c: Nat, +t: String, +u: String, +other: {String.eq(t, u) == False{} : Bool}) -> {T.members_of(A, T.without(A, s, c, t), u) == T.members_of(A, s, u) : List<&2, Nat>}:
  match s:
    case Nil{}: {==}
    case T.Sub{topic, id, x} <> rest:
      other_step(A, topic, id, x, rest, c, t, u, other, String.eq(topic, t) && Nat.is_eq(id, c), {==}, without_other(A, rest, c, t, u, other))

def L.ws_topics_subscribe_independent(A, r, c, t, u, x, other):
  match r:
    case T.Registry{next, s}:
      Equal.trans(List<&2, Nat>, T.pick(c, T.members_of(A, T.without(A, s, c, t), u), String.eq(t, u)), T.members_of(A, T.without(A, s, c, t), u), T.members_of(A, s, u), pick_false(c, T.members_of(A, T.without(A, s, c, t), u), String.eq(t, u), other), without_other(A, s, c, t, u, other))

def L.ws_topics_unsubscribe_independent(A, r, c, t, u, other):
  match r:
    case T.Registry{next, s}: without_other(A, s, c, t, u, other)

# ---- Publication targets ----

def target_pick(-A: Data, +topic: String, +id: Nat, +x: A, +rest: List<&2, T.Sub<A>>, +t: String, +ex: Maybe<&2, Nat>, q: Bool, ih: {T.target_ids(A, T.targets_of(A, rest, t, ex)) == Spec.others(T.members_of(A, rest, t), ex) : List<&2, Nat>}) -> {T.target_ids(A, List.filter.put(T.Sub<A>, T.Sub{topic, id, x}, T.targets_of(A, rest, t, ex), Bool.not(q))) == Spec.skip(id, Spec.others(T.members_of(A, rest, t), ex), q) : List<&2, Nat>}:
  match q:
    case True{}: ih
    case False{}: Equal.cong(List<&2, Nat>, List<&2, Nat>, m => id <> m, T.target_ids(A, T.targets_of(A, rest, t, ex)), Spec.others(T.members_of(A, rest, t), ex), ih)

def target_step(-A: Data, +topic: String, +id: Nat, +x: A, +rest: List<&2, T.Sub<A>>, +t: String, b: Bool, +ex: Maybe<&2, Nat>, ih: {T.target_ids(A, T.targets_of(A, rest, t, ex)) == Spec.others(T.members_of(A, rest, t), ex) : List<&2, Nat>}) -> {T.target_ids(A, List.filter.put(T.Sub<A>, T.Sub{topic, id, x}, T.targets_of(A, rest, t, ex), b && Bool.not(T.excluded(id, ex)))) == Spec.others(T.pick(id, T.members_of(A, rest, t), b), ex) : List<&2, Nat>}:
  match b ex:
    case False{} _: ih
    case True{} None{}: target_pick(A, topic, id, x, rest, t, None{}, False{}, ih)
    case True{} Some{e}: target_pick(A, topic, id, x, rest, t, Some{e}, Nat.is_eq(id, e), ih)

def targets_spec(-A: Data, +s: List<&2, T.Sub<A>>, +t: String, +ex: Maybe<&2, Nat>) -> {T.target_ids(A, T.targets_of(A, s, t, ex)) == Spec.others(T.members_of(A, s, t), ex) : List<&2, Nat>}:
  match s:
    case Nil{}: {==}
    case T.Sub{topic, id, x} <> rest:
      target_step(A, topic, id, x, rest, t, String.eq(topic, t), ex, targets_spec(A, rest, t, ex))

def targets_registry(-A: Data, +r: T.Registry<A>, +t: String, +ex: Maybe<&2, Nat>) -> {T.target_ids(A, T.targets(A, r, t, ex)) == Spec.others(T.members(A, r, t), ex) : List<&2, Nat>}:
  match r:
    case T.Registry{next, s}: targets_spec(A, s, t, ex)

def L.ws_topics_publish_targets(A, r, t, sender):
  targets_registry(A, r, t, sender)

# ---- Counting through each operation ----

# Unsubscribing (d, u) zeroes the count of (c, t) when the pairs match and
# leaves it otherwise.
def count_without_step(-A: Data, +topic: String, +id: Nat, +x: A, +rest: List<&2, T.Sub<A>>, +d: Nat, +u: String, +c: Nat, +t: String, hs: Bool, +ehs: {(String.eq(topic, u) && Nat.is_eq(id, d)) == hs : Bool}, h: Bool, +eh: {(String.eq(u, t) && Nat.is_eq(d, c)) == h : Bool}, ih: {Spec.count(T.members_of(A, T.without(A, rest, d, u), t), c) == set_if(h, 0n, Spec.count(T.members_of(A, rest, t), c)) : Nat}) -> {Spec.count(T.members_of(A, T.keep(A, T.Sub{topic, id, x}, T.without(A, rest, d, u), hs), t), c) == set_if(h, 0n, Spec.count(T.pick(id, T.members_of(A, rest, t), String.eq(topic, t)), c)) : Nat}:
  match hs h:
    case True{} True{}: ih
    case True{} False{}:
      +same_topic = JS.string_sound(topic, u, and_l(String.eq(topic, u), Nat.is_eq(id, d), ehs))
      +same_id = nat_sound(id, d, and_r(String.eq(topic, u), Nat.is_eq(id, d), ehs))
      +kf = Equal.trans(Bool, String.eq(topic, t) && Nat.is_eq(id, c), String.eq(u, t) && Nat.is_eq(d, c), False{}, swap_left(topic, u, id, d, t, c, same_topic, same_id), eh)
      Equal.trans(Nat, Spec.count(T.members_of(A, T.without(A, rest, d, u), t), c), Spec.count(T.members_of(A, rest, t), c), Spec.count(T.pick(id, T.members_of(A, rest, t), String.eq(topic, t)), c), ih, Equal.sym(Nat, Spec.count(T.pick(id, T.members_of(A, rest, t), String.eq(topic, t)), c), Spec.count(T.members_of(A, rest, t), c), Equal.trans(Nat, Spec.count(T.pick(id, T.members_of(A, rest, t), String.eq(topic, t)), c), Spec.tick(String.eq(topic, t) && Nat.is_eq(id, c), Spec.count(T.members_of(A, rest, t), c)), Spec.count(T.members_of(A, rest, t), c), count_pick(id, T.members_of(A, rest, t), String.eq(topic, t), c), tick_false(String.eq(topic, t) && Nat.is_eq(id, c), Spec.count(T.members_of(A, rest, t), c), kf))))
    case False{} True{}:
      +same_topic = JS.string_sound(u, t, and_l(String.eq(u, t), Nat.is_eq(d, c), eh))
      +same_id = nat_sound(d, c, and_r(String.eq(u, t), Nat.is_eq(d, c), eh))
      +kf = Equal.trans(Bool, String.eq(topic, t) && Nat.is_eq(id, c), String.eq(topic, u) && Nat.is_eq(id, d), False{}, swap_right(topic, id, t, u, c, d, same_topic, same_id), ehs)
      Equal.trans(Nat, Spec.count(T.pick(id, T.members_of(A, T.without(A, rest, d, u), t), String.eq(topic, t)), c), Spec.tick(String.eq(topic, t) && Nat.is_eq(id, c), Spec.count(T.members_of(A, T.without(A, rest, d, u), t), c)), 0n, count_pick(id, T.members_of(A, T.without(A, rest, d, u), t), String.eq(topic, t), c), Equal.trans(Nat, Spec.tick(String.eq(topic, t) && Nat.is_eq(id, c), Spec.count(T.members_of(A, T.without(A, rest, d, u), t), c)), Spec.count(T.members_of(A, T.without(A, rest, d, u), t), c), 0n, tick_false(String.eq(topic, t) && Nat.is_eq(id, c), Spec.count(T.members_of(A, T.without(A, rest, d, u), t), c), kf), ih))
    case False{} False{}:
      Equal.trans(Nat, Spec.count(T.pick(id, T.members_of(A, T.without(A, rest, d, u), t), String.eq(topic, t)), c), Spec.tick(String.eq(topic, t) && Nat.is_eq(id, c), Spec.count(T.members_of(A, rest, t), c)), Spec.count(T.pick(id, T.members_of(A, rest, t), String.eq(topic, t)), c), Equal.trans(Nat, Spec.count(T.pick(id, T.members_of(A, T.without(A, rest, d, u), t), String.eq(topic, t)), c), Spec.tick(String.eq(topic, t) && Nat.is_eq(id, c), Spec.count(T.members_of(A, T.without(A, rest, d, u), t), c)), Spec.tick(String.eq(topic, t) && Nat.is_eq(id, c), Spec.count(T.members_of(A, rest, t), c)), count_pick(id, T.members_of(A, T.without(A, rest, d, u), t), String.eq(topic, t), c), Equal.cong(Nat, Nat, n => Spec.tick(String.eq(topic, t) && Nat.is_eq(id, c), n), Spec.count(T.members_of(A, T.without(A, rest, d, u), t), c), Spec.count(T.members_of(A, rest, t), c), ih)), Equal.sym(Nat, Spec.count(T.pick(id, T.members_of(A, rest, t), String.eq(topic, t)), c), Spec.tick(String.eq(topic, t) && Nat.is_eq(id, c), Spec.count(T.members_of(A, rest, t), c)), count_pick(id, T.members_of(A, rest, t), String.eq(topic, t), c)))

def count_without(-A: Data, +s: List<&2, T.Sub<A>>, +d: Nat, +u: String, +c: Nat, +t: String) -> {Spec.count(T.members_of(A, T.without(A, s, d, u), t), c) == set_if(String.eq(u, t) && Nat.is_eq(d, c), 0n, Spec.count(T.members_of(A, s, t), c)) : Nat}:
  match s:
    case Nil{}: count_nil(String.eq(u, t) && Nat.is_eq(d, c))
    case T.Sub{topic, id, x} <> rest:
      count_without_step(A, topic, id, x, rest, d, u, c, t, String.eq(topic, u) && Nat.is_eq(id, d), {==}, String.eq(u, t) && Nat.is_eq(d, c), {==}, count_without(A, rest, d, u, c, t))

# Closing steps shared by the remove count: `b` is String.eq(topic, t).
def fin_tf(+id: Nat, +m: List<&2, Nat>, +n: Nat, +b: Bool, +c: Nat, kf: {(b && Nat.is_eq(id, c)) == False{} : Bool}, ih: {n == Spec.count(m, c) : Nat}) -> {n == Spec.count(T.pick(id, m, b), c) : Nat}:
  match b:
    case False{}: ih
    case True{}: Equal.trans(Nat, n, Spec.count(m, c), Spec.tick(Nat.is_eq(id, c), Spec.count(m, c)), ih, Equal.sym(Nat, Spec.tick(Nat.is_eq(id, c), Spec.count(m, c)), Spec.count(m, c), tick_false(Nat.is_eq(id, c), Spec.count(m, c), kf)))

def fin_ft(+id: Nat, +m: List<&2, Nat>, +b: Bool, +c: Nat, kf: {(b && Nat.is_eq(id, c)) == False{} : Bool}, ih: {Spec.count(m, c) == 0n : Nat}) -> {Spec.count(T.pick(id, m, b), c) == 0n : Nat}:
  match b:
    case False{}: ih
    case True{}: Equal.trans(Nat, Spec.tick(Nat.is_eq(id, c), Spec.count(m, c)), Spec.count(m, c), 0n, tick_false(Nat.is_eq(id, c), Spec.count(m, c), kf), ih)

def fin_ff(+id: Nat, +m: List<&2, Nat>, +k: List<&2, Nat>, +b: Bool, +c: Nat, ih: {Spec.count(m, c) == Spec.count(k, c) : Nat}) -> {Spec.count(T.pick(id, m, b), c) == Spec.count(T.pick(id, k, b), c) : Nat}:
  match b:
    case False{}: ih
    case True{}: Equal.cong(Nat, Nat, n => Spec.tick(Nat.is_eq(id, c), n), Spec.count(m, c), Spec.count(k, c), ih)

def count_dropped_step(-A: Data, +topic: String, +id: Nat, +x: A, +rest: List<&2, T.Sub<A>>, +d: Nat, +c: Nat, +t: String, hs: Bool, +ehs: {Nat.is_eq(id, d) == hs : Bool}, h: Bool, +eh: {Nat.is_eq(d, c) == h : Bool}, ih: {Spec.count(T.members_of(A, T.dropped(A, rest, d), t), c) == set_if(h, 0n, Spec.count(T.members_of(A, rest, t), c)) : Nat}) -> {Spec.count(T.members_of(A, T.keep(A, T.Sub{topic, id, x}, T.dropped(A, rest, d), hs), t), c) == set_if(h, 0n, Spec.count(T.pick(id, T.members_of(A, rest, t), String.eq(topic, t)), c)) : Nat}:
  match hs h:
    case True{} True{}: ih
    case True{} False{}:
      +same = nat_sound(id, d, ehs)
      +kf = Equal.trans(Bool, String.eq(topic, t) && Nat.is_eq(id, c), String.eq(topic, t) && Nat.is_eq(d, c), False{}, Equal.cong(Nat, Bool, v => String.eq(topic, t) && Nat.is_eq(v, c), id, d, same), and_false_r(String.eq(topic, t), Nat.is_eq(d, c), eh))
      fin_tf(id, T.members_of(A, rest, t), Spec.count(T.members_of(A, T.dropped(A, rest, d), t), c), String.eq(topic, t), c, kf, ih)
    case False{} True{}:
      +same = nat_sound(d, c, eh)
      +kf = Equal.trans(Bool, String.eq(topic, t) && Nat.is_eq(id, c), String.eq(topic, t) && Nat.is_eq(id, d), False{}, Equal.cong(Nat, Bool, v => String.eq(topic, t) && Nat.is_eq(id, v), c, d, Equal.sym(Nat, d, c, same)), and_false_r(String.eq(topic, t), Nat.is_eq(id, d), ehs))
      fin_ft(id, T.members_of(A, T.dropped(A, rest, d), t), String.eq(topic, t), c, kf, ih)
    case False{} False{}:
      fin_ff(id, T.members_of(A, T.dropped(A, rest, d), t), T.members_of(A, rest, t), String.eq(topic, t), c, ih)

def count_dropped(-A: Data, +s: List<&2, T.Sub<A>>, +d: Nat, +c: Nat, +t: String) -> {Spec.count(T.members_of(A, T.dropped(A, s, d), t), c) == set_if(Nat.is_eq(d, c), 0n, Spec.count(T.members_of(A, s, t), c)) : Nat}:
  match s:
    case Nil{}: count_nil(Nat.is_eq(d, c))
    case T.Sub{topic, id, x} <> rest:
      count_dropped_step(A, topic, id, x, rest, d, c, t, Nat.is_eq(id, d), {==}, Nat.is_eq(d, c), {==}, count_dropped(A, rest, d, c, t))

def count_subscribe(-A: Data, +s: List<&2, T.Sub<A>>, +d: Nat, +u: String, +x: A, +c: Nat, +t: String) -> {Spec.count(T.members_of(A, T.subscribe_subs(A, s, d, u, x), t), c) == set_if(String.eq(u, t) && Nat.is_eq(d, c), 1n, Spec.count(T.members_of(A, s, t), c)) : Nat}:
  +h = String.eq(u, t) && Nat.is_eq(d, c)
  +w = T.members_of(A, T.without(A, s, d, u), t)
  +n = Spec.count(T.members_of(A, s, t), c)
  Equal.trans(Nat, Spec.count(T.pick(d, w, String.eq(u, t)), c), Spec.tick(h, Spec.count(w, c)), set_if(h, 1n, n), count_pick(d, w, String.eq(u, t), c), Equal.trans(Nat, Spec.tick(h, Spec.count(w, c)), Spec.tick(h, set_if(h, 0n, n)), set_if(h, 1n, n), Equal.cong(Nat, Nat, k => Spec.tick(h, k), Spec.count(w, c), set_if(h, 0n, n), count_without(A, s, d, u, c, t)), tick_set(h, n)))

# ---- Histories ----

def tally_effect(op: Spec.Op, +c: Nat, +t: String, n: Nat) -> Nat:
  match op:
    case Spec.OpSubscribe{d, u}: set_if(String.eq(u, t) && Nat.is_eq(d, c), 1n, n)
    case Spec.OpUnsubscribe{d, u}: set_if(String.eq(u, t) && Nat.is_eq(d, c), 0n, n)
    case Spec.OpRemove{d}: set_if(Nat.is_eq(d, c), 0n, n)

def tally(ops: List<&2, Spec.Op>, +c: Nat, +t: String, n: Nat) -> Nat:
  match ops:
    case Nil{}: n
    case op <> rest: tally(rest, c, t, tally_effect(op, c, t, n))

def apply_count(-A: Data, +x: A, +r: T.Registry<A>, +op: Spec.Op, +c: Nat, +t: String) -> {Spec.count(T.members(A, Spec.apply(A, x, r, op), t), c) == tally_effect(op, c, t, Spec.count(T.members(A, r, t), c)) : Nat}:
  match r op:
    case T.Registry{next, s} Spec.OpSubscribe{d, u}: count_subscribe(A, s, d, u, x, c, t)
    case T.Registry{next, s} Spec.OpUnsubscribe{d, u}: count_without(A, s, d, u, c, t)
    case T.Registry{next, s} Spec.OpRemove{d}: count_dropped(A, s, d, c, t)

def replay_count(-A: Data, +x: A, +ops: List<&2, Spec.Op>, +r: T.Registry<A>, +c: Nat, +t: String) -> {Spec.count(T.members(A, Spec.replay_from(A, x, ops, r), t), c) == tally(ops, c, t, Spec.count(T.members(A, r, t), c)) : Nat}:
  match ops:
    case Nil{}: {==}
    case op <> rest:
      Equal.trans(Nat, Spec.count(T.members(A, Spec.replay_from(A, x, rest, Spec.apply(A, x, r, op)), t), c), tally(rest, c, t, Spec.count(T.members(A, Spec.apply(A, x, r, op), t), c)), tally(rest, c, t, tally_effect(op, c, t, Spec.count(T.members(A, r, t), c))), replay_count(A, x, rest, Spec.apply(A, x, r, op), c, t), Equal.cong(Nat, Nat, n => tally(rest, c, t, n), Spec.count(T.members(A, Spec.apply(A, x, r, op), t), c), tally_effect(op, c, t, Spec.count(T.members(A, r, t), c)), apply_count(A, x, r, op, c, t)))

def sub_once(+h: Bool, +b: Bool) -> {set_if(h, 1n, Spec.once(b)) == Spec.once(h || b) : Nat}:
  match h:
    case True{}: {==}
    case False{}: {==}

def unsub_once(+h: Bool, +b: Bool) -> {set_if(h, 0n, Spec.once(b)) == Spec.once(Bool.not(h) && b) : Nat}:
  match h:
    case True{}: {==}
    case False{}: {==}

def effect_once(+op: Spec.Op, +c: Nat, +t: String, +b: Bool) -> {tally_effect(op, c, t, Spec.once(b)) == Spec.once(Spec.effect(op, c, t, b)) : Nat}:
  match op:
    case Spec.OpSubscribe{d, u}: sub_once(String.eq(u, t) && Nat.is_eq(d, c), b)
    case Spec.OpUnsubscribe{d, u}: unsub_once(String.eq(u, t) && Nat.is_eq(d, c), b)
    case Spec.OpRemove{d}: unsub_once(Nat.is_eq(d, c), b)

def tally_once(+ops: List<&2, Spec.Op>, +c: Nat, +t: String, +b: Bool) -> {tally(ops, c, t, Spec.once(b)) == Spec.once(Spec.member(ops, c, t, b)) : Nat}:
  match ops:
    case Nil{}: {==}
    case op <> rest:
      Equal.trans(Nat, tally(rest, c, t, tally_effect(op, c, t, Spec.once(b))), tally(rest, c, t, Spec.once(Spec.effect(op, c, t, b))), Spec.once(Spec.member(rest, c, t, Spec.effect(op, c, t, b))), Equal.cong(Nat, Nat, n => tally(rest, c, t, n), tally_effect(op, c, t, Spec.once(b)), Spec.once(Spec.effect(op, c, t, b)), effect_once(op, c, t, b)), tally_once(rest, c, t, Spec.effect(op, c, t, b)))

def replay_once(-A: Data, +x: A, +ops: List<&2, Spec.Op>, +c: Nat, +t: String) -> {Spec.count(T.members(A, Spec.replay(A, x, ops), t), c) == Spec.once(Spec.member(ops, c, t, False{})) : Nat}:
  Equal.trans(Nat, Spec.count(T.members(A, Spec.replay(A, x, ops), t), c), tally(ops, c, t, 0n), Spec.once(Spec.member(ops, c, t, False{})), replay_count(A, x, ops, T.empty(A), c, t), tally_once(ops, c, t, False{}))

def pos_tick(+b: Bool, +n: Nat) -> {(b || positive(n)) == positive(Spec.tick(b, n)) : Bool}:
  match b:
    case True{}: {==}
    case False{}: {==}

def pos_once(+b: Bool) -> {positive(Spec.once(b)) == b : Bool}:
  match b:
    case True{}: {==}
    case False{}: {==}

def has_count(+ids: List<&2, Nat>, +c: Nat) -> {Spec.has(ids, c) == positive(Spec.count(ids, c)) : Bool}:
  match ids:
    case Nil{}: {==}
    case h <> t:
      Equal.trans(Bool, Nat.is_eq(h, c) || Spec.has(t, c), Nat.is_eq(h, c) || positive(Spec.count(t, c)), positive(Spec.tick(Nat.is_eq(h, c), Spec.count(t, c))), Equal.cong(Bool, Bool, v => Nat.is_eq(h, c) || v, Spec.has(t, c), positive(Spec.count(t, c)), has_count(t, c)), pos_tick(Nat.is_eq(h, c), Spec.count(t, c)))

def L.ws_topics_registry_spec(A, x, ops, c, t):
  +m = T.members(A, Spec.replay(A, x, ops), t)
  +b = Spec.member(ops, c, t, False{})
  Equal.trans(Bool, Spec.has(m, c), positive(Spec.count(m, c)), b, has_count(m, c), Equal.trans(Bool, positive(Spec.count(m, c)), positive(Spec.once(b)), b, Equal.cong(Nat, Bool, n => positive(n), Spec.count(m, c), Spec.once(b), replay_once(A, x, ops, c, t)), pos_once(b)))

# ---- Each target once ----

def others_none(+ids: List<&2, Nat>) -> {Spec.others(ids, None{}) == ids : List<&2, Nat>}:
  match ids:
    case Nil{}: {==}
    case h <> t: Equal.cong(List<&2, Nat>, List<&2, Nat>, m => h <> m, Spec.others(t, None{}), t, others_none(t))

def count_some_step(+h: Nat, +t: List<&2, Nat>, +e: Nat, +c: Nat, hs: Bool, +ehs: {Nat.is_eq(h, e) == hs : Bool}, g: Bool, +eg: {Nat.is_eq(c, e) == g : Bool}, ih: {Spec.count(Spec.others(t, Some{e}), c) == set_if(g, 0n, Spec.count(t, c)) : Nat}) -> {Spec.count(Spec.skip(h, Spec.others(t, Some{e}), hs), c) == set_if(g, 0n, Spec.tick(Nat.is_eq(h, c), Spec.count(t, c))) : Nat}:
  match hs g:
    case True{} True{}: ih
    case True{} False{}:
      +kf = Equal.trans(Bool, Nat.is_eq(h, c), Nat.is_eq(e, c), False{}, Equal.cong(Nat, Bool, v => Nat.is_eq(v, c), h, e, nat_sound(h, e, ehs)), Equal.trans(Bool, Nat.is_eq(e, c), Nat.is_eq(c, e), False{}, nat_sym(e, c), eg))
      Equal.trans(Nat, Spec.count(Spec.others(t, Some{e}), c), Spec.count(t, c), Spec.tick(Nat.is_eq(h, c), Spec.count(t, c)), ih, Equal.sym(Nat, Spec.tick(Nat.is_eq(h, c), Spec.count(t, c)), Spec.count(t, c), tick_false(Nat.is_eq(h, c), Spec.count(t, c), kf)))
    case False{} True{}:
      +kf = Equal.trans(Bool, Nat.is_eq(h, c), Nat.is_eq(h, e), False{}, Equal.cong(Nat, Bool, v => Nat.is_eq(h, v), c, e, nat_sound(c, e, eg)), ehs)
      Equal.trans(Nat, Spec.tick(Nat.is_eq(h, c), Spec.count(Spec.others(t, Some{e}), c)), Spec.count(Spec.others(t, Some{e}), c), 0n, tick_false(Nat.is_eq(h, c), Spec.count(Spec.others(t, Some{e}), c), kf), ih)
    case False{} False{}:
      Equal.cong(Nat, Nat, n => Spec.tick(Nat.is_eq(h, c), n), Spec.count(Spec.others(t, Some{e}), c), Spec.count(t, c), ih)

def count_some(+ids: List<&2, Nat>, +e: Nat, +c: Nat) -> {Spec.count(Spec.others(ids, Some{e}), c) == set_if(Nat.is_eq(c, e), 0n, Spec.count(ids, c)) : Nat}:
  match ids:
    case Nil{}: count_nil(Nat.is_eq(c, e))
    case h <> t: count_some_step(h, t, e, c, Nat.is_eq(h, e), {==}, Nat.is_eq(c, e), {==}, count_some(t, e, c))

def count_others(+ex: Maybe<&2, Nat>, +ids: List<&2, Nat>, +c: Nat) -> {Spec.count(Spec.others(ids, ex), c) == set_if(Spec.sender(c, ex), 0n, Spec.count(ids, c)) : Nat}:
  match ex:
    case None{}: Equal.cong(List<&2, Nat>, Nat, l => Spec.count(l, c), Spec.others(ids, None{}), ids, others_none(ids))
    case Some{e}: count_some(ids, e, c)

def mask_once(+s: Bool, +m: Bool) -> {set_if(s, 0n, Spec.once(m)) == Spec.once(m && Bool.not(s)) : Nat}:
  match s m:
    case True{} True{}: {==}
    case True{} False{}: {==}
    case False{} True{}: {==}
    case False{} False{}: {==}

def L.ws_topics_publish_once(A, x, ops, c, t, sender):
  +r = Spec.replay(A, x, ops)
  +m = T.members(A, r, t)
  +b = Spec.member(ops, c, t, False{})
  +s = Spec.sender(c, sender)
  Equal.trans(Nat, Spec.count(T.target_ids(A, T.targets(A, r, t, sender)), c), Spec.count(Spec.others(m, sender), c), Spec.once(b && Bool.not(s)), Equal.cong(List<&2, Nat>, Nat, l => Spec.count(l, c), T.target_ids(A, T.targets(A, r, t, sender)), Spec.others(m, sender), targets_registry(A, r, t, sender)), Equal.trans(Nat, Spec.count(Spec.others(m, sender), c), set_if(s, 0n, Spec.count(m, c)), Spec.once(b && Bool.not(s)), count_others(sender, m, c), Equal.trans(Nat, set_if(s, 0n, Spec.count(m, c)), set_if(s, 0n, Spec.once(b)), Spec.once(b && Bool.not(s)), Equal.cong(Nat, Nat, n => set_if(s, 0n, n), Spec.count(m, c), Spec.once(b), replay_once(A, x, ops, c, t)), mask_once(s, b))))
