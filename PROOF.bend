# Proofs of LAWS.bend. Run: bend PROOF.bend --verdict
import Base
import ./src/http.bend as Http
import ./LAWS.bend as Laws
import ./src/router/proofs.bend as PatternProof
import ./src/router/pattern.bend as Pattern
import ./src/router/compile-proofs.bend as CompileProof
import ./src/router/equality-proofs.bend as EqualityProof

def Laws.text_body_after_blank(body):
  ("HTTP/1.1 200 OK\r\nContent-Type: text/plain; charset=utf-8\r\nConnection: close", ({==}, {==}))

def Laws.path_of_request_line():
  {==}

# BND-14
# src/router/proofs.bend proves fill_segments_success and fill_success under
# independent admissibility, with no compilation or roundtrip premise.
# It also proves split/join preservation for nonempty slash-free segment lists
# and that splitting a source produces slash-free segments. Its transitive
# import octet-proofs.bend proves percent inversion for every octet list and
# separator absence. These helpers are checked by this root verdict gate.
# Still open: Unicode codec inversion and its connection to octet encoding,
# propagation of split cleanliness through compilation, and matching induction.
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
