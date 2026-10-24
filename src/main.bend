# Public Bendo entrypoint. Route tags and startup environments are app-owned Data.
import Base
import ./stream.bend as Stream
import ./http/stream_types.bend as StreamTypes
import ./sse.bend as Sse
import ./http/sse.bend as SseCodec
import ./http/sse_types.bend as SseTypes
import ./app/observability.bend as Observation
import ./mw/builtin.bend as Builtin
import ./mw/cache.bend as Cache
import ./mw/server_timing.bend as Timing
import ./mw/basic_auth.bend as BasicAuth
import ./mw/jwt.bend as JwtAuth
import ./mw/csrf_policy.bend as CsrfPolicy
import ./crypto/jwt.bend as Jwt
import ./data/utf8.bend as Utf8
import ./app/config.bend as Config
import ./app/table.bend as Table
import ./app/scopes.bend as Scopes
import ./app/compose.bend as Compose
import ./app/plugin.bend as Plugin
import ./app/manifest.bend as Manifest
import ./app/handle.bend as Handle
import ./app/context.bend as Context
import ./app/errors.bend as Errors
import ./app/store.bend as Store
import ./app/store_actor.bend as StoreActor
import ./data/json.bend as Json
import ./data/cookie.bend as Cookie
import ./data/signed-cookie.bend as SignedCookie
import ./serve.bend as Serve
import ./http/request.bend as Request
import ./http/response.bend as Response
import ./router/methods.bend as Methods
import ./router/router.bend as Router
import ./net/ip.bend as Ip
import ./net/conn_info.bend as Conn
import ./mw/ip_restriction.bend as IpRestriction
import ./mw/rate_limit.bend as RateLimit
import ./mw/rate_limit_core.bend as RateCore

def HttpError() -> Data: Errors.HttpError
def http_error(status: U32, message: String) -> Errors.HttpError: Errors.http_error(status, message)
def error(c: Handle.Ctx, failure: Errors.HttpError) -> Response.Res: Context.error(Unit, c, failure)
def result(c: Handle.Ctx, value: Result<&2, &2, Errors.HttpError, Response.Res>) -> Response.Res: Context.result(Unit, c, value)

def Req() -> Data: Request.Req
def Res() -> Data: Response.Res
def Ctx() -> Data: Handle.Ctx
def Context(-Vars: Data) -> Data: Context.Ctx<Vars>
def ServerConfig() -> Data: Config.Config
def RouterKind() -> Data: Router.RouterKind
def Registration(-Tag: Data) -> Data: Table.Entry<Tag>
def Routes(-Tag: Data) -> Data: Table.Table<Tag>
def RouteError() -> Data: Methods.BuildError

def config() -> Config.Config: Config.defaults()
def spec() -> Router.RouterKind: Router.Spec{}
def trie() -> Router.RouterKind: Router.Trie{}
def not_modified(headers: List<&2, Request.Header>, representation: Maybe<&2, List<&2, U32>>) -> Response.Res: Response.not_modified(headers, representation)

def param(c: Handle.Ctx, name: String) -> Maybe<&2, String>: Context.param(Unit, c, name)
def query(c: Handle.Ctx, name: String) -> Maybe<&2, String>: Context.query(Unit, c, name)
def queries(c: Handle.Ctx, name: String) -> List<&2, String>: Context.queries(Unit, c, name)
def request_header(c: Handle.Ctx, name: String) -> Maybe<&2, String>: Context.request_header(Unit, c, name)
def header_bytes(c: Handle.Ctx, name: String) -> List<&2, List<&2, U32>>: Context.header_bytes(Unit, c, name)
def method(c: Handle.Ctx) -> Request.Method: Context.method(Unit, c)
def path(c: Handle.Ctx) -> String: Context.path(Unit, c)
def url(c: Handle.Ctx) -> String: Context.url(Unit, c)
def rewrite(c: Handle.Ctx, method: Request.Method, path: String) -> Handle.Ctx: Context.rewrite(Unit, c, method, path)
def raw_body(c: Handle.Ctx) -> List<&2, U32>: Context.raw_body(Unit, c)
def text(c: Handle.Ctx, value: String) -> Response.Res: Context.text(Unit, c, value)
def html(c: Handle.Ctx, value: String) -> Response.Res: Context.html(Unit, c, value)
def json(c: Handle.Ctx, value: Json.Json) -> Response.Res: Context.json(Unit, c, value)
def body(c: Handle.Ctx, bytes: List<&2, U32>, content_type: Maybe<&2, String>) -> Response.Res: Context.body(Unit, c, bytes, content_type)
def status(c: Handle.Ctx, code: U32) -> Handle.Ctx: Context.status(Unit, c, code)
def header(c: Handle.Ctx, name: String, value: String) -> Handle.Ctx: Context.header(Unit, c, name, value)
def redirect(c: Handle.Ctx, location: String) -> Response.Res: Context.redirect(Unit, c, location)
def redirect_status(c: Handle.Ctx, location: String, code: U32) -> Response.Res: Context.redirect_status(Unit, c, location, code)
def not_found(c: Handle.Ctx) -> Response.Res: Context.not_found(Unit, c)

def get(-Tag: Data, path: String, tag: Tag) -> Table.Entry<Tag>: Table.Route{Methods.get(Tag, path, tag)}
def head(-Tag: Data, path: String, tag: Tag) -> Table.Entry<Tag>: Table.Route{Methods.head(Tag, path, tag)}
def post(-Tag: Data, path: String, tag: Tag) -> Table.Entry<Tag>: Table.Route{Methods.post(Tag, path, tag)}
def put(-Tag: Data, path: String, tag: Tag) -> Table.Entry<Tag>: Table.Route{Methods.put(Tag, path, tag)}
def patch(-Tag: Data, path: String, tag: Tag) -> Table.Entry<Tag>: Table.Route{Methods.patch(Tag, path, tag)}
def delete(-Tag: Data, path: String, tag: Tag) -> Table.Entry<Tag>: Table.Route{Methods.delete(Tag, path, tag)}
def options(-Tag: Data, path: String, tag: Tag) -> Table.Entry<Tag>: Table.Route{Methods.options(Tag, path, tag)}
def all(-Tag: Data, path: String, tag: Tag) -> Table.Entry<Tag>: Table.Route{Methods.all(Tag, path, tag)}
def on(-Tag: Data, methods: List<&2, Request.Method>, path: String, tag: Tag) -> Table.Entry<Tag>: Table.Route{Methods.on(Tag, methods, path, tag)}
# Adapt a low-level method registration into the public app registration list.
def registration(-Tag: Data, entry: Methods.Registration(Tag)) -> Table.Entry<Tag>: Table.Route{entry}
def use(-Tag: Data, id: Tag) -> Table.Entry<Tag>: Table.Use{None{}, id}
def use_path(-Tag: Data, pattern: String, id: Tag) -> Table.Entry<Tag>: Table.Use{Some{pattern}, id}
def on_request(-Tag: Data, id: Tag) -> Table.Entry<Tag>: Table.Hook{Table.Request{}, id}
def on_parse(-Tag: Data, id: Tag) -> Table.Entry<Tag>: Table.Hook{Table.Parse{}, id}
def on_transform(-Tag: Data, id: Tag) -> Table.Entry<Tag>: Table.Hook{Table.Transform{}, id}
def before_handle(-Tag: Data, id: Tag) -> Table.Entry<Tag>: Table.Hook{Table.BeforeHandle{}, id}
def after_handle(-Tag: Data, id: Tag) -> Table.Entry<Tag>: Table.Hook{Table.AfterHandle{}, id}
def map_response(-Tag: Data, id: Tag) -> Table.Entry<Tag>: Table.Hook{Table.MapResponse{}, id}
def on_not_found(-Tag: Data, id: Tag) -> Table.Entry<Tag>: Table.Hook{Table.NotFound{}, id}
def on_error(-Tag: Data, id: Tag) -> Table.Entry<Tag>: Table.Hook{Table.Error{}, id}
def on_after_response(-Tag: Data, id: Tag) -> Table.Entry<Tag>: Table.Hook{Table.AfterResponse{}, id}
def routes(-Tag: Data, entries: List<&2, Table.Entry<Tag>>) -> Result<&2, &2, Methods.BuildError, Table.Table<Tag>>: Table.build(Tag, entries)

# Typed hook data for group/guard/route options; on_* entries are global until assembled into a scope.
def Hook(-Tag: Data) -> Data: Table.HookSpec<Tag>
def GuardOptions(-Tag: Data) -> Data: Table.GuardOptions<Tag>
def hook(-Tag: Data, stage: Table.Stage, id: Tag) -> Table.HookSpec<Tag>: Table.HookSpec{stage, id}
def guard_options(-Tag: Data, hooks: List<&2, Table.HookSpec<Tag>>) -> Table.GuardOptions<Tag>: Table.GuardOptions{hooks, Table.NoSchemas{}}
def guard(-Tag: Data, options: Table.GuardOptions<Tag>, entries: List<&2, Table.Entry<Tag>>) -> List<&2, Table.Entry<Tag>>: Scopes.guard(Tag, options, entries)
def group(-Tag: Data, prefix: String, hooks: List<&2, Table.HookSpec<Tag>>, entries: List<&2, Table.Entry<Tag>>) -> List<&2, Table.Entry<Tag>>: Compose.group(Tag, prefix, hooks, entries)
# Sub-apps are reusable registration lists sharing the app's tag/dispatcher types.
def route(-Tag: Data, prefix: String, sub: List<&2, Table.Entry<Tag>>) -> List<&2, Table.Entry<Tag>>: Compose.mount(Tag, prefix, sub)
def base_path(-Tag: Data, prefix: String, entries: List<&2, Table.Entry<Tag>>) -> List<&2, Table.Entry<Tag>>: Compose.mount(Tag, prefix, entries)
def show_routes(-Tag: Data, table: Table.Table<Tag>) -> IO(Unit): IO.print(Manifest.table_text(Tag, table))
def route_hooks(-Tag: Data, registration: Methods.Registration(Tag), hooks: List<&2, Table.HookSpec<Tag>>) -> Table.Entry<Tag>:
  Scopes.local(Tag, registration, hooks)

# BND-26 plugins: functions from a Builder to a Builder. See docs/guides/plugins.md.
def Builder(-Tag: Data) -> Data: Plugin.Builder<Tag>
def PluginId() -> Data: Plugin.Identity
def app(-Tag: Data) -> Plugin.Builder<Tag>: Plugin.Builder{[], []}
def app_from(-Tag: Data, entries: List<&2, Table.Entry<Tag>>) -> Plugin.Builder<Tag>: Plugin.Builder{[], entries}
def register(-Tag: Data, app: Plugin.Builder<Tag>, entries: List<&2, Table.Entry<Tag>>) -> Plugin.Builder<Tag>: Plugin.register(Tag, app, entries)
def use_plugin(-Tag: Data, app: Plugin.Builder<Tag>, plugin: Plugin.Builder<Tag> -> Plugin.Builder<Tag>) -> Plugin.Builder<Tag>: Plugin.use(Tag, app, plugin)
def plugin_id(name: String) -> Plugin.Identity: Plugin.Identity{name, ""}
def plugin_seed(name: String, seed: String) -> Plugin.Identity: Plugin.Identity{name, seed}
def named(-Tag: Data, id: Plugin.Identity, app: Plugin.Builder<Tag>, body: Plugin.Builder<Tag> -> Plugin.Builder<Tag>) -> Plugin.Builder<Tag>: Plugin.named(Tag, id, app, body)
def use_route(-Tag: Data, app: Plugin.Builder<Tag>, prefix: String, body: Plugin.Builder<Tag> -> Plugin.Builder<Tag>) -> Plugin.Builder<Tag>: Plugin.mount(Tag, app, prefix, body)
def use_group(-Tag: Data, app: Plugin.Builder<Tag>, prefix: String, hooks: List<&2, Table.HookSpec<Tag>>, body: Plugin.Builder<Tag> -> Plugin.Builder<Tag>) -> Plugin.Builder<Tag>: Plugin.group(Tag, app, prefix, hooks, body)
def use_guard(-Tag: Data, app: Plugin.Builder<Tag>, options: Table.GuardOptions<Tag>, body: Plugin.Builder<Tag> -> Plugin.Builder<Tag>) -> Plugin.Builder<Tag>: Plugin.guard(Tag, app, options, body)
def app_entries(-Tag: Data, app: Plugin.Builder<Tag>) -> List<&2, Table.Entry<Tag>>: Plugin.entries(Tag, app)
def app_routes(-Tag: Data, app: Plugin.Builder<Tag>) -> Result<&2, &2, Methods.BuildError, Table.Table<Tag>>: Table.build(Tag, Plugin.entries(Tag, app))

def handle(~Tag: Data, ~Env: Data, ~dispatch: Tag -> Handle.Ctx -> Env -> IO(Response.Res), table: Table.Table<Tag>, env: Env, req: Request.Req, body: List<&2, U32>) -> IO(Response.Res):
  Handle.handle(~Tag, ~Env, ~dispatch, table, env, req, body)

def serve(~Tag: Data, ~Env: Data, ~dispatch: Tag -> Handle.Ctx -> Env -> IO(Response.Res), table: Table.Table<Tag>, env: Env, config: Config.Config) -> IO(Unit):
  Serve.run(~Tag, ~Env, ~dispatch, table, env, config)

# Vars is uniform across every middleware and handler in an app.
def handle_with(~Vars: Data, ~Tag: Data, ~Env: Data, ~dispatch: Tag -> Context.Ctx<Vars> -> Env -> IO(Response.Res), ~middleware: Tag -> Context.Ctx<Vars> -> Env -> (Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res), table: Table.Table<Tag>, env: Env, req: Request.Req, body: List<&2, U32>) -> IO(Response.Res):
  Handle.handle_with(~Vars, ~Tag, ~Env, ~dispatch, ~middleware, table, env, req, body)

def serve_with(~Vars: Data, ~Tag: Data, ~Env: Data, ~dispatch: Tag -> Context.Ctx<Vars> -> Env -> IO(Response.Res), ~middleware: Tag -> Context.Ctx<Vars> -> Env -> (Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res), table: Table.Table<Tag>, env: Env, config: Config.Config) -> IO(Unit):
  Serve.run_with(~Vars, ~Tag, ~Env, ~dispatch, ~middleware, table, env, config)

# Store operations use a prefix because B.get registers routes.
def Store(-S: Data) -> Data: Store.Store<S>
def StoreError() -> Data: Store.Error

def store(-S: Data, initial: S) -> IO(Store.Store<S>):
  StoreActor.store(S, initial)

def store_with_timeout(-S: Data, initial: S, timeout_ms: U32) -> IO(Store.Store<S>):
  StoreActor.store_with_timeout(S, initial, timeout_ms)

def store_get(-S: Data, handle: Store.Store<S>) -> IO(Result<&2, &2, Store.Error, S>):
  Store.get(S, handle)

def store_set(-S: Data, handle: Store.Store<S>, value: S) -> IO(Result<&2, &2, Store.Error, Unit>):
  Store.set(S, handle, value)

def store_update(-S: Data, handle: Store.Store<S>, change: S -> S) -> IO(Result<&2, &2, Store.Error, S>):
  Store.update(S, handle, change)

# Built-in identifiers are wrapped in the application's own middleware Tag.
def Builtin() -> Data: Builtin.Builtin
def logger() -> Builtin.Builtin: Builtin.Logger{}
def request_id() -> Builtin.Builtin: Builtin.RequestId{}
def server_timing() -> Builtin.Builtin: Builtin.ServerTiming{}
def powered_by(name: String) -> Builtin.Builtin: Builtin.PoweredBy{name}
def pretty_json() -> Builtin.Builtin: Builtin.PrettyJson{}
def builtin(-Vars: Data, id: Builtin.Builtin, c: Context.Ctx<Vars>, next: Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res):
  Builtin.dispatch(Vars, id, c, next)
def timing_mark(-Vars: Data, c: Context.Ctx<Vars>, name: String, duration_ms: Nat) -> IO(Bool):
  Timing.mark(Vars, c, name, duration_ms)

# Cookie setters append fields and return validation failures explicitly.
def cookies(c: Handle.Ctx) -> List<&2, Cookie.Entry>: Context.cookies(Unit, c)
def cookie(c: Handle.Ctx, name: String) -> Maybe<&2, String>: Context.cookie(Unit, c, name)
def set_cookie(c: Handle.Ctx, name: String, value: String, options: Cookie.Options) -> Result<&2, &2, Cookie.Error, Handle.Ctx>: Context.set_cookie(Unit, c, name, value, options)
def delete_cookie(c: Handle.Ctx, name: String, options: Cookie.Options) -> Result<&2, &2, Cookie.Error, Handle.Ctx>: Context.delete_cookie(Unit, c, name, options)

def set_signed_cookie(c: Handle.Ctx, name: String, value: String, keys: SignedCookie.Keys, options: Cookie.Options) -> Result<&2, &2, Cookie.Error, Handle.Ctx>:
  Context.set_signed_cookie(Unit, c, name, value, keys, options)

def signed_cookie(c: Handle.Ctx, name: String, keys: SignedCookie.Keys) -> Maybe<&2, String>:
  Context.signed_cookie(Unit, c, name, keys)

# Authentication and CSRF built-ins. Credentials and secrets live in the
# reusable route table, like Hono's middleware options.
def Credential() -> Data: BasicAuth.Credential
def credential(username: String, password: String) -> BasicAuth.Credential: BasicAuth.Credential{username, password}
def basic_auth(realm: String, users: List<&2, BasicAuth.Credential>) -> Builtin.Builtin: Builtin.BasicAuth{realm, users}
def bearer_auth(realm: String, tokens: List<&2, String>) -> Builtin.Builtin: Builtin.BearerAuth{realm, tokens}
# Trust only the listed origins ("https://app.example"; any path is ignored).
def csrf(origins: List<&2, String>) -> Builtin.Builtin: Builtin.Csrf{CsrfPolicy.policy(origins, None{})}
# Also trust scheme://Host, for a deployment that knows the scheme browsers
# use. Behind a TLS-terminating proxy that keeps Host, pass "https".
def csrf_host(scheme: String, origins: List<&2, String>) -> Builtin.Builtin: Builtin.Csrf{CsrfPolicy.policy(origins, Some{scheme})}

# HS256 with a UTF-8 secret; leeway is the allowed clock skew in seconds.
def JwtConfig() -> Data: JwtAuth.Config
def JwtError() -> Data: Jwt.Error
def jwt_config(secret: String, leeway: Nat, realm: String) -> JwtAuth.Config: JwtAuth.Config{Utf8.encode(secret), leeway, realm}
def jwt(config: JwtAuth.Config) -> Builtin.Builtin: Builtin.Jwt{config}
def jwt_with(-Vars: Data, config: JwtAuth.Config, c: Context.Ctx<Vars>, next: Json.Json -> Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res):
  JwtAuth.with_claims(Vars, config, c, next)
def jwt_sign(secret: String, claims: Json.Json) -> Result<&2, &2, Jwt.Error, String>: Jwt.sign(Utf8.encode(secret), claims)
def jwt_verify(secret: String, token: String, now: Nat, leeway: Nat) -> Result<&2, &2, Jwt.Error, Json.Json>: Jwt.verify(Utf8.encode(secret), token, now, leeway)

# Pull-based binary streaming through the ordinary routing/middleware lifecycle.
def StreamConfig() -> Data: StreamTypes.Config
def StreamStep(-State: Type) -> Type: StreamTypes.Step<State>
def stream_config() -> StreamTypes.Config: Stream.defaults()
def stream(~Vars: Data, ~State: Type, ~step: State -> IO(StreamTypes.Step<State>), ~cleanup: State -> IO(Unit), +c: Context.Ctx<Vars>, state: State, config: StreamTypes.Config) -> IO(Response.Res):
  Stream.register(Observation.stream(Context.observation(Vars, c)), Context.body(Vars, c, [], None{}), Stream.plan(~State, ~step, ~cleanup, state, config))

# Buffered protection and cache middleware.
def body_limit(bytes: U32) -> Builtin.Builtin: Builtin.BodyLimit{bytes}
def timeout(milliseconds: U32) -> Builtin.Builtin: Builtin.Timeout{milliseconds}
def etag() -> Builtin.Builtin: Builtin.ETag{}
def cache_control(policy: Cache.Policy) -> Builtin.Builtin: Builtin.CacheControl{policy}
def cache_no_store() -> Cache.Policy: Cache.NoStore{}
def cache_no_cache() -> Cache.Policy: Cache.NoCache{}
def cache_public(max_age: U32, immutable: Bool) -> Cache.Policy: Cache.Public{max_age, immutable}
def cache_private(max_age: U32) -> Cache.Policy: Cache.Private{max_age}
def builtin_body_limit(id: Builtin.Builtin) -> Maybe<&2, U32>: Builtin.body_limit(id)

# Select BodyLimit tags before reading request payloads, using original scopes.
def serve_limits_with(~Vars: Data, ~Tag: Data, ~select: Tag -> Maybe<&2, U32>, ~Env: Data, ~dispatch: Tag -> Context.Ctx<Vars> -> Env -> IO(Response.Res), ~middleware: Tag -> Context.Ctx<Vars> -> Env -> (Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res), table: Table.Table<Tag>, env: Env, config: Config.Config) -> IO(Unit):
  Serve.run_limits_with(~Vars, ~Tag, ~select, ~Env, ~dispatch, ~middleware, table, env, config)

# Server-Sent Events over the same pull producer transport.
def SseConfig() -> Data: SseTypes.Config
def SseStep(-State: Type) -> Type: SseTypes.Step<State>
def SseFrame() -> Data: SseCodec.Frame
def sse_config() -> SseTypes.Config: Sse.defaults()
def sse_message(event: Maybe<&2, String>, data: String, id: Maybe<&2, String>, retry: Maybe<&2, U32>) -> SseCodec.Frame: Sse.message(event, data, id, retry)
def sse_data(data: String) -> SseCodec.Frame: Sse.message(None{}, data, None{}, None{})
def sse_comment(text: String) -> SseCodec.Frame: Sse.comment_frame(text)
def last_event_id(-Vars: Data, c: Context.Ctx<Vars>) -> Maybe<&2, String>: Sse.last_event_id(Vars, c)
def stream_sse(~Vars: Data, ~State: Type, ~step: State -> IO(SseTypes.Step<State>), ~cleanup: State -> IO(Unit), c: Context.Ctx<Vars>, state: State, +config: SseTypes.Config) -> IO(Response.Res):
  do IO<Response.Res>:
    now : Nat <- IO.now()
    stream(~Vars, ~SseTypes.Pump<State>, ~(p => Sse.pull(~State, ~step, p)), ~(p => Sse.release(~State, ~cleanup, p)), Sse.headers(Vars, c), SseTypes.Pump{state, config, now}, Sse.stream_config(config))

# Connection info: the socket peer from getpeername, never a client header.
def ConnInfo() -> Data: Conn.ConnInfo
def conn_info(-Vars: Data, c: Context.Ctx<Vars>) -> Maybe<&2, Conn.ConnInfo>: Context.conn_info(Vars, c)
def remote_address(info: Conn.ConnInfo) -> String: Conn.text(info)
def remote_port(info: Conn.ConnInfo) -> U32: Conn.port(info)
def address_type(info: Conn.ConnInfo) -> String: Ip.address_type(Conn.address(info))

# IP allow and deny lists. Deny wins; an empty allow list admits everyone not
# denied. trusted lists proxies whose X-Forwarded-For is believed (default none).
def IpPolicy() -> Data: IpRestriction.Policy
def ip_policy(deny: List<&2, String>, allow: List<&2, String>, trusted: List<&2, String>) -> Maybe<&2, IpRestriction.Policy>: IpRestriction.policy(deny, allow, trusted)
def ip_rules(deny: List<&2, String>, allow: List<&2, String>) -> Maybe<&2, IpRestriction.Policy>: IpRestriction.policy(deny, allow, [])
def ip_restriction(policy: IpRestriction.Policy) -> Builtin.Builtin: Builtin.IpRestriction{policy}
# The client address after the trusted-proxy rule, canonical text.
def client_address(-Vars: Data, c: Context.Ctx<Vars>, trusted: List<&2, Ip.Cidr>) -> Maybe<&2, String>:
  RateLimit.key_option(IpRestriction.client(Vars, c, trusted))
def Cidr() -> Data: Ip.Cidr
def cidrs(ranges: List<&2, String>) -> Maybe<&2, List<&2, Ip.Cidr>>: Ip.parse_cidrs(ranges)

# Rate limiting on a store actor. Create the limiter at startup, keep it in
# env and call B.rate_limit from a middleware case.
def RateLimitPolicy() -> Data: RateCore.Policy
def RateLimitConfig() -> Data: RateLimit.Config
def RateLimiter() -> Data: RateLimit.Limiter
def fixed_window(limit: Nat, window_ms: Nat) -> RateCore.Policy: RateCore.fixed_window_policy(limit, window_ms)
def token_bucket(capacity: Nat, refill: Nat, every_ms: Nat) -> RateCore.Policy: RateCore.token_bucket_policy(capacity, refill, every_ms)
def rate_limit_config(name: String, policy: RateCore.Policy, max_keys: Nat, trusted: List<&2, Ip.Cidr>) -> RateLimit.Config: RateLimit.Config{name, policy, max_keys, trusted, RateCore.AllowUntracked{}}
# What a new key gets while the key table is full of live entries.
def RateLimitSaturation() -> Data: RateCore.Saturation
def saturation_allow() -> RateCore.Saturation: RateCore.AllowUntracked{}
def saturation_shared() -> RateCore.Saturation: RateCore.SharedQuota{}
def saturation_evict() -> RateCore.Saturation: RateCore.EvictOldest{}
def rate_limit_saturation(config: RateLimit.Config, mode: RateCore.Saturation) -> RateLimit.Config: RateLimit.with_saturation(config, mode)
# Monitoring counters: tracked keys, requests that met a full table, saturated now.
def RateLimitStats() -> Data: RateCore.Stats
def rate_limit_stats(limiter: RateLimit.Limiter) -> IO(Result<&2, &2, Store.Error, RateCore.Stats>): RateLimit.stats(limiter)
def stats_tracked(s: RateCore.Stats) -> Nat:
  RateCore.Stats{tracked, saturated, saturating} = s
  tracked
def stats_saturated(s: RateCore.Stats) -> Nat:
  RateCore.Stats{tracked, saturated, saturating} = s
  saturated
def stats_saturating(s: RateCore.Stats) -> Bool:
  RateCore.Stats{tracked, saturated, saturating} = s
  saturating
def rate_limiter(policy: RateCore.Policy) -> IO(RateLimit.Limiter): RateLimit.limiter(RateLimit.config(policy))
def rate_limiter_with(config: RateLimit.Config) -> IO(RateLimit.Limiter): RateLimit.limiter(config)
def rate_limit(-Vars: Data, limiter: RateLimit.Limiter, c: Context.Ctx<Vars>, next: Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res):
  RateLimit.limit(Vars, limiter, c, next)
def rate_limit_with(-Vars: Data, limiter: RateLimit.Limiter, key: String, now_ms: Nat, c: Context.Ctx<Vars>, next: Context.Ctx<Vars> -> IO(Response.Res)) -> IO(Response.Res):
  RateLimit.limit_with(Vars, limiter, key, now_ms, c, next)
