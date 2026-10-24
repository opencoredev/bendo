# Bundle-to-wire composition, including the standalone document dialect.
import Base
import ../src/app/manifest-schemas.bend as M
import ../src/app/manifest.bend as Rows
import ../src/app/route-schemas.bend as R
import ../src/data/schema.bend as S
import ../src/data/json.bend as J
import ../src/data/json-schema.bend as X
import ./json-schema.bend as XP
import ./json-schema-spec.bend as JS
import ./manifest-schema-spec.bend as Spec

def slots_parts(+p: Maybe<&2, S.Schema>, +q: Maybe<&2, S.Schema>, +h: Maybe<&2, S.Schema>, +b: Maybe<&2, S.Schema>, +r: Maybe<&2, S.Schema>) -> {R.slots(R.RouteSchemas{p, q, h, b, r}) == Spec.document_slots(R.RouteSchemas{p, q, h, b, r}) : List<&2, R.Named>}:
  match p q h b r:
    case None{} None{} None{} None{} None{}: {==}
    case None{} None{} None{} None{} Some{rx}: {==}
    case None{} None{} None{} Some{bx} None{}: {==}
    case None{} None{} None{} Some{bx} Some{rx}: {==}
    case None{} None{} Some{hx} None{} None{}: {==}
    case None{} None{} Some{hx} None{} Some{rx}: {==}
    case None{} None{} Some{hx} Some{bx} None{}: {==}
    case None{} None{} Some{hx} Some{bx} Some{rx}: {==}
    case None{} Some{qx} None{} None{} None{}: {==}
    case None{} Some{qx} None{} None{} Some{rx}: {==}
    case None{} Some{qx} None{} Some{bx} None{}: {==}
    case None{} Some{qx} None{} Some{bx} Some{rx}: {==}
    case None{} Some{qx} Some{hx} None{} None{}: {==}
    case None{} Some{qx} Some{hx} None{} Some{rx}: {==}
    case None{} Some{qx} Some{hx} Some{bx} None{}: {==}
    case None{} Some{qx} Some{hx} Some{bx} Some{rx}: {==}
    case Some{px} None{} None{} None{} None{}: {==}
    case Some{px} None{} None{} None{} Some{rx}: {==}
    case Some{px} None{} None{} Some{bx} None{}: {==}
    case Some{px} None{} None{} Some{bx} Some{rx}: {==}
    case Some{px} None{} Some{hx} None{} None{}: {==}
    case Some{px} None{} Some{hx} None{} Some{rx}: {==}
    case Some{px} None{} Some{hx} Some{bx} None{}: {==}
    case Some{px} None{} Some{hx} Some{bx} Some{rx}: {==}
    case Some{px} Some{qx} None{} None{} None{}: {==}
    case Some{px} Some{qx} None{} None{} Some{rx}: {==}
    case Some{px} Some{qx} None{} Some{bx} None{}: {==}
    case Some{px} Some{qx} None{} Some{bx} Some{rx}: {==}
    case Some{px} Some{qx} Some{hx} None{} None{}: {==}
    case Some{px} Some{qx} Some{hx} None{} Some{rx}: {==}
    case Some{px} Some{qx} Some{hx} Some{bx} None{}: {==}
    case Some{px} Some{qx} Some{hx} Some{bx} Some{rx}: {==}

def slots(+x: R.RouteSchemas) -> {R.slots(x) == Spec.document_slots(x) : List<&2, R.Named>}:
  match x:
    case R.RouteSchemas{p, q, h, b, r}: slots_parts(p, q, h, b, r)

def written(+r: Result<&2, &2, J.Error, String>, +route: Nat, +slot: String) -> {M.written(r, route, slot) == Spec.written(r, route, slot) : Result<&2, &2, M.AttachError, String>}:
  match r:
    case Done{text}: {==}
    case Fail{e}: {==}

def member(+rev: Result<&2, &2, M.AttachError, List<&2, String>>, +text: Result<&2, &2, M.AttachError, String>, +slot: String) -> {M.member(rev, text, slot) == Spec.member(rev, text, slot) : Result<&2, &2, M.AttachError, List<&2, String>>}:
  match rev text:
    case Fail{e} text: {==}
    case Done{xs} Fail{e}: {==}
    case Done{xs} Done{t}: {==}

def documents(+xs: List<&2, R.Named>, +route: Nat, +rev: Result<&2, &2, M.AttachError, List<&2, String>>) -> {M.members(xs, route, rev) == Spec.documents(~(+c => JS.document(X.export(c))), xs, route, rev) : Result<&2, &2, M.AttachError, List<&2, String>>}:
  match xs:
    case Nil{}: {==}
    case R.Named{slot, s} <> t:
      %XP.document_dialect(s) : {M.members(xs, route, rev) == Spec.documents(~(+c => JS.document(X.export(c))), t, route, Spec.member(rev, Spec.written(J.stringify(_), route, slot), slot)) : Result<&2, &2, M.AttachError, List<&2, String>>}
      %written(J.stringify(X.document(s)), route, slot) : {M.members(xs, route, rev) == Spec.documents(~(+c => JS.document(X.export(c))), t, route, Spec.member(rev, _, slot)) : Result<&2, &2, M.AttachError, List<&2, String>>}
      %member(rev, M.written(J.stringify(X.document(s)), route, slot), slot) : {M.members(xs, route, rev) == Spec.documents(~(+c => JS.document(X.export(c))), t, route, _) : Result<&2, &2, M.AttachError, List<&2, String>>}
      documents(t, route, M.member(rev, M.written(J.stringify(X.document(s)), route, slot), slot))

def schema_text(+r: Result<&2, &2, M.AttachError, List<&2, String>>) -> {M.schemas_member(r) == Spec.schema_text(r) : Result<&2, &2, M.AttachError, String>}:
  match r:
    case Fail{e}: {==}
    case Done{Nil{}}: {==}
    case Done{h <> t}: {==}

def close(+open: String, +r: Result<&2, &2, M.AttachError, String>) -> {M.attached_close(open, r) == Spec.attached(open, r) : Result<&2, &2, M.AttachError, String>}:
  match r:
    case Fail{e}: {==}
    case Done{x}: {==}

def attached(+route: Nat, +row: Rows.Row, +bundle: R.RouteSchemas) -> {M.attached_json(M.Attached{route, row, bundle}) == Spec.attached(M.row_open(row), Spec.schema_text(Spec.documents(~(+c => JS.document(X.export(c))), Spec.document_slots(bundle), route, Done{[]}))) : Result<&2, &2, M.AttachError, String>}:
  %slots(bundle) : {M.attached_json(M.Attached{route, row, bundle}) == Spec.attached(M.row_open(row), Spec.schema_text(Spec.documents(~(+c => JS.document(X.export(c))), _, route, Done{[]}))) : Result<&2, &2, M.AttachError, String>}
  %documents(R.slots(bundle), route, Done{[]}) : {M.attached_json(M.Attached{route, row, bundle}) == Spec.attached(M.row_open(row), Spec.schema_text(_)) : Result<&2, &2, M.AttachError, String>}
  %schema_text(M.members(R.slots(bundle), route, Done{[]})) : {M.attached_json(M.Attached{route, row, bundle}) == Spec.attached(M.row_open(row), _) : Result<&2, &2, M.AttachError, String>}
  close(M.row_open(row), M.schemas_member(M.members(R.slots(bundle), route, Done{[]})))
