# Pure topic registry for WebSocket publish/subscribe (BND-53). One B.Store
# actor owns a Registry, so every change is serialized; ./pubsub.bend is the IO
# shell. `A` is the delivery target, a connection handle at runtime.
import Base

# Connection `id` is subscribed to `topic`. A registry built only through these
# operations holds each (topic, id) pair at most once.
type Sub<-A: Data> is Data:
  Sub{topic: String, id: Nat, target: A}

# `next` is the next connection ID to hand out. IDs start at 1; 0 means a
# connection that never joined.
type Registry<-A: Data> is Data:
  Registry{next: Nat, subs: List<&2, Sub<A>>}

def empty(-A: Data) -> Registry<A>:
  Registry{1n, []}

def subs(-A: Data, r: Registry<A>) -> List<&2, Sub<A>>:
  Registry{next, s} = r
  s

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

def subscribe(-A: Data, r: Registry<A>, +c: Nat, +t: String, x: A) -> Registry<A>:
  Registry{next, s} = r
  Registry{next, subscribe_subs(A, s, c, t, x)}

def unsubscribe(-A: Data, r: Registry<A>, +c: Nat, +t: String) -> Registry<A>:
  Registry{next, s} = r
  Registry{next, without(A, s, c, t)}

# Leaves every topic: the close path of each connection.
def remove(-A: Data, r: Registry<A>, +c: Nat) -> Registry<A>:
  Registry{next, s} = r
  Registry{next, dropped(A, s, c)}

def remove_all(-A: Data, ids: List<&2, Nat>, r: Registry<A>) -> Registry<A>:
  match ids:
    case Nil{}: r
    case +c <> rest: remove_all(A, rest, remove(A, r, c))

# Hands out `next`. Read the new ID back as `joined(updated)`.
def join(-A: Data, r: Registry<A>) -> Registry<A>:
  Registry{next, s} = r
  Registry{1n+next, s}

def joined(-A: Data, r: Registry<A>) -> Nat:
  Registry{next, s} = r
  Nat.sub(next, 1n)

def pick(id: Nat, rest: List<&2, Nat>, take: Bool) -> List<&2, Nat>:
  match take:
    case True{}: id <> rest
    case False{}: rest

def members_of(-A: Data, xs: List<&2, Sub<A>>, +t: String) -> List<&2, Nat>:
  match xs:
    case Nil{}: []
    case Sub{topic, +id, x} <> rest: pick(id, members_of(A, rest, t), String.eq(topic, t))

# Connection IDs subscribed to `t`.
def members(-A: Data, r: Registry<A>, +t: String) -> List<&2, Nat>:
  Registry{next, s} = r
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
  Registry{next, s} = r
  targets_of(A, s, t, sender)

def target_ids(-A: Data, xs: List<&2, Sub<A>>) -> List<&2, Nat>:
  match xs:
    case Nil{}: []
    case Sub{topic, id, x} <> rest: id <> target_ids(A, rest)

def size(-A: Data, r: Registry<A>) -> Nat:
  Registry{next, s} = r
  List.length(&2, Sub<A>, s)
