import os
import sys; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); import bits
o = []; w = o.append
w('''# Remaining BND-84 tail loops equal their recursive specs: Text.length and
# Text.join, Ip's address scans, the trailing-slash and authority
# paramorphisms, Conditional's entity-tag scans, Auth.escape and
# Media.before_params. Literal patterns are split bit by bit (generated).
# This module deliberately does not import LAWS.
import Base
import ../src/http/text.bend as T
import ../src/net/ip.bend as Ip
import ../src/http/origin.bend as O
import ../src/http/conditional.bend as Cond
import ../src/http/conditional-lex.bend as Lex
import ../src/http/media.bend as Media
import ../src/mw/auth_common.bend as A
import ../src/mw/trailing_slash_policy.bend as Ts
import ./text.bend as TP
import ../src/router/reverse-proofs.bend as Rev

def or_assoc(a: Bool, +b: Bool, +c: Bool) -> {(a || b) || c == a || (b || c) : Bool}:
  match a:
    case True{}:
      {==}
    case False{}:
      {==}

def and_assoc(a: Bool, +b: Bool, +c: Bool) -> {(a && b) && c == a && (b && c) : Bool}:
  match a:
    case True{}:
      {==}
    case False{}:
      {==}

def and_true(a: Bool) -> {a && True{} == a : Bool}:
  match a:
    case True{}:
      {==}
    case False{}:
      {==}

def or_false(a: Bool) -> {a || False{} == a : Bool}:
  match a:
    case True{}:
      {==}
    case False{}:
      {==}

# ---- Text.length ----

def add_succ(+a: Nat, +b: Nat) -> {Nat.add(a, 1n+b) == 1n+Nat.add(a, b) : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+p:
      Equal.cong(Nat, Nat, x => 1n+x, Nat.add(p, 1n+b), 1n+Nat.add(p, b), add_succ(p, b))

def add_zero(+a: Nat) -> {Nat.add(a, 0n) == a : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+p:
      Equal.cong(Nat, Nat, x => 1n+x, Nat.add(p, 0n), p, add_zero(p))

def length_go_equiv(-A: Data, +xs: List<&2, A>, +n: Nat) -> {T.length_go(A, xs, n) == Nat.add(List.length(&2, A, xs), n) : Nat}:
  match xs:
    case Nil{}:
      {==}
    case h <> t:
      Equal.trans(Nat, T.length_go(A, t, 1n+n), Nat.add(List.length(&2, A, t), 1n+n), 1n+Nat.add(List.length(&2, A, t), n), length_go_equiv(A, t, 1n+n), add_succ(List.length(&2, A, t), n))

def length_equiv(-A: Data, +xs: List<&2, A>) -> {T.length(A, xs) == List.length(&2, A, xs) : Nat}:
  Equal.trans(Nat, T.length(A, xs), Nat.add(List.length(&2, A, xs), 0n), List.length(&2, A, xs), length_go_equiv(A, xs, 0n), add_zero(List.length(&2, A, xs)))

# ---- Text.join ----

# ((acc ++ h) ++ sep) ++ j == acc ++ (h ++ (sep ++ j))
def join_shift(+acc: String, +h: String, +sep: String, +j: String) -> {String.append(String.append(String.append(acc, h), sep), j) == String.append(acc, String.append(h, String.append(sep, j))) : String}:
  Equal.trans(String, String.append(String.append(String.append(acc, h), sep), j), String.append(String.append(acc, h), String.append(sep, j)), String.append(acc, String.append(h, String.append(sep, j))), TP.string_append_assoc(String.append(acc, h), sep, j), TP.string_append_assoc(acc, h, String.append(sep, j)))

def join_go_equiv(+xs: List<&2, String>, +sep: String, +acc: String, +h: String) -> {T.join_go(xs, sep, String.append(acc, h)) == String.append(acc, String.join.go(xs, h, sep)) : String}:
  match xs:
    case Nil{}:
      {==}
    case h2 <> t:
      +a1 = String.append(String.append(acc, h), sep)
      e1 = TP.string_append_assoc(String.append(acc, h), sep, h2)
      %e1 : {T.join_go(t, sep, _) == String.append(acc, String.append(h, String.append(sep, String.join.go(t, h2, sep)))) : String}
      %join_shift(acc, h, sep, String.join.go(t, h2, sep)) : {T.join_go(t, sep, String.append(a1, h2)) == _ : String}
      join_go_equiv(t, sep, a1, h2)

def join_rev_claim(t: List<&2, String>, +x: String, +xs: List<&2, String>, +sep: String) -> {T.join_rev_go(t, sep, String.join.go(xs, x, sep)) == String.join(List.reverse.go(&2, String, t, x <> xs), sep) : String}:
  match t:
    case Nil{}: {==}
    case +y <> t2: join_rev_claim(t2, y, x <> xs, sep)

def join_reversed_equiv(+xs: List<&2, String>, +sep: String) -> {T.join_reversed(xs, sep) == String.join(List.reverse(&2, String, xs), sep) : String}:
  match xs:
    case Nil{}: {==}
    case +h <> +t: join_rev_claim(t, h, [], sep)

def join_equiv(+xs: List<&2, String>, +sep: String) -> {T.join(xs, sep) == String.join(xs, sep) : String}:
  Equal.trans(String, T.join(xs, sep), String.join(List.reverse(&2, String, List.reverse(&2, String, xs)), sep), String.join(xs, sep), join_reversed_equiv(List.reverse(&2, String, xs), sep), Equal.cong(List<&2, String>, String, ys => String.join(ys, sep), List.reverse(&2, String, List.reverse(&2, String, xs)), xs, Rev.list_twice(String, xs)))

# ---- Ip: left accumulators ----

def has_go_equiv(+xs: List<&2, U32>, +c: U32, +acc: Bool) -> {Ip.has_go(xs, c, acc) == acc || Ip.has_spec(xs, c) : Bool}:
  match xs:
    case Nil{}:
      Equal.sym(Bool, acc || False{}, acc, or_false(acc))
    case x <> t:
      Equal.trans(Bool, Ip.has_go(t, c, acc || U32.is_eq(x, c)), (acc || U32.is_eq(x, c)) || Ip.has_spec(t, c), acc || (U32.is_eq(x, c) || Ip.has_spec(t, c)), has_go_equiv(t, c, acc || U32.is_eq(x, c)), or_assoc(acc, U32.is_eq(x, c), Ip.has_spec(t, c)))

def has_equiv(+xs: List<&2, U32>, +c: U32) -> {Ip.has(xs, c) == Ip.has_spec(xs, c) : Bool}:
  has_go_equiv(xs, c, False{})
''')
for n, p in [("all_digits", "Ip.digit"), ("all_hex", "Ip.hex")]:
    w('''def %(n)s_go_equiv(+xs: List<&2, U32>, +acc: Bool) -> {Ip.%(n)s_go(xs, acc) == acc && Ip.%(n)s_spec(xs) : Bool}:
  match xs:
    case Nil{}:
      Equal.sym(Bool, acc && True{}, acc, and_true(acc))
    case +c <> t:
      Equal.trans(Bool, Ip.%(n)s_go(t, acc && %(p)s(c)), (acc && %(p)s(c)) && Ip.%(n)s_spec(t), acc && (%(p)s(c) && Ip.%(n)s_spec(t)), %(n)s_go_equiv(t, acc && %(p)s(c)), and_assoc(acc, %(p)s(c), Ip.%(n)s_spec(t)))

def %(n)s_equiv(+xs: List<&2, U32>) -> {Ip.%(n)s(xs) == Ip.%(n)s_spec(xs) : Bool}:
  %(n)s_go_equiv(xs, True{})
''' % dict(n=n, p=p))
w('''# ---- Ip.groups ----

def finish_push(g: Maybe<&2, U32>, done: Maybe<&2, List<&2, U32>>, rest: Maybe<&2, List<&2, U32>>) -> {Ip.groups_finish(Ip.groups_push(g, done), rest) == Ip.groups_finish(done, Ip.cons_group(g, rest)) : Maybe<&2, List<&2, U32>>}:
  match g done rest:
    case Some{x} Some{r} Some{xs}:
      {==}
    case Some{x} Some{r} None{}:
      {==}
    case Some{x} None{} Some{xs}:
      {==}
    case Some{x} None{} None{}:
      {==}
    case None{} Some{r} Some{xs}:
      {==}
    case None{} Some{r} None{}:
      {==}
    case None{} None{} Some{xs}:
      {==}
    case None{} None{} None{}:
      {==}

def finish_start(m: Maybe<&2, List<&2, U32>>) -> {Ip.groups_finish(Some{[]}, m) == m : Maybe<&2, List<&2, U32>>}:
  match m:
    case Some{xs}:
      {==}
    case None{}:
      {==}

def groups_go_equiv(+parts: List<&2, List<&2, U32>>, +tail: Bool, +done: Maybe<&2, List<&2, U32>>) -> {Ip.groups_go(parts, tail, done) == Ip.groups_finish(done, Ip.groups_spec(parts, tail)) : Maybe<&2, List<&2, U32>>}:
  match parts:
    case Nil{}:
      {==}
    case p <> Nil{}:
      {==}
    case p <> q <> u:
      Equal.trans(Maybe<&2, List<&2, U32>>, Ip.groups_go(q <> u, tail, Ip.groups_push(Ip.hex_group(p), done)), Ip.groups_finish(Ip.groups_push(Ip.hex_group(p), done), Ip.groups_spec(q <> u, tail)), Ip.groups_finish(done, Ip.cons_group(Ip.hex_group(p), Ip.groups_spec(q <> u, tail))), groups_go_equiv(q <> u, tail, Ip.groups_push(Ip.hex_group(p), done)), finish_push(Ip.hex_group(p), done, Ip.groups_spec(q <> u, tail)))

def groups_equiv(+parts: List<&2, List<&2, U32>>, +tail: Bool) -> {Ip.groups(parts, tail) == Ip.groups_spec(parts, tail) : Maybe<&2, List<&2, U32>>}:
  Equal.trans(Maybe<&2, List<&2, U32>>, Ip.groups(parts, tail), Ip.groups_finish(Some{[]}, Ip.groups_spec(parts, tail)), Ip.groups_spec(parts, tail), groups_go_equiv(parts, tail, Some{[]}), finish_start(Ip.groups_spec(parts, tail)))
''')
# paramorphisms: (module alias, impl, spec, go, ctor, res type, init res, pick expr)
for name, impl, spec, go, ctor, R, init, pick in [
    ("trim_last", "Ts.trim_last", "Ts.trim_last_spec", "Ts.trim_last_go", "Ts.Trimmed", "Maybe<&2, String>", "None{}", None),
    ("final_slash", "Ts.final_slash", "Ts.final_slash_spec", "Ts.final_slash_go", "Ts.Slashed", "Bool", "False{}", None),
    ("authority", "O.authority", "O.authority_spec", "O.authority_go", "O.Folded", "O.Cut", 'O.Cut{"", ""}', None)]:
    w('''def %(n)s_reverse(+s: String, +r: String, +ys: String) -> {%(go)s(String.reverse.go(s, r), %(ctor)s{ys, %(spec)s(ys)}) == %(go)s(r, %(ctor)s{String.append(s, ys), %(spec)s(String.append(s, ys))}) : %(R)s}:
  match s:
    case SNil{}:
      {==}
    case SCon{c, t}:
      %(n)s_reverse(t, SCon{c, r}, ys)

def %(n)s_equiv(+s: String) -> {%(impl)s(s) == %(spec)s(s) : %(R)s}:
  Equal.trans(%(R)s, %(impl)s(s), %(spec)s(String.append(s, "")), %(spec)s(s), %(n)s_reverse(s, "", ""), Equal.cong(String, %(R)s, x => %(spec)s(x), String.append(s, ""), s, TP.string_append_nil(s)))
''' % dict(n=name, impl=impl, spec=spec, go=go, ctor=ctor, R=R))
print("\n".join(o))

o2 = []; w = o2.append
w('''# ---- Media.before_params and Auth.escape: reversed output ----

def before_params_go_equiv(+s: String, +rev: String) -> {Media.before_params_go(s, rev) == String.reverse.go(rev, Media.before_params_spec(s)) : String}:
  match s:
    case SNil{}:
      {==}
    case SCon{';', t}:
      {==}''')
for p in bits.others([59]):
    w('''    case SCon{Chr{%s}, t}:
      before_params_go_equiv(t, SCon{Chr{%s}, rev})''' % (p, p))
w('''
def before_params_equiv(+s: String) -> {Media.before_params(s) == Media.before_params_spec(s) : String}:
  before_params_go_equiv(s, "")

def escape_go_equiv(+s: String, +rev: String) -> {A.escape_go(s, rev) == String.reverse.go(rev, A.escape_spec(s)) : String}:
  match s:
    case SNil{}:
      {==}
    case SCon{'"', t}:
      escape_go_equiv(t, SCon{'"', SCon{'\\\\', rev}})
    case SCon{'\\\\', t}:
      escape_go_equiv(t, SCon{'\\\\', SCon{'\\\\', rev}})''')
for p in bits.others([34, 92]):
    w('''    case SCon{Chr{%s}, t}:
      escape_go_equiv(t, SCon{Chr{%s}, rev})''' % (p, p))
w('''
def escape_equiv(+s: String) -> {A.escape(s) == A.escape_spec(s) : String}:
  escape_go_equiv(s, "")

# ---- Conditional.opaque ----

def gate(ok: Bool, m: Maybe<&2, String>) -> Maybe<&2, String>:
  match ok:
    case True{}: m
    case False{}: None{}

def opaque_nil(ok: Bool) -> {None{} == gate(ok, None{}) : Maybe<&2, String>}:
  match ok:
    case True{}:
      {==}
    case False{}:
      {==}

def opaque_last_case(+acc: String, ok: Bool, b: Bool, v: Bool) -> {Cond.opaque_end(acc, ok && b) == gate(ok, Cond.opaque_step(None{}, acc, b && True{}, v)) : Maybe<&2, String>}:
  match ok b v:
    case True{} True{} _:
      {==}
    case True{} False{} True{}:
      {==}
    case True{} False{} False{}:
      {==}
    case False{} _ _:
      {==}

def opaque_mid_case(+acc: String, ok: Bool, b: Bool, v: Bool, +x: Maybe<&2, String>) -> {gate(ok && v, x) == gate(ok, Cond.opaque_step(x, acc, b && False{}, v)) : Maybe<&2, String>}:
  match ok b v:
    case True{} True{} True{}:
      {==}
    case True{} True{} False{}:
      {==}
    case True{} False{} True{}:
      {==}
    case True{} False{} False{}:
      {==}
    case False{} True{} _:
      {==}
    case False{} False{} _:
      {==}

def opaque_go_equiv(+s: String, +acc: String, +ok: Bool) -> {Cond.opaque_go(s, acc, ok) == gate(ok, Cond.opaque_spec(s, acc)) : Maybe<&2, String>}:
  match s:
    case SNil{}:
      opaque_nil(ok)
    case SCon{Chr{c}, SNil{}}:
      opaque_last_case(acc, ok, U32.is_eq(c, 34), Lex.etagc(c))
    case SCon{Chr{c}, SCon{d, u}}:
      Equal.trans(Maybe<&2, String>, Cond.opaque_go(SCon{d, u}, SCon{Chr{c}, acc}, ok && Lex.etagc(c)), gate(ok && Lex.etagc(c), Cond.opaque_spec(SCon{d, u}, SCon{Chr{c}, acc})), gate(ok, Cond.opaque_step(Cond.opaque_spec(SCon{d, u}, SCon{Chr{c}, acc}), acc, U32.is_eq(c, 34) && False{}, Lex.etagc(c))), opaque_go_equiv(SCon{d, u}, SCon{Chr{c}, acc}, ok && Lex.etagc(c)), opaque_mid_case(acc, ok, U32.is_eq(c, 34), Lex.etagc(c), Cond.opaque_spec(SCon{d, u}, SCon{Chr{c}, acc})))

def opaque_equiv(+s: String, +acc: String) -> {Cond.opaque(s, acc) == Cond.opaque_spec(s, acc) : Maybe<&2, String>}:
  opaque_go_equiv(s, acc, True{})

# ---- Conditional.segments ----

def prepended_reverse(+done: List<&2, String>, +acc: String, cut: Bool, +x: List<&2, String>) -> {List.reverse.go(&2, String, Cond.prepended(done, acc, cut), x) == List.reverse.go(&2, String, done, Cond.prepended(x, acc, cut)) : List<&2, String>}:
  match cut:
    case True{}:
      {==}
    case False{}:
      {==}

def segments_go_equiv(+s: String, +q: Bool, +acc: String, +done: List<&2, String>) -> {Cond.segments_go(s, q, acc, done) == List.reverse.go(&2, String, done, Cond.segments_spec(s, q, acc)) : List<&2, String>}:
  match s:
    case SNil{}:
      {==}
    case SCon{Chr{c}, t}:
      +cut = U32.is_eq(c, 44) && Bool.not(q)
      +q2 = Cond.toggled(q, U32.is_eq(c, 34))
      +a2 = Cond.accumulated(Chr{c}, acc, cut)
      Equal.trans(List<&2, String>, Cond.segments_go(t, q2, a2, Cond.prepended(done, acc, cut)), List.reverse.go(&2, String, Cond.prepended(done, acc, cut), Cond.segments_spec(t, q2, a2)), List.reverse.go(&2, String, done, Cond.prepended(Cond.segments_spec(t, q2, a2), acc, cut)), segments_go_equiv(t, q2, a2, Cond.prepended(done, acc, cut)), prepended_reverse(done, acc, cut, Cond.segments_spec(t, q2, a2)))

def segments_equiv(+s: String, +q: Bool, +acc: String) -> {Cond.segments(s, q, acc) == Cond.segments_spec(s, q, acc) : List<&2, String>}:
  segments_go_equiv(s, q, acc, [])

# ---- Ip.doubles ----

def u32_append_assoc(+xs: List<&2, U32>, +ys: List<&2, U32>, +zs: List<&2, U32>) -> {List.append(&2, U32, List.append(&2, U32, xs, ys), zs) == List.append(&2, U32, xs, List.append(&2, U32, ys, zs)) : List<&2, U32>}:
  match xs:
    case Nil{}:
      {==}
    case h <> t:
      Equal.cong(List<&2, U32>, List<&2, U32>, x => h <> x, List.append(&2, U32, List.append(&2, U32, t, ys), zs), List.append(&2, U32, t, List.append(&2, U32, ys, zs)), u32_append_assoc(t, ys, zs))

def u32_reverse_snoc(+xs: List<&2, U32>, +acc: List<&2, U32>, +b: List<&2, U32>) -> {List.reverse.go(&2, U32, xs, List.append(&2, U32, acc, b)) == List.append(&2, U32, List.reverse.go(&2, U32, xs, acc), b) : List<&2, U32>}:
  match xs:
    case Nil{}:
      {==}
    case h <> t:
      u32_reverse_snoc(t, h <> acc, b)

def glue(p: List<&2, U32>, parts: List<&2, List<&2, U32>>) -> List<&2, List<&2, U32>>:
  match parts:
    case Nil{}:
      [p]
    case q <> qs:
      List.append(&2, U32, p, q) <> qs

def glue_push_empty(+c: U32, +parts: List<&2, List<&2, U32>>) -> {glue([], Ip.double_push(c, parts)) == Ip.double_push(c, parts) : List<&2, List<&2, U32>>}:
  match parts:
    case Nil{}:
      {==}
    case q <> qs:
      {==}

def glue_snoc(+rc: List<&2, U32>, +c: U32, +parts: List<&2, List<&2, U32>>) -> {glue(List.append(&2, U32, rc, [c]), parts) == glue(rc, Ip.double_push(c, parts)) : List<&2, List<&2, U32>>}:
  match parts:
    case Nil{}:
      {==}
    case q <> qs:
      Equal.cong(List<&2, U32>, List<&2, List<&2, U32>>, x => x <> qs, List.append(&2, U32, List.append(&2, U32, rc, [c]), q), List.append(&2, U32, rc, c <> q), u32_append_assoc(rc, [c], q))

def glue_empty(+xs: List<&2, U32>) -> {glue([], Ip.doubles_spec(xs)) == Ip.doubles_spec(xs) : List<&2, List<&2, U32>>}:
  match xs:
    case Nil{}:
      {==}
    case 58 <> 58 <> t:
      {==}
    case 58 <> Nil{}:
      glue_push_empty(58, Ip.doubles_spec([]))''')
for p in bits.others([58]):
    w('''    case 58 <> %s <> u:
      glue_push_empty(58, Ip.doubles_spec(%s <> u))''' % (p, p))
for p in bits.others([58]):
    w('''    case %s <> t:
      glue_push_empty(%s, Ip.doubles_spec(t))''' % (p, p))
w('''
def doubles_plain(+c: U32, +t: List<&2, U32>, +cur: List<&2, U32>, +done: List<&2, List<&2, U32>>, ih: {Ip.doubles_go(t, c <> cur, done) == List.reverse.go(&2, List<&2, U32>, done, glue(List.reverse(&2, U32, c <> cur), Ip.doubles_spec(t))) : List<&2, List<&2, U32>>}) -> {Ip.doubles_go(t, c <> cur, done) == List.reverse.go(&2, List<&2, U32>, done, glue(List.reverse(&2, U32, cur), Ip.double_push(c, Ip.doubles_spec(t)))) : List<&2, List<&2, U32>>}:
  %glue_snoc(List.reverse(&2, U32, cur), c, Ip.doubles_spec(t)) : {Ip.doubles_go(t, c <> cur, done) == List.reverse.go(&2, List<&2, U32>, done, _) : List<&2, List<&2, U32>>}
  %u32_reverse_snoc(cur, [], [c]) : {Ip.doubles_go(t, c <> cur, done) == List.reverse.go(&2, List<&2, U32>, done, glue(_, Ip.doubles_spec(t))) : List<&2, List<&2, U32>>}
  ih

def doubles_cut(+t: List<&2, U32>, +cur: List<&2, U32>, +done: List<&2, List<&2, U32>>, ih: {Ip.doubles_go(t, [], List.reverse(&2, U32, cur) <> done) == List.reverse.go(&2, List<&2, U32>, List.reverse(&2, U32, cur) <> done, glue([], Ip.doubles_spec(t))) : List<&2, List<&2, U32>>}) -> {Ip.doubles_go(t, [], List.reverse(&2, U32, cur) <> done) == List.reverse.go(&2, List<&2, U32>, done, glue(List.reverse(&2, U32, cur), [] <> Ip.doubles_spec(t))) : List<&2, List<&2, U32>>}:
  +rc = List.reverse(&2, U32, cur)
  %Equal.sym(List<&2, U32>, List.append(&2, U32, rc, []), rc, TP.list_append_nil(U32, rc)) : {Ip.doubles_go(t, [], rc <> done) == List.reverse.go(&2, List<&2, U32>, done, _ <> Ip.doubles_spec(t)) : List<&2, List<&2, U32>>}
  %glue_empty(t) : {Ip.doubles_go(t, [], rc <> done) == List.reverse.go(&2, List<&2, U32>, done, rc <> _) : List<&2, List<&2, U32>>}
  ih

def doubles_go_equiv(+xs: List<&2, U32>, +cur: List<&2, U32>, +done: List<&2, List<&2, U32>>) -> {Ip.doubles_go(xs, cur, done) == List.reverse.go(&2, List<&2, U32>, done, glue(List.reverse(&2, U32, cur), Ip.doubles_spec(xs))) : List<&2, List<&2, U32>>}:
  match xs:
    case Nil{}:
      Equal.cong(List<&2, U32>, List<&2, List<&2, U32>>, x => List.reverse.go(&2, List<&2, U32>, done, [x]), List.reverse(&2, U32, cur), List.append(&2, U32, List.reverse(&2, U32, cur), []), Equal.sym(List<&2, U32>, List.append(&2, U32, List.reverse(&2, U32, cur), []), List.reverse(&2, U32, cur), TP.list_append_nil(U32, List.reverse(&2, U32, cur))))
    case 58 <> 58 <> t:
      doubles_cut(t, cur, done, doubles_go_equiv(t, [], List.reverse(&2, U32, cur) <> done))
    case 58 <> Nil{}:
      doubles_plain(58, [], cur, done, doubles_go_equiv([], 58 <> cur, done))''')
for p in bits.others([58]):
    w('''    case 58 <> %s <> u:
      doubles_plain(58, %s <> u, cur, done, doubles_go_equiv(%s <> u, 58 <> cur, done))''' % (p, p, p))
for p in bits.others([58]):
    w('''    case %s <> t:
      doubles_plain(%s, t, cur, done, doubles_go_equiv(t, %s <> cur, done))''' % (p, p, p))
w('''
def doubles_equiv(+xs: List<&2, U32>) -> {Ip.doubles(xs) == Ip.doubles_spec(xs) : List<&2, List<&2, U32>>}:
  Equal.trans(List<&2, List<&2, U32>>, Ip.doubles(xs), glue([], Ip.doubles_spec(xs)), Ip.doubles_spec(xs), doubles_go_equiv(xs, [], []), glue_empty(xs))
''')
print("\n".join(o2))
