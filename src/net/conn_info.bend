# Connection info and the client address. Pure; the laws import it.
# The socket peer is the only address Bendo knows first hand. X-Forwarded-For
# is read only when the peer itself is a configured trusted proxy.
import Base
import ./ip.bend as Ip
import ../http/bytes.bend as Bytes

# The socket peer from getpeername, its address canonical (IPv4-mapped IPv6
# shown as IPv4), and the peer's port.
type ConnInfo is Data:
  ConnInfo{address: Ip.Addr, text: String, port: U32}

def made(port: U32, parsed: Maybe<&2, Ip.Addr>) -> Maybe<&2, ConnInfo>:
  match parsed:
    case None{}: None{}
    case Some{+a}: Some{ConnInfo{a, Ip.format(a), port}}

def from_peer(host: String, port: U32) -> Maybe<&2, ConnInfo>:
  made(port, Ip.parse(host))

def address(info: ConnInfo) -> Ip.Addr:
  ConnInfo{a, t, p} = info
  a

def text(info: ConnInfo) -> String:
  ConnInfo{a, t, p} = info
  t

def port(info: ConnInfo) -> U32:
  ConnInfo{a, t, p} = info
  p

def peer_address(info: Maybe<&2, ConnInfo>) -> Maybe<&2, Ip.Addr>:
  match info:
    case None{}: None{}
    case Some{i}: Some{address(i)}

# Entry trimming tests characters through Bytes.ows, so the entries law can
# reason about any character without splitting on its bits.
def lead_pick(+c: U32, t: List<&2, U32>, rest: List<&2, U32>, space: Bool) -> List<&2, U32>:
  match space:
    case True{}: rest
    case False{}: c <> t

# Drop leading spaces and tabs.
def strip_lead(xs: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}: []
    case +c <> +t: lead_pick(c, t, strip_lead(t), Bytes.ows(c))

def trail_pick(+c: U32, space: Bool, rest: List<&2, U32>) -> List<&2, U32>:
  match space rest:
    case True{} Nil{}: []
    case True{} h <> t: c <> h <> t
    case False{} rest: c <> rest

# Drop trailing spaces and tabs: a blank character survives only if something
# after it does.
def strip_trail(xs: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}: []
    case +c <> t: trail_pick(c, Bytes.ows(c), strip_trail(t))

def trim(xs: List<&2, U32>) -> List<&2, U32>:
  strip_trail(strip_lead(xs))

def entry_texts(parts: List<&2, List<&2, U32>>) -> List<&2, String>:
  match parts:
    case Nil{}: []
    case p <> t: Bytes.ascii(trim(p)) <> entry_texts(t)

# Every comma-separated entry of every X-Forwarded-For field, in order, with
# surrounding spaces and tabs removed. Empty entries stay (and are malformed),
# so "a,,b" has three entries and an empty field has one.
def entries(fields: List<&2, List<&2, U32>>) -> List<&2, String>:
  match fields:
    case Nil{}: []
    case f <> t: List.append(&2, String, entry_texts(Ip.split(f, 44)), entries(t))

type Hop is Data:
  Bad{}
  Proxy{address: Ip.Addr}
  Client{address: Ip.Addr}

def hop_kind(+a: Ip.Addr, proxy: Bool) -> Hop:
  match proxy:
    case True{}: Proxy{a}
    case False{}: Client{a}

def hop(parsed: Maybe<&2, Ip.Addr>, +trusted: List<&2, Ip.Cidr>) -> Hop:
  match parsed:
    case None{}: Bad{}
    case Some{+a}: hop_kind(a, Ip.any(a, trusted))

def hops(xs: List<&2, String>, +trusted: List<&2, Ip.Cidr>) -> List<&2, Hop>:
  match xs:
    case Nil{}: []
    case x <> t: hop(Ip.parse(x), trusted) <> hops(t, trusted)

# Nearest hop first: skip trusted proxies; the first other address is the
# client. A malformed entry, or running out of entries, stops at the last
# trusted hop.
def walk(xs: List<&2, Hop>, current: Ip.Addr) -> Ip.Addr:
  match xs:
    case Nil{}: current
    case Bad{} <> t: current
    case Client{a} <> t: a
    case Proxy{a} <> t: walk(t, a)

def forwarded(+peer: Ip.Addr, fields: List<&2, List<&2, U32>>, +trusted: List<&2, Ip.Cidr>, proxy: Bool) -> Ip.Addr:
  match proxy:
    case False{}: peer
    case True{}: walk(hops(List.reverse(&2, String, entries(fields)), trusted), peer)

# The client address. With no trusted proxies (the default), or a peer outside
# them, this is the socket peer and the forwarded fields are never read.
def client(peer: Maybe<&2, Ip.Addr>, fields: List<&2, List<&2, U32>>, +trusted: List<&2, Ip.Cidr>) -> Maybe<&2, Ip.Addr>:
  match peer:
    case None{}: None{}
    case Some{+p}: Some{forwarded(p, fields, trusted, Ip.any(p, trusted))}
