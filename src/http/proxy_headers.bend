# Hop-by-hop header removal for the proxy (BND-47, RFC 9110 section 7.6.1).
# Pure; the laws import it. The same filter runs on the request sent upstream
# and on the upstream response sent back to the client.
import Base
import ./request.bend as Request
import ./bytes.bend as Bytes

# Fields that describe one connection, never the message.
def hop_names() -> List<&2, String>:
  ["connection", "keep-alive", "proxy-connection", "te", "trailer", "transfer-encoding", "upgrade"]

def named(+name: String, names: List<&2, String>) -> Bool:
  match names:
    case Nil{}: False{}
    case n <> rest: String.eq(name, n) || named(name, rest)

def blank(+c: U32) -> Bool:
  U32.is_eq(c, 32) || U32.is_eq(c, 9)

def lead_pick(+c: U32, t: List<&2, U32>, rest: List<&2, U32>, space: Bool) -> List<&2, U32>:
  match space:
    case True{}: rest
    case False{}: c <> t

def strip_lead(xs: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}: []
    case +c <> +t: lead_pick(c, t, strip_lead(t), blank(c))

def trail_pick(+c: U32, space: Bool, rest: List<&2, U32>) -> List<&2, U32>:
  match space rest:
    case True{} Nil{}: []
    case True{} h <> t: c <> h <> t
    case False{} rest: c <> rest

def strip_trail(xs: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}: []
    case +c <> t: trail_pick(c, blank(c), strip_trail(t))

def comma_push(c: U32, parts: List<&2, List<&2, U32>>) -> List<&2, List<&2, U32>>:
  match parts:
    case Nil{}: [[c]]
    case p <> t: (c <> p) <> t

def comma_pick(+c: U32, parts: List<&2, List<&2, U32>>, here: Bool) -> List<&2, List<&2, U32>>:
  match here:
    case True{}: [] <> parts
    case False{}: comma_push(c, parts)

def commas(xs: List<&2, U32>) -> List<&2, List<&2, U32>>:
  match xs:
    case Nil{}: [[]]
    case +c <> t: comma_pick(c, commas(t), U32.is_eq(c, 44))

def name_pick(n: String, rest: List<&2, String>, empty: Bool) -> List<&2, String>:
  match empty:
    case True{}: rest
    case False{}: n <> rest

# Each option trimmed and case-folded. Empty elements ("a,,b", " ") name no
# field and are skipped.
def token_names(parts: List<&2, List<&2, U32>>) -> List<&2, String>:
  match parts:
    case Nil{}: []
    case p <> t:
      +n = Bytes.fold(Bytes.ascii(strip_trail(strip_lead(p))))
      name_pick(n, token_names(t), String.is_empty(n))

def listed_pick(value: List<&2, U32>, rest: List<&2, String>, connection: Bool) -> List<&2, String>:
  match connection:
    case True{}: List.append(&2, String, token_names(commas(value)), rest)
    case False{}: rest

# Every option named in every Connection field, case-folded and trimmed.
def listed(hs: List<&2, Request.Header>) -> List<&2, String>:
  match hs:
    case Nil{}: []
    case Request.Header{name, value} <> t:
      listed_pick(value, listed(t), String.eq(Bytes.fold(name), "connection"))

def keep(+tokens: List<&2, String>, h: Request.Header) -> Bool:
  Request.Header{name, value} = h
  +folded = Bytes.fold(name)
  Bool.not(named(folded, hop_names())) && Bool.not(named(folded, tokens))

def keep_pick(h: Request.Header, rest: List<&2, Request.Header>, kept: Bool) -> List<&2, Request.Header>:
  match kept:
    case True{}: h <> rest
    case False{}: rest

def keep_all(+tokens: List<&2, String>, hs: List<&2, Request.Header>) -> List<&2, Request.Header>:
  match hs:
    case Nil{}: []
    case +h <> t: keep_pick(h, keep_all(tokens, t), keep(tokens, h))

# Every end-to-end field, in arrival order.
def forward(+hs: List<&2, Request.Header>) -> List<&2, Request.Header>:
  keep_all(listed(hs), hs)
