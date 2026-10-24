# The route schemas a successful attachment pairs with manifest rows, and when
# attachment succeeds, read from the registrations and schema entries alone
# (BND-37). It never calls the attachment code.
import Base
import ../src/data/json.bend as J
import ../src/app/manifest.bend as Out
import ../src/app/manifest-schemas.bend as MS
import ../src/app/route-schemas.bend as RS
import ../src/data/schema.bend as S
import ../src/router/pattern.bend as P
import ../src/router/spec.bend as R
import ../src/router/methods.bend as M
import ./manifest-spec.bend as Rows

def copies(n: Nat, +x: RS.RouteSchemas) -> List<&2, RS.RouteSchemas>:
  match n:
    case 0n: []
    case 1n+k: x <> copies(k, x)

# Entry i belongs to registration i and repeats on every row it prints.
def spread(-Tag: Data, sources: List<&2, M.Registration(Tag)>, certified: M.Table(Tag), ss: List<&2, RS.RouteSchemas>) -> List<&2, RS.RouteSchemas>:
  match sources certified ss:
    case R.Registration{path, unused} <> xs R.Route{P.Pattern{segments}, M.Binding{methods, tag}} <> ys x <> zs:
      List.append(&2, RS.RouteSchemas, copies(List.length(&2, Out.Row, Rows.rows(methods, path, segments)), x), spread(Tag, xs, ys, zs))
    case _ _ _: []

def slot_ok(s: Maybe<&2, S.Schema>) -> Bool:
  match s:
    case None{}: True{}
    case Some{x}: S.valid(x)

def slots_ok(x: RS.RouteSchemas) -> Bool:
  match x:
    case RS.RouteSchemas{p, q, h, b, r}: slot_ok(p) && (slot_ok(q) && (slot_ok(h) && (slot_ok(b) && slot_ok(r))))

def all_valid(xs: List<&2, RS.RouteSchemas>) -> Bool:
  match xs:
    case Nil{}: True{}
    case x <> t: slots_ok(x) && all_valid(t)

def accepted(r: Result<&2, &2, MS.AttachError, List<&2, MS.Attached>>) -> Bool:
  match r:
    case Done{xs}: True{}
    case Fail{e}: False{}

# The five named slots in their wire order, independent of RS.slots.
def named(name: String, s: Maybe<&2, S.Schema>, rest: List<&2, RS.Named>) -> List<&2, RS.Named>:
  match s:
    case None{}: rest
    case Some{x}: RS.Named{name, x} <> rest

def document_slots(x: RS.RouteSchemas) -> List<&2, RS.Named>:
  match x:
    case RS.RouteSchemas{p, q, h, b, r}: named("params", p, named("query", q, named("headers", h, named("body", b, named("response", r, [])))))

def written(r: Result<&2, &2, J.Error, String>, route: Nat, slot: String) -> Result<&2, &2, MS.AttachError, String>:
  match r:
    case Done{text}: Done{text}
    case Fail{e}: Fail{MS.UnwritableRouteSchema{route, slot}}

def member(rev: Result<&2, &2, MS.AttachError, List<&2, String>>, text: Result<&2, &2, MS.AttachError, String>, slot: String) -> Result<&2, &2, MS.AttachError, List<&2, String>>:
  match rev text:
    case Fail{e} _: Fail{e}
    case Done{xs} Fail{e}: Fail{e}
    case Done{xs} Done{t}: Done{(Out.quote(slot) ++ ":" ++ t) <> xs}

# Each present slot serializes the supplied standalone document, preserving
# the first serialization failure. No manifest-schema or exporter helpers.
def documents(~doc: S.Schema -> J.Json, xs: List<&2, RS.Named>, +route: Nat, rev: Result<&2, &2, MS.AttachError, List<&2, String>>) -> Result<&2, &2, MS.AttachError, List<&2, String>>:
  match xs:
    case Nil{}: rev
    case RS.Named{+slot, s} <> t: documents(~doc, t, route, member(rev, written(J.stringify(doc(s)), route, slot), slot))

def schema_text(r: Result<&2, &2, MS.AttachError, List<&2, String>>) -> Result<&2, &2, MS.AttachError, String>:
  match r:
    case Fail{e}: Fail{e}
    case Done{Nil{}}: Done{""}
    case Done{xs}: Done{",\"schemas\":{" ++ String.join(List.reverse(&2, String, xs), ",") ++ "}"}

def attached(open: String, r: Result<&2, &2, MS.AttachError, String>) -> Result<&2, &2, MS.AttachError, String>:
  match r:
    case Fail{e}: Fail{e}
    case Done{extra}: Done{open ++ extra ++ "}"}
