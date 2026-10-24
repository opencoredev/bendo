# BND-44: independent specifications for the rate limiting steps.
import Base
import ../src/mw/rate_limit_core.bend as R

def cap_pick(full: Nat, gained: Nat, over: Bool) -> Nat:
  match over:
    case True{}: full
    case False{}: gained

# The bucket level after refilling: the old level plus elapsed * rate,
# or the full level when that would exceed it.
def refill(+full: Nat, level: Nat, last: Nat, now: Nat, rate: Nat) -> Nat:
  +gained = Nat.add(level, Nat.mul(Nat.sub(now, last), rate))
  cap_pick(full, gained, Nat.is_le(full, gained))

def level(step: R.BucketStep) -> Nat:
  match step:
    case R.BucketStep{ok, R.Bucket{l, t}}: l

def allowed(step: R.FixedStep) -> Bool:
  match step:
    case R.FixedStep{ok, w}: ok

def entry(step: R.FixedStep) -> R.Counter:
  match step:
    case R.FixedStep{ok, w}: w

# The fixed-window answers for a run of requests at the given times.
def run(+limit: Nat, +window_ms: Nat, times: List<&2, Nat>, +counter: R.Counter) -> List<&2, Bool>:
  match times:
    case Nil{}: []
    case +t <> ts: allowed(R.fixed_step(limit, window_ms, counter, t)) <> run(limit, window_ms, ts, entry(R.fixed_step(limit, window_ms, counter, t)))

# k answers when budget requests remain: budget yeses, then noes.
def expected(k: Nat, budget: Nat) -> List<&2, Bool>:
  match k budget:
    case 0n _: []
    case 1n+j 0n: False{} <> expected(j, 0n)
    case 1n+j 1n+b: True{} <> expected(j, b)

# Every time falls in the window numbered epoch or an earlier one.
def within(+window_ms: Nat, +epoch: Nat, times: List<&2, Nat>) -> Bool:
  match times:
    case Nil{}: True{}
    case t <> ts: Nat.is_le(Nat.div(t, window_ms), epoch) && within(window_ms, epoch, ts)
