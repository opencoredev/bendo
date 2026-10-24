# BND-93: the host and port of a proxy upstream URL, stated without
# src/http/upstream.bend's parser or src/http/origin.bend. It builds on the
# origin specification (proof/origin-spec.bend) and imports only the
# Upstream.Endpoint record. The parser cuts the authority at its first ']' or
# ':' and tests each part with its own predicates; this module splits the
# whole authority into pieces and states each part's grammar separately, so
# the law equating the two compares different formulations.
#
# A lowercase authority is accepted exactly when it is one of:
# - "[" v6 "]", optionally followed by ":" port, with exactly one ']' in
#   the authority;
# - name, optionally followed by ":" port, with at most one ':' in the
#   authority.
# v6 is IPv6 text in RFC 5952 form (OriginSpec.ipv6) whose eight groups do
# not embed an IPv4 address (embeds_v4). name is an origin host outside
# brackets (OriginSpec.name_host: a dotted-quad IPv4 address, or a DNS name of
# a-z, 0-9, '-', '.' and '_' of at most 253 characters that does not end in a
# number) whose every dot-separated label is a label (RFC 1123 section 2.1).
# port is one to five decimal digits whose value is 1 to 65535; leading zeros
# are allowed. The endpoint keeps the host and the port digits as written.
import Base
import ./origin-spec.bend as S
import ../src/http/upstream.bend as U

# ---- Names ----

def not_hyphen(c: Char) -> Bool:
  Bool.not(Char.is_eq(c, '-'))

# The last character of SCon{c, t}.
def last_of(t: String, c: Char) -> Char:
  match t:
    case SNil{}: c
    case SCon{d, u}: last_of(u, d)

# 1 to 63 characters, the first and the last not '-'.
def label(l: String) -> Bool:
  match l:
    case SNil{}: False{}
    case SCon{+c, +t}: Nat.is_le(String.length(t), 62n) && not_hyphen(c) && not_hyphen(last_of(t, c))

def every_label(ls: List<&2, String>) -> Bool:
  match ls:
    case Nil{}: True{}
    case l <> t: label(l) && every_label(t)

def name(+h: String) -> Bool:
  S.name_host(h) && every_label(String.split(h, '.'))

# ---- Ports ----

def in_range(n: Maybe<&2, Nat>) -> Bool:
  match n:
    case None{}: False{}
    case Some{+v}: Nat.is_le(1n, v) && Nat.is_le(v, 65535n)

def port(+p: String) -> Bool:
  S.decimals(p) && Bool.not(String.is_empty(p)) && Nat.is_le(String.length(p), 5n) && in_range(Nat.read(p))

# ---- IPv6 ----

def first_empty(gs: List<&2, String>) -> Bool:
  match gs:
    case Nil{}: False{}
    case g <> t: String.is_empty(g)

def first_is(gs: List<&2, String>, +text: String) -> Bool:
  match gs:
    case Nil{}: False{}
    case g <> t: String.eq(g, text)

# The groups after a leading "::" of RFC 5952 text. With five or more zero
# groups first, the "::" stands for them, so the eight groups are
# 0:0:0:0:0:ffff:x:y (IPv4-mapped, ::ffff:0:0/96) exactly when these are
# "ffff" and two more, and 0:0:0:0:0:0:x:y (IPv4-compatible, ::/96) exactly
# when there are one or two; one group "1" is ::1 and none is ::, which embed
# nothing.
def mapped_or_compatible(+gs: List<&2, String>) -> Bool:
  +n = List.length(&2, String, gs)
  Nat.is_eq(n, 2n) || (Nat.is_eq(n, 3n) && first_is(gs, "ffff")) || (Nat.is_eq(n, 1n) && Bool.not(first_empty(gs)) && Bool.not(first_is(gs, "1")))

def embedding(m: Maybe<&2, S.Split>) -> Bool:
  match m:
    case None{}: False{}
    case Some{S.Split{a, b}}: String.is_empty(a) && mapped_or_compatible(S.group_list(b))

# Text that starts with "::" and embeds an IPv4 address. An address without
# "::" has fewer than two zero groups in a row, so it embeds none.
def embeds_v4(+t: String) -> Bool:
  embedding(S.split_double(t))

def v6(+t: String) -> Bool:
  S.ipv6(t) && Bool.not(embeds_v4(t))

# ---- Authorities ----

def made(+host: U.Host, +p: Maybe<&2, String>, ok: Bool) -> Maybe<&2, U.Endpoint>:
  match ok:
    case True{}: Some{U.Endpoint{host, p}}
    case False{}: None{}

def v6_port(+inside: String, +p: String, colon: Bool) -> Maybe<&2, U.Endpoint>:
  match colon:
    case True{}: made(U.HostV6{inside}, Some{p}, v6(inside) && port(p))
    case False{}: None{}

# What follows the ']': nothing, or ':' and the port.
def v6_rest(+inside: String, rest: String) -> Maybe<&2, U.Endpoint>:
  match rest:
    case SNil{}: made(U.HostV6{inside}, None{}, v6(inside))
    case SCon{c, p}: v6_port(inside, p, Char.is_eq(c, ':'))

def bracket_end(+inside: String, +rest: String, more: List<&2, String>) -> Maybe<&2, U.Endpoint>:
  match more:
    case Nil{}: v6_rest(inside, rest)
    case _: None{}

def bracket_tail(+inside: String, more: List<&2, String>) -> Maybe<&2, U.Endpoint>:
  match more:
    case Nil{}: None{}
    case rest <> t: bracket_end(inside, rest, t)

# The pieces of the authority after its '[', split at every ']'.
def bracketed(pieces: List<&2, String>) -> Maybe<&2, U.Endpoint>:
  match pieces:
    case Nil{}: None{}
    case inside <> more: bracket_tail(inside, more)

def named_end(+h: String, +p: String, more: List<&2, String>) -> Maybe<&2, U.Endpoint>:
  match more:
    case Nil{}: made(U.HostName{h}, Some{p}, name(h) && port(p))
    case _: None{}

def named_tail(+h: String, more: List<&2, String>) -> Maybe<&2, U.Endpoint>:
  match more:
    case Nil{}: made(U.HostName{h}, None{}, name(h))
    case p <> t: named_end(h, p, t)

# The pieces of the authority split at every ':'.
def named(pieces: List<&2, String>) -> Maybe<&2, U.Endpoint>:
  match pieces:
    case Nil{}: None{}
    case h <> more: named_tail(h, more)

def at(+c: Char, +t: String, bracket: Bool) -> Maybe<&2, U.Endpoint>:
  match bracket:
    case True{}: bracketed(String.split(t, ']'))
    case False{}: named(String.split(SCon{c, t}, ':'))

def authority(s: String) -> Maybe<&2, U.Endpoint>:
  match s:
    case SNil{}: None{}
    case SCon{+c, +t}: at(c, t, Char.is_eq(c, '['))

# The endpoint read back from the Host value the proxy sends for it.
def reread(m: Maybe<&2, U.Endpoint>) -> Maybe<&2, U.Endpoint>:
  match m:
    case None{}: None{}
    case Some{e}: U.read_authority(U.host_header(e))
