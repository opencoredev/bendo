# Context and responses

A handler gets a `B.Ctx` for its request, reads the request through it, and
turns it into a `B.Res`. A context is an immutable value: setters return a new
context and leave the old one as it was. [Context](../../concepts/context.md)
explains the model and [Request context](../../context.md) has the full rules;
this page lists the calls.

A heading that also names a `C.` function, such as `B.param`, `C.param`, marks
the same call for a context that carries a typed record. `C` is
`bendo/app/context.bend`. Each `C` function takes the erased `Vars` type first
and `B.Context(Vars)` where the `B` one takes `B.Ctx`, so `B.param(c, name)` is
`C.param(Unit, c, name)`. [Typed variables](#typed-variables) shows how to set
the record.

Examples on this page are one Bend program and share this setup:

```bend
import Base
import ./bendo/main.bend as B
import ./bendo/app/context.bend as C
import ./bendo/data/json.bend as J
import ./bendo/data/cookie.bend as Cookie
import ./bendo/data/signed-cookie.bend as SignedCookie
import ./bendo/http/request.bend as Request

type Vars is Data:
  Vars{user: String}

def or_empty(value: Maybe<&2, String>) -> String:
  Maybe.default(&2, String, value, "")
```

## Read the request

### `B.param`, `C.param`

```bend signature
def param(c: B.Ctx, name: String) -> Maybe<&2, String>
```

The route capture called `name`, percent-decoded, or `None{}` when the matched
pattern has no such capture. See [route patterns](../../router-patterns.md).

```bend
def ex_user(+c: B.Ctx) -> B.Res:
  B.text(c, "user " ++ or_empty(B.param(c, "id")))

def ex_typed_user(+c: B.Context(Vars)) -> B.Res:
  C.text(Vars, c, "user " ++ or_empty(C.param(Vars, c, "id")))
```

### `B.query`, `B.queries`, `C.query`, `C.queries`

```bend signature
def query(c: B.Ctx, name: String) -> Maybe<&2, String>
def queries(c: B.Ctx, name: String) -> List<&2, String>
```

`B.query` returns the first decoded value of the query parameter `name`;
`B.queries` returns every value in arrival order, and an empty list when there
is none. Names are case-sensitive, `+` decodes to a space and empty values are
kept. A malformed query never reaches a handler: the server answers 400 first.

```bend
def ex_search(+c: B.Ctx) -> B.Res:
  term = or_empty(B.query(c, "q"))
  tags = B.queries(c, "tag")
  B.text(c, term ++ " in " ++ Nat.show(List.length(&2, String, tags)) ++ " tags")

def ex_typed_search(+c: B.Context(Vars)) -> B.Res:
  tags = C.queries(Vars, c, "tag")
  C.text(Vars, c, or_empty(C.query(Vars, c, "q")) ++ " in " ++ Nat.show(List.length(&2, String, tags)) ++ " tags")
```

### `B.request_header`, `B.header_bytes`, `C.request_header`

```bend signature
def request_header(c: B.Ctx, name: String) -> Maybe<&2, String>
def header_bytes(c: B.Ctx, name: String) -> List<&2, List<&2, U32>>
```

Both match `name` case-insensitively. `B.request_header` returns the first field
decoded as UTF-8, and `None{}` both when the header is absent and when its value
is not valid UTF-8. `B.header_bytes` returns the octets of every matching
field in arrival order, so an empty list means absent. The name is
`request_header` because `B.header` sets a response header.

```bend
def ex_agent(+c: B.Ctx) -> B.Res:
  fields = B.header_bytes(c, "x-forwarded-for")
  B.text(c, or_empty(B.request_header(c, "user-agent")) ++ " via " ++ Nat.show(List.length(&2, List<&2, U32>, fields)) ++ " proxies")

def ex_typed_agent(+c: B.Context(Vars)) -> B.Res:
  C.text(Vars, c, or_empty(C.request_header(Vars, c, "user-agent")))
```

### `B.method`, `B.path`, `B.url`, `C.method`, `C.path`

```bend signature
def method(c: B.Ctx) -> Request.Method
def path(c: B.Ctx) -> String
def url(c: B.Ctx) -> String
```

`B.method` returns the parsed method, a constructor of `Request.Method` in
`bendo/http/request.bend` (`Get{}`, `Post{}`, ..., `Extension{token}`).
`B.path` is the path as received, without the query. `B.url` is the path plus
the query, with a trailing `?` when the request had one; it does not build an
absolute URL or read `Host` or forwarded headers.

```bend
def ex_echo(+c: B.Ctx) -> B.Res:
  same = B.rewrite(c, B.method(c), B.path(c))
  B.text(same, B.url(c))

def ex_verb(m: Request.Method) -> String:
  match m:
    case Request.Get{}: "GET"
    case Request.Post{}: "POST"
    case _: "other"

def ex_typed_path(+c: B.Context(Vars)) -> B.Res:
  C.text(Vars, c, ex_verb(C.method(Vars, c)) ++ " " ++ C.path(Vars, c))
```

### `B.raw_body`, `C.raw_body`

```bend signature
def raw_body(c: B.Ctx) -> List<&2, U32>
```

The buffered request body as octets. The server has already framed and
buffered it, within the [body limit](../../limits-cache.md#limit-request-bodies-before-buffering), before any hook
runs. Parse JSON from it with `J.parse`, or declare a
[body schema](validation.md) instead.

```bend
def ex_size(+c: B.Ctx) -> B.Res:
  B.text(c, Nat.show(List.length(&2, U32, B.raw_body(c))) ++ " bytes")

def ex_typed_size(+c: B.Context(Vars)) -> B.Res:
  C.text(Vars, c, Nat.show(List.length(&2, U32, C.raw_body(Vars, c))) ++ " bytes")
```

### `B.rewrite`

```bend signature
def rewrite(c: B.Ctx, method: Request.Method, path: String) -> B.Ctx
```

Returns the context with a new method and path for route selection. Pass it
to `next` from an `on_request` hook, the only stage that runs before routing.
The buffered body, query and request headers are kept and the route params are
recomputed. The original wire method still decides HEAD framing. See
[hooks](../../decisions/0010-hooks.md#routing-parsing-and-context).

```bend
def ex_to_index(+c: B.Ctx) -> B.Ctx:
  B.rewrite(c, B.method(c), "/index.html")
```

## Build a response

A response starts at status 200 with no headers. The final helpers below
consume the context with its pending status and headers. Invalid output, such
as a header value with a newline or a status outside 100 to 599, becomes an
empty 500 instead of reaching the wire. The writer always owns
`Content-Length`, `Transfer-Encoding` and HEAD framing.

### `B.text`, `B.html`, `C.text`, `C.html`

```bend signature
def text(c: B.Ctx, value: String) -> B.Res
def html(c: B.Ctx, value: String) -> B.Res
```

Sends `value` as UTF-8 with `text/plain; charset=utf-8` or
`text/html; charset=utf-8`, replacing any pending `Content-Type`. `B.html` does
not escape its input.

```bend
def ex_hello(c: B.Ctx) -> B.Res:
  B.text(c, "Hello")

def ex_page(c: B.Ctx) -> B.Res:
  B.html(c, "<h1>Hello</h1>")

def ex_typed_hello(c: B.Context(Vars)) -> B.Res:
  C.text(Vars, c, "Hello")

def ex_typed_page(c: B.Context(Vars)) -> B.Res:
  C.html(Vars, c, "<h1>Hello</h1>")
```

### `B.json`, `C.json`

```bend signature
def json(c: B.Ctx, value: J.Json) -> B.Res
```

Writes `value` with `J.stringify` and sends it as
`application/json; charset=utf-8`. A value the writer refuses, such as a
`JNumber` with an invalid spelling, gives an empty 500.

```bend
def ex_todo(c: B.Ctx) -> B.Res:
  B.json(c, J.JObject{[J.Field{"title", J.JString{"Write docs"}}, J.Field{"done", J.JBool{False{}}}]})

def ex_typed_todo(c: B.Context(Vars)) -> B.Res:
  C.json(Vars, c, J.JArray{[]})
```

### `B.body`, `C.body`

```bend signature
def body(c: B.Ctx, bytes: List<&2, U32>, content_type: Maybe<&2, String>) -> B.Res
```

Sends `bytes` exactly. `Some{type}` sets `Content-Type`; `None{}` keeps a
pending one or leaves it absent. Every element must be an octet, 0 to 255.

```bend
def ex_pixel(c: B.Ctx) -> B.Res:
  B.body(c, [71, 73, 70, 56, 57, 97], Some{"image/gif"})

def ex_typed_empty(c: B.Context(Vars)) -> B.Res:
  C.body(Vars, C.status(Vars, c, 204), [], None{})
```

### `B.status`, `B.header`, `C.status`, `C.header`

```bend signature
def status(c: B.Ctx, code: U32) -> B.Ctx
def header(c: B.Ctx, name: String, value: String) -> B.Ctx
```

`B.status` sets the pending status. `B.header` sets a pending response header:
the name is folded to lowercase and replaces every earlier value of that name,
so use `B.set_cookie` rather than `B.header` for `Set-Cookie`. Both return the
new context for the next setter or a final helper.

```bend
def ex_created(c: B.Ctx) -> B.Res:
  B.text(B.header(B.status(c, 201), "location", "/todos/1"), "Created")

def ex_typed_created(c: B.Context(Vars)) -> B.Res:
  C.text(Vars, C.header(Vars, C.status(Vars, c, 201), "location", "/todos/1"), "Created")
```

### `B.redirect`, `B.redirect_status`, `C.redirect`

```bend signature
def redirect(c: B.Ctx, location: String) -> B.Res
def redirect_status(c: B.Ctx, location: String, code: U32) -> B.Res
```

An empty response with `Location: location`. `B.redirect` answers 302.
`B.redirect_status` accepts 301, 302, 303, 307 and 308; any other code gives an
empty 500. Other pending headers are kept.

```bend
def ex_login(c: B.Ctx) -> B.Res:
  B.redirect(c, "/login")

def ex_moved(c: B.Ctx) -> B.Res:
  B.redirect_status(c, "/new-home", 301)

def ex_typed_login(c: B.Context(Vars)) -> B.Res:
  C.redirect(Vars, c, "/login")
```

### `B.not_found`, `C.not_found`

```bend signature
def not_found(c: B.Ctx) -> B.Res
```

A 404 with the message `Not Found`, rendered like `B.error`: JSON when the
request's `Accept` asks for `application/json`, plain text otherwise. For a
custom answer to unmatched routes, register `B.on_not_found`.

```bend
def ex_missing(c: B.Ctx) -> B.Res:
  B.not_found(c)

def ex_typed_missing(c: B.Context(Vars)) -> B.Res:
  C.not_found(Vars, c)
```

### `B.not_modified`

```bend signature
def not_modified(headers: List<&2, Request.Header>, representation: Maybe<&2, List<&2, U32>>) -> B.Res
```

A bodyless 304 built directly, without a context, carrying `headers`.
`representation` is the exact body a matching GET would send, used only for
its length: with `Some{bytes}` the response carries that `Content-Length`, and
with `None{}` it carries none. The [ETag built-in](../../limits-cache.md) and
static files answer conditional requests on their own.

```bend
def ex_cached() -> B.Res:
  B.not_modified([], None{})
```

## Errors

Errors are values, not exceptions: a handler returns the response that
`B.error` renders. [Decision 0011](../../decisions/0011-crash.md) covers the
rendering rules and their laws.

### `B.HttpError`

```bend signature
def HttpError() -> Data

type HttpError is Data:
  HttpError{status: U32, message: String, expose: Bool}
```

A typed HTTP failure. When `expose` is false, the client sees
`Internal Server Error` instead of `message`. Build values with
`B.http_error`. The constructor lives in `bendo/app/errors.bend`; build it
directly only to show a 5xx message on purpose.

```bend
import ./bendo/app/errors.bend as Errors

def ex_maintenance() -> B.HttpError:
  Errors.HttpError{503, "Down for maintenance", True{}}
```

### `B.http_error`

```bend signature
def http_error(status: U32, message: String) -> B.HttpError
```

Builds an error. A status outside 400 to 599 becomes 500. Messages of 4xx
errors are shown to the client and messages of 5xx errors are hidden. An
empty shown message falls back to the status's reason phrase.

```bend
def ex_tea() -> B.HttpError:
  B.http_error(418, "Tea only")
```

### `B.error`, `C.error`

```bend signature
def error(c: B.Ctx, failure: B.HttpError) -> B.Res
```

Renders `failure` with its status. The body is `{"error":message,"status":code}`
when the request's `Accept` explicitly lists a JSON type, and the message as
plain text otherwise. `Accept` is appended to `Vary`. Pending headers are kept;
`Content-Type` is replaced. `on_error` hooks can still replace the result.

```bend
def ex_forbidden(c: B.Ctx) -> B.Res:
  B.error(c, B.http_error(403, "Admins only"))

def ex_typed_forbidden(c: B.Context(Vars)) -> B.Res:
  C.error(Vars, c, B.http_error(403, "Admins only"))
```

### `B.result`

```bend signature
def result(c: B.Ctx, value: Result<&2, &2, B.HttpError, B.Res>) -> B.Res
```

Returns the response in `Done{res}` and renders `Fail{error}` with `B.error`.
Use it at the end of a handler built from fallible steps.

```bend
def ex_lookup_hit(hit: Bool) -> Result<&2, &2, B.HttpError, String>:
  match hit:
    case True{}: Done{"Write docs"}
    case False{}: Fail{B.http_error(404, "No such todo")}

def ex_lookup(id: String) -> Result<&2, &2, B.HttpError, String>:
  ex_lookup_hit(String.eq(id, "1"))

def ex_found(c: B.Ctx, found: Result<&2, &2, B.HttpError, String>) -> Result<&2, &2, B.HttpError, B.Res>:
  match found:
    case Done{title}: Done{B.text(c, title)}
    case Fail{e}: Fail{e}

def ex_show(+c: B.Ctx) -> B.Res:
  B.result(c, ex_found(c, ex_lookup(or_empty(B.param(c, "id")))))
```

## Cookies

Import `bendo/data/cookie.bend` as `Cookie` for the options and error types.
[Cookies](../../cookies.md) has the parsing rules, every option and the
signed-cookie wire format.

### `B.cookies`, `B.cookie`, `C.cookie`

```bend signature
def cookies(c: B.Ctx) -> List<&2, Cookie.Entry>
def cookie(c: B.Ctx, name: String) -> Maybe<&2, String>
```

`B.cookies` returns every valid pair from every `Cookie` field, in arrival
order, as `Cookie.Entry{name, value}`; repeated names are kept and malformed
pairs are skipped. `B.cookie` returns the value of the first valid pair named
`name`, matched case-sensitively. Values are raw cookie octets: nothing is
percent-decoded.

```bend
def ex_theme(+c: B.Ctx) -> B.Res:
  all = B.cookies(c)
  B.text(c, or_empty(B.cookie(c, "theme")) ++ " of " ++ Nat.show(List.length(&2, Cookie.Entry, all)))

def ex_typed_theme(+c: B.Context(Vars)) -> B.Res:
  C.text(Vars, c, or_empty(C.cookie(Vars, c, "theme")))
```

### `B.set_cookie`, `B.delete_cookie`, `C.set_cookie`, `C.delete_cookie`

```bend signature
def set_cookie(c: B.Ctx, name: String, value: String, options: Cookie.Options) -> Result<&2, &2, Cookie.Error, B.Ctx>
def delete_cookie(c: B.Ctx, name: String, options: Cookie.Options) -> Result<&2, &2, Cookie.Error, B.Ctx>
```

Each successful call appends one `Set-Cookie` field and keeps the pending
status, other headers and earlier cookies. An invalid name, value or option
returns `Fail` with the reason and appends nothing. `B.delete_cookie` sends an
empty value with `Max-Age=0` and no `Expires`; pass the path and domain the
cookie was set with. `Cookie.defaults()` sets no attributes.

```bend
def ex_cookie_sent(c: B.Ctx, result: Result<&2, &2, Cookie.Error, B.Ctx>) -> B.Res:
  match result:
    case Done{updated}: B.text(updated, "Saved")
    case Fail{e}: B.text(B.status(c, 400), "Invalid cookie")

def ex_remember(+c: B.Ctx) -> B.Res:
  ex_cookie_sent(c, B.set_cookie(c, "theme", "dark", Cookie.defaults()))

def ex_forget(+c: B.Ctx) -> B.Res:
  ex_cookie_sent(c, B.delete_cookie(c, "theme", Cookie.defaults()))

def ex_typed_remember(c: B.Context(Vars)) -> Result<&2, &2, Cookie.Error, B.Context(Vars)>:
  C.set_cookie(Vars, c, "theme", "dark", Cookie.defaults())

def ex_typed_forget(c: B.Context(Vars)) -> Result<&2, &2, Cookie.Error, B.Context(Vars)>:
  C.delete_cookie(Vars, c, "theme", Cookie.defaults())
```

### `B.set_signed_cookie`, `B.signed_cookie`, `C.set_signed_cookie`, `C.signed_cookie`

```bend signature
def set_signed_cookie(c: B.Ctx, name: String, value: String, keys: SignedCookie.Keys, options: Cookie.Options) -> Result<&2, &2, Cookie.Error, B.Ctx>
def signed_cookie(c: B.Ctx, name: String, keys: SignedCookie.Keys) -> Maybe<&2, String>
```

Import `bendo/data/signed-cookie.bend` as `SignedCookie` and build `keys` once
at startup with `SignedCookie.configure(["current", "previous"])`.
`B.set_signed_cookie` signs `value` with HMAC-SHA256 under the first key and
percent-encodes it, so the value may hold any Unicode text. `B.signed_cookie` returns
`Some{value}` only when the first cookie named `name` verifies under one of the
keys. Signing authenticates the value; it does not encrypt it, and the name is
not signed.

```bend
def ex_session(+c: B.Ctx, +keys: SignedCookie.Keys) -> Result<&2, &2, Cookie.Error, B.Ctx>:
  user = or_empty(B.signed_cookie(c, "session", keys))
  B.set_signed_cookie(c, "session", user, keys, Cookie.defaults())

def ex_typed_session(+c: B.Context(Vars), +keys: SignedCookie.Keys) -> Result<&2, &2, Cookie.Error, B.Context(Vars)>:
  user = or_empty(C.signed_cookie(Vars, c, "session", keys))
  C.set_signed_cookie(Vars, c, "session", user, keys, Cookie.defaults())
```

## Connection info

[Connection info](../../connection.md) explains where the address comes from
and how trusted proxies work.

### `B.ConnInfo`

```bend signature
def ConnInfo() -> Data
```

The socket peer of a request, read once per connection with `getpeername`.
It never comes from a client header. Read it with `B.remote_address`,
`B.remote_port` and `B.address_type`.

```bend
def ex_peer(info: B.ConnInfo) -> String:
  B.address_type(info)
```

### `B.conn_info`

```bend signature
def conn_info(-Vars: Data, c: B.Context(Vars)) -> Maybe<&2, B.ConnInfo>
```

The peer of the request's connection. It is `None{}` when the request did not
arrive over a socket, as with `B.handle_with`, or when the lookup failed.
Pass `Unit` as `Vars` from a plain `B.Ctx` handler.

```bend
def ex_where(info: Maybe<&2, B.ConnInfo>) -> String:
  match info:
    case Some{peer}: B.remote_address(peer)
    case None{}: "unknown"

def ex_peer_text(+c: B.Ctx) -> B.Res:
  B.text(c, ex_where(B.conn_info(Unit, c)))
```

### `B.remote_address`, `B.remote_port`, `B.address_type`

```bend signature
def remote_address(info: B.ConnInfo) -> String
def remote_port(info: B.ConnInfo) -> U32
def address_type(info: B.ConnInfo) -> String
```

`B.remote_address` is the canonical text of the peer address: dotted IPv4, or
RFC 5952 IPv6. An IPv4-mapped IPv6 peer reports the IPv4 address.
`B.remote_port` is the peer's TCP port. `B.address_type` is `"IPv4"` or
`"IPv6"`.

```bend
def ex_peer_line(+info: B.ConnInfo) -> String:
  B.address_type(info) ++ " " ++ B.remote_address(info) ++ ":" ++ U32.show(B.remote_port(info))
```

### `B.client_address`

```bend signature
def client_address(-Vars: Data, c: B.Context(Vars), trusted: List<&2, B.Cidr>) -> Maybe<&2, String>
```

The client's address as canonical text. It is the socket peer unless the peer
is inside `trusted`, in which case `X-Forwarded-For` is read from the right
past the trusted hops. Build `trusted` with `B.cidrs`. It is `None{}` when
there is no socket peer.

```bend
def ex_client(+c: B.Ctx) -> B.Res:
  B.text(c, Maybe.default(&2, String, B.client_address(Unit, c, []), "unknown"))
```

## Typed variables

`bendo/app/context.bend`, imported as `C`, defines `C.Ctx<Vars>`, which
`main.bend` names `B.Context(Vars)`. `B.Ctx` is `B.Context(Unit)`. Each `C`
function takes the erased `Vars` type first, so typed middleware keeps its
record type. The calls above that list a `C.` name work on such a context;
the entries below set and read the record. [Middleware](../../middleware.md)
shows them in use. The examples use the `Vars` record from the setup.

### `C.variables`

```bend signature
def variables(-Vars: Data, c: B.Ctx) -> B.Context(Vars)
```

Turns a plain context into one that can carry a `Vars` record. The request and
the pending response are kept, and no record is set yet.

```bend
def ex_scoped(c: B.Ctx) -> B.Context(Vars):
  C.variables(Vars, c)
```

### `C.set`, `C.get`

```bend signature
def set(-Vars: Data, c: B.Context(Vars), value: Vars) -> B.Context(Vars)
def get(-Vars: Data, c: B.Context(Vars)) -> Maybe<&2, Vars>
```

`C.set` replaces the record. `C.get` reads it, and is `None{}` until the first
`C.set`. Every request starts without a record; state that outlives a request
belongs in a [store](state.md). `B.get` is route registration, not this.

```bend
def ex_user_name(value: Maybe<&2, Vars>) -> String:
  match value:
    case Some{Vars{name}}: name
    case None{}: "anonymous"

def ex_signed_in(c: B.Context(Vars)) -> String:
  ex_user_name(C.get(Vars, C.set(Vars, c, Vars{"Ada"})))
```

### `C.request_id`

```bend signature
def request_id(-Vars: Data, c: B.Context(Vars)) -> Maybe<&2, String>
```

The ID that the `B.request_id` [middleware](middleware.md) assigned to the
request, or `None{}` before that middleware runs or without it. The ID is kept
apart from the `Vars` record, so `C.set` and `C.variables` leave it in place.
Treat an incoming ID as a label, never as an identity.

```bend
def ex_trace(+c: B.Context(Vars)) -> B.Res:
  C.text(Vars, c, "request " ++ or_empty(C.request_id(Vars, c)))
```
