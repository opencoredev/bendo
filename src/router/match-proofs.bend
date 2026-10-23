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
    case P.Capture{name, c, True{}} <> Nil{} Nil{}:
      (Nil{}, ({==}, ({==}, {==})))
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
        %Equal.sym(Maybe<&2, String>, E.decode(E.encode(value)), Some{value}, Codec.codec_roundtrip(value, unicode)) : {Maybe.bind(&2, String, P.Params, _, v => Some{[P.Param{name, v}]}) == Some{[P.Param{key, value}]} : Maybe<&2, P.Params>}
        Equal.cong(String, Maybe<&2, P.Params>, n => Some{[P.Param{n, value}]}, name, key, Eq.string_eq_sound(name, key, Core.and_left(String.eq(name, key), E.scalars(value), ok)))
      ))))
    case Nil{} h <> t:
      Core.absurd(Roundtrip(Nil{}, h <> t), Core.false_true(admitted))
    case P.Capture{name, c, False{}} <> rest Nil{}:
      Core.absurd(Roundtrip(P.Capture{name, c, False{}} <> rest, Nil{}), Core.false_true(admitted))
    case P.Capture{name, c, True{}} <> h <> t Nil{}:
      Core.absurd(Roundtrip(P.Capture{name, c, True{}} <> h <> t, Nil{}), Core.false_true(admitted))
    case P.Wildcard{name} <> Nil{} Nil{}:
      Core.absurd(Roundtrip([P.Wildcard{name}], Nil{}), Core.false_true(admitted))
    case P.Wildcard{name} <> Nil{} h <> j <> t:
      Core.absurd(Roundtrip([P.Wildcard{name}], h <> j <> t), Core.false_true(admitted))
    case P.Wildcard{name} <> h <> t values:
      Core.absurd(Roundtrip(P.Wildcard{name} <> h <> t, values), Core.false_true(admitted))

def params_some(r: Maybe<&2, P.Params>) -> Bool:
  match r:
    case None{}:
      False{}
    case Some{ps}:
      True{}

def none_some(+ps: P.Params, e: {None{} == Some{ps} : Maybe<&2, P.Params>}) -> Empty:
  Core.false_true(Equal.cong(Maybe<&2, P.Params>, Bool, r => params_some(r), None{}, Some{ps}, e))

# The sole optional capture has a separate root-path branch. With a nonempty
# split input its empty raw segment cannot be an admissible present capture.
def match_tail(+segs: List<&2, P.Segment>, +ps: P.Params, +tail: String,
    matched: {P.match_segments(segs, P.path_segments(tail)) == Some{ps} : Maybe<&2, P.Params>}) ->
    {P.match_path(P.Pattern{segs}, "/" ++ tail) == Some{ps} : Maybe<&2, P.Params>}:
  match segs tail:
    case P.Capture{name, c, True{}} <> Nil{} SNil{}:
      Core.absurd({Some{Nil{}} == Some{ps} : Maybe<&2, P.Params>}, none_some(ps, matched))
    case P.Capture{name, c, True{}} <> Nil{} SCon{h, t}:
      matched
    case P.Capture{name, c, False{}} <> rest t:
      matched
    case P.Capture{name, c, True{}} <> h <> rest t:
      matched
    case P.Static{raw} <> rest t:
      matched
    case P.Wildcard{name} <> rest t:
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

def empty_match(+segs: List<&2, P.Segment>, +ps: P.Params,
    filled: {P.fill_segments(segs, ps) == Some{Nil{}} : Maybe<&2, List<&2, String>>},
    matched: {P.match_segments(segs, Nil{}) == Some{ps} : Maybe<&2, P.Params>},
    nonempty: {Bool.not(List.is_empty(&2, P.Segment, segs)) == True{} : Bool}) ->
    {P.match_path(P.Pattern{segs}, "/") == Some{ps} : Maybe<&2, P.Params>}:
  match segs:
    case Nil{}:
      Core.absurd({P.match_path(P.Pattern{Nil{}}, "/") == Some{ps} : Maybe<&2, P.Params>}, Core.false_true(nonempty))
    case P.Capture{name, c, True{}} <> Nil{}:
      matched
    case P.Capture{name, c, False{}} <> rest:
      Core.absurd({P.match_path(P.Pattern{P.Capture{name, c, False{}} <> rest}, "/") == Some{ps} : Maybe<&2, P.Params>}, none_some(ps, matched))
    case P.Capture{name, c, True{}} <> h <> rest:
      Core.absurd({P.match_path(P.Pattern{P.Capture{name, c, True{}} <> h <> rest}, "/") == Some{ps} : Maybe<&2, P.Params>}, none_some(ps, matched))
    case P.Static{raw} <> rest:
      Core.absurd({P.match_path(P.Pattern{P.Static{raw} <> rest}, "/") == Some{ps} : Maybe<&2, P.Params>}, none_some(ps, matched))
    case P.Wildcard{+name} <> Nil{}:
      Core.absurd({P.match_path(P.Pattern{[P.Wildcard{name}]}, "/") == Some{ps} : Maybe<&2, P.Params>}, Core.false_true(Equal.trans(Bool, False{}, has_empty(P.fill_segments([P.Wildcard{name}], ps)), True{}, Equal.sym(Bool, has_empty(P.fill_segments([P.Wildcard{name}], ps)), False{}, wildcard_fill_nonempty(name, ps)), Equal.cong(Maybe<&2, List<&2, String>>, Bool, r => has_empty(r), P.fill_segments([P.Wildcard{name}], ps), Some{Nil{}}, filled))))
    case P.Wildcard{name} <> h <> rest:
      Core.absurd({P.match_path(P.Pattern{P.Wildcard{name} <> h <> rest}, "/") == Some{ps} : Maybe<&2, P.Params>}, none_some(ps, matched))

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
  +yes = good
  path_roundtrip(segs, ps, Core.and_right(Compile.segments_clean(segs), Bool.not(List.is_empty(&2, P.Segment, segs)), yes), match_fill_segments(segs, ps, Core.and_left(Compile.segments_clean(segs), Bool.not(List.is_empty(&2, P.Segment, segs)), yes), admitted))
