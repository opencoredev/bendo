---
title: Protect routes with auth
description: Add basic auth, bearer tokens, JWTs and cookie sessions to a Bendo app, with CSRF protection for the browser routes.
---

# Protect routes with auth

This guide builds one app with four kinds of protection, each on its own part
of the URL space:

| Path | Who gets in | Built from |
|---|---|---|
| `/admin/*` | An operator with a username and password | `B.basic_auth` |
| `/api/*` | A service with a static API token | `B.bearer_auth` |
| `/me/*` | A client holding a JWT that `/admin/token` issued | `B.jwt_with` |
| `/account` | A browser that signed in through `/login` | Signed cookies and a store |

Every snippet comes from [the complete app](#the-complete-app) at the end of
the page. It assumes the app layout from the [quick start](../getting-started.md),
with the Bendo library in `bendo/`. The [authentication reference](../auth.md)
and [cookies reference](../cookies.md) describe every option and status code.

## Route built-ins through your middleware

The auth built-ins are values of type `B.Builtin`. Wrap them in one case of
your middleware tag and hand that case to `B.builtin`:

```bend
Builtin{id: B.Builtin}
```

```bend
case Builtin{id}: B.builtin(Vars, id, c, next)
```

`Vars` is the record your middleware passes to handlers. This app stores the
signed-in user in it:

```bend
type Vars is Data:
  Vars{user: String}
```

Serve the app with `B.serve_with`, which takes the middleware dispatcher as
well as the handler. Built-ins sit in the route list like any other
middleware, so `B.use_path` scopes each one to a prefix.

## Basic auth for an admin area

```bend
B.use_path(Tag, "/admin/*", Builtin{B.basic_auth("admin", [B.credential("admin", admin_password)])}),
```

A request without the right `Authorization: Basic` header gets 401 with
`WWW-Authenticate: Basic realm="admin", charset="UTF-8"`, so a browser shows
its login prompt. List several `B.credential` values to allow several users.
Every configured pair is checked on every request, by comparing SHA-256
digests, so the response time does not reveal which user matched.

## Bearer tokens for an API

```bend
B.use_path(Tag, "/api/*", Builtin{B.bearer_auth("api", [api_token])}),
```

A client sends `Authorization: Bearer <token>`. A missing header gets 401, a
malformed one 400 and an unknown token 401 with `error="invalid_token"`, as
RFC 6750 asks. Pass several tokens to rotate them: add the new token, move
clients over, then remove the old one.

## Issue and verify JWTs

A JWT lets a client prove who it is without the server looking anything up.
This app issues one from a route behind basic auth, so only the operator can
mint tokens:

```bend
B.post(Tag, "/admin/token", IssueToken{jwt_secret}),
```

The handler reads the wall clock and signs a claim set that expires in an
hour:

```bend
def claims_at(now: Nat) -> Json.Json:
  Json.JObject{[
    Json.Field{"sub", Json.JString{"admin"}},
    Json.Field{"exp", Json.JNumber{Nat.show((now + 3600n : Nat))}}]}
```

```bend
case Done{now}: token_json(c, B.jwt_sign(secret, claims_at(now)))
```

`B.jwt_sign` uses HS256 and returns a `Result`, because a claim set with a
repeated member name cannot be signed.

To check tokens, register a middleware tag that carries the configuration.
`B.jwt_config(secret, leeway, realm)` takes the secret, the allowed clock skew
in seconds and the realm for the challenge:

```bend
B.use_path(Tag, "/me/*", Claims{B.jwt_config(jwt_secret, 30n, "me")}),
```

Its middleware case calls `B.jwt_with`, which verifies the token and hands the
claims to a continuation. The continuation copies the `sub` claim into `Vars`:

```bend
case Claims{config}: B.jwt_with(Vars, config, c, claims => ctx => next(C.set(Vars, ctx, Vars{subject_of(claims)})))
```

Handlers behind `/me/*` read it back with `C.get(Vars, c)`. A bad signature,
an expired token or a header that names any algorithm other than HS256 gets
401 with the reason in `WWW-Authenticate`. If you only need the check and not
the claims, register `Builtin{B.jwt(config)}` instead.

## Sessions with signed cookies

Browsers are better served by a cookie than by a token in JavaScript. This
app keeps sessions on the server: a [store](../store.md) holds the session
IDs, and the browser holds the ID in a cookie signed with a server secret.
Signing stops a client from inventing an ID. Keeping the list on the server
means signing out really ends the session.

### Sign in

`POST /login` reads a form with `user` and `password` fields. `Form.parse_body`
accepts both URL-encoded and multipart forms:

```bend
parsed(Form.parse_body(content_type(C.request_header(Vars, c, "content-type")), C.raw_body(Vars, c)), c, env, password)
```

The password check compares SHA-256 digests with `Compare.ct_equal` rather than
the strings themselves, the same way the built-ins do:

```bend
def same(a: String, b: String) -> Bool:
  Compare.ct_equal(SHA256.hash(Utf8.encode(a)), SHA256.hash(Utf8.encode(b)))
```

On success the handler draws 32 random bytes for the session ID, saves the
session and sets the cookie:

```bend
random : Result<&1, &1, U32 & String, List<&2, U32>> <- Random.random_bytes(32n)
```

```bend
stored : Result<&2, &2, Store.Error, List<&2, Session>> <- Store.update(List<&2, Session>, sessions, xs => Session{id, "admin"} <> xs)
```

```bend
case Done{all}: signed_in(c, C.set_signed_cookie(Vars, c, "sid", id, keys, cookie_options()))
```

The cookie is `Secure`, `HttpOnly` and `SameSite=Lax`, lives for a day and
applies to the whole site. The fields of `Cookie.Options` are path, domain,
max age, expires, secure, HTTP-only, SameSite and partitioned, in that order:

```bend
def cookie_options() -> Cookie.Options:
  Cookie.Options{Some{"/"}, None{}, Some{Cookie.Seconds{86400n}}, None{}, True{}, True{}, Some{Cookie.Lax{}}, False{}}
```

### Require a session

`SessionUser{}` is a middleware tag on `/account`. It verifies the cookie with
`C.signed_cookie`, looks the ID up in the store and either sets `Vars` or
answers 401:

```bend
session_read(stored, C.signed_cookie(Vars, c, "sid", keys), c, next)
```

```bend
case Some{user}: next(C.set(Vars, c, Vars{user}))
```

`C.signed_cookie` returns `None{}` for a missing cookie, a bad signature or a
value that was never signed, so the middleware treats them all as signed out.

### Sign out

`POST /logout` removes the session from the store and deletes the cookie.
`C.delete_cookie` needs the same path and options as the cookie it replaces:

```bend
dropped : Result<&2, &2, Store.Error, List<&2, Session>> <- Store.update(List<&2, Session>, sessions, xs => without(xs, id))
return signed_out(c, C.delete_cookie(Vars, c, "sid", cookie_options()))
```

A copy of the old cookie no longer works, because its ID is gone from the
store.

### Stop cross-site form posts

A cookie is sent with every request to the site, including a form another site
submits. `B.csrf` refuses such requests unless they come from an origin you
list. Put it in front of every route that changes state for a signed-in
browser:

```bend
B.use_path(Tag, "/login", Builtin{B.csrf(["https://app.example"])}),
B.use_path(Tag, "/logout", Builtin{B.csrf(["https://app.example"])}),
```

It only inspects requests a plain HTML form could send, so JSON calls are left
to [CORS](cors.md). Replace `https://app.example` with your site's public
origin. The [CSRF reference](../auth.md#csrf) explains `B.csrf_host` for apps
served under several hostnames.

## Load secrets at startup

Credentials, tokens and signing keys live in the route table and `env`, so
`main` reads them from the environment before it builds the routes. The app
refuses to start when one is missing or empty:

```bend
admin : String <- required("ADMIN_PASSWORD")
token : String <- required("API_TOKEN")
jwt : String <- required("JWT_SECRET")
cookie : String <- required("COOKIE_SECRET")
```

`SignedCookie.configure` checks the cookie keys. Pass a list to rotate them:
the first key signs new cookies and every key verifies old ones.

```bend
start(SignedCookie.configure([cookie]), sessions, Secrets{admin, token, jwt})
```

Generate each secret with `openssl rand -base64 32`, and keep them out of the
repository. The [deployment guide](deploy.md#run-it-under-systemd) loads them from
a file that only the service can read.

## Try it

Build the app and start it with its four secrets:

```sh
bendo build
ADMIN_PASSWORD='correct horse' API_TOKEN=tok-123 \
  JWT_SECRET="$(openssl rand -base64 32)" COOKIE_SECRET="$(openssl rand -base64 32)" \
  ./dist/server
```

Then call each area from another terminal:

```sh
curl -i http://127.0.0.1:8787/admin/dashboard                          # 401, Basic challenge
curl -u 'admin:correct horse' http://127.0.0.1:8787/admin/dashboard    # Admin dashboard
curl -H 'Authorization: Bearer tok-123' http://127.0.0.1:8787/api/report   # {"visits":42}

TOKEN=$(curl -s -u 'admin:correct horse' -X POST http://127.0.0.1:8787/admin/token \
  | sed 's/.*"token":"\([^"]*\)".*/\1/')
curl -H "Authorization: Bearer $TOKEN" http://127.0.0.1:8787/me/profile   # Token for admin

curl -c jar -H 'Origin: https://app.example' \
  -d 'user=admin&password=correct horse' http://127.0.0.1:8787/login      # Signed in
curl -b jar http://127.0.0.1:8787/account                                 # Signed in as admin
curl -b jar -c jar -X POST -H 'Origin: https://app.example' \
  http://127.0.0.1:8787/logout                                            # Signed out
```

A login without the `Origin` header gets `403 Forbidden` from the CSRF check.
A browser always sends it.

## What this app leaves out

- **Password storage.** The app compares a password from the environment. A
  real app stores a slow password hash per user, such as argon2 or scrypt,
  computed by a separate service or library, because Bendo ships no password
  hashing.
- **Session expiry.** Sessions stay in the store until the user signs out or
  the process restarts. Store a creation time with each session and drop old
  ones in the middleware.
- **Several processes.** A store lives in one process. With
  [workers](../workers.md), each worker has its own sessions, so keep sessions
  in an external service or serve with one worker.
- **Brute force.** Put a [rate limiter](../connection.md#rate-limiting) on
  `/login`.

## The complete app

::: details main.bend
```bend
import Base
import ./bendo/main.bend as B
import ./bendo/app/context.bend as C
import ./bendo/app/store.bend as Store
import ./bendo/crypto/compare.bend as Compare
import ./bendo/crypto/random.bend as Random
import ./bendo/crypto/sha256.bend as SHA256
import ./bendo/data/cookie.bend as Cookie
import ./bendo/data/form.bend as Form
import ./bendo/data/hex.bend as Hex
import ./bendo/data/json.bend as Json
import ./bendo/data/multipart.bend as Multipart
import ./bendo/data/signed-cookie.bend as SignedCookie
import ./bendo/data/utf8.bend as Utf8
import ./bendo/effects/clock.bend as Clock

# The signed-in user. The Claims and SessionUser middleware set it.
type Vars is Data:
  Vars{user: String}

type Session is Data:
  Session{id: String, user: String}

type Env is Data:
  Env{sessions: B.Store(List<&2, Session>), keys: SignedCookie.Keys}

type Tag is Data:
  Home{}
  Dashboard{}
  Report{}
  IssueToken{secret: String}
  Profile{}
  Login{password: String}
  Logout{}
  Account{}
  Claims{config: B.JwtConfig}
  SessionUser{}
  Builtin{id: B.Builtin}

# Secrets, read from the environment once at startup.
type Secrets is Data:
  Secrets{admin_password: String, api_token: String, jwt_secret: String}

# --- Helpers ---

def user_of(vars: Maybe<&2, Vars>) -> String:
  match vars:
    case Some{Vars{user}}: user
    case None{}: "nobody"

# The "sub" claim of a verified token, or "" when it has none.
def subject(fields: List<&2, Json.Field>) -> String:
  match fields:
    case Nil{}: ""
    case Json.Field{"sub", Json.JString{s}} <> rest: s
    case _ <> rest: subject(rest)

def subject_of(claims: Json.Json) -> String:
  match claims:
    case Json.JObject{fields}: subject(fields)
    case _: ""

# Compare SHA-256 digests so the work does not depend on where the inputs differ.
def same(a: String, b: String) -> Bool:
  Compare.ct_equal(SHA256.hash(Utf8.encode(a)), SHA256.hash(Utf8.encode(b)))

def form_field(parts: List<&2, Multipart.Part>, +name: String) -> String:
  match parts:
    case Nil{}: ""
    case Multipart.Field{key, value} <> rest: Bool.pick(String, String.eq(key, name), value, form_field(rest, name))
    case _ <> rest: form_field(rest, name)

def content_type(header: Maybe<&2, String>) -> String:
  match header:
    case Some{value}: value
    case None{}: ""

def lookup(sessions: List<&2, Session>, +id: String) -> Maybe<&2, String>:
  match sessions:
    case Nil{}: None{}
    case Session{sid, user} <> rest: Bool.pick(Maybe<&2, String>, String.eq(sid, id), Some{user}, lookup(rest, id))

def kept(drop: Bool, session: Session, rest: List<&2, Session>) -> List<&2, Session>:
  match drop:
    case True{}: rest
    case False{}: session <> rest

def without(sessions: List<&2, Session>, +id: String) -> List<&2, Session>:
  match sessions:
    case Nil{}: []
    case Session{+sid, user} <> rest: kept(String.eq(sid, id), Session{sid, user}, without(rest, id))

# --- JWT ---

def claims_at(now: Nat) -> Json.Json:
  Json.JObject{[
    Json.Field{"sub", Json.JString{"admin"}},
    Json.Field{"exp", Json.JNumber{Nat.show((now + 3600n : Nat))}}]}

def token_json(+c: B.Context(Vars), signed: Result<&2, &2, B.JwtError, String>) -> B.Res:
  match signed:
    case Fail{e}: C.error(Vars, c, B.http_error(500, "cannot sign the token"))
    case Done{token}: C.json(Vars, c, Json.JObject{[Json.Field{"token", Json.JString{token}}]})

def token_at(+c: B.Context(Vars), secret: String, clock: Result<&1, &1, U32 & String, Nat>) -> B.Res:
  match clock:
    case Fail{e}: C.error(Vars, c, B.http_error(500, "no wall clock"))
    case Done{now}: token_json(c, B.jwt_sign(secret, claims_at(now)))

def issue(+c: B.Context(Vars), secret: String) -> IO(B.Res):
  do IO<B.Res>:
    clock : Result<&1, &1, U32 & String, Nat> <- Clock.wall_seconds()
    return token_at(c, secret, clock)

# --- Sessions ---

def cookie_options() -> Cookie.Options:
  Cookie.Options{Some{"/"}, None{}, Some{Cookie.Seconds{86400n}}, None{}, True{}, True{}, Some{Cookie.Lax{}}, False{}}

def signed_in(+c: B.Context(Vars), cookie: Result<&2, &2, Cookie.Error, B.Context(Vars)>) -> B.Res:
  match cookie:
    case Fail{e}: C.error(Vars, c, B.http_error(500, "cannot set the cookie"))
    case Done{ctx}: C.text(Vars, ctx, "Signed in")

def saved(stored: Result<&2, &2, Store.Error, List<&2, Session>>, +c: B.Context(Vars), keys: SignedCookie.Keys, id: String) -> B.Res:
  match stored:
    case Fail{e}: C.error(Vars, c, B.http_error(503, "try again"))
    case Done{all}: signed_in(c, C.set_signed_cookie(Vars, c, "sid", id, keys, cookie_options()))

def save_session(+c: B.Context(Vars), env: Env, +id: String) -> IO(B.Res):
  Env{sessions, keys} = env
  do IO<B.Res>:
    stored : Result<&2, &2, Store.Error, List<&2, Session>> <- Store.update(List<&2, Session>, sessions, xs => Session{id, "admin"} <> xs)
    return saved(stored, c, keys, id)

def start_session(random: Result<&1, &1, U32 & String, List<&2, U32>>, +c: B.Context(Vars), env: Env) -> IO(B.Res):
  match random:
    case Fail{e}: IO.pure(B.Res, C.error(Vars, c, B.http_error(500, "no entropy")))
    case Done{bytes}: save_session(c, env, Hex.encode(bytes))

def checked(ok: Bool, +c: B.Context(Vars), env: Env) -> IO(B.Res):
  match ok:
    case False{}: IO.pure(B.Res, C.error(Vars, c, B.http_error(401, "wrong user or password")))
    case True{}:
      do IO<B.Res>:
        random : Result<&1, &1, U32 & String, List<&2, U32>> <- Random.random_bytes(32n)
        start_session(random, c, env)

def credentials_ok(+parts: List<&2, Multipart.Part>, password: String) -> Bool:
  Bool.and(same(form_field(parts, "user"), "admin"), same(form_field(parts, "password"), password))

def parsed(form: Result<&2, &2, Multipart.Error, List<&2, Multipart.Part>>, +c: B.Context(Vars), env: Env, password: String) -> IO(B.Res):
  match form:
    case Fail{e}: IO.pure(B.Res, C.error(Vars, c, B.http_error(400, "send the login form")))
    case Done{parts}: checked(credentials_ok(parts, password), c, env)

def login(+c: B.Context(Vars), env: Env, password: String) -> IO(B.Res):
  parsed(Form.parse_body(content_type(C.request_header(Vars, c, "content-type")), C.raw_body(Vars, c)), c, env, password)

def signed_out(+c: B.Context(Vars), cookie: Result<&2, &2, Cookie.Error, B.Context(Vars)>) -> B.Res:
  match cookie:
    case Fail{e}: C.error(Vars, c, B.http_error(500, "cannot clear the cookie"))
    case Done{ctx}: C.text(Vars, ctx, "Signed out")

def forget(+c: B.Context(Vars), sessions: B.Store(List<&2, Session>), sid: Maybe<&2, String>) -> IO(B.Res):
  match sid:
    case None{}: IO.pure(B.Res, signed_out(c, C.delete_cookie(Vars, c, "sid", cookie_options())))
    case Some{id}:
      do IO<B.Res>:
        dropped : Result<&2, &2, Store.Error, List<&2, Session>> <- Store.update(List<&2, Session>, sessions, xs => without(xs, id))
        return signed_out(c, C.delete_cookie(Vars, c, "sid", cookie_options()))

def logout(+c: B.Context(Vars), env: Env) -> IO(B.Res):
  Env{sessions, keys} = env
  forget(c, sessions, C.signed_cookie(Vars, c, "sid", keys))

def session_user(found: Maybe<&2, String>, +c: B.Context(Vars), next: B.Context(Vars) -> IO(B.Res)) -> IO(B.Res):
  match found:
    case None{}: IO.pure(B.Res, C.error(Vars, c, B.http_error(401, "sign in first")))
    case Some{user}: next(C.set(Vars, c, Vars{user}))

def session_read(stored: Result<&2, &2, Store.Error, List<&2, Session>>, sid: Maybe<&2, String>, +c: B.Context(Vars), next: B.Context(Vars) -> IO(B.Res)) -> IO(B.Res):
  match stored sid:
    case Done{sessions} Some{id}: session_user(lookup(sessions, id), c, next)
    case _ _: session_user(None{}, c, next)

def require_session(+c: B.Context(Vars), env: Env, next: B.Context(Vars) -> IO(B.Res)) -> IO(B.Res):
  Env{sessions, keys} = env
  do IO<B.Res>:
    stored : Result<&2, &2, Store.Error, List<&2, Session>> <- Store.get(List<&2, Session>, sessions)
    session_read(stored, C.signed_cookie(Vars, c, "sid", keys), c, next)

# --- App ---

def handle(tag: Tag, +c: B.Context(Vars), env: Env) -> IO(B.Res):
  match tag:
    case Home{}: IO.pure(B.Res, C.text(Vars, c, "Public page"))
    case Dashboard{}: IO.pure(B.Res, C.text(Vars, c, "Admin dashboard"))
    case Report{}: IO.pure(B.Res, C.json(Vars, c, Json.JObject{[Json.Field{"visits", Json.JNumber{"42"}}]}))
    case IssueToken{secret}: issue(c, secret)
    case Profile{}: IO.pure(B.Res, C.text(Vars, c, "Token for " ++ user_of(C.get(Vars, c))))
    case Login{password}: login(c, env, password)
    case Logout{}: logout(c, env)
    case Account{}: IO.pure(B.Res, C.text(Vars, c, "Signed in as " ++ user_of(C.get(Vars, c))))
    case _: IO.pure(B.Res, C.not_found(Vars, c))

def handler(tag: Tag, c: B.Context(Vars), env: Env) -> IO(B.Res):
  handle(tag, c, env)

def middleware(tag: Tag, c: B.Context(Vars), env: Env, next: B.Context(Vars) -> IO(B.Res)) -> IO(B.Res):
  match tag:
    case Builtin{id}: B.builtin(Vars, id, c, next)
    case Claims{config}: B.jwt_with(Vars, config, c, claims => ctx => next(C.set(Vars, ctx, Vars{subject_of(claims)})))
    case SessionUser{}: require_session(c, env, next)
    case _: next(c)

def routes(secrets: Secrets) -> List<&2, B.Registration(Tag)>:
  Secrets{+admin_password, api_token, +jwt_secret} = secrets
  [B.use_path(Tag, "/admin/*", Builtin{B.basic_auth("admin", [B.credential("admin", admin_password)])}),
   B.use_path(Tag, "/api/*", Builtin{B.bearer_auth("api", [api_token])}),
   B.use_path(Tag, "/me/*", Claims{B.jwt_config(jwt_secret, 30n, "me")}),
   B.use_path(Tag, "/login", Builtin{B.csrf(["https://app.example"])}),
   B.use_path(Tag, "/logout", Builtin{B.csrf(["https://app.example"])}),
   B.use_path(Tag, "/account", SessionUser{}),
   B.get(Tag, "/", Home{}),
   B.get(Tag, "/admin/dashboard", Dashboard{}),
   B.post(Tag, "/admin/token", IssueToken{jwt_secret}),
   B.get(Tag, "/api/report", Report{}),
   B.get(Tag, "/me/profile", Profile{}),
   B.post(Tag, "/login", Login{admin_password}),
   B.post(Tag, "/logout", Logout{}),
   B.get(Tag, "/account", Account{})]

def ready(env: Env, result: Result<&2, &2, B.RouteError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "invalid routes")
    case Done{table}: B.serve_with(~Vars, ~Tag, ~Env, ~handler, ~middleware, table, env, B.config())

def start(keys: Maybe<&2, SignedCookie.Keys>, sessions: B.Store(List<&2, Session>), secrets: Secrets) -> IO(Unit):
  match keys:
    case None{}: IO.die(Unit, 1, "COOKIE_SECRET must not be empty")
    case Some{k}: ready(Env{sessions, k}, B.routes(Tag, routes(secrets)))

def nonempty(value: String, +name: String) -> IO(String):
  match value:
    case "": IO.die(String, 1, name ++ " must not be empty")
    case _: IO.pure(String, value)

def present(got: Result<&1, &1, U32 & String, String>, +name: String) -> IO(String):
  match got:
    case Fail{e}: IO.die(String, 1, name ++ " is not set")
    case Done{value}: nonempty(value, name)

def required(+name: String) -> IO(String):
  do IO<String>:
    got : Result<&1, &1, U32 & String, String> <- IO.get_env(name)
    present(got, name)

def main() -> IO(Unit):
  do IO<Unit>:
    admin : String <- required("ADMIN_PASSWORD")
    token : String <- required("API_TOKEN")
    jwt : String <- required("JWT_SECRET")
    cookie : String <- required("COOKIE_SECRET")
    sessions : B.Store(List<&2, Session>) <- B.store(List<&2, Session>, [])
    start(SignedCookie.configure([cookie]), sessions, Secrets{admin, token, jwt})
```
:::

## Read on

- [Authentication and CSRF](../auth.md) is the reference for the built-ins and
  the laws behind them.
- [Cookies](../cookies.md) covers every cookie option and the signed-cookie
  format.
- [CORS](cors.md) is the next step when a browser app on another origin calls
  your API.
