# Proofs of LAWS.bend. Run: bend PROOF.bend --verdict
import Base
import ./src/http.bend as Http
import ./LAWS.bend as Laws
import ./src/router/proofs.bend as PatternProof
import ./src/router/pattern.bend as Pattern
import ./src/router/compile-proofs.bend as CompileProof
import ./src/router/equality-proofs.bend as EqualityProof
import ./src/router/match-proofs.bend as MatchProof

def Laws.text_body_after_blank(body):
  ("HTTP/1.1 200 OK\r\nContent-Type: text/plain; charset=utf-8\r\nConnection: close", ({==}, {==}))

def Laws.path_of_request_line():
  {==}

# BND-14: compilation establishes clean, nonempty segment lists. Matching
# induction composes the scalar codec roundtrip with split/join preservation,
# including the omitted sole optional capture at the root path.
def compiled_roundtrip(+pattern: Pattern.Pattern, +params: Pattern.Params,
    good: {CompileProof.pattern_good(pattern) == True{} : Bool},
    admitted: {Pattern.admissible(pattern, params) == True{} : Bool}) ->
    &path: String -> {Pattern.fill(pattern, params) == Some{path} : Maybe<&2, String>} & {Pattern.match_path(pattern, path) == Some{params} : Maybe<&2, Pattern.Params>}:
  match pattern:
    case Pattern.Pattern{+segs}:
      MatchProof.pattern_roundtrip(segs, params, good, admitted)

def Laws.pattern_fill_match(source, pattern, compiled, params, admitted):
  compiled_roundtrip(pattern, params, CompileProof.compiled_pattern_good(source, pattern, compiled), admitted)
