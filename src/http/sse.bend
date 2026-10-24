# Pure Server-Sent Events encoding (WHATWG HTML, "Interpreting an event stream").
# Fields are octets. CR, LF and colon are ASCII, so no UTF-8 multi-octet
# sequence contains them and octet-level line handling equals text handling.
import Base
import ../data/utf8.bend as Utf8

type Frame is Data:
  Message{event: Maybe<&2, List<&2, U32>>, data: List<&2, U32>, id: Maybe<&2, List<&2, U32>>, retry: Maybe<&2, U32>}
  Comment{text: List<&2, U32>}

# Field and line constants, spelled as octets.
def event_prefix() -> List<&2, U32>: [101, 118, 101, 110, 116, 58, 32]
def data_prefix() -> List<&2, U32>: [100, 97, 116, 97, 58, 32]
def id_prefix() -> List<&2, U32>: [105, 100, 58, 32]
def retry_prefix() -> List<&2, U32>: [114, 101, 116, 114, 121, 58, 32]

# A source line break inside data starts the next "data: " line.
def data_break() -> List<&2, U32>: [10, 100, 97, 116, 97, 58, 32]

# One data octet. CR, LF and CRLF each become one line break: an LF right after
# a CR is part of that CR's break. `cr` says the previous octet was a CR.
def data_octet(+c: U32, lf: Bool, here: Bool, cr: Bool) -> List<&2, U32>:
  match lf here:
    case True{} _:
      match cr:
        case True{}: []
        case False{}: data_break()
    case False{} True{}: data_break()
    case False{} False{}: [c]

def data_lines(xs: List<&2, U32>, cr: Bool) -> List<&2, U32>:
  match xs:
    case Nil{}: []
    case +c <> t:
      List.append(&2, U32, data_octet(c, U32.is_eq(c, 10), U32.is_eq(c, 13), cr), data_lines(t, U32.is_eq(c, 13)))

def digit(k: Nat) -> U32:
  match k:
    case 0n: 48
    case 1n: 49
    case 2n: 50
    case 3n: 51
    case 4n: 52
    case 5n: 53
    case 6n: 54
    case 7n: 55
    case 8n: 56
    case 9n: 57
    case _: 48

def branch(-A: Type, ok: Bool, yes: Unit -> A, no: Unit -> A) -> A:
  match ok:
    case True{}: yes(Unit{})
    case False{}: no(Unit{})

# Base-ten digits without leading zeros, most significant first. Each call
# divides by ten, so fuel equal to the number itself always suffices.
def nat_digits(fuel: Nat, +k: Nat) -> List<&2, U32>:
  match fuel:
    case 0n: [digit(k)]
    case 1n+f:
      branch(List<&2, U32>, Nat.is_lt(k, 10n), u => [digit(k)], u => List.append(&2, U32, nat_digits(f, Nat.div(k, 10n)), [digit(Nat.mod(k, 10n))]))

def decimal(n: U32) -> List<&2, U32>:
  +k = U32.to_nat(n)
  nat_digits(k, k)

def event_line(event: Maybe<&2, List<&2, U32>>) -> List<&2, U32>:
  match event:
    case None{}: []
    case Some{name}: List.append(&2, U32, event_prefix(), List.append(&2, U32, name, [10]))

def data_line(data: List<&2, U32>) -> List<&2, U32>:
  List.append(&2, U32, data_prefix(), List.append(&2, U32, data_lines(data, False{}), [10]))

def id_line(id: Maybe<&2, List<&2, U32>>) -> List<&2, U32>:
  match id:
    case None{}: []
    case Some{value}: List.append(&2, U32, id_prefix(), List.append(&2, U32, value, [10]))

def retry_line(retry: Maybe<&2, U32>) -> List<&2, U32>:
  match retry:
    case None{}: []
    case Some{ms}: List.append(&2, U32, retry_prefix(), List.append(&2, U32, decimal(ms), [10]))

# Unchecked rendering. The runtime sends only `encode`, which checks first.
def render(frame: Frame) -> List<&2, U32>:
  match frame:
    case Message{event, data, id, retry}:
      List.append(&2, U32, event_line(event), List.append(&2, U32, data_line(data), List.append(&2, U32, id_line(id), List.append(&2, U32, retry_line(retry), [10]))))
    case Comment{text}: 58 <> List.append(&2, U32, text, [10])

# The octets a stream of frames writes, independently of TCP partitioning.
def wire(frames: List<&2, Frame>) -> List<&2, U32>:
  match frames:
    case Nil{}: []
    case f <> rest: List.append(&2, U32, render(f), wire(rest))

# Single-line fields must not contain a line break, or the value would end
# early and the rest would parse as new fields or events. An id must also not
# contain NUL, which makes receivers ignore the whole id field.
def line_safe(xs: List<&2, U32>) -> Bool:
  match xs:
    case Nil{}: True{}
    case +c <> t: Bool.not(U32.is_eq(c, 10)) && Bool.not(U32.is_eq(c, 13)) && line_safe(t)

def id_safe(xs: List<&2, U32>) -> Bool:
  match xs:
    case Nil{}: True{}
    case +c <> t: Bool.not(U32.is_eq(c, 10)) && Bool.not(U32.is_eq(c, 13)) && Bool.not(U32.is_eq(c, 0)) && id_safe(t)

def same(xs: List<&2, U32>, ys: List<&2, U32>) -> Bool:
  match xs ys:
    case Nil{} Nil{}: True{}
    case Nil{} _: False{}
    case _ Nil{}: False{}
    case +a <> s +b <> t: U32.is_eq(a, b) && same(s, t)

def canonical(decoded: Maybe<&2, String>, xs: List<&2, U32>) -> Bool:
  match decoded:
    case None{}: False{}
    case Some{+s}: Utf8.valid(s) && same(Utf8.encode(s), xs)

# The octets are exactly the UTF-8 encoding of Unicode scalar values, so a
# receiver's UTF-8 decoding replaces nothing and the text equals these octets.
def utf8_text(+xs: List<&2, U32>) -> Bool:
  canonical(Utf8.decode(xs), xs)

def event_safe(event: Maybe<&2, List<&2, U32>>) -> Bool:
  match event:
    case None{}: True{}
    case Some{+name}: line_safe(name) && utf8_text(name)

def id_field_safe(id: Maybe<&2, List<&2, U32>>) -> Bool:
  match id:
    case None{}: True{}
    case Some{+value}: id_safe(value) && utf8_text(value)

def valid(frame: Frame) -> Bool:
  match frame:
    case Message{event, +data, id, retry}: event_safe(event) && id_field_safe(id) && utf8_text(data)
    case Comment{+text}: line_safe(text) && utf8_text(text)

def checked(frame: Frame, ok: Bool) -> Maybe<&2, List<&2, U32>>:
  match ok:
    case True{}: Some{render(frame)}
    case False{}: None{}

# Data may contain any text, including CR and LF. A frame with an unsafe event
# name, id or comment, or with octets that are not UTF-8 text, is rejected
# whole: Bendo never strips, escapes, replaces or truncates it.
def encode(+frame: Frame) -> Maybe<&2, List<&2, U32>>:
  checked(frame, valid(frame))
