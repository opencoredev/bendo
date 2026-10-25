# BND-86: under an admissible prefix, matching the assembled pattern with any
# options is the prefix walk followed by the member, as the specification
# states it. Every lemma here relates specification functions only.
import Base
import ../src/router/pattern.bend as P
import ../src/router/encoding.bend as E
import ../src/router/constraint.bend as C
import ../src/router/methods.bend as M
import ../src/router/proofs.bend as Core
import ../src/router/match-spec-proofs.bend as MSP
import ./router-compile-spec.bend as CS
import ./router-match-spec.bend as MS
import ./mount-spec.bend as S

def get_pattern(m: Maybe<&2, P.Pattern>, d: P.Pattern) -> P.Pattern:
  match m:
    case Some{p}:
      p
    case None{}:
      d

def is_none_type(m: Maybe<&2, P.Pattern>) -> Type:
  match m:
    case None{}:
      Unit
    case Some{p}:
      Empty

def none_some(+p: P.Pattern, e: {None{} == Some{p} : Maybe<&2, P.Pattern>}) -> Empty:
  %e : is_none_type(_)
  Unit{}

def accept_some(ok: Bool, +segs: List<&2, P.Segment>, +p: P.Pattern, e: {CS.accept(ok, segs) == Some{p} : Maybe<&2, P.Pattern>}) ->
    {p == P.Pattern{segs} : P.Pattern}:
  match ok:
    case False{}:
      Core.absurd({p == P.Pattern{segs} : P.Pattern}, none_some(p, e))
    case True{}:
      Equal.sym(P.Pattern, P.Pattern{segs}, p, Equal.cong(Maybe<&2, P.Pattern>, P.Pattern, m => get_pattern(m, P.Pattern{segs}), Some{P.Pattern{segs}}, Some{p}, e))

# ---- Lenient mode keeps a fixed prefix ----

def keep_static(+rest: List<&2, P.Segment>, +x: Char, +y: String) ->
    {S.keep_segment(rest, P.Static{SCon{x, y}}) == P.Static{SCon{x, y}} <> rest : List<&2, P.Segment>}:
  match rest:
    case Nil{}:
      {==}
    case r <> t:
      {==}

def keep_capture(+rest: List<&2, P.Segment>, +n: String, +k: C.Constraint, +o: Bool) ->
    {S.keep_segment(rest, P.Capture{n, k, o}) == P.Capture{n, k, o} <> rest : List<&2, P.Segment>}:
  match rest:
    case Nil{}:
      {==}
    case r <> t:
      {==}

def drop_fixed(+a: List<&2, P.Segment>, +b: List<&2, P.Segment>, fixed: {S.fixed_segments(a) == True{} : Bool}) ->
    {S.drop_static(List.append(&2, P.Segment, a, b)) == List.append(&2, P.Segment, a, S.drop_static(b)) : List<&2, P.Segment>}:
  match a:
    case Nil{}:
      {==}
    case P.Static{SCon{+x, +y}} <> +t:
      %Equal.sym(List<&2, P.Segment>, S.drop_static(List.append(&2, P.Segment, t, b)), List.append(&2, P.Segment, t, S.drop_static(b)), drop_fixed(t, b, fixed)) : {S.keep_segment(_, P.Static{SCon{x, y}}) == P.Static{SCon{x, y}} <> List.append(&2, P.Segment, t, S.drop_static(b)) : List<&2, P.Segment>}
      keep_static(List.append(&2, P.Segment, t, S.drop_static(b)), x, y)
    case P.Capture{+n, +k, False{}} <> +t:
      %Equal.sym(List<&2, P.Segment>, S.drop_static(List.append(&2, P.Segment, t, b)), List.append(&2, P.Segment, t, S.drop_static(b)), drop_fixed(t, b, fixed)) : {S.keep_segment(_, P.Capture{n, k, False{}}) == P.Capture{n, k, False{}} <> List.append(&2, P.Segment, t, S.drop_static(b)) : List<&2, P.Segment>}
      keep_capture(List.append(&2, P.Segment, t, S.drop_static(b)), n, k, False{})
    case P.Static{SNil{}} <> t:
      Core.absurd({S.drop_static(List.append(&2, P.Segment, P.Static{SNil{}} <> t, b)) == List.append(&2, P.Segment, P.Static{SNil{}} <> t, S.drop_static(b)) : List<&2, P.Segment>}, Core.false_true(fixed))
    case P.Capture{n, k, True{}} <> t:
      Core.absurd({S.drop_static(List.append(&2, P.Segment, P.Capture{n, k, True{}} <> t, b)) == List.append(&2, P.Segment, P.Capture{n, k, True{}} <> t, S.drop_static(b)) : List<&2, P.Segment>}, Core.false_true(fixed))
    case P.Wildcard{n} <> t:
      Core.absurd({S.drop_static(List.append(&2, P.Segment, P.Wildcard{n} <> t, b)) == List.append(&2, P.Segment, P.Wildcard{n} <> t, S.drop_static(b)) : List<&2, P.Segment>}, Core.false_true(fixed))
    case P.InteriorWildcard{} <> t:
      Core.absurd({S.drop_static(List.append(&2, P.Segment, P.InteriorWildcard{} <> t, b)) == List.append(&2, P.Segment, P.InteriorWildcard{} <> t, S.drop_static(b)) : List<&2, P.Segment>}, Core.false_true(fixed))
    case P.PrefixWildcard{x} <> t:
      Core.absurd({S.drop_static(List.append(&2, P.Segment, P.PrefixWildcard{x} <> t, b)) == List.append(&2, P.Segment, P.PrefixWildcard{x} <> t, S.drop_static(b)) : List<&2, P.Segment>}, Core.false_true(fixed))
    case P.Span{n} <> t:
      Core.absurd({S.drop_static(List.append(&2, P.Segment, P.Span{n} <> t, b)) == List.append(&2, P.Segment, P.Span{n} <> t, S.drop_static(b)) : List<&2, P.Segment>}, Core.false_true(fixed))

# Lenient mode drops the member's terminal empty statics; the fixed prefix
# keeps every segment, so no root segment comes back.
def norm_append(+s: Bool, +a: List<&2, P.Segment>, +b: List<&2, P.Segment>, fixed: {S.fixed_prefix(a) == True{} : Bool}) ->
    {S.normal_pattern(s, List.append(&2, P.Segment, a, b)) == List.append(&2, P.Segment, a, S.member_segments(s, b)) : List<&2, P.Segment>}:
  match s:
    case True{}:
      {==}
    case False{}:
      match a:
        case Nil{}:
          Core.absurd({S.normal_pattern(False{}, List.append(&2, P.Segment, Nil{}, b)) == List.append(&2, P.Segment, Nil{}, S.member_segments(False{}, b)) : List<&2, P.Segment>}, Core.false_true(fixed))
        case +h <> +t:
          %Equal.sym(List<&2, P.Segment>, S.drop_static(List.append(&2, P.Segment, h <> t, b)), List.append(&2, P.Segment, h <> t, S.drop_static(b)), drop_fixed(h <> t, b, fixed)) : {S.root_segment(_) == List.append(&2, P.Segment, h <> t, S.drop_static(b)) : List<&2, P.Segment>}
          {==}

# A fixed first segment is never the root rule's optional capture.
def root_none(+xs: List<&2, String>, +seg: P.Segment, +rest: List<&2, P.Segment>, +more: List<&2, P.Segment>, fixed: {S.fixed_prefix(seg <> rest) == True{} : Bool}) ->
    {S.root_hit(xs, seg <> more) == None{} : Maybe<&2, P.Params>}:
  match xs:
    case Nil{}:
      {==}
    case SCon{a, b} <> t:
      {==}
    case SNil{} <> y <> z:
      {==}
    case SNil{} <> Nil{}:
      match seg:
        case P.Capture{n, k, True{}}:
          Core.absurd({S.root_hit([""], P.Capture{n, k, True{}} <> more) == None{} : Maybe<&2, P.Params>}, Core.false_true(fixed))
        case P.Capture{n, k, False{}}:
          {==}
        case P.Static{raw}:
          {==}
        case P.Wildcard{n}:
          {==}
        case P.InteriorWildcard{}:
          {==}
        case P.PrefixWildcard{x}:
          {==}
        case P.Span{n}:
          {==}

# Matching prefix segments followed by the member is the prefix walk.
def segs_walk(+a: List<&2, P.Segment>, +b: List<&2, P.Segment>, +xs: List<&2, String>, +c: Bool, fixed: {S.fixed_segments(a) == True{} : Bool}) ->
    {S.segments_with(c, List.append(&2, P.Segment, a, b), xs) == S.walk(a, xs, c, b) : Maybe<&2, P.Params>}:
  match a xs:
    case Nil{} ys:
      {==}
    case P.Static{SCon{+x, +y}} <> +t Nil{}:
      match c:
        case True{}:
          {==}
        case False{}:
          {==}
    case P.Static{SCon{+x, +y}} <> +t +h <> +u:
      match c:
        case True{}:
          Equal.cong(Maybe<&2, P.Params>, Maybe<&2, P.Params>, r => MS.same_text(String.eq(SCon{x, y}, h), r), S.segments_with(True{}, List.append(&2, P.Segment, t, b), u), S.walk(t, u, True{}, b), segs_walk(t, b, u, True{}, fixed))
        case False{}:
          Equal.cong(Maybe<&2, P.Params>, Maybe<&2, P.Params>, r => MS.same_text(S.folded_text(SCon{x, y}, h), r), S.segments_with(False{}, List.append(&2, P.Segment, t, b), u), S.walk(t, u, False{}, b), segs_walk(t, b, u, False{}, fixed))
    case P.Capture{+n, +k, False{}} <> +t Nil{}:
      match c:
        case True{}:
          {==}
        case False{}:
          {==}
    case P.Capture{+n, +k, False{}} <> +t +h <> +u:
      match c:
        case True{}:
          Equal.cong(Maybe<&2, P.Params>, Maybe<&2, P.Params>, r => MS.capture(n, k, E.decode(h), r), S.segments_with(True{}, List.append(&2, P.Segment, t, b), u), S.walk(t, u, True{}, b), segs_walk(t, b, u, True{}, fixed))
        case False{}:
          Equal.cong(Maybe<&2, P.Params>, Maybe<&2, P.Params>, r => MS.capture(n, k, E.decode(h), r), S.segments_with(False{}, List.append(&2, P.Segment, t, b), u), S.walk(t, u, False{}, b), segs_walk(t, b, u, False{}, fixed))
    case P.Static{SNil{}} <> t ys:
      Core.absurd({S.segments_with(c, List.append(&2, P.Segment, P.Static{SNil{}} <> t, b), ys) == S.walk(P.Static{SNil{}} <> t, ys, c, b) : Maybe<&2, P.Params>}, Core.false_true(fixed))
    case P.Capture{n, k, True{}} <> t ys:
      Core.absurd({S.segments_with(c, List.append(&2, P.Segment, P.Capture{n, k, True{}} <> t, b), ys) == S.walk(P.Capture{n, k, True{}} <> t, ys, c, b) : Maybe<&2, P.Params>}, Core.false_true(fixed))
    case P.Wildcard{n} <> t ys:
      Core.absurd({S.segments_with(c, List.append(&2, P.Segment, P.Wildcard{n} <> t, b), ys) == S.walk(P.Wildcard{n} <> t, ys, c, b) : Maybe<&2, P.Params>}, Core.false_true(fixed))
    case P.InteriorWildcard{} <> t ys:
      Core.absurd({S.segments_with(c, List.append(&2, P.Segment, P.InteriorWildcard{} <> t, b), ys) == S.walk(P.InteriorWildcard{} <> t, ys, c, b) : Maybe<&2, P.Params>}, Core.false_true(fixed))
    case P.PrefixWildcard{x} <> t ys:
      Core.absurd({S.segments_with(c, List.append(&2, P.Segment, P.PrefixWildcard{x} <> t, b), ys) == S.walk(P.PrefixWildcard{x} <> t, ys, c, b) : Maybe<&2, P.Params>}, Core.false_true(fixed))
    case P.Span{n} <> t ys:
      Core.absurd({S.segments_with(c, List.append(&2, P.Segment, P.Span{n} <> t, b), ys) == S.walk(P.Span{n} <> t, ys, c, b) : Maybe<&2, P.Params>}, Core.false_true(fixed))

def finish(+a: List<&2, P.Segment>, +mb: List<&2, P.Segment>, +xs: List<&2, String>, +c: Bool, fixed: {S.fixed_prefix(a) == True{} : Bool}) ->
    {S.matched(c, List.append(&2, P.Segment, a, mb), xs) == S.walk(a, xs, c, mb) : Maybe<&2, P.Params>}:
  match a:
    case Nil{}:
      Core.absurd({S.matched(c, List.append(&2, P.Segment, Nil{}, mb), xs) == S.walk(Nil{}, xs, c, mb) : Maybe<&2, P.Params>}, Core.false_true(fixed))
    case +h <> +t:
      +e = fixed
      %Equal.sym(Maybe<&2, P.Params>, S.root_hit(xs, h <> List.append(&2, P.Segment, t, mb)), None{}, root_none(xs, h, t, List.append(&2, P.Segment, t, mb), e)) : {MS.or_else(S.segments_with(c, h <> List.append(&2, P.Segment, t, mb), xs), u => _) == S.walk(h <> t, xs, c, mb) : Maybe<&2, P.Params>}
      Equal.trans(Maybe<&2, P.Params>, MS.or_else(S.segments_with(c, h <> List.append(&2, P.Segment, t, mb), xs), u => None{}), S.segments_with(c, h <> List.append(&2, P.Segment, t, mb), xs), S.walk(h <> t, xs, c, mb), MSP.or_else_none(S.segments_with(c, h <> List.append(&2, P.Segment, t, mb), xs)), segs_walk(h <> t, mb, xs, c, e))

def decomp_at(+m: Maybe<&2, String>, +a: List<&2, P.Segment>, +b: List<&2, P.Segment>, +opts: M.Options, fixed: {S.fixed_prefix(a) == True{} : Bool}) ->
    {S.options_at(m, P.Pattern{List.append(&2, P.Segment, a, b)}, opts) == S.walk_at(m, a, b, opts) : Maybe<&2, P.Params>}:
  match m:
    case None{}:
      {==}
    case Some{+t}:
      match opts:
        case M.Options{+s, +c}:
          +e = fixed
          %Equal.sym(List<&2, P.Segment>, S.normal_pattern(s, List.append(&2, P.Segment, a, b)), List.append(&2, P.Segment, a, S.member_segments(s, b)), norm_append(s, a, b, e)) : {S.matched(c, _, S.normal_path(s, String.split(t, '/'))) == S.walk(a, S.normal_path(s, String.split(t, '/')), c, S.member_segments(s, b)) : Maybe<&2, P.Params>}
          finish(a, S.member_segments(s, b), S.normal_path(s, String.split(t, '/')), c, e)

def decompose_pieces(pp: Maybe<&2, List<&2, P.Segment>>, mp: Maybe<&2, List<&2, P.Segment>>, +p: P.Pattern, +path: String, +opts: M.Options,
    e: {S.joined(pp, mp) == Some{p} : Maybe<&2, P.Pattern>}, adm: {S.fixed_and(pp, S.compiles(S.joined(pp, mp))) == True{} : Bool}) ->
    {S.match_options(p, path, opts) == S.walk_pieces(pp, mp, path, opts) : Maybe<&2, P.Params>}:
  match pp mp:
    case None{} y:
      Core.absurd({S.match_options(p, path, opts) == S.walk_pieces(None{}, y, path, opts) : Maybe<&2, P.Params>}, none_some(p, e))
    case Some{a} None{}:
      Core.absurd({S.match_options(p, path, opts) == S.walk_pieces(Some{a}, None{}, path, opts) : Maybe<&2, P.Params>}, none_some(p, e))
    case Some{+a} Some{+b}:
      +same = accept_some(CS.rules(List.append(&2, P.Segment, a, b), Nil{}) && CS.spans(List.append(&2, P.Segment, a, b)), List.append(&2, P.Segment, a, b), p, e)
      +fixed = Core.and_left(S.fixed_prefix(a), S.compiles(CS.checked(Some{List.append(&2, P.Segment, a, b)})), adm)
      %Equal.sym(P.Pattern, p, P.Pattern{List.append(&2, P.Segment, a, b)}, same) : {S.match_options(_, path, opts) == S.walk_pieces(Some{a}, Some{b}, path, opts) : Maybe<&2, P.Params>}
      decomp_at(S.slash_tail(path), a, b, opts, fixed)

# The decomposition, for every placement of the prefix.
def decompose_at(at: S.Place, +member: String, +p: P.Pattern, +path: String, +opts: M.Options,
    e: {S.assembled_at(at, member) == Some{p} : Maybe<&2, P.Pattern>}, adm: {S.admissible_at(at, member) == True{} : Bool}) ->
    {S.match_options(p, path, opts) == S.mounted_at(at, member, path, opts) : Maybe<&2, P.Params>}:
  match at:
    case S.AtRoot{}:
      %Equal.sym(Maybe<&2, P.Pattern>, CS.compile(member), Some{p}, e) : {S.match_options(p, path, opts) == S.member_alone(_, path, opts) : Maybe<&2, P.Params>}
      {==}
    case S.Under{+raws}:
      decompose_pieces(S.prefix_pieces(raws), S.member_pieces(S.member_text(member)), p, path, opts, e, adm)
    case S.Unplaced{}:
      Core.absurd({S.match_options(p, path, opts) == S.mounted_at(S.Unplaced{}, member, path, opts) : Maybe<&2, P.Params>}, Core.false_true(adm))
