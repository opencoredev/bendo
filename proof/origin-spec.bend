# BND-85: web origins for http and https, stated without
# src/http/origin.bend. An origin is a scheme, a host and an effective port
# (RFC 6454 section 4), serialized the way WHATWG URL serializes it:
# "scheme://host", plus ":port" unless the port is the scheme's default.
#
# The host must already be in that serialized form, so text a browser would
# rewrite is no origin at all:
# - a bracketed IPv6 address in RFC 5952 form (section 4);
# - a dotted-quad IPv4 address with decimal octets 0 to 255 and no leading
#   zeros, which is how WHATWG serializes every IPv4 host;
# - otherwise a DNS name of lowercase letters, digits, '-', '.' and '_' (the
#   characters left after IDNA) of at most 253 characters (RFC 1035 section
#   2.3.4), which must not end in a number: WHATWG would parse such a host
#   as IPv4 ("127.1", "0x7f.1", "1.2.3.4.").
# Scheme and host compare in ASCII lowercase. The value is trimmed of SP and
# HTAB first (proof/trim-spec.bend).
import Base
import ./trim-spec.bend as Trim

# ---- The origin and its serialization ----

# port is None for the scheme's default port, else its decimal digits.
type Origin is Data:
  Origin{scheme: String, host: String, port: Maybe<&2, String>}

def suffix(port: Maybe<&2, String>) -> String:
  match port:
    case None{}: ""
    case Some{p}: ":" ++ p

def serialize(t: Origin) -> String:
  match t:
    case Origin{s, h, p}: s ++ "://" ++ h ++ suffix(p)

def serialized(m: Maybe<&2, Origin>) -> Maybe<&2, String>:
  match m:
    case None{}: None{}
    case Some{t}: Some{serialize(t)}

# ---- Characters ----

def between(+x: U32, lo: U32, hi: U32) -> Bool:
  (x >= lo : U32) && (x <= hi : U32)

def decimal(c: Char) -> Bool:
  match c:
    case Chr{+x}: between(x, 48, 57)

def hex(c: Char) -> Bool:
  match c:
    case Chr{+x}: between(x, 48, 57) || between(x, 97, 102)

# a-z, 0-9, '-', '.' and '_'.
def host_char(c: Char) -> Bool:
  match c:
    case Chr{+x}: between(x, 97, 122) || between(x, 48, 57) || between(x, 45, 46) || U32.is_eq(x, 95)

def decimals(s: String) -> Bool:
  match s:
    case SNil{}: True{}
    case SCon{c, t}: decimal(c) && decimals(t)

def hexes(s: String) -> Bool:
  match s:
    case SNil{}: True{}
    case SCon{c, t}: hex(c) && hexes(t)

def host_chars(s: String) -> Bool:
  match s:
    case SNil{}: True{}
    case SCon{c, t}: host_char(c) && host_chars(t)

# ---- Splitting ----

type Split is Data:
  Split{before: String, after: String}

def split_prepend(c: Char, r: Maybe<&2, Split>) -> Maybe<&2, Split>:
  match r:
    case None{}: None{}
    case Some{Split{a, b}}: Some{Split{SCon{c, a}, b}}

def split_pick(c: Char, t: String, rest: Maybe<&2, Split>, here: Bool) -> Maybe<&2, Split>:
  match here:
    case True{}: Some{Split{"", t}}
    case False{}: split_prepend(c, rest)

# The text before and after the first sep; None without one.
def split_at(s: String, +sep: Char) -> Maybe<&2, Split>:
  match s:
    case SNil{}: None{}
    case SCon{+c, +t}: split_pick(c, t, split_at(t, sep), Char.is_eq(c, sep))

# The authority ends at the first '/', '?' or '#' (RFC 3986 section 3.2).
def ends(+c: Char) -> Bool:
  Char.is_eq(c, '/') || Char.is_eq(c, '?') || Char.is_eq(c, '#')

def authority_prepend(c: Char, r: Split) -> Split:
  match r:
    case Split{a, b}: Split{SCon{c, a}, b}

def authority_pick(c: Char, t: String, rest: Split, end: Bool) -> Split:
  match end:
    case True{}: Split{"", SCon{c, t}}
    case False{}: authority_prepend(c, rest)

def authority(s: String) -> Split:
  match s:
    case SNil{}: Split{"", ""}
    case SCon{+c, +t}: authority_pick(c, t, authority(t), ends(c))

# ---- IPv4 ----

def nonzero_lead(c: Char) -> Bool:
  Bool.not(Char.is_eq(c, '0'))

def code_at_most(c: Char, +x: U32) -> Bool:
  match c:
    case Chr{+y}: (y <= x : U32)

# Three digits abc are at most 255.
def up_to_255(+a: Char, +b: Char, c: Char) -> Bool:
  Char.is_eq(a, '1') || (Char.is_eq(a, '2') && (code_at_most(b, 52) || (Char.is_eq(b, '5') && code_at_most(c, 53))))

# "0" to "255", without leading zeros.
def dec_octet(s: String) -> Bool:
  match s:
    case SCon{a, SNil{}}: decimal(a)
    case SCon{+a, SCon{b, SNil{}}}: decimal(a) && decimal(b) && nonzero_lead(a)
    case SCon{+a, SCon{+b, SCon{+c, SNil{}}}}: decimal(a) && decimal(b) && decimal(c) && up_to_255(a, b, c)
    case _: False{}

def four_octets(parts: List<&2, String>) -> Bool:
  match parts:
    case a <> (b <> (c <> (d <> Nil{}))): dec_octet(a) && dec_octet(b) && dec_octet(c) && dec_octet(d)
    case _: False{}

def ipv4(host: String) -> Bool:
  four_octets(String.split(host, '.'))

# ---- DNS names ----

# "0x" and hex digits: WHATWG's IPv4 number parser reads it as a number.
def hex_number(s: String) -> Bool:
  match s:
    case SCon{a, SCon{b, t}}: Char.is_eq(a, '0') && Char.is_eq(b, 'x') && hexes(t)
    case _: False{}

def numeric(+label: String) -> Bool:
  (Bool.not(String.is_empty(label)) && decimals(label)) || hex_number(label)

def before_last(labels: List<&2, String>) -> String:
  match labels:
    case Nil{}: ""
    case p <> t: p

def last_nonempty(+p: String, labels: List<&2, String>) -> String:
  match p:
    case SNil{}: before_last(labels)
    case SCon{c, t}: p

# Labels in reverse order: the last label, or the one before an empty last
# label (a trailing dot).
def final_label(labels: List<&2, String>) -> String:
  match labels:
    case Nil{}: ""
    case p <> t: last_nonempty(p, t)

# WHATWG URL's "ends in a number" check.
def ends_in_number(+host: String) -> Bool:
  numeric(final_label(List.reverse(&2, String, String.split(host, '.'))))

def host_kind(+host: String, number: Bool) -> Bool:
  match number:
    case True{}: ipv4(host)
    case False{}: Bool.not(String.is_empty(host)) && host_chars(host)

def host_short(+host: String, short: Bool) -> Bool:
  match short:
    case True{}: host_kind(host, ends_in_number(host))
    case False{}: False{}

# A host outside brackets: IPv4 when it ends in a number, else a DNS name.
# RFC 1035 section 3.1 limits a name to 255 octets on the wire, which is 253
# characters of text; a fully qualified name's trailing root dot is the empty
# root label and does not count.
def name_host(+host: String) -> Bool:
  host_short(host, Nat.is_le(String.length(host), 253n) || (String.ends_with(host, ".") && Nat.is_le(String.length(host), 254n)))

# ---- IPv6 in RFC 5952 form ----

# One group: one to four lowercase hex digits (4.3), no leading zero (4.1).
def hex_group(g: String) -> Bool:
  match g:
    case SNil{}: False{}
    case SCon{+c, +t}: hex(c) && hexes(t) && Nat.is_le(String.length(t), 3n) && (String.is_empty(t) || nonzero_lead(c))

def hex_groups(gs: List<&2, String>) -> Bool:
  match gs:
    case Nil{}: True{}
    case g <> t: hex_group(g) && hex_groups(t)

def is_zero_group(g: String) -> Bool:
  String.eq(g, "0")

def run_after(+cur: Nat, zero: Bool) -> Nat:
  match zero:
    case True{}: 1n+cur
    case False{}: 0n

# The longest run of "0" groups. cur is the run ending here; best the longest
# before it.
def zeros(gs: List<&2, String>, +cur: Nat, +best: Nat) -> Nat:
  match gs:
    case Nil{}: Nat.max(cur, best)
    case g <> t: zeros(t, run_after(cur, is_zero_group(g)), Nat.max(cur, best))

def longest_zeros(gs: List<&2, String>) -> Nat:
  zeros(gs, 0n, 0n)

def starts_zero(gs: List<&2, String>) -> Bool:
  match gs:
    case Nil{}: False{}
    case g <> t: is_zero_group(g)

def group_list(+s: String) -> List<&2, String>:
  match s:
    case SNil{}: []
    case _: String.split(s, ':')

def next_colon(s: String) -> Bool:
  match s:
    case SNil{}: False{}
    case SCon{c, t}: Char.is_eq(c, ':')

def drop_one(s: String) -> String:
  match s:
    case SNil{}: ""
    case SCon{c, t}: t

def double_pick(c: Char, t: String, rest: Maybe<&2, Split>, here: Bool) -> Maybe<&2, Split>:
  match here:
    case True{}: Some{Split{"", drop_one(t)}}
    case False{}: split_prepend(c, rest)

# The text before and after the first "::".
def split_double(s: String) -> Maybe<&2, Split>:
  match s:
    case SNil{}: None{}
    case SCon{+c, +t}: double_pick(c, t, split_double(t), Char.is_eq(c, ':') && next_colon(t))

# Without "::": eight groups, and no two zero groups in a row (4.2.2 would
# have compressed them).
def uncompressed(+gs: List<&2, String>) -> Bool:
  Nat.is_eq(List.length(&2, String, gs), 8n) && hex_groups(gs) && Nat.is_lt(longest_zeros(gs), 2n)

# "::" replaces gap >= 2 zero groups (4.2.2). It is the longest run (4.2.1)
# and the first of the longest runs (4.2.3): no run before it is as long, none
# after it is longer, and no zero group touches it.
def compression(+left: List<&2, String>, +right: List<&2, String>, +gap: Nat) -> Bool:
  Nat.is_lt(longest_zeros(left), gap) && Nat.is_le(longest_zeros(right), gap) && Bool.not(starts_zero(List.reverse(&2, String, left))) && Bool.not(starts_zero(right))

def compressed(+left: List<&2, String>, +right: List<&2, String>) -> Bool:
  hex_groups(left) && hex_groups(right) && Nat.is_le(Nat.add(List.length(&2, String, left), List.length(&2, String, right)), 6n) && compression(left, right, Nat.sub(8n, Nat.add(List.length(&2, String, left), List.length(&2, String, right))))

def v6_parts(+text: String, parts: Maybe<&2, Split>) -> Bool:
  match parts:
    case None{}: uncompressed(String.split(text, ':'))
    case Some{Split{a, b}}: compressed(group_list(a), group_list(b))

def v6_short(+text: String, short: Bool) -> Bool:
  match short:
    case True{}: v6_parts(text, split_double(text))
    case False{}: False{}

# RFC 5952 text is at most 39 characters (eight groups of four and seven
# colons), so longer text is not read.
def ipv6(+text: String) -> Bool:
  v6_short(text, Nat.is_le(String.length(text), 39n))

# ---- Ports ----

# The port as the tuple keeps it, or None when it is out of range.
def port_default(+n: Nat, default: Bool) -> Maybe<&2, Maybe<&2, String>>:
  match default:
    case True{}: Some{None{}}
    case False{}: Some{Some{Nat.show(n)}}

def port_range(+n: Nat, +default: Nat, valid: Bool) -> Maybe<&2, Maybe<&2, String>>:
  match valid:
    case True{}: port_default(n, Nat.is_eq(n, default))
    case False{}: None{}

def port_read(n: Maybe<&2, Nat>, +default: Nat) -> Maybe<&2, Maybe<&2, String>>:
  match n:
    case None{}: None{}
    case Some{+v}: port_range(v, default, Nat.is_le(v, 65535n))

def port_text(+text: String, +default: Nat, empty: Bool, valid: Bool) -> Maybe<&2, Maybe<&2, String>>:
  match empty valid:
    case True{} _: Some{None{}}
    case False{} True{}: port_read(Nat.read(text), default)
    case False{} False{}: None{}

# The text after ':': empty, or up to five decimal digits with a value of at
# most 65535. An empty port and the default port both mean the default.
def port(+text: String, +default: Nat) -> Maybe<&2, Maybe<&2, String>>:
  port_text(text, default, String.is_empty(text), decimals(text) && Nat.is_le(String.length(text), 5n))

# ---- Parsing ----

def origin(+scheme: String, host: Maybe<&2, String>, port: Maybe<&2, Maybe<&2, String>>) -> Maybe<&2, Origin>:
  match host port:
    case Some{h} Some{p}: Some{Origin{scheme, h, p}}
    case _ _: None{}

def valid_host(+host: String, valid: Bool) -> Maybe<&2, String>:
  match valid:
    case True{}: Some{host}
    case False{}: None{}

def bracket_port(+scheme: String, +default: Nat, +inside: String, p: String, colon: Bool) -> Maybe<&2, Origin>:
  match colon:
    case True{}: origin(scheme, valid_host("[" ++ inside ++ "]", ipv6(inside)), port(p, default))
    case False{}: None{}

def bracket_rest(+scheme: String, +default: Nat, +inside: String, rest: String) -> Maybe<&2, Origin>:
  match rest:
    case SNil{}: origin(scheme, valid_host("[" ++ inside ++ "]", ipv6(inside)), Some{None{}})
    case SCon{c, p}: bracket_port(scheme, default, inside, p, Char.is_eq(c, ':'))

def bracketed(+scheme: String, +default: Nat, parts: Maybe<&2, Split>) -> Maybe<&2, Origin>:
  match parts:
    case None{}: None{}
    case Some{Split{inside, rest}}: bracket_rest(scheme, default, inside, rest)

def named_with(+scheme: String, +host: String, port: Maybe<&2, Maybe<&2, String>>) -> Maybe<&2, Origin>:
  origin(scheme, valid_host(host, name_host(host)), port)

def named(+scheme: String, +default: Nat, +whole: String, parts: Maybe<&2, Split>) -> Maybe<&2, Origin>:
  match parts:
    case None{}: named_with(scheme, whole, Some{None{}})
    case Some{Split{+host, p}}: named_with(scheme, host, port(p, default))

def host_at(+scheme: String, +default: Nat, +c: Char, +t: String, bracket: Bool) -> Maybe<&2, Origin>:
  match bracket:
    case True{}: bracketed(scheme, default, split_at(t, ']'))
    case False{}: named(scheme, default, SCon{c, t}, split_at(SCon{c, t}, ':'))

# The host and port of a lowercase authority. Userinfo ('@') and an empty
# host fail.
def host_port(+scheme: String, +default: Nat, auth: String) -> Maybe<&2, Origin>:
  match auth:
    case SNil{}: None{}
    case SCon{+c, +t}: host_at(scheme, default, c, t, Char.is_eq(c, '['))

# Only a URL may have a path, query or fragment after the authority.
def path_ok(url: Bool, rest: String) -> Bool:
  match url rest:
    case True{} _: True{}
    case False{} SNil{}: True{}
    case False{} _: False{}

def checked(+scheme: String, +default: Nat, auth: String, ok: Bool) -> Maybe<&2, Origin>:
  match ok:
    case True{}: host_port(scheme, default, String.to_lower(auth))
    case False{}: None{}

def after_authority(+scheme: String, +default: Nat, parts: Split, url: Bool) -> Maybe<&2, Origin>:
  match parts:
    case Split{auth, rest}: checked(scheme, default, auth, path_ok(url, rest))

def slashed(+scheme: String, +default: Nat, r: String, url: Bool, ok: Bool) -> Maybe<&2, Origin>:
  match ok:
    case True{}: after_authority(scheme, default, authority(r), url)
    case False{}: None{}

def slashes(+scheme: String, +default: Nat, rest: String, url: Bool) -> Maybe<&2, Origin>:
  match rest:
    case SCon{a, SCon{b, r}}: slashed(scheme, default, r, url, Char.is_eq(a, '/') && Char.is_eq(b, '/'))
    case _: None{}

type Scheme is Data:
  Scheme{name: String, port: Nat}

def known(scheme: Maybe<&2, Scheme>, rest: String, url: Bool) -> Maybe<&2, Origin>:
  match scheme:
    case None{}: None{}
    case Some{Scheme{+name, +n}}: slashes(name, n, rest, url)

def http(is_http: Bool) -> Maybe<&2, Scheme>:
  match is_http:
    case True{}: Some{Scheme{"http", 80n}}
    case False{}: None{}

def https(+s: String, is_https: Bool) -> Maybe<&2, Scheme>:
  match is_https:
    case True{}: Some{Scheme{"https", 443n}}
    case False{}: http(String.eq(s, "http"))

# http (default port 80) and https (443), in lowercase; nothing else.
def scheme(+s: String) -> Maybe<&2, Scheme>:
  https(s, String.eq(s, "https"))

def parse_split(parts: Maybe<&2, Split>, url: Bool) -> Maybe<&2, Origin>:
  match parts:
    case None{}: None{}
    case Some{Split{s, rest}}: known(scheme(String.to_lower(s)), rest, url)

# The origin of s. A URL (url = True) may continue with a path, query or
# fragment; an Origin value may not.
def parse(s: String, url: Bool) -> Maybe<&2, Origin>:
  parse_split(split_at(Trim.trim(s), ':'), url)

# An Origin header value.
def canonical(s: String) -> Maybe<&2, String>:
  serialized(parse(s, False{}))

# The origin of a URL (Referer, configured origins).
def of_url(s: String) -> Maybe<&2, String>:
  serialized(parse(s, True{}))

# The origin a request addressed: the deployment's scheme and the Host value.
def of_host(scheme: String, host: String) -> Maybe<&2, String>:
  serialized(parse(scheme ++ "://" ++ Trim.trim(host), False{}))

# ---- Reading a serialized origin back ----

def read_colon(p: String, colon: Bool) -> Maybe<&2, Maybe<&2, String>>:
  match colon:
    case True{}: Some{Some{p}}
    case False{}: None{}

def read_port(rest: String) -> Maybe<&2, Maybe<&2, String>>:
  match rest:
    case SNil{}: Some{None{}}
    case SCon{c, p}: read_colon(p, Char.is_eq(c, ':'))

def read_with(+scheme: String, +host: String, port: Maybe<&2, Maybe<&2, String>>) -> Maybe<&2, Origin>:
  match port:
    case None{}: None{}
    case Some{p}: Some{Origin{scheme, host, p}}

def read_bracket(+scheme: String, parts: Maybe<&2, Split>) -> Maybe<&2, Origin>:
  match parts:
    case None{}: None{}
    case Some{Split{inside, rest}}: read_with(scheme, "[" ++ inside ++ "]", read_port(rest))

def read_name(+scheme: String, +whole: String, parts: Maybe<&2, Split>) -> Maybe<&2, Origin>:
  match parts:
    case None{}: Some{Origin{scheme, whole, None{}}}
    case Some{Split{host, p}}: Some{Origin{scheme, host, Some{p}}}

def read_at(+scheme: String, +c: Char, +t: String, bracket: Bool) -> Maybe<&2, Origin>:
  match bracket:
    case True{}: read_bracket(scheme, split_at(t, ']'))
    case False{}: read_name(scheme, SCon{c, t}, split_at(SCon{c, t}, ':'))

def read_authority(+scheme: String, auth: String) -> Maybe<&2, Origin>:
  match auth:
    case SNil{}: None{}
    case SCon{+c, +t}: read_at(scheme, c, t, Char.is_eq(c, '['))

def read_slashed(+scheme: String, r: String, ok: Bool) -> Maybe<&2, Origin>:
  match ok:
    case True{}: read_authority(scheme, r)
    case False{}: None{}

def read_slashes(+scheme: String, rest: String) -> Maybe<&2, Origin>:
  match rest:
    case SCon{a, SCon{b, r}}: read_slashed(scheme, r, Char.is_eq(a, '/') && Char.is_eq(b, '/'))
    case _: None{}

def read_split(parts: Maybe<&2, Split>) -> Maybe<&2, Origin>:
  match parts:
    case None{}: None{}
    case Some{Split{scheme, rest}}: read_slashes(scheme, rest)

# Scheme, host and port, read from "scheme://host[:port]".
def read(o: String) -> Maybe<&2, Origin>:
  read_split(split_at(o, ':'))

def read_back(m: Maybe<&2, String>) -> Maybe<&2, Origin>:
  match m:
    case None{}: None{}
    case Some{o}: read(o)
