# BND-44: an independent specification of the allow/deny decision.
import Base
import ../src/net/ip.bend as Ip

def one_if(b: Bool) -> Nat:
  match b:
    case True{}: 1n
    case False{}: 0n

# How many ranges in cs contain a.
def hits(+a: Ip.Addr, cs: List<&2, Ip.Cidr>) -> Nat:
  match cs:
    case Nil{}: 0n
    case c <> t: Nat.add(one_if(Ip.member(a, c)), hits(a, t))

def exists(+a: Ip.Addr, cs: List<&2, Ip.Cidr>) -> Bool:
  Nat.is_lt(0n, hits(a, cs))

# Admitted: no deny range contains the address, and the allow list is empty
# or one of its ranges contains it.
def permitted(rules: Ip.Rules, +a: Ip.Addr) -> Bool:
  Ip.Rules{deny, +allow} = rules
  Bool.not(exists(a, deny)) && (List.is_empty(&2, Ip.Cidr, allow) || exists(a, allow))
