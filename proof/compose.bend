import Base
import ./compose-laws.bend as L
import ./compose-spec.bend as S
import ./scoped-assembly-spec.bend as AssemblySpec
import ./scoped-assembly.bend as Assembly
import ../src/app/compose.bend as C
import ../src/app/table.bend as T
import ../src/router/spec.bend as R
import ../src/router/methods.bend as M
import ../src/router/router.bend as Router
import ../src/router/pattern.bend as P
import ../src/router/encoding.bend as E
import ../src/router/equality-proofs.bend as Eq
import ../src/router/methods-trie-proofs.bend as Routing
import ../src/http/request.bend as H

def canonical(+source: String) -> {C.canonical(source) == S.canonical(source) : String}:
  match source:
    case SNil{}: {==}
    case SCon{Chr{U32{bits}}, tail}:
      match bits:
        case WCon{True{}, rest}: {==}
        case WCon{False{}, WCon{False{}, rest}}: {==}
        case WCon{False{}, WCon{True{}, WCon{True{}, rest}}}: {==}
        case WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, rest}}}}: {==}
        case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, rest}}}}}: {==}
        case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, rest}}}}}}: {==}
        case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, rest}}}}}}}: {==}
        case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, rest}}}}}}}}: {==}
        case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}: {==}
        case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}: {==}
        case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}: {==}
        case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}: {==}
        case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}: {==}
        case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}: {==}
        case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}: {==}
        case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}: {==}
        case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}: {==}
        case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}: {==}
        case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}: {==}
        case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}}: {==}
        case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}}}: {==}
        case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}}}}: {==}
        case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}}}}}: {==}
        case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}}}}}}: {==}
        case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
        case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
        case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
        case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
        case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
        case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
        case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
        case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}: {==}
        case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
          match tail:
            case SNil{}: {==}
            case SCon{h, t}: {==}

def registration(-Tag: Data, +r: M.Registration(Tag)) -> {C.registration(Tag, r) == S.registration(Tag, r) : M.Registration(Tag)}:
  R.Registration{source, binding} = r
  Equal.cong(String, M.Registration(Tag), path => R.Registration{path, binding}, C.canonical(source), S.canonical(source), canonical(source))

def middleware(-Tag: Data, +source: Maybe<&2, String>, +tag: Tag, +mount: Bool) -> {C.middleware(Tag, source, tag, mount) == S.middleware(Tag, source, tag, mount) : T.Entry<Tag>}:
  match source mount:
    case None{} True{}: {==}
    case Some{path} True{}: Equal.cong(String, T.Entry<Tag>, p => T.PrefixedUse{p, tag}, C.canonical(path), S.canonical(path), canonical(path))
    case None{} False{}: {==}
    case Some{path} False{}: {==}

def L.compose_prepare(Tag, entries, mount):
  match entries:
    case Nil{}: {==}
    case T.Route{r} <> tail:
      %Equal.sym(M.Registration(Tag), C.registration(Tag, r), S.registration(Tag, r), registration(Tag, r)) : {T.Route{_} <> C.prepare(Tag, tail, mount) == S.prepare(Tag, T.Route{r} <> tail, mount) : List<&2, T.Entry<Tag>>}
      Equal.cong(List<&2, T.Entry<Tag>>, List<&2, T.Entry<Tag>>, rest => T.Route{S.registration(Tag, r)} <> rest, C.prepare(Tag, tail, mount), S.prepare(Tag, tail, mount), L.compose_prepare(Tag, tail, mount))
    case T.ScopedRoute{r, hooks} <> tail:
      %Equal.sym(M.Registration(Tag), C.registration(Tag, r), S.registration(Tag, r), registration(Tag, r)) : {T.ScopedRoute{_, hooks} <> C.prepare(Tag, tail, mount) == S.prepare(Tag, T.ScopedRoute{r, hooks} <> tail, mount) : List<&2, T.Entry<Tag>>}
      Equal.cong(List<&2, T.Entry<Tag>>, List<&2, T.Entry<Tag>>, rest => T.ScopedRoute{S.registration(Tag, r), hooks} <> rest, C.prepare(Tag, tail, mount), S.prepare(Tag, tail, mount), L.compose_prepare(Tag, tail, mount))
    case T.Hook{stage, tag} <> tail:
      Equal.cong(List<&2, T.Entry<Tag>>, List<&2, T.Entry<Tag>>, rest => T.Hook{stage, tag} <> rest, C.prepare(Tag, tail, mount), S.prepare(Tag, tail, mount), L.compose_prepare(Tag, tail, mount))
    case T.PrefixedUse{source, tag} <> tail:
      Equal.cong(List<&2, T.Entry<Tag>>, List<&2, T.Entry<Tag>>, rest => T.PrefixedUse{source, tag} <> rest, C.prepare(Tag, tail, mount), S.prepare(Tag, tail, mount), L.compose_prepare(Tag, tail, mount))
    case T.Use{source, tag} <> tail:
      Equal.trans(List<&2, T.Entry<Tag>>, C.middleware(Tag, source, tag, mount) <> C.prepare(Tag, tail, mount), C.middleware(Tag, source, tag, mount) <> S.prepare(Tag, tail, mount), S.middleware(Tag, source, tag, mount) <> S.prepare(Tag, tail, mount), Equal.cong(List<&2, T.Entry<Tag>>, List<&2, T.Entry<Tag>>, rest => C.middleware(Tag, source, tag, mount) <> rest, C.prepare(Tag, tail, mount), S.prepare(Tag, tail, mount), L.compose_prepare(Tag, tail, mount)), Equal.cong(T.Entry<Tag>, List<&2, T.Entry<Tag>>, head => head <> S.prepare(Tag, tail, mount), C.middleware(Tag, source, tag, mount), S.middleware(Tag, source, tag, mount), middleware(Tag, source, tag, mount)))

def L.compose_group(Tag, prefix, hooks, entries):
  Equal.trans(List<&2, T.Entry<Tag>>, C.group(Tag, prefix, hooks, entries), AssemblySpec.group(Tag, prefix, hooks, C.prepare(Tag, entries, False{})), S.group(Tag, prefix, hooks, entries), Assembly.group(Tag, prefix, hooks, C.prepare(Tag, entries, False{})), Equal.cong(List<&2, T.Entry<Tag>>, List<&2, T.Entry<Tag>>, xs => AssemblySpec.group(Tag, prefix, hooks, xs), C.prepare(Tag, entries, False{}), S.prepare(Tag, entries, False{}), L.compose_prepare(Tag, entries, False{})))

def L.compose_mount(Tag, prefix, entries):
  Equal.trans(List<&2, T.Entry<Tag>>, C.mount(Tag, prefix, entries), AssemblySpec.group(Tag, prefix, [], C.prepare(Tag, entries, True{})), S.mount(Tag, prefix, entries), Assembly.group(Tag, prefix, [], C.prepare(Tag, entries, True{})), Equal.cong(List<&2, T.Entry<Tag>>, List<&2, T.Entry<Tag>>, xs => AssemblySpec.group(Tag, prefix, [], xs), C.prepare(Tag, entries, True{}), S.prepare(Tag, entries, True{}), L.compose_prepare(Tag, entries, True{})))

# Only indexes produced by the builder have the required trie invariant.
def built_routing(-Tag: Data, +entries: List<&2, M.Registration(Tag)>, +layers: List<&2, T.Middleware<Tag>>, +valid: Result<&2, &2, M.BuildError, M.Valid<Tag>>, +kind: Router.RouterKind, +path: String, +method: H.Method, +opts: M.Options) -> {S.routed(Tag, kind, T.built(Tag, entries, layers, valid), path, method, opts) == S.reference(Tag, T.built(Tag, entries, layers, valid), path, method, opts) : Result<&2, &2, M.BuildError, M.Resolution<Tag>>}:
  match valid:
    case Fail{error}: {==}
    case Done{v}:
      Equal.cong(M.Resolution<Tag>, Result<&2, &2, M.BuildError, M.Resolution<Tag>>, resolution => Done{resolution}, M.resolve_with(Tag, kind, M.prepare(Tag, v), path, method, opts), M.resolve(Tag, v, path, method, opts), Routing.resolve_equal(Tag, kind, v, path, method, opts))

def collected_routing(-Tag: Data, +entries: List<&2, M.Registration(Tag)>, +layers: Result<&2, &2, M.BuildError, List<&2, T.Middleware<Tag>>>, +kind: Router.RouterKind, +path: String, +method: H.Method, +opts: M.Options) -> {S.routed(Tag, kind, T.collected(Tag, entries, layers), path, method, opts) == S.reference(Tag, T.collected(Tag, entries, layers), path, method, opts) : Result<&2, &2, M.BuildError, M.Resolution<Tag>>}:
  match layers:
    case Fail{error}: {==}
    case Done{xs}: built_routing(Tag, entries, xs, M.build_table(Tag, entries), kind, path, method, opts)

def L.compose_mount_routing(Tag, prefix, entries, kind, path, method, opts):
  Equal.trans(Result<&2, &2, M.BuildError, M.Resolution<Tag>>, S.routed(Tag, kind, T.build(Tag, C.mount(Tag, prefix, entries)), path, method, opts), S.reference(Tag, T.build(Tag, C.mount(Tag, prefix, entries)), path, method, opts), S.mount_routing(Tag, prefix, entries, path, method, opts), collected_routing(Tag, T.route_entries(Tag, C.mount(Tag, prefix, entries)), T.middleware_entries(Tag, C.mount(Tag, prefix, entries), 0n), kind, path, method, opts), Equal.cong(List<&2, T.Entry<Tag>>, Result<&2, &2, M.BuildError, M.Resolution<Tag>>, xs => S.reference(Tag, T.build(Tag, xs), path, method, opts), C.mount(Tag, prefix, entries), S.mount(Tag, prefix, entries), L.compose_mount(Tag, prefix, entries)))

def L.compose_literal_segments_suffix(prefix, segments, paths):
  match prefix:
    case Nil{}: {==}
    case head <> tail:
      %Equal.sym(Bool, String.eq(head, head), True{}, Eq.string_eq_refl(head)) : {E.choose(Maybe<&2, P.Params>, _, u => P.match_segments(List.append(&2, P.Segment, S.literals(tail), segments), List.append(&2, String, tail, paths)), u => None{}) == P.match_segments(segments, paths) : Maybe<&2, P.Params>}
      L.compose_literal_segments_suffix(tail, segments, paths)

# Fused prefix mapping avoids relying on the runtime composition operation.
def literal_join(+outer: List<&2, String>, +inner: List<&2, String>, +segments: List<&2, P.Segment>) -> {List.append(&2, P.Segment, S.literals(outer), List.append(&2, P.Segment, S.literals(inner), segments)) == List.append(&2, P.Segment, S.literals(List.append(&2, String, outer, inner)), segments) : List<&2, P.Segment>}:
  match outer:
    case Nil{}: {==}
    case head <> tail:
      Equal.cong(List<&2, P.Segment>, List<&2, P.Segment>, rest => P.Static{head} <> rest, List.append(&2, P.Segment, S.literals(tail), List.append(&2, P.Segment, S.literals(inner), segments)), List.append(&2, P.Segment, S.literals(List.append(&2, String, tail, inner)), segments), literal_join(tail, inner, segments))

def L.compose_literal_groups_associate(outer, inner, segments, paths):
  Equal.cong(List<&2, P.Segment>, Maybe<&2, P.Params>, pattern => P.match_segments(pattern, paths), List.append(&2, P.Segment, S.literals(outer), List.append(&2, P.Segment, S.literals(inner), segments)), List.append(&2, P.Segment, S.literals(List.append(&2, String, outer, inner)), segments), literal_join(outer, inner, segments))

def L.compose_literal_boundary_miss(expected, actual, segments, paths, different):
  %Equal.sym(Bool, String.eq(expected, actual), False{}, different) : {E.choose(Maybe<&2, P.Params>, _, u => P.match_segments(segments, paths), u => None{}) == None{} : Maybe<&2, P.Params>}
  {==}
