# Bendo's laws. A human states each law; PROOF.bend proves it.
# Agents may add laws. Never delete or weaken one without a written reason
# in the pull request.
import Base
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
