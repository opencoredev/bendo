# BND-50: the RFC 6455 opening handshake, stated without the handshake
# module's helpers. It uses only Base, the request types, the proven Base64
# and SHA-1 primitives, and the independent origin specification
# (proof/origin-spec.bend; BND-85).
import Base
import ../src/http/response.bend as Response
import ../src/http/request.bend as Request
import ../src/http/bytes.bend as Bytes
import ./origin-spec.bend as OriginSpec
import ../src/crypto/sha1.bend as Sha1
import ../src/data/base64.bend as Base64
import ../src/http/websocket.bend as W

# "258EAFA5-E914-47DA-95CA-C5AB0DC85B11" (RFC 6455 section 1.3), as octets.
def guid() -> List<&2, U32>:
  [50, 53, 56, 69, 65, 70, 65, 53, 45, 69, 57, 49, 52, 45, 52, 55, 68, 65, 45, 57, 53, 67, 65, 45, 67, 53, 65, 66, 48, 68, 67, 56, 53, 66, 49, 49]

# Section 4.2.2: base64 (standard alphabet, padded) of the SHA-1 of the key
# octets followed by the GUID.
def accept(key: List<&2, U32>) -> String:
  Base64.encode(Sha1.hash(List.append(&2, U32, key, guid())), False{}, True{})

def keep_value(+v: List<&2, U32>, rest: List<&2, List<&2, U32>>, same: Bool) -> List<&2, List<&2, U32>>:
  match same:
    case True{}: v <> rest
    case False{}: rest

# The values of the fields named name, in order. The parser stores field names
# in lowercase, so name is lowercase.
def fields(hs: List<&2, Request.Header>, +name: String) -> List<&2, List<&2, U32>>:
  match hs:
    case Nil{}: []
    case Request.Header{n, +v} <> t: keep_value(v, fields(t, name), String.eq(n, name))

# Every comma-separated element of every value, without surrounding OWS.
def trimmed(parts: List<&2, String>) -> List<&2, String>:
  match parts:
    case Nil{}: []
    case p <> t: Bytes.ascii(Bytes.trim(Bytes.encode(p))) <> trimmed(t)

def elements(values: List<&2, List<&2, U32>>) -> List<&2, String>:
  match values:
    case Nil{}: []
    case v <> t: List.append(&2, String, trimmed(String.split(Bytes.ascii(v), ',')), elements(t))

def has_folded(xs: List<&2, String>, +wanted: String) -> Bool:
  match xs:
    case Nil{}: False{}
    case x <> t: String.eq(String.to_lower(x), wanted) || has_folded(t, wanted)

def has_exact(xs: List<&2, String>, +wanted: String) -> Bool:
  match xs:
    case Nil{}: False{}
    case x <> t: String.eq(x, wanted) || has_exact(t, wanted)

def all_zero(xs: List<&2, U32>) -> Bool:
  match xs:
    case Nil{}: True{}
    case +c <> t: U32.is_eq(c, 48) && all_zero(t)

# Section 4.1 sends no body. Any Transfer-Encoding (even an empty chunked
# body) is one; Content-Length is allowed only once, with a value of zero
# written in one or more digits.
def no_length(values: List<&2, List<&2, U32>>) -> Bool:
  match values:
    case Nil{}: True{}
    case Nil{} <> Nil{}: False{}
    case (c <> d) <> Nil{}: all_zero(c <> d)
    case _: False{}

def no_coding(codings: List<&2, List<&2, U32>>, lengths: List<&2, List<&2, U32>>) -> Bool:
  match codings:
    case Nil{}: no_length(lengths)
    case _: False{}

def no_body(+hs: List<&2, Request.Header>) -> Bool:
  no_coding(fields(hs, "transfer-encoding"), fields(hs, "content-length"))

def nonce(+text: String, decoded: Maybe<&2, List<&2, U32>>) -> Bool:
  match decoded:
    case None{}: False{}
    case Some{+octets}: Nat.is_eq(List.length(&2, U32, octets), 16n) && String.eq(Base64.encode(octets, False{}, True{}), text)

# Section 4.2.1: exactly one Sec-WebSocket-Key, the padded base64 of 16
# octets, spelled the one way base64 writes those octets.
def good_key(keys: List<&2, List<&2, U32>>) -> Bool:
  match keys:
    case Nil{}: False{}
    case k <> Nil{}:
      +text = Bytes.ascii(k)
      nonce(text, Base64.decode(text, False{}, True{}))
    case k <> (j <> rest): False{}

def the_key(keys: List<&2, List<&2, U32>>) -> List<&2, U32>:
  match keys:
    case Nil{}: []
    case k <> rest: k

type Version is Data:
  Malformed{}
  Supported{}
  Unsupported{}

def thirteen(same: Bool) -> Version:
  match same:
    case True{}: Supported{}
    case False{}: Unsupported{}

# Section 4.4: one Sec-WebSocket-Version field of "13". A missing or repeated
# field is malformed; one other value is a version Bendo does not speak.
def version(values: List<&2, List<&2, U32>>) -> Version:
  match values:
    case Nil{}: Malformed{}
    case v <> Nil{}: thirteen(String.eq(Bytes.ascii(v), "13"))
    case v <> (w <> rest): Malformed{}

def listed_origin(xs: List<&2, String>, +o: String) -> Bool:
  match xs:
    case Nil{}: False{}
    case x <> t: String.eq(x, o) || listed_origin(t, o)

def serialized_in(+xs: List<&2, String>, o: Maybe<&2, String>) -> Bool:
  match o:
    case None{}: False{}
    case Some{+s}: listed_origin(xs, s)

def one_origin(+xs: List<&2, String>, values: List<&2, List<&2, U32>>) -> Bool:
  match values:
    case Nil{}: False{}
    case v <> Nil{}: serialized_in(xs, OriginSpec.canonical(Bytes.ascii(v)))
    case v <> (w <> rest): False{}

# Section 10.2: a listed policy needs exactly one Origin field whose
# serialization is listed.
def origin_ok(origins: W.Origins, +hs: List<&2, Request.Header>) -> Bool:
  match origins:
    case W.AnyOrigin{}: True{}
    case W.Listed{xs}: one_origin(xs, fields(hs, "origin"))

def first_offered(+p: String, rest: Maybe<&2, String>, offered: Bool) -> Maybe<&2, String>:
  match offered:
    case True{}: Some{p}
    case False{}: rest

# Section 4.2.2: the first server subprotocol, in the server's order, that the
# client offered exactly. None when no offer matches. Extensions are ignored.
def protocol(protocols: List<&2, String>, +offers: List<&2, String>) -> Maybe<&2, String>:
  match protocols:
    case Nil{}: None{}
    case +p <> t: first_offered(p, protocol(t, offers), has_exact(offers, p))

def is_get(m: Request.Method) -> Bool:
  match m:
    case Request.Get{}: True{}
    case Request.Head{}: False{}
    case Request.Post{}: False{}
    case Request.Put{}: False{}
    case Request.Delete{}: False{}
    case Request.Connect{}: False{}
    case Request.Options{}: False{}
    case Request.Trace{}: False{}
    case Request.Patch{}: False{}
    case Request.Extension{t}: False{}

def is_http11(v: Request.Version) -> Bool:
  match v:
    case Request.Http10{}: False{}
    case Request.Http11{}: True{}

def judge(valid: Bool, v: Version, origin: Bool, keys: List<&2, List<&2, U32>>, protocols: List<&2, String>, offers: List<&2, List<&2, U32>>) -> W.Decision:
  match valid v origin:
    case False{} _ _: W.Refuse{400}
    case True{} Malformed{} _: W.Refuse{400}
    case True{} Unsupported{} _: W.Refuse{426}
    case True{} Supported{} False{}: W.Refuse{403}
    case True{} Supported{} True{}: W.Accept{accept(the_key(keys)), protocol(protocols, elements(offers))}

# The whole decision. 400 unless the request is a GET over HTTP/1.1 with no
# body, an Upgrade element "websocket" and a Connection element "upgrade"
# (both without ASCII case) and one valid key; then the version rule (400 or
# 426), then the origin rule (403). Otherwise accept with the computed key and
# chosen subprotocol.
def decide(config: W.Config, req: Request.Req) -> W.Decision:
  W.Config{origins, protocols, ms} = config
  Request.Req{method, path, query, v, +hs} = req
  +keys = fields(hs, "sec-websocket-key")
  judge(((((is_get(method) && is_http11(v)) && no_body(hs)) && has_folded(elements(fields(hs, "upgrade")), "websocket")) && has_folded(elements(fields(hs, "connection")), "upgrade")) && good_key(keys), version(fields(hs, "sec-websocket-version")), origin_ok(origins, hs), keys, protocols, fields(hs, "sec-websocket-protocol"))

def protocol_field(protocol: Maybe<&2, String>) -> List<&2, Request.Header>:
  match protocol:
    case None{}: []
    case Some{p}: [Request.Header{"sec-websocket-protocol", Bytes.encode(p)}]

# No field with either framing name, irrespective of ASCII name case.
def unframed(hs: List<&2, Request.Header>) -> Bool:
  match hs:
    case Nil{}: True{}
    case Request.Header{name, value} <> tail:
      +folded = String.to_lower(name)
      Bool.not(String.eq(folded, "content-length") || String.eq(folded, "transfer-encoding")) && unframed(tail)

def frameless(res: Response.Res) -> Bool:
  Response.Res{status, hs, body, rep} = res
  U32.is_eq(status, 101) && List.is_empty(&2, U32, body) && unframed(hs)

# Independent response field contract. Preserve unrelated fields byte for byte,
# including duplicates and order; remove private metadata, framing, and every
# handshake-owned field, regardless of ASCII name case.
def middleware_allowed(name: String) -> Bool:
  +n = String.to_lower(name)
  Bool.not(String.eq(n, "x-bendo-stream-internal")) && Bool.not((String.eq(n, "content-length") || String.eq(n, "transfer-encoding")) || (String.eq(n, "upgrade") || String.eq(n, "connection") || String.eq(n, "sec-websocket-accept") || String.eq(n, "sec-websocket-protocol") || String.eq(n, "sec-websocket-extensions") || String.eq(n, "sec-websocket-version")))

def middleware_pick(h: Request.Header, tail: List<&2, Request.Header>, allowed: Bool) -> List<&2, Request.Header>:
  match allowed:
    case True{}: h <> tail
    case False{}: tail

def middleware_fields(hs: List<&2, Request.Header>) -> List<&2, Request.Header>:
  match hs:
    case Nil{}: []
    case Request.Header{+name, value} <> tail:
      middleware_pick(Request.Header{name, value}, middleware_fields(tail), middleware_allowed(name))

def opening_fields(accept: String, protocol: Maybe<&2, String>) -> List<&2, Request.Header>:
  Request.Header{"upgrade", Bytes.encode("websocket")} <> (Request.Header{"connection", Bytes.encode("Upgrade")} <> (Request.Header{"sec-websocket-accept", Bytes.encode(accept)} <> protocol_field(protocol)))

def rebuilt(res: Response.Res, accept: String, protocol: Maybe<&2, String>) -> Response.Res:
  Response.Res{status, hs, body, rep} = res
  Response.Res{101, List.append(&2, Request.Header, opening_fields(accept, protocol), middleware_fields(hs)), [], None{}}

# BND-94: a refused handshake the clock cannot date. Keep every field the
# refusal carried byte for byte, in order and with duplicates, except private
# metadata, framing, the media type and every handshake-owned field, regardless
# of ASCII name case; answer an empty 500 framed as zero bytes.
def refusal_allowed(name: String) -> Bool:
  +n = String.to_lower(name)
  Bool.not(((String.eq(n, "content-length") || String.eq(n, "transfer-encoding")) || (String.eq(n, "upgrade") || String.eq(n, "connection") || String.eq(n, "sec-websocket-accept") || String.eq(n, "sec-websocket-protocol") || String.eq(n, "sec-websocket-extensions") || String.eq(n, "sec-websocket-version"))) || String.eq(n, "x-bendo-stream-internal") || String.eq(n, "content-type"))

def refusal_kept(hs: List<&2, Request.Header>) -> List<&2, Request.Header>:
  match hs:
    case Nil{}: []
    case Request.Header{+name, value} <> tail:
      middleware_pick(Request.Header{name, value}, refusal_kept(tail), refusal_allowed(name))

def unavailable(res: Response.Res) -> Response.Res:
  Response.Res{status, hs, body, rep} = res
  Response.Res{500, Request.Header{"content-length", Bytes.encode("0")} <> refusal_kept(hs), [], None{}}
