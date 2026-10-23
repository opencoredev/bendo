# Assembly contract over source entries. Only data constructors and Base are
# shared with runtime assembly; no Scopes or Table assembly helper is used.
import Base
import ../src/app/table.bend as T
import ../src/router/methods.bend as M
import ../src/router/spec.bend as R

# Extract every direct declaration in source order, including duplicates.
def declarations(-Tag: Data, entries: List<&2, T.Entry<Tag>>) -> List<&2, T.HookSpec<Tag>>:
  match entries:
    case Nil{}: []
    case T.Hook{stage, tag} <> tail: T.HookSpec{stage, tag} <> declarations(Tag, tail)
    case _ <> tail: declarations(Tag, tail)

def located(-Tag: Data, hooks: List<&2, T.HookSpec<Tag>>, +scope: T.Scope) -> List<&2, T.Placement<Tag>>:
  match hooks:
    case Nil{}: []
    case hook <> tail: T.Placement{scope, hook} <> located(Tag, tail, scope)

# Remove exactly one terminal slash from a nonidentity prefix. Validation of
# malformed composed paths belongs to table building, not assembly.
def trim_terminal(+prefix: String, slash: Bool) -> String:
  match slash:
    case True{}: String.take(prefix, Nat.sub(String.length(prefix), 1n))
    case False{}: prefix

def path(+prefix: String, source: String) -> String:
  match prefix:
    case "": source
    case "/": source
    case _: trim_terminal(prefix, String.ends_with(prefix, "/")) ++ source

def registration(-Tag: Data, prefix: String, route: M.Registration(Tag)) -> M.Registration(Tag):
  R.Registration{source, tag} = route
  R.Registration{path(prefix, source), tag}

# Stable route mapping/filter: declarations become placements, Use entries stay
# untouched, and each route retains its tag, position and existing placements.
def assemble(-Tag: Data, entries: List<&2, T.Entry<Tag>>, +prefix: String, +inherited: List<&2, T.Placement<Tag>>) -> List<&2, T.Entry<Tag>>:
  match entries:
    case Nil{}: []
    case T.Route{r} <> tail:
      T.ScopedRoute{registration(Tag, prefix, r), inherited} <> assemble(Tag, tail, prefix, inherited)
    case T.ScopedRoute{r, local} <> tail:
      T.ScopedRoute{registration(Tag, prefix, r), List.append(&2, T.Placement<Tag>, inherited, local)} <> assemble(Tag, tail, prefix, inherited)
    case T.Hook{stage, tag} <> tail: assemble(Tag, tail, prefix, inherited)
    case T.Use{source, tag} <> tail: T.Use{source, tag} <> assemble(Tag, tail, prefix, inherited)

def guard(-Tag: Data, options: T.GuardOptions<Tag>, +entries: List<&2, T.Entry<Tag>>) -> List<&2, T.Entry<Tag>>:
  T.GuardOptions{explicit, schemas} = options
  assemble(Tag, entries, "", located(Tag, List.append(&2, T.HookSpec<Tag>, explicit, declarations(Tag, entries)), T.GuardScope{}))

def group(-Tag: Data, +prefix: String, explicit: List<&2, T.HookSpec<Tag>>, +entries: List<&2, T.Entry<Tag>>) -> List<&2, T.Entry<Tag>>:
  assemble(Tag, entries, prefix, located(Tag, List.append(&2, T.HookSpec<Tag>, explicit, declarations(Tag, entries)), T.GroupScope{prefix}))

def local(-Tag: Data, route: M.Registration(Tag), hooks: List<&2, T.HookSpec<Tag>>) -> T.Entry<Tag>:
  T.ScopedRoute{route, located(Tag, hooks, T.RouteScope{})}
