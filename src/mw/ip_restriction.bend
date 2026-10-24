# IP allow and deny lists with CIDR ranges, like Hono's ipRestriction.
# Deny wins over allow; an unknown client address is refused unless both
# lists are empty. X-Forwarded-For counts only behind a trusted proxy.
import Base
import ../app/context.bend as C
import ../app/errors.bend as Errors
import ../http/response.bend as Response
import ../net/ip.bend as Ip
import ../net/conn_info.bend as Conn

type Policy is Data:
  Policy{rules: Ip.Rules, trusted: List<&2, Ip.Cidr>}

# Every entry must parse ("10.0.0.0/8", "2001:db8::/32", "127.0.0.1").
def policy(deny: List<&2, String>, allow: List<&2, String>, trusted: List<&2, String>) -> Maybe<&2, Policy>:
  do Maybe<&2, Policy>:
    rules : Ip.Rules <- Ip.rules(deny, allow)
    proxies : List<&2, Ip.Cidr> <- Ip.parse_cidrs(trusted)
    return Policy{rules, proxies}

# The client address for a request: the socket peer, or a forwarded address
# when the peer is one of the trusted proxies.
def client(-Vars: Data, +c: C.Ctx<Vars>, +trusted: List<&2, Ip.Cidr>) -> Maybe<&2, Ip.Addr>:
  Conn.client(Conn.peer_address(C.conn_info(Vars, c)), C.header_bytes(Vars, c, "x-forwarded-for"), trusted)

def checked(-Vars: Data, +c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res), ok: Bool) -> IO(Response.Res):
  match ok:
    case True{}: next(c)
    case False{}: IO.pure(Response.Res, C.error(Vars, c, Errors.http_error(403, "Forbidden")))

def middleware(-Vars: Data, policy: Policy, +c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res):
  Policy{rules, +trusted} = policy
  checked(Vars, c, next, Ip.permitted_peer(rules, client(Vars, c, trusted)))
