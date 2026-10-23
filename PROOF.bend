# Proofs of LAWS.bend. Run: bend PROOF.bend --verdict
import Base
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

def Laws.text_body_after_blank(body):
  ("HTTP/1.1 200 OK\r\nContent-Type: text/plain; charset=utf-8\r\nConnection: close", ({==}, {==}))

def Laws.path_of_request_line():
  {==}

# BND-7: proofs of universal request-head guarantees.

def Laws.header_lookup_case_insensitive(headers, name, variant, same):
  %same : {Request.lookup_folded(headers, Bytes.fold(name)) == Request.lookup_folded(headers, _) : List<&2, List<&2, U32>>}
  {==}

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
