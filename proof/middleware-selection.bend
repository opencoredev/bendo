import Base
import ../src/app/table.bend as T
import ../src/router/methods.bend as M
import ../src/router/pattern.bend as P
import ./middleware-selection-spec.bend as S

# The property is vacuous on construction failures, exact on successes.
def Collected(-Tag: Data, result: Result<&2, &2, M.BuildError, List<&2, T.Middleware<Tag>>>, expected: List<&2, Tag>, path: String) -> Type:
  match result:
    case Fail{error}: Unit
    case Done{layers}: {T.selected(Tag, layers, path) == expected : List<&2, Tag>}

def matching(-Tag: Data, +tag: Tag, +rest: List<&2, Tag>, +result: Maybe<&2, P.Params>) -> {T.include(Tag, tag, rest, Maybe.is_some(&2, P.Params, result)) == S.matching(Tag, tag, rest, result) : List<&2, Tag>}:
  match result:
    case None{}: {==}
    case Some{params}: {==}

def prepend_global(-Tag: Data, +tag: Tag, +rest: Result<&2, &2, M.BuildError, List<&2, T.Middleware<Tag>>>, +expected: List<&2, Tag>, +path: String, proof: Collected(Tag, rest, expected, path)) -> Collected(Tag, T.prepend(Tag, T.Middleware{None{}, tag}, rest), tag <> expected, path):
  match rest:
    case Fail{error}: Unit{}
    case Done{layers}:
      Equal.cong(List<&2, Tag>, List<&2, Tag>, xs => tag <> xs, T.selected(Tag, layers, path), expected, proof)

def prepend_hook(-Tag: Data, +stage: T.Stage, +tag: Tag, +rest: Result<&2, &2, M.BuildError, List<&2, T.Middleware<Tag>>>, +expected: List<&2, Tag>, +path: String, proof: Collected(Tag, rest, expected, path)) -> Collected(Tag, T.prepend(Tag, T.Staged{stage, tag}, rest), expected, path):
  match rest:
    case Fail{error}: Unit{}
    case Done{layers}: proof

def prepend_path(-Tag: Data, +tag: Tag, +pattern: P.Pattern, +rest: Result<&2, &2, M.BuildError, List<&2, T.Middleware<Tag>>>, +expected: List<&2, Tag>, +path: String, proof: Collected(Tag, rest, expected, path)) -> Collected(Tag, T.prepend(Tag, T.Middleware{Some{pattern}, tag}, rest), S.matching(Tag, tag, expected, P.match_path(pattern, path)), path):
  match rest:
    case Fail{error}: Unit{}
    case Done{layers}:
      +matched = P.match_path(pattern, path)
      Equal.trans(List<&2, Tag>, T.include(Tag, tag, T.selected(Tag, layers, path), Maybe.is_some(&2, P.Params, matched)), T.include(Tag, tag, expected, Maybe.is_some(&2, P.Params, matched)), S.matching(Tag, tag, expected, matched), Equal.cong(List<&2, Tag>, List<&2, Tag>, xs => T.include(Tag, tag, xs, Maybe.is_some(&2, P.Params, matched)), T.selected(Tag, layers, path), expected, proof), matching(Tag, tag, expected, matched))

def pattern_built(-Tag: Data, +index: Nat, +source: String, +tag: Tag, +pattern: Result<&2, &2, P.PatternError, P.Pattern>, +rest: Result<&2, &2, M.BuildError, List<&2, T.Middleware<Tag>>>, +expected: List<&2, Tag>, +path: String, proof: Collected(Tag, rest, expected, path)) -> Collected(Tag, T.pattern_built(Tag, index, source, tag, pattern, u => rest), S.compiled(Tag, tag, expected, path, pattern), path):
  match pattern:
    case Fail{error}: Unit{}
    case Done{p}: prepend_path(Tag, tag, p, rest, expected, path, proof)

def route_checked(-Tag: Data, +index: Nat, +checked: Result<&2, &2, M.BuildError, M.Valid<Tag>>, +rest: Result<&2, &2, M.BuildError, List<&2, T.Middleware<Tag>>>, +expected: List<&2, Tag>, +path: String, proof: Collected(Tag, rest, expected, path)) -> Collected(Tag, T.route_checked(Tag, index, checked, u => rest), expected, path):
  match checked:
    case Fail{M.InvalidPattern{old, source, error}}: Unit{}
    case Fail{M.InvalidMethod{old, source, token}}: Unit{}
    case Done{table}: proof

def prepend_scoped(-Tag: Data, +ordinal: Nat, +hooks: List<&2, T.Placement<Tag>>, +rest: Result<&2, &2, M.BuildError, List<&2, T.Middleware<Tag>>>, +expected: List<&2, Tag>, +path: String, proof: Collected(Tag, rest, expected, path)) -> Collected(Tag, T.prepend(Tag, T.Scoped{ordinal, hooks}, rest), expected, path):
  match rest:
    case Fail{error}: Unit{}
    case Done{layers}: proof

def entries(-Tag: Data, +xs: List<&2, T.Entry<Tag>>, +index: Nat, +path: String) -> Collected(Tag, T.middleware_entries(Tag, xs, index), S.filter(Tag, xs, path), path):
  match xs:
    case Nil{}: {==}
    case T.Hook{stage, tag} <> tail:
      prepend_hook(Tag, stage, tag, T.middleware_entries(Tag, tail, 1n+index), S.filter(Tag, tail, path), path, entries(Tag, tail, 1n+index, path))
    case T.Route{r} <> tail:
      route_checked(Tag, index, M.build_table(Tag, [r]), T.middleware_entries(Tag, tail, 1n+index), S.filter(Tag, tail, path), path, entries(Tag, tail, 1n+index, path))
    case T.ScopedRoute{r, hooks} <> tail:
      route_checked(Tag, index, M.build_table(Tag, [r]), T.prepend(Tag, T.Scoped{List.length(&2, M.Registration(Tag), T.route_entries(Tag, tail)), hooks}, T.middleware_entries(Tag, tail, 1n+index)), S.filter(Tag, tail, path), path, prepend_scoped(Tag, List.length(&2, M.Registration(Tag), T.route_entries(Tag, tail)), hooks, T.middleware_entries(Tag, tail, 1n+index), S.filter(Tag, tail, path), path, entries(Tag, tail, 1n+index, path)))
    case T.Use{None{}, tag} <> tail:
      prepend_global(Tag, tag, T.middleware_entries(Tag, tail, 1n+index), S.filter(Tag, tail, path), path, entries(Tag, tail, 1n+index, path))
    case T.Use{Some{source}, tag} <> tail:
      pattern_built(Tag, index, source, tag, P.compile(source), T.middleware_entries(Tag, tail, 1n+index), S.filter(Tag, tail, path), path, entries(Tag, tail, 1n+index, path))

def Built(-Tag: Data, result: Result<&2, &2, M.BuildError, T.Table<Tag>>, expected: List<&2, Tag>, path: String) -> Type:
  match result:
    case Fail{error}: Unit
    case Done{table}: {S.selected(Tag, table, path) == expected : List<&2, Tag>}

def built(-Tag: Data, +routes: List<&2, M.Registration(Tag)>, +layers: List<&2, T.Middleware<Tag>>, +result: Result<&2, &2, M.BuildError, M.Valid<Tag>>, +expected: List<&2, Tag>, +path: String, proof: {T.selected(Tag, layers, path) == expected : List<&2, Tag>}) -> Built(Tag, T.built(Tag, routes, layers, result), expected, path):
  match result:
    case Fail{error}: Unit{}
    case Done{table}: proof

def collected(-Tag: Data, +routes: List<&2, M.Registration(Tag)>, +result: Result<&2, &2, M.BuildError, List<&2, T.Middleware<Tag>>>, +expected: List<&2, Tag>, +path: String, proof: Collected(Tag, result, expected, path)) -> Built(Tag, T.collected(Tag, routes, result), expected, path):
  match result:
    case Fail{error}: Unit{}
    case Done{layers}: built(Tag, routes, layers, M.build_table(Tag, routes), expected, path, proof)

def selection(-Tag: Data, +xs: List<&2, T.Entry<Tag>>, +table: T.Table<Tag>, +path: String, built: {T.build(Tag, xs) == Done{table} : Result<&2, &2, M.BuildError, T.Table<Tag>>}) -> {S.selected(Tag, table, path) == S.filter(Tag, xs, path) : List<&2, Tag>}:
  %built : Built(Tag, _, S.filter(Tag, xs, path), path)
  collected(Tag, T.route_entries(Tag, xs), T.middleware_entries(Tag, xs, 0n), S.filter(Tag, xs, path), path, entries(Tag, xs, 0n, path))
