# Non-default routing options also rebuild request-derived path segments.
import Base
import ../src/router/methods.bend as M
import ../src/router/pattern.bend as P
import ../src/router/pattern-stack-proofs.bend as PP
import ../src/router/reverse-proofs.bend as RP

def joined_equiv(+xs: List<&2, String>) -> {P.join_taken(List.reverse(&2, String, xs)) == String.join(xs, "/") : String}:
  Equal.trans(String, P.join_taken(List.reverse(&2, String, xs)), String.join(List.reverse(&2, String, List.reverse(&2, String, xs)), "/"), String.join(xs, "/"), Equal.sym(String, String.join(List.reverse(&2, String, List.reverse(&2, String, xs)), "/"), P.join_taken(List.reverse(&2, String, xs)), PP.join_taken_equiv(List.reverse(&2, String, xs))), Equal.cong(List<&2, String>, String, ys => String.join(ys, "/"), List.reverse(&2, String, List.reverse(&2, String, xs)), xs, RP.list_twice(String, xs)))

def options_char(+segs: List<&2, P.Segment>, c: Char, +tail: String, +strict: Bool, +sensitive: Bool) -> {M.adapted_path(P.Pattern{segs}, SCon{c, tail}, M.Options{strict, sensitive}) == M.adapted_path_spec(P.Pattern{segs}, SCon{c, tail}, M.Options{strict, sensitive}) : Maybe<&2, P.Params>}:
  match c:
    case '/':
      +ps = M.slash_segments(P.path_segments(tail), strict)
      Equal.cong(String, Maybe<&2, P.Params>, joined => M.compare_path(P.Pattern{M.slash_pattern(segs, strict)}, "/" ++ joined, sensitive), P.join_taken(List.reverse(&2, String, ps)), String.join(ps, "/"), joined_equiv(ps))
    case Chr{U32{WCon{False{}, bits}}}: {==}
    case Chr{U32{WCon{True{}, WCon{False{}, bits}}}}: {==}
    case Chr{U32{WCon{True{}, WCon{True{}, WCon{False{}, bits}}}}}: {==}
    case Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, bits}}}}}}: {==}
    case Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, bits}}}}}}}}: {==}
    case Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}}: {==}
    case Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}}: {==}
    case Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, bits}}}}}}}}}}: {==}
    case Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, bits}}}}}}}}}: {==}
    case Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, bits}}}}}}}: {==}

law routing_options_stack_safe:
  for +pattern: P.Pattern
  for +path: String
  for +opts: M.Options
  {M.adapted_path(pattern, path, opts) == M.adapted_path_spec(pattern, path, opts) : Maybe<&2, P.Params>}

def routing_options_stack_safe(pattern, path, opts):
  match pattern path opts:
    case P.Pattern{segs} SNil{} M.Options{strict, sensitive}: {==}
    case P.Pattern{segs} SCon{c, tail} M.Options{strict, sensitive}:
      options_char(segs, c, tail, strict, sensitive)
