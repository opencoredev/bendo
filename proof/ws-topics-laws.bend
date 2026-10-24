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

# ---- Complete records (review round 1) ----

# Membership read from the records: c is in members(t) exactly when some
# record is for the pair (t, c).
law ws_topics_members_records:
  for -A: Data
  for +r: T.Registry<A>
  for +c: Nat
  for +t: String
  {Spec.has(T.members(A, r, t), c) == Spec.paired(A, T.subs(A, r), c, t) : Bool}

# A publication to t selects exactly the complete records for topic t, minus
# the sender's, in registry order: the stored targets, not just their IDs.
law ws_topics_targets_records:
  for -A: Data
  for +r: T.Registry<A>
  for +t: String
  for +sender: Maybe<&2, Nat>
  {T.targets(A, r, t, sender) == Spec.select(A, T.subs(A, r), t, sender) : List<&2, T.Sub<A>>}

# Subscribing (c, t, x) stores target x and replaces every earlier record for
# that pair; all other records keep their order.
law ws_topics_subscribe_record:
  for -A: Data
  for +r: T.Registry<A>
  for +c: Nat
  for +t: String
  for +x: A
  {T.subs(A, T.subscribe(A, r, c, t, x)) == T.Sub{t, c, x} <> Spec.unpaired(A, T.subs(A, r), c, t) : List<&2, T.Sub<A>>}

law ws_topics_subscribe_target:
  for -A: Data
  for +r: T.Registry<A>
  for +c: Nat
  for +t: String
  for +x: A
  {Spec.find(A, T.subs(A, T.subscribe(A, r, c, t, x)), c, t) == Some{x} : Maybe<&2, A>}

law ws_topics_unsubscribe_record:
  for -A: Data
  for +r: T.Registry<A>
  for +c: Nat
  for +t: String
  {T.subs(A, T.unsubscribe(A, r, c, t)) == Spec.unpaired(A, T.subs(A, r), c, t) : List<&2, T.Sub<A>>}

# Topics are independent at the record level: every other topic's records,
# targets included, are unchanged.
law ws_topics_subscribe_records_independent:
  for -A: Data
  for +r: T.Registry<A>
  for +c: Nat
  for +t: String
  for +u: String
  for +x: A
  for +other: {String.eq(t, u) == False{} : Bool}
  {Spec.on_topic(A, T.subs(A, T.subscribe(A, r, c, t, x)), u) == Spec.on_topic(A, T.subs(A, r), u) : List<&2, T.Sub<A>>}

law ws_topics_unsubscribe_records_independent:
  for -A: Data
  for +r: T.Registry<A>
  for +c: Nat
  for +t: String
  for +u: String
  for +other: {String.eq(t, u) == False{} : Bool}
  {Spec.on_topic(A, T.subs(A, T.unsubscribe(A, r, c, t)), u) == Spec.on_topic(A, T.subs(A, r), u) : List<&2, T.Sub<A>>}

# remove(c) keeps exactly the records of other connections, in order, keeps
# `next`, and revokes c.
law ws_topics_remove_record:
  for -A: Data
  for +r: T.Registry<A>
  for +c: Nat
  {T.subs(A, T.remove(A, r, c)) == Spec.not_owned(A, T.subs(A, r), c) : List<&2, T.Sub<A>>}

law ws_topics_remove_next:
  for -A: Data
  for +r: T.Registry<A>
  for +c: Nat
  {T.next(A, T.remove(A, r, c)) == T.next(A, r) : Nat}

law ws_topics_remove_revokes:
  for -A: Data
  for +r: T.Registry<A>
  for +c: Nat
  {Spec.has(T.live(A, T.remove(A, r, c)), c) == False{} : Bool}

# ---- Active connections ----

# admit is subscribe for an active connection and no change otherwise.
law ws_topics_admit_active:
  for -A: Data
  for +r: T.Registry<A>
  for +c: Nat
  for +t: String
  for +x: A
  for +active: {Spec.has(T.live(A, r), c) == True{} : Bool}
  {T.admit(A, r, c, t, x) == T.subscribe(A, r, c, t, x) : T.Registry<A>}

law ws_topics_admit_inactive:
  for -A: Data
  for +r: T.Registry<A>
  for +c: Nat
  for +t: String
  for +x: A
  for +inactive: {Spec.has(T.live(A, r), c) == False{} : Bool}
  {T.admit(A, r, c, t, x) == r : T.Registry<A>}

# A subscribe that arrives after the close cleanup changes nothing.
law ws_topics_late_subscribe:
  for -A: Data
  for +r: T.Registry<A>
  for +c: Nat
  for +t: String
  for +x: A
  {T.admit(A, T.remove(A, r, c), c, t, x) == T.remove(A, r, c) : T.Registry<A>}

# ---- Allocator ----

law ws_topics_join_next:
  for -A: Data
  for +r: T.Registry<A>
  {T.next(A, T.join(A, r)) == 1n+T.next(A, r) : Nat}

law ws_topics_join_id:
  for -A: Data
  for +r: T.Registry<A>
  {T.joined(A, T.join(A, r)) == T.next(A, r) : Nat}

# join keeps every record and adds only the new ID to the active set.
law ws_topics_join_subs:
  for -A: Data
  for +r: T.Registry<A>
  {T.subs(A, T.join(A, r)) == T.subs(A, r) : List<&2, T.Sub<A>>}

law ws_topics_join_live:
  for -A: Data
  for +r: T.Registry<A>
  {T.live(A, T.join(A, r)) == T.next(A, r) <> T.live(A, r) : List<&2, Nat>}

# In a well-formed registry the new ID is not 0 and differs from every active
# ID and every subscribed ID.
law ws_topics_join_positive:
  for -A: Data
  for +r: T.Registry<A>
  for +wf: {Spec.wf(A, r) == True{} : Bool}
  {Nat.is_eq(T.joined(A, T.join(A, r)), 0n) == False{} : Bool}

law ws_topics_join_fresh_live:
  for -A: Data
  for +r: T.Registry<A>
  for +wf: {Spec.wf(A, r) == True{} : Bool}
  {Spec.has(T.live(A, r), T.joined(A, T.join(A, r))) == False{} : Bool}

law ws_topics_join_fresh_subs:
  for -A: Data
  for +r: T.Registry<A>
  for +wf: {Spec.wf(A, r) == True{} : Bool}
  {Spec.has(Spec.ids(A, T.subs(A, r)), T.joined(A, T.join(A, r))) == False{} : Bool}

# ---- Well-formedness is preserved by every runtime operation ----

law ws_topics_wf_empty:
  for -A: Data
  {Spec.wf(A, T.empty(A)) == True{} : Bool}

law ws_topics_wf_join:
  for -A: Data
  for +r: T.Registry<A>
  for +wf: {Spec.wf(A, r) == True{} : Bool}
  {Spec.wf(A, T.join(A, r)) == True{} : Bool}

law ws_topics_wf_admit:
  for -A: Data
  for +r: T.Registry<A>
  for +c: Nat
  for +t: String
  for +x: A
  for +wf: {Spec.wf(A, r) == True{} : Bool}
  {Spec.wf(A, T.admit(A, r, c, t, x)) == True{} : Bool}

law ws_topics_wf_unsubscribe:
  for -A: Data
  for +r: T.Registry<A>
  for +c: Nat
  for +t: String
  for +wf: {Spec.wf(A, r) == True{} : Bool}
  {Spec.wf(A, T.unsubscribe(A, r, c, t)) == True{} : Bool}

law ws_topics_wf_remove:
  for -A: Data
  for +r: T.Registry<A>
  for +c: Nat
  for +wf: {Spec.wf(A, r) == True{} : Bool}
  {Spec.wf(A, T.remove(A, r, c)) == True{} : Bool}

law ws_topics_wf_remove_all:
  for -A: Data
  for +ids: List<&2, Nat>
  for +r: T.Registry<A>
  for +wf: {Spec.wf(A, r) == True{} : Bool}
  {Spec.wf(A, T.remove_all(A, ids, r)) == True{} : Bool}

# Every registry the shell can reach, through any history of joins,
# subscribes with their targets, unsubscribes, closes and prunes, is
# well-formed.
law ws_topics_history_wf:
  for -A: Data
  for +chs: List<&2, Spec.Change<A>>
  {Spec.wf(A, Spec.run(A, chs)) == True{} : Bool}

# ---- Exactly-once selection ----

# In a well-formed registry, a publication to t selects connection c exactly
# once if a record pairs it with t and it is not the excluded sender, and
# otherwise never.
law ws_topics_publish_once_wf:
  for -A: Data
  for +r: T.Registry<A>
  for +c: Nat
  for +t: String
  for +sender: Maybe<&2, Nat>
  for +wf: {Spec.wf(A, r) == True{} : Bool}
  {Spec.count(T.target_ids(A, T.targets(A, r, t, sender)), c) == Spec.once(Spec.paired(A, T.subs(A, r), c, t) && Bool.not(Spec.sender(c, sender))) : Nat}

# The same over every runtime history.
law ws_topics_history_once:
  for -A: Data
  for +chs: List<&2, Spec.Change<A>>
  for +c: Nat
  for +t: String
  for +sender: Maybe<&2, Nat>
  {Spec.count(T.target_ids(A, T.targets(A, Spec.run(A, chs), t, sender)), c) == Spec.once(Spec.paired(A, T.subs(A, Spec.run(A, chs)), c, t) && Bool.not(Spec.sender(c, sender))) : Nat}

# ---- Claims (review round 2) ----

# claim(k) is join on the registry and records the new ID under k.
law ws_topics_claim_registry:
  for -A: Data
  for +l: T.Ledger<A>
  for +k: String
  {T.registry(A, T.claim(A, l, k)) == T.join(A, T.registry(A, l)) : T.Registry<A>}

law ws_topics_claim_records:
  for -A: Data
  for +l: T.Ledger<A>
  for +k: String
  {T.claimed(T.claims(A, T.claim(A, l, k)), k) == T.next(A, T.registry(A, l)) <> T.claimed(T.claims(A, l), k) : List<&2, Nat>}

# Registry changes keep every claim, so a token still names its ID when the
# session closes.
law ws_topics_change_keeps_claims:
  for -A: Data
  for +l: T.Ledger<A>
  for +ch: Spec.Change<A>
  {T.claims(A, Spec.lift(A, l, ch)) == T.claims(A, l) : List<&2, T.Claim>}

# release(k) revokes every ID claimed under k, whether or not the session
# learned it, and forgets k's claims.
law ws_topics_release_revokes:
  for -A: Data
  for +l: T.Ledger<A>
  for +k: String
  for +c: Nat
  for +held: {Spec.has(T.claimed(T.claims(A, l), k), c) == True{} : Bool}
  {Spec.has(T.live(A, T.registry(A, T.release(A, l, k))), c) == False{} : Bool}

law ws_topics_release_leaves:
  for -A: Data
  for +l: T.Ledger<A>
  for +k: String
  for +c: Nat
  for +t: String
  for +held: {Spec.has(T.claimed(T.claims(A, l), k), c) == True{} : Bool}
  {Spec.has(T.members(A, T.registry(A, T.release(A, l, k)), t), c) == False{} : Bool}

law ws_topics_release_unclaims:
  for -A: Data
  for +l: T.Ledger<A>
  for +k: String
  {T.claimed(T.claims(A, T.release(A, l, k)), k) == [] : List<&2, Nat>}

# A join committed after the session stopped waiting is still revoked by the
# session's close, with any registry changes in between.
law ws_topics_late_join_released:
  for -A: Data
  for +l: T.Ledger<A>
  for +k: String
  for +chs: List<&2, Spec.Change<A>>
  {Spec.has(T.live(A, T.registry(A, T.release(A, Spec.play_from(A, Spec.changes(A, chs), T.claim(A, l, k)), k))), T.next(A, T.registry(A, l))) == False{} : Bool}

law ws_topics_wf_claim:
  for -A: Data
  for +l: T.Ledger<A>
  for +k: String
  for +wf: {Spec.wf(A, T.registry(A, l)) == True{} : Bool}
  {Spec.wf(A, T.registry(A, T.claim(A, l, k))) == True{} : Bool}

law ws_topics_wf_release:
  for -A: Data
  for +l: T.Ledger<A>
  for +k: String
  for +wf: {Spec.wf(A, T.registry(A, l)) == True{} : Bool}
  {Spec.wf(A, T.registry(A, T.release(A, l, k))) == True{} : Bool}

# Every registry the hub's ledger can reach, through any history of claims,
# releases and registry changes, is well-formed.
law ws_topics_ledger_history_wf:
  for -A: Data
  for +evs: List<&2, Spec.Step<A>>
  {Spec.wf(A, T.registry(A, Spec.play(A, evs))) == True{} : Bool}
