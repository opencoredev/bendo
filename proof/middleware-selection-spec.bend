import Base
import ../src/app/table.bend as Table
import ../src/router/pattern.bend as Pattern

# Direct stable filter over source registrations. Routes contribute no ids;
# invalid patterns cannot occur in a successful table and select nothing here.
def matching(-Tag: Data, tag: Tag, rest: List<&2, Tag>, result: Maybe<&2, Pattern.Params>) -> List<&2, Tag>:
  match result:
    case None{}: rest
    case Some{params}: tag <> rest

def compiled(-Tag: Data, tag: Tag, rest: List<&2, Tag>, path: String, result: Result<&2, &2, Pattern.PatternError, Pattern.Pattern>) -> List<&2, Tag>:
  match result:
    case Fail{error}: rest
    case Done{pattern}: matching(Tag, tag, rest, Pattern.match_path(pattern, path))

def filter(-Tag: Data, entries: List<&2, Table.Entry<Tag>>, +path: String) -> List<&2, Tag>:
  match entries:
    case Nil{}: []
    case Table.Route{registration} <> rest: filter(Tag, rest, path)
    case Table.Use{None{}, tag} <> rest: tag <> filter(Tag, rest, path)
    case Table.Use{Some{source}, tag} <> rest:
      compiled(Tag, tag, filter(Tag, rest, path), path, Pattern.compile(source))

def selected(-Tag: Data, table: Table.Table<Tag>, path: String) -> List<&2, Tag>:
  Table.Table{entries, routes, middleware} = table
  Table.selected(Tag, middleware, path)
