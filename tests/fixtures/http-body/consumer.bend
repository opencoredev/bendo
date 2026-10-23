import Base
import ../../../src/http/chunked.bend as C
import ../../../src/http/body.bend as B

def initial(limit: U32) -> C.State:
  C.initial(limit)

def feed(xs: List<&2, U32>, s: C.State) -> C.State & C.DecodeResult:
  C.feed(xs, s)

def decode(xs: List<&2, U32>, limit: U32) -> C.DecodeResult:
  C.decode(xs, limit)
