# The manifest a successful build must print, read from the assembled entries
# alone. It never reads a built table and never calls the exporter: each
# route's capture names come from compiling that route's own source path.
import Base
import ../src/app/manifest.bend as Out
import ../src/app/table.bend as T
import ../src/router/pattern.bend as P
import ../src/router/spec.bend as S
import ../src/router/methods.bend as M
import ../src/http/request.bend as R
import ./manifest-spec.bend as Names

# Registration normalizes a method through its text: an exact standard name
# becomes that standard method and any other token is kept as written.
def normal(m: R.Method) -> String:
  R.method_text(R.method(R.method_text(m)))

# One row per listed method, in order and with duplicates. HEAD is never added.
def finite(ms: List<&2, R.Method>, +path: String, +params: List<&2, String>) -> List<&2, Out.Row>:
  match ms:
    case Nil{}: []
    case h <> t: Out.Row{normal(h), False{}, path, params} <> finite(t, path, params)

def captures(compiled: Result<&2, &2, P.PatternError, P.Pattern>) -> List<&2, String>:
  match compiled:
    case Done{P.Pattern{segments}}: Names.names(segments)
    case Fail{error}: []

# An all-method route is one distinct ALL row, never an expansion.
def rows(ms: M.MethodSelector, +path: String, +params: List<&2, String>) -> List<&2, Out.Row>:
  match ms:
    case M.AllMethods{}: [Out.Row{"ALL", True{}, path, params}]
    case M.OnlyMethods{methods}: finite(methods, path, params)

def registration(-Tag: Data, r: M.Registration(Tag)) -> List<&2, Out.Row>:
  match r:
    case S.Registration{+path, M.Binding{methods, tag}}: rows(methods, path, captures(P.compile(path)))

# Every route declaration in entry order; hooks and middleware add no rows.
def enumerate(-Tag: Data, xs: List<&2, T.Entry<Tag>>) -> List<&2, Out.Row>:
  match xs:
    case Nil{}: []
    case T.Route{r} <> tail: List.append(&2, Out.Row, registration(Tag, r), enumerate(Tag, tail))
    case T.ScopedRoute{r, hooks} <> tail: List.append(&2, Out.Row, registration(Tag, r), enumerate(Tag, tail))
    case _ <> tail: enumerate(Tag, tail)
