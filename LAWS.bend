# Bendo's laws. A human states each law; PROOF.bend proves it.
# Agents may add laws. Never delete or weaken one without a written reason
# in the pull request.
import Base
import ./src/app/route-schemas.bend as RouteSchemas
import ./src/app/manifest-schemas.bend as ManifestSchemas
import ./proof/manifest-schema-spec.bend as ManifestSchemaSpec
import ./src/data/json-schema.bend as JsonSchema
import ./proof/json-schema-spec.bend as JsonSchemaSpec
import ./src/data/schema-pattern.bend as SchemaPattern
import ./src/app/transport_response.bend as WebSocketTransport
import ./src/mw/etag.bend as ETag
import ./src/http/conditional.bend as Conditional
import ./src/mw/body_limit.bend as BodyLimit
import ./proof/limits-spec.bend as LimitsSpec
import ./src/app/manifest.bend as Manifest
import ./proof/manifest-spec.bend as ManifestSpec
import ./proof/manifest-built-spec.bend as ManifestBuiltSpec
import ./proof/compose-laws.bend as ComposeLaws
import ./proof/validate-laws.bend as ValidateLaws
import ./proof/plugin-laws.bend as PluginLaws

# BND-84
import ./proof/review-tail-laws.bend as ReviewTailLaws
import ./proof/tail-laws.bend as TailLaws
import ./proof/routing-stack-laws.bend as RoutingStackLaws
import ./proof/legacy-http-tail.bend as LegacyHttpTail
import ./proof/methods-tail.bend as MethodsTail
# BND-47
import ./proof/proxy-laws.bend as ProxyLaws

# BND-44
import ./proof/ip-laws.bend as IpLaws
import ./proof/rate-limit-laws.bend as RateLimitLaws

# BND-32
import ./proof/signed-cookie-laws.bend as SignedCookieLaws

# BND-31
import ./proof/cookie-ows-laws.bend as CookieOwsLaws
import ./proof/cookie-serialization-laws.bend as CookieSerializationLaws
import ./src/data/cookie.bend as Cookie
import ./proof/cookie-spec.bend as CookieSpec

# BND-25
import ./src/app/errors.bend as Errors
import ./proof/error-laws.bend as ErrorLaws

import ./src/app/table.bend as Table
import ./src/app/route-slot.bend as RouteSlot
import ./proof/middleware-selection-spec.bend as MiddlewareSelectionSpec
import ./proof/scoped-selection-spec.bend as ScopedSelectionSpec
import ./proof/scoped-assembly-spec.bend as AssemblySpec
import ./src/app/scopes.bend as Scopes
import ./src/app/middleware.bend as Middleware

import ./src/data/schema.bend as Schema
import ./src/data/schema-spec.bend as SchemaSpec
import ./src/data/json.bend as Json
import ./src/http/response.bend as Response
import ./src/http/write_response.bend as WriteResponse
import ./proof/response-spec.bend as ResponseSpec
import ./proof/response-framing-spec.bend as ResponseFramingSpec

import ./src/http/chunked.bend as Chunked
import ./src/http/stream_framing.bend as StreamFraming
import ./proof/stream-rfc-spec.bend as StreamRfc
import ./src/http/sse.bend as Sse
import ./proof/sse-spec.bend as SseSpec
import ./proof/sse-model.bend as SseModel
import ./src/http.bend as Http
import ./src/http/bytes.bend as Bytes
import ./src/http/request.bend as Request
import ./src/http/parse.bend as Parse
import ./src/http/write.bend as Write
import ./proof/support.bend as Support
import ./src/data/urlencoded.bend as Form
import ./src/data/utf8.bend as Utf8
import ./proof/forms.bend as FormSpec

import ./src/router/pattern.bend as Pattern
import ./src/router/constraint.bend as Constraint
import ./proof/router-match-spec.bend as MatchSpec

import ./src/router/spec.bend as Spec
import ./src/router/spec-proofs.bend as SpecProof

import ./src/router/methods.bend as Methods
import ./src/router/methods-proofs.bend as MethodProof

import ./src/router/trie.bend as Trie
import ./src/router/router.bend as Router

import ./src/data/hex.bend as Hex
import ./src/data/base64.bend as Base64
import ./src/crypto/octets.bend as Octets
import ./src/crypto/compare.bend as Compare
import ./src/crypto/hmac.bend as HMAC
import ./src/crypto/jwt.bend as Jwt
import ./proof/crypto-compare-spec.bend as CompareSpec
import ./proof/jwt-spec.bend as JwtSpec
import ./src/mw/csrf_policy.bend as CsrfPolicy
import ./proof/csrf-spec.bend as CsrfSpec
import ./src/mw/cors_policy.bend as CorsPolicy
import ./proof/cors-spec.bend as CorsSpec
import ./src/mw/cors_request.bend as CorsRequest
import ./src/mw/vary.bend as Vary
import ./src/mw/response_policy.bend as ResponsePolicy
import ./src/mw/secure_headers.bend as SecureHeaders
import ./proof/response-policy-spec.bend as ResponsePolicySpec
import ./proof/cors-response-spec.bend as CorsResponseSpec
import ./proof/secure-headers-spec.bend as SecureHeadersSpec
import ./src/mw/method_override_policy.bend as OverridePolicy
import ./proof/override-spec.bend as OverrideSpec
import ./src/mw/trailing_slash_policy.bend as TrailingPolicy
import ./proof/trailing-spec.bend as TrailingSpec

import ./src/http/date.bend as HttpDate
import ./src/http/websocket.bend as WebSocket
import ./proof/websocket-spec.bend as WebSocketSpec
import ./proof/date-spec.bend as HttpDateSpec

# BND-45
import ./src/static/path.bend as StaticPath
import ./proof/static-spec.bend as StaticSpec

# BND-51
import ./proof/ws-frame-laws.bend as WsFrameLaws

# LAW: a text response is a head with no blank line in it, then a blank
# line, then the body. So the first blank line in the response is the one
# that ends the head, and a client that cuts there reads the body back.
law text_body_after_blank:
  for +body: String
  exs head: String
  {String.contains(head, "\r\n\r\n") == False{} : Bool} & {head ++ ("\r\n\r\n" ++ body) == Http.text(body) : String}

# LAW: path_of reads the target of a request line. A single example for
# retained alongside the universal BND-7 request-line law below.
law path_of_request_line:
  {Http.path_of("GET /todos/42 HTTP/1.1\r\nHost: x\r\n\r\n") == "/todos/42" : String}

# BND-7: universal request-head guarantees.

# Every structurally well-formed request survives canonical serialization.
# well_formed independently checks canonical methods, supported raw targets,
# lowercase token names and trimmed valid octet values (request.bend).
law request_head_roundtrip:
  for +req: Request.Req
  for valid: {Request.well_formed(req) == True{} : Bool}
  {Parse.parse(Write.write(req)) == Request.Parsed{req, []} : Request.ParseResult}

# ASCII case variants are precisely names with the same ASCII lowercase
# spelling. For every header list and every such pair, all values and their
# order are unchanged. This even holds for names not present in the list.
law header_lookup_case_insensitive:
  for +headers: List<&2, Request.Header>
  for +name: String
  for +variant: String
  for same: {Bytes.fold(name) == Bytes.fold(variant) : String}
  {Request.lookup(headers, name) == Request.lookup(headers, variant) : List<&2, List<&2, U32>>}

# Lookup returns precisely every matching header value in arrival order.
# The independent specification selects headers by the folded lookup name,
# then projects their values. This holds for every list, including all valid
# canonical header lists stored by the parser, and every lookup name.
law header_lookup_all_in_order:
  for +headers: List<&2, Request.Header>
  for +name: String
  {Request.lookup(headers, name) == Support.matching_values(headers, name) : List<&2, List<&2, U32>>}

# Every well-formed request line, not an example: its parsed path is exactly
# the raw target prefix ending at its first '?'. The independent target
# predicate covers origin-form and OPTIONS *, with valid percent escapes.
law parsed_request_line_path:
  for +method: Request.Method
  for +path: String
  for +query: Maybe<&2, String>
  for +version: Request.Version
  for valid: {Request.well_formed(Request.Req{method, path, query, version, []}) == True{} : Bool}
  {Parse.request_line(Write.line_content(method, path, query, version)) == Parse.Headers{Request.Req{method, Bytes.prefix(path ++ Request.query_text(query)), query, version, []}, [], False{}} : Parse.State}

# Every valid canonical header line restores its name and octet value.
law header_line_roundtrip:
  for +req: Request.Req
  for +name: String
  for +value: List<&2, U32>
  for +valid: {Request.header_valid(Request.Header{name, value}) == True{} : Bool}
  {Parse.header_line(req, Bytes.append(Bytes.encode(name), 58 <> 32 <> value)) == Parse.push_header(req, Request.Header{name, value}) : Parse.State}

# BND-7 lemmas (proof support)

# Valid URI text serializes to printable request-line bytes.
law uri_printable:
  for +s: String
  for +q: Bool
  for +ok: {Bytes.uri(s, q) == True{} : Bool}
  {Support.printable(Bytes.encode(s)) == True{} : Bool}

# Every well-formed target serializes to printable bytes.
law target_printable:
  for +m: Request.Method
  for +p: String
  for +q: Maybe<&2, String>
  for +ok: {Request.target_valid(m, p, q) == True{} : Bool}
  {Support.printable(Bytes.encode(p ++ Request.query_text(q))) == True{} : Bool}

# A well-formed request line serializes entirely to printable bytes.
law line_printable:
  for +m: Request.Method
  for +p: String
  for +q: Maybe<&2, String>
  for +v: Request.Version
  for +mv: {Request.method_valid(m) == True{} : Bool}
  for +tv: {Request.target_valid(m, p, q) == True{} : Bool}
  {Support.printable(Write.line_content(m, p, q, v)) == True{} : Bool}

# Accepted URI characters cannot be spaces.
law uri_char_not_space:
  for +c: U32
  for +q: Bool
  for ok: {Bytes.uri_char(c, q) == True{} : Bool}
  {Char.is_eq(Chr{c}, ' ') == False{} : Bool}

# Valid URI text contains no spaces, including percent escapes.
law uri_free:
  for +s: String
  for +q: Bool
  for +ok: {Bytes.uri(s, q) == True{} : Bool}
  {Support.free(s) == True{} : Bool}

# Splitting after a space-free prefix preserves the whole prefix.
law split_free:
  for +s: String
  for +rest: String
  for +ok: {Support.free(s) == True{} : Bool}
  {String.split(s ++ " " ++ rest, ' ') == s <> String.split(rest, ' ') : List<&2, String>}

# A valid raw path contains no query delimiter.
law uri_path_clear:
  for +s: String
  for +ok: {Bytes.uri(s, False{}) == True{} : Bool}
  {Support.path_clear(s) == True{} : Bool}

# Splitting a path and serialized query recovers both components.
law split_path:
  for +p: String
  for +q: Maybe<&2, String>
  for +ok: {Support.path_clear(p) == True{} : Bool}
  {Bytes.split_target(p ++ Request.query_text(q)) == (p, q) : String & Maybe<&2, String>}

# A header token character is never the colon delimiter.
law field_token_char:
  for +c: U32
  for +rest: List<&2, U32>
  for ok: {Bytes.tchar(c) == True{} : Bool}
  {Parse.field(c <> rest) == Parse.field_push(c, Parse.field(rest)) : Parse.Field}

# A token character starts a header field rather than folded whitespace.
law header_token_char:
  for +r: Request.Req
  for +c: U32
  for +rest: List<&2, U32>
  for ok: {Bytes.tchar(c) == True{} : Bool}
  {Parse.header_line(r, c <> rest) == Parse.header_field(r, Parse.field(c <> rest)) : Parse.State}

# Splitting a serialized token name recovers the complete name.
law field_token_tail:
  for +name: String
  for +value: List<&2, U32>
  for +ok: {Bytes.token_tail(name) == True{} : Bool}
  {Parse.field(Bytes.append(Bytes.encode(name), 58 <> value)) == Parse.Field{name, value} : Parse.Field}

# A value without leading whitespace needs no leading trim.
law trim_start_identity:
  for +xs: List<&2, U32>
  for ok: {Request.value_start(xs) == True{} : Bool}
  {Bytes.trim_start(xs) == xs : List<&2, U32>}

# Two accumulator reversals compose by appending their inputs.
law reverse_go_twice:
  for -A: Data
  for xs: List<&2, A>
  for ys: List<&2, A>
  for zs: List<&2, A>
  {List.reverse.go(&2, A, List.reverse.go(&2, A, xs, ys), zs) == List.reverse.go(&2, A, ys, List.append(&2, A, xs, zs)) : List<&2, A>}

# Appending an empty list preserves the list.
law append_nil:
  for -A: Data
  for xs: List<&2, A>
  {List.append(&2, A, xs, []) == xs : List<&2, A>}

# Reversing a list twice restores its original order.
law reverse_twice:
  for -A: Data
  for +xs: List<&2, A>
  {List.reverse(&2, A, List.reverse(&2, A, xs)) == xs : List<&2, A>}

# A value trimmed at both ends is unchanged by trimming.
law trim_identity:
  for +xs: List<&2, U32>
  for start: {Request.value_start(xs) == True{} : Bool}
  for end: {Request.value_start(List.reverse(&2, U32, xs)) == True{} : Bool}
  {Bytes.trim(xs) == xs : List<&2, U32>}

# Valid field components normalize to the expected header.
law header_field_valid:
  for +r: Request.Req
  for +name: String
  for +raw: List<&2, U32>
  for token: {Bytes.token(name) == True{} : Bool}
  for value: {Bytes.value(raw) == True{} : Bool}
  {Parse.header_field(r, Parse.Field{name, raw}) == Parse.push_header(r, Request.Header{Bytes.fold(name), Bytes.trim(raw)}) : Parse.State}

# A serialized valid header name splits at its following colon.
law header_name_split:
  for +r: Request.Req
  for +name: String
  for +raw: List<&2, U32>
  for +token: {Bytes.token(name) == True{} : Bool}
  {Parse.header_line(r, Bytes.append(Bytes.encode(name), 58 <> raw)) == Parse.header_field(r, Parse.Field{name, raw}) : Parse.State}

# A valid canonical header reconstructs without normalization changes.
law header_fields:
  for +r: Request.Req
  for +name: String
  for +value: List<&2, U32>
  for +ok: {Request.header_valid(Request.Header{name, value}) == True{} : Bool}
  {Parse.header_line(r, Bytes.append(Bytes.encode(name), 58 <> 32 <> value)) == Parse.push_header(r, Request.Header{name, value}) : Parse.State}

# Every valid target is space-free and reconstructs its parsed fields.
law target_recover:
  for +m: Request.Method
  for +p: String
  for +q: Maybe<&2, String>
  for +v: Request.Version
  for +ok: {Request.target_valid(m, p, q) == True{} : Bool}
  {Support.free(p ++ Request.query_text(q)) == True{} : Bool} & ({Bytes.split_target(p ++ Request.query_text(q)) == (p, q) : String & Maybe<&2, String>} & {Parse.target_form(m, p ++ Request.query_text(q), Request.version_text(v)) == Parse.Headers{Request.Req{m, p, q, v, []}, [], False{}} : Parse.State})

# A valid serialized request line restores all original fields.
law line_recover:
  for +m: Request.Method
  for +p: String
  for +q: Maybe<&2, String>
  for +v: Request.Version
  for +mv: {Request.method_valid(m) == True{} : Bool}
  for +tv: {Request.target_valid(m, p, q) == True{} : Bool}
  {Parse.request_line(Write.line_content(m, p, q, v)) == Parse.Headers{Request.Req{m, p, q, v, []}, [], False{}} : Parse.State}

# The first query delimiter follows the complete validated path.
law target_prefix:
  for +m: Request.Method
  for +p: String
  for +q: Maybe<&2, String>
  for +v: Request.Version
  for +tv: {Request.target_valid(m, p, q) == True{} : Bool}
  {Bytes.prefix(p ++ Request.query_text(q)) == p : String}

# A printable request byte advances the reverse line buffer.
law advance_request:
  for +c: U32
  for +rev: List<&2, U32>
  for ok: {Support.printable_octet(c) == True{} : Bool}
  {Parse.advance(Parse.RequestLine{rev, False{}}, c) == Parse.RequestLine{c <> rev, False{}} : Parse.State}

# A valid header byte advances the reverse line buffer.
law advance_header:
  for +r: Request.Req
  for +c: U32
  for +rev: List<&2, U32>
  for ok: {Bytes.value_octet(c) == True{} : Bool}
  {Parse.advance(Parse.Headers{r, rev, False{}}, c) == Parse.Headers{r, c <> rev, False{}} : Parse.State}

# Scanning a printable request line preserves its buffer and suffix.
law scan_request_line_acc:
  for +xs: List<&2, U32>
  for +rev: List<&2, U32>
  for +tail: List<&2, U32>
  for +ok: {Support.printable(xs) == True{} : Bool}
  {Parse.feed(Bytes.append(xs, 13 <> 10 <> tail), Parse.RequestLine{rev, False{}}) == Parse.feed(tail, Parse.request_line(List.reverse(&2, U32, List.reverse.go(&2, U32, xs, rev)))) : Parse.State & Request.ParseResult}

# Scanning a complete printable line invokes request-line parsing.
law scan_request_line:
  for +xs: List<&2, U32>
  for +tail: List<&2, U32>
  for ok: {Support.printable(xs) == True{} : Bool}
  {Parse.feed(Bytes.append(xs, 13 <> 10 <> tail), Parse.initial()) == Parse.feed(tail, Parse.request_line(xs)) : Parse.State & Request.ParseResult}

# Scanning a valid header line preserves its buffer and suffix.
law scan_header_line_acc:
  for +r: Request.Req
  for +xs: List<&2, U32>
  for +rev: List<&2, U32>
  for +tail: List<&2, U32>
  for +ok: {Bytes.value(xs) == True{} : Bool}
  {Parse.feed(Bytes.append(xs, 13 <> 10 <> tail), Parse.Headers{r, rev, False{}}) == Parse.feed(tail, Parse.header_line(r, List.reverse(&2, U32, List.reverse.go(&2, U32, xs, rev)))) : Parse.State & Request.ParseResult}

# Scanning a complete header line invokes header parsing.
law scan_header_line:
  for +r: Request.Req
  for +xs: List<&2, U32>
  for +tail: List<&2, U32>
  for ok: {Bytes.value(xs) == True{} : Bool}
  {Parse.feed(Bytes.append(xs, 13 <> 10 <> tail), Parse.Headers{r, [], False{}}) == Parse.feed(tail, Parse.header_line(r, xs)) : Parse.State & Request.ParseResult}

# Byte-list concatenation associates without changing bytes.
law append_assoc:
  for +xs: List<&2, U32>
  for +ys: List<&2, U32>
  for +zs: List<&2, U32>
  {Bytes.append(Bytes.append(xs, ys), zs) == Bytes.append(xs, Bytes.append(ys, zs)) : List<&2, U32>}

# A written header consists of its content, CRLF and suffix.
law header_bytes:
  for +h: Request.Header
  for +tail: List<&2, U32>
  {Write.header(h, tail) == Bytes.append(Support.header_content(h), 13 <> 10 <> tail) : List<&2, U32>}

# Scanning a valid serialized header pushes that header.
law scan_header_octets:
  for +r: Request.Req
  for +h: Request.Header
  for +tail: List<&2, U32>
  for +ok: {Request.header_valid(h) == True{} : Bool}
  for bytes: {Bytes.value(Support.header_content(h)) == True{} : Bool}
  {Parse.feed(Write.header(h, tail), Parse.Headers{r, [], False{}}) == Parse.feed(tail, Parse.push_header(r, h)) : Parse.State & Request.ParseResult}

# Appending bytes after a written header extends only its suffix.
law header_suffix:
  for +h: Request.Header
  for +body: List<&2, U32>
  for +tail: List<&2, U32>
  {Bytes.append(Write.header(h, body), tail) == Write.header(h, Bytes.append(body, tail)) : List<&2, U32>}

# Scanning written headers accumulates them in arrival order.
law scan_headers_octets:
  for +hs: List<&2, Request.Header>
  for +m: Request.Method
  for +p: String
  for +q: Maybe<&2, String>
  for +v: Request.Version
  for +acc: List<&2, Request.Header>
  for +tail: List<&2, U32>
  for +ok: {Request.headers_valid(hs) == True{} : Bool}
  for +bytes: {Support.headers_scannable(hs) == True{} : Bool}
  {Parse.feed(Bytes.append(Write.headers(hs), tail), Parse.Headers{Request.Req{m, p, q, v, acc}, [], False{}}) == Parse.feed(tail, Parse.finish(Request.Req{m, p, q, v, List.reverse.go(&2, Request.Header, hs, acc)})) : Parse.State & Request.ParseResult}

# Every HTTP token character is printable ASCII.
law tchar_printable:
  for +c: U32
  for ok: {Bytes.tchar(c) == True{} : Bool}
  {Support.printable_octet(c) == True{} : Bool}

# Printable ASCII is accepted inside a header value.
law printable_value_octet:
  for +c: U32
  for ok: {Support.printable_octet(c) == True{} : Bool}
  {Bytes.value_octet(c) == True{} : Bool}

# Concatenating valid header values preserves byte validity.
law value_append:
  for +xs: List<&2, U32>
  for +ys: List<&2, U32>
  for +xok: {Bytes.value(xs) == True{} : Bool}
  for +yok: {Bytes.value(ys) == True{} : Bool}
  {Bytes.value(Bytes.append(xs, ys)) == True{} : Bool}

# A token tail serializes to valid header-value bytes.
law token_tail_value:
  for +s: String
  for +ok: {Bytes.token_tail(s) == True{} : Bool}
  {Bytes.value(Bytes.encode(s)) == True{} : Bool}

# A token serializes to valid header-value bytes.
law token_value:
  for +s: String
  for +ok: {Bytes.token(s) == True{} : Bool}
  {Bytes.value(Bytes.encode(s)) == True{} : Bool}

# Every valid canonical header has scannable wire content.
law header_scannable_valid:
  for +h: Request.Header
  for +ok: {Request.header_valid(h) == True{} : Bool}
  {Bytes.value(Support.header_content(h)) == True{} : Bool}

# Every valid header list has scannable wire content.
law headers_scannable_valid:
  for +hs: List<&2, Request.Header>
  for +ok: {Request.headers_valid(hs) == True{} : Bool}
  {Support.headers_scannable(hs) == True{} : Bool}

# A valid header alone suffices to prove its scanner reconstruction.
law scan_header:
  for +r: Request.Req
  for +h: Request.Header
  for +tail: List<&2, U32>
  for +ok: {Request.header_valid(h) == True{} : Bool}
  {Parse.feed(Write.header(h, tail), Parse.Headers{r, [], False{}}) == Parse.feed(tail, Parse.push_header(r, h)) : Parse.State & Request.ParseResult}

# A valid header list alone suffices to prove scanner reconstruction.
law scan_headers:
  for +hs: List<&2, Request.Header>
  for +m: Request.Method
  for +p: String
  for +q: Maybe<&2, String>
  for +v: Request.Version
  for +acc: List<&2, Request.Header>
  for +tail: List<&2, U32>
  for +ok: {Request.headers_valid(hs) == True{} : Bool}
  {Parse.feed(Bytes.append(Write.headers(hs), tail), Parse.Headers{Request.Req{m, p, q, v, acc}, [], False{}}) == Parse.feed(tail, Parse.finish(Request.Req{m, p, q, v, List.reverse.go(&2, Request.Header, hs, acc)})) : Parse.State & Request.ParseResult}

# Concatenating printable byte lists preserves printability.
law printable_append:
  for +xs: List<&2, U32>
  for +ys: List<&2, U32>
  for +xok: {Support.printable(xs) == True{} : Bool}
  for +yok: {Support.printable(ys) == True{} : Bool}
  {Support.printable(Bytes.append(xs, ys)) == True{} : Bool}

# A token tail serializes to printable request-line bytes.
law token_tail_printable:
  for +s: String
  for +ok: {Bytes.token_tail(s) == True{} : Bool}
  {Support.printable(Bytes.encode(s)) == True{} : Bool}

# A token serializes to printable request-line bytes.
law token_printable:
  for +s: String
  for +ok: {Bytes.token(s) == True{} : Bool}
  {Support.printable(Bytes.encode(s)) == True{} : Bool}

# A true conjunction has a true left operand.
law and_left:
  for a: Bool
  for b: Bool
  for e: {a && b == True{} : Bool}
  {a == True{} : Bool}

# A true conjunction has a true right operand.
law and_right:
  for a: Bool
  for b: Bool
  for e: {a && b == True{} : Bool}
  {b == True{} : Bool}

# An equal word comparison has an equal tail comparison.
law cmp_fin_tail:
  for a: Bool
  for b: Bool
  for c: Cmp
  for e: {Cmp.is_eq(Word.cmp.fin(a, b, c)) == True{} : Bool}
  {Cmp.is_eq(c) == True{} : Bool}

# A word compares equal to itself.
law word_cmp_self:
  for +n: Nat
  for +a: Word(n)
  {Word.cmp(n, a, a) == EQ{} : Cmp}

# A successful word equality test supplies an equality proof.
law word_eq_sound:
  for +n: Nat
  for +a: Word(n)
  for +b: Word(n)
  for +e: {Cmp.is_eq(Word.cmp(n, a, b)) == True{} : Bool}
  {a == b : Word(n)}

# A successful U32 equality test supplies an equality proof.
law u32_eq_sound:
  for +a: U32
  for +b: U32
  for +e: {U32.is_eq(a, b) == True{} : Bool}
  {a == b : U32}

# An equal string comparison has an equal character comparison.
law cmp_step_tail:
  for a: String
  for b: String
  for c: Cmp
  for e: {Cmp.is_eq(String.order.go(a, b, c)) == True{} : Bool}
  {Cmp.is_eq(c) == True{} : Bool}

# A successful string equality test supplies an equality proof.
law string_eq_sound:
  for +a: String
  for +b: String
  for +e: {String.eq(a, b) == True{} : Bool}
  {a == b : String}

# HTTP token characters cannot be spaces.
law tchar_not_space:
  for +c: U32
  for ok: {Bytes.tchar(c) == True{} : Bool}
  {Char.is_eq(Chr{c}, ' ') == False{} : Bool}

# A token prefix splits only at the appended separator.
law split_token_tail:
  for +s: String
  for +rest: String
  for +ok: {Bytes.token_tail(s) == True{} : Bool}
  {String.split(s ++ " " ++ rest, ' ') == s <> String.split(rest, ' ') : List<&2, String>}

# Every valid method serializes to an HTTP token.
law method_text_token:
  for +method: Request.Method
  for ok: {Request.method_valid(method) == True{} : Bool}
  {Bytes.token(Request.method_text(method)) == True{} : Bool}

# A valid nonempty token also satisfies token-tail validation.
law token_tail_valid:
  for +s: String
  for ok: {Bytes.token(s) == True{} : Bool}
  {Bytes.token_tail(s) == True{} : Bool}

# A serialized method splits from the rest of the request line.
law split_method:
  for +method: Request.Method
  for +rest: String
  for ok: {Request.method_valid(method) == True{} : Bool}
  {String.split(Request.method_text(method) ++ " " ++ rest, ' ') == Request.method_text(method) <> String.split(rest, ' ') : List<&2, String>}

# Parsing canonical method text restores its method constructor.
law method_recover:
  for +m: Request.Method
  for +ok: {Request.method_valid(m) == True{} : Bool}
  {Request.method(Request.method_text(m)) == m : Request.Method}

# BND-14

# Every successfully compiled pattern roundtrips every independently admissible
# ordered assignment. Admissibility checks exactly the capture names in order,
# nonempty present non-wildcard values, constraints and Unicode scalars; only a
# trailing chain of optional captures may be omitted, and a wildcard may hold
# an empty value.
# It never invokes fill or match_path. Both filling success and matching success
# are promised, so a filler that always fails cannot satisfy this law.
law pattern_fill_match:
  for +source: String
  for +pattern: Pattern.Pattern
  for compiled: {Pattern.compile(source) == Done{pattern} : Result<&2, &2, Pattern.PatternError, Pattern.Pattern>}
  for +params: Pattern.Params
  for admitted: {Pattern.admissible(pattern, params) == True{} : Bool}
  exs path: String
  {Pattern.fill(pattern, params) == Some{path} : Maybe<&2, String>} & {Pattern.match_path(pattern, path) == Some{params} : Maybe<&2, Pattern.Params>}

# BND-78

# Matching is exactly the independent raw-path specification in
# proof/router-match-spec.bend, for every pattern value and every raw path:
# the same hit or miss, the same ordered captures, and the same precedence
# (optional captures take present segments, interior wildcards take the fewest
# segments, spans take the most). The specification calls no Pattern helper.
law pattern_match_spec:
  for +pattern: Pattern.Pattern
  for +path: String
  {Pattern.match_path(pattern, path) == MatchSpec.match_path(pattern, path) : Maybe<&2, Pattern.Params>}

# Each promised syntax form compiles, to the segments the specification reads.
law compile_bare_star:
  {Pattern.compile("*") == Done{Pattern.Pattern{[Pattern.Wildcard{"*"}]}} : Result<&2, &2, Pattern.PatternError, Pattern.Pattern>}

law compile_prefix_wildcard:
  {Pattern.compile("/assets*") == Done{Pattern.Pattern{[Pattern.PrefixWildcard{"assets"}]}} : Result<&2, &2, Pattern.PatternError, Pattern.Pattern>}

law compile_interior_wildcards:
  {Pattern.compile("/a/*/b/*") == Done{Pattern.Pattern{[Pattern.Static{"a"}, Pattern.InteriorWildcard{}, Pattern.Static{"b"}, Pattern.Wildcard{"*"}]}} : Result<&2, &2, Pattern.PatternError, Pattern.Pattern>}

law compile_optional_chain:
  {Pattern.compile("/v1/:version?/:platform?") == Done{Pattern.Pattern{[Pattern.Static{"v1"}, Pattern.Capture{"version", Constraint.Any{}, True{}}, Pattern.Capture{"platform", Constraint.Any{}, True{}}]}} : Result<&2, &2, Pattern.PatternError, Pattern.Pattern>}

law compile_static_colon:
  {Pattern.compile("/v1/name:activate") == Done{Pattern.Pattern{[Pattern.Static{"v1"}, Pattern.Static{"name:activate"}]}} : Result<&2, &2, Pattern.PatternError, Pattern.Pattern>}

law compile_anchored_span:
  {Pattern.compile("/:prefix{.+}/contents/:id?") == Done{Pattern.Pattern{[Pattern.Span{"prefix"}, Pattern.Static{"contents"}, Pattern.Capture{"id", Constraint.Any{}, True{}}]}} : Result<&2, &2, Pattern.PatternError, Pattern.Pattern>}

# A span needs a static anchor after it.
law compile_unanchored_span:
  {Pattern.compile("/:a{.+}/:b") == Fail{Pattern.PatternError{Pattern.InvalidSpan{}, ":a{.+}/:b"}} : Result<&2, &2, Pattern.PatternError, Pattern.Pattern>}

# The specification gives the promised raw-path results for those forms.
law spec_prefix_wildcard:
  {MatchSpec.match_path(Pattern.Pattern{[Pattern.PrefixWildcard{"assets"}]}, "/assets-v2") == Some{Nil{}} : Maybe<&2, Pattern.Params>} & {MatchSpec.match_path(Pattern.Pattern{[Pattern.PrefixWildcard{"assets"}]}, "/assets/app.js") == Some{Nil{}} : Maybe<&2, Pattern.Params>}

law spec_interior_wildcards:
  {MatchSpec.match_path(Pattern.Pattern{[Pattern.Static{"a"}, Pattern.InteriorWildcard{}, Pattern.Static{"b"}, Pattern.Wildcard{"*"}]}, "/a/x/y/b/c/d") == Some{[Pattern.Param{"*", "c/d"}]} : Maybe<&2, Pattern.Params>}

law spec_optional_chain:
  {MatchSpec.match_path(Pattern.Pattern{[Pattern.Static{"v1"}, Pattern.Capture{"version", Constraint.Any{}, True{}}, Pattern.Capture{"platform", Constraint.Any{}, True{}}]}, "/v1/x") == Some{[Pattern.Param{"version", "x"}]} : Maybe<&2, Pattern.Params>}

law spec_greedy_span:
  {MatchSpec.match_path(Pattern.Pattern{[Pattern.Span{"prefix"}, Pattern.Static{"contents"}, Pattern.Capture{"id", Constraint.Any{}, True{}}]}, "/foo/bar/contents/123") == Some{[Pattern.Param{"prefix", "foo/bar"}, Pattern.Param{"id", "123"}]} : Maybe<&2, Pattern.Params>} & {MatchSpec.match_path(Pattern.Pattern{[Pattern.Span{"prefix"}, Pattern.Static{"contents"}, Pattern.Capture{"id", Constraint.Any{}, True{}}]}, "/a/contents/contents") == Some{[Pattern.Param{"prefix", "a/contents"}]} : Maybe<&2, Pattern.Params>}

# BND-29: URL-encoded data and ordered repeated-key lookup.

# Every String of Unicode scalar values survives query-component encoding.
# Utf8.valid is the independent Unicode range/surrogate predicate.
law query_component_roundtrip:
  for +s: String
  for +valid: {Utf8.valid(s) == True{} : Bool}
  {Form.decode(Form.encode(s)) == Done{s} : Result<&2, &2, Form.Error, String>}

# Every String of Unicode scalar values survives WHATWG form encoding,
# including space -> '+' and literal '+' -> '%2B'.
law form_component_roundtrip:
  for +s: String
  for +valid: {Utf8.valid(s) == True{} : Bool}
  {Form.decode_form(Form.encode_form(s)) == Done{s} : Result<&2, &2, Form.Error, String>}

# For every ordered list and key, lookup returns exactly all matching values,
# in order. The specification filters whole entries before projecting values.
law form_queries_all_in_order:
  for +pairs: List<&2, Form.Entry>
  for +key: String
  {Form.queries(pairs, key) == FormSpec.spec(pairs, key) : List<&2, String>}

# BND-15: universal reference-router guarantees.
# A returned hit matches the independently looked-up route, including its tag
# and ordered params. Every smaller registration index independently misses.
law router_sound:
  for -T: Data
  for +table: Spec.Table(T)
  for +path: String
  for +i: Nat
  for +tag: T
  for +params: Pattern.Params
  for returned: {Spec.route(T, table, path) == Some{Spec.Match{i, tag, params}} : Maybe<&2, Spec.Match<T>>}
  {SpecProof.match_at(T, table, path, i) == Some{SpecProof.At{tag, params}} : Maybe<&2, SpecProof.AtMatch<T>>} & SpecProof.NoEarlier(T, table, path, i)

# Every independently matching entry guarantees a returned hit no later than
# that entry. This quantifies over every table, path, index, tag and assignment.
law router_complete:
  for -T: Data
  for +table: Spec.Table(T)
  for +path: String
  for +i: Nat
  for +tag: T
  for +params: Pattern.Params
  for matched: {SpecProof.match_at(T, table, path, i) == Some{SpecProof.At{tag, params}} : Maybe<&2, SpecProof.AtMatch<T>>}
  exs hit: Spec.Match<T>
  {Spec.route(T, table, path) == Some{hit} : Maybe<&2, Spec.Match<T>>} & {Nat.is_le(SpecProof.index(T, hit), i) == True{} : Bool}

# When no smaller index matches, matching at i returns exactly that index,
# tag and ordered params, even if later routes also match.
law router_first_match:
  for -T: Data
  for +table: Spec.Table(T)
  for +path: String
  for +i: Nat
  for +tag: T
  for +params: Pattern.Params
  for matched: {SpecProof.match_at(T, table, path, i) == Some{SpecProof.At{tag, params}} : Maybe<&2, SpecProof.AtMatch<T>>}
  for earlier: SpecProof.NoEarlier(T, table, path, i)
  {Spec.route(T, table, path) == Some{Spec.Match{i, tag, params}} : Maybe<&2, Spec.Match<T>>}

# If A and B both match and A precedes B, the winner is no later than A,
# and strictly before B. Routes preceding A remain eligible to win.
law router_priority:
  for -T: Data
  for +table: Spec.Table(T)
  for +path: String
  for +a: Nat
  for +b: Nat
  for +tag_a: T
  for +params_a: Pattern.Params
  for +tag_b: T
  for +params_b: Pattern.Params
  for a_matches: {SpecProof.match_at(T, table, path, a) == Some{SpecProof.At{tag_a, params_a}} : Maybe<&2, SpecProof.AtMatch<T>>}
  for b_matches: {SpecProof.match_at(T, table, path, b) == Some{SpecProof.At{tag_b, params_b}} : Maybe<&2, SpecProof.AtMatch<T>>}
  for before: {Nat.is_lt(a, b) == True{} : Bool}
  exs hit: Spec.Match<T>
  {Spec.route(T, table, path) == Some{hit} : Maybe<&2, Spec.Match<T>>} & ({Nat.is_le(SpecProof.index(T, hit), a) == True{} : Bool} & {Nat.is_lt(SpecProof.index(T, hit), b) == True{} : Bool})

# Any compiled route at any table index can fill every admissible assignment.
# The filled path has a router hit at index <= i. If every earlier entry misses
# that path, the router returns exactly Match{i, tag, params}.
law router_fill_match:
  for -T: Data
  for +table: Spec.Table(T)
  for +i: Nat
  for +source: String
  for +pattern: Pattern.Pattern
  for +tag: T
  for entry: {List.get(&2, Spec.Route<T>, table, i) == Some{Spec.Route{pattern, tag}} : Maybe<&2, Spec.Route<T>>}
  for compiled: {Pattern.compile(source) == Done{pattern} : Result<&2, &2, Pattern.PatternError, Pattern.Pattern>}
  for +params: Pattern.Params
  for admitted: {Pattern.admissible(pattern, params) == True{} : Bool}
  exs path: String
  exs hit: Spec.Match<T>
  {Pattern.fill(pattern, params) == Some{path} : Maybe<&2, String>} & ({Spec.route(T, table, path) == Some{hit} : Maybe<&2, Spec.Match<T>>} & ({Nat.is_le(SpecProof.index(T, hit), i) == True{} : Bool} & (SpecProof.NoEarlier(T, table, path, i) -> {Spec.route(T, table, path) == Some{Spec.Match{i, tag, params}} : Maybe<&2, Spec.Match<T>>})))

# BND-9: buffered response framing, over every admissible response.

# Observe the FIRST delimiter and independently parse the complete head.
# Exactly one case-insensitive Content-Length, and no Transfer-Encoding.
# All octet bodies are covered, including multibyte UTF-8 and embedded blanks.
law response_body_after_first_blank:
  for +method: Request.Method
  for +status: U32
  for +headers: List<&2, Request.Header>
  for +body: List<&2, U32>
  for +representation: Maybe<&2, List<&2, U32>>
  for +valid: {Response.valid(Response.Res{status, headers, body, representation}) == True{} : Bool}
  for +allowed: {WriteResponse.allows_body(status) == True{} : Bool}
  for +not_head: {WriteResponse.is_head(method) == False{} : Bool}
  for +not_tunnel: {WriteResponse.tunnel(method, status) == False{} : Bool}
  exs head: List<&2, U32>
  exs parsed: ResponseSpec.Head
  {ResponseSpec.split_first(WriteResponse.write(method, Response.Res{status, headers, body, representation})) == Some{(head, body)} : Maybe<&2, ResponseSpec.BytePair()>} &
  {ResponseSpec.parse_head(Bytes.append(head, [13, 10, 13, 10])) == Some{parsed} : Maybe<&2, ResponseSpec.Head>} &
  {ResponseSpec.header_values(parsed, "content-length") == [Bytes.encode(Nat.show(List.length(&2, U32, body)))] : List<&2, List<&2, U32>>} &
  {ResponseSpec.header_values(parsed, "transfer-encoding") == [] : List<&2, List<&2, U32>>}

# Every method and 1xx/204: empty suffix after the FIRST delimiter, a valid
# independently parsed head, and no Content-Length or Transfer-Encoding.
law response_forbidden_has_no_body_or_length:
  for +method: Request.Method
  for +status: U32
  for +headers: List<&2, Request.Header>
  for +body: List<&2, U32>
  for +representation: Maybe<&2, List<&2, U32>>
  for +valid: {Response.valid(Response.Res{status, headers, body, representation}) == True{} : Bool}
  for +forbidden: {WriteResponse.forbidden(status) == True{} : Bool}
  exs head: List<&2, U32>
  exs parsed: ResponseSpec.Head
  {ResponseSpec.split_first(WriteResponse.write(method, Response.Res{status, headers, body, representation})) == Some{(head, [])} : Maybe<&2, ResponseSpec.BytePair()>} &
  {ResponseSpec.parse_head(Bytes.append(head, [13, 10, 13, 10])) == Some{parsed} : Maybe<&2, ResponseSpec.Head>} &
  {ResponseSpec.header_values(parsed, "content-length") == [] : List<&2, List<&2, U32>>} &
  {ResponseSpec.header_values(parsed, "transfer-encoding") == [] : List<&2, List<&2, U32>>}

# Every valid 304 and every method: no payload or transfer coding. A length
# occurs exactly once iff a representation witness is supplied, and counts it.
law response_304_framing:
  for +method: Request.Method
  for +headers: List<&2, Request.Header>
  for +body: List<&2, U32>
  for +representation: Maybe<&2, List<&2, U32>>
  for +valid: {Response.valid(Response.Res{304, headers, body, representation}) == True{} : Bool}
  exs head: List<&2, U32>
  exs parsed: ResponseSpec.Head
  {ResponseSpec.split_first(WriteResponse.write(method, Response.Res{304, headers, body, representation})) == Some{(head, [])} : Maybe<&2, ResponseSpec.BytePair()>} &
  {ResponseSpec.parse_head(Bytes.append(head, [13, 10, 13, 10])) == Some{parsed} : Maybe<&2, ResponseSpec.Head>} &
  {ResponseSpec.header_values(parsed, "content-length") == ResponseFramingSpec.representation_lengths(representation) : List<&2, List<&2, U32>>} &
  {ResponseSpec.header_values(parsed, "transfer-encoding") == [] : List<&2, List<&2, U32>>}

# Independently split actual GET and HEAD wire outputs. Their valid heads
# agree, HEAD has no suffix, and that head meets the independent framing table.
law response_head_matches_get:
  for +res: Response.Res
  for +valid: {Response.valid(res) == True{} : Bool}
  exs head: List<&2, U32>
  exs get_body: List<&2, U32>
  exs parsed: ResponseSpec.Head
  {ResponseSpec.split_first(WriteResponse.write(Request.Get{}, res)) == Some{(head, get_body)} : Maybe<&2, ResponseSpec.BytePair()>} &
  {ResponseSpec.split_first(WriteResponse.write(Request.Head{}, res)) == Some{(head, [])} : Maybe<&2, ResponseSpec.BytePair()>} &
  {ResponseSpec.parse_head(Bytes.append(head, [13, 10, 13, 10])) == Some{parsed} : Maybe<&2, ResponseSpec.Head>} &
  {ResponseSpec.header_values(parsed, "content-length") == ResponseFramingSpec.get_lengths(res) : List<&2, List<&2, U32>>} &
  {ResponseSpec.header_values(parsed, "transfer-encoding") == [] : List<&2, List<&2, U32>>}

# Response.text uses this encoder. Every scalar String survives the shared
# strict UTF-8 decoder, rather than merely counting unspecified octets.
law response_utf8_encode:
  for +s: String
  for +valid: {Utf8.valid(s) == True{} : Bool}
  {Utf8.decode(Response.utf8(s)) == Some{s} : Maybe<&2, String>}

# BND-18: universal method-aware routing guarantees.

# Every direct Found is the first registration matching both path and method.
# Indexed eligibility reads List.get and adapts only the requested path options.
law methods_found_first:
  for -T: Data
  for +table: Methods.Valid<T>
  for +path: String
  for +method: Request.Method
  for +opts: Methods.Options
  for +i: Nat
  for +tag: T
  for +params: Pattern.Params
  for returned: {Methods.resolve(T, table, path, method, opts) == Methods.Found{Spec.Match{i, tag, params}, False{}} : Methods.Resolution<T>}
  MethodProof.First(T, Methods.raw(T, table), path, method, opts, i, tag, params)

# Default options are exactly the original matcher, for every pattern and path.
law methods_default_path_identity:
  for +pattern: Pattern.Pattern
  for +path: String
  {Methods.match_path(pattern, path, Methods.defaults()) == Pattern.match_path(pattern, path) : Maybe<&2, Pattern.Params>}

# The default first-match statement uses direct Pattern.match_path and an
# independent selector predicate at each List.get registration: AllMethods
# accepts every method; OnlyMethods uses literal token membership.
law methods_default_found_first:
  for -T: Data
  for +table: Methods.Valid<T>
  for +path: String
  for +method: Request.Method
  for +i: Nat
  for +tag: T
  for +params: Pattern.Params
  for returned: {Methods.resolve(T, table, path, method, Methods.defaults()) == Methods.Found{Spec.Match{i, tag, params}, False{}} : Methods.Resolution<T>}
  MethodProof.DefaultFirst(T, Methods.raw(T, table), path, method, i, tag, params)

# Any explicit HEAD match anywhere in the table defeats every GET fallback.
# The returned explicit HEAD is itself the first matching HEAD registration.
law methods_explicit_head_priority:
  for -T: Data
  for +table: Methods.Valid<T>
  for +path: String
  for +opts: Methods.Options
  for +i: Nat
  for +tag: T
  for +params: Pattern.Params
  for matched: {MethodProof.match_at(T, Methods.raw(T, table), path, Request.Head{}, opts, i) == Some{MethodProof.At{tag, params}} : Maybe<&2, MethodProof.AtMatch<T>>}
  MethodProof.HeadPriority(T, Methods.raw(T, table), path, opts)

# A fallback Found requires HEAD, a miss at every HEAD registration index,
# and exactly the first GET path+method registration, including its params.
law methods_head_fallback_first_get:
  for -T: Data
  for +table: Methods.Valid<T>
  for +path: String
  for +method: Request.Method
  for +opts: Methods.Options
  for +i: Nat
  for +tag: T
  for +params: Pattern.Params
  for returned: {Methods.resolve(T, table, path, method, opts) == Methods.Found{Spec.Match{i, tag, params}, True{}} : Methods.Resolution<T>}
  {method == Request.Head{} : Request.Method} & (MethodProof.Misses(T, Methods.raw(T, table), path, Request.Head{}, opts) & MethodProof.First(T, Methods.raw(T, table), path, Request.Get{}, opts, i, tag, params))

# NotFound iff every registered pattern misses the path. NoPaths checks every
# entry, including registrations whose method list is empty.
law methods_not_found_iff_all_paths_miss:
  for -T: Data
  for +table: Methods.Valid<T>
  for +path: String
  for +method: Request.Method
  for +opts: Methods.Options
  ({Methods.resolve(T, table, path, method, opts) == Methods.NotFound{} : Methods.Resolution<T>} -> MethodProof.NoPaths(T, Methods.raw(T, table), path, opts)) &
    (MethodProof.NoPaths(T, Methods.raw(T, table), path, opts) -> {Methods.resolve(T, table, path, method, opts) == Methods.NotFound{} : Methods.Resolution<T>})

# ExactAllow independently requires strict canonical rank/token adjacency,
# no repeated method token, absence of the requested method, and membership
# iff present in ANY path-matching registration or HEAD supplied by GET.
# Registrations and the request use canonical Method constructors. Output
# methods are valid too. Every admissible table, pattern, path, option
# combination and query-method token is covered. ExactAllow additionally
# requires every AllMethods registration to miss the path, so a matching all
# cannot produce 405. Finite registrations retain the same exact set guarantee.
law methods_allow_exact:
  for -T: Data
  for +table: Methods.Valid<T>
  for +path: String
  for +method: Request.Method
  for +opts: Methods.Options
  for +allow: List<&2, Request.Method>
  for valid: {Request.method_valid(method) == True{} : Bool}
  for returned: {Methods.resolve(T, table, path, method, opts) == Methods.MethodNotAllowed{allow} : Methods.Resolution<T>}
  MethodProof.ExactAllow(T, Methods.raw(T, table), path, method, opts, allow)

# Every successful public construction carries valid method-token evidence.
law methods_build_valid:
  for -T: Data
  for +entries: List<&2, Methods.Registration(T)>
  for +table: Methods.Valid<T>
  for built: {Methods.build_table(T, entries) == Done{table} : Result<&2, &2, Methods.BuildError, Methods.Valid<T>>}
  {MethodProof.TableValid(T, Methods.raw(T, table)) == True{} : Bool}

# BND-42: encoding inversion over every admissible octet list.
# Octets.valid explicitly requires (x <= 255 : U32) for every element.
law hex_roundtrip:
  for +xs: List<&2, U32>
  for valid: {Octets.valid(xs) == True{} : Bool}
  {Hex.decode(Hex.encode(xs)) == Some{xs} : Maybe<&2, List<&2, U32>>}

# Quantifying both flags promises all four RFC 4648 modes: standard/URL,
# each with required padding or without padding. This is not a sample law.
law base64_roundtrip:
  for +xs: List<&2, U32>
  for +url: Bool
  for +padded: Bool
  for valid: {Octets.valid(xs) == True{} : Bool}
  {Base64.decode(Base64.encode(xs, url, padded), url, padded) == Some{xs} : Maybe<&2, List<&2, U32>>}

# BND-8: chunked decoding, for every octet body and producer chunking.

# The independent admissible predicate checks only octets and total body length.
# Empty producer chunks are allowed and omitted on the wire. The arbitrary
# suffix represents a following pipelined request and is returned untouched.
law chunked_roundtrip:
  for +chunks: List<&2, List<&2, U32>>
  for +limit: U32
  for +suffix: List<&2, U32>
  for valid: {Chunked.admissible(chunks, limit) == True{} : Bool}
  {Chunked.decode(Bytes.append(Chunked.encode(chunks), suffix), limit) == Chunked.Decoded{List.concat(&2, U32, chunks), [], suffix} : Chunked.DecodeResult}

# BND-22: onion middleware. These equations quantify over every admissible
# middleware function, context, continuation and result type. R is Type, so
# the same pure algebra used at runtime also admits IO(Res); no equality of
# foreign effects is assumed. Functions are erased here, never made copyable.

law middleware_application:
  for -C: Data
  for -R: Type
  for -a: Middleware.Value(C, R)
  for -b: Middleware.Value(C, R)
  for -ctx: C
  for -next: C -> R
  {Middleware.compose(C, R, a, b, ctx, next) == a(ctx, changed => b(changed, next)) : R}

law middleware_identity_left:
  for -C: Data
  for -R: Type
  for -mw: Middleware.Value(C, R)
  for -ctx: C
  for -next: C -> R
  {Middleware.compose(C, R, Middleware.identity(C, R), mw, ctx, next) == mw(ctx, next) : R}

law middleware_identity_right:
  for -C: Data
  for -R: Type
  for -mw: Middleware.Value(C, R)
  for -ctx: C
  for -next: C -> R
  {Middleware.compose(C, R, mw, Middleware.identity(C, R), ctx, next) == mw(ctx, next) : R}

# An identity inserted between arbitrary prefix/suffix middleware changes no
# result, including when the prefix short-circuits or changes the context.
law middleware_identity_insert:
  for -C: Data
  for -R: Type
  for -a: Middleware.Value(C, R)
  for -b: Middleware.Value(C, R)
  for -ctx: C
  for -next: C -> R
  {Middleware.compose(C, R, a, Middleware.compose(C, R, Middleware.identity(C, R), b), ctx, next) == Middleware.compose(C, R, a, b, ctx, next) : R}

law middleware_associative:
  for -C: Data
  for -R: Type
  for -a: Middleware.Value(C, R)
  for -b: Middleware.Value(C, R)
  for -c: Middleware.Value(C, R)
  for -ctx: C
  for -next: C -> R
  {Middleware.compose(C, R, Middleware.compose(C, R, a, b), c, ctx, next) == Middleware.compose(C, R, a, Middleware.compose(C, R, b, c), ctx, next) : R}

# Ordinary middleware only: successful construction preserves registration order,
# duplicates, and selection at the supplied raw path, with global and matching
# path-specific ids interleaved. Hook registrations contribute no ordinary ids.
law middleware_registration_selection:
  for -Tag: Data
  for +entries: List<&2, Table.Entry<Tag>>
  for +table: Table.Table<Tag>
  for +path: String
  for built: {Table.build(Tag, entries) == Done{table} : Result<&2, &2, Methods.BuildError, Table.Table<Tag>>}
  {MiddlewareSelectionSpec.selected(Tag, table, path) == MiddlewareSelectionSpec.filter(Tag, entries, path) : List<&2, Tag>}

# BND-23
# Every stage selects exactly its registration-ordered, duplicate-preserving ids.
law lifecycle_stage_selection:
  for -Tag: Data
  for +entries: List<&2, Table.Entry<Tag>>
  for +routes: List<&2, Methods.Registration(Tag)>
  for +compiled: Methods.Index<Tag>
  for +layers: List<&2, Table.Middleware<Tag>>
  for +count: Nat
  for +stage: Table.Stage
  for built: {Table.build(Tag, entries) == Done{Table.Table{routes, compiled, layers, count}} : Result<&2, &2, Methods.BuildError, Table.Table<Tag>>}
  {Table.stage_ids(Tag, layers, stage) == MiddlewareSelectionSpec.hooks(Tag, entries, stage) : List<&2, Tag>}

# The exact plan consumed by Handle: request, ordinary/parse/transform/before,
# after_handle, map_response, conditional on_error, deferred on_after_response.
# path is the raw routing path AFTER on_request rewrites; only ordinary use_path
# selection depends on it. Request and response ids are path-independent, so the
# runtime may select them before rewrites. This is selection, not a promise that
# short-circuited pre stages or conditional error hooks execute on every request.
law lifecycle_ordered_selection:
  for -Tag: Data
  for +entries: List<&2, Table.Entry<Tag>>
  for +routes: List<&2, Methods.Registration(Tag)>
  for +compiled: Methods.Index<Tag>
  for +layers: List<&2, Table.Middleware<Tag>>
  for +count: Nat
  for +path: String
  for +built: {Table.build(Tag, entries) == Done{Table.Table{routes, compiled, layers, count}} : Result<&2, &2, Methods.BuildError, Table.Table<Tag>>}
  {Table.lifecycle(Tag, layers, path) == MiddlewareSelectionSpec.lifecycle(Tag, entries, path) : Table.Lifecycle<Tag>}

# BND-17: the trie router equals the reference router.

# For every table, including hand-built patterns that compile could never
# produce, and every path, the trie built from that table returns the
# reference router's exact result: index, tag and ordered params, or None.
law trie_route_spec:
  for -T: Data
  for +table: Spec.Table(T)
  for +path: String
  {Trie.trie_route(T, Trie.build_trie(T, table), path) == Spec.route(T, table, path) : Maybe<&2, Spec.Match<T>>}

# The trie's ordered match list is exactly every registration whose pattern
# matches the path, ascending by index, with its tag and params. The
# specification filters the whole table and never consults a router.
law trie_matches_spec:
  for -T: Data
  for +table: Spec.Table(T)
  for +path: String
  {Trie.matches(T, Trie.build_trie(T, table), path) == SpecProof.matching(T, table, path) : List<&2, Spec.Match<T>>}

# Every router kind, prepared from a table, routes like the reference router.
law router_kind_spec:
  for -T: Data
  for +kind: Router.RouterKind
  for +table: Spec.Table(T)
  for +path: String
  {Router.route(T, kind, Router.prepare(T, table), path) == Spec.route(T, table, path) : Maybe<&2, Spec.Match<T>>}

# Method resolution through every router kind, for every valid table, path,
# request method and option combination, returns exactly Methods.resolve.
# Every BND-18 law about Found, HEAD fallback, 404 and the exact Allow set
# therefore holds for the configured router too.
law methods_router_resolve:
  for -T: Data
  for +kind: Router.RouterKind
  for +table: Methods.Valid<T>
  for +path: String
  for +method: Request.Method
  for +opts: Methods.Options
  {Methods.resolve_with(T, kind, Methods.prepare(T, table), path, method, opts) == Methods.resolve(T, table, path, method, opts) : Methods.Resolution<T>}

# BND-31: independently admissible cookie names and raw cookie-octet values.

law cookies_pair_roundtrip:
  for +name: String
  for +value: String
  for name_valid: {Cookie.name_valid(name) == True{} : Bool}
  for value_valid: {Cookie.value_valid(value) == True{} : Bool}
  {Cookie.parse(Cookie.serialize_pair(name, value)) == [Cookie.Entry{name, value}] : List<&2, Cookie.Entry>}

law cookies_defaults_checked:
  for +name: String
  for +value: String
  for name_valid: {Cookie.name_valid(name) == True{} : Bool}
  for value_valid: {Cookie.value_valid(value) == True{} : Bool}
  {Cookie.serialize(name, value, Cookie.defaults()) == Done{Cookie.serialize_pair(name, value)} : Result<&2, &2, Cookie.Error, String>}

# BND-31: the complete ordered Cookie header, including repeated names.
law cookies_ordered_list_roundtrip:
  for +entries: List<&2, Cookie.Entry>
  for valid: {CookieSpec.entries_valid(entries) == True{} : Bool}
  {Cookie.parse(String.join(CookieSpec.pairs(entries), ";")) == entries : List<&2, Cookie.Entry>}

# BND-33, extended by BND-34: decoding agrees with an independent
# specification for EVERY schema and Json tree, including malformed schemas and
# constructed data. SchemaSpec restates each rule from docs/data/schema.md
# (scalar counts, the RFC 8259 number grammar, exact decimal values, patterns
# as regular languages with a size cap, email and URL grammars; array item
# counts and items; object key policy, per-key member counts and members;
# nullables; unions as "some member") and calls no decoder helper. Equality
# proves both soundness (accepted implies satisfies) and completeness. BND-34
# added constructors to Schema without changing this statement. On a scalar
# schema, decode accepts and satisfies holds exactly as in BND-33, so the
# BND-33 law is this one restricted to scalar schemas.

law schema_acceptance_iff:
  for +schema: Schema.Schema
  for +value: Json.Json
  {Schema.accepted(Schema.decode(schema, value)) == SchemaSpec.satisfies(schema, value) : Bool}

# Every success has the right typed constructor AND preserves the exact input
# payload, including decimal spelling. Failures impose no payload obligation.
# For compound schemas value_for builds the whole tree: each array item in
# order, each declared field in schema order from the first member with its
# key (None when absent), and a union's first accepted member with its index.
# On scalar schemas value_for and decode are unchanged from BND-33.
law schema_preserves_typed_value:
  for +schema: Schema.Schema
  for +value: Json.Json
  Schema.Preserves(Schema.value_for(schema, value), Schema.decode(schema, value))

# BND-34: an accepted compound value satisfies every child schema. Each array
# item satisfies the item schema, each member with a declared key satisfies
# that field's schema, a non-null value satisfies a nullable's inner schema,
# and the value satisfies at least one union member. (It follows from
# schema_acceptance_iff; it is stated on its own so the guarantee is explicit.)
law schema_children_satisfy:
  for +schema: Schema.Schema
  for +value: Json.Json
  for accepted: {Schema.accepted(Schema.decode(schema, value)) == True{} : Bool}
  {SchemaSpec.children(schema, value) == True{} : Bool}

# BND-35: a rejection names where it fails. When decoding rejects a value it
# lists at least one and at most SchemaSpec.error_cap() (100) errors, and the
# path of every error is a location where the independent specification finds
# a failing check (SchemaSpec.error_at): the value there fails its scalar
# schema, has the wrong kind or array length, matches no union member, is a
# declared key present a number of times its presence forbids, or is a key
# Strict does not declare; an invalid schema is one error at the root.
# Successes impose nothing; schema_acceptance_iff says when decoding succeeds.
law schema_errors_name_failing_paths:
  for +schema: Schema.Schema
  for +value: Json.Json
  {SchemaSpec.located_errors(schema, value, Schema.decode(schema, value)) == True{} : Bool}

# BND-35: and it names every one. For every path where the specification finds
# a failing check, decoding rejects and lists an error with exactly that path,
# unless the list already holds error_cap() errors. Errors are collected across
# all array items and object fields. Nothing below a failed kind or length
# check, and nothing inside a union, is a location (SchemaSpec.fault).
law schema_errors_complete:
  for +schema: Schema.Schema
  for +value: Json.Json
  for +path: List<&2, Schema.PathPart>
  for fault: {SchemaSpec.error_at(schema, value, path) == True{} : Bool}
  {SchemaSpec.reported(Schema.decode(schema, value), path) == True{} : Bool}

# BND-35: coercion for text sources (params, query, headers, forms) is exactly
# the independent restatement SchemaSpec.coerce_text: number tokens under number
# and integer schemas, "true"/"false" under boolean schemas, items under arrays,
# the inner schema under nullables, and under an object every declared member,
# with all members named by an array field gathered in order into one array at
# the first one's position. JSON bodies are decoded without it.
law schema_coerce_matches_spec:
  for +schema: Schema.Schema
  for +value: Json.Json
  {Schema.coerce(schema, value) == SchemaSpec.coerce_text(schema, value) : Json.Json}

# BND-35: the BND-33/34 acceptance, preservation and BND-35 error laws hold in
# text mode, read against the coerced value.
law schema_coerced_acceptance_iff:
  for +schema: Schema.Schema
  for +value: Json.Json
  {Schema.accepted(Schema.decode_from(Schema.TextSource{}, schema, value)) == SchemaSpec.satisfies(schema, SchemaSpec.coerce_text(schema, value)) : Bool}

law schema_coerced_preserves_typed_value:
  for +schema: Schema.Schema
  for +value: Json.Json
  Schema.Preserves(Schema.value_for(schema, SchemaSpec.coerce_text(schema, value)), Schema.decode_from(Schema.TextSource{}, schema, value))

law schema_coerced_errors_name_failing_paths:
  for +schema: Schema.Schema
  for +value: Json.Json
  {SchemaSpec.located_errors(schema, SchemaSpec.coerce_text(schema, value), Schema.decode_from(Schema.TextSource{}, schema, value)) == True{} : Bool}

law schema_coerced_errors_complete:
  for +schema: Schema.Schema
  for +value: Json.Json
  for +path: List<&2, Schema.PathPart>
  for fault: {SchemaSpec.error_at(schema, SchemaSpec.coerce_text(schema, value), path) == True{} : Bool}
  {SchemaSpec.reported(Schema.decode_from(Schema.TextSource{}, schema, value), path) == True{} : Bool}

# BND-24: selection from source memberships, independent of runtime helpers.
# Globals precede inherited group/guard placements and then route-local hooks;
# each source order and every duplicate is retained. None denotes no selected
# route, including routing misses and method failures.
law scoped_stage_selection:
  for -Tag: Data
  for +entries: List<&2, Table.Entry<Tag>>
  for +routes: List<&2, Methods.Registration(Tag)>
  for +compiled: Methods.Index<Tag>
  for +layers: List<&2, Table.Middleware<Tag>>
  for +count: Nat
  for +route: Maybe<&2, Nat>
  for +stage: Table.Stage
  for +built: {Table.build(Tag, entries) == Done{Table.Table{routes, compiled, layers, count}} : Result<&2, &2, Methods.BuildError, Table.Table<Tag>>}
  {Table.scoped_stage_ids(Tag, layers, route, stage) == ScopedSelectionSpec.stage_ids(Tag, entries, route, stage) : List<&2, Tag>}

law scoped_lifecycle_selection:
  for -Tag: Data
  for +entries: List<&2, Table.Entry<Tag>>
  for +routes: List<&2, Methods.Registration(Tag)>
  for +compiled: Methods.Index<Tag>
  for +layers: List<&2, Table.Middleware<Tag>>
  for +count: Nat
  for +path: String
  for +route: Maybe<&2, Nat>
  for +built: {Table.build(Tag, entries) == Done{Table.Table{routes, compiled, layers, count}} : Result<&2, &2, Methods.BuildError, Table.Table<Tag>>}
  {Table.scoped_lifecycle(Tag, layers, path, route) == ScopedSelectionSpec.lifecycle(Tag, entries, path, route) : Table.Lifecycle<Tag>}

# Even a matching path grants no scoped hook without route membership.
law scoped_nonmember_global_only:
  for -Tag: Data
  for +entries: List<&2, Table.Entry<Tag>>
  for +routes: List<&2, Methods.Registration(Tag)>
  for +compiled: Methods.Index<Tag>
  for +layers: List<&2, Table.Middleware<Tag>>
  for +count: Nat
  for +route: Maybe<&2, Nat>
  for +stage: Table.Stage
  for +built: {Table.build(Tag, entries) == Done{Table.Table{routes, compiled, layers, count}} : Result<&2, &2, Methods.BuildError, Table.Table<Tag>>}
  for no: {ScopedSelectionSpec.member(Tag, entries, route) == False{} : Bool}
  {Table.scoped_stage_ids(Tag, layers, route, stage) == Table.stage_ids(Tag, layers, stage) : List<&2, Tag>}

law scoped_miss_global_only:
  for -Tag: Data
  for +entries: List<&2, Table.Entry<Tag>>
  for +routes: List<&2, Methods.Registration(Tag)>
  for +compiled: Methods.Index<Tag>
  for +layers: List<&2, Table.Middleware<Tag>>
  for +count: Nat
  for +stage: Table.Stage
  for +built: {Table.build(Tag, entries) == Done{Table.Table{routes, compiled, layers, count}} : Result<&2, &2, Methods.BuildError, Table.Table<Tag>>}
  {Table.scoped_stage_ids(Tag, layers, None{}, stage) == Table.stage_ids(Tag, layers, stage) : List<&2, Tag>}

# The real runtime boundary: every path, method, router kind and option set.
# This checks forward-router-index to reversed-source-ordinal conversion too;
# source hook filtering still never consults runtime selection helpers.
law scoped_resolved_stage_selection:
  for -Tag: Data
  for +entries: List<&2, Table.Entry<Tag>>
  for +routes: List<&2, Methods.Registration(Tag)>
  for +compiled: Methods.Index<Tag>
  for +layers: List<&2, Table.Middleware<Tag>>
  for +count: Nat
  for +kind: Router.RouterKind
  for +path: String
  for +method: Request.Method
  for +opts: Methods.Options
  for +stage: Table.Stage
  for +built: {Table.build(Tag, entries) == Done{Table.Table{routes, compiled, layers, count}} : Result<&2, &2, Methods.BuildError, Table.Table<Tag>>}
  {Table.scoped_stage_ids(Tag, layers, RouteSlot.identity(Tag, count, Methods.resolve_with(Tag, kind, compiled, path, method, opts)), stage) == ScopedSelectionSpec.stage_ids(Tag, entries, ScopedSelectionSpec.resolved_route(Tag, entries, Methods.resolve_with(Tag, kind, compiled, path, method, opts)), stage) : List<&2, Tag>}

# BND-24: assembly from raw public declarations. Equality includes scope
# provenance, route paths/tags/order, every duplicate and every placement.
# The independent fused map puts explicit hooks before direct declarations,
# and new outer placements before every existing inner/local placement.
law scoped_guard_assembly:
  for -Tag: Data
  for +options: Table.GuardOptions<Tag>
  for +entries: List<&2, Table.Entry<Tag>>
  {Scopes.guard(Tag, options, entries) == AssemblySpec.guard(Tag, options, entries) : List<&2, Table.Entry<Tag>>}

law scoped_group_assembly:
  for -Tag: Data
  for +prefix: String
  for +hooks: List<&2, Table.HookSpec<Tag>>
  for +entries: List<&2, Table.Entry<Tag>>
  {Scopes.group(Tag, prefix, hooks, entries) == AssemblySpec.group(Tag, prefix, hooks, entries) : List<&2, Table.Entry<Tag>>}

law scoped_local_assembly:
  for -Tag: Data
  for +registration: Methods.Registration(Tag)
  for +hooks: List<&2, Table.HookSpec<Tag>>
  {Scopes.local(Tag, registration, hooks) == AssemblySpec.local(Tag, registration, hooks) : Table.Entry<Tag>}

# Arbitrary neighbours, including identical paths and hook tags, are untouched.
# Inside may itself contain any nesting or route-local hooks. Both outer and
# inner scope constructors retain their provenance and structural order.
law scoped_nested_assembly_isolation:
  for -Tag: Data
  for +before: List<&2, Table.Entry<Tag>>
  for +options: Table.GuardOptions<Tag>
  for +prefix: String
  for +hooks: List<&2, Table.HookSpec<Tag>>
  for +inside: List<&2, Table.Entry<Tag>>
  for +after: List<&2, Table.Entry<Tag>>
  {List.append(&2, Table.Entry<Tag>, before, List.append(&2, Table.Entry<Tag>, Scopes.guard(Tag, options, Scopes.group(Tag, prefix, hooks, inside)), after)) == List.append(&2, Table.Entry<Tag>, before, List.append(&2, Table.Entry<Tag>, AssemblySpec.guard(Tag, options, AssemblySpec.group(Tag, prefix, hooks, inside)), after)) : List<&2, Table.Entry<Tag>>}

law scoped_guard_built_selection:
  for -Tag: Data
  for +options: Table.GuardOptions<Tag>
  for +inside: List<&2, Table.Entry<Tag>>
  for +outside: List<&2, Table.Entry<Tag>>
  for +routes: List<&2, Methods.Registration(Tag)>
  for +compiled: Methods.Index<Tag>
  for +layers: List<&2, Table.Middleware<Tag>>
  for +count: Nat
  for +route: Maybe<&2, Nat>
  for +stage: Table.Stage
  for +built: {Table.build(Tag, List.append(&2, Table.Entry<Tag>, Scopes.guard(Tag, options, inside), outside)) == Done{Table.Table{routes, compiled, layers, count}} : Result<&2, &2, Methods.BuildError, Table.Table<Tag>>}
  {Table.scoped_stage_ids(Tag, layers, route, stage) == ScopedSelectionSpec.stage_ids(Tag, List.append(&2, Table.Entry<Tag>, AssemblySpec.guard(Tag, options, inside), outside), route, stage) : List<&2, Tag>}

law scoped_group_built_selection:
  for -Tag: Data
  for +prefix: String
  for +hooks: List<&2, Table.HookSpec<Tag>>
  for +inside: List<&2, Table.Entry<Tag>>
  for +outside: List<&2, Table.Entry<Tag>>
  for +routes: List<&2, Methods.Registration(Tag)>
  for +compiled: Methods.Index<Tag>
  for +layers: List<&2, Table.Middleware<Tag>>
  for +count: Nat
  for +route: Maybe<&2, Nat>
  for +stage: Table.Stage
  for +built: {Table.build(Tag, List.append(&2, Table.Entry<Tag>, Scopes.group(Tag, prefix, hooks, inside), outside)) == Done{Table.Table{routes, compiled, layers, count}} : Result<&2, &2, Methods.BuildError, Table.Table<Tag>>}
  {Table.scoped_stage_ids(Tag, layers, route, stage) == ScopedSelectionSpec.stage_ids(Tag, List.append(&2, Table.Entry<Tag>, AssemblySpec.group(Tag, prefix, hooks, inside), outside), route, stage) : List<&2, Tag>}

# BND-25: a private HTTP failure's public message is independent of its
# internal text. proof/error-laws.bend states the same for the rendered
# response and its wire bytes, and pins the exact output.
law http_error_private_message:
  for code: U32
  for message: String
  {Errors.message(Errors.HttpError{code, message, False{}}) == "Internal Server Error" : String}

# BND-80: HTTP dates (docs/decisions/0007-http-date.md).
#
# Both laws cover every Unix second from 1970-01-01T00:00:00Z through
# 9999-12-31T23:59:59Z, that is 0 <= second <= 253402300799. The bound avoids
# that constant, which Bend's checkers would expand in unary. Let
# d = second / 86400, the Unix day. Then d - 10957 (0 when negative) counts
# days since 2000-01-01, and fewer than 20 whole 400-year Gregorian cycles of
# 146097 days means d < 10957 + 20 * 146097 = 2932897, the day of
# 10000-01-01. That holds exactly when second < 2932897 * 86400 =
# 253402300800, so the bound selects the same seconds as
# second <= 253402300799, no more and no fewer.

# LAW: parsing the formatted IMF-fixdate of any supported second returns it.
law http_date_roundtrip:
  for +second: Nat
  for bound: {Nat.is_lt(Nat.div(Nat.sub(Nat.div(second, 86400n), 10957n), 146097n), 20n) == True{} : Bool}
  {HttpDate.parse_imf(HttpDate.format_imf(second)) == Some{second} : Maybe<&2, Nat>}

# LAW: the formatted text is exact IMF-fixdate for that second. The spec in
# proof/date-spec.bend shares no code with the codec: it checks the 29-byte
# grammar, English day and month names, decimal fields, and that the fields
# are the Gregorian date (counted day by day from 1970-01-01, century leap
# rules included), weekday (counted from Thursday) and time of day of second.
# The round trip alone cannot catch a wrong weekday, because the parser checks
# the weekday through the formatter.
law http_date_imf_spec:
  for +second: Nat
  for bound: {Nat.is_lt(Nat.div(Nat.sub(Nat.div(second, 86400n), 10957n), 146097n), 20n) == True{} : Bool}
  {HttpDateSpec.denotes(HttpDate.format_imf(second), second) == True{} : Bool}

# LAW: parsing is strict. Any text parse_imf accepts is exactly the formatted
# IMF-fixdate of the second it returns, so malformed, obsolete or
# non-canonical dates are never accepted.
law http_date_parse_strict:
  for +text: String
  for +second: Nat
  for ok: {HttpDate.parse_imf(text) == Some{second} : Maybe<&2, Nat>}
  {HttpDate.format_imf(second) == text : String}

# BND-43: authentication primitives. These laws state functional results only.
# Execution time is outside them; see docs/decisions/0012-constant-time-auth.md.

# The accumulating comparison is exactly element-wise equality, for every pair
# of U32 lists of any lengths. The specification compares in order and stops.
law ct_equal_spec:
  for +xs: List<&2, U32>
  for +ys: List<&2, U32>
  {Compare.ct_equal(xs, ys) == CompareSpec.equal(xs, ys) : Bool}

# For every secret and every octet header and payload, opening a token sealed
# with the same secret returns exactly the sealed octets.
law jwt_open_seal:
  for +secret: List<&2, U32>
  for +header: List<&2, U32>
  for +payload: List<&2, U32>
  for vh: {Octets.valid(header) == True{} : Bool}
  for vp: {Octets.valid(payload) == True{} : Bool}
  {Jwt.open(secret, Jwt.seal(secret, header, payload)) == Done{Jwt.Parts{header, payload}} : Result<&2, &2, Jwt.Error, Jwt.Parts>}

# Every token a.b.c with three dot-free segments whose signature segment c is
# not the unpadded base64url HMAC-SHA256 of the signing input "a.b" (its UTF-8
# octets, under the same secret) is rejected with BadSignature. Any other
# token has fewer or more than three segments.
law jwt_rejects_bad_signature:
  for +secret: List<&2, U32>
  for +a: String
  for +b: String
  for +c: String
  for fa: {Jwt.dotfree(a) == True{} : Bool}
  for fb: {Jwt.dotfree(b) == True{} : Bool}
  for fc: {Jwt.dotfree(c) == True{} : Bool}
  for differs: {c != Base64.encode(HMAC.sha256(secret, Utf8.encode(a ++ ("." ++ b))), True{}, False{}) : String}
  {Jwt.open(secret, a ++ ("." ++ (b ++ ("." ++ c)))) == Fail{Jwt.BadSignature{}} : Result<&2, &2, Jwt.Error, Jwt.Parts>}

# Every token whose number of '.' characters (JwtSpec.dots) is not two is
# Malformed, whatever the secret.
law jwt_rejects_malformed:
  for +secret: List<&2, U32>
  for +token: String
  for wrong: {JwtSpec.dots(token) != 2n : Nat}
  {Jwt.open(secret, token) == Fail{Jwt.Malformed{}} : Result<&2, &2, Jwt.Error, Jwt.Parts>}

# A token a.b.c whose c is the correct signature of "a.b", but whose a or b is
# not strict unpadded base64url (JwtSpec.base64url: alphabet, length and
# unused bits, stated by character sets), fails with BadEncoding. The
# signature is checked first: with any other c the error is BadSignature.
law jwt_rejects_bad_encoding:
  for +secret: List<&2, U32>
  for +a: String
  for +b: String
  for za: {JwtSpec.dots(a) == 0n : Nat}
  for zb: {JwtSpec.dots(b) == 0n : Nat}
  for bad: {JwtSpec.base64url(a) && JwtSpec.base64url(b) == False{} : Bool}
  {Jwt.open(secret, a ++ ("." ++ (b ++ ("." ++ Base64.encode(HMAC.sha256(secret, Utf8.encode(a ++ ("." ++ b))), True{}, False{}))))) == Fail{Jwt.BadEncoding{}} : Result<&2, &2, Jwt.Error, Jwt.Parts>}

# For every secret, time, leeway, payload segment and signature segment: if
# the header segment decodes to a JSON object that does not have exactly one
# member named "alg" holding the string "HS256" (absent, repeated, non-string
# or another algorithm; JwtSpec.alg_accepted counts members itself), verify
# fails. Tokens without exactly three segments fail by jwt_rejects_malformed.
law jwt_verify_rejects_bad_alg:
  for +secret: List<&2, U32>
  for +a: String
  for +b: String
  for +c: String
  for +now: Nat
  for +leeway: Nat
  for +header: List<&2, U32>
  for +fields: List<&2, Json.Field>
  for za: {JwtSpec.dots(a) == 0n : Nat}
  for zb: {JwtSpec.dots(b) == 0n : Nat}
  for zc: {JwtSpec.dots(c) == 0n : Nat}
  for decoded: {Base64.decode(a, True{}, False{}) == Some{header} : Maybe<&2, List<&2, U32>>}
  for parsed: {Json.parse(header) == Done{Json.JObject{fields}} : Result<&2, &2, Json.Error, Json.Json>}
  for bad: {JwtSpec.alg_accepted(fields) == False{} : Bool}
  {JwtSpec.failed(Jwt.verify(secret, a ++ ("." ++ (b ++ ("." ++ c))), now, leeway)) == True{} : Bool}

# With canonical segments, the correct signature and no repeated header
# member names, such a header fails with exactly BadAlgorithm.
law jwt_verify_bad_alg_exact:
  for +secret: List<&2, U32>
  for +a: String
  for +b: String
  for +now: Nat
  for +leeway: Nat
  for +header: List<&2, U32>
  for +payload: List<&2, U32>
  for +fields: List<&2, Json.Field>
  for za: {JwtSpec.dots(a) == 0n : Nat}
  for zb: {JwtSpec.dots(b) == 0n : Nat}
  for dh: {Base64.decode(a, True{}, False{}) == Some{header} : Maybe<&2, List<&2, U32>>}
  for dp: {Base64.decode(b, True{}, False{}) == Some{payload} : Maybe<&2, List<&2, U32>>}
  for parsed: {Json.parse(header) == Done{Json.JObject{fields}} : Result<&2, &2, Json.Error, Json.Json>}
  for distinct: {JwtSpec.distinct(fields) == True{} : Bool}
  for bad: {JwtSpec.alg_accepted(fields) == False{} : Bool}
  {Jwt.verify(secret, a ++ ("." ++ (b ++ ("." ++ Base64.encode(HMAC.sha256(secret, Utf8.encode(a ++ ("." ++ b))), True{}, False{})))), now, leeway) == Fail{Jwt.BadAlgorithm{}} : Result<&2, &2, Jwt.Error, Json.Json>}

# verify runs open first and adds checks after it, so every failure of open
# (Malformed, BadEncoding, BadSignature) is verify's failure, unchanged.
law jwt_verify_keeps_open_failure:
  for +secret: List<&2, U32>
  for +token: String
  for +now: Nat
  for +leeway: Nat
  for +e: Jwt.Error
  for failed: {Jwt.open(secret, token) == Fail{e} : Result<&2, &2, Jwt.Error, Jwt.Parts>}
  {Jwt.verify(secret, token, now, leeway) == Fail{e} : Result<&2, &2, Jwt.Error, Json.Json>}

# For every signature segment, time, leeway and payload segment: if the
# header segment decodes to octets that are not JSON, or are JSON but not an
# object, verify fails.
law jwt_verify_rejects_non_object_header:
  for +secret: List<&2, U32>
  for +a: String
  for +b: String
  for +c: String
  for +now: Nat
  for +leeway: Nat
  for +header: List<&2, U32>
  for za: {JwtSpec.dots(a) == 0n : Nat}
  for zb: {JwtSpec.dots(b) == 0n : Nat}
  for zc: {JwtSpec.dots(c) == 0n : Nat}
  for decoded: {Base64.decode(a, True{}, False{}) == Some{header} : Maybe<&2, List<&2, U32>>}
  for bad: {JwtSpec.json_object(Json.parse(header)) == False{} : Bool}
  {JwtSpec.failed(Jwt.verify(secret, a ++ ("." ++ (b ++ ("." ++ c))), now, leeway)) == True{} : Bool}

# For every header segment, signature segment, time and leeway: if the
# payload segment decodes to octets that are not JSON, or are JSON but not an
# object, verify fails.
law jwt_verify_rejects_non_object_payload:
  for +secret: List<&2, U32>
  for +a: String
  for +b: String
  for +c: String
  for +now: Nat
  for +leeway: Nat
  for +payload: List<&2, U32>
  for za: {JwtSpec.dots(a) == 0n : Nat}
  for zb: {JwtSpec.dots(b) == 0n : Nat}
  for zc: {JwtSpec.dots(c) == 0n : Nat}
  for decoded: {Base64.decode(b, True{}, False{}) == Some{payload} : Maybe<&2, List<&2, U32>>}
  for bad: {JwtSpec.json_object(Json.parse(payload)) == False{} : Bool}
  {JwtSpec.failed(Jwt.verify(secret, a ++ ("." ++ (b ++ ("." ++ c))), now, leeway)) == True{} : Bool}

# A header that decodes to a JSON object in which two top-level members share
# a name (JwtSpec.distinct is False) never verifies, whatever the signature,
# payload, time and leeway.
law jwt_verify_rejects_repeated_header_member:
  for +secret: List<&2, U32>
  for +a: String
  for +b: String
  for +c: String
  for +now: Nat
  for +leeway: Nat
  for +header: List<&2, U32>
  for +fields: List<&2, Json.Field>
  for za: {JwtSpec.dots(a) == 0n : Nat}
  for zb: {JwtSpec.dots(b) == 0n : Nat}
  for zc: {JwtSpec.dots(c) == 0n : Nat}
  for decoded: {Base64.decode(a, True{}, False{}) == Some{header} : Maybe<&2, List<&2, U32>>}
  for parsed: {Json.parse(header) == Done{Json.JObject{fields}} : Result<&2, &2, Json.Error, Json.Json>}
  for repeated: {JwtSpec.distinct(fields) == False{} : Bool}
  {JwtSpec.failed(Jwt.verify(secret, a ++ ("." ++ (b ++ ("." ++ c))), now, leeway)) == True{} : Bool}

# A payload that decodes to a JSON object in which two top-level members
# share a name never verifies, whatever the header, signature, time and leeway.
law jwt_verify_rejects_repeated_claim:
  for +secret: List<&2, U32>
  for +a: String
  for +b: String
  for +c: String
  for +now: Nat
  for +leeway: Nat
  for +payload: List<&2, U32>
  for +fields: List<&2, Json.Field>
  for za: {JwtSpec.dots(a) == 0n : Nat}
  for zb: {JwtSpec.dots(b) == 0n : Nat}
  for zc: {JwtSpec.dots(c) == 0n : Nat}
  for decoded: {Base64.decode(b, True{}, False{}) == Some{payload} : Maybe<&2, List<&2, U32>>}
  for parsed: {Json.parse(payload) == Done{Json.JObject{fields}} : Result<&2, &2, Json.Error, Json.Json>}
  for repeated: {JwtSpec.distinct(fields) == False{} : Bool}
  {JwtSpec.failed(Jwt.verify(secret, a ++ ("." ++ (b ++ ("." ++ c))), now, leeway)) == True{} : Bool}

# The CSRF decision equals CsrfSpec.allows for every policy (configured
# origins and optional scheme), method and header combination. The spec
# inspects only non-GET/HEAD requests with a form-like or absent
# Content-Type; trusts Sec-Fetch-Site: same-origin, a listed source, or the
# scheme://Host origin unless Sec-Fetch-Site is cross-site; takes Origin over
# Referer; and never trusts a missing or unparsable source such as "null".
law csrf_decision_spec:
  for +origins: List<&2, String>
  for +scheme: Maybe<&2, String>
  for +method: Request.Method
  for +content_type: Maybe<&2, String>
  for +site: Maybe<&2, String>
  for +origin: Maybe<&2, String>
  for +referer: Maybe<&2, String>
  for +host: Maybe<&2, String>
  {CsrfPolicy.decide(CsrfPolicy.Policy{origins, scheme}, method, content_type, site, origin, referer, host) == CsrfSpec.allows(origins, scheme, method, content_type, site, origin, referer, host) : Bool}

# The middleware builds its policy with CsrfPolicy.policy, so the decision is
# also stated from configuration: configured entries become their URL origins
# (CsrfSpec.configured drops any that is not an http or https URL) and the
# scheme is compared in lowercase. The origin parser itself is shared with the
# specification (src/http/origin.bend).
law csrf_configured_decision_spec:
  for +origins: List<&2, String>
  for +scheme: Maybe<&2, String>
  for +method: Request.Method
  for +content_type: Maybe<&2, String>
  for +site: Maybe<&2, String>
  for +origin: Maybe<&2, String>
  for +referer: Maybe<&2, String>
  for +host: Maybe<&2, String>
  {CsrfPolicy.decide(CsrfPolicy.policy(origins, scheme), method, content_type, site, origin, referer, host) == CsrfSpec.allows(CsrfSpec.configured(origins), CsrfSpec.configured_scheme(scheme), method, content_type, site, origin, referer, host) : Bool}

# BND-19: enumerate capture names from compiled segments, never source guessing.
law manifest_capture_names:
  for +segments: List<&2, Pattern.Segment>
  {Manifest.names(segments) == ManifestSpec.names(segments) : List<&2, String>}

# Exactly the explicit certified routes, normalized methods and ordered names.
# ALL remains a distinct row; duplicates and registration order are preserved.
law manifest_exact_routes:
  for -Tag: Data
  for +sources: List<&2, Methods.Registration(Tag)>
  for +compiled: Methods.Index<Tag>
  for +layers: List<&2, Table.Middleware<Tag>>
  for +count: Nat
  {Manifest.rows(Tag, Table.Table{sources, compiled, layers, count}) == ManifestSpec.describe(Tag, sources, Methods.raw(Tag, Methods.index_valid(Tag, compiled))) : List<&2, Manifest.Row>}

# A successful build lists exactly the route declarations of its entries, in
# entry order with duplicates: each route's full assembled source path, its
# methods as registration normalizes them (ALL as one distinct row, no implicit
# HEAD) and the capture names of its own compiled source. Hooks and middleware
# add no rows. The specification reads the entries, never the built table.
law manifest_built_routes:
  for -Tag: Data
  for +entries: List<&2, Table.Entry<Tag>>
  for +table: Table.Table<Tag>
  for built: {Table.build(Tag, entries) == Done{table} : Result<&2, &2, Methods.BuildError, Table.Table<Tag>>}
  {Manifest.rows(Tag, table) == ManifestBuiltSpec.enumerate(Tag, entries) : List<&2, Manifest.Row>}


# BND-48: incremental writes use the existing proven chunked framing, over
# every admissible partition (including empty chunks), with suffix preservation.
law stream_roundtrip:
  for +chunks: List<&2, List<&2, U32>>
  for +limit: U32
  for +suffix: List<&2, U32>
  for valid: {Chunked.admissible(chunks, limit) == True{} : Bool}
  {Chunked.decode(Bytes.append(StreamFraming.wire(chunks), suffix), limit) == Chunked.Decoded{List.concat(&2, U32, chunks), [], suffix} : Chunked.DecodeResult}

law stream_empty_chunk:
  {StreamFraming.chunk([]) == [] : List<&2, U32>}

# The actual single-chunk writes compose to the canonical sequence above.
law stream_chunk_tail:
  for +bytes: List<&2, U32>
  for +tail: List<&2, U32>
  {Bytes.append(StreamFraming.chunk(bytes), tail) == Chunked.encode_chunk(bytes, tail) : List<&2, U32>}

# BND-48: successful finite body-bearing streams satisfy the independent
# RFC 9112 section 7.1 grammar (lowercase hex, no extensions or trailers).
# The U32 limit bounds the total payload here, not the runtime chunk maximum.
law stream_rfc_roundtrip:
  for +chunks: List<&2, List<&2, U32>>
  for +limit: U32
  for +suffix: List<&2, U32>
  for valid: {Chunked.admissible(chunks, limit) == True{} : Bool}
  {StreamRfc.parse(Bytes.append(StreamFraming.wire(chunks), suffix), limit) == StreamRfc.Decoded{List.concat(&2, U32, chunks), suffix} : StreamRfc.DecodeResult}

# The first last-chunk ends parsing. Even a suffix that looks like more data
# chunks remains untouched, rather than being accepted as part of this body.
law stream_rfc_last_chunk:
  for +limit: U32
  for +suffix: List<&2, U32>
  {StreamRfc.parse(48 <> 13 <> 10 <> 13 <> 10 <> suffix, limit) == StreamRfc.Decoded{[], suffix} : StreamRfc.DecodeResult}

# BND-41: RFC 9110 weak If-None-Match comparison for arbitrary fields and tags.
# The independent specification validates every list member and separately
# asks whether any entity-tag denotes the same opaque validator.
law conditional_if_none_match_spec:
  for +field: Maybe<&2, String>
  for +tag: String
  {Conditional.matches(field, tag) == LimitsSpec.matches(field, tag) : Bool}

# Exactly cache metadata, in original order (including duplicates); no body,
# representation witness or content/framing headers survive construction.
law conditional_304_spec:
  for +res: Response.Res
  {Conditional.not_modified(res) == LimitsSpec.response(res) : Response.Res}

# Accept exactly the inclusive byte-length boundary, for every natural length.
law body_limit_spec:
  for +length: Nat
  for +limit: Nat
  {BodyLimit.accepts(length, limit) == LimitsSpec.within(length, limit) : Bool}

# The actual middleware decision preserves every ineligible response exactly.
# Eligible buffered 200 GET/HEAD responses carry the body validator, and become
# exactly Conditional.not_modified iff the independent field spec matches it.
law etag_middleware_spec:
  for +method: Request.Method
  for +field: Maybe<&2, String>
  for +res: Response.Res
  {ETag.decide(method, field, res) == LimitsSpec.etag(method, field, res) : Response.Res}

# BND-49: Server-Sent Events, checked against the independent WHATWG HTML
# event-stream parser in proof/sse-spec.bend (Base only). Over every list of
# admissible frames, with arbitrary text data: each message reports its retry
# value as a number, then one event with its type, its data with every CR, LF
# and CRLF read as one LF, and the last event id in force. Comments
# (heartbeats) report nothing. Admissible: every field is exactly the UTF-8 of
# Unicode scalar values (so a browser's UTF-8 decoding replaces nothing and
# the parsed octets are the UTF-8 of its text), no CR or LF in an event name,
# id or comment, and no NUL in an id.
law sse_roundtrip:
  for +frames: List<&2, Sse.Frame>
  for valid: {SseModel.admissible(frames) == True{} : Bool}
  {SseSpec.parse(Sse.wire(frames)) == SseModel.observe(frames, []) : List<&2, SseSpec.Observed>}

# The runtime sends exactly the admissible frames, unchanged, and rejects
# every other frame whole: no stripping, escaping or truncation.
law sse_encode_rejects_unsafe:
  for +frame: Sse.Frame
  {Sse.encode(frame) == SseModel.guard(frame) : Maybe<&2, List<&2, U32>>}

# No injection, for any frame: whatever octets the runtime sends parse as
# exactly that frame's observations and nothing else.
law sse_sent_frame_exact:
  for +frame: Sse.Frame
  for +bytes: List<&2, U32>
  for sent: {Sse.encode(frame) == Some{bytes} : Maybe<&2, List<&2, U32>>}
  {SseSpec.parse(bytes) == SseModel.observe([frame], []) : List<&2, SseSpec.Observed>}

# A heartbeat comment at any line start, mid-event included, leaves the
# parser's buffers and every later observation unchanged.
law sse_heartbeat_ignored:
  for +buffers: SseSpec.Buffers
  for +text: List<&2, U32>
  for +rest: List<&2, U32>
  for clean: {SseModel.one_line(text) == True{} : Bool}
  {SseSpec.run(Bytes.append(Sse.render(Sse.Comment{text}), rest), SseSpec.Begin{buffers}) == SseSpec.run(rest, SseSpec.Begin{buffers}) : SseSpec.State}

# Admissibility excludes no text: every String of Unicode scalar values, as
# B.sse_message encodes it, passes the UTF-8 check.
law sse_text_utf8:
  for +s: String
  for +valid: {Utf8.valid(s) == True{} : Bool}
  {SseModel.utf8_ok(Response.utf8(s)) == True{} : Bool}

# Retry renders as ASCII digits whose base-ten value is the number sent.
law sse_retry_decimal:
  for +ms: U32
  {SseSpec.digits(Sse.decimal(ms)) == True{} : Bool}

law sse_retry_value:
  for +ms: U32
  {SseSpec.decimal_value(Sse.decimal(ms), 0n) == U32.to_nat(ms) : Nat}

# BND-40: CORS. The grant (the Access-Control-Allow-Origin value and whether
# credentials are allowed) equals CorsSpec.grant for every policy and Origin
# field: a wildcard policy answers "*" without credentials; a listed policy
# answers only a request whose single Origin field serializes to a configured
# origin, echoing it with that entry's credentials flag.
law cors_grant_spec:
  for +origins: CorsPolicy.Origins
  for +sent: CorsPolicy.Sent
  {CorsPolicy.grant(origins, sent) == CorsSpec.grant(origins, sent) : Maybe<&2, CorsPolicy.Grant>}

# A wildcard policy never allows credentials, whatever the request.
law cors_wildcard_never_credentials:
  for +sent: CorsPolicy.Sent
  {CorsPolicy.grant(CorsPolicy.Any{}, sent) == Some{CorsPolicy.Grant{"*", False{}}} : Maybe<&2, CorsPolicy.Grant>}

# A listed policy denies a request without a usable origin: no Origin, a
# repeated Origin, "null", or anything that is not a bare http or https
# origin. It never falls back to "*".
law cors_listed_denies_unusable_origin:
  for +es: List<&2, CorsPolicy.Entry>
  for +sent: CorsPolicy.Sent
  for h: {CorsSpec.request_origin(sent) == None{} : Maybe<&2, String>}
  {CorsPolicy.grant(CorsPolicy.Listed{es}, sent) == None{} : Maybe<&2, CorsPolicy.Grant>}

# Whatever a listed policy grants, with or without credentials, names exactly
# the request's own serialized origin.
law cors_listed_grant_echoes_origin:
  for +es: List<&2, CorsPolicy.Entry>
  for +sent: CorsPolicy.Sent
  for +o: String
  for +c: Bool
  for h: {CorsPolicy.grant(CorsPolicy.Listed{es}, sent) == Some{CorsPolicy.Grant{o, c}} : Maybe<&2, CorsPolicy.Grant>}
  {CorsSpec.request_origin(sent) == Some{o} : Maybe<&2, String>}

# Configured origins are compared as their URL origins, in order; entries
# that are not http or https URLs (including "*" and "null") are dropped.
law cors_configured_origins:
  for +xs: List<&2, CorsPolicy.Entry>
  {CorsPolicy.listed(xs) == CorsPolicy.Listed{CorsSpec.configured(xs)} : CorsPolicy.Origins}

# A preflight is exactly OPTIONS with an Origin field and an
# Access-Control-Request-Method field; every other request, including other
# OPTIONS requests, reaches the application.
law cors_preflight_spec:
  for +method: Request.Method
  for +sent: CorsPolicy.Sent
  for +requests_method: Bool
  {CorsPolicy.preflight(method, sent, requests_method) == CorsSpec.preflight(method, sent, requests_method) : Bool}

# A preflight answer carries exactly the granted origin, credentials when
# granted, the configured methods, the configured (or else reflected) headers
# and the configured max age, in that order; a denied origin gets no CORS
# field.
law cors_preflight_fields_spec:
  for +config: CorsPolicy.Config
  for +g: Maybe<&2, CorsPolicy.Grant>
  for +reflected: Maybe<&2, String>
  {CorsPolicy.preflight_fields(config, g, reflected) == CorsSpec.preflight_fields(config, g, reflected) : List<&2, CorsPolicy.Field>}

# An ordinary response carries exactly the granted origin, credentials when
# granted and the exposed headers; a denied origin gets no CORS field.
law cors_actual_fields_spec:
  for +config: CorsPolicy.Config
  for +g: Maybe<&2, CorsPolicy.Grant>
  {CorsPolicy.actual_fields(config, g) == CorsSpec.actual_fields(config, g) : List<&2, CorsPolicy.Field>}

# The CORS policy a request retains, applied at finalization to whatever
# response reached it, equals CorsResponseSpec.response for every
# configuration, request and response. The grant, the preflight
# classification and the requested headers are read from the request's own
# fields (missing, single or repeated). Status, body, representation and
# unrelated fields stay as they were; every downstream copy of the six CORS
# fields, in any case, is dropped; then the complete preflight or actual
# field set follows, then the Vary merge.
law cors_response_spec:
  for +config: CorsPolicy.Config
  for +req: Request.Req
  for +res: Response.Res
  {ResponsePolicy.apply(CorsRequest.policy(config, req), res) == CorsResponseSpec.response(config, req, res) : Response.Res}

# A listed-origin CORS response always ends with exactly one Vary field that
# covers Origin: "*" when downstream Vary listed "*", otherwise every
# downstream Vary value byte for byte followed by Origin (and, for a
# reflecting preflight, Access-Control-Request-Headers) unless already listed.
# Vary fields are found without regard to name case.
law cors_vary_origin:
  for +es: List<&2, CorsPolicy.Entry>
  for +methods: List<&2, String>
  for +headers: List<&2, String>
  for +expose: List<&2, String>
  for +max_age: Maybe<&2, Nat>
  for +req: Request.Req
  for +res: Response.Res
  {ResponsePolicySpec.vary_values(ResponsePolicySpec.headers(ResponsePolicy.apply(CorsRequest.policy(CorsPolicy.Config{CorsPolicy.Listed{es}, methods, headers, expose, max_age}, req), res))) == ResponsePolicySpec.vary_result(ResponsePolicySpec.vary_values(ResponsePolicySpec.headers(res)), "Origin" <> CorsResponseSpec.request_header_names(CorsResponseSpec.preflight(req), headers)) : List<&2, List<&2, U32>>}

# Adding names to Vary equals the independent merge for every field list.
law vary_add_spec:
  for +hs: List<&2, Request.Header>
  for +names: List<&2, String>
  {Vary.add(hs, names) == ResponsePolicySpec.vary_add(hs, names) : List<&2, Request.Header>}

# The default security policy, applied to any response, keeps status, body,
# representation and every unrelated field, drops every copy of the eleven
# default fields and of X-Powered-By in any case, and appends the eleven
# literal defaults once each.
law secure_headers_defaults_spec:
  for +res: Response.Res
  {ResponsePolicy.apply(SecureHeaders.policy(SecureHeaders.defaults()), res) == SecureHeadersSpec.secured(res) : Response.Res}

# BND-40: method override. A rewrite happens only for a POST.
law override_rewrites_only_post:
  for +allowed: List<&2, Request.Method>
  for +wire: Request.Method
  for +values: List<&2, String>
  for +m: Request.Method
  for h: {OverridePolicy.decide(allowed, wire, values) == OverridePolicy.Rewrite{m} : OverridePolicy.Outcome}
  {OverrideSpec.is_post(wire) == True{} : Bool}

# A rewrite never produces GET or HEAD, so CSRF protection still inspects
# the rewritten request.
law override_never_safe_destination:
  for +allowed: List<&2, Request.Method>
  for +wire: Request.Method
  for +values: List<&2, String>
  for +m: Request.Method
  for h: {OverridePolicy.decide(allowed, wire, values) == OverridePolicy.Rewrite{m} : OverridePolicy.Outcome}
  {CsrfSpec.reads_only(m) == False{} : Bool}

# A rewrite produces only a method on the configured allowlist.
law override_destination_listed:
  for +allowed: List<&2, Request.Method>
  for +wire: Request.Method
  for +values: List<&2, String>
  for +m: Request.Method
  for h: {OverridePolicy.decide(allowed, wire, values) == OverridePolicy.Rewrite{m} : OverridePolicy.Outcome}
  {OverrideSpec.listed(m, allowed) == True{} : Bool}

# A POST with two or more override values is rejected.
law override_rejects_repeated:
  for +allowed: List<&2, Request.Method>
  for +v: String
  for +w: String
  for +rest: List<&2, String>
  {OverridePolicy.decide(allowed, Request.Post{}, v <> (w <> rest)) == OverridePolicy.Reject{} : OverridePolicy.Outcome}

# Any other method is kept as sent.
law override_keeps_non_post:
  for +allowed: List<&2, Request.Method>
  for +wire: Request.Method
  for +values: List<&2, String>
  for h: {OverrideSpec.is_post(wire) == False{} : Bool}
  {OverridePolicy.decide(allowed, wire, values) == OverridePolicy.Keep{} : OverridePolicy.Outcome}

# A rewrite never produces a method whose name is GET, HEAD, OPTIONS,
# CONNECT or TRACE, so no extension method can stand in for one by spelling.
law override_never_safe_name:
  for +allowed: List<&2, Request.Method>
  for +wire: Request.Method
  for +values: List<&2, String>
  for +m: Request.Method
  for h: {OverridePolicy.decide(allowed, wire, values) == OverridePolicy.Rewrite{m} : OverridePolicy.Outcome}
  {OverrideSpec.named_safe(Request.method_text(m)) == False{} : Bool}

# The whole decision equals OverrideSpec.decide: a non-POST and a POST
# without a value are kept; two or more values are rejected; one value is
# trimmed, an empty one keeps the request, and otherwise its uppercase method
# m keeps POST, rewrites to exactly m when m is listed and not a safe name,
# and is rejected in every other case.
law override_decision_spec:
  for +allowed: List<&2, Request.Method>
  for +wire: Request.Method
  for +values: List<&2, String>
  {OverridePolicy.decide(allowed, wire, values) == OverrideSpec.decide(allowed, wire, values) : OverridePolicy.Outcome}

# A configured allowlist never contains GET or HEAD.
law override_allowlist_unsafe:
  for +xs: List<&2, String>
  {OverrideSpec.all_unsafe(OverridePolicy.allowlist(xs)) == True{} : Bool}

# BND-40: trailing slash. Every redirect target is a same-origin path: one
# leading '/', never "//" and no character a browser strips or reads as '/'.
law trailing_redirect_same_origin:
  for +mode: TrailingPolicy.Mode
  for +m: Request.Method
  for +path: String
  for +q: Maybe<&2, String>
  for +loc: String
  for h: {TrailingPolicy.target(mode, m, path, q) == Some{loc} : Maybe<&2, String>}
  {TrailingSpec.same_origin_path(loc) == True{} : Bool}

# Only GET and HEAD are redirected.
law trailing_redirect_reads_only:
  for +mode: TrailingPolicy.Mode
  for +m: Request.Method
  for +path: String
  for +q: Maybe<&2, String>
  for +loc: String
  for h: {TrailingPolicy.target(mode, m, path, q) == Some{loc} : Maybe<&2, String>}
  {CsrfSpec.reads_only(m) == True{} : Bool}

# The full target equals TrailingSpec.target: only GET and HEAD move; trim
# moves a path ending in '/' to the text before it, append moves a path not
# ending in '/' to the path plus '/'; the raw query is kept; the result is
# offered only when it is a same-origin path. Every other request has none.
law trailing_target_spec:
  for +mode: TrailingPolicy.Mode
  for +m: Request.Method
  for +path: String
  for +q: Maybe<&2, String>
  {TrailingPolicy.target(mode, m, path, q) == TrailingSpec.target(mode, m, path, q) : Maybe<&2, String>}

# "/" is never trimmed.
law trailing_trim_keeps_root:
  for +m: Request.Method
  for +q: Maybe<&2, String>
  {TrailingPolicy.target(TrailingPolicy.Trim{}, m, "/", q) == None{} : Maybe<&2, String>}

# Trimming a GET or HEAD for base + "/" targets base with the raw query
# unchanged, whenever that target is a same-origin path.
law trailing_trim_target:
  for +base: String
  for +q: Maybe<&2, String>
  for +m: Request.Method
  for r: {CsrfSpec.reads_only(m) == True{} : Bool}
  for ok: {TrailingSpec.same_origin_path(base ++ Request.query_text(q)) == True{} : Bool}
  {TrailingPolicy.target(TrailingPolicy.Trim{}, m, base ++ "/", q) == Some{base ++ Request.query_text(q)} : Maybe<&2, String>}

# Appending to a GET or HEAD whose path does not end in '/' targets path +
# "/" with the raw query unchanged, whenever that target is a same-origin path.
law trailing_append_target:
  for +path: String
  for +q: Maybe<&2, String>
  for +m: Request.Method
  for r: {CsrfSpec.reads_only(m) == True{} : Bool}
  for ends: {TrailingSpec.final_slash(path) == False{} : Bool}
  for ok: {TrailingSpec.same_origin_path(path ++ ("/" ++ Request.query_text(q))) == True{} : Bool}
  {TrailingPolicy.target(TrailingPolicy.Append{}, m, path, q) == Some{path ++ ("/" ++ Request.query_text(q))} : Maybe<&2, String>}

# BND-45: static files (docs/static.md).
#
# `raw` is any request path after the mount prefix, undecoded, and `index`
# any index file name. StaticSpec (proof/static-spec.bend) shares no code
# with the resolver: it splits the relative path on '/' with Base's
# String.split and requires every piece to be nonempty, not ".", not "..",
# and free of control characters (NUL included), DEL, backslash and '%'.
# With no '%' left after one decoding, no encoded separator or second
# encoding survives. static_path_confined also requires the segment count
# to equal the raw path's count after its leading '/'. A count alone does
# not show that decoding added no separator ("/a%2Fb/c" and "a/b" have
# matching counts); static_path_segments does, segment by segment.

# LAW: no request path resolves outside the static root. Every resolution
# is refused, or is a relative path made only of in-root segments.
law static_path_confined:
  for +raw: String
  for +index: String
  {StaticSpec.confined(raw, StaticPath.resolve(raw, index)) == True{} : Bool}

# LAW: the path handed to the open effect is root ++ "/" ++ the resolved
# relative path, and nothing is opened for a refused one. The effect opens
# root, then walks each '/'-separated segment beneath it without following
# symlinks (src/effects/static_file.c).
law static_path_target:
  for root: String
  for +raw: String
  for +index: String
  {StaticPath.target(root, raw, index) == StaticSpec.opened(root, StaticPath.resolve(raw, index)) : Maybe<&2, String>}

# LAW: each piece of a resolution is the decoding of exactly one raw
# segment, in order. If `raw` resolves to `rel`, splitting `rel` on '/'
# gives the raw path's segments after its leading '/', each decoded on its
# own (StaticSpec.decoded), with an empty final segment replaced by `index`.
# Since no piece contains '/', decoding added no separator.
law static_path_segments:
  for +raw: String
  for +index: String
  {StaticSpec.resolved_pieces(StaticPath.resolve(raw, index)) == StaticSpec.when_resolved(StaticPath.resolve(raw, index), StaticSpec.decoded(raw, index)) : Maybe<&2, List<&2, String>>}

# LAW: no resolution has a piece starting with '.', so dotfiles and dot
# directories such as .env and .git are never served.
law static_path_no_dotfiles:
  for +raw: String
  for +index: String
  {StaticSpec.no_dotfiles(StaticPath.resolve(raw, index)) == True{} : Bool}

# LAW: the resolver is not empty. Servable segments (nonempty printable
# ASCII without space, '%', '/' or '\', not starting with '.') written as
# "/first/rest..." resolve to the same segments joined by '/'.
law static_path_complete:
  for +first: String
  for +rest: List<&2, String>
  for +index: String
  for servable: {StaticSpec.servable(first <> rest) == True{} : Bool}
  {StaticPath.resolve(StaticSpec.request(first <> rest), index) == Some{StaticSpec.joined(rest, first)} : Maybe<&2, String>}

# LAW: a trailing slash names the index. Servable segments written as
# "/xs.../" ("/" for none) resolve to those segments followed by `index`,
# when `index` is itself a servable segment.
law static_path_index:
  for +xs: List<&2, String>
  for +index: String
  for servable: {StaticSpec.servable(xs) == True{} : Bool}
  for named: {StaticSpec.servable_segment(index) == True{} : Bool}
  {StaticPath.resolve(StaticSpec.directory(xs), index) == Some{StaticSpec.joined_index(xs, index)} : Maybe<&2, String>}

# BND-37: route schemas never change the manifest's rows. A successful
# attachment lists exactly the version-1 rows of the specification, in
# registration order with duplicates, so schemas are purely additive.
law manifest_schema_rows:
  for -Tag: Data
  for +sources: List<&2, Methods.Registration(Tag)>
  for +compiled: Methods.Index<Tag>
  for +layers: List<&2, Table.Middleware<Tag>>
  for +count: Nat
  for +schemas: List<&2, RouteSchemas.RouteSchemas>
  for +attached: List<&2, ManifestSchemas.Attached>
  for done: {ManifestSchemas.attach(Tag, Table.Table{sources, compiled, layers, count}, schemas) == Done{attached} : Result<&2, &2, ManifestSchemas.AttachError, List<&2, ManifestSchemas.Attached>>}
  {ManifestSchemas.attached_rows(attached) == ManifestSpec.describe(Tag, sources, Methods.raw(Tag, Methods.index_valid(Tag, compiled))) : List<&2, Manifest.Row>}

# Schemas are positional: entry i belongs to registration i and appears on
# every row that registration prints (one per method), so duplicate
# registrations keep their own schemas.
law manifest_schema_positions:
  for -Tag: Data
  for +sources: List<&2, Methods.Registration(Tag)>
  for +compiled: Methods.Index<Tag>
  for +layers: List<&2, Table.Middleware<Tag>>
  for +count: Nat
  for +schemas: List<&2, RouteSchemas.RouteSchemas>
  for +attached: List<&2, ManifestSchemas.Attached>
  for done: {ManifestSchemas.attach(Tag, Table.Table{sources, compiled, layers, count}, schemas) == Done{attached} : Result<&2, &2, ManifestSchemas.AttachError, List<&2, ManifestSchemas.Attached>>}
  {ManifestSchemas.attached_schemas(attached) == ManifestSchemaSpec.spread(Tag, sources, Methods.raw(Tag, Methods.index_valid(Tag, compiled)), schemas) : List<&2, RouteSchemas.RouteSchemas>}

# Attachment succeeds exactly when there is one entry per registration and
# every slot that is set holds a valid schema.
law manifest_schema_accepted:
  for -Tag: Data
  for +sources: List<&2, Methods.Registration(Tag)>
  for +compiled: Methods.Index<Tag>
  for +layers: List<&2, Table.Middleware<Tag>>
  for +count: Nat
  for +schemas: List<&2, RouteSchemas.RouteSchemas>
  {ManifestSchemaSpec.accepted(ManifestSchemas.attach(Tag, Table.Table{sources, compiled, layers, count}, schemas)) == (Nat.is_eq(List.length(&2, Methods.Registration(Tag), sources), List.length(&2, RouteSchemas.RouteSchemas, schemas)) && ManifestSchemaSpec.all_valid(schemas)) : Bool}

# BND-37: the decoder rejects every input for an invalid schema, so its JSON
# Schema is `not: {}`, which accepts nothing.
law json_schema_invalid_rejects_all:
  for +schema: Schema.Schema
  for bad: {Schema.valid(schema) == False{} : Bool}
  {JsonSchemaSpec.keyword(JsonSchema.export(schema), "not") == Some{Json.JObject{[]}} : Maybe<&2, Json.Json>}

# A valid schema exports its node, the same function that exports every
# child, so the node laws below hold at every depth of an export.
law json_schema_valid_exports_node:
  for +schema: Schema.Schema
  for ok: {Schema.valid(schema) == True{} : Bool}
  {JsonSchema.export(schema) == JsonSchema.go(schema, JsonSchema.start(schema)) : Json.Json}

# Every node's "type" names the JSON type its kind requires; literal, enum,
# nullable and union nodes have none.
law json_schema_type_keyword:
  for +schema: Schema.Schema
  {JsonSchemaSpec.keyword(JsonSchema.go(schema, JsonSchema.start(schema)), "type") == JsonSchemaSpec.type_of(schema) : Maybe<&2, Json.Json>}

# An object requires exactly its Required keys, in order: optional and
# defaulted fields are never required.
law json_schema_required_keys:
  for +fields: List<&2, Schema.Field>
  for +unknown: Schema.Unknown
  {JsonSchemaSpec.keyword(JsonSchema.go(Schema.ObjectSchema{fields, unknown}, JsonSchema.start(Schema.ObjectSchema{fields, unknown})), "required") == Some{Json.JArray{JsonSchemaSpec.required(fields)}} : Maybe<&2, Json.Json>}

# Strict objects export additionalProperties false; Strip objects true.
law json_schema_unknown_keys:
  for +fields: List<&2, Schema.Field>
  for +unknown: Schema.Unknown
  {JsonSchemaSpec.keyword(JsonSchema.go(Schema.ObjectSchema{fields, unknown}, JsonSchema.start(Schema.ObjectSchema{fields, unknown})), "additionalProperties") == Some{Json.JBool{JsonSchemaSpec.allows_unknown(unknown)}} : Maybe<&2, Json.Json>}

# A string's top-level pattern is the ECMAScript source of its own pattern,
# absent without one, and maxLength is its upper bound, absent without one.
law json_schema_string_pattern:
  for +min: Nat
  for +max: Maybe<&2, Nat>
  for +pattern: Maybe<&2, SchemaPattern.Pattern>
  for +format: Schema.Format
  {JsonSchemaSpec.keyword(JsonSchema.go(Schema.StringSchema{min, max, pattern, format}, JsonSchema.start(Schema.StringSchema{min, max, pattern, format})), "pattern") == JsonSchemaSpec.pattern_of(pattern) : Maybe<&2, Json.Json>}

law json_schema_string_max_length:
  for +min: Nat
  for +max: Maybe<&2, Nat>
  for +pattern: Maybe<&2, SchemaPattern.Pattern>
  for +format: Schema.Format
  {JsonSchemaSpec.keyword(JsonSchema.go(Schema.StringSchema{min, max, pattern, format}, JsonSchema.start(Schema.StringSchema{min, max, pattern, format})), "maxLength") == JsonSchemaSpec.upper_of(max) : Maybe<&2, Json.Json>}

# Every string node rejects lone surrogates, which the decoder never accepts.
law json_schema_string_wellformed:
  for +min: Nat
  for +max: Maybe<&2, Nat>
  for +pattern: Maybe<&2, SchemaPattern.Pattern>
  for +format: Schema.Format
  {JsonSchemaSpec.keyword(JsonSchema.go(Schema.StringSchema{min, max, pattern, format}, JsonSchema.start(Schema.StringSchema{min, max, pattern, format})), "not") == Some{Json.JObject{[Json.Field{"pattern", Json.JString{JsonSchemaSpec.lone()}}]}} : Maybe<&2, Json.Json>}

# Empty enums and unions accept nothing, as an always-false schema rather
# than the invalid `enum: []` or `anyOf: []`.
law json_schema_empty_enum:
  {JsonSchema.go(Schema.EnumSchema{[]}, JsonSchema.start(Schema.EnumSchema{[]})) == Json.JObject{[Json.Field{"not", Json.JObject{[]}}]} : Json.Json}

law json_schema_empty_union:
  {JsonSchema.go(Schema.UnionSchema{[]}, JsonSchema.start(Schema.UnionSchema{[]})) == Json.JObject{[Json.Field{"not", Json.JObject{[]}}]} : Json.Json}

# BND-37: compositional structure and exact annotations, including absence.

law json_schema_object_properties:
  for +fields: List<&2, Schema.Field>
  for +unknown: Schema.Unknown
  {JsonSchemaSpec.keyword(JsonSchema.go(Schema.ObjectSchema{fields, unknown}, JsonSchema.start(Schema.ObjectSchema{fields, unknown})), "properties") == Some{Json.JObject{JsonSchemaSpec.properties(~(+c => JsonSchema.go(c, JsonSchema.start(c))), fields)}} : Maybe<&2, Json.Json>}

law json_schema_literal_const:
  for +value: Json.Json
  {JsonSchema.go(Schema.LiteralSchema{value}, JsonSchema.start(Schema.LiteralSchema{value})) == Json.JObject{[Json.Field{"const", value}]} : Json.Json}

law json_schema_enum_values:
  for +values: List<&2, Json.Json>
  {JsonSchema.go(Schema.EnumSchema{values}, JsonSchema.start(Schema.EnumSchema{values})) == JsonSchemaSpec.enum(JsonSchemaSpec.unique(values, [])) : Json.Json}

law json_schema_array_items_bounds:
  for +child: Schema.Schema
  for +min: Nat
  for +max: Maybe<&2, Nat>
  {JsonSchema.go(Schema.ArraySchema{child, min, max}, JsonSchema.start(Schema.ArraySchema{child, min, max})) == JsonSchemaSpec.array(JsonSchema.go(child, JsonSchema.start(child)), min, max) : Json.Json}

law json_schema_nullable_child:
  for +child: Schema.Schema
  {JsonSchema.go(Schema.NullableSchema{child}, JsonSchema.start(Schema.NullableSchema{child})) == JsonSchemaSpec.nullable(JsonSchema.go(child, JsonSchema.start(child))) : Json.Json}

law json_schema_union_members:
  for +members: List<&2, Schema.Schema>
  {JsonSchema.go(Schema.UnionSchema{members}, JsonSchema.start(Schema.UnionSchema{members})) == JsonSchemaSpec.union(JsonSchemaSpec.nodes(~(+c => JsonSchema.go(c, JsonSchema.start(c))), members)) : Json.Json}

law json_schema_number_bounds:
  for +min: Maybe<&2, String>
  for +max: Maybe<&2, String>
  {JsonSchema.go(Schema.NumberSchema{min, max}, JsonSchema.start(Schema.NumberSchema{min, max})) == JsonSchemaSpec.number("number", min, max, []) : Json.Json}

law json_schema_integer_bounds:
  for +min: Maybe<&2, String>
  for +max: Maybe<&2, String>
  {JsonSchema.go(Schema.IntegerSchema{min, max}, JsonSchema.start(Schema.IntegerSchema{min, max})) == JsonSchemaSpec.number("integer", min, max, [Json.Field{"$comment", Json.JString{"Bendo accepts only integer tokens -?(0|[1-9][0-9]*); 1.0 and 1e0 are rejected"}}]) : Json.Json}

law json_schema_string_min_length:
  for +min: Nat
  for +max: Maybe<&2, Nat>
  for +pattern: Maybe<&2, SchemaPattern.Pattern>
  for +format: Schema.Format
  {JsonSchemaSpec.keyword(JsonSchema.go(Schema.StringSchema{min, max, pattern, format}, JsonSchema.start(Schema.StringSchema{min, max, pattern, format})), "minLength") == Some{Json.JNumber{Nat.show(min)}} : Maybe<&2, Json.Json>}

law json_schema_string_format:
  for +min: Nat
  for +max: Maybe<&2, Nat>
  for +pattern: Maybe<&2, SchemaPattern.Pattern>
  for +format: Schema.Format
  {JsonSchemaSpec.keyword(JsonSchema.go(Schema.StringSchema{min, max, pattern, format}, JsonSchema.start(Schema.StringSchema{min, max, pattern, format})), "allOf") == JsonSchemaSpec.format(format) : Maybe<&2, Json.Json>}

law json_schema_default_annotation:
  for +fields: List<&2, Json.Field>
  for +presence: Schema.Presence
  {JsonSchema.with_default(Json.JObject{fields}, presence) == JsonSchemaSpec.annotate(Json.JObject{fields}, presence) : Json.Json}

# A node acquires a default only when its parent declares Default{value}.
law json_schema_no_default:
  for +schema: Schema.Schema
  {JsonSchemaSpec.keyword(JsonSchema.go(schema, JsonSchema.start(schema)), "default") == None{} : Maybe<&2, Json.Json>}

law json_schema_document_dialect:
  for +schema: Schema.Schema
  {JsonSchema.document(schema) == JsonSchemaSpec.document(JsonSchema.export(schema)) : Json.Json}

# Each attached bundle serializes exactly its present slots as standalone
# 2020-12 documents, or reports the first unwritable slot.
law manifest_schema_documents:
  for +route: Nat
  for +row: Manifest.Row
  for +bundle: RouteSchemas.RouteSchemas
  {ManifestSchemas.attached_json(ManifestSchemas.Attached{route, row, bundle}) == ManifestSchemaSpec.attached(ManifestSchemas.row_open(row), ManifestSchemaSpec.schema_text(ManifestSchemaSpec.documents(~(+c => JsonSchemaSpec.document(JsonSchema.export(c))), ManifestSchemaSpec.document_slots(bundle), route, Done{[]}))) : Result<&2, &2, ManifestSchemas.AttachError, String>}

# Exact outer keys and order rule out duplicate or contradictory keywords.
law json_schema_object_node_exact:
  for +fields: List<&2, Schema.Field>
  for +unknown: Schema.Unknown
  {JsonSchema.go(Schema.ObjectSchema{fields, unknown}, JsonSchema.start(Schema.ObjectSchema{fields, unknown})) == JsonSchemaSpec.object(JsonSchemaSpec.properties(~(+c => JsonSchema.go(c, JsonSchema.start(c))), fields), JsonSchemaSpec.required(fields), unknown) : Json.Json}

law json_schema_string_node_exact:
  for +min: Nat
  for +max: Maybe<&2, Nat>
  for +pattern: Maybe<&2, SchemaPattern.Pattern>
  for +format: Schema.Format
  {JsonSchema.go(Schema.StringSchema{min, max, pattern, format}, JsonSchema.start(Schema.StringSchema{min, max, pattern, format})) == JsonSchemaSpec.string(min, max, pattern, format) : Json.Json}

# A boolean node is exactly {"type": "boolean"}: no other keyword can narrow
# the two values the decoder accepts.
law json_schema_boolean_node_exact:
  {JsonSchema.go(Schema.BooleanSchema{}, JsonSchema.start(Schema.BooleanSchema{})) == Json.JObject{[Json.Field{"type", Json.JString{"boolean"}}]} : Json.Json}

# BND-50: the WebSocket opening handshake (RFC 6455 section 4).

# For every key, Sec-WebSocket-Accept is the padded standard base64 of the
# SHA-1 of the key's octets followed by the RFC's GUID, which the spec spells
# out as literal octets.
# SHA-1 and base64 correctness rest on BND-42's NIST vectors,
# base64_roundtrip, and the RFC example law below.
law websocket_accept_spec:
  for +key: List<&2, U32>
  {WebSocket.accept(key) == WebSocketSpec.accept(key) : String}

# The worked example of RFC 6455 section 1.3.
law websocket_accept_rfc:
  {WebSocket.accept(Bytes.encode("dGhlIHNhbXBsZSBub25jZQ==")) == "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=" : String}

# For every configuration and request, the handshake decision equals
# WebSocketSpec.decide: 400 unless the request is a GET over HTTP/1.1 with no
# Transfer-Encoding and at most one zero Content-Length, a "websocket" Upgrade
# element and an "upgrade" Connection element (ASCII case ignored), and exactly
# one key that is the canonical padded base64 of 16 octets; then 400 for a
# missing or repeated version and 426 for one that is not "13"; then 403 when
# a listed origin policy does not list the single Origin field's
# serialization; otherwise accept with the computed key and the first
# configured subprotocol the client offered, or none.
# Domain: canonical requests with lowercase header names. Origin.canonical
# is shared by the implementation and spec; independent coverage is BND-85.
law websocket_decision_spec:
  for +config: WebSocket.Config
  for +req: Request.Req
  {WebSocket.decide(config, req) == WebSocketSpec.decide(config, req) : WebSocket.Decision}

# The pure opening response names exactly version 13 on a 426.
law websocket_response_version:
  {WebSocket.response(WebSocket.Refuse{426}) == Response.Res{426, [Request.Header{"sec-websocket-version", Bytes.encode("13")}], [], None{}} : Response.Res}

# A successful pure opening response has precisely the RFC fields, with the
# selected protocol present exactly in the Some case (including its value).
law websocket_response_success:
  for +key: List<&2, U32>
  for +protocol: Maybe<&2, String>
  {WebSocket.response(WebSocket.Accept{WebSocket.accept(key), protocol}) == Response.Res{101, Request.Header{"upgrade", Bytes.encode("websocket")} <> (Request.Header{"connection", Bytes.encode("Upgrade")} <> (Request.Header{"sec-websocket-accept", Bytes.encode(WebSocketSpec.accept(key))} <> WebSocketSpec.protocol_field(protocol))), [], None{}} : Response.Res}

# Even arbitrary middleware responses rebuild to an empty 101 with neither
# Content-Length nor Transfer-Encoding, checking field names case-insensitively.
law websocket_rebuilt_framing:
  for +res: Response.Res
  for +accept: String
  for +protocol: Maybe<&2, String>
  {WebSocketSpec.frameless(WebSocketTransport.rebuilt(res, accept, protocol)) == True{} : Bool}

# Every middleware field survives unchanged, in its original order and with
# duplicates intact, except handshake-owned fields, framing and the marker.
# The independent spec puts the computed handshake first, with no body or rep.
law websocket_rebuilt_response:
  for +res: Response.Res
  for +accept: String
  for +protocol: Maybe<&2, String>
  {WebSocketTransport.rebuilt(res, accept, protocol) == WebSocketSpec.rebuilt(res, accept, protocol) : Response.Res}

# Pure refusal responses are empty; the context layer supplies error bodies.
law websocket_response_refuse_400:
  {WebSocket.response(WebSocket.Refuse{400}) == Response.Res{400, [], [], None{}} : Response.Res}

law websocket_response_refuse_403:
  {WebSocket.response(WebSocket.Refuse{403}) == Response.Res{403, [], [], None{}} : Response.Res}

# BND-28: every scalar-string, lexical-number JSON tree with at most 512
# nested containers serializes successfully and survives strict byte parsing.
# Pretty printing and ASCII Unicode escaping are independently quantified.

law json_roundtrip:
  for +value: Json.Json
  for +pretty: Bool
  for +ascii: Bool
  for +valid: {Json.admissible(value) == True{} : Bool}
  exs output: String
  {Json.write(value, pretty, ascii) == Done{output} : Result<&2, &2, Json.Error, String>} &
  {Json.parse(Utf8.encode(output)) == Done{value} : Result<&2, &2, Json.Error, Json.Json>}
