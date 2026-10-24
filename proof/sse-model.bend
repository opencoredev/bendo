# BND-49: what a receiver must observe for each frame Bendo sends, stated
# over the independent parser's results. No encoder helper defines it.
import Base
import ../src/http/sse.bend as Sse
import ./sse-spec.bend as Spec
import ../src/data/utf8.bend as Utf8

# No CR or LF: a single-line value cannot end early.
def one_line(xs: List<&2, U32>) -> Bool:
  match xs:
    case Nil{}: True{}
    case +c <> t: Bool.not(U32.is_eq(c, 10) || U32.is_eq(c, 13)) && one_line(t)

def scalars_of(decoded: Maybe<&2, String>, xs: List<&2, U32>) -> Bool:
  match decoded:
    case None{}: False{}
    case Some{+s}: Utf8.valid(s) && Spec.same(Utf8.encode(s), xs)

# Exactly the UTF-8 encoding of a String of Unicode scalar values. A browser
# decodes the stream as UTF-8 before parsing; on such octets that decoding
# replaces nothing, so the parsed octets are the UTF-8 of the browser's text.
def utf8_ok(+xs: List<&2, U32>) -> Bool:
  scalars_of(Utf8.decode(xs), xs)

def event_ok(event: Maybe<&2, List<&2, U32>>) -> Bool:
  match event:
    case None{}: True{}
    case Some{+name}: one_line(name) && utf8_ok(name)

# A receiver ignores an id field containing NUL.
def id_ok(id: Maybe<&2, List<&2, U32>>) -> Bool:
  match id:
    case None{}: True{}
    case Some{+value}: one_line(value) && Bool.not(Spec.has_nul(value)) && utf8_ok(value)

def frame_ok(frame: Sse.Frame) -> Bool:
  match frame:
    case Sse.Message{event, +data, id, retry}: event_ok(event) && id_ok(id) && utf8_ok(data)
    case Sse.Comment{+text}: one_line(text) && utf8_ok(text)

def admissible(frames: List<&2, Sse.Frame>) -> Bool:
  match frames:
    case Nil{}: True{}
    case +f <> rest: frame_ok(f) && admissible(rest)

def guarded(frame: Sse.Frame, ok: Bool) -> Maybe<&2, List<&2, U32>>:
  match ok:
    case True{}: Some{Sse.render(frame)}
    case False{}: None{}

# Send exactly the admissible frames, unchanged; reject the rest.
def guard(+frame: Sse.Frame) -> Maybe<&2, List<&2, U32>>:
  guarded(frame, frame_ok(frame))

def kind(event: Maybe<&2, List<&2, U32>>) -> List<&2, U32>:
  match event:
    case None{}: []
    case Some{name}: name

def next_id(last: List<&2, U32>, id: Maybe<&2, List<&2, U32>>) -> List<&2, U32>:
  match id:
    case None{}: last
    case Some{value}: value

def reconnect(retry: Maybe<&2, U32>) -> List<&2, Spec.Observed>:
  match retry:
    case None{}: []
    case Some{ms}: [Spec.Reconnect{U32.to_nat(ms)}]

# A message reports its retry value, then one event: its type (empty means
# "message"), its data with every CR, LF and CRLF as one LF, and the id in
# force. Comments report nothing.
def frame_events(last: List<&2, U32>, frame: Sse.Frame) -> List<&2, Spec.Observed>:
  match frame:
    case Sse.Message{event, data, +id, retry}:
      List.append(&2, Spec.Observed, reconnect(retry), [Spec.Dispatched{Spec.event_type(kind(event)), Spec.newlines(data, False{}), next_id(last, id)}])
    case Sse.Comment{text}: []

def after(last: List<&2, U32>, frame: Sse.Frame) -> List<&2, U32>:
  match frame:
    case Sse.Message{event, data, id, retry}: next_id(last, id)
    case Sse.Comment{text}: last

def observe(frames: List<&2, Sse.Frame>, +last: List<&2, U32>) -> List<&2, Spec.Observed>:
  match frames:
    case Nil{}: []
    case +f <> rest: List.append(&2, Spec.Observed, frame_events(last, f), observe(rest, after(last, f)))
