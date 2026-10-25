---
title: Call your API from another origin
description: Configure CORS, credentials, CSRF and security headers for a browser app that calls a Bendo API on a different origin.
---

# Call your API from another origin

A browser refuses to let a page on `https://app.example` read responses from
`https://api.example` unless the API says it may. This guide configures a
Bendo API for that: CORS for the allowed origins, cookies for one of them,
CSRF protection for form posts, and security headers on every response.

The snippets come from [the complete app](#the-complete-app) at the end of the
page. The [CORS reference](../web-middleware.md#cors) lists every setting and
the exact fields Bendo sends.

## List the origins

Name each origin that may call the API. An origin is a scheme, host and
optional port, with no path. Choose per origin whether the browser may send
cookies and `Authorization` headers:

```bend
def origins() -> List<&2, B.CorsOrigin>:
  [B.cors_origin_credentials("https://app.example"),
   B.cors_origin("http://localhost:5173")]
```

`B.cors_origin_credentials` adds `Access-Control-Allow-Credentials: true` for
the production app. The Vite dev server on port 5173 gets plain CORS, so its
requests carry no cookies.

Build the configuration in `main` with `B.cors_allow_checked`. It drops entries
that are not origins, such as `app.example` without a scheme, and prints one
line on stderr for each, so a typo shows up at startup rather than as a
blocked request:

```bend
allowed : B.CorsConfig <- B.cors_allow_checked(origins())
```

`B.cors_defaults()` instead allows every origin with `*`. It never allows
credentials, because browsers reject `*` with them.

## Set methods, headers and caching

```bend
def cors(allowed: B.CorsConfig) -> B.CorsConfig:
  B.cors_max_age(B.cors_expose(B.cors_headers(B.cors_methods(allowed,
    ["GET", "POST", "DELETE"]),
    ["content-type", "authorization"]),
    ["x-request-id"]),
    600n)
```

| Setter | What the browser learns |
|---|---|
| `B.cors_methods` | The methods a page may use. The default is Hono's list: `GET,HEAD,PUT,POST,DELETE,PATCH,QUERY`. |
| `B.cors_headers` | The request headers a page may send. Without it, Bendo echoes whatever the preflight asks for, which is too loose for a credentialed origin. |
| `B.cors_expose` | Response headers that page JavaScript may read, beyond the simple ones. |
| `B.cors_max_age` | How many seconds the browser may cache a preflight answer. |

## Register the middleware

Register CORS before anything whose responses it should cover. The first
registration is the outermost layer, so here CORS also covers the CSRF
refusals, the router's 404 and 405 answers and handler errors:

```bend
B.use_path(Tag, "/api/*", Builtin{B.cors(cors(allowed))}),
B.use_path(Tag, "/api/*", Builtin{B.csrf(["https://app.example", "http://localhost:5173"])}),
B.use(Tag, Builtin{security()}),
B.use(Tag, Builtin{B.request_id()}),
```

The middleware dispatcher routes every built-in the same way:

```bend
case Builtin{id}: B.builtin(Unit, id, c, next)
```

A preflight (`OPTIONS` with `Origin` and `Access-Control-Request-Method`)
never reaches a handler. Bendo answers it with an empty 204, and an origin
that is not listed gets the 204 without any CORS field, so the browser blocks
the real request. Every response from a listed policy carries `Vary: Origin`,
so a cache never serves one origin's answer to another.

## Send cookies from the browser

The page must ask for credentials, and the API must allow them for its origin:

```ts
const response = await fetch("https://api.example/api/me", { credentials: "include" });
console.log(await response.text());
```

The cookie itself needs `SameSite=None; Secure` if the page and the API are on
different sites, such as `app.example` and `api.example-cdn.net`. Pages and
APIs under one registrable domain (`app.example.com` and `api.example.com`)
are the same site, and `SameSite=Lax` works. The [auth guide](auth.md#sessions-with-signed-cookies)
shows how to set the cookie.

## Stop cross-site form posts

CORS controls who may read a response. It does not stop a request from being
sent: any site can submit an HTML form to your API, and the browser attaches
your cookies. JSON requests are safe, because the browser sends a preflight
first. Forms are not. `B.csrf` closes that gap by refusing form-like requests
from origins you have not listed, with 403:

```bend
B.use_path(Tag, "/api/*", Builtin{B.csrf(["https://app.example", "http://localhost:5173"])}),
```

Give it the same origins as CORS. It also checks requests without a
`Content-Type`, such as a bare `DELETE`, so a client that sends no `Origin`
header gets 403 there. Browsers always send one; scripts and `curl` must add
it.

## Add security headers

`B.secure_headers()` sets Hono's default security headers on every response.
For a JSON API, also send a Content Security Policy that forbids everything,
since the API serves no pages:

```bend
def security() -> B.Builtin:
  B.secure_headers_with(B.secure_set(B.secure_defaults(), "Content-Security-Policy", "default-src 'none'; frame-ancestors 'none'"))
```

## Try it

Build and start the app, then send a preflight the way a browser would:

```sh
bendo build && ./dist/server &
curl -i -X OPTIONS http://127.0.0.1:8787/api/todos/1 \
  -H 'Origin: https://app.example' \
  -H 'Access-Control-Request-Method: DELETE' \
  -H 'Access-Control-Request-Headers: content-type'
```

```text
HTTP/1.1 204 No Content
access-control-allow-origin: https://app.example
access-control-allow-credentials: true
access-control-allow-methods: GET,POST,DELETE
access-control-allow-headers: content-type,authorization
access-control-max-age: 600
vary: Origin
```

The same preflight from `https://evil.example` gets `204 No Content` and no
`access-control-*` fields. A form post from that origin gets `403 Forbidden`:

```sh
curl -i -H 'Origin: https://evil.example' -d 'title=x' http://127.0.0.1:8787/api/todos
```

## The complete app

::: details main.bend
```bend
import Base
import ./bendo/main.bend as B
import ./bendo/app/context.bend as C
import ./bendo/data/json.bend as Json

type Tag is Data:
  ListTodos{}
  CreateTodo{}
  DeleteTodo{}
  Me{}
  Builtin{id: B.Builtin}

def session_text(cookie: Maybe<&2, String>) -> String:
  match cookie:
    case Some{value}: "session " ++ value
    case None{}: "no session cookie"

def handle(tag: Tag, +c: B.Context(Unit)) -> B.Res:
  match tag:
    case ListTodos{}: C.json(Unit, c, Json.JArray{[Json.JString{"Write the CORS guide"}]})
    case CreateTodo{}: C.text(Unit, C.status(Unit, c, 201), "created")
    case DeleteTodo{}: C.body(Unit, C.status(Unit, c, 204), [], None{})
    case Me{}: C.text(Unit, c, session_text(C.cookie(Unit, c, "session")))
    case _: C.not_found(Unit, c)

def handler(tag: Tag, c: B.Context(Unit), env: Unit) -> IO(B.Res):
  IO.pure(B.Res, handle(tag, c))

def middleware(tag: Tag, c: B.Context(Unit), env: Unit, next: B.Context(Unit) -> IO(B.Res)) -> IO(B.Res):
  match tag:
    case Builtin{id}: B.builtin(Unit, id, c, next)
    case _: next(c)

# The origins that may call the API from a browser. Only the production app
# sends cookies; the Vite dev server gets plain CORS.
def origins() -> List<&2, B.CorsOrigin>:
  [B.cors_origin_credentials("https://app.example"),
   B.cors_origin("http://localhost:5173")]

def cors(allowed: B.CorsConfig) -> B.CorsConfig:
  B.cors_max_age(B.cors_expose(B.cors_headers(B.cors_methods(allowed,
    ["GET", "POST", "DELETE"]),
    ["content-type", "authorization"]),
    ["x-request-id"]),
    600n)

def security() -> B.Builtin:
  B.secure_headers_with(B.secure_set(B.secure_defaults(), "Content-Security-Policy", "default-src 'none'; frame-ancestors 'none'"))

def routes(allowed: B.CorsConfig) -> List<&2, B.Registration(Tag)>:
  [B.use_path(Tag, "/api/*", Builtin{B.cors(cors(allowed))}),
   B.use_path(Tag, "/api/*", Builtin{B.csrf(["https://app.example", "http://localhost:5173"])}),
   B.use(Tag, Builtin{security()}),
   B.use(Tag, Builtin{B.request_id()}),
   B.get(Tag, "/api/todos", ListTodos{}),
   B.post(Tag, "/api/todos", CreateTodo{}),
   B.delete(Tag, "/api/todos/:id{int}", DeleteTodo{}),
   B.get(Tag, "/api/me", Me{})]

def ready(result: Result<&2, &2, B.RouteError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "invalid routes")
    case Done{table}: B.serve_with(~Unit, ~Tag, ~Unit, ~handler, ~middleware, table, Unit{}, B.config())

def main() -> IO(Unit):
  do IO<Unit>:
    allowed : B.CorsConfig <- B.cors_allow_checked(origins())
    ready(B.routes(Tag, routes(allowed)))
```
:::

## Read on

- [CORS, secure headers, method override and trailing slash](../web-middleware.md)
  is the reference for these built-ins.
- [WebSockets](websockets.md#check-the-origin) need their own origin list:
  CORS does not apply to them.
- The [todo example](../examples.md#todo) runs a React app on Vite's port
  against a CORS-enabled API.
