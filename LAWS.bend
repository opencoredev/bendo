# Bendo's laws. A human states each law; PROOF.bend proves it.
# Agents may add laws. Never delete or weaken one without a written reason
# in the pull request.
import Base
import ./src/http.bend as Http
import ./src/router/pattern.bend as Pattern

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
