# Vary merging for middleware that adds request-dependent fields. Every Vary
# field becomes one field: the existing values byte for byte, then each added
# name the list does not already contain (compared without ASCII case).
# Vary: * stays *.
import Base
import ./response_fields.bend as Fields
import ../http/request.bend as Request
import ../http/bytes.bend as Bytes

type Items is Data:
  Items{current: List<&2, U32>, done: List<&2, String>}

def item(rev: List<&2, U32>) -> String:
  Bytes.fold(Bytes.ascii(Bytes.trim(List.reverse(&2, U32, rev))))

def items_step(+x: U32, s: Items, comma: Bool) -> Items:
  match s comma:
    case Items{cur, done} True{}: Items{[], item(cur) <> done}
    case Items{cur, done} False{}: Items{x <> cur, done}

def items_go(xs: List<&2, U32>, s: Items) -> Items:
  match xs:
    case Nil{}: s
    case +x <> t: items_go(t, items_step(x, s, U32.is_eq(x, 44)))

def items_end(s: Items) -> List<&2, String>:
  match s:
    case Items{cur, done}: item(cur) <> done

# The lowercase list members of one field value.
def items(xs: List<&2, U32>) -> List<&2, String>:
  items_end(items_go(xs, Items{[], []}))

def all_items(values: List<&2, List<&2, U32>>) -> List<&2, String>:
  match values:
    case Nil{}: []
    case v <> t: List.append(&2, String, items(v), all_items(t))

def has(+name: String, xs: List<&2, String>) -> Bool:
  match xs:
    case Nil{}: False{}
    case x <> t: String.eq(x, name) || has(name, t)

def missing_pick(+n: String, rest: List<&2, String>, present: Bool) -> List<&2, String>:
  match present:
    case True{}: rest
    case False{}: n <> rest

def missing(names: List<&2, String>, +seen: List<&2, String>) -> List<&2, String>:
  match names:
    case Nil{}: []
    case +n <> t: missing_pick(n, missing(t, Bytes.fold(n) <> seen), has(Bytes.fold(n), seen))

def added_after(v: List<&2, U32>, added: List<&2, String>) -> List<&2, U32>:
  match added:
    case Nil{}: v
    case a <> t: List.append(&2, U32, v, Bytes.encode(", " ++ String.join(a <> t, ", ")))

def joined(values: List<&2, List<&2, U32>>, added: List<&2, String>) -> List<&2, U32>:
  match values:
    case Nil{}: Bytes.encode(String.join(added, ", "))
    case v <> Nil{}: added_after(v, added)
    case v <> t: List.append(&2, U32, v, List.append(&2, U32, Bytes.encode(", "), joined(t, added)))

def blank(values: List<&2, List<&2, U32>>, added: List<&2, String>) -> Bool:
  match values added:
    case Nil{} Nil{}: True{}
    case _ _: False{}

def unstarred(hs: List<&2, Request.Header>, +values: List<&2, List<&2, U32>>, +added: List<&2, String>, empty: Bool) -> List<&2, Request.Header>:
  match empty:
    case True{}: hs
    case False{}: List.append(&2, Request.Header, hs, [Request.Header{"vary", joined(values, added)}])

def merged(hs: List<&2, Request.Header>, +values: List<&2, List<&2, U32>>, +added: List<&2, String>, star: Bool) -> List<&2, Request.Header>:
  match star:
    case True{}: List.append(&2, Request.Header, hs, [Request.Header{"vary", [42]}])
    case False{}: unstarred(hs, values, added, blank(values, added))

def add(+hs: List<&2, Request.Header>, names: List<&2, String>) -> List<&2, Request.Header>:
  +values = Fields.values(hs, "vary")
  +seen = all_items(values)
  merged(Fields.without(hs, "vary"), values, missing(names, seen), has("*", seen))
