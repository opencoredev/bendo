# Connection info and the client address. Pure; the laws import it.
# The socket peer is the only address Bendo knows first hand. X-Forwarded-For
# is read only when the peer itself is a configured trusted proxy.
import Base
import ./ip.bend as Ip
import ../http/bytes.bend as Bytes
import ../http/text.bend as Text

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

def strip_lead_spec(xs: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}: []
    case +c <> +t: lead_pick(c, t, strip_lead_spec(t), Bytes.ows(c))

# Every loop here is a tail call over the reversed input (BND-84): the
# accumulator holds the suffix read so far and the spec's answer for it.
type Lead is Data:
  Lead{rest: List<&2, U32>, kept: List<&2, U32>}

def lead_fold(+c: U32, acc: Lead) -> Lead:
  match acc:
    case Lead{+t, kept}: Lead{c <> t, lead_pick(c, t, kept, Bytes.ows(c))}

def lead_kept(acc: Lead) -> List<&2, U32>:
  match acc:
    case Lead{t, kept}: kept

def strip_lead_go(rev: List<&2, U32>, acc: Lead) -> List<&2, U32>:
  match rev:
    case Nil{}: lead_kept(acc)
    case +c <> r: strip_lead_go(r, lead_fold(c, acc))

# Drop leading spaces and tabs.
def strip_lead(xs: List<&2, U32>) -> List<&2, U32>:
  strip_lead_go(List.reverse(&2, U32, xs), Lead{[], []})

def trail_pick(+c: U32, space: Bool, rest: List<&2, U32>) -> List<&2, U32>:
  match space rest:
    case True{} Nil{}: []
    case True{} h <> t: c <> h <> t
    case False{} rest: c <> rest

def strip_trail_spec(xs: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}: []
    case +c <> t: trail_pick(c, Bytes.ows(c), strip_trail_spec(t))

def strip_trail_go(rev: List<&2, U32>, acc: List<&2, U32>) -> List<&2, U32>:
  match rev:
    case Nil{}: acc
    case +c <> r: strip_trail_go(r, trail_pick(c, Bytes.ows(c), acc))

# Drop trailing spaces and tabs: a blank character survives only if something
# after it does.
def strip_trail(xs: List<&2, U32>) -> List<&2, U32>:
  strip_trail_go(List.reverse(&2, U32, xs), [])

def trim(xs: List<&2, U32>) -> List<&2, U32>:
  strip_trail(strip_lead(xs))

def entry_texts_spec(parts: List<&2, List<&2, U32>>) -> List<&2, String>:
  match parts:
    case Nil{}: []
    case p <> t: Bytes.ascii(trim(p)) <> entry_texts_spec(t)

def entry_texts_go(rev: List<&2, List<&2, U32>>, acc: List<&2, String>) -> List<&2, String>:
  match rev:
    case Nil{}: acc
    case p <> r: entry_texts_go(r, Bytes.ascii(trim(p)) <> acc)

def entry_texts(parts: List<&2, List<&2, U32>>) -> List<&2, String>:
  entry_texts_go(List.reverse(&2, List<&2, U32>, parts), [])

# Every comma-separated entry of every X-Forwarded-For field, in order, with
# surrounding spaces and tabs removed. Empty entries stay (and are malformed),
# so "a,,b" has three entries and an empty field has one.
def entries_spec(fields: List<&2, List<&2, U32>>) -> List<&2, String>:
  match fields:
    case Nil{}: []
    case f <> t: List.append(&2, String, entry_texts(Ip.split(f, 44)), entries_spec(t))

def entries_go(rev: List<&2, List<&2, U32>>, acc: List<&2, String>) -> List<&2, String>:
  match rev:
    case Nil{}: acc
    case f <> r: entries_go(r, Text.list_append(String, entry_texts(Ip.split(f, 44)), acc))

def entries(fields: List<&2, List<&2, U32>>) -> List<&2, String>:
  entries_go(List.reverse(&2, List<&2, U32>, fields), [])

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

# walk(hops(xs, trusted), current) as one tail loop over the entries.
type Walk is Data:
  Going{current: Ip.Addr}
  Stopped{address: Ip.Addr}

def walk_step(st: Walk, h: Hop) -> Walk:
  match st h:
    case Going{c} Bad{}: Stopped{c}
    case Going{c} Client{a}: Stopped{a}
    case Going{c} Proxy{a}: Going{a}
    case Stopped{a} _: Stopped{a}

def walk_done(st: Walk) -> Ip.Addr:
  match st:
    case Going{c}: c
    case Stopped{a}: a

def walk_entries(xs: List<&2, String>, +trusted: List<&2, Ip.Cidr>, st: Walk) -> Ip.Addr:
  match xs:
    case Nil{}: walk_done(st)
    case x <> t: walk_entries(t, trusted, walk_step(st, hop(Ip.parse(x), trusted)))

def forwarded(+peer: Ip.Addr, fields: List<&2, List<&2, U32>>, +trusted: List<&2, Ip.Cidr>, proxy: Bool) -> Ip.Addr:
  match proxy:
    case False{}: peer
    case True{}: walk_entries(List.reverse(&2, String, entries(fields)), trusted, Going{peer})

# The client address. With no trusted proxies (the default), or a peer outside
# them, this is the socket peer and the forwarded fields are never read.
def client(peer: Maybe<&2, Ip.Addr>, fields: List<&2, List<&2, U32>>, +trusted: List<&2, Ip.Cidr>) -> Maybe<&2, Ip.Addr>:
  match peer:
    case None{}: None{}
    case Some{+p}: Some{forwarded(p, fields, trusted, Ip.any(p, trusted))}
