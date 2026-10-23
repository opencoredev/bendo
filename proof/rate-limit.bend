# BND-44: proofs of the fixed-window and token-bucket laws.
import Base
import ../src/mw/rate_limit_core.bend as R
import ./rate-limit-spec.bend as Spec
import ./rate-limit-laws.bend as Laws

def absurd(-A: Type, e: Empty) -> A:
  match e:

def false_true(e: {False{} == True{} : Bool}) -> Empty:
  %e : Bool.pick(Type, _, Empty, Unit)
  Unit{}

def zero_disc(n: Nat) -> Type:
  match n:
    case 0n: Empty
    case 1n+p: Unit

def succ_zero(+b: Nat, e: {1n+b == 0n : Nat}) -> Empty:
  %e : zero_disc(_)
  Unit{}

def pred(n: Nat) -> Nat:
  match n:
    case 0n: 0n
    case 1n+p: p

def succ_inj(+a: Nat, +b: Nat, e: {1n+a == 1n+b : Nat}) -> {a == b : Nat}:
  Equal.cong(Nat, Nat, n => pred(n), 1n+a, 1n+b, e)

# Fixed window.
def fixed_allow(+limit: Nat, +window_ms: Nat, +epoch: Nat, +count: Nat, +now: Nat, same: {Nat.is_le(Nat.div(now, window_ms), epoch) == True{} : Bool}, under: {Nat.is_lt(count, limit) == True{} : Bool}) -> {R.fixed_step(limit, window_ms, R.Counter{epoch, count}, now) == R.FixedStep{True{}, R.Counter{epoch, 1n+count}} : R.FixedStep}:
  %Equal.sym(Bool, Nat.is_le(Nat.div(now, window_ms), epoch), True{}, same) : {R.fixed_window(limit, R.Counter{epoch, count}, Nat.div(now, window_ms), _) == R.FixedStep{True{}, R.Counter{epoch, 1n+count}} : R.FixedStep}
  %Equal.sym(Bool, Nat.is_lt(count, limit), True{}, under) : {R.fixed_pick(epoch, count, _) == R.FixedStep{True{}, R.Counter{epoch, 1n+count}} : R.FixedStep}
  {==}

def fixed_deny(+limit: Nat, +window_ms: Nat, +epoch: Nat, +count: Nat, +now: Nat, same: {Nat.is_le(Nat.div(now, window_ms), epoch) == True{} : Bool}, over: {Nat.is_lt(count, limit) == False{} : Bool}) -> {R.fixed_step(limit, window_ms, R.Counter{epoch, count}, now) == R.FixedStep{False{}, R.Counter{epoch, count}} : R.FixedStep}:
  %Equal.sym(Bool, Nat.is_le(Nat.div(now, window_ms), epoch), True{}, same) : {R.fixed_window(limit, R.Counter{epoch, count}, Nat.div(now, window_ms), _) == R.FixedStep{False{}, R.Counter{epoch, count}} : R.FixedStep}
  %Equal.sym(Bool, Nat.is_lt(count, limit), False{}, over) : {R.fixed_pick(epoch, count, _) == R.FixedStep{False{}, R.Counter{epoch, count}} : R.FixedStep}
  {==}

def fixed_new(+l: Nat, +window_ms: Nat, +epoch: Nat, +count: Nat, +now: Nat, later: {Nat.is_le(Nat.div(now, window_ms), epoch) == False{} : Bool}) -> {R.fixed_step(1n+l, window_ms, R.Counter{epoch, count}, now) == R.FixedStep{True{}, R.Counter{Nat.div(now, window_ms), 1n}} : R.FixedStep}:
  %Equal.sym(Bool, Nat.is_le(Nat.div(now, window_ms), epoch), False{}, later) : {R.fixed_window(1n+l, R.Counter{epoch, count}, Nat.div(now, window_ms), _) == R.FixedStep{True{}, R.Counter{Nat.div(now, window_ms), 1n}} : R.FixedStep}
  {==}

def lt_zero(+n: Nat) -> {Nat.is_lt(n, 0n) == False{} : Bool}:
  match n:
    case 0n: {==}
    case 1n+p: {==}

def count_zero(+limit_window: Nat, +current: Nat, +counter: R.Counter, +same: Bool) -> {Spec.allowed(R.fixed_window(0n, counter, current, same)) == False{} : Bool}:
  match counter same:
    case R.Counter{e, c} True{}:
      %Equal.sym(Bool, Nat.is_lt(c, 0n), False{}, lt_zero(c)) : {Spec.allowed(R.fixed_pick(e, c, _)) == False{} : Bool}
      {==}
    case R.Counter{e, c} False{}: {==}

def fixed_zero(+window_ms: Nat, +counter: R.Counter, +now: Nat) -> {Spec.allowed(R.fixed_step(0n, window_ms, counter, now)) == False{} : Bool}:
  match counter:
    case R.Counter{+e, +c}: count_zero(window_ms, Nat.div(now, window_ms), R.Counter{e, c}, Nat.is_le(Nat.div(now, window_ms), e))

def and_left(+a: Bool, -b: Bool, e: {(a && b) == True{} : Bool}) -> {a == True{} : Bool}:
  match a:
    case True{}: {==}
    case False{}: e

def and_right(+a: Bool, -b: Bool, e: {(a && b) == True{} : Bool}) -> {b == True{} : Bool}:
  match a:
    case True{}: e
    case False{}: absurd({b == True{} : Bool}, false_true(e))

def sub_zero_r(+l: Nat) -> {Nat.sub(l, 0n) == l : Nat}:
  match l:
    case 0n: {==}
    case 1n+p: {==}

def sub_succ_lt(+limit: Nat, +c: Nat, +b: Nat, e: {Nat.sub(limit, c) == 1n+b : Nat}) -> {Nat.is_lt(c, limit) == True{} : Bool}:
  match limit c:
    case 0n _: absurd({Nat.is_lt(c, 0n) == True{} : Bool}, succ_zero(b, Equal.sym(Nat, 0n, 1n+b, e)))
    case 1n+l 0n: {==}
    case 1n+l 1n+k: sub_succ_lt(l, k, b, e)

def sub_succ_next(+limit: Nat, +c: Nat, +b: Nat, e: {Nat.sub(limit, c) == 1n+b : Nat}) -> {Nat.sub(limit, 1n+c) == b : Nat}:
  match limit c:
    case 0n _: absurd({Nat.sub(0n, 1n+c) == b : Nat}, succ_zero(b, Equal.sym(Nat, 0n, 1n+b, e)))
    case 1n+l 0n: Equal.trans(Nat, Nat.sub(l, 0n), l, b, sub_zero_r(l), succ_inj(l, b, e))
    case 1n+l 1n+k: sub_succ_next(l, k, b, e)

def sub_zero_ge(+limit: Nat, +c: Nat, e: {Nat.sub(limit, c) == 0n : Nat}) -> {Nat.is_lt(c, limit) == False{} : Bool}:
  match limit c:
    case 0n _: lt_zero(c)
    case 1n+l 0n: absurd({Nat.is_lt(0n, 1n+l) == False{} : Bool}, succ_zero(l, e))
    case 1n+l 1n+k: sub_zero_ge(l, k, e)

def quota_go(+limit: Nat, +window_ms: Nat, +epoch: Nat, +times: List<&2, Nat>, +count: Nat, +m: Nat, +em: {Nat.sub(limit, count) == m : Nat}, +inside: {Spec.within(window_ms, epoch, times) == True{} : Bool}) -> {Spec.run(limit, window_ms, times, R.Counter{epoch, count}) == Spec.expected(List.length(&2, Nat, times), m) : List<&2, Bool>}:
  match times:
    case Nil{}: {==}
    case +t <> +ts:
      match m:
        case 0n:
          %Equal.sym(R.FixedStep, R.fixed_step(limit, window_ms, R.Counter{epoch, count}, t), R.FixedStep{False{}, R.Counter{epoch, count}}, fixed_deny(limit, window_ms, epoch, count, t, and_left(Nat.is_le(Nat.div(t, window_ms), epoch), Spec.within(window_ms, epoch, ts), inside), sub_zero_ge(limit, count, em))) : {Spec.allowed(_) <> Spec.run(limit, window_ms, ts, Spec.entry(_)) == Spec.expected(1n+List.length(&2, Nat, ts), 0n) : List<&2, Bool>}
          Equal.cong(List<&2, Bool>, List<&2, Bool>, xs => False{} <> xs, Spec.run(limit, window_ms, ts, R.Counter{epoch, count}), Spec.expected(List.length(&2, Nat, ts), 0n), quota_go(limit, window_ms, epoch, ts, count, 0n, em, and_right(Nat.is_le(Nat.div(t, window_ms), epoch), Spec.within(window_ms, epoch, ts), inside)))
        case 1n+b:
          %Equal.sym(R.FixedStep, R.fixed_step(limit, window_ms, R.Counter{epoch, count}, t), R.FixedStep{True{}, R.Counter{epoch, 1n+count}}, fixed_allow(limit, window_ms, epoch, count, t, and_left(Nat.is_le(Nat.div(t, window_ms), epoch), Spec.within(window_ms, epoch, ts), inside), sub_succ_lt(limit, count, b, em))) : {Spec.allowed(_) <> Spec.run(limit, window_ms, ts, Spec.entry(_)) == Spec.expected(1n+List.length(&2, Nat, ts), 1n+b) : List<&2, Bool>}
          Equal.cong(List<&2, Bool>, List<&2, Bool>, xs => True{} <> xs, Spec.run(limit, window_ms, ts, R.Counter{epoch, 1n+count}), Spec.expected(List.length(&2, Nat, ts), b), quota_go(limit, window_ms, epoch, ts, 1n+count, b, sub_succ_next(limit, count, b, em), and_right(Nat.is_le(Nat.div(t, window_ms), epoch), Spec.within(window_ms, epoch, ts), inside)))

def fixed_quota(+limit: Nat, +window_ms: Nat, +epoch: Nat, +count: Nat, +times: List<&2, Nat>, inside: {Spec.within(window_ms, epoch, times) == True{} : Bool}) -> {Spec.run(limit, window_ms, times, R.Counter{epoch, count}) == Spec.expected(List.length(&2, Nat, times), Nat.sub(limit, count)) : List<&2, Bool>}:
  quota_go(limit, window_ms, epoch, times, count, Nat.sub(limit, count), {==}, inside)

# Token bucket.
def pick_succ(+a: Nat, +b: Nat, +x: Bool) -> {1n+Spec.cap_pick(a, b, x) == Spec.cap_pick(1n+a, 1n+b, x) : Nat}:
  match x:
    case True{}: {==}
    case False{}: {==}

def min_spec(+a: Nat, +b: Nat) -> {Nat.min(a, b) == Spec.cap_pick(a, b, Nat.is_le(a, b)) : Nat}:
  match a b:
    case 0n 0n: {==}
    case 0n 1n+q: {==}
    case 1n+p 0n: {==}
    case 1n+p 1n+q:
      %Equal.sym(Nat, Nat.min(p, q), Spec.cap_pick(p, q, Nat.is_le(p, q)), min_spec(p, q)) : {1n+_ == Spec.cap_pick(1n+p, 1n+q, Nat.is_le(p, q)) : Nat}
      pick_succ(p, q, Nat.is_le(p, q))

def refilled_spec(+full: Nat, +level: Nat, +last: Nat, +now: Nat, +rate: Nat) -> {R.refilled(full, level, last, now, rate) == Spec.refill(full, level, last, now, rate) : Nat}:
  min_spec(full, Nat.add(level, Nat.mul(Nat.sub(now, last), rate)))

def bucket_allow(+capacity: Nat, +refill: Nat, +every_ms: Nat, +level: Nat, +last: Nat, +now: Nat, enough: {Nat.is_le(every_ms, Spec.refill(R.full_level(capacity, every_ms), level, last, now, refill)) == True{} : Bool}) -> {R.bucket_step(capacity, refill, every_ms, R.Bucket{level, last}, now) == R.BucketStep{True{}, R.Bucket{Nat.sub(Spec.refill(R.full_level(capacity, every_ms), level, last, now, refill), every_ms), Nat.max(last, now)}} : R.BucketStep}:
  %Equal.sym(Nat, R.refilled(R.full_level(capacity, every_ms), level, last, now, refill), Spec.refill(R.full_level(capacity, every_ms), level, last, now, refill), refilled_spec(R.full_level(capacity, every_ms), level, last, now, refill)) : {R.bucket_take(_, every_ms, Nat.max(last, now)) == R.BucketStep{True{}, R.Bucket{Nat.sub(Spec.refill(R.full_level(capacity, every_ms), level, last, now, refill), every_ms), Nat.max(last, now)}} : R.BucketStep}
  %Equal.sym(Bool, Nat.is_le(every_ms, Spec.refill(R.full_level(capacity, every_ms), level, last, now, refill)), True{}, enough) : {R.bucket_pick(Spec.refill(R.full_level(capacity, every_ms), level, last, now, refill), every_ms, Nat.max(last, now), _) == R.BucketStep{True{}, R.Bucket{Nat.sub(Spec.refill(R.full_level(capacity, every_ms), level, last, now, refill), every_ms), Nat.max(last, now)}} : R.BucketStep}
  {==}

def bucket_deny(+capacity: Nat, +refill: Nat, +every_ms: Nat, +level: Nat, +last: Nat, +now: Nat, short: {Nat.is_le(every_ms, Spec.refill(R.full_level(capacity, every_ms), level, last, now, refill)) == False{} : Bool}) -> {R.bucket_step(capacity, refill, every_ms, R.Bucket{level, last}, now) == R.BucketStep{False{}, R.Bucket{Spec.refill(R.full_level(capacity, every_ms), level, last, now, refill), Nat.max(last, now)}} : R.BucketStep}:
  %Equal.sym(Nat, R.refilled(R.full_level(capacity, every_ms), level, last, now, refill), Spec.refill(R.full_level(capacity, every_ms), level, last, now, refill), refilled_spec(R.full_level(capacity, every_ms), level, last, now, refill)) : {R.bucket_take(_, every_ms, Nat.max(last, now)) == R.BucketStep{False{}, R.Bucket{Spec.refill(R.full_level(capacity, every_ms), level, last, now, refill), Nat.max(last, now)}} : R.BucketStep}
  %Equal.sym(Bool, Nat.is_le(every_ms, Spec.refill(R.full_level(capacity, every_ms), level, last, now, refill)), False{}, short) : {R.bucket_pick(Spec.refill(R.full_level(capacity, every_ms), level, last, now, refill), every_ms, Nat.max(last, now), _) == R.BucketStep{False{}, R.Bucket{Spec.refill(R.full_level(capacity, every_ms), level, last, now, refill), Nat.max(last, now)}} : R.BucketStep}
  {==}

def add_zero(+p: Nat) -> {Nat.add(p, 0n) == p : Nat}:
  match p:
    case 0n: {==}
    case 1n+k:
      %Equal.sym(Nat, Nat.add(k, 0n), k, add_zero(k)) : {1n+_ == 1n+k : Nat}
      {==}

def add_succ(+x: Nat, +y: Nat) -> {Nat.add(x, 1n+y) == 1n+Nat.add(x, y) : Nat}:
  match x:
    case 0n: {==}
    case 1n+k:
      %Equal.sym(Nat, Nat.add(k, 1n+y), 1n+Nat.add(k, y), add_succ(k, y)) : {1n+_ == 1n+1n+Nat.add(k, y) : Nat}
      {==}

def sub_add(+x: Nat, +y: Nat, le: {Nat.is_le(y, x) == True{} : Bool}) -> {Nat.add(Nat.sub(x, y), y) == x : Nat}:
  match x y:
    case 0n 0n: {==}
    case 1n+p 0n:
      %Equal.sym(Nat, Nat.add(p, 0n), p, add_zero(p)) : {1n+_ == 1n+p : Nat}
      {==}
    case 0n 1n+q: absurd({Nat.add(Nat.sub(0n, 1n+q), 1n+q) == 0n : Nat}, false_true(le))
    case 1n+p 1n+q:
      %Equal.sym(Nat, Nat.add(Nat.sub(p, q), 1n+q), 1n+Nat.add(Nat.sub(p, q), q), add_succ(Nat.sub(p, q), q)) : {_ == 1n+p : Nat}
      %Equal.sym(Nat, Nat.add(Nat.sub(p, q), q), p, sub_add(p, q, le)) : {1n+_ == 1n+p : Nat}
      {==}

def bucket_conserve(+capacity: Nat, +refill: Nat, +every_ms: Nat, +level: Nat, +last: Nat, +now: Nat, +enough: {Nat.is_le(every_ms, Spec.refill(R.full_level(capacity, every_ms), level, last, now, refill)) == True{} : Bool}) -> {Nat.add(Spec.level(R.bucket_step(capacity, refill, every_ms, R.Bucket{level, last}, now)), every_ms) == Spec.refill(R.full_level(capacity, every_ms), level, last, now, refill) : Nat}:
  %Equal.sym(R.BucketStep, R.bucket_step(capacity, refill, every_ms, R.Bucket{level, last}, now), R.BucketStep{True{}, R.Bucket{Nat.sub(Spec.refill(R.full_level(capacity, every_ms), level, last, now, refill), every_ms), Nat.max(last, now)}}, bucket_allow(capacity, refill, every_ms, level, last, now, enough)) : {Nat.add(Spec.level(_), every_ms) == Spec.refill(R.full_level(capacity, every_ms), level, last, now, refill) : Nat}
  sub_add(Spec.refill(R.full_level(capacity, every_ms), level, last, now, refill), every_ms, enough)

def min_le(+a: Nat, +b: Nat) -> {Nat.is_le(Nat.min(a, b), a) == True{} : Bool}:
  match a b:
    case 0n _: {==}
    case 1n+p 0n: {==}
    case 1n+p 1n+q: min_le(p, q)

def le_refl(+n: Nat) -> {Nat.is_le(n, n) == True{} : Bool}:
  match n:
    case 0n: {==}
    case 1n+k: le_refl(k)

def le_succ(+z: Nat, +p: Nat, e: {Nat.is_le(z, p) == True{} : Bool}) -> {Nat.is_le(z, 1n+p) == True{} : Bool}:
  match z p:
    case 0n _: {==}
    case 1n+k 0n: absurd({Nat.is_le(1n+k, 1n) == True{} : Bool}, false_true(e))
    case 1n+k 1n+q: le_succ(k, q, e)

def sub_le(+x: Nat, +y: Nat) -> {Nat.is_le(Nat.sub(x, y), x) == True{} : Bool}:
  match x y:
    case 0n _: {==}
    case 1n+p 0n: le_refl(p)
    case 1n+p 1n+q: le_succ(Nat.sub(p, q), p, sub_le(p, q))

def le_trans(+a: Nat, +b: Nat, +c: Nat, e1: {Nat.is_le(a, b) == True{} : Bool}, e2: {Nat.is_le(b, c) == True{} : Bool}) -> {Nat.is_le(a, c) == True{} : Bool}:
  match a b c:
    case 0n _ 0n: {==}
    case 0n _ 1n+r: {==}
    case 1n+x 0n _: absurd({Nat.is_le(1n+x, c) == True{} : Bool}, false_true(e1))
    case 1n+x 1n+y 0n: absurd({Nat.is_le(1n+x, 0n) == True{} : Bool}, false_true(e2))
    case 1n+x 1n+y 1n+z: le_trans(x, y, z, e1, e2)

def cap_case(+r: Nat, +full: Nat, +every_ms: Nat, +at: Nat, r_le: {Nat.is_le(r, full) == True{} : Bool}, +b: Bool) -> {Nat.is_le(Spec.level(R.bucket_pick(r, every_ms, at, b)), full) == True{} : Bool}:
  match b:
    case True{}: le_trans(Nat.sub(r, every_ms), r, full, sub_le(r, every_ms), r_le)
    case False{}: r_le

def bucket_capacity(+capacity: Nat, +refill: Nat, +every_ms: Nat, +level: Nat, +last: Nat, +now: Nat) -> {Nat.is_le(Spec.level(R.bucket_step(capacity, refill, every_ms, R.Bucket{level, last}, now)), R.full_level(capacity, every_ms)) == True{} : Bool}:
  +full = R.full_level(capacity, every_ms)
  +r = R.refilled(full, level, last, now, refill)
  cap_case(r, full, every_ms, Nat.max(last, now), min_le(full, Nat.add(level, Nat.mul(Nat.sub(now, last), refill))), Nat.is_le(every_ms, r))

def Laws.rate_fixed_allow(limit, window_ms, epoch, count, now, same, under): fixed_allow(limit, window_ms, epoch, count, now, same, under)
def Laws.rate_fixed_deny(limit, window_ms, epoch, count, now, same, over): fixed_deny(limit, window_ms, epoch, count, now, same, over)
def Laws.rate_fixed_new_window(l, window_ms, epoch, count, now, later): fixed_new(l, window_ms, epoch, count, now, later)
def Laws.rate_fixed_zero_limit(window_ms, counter, now): fixed_zero(window_ms, counter, now)
def Laws.rate_fixed_quota(limit, window_ms, epoch, count, times, inside): fixed_quota(limit, window_ms, epoch, count, times, inside)
def Laws.rate_bucket_capacity(capacity, refill, every_ms, level, last, now): bucket_capacity(capacity, refill, every_ms, level, last, now)
def Laws.rate_bucket_allow(capacity, refill, every_ms, level, last, now, enough): bucket_allow(capacity, refill, every_ms, level, last, now, enough)
def Laws.rate_bucket_conserve(capacity, refill, every_ms, level, last, now, enough): bucket_conserve(capacity, refill, every_ms, level, last, now, enough)
def Laws.rate_bucket_deny(capacity, refill, every_ms, level, last, now, short): bucket_deny(capacity, refill, every_ms, level, last, now, short)
