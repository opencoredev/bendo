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
| `static_buffer_bytes(o, n)` | 1 MiB | Largest body read into memory and sent with `Content-Length`. Longer bodies stream. |
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
refuses double encoding such as `%252e`. A segment of printable ASCII without
space, `%`, `/` or `\` contains no escape and skips the decoder. A trailing `/`
adds the index name as the last segment. Any refusal is a 404; the HTTP parser
already answers 400 to targets with characters like a raw backslash.

Six laws in `LAWS.bend`, proven in `proof/static-path.bend`, cover every
request path and index name. The spec is `proof/static-spec.bend`; it shares
no code with the resolver and uses the router's percent decoder only to say
what one segment decodes to.

- `static_path_confined`: a resolution is refused, or every segment of the
  relative path, split on `/` by Base's `String.split`, is nonempty, not `.`,
  not `..`, and free of control characters, DEL, `\` and `%`, with one segment
  per `/` in the raw path.
- `static_path_segments`: each segment of a resolution is the decoding of
  exactly one raw segment, in order, with an empty final segment replaced by
  the index. No segment contains `/`, so decoding added no separator. (A count
  alone would allow `/a%2Fb/c` to resolve to `a/b`.)
- `static_path_no_dotfiles`: no segment of a resolution starts with `.`.
- `static_path_complete`: servable segments (nonempty printable ASCII without
  space, `%`, `/` or `\`, not starting with `.`) written as `/a/b` resolve to
  `a/b`. Together with the next law, this rules out a resolver that refuses
  everything.
- `static_path_index`: servable segments written as `/a/b/` (or `/`) resolve to
  `a/b/<index>` when the index is a servable segment.
- `static_path_target`: the path handed to the open effect is
  `root ++ "/" ++ rel` for that resolution, and nothing is opened for a
  refused one.

The resolver ends with an output check (`Path.guard`) that the confinement and
dotfile proofs rely on, so they hold whatever the percent decoder does.

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

`ETag` is strong and built from the file's metadata, not its bytes: device,
inode, size, and modification and status-change times with nanoseconds, in hex
(`"803-1a2b-b-6718f00c.1f3a…-6718f00c.1f3a…"`). The status-change time (ctime)
moves to the current time on every write, rename onto the path or `utimes`,
and no system call can set it back. So once a file has settled, any later
change to its content changes the tag, even a same-size rewrite that restores
the old mtime. The one exception is a wall clock stepped backwards onto the
exact nanosecond of an earlier ctime.

A file settles when its mtime and ctime are both at least two seconds old,
which covers filesystems with two-second timestamps. Until then it gets no
`ETag` and no `Last-Modified`, and conditional fields are ignored, so a change
within the same second cannot produce a stale 304. Hashing the content would
also be exact, but it reads the whole file on every request, which defeats
streaming large files; the metadata tag costs one `fstat`.

`src/http/etag.bend` holds the tag and its weak and strong comparisons.
`Etag.none_match` is the only place static files compare `If-None-Match`. When
BND-41's `Conditional.matches` reaches main it becomes the canonical
comparison, and `none_match` should call it.

`If-None-Match` decides when present: `*` or any listed tag that matches by
weak comparison gives 304. Without it, `If-Modified-Since` gives 304 when
neither the mtime nor the ctime is later than the date. Counting ctime means a
copy that restored an old mtime (`cp -p`, `rsync -t`) is never reported
unmodified; such files still revalidate through `ETag`. A date that is not an
IMF-fixdate is ignored. A 304 carries `ETag`, `Last-Modified`,
`Accept-Ranges`, `X-Content-Type-Options` and `Cache-Control`, and no body.

## Ranges

`src/static/range.bend` reads `Range` for one byte range: `bytes=a-b`,
`bytes=a-` or `bytes=-n`. The unit is case-insensitive. A satisfiable range
gives 206 with `Content-Range: bytes a-b/length`; an end past the file is
clamped. A start at or past the length, `bytes=-0`, or any range of an empty
file gives 416 with `Content-Range: bytes */length`. A list of ranges, a
reversed range, another unit or malformed syntax is ignored and the whole file
is sent with 200, as RFC 9110 permits. Multipart responses are not produced.

`If-Range` keeps the range only for the current tag (by strong comparison, so
`W/` never matches) or the exact `Last-Modified` date of a file whose ctime is
no later than that date. Anything else, including any `If-Range` on a file
that has not settled, sends the whole file.

## Content types and limits

The extension of the file name, lowercased, picks the type from
`src/static/mime.bend`. Text types (HTML, CSS, JavaScript, JSON, source maps,
SVG, XML, plain text, Markdown, CSV, web manifests) get `charset=utf-8`.
Anything else is `application/octet-stream`. Every file response carries
`X-Content-Type-Options: nosniff`.

A body (the whole file, or the selected range) up to `buffer_bytes` is read
into memory in 64 KiB chunks and sent with `Content-Length`. A longer body
streams through `B.stream` ([streaming](streaming.md)) with chunked encoding
and no `Content-Length`: the producer reads the next 64 KiB only after the
previous chunk was sent, and its cleanup closes the file whether the stream
ends, fails, is cancelled or the client disconnects. Octet lists cost about 16
bytes of memory per octet ([0002](decisions/0002-bytes.md)), so a buffered body
needs up to about 16 MiB at the 1 MiB default, and a streamed one about 1 MiB
for its current chunk, whatever the file size.

HEAD over HTTP/1.1 never reads the file. It registers the same stream, which
the transport does not pull for HEAD, and gets every header GET gets except
`Content-Length`, because the response writer derives that from a body.
HTTP/1.0 cannot carry a stream: a body above `buffer_bytes` gets 505 there,
and HEAD over HTTP/1.0 reads a buffered body to send its length. Network-free
`B.handle` cannot carry a stream either, so a streamed file is an empty 500
there.

Files of 4 GiB or more are refused, because Base reads files at 32-bit
offsets. If a file shrinks while it is read, a buffered response is 500 and a
streamed one is aborted.

## Verification

`tests/static.test.ts` serves a temporary tree and a committed Vite build
(`tests/fixtures/static/vite-app`, rebuilt with `bun install && bun run build`
in that directory). It covers headers, HEAD, MIME types, index files and
redirects, validators across same-second rewrites, conditional requests,
ranges, traversal attempts over raw sockets, symlinks, a FIFO, streaming above
`buffer_bytes` (including descriptor counts after aborted downloads), and both
effect twins. The Vite build's `vite.config.js` writes each bundled package's
license to `build/THIRD_PARTY_LICENSES.txt` and names them in a banner at the
top of every chunk.
