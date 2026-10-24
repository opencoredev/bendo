# TODO BND-28: replace this local JSON string writer with the shared writer.
import Base
import ./table.bend as Table
import ../router/methods.bend as Methods
import ../router/spec.bend as Spec
import ../router/pattern.bend as Pattern
import ../http/request.bend as Request

# BND-37 hook: a route's schemas are Table.route_schemas(Tag, layers, route) for
# its reversed ordinal (RouteSlot.identity), and SP.schema(checked) returns the
# raw Schema of each prepared slot for JSON Schema export.

def hex(n: U32) -> String:
  match n:
    case 0: "0"
    case 1: "1"
    case 2: "2"
    case 3: "3"
    case 4: "4"
    case 5: "5"
    case 6: "6"
    case 7: "7"
    case 8: "8"
    case 9: "9"
    case 10: "a"
    case 11: "b"
    case 12: "c"
    case 13: "d"
    case 14: "e"
    case _: "f"

def ordinary(+n: U32, control: Bool) -> String:
  match control:
    case True{}:
      "\\u00" ++ hex((n / 16 : U32)) ++ hex((n % 16 : U32))
    case False{}:
      SCon{Chr{n}, ""}

def escape_char(+n: U32) -> String:
  match n:
    case 34: "\\\""
    case 92: "\\\\"
    case _: ordinary(n, (n < 32 : U32))

def escape(s: String) -> String:
  match s:
    case SNil{}: ""
    case SCon{Chr{n}, tail}: escape_char(n) ++ escape(tail)

def quote(s: String) -> String:
  "\"" ++ escape(s) ++ "\""

# One projection owns both JSON and the human-readable method/path table.
# Future schemas can extend a row without changing the version-1 envelope.
type Row is Data:
  Row{method: String, all: Bool, path: String, params: List<&2, String>}

def names(segments: List<&2, Pattern.Segment>) -> List<&2, String>:
  match segments:
    case Nil{}: []
    case Pattern.Capture{name, constraint, optional} <> tail: name <> names(tail)
    case Pattern.Wildcard{name} <> tail: name <> names(tail)
    case Pattern.Span{name} <> tail: name <> names(tail)
    case _ <> tail: names(tail)

def methods(xs: List<&2, Request.Method>, +path: String, +params: List<&2, String>) -> List<&2, Row>:
  match xs:
    case Nil{}: []
    case method <> tail:
      Row{Request.method_text(method), False{}, path, params} <> methods(tail, path, params)

def selector(method: Methods.MethodSelector, path: String, params: List<&2, String>) -> List<&2, Row>:
  match method:
    case Methods.AllMethods{}: [Row{"ALL", True{}, path, params}]
    case Methods.OnlyMethods{xs}: methods(xs, path, params)

# Paths retain their full assembled spelling; methods and names are certified.
def describe(-Tag: Data, xs: List<&2, Methods.Registration(Tag)>, table: Methods.Table(Tag)) -> List<&2, Row>:
  match xs table:
    case Spec.Registration{path, binding} <> tail Spec.Route{Pattern.Pattern{segments}, Methods.Binding{ms, tag}} <> rest:
      List.append(&2, Row, selector(ms, path, names(segments)), describe(Tag, tail, rest))
    case _ _: []

def rows(-Tag: Data, table: Table.Table<Tag>) -> List<&2, Row>:
  Table.Table{xs, compiled, middleware, count} = table
  describe(Tag, xs, Methods.raw(Tag, Methods.index_valid(Tag, compiled)))

def quoted(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}: []
    case h <> tail: quote(h) <> quoted(tail)

def all_field(all: Bool) -> String:
  match all:
    case True{}: ",\"all\":true"
    case False{}: ""

def row_json(row: Row) -> String:
  Row{method, all, path, params} = row
  "{\"method\":" ++ quote(method) ++ all_field(all) ++ ",\"path\":" ++ quote(path) ++ ",\"params\":[" ++ String.join(quoted(params), ",") ++ "]}"

def json_rows(xs: List<&2, Row>) -> List<&2, String>:
  match xs:
    case Nil{}: []
    case row <> tail: row_json(row) <> json_rows(tail)

def entries(-Tag: Data, xs: List<&2, Methods.Registration(Tag)>, table: Methods.Table(Tag)) -> List<&2, String>:
  json_rows(describe(Tag, xs, table))

def json(-Tag: Data, table: Table.Table<Tag>) -> String:
  "{\"bendo\":1,\"routes\":[" ++ String.join(json_rows(rows(Tag, table)), ",") ++ "]}"

def text_rows(xs: List<&2, Row>) -> String:
  match xs:
    case Nil{}: ""
    case Row{method, all, path, params} <> tail: "\n" ++ method ++ "\t" ++ path ++ text_rows(tail)

def table_text(-Tag: Data, table: Table.Table<Tag>) -> String:
  "METHOD\tPATH" ++ text_rows(rows(Tag, table))

# IO.args is affine and includes argv[0]; callers skip that first item.
def requested(args: List<String>) -> Bool:
  match args:
    case Nil{}: False{}
    case h <> tail: String.eq(h, "--bendo-routes") || requested(tail)

def argv(args: List<String>) -> Bool:
  match args:
    case Nil{}: False{}
    case program <> tail: requested(tail)
