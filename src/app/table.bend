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

# Scope is provenance attached to an individual route, never a path predicate.
# Prefixes are already applied by group; guard membership is structural.
type Scope is Data:
  GroupScope{prefix: String}
  GuardScope{}
  RouteScope{}

type HookSpec<-Tag: Data> is Data:
  HookSpec{stage: Stage, tag: Tag}

type Placement<-Tag: Data> is Data:
  Placement{scope: Scope, hook: HookSpec<Tag>}

# BND-33/34 will supply schema descriptions. This closed slot deliberately
# cannot carry an unchecked string or promise validation that does not exist.
type SchemaSlot is Data:
  NoSchemas{}

type GuardOptions<-Tag: Data> is Data:
  GuardOptions{hooks: List<&2, HookSpec<Tag>>, schemas: SchemaSlot}

# Routes and middleware share app-owned identifiers, resolved by separate
# closed dispatchers. No function or continuation is stored in this table.
type Entry<-Tag: Data> is Data:
  Route{registration: Methods.Registration(Tag)}
  ScopedRoute{registration: Methods.Registration(Tag), hooks: List<&2, Placement<Tag>>}
  Hook{stage: Stage, tag: Tag}
  Use{source: Maybe<&2, String>, tag: Tag}
  # Mounted middleware moves with member routes through subsequent groups.
  PrefixedUse{source: String, tag: Tag}

type Middleware<-Tag: Data> is Data:
  Staged{stage: Stage, tag: Tag}
  Scoped{from_end: Nat, hooks: List<&2, Placement<Tag>>}
  Middleware{pattern: Maybe<&2, Pattern.Pattern>, tag: Tag}

# The compiled index and route count are built once. Request-time scope
# identity conversion must not traverse the registration list.
type Table<-Tag: Data> is Data:
  Table{entries: List<&2, Methods.Registration(Tag)>, compiled: Methods.Index<Tag>, middleware: List<&2, Middleware<Tag>>, count: Nat}

def route_entries(-Tag: Data, xs: List<&2, Entry<Tag>>) -> List<&2, Methods.Registration(Tag)>:
  match xs:
    case Nil{}: []
    case Route{r} <> tail: r <> route_entries(Tag, tail)
    case ScopedRoute{r, hooks} <> +tail: r <> route_entries(Tag, tail)
    case Hook{stage, tag} <> tail: route_entries(Tag, tail)
    case Use{source, tag} <> tail: route_entries(Tag, tail)
    case PrefixedUse{source, tag} <> tail: route_entries(Tag, tail)

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
    case ScopedRoute{r, hooks} <> +tail:
      route_checked(Tag, index, Methods.build_table(Tag, [r]), u => prepend(Tag, Scoped{List.length(&2, Methods.Registration(Tag), route_entries(Tag, tail)), hooks}, middleware_entries(Tag, tail, 1n+index)))
    case Hook{stage, tag} <> tail:
      prepend(Tag, Staged{stage, tag}, middleware_entries(Tag, tail, 1n+index))
    case Use{None{}, tag} <> tail:
      prepend(Tag, Middleware{None{}, tag}, middleware_entries(Tag, tail, 1n+index))
    case PrefixedUse{+source, tag} <> tail:
      pattern_built(Tag, index, source, tag, Pattern.compile(source), u => middleware_entries(Tag, tail, 1n+index))
    case Use{Some{+source}, tag} <> tail:
      pattern_built(Tag, index, source, tag, Pattern.compile(source), u => middleware_entries(Tag, tail, 1n+index))

def built(-Tag: Data, +entries: List<&2, Methods.Registration(Tag)>, middleware: List<&2, Middleware<Tag>>, result: Result<&2, &2, Methods.BuildError, Methods.Valid<Tag>>) -> Result<&2, &2, Methods.BuildError, Table<Tag>>:
  match result:
    case Fail{error}: Fail{error}
    case Done{table}: Done{Table{entries, Methods.prepare(Tag, table), middleware, List.length(&2, Methods.Registration(Tag), entries)}}

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
    case Scoped{index, hooks} <> tail: selected(Tag, tail, path)
    case Middleware{None{}, tag} <> tail: tag <> selected(Tag, tail, path)
    case Middleware{Some{p}, tag} <> tail:
      include(Tag, tag, selected(Tag, tail, path), Maybe.is_some(&2, Pattern.Params, Pattern.match_path(p, path)))

# A stable stage filter; legacy middleware remains independently path-selected.
def stage_ids(-Tag: Data, entries: List<&2, Middleware<Tag>>, +stage: Stage) -> List<&2, Tag>:
  match entries:
    case Nil{}: []
    case Middleware{pattern, tag} <> tail: stage_ids(Tag, tail, stage)
    case Scoped{index, hooks} <> tail: stage_ids(Tag, tail, stage)
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

# The reversed ordinal is stable when a group/guard list is prepended to another
# list. Convert the router's forward ordinal once at the runtime boundary.
def hook_ids(-Tag: Data, hooks: List<&2, Placement<Tag>>, +stage: Stage) -> List<&2, Tag>:
  match hooks:
    case Nil{}: []
    case Placement{scope, HookSpec{kind, tag}} <> tail:
      include(Tag, tag, hook_ids(Tag, tail, stage), U32.is_eq(stage_number(kind), stage_number(stage)))

def include_hooks(-Tag: Data, hooks: List<&2, Placement<Tag>>, stage: Stage, yes: Bool) -> List<&2, Tag>:
  match yes:
    case True{}: hook_ids(Tag, hooks, stage)
    case False{}: []

def route_stage_ids(-Tag: Data, layers: List<&2, Middleware<Tag>>, +route: Maybe<&2, Nat>, +stage: Stage) -> List<&2, Tag>:
  match layers:
    case Nil{}: []
    case Scoped{index, hooks} <> tail:
      match route:
        case None{}: route_stage_ids(Tag, tail, None{}, stage)
        case Some{n}: List.append(&2, Tag, include_hooks(Tag, hooks, stage, Nat.is_eq(index, n)), route_stage_ids(Tag, tail, Some{n}, stage))
    case _ <> tail: route_stage_ids(Tag, tail, route, stage)

def scoped_stage_ids(-Tag: Data, +layers: List<&2, Middleware<Tag>>, route: Maybe<&2, Nat>, +stage: Stage) -> List<&2, Tag>:
  List.append(&2, Tag, stage_ids(Tag, layers, stage), route_stage_ids(Tag, layers, route, stage))

def scoped_lifecycle(-Tag: Data, +layers: List<&2, Middleware<Tag>>, path: String, +route: Maybe<&2, Nat>) -> Lifecycle<Tag>:
  Lifecycle{
    scoped_stage_ids(Tag, layers, route, Request{}),
    List.concat(&2, Tag, [selected(Tag, layers, path), scoped_stage_ids(Tag, layers, route, Parse{}), scoped_stage_ids(Tag, layers, route, Transform{}), scoped_stage_ids(Tag, layers, route, BeforeHandle{})]),
    scoped_stage_ids(Tag, layers, route, AfterHandle{}),
    scoped_stage_ids(Tag, layers, route, MapResponse{}),
    scoped_stage_ids(Tag, layers, route, Error{}),
    scoped_stage_ids(Tag, layers, route, AfterResponse{})}
