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

# Quality characters, tested once: 0, 1, another digit, the dot, or other.
type QChar is Data:
  QZero{}
  QOne{}
  QDigit{}
  QDot{}
  QOther{}

def qkind(zero: Bool, one: Bool, digit: Bool, dot: Bool) -> QChar:
  match zero one digit dot:
    case True{} _ _ _: QZero{}
    case False{} True{} _ _: QOne{}
    case False{} False{} True{} _: QDigit{}
    case False{} False{} False{} True{}: QDot{}
    case False{} False{} False{} False{}: QOther{}

def qchar(+c: U32) -> QChar:
  qkind(U32.is_eq(c, 48), U32.is_eq(c, 49), (c >= 48 : U32) && (c <= 57 : U32), U32.is_eq(c, 46))

def q_zero(k: QChar) -> Bool:
  match k:
    case QZero{}: True{}
    case _: False{}

def q_digit(k: QChar) -> Bool:
  match k:
    case QZero{}: True{}
    case QOne{}: True{}
    case QDigit{}: True{}
    case _: False{}

def q_positive(k: QChar) -> Bool:
  match k:
    case QOne{}: True{}
    case QDigit{}: True{}
    case _: False{}

def q_dot(k: QChar) -> Bool:
  match k:
    case QDot{}: True{}
    case _: False{}

# After "1.": at most fuel zeros.
def zeros(xs: String, fuel: Nat) -> Bool:
  match xs fuel:
    case SNil{} _: True{}
    case SCon{Chr{+c}, tail} 1n+left: q_zero(qchar(c)) && zeros(tail, left)
    case _ 0n: False{}

# After "0.": at most fuel digits, at least one of them nonzero.
def fraction(xs: String, fuel: Nat, positive: Bool) -> Bool:
  match xs fuel:
    case SNil{} _: positive
    case SCon{Chr{+c}, tail} 1n+left:
      q_digit(qchar(c)) && fraction(tail, left, positive || q_positive(qchar(c)))
    case _ 0n: False{}

def quality_tail(k: QChar, t: String) -> Bool:
  match k t:
    case QOne{} SNil{}: True{}
    case QOne{} SCon{Chr{+c}, u}: q_dot(qchar(c)) && zeros(u, 3n)
    case QZero{} SCon{Chr{+c}, u}: q_dot(qchar(c)) && fraction(u, 3n, False{})
    case _ _: False{}

def quality(s: String) -> Bool:
  match s:
    case SNil{}: False{}
    case SCon{Chr{+c}, t}: quality_tail(qchar(c), t)

# Preserve quoted extension parameters so delimiters inside them cannot move
# a range's q=0 onto a different apparent media range.
type Split is Data:
  Split{quoted: Bool, escaped: Bool, part: String, parts: List<&2, String>}

# Split characters, tested once: a quote, a backslash, the delimiter, or other.
type SChar is Data:
  SQuote{}
  SEscape{}
  SCut{}
  SPlain{}

def skind(quote: Bool, escape: Bool, cut: Bool) -> SChar:
  match quote escape cut:
    case True{} _ _: SQuote{}
    case False{} True{} _: SEscape{}
    case False{} False{} True{}: SCut{}
    case False{} False{} False{}: SPlain{}

def schar(c: Char, d: Char) -> SChar:
  match c d:
    case Chr{+x} Chr{y}: skind(U32.is_eq(x, 34), U32.is_eq(x, 92), U32.is_eq(x, y))

def split_char(quoted: Bool, escaped: Bool, k: SChar, c: Char, part: String, parts: List<&2, String>) -> Split:
  match quoted escaped k:
    case True{} True{} _: Split{True{}, False{}, SCon{c, part}, parts}
    case True{} False{} SEscape{}: Split{True{}, True{}, SCon{c, part}, parts}
    case True{} False{} SQuote{}: Split{False{}, False{}, SCon{c, part}, parts}
    case True{} False{} _: Split{True{}, False{}, SCon{c, part}, parts}
    case False{} _ SQuote{}: Split{True{}, False{}, SCon{c, part}, parts}
    case False{} _ SCut{}: Split{False{}, False{}, "", String.reverse(part) <> parts}
    case False{} _ _: Split{False{}, False{}, SCon{c, part}, parts}

def split_end(state: Split) -> List<&2, String>:
  match state:
    case Split{False{}, escaped, part, parts}: List.reverse(&2, String, String.reverse(part) <> parts)
    case _: []

def split_go(s: String, +delimiter: Char, state: Split) -> List<&2, String>:
  match s:
    case SNil{}: split_end(state)
    case SCon{+c, tail}:
      Split{quoted, escaped, part, parts} = state
      split_go(tail, delimiter, split_char(quoted, escaped, schar(c, delimiter), c, part, parts))

def split(s: String, delimiter: Char) -> List<&2, String>:
  split_go(s, delimiter, Split{False{}, False{}, "", []})

def parameter(parts: List<&2, String>) -> Bool:
  match parts:
    case key <> value <> Nil{}:
      Bool.not(String.eq(trim(key), "q")) || quality(trim(value))
    case key <> Nil{}: Bool.not(String.eq(trim(key), "q"))
    case _: False{}

def parameters_spec(xs: List<&2, String>) -> Bool:
  match xs:
    case Nil{}: True{}
    case x <> tail: parameter(split(trim(x), '=')) && parameters_spec(tail)

# List folds are tail loops over the reversed list (BND-84): a 64 KiB Accept
# field may hold tens of thousands of elements.
def parameters_go(rev: List<&2, String>, acc: Bool) -> Bool:
  match rev:
    case Nil{}: acc
    case x <> r: parameters_go(r, parameter(split(trim(x), '=')) && acc)

def parameters(xs: List<&2, String>) -> Bool:
  parameters_go(List.reverse(&2, String, xs), True{})

def media(parts: List<&2, String>) -> Bool:
  match parts:
    case Nil{}: False{}
    case name <> rest: String.eq(trim(name), "application/json") && parameters(rest)

def accepts_json_tokens_spec(xs: List<&2, String>) -> Bool:
  match xs:
    case Nil{}: False{}
    case x <> tail:
      media(split(Bytes.fold(x), ';')) || accepts_json_tokens_spec(tail)

def accepts_json_tokens_go(rev: List<&2, String>, acc: Bool) -> Bool:
  match rev:
    case Nil{}: acc
    case x <> r: accepts_json_tokens_go(r, media(split(Bytes.fold(x), ';')) || acc)

def accepts_json_tokens(xs: List<&2, String>) -> Bool:
  accepts_json_tokens_go(List.reverse(&2, String, xs), False{})

def accepts_json(value: Maybe<&2, String>) -> Bool:
  match value:
    case None{}: False{}
    case Some{s}: accepts_json_tokens(split(s, ','))
