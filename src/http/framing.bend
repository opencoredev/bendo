# RFC 9112 request framing. Header names/OWS have been normalized by Parse.
import Base
import ./bytes.bend as Bytes
import ./request.bend as R

type Framing is Data:
  NoBody{}
  Length{size: U32}
  Chunked{}
  Reject{status: U32}

def number_step(+n: U32, +c: U32, ok: Bool) -> Maybe<&2, U32>:
  match ok:
    case False{}:
      None{}
    case True{}:
      Some{(n * 10 + c - 48 : U32)}

def decimal(xs: List<&2, U32>, +n: U32) -> Maybe<&2, U32>:
  match xs:
    case Nil{}:
      Some{n}
    case +c <> t:
      +ok = (c >= 48 : U32) && (c <= 57 : U32) && ((n < 429496729 : U32) || (U32.is_eq(n, 429496729) && (c <= 53 : U32)))
      do Maybe<&2, U32>:
        next : U32 <- number_step(n, c, ok)
        decimal(t, next)

def bound_size(size: U32, over: Bool) -> Framing:
  match over:
    case True{}:
      Reject{413}
    case False{}:
      Length{size}

def bounded(n: Maybe<&2, U32>, +limit: U32) -> Framing:
  match n:
    case None{}:
      Reject{400}
    case Some{+size}:
      bound_size(size, (size > limit : U32))

def content_length(values: List<&2, List<&2, U32>>, limit: U32) -> Framing:
  match values:
    case Nil{}:
      NoBody{}
    case Nil{} <> Nil{}:
      Reject{400}
    case (c <> t) <> Nil{}:
      bounded(decimal(c <> t, 0), limit)
    case _:
      Reject{400}

def chunked_only(same: Bool) -> Framing:
  match same:
    case True{}:
      Chunked{}
    case False{}:
      Reject{400}

def transfer(v: R.Version, values: List<&2, List<&2, U32>>) -> Framing:
  match v values:
    case R.Http11{} value <> Nil{}:
      chunked_only(String.eq(Bytes.fold(Bytes.ascii(value)), "chunked"))
    case _ _:
      Reject{400}

def choose(v: R.Version, cls: List<&2, List<&2, U32>>, tes: List<&2, List<&2, U32>>, limit: U32) -> Framing:
  match cls tes:
    case cls Nil{}:
      content_length(cls, limit)
    case Nil{} tes:
      transfer(v, tes)
    case _ _:
      Reject{400}

def framing(r: R.Req, limit: U32) -> Framing:
  match r:
    case R.Req{m, p, q, v, +hs}:
      choose(v, R.lookup(hs, "content-length"), R.lookup(hs, "transfer-encoding"), limit)

# 0 = none, 100 = supported expectation, 417 = unsupported expectation.
def expect_value(same: Bool) -> U32:
  match same:
    case True{}:
      100
    case False{}:
      417

def expectation_values(v: R.Version, values: List<&2, List<&2, U32>>) -> U32:
  match v values:
    case _ Nil{}:
      0
    case R.Http11{} value <> Nil{}:
      expect_value(String.eq(Bytes.fold(Bytes.ascii(value)), "100-continue"))
    case R.Http10{} _:
      # RFC 9110: ignore Expect on HTTP/1.0.
      0
    case _ _:
      417

def expectation(r: R.Req) -> U32:
  match r:
    case R.Req{m, p, q, v, hs}:
      expectation_values(v, R.lookup(hs, "expect"))
