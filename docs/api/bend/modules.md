# Data and protocol modules

Names from Bendo's lower-level modules that the guides call directly: cookie
options, form and multipart bodies, JSON Schema export, hashing and encodings,
raw requests and responses, stream steps, route patterns and WebSocket frames.
Everything else in these modules is internal.

Examples on this page are one Bend program and share this setup:

```bend
import Base
import ./bendo/main.bend as B
import ./bendo/data/cookie.bend as Cookie
import ./bendo/data/form.bend as Form
import ./bendo/data/multipart.bend as Multipart
import ./bendo/data/json.bend as J
import ./bendo/data/schema.bend as S
import ./bendo/data/json-schema.bend as JS
import ./bendo/data/schema-pattern.bend as SchemaPattern
import ./bendo/crypto/sha256.bend as SHA
import ./bendo/data/hex.bend as Hex
import ./bendo/data/utf8.bend as Utf8
import ./bendo/http/request.bend as Request
import ./bendo/http/response.bend as Response
import ./bendo/http/stream_types.bend as StreamTypes
import ./bendo/http/sse_types.bend as SseTypes
import ./bendo/router/pattern.bend as RoutePattern
import ./bendo/ws/frame.bend as Frame
```

## Cookies

`B.set_cookie`, `B.delete_cookie` and `B.set_signed_cookie` take these
options and return these errors. [Cookies](../../cookies.md) describes
validation and output in full.

### `Cookie.Options`

```bend signature
type Options is Data:
  Options{path: Maybe<&2, String>, domain: Maybe<&2, String>, max_age: Maybe<&2, MaxAge>, expires: Maybe<&2, String>, secure: Bool, http_only: Bool, same_site: Maybe<&2, SameSite>, partitioned: Bool}
```

The attributes of a `Set-Cookie` field, emitted in field order. `None{}` and
`False{}` leave an attribute out. `expires` must be an IMF-fixdate such as
`Wed, 21 Oct 2015 07:28:00 GMT`.

```bend
def ex_session_options() -> Cookie.Options:
  Cookie.Options{Some{"/"}, None{}, Some{Cookie.Seconds{3600n}}, None{}, True{}, True{}, Some{Cookie.Lax{}}, False{}}
```

### `Cookie.MaxAge`

```bend signature
type MaxAge is Data:
  Seconds{seconds: Nat}
  NegativeSeconds{seconds: Nat}
```

`Max-Age` in whole seconds. `NegativeSeconds{n}` writes `-n`. Zero or a
negative age makes the browser drop the cookie at once.

```bend
def ex_expire_now() -> Cookie.MaxAge:
  Cookie.NegativeSeconds{1n}
```

### `Cookie.SameSite`

```bend signature
type SameSite is Data:
  Strict{}
  Lax{}
  NoRestriction{}
```

The `SameSite` attribute. `NoRestriction{}` writes `SameSite=None`, which
requires `secure`.

```bend
def ex_cross_site() -> Cookie.SameSite:
  Cookie.NoRestriction{}
```

### `Cookie.Error`

```bend signature
type Error is Data:
  InvalidName{}
  InvalidValue{}
  InvalidPath{}
  InvalidDomain{}
  InvalidExpires{}
  SameSiteRequiresSecure{}
  PartitionedRequiresSecure{}
  InvalidSecret{}
```

Why a cookie was not set. Nothing is appended when a setter fails.
`InvalidSecret{}` comes from signed-cookie keys with an empty or invalid slot.

```bend
def ex_remembered(result: Result<&2, &2, Cookie.Error, B.Ctx>) -> B.Res:
  match result:
    case Fail{error}: Response.text(400, "Invalid cookie")
    case Done{updated}: B.text(updated, "Remembered")

def ex_remember(c: B.Ctx) -> B.Res:
  ex_remembered(B.set_cookie(c, "session", "abc123", ex_session_options()))
```

## Form and multipart bodies

[Multipart form bodies](../../data/multipart.md) covers parsing, limits and
memory use.

### `Form.parse_body_with_limits`

```bend signature
def parse_body_with_limits(+content_type: String, body: List<&2, U32>, limits: Multipart.Limits) -> Result<&2, &2, Multipart.Error, List<&2, Multipart.Part>>
```

Parses a `multipart/form-data` or `application/x-www-form-urlencoded` body,
chosen by `content_type`, into parts in arrival order. The limits apply to
multipart bodies only; the server's `B.body_limit` bounds every body.

```bend
def ex_upload(content_type: String, body: List<&2, U32>) -> Result<&2, &2, Multipart.Error, List<&2, Multipart.Part>>:
  Form.parse_body_with_limits(content_type, body, Multipart.Limits{3145728, 4194304, 128, 8192})
```

### `Multipart.Limits`

```bend signature
type Limits is Data:
  Limits{file_size: U32, total_size: U32, parts: U32, header_size: U32}
```

Inclusive limits in octets (parts for `parts`): each file's payload, the whole
body, the number of fields and files, and each part's header block. The
defaults used by `Form.parse_body` are 1 MiB, 2 MiB, 128 and 8,192.

```bend
def ex_small_limits() -> Multipart.Limits:
  Multipart.Limits{65536, 131072, 16, 4096}
```

### `Multipart.Part`

```bend signature
type Part is Data:
  Field{name: String, value: String}
  File{name: String, filename: String, content_type: String, bytes: List<&2, U32>}
```

One form field or uploaded file. File contents stay as raw octets.

```bend
def ex_part_name(part: Multipart.Part) -> String:
  match part:
    case Multipart.Field{name, value}: name
    case Multipart.File{name, filename, content_type, bytes}: filename
```

### `Multipart.Error`

```bend signature
type Error is Data:
  Malformed{}
  TooLarge{}
  Urlencoded{error: Url.Error}
```

`TooLarge{}` when a limit is exceeded, `Malformed{}` for a bad multipart body,
and `Urlencoded{error}` wrapping the URL-encoded parser's error. Answer 413
for `TooLarge{}` and 400 otherwise.

```bend
def ex_upload_status(error: Multipart.Error) -> U32:
  match error:
    case Multipart.TooLarge{}: 413
    case Multipart.Malformed{}: 400
    case Multipart.Urlencoded{e}: 400
```

## JSON Schema export

[JSON Schema export](../../data/json-schema.md) lists how each schema maps
and where validators differ from Bendo's decoder.

### `JS.export`, `JS.document`

```bend signature
def export(+s: S.Schema) -> J.Json
def document(+s: S.Schema) -> J.Json
```

`JS.export` turns a schema into JSON Schema 2020-12 as a JSON value.
`JS.document` adds `"$schema": "https://json-schema.org/draft/2020-12/schema"`.
Both are total.

```bend
def ex_flag_schema() -> S.Schema:
  S.BooleanSchema{}

def ex_schema_text() -> Result<&2, &2, J.Error, String>:
  J.stringify(JS.document(ex_flag_schema()))

def ex_schema_value() -> J.Json:
  JS.export(ex_flag_schema())
```

### `SchemaPattern.Pattern`, `SchemaPattern.Range`, `SchemaPattern.seq`

```bend signature
type Range is Data:
  Range{lo: U32, hi: U32}

type Pattern is Data:
  Literal{text: String}
  Class{ranges: List<&2, Range>}
  Cat{first: Pattern, second: Pattern}
  Repeat{body: Pattern, min: Nat, max: Maybe<&2, Nat>}

def seq(ps: List<&2, Pattern>) -> Pattern
```

A string pattern for `S.StringSchema`, written as data rather than regex
source. It always matches the whole string. `Range{lo, hi}` is an inclusive
range of code points, and `SchemaPattern.seq` concatenates a list of patterns.
See [Schemas](../../data/schema.md#patterns).

```bend
def ex_lower() -> SchemaPattern.Pattern:
  SchemaPattern.Class{[SchemaPattern.Range{97, 122}, SchemaPattern.Range{48, 57}]}

# [a-z0-9]+(-[a-z0-9]+)*
def ex_slug() -> SchemaPattern.Pattern:
  SchemaPattern.seq([SchemaPattern.Repeat{ex_lower(), 1n, None{}}, SchemaPattern.Repeat{SchemaPattern.Cat{SchemaPattern.Literal{"-"}, SchemaPattern.Repeat{ex_lower(), 1n, None{}}}, 0n, None{}}])
```

## Hashing and encodings

[Crypto and encoding](../../crypto.md) lists the other hashes, HMAC and Base64.

### `SHA.hash`, `Hex.encode`, `Utf8.encode`

```bend signature
def hash(xs: List<&2, U32>) -> List<&2, U32>     # crypto/sha256.bend
def encode(xs: List<&2, U32>) -> String          # data/hex.bend
def encode(s: String) -> List<&2, U32>           # data/utf8.bend
```

`SHA.hash` is SHA-256: 32 bytes, big-endian. `Hex.encode` writes bytes as
lowercase hex. `Utf8.encode` turns a string into its UTF-8 octets, writing
U+FFFD for a non-scalar character (a lone surrogate), as `TextEncoder` does.
Bytes are lists with one octet per `U32`.

```bend
def ex_digest(text: String) -> String:
  Hex.encode(SHA.hash(Utf8.encode(text)))
```

## Requests and responses

### `Request.Method`

```bend signature
type Method is Data:
  Get{}
  Head{}
  Post{}
  Put{}
  Delete{}
  Connect{}
  Options{}
  Trace{}
  Patch{}
  Extension{token: String}
```

An HTTP method. `B.method` returns one, and `B.on` takes a list of them.
`Extension{token}` holds any other method token as written.

```bend
type Route is Data:
  Save{}

def ex_save_routes() -> List<&2, B.Registration(Route)>:
  [B.on(Route, [Request.Post{}, Request.Put{}], "/items/:id", Save{})]

def ex_is_write(m: Request.Method) -> Bool:
  match m:
    case Request.Post{}: True{}
    case Request.Put{}: True{}
    case Request.Patch{}: True{}
    case Request.Delete{}: True{}
    case _: False{}
```

### `Response.Res`

```bend signature
type Res is Data:
  Res{status: U32, headers: List<&2, Request.Header>, body: List<&2, U32>, representation: Maybe<&2, List<&2, U32>>}
```

The response a handler returns, the same type as `B.Res`. Destructure it in
middleware to change a field. `representation` holds the bytes a matching
`GET` would send, which sets `Content-Length` on `HEAD` and `304` answers.

```bend
def ex_accepted(res: Response.Res) -> Response.Res:
  Response.Res{code, headers, body, representation} = res
  Response.Res{202, headers, body, representation}
```

### `Response.text`

```bend signature
def text(status: U32, s: String) -> Res
```

A `text/plain; charset=utf-8` response with `status`, built without a
context. It carries none of the headers or cookies set on a context; use it
where no context exists, and `B.text` everywhere else.

```bend
def ex_plain_error() -> Response.Res:
  Response.text(400, "Invalid cookie")
```

## Stream steps

### `StreamTypes.Step`

```bend signature
type Step<-State: Type> is Type:
  Chunk{bytes: List<&2, U32>, state: State}
  End{state: State}
  Failed{state: State}
```

What a `B.stream` step returns, the type behind `B.StreamStep(State)`.
`Chunk` sends bytes and continues with the new state, `End` finishes the
body, and `Failed` aborts the response. Each carries the state that the
cleanup function receives. See [Stream a response](../../streaming.md).

```bend
def ex_countdown(n: Nat) -> IO(StreamTypes.Step<Nat>):
  match n:
    case 0n: IO.pure(StreamTypes.Step<Nat>, StreamTypes.End{0n})
    case 1n+left: IO.pure(StreamTypes.Step<Nat>, StreamTypes.Chunk{Utf8.encode("tick\n"), left})
```

### `SseTypes.Step`

```bend signature
type Step<-State: Type> is Type:
  Send{frame: Sse.Frame, state: State}
  Idle{state: State}
  End{state: State}
  Failed{state: State}
```

What a `B.stream_sse` step returns, the type behind `B.SseStep(State)`.
`Send` writes one event, `Idle` sends nothing this time (heartbeats keep the
connection open), `End` closes the stream and `Failed` aborts it. See
[Server-Sent Events](../../sse.md).

```bend
def ex_ticks(n: Nat) -> IO(SseTypes.Step<Nat>):
  match n:
    case 0n: IO.pure(SseTypes.Step<Nat>, SseTypes.End{0n})
    case 1n+left: IO.pure(SseTypes.Step<Nat>, SseTypes.Send{B.sse_data("tick"), left})
```

## Route patterns

[Route patterns](../../router-patterns.md) defines the syntax and how values
are decoded and constrained.

### `RoutePattern.compile`, `RoutePattern.Pattern`, `RoutePattern.PatternError`

```bend signature
def compile(source: String) -> Result<&2, &2, PatternError, Pattern>

type Pattern is Data:
  Pattern{segments: List<&2, Segment>}

type PatternError is Data:
  PatternError{kind: ErrorKind, segment: String}
```

Compiles a route pattern such as `/posts/:id{int}` once, so it can be matched
against many paths. A pattern must start with `/` (`*` alone means `/*`).
The error names the problem and the offending segment.

```bend
def ex_compiled() -> Result<&2, &2, RoutePattern.PatternError, RoutePattern.Pattern>:
  RoutePattern.compile("/posts/:id{int}")
```

### `RoutePattern.match_path`, `RoutePattern.Params`

```bend signature
def match_path(pattern: Pattern, path: String) -> Maybe<&2, Params>
def Params() -> Data    # List<&2, Param>
```

Matches a decoded path against a compiled pattern and returns the captured
parameters in pattern order, or `None{}` when it does not match. Paths that
do not start with `/` never match.

```bend
def ex_matched(result: Result<&2, &2, RoutePattern.PatternError, RoutePattern.Pattern>) -> Maybe<&2, RoutePattern.Params>:
  match result:
    case Done{pattern}: RoutePattern.match_path(pattern, "/posts/42")
    case Fail{error}: None{}
```

## WebSocket frames

[WebSocket frames and messages](../../websocket-frames.md) describes the
codec, the rejection rules and the encoder.

### `Frame.decode`, `Frame.Config`, `Frame.Role`, `Frame.Decoded`

```bend signature
def decode(cfg: Config, xs: List<&2, U32>) -> Decoded

type Config is Data:
  Config{role: Role, max: U32}

type Role is Data:
  Server{}
  Client{}

type Decoded is Data:
  NeedMore{need: Nat}
  Partial{body: Body}
  Got{frame: Frame, key: Maybe<&2, Key>, rest: List<&2, U32>}
  Reject{code: U32}
```

Reads one RFC 6455 frame from the front of a buffer. `Server{}` expects
masked client frames and `Client{}` unmasked ones; `max` caps the payload
length. `Got` returns the unmasked frame and the bytes after it, `NeedMore`
says how many more bytes are needed at least, and `Reject{code}` gives the
close code to send. `Partial` belongs to the incremental decoder;
`Frame.decode` reports it as `NeedMore` instead.

```bend
def ex_read_frame(bytes: List<&2, U32>) -> Frame.Decoded:
  Frame.decode(Frame.Config{Frame.Server{}, 1048576}, bytes)

def ex_role() -> Frame.Role:
  Frame.Client{}
```
