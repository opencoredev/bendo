# Request limits and response caching

Bendo provides `body_limit(bytes)`, `timeout(milliseconds)`, `etag()` and
`cache_control(policy)` built-ins. Wrap them in your app's tag and dispatch
through `B.builtin`, as in [middleware](middleware.md). The compiled consumer
in [mw-limits.bend](../tests/servers/mw-limits.bend) shows the complete setup.

## Limit request bodies before buffering

The server defaults to a 1 MiB decoded body limit. `Config.body_limit` is the
transport ceiling. Route, group and guard limits can tighten it; every selected
limit must pass. To allow a larger route, raise the server ceiling and put lower
limits on the other routes. Limits count octets, including binary bodies.

Ordinary middleware runs after buffering. For early rejection, use
`B.serve_limits_with` with a pure selector that extracts limits from your tags:

```python
def limit(tag: Tag) -> Maybe<&2, U32>:
  match tag:
    case Builtin{id}: B.builtin_body_limit(id)
    case _: None{}
```

Replace `B.serve_with(~Vars, ~Tag, ~Env, ~handler, ~middleware, table, env, config)`
with `B.serve_limits_with(~Vars, ~Tag, ~limit, ~Env, ~handler, ~middleware,
table, env, config)`. No handler or continuation goes in the route table.
The selector must return the same limits your middleware enforces.

Register `Builtin{B.body_limit(4096)}` through `use`, `use_path`, or a scoped
request/parse/transform/before-handle hook. `B.route_hooks`, `B.group` and
`B.guard` retain their structural route membership. Response-stage hooks do
not control request admission.

Admission resolves the original method and path before request hooks execute.
It takes the minimum of the server ceiling and every limit in that request's
request/pre-handler plan. It uses the existing framing reader: oversized
Content-Length is refused before reading the body, and each chunk size is
checked against the remaining budget before its data is accepted. The receive
buffer may already contain later wire bytes, but those bytes never enter the
decoded body accumulator. Rejection uses the existing bounded discard/close.

Request hooks may rewrite the method or path. Original-route admission still
applies, and middleware also checks the buffered body against the routed
limits. A rewrite from a small route cannot raise its admission budget. A
rewrite to a smaller route receives 413 from middleware. With network-free
`B.handle_with`, only the buffered middleware check applies. Request-stage
short circuits retain the provisional scopes, as in the lifecycle contract.
Route-limit 413 responses negotiate text or JSON through `C.error`; parser and
server-ceiling rejections keep the transport error policy.

## Answer slow requests with 504

Put `Builtin{B.timeout(1000)}` around the work to bound, through ordinary
middleware or a pre-handler hook. It races `next` against `IO.within` and renders
504 through `C.error`, including Accept negotiation. Response hooks, validation,
request-ID/Server-Timing finalization and deferred observers still run normally.
The budget covers the inner chain, not body reading, later response hooks or
socket writes. The transport's read deadlines remain separate.

This timeout is cooperative. `IO.within` does not cancel its losing computation.
A timed-out handler can still update stores, write files or perform other side
effects. Its late response is discarded. A deadline cannot interrupt
uninterrupted pure computation: the event loop advances only at the next
effect. The client can therefore receive 504 after pure work has already
exceeded the budget. Cancellation and a hard wall-clock response deadline are
never promised. Keep pure handlers and store updates bounded.

## ETag and conditional GET or HEAD

`Builtin{B.etag()}` hashes the final buffered body with pure SHA-256, encodes the
digest as unpadded base64url and quotes it as a strong entity-tag. It replaces
an existing validator. Only status 200 GET/HEAD responses qualify. HEAD hashes
the same full representation as GET, before the writer removes its payload.
Other methods and statuses pass through unchanged.

Prefer `map_response` after all body transformations, including pretty JSON.
With ordinary onion middleware, put ETag outside body-transforming middleware.
Later changes to the body would invalidate the validator. Do not install ETag
before a later error recovery that replaces a 200 body without removing its
validator. Current `Res` values are buffered; streaming has no representation in
this API yet. A future streaming variant must bypass hashing rather than
buffering the stream to compute a validator.

`If-None-Match` uses weak comparison under RFC 9110 section 13.1.2: `W/` is
case-sensitive and ignored for comparison; opaque tag contents are compared
case-sensitively. `*` matches an existing valid validator, lists can contain
empty elements, and commas inside tags remain data. Backslash is literal,
not a quoted-string escape. Repeated fields are comma-joined in arrival order.
Malformed fields or validators do not match, including a list containing an
otherwise matching tag plus an invalid member.

A match returns 304 with no body or representation witness. Construction keeps
exactly ETag, Cache-Control, Vary, Date, Content-Location and Expires in their
original order, including duplicates. It drops content and framing headers and
other application fields. Framework observability finalization can then add
request ID and timing; the Date boundary supplies Date when absent. The writer
emits no Content-Length for this 304, including HEAD.

### Reuse from static files

`src/http/conditional.bend` is pure and independent of middleware/context:

- `strong(body) -> String`: the quoted SHA-256 validator.
- `matches(Maybe<String>, tag) -> Bool`: field grammar and weak comparison.
- `headers(headers)`: cache metadata allowlist.
- `not_modified(res)`: bodyless 304 construction.

Static-file handlers can use `matches` with their own valid strong or weak tag
and apply `not_modified` after adding their cache metadata. They remain
responsible for method/status eligibility, Last-Modified precedence, ranges,
and selecting the current representation. This evaluator covers If-None-Match,
not If-Match or If-Modified-Since.

## Set Cache-Control

`B.cache_control(policy)` sets one Cache-Control field after its inner chain.
Policies are typed, so callers cannot accidentally insert arbitrary header text:

- `B.cache_no_store()`: `no-store`.
- `B.cache_no_cache()`: `no-cache` (storage is allowed; reuse requires validation).
- `B.cache_public(seconds, immutable)`: `public, max-age=<seconds>`, with
  `, immutable` when true.
- `B.cache_private(seconds)`: `private, max-age=<seconds>`.

These helpers describe caching policy; they do not store responses. Configure
one through `map_response` after ETag if the same policy should cover both 200
and 304 responses. Avoid public caching for personalized content.

Run `bun test --timeout 30000 tests/mw-limits.test.ts`. It exercises native HTTP,
raw streamed framing, late store mutation, relative pure-work timings and the
pure parser's grammar cases. `conditional_if_none_match_spec`,
`conditional_304_spec` and `body_limit_spec` in `LAWS.bend` quantify over all
fields/tags, responses and natural lengths respectively. The reference evaluator
in `proof/limits-spec.bend` builds tags and list elements from their suffixes,
while the implementation scans forward into accumulators. It then checks list
grammar and existence of a weak match in separate traversals; the implementation
combines them. The proof shares the
RFC octet class and OWS primitive, not the conditional decision.
