# Pure parts of the proxy (BND-47): the upstream URL, the request head sent
# upstream, the upstream response head parser, its body framing, and the
# incremental body decoder. The IO shell is src/proxy.bend.
import Base
import ./request.bend as Request
import ./bytes.bend as Bytes
import ./write.bend as Write
import ./framing.bend as Framing
import ./chunked.bend as Chunked
import ./parse.bend as Parse
import ./proxy_headers.bend as Hop
import ./stream_types.bend as StreamTypes
import ../net/ip.bend as Ip
import ../net/conn_info.bend as Conn

# ---------------------------------------------------------------- options

type Rewrite is Data:
  NoRewrite{}
  # A path starting with `from` has that prefix replaced by `to`.
  Prefix{from: String, to: String}

type Options is Data:
  Options{upstream: String, preserve_host: Bool, trust: Bool, forwarded: Bool, rewrite: Rewrite, connect_ms: U32, send_ms: U32, head_ms: U32, read_ms: U32, stream: StreamTypes.Config}

def defaults(upstream: String) -> Options:
  Options{upstream, False{}, False{}, False{}, NoRewrite{}, 5000, 30000, 30000, 30000, StreamTypes.Config{30000, 65536}}

def with_preserve_host(o: Options, on: Bool) -> Options:
  Options{u, p, t, f, r, c, s, h, x, st} = o
  Options{u, on, t, f, r, c, s, h, x, st}

def with_trust(o: Options, on: Bool) -> Options:
  Options{u, p, t, f, r, c, s, h, x, st} = o
  Options{u, p, on, f, r, c, s, h, x, st}

def with_forwarded(o: Options, on: Bool) -> Options:
  Options{u, p, t, f, r, c, s, h, x, st} = o
  Options{u, p, t, on, r, c, s, h, x, st}

def with_rewrite(o: Options, from: String, to: String) -> Options:
  Options{u, p, t, f, r, c, s, h, x, st} = o
  Options{u, p, t, f, Prefix{from, to}, c, s, h, x, st}

# Connect, request-send, response-head and per-read body budgets in ms.
def with_timeouts(o: Options, connect: U32, send: U32, head: U32, read: U32) -> Options:
  Options{u, p, t, f, r, c, s, h, x, st} = o
  Options{u, p, t, f, r, connect, send, head, read, st}

def with_stream(o: Options, config: StreamTypes.Config) -> Options:
  Options{u, p, t, f, r, c, s, h, x, st} = o
  Options{u, p, t, f, r, c, s, h, x, config}

# ---------------------------------------------------------------- URL

# host: numeric IPv4 text handed to the connect effect. authority: the Host
# value for the upstream, as written in the URL. base: a path prefix with no
# trailing slash.
type Upstream is Data:
  Upstream{host: String, port: U32, authority: String, base: String}

def digit(+c: U32) -> Bool:
  (c >= 48 : U32) && (c <= 57 : U32)

def digit_step(+n: Nat, +c: U32, ok: Bool) -> Maybe<&2, Nat>:
  match ok:
    case False{}: None{}
    case True{}: Some{Nat.add(Nat.mul(n, 10n), U32.to_nat((c - 48 : U32)))}

def digits(xs: List<&2, U32>, +n: Nat) -> Maybe<&2, Nat>:
  match xs:
    case Nil{}: Some{n}
    case +c <> t:
      do Maybe<&2, Nat>:
        next : Nat <- digit_step(n, c, digit(c))
        digits(t, next)

def port_value(n: Maybe<&2, Nat>) -> Maybe<&2, U32>:
  match n:
    case None{}: None{}
    case Some{+v}: Bool.pick(Maybe<&2, U32>, Nat.is_lt(0n, v) && Nat.is_le(v, 65535n), Some{U32.from_nat(v)}, None{})

def port_text(+s: String, short: Bool) -> Maybe<&2, U32>:
  match short:
    case False{}: None{}
    case True{}: port_value(digits(Bytes.encode(s), 0n))

def v4_text(a: Maybe<&2, Ip.Addr>) -> Maybe<&2, String>:
  match a:
    case None{}: None{}
    case Some{Ip.Addr{Ip.V4{}, bits}}: Some{Ip.format(Ip.Addr{Ip.V4{}, bits})}
    case Some{Ip.Addr{Ip.V6{}, bits}}: None{}

def host_named(+host: String, local: Bool) -> Maybe<&2, String>:
  match local:
    case True{}: Some{"127.0.0.1"}
    case False{}: v4_text(Ip.parse(host))

# Only localhost and numeric IPv4 hosts: Base's connector has no resolver.
def host_text(+host: String) -> Maybe<&2, String>:
  host_named(host, String.eq(String.to_lower(host), "localhost"))

def made(host: Maybe<&2, String>, port: Maybe<&2, U32>, authority: String, base: String) -> Maybe<&2, Upstream>:
  match host port:
    case Some{h} Some{p}: Some{Upstream{h, p, authority, base}}
    case _ _: None{}

def authority_parts(+authority: String, parts: List<&2, String>, base: String) -> Maybe<&2, Upstream>:
  match parts:
    case h <> Nil{}: made(host_text(h), Some{80}, String.to_lower(authority), base)
    case h <> +p <> Nil{}: made(host_text(h), port_text(p, Nat.is_le(String.length(p), 5n)), String.to_lower(authority), base)
    case _: None{}

def trim_slash(+p: String, ends: Bool) -> String:
  match ends:
    case True{}: String.take(p, Nat.sub(String.length(p), 1n))
    case False{}: p

def path_ok(+p: String) -> Bool:
  String.is_empty(p) || (String.starts_with(p, "/") && Bytes.uri(p, False{}))

def no_userinfo(+authority: String) -> Bool:
  Bool.not(String.contains(authority, "@")) && Bool.not(String.is_empty(authority))

def located(+authority: String, +path: String, ok: Bool) -> Maybe<&2, Upstream>:
  match ok:
    case False{}: None{}
    case True{}: authority_parts(authority, String.split(authority, ':'), trim_slash(path, String.ends_with(path, "/")))

def slashed(parts: List<&2, String>) -> String:
  match parts:
    case Nil{}: ""
    case p <> t: "/" ++ p ++ slashed(t)

def split_rest(pieces: List<&2, String>) -> Maybe<&2, Upstream>:
  match pieces:
    case Nil{}: None{}
    case +authority <> rest:
      +path = slashed(rest)
      located(authority, path, no_userinfo(authority) && path_ok(path))

def after_scheme(+s: String, http: Bool) -> Maybe<&2, Upstream>:
  match http:
    case False{}: None{}
    case True{}: split_rest(String.split(String.drop(s, 7n), '/'))

# http://host[:port][/base], host numeric IPv4 or localhost. No userinfo,
# query, fragment, https or IPv6 (the path check refuses '?' and '#').
def parse_url(+s: String) -> Maybe<&2, Upstream>:
  after_scheme(s, String.eq(String.to_lower(String.take(s, 7n)), "http://"))

# ---------------------------------------------------------------- request

def rewrite_pick(+path: String, +to: String, +n: Nat, hit: Bool) -> String:
  match hit:
    case True{}: to ++ String.drop(path, n)
    case False{}: path

def rewritten(+path: String, rule: Rewrite) -> String:
  match rule:
    case NoRewrite{}: path
    case Prefix{+from, to}: rewrite_pick(path, to, String.length(from), String.starts_with(path, from))

def target_ok(+p: String, +q: Maybe<&2, String>) -> Maybe<&2, String>:
  Bool.pick(Maybe<&2, String>, String.starts_with(p, "/") && Bytes.uri(p, False{}) && Request.query_valid(q), Some{p ++ Request.query_text(q)}, None{})

def star_target(+path: String, base: String, rule: Rewrite, q: Maybe<&2, String>, star: Bool) -> Maybe<&2, String>:
  match star:
    case True{}: Some{"*"}
    case False{}: target_ok(base ++ rewritten(path, rule), q)

# The request target sent upstream, or None when a rewrite leaves an invalid
# origin-form path. OPTIONS * stays "*".
def target(+path: String, base: String, rule: Rewrite, q: Maybe<&2, String>) -> Maybe<&2, String>:
  star_target(path, base, rule, q, String.eq(path, "*"))

def named(+name: String, names: List<&2, String>) -> Bool:
  match names:
    case Nil{}: False{}
    case n <> rest: String.eq(name, n) || named(name, rest)

def forwarding_names() -> List<&2, String>:
  ["forwarded", "x-forwarded-for", "x-forwarded-proto", "x-forwarded-host"]

# Fields Bendo regenerates or that belong to this proxy hop. Framing is
# recomputed; Expect was answered by the server; Proxy-Authorization is a
# credential for this proxy.
def own_names() -> List<&2, String>:
  ["host", "content-length", "transfer-encoding", "expect", "proxy-authorization", "forwarded", "x-forwarded-for", "x-forwarded-proto", "x-forwarded-host"]

def keep_pick(h: Request.Header, rest: List<&2, Request.Header>, keep: Bool) -> List<&2, Request.Header>:
  match keep:
    case True{}: h <> rest
    case False{}: rest

def without(+names: List<&2, String>, hs: List<&2, Request.Header>) -> List<&2, Request.Header>:
  match hs:
    case Nil{}: []
    case Request.Header{+n, v} <> t: keep_pick(Request.Header{n, v}, without(names, t), Bool.not(named(Bytes.fold(n), names)))

def ascii_values(vs: List<&2, List<&2, U32>>) -> List<&2, String>:
  match vs:
    case Nil{}: []
    case v <> t: Bytes.ascii(v) <> ascii_values(t)

def first_or(vs: List<&2, List<&2, U32>>, fallback: Maybe<&2, String>) -> Maybe<&2, String>:
  match vs:
    case Nil{}: fallback
    case v <> t: Some{Bytes.ascii(v)}

def first_value(vs: List<&2, List<&2, U32>>) -> Maybe<&2, String>:
  first_or(vs, None{})

def chain(old: List<&2, String>, mine: Maybe<&2, String>) -> Maybe<&2, String>:
  match old mine:
    case Nil{} None{}: None{}
    case old None{}: Some{String.join(old, ", ")}
    case old Some{m}: Some{String.join(List.append(&2, String, old, [m]), ", ")}

def trusted(+trust: Bool, vs: List<&2, List<&2, U32>>) -> List<&2, String>:
  match trust:
    case True{}: ascii_values(vs)
    case False{}: []

# RFC 7230 quoted-string: backslash-escape '"' and '\'.
def quote_chars(s: String) -> String:
  match s:
    case SNil{}: ""
    case SCon{Chr{34}, t}: "\\\"" ++ quote_chars(t)
    case SCon{Chr{92}, t}: "\\\\" ++ quote_chars(t)
    case SCon{c, t}: SCon{c, quote_chars(t)}

def quoted(s: String) -> String:
  "\"" ++ quote_chars(s) ++ "\""

# RFC 7239 node: IPv4 as a token, IPv6 bracketed and quoted.
def node(info: Maybe<&2, Conn.ConnInfo>) -> String:
  match info:
    case None{}: "unknown"
    case Some{Conn.ConnInfo{Ip.Addr{Ip.V4{}, bits}, text, port}}: text
    case Some{Conn.ConnInfo{Ip.Addr{Ip.V6{}, bits}, text, port}}: quoted("[" ++ text ++ "]")

def forwarded_element(+info: Maybe<&2, Conn.ConnInfo>, host: Maybe<&2, String>) -> String:
  match host:
    case None{}: "for=" ++ node(info) ++ ";proto=http"
    case Some{h}: "for=" ++ node(info) ++ ";host=" ++ quoted(h) ++ ";proto=http"

def peer_text(info: Maybe<&2, Conn.ConnInfo>) -> Maybe<&2, String>:
  match info:
    case None{}: None{}
    case Some{i}: Some{Conn.text(i)}

def field(name: String, value: Maybe<&2, String>) -> List<&2, Request.Header>:
  match value:
    case None{}: []
    case Some{v}: [Request.Header{name, Bytes.encode(v)}]

def forwarded_field(+on: Bool, old: List<&2, String>, mine: String) -> List<&2, Request.Header>:
  match on:
    case True{}: field("forwarded", chain(old, Some{mine}))
    case False{}: field("forwarded", chain(old, None{}))

def length_field(n: Nat, framed: Bool) -> List<&2, Request.Header>:
  match framed:
    case True{}: [Request.Header{"content-length", Bytes.encode(Nat.show(n))}]
    case False{}: []

def host_value(+preserve: Bool, +client: Maybe<&2, String>, authority: String) -> String:
  match preserve client:
    case True{} Some{h}: h
    case _ _: authority

# Every name a token and every value field-content, or the field is dropped.
def sane(h: Request.Header) -> Bool:
  Request.Header{n, v} = h
  Bytes.token(n) && Bytes.value(v)

def sane_all(hs: List<&2, Request.Header>) -> List<&2, Request.Header>:
  match hs:
    case Nil{}: []
    case +h <> t: keep_pick(h, sane_all(t), sane(h))

# The upstream header list. Hop-by-hop and Connection-listed fields of the
# original request are removed first, so a client naming Host,
# Content-Length or X-Forwarded-For in Connection cannot remove a field
# Bendo adds afterwards.
def request_headers(+o: Options, +up: Upstream, +hs: List<&2, Request.Header>, +info: Maybe<&2, Conn.ConnInfo>, +body_len: Nat) -> List<&2, Request.Header>:
  Options{url, +preserve, +trust, +fwd, rule, cms, sms, hms, rms, sc} = o
  Upstream{host, port, +authority, base} = up
  +end = Hop.forward(hs)
  +client = first_value(Request.lookup(end, "host"))
  +framed = Bool.not(Nat.is_eq(body_len, 0n)) || Bool.not(List.is_empty(&2, List<&2, U32>, Request.lookup(hs, "content-length"))) || Bool.not(List.is_empty(&2, List<&2, U32>, Request.lookup(hs, "transfer-encoding")))
  sane_all(List.concat(&2, Request.Header, [
    [Request.Header{"host", Bytes.encode(host_value(preserve, client, authority))}],
    without(own_names(), end),
    field("x-forwarded-for", chain(trusted(trust, Request.lookup(end, "x-forwarded-for")), peer_text(info))),
    field("x-forwarded-proto", chain(trusted(trust, Request.lookup(end, "x-forwarded-proto")), Some{"http"})),
    field("x-forwarded-host", chain(trusted(trust, Request.lookup(end, "x-forwarded-host")), client)),
    forwarded_field(fwd, trusted(trust, Request.lookup(end, "forwarded")), forwarded_element(info, client)),
    length_field(body_len, framed),
    [Request.Header{"connection", Bytes.encode("close")}]
  ]))

def head_bytes(m: Request.Method, target: String, hs: List<&2, Request.Header>) -> List<&2, U32>:
  Bytes.append(Bytes.encode(Request.method_text(m) ++ " " ++ target ++ " HTTP/1.1\r\n"), Write.headers(hs))

# ---------------------------------------------------------------- response head

type Head is Data:
  Line{reverse: List<&2, U32>, cr: Bool, count: Nat, interim: Nat}
  Fields{status: U32, version: Request.Version, headers: List<&2, Request.Header>, reverse: List<&2, U32>, cr: Bool, count: Nat, interim: Nat}
  Final{status: U32, version: Request.Version, headers: List<&2, Request.Header>}
  Bad{}

def head_initial() -> Head:
  Line{[], False{}, 0n, 0n}

def max_head() -> Nat: 65536n
def max_interim() -> Nat: 8n

def code3(a: U32, b: U32, c: U32) -> U32:
  ((a - 48 : U32) * 100 + (b - 48 : U32) * 10 + (c - 48 : U32) : U32)

def status_ok(+code: U32, version: Request.Version, +count: Nat, +interim: Nat, ok: Bool) -> Head:
  match ok:
    case False{}: Bad{}
    case True{}: Fields{code, version, [], [], False{}, count, interim}

def reason_ok(xs: List<&2, U32>) -> Bool:
  Bytes.value(xs)

def status_version(v: Maybe<&2, Request.Version>, +a: U32, +b: U32, +c: U32, rest: List<&2, U32>, +count: Nat, +interim: Nat) -> Head:
  match v rest:
    case None{} _: Bad{}
    case Some{version} 32 <> reason:
      +code = code3(a, b, c)
      status_ok(code, version, count, interim, digit(a) && digit(b) && digit(c) && (code >= 100 : U32) && (code <= 599 : U32) && reason_ok(reason))
    case Some{version} _: Bad{}

def version_of(+s: String) -> Maybe<&2, Request.Version>:
  Bool.pick(Maybe<&2, Request.Version>, String.eq(s, "HTTP/1.1"), Some{Request.Http11{}}, Bool.pick(Maybe<&2, Request.Version>, String.eq(s, "HTTP/1.0"), Some{Request.Http10{}}, None{}))

# status-line = HTTP-version SP 3DIGIT SP [ reason-phrase ] (RFC 9112 4).
# The SP after the code is required even with an empty reason.
def status_line(line: List<&2, U32>, +count: Nat, +interim: Nat) -> Head:
  match line:
    case v1 <> v2 <> v3 <> v4 <> v5 <> v6 <> v7 <> v8 <> 32 <> a <> b <> c <> rest:
      status_version(version_of(Bytes.ascii([v1, v2, v3, v4, v5, v6, v7, v8])), a, b, c, rest, count, interim)
    case _: Bad{}

def push_field(status: U32, version: Request.Version, hs: List<&2, Request.Header>, +count: Nat, +interim: Nat, f: Parse.Field) -> Head:
  match f:
    case Parse.MissingColon{}: Bad{}
    case Parse.Field{+n, +v}:
      Bool.pick(Head, Bytes.token(n) && Bytes.value(v), Fields{status, version, Request.Header{Bytes.fold(n), Bytes.trim(v)} <> hs, [], False{}, count, interim}, Bad{})

# 1xx other than 101 is interim: discard it and read the next head, within
# the same byte budget. 101 is refused: no Upgrade is ever forwarded.
def complete(+status: U32, version: Request.Version, hs: List<&2, Request.Header>, +count: Nat, +interim: Nat, informational: Bool) -> Head:
  match informational:
    case False{}: Final{status, version, List.reverse(&2, Request.Header, hs)}
    case True{}: Bool.pick(Head, Bool.not(U32.is_eq(status, 101)) && Nat.is_lt(interim, max_interim()), Line{[], False{}, count, Nat.add(interim, 1n)}, Bad{})

def field_line(+status: U32, version: Request.Version, hs: List<&2, Request.Header>, +count: Nat, +interim: Nat, line: List<&2, U32>) -> Head:
  match line:
    case Nil{}: complete(status, version, hs, count, interim, (status < 200 : U32))
    case 32 <> t: Bad{}
    case 9 <> t: Bad{}
    case c <> t: push_field(status, version, hs, count, interim, Parse.field(c <> t))

def line_octet(ok: Bool, +c: U32, rev: List<&2, U32>, +count: Nat, +interim: Nat) -> Head:
  match ok c:
    case True{} c: Line{c <> rev, False{}, count, interim}
    case False{} 13: Line{rev, True{}, count, interim}
    case False{} _: Bad{}

def field_octet(ok: Bool, +c: U32, status: U32, version: Request.Version, hs: List<&2, Request.Header>, rev: List<&2, U32>, +count: Nat, +interim: Nat) -> Head:
  match ok c:
    case True{} c: Fields{status, version, hs, c <> rev, False{}, count, interim}
    case False{} 13: Fields{status, version, hs, rev, True{}, count, interim}
    case False{} _: Bad{}

def head_step(s: Head, +c: U32) -> Head:
  match s c:
    case Line{rev, True{}, count, interim} 10: status_line(List.reverse(&2, U32, rev), count, interim)
    case Line{rev, True{}, count, interim} _: Bad{}
    case Line{rev, False{}, count, interim} c: line_octet(Bytes.value_octet(c), c, rev, count, interim)
    case Fields{status, version, hs, rev, True{}, count, interim} 10: field_line(status, version, hs, count, interim, List.reverse(&2, U32, rev))
    case Fields{status, version, hs, rev, True{}, count, interim} _: Bad{}
    case Fields{status, version, hs, rev, False{}, count, interim} c: field_octet(Bytes.value_octet(c), c, status, version, hs, rev, count, interim)
    case Final{status, version, hs} _: Final{status, version, hs}
    case Bad{} _: Bad{}

def counted(s: Head) -> Head:
  match s:
    case Line{rev, cr, +count, interim}: Bool.pick(Head, Nat.is_lt(count, max_head()), Line{rev, cr, Nat.add(count, 1n), interim}, Bad{})
    case Fields{status, version, hs, rev, cr, +count, interim}: Bool.pick(Head, Nat.is_lt(count, max_head()), Fields{status, version, hs, rev, cr, Nat.add(count, 1n), interim}, Bad{})
    case Final{status, version, hs}: Final{status, version, hs}
    case Bad{}: Bad{}

type HeadResult is Data:
  More{state: Head}
  Got{status: U32, version: Request.Version, headers: List<&2, Request.Header>, rest: List<&2, U32>}
  Malformed{}

# Feed newly received octets; on completion the unconsumed suffix is the
# start of the body.
def head_feed(xs: List<&2, U32>, s: Head) -> HeadResult:
  match xs s:
    case xs Final{status, version, hs}: Got{status, version, hs, xs}
    case _ Bad{}: Malformed{}
    case Nil{} s: More{s}
    case +c <> t s: head_feed(t, head_step(counted(s), c))

# ---------------------------------------------------------------- framing

type Framing is Data:
  NoBody{}
  Fixed{size: Nat}
  Chunks{}
  UntilClose{}
  Invalid{}

def list_digits(xs: List<&2, U32>) -> Maybe<&2, U32>:
  match xs:
    case Nil{}: None{}
    case +c <> t: Framing.decimal(c <> t, 0)

def lengths(parts: List<&2, List<&2, U32>>) -> List<&2, Maybe<&2, U32>>:
  match parts:
    case Nil{}: []
    case p <> t: list_digits(Bytes.trim(p)) <> lengths(t)

def all_values(vs: List<&2, List<&2, U32>>) -> List<&2, Maybe<&2, U32>>:
  match vs:
    case Nil{}: []
    case v <> t: List.append(&2, Maybe<&2, U32>, lengths(Hop.commas(v)), all_values(t))

def same_length(+n: U32, xs: List<&2, Maybe<&2, U32>>) -> Bool:
  match xs:
    case Nil{}: True{}
    case None{} <> t: False{}
    case Some{m} <> t: U32.is_eq(n, m) && same_length(n, t)

# RFC 9110 8.6: a list of identical valid lengths is that length.
def agreed(xs: List<&2, Maybe<&2, U32>>) -> Framing:
  match xs:
    case Nil{}: Invalid{}
    case None{} <> t: Invalid{}
    case Some{+n} <> t: Bool.pick(Framing, same_length(n, t), Fixed{U32.to_nat(n)}, Invalid{})

def coding(vs: List<&2, List<&2, U32>>) -> List<&2, String>:
  match vs:
    case Nil{}: []
    case v <> t: List.append(&2, String, Hop.token_names(Hop.commas(v)), coding(t))

def only_chunked(codings: List<&2, String>) -> Framing:
  match codings:
    case c <> Nil{}: Bool.pick(Framing, String.eq(c, "chunked"), Chunks{}, Invalid{})
    case _: Invalid{}

def transfer(v: Request.Version, cls: List<&2, List<&2, U32>>, tes: List<&2, List<&2, U32>>) -> Framing:
  match v cls tes:
    case _ Nil{} Nil{}: UntilClose{}
    case _ cls Nil{}: agreed(all_values(cls))
    case Request.Http11{} Nil{} tes: only_chunked(coding(tes))
    case _ _ _: Invalid{}

def bodyless(+status: U32, head: Bool) -> Bool:
  head || U32.is_eq(status, 204) || U32.is_eq(status, 304)

def framing_pick(v: Request.Version, +hs: List<&2, Request.Header>, none: Bool) -> Framing:
  match none:
    case True{}: NoBody{}
    case False{}: transfer(v, Request.lookup(hs, "content-length"), Request.lookup(hs, "transfer-encoding"))

# RFC 9112 6.3, from the raw upstream head before any filtering. Only
# exactly `chunked` is a supported transfer coding; Transfer-Encoding with
# Content-Length, an HTTP/1.0 Transfer-Encoding, or disagreeing or invalid
# lengths are refused.
def framing(+head_request: Bool, +status: U32, v: Request.Version, hs: List<&2, Request.Header>) -> Framing:
  framing_pick(v, hs, bodyless(status, head_request))

# Fields the client receives: hop-by-hop and Connection-listed fields gone,
# framing recomputed by the stream writer, proxy credentials dropped.
def response_headers(+hs: List<&2, Request.Header>) -> List<&2, Request.Header>:
  without(["content-length", "proxy-authenticate"], Hop.forward(hs))

# ---------------------------------------------------------------- body

type Body is Data:
  Remaining{left: Nat}
  Decoding{state: Chunked.State}
  ToClose{}
  Finished{}

type Fed is Data:
  Fed{bytes: List<&2, U32>, body: Body}
  Broken{}

def max_u32() -> U32: 4294967295

def start(f: Framing) -> Body:
  match f:
    case NoBody{}: Finished{}
    case Fixed{n}: Remaining{n}
    case Chunks{}: Decoding{Chunked.initial(max_u32())}
    case UntilClose{}: ToClose{}
    case Invalid{}: Finished{}

def take_go(xs: List<&2, U32>, left: Nat, acc: List<&2, U32>) -> List<&2, U32> & Nat:
  match xs left:
    case Nil{} left: (List.reverse(&2, U32, acc), left)
    case _ 0n: (List.reverse(&2, U32, acc), 0n)
    case c <> t 1n+n: take_go(t, n, c <> acc)

def fixed_fed(pair: List<&2, U32> & Nat) -> Fed:
  match pair:
    case (bytes, 0n): Fed{bytes, Finished{}}
    case (bytes, 1n+n): Fed{bytes, Remaining{1n+n}}

# Each drain hands back the octets decoded so far and resets the budget:
# the decoder never accumulates more than one receive.
def drained(s: Chunked.State) -> Fed:
  match s:
    case Chunked.Size{b, body, line, count, cr}: Fed{List.reverse(&2, U32, body), Decoding{Chunked.Size{max_u32(), [], line, count, cr}}}
    case Chunked.Payload{b, body, left}: Fed{List.reverse(&2, U32, body), Decoding{Chunked.Payload{max_u32(), [], left}}}
    case Chunked.DataCR{b, body}: Fed{List.reverse(&2, U32, body), Decoding{Chunked.DataCR{max_u32(), []}}}
    case Chunked.DataLF{b, body}: Fed{List.reverse(&2, U32, body), Decoding{Chunked.DataLF{max_u32(), []}}}
    case Chunked.Trailers{body, hs, line, count, cr}: Fed{List.reverse(&2, U32, body), Decoding{Chunked.Trailers{[], hs, line, count, cr}}}
    case Chunked.Complete{body, hs}: Fed{body, Finished{}}
    case Chunked.Failed{status}: Broken{}

def chunk_fed(pair: Chunked.State & Chunked.DecodeResult) -> Fed:
  (s, r) = pair
  drained(s)

# Octets received from upstream, decoded for the client.
def feed(b: Body, xs: List<&2, U32>) -> Fed:
  match b:
    case Remaining{left}: fixed_fed(take_go(xs, left, []))
    case Decoding{s}: chunk_fed(Chunked.feed(xs, s))
    case ToClose{}: Fed{xs, ToClose{}}
    case Finished{}: Fed{[], Finished{}}

# Upstream EOF: only a close-delimited body may end this way.
def at_eof(b: Body) -> Bool:
  match b:
    case Remaining{left}: False{}
    case Decoding{s}: False{}
    case ToClose{}: True{}
    case Finished{}: True{}

def done(b: Body) -> Bool:
  match b:
    case Finished{}: True{}
    case _: False{}
