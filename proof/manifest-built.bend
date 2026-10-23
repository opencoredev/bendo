# A successful build's manifest equals the entry-level specification. The proof
# follows the real builder: build_go, certify, prepare, built and collected.
import Base
import ../src/app/manifest.bend as O
import ../src/app/table.bend as T
import ../src/router/pattern.bend as P
import ../src/router/spec.bend as S
import ../src/router/methods.bend as M
import ../src/http/request.bend as R
import ./manifest-spec.bend as Names
import ./manifest.bend as Proved
import ./manifest-built-spec.bend as Spec

def regs(-Tag: Data, xs: List<&2, M.Registration(Tag)>) -> List<&2, O.Row>:
  match xs:
    case Nil{}: []
    case r <> t: List.append(&2, O.Row, Spec.registration(Tag, r), regs(Tag, t))

def finite(+xs: List<&2, R.Method>, +path: String, +params: List<&2, String>) -> {O.methods(M.normalize_methods(xs), path, params) == Spec.finite(xs, path, params) : List<&2, O.Row>}:
  match xs:
    case Nil{}: {==}
    case h <> t:
      Equal.cong(List<&2, O.Row>, List<&2, O.Row>, rows => O.Row{Spec.normal(h), False{}, path, params} <> rows, O.methods(M.normalize_methods(t), path, params), Spec.finite(t, path, params), finite(t, path, params))

def selector(+ms: M.MethodSelector, +path: String, +segments: List<&2, P.Segment>) -> {O.selector(M.normalize_selector(ms), path, O.names(segments)) == Spec.rows(ms, path, Names.names(segments)) : List<&2, O.Row>}:
  match ms:
    case M.AllMethods{}:
      Equal.cong(List<&2, String>, List<&2, O.Row>, ns => [O.Row{"ALL", True{}, path, ns}], O.names(segments), Names.names(segments), Proved.names(segments))
    case M.OnlyMethods{methods}:
      %Equal.sym(List<&2, String>, O.names(segments), Names.names(segments), Proved.names(segments)) : {O.methods(M.normalize_methods(methods), path, _) == Spec.rows(ms, path, Names.names(segments)) : List<&2, O.Row>}
      finite(methods, path, Names.names(segments))

# Vacuous on a failed build, exact on the table a success stores.
def GoRows(-Tag: Data, result: Result<&2, &2, M.BuildError, M.Table(Tag)>, sources: List<&2, M.Registration(Tag)>, expected: List<&2, O.Row>) -> Type:
  match result:
    case Fail{error}: Unit
    case Done{table}: {O.describe(Tag, sources, table) == expected : List<&2, O.Row>}

def prepend_step(-Tag: Data, +segments: List<&2, P.Segment>, +source: String, +ms: M.MethodSelector, +tag: Tag, +sources: List<&2, M.Registration(Tag)>, +result: Result<&2, &2, M.BuildError, M.Table(Tag)>, proof: GoRows(Tag, result, sources, regs(Tag, sources))) -> GoRows(Tag, M.prepend_built(Tag, P.Pattern{segments}, M.Binding{M.normalize_selector(ms), tag}, result), S.Registration{source, M.Binding{ms, tag}} <> sources, List.append(&2, O.Row, Spec.rows(ms, source, Names.names(segments)), regs(Tag, sources))):
  match result:
    case Fail{error}: Unit{}
    case Done{table}:
      %Equal.sym(List<&2, O.Row>, O.selector(M.normalize_selector(ms), source, O.names(segments)), Spec.rows(ms, source, Names.names(segments)), selector(ms, source, segments)) : {List.append(&2, O.Row, _, O.describe(Tag, sources, table)) == List.append(&2, O.Row, Spec.rows(ms, source, Names.names(segments)), regs(Tag, sources)) : List<&2, O.Row>}
      Equal.cong(List<&2, O.Row>, List<&2, O.Row>, rows => List.append(&2, O.Row, Spec.rows(ms, source, Names.names(segments)), rows), O.describe(Tag, sources, table), regs(Tag, sources), proof)

def pattern_step(-Tag: Data, +index: Nat, +source: String, +ms: M.MethodSelector, +tag: Tag, +sources: List<&2, M.Registration(Tag)>, +compiled: Result<&2, &2, P.PatternError, P.Pattern>, rest: Unit -> Result<&2, &2, M.BuildError, M.Table(Tag)>, good: GoRows(Tag, rest(Unit{}), sources, regs(Tag, sources))) -> GoRows(Tag, M.build_pattern(Tag, index, source, M.Binding{M.normalize_selector(ms), tag}, compiled, rest), S.Registration{source, M.Binding{ms, tag}} <> sources, List.append(&2, O.Row, Spec.rows(ms, source, Spec.captures(compiled)), regs(Tag, sources))):
  match compiled:
    case Fail{error}: Unit{}
    case Done{P.Pattern{segments}}: prepend_step(Tag, segments, source, ms, tag, sources, rest(Unit{}), good)

def methods_step(-Tag: Data, +index: Nat, +source: String, +ms: M.MethodSelector, +tag: Tag, +sources: List<&2, M.Registration(Tag)>, +invalid: Maybe<&2, String>, rest: Unit -> Result<&2, &2, M.BuildError, M.Table(Tag)>, -checked: M.InvalidChecked(M.finite(M.normalize_selector(ms)), invalid), good: GoRows(Tag, rest(Unit{}), sources, regs(Tag, sources))) -> GoRows(Tag, M.build_methods(Tag, index, source, M.normalize_selector(ms), tag, invalid, checked, rest), S.Registration{source, M.Binding{ms, tag}} <> sources, regs(Tag, S.Registration{source, M.Binding{ms, tag}} <> sources)):
  match invalid:
    case Some{token}: Unit{}
    case None{}: pattern_step(Tag, index, source, ms, tag, sources, P.compile(source), rest, good)

def go(-Tag: Data, +sources: List<&2, M.Registration(Tag)>, +index: Nat) -> GoRows(Tag, M.build_go(Tag, sources, index), sources, regs(Tag, sources)):
  match sources:
    case Nil{}: {==}
    case S.Registration{+source, M.Binding{+methods, +tag}} <> +tail:
      +normalized = M.normalize_selector(methods)
      methods_step(Tag, index, source, methods, tag, tail, M.invalid_method(M.finite(normalized)), u => M.build_go(Tag, tail, 1n+index), M.invalid_checked(M.finite(normalized)), go(Tag, tail, 1n+index))

def BuiltRows(-Tag: Data, result: Result<&2, &2, M.BuildError, T.Table<Tag>>, expected: List<&2, O.Row>) -> Type:
  match result:
    case Fail{error}: Unit
    case Done{table}: {O.rows(Tag, table) == expected : List<&2, O.Row>}

# The stored index wraps the certified table unchanged, so rows read it back.
def certified(-Tag: Data, +routes: List<&2, M.Registration(Tag)>, +layers: List<&2, T.Middleware<Tag>>, +result: Result<&2, &2, M.BuildError, M.Table(Tag)>, good: {M.BuildValid(Tag, result) == True{} : Bool}, proof: GoRows(Tag, result, routes, regs(Tag, routes))) -> BuiltRows(Tag, T.built(Tag, routes, layers, M.certify(Tag, result, good)), regs(Tag, routes)):
  match result:
    case Fail{error}: Unit{}
    case Done{table}: proof

def collected(-Tag: Data, +routes: List<&2, M.Registration(Tag)>, +result: Result<&2, &2, M.BuildError, List<&2, T.Middleware<Tag>>>, proof: GoRows(Tag, M.build_go(Tag, routes, 0n), routes, regs(Tag, routes))) -> BuiltRows(Tag, T.collected(Tag, routes, result), regs(Tag, routes)):
  match result:
    case Fail{error}: Unit{}
    case Done{layers}: certified(Tag, routes, layers, M.build_go(Tag, routes, 0n), M.build_go_valid(Tag, routes, 0n), proof)

def enumerated(-Tag: Data, +xs: List<&2, T.Entry<Tag>>) -> {regs(Tag, T.route_entries(Tag, xs)) == Spec.enumerate(Tag, xs) : List<&2, O.Row>}:
  match xs:
    case Nil{}: {==}
    case T.Route{r} <> tail:
      Equal.cong(List<&2, O.Row>, List<&2, O.Row>, rows => List.append(&2, O.Row, Spec.registration(Tag, r), rows), regs(Tag, T.route_entries(Tag, tail)), Spec.enumerate(Tag, tail), enumerated(Tag, tail))
    case T.ScopedRoute{r, hooks} <> tail:
      Equal.cong(List<&2, O.Row>, List<&2, O.Row>, rows => List.append(&2, O.Row, Spec.registration(Tag, r), rows), regs(Tag, T.route_entries(Tag, tail)), Spec.enumerate(Tag, tail), enumerated(Tag, tail))
    case T.Hook{stage, tag} <> tail: enumerated(Tag, tail)
    case T.Use{source, tag} <> tail: enumerated(Tag, tail)
    case T.PrefixedUse{source, tag} <> tail: enumerated(Tag, tail)

def built_rows(-Tag: Data, +entries: List<&2, T.Entry<Tag>>, +table: T.Table<Tag>, built: {T.build(Tag, entries) == Done{table} : Result<&2, &2, M.BuildError, T.Table<Tag>>}) -> {O.rows(Tag, table) == Spec.enumerate(Tag, entries) : List<&2, O.Row>}:
  %built : BuiltRows(Tag, _, Spec.enumerate(Tag, entries))
  %enumerated(Tag, entries) : BuiltRows(Tag, T.build(Tag, entries), _)
  collected(Tag, T.route_entries(Tag, entries), T.middleware_entries(Tag, entries, 0n), go(Tag, T.route_entries(Tag, entries), 0n))
