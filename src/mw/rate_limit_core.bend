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

# What a request from a new key gets while the table is full of live entries
# and no sweep is due.
# AllowUntracked (default): it passes uncounted, so spraying keys can never
#   deny a new client. Tracked keys keep their quotas.
# SharedQuota: new keys share one overflow entry with the same policy. This
#   fails closed: a flood of new keys can exhaust it and deny every new client.
# EvictOldest: the least recently used key is dropped and the new key takes
#   its place. Nothing goes uncounted, but under churn an evicted key's quota
#   starts over the next time it is seen.
type Saturation is Data:
  AllowUntracked{}
  SharedQuota{}
  EvictOldest{}

# A stored entry and the number of the request that last touched it.
type Slot is Data:
  Slot{entry: Entry, stamp: Nat}

# Recency order for EvictOldest: (key, stamp) pairs, oldest first in front,
# newest first in back. A pair is current while its key's slot has the same
# stamp; stale pairs are skipped on eviction and dropped on compaction.
type Recent is Data:
  Recent{key: String, stamp: Nat}

type Recency is Data:
  Recency{front: List<&2, Recent>, back: List<&2, Recent>, length: Nat}

# Requests that met a full table, whether the table is saturated now, and
# whether the latest request started that episode.
type Pressure is Data:
  Pressure{count: Nat, active: Bool, began: Bool}

# How the latest request was handled: counted against a tracked key (or the
# shared overflow entry), or let through uncounted.
type Verdict is Data:
  Counted{decision: Decision}
  Untracked{}

type Book is Data:
  Book{size: Nat, overflow: Entry, sweep_at: Nat, tick: Nat, recency: Recency, pressure: Pressure}

# The key table. size counts entries; it never exceeds max_keys. last is the
# verdict for the latest request.
type Table is Data:
  Table{entries: Map<&2, Slot>, book: Book, last: Verdict}

type Stats is Data:
  Stats{tracked: Nat, saturated: Nat, saturating: Bool}

def empty(policy: Policy) -> Table:
  Table{Map.new(&2, Slot), Book{0n, fresh(policy, 0n), 0n, 0n, Recency{[], [], 0n}, Pressure{0n, False{}, False{}}}, Counted{Decision{True{}, 0n, 0n, 0n, 0n}}}

def blank_slot() -> Slot:
  Slot{Win{Counter{0n, 0n}}, 0n}

def slot_entry(slot: Slot) -> Entry:
  Slot{e, s} = slot
  e

def quiet(p: Pressure) -> Pressure:
  Pressure{count, active, began} = p
  Pressure{count, active, False{}}

def calm(p: Pressure) -> Pressure:
  Pressure{count, active, began} = p
  Pressure{count, False{}, False{}}

def press(p: Pressure) -> Pressure:
  Pressure{count, +active, began} = p
  Pressure{1n+count, True{}, Bool.not(active)}

# Whether key's slot still has stamp s.
def stamp_is(+s: Nat, got: Map<&2, Slot> & Slot) -> Map<&2, Slot> & Bool:
  (m, slot) = got
  Slot{e, t} = slot
  (m, Nat.is_eq(t, s))

def current_pick(+key: String, +s: Nat, m: Map<&2, Slot>, has: Bool) -> Map<&2, Slot> & Bool:
  match has:
    case True{}: stamp_is(s, Map.get(Slot, blank_slot(), m, key))
    case False{}: (m, False{})

def current_has(+key: String, +s: Nat, got: Map<&2, Slot> & Bool) -> Map<&2, Slot> & Bool:
  (m, has) = got
  current_pick(key, s, m, has)

def current(+key: String, +s: Nat, m: Map<&2, Slot>) -> Map<&2, Slot> & Bool:
  current_has(key, s, Map.has(&2, Slot, m, key))

# Compaction keeps the current pairs only, in order, newest first.
type Compact is Data:
  Compact{todo: List<&2, Recent>, kept: List<&2, Recent>, count: Nat, m: Map<&2, Slot>}

def compact_keep(t: List<&2, Recent>, r: Recent, kept: List<&2, Recent>, count: Nat, m: Map<&2, Slot>, ok: Bool) -> Compact:
  match ok:
    case True{}: Compact{t, r <> kept, 1n+count, m}
    case False{}: Compact{t, kept, count, m}

def compact_put(t: List<&2, Recent>, r: Recent, kept: List<&2, Recent>, count: Nat, got: Map<&2, Slot> & Bool) -> Compact:
  (m, ok) = got
  compact_keep(t, r, kept, count, m, ok)

def compact_step(c: Compact) -> Compact:
  match c:
    case Compact{Nil{}, kept, n, m}: Compact{[], kept, n, m}
    case Compact{Recent{+k, +s} <> t, kept, n, m}: compact_put(t, Recent{k, s}, kept, n, current(k, s, m))

def compact_run(fuel: Nat, c: Compact) -> Compact:
  match fuel:
    case 0n: c
    case 1n+f: compact_run(f, compact_step(c))

def compacted(c: Compact) -> Map<&2, Slot> & Recency:
  Compact{t, kept, n, m} = c
  (m, Recency{[], kept, n})

def compact(m: Map<&2, Slot>, recency: Recency) -> Map<&2, Slot> & Recency:
  Recency{front, back, +length} = recency
  compacted(compact_run(1n+length, Compact{List.concat(&2, Recent, [front, List.reverse(&2, Recent, back)]), [], 0n, m}))

def compact_when(m: Map<&2, Slot>, recency: Recency, due: Bool) -> Map<&2, Slot> & Recency:
  match due:
    case True{}: compact(m, recency)
    case False{}: (m, recency)

# The queue grows by one pair per request; once it holds more than twice
# max_keys pairs, compaction brings it back to at most max_keys.
def pushed(+max_keys: Nat, m: Map<&2, Slot>, recency: Recency, r: Recent) -> Map<&2, Slot> & Recency:
  Recency{front, back, +length} = recency
  compact_when(m, Recency{front, r <> back, 1n+length}, Nat.is_lt(Nat.add(Nat.add(max_keys, max_keys), 1n), length))

def touch(mode: Saturation, +max_keys: Nat, key: String, stamp: Nat, m: Map<&2, Slot>, recency: Recency) -> Map<&2, Slot> & Recency:
  match mode:
    case EvictOldest{}: pushed(max_keys, m, recency, Recent{key, stamp})
    case AllowUntracked{}: (m, recency)
    case SharedQuota{}: (m, recency)

# Eviction pops pairs from the front until one is current.
type Seek is Data:
  Seeking{front: List<&2, Recent>, back: List<&2, Recent>, length: Nat, m: Map<&2, Slot>}
  Found{key: String, front: List<&2, Recent>, back: List<&2, Recent>, length: Nat, m: Map<&2, Slot>}
  Exhausted{m: Map<&2, Slot>}

def seek_pick(k: String, t: List<&2, Recent>, back: List<&2, Recent>, length: Nat, m: Map<&2, Slot>, ok: Bool) -> Seek:
  match ok:
    case True{}: Found{k, t, back, length, m}
    case False{}: Seeking{t, back, length, m}

def seek_hit(k: String, t: List<&2, Recent>, back: List<&2, Recent>, length: Nat, got: Map<&2, Slot> & Bool) -> Seek:
  (m, ok) = got
  seek_pick(k, t, back, length, m, ok)

def seek_step(front: List<&2, Recent>, back: List<&2, Recent>, length: Nat, m: Map<&2, Slot>) -> Seek:
  match front back:
    case Nil{} Nil{}: Exhausted{m}
    case Nil{} h <> t: Seeking{List.reverse(&2, Recent, h <> t), [], length, m}
    case Recent{+k, +st} <> t back: seek_hit(k, t, back, Nat.sub(length, 1n), current(k, st, m))

# Fuel only bounds the search; it stops at the first current pair, so a pop
# costs the stale pairs it skips, not the table size.
def seek_run(fuel: Nat, s: Seek) -> Seek:
  match fuel s:
    case 0n s: s
    case 1n+f Seeking{front, back, length, m}: seek_run(f, seek_step(front, back, length, m))
    case 1n+f Found{k, front, back, length, m}: Found{k, front, back, length, m}
    case 1n+f Exhausted{m}: Exhausted{m}

def sweep_key(m: Map<&2, Slot>, +key: String, drop: Bool) -> Map<&2, Slot>:
  match drop:
    case True{}: Map.del(&2, Slot, m, key)
    case False{}: m

def sweep_at_key(+policy: Policy, +now: Nat, got: Map<&2, Slot> & Slot, +key: String) -> Map<&2, Slot>:
  (m, slot) = got
  sweep_key(m, key, idle(policy, slot_entry(slot), now))

def sweep_go(+policy: Policy, +now: Nat, keys: List<&2, String>, m: Map<&2, Slot>) -> Map<&2, Slot>:
  match keys:
    case Nil{}: m
    case +k <> t: sweep_go(policy, now, t, sweep_at_key(policy, now, Map.get(Slot, blank_slot(), m, k), k))

# Drop every idle entry. Runs at most once per horizon, only when full.
def sweep(+policy: Policy, +now: Nat, +m: Map<&2, Slot>) -> Map<&2, Slot>:
  sweep_go(policy, now, Map.keys(&2, Slot, m), m)

def count(+m: Map<&2, Slot>) -> Nat:
  List.length(&2, String, Map.keys(&2, Slot, m))

def finish(got: Map<&2, Slot> & Recency, size: Nat, overflow: Entry, sweep_at: Nat, tick: Nat, pressure: Pressure, last: Verdict) -> Table:
  (m, recency) = got
  Table{m, Book{size, overflow, sweep_at, 1n+tick, recency, pressure}, last}

def keep(m: Map<&2, Slot>, size: Nat, overflow: Entry, sweep_at: Nat, tick: Nat, recency: Recency, pressure: Pressure, last: Verdict) -> Table:
  Table{m, Book{size, overflow, sweep_at, 1n+tick, recency, pressure}, last}

# Store out's entry under key, stamped with this request's number.
def stored(mode: Saturation, +max_keys: Nat, +key: String, m: Map<&2, Slot>, size: Nat, overflow: Entry, sweep_at: Nat, +tick: Nat, recency: Recency, pressure: Pressure, out: Outcome) -> Table:
  Outcome{decision, entry} = out
  finish(touch(mode, max_keys, key, tick, Map.set(&2, Slot, m, key, Slot{entry, tick}), recency), size, overflow, sweep_at, tick, pressure, Counted{decision})

def known(+policy: Policy, mode: Saturation, +max_keys: Nat, +key: String, +now: Nat, got: Map<&2, Slot> & Slot, size: Nat, overflow: Entry, sweep_at: Nat, tick: Nat, recency: Recency, pressure: Pressure) -> Table:
  (m, slot) = got
  stored(mode, max_keys, key, m, size, overflow, sweep_at, tick, recency, pressure, apply(policy, slot_entry(slot), now))

def insert(+policy: Policy, mode: Saturation, +max_keys: Nat, +key: String, +now: Nat, m: Map<&2, Slot>, size: Nat, overflow: Entry, sweep_at: Nat, tick: Nat, recency: Recency, pressure: Pressure) -> Table:
  stored(mode, max_keys, key, m, 1n+size, overflow, sweep_at, tick, recency, pressure, apply(policy, fresh(policy, now), now))

def untracked(m: Map<&2, Slot>, size: Nat, overflow: Entry, sweep_at: Nat, tick: Nat, recency: Recency, pressure: Pressure) -> Table:
  keep(m, size, overflow, sweep_at, tick, recency, press(pressure), Untracked{})

def shared(m: Map<&2, Slot>, size: Nat, sweep_at: Nat, tick: Nat, recency: Recency, pressure: Pressure, out: Outcome) -> Table:
  Outcome{decision, entry} = out
  keep(m, size, entry, sweep_at, tick, recency, press(pressure), Counted{decision})

def evicted(+policy: Policy, +max_keys: Nat, +key: String, +now: Nat, s: Seek, size: Nat, overflow: Entry, sweep_at: Nat, tick: Nat, pressure: Pressure) -> Table:
  match s:
    case Found{victim, front, back, length, m}: insert(policy, EvictOldest{}, max_keys, key, now, Map.del(&2, Slot, m, victim), Nat.sub(size, 1n), overflow, sweep_at, tick, Recency{front, back, length}, press(pressure))
    case Seeking{front, back, length, m}: untracked(m, size, overflow, sweep_at, tick, Recency{front, back, length}, pressure)
    case Exhausted{m}: untracked(m, size, overflow, sweep_at, tick, Recency{[], [], 0n}, pressure)

def evict(+policy: Policy, +max_keys: Nat, +key: String, +now: Nat, m: Map<&2, Slot>, size: Nat, overflow: Entry, sweep_at: Nat, tick: Nat, recency: Recency, pressure: Pressure) -> Table:
  Recency{front, back, +length} = recency
  evicted(policy, max_keys, key, now, seek_run(Nat.add(Nat.add(length, length), 2n), Seeking{front, back, length, m}), size, overflow, sweep_at, tick, pressure)

def saturated(+policy: Policy, mode: Saturation, +max_keys: Nat, +key: String, +now: Nat, m: Map<&2, Slot>, size: Nat, overflow: Entry, sweep_at: Nat, tick: Nat, recency: Recency, pressure: Pressure) -> Table:
  match mode:
    case AllowUntracked{}: untracked(m, size, overflow, sweep_at, tick, recency, pressure)
    case SharedQuota{}: shared(m, size, sweep_at, tick, recency, pressure, apply(policy, overflow, now))
    case EvictOldest{}: evict(policy, max_keys, key, now, m, size, overflow, sweep_at, tick, recency, pressure)

def placed(+policy: Policy, mode: Saturation, +max_keys: Nat, +key: String, +now: Nat, m: Map<&2, Slot>, size: Nat, overflow: Entry, sweep_at: Nat, tick: Nat, recency: Recency, pressure: Pressure, has_room: Bool) -> Table:
  match has_room:
    case True{}: insert(policy, mode, max_keys, key, now, m, size, overflow, sweep_at, tick, recency, calm(pressure))
    case False{}: saturated(policy, mode, max_keys, key, now, m, size, overflow, sweep_at, tick, recency, pressure)

def swept(+policy: Policy, mode: Saturation, +max_keys: Nat, +key: String, +now: Nat, +m: Map<&2, Slot>, overflow: Entry, tick: Nat, recency: Recency, pressure: Pressure) -> Table:
  +size = count(m)
  placed(policy, mode, max_keys, key, now, m, size, overflow, Nat.add(now, horizon(policy)), tick, recency, pressure, Nat.is_lt(size, max_keys))

def full(+policy: Policy, mode: Saturation, +max_keys: Nat, +key: String, +now: Nat, m: Map<&2, Slot>, size: Nat, overflow: Entry, sweep_at: Nat, tick: Nat, recency: Recency, pressure: Pressure, due: Bool) -> Table:
  match due:
    case True{}: swept(policy, mode, max_keys, key, now, sweep(policy, now, m), overflow, tick, recency, pressure)
    case False{}: saturated(policy, mode, max_keys, key, now, m, size, overflow, sweep_at, tick, recency, pressure)

def unknown(+policy: Policy, mode: Saturation, +max_keys: Nat, +key: String, +now: Nat, m: Map<&2, Slot>, size: Nat, overflow: Entry, +sweep_at: Nat, tick: Nat, recency: Recency, pressure: Pressure, has_room: Bool) -> Table:
  match has_room:
    case True{}: insert(policy, mode, max_keys, key, now, m, size, overflow, sweep_at, tick, recency, calm(pressure))
    case False{}: full(policy, mode, max_keys, key, now, m, size, overflow, sweep_at, tick, recency, pressure, Nat.is_le(sweep_at, now))

def present(+policy: Policy, mode: Saturation, +max_keys: Nat, +key: String, +now: Nat, m: Map<&2, Slot>, has: Bool, +size: Nat, overflow: Entry, sweep_at: Nat, tick: Nat, recency: Recency, pressure: Pressure) -> Table:
  match has:
    case True{}: known(policy, mode, max_keys, key, now, Map.get(Slot, blank_slot(), m, key), size, overflow, sweep_at, tick, recency, pressure)
    case False{}: unknown(policy, mode, max_keys, key, now, m, size, overflow, sweep_at, tick, recency, pressure, Nat.is_lt(size, max_keys))

def lookup(+policy: Policy, mode: Saturation, +max_keys: Nat, +key: String, +now: Nat, got: Map<&2, Slot> & Bool, book: Book) -> Table:
  (m, has) = got
  Book{size, overflow, sweep_at, tick, recency, pressure} = book
  present(policy, mode, max_keys, key, now, m, has, size, overflow, sweep_at, tick, recency, quiet(pressure))

# Count one request from key at time now. The result's last field is its
# verdict. Apply it inside one store update so requests never interleave.
def admit(+policy: Policy, mode: Saturation, +max_keys: Nat, +key: String, +now: Nat, table: Table) -> Table:
  Table{entries, book, last} = table
  lookup(policy, mode, max_keys, key, now, Map.has(&2, Slot, entries, key), book)

# The latest verdict, and whether that request started a saturation episode.
def outcome(table: Table) -> Verdict & Bool:
  Table{e, Book{s, o, w, t, r, Pressure{n, a, began}}, last} = table
  (last, began)

def stats(table: Table) -> Stats:
  Table{e, Book{s, o, w, t, r, Pressure{n, a, b}}, last} = table
  Stats{s, n, a}

# Policies clamp zero parameters to 1, so no division is by zero.
def fixed_window_policy(limit: Nat, window_ms: Nat) -> Policy:
  FixedWindow{limit, Nat.max(1n, window_ms)}

def token_bucket_policy(capacity: Nat, refill: Nat, every_ms: Nat) -> Policy:
  TokenBucket{capacity, Nat.max(1n, refill), Nat.max(1n, every_ms)}
