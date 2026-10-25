# BND-86: matching under the slash and case options equals the independent
# option reading in proof/mount-spec.bend, for every pattern and raw path.
import Base
import ../src/router/pattern.bend as P
import ../src/router/encoding.bend as E
import ../src/router/constraint.bend as C
import ../src/router/methods.bend as M
import ../src/router/proofs.bend as Core
import ../src/router/pattern-stack-proofs.bend as PS
import ../src/router/match-spec-proofs.bend as MSP
import ../src/http/bytes.bend as B
import ./bytes-tail.bend as BT
import ./parser-spec.bend as PSP
import ./fold-spec.bend as F
import ./router-match-spec.bend as MS
import ./mount-spec.bend as S

# ---- ASCII folding is the letter table ----

def fold_same(+s: String) -> {B.fold(s) == F.fold(s) : String}:
  Equal.trans(String, B.fold(s), String.to_lower(s), F.fold(s), BT.fold_equiv(s), PSP.lower_table(s))

def equal_same(+a: String, +b: String) -> {M.folded_equal(a, b) == S.folded_text(a, b) : Bool}:
  %fold_same(a) : {String.eq(B.fold(a), B.fold(b)) == String.eq(_, F.fold(b)) : Bool}
  %fold_same(b) : {String.eq(B.fold(a), B.fold(b)) == String.eq(B.fold(a), _) : Bool}
  {==}

def starts_same(+a: String, +b: String) -> {M.folded_starts(a, b) == S.folded_start(a, b) : Bool}:
  %fold_same(a) : {String.starts_with(B.fold(a), B.fold(b)) == String.starts_with(_, F.fold(b)) : Bool}
  %fold_same(b) : {String.starts_with(B.fold(a), B.fold(b)) == String.starts_with(B.fold(a), _) : Bool}
  {==}

# ---- The cached-row engine with injected comparisons ----

def rows_cons_t(~eq: String -> String -> Bool, ~st: String -> String -> Bool, +segs: List<&2, P.Segment>, +h: String, +t: List<&2, String>) ->
    {P.match_rows(~eq, ~st, segs, h <> t) == P.row_head(P.match_rows(~eq, ~st, segs, h <> t)) <> P.match_rows(~eq, ~st, segs, t) : Core.Rows}:
  match segs:
    case Nil{}:
      %PS.empty_rows_equiv(h <> t) : {_ == P.row_head(_) <> P.empty_rows(t) : Core.Rows}
      %PS.empty_rows_equiv(t) : {P.empty_rows_spec(h <> t) == P.row_head(P.empty_rows_spec(h <> t)) <> _ : Core.Rows}
      {==}
    case +seg <> +rest:
      +same = rows_cons_t(~eq, ~st, rest, h, t)
      %Equal.sym(Core.Rows, P.match_rows(~eq, ~st, rest, h <> t), P.row_head(P.match_rows(~eq, ~st, rest, h <> t)) <> P.match_rows(~eq, ~st, rest, t), same) : {P.rows_for(~eq, ~st, seg, List.is_empty(&2, P.Segment, rest), h <> t, _) == P.row_head(P.rows_for(~eq, ~st, seg, List.is_empty(&2, P.Segment, rest), h <> t, _)) <> P.rows_for(~eq, ~st, seg, List.is_empty(&2, P.Segment, rest), t, P.match_rows(~eq, ~st, rest, t)) : Core.Rows}
      %PS.rows_for_equiv(~eq, ~st, seg, List.is_empty(&2, P.Segment, rest), h <> t, P.row_head(P.match_rows(~eq, ~st, rest, h <> t)) <> P.match_rows(~eq, ~st, rest, t)) : {_ == P.row_head(_) <> P.rows_for(~eq, ~st, seg, List.is_empty(&2, P.Segment, rest), t, P.match_rows(~eq, ~st, rest, t)) : Core.Rows}
      %PS.rows_for_equiv(~eq, ~st, seg, List.is_empty(&2, P.Segment, rest), t, P.match_rows(~eq, ~st, rest, t)) : {P.rows_for_spec(~eq, ~st, seg, List.is_empty(&2, P.Segment, rest), h <> t, P.row_head(P.match_rows(~eq, ~st, rest, h <> t)) <> P.match_rows(~eq, ~st, rest, t)) == P.row_head(P.rows_for_spec(~eq, ~st, seg, List.is_empty(&2, P.Segment, rest), h <> t, P.row_head(P.match_rows(~eq, ~st, rest, h <> t)) <> P.match_rows(~eq, ~st, rest, t))) <> _ : Core.Rows}
      {==}

def below_t(~eq: String -> String -> Bool, ~st: String -> String -> Bool, +seg: P.Segment, +rest: List<&2, P.Segment>, +paths: List<&2, String>) -> Core.Rows:
  match paths:
    case Nil{}:
      Nil{}
    case h <> +t:
      P.match_rows(~eq, ~st, seg <> rest, t)

def rows_head_t(~eq: String -> String -> Bool, ~st: String -> String -> Bool, +seg: P.Segment, +rest: List<&2, P.Segment>, +paths: List<&2, String>) ->
    {P.row_head(P.match_rows(~eq, ~st, seg <> rest, paths)) == P.row_one(~eq, ~st, seg, List.is_empty(&2, P.Segment, rest), paths, P.match_rows(~eq, ~st, rest, paths), below_t(~eq, ~st, seg, rest, paths)) : Maybe<&2, P.Params>}:
  match paths:
    case Nil{}:
      {==}
    case +h <> +t:
      %Equal.sym(Core.Rows, P.match_rows(~eq, ~st, rest, h <> t), P.row_head(P.match_rows(~eq, ~st, rest, h <> t)) <> P.match_rows(~eq, ~st, rest, t), rows_cons_t(~eq, ~st, rest, h, t)) : {P.row_head(P.rows_for(~eq, ~st, seg, List.is_empty(&2, P.Segment, rest), h <> t, _)) == P.row_one(~eq, ~st, seg, List.is_empty(&2, P.Segment, rest), h <> t, _, P.match_rows(~eq, ~st, seg <> rest, t)) : Maybe<&2, P.Params>}
      %PS.rows_for_equiv(~eq, ~st, seg, List.is_empty(&2, P.Segment, rest), h <> t, P.row_head(P.match_rows(~eq, ~st, rest, h <> t)) <> P.match_rows(~eq, ~st, rest, t)) : {P.row_head(_) == P.row_one(~eq, ~st, seg, List.is_empty(&2, P.Segment, rest), h <> t, P.row_head(P.match_rows(~eq, ~st, rest, h <> t)) <> P.match_rows(~eq, ~st, rest, t), P.rows_for(~eq, ~st, seg, List.is_empty(&2, P.Segment, rest), t, P.match_rows(~eq, ~st, rest, t))) : Maybe<&2, P.Params>}
      %PS.rows_for_equiv(~eq, ~st, seg, List.is_empty(&2, P.Segment, rest), t, P.match_rows(~eq, ~st, rest, t)) : {P.row_head(P.rows_for_spec(~eq, ~st, seg, List.is_empty(&2, P.Segment, rest), h <> t, P.row_head(P.match_rows(~eq, ~st, rest, h <> t)) <> P.match_rows(~eq, ~st, rest, t))) == P.row_one(~eq, ~st, seg, List.is_empty(&2, P.Segment, rest), h <> t, P.row_head(P.match_rows(~eq, ~st, rest, h <> t)) <> P.match_rows(~eq, ~st, rest, t), _) : Maybe<&2, P.Params>}
      {==}

def wildcard_search_t(~eq: String -> String -> Bool, ~st: String -> String -> Bool, +name: String, +ps: List<&2, String>) ->
    {P.row_head(P.match_rows(~eq, ~st, [P.Wildcard{name}], ps)) == P.match_with(~eq, ~st, [P.Wildcard{name}], ps) : Maybe<&2, P.Params>}:
  match ps:
    case Nil{}:
      {==}
    case +raw <> +tail:
      %Equal.sym(Maybe<&2, P.Params>, P.row_head(P.match_rows(~eq, ~st, [P.Wildcard{name}], raw <> tail)), P.row_one(~eq, ~st, P.Wildcard{name}, True{}, raw <> tail, P.match_rows(~eq, ~st, Nil{}, raw <> tail), below_t(~eq, ~st, P.Wildcard{name}, Nil{}, raw <> tail)), rows_head_t(~eq, ~st, P.Wildcard{name}, Nil{}, raw <> tail)) : {_ == P.match_with(~eq, ~st, [P.Wildcard{name}], raw <> tail) : Maybe<&2, P.Params>}
      %Equal.sym(Maybe<&2, P.Params>, P.row_head(P.match_rows(~eq, ~st, [P.Wildcard{name}], tail)), P.match_with(~eq, ~st, [P.Wildcard{name}], tail), wildcard_search_t(~eq, ~st, name, tail)) : {P.wildcard_param(name, P.join_value(E.decode(raw), tail, P.wildcard_value(_))) == P.match_with(~eq, ~st, [P.Wildcard{name}], raw <> tail) : Maybe<&2, P.Params>}
      %Equal.sym(Maybe<&2, String>, P.wildcard_value(P.wildcard_param(name, P.decode_segments(tail))), P.decode_segments(tail), Core.wildcard_value_param(name, P.decode_segments(tail))) : {P.wildcard_param(name, P.join_value(E.decode(raw), tail, _)) == P.match_with(~eq, ~st, [P.Wildcard{name}], raw <> tail) : Maybe<&2, P.Params>}
      %PS.decode_segments_equiv(tail) : {P.wildcard_param(name, P.join_value(E.decode(raw), tail, _)) == P.wildcard_param(name, P.decode_segments(raw <> tail)) : Maybe<&2, P.Params>}
      %PS.decode_segments_equiv(raw <> tail) : {P.wildcard_param(name, P.join_value(E.decode(raw), tail, P.decode_segments_spec(tail))) == P.wildcard_param(name, _) : Maybe<&2, P.Params>}
      {==}

def search_equal_t(~eq: String -> String -> Bool, ~st: String -> String -> Bool, +segs: List<&2, P.Segment>, +paths: List<&2, String>) ->
    {P.row_head(P.match_rows(~eq, ~st, segs, paths)) == P.match_with(~eq, ~st, segs, paths) : Maybe<&2, P.Params>}:
  match segs paths:
    case Nil{} Nil{}:
      {==}
    case Nil{} +h <> +t:
      %PS.empty_rows_equiv(h <> t) : {P.row_head(_) == None{} : Maybe<&2, P.Params>}
      {==}
    case P.Static{+raw} <> +rest +h <> +t:
      %Equal.sym(Maybe<&2, P.Params>, P.row_head(P.match_rows(~eq, ~st, P.Static{raw} <> rest, h <> t)), P.row_one(~eq, ~st, P.Static{raw}, List.is_empty(&2, P.Segment, rest), h <> t, P.match_rows(~eq, ~st, rest, h <> t), below_t(~eq, ~st, P.Static{raw}, rest, h <> t)), rows_head_t(~eq, ~st, P.Static{raw}, rest, h <> t)) : {_ == P.match_with(~eq, ~st, P.Static{raw} <> rest, h <> t) : Maybe<&2, P.Params>}
      %Equal.sym(Core.Rows, P.match_rows(~eq, ~st, rest, h <> t), P.row_head(P.match_rows(~eq, ~st, rest, h <> t)) <> P.match_rows(~eq, ~st, rest, t), rows_cons_t(~eq, ~st, rest, h, t)) : {P.row_one(~eq, ~st, P.Static{raw}, List.is_empty(&2, P.Segment, rest), h <> t, _, below_t(~eq, ~st, P.Static{raw}, rest, h <> t)) == P.match_with(~eq, ~st, P.Static{raw} <> rest, h <> t) : Maybe<&2, P.Params>}
      Equal.cong(Maybe<&2, P.Params>, Maybe<&2, P.Params>, r => E.choose(Maybe<&2, P.Params>, eq(raw, h), u => r, u => None{}), P.row_head(P.match_rows(~eq, ~st, rest, t)), P.match_with(~eq, ~st, rest, t), search_equal_t(~eq, ~st, rest, t))
    case P.Static{raw} <> rest Nil{}:
      {==}
    case P.Capture{+name, +c, True{}} <> +rest Nil{}:
      search_equal_t(~eq, ~st, rest, Nil{})
    case P.Capture{name, c, False{}} <> rest Nil{}:
      {==}
    case P.Capture{+name, +c, +optional} <> +rest +h <> +t:
      %Equal.sym(Maybe<&2, P.Params>, P.row_head(P.match_rows(~eq, ~st, P.Capture{name, c, optional} <> rest, h <> t)), P.row_one(~eq, ~st, P.Capture{name, c, optional}, List.is_empty(&2, P.Segment, rest), h <> t, P.match_rows(~eq, ~st, rest, h <> t), below_t(~eq, ~st, P.Capture{name, c, optional}, rest, h <> t)), rows_head_t(~eq, ~st, P.Capture{name, c, optional}, rest, h <> t)) : {_ == P.match_with(~eq, ~st, P.Capture{name, c, optional} <> rest, h <> t) : Maybe<&2, P.Params>}
      %Equal.sym(Core.Rows, P.match_rows(~eq, ~st, rest, h <> t), P.row_head(P.match_rows(~eq, ~st, rest, h <> t)) <> P.match_rows(~eq, ~st, rest, t), rows_cons_t(~eq, ~st, rest, h, t)) : {P.row_one(~eq, ~st, P.Capture{name, c, optional}, List.is_empty(&2, P.Segment, rest), h <> t, _, below_t(~eq, ~st, P.Capture{name, c, optional}, rest, h <> t)) == P.match_with(~eq, ~st, P.Capture{name, c, optional} <> rest, h <> t) : Maybe<&2, P.Params>}
      Equal.cong(Maybe<&2, P.Params>, Maybe<&2, P.Params>, r => Maybe.bind(&2, String, P.Params, E.decode(h), +value => E.choose(Maybe<&2, P.Params>, P.value_ok(c, value), u => P.put_capture(name, value, r), u => None{})), P.row_head(P.match_rows(~eq, ~st, rest, t)), P.match_with(~eq, ~st, rest, t), search_equal_t(~eq, ~st, rest, t))
    case P.Wildcard{+name} <> Nil{} +p:
      wildcard_search_t(~eq, ~st, name, p)
    case P.Wildcard{name} <> h <> t p:
      {==}
    case P.InteriorWildcard{} <> rest p:
      {==}
    case P.PrefixWildcard{prefix} <> rest p:
      {==}
    case P.Span{+name} <> +rest +p:
      rows_head_t(~eq, ~st, P.Span{name}, rest, p)

# ---- Case-insensitive matching is the folded specification ----

# Span cells are scanned with the accumulated raw prefix; other heads match directly.
def lhs_f(+segs: List<&2, P.Segment>, +paths: List<&2, String>, +taken: List<&2, String>) -> Maybe<&2, P.Params>:
  match segs:
    case P.Span{name} <> rest:
      P.span_scan(paths, P.match_rows(~M.folded_equal, ~M.folded_starts, rest, paths), name, taken)
    case _:
      P.match_with(~M.folded_equal, ~M.folded_starts, segs, paths)

def lhs_f_nil(+segs: List<&2, P.Segment>, +paths: List<&2, String>) ->
    {lhs_f(segs, paths, Nil{}) == P.match_with(~M.folded_equal, ~M.folded_starts, segs, paths) : Maybe<&2, P.Params>}:
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

def capture_f(+name: String, +c: C.Constraint, +optional: Bool, +rest: List<&2, P.Segment>, +h: String, +t: List<&2, String>,
    inner: {P.match_with(~M.folded_equal, ~M.folded_starts, rest, t) == S.folded(rest, t, Nil{}) : Maybe<&2, P.Params>}) ->
    {P.match_with(~M.folded_equal, ~M.folded_starts, P.Capture{name, c, optional} <> rest, h <> t) == MS.capture(name, c, E.decode(h), S.folded(rest, t, Nil{})) : Maybe<&2, P.Params>}:
  match optional:
    case True{}:
      %Equal.sym(Maybe<&2, P.Params>, P.match_with(~M.folded_equal, ~M.folded_starts, rest, t), S.folded(rest, t, Nil{}), inner) : {Maybe.bind(&2, String, P.Params, E.decode(h), +v => E.choose(Maybe<&2, P.Params>, P.value_ok(c, v), u => P.put_capture(name, v, _), u => None{})) == MS.capture(name, c, E.decode(h), S.folded(rest, t, Nil{})) : Maybe<&2, P.Params>}
      MSP.capture_eq(name, c, E.decode(h), S.folded(rest, t, Nil{}))
    case False{}:
      %Equal.sym(Maybe<&2, P.Params>, P.match_with(~M.folded_equal, ~M.folded_starts, rest, t), S.folded(rest, t, Nil{}), inner) : {Maybe.bind(&2, String, P.Params, E.decode(h), +v => E.choose(Maybe<&2, P.Params>, P.value_ok(c, v), u => P.put_capture(name, v, _), u => None{})) == MS.capture(name, c, E.decode(h), S.folded(rest, t, Nil{})) : Maybe<&2, P.Params>}
      MSP.capture_eq(name, c, E.decode(h), S.folded(rest, t, Nil{}))

law folded_spec:
  for +segs: List<&2, P.Segment>
  for +paths: List<&2, String>
  for +taken: List<&2, String>
  {lhs_f(segs, paths, taken) == S.folded(segs, paths, taken) : Maybe<&2, P.Params>}

def folded_spec(segs, paths, taken):
  match segs paths:
    case Nil{} Nil{}:
      {==}
    case Nil{} h <> t:
      {==}
    case P.Static{raw} <> rest Nil{}:
      {==}
    case P.Static{+raw} <> +rest +h <> +t:
      %equal_same(raw, h) : {P.match_with(~M.folded_equal, ~M.folded_starts, P.Static{raw} <> rest, h <> t) == MS.same_text(_, S.folded(rest, t, Nil{})) : Maybe<&2, P.Params>}
      %Equal.sym(Maybe<&2, P.Params>, P.match_with(~M.folded_equal, ~M.folded_starts, rest, t), S.folded(rest, t, Nil{}), Equal.trans(Maybe<&2, P.Params>, P.match_with(~M.folded_equal, ~M.folded_starts, rest, t), lhs_f(rest, t, Nil{}), S.folded(rest, t, Nil{}), Equal.sym(Maybe<&2, P.Params>, lhs_f(rest, t, Nil{}), P.match_with(~M.folded_equal, ~M.folded_starts, rest, t), lhs_f_nil(rest, t)), folded_spec(rest, t, Nil{}))) : {E.choose(Maybe<&2, P.Params>, M.folded_equal(raw, h), u => _, u => None{}) == MS.same_text(M.folded_equal(raw, h), S.folded(rest, t, Nil{})) : Maybe<&2, P.Params>}
      MSP.choose_same(M.folded_equal(raw, h), S.folded(rest, t, Nil{}))
    case P.Capture{name, c, True{}} <> +rest Nil{}:
      Equal.trans(Maybe<&2, P.Params>, P.match_with(~M.folded_equal, ~M.folded_starts, rest, Nil{}), lhs_f(rest, Nil{}, Nil{}), S.folded(rest, Nil{}, Nil{}), Equal.sym(Maybe<&2, P.Params>, lhs_f(rest, Nil{}, Nil{}), P.match_with(~M.folded_equal, ~M.folded_starts, rest, Nil{}), lhs_f_nil(rest, Nil{})), folded_spec(rest, Nil{}, Nil{}))
    case P.Capture{name, c, False{}} <> rest Nil{}:
      {==}
    case P.Capture{+name, +c, +optional} <> +rest +h <> +t:
      capture_f(name, c, optional, rest, h, t, Equal.trans(Maybe<&2, P.Params>, P.match_with(~M.folded_equal, ~M.folded_starts, rest, t), lhs_f(rest, t, Nil{}), S.folded(rest, t, Nil{}), Equal.sym(Maybe<&2, P.Params>, lhs_f(rest, t, Nil{}), P.match_with(~M.folded_equal, ~M.folded_starts, rest, t), lhs_f_nil(rest, t)), folded_spec(rest, t, Nil{})))
    case P.Wildcard{+name} <> Nil{} +ps:
      %Equal.sym(Maybe<&2, String>, P.decode_segments(ps), MSP.joined(MS.decoded_all(ps)), MSP.decode_eq(ps)) : {P.wildcard_param(name, _) == MS.wildcard(name, MS.decoded_all(ps)) : Maybe<&2, P.Params>}
      MSP.wildcard_eq(name, MS.decoded_all(ps))
    case P.Wildcard{name} <> h <> t Nil{}:
      {==}
    case P.Wildcard{+name} <> +h <> +t +x <> +y:
      rows_head_t(~M.folded_equal, ~M.folded_starts, P.Wildcard{name}, h <> t, x <> y)
    case P.InteriorWildcard{} <> +rest Nil{}:
      Equal.trans(Maybe<&2, P.Params>, P.prefer(P.row_head(P.match_rows(~M.folded_equal, ~M.folded_starts, rest, Nil{})), u => None{}), P.row_head(P.match_rows(~M.folded_equal, ~M.folded_starts, rest, Nil{})), S.folded(rest, Nil{}, Nil{}), MSP.prefer_none(P.row_head(P.match_rows(~M.folded_equal, ~M.folded_starts, rest, Nil{}))), Equal.trans(Maybe<&2, P.Params>, P.row_head(P.match_rows(~M.folded_equal, ~M.folded_starts, rest, Nil{})), P.match_with(~M.folded_equal, ~M.folded_starts, rest, Nil{}), S.folded(rest, Nil{}, Nil{}), search_equal_t(~M.folded_equal, ~M.folded_starts, rest, Nil{}), Equal.trans(Maybe<&2, P.Params>, P.match_with(~M.folded_equal, ~M.folded_starts, rest, Nil{}), lhs_f(rest, Nil{}, Nil{}), S.folded(rest, Nil{}, Nil{}), Equal.sym(Maybe<&2, P.Params>, lhs_f(rest, Nil{}, Nil{}), P.match_with(~M.folded_equal, ~M.folded_starts, rest, Nil{}), lhs_f_nil(rest, Nil{})), folded_spec(rest, Nil{}, Nil{}))))
    case P.InteriorWildcard{} <> +rest +h <> +t:
      %Equal.sym(Maybe<&2, P.Params>, P.row_head(P.match_rows(~M.folded_equal, ~M.folded_starts, P.InteriorWildcard{} <> rest, h <> t)), P.row_one(~M.folded_equal, ~M.folded_starts, P.InteriorWildcard{}, List.is_empty(&2, P.Segment, rest), h <> t, P.match_rows(~M.folded_equal, ~M.folded_starts, rest, h <> t), below_t(~M.folded_equal, ~M.folded_starts, P.InteriorWildcard{}, rest, h <> t)), rows_head_t(~M.folded_equal, ~M.folded_starts, P.InteriorWildcard{}, rest, h <> t)) : {_ == MS.or_else(S.folded(rest, h <> t, Nil{}), u => S.folded(P.InteriorWildcard{} <> rest, t, Nil{})) : Maybe<&2, P.Params>}
      %Equal.sym(Maybe<&2, P.Params>, P.row_head(P.match_rows(~M.folded_equal, ~M.folded_starts, rest, h <> t)), S.folded(rest, h <> t, Nil{}), Equal.trans(Maybe<&2, P.Params>, P.row_head(P.match_rows(~M.folded_equal, ~M.folded_starts, rest, h <> t)), P.match_with(~M.folded_equal, ~M.folded_starts, rest, h <> t), S.folded(rest, h <> t, Nil{}), search_equal_t(~M.folded_equal, ~M.folded_starts, rest, h <> t), Equal.trans(Maybe<&2, P.Params>, P.match_with(~M.folded_equal, ~M.folded_starts, rest, h <> t), lhs_f(rest, h <> t, Nil{}), S.folded(rest, h <> t, Nil{}), Equal.sym(Maybe<&2, P.Params>, lhs_f(rest, h <> t, Nil{}), P.match_with(~M.folded_equal, ~M.folded_starts, rest, h <> t), lhs_f_nil(rest, h <> t)), folded_spec(rest, h <> t, Nil{})))) : {P.prefer(_, u => P.row_head(P.match_rows(~M.folded_equal, ~M.folded_starts, P.InteriorWildcard{} <> rest, t))) == MS.or_else(S.folded(rest, h <> t, Nil{}), u => S.folded(P.InteriorWildcard{} <> rest, t, Nil{})) : Maybe<&2, P.Params>}
      %Equal.sym(Maybe<&2, P.Params>, lhs_f(P.InteriorWildcard{} <> rest, t, Nil{}), S.folded(P.InteriorWildcard{} <> rest, t, Nil{}), folded_spec(P.InteriorWildcard{} <> rest, t, Nil{})) : {P.prefer(S.folded(rest, h <> t, Nil{}), u => _) == MS.or_else(S.folded(rest, h <> t, Nil{}), u => S.folded(P.InteriorWildcard{} <> rest, t, Nil{})) : Maybe<&2, P.Params>}
      MSP.prefer_or_else(S.folded(rest, h <> t, Nil{}), S.folded(P.InteriorWildcard{} <> rest, t, Nil{}))
    case P.PrefixWildcard{+prefix} <> Nil{} +h <> +t:
      %starts_same(h, prefix) : {P.match_with(~M.folded_equal, ~M.folded_starts, [P.PrefixWildcard{prefix}], h <> t) == MS.prefix_hit(_) : Maybe<&2, P.Params>}
      %Equal.sym(Maybe<&2, P.Params>, P.row_head(P.match_rows(~M.folded_equal, ~M.folded_starts, [P.PrefixWildcard{prefix}], h <> t)), P.row_one(~M.folded_equal, ~M.folded_starts, P.PrefixWildcard{prefix}, True{}, h <> t, P.match_rows(~M.folded_equal, ~M.folded_starts, Nil{}, h <> t), below_t(~M.folded_equal, ~M.folded_starts, P.PrefixWildcard{prefix}, Nil{}, h <> t)), rows_head_t(~M.folded_equal, ~M.folded_starts, P.PrefixWildcard{prefix}, Nil{}, h <> t)) : {_ == MS.prefix_hit(M.folded_starts(h, prefix)) : Maybe<&2, P.Params>}
      MSP.hit_eq(M.folded_starts(h, prefix))
    case P.PrefixWildcard{prefix} <> Nil{} Nil{}:
      {==}
    case P.PrefixWildcard{prefix} <> a <> b Nil{}:
      {==}
    case P.PrefixWildcard{+prefix} <> +a <> +b +h <> +t:
      %Equal.sym(Maybe<&2, P.Params>, P.row_head(P.match_rows(~M.folded_equal, ~M.folded_starts, P.PrefixWildcard{prefix} <> a <> b, h <> t)), P.row_one(~M.folded_equal, ~M.folded_starts, P.PrefixWildcard{prefix}, False{}, h <> t, P.match_rows(~M.folded_equal, ~M.folded_starts, a <> b, h <> t), below_t(~M.folded_equal, ~M.folded_starts, P.PrefixWildcard{prefix}, a <> b, h <> t)), rows_head_t(~M.folded_equal, ~M.folded_starts, P.PrefixWildcard{prefix}, a <> b, h <> t)) : {_ == None{} : Maybe<&2, P.Params>}
      {==}
    case P.Span{name} <> rest Nil{}:
      {==}
    case P.Span{+name} <> +rest +h <> +t:
      %Equal.sym(Core.Rows, P.match_rows(~M.folded_equal, ~M.folded_starts, rest, h <> t), P.row_head(P.match_rows(~M.folded_equal, ~M.folded_starts, rest, h <> t)) <> P.match_rows(~M.folded_equal, ~M.folded_starts, rest, t), rows_cons_t(~M.folded_equal, ~M.folded_starts, rest, h, t)) : {P.span_scan(h <> t, _, name, taken) == MS.or_else(S.folded(P.Span{name} <> rest, t, h <> taken), u => MS.span_here(name, h <> taken, S.folded(rest, t, Nil{}))) : Maybe<&2, P.Params>}
      %PS.span_scan_cons(h, t, P.row_head(P.match_rows(~M.folded_equal, ~M.folded_starts, rest, h <> t)), P.match_rows(~M.folded_equal, ~M.folded_starts, rest, t), name, taken) : {_ == MS.or_else(S.folded(P.Span{name} <> rest, t, h <> taken), u => MS.span_here(name, h <> taken, S.folded(rest, t, Nil{}))) : Maybe<&2, P.Params>}
      %Equal.sym(Maybe<&2, P.Params>, lhs_f(P.Span{name} <> rest, t, h <> taken), S.folded(P.Span{name} <> rest, t, h <> taken), folded_spec(P.Span{name} <> rest, t, h <> taken)) : {P.prefer(_, u => P.span_value(name, h <> taken, P.row_head(P.match_rows(~M.folded_equal, ~M.folded_starts, rest, t)))) == MS.or_else(S.folded(P.Span{name} <> rest, t, h <> taken), u => MS.span_here(name, h <> taken, S.folded(rest, t, Nil{}))) : Maybe<&2, P.Params>}
      %Equal.sym(Maybe<&2, P.Params>, P.row_head(P.match_rows(~M.folded_equal, ~M.folded_starts, rest, t)), S.folded(rest, t, Nil{}), Equal.trans(Maybe<&2, P.Params>, P.row_head(P.match_rows(~M.folded_equal, ~M.folded_starts, rest, t)), P.match_with(~M.folded_equal, ~M.folded_starts, rest, t), S.folded(rest, t, Nil{}), search_equal_t(~M.folded_equal, ~M.folded_starts, rest, t), Equal.trans(Maybe<&2, P.Params>, P.match_with(~M.folded_equal, ~M.folded_starts, rest, t), lhs_f(rest, t, Nil{}), S.folded(rest, t, Nil{}), Equal.sym(Maybe<&2, P.Params>, lhs_f(rest, t, Nil{}), P.match_with(~M.folded_equal, ~M.folded_starts, rest, t), lhs_f_nil(rest, t)), folded_spec(rest, t, Nil{})))) : {P.prefer(S.folded(P.Span{name} <> rest, t, h <> taken), u => P.span_value(name, h <> taken, _)) == MS.or_else(S.folded(P.Span{name} <> rest, t, h <> taken), u => MS.span_here(name, h <> taken, S.folded(rest, t, Nil{}))) : Maybe<&2, P.Params>}
      %Equal.sym(Maybe<&2, P.Params>, P.span_value(name, h <> taken, S.folded(rest, t, Nil{})), MS.span_here(name, h <> taken, S.folded(rest, t, Nil{})), MSP.span_eq(name, h <> taken, S.folded(rest, t, Nil{}))) : {P.prefer(S.folded(P.Span{name} <> rest, t, h <> taken), u => _) == MS.or_else(S.folded(P.Span{name} <> rest, t, h <> taken), u => MS.span_here(name, h <> taken, S.folded(rest, t, Nil{}))) : Maybe<&2, P.Params>}
      MSP.prefer_or_else(S.folded(P.Span{name} <> rest, t, h <> taken), MS.span_here(name, h <> taken, S.folded(rest, t, Nil{})))

def with_folded(+segs: List<&2, P.Segment>, +paths: List<&2, String>) ->
    {P.match_with(~M.folded_equal, ~M.folded_starts, segs, paths) == S.folded(segs, paths, Nil{}) : Maybe<&2, P.Params>}:
  Equal.trans(Maybe<&2, P.Params>, P.match_with(~M.folded_equal, ~M.folded_starts, segs, paths), lhs_f(segs, paths, Nil{}), S.folded(segs, paths, Nil{}), Equal.sym(Maybe<&2, P.Params>, lhs_f(segs, paths, Nil{}), P.match_with(~M.folded_equal, ~M.folded_starts, segs, paths), lhs_f_nil(segs, paths)), folded_spec(segs, paths, Nil{}))


# ---- Generic list facts ----

def rev_onto(-A: Data, +t: List<&2, A>, +b: List<&2, A>, +acc: List<&2, A>) ->
    {List.reverse.go(&2, A, t, List.append(&2, A, b, acc)) == List.append(&2, A, List.reverse.go(&2, A, t, b), acc) : List<&2, A>}:
  match t:
    case Nil{}:
      {==}
    case +x <> +u:
      rev_onto(A, u, x <> b, acc)

def rev_append(-A: Data, +l: List<&2, A>, +ys: List<&2, A>, +acc: List<&2, A>) ->
    {List.reverse.go(&2, A, List.append(&2, A, l, ys), acc) == List.reverse.go(&2, A, ys, List.reverse.go(&2, A, l, acc)) : List<&2, A>}:
  match l:
    case Nil{}:
      {==}
    case +x <> +m:
      rev_append(A, m, ys, x <> acc)

# Reversing a cons, as an append.
def rev_cons(-A: Data, +h: A, +t: List<&2, A>) ->
    {List.reverse(&2, A, h <> t) == List.append(&2, A, List.reverse(&2, A, t), [h]) : List<&2, A>}:
  rev_onto(A, t, Nil{}, [h])

def rev_rev(-A: Data, +xs: List<&2, A>) -> {List.reverse(&2, A, List.reverse(&2, A, xs)) == xs : List<&2, A>}:
  match xs:
    case Nil{}:
      {==}
    case +h <> +t:
      %Equal.sym(List<&2, A>, List.reverse(&2, A, h <> t), List.append(&2, A, List.reverse(&2, A, t), [h]), rev_cons(A, h, t)) : {List.reverse(&2, A, _) == h <> t : List<&2, A>}
      Equal.trans(List<&2, A>, List.reverse.go(&2, A, List.append(&2, A, List.reverse(&2, A, t), [h]), Nil{}), h <> List.reverse(&2, A, List.reverse(&2, A, t)), h <> t, rev_append(A, List.reverse(&2, A, t), [h], Nil{}), Equal.cong(List<&2, A>, List<&2, A>, r => h <> r, List.reverse(&2, A, List.reverse(&2, A, t)), t, rev_rev(A, t)))

def is_cons(-A: Data, xs: List<&2, A>) -> Type:
  match xs:
    case Nil{}:
      Empty
    case h <> t:
      Unit

def nil_cons(-A: Data, +h: A, +t: List<&2, A>, e: {h <> t == Nil{} : List<&2, A>}) -> Empty:
  %e : is_cons(A, _)
  Unit{}

# ---- Lenient trailing slashes on request segments ----

def skip_text(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case SNil{} <> t:
      skip_text(t)
    case SCon{a, b} <> t:
      SCon{a, b} <> t

def trim_skip(+r: List<&2, String>) -> {M.trim_segments(r) == S.root_text(skip_text(r)) : List<&2, String>}:
  match r:
    case Nil{}:
      {==}
    case SNil{} <> +t:
      trim_skip(t)
    case SCon{a, b} <> t:
      {==}

def skip_after(k: List<&2, String>, ys: List<&2, String>) -> List<&2, String>:
  match k:
    case Nil{}:
      skip_text(ys)
    case z <> zs:
      List.append(&2, String, z <> zs, ys)

def skip_append(+r: List<&2, String>, +ys: List<&2, String>) -> {skip_text(List.append(&2, String, r, ys)) == skip_after(skip_text(r), ys) : List<&2, String>}:
  match r:
    case Nil{}:
      {==}
    case SNil{} <> +t:
      skip_append(t, ys)
    case SCon{a, b} <> t:
      {==}

def keep_rev(+zs: List<&2, String>, +z: String, +acc: List<&2, String>, +h: String) ->
    {S.keep_text(List.reverse.go(&2, String, zs, z <> acc), h) == h <> List.reverse.go(&2, String, zs, z <> acc) : List<&2, String>}:
  match zs:
    case Nil{}:
      {==}
    case +y <> +u:
      keep_rev(u, y, z <> acc, h)

def drop_step(+k: List<&2, String>, +h: String, +d: List<&2, String>, ih: {List.reverse(&2, String, k) == d : List<&2, String>}) ->
    {List.reverse(&2, String, skip_after(k, [h])) == S.keep_text(d, h) : List<&2, String>}:
  match k:
    case Nil{}:
      match h:
        case SNil{}:
          %ih : {List.reverse(&2, String, skip_after(Nil{}, [""])) == S.keep_text(_, "") : List<&2, String>}
          {==}
        case SCon{+x, +y}:
          %ih : {List.reverse(&2, String, skip_after(Nil{}, [SCon{x, y}])) == S.keep_text(_, SCon{x, y}) : List<&2, String>}
          {==}
    case +z <> +zs:
      %ih : {List.reverse(&2, String, skip_after(z <> zs, [h])) == S.keep_text(_, h) : List<&2, String>}
      Equal.trans(List<&2, String>, List.reverse.go(&2, String, List.append(&2, String, z <> zs, [h]), Nil{}), h <> List.reverse(&2, String, z <> zs), S.keep_text(List.reverse(&2, String, z <> zs), h), rev_append(String, z <> zs, [h], Nil{}), Equal.sym(List<&2, String>, S.keep_text(List.reverse(&2, String, z <> zs), h), h <> List.reverse(&2, String, z <> zs), keep_rev(zs, z, Nil{}, h)))

# Removing terminal empty segments from the right is skipping them from the
# left of the reversed list.
def drop_rev(+xs: List<&2, String>) -> {List.reverse(&2, String, skip_text(List.reverse(&2, String, xs))) == S.drop_empty(xs) : List<&2, String>}:
  match xs:
    case Nil{}:
      {==}
    case +h <> +t:
      %Equal.sym(List<&2, String>, List.reverse(&2, String, h <> t), List.append(&2, String, List.reverse(&2, String, t), [h]), rev_cons(String, h, t)) : {List.reverse(&2, String, skip_text(_)) == S.drop_empty(h <> t) : List<&2, String>}
      %Equal.sym(List<&2, String>, skip_text(List.append(&2, String, List.reverse(&2, String, t), [h])), skip_after(skip_text(List.reverse(&2, String, t)), [h]), skip_append(List.reverse(&2, String, t), [h])) : {List.reverse(&2, String, _) == S.drop_empty(h <> t) : List<&2, String>}
      drop_step(skip_text(List.reverse(&2, String, t)), h, S.drop_empty(t), drop_rev(t))

def root_rev(+t: List<&2, String>, +h: String, +acc: List<&2, String>) ->
    {S.root_text(List.reverse.go(&2, String, t, h <> acc)) == List.reverse.go(&2, String, t, h <> acc) : List<&2, String>}:
  match t:
    case Nil{}:
      {==}
    case +y <> +u:
      root_rev(u, y, h <> acc)

def rev_root(+l: List<&2, String>) -> {List.reverse(&2, String, S.root_text(l)) == S.root_text(List.reverse(&2, String, l)) : List<&2, String>}:
  match l:
    case Nil{}:
      {==}
    case +h <> +t:
      Equal.sym(List<&2, String>, S.root_text(List.reverse.go(&2, String, t, h <> Nil{})), List.reverse.go(&2, String, t, h <> Nil{}), root_rev(t, h, Nil{}))

def path_lenient(+xs: List<&2, String>) -> {List.reverse(&2, String, M.trim_segments(List.reverse(&2, String, xs))) == S.root_text(S.drop_empty(xs)) : List<&2, String>}:
  %Equal.sym(List<&2, String>, M.trim_segments(List.reverse(&2, String, xs)), S.root_text(skip_text(List.reverse(&2, String, xs))), trim_skip(List.reverse(&2, String, xs))) : {List.reverse(&2, String, _) == S.root_text(S.drop_empty(xs)) : List<&2, String>}
  %drop_rev(xs) : {List.reverse(&2, String, S.root_text(skip_text(List.reverse(&2, String, xs)))) == S.root_text(_) : List<&2, String>}
  rev_root(skip_text(List.reverse(&2, String, xs)))

def path_normal(+xs: List<&2, String>, +strict: Bool) -> {M.slash_segments(xs, strict) == S.normal_path(strict, xs) : List<&2, String>}:
  match strict:
    case True{}:
      {==}
    case False{}:
      path_lenient(xs)

# ---- Lenient trailing slashes on pattern segments ----

def skip_seg(xs: List<&2, P.Segment>) -> List<&2, P.Segment>:
  match xs:
    case Nil{}:
      Nil{}
    case P.Static{SNil{}} <> t:
      skip_seg(t)
    case s <> t:
      s <> t

def trim_skip_seg(+r: List<&2, P.Segment>) -> {M.trim_pattern_rev(r) == S.root_segment(skip_seg(r)) : List<&2, P.Segment>}:
  match r:
    case Nil{}:
      {==}
    case P.Static{SNil{}} <> +t:
      trim_skip_seg(t)
    case P.Static{SCon{a, b}} <> t:
      {==}
    case P.Capture{n, c, o} <> t:
      {==}
    case P.Wildcard{n} <> t:
      {==}
    case P.InteriorWildcard{} <> t:
      {==}
    case P.PrefixWildcard{x} <> t:
      {==}
    case P.Span{n} <> t:
      {==}

def skip_after_seg(k: List<&2, P.Segment>, ys: List<&2, P.Segment>) -> List<&2, P.Segment>:
  match k:
    case Nil{}:
      skip_seg(ys)
    case z <> zs:
      List.append(&2, P.Segment, z <> zs, ys)

def skip_append_seg(+r: List<&2, P.Segment>, +ys: List<&2, P.Segment>) -> {skip_seg(List.append(&2, P.Segment, r, ys)) == skip_after_seg(skip_seg(r), ys) : List<&2, P.Segment>}:
  match r:
    case Nil{}:
      {==}
    case P.Static{SNil{}} <> +t:
      skip_append_seg(t, ys)
    case P.Static{SCon{a, b}} <> t:
      {==}
    case P.Capture{n, c, o} <> t:
      {==}
    case P.Wildcard{n} <> t:
      {==}
    case P.InteriorWildcard{} <> t:
      {==}
    case P.PrefixWildcard{x} <> t:
      {==}
    case P.Span{n} <> t:
      {==}

def keep_rev_seg(+zs: List<&2, P.Segment>, +z: P.Segment, +acc: List<&2, P.Segment>, +h: P.Segment) ->
    {S.keep_segment(List.reverse.go(&2, P.Segment, zs, z <> acc), h) == h <> List.reverse.go(&2, P.Segment, zs, z <> acc) : List<&2, P.Segment>}:
  match zs:
    case Nil{}:
      {==}
    case +y <> +u:
      keep_rev_seg(u, y, z <> acc, h)

def drop_step_seg(+k: List<&2, P.Segment>, +h: P.Segment, +d: List<&2, P.Segment>, ih: {List.reverse(&2, P.Segment, k) == d : List<&2, P.Segment>}) ->
    {List.reverse(&2, P.Segment, skip_after_seg(k, [h])) == S.keep_segment(d, h) : List<&2, P.Segment>}:
  match k:
    case Nil{}:
      match h:
        case P.Static{SNil{}}:
          %ih : {List.reverse(&2, P.Segment, skip_after_seg(Nil{}, [P.Static{""}])) == S.keep_segment(_, P.Static{""}) : List<&2, P.Segment>}
          {==}
        case P.Static{SCon{+a, +b}}:
          %ih : {List.reverse(&2, P.Segment, skip_after_seg(Nil{}, [P.Static{SCon{a, b}}])) == S.keep_segment(_, P.Static{SCon{a, b}}) : List<&2, P.Segment>}
          {==}
        case P.Capture{+n, +c, +o}:
          %ih : {List.reverse(&2, P.Segment, skip_after_seg(Nil{}, [P.Capture{n, c, o}])) == S.keep_segment(_, P.Capture{n, c, o}) : List<&2, P.Segment>}
          {==}
        case P.Wildcard{+n}:
          %ih : {List.reverse(&2, P.Segment, skip_after_seg(Nil{}, [P.Wildcard{n}])) == S.keep_segment(_, P.Wildcard{n}) : List<&2, P.Segment>}
          {==}
        case P.InteriorWildcard{}:
          %ih : {List.reverse(&2, P.Segment, skip_after_seg(Nil{}, [P.InteriorWildcard{}])) == S.keep_segment(_, P.InteriorWildcard{}) : List<&2, P.Segment>}
          {==}
        case P.PrefixWildcard{+x}:
          %ih : {List.reverse(&2, P.Segment, skip_after_seg(Nil{}, [P.PrefixWildcard{x}])) == S.keep_segment(_, P.PrefixWildcard{x}) : List<&2, P.Segment>}
          {==}
        case P.Span{+n}:
          %ih : {List.reverse(&2, P.Segment, skip_after_seg(Nil{}, [P.Span{n}])) == S.keep_segment(_, P.Span{n}) : List<&2, P.Segment>}
          {==}
    case +z <> +zs:
      %ih : {List.reverse(&2, P.Segment, skip_after_seg(z <> zs, [h])) == S.keep_segment(_, h) : List<&2, P.Segment>}
      Equal.trans(List<&2, P.Segment>, List.reverse.go(&2, P.Segment, List.append(&2, P.Segment, z <> zs, [h]), Nil{}), h <> List.reverse(&2, P.Segment, z <> zs), S.keep_segment(List.reverse(&2, P.Segment, z <> zs), h), rev_append(P.Segment, z <> zs, [h], Nil{}), Equal.sym(List<&2, P.Segment>, S.keep_segment(List.reverse(&2, P.Segment, z <> zs), h), h <> List.reverse(&2, P.Segment, z <> zs), keep_rev_seg(zs, z, Nil{}, h)))

def drop_rev_seg(+xs: List<&2, P.Segment>) -> {List.reverse(&2, P.Segment, skip_seg(List.reverse(&2, P.Segment, xs))) == S.drop_static(xs) : List<&2, P.Segment>}:
  match xs:
    case Nil{}:
      {==}
    case +h <> +t:
      %Equal.sym(List<&2, P.Segment>, List.reverse(&2, P.Segment, h <> t), List.append(&2, P.Segment, List.reverse(&2, P.Segment, t), [h]), rev_cons(P.Segment, h, t)) : {List.reverse(&2, P.Segment, skip_seg(_)) == S.drop_static(h <> t) : List<&2, P.Segment>}
      %Equal.sym(List<&2, P.Segment>, skip_seg(List.append(&2, P.Segment, List.reverse(&2, P.Segment, t), [h])), skip_after_seg(skip_seg(List.reverse(&2, P.Segment, t)), [h]), skip_append_seg(List.reverse(&2, P.Segment, t), [h])) : {List.reverse(&2, P.Segment, _) == S.drop_static(h <> t) : List<&2, P.Segment>}
      drop_step_seg(skip_seg(List.reverse(&2, P.Segment, t)), h, S.drop_static(t), drop_rev_seg(t))

def root_rev_seg(+t: List<&2, P.Segment>, +h: P.Segment, +acc: List<&2, P.Segment>) ->
    {S.root_segment(List.reverse.go(&2, P.Segment, t, h <> acc)) == List.reverse.go(&2, P.Segment, t, h <> acc) : List<&2, P.Segment>}:
  match t:
    case Nil{}:
      {==}
    case +y <> +u:
      root_rev_seg(u, y, h <> acc)

def rev_root_seg(+l: List<&2, P.Segment>) -> {List.reverse(&2, P.Segment, S.root_segment(l)) == S.root_segment(List.reverse(&2, P.Segment, l)) : List<&2, P.Segment>}:
  match l:
    case Nil{}:
      {==}
    case +h <> +t:
      Equal.sym(List<&2, P.Segment>, S.root_segment(List.reverse.go(&2, P.Segment, t, h <> Nil{})), List.reverse.go(&2, P.Segment, t, h <> Nil{}), root_rev_seg(t, h, Nil{}))

def pattern_lenient(+xs: List<&2, P.Segment>) -> {List.reverse(&2, P.Segment, M.trim_pattern_rev(List.reverse(&2, P.Segment, xs))) == S.root_segment(S.drop_static(xs)) : List<&2, P.Segment>}:
  %Equal.sym(List<&2, P.Segment>, M.trim_pattern_rev(List.reverse(&2, P.Segment, xs)), S.root_segment(skip_seg(List.reverse(&2, P.Segment, xs))), trim_skip_seg(List.reverse(&2, P.Segment, xs))) : {List.reverse(&2, P.Segment, _) == S.root_segment(S.drop_static(xs)) : List<&2, P.Segment>}
  %drop_rev_seg(xs) : {List.reverse(&2, P.Segment, S.root_segment(skip_seg(List.reverse(&2, P.Segment, xs)))) == S.root_segment(_) : List<&2, P.Segment>}
  rev_root_seg(skip_seg(List.reverse(&2, P.Segment, xs)))

def pattern_normal(+segs: List<&2, P.Segment>, +strict: Bool) -> {M.slash_pattern(segs, strict) == S.normal_pattern(strict, segs) : List<&2, P.Segment>}:
  match strict:
    case True{}:
      {==}
    case False{}:
      pattern_lenient(segs)

# ---- The root path ----

def fin_ne(+h: Char, +r: List<&2, String>, +c: Bool, e: {String.split.fin(h, r, c) == Nil{} : List<&2, String>}) -> Empty:
  match r c:
    case Nil{} True{}:
      nil_cons(String, "", Nil{}, e)
    case Nil{} False{}:
      nil_cons(String, SCon{h, SNil{}}, Nil{}, e)
    case +x <> +y True{}:
      nil_cons(String, "", x <> y, e)
    case +x <> +y False{}:
      nil_cons(String, SCon{h, x}, y, e)

# Splitting never gives an empty list.
def split_ne(+s: String, e: {String.split(s, '/') == Nil{} : List<&2, String>}) -> Empty:
  match s:
    case SNil{}:
      nil_cons(String, "", Nil{}, e)
    case SCon{+h, +t}:
      fin_ne(h, String.split(t, '/'), Char.is_eq(h, '/'), e)

def root_fin(+a: Char, +r: List<&2, String>, +c: Bool, +segs: List<&2, P.Segment>, ne: {r == Nil{} : List<&2, String>} -> Empty) ->
    {S.root_hit(String.split.fin(a, r, c), segs) == None{} : Maybe<&2, P.Params>}:
  match r c:
    case Nil{} b:
      Core.absurd({S.root_hit(String.split.fin(a, Nil{}, b), segs) == None{} : Maybe<&2, P.Params>}, ne({==}))
    case x <> y True{}:
      {==}
    case x <> y False{}:
      {==}

# The BND-78 root rule reads the text after `/`; the option reading reads its
# segments. Only the empty text splits into the single empty segment.
def root_same(+j: String, +segs: List<&2, P.Segment>) -> {MS.root_rule(segs, j) == S.root_hit(String.split(j, '/'), segs) : Maybe<&2, P.Params>}:
  match j:
    case SNil{}:
      match segs:
        case Nil{}:
          {==}
        case P.Capture{+n, +c, True{}} <> +rest:
          {==}
        case P.Capture{+n, +c, False{}} <> +rest:
          {==}
        case P.Static{+raw} <> +rest:
          {==}
        case P.Wildcard{+n} <> +rest:
          {==}
        case P.InteriorWildcard{} <> +rest:
          {==}
        case P.PrefixWildcard{+x} <> +rest:
          {==}
        case P.Span{+n} <> +rest:
          {==}
    case SCon{+a, +b}:
      match segs:
        case Nil{}:
          Equal.sym(Maybe<&2, P.Params>, S.root_hit(String.split(SCon{a, b}, '/'), Nil{}), None{}, root_fin(a, String.split(b, '/'), Char.is_eq(a, '/'), Nil{}, e => split_ne(b, e)))
        case P.Capture{+n, +c, True{}} <> +rest:
          Equal.sym(Maybe<&2, P.Params>, S.root_hit(String.split(SCon{a, b}, '/'), P.Capture{n, c, True{}} <> rest), None{}, root_fin(a, String.split(b, '/'), Char.is_eq(a, '/'), P.Capture{n, c, True{}} <> rest, e => split_ne(b, e)))
        case P.Capture{+n, +c, False{}} <> +rest:
          Equal.sym(Maybe<&2, P.Params>, S.root_hit(String.split(SCon{a, b}, '/'), P.Capture{n, c, False{}} <> rest), None{}, root_fin(a, String.split(b, '/'), Char.is_eq(a, '/'), P.Capture{n, c, False{}} <> rest, e => split_ne(b, e)))
        case P.Static{+raw} <> +rest:
          Equal.sym(Maybe<&2, P.Params>, S.root_hit(String.split(SCon{a, b}, '/'), P.Static{raw} <> rest), None{}, root_fin(a, String.split(b, '/'), Char.is_eq(a, '/'), P.Static{raw} <> rest, e => split_ne(b, e)))
        case P.Wildcard{+n} <> +rest:
          Equal.sym(Maybe<&2, P.Params>, S.root_hit(String.split(SCon{a, b}, '/'), P.Wildcard{n} <> rest), None{}, root_fin(a, String.split(b, '/'), Char.is_eq(a, '/'), P.Wildcard{n} <> rest, e => split_ne(b, e)))
        case P.InteriorWildcard{} <> +rest:
          Equal.sym(Maybe<&2, P.Params>, S.root_hit(String.split(SCon{a, b}, '/'), P.InteriorWildcard{} <> rest), None{}, root_fin(a, String.split(b, '/'), Char.is_eq(a, '/'), P.InteriorWildcard{} <> rest, e => split_ne(b, e)))
        case P.PrefixWildcard{+x} <> +rest:
          Equal.sym(Maybe<&2, P.Params>, S.root_hit(String.split(SCon{a, b}, '/'), P.PrefixWildcard{x} <> rest), None{}, root_fin(a, String.split(b, '/'), Char.is_eq(a, '/'), P.PrefixWildcard{x} <> rest, e => split_ne(b, e)))
        case P.Span{+n} <> +rest:
          Equal.sym(Maybe<&2, P.Params>, S.root_hit(String.split(SCon{a, b}, '/'), P.Span{n} <> rest), None{}, root_fin(a, String.split(b, '/'), Char.is_eq(a, '/'), P.Span{n} <> rest, e => split_ne(b, e)))

# ---- Rejoining normalized request segments ----

def rejoin(+ys: List<&2, String>, ne: {ys == Nil{} : List<&2, String>} -> Empty, clean: {Core.clean_segments(ys) == True{} : Bool}) ->
    {String.split(String.join(ys, "/"), '/') == ys : List<&2, String>}:
  match ys:
    case Nil{}:
      Core.absurd({String.split(String.join(Nil{}, "/"), '/') == Nil{} : List<&2, String>}, ne({==}))
    case +h <> +t:
      Core.split_join_base(t, h, clean)

def clean_keep(+r: List<&2, String>, +h: String, cr: {Core.clean_segments(r) == True{} : Bool}, ch: {Core.no_slash(h) == True{} : Bool}) ->
    {Core.clean_segments(S.keep_text(r, h)) == True{} : Bool}:
  match r:
    case Nil{}:
      match h:
        case SNil{}:
          {==}
        case SCon{+x, +y}:
          %Equal.sym(Bool, Core.no_slash(SCon{x, y}), True{}, ch) : {_ && True{} == True{} : Bool}
          {==}
    case +x <> +y:
      %Equal.sym(Bool, Core.no_slash(h), True{}, ch) : {_ && Core.clean_segments(x <> y) == True{} : Bool}
      cr

def clean_drop(+xs: List<&2, String>, clean: {Core.clean_segments(xs) == True{} : Bool}) -> {Core.clean_segments(S.drop_empty(xs)) == True{} : Bool}:
  match xs:
    case Nil{}:
      {==}
    case +h <> +t:
      +e = clean
      clean_keep(S.drop_empty(t), h, clean_drop(t, Core.and_right(Core.no_slash(h), Core.clean_segments(t), e)), Core.and_left(Core.no_slash(h), Core.clean_segments(t), e))

def clean_root(+l: List<&2, String>, clean: {Core.clean_segments(l) == True{} : Bool}) -> {Core.clean_segments(S.root_text(l)) == True{} : Bool}:
  match l:
    case Nil{}:
      {==}
    case h <> t:
      clean

def clean_normal(+xs: List<&2, String>, +strict: Bool, clean: {Core.clean_segments(xs) == True{} : Bool}) -> {Core.clean_segments(S.normal_path(strict, xs)) == True{} : Bool}:
  match strict:
    case True{}:
      clean
    case False{}:
      clean_root(S.drop_empty(xs), clean_drop(xs, clean))

def root_ne(+l: List<&2, String>, e: {S.root_text(l) == Nil{} : List<&2, String>}) -> Empty:
  match l:
    case Nil{}:
      nil_cons(String, "", Nil{}, e)
    case +h <> +t:
      nil_cons(String, h, t, e)

def normal_ne(+t: String, +strict: Bool, e: {S.normal_path(strict, String.split(t, '/')) == Nil{} : List<&2, String>}) -> Empty:
  match strict:
    case True{}:
      split_ne(t, e)
    case False{}:
      root_ne(S.drop_empty(String.split(t, '/')), e)

# ---- Case-insensitive root handling ----

def rest_eq_f(+segs: List<&2, P.Segment>, +paths: List<&2, String>, +r: Maybe<&2, P.Params>, none: {r == None{} : Maybe<&2, P.Params>}) ->
    {P.match_with(~M.folded_equal, ~M.folded_starts, segs, paths) == MS.or_else(S.folded(segs, paths, Nil{}), u => r) : Maybe<&2, P.Params>}:
  %Equal.sym(Maybe<&2, P.Params>, r, None{}, none) : {P.match_with(~M.folded_equal, ~M.folded_starts, segs, paths) == MS.or_else(S.folded(segs, paths, Nil{}), u => _) : Maybe<&2, P.Params>}
  Equal.trans(Maybe<&2, P.Params>, P.match_with(~M.folded_equal, ~M.folded_starts, segs, paths), S.folded(segs, paths, Nil{}), MS.or_else(S.folded(segs, paths, Nil{}), u => None{}), with_folded(segs, paths), Equal.sym(Maybe<&2, P.Params>, MS.or_else(S.folded(segs, paths, Nil{}), u => None{}), S.folded(segs, paths, Nil{}), MSP.or_else_none(S.folded(segs, paths, Nil{}))))

def with_root_f(+segs: List<&2, P.Segment>, +j: String) ->
    {P.match_path_with(~M.folded_equal, ~M.folded_starts, P.Pattern{segs}, SCon{'/', j}) == MS.or_else(S.folded(segs, String.split(j, '/'), Nil{}), u => MS.root_rule(segs, j)) : Maybe<&2, P.Params>}:
  match segs j:
    case P.Capture{+n, +c, True{}} <> +rest SNil{}:
      %Equal.sym(Bool, P.all_optional(rest), MS.only_optional(rest), MSP.optional_same(rest)) : {E.choose(Maybe<&2, P.Params>, _, u => Some{Nil{}}, u => P.match_with(~M.folded_equal, ~M.folded_starts, P.Capture{n, c, True{}} <> rest, [""])) == MS.or_else(S.folded(P.Capture{n, c, True{}} <> rest, [""], Nil{}), u => MS.root_rule(P.Capture{n, c, True{}} <> rest, SNil{})) : Maybe<&2, P.Params>}
      MSP.root_choice(MS.only_optional(rest), P.match_with(~M.folded_equal, ~M.folded_starts, P.Capture{n, c, True{}} <> rest, [""]), with_folded(P.Capture{n, c, True{}} <> rest, [""]))
    case P.Capture{+n, +c, True{}} <> +rest SCon{+x, +y}:
      %PS.segments_equiv(SCon{x, y}) : {P.match_with(~M.folded_equal, ~M.folded_starts, P.Capture{n, c, True{}} <> rest, _) == MS.or_else(S.folded(P.Capture{n, c, True{}} <> rest, String.split(SCon{x, y}, '/'), Nil{}), u => MS.root_rule(P.Capture{n, c, True{}} <> rest, SCon{x, y})) : Maybe<&2, P.Params>}
      rest_eq_f(P.Capture{n, c, True{}} <> rest, String.split(SCon{x, y}, '/'), MS.root_rule(P.Capture{n, c, True{}} <> rest, SCon{x, y}), {==})
    case Nil{} +t:
      %PS.segments_equiv(t) : {P.match_with(~M.folded_equal, ~M.folded_starts, Nil{}, _) == MS.or_else(S.folded(Nil{}, String.split(t, '/'), Nil{}), u => MS.root_rule(Nil{}, t)) : Maybe<&2, P.Params>}
      rest_eq_f(Nil{}, String.split(t, '/'), MS.root_rule(Nil{}, t), {==})
    case P.Capture{+n, +c, False{}} <> +rest +t:
      %PS.segments_equiv(t) : {P.match_with(~M.folded_equal, ~M.folded_starts, P.Capture{n, c, False{}} <> rest, _) == MS.or_else(S.folded(P.Capture{n, c, False{}} <> rest, String.split(t, '/'), Nil{}), u => MS.root_rule(P.Capture{n, c, False{}} <> rest, t)) : Maybe<&2, P.Params>}
      rest_eq_f(P.Capture{n, c, False{}} <> rest, String.split(t, '/'), MS.root_rule(P.Capture{n, c, False{}} <> rest, t), {==})
    case P.Static{+raw} <> +rest +t:
      %PS.segments_equiv(t) : {P.match_with(~M.folded_equal, ~M.folded_starts, P.Static{raw} <> rest, _) == MS.or_else(S.folded(P.Static{raw} <> rest, String.split(t, '/'), Nil{}), u => MS.root_rule(P.Static{raw} <> rest, t)) : Maybe<&2, P.Params>}
      rest_eq_f(P.Static{raw} <> rest, String.split(t, '/'), MS.root_rule(P.Static{raw} <> rest, t), {==})
    case P.Wildcard{+n} <> +rest +t:
      %PS.segments_equiv(t) : {P.match_with(~M.folded_equal, ~M.folded_starts, P.Wildcard{n} <> rest, _) == MS.or_else(S.folded(P.Wildcard{n} <> rest, String.split(t, '/'), Nil{}), u => MS.root_rule(P.Wildcard{n} <> rest, t)) : Maybe<&2, P.Params>}
      rest_eq_f(P.Wildcard{n} <> rest, String.split(t, '/'), MS.root_rule(P.Wildcard{n} <> rest, t), {==})
    case P.InteriorWildcard{} <> +rest +t:
      %PS.segments_equiv(t) : {P.match_with(~M.folded_equal, ~M.folded_starts, P.InteriorWildcard{} <> rest, _) == MS.or_else(S.folded(P.InteriorWildcard{} <> rest, String.split(t, '/'), Nil{}), u => MS.root_rule(P.InteriorWildcard{} <> rest, t)) : Maybe<&2, P.Params>}
      rest_eq_f(P.InteriorWildcard{} <> rest, String.split(t, '/'), MS.root_rule(P.InteriorWildcard{} <> rest, t), {==})
    case P.PrefixWildcard{+x} <> +rest +t:
      %PS.segments_equiv(t) : {P.match_with(~M.folded_equal, ~M.folded_starts, P.PrefixWildcard{x} <> rest, _) == MS.or_else(S.folded(P.PrefixWildcard{x} <> rest, String.split(t, '/'), Nil{}), u => MS.root_rule(P.PrefixWildcard{x} <> rest, t)) : Maybe<&2, P.Params>}
      rest_eq_f(P.PrefixWildcard{x} <> rest, String.split(t, '/'), MS.root_rule(P.PrefixWildcard{x} <> rest, t), {==})
    case P.Span{+n} <> +rest +t:
      %PS.segments_equiv(t) : {P.match_with(~M.folded_equal, ~M.folded_starts, P.Span{n} <> rest, _) == MS.or_else(S.folded(P.Span{n} <> rest, String.split(t, '/'), Nil{}), u => MS.root_rule(P.Span{n} <> rest, t)) : Maybe<&2, P.Params>}
      rest_eq_f(P.Span{n} <> rest, String.split(t, '/'), MS.root_rule(P.Span{n} <> rest, t), {==})

# Comparing a rebuilt path: matching, then the root rule.
def compare_eq(+segs: List<&2, P.Segment>, +j: String, +c: Bool) ->
    {M.compare_path(P.Pattern{segs}, SCon{'/', j}, c) == MS.or_else(S.segments_with(c, segs, String.split(j, '/')), u => MS.root_rule(segs, j)) : Maybe<&2, P.Params>}:
  match c:
    case True{}:
      MSP.path_spec(P.Pattern{segs}, SCon{'/', j})
    case False{}:
      with_root_f(segs, j)

def joined_step(+np: List<&2, P.Segment>, +nx: List<&2, String>, +c: Bool, back: {String.split(String.join(nx, "/"), '/') == nx : List<&2, String>}) ->
    {MS.or_else(S.segments_with(c, np, String.split(String.join(nx, "/"), '/')), u => MS.root_rule(np, String.join(nx, "/"))) == S.matched(c, np, nx) : Maybe<&2, P.Params>}:
  %Equal.sym(Maybe<&2, P.Params>, MS.root_rule(np, String.join(nx, "/")), S.root_hit(String.split(String.join(nx, "/"), '/'), np), root_same(String.join(nx, "/"), np)) : {MS.or_else(S.segments_with(c, np, String.split(String.join(nx, "/"), '/')), u => _) == S.matched(c, np, nx) : Maybe<&2, P.Params>}
  %Equal.sym(List<&2, String>, String.split(String.join(nx, "/"), '/'), nx, back) : {MS.or_else(S.segments_with(c, np, _), u => S.root_hit(_, np)) == S.matched(c, np, nx) : Maybe<&2, P.Params>}
  {==}

def compare_joined(+np: List<&2, P.Segment>, +nx: List<&2, String>, +c: Bool, ne: {nx == Nil{} : List<&2, String>} -> Empty, clean: {Core.clean_segments(nx) == True{} : Bool}) ->
    {M.compare_path(P.Pattern{np}, SCon{'/', String.join(nx, "/")}, c) == S.matched(c, np, nx) : Maybe<&2, P.Params>}:
  Equal.trans(Maybe<&2, P.Params>, M.compare_path(P.Pattern{np}, SCon{'/', String.join(nx, "/")}, c), MS.or_else(S.segments_with(c, np, String.split(String.join(nx, "/"), '/')), u => MS.root_rule(np, String.join(nx, "/"))), S.matched(c, np, nx), compare_eq(np, String.join(nx, "/"), c), joined_step(np, nx, c, rejoin(nx, ne, clean)))

def compare_norm(+segs: List<&2, P.Segment>, +tail: String, +s: Bool, +c: Bool) ->
    {M.compare_path(P.Pattern{M.slash_pattern(segs, s)}, "/" ++ P.join_taken(List.reverse(&2, String, M.slash_segments(P.path_segments(tail), s))), c) == S.matched(c, S.normal_pattern(s, segs), S.normal_path(s, String.split(tail, '/'))) : Maybe<&2, P.Params>}:
  %PS.segments_equiv(tail) : {M.compare_path(P.Pattern{M.slash_pattern(segs, s)}, "/" ++ P.join_taken(List.reverse(&2, String, M.slash_segments(_, s))), c) == S.matched(c, S.normal_pattern(s, segs), S.normal_path(s, String.split(tail, '/'))) : Maybe<&2, P.Params>}
  %Equal.sym(List<&2, String>, M.slash_segments(String.split(tail, '/'), s), S.normal_path(s, String.split(tail, '/')), path_normal(String.split(tail, '/'), s)) : {M.compare_path(P.Pattern{M.slash_pattern(segs, s)}, "/" ++ P.join_taken(List.reverse(&2, String, _)), c) == S.matched(c, S.normal_pattern(s, segs), S.normal_path(s, String.split(tail, '/'))) : Maybe<&2, P.Params>}
  %Equal.sym(List<&2, P.Segment>, M.slash_pattern(segs, s), S.normal_pattern(s, segs), pattern_normal(segs, s)) : {M.compare_path(P.Pattern{_}, "/" ++ P.join_taken(List.reverse(&2, String, S.normal_path(s, String.split(tail, '/')))), c) == S.matched(c, S.normal_pattern(s, segs), S.normal_path(s, String.split(tail, '/'))) : Maybe<&2, P.Params>}
  %PS.join_taken_equiv(List.reverse(&2, String, S.normal_path(s, String.split(tail, '/')))) : {M.compare_path(P.Pattern{S.normal_pattern(s, segs)}, "/" ++ _, c) == S.matched(c, S.normal_pattern(s, segs), S.normal_path(s, String.split(tail, '/'))) : Maybe<&2, P.Params>}
  %Equal.sym(List<&2, String>, List.reverse(&2, String, List.reverse(&2, String, S.normal_path(s, String.split(tail, '/')))), S.normal_path(s, String.split(tail, '/')), rev_rev(String, S.normal_path(s, String.split(tail, '/')))) : {M.compare_path(P.Pattern{S.normal_pattern(s, segs)}, "/" ++ String.join(_, "/"), c) == S.matched(c, S.normal_pattern(s, segs), S.normal_path(s, String.split(tail, '/'))) : Maybe<&2, P.Params>}
  compare_joined(S.normal_pattern(s, segs), S.normal_path(s, String.split(tail, '/')), c, e => normal_ne(tail, s, e), clean_normal(String.split(tail, '/'), s, Core.clean_split_base(tail)))

# ---- Every option combination ----

def default_eq(+path: String, +pattern: P.Pattern) -> {MS.match_path(pattern, path) == S.match_options(pattern, path, M.Options{True{}, True{}}) : Maybe<&2, P.Params>}:
  match path:
    case SCon{'/', +tail}:
      match pattern:
        case P.Pattern{+segs}:
          %Equal.sym(Maybe<&2, P.Params>, MS.root_rule(segs, tail), S.root_hit(String.split(tail, '/'), segs), root_same(tail, segs)) : {MS.or_else(MS.matches(segs, String.split(tail, '/'), Nil{}), u => _) == S.match_options(P.Pattern{segs}, SCon{'/', tail}, M.Options{True{}, True{}}) : Maybe<&2, P.Params>}
          {==}
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

def adapted_eq(+pattern: P.Pattern, +path: String, +st: Bool, +c: Bool) -> {M.adapted_path(pattern, path, M.Options{st, c}) == S.match_options(pattern, path, M.Options{st, c}) : Maybe<&2, P.Params>}:
  match pattern path:
    case P.Pattern{+segs} SCon{'/', +tail}:
      compare_norm(segs, tail, st, c)
    case P.Pattern{segs} SNil{}:
      {==}
    case P.Pattern{segs} SCon{Chr{U32{WCon{False{}, remaining}}}, tail}:
      {==}
    case P.Pattern{segs} SCon{Chr{U32{WCon{True{}, WCon{False{}, remaining}}}}, tail}:
      {==}
    case P.Pattern{segs} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{False{}, remaining}}}}}, tail}:
      {==}
    case P.Pattern{segs} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, remaining}}}}}}, tail}:
      {==}
    case P.Pattern{segs} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, remaining}}}}}}}, tail}:
      {==}
    case P.Pattern{segs} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, remaining}}}}}}}}, tail}:
      {==}
    case P.Pattern{segs} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, remaining}}}}}}}}}, tail}:
      {==}
    case P.Pattern{segs} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{segs} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{segs} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{segs} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{segs} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{segs} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{segs} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{segs} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{segs} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{segs} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{segs} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{segs} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{segs} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{segs} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{segs} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{segs} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{segs} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{segs} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{segs} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{segs} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{segs} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{segs} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{segs} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{segs} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{segs} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}

def options_spec(+pattern: P.Pattern, +path: String, +opts: M.Options) -> {M.match_path(pattern, path, opts) == S.match_options(pattern, path, opts) : Maybe<&2, P.Params>}:
  match opts:
    case M.Options{True{}, True{}}:
      Equal.trans(Maybe<&2, P.Params>, P.match_path(pattern, path), MS.match_path(pattern, path), S.match_options(pattern, path, M.Options{True{}, True{}}), MSP.path_spec(pattern, path), default_eq(path, pattern))
    case M.Options{True{}, False{}}:
      adapted_eq(pattern, path, True{}, False{})
    case M.Options{False{}, +c}:
      adapted_eq(pattern, path, False{}, c)
