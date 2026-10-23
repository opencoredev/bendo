# Compilation preserves the slash-free static text supplied by source splitting.
import Base
import ./pattern.bend as P
import ./constraint.bend as C
import ./encoding.bend as E
import ./proofs.bend as Core

def segment_clean(s: P.Segment) -> Bool:
  match s:
    case P.Static{raw}:
      Core.no_slash(raw)
    case _:
      True{}

def segment_result_clean(r: Result<&2, &2, P.PatternError, P.Segment>) -> Bool:
  match r:
    case Done{s}:
      segment_clean(s)
    case Fail{e}:
      True{}

def choose_segment_clean(+test: Bool,
    yes: Unit -> Result<&2, &2, P.PatternError, P.Segment>,
    no: Unit -> Result<&2, &2, P.PatternError, P.Segment>,
    py: {segment_result_clean(yes(Unit{})) == True{} : Bool},
    pn: {segment_result_clean(no(Unit{})) == True{} : Bool}) ->
    {segment_result_clean(E.choose(Result<&2, &2, P.PatternError, P.Segment>, test, yes, no)) == True{} : Bool}:
  match test:
    case True{}:
      py
    case False{}:
      pn

def constraint_result_clean(r: Maybe<&2, C.Constraint>, +body: String, +name: String, +optional: Bool) ->
    {segment_result_clean(P.constraint_result(r, body, name, optional)) == True{} : Bool}:
  match r:
    case Some{c}:
      {==}
    case None{}:
      choose_segment_clean(String.starts_with(body, "["), u => Fail{P.PatternError{P.InvalidClass{}, body}}, u => Fail{P.PatternError{P.UnknownConstraint{}, body}}, {==}, {==})

def constrained_clean(+suffix: String, +name: String, +optional: Bool) ->
    {segment_result_clean(P.constrained(suffix, name, optional)) == True{} : Bool}:
  choose_segment_clean(String.starts_with(suffix, "{") && String.ends_with(suffix, "}"), u => (
    +body = String.take(String.drop(suffix, 1n), Nat.sub(String.length(suffix), 2n))
    P.constraint_result(C.compile(body), body, name, optional)
  ), u => Fail{P.PatternError{P.UnbalancedBraces{}, suffix}}, constraint_result_clean(C.compile(String.take(String.drop(suffix, 1n), Nat.sub(String.length(suffix), 2n))), String.take(String.drop(suffix, 1n), Nat.sub(String.length(suffix), 2n)), name, optional), {==})

def capture_suffix_clean(+suffix: String, +name: String) ->
    {segment_result_clean(P.capture_suffix(suffix, name)) == True{} : Bool}:
  choose_segment_clean(String.is_empty(suffix), u => Done{P.Capture{name, C.Any{}, False{}}}, u => (
    E.choose(Result<&2, &2, P.PatternError, P.Segment>, String.eq(suffix, "?"), u => Done{P.Capture{name, C.Any{}, True{}}}, u => (
      E.choose(Result<&2, &2, P.PatternError, P.Segment>, String.ends_with(suffix, "?"), u => P.constrained(String.take(suffix, Nat.sub(String.length(suffix), 1n)), name, True{}), u => P.constrained(suffix, name, False{}))
    ))
  ), {==}, choose_segment_clean(String.eq(suffix, "?"), u => Done{P.Capture{name, C.Any{}, True{}}}, u => (
    E.choose(Result<&2, &2, P.PatternError, P.Segment>, String.ends_with(suffix, "?"), u => P.constrained(String.take(suffix, Nat.sub(String.length(suffix), 1n)), name, True{}), u => P.constrained(suffix, name, False{}))
  ), {==}, choose_segment_clean(String.ends_with(suffix, "?"), u => P.constrained(String.take(suffix, Nat.sub(String.length(suffix), 1n)), name, True{}), u => P.constrained(suffix, name, False{}), constrained_clean(String.take(suffix, Nat.sub(String.length(suffix), 1n)), name, True{}), constrained_clean(suffix, name, False{}))))

def capture_clean(pair: C.Split) -> {segment_result_clean(P.capture(pair)) == True{} : Bool}:
  match pair:
    case C.Split{+name, +suffix}:
      choose_segment_clean(String.is_empty(name), u => Fail{P.PatternError{P.EmptyName{}, name}}, u => (
        E.choose(Result<&2, &2, P.PatternError, P.Segment>, P.name_ok(name), u => P.capture_suffix(suffix, name), u => Fail{P.PatternError{P.InvalidName{}, name}})
      ), {==}, choose_segment_clean(P.name_ok(name), u => P.capture_suffix(suffix, name), u => Fail{P.PatternError{P.InvalidName{}, name}}, capture_suffix_clean(suffix, name), {==}))

law compile_segment_clean:
  for +raw: String
  for clean: {Core.no_slash(raw) == True{} : Bool}
  {segment_result_clean(P.compile_segment(raw)) == True{} : Bool}

def compile_head_clean(+h: Char, +t: String, clean: {Core.no_slash(SCon{h, t}) == True{} : Bool}) ->
    {segment_result_clean(P.compile_head(h, t)) == True{} : Bool}:
  choose_segment_clean(Char.is_eq(h, ':'), u => P.capture(P.split_name(t)), u => (
    E.choose(Result<&2, &2, P.PatternError, P.Segment>, Char.is_eq(h, '*'), u => (
      E.choose(Result<&2, &2, P.PatternError, P.Segment>, String.is_empty(t), u => Done{P.Wildcard{"*"}}, u => (
        E.choose(Result<&2, &2, P.PatternError, P.Segment>, P.name_ok(t), u => Done{P.Wildcard{t}}, u => Fail{P.PatternError{P.InvalidName{}, t}})
      ))
    ), u => (
      E.choose(Result<&2, &2, P.PatternError, P.Segment>, P.static_ok(SCon{h, t}), u => Done{P.Static{SCon{h, t}}}, u => Fail{P.PatternError{P.InvalidStatic{}, SCon{h, t}}})
    ))
  ), capture_clean(P.split_name(t)), choose_segment_clean(Char.is_eq(h, '*'), u => (
    E.choose(Result<&2, &2, P.PatternError, P.Segment>, String.is_empty(t), u => Done{P.Wildcard{"*"}}, u => (
      E.choose(Result<&2, &2, P.PatternError, P.Segment>, P.name_ok(t), u => Done{P.Wildcard{t}}, u => Fail{P.PatternError{P.InvalidName{}, t}})
    ))
  ), u => (
    E.choose(Result<&2, &2, P.PatternError, P.Segment>, P.static_ok(SCon{h, t}), u => Done{P.Static{SCon{h, t}}}, u => Fail{P.PatternError{P.InvalidStatic{}, SCon{h, t}}})
  ), choose_segment_clean(String.is_empty(t), u => Done{P.Wildcard{"*"}}, u => (
    E.choose(Result<&2, &2, P.PatternError, P.Segment>, P.name_ok(t), u => Done{P.Wildcard{t}}, u => Fail{P.PatternError{P.InvalidName{}, t}})
  ), {==}, choose_segment_clean(P.name_ok(t), u => Done{P.Wildcard{t}}, u => Fail{P.PatternError{P.InvalidName{}, t}}, {==}, {==})), choose_segment_clean(P.static_ok(SCon{h, t}), u => Done{P.Static{SCon{h, t}}}, u => Fail{P.PatternError{P.InvalidStatic{}, SCon{h, t}}}, clean, {==})))

def compile_segment_clean(raw, clean):
  match raw:
    case SNil{}:
      {==}
    case SCon{+h, +t}:
      compile_head_clean(h, t, clean)

def segments_clean(xs: List<&2, P.Segment>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case h <> t:
      segment_clean(h) && segments_clean(t)

def same_bool(a: Bool, b: Bool) -> Bool:
  match b:
    case True{}:
      a
    case False{}:
      Bool.not(a)

def result_good(r: Result<&2, &2, P.PatternError, List<&2, P.Segment>>, empty: Bool) -> Bool:
  match r:
    case Fail{e}:
      True{}
    case Done{+ys}:
      segments_clean(ys) && same_bool(List.is_empty(&2, P.Segment, ys), empty)

def choose_list_good(+test: Bool, +empty: Bool,
    yes: Unit -> Result<&2, &2, P.PatternError, List<&2, P.Segment>>,
    no: Unit -> Result<&2, &2, P.PatternError, List<&2, P.Segment>>,
    py: {result_good(yes(Unit{}), empty) == True{} : Bool},
    pn: {result_good(no(Unit{}), empty) == True{} : Bool}) ->
    {result_good(E.choose(Result<&2, &2, P.PatternError, List<&2, P.Segment>>, test, yes, no), empty) == True{} : Bool}:
  match test:
    case True{}:
      py
    case False{}:
      pn

def attach_good(+seg: P.Segment, r: Result<&2, &2, P.PatternError, List<&2, P.Segment>>, +empty: Bool,
    first: {segment_clean(seg) == True{} : Bool},
    rest: {result_good(r, empty) == True{} : Bool}) ->
    {result_good(Result.bind(&2, &2, P.PatternError, List<&2, P.Segment>, List<&2, P.Segment>, r, ys => Done{seg <> ys}), False{}) == True{} : Bool}:
  match r:
    case Fail{e}:
      {==}
    case Done{+ys}:
      %Equal.sym(Bool, segment_clean(seg), True{}, first) : {(_ && segments_clean(ys)) && True{} == True{} : Bool}
      %Equal.sym(Bool, segments_clean(ys), True{}, Core.and_left(segments_clean(ys), same_bool(List.is_empty(&2, P.Segment, ys), empty), rest)) : {(_ && True{}) == True{} : Bool}
      {==}

def compile_tail(+seg: P.Segment, +raw: String, +rest: List<&2, String>, +names: List<&2, String>) -> Result<&2, &2, P.PatternError, List<&2, P.Segment>>:
  E.choose(Result<&2, &2, P.PatternError, List<&2, P.Segment>>, P.duplicate(P.segment_name(seg), names), u => (
    Fail{P.PatternError{P.DuplicateName{}, raw}}
  ), u => (
    E.choose(Result<&2, &2, P.PatternError, List<&2, P.Segment>>, P.terminal(seg) && Bool.not(List.is_empty(&2, String, rest)), u => (
      Fail{P.PatternError{P.terminal_error(seg), raw}}
    ), u => (
      Result.bind(&2, &2, P.PatternError, List<&2, P.Segment>, List<&2, P.Segment>, P.compile_segments(rest, P.add_name(P.segment_name(seg), names)), ys => Done{seg <> ys})
    ))
  ))

def compile_tail_good(+seg: P.Segment, +raw: String, +rest: List<&2, String>, +names: List<&2, String>,
    first: {segment_clean(seg) == True{} : Bool},
    tail: {result_good(P.compile_segments(rest, P.add_name(P.segment_name(seg), names)), List.is_empty(&2, String, rest)) == True{} : Bool}) ->
    {result_good(compile_tail(seg, raw, rest, names), False{}) == True{} : Bool}:
  choose_list_good(P.duplicate(P.segment_name(seg), names), False{}, u => Fail{P.PatternError{P.DuplicateName{}, raw}}, u => (
    E.choose(Result<&2, &2, P.PatternError, List<&2, P.Segment>>, P.terminal(seg) && Bool.not(List.is_empty(&2, String, rest)), u => Fail{P.PatternError{P.terminal_error(seg), raw}}, u => (
      Result.bind(&2, &2, P.PatternError, List<&2, P.Segment>, List<&2, P.Segment>, P.compile_segments(rest, P.add_name(P.segment_name(seg), names)), ys => Done{seg <> ys})
    ))
  ), {==}, choose_list_good(P.terminal(seg) && Bool.not(List.is_empty(&2, String, rest)), False{}, u => Fail{P.PatternError{P.terminal_error(seg), raw}}, u => (
    Result.bind(&2, &2, P.PatternError, List<&2, P.Segment>, List<&2, P.Segment>, P.compile_segments(rest, P.add_name(P.segment_name(seg), names)), ys => Done{seg <> ys})
  ), {==}, attach_good(seg, P.compile_segments(rest, P.add_name(P.segment_name(seg), names)), List.is_empty(&2, String, rest), first, tail)))

def segment_bind_good(+raw: String, +rest: List<&2, String>, +names: List<&2, String>,
    r: Result<&2, &2, P.PatternError, P.Segment>,
    first: {segment_result_clean(r) == True{} : Bool},
    tail: @seg: P.Segment -> {result_good(P.compile_segments(rest, P.add_name(P.segment_name(seg), names)), List.is_empty(&2, String, rest)) == True{} : Bool}) ->
    {result_good(Result.bind(&2, &2, P.PatternError, P.Segment, List<&2, P.Segment>, r, seg => compile_tail(seg, raw, rest, names)), False{}) == True{} : Bool}:
  match r:
    case Fail{e}:
      {==}
    case Done{+seg}:
      compile_tail_good(seg, raw, rest, names, first, tail(seg))

law compile_segments_good:
  for +xs: List<&2, String>
  for +names: List<&2, String>
  for clean: {Core.clean_segments(xs) == True{} : Bool}
  {result_good(P.compile_segments(xs, names), List.is_empty(&2, String, xs)) == True{} : Bool}

def compile_segments_good(xs, names, clean):
  match xs:
    case Nil{}:
      {==}
    case +raw <> +rest:
      +yes = clean
      first = Core.and_left(Core.no_slash(raw), Core.clean_segments(rest), yes)
      tail = Core.and_right(Core.no_slash(raw), Core.clean_segments(rest), yes)
      segment_bind_good(raw, rest, names, P.compile_segment(raw), compile_segment_clean(raw, first), +seg => compile_segments_good(rest, P.add_name(P.segment_name(seg), names), tail))

def split_push_nonempty(+h: Char, xs: List<&2, String>) ->
    {List.is_empty(&2, String, String.split.push(h, xs)) == False{} : Bool}:
  match xs:
    case Nil{}:
      {==}
    case s <> ss:
      {==}

def split_fin_nonempty(+h: Char, +xs: List<&2, String>, cut: Bool) ->
    {List.is_empty(&2, String, String.split.fin(h, xs, cut)) == False{} : Bool}:
  match cut:
    case True{}:
      {==}
    case False{}:
      split_push_nonempty(h, xs)

law split_nonempty:
  for +s: String
  {List.is_empty(&2, String, P.path_segments(s)) == False{} : Bool}

def split_nonempty(s):
  match s:
    case SNil{}:
      {==}
    case SCon{+h, +t}:
      split_fin_nonempty(h, P.path_segments(t), Char.is_eq(h, '/'))

def pattern_good(p: P.Pattern) -> Bool:
  match p:
    case P.Pattern{+segs}:
      segments_clean(segs) && Bool.not(List.is_empty(&2, P.Segment, segs))

def pattern_result_good(r: Result<&2, &2, P.PatternError, P.Pattern>) -> Bool:
  match r:
    case Fail{e}:
      True{}
    case Done{p}:
      pattern_good(p)

def wrap_good(r: Result<&2, &2, P.PatternError, List<&2, P.Segment>>,
    good: {result_good(r, False{}) == True{} : Bool}) ->
    {pattern_result_good(Result.bind(&2, &2, P.PatternError, List<&2, P.Segment>, P.Pattern, r, xs => Done{P.Pattern{xs}})) == True{} : Bool}:
  match r:
    case Fail{e}:
      {==}
    case Done{xs}:
      good

def compile_body_good(+t: String) -> {pattern_result_good(P.compile_body(t)) == True{} : Bool}:
  wrap_good(P.compile_segments(P.path_segments(t), Nil{}), (
    %split_nonempty(t) : {result_good(P.compile_segments(P.path_segments(t), Nil{}), _) == True{} : Bool}
    compile_segments_good(P.path_segments(t), Nil{}, Core.clean_split(t))
  ))

def compile_head_good(+h: Char, +t: String, slash: Bool) ->
    {pattern_result_good(E.choose(Result<&2, &2, P.PatternError, P.Pattern>, slash, u => P.compile_body(t), u => Fail{P.PatternError{P.MissingSlash{}, SCon{h, t}}})) == True{} : Bool}:
  match slash:
    case True{}:
      compile_body_good(t)
    case False{}:
      {==}

law compile_good:
  for +source: String
  {pattern_result_good(P.compile(source)) == True{} : Bool}

def compile_good(source):
  match source:
    case SNil{}:
      {==}
    case SCon{+h, +t}:
      compile_head_good(h, t, Char.is_eq(h, '/'))

law compiled_pattern_good:
  for +source: String
  for +pattern: P.Pattern
  for compiled: {P.compile(source) == Done{pattern} : Result<&2, &2, P.PatternError, P.Pattern>}
  {pattern_good(pattern) == True{} : Bool}

def compiled_pattern_good(source, pattern, compiled):
  %compiled : {pattern_result_good(_) == True{} : Bool}
  compile_good(source)
