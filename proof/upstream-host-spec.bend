# BND-93: the host and port of a proxy upstream URL, stated without
# src/http/upstream.bend's parser or src/http/origin.bend. It builds on the
# origin specification (proof/origin-spec.bend) and imports only the
# Upstream.Endpoint record.
#
# A lowercase authority is accepted exactly when it is one of:
# - "[" v6 "]", optionally followed by ":" port, where v6 is an IPv6 address
#   in RFC 5952 form (OriginSpec.ipv6);
# - name, optionally followed by ":" port, where name is an origin host
#   outside brackets (OriginSpec.name_host: a dotted-quad IPv4 address, or a
#   DNS name of a-z, 0-9, '-', '.' and '_' of at most 253 characters that
#   does not end in a number) whose dot-separated labels all have 1 to 63
#   characters and neither start nor end with '-' (RFC 1123 section 2.1);
# - and port is one to five decimal digits with a value from 1 to 65535.
# The host splits from the port at the first ']' after a '[', or else at the
# first ':'. The endpoint keeps the host and the port digits as written.
import Base
import ./origin-spec.bend as S
import ../src/http/upstream.bend as U

def label(+l: String) -> Bool:
  Nat.is_lt(0n, String.length(l)) && Nat.is_le(String.length(l), 63n) && Bool.not(String.starts_with(l, "-")) && Bool.not(String.ends_with(l, "-"))

def labels(ls: List<&2, String>) -> Bool:
  match ls:
    case Nil{}: True{}
    case +l <> t: label(l) && labels(t)

def name(+h: String) -> Bool:
  S.name_host(h) && labels(String.split(h, '.'))

def in_range(n: Maybe<&2, Nat>) -> Bool:
  match n:
    case None{}: False{}
    case Some{+v}: Nat.is_lt(0n, v) && Nat.is_le(v, 65535n)

def port_digits(+p: String, short: Bool) -> Bool:
  match short:
    case True{}: in_range(Nat.read(p))
    case False{}: False{}

def port(+p: String) -> Bool:
  port_digits(p, S.decimals(p) && Nat.is_lt(0n, String.length(p)) && Nat.is_le(String.length(p), 5n))

def made(+host: U.Host, +p: Maybe<&2, String>, ok: Bool) -> Maybe<&2, U.Endpoint>:
  match ok:
    case True{}: Some{U.Endpoint{host, p}}
    case False{}: None{}

def v6_port(+inside: String, +p: String, colon: Bool) -> Maybe<&2, U.Endpoint>:
  match colon:
    case True{}: made(U.HostV6{inside}, Some{p}, S.ipv6(inside) && port(p))
    case False{}: None{}

def v6_rest(+inside: String, rest: String) -> Maybe<&2, U.Endpoint>:
  match rest:
    case SNil{}: made(U.HostV6{inside}, None{}, S.ipv6(inside))
    case SCon{c, p}: v6_port(inside, p, Char.is_eq(c, ':'))

def v6(parts: Maybe<&2, S.Split>) -> Maybe<&2, U.Endpoint>:
  match parts:
    case None{}: None{}
    case Some{S.Split{inside, rest}}: v6_rest(inside, rest)

def named(+whole: String, parts: Maybe<&2, S.Split>) -> Maybe<&2, U.Endpoint>:
  match parts:
    case None{}: made(U.HostName{whole}, None{}, name(whole))
    case Some{S.Split{+h, +p}}: made(U.HostName{h}, Some{p}, name(h) && port(p))

def at(+c: Char, +t: String, bracket: Bool) -> Maybe<&2, U.Endpoint>:
  match bracket:
    case True{}: v6(S.split_at(t, ']'))
    case False{}: named(SCon{c, t}, S.split_at(SCon{c, t}, ':'))

def authority(s: String) -> Maybe<&2, U.Endpoint>:
  match s:
    case SNil{}: None{}
    case SCon{+c, +t}: at(c, t, Char.is_eq(c, '['))

# The endpoint read back from the Host value the proxy sends for it.
def reread(m: Maybe<&2, U.Endpoint>) -> Maybe<&2, U.Endpoint>:
  match m:
    case None{}: None{}
    case Some{e}: U.read_authority(U.host_header(e))
