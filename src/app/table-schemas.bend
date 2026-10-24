# The schemas each route of an assembled table validates with (BND-36), in
# registration order, for the BND-37 manifest. Kept out of table.bend and
# manifest-schemas.bend so only validating apps compile it.
import Base
import ./table.bend as Table
import ./validate.bend as V
import ./route-schemas.bend as RS
import ../data/schema.bend as S
import ../data/schema-prepared.bend as SP

def raw(c: Maybe<&2, SP.Checked>) -> Maybe<&2, S.Schema>:
  match c:
    case None{}: None{}
    case Some{k}: Some{SP.schema(k)}

def route_schemas(set: V.Schemas) -> RS.RouteSchemas:
  V.Schemas{p, q, h, b, r} = set
  RS.RouteSchemas{raw(p), raw(q), raw(h), raw(b), raw(r)}

# The table stores a route's identity as the number of routes after it, so
# with k routes left the next one in registration order is identity k - 1.
def effective_go(-Tag: Data, +layers: List<&2, Table.Middleware<Tag>>, k: Nat) -> List<&2, RS.RouteSchemas>:
  match k:
    case 0n: []
    case 1n+(+j): route_schemas(Table.route_schemas(Tag, layers, Some{j})) <> effective_go(Tag, layers, j)

# One entry per route registration, in registration order: each route's
# effective schemas after guards, groups, mounts and plugins.
def effective(-Tag: Data, table: Table.Table<Tag>) -> List<&2, RS.RouteSchemas>:
  Table.Table{entries, compiled, layers, count} = table
  effective_go(Tag, layers, count)
