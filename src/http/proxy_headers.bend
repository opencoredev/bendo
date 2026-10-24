# Hop-by-hop header removal for the proxy (BND-47, RFC 9110 section 7.6.1).
# Pure; the laws import it. The same filter runs on the request sent upstream
# and on the upstream response sent back to the client.
import Base
import ./request.bend as Request
import ./bytes.bend as Bytes
import ./text.bend as Text

# Fields that describe one connection, never the message.
def hop_names() -> List<&2, String>:
  ["connection", "keep-alive", "proxy-connection", "te", "trailer", "transfer-encoding", "upgrade"]

def named_spec(+name: String, names: List<&2, String>) -> Bool:
  match names:
    case Nil{}: False{}
    case n <> rest: String.eq(name, n) || named_spec(name, rest)

def named_go(xs: List<&2, String>, +name: String, acc: Bool) -> Bool:
  match xs:
    case Nil{}: acc
    case n <> t: named_go(t, name, String.eq(name, n) || acc)

def named(+name: String, xs: List<&2, String>) -> Bool:
  named_go(List.reverse(&2, String, xs), name, False{})

def blank(+c: U32) -> Bool:
  U32.is_eq(c, 32) || U32.is_eq(c, 9)

def lead_pick(+c: U32, t: List<&2, U32>, rest: List<&2, U32>, space: Bool) -> List<&2, U32>:
  match space:
    case True{}: rest
    case False{}: c <> t

def strip_lead_spec(xs: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}: []
    case +c <> +t: lead_pick(c, t, strip_lead_spec(t), blank(c))

# Retain the suffix alongside its trimmed answer, avoiding recursive unwinding.
type Lead is Data:
  Lead{rest: List<&2, U32>, kept: List<&2, U32>}

def lead_fold(+c: U32, acc: Lead) -> Lead:
  match acc:
    case Lead{+t, kept}: Lead{c <> t, lead_pick(c, t, kept, blank(c))}

def lead_kept(acc: Lead) -> List<&2, U32>:
  match acc:
    case Lead{t, kept}: kept

def strip_lead_go(xs: List<&2, U32>, acc: Lead) -> List<&2, U32>:
  match xs:
    case Nil{}: lead_kept(acc)
    case +c <> t: strip_lead_go(t, lead_fold(c, acc))

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
    case +c <> t: trail_pick(c, blank(c), strip_trail_spec(t))

def strip_trail_go(xs: List<&2, U32>, acc: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}: acc
    case +c <> t: strip_trail_go(t, trail_pick(c, blank(c), acc))

def strip_trail(xs: List<&2, U32>) -> List<&2, U32>:
  strip_trail_go(List.reverse(&2, U32, xs), [])

def comma_push(c: U32, parts: List<&2, List<&2, U32>>) -> List<&2, List<&2, U32>>:
  match parts:
    case Nil{}: [[c]]
    case p <> t: (c <> p) <> t

def comma_pick(+c: U32, parts: List<&2, List<&2, U32>>, here: Bool) -> List<&2, List<&2, U32>>:
  match here:
    case True{}: [] <> parts
    case False{}: comma_push(c, parts)

def commas_spec(xs: List<&2, U32>) -> List<&2, List<&2, U32>>:
  match xs:
    case Nil{}: [[]]
    case +c <> t: comma_pick(c, commas_spec(t), U32.is_eq(c, 44))

def commas_go(xs: List<&2, U32>, acc: List<&2, List<&2, U32>>) -> List<&2, List<&2, U32>>:
  match xs:
    case Nil{}: acc
    case +c <> t: commas_go(t, comma_pick(c, acc, U32.is_eq(c, 44)))

def commas(xs: List<&2, U32>) -> List<&2, List<&2, U32>>:
  commas_go(List.reverse(&2, U32, xs), [[]])

def name_pick(n: String, rest: List<&2, String>, empty: Bool) -> List<&2, String>:
  match empty:
    case True{}: rest
    case False{}: n <> rest

# Each option trimmed and case-folded. Empty elements ("a,,b", " ") name no
# field and are skipped.
def token_names_spec(parts: List<&2, List<&2, U32>>) -> List<&2, String>:
  match parts:
    case Nil{}: []
    case p <> t:
      +n = Bytes.fold(Bytes.ascii(strip_trail(strip_lead(p))))
      name_pick(n, token_names_spec(t), String.is_empty(n))

def token_names_go(xs: List<&2, List<&2, U32>>, acc: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}: acc
    case +p <> t: token_names_go(t, name_pick(Bytes.fold(Bytes.ascii(strip_trail(strip_lead(p)))), acc, String.is_empty(Bytes.fold(Bytes.ascii(strip_trail(strip_lead(p)))))))

def token_names(xs: List<&2, List<&2, U32>>) -> List<&2, String>:
  token_names_go(List.reverse(&2, List<&2, U32>, xs), [])

def listed_pick_spec(value: List<&2, U32>, rest: List<&2, String>, connection: Bool) -> List<&2, String>:
  match connection:
    case True{}: List.append(&2, String, token_names(commas(value)), rest)
    case False{}: rest

# Every option named in every Connection field, case-folded and trimmed.

def listed_pick(value: List<&2, U32>, rest: List<&2, String>, connection: Bool) -> List<&2, String>:
  match connection:
    case True{}: Text.list_append(String, token_names(commas(value)), rest)
    case False{}: rest

# Every option named in every Connection field, case-folded and trimmed.
def listed_spec(hs: List<&2, Request.Header>) -> List<&2, String>:
  match hs:
    case Nil{}: []
    case Request.Header{name, value} <> t:
      listed_pick(value, listed_spec(t), String.eq(Bytes.fold(name), "connection"))

def listed_go(xs: List<&2, Request.Header>, acc: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}: acc
    case Request.Header{+name, value} <> t: listed_go(t, listed_pick(value, acc, String.eq(Bytes.fold(name), "connection")))

def listed(xs: List<&2, Request.Header>) -> List<&2, String>:
  listed_go(List.reverse(&2, Request.Header, xs), [])

def keep(+tokens: List<&2, String>, h: Request.Header) -> Bool:
  Request.Header{name, value} = h
  +folded = Bytes.fold(name)
  Bool.not(named(folded, hop_names())) && Bool.not(named(folded, tokens))

def keep_pick(h: Request.Header, rest: List<&2, Request.Header>, kept: Bool) -> List<&2, Request.Header>:
  match kept:
    case True{}: h <> rest
    case False{}: rest

def keep_all_spec(+tokens: List<&2, String>, hs: List<&2, Request.Header>) -> List<&2, Request.Header>:
  match hs:
    case Nil{}: []
    case +h <> t: keep_pick(h, keep_all_spec(tokens, t), keep(tokens, h))

# Every end-to-end field, in arrival order.

def keep_all_go(xs: List<&2, Request.Header>, +tokens: List<&2, String>, acc: List<&2, Request.Header>) -> List<&2, Request.Header>:
  match xs:
    case Nil{}: acc
    case +h <> t: keep_all_go(t, tokens, keep_pick(h, acc, keep(tokens, h)))

def keep_all(+tokens: List<&2, String>, xs: List<&2, Request.Header>) -> List<&2, Request.Header>:
  keep_all_go(List.reverse(&2, Request.Header, xs), tokens, [])

def forward(+hs: List<&2, Request.Header>) -> List<&2, Request.Header>:
  keep_all(listed(hs), hs)
