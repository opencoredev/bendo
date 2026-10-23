# Independent source normalization and assembly; no Compose/Scopes helpers.
import Base
import ../src/app/table.bend as T
import ../src/router/methods.bend as M
import ../src/router/spec.bend as R
import ../src/router/router.bend as Router
import ../src/router/pattern.bend as P
import ../src/http/request.bend as H
import ./scoped-assembly-spec.bend as AssemblySpec

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

def prepare(-Tag: Data, entries: List<&2, T.Entry<Tag>>, +mount: Bool) -> List<&2, T.Entry<Tag>>:
  match entries:
    case Nil{}: []
    case T.Route{r} <> tail: T.Route{registration(Tag, r)} <> prepare(Tag, tail, mount)
    case T.ScopedRoute{r, hooks} <> tail: T.ScopedRoute{registration(Tag, r), hooks} <> prepare(Tag, tail, mount)
    case T.Hook{stage, tag} <> tail: T.Hook{stage, tag} <> prepare(Tag, tail, mount)
    case T.PrefixedUse{source, tag} <> tail: T.PrefixedUse{source, tag} <> prepare(Tag, tail, mount)
    case T.Use{source, tag} <> tail: middleware(Tag, source, tag, mount) <> prepare(Tag, tail, mount)

def group(-Tag: Data, prefix: String, hooks: List<&2, T.HookSpec<Tag>>, entries: List<&2, T.Entry<Tag>>) -> List<&2, T.Entry<Tag>>:
  AssemblySpec.group(Tag, prefix, hooks, prepare(Tag, entries, False{}))

def mount(-Tag: Data, prefix: String, entries: List<&2, T.Entry<Tag>>) -> List<&2, T.Entry<Tag>>:
  AssemblySpec.group(Tag, prefix, [], prepare(Tag, entries, True{}))

# Observe build failures as well as complete method resolution. Shared building
# validates patterns/methods; the reference always uses the linear router.
def routed(-Tag: Data, kind: Router.RouterKind, result: Result<&2, &2, M.BuildError, T.Table<Tag>>, path: String, method: H.Method, opts: M.Options) -> Result<&2, &2, M.BuildError, M.Resolution<Tag>>:
  match result:
    case Fail{error}: Fail{error}
    case Done{T.Table{entries, index, layers, count}}:
      Done{M.resolve_with(Tag, kind, index, path, method, opts)}

def reference(-Tag: Data, result: Result<&2, &2, M.BuildError, T.Table<Tag>>, path: String, method: H.Method, opts: M.Options) -> Result<&2, &2, M.BuildError, M.Resolution<Tag>>:
  match result:
    case Fail{error}: Fail{error}
    case Done{T.Table{entries, index, layers, count}}:
      Done{M.resolve(Tag, M.index_valid(Tag, index), path, method, opts)}

def mount_routing(-Tag: Data, prefix: String, entries: List<&2, T.Entry<Tag>>, path: String, method: H.Method, opts: M.Options) -> Result<&2, &2, M.BuildError, M.Resolution<Tag>>:
  reference(Tag, T.build(Tag, mount(Tag, prefix, entries)), path, method, opts)

# A sequence of literal path segments, with no interpretation as captures.
def literals(prefix: List<&2, String>) -> List<&2, P.Segment>:
  match prefix:
    case Nil{}: []
    case head <> tail: P.Static{head} <> literals(tail)
