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
    case T.Registry{next, live, s}:
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
    case T.Registry{next, live, s}: unsub_gone(A, s, c, t)

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
    case T.Registry{next, live, s}: drop_gone(A, s, c, t)

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
    case T.Registry{next, live, s}:
      Equal.trans(List<&2, Nat>, T.pick(c, T.members_of(A, T.without(A, s, c, t), u), String.eq(t, u)), T.members_of(A, T.without(A, s, c, t), u), T.members_of(A, s, u), pick_false(c, T.members_of(A, T.without(A, s, c, t), u), String.eq(t, u), other), without_other(A, s, c, t, u, other))

def L.ws_topics_unsubscribe_independent(A, r, c, t, u, other):
  match r:
    case T.Registry{next, live, s}: without_other(A, s, c, t, u, other)

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
    case T.Registry{next, live, s}: targets_spec(A, s, t, ex)

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
    case T.Registry{next, live, s} Spec.OpSubscribe{d, u}: count_subscribe(A, s, d, u, x, c, t)
    case T.Registry{next, live, s} Spec.OpUnsubscribe{d, u}: count_without(A, s, d, u, c, t)
    case T.Registry{next, live, s} Spec.OpRemove{d}: count_dropped(A, s, d, c, t)

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

# ==== Review round 1: records, active IDs, allocator, well-formedness ====

# ---- More Bool facts ----

def or_right(+a: Bool, -b: Bool, eb: {b == True{} : Bool}) -> {(a || b) == True{} : Bool}:
  match a:
    case True{}: {==}
    case False{}: eb

def or_false_l(+a: Bool, -b: Bool, e: {(a || b) == False{} : Bool}) -> {a == False{} : Bool}:
  match a:
    case False{}: {==}
    case True{}: absurd({True{} == False{} : Bool}, false_true(Equal.sym(Bool, True{}, False{}, e)))

def or_false_r(+a: Bool, -b: Bool, e: {(a || b) == False{} : Bool}) -> {b == False{} : Bool}:
  match a:
    case False{}: e
    case True{}: absurd({b == False{} : Bool}, false_true(Equal.sym(Bool, True{}, False{}, e)))

def not_true(+a: Bool, e: {Bool.not(a) == True{} : Bool}) -> {a == False{} : Bool}:
  match a:
    case False{}: {==}
    case True{}: absurd({True{} == False{} : Bool}, false_true(e))

def not_false(+a: Bool, e: {a == False{} : Bool}) -> {Bool.not(a) == True{} : Bool}:
  match a:
    case False{}: {==}
    case True{}: absurd({Bool.not(True{}) == True{} : Bool}, false_true(Equal.sym(Bool, True{}, False{}, e)))

# ---- Nat order facts ----

def lt_succ(+n: Nat) -> {Nat.is_lt(n, 1n+n) == True{} : Bool}:
  match n:
    case 0n: {==}
    case 1n+m: lt_succ(m)

def lt_step(+a: Nat, +n: Nat, e: {Nat.is_lt(a, n) == True{} : Bool}) -> {Nat.is_lt(a, 1n+n) == True{} : Bool}:
  match a n:
    case 0n 0n: {==}
    case 0n 1n+q: {==}
    case 1n+p 0n: absurd({Nat.is_lt(1n+p, 1n) == True{} : Bool}, false_true(e))
    case 1n+p 1n+q: lt_step(p, q, e)

def lt_ne(+a: Nat, +b: Nat, e: {Nat.is_lt(a, b) == True{} : Bool}) -> {Nat.is_eq(a, b) == False{} : Bool}:
  match a b:
    case 0n 0n: absurd({Nat.is_eq(0n, 0n) == False{} : Bool}, false_true(e))
    case 0n 1n+q: {==}
    case 1n+p 0n: {==}
    case 1n+p 1n+q: lt_ne(p, q, e)

def lt_zero_ne(+n: Nat, e: {Nat.is_lt(0n, n) == True{} : Bool}) -> {Nat.is_eq(n, 0n) == False{} : Bool}:
  match n:
    case 0n: absurd({Nat.is_eq(0n, 0n) == False{} : Bool}, false_true(e))
    case 1n+m: {==}

# ---- Records ----

def put_same(-A: Data, +s: T.Sub<A>, +a: List<&2, T.Sub<A>>, +b: List<&2, T.Sub<A>>, k: Bool, e: {a == b : List<&2, T.Sub<A>>}) -> {List.filter.put(T.Sub<A>, s, a, k) == Spec.put_if(A, s, b, k) : List<&2, T.Sub<A>>}:
  match k:
    case True{}: Equal.cong(List<&2, T.Sub<A>>, List<&2, T.Sub<A>>, m => s <> m, a, b, e)
    case False{}: e

def select_step(-A: Data, +topic: String, +id: Nat, +x: A, +rest: List<&2, T.Sub<A>>, +t: String, +ex: Maybe<&2, Nat>, ih: {T.targets_of(A, rest, t, ex) == Spec.select(A, rest, t, ex) : List<&2, T.Sub<A>>}) -> {T.targets_of(A, T.Sub{topic, id, x} <> rest, t, ex) == Spec.select(A, T.Sub{topic, id, x} <> rest, t, ex) : List<&2, T.Sub<A>>}:
  match ex:
    case None{}: put_same(A, T.Sub{topic, id, x}, T.targets_of(A, rest, t, None{}), Spec.select(A, rest, t, None{}), String.eq(topic, t) && Bool.not(False{}), ih)
    case Some{e}: put_same(A, T.Sub{topic, id, x}, T.targets_of(A, rest, t, Some{e}), Spec.select(A, rest, t, Some{e}), String.eq(topic, t) && Bool.not(Nat.is_eq(id, e)), ih)

def targets_select(-A: Data, +s: List<&2, T.Sub<A>>, +t: String, +ex: Maybe<&2, Nat>) -> {T.targets_of(A, s, t, ex) == Spec.select(A, s, t, ex) : List<&2, T.Sub<A>>}:
  match s:
    case Nil{}: {==}
    case T.Sub{topic, id, x} <> rest: select_step(A, topic, id, x, rest, t, ex, targets_select(A, rest, t, ex))

def L.ws_topics_targets_records(A, r, t, sender):
  match r:
    case T.Registry{next, live, s}: targets_select(A, s, t, sender)

def members_paired(-A: Data, +s: List<&2, T.Sub<A>>, +c: Nat, +t: String) -> {Spec.has(T.members_of(A, s, t), c) == Spec.paired(A, s, c, t) : Bool}:
  match s:
    case Nil{}: {==}
    case T.Sub{topic, id, x} <> rest:
      Equal.trans(Bool, Spec.has(T.pick(id, T.members_of(A, rest, t), String.eq(topic, t)), c), (String.eq(topic, t) && Nat.is_eq(id, c)) || Spec.has(T.members_of(A, rest, t), c), (String.eq(topic, t) && Nat.is_eq(id, c)) || Spec.paired(A, rest, c, t), has_pick(id, T.members_of(A, rest, t), String.eq(topic, t), c), Equal.cong(Bool, Bool, v => (String.eq(topic, t) && Nat.is_eq(id, c)) || v, Spec.has(T.members_of(A, rest, t), c), Spec.paired(A, rest, c, t), members_paired(A, rest, c, t)))

def L.ws_topics_members_records(A, r, c, t):
  match r:
    case T.Registry{next, live, s}: members_paired(A, s, c, t)

def keep_put(-A: Data, +s: T.Sub<A>, +a: List<&2, T.Sub<A>>, +b: List<&2, T.Sub<A>>, k: Bool, e: {a == b : List<&2, T.Sub<A>>}) -> {T.keep(A, s, a, k) == Spec.put_if(A, s, b, Bool.not(k)) : List<&2, T.Sub<A>>}:
  match k:
    case True{}: e
    case False{}: Equal.cong(List<&2, T.Sub<A>>, List<&2, T.Sub<A>>, m => s <> m, a, b, e)

def without_unpaired(-A: Data, +s: List<&2, T.Sub<A>>, +c: Nat, +t: String) -> {T.without(A, s, c, t) == Spec.unpaired(A, s, c, t) : List<&2, T.Sub<A>>}:
  match s:
    case Nil{}: {==}
    case T.Sub{topic, id, x} <> rest: keep_put(A, T.Sub{topic, id, x}, T.without(A, rest, c, t), Spec.unpaired(A, rest, c, t), String.eq(topic, t) && Nat.is_eq(id, c), without_unpaired(A, rest, c, t))

def dropped_not_owned(-A: Data, +s: List<&2, T.Sub<A>>, +c: Nat) -> {T.dropped(A, s, c) == Spec.not_owned(A, s, c) : List<&2, T.Sub<A>>}:
  match s:
    case Nil{}: {==}
    case T.Sub{topic, id, x} <> rest: keep_put(A, T.Sub{topic, id, x}, T.dropped(A, rest, c), Spec.not_owned(A, rest, c), Nat.is_eq(id, c), dropped_not_owned(A, rest, c))

def L.ws_topics_subscribe_record(A, r, c, t, x):
  match r:
    case T.Registry{next, live, s}: Equal.cong(List<&2, T.Sub<A>>, List<&2, T.Sub<A>>, m => T.Sub{t, c, x} <> m, T.without(A, s, c, t), Spec.unpaired(A, s, c, t), without_unpaired(A, s, c, t))

def L.ws_topics_unsubscribe_record(A, r, c, t):
  match r:
    case T.Registry{next, live, s}: without_unpaired(A, s, c, t)

def L.ws_topics_remove_record(A, r, c):
  match r:
    case T.Registry{next, live, s}: dropped_not_owned(A, s, c)

def L.ws_topics_remove_next(A, r, c):
  match r:
    case T.Registry{next, live, s}: {==}

def found_true(-A: Data, +x: A, +m: Maybe<&2, A>, b: Bool, e: {b == True{} : Bool}) -> {Spec.found(A, x, m, b) == Some{x} : Maybe<&2, A>}:
  match b:
    case True{}: {==}
    case False{}: absurd({Spec.found(A, x, m, False{}) == Some{x} : Maybe<&2, A>}, false_true(e))

def L.ws_topics_subscribe_target(A, r, c, t, x):
  match r:
    case T.Registry{next, live, s}: found_true(A, x, Spec.find(A, T.without(A, s, c, t), c, t), String.eq(t, t) && Nat.is_eq(c, c), and_true(String.eq(t, t), Nat.is_eq(c, c), string_refl(t), nat_refl(c)))

def put_false(-A: Data, +s: T.Sub<A>, +m: List<&2, T.Sub<A>>, b: Bool, e: {b == False{} : Bool}) -> {Spec.put_if(A, s, m, b) == m : List<&2, T.Sub<A>>}:
  match b:
    case False{}: {==}
    case True{}: absurd({Spec.put_if(A, s, m, True{}) == m : List<&2, T.Sub<A>>}, false_true(Equal.sym(Bool, True{}, False{}, e)))

def topic_step(-A: Data, +topic: String, +id: Nat, +x: A, +rest: List<&2, T.Sub<A>>, +c: Nat, +t: String, +u: String, +other: {String.eq(t, u) == False{} : Bool}, b: Bool, eb: {(String.eq(topic, t) && Nat.is_eq(id, c)) == b : Bool}, ih: {Spec.on_topic(A, T.without(A, rest, c, t), u) == Spec.on_topic(A, rest, u) : List<&2, T.Sub<A>>}) -> {Spec.on_topic(A, T.keep(A, T.Sub{topic, id, x}, T.without(A, rest, c, t), b), u) == Spec.put_if(A, T.Sub{topic, id, x}, Spec.on_topic(A, rest, u), String.eq(topic, u)) : List<&2, T.Sub<A>>}:
  match b:
    case False{}:
      Equal.cong(List<&2, T.Sub<A>>, List<&2, T.Sub<A>>, m => Spec.put_if(A, T.Sub{topic, id, x}, m, String.eq(topic, u)), Spec.on_topic(A, T.without(A, rest, c, t), u), Spec.on_topic(A, rest, u), ih)
    case True{}:
      +same = JS.string_sound(topic, t, and_l(String.eq(topic, t), Nat.is_eq(id, c), eb))
      +ne = Equal.trans(Bool, String.eq(topic, u), String.eq(t, u), False{}, Equal.cong(String, Bool, v => String.eq(v, u), topic, t, same), other)
      Equal.trans(List<&2, T.Sub<A>>, Spec.on_topic(A, T.without(A, rest, c, t), u), Spec.on_topic(A, rest, u), Spec.put_if(A, T.Sub{topic, id, x}, Spec.on_topic(A, rest, u), String.eq(topic, u)), ih, Equal.sym(List<&2, T.Sub<A>>, Spec.put_if(A, T.Sub{topic, id, x}, Spec.on_topic(A, rest, u), String.eq(topic, u)), Spec.on_topic(A, rest, u), put_false(A, T.Sub{topic, id, x}, Spec.on_topic(A, rest, u), String.eq(topic, u), ne)))

def without_on_topic(-A: Data, +s: List<&2, T.Sub<A>>, +c: Nat, +t: String, +u: String, +other: {String.eq(t, u) == False{} : Bool}) -> {Spec.on_topic(A, T.without(A, s, c, t), u) == Spec.on_topic(A, s, u) : List<&2, T.Sub<A>>}:
  match s:
    case Nil{}: {==}
    case T.Sub{topic, id, x} <> rest:
      topic_step(A, topic, id, x, rest, c, t, u, other, String.eq(topic, t) && Nat.is_eq(id, c), {==}, without_on_topic(A, rest, c, t, u, other))

def L.ws_topics_subscribe_records_independent(A, r, c, t, u, x, other):
  match r:
    case T.Registry{next, live, s}:
      Equal.trans(List<&2, T.Sub<A>>, Spec.put_if(A, T.Sub{t, c, x}, Spec.on_topic(A, T.without(A, s, c, t), u), String.eq(t, u)), Spec.on_topic(A, T.without(A, s, c, t), u), Spec.on_topic(A, s, u), put_false(A, T.Sub{t, c, x}, Spec.on_topic(A, T.without(A, s, c, t), u), String.eq(t, u), other), without_on_topic(A, s, c, t, u, other))

def L.ws_topics_unsubscribe_records_independent(A, r, c, t, u, other):
  match r:
    case T.Registry{next, live, s}: without_on_topic(A, s, c, t, u, other)

# ---- Active IDs ----

def revoked_step(+h: Nat, +t: List<&2, Nat>, +c: Nat, k: Bool, ek: {Nat.is_eq(h, c) == k : Bool}, ih: {Spec.has(T.revoked(t, c), c) == False{} : Bool}) -> {Spec.has(T.pick(h, T.revoked(t, c), Bool.not(k)), c) == False{} : Bool}:
  match k:
    case True{}: ih
    case False{}: or_false(Nat.is_eq(h, c), Spec.has(T.revoked(t, c), c), ek, ih)

def revoked_gone(+ids: List<&2, Nat>, +c: Nat) -> {Spec.has(T.revoked(ids, c), c) == False{} : Bool}:
  match ids:
    case Nil{}: {==}
    case h <> t: revoked_step(h, t, c, Nat.is_eq(h, c), {==}, revoked_gone(t, c))

def remove_revokes_r(-A: Data, +r: T.Registry<A>, +c: Nat) -> {Spec.has(T.live(A, T.remove(A, r, c)), c) == False{} : Bool}:
  match r:
    case T.Registry{next, live, s}: revoked_gone(live, c)

def L.ws_topics_remove_revokes(A, r, c):
  remove_revokes_r(A, r, c)

def holds_has(+ids: List<&2, Nat>, +c: Nat) -> {T.holds(ids, c) == Spec.has(ids, c) : Bool}:
  match ids:
    case Nil{}: {==}
    case h <> t: Equal.cong(Bool, Bool, v => Nat.is_eq(h, c) || v, T.holds(t, c), Spec.has(t, c), holds_has(t, c))

def active_has(-A: Data, +r: T.Registry<A>, +c: Nat) -> {T.active(A, r, c) == Spec.has(T.live(A, r), c) : Bool}:
  match r:
    case T.Registry{next, live, s}: holds_has(live, c)

def admit_on(-A: Data, +r: T.Registry<A>, +c: Nat, +t: String, +x: A, k: Bool, ek: {k == True{} : Bool}) -> {T.admit_if(A, r, c, t, x, k) == T.subscribe(A, r, c, t, x) : T.Registry<A>}:
  match k:
    case True{}: {==}
    case False{}: absurd({T.admit_if(A, r, c, t, x, False{}) == T.subscribe(A, r, c, t, x) : T.Registry<A>}, false_true(ek))

def admit_off(-A: Data, +r: T.Registry<A>, +c: Nat, +t: String, +x: A, k: Bool, ek: {k == False{} : Bool}) -> {T.admit_if(A, r, c, t, x, k) == r : T.Registry<A>}:
  match k:
    case False{}: {==}
    case True{}: absurd({T.admit_if(A, r, c, t, x, True{}) == r : T.Registry<A>}, false_true(Equal.sym(Bool, True{}, False{}, ek)))

def admit_inactive_r(-A: Data, +r: T.Registry<A>, +c: Nat, +t: String, +x: A, inactive: {Spec.has(T.live(A, r), c) == False{} : Bool}) -> {T.admit(A, r, c, t, x) == r : T.Registry<A>}:
  admit_off(A, r, c, t, x, T.active(A, r, c), Equal.trans(Bool, T.active(A, r, c), Spec.has(T.live(A, r), c), False{}, active_has(A, r, c), inactive))

def L.ws_topics_admit_active(A, r, c, t, x, active):
  admit_on(A, r, c, t, x, T.active(A, r, c), Equal.trans(Bool, T.active(A, r, c), Spec.has(T.live(A, r), c), True{}, active_has(A, r, c), active))

def L.ws_topics_admit_inactive(A, r, c, t, x, inactive):
  admit_inactive_r(A, r, c, t, x, inactive)

def L.ws_topics_late_subscribe(A, r, c, t, x):
  admit_inactive_r(A, T.remove(A, r, c), c, t, x, remove_revokes_r(A, r, c))

# ---- Allocator ----

def L.ws_topics_join_next(A, r):
  match r:
    case T.Registry{next, live, s}: {==}

def L.ws_topics_join_id(A, r):
  match r:
    case T.Registry{next, live, s}: {==}

def L.ws_topics_join_subs(A, r):
  match r:
    case T.Registry{next, live, s}: {==}

def L.ws_topics_join_live(A, r):
  match r:
    case T.Registry{next, live, s}: {==}

# The four parts of Spec.wf.
def wf_d(-A: Data, +n: Nat, +l: List<&2, Nat>, +s: List<&2, T.Sub<A>>, w: {Spec.wf(A, T.Registry{n, l, s}) == True{} : Bool}) -> {Spec.distinct(A, s) == True{} : Bool}:
  and_l(Spec.distinct(A, s), Spec.covered(A, s, l), and_l(Spec.distinct(A, s) && Spec.covered(A, s, l), Spec.below(l, n), and_l((Spec.distinct(A, s) && Spec.covered(A, s, l)) && Spec.below(l, n), Nat.is_lt(0n, n), w)))

def wf_c(-A: Data, +n: Nat, +l: List<&2, Nat>, +s: List<&2, T.Sub<A>>, w: {Spec.wf(A, T.Registry{n, l, s}) == True{} : Bool}) -> {Spec.covered(A, s, l) == True{} : Bool}:
  and_r(Spec.distinct(A, s), Spec.covered(A, s, l), and_l(Spec.distinct(A, s) && Spec.covered(A, s, l), Spec.below(l, n), and_l((Spec.distinct(A, s) && Spec.covered(A, s, l)) && Spec.below(l, n), Nat.is_lt(0n, n), w)))

def wf_b(-A: Data, +n: Nat, +l: List<&2, Nat>, +s: List<&2, T.Sub<A>>, w: {Spec.wf(A, T.Registry{n, l, s}) == True{} : Bool}) -> {Spec.below(l, n) == True{} : Bool}:
  and_r(Spec.distinct(A, s) && Spec.covered(A, s, l), Spec.below(l, n), and_l((Spec.distinct(A, s) && Spec.covered(A, s, l)) && Spec.below(l, n), Nat.is_lt(0n, n), w))

def wf_p(-A: Data, +n: Nat, +l: List<&2, Nat>, +s: List<&2, T.Sub<A>>, w: {Spec.wf(A, T.Registry{n, l, s}) == True{} : Bool}) -> {Nat.is_lt(0n, n) == True{} : Bool}:
  and_r((Spec.distinct(A, s) && Spec.covered(A, s, l)) && Spec.below(l, n), Nat.is_lt(0n, n), w)

def wf_mk(-A: Data, +n: Nat, +l: List<&2, Nat>, +s: List<&2, T.Sub<A>>, d: {Spec.distinct(A, s) == True{} : Bool}, c: {Spec.covered(A, s, l) == True{} : Bool}, b: {Spec.below(l, n) == True{} : Bool}, p: {Nat.is_lt(0n, n) == True{} : Bool}) -> {Spec.wf(A, T.Registry{n, l, s}) == True{} : Bool}:
  and_true((Spec.distinct(A, s) && Spec.covered(A, s, l)) && Spec.below(l, n), Nat.is_lt(0n, n), and_true(Spec.distinct(A, s) && Spec.covered(A, s, l), Spec.below(l, n), and_true(Spec.distinct(A, s), Spec.covered(A, s, l), d, c), b), p)

def below_fresh(+ids: List<&2, Nat>, +n: Nat, +e: {Spec.below(ids, n) == True{} : Bool}) -> {Spec.has(ids, n) == False{} : Bool}:
  match ids:
    case Nil{}: {==}
    case h <> t: or_false(Nat.is_eq(h, n), Spec.has(t, n), lt_ne(h, n, and_l(Nat.is_lt(h, n), Spec.below(t, n), e)), below_fresh(t, n, and_r(Nat.is_lt(h, n), Spec.below(t, n), e)))

def id_out_k(+id: Nat, +c: Nat, +live: List<&2, Nat>, k: Bool, ek: {Nat.is_eq(id, c) == k : Bool}, inn: {Spec.has(live, id) == True{} : Bool}, out: {Spec.has(live, c) == False{} : Bool}) -> {k == False{} : Bool}:
  match k:
    case False{}: {==}
    case True{}:
      +same = nat_sound(id, c, ek)
      +moved = Equal.cong(Nat, Bool, v => Spec.has(live, v), id, c, same)
      +now = Equal.trans(Bool, Spec.has(live, c), Spec.has(live, id), True{}, Equal.sym(Bool, Spec.has(live, id), Spec.has(live, c), moved), inn)
      absurd({True{} == False{} : Bool}, false_true(Equal.trans(Bool, False{}, Spec.has(live, c), True{}, Equal.sym(Bool, Spec.has(live, c), False{}, out), now)))

def covered_ids(-A: Data, +s: List<&2, T.Sub<A>>, +live: List<&2, Nat>, +c: Nat, +cv: {Spec.covered(A, s, live) == True{} : Bool}, +out: {Spec.has(live, c) == False{} : Bool}) -> {Spec.has(Spec.ids(A, s), c) == False{} : Bool}:
  match s:
    case Nil{}: {==}
    case T.Sub{topic, id, x} <> rest:
      or_false(Nat.is_eq(id, c), Spec.has(Spec.ids(A, rest), c), id_out_k(id, c, live, Nat.is_eq(id, c), {==}, and_l(Spec.has(live, id), Spec.covered(A, rest, live), cv), out), covered_ids(A, rest, live, c, and_r(Spec.has(live, id), Spec.covered(A, rest, live), cv), out))

def L.ws_topics_join_positive(A, r, wf):
  match r:
    case T.Registry{next, live, s}: lt_zero_ne(next, wf_p(A, next, live, s, wf))

def L.ws_topics_join_fresh_live(A, r, wf):
  match r:
    case T.Registry{next, live, s}: below_fresh(live, next, wf_b(A, next, live, s, wf))

def L.ws_topics_join_fresh_subs(A, r, wf):
  match r:
    case T.Registry{next, live, s}: covered_ids(A, s, live, next, wf_c(A, next, live, s, wf), below_fresh(live, next, wf_b(A, next, live, s, wf)))

# ---- Invariant preservation ----

def unpaired_keep(-A: Data, +topic: String, +id: Nat, +x: A, +w: List<&2, T.Sub<A>>, +c: Nat, +t: String, b: Bool, hc: {(String.eq(topic, t) && Nat.is_eq(id, c)) == False{} : Bool}, ih: {Spec.paired(A, w, c, t) == False{} : Bool}) -> {Spec.paired(A, T.keep(A, T.Sub{topic, id, x}, w, b), c, t) == False{} : Bool}:
  match b:
    case True{}: ih
    case False{}: or_false(String.eq(topic, t) && Nat.is_eq(id, c), Spec.paired(A, w, c, t), hc, ih)

def unpaired_without(-A: Data, +s: List<&2, T.Sub<A>>, +d: Nat, +u: String, +c: Nat, +t: String, +e: {Spec.paired(A, s, c, t) == False{} : Bool}) -> {Spec.paired(A, T.without(A, s, d, u), c, t) == False{} : Bool}:
  match s:
    case Nil{}: {==}
    case T.Sub{topic, id, x} <> rest:
      unpaired_keep(A, topic, id, x, T.without(A, rest, d, u), c, t, String.eq(topic, u) && Nat.is_eq(id, d), or_false_l(String.eq(topic, t) && Nat.is_eq(id, c), Spec.paired(A, rest, c, t), e), unpaired_without(A, rest, d, u, c, t, or_false_r(String.eq(topic, t) && Nat.is_eq(id, c), Spec.paired(A, rest, c, t), e)))

def unpaired_dropped(-A: Data, +s: List<&2, T.Sub<A>>, +d: Nat, +c: Nat, +t: String, +e: {Spec.paired(A, s, c, t) == False{} : Bool}) -> {Spec.paired(A, T.dropped(A, s, d), c, t) == False{} : Bool}:
  match s:
    case Nil{}: {==}
    case T.Sub{topic, id, x} <> rest:
      unpaired_keep(A, topic, id, x, T.dropped(A, rest, d), c, t, Nat.is_eq(id, d), or_false_l(String.eq(topic, t) && Nat.is_eq(id, c), Spec.paired(A, rest, c, t), e), unpaired_dropped(A, rest, d, c, t, or_false_r(String.eq(topic, t) && Nat.is_eq(id, c), Spec.paired(A, rest, c, t), e)))

def distinct_keep(-A: Data, +topic: String, +id: Nat, +x: A, +w: List<&2, T.Sub<A>>, b: Bool, hd: {Bool.not(Spec.paired(A, w, id, topic)) == True{} : Bool}, ih: {Spec.distinct(A, w) == True{} : Bool}) -> {Spec.distinct(A, T.keep(A, T.Sub{topic, id, x}, w, b)) == True{} : Bool}:
  match b:
    case True{}: ih
    case False{}: and_true(Bool.not(Spec.paired(A, w, id, topic)), Spec.distinct(A, w), hd, ih)

def distinct_without(-A: Data, +s: List<&2, T.Sub<A>>, +d: Nat, +u: String, +e: {Spec.distinct(A, s) == True{} : Bool}) -> {Spec.distinct(A, T.without(A, s, d, u)) == True{} : Bool}:
  match s:
    case Nil{}: {==}
    case T.Sub{topic, id, x} <> rest:
      distinct_keep(A, topic, id, x, T.without(A, rest, d, u), String.eq(topic, u) && Nat.is_eq(id, d), not_false(Spec.paired(A, T.without(A, rest, d, u), id, topic), unpaired_without(A, rest, d, u, id, topic, not_true(Spec.paired(A, rest, id, topic), and_l(Bool.not(Spec.paired(A, rest, id, topic)), Spec.distinct(A, rest), e)))), distinct_without(A, rest, d, u, and_r(Bool.not(Spec.paired(A, rest, id, topic)), Spec.distinct(A, rest), e)))

def distinct_dropped(-A: Data, +s: List<&2, T.Sub<A>>, +d: Nat, +e: {Spec.distinct(A, s) == True{} : Bool}) -> {Spec.distinct(A, T.dropped(A, s, d)) == True{} : Bool}:
  match s:
    case Nil{}: {==}
    case T.Sub{topic, id, x} <> rest:
      distinct_keep(A, topic, id, x, T.dropped(A, rest, d), Nat.is_eq(id, d), not_false(Spec.paired(A, T.dropped(A, rest, d), id, topic), unpaired_dropped(A, rest, d, id, topic, not_true(Spec.paired(A, rest, id, topic), and_l(Bool.not(Spec.paired(A, rest, id, topic)), Spec.distinct(A, rest), e)))), distinct_dropped(A, rest, d, and_r(Bool.not(Spec.paired(A, rest, id, topic)), Spec.distinct(A, rest), e)))

def self_keep(-A: Data, +topic: String, +id: Nat, +x: A, +w: List<&2, T.Sub<A>>, +c: Nat, +t: String, b: Bool, eb: {(String.eq(topic, t) && Nat.is_eq(id, c)) == b : Bool}, ih: {Spec.paired(A, w, c, t) == False{} : Bool}) -> {Spec.paired(A, T.keep(A, T.Sub{topic, id, x}, w, b), c, t) == False{} : Bool}:
  match b:
    case True{}: ih
    case False{}: or_false(String.eq(topic, t) && Nat.is_eq(id, c), Spec.paired(A, w, c, t), eb, ih)

def without_self(-A: Data, +s: List<&2, T.Sub<A>>, +c: Nat, +t: String) -> {Spec.paired(A, T.without(A, s, c, t), c, t) == False{} : Bool}:
  match s:
    case Nil{}: {==}
    case T.Sub{topic, id, x} <> rest:
      self_keep(A, topic, id, x, T.without(A, rest, c, t), c, t, String.eq(topic, t) && Nat.is_eq(id, c), {==}, without_self(A, rest, c, t))

def covered_keep(-A: Data, +topic: String, +id: Nat, +x: A, +w: List<&2, T.Sub<A>>, +live: List<&2, Nat>, b: Bool, hc: {Spec.has(live, id) == True{} : Bool}, ih: {Spec.covered(A, w, live) == True{} : Bool}) -> {Spec.covered(A, T.keep(A, T.Sub{topic, id, x}, w, b), live) == True{} : Bool}:
  match b:
    case True{}: ih
    case False{}: and_true(Spec.has(live, id), Spec.covered(A, w, live), hc, ih)

def covered_without(-A: Data, +s: List<&2, T.Sub<A>>, +d: Nat, +u: String, +live: List<&2, Nat>, +e: {Spec.covered(A, s, live) == True{} : Bool}) -> {Spec.covered(A, T.without(A, s, d, u), live) == True{} : Bool}:
  match s:
    case Nil{}: {==}
    case T.Sub{topic, id, x} <> rest:
      covered_keep(A, topic, id, x, T.without(A, rest, d, u), live, String.eq(topic, u) && Nat.is_eq(id, d), and_l(Spec.has(live, id), Spec.covered(A, rest, live), e), covered_without(A, rest, d, u, live, and_r(Spec.has(live, id), Spec.covered(A, rest, live), e)))

def covered_cons(-A: Data, +s: List<&2, T.Sub<A>>, +n: Nat, +live: List<&2, Nat>, +e: {Spec.covered(A, s, live) == True{} : Bool}) -> {Spec.covered(A, s, n <> live) == True{} : Bool}:
  match s:
    case Nil{}: {==}
    case T.Sub{topic, id, x} <> rest:
      and_true(Spec.has(n <> live, id), Spec.covered(A, rest, n <> live), or_right(Nat.is_eq(n, id), Spec.has(live, id), and_l(Spec.has(live, id), Spec.covered(A, rest, live), e)), covered_cons(A, rest, n, live, and_r(Spec.has(live, id), Spec.covered(A, rest, live), e)))

def has_revoked_step(+h: Nat, +t: List<&2, Nat>, +c: Nat, +i: Nat, k: Bool, +ek: {Nat.is_eq(h, i) == k : Bool}, inn: {(k || Spec.has(t, i)) == True{} : Bool}, ne: {Nat.is_eq(i, c) == False{} : Bool}, ih: {Spec.has(t, i) == True{} : Bool} -> {Spec.has(T.revoked(t, c), i) == True{} : Bool}) -> {Spec.has(T.pick(h, T.revoked(t, c), Bool.not(Nat.is_eq(h, c))), i) == True{} : Bool}:
  match k:
    case True{}:
      +same = nat_sound(h, i, ek)
      +hc = Equal.trans(Bool, Nat.is_eq(h, c), Nat.is_eq(i, c), False{}, Equal.cong(Nat, Bool, v => Nat.is_eq(v, c), h, i, same), ne)
      Equal.trans(Bool, Spec.has(T.pick(h, T.revoked(t, c), Bool.not(Nat.is_eq(h, c))), i), (Bool.not(Nat.is_eq(h, c)) && Nat.is_eq(h, i)) || Spec.has(T.revoked(t, c), i), True{}, has_pick(h, T.revoked(t, c), Bool.not(Nat.is_eq(h, c)), i), or_left(Bool.not(Nat.is_eq(h, c)) && Nat.is_eq(h, i), Spec.has(T.revoked(t, c), i), and_true(Bool.not(Nat.is_eq(h, c)), Nat.is_eq(h, i), not_false(Nat.is_eq(h, c), hc), ek)))
    case False{}:
      Equal.trans(Bool, Spec.has(T.pick(h, T.revoked(t, c), Bool.not(Nat.is_eq(h, c))), i), (Bool.not(Nat.is_eq(h, c)) && Nat.is_eq(h, i)) || Spec.has(T.revoked(t, c), i), True{}, has_pick(h, T.revoked(t, c), Bool.not(Nat.is_eq(h, c)), i), or_right(Bool.not(Nat.is_eq(h, c)) && Nat.is_eq(h, i), Spec.has(T.revoked(t, c), i), ih(inn)))

def has_revoked(+live: List<&2, Nat>, +c: Nat, +i: Nat, inn: {Spec.has(live, i) == True{} : Bool}, +ne: {Nat.is_eq(i, c) == False{} : Bool}) -> {Spec.has(T.revoked(live, c), i) == True{} : Bool}:
  match live:
    case Nil{}: absurd({Spec.has(T.revoked([], c), i) == True{} : Bool}, false_true(inn))
    case h <> t: has_revoked_step(h, t, c, i, Nat.is_eq(h, i), {==}, inn, ne, e2 => has_revoked(t, c, i, e2, ne))

def covered_drop_step(-A: Data, +topic: String, +id: Nat, +x: A, +rest: List<&2, T.Sub<A>>, +c: Nat, +live: List<&2, Nat>, k: Bool, ek: {Nat.is_eq(id, c) == k : Bool}, hc: {Spec.has(live, id) == True{} : Bool}, ih: {Spec.covered(A, T.dropped(A, rest, c), T.revoked(live, c)) == True{} : Bool}) -> {Spec.covered(A, T.keep(A, T.Sub{topic, id, x}, T.dropped(A, rest, c), k), T.revoked(live, c)) == True{} : Bool}:
  match k:
    case True{}: ih
    case False{}: and_true(Spec.has(T.revoked(live, c), id), Spec.covered(A, T.dropped(A, rest, c), T.revoked(live, c)), has_revoked(live, c, id, hc, ek), ih)

def covered_dropped(-A: Data, +s: List<&2, T.Sub<A>>, +c: Nat, +live: List<&2, Nat>, +e: {Spec.covered(A, s, live) == True{} : Bool}) -> {Spec.covered(A, T.dropped(A, s, c), T.revoked(live, c)) == True{} : Bool}:
  match s:
    case Nil{}: {==}
    case T.Sub{topic, id, x} <> rest:
      covered_drop_step(A, topic, id, x, rest, c, live, Nat.is_eq(id, c), {==}, and_l(Spec.has(live, id), Spec.covered(A, rest, live), e), covered_dropped(A, rest, c, live, and_r(Spec.has(live, id), Spec.covered(A, rest, live), e)))

def below_pick(+h: Nat, +m: List<&2, Nat>, +n: Nat, k: Bool, hb: {Nat.is_lt(h, n) == True{} : Bool}, ih: {Spec.below(m, n) == True{} : Bool}) -> {Spec.below(T.pick(h, m, k), n) == True{} : Bool}:
  match k:
    case True{}: and_true(Nat.is_lt(h, n), Spec.below(m, n), hb, ih)
    case False{}: ih

def below_revoked(+ids: List<&2, Nat>, +c: Nat, +n: Nat, +e: {Spec.below(ids, n) == True{} : Bool}) -> {Spec.below(T.revoked(ids, c), n) == True{} : Bool}:
  match ids:
    case Nil{}: {==}
    case h <> t: below_pick(h, T.revoked(t, c), n, Bool.not(Nat.is_eq(h, c)), and_l(Nat.is_lt(h, n), Spec.below(t, n), e), below_revoked(t, c, n, and_r(Nat.is_lt(h, n), Spec.below(t, n), e)))

def below_step(+ids: List<&2, Nat>, +n: Nat, +e: {Spec.below(ids, n) == True{} : Bool}) -> {Spec.below(ids, 1n+n) == True{} : Bool}:
  match ids:
    case Nil{}: {==}
    case h <> t: and_true(Nat.is_lt(h, 1n+n), Spec.below(t, 1n+n), lt_step(h, n, and_l(Nat.is_lt(h, n), Spec.below(t, n), e)), below_step(t, n, and_r(Nat.is_lt(h, n), Spec.below(t, n), e)))

def wf_join_r(-A: Data, +r: T.Registry<A>, +w: {Spec.wf(A, r) == True{} : Bool}) -> {Spec.wf(A, T.join(A, r)) == True{} : Bool}:
  match r:
    case T.Registry{next, live, s}:
      wf_mk(A, 1n+next, next <> live, s, wf_d(A, next, live, s, w), covered_cons(A, s, next, live, wf_c(A, next, live, s, w)), and_true(Nat.is_lt(next, 1n+next), Spec.below(live, 1n+next), lt_succ(next), below_step(live, next, wf_b(A, next, live, s, w))), {==})

def wf_admit_k(-A: Data, +n: Nat, +l: List<&2, Nat>, +s: List<&2, T.Sub<A>>, +c: Nat, +t: String, +x: A, k: Bool, ek: {T.holds(l, c) == k : Bool}, +w: {Spec.wf(A, T.Registry{n, l, s}) == True{} : Bool}) -> {Spec.wf(A, T.admit_if(A, T.Registry{n, l, s}, c, t, x, k)) == True{} : Bool}:
  match k:
    case False{}: w
    case True{}:
      +on = Equal.trans(Bool, Spec.has(l, c), T.holds(l, c), True{}, Equal.sym(Bool, T.holds(l, c), Spec.has(l, c), holds_has(l, c)), ek)
      +ds = and_true(Bool.not(Spec.paired(A, T.without(A, s, c, t), c, t)), Spec.distinct(A, T.without(A, s, c, t)), not_false(Spec.paired(A, T.without(A, s, c, t), c, t), without_self(A, s, c, t)), distinct_without(A, s, c, t, wf_d(A, n, l, s, w)))
      +cs = and_true(Spec.has(l, c), Spec.covered(A, T.without(A, s, c, t), l), on, covered_without(A, s, c, t, l, wf_c(A, n, l, s, w)))
      wf_mk(A, n, l, T.Sub{t, c, x} <> T.without(A, s, c, t), ds, cs, wf_b(A, n, l, s, w), wf_p(A, n, l, s, w))

def wf_admit_r(-A: Data, +r: T.Registry<A>, +c: Nat, +t: String, +x: A, +w: {Spec.wf(A, r) == True{} : Bool}) -> {Spec.wf(A, T.admit(A, r, c, t, x)) == True{} : Bool}:
  match r:
    case T.Registry{next, live, s}: wf_admit_k(A, next, live, s, c, t, x, T.holds(live, c), {==}, w)

def wf_unsubscribe_r(-A: Data, +r: T.Registry<A>, +c: Nat, +t: String, +w: {Spec.wf(A, r) == True{} : Bool}) -> {Spec.wf(A, T.unsubscribe(A, r, c, t)) == True{} : Bool}:
  match r:
    case T.Registry{next, live, s}:
      wf_mk(A, next, live, T.without(A, s, c, t), distinct_without(A, s, c, t, wf_d(A, next, live, s, w)), covered_without(A, s, c, t, live, wf_c(A, next, live, s, w)), wf_b(A, next, live, s, w), wf_p(A, next, live, s, w))

def wf_remove_r(-A: Data, +r: T.Registry<A>, +c: Nat, +w: {Spec.wf(A, r) == True{} : Bool}) -> {Spec.wf(A, T.remove(A, r, c)) == True{} : Bool}:
  match r:
    case T.Registry{next, live, s}:
      wf_mk(A, next, T.revoked(live, c), T.dropped(A, s, c), distinct_dropped(A, s, c, wf_d(A, next, live, s, w)), covered_dropped(A, s, c, live, wf_c(A, next, live, s, w)), below_revoked(live, c, next, wf_b(A, next, live, s, w)), wf_p(A, next, live, s, w))

def wf_remove_all_r(-A: Data, +ids: List<&2, Nat>, +r: T.Registry<A>, +w: {Spec.wf(A, r) == True{} : Bool}) -> {Spec.wf(A, T.remove_all(A, ids, r)) == True{} : Bool}:
  match ids:
    case Nil{}: w
    case c <> rest: wf_remove_all_r(A, rest, T.remove(A, r, c), wf_remove_r(A, r, c, w))

def L.ws_topics_wf_empty(A):
  {==}

def L.ws_topics_wf_join(A, r, wf):
  wf_join_r(A, r, wf)

def L.ws_topics_wf_admit(A, r, c, t, x, wf):
  wf_admit_r(A, r, c, t, x, wf)

def L.ws_topics_wf_unsubscribe(A, r, c, t, wf):
  wf_unsubscribe_r(A, r, c, t, wf)

def L.ws_topics_wf_remove(A, r, c, wf):
  wf_remove_r(A, r, c, wf)

def L.ws_topics_wf_remove_all(A, ids, r, wf):
  wf_remove_all_r(A, ids, r, wf)

def change_wf(-A: Data, +r: T.Registry<A>, +ch: Spec.Change<A>, +w: {Spec.wf(A, r) == True{} : Bool}) -> {Spec.wf(A, Spec.change(A, r, ch)) == True{} : Bool}:
  match ch:
    case Spec.ChJoin{}: wf_join_r(A, r, w)
    case Spec.ChSubscribe{c, t, x}: wf_admit_r(A, r, c, t, x, w)
    case Spec.ChUnsubscribe{c, t}: wf_unsubscribe_r(A, r, c, t, w)
    case Spec.ChClose{c}: wf_remove_r(A, r, c, w)
    case Spec.ChPrune{gone}: wf_remove_all_r(A, gone, r, w)

def run_wf(-A: Data, +chs: List<&2, Spec.Change<A>>, +r: T.Registry<A>, +w: {Spec.wf(A, r) == True{} : Bool}) -> {Spec.wf(A, Spec.run_from(A, chs, r)) == True{} : Bool}:
  match chs:
    case Nil{}: w
    case ch <> rest: run_wf(A, rest, Spec.change(A, r, ch), change_wf(A, r, ch, w))

def history_wf(-A: Data, +chs: List<&2, Spec.Change<A>>) -> {Spec.wf(A, Spec.run(A, chs)) == True{} : Bool}:
  run_wf(A, chs, T.empty(A), {==})

def L.ws_topics_history_wf(A, chs):
  history_wf(A, chs)

# ---- Exactly-once selection ----

def once_step(-A: Data, +topic: String, +id: Nat, +rest: List<&2, T.Sub<A>>, +c: Nat, +t: String, h: Bool, +eh: {(String.eq(topic, t) && Nat.is_eq(id, c)) == h : Bool}, hd: {Spec.paired(A, rest, id, topic) == False{} : Bool}, ih: {Spec.count(T.members_of(A, rest, t), c) == Spec.once(Spec.paired(A, rest, c, t)) : Nat}) -> {Spec.tick(h, Spec.count(T.members_of(A, rest, t), c)) == Spec.once(h || Spec.paired(A, rest, c, t)) : Nat}:
  match h:
    case False{}: ih
    case True{}:
      +st = JS.string_sound(topic, t, and_l(String.eq(topic, t), Nat.is_eq(id, c), eh))
      +si = nat_sound(id, c, and_r(String.eq(topic, t), Nat.is_eq(id, c), eh))
      +moved = Equal.trans(Bool, Spec.paired(A, rest, id, topic), Spec.paired(A, rest, c, topic), Spec.paired(A, rest, c, t), Equal.cong(Nat, Bool, v => Spec.paired(A, rest, v, topic), id, c, si), Equal.cong(String, Bool, v => Spec.paired(A, rest, c, v), topic, t, st))
      +gone = Equal.trans(Bool, Spec.paired(A, rest, c, t), Spec.paired(A, rest, id, topic), False{}, Equal.sym(Bool, Spec.paired(A, rest, id, topic), Spec.paired(A, rest, c, t), moved), hd)
      +zero = Equal.trans(Nat, Spec.count(T.members_of(A, rest, t), c), Spec.once(Spec.paired(A, rest, c, t)), 0n, ih, Equal.cong(Bool, Nat, b => Spec.once(b), Spec.paired(A, rest, c, t), False{}, gone))
      Equal.cong(Nat, Nat, n => 1n+n, Spec.count(T.members_of(A, rest, t), c), 0n, zero)

def count_distinct(-A: Data, +s: List<&2, T.Sub<A>>, +c: Nat, +t: String, +d: {Spec.distinct(A, s) == True{} : Bool}) -> {Spec.count(T.members_of(A, s, t), c) == Spec.once(Spec.paired(A, s, c, t)) : Nat}:
  match s:
    case Nil{}: {==}
    case T.Sub{topic, id, x} <> rest:
      Equal.trans(Nat, Spec.count(T.pick(id, T.members_of(A, rest, t), String.eq(topic, t)), c), Spec.tick(String.eq(topic, t) && Nat.is_eq(id, c), Spec.count(T.members_of(A, rest, t), c)), Spec.once((String.eq(topic, t) && Nat.is_eq(id, c)) || Spec.paired(A, rest, c, t)), count_pick(id, T.members_of(A, rest, t), String.eq(topic, t), c), once_step(A, topic, id, rest, c, t, String.eq(topic, t) && Nat.is_eq(id, c), {==}, not_true(Spec.paired(A, rest, id, topic), and_l(Bool.not(Spec.paired(A, rest, id, topic)), Spec.distinct(A, rest), d)), count_distinct(A, rest, c, t, and_r(Bool.not(Spec.paired(A, rest, id, topic)), Spec.distinct(A, rest), d))))

def publish_once_wf_r(-A: Data, +r: T.Registry<A>, +c: Nat, +t: String, +sender: Maybe<&2, Nat>, +w: {Spec.wf(A, r) == True{} : Bool}) -> {Spec.count(T.target_ids(A, T.targets(A, r, t, sender)), c) == Spec.once(Spec.paired(A, T.subs(A, r), c, t) && Bool.not(Spec.sender(c, sender))) : Nat}:
  match r:
    case T.Registry{next, live, s}:
      +m = T.members_of(A, s, t)
      +p = Spec.paired(A, s, c, t)
      +q = Spec.sender(c, sender)
      Equal.trans(Nat, Spec.count(T.target_ids(A, T.targets_of(A, s, t, sender)), c), Spec.count(Spec.others(m, sender), c), Spec.once(p && Bool.not(q)), Equal.cong(List<&2, Nat>, Nat, ids => Spec.count(ids, c), T.target_ids(A, T.targets_of(A, s, t, sender)), Spec.others(m, sender), targets_spec(A, s, t, sender)), Equal.trans(Nat, Spec.count(Spec.others(m, sender), c), set_if(q, 0n, Spec.count(m, c)), Spec.once(p && Bool.not(q)), count_others(sender, m, c), Equal.trans(Nat, set_if(q, 0n, Spec.count(m, c)), set_if(q, 0n, Spec.once(p)), Spec.once(p && Bool.not(q)), Equal.cong(Nat, Nat, n => set_if(q, 0n, n), Spec.count(m, c), Spec.once(p), count_distinct(A, s, c, t, wf_d(A, next, live, s, w))), mask_once(q, p))))

def L.ws_topics_publish_once_wf(A, r, c, t, sender, wf):
  publish_once_wf_r(A, r, c, t, sender, wf)

def L.ws_topics_history_once(A, chs, c, t, sender):
  publish_once_wf_r(A, Spec.run(A, chs), c, t, sender, history_wf(A, chs))

# ---- Claims ----

# Removing anyone keeps an inactive ID inactive.
def has_revoked_out(+l: List<&2, Nat>, +b: Nat, +c: Nat, +e: {Spec.has(l, c) == False{} : Bool}) -> {Spec.has(T.revoked(l, b), c) == False{} : Bool}:
  match l:
    case Nil{}: {==}
    case h <> t:
      +hf = or_false_l(Nat.is_eq(h, c), Spec.has(t, c), e)
      +tf = or_false_r(Nat.is_eq(h, c), Spec.has(t, c), e)
      Equal.trans(Bool, Spec.has(T.pick(h, T.revoked(t, b), Bool.not(Nat.is_eq(h, b))), c), (Bool.not(Nat.is_eq(h, b)) && Nat.is_eq(h, c)) || Spec.has(T.revoked(t, b), c), False{}, has_pick(h, T.revoked(t, b), Bool.not(Nat.is_eq(h, b)), c), or_false(Bool.not(Nat.is_eq(h, b)) && Nat.is_eq(h, c), Spec.has(T.revoked(t, b), c), and_false_r(Bool.not(Nat.is_eq(h, b)), Nat.is_eq(h, c), hf), has_revoked_out(t, b, c, tf)))

def remove_out(-A: Data, +r: T.Registry<A>, +b: Nat, +c: Nat, +e: {Spec.has(T.live(A, r), c) == False{} : Bool}) -> {Spec.has(T.live(A, T.remove(A, r, b)), c) == False{} : Bool}:
  match r:
    case T.Registry{next, live, s}: has_revoked_out(live, b, c, e)

def remove_all_out(-A: Data, +ids: List<&2, Nat>, +r: T.Registry<A>, +c: Nat, +e: {Spec.has(T.live(A, r), c) == False{} : Bool}) -> {Spec.has(T.live(A, T.remove_all(A, ids, r)), c) == False{} : Bool}:
  match ids:
    case Nil{}: e
    case b <> rest: remove_all_out(A, rest, T.remove(A, r, b), c, remove_out(A, r, b, c, e))

def remove_self_out(-A: Data, +r: T.Registry<A>, +h: Nat, +c: Nat, +ek: {Nat.is_eq(h, c) == True{} : Bool}) -> {Spec.has(T.live(A, T.remove(A, r, h)), c) == False{} : Bool}:
  +same = nat_sound(h, c, ek)
  +moved = Equal.cong(Nat, Bool, v => Spec.has(T.live(A, T.remove(A, r, h)), v), h, c, same)
  Equal.trans(Bool, Spec.has(T.live(A, T.remove(A, r, h)), c), Spec.has(T.live(A, T.remove(A, r, h)), h), False{}, Equal.sym(Bool, Spec.has(T.live(A, T.remove(A, r, h)), h), Spec.has(T.live(A, T.remove(A, r, h)), c), moved), remove_revokes_r(A, r, h))

def remove_all_hit(-A: Data, +h: Nat, +rest: List<&2, Nat>, +r: T.Registry<A>, +c: Nat, k: Bool, +ek: {Nat.is_eq(h, c) == k : Bool}, held: {(k || Spec.has(rest, c)) == True{} : Bool}, ih: {Spec.has(rest, c) == True{} : Bool} -> {Spec.has(T.live(A, T.remove_all(A, rest, T.remove(A, r, h))), c) == False{} : Bool}) -> {Spec.has(T.live(A, T.remove_all(A, rest, T.remove(A, r, h))), c) == False{} : Bool}:
  match k:
    case True{}: remove_all_out(A, rest, T.remove(A, r, h), c, remove_self_out(A, r, h, c, ek))
    case False{}: ih(held)

# Removing a list of IDs revokes each of them.
def remove_all_revokes(-A: Data, +ids: List<&2, Nat>, +r: T.Registry<A>, +c: Nat, held: {Spec.has(ids, c) == True{} : Bool}) -> {Spec.has(T.live(A, T.remove_all(A, ids, r)), c) == False{} : Bool}:
  match ids:
    case Nil{}: absurd({Spec.has(T.live(A, T.remove_all(A, [], r)), c) == False{} : Bool}, false_true(held))
    case h <> rest: remove_all_hit(A, h, rest, r, c, Nat.is_eq(h, c), {==}, held, e => remove_all_revokes(A, rest, T.remove(A, r, h), c, e))

def zero_set(+b: Bool, +n: Nat, e: {n == 0n : Nat}) -> {set_if(b, 0n, n) == 0n : Nat}:
  match b:
    case True{}: {==}
    case False{}: e

def remove_zero(-A: Data, +r: T.Registry<A>, +d: Nat, +c: Nat, +t: String, e: {Spec.count(T.members(A, r, t), c) == 0n : Nat}) -> {Spec.count(T.members(A, T.remove(A, r, d), t), c) == 0n : Nat}:
  match r:
    case T.Registry{next, live, s}: Equal.trans(Nat, Spec.count(T.members_of(A, T.dropped(A, s, d), t), c), set_if(Nat.is_eq(d, c), 0n, Spec.count(T.members_of(A, s, t), c)), 0n, count_dropped(A, s, d, c, t), zero_set(Nat.is_eq(d, c), Spec.count(T.members_of(A, s, t), c), e))

def remove_self_zero(-A: Data, +r: T.Registry<A>, +d: Nat, +c: Nat, +t: String, ek: {Nat.is_eq(d, c) == True{} : Bool}) -> {Spec.count(T.members(A, T.remove(A, r, d), t), c) == 0n : Nat}:
  match r:
    case T.Registry{next, live, s}: Equal.trans(Nat, Spec.count(T.members_of(A, T.dropped(A, s, d), t), c), set_if(Nat.is_eq(d, c), 0n, Spec.count(T.members_of(A, s, t), c)), 0n, count_dropped(A, s, d, c, t), Equal.cong(Bool, Nat, b => set_if(b, 0n, Spec.count(T.members_of(A, s, t), c)), Nat.is_eq(d, c), True{}, ek))

def remove_all_zero(-A: Data, +ids: List<&2, Nat>, +r: T.Registry<A>, +c: Nat, +t: String, e: {Spec.count(T.members(A, r, t), c) == 0n : Nat}) -> {Spec.count(T.members(A, T.remove_all(A, ids, r), t), c) == 0n : Nat}:
  match ids:
    case Nil{}: e
    case b <> rest: remove_all_zero(A, rest, T.remove(A, r, b), c, t, remove_zero(A, r, b, c, t, e))

def remove_all_hit_zero(-A: Data, +h: Nat, +rest: List<&2, Nat>, +r: T.Registry<A>, +c: Nat, +t: String, k: Bool, +ek: {Nat.is_eq(h, c) == k : Bool}, held: {(k || Spec.has(rest, c)) == True{} : Bool}, ih: {Spec.has(rest, c) == True{} : Bool} -> {Spec.count(T.members(A, T.remove_all(A, rest, T.remove(A, r, h)), t), c) == 0n : Nat}) -> {Spec.count(T.members(A, T.remove_all(A, rest, T.remove(A, r, h)), t), c) == 0n : Nat}:
  match k:
    case True{}: remove_all_zero(A, rest, T.remove(A, r, h), c, t, remove_self_zero(A, r, h, c, t, ek))
    case False{}: ih(held)

def remove_all_drops(-A: Data, +ids: List<&2, Nat>, +r: T.Registry<A>, +c: Nat, +t: String, held: {Spec.has(ids, c) == True{} : Bool}) -> {Spec.count(T.members(A, T.remove_all(A, ids, r), t), c) == 0n : Nat}:
  match ids:
    case Nil{}: absurd({Spec.count(T.members(A, T.remove_all(A, [], r), t), c) == 0n : Nat}, false_true(held))
    case h <> rest: remove_all_hit_zero(A, h, rest, r, c, t, Nat.is_eq(h, c), {==}, held, e => remove_all_drops(A, rest, T.remove(A, r, h), c, t, e))

def L.ws_topics_claim_registry(A, l, k):
  match l:
    case T.Ledger{r, cs}:
      match r:
        case T.Registry{n, lv, s}: {==}

def claim_records_r(-A: Data, +l: T.Ledger<A>, +k: String) -> {T.claimed(T.claims(A, T.claim(A, l, k)), k) == T.next(A, T.registry(A, l)) <> T.claimed(T.claims(A, l), k) : List<&2, Nat>}:
  match l:
    case T.Ledger{r, cs}:
      match r:
        case T.Registry{n, lv, s}: Equal.cong(Bool, List<&2, Nat>, b => T.pick(n, T.claimed(cs, k), b), String.eq(k, k), True{}, string_refl(k))

def L.ws_topics_claim_records(A, l, k):
  claim_records_r(A, l, k)

def keeps_claims_r(-A: Data, +l: T.Ledger<A>, +ch: Spec.Change<A>) -> {T.claims(A, Spec.lift(A, l, ch)) == T.claims(A, l) : List<&2, T.Claim>}:
  match l:
    case T.Ledger{r, cs}: {==}

def L.ws_topics_change_keeps_claims(A, l, ch):
  keeps_claims_r(A, l, ch)

def release_revokes_r(-A: Data, +l: T.Ledger<A>, +k: String, +c: Nat, held: {Spec.has(T.claimed(T.claims(A, l), k), c) == True{} : Bool}) -> {Spec.has(T.live(A, T.registry(A, T.release(A, l, k))), c) == False{} : Bool}:
  match l:
    case T.Ledger{r, cs}: remove_all_revokes(A, T.claimed(cs, k), r, c, held)

def L.ws_topics_release_revokes(A, l, k, c, held):
  release_revokes_r(A, l, k, c, held)

def L.ws_topics_release_leaves(A, l, k, c, t, held):
  match l:
    case T.Ledger{r, cs}: Equal.trans(Bool, Spec.has(T.members(A, T.remove_all(A, T.claimed(cs, k), r), t), c), positive(Spec.count(T.members(A, T.remove_all(A, T.claimed(cs, k), r), t), c)), False{}, has_count(T.members(A, T.remove_all(A, T.claimed(cs, k), r), t), c), Equal.cong(Nat, Bool, n => positive(n), Spec.count(T.members(A, T.remove_all(A, T.claimed(cs, k), r), t), c), 0n, remove_all_drops(A, T.claimed(cs, k), r, c, t, held)))

def unclaims_step(+token: String, +id: Nat, +rest: List<&2, T.Claim>, +k: String, b: Bool, eb: {String.eq(token, k) == b : Bool}, ih: {T.claimed(T.unclaimed(rest, k), k) == [] : List<&2, Nat>}) -> {T.claimed(T.keep_claim(T.Claim{token, id}, T.unclaimed(rest, k), b), k) == [] : List<&2, Nat>}:
  match b:
    case True{}: ih
    case False{}: Equal.trans(List<&2, Nat>, T.pick(id, T.claimed(T.unclaimed(rest, k), k), String.eq(token, k)), T.claimed(T.unclaimed(rest, k), k), [], pick_false(id, T.claimed(T.unclaimed(rest, k), k), String.eq(token, k), eb), ih)

def unclaimed_gone(+cs: List<&2, T.Claim>, +k: String) -> {T.claimed(T.unclaimed(cs, k), k) == [] : List<&2, Nat>}:
  match cs:
    case Nil{}: {==}
    case T.Claim{token, id} <> rest: unclaims_step(token, id, rest, k, String.eq(token, k), {==}, unclaimed_gone(rest, k))

def L.ws_topics_release_unclaims(A, l, k):
  match l:
    case T.Ledger{r, cs}: unclaimed_gone(cs, k)

def play_changes_claims(-A: Data, +chs: List<&2, Spec.Change<A>>, +l: T.Ledger<A>) -> {T.claims(A, Spec.play_from(A, Spec.changes(A, chs), l)) == T.claims(A, l) : List<&2, T.Claim>}:
  match chs:
    case Nil{}: {==}
    case ch <> rest: Equal.trans(List<&2, T.Claim>, T.claims(A, Spec.play_from(A, Spec.changes(A, rest), Spec.lift(A, l, ch))), T.claims(A, Spec.lift(A, l, ch)), T.claims(A, l), play_changes_claims(A, rest, Spec.lift(A, l, ch)), keeps_claims_r(A, l, ch))

def L.ws_topics_late_join_released(A, l, k, chs):
  +all = Equal.trans(List<&2, Nat>, T.claimed(T.claims(A, Spec.play_from(A, Spec.changes(A, chs), T.claim(A, l, k))), k), T.claimed(T.claims(A, T.claim(A, l, k)), k), T.next(A, T.registry(A, l)) <> T.claimed(T.claims(A, l), k), Equal.cong(List<&2, T.Claim>, List<&2, Nat>, cs => T.claimed(cs, k), T.claims(A, Spec.play_from(A, Spec.changes(A, chs), T.claim(A, l, k))), T.claims(A, T.claim(A, l, k)), play_changes_claims(A, chs, T.claim(A, l, k))), claim_records_r(A, l, k))
  +top = or_left(Nat.is_eq(T.next(A, T.registry(A, l)), T.next(A, T.registry(A, l))), Spec.has(T.claimed(T.claims(A, l), k), T.next(A, T.registry(A, l))), nat_refl(T.next(A, T.registry(A, l))))
  +held = Equal.trans(Bool, Spec.has(T.claimed(T.claims(A, Spec.play_from(A, Spec.changes(A, chs), T.claim(A, l, k))), k), T.next(A, T.registry(A, l))), Spec.has(T.next(A, T.registry(A, l)) <> T.claimed(T.claims(A, l), k), T.next(A, T.registry(A, l))), True{}, Equal.cong(List<&2, Nat>, Bool, xs => Spec.has(xs, T.next(A, T.registry(A, l))), T.claimed(T.claims(A, Spec.play_from(A, Spec.changes(A, chs), T.claim(A, l, k))), k), T.next(A, T.registry(A, l)) <> T.claimed(T.claims(A, l), k), all), top)
  release_revokes_r(A, Spec.play_from(A, Spec.changes(A, chs), T.claim(A, l, k)), k, T.next(A, T.registry(A, l)), held)

def wf_claim_r(-A: Data, +l: T.Ledger<A>, +k: String, +w: {Spec.wf(A, T.registry(A, l)) == True{} : Bool}) -> {Spec.wf(A, T.registry(A, T.claim(A, l, k))) == True{} : Bool}:
  match l:
    case T.Ledger{r, cs}:
      match r:
        case T.Registry{n, lv, s}: wf_join_r(A, T.Registry{n, lv, s}, w)

def wf_release_r(-A: Data, +l: T.Ledger<A>, +k: String, +w: {Spec.wf(A, T.registry(A, l)) == True{} : Bool}) -> {Spec.wf(A, T.registry(A, T.release(A, l, k))) == True{} : Bool}:
  match l:
    case T.Ledger{r, cs}: wf_remove_all_r(A, T.claimed(cs, k), r, w)

def L.ws_topics_wf_claim(A, l, k, wf):
  wf_claim_r(A, l, k, wf)

def L.ws_topics_wf_release(A, l, k, wf):
  wf_release_r(A, l, k, wf)

def lift_wf(-A: Data, +l: T.Ledger<A>, +ch: Spec.Change<A>, +w: {Spec.wf(A, T.registry(A, l)) == True{} : Bool}) -> {Spec.wf(A, T.registry(A, Spec.lift(A, l, ch))) == True{} : Bool}:
  match l:
    case T.Ledger{r, cs}: change_wf(A, r, ch, w)

def wf_prune_r(-A: Data, +l: T.Ledger<A>, +ids: List<&2, Nat>, +w: {Spec.wf(A, T.registry(A, l)) == True{} : Bool}) -> {Spec.wf(A, T.registry(A, T.prune(A, l, ids))) == True{} : Bool}:
  match l:
    case T.Ledger{r, cs}: wf_remove_all_r(A, ids, r, w)

def event_wf(-A: Data, +l: T.Ledger<A>, +ev: Spec.Step<A>, +w: {Spec.wf(A, T.registry(A, l)) == True{} : Bool}) -> {Spec.wf(A, T.registry(A, Spec.event(A, l, ev))) == True{} : Bool}:
  match ev:
    case Spec.EvChange{ch}: lift_wf(A, l, ch, w)
    case Spec.EvClaim{k}: wf_claim_r(A, l, k, w)
    case Spec.EvRelease{k}: wf_release_r(A, l, k, w)
    case Spec.EvPrune{gone}: wf_prune_r(A, l, gone, w)

def play_wf(-A: Data, +evs: List<&2, Spec.Step<A>>, +l: T.Ledger<A>, +w: {Spec.wf(A, T.registry(A, l)) == True{} : Bool}) -> {Spec.wf(A, T.registry(A, Spec.play_from(A, evs, l))) == True{} : Bool}:
  match evs:
    case Nil{}: w
    case ev <> rest: play_wf(A, rest, Spec.event(A, l, ev), event_wf(A, l, ev, w))

def L.ws_topics_ledger_history_wf(A, evs):
  play_wf(A, evs, T.ledger(A), {==})

# ==== BND-98: other tokens' claims, prunes, mixed ledger histories ====

# ---- More Bool facts ----

def and_false_l(+a: Bool, -b: Bool, ea: {a == False{} : Bool}) -> {(a && b) == False{} : Bool}:
  match a:
    case False{}: {==}
    case True{}: absurd({(True{} && b) == False{} : Bool}, false_true(Equal.sym(Bool, True{}, False{}, ea)))

def and_true_r(+a: Bool, -b: Bool, eb: {b == True{} : Bool}) -> {(a && b) == a : Bool}:
  match a:
    case True{}: eb
    case False{}: {==}

def or_resolve(+a: Bool, -b: Bool, e: {(a || b) == True{} : Bool}, ea: {a == False{} : Bool}) -> {b == True{} : Bool}:
  match a:
    case False{}: e
    case True{}: absurd({b == True{} : Bool}, false_true(Equal.sym(Bool, True{}, False{}, ea)))

def or_drop_l(+a: Bool, -b: Bool, ea: {a == False{} : Bool}) -> {(a || b) == b : Bool}:
  match a:
    case False{}: {==}
    case True{}: absurd({(True{} || b) == b : Bool}, false_true(Equal.sym(Bool, True{}, False{}, ea)))

def set_off(+h: Bool, +v: Nat, +n: Nat, e: {h == False{} : Bool}) -> {set_if(h, v, n) == n : Nat}:
  match h:
    case False{}: {==}
    case True{}: absurd({set_if(True{}, v, n) == n : Nat}, false_true(Equal.sym(Bool, True{}, False{}, e)))

# ---- Other tokens' claims ----

def L.ws_topics_claim_others(A, l, k, j, other):
  match l:
    case T.Ledger{r, cs}:
      match r:
        case T.Registry{n, lv, s}: pick_false(n, T.claimed(cs, j), String.eq(k, j), other)

def release_other_step(+token: String, +id: Nat, +rest: List<&2, T.Claim>, +k: String, +j: String, +other: {String.eq(k, j) == False{} : Bool}, b: Bool, eb: {String.eq(token, k) == b : Bool}, ih: {T.claimed(T.unclaimed(rest, k), j) == T.claimed(rest, j) : List<&2, Nat>}) -> {T.claimed(T.keep_claim(T.Claim{token, id}, T.unclaimed(rest, k), b), j) == T.pick(id, T.claimed(rest, j), String.eq(token, j)) : List<&2, Nat>}:
  match b:
    case False{}:
      Equal.cong(List<&2, Nat>, List<&2, Nat>, m => T.pick(id, m, String.eq(token, j)), T.claimed(T.unclaimed(rest, k), j), T.claimed(rest, j), ih)
    case True{}:
      +same = JS.string_sound(token, k, eb)
      +ne = Equal.trans(Bool, String.eq(token, j), String.eq(k, j), False{}, Equal.cong(String, Bool, v => String.eq(v, j), token, k, same), other)
      Equal.trans(List<&2, Nat>, T.claimed(T.unclaimed(rest, k), j), T.claimed(rest, j), T.pick(id, T.claimed(rest, j), String.eq(token, j)), ih, Equal.sym(List<&2, Nat>, T.pick(id, T.claimed(rest, j), String.eq(token, j)), T.claimed(rest, j), pick_false(id, T.claimed(rest, j), String.eq(token, j), ne)))

# Releasing k keeps the IDs claimed under any other token j.
def unclaimed_other(+cs: List<&2, T.Claim>, +k: String, +j: String, +other: {String.eq(k, j) == False{} : Bool}) -> {T.claimed(T.unclaimed(cs, k), j) == T.claimed(cs, j) : List<&2, Nat>}:
  match cs:
    case Nil{}: {==}
    case T.Claim{token, id} <> rest: release_other_step(token, id, rest, k, j, other, String.eq(token, k), {==}, unclaimed_other(rest, k, j, other))

def L.ws_topics_release_others(A, l, k, j, other):
  match l:
    case T.Ledger{r, cs}: unclaimed_other(cs, k, j, other)

# ---- Prune ----

def L.ws_topics_prune_registry(A, l, ids):
  match l:
    case T.Ledger{r, cs}: {==}

def outside_pick(+id: Nat, +m: List<&2, Nat>, +q: Bool, +gone: List<&2, Nat>) -> {Spec.outside(T.pick(id, m, q), gone) == T.pick(id, Spec.outside(m, gone), q && Bool.not(Spec.has(gone, id))) : List<&2, Nat>}:
  match q:
    case True{}: {==}
    case False{}: {==}

def prune_step(+token: String, +id: Nat, +rest: List<&2, T.Claim>, +gone: List<&2, Nat>, +k: String, b: Bool, eb: {T.holds(gone, id) == b : Bool}, ih: {T.claimed(T.unpruned(rest, gone), k) == Spec.outside(T.claimed(rest, k), gone) : List<&2, Nat>}) -> {T.claimed(T.keep_claim(T.Claim{token, id}, T.unpruned(rest, gone), b), k) == Spec.outside(T.pick(id, T.claimed(rest, k), String.eq(token, k)), gone) : List<&2, Nat>}:
  match b:
    case True{}:
      +q = String.eq(token, k)
      +w = Spec.outside(T.claimed(rest, k), gone)
      +hg = Equal.trans(Bool, Spec.has(gone, id), T.holds(gone, id), True{}, Equal.sym(Bool, T.holds(gone, id), Spec.has(gone, id), holds_has(gone, id)), eb)
      +off = and_false_r(q, Bool.not(Spec.has(gone, id)), Equal.cong(Bool, Bool, v => Bool.not(v), Spec.has(gone, id), True{}, hg))
      +rhs = Equal.trans(List<&2, Nat>, Spec.outside(T.pick(id, T.claimed(rest, k), q), gone), T.pick(id, w, q && Bool.not(Spec.has(gone, id))), w, outside_pick(id, T.claimed(rest, k), q, gone), pick_false(id, w, q && Bool.not(Spec.has(gone, id)), off))
      Equal.trans(List<&2, Nat>, T.claimed(T.unpruned(rest, gone), k), w, Spec.outside(T.pick(id, T.claimed(rest, k), q), gone), ih, Equal.sym(List<&2, Nat>, Spec.outside(T.pick(id, T.claimed(rest, k), q), gone), w, rhs))
    case False{}:
      +q = String.eq(token, k)
      +w = Spec.outside(T.claimed(rest, k), gone)
      +hg = Equal.trans(Bool, Spec.has(gone, id), T.holds(gone, id), False{}, Equal.sym(Bool, T.holds(gone, id), Spec.has(gone, id), holds_has(gone, id)), eb)
      +on = and_true_r(q, Bool.not(Spec.has(gone, id)), not_false(Spec.has(gone, id), hg))
      +rhs = Equal.trans(List<&2, Nat>, Spec.outside(T.pick(id, T.claimed(rest, k), q), gone), T.pick(id, w, q && Bool.not(Spec.has(gone, id))), T.pick(id, w, q), outside_pick(id, T.claimed(rest, k), q, gone), Equal.cong(Bool, List<&2, Nat>, v => T.pick(id, w, v), q && Bool.not(Spec.has(gone, id)), q, on))
      Equal.trans(List<&2, Nat>, T.pick(id, T.claimed(T.unpruned(rest, gone), k), q), T.pick(id, w, q), Spec.outside(T.pick(id, T.claimed(rest, k), q), gone), Equal.cong(List<&2, Nat>, List<&2, Nat>, m => T.pick(id, m, q), T.claimed(T.unpruned(rest, gone), k), w, ih), Equal.sym(List<&2, Nat>, Spec.outside(T.pick(id, T.claimed(rest, k), q), gone), T.pick(id, w, q), rhs))

def prune_claims_cs(+cs: List<&2, T.Claim>, +gone: List<&2, Nat>, +k: String) -> {T.claimed(T.unpruned(cs, gone), k) == Spec.outside(T.claimed(cs, k), gone) : List<&2, Nat>}:
  match cs:
    case Nil{}: {==}
    case T.Claim{token, id} <> rest: prune_step(token, id, rest, gone, k, T.holds(gone, id), {==}, prune_claims_cs(rest, gone, k))

def L.ws_topics_prune_claims(A, l, ids, k):
  match l:
    case T.Ledger{r, cs}: prune_claims_cs(cs, ids, k)

def outside_gone_step(+h: Nat, +t: List<&2, Nat>, +gone: List<&2, Nat>, +c: Nat, +gc: {Spec.has(gone, c) == True{} : Bool}, k: Bool, ek: {Nat.is_eq(h, c) == k : Bool}, ih: {Spec.has(Spec.outside(t, gone), c) == False{} : Bool}) -> {Spec.has(T.pick(h, Spec.outside(t, gone), Bool.not(Spec.has(gone, h))), c) == False{} : Bool}:
  match k:
    case False{}:
      Equal.trans(Bool, Spec.has(T.pick(h, Spec.outside(t, gone), Bool.not(Spec.has(gone, h))), c), (Bool.not(Spec.has(gone, h)) && Nat.is_eq(h, c)) || Spec.has(Spec.outside(t, gone), c), False{}, has_pick(h, Spec.outside(t, gone), Bool.not(Spec.has(gone, h)), c), or_false(Bool.not(Spec.has(gone, h)) && Nat.is_eq(h, c), Spec.has(Spec.outside(t, gone), c), and_false_r(Bool.not(Spec.has(gone, h)), Nat.is_eq(h, c), ek), ih))
    case True{}:
      +same = nat_sound(h, c, ek)
      +hg = Equal.trans(Bool, Spec.has(gone, h), Spec.has(gone, c), True{}, Equal.cong(Nat, Bool, v => Spec.has(gone, v), h, c, same), gc)
      +nf = Equal.cong(Bool, Bool, v => Bool.not(v), Spec.has(gone, h), True{}, hg)
      Equal.trans(Bool, Spec.has(T.pick(h, Spec.outside(t, gone), Bool.not(Spec.has(gone, h))), c), (Bool.not(Spec.has(gone, h)) && Nat.is_eq(h, c)) || Spec.has(Spec.outside(t, gone), c), False{}, has_pick(h, Spec.outside(t, gone), Bool.not(Spec.has(gone, h)), c), or_false(Bool.not(Spec.has(gone, h)) && Nat.is_eq(h, c), Spec.has(Spec.outside(t, gone), c), and_false_l(Bool.not(Spec.has(gone, h)), Nat.is_eq(h, c), nf), ih))

# A pruned ID is not left in the list.
def outside_gone(+xs: List<&2, Nat>, +gone: List<&2, Nat>, +c: Nat, +gc: {Spec.has(gone, c) == True{} : Bool}) -> {Spec.has(Spec.outside(xs, gone), c) == False{} : Bool}:
  match xs:
    case Nil{}: {==}
    case h <> t: outside_gone_step(h, t, gone, c, gc, Nat.is_eq(h, c), {==}, outside_gone(t, gone, c, gc))

def L.ws_topics_prune_unclaims(A, l, ids, k, c, gone):
  match l:
    case T.Ledger{r, cs}: Equal.trans(Bool, Spec.has(T.claimed(T.unpruned(cs, ids), k), c), Spec.has(Spec.outside(T.claimed(cs, k), ids), c), False{}, Equal.cong(List<&2, Nat>, Bool, xs => Spec.has(xs, c), T.claimed(T.unpruned(cs, ids), k), Spec.outside(T.claimed(cs, k), ids), prune_claims_cs(cs, ids, k)), outside_gone(T.claimed(cs, k), ids, c, gone))

def outside_keep_step(+h: Nat, +t: List<&2, Nat>, +gone: List<&2, Nat>, +c: Nat, +gc: {Spec.has(gone, c) == False{} : Bool}, k: Bool, +ek: {Nat.is_eq(h, c) == k : Bool}, ih: {Spec.has(Spec.outside(t, gone), c) == Spec.has(t, c) : Bool}) -> {Spec.has(T.pick(h, Spec.outside(t, gone), Bool.not(Spec.has(gone, h))), c) == (k || Spec.has(t, c)) : Bool}:
  match k:
    case False{}:
      Equal.trans(Bool, Spec.has(T.pick(h, Spec.outside(t, gone), Bool.not(Spec.has(gone, h))), c), (Bool.not(Spec.has(gone, h)) && Nat.is_eq(h, c)) || Spec.has(Spec.outside(t, gone), c), Spec.has(t, c), has_pick(h, Spec.outside(t, gone), Bool.not(Spec.has(gone, h)), c), Equal.trans(Bool, (Bool.not(Spec.has(gone, h)) && Nat.is_eq(h, c)) || Spec.has(Spec.outside(t, gone), c), Spec.has(Spec.outside(t, gone), c), Spec.has(t, c), or_drop_l(Bool.not(Spec.has(gone, h)) && Nat.is_eq(h, c), Spec.has(Spec.outside(t, gone), c), and_false_r(Bool.not(Spec.has(gone, h)), Nat.is_eq(h, c), ek)), ih))
    case True{}:
      +same = nat_sound(h, c, ek)
      +hg = Equal.trans(Bool, Spec.has(gone, h), Spec.has(gone, c), False{}, Equal.cong(Nat, Bool, v => Spec.has(gone, v), h, c, same), gc)
      Equal.trans(Bool, Spec.has(T.pick(h, Spec.outside(t, gone), Bool.not(Spec.has(gone, h))), c), (Bool.not(Spec.has(gone, h)) && Nat.is_eq(h, c)) || Spec.has(Spec.outside(t, gone), c), True{}, has_pick(h, Spec.outside(t, gone), Bool.not(Spec.has(gone, h)), c), or_left(Bool.not(Spec.has(gone, h)) && Nat.is_eq(h, c), Spec.has(Spec.outside(t, gone), c), and_true(Bool.not(Spec.has(gone, h)), Nat.is_eq(h, c), not_false(Spec.has(gone, h), hg), ek)))

# An ID that was not pruned keeps its place.
def outside_keep(+xs: List<&2, Nat>, +gone: List<&2, Nat>, +c: Nat, +gc: {Spec.has(gone, c) == False{} : Bool}) -> {Spec.has(Spec.outside(xs, gone), c) == Spec.has(xs, c) : Bool}:
  match xs:
    case Nil{}: {==}
    case h <> t: outside_keep_step(h, t, gone, c, gc, Nat.is_eq(h, c), {==}, outside_keep(t, gone, c, gc))

def L.ws_topics_wf_prune(A, l, ids, wf):
  wf_prune_r(A, l, ids, wf)

# ---- A claimed ID through any ledger history ----

# What stays true of the ID `i` a claim under k got, seen from topic t: it is
# below `next`, and either still claimed under k or inactive and in no record
# for t.
def fate_held(cs: List<&2, T.Claim>, +k: String, +i: Nat) -> Bool:
  Spec.has(T.claimed(cs, k), i)

def fate_gone(-A: Data, +r: T.Registry<A>, +i: Nat, +t: String) -> Bool:
  Bool.not(Spec.has(T.live(A, r), i)) && Nat.is_eq(Spec.count(T.members(A, r, t), i), 0n)

def fate(-A: Data, +r: T.Registry<A>, +cs: List<&2, T.Claim>, +k: String, +i: Nat, +t: String) -> Bool:
  Nat.is_lt(i, T.next(A, r)) && (fate_held(cs, k, i) || fate_gone(A, r, i, t))

def fate_l(-A: Data, l: T.Ledger<A>, +k: String, +i: Nat, +t: String) -> Bool:
  match l:
    case T.Ledger{r, cs}: fate(A, r, cs, k, i, t)

def gone_mk(-A: Data, +r: T.Registry<A>, +i: Nat, +t: String, lf: {Spec.has(T.live(A, r), i) == False{} : Bool}, cz: {Spec.count(T.members(A, r, t), i) == 0n : Nat}) -> {fate_gone(A, r, i, t) == True{} : Bool}:
  and_true(Bool.not(Spec.has(T.live(A, r), i)), Nat.is_eq(Spec.count(T.members(A, r, t), i), 0n), not_false(Spec.has(T.live(A, r), i), lf), Equal.trans(Bool, Nat.is_eq(Spec.count(T.members(A, r, t), i), 0n), Nat.is_eq(0n, 0n), True{}, Equal.cong(Nat, Bool, n => Nat.is_eq(n, 0n), Spec.count(T.members(A, r, t), i), 0n, cz), {==}))

def gone_live(-A: Data, +r: T.Registry<A>, +i: Nat, +t: String, g: {fate_gone(A, r, i, t) == True{} : Bool}) -> {Spec.has(T.live(A, r), i) == False{} : Bool}:
  not_true(Spec.has(T.live(A, r), i), and_l(Bool.not(Spec.has(T.live(A, r), i)), Nat.is_eq(Spec.count(T.members(A, r, t), i), 0n), g))

def gone_zero(-A: Data, +r: T.Registry<A>, +i: Nat, +t: String, g: {fate_gone(A, r, i, t) == True{} : Bool}) -> {Spec.count(T.members(A, r, t), i) == 0n : Nat}:
  nat_sound(Spec.count(T.members(A, r, t), i), 0n, and_r(Bool.not(Spec.has(T.live(A, r), i)), Nat.is_eq(Spec.count(T.members(A, r, t), i), 0n), g))

def fate_split(-A: Data, +r: T.Registry<A>, +cs: List<&2, T.Claim>, +r2: T.Registry<A>, +cs2: List<&2, T.Claim>, +k: String, +i: Nat, +t: String, h: Bool, eh: {fate_held(cs, k, i) == h : Bool}, o: {(fate_held(cs, k, i) || fate_gone(A, r, i, t)) == True{} : Bool}, fh: {fate_held(cs, k, i) == True{} : Bool} -> {(fate_held(cs2, k, i) || fate_gone(A, r2, i, t)) == True{} : Bool}, fg: {fate_gone(A, r, i, t) == True{} : Bool} -> {fate_gone(A, r2, i, t) == True{} : Bool}) -> {(fate_held(cs2, k, i) || fate_gone(A, r2, i, t)) == True{} : Bool}:
  match h:
    case True{}: fh(eh)
    case False{}: or_right(fate_held(cs2, k, i), fate_gone(A, r2, i, t), fg(or_resolve(fate_held(cs, k, i), fate_gone(A, r, i, t), o, eh)))

# One ledger step keeps the fate, given the new `next` bound, what a held
# claim becomes, and that an inactive, unsubscribed ID stays so.
def fate_next(-A: Data, +r: T.Registry<A>, +cs: List<&2, T.Claim>, +r2: T.Registry<A>, +cs2: List<&2, T.Claim>, +k: String, +i: Nat, +t: String, e: {fate(A, r, cs, k, i, t) == True{} : Bool}, lt: {Nat.is_lt(i, T.next(A, r2)) == True{} : Bool}, fh: {fate_held(cs, k, i) == True{} : Bool} -> {(fate_held(cs2, k, i) || fate_gone(A, r2, i, t)) == True{} : Bool}, fg: {fate_gone(A, r, i, t) == True{} : Bool} -> {fate_gone(A, r2, i, t) == True{} : Bool}) -> {fate(A, r2, cs2, k, i, t) == True{} : Bool}:
  and_true(Nat.is_lt(i, T.next(A, r2)), fate_held(cs2, k, i) || fate_gone(A, r2, i, t), lt, fate_split(A, r, cs, r2, cs2, k, i, t, fate_held(cs, k, i), {==}, and_r(Nat.is_lt(i, T.next(A, r)), fate_held(cs, k, i) || fate_gone(A, r, i, t), e), fh, fg))

def lt_moved(-A: Data, +r: T.Registry<A>, +r2: T.Registry<A>, +i: Nat, nk: {T.next(A, r2) == T.next(A, r) : Nat}, lt: {Nat.is_lt(i, T.next(A, r)) == True{} : Bool}) -> {Nat.is_lt(i, T.next(A, r2)) == True{} : Bool}:
  Equal.trans(Bool, Nat.is_lt(i, T.next(A, r2)), Nat.is_lt(i, T.next(A, r)), True{}, Equal.cong(Nat, Bool, m => Nat.is_lt(i, m), T.next(A, r2), T.next(A, r), nk), lt)

# A registry change that keeps `next` and the claims.
def fate_keep(-A: Data, +r: T.Registry<A>, +cs: List<&2, T.Claim>, +r2: T.Registry<A>, +k: String, +i: Nat, +t: String, +e: {fate(A, r, cs, k, i, t) == True{} : Bool}, nk: {T.next(A, r2) == T.next(A, r) : Nat}, fg: {fate_gone(A, r, i, t) == True{} : Bool} -> {fate_gone(A, r2, i, t) == True{} : Bool}) -> {fate(A, r2, cs, k, i, t) == True{} : Bool}:
  +lt0 = and_l(Nat.is_lt(i, T.next(A, r)), fate_held(cs, k, i) || fate_gone(A, r, i, t), e)
  fate_next(A, r, cs, r2, cs, k, i, t, e, lt_moved(A, r, r2, i, nk, lt0), eh => or_left(fate_held(cs, k, i), fate_gone(A, r2, i, t), eh), fg)

def next_remove_r(-A: Data, +r: T.Registry<A>, +c: Nat) -> {T.next(A, T.remove(A, r, c)) == T.next(A, r) : Nat}:
  match r:
    case T.Registry{n, lv, s}: {==}

def next_remove_all(-A: Data, +ids: List<&2, Nat>, +r: T.Registry<A>) -> {T.next(A, T.remove_all(A, ids, r)) == T.next(A, r) : Nat}:
  match ids:
    case Nil{}: {==}
    case c <> rest: Equal.trans(Nat, T.next(A, T.remove_all(A, rest, T.remove(A, r, c))), T.next(A, T.remove(A, r, c)), T.next(A, r), next_remove_all(A, rest, T.remove(A, r, c)), next_remove_r(A, r, c))

def next_admit_if(-A: Data, +n: Nat, +lv: List<&2, Nat>, +s: List<&2, T.Sub<A>>, +c: Nat, +u: String, +x: A, b: Bool) -> {T.next(A, T.admit_if(A, T.Registry{n, lv, s}, c, u, x, b)) == n : Nat}:
  match b:
    case True{}: {==}
    case False{}: {==}

# A join hands out `next`, which differs from i.
def gone_join(-A: Data, +n: Nat, +lv: List<&2, Nat>, +s: List<&2, T.Sub<A>>, +i: Nat, +t: String, +lt0: {Nat.is_lt(i, n) == True{} : Bool}, +eg: {fate_gone(A, T.Registry{n, lv, s}, i, t) == True{} : Bool}) -> {fate_gone(A, T.Registry{1n+n, n <> lv, s}, i, t) == True{} : Bool}:
  +ne = Equal.trans(Bool, Nat.is_eq(n, i), Nat.is_eq(i, n), False{}, nat_sym(n, i), lt_ne(i, n, lt0))
  gone_mk(A, T.Registry{1n+n, n <> lv, s}, i, t, or_false(Nat.is_eq(n, i), Spec.has(lv, i), ne, gone_live(A, T.Registry{n, lv, s}, i, t, eg)), gone_zero(A, T.Registry{n, lv, s}, i, t, eg))

# Only an active connection subscribes, and i is not active.
def gone_admit(-A: Data, +n: Nat, +lv: List<&2, Nat>, +s: List<&2, T.Sub<A>>, +c: Nat, +u: String, +x: A, +i: Nat, +t: String, b: Bool, eb: {T.holds(lv, c) == b : Bool}, +eg: {fate_gone(A, T.Registry{n, lv, s}, i, t) == True{} : Bool}) -> {fate_gone(A, T.admit_if(A, T.Registry{n, lv, s}, c, u, x, b), i, t) == True{} : Bool}:
  match b:
    case False{}: eg
    case True{}:
      +out = gone_live(A, T.Registry{n, lv, s}, i, t, eg)
      +inn = Equal.trans(Bool, Spec.has(lv, c), T.holds(lv, c), True{}, Equal.sym(Bool, T.holds(lv, c), Spec.has(lv, c), holds_has(lv, c)), eb)
      +ci = id_out_k(c, i, lv, Nat.is_eq(c, i), {==}, inn, out)
      +h = String.eq(u, t) && Nat.is_eq(c, i)
      +m = Spec.count(T.members_of(A, s, t), i)
      +z = Equal.trans(Nat, Spec.count(T.members_of(A, T.subscribe_subs(A, s, c, u, x), t), i), set_if(h, 1n, m), 0n, count_subscribe(A, s, c, u, x, i, t), Equal.trans(Nat, set_if(h, 1n, m), m, 0n, set_off(h, 1n, m, and_false_r(String.eq(u, t), Nat.is_eq(c, i), ci)), gone_zero(A, T.Registry{n, lv, s}, i, t, eg)))
      gone_mk(A, T.Registry{n, lv, T.subscribe_subs(A, s, c, u, x)}, i, t, out, z)

def gone_unsub(-A: Data, +n: Nat, +lv: List<&2, Nat>, +s: List<&2, T.Sub<A>>, +c: Nat, +u: String, +i: Nat, +t: String, +eg: {fate_gone(A, T.Registry{n, lv, s}, i, t) == True{} : Bool}) -> {fate_gone(A, T.Registry{n, lv, T.without(A, s, c, u)}, i, t) == True{} : Bool}:
  +m = Spec.count(T.members_of(A, s, t), i)
  gone_mk(A, T.Registry{n, lv, T.without(A, s, c, u)}, i, t, gone_live(A, T.Registry{n, lv, s}, i, t, eg), Equal.trans(Nat, Spec.count(T.members_of(A, T.without(A, s, c, u), t), i), set_if(String.eq(u, t) && Nat.is_eq(c, i), 0n, m), 0n, count_without(A, s, c, u, i, t), zero_set(String.eq(u, t) && Nat.is_eq(c, i), m, gone_zero(A, T.Registry{n, lv, s}, i, t, eg))))

def gone_remove_all(-A: Data, +ids: List<&2, Nat>, +r: T.Registry<A>, +i: Nat, +t: String, +eg: {fate_gone(A, r, i, t) == True{} : Bool}) -> {fate_gone(A, T.remove_all(A, ids, r), i, t) == True{} : Bool}:
  gone_mk(A, T.remove_all(A, ids, r), i, t, remove_all_out(A, ids, r, i, gone_live(A, r, i, t, eg)), remove_all_zero(A, ids, r, i, t, gone_zero(A, r, i, t, eg)))

def fate_change(-A: Data, +r: T.Registry<A>, +cs: List<&2, T.Claim>, +ch: Spec.Change<A>, +k: String, +i: Nat, +t: String, +e: {fate(A, r, cs, k, i, t) == True{} : Bool}) -> {fate(A, Spec.change(A, r, ch), cs, k, i, t) == True{} : Bool}:
  match r:
    case T.Registry{n, lv, s}:
      match ch:
        case Spec.ChJoin{}:
          +lt0 = and_l(Nat.is_lt(i, n), fate_held(cs, k, i) || fate_gone(A, T.Registry{n, lv, s}, i, t), e)
          fate_next(A, T.Registry{n, lv, s}, cs, T.Registry{1n+n, n <> lv, s}, cs, k, i, t, e, lt_step(i, n, lt0), eh => or_left(fate_held(cs, k, i), fate_gone(A, T.Registry{1n+n, n <> lv, s}, i, t), eh), eg => gone_join(A, n, lv, s, i, t, lt0, eg))
        case Spec.ChSubscribe{c, u, x}:
          fate_keep(A, T.Registry{n, lv, s}, cs, T.admit(A, T.Registry{n, lv, s}, c, u, x), k, i, t, e, next_admit_if(A, n, lv, s, c, u, x, T.holds(lv, c)), eg => gone_admit(A, n, lv, s, c, u, x, i, t, T.holds(lv, c), {==}, eg))
        case Spec.ChUnsubscribe{c, u}:
          fate_keep(A, T.Registry{n, lv, s}, cs, T.unsubscribe(A, T.Registry{n, lv, s}, c, u), k, i, t, e, {==}, eg => gone_unsub(A, n, lv, s, c, u, i, t, eg))
        case Spec.ChClose{c}:
          fate_keep(A, T.Registry{n, lv, s}, cs, T.remove(A, T.Registry{n, lv, s}, c), k, i, t, e, {==}, eg => gone_remove_all(A, [c], T.Registry{n, lv, s}, i, t, eg))
        case Spec.ChPrune{gone}:
          fate_keep(A, T.Registry{n, lv, s}, cs, T.remove_all(A, gone, T.Registry{n, lv, s}), k, i, t, e, next_remove_all(A, gone, T.Registry{n, lv, s}), eg => gone_remove_all(A, gone, T.Registry{n, lv, s}, i, t, eg))

def held_claim(+n: Nat, +cs: List<&2, T.Claim>, +j: String, +k: String, +i: Nat, eh: {fate_held(cs, k, i) == True{} : Bool}) -> {fate_held(T.Claim{j, n} <> cs, k, i) == True{} : Bool}:
  Equal.trans(Bool, Spec.has(T.pick(n, T.claimed(cs, k), String.eq(j, k)), i), (String.eq(j, k) && Nat.is_eq(n, i)) || Spec.has(T.claimed(cs, k), i), True{}, has_pick(n, T.claimed(cs, k), String.eq(j, k), i), or_right(String.eq(j, k) && Nat.is_eq(n, i), Spec.has(T.claimed(cs, k), i), eh))

# Any token's claim: a join, and k's claims are kept.
def fate_claimed(-A: Data, +r: T.Registry<A>, +cs: List<&2, T.Claim>, +j: String, +k: String, +i: Nat, +t: String, +e: {fate(A, r, cs, k, i, t) == True{} : Bool}) -> {fate_l(A, T.claim(A, T.Ledger{r, cs}, j), k, i, t) == True{} : Bool}:
  match r:
    case T.Registry{n, lv, s}:
      +lt0 = and_l(Nat.is_lt(i, n), fate_held(cs, k, i) || fate_gone(A, T.Registry{n, lv, s}, i, t), e)
      fate_next(A, T.Registry{n, lv, s}, cs, T.Registry{1n+n, n <> lv, s}, T.Claim{j, n} <> cs, k, i, t, e, lt_step(i, n, lt0), eh => or_left(fate_held(T.Claim{j, n} <> cs, k, i), fate_gone(A, T.Registry{1n+n, n <> lv, s}, i, t), held_claim(n, cs, j, k, i, eh)), eg => gone_join(A, n, lv, s, i, t, lt0, eg))

# A release of another token keeps k's claims; a release of k revokes and
# unsubscribes every ID k holds.
def release_fate(-A: Data, +r: T.Registry<A>, +cs: List<&2, T.Claim>, +j: String, +k: String, +i: Nat, +t: String, q: Bool, ej: {String.eq(j, k) == q : Bool}, +eh: {fate_held(cs, k, i) == True{} : Bool}) -> {(fate_held(T.unclaimed(cs, j), k, i) || fate_gone(A, T.remove_all(A, T.claimed(cs, j), r), i, t)) == True{} : Bool}:
  match q:
    case False{}:
      or_left(fate_held(T.unclaimed(cs, j), k, i), fate_gone(A, T.remove_all(A, T.claimed(cs, j), r), i, t), Equal.trans(Bool, Spec.has(T.claimed(T.unclaimed(cs, j), k), i), Spec.has(T.claimed(cs, k), i), True{}, Equal.cong(List<&2, Nat>, Bool, xs => Spec.has(xs, i), T.claimed(T.unclaimed(cs, j), k), T.claimed(cs, k), unclaimed_other(cs, j, k, ej)), eh))
    case True{}:
      +same = JS.string_sound(j, k, ej)
      +hj = Equal.trans(Bool, Spec.has(T.claimed(cs, j), i), Spec.has(T.claimed(cs, k), i), True{}, Equal.cong(String, Bool, v => Spec.has(T.claimed(cs, v), i), j, k, same), eh)
      or_right(fate_held(T.unclaimed(cs, j), k, i), fate_gone(A, T.remove_all(A, T.claimed(cs, j), r), i, t), gone_mk(A, T.remove_all(A, T.claimed(cs, j), r), i, t, remove_all_revokes(A, T.claimed(cs, j), r, i, hj), remove_all_drops(A, T.claimed(cs, j), r, i, t, hj)))

def fate_released(-A: Data, +r: T.Registry<A>, +cs: List<&2, T.Claim>, +j: String, +k: String, +i: Nat, +t: String, +e: {fate(A, r, cs, k, i, t) == True{} : Bool}) -> {fate(A, T.remove_all(A, T.claimed(cs, j), r), T.unclaimed(cs, j), k, i, t) == True{} : Bool}:
  +lt0 = and_l(Nat.is_lt(i, T.next(A, r)), fate_held(cs, k, i) || fate_gone(A, r, i, t), e)
  fate_next(A, r, cs, T.remove_all(A, T.claimed(cs, j), r), T.unclaimed(cs, j), k, i, t, e, lt_moved(A, r, T.remove_all(A, T.claimed(cs, j), r), i, next_remove_all(A, T.claimed(cs, j), r), lt0), eh => release_fate(A, r, cs, j, k, i, t, String.eq(j, k), {==}, eh), eg => gone_remove_all(A, T.claimed(cs, j), r, i, t, eg))

# A prune of i revokes and unsubscribes it; any other prune keeps k's claim.
def prune_fate(-A: Data, +r: T.Registry<A>, +cs: List<&2, T.Claim>, +ids: List<&2, Nat>, +k: String, +i: Nat, +t: String, b: Bool, +eb: {Spec.has(ids, i) == b : Bool}, +eh: {fate_held(cs, k, i) == True{} : Bool}) -> {(fate_held(T.unpruned(cs, ids), k, i) || fate_gone(A, T.remove_all(A, ids, r), i, t)) == True{} : Bool}:
  match b:
    case True{}:
      or_right(fate_held(T.unpruned(cs, ids), k, i), fate_gone(A, T.remove_all(A, ids, r), i, t), gone_mk(A, T.remove_all(A, ids, r), i, t, remove_all_revokes(A, ids, r, i, eb), remove_all_drops(A, ids, r, i, t, eb)))
    case False{}:
      or_left(fate_held(T.unpruned(cs, ids), k, i), fate_gone(A, T.remove_all(A, ids, r), i, t), Equal.trans(Bool, Spec.has(T.claimed(T.unpruned(cs, ids), k), i), Spec.has(Spec.outside(T.claimed(cs, k), ids), i), True{}, Equal.cong(List<&2, Nat>, Bool, xs => Spec.has(xs, i), T.claimed(T.unpruned(cs, ids), k), Spec.outside(T.claimed(cs, k), ids), prune_claims_cs(cs, ids, k)), Equal.trans(Bool, Spec.has(Spec.outside(T.claimed(cs, k), ids), i), Spec.has(T.claimed(cs, k), i), True{}, outside_keep(T.claimed(cs, k), ids, i, eb), eh)))

def fate_pruned(-A: Data, +r: T.Registry<A>, +cs: List<&2, T.Claim>, +ids: List<&2, Nat>, +k: String, +i: Nat, +t: String, +e: {fate(A, r, cs, k, i, t) == True{} : Bool}) -> {fate(A, T.remove_all(A, ids, r), T.unpruned(cs, ids), k, i, t) == True{} : Bool}:
  +lt0 = and_l(Nat.is_lt(i, T.next(A, r)), fate_held(cs, k, i) || fate_gone(A, r, i, t), e)
  fate_next(A, r, cs, T.remove_all(A, ids, r), T.unpruned(cs, ids), k, i, t, e, lt_moved(A, r, T.remove_all(A, ids, r), i, next_remove_all(A, ids, r), lt0), eh => prune_fate(A, r, cs, ids, k, i, t, Spec.has(ids, i), {==}, eh), eg => gone_remove_all(A, ids, r, i, t, eg))

def fate_event(-A: Data, +r: T.Registry<A>, +cs: List<&2, T.Claim>, +ev: Spec.Step<A>, +k: String, +i: Nat, +t: String, +e: {fate(A, r, cs, k, i, t) == True{} : Bool}) -> {fate_l(A, Spec.event(A, T.Ledger{r, cs}, ev), k, i, t) == True{} : Bool}:
  match ev:
    case Spec.EvChange{ch}: fate_change(A, r, cs, ch, k, i, t, e)
    case Spec.EvClaim{j}: fate_claimed(A, r, cs, j, k, i, t, e)
    case Spec.EvRelease{j}: fate_released(A, r, cs, j, k, i, t, e)
    case Spec.EvPrune{ids}: fate_pruned(A, r, cs, ids, k, i, t, e)

def fate_event_l(-A: Data, +l: T.Ledger<A>, +ev: Spec.Step<A>, +k: String, +i: Nat, +t: String, e: {fate_l(A, l, k, i, t) == True{} : Bool}) -> {fate_l(A, Spec.event(A, l, ev), k, i, t) == True{} : Bool}:
  match l:
    case T.Ledger{r, cs}: fate_event(A, r, cs, ev, k, i, t, e)

def fate_play(-A: Data, +evs: List<&2, Spec.Step<A>>, +l: T.Ledger<A>, +k: String, +i: Nat, +t: String, e: {fate_l(A, l, k, i, t) == True{} : Bool}) -> {fate_l(A, Spec.play_from(A, evs, l), k, i, t) == True{} : Bool}:
  match evs:
    case Nil{}: e
    case ev <> rest: fate_play(A, rest, Spec.event(A, l, ev), k, i, t, fate_event_l(A, l, ev, k, i, t, e))

def fate_claim(-A: Data, +n: Nat, +lv: List<&2, Nat>, +s: List<&2, T.Sub<A>>, +cs: List<&2, T.Claim>, +k: String, +t: String) -> {fate(A, T.Registry{1n+n, n <> lv, s}, T.Claim{k, n} <> cs, k, n, t) == True{} : Bool}:
  +held = Equal.trans(Bool, Spec.has(T.pick(n, T.claimed(cs, k), String.eq(k, k)), n), (String.eq(k, k) && Nat.is_eq(n, n)) || Spec.has(T.claimed(cs, k), n), True{}, has_pick(n, T.claimed(cs, k), String.eq(k, k), n), or_left(String.eq(k, k) && Nat.is_eq(n, n), Spec.has(T.claimed(cs, k), n), and_true(String.eq(k, k), Nat.is_eq(n, n), string_refl(k), nat_refl(n))))
  and_true(Nat.is_lt(n, 1n+n), fate_held(T.Claim{k, n} <> cs, k, n) || fate_gone(A, T.Registry{1n+n, n <> lv, s}, n, t), lt_succ(n), or_left(fate_held(T.Claim{k, n} <> cs, k, n), fate_gone(A, T.Registry{1n+n, n <> lv, s}, n, t), held))

def fate_live_split(-A: Data, +r: T.Registry<A>, +cs: List<&2, T.Claim>, +k: String, +i: Nat, +t: String, h: Bool, eh: {fate_held(cs, k, i) == h : Bool}, o: {(fate_held(cs, k, i) || fate_gone(A, r, i, t)) == True{} : Bool}) -> {Spec.has(T.live(A, T.remove_all(A, T.claimed(cs, k), r)), i) == False{} : Bool}:
  match h:
    case True{}: remove_all_revokes(A, T.claimed(cs, k), r, i, eh)
    case False{}: remove_all_out(A, T.claimed(cs, k), r, i, gone_live(A, r, i, t, or_resolve(fate_held(cs, k, i), fate_gone(A, r, i, t), o, eh)))

def fate_count_split(-A: Data, +r: T.Registry<A>, +cs: List<&2, T.Claim>, +k: String, +i: Nat, +t: String, h: Bool, eh: {fate_held(cs, k, i) == h : Bool}, o: {(fate_held(cs, k, i) || fate_gone(A, r, i, t)) == True{} : Bool}) -> {Spec.count(T.members(A, T.remove_all(A, T.claimed(cs, k), r), t), i) == 0n : Nat}:
  match h:
    case True{}: remove_all_drops(A, T.claimed(cs, k), r, i, t, eh)
    case False{}: remove_all_zero(A, T.claimed(cs, k), r, i, t, gone_zero(A, r, i, t, or_resolve(fate_held(cs, k, i), fate_gone(A, r, i, t), o, eh)))

def fate_release_live(-A: Data, +l: T.Ledger<A>, +k: String, +i: Nat, +t: String, e: {fate_l(A, l, k, i, t) == True{} : Bool}) -> {Spec.has(T.live(A, T.registry(A, T.release(A, l, k))), i) == False{} : Bool}:
  match l:
    case T.Ledger{r, cs}: fate_live_split(A, r, cs, k, i, t, fate_held(cs, k, i), {==}, and_r(Nat.is_lt(i, T.next(A, r)), fate_held(cs, k, i) || fate_gone(A, r, i, t), e))

def fate_release_member(-A: Data, +l: T.Ledger<A>, +k: String, +i: Nat, +t: String, e: {fate_l(A, l, k, i, t) == True{} : Bool}) -> {Spec.has(T.members(A, T.registry(A, T.release(A, l, k)), t), i) == False{} : Bool}:
  match l:
    case T.Ledger{r, cs}:
      +m = T.members(A, T.remove_all(A, T.claimed(cs, k), r), t)
      Equal.trans(Bool, Spec.has(m, i), positive(Spec.count(m, i)), False{}, has_count(m, i), Equal.cong(Nat, Bool, n => positive(n), Spec.count(m, i), 0n, fate_count_split(A, r, cs, k, i, t, fate_held(cs, k, i), {==}, and_r(Nat.is_lt(i, T.next(A, r)), fate_held(cs, k, i) || fate_gone(A, r, i, t), e))))

def L.ws_topics_history_release_revokes(A, l, k, evs):
  match l:
    case T.Ledger{r, cs}:
      match r:
        case T.Registry{n, lv, s}:
          fate_release_live(A, Spec.play_from(A, evs, T.Ledger{T.Registry{1n+n, n <> lv, s}, T.Claim{k, n} <> cs}), k, n, "", fate_play(A, evs, T.Ledger{T.Registry{1n+n, n <> lv, s}, T.Claim{k, n} <> cs}, k, n, "", fate_claim(A, n, lv, s, cs, k, "")))

def L.ws_topics_history_release_leaves(A, l, k, evs, t):
  match l:
    case T.Ledger{r, cs}:
      match r:
        case T.Registry{n, lv, s}:
          fate_release_member(A, Spec.play_from(A, evs, T.Ledger{T.Registry{1n+n, n <> lv, s}, T.Claim{k, n} <> cs}), k, n, t, fate_play(A, evs, T.Ledger{T.Registry{1n+n, n <> lv, s}, T.Claim{k, n} <> cs}, k, n, t, fate_claim(A, n, lv, s, cs, k, t)))
