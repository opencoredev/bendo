# HTTP laws

These laws cover the request parser, response framing, HTTP dates, conditional
requests, the response write deadline, media types and error responses. See
the [laws index](README.md) for how to read an entry and for the laws on other
areas.

## Request parsing

The parser reads a request head byte by byte. The central guarantee is
`request_head_roundtrip`: every well-formed request, written out in canonical
form, parses back to exactly the same request, with nothing left over.
"Well-formed" is `Request.well_formed`: a canonical method, a supported
origin-form target (or `OPTIONS *`) with valid percent escapes, lowercase token
header names and trimmed values of valid octets. Header lookup ignores ASCII
case and returns every value in arrival order.

These laws describe what happens to canonical input. They do not claim the
parser rejects every malformed head, or that it reads non-canonical spellings
the way RFC 9112 does; the conformance suite and the fuzzer cover that (see
[HTTP conformance](../http-conformance.md) and
[decision 0004](../decisions/0004-request-parser.md)).

- `request_head_roundtrip`: parsing the canonical serialization of any well-formed request gives back that request and no leftover bytes.
- `parsed_request_line_path`: for every well-formed request line, the parsed path is the raw target up to its first `?`.
- `path_of_request_line`: one fixed example, kept from the first milestone: `Http.path_of` reads `/todos/42` from `GET /todos/42 HTTP/1.1`.
- `header_lookup_case_insensitive`: two header names with the same ASCII lowercase spelling look up exactly the same values, in the same order, in any header list.
- `fold_matches_letter_table`: `Bytes.fold`, which lowercases header names, equals an independent fold for every string: each of the 26 capital letters A to Z becomes its small letter and every other character, non-ASCII included, is kept. The specification is a written-out table of the 26 letter pairs in `proof/fold-spec.bend`, not Base's numeric `Char.to_lower` that `Bytes.fold` calls, so a wrong range or offset there would break the law.
- `header_lookup_all_in_order`: a lookup returns every value of every header with that name, in arrival order, matching an independent filter-then-project definition.
- `header_line_roundtrip`: a valid canonical header line `name: value` parses to that header, name and octets unchanged.
- `text_body_after_blank`: `Http.text(body)` is a head with no blank line in it, then a blank line, then the body, so a client that cuts at the first blank line reads the body back.

The remaining laws in this group are the steps of the round-trip proof. They
are stated as laws so each step is checked on its own, and each holds for every
input that meets its condition.

- `line_recover`: a valid request line, serialized, parses back to its method, path, query and version.
- `target_recover`: a valid target is free of spaces, splits back into path and query, and parses back to the same request fields.
- `target_prefix`: in a valid target, the first `?` comes right after the whole path.
- `split_path`: splitting a space-free path followed by its serialized query recovers both parts.
- `uri_path_clear`: a valid raw path contains no `?`.
- `uri_printable`, `target_printable`, `line_printable`: valid URI text, a valid target and a valid request line all serialize to printable ASCII bytes.
- `uri_char_not_space`, `uri_free`: no accepted URI character is a space, so valid URI text, percent escapes included, contains no space.
- `split_free`, `split_token_tail`, `split_method`: splitting at the space after a space-free prefix, a token or a serialized method keeps that prefix whole.
- `tchar_not_space`, `tchar_printable`: an HTTP token character is never a space and is always printable ASCII.
- `printable_value_octet`: every printable ASCII byte is allowed in a header value.
- `field_token_char`, `header_token_char`: a token character extends the header name being read and starts a header field, never folded whitespace.
- `field_token_tail`, `header_name_split`: a serialized token name splits at the colon that follows it, giving back the whole name.
- `header_field_valid`: a valid name and value normalize to the lowercase name and the trimmed value.
- `header_fields`: a valid canonical header parses back without any normalization change.
- `trim_start_identity`, `trim_identity`: a value with no whitespace at its start, or at either end, is unchanged by trimming.
- `advance_request`, `advance_header`: a printable request-line byte or a valid header byte is added to the line buffer.
- `scan_request_line`, `scan_request_line_acc`: scanning a printable line up to CRLF hands exactly that line to request-line parsing and keeps the bytes after it.
- `scan_header_line`, `scan_header_line_acc`: the same for a header line of valid bytes.
- `header_bytes`, `header_suffix`: a written header is its content, CRLF, then whatever follows, and appending bytes after it only extends that suffix.
- `scan_header`, `scan_header_octets`: scanning one written valid header adds that header and continues with the rest.
- `scan_headers`, `scan_headers_octets`: scanning a written list of valid headers adds them all in order, then finishes the head.
- `header_scannable_valid`, `headers_scannable_valid`: every valid header, and every list of them, writes bytes the scanner accepts.
- `value_append`, `printable_append`: joining two valid header values, or two printable byte lists, keeps the result valid or printable.
- `token_value`, `token_tail_value`, `token_printable`, `token_tail_printable`: a token, or a token tail, encodes to valid header-value bytes and to printable bytes.
- `token_tail_valid`: every valid nonempty token also passes the token-tail check.
- `method_text_token`, `method_recover`: every valid method writes as an HTTP token, and parsing that text gives back the same method.
- `append_assoc`: joining byte lists is associative.

## Response framing

`WriteResponse.write` turns a response into wire bytes. These laws check its
output against an independent response-head parser (`proof/response-spec.bend`)
that splits at the first blank line. Together they say a client always finds
the body where the head says it is: one `Content-Length` and no
`Transfer-Encoding` when a body is allowed, no body or length for 1xx and 204,
and for HEAD no body but a head identical to the GET head, `Content-Length`
included. See
[decision 0006](../decisions/0006-response-framing.md).

- `response_body_after_first_blank`: for any valid response with a body-bearing status to a method other than HEAD (and not a 2xx answer to CONNECT, which opens a tunnel), the bytes after the first blank line are exactly the body, and the head has exactly one `content-length` (the body's length) and no `transfer-encoding`, whatever the body contains.
- `response_forbidden_has_no_body_or_length`: for 1xx and 204 responses, to any method, nothing follows the blank line and the head has neither `content-length` nor `transfer-encoding`.
- `response_304_framing`: a valid 304 sends no payload and no `transfer-encoding`; it has one `content-length` exactly when the response carries a representation length, and that header counts the representation.
- `response_head_matches_get`: a HEAD response has the same head as the GET response for the same value, with nothing after it, and that head follows the independent framing table.
- `response_utf8_encode`: `Response.utf8`, the encoder behind text responses, produces bytes that the strict UTF-8 decoder reads back to the same string, for every string of Unicode scalar values.

## HTTP dates

The `Date` header and cache validators use IMF-fixdate (`Sun, 06 Nov 1994
08:49:37 GMT`). The laws cover every second from 1970-01-01 through the end of
9999, the range the formatter supports. See
[decision 0007](../decisions/0007-http-date.md).

- `http_date_roundtrip`: parsing the formatted date of any supported second gives back that second.
- `http_date_imf_spec`: the formatted text is the exact IMF-fixdate for that second, checked against a specification that shares no code with the codec. It counts the calendar day by day from 1970 with the century leap rules and the weekday from Thursday, so a wrong weekday cannot slip through the round trip.
- `http_date_parse_strict`: any text the parser accepts is exactly the formatted date of the second it returns, so malformed, obsolete and non-canonical dates are refused.

## Conditional requests and body limits

These laws pin the ETag middleware, `If-None-Match` matching, 304 construction
and the body size check to independent definitions in
`proof/limits-spec.bend`. See [request limits and response
caching](../limits-cache.md).

- `conditional_if_none_match_spec`: `If-None-Match` uses the RFC 9110 weak comparison for every field value and tag: every list member must be well formed, and any member that names the same opaque validator matches.
- `conditional_304_spec`: a 304 built from a response keeps only its cache metadata headers, in order and with duplicates, and drops the body, the representation length and the content and framing headers.
- `etag_middleware_spec`: the ETag middleware leaves every ineligible response untouched. An eligible buffered 200 response to GET or HEAD gets its body's validator and becomes exactly the 304 above when the request's `If-None-Match` matches it.
- `body_limit_spec`: the body limit accepts a length exactly when it is at most the limit, for every length.

## Response write deadline

A buffered response goes out in windows of the server's write timeout. These
laws pin the decision taken after each window that ends with bytes still
unsent: send another window only if the client accepted some of them during
this one. A client that keeps reading is never cut off, and one that stops
reading is closed. The socket loop around the decision is IO, covered by
`tests/write-deadline.test.ts`.
See [decision 0009](../decisions/0009-connections.md#write-deadline).

- `write_progress_continues`: a window that ends with fewer bytes unsent than it started with sends another window, for every count.
- `write_stall_closes`: a window that ends with no fewer bytes unsent than it started with closes the connection, for every count.
- `write_opening_continues`: the first send, which takes only what the socket accepts at once, always continues to a window.
- `write_timeout_default`: the default write timeout in `B.config()` is 30,000 ms.

## Media types and whitespace

Content-Type checks (CSRF, JSON bodies, error negotiation) read the media type
essence. These laws tie the shared helpers to independent grammars written
for BND-85.

- `media_essence_spec`: `Media.essence` returns the same essence as the independent definition for every value: the text before the first `;`, without surrounding spaces and tabs, in ASCII lowercase.
- `media_well_formed_spec`: `Media.well_formed` agrees with the independent media-type grammar for every value.
- `bytes_trim_spec`, `bytes_trim_text_spec`: trimming a header value removes exactly the leading and trailing spaces and tabs, for every byte list and every string.

## Error responses

When a handler fails with an `HttpError`, Bendo renders a 4xx or 5xx response
in JSON or text, picked from the request's `Accept` field. A private error
never leaks its internal message: two private errors with the same code produce
identical bytes. An exposed error shows its message exactly. If any header the
app added would make the response invalid, the client gets an empty 500 rather
than a malformed response. See [decision 0011](../decisions/0011-crash.md) and
[request context](../context.md).

- `http_error_private_message`: the public message of a private error is always `Internal Server Error`, whatever its internal text.
- `http_error_private_independent`, `http_error_private_wire_independent`: two private errors with the same code render the same response and the same wire bytes, whatever their messages, request, method and accumulated headers.
- `http_error_private_rendered`: with no accumulated headers, a private error renders exactly the specification's response: its code if it is 400 to 599, else 500, the negotiated `Content-Type`, `Vary: Accept` and the exact body.
- `http_error_private_accept_samples`: the same, end to end from the `Accept` field, for a set of representative fields whose outcome the documented policy fixes.
- `http_error_exposed_rendered`: an exposed 4xx or 5xx error carries its message exactly, as UTF-8 text or as escaped JSON; an empty message uses the reason phrase.
- `http_error_tea_only_rendered`: the documented `http_error(418, "Tea only")` example renders exactly as shown.
- `http_error_private_with_headers`, `http_error_exposed_with_headers`: with any accumulated headers, the client gets the negotiated `Content-Type` first, the other headers in order, then one `Vary` that keeps the existing values and adds `Accept` (or is `*`). If any of those headers is inadmissible the response is the empty 500.
- `http_error_invalid_header_fallback`: one example of that fallback: a header value containing a newline turns any error into the empty 500.
- `http_error_inadmissible_fallback`: whenever the effective header list is inadmissible, every error, exposed or private, renders the empty 500, so no invalid header byte reaches the wire.
- `http_error_validity_spec`: the framework's response validity check equals the independent one.
- `http_error_accept_policy`: JSON is chosen exactly as the documented `Accept` policy in `proof/accept-spec.bend` says, for every field value.
- `http_error_accept_field`: the field negotiation reads is the request's first `accept` header, decoded as UTF-8.
- `http_error_private_negotiated`, `http_error_exposed_negotiated`: end to end with no assumption about negotiation: for any request and accumulated headers, the rendered error is the specification's, in the representation the `Accept` policy picks.
- `http_error_head_no_payload`: an error response to HEAD is written with no payload.
