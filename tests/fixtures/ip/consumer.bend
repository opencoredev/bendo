# Text-only wrappers over the pure IP and client-address core for mw-ip tests.
import Base
import ../../../src/net/ip.bend as Ip
import ../../../src/net/conn_info.bend as Conn
import ../../../src/http/bytes.bend as Bytes

def addr_text(parsed: Maybe<&2, Ip.Addr>) -> String:
  match parsed:
    case None{}: "invalid"
    case Some{+a}: Ip.address_type(a) ++ " " ++ Ip.format(a)

# "IPv4 1.2.3.4" or "IPv6 ::1", or "invalid".
def parse(s: String) -> String:
  addr_text(Ip.parse(s))

def bit_text(xs: List<&2, Bool>) -> String:
  match xs:
    case Nil{}: ""
    case True{} <> t: SCon{'1', bit_text(t)}
    case False{} <> t: SCon{'0', bit_text(t)}

# The address bits as 0/1 text, so tests can compare against their own model.
def bits_text(parsed: Maybe<&2, Ip.Addr>) -> String:
  match parsed:
    case None{}: "invalid"
    case Some{a}: bit_text(Ip.bits(a))

def bits(s: String) -> String:
  bits_text(Ip.parse(s))

def cidr_text(parsed: Maybe<&2, Ip.Cidr>) -> String:
  match parsed:
    case None{}: "invalid"
    case Some{Ip.Cidr{f, xs, n}}: Ip.family_text(f) ++ " " ++ bit_text(xs) ++ "/" ++ Nat.show(n)

# "IPv4 <32 bits>/len", or "invalid".
def cidr(s: String) -> String:
  cidr_text(Ip.parse_cidr(s))

def member_text(a: Maybe<&2, Ip.Addr>, c: Maybe<&2, Ip.Cidr>) -> String:
  match a c:
    case Some{x} Some{y}: Bool.show(Ip.member(x, y))
    case _ _: "invalid"

def member(addr: String, range: String) -> String:
  member_text(Ip.parse(addr), Ip.parse_cidr(range))

def list(csv: String) -> List<&2, String>:
  match csv:
    case SNil{}: []
    case SCon{c, t}: String.split(SCon{c, t}, ',')

def permitted_text(rules: Maybe<&2, Ip.Rules>, addr: String) -> String:
  match rules:
    case None{}: "invalid"
    case Some{r}: Bool.show(Ip.permitted_peer(r, Ip.parse(addr)))

# Comma-separated deny and allow lists; an unparseable address is unknown.
def permitted(deny: String, allow: String, addr: String) -> String:
  permitted_text(Ip.rules(list(deny), list(allow)), addr)

def field_bytes(fields: List<&2, String>) -> List<&2, List<&2, U32>>:
  match fields:
    case Nil{}: []
    case f <> t: Bytes.encode(f) <> field_bytes(t)

def client_text(+trusted: Maybe<&2, List<&2, Ip.Cidr>>, peer: String, fields: List<&2, String>) -> String:
  match trusted:
    case None{}: "invalid"
    case Some{ts}: addr_text(Conn.client(Ip.parse(peer), field_bytes(fields), ts))

# Fields are separated by '|', so one test can send several header fields.
def client(trusted: String, peer: String, fields: String) -> String:
  client_text(Ip.parse_cidrs(list(trusted)), peer, String.split(fields, '|'))
