# Test consumer of the public parser, writer and request accessors.
import Base
import ../../../src/http/parse.bend as P
import ../../../src/http/write.bend as W
import ../../../src/http/request.bend as R

def parse(xs: List<&2, U32>) -> R.ParseResult:
  P.parse(xs)

def write(r: R.Req) -> List<&2, U32>:
  W.write(r)

def lookup(hs: List<&2, R.Header>, n: String) -> List<&2, List<&2, U32>>:
  R.lookup(hs, n)

def well_formed(r: R.Req) -> Bool:
  R.well_formed(r)

def initial() -> P.State:
  P.initial()

def feed(xs: List<&2, U32>, s: P.State) -> P.State & R.ParseResult:
  P.feed(xs, s)
