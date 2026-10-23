# WHATWG HTML, section 9.2.6 "Interpreting an event stream", over octets.
# Independent specification: Base only, no Bendo encoder or runtime helpers.
#
# stream = [ bom ] *event end-of-stream
# A line ends at CRLF, LF or CR. An empty line dispatches the event. A line
# starting with ":" is a comment. Otherwise the field name runs to the first
# colon, and the value follows it, less one leading space if present. A line
# with no colon is a field name with an empty value.
#
# Fields: "event" sets the event type buffer. "data" appends the value and an
# LF to the data buffer. "id" sets the last event ID buffer unless the value
# contains NUL. "retry" reports the base-ten reconnection time when the value
# is ASCII digits; this spec requires at least one digit. Other fields are
# ignored.
#
# Dispatch sets the event's last event ID from the buffer, which persists
# across events. An empty data buffer dispatches nothing. Otherwise one final
# LF is removed, an empty type means "message", and both buffers reset. An
# event still pending at end of stream is discarded, as is an unterminated
# final line. CR, LF, colon, space and NUL are ASCII, so parsing octets of
# UTF-8 equals parsing the decoded text.
import Base

type Observed is Data:
  Dispatched{kind: List<&2, U32>, data: List<&2, U32>, id: List<&2, U32>}
  Reconnect{ms: Nat}

type Buffers is Data:
  Buffers{kind: List<&2, U32>, data: List<&2, U32>, id: List<&2, U32>, out: List<&2, Observed>}

type State is Data:
  Begin{b: Buffers}
  BeginCR{b: Buffers}
  Field{b: Buffers, name: List<&2, U32>}
  Colon{b: Buffers, name: List<&2, U32>}
  Value{b: Buffers, name: List<&2, U32>, value: List<&2, U32>}
  Skip{b: Buffers}

def event_name() -> List<&2, U32>: [101, 118, 101, 110, 116]
def data_name() -> List<&2, U32>: [100, 97, 116, 97]
def id_name() -> List<&2, U32>: [105, 100]
def retry_name() -> List<&2, U32>: [114, 101, 116, 114, 121]
def message() -> List<&2, U32>: [109, 101, 115, 115, 97, 103, 101]

def same(xs: List<&2, U32>, ys: List<&2, U32>) -> Bool:
  match xs ys:
    case Nil{} Nil{}: True{}
    case Nil{} _: False{}
    case _ Nil{}: False{}
    case +a <> s +b <> t: U32.is_eq(a, b) && same(s, t)

def has_nul(xs: List<&2, U32>) -> Bool:
  match xs:
    case Nil{}: False{}
    case +c <> t: U32.is_eq(c, 0) || has_nul(t)

def ascii_digit(+c: U32) -> Bool:
  (48 <= c : U32) && (c <= 57 : U32)

def all_digits(xs: List<&2, U32>) -> Bool:
  match xs:
    case Nil{}: True{}
    case +c <> t: ascii_digit(c) && all_digits(t)

# Base-ten value, most significant digit first.
def decimal_value(xs: List<&2, U32>, acc: Nat) -> Nat:
  match xs:
    case Nil{}: acc
    case +c <> t: decimal_value(t, Nat.add(Nat.mul(acc, 10n), U32.to_nat((c - 48 : U32))))

def digits(xs: List<&2, U32>) -> Bool:
  match xs:
    case Nil{}: False{}
    case +c <> t: ascii_digit(c) && all_digits(t)

# The data a receiver sees for a multi-line value: CRLF, CR and LF each become
# one LF. `cr` says the previous octet was a CR, so an LF there is dropped.
def newline_octet(+c: U32, lf: Bool, here: Bool, cr: Bool) -> List<&2, U32>:
  match lf here:
    case True{} _:
      match cr:
        case True{}: []
        case False{}: [10]
    case False{} True{}: [10]
    case False{} False{}: [c]

def newlines(xs: List<&2, U32>, cr: Bool) -> List<&2, U32>:
  match xs:
    case Nil{}: []
    case +c <> t:
      List.append(&2, U32, newline_octet(c, U32.is_eq(c, 10), U32.is_eq(c, 13), cr), newlines(t, U32.is_eq(c, 13)))

def event_type(t: List<&2, U32>) -> List<&2, U32>:
  match t:
    case Nil{}: message()
    case c <> rest: c <> rest

def last_lf(+c: U32, lf: Bool) -> List<&2, U32>:
  match lf:
    case True{}: []
    case False{}: [c]

# Remove one final LF, if any.
def drop_lf(xs: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}: []
    case +c <> Nil{}: last_lf(c, U32.is_eq(c, 10))
    case c <> t: c <> drop_lf(t)

def deliver(t: List<&2, U32>, data: List<&2, U32>, +id: List<&2, U32>, out: List<&2, Observed>) -> Buffers:
  match data:
    case Nil{}: Buffers{[], [], id, out}
    case c <> rest: Buffers{[], [], id, List.append(&2, Observed, out, [Dispatched{event_type(t), drop_lf(c <> rest), id}])}

def dispatch(b: Buffers) -> Buffers:
  Buffers{t, data, id, out} = b
  deliver(t, data, id, out)

def set_type(b: Buffers, value: List<&2, U32>) -> Buffers:
  Buffers{t, data, id, out} = b
  Buffers{value, data, id, out}

def add_data(b: Buffers, value: List<&2, U32>) -> Buffers:
  Buffers{t, data, id, out} = b
  Buffers{t, List.append(&2, U32, data, List.append(&2, U32, value, [10])), id, out}

def set_id(nul: Bool, b: Buffers, value: List<&2, U32>) -> Buffers:
  match nul:
    case True{}: b
    case False{}:
      Buffers{t, data, id, out} = b
      Buffers{t, data, value, out}

def set_retry(ok: Bool, b: Buffers, value: List<&2, U32>) -> Buffers:
  match ok:
    case True{}:
      Buffers{t, data, id, out} = b
      Buffers{t, data, id, List.append(&2, Observed, out, [Reconnect{decimal_value(value, 0n)}])}
    case False{}: b

def field_by(b: Buffers, +value: List<&2, U32>, event: Bool, data: Bool, id: Bool, retry: Bool) -> Buffers:
  match event data id retry:
    case True{} _ _ _: set_type(b, value)
    case False{} True{} _ _: add_data(b, value)
    case False{} False{} True{} _: set_id(has_nul(value), b, value)
    case False{} False{} False{} True{}: set_retry(digits(value), b, value)
    case False{} False{} False{} False{}: b

def field(b: Buffers, +name: List<&2, U32>, value: List<&2, U32>) -> Buffers:
  field_by(b, value, same(name, event_name()), same(name, data_name()), same(name, id_name()), same(name, retry_name()))

# The buffers after the current line ends.
def finish(s: State) -> Buffers:
  match s:
    case Begin{b}: dispatch(b)
    case BeginCR{b}: dispatch(b)
    case Field{b, name}: field(b, name, [])
    case Colon{b, name}: field(b, name, [])
    case Value{b, name, value}: field(b, name, value)
    case Skip{b}: b

# An LF right after a CR belongs to that CR's line ending.
def line_feed(s: State) -> State:
  match s:
    case BeginCR{b}: Begin{b}
    case Begin{b}: Begin{dispatch(b)}
    case Field{b, name}: Begin{field(b, name, [])}
    case Colon{b, name}: Begin{field(b, name, [])}
    case Value{b, name, value}: Begin{field(b, name, value)}
    case Skip{b}: Begin{b}

def begin_octet(b: Buffers, +c: U32, colon: Bool) -> State:
  match colon:
    case True{}: Skip{b}
    case False{}: Field{b, [c]}

def name_octet(b: Buffers, name: List<&2, U32>, +c: U32, colon: Bool) -> State:
  match colon:
    case True{}: Colon{b, name}
    case False{}: Field{b, List.append(&2, U32, name, [c])}

def first_value_octet(b: Buffers, name: List<&2, U32>, +c: U32, space: Bool) -> State:
  match space:
    case True{}: Value{b, name, []}
    case False{}: Value{b, name, [c]}

# Any octet other than CR or LF.
def octet(s: State, +c: U32) -> State:
  match s:
    case Begin{b}: begin_octet(b, c, U32.is_eq(c, 58))
    case BeginCR{b}: begin_octet(b, c, U32.is_eq(c, 58))
    case Field{b, name}: name_octet(b, name, c, U32.is_eq(c, 58))
    case Colon{b, name}: first_value_octet(b, name, c, U32.is_eq(c, 32))
    case Value{b, name, value}: Value{b, name, List.append(&2, U32, value, [c])}
    case Skip{b}: Skip{b}

def classify(s: State, +c: U32, cr: Bool, lf: Bool) -> State:
  match cr lf:
    case True{} _: BeginCR{finish(s)}
    case False{} True{}: line_feed(s)
    case False{} False{}: octet(s, c)

def step(s: State, +c: U32) -> State:
  classify(s, c, U32.is_eq(c, 13), U32.is_eq(c, 10))

def run(xs: List<&2, U32>, s: State) -> State:
  match xs:
    case Nil{}: s
    case +c <> t: run(t, step(s, c))

def buffers(s: State) -> Buffers:
  match s:
    case Begin{b}: b
    case BeginCR{b}: b
    case Field{b, name}: b
    case Colon{b, name}: b
    case Value{b, name, value}: b
    case Skip{b}: b

def observed(b: Buffers) -> List<&2, Observed>:
  Buffers{t, data, id, out} = b
  out

# The UTF-8 decoder strips one leading byte order mark, EF BB BF.
def bom_third(+a: U32, +b: U32, t: List<&2, U32>) -> List<&2, U32>:
  match t:
    case Nil{}: [a, b]
    case +c <> +rest: Bool.pick(List<&2, U32>, U32.is_eq(c, 191), rest, a <> b <> c <> rest)

def bom_second(lead: Bool, +a: U32, t: List<&2, U32>) -> List<&2, U32>:
  match lead t:
    case False{} t: a <> t
    case True{} Nil{}: [a]
    case True{} +b <> +rest: Bool.pick(List<&2, U32>, U32.is_eq(b, 187), bom_third(a, b, rest), a <> b <> rest)

def strip_bom(xs: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}: []
    case +a <> t: bom_second(U32.is_eq(a, 239), a, t)

def initial() -> State:
  Begin{Buffers{[], [], [], []}}

# Every event and reconnection time a receiver reports, in stream order.
def parse(xs: List<&2, U32>) -> List<&2, Observed>:
  observed(buffers(run(strip_bom(xs), initial())))
