# Proofs of LAWS.bend. Run: bend PROOF.bend --verdict
import Base

# BND-32
import ./proof/signed-cookie.bend as SignedCookieProof

# BND-31
import ./proof/cookie-ows.bend as CookieOwsProof
import ./proof/cookie-serialization.bend as CookieSerializationProof
import ./proof/cookies.bend as CookieProof
import ./src/app/table.bend as Table
import ./proof/middleware-selection-spec.bend as MiddlewareSelectionSpec
import ./proof/lifecycle-selection.bend as LifecycleSelection
import ./proof/scoped-selection.bend as ScopedSelection
import ./proof/scoped-assembly.bend as Assembly
import ./proof/scoped-assembly-spec.bend as AssemblySpec
import ./src/app/scopes.bend as Scopes
import ./proof/middleware-selection.bend as MiddlewareSelection

import ./proof/schema.bend as SchemaProof
import ./src/data/schema.bend as Schema
import ./src/http/response.bend as Response
import ./src/http/write_response.bend as WriteResponse

import ./src/http/chunked.bend as Chunked
import ./src/http.bend as Http
import ./src/http/bytes.bend as Bytes
import ./src/http/request.bend as Request
import ./src/http/parse.bend as Parse
import ./src/http/write.bend as Write
import ./LAWS.bend as Laws
import ./proof/equality.bend as Equality
import ./proof/tokens.bend as Tokens
import ./proof/headers.bend as Headers
import ./proof/line.bend as Line
import ./proof/scanner.bend as Scanner
import ./proof/printable.bend as Printable
import ./proof/support.bend as Support
import ./src/data/urlencoded.bend as Form
import ./src/data/utf8.bend as Utf8
import ./proof/forms.bend as FormSpec
import ./proof/percent.bend as Percent
import ./proof/utf8.bend as Utf8Proof

import ./proof/response-lines.bend as ResponseLines
import ./proof/response-framing.bend as ResponseFraming
import ./proof/response-absence.bend as ResponseAbsence
import ./proof/response-runtime.bend as ResponseRuntime
import ./proof/response-fields.bend as ResponseFields
import ./proof/response-status.bend as ResponseStatus
import ./proof/response-spec-proof.bend as ResponseSpecProof
import ./proof/response-spec.bend as ResponseSpec
import ./proof/response-framing-spec.bend as ResponseFramingSpec

import ./proof/chunked.bend as ChunkedProof
import ./proof/chunked-roundtrip.bend as ChunkedRoundtrip

import ./src/router/proofs.bend as PatternProof
import ./src/router/pattern.bend as Pattern
import ./src/router/compile-proofs.bend as CompileProof
import ./src/router/equality-proofs.bend as EqualityProof
import ./src/router/match-proofs.bend as MatchProof

import ./src/router/spec.bend as Spec
import ./src/router/spec-proofs.bend as SpecProof

import ./src/router/methods.bend as Methods
import ./src/router/methods-proofs.bend as MethodProof

import ./src/router/trie.bend as Trie
import ./src/router/router.bend as Router
import ./src/router/trie-proofs.bend as TrieProof
import ./src/router/methods-trie-proofs.bend as MethodTrieProof

import ./proof/crypto-hex.bend as HexProof
import ./proof/crypto-base64.bend as Base64Proof

# Check the pure crypto implementations with the strict kernel as well.
import ./src/crypto/sha1.bend as SHA1
import ./src/crypto/sha256.bend as SHA256
import ./src/crypto/hmac.bend as HMAC
import ./src/crypto/compare.bend as Compare

def Laws.text_body_after_blank(body):
  ("HTTP/1.1 200 OK\r\nContent-Type: text/plain; charset=utf-8\r\nConnection: close", ({==}, {==}))

def Laws.path_of_request_line():
  {==}

# BND-7: proofs of universal request-head guarantees.

def Laws.header_lookup_case_insensitive(headers, name, variant, same):
  %same : {Request.lookup_folded(headers, Bytes.fold(name)) == Request.lookup_folded(headers, _) : List<&2, List<&2, U32>>}
  {==}

# Mapping values over the independent selection agrees for either decision.
def selected_values(+n: String, +v: List<&2, U32>, +hs: List<&2, Request.Header>, same: Bool) -> {Request.lookup_step(v, Support.header_values(hs), same) == Support.header_values(Support.select_header(Request.Header{n, v}, hs, same)) : List<&2, List<&2, U32>>}:
  match same:
    case True{}:
      {==}
    case False{}:
      {==}

def lookup_selected(+hs: List<&2, Request.Header>, +name: String) -> {Request.lookup_folded(hs, name) == Support.header_values(Support.matching_headers(hs, name)) : List<&2, List<&2, U32>>}:
  match hs:
    case Nil{}:
      {==}
    case Request.Header{n, v} <> t:
      %Equal.sym(List<&2, List<&2, U32>>, Request.lookup_folded(t, name), Support.header_values(Support.matching_headers(t, name)), lookup_selected(t, name)) : {Request.lookup_step(v, _, String.eq(n, name)) == Support.header_values(Support.matching_headers(Request.Header{n, v} <> t, name)) : List<&2, List<&2, U32>>}
      selected_values(n, v, Support.matching_headers(t, name), String.eq(n, name))

def Laws.header_lookup_all_in_order(headers, name):
  lookup_selected(headers, Bytes.fold(name))

# Scan the serialized line, reconstruct each field, then restore header order.
def head_feed(+m: Request.Method, +p: String, +q: Maybe<&2, String>, +v: Request.Version, +hs: List<&2, Request.Header>, +mv: {Request.method_valid(m) == True{} : Bool}, +tv: {Request.target_valid(m, p, q) == True{} : Bool}, hv: {Request.headers_valid(hs) == True{} : Bool}) -> {Parse.feed(Write.write(Request.Req{m, p, q, v, hs}), Parse.initial()) == (Parse.Complete{Request.Req{m, p, q, v, hs}}, Request.Parsed{Request.Req{m, p, q, v, hs}, []}) : Parse.State & Request.ParseResult}:
  +content = Write.line_content(m, p, q, v)
  +tail = Write.headers(hs)
  %Equal.sym(List<&2, U32>, Bytes.append(Bytes.append(content, [13, 10]), tail), Bytes.append(content, 13 <> 10 <> tail), Laws.append_assoc(content, [13, 10], tail)) : {Parse.feed(_, Parse.initial()) == (Parse.Complete{Request.Req{m, p, q, v, hs}}, Request.Parsed{Request.Req{m, p, q, v, hs}, []}) : Parse.State & Request.ParseResult}
  %Equal.sym(Parse.State & Request.ParseResult, Parse.feed(Bytes.append(content, 13 <> 10 <> tail), Parse.initial()), Parse.feed(tail, Parse.request_line(content)), Laws.scan_request_line(content, tail, Laws.line_printable(m, p, q, v, mv, tv))) : {_ == (Parse.Complete{Request.Req{m, p, q, v, hs}}, Request.Parsed{Request.Req{m, p, q, v, hs}, []}) : Parse.State & Request.ParseResult}
  %Equal.sym(Parse.State, Parse.request_line(content), Parse.Headers{Request.Req{m, p, q, v, []}, [], False{}}, Laws.line_recover(m, p, q, v, mv, tv)) : {Parse.feed(tail, _) == (Parse.Complete{Request.Req{m, p, q, v, hs}}, Request.Parsed{Request.Req{m, p, q, v, hs}, []}) : Parse.State & Request.ParseResult}
  %Laws.append_nil(U32, tail) : {Parse.feed(_, Parse.Headers{Request.Req{m, p, q, v, []}, [], False{}}) == (Parse.Complete{Request.Req{m, p, q, v, hs}}, Request.Parsed{Request.Req{m, p, q, v, hs}, []}) : Parse.State & Request.ParseResult}
  %Laws.reverse_twice(Request.Header, hs) : {Parse.feed(Bytes.append(tail, []), Parse.Headers{Request.Req{m, p, q, v, []}, [], False{}}) == (Parse.Complete{Request.Req{m, p, q, v, _}}, Request.Parsed{Request.Req{m, p, q, v, _}, []}) : Parse.State & Request.ParseResult}
  Laws.scan_headers(hs, m, p, q, v, [], [], hv)

def Laws.request_head_roundtrip(req, valid):
  match req:
    case Request.Req{m, p, q, v, hs}:
      +valid = valid
      +line_valid = Laws.and_left(Request.method_valid(m) && Request.target_valid(m, p, q), Request.headers_valid(hs), valid)
      hv = Laws.and_right(Request.method_valid(m) && Request.target_valid(m, p, q), Request.headers_valid(hs), valid)
      mv = Laws.and_left(Request.method_valid(m), Request.target_valid(m, p, q), line_valid)
      tv = Laws.and_right(Request.method_valid(m), Request.target_valid(m, p, q), line_valid)
      Equal.cong(Parse.State & Request.ParseResult, Request.ParseResult, pair => Parse.result(pair), Parse.feed(Write.write(Request.Req{m, p, q, v, hs}), Parse.initial()), (Parse.Complete{Request.Req{m, p, q, v, hs}}, Request.Parsed{Request.Req{m, p, q, v, hs}, []}), head_feed(m, p, q, v, hs, mv, tv, hv))

# Token separation and target validation recover the entire request line.
def Laws.parsed_request_line_path(method, path, query, version, valid):
  +line_valid = Laws.and_left(Request.method_valid(method) && Request.target_valid(method, path, query), True{}, valid)
  mv = Laws.and_left(Request.method_valid(method), Request.target_valid(method, path, query), line_valid)
  +tv = Laws.and_right(Request.method_valid(method), Request.target_valid(method, path, query), line_valid)
  %Equal.sym(String, Bytes.prefix(path ++ Request.query_text(query)), path, Laws.target_prefix(method, path, query, version, tv)) : {Parse.request_line(Write.line_content(method, path, query, version)) == Parse.Headers{Request.Req{method, _, query, version, []}, [], False{}} : Parse.State}
  Laws.line_recover(method, path, query, version, mv, tv)

# The single-header obligation from the request-head round trip.
def Laws.header_line_roundtrip(req, name, value, valid):
  Laws.header_fields(req, name, value, valid)

# BND-14: compilation establishes clean, nonempty segment lists. Matching
# induction composes the scalar codec roundtrip with split/join preservation,
# including the omitted sole optional capture at the root path.
def compiled_roundtrip(+pattern: Pattern.Pattern, +params: Pattern.Params,
    good: {CompileProof.pattern_good(pattern) == True{} : Bool},
    admitted: {Pattern.admissible(pattern, params) == True{} : Bool}) ->
    &path: String -> {Pattern.fill(pattern, params) == Some{path} : Maybe<&2, String>} & {Pattern.match_path(pattern, path) == Some{params} : Maybe<&2, Pattern.Params>}:
  match pattern:
    case Pattern.Pattern{+segs}:
      MatchProof.pattern_roundtrip(segs, params, good, admitted)

def Laws.pattern_fill_match(source, pattern, compiled, params, admitted):
  compiled_roundtrip(pattern, params, CompileProof.compiled_pattern_good(source, pattern, compiled), admitted)

# BND-29: URL-encoded data and ordered repeated-key lookup.

def Laws.form_queries_all_in_order(pairs, key):
  FormSpec.ordered(pairs, key)

def Laws.query_component_roundtrip(s, valid):
  Percent.component_roundtrip(s, False{}, Utf8Proof.roundtrip(s, valid))

def Laws.form_component_roundtrip(s, valid):
  Percent.component_roundtrip(s, True{}, Utf8Proof.roundtrip(s, valid))

# BND-15: indexed routing proofs are independent of the root pattern law.
def Laws.router_sound(T, table, path, i, tag, params, returned):
  SpecProof.sound(T, table, path, i, tag, params, returned)

def Laws.router_complete(T, table, path, i, tag, params, matched):
  SpecProof.complete(T, table, path, i, tag, params, matched)

def Laws.router_first_match(T, table, path, i, tag, params, matched, earlier):
  SpecProof.exact(T, table, path, i, tag, params, matched, earlier)

def Laws.router_priority(T, table, path, a, b, tag_a, params_a, tag_b, params_b, a_matches, b_matches, before):
  SpecProof.priority_witness(T, a, b, Spec.route(T, table, path), before, SpecProof.complete(T, table, path, a, tag_a, params_a, a_matches))

def Laws.router_fill_match(T, table, i, source, pattern, tag, entry, compiled, params, admitted):
  SpecProof.filled_roundtrip(T, table, i, pattern, tag, params, entry, Laws.pattern_fill_match(source, pattern, compiled, params, admitted))

# BND-9: proofs of buffered response framing.

def response_head_prefix(+r: Response.Res) -> {WriteResponse.prefix(Request.Head{}, r) == WriteResponse.prefix(Request.Get{}, r) : List<&2, U32>}:
  match r:
    case Response.Res{s, hs, b, rep}:
      {==}

def response_head_empty(+r: Response.Res) -> {WriteResponse.payload(Request.Head{}, r) == [] : List<&2, U32>}:
  match r:
    case Response.Res{s, hs, b, rep}:
      {==}

# Body equality is proved separately from the remaining head-safety goals.
def response_body_condition(+method: Request.Method, +status: U32, not_head: {WriteResponse.is_head(method) == False{} : Bool}, allowed: {WriteResponse.allows_body(status) == True{} : Bool}, not_tunnel: {WriteResponse.tunnel(method, status) == False{} : Bool}) -> {WriteResponse.is_head(method) || Bool.not(WriteResponse.allows_body(status)) || WriteResponse.tunnel(method, status) == False{} : Bool}:
  %Equal.sym(Bool, WriteResponse.is_head(method), False{}, not_head) : {_ || Bool.not(WriteResponse.allows_body(status)) || WriteResponse.tunnel(method, status) == False{} : Bool}
  %Equal.sym(Bool, WriteResponse.allows_body(status), True{}, allowed) : {False{} || Bool.not(_) || WriteResponse.tunnel(method, status) == False{} : Bool}
  not_tunnel

def response_body_bytes(+method: Request.Method, +status: U32, +headers: List<&2, Request.Header>, +body: List<&2, U32>, +representation: Maybe<&2, List<&2, U32>>, valid: {Response.valid(Response.Res{status, headers, body, representation}) == True{} : Bool}, allowed: {WriteResponse.allows_body(status) == True{} : Bool}, not_head: {WriteResponse.is_head(method) == False{} : Bool}, not_tunnel: {WriteResponse.tunnel(method, status) == False{} : Bool}) -> {WriteResponse.write(method, Response.Res{status, headers, body, representation}) == Bytes.append(WriteResponse.prefix(method, Response.Res{status, headers, body, representation}), 13 <> 10 <> 13 <> 10 <> body) : List<&2, U32>}:
  +r = {Response.Res{status, headers, body, representation} : Response.Res}
  %Equal.sym(Bool, Response.valid(r), True{}, valid) : {WriteResponse.write_valid(method, r, _) == Bytes.append(WriteResponse.prefix(method, r), 13 <> 10 <> 13 <> 10 <> body) : List<&2, U32>}
  %Equal.sym(Bool, WriteResponse.is_head(method) || Bool.not(WriteResponse.allows_body(status)) || WriteResponse.tunnel(method, status), False{}, response_body_condition(method, status, not_head, allowed, not_tunnel)) : {Bytes.append(WriteResponse.head(method, r), WriteResponse.emitted_body(body, _)) == Bytes.append(WriteResponse.prefix(method, r), 13 <> 10 <> 13 <> 10 <> body) : List<&2, U32>}
  Laws.append_assoc(WriteResponse.prefix(method, r), [13, 10, 13, 10], body)

def response_empty_when_forbidden(+body: List<&2, U32>, h: Bool, t: Bool) -> {WriteResponse.emitted_body(body, h || True{} || t) == [] : List<&2, U32>}:
  match h:
    case True{}:
      {==}
    case False{}:
      {==}

def response_forbidden_payload(+method: Request.Method, +status: U32, +headers: List<&2, Request.Header>, +body: List<&2, U32>, +representation: Maybe<&2, List<&2, U32>>, forbidden: {WriteResponse.forbidden(status) == True{} : Bool}) -> {WriteResponse.payload(method, Response.Res{status, headers, body, representation}) == [] : List<&2, U32>}:
  %Equal.sym(Bool, WriteResponse.forbidden(status), True{}, forbidden) : {WriteResponse.emitted_body(body, WriteResponse.is_head(method) || Bool.not(Bool.not(_ || U32.is_eq(status, 205) || U32.is_eq(status, 304))) || WriteResponse.tunnel(method, status)) == [] : List<&2, U32>}
  response_empty_when_forbidden(body, WriteResponse.is_head(method), WriteResponse.tunnel(method, status))

def response_forbidden_bytes(+method: Request.Method, +status: U32, +headers: List<&2, Request.Header>, +body: List<&2, U32>, +representation: Maybe<&2, List<&2, U32>>, valid: {Response.valid(Response.Res{status, headers, body, representation}) == True{} : Bool}, forbidden: {WriteResponse.forbidden(status) == True{} : Bool}) -> {WriteResponse.write(method, Response.Res{status, headers, body, representation}) == Bytes.append(WriteResponse.prefix(method, Response.Res{status, headers, body, representation}), [13, 10, 13, 10]) : List<&2, U32>}:
  +r = {Response.Res{status, headers, body, representation} : Response.Res}
  %Equal.sym(Bool, Response.valid(r), True{}, valid) : {WriteResponse.write_valid(method, r, _) == WriteResponse.head(method, r) : List<&2, U32>}
  %Equal.sym(List<&2, U32>, WriteResponse.payload(method, r), [], response_forbidden_payload(method, status, headers, body, representation, forbidden)) : {Bytes.append(WriteResponse.head(method, r), _) == WriteResponse.head(method, r) : List<&2, U32>}
  Laws.append_nil(U32, WriteResponse.head(method, r))

def response_prefix_safe(+method: Request.Method, +res: Response.Res, valid: {Response.valid(res) == True{} : Bool}) -> {String.contains(Bytes.ascii(WriteResponse.prefix(method, res)), "\r\n\r\n") == False{} : Bool}:
  match res:
    case Response.Res{s, hs, b, rep}:
      +r = {Response.Res{s, hs, b, rep} : Response.Res}
      %Equal.sym(String, Bytes.ascii(Bytes.encode(WriteResponse.prefix_text(method, r))), WriteResponse.prefix_text(method, r), Line.ascii_encode(WriteResponse.prefix_text(method, r))) : {String.contains(_, "\r\n\r\n") == False{} : Bool}
      Equal.trans(Bool, String.contains(WriteResponse.status_text(s) ++ WriteResponse.headers_text(WriteResponse.response_headers(method, r)), "\r\n\r\n"), String.contains(WriteResponse.headers_text(WriteResponse.response_headers(method, r)), "\r\n\r\n"), False{}, ResponseLines.clear_scan(WriteResponse.status_text(s), WriteResponse.headers_text(WriteResponse.response_headers(method, r)), "\n\r\n", ResponseFraming.status_value(s)), ResponseLines.headers_blank(WriteResponse.response_headers(method, r), ResponseFraming.response_scannable(method, r, valid)))

def response_length_present(+method: Request.Method, +status: U32, +headers: List<&2, Request.Header>, +body: List<&2, U32>, +representation: Maybe<&2, List<&2, U32>>, valid: {Response.valid(Response.Res{status, headers, body, representation}) == True{} : Bool}, allowed: {WriteResponse.allows_body(status) == True{} : Bool}, not_tunnel: {WriteResponse.tunnel(method, status) == False{} : Bool}) -> {String.contains(Bytes.ascii(Bytes.append(WriteResponse.prefix(method, Response.Res{status, headers, body, representation}), [13, 10])), "\r\ncontent-length: " ++ Nat.show(Response.length(body)) ++ "\r\n") == True{} : Bool}:
  +r = {Response.Res{status, headers, body, representation} : Response.Res}
  %Equal.sym(String, Bytes.ascii(Bytes.append(WriteResponse.prefix(method, r), [13, 10])), WriteResponse.prefix_text(method, r) ++ "\r\n", ResponseLines.ascii_prefix_suffix(method, r)) : {String.contains(_, "\r\ncontent-length: " ++ Nat.show(Response.length(body)) ++ "\r\n") == True{} : Bool}
  %Equal.sym(String, (WriteResponse.status_text(status) ++ WriteResponse.headers_text(WriteResponse.response_headers(method, r))) ++ "\r\n", WriteResponse.status_text(status) ++ (WriteResponse.headers_text(WriteResponse.response_headers(method, r)) ++ "\r\n"), Line.string_assoc(WriteResponse.status_text(status), WriteResponse.headers_text(WriteResponse.response_headers(method, r)), "\r\n")) : {String.contains(_, "\r\ncontent-length: " ++ Nat.show(Response.length(body)) ++ "\r\n") == True{} : Bool}
  %Equal.sym(List<&2, Request.Header>, WriteResponse.response_headers(method, r), WriteResponse.length_header(Response.length(body)) <> WriteResponse.headers(headers), ResponseFraming.body_headers(method, status, headers, body, representation, allowed, not_tunnel)) : {String.contains(WriteResponse.status_text(status) ++ (WriteResponse.headers_text(_) ++ "\r\n"), "\r\ncontent-length: " ++ Nat.show(Response.length(body)) ++ "\r\n") == True{} : Bool}
  ResponseLines.contains_prepend(WriteResponse.status_text(status), WriteResponse.headers_text(WriteResponse.length_header(Response.length(body)) <> WriteResponse.headers(headers)) ++ "\r\n", "\r\ncontent-length: " ++ Nat.show(Response.length(body)) ++ "\r\n", ResponseLines.length_present(Response.length(body), WriteResponse.headers(headers)))

def response_length_absent(+method: Request.Method, +status: U32, +headers: List<&2, Request.Header>, +body: List<&2, U32>, +representation: Maybe<&2, List<&2, U32>>, valid: {Response.valid(Response.Res{status, headers, body, representation}) == True{} : Bool}, forbidden: {WriteResponse.forbidden(status) == True{} : Bool}) -> {String.contains(Bytes.ascii(WriteResponse.prefix(method, Response.Res{status, headers, body, representation})), "\r\ncontent-length:") == False{} : Bool}:
  +r = {Response.Res{status, headers, body, representation} : Response.Res}
  %Equal.sym(String, Bytes.ascii(Bytes.encode(WriteResponse.prefix_text(method, r))), WriteResponse.prefix_text(method, r), Line.ascii_encode(WriteResponse.prefix_text(method, r))) : {String.contains(_, "\r\ncontent-length:") == False{} : Bool}
  %Equal.sym(List<&2, Request.Header>, WriteResponse.response_headers(method, r), WriteResponse.headers(headers), ResponseFraming.forbidden_headers(method, status, headers, body, representation, forbidden)) : {String.contains(WriteResponse.status_text(status) ++ WriteResponse.headers_text(_), "\r\ncontent-length:") == False{} : Bool}
  Equal.trans(Bool, String.contains(WriteResponse.status_text(status) ++ WriteResponse.headers_text(WriteResponse.headers(headers)), "\r\ncontent-length:"), String.contains(WriteResponse.headers_text(WriteResponse.headers(headers)), "\r\ncontent-length:"), False{}, ResponseLines.clear_scan(WriteResponse.status_text(status), WriteResponse.headers_text(WriteResponse.headers(headers)), "\ncontent-length:", ResponseFraming.status_value(status)), ResponseAbsence.filtered_headers_absent(headers, ResponseFraming.valid_headers(status, headers, body, representation, valid)))

def Laws.response_utf8_encode(s, valid):
  ResponseRuntime.utf8(s, valid)

def response_observed_head(+method: Request.Method, +res: Response.Res) -> ResponseSpec.Head:
  ResponseSpec.Head{Bytes.encode(WriteResponse.status_text(ResponseStatus.status(res))), WriteResponse.response_headers(method, res)}

def response_split(+method: Request.Method, +res: Response.Res, +valid: {Response.valid(res) == True{} : Bool}) -> {ResponseSpec.split_first(WriteResponse.write(method, res)) == Some{(WriteResponse.prefix(method, res), WriteResponse.payload(method, res))} : Maybe<&2, ResponseSpec.BytePair()>}:
  %Equal.sym(Bool, Response.valid(res), True{}, valid) : {ResponseSpec.split_first(WriteResponse.write_valid(method, res, _)) == Some{(WriteResponse.prefix(method, res), WriteResponse.payload(method, res))} : Maybe<&2, ResponseSpec.BytePair()>}
  ResponseSpecProof.split_valid(method, res, valid)

def response_parse(+method: Request.Method, +res: Response.Res, +valid: {Response.valid(res) == True{} : Bool}) -> {ResponseSpec.parse_head(WriteResponse.head(method, res)) == Some{response_observed_head(method, res)} : Maybe<&2, ResponseSpec.Head>}:
  match res:
    case Response.Res{s, hs, b, rep}:
      ResponseSpecProof.parse_valid(method, Response.Res{s, hs, b, rep}, ResponseStatus.response(Response.Res{s, hs, b, rep}, valid), ResponseFraming.response_valid(method, Response.Res{s, hs, b, rep}, valid))

def response_payload_body(+method: Request.Method, +status: U32, +headers: List<&2, Request.Header>, +body: List<&2, U32>, +representation: Maybe<&2, List<&2, U32>>, allowed: {WriteResponse.allows_body(status) == True{} : Bool}, not_head: {WriteResponse.is_head(method) == False{} : Bool}, not_tunnel: {WriteResponse.tunnel(method, status) == False{} : Bool}) -> {WriteResponse.payload(method, Response.Res{status, headers, body, representation}) == body : List<&2, U32>}:
  %Equal.sym(Bool, WriteResponse.is_head(method) || Bool.not(WriteResponse.allows_body(status)) || WriteResponse.tunnel(method, status), False{}, response_body_condition(method, status, not_head, allowed, not_tunnel)) : {WriteResponse.emitted_body(body, _) == body : List<&2, U32>}
  {==}

def Laws.response_body_after_first_blank(method, status, headers, body, representation, valid, allowed, not_head, not_tunnel):
  +r = {Response.Res{status, headers, body, representation} : Response.Res}
  +head = WriteResponse.prefix(method, r)
  +parsed = response_observed_head(method, r)
  +split = { (
    %response_payload_body(method, status, headers, body, representation, allowed, not_head, not_tunnel) : {ResponseSpec.split_first(WriteResponse.write(method, r)) == Some{(head, _)} : Maybe<&2, ResponseSpec.BytePair()>}
    response_split(method, r, valid)) : {ResponseSpec.split_first(WriteResponse.write(method, r)) == Some{(head, body)} : Maybe<&2, ResponseSpec.BytePair()>}}
  +length = { (
    %Equal.sym(List<&2, Request.Header>, WriteResponse.response_headers(method, r), WriteResponse.length_header(Response.length(body)) <> WriteResponse.headers(headers), ResponseFraming.body_headers(method, status, headers, body, representation, allowed, not_tunnel)) : {Request.lookup(_, "content-length") == [Bytes.encode(Nat.show(List.length(&2, U32, body)))] : List<&2, List<&2, U32>>}
    %Equal.sym(Nat, Response.length(body), List.length(&2, U32, body), ResponseRuntime.length(body)) : {Request.lookup(WriteResponse.length_header(_) <> WriteResponse.headers(headers), "content-length") == [Bytes.encode(Nat.show(List.length(&2, U32, body)))] : List<&2, List<&2, U32>>}
    ResponseFields.added_length(List.length(&2, U32, body), headers)) : {Request.lookup(WriteResponse.response_headers(method, r), "content-length") == [Bytes.encode(Nat.show(List.length(&2, U32, body)))] : List<&2, List<&2, U32>>}}
  (head, (parsed, (split, response_parse(method, r, valid), length, ResponseFields.response_transfer(method, r))))

def Laws.response_forbidden_has_no_body_or_length(method, status, headers, body, representation, valid, forbidden):
  +r = {Response.Res{status, headers, body, representation} : Response.Res}
  +head = WriteResponse.prefix(method, r)
  +parsed = response_observed_head(method, r)
  +split = { (
    %response_forbidden_payload(method, status, headers, body, representation, forbidden) : {ResponseSpec.split_first(WriteResponse.write(method, r)) == Some{(head, _)} : Maybe<&2, ResponseSpec.BytePair()>}
    response_split(method, r, valid)) : {ResponseSpec.split_first(WriteResponse.write(method, r)) == Some{(head, [])} : Maybe<&2, ResponseSpec.BytePair()>}}
  +length = { (
    %Equal.sym(List<&2, Request.Header>, WriteResponse.response_headers(method, r), WriteResponse.headers(headers), ResponseFraming.forbidden_headers(method, status, headers, body, representation, forbidden)) : {Request.lookup(_, "content-length") == [] : List<&2, List<&2, U32>>}
    ResponseFields.length(headers)) : {Request.lookup(WriteResponse.response_headers(method, r), "content-length") == [] : List<&2, List<&2, U32>>}}
  (head, (parsed, (split, response_parse(method, r, valid), length, ResponseFields.response_transfer(method, r))))

def response_304_tunnel(method: Request.Method) -> {WriteResponse.tunnel(method, 304) == False{} : Bool}:
  match method:
    case Request.Get{}:
      {==}
    case Request.Head{}:
      {==}
    case Request.Post{}:
      {==}
    case Request.Put{}:
      {==}
    case Request.Delete{}:
      {==}
    case Request.Connect{}:
      {==}
    case Request.Options{}:
      {==}
    case Request.Trace{}:
      {==}
    case Request.Patch{}:
      {==}
    case Request.Extension{token}:
      {==}

def response_304_payload(+method: Request.Method, headers: List<&2, Request.Header>, body: List<&2, U32>, representation: Maybe<&2, List<&2, U32>>) -> {WriteResponse.payload(method, Response.Res{304, headers, body, representation}) == [] : List<&2, U32>}:
  response_empty_when_forbidden(body, WriteResponse.is_head(method), WriteResponse.tunnel(method, 304))

def Laws.response_304_framing(method, headers, body, representation, valid):
  +r = {Response.Res{304, headers, body, representation} : Response.Res}
  +head = WriteResponse.prefix(method, r)
  +parsed = response_observed_head(method, r)
  +split = { (
    %response_304_payload(method, headers, body, representation) : {ResponseSpec.split_first(WriteResponse.write(method, r)) == Some{(head, _)} : Maybe<&2, ResponseSpec.BytePair()>}
    response_split(method, r, valid)) : {ResponseSpec.split_first(WriteResponse.write(method, r)) == Some{(head, [])} : Maybe<&2, ResponseSpec.BytePair()>}}
  +length = { (
    %Equal.sym(Bool, WriteResponse.tunnel(method, 304), False{}, response_304_tunnel(method)) : {Request.lookup(WriteResponse.framing_headers(304, body, representation, WriteResponse.headers(headers), False{} || _), "content-length") == ResponseFramingSpec.representation_lengths(representation) : List<&2, List<&2, U32>>}
    ResponseFields.representation_length(representation, headers)) : {Request.lookup(WriteResponse.response_headers(method, r), "content-length") == ResponseFramingSpec.representation_lengths(representation) : List<&2, List<&2, U32>>}}
  (head, (parsed, (split, response_parse(method, r, valid), length, ResponseFields.response_transfer(method, r))))

def Laws.response_head_matches_get(res, valid):
  +head = WriteResponse.prefix(Request.Get{}, res)
  +get_body = WriteResponse.payload(Request.Get{}, res)
  +parsed = response_observed_head(Request.Get{}, res)
  +split_head = { (
    %response_head_prefix(res) : {ResponseSpec.split_first(WriteResponse.write(Request.Head{}, res)) == Some{(_, [])} : Maybe<&2, ResponseSpec.BytePair()>}
    %response_head_empty(res) : {ResponseSpec.split_first(WriteResponse.write(Request.Head{}, res)) == Some{(WriteResponse.prefix(Request.Head{}, res), _)} : Maybe<&2, ResponseSpec.BytePair()>}
    response_split(Request.Head{}, res, valid)) : {ResponseSpec.split_first(WriteResponse.write(Request.Head{}, res)) == Some{(head, [])} : Maybe<&2, ResponseSpec.BytePair()>}}
  (head, (get_body, (parsed, (response_split(Request.Get{}, res, valid), split_head, response_parse(Request.Get{}, res, valid), ResponseFields.get_length(res), ResponseFields.response_transfer(Request.Get{}, res)))))

# BND-18: universal method-aware routing proofs.

def Laws.methods_found_first(T, table, path, method, opts, i, tag, params, returned):
  match table:
    case Methods.Valid{+rows, ok}:
      MethodProof.found_first(T, rows, path, method, opts, i, tag, params, returned)

def Laws.methods_default_path_identity(pattern, path):
  MethodProof.default_path(pattern, path)

def Laws.methods_default_found_first(T, table, path, method, i, tag, params, returned):
  match table:
    case Methods.Valid{+rows, ok}:
      MethodProof.default_first(T, rows, path, method, i, tag, params, MethodProof.found_first(T, rows, path, method, Methods.defaults(), i, tag, params, returned))

def Laws.methods_explicit_head_priority(T, table, path, opts, i, tag, params, matched):
  match table:
    case Methods.Valid{+rows, ok}:
      MethodProof.head_priority(T, rows, path, opts, i, tag, params, matched)

def Laws.methods_head_fallback_first_get(T, table, path, method, opts, i, tag, params, returned):
  match table:
    case Methods.Valid{+rows, ok}:
      MethodProof.fallback_first(T, rows, path, method, opts, i, tag, params, returned)

def Laws.methods_not_found_iff_all_paths_miss(T, table, path, method, opts):
  match table:
    case Methods.Valid{+rows, ok}:
      (returned => MethodProof.not_found_only(T, rows, path, method, opts, returned), misses => MethodProof.not_found(T, rows, path, method, opts, misses))

def Laws.methods_allow_exact(T, table, path, method, opts, allow, valid, returned):
  match table:
    case Methods.Valid{+rows, ok}:
      MethodProof.exact_allow(T, rows, path, method, opts, allow, ok, valid, returned)

def Laws.methods_build_valid(T, entries, table, built):
  match table:
    case Methods.Valid{rows, ok}:
      ok


def Laws.hex_roundtrip(xs, valid):
  HexProof.roundtrip(xs, valid)

def Laws.base64_roundtrip(xs, url, padded, valid):
  Base64Proof.roundtrip(xs, url, padded, valid)

# BND-8: chunked encode/decode roundtrip.

def Laws.chunked_roundtrip(chunks, limit, suffix, valid):
  ChunkedRoundtrip.roundtrip(chunks, limit, suffix, valid)

# BND-22. Unfolding the shared runtime composition primitive proves these
# equations without restricting middleware to a particular implementation.
def Laws.middleware_application(C, R, a, b, ctx, next): {==}
def Laws.middleware_identity_left(C, R, mw, ctx, next): {==}
def Laws.middleware_identity_right(C, R, mw, ctx, next): {==}
def Laws.middleware_identity_insert(C, R, a, b, ctx, next): {==}
def Laws.middleware_associative(C, R, a, b, c, ctx, next): {==}

def Laws.middleware_registration_selection(Tag, entries, table, path, built):
  MiddlewareSelection.selection(Tag, entries, table, path, built)

# BND-23
def Laws.lifecycle_stage_selection(Tag, entries, routes, compiled, layers, count, stage, built):
  LifecycleSelection.selection(Tag, entries, routes, compiled, layers, count, stage, built)

def Laws.lifecycle_ordered_selection(Tag, entries, routes, compiled, layers, count, path, built):
  %Equal.sym(List<&2, Tag>, Table.stage_ids(Tag, layers, Table.Request{}), MiddlewareSelectionSpec.hooks(Tag, entries, Table.Request{}), LifecycleSelection.selection(Tag, entries, routes, compiled, layers, count, Table.Request{}, built)) : {Table.Lifecycle{_, List.concat(&2, Tag, [Table.selected(Tag, layers, path), Table.stage_ids(Tag, layers, Table.Parse{}), Table.stage_ids(Tag, layers, Table.Transform{}), Table.stage_ids(Tag, layers, Table.BeforeHandle{})]), Table.stage_ids(Tag, layers, Table.AfterHandle{}), Table.stage_ids(Tag, layers, Table.MapResponse{}), Table.stage_ids(Tag, layers, Table.Error{}), Table.stage_ids(Tag, layers, Table.AfterResponse{})} == MiddlewareSelectionSpec.lifecycle(Tag, entries, path) : Table.Lifecycle<Tag>}
  %Equal.sym(List<&2, Tag>, Table.selected(Tag, layers, path), MiddlewareSelectionSpec.filter(Tag, entries, path), MiddlewareSelection.selection(Tag, entries, Table.Table{routes, compiled, layers, count}, path, built)) : {Table.Lifecycle{MiddlewareSelectionSpec.hooks(Tag, entries, Table.Request{}), List.concat(&2, Tag, [_, Table.stage_ids(Tag, layers, Table.Parse{}), Table.stage_ids(Tag, layers, Table.Transform{}), Table.stage_ids(Tag, layers, Table.BeforeHandle{})]), Table.stage_ids(Tag, layers, Table.AfterHandle{}), Table.stage_ids(Tag, layers, Table.MapResponse{}), Table.stage_ids(Tag, layers, Table.Error{}), Table.stage_ids(Tag, layers, Table.AfterResponse{})} == MiddlewareSelectionSpec.lifecycle(Tag, entries, path) : Table.Lifecycle<Tag>}
  %Equal.sym(List<&2, Tag>, Table.stage_ids(Tag, layers, Table.Parse{}), MiddlewareSelectionSpec.hooks(Tag, entries, Table.Parse{}), LifecycleSelection.selection(Tag, entries, routes, compiled, layers, count, Table.Parse{}, built)) : {Table.Lifecycle{MiddlewareSelectionSpec.hooks(Tag, entries, Table.Request{}), List.concat(&2, Tag, [MiddlewareSelectionSpec.filter(Tag, entries, path), _, Table.stage_ids(Tag, layers, Table.Transform{}), Table.stage_ids(Tag, layers, Table.BeforeHandle{})]), Table.stage_ids(Tag, layers, Table.AfterHandle{}), Table.stage_ids(Tag, layers, Table.MapResponse{}), Table.stage_ids(Tag, layers, Table.Error{}), Table.stage_ids(Tag, layers, Table.AfterResponse{})} == MiddlewareSelectionSpec.lifecycle(Tag, entries, path) : Table.Lifecycle<Tag>}
  %Equal.sym(List<&2, Tag>, Table.stage_ids(Tag, layers, Table.Transform{}), MiddlewareSelectionSpec.hooks(Tag, entries, Table.Transform{}), LifecycleSelection.selection(Tag, entries, routes, compiled, layers, count, Table.Transform{}, built)) : {Table.Lifecycle{MiddlewareSelectionSpec.hooks(Tag, entries, Table.Request{}), List.concat(&2, Tag, [MiddlewareSelectionSpec.filter(Tag, entries, path), MiddlewareSelectionSpec.hooks(Tag, entries, Table.Parse{}), _, Table.stage_ids(Tag, layers, Table.BeforeHandle{})]), Table.stage_ids(Tag, layers, Table.AfterHandle{}), Table.stage_ids(Tag, layers, Table.MapResponse{}), Table.stage_ids(Tag, layers, Table.Error{}), Table.stage_ids(Tag, layers, Table.AfterResponse{})} == MiddlewareSelectionSpec.lifecycle(Tag, entries, path) : Table.Lifecycle<Tag>}
  %Equal.sym(List<&2, Tag>, Table.stage_ids(Tag, layers, Table.BeforeHandle{}), MiddlewareSelectionSpec.hooks(Tag, entries, Table.BeforeHandle{}), LifecycleSelection.selection(Tag, entries, routes, compiled, layers, count, Table.BeforeHandle{}, built)) : {Table.Lifecycle{MiddlewareSelectionSpec.hooks(Tag, entries, Table.Request{}), List.concat(&2, Tag, [MiddlewareSelectionSpec.filter(Tag, entries, path), MiddlewareSelectionSpec.hooks(Tag, entries, Table.Parse{}), MiddlewareSelectionSpec.hooks(Tag, entries, Table.Transform{}), _]), Table.stage_ids(Tag, layers, Table.AfterHandle{}), Table.stage_ids(Tag, layers, Table.MapResponse{}), Table.stage_ids(Tag, layers, Table.Error{}), Table.stage_ids(Tag, layers, Table.AfterResponse{})} == MiddlewareSelectionSpec.lifecycle(Tag, entries, path) : Table.Lifecycle<Tag>}
  %Equal.sym(List<&2, Tag>, Table.stage_ids(Tag, layers, Table.AfterHandle{}), MiddlewareSelectionSpec.hooks(Tag, entries, Table.AfterHandle{}), LifecycleSelection.selection(Tag, entries, routes, compiled, layers, count, Table.AfterHandle{}, built)) : {Table.Lifecycle{MiddlewareSelectionSpec.hooks(Tag, entries, Table.Request{}), List.concat(&2, Tag, [MiddlewareSelectionSpec.filter(Tag, entries, path), MiddlewareSelectionSpec.hooks(Tag, entries, Table.Parse{}), MiddlewareSelectionSpec.hooks(Tag, entries, Table.Transform{}), MiddlewareSelectionSpec.hooks(Tag, entries, Table.BeforeHandle{})]), _, Table.stage_ids(Tag, layers, Table.MapResponse{}), Table.stage_ids(Tag, layers, Table.Error{}), Table.stage_ids(Tag, layers, Table.AfterResponse{})} == MiddlewareSelectionSpec.lifecycle(Tag, entries, path) : Table.Lifecycle<Tag>}
  %Equal.sym(List<&2, Tag>, Table.stage_ids(Tag, layers, Table.MapResponse{}), MiddlewareSelectionSpec.hooks(Tag, entries, Table.MapResponse{}), LifecycleSelection.selection(Tag, entries, routes, compiled, layers, count, Table.MapResponse{}, built)) : {Table.Lifecycle{MiddlewareSelectionSpec.hooks(Tag, entries, Table.Request{}), List.concat(&2, Tag, [MiddlewareSelectionSpec.filter(Tag, entries, path), MiddlewareSelectionSpec.hooks(Tag, entries, Table.Parse{}), MiddlewareSelectionSpec.hooks(Tag, entries, Table.Transform{}), MiddlewareSelectionSpec.hooks(Tag, entries, Table.BeforeHandle{})]), MiddlewareSelectionSpec.hooks(Tag, entries, Table.AfterHandle{}), _, Table.stage_ids(Tag, layers, Table.Error{}), Table.stage_ids(Tag, layers, Table.AfterResponse{})} == MiddlewareSelectionSpec.lifecycle(Tag, entries, path) : Table.Lifecycle<Tag>}
  %Equal.sym(List<&2, Tag>, Table.stage_ids(Tag, layers, Table.Error{}), MiddlewareSelectionSpec.hooks(Tag, entries, Table.Error{}), LifecycleSelection.selection(Tag, entries, routes, compiled, layers, count, Table.Error{}, built)) : {Table.Lifecycle{MiddlewareSelectionSpec.hooks(Tag, entries, Table.Request{}), List.concat(&2, Tag, [MiddlewareSelectionSpec.filter(Tag, entries, path), MiddlewareSelectionSpec.hooks(Tag, entries, Table.Parse{}), MiddlewareSelectionSpec.hooks(Tag, entries, Table.Transform{}), MiddlewareSelectionSpec.hooks(Tag, entries, Table.BeforeHandle{})]), MiddlewareSelectionSpec.hooks(Tag, entries, Table.AfterHandle{}), MiddlewareSelectionSpec.hooks(Tag, entries, Table.MapResponse{}), _, Table.stage_ids(Tag, layers, Table.AfterResponse{})} == MiddlewareSelectionSpec.lifecycle(Tag, entries, path) : Table.Lifecycle<Tag>}
  %Equal.sym(List<&2, Tag>, Table.stage_ids(Tag, layers, Table.AfterResponse{}), MiddlewareSelectionSpec.hooks(Tag, entries, Table.AfterResponse{}), LifecycleSelection.selection(Tag, entries, routes, compiled, layers, count, Table.AfterResponse{}, built)) : {Table.Lifecycle{MiddlewareSelectionSpec.hooks(Tag, entries, Table.Request{}), List.concat(&2, Tag, [MiddlewareSelectionSpec.filter(Tag, entries, path), MiddlewareSelectionSpec.hooks(Tag, entries, Table.Parse{}), MiddlewareSelectionSpec.hooks(Tag, entries, Table.Transform{}), MiddlewareSelectionSpec.hooks(Tag, entries, Table.BeforeHandle{})]), MiddlewareSelectionSpec.hooks(Tag, entries, Table.AfterHandle{}), MiddlewareSelectionSpec.hooks(Tag, entries, Table.MapResponse{}), MiddlewareSelectionSpec.hooks(Tag, entries, Table.Error{}), _} == MiddlewareSelectionSpec.lifecycle(Tag, entries, path) : Table.Lifecycle<Tag>}
  {==}

# BND-17: trie router equivalence.

def Laws.trie_route_spec(T, table, path):
  TrieProof.route_equal(T, table, path)

def Laws.trie_matches_spec(T, table, path):
  TrieProof.matches_equal(T, table, path)

def Laws.router_kind_spec(T, kind, table, path):
  match kind:
    case Router.Spec{}:
      {==}
    case Router.Trie{}:
      TrieProof.route_equal(T, table, path)

def Laws.methods_router_resolve(T, kind, table, path, method, opts):
  MethodTrieProof.resolve_equal(T, kind, table, path, method, opts)

# BND-31: universal cookie roundtrip and checked default serialization.

def Laws.cookies_pair_roundtrip(name, value, name_valid, value_valid):
  CookieProof.roundtrip(name, value, name_valid, value_valid)

def Laws.cookies_defaults_checked(name, value, name_valid, value_valid):
  CookieProof.defaults_checked(name, value, name_valid, value_valid)

# BND-31
def Laws.cookies_ordered_list_roundtrip(entries, valid):
  CookieProof.list_roundtrip(entries, valid)

# BND-33

def Laws.schema_acceptance_iff(schema, value):
  SchemaProof.acceptance_spec(schema, value)

def Laws.schema_preserves_typed_value(schema, value):
  SchemaProof.preservation(schema, value, Schema.valid(schema))

# BND-24

def Laws.scoped_stage_selection(Tag, entries, routes, compiled, layers, count, route, stage, built):
  ScopedSelection.stage_selection(Tag, entries, routes, compiled, layers, count, route, stage, built)

def Laws.scoped_lifecycle_selection(Tag, entries, routes, compiled, layers, count, path, route, built):
  ScopedSelection.lifecycle_selection(Tag, entries, routes, compiled, layers, count, path, route, built)

def Laws.scoped_nonmember_global_only(Tag, entries, routes, compiled, layers, count, route, stage, built, no):
  ScopedSelection.nonmember_selection(Tag, entries, routes, compiled, layers, count, route, stage, built, no)

def Laws.scoped_miss_global_only(Tag, entries, routes, compiled, layers, count, stage, built):
  ScopedSelection.nonmember_selection(Tag, entries, routes, compiled, layers, count, None{}, stage, built, ScopedSelection.none_member(Tag, entries))

def Laws.scoped_resolved_stage_selection(Tag, entries, routes, compiled, layers, count, kind, path, method, opts, stage, built):
  ScopedSelection.resolved_selection(Tag, entries, routes, compiled, layers, count, kind, path, method, opts, stage, built)

def Laws.scoped_guard_assembly(Tag, options, entries):
  Assembly.guard(Tag, options, entries)

def Laws.scoped_group_assembly(Tag, prefix, hooks, entries):
  Assembly.group(Tag, prefix, hooks, entries)

def Laws.scoped_local_assembly(Tag, registration, hooks):
  Assembly.local(Tag, registration, hooks)

def Laws.scoped_nested_assembly_isolation(Tag, before, options, prefix, hooks, inside, after):
  Assembly.context(Tag, before, Scopes.guard(Tag, options, Scopes.group(Tag, prefix, hooks, inside)), AssemblySpec.guard(Tag, options, AssemblySpec.group(Tag, prefix, hooks, inside)), after, Assembly.nested(Tag, options, prefix, hooks, inside))

def Laws.scoped_guard_built_selection(Tag, options, inside, outside, routes, compiled, layers, count, route, stage, built):
  Assembly.selection(Tag, List.append(&2, Table.Entry<Tag>, Scopes.guard(Tag, options, inside), outside), List.append(&2, Table.Entry<Tag>, AssemblySpec.guard(Tag, options, inside), outside), routes, compiled, layers, count, route, stage, built, Assembly.context(Tag, [], Scopes.guard(Tag, options, inside), AssemblySpec.guard(Tag, options, inside), outside, Assembly.guard(Tag, options, inside)))

def Laws.scoped_group_built_selection(Tag, prefix, hooks, inside, outside, routes, compiled, layers, count, route, stage, built):
  Assembly.selection(Tag, List.append(&2, Table.Entry<Tag>, Scopes.group(Tag, prefix, hooks, inside), outside), List.append(&2, Table.Entry<Tag>, AssemblySpec.group(Tag, prefix, hooks, inside), outside), routes, compiled, layers, count, route, stage, built, Assembly.context(Tag, [], Scopes.group(Tag, prefix, hooks, inside), AssemblySpec.group(Tag, prefix, hooks, inside), outside, Assembly.group(Tag, prefix, hooks, inside)))
