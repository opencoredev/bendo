import Base
import ../router/methods.bend as Methods
import ../router/pattern.bend as Pattern

# Routes and middleware share app-owned identifiers, resolved by separate
# closed dispatchers. No function or continuation is stored in this table.
type Entry<-Tag: Data> is Data:
  Route{registration: Methods.Registration(Tag)}
  Use{source: Maybe<&2, String>, tag: Tag}

type Middleware<-Tag: Data> is Data:
  Middleware{pattern: Maybe<&2, Pattern.Pattern>, tag: Tag}

type Table<-Tag: Data> is Data:
  Table{entries: List<&2, Methods.Registration(Tag)>, compiled: Methods.Valid<Tag>, middleware: List<&2, Middleware<Tag>>}

def route_entries(-Tag: Data, xs: List<&2, Entry<Tag>>) -> List<&2, Methods.Registration(Tag)>:
  match xs:
    case Nil{}: []
    case Route{r} <> tail: r <> route_entries(Tag, tail)
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
    case Use{None{}, tag} <> tail:
      prepend(Tag, Middleware{None{}, tag}, middleware_entries(Tag, tail, 1n+index))
    case Use{Some{+source}, tag} <> tail:
      pattern_built(Tag, index, source, tag, Pattern.compile(source), u => middleware_entries(Tag, tail, 1n+index))

def built(-Tag: Data, entries: List<&2, Methods.Registration(Tag)>, middleware: List<&2, Middleware<Tag>>, result: Result<&2, &2, Methods.BuildError, Methods.Valid<Tag>>) -> Result<&2, &2, Methods.BuildError, Table<Tag>>:
  match result:
    case Fail{error}: Fail{error}
    case Done{table}: Done{Table{entries, table, middleware}}

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
    case Middleware{None{}, tag} <> tail: tag <> selected(Tag, tail, path)
    case Middleware{Some{p}, tag} <> tail:
      include(Tag, tag, selected(Tag, tail, path), Maybe.is_some(&2, Pattern.Params, Pattern.match_path(p, path)))
