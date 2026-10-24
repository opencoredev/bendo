# Middleware

Bendo's built-in middleware are `B.Builtin` values. Wrap one in a case of
your own middleware tag, register it with `B.use`, `B.use_path` or a lifecycle
hook, and hand that case to `B.builtin` in your middleware dispatcher.
[Middleware](../../middleware.md) explains the onion and the dispatcher; this
page lists the calls. The rate limiter and `Cors.middleware` are called
directly from a middleware case instead.

Examples on this page are one Bend program and share this setup:

```bend
import Base
import ./bendo/main.bend as B
import ./bendo/app/context.bend as C
import ./bendo/data/json.bend as J
import ./bendo/crypto/jwt.bend as Jwt
import ./bendo/mw/cors.bend as Cors
import ./bendo/mw/cors_policy.bend as CorsPolicy

type Tag is Data:
  Home{}
  Builtin{id: B.Builtin}

def ex_or_none(cs: Maybe<&2, List<&2, B.Cidr>>) -> List<&2, B.Cidr>:
  match cs:
    case Some{x}: x
    case None{}: []
```

## Built-in identifiers

### `B.Builtin`

```bend signature
def Builtin() -> Data
```

The type of every built-in middleware identifier. It is `Data`, so it can sit
in your tag and in the route table. Its constructors are internal; build values
with the functions on this page.

```bend
def ex_wrap(id: B.Builtin) -> Tag:
  Builtin{id}
```

### `B.builtin`

```bend signature
def builtin(-Vars: Data, id: B.Builtin, c: B.Context(Vars), next: B.Context(Vars) -> IO(B.Res)) -> IO(B.Res)
```

Runs the built-in `id` around `next`. Call it from the case of your
middleware dispatcher that holds the wrapped `B.Builtin`. It works with any
typed `Vars`.

```bend
def ex_middleware(tag: Tag, c: B.Context(Unit), env: Unit, next: B.Context(Unit) -> IO(B.Res)) -> IO(B.Res):
  match tag:
    case Builtin{id}: B.builtin(Unit, id, c, next)
    case _: next(c)
```

## Observability

[Observability middleware](../../observability.md) has the exact formats and
how each built-in behaves in lifecycle hooks.

### `B.logger`

```bend signature
def logger() -> B.Builtin
```

Writes one line to stderr after `next` returns:
`<METHOD> <PATH> <STATUS> <DURATION>ms`, plus ` id=<REQUEST_ID>` when the
response has a safe request ID. The duration comes from the monotonic clock.
Queries, headers and bodies are never logged. Register it first to observe
every inner layer.

```bend
def ex_logged() -> List<&2, B.Registration(Tag)>:
  [B.use(Tag, Builtin{B.logger()}), B.get(Tag, "/", Home{})]
```

### `B.request_id`

```bend signature
def request_id() -> B.Builtin
```

Reuses the incoming `X-Request-Id` when it is 1 to 200 characters from
`A-Z a-z 0-9 . _ -`, and otherwise generates 32 lowercase hex digits from 16
random bytes. The ID is set on the response and readable in handlers with
`C.request_id`. If the system cannot supply random bytes, the response is an
empty 500 and the handler does not run.

```bend
def ex_traced() -> List<&2, B.Registration(Tag)>:
  [B.on_request(Tag, Builtin{B.request_id()}), B.get(Tag, "/", Home{})]
```

### `B.server_timing`

```bend signature
def server_timing() -> B.Builtin
```

Adds `Server-Timing: total;dur=<ms>` for its inner chain, followed by every
mark recorded with `B.timing_mark`. A `Server-Timing` header the app sets
itself wins.

```bend
def ex_timing() -> List<&2, B.Registration(Tag)>:
  [B.use(Tag, Builtin{B.server_timing()}), B.get(Tag, "/", Home{})]
```

### `B.timing_mark`

```bend signature
def timing_mark(-Vars: Data, c: B.Context(Vars), name: String, duration_ms: Nat) -> IO(Bool)
```

Adds a metric to the `Server-Timing` header. It returns `False` when no
`B.server_timing` middleware is active or the write fails. Names are encoded
as tokens prefixed with `mark_`, so `db` appears as `mark_db` and can never
replace `total`.

```bend
def ex_timed(+c: B.Context(Unit)) -> IO(B.Res):
  do IO<B.Res>:
    start : Nat <- IO.now()
    stop : Nat <- IO.now()
    ok : Bool <- B.timing_mark(Unit, c, "db", Nat.sub(stop, start))
    return C.text(Unit, c, "ok")
```

### `B.powered_by`

```bend signature
def powered_by(name: String) -> B.Builtin
```

Sets or replaces `X-Powered-By` with `name` after `next`. Bendo sends no such
header unless you register this. An invalid header value becomes a 500 in
response validation.

```bend
def ex_branded() -> List<&2, B.Registration(Tag)>:
  [B.map_response(Tag, Builtin{B.powered_by("Bendo")}), B.get(Tag, "/", Home{})]
```

### `B.pretty_json`

```bend signature
def pretty_json() -> B.Builtin
```

When the query has a `pretty` key (any value, or none), re-renders an
`application/json` response with two-space indentation and drops validators
such as `ETag` that described the old body. Other responses, invalid JSON,
encoded and partial responses pass through unchanged. It buffers and reparses
the body, so use it for debugging.

```bend
def ex_pretty() -> List<&2, B.Registration(Tag)>:
  [B.use(Tag, Builtin{B.pretty_json()}), B.get(Tag, "/", Home{})]
```

## Authentication and CSRF

[Authentication middleware](../../auth.md) has the full rules, status codes
and challenges. Load secrets from the environment at startup; never commit
them.

### `B.Credential`, `B.credential`

```bend signature
def Credential() -> Data
def credential(username: String, password: String) -> B.Credential
```

One user name and password pair for `B.basic_auth`. The user name cannot
contain a colon; the password can.

```bend
def ex_users() -> List<&2, B.Credential>:
  [B.credential("ada", "correct horse")]
```

### `B.basic_auth`

```bend signature
def basic_auth(realm: String, users: List<&2, B.Credential>) -> B.Builtin
```

Admits a request whose `Authorization: Basic` credentials match one of
`users`. Anything else gets 401 `Unauthorized` with
`WWW-Authenticate: Basic realm="<realm>", charset="UTF-8"`. Every pair is
compared on every request, through SHA-256 digests and a comparison with no
early exit.

```bend
def ex_admin_auth() -> B.Registration(Tag):
  B.use_path(Tag, "/admin/*", Builtin{B.basic_auth("admin", ex_users())})
```

### `B.bearer_auth`

```bend signature
def bearer_auth(realm: String, tokens: List<&2, String>) -> B.Builtin
```

Admits a request whose `Authorization: Bearer` token is one of `tokens`. A
missing header or an unlisted token gets 401; another scheme or a token
outside the `b64token` syntax gets 400. Each carries an RFC 6750 challenge
naming `realm`.

```bend
def ex_api_auth() -> B.Registration(Tag):
  B.use_path(Tag, "/api/*", Builtin{B.bearer_auth("api", ["a-long-random-token"])})
```

### `B.csrf`, `B.csrf_host`

```bend signature
def csrf(origins: List<&2, String>) -> B.Builtin
def csrf_host(scheme: String, origins: List<&2, String>) -> B.Builtin
```

Rejects cross-site form requests with 403 `Forbidden`. Only requests a
cross-site HTML form could send without a preflight are inspected: methods
other than GET and HEAD with a form `Content-Type`, `text/plain`, a malformed
one or none. A request passes when `Sec-Fetch-Site` is `same-origin` or its
`Origin` (or, without one, its `Referer`) is in `origins`. `B.csrf_host` also
trusts `scheme://` plus the request's `Host`, unless `Sec-Fetch-Site` is
`cross-site`; use it only when you know the scheme browsers use. See
[which constructor to use](../../auth.md#which-constructor-to-use).

```bend
def ex_forms() -> List<&2, B.Registration(Tag)>:
  [
    B.use_path(Tag, "/account/*", Builtin{B.csrf(["https://app.example"])}),
    B.use_path(Tag, "/admin/*", Builtin{B.csrf_host("https", ["https://admin.example"])})
  ]
```

## JWT

HS256 only, with a UTF-8 secret. The rejection rules are listed in
[JWT](../../auth.md#jwt).

### `B.JwtConfig`, `B.jwt_config`

```bend signature
def JwtConfig() -> Data
def jwt_config(secret: String, leeway: Nat, realm: String) -> B.JwtConfig
```

The settings for `B.jwt` and `B.jwt_with`. `leeway` is the allowed clock skew
in seconds, applied to `exp`, `nbf` and `iat`. `realm` goes in the
`WWW-Authenticate` challenge.

```bend
def ex_jwt_config() -> B.JwtConfig:
  B.jwt_config("a-long-random-secret", 30n, "me")
```

### `B.jwt`

```bend signature
def jwt(config: B.JwtConfig) -> B.Builtin
```

Verifies the `Authorization: Bearer` token against the wall clock and calls
`next` when it is valid. A missing, malformed, badly signed or expired token
gets 401 with the reason in the challenge. If the wall clock fails, the
response is an empty 500. Tokens in cookies are not read.

```bend
def ex_jwt_route() -> B.Registration(Tag):
  B.use_path(Tag, "/me/*", Builtin{B.jwt(ex_jwt_config())})
```

### `B.jwt_with`

```bend signature
def jwt_with(-Vars: Data, config: B.JwtConfig, c: B.Context(Vars), next: J.Json -> B.Context(Vars) -> IO(B.Res)) -> IO(B.Res)
```

`B.jwt` as a call from your own middleware case, passing the verified claim
set (always a `J.JObject`) to `next` along with the context. Store the claims
in your typed variables so handlers can read them.

```bend
type Session is Data:
  Session{claims: J.Json}

def ex_claims(c: B.Context(Session), next: B.Context(Session) -> IO(B.Res)) -> IO(B.Res):
  B.jwt_with(Session, ex_jwt_config(), c, claims => ctx => next(C.set(Session, ctx, Session{claims})))
```

### `B.JwtError`

```bend signature
def JwtError() -> Data

type Error is Data:
  Malformed{}
  BadSignature{}
  BadEncoding{}
  BadHeader{}
  BadAlgorithm{}
  BadClaims{}
  BadClaim{name: String}
  DuplicateMember{}
  TooManyMembers{}
  Expired{}
  NotYetValid{}
  IssuedInFuture{}
  Unwritable{}
```

Why signing or verifying a token failed. The constructors live in
`bendo/crypto/jwt.bend`; import it to match them, or call its `error_text`
for the message the middleware puts in its challenge.

```bend
def ex_jwt_reason(e: B.JwtError) -> String:
  Jwt.error_text(e)

def ex_expired(e: B.JwtError) -> Bool:
  match e:
    case Jwt.Expired{}: True{}
    case _: False{}
```

### `B.jwt_sign`

```bend signature
def jwt_sign(secret: String, claims: J.Json) -> Result<&2, &2, B.JwtError, String>
```

Signs `claims` with the header `{"alg":"HS256","typ":"JWT"}`. It fails with
`BadClaims` when `claims` is not a JSON object, and with `DuplicateMember` or
`TooManyMembers` (over 256 members) when verifying the token would fail.

```bend
def ex_token() -> Result<&2, &2, B.JwtError, String>:
  B.jwt_sign("a-long-random-secret", J.JObject{[J.Field{"sub", J.JString{"ada"}}, J.Field{"exp", J.JNumber{"2000000000"}}]})
```

### `B.jwt_verify`

```bend signature
def jwt_verify(secret: String, token: String, now: Nat, leeway: Nat) -> Result<&2, &2, B.JwtError, J.Json>
```

Checks the signature, the header and the time claims of `token` and returns
its claims. `now` is the current time in Unix seconds and `leeway` the allowed
skew in seconds. It is pure, so tests can pass any time.

```bend
def ex_check(token: String, now: Nat) -> Result<&2, &2, B.JwtError, J.Json>:
  B.jwt_verify("a-long-random-secret", token, now, 30n)
```

## Limits and caching

[Request limits and response caching](../../limits-cache.md) covers admission,
cooperative timeouts and conditional requests.

### `B.body_limit`

```bend signature
def body_limit(bytes: U32) -> B.Builtin
```

Answers 413 when the decoded request body is larger than `bytes`. As
ordinary middleware it checks the body after it is buffered. To refuse
oversized bodies before reading them, serve with `B.serve_limits_with` and a
selector built on `B.builtin_body_limit`. The server's own ceiling,
`Config.body_limit`, still applies; a route limit can only tighten it.

```bend
def ex_upload_limit() -> B.Registration(Tag):
  B.use_path(Tag, "/upload", Builtin{B.body_limit(4096)})
```

### `B.builtin_body_limit`

```bend signature
def builtin_body_limit(id: B.Builtin) -> Maybe<&2, U32>
```

The byte limit of a `B.body_limit` identifier, and `None` for every other
built-in. Use it in the pure selector you pass to `B.serve_limits_with`.

```bend
def ex_limit(tag: Tag) -> Maybe<&2, U32>:
  match tag:
    case Builtin{id}: B.builtin_body_limit(id)
    case _: None{}
```

### `B.timeout`

```bend signature
def timeout(milliseconds: U32) -> B.Builtin
```

Answers 504 when the inner chain takes longer than `milliseconds`. The
timeout does not cancel the inner work: a late handler can still change
stores or write files, and its response is discarded. Pure computation is
interrupted only at its next effect.

```bend
def ex_bounded() -> B.Registration(Tag):
  B.use(Tag, Builtin{B.timeout(1000)})
```

### `B.etag`

```bend signature
def etag() -> B.Builtin
```

Sets a strong `ETag` from the SHA-256 of the buffered body on 200 responses
to GET and HEAD, and answers 304 when `If-None-Match` matches. Other methods,
statuses and streamed responses pass through. Register it outside any
middleware that changes the body; it hashes every qualifying response.

```bend
def ex_validated() -> B.Registration(Tag):
  B.map_response(Tag, Builtin{B.etag()})
```

### `B.cache_control`

```bend signature
def cache_control(policy: Cache.Policy) -> B.Builtin
```

Sets one `Cache-Control` field after the inner chain. The policy type has no
public name; build one with the four constructors below. Register it with
`B.map_response` after `B.etag` so 304 responses carry it too.

```bend
def ex_cache_hooks() -> List<&2, B.Registration(Tag)>:
  [B.map_response(Tag, Builtin{B.etag()}), B.map_response(Tag, Builtin{B.cache_control(B.cache_no_cache())})]
```

### `B.cache_no_store`, `B.cache_no_cache`, `B.cache_public`, `B.cache_private`

```bend signature
def cache_no_store() -> Cache.Policy
def cache_no_cache() -> Cache.Policy
def cache_public(max_age: U32, immutable: Bool) -> Cache.Policy
def cache_private(max_age: U32) -> Cache.Policy
```

Policies for `B.cache_control`, sent as `no-store`, `no-cache`,
`public, max-age=<max_age>` (plus `, immutable` when `immutable` is true) and
`private, max-age=<max_age>`. `max_age` is in seconds. Avoid `public` for
personalized responses.

```bend
def ex_policies() -> List<&2, B.Registration(Tag)>:
  [
    B.use_path(Tag, "/account/*", Builtin{B.cache_control(B.cache_no_store())}),
    B.use_path(Tag, "/feed", Builtin{B.cache_control(B.cache_no_cache())}),
    B.use_path(Tag, "/assets/*", Builtin{B.cache_control(B.cache_public(31536000, True{}))}),
    B.use_path(Tag, "/me", Builtin{B.cache_control(B.cache_private(60))})
  ]
```

## CORS

[CORS](../../web-middleware.md#cors) explains origin matching, preflights and
`Vary`.

### `B.CorsConfig`

```bend signature
def CorsConfig() -> Data
```

A CORS policy: which origins get a grant, plus the methods, headers, exposed
headers and max age. It is `Data`, so build it once at startup and keep it in
`env` or in a `B.cors` identifier.

```bend
type CorsEnv is Data:
  CorsEnv{cors: B.CorsConfig}
```

### `B.CorsOrigin`, `CorsPolicy.Entry`

```bend signature
def CorsOrigin() -> Data

type Entry is Data:
  Entry{origin: String, credentials: Bool}
```

One allowed origin and whether its responses may carry credentials.
`CorsPolicy.Entry` is the same type, for code that imports
`mw/cors_policy.bend`. Build entries with `B.cors_origin` and
`B.cors_origin_credentials`.

```bend
def ex_dev_origins() -> List<&2, CorsPolicy.Entry>:
  [B.cors_origin("http://localhost:5173")]

def ex_same_origin_type(e: B.CorsOrigin) -> CorsPolicy.Entry:
  e
```

### `B.cors_origin`, `B.cors_origin_credentials`

```bend signature
def cors_origin(origin: String) -> B.CorsOrigin
def cors_origin_credentials(origin: String) -> B.CorsOrigin
```

An allowed origin for `B.cors_allow`. `B.cors_origin_credentials` also sends
`Access-Control-Allow-Credentials: true` to that origin. `origin` may be a
full URL; only its scheme, host and port count. Entries that are not http or
https URLs, or that spell a host differently from browsers (`http://127.1`),
are dropped.

```bend
def ex_origins() -> List<&2, B.CorsOrigin>:
  [B.cors_origin("https://app.example"), B.cors_origin_credentials("https://admin.example")]
```

### `B.cors_defaults`

```bend signature
def cors_defaults() -> B.CorsConfig
```

Answers every origin, including `null`, with `Access-Control-Allow-Origin: *`
and never allows credentials. The methods default to
`GET,HEAD,PUT,POST,DELETE,PATCH,QUERY`, and preflights reflect the requested
headers. It adds no `Vary: Origin`.

```bend
def ex_open_api() -> B.Registration(Tag):
  B.use(Tag, Builtin{B.cors(B.cors_defaults())})
```

### `B.cors_allow`

```bend signature
def cors_allow(origins: List<&2, B.CorsOrigin>) -> B.CorsConfig
```

Grants only the listed origins, echoing the request's serialized origin, with
the same default methods and headers as `B.cors_defaults`. Every response
varies by `Origin`. `Origin: null` and requests with two `Origin` fields get no
grant. Dropped entries are silent; use `B.cors_allow_checked` at startup to
report them.

```bend
def ex_listed() -> B.CorsConfig:
  B.cors_allow(ex_origins())
```

### `B.cors_allow_checked`

```bend signature
def cors_allow_checked(+origins: List<&2, B.CorsOrigin>) -> IO(B.CorsConfig)
```

`B.cors_allow`, run once at startup, printing one stderr line for each entry it
drops, such as
`bendo: cors: ignoring allowed origin "app.example": not an http or https URL`.

```bend
def ex_cors_startup() -> IO(CorsEnv):
  do IO<CorsEnv>:
    cors : B.CorsConfig <- B.cors_allow_checked(ex_origins())
    return CorsEnv{cors}
```

### `B.cors_methods`, `B.cors_headers`, `B.cors_expose`, `B.cors_max_age`

```bend signature
def cors_methods(config: B.CorsConfig, methods: List<&2, String>) -> B.CorsConfig
def cors_headers(config: B.CorsConfig, headers: List<&2, String>) -> B.CorsConfig
def cors_expose(config: B.CorsConfig, headers: List<&2, String>) -> B.CorsConfig
def cors_max_age(config: B.CorsConfig, seconds: Nat) -> B.CorsConfig
```

Replace one setting. Methods, headers and max age are sent on preflights as
`Access-Control-Allow-Methods`, `-Allow-Headers` and `-Max-Age`; exposed
headers on other responses as `Access-Control-Expose-Headers`. Without
configured headers, a preflight reflects the requested ones. For credentialed
origins, list header names: `"*"` is sent literally and browsers do not treat
it as a wildcard there.

```bend
def ex_tuned() -> B.CorsConfig:
  B.cors_max_age(B.cors_expose(B.cors_headers(B.cors_methods(ex_listed(), ["GET", "POST"]), ["content-type"]), ["x-request-id"]), 600n)
```

### `B.cors`

```bend signature
def cors(config: B.CorsConfig) -> B.Builtin
```

Answers a preflight (`OPTIONS` with `Origin` and
`Access-Control-Request-Method`) with an empty 204 without calling the
handler. On other requests it removes any CORS grant fields the app set and
adds its own for an allowed origin. A denied origin gets no CORS fields.

```bend
def ex_api_cors() -> B.Registration(Tag):
  B.use_path(Tag, "/api/*", Builtin{B.cors(ex_tuned())})
```

### `Cors.middleware`

```bend signature
def middleware(-Vars: Data, +config: B.CorsConfig, +c: B.Context(Vars), next: B.Context(Vars) -> IO(B.Res)) -> IO(B.Res)
```

The CORS middleware as a direct call, for a policy built at runtime and kept
in `env`, as in [examples/todo](../../../examples/todo/main.bend). It behaves
exactly like `B.cors(config)`.

```bend
def ex_cors_layer(env: CorsEnv, c: B.Ctx, next: B.Ctx -> IO(B.Res)) -> IO(B.Res):
  match env:
    case CorsEnv{cors}: Cors.middleware(Unit, cors, c, next)
```

### `B.report_rejected`

```bend signature
def report_rejected(+kind: String, xs: List<&2, String>) -> IO(Unit)
```

A low-level helper behind `B.cors_allow_checked` and
`B.websocket_origins_checked`. For each string in `xs` it prints
`bendo: <kind>: ignoring allowed origin "<x>": not an http or https URL` to
stderr. It does not check the strings itself; pass it the entries a policy
already rejected.

```bend
def ex_warn(dropped: List<&2, String>) -> IO(Unit):
  B.report_rejected("cors", dropped)
```

## Secure headers

[Secure headers](../../web-middleware.md#secure-headers) lists every default
header and why it is sent.

### `B.SecureConfig`, `B.secure_defaults`

```bend signature
def SecureConfig() -> Data
def secure_defaults() -> B.SecureConfig
```

The header set for `B.secure_headers_with`. `B.secure_defaults` is the set
`B.secure_headers` sends; change it with the functions below.

```bend
def ex_csp() -> B.SecureConfig:
  B.secure_set(B.secure_defaults(), "Content-Security-Policy", "default-src 'self'")
```

### `B.secure_set`, `B.secure_unset`, `B.secure_keep_powered_by`

```bend signature
def secure_set(config: B.SecureConfig, name: String, value: String) -> B.SecureConfig
def secure_unset(config: B.SecureConfig, name: String) -> B.SecureConfig
def secure_keep_powered_by(config: B.SecureConfig) -> B.SecureConfig
```

`B.secure_set` adds a header or replaces its value. `B.secure_unset` stops
sending one, so the app's own value passes through. `B.secure_keep_powered_by`
leaves `X-Powered-By` in place. Names ignore case; an invalid name or value
becomes a 500 in response validation.

```bend
def ex_framed() -> B.SecureConfig:
  B.secure_keep_powered_by(B.secure_unset(B.secure_set(B.secure_defaults(), "X-Frame-Options", "DENY"), "Strict-Transport-Security"))
```

### `B.secure_headers`, `B.secure_headers_with`

```bend signature
def secure_headers() -> B.Builtin
def secure_headers_with(config: B.SecureConfig) -> B.Builtin
```

Sets security headers after `next`, replacing any value the app set, and
removes `X-Powered-By`. `B.secure_headers` uses Hono's eleven defaults;
`B.secure_headers_with` uses `config`. Neither sends
`Content-Security-Policy` or `Cross-Origin-Embedder-Policy` unless you add it.

```bend
def ex_hardened() -> List<&2, B.Registration(Tag)>:
  [B.use(Tag, Builtin{B.secure_headers()}), B.use_path(Tag, "/app/*", Builtin{B.secure_headers_with(ex_csp())})]
```

## Method override

### `B.method_override`, `B.method_override_form`, `B.method_override_header`

```bend signature
def method_override() -> B.Builtin
def method_override_form(field: String, methods: List<&2, String>) -> B.Builtin
def method_override_header(name: String, methods: List<&2, String>) -> B.Builtin
```

Lets a POST ask for another method. `B.method_override` reads the `_method`
form field and allows PUT, PATCH and DELETE; the other two read another form
field or a request header and allow `methods`. Forms are read from urlencoded
and multipart bodies. A listed value replaces the method; an unlisted value,
two values or an unreadable form get 400. GET, HEAD, OPTIONS, CONNECT and
TRACE are never produced. Register these with `B.on_request`, the only stage
before routing. See [method override](../../web-middleware.md#method-override).

```bend
def ex_overrides() -> List<&2, B.Registration(Tag)>:
  [
    B.on_request(Tag, Builtin{B.method_override()}),
    B.on_request(Tag, Builtin{B.method_override_form("_action", ["PUT", "DELETE"])}),
    B.on_request(Tag, Builtin{B.method_override_header("X-HTTP-Method-Override", ["PATCH"])})
  ]
```

## Trailing slash

Redirects apply to GET and HEAD only, with 301 and the raw query kept. `/` is
never trimmed, and a target that would leave the origin, such as
`//evil.example`, is not sent. See
[trailing slash](../../web-middleware.md#trailing-slash).

### `B.trim_trailing_slash`, `B.append_trailing_slash`

```bend signature
def trim_trailing_slash() -> B.Builtin
def append_trailing_slash() -> B.Builtin
```

When the route answers 404, redirect `/about/` to `/about`, or `/about` to
`/about/`. They need the route's answer, so register them with `B.use`.

```bend
def ex_slashes() -> List<&2, B.Registration(Tag)>:
  [B.use(Tag, Builtin{B.trim_trailing_slash()}), B.use_path(Tag, "/docs/*", Builtin{B.append_trailing_slash()})]
```

### `B.trim_trailing_slash_always`, `B.append_trailing_slash_always`

```bend signature
def trim_trailing_slash_always() -> B.Builtin
def append_trailing_slash_always() -> B.Builtin
```

Redirect before calling `next`, whether or not a route exists. Register them
with `B.on_request` to redirect before routing and before other middleware.

```bend
def ex_canonical() -> List<&2, B.Registration(Tag)>:
  [B.on_request(Tag, Builtin{B.trim_trailing_slash_always()}), B.use_path(Tag, "/blog/*", Builtin{B.append_trailing_slash_always()})]
```

## IP restriction

[IP restriction](../../connection.md#ip-restriction) covers the address
syntax, IPv4-mapped addresses and the forwarded-address rule.

### `B.IpPolicy`

```bend signature
def IpPolicy() -> Data
```

Parsed deny and allow ranges plus the trusted proxies. Build one at startup
with `B.ip_rules` or `B.ip_policy`.

```bend
def ex_ip_ready(p: Maybe<&2, B.IpPolicy>) -> IO(B.IpPolicy):
  match p:
    case Some{policy}: IO.pure(B.IpPolicy, policy)
    case None{}: IO.die(B.IpPolicy, 1, "invalid IP rules")
```

### `B.ip_rules`, `B.ip_policy`

```bend signature
def ip_rules(deny: List<&2, String>, allow: List<&2, String>) -> Maybe<&2, B.IpPolicy>
def ip_policy(deny: List<&2, String>, allow: List<&2, String>, trusted: List<&2, String>) -> Maybe<&2, B.IpPolicy>
```

Each entry is an address or a CIDR range such as `10.0.0.0/8` or
`2001:db8::/32`. The result is `None` if any entry fails to parse, so a typo
stops the app instead of opening a hole. `B.ip_rules` trusts no proxies;
`B.ip_policy` reads `X-Forwarded-For` when the socket peer is in `trusted`.

```bend
def ex_rules() -> Maybe<&2, B.IpPolicy>:
  B.ip_rules(["203.0.113.0/24"], [])

def ex_behind_proxy() -> Maybe<&2, B.IpPolicy>:
  B.ip_policy([], ["10.0.0.0/8"], ["10.0.0.1"])
```

### `B.ip_restriction`

```bend signature
def ip_restriction(policy: B.IpPolicy) -> B.Builtin
```

Refuses a client in a deny range, admits everyone else when the allow list is
empty, and otherwise admits only clients in an allow range. A request with no
known client address is refused unless both lists are empty. Refusals get 403
`Forbidden`, as text or JSON depending on `Accept`.

```bend
def ex_admin_ip(policy: B.IpPolicy) -> B.Registration(Tag):
  B.use_path(Tag, "/admin/*", Builtin{B.ip_restriction(policy)})
```

### `B.Cidr`, `B.cidrs`

```bend signature
def Cidr() -> Data
def cidrs(ranges: List<&2, String>) -> Maybe<&2, List<&2, B.Cidr>>
```

Parsed address ranges, for the `trusted` arguments of `B.rate_limit_config`
and `B.client_address`. The result is `None` if any entry fails to parse. A
bare address is a single host.

```bend
def ex_proxies() -> List<&2, B.Cidr>:
  ex_or_none(B.cidrs(["10.0.0.0/8"]))
```

## Rate limiting

The limiter keeps its counts in a [store](../../store.md), one per process,
so create it at startup and keep it in `env`. [Rate limiting](../../connection.md#rate-limiting)
explains the `RateLimit` fields, out-of-order requests and saturation.

### `B.RateLimitPolicy`, `B.fixed_window`, `B.token_bucket`

```bend signature
def RateLimitPolicy() -> Data
def fixed_window(limit: Nat, window_ms: Nat) -> B.RateLimitPolicy
def token_bucket(capacity: Nat, refill: Nat, every_ms: Nat) -> B.RateLimitPolicy
```

How requests are counted. `B.fixed_window` allows `limit` requests per window
of `window_ms`, aligned to multiples of `window_ms`. `B.token_bucket` allows
bursts of `capacity` and returns `refill` tokens every `every_ms`; each request
takes one. Zero for `window_ms`, `refill` or `every_ms` becomes 1, and a zero
limit or capacity refuses every request.

```bend
def ex_per_minute() -> B.RateLimitPolicy:
  B.fixed_window(100n, 60000n)

def ex_bursty() -> B.RateLimitPolicy:
  B.token_bucket(10n, 1n, 1000n)
```

### `B.RateLimiter`, `B.rate_limiter`

```bend signature
def RateLimiter() -> Data
def rate_limiter(policy: B.RateLimitPolicy) -> IO(B.RateLimiter)
```

Starts a limiter with `policy`, the policy name `"default"`, room for 10,000
keys and no trusted proxies. The handle is `Data`.

```bend
type LimitEnv is Data:
  LimitEnv{limiter: B.RateLimiter}

def ex_limit_startup() -> IO(LimitEnv):
  do IO<LimitEnv>:
    limiter : B.RateLimiter <- B.rate_limiter(ex_per_minute())
    return LimitEnv{limiter}
```

### `B.RateLimitConfig`, `B.rate_limit_config`

```bend signature
def RateLimitConfig() -> Data
def rate_limit_config(name: String, policy: B.RateLimitPolicy, max_keys: Nat, trusted: List<&2, B.Cidr>) -> B.RateLimitConfig
```

Limiter settings for `B.rate_limiter_with`. `name` is the policy name in the
`RateLimit` fields, `max_keys` bounds the key table, and `trusted` lists
proxies whose `X-Forwarded-For` picks the client address. Saturation starts
as `B.saturation_allow`.

```bend
def ex_config() -> B.RateLimitConfig:
  B.rate_limit_config("api", ex_bursty(), 50000n, ex_proxies())
```

### `B.rate_limiter_with`

```bend signature
def rate_limiter_with(config: B.RateLimitConfig) -> IO(B.RateLimiter)
```

Starts a limiter with `config`.

```bend
def ex_api_limiter() -> IO(B.RateLimiter):
  B.rate_limiter_with(ex_config())
```

### `B.RateLimitSaturation`, `B.saturation_allow`, `B.saturation_shared`, `B.saturation_evict`

```bend signature
def RateLimitSaturation() -> Data
def saturation_allow() -> B.RateLimitSaturation
def saturation_shared() -> B.RateLimitSaturation
def saturation_evict() -> B.RateLimitSaturation
```

What a new key gets when the key table is full of live entries.
`B.saturation_allow`, the default, lets it pass uncounted and without
`RateLimit` fields. `B.saturation_shared` counts every such key against one
shared entry, so a flood of new keys gets 429. `B.saturation_evict` replaces
the least recently used key, whose count then starts over.

```bend
def ex_modes() -> List<&2, B.RateLimitSaturation>:
  [B.saturation_allow(), B.saturation_shared(), B.saturation_evict()]
```

### `B.rate_limit_saturation`

```bend signature
def rate_limit_saturation(config: B.RateLimitConfig, mode: B.RateLimitSaturation) -> B.RateLimitConfig
```

Sets the saturation mode of `config`.

```bend
def ex_strict() -> IO(B.RateLimiter):
  B.rate_limiter_with(B.rate_limit_saturation(ex_config(), B.saturation_shared()))
```

### `B.rate_limit`

```bend signature
def rate_limit(-Vars: Data, limiter: B.RateLimiter, c: B.Context(Vars), next: B.Context(Vars) -> IO(B.Res)) -> IO(B.Res)
```

Counts the request against its client address, from the socket peer or a
trusted proxy's `X-Forwarded-For`, using `IO.now`. An allowed request runs
`next` and gets `RateLimit-Policy` and `RateLimit` fields; a refused one gets
429 with those fields and `Retry-After`. If the store does not answer, the
response is 503. Requests with no socket peer share the key `unknown`.

```bend
def ex_limited(env: LimitEnv, c: B.Context(Unit), next: B.Context(Unit) -> IO(B.Res)) -> IO(B.Res):
  match env:
    case LimitEnv{limiter}: B.rate_limit(Unit, limiter, c, next)
```

### `B.rate_limit_with`

```bend signature
def rate_limit_with(-Vars: Data, limiter: B.RateLimiter, key: String, now_ms: Nat, c: B.Context(Vars), next: B.Context(Vars) -> IO(B.Res)) -> IO(B.Res)
```

`B.rate_limit` with your own key, such as a user ID or a token's hash, and
your own clock in milliseconds. Tests pass a fake clock with it.

```bend
def ex_key(m: Maybe<&2, String>) -> String:
  match m:
    case Some{k}: k
    case None{}: "anonymous"

def ex_per_key(limiter: B.RateLimiter, +c: B.Context(Unit), next: B.Context(Unit) -> IO(B.Res)) -> IO(B.Res):
  do IO<B.Res>:
    now : Nat <- IO.now()
    B.rate_limit_with(Unit, limiter, ex_key(C.request_header(Unit, c, "x-api-key")), now, c, next)
```

### `B.stats_tracked`, `B.stats_saturated`, `B.stats_saturating`

```bend signature
def stats_tracked(s: B.RateLimitStats) -> Nat
def stats_saturated(s: B.RateLimitStats) -> Nat
def stats_saturating(s: B.RateLimitStats) -> Bool
```

The number of tracked keys, the number of requests that met a full table
since startup, and whether the table is full now. `B.stats_saturating` turns
false when a sweep frees room.

```bend
def ex_full_text(b: Bool) -> String:
  match b:
    case True{}: "full"
    case False{}: "ok"

def ex_stats_text(+s: B.RateLimitStats) -> String:
  Nat.show(B.stats_tracked(s)) ++ " keys, " ++ Nat.show(B.stats_saturated(s)) ++ " saturated, " ++ ex_full_text(B.stats_saturating(s))
```

### `B.RateLimitStats`, `B.rate_limit_stats`

```bend signature
def RateLimitStats() -> Data
def rate_limit_stats(limiter: B.RateLimiter) -> IO(Result<&2, &2, B.StoreError, B.RateLimitStats>)
```

Reads the limiter's monitoring counters, or the store error when its actor
does not answer. Read the counters with the accessors below.

```bend
def ex_report(+c: B.Ctx, r: Result<&2, &2, B.StoreError, B.RateLimitStats>) -> B.Res:
  match r:
    case Done{s}: B.text(c, ex_stats_text(s))
    case Fail{e}: B.text(B.status(c, 503), "stats unavailable")

def ex_stats(c: B.Ctx, limiter: B.RateLimiter) -> IO(B.Res):
  do IO<B.Res>:
    r : Result<&2, &2, B.StoreError, B.RateLimitStats> <- B.rate_limit_stats(limiter)
    return ex_report(c, r)
```

