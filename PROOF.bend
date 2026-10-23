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

def Laws.text_body_after_blank(body):
  ("HTTP/1.1 200 OK\r\nContent-Type: text/plain; charset=utf-8\r\nConnection: close", ({==}, {==}))

def Laws.path_of_request_line():
  {==}

# BND-7: proofs of universal request-head guarantees.

# First conversion lemma for the request-line proof, kernel-checked in
# isolation while the two composite parser proofs remain open.
def ascii_encode(s: String) -> {Bytes.ascii(Bytes.encode(s)) == s : String}:
  match s:
    case SNil{}:
      {==}
    case SCon{Chr{c}, t}:
      %ascii_encode(t) : {SCon{Chr{c}, Bytes.ascii(Bytes.encode(t))} == SCon{Chr{c}, _} : String}
      {==}

def Laws.header_lookup_case_insensitive(headers, name, variant, same):
  %same : {Request.lookup_folded(headers, Bytes.fold(name)) == Request.lookup_folded(headers, _) : List<&2, List<&2, U32>>}
  {==}

# Header field reconstruction is checked below. The remaining composition
# needs printable-line proofs, scanner application and header-list induction.
def Laws.request_head_roundtrip(req, valid):
  match req:
    case Request.Req{m, p, q, v, hs}:
      ?TODO

# Token separation and target validation recover the entire request line.
def Laws.parsed_request_line_path(method, path, query, version, valid):
  +line_valid = Equality.and_left(Request.method_valid(method) && Request.target_valid(method, path, query), True{}, valid)
  mv = Equality.and_left(Request.method_valid(method), Request.target_valid(method, path, query), line_valid)
  +tv = Equality.and_right(Request.method_valid(method), Request.target_valid(method, path, query), line_valid)
  %Equal.sym(String, Bytes.prefix(path ++ Request.query_text(query)), path, Line.target_prefix(method, path, query, version, tv)) : {Parse.request_line(Write.line_content(method, path, query, version)) == Parse.Headers{Request.Req{method, _, query, version, []}, [], False{}} : Parse.State}
  Line.line_recover(method, path, query, version, mv, tv)

# The single-header obligation from the request-head round trip.
def Laws.header_line_roundtrip(req, name, value, valid):
  Headers.header_fields(req, name, value, valid)
