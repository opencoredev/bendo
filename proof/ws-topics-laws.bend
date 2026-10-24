# BND-53: WebSocket topic registry laws. Proofs live in proof/ws-topics.bend.
import Base
import ../src/ws/topics.bend as T
import ./ws-topics-spec.bend as Spec

# After subscribe(c, t), members(t) contains c.
law ws_topics_subscribe_member:
  for -A: Data
  for +r: T.Registry<A>
  for +c: Nat
  for +t: String
  for +x: A
  {Spec.has(T.members(A, T.subscribe(A, r, c, t, x), t), c) == True{} : Bool}

# After unsubscribe(c, t), members(t) does not contain c.
law ws_topics_unsubscribe_leaves:
  for -A: Data
  for +r: T.Registry<A>
  for +c: Nat
  for +t: String
  {Spec.has(T.members(A, T.unsubscribe(A, r, c, t), t), c) == False{} : Bool}

# After remove(c), no topic contains c.
law ws_topics_remove_leaves:
  for -A: Data
  for +r: T.Registry<A>
  for +c: Nat
  for +t: String
  {Spec.has(T.members(A, T.remove(A, r, c), t), c) == False{} : Bool}

# Topics are independent: changing (c, t) leaves every other topic's members,
# in order, unchanged.
law ws_topics_subscribe_independent:
  for -A: Data
  for +r: T.Registry<A>
  for +c: Nat
  for +t: String
  for +u: String
  for +x: A
  for +other: {String.eq(t, u) == False{} : Bool}
  {T.members(A, T.subscribe(A, r, c, t, x), u) == T.members(A, r, u) : List<&2, Nat>}

law ws_topics_unsubscribe_independent:
  for -A: Data
  for +r: T.Registry<A>
  for +c: Nat
  for +t: String
  for +u: String
  for +other: {String.eq(t, u) == False{} : Bool}
  {T.members(A, T.unsubscribe(A, r, c, t), u) == T.members(A, r, u) : List<&2, Nat>}

# A publication to t targets exactly members(t), minus the sender when one is
# given.
law ws_topics_publish_targets:
  for -A: Data
  for +r: T.Registry<A>
  for +t: String
  for +sender: Maybe<&2, Nat>
  {T.target_ids(A, T.targets(A, r, t, sender)) == Spec.others(T.members(A, r, t), sender) : List<&2, Nat>}

# Over any history of subscribe, unsubscribe and remove, membership matches
# the independent model.
law ws_topics_registry_spec:
  for -A: Data
  for +x: A
  for +ops: List<&2, Spec.Op>
  for +c: Nat
  for +t: String
  {Spec.has(T.members(A, Spec.replay(A, x, ops), t), c) == Spec.member(ops, c, t, False{}) : Bool}

# Over any history, a publication reaches each connection exactly once if it
# is a member and not the excluded sender, and otherwise never.
law ws_topics_publish_once:
  for -A: Data
  for +x: A
  for +ops: List<&2, Spec.Op>
  for +c: Nat
  for +t: String
  for +sender: Maybe<&2, Nat>
  {Spec.count(T.target_ids(A, T.targets(A, Spec.replay(A, x, ops), t, sender)), c) == Spec.once(Spec.member(ops, c, t, False{}) && Bool.not(Spec.sender(c, sender))) : Nat}
