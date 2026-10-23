# Conservative raw-prefix trie. Candidate validation stays with Pattern.match_path.
import Base
import ./pattern.bend as P
import ./spec.bend as S
import ./encoding.bend as E

type Candidate<-T: Data> is Data:
  Candidate{index: Nat, route: S.Route<T>}

type Trie<-T: Data> is Data:
  Empty{}
  Fork{char: Char, equal: Trie<T>, other: Trie<T>}
  Bucket{entries: List<&2, Candidate<T>>, child: Trie<T>}

# Keep empty static segments; stop before the slash introducing a dynamic one.
def prefix_tail(segments: List<&2, P.Segment>) -> String:
  match segments:
    case P.Static{raw} <> rest:
      "/" ++ raw ++ prefix_tail(rest)
    case _:
      ""

def prefix(pattern: P.Pattern) -> String:
  match pattern:
    case P.Pattern{P.Static{raw} <> rest}:
      "/" ++ raw ++ prefix_tail(rest)
    case _:
      "/"

def singleton(-T: Data, key: String, entry: Candidate<T>) -> Trie<T>:
  match key:
    case SNil{}:
      Bucket{[entry], Empty{}}
    case SCon{char, tail}:
      Fork{char, singleton(T, tail, entry), Empty{}}

# Build inserts in descending index order, so each bucket remains ascending.
def insert(-T: Data, trie: Trie<T>, +key: String, +entry: Candidate<T>) -> Trie<T>:
  match trie key:
    case Empty{} k:
      singleton(T, k, entry)
    case Bucket{entries, child} SNil{}:
      Bucket{entry <> entries, child}
    case Bucket{entries, child} k:
      Bucket{entries, insert(T, child, k, entry)}
    case Fork{char, equal, other} SNil{}:
      Bucket{[entry], Fork{char, equal, other}}
    case Fork{+char, +equal, +other} SCon{+head, +tail}:
      E.choose(Trie<T>, Char.is_eq(char, head), u => (
        Fork{char, insert(T, equal, tail, entry), other}
      ), u => (
        Fork{char, equal, insert(T, other, SCon{head, tail}, entry)}
      ))

def build_go(-T: Data, table: S.Table(T), +index: Nat) -> Trie<T>:
  match table:
    case Nil{}:
      Empty{}
    case S.Route{+pattern, tag} <> rest:
      insert(T, build_go(T, rest, 1n+index), prefix(pattern), Candidate{index, S.Route{pattern, tag}})

def build_trie(-T: Data, table: S.Table(T)) -> Trie<T>:
  build_go(T, table, 0n)

def candidate_hit(-T: Data, index: Nat, tag: T, hit: Maybe<&2, P.Params>, rest: Unit -> Maybe<&2, S.Match<T>>) -> Maybe<&2, S.Match<T>>:
  match hit:
    case None{}:
      rest(Unit{})
    case Some{params}:
      Some{S.Match{index, tag, params}}

def candidates(-T: Data, entries: List<&2, Candidate<T>>, +path: String) -> Maybe<&2, S.Match<T>>:
  match entries:
    case Nil{}:
      None{}
    case Candidate{index, S.Route{pattern, tag}} <> rest:
      candidate_hit(T, index, tag, P.match_path(pattern, path), u => candidates(T, rest, path))

def minimum(-T: Data, a: Maybe<&2, S.Match<T>>, b: Maybe<&2, S.Match<T>>) -> Maybe<&2, S.Match<T>>:
  match a b:
    case None{} hit:
      hit
    case hit None{}:
      hit
    case Some{S.Match{+i, tag, params}} Some{S.Match{+j, tag2, params2}}:
      E.choose(Maybe<&2, S.Match<T>>, Nat.is_le(i, j), u => Some{S.Match{i, tag, params}}, u => Some{S.Match{j, tag2, params2}})

# Inspect buckets even when the suffix is empty. Preserve ancestor matches.
def lookup(-T: Data, trie: Trie<T>, +suffix: String, +path: String) -> Maybe<&2, S.Match<T>>:
  match trie suffix:
    case Empty{} _:
      None{}
    case Bucket{entries, child} s:
      minimum(T, candidates(T, entries, path), lookup(T, child, s, path))
    case Fork{char, equal, other} SNil{}:
      None{}
    case Fork{char, equal, other} SCon{+head, tail}:
      E.choose(Maybe<&2, S.Match<T>>, Char.is_eq(char, head), u => lookup(T, equal, tail, path), u => lookup(T, other, SCon{head, tail}, path))

def trie_route(-T: Data, trie: Trie<T>, +path: String) -> Maybe<&2, S.Match<T>>:
  lookup(T, trie, path, path)
