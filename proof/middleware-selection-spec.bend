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
    case Table.Hook{stage, tag} <> rest: filter(Tag, rest, path)
    case Table.Route{registration} <> rest: filter(Tag, rest, path)
    case Table.Use{None{}, tag} <> rest: tag <> filter(Tag, rest, path)
    case Table.Use{Some{source}, tag} <> rest:
      compiled(Tag, tag, filter(Tag, rest, path), path, Pattern.compile(source))

def selected(-Tag: Data, table: Table.Table<Tag>, path: String) -> List<&2, Tag>:
  Table.Table{entries, routes, middleware} = table
  Table.selected(Tag, middleware, path)

# Independent constructor comparison, deliberately not Table.stage_number.
def same_stage(a: Table.Stage, b: Table.Stage) -> Bool:
  match a b:
    case Table.Request{} Table.Request{}: True{}
    case Table.Parse{} Table.Parse{}: True{}
    case Table.Transform{} Table.Transform{}: True{}
    case Table.BeforeHandle{} Table.BeforeHandle{}: True{}
    case Table.AfterHandle{} Table.AfterHandle{}: True{}
    case Table.MapResponse{} Table.MapResponse{}: True{}
    case Table.Error{} Table.Error{}: True{}
    case Table.AfterResponse{} Table.AfterResponse{}: True{}
    case _ _: False{}

def keep(-Tag: Data, tag: Tag, rest: List<&2, Tag>, yes: Bool) -> List<&2, Tag>:
  match yes:
    case True{}: tag <> rest
    case False{}: rest

# Stable source filter: routes/use contribute nothing, duplicates stay intact.
def hooks(-Tag: Data, entries: List<&2, Table.Entry<Tag>>, +stage: Table.Stage) -> List<&2, Tag>:
  match entries:
    case Nil{}: []
    case Table.Hook{kind, tag} <> rest:
      keep(Tag, tag, hooks(Tag, rest, stage), same_stage(kind, stage))
    case _ <> rest: hooks(Tag, rest, stage)

# 0010's complete selection plan, independently filtered from registrations.
def lifecycle(-Tag: Data, +entries: List<&2, Table.Entry<Tag>>, path: String) -> Table.Lifecycle<Tag>:
  Table.Lifecycle{
    hooks(Tag, entries, Table.Request{}),
    List.concat(&2, Tag, [filter(Tag, entries, path), hooks(Tag, entries, Table.Parse{}), hooks(Tag, entries, Table.Transform{}), hooks(Tag, entries, Table.BeforeHandle{})]),
    hooks(Tag, entries, Table.AfterHandle{}),
    hooks(Tag, entries, Table.MapResponse{}),
    hooks(Tag, entries, Table.Error{}),
    hooks(Tag, entries, Table.AfterResponse{})}
