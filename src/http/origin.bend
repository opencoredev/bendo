# Web origins (RFC 6454) for http and https, serialized the way browsers send
# them (WHATWG URL): "scheme://host" or "scheme://host:port", the scheme and
# host in lowercase and the port left out when it is the scheme's default.
#
# A host is accepted only in the form browsers serialize: a DNS name, a
# dotted-quad IPv4 address without leading zeros, or a bracketed IPv6 address
# in RFC 5952 form. A host a browser would rewrite, such as "127.1", "0x7f.1"
# or "[0::1]", is rejected rather than normalized, so a configured origin
# either equals what browsers send or is dropped. proof/origin-spec.bend states
# the grammar without this module, and LAWS.bend equates the two.
import Base
import ./bytes.bend as Bytes
import ./text.bend as Text

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

def cut_spec(s: String, +sep: Char) -> Maybe<&2, Cut>:
  match s:
    case SNil{}: None{}
    case SCon{+c, +t}: cut_pick(c, t, cut_spec(t, sep), Char.is_eq(c, sep))

def from_text(r: Maybe<&2, Text.Cut>) -> Maybe<&2, Cut>:
  match r:
    case None{}: None{}
    case Some{Text.Cut{a, b}}: Some{Cut{a, b}}

# Split at the first occurrence of sep. Every loop over header text in this
# module is a tail call (BND-84).
def cut(s: String, +sep: Char) -> Maybe<&2, Cut>:
  from_text(Text.cut(s, sep))

def ends_authority(+c: Char) -> Bool:
  Char.is_eq(c, '/') || Char.is_eq(c, '?') || Char.is_eq(c, '#')

def authority_prepend(c: Char, r: Cut) -> Cut:
  Cut{a, b} = r
  Cut{SCon{c, a}, b}

def authority_pick(c: Char, t: String, rest: Cut, end: Bool) -> Cut:
  match end:
    case True{}: Cut{"", SCon{c, t}}
    case False{}: authority_prepend(c, rest)

def authority_spec(s: String) -> Cut:
  match s:
    case SNil{}: Cut{"", ""}
    case SCon{+c, +t}: authority_pick(c, t, authority_spec(t), ends_authority(c))

# The suffix read so far, from the right, and the spec's answer for it.
type Folded is Data:
  Folded{rest: String, cut: Cut}

def authority_fold(+c: Char, acc: Folded) -> Folded:
  match acc:
    case Folded{+t, res}: Folded{SCon{c, t}, authority_pick(c, t, res, ends_authority(c))}

def authority_answer(acc: Folded) -> Cut:
  match acc:
    case Folded{t, res}: res

def authority_go(rev: String, acc: Folded) -> Cut:
  match rev:
    case SNil{}: authority_answer(acc)
    case SCon{+c, r}: authority_go(r, authority_fold(c, acc))

# The authority runs up to the first '/', '?' or '#'.
def authority(s: String) -> Cut:
  authority_go(String.reverse(s), Folded{"", Cut{"", ""}})

def in_range(+x: U32, lo: U32, hi: U32) -> Bool:
  (x >= lo : U32) && (x <= hi : U32)

def digit(c: Char) -> Bool:
  match c:
    case Chr{+x}: in_range(x, 48, 57)

def digits_spec(s: String) -> Bool:
  match s:
    case SNil{}: True{}
    case SCon{c, t}: digit(c) && digits_spec(t)

def digits_go(rev: String, acc: Bool) -> Bool:
  match rev:
    case SNil{}: acc
    case SCon{c, r}: digits_go(r, digit(c) && acc)

def digits(s: String) -> Bool:
  digits_go(String.reverse(s), True{})

# Host characters a browser serializes after IDNA: letters, digits, '-', '.'
# and '_'. Anything else (userinfo '@', '%', spaces) is rejected.
def name_char(c: Char) -> Bool:
  match c:
    case Chr{+x}: in_range(x, 97, 122) || in_range(x, 48, 57) || in_range(x, 45, 46) || U32.is_eq(x, 95)

def name_chars_spec(s: String) -> Bool:
  match s:
    case SNil{}: True{}
    case SCon{c, t}: name_char(c) && name_chars_spec(t)

def name_chars_go(rev: String, acc: Bool) -> Bool:
  match rev:
    case SNil{}: acc
    case SCon{c, r}: name_chars_go(r, name_char(c) && acc)

def name_chars(s: String) -> Bool:
  name_chars_go(String.reverse(s), True{})

# Characters of an IPv6 literal with an embedded IPv4 address. The host check
# no longer uses these; they are kept for the tail_origin_ipv6_chars law.
def ipv6_char(c: Char) -> Bool:
  match c:
    case Chr{+x}: in_range(x, 97, 102) || in_range(x, 48, 58) || U32.is_eq(x, 46)

def ipv6_chars_spec(s: String) -> Bool:
  match s:
    case SNil{}: True{}
    case SCon{c, t}: ipv6_char(c) && ipv6_chars_spec(t)

def ipv6_chars_go(rev: String, acc: Bool) -> Bool:
  match rev:
    case SNil{}: acc
    case SCon{c, r}: ipv6_chars_go(r, ipv6_char(c) && acc)

def ipv6_chars(s: String) -> Bool:
  ipv6_chars_go(String.reverse(s), True{})

# ---- Hosts ----
# Each check reads at most 253 characters (a DNS name's limit, RFC 1035
# section 2.3.4), so these recurse directly.

def hex_digit(c: Char) -> Bool:
  match c:
    case Chr{+x}: in_range(x, 48, 57) || in_range(x, 97, 102)

def hex_digits(s: String) -> Bool:
  match s:
    case SNil{}: True{}
    case SCon{c, t}: hex_digit(c) && hex_digits(t)

def zero(c: Char) -> Bool:
  Char.is_eq(c, '0')

def hex_prefixed(s: String) -> Bool:
  match s:
    case SCon{a, SCon{b, t}}: zero(a) && Char.is_eq(b, 'x') && hex_digits(t)
    case _: False{}

# A label WHATWG reads as an IPv4 number: decimal digits, or "0x" and hex
# digits (the host is already lowercase).
def number(+label: String) -> Bool:
  (Bool.not(String.is_empty(label)) && digits_spec(label)) || hex_prefixed(label)

def second_label(rev: List<&2, String>) -> String:
  match rev:
    case Nil{}: ""
    case p <> t: p

def last_pick(+p: String, rest: List<&2, String>) -> String:
  match p:
    case SNil{}: second_label(rest)
    case SCon{c, t}: p

# The labels in reverse order. A trailing dot leaves an empty last label;
# then the one before it counts.
def last_label(rev: List<&2, String>) -> String:
  match rev:
    case Nil{}: ""
    case p <> t: last_pick(p, t)

# WHATWG URL's "ends in a number" check: such a host is an IPv4 address.
def ends_in_number(+host: String) -> Bool:
  number(last_label(List.reverse(&2, String, String.split(host, '.'))))

def at_most(c: Char, +x: U32) -> Bool:
  match c:
    case Chr{+y}: (y <= x : U32)

def below_256(+a: Char, +b: Char, c: Char) -> Bool:
  Char.is_eq(a, '1') || (Char.is_eq(a, '2') && (at_most(b, 52) || (Char.is_eq(b, '5') && at_most(c, 53))))

# A decimal octet, 0 to 255, without leading zeros.
def octet(s: String) -> Bool:
  match s:
    case SCon{a, SNil{}}: digit(a)
    case SCon{+a, SCon{b, SNil{}}}: digit(a) && digit(b) && Bool.not(zero(a))
    case SCon{+a, SCon{+b, SCon{+c, SNil{}}}}: digit(a) && digit(b) && digit(c) && below_256(a, b, c)
    case _: False{}

def quad(parts: List<&2, String>) -> Bool:
  match parts:
    case a <> (b <> (c <> (d <> Nil{}))): octet(a) && octet(b) && octet(c) && octet(d)
    case _: False{}

# A dotted-quad IPv4 address as browsers serialize it.
def ipv4(host: String) -> Bool:
  quad(String.split(host, '.'))

def name_kind(+host: String, numeric: Bool) -> Bool:
  match numeric:
    case True{}: ipv4(host)
    case False{}: Bool.not(String.is_empty(host)) && name_chars(host)

def name_bounded(+host: String, short: Bool) -> Bool:
  match short:
    case True{}: name_kind(host, ends_in_number(host))
    case False{}: False{}

# A host outside brackets: an IPv4 address when it ends in a number,
# otherwise a DNS name of letters, digits, '-', '.' and '_' (after IDNA). The
# name has at most 253 characters, not counting one trailing root dot, which
# stays in the serialized origin.
def name_host(+host: String) -> Bool:
  name_bounded(host, Nat.is_le(String.length(host), 253n) || (String.ends_with(host, ".") && Nat.is_le(String.length(host), 254n)))

# One 16-bit group of RFC 5952 text: one to four lowercase hex digits, no
# leading zero.
def group(g: String) -> Bool:
  match g:
    case SNil{}: False{}
    case SCon{+c, +t}: hex_digit(c) && hex_digits(t) && Nat.is_le(String.length(t), 3n) && (String.is_empty(t) || Bool.not(zero(c)))

def groups(gs: List<&2, String>) -> Bool:
  match gs:
    case Nil{}: True{}
    case g <> t: group(g) && groups(t)

def zero_group(g: String) -> Bool:
  String.eq(g, "0")

def run_next(+cur: Nat, hit: Bool) -> Nat:
  match hit:
    case True{}: 1n+cur
    case False{}: 0n

# The longest run of "0" groups; cur is the run that ends here, best the
# longest one before it.
def zero_run(gs: List<&2, String>, +cur: Nat, +best: Nat) -> Nat:
  match gs:
    case Nil{}: Nat.max(cur, best)
    case g <> t: zero_run(t, run_next(cur, zero_group(g)), Nat.max(cur, best))

def longest(gs: List<&2, String>) -> Nat:
  zero_run(gs, 0n, 0n)

def first_zero(gs: List<&2, String>) -> Bool:
  match gs:
    case Nil{}: False{}
    case g <> t: zero_group(g)

def pieces(+s: String) -> List<&2, String>:
  match s:
    case SNil{}: []
    case _: String.split(s, ':')

def colon_first(s: String) -> Bool:
  match s:
    case SNil{}: False{}
    case SCon{c, t}: Char.is_eq(c, ':')

def after_first(s: String) -> String:
  match s:
    case SNil{}: ""
    case SCon{c, t}: t

def pair_pick(c: Char, t: String, rest: Maybe<&2, Cut>, here: Bool) -> Maybe<&2, Cut>:
  match here:
    case True{}: Some{Cut{"", after_first(t)}}
    case False{}: cut_prepend(c, rest)

# Split at the first "::".
def cut_pair(s: String) -> Maybe<&2, Cut>:
  match s:
    case SNil{}: None{}
    case SCon{+c, +t}: pair_pick(c, t, cut_pair(t), Char.is_eq(c, ':') && colon_first(t))

# Eight groups and no run of two zero groups, which "::" would have shortened.
def full(+gs: List<&2, String>) -> Bool:
  Nat.is_eq(List.length(&2, String, gs), 8n) && groups(gs) && Nat.is_lt(longest(gs), 2n)

# "::" stands for gap >= 2 zero groups: the longest run, and the first of the
# longest runs, so no zero group touches it and no run before it is as long.
def gapped(+left: List<&2, String>, +right: List<&2, String>, +gap: Nat) -> Bool:
  Nat.is_lt(longest(left), gap) && Nat.is_le(longest(right), gap) && Bool.not(first_zero(List.reverse(&2, String, left))) && Bool.not(first_zero(right))

def compressed(+left: List<&2, String>, +right: List<&2, String>) -> Bool:
  groups(left) && groups(right) && Nat.is_le(Nat.add(List.length(&2, String, left), List.length(&2, String, right)), 6n) && gapped(left, right, Nat.sub(8n, Nat.add(List.length(&2, String, left), List.length(&2, String, right))))

def ipv6_parts(+text: String, parts: Maybe<&2, Cut>) -> Bool:
  match parts:
    case None{}: full(String.split(text, ':'))
    case Some{Cut{a, b}}: compressed(pieces(a), pieces(b))

def ipv6_bounded(+text: String, short: Bool) -> Bool:
  match short:
    case True{}: ipv6_parts(text, cut_pair(text))
    case False{}: False{}

# An IPv6 address in RFC 5952 form (section 4), the only form browsers send.
# Such text is at most 39 characters.
def ipv6(+text: String) -> Bool:
  ipv6_bounded(text, Nat.is_le(String.length(text), 39n))

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

def bracketed_port(+scheme: String, +default: Nat, +inside: String, p: String, colon: Bool) -> Maybe<&2, String>:
  match colon:
    case True{}: assemble(scheme, host_ok("[" ++ inside ++ "]", ipv6(inside)), port(p, default))
    case False{}: None{}

def bracketed_rest(+scheme: String, +default: Nat, +inside: String, rest: String) -> Maybe<&2, String>:
  match rest:
    case SNil{}: assemble(scheme, host_ok("[" ++ inside ++ "]", ipv6(inside)), Some{""})
    case SCon{c, p}: bracketed_port(scheme, default, inside, p, Char.is_eq(c, ':'))

def bracketed(+scheme: String, +default: Nat, parts: Maybe<&2, Cut>) -> Maybe<&2, String>:
  match parts:
    case None{}: None{}
    case Some{Cut{inside, rest}}: bracketed_rest(scheme, default, inside, rest)

def named_host(+scheme: String, +host: String, suffix: Maybe<&2, String>) -> Maybe<&2, String>:
  assemble(scheme, host_ok(host, name_host(host)), suffix)

def named(+scheme: String, +default: Nat, +whole: String, parts: Maybe<&2, Cut>) -> Maybe<&2, String>:
  match parts:
    case None{}: named_host(scheme, whole, Some{""})
    case Some{Cut{+host, p}}: named_host(scheme, host, port(p, default))

def hostport_at(+scheme: String, +default: Nat, +c: Char, +t: String, bracket: Bool) -> Maybe<&2, String>:
  match bracket:
    case True{}: bracketed(scheme, default, cut(t, ']'))
    case False{}: named(scheme, default, SCon{c, t}, cut(SCon{c, t}, ':'))

def hostport(+scheme: String, +default: Nat, auth: String) -> Maybe<&2, String>:
  match auth:
    case SNil{}: None{}
    case SCon{+c, +t}: hostport_at(scheme, default, c, t, Char.is_eq(c, '['))

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

def slashed(+scheme: String, +default: Nat, r: String, allow_path: Bool, ok: Bool) -> Maybe<&2, String>:
  match ok:
    case True{}: split_authority(scheme, default, authority(r), allow_path)
    case False{}: None{}

def slashes(+scheme: String, +default: Nat, rest: String, allow_path: Bool) -> Maybe<&2, String>:
  match rest:
    case SCon{a, SCon{b, r}}: slashed(scheme, default, r, allow_path, Char.is_eq(a, '/') && Char.is_eq(b, '/'))
    case _: None{}

# A web scheme, as serialized, and its default port.
type Web is Data:
  Web{name: String, port: Nat}

def defaulted(web: Maybe<&2, Web>, rest: String, allow_path: Bool) -> Maybe<&2, String>:
  match web:
    case None{}: None{}
    case Some{Web{+name, +n}}: slashes(name, n, rest, allow_path)

def web_http(http: Bool) -> Maybe<&2, Web>:
  match http:
    case True{}: Some{Web{"http", 80n}}
    case False{}: None{}

def web_https(+scheme: String, https: Bool) -> Maybe<&2, Web>:
  match https:
    case True{}: Some{Web{"https", 443n}}
    case False{}: web_http(String.eq(scheme, "http"))

# A lowercase web scheme; None for every other scheme.
def web(+scheme: String) -> Maybe<&2, Web>:
  web_https(scheme, String.eq(scheme, "https"))

def parse_cut(parts: Maybe<&2, Cut>, allow_path: Bool) -> Maybe<&2, String>:
  match parts:
    case None{}: None{}
    case Some{Cut{scheme, rest}}: defaulted(web(Bytes.fold(scheme)), rest, allow_path)

def parse(s: String, allow_path: Bool) -> Maybe<&2, String>:
  parse_cut(cut(Bytes.trim_text(s), ':'), allow_path)

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
  parse(scheme ++ "://" ++ Bytes.trim_text(host), False{})
