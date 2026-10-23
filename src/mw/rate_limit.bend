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

type Config is Data:
  Config{name: String, policy: Core.Policy, max_keys: Nat, trusted: List<&2, Ip.Cidr>}

type Limiter is Data:
  Limiter{config: Config, store: Store.Store<Core.Table>}

def config(policy: Core.Policy) -> Config:
  Config{"default", policy, 10000n, []}

def limiter(config: Config) -> IO(Limiter):
  Config{name, +policy, max_keys, trusted} = config
  do IO<Limiter>:
    store : Store.Store<Core.Table> <- StoreActor.store(Core.Table, Core.empty(policy))
    return Limiter{Config{name, policy, max_keys, trusted}, store}

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

def decided(-Vars: Data, +c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res), +name: String, +policy: Core.Policy, result: Result<&2, &2, Store.Error, Core.Table>) -> IO(Response.Res):
  match result:
    case Done{table}: verdict(Vars, c, next, name, policy, Core.decision(table))
    case Fail{e}: IO.pure(Response.Res, C.error(Vars, c, Errors.http_error(503, "Service Unavailable")))

# Count one request for key at now (milliseconds on any monotonic clock).
# Tests pass their own clock here; limit uses IO.now.
def limit_with(-Vars: Data, limiter: Limiter, key: String, now: Nat, +c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res):
  Limiter{Config{name, +policy, +max_keys, trusted}, store} = limiter
  +label = sf_chars(name)
  do IO<Response.Res>:
    result : Result<&2, &2, Store.Error, Core.Table> <- Store.update(Core.Table, store, table => Core.admit(policy, max_keys, key, now, table))
    decided(Vars, c, next, label, policy, result)

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
  Limiter{Config{name, policy, max_keys, trusted}, store} = limiter
  key_text(IpRestriction.client(Vars, c, trusted))

def limit(-Vars: Data, +limiter: Limiter, +c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res):
  do IO<Response.Res>:
    now : Nat <- IO.now()
    limit_with(Vars, limiter, client_key(Vars, c, limiter), now, c, next)
