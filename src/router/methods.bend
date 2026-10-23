# Method-aware reference routing; app tags remain copyable data.
import Base
import ./spec.bend as S
import ./trie.bend as Tr
import ./router.bend as Router
import ./pattern.bend as P
import ./encoding.bend as E
import ./proofs.bend as Core
import ../http/request.bend as R
import ../http/bytes.bend as B

type Binding<-T: Data> is Data:
  Binding{methods: List<&2, R.Method>, tag: T}

def Table(-T: Data) -> Data:
  S.Table(Binding<T>)

def list_valid(xs: List<&2, R.Method>) -> Bool:
  match xs:
    case Nil{}: True{}
    case h <> tail: R.method_valid(h) && list_valid(tail)

def TableValid(-T: Data, table: Table(T)) -> Bool:
  match table:
    case Nil{}: True{}
    case S.Route{pattern, Binding{methods, tag}} <> tail:
      list_valid(methods) && TableValid(T, tail)

# Public resolution requires evidence for the exact stored table. Constructors
# remain exported, but invalid method tokens cannot inhabit this type.
type Valid<-T: Data> is Data:
  Valid{table: Table(T), ok: {TableValid(T, table) == True{} : Bool}}

def raw(-T: Data, valid: Valid<T>) -> Table(T):
  Valid{table, ok} = valid
  table

def Registration(-T: Data) -> Data:
  S.Registration<Binding<T>>

type Options is Data:
  Options{strict_trailing_slash: Bool, case_sensitive: Bool}

def defaults() -> Options:
  Options{True{}, True{}}

type Resolution<-T: Data> is Data:
  Found{hit: S.Match<T>, head_from_get: Bool}
  MethodNotAllowed{allow: List<&2, R.Method>}
  NotFound{}

def on(-T: Data, methods: List<&2, R.Method>, path: String, tag: T) -> Registration(T):
  S.Registration{path, Binding{methods, tag}}

def standard_methods() -> List<&2, R.Method>:
  [R.Get{}, R.Head{}, R.Post{}, R.Put{}, R.Delete{}, R.Connect{}, R.Options{}, R.Trace{}, R.Patch{}]

def get(-T: Data, path: String, tag: T) -> Registration(T):
  on(T, [R.Get{}], path, tag)

def post(-T: Data, path: String, tag: T) -> Registration(T):
  on(T, [R.Post{}], path, tag)

def put(-T: Data, path: String, tag: T) -> Registration(T):
  on(T, [R.Put{}], path, tag)

def patch(-T: Data, path: String, tag: T) -> Registration(T):
  on(T, [R.Patch{}], path, tag)

def delete(-T: Data, path: String, tag: T) -> Registration(T):
  on(T, [R.Delete{}], path, tag)

def options(-T: Data, path: String, tag: T) -> Registration(T):
  on(T, [R.Options{}], path, tag)

def head(-T: Data, path: String, tag: T) -> Registration(T):
  on(T, [R.Head{}], path, tag)

def all(-T: Data, path: String, tag: T) -> Registration(T):
  on(T, standard_methods(), path, tag)

type BuildError is Data:
  InvalidPattern{index: Nat, source: String, error: P.PatternError}
  InvalidMethod{index: Nat, source: String, token: String}

# HTTP method tokens are case-sensitive. Only exact standard names normalize.
def normalize_methods(xs: List<&2, R.Method>) -> List<&2, R.Method>:
  match xs:
    case Nil{}: Nil{}
    case h <> tail:
      R.method(R.method_text(h)) <> normalize_methods(tail)

def invalid_method(xs: List<&2, R.Method>) -> Maybe<&2, String>:
  match xs:
    case Nil{}: None{}
    case +h <> tail:
      E.choose(Maybe<&2, String>, R.method_valid(h), u => invalid_method(tail), u => Some{R.method_text(h)})

def InvalidChecked(+methods: List<&2, R.Method>, invalid: Maybe<&2, String>) -> Type:
  match invalid:
    case Some{token}: Unit
    case None{}: {list_valid(methods) == True{} : Bool}

def invalid_checked_cons(+h: R.Method, +tail: List<&2, R.Method>, +invalid: Maybe<&2, String>,
    valid: {R.method_valid(h) == True{} : Bool}, rest: InvalidChecked(tail, invalid)) -> InvalidChecked(h <> tail, invalid):
  match invalid:
    case Some{token}: Unit{}
    case None{}:
      %Equal.sym(Bool, R.method_valid(h), True{}, valid) : {_ && list_valid(tail) == True{} : Bool}
      rest

def invalid_checked_step(+h: R.Method, +tail: List<&2, R.Method>, test: Bool,
    decision: {R.method_valid(h) == test : Bool},
    rest: InvalidChecked(tail, invalid_method(tail))) ->
    InvalidChecked(h <> tail, E.choose(Maybe<&2, String>, test, u => invalid_method(tail), u => Some{R.method_text(h)})):
  match test:
    case False{}: Unit{}
    case True{}:
      invalid_checked_cons(h, tail, invalid_method(tail), decision, rest)

def invalid_checked(+methods: List<&2, R.Method>) -> InvalidChecked(methods, invalid_method(methods)):
  match methods:
    case Nil{}: {==}
    case +h <> +tail:
      invalid_checked_step(h, tail, R.method_valid(h), {==}, invalid_checked(tail))

def prepend_built(-T: Data, pattern: P.Pattern, binding: Binding<T>, result: Result<&2, &2, BuildError, Table(T)>) -> Result<&2, &2, BuildError, Table(T)>:
  match result:
    case Fail{error}: Fail{error}
    case Done{tail}: Done{S.Route{pattern, binding} <> tail}

def build_pattern(-T: Data, index: Nat, source: String, binding: Binding<T>, compiled: Result<&2, &2, P.PatternError, P.Pattern>, rest: Unit -> Result<&2, &2, BuildError, Table(T)>) -> Result<&2, &2, BuildError, Table(T)>:
  match compiled:
    case Fail{error}: Fail{InvalidPattern{index, source, error}}
    case Done{pattern}: prepend_built(T, pattern, binding, rest(Unit{}))

# A caller-supplied None must carry evidence that every method is valid.
def build_methods(-T: Data, index: Nat, +source: String, methods: List<&2, R.Method>, tag: T, invalid: Maybe<&2, String>, -checked: InvalidChecked(methods, invalid), rest: Unit -> Result<&2, &2, BuildError, Table(T)>) -> Result<&2, &2, BuildError, Table(T)>:
  match invalid:
    case Some{token}: Fail{InvalidMethod{index, source, token}}
    case None{}: build_pattern(T, index, source, Binding{methods, tag}, P.compile(source), rest)

# Fail atomically at the first invalid registration; method errors precede
# pattern errors within the same registration.
def build_go(-T: Data, entries: List<&2, Registration(T)>, +index: Nat) -> Result<&2, &2, BuildError, Table(T)>:
  match entries:
    case Nil{}: Done{Nil{}}
    case S.Registration{+source, Binding{methods, tag}} <> rest:
      +normalized = normalize_methods(methods)
      build_methods(T, index, source, normalized, tag, invalid_method(normalized), invalid_checked(normalized), u => build_go(T, rest, 1n+index))

# A successful public build has no invalid methods, including raw on entries.
def BuildValid(-T: Data, result: Result<&2, &2, BuildError, Table(T)>) -> Bool:
  match result:
    case Fail{error}: True{}
    case Done{table}: TableValid(T, table)

def prepend_valid(-T: Data, +pattern: P.Pattern, +methods: List<&2, R.Method>, +tag: T,
    +result: Result<&2, &2, BuildError, Table(T)>,
    valid: {list_valid(methods) == True{} : Bool},
    rest: {BuildValid(T, result) == True{} : Bool}) ->
    {BuildValid(T, prepend_built(T, pattern, Binding{methods, tag}, result)) == True{} : Bool}:
  match result:
    case Fail{error}: {==}
    case Done{table}:
      %Equal.sym(Bool, list_valid(methods), True{}, valid) : {_ && TableValid(T, table) == True{} : Bool}
      rest

def build_pattern_valid(-T: Data, +index: Nat, +source: String, +methods: List<&2, R.Method>, +tag: T,
    +compiled: Result<&2, &2, P.PatternError, P.Pattern>,
    rest: Unit -> Result<&2, &2, BuildError, Table(T)>,
    valid: {list_valid(methods) == True{} : Bool},
    good: {BuildValid(T, rest(Unit{})) == True{} : Bool}) ->
    {BuildValid(T, build_pattern(T, index, source, Binding{methods, tag}, compiled, rest)) == True{} : Bool}:
  match compiled:
    case Fail{error}: {==}
    case Done{pattern}: prepend_valid(T, pattern, methods, tag, rest(Unit{}), valid, good)

def build_methods_valid(-T: Data, +index: Nat, +source: String, +methods: List<&2, R.Method>, +tag: T,
    +invalid: Maybe<&2, String>, rest: Unit -> Result<&2, &2, BuildError, Table(T)>,
    checked: InvalidChecked(methods, invalid), good: {BuildValid(T, rest(Unit{})) == True{} : Bool}) ->
    {BuildValid(T, build_methods(T, index, source, methods, tag, invalid, checked, rest)) == True{} : Bool}:
  match invalid:
    case Some{token}: {==}
    case None{}: build_pattern_valid(T, index, source, methods, tag, P.compile(source), rest, checked, good)

def build_go_valid(-T: Data, +entries: List<&2, Registration(T)>, +index: Nat) ->
    {BuildValid(T, build_go(T, entries, index)) == True{} : Bool}:
  match entries:
    case Nil{}: {==}
    case S.Registration{+source, Binding{methods, +tag}} <> +tail:
      +normalized = normalize_methods(methods)
      build_methods_valid(T, index, source, normalized, tag, invalid_method(normalized), u => build_go(T, tail, 1n+index), invalid_checked(normalized), build_go_valid(T, tail, 1n+index))

def certify(-T: Data, result: Result<&2, &2, BuildError, Table(T)>, good: {BuildValid(T, result) == True{} : Bool}) -> Result<&2, &2, BuildError, Valid<T>>:
  match result:
    case Fail{error}: Fail{error}
    case Done{table}: Done{Valid{table, good}}

def build_table(-T: Data, +entries: List<&2, Registration(T)>) -> Result<&2, &2, BuildError, Valid<T>>:
  certify(T, build_go(T, entries, 0n), build_go_valid(T, entries, 0n))

# Strip terminal empty segments, retaining one segment for the root.
def trim_segments(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      [""]
    case "" <> tail:
      trim_segments(tail)
    case h <> tail:
      h <> tail

def slash_segments(xs: List<&2, String>, strict: Bool) -> List<&2, String>:
  match strict:
    case True{}:
      xs
    case False{}:
      List.reverse(&2, String, trim_segments(List.reverse(&2, String, xs)))

def fold_static(raw: String, sensitive: Bool) -> String:
  match sensitive:
    case True{}:
      raw
    case False{}:
      B.fold(raw)

# Fold only path positions occupied by static segments; never captures.
def adapt_segments(segs: List<&2, P.Segment>, paths: List<&2, String>, +sensitive: Bool) -> List<&2, String>:
  match segs paths:
    case P.Static{raw} <> rest h <> tail:
      fold_static(h, sensitive) <> adapt_segments(rest, tail, sensitive)
    case P.Capture{name, c, optional} <> rest h <> tail:
      h <> adapt_segments(rest, tail, sensitive)
    case _ ps:
      ps

def pattern_segments(segs: List<&2, P.Segment>, +sensitive: Bool) -> List<&2, P.Segment>:
  match segs:
    case Nil{}:
      Nil{}
    case P.Static{raw} <> rest:
      P.Static{fold_static(raw, sensitive)} <> pattern_segments(rest, sensitive)
    case h <> rest:
      h <> pattern_segments(rest, sensitive)

def trim_pattern_rev(segs: List<&2, P.Segment>) -> List<&2, P.Segment>:
  match segs:
    case Nil{}:
      [P.Static{""}]
    case P.Static{""} <> tail:
      trim_pattern_rev(tail)
    case h <> tail:
      h <> tail

def slash_pattern(segs: List<&2, P.Segment>, strict: Bool) -> List<&2, P.Segment>:
  match strict:
    case True{}:
      segs
    case False{}:
      List.reverse(&2, P.Segment, trim_pattern_rev(List.reverse(&2, P.Segment, segs)))

def match_path(pattern: P.Pattern, path: String, opts: Options) -> Maybe<&2, P.Params>:
  match pattern path opts:
    case P.Pattern{segs} SCon{'/', tail} Options{+strict, +sensitive}:
      +normalized = slash_pattern(segs, strict)
      P.match_path(P.Pattern{pattern_segments(normalized, sensitive)}, "/" ++ String.join(adapt_segments(normalized, slash_segments(P.path_segments(tail), strict), sensitive), "/"))
    case _ _ _:
      None{}

def contains(methods: List<&2, R.Method>, +method: R.Method) -> Bool:
  match methods:
    case Nil{}:
      False{}
    case h <> tail:
      String.eq(R.method_text(h), R.method_text(method)) || contains(tail, method)

def eligible(methods: List<&2, R.Method>, method: R.Method, hit: Maybe<&2, P.Params>) -> Maybe<&2, P.Params>:
  E.choose(Maybe<&2, P.Params>, contains(methods, method), u => hit, u => None{})

def select(-T: Data, tag: T, hit: Maybe<&2, P.Params>, rest: Unit -> Maybe<&2, S.Match<T>>) -> Maybe<&2, S.Match<T>>:
  S.select(T, tag, hit, rest)

def find(-T: Data, table: Table(T), +path: String, +method: R.Method, +opts: Options) -> Maybe<&2, S.Match<T>>:
  match table:
    case Nil{}:
      None{}
    case S.Route{pattern, Binding{methods, tag}} <> +tail:
      select(T, tag, eligible(methods, method, match_path(pattern, path, opts)), u => find(T, tail, path, method, opts))

# Sorted token set: standards have fixed rank, extensions follow lexically.
def rank(m: R.Method) -> U32:
  match m:
    case R.Get{}: 0
    case R.Head{}: 1
    case R.Post{}: 2
    case R.Put{}: 3
    case R.Delete{}: 4
    case R.Connect{}: 5
    case R.Options{}: 6
    case R.Trace{}: 7
    case R.Patch{}: 8
    case R.Extension{token}: 9

def before(+a: R.Method, +b: R.Method) -> Bool:
  (rank(a) < rank(b) : U32) || (U32.is_eq(rank(a), rank(b)) && String.is_lt(R.method_text(a), R.method_text(b)))

# Keep set membership separate from position insertion. The guard makes
# duplicate exclusion independent of the ordering invariant.
def insert_new(+m: R.Method, xs: List<&2, R.Method>) -> List<&2, R.Method>:
  match xs:
    case Nil{}:
      [m]
    case +h <> +tail:
      E.choose(List<&2, R.Method>, before(m, h), u => m <> h <> tail, u => h <> insert_new(m, tail))

def insert(+m: R.Method, +xs: List<&2, R.Method>) -> List<&2, R.Method>:
  E.choose(List<&2, R.Method>, contains(xs, m), u => xs, u => insert_new(m, xs))

def canonical(xs: List<&2, R.Method>) -> List<&2, R.Method>:
  match xs:
    case Nil{}:
      Nil{}
    case +h <> tail:
      +rest = insert(h, canonical(tail))
      E.choose(List<&2, R.Method>, String.eq(R.method_text(h), "GET"), u => insert(R.Head{}, rest), u => rest)

def matching_methods(-T: Data, table: Table(T), +path: String, +opts: Options) -> List<&2, R.Method>:
  match table:
    case Nil{}:
      Nil{}
    case S.Route{pattern, Binding{methods, tag}} <> +tail:
      E.choose(List<&2, R.Method>, Maybe.is_some(&2, P.Params, match_path(pattern, path, opts)), u => List.append(&2, R.Method, methods, matching_methods(T, tail, path, opts)), u => matching_methods(T, tail, path, opts))

def path_exists(-T: Data, table: Table(T), +path: String, +opts: Options) -> Bool:
  match table:
    case Nil{}:
      False{}
    case S.Route{pattern, binding} <> tail:
      Maybe.is_some(&2, P.Params, match_path(pattern, path, opts)) || path_exists(T, tail, path, opts)

def miss(-T: Data, exists: Bool, allow: List<&2, R.Method>) -> Resolution<T>:
  match exists:
    case True{}:
      MethodNotAllowed{allow}
    case False{}:
      NotFound{}

def fallback(-T: Data, hit: Maybe<&2, S.Match<T>>, rest: Unit -> Resolution<T>) -> Resolution<T>:
  match hit:
    case Some{hit}:
      Found{hit, True{}}
    case None{}:
      rest(Unit{})

def resolve_direct(-T: Data, hit: Maybe<&2, S.Match<T>>, +table: Table(T), +path: String, method: R.Method, +opts: Options) -> Resolution<T>:
  match hit:
    case Some{hit}:
      Found{hit, False{}}
    case None{}:
      match method:
        case R.Head{}:
          fallback(T, find(T, table, path, R.Get{}, opts), u => miss(T, path_exists(T, table, path, opts), canonical(matching_methods(T, table, path, opts))))
        case _:
          miss(T, path_exists(T, table, path, opts), canonical(matching_methods(T, table, path, opts)))

def resolve(-T: Data, valid: Valid<T>, +path: String, +method: R.Method, +opts: Options) -> Resolution<T>:
  Valid{+table, ok} = valid
  resolve_direct(T, find(T, table, path, method, opts), table, path, method, opts)

def allow_text(xs: List<&2, R.Method>) -> String:
  match xs:
    case Nil{}:
      ""
    case h <> Nil{}:
      R.method_text(h)
    case h <> tail:
      R.method_text(h) ++ ", " ++ allow_text(tail)

# BND-17: resolution through the configured router. The trie supplies the
# ordered path-matching candidates; direct hits stop at the first match.

# A validated table with its trie, built once at startup.
type Index<-T: Data> is Data:
  Index{valid: Valid<T>, trie: Tr.Trie<Binding<T>>}

def prepare(-T: Data, +valid: Valid<T>) -> Index<T>:
  Index{valid, Tr.build_trie(Binding<T>, raw(T, valid))}

def index_valid(-T: Data, index: Index<T>) -> Valid<T>:
  Index{valid, trie} = index
  valid

# Every registration that matches the path, ascending by index.
def hits(-T: Data, entries: List<&2, Tr.Candidate<Binding<T>>>, +path: String, +opts: Options) -> List<&2, S.Match<Binding<T>>>:
  match entries:
    case Nil{}:
      Nil{}
    case Tr.Candidate{index, S.Route{pattern, binding}} <> rest:
      Tr.keep(Binding<T>, index, binding, match_path(pattern, path, opts), hits(T, rest, path, opts))

# The first hit allowing `method`; the proof's reference for first_direct.
def first_allowed(-T: Data, xs: List<&2, S.Match<Binding<T>>>, +method: R.Method) -> Maybe<&2, S.Match<T>>:
  match xs:
    case Nil{}:
      None{}
    case S.Match{index, Binding{methods, tag}, params} <> rest:
      E.choose(Maybe<&2, S.Match<T>>, contains(methods, method), u => Some{S.Match{index, tag, params}}, u => first_allowed(T, rest, method))

def any_hit(-T: Data, xs: List<&2, S.Match<Binding<T>>>) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case h <> rest:
      True{}

def hit_methods(-T: Data, xs: List<&2, S.Match<Binding<T>>>) -> List<&2, R.Method>:
  match xs:
    case Nil{}:
      Nil{}
    case S.Match{index, Binding{methods, tag}, params} <> rest:
      List.append(&2, R.Method, methods, hit_methods(T, rest))

# The first candidate allowing `method` whose pattern matches; later
# candidates are never evaluated, as in find.
def first_direct(-T: Data, entries: List<&2, Tr.Candidate<Binding<T>>>, +path: String, +method: R.Method, +opts: Options) -> Maybe<&2, S.Match<T>>:
  match entries:
    case Nil{}:
      None{}
    case Tr.Candidate{index, S.Route{pattern, Binding{methods, tag}}} <> rest:
      Tr.candidate_hit(T, index, tag, eligible(methods, method, match_path(pattern, path, opts)), u => first_direct(T, rest, path, method, opts))

# Existence and Allow read one matching list, built only after a direct miss.
def miss_hits(-T: Data, +xs: List<&2, S.Match<Binding<T>>>) -> Resolution<T>:
  miss(T, any_hit(T, xs), canonical(hit_methods(T, xs)))

# The same decisions as resolve_direct, read from the ordered candidates.
def decide(-T: Data, hit: Maybe<&2, S.Match<T>>, +entries: List<&2, Tr.Candidate<Binding<T>>>, +path: String, method: R.Method, +opts: Options) -> Resolution<T>:
  match hit:
    case Some{hit}:
      Found{hit, False{}}
    case None{}:
      match method:
        case R.Head{}:
          fallback(T, first_direct(T, entries, path, R.Get{}, opts), u => miss_hits(T, hits(T, entries, path, opts)))
        case _:
          miss_hits(T, hits(T, entries, path, opts))

def resolve_entries(-T: Data, +entries: List<&2, Tr.Candidate<Binding<T>>>, +path: String, +method: R.Method, +opts: Options) -> Resolution<T>:
  decide(T, first_direct(T, entries, path, method, opts), entries, path, method, opts)

# The trie indexes raw static segments, so it prefilters only the default
# strict, case-sensitive options. Other options scan every registration.
def entries(-T: Data, valid: Valid<T>, trie: Tr.Trie<Binding<T>>, +path: String, opts: Options) -> List<&2, Tr.Candidate<Binding<T>>>:
  match opts:
    case Options{True{}, True{}}:
      Tr.candidates(Binding<T>, trie, path)
    case _:
      Tr.indexed(Binding<T>, raw(T, valid), 0n)

def resolve_with(-T: Data, kind: Router.RouterKind, index: Index<T>, +path: String, +method: R.Method, +opts: Options) -> Resolution<T>:
  match kind index:
    case Router.Spec{} Index{valid, trie}:
      resolve(T, valid, path, method, opts)
    case Router.Trie{} Index{valid, trie}:
      resolve_entries(T, entries(T, valid, trie, path, opts), path, method, opts)
