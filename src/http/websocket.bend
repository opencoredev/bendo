# RFC 6455 section 4 opening handshake, as pure functions of the server's
# configuration and the request. src/websocket.bend registers the session;
# LAWS.bend states what the decision is.
import Base
import ./response.bend as Response
import ./request.bend as Request
import ./origin.bend as Origin
import ./bytes.bend as Bytes
import ./text.bend as Text
import ../crypto/sha1.bend as Sha1
import ../data/base64.bend as Base64

# Any accepts every Origin field, or none. Listed holds serialized origins and
# requires exactly one Origin field whose serialization is listed.
type Origins is Data:
  AnyOrigin{}
  Listed{origins: List<&2, String>}

# protocols: subprotocols the server speaks, most preferred first.
# write_timeout_ms bounds sending the 101 head.
type Config is Data:
  Config{origins: Origins, protocols: List<&2, String>, write_timeout_ms: U32}

type Decision is Data:
  Accept{accept: String, protocol: Maybe<&2, String>}
  Refuse{status: U32}

# The globally unique identifier of RFC 6455 section 1.3.
def guid() -> String: "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

# Sec-WebSocket-Accept: base64 of the SHA-1 of the key's octets and the GUID.
def accept(key: List<&2, U32>) -> String:
  Base64.encode(Sha1.hash(Bytes.append(key, Bytes.encode(guid()))), False{}, True{})

def defaults() -> Config:
  Config{AnyOrigin{}, [], 30000}

def origin_kept(m: Maybe<&2, String>, rest: List<&2, String>) -> List<&2, String>:
  match m:
    case None{}: rest
    case Some{o}: o <> rest

# Configured origins are serialized once, as URL origins. Entries that are not
# http or https URLs can never match and are dropped.
def serialized(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}: []
    case x <> t: origin_kept(Origin.of_url(x), serialized(t))

def with_origins(config: Config, origins: List<&2, String>) -> Config:
  Config{old, protocols, timeout} = config
  Config{Listed{serialized(origins)}, protocols, timeout}

def protocol_kept(+p: String, rest: List<&2, String>, ok: Bool) -> List<&2, String>:
  match ok:
    case True{}: p <> rest
    case False{}: rest

# Subprotocols are HTTP tokens; anything else could never be offered and is dropped.
def tokens(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}: []
    case +x <> t: protocol_kept(x, tokens(t), Bytes.token(x))

def with_protocols(config: Config, protocols: List<&2, String>) -> Config:
  Config{origins, old, timeout} = config
  Config{origins, tokens(protocols), timeout}

def with_timeout(config: Config, milliseconds: U32) -> Config:
  Config{origins, protocols, old} = config
  Config{origins, protocols, milliseconds}

def timeout(config: Config) -> U32:
  Config{origins, protocols, ms} = config
  ms

# One comma-separated list element without its optional whitespace.
def element(part: String) -> String:
  Bytes.ascii(Bytes.trim(Bytes.encode(part)))

def has_element_spec(parts: List<&2, String>, +wanted: String) -> Bool:
  match parts:
    case Nil{}: False{}
    case p <> t: String.eq(Bytes.fold(element(p)), wanted) || has_element_spec(t, wanted)

# Every fold over request lists and octets is a tail loop over the reversed
# input (BND-84).
def has_element_go(rev: List<&2, String>, +wanted: String, acc: Bool) -> Bool:
  match rev:
    case Nil{}: acc
    case p <> r: has_element_go(r, wanted, String.eq(Bytes.fold(element(p)), wanted) || acc)

def has_element(parts: List<&2, String>, +wanted: String) -> Bool:
  has_element_go(List.reverse(&2, String, parts), wanted, False{})

def listed_spec(values: List<&2, List<&2, U32>>, +wanted: String) -> Bool:
  match values:
    case Nil{}: False{}
    case v <> t: has_element(Text.split(Bytes.ascii(v), ','), wanted) || listed_spec(t, wanted)

def listed_go(rev: List<&2, List<&2, U32>>, +wanted: String, acc: Bool) -> Bool:
  match rev:
    case Nil{}: acc
    case v <> r: listed_go(r, wanted, has_element(Text.split(Bytes.ascii(v), ','), wanted) || acc)

# Some field value lists wanted, without ASCII case.
def listed(values: List<&2, List<&2, U32>>, +wanted: String) -> Bool:
  listed_go(List.reverse(&2, List<&2, U32>, values), wanted, False{})

def zeros_spec(xs: List<&2, U32>) -> Bool:
  match xs:
    case Nil{}: True{}
    case +c <> t: U32.is_eq(c, 48) && zeros_spec(t)

def zeros_go(rev: List<&2, U32>, acc: Bool) -> Bool:
  match rev:
    case Nil{}: acc
    case +c <> r: zeros_go(r, U32.is_eq(c, 48) && acc)

def zeros(xs: List<&2, U32>) -> Bool:
  zeros_go(List.reverse(&2, U32, xs), True{})

# A Content-Length of zero, in any number of digits.
def zero_length(v: List<&2, U32>) -> Bool:
  match v:
    case Nil{}: False{}
    case c <> t: zeros(c <> t)

# No Content-Length, or exactly one whose value is zero. The request parser
# already refuses repeated Content-Length fields.
def zero_lengths(values: List<&2, List<&2, U32>>) -> Bool:
  match values:
    case Nil{}: True{}
    case v <> Nil{}: zero_length(v)
    case _: False{}

# No Transfer-Encoding at all (even an empty chunked body) and no nonzero
# Content-Length.
def bodyless(+hs: List<&2, Request.Header>) -> Bool:
  List.is_empty(&2, List<&2, U32>, Request.lookup(hs, "transfer-encoding")) && zero_lengths(Request.lookup(hs, "content-length"))

def key_sized(+key: String, decoded: Maybe<&2, List<&2, U32>>) -> Bool:
  match decoded:
    case None{}: False{}
    case Some{+xs}: Nat.is_eq(Text.length(U32, xs), 16n) && String.eq(Base64.encode(xs, False{}, True{}), key)

# Exactly one key field: padded standard base64 of 16 octets, in its one
# canonical spelling.
def key_valid(values: List<&2, List<&2, U32>>) -> Bool:
  match values:
    case v <> Nil{}:
      +key = Bytes.ascii(v)
      key_sized(key, Base64.decode(key, False{}, True{}))
    case _: False{}

def key_value(values: List<&2, List<&2, U32>>) -> List<&2, U32>:
  match values:
    case v <> t: v
    case Nil{}: []

def supported(same: Bool) -> U32:
  match same:
    case True{}: 0
    case False{}: 426

# 0: exactly "13"; 400: missing or repeated; 426: one other version
# (RFC 6455 section 4.4).
def version_status(values: List<&2, List<&2, U32>>) -> U32:
  match values:
    case v <> Nil{}: supported(String.eq(Bytes.ascii(v), "13"))
    case _: 400

def member(xs: List<&2, String>, +o: String) -> Bool:
  match xs:
    case Nil{}: False{}
    case x <> t: String.eq(x, o) || member(t, o)

def origin_in(+xs: List<&2, String>, m: Maybe<&2, String>) -> Bool:
  match m:
    case None{}: False{}
    case Some{o}: member(xs, o)

def origin_sent(+xs: List<&2, String>, values: List<&2, List<&2, U32>>) -> Bool:
  match values:
    case v <> Nil{}: origin_in(xs, Origin.canonical(Bytes.ascii(v)))
    case _: False{}

def origin_allowed(origins: Origins, +hs: List<&2, Request.Header>) -> Bool:
  match origins:
    case AnyOrigin{}: True{}
    case Listed{xs}: origin_sent(xs, Request.lookup(hs, "origin"))

def has_offer_spec(parts: List<&2, String>, +p: String) -> Bool:
  match parts:
    case Nil{}: False{}
    case x <> t: String.eq(element(x), p) || has_offer_spec(t, p)

def has_offer_go(rev: List<&2, String>, +p: String, acc: Bool) -> Bool:
  match rev:
    case Nil{}: acc
    case x <> r: has_offer_go(r, p, String.eq(element(x), p) || acc)

def has_offer(parts: List<&2, String>, +p: String) -> Bool:
  has_offer_go(List.reverse(&2, String, parts), p, False{})

def offered_any_spec(values: List<&2, List<&2, U32>>, +p: String) -> Bool:
  match values:
    case Nil{}: False{}
    case v <> t: has_offer(Text.split(Bytes.ascii(v), ','), p) || offered_any_spec(t, p)

def offered_any_go(rev: List<&2, List<&2, U32>>, +p: String, acc: Bool) -> Bool:
  match rev:
    case Nil{}: acc
    case v <> r: offered_any_go(r, p, has_offer(Text.split(Bytes.ascii(v), ','), p) || acc)

def offered_any(values: List<&2, List<&2, U32>>, +p: String) -> Bool:
  offered_any_go(List.reverse(&2, List<&2, U32>, values), p, False{})

def chosen(+p: String, rest: Maybe<&2, String>, offered: Bool) -> Maybe<&2, String>:
  match offered:
    case True{}: Some{p}
    case False{}: rest

# The first configured subprotocol the client offered; elements match exactly.
def select(protocols: List<&2, String>, +values: List<&2, List<&2, U32>>) -> Maybe<&2, String>:
  match protocols:
    case Nil{}: None{}
    case +p <> t: chosen(p, select(t, values), offered_any(values, p))

def is_get(m: Request.Method) -> Bool:
  match m:
    case Request.Get{}: True{}
    case _: False{}

def is_http11(v: Request.Version) -> Bool:
  match v:
    case Request.Http10{}: False{}
    case Request.Http11{}: True{}

def accepted(keys: List<&2, List<&2, U32>>, protocols: List<&2, String>, offers: List<&2, List<&2, U32>>) -> Decision:
  Accept{accept(key_value(keys)), select(protocols, offers)}

def negotiated(version: U32, origin: Bool, keys: List<&2, List<&2, U32>>, protocols: List<&2, String>, offers: List<&2, List<&2, U32>>) -> Decision:
  match version origin:
    case 0 True{}: accepted(keys, protocols, offers)
    case 0 False{}: Refuse{403}
    case _ _: Refuse{version}

def decided(get: Bool, http11: Bool, body: Bool, upgrade: Bool, connection: Bool, key: Bool, version: U32, origin: Bool, keys: List<&2, List<&2, U32>>, protocols: List<&2, String>, offers: List<&2, List<&2, U32>>) -> Decision:
  match get http11 body upgrade connection key:
    case True{} True{} True{} True{} True{} True{}: negotiated(version, origin, keys, protocols, offers)
    case _ _ _ _ _ _: Refuse{400}

# Every check of the opening handshake. 400: not GET, HTTP/1.0, a request
# body, no "websocket" Upgrade element, no "upgrade" Connection element, or not
# exactly one valid key; then 400 or 426 for the version, then 403 for the
# origin. Extensions are never negotiated.
def decide(config: Config, req: Request.Req) -> Decision:
  Config{origins, protocols, ms} = config
  Request.Req{method, path, query, version, +hs} = req
  +keys = Request.lookup(hs, "sec-websocket-key")
  decided(is_get(method), is_http11(version), bodyless(hs), listed(Request.lookup(hs, "upgrade"), "websocket"), listed(Request.lookup(hs, "connection"), "upgrade"), key_valid(keys), version_status(Request.lookup(hs, "sec-websocket-version")), origin_allowed(origins, hs), keys, protocols, Request.lookup(hs, "sec-websocket-protocol"))

# The error message for a refused handshake.
def reason(status: U32) -> String:
  match status:
    case 403: "Forbidden"
    case 426: "Upgrade Required"
    case _: "Bad Request"

# The fields of an accepted 101, in order.
def protocol_field(protocol: Maybe<&2, String>) -> List<&2, Request.Header>:
  match protocol:
    case None{}: []
    case Some{p}: [Request.Header{"sec-websocket-protocol", Bytes.encode(p)}]

def handshake(accept: String, protocol: Maybe<&2, String>) -> List<&2, Request.Header>:
  Request.Header{"upgrade", Bytes.encode("websocket")} <> (Request.Header{"connection", Bytes.encode("Upgrade")} <> (Request.Header{"sec-websocket-accept", Bytes.encode(accept)} <> protocol_field(protocol)))

# Fields the handshake owns, plus framing a 101 never carries. Middleware
# copies of them are replaced by the computed handshake.
def framing(+name: String) -> Bool:
  String.eq(name, "content-length") || String.eq(name, "transfer-encoding")

def handshake_owned(+name: String) -> Bool:
  String.eq(name, "upgrade") || String.eq(name, "connection") || String.eq(name, "sec-websocket-accept") || String.eq(name, "sec-websocket-protocol") || String.eq(name, "sec-websocket-extensions") || String.eq(name, "sec-websocket-version")

def owned(+name: String) -> Bool:
  framing(name) || handshake_owned(name)

def kept(h: Request.Header) -> Bool:
  Request.Header{name, value} = h
  Bool.not(owned(Bytes.fold(name)))

# The handshake's own fields, which must not survive on a response that is
# not the 101 (Connection and framing stay with the response writer).
def handshake_field(h: Request.Header) -> Bool:
  Request.Header{name, value} = h
  +folded = Bytes.fold(name)
  Bool.not(String.eq(folded, "upgrade") || String.eq(folded, "sec-websocket-accept") || String.eq(folded, "sec-websocket-protocol") || (String.eq(folded, "connection") && String.eq(Bytes.fold(Bytes.ascii(value)), "upgrade")))

# Pure opening response; context formatting adds an ordinary error body for a
# refusal. All opening-handshake fields originate here.
def refusal_fields(status: U32) -> List<&2, Request.Header>:
  match status:
    case 426: [Request.Header{"sec-websocket-version", Bytes.encode("13")}]
    case _: []

def response(decision: Decision) -> Response.Res:
  match decision:
    case Refuse{+status}: Response.Res{status, refusal_fields(status), [], None{}}
    case Accept{accept, protocol}: Response.Res{101, handshake(accept, protocol), [], None{}}
