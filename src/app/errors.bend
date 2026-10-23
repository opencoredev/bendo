# Typed recoverable failures. They are values, never runtime exceptions.
import Base
import ../http/response.bend as Response
import ../http/bytes.bend as Bytes

type HttpError is Data:
  HttpError{status: U32, message: String, expose: Bool}

def status_valid(code: U32, valid: Bool) -> U32:
  match valid:
    case True{}: code
    case False{}: 500

def status(+code: U32) -> U32:
  status_valid(code, (code >= 400 : U32) && (code <= 599 : U32))

def public_message(message: String, exposed: Bool) -> String:
  match exposed:
    case True{}: message
    case False{}: "Internal Server Error"

def message_default(message: String, fallback: String, empty: Bool) -> String:
  match empty:
    case True{}: fallback
    case False{}: message

def message(error: HttpError) -> String:
  HttpError{+code, +message, expose} = error
  public_message(message_default(message, Response.reason(code), String.is_empty(message)), expose && (code >= 400 : U32) && (code <= 599 : U32))

def http_error(+code: U32, message: String) -> HttpError:
  HttpError{status(code), message, (code >= 400 : U32) && (code < 500 : U32)}

# Explicit JSON ranges opt in; wildcards retain the text default. A q=0
# range is excluded. Quality values follow HTTP's zero-to-one, 3-digit grammar.
def trim(s: String) -> String:
  Bytes.ascii(Bytes.trim(Bytes.encode(s)))

def fraction(xs: String, fuel: Nat, positive: Bool) -> Bool:
  match xs fuel:
    case SNil{} _: positive
    case SCon{Chr{+c}, tail} 1n+left:
      (c >= 48 : U32) && (c <= 57 : U32) && fraction(tail, left, positive || (c > 48 : U32))
    case _ 0n: False{}

def quality(s: String) -> Bool:
  match s:
    case "1": True{}
    case "1.": True{}
    case "1.0": True{}
    case "1.00": True{}
    case "1.000": True{}
    case SCon{Chr{48}, SCon{Chr{46}, tail}}: fraction(tail, 3n, False{})
    case _: False{}

# Preserve quoted extension parameters so delimiters inside them cannot move
# a range's q=0 onto a different apparent media range.
type Split is Data:
  Split{quoted: Bool, escaped: Bool, part: String, parts: List<&2, String>}

def split_cut(c: Char, part: String, parts: List<&2, String>, cut: Bool) -> Split:
  match cut:
    case True{}: Split{False{}, False{}, "", String.reverse(part) <> parts}
    case False{}: Split{False{}, False{}, SCon{c, part}, parts}

def split_char(quoted: Bool, escaped: Bool, +c: Char, delimiter: Char, part: String, parts: List<&2, String>) -> Split:
  match quoted escaped c:
    case True{} True{} _: Split{True{}, False{}, SCon{c, part}, parts}
    case True{} False{} Chr{92}: Split{True{}, True{}, SCon{c, part}, parts}
    case True{} False{} Chr{34}: Split{False{}, False{}, SCon{c, part}, parts}
    case True{} False{} _: Split{True{}, False{}, SCon{c, part}, parts}
    case False{} _ Chr{34}: Split{True{}, False{}, SCon{c, part}, parts}
    case False{} _ _: split_cut(c, part, parts, Char.is_eq(c, delimiter))

def split_end(state: Split) -> List<&2, String>:
  match state:
    case Split{False{}, escaped, part, parts}: List.reverse(&2, String, String.reverse(part) <> parts)
    case _: []

def split_go(s: String, +delimiter: Char, state: Split) -> List<&2, String>:
  match s:
    case SNil{}: split_end(state)
    case SCon{c, tail}:
      Split{quoted, escaped, part, parts} = state
      split_go(tail, delimiter, split_char(quoted, escaped, c, delimiter, part, parts))

def split(s: String, delimiter: Char) -> List<&2, String>:
  split_go(s, delimiter, Split{False{}, False{}, "", []})

def parameter(parts: List<&2, String>) -> Bool:
  match parts:
    case key <> value <> Nil{}:
      Bool.not(String.eq(trim(key), "q")) || quality(trim(value))
    case key <> Nil{}: Bool.not(String.eq(trim(key), "q"))
    case _: False{}

def parameters(xs: List<&2, String>) -> Bool:
  match xs:
    case Nil{}: True{}
    case x <> tail: parameter(split(trim(x), '=')) && parameters(tail)

def media(parts: List<&2, String>) -> Bool:
  match parts:
    case Nil{}: False{}
    case name <> rest: String.eq(trim(name), "application/json") && parameters(rest)

def accepts_json_tokens(xs: List<&2, String>) -> Bool:
  match xs:
    case Nil{}: False{}
    case x <> tail:
      media(split(Bytes.fold(x), ';')) || accepts_json_tokens(tail)

def accepts_json(value: Maybe<&2, String>) -> Bool:
  match value:
    case None{}: False{}
    case Some{s}: accepts_json_tokens(split(s, ','))
