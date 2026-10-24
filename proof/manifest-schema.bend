# Proofs of the BND-37 manifest attachment laws: schemas never change the
# rows, they sit on the rows of their own registration, and attachment
# succeeds exactly on a full count of valid schemas.
import Base
import ../src/app/manifest.bend as O
import ../src/app/manifest-schemas.bend as MS
import ../src/app/route-schemas.bend as RS
import ../src/app/table.bend as T
import ../src/data/schema.bend as S
import ../src/router/pattern.bend as P
import ../src/router/spec.bend as R
import ../src/router/methods.bend as M
import ./manifest-spec.bend as Rows
import ./manifest.bend as Proved
import ./manifest-schema-spec.bend as Spec

def true_type(b: Bool) -> Type:
  match b:
    case True{}: Unit
    case False{}: Empty

def false_true(e: {False{} == True{} : Bool}) -> Empty:
  %Equal.sym(Bool, False{}, True{}, e) : true_type(_)
  Unit{}

def absurd(-A: Type, impossible: Empty) -> A:
  match impossible:

def rows_tagged(+rows: List<&2, O.Row>, +route: Nat, +x: RS.RouteSchemas, +rest: List<&2, MS.Attached>) -> {MS.attached_rows(List.append(&2, MS.Attached, MS.tag_rows(rows, route, x), rest)) == List.append(&2, O.Row, rows, MS.attached_rows(rest)) : List<&2, O.Row>}:
  match rows:
    case Nil{}: {==}
    case r <> t:
      Equal.cong(List<&2, O.Row>, List<&2, O.Row>, ys => r <> ys, MS.attached_rows(List.append(&2, MS.Attached, MS.tag_rows(t, route, x), rest)), List.append(&2, O.Row, t, MS.attached_rows(rest)), rows_tagged(t, route, x, rest))

def schemas_tagged(+rows: List<&2, O.Row>, +route: Nat, +x: RS.RouteSchemas, +rest: List<&2, MS.Attached>) -> {MS.attached_schemas(List.append(&2, MS.Attached, MS.tag_rows(rows, route, x), rest)) == List.append(&2, RS.RouteSchemas, Spec.copies(List.length(&2, O.Row, rows), x), MS.attached_schemas(rest)) : List<&2, RS.RouteSchemas>}:
  match rows:
    case Nil{}: {==}
    case r <> t:
      Equal.cong(List<&2, RS.RouteSchemas>, List<&2, RS.RouteSchemas>, ys => x <> ys, MS.attached_schemas(List.append(&2, MS.Attached, MS.tag_rows(t, route, x), rest)), List.append(&2, RS.RouteSchemas, Spec.copies(List.length(&2, O.Row, t), x), MS.attached_schemas(rest)), schemas_tagged(t, route, x, rest))

# With as many entries as registrations, the paired rows are the specification's.
def pairs_rows(-Tag: Data, +xs: List<&2, M.Registration(Tag)>, +table: M.Table(Tag), +ss: List<&2, RS.RouteSchemas>, +route: Nat, same: {Nat.is_eq(List.length(&2, M.Registration(Tag), xs), List.length(&2, RS.RouteSchemas, ss)) == True{} : Bool}) -> {MS.attached_rows(MS.pairs(Tag, xs, table, ss, route)) == Rows.describe(Tag, xs, table) : List<&2, O.Row>}:
  match xs table ss:
    case R.Registration{path, unused} <> xt R.Route{P.Pattern{segments}, M.Binding{methods, tag}} <> tt x <> st:
      %Equal.sym(List<&2, O.Row>, MS.attached_rows(List.append(&2, MS.Attached, MS.tag_rows(O.selector(methods, path, O.names(segments)), route, x), MS.pairs(Tag, xt, tt, st, 1n+route))), List.append(&2, O.Row, O.selector(methods, path, O.names(segments)), MS.attached_rows(MS.pairs(Tag, xt, tt, st, 1n+route))), rows_tagged(O.selector(methods, path, O.names(segments)), route, x, MS.pairs(Tag, xt, tt, st, 1n+route))) : {_ == Rows.describe(Tag, xs, table) : List<&2, O.Row>}
      %Proved.selector(methods, path, segments) : {List.append(&2, O.Row, O.selector(methods, path, O.names(segments)), MS.attached_rows(MS.pairs(Tag, xt, tt, st, 1n+route))) == List.append(&2, O.Row, _, Rows.describe(Tag, xt, tt)) : List<&2, O.Row>}
      Equal.cong(List<&2, O.Row>, List<&2, O.Row>, ys => List.append(&2, O.Row, O.selector(methods, path, O.names(segments)), ys), MS.attached_rows(MS.pairs(Tag, xt, tt, st, 1n+route)), Rows.describe(Tag, xt, tt), pairs_rows(Tag, xt, tt, st, 1n+route, same))
    case R.Registration{path, unused} <> xt R.Route{P.Pattern{segments}, M.Binding{methods, tag}} <> tt Nil{}:
      absurd({MS.attached_rows(MS.pairs(Tag, xs, table, ss, route)) == Rows.describe(Tag, xs, table) : List<&2, O.Row>}, false_true(same))
    case Nil{} _ _: {==}
    case _ Nil{} _: {==}

def pairs_schemas(-Tag: Data, +xs: List<&2, M.Registration(Tag)>, +table: M.Table(Tag), +ss: List<&2, RS.RouteSchemas>, +route: Nat) -> {MS.attached_schemas(MS.pairs(Tag, xs, table, ss, route)) == Spec.spread(Tag, xs, table, ss) : List<&2, RS.RouteSchemas>}:
  match xs table ss:
    case R.Registration{path, unused} <> xt R.Route{P.Pattern{segments}, M.Binding{methods, tag}} <> tt x <> st:
      %Equal.sym(List<&2, RS.RouteSchemas>, MS.attached_schemas(List.append(&2, MS.Attached, MS.tag_rows(O.selector(methods, path, O.names(segments)), route, x), MS.pairs(Tag, xt, tt, st, 1n+route))), List.append(&2, RS.RouteSchemas, Spec.copies(List.length(&2, O.Row, O.selector(methods, path, O.names(segments))), x), MS.attached_schemas(MS.pairs(Tag, xt, tt, st, 1n+route))), schemas_tagged(O.selector(methods, path, O.names(segments)), route, x, MS.pairs(Tag, xt, tt, st, 1n+route))) : {_ == Spec.spread(Tag, xs, table, ss) : List<&2, RS.RouteSchemas>}
      %Proved.selector(methods, path, segments) : {List.append(&2, RS.RouteSchemas, Spec.copies(List.length(&2, O.Row, O.selector(methods, path, O.names(segments))), x), MS.attached_schemas(MS.pairs(Tag, xt, tt, st, 1n+route))) == List.append(&2, RS.RouteSchemas, Spec.copies(List.length(&2, O.Row, _), x), Spec.spread(Tag, xt, tt, st)) : List<&2, RS.RouteSchemas>}
      Equal.cong(List<&2, RS.RouteSchemas>, List<&2, RS.RouteSchemas>, ys => List.append(&2, RS.RouteSchemas, Spec.copies(List.length(&2, O.Row, O.selector(methods, path, O.names(segments))), x), ys), MS.attached_schemas(MS.pairs(Tag, xt, tt, st, 1n+route)), Spec.spread(Tag, xt, tt, st), pairs_schemas(Tag, xt, tt, st, 1n+route))
    case Nil{} _ _: {==}
    case _ Nil{} _: {==}
    case _ _ Nil{}: {==}

def RowsOf(-Tag: Data, r: Result<&2, &2, MS.AttachError, List<&2, MS.Attached>>, expected: List<&2, O.Row>) -> Type:
  match r:
    case Fail{e}: Unit
    case Done{ps}: {MS.attached_rows(ps) == expected : List<&2, O.Row>}

def SchemasOf(r: Result<&2, &2, MS.AttachError, List<&2, MS.Attached>>, expected: List<&2, RS.RouteSchemas>) -> Type:
  match r:
    case Fail{e}: Unit
    case Done{ps}: {MS.attached_schemas(ps) == expected : List<&2, RS.RouteSchemas>}

def gate_rows(-Tag: Data, +same: Bool, +found: Maybe<&2, MS.AttachError>, +routes: Nat, +schemas: Nat, +xs: List<&2, M.Registration(Tag)>, +table: M.Table(Tag), +ss: List<&2, RS.RouteSchemas>, e: {Nat.is_eq(List.length(&2, M.Registration(Tag), xs), List.length(&2, RS.RouteSchemas, ss)) == same : Bool}) -> RowsOf(Tag, MS.gate(Tag, same, found, routes, schemas, xs, table, ss), Rows.describe(Tag, xs, table)):
  match same found:
    case False{} _: Unit{}
    case True{} Some{err}: Unit{}
    case True{} None{}: pairs_rows(Tag, xs, table, ss, 0n, e)

def gate_schemas(-Tag: Data, +same: Bool, +found: Maybe<&2, MS.AttachError>, +routes: Nat, +schemas: Nat, +xs: List<&2, M.Registration(Tag)>, +table: M.Table(Tag), +ss: List<&2, RS.RouteSchemas>) -> SchemasOf(MS.gate(Tag, same, found, routes, schemas, xs, table, ss), Spec.spread(Tag, xs, table, ss)):
  match same found:
    case False{} _: Unit{}
    case True{} Some{err}: Unit{}
    case True{} None{}: pairs_schemas(Tag, xs, table, ss, 0n)

def attached_rows(-Tag: Data, +sources: List<&2, M.Registration(Tag)>, +compiled: M.Index<Tag>, +layers: List<&2, T.Middleware<Tag>>, +count: Nat, +ss: List<&2, RS.RouteSchemas>, +ps: List<&2, MS.Attached>, done: {MS.attach(Tag, T.Table{sources, compiled, layers, count}, ss) == Done{ps} : Result<&2, &2, MS.AttachError, List<&2, MS.Attached>>}) -> {MS.attached_rows(ps) == Rows.describe(Tag, sources, M.raw(Tag, M.index_valid(Tag, compiled))) : List<&2, O.Row>}:
  %done : RowsOf(Tag, _, Rows.describe(Tag, sources, M.raw(Tag, M.index_valid(Tag, compiled))))
  gate_rows(Tag, Nat.is_eq(List.length(&2, M.Registration(Tag), sources), List.length(&2, RS.RouteSchemas, ss)), MS.problem(ss, 0n), List.length(&2, M.Registration(Tag), sources), List.length(&2, RS.RouteSchemas, ss), sources, M.raw(Tag, M.index_valid(Tag, compiled)), ss, {==})

def attached_schemas(-Tag: Data, +sources: List<&2, M.Registration(Tag)>, +compiled: M.Index<Tag>, +layers: List<&2, T.Middleware<Tag>>, +count: Nat, +ss: List<&2, RS.RouteSchemas>, +ps: List<&2, MS.Attached>, done: {MS.attach(Tag, T.Table{sources, compiled, layers, count}, ss) == Done{ps} : Result<&2, &2, MS.AttachError, List<&2, MS.Attached>>}) -> {MS.attached_schemas(ps) == Spec.spread(Tag, sources, M.raw(Tag, M.index_valid(Tag, compiled)), ss) : List<&2, RS.RouteSchemas>}:
  %done : SchemasOf(_, Spec.spread(Tag, sources, M.raw(Tag, M.index_valid(Tag, compiled)), ss))
  gate_schemas(Tag, Nat.is_eq(List.length(&2, M.Registration(Tag), sources), List.length(&2, RS.RouteSchemas, ss)), MS.problem(ss, 0n), List.length(&2, M.Registration(Tag), sources), List.length(&2, RS.RouteSchemas, ss), sources, M.raw(Tag, M.index_valid(Tag, compiled)), ss)

# Acceptance.
def none(m: Maybe<&2, String>) -> Bool:
  match m:
    case None{}: True{}
    case Some{x}: False{}

def no_error(m: Maybe<&2, MS.AttachError>) -> Bool:
  match m:
    case None{}: True{}
    case Some{x}: False{}

def blame(+ok: Bool, +name: String, +rest: Maybe<&2, String>) -> {none(RS.blame(ok, name, rest)) == (ok && none(rest)) : Bool}:
  match ok:
    case True{}: {==}
    case False{}: {==}

def slot(+name: String, +s: Maybe<&2, S.Schema>, +rest: Maybe<&2, String>) -> {none(RS.slot(name, s, rest)) == (Spec.slot_ok(s) && none(rest)) : Bool}:
  match s:
    case None{}: {==}
    case Some{x}: blame(S.valid(x), name, rest)

def and_right(+a: Bool, +b: Bool, +c: Bool, e: {b == c : Bool}) -> {(a && b) == (a && c) : Bool}:
  Equal.cong(Bool, Bool, z => a && z, b, c, e)

def chain(+name: String, +s: Maybe<&2, S.Schema>, +rest: Maybe<&2, String>, +tail: Bool, e: {none(rest) == tail : Bool}) -> {none(RS.slot(name, s, rest)) == (Spec.slot_ok(s) && tail) : Bool}:
  Equal.trans(Bool, none(RS.slot(name, s, rest)), Spec.slot_ok(s) && none(rest), Spec.slot_ok(s) && tail, slot(name, s, rest), and_right(Spec.slot_ok(s), none(rest), tail, e))

def last_blame(+ok: Bool, +name: String) -> {none(RS.blame(ok, name, None{})) == ok : Bool}:
  match ok:
    case True{}: {==}
    case False{}: {==}

def last(+name: String, +s: Maybe<&2, S.Schema>) -> {none(RS.slot(name, s, None{})) == Spec.slot_ok(s) : Bool}:
  match s:
    case None{}: {==}
    case Some{x}: last_blame(S.valid(x), name)

def invalid_slot(+x: RS.RouteSchemas) -> {none(RS.invalid_slot(x)) == Spec.slots_ok(x) : Bool}:
  match x:
    case RS.RouteSchemas{p, q, h, b, r}:
      +r5 = RS.slot("response", r, None{})
      +r4 = RS.slot("body", b, r5)
      +r3 = RS.slot("headers", h, r4)
      +r2 = RS.slot("query", q, r3)
      chain("params", p, r2, Spec.slot_ok(q) && (Spec.slot_ok(h) && (Spec.slot_ok(b) && Spec.slot_ok(r))), chain("query", q, r3, Spec.slot_ok(h) && (Spec.slot_ok(b) && Spec.slot_ok(r)), chain("headers", h, r4, Spec.slot_ok(b) && Spec.slot_ok(r), chain("body", b, r5, Spec.slot_ok(r), last("response", r)))))

def first_problem(+route: Nat, +bad: Maybe<&2, String>, +rest: Maybe<&2, MS.AttachError>) -> {no_error(MS.first_problem(route, bad, rest)) == (none(bad) && no_error(rest)) : Bool}:
  match bad:
    case None{}: {==}
    case Some{x}: {==}

def problem(+xs: List<&2, RS.RouteSchemas>, +route: Nat) -> {no_error(MS.problem(xs, route)) == Spec.all_valid(xs) : Bool}:
  match xs:
    case Nil{}: {==}
    case x <> t:
      %invalid_slot(x) : {no_error(MS.problem(xs, route)) == (_ && Spec.all_valid(t)) : Bool}
      Equal.trans(Bool, no_error(MS.problem(xs, route)), none(RS.invalid_slot(x)) && no_error(MS.problem(t, 1n+route)), none(RS.invalid_slot(x)) && Spec.all_valid(t), first_problem(route, RS.invalid_slot(x), MS.problem(t, 1n+route)), and_right(none(RS.invalid_slot(x)), no_error(MS.problem(t, 1n+route)), Spec.all_valid(t), problem(t, 1n+route)))

def gate_accepted(-Tag: Data, +same: Bool, +found: Maybe<&2, MS.AttachError>, +routes: Nat, +schemas: Nat, +xs: List<&2, M.Registration(Tag)>, +table: M.Table(Tag), +ss: List<&2, RS.RouteSchemas>) -> {Spec.accepted(MS.gate(Tag, same, found, routes, schemas, xs, table, ss)) == (same && no_error(found)) : Bool}:
  match same found:
    case False{} _: {==}
    case True{} Some{err}: {==}
    case True{} None{}: {==}

def accepted(-Tag: Data, +sources: List<&2, M.Registration(Tag)>, +compiled: M.Index<Tag>, +layers: List<&2, T.Middleware<Tag>>, +count: Nat, +ss: List<&2, RS.RouteSchemas>) -> {Spec.accepted(MS.attach(Tag, T.Table{sources, compiled, layers, count}, ss)) == (Nat.is_eq(List.length(&2, M.Registration(Tag), sources), List.length(&2, RS.RouteSchemas, ss)) && Spec.all_valid(ss)) : Bool}:
  +same = Nat.is_eq(List.length(&2, M.Registration(Tag), sources), List.length(&2, RS.RouteSchemas, ss))
  Equal.trans(Bool, Spec.accepted(MS.attach(Tag, T.Table{sources, compiled, layers, count}, ss)), same && no_error(MS.problem(ss, 0n)), same && Spec.all_valid(ss), gate_accepted(Tag, same, MS.problem(ss, 0n), List.length(&2, M.Registration(Tag), sources), List.length(&2, RS.RouteSchemas, ss), sources, M.raw(Tag, M.index_valid(Tag, compiled)), ss), and_right(same, no_error(MS.problem(ss, 0n)), Spec.all_valid(ss), problem(ss, 0n)))
