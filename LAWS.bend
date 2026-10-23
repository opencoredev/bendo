# Bendo's laws. A human states each law; PROOF.bend proves it.
# Agents may add laws. Never delete or weaken one without a written reason
# in the pull request.
import Base
import ./src/http.bend as Http
import ./src/http/bytes.bend as Bytes
import ./src/http/request.bend as Request
import ./src/http/parse.bend as Parse
import ./src/http/write.bend as Write

# LAW: a text response is a head with no blank line in it, then a blank
# line, then the body. So the first blank line in the response is the one
# that ends the head, and a client that cuts there reads the body back.
law text_body_after_blank:
  for +body: String
  exs head: String
  {String.contains(head, "\r\n\r\n") == False{} : Bool} & {head ++ ("\r\n\r\n" ++ body) == Http.text(body) : String}

# LAW: path_of reads the target of a request line. A single example for
# now; ticket 1.1 replaces it with a law over every well-formed request line.
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
