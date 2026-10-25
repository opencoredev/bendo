# Compress responses

`src/compress.bend` compresses buffered responses with gzip or deflate, chosen
by the request's `Accept-Encoding`. It is opt-in: import it next to
`src/main.bend` and call it from a middleware case. Apps that never import it
compile without the zlib effect, so their build time and binary do not change.
[compress.bend](../tests/servers/compress.bend) is the compiled test server
with every case on this page.

## Set it up

Give your middleware tag a case that holds a `Z.Config`, register it with
`B.use` or `B.use_path`, and call `Z.compress` from that case of your
middleware dispatcher:

```bend
import Base
import ./bendo/main.bend as B
import ./bendo/compress.bend as Z
import ./bendo/router/methods.bend as Methods

type Tag is Data:
  Home{}
  Zip{config: Z.Config}
  Builtin{id: B.Builtin}

def handler(tag: Tag, c: B.Ctx, env: Unit) -> IO(B.Res):
  IO.pure(B.Res, B.html(c, "<h1>Hello</h1>"))

def middleware(tag: Tag, c: B.Ctx, env: Unit, next: B.Ctx -> IO(B.Res)) -> IO(B.Res):
  match tag:
    case Zip{config}: Z.compress(Unit, config, c, next)
    case Builtin{id}: B.builtin(Unit, id, c, next)
    case _: next(c)

def ready(result: Result<&2, &2, Methods.BuildError, B.Routes(Tag)>) -> IO(Unit):
  match result:
    case Fail{e}: IO.die(Unit, 1, "invalid routes")
    case Done{table}: B.serve_with(~Unit, ~Tag, ~Unit, ~handler, ~middleware, table, Unit{}, B.config())

def main() -> IO(Unit):
  ready(B.routes(Tag, [
    B.use(Tag, Builtin{B.etag()}),
    B.use(Tag, Zip{Z.threshold(Z.defaults(), 512)}),
    B.get(Tag, "/", Home{})
  ]))
```

`Z.compress` works with any typed `Vars`, as `B.builtin` does. Use
`B.use_path` instead of `B.use` to compress only part of the app.

## Which coding is used

The middleware reads every `Accept-Encoding` field as RFC 9110 section 12.5.3
describes:

- Each member's weight is its `q` value from 0 to 1, with up to three
  decimals. A member without `q` weighs 1. A malformed `q` counts as 0.
- A coding named explicitly takes that member's weight. Otherwise `*` gives
  its weight. A coding that neither names nor `*` covers is not acceptable.
  `x-gzip` counts as `gzip`. Names are compared without ASCII case.
- `q=0` refuses a coding. Bendo never sends a refused coding.
- Gzip wins over deflate unless deflate weighs strictly more, so a tie goes to
  gzip.
- A coding weighed below `identity` (named, or covered by `*`) is not used:
  `gzip;q=0.5, identity` gets an uncompressed body.
- A request without `Accept-Encoding` gets an uncompressed body. RFC 9110 lets
  a server choose any coding then, but clients that send no field rarely
  expect one.

When nothing is acceptable, the body goes out as it is. Bendo never answers
406.

`deflate` means the zlib format (RFC 1950), which is what RFC 9110 section
8.4.1.2 defines, not raw deflate.

## What is not compressed

The middleware leaves a response exactly as it is, with no `Vary` added, when
the decision does not depend on `Accept-Encoding`:

- The response already has `Content-Encoding`, so nothing is encoded twice.
- The body is streamed: `B.stream`, Server-Sent Events and the proxy produce
  their bodies after the middleware returns, so they are never compressed.
- The status is 1xx, 204, 205 or 206. A 206 also carries `Content-Range`, and
  any response with `Content-Range` is skipped: ranges count identity octets.
- `Cache-Control` has `no-transform`.
- The media type is already compressed or unknown: any `image/*` other than
  `image/svg+xml`, `video/*`, `audio/*`, zip, gzip, bzip2, xz, zstd, brotli,
  7z and rar archives, WOFF and WOFF2 fonts, `application/octet-stream`,
  `text/event-stream` and `multipart/byteranges`. A response without
  `Content-Type` is skipped too.
- The body is shorter than the threshold (1024 octets by default) or longer
  than the limit (8 MiB by default).

## What changes on a compressed response

- The body is the coded octets, and `Content-Encoding` names the coding. The
  server writes `Content-Length` from the new body.
- `Vary` gains `Accept-Encoding`, merged into any `Vary` already there.
- A strong `ETag` such as `"v1"` becomes `W/"v1"`, because the coded bytes are
  not the bytes the tag was computed from. A weak tag stays as it is.
- `Accept-Ranges` is removed.

When the response could have been compressed but is not, because the client
did not accept a coding or because compression would not make the body
smaller, it goes out as it is with `Accept-Encoding` added to `Vary`.

A HEAD answer is never compressed. It gets the same `Vary` as the GET would,
but its `Content-Length` is the identity length.

A 304 whose response carries its representation witness (static files do)
gets `Vary` and the weakened `ETag` the 200 would have had, and no
`Content-Length`. A 304 without the witness is left as it is.

## Use it with ETags

Register `B.etag()` before compression, so that it runs outside it, as the
program above does with `B.use(Tag, Builtin{B.etag()})` ahead of the `Zip`
entry.

The ETag is then computed over the coded body, so each coding gets its own
strong tag, and a 304 keeps the `Vary` header the compression added. Compression
still runs on requests that end in 304.

## Limits and failures

The limit bounds the memory one compression takes: the body, at most the limit,
plus zlib's worst-case output size. The native build runs zlib on a helper
thread, so other connections keep being served. If compression fails, for
example because zlib cannot be loaded or memory runs out, the response goes out
uncompressed with `Vary`.

## Outside the proofs

`src/effects/zlib.c` loads the system zlib with `dlopen`. `bend` links native
programs with only `-lpthread -lm`, so linking `-lz` is not possible.
`libz.so.1` comes with Ubuntu's `zlib1g` package, which every Ubuntu and
Debian system has installed, and macOS ships `libz.1.dylib`. No extra package
is needed to build or run. Gzip output is assembled from zlib's own stream:
the raw deflate data, a gzip header, CRC-32 and the length.

The JS twin, `src/effects/zlib.js`, uses `node:zlib` (`gzipSync` and
`deflateSync`). Its gzip header differs from the native one, but both decode
to the same bytes, and `tests/mw-compress.test.ts` checks both. It blocks the
JavaScript event loop while it runs.

## Laws

`src/mw/compress_policy.bend` holds the decision, free of IO, and
[the middleware laws](laws/middleware.md#compression) state what it
guarantees: a coding is only used when accepted at a nonzero weight, short,
oversized, already-encoded, streamed, HEAD, 204, 206 and 304 responses are
never compressed, and ties go to gzip.

## API reference

### `Z.Config`

```bend signature
def Config() -> Data
```

The compression settings: threshold, limit and zlib level. It is `Data`, so it
can sit in your middleware tag.

### `Z.defaults`

```bend signature
def defaults() -> Z.Config
```

A 1024-octet threshold, an 8 MiB limit and zlib level 6.

### `Z.threshold`

```bend signature
def threshold(config: Z.Config, n: U32) -> Z.Config
```

Bodies shorter than `n` octets are sent uncompressed. A body of exactly `n`
octets may be compressed.

### `Z.limit`

```bend signature
def limit(config: Z.Config, n: U32) -> Z.Config
```

Bodies longer than `n` octets are sent uncompressed. This bounds the memory one
compression takes.

### `Z.level`

```bend signature
def level(config: Z.Config, n: U32) -> Z.Config
```

The zlib level, clamped to 1 (fastest) through 9 (smallest output).

### `Z.compress`

```bend signature
def compress(-Vars: Data, +config: Z.Config, +c: B.Context(Vars), next: B.Context(Vars) -> IO(B.Res)) -> IO(B.Res)
```

Runs `next`, then compresses its response as this page describes. Call it from
a middleware case.
