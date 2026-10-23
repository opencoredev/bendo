# Canonical request-head writer. Only well_formed Req values round-trip;
# this deliberately writes no body and does not choose body framing.
import Base
import ./bytes.bend as Bytes
import ./request.bend as R

def header(h: R.Header, tail: List<&2, U32>) -> List<&2, U32>:
  match h:
    case R.Header{n, v}:
      Bytes.append(Bytes.encode(n), 58 <> 32 <> Bytes.append(v, 13 <> 10 <> tail))

def headers(hs: List<&2, R.Header>) -> List<&2, U32>:
  match hs:
    case Nil{}:
      [13, 10]
    case h <> t:
      header(h, headers(t))

def line_content(m: R.Method, p: String, q: Maybe<&2, String>, v: R.Version) -> List<&2, U32>:
  Bytes.encode(R.method_text(m) ++ " " ++ p ++ R.query_text(q) ++ " " ++ R.version_text(v))

def line(m: R.Method, p: String, q: Maybe<&2, String>, v: R.Version) -> List<&2, U32>:
  Bytes.append(line_content(m, p, q, v), [13, 10])

def write(r: R.Req) -> List<&2, U32>:
  match r:
    case R.Req{m, p, q, v, hs}:
      Bytes.append(line(m, p, q, v), headers(hs))
