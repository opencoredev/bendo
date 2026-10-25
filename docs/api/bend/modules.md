# Data and protocol modules

Names from Bendo's lower-level modules that the guides call directly: cookie
options and signing keys, form and multipart bodies, JSON Schema export, hashing, comparison,
randomness and encodings, raw requests and responses, stream steps, route patterns and WebSocket frames.
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
import ./bendo/data/signed-cookie.bend as SignedCookie
import ./bendo/crypto/sha256.bend as SHA
import ./bendo/crypto/compare.bend as Compare
import ./bendo/crypto/random.bend as Random
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

### `Cookie.defaults`, `Cookie.deletion`

```bend signature
def defaults() -> Cookie.Options
def deletion(options: Cookie.Options) -> Cookie.Options
```

`Cookie.defaults` leaves out every attribute. `Cookie.deletion` turns options
into the ones `B.delete_cookie` sends: `Max-Age=0`, no `Expires`, and every
other attribute as given.

```bend
def ex_forget_options() -> Cookie.Options:
  Cookie.deletion(Cookie.defaults())
```

### `Cookie.Entry`, `Cookie.parse`, `Cookie.first`

```bend signature
type Entry is Data:
  Entry{name: String, value: String}

def parse(header: String) -> List<&2, Entry>
def first(pairs: List<&2, Entry>, name: String) -> Maybe<&2, String>
```

The pure parser behind `B.cookies` and `B.cookie`. `Cookie.parse` reads one
`Cookie` field value into its valid pairs in order, skipping malformed
segments and keeping repeated names. `Cookie.first` returns the value of the
first pair named `name`, compared case-sensitively.

```bend
def ex_pairs() -> List<&2, Cookie.Entry>:
  Cookie.parse("theme=dark; session=abc123")

def ex_theme() -> Maybe<&2, String>:
  Cookie.first(ex_pairs(), "theme")
```

### `Cookie.serialize`, `Cookie.serialize_pair`

```bend signature
def serialize(+name: String, +value: String, +options: Cookie.Options) -> Result<&2, &2, Cookie.Error, String>
def serialize_pair(name: String, value: String) -> String
```

`Cookie.serialize` builds the `Set-Cookie` field value that `B.set_cookie`
appends, after the same checks, and fails with the same errors.
`Cookie.serialize_pair` writes `name=value` without any check; use it only for
values already validated.

```bend
def ex_set_cookie_value() -> Result<&2, &2, Cookie.Error, String>:
  Cookie.serialize("session", "abc123", ex_session_options())

def ex_trusted_pair() -> String:
  Cookie.serialize_pair("theme", "dark")
```

### `Cookie.name_valid`, `Cookie.value_valid`

```bend signature
def name_valid(s: String) -> Bool
def value_valid(s: String) -> Bool
```

The checks `Cookie.serialize` applies. A name must be a nonempty HTTP token. A
value may be empty and may hold ASCII `0x21`, `0x23–0x2B`, `0x2D–0x3A`,
`0x3C–0x5B` and `0x5D–0x7E`: no space, `"`, `,`, `;` or `\`.

```bend
def ex_storable(name: String, value: String) -> Bool:
  Cookie.name_valid(name) && Cookie.value_valid(value)
```

### `SignedCookie.Keys`, `SignedCookie.configure`

```bend signature
type Keys is Data:   # data/signed-cookie.bend
  Keys{first: String, rest: List<&2, String>}

def configure(xs: List<&2, String>) -> Maybe<&2, SignedCookie.Keys>
```

The secrets that `B.set_signed_cookie` and `B.signed_cookie` take. New cookies
are signed with the first key, and a cookie verifies under any of them, so put
a new secret first and keep the old one after it until its cookies expire.
`SignedCookie.configure` returns `None{}` for an empty list or when any key is
empty or holds a non-scalar character. Build keys with it once at startup
rather than with the `Keys` constructor: the cookie calls recheck every slot.
On a bad one, `B.set_signed_cookie` fails with `Cookie.InvalidSecret{}` and
`B.signed_cookie` returns `None{}`, as it does for a cookie that doesn't verify.

```bend
def ex_keys() -> Maybe<&2, SignedCookie.Keys>:
  SignedCookie.configure(["new secret", "old secret"])
```

## Form and multipart bodies

[Multipart form bodies](../../data/multipart.md) covers parsing, limits and
memory use.

### `Form.parse_body`

```bend signature
def parse_body(content_type: String, body: List<&2, U32>) -> Result<&2, &2, Multipart.Error, List<&2, Multipart.Part>>
```

`Form.parse_body_with_limits` with the default multipart limits: 1 MiB per
file, 2 MiB per body, 128 parts and 8,192 header bytes per part.

```bend
def ex_form(content_type: String, body: List<&2, U32>) -> Result<&2, &2, Multipart.Error, List<&2, Multipart.Part>>:
  Form.parse_body(content_type, body)
```

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

### `Multipart.parse`, `Multipart.parse_with_limits`

```bend signature
def parse(content_type: String, body: List<&2, U32>) -> Result<&2, &2, Multipart.Error, List<&2, Multipart.Part>>
def parse_with_limits(+content_type: String, +body: List<&2, U32>, +limits: Multipart.Limits) -> Result<&2, &2, Multipart.Error, List<&2, Multipart.Part>>
```

The `Form` parsers restricted to `multipart/form-data`: any other content type
fails. `Multipart.parse` uses the default limits.

```bend
def ex_multipart_only(content_type: String, body: List<&2, U32>) -> Result<&2, &2, Multipart.Error, List<&2, Multipart.Part>>:
  Multipart.parse(content_type, body)

def ex_small_upload(content_type: String, body: List<&2, U32>) -> Result<&2, &2, Multipart.Error, List<&2, Multipart.Part>>:
  Multipart.parse_with_limits(content_type, body, Multipart.Limits{65536, 131072, 16, 4096})
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

### `Multipart.error_status`

```bend signature
def error_status(e: Multipart.Error) -> U32
```

The status to answer a failed parse with: 413 for `TooLarge{}`, 400 for every
other error.

```bend
def ex_upload_answer(c: B.Ctx, result: Result<&2, &2, Multipart.Error, List<&2, Multipart.Part>>) -> B.Res:
  match result:
    case Fail{error}: B.text(B.status(c, Multipart.error_status(error)), "Upload refused")
    case Done{parts}: B.text(c, "Uploaded")
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

### `JS.email`, `JS.url`

```bend signature
def email() -> String
def url() -> String
```

The ECMAScript pattern sources that `JS.export` writes for strings with the
`S.Email{}` and `S.Url{}` formats. Both are anchored and mean the same with or without the `u`
flag.

```bend
def ex_text_patterns() -> List<&2, String>:
  [JS.email(), JS.url()]
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

### `SchemaPattern.matches`, `SchemaPattern.source`

```bend signature
def matches(+p: Pattern, s: String) -> Bool
def source(p: Pattern) -> String
```

`SchemaPattern.matches` tests a whole string against a pattern with the proven
derivative matcher. The decoder uses a faster compiled table and falls back to
this one when the table fails its size check. `SchemaPattern.source` returns the anchored ECMAScript source that
`JS.export` writes as `pattern`.

```bend
def ex_is_slug(s: String) -> Bool:
  SchemaPattern.matches(ex_slug(), s)

def ex_slug_source() -> String:
  SchemaPattern.source(ex_slug())
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

### `Utf8.valid`

```bend signature
def valid(s: String) -> Bool
```

`True` when every character is a Unicode scalar value, so `Utf8.encode` writes
no U+FFFD. Check secrets with it before hashing them, since two strings that
differ only in lone surrogates encode to the same bytes.

```bend
def ex_digest_if(valid: Bool, secret: String) -> Maybe<&2, String>:
  match valid:
    case True{}: Some{ex_digest(secret)}
    case False{}: None{}

def ex_safe_digest(+secret: String) -> Maybe<&2, String>:
  ex_digest_if(Utf8.valid(secret), secret)
```

### `Utf8.decode`

```bend signature
def decode(xs: List<&2, U32>) -> Maybe<&2, String>
```

Decodes UTF-8 octets, such as a request body, into a string. It returns
`None{}` for anything that is not strict UTF-8: a value above 255, an overlong
encoding, a surrogate, a scalar above U+10FFFF, a stray continuation byte or
an incomplete sequence. Nothing is replaced with U+FFFD.

```bend
def ex_body_text(+c: B.Ctx) -> String:
  Maybe.default(&2, String, Utf8.decode(B.raw_body(c)), "")
```

### `Compare.ct_equal`

```bend signature
def ct_equal(xs: List<&2, U32>, ys: List<&2, U32>) -> Bool
```

Whether two byte lists are equal, visiting every element of both instead of
stopping at the first difference. Use it to compare secrets, such as the
SHA-256 digests of a submitted and a stored password. It is best effort: Bend
gives no constant-time guarantee, and the list lengths stay observable, so
compare fixed-length digests rather than the secrets themselves.

```bend
def ex_same_secret(a: String, b: String) -> Bool:
  Compare.ct_equal(SHA.hash(Utf8.encode(a)), SHA.hash(Utf8.encode(b)))
```

### `Random.random_bytes`

```bend signature
def random_bytes(n: Nat) -> IO(Result<&1, &1, U32 & String, List<&2, U32>>)
```

`n` bytes from the operating system's secure source: `getrandom` on Linux,
`arc4random_buf` on macOS and `crypto.getRandomValues` in JavaScript. A
failure gives `Fail{(errno, message)}`, and JavaScript reports a missing or
failing WebCrypto as error 5. There is no fallback generator. `0n` reads
nothing.

```bend
def ex_token_text(r: Result<&1, &1, U32 & String, List<&2, U32>>) -> String:
  match r:
    case Done{bytes}: Hex.encode(bytes)
    case Fail{e}: ""

def ex_session_id() -> IO(String):
  do IO<String>:
    got : Result<&1, &1, U32 & String, List<&2, U32>> <- Random.random_bytes(32n)
    return ex_token_text(got)
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

### `Request.Version`

```bend signature
type Version is Data:
  Http10{}
  Http11{}
```

The HTTP version of a request head, the `version` field of `B.Req`. Build one
only for a request you pass to `B.handle`, usually `Request.Http11{}`.

```bend
def ex_http11() -> Request.Version:
  Request.Http11{}

def ex_test_request(path: String) -> B.Req:
  Request.Req{Request.Get{}, path, None{}, ex_http11(), []}
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

### `Frame.start`, `Frame.resume`, `Frame.next`, `Frame.feed`

```bend signature
def start(cfg: Config, xs: List<&2, U32>) -> Decoded
def resume(b: Body, xs: List<&2, U32>) -> Decoded
def next(cfg: Config, body: Maybe<&2, Body>, xs: List<&2, U32>) -> Decoded
def feed(+cfg: Config, +body: Maybe<&2, Body>, +pending: List<&2, U32>, chunks: List<&2, List<&2, U32>>) -> Decoded
```

The resumable decoder a connection uses, so a payload that arrives over many
reads costs linear work. `Frame.start` answers like `Frame.decode`, except that
a frame whose header was accepted but whose payload is incomplete comes back as
`Partial{body}`: keep `body` and drop the buffer. `Frame.resume` continues that
body with the next bytes; pass it only a body from `start` or `resume` with
the same `Config`. While `start` answers `NeedMore`, append the next read and
call `start` again. `Frame.next` makes that choice, `start` without a body and
`resume` with one. `Frame.feed` folds `next` over a list of reads, and gives
the same frame or rejection as `Frame.decode` on the whole input.

```bend
def ex_continue(cfg: Frame.Config, d: Frame.Decoded, pending: List<&2, U32>, read: List<&2, U32>) -> Frame.Decoded:
  match d:
    case Frame.Partial{body}: Frame.resume(body, read)
    case _: Frame.start(cfg, List.append(&2, U32, pending, read))

def ex_step(cfg: Frame.Config, body: Maybe<&2, Frame.Body>, read: List<&2, U32>) -> Frame.Decoded:
  Frame.next(cfg, body, read)

def ex_reads(cfg: Frame.Config, chunks: List<&2, List<&2, U32>>) -> Frame.Decoded:
  Frame.feed(cfg, None{}, [], chunks)
```

### `Frame.encode`, `Frame.Key`

```bend signature
def encode(max: U32, +f: Frame, +k: Maybe<&2, Key>) -> Maybe<&2, List<&2, U32>>

type Key is Data:
  MaskKey{a: U32, b: U32, c: U32, d: U32}

type Frame is Data:
  Frame{fin: Bool, opcode: Opcode, payload: List<&2, U32>}
```

Encodes one frame with the shortest length form, or answers `None{}` when RFC
6455 does not let an endpoint send it: a fragmented control frame, a control
payload over 125 bytes, a payload over `max`, or a payload or key value above
255. A server passes `None{}` as the key. A client passes
`Some{Frame.MaskKey{a, b, c, d}}` with fresh random octets for every frame.

```bend
def ex_server_text() -> Maybe<&2, List<&2, U32>>:
  Frame.encode(1048576, Frame.Frame{True{}, Frame.OpText{}, Utf8.encode("hi")}, None{})

def ex_client_key(a: U32, b: U32, c: U32, d: U32) -> Frame.Key:
  Frame.MaskKey{a, b, c, d}

def ex_client_ping(key: Frame.Key) -> Maybe<&2, List<&2, U32>>:
  Frame.encode(125, Frame.Frame{True{}, Frame.OpPing{}, []}, Some{key})
```
