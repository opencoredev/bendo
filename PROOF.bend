# Proofs of LAWS.bend. Run: bend PROOF.bend --verdict
import Base
import ./src/http.bend as Http
import ./src/http/bytes.bend as Bytes
import ./src/http/request.bend as Request
import ./src/http/parse.bend as Parse
import ./src/http/write.bend as Write
import ./LAWS.bend as Laws

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

# Open: require feed-of-valid-written-line, feed-of-written-header and
# header-list induction. The original laws remain unchanged.
def Laws.request_head_roundtrip(req, valid):
  match req:
    case Request.Req{m, p, q, v, hs}:
      ?TODO

# Open after eliminating ASCII encode/decode: prove the validated token
# split and target reconstruction for arbitrary method/path/query fields.
def Laws.parsed_request_line_path(method, path, query, version, valid):
  +content = Request.method_text(method) ++ " " ++ path ++ Request.query_text(query) ++ " " ++ Request.version_text(version)
  %Equal.sym(String, Bytes.ascii(Bytes.encode(content)), content, ascii_encode(content)) : {Parse.request_line_parts(String.split(_, ' ')) == Parse.Headers{Request.Req{method, Bytes.prefix(path ++ Request.query_text(query)), query, version, []}, [], False{}} : Parse.State}
  ?TODO
