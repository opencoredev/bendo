---
title: Accept file uploads
description: Receive multipart file uploads in Bendo, raise the body limit for one route, refuse oversized requests early and map parser errors to status codes.
---

# Accept file uploads

This guide adds an upload route that takes files up to 4 MiB in a
`multipart/form-data` form, while every other route keeps a small body limit.
The route answers with each file's name, size and SHA-256 digest.

Bendo reads the whole request body into memory before a handler runs, then
the multipart parser splits it into fields and files. There is no streaming to
disk, so the limits on this page are also your memory budget. The snippets
come from [the complete app](#the-complete-app) at the end of the page.

## Raise the server body limit

The server refuses any body over its `body_limit`, 1 MiB by default, with
`413 Content Too Large`. Set the ceiling to the largest body any route
accepts. `B.config()` returns a `Config.Config` record, so copy it with one
field changed:

```bend
def with_body_limit(config: Config.Config, bytes: U32) -> Config.Config:
  Config.Config{host, port, limit, headers, idle, head, body, write, max, keep, router, mode, workers} = config
  Config.Config{host, port, bytes, headers, idle, head, body, write, max, keep, router, mode, workers}
```

```bend
def config() -> Config.Config:
  with_body_limit(B.config(), 5242880)
```

## Keep the other routes small

Route limits can only tighten the ceiling, never raise it. Give the upload
route its own limit and put a small one on everything else:

```bend
B.use_path(Tag, "/uploads", Builtin{B.body_limit(5242880)}),
B.use_path(Tag, "/api/*", Builtin{B.body_limit(65536)}),
```

So that the server can refuse a large body before reading it, serve with
`B.serve_limits_with` and a selector that tells it which tags carry a limit:

```bend
def limit(tag: Tag) -> Maybe<&2, U32>:
  match tag:
    case Builtin{id}: B.builtin_body_limit(id)
    case _: None{}
```

```bend
case Done{table}: B.serve_limits_with(~Unit, ~Tag, ~limit, ~Unit, ~handler, ~middleware, table, Unit{}, config())
```

With it, a 70 KB request to `/api/echo` gets 413 as soon as its
`Content-Length` arrives, and a chunked body is cut off at the limit. With
plain `B.serve_with`, the same middleware still answers 413, but only after the
body has been read. The [limits reference](../limits-cache.md#limit-request-bodies-before-buffering)
covers request hooks that rewrite paths.

## Parse the form

`Form.parse_body_with_limits` takes the request's `Content-Type`, the body
octets and the multipart limits. It accepts URL-encoded forms too, so one
handler serves both:

```bend
uploaded(c, Form.parse_body_with_limits(content_type(C.request_header(Unit, c, "content-type")), C.raw_body(Unit, c), upload_limits()))
```

`Multipart.Limits` holds the largest file, the largest whole body, the most
parts and the largest header block of one part, in that order:

```bend
def upload_limits() -> Multipart.Limits:
  Multipart.Limits{4194304, 5242880, 8, 8192}
```

The result is every part in arrival order. A field is
`Multipart.Field{name, value}` with UTF-8 text, and a file is
`Multipart.File{name, filename, content_type, bytes}` with the exact octets.
This handler keeps the files and skips the fields:

```bend
case Multipart.File{name, filename, content_type, bytes} <> rest: file_json(name, filename, content_type, bytes) <> files(rest)
case _ <> rest: files(rest)
```

The filename is whatever the client sent. Never use it as a path on disk
without cleaning it; better, store the file under a name you generate.

## Map errors to status codes

A body over any multipart limit fails with `TooLarge`, and anything else the
parser refuses, such as a missing boundary or a non-form content type, fails
with `Malformed` or an encoding error. `Multipart.error_status` maps them to
413 and 400:

```bend
case Fail{error}: C.text(Unit, C.status(Unit, c, Multipart.error_status(error)), "rejected upload")
```

## Try it

```sh
bendo build && ./dist/server &
head -c 3000000 /dev/urandom > photo.bin
curl -F note=hello -F file=@photo.bin http://127.0.0.1:8787/uploads
```

```json
[{"field":"file","filename":"photo.bin","type":"application/octet-stream","bytes":3000000,"sha256":"…"}]
```

The digest matches `sha256sum photo.bin`. A 6 MB file gets
`413 Content Too Large` before its body is read, and a form with nine parts
gets 413 from the parser's part limit.

A browser sends the same request from a form or from `FormData`:

```ts
const form = new FormData();
form.append("file", new File(["hello"], "hello.txt", { type: "text/plain" }));
const response = await fetch("/uploads", { method: "POST", body: form });
console.log(response.status);
```

Do not set `Content-Type` yourself: the browser adds it with the boundary.

## Memory

Plan for about 16 bytes of native memory for each byte of a buffered body,
plus the parser's copies (decision [0002](../decisions/0002-bytes.md) has the
measurement). A 5 MiB upload needs more than 80 MB while it is parsed, so
size the limits for how many uploads may run at once. For files much larger
than a few megabytes, have the browser upload straight to object storage with
a signed URL that your Bendo app issues.

## The complete app

::: details main.bend
```bend
import Base
import ./bendo/main.bend as B
import ./bendo/app/config.bend as Config
import ./bendo/app/context.bend as C
import ./bendo/crypto/sha256.bend as SHA256
import ./bendo/data/form.bend as Form
import ./bendo/data/hex.bend as Hex
import ./bendo/data/json.bend as Json
import ./bendo/data/multipart.bend as Multipart

type Tag is Data:
  Upload{}
  Echo{}
  Builtin{id: B.Builtin}

# Files up to 4 MiB, a whole form up to 5 MiB, at most 8 parts.
def upload_limits() -> Multipart.Limits:
  Multipart.Limits{4194304, 5242880, 8, 8192}

def file_json(name: String, filename: String, content_type: String, +bytes: List<&2, U32>) -> Json.Json:
  Json.JObject{[
    Json.Field{"field", Json.JString{name}},
    Json.Field{"filename", Json.JString{filename}},
    Json.Field{"type", Json.JString{content_type}},
    Json.Field{"bytes", Json.JNumber{Nat.show(List.length(&2, U32, bytes))}},
    Json.Field{"sha256", Json.JString{Hex.encode(SHA256.hash(bytes))}}]}

def files(parts: List<&2, Multipart.Part>) -> List<&2, Json.Json>:
  match parts:
    case Nil{}: []
    case Multipart.File{name, filename, content_type, bytes} <> rest: file_json(name, filename, content_type, bytes) <> files(rest)
    case _ <> rest: files(rest)

def uploaded(+c: B.Context(Unit), form: Result<&2, &2, Multipart.Error, List<&2, Multipart.Part>>) -> B.Res:
  match form:
    case Fail{error}: C.text(Unit, C.status(Unit, c, Multipart.error_status(error)), "rejected upload")
    case Done{parts}: C.json(Unit, C.status(Unit, c, 201), Json.JArray{files(parts)})

def content_type(header: Maybe<&2, String>) -> String:
  match header:
    case Some{value}: value
    case None{}: ""

def upload(+c: B.Context(Unit)) -> B.Res:
  uploaded(c, Form.parse_body_with_limits(content_type(C.request_header(Unit, c, "content-type")), C.raw_body(Unit, c), upload_limits()))

def handle(tag: Tag, +c: B.Context(Unit)) -> B.Res:
  match tag:
    case Upload{}: upload(c)
    case Echo{}: C.body(Unit, c, C.raw_body(Unit, c), Some{"application/octet-stream"})
    case _: C.not_found(Unit, c)

def handler(tag: Tag, c: B.Context(Unit), env: Unit) -> IO(B.Res):
  IO.pure(B.Res, handle(tag, c))

def middleware(tag: Tag, c: B.Context(Unit), env: Unit, next: B.Context(Unit) -> IO(B.Res)) -> IO(B.Res):
  match tag:
    case Builtin{id}: B.builtin(Unit, id, c, next)
    case _: next(c)

# Tells the server which body limit each tag carries, so it can refuse an
# oversized request before reading its body.
def limit(tag: Tag) -> Maybe<&2, U32>:
  match tag:
    case Builtin{id}: B.builtin_body_limit(id)
    case _: None{}

def with_body_limit(config: Config.Config, bytes: U32) -> Config.Config:
  Config.Config{host, port, limit, headers, idle, head, body, write, max, keep, router, mode, workers} = config
  Config.Config{host, port, bytes, headers, idle, head, body, write, max, keep, router, mode, workers}

# Raise the server-wide ceiling from 1 MiB to the largest route's limit.
def config() -> Config.Config:
  with_body_limit(B.config(), 5242880)

def routes() -> List<&2, B.Registration(Tag)>:
  [B.use_path(Tag, "/uploads", Builtin{B.body_limit(5242880)}),
   B.use_path(Tag, "/api/*", Builtin{B.body_limit(65536)}),
   B.post(Tag, "/uploads", Upload{}),
   B.post(Tag, "/api/echo", Echo{})]

def ready(result: Result<&2, &2, B.RouteError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "invalid routes")
    case Done{table}: B.serve_limits_with(~Unit, ~Tag, ~limit, ~Unit, ~handler, ~middleware, table, Unit{}, config())

def main() -> IO(Unit):
  ready(B.routes(Tag, routes()))
```
:::

## Read on

- [Multipart forms](../data/multipart.md) is the parser's reference: framing,
  limits and every error.
- [Request limits and caching](../limits-cache.md) covers `body_limit`,
  timeouts and `serve_limits_with`.
- [Query strings and forms](../data/urlencoded.md) covers URL-encoded forms.
