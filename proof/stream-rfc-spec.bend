# RFC 9112 section 7.1, extension-free and trailer-free subset.
# chunked-body = *chunk last-chunk CRLF
# chunk = 1*HEXDIG CRLF chunk-data CRLF (size > 0)
# last-chunk = 1*"0" CRLF; the canonical writer emits one zero.
# This parser accepts lowercase hex, as Bendo emits.
# A zero size switches irrevocably to the empty trailer section; it can never
# be read as a data chunk. Parsing stops there and returns all unconsumed input.
# Independent specification: Base only, no encoder or runtime decoder helpers.
import Base

type DecodeResult is Data:
  NeedMore{}
  Decoded{body: List<&2, U32>, rest: List<&2, U32>}
  Error{status: U32}

type State is Data:
  Size{budget: U32, body: List<&2, U32>, line: List<&2, U32>, count: U32, cr: Bool}
  Payload{budget: U32, body: List<&2, U32>, left: U32}
  DataCR{budget: U32, body: List<&2, U32>}
  DataLF{budget: U32, body: List<&2, U32>}
  EndCR{body: List<&2, U32>}
  EndLF{body: List<&2, U32>}
  Complete{body: List<&2, U32>}
  Failed{status: U32}

def branch(-A: Type, ok: Bool, yes: Unit -> A, no: Unit -> A) -> A:
  match ok:
    case True{}: yes(Unit{})
    case False{}: no(Unit{})

def hex(+c: U32) -> Bool:
  ((48 <= c : U32) && (c <= 57 : U32)) || ((97 <= c : U32) && (c <= 102 : U32))

def hex_digit(+c: U32) -> U32:
  Bool.pick(U32, (c <= 57 : U32), (c - 48 : U32), (c - 87 : U32))

def size_result(n: U32, ok: Bool) -> Maybe<&2, U32>:
  match ok:
    case True{}: Some{n}
    case False{}: None{}

# Check the digit grammar and overflow before numeric accumulation.
def size_digits(xs: List<&2, U32>, +n: U32, seen: Bool) -> Maybe<&2, U32>:
  match xs:
    case Nil{}: size_result(n, seen)
    case +c <> +t:
      branch(Maybe<&2, U32>, hex(c),
        u => branch(Maybe<&2, U32>, (n <= 268435455 : U32),
          u => size_digits(t, (16 * n + hex_digit(c) : U32), True{}), u => None{}),
        u => None{})

def start_size(+budget: U32, body: List<&2, U32>, +n: U32, zero: Bool) -> State:
  match zero:
    case True{}: EndCR{body}
    case False{}:
      Bool.pick(State, (n <= budget : U32), Payload{(budget - n : U32), body, n}, Failed{413})

def start_chunk(budget: U32, body: List<&2, U32>, size: Maybe<&2, U32>) -> State:
  match size:
    case None{}: Failed{400}
    case Some{+n}: start_size(budget, body, n, U32.is_eq(n, 0))

def size_octet_inner(budget: U32, body: List<&2, U32>, line: List<&2, U32>, count: U32, cr: Bool, +c: U32) -> State:
  match cr c:
    case True{} 10:
      start_chunk(budget, body, size_digits(List.reverse(&2, U32, line), 0, False{}))
    case True{} _: Failed{400}
    case False{} 13: Size{budget, body, line, count, True{}}
    case False{} c:
      Bool.pick(State, hex(c), Size{budget, body, c <> line, count, False{}}, Failed{400})

def size_octet(budget: U32, body: List<&2, U32>, line: List<&2, U32>, +count: U32, cr: Bool, c: U32) -> State:
  branch(State, (count < 8192 : U32), u => size_octet_inner(budget, body, line, (count + 1 : U32), cr, c), u => Failed{400})

def data_rest(budget: U32, body: List<&2, U32>, +left: U32, zero: Bool) -> State:
  match zero:
    case True{}: Failed{400}
    case False{}: Payload{budget, body, (left - 1 : U32)}

def data_next(budget: U32, body: List<&2, U32>, +left: U32, last: Bool) -> State:
  match last:
    case True{}: DataCR{budget, body}
    case False{}: data_rest(budget, body, left, U32.is_eq(left, 0))

def data_left(budget: U32, body: List<&2, U32>, +left: U32, c: U32) -> State:
  data_next(budget, c <> body, left, U32.is_eq(left, 1))

def data_octet(budget: U32, body: List<&2, U32>, left: U32, +c: U32) -> State:
  branch(State, (c <= 255 : U32), u => data_left(budget, body, left, c), u => Failed{400})

# Every mandatory CR and LF is consumed in a separate grammar state.
def advance(s: State, c: U32) -> State:
  match s c:
    case Size{budget, body, line, count, cr} c: size_octet(budget, body, line, count, cr, c)
    case Payload{budget, body, left} c: data_octet(budget, body, left, c)
    case DataCR{budget, body} 13: DataLF{budget, body}
    case DataLF{budget, body} 10: Size{budget, body, [], 0, False{}}
    case EndCR{body} 13: EndLF{body}
    case EndLF{body} 10: Complete{List.reverse(&2, U32, body)}
    case Complete{body} _: Complete{body}
    case Failed{status} _: Failed{status}
    case _ _: Failed{400}

def feed(xs: List<&2, U32>, s: State) -> State & DecodeResult:
  match xs s:
    case xs Complete{+body}: (Complete{body}, Decoded{body, xs})
    case _ Failed{+status}: (Failed{status}, Error{status})
    case Nil{} s: (s, NeedMore{})
    case c <> t s: feed(t, advance(s, c))

def result(pair: State & DecodeResult) -> DecodeResult:
  (s, r) = pair
  r

def parse(xs: List<&2, U32>, limit: U32) -> DecodeResult:
  result(feed(xs, Size{limit, [], [], 0, False{}}))
