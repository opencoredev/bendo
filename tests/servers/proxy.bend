# BND-47 fixture: upstream URLs come from the environment at startup.
# BND-93 adds a named upstream, a name that never resolves and an IPv6 one.
import Base
import ../../src/main.bend as B
import ../../src/http/response.bend as Response
import ../../src/http/stream_types.bend as S
import ../../src/app/config.bend as Config
import ../../src/router/methods.bend as Methods

type Tag is Data:
  Up{}
  Preserve{}
  Trust{}
  Raw{}
  Slow{}
  Small{}
  Refused{}
  Blackhole{}
  Misconfigured{}
  Named{}
  Unresolved{}
  V6{}
  BadRewrite{}
  Replaced{}
  Replace{}
  Observe{}

type Env is Data:
  Env{up: String, raw: String, named: String, v6: String}

def up_url(env: Env) -> String:
  Env{up, raw, named, v6} = env
  up

def raw_url(env: Env) -> String:
  Env{up, raw, named, v6} = env
  raw

def named_url(env: Env) -> String:
  Env{up, raw, named, v6} = env
  named

def v6_url(env: Env) -> String:
  Env{up, raw, named, v6} = env
  v6

def options(tag: Tag, env: Env) -> B.ProxyOptions:
  match tag:
    case Preserve{}: B.proxy_rewrite(B.proxy_preserve_host(B.proxy_options(up_url(env)), True{}), "/preserve", "")
    case Trust{}: B.proxy_rewrite(B.proxy_forwarded(B.proxy_trust_forwarded(B.proxy_options(up_url(env)), True{}), True{}), "/trust", "")
    case Raw{}: B.proxy_rewrite(B.proxy_options(raw_url(env)), "/raw", "")
    case Slow{}: B.proxy_timeouts(B.proxy_rewrite(B.proxy_options(raw_url(env)), "/slow", ""), 1000, 1000, 500, 500)
    case Small{}: B.proxy_stream_config(B.proxy_rewrite(B.proxy_options(raw_url(env)), "/small", ""), S.Config{30000, 1024})
    case Replaced{}: B.proxy_rewrite(B.proxy_options(raw_url(env)), "/replaced", "")
    case Refused{}: B.proxy_options("http://127.0.0.1:1")
    case Blackhole{}: B.proxy_timeouts(B.proxy_options("http://10.255.255.1:80"), 300, 1000, 1000, 1000)
    case Misconfigured{}: B.proxy_options("http://example.com:0")
    case Named{}: B.proxy_rewrite(B.proxy_options(named_url(env)), "/named", "")
    case Unresolved{}: B.proxy_options("http://bendo-upstream.invalid")
    case V6{}: B.proxy_rewrite(B.proxy_options(v6_url(env)), "/v6", "")
    case BadRewrite{}: B.proxy_rewrite(B.proxy_options(up_url(env)), "/bad", "nope")
    case _: B.proxy_options(up_url(env))

def handler(tag: Tag, c: B.Ctx, env: Env) -> IO(B.Res):
  B.proxy(c, options(tag, env))

def middleware(tag: Tag, c: B.Ctx, env: Env, next: B.Ctx -> IO(B.Res)) -> IO(B.Res):
  match tag:
    case Replace{}:
      +ctx = c
      do IO<B.Res>:
        res : B.Res <- next(ctx)
        return B.text(ctx, "replacement")
    case Observe{}:
      do IO<B.Res>:
        res : B.Res <- next(c)
        IO.print("after")
        return res
    case _: next(c)

def limited(c: Config.Config) -> Config.Config:
  Config.Config{host, port, limit, headers, idle, head, body, max, keep, router, mode} = c
  Config.Config{host, port, 4194304, headers, idle, head, body, max, keep, router, mode}

def config() -> Config.Config:
  limited(Config.defaults())

def ready(env: Env, result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "invalid proxy routes")
    case Done{table}: B.serve_with(~Unit, ~Tag, ~Env, ~handler, ~middleware, table, env, config())

def main() -> IO(Unit):
  do IO<Unit>:
    up : String <- IO.try(String, IO.get_env("BENDO_UPSTREAM"))
    raw : String <- IO.try(String, IO.get_env("BENDO_RAW_UPSTREAM"))
    named : String <- IO.try(String, IO.get_env("BENDO_NAMED_UPSTREAM"))
    v6 : String <- IO.try(String, IO.get_env("BENDO_V6_UPSTREAM"))
    ready(Env{up, raw, named, v6}, B.routes(Tag, [
      B.on_after_response(Tag, Observe{}),
      B.use_path(Tag, "/replaced/*", Replace{}),
      B.all(Tag, "/preserve/*", Preserve{}),
      B.all(Tag, "/trust/*", Trust{}),
      B.all(Tag, "/raw/*", Raw{}),
      B.all(Tag, "/slow/*", Slow{}),
      B.all(Tag, "/small/*", Small{}),
      B.all(Tag, "/replaced/*", Replaced{}),
      B.get(Tag, "/refused", Refused{}),
      B.get(Tag, "/blackhole", Blackhole{}),
      B.get(Tag, "/misconfigured", Misconfigured{}),
      B.all(Tag, "/named/*", Named{}),
      B.get(Tag, "/unresolved", Unresolved{}),
      B.all(Tag, "/v6/*", V6{}),
      B.get(Tag, "/bad/*", BadRewrite{}),
      B.all(Tag, "/*", Up{})
    ]))
