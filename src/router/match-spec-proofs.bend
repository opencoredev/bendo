# BND-78: the matcher returns exactly the independent raw-path specification.
import Base
import ./pattern.bend as P
import ./encoding.bend as E
import ./constraint.bend as C
import ./proofs.bend as Core
import ../../proof/router-match-spec.bend as S
import ./pattern-stack-proofs.bend as PS
import ../http/text-proofs.bend as TP

def prefer_or_else(a: Maybe<&2, P.Params>, +b: Maybe<&2, P.Params>) ->
    {P.prefer(a, u => b) == S.or_else(a, u => b) : Maybe<&2, P.Params>}:
  match a:
    case Some{ps}:
      {==}
    case None{}:
      {==}

def prefer_none(a: Maybe<&2, P.Params>) -> {P.prefer(a, u => None{}) == a : Maybe<&2, P.Params>}:
  match a:
    case Some{ps}:
      {==}
    case None{}:
      {==}

def or_else_none(a: Maybe<&2, P.Params>) -> {S.or_else(a, u => None{}) == a : Maybe<&2, P.Params>}:
  match a:
    case Some{ps}:
      {==}
    case None{}:
      {==}

def choose_same(b: Bool, +r: Maybe<&2, P.Params>) ->
    {E.choose(Maybe<&2, P.Params>, b, u => r, u => None{}) == S.same_text(b, r) : Maybe<&2, P.Params>}:
  match b:
    case True{}:
      {==}
    case False{}:
      {==}

def put_param(+name: String, +v: String, r: Maybe<&2, P.Params>) ->
    {P.put_capture(name, v, r) == S.with_param(name, v, r) : Maybe<&2, P.Params>}:
  match r:
    case None{}:
      {==}
    case Some{ps}:
      {==}

def keep_eq(+name: String, +v: String, +r: Maybe<&2, P.Params>, b: Bool) ->
    {E.choose(Maybe<&2, P.Params>, b, u => P.put_capture(name, v, r), u => None{}) == S.keep(b, name, v, r) : Maybe<&2, P.Params>}:
  match b:
    case True{}:
      put_param(name, v, r)
    case False{}:
      {==}

def capture_eq(+name: String, +c: C.Constraint, d: Maybe<&2, String>, +r: Maybe<&2, P.Params>) ->
    {Maybe.bind(&2, String, P.Params, d, +v => E.choose(Maybe<&2, P.Params>, P.value_ok(c, v), u => P.put_capture(name, v, r), u => None{})) == S.capture(name, c, d, r) : Maybe<&2, P.Params>}:
  match d:
    case None{}:
      {==}
    case Some{+v}:
      keep_eq(name, v, r, P.value_ok(c, v))

def joined(m: Maybe<&2, List<&2, String>>) -> Maybe<&2, String>:
  match m:
    case None{}:
      None{}
    case Some{vs}:
      Some{String.join(vs, "/")}

def join_last(dp: Maybe<&2, String>) ->
    {dp == joined(Maybe.bind(&2, String, List<&2, String>, dp, v => Some{[v]})) : Maybe<&2, String>}:
  match dp:
    case None{}:
      {==}
    case Some{a}:
      {==}

def join_more(+h: String, +t: List<&2, String>, dp: Maybe<&2, String>, dh: Maybe<&2, String>, mt: Maybe<&2, List<&2, String>>) ->
    {P.join_value(dp, h <> t, joined(Maybe.bind(&2, String, List<&2, String>, dh, w => Maybe.bind(&2, List<&2, String>, List<&2, String>, mt, ws => Some{w <> ws})))) == joined(Maybe.bind(&2, String, List<&2, String>, dp, v => Maybe.bind(&2, List<&2, String>, List<&2, String>, Maybe.bind(&2, String, List<&2, String>, dh, w => Maybe.bind(&2, List<&2, String>, List<&2, String>, mt, ws => Some{w <> ws})), vs => Some{v <> vs}))) : Maybe<&2, String>}:
  match dp dh mt:
    case None{} y z:
      {==}
    case Some{a} None{} z:
      {==}
    case Some{a} Some{w} None{}:
      {==}
    case Some{a} Some{w} Some{ws}:
      {==}

# Decoding a wildcard one segment at a time is the spec's decode-then-join.
def decode_spec_eq(+ps: List<&2, String>) -> {P.decode_segments_spec(ps) == joined(S.decoded_all(ps)) : Maybe<&2, String>}:
  match ps:
    case Nil{}:
      {==}
    case +p <> Nil{}:
      join_last(E.decode(p))
    case +p <> +h <> +t:
      %Equal.sym(Maybe<&2, String>, P.decode_segments_spec(h <> t), joined(S.decoded_all(h <> t)), decode_spec_eq(h <> t)) : {P.join_value(E.decode(p), h <> t, _) == joined(S.decoded_all(p <> h <> t)) : Maybe<&2, String>}
      join_more(h, t, E.decode(p), E.decode(h), S.decoded_all(t))

def decode_eq(+ps: List<&2, String>) -> {P.decode_segments(ps) == joined(S.decoded_all(ps)) : Maybe<&2, String>}:
  %PS.decode_segments_equiv(ps) : {_ == joined(S.decoded_all(ps)) : Maybe<&2, String>}
  decode_spec_eq(ps)

def wildcard_eq(+name: String, m: Maybe<&2, List<&2, String>>) ->
    {P.wildcard_param(name, joined(m)) == S.wildcard(name, m) : Maybe<&2, P.Params>}:
  match m:
    case None{}:
      {==}
    case Some{vs}:
      {==}

def hit_eq(b: Bool) -> {E.choose(Maybe<&2, P.Params>, b, u => Some{Nil{}}, u => None{}) == S.prefix_hit(b) : Maybe<&2, P.Params>}:
  match b:
    case True{}:
      {==}
    case False{}:
      {==}

def span_keep(+name: String, +v: String, +ps: P.Params, b: Bool) ->
    {E.choose(Maybe<&2, P.Params>, b, u => Some{P.Param{name, v} <> ps}, u => None{}) == S.keep(b, name, v, Some{ps}) : Maybe<&2, P.Params>}:
  match b:
    case True{}:
      {==}
    case False{}:
      {==}

def span_choice(+name: String, +ps: P.Params, d: Maybe<&2, String>) ->
    {Maybe.bind(&2, String, P.Params, d, +v => E.choose(Maybe<&2, P.Params>, P.value_ok(C.Any{}, v), u => Some{P.Param{name, v} <> ps}, u => None{})) == S.capture(name, C.Any{}, d, Some{ps}) : Maybe<&2, P.Params>}:
  match d:
    case None{}:
      {==}
    case Some{+v}:
      span_keep(name, v, ps, P.value_ok(C.Any{}, v))

def span_eq(+name: String, +taken: List<&2, String>, r: Maybe<&2, P.Params>) ->
    {P.span_value(name, taken, r) == S.span_here(name, taken, r) : Maybe<&2, P.Params>}:
  match r:
    case None{}:
      {==}
    case Some{+ps}:
      %PS.join_taken_equiv(taken) : {Maybe.bind(&2, String, P.Params, E.decode(_), +v => E.choose(Maybe<&2, P.Params>, P.value_ok(C.Any{}, v), u => Some{P.Param{name, v} <> ps}, u => None{})) == S.span_here(name, taken, Some{ps}) : Maybe<&2, P.Params>}
      span_choice(name, ps, E.decode(String.join(List.reverse(&2, String, taken), "/")))

# Span cells are scanned with the accumulated raw prefix; other heads match directly.
def lhs(+segs: List<&2, P.Segment>, +paths: List<&2, String>, +taken: List<&2, String>) -> Maybe<&2, P.Params>:
  match segs:
    case P.Span{name} <> rest:
      P.span_scan(paths, P.match_rows(~String.eq, ~String.starts_with, rest, paths), name, taken)
    case _:
      P.match_segments(segs, paths)

def lhs_nil(+segs: List<&2, P.Segment>, +paths: List<&2, String>) ->
    {lhs(segs, paths, Nil{}) == P.match_segments(segs, paths) : Maybe<&2, P.Params>}:
  match segs:
    case Nil{}:
      {==}
    case P.Static{raw} <> rest:
      {==}
    case P.Capture{name, c, optional} <> rest:
      {==}
    case P.Wildcard{name} <> rest:
      {==}
    case P.InteriorWildcard{} <> rest:
      {==}
    case P.PrefixWildcard{prefix} <> rest:
      {==}
    case P.Span{name} <> rest:
      {==}

def capture_cons(+name: String, +c: C.Constraint, +optional: Bool, +rest: List<&2, P.Segment>, +h: String, +t: List<&2, String>,
    inner: {P.match_segments(rest, t) == S.matches(rest, t, Nil{}) : Maybe<&2, P.Params>}) ->
    {P.match_segments(P.Capture{name, c, optional} <> rest, h <> t) == S.capture(name, c, E.decode(h), S.matches(rest, t, Nil{})) : Maybe<&2, P.Params>}:
  match optional:
    case True{}:
      %Equal.sym(Maybe<&2, P.Params>, P.match_segments(rest, t), S.matches(rest, t, Nil{}), inner) : {Maybe.bind(&2, String, P.Params, E.decode(h), +v => E.choose(Maybe<&2, P.Params>, P.value_ok(c, v), u => P.put_capture(name, v, _), u => None{})) == S.capture(name, c, E.decode(h), S.matches(rest, t, Nil{})) : Maybe<&2, P.Params>}
      capture_eq(name, c, E.decode(h), S.matches(rest, t, Nil{}))
    case False{}:
      %Equal.sym(Maybe<&2, P.Params>, P.match_segments(rest, t), S.matches(rest, t, Nil{}), inner) : {Maybe.bind(&2, String, P.Params, E.decode(h), +v => E.choose(Maybe<&2, P.Params>, P.value_ok(c, v), u => P.put_capture(name, v, _), u => None{})) == S.capture(name, c, E.decode(h), S.matches(rest, t, Nil{})) : Maybe<&2, P.Params>}
      capture_eq(name, c, E.decode(h), S.matches(rest, t, Nil{}))

law segments_spec:
  for +segs: List<&2, P.Segment>
  for +paths: List<&2, String>
  for +taken: List<&2, String>
  {lhs(segs, paths, taken) == S.matches(segs, paths, taken) : Maybe<&2, P.Params>}

def segments_spec(segs, paths, taken):
  match segs paths:
    case Nil{} Nil{}:
      {==}
    case Nil{} h <> t:
      {==}
    case P.Static{raw} <> rest Nil{}:
      {==}
    case P.Static{+raw} <> +rest +h <> +t:
      %Equal.sym(Maybe<&2, P.Params>, P.match_segments(rest, t), S.matches(rest, t, Nil{}), Equal.trans(Maybe<&2, P.Params>, P.match_segments(rest, t), lhs(rest, t, Nil{}), S.matches(rest, t, Nil{}), Equal.sym(Maybe<&2, P.Params>, lhs(rest, t, Nil{}), P.match_segments(rest, t), lhs_nil(rest, t)), segments_spec(rest, t, Nil{}))) : {E.choose(Maybe<&2, P.Params>, String.eq(raw, h), u => _, u => None{}) == S.same_text(String.eq(raw, h), S.matches(rest, t, Nil{})) : Maybe<&2, P.Params>}
      choose_same(String.eq(raw, h), S.matches(rest, t, Nil{}))
    case P.Capture{name, c, True{}} <> +rest Nil{}:
      Equal.trans(Maybe<&2, P.Params>, P.match_segments(rest, Nil{}), lhs(rest, Nil{}, Nil{}), S.matches(rest, Nil{}, Nil{}), Equal.sym(Maybe<&2, P.Params>, lhs(rest, Nil{}, Nil{}), P.match_segments(rest, Nil{}), lhs_nil(rest, Nil{})), segments_spec(rest, Nil{}, Nil{}))
    case P.Capture{name, c, False{}} <> rest Nil{}:
      {==}
    case P.Capture{+name, +c, +optional} <> +rest +h <> +t:
      capture_cons(name, c, optional, rest, h, t, Equal.trans(Maybe<&2, P.Params>, P.match_segments(rest, t), lhs(rest, t, Nil{}), S.matches(rest, t, Nil{}), Equal.sym(Maybe<&2, P.Params>, lhs(rest, t, Nil{}), P.match_segments(rest, t), lhs_nil(rest, t)), segments_spec(rest, t, Nil{})))
    case P.Wildcard{+name} <> Nil{} +ps:
      %Equal.sym(Maybe<&2, String>, P.decode_segments(ps), joined(S.decoded_all(ps)), decode_eq(ps)) : {P.wildcard_param(name, _) == S.wildcard(name, S.decoded_all(ps)) : Maybe<&2, P.Params>}
      wildcard_eq(name, S.decoded_all(ps))
    case P.Wildcard{name} <> h <> t Nil{}:
      {==}
    case P.Wildcard{name} <> h <> t x <> y:
      {==}
    case P.InteriorWildcard{} <> +rest Nil{}:
      Equal.trans(Maybe<&2, P.Params>, P.prefer(P.search_segments(rest, Nil{}), u => None{}), P.search_segments(rest, Nil{}), S.matches(rest, Nil{}, Nil{}), prefer_none(P.search_segments(rest, Nil{})), Equal.trans(Maybe<&2, P.Params>, P.search_segments(rest, Nil{}), P.match_segments(rest, Nil{}), S.matches(rest, Nil{}, Nil{}), Core.search_equal(rest, Nil{}), Equal.trans(Maybe<&2, P.Params>, P.match_segments(rest, Nil{}), lhs(rest, Nil{}, Nil{}), S.matches(rest, Nil{}, Nil{}), Equal.sym(Maybe<&2, P.Params>, lhs(rest, Nil{}, Nil{}), P.match_segments(rest, Nil{}), lhs_nil(rest, Nil{})), segments_spec(rest, Nil{}, Nil{}))))
    case P.InteriorWildcard{} <> +rest +h <> +t:
      %Equal.sym(Maybe<&2, P.Params>, P.search_segments(P.InteriorWildcard{} <> rest, h <> t), P.row_one(~String.eq, ~String.starts_with, P.InteriorWildcard{}, List.is_empty(&2, P.Segment, rest), h <> t, P.match_rows(~String.eq, ~String.starts_with, rest, h <> t), Core.below(P.InteriorWildcard{}, rest, h <> t)), Core.rows_head(P.InteriorWildcard{}, rest, h <> t)) : {_ == S.or_else(S.matches(rest, h <> t, Nil{}), u => S.matches(P.InteriorWildcard{} <> rest, t, Nil{})) : Maybe<&2, P.Params>}
      %Equal.sym(Maybe<&2, P.Params>, P.search_segments(rest, h <> t), S.matches(rest, h <> t, Nil{}), Equal.trans(Maybe<&2, P.Params>, P.search_segments(rest, h <> t), P.match_segments(rest, h <> t), S.matches(rest, h <> t, Nil{}), Core.search_equal(rest, h <> t), Equal.trans(Maybe<&2, P.Params>, P.match_segments(rest, h <> t), lhs(rest, h <> t, Nil{}), S.matches(rest, h <> t, Nil{}), Equal.sym(Maybe<&2, P.Params>, lhs(rest, h <> t, Nil{}), P.match_segments(rest, h <> t), lhs_nil(rest, h <> t)), segments_spec(rest, h <> t, Nil{})))) : {P.prefer(_, u => P.search_segments(P.InteriorWildcard{} <> rest, t)) == S.or_else(S.matches(rest, h <> t, Nil{}), u => S.matches(P.InteriorWildcard{} <> rest, t, Nil{})) : Maybe<&2, P.Params>}
      %Equal.sym(Maybe<&2, P.Params>, lhs(P.InteriorWildcard{} <> rest, t, Nil{}), S.matches(P.InteriorWildcard{} <> rest, t, Nil{}), segments_spec(P.InteriorWildcard{} <> rest, t, Nil{})) : {P.prefer(S.matches(rest, h <> t, Nil{}), u => _) == S.or_else(S.matches(rest, h <> t, Nil{}), u => S.matches(P.InteriorWildcard{} <> rest, t, Nil{})) : Maybe<&2, P.Params>}
      prefer_or_else(S.matches(rest, h <> t, Nil{}), S.matches(P.InteriorWildcard{} <> rest, t, Nil{}))
    case P.PrefixWildcard{+prefix} <> Nil{} +h <> +t:
      %Equal.sym(Maybe<&2, P.Params>, P.search_segments([P.PrefixWildcard{prefix}], h <> t), P.row_one(~String.eq, ~String.starts_with, P.PrefixWildcard{prefix}, True{}, h <> t, P.match_rows(~String.eq, ~String.starts_with, Nil{}, h <> t), Core.below(P.PrefixWildcard{prefix}, Nil{}, h <> t)), Core.rows_head(P.PrefixWildcard{prefix}, Nil{}, h <> t)) : {_ == S.prefix_hit(String.starts_with(h, prefix)) : Maybe<&2, P.Params>}
      hit_eq(String.starts_with(h, prefix))
    case P.PrefixWildcard{prefix} <> Nil{} Nil{}:
      {==}
    case P.PrefixWildcard{prefix} <> a <> b Nil{}:
      {==}
    case P.PrefixWildcard{+prefix} <> +a <> +b +h <> +t:
      %Equal.sym(Maybe<&2, P.Params>, P.search_segments(P.PrefixWildcard{prefix} <> a <> b, h <> t), P.row_one(~String.eq, ~String.starts_with, P.PrefixWildcard{prefix}, False{}, h <> t, P.match_rows(~String.eq, ~String.starts_with, a <> b, h <> t), Core.below(P.PrefixWildcard{prefix}, a <> b, h <> t)), Core.rows_head(P.PrefixWildcard{prefix}, a <> b, h <> t)) : {_ == None{} : Maybe<&2, P.Params>}
      {==}
    case P.Span{name} <> rest Nil{}:
      {==}
    case P.Span{+name} <> +rest +h <> +t:
      %Equal.sym(Core.Rows, P.match_rows(~String.eq, ~String.starts_with, rest, h <> t), P.search_segments(rest, h <> t) <> P.match_rows(~String.eq, ~String.starts_with, rest, t), Core.rows_cons(rest, h, t)) : {P.span_scan(h <> t, _, name, taken) == S.or_else(S.matches(P.Span{name} <> rest, t, h <> taken), u => S.span_here(name, h <> taken, S.matches(rest, t, Nil{}))) : Maybe<&2, P.Params>}
      %PS.span_scan_cons(h, t, P.search_segments(rest, h <> t), P.match_rows(~String.eq, ~String.starts_with, rest, t), name, taken) : {_ == S.or_else(S.matches(P.Span{name} <> rest, t, h <> taken), u => S.span_here(name, h <> taken, S.matches(rest, t, Nil{}))) : Maybe<&2, P.Params>}
      %Equal.sym(Maybe<&2, P.Params>, lhs(P.Span{name} <> rest, t, h <> taken), S.matches(P.Span{name} <> rest, t, h <> taken), segments_spec(P.Span{name} <> rest, t, h <> taken)) : {P.prefer(_, u => P.span_value(name, h <> taken, P.row_head(P.match_rows(~String.eq, ~String.starts_with, rest, t)))) == S.or_else(S.matches(P.Span{name} <> rest, t, h <> taken), u => S.span_here(name, h <> taken, S.matches(rest, t, Nil{}))) : Maybe<&2, P.Params>}
      %Equal.sym(Maybe<&2, P.Params>, P.search_segments(rest, t), S.matches(rest, t, Nil{}), Equal.trans(Maybe<&2, P.Params>, P.search_segments(rest, t), P.match_segments(rest, t), S.matches(rest, t, Nil{}), Core.search_equal(rest, t), Equal.trans(Maybe<&2, P.Params>, P.match_segments(rest, t), lhs(rest, t, Nil{}), S.matches(rest, t, Nil{}), Equal.sym(Maybe<&2, P.Params>, lhs(rest, t, Nil{}), P.match_segments(rest, t), lhs_nil(rest, t)), segments_spec(rest, t, Nil{})))) : {P.prefer(S.matches(P.Span{name} <> rest, t, h <> taken), u => P.span_value(name, h <> taken, _)) == S.or_else(S.matches(P.Span{name} <> rest, t, h <> taken), u => S.span_here(name, h <> taken, S.matches(rest, t, Nil{}))) : Maybe<&2, P.Params>}
      %Equal.sym(Maybe<&2, P.Params>, P.span_value(name, h <> taken, S.matches(rest, t, Nil{})), S.span_here(name, h <> taken, S.matches(rest, t, Nil{})), span_eq(name, h <> taken, S.matches(rest, t, Nil{}))) : {P.prefer(S.matches(P.Span{name} <> rest, t, h <> taken), u => _) == S.or_else(S.matches(P.Span{name} <> rest, t, h <> taken), u => S.span_here(name, h <> taken, S.matches(rest, t, Nil{}))) : Maybe<&2, P.Params>}
      prefer_or_else(S.matches(P.Span{name} <> rest, t, h <> taken), S.span_here(name, h <> taken, S.matches(rest, t, Nil{})))

def matches_spec(+segs: List<&2, P.Segment>, +paths: List<&2, String>) ->
    {P.match_segments(segs, paths) == S.matches(segs, paths, Nil{}) : Maybe<&2, P.Params>}:
  Equal.trans(Maybe<&2, P.Params>, P.match_segments(segs, paths), lhs(segs, paths, Nil{}), S.matches(segs, paths, Nil{}), Equal.sym(Maybe<&2, P.Params>, lhs(segs, paths, Nil{}), P.match_segments(segs, paths), lhs_nil(segs, paths)), segments_spec(segs, paths, Nil{}))

def optional_same(+segs: List<&2, P.Segment>) -> {P.all_optional(segs) == S.only_optional(segs) : Bool}:
  match segs:
    case Nil{}:
      {==}
    case P.Capture{name, c, True{}} <> +rest:
      optional_same(rest)
    case P.Capture{name, c, False{}} <> rest:
      {==}
    case P.Static{raw} <> rest:
      {==}
    case P.Wildcard{name} <> rest:
      {==}
    case P.InteriorWildcard{} <> rest:
      {==}
    case P.PrefixWildcard{prefix} <> rest:
      {==}
    case P.Span{name} <> rest:
      {==}

def root_choice(b: Bool, +r: Maybe<&2, P.Params>, none: {r == None{} : Maybe<&2, P.Params>}) ->
    {E.choose(Maybe<&2, P.Params>, b, u => Some{Nil{}}, u => r) == S.prefix_hit(b) : Maybe<&2, P.Params>}:
  match b:
    case True{}:
      {==}
    case False{}:
      none

def rest_eq(+segs: List<&2, P.Segment>, +paths: List<&2, String>, +r: Maybe<&2, P.Params>, none: {r == None{} : Maybe<&2, P.Params>}) ->
    {P.match_segments(segs, paths) == S.or_else(S.matches(segs, paths, Nil{}), u => r) : Maybe<&2, P.Params>}:
  %Equal.sym(Maybe<&2, P.Params>, r, None{}, none) : {P.match_segments(segs, paths) == S.or_else(S.matches(segs, paths, Nil{}), u => _) : Maybe<&2, P.Params>}
  Equal.trans(Maybe<&2, P.Params>, P.match_segments(segs, paths), S.matches(segs, paths, Nil{}), S.or_else(S.matches(segs, paths, Nil{}), u => None{}), matches_spec(segs, paths), Equal.sym(Maybe<&2, P.Params>, S.or_else(S.matches(segs, paths, Nil{}), u => None{}), S.matches(segs, paths, Nil{}), or_else_none(S.matches(segs, paths, Nil{}))))

def root_eq(+pattern: P.Pattern, +t: String) -> {P.match_root(pattern, t) == S.match_rest(pattern, t) : Maybe<&2, P.Params>}:
  match pattern t:
    case P.Pattern{P.Capture{+name, +c, True{}} <> +rest} SNil{}:
      %Equal.sym(Bool, P.all_optional(rest), S.only_optional(rest), optional_same(rest)) : {E.choose(Maybe<&2, P.Params>, _, u => Some{Nil{}}, u => P.match_segments(P.Capture{name, c, True{}} <> rest, [""])) == S.match_rest(P.Pattern{P.Capture{name, c, True{}} <> rest}, SNil{}) : Maybe<&2, P.Params>}
      root_choice(S.only_optional(rest), P.match_segments(P.Capture{name, c, True{}} <> rest, [""]), {==})
    case P.Pattern{P.Capture{+name, +c, True{}} <> +rest} SCon{+x, +y}:
      %TP.split_equiv(SCon{x, y}, '/') : {P.match_root(P.Pattern{P.Capture{name, c, True{}} <> rest}, SCon{x, y}) == S.or_else(S.matches(P.Capture{name, c, True{}} <> rest, _, Nil{}), u => None{}) : Maybe<&2, P.Params>}
      rest_eq(P.Capture{name, c, True{}} <> rest, P.path_segments(SCon{x, y}), None{}, {==})
    case P.Pattern{Nil{}} +s:
      %TP.split_equiv(s, '/') : {P.match_root(P.Pattern{Nil{}}, s) == S.or_else(S.matches(Nil{}, _, Nil{}), u => None{}) : Maybe<&2, P.Params>}
      rest_eq(Nil{}, P.path_segments(s), None{}, {==})
    case P.Pattern{P.Capture{+name, +c, False{}} <> +rest} +s:
      %TP.split_equiv(s, '/') : {P.match_root(P.Pattern{P.Capture{name, c, False{}} <> rest}, s) == S.or_else(S.matches(P.Capture{name, c, False{}} <> rest, _, Nil{}), u => None{}) : Maybe<&2, P.Params>}
      rest_eq(P.Capture{name, c, False{}} <> rest, P.path_segments(s), None{}, {==})
    case P.Pattern{P.Static{+raw} <> +rest} +s:
      %TP.split_equiv(s, '/') : {P.match_root(P.Pattern{P.Static{raw} <> rest}, s) == S.or_else(S.matches(P.Static{raw} <> rest, _, Nil{}), u => None{}) : Maybe<&2, P.Params>}
      rest_eq(P.Static{raw} <> rest, P.path_segments(s), None{}, {==})
    case P.Pattern{P.Wildcard{+name} <> +rest} +s:
      %TP.split_equiv(s, '/') : {P.match_root(P.Pattern{P.Wildcard{name} <> rest}, s) == S.or_else(S.matches(P.Wildcard{name} <> rest, _, Nil{}), u => None{}) : Maybe<&2, P.Params>}
      rest_eq(P.Wildcard{name} <> rest, P.path_segments(s), None{}, {==})
    case P.Pattern{P.InteriorWildcard{} <> +rest} +s:
      %TP.split_equiv(s, '/') : {P.match_root(P.Pattern{P.InteriorWildcard{} <> rest}, s) == S.or_else(S.matches(P.InteriorWildcard{} <> rest, _, Nil{}), u => None{}) : Maybe<&2, P.Params>}
      rest_eq(P.InteriorWildcard{} <> rest, P.path_segments(s), None{}, {==})
    case P.Pattern{P.PrefixWildcard{+prefix} <> +rest} +s:
      %TP.split_equiv(s, '/') : {P.match_root(P.Pattern{P.PrefixWildcard{prefix} <> rest}, s) == S.or_else(S.matches(P.PrefixWildcard{prefix} <> rest, _, Nil{}), u => None{}) : Maybe<&2, P.Params>}
      rest_eq(P.PrefixWildcard{prefix} <> rest, P.path_segments(s), None{}, {==})
    case P.Pattern{P.Span{+name} <> +rest} +s:
      %TP.split_equiv(s, '/') : {P.match_root(P.Pattern{P.Span{name} <> rest}, s) == S.or_else(S.matches(P.Span{name} <> rest, _, Nil{}), u => None{}) : Maybe<&2, P.Params>}
      rest_eq(P.Span{name} <> rest, P.path_segments(s), None{}, {==})

def path_spec(+pattern: P.Pattern, +path: String) -> {P.match_path(pattern, path) == S.match_path(pattern, path) : Maybe<&2, P.Params>}:
  match path:
    case SCon{'/', +tail}:
      root_eq(pattern, tail)
    case SNil{}:
      {==}
    case SCon{Chr{U32{WCon{False{}, remaining}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{False{}, remaining}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{False{}, remaining}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, remaining}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, remaining}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, remaining}}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, remaining}}}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
