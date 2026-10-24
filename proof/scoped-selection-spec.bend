import Base
import ../src/app/table.bend as T
import ./middleware-selection-spec.bend as Global
import ../src/router/methods.bend as M
import ../src/router/spec.bend as RouterSpec

# Independent count of route registrations in SOURCE entries. A scoped route's
# identity is the number of routes after it; middleware never changes identity.
def route_count(-Tag: Data, xs: List<&2, T.Entry<Tag>>) -> Nat:
  match xs:
    case Nil{}: 0n
    case T.Route{r} <> tail: 1n+route_count(Tag, tail)
    case T.ScopedRoute{r, hooks} <> tail: 1n+route_count(Tag, tail)
    case _ <> tail: route_count(Tag, tail)

# The placement list is structural outer-to-inner order: inherited group/guard
# hooks precede local hooks. No prefix or path predicate grants membership.
def hooks(-Tag: Data, xs: List<&2, T.Placement<Tag>>, +stage: T.Stage) -> List<&2, Tag>:
  match xs:
    case Nil{}: []
    case T.Placement{scope, T.HookSpec{kind, tag}} <> tail:
      Global.keep(Tag, tag, hooks(Tag, tail, stage), Global.same_stage(kind, stage))
    case T.Checks{scope, schemas} <> tail: hooks(Tag, tail, stage)

def at(-Tag: Data, placements: List<&2, T.Placement<Tag>>, stage: T.Stage, yes: Bool) -> List<&2, Tag>:
  match yes:
    case True{}: hooks(Tag, placements, stage)
    case False{}: []

def route_hooks(-Tag: Data, xs: List<&2, T.Entry<Tag>>, +route: Maybe<&2, Nat>, +stage: T.Stage) -> List<&2, Tag>:
  match xs:
    case Nil{}: []
    case T.ScopedRoute{registration, placements} <> +tail:
      match route:
        case None{}: route_hooks(Tag, tail, None{}, stage)
        case Some{n}:
          List.append(&2, Tag, at(Tag, placements, stage, Nat.is_eq(route_count(Tag, tail), n)), route_hooks(Tag, tail, Some{n}, stage))
    case _ <> tail: route_hooks(Tag, tail, route, stage)

# Global hooks always come first in registration order. Scoped hooks follow in
# structural nesting order, regardless of where global hooks were registered.
def stage_ids(-Tag: Data, +xs: List<&2, T.Entry<Tag>>, route: Maybe<&2, Nat>, +stage: T.Stage) -> List<&2, Tag>:
  List.append(&2, Tag, Global.hooks(Tag, xs, stage), route_hooks(Tag, xs, route, stage))

def lifecycle(-Tag: Data, +xs: List<&2, T.Entry<Tag>>, path: String, +route: Maybe<&2, Nat>) -> T.Lifecycle<Tag>:
  T.Lifecycle{
    stage_ids(Tag, xs, route, T.Request{}),
    List.concat(&2, Tag, [Global.filter(Tag, xs, path), stage_ids(Tag, xs, route, T.Parse{}), stage_ids(Tag, xs, route, T.Transform{}), stage_ids(Tag, xs, route, T.BeforeHandle{})]),
    stage_ids(Tag, xs, route, T.AfterHandle{}),
    stage_ids(Tag, xs, route, T.MapResponse{}),
    stage_ids(Tag, xs, route, T.Error{}),
    stage_ids(Tag, xs, route, T.AfterResponse{})}

# A membership test over source structure, with no path approximation. A plain
# Route is absent even when its path equals a scoped route's path.
def member(-Tag: Data, xs: List<&2, T.Entry<Tag>>, +route: Maybe<&2, Nat>) -> Bool:
  match xs:
    case Nil{}: False{}
    case T.ScopedRoute{r, placements} <> +tail:
      match route:
        case None{}: member(Tag, tail, None{})
        case Some{n}: Nat.is_eq(route_count(Tag, tail), n) || member(Tag, tail, Some{n})
    case _ <> tail: member(Tag, tail, route)

# Interpret a router result using the independent source count. The established
# method/router laws cover path matching, method priority and HEAD fallback.
def resolved_route(-Tag: Data, xs: List<&2, T.Entry<Tag>>, resolution: M.Resolution<Tag>) -> Maybe<&2, Nat>:
  match resolution:
    case M.Found{RouterSpec.Match{index, tag, params}, head}: Some{Nat.sub(Nat.sub(route_count(Tag, xs), 1n), index)}
    case _: None{}
