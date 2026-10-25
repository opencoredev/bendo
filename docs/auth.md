# Authentication and CSRF middleware

Bendo ships four built-ins for protecting routes: basic auth, bearer auth, JWT
(HS256) and CSRF. They follow Hono's `basicAuth`, `bearerAuth`, `jwt` and `csrf`
middleware. Like the [observability built-ins](observability.md), you wrap them
in your app's middleware tag and delegate to `B.builtin`.

The complete compiled example is
[`tests/servers/mw-auth.bend`](../tests/servers/mw-auth.bend):

```python
B.use_path(Tag, "/admin/*", Builtin{B.basic_auth("admin", [B.credential("ada", "correct horse")])}),
B.use_path(Tag, "/api/*", Builtin{B.bearer_auth("api", ["a-long-random-token"])}),
B.use_path(Tag, "/me/*", Builtin{B.jwt(B.jwt_config("a-long-random-secret", 30n, "me"))}),
B.use(Tag, Builtin{B.csrf_host("https", ["https://admin.example"])}),
```

Credentials, tokens and secrets are `Data` stored in the route table, the same
way Hono keeps them in middleware options. Load real values from the
environment at startup; never commit them.

## Basic auth

`B.basic_auth(realm, users)` accepts `Authorization: Basic <base64>` where the
decoded text is `user-id:password` in UTF-8. Build each user with
`B.credential(username, password)`.

- The scheme name is case-insensitive and may be followed by several spaces.
- Standard base64 is required. Padded and unpadded forms are both accepted.
- The user-id ends at the first colon, so a password may contain colons, as
  RFC 7617 requires. A user-id cannot contain a colon.
- Bytes that are not valid UTF-8 are rejected.
- A configured credential whose username or password holds a non-scalar character (a lone surrogate, or a code point above U+10FFFF) never matches, so no client can sign in with it.

A request without valid credentials gets status 401, body `Unauthorized`, and
this challenge, with `"` and `\` in the realm escaped:

```text
WWW-Authenticate: Basic realm="admin", charset="UTF-8"
```

Every configured pair is checked on every request. See
[constant-time comparison](#constant-time-comparison) below.

## Bearer auth

`B.bearer_auth(realm, tokens)` accepts `Authorization: Bearer <token>` for any
of the listed tokens. The responses follow RFC 6750:

| Request | Status | `WWW-Authenticate` |
|---|---|---|
| No `Authorization` header | 401 | `Bearer realm="api"` |
| Another scheme, or a token outside the `b64token` syntax | 400 | `Bearer realm="api", error="invalid_request"` |
| A well-formed token that is not listed | 401 | `Bearer realm="api", error="invalid_token"` |

`b64token` is one or more of `A–Z a–z 0–9 - . _ ~ + /`, followed by any number of
`=`.

## JWT

`B.jwt_config(secret, leeway, realm)` configures HS256 verification with a UTF-8
secret. Use at least 32 random bytes, such as `openssl rand -base64 32`, and
load it from the environment rather than the source. HS256 is only as strong
as its secret: anyone who guesses it can sign any claims. A secret holding a
non-scalar character (a lone surrogate, or a code point above U+10FFFF) has no
UTF-8 form, and the empty secret is no secret, since anyone can compute HMAC
under an empty key. A config with either refuses every token, and so does one
built directly with an empty key.
`leeway` is the allowed clock skew in whole seconds. `B.jwt(config)`
reads `Authorization: Bearer <token>`, verifies it against the wall clock
(`src/effects/clock.bend`) and calls the next layer. To hand the claim set to
your handler, call `B.jwt_with` from your own middleware case and store it in
your `Vars`:

```python
case Auth{}:
  B.jwt_with(Vars, B.jwt_config("a-long-random-secret", 30n, "me"), c, claims => ctx => next(C.set(Vars, ctx, Vars{claims})))
```

`claims` is the payload as `Json.Json`, always a `JObject`.

Verification rejects a token, with status 401, when:

- it does not have exactly three `.`-separated segments;
- its signature segment is not the unpadded base64url HMAC-SHA256 of the first
  two segments, which covers tampered headers, payloads and signatures, and
  `alg: none` tokens with an empty signature;
- a segment is not strict unpadded base64url, or the header or payload is not a
  JSON object;
- the header's `alg` is anything but the string `HS256`, including `none`,
  `RS256` and `HS512`, or the header has a `crit` field;
- the header or the payload repeats a top-level member name (error
  `duplicate member name`), such as `{"alg":"HS256","alg":"none"}` or
  `{"exp":2000000000,"exp":1}`;
- the header or the payload has more than 256 top-level members (error
  `too many members`);
- `exp`, `nbf` or `iat` is present but not a JSON number;
- `now >= exp + leeway` (expired), `nbf > now + leeway` (not yet valid), or
  `iat > now + leeway` (issued in the future).

The signature is checked before the header, so a forged header never reaches
the `alg` check, and only a token signed with the secret can make the verifier
parse JSON or compare member names. The header checks run in the order listed:
`alg` and `crit` read the first member of each name, then the member names are
checked. A header with a repeated name is therefore always rejected, though the
error may be `unsupported algorithm` when its first `alg` is wrong. Member
names are compared pairwise, which is why objects are capped at 256 members:
anything larger fails after one linear count. Because only HS256 is accepted, a token that names RS256 cannot
be verified with the HMAC secret as if it were a public key.

Time claims are compared exactly as decimal numbers, so fractions and exponents
such as `1.7e9` work. A negative `exp` is always expired; a negative `nbf` or
`iat` always passes. The leeway applies to all three claims. Hono checks `iat`
without leeway, and jose does not reject a future `iat` by default.

Failures carry the reason in the challenge:

```text
WWW-Authenticate: Bearer realm="me", error="invalid_token", error_description="token expired"
```

A missing header gets `Bearer realm="me"` and another scheme gets
`error="invalid_request"`, both with status 401, as in Hono. If the wall clock
fails, the response is an empty 500. Cookie tokens are not supported.

### Signing and verifying directly

`B.jwt_sign(secret, claims)` signs a `JObject` claim set with the header
`{"alg":"HS256","typ":"JWT"}` and returns `Result<.., B.JwtError, String>`.
`B.jwt_verify(secret, token, now, leeway)` returns the claims or the error.
With an empty secret, or one holding a non-scalar character, `jwt_sign` fails
with `BadEncoding` and `jwt_verify` with `BadSignature`.
Both are pure. The tests check every direction against the `jose` npm package.
Signing a claim set with a repeated member name, or with more than 256
members, fails with the same error (`DuplicateMember` or `TooManyMembers`) that
verifying it would give.
For byte secrets, pass the octets to `B.jwt_signed` or put them in the config
yourself; an empty key is refused there too. `src/crypto/jwt.bend` (`sign`,
`verify`, `error_text`) is the raw HS256 layer under them and does not check
the key, so do not call its `sign` or `verify` with an empty one.

## CSRF

`B.csrf(origins)` and `B.csrf_host(scheme, origins)` follow Hono's `csrf`
middleware. They inspect only requests that a cross-site HTML form could send
without a CORS preflight: any method other than `GET` and `HEAD`, with a
`Content-Type` of `application/x-www-form-urlencoded`, `multipart/form-data` or
`text/plain`, or no `Content-Type` at all. A JSON request is not inspected,
because browsers preflight cross-origin JSON; use CORS to control it.

The check fails closed. A `Content-Type` whose media type is not
`type/subtype`, two HTTP tokens after trimming spaces and tabs, is inspected
like a form type. That covers `text`, `text/plain/x`, an empty value and any
control character.

An inspected request passes when any of these holds:

- `Sec-Fetch-Site` is `same-origin`.
- Its claimed origin is one of `origins`.
- `Sec-Fetch-Site` is not `cross-site`, the middleware was built with
  `B.csrf_host(scheme, ..)`, and the claimed origin is `scheme://` followed by
  the request's `Host`.

Everything else gets status 403 with body `Forbidden`.

The claimed origin is the `Origin` header. Only when `Origin` is absent does
the middleware use the origin of the `Referer` URL; Hono does not read
`Referer`. `Origin: null`, a scheme other than `http` or `https`, userinfo, or
an `Origin` value with a path fails, and so does a request with neither header.
If `Origin`, `Referer` or `Sec-Fetch-Site` appears more than once, the
middleware ignores all three, so an inspected request fails: two copies
disagree about the sender, and a repeated `Origin` must not fall back to
`Referer`.

Origins compare as serialized origins: scheme, host and port. Scheme and host
are compared in lowercase, and the default port is dropped, so
`https://App.Example:443` equals `https://app.example`, while
`http://app.example` and `https://app.example:8443` are different origins.

A host counts only in the form browsers send it: a DNS name, a dotted-quad
IPv4 address such as `127.0.0.1`, or a bracketed IPv6 address in RFC 5952 form
such as `[::1]`. Bendo rejects other spellings instead of rewriting them. So
configure `http://127.0.0.1`, not `http://127.1`, and `https://[::1]`, not
`https://[0::1]`; the rejected forms are never what a browser sends, and an
entry written that way is dropped. A DNS name may not end in a number
(`a.b.1`), since browsers read such a host as IPv4, and has at most 253
characters; one trailing root dot (`app.example.`) does not count and stays in
the origin. Each entry of `origins` may
be a full URL; only its origin counts. Entries that are not `http` or `https`
URLs are ignored.

`Sec-Fetch-Site: cross-site` only blocks the `Host` match. A listed origin is
trusted even from another site, since listing it is the way to allow one.

### Which constructor to use

The server cannot see the scheme a browser used: behind a proxy, TLS ends
before Bendo. So `Host` only proves an origin when you supply the scheme.

- Use `B.csrf(["https://app.example"])` when you know your public origin. This
  is the safest choice and works behind any proxy.
- Use `B.csrf_host("https", origins)` when one build serves several hostnames
  over HTTPS through a proxy that passes the browser's `Host` through
  unchanged. Do not use `"https"` if the app is also reachable over plain HTTP
  under the same `Host`.
- Use `B.csrf_host("http", origins)` only for local development over plain
  HTTP.

A proxy that rewrites `Host` breaks the `Host` match; list the public origin in
`origins` instead.

## Constant-time comparison

Basic and bearer auth never compare a supplied secret with a stored one
directly. They hash both sides with SHA-256 and compare the 32-byte digests with
`Compare.ct_equal`, which XORs every byte pair and ORs the results together with
no early exit. Basic auth compares a 64-byte digest pair per user, so the
username and password are checked together. The result for each configured
entry is folded with `U32.or`, which evaluates both sides, so the position of a
matching entry does not end the scan.

This is an algorithmic property, not a timing guarantee. Bend's compiler and
runtime promise nothing about constant-time execution. Decision
[0012](decisions/0012-constant-time-auth.md) explains what is and is not
covered.

## Laws

`LAWS.bend` proves the functional parts with the strict kernel:

- `ct_equal_spec`: `Compare.ct_equal(xs, ys)` equals an independent in-order
  element-wise equality, for all lists of any lengths.
- `jwt_open_seal`: opening a token sealed with a secret returns exactly the
  sealed header and payload octets, for every secret and every octet header and
  payload.
- `jwt_rejects_bad_signature`: every token `a.b.c` with dot-free segments whose
  `c` is not the base64url HMAC-SHA256 of `a.b` fails with `BadSignature`.
- `jwt_rejects_malformed`: every token whose number of `.` characters is not
  two fails with `Malformed`.
- `jwt_rejects_bad_encoding`: a correctly signed `a.b.c` whose `a` or `b` is
  not strict unpadded base64url fails with `BadEncoding`. Strictness is stated
  independently in `proof/jwt-spec.bend` (`base64url`): alphabet characters
  only, a length that is not one more than a multiple of four, and zero unused
  bits in the last character.
- `jwt_verify_rejects_bad_alg`: if the header segment decodes to a JSON object
  that does not have exactly one `alg` member holding the string `HS256`
  (`alg_accepted` counts the members itself), `verify` fails, whatever the
  signature, payload, time and leeway.
- `jwt_verify_bad_alg_exact`: with canonical segments, the correct signature
  and no repeated header member names, that failure is exactly `BadAlgorithm`,
  at any number of members.
- `jwt_verify_keeps_open_failure`: whenever `open` fails (malformed token, bad
  encoding, bad signature), `verify` fails with the same error.
- `jwt_verify_rejects_non_object_header` and
  `jwt_verify_rejects_non_object_payload`: if the header or payload segment
  decodes to octets that are not JSON, or JSON that is not an object
  (`JwtSpec.json_object`), `verify` fails, whatever the other segments.
- `jwt_verify_rejects_repeated_header_member` and
  `jwt_verify_rejects_repeated_claim`: if the header or payload decodes to a
  JSON object with a repeated top-level member name (`JwtSpec.distinct` is
  false), `verify` fails, whatever the other segments.
- `csrf_decision_spec`: the CSRF decision equals `CsrfSpec.allows` in
  `proof/csrf-spec.bend` for every policy, method and header combination. The
  spec restates the policy above without calling the middleware's helpers.
  It reads origins and media types through the independent specifications in
  `proof/origin-spec.bend` and `proof/media-spec.bend`, not through the
  middleware's parsers.
- `origin_canonical_spec`, `origin_of_url_spec` and `origin_of_host_spec`: for
  every input, `src/http/origin.bend` returns what `proof/origin-spec.bend`
  says, so the CSRF, CORS and WebSocket laws also hold for the parser the
  middleware runs. `media_essence_spec` and `media_well_formed_spec` do the
  same for `src/http/media.bend`.
- `csrf_spec_v1_inspected` and `csrf_spec_v1_denies`: failing closed on a
  malformed media type only adds denials. `proof/csrf-spec-v1.bend` keeps the
  Content-Type rule from before BND-85, which trimmed with Base's
  `String.trim` and exempted every value that was not a form type. Every
  request it inspected is still inspected, and every request it denied is
  still denied.
- `origin_read_back`: reading a serialized origin gives back the scheme, host
  and port it was parsed into, so distinct origins never serialize alike.
- `csrf_configured_decision_spec`: the same, for the policy the middleware
  builds from configuration with `CsrfPolicy.policy`. Configured entries become
  their URL origins (`CsrfSpec.configured`) and the scheme is lowercased
  (`CsrfSpec.configured_scheme`).
- The middleware's rule for repeated `Origin`, `Referer` and `Sec-Fetch-Site`
  fields lives in its IO shell and is covered by integration tests.

The per-character facts behind `jwt_rejects_bad_encoding` are generated:
`bun scripts/gen-base64url-chars.ts > proof/base64url-chars.bend` rebuilds
them.

The claim layer's time checks (`exp`, `nbf`, `iat`) are covered by integration
tests, not laws. The claim round trip is pending on BND-79's JSON round trip
(see [JSON](data/json.md)). Stated precisely, it is: for every claim object in
an independently specified JSON round-trip domain (defined to include
duplicate keys and number spelling), if signing succeeds and its optional
`exp`/`nbf`/`iat` satisfy the documented checks at `now` and `leeway`,
verifying the resulting token returns exactly that claim object. In Bend terms
it will quantify over `fields`, require `Json.admissible(JObject{fields})`
(BND-79's domain, which fixes number spelling), `JwtSpec.distinct(fields)`
(which excludes duplicate keys, since `verify` rejects them),
`Jwt.sign(secret, JObject{fields}) == Done{token}` and an independent
restatement of the three time checks, and conclude
`Jwt.verify(secret, token, now, leeway) == Done{JObject{fields}}`.

Verify with:

```sh
bun run prove
bun test --timeout 30000 tests/mw-auth.test.ts
```
