# Pure incremental framing. The runtime sends one frame before pulling again.
# A stream with no length up front uses chunked encoding; one that declares
# its length (BND-91) sends Content-Length and raw octets, and must produce
# exactly that many.
import Base
import ./chunked.bend as Chunked
import ./bytes.bend as Bytes
import ./request.bend as Request
import ./write_response.bend as Write

def chunk(bytes: List<&2, U32>) -> List<&2, U32>:
  Chunked.encode_chunk(bytes, [])

def end() -> List<&2, U32>:
  [48, 13, 10, 13, 10]

# The sequence of writes, independently of how TCP partitions each write.
def wire(chunks: List<&2, List<&2, U32>>) -> List<&2, U32>:
  match chunks:
    case Nil{}: end()
    case bytes <> rest: Chunked.encode_chunk(bytes, wire(rest))

# Head fields. Application Content-Length and Transfer-Encoding are always
# replaced. A body-bearing stream is chunked without a length and carries
# exactly its declared length otherwise.
def body_fields(length: Maybe<&2, Nat>, hs: List<&2, Request.Header>) -> List<&2, Request.Header>:
  match length:
    case None{}: Request.Header{"transfer-encoding", Bytes.encode("chunked")} <> Write.headers(hs)
    case Some{n}: Write.length_header(n) <> Write.headers(hs)

def unsized_fields(+method: Request.Method, +status: U32, hs: List<&2, Request.Header>) -> List<&2, Request.Header>:
  Write.framing_headers(status, [], None{}, Write.headers(hs), Bool.not(U32.is_eq(status, 205)) || Write.tunnel(method, status))

def head_fields(+method: Request.Method, +status: U32, length: Maybe<&2, Nat>, hs: List<&2, Request.Header>, same: Bool) -> List<&2, Request.Header>:
  match same:
    case True{}: body_fields(length, hs)
    case False{}: unsized_fields(method, status, hs)

def known(length: Maybe<&2, Nat>) -> Bool:
  match length:
    case None{}: False{}
    case Some{n}: True{}

# A suppressed body (HEAD, 1xx, 204, 205, 304, successful CONNECT). HEAD of a
# status that allows a body gets the fields GET would get when the length is
# known; without a length there is no fabricated one, as before.
def bodyless_fields(+method: Request.Method, +status: U32, +length: Maybe<&2, Nat>, hs: List<&2, Request.Header>) -> List<&2, Request.Header>:
  head_fields(method, status, length, hs, Write.is_head(method) && Write.allows_body(status) && known(length))

# HTTP/1.0 has no chunked encoding. A stream of known length needs none.
def version_ok(version: Request.Version, +length: Maybe<&2, Nat>) -> Bool:
  match version:
    case Request.Http11{}: True{}
    case Request.Http10{}: known(length)

# What a sized body may still send: Open for a chunked stream, Left{n} with
# n octets owed, Over once a chunk would overrun the declared length.
type Budget is Data:
  Open{}
  Left{owed: Nat}
  Over{}

def budget(length: Maybe<&2, Nat>) -> Budget:
  match length:
    case None{}: Open{}
    case Some{n}: Left{n}

# The octets owed after sending bytes, or None if bytes exceed n.
def spend(bytes: List<&2, U32>, n: Nat) -> Maybe<&2, Nat>:
  match bytes n:
    case Nil{} n: Some{n}
    case b <> t 0n: None{}
    case b <> t 1n+m: spend(t, m)

def left_of(owed: Maybe<&2, Nat>) -> Budget:
  match owed:
    case None{}: Over{}
    case Some{n}: Left{n}

def charge(bytes: List<&2, U32>, b: Budget) -> Budget:
  match b:
    case Open{}: Open{}
    case Left{n}: left_of(spend(bytes, n))
    case Over{}: Over{}

def within(b: Budget) -> Bool:
  match b:
    case Over{}: False{}
    case _: True{}

# The write for one producer chunk.
def encoded(bytes: List<&2, U32>, b: Budget) -> List<&2, U32>:
  match b:
    case Open{}: chunk(bytes)
    case _: bytes

# The final write after End, or None when the stream must abort: a sized
# body that is still owed octets, or overran.
def last(b: Budget) -> Maybe<&2, List<&2, U32>>:
  match b:
    case Open{}: Some{end()}
    case Left{0n}: Some{[]}
    case Left{1n+n}: None{}
    case Over{}: None{}

# Model of a finished stream: every write in order, or None for an abort.
def prepend(bytes: List<&2, U32>, r: Maybe<&2, List<&2, U32>>) -> Maybe<&2, List<&2, U32>>:
  match r:
    case None{}: None{}
    case Some{tail}: Some{List.append(&2, U32, bytes, tail)}

def sent(chunks: List<&2, List<&2, U32>>, +b: Budget) -> Maybe<&2, List<&2, U32>>:
  match chunks:
    case Nil{}: last(b)
    case +bytes <> rest: prepend(encoded(bytes, b), sent(rest, charge(bytes, b)))

# Spec: bytes has exactly n octets.
def exact(bytes: List<&2, U32>, n: Nat) -> Bool:
  match bytes n:
    case Nil{} 0n: True{}
    case Nil{} 1n+m: False{}
    case b <> t 0n: False{}
    case b <> t 1n+m: exact(t, m)

def pick(ok: Bool, bytes: List<&2, U32>) -> Maybe<&2, List<&2, U32>>:
  match ok:
    case True{}: Some{bytes}
    case False{}: None{}

def exactly(+bytes: List<&2, U32>, n: Nat) -> Maybe<&2, List<&2, U32>>:
  pick(exact(bytes, n), bytes)
