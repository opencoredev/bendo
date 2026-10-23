import Base
import ../src/app/manifest.bend as O
import ../src/router/pattern.bend as P
import ../src/router/spec.bend as R
import ../src/router/methods.bend as M
import ../src/http/request.bend as Req
import ./manifest-spec.bend as S

def names(+xs: List<&2, P.Segment>) -> {O.names(xs) == S.names(xs) : List<&2, String>}:
  match xs:
    case Nil{}: {==}
    case P.Static{raw} <> t: names(t)
    case P.InteriorWildcard{} <> t: names(t)
    case P.PrefixWildcard{prefix} <> t: names(t)
    case P.Capture{name, constraint, optional} <> t:
      Equal.cong(List<&2, String>, List<&2, String>, ns => name <> ns, O.names(t), S.names(t), names(t))
    case P.Span{name} <> t:
      Equal.cong(List<&2, String>, List<&2, String>, ns => name <> ns, O.names(t), S.names(t), names(t))
    case P.Wildcard{name} <> t:
      Equal.cong(List<&2, String>, List<&2, String>, ns => name <> ns, O.names(t), S.names(t), names(t))

def finite(+ms: List<&2, Req.Method>, +path: String, +params: List<&2, String>) -> {O.methods(ms, path, params) == S.finite(ms, path, params) : List<&2, O.Row>}:
  match ms:
    case Nil{}: {==}
    case h <> t:
      Equal.cong(List<&2, O.Row>, List<&2, O.Row>, rows => O.Row{Req.method_text(h), False{}, path, params} <> rows, O.methods(t, path, params), S.finite(t, path, params), finite(t, path, params))

def selector(+ms: M.MethodSelector, +path: String, +segments: List<&2, P.Segment>) -> {O.selector(ms, path, O.names(segments)) == S.rows(ms, path, segments) : List<&2, O.Row>}:
  match ms:
    case M.AllMethods{}:
      Equal.cong(List<&2, String>, List<&2, O.Row>, ns => [O.Row{"ALL", True{}, path, ns}], O.names(segments), S.names(segments), names(segments))
    case M.OnlyMethods{methods}:
      %Equal.sym(List<&2, String>, O.names(segments), S.names(segments), names(segments)) : {O.methods(methods, path, _) == S.rows(ms, path, segments) : List<&2, O.Row>}
      finite(methods, path, S.names(segments))

def describe(-Tag: Data, +sources: List<&2, M.Registration(Tag)>, +certified: M.Table(Tag)) -> {O.describe(Tag, sources, certified) == S.describe(Tag, sources, certified) : List<&2, O.Row>}:
  match sources certified:
    case R.Registration{path, unused} <> xs R.Route{P.Pattern{segments}, M.Binding{methods, tag}} <> ys:
      %Equal.sym(List<&2, O.Row>, O.selector(methods, path, O.names(segments)), S.rows(methods, path, segments), selector(methods, path, segments)) : {List.append(&2, O.Row, _, O.describe(Tag, xs, ys)) == S.describe(Tag, sources, certified) : List<&2, O.Row>}
      Equal.cong(List<&2, O.Row>, List<&2, O.Row>, tail => List.append(&2, O.Row, S.rows(methods, path, segments), tail), O.describe(Tag, xs, ys), S.describe(Tag, xs, ys), describe(Tag, xs, ys))
    case Nil{} _: {==}
    case _ Nil{}: {==}
