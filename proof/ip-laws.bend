# BND-44: CIDR membership against address bits, deny-over-allow precedence,
# and the trusted-proxy rule for the client address.
import Base
import ../src/net/ip.bend as Ip
import ../src/net/conn_info.bend as Conn
import ./ip-spec.bend as Spec

# Membership means the first len bits agree: every bit index below the
# prefix length reads the same (present) bit in the address and the network.
law ip_member_bits:
  for +a: Ip.Addr
  for +c: Ip.Cidr
  for hit: {Ip.member(a, c) == True{} : Bool}
  for +i: Nat
  for below: {Nat.is_lt(i, Ip.cidr_len(c)) == True{} : Bool}
  {List.get(&2, Bool, Ip.bits(a), i) == List.get(&2, Bool, Ip.cidr_bits(c), i) : Maybe<&2, Bool>}

# A member has the network's family; both are full width; the prefix fits.
law ip_member_family:
  for +a: Ip.Addr
  for +c: Ip.Cidr
  for hit: {Ip.member(a, c) == True{} : Bool}
  {Ip.same_family(Ip.family(a), Ip.cidr_family(c)) == True{} : Bool}

law ip_member_width:
  for +a: Ip.Addr
  for +c: Ip.Cidr
  for hit: {Ip.member(a, c) == True{} : Bool}
  {Nat.is_eq(List.length(&2, Bool, Ip.bits(a)), Ip.width(Ip.family(a))) && Nat.is_eq(List.length(&2, Bool, Ip.cidr_bits(c)), Ip.width(Ip.cidr_family(c))) && Nat.is_le(Ip.cidr_len(c), Ip.width(Ip.cidr_family(c))) == True{} : Bool}

# Conversely, a full-width address of the network's family whose first len
# bits agree with the network's is a member.
law ip_member_complete:
  for +a: Ip.Addr
  for +c: Ip.Cidr
  for family: {Ip.same_family(Ip.family(a), Ip.cidr_family(c)) == True{} : Bool}
  for wa: {List.length(&2, Bool, Ip.bits(a)) == Ip.width(Ip.family(a)) : Nat}
  for wc: {List.length(&2, Bool, Ip.cidr_bits(c)) == Ip.width(Ip.cidr_family(c)) : Nat}
  for fits: {Nat.is_le(Ip.cidr_len(c), Ip.width(Ip.cidr_family(c))) == True{} : Bool}
  for agree: @i:Nat -> {Nat.is_lt(i, Ip.cidr_len(c)) == True{} : Bool} -> {List.get(&2, Bool, Ip.bits(a), i) == List.get(&2, Bool, Ip.cidr_bits(c), i) : Maybe<&2, Bool>}
  {Ip.member(a, c) == True{} : Bool}

# The decision equals the specification: no deny range contains the address,
# and the allow list is empty or contains it.
law ip_permitted_spec:
  for +rules: Ip.Rules
  for +a: Ip.Addr
  {Ip.permitted(rules, a) == Spec.permitted(rules, a) : Bool}

# Deny wins: an address inside any deny range is refused, whatever allows it.
law ip_deny_wins:
  for +deny: List<&2, Ip.Cidr>
  for +allow: List<&2, Ip.Cidr>
  for +a: Ip.Addr
  for +i: Nat
  for +c: Ip.Cidr
  for at: {List.get(&2, Ip.Cidr, deny, i) == Some{c} : Maybe<&2, Ip.Cidr>}
  for hit: {Ip.member(a, c) == True{} : Bool}
  {Ip.permitted(Ip.Rules{deny, allow}, a) == False{} : Bool}

# An address outside every deny range and inside some allow range is admitted.
law ip_allow_listed:
  for +deny: List<&2, Ip.Cidr>
  for +allow: List<&2, Ip.Cidr>
  for +a: Ip.Addr
  for +i: Nat
  for +c: Ip.Cidr
  for clear: {Spec.exists(a, deny) == False{} : Bool}
  for at: {List.get(&2, Ip.Cidr, allow, i) == Some{c} : Maybe<&2, Ip.Cidr>}
  for hit: {Ip.member(a, c) == True{} : Bool}
  {Ip.permitted(Ip.Rules{deny, allow}, a) == True{} : Bool}

# Without a known address, any configured range refuses the request.
law ip_unknown_denied:
  for +d: Ip.Cidr
  for +deny: List<&2, Ip.Cidr>
  for +allow: List<&2, Ip.Cidr>
  {Ip.permitted_peer(Ip.Rules{d <> deny, allow}, None{}) == False{} : Bool}

law ip_unknown_not_allowed:
  for +deny: List<&2, Ip.Cidr>
  for +c: Ip.Cidr
  for +allow: List<&2, Ip.Cidr>
  {Ip.permitted_peer(Ip.Rules{deny, c <> allow}, None{}) == False{} : Bool}

# Client headers are never trusted by default: with no trusted proxies the
# client address is the socket peer, whatever X-Forwarded-For says.
law client_default_peer:
  for +peer: Maybe<&2, Ip.Addr>
  for +fields: List<&2, List<&2, U32>>
  {Conn.client(peer, fields, []) == peer : Maybe<&2, Ip.Addr>}

# A peer outside the trusted proxies is the client, whatever it forwards.
law client_untrusted_peer:
  for +peer: Ip.Addr
  for +fields: List<&2, List<&2, U32>>
  for +trusted: List<&2, Ip.Cidr>
  for outside: {Ip.any(peer, trusted) == False{} : Bool}
  {Conn.client(Some{peer}, fields, trusted) == Some{peer} : Maybe<&2, Ip.Addr>}
