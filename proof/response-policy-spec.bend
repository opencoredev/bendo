# BND-40: what a retained response policy does to a response, stated without
# the middleware's helpers. Field names compare without ASCII case. Byte
# trimming, ASCII decoding and case folding are shared primitives; the Vary
# list splitting and merging are restated here.
import Base
import ../src/http/request.bend as Request
import ../src/http/response.bend as Response
import ../src/http/bytes.bend as Bytes

# ---- Field filtering ----

def listed(+k: String, names: List<&2, String>) -> Bool:
  match names:
    case Nil{}: False{}
    case n <> t: String.eq(k, n) || listed(k, t)

def kept(h: Request.Header, rest: List<&2, Request.Header>, drop: Bool) -> List<&2, Request.Header>:
  match drop:
    case True{}: rest
    case False{}: h <> rest

# The fields whose lowercase name is none of names (each given in lowercase),
# in their original order and byte for byte.
def unrelated(hs: List<&2, Request.Header>, +names: List<&2, String>) -> List<&2, Request.Header>:
  match hs:
    case Nil{}: []
    case Request.Header{+k, v} <> t: kept(Request.Header{k, v}, unrelated(t, names), listed(Bytes.fold(k), names))

def headers(res: Response.Res) -> List<&2, Request.Header>:
  match res:
    case Response.Res{s, hs, b, rep}: hs

# ---- Vary ----

def vary_pick(v: List<&2, U32>, rest: List<&2, List<&2, U32>>, hit: Bool) -> List<&2, List<&2, U32>>:
  match hit:
    case True{}: v <> rest
    case False{}: rest

# The value of every Vary field, any case, in order.
def vary_values(hs: List<&2, Request.Header>) -> List<&2, List<&2, U32>>:
  match hs:
    case Nil{}: []
    case Request.Header{+k, v} <> t: vary_pick(v, vary_values(t), String.eq(Bytes.fold(k), "vary"))

# A field value split at every comma, in order: the first piece, then the
# rest. A value with no comma is one piece.
type Pieces is Data:
  Pieces{first: List<&2, U32>, rest: List<&2, List<&2, U32>>}

def split_step(+x: U32, s: Pieces, comma: Bool) -> Pieces:
  match s comma:
    case Pieces{f, r} True{}: Pieces{[], f <> r}
    case Pieces{f, r} False{}: Pieces{x <> f, r}

def split(xs: List<&2, U32>) -> Pieces:
  match xs:
    case Nil{}: Pieces{[], []}
    case +x <> t: split_step(x, split(t), U32.is_eq(x, 44))

# A list member: the piece without surrounding spaces and tabs, lowercased.
def member_name(piece: List<&2, U32>) -> String:
  Bytes.fold(Bytes.ascii(Bytes.trim(piece)))

def member_names(pieces: List<&2, List<&2, U32>>) -> List<&2, String>:
  match pieces:
    case Nil{}: []
    case p <> t: member_name(p) <> member_names(t)

def piece_names(s: Pieces) -> List<&2, String>:
  match s:
    case Pieces{f, r}: member_names(f <> r)

# The members one Vary value lists, in order.
def value_members(v: List<&2, U32>) -> List<&2, String>:
  piece_names(split(v))

# The lowercase members those values list.
def members(values: List<&2, List<&2, U32>>) -> List<&2, String>:
  match values:
    case Nil{}: []
    case v <> t: List.append(&2, String, value_members(v), members(t))

# Whether name (lowercase) is one of the members.
def member(+name: String, xs: List<&2, String>) -> Bool:
  match xs:
    case Nil{}: False{}
    case x <> t: String.eq(x, name) || member(name, t)

def fresh_pick(+n: String, rest: List<&2, String>, known: Bool) -> List<&2, String>:
  match known:
    case True{}: rest
    case False{}: n <> rest

# The names to add, as given: each one whose lowercase form is neither already
# listed nor an earlier name.
def fresh_go(names: List<&2, String>, +listed_members: List<&2, String>, +earlier: List<&2, String>) -> List<&2, String>:
  match names:
    case Nil{}: []
    case +n <> t: fresh_pick(n, fresh_go(t, listed_members, Bytes.fold(n) <> earlier), member(Bytes.fold(n), listed_members) || member(Bytes.fold(n), earlier))

def fresh(names: List<&2, String>, +listed_members: List<&2, String>) -> List<&2, String>:
  fresh_go(names, listed_members, [])

def encoded(names: List<&2, String>) -> List<&2, List<&2, U32>>:
  match names:
    case Nil{}: []
    case n <> t: Bytes.encode(n) <> encoded(t)

# Items joined by ", ".
def separated(xs: List<&2, List<&2, U32>>) -> List<&2, U32>:
  match xs:
    case Nil{}: []
    case x <> Nil{}: x
    case x <> t: List.append(&2, U32, x, List.append(&2, U32, [44, 32], separated(t)))

def vary_field(star: Bool, values: List<&2, List<&2, U32>>, added: List<&2, String>) -> List<&2, Request.Header>:
  match star values added:
    case True{} _ _: [Request.Header{"vary", [42]}]
    case False{} Nil{} Nil{}: []
    case False{} _ _: [Request.Header{"vary", separated(List.append(&2, List<&2, U32>, values, encoded(added)))}]

# Adding names to Vary: every other field stays in order, then one Vary field
# holds every existing value byte for byte followed by each fresh name. Once
# any existing member is "*", the field is exactly "*".
def vary_add(+hs: List<&2, Request.Header>, names: List<&2, String>) -> List<&2, Request.Header>:
  +values = vary_values(hs)
  +ms = members(values)
  List.append(&2, Request.Header, unrelated(hs, ["vary"]), vary_field(member("*", ms), values, fresh(names, ms)))

# With no names to add, the fields are untouched.
def varied(+hs: List<&2, Request.Header>, names: List<&2, String>) -> List<&2, Request.Header>:
  match names:
    case Nil{}: hs
    case n <> t: vary_add(hs, n <> t)

def vary_single(star: Bool, values: List<&2, List<&2, U32>>, added: List<&2, String>) -> List<&2, List<&2, U32>>:
  match star:
    case True{}: [[42]]
    case False{}: [separated(List.append(&2, List<&2, U32>, values, encoded(added)))]

# The Vary values a response carries after adding names to one whose Vary
# values are values: exactly one field, "*" when a member was "*", else every
# old value byte for byte, then each fresh name.
def vary_result(+values: List<&2, List<&2, U32>>, names: List<&2, String>) -> List<&2, List<&2, U32>>:
  +ms = members(values)
  vary_single(member("*", ms), values, fresh(names, ms))
