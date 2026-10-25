# Pure topic registry for WebSocket publish/subscribe (BND-53). One B.Store
# actor owns a Registry, so every change is serialized; ./pubsub.bend is the IO
# shell. `A` is the delivery target, a connection handle at runtime.
import Base
import ../data/utf8.bend as Utf8

# Connection `id` is subscribed to `topic`. A registry built only through these
# operations holds each (topic, id) pair at most once.
type Sub<-A: Data> is Data:
  Sub{topic: String, id: Nat, target: A}

# `next` is the next connection ID to hand out. IDs start at 1; 0 means a
# connection that never joined. `live` holds the IDs that joined and have not
# closed: only they may subscribe.
type Registry<-A: Data> is Data:
  Registry{next: Nat, live: List<&2, Nat>, subs: List<&2, Sub<A>>}

def empty(-A: Data) -> Registry<A>:
  Registry{1n, [], []}

def subs(-A: Data, r: Registry<A>) -> List<&2, Sub<A>>:
  Registry{next, live, s} = r
  s

def live(-A: Data, r: Registry<A>) -> List<&2, Nat>:
  Registry{next, live, s} = r
  live

def next(-A: Data, r: Registry<A>) -> Nat:
  Registry{next, live, s} = r
  next

def keep(-A: Data, s: Sub<A>, rest: List<&2, Sub<A>>, drop: Bool) -> List<&2, Sub<A>>:
  match drop:
    case True{}: rest
    case False{}: s <> rest

# Whether `s` is connection `c`'s membership in topic `t`.
def hit(-A: Data, s: Sub<A>, +c: Nat, +t: String) -> Bool:
  Sub{topic, id, x} = s
  String.eq(topic, t) && Nat.is_eq(id, c)

def owned(-A: Data, s: Sub<A>, +c: Nat) -> Bool:
  Sub{topic, id, x} = s
  Nat.is_eq(id, c)

def without(-A: Data, xs: List<&2, Sub<A>>, +c: Nat, +t: String) -> List<&2, Sub<A>>:
  match xs:
    case Nil{}: []
    case +s <> rest: keep(A, s, without(A, rest, c, t), hit(A, s, c, t))

def dropped(-A: Data, xs: List<&2, Sub<A>>, +c: Nat) -> List<&2, Sub<A>>:
  match xs:
    case Nil{}: []
    case +s <> rest: keep(A, s, dropped(A, rest, c), owned(A, s, c))

# Subscribing again replaces the old entry, so each pair appears once.
def subscribe_subs(-A: Data, xs: List<&2, Sub<A>>, +c: Nat, +t: String, x: A) -> List<&2, Sub<A>>:
  Sub{t, c, x} <> without(A, xs, c, t)

def pick(id: Nat, rest: List<&2, Nat>, take: Bool) -> List<&2, Nat>:
  match take:
    case True{}: id <> rest
    case False{}: rest

def holds(ids: List<&2, Nat>, +c: Nat) -> Bool:
  match ids:
    case Nil{}: False{}
    case h <> t: Nat.is_eq(h, c) || holds(t, c)

def revoked(ids: List<&2, Nat>, +c: Nat) -> List<&2, Nat>:
  match ids:
    case Nil{}: []
    case +h <> t: pick(h, revoked(t, c), Bool.not(Nat.is_eq(h, c)))

# Whether connection `c` has joined and not yet closed.
def active(-A: Data, r: Registry<A>, +c: Nat) -> Bool:
  Registry{next, live, s} = r
  holds(live, c)

# Records the subscription unconditionally. The shell goes through `admit`.
def subscribe(-A: Data, r: Registry<A>, +c: Nat, +t: String, x: A) -> Registry<A>:
  Registry{next, live, s} = r
  Registry{next, live, subscribe_subs(A, s, c, t, x)}

def admit_if(-A: Data, r: Registry<A>, +c: Nat, +t: String, x: A, ok: Bool) -> Registry<A>:
  match ok:
    case True{}: subscribe(A, r, c, t, x)
    case False{}: r

# Subscribes an active connection and leaves the registry unchanged for one
# that closed or never joined, so a retained Peer cannot re-register a dead ID.
def admit(-A: Data, +r: Registry<A>, +c: Nat, +t: String, x: A) -> Registry<A>:
  admit_if(A, r, c, t, x, active(A, r, c))

def unsubscribe(-A: Data, r: Registry<A>, +c: Nat, +t: String) -> Registry<A>:
  Registry{next, live, s} = r
  Registry{next, live, without(A, s, c, t)}

# Leaves every topic and revokes the ID in one step: the close path of each
# connection.
def remove(-A: Data, r: Registry<A>, +c: Nat) -> Registry<A>:
  Registry{next, live, s} = r
  Registry{next, revoked(live, c), dropped(A, s, c)}

def remove_all(-A: Data, ids: List<&2, Nat>, r: Registry<A>) -> Registry<A>:
  match ids:
    case Nil{}: r
    case +c <> rest: remove_all(A, rest, remove(A, r, c))

# Hands out `next` and marks it active. Read the new ID back as
# `joined(updated)`.
def join(-A: Data, r: Registry<A>) -> Registry<A>:
  Registry{+next, live, s} = r
  Registry{1n+next, next <> live, s}

def previous(n: Nat) -> Nat:
  match n:
    case 0n: 0n
    case 1n+m: m

def joined(-A: Data, r: Registry<A>) -> Nat:
  Registry{next, live, s} = r
  previous(next)

def members_of(-A: Data, xs: List<&2, Sub<A>>, +t: String) -> List<&2, Nat>:
  match xs:
    case Nil{}: []
    case Sub{topic, +id, x} <> rest: pick(id, members_of(A, rest, t), String.eq(topic, t))

# Connection IDs subscribed to `t`.
def members(-A: Data, r: Registry<A>, +t: String) -> List<&2, Nat>:
  Registry{next, live, s} = r
  members_of(A, s, t)

def excluded(id: Nat, sender: Maybe<&2, Nat>) -> Bool:
  match sender:
    case None{}: False{}
    case Some{e}: Nat.is_eq(id, e)

def chosen(-A: Data, s: Sub<A>, +t: String, +sender: Maybe<&2, Nat>) -> Bool:
  Sub{topic, id, x} = s
  String.eq(topic, t) && Bool.not(excluded(id, sender))

def targets_of(-A: Data, xs: List<&2, Sub<A>>, +t: String, +sender: Maybe<&2, Nat>) -> List<&2, Sub<A>>:
  match xs:
    case Nil{}: []
    case +s <> rest: List.filter.put(Sub<A>, s, targets_of(A, rest, t, sender), chosen(A, s, t, sender))

# Who a publication to `t` reaches: its members, minus `sender` when given.
def targets(-A: Data, r: Registry<A>, +t: String, +sender: Maybe<&2, Nat>) -> List<&2, Sub<A>>:
  Registry{next, live, s} = r
  targets_of(A, s, t, sender)

def target_ids(-A: Data, xs: List<&2, Sub<A>>) -> List<&2, Nat>:
  match xs:
    case Nil{}: []
    case Sub{topic, id, x} <> rest: id <> target_ids(A, rest)

def size(-A: Data, r: Registry<A>) -> Nat:
  Registry{next, live, s} = r
  List.length(&2, Sub<A>, s)

# Connections that joined and have not closed.
def connections(-A: Data, r: Registry<A>) -> Nat:
  Registry{next, live, s} = r
  List.length(&2, Nat, live)

# ---- Limits (BND-105) ----

# How many subscriptions one connection (`per_peer`) and the whole registry
# (`per_hub`) may hold, and the longest topic name in UTF-8 bytes.
type Limits is Data:
  Limits{per_peer: Nat, per_hub: Nat, topic_bytes: Nat}

# 128 per connection and 255-byte names, as Centrifugo's defaults. 65,536 in
# all bounds what each subscribe and publication scans.
def limits_default() -> Limits:
  Limits{128n, 65536n, 255n}

def per_peer(l: Limits) -> Nat:
  Limits{p, h, b} = l
  p

def per_hub(l: Limits) -> Nat:
  Limits{p, h, b} = l
  h

def topic_bytes(l: Limits) -> Nat:
  Limits{p, h, b} = l
  b

# What a subscribe request gets. Only Admitted changes the registry.
type Admission is Data:
  Admitted{}
  AlreadyMember{}
  NotActive{}
  TopicTooLong{}
  PeerFull{}
  HubFull{}

def admitted(a: Admission) -> Bool:
  match a:
    case Admitted{}: True{}
    case AlreadyMember{}: False{}
    case NotActive{}: False{}
    case TopicTooLong{}: False{}
    case PeerFull{}: False{}
    case HubFull{}: False{}

def bump(b: Bool, n: Nat) -> Nat:
  match b:
    case True{}: 1n+n
    case False{}: n

# Subscriptions held by connection `c`.
def owned_count(-A: Data, xs: List<&2, Sub<A>>, +c: Nat) -> Nat:
  match xs:
    case Nil{}: 0n
    case +s <> rest: bump(owned(A, s, c), owned_count(A, rest, c))

# Whether connection `c` already holds topic `t`.
def has_sub(-A: Data, xs: List<&2, Sub<A>>, +c: Nat, +t: String) -> Bool:
  match xs:
    case Nil{}: False{}
    case +s <> rest: hit(A, s, c, t) || has_sub(A, rest, c, t)

def bytes_of(t: String) -> Nat:
  List.length(&2, U32, Utf8.encode(t))

# The checks in order: the connection is active, the topic is short enough,
# the connection is not already in it (a repeat uses no slot), it has a slot
# left, and the registry has one left.
def verdict(active: Bool, short: Bool, member: Bool, peer_room: Bool, hub_room: Bool) -> Admission:
  match active:
    case False{}: NotActive{}
    case True{}:
      match short:
        case False{}: TopicTooLong{}
        case True{}:
          match member:
            case True{}: AlreadyMember{}
            case False{}:
              match peer_room:
                case False{}: PeerFull{}
                case True{}:
                  match hub_room:
                    case False{}: HubFull{}
                    case True{}: Admitted{}

def decide(-A: Data, +l: Limits, +r: Registry<A>, +c: Nat, +t: String) -> Admission:
  verdict(active(A, r, c), Nat.is_le(bytes_of(t), topic_bytes(l)), has_sub(A, subs(A, r), c, t), Nat.is_lt(owned_count(A, subs(A, r), c), per_peer(l)), Nat.is_lt(size(A, r), per_hub(l)))

# The verdict as the registry records it: an admission makes the connection
# a member, which a second decide reports as AlreadyMember.
def settled(a: Admission) -> Admission:
  match a:
    case Admitted{}: AlreadyMember{}
    case AlreadyMember{}: AlreadyMember{}
    case NotActive{}: NotActive{}
    case TopicTooLong{}: TopicTooLong{}
    case PeerFull{}: PeerFull{}
    case HubFull{}: HubFull{}

def granted(-A: Data, r: Registry<A>, +c: Nat, +t: String, x: A, a: Admission) -> Registry<A>:
  match a:
    case Admitted{}: subscribe(A, r, c, t, x)
    case AlreadyMember{}: r
    case NotActive{}: r
    case TopicTooLong{}: r
    case PeerFull{}: r
    case HubFull{}: r

# admit under `l`: subscribes only when decide says Admitted, and otherwise
# returns `r` unchanged. The shell reads the outcome back as
# `decide(l, updated, c, t)`, which is AlreadyMember after an admission.
def admit_within(-A: Data, +l: Limits, +r: Registry<A>, +c: Nat, +t: String, x: A) -> Registry<A>:
  granted(A, r, c, t, x, decide(A, l, r, c, t))

# ---- Claims ----

# A session's join under its own `token`. Store.update can time out after the
# join is queued, and the actor still commits it, so the session may never
# learn its ID. It closes by token instead, and the actor revokes whatever ID
# that token claimed.
type Claim is Data:
  Claim{token: String, id: Nat}

# What the hub's actor holds: the registry and every unreleased claim.
type Ledger<-A: Data> is Data:
  Ledger{registry: Registry<A>, claims: List<&2, Claim>}

def ledger(-A: Data) -> Ledger<A>:
  Ledger{empty(A), []}

def registry(-A: Data, l: Ledger<A>) -> Registry<A>:
  Ledger{r, cs} = l
  r

def claims(-A: Data, l: Ledger<A>) -> List<&2, Claim>:
  Ledger{r, cs} = l
  cs

# Applies a registry operation, keeping every claim.
def within(-A: Data, l: Ledger<A>, f: Registry<A> -> Registry<A>) -> Ledger<A>:
  Ledger{r, cs} = l
  Ledger{f(r), cs}

# IDs claimed under token `k`.
def claimed(cs: List<&2, Claim>, +k: String) -> List<&2, Nat>:
  match cs:
    case Nil{}: []
    case Claim{token, +id} <> rest: pick(id, claimed(rest, k), String.eq(token, k))

def keep_claim(c: Claim, rest: List<&2, Claim>, drop: Bool) -> List<&2, Claim>:
  match drop:
    case True{}: rest
    case False{}: c <> rest

def for_token(c: Claim, +k: String) -> Bool:
  Claim{token, id} = c
  String.eq(token, k)

def unclaimed(cs: List<&2, Claim>, +k: String) -> List<&2, Claim>:
  match cs:
    case Nil{}: []
    case +c <> rest: keep_claim(c, unclaimed(rest, k), for_token(c, k))

def claim_registry(-A: Data, r: Registry<A>, +k: String, cs: List<&2, Claim>) -> Ledger<A>:
  Registry{+next, live, s} = r
  Ledger{join(A, Registry{next, live, s}), Claim{k, next} <> cs}

# Joins and records the new ID under `k`. Read it back as
# `joined(registry(updated))`.
def claim(-A: Data, l: Ledger<A>, +k: String) -> Ledger<A>:
  Ledger{r, cs} = l
  claim_registry(A, r, k, cs)

# The close path: removes every ID claimed under `k` from every topic,
# revokes it, and forgets the claims. Other tokens' claims are kept.
def release(-A: Data, l: Ledger<A>, +k: String) -> Ledger<A>:
  Ledger{r, +cs} = l
  Ledger{remove_all(A, claimed(cs, k), r), unclaimed(cs, k)}

def pruned_claim(c: Claim, +ids: List<&2, Nat>) -> Bool:
  Claim{token, id} = c
  holds(ids, id)

# The claims whose ID is not in `ids`.
def unpruned(cs: List<&2, Claim>, +ids: List<&2, Nat>) -> List<&2, Claim>:
  match cs:
    case Nil{}: []
    case +c <> rest: keep_claim(c, unpruned(rest, ids), pruned_claim(c, ids))

# A publication's cleanup of connections it found closed: removes each ID from
# every topic, revokes it, and forgets its claim, so the ledger shrinks back
# even when that connection's own release never arrives.
def prune(-A: Data, l: Ledger<A>, +ids: List<&2, Nat>) -> Ledger<A>:
  Ledger{r, cs} = l
  Ledger{remove_all(A, ids, r), unpruned(cs, ids)}
