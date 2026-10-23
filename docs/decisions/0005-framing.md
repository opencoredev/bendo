# 0005: Strict request body framing

Accepted for BND-8, Bend 2.0.38. This extends the request-head parser in
[0004](0004-request-parser.md) and the octet representation in
[0002](0002-bytes.md).

Bendo chooses framing once, after parsing the complete head. It feeds unconsumed
head bytes into the body reader before reading again. A successful read returns
the parsed request, the complete octet body, parsed trailers, and the unused
suffix. The connection shell currently passes the request and body to the
handler and closes after one response. It does not merge trailers into headers.

## Decision table

Every final response closes the connection, including successful responses in
this milestone. Errors have `Content-Length: 0` and `Connection: close`.
The raw-socket tests read until EOF and fail on timeout or reset before EOF.
Section references below are to [RFC 9112](https://www.rfc-editor.org/rfc/rfc9112)
unless marked [RFC 9110](https://www.rfc-editor.org/rfc/rfc9110).

| Input | Answer | Section |
| --- | --- | --- |
| Neither CL nor TE | Empty body; bytes after the head remain unused | 6.3, rule 6 |
| One decimal Content-Length | Read exactly that many octets, across reads | 6.2; 6.3, rule 5 |
| One TE field containing only `chunked` (case insensitive) | Decode chunks through the empty trailer line | 6.1; 7.1 |
| TE and CL together, even CL zero | 400 | 6.3, rule 3 |
| Repeated CL with differing values | 400 | 6.2; 6.3, rule 5 |
| Repeated identical CL or comma-separated CL | 400; choose rejection rather than normalization | 6.2; 6.3, rule 5 |
| Empty, non-digit, signed, leading `+`, or internally spaced CL | 400 | 6.2 (`1*DIGIT`) |
| Surrounding SP/HTAB on CL | Accept; the head parser removes field OWS | 5.1; RFC 9110 5.6.3 |
| CL above 4294967295 | 400; checked arithmetic, never wrap | 6.2 |
| TE with unknown/unsupported coding, including `gzip, chunked` | 400; this server supports only sole `chunked` | 6.1; 6.3, rule 4 |
| TE list with chunked not last | 400 | 6.1; 6.3, rule 4 |
| `chunked, chunked` or repeated TE fields | 400 | 6.1 |
| Any TE in HTTP/1.0 | 400 | 6.1 |
| Empty or invalid hexadecimal chunk size | 400 | 7.1 |
| Chunk size above 4294967295 | 400; checked arithmetic | 7.1 |
| Bare LF or missing CRLF after size or chunk data | 400 when detected; incomplete input returns 400 on EOF | 7.1 |
| Chunk-size/extension line above 8192 octets, including CRLF | 400 | 7.1.1 (recipient limits) |
| Invalid chunk extension grammar | 400; accept token and quoted-string values, ignore valid extensions | 7.1.1 |
| Trailer block above 8192 octets, including line endings | 400 | 7.1.2; RFC 9110 6.5 |
| Invalid trailer field syntax or forbidden trailer field | 400; never merge trailers into request headers | 7.1.2; RFC 9110 6.5.1 |
| CL or decoded chunked body above configured limit | 413 before buffering past the limit; chunk sizes checked against remaining budget | RFC 9110 15.5.14 |
| `Expect: 100-continue` on HTTP/1.1, framed body pending and no body octets received | Send `HTTP/1.1 100 Continue` before the next receive | RFC 9110 10.1.1 |
| Supported Expect with body octets already received, or no body/zero length | Omit interim response; finish reading or return final response | RFC 9110 10.1.1 |
| Unsupported or repeated Expect on HTTP/1.1 | 417 | RFC 9110 10.1.1; 15.5.18 |
| Expect on HTTP/1.0 | Ignore expectation | RFC 9110 10.1.1 |
| Premature EOF while a head/body/chunk/trailer is incomplete | 400 and close | 8; 6.3 |

The 400 policy for unsupported transfer codings is deliberately stricter than
RFC 9112 section 6.1's recommendation to send 501 for an unsupported coding.
It treats unsupported request framing as a connection error. Rejecting repeated
CL, including identical values, is explicitly allowed by section 6.3.

## Limits and API

`Serve.defaults(port)` sets a 1 MiB decoded body limit.
`Serve.serve_config(~app, Serve.Config{port, body_limit})` overrides it. The
handler is a closed template taking `Request.Req` and `List<&2, U32>` and
returning response octets. `Serve.serve(~app, port)` uses the default limit.
The HTTP parser retains incremental state; fixed-length reads use a countdown
and reverse accumulator, so a fragmented body is not rescanned or repeatedly
copied. The chunk decoder likewise carries state between reads.

The temporary connection shell caps head reads at 64 KiB, reads at most 4096
wire octets per receive, and has no idle timeout yet. BND-11 adds the response
writer and keep-alive/connection limits; BND-12 supplies the full server config;
BND-21 supplies body accessors on context. These follow-ups must retain the
framing decisions and the suffix rather than reinterpreting received bytes.

## Verification

`bun test tests/http-body.test.ts` compiles a native echo consumer and tests
these decisions through TCP. It compares binary bodies byte for byte, exercises
chunk extensions/trailers and split reads, waits for 100 before uploading,
and sends a 5,000,000-octet body in 1024-octet writes on one connection with a
6,000,000-octet configured limit. Each test has a 30-second maximum.
