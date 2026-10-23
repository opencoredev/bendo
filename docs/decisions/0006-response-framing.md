# 0006: Buffered HTTP/1.1 response framing

BND-9 adds `Response.Res` and `WriteResponse.write(method, res)`. Bodies are
`List<&2, U32>` octets, following [0002](0002-bytes.md). `Response.text(status,
text)` UTF-8 encodes the text once. The writer counts the resulting octets,
not Bend characters. Invalid Unicode scalar values encode as U+FFFD.

## Framing table

Apply the rows in order. A representation is the octet sequence a matching
GET would have sent, including any content coding already applied.

| Method and status | Content-Length | Bytes after the first blank line |
| --- | --- | --- |
| Any method, 100–199 (including 101), or 204 | Omitted | None |
| CONNECT, 200–299 | Omitted | None; subsequent tunnel traffic belongs to the connection layer |
| Any method, 304, representation unknown | Omitted | None |
| Any method, 304, representation supplied | Exact representation octet count | None |
| Any method, 205 | `0` | None |
| HEAD, other statuses | Body octet count, as for GET | None |
| Other methods and statuses | Body octet count, including `0` for an empty body | Exact body octets |

The method comes from `Request.Method`; HEAD requires its `Head{}` constructor.
`Response.not_modified(headers, None{})` omits a 304 length. Passing
`Some{representation}` supplies the actual selected GET representation, not an
unchecked number. The writer derives its length and never sends those bytes.
The caller must select the same representation that GET would select; the
writer cannot establish cache or representation selection semantics.

[RFC 9110 §8.6](https://www.rfc-editor.org/rfc/rfc9110.html#section-8.6)
prohibits Content-Length on 1xx, 204, and successful CONNECT, and restricts
HEAD and 304 lengths to the corresponding GET representation.
[§9.3.2](https://www.rfc-editor.org/rfc/rfc9110.html#section-9.3.2) defines
HEAD; [§9.3.6](https://www.rfc-editor.org/rfc/rfc9110.html#section-9.3.6)
defines CONNECT. [§15.3.6](https://www.rfc-editor.org/rfc/rfc9110.html#section-15.3.6)
forbids content on 205. [RFC 9112 §6.3](https://www.rfc-editor.org/rfc/rfc9112.html#section-6.3)
sets message-body length precedence. This buffered writer uses Content-Length
where content is allowed and never uses chunked transfer coding.

## Model and validation

`Res{status, headers, body, representation}` stores a numeric status, an ordered
list of `Request.Header`, body octets, and an optional selected representation.
Status codes must be 100–599. Header names must be lowercase ASCII tokens;
values permit HTAB, visible ASCII, and obs-text, with no surrounding SP or HTAB.
These are the request header model's existing canonical validity rules.
Repeated application headers remain separate and keep their order.

`checked(method, res)` returns `Done{wire_bytes}` or
`Fail{InvalidResponse{}}`. It validates the status, every header, and the octets
in both the body and optional representation before serialization. CR, LF,
other forbidden control values, invalid names, or non-octet body elements reject
the whole response. No invalid field can introduce an extra response or an
earlier blank line. `write(method, res)` is the convenient total API: invalid
input becomes an empty 500 response with Content-Length 0. It applies the same
method rules to that fallback. Low-level serialization helpers assume a valid
response; applications should call `checked` or `write`.

The writer owns framing. It drops every supplied `content-length` and
`transfer-encoding`, even when the supplied value is correct. It then emits
exactly the length required by the table. This avoids duplicate lengths and
conflicting transfer coding. A syntactically invalid framing header still
fails validation before filtering; filtering is not a way to bypass validation.

The status line uses the [IANA HTTP status code registry](https://www.iana.org/assignments/http-status-codes/http-status-codes.xhtml)
consulted on 2026-10-22, including registered extension codes. Registry lifecycle
notes for 104 and 510 are not reason-phrase text. Unassigned codes, and reserved
codes without a registered phrase, use an empty reason phrase and retain the
required space after the status code (RFC 9112 §4). A reason phrase is never
supplied by application code.

## Scope and verification

Streaming and chunked responses arrive in M6.1. Connection persistence,
Connection handling, upgrade handoff, and tunnel traffic belong to M1.4 and
M6.3. This writer does not add `Connection: close`. The test-only byte server
closes each response and can demonstrate a 101 head, but does not implement a
WebSocket upgrade. Curl captures that 101 head and reports exit 52 because the
fixture closes without a final ordinary response; raw sockets verify the same
bytes directly. Production `src/serve.bend` remains unchanged in this ticket.
The legacy `Http.text` helper and its existing law are retained for its current
callers; new buffered responses use `Response.text` and `WriteResponse.write`.

`bun test tests/http-response.test.ts` compiles the pure API and a native byte
server. It compares the assigned status phrases to an independent expected
table, checks text and binary bodies, conflicting framing, invalid headers,
HEAD across every status, and exact curl/raw-socket heads for 101, 200, 204,
304 and 404. `bun run prove` checks the universal framing laws in `LAWS.bend`.

The universal head-safety and Content-Length proofs remain open in this progress
commit. The root `prove` and `check` gates fail; passing wire tests do not close
those claims. The HEAD and payload-equation proofs check separately with the
strict kernel.
