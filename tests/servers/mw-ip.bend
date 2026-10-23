# BND-44 test server: connection info, IP restriction and rate limiting.
# Every request in the tests comes from 127.0.0.1, so each rule scenario has
# its own path. Rate limits read a fake clock that POST /clock?ms=N sets.
import Base
import ../../src/main.bend as B
import ../../src/app/context.bend as C
import ../../src/app/store.bend as Store
import ../../src/http/response.bend as Response
import ../../src/router/methods.bend as Methods

type Env is Data:
  Env{clock: B.Store(Nat), fixed: B.RateLimiter, bucket: B.RateLimiter, tiny: B.RateLimiter, conc: B.RateLimiter, live: B.RateLimiter, shared: B.RateLimiter, evict: B.RateLimiter}

type Which is Data:
  Fixed{}
  Bucket{}
  Tiny{}
  Conc{}
  Shared{}
  Evict{}

type Tag is Data:
  Info{}
  Client{}
  ProxiedClient{}
  SetClock{}
  Hello{}
  Builtin{id: B.Builtin}
  Limit{which: Which}
  Stats{which: Which}
  Live{}
  Broken{}

def info_text(info: Maybe<&2, B.ConnInfo>) -> String:
  match info:
    case None{}: "none"
    case Some{+i}: B.address_type(i) ++ " " ++ B.remote_address(i) ++ " " ++ U32.show(B.remote_port(i))

def client_text(address: Maybe<&2, String>) -> String:
  match address:
    case None{}: "none"
    case Some{a}: a

def or_empty(cs: Maybe<&2, List<&2, B.Cidr>>) -> List<&2, B.Cidr>:
  match cs:
    case Some{x}: x
    case None{}: []

def trusted() -> List<&2, B.Cidr>:
  or_empty(B.cidrs(["127.0.0.1/32"]))

def ms_value(q: Maybe<&2, String>) -> Nat:
  match q:
    case None{}: 0n
    case Some{s}: Maybe.default(&2, Nat, Nat.read(s), 0n)

def clock_ms(c: B.Context(Unit)) -> Nat:
  ms_value(C.query(Unit, c, "ms"))

def set_clock(c: B.Context(Unit), r: Result<&2, &2, Store.Error, Unit>) -> B.Res:
  match r:
    case Done{u}: C.text(Unit, c, "ok")
    case Fail{e}: Response.text(503, "clock unavailable")

def pick(which: Which, env: Env) -> B.RateLimiter:
  match which env:
    case Fixed{} Env{clock, f, b, t, k, l, sh, ev}: f
    case Bucket{} Env{clock, f, b, t, k, l, sh, ev}: b
    case Tiny{} Env{clock, f, b, t, k, l, sh, ev}: t
    case Conc{} Env{clock, f, b, t, k, l, sh, ev}: k
    case Shared{} Env{clock, f, b, t, k, l, sh, ev}: sh
    case Evict{} Env{clock, f, b, t, k, l, sh, ev}: ev

def bool_text(b: Bool) -> String:
  match b:
    case True{}: "true"
    case False{}: "false"

# "tracked saturated saturating", for the saturation tests.
def stats_text(+c: B.Context(Unit), r: Result<&2, &2, Store.Error, B.RateLimitStats>) -> B.Res:
  match r:
    case Done{+st}: C.text(Unit, c, Nat.show(B.stats_tracked(st)) ++ " " ++ Nat.show(B.stats_saturated(st)) ++ " " ++ bool_text(B.stats_saturating(st)))
    case Fail{e}: Response.text(503, "stats unavailable")

def handle(tag: Tag, +c: B.Context(Unit), env: Env) -> IO(B.Res):
  match tag env:
    case Info{} _: IO.pure(B.Res, C.text(Unit, c, info_text(B.conn_info(Unit, c))))
    case Client{} _: IO.pure(B.Res, C.text(Unit, c, client_text(B.client_address(Unit, c, []))))
    case ProxiedClient{} _: IO.pure(B.Res, C.text(Unit, c, client_text(B.client_address(Unit, c, trusted()))))
    case SetClock{} Env{clock, f, b, t, k, l, sh, ev}:
      do IO<B.Res>:
        r : Result<&2, &2, Store.Error, Unit> <- B.store_set(Nat, clock, clock_ms(c))
        return set_clock(c, r)
    case Stats{which} _:
      do IO<B.Res>:
        r : Result<&2, &2, Store.Error, B.RateLimitStats> <- B.rate_limit_stats(pick(which, env))
        return stats_text(c, r)
    case _ _: IO.pure(B.Res, C.text(Unit, c, "ok"))

def handler(tag: Tag, c: B.Context(Unit), env: Env) -> IO(B.Res):
  handle(tag, c, env)

# Tests name their own key, so cases never share a counter.
def key_pick(given: Maybe<&2, String>, +c: B.Context(Unit)) -> String:
  match given:
    case Some{k}: k
    case None{}: client_text(B.client_address(Unit, c, []))

def key(+c: B.Context(Unit)) -> String:
  key_pick(C.request_header(Unit, c, "x-test-key"), c)

def now(r: Result<&2, &2, Store.Error, Nat>) -> Nat:
  match r:
    case Done{n}: n
    case Fail{e}: 0n

def clock_of(env: Env) -> B.Store(Nat):
  Env{clock, f, b, t, k, l, sh, ev} = env
  clock

def live_of(env: Env) -> B.RateLimiter:
  Env{clock, f, b, t, k, l, sh, ev} = env
  l

def limited(+c: B.Context(Unit), +env: Env, which: Which, next: B.Context(Unit) -> IO(B.Res)) -> IO(B.Res):
  +clock = clock_of(env)
  do IO<B.Res>:
    r : Result<&2, &2, Store.Error, Nat> <- B.store_get(Nat, clock)
    B.rate_limit_with(Unit, pick(which, env), key(c), now(r), c, next)

def layer(tag: Tag, c: B.Context(Unit), +env: Env, next: B.Context(Unit) -> IO(B.Res)) -> IO(B.Res):
  match tag:
    case Builtin{id}: B.builtin(Unit, id, c, next)
    case Limit{which}: limited(c, env, which, next)
    case Broken{}: IO.pure(B.Res, Response.text(500, "invalid fixture policy"))
    case Live{}: B.rate_limit(Unit, live_of(env), c, next)
    case _: next(c)

def middleware(tag: Tag, c: B.Context(Unit), env: Env, next: B.Context(Unit) -> IO(B.Res)) -> IO(B.Res):
  layer(tag, c, env, next)

# An invalid policy registers a route that answers 500 instead, so a typo in
# this fixture fails its test loudly.
def restrict(pattern: String, p: Maybe<&2, B.IpPolicy>) -> B.Registration(Tag):
  match p:
    case Some{x}: B.use_path(Tag, pattern, Builtin{B.ip_restriction(x)})
    case None{}: B.use_path(Tag, pattern, Broken{})

def routes() -> List<&2, B.Registration(Tag)>:
  [
    restrict("/deny/*", B.ip_rules(["127.0.0.0/8"], [])),
    restrict("/allow-other/*", B.ip_rules([], ["10.0.0.0/8", "2001:db8::/32"])),
    restrict("/allow-local/*", B.ip_rules([], ["10.0.0.0/8", "127.0.0.1/32"])),
    restrict("/deny-wins/*", B.ip_rules(["127.0.0.1"], ["127.0.0.0/8"])),
    restrict("/mapped/*", B.ip_rules(["::ffff:127.0.0.0/104"], [])),
    restrict("/v6-only/*", B.ip_rules(["::/0"], [])),
    restrict("/proxied/*", B.ip_policy(["203.0.113.0/24"], [], ["127.0.0.1/32"])),
    restrict("/spoof/*", B.ip_rules(["203.0.113.0/24"], [])),
    restrict("/spoof-allow/*", B.ip_rules([], ["10.0.0.0/8"])),
    B.use_path(Tag, "/fixed", Limit{Fixed{}}),
    B.use_path(Tag, "/bucket", Limit{Bucket{}}),
    B.use_path(Tag, "/tiny", Limit{Tiny{}}),
    B.use_path(Tag, "/conc", Limit{Conc{}}),
    B.use_path(Tag, "/tiny-shared", Limit{Shared{}}),
    B.use_path(Tag, "/tiny-evict", Limit{Evict{}}),
    B.use_path(Tag, "/live", Live{}),
    B.get(Tag, "/info", Info{}),
    B.get(Tag, "/client", Client{}),
    B.get(Tag, "/proxied/client", ProxiedClient{}),
    B.post(Tag, "/clock", SetClock{}),
    B.get(Tag, "/fixed", Hello{}),
    B.get(Tag, "/bucket", Hello{}),
    B.get(Tag, "/tiny", Hello{}),
    B.get(Tag, "/conc", Hello{}),
    B.get(Tag, "/tiny-shared", Hello{}),
    B.get(Tag, "/tiny-evict", Hello{}),
    B.get(Tag, "/stats/tiny", Stats{Tiny{}}),
    B.get(Tag, "/stats/tiny-shared", Stats{Shared{}}),
    B.get(Tag, "/stats/tiny-evict", Stats{Evict{}}),
    B.get(Tag, "/live", Hello{}),
    B.get(Tag, "/*", Hello{})
  ]

def ready(result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>, env: Env) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "invalid routes")
    case Done{table}:
      B.serve_with(~Unit, ~Tag, ~Env, ~handler, ~middleware, table, env, B.config())

def main() -> IO(Unit):
  do IO<Unit>:
    clock : B.Store(Nat) <- B.store(Nat, 0n)
    fixed : B.RateLimiter <- B.rate_limiter(B.fixed_window(100n, 60000n))
    bucket : B.RateLimiter <- B.rate_limiter_with(B.rate_limit_config("burst", B.token_bucket(5n, 1n, 1000n), 10000n, []))
    tiny : B.RateLimiter <- B.rate_limiter_with(B.rate_limit_config("tiny", B.fixed_window(2n, 60000n), 2n, []))
    conc : B.RateLimiter <- B.rate_limiter(B.fixed_window(40n, 60000n))
    live : B.RateLimiter <- B.rate_limiter(B.fixed_window(3n, 3600000n))
    shared : B.RateLimiter <- B.rate_limiter_with(B.rate_limit_saturation(B.rate_limit_config("tiny", B.fixed_window(2n, 60000n), 2n, []), B.saturation_shared()))
    evict : B.RateLimiter <- B.rate_limiter_with(B.rate_limit_saturation(B.rate_limit_config("tiny", B.fixed_window(2n, 60000n), 2n, []), B.saturation_evict()))
    ready(B.routes(Tag, routes()), Env{clock, fixed, bucket, tiny, conc, live, shared, evict})
