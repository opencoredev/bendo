# Transport admission uses the original request's route and scopes. Request
# hooks have not run yet; rewrites receive an additional buffered limit check.
import Base
import ./table.bend as Table
import ./route-slot.bend as Slot
import ../http/request.bend as Request
import ../router/methods.bend as Methods
import ../router/router.bend as Router

def lower(current: U32, proposed: Maybe<&2, U32>) -> U32:
  match proposed:
    case None{}: current
    case Some{n}: U32.min(current, n)

def limits(~Tag: Data, ~select: Tag -> Maybe<&2, U32>, ids: List<&2, Tag>, fallback: U32) -> U32:
  match ids:
    case Nil{}: fallback
    case id <> tail: limits(~Tag, ~select, tail, lower(fallback, select(id)))

def for_request(~Tag: Data, ~select: Tag -> Maybe<&2, U32>, +req: Request.Req, table: Table.Table<Tag>, hooks: Table.HookIndex<Tag>, kind: Router.RouterKind, fallback: U32) -> U32:
  Request.Req{method, +path, q, version, hs} = req
  Table.Table{entries, compiled, layers, count} = table
  +route = Slot.identity(Tag, count, Methods.resolve_with(Tag, kind, compiled, path, method, Methods.defaults()))
  +plan = Table.scoped_lifecycle(Tag, Table.relevant(Tag, hooks, route), path, route)
  limits(~Tag, ~select, List.append(&2, Tag, Table.lifecycle_request(Tag, plan), Table.lifecycle_pre(Tag, plan)), fallback)
