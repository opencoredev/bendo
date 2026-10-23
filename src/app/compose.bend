# Composition lowers through the same route-attached group mechanism as hooks.
import Base
import ./table.bend as T
import ./scopes.bend as S
import ../router/methods.bend as M
import ../router/spec.bend as R

def canonical(source: String) -> String:
  match source:
    case "*": "/*"
    case _: source

def registration(-Tag: Data, entry: M.Registration(Tag)) -> M.Registration(Tag):
  R.Registration{source, binding} = entry
  R.Registration{canonical(source), binding}

def middleware(-Tag: Data, source: Maybe<&2, String>, tag: Tag, mount: Bool) -> T.Entry<Tag>:
  match source mount:
    case None{} True{}: T.PrefixedUse{"/*", tag}
    case Some{path} True{}: T.PrefixedUse{canonical(path), tag}
    case _ False{}: T.Use{source, tag}

# Normalizing the bare wildcard before joining preserves the segment boundary.
# A mount owns its ordinary middleware paths; outer groups keep moving them.
def prepare(-Tag: Data, entries: List<&2, T.Entry<Tag>>, +mount: Bool) -> List<&2, T.Entry<Tag>>:
  match entries:
    case Nil{}: []
    case T.Route{r} <> tail: T.Route{registration(Tag, r)} <> prepare(Tag, tail, mount)
    case T.ScopedRoute{r, hooks} <> tail: T.ScopedRoute{registration(Tag, r), hooks} <> prepare(Tag, tail, mount)
    case T.Hook{stage, tag} <> tail: T.Hook{stage, tag} <> prepare(Tag, tail, mount)
    case T.PrefixedUse{source, tag} <> tail: T.PrefixedUse{source, tag} <> prepare(Tag, tail, mount)
    case T.Use{source, tag} <> tail: middleware(Tag, source, tag, mount) <> prepare(Tag, tail, mount)

def group(-Tag: Data, prefix: String, hooks: List<&2, T.HookSpec<Tag>>, entries: List<&2, T.Entry<Tag>>) -> List<&2, T.Entry<Tag>>:
  S.group(Tag, prefix, hooks, prepare(Tag, entries, False{}))

def mount(-Tag: Data, prefix: String, entries: List<&2, T.Entry<Tag>>) -> List<&2, T.Entry<Tag>>:
  S.group(Tag, prefix, [], prepare(Tag, entries, True{}))
