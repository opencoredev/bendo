# Bendo's laws. A human states each law; PROOF.bend proves it.
# Agents may add laws. Never delete or weaken one without a written reason
# in the pull request.
import Base

# BND-31
import ./proof/cookie-ows-laws.bend as CookieOwsLaws
import ./proof/cookie-serialization-laws.bend as CookieSerializationLaws
import ./src/data/cookie.bend as Cookie
import ./proof/cookie-spec.bend as CookieSpec
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

import ./src/router/spec.bend as Spec
import ./src/router/spec-proofs.bend as SpecProof

import ./src/router/methods.bend as Methods
import ./src/router/methods-proofs.bend as MethodProof

import ./src/router/trie.bend as Trie
import ./src/router/router.bend as Router

import ./src/data/hex.bend as Hex
import ./src/data/base64.bend as Base64
import ./src/crypto/octets.bend as Octets

import ./src/http/date.bend as HttpDate
import ./proof/date-spec.bend as HttpDateSpec

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
# final optional capture may be omitted, and a wildcard may hold an empty value.
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
# independent token-membership predicate at each List.get registration.
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
# combination and query-method token is covered.
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

# BND-33: scalar decoding agrees with an independent specification for EVERY
# schema and Json tree, including malformed schemas and constructed data.
# SchemaSpec restates each rule from docs/data/schema.md (scalar counts, the
# RFC 8259 number grammar, exact decimal values, patterns as regular languages
# with a size cap, email and URL grammars) and calls no decoder helper.
# Equality proves both soundness (accepted implies satisfies) and completeness.

law schema_acceptance_iff:
  for +schema: Schema.Schema
  for +value: Json.Json
  {Schema.accepted(Schema.decode(schema, value)) == SchemaSpec.satisfies(schema, value) : Bool}

# Every success has the right typed constructor AND preserves the exact input
# payload, including decimal spelling. Failures impose no payload obligation.
law schema_preserves_typed_value:
  for +schema: Schema.Schema
  for +value: Json.Json
  Schema.Preserves(Schema.value_for(schema, value), Schema.decode(schema, value))

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

