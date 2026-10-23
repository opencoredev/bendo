# Rate limiting on B.Store: fixed window or token bucket, keyed by client
# address or an app-supplied key. Answers 429 with Retry-After and sets the
# IETF RateLimit and RateLimit-Policy fields (draft-ietf-httpapi-ratelimit-headers-11).
import Base
import ../app/context.bend as C
import ../app/errors.bend as Errors
import ../app/store.bend as Store
import ../app/store_actor.bend as StoreActor
import ../http/response.bend as Response
import ../net/ip.bend as Ip
import ./ip_restriction.bend as IpRestriction
import ./common.bend as Common
import ./rate_limit_core.bend as Core

# saturation picks what a new key gets while the table is full; see
# Core.Saturation. The default lets it through uncounted.
type Config is Data:
  Config{name: String, policy: Core.Policy, max_keys: Nat, trusted: List<&2, Ip.Cidr>, saturation: Core.Saturation}

type Limiter is Data:
  Limiter{config: Config, store: Store.Store<Core.Table>}

def config(policy: Core.Policy) -> Config:
  Config{"default", policy, 10000n, [], Core.AllowUntracked{}}

def with_saturation(config: Config, mode: Core.Saturation) -> Config:
  Config{name, policy, max_keys, trusted, old} = config
  Config{name, policy, max_keys, trusted, mode}

def limiter(config: Config) -> IO(Limiter):
  Config{name, +policy, max_keys, trusted, saturation} = config
  do IO<Limiter>:
    store : Store.Store<Core.Table> <- StoreActor.store(Core.Table, Core.empty(policy))
    return Limiter{Config{name, policy, max_keys, trusted, saturation}, store}

# Counters for monitoring: keys tracked, requests that met a full table since
# startup, and whether the table is saturated now.
def stats_of(result: Result<&2, &2, Store.Error, Core.Table>) -> Result<&2, &2, Store.Error, Core.Stats>:
  match result:
    case Done{table}: Done{Core.stats(table)}
    case Fail{e}: Fail{e}

def stats(limiter: Limiter) -> IO(Result<&2, &2, Store.Error, Core.Stats>):
  Limiter{config, store} = limiter
  do IO<Result<&2, &2, Store.Error, Core.Stats>>:
    result : Result<&2, &2, Store.Error, Core.Table> <- Store.get(Core.Table, store)
    return stats_of(result)

def sf_keep(x: U32, rest: String, ok: Bool) -> String:
  match ok:
    case True{}: SCon{Chr{x}, rest}
    case False{}: rest

# A structured-field string keeps printable ASCII only, with " and \ escaped.
def sf_chars(s: String) -> String:
  match s:
    case SNil{}: ""
    case SCon{'"', t}: "\\\"" ++ sf_chars(t)
    case SCon{'\\', t}: "\\\\" ++ sf_chars(t)
    case SCon{Chr{+x}, t}: sf_keep(x, sf_chars(t), (x >= 32 : U32) && (x <= 126 : U32))

def seconds(+ms: Nat) -> Nat:
  Core.ceil_div(ms, 1000n)

def window_seconds(policy: Core.Policy) -> Nat:
  Nat.max(1n, seconds(Core.horizon(policy)))

def quota(policy: Core.Policy) -> Nat:
  match policy:
    case Core.FixedWindow{limit, w}: limit
    case Core.TokenBucket{capacity, r, e}: capacity

def policy_value(+name: String, +policy: Core.Policy) -> String:
  "\"" ++ name ++ "\";q=" ++ Nat.show(quota(policy)) ++ ";w=" ++ Nat.show(window_seconds(policy))

def limit_value(+name: String, +d: Core.Decision) -> String:
  Core.Decision{ok, limit, remaining, reset_ms, retry_ms} = d
  "\"" ++ name ++ "\";r=" ++ Nat.show(remaining) ++ ";t=" ++ Nat.show(seconds(reset_ms))

def decorated(+name: String, +policy: Core.Policy, +d: Core.Decision, res: Response.Res) -> Response.Res:
  Common.header(Common.header(res, "ratelimit-policy", policy_value(name, policy)), "ratelimit", limit_value(name, d))

def denied(-Vars: Data, +c: C.Ctx<Vars>, +name: String, +policy: Core.Policy, +d: Core.Decision) -> Response.Res:
  Core.Decision{ok, limit, remaining, reset_ms, +retry_ms} = d
  +headed = C.header(Vars, C.header(Vars, C.header(Vars, c, "retry-after", Nat.show(Nat.max(1n, seconds(retry_ms)))), "ratelimit-policy", policy_value(name, policy)), "ratelimit", limit_value(name, d))
  C.error(Vars, headed, Errors.http_error(429, "Too Many Requests"))

def allowed_go(-Vars: Data, +c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res), +name: String, +policy: Core.Policy, +d: Core.Decision, ok: Bool) -> IO(Response.Res):
  match ok:
    case True{}:
      do IO<Response.Res>:
        res : Response.Res <- next(c)
        return decorated(name, policy, d, res)
    case False{}: IO.pure(Response.Res, denied(Vars, c, name, policy, d))

def verdict(-Vars: Data, +c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res), +name: String, +policy: Core.Policy, +d: Core.Decision) -> IO(Response.Res):
  Core.Decision{+ok, l, r, s, w} = d
  allowed_go(Vars, c, next, name, policy, d, ok)

# An uncounted request carries no RateLimit fields: no quota applied to it.
def judged(-Vars: Data, +c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res), +name: String, +policy: Core.Policy, v: Core.Verdict) -> IO(Response.Res):
  match v:
    case Core.Counted{d}: verdict(Vars, c, next, name, policy, d)
    case Core.Untracked{}: next(c)

def mode_text(mode: Core.Saturation) -> String:
  match mode:
    case Core.AllowUntracked{}: "new keys pass uncounted until a sweep frees room"
    case Core.SharedQuota{}: "new keys share one overflow quota until a sweep frees room"
    case Core.EvictOldest{}: "evicting the least recently used keys"

# One log line when the table becomes saturated, not one per request.
def announce(+name: String, +max_keys: Nat, mode: Core.Saturation, began: Bool) -> IO(Unit):
  match began:
    case True{}: IO.print("bendo rate limit \"" ++ name ++ "\": key table full at " ++ Nat.show(max_keys) ++ " keys; " ++ mode_text(mode))
    case False{}: IO.pure(Unit, Unit{})

def reported(-Vars: Data, +c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res), +name: String, +policy: Core.Policy, +max_keys: Nat, mode: Core.Saturation, got: Core.Verdict & Bool) -> IO(Response.Res):
  (v, began) = got
  do IO<Response.Res>:
    announce(name, max_keys, mode, began)
    judged(Vars, c, next, name, policy, v)

def decided(-Vars: Data, +c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res), +name: String, +policy: Core.Policy, +max_keys: Nat, mode: Core.Saturation, result: Result<&2, &2, Store.Error, Core.Table>) -> IO(Response.Res):
  match result:
    case Done{table}: reported(Vars, c, next, name, policy, max_keys, mode, Core.outcome(table))
    case Fail{e}: IO.pure(Response.Res, C.error(Vars, c, Errors.http_error(503, "Service Unavailable")))

# Count one request for key at now (milliseconds on any monotonic clock).
# Tests pass their own clock here; limit uses IO.now.
def limit_with(-Vars: Data, limiter: Limiter, key: String, now: Nat, +c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res):
  Limiter{Config{name, +policy, +max_keys, trusted, +saturation}, store} = limiter
  +label = sf_chars(name)
  do IO<Response.Res>:
    result : Result<&2, &2, Store.Error, Core.Table> <- Store.update(Core.Table, store, table => Core.admit(policy, saturation, max_keys, key, now, table))
    decided(Vars, c, next, label, policy, max_keys, saturation, result)

# The client address text, or "unknown" when there is no socket peer (all
# such requests share one key).
def key_text(address: Maybe<&2, Ip.Addr>) -> String:
  match address:
    case Some{a}: Ip.format(a)
    case None{}: "unknown"

def key_option(address: Maybe<&2, Ip.Addr>) -> Maybe<&2, String>:
  match address:
    case Some{a}: Some{Ip.format(a)}
    case None{}: None{}

def client_key(-Vars: Data, +c: C.Ctx<Vars>, limiter: Limiter) -> String:
  Limiter{Config{name, policy, max_keys, trusted, saturation}, store} = limiter
  key_text(IpRestriction.client(Vars, c, trusted))

def limit(-Vars: Data, +limiter: Limiter, +c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res):
  do IO<Response.Res>:
    now : Nat <- IO.now()
    limit_with(Vars, limiter, client_key(Vars, c, limiter), now, c, next)
