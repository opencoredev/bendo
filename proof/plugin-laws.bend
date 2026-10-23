import Base
import ../src/app/plugin.bend as P
import ../src/app/table.bend as T
import ./plugin-spec.bend as S

# BND-26: every plugin use sequence, from any starting app, equals its
# independent first-use assembly. Equality covers the applied identities and
# every entry: order, duplicates, prefixes and hook provenance. Programs nest
# named, anonymous and scoped plugins to any depth.
law plugin_first_use_assembly:
  for -Tag: Data
  for +steps: List<&2, S.Step<Tag>>
  for +ids: List<&2, P.Identity>
  for +entries: List<&2, T.Entry<Tag>>
  {S.run(Tag, steps, P.Builder{ids, entries}) == S.follow(Tag, entries, S.assemble(Tag, steps, ids)) : P.Builder<Tag>}

# A second use of an identity is a no-op whatever its body (or config) and
# whatever the first body did, at any position and from any starting app.
law plugin_named_repeat:
  for -Tag: Data
  for +id: P.Identity
  for +first: List<&2, S.Step<Tag>>
  for +second: List<&2, S.Step<Tag>>
  for +rest: List<&2, S.Step<Tag>>
  for +app: P.Builder<Tag>
  {S.run(Tag, S.Plugin{Some{id}, first} <> S.Plugin{Some{id}, second} <> rest, app) == S.run(Tag, S.Plugin{Some{id}, first} <> rest, app) : P.Builder<Tag>}

# Anonymous plugins compose exactly as plain list concatenation, with each
# scope applied to its own flattened body, and never change the identities.
law plugin_anonymous_flatten:
  for -Tag: Data
  for +steps: List<&2, S.Step<Tag>>
  for +ids: List<&2, P.Identity>
  for +entries: List<&2, T.Entry<Tag>>
  {S.run(Tag, S.erase(Tag, steps), P.Builder{ids, entries}) == P.Builder{ids, List.append(&2, T.Entry<Tag>, entries, S.flatten(Tag, steps))} : P.Builder<Tag>}
