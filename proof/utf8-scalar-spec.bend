# BND-100: what Utf8.encode promises for every String, stated without the
# encoder. Each Char that is not a Unicode scalar value (a surrogate, or a
# value above U+10FFFF) is replaced by U+FFFD; scalars stay as they are.
import Base
import ../src/data/utf8.bend as Utf8

def replace_char(c: U32, ok: Bool) -> U32:
  match ok:
    case True{}:
      c
    case False{}:
      65533

def replaced(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{+c}, t}:
      SCon{Chr{replace_char(c, Utf8.scalar(c))}, replaced(t)}
