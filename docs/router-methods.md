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

def routes() -> Result<&2, &2, M.BuildError, M.Valid<Tag>>:
  M.build_table(Tag, [
    M.get(Tag, "/items/:id", Read{}),
    M.on(Tag, [R.Post{}, R.Put{}], "/items/:id", Create{})
  ])
```

The complete native consumer is [the method test server](../tests/servers/router-methods.bend).
`build_table` compiles each pattern through the [spec router](router-spec.md).
It fails atomically at the first invalid registration, preserving its index and
source. `Methods.InvalidPattern{index, source, error}` wraps a pattern error;
`Methods.InvalidMethod{index, source, token}` identifies an invalid method token.
Methods are checked before the pattern within each registration.

A successful build returns `Valid<T>`, a copyable table with a proof field:

```python
type Valid<-T: Data> is Data:
  Valid{table: Table(T), ok: {TableValid(T, table) == True{} : Bool}}
```

`TableValid` checks that every method in every registration is valid and uses
its canonical constructor. `resolve` accepts `Valid<T>`. A raw `Table(T)` cannot
be passed to it. Bend exports constructors, so callers may construct `Valid`
directly, but must supply the proof for that exact table. `{==}` cannot prove
validity for `Extension{"BAD TOKEN"}`. `raw(T, valid)` exposes the underlying
list for inspection; modifying that list requires a new proof before resolving.
The low-level `build_methods` helper requires proof that the methods are valid
when its supplied validation result is `None{}`; a forged `None{}` cannot bypass
it.

## Registration and resolution

`get`, `post`, `put`, `patch`, `delete`, `options`, and `head` each take
`(T, path, tag)`. `on(T, methods, path, tag)` accepts a list of `Request.Method`.
Use standard constructors or `Extension{token}`. Construction normalizes exact
standard tokens: `Extension{"GET"}` behaves exactly like `Get{}`, including HEAD
fallback and Allow ordering. Empty tokens and tokens containing spaces, control
characters, non-ASCII characters, or HTTP separators are build errors.
Methods are case-sensitive under RFC 9110: `Extension{"get"}` remains distinct
from GET and does not supply HEAD fallback. Duplicate methods in a registration
are harmless. An empty `on` list
registers a path that accepts no method.

`all(T, path, tag)` registers these nine standard methods, in this order:
`GET, HEAD, POST, PUT, DELETE, CONNECT, OPTIONS, TRACE, PATCH`. It does not accept
extension methods. The current request parser rejects CONNECT targets, so a
pure router call can select CONNECT even though the current HTTP server cannot
serve it. CONNECT framing remains the response writer's responsibility.

Call `resolve(T, table, path, request_method, opts)` with the `Valid<T>` returned
by `build_table` and a raw path excluding its query and fragment. It returns
one of:

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

## Router selection

`resolve` is the reference resolver. Applications resolve through the
configured router instead:

```python
+index = M.prepare(Tag, valid)
M.resolve_with(Tag, Router.Trie{}, index, path, method, M.defaults())
```

`prepare(T, valid)` returns `Index<T>`, which holds the validated table and its
[trie](router-trie.md), built once. `index_valid(T, index)` returns the
`Valid<T>`. `resolve_with(T, kind, index, path, method, opts)` takes a
`Router.RouterKind`. With `Spec{}` it calls `resolve`. With `Trie{}` it takes the
trie's ordered candidates for the path, keeps those whose pattern matches, and
reads the direct match, HEAD fallback, 404 decision and `Allow` set from that
one list. The trie keys raw static segments, so it prefilters only under the
default strict, case-sensitive options. The other three option combinations
scan every registration, as `resolve` does.

The law `methods_router_resolve` proves `resolve_with(T, kind, prepare(T,
valid), path, method, opts) == resolve(T, valid, path, method, opts)` for every
kind, valid table, path, method and option combination. Every BND-18 law above
therefore also holds for the trie path. `B.routes` builds the index, `B.handle`
uses `Router.default_kind()` (`Trie`), and `B.serve` uses the configured
`router` field.

## Verification

`bun test tests/router-methods.test.ts` compiles a native Bend server and checks
method dispatch, exact Allow values, raw HEAD bytes, 404/405, extension methods,
and all four option combinations through `resolve_with` with the default
trie. `bun run prove` checks the BND-18 laws and `methods_router_resolve`;
`methods_build_valid` proves that successful builds carry valid method-token
evidence. All table-based BND-18 laws quantify over `Valid<T>`;
`methods_allow_exact` obtains table validity from the value and has no separate
table-validity hypothesis. Compile-failure fixtures check raw-table resolution,
the old forged-`None{}` helper call, a forged validation proof, and a forged
`Valid` proof. A native consumer also constructs a valid table directly.
`bun run check` runs the full repository gate.
