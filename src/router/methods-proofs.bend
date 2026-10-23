# Independent indexed specification and constructive first-match proofs.
import Base
import ./spec.bend as R
import ./methods.bend as M
import ../http/request.bend as H
import ./pattern.bend as P
import ./proofs.bend as Core
import ./encoding.bend as E
import ./compile-proofs.bend as CP
import ./equality-proofs.bend as Eq
import ./methods-order-proofs.bend as O
import ./methods-set-proofs.bend as Set

# Token membership and indexed eligibility are independent of find/resolve.
def member(methods: List<&2, H.Method>, +method: H.Method) -> Bool:
  match methods:
    case Nil{}:
      False{}
    case h <> tail:
      String.eq(H.method_text(h), H.method_text(method)) || member(tail, method)

def membership(methods: List<&2, H.Method>, +method: H.Method) -> {M.contains(methods, method) == member(methods, method) : Bool}:
  match methods:
    case Nil{}:
      {==}
    case +h <> tail:
      Equal.cong(Bool, Bool, x => String.eq(H.method_text(h), H.method_text(method)) || x, M.contains(tail, method), member(tail, method), membership(tail, method))

type AtMatch<-T: Data> is Data:
  At{tag: T, params: P.Params}

# Neither indexed lookup nor the first-match predicate calls the router.
def entry_match(-T: Data, tag: T, hit: Maybe<&2, P.Params>) -> Maybe<&2, AtMatch<T>>:
  match hit:
    case None{}:
      None{}
    case Some{ps}:
      Some{At{tag, ps}}

def lookup_match(-T: Data, entry: Maybe<&2, R.Route<M.Binding<T>>>, path: String, +method: H.Method, +opts: M.Options) -> Maybe<&2, AtMatch<T>>:
  match entry:
    case None{}:
      None{}
    case Some{R.Route{pattern, M.Binding{methods, tag}}}:
      entry_match(T, tag, E.choose(Maybe<&2, P.Params>, M.contains(methods, method), u => M.match_path(pattern, path, opts), u => None{}))

def match_at(-T: Data, table: M.Table(T), path: String, +method: H.Method, +opts: M.Options, i: Nat) -> Maybe<&2, AtMatch<T>>:
  lookup_match(T, List.get(&2, R.Route<M.Binding<T>>, table, i), path, method, opts)

def NoEarlier(-T: Data, +table: M.Table(T), +path: String, +method: H.Method, +opts: M.Options, +i: Nat) -> Type:
  @j: Nat -> {Nat.is_lt(j, i) == True{} : Bool} ->
    {match_at(T, table, path, method, opts, j) == None{} : Maybe<&2, AtMatch<T>>}

def First(-T: Data, +table: M.Table(T), +path: String, +method: H.Method, +opts: M.Options, +i: Nat, +tag: T, +ps: P.Params) -> Type:
  {match_at(T, table, path, method, opts, i) == Some{At{tag, ps}} : Maybe<&2, AtMatch<T>>} & NoEarlier(T, table, path, method, opts, i)

def Outcome(-T: Data, +table: M.Table(T), +path: String, +method: H.Method, +opts: M.Options, hit: Maybe<&2, R.Match<T>>) -> Type:
  match hit:
    case None{}:
      @i: Nat -> {match_at(T, table, path, method, opts, i) == None{} : Maybe<&2, AtMatch<T>>}
    case Some{R.Match{i, tag, ps}}:
      First(T, table, path, method, opts, i, tag, ps)

def index(-T: Data, hit: R.Match<T>) -> Nat:
  R.Match{i, tag, ps} = hit
  i

def some_test(-A: Data, x: Maybe<&2, A>) -> Bool:
  match x:
    case None{}:
      False{}
    case Some{v}:
      True{}

def none_some(-A: Data, +v: A, e: {None{} == Some{v} : Maybe<&2, A>}) -> Empty:
  Core.false_true(Equal.cong(Maybe<&2, A>, Bool, x => some_test(A, x), None{}, Some{v}, e))

def no_before_zero(-T: Data, +table: M.Table(T), +path: String, +method: H.Method, +opts: M.Options, j: Nat,
    lt: {Nat.is_lt(j, 0n) == True{} : Bool}) ->
    {match_at(T, table, path, method, opts, j) == None{} : Maybe<&2, AtMatch<T>>}:
  match j:
    case 0n:
      Core.absurd({match_at(T, table, path, method, opts, 0n) == None{} : Maybe<&2, AtMatch<T>>}, Core.false_true(lt))
    case 1n+p:
      Core.absurd({match_at(T, table, path, method, opts, 1n+p) == None{} : Maybe<&2, AtMatch<T>>}, Core.false_true(lt))

def cons_none(-T: Data, +pattern: P.Pattern, +methods: List<&2, H.Method>, +tag: T, +tail: M.Table(T), +path: String, +method: H.Method, +opts: M.Options,
    +head_miss: {M.eligible(methods, method, M.match_path(pattern, path, opts)) == None{} : Maybe<&2, P.Params>},
    misses: @i: Nat -> {match_at(T, tail, path, method, opts, i) == None{} : Maybe<&2, AtMatch<T>>}, i: Nat) ->
    {match_at(T, R.Route{pattern, M.Binding{methods, tag}} <> tail, path, method, opts, i) == None{} : Maybe<&2, AtMatch<T>>}:
  match i:
    case 0n:
      Equal.cong(Maybe<&2, P.Params>, Maybe<&2, AtMatch<T>>, x => entry_match(T, tag, x), M.eligible(methods, method, M.match_path(pattern, path, opts)), None{}, head_miss)
    case 1n+p:
      misses(p)

def cons_earlier(-T: Data, +pattern: P.Pattern, +methods: List<&2, H.Method>, +tag: T, +tail: M.Table(T), +path: String, +method: H.Method, +opts: M.Options, +i: Nat,
    +head_miss: {M.eligible(methods, method, M.match_path(pattern, path, opts)) == None{} : Maybe<&2, P.Params>},
    earlier: NoEarlier(T, tail, path, method, opts, i), j: Nat,
    lt: {Nat.is_lt(j, 1n+i) == True{} : Bool}) ->
    {match_at(T, R.Route{pattern, M.Binding{methods, tag}} <> tail, path, method, opts, j) == None{} : Maybe<&2, AtMatch<T>>}:
  match j:
    case 0n:
      Equal.cong(Maybe<&2, P.Params>, Maybe<&2, AtMatch<T>>, x => entry_match(T, tag, x), M.eligible(methods, method, M.match_path(pattern, path, opts)), None{}, head_miss)
    case 1n+p:
      earlier(p, lt)

def select_correct(-T: Data, +pattern: P.Pattern, +methods: List<&2, H.Method>, +tag: T, +tail: M.Table(T), +path: String, +method: H.Method, +opts: M.Options,
    +head: Maybe<&2, P.Params>, +rest: Maybe<&2, R.Match<T>>,
    +head_eq: {M.eligible(methods, method, M.match_path(pattern, path, opts)) == head : Maybe<&2, P.Params>},
    correct: Outcome(T, tail, path, method, opts, rest)) ->
    Outcome(T, R.Route{pattern, M.Binding{methods, tag}} <> tail, path, method, opts, R.select(T, tag, head, u => rest)):
  match head rest:
    case Some{+ps} r:
      (Equal.cong(Maybe<&2, P.Params>, Maybe<&2, AtMatch<T>>, x => entry_match(T, tag, x), M.eligible(methods, method, M.match_path(pattern, path, opts)), Some{ps}, head_eq), j => lt => no_before_zero(T, R.Route{pattern, M.Binding{methods, tag}} <> tail, path, method, opts, j, lt))
    case None{} None{}:
      i => cons_none(T, pattern, methods, tag, tail, path, method, opts, head_eq, correct, i)
    case None{} Some{R.Match{+i, +other_tag, +ps}}:
      (found, earlier) = correct
      (found, j => lt => cons_earlier(T, pattern, methods, tag, tail, path, method, opts, i, head_eq, earlier, j, lt))

def route_correct(-T: Data, +table: M.Table(T), +path: String, +method: H.Method, +opts: M.Options) -> Outcome(T, table, path, method, opts, M.find(T, table, path, method, opts)):
  match table:
    case Nil{}:
      i => {==}
    case R.Route{+pattern, M.Binding{+methods, +tag}} <> +tail:
      select_correct(T, pattern, methods, tag, tail, path, method, opts, M.eligible(methods, method, M.match_path(pattern, path, opts)), M.find(T, tail, path, method, opts), {==}, route_correct(T, tail, path, method, opts))

# A recursive conjunction quantifies over every entry, even empty method lists.
def NoPaths(-T: Data, table: M.Table(T), +path: String, +opts: M.Options) -> Type:
  match table:
    case Nil{}:
      Unit
    case R.Route{pattern, binding} <> tail:
      {M.match_path(pattern, path, opts) == None{} : Maybe<&2, P.Params>} & NoPaths(T, tail, path, opts)

def paths_false_step(-T: Data, +pattern: P.Pattern, +binding: M.Binding<T>, +tail: M.Table(T), +path: String, +opts: M.Options,
    +hit: Maybe<&2, P.Params>,
    +eq: {M.match_path(pattern, path, opts) == hit : Maybe<&2, P.Params>},
    recurse: {M.path_exists(T, tail, path, opts) == False{} : Bool} -> NoPaths(T, tail, path, opts),
    no: {Maybe.is_some(&2, P.Params, hit) || M.path_exists(T, tail, path, opts) == False{} : Bool}) ->
    NoPaths(T, R.Route{pattern, binding} <> tail, path, opts):
  match hit:
    case None{}:
      (eq, recurse(no))
    case Some{ps}:
      Core.absurd(NoPaths(T, R.Route{pattern, binding} <> tail, path, opts), Core.false_true(Equal.sym(Bool, True{}, False{}, no)))

def paths_false(-T: Data, +table: M.Table(T), +path: String, +opts: M.Options,
    no: {M.path_exists(T, table, path, opts) == False{} : Bool}) -> NoPaths(T, table, path, opts):
  match table:
    case Nil{}:
      Unit{}
    case R.Route{+pattern, +binding} <> +tail:
      paths_false_step(T, pattern, binding, tail, path, opts, M.match_path(pattern, path, opts), {==}, e => paths_false(T, tail, path, opts, e), no)

def paths_none(-T: Data, +table: M.Table(T), +path: String, +opts: M.Options, no: NoPaths(T, table, path, opts)) ->
    {M.path_exists(T, table, path, opts) == False{} : Bool}:
  match table:
    case Nil{}:
      {==}
    case R.Route{+pattern, binding} <> +tail:
      (head, rest) = no
      %Equal.sym(Maybe<&2, P.Params>, M.match_path(pattern, path, opts), None{}, head) : {Maybe.is_some(&2, P.Params, _) || M.path_exists(T, tail, path, opts) == False{} : Bool}
      paths_none(T, tail, path, opts, rest)

def choose_none(test: Bool) ->
    {E.choose(Maybe<&2, P.Params>, test, u => None{}, u => None{}) == None{} : Maybe<&2, P.Params>}:
  match test:
    case True{}:
      {==}
    case False{}:
      {==}

def find_none(-T: Data, +table: M.Table(T), +path: String, +method: H.Method, +opts: M.Options, no: NoPaths(T, table, path, opts)) ->
    {M.find(T, table, path, method, opts) == None{} : Maybe<&2, R.Match<T>>}:
  match table:
    case Nil{}:
      {==}
    case R.Route{+pattern, M.Binding{+methods, +tag}} <> +tail:
      (head, rest) = no
      %Equal.sym(Maybe<&2, P.Params>, M.match_path(pattern, path, opts), None{}, head) : {M.select(T, tag, M.eligible(methods, method, _), u => M.find(T, tail, path, method, opts)) == None{} : Maybe<&2, R.Match<T>>}
      %Equal.sym(Maybe<&2, P.Params>, M.eligible(methods, method, None{}), None{}, choose_none(M.contains(methods, method))) : {M.select(T, tag, _, u => M.find(T, tail, path, method, opts)) == None{} : Maybe<&2, R.Match<T>>}
      Equal.cong(Maybe<&2, R.Match<T>>, Maybe<&2, R.Match<T>>, x => R.bump(T, x), M.find(T, tail, path, method, opts), None{}, find_none(T, tail, path, method, opts, rest))
# This collection reads every matching registration, not just the winning one.
def path_methods(-T: Data, table: M.Table(T), +path: String, +opts: M.Options) -> List<&2, H.Method>:
  match table:
    case Nil{}:
      Nil{}
    case R.Route{pattern, M.Binding{methods, tag}} <> +tail:
      E.choose(List<&2, H.Method>, Maybe.is_some(&2, P.Params, M.match_path(pattern, path, opts)), u => List.append(&2, H.Method, methods, path_methods(T, tail, path, opts)), u => path_methods(T, tail, path, opts))

def collection(-T: Data, +table: M.Table(T), +path: String, +opts: M.Options) ->
    {M.matching_methods(T, table, path, opts) == path_methods(T, table, path, opts) : List<&2, H.Method>}:
  match table:
    case Nil{}:
      {==}
    case R.Route{+pattern, M.Binding{+methods, tag}} <> +tail:
      Equal.cong(List<&2, H.Method>, List<&2, H.Method>, xs => E.choose(List<&2, H.Method>, Maybe.is_some(&2, P.Params, M.match_path(pattern, path, opts)), u => List.append(&2, H.Method, methods, xs), u => xs), M.matching_methods(T, tail, path, opts), path_methods(T, tail, path, opts), collection(T, tail, path, opts))

def Misses(-T: Data, +table: M.Table(T), +path: String, +method: H.Method, +opts: M.Options) -> Type:
  @i: Nat -> {match_at(T, table, path, method, opts, i) == None{} : Maybe<&2, AtMatch<T>>}

def HeadNone(-T: Data, +table: M.Table(T), +path: String, method: H.Method, +opts: M.Options) -> Type:
  match method:
    case H.Head{}:
      {M.find(T, table, path, H.Get{}, opts) == None{} : Maybe<&2, R.Match<T>>}
    case _:
      Unit

def ResolutionCorrect(-T: Data, +table: M.Table(T), +path: String, +method: H.Method, +opts: M.Options, result: M.Resolution<T>) -> Type:
  match result:
    case M.Found{R.Match{i, tag, ps}, False{}}:
      First(T, table, path, method, opts, i, tag, ps)
    case M.Found{R.Match{i, tag, ps}, True{}}:
      {method == H.Head{} : H.Method} & (Misses(T, table, path, H.Head{}, opts) & First(T, table, path, H.Get{}, opts, i, tag, ps))
    case M.NotFound{}:
      NoPaths(T, table, path, opts)
    case M.MethodNotAllowed{allow}:
      {M.path_exists(T, table, path, opts) == True{} : Bool} &
        ({allow == M.canonical(path_methods(T, table, path, opts)) : List<&2, H.Method>} &
        ({M.find(T, table, path, method, opts) == None{} : Maybe<&2, R.Match<T>>} & HeadNone(T, table, path, method, opts)))

def miss_correct(-T: Data, +table: M.Table(T), +path: String, +method: H.Method, +opts: M.Options, exists: Bool,
    eq: {M.path_exists(T, table, path, opts) == exists : Bool},
    direct: {M.find(T, table, path, method, opts) == None{} : Maybe<&2, R.Match<T>>}, get: HeadNone(T, table, path, method, opts)) ->
    ResolutionCorrect(T, table, path, method, opts, M.miss(T, exists, M.canonical(M.matching_methods(T, table, path, opts)))):
  match exists:
    case False{}:
      paths_false(T, table, path, opts, eq)
    case True{}:
      (eq, (Equal.cong(List<&2, H.Method>, List<&2, H.Method>, xs => M.canonical(xs), M.matching_methods(T, table, path, opts), path_methods(T, table, path, opts), collection(T, table, path, opts)), (direct, get)))

def fallback_correct(-T: Data, +table: M.Table(T), +path: String, +opts: M.Options, hit: Maybe<&2, R.Match<T>>,
    +direct: {M.find(T, table, path, H.Head{}, opts) == None{} : Maybe<&2, R.Match<T>>},
    eq: {M.find(T, table, path, H.Get{}, opts) == hit : Maybe<&2, R.Match<T>>}, get: Outcome(T, table, path, H.Get{}, opts, hit)) ->
    ResolutionCorrect(T, table, path, H.Head{}, opts, M.fallback(T, hit, u => M.miss(T, M.path_exists(T, table, path, opts), M.canonical(M.matching_methods(T, table, path, opts))))):
  match hit:
    case Some{R.Match{i, tag, ps}}:
      ({==}, ((%direct : Outcome(T, table, path, H.Head{}, opts, _); route_correct(T, table, path, H.Head{}, opts)), get))
    case None{}:
      miss_correct(T, table, path, H.Head{}, opts, M.path_exists(T, table, path, opts), {==}, direct, eq)

def resolve_correct_direct(-T: Data, +table: M.Table(T), +path: String, +opts: M.Options, hit: Maybe<&2, R.Match<T>>, +method: H.Method,
    +eq: {M.find(T, table, path, method, opts) == hit : Maybe<&2, R.Match<T>>},
    direct: Outcome(T, table, path, method, opts, hit)) ->
    ResolutionCorrect(T, table, path, method, opts, M.resolve_direct(T, hit, table, path, method, opts)):
  match hit:
    case Some{R.Match{i, tag, ps}}:
      direct
    case None{}:
      match method:
        case H.Head{}:
          fallback_correct(T, table, path, opts, M.find(T, table, path, H.Get{}, opts), eq, {==}, route_correct(T, table, path, H.Get{}, opts))
        case H.Get{}:
          miss_correct(T, table, path, H.Get{}, opts, M.path_exists(T, table, path, opts), {==}, eq, Unit{})
        case H.Post{}:
          miss_correct(T, table, path, H.Post{}, opts, M.path_exists(T, table, path, opts), {==}, eq, Unit{})
        case H.Put{}:
          miss_correct(T, table, path, H.Put{}, opts, M.path_exists(T, table, path, opts), {==}, eq, Unit{})
        case H.Delete{}:
          miss_correct(T, table, path, H.Delete{}, opts, M.path_exists(T, table, path, opts), {==}, eq, Unit{})
        case H.Connect{}:
          miss_correct(T, table, path, H.Connect{}, opts, M.path_exists(T, table, path, opts), {==}, eq, Unit{})
        case H.Options{}:
          miss_correct(T, table, path, H.Options{}, opts, M.path_exists(T, table, path, opts), {==}, eq, Unit{})
        case H.Trace{}:
          miss_correct(T, table, path, H.Trace{}, opts, M.path_exists(T, table, path, opts), {==}, eq, Unit{})
        case H.Patch{}:
          miss_correct(T, table, path, H.Patch{}, opts, M.path_exists(T, table, path, opts), {==}, eq, Unit{})
        case H.Extension{+token}:
          miss_correct(T, table, path, H.Extension{token}, opts, M.path_exists(T, table, path, opts), {==}, eq, Unit{})

def resolve_correct(-T: Data, +table: M.Table(T), +path: String, +method: H.Method, +opts: M.Options) ->
    ResolutionCorrect(T, table, path, method, opts, M.resolve(T, table, path, method, opts)):
  resolve_correct_direct(T, table, path, opts, M.find(T, table, path, method, opts), method, {==}, route_correct(T, table, path, method, opts))

def missing_direct(-T: Data, +table: M.Table(T), +path: String, +method: H.Method, +opts: M.Options, +no: {M.path_exists(T, table, path, opts) == False{} : Bool}) ->
    {M.resolve_direct(T, None{}, table, path, method, opts) == M.NotFound{} : M.Resolution<T>}:
  match method:
    case H.Head{}:
      %Equal.sym(Maybe<&2, R.Match<T>>, M.find(T, table, path, H.Get{}, opts), None{}, find_none(T, table, path, H.Get{}, opts, paths_false(T, table, path, opts, no))) : {M.fallback(T, _, u => M.miss(T, M.path_exists(T, table, path, opts), M.canonical(M.matching_methods(T, table, path, opts)))) == M.NotFound{} : M.Resolution<T>}
      Equal.cong(Bool, M.Resolution<T>, x => M.miss(T, x, M.canonical(M.matching_methods(T, table, path, opts))), M.path_exists(T, table, path, opts), False{}, no)
    case H.Get{}:
      Equal.cong(Bool, M.Resolution<T>, x => M.miss(T, x, M.canonical(M.matching_methods(T, table, path, opts))), M.path_exists(T, table, path, opts), False{}, no)
    case H.Post{}:
      Equal.cong(Bool, M.Resolution<T>, x => M.miss(T, x, M.canonical(M.matching_methods(T, table, path, opts))), M.path_exists(T, table, path, opts), False{}, no)
    case H.Put{}:
      Equal.cong(Bool, M.Resolution<T>, x => M.miss(T, x, M.canonical(M.matching_methods(T, table, path, opts))), M.path_exists(T, table, path, opts), False{}, no)
    case H.Delete{}:
      Equal.cong(Bool, M.Resolution<T>, x => M.miss(T, x, M.canonical(M.matching_methods(T, table, path, opts))), M.path_exists(T, table, path, opts), False{}, no)
    case H.Connect{}:
      Equal.cong(Bool, M.Resolution<T>, x => M.miss(T, x, M.canonical(M.matching_methods(T, table, path, opts))), M.path_exists(T, table, path, opts), False{}, no)
    case H.Options{}:
      Equal.cong(Bool, M.Resolution<T>, x => M.miss(T, x, M.canonical(M.matching_methods(T, table, path, opts))), M.path_exists(T, table, path, opts), False{}, no)
    case H.Trace{}:
      Equal.cong(Bool, M.Resolution<T>, x => M.miss(T, x, M.canonical(M.matching_methods(T, table, path, opts))), M.path_exists(T, table, path, opts), False{}, no)
    case H.Patch{}:
      Equal.cong(Bool, M.Resolution<T>, x => M.miss(T, x, M.canonical(M.matching_methods(T, table, path, opts))), M.path_exists(T, table, path, opts), False{}, no)
    case H.Extension{token}:
      Equal.cong(Bool, M.Resolution<T>, x => M.miss(T, x, M.canonical(M.matching_methods(T, table, path, opts))), M.path_exists(T, table, path, opts), False{}, no)

def not_found(-T: Data, +table: M.Table(T), +path: String, +method: H.Method, +opts: M.Options, no: NoPaths(T, table, path, opts)) ->
    {M.resolve(T, table, path, method, opts) == M.NotFound{} : M.Resolution<T>}:
  +absent = paths_none(T, table, path, opts, no)
  %Equal.sym(Maybe<&2, R.Match<T>>, M.find(T, table, path, method, opts), None{}, find_none(T, table, path, method, opts, paths_false(T, table, path, opts, absent))) : {M.resolve_direct(T, _, table, path, method, opts) == M.NotFound{} : M.Resolution<T>}
  missing_direct(T, table, path, method, opts, absent)

# With case sensitivity enabled the adapter preserves captures and statics.
def pattern_identity(+segs: List<&2, P.Segment>) ->
    {M.pattern_segments(segs, True{}) == segs : List<&2, P.Segment>}:
  match segs:
    case Nil{}:
      {==}
    case P.Static{+raw} <> +rest:
      Equal.cong(List<&2, P.Segment>, List<&2, P.Segment>, xs => P.Static{raw} <> xs, M.pattern_segments(rest, True{}), rest, pattern_identity(rest))
    case P.Capture{+name, +c, +optional} <> +rest:
      Equal.cong(List<&2, P.Segment>, List<&2, P.Segment>, xs => P.Capture{name, c, optional} <> xs, M.pattern_segments(rest, True{}), rest, pattern_identity(rest))
    case P.Wildcard{+name} <> +rest:
      Equal.cong(List<&2, P.Segment>, List<&2, P.Segment>, xs => P.Wildcard{name} <> xs, M.pattern_segments(rest, True{}), rest, pattern_identity(rest))

def adapt_identity(+segs: List<&2, P.Segment>, +paths: List<&2, String>) ->
    {M.adapt_segments(segs, paths, True{}) == paths : List<&2, String>}:
  match segs paths:
    case P.Static{raw} <> +rest +h <> +tail:
      Equal.cong(List<&2, String>, List<&2, String>, xs => h <> xs, M.adapt_segments(rest, tail, True{}), tail, adapt_identity(rest, tail))
    case P.Capture{name, c, optional} <> +rest +h <> +tail:
      Equal.cong(List<&2, String>, List<&2, String>, xs => h <> xs, M.adapt_segments(rest, tail, True{}), tail, adapt_identity(rest, tail))
    case Nil{} ps:
      {==}
    case P.Static{raw} <> rest Nil{}:
      {==}
    case P.Capture{name, c, optional} <> rest Nil{}:
      {==}
    case P.Wildcard{name} <> rest ps:
      {==}
def char_sound(+c: Char, yes: {Char.is_eq(c, '/') == True{} : Bool}) -> {c == '/' : Char}:
  match c:
    case Chr{+n}:
      Equal.cong(U32, Char, x => Chr{x}, n, 47, Eq.u32_cmp_sound(n, 47, yes))

def join_push(+c: Char, +xs: List<&2, String>, nonempty: {List.is_empty(&2, String, xs) == False{} : Bool}) ->
    {String.join(String.split.push(c, xs), "/") == SCon{c, String.join(xs, "/")} : String}:
  match xs:
    case Nil{}:
      Core.absurd({String.join(String.split.push(c, Nil{}), "/") == SCon{c, String.join(Nil{}, "/")} : String}, Core.false_true(Equal.sym(Bool, True{}, False{}, nonempty)))
    case h <> Nil{}:
      {==}
    case h <> other <> tail:
      {==}

def join_slash(+xs: List<&2, String>, nonempty: {List.is_empty(&2, String, xs) == False{} : Bool}) ->
    {String.join(SNil{} <> xs, "/") == SCon{'/', String.join(xs, "/")} : String}:
  match xs:
    case Nil{}:
      Core.absurd({String.join([""], "/") == SCon{'/', String.join(Nil{}, "/")} : String}, Core.false_true(Equal.sym(Bool, True{}, False{}, nonempty)))
    case h <> t:
      {==}

def join_cut(+c: Char, +xs: List<&2, String>, cut: Bool,
    eq: {Char.is_eq(c, '/') == cut : Bool}, nonempty: {List.is_empty(&2, String, xs) == False{} : Bool}) ->
    {String.join(String.split.fin(c, xs, cut), "/") == SCon{c, String.join(xs, "/")} : String}:
  match cut:
    case False{}:
      join_push(c, xs, nonempty)
    case True{}:
      %Equal.sym(Char, c, '/', char_sound(c, eq)) : {String.join(SNil{} <> xs, "/") == SCon{_, String.join(xs, "/")} : String}
      join_slash(xs, nonempty)

def join_split(+s: String) -> {String.join(P.path_segments(s), "/") == s : String}:
  match s:
    case SNil{}:
      {==}
    case SCon{+c, +tail}:
      Equal.trans(String, String.join(String.split.fin(c, P.path_segments(tail), Char.is_eq(c, '/')), "/"), SCon{c, String.join(P.path_segments(tail), "/")}, SCon{c, tail}, join_cut(c, P.path_segments(tail), Char.is_eq(c, '/'), {==}, CP.split_nonempty(tail)), Equal.cong(String, String, x => SCon{c, x}, String.join(P.path_segments(tail), "/"), tail, join_split(tail)))

def default_slash(+segs: List<&2, P.Segment>, +tail: String) ->
    {M.match_path(P.Pattern{segs}, SCon{'/', tail}, M.defaults()) == P.match_path(P.Pattern{segs}, SCon{'/', tail}) : Maybe<&2, P.Params>}:
  %Equal.sym(List<&2, P.Segment>, M.pattern_segments(segs, True{}), segs, pattern_identity(segs)) : {P.match_path(P.Pattern{_}, "/" ++ String.join(M.adapt_segments(segs, P.path_segments(tail), True{}), "/")) == P.match_path(P.Pattern{segs}, SCon{'/', tail}) : Maybe<&2, P.Params>}
  %Equal.sym(List<&2, String>, M.adapt_segments(segs, P.path_segments(tail), True{}), P.path_segments(tail), adapt_identity(segs, P.path_segments(tail))) : {P.match_path(P.Pattern{segs}, "/" ++ String.join(_, "/")) == P.match_path(P.Pattern{segs}, SCon{'/', tail}) : Maybe<&2, P.Params>}
  %Equal.sym(String, String.join(P.path_segments(tail), "/"), tail, join_split(tail)) : {P.match_path(P.Pattern{segs}, "/" ++ _) == P.match_path(P.Pattern{segs}, SCon{'/', tail}) : Maybe<&2, P.Params>}
  {==}

# Literal-prefix cases keep malformed/non-origin paths in the universal domain.
def default_path(+pattern: P.Pattern, +path: String) ->
    {M.match_path(pattern, path, M.defaults()) == P.match_path(pattern, path) : Maybe<&2, P.Params>}:
  match pattern path:
    case P.Pattern{+segs} SCon{'/', +tail}:
      default_slash(segs, tail)
    case P.Pattern{Nil{}} SNil{}:
      {==}
    case P.Pattern{Nil{}} SCon{Chr{U32{WCon{False{}, remaining}}}, tail}:
      {==}
    case P.Pattern{Nil{}} SCon{Chr{U32{WCon{True{}, WCon{False{}, remaining}}}}, tail}:
      {==}
    case P.Pattern{Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{False{}, remaining}}}}}, tail}:
      {==}
    case P.Pattern{Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, remaining}}}}}}, tail}:
      {==}
    case P.Pattern{Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, remaining}}}}}}}, tail}:
      {==}
    case P.Pattern{Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, remaining}}}}}}}}, tail}:
      {==}
    case P.Pattern{Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, remaining}}}}}}}}}, tail}:
      {==}
    case P.Pattern{Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Static{raw} <> rest} SNil{}:
      {==}
    case P.Pattern{P.Static{raw} <> rest} SCon{Chr{U32{WCon{False{}, remaining}}}, tail}:
      {==}
    case P.Pattern{P.Static{raw} <> rest} SCon{Chr{U32{WCon{True{}, WCon{False{}, remaining}}}}, tail}:
      {==}
    case P.Pattern{P.Static{raw} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{False{}, remaining}}}}}, tail}:
      {==}
    case P.Pattern{P.Static{raw} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, remaining}}}}}}, tail}:
      {==}
    case P.Pattern{P.Static{raw} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, remaining}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Static{raw} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, remaining}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Static{raw} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, remaining}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Static{raw} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Static{raw} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Static{raw} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Static{raw} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Static{raw} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Static{raw} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Static{raw} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Static{raw} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Static{raw} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Static{raw} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Static{raw} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Static{raw} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Static{raw} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Static{raw} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Static{raw} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Static{raw} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Static{raw} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Static{raw} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Static{raw} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Static{raw} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Static{raw} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Static{raw} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Static{raw} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Static{raw} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Static{raw} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Wildcard{name} <> rest} SNil{}:
      {==}
    case P.Pattern{P.Wildcard{name} <> rest} SCon{Chr{U32{WCon{False{}, remaining}}}, tail}:
      {==}
    case P.Pattern{P.Wildcard{name} <> rest} SCon{Chr{U32{WCon{True{}, WCon{False{}, remaining}}}}, tail}:
      {==}
    case P.Pattern{P.Wildcard{name} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{False{}, remaining}}}}}, tail}:
      {==}
    case P.Pattern{P.Wildcard{name} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, remaining}}}}}}, tail}:
      {==}
    case P.Pattern{P.Wildcard{name} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, remaining}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Wildcard{name} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, remaining}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Wildcard{name} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, remaining}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Wildcard{name} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Wildcard{name} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Wildcard{name} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Wildcard{name} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Wildcard{name} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Wildcard{name} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Wildcard{name} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Wildcard{name} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Wildcard{name} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Wildcard{name} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Wildcard{name} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Wildcard{name} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Wildcard{name} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Wildcard{name} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Wildcard{name} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Wildcard{name} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Wildcard{name} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Wildcard{name} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Wildcard{name} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Wildcard{name} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Wildcard{name} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Wildcard{name} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Wildcard{name} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Wildcard{name} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Wildcard{name} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, False{}} <> rest} SNil{}:
      {==}
    case P.Pattern{P.Capture{name, c, False{}} <> rest} SCon{Chr{U32{WCon{False{}, remaining}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, False{}} <> rest} SCon{Chr{U32{WCon{True{}, WCon{False{}, remaining}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, False{}} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{False{}, remaining}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, False{}} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, remaining}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, False{}} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, remaining}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, False{}} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, remaining}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, False{}} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, remaining}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, False{}} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, False{}} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, False{}} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, False{}} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, False{}} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, False{}} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, False{}} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, False{}} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, False{}} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, False{}} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, False{}} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, False{}} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, False{}} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, False{}} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, False{}} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, False{}} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, False{}} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, False{}} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, False{}} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, False{}} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, False{}} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, False{}} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, False{}} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, False{}} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, False{}} <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> Nil{}} SNil{}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> Nil{}} SCon{Chr{U32{WCon{False{}, remaining}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> Nil{}} SCon{Chr{U32{WCon{True{}, WCon{False{}, remaining}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{False{}, remaining}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, remaining}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, remaining}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, remaining}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, remaining}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> Nil{}} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> h <> rest} SNil{}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> h <> rest} SCon{Chr{U32{WCon{False{}, remaining}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> h <> rest} SCon{Chr{U32{WCon{True{}, WCon{False{}, remaining}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> h <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{False{}, remaining}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> h <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, remaining}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> h <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, remaining}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> h <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, remaining}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> h <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, remaining}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> h <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> h <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> h <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> h <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> h <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> h <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> h <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> h <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> h <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> h <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> h <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> h <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> h <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> h <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> h <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> h <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> h <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> h <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> h <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> h <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> h <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> h <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> h <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> h <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
    case P.Pattern{P.Capture{name, c, True{}} <> h <> rest} SCon{Chr{U32{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, remaining}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}, tail}:
      {==}
def absent_step(-T: Data, +tag: T, +methods: List<&2, H.Method>, +method: H.Method, +rest: List<&2, H.Method>, hit: Maybe<&2, P.Params>, contains: Bool,
    eq: {M.contains(methods, method) == contains : Bool},
    none: {entry_match(T, tag, E.choose(Maybe<&2, P.Params>, contains, u => hit, u => None{})) == None{} : Maybe<&2, AtMatch<T>>},
    tail: {O.member(rest, method) == False{} : Bool}) ->
    {O.member(E.choose(List<&2, H.Method>, Maybe.is_some(&2, P.Params, hit), u => List.append(&2, H.Method, methods, rest), u => rest), method) == False{} : Bool}:
  match hit contains:
    case None{} c:
      tail
    case Some{ps} True{}:
      Core.absurd({O.member(List.append(&2, H.Method, methods, rest), method) == False{} : Bool}, none_some(AtMatch<T>, At{tag, ps}, Equal.sym(Maybe<&2, AtMatch<T>>, Some{At{tag, ps}}, None{}, none)))
    case Some{ps} False{}:
      %Equal.sym(Bool, O.member(List.append(&2, H.Method, methods, rest), method), O.member(methods, method) || O.member(rest, method), O.member_append(methods, rest, method)) : {_ == False{} : Bool}
      %Equal.sym(Bool, O.member(methods, method), False{}, Equal.trans(Bool, O.member(methods, method), M.contains(methods, method), False{}, Equal.sym(Bool, M.contains(methods, method), O.member(methods, method), O.member_contains(methods, method)), eq)) : {_ || O.member(rest, method) == False{} : Bool}
      tail

def find_misses(-T: Data, +table: M.Table(T), +path: String, +method: H.Method, +opts: M.Options,
    none: {M.find(T, table, path, method, opts) == None{} : Maybe<&2, R.Match<T>>}) -> Misses(T, table, path, method, opts):
  %none : Outcome(T, table, path, method, opts, _)
  route_correct(T, table, path, method, opts)

def selected_none_tail(-T: Data, +tag: T, +head: Maybe<&2, P.Params>, +rest: Maybe<&2, R.Match<T>>,
    none: {M.select(T, tag, head, u => rest) == None{} : Maybe<&2, R.Match<T>>}) -> {rest == None{} : Maybe<&2, R.Match<T>>}:
  match head rest:
    case None{} None{}: {==}
    case None{} Some{R.Match{+i, +other, +ps}}:
      Core.absurd({Some{R.Match{i, other, ps}} == None{} : Maybe<&2, R.Match<T>>}, none_some(R.Match<T>, R.Match{1n+i, other, ps}, Equal.sym(Maybe<&2, R.Match<T>>, Some{R.Match{1n+i, other, ps}}, None{}, none)))
    case Some{+ps} r:
      Core.absurd({r == None{} : Maybe<&2, R.Match<T>>}, none_some(R.Match<T>, R.Match{0n, tag, ps}, Equal.sym(Maybe<&2, R.Match<T>>, Some{R.Match{0n, tag, ps}}, None{}, none)))

def missed_union(-T: Data, +table: M.Table(T), +path: String, +method: H.Method, +opts: M.Options,
    +none: {M.find(T, table, path, method, opts) == None{} : Maybe<&2, R.Match<T>>}) ->
    {O.member(path_methods(T, table, path, opts), method) == False{} : Bool}:
  match table:
    case Nil{}: {==}
    case R.Route{+pattern, M.Binding{+methods, +tag}} <> +tail:
      absent_step(T, tag, methods, method, path_methods(T, tail, path, opts), M.match_path(pattern, path, opts), M.contains(methods, method), {==}, find_misses(T, R.Route{pattern, M.Binding{methods, tag}} <> tail, path, method, opts, none)(0n), missed_union(T, tail, path, method, opts, selected_none_tail(T, tag, M.eligible(methods, method, M.match_path(pattern, path, opts)), M.find(T, tail, path, method, opts), none)))
def set_order_member(+xs: List<&2, H.Method>, +q: H.Method) -> {Set.member(xs, q) == O.member(xs, q) : Bool}:
  match xs:
    case Nil{}: {==}
    case +h <> +tail:
      Equal.cong(Bool, Bool, x => String.eq(H.method_text(h), H.method_text(q)) || x, Set.member(tail, q), O.member(tail, q), set_order_member(tail, q))

def missed_set_union(-T: Data, +table: M.Table(T), +path: String, +method: H.Method, +opts: M.Options,
    none: {M.find(T, table, path, method, opts) == None{} : Maybe<&2, R.Match<T>>}) ->
    {Set.member(path_methods(T, table, path, opts), method) == False{} : Bool}:
  Equal.trans(Bool, Set.member(path_methods(T, table, path, opts), method), O.member(path_methods(T, table, path, opts), method), False{}, set_order_member(path_methods(T, table, path, opts), method), missed_union(T, table, path, method, opts, none))

def extension_head_case(+token: String, test: Bool,
    eq: {Set.is_head(H.Extension{token}) == test : Bool}, valid: {H.method_valid(H.Extension{token}) == True{} : Bool}) ->
    {Set.is_head(H.Extension{token}) == False{} : Bool}:
  match test:
    case False{}: eq
    case True{}:
      same = Eq.string_eq_sound("HEAD", token, eq)
      bad = Equal.trans(Bool, H.method_valid(H.Extension{"HEAD"}), H.method_valid(H.Extension{token}), True{}, Equal.cong(String, Bool, s => H.method_valid(H.Extension{s}), "HEAD", token, same), valid)
      Core.absurd({Set.is_head(H.Extension{token}) == False{} : Bool}, Core.false_true(bad))

def canonical_absent_plain(+xs: List<&2, H.Method>, +q: H.Method,
    absent: {Set.member(xs, q) == False{} : Bool}, not_head: {Set.is_head(q) == False{} : Bool}) ->
    {Set.member(M.canonical(xs), q) == False{} : Bool}:
  %Equal.sym(Bool, Set.member(M.canonical(xs), q), Set.member(xs, q) || (Set.is_head(q) && Set.member(xs, H.Get{})), Set.canonical_member(xs, q)) : {_ == False{} : Bool}
  %Equal.sym(Bool, Set.is_head(q), False{}, not_head) : {Set.member(xs, q) || (_ && Set.member(xs, H.Get{})) == False{} : Bool}
  %Equal.sym(Bool, Set.member(xs, q), False{}, absent) : {_ || False{} == False{} : Bool}
  {==}

def canonical_head_absent(+xs: List<&2, H.Method>, head: {Set.member(xs, H.Head{}) == False{} : Bool}, get: {Set.member(xs, H.Get{}) == False{} : Bool}) ->
    {Set.member(M.canonical(xs), H.Head{}) == False{} : Bool}:
  %Equal.sym(Bool, Set.member(M.canonical(xs), H.Head{}), Set.member(xs, H.Head{}) || (True{} && Set.member(xs, H.Get{})), Set.canonical_member(xs, H.Head{})) : {_ == False{} : Bool}
  %Equal.sym(Bool, Set.member(xs, H.Head{}), False{}, head) : {_ || Set.member(xs, H.Get{}) == False{} : Bool}
  get

def canonical_request_absent(-T: Data, +table: M.Table(T), +path: String, +method: H.Method, +opts: M.Options,
    valid: {H.method_valid(method) == True{} : Bool},
    direct: {M.find(T, table, path, method, opts) == None{} : Maybe<&2, R.Match<T>>}, get: HeadNone(T, table, path, method, opts)) ->
    {Set.member(M.canonical(path_methods(T, table, path, opts)), method) == False{} : Bool}:
  match method:
    case H.Head{}:
      canonical_head_absent(path_methods(T, table, path, opts), missed_set_union(T, table, path, H.Head{}, opts, direct), missed_set_union(T, table, path, H.Get{}, opts, get))
    case H.Get{}:
      canonical_absent_plain(path_methods(T, table, path, opts), H.Get{}, missed_set_union(T, table, path, H.Get{}, opts, direct), {==})
    case H.Post{}:
      canonical_absent_plain(path_methods(T, table, path, opts), H.Post{}, missed_set_union(T, table, path, H.Post{}, opts, direct), {==})
    case H.Put{}:
      canonical_absent_plain(path_methods(T, table, path, opts), H.Put{}, missed_set_union(T, table, path, H.Put{}, opts, direct), {==})
    case H.Delete{}:
      canonical_absent_plain(path_methods(T, table, path, opts), H.Delete{}, missed_set_union(T, table, path, H.Delete{}, opts, direct), {==})
    case H.Connect{}:
      canonical_absent_plain(path_methods(T, table, path, opts), H.Connect{}, missed_set_union(T, table, path, H.Connect{}, opts, direct), {==})
    case H.Options{}:
      canonical_absent_plain(path_methods(T, table, path, opts), H.Options{}, missed_set_union(T, table, path, H.Options{}, opts, direct), {==})
    case H.Trace{}:
      canonical_absent_plain(path_methods(T, table, path, opts), H.Trace{}, missed_set_union(T, table, path, H.Trace{}, opts, direct), {==})
    case H.Patch{}:
      canonical_absent_plain(path_methods(T, table, path, opts), H.Patch{}, missed_set_union(T, table, path, H.Patch{}, opts, direct), {==})
    case H.Extension{+token}:
      canonical_absent_plain(path_methods(T, table, path, opts), H.Extension{token}, missed_set_union(T, table, path, H.Extension{token}, opts, direct), extension_head_case(token, Set.is_head(H.Extension{token}), {==}, valid))
# Admissible registrations use canonical Method constructors. Patterns and
# method-list shape (including empty lists and duplicates) remain unrestricted.
def TableValid(-T: Data, table: M.Table(T)) -> Bool:
  match table:
    case Nil{}: True{}
    case R.Route{pattern, M.Binding{methods, tag}} <> tail:
      Set.list_valid(methods) && TableValid(T, tail)

def collection_valid_step(+methods: List<&2, H.Method>, +rest: List<&2, H.Method>, test: Bool,
    mv: {Set.list_valid(methods) == True{} : Bool}, rv: {Set.list_valid(rest) == True{} : Bool}) ->
    {Set.list_valid(E.choose(List<&2, H.Method>, test, u => List.append(&2, H.Method, methods, rest), u => rest)) == True{} : Bool}:
  match test:
    case True{}: O.valid_append(methods, rest, mv, rv)
    case False{}: rv

def collection_valid(-T: Data, +table: M.Table(T), +path: String, +opts: M.Options, +valid: {TableValid(T, table) == True{} : Bool}) ->
    {Set.list_valid(path_methods(T, table, path, opts)) == True{} : Bool}:
  match table:
    case Nil{}: {==}
    case R.Route{+pattern, M.Binding{+methods, tag}} <> +tail:
      collection_valid_step(methods, path_methods(T, tail, path, opts), Maybe.is_some(&2, P.Params, M.match_path(pattern, path, opts)), Core.and_left(Set.list_valid(methods), TableValid(T, tail), valid), collection_valid(T, tail, path, opts, Core.and_right(Set.list_valid(methods), TableValid(T, tail), valid)))

# No canonicalization helper occurs in the promised Allow specification.
def ExactAllow(-T: Data, +table: M.Table(T), +path: String, +method: H.Method, +opts: M.Options, +allow: List<&2, H.Method>) -> Type:
  {Set.list_valid(allow) == True{} : Bool} & ({O.ordered(allow) == True{} : Bool} &
    ({O.unique(allow) == True{} : Bool} &
    ({Set.member(allow, method) == False{} : Bool} &
    (@q: H.Method -> {Set.member(allow, q) == Set.member(path_methods(T, table, path, opts), q) || (Set.is_head(q) && Set.member(path_methods(T, table, path, opts), H.Get{})) : Bool}))))

def allow_from_correct(-T: Data, +table: M.Table(T), +path: String, +method: H.Method, +opts: M.Options, +allow: List<&2, H.Method>,
    tv: {TableValid(T, table) == True{} : Bool}, valid: {H.method_valid(method) == True{} : Bool}, correct: ResolutionCorrect(T, table, path, method, opts, M.MethodNotAllowed{allow})) -> ExactAllow(T, table, path, method, opts, allow):
  (exists, (same, (direct, get))) = correct
  %Equal.sym(List<&2, H.Method>, allow, M.canonical(path_methods(T, table, path, opts)), same) : ExactAllow(T, table, path, method, opts, _)
  (O.canonical_valid(path_methods(T, table, path, opts), collection_valid(T, table, path, opts, tv)), (O.canonical_order(path_methods(T, table, path, opts)), (O.canonical_unique(path_methods(T, table, path, opts)), (canonical_request_absent(T, table, path, method, opts, valid, direct, get), q => Set.canonical_member(path_methods(T, table, path, opts), q)))))

def exact_allow(-T: Data, +table: M.Table(T), +path: String, +method: H.Method, +opts: M.Options, +allow: List<&2, H.Method>,
    tv: {TableValid(T, table) == True{} : Bool}, valid: {H.method_valid(method) == True{} : Bool}, returned: {M.resolve(T, table, path, method, opts) == M.MethodNotAllowed{allow} : M.Resolution<T>}) -> ExactAllow(T, table, path, method, opts, allow):
  allow_from_correct(T, table, path, method, opts, allow, tv, valid, (
    %returned : ResolutionCorrect(T, table, path, method, opts, _)
    resolve_correct(T, table, path, method, opts)))

def found_first(-T: Data, +table: M.Table(T), +path: String, +method: H.Method, +opts: M.Options, +i: Nat, +tag: T, +ps: P.Params,
    returned: {M.resolve(T, table, path, method, opts) == M.Found{R.Match{i, tag, ps}, False{}} : M.Resolution<T>}) -> First(T, table, path, method, opts, i, tag, ps):
  %returned : ResolutionCorrect(T, table, path, method, opts, _)
  resolve_correct(T, table, path, method, opts)

def fallback_first(-T: Data, +table: M.Table(T), +path: String, +method: H.Method, +opts: M.Options, +i: Nat, +tag: T, +ps: P.Params,
    returned: {M.resolve(T, table, path, method, opts) == M.Found{R.Match{i, tag, ps}, True{}} : M.Resolution<T>}) ->
    {method == H.Head{} : H.Method} & (Misses(T, table, path, H.Head{}, opts) & First(T, table, path, H.Get{}, opts, i, tag, ps)):
  %returned : ResolutionCorrect(T, table, path, method, opts, _)
  resolve_correct(T, table, path, method, opts)

def not_found_only(-T: Data, +table: M.Table(T), +path: String, +method: H.Method, +opts: M.Options,
    returned: {M.resolve(T, table, path, method, opts) == M.NotFound{} : M.Resolution<T>}) -> NoPaths(T, table, path, opts):
  %returned : ResolutionCorrect(T, table, path, method, opts, _)
  resolve_correct(T, table, path, method, opts)

# Default lookup independently uses List.get, direct Pattern.match_path and
# token membership. It never calls the option adapter, find or resolve.
def direct_lookup(-T: Data, entry: Maybe<&2, R.Route<M.Binding<T>>>, path: String, +method: H.Method) -> Maybe<&2, AtMatch<T>>:
  match entry:
    case None{}: None{}
    case Some{R.Route{pattern, M.Binding{methods, tag}}}:
      entry_match(T, tag, E.choose(Maybe<&2, P.Params>, Set.member(methods, method), u => P.match_path(pattern, path), u => None{}))

def direct_at(-T: Data, table: M.Table(T), path: String, method: H.Method, i: Nat) -> Maybe<&2, AtMatch<T>>:
  direct_lookup(T, List.get(&2, R.Route<M.Binding<T>>, table, i), path, method)

def default_lookup(-T: Data, +entry: Maybe<&2, R.Route<M.Binding<T>>>, +path: String, +method: H.Method) ->
    {lookup_match(T, entry, path, method, M.defaults()) == direct_lookup(T, entry, path, method) : Maybe<&2, AtMatch<T>>}:
  match entry:
    case None{}: {==}
    case Some{R.Route{+pattern, M.Binding{+methods, +tag}}}:
      %Equal.sym(Bool, M.contains(methods, method), Set.member(methods, method), Equal.trans(Bool, M.contains(methods, method), O.member(methods, method), Set.member(methods, method), O.member_contains(methods, method), Equal.sym(Bool, Set.member(methods, method), O.member(methods, method), set_order_member(methods, method)))) : {entry_match(T, tag, E.choose(Maybe<&2, P.Params>, _, u => M.match_path(pattern, path, M.defaults()), u => None{})) == direct_lookup(T, entry, path, method) : Maybe<&2, AtMatch<T>>}
      Equal.cong(Maybe<&2, P.Params>, Maybe<&2, AtMatch<T>>, x => entry_match(T, tag, E.choose(Maybe<&2, P.Params>, Set.member(methods, method), u => x, u => None{})), M.match_path(pattern, path, M.defaults()), P.match_path(pattern, path), default_path(pattern, path))

def default_index(-T: Data, +table: M.Table(T), +path: String, +method: H.Method, +i: Nat) ->
    {match_at(T, table, path, method, M.defaults(), i) == direct_at(T, table, path, method, i) : Maybe<&2, AtMatch<T>>}:
  default_lookup(T, List.get(&2, R.Route<M.Binding<T>>, table, i), path, method)

def DefaultFirst(-T: Data, +table: M.Table(T), +path: String, +method: H.Method, +i: Nat, +tag: T, +ps: P.Params) -> Type:
  {direct_at(T, table, path, method, i) == Some{At{tag, ps}} : Maybe<&2, AtMatch<T>>} &
    (@j: Nat -> {Nat.is_lt(j, i) == True{} : Bool} -> {direct_at(T, table, path, method, j) == None{} : Maybe<&2, AtMatch<T>>})

def default_first(-T: Data, +table: M.Table(T), +path: String, +method: H.Method, +i: Nat, +tag: T, +ps: P.Params,
    first: First(T, table, path, method, M.defaults(), i, tag, ps)) -> DefaultFirst(T, table, path, method, i, tag, ps):
  (at, earlier) = first
  (Equal.trans(Maybe<&2, AtMatch<T>>, direct_at(T, table, path, method, i), match_at(T, table, path, method, M.defaults(), i), Some{At{tag, ps}}, Equal.sym(Maybe<&2, AtMatch<T>>, match_at(T, table, path, method, M.defaults(), i), direct_at(T, table, path, method, i), default_index(T, table, path, method, i)), at), +j => lt => Equal.trans(Maybe<&2, AtMatch<T>>, direct_at(T, table, path, method, j), match_at(T, table, path, method, M.defaults(), j), None{}, Equal.sym(Maybe<&2, AtMatch<T>>, match_at(T, table, path, method, M.defaults(), j), direct_at(T, table, path, method, j), default_index(T, table, path, method, j)), earlier(j, lt)))
def present_result(-T: Data, +table: M.Table(T), +path: String, +method: H.Method, +opts: M.Options, +i: Nat, +tag: T, +ps: P.Params,
    at: {match_at(T, table, path, method, opts, i) == Some{At{tag, ps}} : Maybe<&2, AtMatch<T>>},
    +result: Maybe<&2, R.Match<T>>, correct: Outcome(T, table, path, method, opts, result)) ->
    &hit: R.Match<T> -> {result == Some{hit} : Maybe<&2, R.Match<T>>} & Unit:
  match result:
    case Some{+hit}: (hit, ({==}, Unit{}))
    case None{}:
      Core.absurd(&hit: R.Match<T> -> {None{} == Some{hit} : Maybe<&2, R.Match<T>>} & Unit, none_some(AtMatch<T>, At{tag, ps}, Equal.trans(Maybe<&2, AtMatch<T>>, None{}, match_at(T, table, path, method, opts, i), Some{At{tag, ps}}, Equal.sym(Maybe<&2, AtMatch<T>>, match_at(T, table, path, method, opts, i), None{}, correct(i)), at)))

def HeadPriority(-T: Data, +table: M.Table(T), +path: String, +opts: M.Options) -> Type:
  &hit: R.Match<T> -> {M.resolve(T, table, path, H.Head{}, opts) == M.Found{hit, False{}} : M.Resolution<T>} & Outcome(T, table, path, H.Head{}, opts, Some{hit})

def head_witness(-T: Data, +table: M.Table(T), +path: String, +opts: M.Options,
    witness: &hit: R.Match<T> -> {M.find(T, table, path, H.Head{}, opts) == Some{hit} : Maybe<&2, R.Match<T>>} & Unit) -> HeadPriority(T, table, path, opts):
  (+hit, (+found, u)) = witness
  (hit, ((
    %Equal.sym(Maybe<&2, R.Match<T>>, M.find(T, table, path, H.Head{}, opts), Some{hit}, found) : {M.resolve_direct(T, _, table, path, H.Head{}, opts) == M.Found{hit, False{}} : M.Resolution<T>}
    {==}), (
    %found : Outcome(T, table, path, H.Head{}, opts, _)
    route_correct(T, table, path, H.Head{}, opts))))

def head_priority(-T: Data, +table: M.Table(T), +path: String, +opts: M.Options, +i: Nat, +tag: T, +ps: P.Params,
    at: {match_at(T, table, path, H.Head{}, opts, i) == Some{At{tag, ps}} : Maybe<&2, AtMatch<T>>}) -> HeadPriority(T, table, path, opts):
  head_witness(T, table, path, opts, present_result(T, table, path, H.Head{}, opts, i, tag, ps, at, M.find(T, table, path, H.Head{}, opts), route_correct(T, table, path, H.Head{}, opts)))
