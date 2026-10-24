# Pure HTTP helpers. Scaffold only: the real request and response types
# arrive with the HTTP core milestone (see docs/PLAN.md).
import Base
import ./http/text.bend as Text

def or_empty(m: Maybe<&2, String>) -> String:
  match m:
    case Some{x}:
      x
    case None{}:
      ""

def first_line(ls: List<&2, String>) -> String:
  or_empty(List.head(&2, String, ls))

# "GET /todos/42 HTTP/1.1\r\n..." -> "/todos/42"
def path_of_spec(req: String) -> String:
  line = first_line(String.lines(req))
  or_empty(List.get(&2, String, String.split(line, ' '), 1n))

def path_of(req: String) -> String:
  line = first_line(Text.split(req, '\n'))
  or_empty(List.get(&2, String, Text.split(line, ' '), 1n))

# A 200 text/plain response that closes the connection.
def text(body: String) -> String:
  "HTTP/1.1 200 OK\r\nContent-Type: text/plain; charset=utf-8\r\nConnection: close\r\n\r\n" ++ body
