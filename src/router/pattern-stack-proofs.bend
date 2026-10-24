# The stack-safe matcher loops equal their recursive specs (BND-84).
# Each `_equiv` lemma is stated spec first, so `%X_equiv(..)` rewrites a
# production term into its spec.
import Base
import ./pattern.bend as P
import ./encoding.bend as E
import ./reverse-proofs.bend as Rev
import ../http/text-proofs.bend as TP

def segments_equiv(+s: String) -> {String.split(s, '/') == P.path_segments(s) : List<&2, String>}:
  Equal.sym(List<&2, String>, P.path_segments(s), String.split(s, '/'), TP.split_equiv(s, '/'))

def join_claim(t: List<&2, String>, +x: String, +xs: List<&2, String>) ->
    {P.join_rev(t, String.join.go(xs, x, "/")) == String.join(List.reverse.go(&2, String, t, x <> xs), "/") : String}:
  match t:
    case Nil{}:
      {==}
    case +y <> t2:
      join_claim(t2, y, x <> xs)

def join_taken_equiv(+xs: List<&2, String>) -> {String.join(List.reverse(&2, String, xs), "/") == P.join_taken(xs) : String}:
  match xs:
    case Nil{}:
      {==}
    case +h <> +t:
      Equal.sym(String, P.join_rev(t, h), String.join(List.reverse.go(&2, String, t, [h]), "/"), join_claim(t, h, []))

# Wildcard values: decode every segment, then join.
def decoded_list(ps: List<&2, String>) -> Maybe<&2, List<&2, String>>:
  match ps:
    case Nil{}:
      Some{Nil{}}
    case p <> t:
      Maybe.bind(&2, String, List<&2, String>, E.decode(p), v => Maybe.bind(&2, List<&2, String>, List<&2, String>, decoded_list(t), vs => Some{v <> vs}))

def joined(m: Maybe<&2, List<&2, String>>) -> Maybe<&2, String>:
  match m:
    case None{}:
      None{}
    case Some{vs}:
      Some{String.join(vs, "/")}

def join_last(dp: Maybe<&2, String>) ->
    {dp == joined(Maybe.bind(&2, String, List<&2, String>, dp, v => Maybe.bind(&2, List<&2, String>, List<&2, String>, Some{Nil{}}, vs => Some{v <> vs}))) : Maybe<&2, String>}:
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

def spec_joined(+ps: List<&2, String>) -> {P.decode_segments_spec(ps) == joined(decoded_list(ps)) : Maybe<&2, String>}:
  match ps:
    case Nil{}:
      {==}
    case +p <> Nil{}:
      join_last(E.decode(p))
    case +p <> +h <> +t:
      %Equal.sym(Maybe<&2, String>, P.decode_segments_spec(h <> t), joined(decoded_list(h <> t)), spec_joined(h <> t)) : {P.join_value(E.decode(p), h <> t, _) == joined(decoded_list(p <> h <> t)) : Maybe<&2, String>}
      join_more(h, t, E.decode(p), E.decode(h), decoded_list(t))

def onto_list(acc: List<&2, String>, m: Maybe<&2, List<&2, String>>) -> Maybe<&2, List<&2, String>>:
  match m:
    case None{}:
      None{}
    case Some{vs}:
      Some{List.reverse.go(&2, String, vs, acc)}

def decoded_failed(ps: List<&2, String>) -> {P.decoded_go(ps, None{}) == None{} : Maybe<&2, List<&2, String>>}:
  match ps:
    case Nil{}:
      {==}
    case p <> t:
      decoded_failed(t)

def onto_cons(+v: String, +acc: List<&2, String>, m: Maybe<&2, List<&2, String>>) ->
    {onto_list(v <> acc, m) == onto_list(acc, Maybe.bind(&2, List<&2, String>, List<&2, String>, m, vs => Some{v <> vs})) : Maybe<&2, List<&2, String>>}:
  match m:
    case None{}:
      {==}
    case Some{vs}:
      {==}

def value_step(d: Maybe<&2, String>, +acc: List<&2, String>, +t: List<&2, String>,
    ih: @c: List<&2, String> -> {P.decoded_go(t, Some{c}) == onto_list(c, decoded_list(t)) : Maybe<&2, List<&2, String>>}) ->
    {P.decoded_go(t, P.push_value(Some{acc}, d)) == onto_list(acc, Maybe.bind(&2, String, List<&2, String>, d, v => Maybe.bind(&2, List<&2, String>, List<&2, String>, decoded_list(t), vs => Some{v <> vs}))) : Maybe<&2, List<&2, String>>}:
  match d:
    case None{}:
      decoded_failed(t)
    case Some{+v}:
      Equal.trans(Maybe<&2, List<&2, String>>, P.decoded_go(t, Some{v <> acc}), onto_list(v <> acc, decoded_list(t)), onto_list(acc, Maybe.bind(&2, List<&2, String>, List<&2, String>, decoded_list(t), vs => Some{v <> vs})), ih(v <> acc), onto_cons(v, acc, decoded_list(t)))

def decoded_go_equiv(ps: List<&2, String>, +acc: List<&2, String>) -> {P.decoded_go(ps, Some{acc}) == onto_list(acc, decoded_list(ps)) : Maybe<&2, List<&2, String>>}:
  match ps:
    case Nil{}:
      {==}
    case p <> +t:
      value_step(E.decode(p), acc, t, c => decoded_go_equiv(t, c))

def joined_fin(m: Maybe<&2, List<&2, String>>) -> {P.joined_rev(onto_list([], m)) == joined(m) : Maybe<&2, String>}:
  match m:
    case None{}:
      {==}
    case Some{+vs}:
      %join_taken_equiv(List.reverse(&2, String, vs)) : {Some{_} == Some{String.join(vs, "/")} : Maybe<&2, String>}
      %Rev.list_twice(String, vs) : {Some{String.join(List.reverse(&2, String, List.reverse(&2, String, vs)), "/")} == Some{String.join(_, "/")} : Maybe<&2, String>}
      {==}

def decode_segments_equiv(+ps: List<&2, String>) -> {P.decode_segments_spec(ps) == P.decode_segments(ps) : Maybe<&2, String>}:
  +dl = decoded_list(ps)
  e4 = Equal.cong(Maybe<&2, List<&2, String>>, Maybe<&2, String>, m => P.joined_rev(m), P.decoded_go(ps, Some{[]}), onto_list([], dl), decoded_go_equiv(ps, []))
  Equal.trans(Maybe<&2, String>, P.decode_segments_spec(ps), joined(dl), P.decode_segments(ps), spec_joined(ps), Equal.sym(Maybe<&2, String>, P.decode_segments(ps), joined(dl), Equal.trans(Maybe<&2, String>, P.decode_segments(ps), P.joined_rev(onto_list([], dl)), joined(dl), e4, joined_fin(dl))))

def empty_rows_shift(ps: List<&2, String>, +acc: List<&2, Maybe<&2, P.Params>>) ->
    {P.empty_rows_go(ps, None{} <> acc) == None{} <> P.empty_rows_go(ps, acc) : List<&2, Maybe<&2, P.Params>>}:
  match ps:
    case Nil{}:
      {==}
    case h <> t:
      empty_rows_shift(t, None{} <> acc)

def empty_rows_equiv(+ps: List<&2, String>) -> {P.empty_rows_spec(ps) == P.empty_rows(ps) : List<&2, Maybe<&2, P.Params>>}:
  match ps:
    case Nil{}:
      {==}
    case h <> +t:
      %Equal.sym(List<&2, Maybe<&2, P.Params>>, P.empty_rows_go(t, None{} <> [Some{Nil{}}]), None{} <> P.empty_rows(t), empty_rows_shift(t, [Some{Nil{}}])) : {P.empty_rows_spec(h <> t) == _ : List<&2, Maybe<&2, P.Params>>}
      Equal.cong(List<&2, Maybe<&2, P.Params>>, List<&2, Maybe<&2, P.Params>>, r => None{} <> r, P.empty_rows_spec(t), P.empty_rows(t), empty_rows_equiv(t))

def rows_go_equiv(~equal: String -> String -> Bool, ~starts: String -> String -> Bool, +seg: P.Segment, +last: Bool, paths: List<&2, String>, hits: List<&2, Maybe<&2, P.Params>>, +frames: List<&2, P.Frame>) ->
    {P.rows_run(~equal, ~starts, seg, last, P.rows_plan(~equal, ~starts, seg, last, paths, hits, frames)) == P.rows_build(~equal, ~starts, seg, last, frames, P.rows_for_spec(~equal, ~starts, seg, last, paths, hits)) : List<&2, Maybe<&2, P.Params>>}:
  match paths hits:
    case Nil{} cells:
      {==}
    case +h <> +tail +old <> +next:
      rows_go_equiv(~equal, ~starts, seg, last, tail, next, P.Frame{h <> tail, old <> next} <> frames)
    case h <> tail Nil{}:
      {==}

def rows_for_equiv(~equal: String -> String -> Bool, ~starts: String -> String -> Bool, +seg: P.Segment, +last: Bool, +paths: List<&2, String>, +hits: List<&2, Maybe<&2, P.Params>>) ->
    {P.rows_for_spec(~equal, ~starts, seg, last, paths, hits) == P.rows_for(~equal, ~starts, seg, last, paths, hits) : List<&2, Maybe<&2, P.Params>>}:
  Equal.sym(List<&2, Maybe<&2, P.Params>>, P.rows_for(~equal, ~starts, seg, last, paths, hits), P.rows_for_spec(~equal, ~starts, seg, last, paths, hits), rows_go_equiv(~equal, ~starts, seg, last, paths, hits, Nil{}))

def or_else(m: Maybe<&2, P.Params>, k: Maybe<&2, P.Params>) -> Maybe<&2, P.Params>:
  match m:
    case Some{ps}:
      Some{ps}
    case None{}:
      k

def pick_some(cs: List<&2, P.Candidate>, +name: String, +ps: P.Params) -> {P.span_pick(cs, name, Some{ps}) == Some{ps} : Maybe<&2, P.Params>}:
  match cs:
    case Nil{}:
      {==}
    case c <> t:
      pick_some(t, name, ps)

def pick_from(+cs: List<&2, P.Candidate>, +name: String, m: Maybe<&2, P.Params>) ->
    {P.span_pick(cs, name, m) == or_else(m, P.span_pick(cs, name, None{})) : Maybe<&2, P.Params>}:
  match m:
    case Some{+ps}:
      pick_some(cs, name, ps)
    case None{}:
      {==}

def or_else_prefer(a: Maybe<&2, P.Params>, +b: Maybe<&2, P.Params>, +k: Maybe<&2, P.Params>) ->
    {or_else(a, or_else(b, k)) == or_else(P.prefer(a, u => b), k) : Maybe<&2, P.Params>}:
  match a:
    case Some{ps}:
      {==}
    case None{}:
      {==}

def candidates_equiv(paths: List<&2, String>, cells: List<&2, Maybe<&2, P.Params>>, +name: String, +taken: List<&2, String>, +acc: List<&2, P.Candidate>) ->
    {P.span_pick(P.span_candidates(paths, cells, taken, acc), name, None{}) == or_else(P.span_scan_spec(paths, cells, name, taken), P.span_pick(acc, name, None{})) : Maybe<&2, P.Params>}:
  match paths cells:
    case +raw <> +tail old <> +next:
      +a = P.span_scan_spec(tail, next, name, raw <> taken)
      +b = P.span_value(name, raw <> taken, P.row_head(next))
      +k = P.span_pick(acc, name, None{})
      e1 = candidates_equiv(tail, next, name, raw <> taken, P.Candidate{raw <> taken, P.row_head(next)} <> acc)
      e2 = Equal.cong(Maybe<&2, P.Params>, Maybe<&2, P.Params>, m => or_else(a, m), P.span_pick(acc, name, b), or_else(b, k), pick_from(acc, name, b))
      Equal.trans(Maybe<&2, P.Params>, P.span_pick(P.span_candidates(tail, next, raw <> taken, P.Candidate{raw <> taken, P.row_head(next)} <> acc), name, None{}), or_else(a, or_else(b, k)), or_else(P.prefer(a, u => b), k), Equal.trans(Maybe<&2, P.Params>, P.span_pick(P.span_candidates(tail, next, raw <> taken, P.Candidate{raw <> taken, P.row_head(next)} <> acc), name, None{}), or_else(a, P.span_pick(acc, name, b)), or_else(a, or_else(b, k)), e1, e2), or_else_prefer(a, b, k))
    case Nil{} cells:
      {==}
    case raw <> tail Nil{}:
      {==}

def or_else_none(m: Maybe<&2, P.Params>) -> {or_else(m, None{}) == m : Maybe<&2, P.Params>}:
  match m:
    case Some{ps}:
      {==}
    case None{}:
      {==}

def span_scan_equiv(+paths: List<&2, String>, +cells: List<&2, Maybe<&2, P.Params>>, +name: String, +taken: List<&2, String>) ->
    {P.span_scan_spec(paths, cells, name, taken) == P.span_scan(paths, cells, name, taken) : Maybe<&2, P.Params>}:
  Equal.sym(Maybe<&2, P.Params>, P.span_scan(paths, cells, name, taken), P.span_scan_spec(paths, cells, name, taken), Equal.trans(Maybe<&2, P.Params>, P.span_scan(paths, cells, name, taken), or_else(P.span_scan_spec(paths, cells, name, taken), None{}), P.span_scan_spec(paths, cells, name, taken), candidates_equiv(paths, cells, name, taken, Nil{}), or_else_none(P.span_scan_spec(paths, cells, name, taken))))

# One unfolding step of span_scan, as the spec takes it.
def span_scan_cons(+raw: String, +tail: List<&2, String>, +old: Maybe<&2, P.Params>, +next: List<&2, Maybe<&2, P.Params>>, +name: String, +taken: List<&2, String>) ->
    {P.prefer(P.span_scan(tail, next, name, raw <> taken), u => P.span_value(name, raw <> taken, P.row_head(next))) == P.span_scan(raw <> tail, old <> next, name, taken) : Maybe<&2, P.Params>}:
  %span_scan_equiv(raw <> tail, old <> next, name, taken) : {P.prefer(P.span_scan(tail, next, name, raw <> taken), u => P.span_value(name, raw <> taken, P.row_head(next))) == _ : Maybe<&2, P.Params>}
  %span_scan_equiv(tail, next, name, raw <> taken) : {P.prefer(_, u => P.span_value(name, raw <> taken, P.row_head(next))) == P.span_scan_spec(raw <> tail, old <> next, name, taken) : Maybe<&2, P.Params>}
  {==}
