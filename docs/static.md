# Static files

`B.serve_static(c, options)` answers a request with a file from a directory.
Register it on a GET wildcard route; HEAD follows GET. The complete compiled
example is [`tests/servers/static.bend`](../tests/servers/static.bend).

```python
type Tag is Data:
  Assets{}
  App{}

def assets() -> B.StaticOptions:
  B.static_cache_control(B.static_mounted(B.static_options("public"), "/assets"), "public, max-age=31536000, immutable")

def dispatch(tag: Tag, c: B.Ctx, env: Unit) -> IO(B.Res):
  match tag:
    case Assets{}: B.serve_static(c, assets())
    case App{}: B.serve_static(c, B.static_options("dist"))

# B.get(Tag, "/assets/*", Assets{}), then B.get(Tag, "*", App{}) last.
```

| Option | Default | Meaning |
| --- | --- | --- |
| `static_options(root)` | | Directory to serve, absolute or relative to the working directory. The root itself may be a symlink. |
| `static_mounted(o, prefix)` | `""` | Route prefix removed from the request path. A path outside the prefix gets 404. |
| `static_index(o, name)` | `"index.html"` | File served for a path ending in `/`. `""` turns that off. |
| `static_max_bytes(o, n)` | 8 MiB | Largest body read into memory for one response. |
| `static_cache_control(o, v)` | none | `Cache-Control` value for served files and 304s. |

The handler reads the raw, still-encoded request path, not the decoded
wildcard capture, so it can see encoded separators. Methods other than GET and
HEAD get 405 with `Allow: GET, HEAD`.

## Paths

`src/static/path.bend` resolves the path after the prefix. It is pure. The
path must start with `/`. Each `/`-separated segment is percent-decoded once
and must be valid UTF-8, so a bad escape or an overlong sequence such as
`%C0%AE` is refused. A decoded segment must be nonempty, must not start with
`.` (which refuses `.`, `..` and dotfiles such as `.env`), and must not contain
a control character, NUL, DEL, `/`, `\` or `%`. Refusing `%` after one decoding
refuses double encoding such as `%252e`. A trailing `/` adds the index name as
the last segment. Any refusal is a 404; the HTTP parser already answers 400 to
targets with characters like a raw backslash.

Two laws in `LAWS.bend`, proven in `proof/static-path.bend`, cover every
request path and index name:

- `static_path_confined`: a resolution is refused, or every segment of the
  relative path, split on `/` by Base's `String.split`, is nonempty, not `.`,
  not `..`, and free of control characters, DEL, `\` and `%`. It also has
  exactly one segment per `/` in the raw path, so decoding added no separator.
  The spec is `proof/static-spec.bend` and shares no code with the resolver.
- `static_path_target`: the path handed to the open effect is
  `root ++ "/" ++ rel` for that resolution, and nothing is opened for a
  refused one.

The resolver ends with an output check (`Path.guard`) that the proof relies on,
so the laws hold whatever the percent decoder does.

## Opening

Normalizing the text is not enough: a symlink inside the root can point
anywhere. `src/effects/static_file.c` opens the root as a directory, then
walks each segment with `openat(dir, name, O_NOFOLLOW)`, intermediate
segments with `O_DIRECTORY`. Any symlink below the root fails, including one
whose target is inside the root. The last segment is inspected with
`fstatat(AT_SYMLINK_NOFOLLOW)` before opening, so FIFOs and devices are never
opened, and after opening `fstat` must report the same regular file. A
directory without its trailing slash gets a 301 to the slash form, keeping the
query, so relative URLs in its index resolve. A directory with the slash and no
index file gets 404. There is no directory listing. Per-component `openat` was
chosen over Linux's `openat2(RESOLVE_BENEATH)` because it also works on macOS
and refuses every symlink.

The JavaScript twin, `static_file.js`, has no `openat`. It checks each segment
with `lstat`, opens the file with `O_NOFOLLOW`, and requires the opened file to
match the inspected one. A directory swapped for a symlink between those steps
could still redirect the walk. Serve writable, untrusted trees from the native
build. Tests run both twins over the same cases.

## Caching

`ETag` is weak: `W/"<size>-<mtime seconds>"`. Two versions with the same size
written within one second would share it, so it cannot be strong.
`src/http/etag.bend` holds the tag and its weak and strong comparisons for
reuse by cache middleware. `Last-Modified` is the modification time as an
IMF-fixdate.

`If-None-Match` decides when present: `*` or any listed tag that matches by
weak comparison gives 304. Without it, `If-Modified-Since` gives 304 when the
file is not newer than the date. A date that is not an IMF-fixdate is
ignored. A 304 carries `ETag`, `Last-Modified`, `Accept-Ranges`,
`X-Content-Type-Options` and `Cache-Control`, and no body.

## Ranges

`src/static/range.bend` reads `Range` for one byte range: `bytes=a-b`,
`bytes=a-` or `bytes=-n`. The unit is case-insensitive. A satisfiable range
gives 206 with `Content-Range: bytes a-b/length`; an end past the file is
clamped. A start at or past the length, `bytes=-0`, or any range of an empty
file gives 416 with `Content-Range: bytes */length`. A list of ranges, a
reversed range, another unit or malformed syntax is ignored and the whole file
is sent with 200, as RFC 9110 permits. Multipart responses are not produced.

`If-Range` keeps the range only for a strong tag that matches or the exact
`Last-Modified` date. The tags here are weak, so in practice only the date
form keeps a range; anything else sends the whole file.

## Content types and limits

The extension of the file name, lowercased, picks the type from
`src/static/mime.bend`. Text types (HTML, CSS, JavaScript, JSON, source maps,
SVG, XML, plain text, Markdown, CSV, web manifests) get `charset=utf-8`.
Anything else is `application/octet-stream`. Every file response carries
`X-Content-Type-Options: nosniff`.

Streaming responses arrive with BND-48. Until then the body is read into
memory in 64 KiB chunks, and a body larger than `max_bytes` gets 500 instead.
A range within the cap is still served, so large media can be fetched in parts.
Bodies cost about 16 bytes of memory per octet ([0002](decisions/0002-bytes.md)),
so the 8 MiB default needs about 128 MiB per response. Files of 4 GiB or more
are refused, because Base reads files at 32-bit offsets. HEAD reads the file as
GET does, since the response writer derives `Content-Length` from the body. If a file shrinks
while it is read, the response is 500.

## Verification

`tests/static.test.ts` serves a temporary tree and a committed Vite build
(`tests/fixtures/static/vite-app`, rebuilt with `bun install && bun run build`
in that directory). It covers headers, HEAD, MIME types, index files and
redirects, conditional requests, ranges, traversal attempts over raw sockets,
symlinks, a FIFO, the size cap, and both effect twins.
