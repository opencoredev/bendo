# Pure assembly: scopes decorate routes before table validation and indexing.
import Base
import ./table.bend as T
import ../router/spec.bend as S
import ../router/methods.bend as M
import ./validate.bend as V

def placements(-Tag: Data, hooks: List<&2, T.HookSpec<Tag>>, +scope: T.Scope) -> List<&2, T.Placement<Tag>>:
  match hooks:
    case Nil{}: []
    case hook <> tail: T.Placement{scope, hook} <> placements(Tag, tail, scope)

def attach(-Tag: Data, entries: List<&2, T.Entry<Tag>>, +hooks: List<&2, T.Placement<Tag>>) -> List<&2, T.Entry<Tag>>:
  match entries:
    case Nil{}: []
    case T.Route{r} <> tail: T.ScopedRoute{r, hooks} <> attach(Tag, tail, hooks)
    case T.ScopedRoute{r, old} <> tail: T.ScopedRoute{r, List.append(&2, T.Placement<Tag>, hooks, old)} <> attach(Tag, tail, hooks)
    case T.Hook{stage, tag} <> tail: attach(Tag, tail, hooks)
    case entry <> tail: entry <> attach(Tag, tail, hooks)

def declared(-Tag: Data, entries: List<&2, T.Entry<Tag>>) -> List<&2, T.HookSpec<Tag>>:
  match entries:
    case Nil{}: []
    case T.Hook{stage, tag} <> tail: T.HookSpec{stage, tag} <> declared(Tag, tail)
    case _ <> tail: declared(Tag, tail)

# A guard's schemas follow its hooks, so a member route's own schemas, placed
# after them, win slot by slot (BND-36).
def checks(-Tag: Data, slot: T.SchemaSlot, +scope: T.Scope) -> List<&2, T.Placement<Tag>>:
  match slot:
    case T.NoSchemas{}: []
    case T.WithSchemas{schemas}: [T.Checks{scope, schemas}]

def guard(-Tag: Data, options: T.GuardOptions<Tag>, +entries: List<&2, T.Entry<Tag>>) -> List<&2, T.Entry<Tag>>:
  T.GuardOptions{hooks, schemas} = options
  attach(Tag, entries, List.append(&2, T.Placement<Tag>, placements(Tag, List.append(&2, T.HookSpec<Tag>, hooks, declared(Tag, entries)), T.GuardScope{}), checks(Tag, schemas, T.GuardScope{})))

# Prefixes are pattern sources starting with / (or empty). Table building
# validates composed paths. Empty and / are the identity. A trailing /
# on a non-root prefix is removed to avoid a double slash.
def normalized_prefix(+prefix: String, trailing: Bool) -> String:
  match trailing:
    case True{}: String.take(prefix, Nat.sub(String.length(prefix), 1n))
    case False{}: prefix

def prefix_path(+prefix: String, path: String) -> String:
  match prefix:
    case "": path
    case "/": path
    case _: normalized_prefix(prefix, String.ends_with(prefix, "/")) ++ path

def prefixed(-Tag: Data, prefix: String, registration: M.Registration(Tag)) -> M.Registration(Tag):
  S.Registration{source, tag} = registration
  S.Registration{prefix_path(prefix, source), tag}

def prefix_entries(-Tag: Data, entries: List<&2, T.Entry<Tag>>, +prefix: String) -> List<&2, T.Entry<Tag>>:
  match entries:
    case Nil{}: []
    case T.Route{r} <> tail: T.Route{prefixed(Tag, prefix, r)} <> prefix_entries(Tag, tail, prefix)
    case T.ScopedRoute{r, hooks} <> tail: T.ScopedRoute{prefixed(Tag, prefix, r), hooks} <> prefix_entries(Tag, tail, prefix)
    case T.Hook{stage, tag} <> tail: T.Hook{stage, tag} <> prefix_entries(Tag, tail, prefix)
    case T.Use{source, tag} <> tail: T.Use{source, tag} <> prefix_entries(Tag, tail, prefix)
    case T.PrefixedUse{source, tag} <> tail: T.PrefixedUse{prefix_path(prefix, source), tag} <> prefix_entries(Tag, tail, prefix)

def group(-Tag: Data, +prefix: String, hooks: List<&2, T.HookSpec<Tag>>, +entries: List<&2, T.Entry<Tag>>) -> List<&2, T.Entry<Tag>>:
  attach(Tag, prefix_entries(Tag, entries, prefix), placements(Tag, List.append(&2, T.HookSpec<Tag>, hooks, declared(Tag, entries)), T.GroupScope{prefix}))

# Pure public lowering for one route; kept here so laws avoid importing IO APIs.
def local(-Tag: Data, registration: M.Registration(Tag), hooks: List<&2, T.HookSpec<Tag>>) -> T.Entry<Tag>:
  T.ScopedRoute{registration, placements(Tag, hooks, T.RouteScope{})}

# Attach schemas to one registered route, after any hooks it already has.
def with_schemas(-Tag: Data, entry: T.Entry<Tag>, schemas: V.Schemas) -> T.Entry<Tag>:
  match entry:
    case T.Route{r}: T.ScopedRoute{r, [T.Checks{T.RouteScope{}, schemas}]}
    case T.ScopedRoute{r, hooks}: T.ScopedRoute{r, List.append(&2, T.Placement<Tag>, hooks, [T.Checks{T.RouteScope{}, schemas}])}
    case other: other

# One route with its own hooks and schemas (BND-36).
def validated(-Tag: Data, registration: M.Registration(Tag), hooks: List<&2, T.HookSpec<Tag>>, schemas: V.Schemas) -> T.Entry<Tag>:
  T.ScopedRoute{registration, List.append(&2, T.Placement<Tag>, placements(Tag, hooks, T.RouteScope{}), [T.Checks{T.RouteScope{}, schemas}])}
