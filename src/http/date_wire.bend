# Date at the transport boundary for structured responses, legacy byte handlers
# and transport-generated errors. Existing Date fields skip the clock.
import Base
import ./bytes.bend as Bytes
import ./parse.bend as Parse
import ./date.bend as Date
import ../effects/clock.bend as Clock

def date_field(field: Parse.Field) -> Bool:
  match field:
    case Parse.Field{n, v}: String.eq(Bytes.fold(n), "date")
    case Parse.MissingColon{}: False{}

# Traverse the finite head only; never inspect body text as fields.
def has_date(xs: List<&2, U32>, line: List<&2, U32>, found: Bool) -> Bool:
  match xs line:
    case 13 <> 10 <> rest Nil{}: found
    case 13 <> 10 <> rest line:
      has_date(rest, [], found || date_field(Parse.field(List.reverse(&2, U32, line))))
    case c <> rest line: has_date(rest, c <> line, found)
    case _ _: True{}

# The HTTP/1.x status begins at byte 9. 1xx needs no generated Date.
def informational(xs: List<&2, U32>) -> Bool:
  match xs:
    case 72 <> 84 <> 84 <> 80 <> 47 <> 49 <> 46 <> version <> 32 <> 49 <> rest: True{}
    case _: False{}

def server_error(xs: List<&2, U32>) -> Bool:
  match xs:
    case 72 <> 84 <> 84 <> 80 <> 47 <> 49 <> 46 <> version <> 32 <> 53 <> rest: True{}
    case _: False{}

def close_field(field: Parse.Field) -> Bool:
  match field:
    case Parse.Field{n, v}:
      String.eq(Bytes.fold(n), "connection") && String.eq(Bytes.fold(Bytes.ascii(Bytes.trim(v))), "close")
    case Parse.MissingColon{}: False{}

# Transport Connection fields are normalized to the single value close.
def closing(xs: List<&2, U32>, line: List<&2, U32>, found: Bool) -> Bool:
  match xs line:
    case 13 <> 10 <> rest Nil{}: found
    case 13 <> 10 <> rest line:
      closing(rest, [], found || close_field(Parse.field(List.reverse(&2, U32, line))))
    case c <> rest line: closing(rest, c <> line, found)
    case _ _: found

def fallback(close: Bool) -> List<&2, U32>:
  match close:
    case True{}: Bytes.encode("HTTP/1.1 500 Internal Server Error\r\ncontent-length: 0\r\nconnection: close\r\n\r\n")
    case False{}: Bytes.encode("HTTP/1.1 500 Internal Server Error\r\ncontent-length: 0\r\n\r\n")

def unavailable(xs: List<&2, U32>, keep: Bool) -> List<&2, U32>:
  match keep:
    case True{}: xs
    case False{}: fallback(closing(xs, [], False{}))

def insert(xs: List<&2, U32>, rev: List<&2, U32>, date: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case 13 <> 10 <> 13 <> 10 <> rest:
      Bytes.append(List.reverse(&2, U32, rev), Bytes.append([13, 10], Bytes.append(date, Bytes.append([13, 10, 13, 10], rest))))
    case c <> rest: insert(rest, c <> rev, date)
    case _: List.reverse(&2, U32, rev)

def sampled(sample: Result<&1, &1, U32 & String, Nat>, +xs: List<&2, U32>) -> List<&2, U32>:
  match sample:
    case Done{s}: insert(xs, [], Bytes.encode("date: " ++ Date.format_imf(s)))
    case Fail{error}: unavailable(xs, server_error(xs))

def ensure_missing(xs: List<&2, U32>, needed: Bool) -> IO(List<&2, U32>):
  match needed:
    case False{}: IO.pure(List<&2, U32>, xs)
    case True{}:
      do IO<List<&2, U32>>:
        sample : Result<&1, &1, U32 & String, Nat> <- Clock.wall_seconds()
        return sampled(sample, xs)

def ensure(+xs: List<&2, U32>) -> IO(List<&2, U32>):
  ensure_missing(xs, Bool.not(informational(xs) || has_date(xs, [], False{})))
