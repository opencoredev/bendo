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

Run `bun run prove` and `bun test --timeout 30000 tests/cookies.test.ts` to check
the universal pair roundtrip, checked default serialization, ordered-list
roundtrip and native HTTP behavior, including raw `curl -i` Set-Cookie fields.
