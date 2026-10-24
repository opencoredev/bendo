# CORS, secure headers, method override and trailing slash

Bendo ships four built-ins for browser-facing apps. They follow Hono's `cors`,
`secureHeaders`, `methodOverride` and `trimTrailingSlash`/`appendTrailingSlash`
middleware, with the differences listed in each section. Like the
[observability](observability.md) and [authentication](auth.md) built-ins,
you wrap them in your app's middleware tag and delegate to `B.builtin`.

The complete compiled example is
[`tests/servers/mw-cors.bend`](../tests/servers/mw-cors.bend):

```python
B.on_request(Tag, Builtin{B.method_override()}),
B.use(Tag, Builtin{B.trim_trailing_slash()}),
B.use_path(Tag, "/api/*", Builtin{B.cors(B.cors_allow([
  B.cors_origin("https://app.example"),
  B.cors_origin_credentials("https://admin.example")
]))}),
B.use(Tag, Builtin{B.secure_headers()}),
```

## Where to register them

Method override must be an `on_request` hook. It is the only stage that runs
before routing, so only there does the new method select the route. Registered
with `B.use`, the handler would see the new method but the route would already
have been chosen by the old one.

CORS, secure headers and trailing slash are ordinary middleware. Register them
with `B.use` or `B.use_path`, before the middleware whose responses they should
cover, since the first registration is the outermost layer. They then cover the
handler, inner middleware, inner short circuits and the router's 404 and 405
answers.

CORS and security middleware retain the policy that applies to this request.
After `after_handle`, `map_response`, `on_error` and final response validation,
the framework applies those policies again before observers and transport.
Replacement responses and validation-generated 500s carry the same CORS grant
and security headers. An invalid custom field produces a 500; valid policy
fields, request ID and timing still reach that response. Existing `Vary` fields
are merged, including `Vary: *`.
Requests rejected before middleware runs (malformed HTTP or bad query encoding)
are outside these policies. A middleware registered inside a short circuit
cannot cover that response, because it never ran.

## CORS

`B.cors(config)` answers preflights and adds CORS fields to other responses.
Build `config` with one of:

- `B.cors_defaults()`: every origin gets `Access-Control-Allow-Origin: *`.
  Credentials are never allowed: browsers reject `*` with credentials, so the
  type has no way to ask for both.
- `B.cors_allow(origins)`: only listed origins get a grant. Build each entry
  with `B.cors_origin(origin)` or, to also send
  `Access-Control-Allow-Credentials: true` to that origin,
  `B.cors_origin_credentials(origin)`. Credentials are chosen per origin.

For credentialed origins, list header names explicitly. A configured
`headers: ["*"]` is sent literally; browsers do not treat it as a wildcard on
credentialed requests. Leaving headers unconfigured reflects the requested names.

Adjust either with `B.cors_methods(config, methods)`,
`B.cors_headers(config, headers)`, `B.cors_expose(config, headers)` and
`B.cors_max_age(config, seconds)`.

| Setting | Default | Sent as |
|---|---|---|
| methods | `GET,HEAD,PUT,POST,DELETE,PATCH,QUERY` (Hono 4's list) | `Access-Control-Allow-Methods` on preflights |
| headers | none: the preflight's requested headers are reflected | `Access-Control-Allow-Headers` on preflights |
| expose | none | `Access-Control-Expose-Headers` on other responses |
| max age | none | `Access-Control-Max-Age` on preflights |

### Which origins match

A request's origin is its `Origin` field serialized as an origin, with the
parser the [CSRF middleware](auth.md#csrf) uses (`src/http/origin.bend`):
scheme and host in lowercase, the default port dropped. So
`https://APP.example:443` matches a configured `https://app.example`, and the
grant echoes the serialized form. `http://app.example`,
`https://app.example:8443` and `https://sub.app.example` are other origins.

Hosts must be written the way browsers send them, as described in
[the CSRF section](auth.md#csrf): an entry such as `http://127.1` or
`https://[0::1]` is dropped, so configure `http://127.0.0.1` or
`https://[::1]`.

Dropped entries are silent with `B.cors_allow`. Build the list once at
startup with `B.cors_allow_checked(origins)` instead, an `IO(B.CorsConfig)`,
and each dropped entry prints one line on stderr:

```text
bendo: cors: ignoring allowed origin "app.example": not an http or https URL
```

Configured entries may be full URLs; only their origin counts, so
`https://app.example/login` configures `https://app.example`. Request `Origin`
values must be bare origins: a path, userinfo or another scheme is not an
origin and is denied.

`Origin: null` comes from sandboxed iframes, `file:` pages, some redirects and
privacy-sensitive contexts. Any of those pages could send it, so it cannot
identify anyone. A listed policy never matches it, and configuring `"null"` (or
`"*"`) in `B.cors_allow` has no effect. `B.cors_defaults()` answers `null`
origins with `*`, like every other origin, still without credentials.

With `B.cors_allow`, a request with two `Origin` fields gets no grant, even if
one copy is listed. `B.cors_defaults()` still answers it with `*`, since `*`
does not depend on the origin and never carries credentials.

### Responses

A preflight is an `OPTIONS` request with an `Origin` field and an
`Access-Control-Request-Method` field. The middleware answers it with an empty
204 and does not call the handler. An allowed origin gets, in order:
`Access-Control-Allow-Origin`, `Access-Control-Allow-Credentials` when that
origin has credentials, the methods, the headers and the max age. A denied
origin gets the 204 with no CORS field, so the browser blocks the request.
Hono sends the methods and headers to denied origins too.

Any other request, including an `OPTIONS` request without those fields, goes
to the app. The middleware then removes any `Access-Control-Allow-Origin`,
`Access-Control-Allow-Credentials`, `Access-Control-Allow-Methods`,
`Access-Control-Allow-Headers`, `Access-Control-Max-Age` and
`Access-Control-Expose-Headers` fields
the app set, and adds its own for an allowed origin. Two conflicting grants
are never sent, and a handler cannot grant an origin the policy denies.

When no headers are configured, the requested headers are reflected: every
`Access-Control-Request-Headers` field is combined, split on commas, trimmed,
lowercased, and items that are not HTTP tokens are dropped.

### Vary

With `B.cors_allow`, every response varies by origin, whether the origin was
allowed, denied or absent. A cache therefore never replays one origin's
answer to another. Preflights that reflect requested headers also vary by
`Access-Control-Request-Headers`. `B.cors_defaults()` answers every origin the
same way and adds no `Vary: Origin`.

Every existing `Vary` field is merged into one: the app's values stay as
written, and each added name is appended unless the list already has it,
compared without case. `Vary: *` stays `*`.

## Secure headers

`B.secure_headers()` sets Hono's default security headers after `next`, replacing
any value the app set, and removes `X-Powered-By`:

| Header | Value | Why |
|---|---|---|
| `Cross-Origin-Resource-Policy` | `same-origin` | Other sites cannot embed your responses with `<img>` or `<script>`, which blocks Spectre-style reads of them. |
| `Cross-Origin-Opener-Policy` | `same-origin` | A cross-origin page your page opens, or that opens it, gets no window handle to it. |
| `Origin-Agent-Cluster` | `?1` | Asks the browser to isolate the origin in its own agent cluster, so same-site pages cannot share its memory. |
| `Referrer-Policy` | `no-referrer` | Links leave no URL, so paths and query strings with tokens do not leak to other sites. |
| `Strict-Transport-Security` | `max-age=15552000; includeSubDomains` | After one HTTPS visit, the browser uses HTTPS for 180 days, for subdomains too, which defeats SSL-stripping. |
| `X-Content-Type-Options` | `nosniff` | The browser trusts `Content-Type` instead of guessing, so an upload cannot run as a script or style sheet. |
| `X-DNS-Prefetch-Control` | `off` | The browser does not resolve link hosts in advance, which would tell DNS servers what a page links to. |
| `X-Download-Options` | `noopen` | Old Internet Explorer saves downloads instead of opening them in the site's context. |
| `X-Frame-Options` | `SAMEORIGIN` | Only your own pages can frame yours, which blocks clickjacking. |
| `X-Permitted-Cross-Domain-Policies` | `none` | Flash and PDF readers ignore any `crossdomain.xml`, so they cannot load your data cross-origin. |
| `X-XSS-Protection` | `0` | Turns off the old XSS auditors, whose filtering could itself be abused to leak or break pages. Modern browsers have removed them. |

`Cross-Origin-Embedder-Policy` is off by default, as in Hono: `require-corp`
breaks pages that load cross-origin images or scripts without CORP headers.
Browsers ignore `Strict-Transport-Security` over plain HTTP, so it is harmless
in local development.

To change the set, start from `B.secure_defaults()` and pass the result to
`B.secure_headers_with(config)`:

- `B.secure_set(config, name, value)` adds a header or replaces a default, for
  example `Content-Security-Policy`.
- `B.secure_unset(config, name)` stops sending one. The app's own value for
  that header then passes through.
- `B.secure_keep_powered_by(config)` keeps `X-Powered-By`.

Names ignore case. An invalid name or value fails normal response validation
as 500.

`Content-Security-Policy` is not sent by default, as in Hono. A useful policy
lists the exact script, style, image and connect sources one app needs, and a
generic one either breaks pages or allows too much. Add yours with
`B.secure_set(config, "Content-Security-Policy", "default-src 'self'")`.
Nonces are not generated.

## Method override

HTML forms can only send `GET` and `POST`. Method override lets a form ask for
`PUT`, `PATCH` or `DELETE`:

```html
<form method="post" action="/todos/42">
  <input type="hidden" name="_method" value="DELETE">
</form>
```

- `B.method_override()` reads the `_method` field and allows `PUT`, `PATCH`
  and `DELETE`.
- `B.method_override_form(field, methods)` reads another field.
- `B.method_override_header(name, methods)` reads a request header, such as
  `X-HTTP-Method-Override`.

The form field is read from `application/x-www-form-urlencoded` and
`multipart/form-data` bodies; other content types are left alone. Only a
`POST` is overridden, like Rails and Laravel; Hono also rewrites other
non-`GET` methods. The value is trimmed and compared without case.

| Override values on a POST | Result |
|---|---|
| none, or one empty value | stays `POST` |
| one value naming `POST` | stays `POST` |
| one value naming a listed method | the method is replaced, then routing runs |
| one value naming any other method | 400 `Bad Request` |
| two or more values (fields or headers) | 400 `Bad Request` |
| an unreadable form body, or a file part with the field's name | 400 `Bad Request` |

The body, query and headers stay unchanged, including the `_method` field.
Hono removes the field.

`GET`, `HEAD`, `OPTIONS`, `CONNECT` and `TRACE` are never produced, even when
listed, and no extension method spelled like one can stand in for them. This
keeps [CSRF protection](auth.md#csrf) sound in either registration order: a
cross-site form POST that becomes `PUT` is still an unsafe form request, so
the CSRF check inspects it. Had it become `GET`, the CSRF check would skip it.

## Trailing slash

- `B.trim_trailing_slash()` redirects `/about/` to `/about` when the route
  answers 404.
- `B.append_trailing_slash()` redirects `/about` to `/about/` when the route
  answers 404.
- `B.trim_trailing_slash_always()` and `B.append_trailing_slash_always()`
  redirect before calling `next`, whether or not a route exists. Registered
  with `B.use`, they run after routing but before the handler. To redirect
  before routing and before any other ordinary middleware, register an
  `_always` form with `B.on_request` instead. The 404 forms need the route's
  answer, so keep them in `B.use`.

Only `GET` and `HEAD` are redirected, with 301, as in Hono. The `Location` is
the new path plus the raw query, so `/about/?a=1&b=%20x` moves to
`/about?a=1&b=%20x`. `/` is never trimmed, and `OPTIONS *` is never touched.

A redirect is sent only when its target is a same-origin path: it starts with
exactly one `/` and contains no control character, space, DEL or `\`. Without
that check, trimming `//evil.example/` would answer
`Location: //evil.example`, which a browser follows to another host. Browsers
also turn `\` into `/` and drop tabs and newlines, so `/\evil.example/` is
refused too. Such requests keep their original answer, usually 404.

## Laws

`LAWS.bend` proves the pure decisions with the strict kernel. The shells that
read fields and edit responses are covered by the integration tests.

CORS (`src/mw/cors_policy.bend` against `proof/cors-spec.bend`):

- `cors_grant_spec`: the grant equals `CorsSpec.grant` for every policy and
  `Origin` field.
- `cors_wildcard_never_credentials`: `B.cors_defaults()` grants `*` without
  credentials for every request.
- `cors_listed_denies_unusable_origin`: a listed policy grants nothing when
  the request has no usable origin: none, repeated, `null` or malformed. It
  never falls back to `*`.
- `cors_listed_grant_echoes_origin`: whatever a listed policy grants names
  exactly the request's own serialized origin.
- `cors_configured_origins`: configured entries compare as their URL origins,
  and entries that are not http or https URLs are dropped.
- `cors_preflight_spec`: a preflight is exactly `OPTIONS` with `Origin` and
  `Access-Control-Request-Method`.
- `cors_preflight_fields_spec` and `cors_actual_fields_spec`: the CORS fields
  equal the specification, with the configured values in order, and none for
  a denied origin.

Response finalization (`src/mw/response_policy.bend` and request policies
against the response specs in `proof/`):

- `cors_response_spec`: for every configuration, request and downstream
  response, derive the grant from the request, remove all six downstream CORS
  grant fields and emit the complete actual or preflight field set.
- `cors_vary_origin`: listed-origin policies preserve existing `Vary` values
  and add `Origin` when absent; an existing `*` stays `*`.
- `vary_add_spec`: merging matches the independent Vary specification for
  every existing field list.
- `secure_headers_defaults_spec`: applying defaults to every response removes
  conflicting fields and `X-Powered-By`, adds the eleven literal values in
  `proof/secure-headers-spec.bend`, and preserves unrelated response data.

Method override (`src/mw/method_override_policy.bend` against
`proof/override-spec.bend`):

- `override_decision_spec`: the decision equals `OverrideSpec.decide`, which
  ties a rewrite to exactly the submitted, normalized method.
- `override_rewrites_only_post`, `override_never_safe_destination`,
  `override_never_safe_name` and `override_destination_listed`: a rewrite
  comes from a POST, is not `GET` or `HEAD`, is not named like a safe method,
  and is listed.
- `override_rejects_repeated` and `override_keeps_non_post`.
- `override_allowlist_unsafe`: a configured allowlist never contains `GET` or
  `HEAD`.

Trailing slash (`src/mw/trailing_slash_policy.bend` against
`proof/trailing-spec.bend`):

- `trailing_target_spec`: the target equals `TrailingSpec.target` for every
  mode, method, path and query.
- `trailing_redirect_same_origin` and `trailing_redirect_reads_only`: every
  target is a same-origin path and answers `GET` or `HEAD`.
- `trailing_trim_keeps_root`, `trailing_trim_target` and
  `trailing_append_target`.

Origin serialization, request field lookup, UTF-8 decoding, `Request.method`,
string splitting and token validation are shared parsing primitives. The
response specs independently define Vary membership and reflected header
selection.

Verify with:

```sh
bun run prove
bun test --timeout 30000 tests/mw-cors.test.ts
```
