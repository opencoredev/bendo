# TODO BND-28: replace this local JSON string writer with the shared writer.
import Base
import ./table.bend as Table
import ../router/methods.bend as Methods
import ../router/spec.bend as Spec
import ../http/request.bend as Request

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

def methods(xs: List<&2, Request.Method>, +path: String) -> List<&2, String>:
  match xs:
    case Nil{}: []
    case method <> tail:
      ("{\"method\":" ++ quote(Request.method_text(method)) ++ ",\"path\":" ++ quote(path) ++ "}") <> methods(tail, path)

# Paths retain their source spelling; methods come from the certified table.
def entries(-Tag: Data, xs: List<&2, Methods.Registration(Tag)>, table: Methods.Table(Tag)) -> List<&2, String>:
  match xs table:
    case Spec.Registration{path, binding} <> tail Spec.Route{pattern, Methods.Binding{ms, tag}} <> rest:
      List.append(&2, String, methods(ms, path), entries(Tag, tail, rest))
    case _ _: []

def json(-Tag: Data, table: Table.Table<Tag>) -> String:
  Table.Table{xs, compiled, middleware} = table
  "{\"bendo\":1,\"routes\":[" ++ String.join(entries(Tag, xs, Methods.raw(Tag, Methods.index_valid(Tag, compiled))), ",") ++ "]}"

# IO.args is affine and includes argv[0]; callers skip that first item.
def requested(args: List<String>) -> Bool:
  match args:
    case Nil{}: False{}
    case h <> tail: String.eq(h, "--bendo-routes") || requested(tail)

def argv(args: List<String>) -> Bool:
  match args:
    case Nil{}: False{}
    case program <> tail: requested(tail)
