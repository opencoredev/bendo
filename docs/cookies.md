# Cookies

Read request cookies and append response cookies through the public context API.
Import `src/data/cookie.bend` for the options and error constructors.

```python
import Base
import ../src/main.bend as B
import ../src/data/cookie.bend as Cookie
import ../src/http/response.bend as Response

def remembered(result: Result<&2, &2, Cookie.Error, B.Ctx>) -> B.Res:
  match result:
    case Fail{error}: Response.text(400, "Invalid cookie")
    case Done{updated}: B.text(updated, "Remembered")

def remember(c: B.Ctx) -> B.Res:
  remembered(B.set_cookie(c, "session", "abc123", Cookie.Options{
    Some{"/"}, None{}, Some{Cookie.Seconds{3600n}}, None{},
    True{}, True{}, Some{Cookie.Lax{}}, False{}
  }))
```

This appends `set-cookie: session=abc123; Path=/; Max-Age=3600; Secure; HttpOnly; SameSite=Lax`.
Setters return a new context; they preserve pending status, other headers and
previous cookies. Each successful set or delete appends one field. Cookies are
never comma-joined. Handle the typed error before committing the response.

## Read cookies

`B.cookies(c) -> List<&2, Cookie.Entry>` parses all Cookie header fields in
arrival order. `Cookie.Entry{name: String, value: String}` retains repeated names.
`B.cookie(c, name) -> Maybe<&2, String>` returns the first valid pair with that
case-sensitive name, or `None{}`.

Parsing tolerates SP and HTAB around semicolon-separated pairs. Only the first
`=` separates name and value, so `a=x=y` reads as name `a`, value `x=y`. Empty
values are valid. Matching outer double quotes are removed: `a="x=y"` reads as
`x=y`. Missing `=`, empty or invalid names, unmatched quotes and invalid value
characters cause that segment to be skipped; subsequent segments still parse.
There are no backslash escapes in quoted cookie values.

Values are raw RFC 6265 cookie-octets. There is no automatic percent encoding or
decoding; `%20` and `+` remain literal. Encode arbitrary text explicitly, for
example with `src/data/urlencoded.bend`'s `encode`, then decode it in your app.
Do not pass raw Unicode, whitespace, double quotes, commas, semicolons,
backslashes or control characters as values.

The pure functions are `Cookie.parse(header) -> List<&2, Cookie.Entry>` and
`Cookie.first(pairs, name) -> Maybe<&2, String>`.

The pure parser uses accumulator scans for splitting, validation and collecting
pairs. Native and `.mjs` regression tests cover 32,000- and 64,000-character
values, a 64,000-character name and 8,000 ordered pairs. These are parser tests;
the HTTP server's configured header limit still applies to network requests.

## Write cookies

`B.set_cookie(c, name, value, options)` returns
`Result<&2, &2, Cookie.Error, B.Ctx>`. The generic context module offers the same
function as `C.set_cookie(Vars, c, name, value, options)` for `C.Ctx<Vars>`.
The pure serializer is `Cookie.serialize(name, value, options)`, returning
`Result<&2, &2, Cookie.Error, String>`.

`Cookie.defaults()` omits every attribute. `Cookie.Options` has these fields,
in constructor order:

| Field | Type | Behavior |
| --- | --- | --- |
| `path` | `Maybe<&2, String>` | Absolute path beginning with `/`; printable ASCII, no semicolons or trailing space. |
| `domain` | `Maybe<&2, String>` | ASCII hostname labels, optionally with a leading dot; no empty labels or leading/trailing hyphens. Labels have at most 63 characters; the complete input has at most 254. No public-suffix or origin check is performed. |
| `max_age` | `Maybe<&2, Cookie.MaxAge>` | `Seconds{n}` emits a nonnegative integer; `NegativeSeconds{n}` emits a negative integer. Both use `Nat` whole seconds. Zero or negative ages expire the cookie immediately. |
| `expires` | `Maybe<&2, String>` | Fixed-width IMF-fixdate such as `Wed, 21 Oct 2015 07:28:00 GMT`. Checks weekday/month tokens, digit widths, Gregorian day ranges, year ≥ 1601 and time ranges. Weekday/date agreement is not checked. |
| `secure` | `Bool` | Emits `Secure` when true. |
| `http_only` | `Bool` | Emits `HttpOnly` when true. |
| `same_site` | `Maybe<&2, Cookie.SameSite>` | `Strict{}`, `Lax{}`, or `NoRestriction{}` for `SameSite=None`. None requires Secure. |
| `partitioned` | `Bool` | Emits `Partitioned` when true; requires Secure. |

Attributes are emitted in that order, exactly as supplied. Max-Age takes
precedence over Expires in browsers when both are present. BND-10 will add the
wall clock and Unix-time formatter; this API currently accepts an Expires string
and never reads the monotonic clock for expiry.

Names must be nonempty HTTP tokens. Values must satisfy `Cookie.value_valid`,
which permits ASCII `0x21`, `0x23–0x2B`, `0x2D–0x3A`, `0x3C–0x5B`, and
`0x5D–0x7E`, including `=` and the empty string. `Cookie.name_valid` is the name
predicate. Invalid input returns `InvalidName{}`, `InvalidValue{}`,
`InvalidPath{}`, `InvalidDomain{}`, or `InvalidExpires{}`. Invalid security
combinations return `SameSiteRequiresSecure{}` or `PartitionedRequiresSecure{}`.
No header is appended on failure. Cookie name prefixes such as `__Host-` have
no additional framework policy; configure their browser-required attributes.

`Cookie.serialize_pair(name, value)` is an unchecked pair formatter for already
validated values and proofs. Use `serialize` or `set_cookie` for external input.

## Delete cookies

`B.delete_cookie(c, name, options)` has the same result type as `set_cookie`.
Supply the same Path and Domain as the original cookie, plus its security and
SameSite options. Deletion forces an empty value and `Max-Age=0`, removes Expires,
and preserves the other options. Existing Max-Age and Expires are overridden,
even if the supplied expiry string is invalid. Deleting a different scope does
not remove the original browser cookie.

The generic form is `C.delete_cookie(Vars, c, name, options)`.
`Cookie.deletion(options)` builds the corresponding pure options value.

Run `bun run prove` and
`bun test --timeout 120000 tests/cookies.test.ts` to check the laws and both
compiled targets, including raw `curl -i` Set-Cookie fields.

The original pair, default-serialization and ordered-list laws remain in
`LAWS.bend`. Its imported cookie law modules also cover ordered headers joined
with `"; "`, arbitrary SP/HTAB padding before and after each pair, and full
Set-Cookie serialization. `proof/cookie-ows-spec.bend` represents padding as any
finite mixture of `Space` and `Tab`, selected separately for every pair and side.

`proof/cookie-serialization-spec.bend` defines admissibility and the exact wire
format independently of the implementation's validators and serializer.
Serialization must succeed for every admissible name, value and options tuple,
with attributes in the table's order, casing and spacing. A successful result
must satisfy the independent Set-Cookie structure specification, including
proof that every Path, Domain, Max-Age, Expires and SameSite payload excludes
semicolons, CR and LF. Expires is copied verbatim after an independent
fixed-width date and calendar check; weekday/date agreement remains outside
this contract.

## Sign and verify cookies

Import `src/data/signed-cookie.bend` as `SignedCookie`. Configure rotation keys
once at startup with `SignedCookie.configure(["current-secret", "previous-secret"])`.
It returns `Some{keys}` for a nonempty list of nonempty Unicode scalar strings
and `None{}` for an empty list, an empty string in any slot, or an invalid
scalar in any key. Anyone can compute an HMAC under the empty key, so an empty
previous-key slot would accept forged cookies; Hono's WebCrypto backend rejects
empty keys too. Handle `None{}` as a configuration error before serving
requests.

Use at least 32 random bytes for each secret, generated by a cryptographically
secure source (for example `openssl rand -base64 32`), not a password or a
word. Keep keys on the server and load them from your secret configuration.

Bend cannot hide the `Keys{first, rest}` constructor, so a `Keys` value can be
built without `configure`. Every entry point rechecks it with the same rule:
if any slot is empty or not a Unicode scalar string, `verify`, `read`,
`verify_digest` and `B.signed_cookie` return `None{}`, `sign` returns `None{}`,
and `serialize` and `B.set_signed_cookie` return `Cookie.InvalidSecret{}`. The
value is checked first: a non-scalar value gives `Cookie.InvalidValue{}` under
any keys.

`B.set_signed_cookie(c, name, value, keys, options)` returns
`Result<&2, &2, Cookie.Error, B.Ctx>`, just like `set_cookie`. It signs with the
first key, applies the ordinary cookie name and options checks, and appends one
Set-Cookie field. Non-scalar values return `Cookie.InvalidValue{}`; keys with an
unusable slot return `Cookie.InvalidSecret{}`. Other response
state and previously appended cookies are preserved. Unlike raw cookie setters,
this API accepts Unicode, whitespace and delimiters in values because it percent
encodes the complete signed payload before passing it to the cookie serializer.

`B.signed_cookie(c, name, keys) -> Maybe<&2, String>` reads the first cookie with
that name and verifies it against every configured key. It returns `Some{value}`
only after a signature matches. Missing cookies, malformed encodings, unsigned
cookies and bad signatures all return `None{}`. An invalid first duplicate is
not skipped in favor of a later valid cookie. Keep the previous key in the list
until cookies signed with it have expired; remove it to revoke those cookies.
The generic context module provides both functions with `Vars` as the first
argument.

The wire format follows Hono's `setSignedCookie`/`getSignedCookie` algorithm:
percent encode `value + "." + base64(HMAC-SHA256(UTF8(secret), UTF8(value)))`.
Base64 uses the standard `+` and `/` alphabet with padding. Verification decodes
percent escapes once, splits at the last dot, and strictly decodes Base64.
Literal `+` stays a plus, not a form-space. The encoder escapes a few more
characters than JavaScript's `encodeURIComponent`; both decode to the identical
signed payload, so cookies interoperate in both directions. The output consists
only of valid cookie-octets. No BND-31 raw-cookie parsing behavior changes.

For Hono compatibility, the cookie name is **not signed**. A signed value can be
moved between cookie names that use the same key. Use separate keys for distinct
purposes or include and validate a purpose field in your application payload.
Signing authenticates the value; it does not encrypt it or add expiry, replay
protection or server-side revocation. Use cookie options and application policy
for those properties.

Verification reuses `src/crypto/compare.bend`'s `ct_equal`, visits every digest
byte and checks all keys even after a match. This is best-effort constant-time
comparison: Bend's compiler and runtime do not guarantee constant-time execution.
Malformed-input rejection, lengths and allocation remain observable.

The pure module exposes `sign(keys, value) -> Maybe<&2, String>`, `verify(keys,
wire) -> Maybe<&2, String>`, `read(keys, maybe_wire)` and `serialize(name,
value, keys, options)`. `sign` signs with the first key and returns `None{}` for
unusable keys or a non-scalar value. `unchecked_sign(key, value) -> String` is
the raw primitive the others build on; it checks neither the key nor the value.

The module also exposes the internal steps those entry points are built from:
`matches`, `verify_usable`, `signed` and `serialize_keys`. They take a flag or
assume keys already passed `usable`, and do **not** recheck the slots, so a
directly built `Keys` with an empty slot can authenticate a forged cookie
through them. Treat them like `unchecked_sign`: never call them from
application code. Use `verify`, `read`, `sign`, `serialize`,
`B.signed_cookie` and `B.set_signed_cookie`, which always check.
Run
`bun test --timeout 30000 tests/cookies-signed.test.ts` for native HTTP and `.mjs`
roundtrips, rotation, tampering and Hono-algorithm interoperability checks.

The signed-cookie laws in `proof/signed-cookie-laws.bend` are checked through
`PROOF.bend`. `proof/signed-cookie-spec.bend` states the independent
specifications they refer to:

- `configure(keys)` equals `Spec.configure`, which accepts exactly the nonempty
  lists whose every key is nonempty and `Utf8.valid`. A successful
  configuration implies every key is nonempty.
- Keys with any slot that `Spec.configure` would reject (`Spec.secrets` is
  false) accept and sign nothing: `verify_digest`, `verify` (every wire),
  `read` and the context reader return `None{}`, `sign` returns `None{}`, and
  for scalar values `serialize` and the context setter return
  `InvalidSecret{}`.
- `unchecked_sign(key, value)` equals `Spec.signed_wire(key, value)` for every
  key and value. The spec percent encodes the UTF-8 octets of `value ++ "." ++
  Spec.base64(HMAC-SHA256(key, value))`: RFC 3986 unreserved octets stay
  literal and the rest become `%HH` with uppercase hex. `Spec.base64` is RFC
  4648 stated over bits, with the standard alphabet and `=` padding.
  For usable keys and a scalar value, `sign` returns the first key's
  `Spec.signed_wire`; a non-scalar value gives `None{}` for every `Keys`.
- `serialize` with usable `Keys{first, rest}` equals `Cookie.serialize` of the
  first key's `Spec.signed_wire`, and returns `InvalidValue{}` for non-scalar
  values under any keys. The context setter equals `set_cookie` with that wire
  value. For an admissible name and options, the emitted field is exactly
  BND-31's independent `Set-Cookie` serialization of `name=wire`, and the
  setter appends exactly that one `set-cookie` header after the existing
  response headers, leaving the rest of the context unchanged.
- For usable keys, every scalar value and every key listed anywhere in
  `Keys{first, rest}`, `verify(keys, unchecked_sign(key, value)) ==
  Some{value}`. The proofs establish
  universally that HMAC output is octets, that the Base64 payload is
  dot-free scalars and that the last-dot split recovers both halves.
- Placing the emitted pair in a `"; "`-joined Cookie header, after valid pairs
  with other names and before any valid pairs (including later duplicates),
  makes the first-wins lookup plus `read` return the value. The context reader
  is that lookup followed by verification. The same holds end to end through
  `Context.signed_cookie` on a request whose `cookie` header field carries
  that header, with any other request headers around it as long as none is
  named `cookie`.
- For every `Keys` value and every wire string, `verify(keys, wire)` equals
  `Spec.verify(keys, wire)`. That spec rejects unusable keys, URL-decodes with
  `Url.decode`, splits at the last dot with an independent structural
  definition, decodes the suffix with `Base64.decode`, and accepts only when
  the bytes equal some listed key's HMAC over the prefix. Malformed or
  unauthenticated input therefore returns `None{}`, and a signature under any
  listed key is accepted.

`Spec.verify` is independent of the implementation only in the last-dot split
and the key and HMAC relation: it calls the same `Url.decode` and
`Base64.decode`. The laws in `proof/signed-cookie-decoder-laws.bend` specify
both decoders independently, so a decoder bug cannot hide behind the wire law:

- `Base64.decode(s, False{}, True{}) == Some{bytes}` implies
  `s == Spec.base64(bytes)` and every byte is at most 255. Strict standard
  Base64 accepts only the canonical encoding.
- `Url.percent_decode` in query mode equals `proof/url-decode-spec.bend`'s
  `unpercent`: RFC 3986 `%HH` escapes with either hex case, a `%` without two
  hex digits rejected, and every other octet, including `+`, kept literally.
- A string `Utf8.decode` returns holds only Unicode scalars and encodes back to
  exactly its input octets. With the existing roundtrip law (every scalar
  string decodes back), strict UTF-8 decoding is the inverse of the encoder.
- Together, five laws fix `Url.decode(wire)` completely. It returns
  `Done{value}` exactly when the wire is a scalar string and `value` is a
  scalar string whose UTF-8 octets are `unpercent` of the wire's UTF-8 octets.
  It returns the percent error when `unpercent` fails, and `InvalidUtf8`
  otherwise.
- Verification is restated over these decoders alone. `verify(Keys{first,
  rest}, wire) == Some{value}` holds exactly when the wire and `value` are
  scalar strings, the keys are usable, and for some listed key, `unpercent` of
  the wire's octets
  is the UTF-8 encoding of `value ++ "." ++ Spec.base64(HMAC-SHA256(key,
  value))`. Every escaping of that payload verifies, and nothing else does.

`Url.decode` reads the wire's characters as their UTF-8 octets first. A Bend
`Char` can hold a surrogate or a value above U+10FFFF, which has no UTF-8
encoding. `Utf8.encode` writes such a character as U+FFFD, so `Url.decode`
checks the wire with `Utf8.valid` and fails with `InvalidUtf8` instead of
decoding a replacement character, and `verify` returns `None{}`. HTTP cookie
values cannot carry one, because the cookie parser accepts only ASCII
cookie-octets, so wires that reach `verify` through `B.signed_cookie` never
hold one.

Cookie-name binding is out of scope by design (see above).
