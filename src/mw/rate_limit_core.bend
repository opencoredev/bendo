# Rate limiting decisions and the bounded key table. Pure; the laws import it.
# The middleware applies admit() inside one B.Store update, so concurrent
# requests are serialized and no count is lost.
import Base

# FixedWindow: at most limit requests per aligned window of window_ms.
# TokenBucket: capacity tokens; refill tokens are added every every_ms.
type Policy is Data:
  FixedWindow{limit: Nat, window_ms: Nat}
  TokenBucket{capacity: Nat, refill: Nat, every_ms: Nat}

# The window number (now / window_ms) and the requests counted in it.
type Counter is Data:
  Counter{epoch: Nat, count: Nat}

# level is in token-milliseconds (tokens * every_ms), so refill is exact
# integer math: elapsed ms * refill. last is the latest time seen.
type Bucket is Data:
  Bucket{level: Nat, last: Nat}

type FixedStep is Data:
  FixedStep{allowed: Bool, entry: Counter}

type BucketStep is Data:
  BucketStep{allowed: Bool, entry: Bucket}

# Fixed window. A request whose window is not later than the entry's counts
# against the entry's window: requests can reach the store out of clock order,
# and an earlier one must never reset a newer window.
def fixed_pick(epoch: Nat, count: Nat, ok: Bool) -> FixedStep:
  match ok:
    case True{}: FixedStep{True{}, Counter{epoch, 1n+count}}
    case False{}: FixedStep{False{}, Counter{epoch, count}}

def fixed_count(+limit: Nat, epoch: Nat, +count: Nat) -> FixedStep:
  fixed_pick(epoch, count, Nat.is_lt(count, limit))

def fixed_window(+limit: Nat, entry: Counter, +current: Nat, same: Bool) -> FixedStep:
  match entry same:
    case Counter{epoch, count} True{}: fixed_count(limit, epoch, count)
    case Counter{epoch, count} False{}: fixed_count(limit, current, 0n)

def fixed_step(+limit: Nat, window_ms: Nat, entry: Counter, now: Nat) -> FixedStep:
  Counter{+epoch, count} = entry
  +current = Nat.div(now, window_ms)
  fixed_window(limit, Counter{epoch, count}, current, Nat.is_le(current, epoch))

# Token bucket. The level refills by elapsed * refill, capped at the full
# level, then a request takes every_ms (one token) if that much is there.
def full_level(capacity: Nat, +every_ms: Nat) -> Nat:
  Nat.mul(capacity, every_ms)

def refilled(+full: Nat, level: Nat, last: Nat, now: Nat, +refill: Nat) -> Nat:
  Nat.min(full, Nat.add(level, Nat.mul(Nat.sub(now, last), refill)))

def bucket_pick(+level: Nat, +every_ms: Nat, at: Nat, ok: Bool) -> BucketStep:
  match ok:
    case True{}: BucketStep{True{}, Bucket{Nat.sub(level, every_ms), at}}
    case False{}: BucketStep{False{}, Bucket{level, at}}

def bucket_take(+level: Nat, +every_ms: Nat, at: Nat) -> BucketStep:
  bucket_pick(level, every_ms, at, Nat.is_le(every_ms, level))

def bucket_step(capacity: Nat, +refill: Nat, +every_ms: Nat, entry: Bucket, +now: Nat) -> BucketStep:
  Bucket{level, +last} = entry
  bucket_take(refilled(full_level(capacity, every_ms), level, last, now, refill), every_ms, Nat.max(last, now))

# What one request learned: whether it may proceed, the policy's quota, the
# quota left, milliseconds until the quota is whole again, and (when denied)
# milliseconds until a retry can succeed.
type Decision is Data:
  Decision{allowed: Bool, limit: Nat, remaining: Nat, reset_ms: Nat, retry_ms: Nat}

def ceil_div(a: Nat, +b: Nat) -> Nat:
  Nat.div(Nat.add(a, Nat.sub(b, 1n)), b)

def retry(+allowed: Bool, +wait: Nat) -> Nat:
  match allowed:
    case True{}: 0n
    case False{}: wait

def fixed_decision(+limit: Nat, +window_ms: Nat, now: Nat, step: FixedStep) -> Decision:
  FixedStep{+ok, Counter{+epoch, +count}} = step
  +reset = Nat.sub(Nat.mul(1n+epoch, window_ms), now)
  Decision{ok, limit, Nat.sub(limit, count), reset, retry(ok, reset)}

def bucket_decision(+capacity: Nat, +refill: Nat, +every_ms: Nat, step: BucketStep) -> Decision:
  BucketStep{+ok, Bucket{+level, at}} = step
  +full = full_level(capacity, every_ms)
  Decision{ok, capacity, Nat.div(level, every_ms), ceil_div(Nat.sub(full, level), refill), retry(ok, ceil_div(Nat.sub(every_ms, level), refill))}

# One stored entry. A mismatched kind (impossible through admit) starts fresh.
type Entry is Data:
  Win{window: Counter}
  Buck{bucket: Bucket}

def fresh(policy: Policy, +now: Nat) -> Entry:
  match policy:
    case FixedWindow{limit, +window_ms}: Win{Counter{Nat.div(now, window_ms), 0n}}
    case TokenBucket{capacity, refill, +every_ms}: Buck{Bucket{full_level(capacity, every_ms), now}}

def as_window(entry: Entry, +now: Nat, +window_ms: Nat) -> Counter:
  match entry:
    case Win{w}: w
    case Buck{b}: Counter{Nat.div(now, window_ms), 0n}

def as_bucket(entry: Entry, +now: Nat, +full: Nat) -> Bucket:
  match entry:
    case Buck{b}: b
    case Win{w}: Bucket{full, now}

type Outcome is Data:
  Outcome{decision: Decision, entry: Entry}

def fixed_outcome(+limit: Nat, +window_ms: Nat, +now: Nat, +step: FixedStep) -> Outcome:
  FixedStep{ok, w} = step
  Outcome{fixed_decision(limit, window_ms, now, step), Win{w}}

def bucket_outcome(+capacity: Nat, +refill: Nat, +every_ms: Nat, +step: BucketStep) -> Outcome:
  BucketStep{ok, b} = step
  Outcome{bucket_decision(capacity, refill, every_ms, step), Buck{b}}

def apply(policy: Policy, entry: Entry, +now: Nat) -> Outcome:
  match policy:
    case FixedWindow{+limit, +window_ms}: fixed_outcome(limit, window_ms, now, fixed_step(limit, window_ms, as_window(entry, now, window_ms), now))
    case TokenBucket{+capacity, +refill, +every_ms}: bucket_outcome(capacity, refill, every_ms, bucket_step(capacity, refill, every_ms, as_bucket(entry, now, full_level(capacity, every_ms)), now))

# An idle entry carries no state a fresh one lacks: a window before now's, or
# a bucket that has refilled to full. Sweeps drop idle entries.
def idle(policy: Policy, entry: Entry, +now: Nat) -> Bool:
  match policy entry:
    case FixedWindow{l, +window_ms} Win{Counter{epoch, c}}: Nat.is_lt(epoch, Nat.div(now, window_ms))
    case TokenBucket{capacity, +refill, +every_ms} Buck{Bucket{level, last}}:
      +full = full_level(capacity, every_ms)
      Nat.is_le(full, refilled(full, level, last, now, refill))
    case _ _: True{}

# How long until every entry seen now is idle: one window, or the time a
# bucket takes to refill from empty.
def horizon(policy: Policy) -> Nat:
  match policy:
    case FixedWindow{l, window_ms}: window_ms
    case TokenBucket{capacity, refill, +every_ms}: ceil_div(full_level(capacity, every_ms), refill)

# The key table. size counts entries; it never exceeds max_keys. When the
# table is full of live entries, new keys share the overflow entry until the
# next sweep frees room, so spraying keys can neither grow memory nor reset
# any tracked key's count. last is the decision for the latest request.
type Table is Data:
  Table{entries: Map<&2, Entry>, size: Nat, overflow: Entry, sweep_at: Nat, last: Decision}

def empty(policy: Policy) -> Table:
  Table{Map.new(&2, Entry), 0n, fresh(policy, 0n), 0n, Decision{True{}, 0n, 0n, 0n, 0n}}

def sweep_key(m: Map<&2, Entry>, +key: String, drop: Bool) -> Map<&2, Entry>:
  match drop:
    case True{}: Map.del(&2, Entry, m, key)
    case False{}: m

def sweep_at_key(+policy: Policy, +now: Nat, got: Map<&2, Entry> & Entry, +key: String) -> Map<&2, Entry>:
  (m, +entry) = got
  sweep_key(m, key, idle(policy, entry, now))

def sweep_go(+policy: Policy, +now: Nat, keys: List<&2, String>, m: Map<&2, Entry>) -> Map<&2, Entry>:
  match keys:
    case Nil{}: m
    case +k <> t: sweep_go(policy, now, t, sweep_at_key(policy, now, Map.get(Entry, fresh(policy, now), m, k), k))

# Drop every idle entry. Runs at most once per horizon, only when full.
def sweep(+policy: Policy, +now: Nat, +m: Map<&2, Entry>) -> Map<&2, Entry>:
  sweep_go(policy, now, Map.keys(&2, Entry, m), m)

def count(+m: Map<&2, Entry>) -> Nat:
  List.length(&2, String, Map.keys(&2, Entry, m))

def overflowed(m: Map<&2, Entry>, size: Nat, sweep_at: Nat, out: Outcome) -> Table:
  Outcome{decision, entry} = out
  Table{m, size, entry, sweep_at, decision}

def inserted(m: Map<&2, Entry>, +key: String, size: Nat, overflow: Entry, sweep_at: Nat, out: Outcome) -> Table:
  Outcome{decision, entry} = out
  Table{Map.set(&2, Entry, m, key, entry), 1n+size, overflow, sweep_at, decision}

def placed(+policy: Policy, +key: String, +now: Nat, m: Map<&2, Entry>, size: Nat, overflow: Entry, sweep_at: Nat, has_room: Bool) -> Table:
  match has_room:
    case True{}: inserted(m, key, size, overflow, sweep_at, apply(policy, fresh(policy, now), now))
    case False{}: overflowed(m, size, sweep_at, apply(policy, overflow, now))

def swept(+policy: Policy, +max_keys: Nat, +key: String, +now: Nat, +m: Map<&2, Entry>, overflow: Entry) -> Table:
  +size = count(m)
  placed(policy, key, now, m, size, overflow, Nat.add(now, horizon(policy)), Nat.is_lt(size, max_keys))

def full(+policy: Policy, +max_keys: Nat, +key: String, +now: Nat, m: Map<&2, Entry>, size: Nat, overflow: Entry, sweep_at: Nat, due: Bool) -> Table:
  match due:
    case True{}: swept(policy, max_keys, key, now, sweep(policy, now, m), overflow)
    case False{}: overflowed(m, size, sweep_at, apply(policy, overflow, now))

def stored(m: Map<&2, Entry>, +key: String, size: Nat, overflow: Entry, sweep_at: Nat, out: Outcome) -> Table:
  Outcome{decision, entry} = out
  Table{Map.set(&2, Entry, m, key, entry), size, overflow, sweep_at, decision}

def known(+policy: Policy, +key: String, +now: Nat, got: Map<&2, Entry> & Entry, size: Nat, overflow: Entry, sweep_at: Nat) -> Table:
  (m, entry) = got
  stored(m, key, size, overflow, sweep_at, apply(policy, entry, now))

def unknown(+policy: Policy, +max_keys: Nat, +key: String, +now: Nat, m: Map<&2, Entry>, +size: Nat, overflow: Entry, +sweep_at: Nat, has_room: Bool) -> Table:
  match has_room:
    case True{}: placed(policy, key, now, m, size, overflow, sweep_at, True{})
    case False{}: full(policy, max_keys, key, now, m, size, overflow, sweep_at, Nat.is_le(sweep_at, now))

def present(+policy: Policy, +max_keys: Nat, +key: String, +now: Nat, m: Map<&2, Entry>, has: Bool, +size: Nat, overflow: Entry, sweep_at: Nat) -> Table:
  match has:
    case True{}: known(policy, key, now, Map.get(Entry, fresh(policy, now), m, key), size, overflow, sweep_at)
    case False{}: unknown(policy, max_keys, key, now, m, size, overflow, sweep_at, Nat.is_lt(size, max_keys))

def lookup(+policy: Policy, +max_keys: Nat, +key: String, +now: Nat, got: Map<&2, Entry> & Bool, size: Nat, overflow: Entry, sweep_at: Nat) -> Table:
  (m, has) = got
  present(policy, max_keys, key, now, m, has, size, overflow, sweep_at)

# Count one request from key at time now. The result's last field is its
# decision. Apply it inside one store update so requests never interleave.
def admit(+policy: Policy, +max_keys: Nat, +key: String, +now: Nat, table: Table) -> Table:
  Table{entries, size, overflow, sweep_at, last} = table
  lookup(policy, max_keys, key, now, Map.has(&2, Entry, entries, key), size, overflow, sweep_at)

def decision(table: Table) -> Decision:
  Table{e, s, o, w, last} = table
  last

def size(table: Table) -> Nat:
  Table{e, s, o, w, last} = table
  s

# Policies clamp zero parameters to 1, so no division is by zero.
def fixed_window_policy(limit: Nat, window_ms: Nat) -> Policy:
  FixedWindow{limit, Nat.max(1n, window_ms)}

def token_bucket_policy(capacity: Nat, refill: Nat, every_ms: Nat) -> Policy:
  TokenBucket{capacity, Nat.max(1n, refill), Nat.max(1n, every_ms)}
