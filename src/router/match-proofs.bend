# Matching the filler output, before joining it into an HTTP path.
import Base
import ./pattern.bend as P
import ./encoding.bend as E
import ./constraint.bend as C
import ./proofs.bend as Core
import ./compile-proofs.bend as Compile
import ./utf8-proofs.bend as Codec
import ./equality-proofs.bend as Eq
import ./utf8-code.bend as Code

# The proof carries filling, separator cleanliness, and matching together.
def Roundtrip(+segs: List<&2, P.Segment>, +ps: P.Params) -> Type:
  &xs: List<&2, String> ->
    {P.fill_segments(segs, ps) == Some{xs} : Maybe<&2, List<&2, String>>} &
    ({Core.clean_segments(xs) == True{} : Bool} &
    {P.match_segments(segs, xs) == Some{ps} : Maybe<&2, P.Params>})

def static_step(+raw: String, +rest: List<&2, P.Segment>, +ps: P.Params,
    clean: {Core.no_slash(raw) == True{} : Bool},
    success: Roundtrip(rest, ps)) -> Roundtrip(P.Static{raw} <> rest, ps):
  (+xs, (filled, (clean_tail, matched))) = success
  (raw <> xs, ((
    %Equal.sym(Maybe<&2, List<&2, String>>, P.fill_segments(rest, ps), Some{xs}, filled) : {Maybe.bind(&2, List<&2, String>, List<&2, String>, _, ys => Some{raw <> ys}) == Some{raw <> xs} : Maybe<&2, List<&2, String>>}
    {==}
  ), ((
    %Equal.sym(Bool, Core.no_slash(raw), True{}, clean) : {_ && Core.clean_segments(xs) == True{} : Bool}
    clean_tail
  ), (
    %Equal.sym(Bool, String.eq(raw, raw), True{}, Eq.string_eq_refl(raw)) : {E.choose(Maybe<&2, P.Params>, _, u => P.match_segments(rest, xs), u => None{}) == Some{ps} : Maybe<&2, P.Params>}
    matched
  ))))

def capture_fill_reduce(+name: String, +c: C.Constraint, +optional: Bool,
    +rest: List<&2, P.Segment>, +key: String, +value: String, +tail: P.Params, +xs: List<&2, String>,
    e: {E.choose(Maybe<&2, List<&2, String>>, String.eq(name, key) && P.value_ok(c, value), u => Maybe.bind(&2, List<&2, String>, List<&2, String>, P.fill_segments(rest, tail), ys => Some{E.encode(value) <> ys}), u => None{}) == Some{E.encode(value) <> xs} : Maybe<&2, List<&2, String>>}) ->
    {P.fill_segments(P.Capture{name, c, optional} <> rest, P.Param{key, value} <> tail) == Some{E.encode(value) <> xs} : Maybe<&2, List<&2, String>>}:
  match optional rest:
    case False{} r:
      e
    case True{} Nil{}:
      e
    case True{} h <> t:
      e

def capture_match_reduce(+name: String, +c: C.Constraint, +optional: Bool,
    +rest: List<&2, P.Segment>, +key: String, +value: String, +tail: P.Params, +xs: List<&2, String>,
    e: {Maybe.bind(&2, String, P.Params, E.decode(E.encode(value)), v => E.choose(Maybe<&2, P.Params>, P.value_ok(c, v), u => P.put_capture(name, v, P.match_segments(rest, xs)), u => None{})) == Some{P.Param{key, value} <> tail} : Maybe<&2, P.Params>}) ->
    {P.match_segments(P.Capture{name, c, optional} <> rest, E.encode(value) <> xs) == Some{P.Param{key, value} <> tail} : Maybe<&2, P.Params>}:
  match optional rest:
    case False{} r:
      e
    case True{} Nil{}:
      e
    case True{} h <> t:
      e

def capture_step(+name: String, +c: C.Constraint, +optional: Bool,
    +rest: List<&2, P.Segment>, +key: String, +value: String, +tail: P.Params,
    +same: {String.eq(name, key) == True{} : Bool},
    valid: {P.value_ok(c, value) == True{} : Bool},
    success: Roundtrip(rest, tail)) -> Roundtrip(P.Capture{name, c, optional} <> rest, P.Param{key, value} <> tail):
  (+xs, (filled, (clean_tail, matched))) = success
  +ok = valid
  scalar = Core.and_right(Bool.not(String.is_empty(value)), E.scalars(value), Core.and_left(Bool.not(String.is_empty(value)) && E.scalars(value), C.accepts(c, value), ok))
  +unicode = scalar
  +names = Eq.string_eq_sound(name, key, same)
  (E.encode(value) <> xs, (capture_fill_reduce(name, c, optional, rest, key, value, tail, xs, (
    %Equal.sym(Bool, String.eq(name, key) && P.value_ok(c, value), True{}, Codec.and_true(String.eq(name, key), P.value_ok(c, value), same, ok)) : {E.choose(Maybe<&2, List<&2, String>>, _, u => Maybe.bind(&2, List<&2, String>, List<&2, String>, P.fill_segments(rest, tail), ys => Some{E.encode(value) <> ys}), u => None{}) == Some{E.encode(value) <> xs} : Maybe<&2, List<&2, String>>}
    %Equal.sym(Maybe<&2, List<&2, String>>, P.fill_segments(rest, tail), Some{xs}, filled) : {Maybe.bind(&2, List<&2, String>, List<&2, String>, _, ys => Some{E.encode(value) <> ys}) == Some{E.encode(value) <> xs} : Maybe<&2, List<&2, String>>}
    {==}
  )), ((
    %Equal.sym(Bool, Core.no_slash(E.encode(value)), True{}, Core.encode_no_slash(value, unicode)) : {_ && Core.clean_segments(xs) == True{} : Bool}
    clean_tail
  ), capture_match_reduce(name, c, optional, rest, key, value, tail, xs, (
    %Equal.sym(Maybe<&2, String>, E.decode(E.encode(value)), Some{value}, Codec.codec_roundtrip(value, unicode)) : {Maybe.bind(&2, String, P.Params, _, v => E.choose(Maybe<&2, P.Params>, P.value_ok(c, v), u => P.put_capture(name, v, P.match_segments(rest, xs)), u => None{})) == Some{P.Param{key, value} <> tail} : Maybe<&2, P.Params>}
    %Equal.sym(Bool, P.value_ok(c, value), True{}, ok) : {E.choose(Maybe<&2, P.Params>, _, u => P.put_capture(name, value, P.match_segments(rest, xs)), u => None{}) == Some{P.Param{key, value} <> tail} : Maybe<&2, P.Params>}
    %Equal.sym(Maybe<&2, P.Params>, P.match_segments(rest, xs), Some{tail}, matched) : {P.put_capture(name, value, _) == Some{P.Param{key, value} <> tail} : Maybe<&2, P.Params>}
    Equal.cong(String, Maybe<&2, P.Params>, n => Some{P.Param{n, value} <> tail}, name, key, names)
  )))))

def interior_step(+rest: List<&2, P.Segment>, +ps: P.Params,
    success: Roundtrip(rest, ps)) -> Roundtrip(P.InteriorWildcard{} <> rest, ps):
  (+xs, (filled, (clean, matched))) = success
  (xs, (filled, (clean, Core.interior_match(rest, xs, ps, matched))))

def prefix_refl(+s: String) -> {String.starts_with(s, s) == True{} : Bool}:
  match s:
    case SNil{}:
      {==}
    case SCon{Chr{+n}, +t}:
      %Equal.sym(Cmp, U32.cmp(n, n), EQ{}, Eq.u32_cmp_refl(n)) : {String.starts_with.go.if(t, t, Cmp.is_eq(_)) == True{} : Bool}
      prefix_refl(t)

def prefix_step(+prefix: String, clean: {Core.no_slash(prefix) == True{} : Bool}) -> Roundtrip([P.PrefixWildcard{prefix}], Nil{}):
  ([prefix], ({==}, ((
    %Equal.sym(Bool, Core.no_slash(prefix), True{}, clean) : {_ && True{} == True{} : Bool}
    {==}
  ), (
    %Equal.sym(Bool, String.starts_with(prefix, prefix), True{}, prefix_refl(prefix)) : {E.choose(Maybe<&2, P.Params>, _, u => Some{Nil{}}, u => None{}) == Some{Nil{}} : Maybe<&2, P.Params>}
    {==}
  ))))

# Greedy spans try longer raw prefixes first. A filled path anchors the span's
# tail at its first static; statics there have no `%` and every filled
# capture has one, so no shorter remainder can match the tail.
def bump(b: Bool, n: Nat) -> Nat:
  match b:
    case True{}:
      1n+n
    case False{}:
      n

def free_count(xs: List<&2, String>) -> Nat:
  match xs:
    case Nil{}:
      0n
    case h <> t:
      bump(P.no_percent(h), free_count(t))

def static_count(segs: List<&2, P.Segment>) -> Nat:
  match segs:
    case Nil{}:
      0n
    case P.Static{raw} <> rest:
      1n+static_count(rest)
    case h <> rest:
      static_count(rest)

# under(b, a) holds when a < b.
def under(b: Nat, a: Nat) -> Bool:
  match b a:
    case 0n x:
      False{}
    case 1n+q 0n:
      True{}
    case 1n+q 1n+p:
      under(q, p)

def under_succ(+b: Nat, +a: Nat, e: {under(b, 1n+a) == True{} : Bool}) -> {under(b, a) == True{} : Bool}:
  match b a:
    case 0n x:
      Core.absurd({under(0n, x) == True{} : Bool}, Core.false_true(e))
    case 1n+q 0n:
      {==}
    case 1n+q 1n+p:
      under_succ(q, p, e)

def under_bump(+b: Nat, +flag: Bool, +a: Nat, e: {under(b, bump(flag, a)) == True{} : Bool}) -> {under(b, a) == True{} : Bool}:
  match flag:
    case True{}:
      under_succ(b, a, e)
    case False{}:
      e

def under_true(+b: Nat, +flag: Bool, +a: Nat, yes: {flag == True{} : Bool}, e: {under(1n+b, bump(flag, a)) == True{} : Bool}) -> {under(b, a) == True{} : Bool}:
  match flag:
    case True{}:
      e
    case False{}:
      Core.absurd({under(b, a) == True{} : Bool}, Core.false_true(yes))

def code_percent(+code: Code.Code, +s: String) -> {P.no_percent(E.encode_rep(Code.Packed{code}) ++ s) == False{} : Bool}:
  match code:
    case Code.One{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WNil{}}}}}}}}}:
      {==}
    case Code.Two{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WNil{}}}}}}}}}}}}}:
      {==}
    case Code.Three{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WNil{}}}}}}}}}}}}}}}}}}:
      {==}
    case Code.Four{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WNil{}}}}}}}}}}}}}}}}}}}}}}}:
      {==}

def packed_percent(+r: Code.Representation, packed: {Code.is_packed(r) == True{} : Bool}, +s: String) ->
    {P.no_percent(E.encode_rep(r) ++ s) == False{} : Bool}:
  match r:
    case Code.Packed{+code}:
      code_percent(code, s)
    case Code.Outside{raw}:
      Core.absurd({P.no_percent(E.encode_rep(Code.Outside{raw}) ++ s) == False{} : Bool}, Core.false_true(packed))

# Every admissible capture value fills a segment containing `%`.
def encode_percent(+c: C.Constraint, +v: String, valid: {P.value_ok(c, v) == True{} : Bool}) ->
    {P.no_percent(E.encode(v)) == False{} : Bool}:
  match v:
    case SNil{}:
      Core.absurd({P.no_percent(E.encode(SNil{})) == False{} : Bool}, Core.false_true(valid))
    case SCon{Chr{+n}, +t}:
      +scalars = Core.and_left(E.scalar(n) && E.scalars(t), C.accepts(c, SCon{Chr{n}, t}), valid)
      packed_percent(Code.represent(n), Codec.scalar_is_packed(n, Core.and_left(E.scalar(n), E.scalars(t), scalars)), E.encode(t))

def choose_none(+name: String, +v: String, b: Bool) ->
    {E.choose(Maybe<&2, P.Params>, b, u => P.put_capture(name, v, None{}), u => None{}) == None{} : Maybe<&2, P.Params>}:
  match b:
    case True{}:
      {==}
    case False{}:
      {==}

def bind_none(+name: String, +c: C.Constraint, d: Maybe<&2, String>) ->
    {Maybe.bind(&2, String, P.Params, d, +v => E.choose(Maybe<&2, P.Params>, P.value_ok(c, v), u => P.put_capture(name, v, None{}), u => None{})) == None{} : Maybe<&2, P.Params>}:
  match d:
    case None{}:
      {==}
    case Some{+v}:
      choose_none(name, v, P.value_ok(c, v))

def capture_none(+name: String, +c: C.Constraint, +optional: Bool, +rest: List<&2, P.Segment>, +h: String, +t: List<&2, String>,
    none: {P.match_segments(rest, t) == None{} : Maybe<&2, P.Params>}) ->
    {P.match_segments(P.Capture{name, c, optional} <> rest, h <> t) == None{} : Maybe<&2, P.Params>}:
  match optional:
    case True{}:
      %Equal.sym(Maybe<&2, P.Params>, P.match_segments(rest, t), None{}, none) : {Maybe.bind(&2, String, P.Params, E.decode(h), +v => E.choose(Maybe<&2, P.Params>, P.value_ok(c, v), u => P.put_capture(name, v, _), u => None{})) == None{} : Maybe<&2, P.Params>}
      bind_none(name, c, E.decode(h))
    case False{}:
      %Equal.sym(Maybe<&2, P.Params>, P.match_segments(rest, t), None{}, none) : {Maybe.bind(&2, String, P.Params, E.decode(h), +v => E.choose(Maybe<&2, P.Params>, P.value_ok(c, v), u => P.put_capture(name, v, _), u => None{})) == None{} : Maybe<&2, P.Params>}
      bind_none(name, c, E.decode(h))

def same_free(+raw: String, +h: String, same: {raw == h : String}, free: {P.no_percent(raw) == True{} : Bool}) -> {P.no_percent(h) == True{} : Bool}:
  %same : {P.no_percent(_) == True{} : Bool}
  free

def static_none(+raw: String, +rest: List<&2, P.Segment>, +h: String, +t: List<&2, String>,
    test: Bool, decided: {String.eq(raw, h) == test : Bool},
    fixed: {P.no_percent(raw) && P.fixed_tail(rest) == True{} : Bool},
    few: {under(1n+static_count(rest), bump(P.no_percent(h), free_count(t))) == True{} : Bool},
    inner: {under(static_count(rest), free_count(t)) == True{} : Bool} -> {P.match_segments(rest, t) == None{} : Maybe<&2, P.Params>}) ->
    {E.choose(Maybe<&2, P.Params>, test, u => P.match_segments(rest, t), u => None{}) == None{} : Maybe<&2, P.Params>}:
  match test:
    case False{}:
      {==}
    case True{}:
      free = same_free(raw, h, Eq.string_eq_sound(raw, h, decided), Core.and_left(P.no_percent(raw), P.fixed_tail(rest), fixed))
      inner(under_true(static_count(rest), P.no_percent(h), free_count(t), free, few))

# A fixed-width tail needs a static-free segment for each of its statics.
def count_none(+segs: List<&2, P.Segment>, +paths: List<&2, String>,
    fixed: {P.fixed_tail(segs) == True{} : Bool},
    few: {under(static_count(segs), free_count(paths)) == True{} : Bool}) ->
    {P.match_segments(segs, paths) == None{} : Maybe<&2, P.Params>}:
  match segs paths:
    case Nil{} +l:
      Core.absurd({P.match_segments(Nil{}, l) == None{} : Maybe<&2, P.Params>}, Core.false_true(few))
    case P.Static{raw} <> rest Nil{}:
      {==}
    case P.Static{+raw} <> +rest +h <> +t:
      +yes = fixed
      static_none(raw, rest, h, t, String.eq(raw, h), {==}, yes, few, e => count_none(rest, t, Core.and_right(P.no_percent(raw), P.fixed_tail(rest), yes), e))
    case P.Capture{+name, +c, True{}} <> +rest Nil{}:
      count_none(rest, Nil{}, fixed, few)
    case P.Capture{name, c, False{}} <> rest Nil{}:
      {==}
    case P.Capture{+name, +c, +optional} <> +rest +h <> +t:
      capture_none(name, c, optional, rest, h, t, count_none(rest, t, fixed, under_bump(static_count(rest), P.no_percent(h), free_count(t), few)))
    case P.Wildcard{name} <> rest l:
      Core.absurd({P.match_segments(P.Wildcard{name} <> rest, l) == None{} : Maybe<&2, P.Params>}, Core.false_true(fixed))
    case P.InteriorWildcard{} <> rest l:
      Core.absurd({P.match_segments(P.InteriorWildcard{} <> rest, l) == None{} : Maybe<&2, P.Params>}, Core.false_true(fixed))
    case P.PrefixWildcard{prefix} <> rest l:
      Core.absurd({P.match_segments(P.PrefixWildcard{prefix} <> rest, l) == None{} : Maybe<&2, P.Params>}, Core.false_true(fixed))
    case P.Span{name} <> rest l:
      Core.absurd({P.match_segments(P.Span{name} <> rest, l) == None{} : Maybe<&2, P.Params>}, Core.false_true(fixed))

# Filled fixed-width tails have at most one `%`-free segment per static.
def fill_le(m: Maybe<&2, List<&2, String>>, +n: Nat) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{xs}:
      under(1n+n, free_count(xs))

def static_fill_count(+raw: String, free: {P.no_percent(raw) == True{} : Bool}, m: Maybe<&2, List<&2, String>>, +n: Nat,
    prev: {fill_le(m, n) == True{} : Bool}) ->
    {fill_le(Maybe.bind(&2, List<&2, String>, List<&2, String>, m, ys => Some{raw <> ys}), 1n+n) == True{} : Bool}:
  match m:
    case None{}:
      Core.absurd({fill_le(None{}, 1n+n) == True{} : Bool}, Core.false_true(prev))
    case Some{+ys}:
      %Equal.sym(Bool, P.no_percent(raw), True{}, free) : {under(2n+n, bump(_, free_count(ys))) == True{} : Bool}
      prev

def capture_fill_count(+enc: String, encoded: {P.no_percent(enc) == False{} : Bool}, m: Maybe<&2, List<&2, String>>, +n: Nat,
    prev: {fill_le(m, n) == True{} : Bool}) ->
    {fill_le(Maybe.bind(&2, List<&2, String>, List<&2, String>, m, ys => Some{enc <> ys}), n) == True{} : Bool}:
  match m:
    case None{}:
      Core.absurd({fill_le(None{}, n) == True{} : Bool}, Core.false_true(prev))
    case Some{+ys}:
      %Equal.sym(Bool, P.no_percent(enc), False{}, encoded) : {under(1n+n, bump(_, free_count(ys))) == True{} : Bool}
      prev

def capture_fill_eq(+name: String, +c: C.Constraint, +optional: Bool, +rest: List<&2, P.Segment>, +key: String, +value: String, +tail: P.Params) ->
    {P.fill_segments(P.Capture{name, c, optional} <> rest, P.Param{key, value} <> tail) == E.choose(Maybe<&2, List<&2, String>>, String.eq(name, key) && P.value_ok(c, value), u => Maybe.bind(&2, List<&2, String>, List<&2, String>, P.fill_segments(rest, tail), ys => Some{E.encode(value) <> ys}), u => None{}) : Maybe<&2, List<&2, String>>}:
  match optional rest:
    case False{} r:
      {==}
    case True{} Nil{}:
      {==}
    case True{} h <> t:
      {==}

def fill_count(+segs: List<&2, P.Segment>, +ps: P.Params,
    fixed: {P.fixed_tail(segs) == True{} : Bool},
    admitted: {P.admissible_segments(segs, ps) == True{} : Bool}) ->
    {fill_le(P.fill_segments(segs, ps), static_count(segs)) == True{} : Bool}:
  match segs ps:
    case Nil{} Nil{}:
      {==}
    case Nil{} h <> t:
      Core.absurd({fill_le(P.fill_segments(Nil{}, h <> t), 0n) == True{} : Bool}, Core.false_true(admitted))
    case P.Static{+raw} <> +rest +values:
      +yes = fixed
      static_fill_count(raw, Core.and_left(P.no_percent(raw), P.fixed_tail(rest), yes), P.fill_segments(rest, values), static_count(rest), fill_count(rest, values, Core.and_right(P.no_percent(raw), P.fixed_tail(rest), yes), admitted))
    case P.Capture{name, c, True{}} <> +rest Nil{}:
      %Equal.sym(Bool, P.all_optional(rest), True{}, admitted) : {fill_le(E.choose(Maybe<&2, List<&2, String>>, _, u => Some{Nil{}}, u => None{}), static_count(rest)) == True{} : Bool}
      {==}
    case P.Capture{name, c, False{}} <> rest Nil{}:
      Core.absurd({fill_le(P.fill_segments(P.Capture{name, c, False{}} <> rest, Nil{}), static_count(rest)) == True{} : Bool}, Core.false_true(admitted))
    case P.Capture{+name, +c, +optional} <> +rest P.Param{+key, +value} <> +tail:
      +yes = admitted
      +ok = Core.and_left(String.eq(name, key) && P.value_ok(c, value), P.admissible_segments(rest, tail), yes)
      %capture_fill_eq(name, c, optional, rest, key, value, tail) : {fill_le(_, static_count(rest)) == True{} : Bool}
      %Equal.sym(Bool, String.eq(name, key) && P.value_ok(c, value), True{}, ok) : {fill_le(E.choose(Maybe<&2, List<&2, String>>, _, u => Maybe.bind(&2, List<&2, String>, List<&2, String>, P.fill_segments(rest, tail), ys => Some{E.encode(value) <> ys}), u => None{}), static_count(rest)) == True{} : Bool}
      capture_fill_count(E.encode(value), encode_percent(c, value, Core.and_right(String.eq(name, key), P.value_ok(c, value), ok)), P.fill_segments(rest, tail), static_count(rest), fill_count(rest, tail, fixed, Core.and_right(String.eq(name, key) && P.value_ok(c, value), P.admissible_segments(rest, tail), yes)))
    case P.Wildcard{name} <> rest values:
      Core.absurd({fill_le(P.fill_segments(P.Wildcard{name} <> rest, values), static_count(rest)) == True{} : Bool}, Core.false_true(fixed))
    case P.InteriorWildcard{} <> rest values:
      Core.absurd({fill_le(P.fill_segments(P.InteriorWildcard{} <> rest, values), static_count(rest)) == True{} : Bool}, Core.false_true(fixed))
    case P.PrefixWildcard{prefix} <> rest values:
      Core.absurd({fill_le(P.fill_segments(P.PrefixWildcard{prefix} <> rest, values), static_count(rest)) == True{} : Bool}, Core.false_true(fixed))
    case P.Span{name} <> rest values:
      Core.absurd({fill_le(P.fill_segments(P.Span{name} <> rest, values), static_count(rest)) == True{} : Bool}, Core.false_true(fixed))

# After the anchor, the filled tail has fewer `%`-free segments than statics.
def fill_tail(m: Maybe<&2, List<&2, String>>, +n: Nat) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{Nil{}}:
      True{}
    case Some{h <> t}:
      under(n, free_count(t))

def anchor_count(+raw: String, m: Maybe<&2, List<&2, String>>, +n: Nat,
    prev: {fill_le(m, n) == True{} : Bool}) ->
    {fill_tail(Maybe.bind(&2, List<&2, String>, List<&2, String>, m, ys => Some{raw <> ys}), 1n+n) == True{} : Bool}:
  match m:
    case None{}:
      Core.absurd({fill_tail(None{}, 1n+n) == True{} : Bool}, Core.false_true(prev))
    case Some{ys}:
      prev

def fill_tail_count(+rest: List<&2, P.Segment>, +ps: P.Params,
    anchored: {P.span_tail(rest) == True{} : Bool},
    admitted: {P.admissible_segments(rest, ps) == True{} : Bool}) ->
    {fill_tail(P.fill_segments(rest, ps), static_count(rest)) == True{} : Bool}:
  match rest:
    case P.Static{+raw} <> +r:
      anchor_count(raw, P.fill_segments(r, ps), static_count(r), fill_count(r, ps, Core.and_right(P.no_percent(raw), P.fixed_tail(r), anchored), admitted))
    case Nil{}:
      Core.absurd({fill_tail(P.fill_segments(Nil{}, ps), 0n) == True{} : Bool}, Core.false_true(anchored))
    case P.Capture{name, c, optional} <> r:
      Core.absurd({fill_tail(P.fill_segments(P.Capture{name, c, optional} <> r, ps), static_count(r)) == True{} : Bool}, Core.false_true(anchored))
    case P.Wildcard{name} <> r:
      Core.absurd({fill_tail(P.fill_segments(P.Wildcard{name} <> r, ps), static_count(r)) == True{} : Bool}, Core.false_true(anchored))
    case P.InteriorWildcard{} <> r:
      Core.absurd({fill_tail(P.fill_segments(P.InteriorWildcard{} <> r, ps), static_count(r)) == True{} : Bool}, Core.false_true(anchored))
    case P.PrefixWildcard{prefix} <> r:
      Core.absurd({fill_tail(P.fill_segments(P.PrefixWildcard{prefix} <> r, ps), static_count(r)) == True{} : Bool}, Core.false_true(anchored))
    case P.Span{name} <> r:
      Core.absurd({fill_tail(P.fill_segments(P.Span{name} <> r, ps), static_count(r)) == True{} : Bool}, Core.false_true(anchored))

def tail_fixed(+rest: List<&2, P.Segment>, anchored: {P.span_tail(rest) == True{} : Bool}) -> {P.fixed_tail(rest) == True{} : Bool}:
  match rest:
    case P.Static{raw} <> r:
      anchored
    case Nil{}:
      Core.absurd({P.fixed_tail(Nil{}) == True{} : Bool}, Core.false_true(anchored))
    case P.Capture{name, c, optional} <> r:
      Core.absurd({P.fixed_tail(P.Capture{name, c, optional} <> r) == True{} : Bool}, Core.false_true(anchored))
    case P.Wildcard{name} <> r:
      Core.absurd({P.fixed_tail(P.Wildcard{name} <> r) == True{} : Bool}, Core.false_true(anchored))
    case P.InteriorWildcard{} <> r:
      Core.absurd({P.fixed_tail(P.InteriorWildcard{} <> r) == True{} : Bool}, Core.false_true(anchored))
    case P.PrefixWildcard{prefix} <> r:
      Core.absurd({P.fixed_tail(P.PrefixWildcard{prefix} <> r) == True{} : Bool}, Core.false_true(anchored))
    case P.Span{name} <> r:
      Core.absurd({P.fixed_tail(P.Span{name} <> r) == True{} : Bool}, Core.false_true(anchored))

# The tail fails on a list and on every suffix of it.
def AllFail(+rest: List<&2, P.Segment>, +ys: List<&2, String>) -> Type:
  match ys:
    case Nil{}:
      {P.search_segments(rest, Nil{}) == None{} : Maybe<&2, P.Params>}
    case h <> +t:
      {P.search_segments(rest, h <> t) == None{} : Maybe<&2, P.Params>} & AllFail(rest, t)

def ProperFail(+rest: List<&2, P.Segment>, +xs: List<&2, String>) -> Type:
  match xs:
    case Nil{}:
      Unit
    case h <> +t:
      AllFail(rest, t)

def all_fail(+rest: List<&2, P.Segment>, +ys: List<&2, String>,
    +fixed: {P.fixed_tail(rest) == True{} : Bool},
    few: {under(static_count(rest), free_count(ys)) == True{} : Bool}) -> AllFail(rest, ys):
  match ys:
    case Nil{}:
      Equal.trans(Maybe<&2, P.Params>, P.search_segments(rest, Nil{}), P.match_segments(rest, Nil{}), None{}, Core.search_equal(rest, Nil{}), count_none(rest, Nil{}, fixed, few))
    case +h <> +t:
      +more = few
      (Equal.trans(Maybe<&2, P.Params>, P.search_segments(rest, h <> t), P.match_segments(rest, h <> t), None{}, Core.search_equal(rest, h <> t), count_none(rest, h <> t, fixed, more)), all_fail(rest, t, fixed, under_bump(static_count(rest), P.no_percent(h), free_count(t), more)))

def split_fail(+rest: List<&2, P.Segment>, +t: List<&2, String>, fails: AllFail(rest, t)) ->
    {P.search_segments(rest, t) == None{} : Maybe<&2, P.Params>} & ProperFail(rest, t):
  match t:
    case Nil{}:
      (fails, Unit{})
    case h <> u:
      fails

def scan_cons(+rest: List<&2, P.Segment>, +h: String, +t: List<&2, String>, +name: String, +taken: List<&2, String>,
    parts: {P.search_segments(rest, t) == None{} : Maybe<&2, P.Params>} & ProperFail(rest, t),
    inner: ProperFail(rest, t) -> {P.span_scan(t, P.match_rows(~String.eq, ~String.starts_with, rest, t), name, h <> taken) == None{} : Maybe<&2, P.Params>}) ->
    {P.span_scan(h <> t, P.match_rows(~String.eq, ~String.starts_with, rest, h <> t), name, taken) == None{} : Maybe<&2, P.Params>}:
  (here, later) = parts
  %Equal.sym(Core.Rows, P.match_rows(~String.eq, ~String.starts_with, rest, h <> t), P.search_segments(rest, h <> t) <> P.match_rows(~String.eq, ~String.starts_with, rest, t), Core.rows_cons(rest, h, t)) : {P.span_scan(h <> t, _, name, taken) == None{} : Maybe<&2, P.Params>}
  %Equal.sym(Maybe<&2, P.Params>, P.span_scan(t, P.match_rows(~String.eq, ~String.starts_with, rest, t), name, h <> taken), None{}, inner(later)) : {P.prefer(_, u => P.span_value(name, h <> taken, P.row_head(P.match_rows(~String.eq, ~String.starts_with, rest, t)))) == None{} : Maybe<&2, P.Params>}
  %Equal.sym(Maybe<&2, P.Params>, P.search_segments(rest, t), None{}, here) : {P.span_value(name, h <> taken, _) == None{} : Maybe<&2, P.Params>}
  {==}

def scan_none(+rest: List<&2, P.Segment>, +xs: List<&2, String>, +name: String, +taken: List<&2, String>,
    fails: ProperFail(rest, xs)) ->
    {P.span_scan(xs, P.match_rows(~String.eq, ~String.starts_with, rest, xs), name, taken) == None{} : Maybe<&2, P.Params>}:
  match xs:
    case Nil{}:
      {==}
    case +h <> +t:
      scan_cons(rest, h, t, name, taken, split_fail(rest, t, fails), p => scan_none(rest, t, name, h <> taken, p))

def proper_fail(+rest: List<&2, P.Segment>, +xs: List<&2, String>,
    +fixed: {P.fixed_tail(rest) == True{} : Bool},
    counted: {fill_tail(Some{xs}, static_count(rest)) == True{} : Bool}) -> ProperFail(rest, xs):
  match xs:
    case Nil{}:
      Unit{}
    case h <> +t:
      all_fail(rest, t, fixed, counted)

def span_step(+name: String, +rest: List<&2, P.Segment>, +key: String, +value: String, +tail: P.Params,
    +same: {String.eq(name, key) == True{} : Bool},
    +valid: {P.value_ok(C.Any{}, value) == True{} : Bool},
    +anchored: {P.span_tail(rest) == True{} : Bool},
    rest_ok: {P.admissible_segments(rest, tail) == True{} : Bool},
    success: Roundtrip(rest, tail)) -> Roundtrip(P.Span{name} <> rest, P.Param{key, value} <> tail):
  (+xs, (+filled, (clean, matched))) = success
  +unicode = Core.and_right(Bool.not(String.is_empty(value)), E.scalars(value), Core.and_left(Bool.not(String.is_empty(value)) && E.scalars(value), C.accepts(C.Any{}, value), valid))
  counted = Equal.trans(Bool, fill_tail(Some{xs}, static_count(rest)), fill_tail(P.fill_segments(rest, tail), static_count(rest)), True{}, Equal.cong(Maybe<&2, List<&2, String>>, Bool, m => fill_tail(m, static_count(rest)), Some{xs}, P.fill_segments(rest, tail), Equal.sym(Maybe<&2, List<&2, String>>, P.fill_segments(rest, tail), Some{xs}, filled)), fill_tail_count(rest, tail, anchored, rest_ok))
  +enc = E.encode(value)
  (enc <> xs, ((
    %Equal.sym(Bool, (String.eq(name, key) && P.value_ok(C.Any{}, value)) && P.span_tail(rest), True{}, Codec.and_true(String.eq(name, key) && P.value_ok(C.Any{}, value), P.span_tail(rest), Codec.and_true(String.eq(name, key), P.value_ok(C.Any{}, value), same, valid), anchored)) : {E.choose(Maybe<&2, List<&2, String>>, _, u => Maybe.bind(&2, List<&2, String>, List<&2, String>, P.fill_segments(rest, tail), ys => Some{enc <> ys}), u => None{}) == Some{enc <> xs} : Maybe<&2, List<&2, String>>}
    %Equal.sym(Maybe<&2, List<&2, String>>, P.fill_segments(rest, tail), Some{xs}, filled) : {Maybe.bind(&2, List<&2, String>, List<&2, String>, _, ys => Some{enc <> ys}) == Some{enc <> xs} : Maybe<&2, List<&2, String>>}
    {==}
  ), ((
    %Equal.sym(Bool, Core.no_slash(enc), True{}, Core.encode_no_slash(value, unicode)) : {_ && Core.clean_segments(xs) == True{} : Bool}
    clean
  ), (
    %Equal.sym(Core.Rows, P.match_rows(~String.eq, ~String.starts_with, rest, enc <> xs), P.search_segments(rest, enc <> xs) <> P.match_rows(~String.eq, ~String.starts_with, rest, xs), Core.rows_cons(rest, enc, xs)) : {P.span_scan(enc <> xs, _, name, Nil{}) == Some{P.Param{key, value} <> tail} : Maybe<&2, P.Params>}
    %Equal.sym(Maybe<&2, P.Params>, P.span_scan(xs, P.match_rows(~String.eq, ~String.starts_with, rest, xs), name, [enc]), None{}, scan_none(rest, xs, name, [enc], proper_fail(rest, xs, tail_fixed(rest, anchored), counted))) : {P.prefer(_, u => P.span_value(name, [enc], P.row_head(P.match_rows(~String.eq, ~String.starts_with, rest, xs)))) == Some{P.Param{key, value} <> tail} : Maybe<&2, P.Params>}
    %Equal.sym(Maybe<&2, P.Params>, P.search_segments(rest, xs), Some{tail}, Equal.trans(Maybe<&2, P.Params>, P.search_segments(rest, xs), P.match_segments(rest, xs), Some{tail}, Core.search_equal(rest, xs), matched)) : {P.span_value(name, [enc], _) == Some{P.Param{key, value} <> tail} : Maybe<&2, P.Params>}
    %Equal.sym(Maybe<&2, String>, E.decode(E.encode(value)), Some{value}, Codec.codec_roundtrip(value, unicode)) : {Maybe.bind(&2, String, P.Params, _, +v => E.choose(Maybe<&2, P.Params>, P.value_ok(C.Any{}, v), u => Some{P.Param{name, v} <> tail}, u => None{})) == Some{P.Param{key, value} <> tail} : Maybe<&2, P.Params>}
    %Equal.sym(Bool, P.value_ok(C.Any{}, value), True{}, valid) : {E.choose(Maybe<&2, P.Params>, _, u => Some{P.Param{name, value} <> tail}, u => None{}) == Some{P.Param{key, value} <> tail} : Maybe<&2, P.Params>}
    Equal.cong(String, Maybe<&2, P.Params>, n => Some{P.Param{n, value} <> tail}, name, key, Eq.string_eq_sound(name, key, same))
  ))))

def optional_filled(+segs: List<&2, P.Segment>, yes: {P.all_optional(segs) == True{} : Bool}) ->
    {P.fill_segments(segs, Nil{}) == Some{Nil{}} : Maybe<&2, List<&2, String>>}:
  match segs:
    case Nil{}:
      {==}
    case P.Capture{name, c, True{}} <> +rest:
      %Equal.sym(Bool, P.all_optional(rest), True{}, yes) : {E.choose(Maybe<&2, List<&2, String>>, _, u => Some{Nil{}}, u => None{}) == Some{Nil{}} : Maybe<&2, List<&2, String>>}
      {==}
    case P.Capture{name, c, False{}} <> rest:
      Core.absurd({P.fill_segments(P.Capture{name, c, False{}} <> rest, Nil{}) == Some{Nil{}} : Maybe<&2, List<&2, String>>}, Core.false_true(yes))
    case P.Static{raw} <> rest:
      Core.absurd({P.fill_segments(P.Static{raw} <> rest, Nil{}) == Some{Nil{}} : Maybe<&2, List<&2, String>>}, Core.false_true(yes))
    case P.Wildcard{name} <> rest:
      Core.absurd({P.fill_segments(P.Wildcard{name} <> rest, Nil{}) == Some{Nil{}} : Maybe<&2, List<&2, String>>}, Core.false_true(yes))
    case P.InteriorWildcard{} <> rest:
      Core.absurd({P.fill_segments(P.InteriorWildcard{} <> rest, Nil{}) == Some{Nil{}} : Maybe<&2, List<&2, String>>}, Core.false_true(yes))
    case P.PrefixWildcard{prefix} <> rest:
      Core.absurd({P.fill_segments(P.PrefixWildcard{prefix} <> rest, Nil{}) == Some{Nil{}} : Maybe<&2, List<&2, String>>}, Core.false_true(yes))
    case P.Span{name} <> rest:
      Core.absurd({P.fill_segments(P.Span{name} <> rest, Nil{}) == Some{Nil{}} : Maybe<&2, List<&2, String>>}, Core.false_true(yes))

def optional_matched(+segs: List<&2, P.Segment>, yes: {P.all_optional(segs) == True{} : Bool}) ->
    {P.match_segments(segs, Nil{}) == Some{Nil{}} : Maybe<&2, P.Params>}:
  match segs:
    case Nil{}:
      {==}
    case P.Capture{name, c, True{}} <> +rest:
      optional_matched(rest, yes)
    case P.Capture{name, c, False{}} <> rest:
      Core.absurd({P.match_segments(P.Capture{name, c, False{}} <> rest, Nil{}) == Some{Nil{}} : Maybe<&2, P.Params>}, Core.false_true(yes))
    case P.Static{raw} <> rest:
      Core.absurd({P.match_segments(P.Static{raw} <> rest, Nil{}) == Some{Nil{}} : Maybe<&2, P.Params>}, Core.false_true(yes))
    case P.Wildcard{name} <> rest:
      Core.absurd({P.match_segments(P.Wildcard{name} <> rest, Nil{}) == Some{Nil{}} : Maybe<&2, P.Params>}, Core.false_true(yes))
    case P.InteriorWildcard{} <> rest:
      Core.absurd({P.match_segments(P.InteriorWildcard{} <> rest, Nil{}) == Some{Nil{}} : Maybe<&2, P.Params>}, Core.false_true(yes))
    case P.PrefixWildcard{prefix} <> rest:
      Core.absurd({P.match_segments(P.PrefixWildcard{prefix} <> rest, Nil{}) == Some{Nil{}} : Maybe<&2, P.Params>}, Core.false_true(yes))
    case P.Span{name} <> rest:
      Core.absurd({P.match_segments(P.Span{name} <> rest, Nil{}) == Some{Nil{}} : Maybe<&2, P.Params>}, Core.false_true(yes))

# Every clean hand-built segment list roundtrips every admissible assignment.
# Admissibility alone excludes the forms compile rejects.
law match_fill_segments:
  for +segs: List<&2, P.Segment>
  for +ps: P.Params
  for clean: {Compile.segments_clean(segs) == True{} : Bool}
  for admitted: {P.admissible_segments(segs, ps) == True{} : Bool}
  Roundtrip(segs, ps)

def match_fill_segments(segs, ps, clean, admitted):
  match segs ps:
    case Nil{} Nil{}:
      (Nil{}, ({==}, ({==}, {==})))
    case P.Static{+raw} <> +rest +values:
      +yes = clean
      static_step(raw, rest, values, Core.and_left(Core.no_slash(raw), Compile.segments_clean(rest), yes), match_fill_segments(rest, values, Core.and_right(Core.no_slash(raw), Compile.segments_clean(rest), yes), admitted))
    case P.Capture{+name, +c, True{}} <> +rest Nil{}:
      +yes = admitted
      (Nil{}, (optional_filled(P.Capture{name, c, True{}} <> rest, yes), ({==}, optional_matched(P.Capture{name, c, True{}} <> rest, yes))))
    case P.InteriorWildcard{} <> +rest +values:
      interior_step(rest, values, match_fill_segments(rest, values, clean, admitted))
    case P.PrefixWildcard{+prefix} <> Nil{} Nil{}:
      prefix_step(prefix, Core.and_left(Core.no_slash(prefix), True{}, clean))
    case P.Span{+name} <> +rest P.Param{+key, +value} <> +tail:
      +yes = admitted
      +head = Core.and_left((String.eq(name, key) && P.value_ok(C.Any{}, value)) && P.span_tail(rest), P.admissible_segments(rest, tail), yes)
      +ok = Core.and_left(String.eq(name, key) && P.value_ok(C.Any{}, value), P.span_tail(rest), head)
      +rest_ok = Core.and_right((String.eq(name, key) && P.value_ok(C.Any{}, value)) && P.span_tail(rest), P.admissible_segments(rest, tail), yes)
      span_step(name, rest, key, value, tail, Core.and_left(String.eq(name, key), P.value_ok(C.Any{}, value), ok), Core.and_right(String.eq(name, key), P.value_ok(C.Any{}, value), ok), Core.and_right(String.eq(name, key) && P.value_ok(C.Any{}, value), P.span_tail(rest), head), rest_ok, match_fill_segments(rest, tail, clean, rest_ok))
    case P.Capture{+name, +c, +optional} <> +rest P.Param{+key, +value} <> +tail:
      +yes = admitted
      +ok = Core.and_left(String.eq(name, key) && P.value_ok(c, value), P.admissible_segments(rest, tail), yes)
      capture_step(name, c, optional, rest, key, value, tail, Core.and_left(String.eq(name, key), P.value_ok(c, value), ok), Core.and_right(String.eq(name, key), P.value_ok(c, value), ok), match_fill_segments(rest, tail, Core.and_right(True{}, Compile.segments_clean(rest), clean), Core.and_right(String.eq(name, key) && P.value_ok(c, value), P.admissible_segments(rest, tail), yes)))
    case P.Wildcard{+name} <> Nil{} P.Param{+key, +value} <> Nil{}:
      +ok = admitted
      +unicode = Core.and_right(String.eq(name, key), E.scalars(value), ok)
      ([E.encode(value)], ((
        %Equal.sym(Bool, String.eq(name, key) && E.scalars(value), True{}, ok) : {E.choose(Maybe<&2, List<&2, String>>, _, u => Some{[E.encode(value)]}, u => None{}) == Some{[E.encode(value)]} : Maybe<&2, List<&2, String>>}
        {==}
      ), ((
        %Equal.sym(Bool, Core.no_slash(E.encode(value)), True{}, Core.encode_no_slash(value, unicode)) : {_ && True{} == True{} : Bool}
        {==}
      ), (
        %Equal.sym(Maybe<&2, String>, E.decode(E.encode(value)), Some{value}, Codec.codec_roundtrip(value, unicode)) : {P.wildcard_param(name, _) == Some{[P.Param{key, value}]} : Maybe<&2, P.Params>}
        Equal.cong(String, Maybe<&2, P.Params>, n => Some{[P.Param{n, value}]}, name, key, Eq.string_eq_sound(name, key, Core.and_left(String.eq(name, key), E.scalars(value), ok)))
      ))))
    case Nil{} h <> t:
      Core.absurd(Roundtrip(Nil{}, h <> t), Core.false_true(admitted))
    case P.Capture{name, c, False{}} <> rest Nil{}:
      Core.absurd(Roundtrip(P.Capture{name, c, False{}} <> rest, Nil{}), Core.false_true(admitted))
    case P.Wildcard{name} <> Nil{} Nil{}:
      Core.absurd(Roundtrip([P.Wildcard{name}], Nil{}), Core.false_true(admitted))
    case P.Wildcard{name} <> Nil{} h <> j <> t:
      Core.absurd(Roundtrip([P.Wildcard{name}], h <> j <> t), Core.false_true(admitted))
    case P.Wildcard{name} <> h <> t values:
      Core.absurd(Roundtrip(P.Wildcard{name} <> h <> t, values), Core.false_true(admitted))
    case P.PrefixWildcard{prefix} <> Nil{} h <> t:
      Core.absurd(Roundtrip([P.PrefixWildcard{prefix}], h <> t), Core.false_true(admitted))
    case P.PrefixWildcard{prefix} <> h <> t values:
      Core.absurd(Roundtrip(P.PrefixWildcard{prefix} <> h <> t, values), Core.false_true(admitted))
    case P.Span{name} <> rest Nil{}:
      Core.absurd(Roundtrip(P.Span{name} <> rest, Nil{}), Core.false_true(admitted))

# The compiled-shape variant, for callers that carry segments_shape.
law match_fill_segments_shaped:
  for +segs: List<&2, P.Segment>
  for +ps: P.Params
  for clean: {Compile.segments_clean(segs) == True{} : Bool}
  for shape: {Compile.segments_shape(segs) == True{} : Bool}
  for admitted: {P.admissible_segments(segs, ps) == True{} : Bool}
  Roundtrip(segs, ps)

def match_fill_segments_shaped(segs, ps, clean, shape, admitted):
  match_fill_segments(segs, ps, clean, admitted)

def params_some(r: Maybe<&2, P.Params>) -> Bool:
  match r:
    case None{}:
      False{}
    case Some{ps}:
      True{}

def none_some(+ps: P.Params, e: {None{} == Some{ps} : Maybe<&2, P.Params>}) -> Empty:
  Core.false_true(Equal.cong(Maybe<&2, P.Params>, Bool, r => params_some(r), None{}, Some{ps}, e))

# Optional chains have a separate root-path branch. An empty raw segment
# cannot be an admissible present capture.
def match_tail(+segs: List<&2, P.Segment>, +ps: P.Params, +tail: String,
    matched: {P.match_segments(segs, P.path_segments(tail)) == Some{ps} : Maybe<&2, P.Params>}) ->
    {P.match_path(P.Pattern{segs}, "/" ++ tail) == Some{ps} : Maybe<&2, P.Params>}:
  match segs tail:
    case P.Capture{name, c, True{}} <> rest SNil{}:
      Core.absurd({P.match_path(P.Pattern{P.Capture{name, c, True{}} <> rest}, "/") == Some{ps} : Maybe<&2, P.Params>}, none_some(ps, matched))
    case P.Capture{name, c, True{}} <> rest SCon{h, t}:
      matched
    case P.Capture{name, c, False{}} <> rest t:
      matched
    case P.Static{raw} <> rest t:
      matched
    case P.Wildcard{name} <> rest t:
      matched
    case P.InteriorWildcard{} <> rest t:
      matched
    case P.PrefixWildcard{prefix} <> rest t:
      matched
    case P.Span{name} <> rest t:
      matched
    case Nil{} t:
      matched

def has_empty(r: Maybe<&2, List<&2, String>>) -> Bool:
  match r:
    case Some{Nil{}}:
      True{}
    case _:
      False{}

def wildcard_guard_nonempty(+value: String, test: Bool) ->
    {has_empty(E.choose(Maybe<&2, List<&2, String>>, test, u => Some{[E.encode(value)]}, u => None{})) == False{} : Bool}:
  match test:
    case True{}:
      {==}
    case False{}:
      {==}

def wildcard_fill_nonempty(+name: String, +ps: P.Params) ->
    {has_empty(P.fill_segments([P.Wildcard{name}], ps)) == False{} : Bool}:
  match ps:
    case Nil{}:
      {==}
    case P.Param{+key, +value} <> Nil{}:
      wildcard_guard_nonempty(value, String.eq(name, key) && E.scalars(value))
    case h <> j <> rest:
      {==}

def bind_nonempty(+raw: String, r: Maybe<&2, List<&2, String>>) ->
    {has_empty(Maybe.bind(&2, List<&2, String>, List<&2, String>, r, xs => Some{raw <> xs})) == False{} : Bool}:
  match r:
    case None{}:
      {==}
    case Some{xs}:
      {==}

def guard_bind_nonempty(+raw: String, +r: Maybe<&2, List<&2, String>>, test: Bool) ->
    {has_empty(E.choose(Maybe<&2, List<&2, String>>, test, u => Maybe.bind(&2, List<&2, String>, List<&2, String>, r, xs => Some{raw <> xs}), u => None{})) == False{} : Bool}:
  match test:
    case False{}:
      {==}
    case True{}:
      bind_nonempty(raw, r)

def capture_nonempty(+name: String, +c: C.Constraint, +optional: Bool, +rest: List<&2, P.Segment>, +key: String, +value: String, +tail: P.Params) ->
    {has_empty(P.fill_segments(P.Capture{name, c, optional} <> rest, P.Param{key, value} <> tail)) == False{} : Bool}:
  match optional rest:
    case False{} +r:
      guard_bind_nonempty(E.encode(value), P.fill_segments(r, tail), String.eq(name, key) && P.value_ok(c, value))
    case True{} Nil{}:
      guard_bind_nonempty(E.encode(value), P.fill_segments(Nil{}, tail), String.eq(name, key) && P.value_ok(c, value))
    case True{} +h <> +t:
      guard_bind_nonempty(E.encode(value), P.fill_segments(h <> t, tail), String.eq(name, key) && P.value_ok(c, value))

def filled_impossible(+r: Maybe<&2, List<&2, String>>,
    not_empty: {has_empty(r) == False{} : Bool},
    filled: {r == Some{Nil{}} : Maybe<&2, List<&2, String>>}) -> Empty:
  Core.false_true(Equal.trans(Bool, False{}, has_empty(r), True{}, Equal.sym(Bool, has_empty(r), False{}, not_empty), Equal.cong(Maybe<&2, List<&2, String>>, Bool, x => has_empty(x), r, Some{Nil{}}, filled)))

def prefer_some(r: Maybe<&2, P.Params>, +ps: P.Params,
    e: {P.prefer(r, u => None{}) == Some{ps} : Maybe<&2, P.Params>}) -> {r == Some{ps} : Maybe<&2, P.Params>}:
  match r:
    case None{}:
      Core.absurd({None{} == Some{ps} : Maybe<&2, P.Params>}, none_some(ps, e))
    case Some{qs}:
      e

def opt_true(b: Bool, e: {E.choose(Maybe<&2, List<&2, String>>, b, u => Some{Nil{}}, u => None{}) == Some{Nil{}} : Maybe<&2, List<&2, String>>}) -> {b == True{} : Bool}:
  match b:
    case True{}:
      {==}
    case False{}:
      Core.absurd({False{} == True{} : Bool}, Core.none_some(List<&2, String>, Nil{}, e))

# The root path "/" is the single empty segment. An assignment that fills to
# "/" either fails on that segment or lets interiors absorb it.
def RootOk(+segs: List<&2, P.Segment>, +ps: P.Params) -> Type:
  {P.prefer(P.match_segments(segs, [""]), u => Some{ps}) == Some{ps} : Maybe<&2, P.Params>}

def root_ok(+segs: List<&2, P.Segment>, +ps: P.Params,
    filled: {P.fill_segments(segs, ps) == Some{Nil{}} : Maybe<&2, List<&2, String>>},
    +matched: {P.match_segments(segs, Nil{}) == Some{ps} : Maybe<&2, P.Params>}) -> RootOk(segs, ps):
  match segs ps:
    case Nil{} Nil{}:
      {==}
    case P.Capture{+name, +c, True{}} <> +rest Nil{}:
      {==}
    case P.InteriorWildcard{} <> +rest +values:
      +m_rest = Equal.trans(Maybe<&2, P.Params>, P.match_segments(rest, Nil{}), P.search_segments(rest, Nil{}), Some{values}, Equal.sym(Maybe<&2, P.Params>, P.search_segments(rest, Nil{}), P.match_segments(rest, Nil{}), Core.search_equal(rest, Nil{})), prefer_some(P.search_segments(rest, Nil{}), values, matched))
      %Equal.sym(Maybe<&2, P.Params>, P.search_segments(P.InteriorWildcard{} <> rest, [""]), P.row_one(~String.eq, ~String.starts_with, P.InteriorWildcard{}, List.is_empty(&2, P.Segment, rest), [""], P.match_rows(~String.eq, ~String.starts_with, rest, [""]), Core.below(P.InteriorWildcard{}, rest, [""])), Core.rows_head(P.InteriorWildcard{}, rest, [""])) : {P.prefer(_, u => Some{values}) == Some{values} : Maybe<&2, P.Params>}
      %Equal.sym(Maybe<&2, P.Params>, P.match_segments(P.InteriorWildcard{} <> rest, Nil{}), Some{values}, matched) : {P.prefer(P.prefer(P.row_head(P.match_rows(~String.eq, ~String.starts_with, rest, [""])), u => _), u => Some{values}) == Some{values} : Maybe<&2, P.Params>}
      %Equal.sym(Maybe<&2, P.Params>, P.search_segments(rest, [""]), P.match_segments(rest, [""]), Core.search_equal(rest, [""])) : {P.prefer(P.prefer(_, u => Some{values}), u => Some{values}) == Some{values} : Maybe<&2, P.Params>}
      %Equal.sym(Maybe<&2, P.Params>, P.prefer(P.match_segments(rest, [""]), u => Some{values}), Some{values}, root_ok(rest, values, filled, m_rest)) : {P.prefer(_, u => Some{values}) == Some{values} : Maybe<&2, P.Params>}
      {==}
    case Nil{} +h <> +t:
      Core.absurd(RootOk(Nil{}, h <> t), filled_impossible(P.fill_segments(Nil{}, h <> t), {==}, filled))
    case P.Static{+raw} <> +rest +values:
      Core.absurd(RootOk(P.Static{raw} <> rest, values), filled_impossible(P.fill_segments(P.Static{raw} <> rest, values), bind_nonempty(raw, P.fill_segments(rest, values)), filled))
    case P.Capture{+name, +c, False{}} <> +rest Nil{}:
      Core.absurd(RootOk(P.Capture{name, c, False{}} <> rest, Nil{}), filled_impossible(P.fill_segments(P.Capture{name, c, False{}} <> rest, Nil{}), {==}, filled))
    case P.Capture{+name, +c, +optional} <> +rest P.Param{+key, +value} <> +tail:
      Core.absurd(RootOk(P.Capture{name, c, optional} <> rest, P.Param{key, value} <> tail), filled_impossible(P.fill_segments(P.Capture{name, c, optional} <> rest, P.Param{key, value} <> tail), capture_nonempty(name, c, optional, rest, key, value, tail), filled))
    case P.PrefixWildcard{+prefix} <> Nil{} Nil{}:
      Core.absurd(RootOk([P.PrefixWildcard{prefix}], Nil{}), filled_impossible(P.fill_segments([P.PrefixWildcard{prefix}], Nil{}), {==}, filled))
    case P.PrefixWildcard{+prefix} <> Nil{} +h <> +t:
      Core.absurd(RootOk([P.PrefixWildcard{prefix}], h <> t), filled_impossible(P.fill_segments([P.PrefixWildcard{prefix}], h <> t), {==}, filled))
    case P.PrefixWildcard{+prefix} <> +h <> +t +values:
      Core.absurd(RootOk(P.PrefixWildcard{prefix} <> h <> t, values), filled_impossible(P.fill_segments(P.PrefixWildcard{prefix} <> h <> t, values), {==}, filled))
    case P.Span{+name} <> +rest Nil{}:
      Core.absurd(RootOk(P.Span{name} <> rest, Nil{}), filled_impossible(P.fill_segments(P.Span{name} <> rest, Nil{}), {==}, filled))
    case P.Span{+name} <> +rest P.Param{+key, +value} <> +tail:
      Core.absurd(RootOk(P.Span{name} <> rest, P.Param{key, value} <> tail), filled_impossible(P.fill_segments(P.Span{name} <> rest, P.Param{key, value} <> tail), guard_bind_nonempty(E.encode(value), P.fill_segments(rest, tail), (String.eq(name, key) && P.value_ok(C.Any{}, value)) && P.span_tail(rest)), filled))
    case P.Wildcard{+name} <> Nil{} +values:
      Core.absurd(RootOk([P.Wildcard{name}], values), filled_impossible(P.fill_segments([P.Wildcard{name}], values), wildcard_fill_nonempty(name, values), filled))
    case P.Wildcard{+name} <> +h <> +t +values:
      Core.absurd(RootOk(P.Wildcard{name} <> h <> t, values), filled_impossible(P.fill_segments(P.Wildcard{name} <> h <> t, values), {==}, filled))

def interior_root(+rest: List<&2, P.Segment>, +values: P.Params,
    filled: {P.fill_segments(rest, values) == Some{Nil{}} : Maybe<&2, List<&2, String>>},
    +matched: {P.match_segments(P.InteriorWildcard{} <> rest, Nil{}) == Some{values} : Maybe<&2, P.Params>}) ->
    {P.match_path(P.Pattern{P.InteriorWildcard{} <> rest}, "/") == Some{values} : Maybe<&2, P.Params>}:
  +m_rest = Equal.trans(Maybe<&2, P.Params>, P.match_segments(rest, Nil{}), P.search_segments(rest, Nil{}), Some{values}, Equal.sym(Maybe<&2, P.Params>, P.search_segments(rest, Nil{}), P.match_segments(rest, Nil{}), Core.search_equal(rest, Nil{})), prefer_some(P.search_segments(rest, Nil{}), values, matched))
  %Equal.sym(Maybe<&2, P.Params>, P.search_segments(P.InteriorWildcard{} <> rest, [""]), P.row_one(~String.eq, ~String.starts_with, P.InteriorWildcard{}, List.is_empty(&2, P.Segment, rest), [""], P.match_rows(~String.eq, ~String.starts_with, rest, [""]), Core.below(P.InteriorWildcard{}, rest, [""])), Core.rows_head(P.InteriorWildcard{}, rest, [""])) : {_ == Some{values} : Maybe<&2, P.Params>}
  %Equal.sym(Maybe<&2, P.Params>, P.match_segments(P.InteriorWildcard{} <> rest, Nil{}), Some{values}, matched) : {P.prefer(P.row_head(P.match_rows(~String.eq, ~String.starts_with, rest, [""])), u => _) == Some{values} : Maybe<&2, P.Params>}
  %Equal.sym(Maybe<&2, P.Params>, P.search_segments(rest, [""]), P.match_segments(rest, [""]), Core.search_equal(rest, [""])) : {P.prefer(_, u => Some{values}) == Some{values} : Maybe<&2, P.Params>}
  root_ok(rest, values, filled, m_rest)

def empty_match(+segs: List<&2, P.Segment>, +ps: P.Params,
    +filled: {P.fill_segments(segs, ps) == Some{Nil{}} : Maybe<&2, List<&2, String>>},
    +matched: {P.match_segments(segs, Nil{}) == Some{ps} : Maybe<&2, P.Params>},
    nonempty: {Bool.not(List.is_empty(&2, P.Segment, segs)) == True{} : Bool}) ->
    {P.match_path(P.Pattern{segs}, "/") == Some{ps} : Maybe<&2, P.Params>}:
  match segs ps:
    case Nil{} values:
      Core.absurd({P.match_path(P.Pattern{Nil{}}, "/") == Some{values} : Maybe<&2, P.Params>}, Core.false_true(nonempty))
    case P.Capture{+name, +c, True{}} <> +rest Nil{}:
      %Equal.sym(Bool, P.all_optional(rest), True{}, opt_true(P.all_optional(rest), filled)) : {E.choose(Maybe<&2, P.Params>, _, u => Some{Nil{}}, u => P.match_segments(P.Capture{name, c, True{}} <> rest, [""])) == Some{Nil{}} : Maybe<&2, P.Params>}
      {==}
    case P.Capture{+name, +c, True{}} <> +rest P.Param{+key, +value} <> +tail:
      Core.absurd({P.match_path(P.Pattern{P.Capture{name, c, True{}} <> rest}, "/") == Some{P.Param{key, value} <> tail} : Maybe<&2, P.Params>}, filled_impossible(P.fill_segments(P.Capture{name, c, True{}} <> rest, P.Param{key, value} <> tail), capture_nonempty(name, c, True{}, rest, key, value, tail), filled))
    case P.InteriorWildcard{} <> +rest +values:
      interior_root(rest, values, filled, matched)
    case P.Static{raw} <> rest values:
      Core.absurd({P.match_path(P.Pattern{P.Static{raw} <> rest}, "/") == Some{values} : Maybe<&2, P.Params>}, none_some(values, matched))
    case P.Capture{name, c, False{}} <> rest values:
      Core.absurd({P.match_path(P.Pattern{P.Capture{name, c, False{}} <> rest}, "/") == Some{values} : Maybe<&2, P.Params>}, none_some(values, matched))
    case P.PrefixWildcard{prefix} <> rest values:
      Core.absurd({P.match_path(P.Pattern{P.PrefixWildcard{prefix} <> rest}, "/") == Some{values} : Maybe<&2, P.Params>}, none_some(values, matched))
    case P.Span{name} <> rest values:
      Core.absurd({P.match_path(P.Pattern{P.Span{name} <> rest}, "/") == Some{values} : Maybe<&2, P.Params>}, none_some(values, matched))
    case P.Wildcard{+name} <> Nil{} +values:
      Core.absurd({P.match_path(P.Pattern{[P.Wildcard{name}]}, "/") == Some{values} : Maybe<&2, P.Params>}, filled_impossible(P.fill_segments([P.Wildcard{name}], values), wildcard_fill_nonempty(name, values), filled))
    case P.Wildcard{name} <> h <> rest values:
      Core.absurd({P.match_path(P.Pattern{P.Wildcard{name} <> h <> rest}, "/") == Some{values} : Maybe<&2, P.Params>}, none_some(values, matched))

def match_joined(+segs: List<&2, P.Segment>, +ps: P.Params, +xs: List<&2, String>,
    filled: {P.fill_segments(segs, ps) == Some{xs} : Maybe<&2, List<&2, String>>},
    clean: {Core.clean_segments(xs) == True{} : Bool},
    matched: {P.match_segments(segs, xs) == Some{ps} : Maybe<&2, P.Params>},
    nonempty: {Bool.not(List.is_empty(&2, P.Segment, segs)) == True{} : Bool}) ->
    {P.match_path(P.Pattern{segs}, "/" ++ String.join(xs, "/")) == Some{ps} : Maybe<&2, P.Params>}:
  match xs:
    case Nil{}:
      empty_match(segs, ps, filled, matched, nonempty)
    case +h <> +t:
      match_tail(segs, ps, String.join(h <> t, "/"), (
        %Equal.sym(List<&2, String>, P.path_segments(String.join(h <> t, "/")), h <> t, Core.split_join(t, h, clean)) : {P.match_segments(segs, _) == Some{ps} : Maybe<&2, P.Params>}
        matched
      ))

def path_roundtrip(+segs: List<&2, P.Segment>, +ps: P.Params,
    nonempty: {Bool.not(List.is_empty(&2, P.Segment, segs)) == True{} : Bool},
    success: Roundtrip(segs, ps)) ->
    &path: String -> {P.fill(P.Pattern{segs}, ps) == Some{path} : Maybe<&2, String>} & {P.match_path(P.Pattern{segs}, path) == Some{ps} : Maybe<&2, P.Params>}:
  (+xs, (+filled, (clean, matched))) = success
  ("/" ++ String.join(xs, "/"), ((
    %Equal.sym(Maybe<&2, List<&2, String>>, P.fill_segments(segs, ps), Some{xs}, filled) : {Maybe.bind(&2, List<&2, String>, String, _, ys => Some{"/" ++ String.join(ys, "/")}) == Some{"/" ++ String.join(xs, "/")} : Maybe<&2, String>}
    {==}
  ), match_joined(segs, ps, xs, filled, clean, matched, nonempty)))

law pattern_roundtrip:
  for +segs: List<&2, P.Segment>
  for +ps: P.Params
  for good: {Compile.pattern_good(P.Pattern{segs}) == True{} : Bool}
  for admitted: {P.admissible(P.Pattern{segs}, ps) == True{} : Bool}
  exs path: String
  {P.fill(P.Pattern{segs}, ps) == Some{path} : Maybe<&2, String>} & {P.match_path(P.Pattern{segs}, path) == Some{ps} : Maybe<&2, P.Params>}

def pattern_roundtrip(segs, ps, good, admitted):
  +yes = Core.and_left(((Compile.segments_clean(segs) && Compile.segments_shape(segs)) && Bool.not(List.is_empty(&2, P.Segment, segs))), P.spans_ok(segs), good)
  +both = Core.and_left(Compile.segments_clean(segs) && Compile.segments_shape(segs), Bool.not(List.is_empty(&2, P.Segment, segs)), yes)
  path_roundtrip(segs, ps, Core.and_right(Compile.segments_clean(segs) && Compile.segments_shape(segs), Bool.not(List.is_empty(&2, P.Segment, segs)), yes), match_fill_segments(segs, ps, Core.and_left(Compile.segments_clean(segs), Compile.segments_shape(segs), both), admitted))
