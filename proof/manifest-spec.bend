# Specification projects certified route data; it never calls the exporter.
import Base
import ../src/app/manifest.bend as Out
import ../src/router/pattern.bend as P
import ../src/router/spec.bend as S
import ../src/router/methods.bend as M
import ../src/http/request.bend as R

def include(name: Maybe<&2, String>, tail: List<&2, String>) -> List<&2, String>:
  match name:
    case None{}: tail
    case Some{n}: n <> tail

def names(xs: List<&2, P.Segment>) -> List<&2, String>:
  match xs:
    case Nil{}: []
    case h <> t: include(P.segment_name(h), names(t))

def finite(ms: List<&2, R.Method>, +path: String, +params: List<&2, String>) -> List<&2, Out.Row>:
  match ms:
    case Nil{}: []
    case h <> t: Out.Row{R.method_text(h), False{}, path, params} <> finite(t, path, params)

def rows(ms: M.MethodSelector, path: String, segments: List<&2, P.Segment>) -> List<&2, Out.Row>:
  match ms:
    case M.AllMethods{}: [Out.Row{"ALL", True{}, path, names(segments)}]
    case M.OnlyMethods{methods}: finite(methods, path, names(segments))

def describe(-Tag: Data, sources: List<&2, M.Registration(Tag)>, certified: M.Table(Tag)) -> List<&2, Out.Row>:
  match sources certified:
    case S.Registration{path, unused} <> xs S.Route{P.Pattern{segments}, M.Binding{methods, tag}} <> ys:
      List.append(&2, Out.Row, rows(methods, path, segments), describe(Tag, xs, ys))
    case _ _: []
