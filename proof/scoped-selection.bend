import Base
import ../src/app/table.bend as T
import ../src/router/methods.bend as M
import ../src/router/pattern.bend as P
import ./scoped-selection-spec.bend as S
import ./middleware-selection-spec.bend as Global
import ./lifecycle-selection.bend as Legacy
import ../src/router/proofs.bend as Core
import ./middleware-selection.bend as Ordinary
import ../src/app/route-slot.bend as Slot
import ../src/router/spec.bend as RouterSpec
import ../src/router/router.bend as Router
import ../src/http/request.bend as Request

def source_count(-Tag: Data, +xs: List<&2, T.Entry<Tag>>) -> {List.length(&2, M.Registration(Tag), T.route_entries(Tag, xs)) == S.route_count(Tag, xs) : Nat}:
  match xs:
    case Nil{}: {==}
    case T.Route{r} <> tail:
      Equal.cong(Nat, Nat, n => 1n+n, List.length(&2, M.Registration(Tag), T.route_entries(Tag, tail)), S.route_count(Tag, tail), source_count(Tag, tail))
    case T.ScopedRoute{r, hooks} <> tail:
      Equal.cong(Nat, Nat, n => 1n+n, List.length(&2, M.Registration(Tag), T.route_entries(Tag, tail)), S.route_count(Tag, tail), source_count(Tag, tail))
    case T.Hook{stage, tag} <> tail: source_count(Tag, tail)
    case T.Use{source, tag} <> tail: source_count(Tag, tail)

def hooks(-Tag: Data, +xs: List<&2, T.Placement<Tag>>, +stage: T.Stage) -> {T.hook_ids(Tag, xs, stage) == S.hooks(Tag, xs, stage) : List<&2, Tag>}:
  match xs:
    case Nil{}: {==}
    case T.Placement{scope, T.HookSpec{kind, tag}} <> tail:
      %Equal.sym(Bool, U32.is_eq(T.stage_number(kind), T.stage_number(stage)), Global.same_stage(kind, stage), Legacy.same(kind, stage)) : {T.include(Tag, tag, T.hook_ids(Tag, tail, stage), _) == Global.keep(Tag, tag, S.hooks(Tag, tail, stage), Global.same_stage(kind, stage)) : List<&2, Tag>}
      %Equal.sym(List<&2, Tag>, T.hook_ids(Tag, tail, stage), S.hooks(Tag, tail, stage), hooks(Tag, tail, stage)) : {T.include(Tag, tag, _, Global.same_stage(kind, stage)) == Global.keep(Tag, tag, S.hooks(Tag, tail, stage), Global.same_stage(kind, stage)) : List<&2, Tag>}
      Legacy.keep(Tag, tag, S.hooks(Tag, tail, stage), Global.same_stage(kind, stage))

def at(-Tag: Data, +xs: List<&2, T.Placement<Tag>>, +stage: T.Stage, yes: Bool) -> {T.include_hooks(Tag, xs, stage, yes) == S.at(Tag, xs, stage, yes) : List<&2, Tag>}:
  match yes:
    case True{}: hooks(Tag, xs, stage)
    case False{}: {==}

def Collected(-Tag: Data, result: Result<&2, &2, M.BuildError, List<&2, T.Middleware<Tag>>>, expected: List<&2, Tag>, route: Maybe<&2, Nat>, stage: T.Stage) -> Type:
  match result:
    case Fail{error}: Unit
    case Done{layers}: {T.route_stage_ids(Tag, layers, route, stage) == expected : List<&2, Tag>}

def prepend_use(-Tag: Data, +pattern: Maybe<&2, P.Pattern>, +tag: Tag, +rest: Result<&2, &2, M.BuildError, List<&2, T.Middleware<Tag>>>, +expected: List<&2, Tag>, +route: Maybe<&2, Nat>, +stage: T.Stage, proof: Collected(Tag, rest, expected, route, stage)) -> Collected(Tag, T.prepend(Tag, T.Middleware{pattern, tag}, rest), expected, route, stage):
  match rest:
    case Fail{error}: Unit{}
    case Done{layers}: proof

def prepend_hook(-Tag: Data, +kind: T.Stage, +tag: Tag, +rest: Result<&2, &2, M.BuildError, List<&2, T.Middleware<Tag>>>, +expected: List<&2, Tag>, +route: Maybe<&2, Nat>, +stage: T.Stage, proof: Collected(Tag, rest, expected, route, stage)) -> Collected(Tag, T.prepend(Tag, T.Staged{kind, tag}, rest), expected, route, stage):
  match rest:
    case Fail{error}: Unit{}
    case Done{layers}: proof

def pattern_built(-Tag: Data, +index: Nat, +source: String, +tag: Tag, +pattern: Result<&2, &2, P.PatternError, P.Pattern>, +rest: Result<&2, &2, M.BuildError, List<&2, T.Middleware<Tag>>>, +expected: List<&2, Tag>, +route: Maybe<&2, Nat>, +stage: T.Stage, proof: Collected(Tag, rest, expected, route, stage)) -> Collected(Tag, T.pattern_built(Tag, index, source, tag, pattern, u => rest), expected, route, stage):
  match pattern:
    case Fail{error}: Unit{}
    case Done{p}: prepend_use(Tag, Some{p}, tag, rest, expected, route, stage, proof)

def route_checked(-Tag: Data, +index: Nat, +checked: Result<&2, &2, M.BuildError, M.Valid<Tag>>, +rest: Result<&2, &2, M.BuildError, List<&2, T.Middleware<Tag>>>, +expected: List<&2, Tag>, +route: Maybe<&2, Nat>, +stage: T.Stage, proof: Collected(Tag, rest, expected, route, stage)) -> Collected(Tag, T.route_checked(Tag, index, checked, u => rest), expected, route, stage):
  match checked:
    case Fail{M.InvalidPattern{old, source, error}}: Unit{}
    case Fail{M.InvalidMethod{old, source, token}}: Unit{}
    case Done{table}: proof

def scoped_expected(-Tag: Data, +ordinal: Nat, +hooks: List<&2, T.Placement<Tag>>, +expected: List<&2, Tag>, route: Maybe<&2, Nat>, +stage: T.Stage) -> List<&2, Tag>:
  match route:
    case None{}: expected
    case Some{n}: List.append(&2, Tag, S.at(Tag, hooks, stage, Nat.is_eq(ordinal, n)), expected)

def prepend_scoped(-Tag: Data, +ordinal: Nat, +hooks: List<&2, T.Placement<Tag>>, +rest: Result<&2, &2, M.BuildError, List<&2, T.Middleware<Tag>>>, +expected: List<&2, Tag>, +route: Maybe<&2, Nat>, +stage: T.Stage, proof: Collected(Tag, rest, expected, route, stage)) -> Collected(Tag, T.prepend(Tag, T.Scoped{ordinal, hooks}, rest), scoped_expected(Tag, ordinal, hooks, expected, route, stage), route, stage):
  match rest:
    case Fail{error}: Unit{}
    case Done{layers}:
      match route:
        case None{}: proof
        case Some{n}:
          %Equal.sym(List<&2, Tag>, T.include_hooks(Tag, hooks, stage, Nat.is_eq(ordinal, n)), S.at(Tag, hooks, stage, Nat.is_eq(ordinal, n)), at(Tag, hooks, stage, Nat.is_eq(ordinal, n))) : {List.append(&2, Tag, _, T.route_stage_ids(Tag, layers, Some{n}, stage)) == List.append(&2, Tag, S.at(Tag, hooks, stage, Nat.is_eq(ordinal, n)), expected) : List<&2, Tag>}
          Equal.cong(List<&2, Tag>, List<&2, Tag>, xs => List.append(&2, Tag, S.at(Tag, hooks, stage, Nat.is_eq(ordinal, n)), xs), T.route_stage_ids(Tag, layers, Some{n}, stage), expected, proof)

def expected(-Tag: Data, +r: M.Registration(Tag), +placements: List<&2, T.Placement<Tag>>, +tail: List<&2, T.Entry<Tag>>, +route: Maybe<&2, Nat>, +stage: T.Stage) -> {scoped_expected(Tag, List.length(&2, M.Registration(Tag), T.route_entries(Tag, tail)), placements, S.route_hooks(Tag, tail, route, stage), route, stage) == S.route_hooks(Tag, T.ScopedRoute{r, placements} <> tail, route, stage) : List<&2, Tag>}:
  match route:
    case None{}: {==}
    case Some{n}:
      Equal.cong(Nat, List<&2, Tag>, k => List.append(&2, Tag, S.at(Tag, placements, stage, Nat.is_eq(k, n)), S.route_hooks(Tag, tail, Some{n}, stage)), List.length(&2, M.Registration(Tag), T.route_entries(Tag, tail)), S.route_count(Tag, tail), source_count(Tag, tail))

def entries(-Tag: Data, +xs: List<&2, T.Entry<Tag>>, +index: Nat, +route: Maybe<&2, Nat>, +stage: T.Stage) -> Collected(Tag, T.middleware_entries(Tag, xs, index), S.route_hooks(Tag, xs, route, stage), route, stage):
  match xs:
    case Nil{}: {==}
    case T.Hook{kind, tag} <> tail:
      prepend_hook(Tag, kind, tag, T.middleware_entries(Tag, tail, 1n+index), S.route_hooks(Tag, tail, route, stage), route, stage, entries(Tag, tail, 1n+index, route, stage))
    case T.Route{r} <> tail:
      route_checked(Tag, index, M.build_table(Tag, [r]), T.middleware_entries(Tag, tail, 1n+index), S.route_hooks(Tag, tail, route, stage), route, stage, entries(Tag, tail, 1n+index, route, stage))
    case T.ScopedRoute{r, hooks} <> tail:
      %expected(Tag, r, hooks, tail, route, stage) : Collected(Tag, T.middleware_entries(Tag, T.ScopedRoute{r, hooks} <> tail, index), _, route, stage)
      route_checked(Tag, index, M.build_table(Tag, [r]), T.prepend(Tag, T.Scoped{List.length(&2, M.Registration(Tag), T.route_entries(Tag, tail)), hooks}, T.middleware_entries(Tag, tail, 1n+index)), scoped_expected(Tag, List.length(&2, M.Registration(Tag), T.route_entries(Tag, tail)), hooks, S.route_hooks(Tag, tail, route, stage), route, stage), route, stage, prepend_scoped(Tag, List.length(&2, M.Registration(Tag), T.route_entries(Tag, tail)), hooks, T.middleware_entries(Tag, tail, 1n+index), S.route_hooks(Tag, tail, route, stage), route, stage, entries(Tag, tail, 1n+index, route, stage)))
    case T.Use{None{}, tag} <> tail:
      prepend_use(Tag, None{}, tag, T.middleware_entries(Tag, tail, 1n+index), S.route_hooks(Tag, tail, route, stage), route, stage, entries(Tag, tail, 1n+index, route, stage))
    case T.Use{Some{source}, tag} <> tail:
      pattern_built(Tag, index, source, tag, P.compile(source), T.middleware_entries(Tag, tail, 1n+index), S.route_hooks(Tag, tail, route, stage), route, stage, entries(Tag, tail, 1n+index, route, stage))

def Built(-Tag: Data, result: Result<&2, &2, M.BuildError, T.Table<Tag>>, expected: List<&2, Tag>, route: Maybe<&2, Nat>, stage: T.Stage) -> Type:
  match result:
    case Fail{error}: Unit
    case Done{T.Table{routes, compiled, layers, count}}: {T.route_stage_ids(Tag, layers, route, stage) == expected : List<&2, Tag>}

def built(-Tag: Data, +routes: List<&2, M.Registration(Tag)>, +layers: List<&2, T.Middleware<Tag>>, +result: Result<&2, &2, M.BuildError, M.Valid<Tag>>, +expected: List<&2, Tag>, +route: Maybe<&2, Nat>, +stage: T.Stage, proof: {T.route_stage_ids(Tag, layers, route, stage) == expected : List<&2, Tag>}) -> Built(Tag, T.built(Tag, routes, layers, result), expected, route, stage):
  match result:
    case Fail{error}: Unit{}
    case Done{table}: proof

def collected(-Tag: Data, +routes: List<&2, M.Registration(Tag)>, +result: Result<&2, &2, M.BuildError, List<&2, T.Middleware<Tag>>>, +expected: List<&2, Tag>, +route: Maybe<&2, Nat>, +stage: T.Stage, proof: Collected(Tag, result, expected, route, stage)) -> Built(Tag, T.collected(Tag, routes, result), expected, route, stage):
  match result:
    case Fail{error}: Unit{}
    case Done{layers}: built(Tag, routes, layers, M.build_table(Tag, routes), expected, route, stage, proof)

def selection(-Tag: Data, +xs: List<&2, T.Entry<Tag>>, +routes: List<&2, M.Registration(Tag)>, +compiled: M.Index<Tag>, +layers: List<&2, T.Middleware<Tag>>, +count: Nat, +route: Maybe<&2, Nat>, +stage: T.Stage, built: {T.build(Tag, xs) == Done{T.Table{routes, compiled, layers, count}} : Result<&2, &2, M.BuildError, T.Table<Tag>>}) -> {T.route_stage_ids(Tag, layers, route, stage) == S.route_hooks(Tag, xs, route, stage) : List<&2, Tag>}:
  %built : Built(Tag, _, S.route_hooks(Tag, xs, route, stage), route, stage)
  collected(Tag, T.route_entries(Tag, xs), T.middleware_entries(Tag, xs, 0n), S.route_hooks(Tag, xs, route, stage), route, stage, entries(Tag, xs, 0n, route, stage))

# Combine the independent global and scoped filters only after each is proved.
def stage_selection(-Tag: Data, +xs: List<&2, T.Entry<Tag>>, +routes: List<&2, M.Registration(Tag)>, +compiled: M.Index<Tag>, +layers: List<&2, T.Middleware<Tag>>, +count: Nat, +route: Maybe<&2, Nat>, +stage: T.Stage, +built: {T.build(Tag, xs) == Done{T.Table{routes, compiled, layers, count}} : Result<&2, &2, M.BuildError, T.Table<Tag>>}) -> {T.scoped_stage_ids(Tag, layers, route, stage) == S.stage_ids(Tag, xs, route, stage) : List<&2, Tag>}:
  %Equal.sym(List<&2, Tag>, T.stage_ids(Tag, layers, stage), Global.hooks(Tag, xs, stage), Legacy.selection(Tag, xs, routes, compiled, layers, count, stage, built)) : {List.append(&2, Tag, _, T.route_stage_ids(Tag, layers, route, stage)) == S.stage_ids(Tag, xs, route, stage) : List<&2, Tag>}
  Equal.cong(List<&2, Tag>, List<&2, Tag>, ids => List.append(&2, Tag, Global.hooks(Tag, xs, stage), ids), T.route_stage_ids(Tag, layers, route, stage), S.route_hooks(Tag, xs, route, stage), selection(Tag, xs, routes, compiled, layers, count, route, stage, built))

def none_member(-Tag: Data, +xs: List<&2, T.Entry<Tag>>) -> {S.member(Tag, xs, None{}) == False{} : Bool}:
  match xs:
    case Nil{}: {==}
    case T.Route{r} <> tail: none_member(Tag, tail)
    case T.ScopedRoute{r, hooks} <> tail: none_member(Tag, tail)
    case T.Hook{stage, tag} <> tail: none_member(Tag, tail)
    case T.Use{source, tag} <> tail: none_member(Tag, tail)

def or_left_false(+a: Bool, +b: Bool, no: {a || b == False{} : Bool}) -> {a == False{} : Bool}:
  match a:
    case False{}: {==}
    case True{}:
      Core.absurd({True{} == False{} : Bool}, Core.false_true(Equal.sym(Bool, True{}, False{}, no)))

def or_right_false(+a: Bool, +b: Bool, no: {a || b == False{} : Bool}) -> {b == False{} : Bool}:
  match a:
    case False{}: no
    case True{}:
      Core.absurd({b == False{} : Bool}, Core.false_true(Equal.sym(Bool, True{}, False{}, no)))

def nonmember(-Tag: Data, +xs: List<&2, T.Entry<Tag>>, +route: Maybe<&2, Nat>, +stage: T.Stage, +no: {S.member(Tag, xs, route) == False{} : Bool}) -> {S.route_hooks(Tag, xs, route, stage) == [] : List<&2, Tag>}:
  match xs:
    case Nil{}: {==}
    case T.Route{r} <> tail: nonmember(Tag, tail, route, stage, no)
    case T.Hook{kind, tag} <> tail: nonmember(Tag, tail, route, stage, no)
    case T.Use{source, tag} <> tail: nonmember(Tag, tail, route, stage, no)
    case T.ScopedRoute{r, placements} <> tail:
      match route:
        case None{}: nonmember(Tag, tail, None{}, stage, no)
        case Some{n}:
          %Equal.sym(Bool, Nat.is_eq(S.route_count(Tag, tail), n), False{}, or_left_false(Nat.is_eq(S.route_count(Tag, tail), n), S.member(Tag, tail, Some{n}), no)) : {List.append(&2, Tag, S.at(Tag, placements, stage, _), S.route_hooks(Tag, tail, Some{n}, stage)) == [] : List<&2, Tag>}
          nonmember(Tag, tail, Some{n}, stage, or_right_false(Nat.is_eq(S.route_count(Tag, tail), n), S.member(Tag, tail, Some{n}), no))

def append_nil(-Tag: Data, +xs: List<&2, Tag>) -> {List.append(&2, Tag, xs, []) == xs : List<&2, Tag>}:
  match xs:
    case Nil{}: {==}
    case h <> t:
      Equal.cong(List<&2, Tag>, List<&2, Tag>, ys => h <> ys, List.append(&2, Tag, t, []), t, append_nil(Tag, t))

def nonmember_selection(-Tag: Data, +xs: List<&2, T.Entry<Tag>>, +routes: List<&2, M.Registration(Tag)>, +compiled: M.Index<Tag>, +layers: List<&2, T.Middleware<Tag>>, +count: Nat, +route: Maybe<&2, Nat>, +stage: T.Stage, +built: {T.build(Tag, xs) == Done{T.Table{routes, compiled, layers, count}} : Result<&2, &2, M.BuildError, T.Table<Tag>>}, no: {S.member(Tag, xs, route) == False{} : Bool}) -> {T.scoped_stage_ids(Tag, layers, route, stage) == T.stage_ids(Tag, layers, stage) : List<&2, Tag>}:
  %Equal.sym(List<&2, Tag>, T.route_stage_ids(Tag, layers, route, stage), [], Equal.trans(List<&2, Tag>, T.route_stage_ids(Tag, layers, route, stage), S.route_hooks(Tag, xs, route, stage), [], selection(Tag, xs, routes, compiled, layers, count, route, stage, built), nonmember(Tag, xs, route, stage, no))) : {List.append(&2, Tag, T.stage_ids(Tag, layers, stage), _) == T.stage_ids(Tag, layers, stage) : List<&2, Tag>}
  append_nil(Tag, T.stage_ids(Tag, layers, stage))

def lifecycle_selection(-Tag: Data, +entries: List<&2, T.Entry<Tag>>, +routes: List<&2, M.Registration(Tag)>, +compiled: M.Index<Tag>, +layers: List<&2, T.Middleware<Tag>>, +count: Nat, +path: String, +route: Maybe<&2, Nat>, +built: {T.build(Tag, entries) == Done{T.Table{routes, compiled, layers, count}} : Result<&2, &2, M.BuildError, T.Table<Tag>>}) -> {T.scoped_lifecycle(Tag, layers, path, route) == S.lifecycle(Tag, entries, path, route) : T.Lifecycle<Tag>}:
  %Equal.sym(List<&2, Tag>, T.scoped_stage_ids(Tag, layers, route, T.Request{}), S.stage_ids(Tag, entries, route, T.Request{}), stage_selection(Tag, entries, routes, compiled, layers, count, route, T.Request{}, built)) : {T.Lifecycle{_, List.concat(&2, Tag, [T.selected(Tag, layers, path), T.scoped_stage_ids(Tag, layers, route, T.Parse{}), T.scoped_stage_ids(Tag, layers, route, T.Transform{}), T.scoped_stage_ids(Tag, layers, route, T.BeforeHandle{})]), T.scoped_stage_ids(Tag, layers, route, T.AfterHandle{}), T.scoped_stage_ids(Tag, layers, route, T.MapResponse{}), T.scoped_stage_ids(Tag, layers, route, T.Error{}), T.scoped_stage_ids(Tag, layers, route, T.AfterResponse{})} == S.lifecycle(Tag, entries, path, route) : T.Lifecycle<Tag>}
  %Equal.sym(List<&2, Tag>, T.selected(Tag, layers, path), Global.filter(Tag, entries, path), Ordinary.selection(Tag, entries, T.Table{routes, compiled, layers, count}, path, built)) : {T.Lifecycle{S.stage_ids(Tag, entries, route, T.Request{}), List.concat(&2, Tag, [_, T.scoped_stage_ids(Tag, layers, route, T.Parse{}), T.scoped_stage_ids(Tag, layers, route, T.Transform{}), T.scoped_stage_ids(Tag, layers, route, T.BeforeHandle{})]), T.scoped_stage_ids(Tag, layers, route, T.AfterHandle{}), T.scoped_stage_ids(Tag, layers, route, T.MapResponse{}), T.scoped_stage_ids(Tag, layers, route, T.Error{}), T.scoped_stage_ids(Tag, layers, route, T.AfterResponse{})} == S.lifecycle(Tag, entries, path, route) : T.Lifecycle<Tag>}
  %Equal.sym(List<&2, Tag>, T.scoped_stage_ids(Tag, layers, route, T.Parse{}), S.stage_ids(Tag, entries, route, T.Parse{}), stage_selection(Tag, entries, routes, compiled, layers, count, route, T.Parse{}, built)) : {T.Lifecycle{S.stage_ids(Tag, entries, route, T.Request{}), List.concat(&2, Tag, [Global.filter(Tag, entries, path), _, T.scoped_stage_ids(Tag, layers, route, T.Transform{}), T.scoped_stage_ids(Tag, layers, route, T.BeforeHandle{})]), T.scoped_stage_ids(Tag, layers, route, T.AfterHandle{}), T.scoped_stage_ids(Tag, layers, route, T.MapResponse{}), T.scoped_stage_ids(Tag, layers, route, T.Error{}), T.scoped_stage_ids(Tag, layers, route, T.AfterResponse{})} == S.lifecycle(Tag, entries, path, route) : T.Lifecycle<Tag>}
  %Equal.sym(List<&2, Tag>, T.scoped_stage_ids(Tag, layers, route, T.Transform{}), S.stage_ids(Tag, entries, route, T.Transform{}), stage_selection(Tag, entries, routes, compiled, layers, count, route, T.Transform{}, built)) : {T.Lifecycle{S.stage_ids(Tag, entries, route, T.Request{}), List.concat(&2, Tag, [Global.filter(Tag, entries, path), S.stage_ids(Tag, entries, route, T.Parse{}), _, T.scoped_stage_ids(Tag, layers, route, T.BeforeHandle{})]), T.scoped_stage_ids(Tag, layers, route, T.AfterHandle{}), T.scoped_stage_ids(Tag, layers, route, T.MapResponse{}), T.scoped_stage_ids(Tag, layers, route, T.Error{}), T.scoped_stage_ids(Tag, layers, route, T.AfterResponse{})} == S.lifecycle(Tag, entries, path, route) : T.Lifecycle<Tag>}
  %Equal.sym(List<&2, Tag>, T.scoped_stage_ids(Tag, layers, route, T.BeforeHandle{}), S.stage_ids(Tag, entries, route, T.BeforeHandle{}), stage_selection(Tag, entries, routes, compiled, layers, count, route, T.BeforeHandle{}, built)) : {T.Lifecycle{S.stage_ids(Tag, entries, route, T.Request{}), List.concat(&2, Tag, [Global.filter(Tag, entries, path), S.stage_ids(Tag, entries, route, T.Parse{}), S.stage_ids(Tag, entries, route, T.Transform{}), _]), T.scoped_stage_ids(Tag, layers, route, T.AfterHandle{}), T.scoped_stage_ids(Tag, layers, route, T.MapResponse{}), T.scoped_stage_ids(Tag, layers, route, T.Error{}), T.scoped_stage_ids(Tag, layers, route, T.AfterResponse{})} == S.lifecycle(Tag, entries, path, route) : T.Lifecycle<Tag>}
  %Equal.sym(List<&2, Tag>, T.scoped_stage_ids(Tag, layers, route, T.AfterHandle{}), S.stage_ids(Tag, entries, route, T.AfterHandle{}), stage_selection(Tag, entries, routes, compiled, layers, count, route, T.AfterHandle{}, built)) : {T.Lifecycle{S.stage_ids(Tag, entries, route, T.Request{}), List.concat(&2, Tag, [Global.filter(Tag, entries, path), S.stage_ids(Tag, entries, route, T.Parse{}), S.stage_ids(Tag, entries, route, T.Transform{}), S.stage_ids(Tag, entries, route, T.BeforeHandle{})]), _, T.scoped_stage_ids(Tag, layers, route, T.MapResponse{}), T.scoped_stage_ids(Tag, layers, route, T.Error{}), T.scoped_stage_ids(Tag, layers, route, T.AfterResponse{})} == S.lifecycle(Tag, entries, path, route) : T.Lifecycle<Tag>}
  %Equal.sym(List<&2, Tag>, T.scoped_stage_ids(Tag, layers, route, T.MapResponse{}), S.stage_ids(Tag, entries, route, T.MapResponse{}), stage_selection(Tag, entries, routes, compiled, layers, count, route, T.MapResponse{}, built)) : {T.Lifecycle{S.stage_ids(Tag, entries, route, T.Request{}), List.concat(&2, Tag, [Global.filter(Tag, entries, path), S.stage_ids(Tag, entries, route, T.Parse{}), S.stage_ids(Tag, entries, route, T.Transform{}), S.stage_ids(Tag, entries, route, T.BeforeHandle{})]), S.stage_ids(Tag, entries, route, T.AfterHandle{}), _, T.scoped_stage_ids(Tag, layers, route, T.Error{}), T.scoped_stage_ids(Tag, layers, route, T.AfterResponse{})} == S.lifecycle(Tag, entries, path, route) : T.Lifecycle<Tag>}
  %Equal.sym(List<&2, Tag>, T.scoped_stage_ids(Tag, layers, route, T.Error{}), S.stage_ids(Tag, entries, route, T.Error{}), stage_selection(Tag, entries, routes, compiled, layers, count, route, T.Error{}, built)) : {T.Lifecycle{S.stage_ids(Tag, entries, route, T.Request{}), List.concat(&2, Tag, [Global.filter(Tag, entries, path), S.stage_ids(Tag, entries, route, T.Parse{}), S.stage_ids(Tag, entries, route, T.Transform{}), S.stage_ids(Tag, entries, route, T.BeforeHandle{})]), S.stage_ids(Tag, entries, route, T.AfterHandle{}), S.stage_ids(Tag, entries, route, T.MapResponse{}), _, T.scoped_stage_ids(Tag, layers, route, T.AfterResponse{})} == S.lifecycle(Tag, entries, path, route) : T.Lifecycle<Tag>}
  %Equal.sym(List<&2, Tag>, T.scoped_stage_ids(Tag, layers, route, T.AfterResponse{}), S.stage_ids(Tag, entries, route, T.AfterResponse{}), stage_selection(Tag, entries, routes, compiled, layers, count, route, T.AfterResponse{}, built)) : {T.Lifecycle{S.stage_ids(Tag, entries, route, T.Request{}), List.concat(&2, Tag, [Global.filter(Tag, entries, path), S.stage_ids(Tag, entries, route, T.Parse{}), S.stage_ids(Tag, entries, route, T.Transform{}), S.stage_ids(Tag, entries, route, T.BeforeHandle{})]), S.stage_ids(Tag, entries, route, T.AfterHandle{}), S.stage_ids(Tag, entries, route, T.MapResponse{}), S.stage_ids(Tag, entries, route, T.Error{}), _} == S.lifecycle(Tag, entries, path, route) : T.Lifecycle<Tag>}
  {==}


# Successful construction retains exactly the source route count.
def BuiltCount(-Tag: Data, result: Result<&2, &2, M.BuildError, T.Table<Tag>>, count: Nat) -> Type:
  match result:
    case Fail{error}: Unit
    case Done{T.Table{routes, compiled, layers, stored}}: {stored == count : Nat}

def built_count(-Tag: Data, +routes: List<&2, M.Registration(Tag)>, +layers: List<&2, T.Middleware<Tag>>, +result: Result<&2, &2, M.BuildError, M.Valid<Tag>>, +n: Nat, proof: {List.length(&2, M.Registration(Tag), routes) == n : Nat}) -> BuiltCount(Tag, T.built(Tag, routes, layers, result), n):
  match result:
    case Fail{error}: Unit{}
    case Done{table}: proof

def collected_count(-Tag: Data, +routes: List<&2, M.Registration(Tag)>, +result: Result<&2, &2, M.BuildError, List<&2, T.Middleware<Tag>>>, +n: Nat, proof: {List.length(&2, M.Registration(Tag), routes) == n : Nat}) -> BuiltCount(Tag, T.collected(Tag, routes, result), n):
  match result:
    case Fail{error}: Unit{}
    case Done{layers}: built_count(Tag, routes, layers, M.build_table(Tag, routes), n, proof)

def successful_count(-Tag: Data, +xs: List<&2, T.Entry<Tag>>, +routes: List<&2, M.Registration(Tag)>, +compiled: M.Index<Tag>, +layers: List<&2, T.Middleware<Tag>>, +count: Nat, built: {T.build(Tag, xs) == Done{T.Table{routes, compiled, layers, count}} : Result<&2, &2, M.BuildError, T.Table<Tag>>}) -> {count == S.route_count(Tag, xs) : Nat}:
  %built : BuiltCount(Tag, _, S.route_count(Tag, xs))
  collected_count(Tag, T.route_entries(Tag, xs), T.middleware_entries(Tag, xs, 0n), S.route_count(Tag, xs), source_count(Tag, xs))

def resolved_identity(-Tag: Data, +xs: List<&2, T.Entry<Tag>>, +routes: List<&2, M.Registration(Tag)>, +compiled: M.Index<Tag>, +layers: List<&2, T.Middleware<Tag>>, +count: Nat, +resolution: M.Resolution<Tag>, built: {T.build(Tag, xs) == Done{T.Table{routes, compiled, layers, count}} : Result<&2, &2, M.BuildError, T.Table<Tag>>}) -> {Slot.identity(Tag, count, resolution) == S.resolved_route(Tag, xs, resolution) : Maybe<&2, Nat>}:
  match resolution:
    case M.Found{RouterSpec.Match{index, tag, params}, head}:
      Equal.cong(Nat, Maybe<&2, Nat>, n => Some{Nat.sub(Nat.sub(n, 1n), index)}, count, S.route_count(Tag, xs), successful_count(Tag, xs, routes, compiled, layers, count, built))
    case M.NotFound{}: {==}
    case M.MethodNotAllowed{allow}: {==}

def resolved_selection(-Tag: Data, +xs: List<&2, T.Entry<Tag>>, +routes: List<&2, M.Registration(Tag)>, +compiled: M.Index<Tag>, +layers: List<&2, T.Middleware<Tag>>, +count: Nat, +kind: Router.RouterKind, +path: String, +method: Request.Method, +opts: M.Options, +stage: T.Stage, +built: {T.build(Tag, xs) == Done{T.Table{routes, compiled, layers, count}} : Result<&2, &2, M.BuildError, T.Table<Tag>>}) -> {T.scoped_stage_ids(Tag, layers, Slot.identity(Tag, count, M.resolve_with(Tag, kind, compiled, path, method, opts)), stage) == S.stage_ids(Tag, xs, S.resolved_route(Tag, xs, M.resolve_with(Tag, kind, compiled, path, method, opts)), stage) : List<&2, Tag>}:
  %Equal.sym(Maybe<&2, Nat>, Slot.identity(Tag, count, M.resolve_with(Tag, kind, compiled, path, method, opts)), S.resolved_route(Tag, xs, M.resolve_with(Tag, kind, compiled, path, method, opts)), resolved_identity(Tag, xs, routes, compiled, layers, count, M.resolve_with(Tag, kind, compiled, path, method, opts), built)) : {T.scoped_stage_ids(Tag, layers, _, stage) == S.stage_ids(Tag, xs, S.resolved_route(Tag, xs, M.resolve_with(Tag, kind, compiled, path, method, opts)), stage) : List<&2, Tag>}
  stage_selection(Tag, xs, routes, compiled, layers, count, S.resolved_route(Tag, xs, M.resolve_with(Tag, kind, compiled, path, method, opts)), stage, built)
