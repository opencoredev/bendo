# Multipart form bodies

Import `src/data/form.bend` to parse URL-encoded and multipart form bodies
through one API. Files stay in memory as octets, preserving arbitrary binary
content. Fields and metadata use strict UTF-8.

```python
import Base
import ../../src/data/form.bend as Form
import ../../src/data/multipart.bend as Multipart

def uploaded(content_type: String, body: List<&2, U32>) -> Result<&2, &2, Multipart.Error, List<&2, Multipart.Part>>:
  Form.parse_body_with_limits(content_type, body, Multipart.Limits{3145728, 4194304, 128, 8192})
```

This example allows files up to 3 MiB and a complete multipart body up to
4 MiB. Configure the server's `body_limit` above the expected body size as
well; its default is 1 MiB. The transport checks its limit before handing the
buffered body to the parser.

## API and results

`Form.parse_body(content_type: String, body: List<&2, U32>)` uses the defaults
below. `Form.parse_body_with_limits(content_type, body, limits)` configures
multipart limits. Both return
`Result<&2, &2, Multipart.Error, List<&2, Multipart.Part>>`.

Parts appear in arrival order, including repeated names:

- `Field{name: String, value: String}` contains decoded text.
- `File{name: String, filename: String, content_type: String, bytes: List<&2, U32>}`
  contains the original file octets. An empty filename still identifies a file.

`Multipart.parse(content_type, body)` and
`Multipart.parse_with_limits(content_type, body, limits)` accept multipart
only and return the same type. The unified dispatcher delegates URL-encoded
bodies to the existing parser and converts `Entry{key, value}` to
`Field{key, value}`. It preserves URL-encoded parameter acceptance, decoding,
and ordering. Original errors are wrapped as `Urlencoded{error: Url.Error}`;
`InvalidPercent`, `InvalidUtf8`, `UnsupportedMediaType`, and
`UnsupportedCharset` remain distinguishable. Multipart limits apply only to
multipart; use the transport limit to bound all request bodies. Existing
`Urlencoded.parse_body` callers and their result types stay unchanged.

## Limits

`Multipart.Limits{file_size, total_size, parts, header_size}` uses inclusive
`U32` limits. Zero is valid; a zero part limit still allows an empty multipart
body with an immediate closing delimiter.

| Setting | Default | Counts |
| --- | --- | --- |
| `file_size` | 1,048,576 (1 MiB) | Payload octets in each file |
| `total_size` | 2,097,152 (2 MiB) | Entire body, including framing, preamble, epilogue, fields and files |
| `parts` | 128 | Fields and files together |
| `header_size` | 8,192 | Each part's header bytes, including CRLFs and the empty terminating line; also the outer Content-Type in UTF-8 octets |

Exceeding any limit returns `Fail{TooLarge{}}`.
`Multipart.error_status(error)` maps `TooLarge` to 413 and other errors to 400.
The runnable [test server](../../tests/servers/multipart.bend) applies this
mapping to HTTP responses without changing the transport module.

The parser checks total size and octet validity before allocating its part
buffers, then checks the outer Content-Type size and grammar. After that it
checks parts in order. An over-limit body can therefore return `TooLarge`
before a malformed boundary is examined. No partial result is returned.

These are wire-byte limits, not resident-memory limits. Decision
[0002](../decisions/0002-bytes.md) measured roughly 16 bytes of native RAM per
octet for one buffered list. Parser buffers and decoded strings add overhead;
a 2 MiB body does not fit in 2 MiB of RAM. Fields are bounded by the total
limit, and files by both limits. Keep limits and upload concurrency small
when memory is constrained. This parser receives a buffered body; it does
not stream to disk.

## Accepted framing and metadata

The parser follows RFC 7578 and RFC 2046 section 5.1. The boundary parameter
is required exactly once. It accepts a token or quoted string, including
quoted-pair escapes. After unquoting, the boundary must contain 1–70 ASCII
`bchars` and cannot end in a space. Internal spaces require quoting. Boundary
matching is case-sensitive; media types, header names, disposition type and
parameter names match without ASCII case sensitivity.

The first delimiter can start at byte zero or follow a CRLF-terminated
preamble. Later delimiters require `\r\n--boundary`. The introducing CRLF is
framing and is excluded from payload bytes. Delimiter lines accept trailing
space or tab padding. A closing `--boundary--` may end at EOF or precede CRLF
and an ignored epilogue. Preamble and epilogue still count toward the total
limit and must contain octets. Prefix matches with an invalid delimiter suffix
stay in the payload. A final closing delimiter is mandatory.

Every part requires one `Content-Disposition: form-data` header and one
`name` parameter. Names and filenames may be empty and may contain Unicode.
Duplicate disposition headers, `name` or `filename` parameters, and duplicate
Content-Type headers are rejected. Unknown syntactically valid headers and
disposition parameters are ignored. Content-Type must have a token type and
subtype and well-formed parameters. Absent field Content-Type means
`text/plain`; absent file Content-Type becomes `application/octet-stream`.
An explicit file Content-Type is preserved after unfolding and trimming OWS.
Part headers may continue on lines beginning with SP or HTAB. Unfolding removes
only the CRLF and preserves the continuation whitespace (RFC 5322 section 2.2.3).
The part-header limit counts the original wire bytes, including folded CRLFs.

RFC 7578 section 4.2 prohibits the RFC 5987 `filename*` parameter in multipart
forms. Bendo rejects it, including when a plain filename is also present.
Use a UTF-8 `filename` parameter. Filenames are untrusted metadata; the parser
does not strip paths, sanitize names, or write files. Percent escapes in
names and filenames remain literal.

All text uses UTF-8. Explicit charset parameters must name UTF-8; `_charset_`
is an ordinary field and does not change decoding. File bytes are never text
decoded. `Content-Transfer-Encoding` is rejected; no base64 or other transfer
decoding occurs, and nested multipart is not recursively expanded.

## Malformed input and runtime behavior

Missing or invalid boundaries, absent final delimiters, bare LF header lines,
leading continuation lines, controls, invalid UTF-8 headers or fields, missing names,
ambiguous metadata and non-octet list elements return `Fail{Malformed{}}`.
Invalid binary UTF-8 inside a file is accepted unchanged.

Input-sized traversals use direct tail calls. The outer scanner uses fuel
from the input length; each step consumes at least one octet and may consume
a whole delimiter or header block. Prefix lookahead is bounded by the
70-byte boundary, so worst-case work is linear in body length. Transport
padding scans contain no new delimiter candidate. Payload buffers grow by
prepending and reverse once; they are never repeatedly concatenated. The
same pure code compiles to native and `.mjs`.

Run `bun test --timeout 30000 tests/multipart.test.ts` to exercise the native
HTTP fixture, a 2 MiB random binary upload with independent SHA-256 comparison,
limits, malformed framing and multi-MiB `.mjs` files and fields.
