# BND-47: pure proxy helpers exported to tests through the .mjs build.
import Base
import ../../../src/http/upstream.bend as U
import ../../../src/http/proxy_headers.bend as Hop
import ../../../src/http/request.bend as Request
import ../../../src/http/bytes.bend as Bytes
import ../../../src/net/conn_info.bend as Conn

def parse_url(s: String) -> Maybe<&2, U.Upstream>:
  U.parse_url(s)

def forward(hs: List<&2, Request.Header>) -> List<&2, Request.Header>:
  Hop.forward(hs)

def response_headers(hs: List<&2, Request.Header>) -> List<&2, Request.Header>:
  U.response_headers(hs)

def head(xs: List<&2, U32>) -> U.HeadResult:
  U.head_feed(xs, U.head_initial())

def resume(r: U.HeadResult, ys: List<&2, U32>) -> U.HeadResult:
  match r:
    case U.More{s}: U.head_feed(ys, s)
    case U.Got{status, version, hs, rest}: U.Got{status, version, hs, Bytes.append(rest, ys)}
    case U.Malformed{}: U.Malformed{}

def head_split(xs: List<&2, U32>, ys: List<&2, U32>) -> U.HeadResult:
  resume(U.head_feed(xs, U.head_initial()), ys)

def framing(head_request: Bool, status: U32, http11: Bool, hs: List<&2, Request.Header>) -> U.Framing:
  match http11:
    case True{}: U.framing(head_request, status, Request.Http11{}, hs)
    case False{}: U.framing(head_request, status, Request.Http10{}, hs)

def target_pick(path: String, base: String, from: String, to: String, q: Maybe<&2, String>, plain: Bool) -> Maybe<&2, String>:
  match plain:
    case True{}: U.target(path, base, U.NoRewrite{}, q)
    case False{}: U.target(path, base, U.Prefix{from, to}, q)

def target(path: String, base: String, +from: String, to: String, q: Maybe<&2, String>) -> Maybe<&2, String>:
  target_pick(path, base, from, to, q, String.is_empty(from))

def options(url: String, preserve: Bool, trust: Bool, forwarded: Bool) -> U.Options:
  U.with_forwarded(U.with_trust(U.with_preserve_host(U.defaults(url), preserve), trust), forwarded)

# Request head for a peer given as text ("" for unknown).
def head_for(up: Maybe<&2, U.Upstream>, o: U.Options, peer: String, method: String, target: String, hs: List<&2, Request.Header>, body_len: Nat) -> Maybe<&2, String>:
  match up:
    case None{}: None{}
    case Some{u}: Some{Bytes.ascii(U.head_bytes(Request.method(method), target, U.request_headers(o, u, hs, Conn.from_peer(peer, 4000), body_len)))}

def request_head(+url: String, preserve: Bool, trust: Bool, forwarded: Bool, peer: String, method: String, target: String, hs: List<&2, Request.Header>, body_len: Nat) -> Maybe<&2, String>:
  head_for(U.parse_url(url), options(url, preserve, trust, forwarded), peer, method, target, hs, body_len)

type Decoded is Data:
  Decoded{bytes: List<&2, U32>, finished: Bool, eof_ok: Bool}
  Broke{}

def go(parts: List<&2, List<&2, U32>>, fed: U.Fed, acc: List<&2, U32>) -> Decoded:
  match parts fed:
    case _ U.Broken{}: Broke{}
    case Nil{} U.Fed{bytes, +b}: Decoded{Bytes.append(acc, bytes), U.done(b), U.at_eof(b)}
    case p <> t U.Fed{bytes, b}: go(t, U.feed(b, p), Bytes.append(acc, bytes))

def decode(f: U.Framing, parts: List<&2, List<&2, U32>>) -> Decoded:
  go(parts, U.Fed{[], U.start(f)}, [])
