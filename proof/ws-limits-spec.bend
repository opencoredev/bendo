# BND-105: an independent statement of the subscribe decision. Each check is
# written against the BND-53 model in ./ws-topics-spec.bend (membership as
# `paired`, slots as a count of the record IDs), and the checks are a table
# read top to bottom: the first one that fails names the refusal, and a
# request that passes all of them is admitted. The order is the one
# src/ws/topics.bend documents above `verdict`.
import Base
import ../src/data/utf8.bend as Utf8
import ../src/ws/topics.bend as T
import ./ws-topics-spec.bend as Spec

# One row: whether the request passes it, and what it gets if not.
type Check is Data:
  Check{pass: Bool, refusal: T.Admission}

def on_fail(pass: Bool, refusal: T.Admission, rest: T.Admission) -> T.Admission:
  match pass:
    case True{}: rest
    case False{}: refusal

def first_refusal(checks: List<&2, Check>) -> T.Admission:
  match checks:
    case Nil{}: T.Admitted{}
    case Check{pass, refusal} <> rest: on_fail(pass, refusal, first_refusal(rest))

# The connection has joined and not closed, the topic fits in `topic_bytes`
# UTF-8 bytes, the connection does not hold it yet, it holds fewer than
# `per_peer` topics, and the hub holds fewer than `per_hub` subscriptions.
def checks(-A: Data, l: T.Limits, r: T.Registry<A>, +c: Nat, +t: String) -> List<&2, Check>:
  T.Limits{p, h, b} = l
  T.Registry{n, live, +s} = r
  [Check{Spec.has(live, c), T.NotActive{}}, Check{Nat.is_le(List.length(&2, U32, Utf8.encode(t)), b), T.TopicTooLong{}}, Check{Bool.not(Spec.paired(A, s, c, t)), T.AlreadyMember{}}, Check{Nat.is_lt(Spec.count(Spec.ids(A, s), c), p), T.PeerFull{}}, Check{Nat.is_lt(List.length(&2, T.Sub<A>, s), h), T.HubFull{}}]

def decision(-A: Data, +l: T.Limits, +r: T.Registry<A>, +c: Nat, +t: String) -> T.Admission:
  first_refusal(checks(A, l, r, c, t))

def all_pass(checks: List<&2, Check>) -> Bool:
  match checks:
    case Nil{}: True{}
    case Check{pass, refusal} <> rest: pass && all_pass(rest)

# Every check passes.
def open(-A: Data, +l: T.Limits, +r: T.Registry<A>, +c: Nat, +t: String) -> Bool:
  all_pass(checks(A, l, r, c, t))
