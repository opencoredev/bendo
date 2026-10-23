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
B.use(Tag, Builtin{B.csrf(["https://app.example"])}),
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
secret. `leeway` is the allowed clock skew in whole seconds. `B.jwt(config)`
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
- `exp`, `nbf` or `iat` is present but not a JSON number;
- `now >= exp + leeway` (expired), `nbf > now + leeway` (not yet valid), or
  `iat > now + leeway` (issued in the future).

The signature is checked before the header, so a forged header never reaches
the `alg` check. Because only HS256 is accepted, a token that names RS256 cannot
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
Both are pure. The tests check every direction against the `jose` npm package.
For byte secrets, use `src/crypto/jwt.bend` (`sign`, `verify`, `error_text`)
directly.

## CSRF

`B.csrf(origins)` follows Hono's `csrf` middleware. It inspects only requests
that a cross-site HTML form could send without a CORS preflight: any method
other than `GET` and `HEAD`, with a `Content-Type` of
`application/x-www-form-urlencoded`, `multipart/form-data` or `text/plain`, or
no `Content-Type` at all. Such a request passes when any of these holds:

- `Sec-Fetch-Site` is `same-origin`.
- `Origin` is exactly one of `origins`.
- `Origin` is `http://` or `https://` followed by the request's `Host` (compared
  without regard to case).

Without an `Origin` header, the origin part of `Referer` (scheme, `//` and host)
is checked the same way. Hono does not read `Referer`. Everything else gets
status 403 with body `Forbidden`, including `Origin: null` and requests with
neither header.

Matching the `Host` header assumes the server sees the browser's host. Behind a
proxy that rewrites `Host`, list your public origin in `origins`. A JSON request
is not inspected, because browsers preflight cross-origin JSON; use CORS to
control it.

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

The claim layer (JSON parsing, `alg`, `exp`, `nbf`, `iat`) is covered by
integration tests, not laws. A law that `verify(secret, sign(secret, claims))`
returns the claims needs a JSON write-then-parse roundtrip law, which Bendo does
not have yet.

Verify with:

```sh
bun run prove
bun test --timeout 30000 tests/mw-auth.test.ts
```
