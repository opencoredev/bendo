# Request context

Handlers receive `B.Ctx`, an immutable context for one request. Read request data
with accessors, pass an updated context to the next handler, and finish with a
response helper. Startup resources remain in the dispatcher's `env` argument; use a
[store actor](store.md) for shared mutable state.

```python
import Base
import ../src/main.bend as B

def greet(+c: B.Ctx) -> B.Res:
  name = Maybe.default(&2, String, B.query(c, "name"), "world")
  B.text(B.header(B.status(c, 201), "x-greeting", "hello"), "Hello, " ++ name)
```

This returns status 201, `x-greeting: hello`, and a UTF-8 plain-text body. Setters
return a new context; retaining the old value does not mutate it.

## Read a request

These public functions take `c: B.Ctx`:

- `param(c, name) -> Maybe<&2, String>` returns a decoded route capture.
- `query(c, name) -> Maybe<&2, String>` returns the first decoded query value.
- `queries(c, name) -> List<&2, String>` returns all values in arrival order.
- `request_header(c, name) -> Maybe<&2, String>` returns the first header value,
  decoded strictly as UTF-8. Lookup is case-insensitive. `None` means absent or
  undecodable; no replacement characters are inserted.
- `header_bytes(c, name) -> List<&2, List<&2, U32>>` preserves every matching
  header's octets in arrival order. An empty list means absent; a nonempty list
  with a failed text decode means present but undecodable.
- `method(c) -> Request.Method` returns the parsed method constructor.
- `path(c) -> String` returns the path as received, without the query.
- `url(c) -> String` returns the original path plus query, including a trailing
  `?` when present. It does not construct an absolute URL, trust `Host`, or read
  forwarded headers.
- `raw_body(c) -> List<&2, U32>` returns the buffered body octets.
- `cookie(c, name) -> Maybe<&2, String>` returns the first valid cookie of that
  name, with case-sensitive lookup.
- `cookies(c) -> List<&2, Cookie.Entry>` returns valid pairs from every Cookie
  field in arrival order, including repeated names and empty values. Malformed
  pairs are skipped; see [Cookies](cookies.md).

Query parsing follows the shared URL-encoded parser: names are case-sensitive,
`+` means space, empty values are retained, and empty `&` pieces are ignored.
Malformed percent escapes produce an empty 400 in the HTTP parser. Invalid UTF-8
in otherwise valid percent syntax produces a plain-text 400 before route
resolution, including on missing routes and method mismatches. They never make
all query lookups silently return empty results.

## Build a response

All final helpers return `B.Res`. They consume the supplied context's pending
status and headers. The initial status is 200.

- `text(c, value: String)` uses `text/plain; charset=utf-8`.
- `html(c, value: String)` uses `text/html; charset=utf-8`; it does not escape HTML.
- `json(c, value: Json.Json)` uses `application/json; charset=utf-8` and the shared
  JSON writer. Invalid JSON values, such as a malformed `JNumber`, produce 500.
- `body(c, octets, content_type: Maybe<&2, String>)` sends exact bytes. `None`
  preserves an accumulated Content-Type or leaves it absent. `Some{value}` sets it.
- `redirect(c, location)` returns an empty 302 response and sets Location.
- `redirect_status(c, location, code)` accepts only 301, 302, 303, 307 and 308.
- `not_found(c)` forces 404 with negotiated `Not Found` (JSON for explicit
  application/json Accept, otherwise plain text).
- `status(c, code) -> B.Ctx` changes the pending status.
- `set_cookie(c, name, value, options)` and `delete_cookie(c, name, options)` return
  `Result<&2, &2, Cookie.Error, B.Ctx>`. Successful calls append separate Set-Cookie
  fields. Handle `Fail` before building the response; see [Cookies](cookies.md).
- `header(c, name, value) -> B.Ctx` changes a pending response header. Names are
  folded to lowercase; a later setter replaces earlier values of that name.

Text, HTML and JSON helpers own their Content-Type and replace any pending value.
Other pending headers survive. Redirect and not-found helpers own their status.
The response writer still owns Content-Length, Transfer-Encoding and HEAD/bodyless
status framing; helpers cannot override those rules.

Invalid status codes, header names, header values, body octets or redirect
locations fail closed as an empty 500. Header validation follows the HTTP response
model, including rejection of CR/LF and surrounding whitespace. Setters retain
invalid data until finalization, so callers cannot accidentally emit it. Error
responses validate the headers they would send, after merging Vary and
replacing Content-Type; see [0011](decisions/0011-crash.md). Do not
use `header` repeatedly to append Set-Cookie; use `set_cookie` instead.

The request accessor is named `request_header` because Bend does not overload
functions by arity. `header` writes the response. `B.get` remains route registration;
typed-variable `get` lives in the context module.

## Typed variables

`src/app/context.bend` defines `Ctx<Vars>`. `B.Ctx` is `Ctx<Unit>` for the closed
dispatcher. Choose an app-owned `Data` record and call `C.variables(Vars, c)` at
an app boundary to get a `B.Context(Vars)` with no value set. All request and
response state survives this conversion.

```python
import Base
import ../src/main.bend as B
import ../src/app/context.bend as C

type Vars is Data:
  Vars{user: String, visits: U32}

def user_name(value: Maybe<&2, Vars>) -> String:
  match value:
    case None{}: "anonymous"
    case Some{Vars{name, visits}}: name

def greet_user(+c: B.Context(Vars)) -> B.Res:
  C.text(Vars, c, user_name(C.get(Vars, c)))

def derive_user(c: B.Ctx) -> B.Res:
  scoped = C.variables(Vars, c)
  greet_user(C.set(Vars, scoped, Vars{"Ada", 1}))
```

`C.set(Vars, c, value) -> Ctx<Vars>` replaces the typed record;
`C.get(Vars, c) -> Maybe<&2, Vars>` returns `None` before the first set. Record
field access is checked by Bend. For independently optional fields, put a typed
`Maybe` on each field and write app-owned field setters that rebuild the record.
There is no string-keyed variable map, row typing, generated setter machinery,
or shared mutable state. Each request begins without variables; shared actors
and channels belong in `env`.

Every context operation also exists in `C` with an explicit erased `Vars` argument:
for example, `C.query(Vars, c, "name")` and `C.status(Vars, c, 201)`. This lets typed
middleware pass `Ctx<Vars>` without erasing its record type. Response helpers still
return `Res`, preserving `dispatch(tag, ctx, env) -> IO(Res)`.

Existing low-level callers can use `src/http/response.bend` for
`Response.text(status, text)` and `Response.body(status, headers, octets)`.
`B.text` and `B.body` now take a context. New handlers should use accessors instead
of destructuring context internals.

Verify with `bun test --timeout 30000 tests/context.test.ts`.

[Middleware](middleware.md) passes the same typed context through an affine
`next` continuation, so middleware can set variables before the handler runs.

With [request-ID middleware](observability.md#request-id), handlers read
`C.request_id(Vars, c) -> Maybe<&2, String>`. Framework metadata lives separately
from the app's typed variables. `B.timing_mark(Vars, c, name, duration_ms)` records
a named duration in the active request's timing collector and returns `IO(Bool)`.

[Typed HTTP errors and custom not-found handlers](decisions/0011-crash.md) use
`B.error(c, B.http_error(status, message))`, `B.result(c, result)`, and
`B.on_not_found(Tag, id)`. Private 5xx messages default to `Internal Server Error`;
existing `on_error` hooks may replace their safe rendered responses.
