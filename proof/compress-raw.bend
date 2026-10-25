# BND-46: compression decisions from the raw request and response fields.
# Accept-Encoding parsing and selection equal proof/compress-spec.bend for
# every field list; already-compressed media is left alone; HEAD gets the
# plan GET would; and Keep never depends on Accept-Encoding.
import Base
import ../LAWS.bend as Laws
import ../src/mw/compress_policy.bend as P
import ../src/mw/vary.bend as Vary
import ../src/http/request.bend as Request
import ../src/http/response.bend as Response
import ../src/http/media.bend as Media
import ../src/http/bytes.bend as Bytes
import ./compress-spec.bend as S
import ./compress.bend as CP
import ./media-spec.bend as MediaSpec
import ./media.bend as MediaProof
import ./response-policy-spec.bend as RS
import ./response-policy.bend as RP

def absurd(-A: Type, +e: Empty) -> A:
  match e:

# ---------------------------------------------------------------- qvalues

def frac_none(+t: String, +scale: Nat) -> {P.frac_go(t, scale, None{}) == None{} : Maybe<&2, Nat>}:
  match t:
    case SNil{}: {==}
    case SCon{Chr{+c}, u}: frac_none(u, Nat.div(scale, 10n))

def frac_past(+n: Nat, +c: U32, +u: String, ok: Bool) -> {P.frac_go(u, Nat.div(0n, 10n), P.frac_add(Some{n}, c, 0n, ok && Nat.is_gt(0n, 0n))) == None{} : Maybe<&2, Nat>}:
  match ok:
    case True{}: frac_none(u, Nat.div(0n, 10n))
    case False{}: frac_none(u, Nat.div(0n, 10n))

def frac_end3(+n: Nat, +t: String) -> {P.frac_go(t, 0n, Some{n}) == S.frac3_end(n, t) : Maybe<&2, Nat>}:
  match t:
    case SNil{}: {==}
    case SCon{Chr{+c}, u}: frac_past(n, c, u, P.frac_digit(c))

def frac_d3(+n: Nat, +c: U32, +u: String, ok: Bool) -> {P.frac_go(u, Nat.div(1n, 10n), P.frac_add(Some{n}, c, 1n, ok && Nat.is_gt(1n, 0n))) == S.frac3_digit(Nat.add(n, Nat.mul(S.value(c), 1n)), u, ok) : Maybe<&2, Nat>}:
  match ok:
    case True{}: frac_end3(Nat.add(n, Nat.mul(S.value(c), 1n)), u)
    case False{}: frac_none(u, Nat.div(1n, 10n))

def frac_end2(+n: Nat, +t: String) -> {P.frac_go(t, 1n, Some{n}) == S.frac2_end(n, t) : Maybe<&2, Nat>}:
  match t:
    case SNil{}: {==}
    case SCon{Chr{+c}, u}: frac_d3(n, c, u, P.frac_digit(c))

def frac_d2(+n: Nat, +c: U32, +u: String, ok: Bool) -> {P.frac_go(u, Nat.div(10n, 10n), P.frac_add(Some{n}, c, 10n, ok && Nat.is_gt(10n, 0n))) == S.frac2_digit(Nat.add(n, Nat.mul(S.value(c), 10n)), u, ok) : Maybe<&2, Nat>}:
  match ok:
    case True{}: frac_end2(Nat.add(n, Nat.mul(S.value(c), 10n)), u)
    case False{}: frac_none(u, Nat.div(10n, 10n))

def frac_end1(+n: Nat, +t: String) -> {P.frac_go(t, 10n, Some{n}) == S.frac1_end(n, t) : Maybe<&2, Nat>}:
  match t:
    case SNil{}: {==}
    case SCon{Chr{+c}, u}: frac_d2(n, c, u, P.frac_digit(c))

def frac_d1(+c: U32, +t: String, ok: Bool) -> {P.frac_go(t, Nat.div(100n, 10n), P.frac_add(Some{0n}, c, 100n, ok && Nat.is_gt(100n, 0n))) == S.frac1_digit(Nat.mul(S.value(c), 100n), t, ok) : Maybe<&2, Nat>}:
  match ok:
    case True{}: frac_end1(Nat.mul(S.value(c), 100n), t)
    case False{}: frac_none(t, Nat.div(100n, 10n))

# The digits after the dot read the same in both.
def fraction(+s: String) -> {P.frac_go(s, 100n, Some{0n}) == S.fraction(s) : Maybe<&2, Nat>}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{+c}, t}: frac_d1(c, t, P.frac_digit(c))

def capped_zero(+f: Maybe<&2, Nat>) -> {P.capped(0n, f) == f : Maybe<&2, Nat>}:
  match f:
    case None{}: {==}
    case Some{x}: {==}

def capped_one_pick(+x: Nat, z: Bool) -> {P.capped_pick(1000n, x, False{}, z) == S.zero_fraction(z) : Maybe<&2, Nat>}:
  match z:
    case True{}: {==}
    case False{}: {==}

def capped_one(+f: Maybe<&2, Nat>) -> {P.capped(1000n, f) == S.one_fraction(f) : Maybe<&2, Nat>}:
  match f:
    case None{}: {==}
    case Some{+x}: capped_one_pick(x, Nat.is_eq(x, 0n))

def zero_dotted(+rest: String, dot: Bool) -> {P.dotted(0n, rest, dot) == S.dot_fraction(rest, dot) : Maybe<&2, Nat>}:
  match dot:
    case True{}: Equal.trans(Maybe<&2, Nat>, P.capped(0n, P.frac_go(rest, 100n, Some{0n})), P.frac_go(rest, 100n, Some{0n}), S.fraction(rest), capped_zero(P.frac_go(rest, 100n, Some{0n})), fraction(rest))
    case False{}: {==}

def one_dotted(+rest: String, dot: Bool) -> {P.dotted(1000n, rest, dot) == S.one_dot(rest, dot) : Maybe<&2, Nat>}:
  match dot:
    case True{}:
      %Equal.sym(Maybe<&2, Nat>, P.frac_go(rest, 100n, Some{0n}), S.fraction(rest), fraction(rest)) : {P.capped(1000n, _) == S.one_fraction(S.fraction(rest)) : Maybe<&2, Nat>}
      capped_one(S.fraction(rest))
    case False{}: {==}

def after_zero(+t: String) -> {P.after_lead(0n, t) == S.after_zero(t) : Maybe<&2, Nat>}:
  match t:
    case SNil{}: {==}
    case SCon{Chr{+c}, rest}: zero_dotted(rest, U32.is_eq(c, 46))

def after_one(+t: String) -> {P.after_lead(1000n, t) == S.after_one(t) : Maybe<&2, Nat>}:
  match t:
    case SNil{}: {==}
    case SCon{Chr{+c}, rest}: one_dotted(rest, U32.is_eq(c, 46))

def leading(+t: String, z: Bool, o: Bool) -> {P.lead_pick(t, z, o) == S.leading(t, z, o) : Maybe<&2, Nat>}:
  match z o:
    case True{} _: after_zero(t)
    case False{} True{}: after_one(t)
    case False{} False{}: {==}

def qvalue(+s: String) -> {P.qvalue(s) == S.qvalue(s) : Maybe<&2, Nat>}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{+c}, t}: leading(t, U32.is_eq(c, 48), U32.is_eq(c, 49))

def weight_same(+q: Maybe<&2, Nat>) -> {P.weight(q) == S.qweight(q) : Nat}:
  match q:
    case None{}: {==}
    case Some{n}: {==}

def qweight(+s: String) -> {P.weight(P.qvalue(s)) == S.qweight(S.qvalue(s)) : Nat}:
  %Equal.sym(Maybe<&2, Nat>, P.qvalue(s), S.qvalue(s), qvalue(s)) : {P.weight(_) == S.qweight(S.qvalue(s)) : Nat}
  weight_same(S.qvalue(s))

# ------------------------------------------------------------- parameters

def drop_zero(+r: String) -> {String.drop(r, 0n) == r : String}:
  match r:
    case SNil{}: {==}
    case SCon{h, t}: {==}

def q_equals(+a: Char, +b: Char, +r: String, +rest: Nat, y: Bool) -> {P.param_pick(SCon{a, SCon{b, r}}, rest, String.starts_with.go.if("", r, y)) == S.param_weight(S.q_pick(r, True{}, y), rest) : Nat}:
  match y:
    case True{}:
      %Equal.sym(String, String.drop(r, 0n), r, drop_zero(r)) : {P.weight(P.qvalue(String.trim(_))) == S.qweight(S.qvalue(String.trim(r))) : Nat}
      qweight(String.trim(r))
    case False{}: {==}

def q_first(+a: Char, +b: Char, +r: String, +rest: Nat, x: Bool) -> {P.param_pick(SCon{a, SCon{b, r}}, rest, String.starts_with.go.if("=", SCon{b, r}, x)) == S.param_weight(S.q_pick(r, x, Char.is_eq(b, '=')), rest) : Nat}:
  match x:
    case True{}: q_equals(a, b, r, rest, Char.is_eq(b, '='))
    case False{}: {==}

def q_short(+a: Char, +rest: Nat, x: Bool) -> {P.param_pick(SCon{a, SNil{}}, rest, String.starts_with.go.if("=", SNil{}, x)) == rest : Nat}:
  match x:
    case True{}: {==}
    case False{}: {==}

def param(+p: String, +rest: Nat) -> {P.param_pick(p, rest, String.starts_with(p, "q=")) == S.param_weight(S.q_text(p), rest) : Nat}:
  match p:
    case SNil{}: {==}
    case SCon{+a, t}:
      match t:
        case SNil{}: q_short(a, rest, Char.is_eq(a, 'q'))
        case SCon{+b, r}: q_first(a, b, r, rest, Char.is_eq(a, 'q'))

def params(+ps: List<&2, String>) -> {P.params_q(ps) == S.weight(ps) : Nat}:
  match ps:
    case Nil{}: {==}
    case +p <> +t:
      %Equal.sym(Nat, P.params_q(t), S.weight(t), params(t)) : {P.param_pick(Bytes.fold(String.trim(p)), _, String.starts_with(Bytes.fold(String.trim(p)), "q=")) == S.weight(p <> t) : Nat}
      param(Bytes.fold(String.trim(p)), S.weight(t))

# ---------------------------------------------------------------- members

def named(+n: String, +w: Nat, e: Bool) -> {P.named_pref(n, w, e) == S.entry(n, w, e) : List<&2, P.Pref>}:
  match e:
    case True{}: {==}
    case False{}: {==}

def parts(+ps: List<&2, String>) -> {P.member_parts(ps) == S.entry_parts(ps) : List<&2, P.Pref>}:
  match ps:
    case Nil{}: {==}
    case +first <> +rest:
      %Equal.sym(Nat, P.params_q(rest), S.weight(rest), params(rest)) : {P.member_named(Media.essence(first), _) == S.entry_parts(first <> rest) : List<&2, P.Pref>}
      %Equal.sym(String, Media.essence(first), MediaSpec.essence(first), MediaProof.essence(first)) : {P.member_named(_, S.weight(rest)) == S.entry_parts(first <> rest) : List<&2, P.Pref>}
      named(MediaSpec.essence(first), S.weight(rest), String.is_empty(MediaSpec.essence(first)))

def member(+m: String) -> {P.member(m) == S.member(m) : List<&2, P.Pref>}:
  parts(String.split(m, ';'))

def members(+ms: List<&2, String>) -> {P.members(ms) == S.members(ms) : List<&2, P.Pref>}:
  match ms:
    case Nil{}: {==}
    case +m <> +t:
      %Equal.sym(List<&2, P.Pref>, P.member(m), S.member(m), member(m)) : {List.append(&2, P.Pref, _, P.members(t)) == S.members(m <> t) : List<&2, P.Pref>}
      Equal.cong(List<&2, P.Pref>, List<&2, P.Pref>, l => List.append(&2, P.Pref, S.member(m), l), P.members(t), S.members(t), members(t))

# Vary.items lists a field's members last first.
def emitted_rev(+ps: List<&2, List<&2, U32>>, +acc: List<&2, String>) -> {RP.emitted(ps, acc) == List.reverse.go(&2, String, RS.member_names(ps), acc) : List<&2, String>}:
  match ps:
    case Nil{}: {==}
    case +p <> +t: emitted_rev(t, RS.member_name(p) <> acc)

def rev_rev(+xs: List<&2, String>, +acc: List<&2, String>, +r: List<&2, String>) -> {List.reverse.go(&2, String, List.reverse.go(&2, String, xs, acc), r) == List.reverse.go(&2, String, acc, List.append(&2, String, xs, r)) : List<&2, String>}:
  match xs:
    case Nil{}: {==}
    case +h <> +t: rev_rev(t, h <> acc, r)

def append_nil(+xs: List<&2, String>) -> {List.append(&2, String, xs, []) == xs : List<&2, String>}:
  match xs:
    case Nil{}: {==}
    case +h <> +t: Equal.cong(List<&2, String>, List<&2, String>, l => h <> l, List.append(&2, String, t, []), t, append_nil(t))

def pieces_rev(+sg: RS.Pieces) -> {List.reverse(&2, String, RP.emitted(RP.glue([], sg), [])) == RS.piece_names(sg) : List<&2, String>}:
  match sg:
    case RS.Pieces{+f, +r}:
      +ns = RS.member_names(f <> r)
      %Equal.sym(List<&2, String>, RP.emitted(f <> r, []), List.reverse.go(&2, String, ns, []), emitted_rev(f <> r, [])) : {List.reverse(&2, String, _) == ns : List<&2, String>}
      Equal.trans(List<&2, String>, List.reverse.go(&2, String, List.reverse.go(&2, String, ns, []), []), List.append(&2, String, ns, []), ns, rev_rev(ns, [], []), append_nil(ns))

def items_rev(+v: List<&2, U32>) -> {List.reverse(&2, String, Vary.items(v)) == RS.value_members(v) : List<&2, String>}:
  %Equal.sym(List<&2, String>, Vary.items(v), RP.emitted(RP.glue([], RS.split(v)), []), RP.tokens(v, [], [])) : {List.reverse(&2, String, _) == RS.value_members(v) : List<&2, String>}
  pieces_rev(RS.split(v))

# Every field's members, in order.
def fields(+values: List<&2, List<&2, U32>>) -> {P.fields(values) == S.prefs(values) : List<&2, P.Pref>}:
  match values:
    case Nil{}: {==}
    case +v <> +t:
      %Equal.sym(List<&2, String>, List.reverse(&2, String, Vary.items(v)), RS.value_members(v), items_rev(v)) : {List.append(&2, P.Pref, P.members(_), P.fields(t)) == S.prefs(v <> t) : List<&2, P.Pref>}
      %Equal.sym(List<&2, P.Pref>, P.members(RS.value_members(v)), S.members(RS.value_members(v)), members(RS.value_members(v))) : {List.append(&2, P.Pref, _, P.fields(t)) == S.prefs(v <> t) : List<&2, P.Pref>}
      Equal.cong(List<&2, P.Pref>, List<&2, P.Pref>, l => List.append(&2, P.Pref, S.members(RS.value_members(v)), l), P.fields(t), S.prefs(t), fields(t))

# ------------------------------------------------------------- precedence

def pick_same(+w: Nat, +r1: Maybe<&2, Nat>, +r2: Maybe<&2, Nat>, e: Bool, ih: {r1 == r2 : Maybe<&2, Nat>}) -> {P.lookup_pick(w, r1, e) == S.first_pick(w, r2, e) : Maybe<&2, Nat>}:
  match e:
    case True{}: {==}
    case False{}: ih

def pick_twice(+w: Nat, +r1: Maybe<&2, Nat>, +r2: Maybe<&2, Nat>, e: Bool, ih: {r1 == r2 : Maybe<&2, Nat>}) -> {P.lookup_pick(w, r1, e || e) == S.first_pick(w, r2, e) : Maybe<&2, Nat>}:
  match e:
    case True{}: {==}
    case False{}: ih

def lookup_named(+ps: List<&2, P.Pref>, +name: String) -> {P.lookup(ps, name, name) == S.first_named(ps, name) : Maybe<&2, Nat>}:
  match ps:
    case Nil{}: {==}
    case P.Pref{+n, +w} <> +t: pick_twice(w, P.lookup(t, name, name), S.first_named(t, name), String.eq(n, name), lookup_named(t, name))

def lookup_gzip(+ps: List<&2, P.Pref>) -> {P.lookup(ps, "gzip", "x-gzip") == S.first_gzip(ps) : Maybe<&2, Nat>}:
  match ps:
    case Nil{}: {==}
    case P.Pref{+n, +w} <> +t: pick_same(w, P.lookup(t, "gzip", "x-gzip"), S.first_gzip(t), String.eq(n, "gzip") || String.eq(n, "x-gzip"), lookup_gzip(t))

def star_same(+f: Maybe<&2, Nat>, +s: Maybe<&2, Nat>) -> {P.or_star(f, s) == S.resolve(f, s) : Nat}:
  match f s:
    case Some{w} _: {==}
    case None{} Some{w}: {==}
    case None{} None{}: {==}

def quality(+ps: List<&2, P.Pref>, +c: P.Coding) -> {P.quality(ps, c) == S.pref_quality(ps, c) : Nat}:
  match c:
    case P.Gzip{}:
      %Equal.sym(Maybe<&2, Nat>, P.lookup(ps, "gzip", "x-gzip"), S.first_gzip(ps), lookup_gzip(ps)) : {P.or_star(_, P.lookup(ps, "*", "*")) == S.pref_quality(ps, P.Gzip{}) : Nat}
      %Equal.sym(Maybe<&2, Nat>, P.lookup(ps, "*", "*"), S.first_named(ps, "*"), lookup_named(ps, "*")) : {P.or_star(S.first_gzip(ps), _) == S.pref_quality(ps, P.Gzip{}) : Nat}
      star_same(S.first_gzip(ps), S.first_named(ps, "*"))
    case P.Deflate{}:
      %Equal.sym(Maybe<&2, Nat>, P.lookup(ps, "deflate", "deflate"), S.first_named(ps, "deflate"), lookup_named(ps, "deflate")) : {P.or_star(_, P.lookup(ps, "*", "*")) == S.pref_quality(ps, P.Deflate{}) : Nat}
      %Equal.sym(Maybe<&2, Nat>, P.lookup(ps, "*", "*"), S.first_named(ps, "*"), lookup_named(ps, "*")) : {P.or_star(S.first_named(ps, "deflate"), _) == S.pref_quality(ps, P.Deflate{}) : Nat}
      star_same(S.first_named(ps, "deflate"), S.first_named(ps, "*"))

def identity(+ps: List<&2, P.Pref>) -> {P.identity_quality(ps) == S.pref_identity(ps) : Nat}:
  %Equal.sym(Maybe<&2, Nat>, P.lookup(ps, "identity", "identity"), S.first_named(ps, "identity"), lookup_named(ps, "identity")) : {P.or_star(_, P.lookup(ps, "*", "*")) == S.pref_identity(ps) : Nat}
  %Equal.sym(Maybe<&2, Nat>, P.lookup(ps, "*", "*"), S.first_named(ps, "*"), lookup_named(ps, "*")) : {P.or_star(S.first_named(ps, "identity"), _) == S.pref_identity(ps) : Nat}
  star_same(S.first_named(ps, "identity"), S.first_named(ps, "*"))

# ------------------------------------------------------------------ choice

def offered_take(+c: P.Coding, b: Bool) -> {P.offered(c, b) == S.take(c, False{}, b) : Maybe<&2, P.Coding>}:
  match b:
    case True{}: {==}
    case False{}: {==}

def offer(+c: P.Coding, +w: Nat, +i: Nat) -> {P.offer(c, w, i) == S.offer(c, w, i) : Maybe<&2, P.Coding>}:
  match w:
    case 0n: {==}
    case 1n+k: offered_take(c, Nat.is_lt(1n+k, i))

def pick(+g: Nat, +d: Nat, +i: Nat, b: Bool) -> {P.pick(g, d, i, b) == S.prefer(g, d, i, b) : Maybe<&2, P.Coding>}:
  match b:
    case True{}: offer(P.Deflate{}, d, i)
    case False{}: offer(P.Gzip{}, g, i)

def select(+ps: List<&2, P.Pref>) -> {P.select(ps) == S.pref_select(ps) : Maybe<&2, P.Coding>}:
  +g = S.pref_quality(ps, P.Gzip{})
  +d = S.pref_quality(ps, P.Deflate{})
  %Equal.sym(Nat, P.quality(ps, P.Gzip{}), g, quality(ps, P.Gzip{})) : {P.pick(_, P.quality(ps, P.Deflate{}), P.identity_quality(ps), Nat.is_lt(_, P.quality(ps, P.Deflate{}))) == S.pref_select(ps) : Maybe<&2, P.Coding>}
  %Equal.sym(Nat, P.quality(ps, P.Deflate{}), d, quality(ps, P.Deflate{})) : {P.pick(g, _, P.identity_quality(ps), Nat.is_lt(g, _)) == S.pref_select(ps) : Maybe<&2, P.Coding>}
  %Equal.sym(Nat, P.identity_quality(ps), S.pref_identity(ps), identity(ps)) : {P.pick(g, d, _, Nat.is_lt(g, d)) == S.pref_select(ps) : Maybe<&2, P.Coding>}
  pick(g, d, S.pref_identity(ps), Nat.is_lt(g, d))

# The coding chosen from the raw fields is the specification's.
def choice(+values: List<&2, List<&2, U32>>) -> {P.choice(P.accept(values)) == S.choice(values) : Maybe<&2, P.Coding>}:
  match values:
    case Nil{}: {==}
    case +v <> +t:
      %Equal.sym(List<&2, P.Pref>, P.fields(v <> t), S.prefs(v <> t), fields(v <> t)) : {P.select(_) == S.choice(v <> t) : Maybe<&2, P.Coding>}
      select(S.prefs(v <> t))

def accepted(+values: List<&2, List<&2, U32>>, +c: P.Coding) -> {P.accepts(P.accept(values), c) == S.accepted(values, c) : Bool}:
  match values:
    case Nil{}: {==}
    case +v <> +t:
      %Equal.sym(List<&2, P.Pref>, P.fields(v <> t), S.prefs(v <> t), fields(v <> t)) : {Bool.not(Nat.is_eq(P.quality(_, c), 0n)) == S.accepted(v <> t, c) : Bool}
      %Equal.sym(Nat, P.quality(S.prefs(v <> t), c), S.pref_quality(S.prefs(v <> t), c), quality(S.prefs(v <> t), c)) : {Bool.not(Nat.is_eq(_, 0n)) == S.accepted(v <> t, c) : Bool}
      {==}

def not_true(+b: Bool, +h: {Bool.not(b) == True{} : Bool}) -> {b == False{} : Bool}:
  match b:
    case True{}: absurd({True{} == False{} : Bool}, CP.false_true(h))
    case False{}: {==}

def accepted_weight(+values: List<&2, List<&2, U32>>, +c: P.Coding, +h: {S.accepted(values, c) == True{} : Bool}) -> {Nat.is_eq(S.quality(values, c), 0n) == False{} : Bool}:
  match values:
    case Nil{}: absurd({Nat.is_eq(S.quality([], c), 0n) == False{} : Bool}, CP.false_true(h))
    case +v <> +t: not_true(Nat.is_eq(S.quality(v <> t, c), 0n), h)

# A response is compressed with c only when the raw fields weigh c above 0.
def raw_refusal(+cfg: P.Config, +m: Request.Method, +values: List<&2, List<&2, U32>>, +s: U32, +hs: List<&2, Request.Header>, +body: List<&2, U32>, +rep: Maybe<&2, List<&2, U32>>, +c: P.Coding, h: {P.decide(cfg, m, P.accept(values), Response.Res{s, hs, body, rep}) == P.Encode{c} : P.Plan}) -> {Nat.is_eq(S.quality(values, c), 0n) == False{} : Bool}:
  +ok = CP.encode_accepted(cfg, m, P.accept(values), s, hs, body, rep, c, h)
  accepted_weight(values, c, Equal.trans(Bool, S.accepted(values, c), P.accepts(P.accept(values), c), True{}, Equal.sym(Bool, P.accepts(P.accept(values), c), S.accepted(values, c), accepted(values, c)), ok))

# A response is compressed with c only when the specification picks c.
def raw_choice(+cfg: P.Config, +m: Request.Method, +values: List<&2, List<&2, U32>>, +s: U32, +hs: List<&2, Request.Header>, +body: List<&2, U32>, +rep: Maybe<&2, List<&2, U32>>, +c: P.Coding, h: {P.decide(cfg, m, P.accept(values), Response.Res{s, hs, body, rep}) == P.Encode{c} : P.Plan}) -> {S.choice(values) == Some{c} : Maybe<&2, P.Coding>}:
  Equal.trans(Maybe<&2, P.Coding>, S.choice(values), P.choice(P.accept(values)), Some{c}, Equal.sym(Maybe<&2, P.Coding>, P.choice(P.accept(values)), S.choice(values), choice(values)), CP.sized_choice(cfg, m, P.choice(P.accept(values)), s, hs, body, rep, U32.is_eq(s, 304), c, h))

# Gzip is chosen whenever its weight is positive, at least deflate's and at
# least identity's: a positive tie goes to gzip.
def offer_pos(+c: P.Coding, +q: Nat, +i: Nat, +hz: {Nat.is_eq(q, 0n) == False{} : Bool}, +hl: {Nat.is_lt(q, i) == False{} : Bool}) -> {P.offer(c, q, i) == Some{c} : Maybe<&2, P.Coding>}:
  match q:
    case 0n: absurd({P.offer(c, 0n, i) == Some{c} : Maybe<&2, P.Coding>}, CP.false_true(Equal.sym(Bool, True{}, False{}, hz)))
    case 1n+k:
      %Equal.sym(Bool, Nat.is_lt(1n+k, i), False{}, hl) : {P.offered(c, _) == Some{c} : Maybe<&2, P.Coding>}
      {==}

def select_gzip(+ps: List<&2, P.Pref>, +h1: {Nat.is_lt(P.quality(ps, P.Gzip{}), P.quality(ps, P.Deflate{})) == False{} : Bool}, +h2: {Nat.is_eq(P.quality(ps, P.Gzip{}), 0n) == False{} : Bool}, +h3: {Nat.is_lt(P.quality(ps, P.Gzip{}), P.identity_quality(ps)) == False{} : Bool}) -> {P.select(ps) == Some{P.Gzip{}} : Maybe<&2, P.Coding>}:
  %Equal.sym(Bool, Nat.is_lt(P.quality(ps, P.Gzip{}), P.quality(ps, P.Deflate{})), False{}, h1) : {P.pick(P.quality(ps, P.Gzip{}), P.quality(ps, P.Deflate{}), P.identity_quality(ps), _) == Some{P.Gzip{}} : Maybe<&2, P.Coding>}
  offer_pos(P.Gzip{}, P.quality(ps, P.Gzip{}), P.identity_quality(ps), h2, h3)

# ------------------------------------------------------------ media types

def and_left(+a: Bool, +b: Bool, +h: {a && b == True{} : Bool}) -> {a == True{} : Bool}:
  match a:
    case True{}: {==}
    case False{}: absurd({False{} == True{} : Bool}, CP.false_true(h))

def and_right(+a: Bool, +b: Bool, +h: {a && b == True{} : Bool}) -> {b == True{} : Bool}:
  match a:
    case True{}: h
    case False{}: absurd({b == True{} : Bool}, CP.false_true(h))

def all_packed(xs: List<&2, String>) -> Bool:
  match xs:
    case Nil{}: True{}
    case x <> t: P.packed(x) && all_packed(t)

def imp_step(+m: String, +x: String, +t: List<&2, String>, b: Bool, +hb: {String.eq(m, x) == b : Bool}, +hx: {P.packed(x) == True{} : Bool}, ih: {Bool.not(S.listed(m, t)) || P.packed(m) == True{} : Bool}) -> {Bool.not(b || S.listed(m, t)) || P.packed(m) == True{} : Bool}:
  match b:
    case True{}:
      %Equal.sym(String, m, x, Laws.string_eq_sound(m, x, hb)) : {P.packed(_) == True{} : Bool}
      hx
    case False{}: ih

# Every member of a listed group the implementation also skips.
def packed_imp(+m: String, +xs: List<&2, String>, +hall: {all_packed(xs) == True{} : Bool}) -> {Bool.not(S.listed(m, xs)) || P.packed(m) == True{} : Bool}:
  match xs:
    case Nil{}: {==}
    case +x <> +t: imp_step(m, x, t, String.eq(m, x), {==}, and_left(P.packed(x), all_packed(t), hall), packed_imp(m, t, and_right(P.packed(x), all_packed(t), hall)))

def imp_use(+m: String, l: Bool, +hl: {l == True{} : Bool}, +imp: {Bool.not(l) || P.packed(m) == True{} : Bool}) -> {P.packed(m) == True{} : Bool}:
  match l:
    case True{}: imp
    case False{}: absurd({P.packed(m) == True{} : Bool}, CP.false_true(hl))

def skip_go(+m: String, e: Bool, r: Bool, v: Bool, a: Bool, l1: Bool, l2: Bool, +h: {(((r || v) || a) || l1) || l2 == True{} : Bool}, +h1: {S.listed(m, S.archives()) == l1 : Bool}, +h2: {S.listed(m, S.fonts()) == l2 : Bool}) -> {(((e || r) || v) || a) || P.packed(m) == True{} : Bool}:
  match e r v a l1 l2:
    case True{} _ _ _ _ _: {==}
    case False{} True{} _ _ _ _: {==}
    case False{} False{} True{} _ _ _: {==}
    case False{} False{} False{} True{} _ _: {==}
    case False{} False{} False{} False{} True{} _: imp_use(m, S.listed(m, S.archives()), h1, packed_imp(m, S.archives(), {==}))
    case False{} False{} False{} False{} False{} True{}: imp_use(m, S.listed(m, S.fonts()), h2, packed_imp(m, S.fonts(), {==}))
    case False{} False{} False{} False{} False{} False{}: absurd({P.packed(m) == True{} : Bool}, CP.false_true(h))

def skipped(+m: String, +h: {S.precompressed(m) == True{} : Bool}) -> {P.media_skipped(m) == True{} : Bool}:
  skip_go(m, String.is_empty(m), S.raster(m), String.starts_with(m, "video/"), String.starts_with(m, "audio/"), S.listed(m, S.archives()), S.listed(m, S.fonts()), h, {==}, {==})

def content_type(+values: List<&2, List<&2, U32>>) -> {P.content_type(values) == S.content_type(values) : String}:
  match values:
    case Nil{}: {==}
    case +v <> +t: MediaProof.essence(Bytes.ascii(v))

def media_skipped(+hs: List<&2, Request.Header>, +h: {S.precompressed(S.content_type(Request.lookup(hs, "content-type"))) == True{} : Bool}) -> {P.media_skipped(P.media(hs)) == True{} : Bool}:
  %Equal.sym(String, P.content_type(Request.lookup(hs, "content-type")), S.content_type(Request.lookup(hs, "content-type")), content_type(Request.lookup(hs, "content-type"))) : {P.media_skipped(_) == True{} : Bool}
  skipped(S.content_type(Request.lookup(hs, "content-type")), h)

def unfit_media(+hs: List<&2, Request.Header>, +n: Nat, +l: U32, +h: {P.media_skipped(P.media(hs)) == True{} : Bool}) -> {P.unfit(hs, n, l) == True{} : Bool}:
  CP.or_left((P.present(hs, "content-range") || P.no_transform(hs)) || P.media_skipped(P.media(hs)), Nat.is_lt(U32.to_nat(l), n), CP.or_right(P.present(hs, "content-range") || P.no_transform(hs), P.media_skipped(P.media(hs)), h))

def plan_bad_keep(+e: Bool, +s: Bool, +b: Bool, +mode: P.Mode, +ch: Maybe<&2, P.Coding>, +hb: {b == True{} : Bool}) -> {P.plan(e, s, b, mode, ch) == P.Keep{} : P.Plan}:
  match e s b:
    case True{} _ _: {==}
    case False{} True{} _: {==}
    case False{} False{} True{}: {==}
    case False{} False{} False{}: absurd({P.plan(False{}, False{}, False{}, mode, ch) == P.Keep{} : P.Plan}, CP.false_true(hb))

def revalidated_media(+cfg: P.Config, +hs: List<&2, Request.Header>, +rep: Maybe<&2, List<&2, U32>>, +ch: Maybe<&2, P.Coding>, +h: {P.media_skipped(P.media(hs)) == True{} : Bool}) -> {P.revalidated(cfg, hs, rep, ch) == P.Keep{} : P.Plan}:
  match rep:
    case None{}: plan_bad_keep(P.already(hs), False{}, True{}, P.Revalidate{}, ch, {==})
    case Some{+w}: plan_bad_keep(P.already(hs), P.small(Response.length(w), P.threshold(cfg)), P.unfit(hs, Response.length(w), P.limit(cfg)), P.Revalidate{}, ch, unfit_media(hs, Response.length(w), P.limit(cfg), h))

def sized_media(+cfg: P.Config, +m: Request.Method, +ch: Maybe<&2, P.Coding>, +s: U32, +hs: List<&2, Request.Header>, +body: List<&2, U32>, +rep: Maybe<&2, List<&2, U32>>, nm: Bool, +h: {P.media_skipped(P.media(hs)) == True{} : Bool}) -> {P.sized(cfg, m, ch, s, hs, body, rep, nm) == P.Keep{} : P.Plan}:
  match nm:
    case True{}: revalidated_media(cfg, hs, rep, ch, h)
    case False{}: plan_bad_keep(P.already(hs), P.small(Response.length(body), P.threshold(cfg)), P.no_body_status(s) || P.unfit(hs, Response.length(body), P.limit(cfg)), P.body_mode(m), ch, CP.or_right(P.no_body_status(s), P.unfit(hs, Response.length(body), P.limit(cfg)), unfit_media(hs, Response.length(body), P.limit(cfg), h)))

# Already-compressed media is left exactly as it is.
def media_kept(+cfg: P.Config, +m: Request.Method, +accept: Maybe<&2, List<&2, P.Pref>>, +s: U32, +hs: List<&2, Request.Header>, +body: List<&2, U32>, +rep: Maybe<&2, List<&2, U32>>, +h: {S.precompressed(S.content_type(Request.lookup(hs, "content-type"))) == True{} : Bool}) -> {P.decide(cfg, m, accept, Response.Res{s, hs, body, rep}) == P.Keep{} : P.Plan}:
  sized_media(cfg, m, P.choice(accept), s, hs, body, rep, U32.is_eq(s, 304), media_skipped(hs, h))

# --------------------------------------------------------------------- HEAD

def headed_fixed(+p: P.Plan, +no: {P.encodes(p) == False{} : Bool}) -> {P.headed(p) == p : P.Plan}:
  match p:
    case P.Keep{}: {==}
    case P.Vary{}: {==}
    case P.Encode{c}: absurd({P.Measure{c} == P.Encode{c} : P.Plan}, CP.false_true(Equal.sym(Bool, True{}, False{}, no)))
    case P.Measure{c}: {==}
    case P.Revalidated{c}: {==}

def plan_headed(+e: Bool, +s: Bool, +b: Bool, +ch: Maybe<&2, P.Coding>) -> {P.plan(e, s, b, P.Headers{}, ch) == P.headed(P.plan(e, s, b, P.Full{}, ch)) : P.Plan}:
  match e s b:
    case True{} _ _: {==}
    case False{} True{} _: {==}
    case False{} False{} True{}: {==}
    case False{} False{} False{}:
      match ch:
        case None{}: {==}
        case Some{c}: {==}

def sized_head(+cfg: P.Config, +ch: Maybe<&2, P.Coding>, +s: U32, +hs: List<&2, Request.Header>, +body: List<&2, U32>, +rep: Maybe<&2, List<&2, U32>>, nm: Bool) -> {P.sized(cfg, Request.Head{}, ch, s, hs, body, rep, nm) == P.headed(P.sized(cfg, Request.Get{}, ch, s, hs, body, rep, nm)) : P.Plan}:
  match nm:
    case True{}: Equal.sym(P.Plan, P.headed(P.revalidated(cfg, hs, rep, ch)), P.revalidated(cfg, hs, rep, ch), headed_fixed(P.revalidated(cfg, hs, rep, ch), CP.revalidated_never(cfg, hs, rep, ch)))
    case False{}: plan_headed(P.already(hs), P.small(Response.length(body), P.threshold(cfg)), P.no_body_status(s) || P.unfit(hs, Response.length(body), P.limit(cfg)), ch)

# HEAD gets the plan GET would, measured instead of encoded.
def head_as_get(+cfg: P.Config, +accept: Maybe<&2, List<&2, P.Pref>>, +s: U32, +hs: List<&2, Request.Header>, +body: List<&2, U32>, +rep: Maybe<&2, List<&2, U32>>) -> {P.decide(cfg, Request.Head{}, accept, Response.Res{s, hs, body, rep}) == P.headed(P.decide(cfg, Request.Get{}, accept, Response.Res{s, hs, body, rep})) : P.Plan}:
  sized_head(cfg, P.choice(accept), s, hs, body, rep, U32.is_eq(s, 304))

# A measured plan gets exactly the response the encoded plan would.
def head_responds(+res: Response.Res, +p: P.Plan, +out: Maybe<&2, List<&2, U32>>) -> {P.respond(res, P.headed(p), out) == P.respond(res, p, out) : Response.Res}:
  match p:
    case P.Keep{}: {==}
    case P.Vary{}: {==}
    case P.Encode{c}: {==}
    case P.Measure{c}: {==}
    case P.Revalidated{c}: {==}

# --------------------------------------------------------------------- Keep

def gated_not_keep(+mode: P.Mode, +ch: Maybe<&2, P.Coding>) -> {P.is_keep(P.gated(mode, ch)) == False{} : Bool}:
  match mode ch:
    case P.Headers{} None{}: {==}
    case P.Headers{} Some{c}: {==}
    case P.Full{} None{}: {==}
    case P.Full{} Some{c}: {==}
    case P.Revalidate{} None{}: {==}
    case P.Revalidate{} Some{c}: {==}

def plan_keep(+e: Bool, +s: Bool, +b: Bool, +mode: P.Mode, +c1: Maybe<&2, P.Coding>, +c2: Maybe<&2, P.Coding>) -> {P.is_keep(P.plan(e, s, b, mode, c1)) == P.is_keep(P.plan(e, s, b, mode, c2)) : Bool}:
  match e s b:
    case True{} _ _: {==}
    case False{} True{} _: {==}
    case False{} False{} True{}: {==}
    case False{} False{} False{}: Equal.trans(Bool, P.is_keep(P.gated(mode, c1)), False{}, P.is_keep(P.gated(mode, c2)), gated_not_keep(mode, c1), Equal.sym(Bool, P.is_keep(P.gated(mode, c2)), False{}, gated_not_keep(mode, c2)))

def revalidated_keep(+cfg: P.Config, +hs: List<&2, Request.Header>, +rep: Maybe<&2, List<&2, U32>>, +c1: Maybe<&2, P.Coding>, +c2: Maybe<&2, P.Coding>) -> {P.is_keep(P.revalidated(cfg, hs, rep, c1)) == P.is_keep(P.revalidated(cfg, hs, rep, c2)) : Bool}:
  match rep:
    case None{}: plan_keep(P.already(hs), False{}, True{}, P.Revalidate{}, c1, c2)
    case Some{+w}: plan_keep(P.already(hs), P.small(Response.length(w), P.threshold(cfg)), P.unfit(hs, Response.length(w), P.limit(cfg)), P.Revalidate{}, c1, c2)

def sized_keep(+cfg: P.Config, +m: Request.Method, +c1: Maybe<&2, P.Coding>, +c2: Maybe<&2, P.Coding>, +s: U32, +hs: List<&2, Request.Header>, +body: List<&2, U32>, +rep: Maybe<&2, List<&2, U32>>, nm: Bool) -> {P.is_keep(P.sized(cfg, m, c1, s, hs, body, rep, nm)) == P.is_keep(P.sized(cfg, m, c2, s, hs, body, rep, nm)) : Bool}:
  match nm:
    case True{}: revalidated_keep(cfg, hs, rep, c1, c2)
    case False{}: plan_keep(P.already(hs), P.small(Response.length(body), P.threshold(cfg)), P.no_body_status(s) || P.unfit(hs, Response.length(body), P.limit(cfg)), P.body_mode(m), c1, c2)

# Whether the response is kept as it is never depends on Accept-Encoding.
def keep_ignores_accept(+cfg: P.Config, +m: Request.Method, +a1: Maybe<&2, List<&2, P.Pref>>, +a2: Maybe<&2, List<&2, P.Pref>>, +s: U32, +hs: List<&2, Request.Header>, +body: List<&2, U32>, +rep: Maybe<&2, List<&2, U32>>) -> {P.is_keep(P.decide(cfg, m, a1, Response.Res{s, hs, body, rep})) == P.is_keep(P.decide(cfg, m, a2, Response.Res{s, hs, body, rep})) : Bool}:
  sized_keep(cfg, m, P.choice(a1), P.choice(a2), s, hs, body, rep, U32.is_eq(s, 304))
