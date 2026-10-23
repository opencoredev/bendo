# 0004: Strict request heads with an incremental byte parser

BND-7 uses `List<&2, U32>` octets as required by decision 0002. The pure
`parse` function returns `NeedMore`, `Rejected{ParseError}`, or
`Parsed{Req, rest}`. `rest` starts immediately after the empty header line;
body framing and pipelined requests belong to BND-8 and BND-11. Body bytes
are neither decoded nor validated by the request-head parser.

`feed(new_bytes, state)` retains an unfinished request line or header across
reads. Keep the returned state and feed only newly received bytes. A trailing
CR is incomplete. Bare LF, CR followed by anything but LF, NUL, forbidden
controls, DEL and values above 255 in the head are errors. Completed malformed
lines fail immediately, even before the final empty line arrives. There is no
header size limit here; BND-11 must enforce one before accumulating unbounded
input. The scanner runs once per input byte and reverses each completed line.

Methods are nonempty RFC 9110 `tchar` tokens and remain case-sensitive.
Standard uppercase methods get dedicated constructors; other tokens, including
lowercase spellings, become `Extension`. Headers use the same token grammar,
store lowercase ASCII names and retain all occurrences in arrival order.
Values permit HTAB, visible ASCII and obs-text (128–255). Only surrounding SP
and HTAB are trimmed. Obsolete line folding and whitespace before a colon are
rejected. Header syntax is checked here; Host requirements, conflicting framing
headers and other field semantics are connection-layer work.

The supported target forms are origin-form and `OPTIONS *`. Absolute-form and
CONNECT authority-form return `UnsupportedTarget`; this version is an origin
server parser, not a forward proxy. Origin-form starts with `/`, uses RFC 3986
path/query characters, and requires two hexadecimal digits after `%`.
Fragments, backslashes, raw non-ASCII and spaces are rejected. A path is the
raw target prefix before the first `?`; the optional query preserves later
question marks and distinguishes no query from an empty query. No percent
decoding occurs. HTTP versions are exactly `HTTP/1.0` and `HTTP/1.1`.

The request writer emits a canonical head with lowercase header names and one
SP after each colon. It does not add a body or framing fields. Its round-trip
contract applies to the independent `well_formed` predicate: canonical method
constructors, supported targets, lowercase token names, valid octet values and
no leading or trailing optional whitespace.
