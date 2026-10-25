# BND-86: ordered method resolution for a mounted registration list.
import Base
import ../src/router/pattern.bend as P
import ../src/router/methods.bend as M
import ../src/router/spec.bend as R
import ../src/router/router.bend as Router
import ../src/router/proofs.bend as Core
import ../src/router/encoding.bend as E
import ../src/http/request.bend as H
import ../src/app/compose.bend as C
import ../src/app/table.bend as T
import ./compose-spec.bend as ComposeSpec
import ./compose-laws.bend as CL
import ./compose.bend as ComposeProof
import ./scoped-assembly-spec.bend as AssemblySpec
import ./router-compile-spec.bend as CS
import ./mount-spec.bend as S
import ./mount-laws.bend as L
import ./mount.bend as MP

def Regs(-Tag: Data) -> Data:
  List<&2, M.Registration(Tag)>

# ---- Assembly of a mounted registration list ----

def joined_regs(-Tag: Data, +prefix: String, routes: Regs(Tag)) -> Regs(Tag):
  match routes:
    case Nil{}:
      Nil{}
    case R.Registration{s, b} <> t:
      R.Registration{AssemblySpec.path(prefix, ComposeSpec.canonical(s)), b} <> joined_regs(Tag, prefix, t)

def canon_regs(-Tag: Data, routes: Regs(Tag)) -> Regs(Tag):
  match routes:
    case Nil{}:
      Nil{}
    case R.Registration{s, b} <> t:
      R.Registration{ComposeSpec.canonical(s), b} <> canon_regs(Tag, t)

def scoped(-Tag: Data, regs: Regs(Tag)) -> List<&2, T.Entry<Tag>>:
  match regs:
    case Nil{}:
      Nil{}
    case r <> t:
      T.ScopedRoute{r, []} <> scoped(Tag, t)

def prepared(-Tag: Data, +routes: Regs(Tag)) -> {ComposeSpec.prepare(Tag, S.entries(Tag, routes), True{}) == S.entries(Tag, canon_regs(Tag, routes)) : List<&2, T.Entry<Tag>>}:
  match routes:
    case Nil{}:
      {==}
    case R.Registration{+s, +b} <> +t:
      Equal.cong(List<&2, T.Entry<Tag>>, List<&2, T.Entry<Tag>>, xs => T.Route{R.Registration{ComposeSpec.canonical(s), b}} <> xs, ComposeSpec.prepare(Tag, S.entries(Tag, t), True{}), S.entries(Tag, canon_regs(Tag, t)), prepared(Tag, t))

def undeclared(-Tag: Data, +routes: Regs(Tag)) -> {AssemblySpec.declarations(Tag, S.entries(Tag, routes)) == [] : List<&2, T.HookSpec<Tag>>}:
  match routes:
    case Nil{}:
      {==}
    case r <> +t:
      undeclared(Tag, t)

def assembled_regs(-Tag: Data, +prefix: String, +routes: Regs(Tag)) ->
    {AssemblySpec.assemble(Tag, S.entries(Tag, canon_regs(Tag, routes)), prefix, []) == scoped(Tag, joined_regs(Tag, prefix, routes)) : List<&2, T.Entry<Tag>>}:
  match routes:
    case Nil{}:
      {==}
    case R.Registration{+s, +b} <> +t:
      Equal.cong(List<&2, T.Entry<Tag>>, List<&2, T.Entry<Tag>>, xs => T.ScopedRoute{R.Registration{AssemblySpec.path(prefix, ComposeSpec.canonical(s)), b}, []} <> xs, AssemblySpec.assemble(Tag, S.entries(Tag, canon_regs(Tag, t)), prefix, []), scoped(Tag, joined_regs(Tag, prefix, t)), assembled_regs(Tag, prefix, t))

# Mounting a registration list gives each route the joined source, no hooks.
def mount_scoped(-Tag: Data, +prefix: String, +routes: Regs(Tag)) ->
    {ComposeSpec.mount(Tag, prefix, S.entries(Tag, routes)) == scoped(Tag, joined_regs(Tag, prefix, routes)) : List<&2, T.Entry<Tag>>}:
  %Equal.sym(List<&2, T.Entry<Tag>>, ComposeSpec.prepare(Tag, S.entries(Tag, routes), True{}), S.entries(Tag, canon_regs(Tag, routes)), prepared(Tag, routes)) : {AssemblySpec.group(Tag, prefix, [], _) == scoped(Tag, joined_regs(Tag, prefix, routes)) : List<&2, T.Entry<Tag>>}
  %Equal.sym(List<&2, T.HookSpec<Tag>>, AssemblySpec.declarations(Tag, S.entries(Tag, canon_regs(Tag, routes))), [], undeclared(Tag, canon_regs(Tag, routes))) : {AssemblySpec.assemble(Tag, S.entries(Tag, canon_regs(Tag, routes)), prefix, AssemblySpec.located(Tag, List.append(&2, T.HookSpec<Tag>, [], _), T.GroupScope{prefix})) == scoped(Tag, joined_regs(Tag, prefix, routes)) : List<&2, T.Entry<Tag>>}
  assembled_regs(Tag, prefix, routes)

def scoped_routes(-Tag: Data, +regs: Regs(Tag)) -> {T.route_entries(Tag, scoped(Tag, regs)) == regs : Regs(Tag)}:
  match regs:
    case Nil{}:
      {==}
    case +r <> +t:
      Equal.cong(Regs(Tag), Regs(Tag), xs => r <> xs, T.route_entries(Tag, scoped(Tag, t)), t, scoped_routes(Tag, t))

# ---- Each joined route compiles and builds ----

def compiled_ok(r: Result<&2, &2, P.PatternError, P.Pattern>) -> Bool:
  match r:
    case Done{p}:
      True{}
    case Fail{e}:
      False{}

def ok_from(r: Result<&2, &2, P.PatternError, P.Pattern>, +m: Maybe<&2, P.Pattern>, e: {CS.accepted(r) == m : Maybe<&2, P.Pattern>}, c: {S.compiles(m) == True{} : Bool}) ->
    {compiled_ok(r) == True{} : Bool}:
  match r:
    case Done{p}:
      {==}
    case Fail{x}:
      Core.absurd({compiled_ok(Fail{x}) == True{} : Bool}, Core.false_true(Equal.trans(Bool, False{}, S.compiles(m), True{}, Equal.cong(Maybe<&2, P.Pattern>, Bool, z => S.compiles(z), None{}, m, e), c)))

def joined_source(+prefix: String, +s: String) -> String:
  AssemblySpec.path(prefix, ComposeSpec.canonical(s))

def accepted_joined(+prefix: String, +s: String, +adm: {S.admissible(prefix, s) == True{} : Bool}) ->
    {CS.accepted(P.compile(joined_source(prefix, s))) == S.assembled(prefix, s) : Maybe<&2, P.Pattern>}:
  %MP.source_eq(prefix, s) : {CS.accepted(P.compile(_)) == S.assembled(prefix, s) : Maybe<&2, P.Pattern>}
  L.mount_compile_spec(prefix, s, MP.placed_at(S.place(prefix), s, adm))

def joined_ok(+prefix: String, +s: String, +adm: {S.admissible(prefix, s) == True{} : Bool}) -> {compiled_ok(P.compile(joined_source(prefix, s))) == True{} : Bool}:
  ok_from(P.compile(joined_source(prefix, s)), S.assembled(prefix, s), accepted_joined(prefix, s, adm), MP.compiles_at(S.place(prefix), s, adm))

def joined_match(+prefix: String, +s: String, +path: String, +opts: M.Options, +adm: {S.admissible(prefix, s) == True{} : Bool}) ->
    {L.compiled_match(P.compile(joined_source(prefix, s)), path, opts) == S.mounted(prefix, s, path, opts) : Maybe<&2, P.Params>}:
  MP.main_at(P.compile(joined_source(prefix, s)), prefix, s, path, opts, accepted_joined(prefix, s, adm), adm)

def none_valid(+xs: List<&2, H.Method>, v: {M.list_valid(xs) == True{} : Bool}) -> {M.invalid_method(xs) == None{} : Maybe<&2, String>}:
  match xs:
    case Nil{}:
      {==}
    case +h <> +t:
      +e = v
      %Equal.sym(Bool, H.method_valid(h), True{}, Core.and_left(H.method_valid(h), M.list_valid(t), e)) : {E.choose(Maybe<&2, String>, _, u => M.invalid_method(t), u => Some{H.method_text(h)}) == None{} : Maybe<&2, String>}
      none_valid(t, Core.and_right(H.method_valid(h), M.list_valid(t), e))

def some_text(m: Maybe<&2, String>) -> Type:
  match m:
    case None{}:
      Empty
    case Some{x}:
      Unit

def some_none_text(+x: String, e: {Some{x} == None{} : Maybe<&2, String>}) -> Empty:
  %e : some_text(_)
  Unit{}

def methods_none(-T: Data, +i: Nat, +src: String, +methods: M.MethodSelector, +tag: T, invalid: Maybe<&2, String>, -checked: M.InvalidChecked(M.finite(methods), invalid),
    rest: Unit -> Result<&2, &2, M.BuildError, M.Table(T)>, none: {invalid == None{} : Maybe<&2, String>}) ->
    {M.build_methods(T, i, src, methods, tag, invalid, checked, rest) == M.build_pattern(T, i, src, M.Binding{methods, tag}, P.compile(src), rest) : Result<&2, &2, M.BuildError, M.Table(T)>}:
  match invalid:
    case None{}:
      {==}
    case Some{x}:
      Core.absurd({M.build_methods(T, i, src, methods, tag, Some{x}, checked, rest) == M.build_pattern(T, i, src, M.Binding{methods, tag}, P.compile(src), rest) : Result<&2, &2, M.BuildError, M.Table(T)>}, some_none_text(x, none))

# ---- Rows of a built table ----

def rows_of(-Tag: Data, tbl: M.Table(Tag), +path: String, +opts: M.Options) -> List<&2, S.Row<Tag>>:
  match tbl:
    case Nil{}:
      Nil{}
    case R.Route{p, M.Binding{methods, tag}} <> t:
      S.Row{M.match_path(p, path, opts), methods, tag} <> rows_of(Tag, t, path, opts)

def rows_result(-Tag: Data, r: Result<&2, &2, M.BuildError, M.Table(Tag)>, +path: String, +opts: M.Options) -> Maybe<&2, List<&2, S.Row<Tag>>>:
  match r:
    case Fail{e}:
      None{}
    case Done{tbl}:
      Some{rows_of(Tag, tbl, path, opts)}

def get_rows(-Tag: Data, m: Maybe<&2, List<&2, S.Row<Tag>>>, d: List<&2, S.Row<Tag>>) -> List<&2, S.Row<Tag>>:
  match m:
    case Some{x}:
      x
    case None{}:
      d

def rows_is_some(-Tag: Data, m: Maybe<&2, List<&2, S.Row<Tag>>>) -> Type:
  match m:
    case None{}:
      Unit
    case Some{x}:
      Empty

def no_rows(-Tag: Data, +ys: List<&2, S.Row<Tag>>, e: {None{} == Some{ys} : Maybe<&2, List<&2, S.Row<Tag>>>}) -> Empty:
  %e : rows_is_some(Tag, _)
  Unit{}

def rows_inj(-Tag: Data, +xs: List<&2, S.Row<Tag>>, +ys: List<&2, S.Row<Tag>>, e: {Some{xs} == Some{ys} : Maybe<&2, List<&2, S.Row<Tag>>>}) -> {xs == ys : List<&2, S.Row<Tag>>}:
  Equal.cong(Maybe<&2, List<&2, S.Row<Tag>>>, List<&2, S.Row<Tag>>, m => get_rows(Tag, m, xs), Some{xs}, Some{ys}, e)

def row_cons(-Tag: Data, +p: P.Pattern, +methods: M.MethodSelector, +tag: Tag, r: Result<&2, &2, M.BuildError, M.Table(Tag)>, +path: String, +opts: M.Options, +ys: List<&2, S.Row<Tag>>,
    hyp: {rows_result(Tag, r, path, opts) == Some{ys} : Maybe<&2, List<&2, S.Row<Tag>>>}) ->
    {rows_result(Tag, M.prepend_built(Tag, p, M.Binding{methods, tag}, r), path, opts) == Some{S.Row{M.match_path(p, path, opts), methods, tag} <> ys} : Maybe<&2, List<&2, S.Row<Tag>>>}:
  match r:
    case Fail{x}:
      Core.absurd({rows_result(Tag, M.prepend_built(Tag, p, M.Binding{methods, tag}, Fail{x}), path, opts) == Some{S.Row{M.match_path(p, path, opts), methods, tag} <> ys} : Maybe<&2, List<&2, S.Row<Tag>>>}, no_rows(Tag, ys, hyp))
    case Done{tbl}:
      Equal.cong(List<&2, S.Row<Tag>>, Maybe<&2, List<&2, S.Row<Tag>>>, xs => Some{S.Row{M.match_path(p, path, opts), methods, tag} <> xs}, rows_of(Tag, tbl, path, opts), ys, rows_inj(Tag, rows_of(Tag, tbl, path, opts), ys, hyp))

def pattern_row(-Tag: Data, +i: Nat, +src: String, +methods: M.MethodSelector, +tag: Tag, c: Result<&2, &2, P.PatternError, P.Pattern>,
    rest: Unit -> Result<&2, &2, M.BuildError, M.Table(Tag)>, +path: String, +opts: M.Options, +hit: Maybe<&2, P.Params>, +ys: List<&2, S.Row<Tag>>,
    ok: {compiled_ok(c) == True{} : Bool}, cm: {L.compiled_match(c, path, opts) == hit : Maybe<&2, P.Params>},
    hyp: {rows_result(Tag, rest(Unit{}), path, opts) == Some{ys} : Maybe<&2, List<&2, S.Row<Tag>>>}) ->
    {rows_result(Tag, M.build_pattern(Tag, i, src, M.Binding{methods, tag}, c, rest), path, opts) == Some{S.Row{hit, methods, tag} <> ys} : Maybe<&2, List<&2, S.Row<Tag>>>}:
  match c:
    case Fail{x}:
      Core.absurd({rows_result(Tag, M.build_pattern(Tag, i, src, M.Binding{methods, tag}, Fail{x}, rest), path, opts) == Some{S.Row{hit, methods, tag} <> ys} : Maybe<&2, List<&2, S.Row<Tag>>>}, Core.false_true(ok))
    case Done{+p}:
      %cm : {rows_result(Tag, M.prepend_built(Tag, p, M.Binding{methods, tag}, rest(Unit{})), path, opts) == Some{S.Row{_, methods, tag} <> ys} : Maybe<&2, List<&2, S.Row<Tag>>>}
      row_cons(Tag, p, methods, tag, rest(Unit{}), path, opts, ys, hyp)

# Under admissible routes and valid methods, the table builds, one row per
# route, each answering exactly the mounted specification.
def rows_build(-Tag: Data, +prefix: String, +routes: Regs(Tag), +i: Nat, +path: String, +opts: M.Options,
    adm: {S.all_admissible(Tag, prefix, routes) == True{} : Bool}, valid: {S.methods_valid(Tag, routes) == True{} : Bool}) ->
    {rows_result(Tag, M.build_go(Tag, joined_regs(Tag, prefix, routes), i), path, opts) == Some{S.rows(Tag, prefix, routes, path, opts)} : Maybe<&2, List<&2, S.Row<Tag>>>}:
  match routes:
    case Nil{}:
      {==}
    case R.Registration{+s, M.Binding{+methods, +tag}} <> +t:
      +a = adm
      +v = valid
      +a1 = Core.and_left(S.admissible(prefix, s), S.all_admissible(Tag, prefix, t), a)
      +v1 = Core.and_left(M.list_valid(M.finite(M.normalize_selector(methods))), S.methods_valid(Tag, t), v)
      Equal.trans(Maybe<&2, List<&2, S.Row<Tag>>>, rows_result(Tag, M.build_methods(Tag, i, joined_source(prefix, s), M.normalize_selector(methods), tag, M.invalid_method(M.finite(M.normalize_selector(methods))), M.invalid_checked(M.finite(M.normalize_selector(methods))), u => M.build_go(Tag, joined_regs(Tag, prefix, t), 1n+i)), path, opts), rows_result(Tag, M.build_pattern(Tag, i, joined_source(prefix, s), M.Binding{M.normalize_selector(methods), tag}, P.compile(joined_source(prefix, s)), u => M.build_go(Tag, joined_regs(Tag, prefix, t), 1n+i)), path, opts), Some{S.rows(Tag, prefix, R.Registration{s, M.Binding{methods, tag}} <> t, path, opts)}, Equal.cong(Result<&2, &2, M.BuildError, M.Table(Tag)>, Maybe<&2, List<&2, S.Row<Tag>>>, r => rows_result(Tag, r, path, opts), M.build_methods(Tag, i, joined_source(prefix, s), M.normalize_selector(methods), tag, M.invalid_method(M.finite(M.normalize_selector(methods))), M.invalid_checked(M.finite(M.normalize_selector(methods))), u => M.build_go(Tag, joined_regs(Tag, prefix, t), 1n+i)), M.build_pattern(Tag, i, joined_source(prefix, s), M.Binding{M.normalize_selector(methods), tag}, P.compile(joined_source(prefix, s)), u => M.build_go(Tag, joined_regs(Tag, prefix, t), 1n+i)), methods_none(Tag, i, joined_source(prefix, s), M.normalize_selector(methods), tag, M.invalid_method(M.finite(M.normalize_selector(methods))), M.invalid_checked(M.finite(M.normalize_selector(methods))), u => M.build_go(Tag, joined_regs(Tag, prefix, t), 1n+i), none_valid(M.finite(M.normalize_selector(methods)), v1))), pattern_row(Tag, i, joined_source(prefix, s), M.normalize_selector(methods), tag, P.compile(joined_source(prefix, s)), u => M.build_go(Tag, joined_regs(Tag, prefix, t), 1n+i), path, opts, S.mounted(prefix, s, path, opts), S.rows(Tag, prefix, t, path, opts), joined_ok(prefix, s, a1), joined_match(prefix, s, path, opts, a1), rows_build(Tag, prefix, t, 1n+i, path, opts, Core.and_right(S.admissible(prefix, s), S.all_admissible(Tag, prefix, t), a), Core.and_right(M.list_valid(M.finite(M.normalize_selector(methods))), S.methods_valid(Tag, t), v))))

# ---- Each route's own validation passes ----

def done_tbl(-Tag: Data, r: Result<&2, &2, M.BuildError, M.Table(Tag)>) -> Bool:
  match r:
    case Fail{e}:
      False{}
    case Done{t}:
      True{}

def prepend_done(-Tag: Data, +p: P.Pattern, +b: M.Binding<Tag>, r: Result<&2, &2, M.BuildError, M.Table(Tag)>, d: {done_tbl(Tag, r) == True{} : Bool}) ->
    {done_tbl(Tag, M.prepend_built(Tag, p, b, r)) == True{} : Bool}:
  match r:
    case Fail{x}:
      Core.absurd({done_tbl(Tag, M.prepend_built(Tag, p, b, Fail{x})) == True{} : Bool}, Core.false_true(d))
    case Done{t}:
      {==}

def single_done(-Tag: Data, +i: Nat, +src: String, +methods: M.MethodSelector, +tag: Tag, c: Result<&2, &2, P.PatternError, P.Pattern>,
    rest: Unit -> Result<&2, &2, M.BuildError, M.Table(Tag)>, ok: {compiled_ok(c) == True{} : Bool}, d: {done_tbl(Tag, rest(Unit{})) == True{} : Bool}) ->
    {done_tbl(Tag, M.build_pattern(Tag, i, src, M.Binding{methods, tag}, c, rest)) == True{} : Bool}:
  match c:
    case Fail{x}:
      Core.absurd({done_tbl(Tag, M.build_pattern(Tag, i, src, M.Binding{methods, tag}, Fail{x}, rest)) == True{} : Bool}, Core.false_true(ok))
    case Done{+p}:
      prepend_done(Tag, p, M.Binding{methods, tag}, rest(Unit{}), d)

def checked_rest(-Tag: Data, +i: Nat, res: Result<&2, &2, M.BuildError, M.Table(Tag)>, good: {M.BuildValid(Tag, res) == True{} : Bool},
    k: Unit -> Result<&2, &2, M.BuildError, List<&2, T.Middleware<Tag>>>, d: {done_tbl(Tag, res) == True{} : Bool}) ->
    {T.route_checked(Tag, i, M.certify(Tag, res, good), k) == k(Unit{}) : Result<&2, &2, M.BuildError, List<&2, T.Middleware<Tag>>>}:
  match res:
    case Fail{x}:
      Core.absurd({T.route_checked(Tag, i, M.certify(Tag, Fail{x}, good), k) == k(Unit{}) : Result<&2, &2, M.BuildError, List<&2, T.Middleware<Tag>>>}, Core.false_true(d))
    case Done{t}:
      {==}

def mw_done(-Tag: Data, +prefix: String, +routes: Regs(Tag), +i: Nat,
    adm: {S.all_admissible(Tag, prefix, routes) == True{} : Bool}, valid: {S.methods_valid(Tag, routes) == True{} : Bool}) ->
    {T.middleware_entries(Tag, scoped(Tag, joined_regs(Tag, prefix, routes)), i) == Done{[]} : Result<&2, &2, M.BuildError, List<&2, T.Middleware<Tag>>>}:
  match routes:
    case Nil{}:
      {==}
    case R.Registration{+s, M.Binding{+methods, +tag}} <> +t:
      +a = adm
      +v = valid
      +a1 = Core.and_left(S.admissible(prefix, s), S.all_admissible(Tag, prefix, t), a)
      +v1 = Core.and_left(M.list_valid(M.finite(M.normalize_selector(methods))), S.methods_valid(Tag, t), v)
      +d = Equal.trans(Bool, done_tbl(Tag, M.build_methods(Tag, 0n, joined_source(prefix, s), M.normalize_selector(methods), tag, M.invalid_method(M.finite(M.normalize_selector(methods))), M.invalid_checked(M.finite(M.normalize_selector(methods))), u => M.build_go(Tag, Nil{}, 1n))), done_tbl(Tag, M.build_pattern(Tag, 0n, joined_source(prefix, s), M.Binding{M.normalize_selector(methods), tag}, P.compile(joined_source(prefix, s)), u => M.build_go(Tag, Nil{}, 1n))), True{}, Equal.cong(Result<&2, &2, M.BuildError, M.Table(Tag)>, Bool, r => done_tbl(Tag, r), M.build_methods(Tag, 0n, joined_source(prefix, s), M.normalize_selector(methods), tag, M.invalid_method(M.finite(M.normalize_selector(methods))), M.invalid_checked(M.finite(M.normalize_selector(methods))), u => M.build_go(Tag, Nil{}, 1n)), M.build_pattern(Tag, 0n, joined_source(prefix, s), M.Binding{M.normalize_selector(methods), tag}, P.compile(joined_source(prefix, s)), u => M.build_go(Tag, Nil{}, 1n)), methods_none(Tag, 0n, joined_source(prefix, s), M.normalize_selector(methods), tag, M.invalid_method(M.finite(M.normalize_selector(methods))), M.invalid_checked(M.finite(M.normalize_selector(methods))), u => M.build_go(Tag, Nil{}, 1n), none_valid(M.finite(M.normalize_selector(methods)), v1))), single_done(Tag, 0n, joined_source(prefix, s), M.normalize_selector(methods), tag, P.compile(joined_source(prefix, s)), u => M.build_go(Tag, Nil{}, 1n), joined_ok(prefix, s, a1), {==}))
      Equal.trans(Result<&2, &2, M.BuildError, List<&2, T.Middleware<Tag>>>, T.route_checked(Tag, i, M.build_table(Tag, [R.Registration{joined_source(prefix, s), M.Binding{methods, tag}}]), u => T.prepend_scoped(Tag, [], scoped(Tag, joined_regs(Tag, prefix, t)), T.middleware_entries(Tag, scoped(Tag, joined_regs(Tag, prefix, t)), 1n+i))), T.middleware_entries(Tag, scoped(Tag, joined_regs(Tag, prefix, t)), 1n+i), Done{[]}, checked_rest(Tag, i, M.build_go(Tag, [R.Registration{joined_source(prefix, s), M.Binding{methods, tag}}], 0n), M.build_go_valid(Tag, [R.Registration{joined_source(prefix, s), M.Binding{methods, tag}}], 0n), u => T.prepend_scoped(Tag, [], scoped(Tag, joined_regs(Tag, prefix, t)), T.middleware_entries(Tag, scoped(Tag, joined_regs(Tag, prefix, t)), 1n+i)), d), mw_done(Tag, prefix, t, 1n+i, Core.and_right(S.admissible(prefix, s), S.all_admissible(Tag, prefix, t), a), Core.and_right(M.list_valid(M.finite(M.normalize_selector(methods))), S.methods_valid(Tag, t), v)))

# ---- Resolution reads only the rows ----

def eligible_same(b: Bool, +hit: Maybe<&2, P.Params>) -> {E.choose(Maybe<&2, P.Params>, b, u => hit, u => None{}) == S.allowed_hit(b, hit) : Maybe<&2, P.Params>}:
  match b:
    case True{}:
      {==}
    case False{}:
      {==}

def bump_later(-Tag: Data, m: Maybe<&2, R.Match<Tag>>) -> {R.bump(Tag, m) == S.later(Tag, m) : Maybe<&2, R.Match<Tag>>}:
  match m:
    case None{}:
      {==}
    case Some{R.Match{i, tag, ps}}:
      {==}

def select_pick(-Tag: Data, +tag: Tag, hit: Maybe<&2, P.Params>, +x: Maybe<&2, R.Match<Tag>>, +y: Maybe<&2, R.Match<Tag>>, ih: {x == y : Maybe<&2, R.Match<Tag>>}) -> {R.select(Tag, tag, hit, u => x) == S.pick(Tag, tag, hit, y) : Maybe<&2, R.Match<Tag>>}:
  match hit:
    case None{}:
      %ih : {R.bump(Tag, x) == S.later(Tag, _) : Maybe<&2, R.Match<Tag>>}
      bump_later(Tag, x)
    case Some{ps}:
      {==}

def find_rows(-Tag: Data, +tbl: M.Table(Tag), +path: String, +method: H.Method, +opts: M.Options) ->
    {M.find(Tag, tbl, path, method, opts) == S.first(Tag, rows_of(Tag, tbl, path, opts), method) : Maybe<&2, R.Match<Tag>>}:
  match tbl:
    case Nil{}:
      {==}
    case R.Route{+p, M.Binding{+methods, +tag}} <> +t:
      Equal.trans(Maybe<&2, R.Match<Tag>>, R.select(Tag, tag, E.choose(Maybe<&2, P.Params>, M.accepts(methods, method), u => M.match_path(p, path, opts), u => None{}), u => M.find(Tag, t, path, method, opts)), R.select(Tag, tag, S.allowed_hit(M.accepts(methods, method), M.match_path(p, path, opts)), u => M.find(Tag, t, path, method, opts)), S.pick(Tag, tag, S.allowed_hit(M.accepts(methods, method), M.match_path(p, path, opts)), S.first(Tag, rows_of(Tag, t, path, opts), method)), Equal.cong(Maybe<&2, P.Params>, Maybe<&2, R.Match<Tag>>, h => R.select(Tag, tag, h, u => M.find(Tag, t, path, method, opts)), E.choose(Maybe<&2, P.Params>, M.accepts(methods, method), u => M.match_path(p, path, opts), u => None{}), S.allowed_hit(M.accepts(methods, method), M.match_path(p, path, opts)), eligible_same(M.accepts(methods, method), M.match_path(p, path, opts))), select_pick(Tag, tag, S.allowed_hit(M.accepts(methods, method), M.match_path(p, path, opts)), M.find(Tag, t, path, method, opts), S.first(Tag, rows_of(Tag, t, path, opts), method), find_rows(Tag, t, path, method, opts)))

def some_same(+h: Maybe<&2, P.Params>) -> {Maybe.is_some(&2, P.Params, h) == S.hit_some(h) : Bool}:
  match h:
    case None{}:
      {==}
    case Some{x}:
      {==}

def exists_rows(-Tag: Data, +tbl: M.Table(Tag), +path: String, +opts: M.Options) ->
    {M.path_exists(Tag, tbl, path, opts) == S.answered(Tag, rows_of(Tag, tbl, path, opts)) : Bool}:
  match tbl:
    case Nil{}:
      {==}
    case R.Route{+p, M.Binding{+methods, +tag}} <> +t:
      %Equal.sym(Bool, Maybe.is_some(&2, P.Params, M.match_path(p, path, opts)), S.hit_some(M.match_path(p, path, opts)), some_same(M.match_path(p, path, opts))) : {_ || M.path_exists(Tag, t, path, opts) == S.hit_some(M.match_path(p, path, opts)) || S.answered(Tag, rows_of(Tag, t, path, opts)) : Bool}
      Equal.cong(Bool, Bool, z => S.hit_some(M.match_path(p, path, opts)) || z, M.path_exists(Tag, t, path, opts), S.answered(Tag, rows_of(Tag, t, path, opts)), exists_rows(Tag, t, path, opts))

def listed_same(b: Bool, +ms: List<&2, H.Method>, +x: List<&2, H.Method>) -> {E.choose(List<&2, H.Method>, b, u => List.append(&2, H.Method, ms, x), u => x) == S.listed_pick(b, ms, x) : List<&2, H.Method>}:
  match b:
    case True{}:
      {==}
    case False{}:
      {==}

def listed_rows(-Tag: Data, +tbl: M.Table(Tag), +path: String, +opts: M.Options) ->
    {M.matching_methods(Tag, tbl, path, opts) == S.listed(Tag, rows_of(Tag, tbl, path, opts)) : List<&2, H.Method>}:
  match tbl:
    case Nil{}:
      {==}
    case R.Route{+p, M.Binding{+methods, +tag}} <> +t:
      %Equal.sym(Bool, Maybe.is_some(&2, P.Params, M.match_path(p, path, opts)), S.hit_some(M.match_path(p, path, opts)), some_same(M.match_path(p, path, opts))) : {E.choose(List<&2, H.Method>, _, u => List.append(&2, H.Method, M.finite(methods), M.matching_methods(Tag, t, path, opts)), u => M.matching_methods(Tag, t, path, opts)) == S.listed(Tag, rows_of(Tag, R.Route{p, M.Binding{methods, tag}} <> t, path, opts)) : List<&2, H.Method>}
      %Equal.sym(List<&2, H.Method>, M.matching_methods(Tag, t, path, opts), S.listed(Tag, rows_of(Tag, t, path, opts)), listed_rows(Tag, t, path, opts)) : {E.choose(List<&2, H.Method>, S.hit_some(M.match_path(p, path, opts)), u => List.append(&2, H.Method, M.finite(methods), _), u => _) == S.listed(Tag, rows_of(Tag, R.Route{p, M.Binding{methods, tag}} <> t, path, opts)) : List<&2, H.Method>}
      listed_same(S.hit_some(M.match_path(p, path, opts)), M.finite(methods), S.listed(Tag, rows_of(Tag, t, path, opts)))

def miss_same(-Tag: Data, a: Bool, +ls: List<&2, H.Method>) -> {M.miss(Tag, a, M.canonical(ls)) == S.missed_pick(Tag, a, ls) : M.Resolution<Tag>}:
  match a:
    case True{}:
      {==}
    case False{}:
      {==}

def missed_rows(-Tag: Data, +tbl: M.Table(Tag), +path: String, +opts: M.Options) ->
    {M.miss(Tag, M.path_exists(Tag, tbl, path, opts), M.canonical(M.matching_methods(Tag, tbl, path, opts))) == S.missed(Tag, rows_of(Tag, tbl, path, opts)) : M.Resolution<Tag>}:
  %Equal.sym(Bool, M.path_exists(Tag, tbl, path, opts), S.answered(Tag, rows_of(Tag, tbl, path, opts)), exists_rows(Tag, tbl, path, opts)) : {M.miss(Tag, _, M.canonical(M.matching_methods(Tag, tbl, path, opts))) == S.missed(Tag, rows_of(Tag, tbl, path, opts)) : M.Resolution<Tag>}
  %Equal.sym(List<&2, H.Method>, M.matching_methods(Tag, tbl, path, opts), S.listed(Tag, rows_of(Tag, tbl, path, opts)), listed_rows(Tag, tbl, path, opts)) : {M.miss(Tag, S.answered(Tag, rows_of(Tag, tbl, path, opts)), M.canonical(_)) == S.missed(Tag, rows_of(Tag, tbl, path, opts)) : M.Resolution<Tag>}
  miss_same(Tag, S.answered(Tag, rows_of(Tag, tbl, path, opts)), S.listed(Tag, rows_of(Tag, tbl, path, opts)))

def fallback_same(-Tag: Data, f: Maybe<&2, R.Match<Tag>>, +tbl: M.Table(Tag), +path: String, +opts: M.Options) ->
    {M.fallback(Tag, f, u => M.miss(Tag, M.path_exists(Tag, tbl, path, opts), M.canonical(M.matching_methods(Tag, tbl, path, opts)))) == S.head_get(Tag, f, rows_of(Tag, tbl, path, opts)) : M.Resolution<Tag>}:
  match f:
    case Some{m}:
      {==}
    case None{}:
      missed_rows(Tag, tbl, path, opts)

def direct(-Tag: Data, hit: Maybe<&2, R.Match<Tag>>, +tbl: M.Table(Tag), +path: String, method: H.Method, +opts: M.Options) ->
    {M.resolve_direct(Tag, hit, tbl, path, method, opts) == S.decided(Tag, hit, rows_of(Tag, tbl, path, opts), method) : M.Resolution<Tag>}:
  match hit:
    case Some{m}:
      {==}
    case None{}:
      match method:
        case H.Head{}:
          %Equal.sym(Maybe<&2, R.Match<Tag>>, M.find(Tag, tbl, path, H.Get{}, opts), S.first(Tag, rows_of(Tag, tbl, path, opts), H.Get{}), find_rows(Tag, tbl, path, H.Get{}, opts)) : {M.fallback(Tag, _, u => M.miss(Tag, M.path_exists(Tag, tbl, path, opts), M.canonical(M.matching_methods(Tag, tbl, path, opts)))) == S.head_get(Tag, S.first(Tag, rows_of(Tag, tbl, path, opts), H.Get{}), rows_of(Tag, tbl, path, opts)) : M.Resolution<Tag>}
          fallback_same(Tag, S.first(Tag, rows_of(Tag, tbl, path, opts), H.Get{}), tbl, path, opts)
        case H.Get{}:
          missed_rows(Tag, tbl, path, opts)
        case H.Post{}:
          missed_rows(Tag, tbl, path, opts)
        case H.Put{}:
          missed_rows(Tag, tbl, path, opts)
        case H.Delete{}:
          missed_rows(Tag, tbl, path, opts)
        case H.Connect{}:
          missed_rows(Tag, tbl, path, opts)
        case H.Options{}:
          missed_rows(Tag, tbl, path, opts)
        case H.Trace{}:
          missed_rows(Tag, tbl, path, opts)
        case H.Patch{}:
          missed_rows(Tag, tbl, path, opts)
        case H.Extension{x}:
          missed_rows(Tag, tbl, path, opts)

def resolve_rows(-Tag: Data, +tbl: M.Table(Tag), +path: String, +method: H.Method, +opts: M.Options) ->
    {M.resolve_direct(Tag, M.find(Tag, tbl, path, method, opts), tbl, path, method, opts) == S.decided(Tag, S.first(Tag, rows_of(Tag, tbl, path, opts), method), rows_of(Tag, tbl, path, opts), method) : M.Resolution<Tag>}:
  %Equal.sym(Maybe<&2, R.Match<Tag>>, M.find(Tag, tbl, path, method, opts), S.first(Tag, rows_of(Tag, tbl, path, opts), method), find_rows(Tag, tbl, path, method, opts)) : {M.resolve_direct(Tag, _, tbl, path, method, opts) == S.decided(Tag, S.first(Tag, rows_of(Tag, tbl, path, opts), method), rows_of(Tag, tbl, path, opts), method) : M.Resolution<Tag>}
  direct(Tag, S.first(Tag, rows_of(Tag, tbl, path, opts), method), tbl, path, method, opts)

# ---- The built table resolves as the rows ----

def final(-Tag: Data, +prefix: String, +routes: Regs(Tag), +path: String, +method: H.Method, +opts: M.Options,
    res: Result<&2, &2, M.BuildError, M.Table(Tag)>, good: {M.BuildValid(Tag, res) == True{} : Bool},
    hyp: {rows_result(Tag, res, path, opts) == Some{S.rows(Tag, prefix, routes, path, opts)} : Maybe<&2, List<&2, S.Row<Tag>>>}) ->
    {ComposeSpec.reference(Tag, T.built(Tag, joined_regs(Tag, prefix, routes), [], M.certify(Tag, res, good)), path, method, opts) == Done{S.resolve(Tag, prefix, routes, path, method, opts)} : Result<&2, &2, M.BuildError, M.Resolution<Tag>>}:
  match res:
    case Fail{x}:
      Core.absurd({ComposeSpec.reference(Tag, T.built(Tag, joined_regs(Tag, prefix, routes), [], M.certify(Tag, Fail{x}, good)), path, method, opts) == Done{S.resolve(Tag, prefix, routes, path, method, opts)} : Result<&2, &2, M.BuildError, M.Resolution<Tag>>}, no_rows(Tag, S.rows(Tag, prefix, routes, path, opts), hyp))
    case Done{+tbl}:
      +same = rows_inj(Tag, rows_of(Tag, tbl, path, opts), S.rows(Tag, prefix, routes, path, opts), hyp)
      Equal.cong(M.Resolution<Tag>, Result<&2, &2, M.BuildError, M.Resolution<Tag>>, z => Done{z}, M.resolve_direct(Tag, M.find(Tag, tbl, path, method, opts), tbl, path, method, opts), S.resolve(Tag, prefix, routes, path, method, opts), Equal.trans(M.Resolution<Tag>, M.resolve_direct(Tag, M.find(Tag, tbl, path, method, opts), tbl, path, method, opts), S.decided(Tag, S.first(Tag, rows_of(Tag, tbl, path, opts), method), rows_of(Tag, tbl, path, opts), method), S.resolve(Tag, prefix, routes, path, method, opts), resolve_rows(Tag, tbl, path, method, opts), Equal.cong(List<&2, S.Row<Tag>>, M.Resolution<Tag>, xs => S.decided(Tag, S.first(Tag, xs, method), xs, method), rows_of(Tag, tbl, path, opts), S.rows(Tag, prefix, routes, path, opts), same)))

def reference_eq(-Tag: Data, +prefix: String, +routes: Regs(Tag), +path: String, +method: H.Method, +opts: M.Options,
    +adm: {S.all_admissible(Tag, prefix, routes) == True{} : Bool}, +valid: {S.methods_valid(Tag, routes) == True{} : Bool}) ->
    {ComposeSpec.reference(Tag, T.build(Tag, ComposeSpec.mount(Tag, prefix, S.entries(Tag, routes))), path, method, opts) == Done{S.resolve(Tag, prefix, routes, path, method, opts)} : Result<&2, &2, M.BuildError, M.Resolution<Tag>>}:
  %Equal.sym(List<&2, T.Entry<Tag>>, ComposeSpec.mount(Tag, prefix, S.entries(Tag, routes)), scoped(Tag, joined_regs(Tag, prefix, routes)), mount_scoped(Tag, prefix, routes)) : {ComposeSpec.reference(Tag, T.build(Tag, _), path, method, opts) == Done{S.resolve(Tag, prefix, routes, path, method, opts)} : Result<&2, &2, M.BuildError, M.Resolution<Tag>>}
  %Equal.sym(Regs(Tag), T.route_entries(Tag, scoped(Tag, joined_regs(Tag, prefix, routes))), joined_regs(Tag, prefix, routes), scoped_routes(Tag, joined_regs(Tag, prefix, routes))) : {ComposeSpec.reference(Tag, T.collected(Tag, _, T.middleware_entries(Tag, scoped(Tag, joined_regs(Tag, prefix, routes)), 0n)), path, method, opts) == Done{S.resolve(Tag, prefix, routes, path, method, opts)} : Result<&2, &2, M.BuildError, M.Resolution<Tag>>}
  %Equal.sym(Result<&2, &2, M.BuildError, List<&2, T.Middleware<Tag>>>, T.middleware_entries(Tag, scoped(Tag, joined_regs(Tag, prefix, routes)), 0n), Done{[]}, mw_done(Tag, prefix, routes, 0n, adm, valid)) : {ComposeSpec.reference(Tag, T.collected(Tag, joined_regs(Tag, prefix, routes), _), path, method, opts) == Done{S.resolve(Tag, prefix, routes, path, method, opts)} : Result<&2, &2, M.BuildError, M.Resolution<Tag>>}
  final(Tag, prefix, routes, path, method, opts, M.build_go(Tag, joined_regs(Tag, prefix, routes), 0n), M.build_go_valid(Tag, joined_regs(Tag, prefix, routes), 0n), rows_build(Tag, prefix, routes, 0n, path, opts, adm, valid))

def L.mount_resolve_spec(Tag, prefix, routes, kind, path, method, opts, admissible, valid):
  Equal.trans(Result<&2, &2, M.BuildError, M.Resolution<Tag>>, ComposeSpec.routed(Tag, kind, T.build(Tag, C.mount(Tag, prefix, S.entries(Tag, routes))), path, method, opts), ComposeSpec.mount_routing(Tag, prefix, S.entries(Tag, routes), path, method, opts), Done{S.resolve(Tag, prefix, routes, path, method, opts)}, CL.compose_mount_routing(Tag, prefix, S.entries(Tag, routes), kind, path, method, opts), reference_eq(Tag, prefix, routes, path, method, opts, admissible, valid))
