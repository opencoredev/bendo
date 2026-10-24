# BND-44: an independent specification of the X-Forwarded-For entry list.
# Every field splits at each comma into pieces, empty pieces included. Each
# piece loses its leading and trailing spaces and tabs, nothing else. Pieces
# keep their order within a field, and fields keep theirs.
import Base

def space(+c: U32) -> Bool:
  U32.is_eq(c, 32) || U32.is_eq(c, 9)

# Whether every character is a space or a tab.
def blank(xs: List<&2, U32>) -> Bool:
  match xs:
    case Nil{}: True{}
    case +c <> t: space(c) && blank(t)

def skip_pick(+c: U32, t: List<&2, U32>, rest: List<&2, U32>, drop: Bool) -> List<&2, U32>:
  match drop:
    case True{}: rest
    case False{}: c <> t

# Without its leading blanks.
def skip(xs: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}: []
    case +c <> +t: skip_pick(c, t, skip(t), space(c))

def cut_pick(+c: U32, cut: Bool, rest: List<&2, U32>) -> List<&2, U32>:
  match cut:
    case True{}: []
    case False{}: c <> rest

# Without its trailing blanks: the list ends at a blank character whose
# remainder is all blank.
def rstrip(xs: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}: []
    case +c <> +t: cut_pick(c, space(c) && blank(t), rstrip(t))

def strip(xs: List<&2, U32>) -> List<&2, U32>:
  rstrip(skip(xs))

def text(xs: List<&2, U32>) -> String:
  match xs:
    case Nil{}: ""
    case c <> t: SCon{Chr{c}, text(t)}

def push(c: U32, parts: List<&2, List<&2, U32>>) -> List<&2, List<&2, U32>>:
  match parts:
    case Nil{}: [[c]]
    case p <> t: (c <> p) <> t

def pieces_pick(+c: U32, comma: Bool, parts: List<&2, List<&2, U32>>) -> List<&2, List<&2, U32>>:
  match comma:
    case True{}: [] <> parts
    case False{}: push(c, parts)

# The pieces between commas: n commas give n + 1 pieces.
def pieces(xs: List<&2, U32>) -> List<&2, List<&2, U32>>:
  match xs:
    case Nil{}: [[]]
    case +c <> t: pieces_pick(c, U32.is_eq(c, 44), pieces(t))

def field(parts: List<&2, List<&2, U32>>) -> List<&2, String>:
  match parts:
    case Nil{}: []
    case p <> t: text(strip(p)) <> field(t)

def entries(fields: List<&2, List<&2, U32>>) -> List<&2, String>:
  match fields:
    case Nil{}: []
    case f <> t: List.append(&2, String, field(pieces(f)), entries(t))
