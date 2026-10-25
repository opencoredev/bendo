# BND-82: scoped hooks indexed by route identity. Request-time selection reads
# relevant(index(layers), route), the global layers plus the route's bucket,
# instead of every layer. These laws state that the index changes no selection:
# for every layer list (built or not), route and stage, selection through the
# index equals the BND-23/BND-24 selection over the full list, so every law
# about that selection holds of the index too. The last two connect the index
# straight to the BND-24 specification for every built table.
import Base
import ../src/app/table.bend as Table
import ../src/app/validate.bend as V
import ../src/router/methods.bend as Methods
import ./scoped-selection-spec.bend as ScopedSelectionSpec

law scoped_index_stage_selection:
  for -Tag: Data
  for +layers: List<&2, Table.Middleware<Tag>>
  for +route: Maybe<&2, Nat>
  for +stage: Table.Stage
  {Table.scoped_stage_ids(Tag, Table.relevant(Tag, Table.index(Tag, layers), route), route, stage) == Table.scoped_stage_ids(Tag, layers, route, stage) : List<&2, Tag>}

law scoped_index_lifecycle_selection:
  for -Tag: Data
  for +layers: List<&2, Table.Middleware<Tag>>
  for +path: String
  for +route: Maybe<&2, Nat>
  {Table.scoped_lifecycle(Tag, Table.relevant(Tag, Table.index(Tag, layers), route), path, route) == Table.scoped_lifecycle(Tag, layers, path, route) : Table.Lifecycle<Tag>}

law scoped_index_route_schemas:
  for -Tag: Data
  for +layers: List<&2, Table.Middleware<Tag>>
  for +route: Maybe<&2, Nat>
  {Table.route_schemas(Tag, Table.relevant(Tag, Table.index(Tag, layers), route), route) == Table.route_schemas(Tag, layers, route) : V.Schemas}

# The global list alone selects every global hook and path middleware.
law scoped_index_global_stages:
  for -Tag: Data
  for +layers: List<&2, Table.Middleware<Tag>>
  for +stage: Table.Stage
  {Table.stage_ids(Tag, Table.index_globals(Tag, Table.index(Tag, layers)), stage) == Table.stage_ids(Tag, layers, stage) : List<&2, Tag>}

law scoped_index_global_selected:
  for -Tag: Data
  for +layers: List<&2, Table.Middleware<Tag>>
  for +path: String
  {Table.selected(Tag, Table.index_globals(Tag, Table.index(Tag, layers)), path) == Table.selected(Tag, layers, path) : List<&2, Tag>}

law scoped_index_spec_stage_selection:
  for -Tag: Data
  for +entries: List<&2, Table.Entry<Tag>>
  for +routes: List<&2, Methods.Registration(Tag)>
  for +compiled: Methods.Index<Tag>
  for +layers: List<&2, Table.Middleware<Tag>>
  for +count: Nat
  for +route: Maybe<&2, Nat>
  for +stage: Table.Stage
  for +built: {Table.build(Tag, entries) == Done{Table.Table{routes, compiled, layers, count}} : Result<&2, &2, Methods.BuildError, Table.Table<Tag>>}
  {Table.scoped_stage_ids(Tag, Table.relevant(Tag, Table.index(Tag, layers), route), route, stage) == ScopedSelectionSpec.stage_ids(Tag, entries, route, stage) : List<&2, Tag>}

law scoped_index_spec_lifecycle_selection:
  for -Tag: Data
  for +entries: List<&2, Table.Entry<Tag>>
  for +routes: List<&2, Methods.Registration(Tag)>
  for +compiled: Methods.Index<Tag>
  for +layers: List<&2, Table.Middleware<Tag>>
  for +count: Nat
  for +path: String
  for +route: Maybe<&2, Nat>
  for +built: {Table.build(Tag, entries) == Done{Table.Table{routes, compiled, layers, count}} : Result<&2, &2, Methods.BuildError, Table.Table<Tag>>}
  {Table.scoped_lifecycle(Tag, Table.relevant(Tag, Table.index(Tag, layers), route), path, route) == ScopedSelectionSpec.lifecycle(Tag, entries, path, route) : Table.Lifecycle<Tag>}
