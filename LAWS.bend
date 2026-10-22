# Bendo's laws. A human states each law; PROOF.bend proves it.
# Agents may add laws. Never delete or weaken one without a written reason
# in the pull request.
import Base
import ./src/http.bend as Http

# LAW: a text response is some head, a blank line, then the body, so a
# client that cuts at the first blank line reads the body back.
law text_body_after_blank:
  for +body: String
  exs head: String
  {head ++ ("\r\n\r\n" ++ body) == Http.text(body) : String}

# LAW: path_of reads the target of a request line.
law path_of_request_line:
  {Http.path_of("GET /todos/42 HTTP/1.1\r\nHost: x\r\n\r\n") == "/todos/42" : String}
