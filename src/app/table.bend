import Base
import ../router/methods.bend as Methods
import ../router/pattern.bend as Pattern

type Stage is Data:
  Request{}
  Parse{}
  Transform{}
  BeforeHandle{}
  AfterHandle{}
  MapResponse{}
  Error{}
  AfterResponse{}
  NotFound{}

def stage_number(stage: Stage) -> U32:
  match stage:
    case Request{}: 0
    case Parse{}: 1
    case Transform{}: 2
    case BeforeHandle{}: 3
    case AfterHandle{}: 4
    case MapResponse{}: 5
    case Error{}: 6
    case AfterResponse{}: 7
    case NotFound{}: 8

# Routes and middleware share app-owned identifiers, resolved by separate
# closed dispatchers. No function or continuation is stored in this table.
type Entry<-Tag: Data> is Data:
  Route{registration: Methods.Registration(Tag)}
  Hook{stage: Stage, tag: Tag}
  Use{source: Maybe<&2, String>, tag: Tag}

type Middleware<-Tag: Data> is Data:
  Staged{stage: Stage, tag: Tag}
  Middleware{pattern: Maybe<&2, Pattern.Pattern>, tag: Tag}

# The compiled index holds the validated table and its trie, built once.
type Table<-Tag: Data> is Data:
  Table{entries: List<&2, Methods.Registration(Tag)>, compiled: Methods.Index<Tag>, middleware: List<&2, Middleware<Tag>>}

def route_entries(-Tag: Data, xs: List<&2, Entry<Tag>>) -> List<&2, Methods.Registration(Tag)>:
  match xs:
    case Nil{}: []
    case Route{r} <> tail: r <> route_entries(Tag, tail)
    case Hook{stage, tag} <> tail: route_entries(Tag, tail)
    case Use{source, tag} <> tail: route_entries(Tag, tail)

def prepend(-Tag: Data, mw: Middleware<Tag>, rest: Result<&2, &2, Methods.BuildError, List<&2, Middleware<Tag>>>) -> Result<&2, &2, Methods.BuildError, List<&2, Middleware<Tag>>>:
  match rest:
    case Fail{e}: Fail{e}
    case Done{xs}: Done{mw <> xs}

def pattern_built(-Tag: Data, index: Nat, source: String, tag: Tag, pattern: Result<&2, &2, Pattern.PatternError, Pattern.Pattern>, rest: Unit -> Result<&2, &2, Methods.BuildError, List<&2, Middleware<Tag>>>) -> Result<&2, &2, Methods.BuildError, List<&2, Middleware<Tag>>>:
  match pattern:
    case Fail{e}: Fail{Methods.InvalidPattern{index, source, e}}
    case Done{p}: prepend(Tag, Middleware{Some{p}, tag}, rest(Unit{}))

# Validate route registrations while traversing the mixed list, so build errors
# refer to the original position and the first invalid entry wins.
def route_checked(-Tag: Data, index: Nat, checked: Result<&2, &2, Methods.BuildError, Methods.Valid<Tag>>, rest: Unit -> Result<&2, &2, Methods.BuildError, List<&2, Middleware<Tag>>>) -> Result<&2, &2, Methods.BuildError, List<&2, Middleware<Tag>>>:
  match checked:
    case Fail{Methods.InvalidPattern{old, source, error}}: Fail{Methods.InvalidPattern{index, source, error}}
    case Fail{Methods.InvalidMethod{old, source, token}}: Fail{Methods.InvalidMethod{index, source, token}}
    case Done{table}: rest(Unit{})

def middleware_entries(-Tag: Data, xs: List<&2, Entry<Tag>>, +index: Nat) -> Result<&2, &2, Methods.BuildError, List<&2, Middleware<Tag>>>:
  match xs:
    case Nil{}: Done{[]}
    case Route{r} <> tail:
      route_checked(Tag, index, Methods.build_table(Tag, [r]), u => middleware_entries(Tag, tail, 1n+index))
    case Hook{stage, tag} <> tail:
      prepend(Tag, Staged{stage, tag}, middleware_entries(Tag, tail, 1n+index))
    case Use{None{}, tag} <> tail:
      prepend(Tag, Middleware{None{}, tag}, middleware_entries(Tag, tail, 1n+index))
    case Use{Some{+source}, tag} <> tail:
      pattern_built(Tag, index, source, tag, Pattern.compile(source), u => middleware_entries(Tag, tail, 1n+index))

def built(-Tag: Data, entries: List<&2, Methods.Registration(Tag)>, middleware: List<&2, Middleware<Tag>>, result: Result<&2, &2, Methods.BuildError, Methods.Valid<Tag>>) -> Result<&2, &2, Methods.BuildError, Table<Tag>>:
  match result:
    case Fail{error}: Fail{error}
    case Done{table}: Done{Table{entries, Methods.prepare(Tag, table), middleware}}

def collected(-Tag: Data, +entries: List<&2, Methods.Registration(Tag)>, result: Result<&2, &2, Methods.BuildError, List<&2, Middleware<Tag>>>) -> Result<&2, &2, Methods.BuildError, Table<Tag>>:
  match result:
    case Fail{e}: Fail{e}
    case Done{middleware}: built(Tag, entries, middleware, Methods.build_table(Tag, entries))

def build(-Tag: Data, +entries: List<&2, Entry<Tag>>) -> Result<&2, &2, Methods.BuildError, Table<Tag>>:
  collected(Tag, route_entries(Tag, entries), middleware_entries(Tag, entries, 0n))

def include(-Tag: Data, tag: Tag, rest: List<&2, Tag>, matches: Bool) -> List<&2, Tag>:
  match matches:
    case True{}: tag <> rest
    case False{}: rest

def selected(-Tag: Data, entries: List<&2, Middleware<Tag>>, +path: String) -> List<&2, Tag>:
  match entries:
    case Nil{}: []
    case Staged{stage, tag} <> tail: selected(Tag, tail, path)
    case Middleware{None{}, tag} <> tail: tag <> selected(Tag, tail, path)
    case Middleware{Some{p}, tag} <> tail:
      include(Tag, tag, selected(Tag, tail, path), Maybe.is_some(&2, Pattern.Params, Pattern.match_path(p, path)))

# A stable stage filter; legacy middleware remains independently path-selected.
def stage_ids(-Tag: Data, entries: List<&2, Middleware<Tag>>, +stage: Stage) -> List<&2, Tag>:
  match entries:
    case Nil{}: []
    case Middleware{pattern, tag} <> tail: stage_ids(Tag, tail, stage)
    case Staged{kind, tag} <> tail:
      include(Tag, tag, stage_ids(Tag, tail, stage), U32.is_eq(stage_number(kind), stage_number(stage)))

# The runtime's stage-ordered execution plan. The pre chain enters after routing;
# response chains execute sequentially, errors conditionally, observers after send.
type Lifecycle<-Tag: Data> is Data:
  Lifecycle{request: List<&2, Tag>, pre: List<&2, Tag>, after: List<&2, Tag>, map: List<&2, Tag>, errors: List<&2, Tag>, observers: List<&2, Tag>}

def lifecycle(-Tag: Data, +layers: List<&2, Middleware<Tag>>, path: String) -> Lifecycle<Tag>:
  Lifecycle{
    stage_ids(Tag, layers, Request{}),
    List.concat(&2, Tag, [selected(Tag, layers, path), stage_ids(Tag, layers, Parse{}), stage_ids(Tag, layers, Transform{}), stage_ids(Tag, layers, BeforeHandle{})]),
    stage_ids(Tag, layers, AfterHandle{}),
    stage_ids(Tag, layers, MapResponse{}),
    stage_ids(Tag, layers, Error{}),
    stage_ids(Tag, layers, AfterResponse{})}

def lifecycle_request(-Tag: Data, plan: Lifecycle<Tag>) -> List<&2, Tag>:
  Lifecycle{request, pre, after, map, errors, observers} = plan
  request

def lifecycle_pre(-Tag: Data, plan: Lifecycle<Tag>) -> List<&2, Tag>:
  Lifecycle{request, pre, after, map, errors, observers} = plan
  pre

def lifecycle_after(-Tag: Data, plan: Lifecycle<Tag>) -> List<&2, Tag>:
  Lifecycle{request, pre, after, map, errors, observers} = plan
  after

def lifecycle_map(-Tag: Data, plan: Lifecycle<Tag>) -> List<&2, Tag>:
  Lifecycle{request, pre, after, map, errors, observers} = plan
  map

def lifecycle_errors(-Tag: Data, plan: Lifecycle<Tag>) -> List<&2, Tag>:
  Lifecycle{request, pre, after, map, errors, observers} = plan
  errors

def lifecycle_observers(-Tag: Data, plan: Lifecycle<Tag>) -> List<&2, Tag>:
  Lifecycle{request, pre, after, map, errors, observers} = plan
  observers
