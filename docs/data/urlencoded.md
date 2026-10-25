# Query strings and URL-encoded forms

Import `src/data/urlencoded.bend` to decode raw query text or an
`application/x-www-form-urlencoded` body. Parsing returns an ordered list of
`Entry{key, value}` records inside `Result<&2, &2, Error, List<&2, Entry>>`.
Repeated keys stay separate. `queries(pairs, key)` returns all matching values
in arrival order; `query(pairs, key)` returns the first as `Maybe<&2, String>`.
Keys are case-sensitive after decoding.

## Components

`encode(s: String) -> String` percent-encodes a query component. Only ASCII
letters, digits, `-`, `.`, `_`, and `~` pass through unchanged. Spaces become
`%20`; literal plus becomes `%2B`. `decode(s: String)` reverses percent encoding
and leaves a raw `+` unchanged.

`encode_form(s: String) -> String` uses the WHATWG form encode set: ASCII
letters, digits, `*`, `-`, `.`, and `_` pass through. Spaces become `+`, and
literal plus becomes `%2B`. `decode_form(s: String)` treats raw plus as space.
Both decoders return `Result<&2, &2, Error, String>`.

Unicode scalar values are U+0000 through U+10FFFF, excluding U+D800 through
U+DFFF. Bend's `Chr{U32}` can represent values outside that range;
`src/data/utf8.bend` exposes `valid(s)` to check constructed Strings. The
encoders write a non-scalar character as U+FFFD (`%EF%BF%BD`), as WHATWG
`TextEncoder` does, so only scalar strings roundtrip. `decode`, `decode_form`
and `parse_pairs` refuse a string holding a non-scalar character with
`Fail{InvalidUtf8{}}`; a percent error elsewhere in the text is reported first.
Percent escapes use uppercase hexadecimal and encode UTF-8 octets.

## Pairs and bodies

`parse_pairs(s: String)` consumes raw query text after the URL's `?`. It does
not remove a leading `?`. `parse_pairs_bytes(body: List<&2, U32>)` accepts the
same data as octets. Both use form component decoding, matching
`URLSearchParams` for valid input.

Only `&` separates pairs. A semicolon is ordinary data. The first `=` separates
key from value; later equals signs belong to the value. Empty pieces are
ignored: `""` and `"&&"` produce no entries. `a` and `a=` both produce
`Entry{"a", ""}`; `=b` produces `Entry{"", "b"}`. `=` produces one entry with
both strings empty. `serialize(pairs) -> String` emits form-encoded pairs in
order, with an equals sign for every pair.

`parse_body(content_type: String, body: List<&2, U32>)` returns the same result
type. It accepts `application/x-www-form-urlencoded`, case-insensitively, with
surrounding whitespace. Charset defaults to UTF-8. An explicit `charset=utf-8`
or `charset="UTF-8"` is accepted, case-insensitively, including whitespace
around `=`. Quoted-pair escapes are decoded inside a quoted charset value.
Semicolons inside quoted parameter values do not separate parameters. Every charset declaration must name UTF-8; conflicting, empty, or
unsupported declarations return `Fail{UnsupportedCharset{}}`. Other parameters
are ignored. Other media types return `Fail{UnsupportedMediaType{}}`.

## Strict errors

Malformed percent escapes, including `%`, `%1`, and `%G1`, return
`Fail{InvalidPercent{}}`. The parser rejects the whole input rather than
returning partial pairs. This differs from WHATWG's forgiving treatment of
malformed escapes.

After percent decoding, each complete component must be valid UTF-8. Invalid
continuation bytes, truncated sequences such as `%E2%82`, overlong sequences,
surrogate code points, values above U+10FFFF, and input elements above 255 return
`Fail{InvalidUtf8{}}`. Decoding never inserts replacement characters or strips
a BOM. Raw and percent-encoded octets may contribute to the same character.
The small pure UTF-8 codec is separate so other data parsers and router work can
reuse it.

For a body decoder that also accepts multipart uploads, use
[`src/data/form.bend`](multipart.md). It returns ordered `Field` and `File`
parts while keeping this module's API unchanged.
