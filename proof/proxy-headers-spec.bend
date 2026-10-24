# BND-47: what the proxy may forward, stated without Bendo code.
#
# RFC 9110 section 7.6.1: a proxy removes Connection, the fields every
# connection-specific option names (Proxy-Connection, Keep-Alive, TE,
# Trailer, Transfer-Encoding, Upgrade), and every field named by an option in
# any Connection field. Field names compare case-insensitively. A Connection
# field holds comma-separated options with optional spaces and tabs around
# each one; every Connection field of the message counts, whatever the case
# of its name.
#
# This module imports only Base and the Request.Header record type (name,
# value octets); it calls no Bendo function.
import Base
import ../src/http/request.bend as Request

def lower(s: String) -> String:
  String.to_lower(s)

def hop_by_hop() -> List<&2, String>:
  ["connection", "keep-alive", "proxy-connection", "te", "trailer", "transfer-encoding", "upgrade"]

def member(+s: String, xs: List<&2, String>) -> Bool:
  match xs:
    case Nil{}: False{}
    case x <> rest: String.eq(s, x) || member(s, rest)

def space(+c: U32) -> Bool:
  U32.is_eq(c, 32) || U32.is_eq(c, 9)

def after_space(+c: U32, t: List<&2, U32>, dropped: List<&2, U32>, sp: Bool) -> List<&2, U32>:
  match sp:
    case True{}: dropped
    case False{}: c <> t

# Leading spaces and tabs removed.
def drop_leading(xs: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}: []
    case +c <> +t: after_space(c, t, drop_leading(t), space(c))

# Whether every octet is a space or a tab.
def blank(xs: List<&2, U32>) -> Bool:
  match xs:
    case Nil{}: True{}
    case +c <> t: space(c) && blank(t)

def cut_if(+c: U32, cut: Bool, rest: List<&2, U32>) -> List<&2, U32>:
  match cut:
    case True{}: []
    case False{}: c <> rest

# Trailing spaces and tabs removed: the list ends at the first blank octet
# followed only by blanks.
def drop_trailing(xs: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}: []
    case +c <> +t: cut_if(c, space(c) && blank(t), drop_trailing(t))

def onto_first(c: U32, parts: List<&2, List<&2, U32>>) -> List<&2, List<&2, U32>>:
  match parts:
    case Nil{}: [[c]]
    case p <> t: (c <> p) <> t

def at_comma(+c: U32, parts: List<&2, List<&2, U32>>, comma: Bool) -> List<&2, List<&2, U32>>:
  match comma:
    case True{}: [] <> parts
    case False{}: onto_first(c, parts)

# The value cut at every ',' (44), empty pieces included.
def pieces(xs: List<&2, U32>) -> List<&2, List<&2, U32>>:
  match xs:
    case Nil{}: [[]]
    case +c <> t: at_comma(c, pieces(t), U32.is_eq(c, 44))

def text(xs: List<&2, U32>) -> String:
  match xs:
    case Nil{}: ""
    case c <> t: SCon{Chr{c}, text(t)}

def option_if(o: String, rest: List<&2, String>, empty: Bool) -> List<&2, String>:
  match empty:
    case True{}: rest
    case False{}: o <> rest

# The nonempty options, trimmed and lowercased. An empty list element names
# no field (RFC 9110 5.6.1 lets recipients ignore empty elements).
def options(parts: List<&2, List<&2, U32>>) -> List<&2, String>:
  match parts:
    case Nil{}: []
    case p <> t:
      +o = lower(text(drop_trailing(drop_leading(p))))
      option_if(o, options(t), String.is_empty(o))

def field_options(value: List<&2, U32>, rest: List<&2, String>, connection: Bool) -> List<&2, String>:
  match connection:
    case True{}: List.append(&2, String, options(pieces(value)), rest)
    case False{}: rest

# The options of every Connection field, in order.
def listed(hs: List<&2, Request.Header>) -> List<&2, String>:
  match hs:
    case Nil{}: []
    case Request.Header{name, value} <> t:
      field_options(value, listed(t), String.eq(lower(name), "connection"))

# A field may cross the proxy unless its name is hop-by-hop or listed.
def clean(+listed: List<&2, String>, h: Request.Header) -> Bool:
  Request.Header{name, value} = h
  +n = lower(name)
  Bool.not(member(n, hop_by_hop())) && Bool.not(member(n, listed))

def keep_if(h: Request.Header, rest: List<&2, Request.Header>, ok: Bool) -> List<&2, Request.Header>:
  match ok:
    case True{}: h <> rest
    case False{}: rest

def keep_clean(+listed: List<&2, String>, hs: List<&2, Request.Header>) -> List<&2, Request.Header>:
  match hs:
    case Nil{}: []
    case +h <> t: keep_if(h, keep_clean(listed, t), clean(listed, h))

# Exactly the clean fields of hs, in their original order and unchanged.
def forward(+hs: List<&2, Request.Header>) -> List<&2, Request.Header>:
  keep_clean(listed(hs), hs)

def all_clean(+listed: List<&2, String>, hs: List<&2, Request.Header>) -> Bool:
  match hs:
    case Nil{}: True{}
    case +h <> t: clean(listed, h) && all_clean(listed, t)
