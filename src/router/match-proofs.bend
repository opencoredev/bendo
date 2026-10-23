# Matching the filler output, before joining it into an HTTP path.
import Base
import ./pattern.bend as P
import ./encoding.bend as E
import ./constraint.bend as C
import ./proofs.bend as Core
import ./compile-proofs.bend as Compile
import ./utf8-proofs.bend as Codec
import ./equality-proofs.bend as Eq

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

def span_step(+name: String, +rest: List<&2, P.Segment>, +key: String, +value: String, +tail: P.Params,
    +same: {String.eq(name, key) == True{} : Bool},
    +valid: {P.value_ok(C.Any{}, value) == True{} : Bool},
    success: Roundtrip(rest, tail)) -> Roundtrip(P.Span{name} <> rest, P.Param{key, value} <> tail):
  (+xs, (filled, (clean, matched))) = success
  +unicode = Core.and_right(Bool.not(String.is_empty(value)), E.scalars(value), Core.and_left(Bool.not(String.is_empty(value)) && E.scalars(value), C.accepts(C.Any{}, value), valid))
  (E.encode(value) <> xs, ((
    %Equal.sym(Bool, String.eq(name, key) && P.value_ok(C.Any{}, value), True{}, Codec.and_true(String.eq(name, key), P.value_ok(C.Any{}, value), same, valid)) : {E.choose(Maybe<&2, List<&2, String>>, _, u => Maybe.bind(&2, List<&2, String>, List<&2, String>, P.fill_segments(rest, tail), ys => Some{E.encode(value) <> ys}), u => None{}) == Some{E.encode(value) <> xs} : Maybe<&2, List<&2, String>>}
    %Equal.sym(Maybe<&2, List<&2, String>>, P.fill_segments(rest, tail), Some{xs}, filled) : {Maybe.bind(&2, List<&2, String>, List<&2, String>, _, ys => Some{E.encode(value) <> ys}) == Some{E.encode(value) <> xs} : Maybe<&2, List<&2, String>>}
    {==}
  ), ((
    %Equal.sym(Bool, Core.no_slash(E.encode(value)), True{}, Core.encode_no_slash(value, unicode)) : {_ && Core.clean_segments(xs) == True{} : Bool}
    clean
  ), (
    %Equal.sym(Maybe<&2, P.Params>, P.search_segments(P.Span{name} <> rest, E.encode(value) <> xs), P.row_one(~String.eq, ~String.starts_with, P.Span{name}, List.is_empty(&2, P.Segment, rest), E.encode(value) <> xs, P.match_rows(~String.eq, ~String.starts_with, rest, E.encode(value) <> xs)), Core.rows_head(P.Span{name}, rest, E.encode(value) <> xs)) : {_ == Some{P.Param{key, value} <> tail} : Maybe<&2, P.Params>}
    %Equal.sym(Core.Rows, P.match_rows(~String.eq, ~String.starts_with, rest, E.encode(value) <> xs), P.search_segments(rest, E.encode(value) <> xs) <> P.match_rows(~String.eq, ~String.starts_with, rest, xs), Core.rows_cons(rest, E.encode(value), xs)) : {P.span_options(E.encode(value) <> xs, _, name, Nil{}) == Some{P.Param{key, value} <> tail} : Maybe<&2, P.Params>}
    %Equal.sym(Maybe<&2, P.Params>, P.search_segments(rest, xs), Some{tail}, Equal.trans(Maybe<&2, P.Params>, P.search_segments(rest, xs), P.match_segments(rest, xs), Some{tail}, Core.search_equal(rest, xs), matched)) : {P.prefer(P.span_result(name, E.encode(value), _), u => P.span_options(xs, P.match_rows(~String.eq, ~String.starts_with, rest, xs), name, [E.encode(value)])) == Some{P.Param{key, value} <> tail} : Maybe<&2, P.Params>}
    %Equal.sym(Maybe<&2, String>, E.decode(E.encode(value)), Some{value}, Codec.codec_roundtrip(value, unicode)) : {P.prefer(Maybe.bind(&2, String, P.Params, _, +v => E.choose(Maybe<&2, P.Params>, P.value_ok(C.Any{}, v), u => P.put_capture(name, v, Some{tail}), u => None{})), u => P.span_options(xs, P.match_rows(~String.eq, ~String.starts_with, rest, xs), name, [E.encode(value)])) == Some{P.Param{key, value} <> tail} : Maybe<&2, P.Params>}
    %Equal.sym(Bool, P.value_ok(C.Any{}, value), True{}, valid) : {P.prefer(E.choose(Maybe<&2, P.Params>, _, u => P.put_capture(name, value, Some{tail}), u => None{}), u => P.span_options(xs, P.match_rows(~String.eq, ~String.starts_with, rest, xs), name, [E.encode(value)])) == Some{P.Param{key, value} <> tail} : Maybe<&2, P.Params>}
    Equal.cong(String, Maybe<&2, P.Params>, n => Some{P.Param{n, value} <> tail}, name, key, Eq.string_eq_sound(name, key, same))
  ))))

def optional_filled(+segs: List<&2, P.Segment>, yes: {P.all_optional(segs) == True{} : Bool}) ->
    {P.fill_segments(segs, Nil{}) == Some{Nil{}} : Maybe<&2, List<&2, String>>}:
  match segs:
    case Nil{}:
      {==}
    case P.Capture{name, c, True{}} <> +rest:
      optional_filled(rest, yes)
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

law match_fill_segments:
  for +segs: List<&2, P.Segment>
  for +ps: P.Params
  for clean: {Compile.segments_clean(segs) == True{} : Bool}
  for shape: {Compile.segments_shape(segs) == True{} : Bool}
  for admitted: {P.admissible_segments(segs, ps) == True{} : Bool}
  Roundtrip(segs, ps)

def match_fill_segments(segs, ps, clean, shape, admitted):
  match segs ps:
    case Nil{} Nil{}:
      (Nil{}, ({==}, ({==}, {==})))
    case P.Static{+raw} <> +rest +values:
      +yes = clean
      static_step(raw, rest, values, Core.and_left(Core.no_slash(raw), Compile.segments_clean(rest), yes), match_fill_segments(rest, values, Core.and_right(Core.no_slash(raw), Compile.segments_clean(rest), yes), Core.and_right(P.optional_tail_ok(P.Static{raw}, rest), Compile.segments_shape(rest), shape), admitted))
    case P.Capture{+name, +c, True{}} <> +rest Nil{}:
      +yes = Core.and_left(P.all_optional(rest), Compile.segments_shape(rest), shape)
      (Nil{}, (optional_filled(P.Capture{name, c, True{}} <> rest, yes), ({==}, optional_matched(P.Capture{name, c, True{}} <> rest, yes))))
    case P.InteriorWildcard{} <> +rest +values:
      interior_step(rest, values, match_fill_segments(rest, values, clean, Core.and_right(True{}, Compile.segments_shape(rest), shape), admitted))
    case P.PrefixWildcard{+prefix} <> Nil{} Nil{}:
      prefix_step(prefix, Core.and_left(Core.no_slash(prefix), True{}, clean))
    case P.Span{+name} <> +rest P.Param{+key, +value} <> +tail:
      +yes = admitted
      +ok = Core.and_left(String.eq(name, key) && P.value_ok(C.Any{}, value), P.admissible_segments(rest, tail), yes)
      span_step(name, rest, key, value, tail, Core.and_left(String.eq(name, key), P.value_ok(C.Any{}, value), ok), Core.and_right(String.eq(name, key), P.value_ok(C.Any{}, value), ok), match_fill_segments(rest, tail, clean, Core.and_right(True{}, Compile.segments_shape(rest), shape), Core.and_right(String.eq(name, key) && P.value_ok(C.Any{}, value), P.admissible_segments(rest, tail), yes)))
    case P.Capture{+name, +c, +optional} <> +rest P.Param{+key, +value} <> +tail:
      +yes = admitted
      +ok = Core.and_left(String.eq(name, key) && P.value_ok(c, value), P.admissible_segments(rest, tail), yes)
      capture_step(name, c, optional, rest, key, value, tail, Core.and_left(String.eq(name, key), P.value_ok(c, value), ok), Core.and_right(String.eq(name, key), P.value_ok(c, value), ok), match_fill_segments(rest, tail, Core.and_right(True{}, Compile.segments_clean(rest), clean), Core.and_right(P.optional_tail_ok(P.Capture{name, c, optional}, rest), Compile.segments_shape(rest), shape), Core.and_right(String.eq(name, key) && P.value_ok(c, value), P.admissible_segments(rest, tail), yes)))
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
        %Equal.sym(Maybe<&2, String>, E.decode(E.encode(value)), Some{value}, Codec.codec_roundtrip(value, unicode)) : {Maybe.bind(&2, String, P.Params, _, v => Some{[P.Param{name, v}]}) == Some{[P.Param{key, value}]} : Maybe<&2, P.Params>}
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

def optional_empty_rows(+name: String, +c: C.Constraint, +rest: List<&2, P.Segment>,
    yes: {P.all_optional(rest) == True{} : Bool}) ->
    {P.first_result(P.match_rows(~String.eq, ~String.starts_with, P.Capture{name, c, True{}} <> rest, [""])) == Some{Nil{}} : Maybe<&2, P.Params>}:
  %Equal.sym(Core.Rows, P.match_rows(~String.eq, ~String.starts_with, rest, [""]), P.search_segments(rest, [""]) <> P.match_rows(~String.eq, ~String.starts_with, rest, Nil{}), Core.rows_cons(rest, "", Nil{})) : {P.first_result(P.rows_for(~String.eq, ~String.starts_with, P.Capture{name, c, True{}}, List.is_empty(&2, P.Segment, rest), [""], _)) == Some{Nil{}} : Maybe<&2, P.Params>}
  %Equal.sym(Maybe<&2, P.Params>, P.search_segments(rest, Nil{}), Some{Nil{}}, Equal.trans(Maybe<&2, P.Params>, P.search_segments(rest, Nil{}), P.match_segments(rest, Nil{}), Some{Nil{}}, Core.search_equal(rest, Nil{}), optional_matched(rest, yes))) : {P.first_result([_]) == Some{Nil{}} : Maybe<&2, P.Params>}
  {==}

def interior_empty_rows(+rest: List<&2, P.Segment>, +ps: P.Params,
    first: {P.first_result(P.match_rows(~String.eq, ~String.starts_with, rest, [""])) == Some{ps} : Maybe<&2, P.Params>}) ->
    {P.first_result(P.match_rows(~String.eq, ~String.starts_with, P.InteriorWildcard{} <> rest, [""])) == Some{ps} : Maybe<&2, P.Params>}:
  Core.first_head(P.match_rows(~String.eq, ~String.starts_with, P.InteriorWildcard{} <> rest, [""]), ps, (
    %Equal.sym(Maybe<&2, P.Params>, P.search_segments(P.InteriorWildcard{} <> rest, [""]), P.row_one(~String.eq, ~String.starts_with, P.InteriorWildcard{}, List.is_empty(&2, P.Segment, rest), [""], P.match_rows(~String.eq, ~String.starts_with, rest, [""])), Core.rows_head(P.InteriorWildcard{}, rest, [""])) : {_ == Some{ps} : Maybe<&2, P.Params>}
    first
  ))

def empty_row_match(+segs: List<&2, P.Segment>, +ps: P.Params,
    shape: {Compile.segments_shape(segs) == True{} : Bool},
    filled: {P.fill_segments(segs, ps) == Some{Nil{}} : Maybe<&2, List<&2, String>>}) ->
    {P.first_result(P.match_rows(~String.eq, ~String.starts_with, segs, [""])) == Some{ps} : Maybe<&2, P.Params>}:
  match segs ps:
    case Nil{} Nil{}:
      {==}
    case P.Capture{+name, +c, True{}} <> +rest Nil{}:
      optional_empty_rows(name, c, rest, Core.and_left(P.all_optional(rest), Compile.segments_shape(rest), shape))
    case P.InteriorWildcard{} <> +rest +values:
      interior_empty_rows(rest, values, empty_row_match(rest, values, Core.and_right(True{}, Compile.segments_shape(rest), shape), filled))
    case Nil{} +h <> +t:
      Core.absurd({P.first_result(P.match_rows(~String.eq, ~String.starts_with, Nil{}, [""])) == Some{h <> t} : Maybe<&2, P.Params>}, filled_impossible(P.fill_segments(Nil{}, h <> t), {==}, filled))
    case P.Static{+raw} <> +rest +values:
      Core.absurd({P.first_result(P.match_rows(~String.eq, ~String.starts_with, P.Static{raw} <> rest, [""])) == Some{values} : Maybe<&2, P.Params>}, filled_impossible(P.fill_segments(P.Static{raw} <> rest, values), bind_nonempty(raw, P.fill_segments(rest, values)), filled))
    case P.Capture{+name, +c, False{}} <> +rest Nil{}:
      Core.absurd({P.first_result(P.match_rows(~String.eq, ~String.starts_with, P.Capture{name, c, False{}} <> rest, [""])) == Some{Nil{}} : Maybe<&2, P.Params>}, filled_impossible(P.fill_segments(P.Capture{name, c, False{}} <> rest, Nil{}), {==}, filled))
    case P.Capture{+name, +c, +optional} <> +rest P.Param{+key, +value} <> +tail:
      Core.absurd({P.first_result(P.match_rows(~String.eq, ~String.starts_with, P.Capture{name, c, optional} <> rest, [""])) == Some{P.Param{key, value} <> tail} : Maybe<&2, P.Params>}, filled_impossible(P.fill_segments(P.Capture{name, c, optional} <> rest, P.Param{key, value} <> tail), capture_nonempty(name, c, optional, rest, key, value, tail), filled))
    case P.PrefixWildcard{+prefix} <> Nil{} Nil{}:
      Core.absurd({P.first_result(P.match_rows(~String.eq, ~String.starts_with, [P.PrefixWildcard{prefix}], [""])) == Some{Nil{}} : Maybe<&2, P.Params>}, filled_impossible(P.fill_segments([P.PrefixWildcard{prefix}], Nil{}), {==}, filled))
    case P.PrefixWildcard{+prefix} <> Nil{} +h <> +t:
      Core.absurd({P.first_result(P.match_rows(~String.eq, ~String.starts_with, [P.PrefixWildcard{prefix}], [""])) == Some{h <> t} : Maybe<&2, P.Params>}, filled_impossible(P.fill_segments([P.PrefixWildcard{prefix}], h <> t), {==}, filled))
    case P.PrefixWildcard{+prefix} <> +h <> +t +values:
      Core.absurd({P.first_result(P.match_rows(~String.eq, ~String.starts_with, P.PrefixWildcard{prefix} <> h <> t, [""])) == Some{values} : Maybe<&2, P.Params>}, filled_impossible(P.fill_segments(P.PrefixWildcard{prefix} <> h <> t, values), {==}, filled))
    case P.Span{+name} <> +rest Nil{}:
      Core.absurd({P.first_result(P.match_rows(~String.eq, ~String.starts_with, P.Span{name} <> rest, [""])) == Some{Nil{}} : Maybe<&2, P.Params>}, filled_impossible(P.fill_segments(P.Span{name} <> rest, Nil{}), {==}, filled))
    case P.Span{+name} <> +rest P.Param{+key, +value} <> +tail:
      Core.absurd({P.first_result(P.match_rows(~String.eq, ~String.starts_with, P.Span{name} <> rest, [""])) == Some{P.Param{key, value} <> tail} : Maybe<&2, P.Params>}, filled_impossible(P.fill_segments(P.Span{name} <> rest, P.Param{key, value} <> tail), guard_bind_nonempty(E.encode(value), P.fill_segments(rest, tail), String.eq(name, key) && P.value_ok(C.Any{}, value)), filled))
    case P.Wildcard{+name} <> Nil{} +values:
      Core.absurd({P.first_result(P.match_rows(~String.eq, ~String.starts_with, [P.Wildcard{name}], [""])) == Some{values} : Maybe<&2, P.Params>}, filled_impossible(P.fill_segments([P.Wildcard{name}], values), wildcard_fill_nonempty(name, values), filled))
    case P.Wildcard{+name} <> +h <> +t +values:
      Core.absurd({P.first_result(P.match_rows(~String.eq, ~String.starts_with, P.Wildcard{name} <> h <> t, [""])) == Some{values} : Maybe<&2, P.Params>}, filled_impossible(P.fill_segments(P.Wildcard{name} <> h <> t, values), {==}, filled))

def empty_match(+segs: List<&2, P.Segment>, +ps: P.Params,
    filled: {P.fill_segments(segs, ps) == Some{Nil{}} : Maybe<&2, List<&2, String>>},
    matched: {P.match_segments(segs, Nil{}) == Some{ps} : Maybe<&2, P.Params>},
    +shape: {Compile.segments_shape(segs) == True{} : Bool},
    nonempty: {Bool.not(List.is_empty(&2, P.Segment, segs)) == True{} : Bool}) ->
    {P.match_path(P.Pattern{segs}, "/") == Some{ps} : Maybe<&2, P.Params>}:
  match segs:
    case Nil{}:
      Core.absurd({P.match_path(P.Pattern{Nil{}}, "/") == Some{ps} : Maybe<&2, P.Params>}, Core.false_true(nonempty))
    case P.Capture{+name, +c, True{}} <> +rest:
      %Equal.sym(Bool, P.all_optional(rest), True{}, Core.and_left(P.all_optional(rest), Compile.segments_shape(rest), shape)) : {E.choose(Maybe<&2, P.Params>, _, u => Some{Nil{}}, u => P.match_segments(P.Capture{name, c, True{}} <> rest, [""])) == Some{ps} : Maybe<&2, P.Params>}
      Equal.trans(Maybe<&2, P.Params>, Some{Nil{}}, P.match_segments(rest, Nil{}), Some{ps}, Equal.sym(Maybe<&2, P.Params>, P.match_segments(rest, Nil{}), Some{Nil{}}, optional_matched(rest, Core.and_left(P.all_optional(rest), Compile.segments_shape(rest), shape))), matched)
    case P.InteriorWildcard{} <> +rest:
      %Equal.sym(Maybe<&2, P.Params>, P.search_segments(P.InteriorWildcard{} <> rest, [""]), P.row_one(~String.eq, ~String.starts_with, P.InteriorWildcard{}, List.is_empty(&2, P.Segment, rest), [""], P.match_rows(~String.eq, ~String.starts_with, rest, [""])), Core.rows_head(P.InteriorWildcard{}, rest, [""])) : {_ == Some{ps} : Maybe<&2, P.Params>}
      empty_row_match(rest, ps, Core.and_right(True{}, Compile.segments_shape(rest), shape), filled)
    case P.Static{raw} <> rest:
      Core.absurd({P.match_path(P.Pattern{P.Static{raw} <> rest}, "/") == Some{ps} : Maybe<&2, P.Params>}, none_some(ps, matched))
    case P.Capture{name, c, False{}} <> rest:
      Core.absurd({P.match_path(P.Pattern{P.Capture{name, c, False{}} <> rest}, "/") == Some{ps} : Maybe<&2, P.Params>}, none_some(ps, matched))
    case P.PrefixWildcard{prefix} <> rest:
      Core.absurd({P.match_path(P.Pattern{P.PrefixWildcard{prefix} <> rest}, "/") == Some{ps} : Maybe<&2, P.Params>}, none_some(ps, matched))
    case P.Span{name} <> rest:
      Core.absurd({P.match_path(P.Pattern{P.Span{name} <> rest}, "/") == Some{ps} : Maybe<&2, P.Params>}, none_some(ps, matched))
    case P.Wildcard{+name} <> Nil{}:
      Core.absurd({P.match_path(P.Pattern{[P.Wildcard{name}]}, "/") == Some{ps} : Maybe<&2, P.Params>}, filled_impossible(P.fill_segments([P.Wildcard{name}], ps), wildcard_fill_nonempty(name, ps), filled))
    case P.Wildcard{name} <> h <> rest:
      Core.absurd({P.match_path(P.Pattern{P.Wildcard{name} <> h <> rest}, "/") == Some{ps} : Maybe<&2, P.Params>}, none_some(ps, matched))

def match_joined(+segs: List<&2, P.Segment>, +ps: P.Params, +xs: List<&2, String>,
    filled: {P.fill_segments(segs, ps) == Some{xs} : Maybe<&2, List<&2, String>>},
    clean: {Core.clean_segments(xs) == True{} : Bool},
    matched: {P.match_segments(segs, xs) == Some{ps} : Maybe<&2, P.Params>},
    +shape: {Compile.segments_shape(segs) == True{} : Bool},
    nonempty: {Bool.not(List.is_empty(&2, P.Segment, segs)) == True{} : Bool}) ->
    {P.match_path(P.Pattern{segs}, "/" ++ String.join(xs, "/")) == Some{ps} : Maybe<&2, P.Params>}:
  match xs:
    case Nil{}:
      empty_match(segs, ps, filled, matched, shape, nonempty)
    case +h <> +t:
      match_tail(segs, ps, String.join(h <> t, "/"), (
        %Equal.sym(List<&2, String>, P.path_segments(String.join(h <> t, "/")), h <> t, Core.split_join(t, h, clean)) : {P.match_segments(segs, _) == Some{ps} : Maybe<&2, P.Params>}
        matched
      ))

def path_roundtrip(+segs: List<&2, P.Segment>, +ps: P.Params,
    +shape: {Compile.segments_shape(segs) == True{} : Bool},
    nonempty: {Bool.not(List.is_empty(&2, P.Segment, segs)) == True{} : Bool},
    success: Roundtrip(segs, ps)) ->
    &path: String -> {P.fill(P.Pattern{segs}, ps) == Some{path} : Maybe<&2, String>} & {P.match_path(P.Pattern{segs}, path) == Some{ps} : Maybe<&2, P.Params>}:
  (+xs, (+filled, (clean, matched))) = success
  ("/" ++ String.join(xs, "/"), ((
    %Equal.sym(Maybe<&2, List<&2, String>>, P.fill_segments(segs, ps), Some{xs}, filled) : {Maybe.bind(&2, List<&2, String>, String, _, ys => Some{"/" ++ String.join(ys, "/")}) == Some{"/" ++ String.join(xs, "/")} : Maybe<&2, String>}
    {==}
  ), match_joined(segs, ps, xs, filled, clean, matched, shape, nonempty)))

law pattern_roundtrip:
  for +segs: List<&2, P.Segment>
  for +ps: P.Params
  for good: {Compile.pattern_good(P.Pattern{segs}) == True{} : Bool}
  for admitted: {P.admissible(P.Pattern{segs}, ps) == True{} : Bool}
  exs path: String
  {P.fill(P.Pattern{segs}, ps) == Some{path} : Maybe<&2, String>} & {P.match_path(P.Pattern{segs}, path) == Some{ps} : Maybe<&2, P.Params>}

def pattern_roundtrip(segs, ps, good, admitted):
  +yes = good
  +both = Core.and_left(Compile.segments_clean(segs) && Compile.segments_shape(segs), Bool.not(List.is_empty(&2, P.Segment, segs)), yes)
  path_roundtrip(segs, ps, Core.and_right(Compile.segments_clean(segs), Compile.segments_shape(segs), both), Core.and_right(Compile.segments_clean(segs) && Compile.segments_shape(segs), Bool.not(List.is_empty(&2, P.Segment, segs)), yes), match_fill_segments(segs, ps, Core.and_left(Compile.segments_clean(segs), Compile.segments_shape(segs), both), Core.and_right(Compile.segments_clean(segs), Compile.segments_shape(segs), both), admitted))
