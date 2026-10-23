# Reference router: list order is registration order; indexes never skip entries.
import Base
import ./pattern.bend as P

type Route<-T: Data> is Data:
  Route{pattern: P.Pattern, tag: T}

def Table(-T: Data) -> Data:
  List<&2, Route<T>>

type Match<-T: Data> is Data:
  Match{index: Nat, tag: T, params: P.Params}

type Registration<-T: Data> is Data:
  Registration{source: String, tag: T}

type BuildError is Data:
  BuildError{index: Nat, source: String, error: P.PatternError}

# Fail atomically on the first invalid registration, preserving its source index.
def build_step(-T: Data, source: String, index: Nat, tag: T, compiled: Result<&2, &2, P.PatternError, P.Pattern>, rest: Unit -> Result<&2, &2, BuildError, Table(T)>) -> Result<&2, &2, BuildError, Table(T)>:
  match compiled:
    case Done{pattern}:
      do Result<&2, &2, BuildError, Table(T)>:
        tail : Table(T) <- rest(Unit{})
        return Route{pattern, tag} <> tail
    case Fail{error}:
      Fail{BuildError{index, source, error}}

def build_go(-T: Data, entries: List<&2, Registration<T>>, +index: Nat) -> Result<&2, &2, BuildError, Table(T)>:
  match entries:
    case Nil{}:
      Done{Nil{}}
    case Registration{+source, tag} <> rest:
      build_step(T, source, index, tag, P.compile(source), u => build_go(T, rest, 1n+index))

def build_table(-T: Data, entries: List<&2, Registration<T>>) -> Result<&2, &2, BuildError, Table(T)>:
  build_go(T, entries, 0n)

def bump(-T: Data, hit: Maybe<&2, Match<T>>) -> Maybe<&2, Match<T>>:
  match hit:
    case None{}:
      None{}
    case Some{Match{index, tag, params}}:
      Some{Match{1n+index, tag, params}}

# A thunk avoids evaluating the rest of the table after a successful match.
def select(-T: Data, tag: T, hit: Maybe<&2, P.Params>, rest: Unit -> Maybe<&2, Match<T>>) -> Maybe<&2, Match<T>>:
  match hit:
    case None{}:
      bump(T, rest(Unit{}))
    case Some{params}:
      Some{Match{0n, tag, params}}

def route(-T: Data, table: Table(T), +path: String) -> Maybe<&2, Match<T>>:
  match table:
    case Nil{}:
      None{}
    case Route{pattern, tag} <> rest:
      select(T, tag, P.match_path(pattern, path), u => route(T, rest, path))
