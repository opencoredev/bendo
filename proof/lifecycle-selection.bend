import Base
import ../src/app/table.bend as T
import ../src/router/methods.bend as M
import ../src/router/pattern.bend as P
import ./middleware-selection-spec.bend as S

# Stage equality is checked by exhaustive constructors, independently of numbering.
def same(+a: T.Stage, +b: T.Stage) -> {U32.is_eq(T.stage_number(a), T.stage_number(b)) == S.same_stage(a, b) : Bool}:
  match a:
    case T.Request{}:
      match b:
        case T.Request{}: {==}
        case T.Parse{}: {==}
        case T.Transform{}: {==}
        case T.BeforeHandle{}: {==}
        case T.AfterHandle{}: {==}
        case T.MapResponse{}: {==}
        case T.Error{}: {==}
        case T.AfterResponse{}: {==}
    case T.Parse{}:
      match b:
        case T.Request{}: {==}
        case T.Parse{}: {==}
        case T.Transform{}: {==}
        case T.BeforeHandle{}: {==}
        case T.AfterHandle{}: {==}
        case T.MapResponse{}: {==}
        case T.Error{}: {==}
        case T.AfterResponse{}: {==}
    case T.Transform{}:
      match b:
        case T.Request{}: {==}
        case T.Parse{}: {==}
        case T.Transform{}: {==}
        case T.BeforeHandle{}: {==}
        case T.AfterHandle{}: {==}
        case T.MapResponse{}: {==}
        case T.Error{}: {==}
        case T.AfterResponse{}: {==}
    case T.BeforeHandle{}:
      match b:
        case T.Request{}: {==}
        case T.Parse{}: {==}
        case T.Transform{}: {==}
        case T.BeforeHandle{}: {==}
        case T.AfterHandle{}: {==}
        case T.MapResponse{}: {==}
        case T.Error{}: {==}
        case T.AfterResponse{}: {==}
    case T.AfterHandle{}:
      match b:
        case T.Request{}: {==}
        case T.Parse{}: {==}
        case T.Transform{}: {==}
        case T.BeforeHandle{}: {==}
        case T.AfterHandle{}: {==}
        case T.MapResponse{}: {==}
        case T.Error{}: {==}
        case T.AfterResponse{}: {==}
    case T.MapResponse{}:
      match b:
        case T.Request{}: {==}
        case T.Parse{}: {==}
        case T.Transform{}: {==}
        case T.BeforeHandle{}: {==}
        case T.AfterHandle{}: {==}
        case T.MapResponse{}: {==}
        case T.Error{}: {==}
        case T.AfterResponse{}: {==}
    case T.Error{}:
      match b:
        case T.Request{}: {==}
        case T.Parse{}: {==}
        case T.Transform{}: {==}
        case T.BeforeHandle{}: {==}
        case T.AfterHandle{}: {==}
        case T.MapResponse{}: {==}
        case T.Error{}: {==}
        case T.AfterResponse{}: {==}
    case T.AfterResponse{}:
      match b:
        case T.Request{}: {==}
        case T.Parse{}: {==}
        case T.Transform{}: {==}
        case T.BeforeHandle{}: {==}
        case T.AfterHandle{}: {==}
        case T.MapResponse{}: {==}
        case T.Error{}: {==}
        case T.AfterResponse{}: {==}

def Collected(-Tag: Data, result: Result<&2, &2, M.BuildError, List<&2, T.Middleware<Tag>>>, expected: List<&2, Tag>, stage: T.Stage) -> Type:
  match result:
    case Fail{error}: Unit
    case Done{layers}: {T.stage_ids(Tag, layers, stage) == expected : List<&2, Tag>}

def prepend_use(-Tag: Data, +pattern: Maybe<&2, P.Pattern>, +tag: Tag, +rest: Result<&2, &2, M.BuildError, List<&2, T.Middleware<Tag>>>, +expected: List<&2, Tag>, +stage: T.Stage, proof: Collected(Tag, rest, expected, stage)) -> Collected(Tag, T.prepend(Tag, T.Middleware{pattern, tag}, rest), expected, stage):
  match rest:
    case Fail{error}: Unit{}
    case Done{layers}: proof

def keep(-Tag: Data, +tag: Tag, +rest: List<&2, Tag>, +yes: Bool) -> {T.include(Tag, tag, rest, yes) == S.keep(Tag, tag, rest, yes) : List<&2, Tag>}:
  match yes:
    case True{}: {==}
    case False{}: {==}

def prepend_hook(-Tag: Data, +kind: T.Stage, +tag: Tag, +rest: Result<&2, &2, M.BuildError, List<&2, T.Middleware<Tag>>>, +expected: List<&2, Tag>, +stage: T.Stage, proof: Collected(Tag, rest, expected, stage)) -> Collected(Tag, T.prepend(Tag, T.Staged{kind, tag}, rest), S.keep(Tag, tag, expected, S.same_stage(kind, stage)), stage):
  match rest:
    case Fail{error}: Unit{}
    case Done{layers}:
      %Equal.sym(Bool, U32.is_eq(T.stage_number(kind), T.stage_number(stage)), S.same_stage(kind, stage), same(kind, stage)) : {T.include(Tag, tag, T.stage_ids(Tag, layers, stage), _) == S.keep(Tag, tag, expected, S.same_stage(kind, stage)) : List<&2, Tag>}
      %Equal.sym(List<&2, Tag>, T.stage_ids(Tag, layers, stage), expected, proof) : {T.include(Tag, tag, _, S.same_stage(kind, stage)) == S.keep(Tag, tag, expected, S.same_stage(kind, stage)) : List<&2, Tag>}
      keep(Tag, tag, expected, S.same_stage(kind, stage))

def pattern_built(-Tag: Data, +index: Nat, +source: String, +tag: Tag, +pattern: Result<&2, &2, P.PatternError, P.Pattern>, +rest: Result<&2, &2, M.BuildError, List<&2, T.Middleware<Tag>>>, +expected: List<&2, Tag>, +stage: T.Stage, proof: Collected(Tag, rest, expected, stage)) -> Collected(Tag, T.pattern_built(Tag, index, source, tag, pattern, u => rest), expected, stage):
  match pattern:
    case Fail{error}: Unit{}
    case Done{p}: prepend_use(Tag, Some{p}, tag, rest, expected, stage, proof)

def route_checked(-Tag: Data, +index: Nat, +checked: Result<&2, &2, M.BuildError, M.Valid<Tag>>, +rest: Result<&2, &2, M.BuildError, List<&2, T.Middleware<Tag>>>, +expected: List<&2, Tag>, +stage: T.Stage, proof: Collected(Tag, rest, expected, stage)) -> Collected(Tag, T.route_checked(Tag, index, checked, u => rest), expected, stage):
  match checked:
    case Fail{M.InvalidPattern{old, source, error}}: Unit{}
    case Fail{M.InvalidMethod{old, source, token}}: Unit{}
    case Done{table}: proof

def prepend_scoped(-Tag: Data, +ordinal: Nat, +hooks: List<&2, T.Placement<Tag>>, +rest: Result<&2, &2, M.BuildError, List<&2, T.Middleware<Tag>>>, +expected: List<&2, Tag>, +stage: T.Stage, proof: Collected(Tag, rest, expected, stage)) -> Collected(Tag, T.prepend(Tag, T.Scoped{ordinal, hooks}, rest), expected, stage):
  match rest:
    case Fail{error}: Unit{}
    case Done{layers}: proof

def entries(-Tag: Data, +xs: List<&2, T.Entry<Tag>>, +index: Nat, +stage: T.Stage) -> Collected(Tag, T.middleware_entries(Tag, xs, index), S.hooks(Tag, xs, stage), stage):
  match xs:
    case Nil{}: {==}
    case T.Hook{kind, tag} <> tail:
      prepend_hook(Tag, kind, tag, T.middleware_entries(Tag, tail, 1n+index), S.hooks(Tag, tail, stage), stage, entries(Tag, tail, 1n+index, stage))
    case T.Route{r} <> tail:
      route_checked(Tag, index, M.build_table(Tag, [r]), T.middleware_entries(Tag, tail, 1n+index), S.hooks(Tag, tail, stage), stage, entries(Tag, tail, 1n+index, stage))
    case T.ScopedRoute{r, hooks} <> tail:
      route_checked(Tag, index, M.build_table(Tag, [r]), T.prepend(Tag, T.Scoped{List.length(&2, M.Registration(Tag), T.route_entries(Tag, tail)), hooks}, T.middleware_entries(Tag, tail, 1n+index)), S.hooks(Tag, tail, stage), stage, prepend_scoped(Tag, List.length(&2, M.Registration(Tag), T.route_entries(Tag, tail)), hooks, T.middleware_entries(Tag, tail, 1n+index), S.hooks(Tag, tail, stage), stage, entries(Tag, tail, 1n+index, stage)))
    case T.Use{None{}, tag} <> tail:
      prepend_use(Tag, None{}, tag, T.middleware_entries(Tag, tail, 1n+index), S.hooks(Tag, tail, stage), stage, entries(Tag, tail, 1n+index, stage))
    case T.Use{Some{source}, tag} <> tail:
      pattern_built(Tag, index, source, tag, P.compile(source), T.middleware_entries(Tag, tail, 1n+index), S.hooks(Tag, tail, stage), stage, entries(Tag, tail, 1n+index, stage))

def Built(-Tag: Data, result: Result<&2, &2, M.BuildError, T.Table<Tag>>, expected: List<&2, Tag>, stage: T.Stage) -> Type:
  match result:
    case Fail{error}: Unit
    case Done{T.Table{routes, compiled, layers, count}}: {T.stage_ids(Tag, layers, stage) == expected : List<&2, Tag>}

def built(-Tag: Data, +routes: List<&2, M.Registration(Tag)>, +layers: List<&2, T.Middleware<Tag>>, +result: Result<&2, &2, M.BuildError, M.Valid<Tag>>, +expected: List<&2, Tag>, +stage: T.Stage, proof: {T.stage_ids(Tag, layers, stage) == expected : List<&2, Tag>}) -> Built(Tag, T.built(Tag, routes, layers, result), expected, stage):
  match result:
    case Fail{error}: Unit{}
    case Done{table}: proof

def collected(-Tag: Data, +routes: List<&2, M.Registration(Tag)>, +result: Result<&2, &2, M.BuildError, List<&2, T.Middleware<Tag>>>, +expected: List<&2, Tag>, +stage: T.Stage, proof: Collected(Tag, result, expected, stage)) -> Built(Tag, T.collected(Tag, routes, result), expected, stage):
  match result:
    case Fail{error}: Unit{}
    case Done{layers}: built(Tag, routes, layers, M.build_table(Tag, routes), expected, stage, proof)

def selection(-Tag: Data, +xs: List<&2, T.Entry<Tag>>, +routes: List<&2, M.Registration(Tag)>, +compiled: M.Index<Tag>, +layers: List<&2, T.Middleware<Tag>>, +count: Nat, +stage: T.Stage, built: {T.build(Tag, xs) == Done{T.Table{routes, compiled, layers, count}} : Result<&2, &2, M.BuildError, T.Table<Tag>>}) -> {T.stage_ids(Tag, layers, stage) == S.hooks(Tag, xs, stage) : List<&2, Tag>}:
  %built : Built(Tag, _, S.hooks(Tag, xs, stage), stage)
  collected(Tag, T.route_entries(Tag, xs), T.middleware_entries(Tag, xs, 0n), S.hooks(Tag, xs, stage), stage, entries(Tag, xs, 0n, stage))
