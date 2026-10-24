# BND-85: trimming optional whitespace, stated without src/http/bytes.bend.
# RFC 9110 section 5.6.3: OWS is SP and HTAB, nothing else. The trimmed value
# loses every leading and trailing SP and HTAB and keeps everything between.
import Base

# SP or HTAB.
def space(+c: U32) -> Bool:
  U32.is_eq(c, 32) || U32.is_eq(c, 9)

# Whether every octet is SP or HTAB.
def blank(xs: List<&2, U32>) -> Bool:
  match xs:
    case Nil{}: True{}
    case +c <> t: space(c) && blank(t)

def skip_pick(+c: U32, t: List<&2, U32>, rest: List<&2, U32>, drop: Bool) -> List<&2, U32>:
  match drop:
    case True{}: rest
    case False{}: c <> t

# Without its leading SP and HTAB.
def skip(xs: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}: []
    case +c <> +t: skip_pick(c, t, skip(t), space(c))

def cut_pick(+c: U32, cut: Bool, rest: List<&2, U32>) -> List<&2, U32>:
  match cut:
    case True{}: []
    case False{}: c <> rest

# Without its trailing SP and HTAB: the list ends at an SP or HTAB whose
# remainder is blank.
def rstrip(xs: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}: []
    case +c <> +t: cut_pick(c, space(c) && blank(t), rstrip(t))

def strip(xs: List<&2, U32>) -> List<&2, U32>:
  rstrip(skip(xs))

# Text as one code per character, and back.
def codes(s: String) -> List<&2, U32>:
  match s:
    case SNil{}: []
    case SCon{Chr{c}, t}: c <> codes(t)

def text(xs: List<&2, U32>) -> String:
  match xs:
    case Nil{}: ""
    case c <> t: SCon{Chr{c}, text(t)}

# Text without leading and trailing SP and HTAB.
def trim(s: String) -> String:
  text(strip(codes(s)))
