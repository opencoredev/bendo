import Base
import ../src/app/compose.bend as C
import ../src/app/table.bend as T
import ../src/router/methods.bend as M
import ../src/router/router.bend as Router
import ../src/router/pattern.bend as P
import ../src/http/request.bend as H
import ./compose-spec.bend as S

law compose_prepare:
  for -Tag: Data
  for +entries: List<&2, T.Entry<Tag>>
  for +mount: Bool
  {C.prepare(Tag, entries, mount) == S.prepare(Tag, entries, mount) : List<&2, T.Entry<Tag>>}

law compose_group:
  for -Tag: Data
  for +prefix: String
  for +hooks: List<&2, T.HookSpec<Tag>>
  for +entries: List<&2, T.Entry<Tag>>
  {C.group(Tag, prefix, hooks, entries) == S.group(Tag, prefix, hooks, entries) : List<&2, T.Entry<Tag>>}

law compose_mount:
  for -Tag: Data
  for +prefix: String
  for +entries: List<&2, T.Entry<Tag>>
  {C.mount(Tag, prefix, entries) == S.mount(Tag, prefix, entries) : List<&2, T.Entry<Tag>>}

# Universal routing against an independently prefixed source assembly.
# This is not a theorem relating a mounted request to an unmounted suffix.
law compose_mount_routing:
  for -Tag: Data
  for +prefix: String
  for +entries: List<&2, T.Entry<Tag>>
  for +kind: Router.RouterKind
  for +path: String
  for +method: H.Method
  for +opts: M.Options
  {S.routed(Tag, kind, T.build(Tag, C.mount(Tag, prefix, entries)), path, method, opts) == S.mount_routing(Tag, prefix, entries, path, method, opts) : Result<&2, &2, M.BuildError, M.Resolution<Tag>>}

# Genuine suffix cancellation at segment boundaries. Lifting this to source
# strings still requires compiler/split lemmas; it is not the public theorem.
law compose_literal_segments_suffix:
  for +prefix: List<&2, String>
  for +segments: List<&2, P.Segment>
  for +paths: List<&2, String>
  {P.match_segments(List.append(&2, P.Segment, S.literals(prefix), segments), List.append(&2, String, prefix, paths)) == P.match_segments(segments, paths) : Maybe<&2, P.Params>}

# Rebracketing literal prefix groups preserves all match results and captures.
# This is stated on compiled segments; source-string normalization is separate.
law compose_literal_groups_associate:
  for +outer: List<&2, String>
  for +inner: List<&2, String>
  for +segments: List<&2, P.Segment>
  for +paths: List<&2, String>
  {P.match_segments(List.append(&2, P.Segment, S.literals(outer), List.append(&2, P.Segment, S.literals(inner), segments)), paths) == P.match_segments(List.append(&2, P.Segment, S.literals(List.append(&2, String, outer, inner)), segments), paths) : Maybe<&2, P.Params>}

# Different whole segments miss, even when one string prefixes the other.
law compose_literal_boundary_miss:
  for +expected: String
  for +actual: String
  for +segments: List<&2, P.Segment>
  for +paths: List<&2, String>
  for different: {String.eq(expected, actual) == False{} : Bool}
  {P.match_segments(P.Static{expected} <> segments, actual <> paths) == None{} : Maybe<&2, P.Params>}
