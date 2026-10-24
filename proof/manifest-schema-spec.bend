# The route schemas a successful attachment pairs with manifest rows, and when
# attachment succeeds, read from the registrations and schema entries alone
# (BND-37). It never calls the attachment code.
import Base
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
