# Web origins (RFC 6454) for http and https. An origin is serialized as
# "scheme://host" or "scheme://host:port": scheme and host in lowercase, and
# the port left out when it is the scheme's default (80 or 443).
import Base
import ./bytes.bend as Bytes

type Cut is Data:
  Cut{left: String, right: String}

def cut_prepend(c: Char, r: Maybe<&2, Cut>) -> Maybe<&2, Cut>:
  match r:
    case None{}: None{}
    case Some{Cut{a, b}}: Some{Cut{SCon{c, a}, b}}

def cut_pick(c: Char, t: String, rest: Maybe<&2, Cut>, here: Bool) -> Maybe<&2, Cut>:
  match here:
    case True{}: Some{Cut{"", t}}
    case False{}: cut_prepend(c, rest)

# Split at the first occurrence of sep.
def cut(s: String, +sep: Char) -> Maybe<&2, Cut>:
  match s:
    case SNil{}: None{}
    case SCon{+c, +t}: cut_pick(c, t, cut(t, sep), Char.is_eq(c, sep))

def ends_authority(c: Char) -> Bool:
  match c:
    case '/': True{}
    case '?': True{}
    case '#': True{}
    case _: False{}

def authority_prepend(c: Char, r: Cut) -> Cut:
  Cut{a, b} = r
  Cut{SCon{c, a}, b}

def authority_pick(c: Char, t: String, rest: Cut, end: Bool) -> Cut:
  match end:
    case True{}: Cut{"", SCon{c, t}}
    case False{}: authority_prepend(c, rest)

# The authority runs up to the first '/', '?' or '#'.
def authority(s: String) -> Cut:
  match s:
    case SNil{}: Cut{"", ""}
    case SCon{+c, +t}: authority_pick(c, t, authority(t), ends_authority(c))

def in_range(+x: U32, lo: U32, hi: U32) -> Bool:
  (x >= lo : U32) && (x <= hi : U32)

def digit(c: Char) -> Bool:
  match c:
    case Chr{+x}: in_range(x, 48, 57)

def digits(s: String) -> Bool:
  match s:
    case SNil{}: True{}
    case SCon{c, t}: digit(c) && digits(t)

# Host characters a browser serializes after IDNA: letters, digits, '-', '.'
# and '_'. Anything else (userinfo '@', '%', spaces) is rejected.
def name_char(c: Char) -> Bool:
  match c:
    case Chr{+x}: in_range(x, 97, 122) || in_range(x, 48, 57) || in_range(x, 45, 46) || U32.is_eq(x, 95)

def name_chars(s: String) -> Bool:
  match s:
    case SNil{}: True{}
    case SCon{c, t}: name_char(c) && name_chars(t)

# An IPv6 literal between brackets: hex digits, ':' and '.' (for an embedded
# IPv4 address). The text is kept as written, so "[::1]" and "[0::1]" differ.
def ipv6_char(c: Char) -> Bool:
  match c:
    case Chr{+x}: in_range(x, 97, 102) || in_range(x, 48, 58) || U32.is_eq(x, 46)

def ipv6_chars(s: String) -> Bool:
  match s:
    case SNil{}: True{}
    case SCon{c, t}: ipv6_char(c) && ipv6_chars(t)

def host_ok(+host: String, valid: Bool) -> Maybe<&2, String>:
  match valid:
    case True{}: Some{host}
    case False{}: None{}

def port_kept(+n: Nat, default: Bool) -> Maybe<&2, String>:
  match default:
    case True{}: Some{""}
    case False{}: Some{":" ++ Nat.show(n)}

def port_bounded(+n: Nat, +default: Nat, valid: Bool) -> Maybe<&2, String>:
  match valid:
    case True{}: port_kept(n, Nat.is_eq(n, default))
    case False{}: None{}

def port_number(n: Maybe<&2, Nat>, +default: Nat) -> Maybe<&2, String>:
  match n:
    case None{}: None{}
    case Some{+v}: port_bounded(v, default, Nat.is_le(v, 65535n))

def port_digits(+text: String, +default: Nat, empty: Bool, valid: Bool) -> Maybe<&2, String>:
  match empty valid:
    case True{} _: Some{""}
    case False{} True{}: port_number(Nat.read(text), default)
    case False{} False{}: None{}

# The port suffix: "" for no port, an empty port or the default port. At most
# five digits are read, so a long port cannot build a large number.
def port(+text: String, +default: Nat) -> Maybe<&2, String>:
  port_digits(text, default, String.is_empty(text), digits(text) && Nat.is_le(String.length(text), 5n))

def assemble(+scheme: String, host: Maybe<&2, String>, suffix: Maybe<&2, String>) -> Maybe<&2, String>:
  match host suffix:
    case Some{h} Some{p}: Some{scheme ++ "://" ++ h ++ p}
    case _ _: None{}

def bracketed_rest(+scheme: String, +default: Nat, +inside: String, rest: String) -> Maybe<&2, String>:
  match rest:
    case SNil{}: assemble(scheme, host_ok("[" ++ inside ++ "]", Bool.not(String.is_empty(inside)) && ipv6_chars(inside)), Some{""})
    case SCon{':', p}: assemble(scheme, host_ok("[" ++ inside ++ "]", Bool.not(String.is_empty(inside)) && ipv6_chars(inside)), port(p, default))
    case _: None{}

def bracketed(+scheme: String, +default: Nat, parts: Maybe<&2, Cut>) -> Maybe<&2, String>:
  match parts:
    case None{}: None{}
    case Some{Cut{inside, rest}}: bracketed_rest(scheme, default, inside, rest)

def named_host(+scheme: String, +host: String, suffix: Maybe<&2, String>) -> Maybe<&2, String>:
  assemble(scheme, host_ok(host, Bool.not(String.is_empty(host)) && name_chars(host)), suffix)

def named(+scheme: String, +default: Nat, +whole: String, parts: Maybe<&2, Cut>) -> Maybe<&2, String>:
  match parts:
    case None{}: named_host(scheme, whole, Some{""})
    case Some{Cut{+host, p}}: named_host(scheme, host, port(p, default))

def hostport(+scheme: String, +default: Nat, +auth: String) -> Maybe<&2, String>:
  match auth:
    case SCon{'[', +t}: bracketed(scheme, default, cut(t, ']'))
    case _: named(scheme, default, auth, cut(auth, ':'))

def tail_ok(allow_path: Bool, tail: String) -> Bool:
  match allow_path tail:
    case True{} _: True{}
    case False{} SNil{}: True{}
    case False{} _: False{}

def checked_tail(+scheme: String, +default: Nat, auth: String, ok: Bool) -> Maybe<&2, String>:
  match ok:
    case True{}: hostport(scheme, default, Bytes.fold(auth))
    case False{}: None{}

def split_authority(+scheme: String, +default: Nat, parts: Cut, allow_path: Bool) -> Maybe<&2, String>:
  match parts:
    case Cut{auth, tail}: checked_tail(scheme, default, auth, tail_ok(allow_path, tail))

def defaulted(+scheme: String, default: Maybe<&2, Nat>, rest: String, allow_path: Bool) -> Maybe<&2, String>:
  match default rest:
    case Some{+n} SCon{'/', SCon{'/', r}}: split_authority(scheme, n, authority(r), allow_path)
    case _ _: None{}

def web_http(http: Bool) -> Maybe<&2, Nat>:
  match http:
    case True{}: Some{80n}
    case False{}: None{}

def web_https(+scheme: String, https: Bool) -> Maybe<&2, Nat>:
  match https:
    case True{}: Some{443n}
    case False{}: web_http(String.eq(scheme, "http"))

# The default port of a lowercase web scheme; None for every other scheme.
def default_port(+scheme: String) -> Maybe<&2, Nat>:
  web_https(scheme, String.eq(scheme, "https"))

def schemed(+scheme: String, rest: String, allow_path: Bool) -> Maybe<&2, String>:
  defaulted(scheme, default_port(scheme), rest, allow_path)

def parse_cut(parts: Maybe<&2, Cut>, allow_path: Bool) -> Maybe<&2, String>:
  match parts:
    case None{}: None{}
    case Some{Cut{scheme, rest}}: schemed(Bytes.fold(scheme), rest, allow_path)

def parse(s: String, allow_path: Bool) -> Maybe<&2, String>:
  parse_cut(cut(String.trim(s), ':'), allow_path)

# The serialized origin of an Origin header value. "null", other schemes,
# userinfo and any path fail.
def canonical(s: String) -> Maybe<&2, String>:
  parse(s, False{})

# The origin a URL starts with, ignoring its path, query and fragment. Used
# for Referer values and for configured origins.
def of_url(s: String) -> Maybe<&2, String>:
  parse(s, True{})

# The origin a request addressed: a scheme the deployment knows (the server
# cannot see TLS behind a proxy) and the Host header.
def of_host(scheme: String, host: String) -> Maybe<&2, String>:
  parse(scheme ++ "://" ++ String.trim(host), False{})
