# BND-105: subscribe admission under the hub's limits (T.admit_within): at
# most per_peer subscriptions per connection, per_hub in all, and topic names
# of at most topic_bytes UTF-8 bytes. The ws_topics laws about T.admit are
# unchanged; ws_limits_admitted_is_admit carries them over.
import Base
import ../src/ws/topics.bend as T

# A refused subscribe, whatever the reason, leaves the registry unchanged.
law ws_limits_refusal_unchanged:
  for -A: Data
  for +l: T.Limits
  for +r: T.Registry<A>
  for +c: Nat
  for +t: String
  for +x: A
  for refused: {T.admitted(T.decide(A, l, r, c, t)) == False{} : Bool}
  {T.admit_within(A, l, r, c, t, x) == r : T.Registry<A>}

# An admitted subscribe is exactly admit.
law ws_limits_admitted_is_admit:
  for -A: Data
  for +l: T.Limits
  for +r: T.Registry<A>
  for +c: Nat
  for +t: String
  for +x: A
  for ok: {T.admitted(T.decide(A, l, r, c, t)) == True{} : Bool}
  {T.admit_within(A, l, r, c, t, x) == T.admit(A, r, c, t, x) : T.Registry<A>}

# No connection goes over per_peer: a connection d within the limit before a
# subscribe, by anyone to anything, is within it after.
law ws_limits_peer_bound:
  for -A: Data
  for +l: T.Limits
  for +r: T.Registry<A>
  for +c: Nat
  for +t: String
  for +x: A
  for +d: Nat
  for within: {Nat.is_le(T.owned_count(A, T.subs(A, r), d), T.per_peer(l)) == True{} : Bool}
  {Nat.is_le(T.owned_count(A, T.subs(A, T.admit_within(A, l, r, c, t, x)), d), T.per_peer(l)) == True{} : Bool}

# The registry never goes over per_hub subscriptions.
law ws_limits_hub_bound:
  for -A: Data
  for +l: T.Limits
  for +r: T.Registry<A>
  for +c: Nat
  for +t: String
  for +x: A
  for within: {Nat.is_le(T.size(A, r), T.per_hub(l)) == True{} : Bool}
  {Nat.is_le(T.size(A, T.admit_within(A, l, r, c, t, x)), T.per_hub(l)) == True{} : Bool}

# A topic longer than topic_bytes in UTF-8 is never recorded.
law ws_limits_long_topic_unchanged:
  for -A: Data
  for +l: T.Limits
  for +r: T.Registry<A>
  for +c: Nat
  for +t: String
  for +x: A
  for long: {Nat.is_le(T.bytes_of(t), T.topic_bytes(l)) == False{} : Bool}
  {T.admit_within(A, l, r, c, t, x) == r : T.Registry<A>}

# Subscribing again to a topic the connection holds uses no slot: nothing
# changes.
law ws_limits_repeat_unchanged:
  for -A: Data
  for +l: T.Limits
  for +r: T.Registry<A>
  for +c: Nat
  for +t: String
  for +x: A
  for member: {T.has_sub(A, T.subs(A, r), c, t) == True{} : Bool}
  {T.admit_within(A, l, r, c, t, x) == r : T.Registry<A>}

# Closing a connection (T.remove, which release and prune apply to each
# claimed or closed ID) leaves it no slots ...
law ws_limits_remove_frees:
  for -A: Data
  for +r: T.Registry<A>
  for +c: Nat
  {T.owned_count(A, T.subs(A, T.remove(A, r, c)), c) == 0n : Nat}

# ... and gives every one of them back to the hub.
law ws_limits_remove_returns_slots:
  for -A: Data
  for +r: T.Registry<A>
  for +c: Nat
  {Nat.add(T.owned_count(A, T.subs(A, r), c), T.size(A, T.remove(A, r, c))) == T.size(A, r) : Nat}

# Deciding again on the updated registry gives the verdict the subscribe
# got, with an admission read as membership. The shell reports this.
law ws_limits_reported:
  for -A: Data
  for +l: T.Limits
  for +r: T.Registry<A>
  for +c: Nat
  for +t: String
  for +x: A
  {T.decide(A, l, T.admit_within(A, l, r, c, t, x), c, t) == T.settled(T.decide(A, l, r, c, t)) : T.Admission}
