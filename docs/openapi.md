# OpenAPI and API docs

`bendo openapi` turns an app's [route manifest](manifest.md) into an OpenAPI 3.1
document. `src/api-docs.bend` serves that document and a
[Scalar](https://github.com/scalar/scalar) API reference page. Neither is part
of `main.bend`, so apps without docs compile nothing extra.
[Decision 0013](decisions/0013-openapi-generation.md) explains the split.

## Quick start

Add two routes and import the docs module:

```python
import ../../src/main.bend as B
import ../../src/serve-schemas.bend as BS
import ../../src/api-docs.bend as Docs
import ./openapi-doc.bend as OpenApiDoc

def spec(c: B.Ctx) -> IO(B.Res):
  IO.pure(B.Res, Docs.openapi(c, OpenApiDoc.json()))

def reference(c: B.Ctx) -> IO(B.Res):
  IO.pure(B.Res, Docs.scalar(c, Docs.options("/openapi.json")))

# In the route list:
#   B.get(Tag, "/openapi.json", Spec{}),
#   B.get(Tag, "/docs", Reference{}),
```

Then generate the document and the module, and rebuild:

```sh
printf 'def json() -> String:\n  "{}"\n' > openapi-doc.bend   # first run only
bendo openapi main.bend --bend openapi-doc.bend
bendo build
```

The manifest does not depend on the document, so one run is enough. Run
`bendo openapi` again after any route or schema change; the embedded document
does not update itself. The complete app is
[`tests/fixtures/openapi/app.bend`](../tests/fixtures/openapi/app.bend).

To skip embedding, serve the generated `openapi.json` from disk with
[`B.serve_static`](static.md) and point `Docs.options` at its URL.

## The command

```text
bendo openapi [entry] [--out <file>] [--bend <file>] [--config <file>] [--manifest <file>]
```

- `entry` defaults to `main.bend`. The app is built with the same cache as
  `bendo build`, then run with `--bendo-routes`.
- `--out` is the JSON output, `openapi.json` by default, indented two spaces.
- `--bend` also writes a Bend module whose `json()` returns the document as
  compact JSON. Non-ASCII characters are written as `\uXXXX` escapes.
- `--config` reads options from a JSON file. Without it, `openapi.config.json`
  in the current directory is used when it exists.
- `--manifest` reads a saved manifest instead of building, for example the
  output of `./server --bendo-routes > routes.json`. It excludes `entry`.

Files are replaced atomically. The command prints one warning per route it
cannot document to stderr and exits 0; config errors exit 1.

## Configuration

Every member is optional.

```json
{
  "info": { "title": "Todo API", "version": "1.2.0", "description": "...", "license": { "name": "MIT", "identifier": "MIT" } },
  "servers": [{ "url": "https://api.example.com", "description": "Production" }],
  "tags": [{ "name": "todos", "description": "Todo items." }],
  "autoTags": true,
  "allMethods": ["get", "post", "put", "patch", "delete"],
  "exclude": ["/openapi.json", "/docs"],
  "operations": {
    "GET /todos/:id{int}": { "summary": "Get a todo", "operationId": "getTodo", "tags": ["todos"], "deprecated": false }
  }
}
```

| Member | Default | Meaning |
| --- | --- | --- |
| `info` | from `package.json` | `title`, `version` and `description` fall back to the current directory's `package.json` `name`, `version` and `description`, then to `Bendo API` and `0.0.0`. `summary`, `termsOfService`, `contact` and `license` pass through. |
| `servers` | none | Without servers, OpenAPI resolves paths against the document's own origin, which suits a document served by the app. |
| `tags` | none | Tag descriptions and their order. Tags that operations use but this list lacks are appended by first use. |
| `autoTags` | `true` | Tag each operation with its path's first static segment: `/todos/:id` gets `todos`. `/` and paths that start with a capture get none. |
| `allMethods` | get, post, put, patch, delete | The operations a `B.all` route documents. Lowercase OpenAPI method names. |
| `exclude` | none | Manifest paths to leave out, compared exactly. |
| `operations` | none | Per-route `summary`, `description`, `operationId`, `tags` and `deprecated`, keyed by the manifest's `METHOD path`. An `ALL` route's key is `ALL /path`. A key that matches no route gives a warning. |

Unknown members and wrongly typed values are errors.

## Mapping

Rows keep manifest order. Paths appear in order of first use.

### Paths

Bendo patterns ([syntax](router-patterns.md)) become OpenAPI templates:

| Pattern | Path | Parameter |
| --- | --- | --- |
| `/todos/:id` | `/todos/{id}` | `id`, a nonempty string |
| `/todos/:id{int}` | `/todos/{id}` | pattern `^-?[0-9]+$` |
| `:u{uuid}`, `:s{slug}`, `:c{[a-z]+}`, `:y{[0-9]{4}}` | `{u}` and so on | `format: uuid` with its pattern; `^[a-z0-9-]+$`; `^[a-z]+$`; `^[0-9]{4}$` |
| `/v1/:version?/:platform?` | `/v1`, `/v1/{version}`, `/v1/{version}/{platform}` | one path per number of present captures |
| `/:prefix{.+}/contents` | `/{prefix}/contents` | described as possibly containing `/` |
| `/files/*path` | `/files/{path}` | the rest of the path, possibly empty |
| `*` or `/*` | `/{wildcard}` | captured as `*` in the route |
| `/a/*/b` | `/a/{wildcard}/b` | not captured by the route |
| `/assets*` | `/assets{suffix}` | not captured by the route |

OpenAPI path parameters are always required, which is why an optional chain
becomes several paths. Wildcards that the route does not capture still get a
parameter, so a client can fill in the path. Generated names (`wildcard`,
`suffix`) take a number when the pattern already uses the name.

A parameter's schema comes from the route's `params` slot when the slot is an
object that declares the name. Otherwise it comes from the constraint, as in
the table. The `params` schema describes the value after
[coercion](data/schema.md#coercion-for-text-sources), so an `id` declared as an
integer is documented as `type: integer`, which is how OpenAPI describes a
numeric path segment.

OpenAPI treats `/todos/{id}` and `/todos/{todo_id}` as the same path. When two
routes give such templates, the first spelling is kept and the later route's
parameters are renamed to match it. Each operation's `x-bendo-route` holds its
original `METHOD path`.

### Methods

`GET`, `PUT`, `POST`, `DELETE`, `OPTIONS`, `HEAD`, `PATCH` and `TRACE` map to
the operation of the same name. `B.on` produces one manifest row per method,
so each becomes its own operation. `B.all` documents the `allMethods` list,
with `x-bendo-all: true` on each. OpenAPI 3.1 has no field for other methods,
such as `PURGE`, `QUERY` or a lowercase extension token, so those routes are
left out with a warning. Implicit HEAD for GET routes is not documented.

When a method on a path is already documented, a later route that gives the
same method and path is left out with a warning. The router tries routes in
registration order, so the earlier route answers at least those requests. A
later route can still serve requests the earlier one rejects, for example
`/users/:id{int}` before `/users/:name`; OpenAPI cannot describe both.

### Slots

| Slot | OpenAPI |
| --- | --- |
| `params` | path parameter schemas, as above |
| `query` | one `in: query` parameter per property, `required` from the schema's `required` list |
| `headers` | one `in: header` parameter per property; `Accept`, `Content-Type` and `Authorization` are left out with a warning, because OpenAPI ignores them |
| `body` | `requestBody`, required, `application/json` |
| `response` | a `200` response with `application/json`; without it, a `default` response with no content |

A `query` or `headers` schema that is not an object with `properties` gives no
parameters and a warning. Each embedded schema is the slot's JSON Schema
without its `$schema` member, because OpenAPI 3.1's default dialect already
is 2020-12. The [decoder policy](data/json-schema.md#decoder-policy-and-validator-differences)
still applies: defaults are annotations, strip objects accept undeclared keys,
and `anyOf` unions decode to their first match. JSON numbers pass through
JavaScript, so a bound such as `1E+2` is written `100` and digits beyond a
double's precision are lost.

`operationId` defaults to the method and path words in camel case:
`getTodosById`, `getRoot` for `/`. A number is appended on a clash. An
`operations` override applies only when the route documents exactly one
operation.

## The docs page

`src/api-docs.bend` takes any `Context.Ctx<Vars>` through the `_with` forms.

| Function | Result |
| --- | --- |
| `Docs.openapi(c, text)` | `text` with `application/json; charset=utf-8` |
| `Docs.scalar(c, o)` | the HTML page, `text/html; charset=utf-8`, with `o`'s Content-Security-Policy |
| `Docs.options(spec_url)` | the CDN script, its SRI hash, the CDN policy and the title `API Reference` |
| `Docs.with_title(o, t)` | the page title, HTML-escaped |
| `Docs.self_hosted(o, url, integrity)` | load Scalar from `url`; see below |
| `Docs.with_csp(o, policy)` | replace the page's policy; `""` sends none |
| `Docs.page(o)`, `Docs.policy(o)` | the HTML and the policy as strings |

The page loads Scalar API Reference 1.75.1 from jsDelivr, pinned to the
exact file with an SRI hash:

```text
https://cdn.jsdelivr.net/npm/@scalar/api-reference@1.75.1/dist/browser/standalone.js
sha384-G+2Q2i9l3PPfmYkk0b4BAIUrs7xb/DNaTL1wCYYab4c9dIKlCyiqzC0Qx3eq9Wf6
```

The browser refuses the script if jsDelivr serves different bytes. Scalar
reads the document URL from `<script id="api-reference" data-url="...">`, so
the page has no inline script. Without JavaScript it shows a link to the
document.

### Content-Security-Policy

`Docs.scalar` sends this policy with the CDN options:

```text
default-src 'none'; script-src https://cdn.jsdelivr.net;
style-src 'self' 'unsafe-inline' https://fonts.scalar.com;
font-src 'self' https://fonts.scalar.com data:; img-src 'self' data: https:;
connect-src 'self'; base-uri 'none'; form-action 'none'; frame-ancestors 'self'
```

Scalar injects inline styles and loads its fonts from `fonts.scalar.com`.
`connect-src 'self'` covers fetching the document and "Test Request" calls to
the same origin. If the document lists `servers` on other origins, add them to
`connect-src` with `Docs.with_csp`, or test requests to them fail.

[Secure headers](web-middleware.md#secure-headers) (BND-40) send no
Content-Security-Policy by default, so the page's own policy reaches the
browser unchanged. If you add one with `B.secure_set(config, "Content-Security-Policy", ...)`,
the middleware replaces the page's policy on every response, `/docs`
included, and a policy such as `default-src 'self'` blocks the CDN script.
Choose one of:

- Register the strict secure-headers middleware with `B.use_path` on your API
  paths only, and plain `B.secure_headers()` on the docs routes.
- Use `B.secure_unset(config, "Content-Security-Policy")` and set your policy
  per route with `B.header`.
- Make your global policy allow what the page needs, using `Docs.cdn_csp()` as
  the reference.

### Self-hosting Scalar

For an offline or air-gapped deployment, download the pinned file, check its
hash and serve it yourself:

```sh
mkdir -p public/scalar
curl -fsSL -o public/scalar/standalone.js \
  https://cdn.jsdelivr.net/npm/@scalar/api-reference@1.75.1/dist/browser/standalone.js
echo "sha384-$(openssl dgst -sha384 -binary public/scalar/standalone.js | base64 -w0)"
```

```python
def reference(c: B.Ctx) -> IO(B.Res):
  IO.pure(B.Res, Docs.scalar(c, Docs.self_hosted(Docs.options("/openapi.json"), "/scalar/standalone.js", "sha384-G+2Q...")))
# and B.serve_static on GET /scalar/* from public/
```

`self_hosted` switches to a policy that allows scripts and fonts from the
app's own origin only, and tells Scalar not to load its default fonts. The
file is about 4.6 MB; give it a long `Cache-Control` with
`B.static_cache_control`.

### Upgrading Scalar

`scalar_version`, `scalar_cdn` and `scalar_integrity` in `src/api-docs.bend`
change together. Download the new `dist/browser/standalone.js`, compute its
SHA-384 as above, update the three defs and the expected values in
`tests/openapi.test.ts`, then open `/docs` in a browser and check the console
for policy violations.

## Verification

`tests/openapi.test.ts` compiles `tests/fixtures/openapi/app.bend`, which has
every pattern form and schema kind. It checks:

- the defaults golden (`tests/fixtures/openapi/golden/`) and the fixture's
  committed `openapi.json` and `openapi-doc.bend` against a fresh generation
  from the compiled manifest; `BENDO_UPDATE_GOLDEN=1` rewrites them;
- both documents against the OpenAPI 3.1 schema with
  `@seriousme/openapi-schema-validator`, and every embedded schema with Ajv's
  2020-12 validator in strict mode;
- the running server's `/openapi.json`, byte for byte, and `/docs` with its
  headers and variants;
- the `bendo openapi` command, its config errors and its arguments.

```sh
bun test --timeout 200000 tests/openapi.test.ts
```

The Scalar page itself was checked in headless Chrome at 1440 and 390 pixels
wide: all 27 operations rendered, and the console showed no policy violations.
