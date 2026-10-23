import Base

def length_or(m: Maybe<&2, U32>, fallback: U32) -> U32:
  match m:
    case Some{x}: x
    case None{}: fallback

def content_line(h: String, fallback: U32, found: Bool) -> U32:
  match found:
    case True{}: length_or(U32.read(String.trim(String.drop(h, 15n))), fallback)
    case False{}: fallback

def content_length(lines: List<&2, String>) -> U32:
  match lines:
    case Nil{}: 0
    case Con{+h, t}:
      content_line(h, content_length(t), String.starts_with(String.to_lower(h), "content-length:"))

# Byte width of a decoded scalar, used by the strongest String candidate.
def width_tail(a: Bool, b: Bool) -> U32:
  match a b:
    case True{} _: 2
    case False{} True{}: 3
    case False{} False{}: 4

def width(+x: U32, ascii: Bool) -> U32:
  match ascii:
    case True{}: 1
    case False{}: width_tail(U32.is_lt(x, 2048), U32.is_lt(x, 65536))

def utf8_size(s: String) -> U32:
  match s:
    case SNil{}: 0
    case SCon{Chr{+x}, t}:
      (width(x, U32.is_lt(x, 128)) + utf8_size(t) : U32)
