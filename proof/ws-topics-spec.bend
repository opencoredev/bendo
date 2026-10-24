# BND-53: an independent model of topic membership. A connection is in a topic
# when the last operation naming that pair (or removing the connection) was a
# subscribe. `replay` runs the same history through src/ws/topics.bend.
import Base
import ../src/ws/topics.bend as T

type Op is Data:
  OpSubscribe{c: Nat, t: String}
  OpUnsubscribe{c: Nat, t: String}
  OpRemove{c: Nat}

def effect(op: Op, +c: Nat, +t: String, now: Bool) -> Bool:
  match op:
    case OpSubscribe{d, u}: (String.eq(u, t) && Nat.is_eq(d, c)) || now
    case OpUnsubscribe{d, u}: Bool.not(String.eq(u, t) && Nat.is_eq(d, c)) && now
    case OpRemove{d}: Bool.not(Nat.is_eq(d, c)) && now

def member(ops: List<&2, Op>, +c: Nat, +t: String, now: Bool) -> Bool:
  match ops:
    case Nil{}: now
    case op <> rest: member(rest, c, t, effect(op, c, t, now))

def apply(-A: Data, x: A, r: T.Registry<A>, op: Op) -> T.Registry<A>:
  match op:
    case OpSubscribe{d, u}: T.subscribe(A, r, d, u, x)
    case OpUnsubscribe{d, u}: T.unsubscribe(A, r, d, u)
    case OpRemove{d}: T.remove(A, r, d)

def replay_from(-A: Data, +x: A, ops: List<&2, Op>, r: T.Registry<A>) -> T.Registry<A>:
  match ops:
    case Nil{}: r
    case op <> rest: replay_from(A, x, rest, apply(A, x, r, op))

def replay(-A: Data, +x: A, ops: List<&2, Op>) -> T.Registry<A>:
  replay_from(A, x, ops, T.empty(A))

def has(ids: List<&2, Nat>, +c: Nat) -> Bool:
  match ids:
    case Nil{}: False{}
    case h <> t: Nat.is_eq(h, c) || has(t, c)

def tick(b: Bool, n: Nat) -> Nat:
  match b:
    case True{}: 1n+n
    case False{}: n

def count(ids: List<&2, Nat>, +c: Nat) -> Nat:
  match ids:
    case Nil{}: 0n
    case h <> t: tick(Nat.is_eq(h, c), count(t, c))

def once(b: Bool) -> Nat:
  match b:
    case True{}: 1n
    case False{}: 0n

def sender(c: Nat, ex: Maybe<&2, Nat>) -> Bool:
  match ex:
    case None{}: False{}
    case Some{e}: Nat.is_eq(c, e)

def skip(h: Nat, rest: List<&2, Nat>, out: Bool) -> List<&2, Nat>:
  match out:
    case True{}: rest
    case False{}: h <> rest

# The ids in order, without the sender.
def others(ids: List<&2, Nat>, +ex: Maybe<&2, Nat>) -> List<&2, Nat>:
  match ids:
    case Nil{}: []
    case +h <> t: skip(h, others(t, ex), sender(h, ex))

# ---- Records (BND-53 review round 1) ----

def put_if(-A: Data, s: T.Sub<A>, rest: List<&2, T.Sub<A>>, b: Bool) -> List<&2, T.Sub<A>>:
  match b:
    case True{}: s <> rest
    case False{}: rest

# The complete records a publication to t selects, in registry order: topic
# t, minus the sender's.
def select(-A: Data, xs: List<&2, T.Sub<A>>, +t: String, +ex: Maybe<&2, Nat>) -> List<&2, T.Sub<A>>:
  match xs:
    case Nil{}: []
    case T.Sub{+topic, +id, x} <> rest: put_if(A, T.Sub{topic, id, x}, select(A, rest, t, ex), String.eq(topic, t) && Bool.not(sender(id, ex)))

# Every record except those for the pair (t, c).
def unpaired(-A: Data, xs: List<&2, T.Sub<A>>, +c: Nat, +t: String) -> List<&2, T.Sub<A>>:
  match xs:
    case Nil{}: []
    case T.Sub{+topic, +id, x} <> rest: put_if(A, T.Sub{topic, id, x}, unpaired(A, rest, c, t), Bool.not(String.eq(topic, t) && Nat.is_eq(id, c)))

# The records for topic u.
def on_topic(-A: Data, xs: List<&2, T.Sub<A>>, +u: String) -> List<&2, T.Sub<A>>:
  match xs:
    case Nil{}: []
    case T.Sub{+topic, id, x} <> rest: put_if(A, T.Sub{topic, id, x}, on_topic(A, rest, u), String.eq(topic, u))

# The records of every connection except c.
def not_owned(-A: Data, xs: List<&2, T.Sub<A>>, +c: Nat) -> List<&2, T.Sub<A>>:
  match xs:
    case Nil{}: []
    case T.Sub{topic, +id, x} <> rest: put_if(A, T.Sub{topic, id, x}, not_owned(A, rest, c), Bool.not(Nat.is_eq(id, c)))

# Whether some record is for the pair (t, c).
def paired(-A: Data, xs: List<&2, T.Sub<A>>, +c: Nat, +t: String) -> Bool:
  match xs:
    case Nil{}: False{}
    case T.Sub{topic, id, x} <> rest: (String.eq(topic, t) && Nat.is_eq(id, c)) || paired(A, rest, c, t)

def found(-A: Data, x: A, rest: Maybe<&2, A>, b: Bool) -> Maybe<&2, A>:
  match b:
    case True{}: Some{x}
    case False{}: rest

# The target of the first record for the pair (t, c).
def find(-A: Data, xs: List<&2, T.Sub<A>>, +c: Nat, +t: String) -> Maybe<&2, A>:
  match xs:
    case Nil{}: None{}
    case T.Sub{topic, id, x} <> rest: found(A, x, find(A, rest, c, t), String.eq(topic, t) && Nat.is_eq(id, c))

def ids(-A: Data, xs: List<&2, T.Sub<A>>) -> List<&2, Nat>:
  match xs:
    case Nil{}: []
    case T.Sub{topic, id, x} <> rest: id <> ids(A, rest)

# ---- Well-formed registries ----

# No pair is recorded twice.
def distinct(-A: Data, xs: List<&2, T.Sub<A>>) -> Bool:
  match xs:
    case Nil{}: True{}
    case T.Sub{topic, id, x} <> +rest: Bool.not(paired(A, rest, id, topic)) && distinct(A, rest)

# Every record belongs to an active connection.
def covered(-A: Data, xs: List<&2, T.Sub<A>>, +live: List<&2, Nat>) -> Bool:
  match xs:
    case Nil{}: True{}
    case T.Sub{topic, id, x} <> rest: has(live, id) && covered(A, rest, live)

# Every active ID was handed out already.
def below(ids: List<&2, Nat>, +n: Nat) -> Bool:
  match ids:
    case Nil{}: True{}
    case h <> t: Nat.is_lt(h, n) && below(t, n)

# What every runtime operation preserves, starting from T.empty.
def wf(-A: Data, r: T.Registry<A>) -> Bool:
  T.Registry{+next, +live, +s} = r
  ((distinct(A, s) && covered(A, s, live)) && below(live, next)) && Nat.is_lt(0n, next)

# ---- Runtime histories ----

# Each registry change the pub/sub shell makes: a connection joins, a Peer
# subscribes with its handle, unsubscribes, closes, or a publication prunes
# closed mailboxes.
type Change<-A: Data> is Data:
  ChJoin{}
  ChSubscribe{c: Nat, t: String, x: A}
  ChUnsubscribe{c: Nat, t: String}
  ChClose{c: Nat}
  ChPrune{gone: List<&2, Nat>}

def change(-A: Data, r: T.Registry<A>, ch: Change<A>) -> T.Registry<A>:
  match ch:
    case ChJoin{}: T.join(A, r)
    case ChSubscribe{c, t, x}: T.admit(A, r, c, t, x)
    case ChUnsubscribe{c, t}: T.unsubscribe(A, r, c, t)
    case ChClose{c}: T.remove(A, r, c)
    case ChPrune{gone}: T.remove_all(A, gone, r)

def run_from(-A: Data, chs: List<&2, Change<A>>, r: T.Registry<A>) -> T.Registry<A>:
  match chs:
    case Nil{}: r
    case ch <> rest: run_from(A, rest, change(A, r, ch))

def run(-A: Data, chs: List<&2, Change<A>>) -> T.Registry<A>:
  run_from(A, chs, T.empty(A))

# ---- Ledger histories ----

# Each change the pub/sub shell makes to the hub's ledger: a registry change
# through `within`, a session joining under a token, or a session closing by
# token.
type Step<-A: Data> is Data:
  EvChange{ch: Change<A>}
  EvClaim{k: String}
  EvRelease{k: String}

def lift(-A: Data, l: T.Ledger<A>, ch: Change<A>) -> T.Ledger<A>:
  T.within(A, l, r => change(A, r, ch))

def event(-A: Data, l: T.Ledger<A>, ev: Step<A>) -> T.Ledger<A>:
  match ev:
    case EvChange{ch}: lift(A, l, ch)
    case EvClaim{k}: T.claim(A, l, k)
    case EvRelease{k}: T.release(A, l, k)

def play_from(-A: Data, evs: List<&2, Step<A>>, l: T.Ledger<A>) -> T.Ledger<A>:
  match evs:
    case Nil{}: l
    case ev <> rest: play_from(A, rest, event(A, l, ev))

def play(-A: Data, evs: List<&2, Step<A>>) -> T.Ledger<A>:
  play_from(A, evs, T.ledger(A))

# Registry changes only, as ledger events.
def changes(-A: Data, chs: List<&2, Change<A>>) -> List<&2, Step<A>>:
  match chs:
    case Nil{}: []
    case ch <> rest: EvChange{ch} <> changes(A, rest)
