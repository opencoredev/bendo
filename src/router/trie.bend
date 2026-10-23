# Segment trie over leading static segments. Candidate validation stays with
# Pattern.match_path; see docs/router-trie.md and trie-proofs.bend.
import Base
import ./pattern.bend as P
import ./spec.bend as S
import ./encoding.bend as E

type Candidate<-T: Data> is Data:
  Candidate{index: Nat, route: S.Route<T>}

# Characters of one segment branch through Fork; Node marks a complete segment.
# A node stores every route whose key is a prefix of the segments read so far,
# in registration order, so lookup never merges or sorts.
type Trie<-T: Data> is Data:
  Tip{}
  Fork{char: Char, equal: Trie<T>, other: Trie<T>}
  Node{entries: List<&2, Candidate<T>>, kids: Trie<T>, other: Trie<T>}

# A route's key is its leading run of raw static segments.
def key(segments: List<&2, P.Segment>) -> List<&2, String>:
  match segments:
    case P.Static{raw} <> rest:
      raw <> key(rest)
    case _:
      Nil{}

def pattern_key(pattern: P.Pattern) -> List<&2, String>:
  P.Pattern{segments} = pattern
  key(segments)

# The raw segments Pattern.match_path compares; other paths match nothing.
def query(path: String) -> List<&2, String>:
  match path:
    case SCon{'/', tail}:
      P.path_segments(tail)
    case _:
      Nil{}

# A new chain for the rest of a key. `parent` is the nearest node's list.
def fresh(-T: Data, rest: List<&2, String>, segment: String, +entry: Candidate<T>, +parent: List<&2, Candidate<T>>) -> Trie<T>:
  match rest segment:
    case r SCon{head, tail}:
      Fork{head, fresh(T, r, tail, entry, parent), Tip{}}
    case Nil{} SNil{}:
      Node{entry <> parent, Tip{}, Tip{}}
    case next <> more SNil{}:
      Node{parent, fresh(T, more, next, entry, parent), Tip{}}

# Add an entry with a smaller index than every stored one to all nodes below.
def prepend(-T: Data, trie: Trie<T>, +entry: Candidate<T>) -> Trie<T>:
  match trie:
    case Tip{}:
      Tip{}
    case Fork{char, equal, other}:
      Fork{char, prepend(T, equal, entry), prepend(T, other, entry)}
    case Node{entries, kids, other}:
      Node{entry <> entries, prepend(T, kids, entry), prepend(T, other, entry)}

# Insert `segment` (remaining characters) then `rest`. Build inserts in
# descending index order, so prepending keeps every list ascending.
def insert(-T: Data, trie: Trie<T>, segment: String, +rest: List<&2, String>, +entry: Candidate<T>, +parent: List<&2, Candidate<T>>) -> Trie<T>:
  match trie segment:
    case Tip{} s:
      fresh(T, rest, s, entry, parent)
    case Fork{+char, +equal, +other} SCon{+head, +tail}:
      E.choose(Trie<T>, Char.is_eq(char, head), u => (
        Fork{char, insert(T, equal, tail, rest, entry, parent), other}
      ), u => (
        Fork{char, equal, insert(T, other, SCon{head, tail}, rest, entry, parent)}
      ))
    case Fork{char, equal, other} SNil{}:
      match rest:
        case Nil{}:
          Node{entry <> parent, Tip{}, Fork{char, equal, other}}
        case next <> more:
          Node{parent, fresh(T, more, next, entry, parent), Fork{char, equal, other}}
    case Node{+entries, kids, other} SNil{}:
      match rest:
        case Nil{}:
          Node{entry <> entries, prepend(T, kids, entry), other}
        case next <> more:
          Node{entries, insert(T, kids, next, more, entry, entries), other}
    case Node{entries, kids, other} SCon{head, tail}:
      Node{entries, kids, insert(T, other, SCon{head, tail}, rest, entry, parent)}

# Return the list of the deepest node on the query's path.
def find(-T: Data, trie: Trie<T>, +segment: String, +segments: List<&2, String>, +fallback: List<&2, Candidate<T>>) -> List<&2, Candidate<T>>:
  match trie segment:
    case Tip{} s:
      fallback
    case Fork{char, equal, other} SNil{}:
      fallback
    case Fork{+char, +equal, +other} SCon{+head, +tail}:
      E.choose(List<&2, Candidate<T>>, Char.is_eq(char, head), u => (
        find(T, equal, tail, segments, fallback)
      ), u => (
        find(T, other, SCon{head, tail}, segments, fallback)
      ))
    case Node{entries, kids, other} SNil{}:
      match segments:
        case Nil{}:
          entries
        case next <> more:
          find(T, kids, next, more, entries)
    case Node{entries, kids, other} SCon{head, tail}:
      find(T, other, SCon{head, tail}, segments, fallback)

def build_go(-T: Data, table: S.Table(T), +index: Nat) -> Trie<T>:
  match table:
    case Nil{}:
      Tip{}
    case S.Route{+pattern, tag} <> rest:
      insert(T, build_go(T, rest, 1n+index), "", pattern_key(pattern), Candidate{index, S.Route{pattern, tag}}, Nil{})

def build_trie(-T: Data, table: S.Table(T)) -> Trie<T>:
  build_go(T, table, 0n)

# Every route that can match `path`, ascending by index, plus routes that
# share the static prefix but may still fail Pattern.match_path.
def candidates(-T: Data, trie: Trie<T>, path: String) -> List<&2, Candidate<T>>:
  find(T, trie, "", query(path), Nil{})

def candidate_hit(-T: Data, index: Nat, tag: T, hit: Maybe<&2, P.Params>, rest: Unit -> Maybe<&2, S.Match<T>>) -> Maybe<&2, S.Match<T>>:
  match hit:
    case None{}:
      rest(Unit{})
    case Some{params}:
      Some{S.Match{index, tag, params}}

# The first candidate that matches; later candidates are never evaluated.
def first(-T: Data, entries: List<&2, Candidate<T>>, +path: String) -> Maybe<&2, S.Match<T>>:
  match entries:
    case Nil{}:
      None{}
    case Candidate{index, S.Route{pattern, tag}} <> rest:
      candidate_hit(T, index, tag, P.match_path(pattern, path), u => first(T, rest, path))

def keep(-T: Data, index: Nat, tag: T, hit: Maybe<&2, P.Params>, rest: List<&2, S.Match<T>>) -> List<&2, S.Match<T>>:
  match hit:
    case None{}:
      rest
    case Some{params}:
      S.Match{index, tag, params} <> rest

# Every matching candidate, in order, with its decoded params.
def hits(-T: Data, entries: List<&2, Candidate<T>>, +path: String) -> List<&2, S.Match<T>>:
  match entries:
    case Nil{}:
      Nil{}
    case Candidate{index, S.Route{pattern, tag}} <> rest:
      keep(T, index, tag, P.match_path(pattern, path), hits(T, rest, path))

def trie_route(-T: Data, trie: Trie<T>, +path: String) -> Maybe<&2, S.Match<T>>:
  first(T, candidates(T, trie, path), path)

def matches(-T: Data, trie: Trie<T>, +path: String) -> List<&2, S.Match<T>>:
  hits(T, candidates(T, trie, path), path)

# Every table entry as a candidate, for engines that do not prefilter.
def indexed(-T: Data, table: S.Table(T), +index: Nat) -> List<&2, Candidate<T>>:
  match table:
    case Nil{}:
      Nil{}
    case route <> rest:
      Candidate{index, route} <> indexed(T, rest, 1n+index)
