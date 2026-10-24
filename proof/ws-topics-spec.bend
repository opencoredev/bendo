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
