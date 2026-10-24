# BND-36: which schemas a built route validates with. The table keeps one
# Scoped record per route that has placements; Table.route_schemas folds the
# record's Checks outer to inner with V.override. This module shows, slot by
# slot, that the fold is the specification's last declaration
# (Spec.effective), following proof/scoped-selection.bend's induction over
# Table.middleware_entries.
import Base
import ../src/app/table.bend as T
import ../src/app/validate.bend as V
import ../src/data/schema-prepared.bend as SP
import ../src/router/methods.bend as M
import ../src/router/pattern.bend as P
import ./validate-spec.bend as Spec
import ./scoped-selection-spec.bend as Routes
import ./scoped-selection.bend as Sel

def MC() -> Data:
  Maybe<&2, SP.Checked>

def fp_none(+a: MC()) -> {Spec.first_present(a, None{}) == a : MC()}:
  match a:
    case None{}: {==}
    case Some{x}: {==}

def fp_assoc(+a: MC(), +b: MC(), +c: MC()) -> {Spec.first_present(a, Spec.first_present(b, c)) == Spec.first_present(Spec.first_present(a, b), c) : MC()}:
  match a:
    case None{}: {==}
    case Some{x}: {==}

def prefer_fp(+o: MC(), +i: MC()) -> {V.prefer(o, i) == Spec.first_present(i, o) : MC()}:
  match i:
    case None{}: {==}
    case Some{c}: {==}

def slot_none(+w: Spec.Which) -> {Spec.slot(w, V.none()) == None{} : MC()}:
  match w:
    case Spec.InParams{}: {==}
    case Spec.InQuery{}: {==}
    case Spec.InHeaders{}: {==}
    case Spec.InBody{}: {==}
    case Spec.InResponse{}: {==}

# An inner set wins wherever it declares the slot.
def override_slot(+w: Spec.Which, +a: V.Schemas, +b: V.Schemas) -> {Spec.slot(w, V.override(a, b)) == Spec.first_present(Spec.slot(w, b), Spec.slot(w, a)) : MC()}:
  match w a b:
    case Spec.InParams{} V.Schemas{p, q, h, x, r} V.Schemas{ip, iq, ih, ix, ir}: prefer_fp(p, ip)
    case Spec.InQuery{} V.Schemas{p, q, h, x, r} V.Schemas{ip, iq, ih, ix, ir}: prefer_fp(q, iq)
    case Spec.InHeaders{} V.Schemas{p, q, h, x, r} V.Schemas{ip, iq, ih, ix, ir}: prefer_fp(h, ih)
    case Spec.InBody{} V.Schemas{p, q, h, x, r} V.Schemas{ip, iq, ih, ix, ir}: prefer_fp(x, ix)
    case Spec.InResponse{} V.Schemas{p, q, h, x, r} V.Schemas{ip, iq, ih, ix, ir}: prefer_fp(r, ir)

# Folding a placement list onto an accumulator: the list's last declaration
# of the slot, else the accumulator's.
def placed(-Tag: Data, +w: Spec.Which, +hooks: List<&2, T.Placement<Tag>>, +acc: V.Schemas) -> {Spec.slot(w, T.placed_schemas(Tag, hooks, acc)) == Spec.first_present(Spec.last_declared(Tag, w, hooks), Spec.slot(w, acc)) : MC()}:
  match hooks:
    case Nil{}: {==}
    case T.Placement{scope, hook} <> tail: placed(Tag, w, tail, acc)
    case T.Checks{scope, +set} <> +tail:
      Equal.trans(MC(), Spec.slot(w, T.placed_schemas(Tag, tail, V.override(acc, set))), Spec.first_present(Spec.last_declared(Tag, w, tail), Spec.slot(w, V.override(acc, set))), Spec.first_present(Spec.first_present(Spec.last_declared(Tag, w, tail), Spec.slot(w, set)), Spec.slot(w, acc)),
        placed(Tag, w, tail, V.override(acc, set)),
        Equal.trans(MC(), Spec.first_present(Spec.last_declared(Tag, w, tail), Spec.slot(w, V.override(acc, set))), Spec.first_present(Spec.last_declared(Tag, w, tail), Spec.first_present(Spec.slot(w, set), Spec.slot(w, acc))), Spec.first_present(Spec.first_present(Spec.last_declared(Tag, w, tail), Spec.slot(w, set)), Spec.slot(w, acc)),
          Equal.cong(MC(), MC(), z => Spec.first_present(Spec.last_declared(Tag, w, tail), z), Spec.slot(w, V.override(acc, set)), Spec.first_present(Spec.slot(w, set), Spec.slot(w, acc)), override_slot(w, acc, set)),
          fp_assoc(Spec.last_declared(Tag, w, tail), Spec.slot(w, set), Spec.slot(w, acc))))

def here(-Tag: Data, +w: Spec.Which, +hooks: List<&2, T.Placement<Tag>>, yes: Bool, +rest: MC()) -> {Spec.first_present(Spec.slot(w, T.schemas_here(Tag, hooks, yes)), rest) == Spec.chosen(yes, Spec.last_declared(Tag, w, hooks), rest) : MC()}:
  match yes:
    case False{}:
      Equal.cong(MC(), MC(), z => Spec.first_present(z, rest), Spec.slot(w, V.none()), None{}, slot_none(w))
    case True{}:
      Equal.cong(MC(), MC(), z => Spec.first_present(z, rest), Spec.slot(w, T.placed_schemas(Tag, hooks, V.none())), Spec.last_declared(Tag, w, hooks),
        Equal.trans(MC(), Spec.slot(w, T.placed_schemas(Tag, hooks, V.none())), Spec.first_present(Spec.last_declared(Tag, w, hooks), Spec.slot(w, V.none())), Spec.last_declared(Tag, w, hooks),
          placed(Tag, w, hooks, V.none()),
          Equal.trans(MC(), Spec.first_present(Spec.last_declared(Tag, w, hooks), Spec.slot(w, V.none())), Spec.first_present(Spec.last_declared(Tag, w, hooks), None{}), Spec.last_declared(Tag, w, hooks),
            Equal.cong(MC(), MC(), z => Spec.first_present(Spec.last_declared(Tag, w, hooks), z), Spec.slot(w, V.none()), None{}, slot_none(w)),
            fp_none(Spec.last_declared(Tag, w, hooks)))))

def chosen_none(yes: Bool, +r: MC()) -> {r == Spec.chosen(yes, None{}, r) : MC()}:
  match yes:
    case True{}: {==}
    case False{}: {==}

def Collected(-Tag: Data, result: Result<&2, &2, M.BuildError, List<&2, T.Middleware<Tag>>>, w: Spec.Which, n: Nat, expected: MC()) -> Type:
  match result:
    case Fail{error}: Unit
    case Done{layers}: {Spec.slot(w, T.route_schemas(Tag, layers, Some{n})) == expected : MC()}

def retag(-Tag: Data, +result: Result<&2, &2, M.BuildError, List<&2, T.Middleware<Tag>>>, +w: Spec.Which, +n: Nat, +a: MC(), +b: MC(), same: {a == b : MC()}, proof: Collected(Tag, result, w, n, a)) -> Collected(Tag, result, w, n, b):
  match result:
    case Fail{error}: Unit{}
    case Done{layers}: Equal.trans(MC(), Spec.slot(w, T.route_schemas(Tag, layers, Some{n})), a, b, proof, same)

def prepend_use(-Tag: Data, +pattern: Maybe<&2, P.Pattern>, +tag: Tag, +rest: Result<&2, &2, M.BuildError, List<&2, T.Middleware<Tag>>>, +w: Spec.Which, +n: Nat, +expected: MC(), proof: Collected(Tag, rest, w, n, expected)) -> Collected(Tag, T.prepend(Tag, T.Middleware{pattern, tag}, rest), w, n, expected):
  match rest:
    case Fail{error}: Unit{}
    case Done{layers}: proof

def prepend_hook(-Tag: Data, +kind: T.Stage, +tag: Tag, +rest: Result<&2, &2, M.BuildError, List<&2, T.Middleware<Tag>>>, +w: Spec.Which, +n: Nat, +expected: MC(), proof: Collected(Tag, rest, w, n, expected)) -> Collected(Tag, T.prepend(Tag, T.Staged{kind, tag}, rest), w, n, expected):
  match rest:
    case Fail{error}: Unit{}
    case Done{layers}: proof

def pattern_built(-Tag: Data, +index: Nat, +source: String, +tag: Tag, +pattern: Result<&2, &2, P.PatternError, P.Pattern>, +rest: Result<&2, &2, M.BuildError, List<&2, T.Middleware<Tag>>>, +w: Spec.Which, +n: Nat, +expected: MC(), proof: Collected(Tag, rest, w, n, expected)) -> Collected(Tag, T.pattern_built(Tag, index, source, tag, pattern, u => rest), w, n, expected):
  match pattern:
    case Fail{error}: Unit{}
    case Done{p}: prepend_use(Tag, Some{p}, tag, rest, w, n, expected, proof)

def route_checked(-Tag: Data, +index: Nat, +checked: Result<&2, &2, M.BuildError, M.Valid<Tag>>, +rest: Result<&2, &2, M.BuildError, List<&2, T.Middleware<Tag>>>, +w: Spec.Which, +n: Nat, +expected: MC(), proof: Collected(Tag, rest, w, n, expected)) -> Collected(Tag, T.route_checked(Tag, index, checked, u => rest), w, n, expected):
  match checked:
    case Fail{M.InvalidPattern{old, source, error}}: Unit{}
    case Fail{M.InvalidMethod{old, source, token}}: Unit{}
    case Done{table}: proof

def prepend_record(-Tag: Data, +ordinal: Nat, +hooks: List<&2, T.Placement<Tag>>, +rest: Result<&2, &2, M.BuildError, List<&2, T.Middleware<Tag>>>, +w: Spec.Which, +n: Nat, +expected: MC(), proof: Collected(Tag, rest, w, n, expected)) -> Collected(Tag, T.prepend(Tag, T.Scoped{ordinal, hooks}, rest), w, n, Spec.chosen(Nat.is_eq(ordinal, n), Spec.last_declared(Tag, w, hooks), expected)):
  match rest:
    case Fail{error}: Unit{}
    case Done{layers}:
      Equal.trans(MC(), Spec.slot(w, V.override(T.route_schemas(Tag, layers, Some{n}), T.schemas_here(Tag, hooks, Nat.is_eq(ordinal, n)))), Spec.first_present(Spec.slot(w, T.schemas_here(Tag, hooks, Nat.is_eq(ordinal, n))), Spec.slot(w, T.route_schemas(Tag, layers, Some{n}))), Spec.chosen(Nat.is_eq(ordinal, n), Spec.last_declared(Tag, w, hooks), expected),
        override_slot(w, T.route_schemas(Tag, layers, Some{n}), T.schemas_here(Tag, hooks, Nat.is_eq(ordinal, n))),
        Equal.trans(MC(), Spec.first_present(Spec.slot(w, T.schemas_here(Tag, hooks, Nat.is_eq(ordinal, n))), Spec.slot(w, T.route_schemas(Tag, layers, Some{n}))), Spec.first_present(Spec.slot(w, T.schemas_here(Tag, hooks, Nat.is_eq(ordinal, n))), expected), Spec.chosen(Nat.is_eq(ordinal, n), Spec.last_declared(Tag, w, hooks), expected),
          Equal.cong(MC(), MC(), z => Spec.first_present(Spec.slot(w, T.schemas_here(Tag, hooks, Nat.is_eq(ordinal, n))), z), Spec.slot(w, T.route_schemas(Tag, layers, Some{n})), expected, proof),
          here(Tag, w, hooks, Nat.is_eq(ordinal, n), expected)))

# A route without placements gets no record; it declares nothing either.
def prepend_scoped(-Tag: Data, +hooks: List<&2, T.Placement<Tag>>, +tail: List<&2, T.Entry<Tag>>, +rest: Result<&2, &2, M.BuildError, List<&2, T.Middleware<Tag>>>, +w: Spec.Which, +n: Nat, +expected: MC(), proof: Collected(Tag, rest, w, n, expected)) -> Collected(Tag, T.prepend_scoped(Tag, hooks, tail, rest), w, n, Spec.chosen(Nat.is_eq(List.length(&2, M.Registration(Tag), T.route_entries(Tag, tail)), n), Spec.last_declared(Tag, w, hooks), expected)):
  match hooks:
    case Nil{}:
      retag(Tag, rest, w, n, expected, Spec.chosen(Nat.is_eq(List.length(&2, M.Registration(Tag), T.route_entries(Tag, tail)), n), None{}, expected), chosen_none(Nat.is_eq(List.length(&2, M.Registration(Tag), T.route_entries(Tag, tail)), n), expected), proof)
    case h <> t:
      prepend_record(Tag, List.length(&2, M.Registration(Tag), T.route_entries(Tag, tail)), h <> t, rest, w, n, expected, proof)

def expected(-Tag: Data, +r: M.Registration(Tag), +ps: List<&2, T.Placement<Tag>>, +tail: List<&2, T.Entry<Tag>>, +w: Spec.Which, +n: Nat) -> {Spec.chosen(Nat.is_eq(List.length(&2, M.Registration(Tag), T.route_entries(Tag, tail)), n), Spec.last_declared(Tag, w, ps), Spec.find(Tag, w, tail, n)) == Spec.find(Tag, w, T.ScopedRoute{r, ps} <> tail, n) : MC()}:
  Equal.cong(Nat, MC(), k => Spec.chosen(Nat.is_eq(k, n), Spec.last_declared(Tag, w, ps), Spec.find(Tag, w, tail, n)), List.length(&2, M.Registration(Tag), T.route_entries(Tag, tail)), Routes.route_count(Tag, tail), Sel.source_count(Tag, tail))

def entries(-Tag: Data, +xs: List<&2, T.Entry<Tag>>, +index: Nat, +w: Spec.Which, +n: Nat) -> Collected(Tag, T.middleware_entries(Tag, xs, index), w, n, Spec.find(Tag, w, xs, n)):
  match xs:
    case Nil{}: slot_none(w)
    case T.Hook{kind, tag} <> tail:
      prepend_hook(Tag, kind, tag, T.middleware_entries(Tag, tail, 1n+index), w, n, Spec.find(Tag, w, tail, n), entries(Tag, tail, 1n+index, w, n))
    case T.Route{r} <> tail:
      route_checked(Tag, index, M.build_table(Tag, [r]), T.middleware_entries(Tag, tail, 1n+index), w, n, Spec.find(Tag, w, tail, n), entries(Tag, tail, 1n+index, w, n))
    case T.ScopedRoute{r, hooks} <> tail:
      retag(Tag, T.middleware_entries(Tag, T.ScopedRoute{r, hooks} <> tail, index), w, n, Spec.chosen(Nat.is_eq(List.length(&2, M.Registration(Tag), T.route_entries(Tag, tail)), n), Spec.last_declared(Tag, w, hooks), Spec.find(Tag, w, tail, n)), Spec.find(Tag, w, T.ScopedRoute{r, hooks} <> tail, n), expected(Tag, r, hooks, tail, w, n),
        route_checked(Tag, index, M.build_table(Tag, [r]), T.prepend_scoped(Tag, hooks, tail, T.middleware_entries(Tag, tail, 1n+index)), w, n, Spec.chosen(Nat.is_eq(List.length(&2, M.Registration(Tag), T.route_entries(Tag, tail)), n), Spec.last_declared(Tag, w, hooks), Spec.find(Tag, w, tail, n)),
          prepend_scoped(Tag, hooks, tail, T.middleware_entries(Tag, tail, 1n+index), w, n, Spec.find(Tag, w, tail, n), entries(Tag, tail, 1n+index, w, n))))
    case T.Use{None{}, tag} <> tail:
      prepend_use(Tag, None{}, tag, T.middleware_entries(Tag, tail, 1n+index), w, n, Spec.find(Tag, w, tail, n), entries(Tag, tail, 1n+index, w, n))
    case T.Use{Some{source}, tag} <> tail:
      pattern_built(Tag, index, source, tag, P.compile(source), T.middleware_entries(Tag, tail, 1n+index), w, n, Spec.find(Tag, w, tail, n), entries(Tag, tail, 1n+index, w, n))
    case T.PrefixedUse{source, tag} <> tail:
      pattern_built(Tag, index, source, tag, P.compile(source), T.middleware_entries(Tag, tail, 1n+index), w, n, Spec.find(Tag, w, tail, n), entries(Tag, tail, 1n+index, w, n))

def Built(-Tag: Data, result: Result<&2, &2, M.BuildError, T.Table<Tag>>, w: Spec.Which, n: Nat, expected: MC()) -> Type:
  match result:
    case Fail{error}: Unit
    case Done{T.Table{routes, compiled, layers, count}}: {Spec.slot(w, T.route_schemas(Tag, layers, Some{n})) == expected : MC()}

def built(-Tag: Data, +routes: List<&2, M.Registration(Tag)>, +layers: List<&2, T.Middleware<Tag>>, +result: Result<&2, &2, M.BuildError, M.Valid<Tag>>, +w: Spec.Which, +n: Nat, +expected: MC(), proof: {Spec.slot(w, T.route_schemas(Tag, layers, Some{n})) == expected : MC()}) -> Built(Tag, T.built(Tag, routes, layers, result), w, n, expected):
  match result:
    case Fail{error}: Unit{}
    case Done{table}: proof

def collected(-Tag: Data, +routes: List<&2, M.Registration(Tag)>, +result: Result<&2, &2, M.BuildError, List<&2, T.Middleware<Tag>>>, +w: Spec.Which, +n: Nat, +expected: MC(), proof: Collected(Tag, result, w, n, expected)) -> Built(Tag, T.collected(Tag, routes, result), w, n, expected):
  match result:
    case Fail{error}: Unit{}
    case Done{layers}: built(Tag, routes, layers, M.build_table(Tag, routes), w, n, expected, proof)

def selection(-Tag: Data, +xs: List<&2, T.Entry<Tag>>, +routes: List<&2, M.Registration(Tag)>, +compiled: M.Index<Tag>, +layers: List<&2, T.Middleware<Tag>>, +count: Nat, +w: Spec.Which, +n: Nat, built: {T.build(Tag, xs) == Done{T.Table{routes, compiled, layers, count}} : Result<&2, &2, M.BuildError, T.Table<Tag>>}) -> {Spec.slot(w, T.route_schemas(Tag, layers, Some{n})) == Spec.find(Tag, w, xs, n) : MC()}:
  %built : Built(Tag, _, w, n, Spec.find(Tag, w, xs, n))
  collected(Tag, T.route_entries(Tag, xs), T.middleware_entries(Tag, xs, 0n), w, n, Spec.find(Tag, w, xs, n), entries(Tag, xs, 0n, w, n))

# No route, no schemas.
def no_route(-Tag: Data, +layers: List<&2, T.Middleware<Tag>>, +w: Spec.Which) -> {Spec.slot(w, T.route_schemas(Tag, layers, None{})) == None{} : MC()}:
  match layers:
    case Nil{}: slot_none(w)
    case T.Scoped{index, hooks} <> tail: slot_none(w)
    case T.Staged{stage, tag} <> tail: no_route(Tag, tail, w)
    case T.Middleware{pattern, tag} <> tail: no_route(Tag, tail, w)

def innermost(-Tag: Data, +xs: List<&2, T.Entry<Tag>>, +routes: List<&2, M.Registration(Tag)>, +compiled: M.Index<Tag>, +layers: List<&2, T.Middleware<Tag>>, +count: Nat, +route: Maybe<&2, Nat>, +w: Spec.Which, built: {T.build(Tag, xs) == Done{T.Table{routes, compiled, layers, count}} : Result<&2, &2, M.BuildError, T.Table<Tag>>}) -> {Spec.slot(w, T.route_schemas(Tag, layers, route)) == Spec.effective(Tag, w, xs, route) : MC()}:
  match route:
    case None{}: no_route(Tag, layers, w)
    case Some{n}: selection(Tag, xs, routes, compiled, layers, count, w, n, built)
