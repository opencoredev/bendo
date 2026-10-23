# BND-44: fixed-window decisions and token-bucket invariants.
import Base
import ../src/mw/rate_limit_core.bend as R
import ./rate-limit-spec.bend as Spec

# Fixed window. A request in the counter's window (or an earlier one, which
# reached the store late) is allowed exactly when fewer than limit requests
# were counted; an allowed request is counted, a denied one is not.
law rate_fixed_allow:
  for +limit: Nat
  for +window_ms: Nat
  for +epoch: Nat
  for +count: Nat
  for +now: Nat
  for same: {Nat.is_le(Nat.div(now, window_ms), epoch) == True{} : Bool}
  for under: {Nat.is_lt(count, limit) == True{} : Bool}
  {R.fixed_step(limit, window_ms, R.Counter{epoch, count}, now) == R.FixedStep{True{}, R.Counter{epoch, 1n+count}} : R.FixedStep}

law rate_fixed_deny:
  for +limit: Nat
  for +window_ms: Nat
  for +epoch: Nat
  for +count: Nat
  for +now: Nat
  for same: {Nat.is_le(Nat.div(now, window_ms), epoch) == True{} : Bool}
  for over: {Nat.is_lt(count, limit) == False{} : Bool}
  {R.fixed_step(limit, window_ms, R.Counter{epoch, count}, now) == R.FixedStep{False{}, R.Counter{epoch, count}} : R.FixedStep}

# A later window starts from zero.
law rate_fixed_new_window:
  for +l: Nat
  for +window_ms: Nat
  for +epoch: Nat
  for +count: Nat
  for +now: Nat
  for later: {Nat.is_le(Nat.div(now, window_ms), epoch) == False{} : Bool}
  {R.fixed_step(1n+l, window_ms, R.Counter{epoch, count}, now) == R.FixedStep{True{}, R.Counter{Nat.div(now, window_ms), 1n}} : R.FixedStep}

# A zero limit refuses every request.
law rate_fixed_zero_limit:
  for +window_ms: Nat
  for +counter: R.Counter
  for +now: Nat
  {Spec.allowed(R.fixed_step(0n, window_ms, counter, now)) == False{} : Bool}

# Any run of requests within one window from a counter at count: the first
# limit - count are allowed and every later one is denied. With count 0 and
# limit 100, request 101 is the first refused.
law rate_fixed_quota:
  for +limit: Nat
  for +window_ms: Nat
  for +epoch: Nat
  for +count: Nat
  for +times: List<&2, Nat>
  for inside: {Spec.within(window_ms, epoch, times) == True{} : Bool}
  {Spec.run(limit, window_ms, times, R.Counter{epoch, count}) == Spec.expected(List.length(&2, Nat, times), Nat.sub(limit, count)) : List<&2, Bool>}

# Token bucket. The level never exceeds the full level (capacity tokens),
# for every input, including a stored level above it.
law rate_bucket_capacity:
  for +capacity: Nat
  for +refill: Nat
  for +every_ms: Nat
  for +level: Nat
  for +last: Nat
  for +now: Nat
  {Nat.is_le(Spec.level(R.bucket_step(capacity, refill, every_ms, R.Bucket{level, last}, now)), R.full_level(capacity, every_ms)) == True{} : Bool}

# With at least one token after refilling, the request is allowed and takes
# exactly one token; otherwise it is denied and takes nothing.
law rate_bucket_allow:
  for +capacity: Nat
  for +refill: Nat
  for +every_ms: Nat
  for +level: Nat
  for +last: Nat
  for +now: Nat
  for enough: {Nat.is_le(every_ms, Spec.refill(R.full_level(capacity, every_ms), level, last, now, refill)) == True{} : Bool}
  {R.bucket_step(capacity, refill, every_ms, R.Bucket{level, last}, now) == R.BucketStep{True{}, R.Bucket{Nat.sub(Spec.refill(R.full_level(capacity, every_ms), level, last, now, refill), every_ms), Nat.max(last, now)}} : R.BucketStep}

law rate_bucket_conserve:
  for +capacity: Nat
  for +refill: Nat
  for +every_ms: Nat
  for +level: Nat
  for +last: Nat
  for +now: Nat
  for enough: {Nat.is_le(every_ms, Spec.refill(R.full_level(capacity, every_ms), level, last, now, refill)) == True{} : Bool}
  {Nat.add(Spec.level(R.bucket_step(capacity, refill, every_ms, R.Bucket{level, last}, now)), every_ms) == Spec.refill(R.full_level(capacity, every_ms), level, last, now, refill) : Nat}

law rate_bucket_deny:
  for +capacity: Nat
  for +refill: Nat
  for +every_ms: Nat
  for +level: Nat
  for +last: Nat
  for +now: Nat
  for short: {Nat.is_le(every_ms, Spec.refill(R.full_level(capacity, every_ms), level, last, now, refill)) == False{} : Bool}
  {R.bucket_step(capacity, refill, every_ms, R.Bucket{level, last}, now) == R.BucketStep{False{}, R.Bucket{Spec.refill(R.full_level(capacity, every_ms), level, last, now, refill), Nat.max(last, now)}} : R.BucketStep}
