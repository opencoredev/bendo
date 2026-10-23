# Proofs of LAWS.bend. Run: bend PROOF.bend --verdict
import Base
import ./src/http.bend as Http
import ./LAWS.bend as Laws
import ./src/router/proofs.bend as PatternProof
import ./src/router/pattern.bend as Pattern

def Laws.text_body_after_blank(body):
  ("HTTP/1.1 200 OK\r\nContent-Type: text/plain; charset=utf-8\r\nConnection: close", ({==}, {==}))

def Laws.path_of_request_line():
  {==}

# BND-14
# src/router/proofs.bend proves fill_segments_success and fill_success under
# independent admissibility, with no compilation or roundtrip premise.
# The matching half still needs strict Unicode codec inversion, split/join
# preservation for compiled static segments, and ordered segment induction.
def pattern_match_remaining(+source: String, +pattern: Pattern.Pattern,
    compiled: {Pattern.compile(source) == Done{pattern} : Result<&2, &2, Pattern.PatternError, Pattern.Pattern>},
    +params: Pattern.Params,
    admitted: {Pattern.admissible(pattern, params) == True{} : Bool},
    success: &path: String -> {Pattern.fill(pattern, params) == Some{path} : Maybe<&2, String>}) ->
    &path: String -> {Pattern.fill(pattern, params) == Some{path} : Maybe<&2, String>} & {Pattern.match_path(pattern, path) == Some{params} : Maybe<&2, Pattern.Params>}:
  (+path, filled) = success
  (path, (filled, ?TODO))

def Laws.pattern_fill_match(source, pattern, compiled, params, admitted):
  +e = admitted
  pattern_match_remaining(source, pattern, compiled, params, e, PatternProof.fill_success(pattern, params, e))
