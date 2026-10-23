# Proofs of LAWS.bend. Run: bend PROOF.bend --verdict
import Base
import ./src/http/response.bend as Response
import ./src/http/write_response.bend as WriteResponse
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

# BND-9: proofs of buffered response framing.

def response_head_prefix(+r: Response.Res) -> {WriteResponse.prefix(Request.Head{}, r) == WriteResponse.prefix(Request.Get{}, r) : List<&2, U32>}:
  match r:
    case Response.Res{s, hs, b, rep}:
      {==}

def response_head_empty(+r: Response.Res) -> {WriteResponse.payload(Request.Head{}, r) == [] : List<&2, U32>}:
  match r:
    case Response.Res{s, hs, b, rep}:
      {==}

def Laws.response_head_matches_get(res, valid):
  +same = Equal.cong(List<&2, U32>, List<&2, U32>, xs => Bytes.append(xs, [13, 10, 13, 10]), WriteResponse.prefix(Request.Head{}, res), WriteResponse.prefix(Request.Get{}, res), response_head_prefix(res))
  (same, (
    %Equal.sym(Bool, Response.valid(res), True{}, valid) : {WriteResponse.write_valid(Request.Head{}, res, _) == WriteResponse.head(Request.Get{}, res) : List<&2, U32>}
    %Equal.sym(List<&2, U32>, WriteResponse.payload(Request.Head{}, res), [], response_head_empty(res)) : {Bytes.append(WriteResponse.head(Request.Head{}, res), _) == WriteResponse.head(Request.Get{}, res) : List<&2, U32>}
    Equal.trans(List<&2, U32>, Bytes.append(WriteResponse.head(Request.Head{}, res), []), WriteResponse.head(Request.Head{}, res), WriteResponse.head(Request.Get{}, res), Laws.append_nil(U32, WriteResponse.head(Request.Head{}, res)), same)
  ))

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
  ?response_prefix_safe

def response_length_present(+method: Request.Method, +status: U32, +headers: List<&2, Request.Header>, +body: List<&2, U32>, +representation: Maybe<&2, List<&2, U32>>, valid: {Response.valid(Response.Res{status, headers, body, representation}) == True{} : Bool}, allowed: {WriteResponse.allows_body(status) == True{} : Bool}, not_tunnel: {WriteResponse.tunnel(method, status) == False{} : Bool}) -> {String.contains(Bytes.ascii(Bytes.append(WriteResponse.prefix(method, Response.Res{status, headers, body, representation}), [13, 10])), "\r\ncontent-length: " ++ Nat.show(List.length(&2, U32, body)) ++ "\r\n") == True{} : Bool}:
  ?response_length_present

def Laws.response_body_after_first_blank(method, status, headers, body, representation, valid, allowed, not_head, not_tunnel):
  +r = {Response.Res{status, headers, body, representation} : Response.Res}
  (WriteResponse.prefix(method, r), (response_prefix_safe(method, r, valid), response_body_bytes(method, status, headers, body, representation, valid, allowed, not_head, not_tunnel), response_length_present(method, status, headers, body, representation, valid, allowed, not_tunnel)))

def response_length_absent(+method: Request.Method, +status: U32, +headers: List<&2, Request.Header>, +body: List<&2, U32>, +representation: Maybe<&2, List<&2, U32>>, valid: {Response.valid(Response.Res{status, headers, body, representation}) == True{} : Bool}, forbidden: {WriteResponse.forbidden(status) == True{} : Bool}) -> {String.contains(Bytes.ascii(WriteResponse.prefix(method, Response.Res{status, headers, body, representation})), "\r\ncontent-length:") == False{} : Bool}:
  ?response_length_absent

def Laws.response_forbidden_has_no_body_or_length(method, status, headers, body, representation, valid, forbidden):
  +r = {Response.Res{status, headers, body, representation} : Response.Res}
  (WriteResponse.prefix(method, r), (response_prefix_safe(method, r, valid), response_forbidden_bytes(method, status, headers, body, representation, valid, forbidden), response_length_absent(method, status, headers, body, representation, valid, forbidden)))
