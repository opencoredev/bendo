# BND-68: each hot-path rewrite equals its retained definition for every
# input, so every earlier law about the original carries over unchanged.
import Base
import ../src/data/utf8.bend as Utf8
import ../src/http/bytes.bend as Bytes
import ../src/http/response.bend as Response
import ../src/app/context.bend as Context
import ../src/http/request.bend as Request
import ../src/http/connection.bend as Connection
import ../src/http/body.bend as Body
import ../src/http/parse.bend as Parse
import ../src/data/json.bend as Json
import ../src/http/stream_marker.bend as Marker
import ../src/mw/cors.bend as Cors
import ../src/mw/secure_headers.bend as SecureHeaders
import ../src/mw/cors_policy.bend as CorsPolicy
import ../src/mw/cors_request.bend as CorsRequest
import ../src/mw/response_policy.bend as ResponsePolicy
import ../src/mw/builtin_core.bend as Builtin
import ../src/mw/jwt_config.bend as JwtConfig

law hot_utf8_encode_char:
  for +c: U32
  {Utf8.encode_char(c) == Utf8.encode_char_spec(c) : List<&2, U32>}

law hot_bytes_tchar:
  for +c: U32
  {Bytes.tchar(c) == Bytes.tchar_spec(c) : Bool}

law hot_response_utf8:
  for +s: String
  {Response.utf8(s) == Response.utf8_spec(s) : List<&2, U32>}

law hot_context_text:
  for -Vars: Data
  for +c: Context.Ctx<Vars>
  for +value: String
  {Context.text(Vars, c, value) == Context.text_spec(Vars, c, value) : Response.Res}

law hot_context_html:
  for -Vars: Data
  for +c: Context.Ctx<Vars>
  for +value: String
  {Context.html(Vars, c, value) == Context.html_spec(Vars, c, value) : Response.Res}

law hot_context_json_result:
  for -Vars: Data
  for +c: Context.Ctx<Vars>
  for +result: Result<&2, &2, Json.Error, String>
  {Context.json_result(Vars, c, result) == Context.json_result_spec(Vars, c, result) : Response.Res}

# CORS retains one policy per request. For an actual (non-preflight)
# request it equals the policy the response used to be built with.
law hot_cors_actual:
  for +config: CorsPolicy.Config
  for +g: Maybe<&2, CorsPolicy.Grant>
  for +requested: Maybe<&2, String>
  for +res: Response.Res
  {ResponsePolicy.apply(CorsRequest.chosen(config, g, requested, False{}), res) == Cors.actual(config, g, res) : Response.Res}

law hot_cors_policy:
  for +config: CorsPolicy.Config
  for +req: Request.Req
  {CorsRequest.chosen(config, CorsRequest.grant(config, req), CorsRequest.requested(req), CorsRequest.preflight(req)) == CorsRequest.policy(config, req) : ResponsePolicy.Policy}

# Secure headers run a policy prepared at registration; the per-config
# middleware is that same shell with the policy built from its config.
law hot_secure_prepared:
  for -Vars: Data
  for +config: SecureHeaders.Config
  for +c: Context.Ctx<Vars>
  for next: Context.Ctx<Vars> -> IO(Response.Res)
  {SecureHeaders.middleware(Vars, config, c, next) == SecureHeaders.prepared(Vars, SecureHeaders.policy(config), c, next) : IO(Response.Res)}

# The prepared shell with the config's policy runs exactly the pre-BND-68
# middleware: next, then the retained policy, then the decorated response.
law hot_secure_prepared_spec:
  for -Vars: Data
  for +config: SecureHeaders.Config
  for +c: Context.Ctx<Vars>
  for next: Context.Ctx<Vars> -> IO(Response.Res)
  {SecureHeaders.prepared(Vars, SecureHeaders.policy(config), c, next) == SecureHeaders.middleware_spec(Vars, config, c, next) : IO(Response.Res)}

# Registering SecurePrepared{policy(config)}, as secure_headers_with now
# does, runs the pre-BND-68 middleware and the SecureHeaders{config}
# registration it replaced. src/mw/builtin.bend's dispatch is dispatch_with
# with the Server-Timing and JWT middleware as templates; these laws hold for
# any templates.
law hot_secure_dispatch:
  for ~timing: @-V:Data -> @+c:Context.Ctx<V> -> (Context.Ctx<V> -> IO(Response.Res)) -> IO(Response.Res)
  for ~jwt: @-V:Data -> JwtConfig.Config -> Context.Ctx<V> -> (Context.Ctx<V> -> IO(Response.Res)) -> IO(Response.Res)
  for -Vars: Data
  for +config: SecureHeaders.Config
  for +c: Context.Ctx<Vars>
  for next: Context.Ctx<Vars> -> IO(Response.Res)
  {Builtin.dispatch_with(~timing, ~jwt, Vars, Builtin.SecurePrepared{SecureHeaders.policy(config)}, c, next) == SecureHeaders.middleware_spec(Vars, config, c, next) : IO(Response.Res)}

law hot_secure_dispatch_registration:
  for ~timing: @-V:Data -> @+c:Context.Ctx<V> -> (Context.Ctx<V> -> IO(Response.Res)) -> IO(Response.Res)
  for ~jwt: @-V:Data -> JwtConfig.Config -> Context.Ctx<V> -> (Context.Ctx<V> -> IO(Response.Res)) -> IO(Response.Res)
  for -Vars: Data
  for +config: SecureHeaders.Config
  for +c: Context.Ctx<Vars>
  for next: Context.Ctx<Vars> -> IO(Response.Res)
  {Builtin.dispatch_with(~timing, ~jwt, Vars, Builtin.SecurePrepared{SecureHeaders.policy(config)}, c, next) == Builtin.dispatch_with(~timing, ~jwt, Vars, Builtin.SecureHeaders{config}, c, next) : IO(Response.Res)}

# The CORS middleware runs exactly the pre-BND-68 sequence for every config,
# context and continuation: a preflight is answered without next, any other
# request runs next and is decorated, and the same policy is retained.
law hot_cors_middleware:
  for -Vars: Data
  for +config: CorsPolicy.Config
  for +c: Context.Ctx<Vars>
  for next: Context.Ctx<Vars> -> IO(Response.Res)
  {Cors.middleware(Vars, config, c, next) == Cors.middleware_spec(Vars, config, c, next) : IO(Response.Res)}

law hot_connection_header_hit:
  for +n: String
  for +v: List<&2, U32>
  for +wanted: String
  {Connection.header_hit(n, v, wanted) == Connection.header_hit_spec(n, v, wanted) : Bool}

# The request-head scan of Body.head_feed. proof/hot-path.bend proves the
# same equation for every policy template that Connection instantiates.
law hot_body_head_feed:
  for +xs: List<&2, U32>
  for +s: Parse.State
  for +bytes: U32
  for +limit: U32
  for +headers: U32
  {Body.head_feed_policy(~U32, ~(req => n => n), limit, xs, s, bytes, limit, headers) == Body.head_feed_policy_spec(~U32, ~(req => n => n), limit, xs, s, bytes, limit, headers) : Body.State & Bool}

# The same equation for any policy type, selector template and policy value.
law hot_body_head_feed_policy:
  for ~Policy: Data
  for ~select: Request.Req -> Policy -> U32
  for +policy: Policy
  for +xs: List<&2, U32>
  for +s: Parse.State
  for +bytes: U32
  for +limit: U32
  for +headers: U32
  {Body.head_feed_policy(~Policy, ~select, policy, xs, s, bytes, limit, headers) == Body.head_feed_policy_spec(~Policy, ~select, policy, xs, s, bytes, limit, headers) : Body.State & Bool}

# BND-96: the stream-marker name test lowers one character at a time and
# stops at the first difference, instead of lowering the whole field name.
# For every name it answers what the lowered comparison did, so the marker
# laws (transport eligibility, finalized delivery, WebSocket fields) carry over.
law hot_marker_named:
  for +name: String
  {Marker.named(name) == Marker.named_spec(name) : Bool}
