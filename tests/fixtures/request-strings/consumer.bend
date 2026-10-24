import Base
import ../../../src/http.bend as Http
import ../../../src/http/text.bend as Text
import ../../../src/http/bytes.bend as B
import ../../../src/http/parse.bend as P
import ../../../src/http/request.bend as R
import ../../../src/app/errors.bend as E
import ../../../src/crypto/jwt.bend as J
import ../../../src/data/base64.bend as B64
import ../../../src/data/hex.bend as H
import ../../../src/data/utf8.bend as U
import ../../../src/data/json.bend as Json
import ../../../src/data/multipart.bend as Multipart
import ../../../src/data/cookie.bend as C
import ../../../src/http/media.bend as M
import ../../../src/net/ip.bend as Ip
import ../../../src/net/conn_info.bend as Info

import ../../../src/http/origin.bend as O
import ../../../src/http/connection.bend as Conn
import ../../../src/router/encoding.bend as Enc
import ../../../src/data/urlencoded.bend as Url

import ../../../src/http/conditional.bend as Cond
import ../../../src/mw/auth_common.bend as Auth
import ../../../src/mw/bearer_auth.bend as Bearer
import ../../../src/static/mime.bend as Mime
import ../../../src/http/websocket.bend as WS
import ../../../src/http/framing.bend as Framing
import ../../../src/mw/method_override_policy.bend as Override
import ../../../src/mw/trailing_slash_policy.bend as Slash
import ../../../src/mw/cors_policy.bend as Cors
import ../../../src/mw/cors_request.bend as CorsRequest

def count(-A: Data, xs: List<&2, A>, n: Nat) -> Nat:
  match xs:
    case Nil{}: n
    case _ <> t: count(A, t, 1n+n)

def req() -> R.Req: R.Req{R.Get{}, "/", None{}, R.Http11{}, []}
def header(p: P.State) -> Bool:
  match p:
    case P.Headers{r, v, cr}: True{}
    case _: False{}
def bytes(m: Maybe<&2, List<&2, U32>>) -> Nat:
  match m:
    case Some{xs}: count(U32, xs, 0n)
    case None{}: 0n
def text(m: Maybe<&2, String>) -> Nat:
  match m:
    case Some{s}: String.length(s)
    case None{}: 0n
def cut(m: Maybe<&2, J.Cut>) -> Nat:
  match m:
    case Some{J.Cut{a, b}}: String.length(a)
    case None{}: 0n
def target(p: String & Maybe<&2, String>) -> Nat:
  (s, q) = p
  String.length(s)
def parsed(p: R.ParseResult) -> Nat:
  match p:
    case R.Parsed{R.Req{m, path, q, v, hs}, rest}: 1n
    case _: 0n

def wellformed(p: R.ParseResult) -> Nat:
  match p:
    case R.Parsed{r, rest}: U32.to_nat(Bool.to_u32(R.well_formed(r)))
    case _: 0n

def lookup_count(p: R.ParseResult) -> Nat:
  match p:
    case R.Parsed{R.Req{m, path, q, v, hs}, rest}: count(List<&2, U32>, R.lookup(hs, "a"), 0n)
    case _: 0n

def url_pairs(r: Result<&2, &2, Url.Error, List<&2, Url.Entry>>) -> Nat:
  match r:
    case Done{xs}: count(Url.Entry, xs, 0n)
    case Fail{e}: 0n

def origin_cut(c: Maybe<&2, O.Cut>) -> Nat:
  match c:
    case Some{O.Cut{a, b}}: String.length(a)
    case None{}: 0n

def authority(c: O.Cut) -> Nat:
  O.Cut{a, b} = c
  String.length(a)

def url_text(r: Result<&2, &2, Url.Error, String>) -> Nat:
  match r:
    case Done{s}: String.length(s)
    case Fail{e}: 0n

def auth_cut(c: Maybe<&2, Auth.Cut>) -> Nat:
  match c:
    case Some{Auth.Cut{a, b}}: String.length(a)
    case None{}: 0n

def json_ok(result: Result<&2, &2, Json.Error, Json.Json>) -> Nat:
  match result:
    case Done{j}: 1n
    case Fail{e}: 0n

def probe(mode: String, +s: String) -> Nat:
  match mode:
    case "json-scalars": U32.to_nat(Bool.to_u32(Json.scalars(s)))
    case "json-quote": String.length(Json.quote(s, False{}))
    case "json-parse": json_ok(Json.parse(B.encode(s)))
    case "multipart-token": U32.to_nat(Bool.to_u32(Multipart.token(s)))
    case "multipart-boundary": text(Multipart.boundary(s))
    case "multipart-type": U32.to_nat(Bool.to_u32(Multipart.content_type_parts(Text.split(s, ';'))))
    case "upper": String.length(Text.upper(s))
    case "legacy-path": String.length(Http.path_of(s))
    case "override": String.length(R.method_text(Override.parse(s)))
    case "slash-trim": text(Slash.target(Slash.Trim{}, R.Get{}, s, None{}))
    case "slash-append": text(Slash.target(Slash.Append{}, R.Get{}, s, None{}))
    case "cors-reflect": text(Cors.reflect(Some{s}))
    case "cors-combined": text(CorsRequest.combined([B.encode(s)]))
    case "cors-combined-many": text(CorsRequest.combined(Ip.split(B.encode(s), 44)))
    case "conditional-match": U32.to_nat(Bool.to_u32(Cond.matches(Some{s}, "\"a\"")))
    case "websocket-listed": U32.to_nat(Bool.to_u32(WS.listed([B.encode(s)], "upgrade")))
    case "websocket-offered": U32.to_nat(Bool.to_u32(WS.offered_any([B.encode(s)], "chat")))
    case "websocket-key": U32.to_nat(Bool.to_u32(WS.key_valid([B.encode(s)])))
    case "ip-parse": U32.to_nat(Bool.to_u32(Maybe.is_some(&2, Ip.Addr, Ip.parse(s))))
    case "forwarded-trim": count(U32, Info.trim(B.encode(s)), 0n)
    case "forwarded-entries": count(String, Info.entries([B.encode(s)]), 0n)
    case "forwarded-client": U32.to_nat(Bool.to_u32(Maybe.is_some(&2, Ip.Addr, Info.client(Ip.parse("127.0.0.1"), [B.encode(s)], [Ip.Cidr{Ip.V4{}, [], 0n}]))))
    case "content-length": U32.to_nat(Maybe.default(&2, U32, Framing.decimal(B.encode(s), 0), 1))
    case "websocket-zeros": U32.to_nat(Bool.to_u32(WS.zero_length(B.encode(s))))
    case "lower": String.length(B.fold(s))
    case "append": count(U32, B.append(B.encode(s), [90]), 0n)
    case "utf8-valid": U32.to_nat(Bool.to_u32(U.valid(s)))
    case "encode": count(U32, B.encode(s), 0n)
    case "ascii": String.length(B.ascii(B.encode(s)))
    case "token": U32.to_nat(Bool.to_u32(B.token(s)))
    case "value": U32.to_nat(Bool.to_u32(B.value(B.encode(s))))
    case "uri": U32.to_nat(Bool.to_u32(B.uri(s, False{})))
    case "target": target(B.split_target(s))
    case "trim": String.length(String.trim(s))
    case "split": count(String, Text.split(s, ','), 0n)
    case "jwt": cut(J.split(s))
    case "jwt-dotfree": U32.to_nat(Bool.to_u32(J.dotfree(s)))
    case "jwt-codes": count(U32, J.codes(s), 0n)
    case "cookie": count(C.Entry, C.parse(s), 0n)
    case "header": U32.to_nat(Bool.to_u32(header(P.header_line(req(), B.encode(s)))))
    case "accept": U32.to_nat(Bool.to_u32(E.accepts_json(Some{s})))
    case "media": String.length(M.essence(s))
    case "ip-split": count(List<&2, U32>, Ip.split(B.encode(s), 44), 0n)
    case "base64-encode": String.length(B64.encode(U.encode(s), False{}, True{}))
    case "base64-decode": bytes(B64.decode(s, False{}, True{}))
    case "hex-encode": String.length(H.encode(U.encode(s)))
    case "hex-decode": bytes(H.decode(s))
    case "utf8-encode": count(U32, U.encode(s), 0n)
    case "utf8-decode": text(U.decode(U.encode(s)))
    case "conditional-entity": text(Cond.entity(s))
    case "conditional-segments": count(String, Cond.segments(s, False{}, ""), 0n)
    case "auth-cut": auth_cut(Auth.cut(s, ' '))
    case "auth-escape": String.length(Auth.escape(s))
    case "bearer": U32.to_nat(Bool.to_u32(Bearer.b64token(s)))
    case "mime": String.length(Mime.extension(s))
    case "parse": parsed(P.parse(B.encode(s)))
    case "wellformed": wellformed(P.parse(B.encode(s)))
    case "lookup": lookup_count(P.parse(B.encode(s)))
    case "origin-cut": origin_cut(O.cut(s, ':'))
    case "origin-authority": authority(O.authority(s))
    case "origin-digits": U32.to_nat(Bool.to_u32(O.digits(s)))
    case "origin-name": U32.to_nat(Bool.to_u32(O.name_chars(s)))
    case "origin-ipv6": U32.to_nat(Bool.to_u32(O.ipv6_chars(s)))
    case "connection": U32.to_nat(Bool.to_u32(Conn.has_token([R.Header{"connection", B.encode(s)}], "close")))
    case "router-encode": String.length(Enc.encode(s))
    case "router-decode": text(Enc.decode(s))
    case "url-encode": String.length(Url.encode(s))
    case "url-decode": url_text(Url.decode(s))
    case "url-pairs": url_pairs(Url.parse_pairs(s))
    case _: 0n

def decoded_text(m: Maybe<&2, String>) -> String:
  match m:
    case None{}: "invalid"
    case Some{s}: s

def run(args: List<String>) -> String:
  match args:
    case _ <> "exact-lower" <> s <> _: B.fold(s)
    case _ <> "exact-upper" <> s <> _: Text.upper(s)
    case _ <> "exact-roundtrip" <> s <> _: B.ascii(B.encode(s))
    case _ <> "exact-escape" <> s <> _: Auth.escape(s)
    case _ <> "exact-router-encode" <> s <> _: Enc.encode(s)
    case _ <> "exact-router-decode" <> s <> _: decoded_text(Enc.decode(s))
    case _ <> mode <> s <> _: Nat.show(probe(mode, s))
    case _: "0"

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args
    IO.print(run(args))

def folded(s: String) -> String: B.fold(s)
def roundtrip(+s: String) -> String: B.ascii(B.encode(s))
def jwt_left(c: Maybe<&2, J.Cut>) -> String:
  match c:
    case Some{J.Cut{a, b}}: a
    case None{}: ""
def jwt_right(c: Maybe<&2, J.Cut>) -> String:
  match c:
    case Some{J.Cut{a, b}}: b
    case None{}: ""
def first_segment(s: String) -> String: jwt_left(J.split(s))
def rest_segments(s: String) -> String: jwt_right(J.split(s))

def uppercased(s: String) -> String: Text.upper(s)
def split_text(s: String) -> List<&2, String>: Text.split(s, ',')
def escaped(s: String) -> String: Auth.escape(s)
def router_encoded(s: String) -> String: Enc.encode(s)
def router_decoded(s: String) -> Maybe<&2, String>: Enc.decode(s)
def conditional_parts(s: String) -> List<&2, String>: Cond.segments(s, False{}, "")
def target_parts(s: String) -> String & Maybe<&2, String>: B.split_target(s)
