# Route by HTTP method

Use `src/router/methods.bend` to register paths for specific HTTP methods.
The table stores app-owned tags. A closed application dispatcher handles the
returned tag, params, and original registration index, as described in
[decision 0001](decisions/0001-route-table.md).

```python
import Base
import ../src/router/methods.bend as M
import ../src/router/spec.bend as S
import ../src/http/request.bend as R

type Tag is Data:
  Read{}
  Create{}

def routes() -> Result<&2, &2, S.BuildError, M.Table(Tag)>:
  M.build_table(Tag, [
    M.get(Tag, "/items/:id", Read{}),
    M.on(Tag, [R.Post{}, R.Put{}], "/items/:id", Create{})
  ])
```

The complete native consumer is [the method test server](../tests/servers/router-methods.bend).
`build_table` compiles each pattern through the [spec router](router-spec.md).
It fails atomically at the first invalid pattern, preserving its registration
index and source in `Spec.BuildError`.

## Registration and resolution

`get`, `post`, `put`, `patch`, `delete`, `options`, and `head` each take
`(T, path, tag)`. `on(T, methods, path, tag)` accepts a list of `Request.Method`.
Use canonical constructors for standard methods and `Extension{token}` for
case-sensitive extension methods such as `PROPFIND`. Methods supplied by an app
must satisfy `Request.method_valid`; the HTTP parser already enforces this for
requests. Duplicate methods in a registration are harmless. An empty `on` list
registers a path that accepts no method.

`all(T, path, tag)` registers these nine standard methods, in this order:
`GET, HEAD, POST, PUT, DELETE, CONNECT, OPTIONS, TRACE, PATCH`. It does not accept
extension methods. The current request parser rejects CONNECT targets, so a
pure router call can select CONNECT even though the current HTTP server cannot
serve it. CONNECT framing remains the response writer's responsibility.

Call `resolve(T, table, path, request_method, opts)` with a raw path excluding
its query and fragment. It returns one of:

- `Found{hit, head_from_get}`: `hit` is `Spec.Match{index, tag, params}`. The
  first registration matching both path and method wins. An earlier path match
  for another method does not shadow it.
- `NotFound{}`: no registration's pattern matches the path, regardless of its
  method list.
- `MethodNotAllowed{allow}`: at least one pattern matches, but the method is
  unavailable, including HEAD fallback. `allow` is the deduplicated union of
  methods from every matching registration, with HEAD added whenever GET is
  present. Standards use the order above; extensions follow in case-sensitive
  lexical order. `allow_text(allow)` joins them with `", "` for an `Allow`
  header. Empty `on` registrations can produce an empty `Allow` value.

For HEAD, the resolver first searches the entire table for a direct HEAD match.
This includes `head`, `on` containing HEAD, and `all`. If none matches, it selects
the first GET match and sets `head_from_get=True`. Direct matches set it to
`False`, including direct HEAD. OPTIONS has no automatic response. Register an
OPTIONS route explicitly; CORS middleware owns preflight behavior.

Build the GET response when HEAD falls back to GET, then serialize it with
`WriteResponse.write(Request.Head{}, response)`. Keep the original request
method through serialization. The existing writer preserves GET's head,
including Content-Length, and suppresses all body octets. The test server
shows the same serialization path for explicit HEAD, 404, and 405 responses.
The router itself returns data and does not construct HTTP responses.

## Slash and case options

`defaults()` returns `Options{strict_trailing_slash=True, case_sensitive=True}`.
Both fields are independent. They apply to successful matches, path-existence
checks, and the collection of allowed methods.

With strict trailing slashes, `/a` differs from `/a/`. Lenient mode removes all
terminal empty slash-separated segments from both the compiled pattern and the
request path, retaining one empty segment for root. Thus `/a`, `/a/`, and
`/a///` agree; `/`, `//`, and `////` agree. Interior repeated slashes remain
distinct. This also trims trailing slashes from a wildcard's captured remainder
in lenient mode; strict mode preserves the original pattern semantics.

Case-insensitive mode folds ASCII letters only in static segments. Capture
names, decoded values, wildcard remainders, and constraints keep their original
case. For `/Mixed/:Value`, `/mixed/AbC` captures `Value="AbC"`. A lowercase-only
constraint still rejects `ABC`. Non-ASCII text is unchanged. Static segments
remain raw rather than percent-decoded, following the
[pattern grammar](router-patterns.md).

## Verification

`bun test tests/router-methods.test.ts` compiles a native Bend server and checks
method dispatch, exact Allow values, raw HEAD bytes, 404/405, extension methods,
and all four option combinations. `bun run prove` checks the BND-18 laws;
`bun run check` runs the full repository gate.
