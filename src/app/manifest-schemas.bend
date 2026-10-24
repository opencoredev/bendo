# BND-37: route schemas in the manifest. This module is separate from
# manifest.bend so apps without schemas never compile the schema exporter.
# See docs/manifest.md#route-schemas.
import Base
import ./manifest.bend as Manifest
import ./table.bend as Table
import ./route-schemas.bend as RS
import ../router/methods.bend as Methods
import ../router/spec.bend as Spec
import ../router/pattern.bend as Pattern
import ../data/json.bend as J
import ../data/json-schema.bend as JS

# A row's members without the closing brace, so schemas can follow them. The
# text up to here is exactly Manifest.row_json's.
def row_open(row: Manifest.Row) -> String:
  Manifest.Row{method, all, path, params} = row
  "{\"method\":" ++ Manifest.quote(method) ++ Manifest.all_field(all) ++ ",\"path\":" ++ Manifest.quote(path) ++ ",\"params\":[" ++ String.join(Manifest.quoted(params), ",") ++ "]"

# A manifest with schemas pairs every row with the
# RouteSchemas of the registration it came from. Schemas are positional: one
# per registration in registration order, so duplicate registrations keep
# their own schemas and every method row of one registration shares them.
type Attached is Data:
  Attached{route: Nat, row: Manifest.Row, schemas: RS.RouteSchemas}

type AttachError is Data:
  CountMismatch{routes: Nat, schemas: Nat}
  InvalidRouteSchema{route: Nat, slot: String}
  UnwritableRouteSchema{route: Nat, slot: String}

def error_text(e: AttachError) -> String:
  match e:
    case CountMismatch{routes, schemas}: "route schemas: " ++ Nat.show(routes) ++ " route registrations but " ++ Nat.show(schemas) ++ " schema entries"
    case InvalidRouteSchema{route, slot}: "route schemas: route " ++ Nat.show(route) ++ " has an invalid " ++ slot ++ " schema"
    case UnwritableRouteSchema{route, slot}: "route schemas: route " ++ Nat.show(route) ++ " has a " ++ slot ++ " schema too deep to write as JSON"

def tag_rows(rows: List<&2, Manifest.Row>, +route: Nat, +x: RS.RouteSchemas) -> List<&2, Attached>:
  match rows:
    case Nil{}: []
    case r <> t: Attached{route, r, x} <> tag_rows(t, route, x)

def pairs(-Tag: Data, xs: List<&2, Methods.Registration(Tag)>, table: Methods.Table(Tag), ss: List<&2, RS.RouteSchemas>, +route: Nat) -> List<&2, Attached>:
  match xs table ss:
    case Spec.Registration{path, binding} <> tail Spec.Route{Pattern.Pattern{segments}, Methods.Binding{ms, tag}} <> rest x <> more:
      List.append(&2, Attached, tag_rows(Manifest.selector(ms, path, Manifest.names(segments)), route, x), pairs(Tag, tail, rest, more, 1n+route))
    case _ _ _: []

def first_problem(+route: Nat, bad: Maybe<&2, String>, rest: Maybe<&2, AttachError>) -> Maybe<&2, AttachError>:
  match bad:
    case Some{slot}: Some{InvalidRouteSchema{route, slot}}
    case None{}: rest

# The first registration, by position, with an invalid schema in some slot.
def problem(xs: List<&2, RS.RouteSchemas>, +route: Nat) -> Maybe<&2, AttachError>:
  match xs:
    case Nil{}: None{}
    case x <> t: first_problem(route, RS.invalid_slot(x), problem(t, 1n+route))

def gate(-Tag: Data, same: Bool, found: Maybe<&2, AttachError>, routes: Nat, schemas: Nat, xs: List<&2, Methods.Registration(Tag)>, table: Methods.Table(Tag), ss: List<&2, RS.RouteSchemas>) -> Result<&2, &2, AttachError, List<&2, Attached>>:
  match same found:
    case False{} _: Fail{CountMismatch{routes, schemas}}
    case True{} Some{e}: Fail{e}
    case True{} None{}: Done{pairs(Tag, xs, table, ss, 0n)}

def attach_from(-Tag: Data, +xs: List<&2, Methods.Registration(Tag)>, table: Methods.Table(Tag), +ss: List<&2, RS.RouteSchemas>) -> Result<&2, &2, AttachError, List<&2, Attached>>:
  +routes = List.length(&2, Methods.Registration(Tag), xs)
  +schemas = List.length(&2, RS.RouteSchemas, ss)
  gate(Tag, Nat.is_eq(routes, schemas), problem(ss, 0n), routes, schemas, xs, table, ss)

# Fails unless there is exactly one entry per registration and every schema
# is valid, so a manifest never prints a schema the decoder would refuse.
def attach(-Tag: Data, table: Table.Table<Tag>, ss: List<&2, RS.RouteSchemas>) -> Result<&2, &2, AttachError, List<&2, Attached>>:
  Table.Table{xs, compiled, middleware, count} = table
  attach_from(Tag, xs, Methods.raw(Tag, Methods.index_valid(Tag, compiled)), ss)

def attached_rows(xs: List<&2, Attached>) -> List<&2, Manifest.Row>:
  match xs:
    case Nil{}: []
    case Attached{route, row, x} <> t: row <> attached_rows(t)

def attached_schemas(xs: List<&2, Attached>) -> List<&2, RS.RouteSchemas>:
  match xs:
    case Nil{}: []
    case Attached{route, row, x} <> t: x <> attached_schemas(t)

def written(r: Result<&2, &2, J.Error, String>, +route: Nat, slot: String) -> Result<&2, &2, AttachError, String>:
  match r:
    case Done{text}: Done{text}
    case Fail{e}: Fail{UnwritableRouteSchema{route, slot}}

def member(rev: Result<&2, &2, AttachError, List<&2, String>>, text: Result<&2, &2, AttachError, String>, slot: String) -> Result<&2, &2, AttachError, List<&2, String>>:
  match rev text:
    case Fail{e} _: Fail{e}
    case Done{xs} Fail{e}: Fail{e}
    case Done{xs} Done{t}: Done{(Manifest.quote(slot) ++ ":" ++ t) <> xs}

def members(xs: List<&2, RS.Named>, +route: Nat, rev: Result<&2, &2, AttachError, List<&2, String>>) -> Result<&2, &2, AttachError, List<&2, String>>:
  match xs:
    case Nil{}: rev
    case RS.Named{+slot, +s} <> t: members(t, route, member(rev, written(J.stringify(JS.document(s)), route, slot), slot))

def schemas_member(r: Result<&2, &2, AttachError, List<&2, String>>) -> Result<&2, &2, AttachError, String>:
  match r:
    case Fail{e}: Fail{e}
    case Done{Nil{}}: Done{""}
    case Done{xs}: Done{",\"schemas\":{" ++ String.join(List.reverse(&2, String, xs), ",") ++ "}"}

def attached_close(open: String, r: Result<&2, &2, AttachError, String>) -> Result<&2, &2, AttachError, String>:
  match r:
    case Fail{e}: Fail{e}
    case Done{extra}: Done{open ++ extra ++ "}"}

def attached_json(a: Attached) -> Result<&2, &2, AttachError, String>:
  Attached{route, row, x} = a
  attached_close(row_open(row), schemas_member(members(RS.slots(x), route, Done{[]})))

def push_row(rev: Result<&2, &2, AttachError, List<&2, String>>, r: Result<&2, &2, AttachError, String>) -> Result<&2, &2, AttachError, List<&2, String>>:
  match rev r:
    case Fail{e} _: Fail{e}
    case Done{xs} Fail{e}: Fail{e}
    case Done{xs} Done{t}: Done{t <> xs}

def attached_rows_json(xs: List<&2, Attached>, rev: Result<&2, &2, AttachError, List<&2, String>>) -> Result<&2, &2, AttachError, List<&2, String>>:
  match xs:
    case Nil{}: rev
    case a <> t: attached_rows_json(t, push_row(rev, attached_json(a)))

def envelope(r: Result<&2, &2, AttachError, List<&2, String>>) -> Result<&2, &2, AttachError, String>:
  match r:
    case Fail{e}: Fail{e}
    case Done{rev}: Done{"{\"bendo\":1,\"routes\":[" ++ String.join(List.reverse(&2, String, rev), ",") ++ "]}"}

def json_attached(r: Result<&2, &2, AttachError, List<&2, Attached>>) -> Result<&2, &2, AttachError, String>:
  match r:
    case Fail{e}: Fail{e}
    case Done{xs}: envelope(attached_rows_json(xs, Done{[]}))

# The version-1 envelope with an additive "schemas" member on each row whose
# registration sets a schema. Rows without schemas print exactly as `json`.
def json_schemas(-Tag: Data, table: Table.Table<Tag>, ss: List<&2, RS.RouteSchemas>) -> Result<&2, &2, AttachError, String>:
  json_attached(attach(Tag, table, ss))
