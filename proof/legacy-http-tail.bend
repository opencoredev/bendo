# The retained request-line helper uses stack-safe splitting for both lines
# and words. Its result is the same as the original Base-helper definition.
import Base
import ../src/http.bend as Http
import ../src/http/text.bend as Text
import ./text.bend as TP

def path_of_equiv(+req: String) -> {Http.path_of(req) == Http.path_of_spec(req) : String}:
  +line = Http.first_line(Text.split(req, '\n'))
  Equal.trans(String, Http.path_of(req), Http.or_empty(List.get(&2, String, String.split(line, ' '), 1n)), Http.path_of_spec(req),
    Equal.cong(List<&2, String>, String, parts => Http.or_empty(List.get(&2, String, parts, 1n)), Text.split(line, ' '), String.split(line, ' '), TP.split_equiv(line, ' ')),
    Equal.cong(List<&2, String>, String, lines => Http.or_empty(List.get(&2, String, String.split(Http.first_line(lines), ' '), 1n)), Text.split(req, '\n'), String.lines(req), TP.split_equiv(req, '\n')))

law legacy_path_of_stack_safe:
  for +req: String
  {Http.path_of(req) == Http.path_of_spec(req) : String}

def legacy_path_of_stack_safe(req):
  path_of_equiv(req)
