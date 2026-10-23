# BND-35: the decoder's error list against the specification's locations.
#
# `decode` rejects with `S.collect`, which walks the schema and the value and
# returns the errors found in reverse with the budget left. Five inductions
# follow the walk's states: the frame (errors a state starts with stay at the
# end of its result), the budget (errors plus budget left stay constant), the
# empty result (a state reports nothing exactly when the specification accepts
# the rest), soundness (every new error names a location where the
# specification finds a failing check) and completeness (every such location
# is named, unless the budget ran out).
import Base
import ../src/data/schema.bend as S
import ../src/data/json.bend as J
import ../src/data/schema-spec.bend as Spec
import ./schema.bend as SP
import ./schema-compound.bend as SC
import ./chunked-arith.bend as A
import ./utf8.bend as UP
import ./crypto-compare.bend as CC
import ./jwt-structure.bend as JS
import ../src/data/decimal.bend as D

# Lists of errors.

def cat(xs: List<&2, S.Error>, ys: List<&2, S.Error>) -> List<&2, S.Error>:
  match xs:
    case Nil{}: ys
    case x <> t: x <> cat(t, ys)

def cat_nil(+xs: List<&2, S.Error>) -> {cat(xs, []) == xs : List<&2, S.Error>}:
  match xs:
    case Nil{}: {==}
    case x <> t:
      %cat_nil(t) : {x <> cat(t, []) == x <> _ : List<&2, S.Error>}
      {==}

def cat_assoc(+xs: List<&2, S.Error>, +ys: List<&2, S.Error>, +zs: List<&2, S.Error>) -> {cat(cat(xs, ys), zs) == cat(xs, cat(ys, zs)) : List<&2, S.Error>}:
  match xs:
    case Nil{}: {==}
    case x <> t:
      %cat_assoc(t, ys, zs) : {x <> cat(cat(t, ys), zs) == x <> _ : List<&2, S.Error>}
      {==}

def extend(o: S.Out, rev: List<&2, S.Error>) -> S.Out:
  match o:
    case S.Out{r, l}: S.Out{cat(r, rev), l}

def extend_nil(+o: S.Out) -> {o == extend(o, []) : S.Out}:
  match o:
    case S.Out{r, l}:
      %Equal.sym(List<&2, S.Error>, cat(r, []), r, cat_nil(r)) : {S.Out{r, l} == S.Out{_, l} : S.Out}
      {==}

def extend_extend(+o: S.Out, +a: List<&2, S.Error>, +b: List<&2, S.Error>) -> {extend(extend(o, a), b) == extend(o, cat(a, b)) : S.Out}:
  match o:
    case S.Out{r, l}:
      %cat_assoc(r, a, b) : {S.Out{cat(cat(r, a), b), l} == S.Out{_, l} : S.Out}
      {==}

def prefix_cat(+part: S.PathPart, +es: List<&2, S.Error>, +rev: List<&2, S.Error>) -> {S.prefix_onto(part, es, rev) == cat(S.prefix_onto(part, es, []), rev) : List<&2, S.Error>}:
  match es:
    case Nil{}: {==}
    case S.Error{c0, m0, p0} <> t:
      %prefix_cat(part, t, rev) : {S.Error{c0, m0, part <> p0} <> S.prefix_onto(part, t, rev) == S.Error{c0, m0, part <> p0} <> _ : List<&2, S.Error>}
      {==}

def blank(w: S.Walk) -> S.Walk:
  match w:
    case S.WHere{l}: S.WHere{l}
    case S.WItems{k, S.Out{r, l}}: S.WItems{k, S.Out{[], l}}
    case S.WFields{ss, S.Out{r, l}}: S.WFields{ss, S.Out{[], l}}
    case S.WDone{S.Out{r, l}}: S.WDone{S.Out{[], l}}

def wrev(w: S.Walk) -> List<&2, S.Error>:
  match w:
    case S.WHere{l}: []
    case S.WItems{k, S.Out{r, l}}: r
    case S.WFields{ss, S.Out{r, l}}: r
    case S.WDone{S.Out{r, l}}: r

# A child's errors joined to the parent's, then the rest of the walk.
def shift_frame(+x: S.Out, +y: S.Out, +a: List<&2, S.Error>, +r: List<&2, S.Error>, -z: List<&2, S.Error>, -lhs: S.Out, ih1: {lhs == extend(x, z) : S.Out}, pz: {z == cat(a, r) : List<&2, S.Error>}, ih2: {y == extend(x, a) : S.Out}) -> {lhs == extend(y, r) : S.Out}:
  %Equal.sym(S.Out, y, extend(x, a), ih2) : {lhs == extend(_, r) : S.Out}
  %Equal.sym(S.Out, extend(extend(x, a), r), extend(x, cat(a, r)), extend_extend(x, a, r)) : {lhs == _ : S.Out}
  %pz : {lhs == extend(x, _) : S.Out}
  ih1

def arr_frame(+i: S.Schema, +m: Nat, +n: Maybe<&2, Nat>, +t: List<&2, J.Json>, +k: Nat, +r: List<&2, S.Error>, cc: S.Out) -> {S.collect_go(S.ArraySchema{i, m, n}, J.JArray{t}, S.WItems{1n+k, S.merge(S.PathIndex{k}, cc, r)}) == extend(S.collect_go(S.ArraySchema{i, m, n}, J.JArray{t}, blank(S.WItems{1n+k, S.merge(S.PathIndex{k}, cc, r)})), wrev(S.WItems{1n+k, S.merge(S.PathIndex{k}, cc, r)})) : S.Out} -> {S.collect_go(S.ArraySchema{i, m, n}, J.JArray{t}, S.WItems{1n+k, S.merge(S.PathIndex{k}, cc, [])}) == extend(S.collect_go(S.ArraySchema{i, m, n}, J.JArray{t}, blank(S.WItems{1n+k, S.merge(S.PathIndex{k}, cc, [])})), wrev(S.WItems{1n+k, S.merge(S.PathIndex{k}, cc, [])})) : S.Out} -> {S.collect_go(S.ArraySchema{i, m, n}, J.JArray{t}, S.WItems{1n+k, S.merge(S.PathIndex{k}, cc, r)}) == extend(S.collect_go(S.ArraySchema{i, m, n}, J.JArray{t}, S.WItems{1n+k, S.merge(S.PathIndex{k}, cc, [])}), r) : S.Out}:
  match cc:
    case S.Out{+es, +cl}: ih1 => ih2 => shift_frame(S.collect_go(S.ArraySchema{i, m, n}, J.JArray{t}, S.WItems{1n+k, S.Out{[], cl}}), S.collect_go(S.ArraySchema{i, m, n}, J.JArray{t}, S.WItems{1n+k, S.Out{S.prefix_onto(S.PathIndex{k}, es, []), cl}}), S.prefix_onto(S.PathIndex{k}, es, []), r, S.prefix_onto(S.PathIndex{k}, es, r), S.collect_go(S.ArraySchema{i, m, n}, J.JArray{t}, S.WItems{1n+k, S.Out{S.prefix_onto(S.PathIndex{k}, es, r), cl}}), ih1, prefix_cat(S.PathIndex{k}, es, r), ih2)

def obj_frame(+k: String, +t: List<&2, S.Field>, +u: S.Unknown, +x: J.Json, +rest: List<&2, S.Slot>, +r: List<&2, S.Error>, cc: S.Out) -> {S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.merge(S.PathKey{k}, cc, r)}) == extend(S.collect_go(S.ObjectSchema{t, u}, x, blank(S.WFields{rest, S.merge(S.PathKey{k}, cc, r)})), wrev(S.WFields{rest, S.merge(S.PathKey{k}, cc, r)})) : S.Out} -> {S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.merge(S.PathKey{k}, cc, [])}) == extend(S.collect_go(S.ObjectSchema{t, u}, x, blank(S.WFields{rest, S.merge(S.PathKey{k}, cc, [])})), wrev(S.WFields{rest, S.merge(S.PathKey{k}, cc, [])})) : S.Out} -> {S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.merge(S.PathKey{k}, cc, r)}) == extend(S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.merge(S.PathKey{k}, cc, [])}), r) : S.Out}:
  match cc:
    case S.Out{+es, +cl}: ih1 => ih2 => shift_frame(S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{[], cl}}), S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{S.prefix_onto(S.PathKey{k}, es, []), cl}}), S.prefix_onto(S.PathKey{k}, es, []), r, S.prefix_onto(S.PathKey{k}, es, r), S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{S.prefix_onto(S.PathKey{k}, es, r), cl}}), ih1, prefix_cat(S.PathKey{k}, es, r), ih2)

def emit_frame(+t: List<&2, S.Field>, +u: S.Unknown, +x: J.Json, +rest: List<&2, S.Slot>, +e: S.Error, +r: List<&2, S.Error>, +l: Nat, b: Bool) -> {S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.emit(b, e, S.Out{r, 1n+l})}) == extend(S.collect_go(S.ObjectSchema{t, u}, x, blank(S.WFields{rest, S.emit(b, e, S.Out{r, 1n+l})})), wrev(S.WFields{rest, S.emit(b, e, S.Out{r, 1n+l})})) : S.Out} -> {S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{[e], l}}) == extend(S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{[], l}}), [e]) : S.Out} -> {S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.emit(b, e, S.Out{r, 1n+l})}) == extend(S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.emit(b, e, S.Out{[], 1n+l})}), r) : S.Out}:
  match b:
    case True{}: ih1 => ih2 => ih1
    case False{}: ih1 => ih2 => shift_frame(S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{[], l}}), S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{[e], l}}), [e], r, e <> r, S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{e <> r, l}}), ih1, {==}, ih2)

# The budget: errors plus budget left.

def size(o: S.Out) -> Nat:
  match o:
    case S.Out{r, l}: Nat.add(Spec.error_count(r), l)

def wsize(w: S.Walk) -> Nat:
  match w:
    case S.WHere{l}: l
    case S.WItems{k, o}: size(o)
    case S.WFields{ss, o}: size(o)
    case S.WDone{o}: size(o)

def emit_size(+b: Bool, +e: S.Error, +o: S.Out) -> {size(S.emit(b, e, o)) == size(o) : Nat}:
  match b o:
    case True{} q: {==}
    case False{} S.Out{r, 0n}: {==}
    case False{} S.Out{r, 1n+n}: Equal.sym(Nat, Nat.add(Spec.error_count(r), 1n+n), 1n+Nat.add(Spec.error_count(r), n), A.add_succ_r(Spec.error_count(r), n))

def emit_all_size(+es: List<&2, S.Error>, +o: S.Out) -> {size(S.emit_all(es, o)) == size(o) : Nat}:
  match es:
    case Nil{}: {==}
    case e <> t: Equal.trans(Nat, size(S.emit_all(t, S.emit(False{}, e, o))), size(S.emit(False{}, e, o)), size(o), emit_all_size(t, S.emit(False{}, e, o)), emit_size(False{}, e, o))

def scalar_size(+r: Result<&2, &2, S.Errors(), S.Value>, +l: Nat) -> {size(S.scalar_out(r, l)) == l : Nat}:
  match r:
    case Done{x}: {==}
    case Fail{es}: emit_all_size(es, S.Out{[], l})

def kind_size(+l: Nat) -> {size(S.kind_out(l)) == l : Nat}:
  emit_size(False{}, S.Error{S.TypeMismatch{}, "expected schema kind", []}, S.Out{[], l})

def strays_size(+input: List<&2, J.Field>, +fs: List<&2, S.Field>, +o: S.Out) -> {size(S.strays(input, fs, o)) == size(o) : Nat}:
  match input o:
    case Nil{} S.Out{r, 0n}: {==}
    case Nil{} S.Out{r, 1n+n}: {==}
    case J.Field{k, v} <> t S.Out{r, 0n}: {==}
    case J.Field{+k, v} <> t S.Out{+r, 1n+(+n)}: Equal.trans(Nat, size(S.strays(t, fs, S.emit(S.declared(fs, k), S.Error{S.Constraint{}, "object has an undeclared key", [S.PathKey{k}]}, S.Out{r, 1n+n}))), size(S.emit(S.declared(fs, k), S.Error{S.Constraint{}, "object has an undeclared key", [S.PathKey{k}]}, S.Out{r, 1n+n})), size(S.Out{r, 1n+n}), strays_size(t, fs, S.emit(S.declared(fs, k), S.Error{S.Constraint{}, "object has an undeclared key", [S.PathKey{k}]}, S.Out{r, 1n+n})), emit_size(S.declared(fs, k), S.Error{S.Constraint{}, "object has an undeclared key", [S.PathKey{k}]}, S.Out{r, 1n+n}))

def unknown_size(+u: S.Unknown, +fs: List<&2, S.Field>, +input: List<&2, J.Field>, +o: S.Out) -> {size(S.unknown_out(u, fs, input, o)) == size(o) : Nat}:
  match u:
    case S.Strict{}: strays_size(input, fs, o)
    case S.Strip{}: {==}

def items_walk_size(+b: Bool, +l: Nat) -> {wsize(S.items_walk(b, l)) == l : Nat}:
  match b:
    case True{}: {==}
    case False{}: emit_size(False{}, S.Error{S.Constraint{}, "array length out of bounds", []}, S.Out{[], l})

def cstart_size(+s: S.Schema, +v: J.Json, +l: Nat) -> {wsize(S.cstart(s, v, l)) == l : Nat}:
  match s v:
    case S.ArraySchema{i, m, n} J.JArray{xs}: items_walk_size(S.item_count(m, n, S.count(xs, 0n)), l)
    case S.ArraySchema{i, m, n} J.JNull{}: {==}
    case S.ArraySchema{i, m, n} J.JBool{b0}: {==}
    case S.ArraySchema{i, m, n} J.JNumber{b0}: {==}
    case S.ArraySchema{i, m, n} J.JString{b0}: {==}
    case S.ArraySchema{i, m, n} J.JObject{b0}: {==}
    case S.ObjectSchema{fs, u} J.JObject{input}: unknown_size(u, fs, input, S.Out{[], l})
    case S.ObjectSchema{fs, u} J.JNull{}: {==}
    case S.ObjectSchema{fs, u} J.JBool{b0}: {==}
    case S.ObjectSchema{fs, u} J.JNumber{b0}: {==}
    case S.ObjectSchema{fs, u} J.JString{b0}: {==}
    case S.ObjectSchema{fs, u} J.JArray{b0}: {==}
    case S.StringSchema{a1, a2, a3, a4} x: {==}
    case S.NumberSchema{a1, a2} x: {==}
    case S.IntegerSchema{a1, a2} x: {==}
    case S.BooleanSchema{} x: {==}
    case S.LiteralSchema{a1} x: {==}
    case S.EnumSchema{a1} x: {==}
    case S.NullableSchema{i} x: {==}
    case S.UnionSchema{ms} x: {==}

def prefix_count(+part: S.PathPart, +es: List<&2, S.Error>, +r: List<&2, S.Error>, +cl: Nat) -> {Nat.add(Spec.error_count(S.prefix_onto(part, es, r)), cl) == Nat.add(Spec.error_count(r), Nat.add(Spec.error_count(es), cl)) : Nat}:
  match es:
    case Nil{}: {==}
    case S.Error{c0, m0, p0} <> t:
      %Equal.sym(Nat, Nat.add(Spec.error_count(r), 1n+Nat.add(Spec.error_count(t), cl)), 1n+Nat.add(Spec.error_count(r), Nat.add(Spec.error_count(t), cl)), A.add_succ_r(Spec.error_count(r), Nat.add(Spec.error_count(t), cl))) : {1n+Nat.add(Spec.error_count(S.prefix_onto(part, t, r)), cl) == _ : Nat}
      %prefix_count(part, t, r, cl) : {1n+Nat.add(Spec.error_count(S.prefix_onto(part, t, r)), cl) == 1n+_ : Nat}
      {==}

def merge_size(+part: S.PathPart, +cc: S.Out, +r: List<&2, S.Error>) -> {size(S.merge(part, cc, r)) == Nat.add(Spec.error_count(r), size(cc)) : Nat}:
  match cc:
    case S.Out{es, cl}: prefix_count(part, es, r, cl)

def step_size(+part: S.PathPart, +r: List<&2, S.Error>, +cc: S.Out, -l: Nat, -lhs: Nat, ih: {lhs == size(S.merge(part, cc, r)) : Nat}, hc: {size(cc) == l : Nat}) -> {lhs == Nat.add(Spec.error_count(r), l) : Nat}:
  %hc : {lhs == Nat.add(Spec.error_count(r), _) : Nat}
  %merge_size(part, cc, r) : {lhs == _ : Nat}
  ih

# Booleans.

def and_false(+a: Bool) -> {(a && False{}) == False{} : Bool}:
  match a:
    case True{}: {==}
    case False{}: {==}

def swap3(+a: Bool, +b: Bool, -c: Bool) -> {((a && b) && c) == (b && (a && c)) : Bool}:
  match a b:
    case True{} True{}: {==}
    case True{} False{}: {==}
    case False{} True{}: {==}
    case False{} False{}: {==}

# x is (cm && mt), cm is (cc && er) and cc is mh: x is (er && (mh && mt)).
def combine3(-x: Bool, -cm: Bool, -cc: Bool, +er: Bool, +mh: Bool, +mt: Bool, ih: {x == (cm && mt) : Bool}, hm: {cm == (cc && er) : Bool}, hc: {cc == mh : Bool}) -> {x == (er && (mh && mt)) : Bool}:
  %swap3(mh, er, mt) : {x == _ : Bool}
  %hc : {x == ((_ && er) && mt) : Bool}
  %hm : {x == (_ && mt) : Bool}
  ih

# Reporting nothing.

def empty(r: List<&2, S.Error>) -> Bool:
  match r:
    case Nil{}: True{}
    case e <> t: False{}

def clean(o: S.Out) -> Bool:
  match o:
    case S.Out{r, l}: empty(r)

def positive(n: Nat) -> Bool:
  match n:
    case 0n: False{}
    case 1n+m: True{}

def live(w: S.Walk) -> Bool:
  positive(wsize(w))

def err_path(e: S.Error) -> List<&2, S.PathPart>:
  match e:
    case S.Error{c, m, p}: p

def root(e: S.Error) -> Bool:
  Spec.ends(err_path(e))

def roots(es: List<&2, S.Error>) -> Bool:
  match es:
    case Nil{}: True{}
    case e <> t: root(e) && roots(t)

# A scalar result: a success, or errors that all sit at the value itself.
def bare(r: Result<&2, &2, S.Errors(), S.Value>) -> Bool:
  match r:
    case Done{x}: True{}
    case Fail{+es}: Bool.not(empty(es)) && roots(es)

def bare_finish(+v: S.Value, +b: Bool) -> {bare(S.finish(v, b)) == True{} : Bool}:
  match b:
    case True{}: {==}
    case False{}: {==}

def bare_scalar(+s: S.Schema, +v: J.Json) -> {bare(S.decode_scalar(s, v)) == True{} : Bool}:
  match s v:
    case S.StringSchema{a1, a2, a3, a4} J.JString{x}: bare_finish(S.VString{x}, S.string_check(a1, a2, a3, a4, x))
    case S.StringSchema{a1, a2, a3, a4} J.JNull{}: {==}
    case S.StringSchema{a1, a2, a3, a4} J.JBool{b0}: {==}
    case S.StringSchema{a1, a2, a3, a4} J.JNumber{b0}: {==}
    case S.StringSchema{a1, a2, a3, a4} J.JArray{b0}: {==}
    case S.StringSchema{a1, a2, a3, a4} J.JObject{b0}: {==}
    case S.NumberSchema{a1, a2} J.JNumber{x}: bare_finish(S.VNumber{x}, S.number_check(a1, a2, x))
    case S.NumberSchema{a1, a2} J.JNull{}: {==}
    case S.NumberSchema{a1, a2} J.JBool{b0}: {==}
    case S.NumberSchema{a1, a2} J.JString{b0}: {==}
    case S.NumberSchema{a1, a2} J.JArray{b0}: {==}
    case S.NumberSchema{a1, a2} J.JObject{b0}: {==}
    case S.IntegerSchema{a1, a2} J.JNumber{x}: bare_finish(S.VInteger{x}, D.is_integer(x) && S.number_check(a1, a2, x))
    case S.IntegerSchema{a1, a2} J.JNull{}: {==}
    case S.IntegerSchema{a1, a2} J.JBool{b0}: {==}
    case S.IntegerSchema{a1, a2} J.JString{b0}: {==}
    case S.IntegerSchema{a1, a2} J.JArray{b0}: {==}
    case S.IntegerSchema{a1, a2} J.JObject{b0}: {==}
    case S.BooleanSchema{} J.JBool{b0}: {==}
    case S.BooleanSchema{} J.JNull{}: {==}
    case S.BooleanSchema{} J.JNumber{b0}: {==}
    case S.BooleanSchema{} J.JString{b0}: {==}
    case S.BooleanSchema{} J.JArray{b0}: {==}
    case S.BooleanSchema{} J.JObject{b0}: {==}
    case S.LiteralSchema{a1} y: bare_finish(S.VLiteral{y}, S.scalar(y) && S.same(a1, y))
    case S.EnumSchema{a1} y: bare_finish(S.VLiteral{y}, S.scalar(y) && S.one_of(a1, y, False{}))
    case S.ArraySchema{a1, a2, a3} y: {==}
    case S.ObjectSchema{a1, a2} y: {==}
    case S.NullableSchema{a1} y: {==}
    case S.UnionSchema{a1} y: {==}

def emit_all_dirty(+t: List<&2, S.Error>, +e: S.Error, +r: List<&2, S.Error>, +n: Nat) -> {clean(S.emit_all(t, S.Out{e <> r, n})) == False{} : Bool}:
  match t n:
    case Nil{} m: {==}
    case f <> u 0n: emit_all_dirty(u, e, r, 0n)
    case f <> u 1n+m: emit_all_dirty(u, f, e <> r, m)

def clean_bare(+r: Result<&2, &2, S.Errors(), S.Value>, +n: Nat, hb: {bare(r) == True{} : Bool}) -> {clean(S.scalar_out(r, 1n+n)) == S.accepted(r) : Bool}:
  match r:
    case Done{x}: {==}
    case Fail{Nil{}}: UP.absurd({clean(S.scalar_out(Fail{[]}, 1n+n)) == False{} : Bool}, UP.false_true(hb))
    case Fail{e <> t}: emit_all_dirty(t, e, [], n)

def no_budget(-A: Type, lv: {positive(0n) == True{} : Bool}) -> A:
  UP.absurd(A, UP.false_true(lv))

def scalar_quiet(+s: S.Schema, +x: J.Json, +l: Nat, +okv: {S.valid(s) == True{} : Bool}, lv: {positive(l) == True{} : Bool}) -> {clean(S.scalar_out(S.decode_scalar(s, x), l)) == Spec.accepts(s, x) : Bool}:
  match l:
    case 0n: no_budget({clean(S.scalar_out(S.decode_scalar(s, x), 0n)) == Spec.accepts(s, x) : Bool}, lv)
    case 1n+n: Equal.trans(Bool, clean(S.scalar_out(S.decode_scalar(s, x), 1n+n)), S.accepted(S.decode_scalar(s, x)), Spec.accepts(s, x), clean_bare(S.decode_scalar(s, x), n, bare_scalar(s, x)), SP.accepts_equiv(s, x, okv))

def kind_quiet(+l: Nat, lv: {positive(l) == True{} : Bool}) -> {clean(S.kind_out(l)) == False{} : Bool}:
  match l:
    case 0n: no_budget({clean(S.kind_out(0n)) == False{} : Bool}, lv)
    case 1n+n: {==}

def zero_quiet(+r: List<&2, S.Error>, lv: {positive(Nat.add(Spec.error_count(r), 0n)) == True{} : Bool}) -> {empty(r) == False{} : Bool}:
  match r:
    case Nil{}: no_budget({True{} == False{} : Bool}, lv)
    case e <> t: {==}

def emit_clean(+b: Bool, +e: S.Error, +r: List<&2, S.Error>, +n: Nat) -> {clean(S.emit(b, e, S.Out{r, 1n+n})) == (b && empty(r)) : Bool}:
  match b:
    case True{}: {==}
    case False{}: {==}

def pos_add(+a: Nat, +n: Nat) -> {positive(Nat.add(a, 1n+n)) == True{} : Bool}:
  %Equal.sym(Nat, Nat.add(a, 1n+n), 1n+Nat.add(a, n), A.add_succ_r(a, n)) : {positive(_) == True{} : Bool}
  {==}

def emit_live(+b: Bool, +e: S.Error, +r: List<&2, S.Error>, +n: Nat) -> {positive(size(S.emit(b, e, S.Out{r, 1n+n}))) == True{} : Bool}:
  %Equal.sym(Nat, size(S.emit(b, e, S.Out{r, 1n+n})), size(S.Out{r, 1n+n}), emit_size(b, e, S.Out{r, 1n+n})) : {positive(_) == True{} : Bool}
  pos_add(Spec.error_count(r), n)

def merge_live(+part: S.PathPart, +cc: S.Out, +r: List<&2, S.Error>, +n: Nat, hc: {size(cc) == 1n+n : Nat}) -> {positive(size(S.merge(part, cc, r))) == True{} : Bool}:
  %Equal.sym(Nat, size(S.merge(part, cc, r)), Nat.add(Spec.error_count(r), size(cc)), merge_size(part, cc, r)) : {positive(_) == True{} : Bool}
  %Equal.sym(Nat, size(cc), 1n+n, hc) : {positive(Nat.add(Spec.error_count(r), _)) == True{} : Bool}
  pos_add(Spec.error_count(r), n)

def merge_clean(+part: S.PathPart, +cc: S.Out, +r: List<&2, S.Error>) -> {clean(S.merge(part, cc, r)) == (clean(cc) && empty(r)) : Bool}:
  match cc:
    case S.Out{Nil{}, cl}: {==}
    case S.Out{S.Error{c0, m0, p0} <> t, cl}: {==}

def cstart_live(+s: S.Schema, +v: J.Json, +n: Nat) -> {live(S.cstart(s, v, 1n+n)) == True{} : Bool}:
  %Equal.sym(Nat, wsize(S.cstart(s, v, 1n+n)), 1n+n, cstart_size(s, v, 1n+n)) : {positive(_) == True{} : Bool}
  {==}

def may_absent(+p: S.Presence) -> {S.may_be_absent(p) == SC.absent_ok(p) : Bool}:
  match p:
    case S.Required{}: {==}
    case S.Optional{}: {==}
    case S.Default{d}: {==}

def slots_ok(fs: List<&2, S.Field>, ss: List<&2, S.Slot>) -> Bool:
  match fs ss:
    case Nil{} _: True{}
    case S.Field{k, c, p} <> t x <> rest: SC.slot_meets(c, p, x) && slots_ok(t, rest)
    case S.Field{k, c, p} <> t Nil{}: True{}

def slots_ok_meet(+fs: List<&2, S.Field>, +input: List<&2, J.Field>) -> {slots_ok(fs, S.slots(fs, input)) == SC.slots_meet(fs, S.slots(fs, input)) : Bool}:
  match fs:
    case Nil{}: {==}
    case S.Field{k, c, p} <> t:
      %slots_ok_meet(t, input) : {(SC.slot_meets(c, p, S.find(input, k, S.Absent{})) && slots_ok(t, S.slots(t, input))) == (SC.slot_meets(c, p, S.find(input, k, S.Absent{})) && _) : Bool}
      {==}

# What a state still promises when it reports nothing.
def expect_c(s: S.Schema, w: S.Walk, v: J.Json) -> Bool:
  match s w v:
    case S.StringSchema{a1, a2, a3, a4} S.WHere{l} x: Spec.accepts(S.StringSchema{a1, a2, a3, a4}, x)
    case S.NumberSchema{a1, a2} S.WHere{l} x: Spec.accepts(S.NumberSchema{a1, a2}, x)
    case S.IntegerSchema{a1, a2} S.WHere{l} x: Spec.accepts(S.IntegerSchema{a1, a2}, x)
    case S.BooleanSchema{} S.WHere{l} x: Spec.accepts(S.BooleanSchema{}, x)
    case S.LiteralSchema{a1} S.WHere{l} x: Spec.accepts(S.LiteralSchema{a1}, x)
    case S.EnumSchema{a1} S.WHere{l} x: Spec.accepts(S.EnumSchema{a1}, x)
    case S.ArraySchema{i, m, n} S.WItems{k, o} J.JArray{xs}: clean(o) && Spec.meets(i, Spec.EveryItem{Spec.Holds{}}, J.JArray{xs})
    case S.ObjectSchema{fs, u} S.WFields{ss, o} x: clean(o) && slots_ok(fs, ss)
    case S.NullableSchema{i} S.WHere{l} x: Spec.meets(S.NullableSchema{i}, Spec.Holds{}, x)
    case S.UnionSchema{ms} S.WHere{l} x: Spec.meets(S.UnionSchema{ms}, Spec.Holds{}, x)
    case _ S.WHere{l} _: False{}
    case _ S.WItems{k, o} _: clean(o)
    case _ S.WFields{ss, o} _: clean(o)
    case _ S.WDone{o} _: clean(o)

def strays_clean(+input: List<&2, J.Field>, +fs: List<&2, S.Field>, +o: S.Out, lv: {positive(size(o)) == True{} : Bool}) -> {clean(S.strays(input, fs, o)) == (clean(o) && Spec.all_declared(input, fs)) : Bool}:
  match input o:
    case Nil{} S.Out{r, 0n}: SP.and_true(empty(r))
    case Nil{} S.Out{r, 1n+n}: SP.and_true(empty(r))
    case J.Field{k, v} <> t S.Out{r, 0n}:
      %Equal.sym(Bool, empty(r), False{}, zero_quiet(r, lv)) : {_ == (_ && (Spec.declares(fs, k) && Spec.all_declared(t, fs))) : Bool}
      {==}
    case J.Field{+k, v} <> t S.Out{+r, 1n+(+n)}: combine3(clean(S.strays(t, fs, S.emit(S.declared(fs, k), S.Error{S.Constraint{}, "object has an undeclared key", [S.PathKey{k}]}, S.Out{r, 1n+n}))), clean(S.emit(S.declared(fs, k), S.Error{S.Constraint{}, "object has an undeclared key", [S.PathKey{k}]}, S.Out{r, 1n+n})), S.declared(fs, k), empty(r), Spec.declares(fs, k), Spec.all_declared(t, fs), strays_clean(t, fs, S.emit(S.declared(fs, k), S.Error{S.Constraint{}, "object has an undeclared key", [S.PathKey{k}]}, S.Out{r, 1n+n}), emit_live(S.declared(fs, k), S.Error{S.Constraint{}, "object has an undeclared key", [S.PathKey{k}]}, r, n)), emit_clean(S.declared(fs, k), S.Error{S.Constraint{}, "object has an undeclared key", [S.PathKey{k}]}, r, n), SP.declared_equiv(fs, k))

def unknown_clean(+u: S.Unknown, +fs: List<&2, S.Field>, +input: List<&2, J.Field>, +n: Nat) -> {clean(S.unknown_out(u, fs, input, S.Out{[], 1n+n})) == Spec.allowed(u, fs, input) : Bool}:
  match u:
    case S.Strict{}: strays_clean(input, fs, S.Out{[], 1n+n}, {==})
    case S.Strip{}: {==}

def items_expect(+i: S.Schema, +m: Nat, +n: Maybe<&2, Nat>, +xs: List<&2, J.Json>, +b: Bool, +bn: Nat) -> {expect_c(S.ArraySchema{i, m, n}, S.items_walk(b, 1n+bn), J.JArray{xs}) == (b && Spec.meets(i, Spec.EveryItem{Spec.Holds{}}, J.JArray{xs})) : Bool}:
  match b:
    case True{}: {==}
    case False{}: {==}

def entry_c(+s: S.Schema, +v: J.Json, +bn: Nat) -> {expect_c(s, S.cstart(s, v, 1n+bn), v) == Spec.meets(s, Spec.Holds{}, v) : Bool}:
  match s v:
    case S.ArraySchema{i, m, n} J.JArray{xs}:
      %SC.count_equiv(xs) : {expect_c(S.ArraySchema{i, m, n}, S.cstart(S.ArraySchema{i, m, n}, J.JArray{xs}, 1n+bn), J.JArray{xs}) == ((Nat.is_le(m, _) && Spec.at_most(n, _)) && Spec.meets(i, Spec.EveryItem{Spec.Holds{}}, J.JArray{xs})) : Bool}
      %SP.max_equiv(n, S.count(xs, 0n)) : {expect_c(S.ArraySchema{i, m, n}, S.cstart(S.ArraySchema{i, m, n}, J.JArray{xs}, 1n+bn), J.JArray{xs}) == ((Nat.is_le(m, S.count(xs, 0n)) && _) && Spec.meets(i, Spec.EveryItem{Spec.Holds{}}, J.JArray{xs})) : Bool}
      items_expect(i, m, n, xs, S.item_count(m, n, S.count(xs, 0n)), bn)
    case S.ArraySchema{i, m, n} J.JNull{}: {==}
    case S.ArraySchema{i, m, n} J.JBool{b0}: {==}
    case S.ArraySchema{i, m, n} J.JNumber{b0}: {==}
    case S.ArraySchema{i, m, n} J.JString{b0}: {==}
    case S.ArraySchema{i, m, n} J.JObject{b0}: {==}
    case S.ObjectSchema{Nil{}, u} J.JObject{input}:
      %unknown_clean(u, [], input, bn) : {expect_c(S.ObjectSchema{[], u}, S.cstart(S.ObjectSchema{[], u}, J.JObject{input}, 1n+bn), J.JObject{input}) == _ : Bool}
      Equal.sym(Bool, clean(S.unknown_out(u, [], input, S.Out{[], 1n+bn})), (clean(S.unknown_out(u, [], input, S.Out{[], 1n+bn})) && True{}), SP.and_true(clean(S.unknown_out(u, [], input, S.Out{[], 1n+bn}))))
    case S.ObjectSchema{S.Field{k, c, p} <> t, u} J.JObject{input}:
      %unknown_clean(u, S.Field{k, c, p} <> t, input, bn) : {(clean(S.unknown_out(u, S.Field{k, c, p} <> t, input, S.Out{[], 1n+bn})) && slots_ok(S.Field{k, c, p} <> t, S.slots(S.Field{k, c, p} <> t, input))) == (_ && (Spec.presence(p, Spec.named(input, k)) && SC.every(c, k, input) && Spec.meets(S.ObjectSchema{t, u}, Spec.EveryField{}, J.JObject{input}))) : Bool}
      %SC.fields_meet(S.Field{k, c, p} <> t, u, input) : {(clean(S.unknown_out(u, S.Field{k, c, p} <> t, input, S.Out{[], 1n+bn})) && slots_ok(S.Field{k, c, p} <> t, S.slots(S.Field{k, c, p} <> t, input))) == (clean(S.unknown_out(u, S.Field{k, c, p} <> t, input, S.Out{[], 1n+bn})) && _) : Bool}
      %slots_ok_meet(S.Field{k, c, p} <> t, input) : {(clean(S.unknown_out(u, S.Field{k, c, p} <> t, input, S.Out{[], 1n+bn})) && slots_ok(S.Field{k, c, p} <> t, S.slots(S.Field{k, c, p} <> t, input))) == (clean(S.unknown_out(u, S.Field{k, c, p} <> t, input, S.Out{[], 1n+bn})) && _) : Bool}
      {==}
    case S.ObjectSchema{fs, u} J.JNull{}: {==}
    case S.ObjectSchema{fs, u} J.JBool{b0}: {==}
    case S.ObjectSchema{fs, u} J.JNumber{b0}: {==}
    case S.ObjectSchema{fs, u} J.JString{b0}: {==}
    case S.ObjectSchema{fs, u} J.JArray{b0}: {==}
    case S.StringSchema{a1, a2, a3, a4} x: {==}
    case S.NumberSchema{a1, a2} x: {==}
    case S.IntegerSchema{a1, a2} x: {==}
    case S.BooleanSchema{} x: {==}
    case S.LiteralSchema{a1} x: {==}
    case S.EnumSchema{a1} x: {==}
    case S.NullableSchema{i} x: {==}
    case S.UnionSchema{ms} x: {==}

def union_quiet(+ms: List<&2, S.Schema>, +x: J.Json, +l: Nat, +okv: {S.valid(S.UnionSchema{ms}) == True{} : Bool}, lv: {positive(l) == True{} : Bool}) -> {clean(S.emit(S.accepted(S.decode_go(S.UnionSchema{ms}, x, S.start(S.UnionSchema{ms}, x))), S.Error{S.Constraint{}, "value matches no union member", []}, S.Out{[], l})) == Spec.meets(S.UnionSchema{ms}, Spec.Holds{}, x) : Bool}:
  match l:
    case 0n: no_budget({clean(S.emit(S.accepted(S.decode_go(S.UnionSchema{ms}, x, S.start(S.UnionSchema{ms}, x))), S.Error{S.Constraint{}, "value matches no union member", []}, S.Out{[], 0n})) == Spec.meets(S.UnionSchema{ms}, Spec.Holds{}, x) : Bool}, lv)
    case 1n+n:
      %SC.child(S.UnionSchema{ms}, x, SC.agree(S.UnionSchema{ms}, x, S.start(S.UnionSchema{ms}, x), okv)) : {clean(S.emit(S.accepted(S.decode_go(S.UnionSchema{ms}, x, S.start(S.UnionSchema{ms}, x))), S.Error{S.Constraint{}, "value matches no union member", []}, S.Out{[], 1n+n})) == _ : Bool}
      Equal.trans(Bool, clean(S.emit(S.accepted(S.decode_go(S.UnionSchema{ms}, x, S.start(S.UnionSchema{ms}, x))), S.Error{S.Constraint{}, "value matches no union member", []}, S.Out{[], 1n+n})), (S.accepted(S.decode_go(S.UnionSchema{ms}, x, S.start(S.UnionSchema{ms}, x))) && True{}), S.accepted(S.decode_go(S.UnionSchema{ms}, x, S.start(S.UnionSchema{ms}, x))), emit_clean(S.accepted(S.decode_go(S.UnionSchema{ms}, x, S.start(S.UnionSchema{ms}, x))), S.Error{S.Constraint{}, "value matches no union member", []}, [], n), Equal.sym(Bool, S.accepted(S.decode_go(S.UnionSchema{ms}, x, S.start(S.UnionSchema{ms}, x))), (S.accepted(S.decode_go(S.UnionSchema{ms}, x, S.start(S.UnionSchema{ms}, x))) && True{}), SP.and_true(S.accepted(S.decode_go(S.UnionSchema{ms}, x, S.start(S.UnionSchema{ms}, x))))))

def entry_c2(+s: S.Schema, +v: J.Json, +l: Nat, lv: {positive(l) == True{} : Bool}) -> {expect_c(s, S.cstart(s, v, l), v) == Spec.meets(s, Spec.Holds{}, v) : Bool}:
  match l:
    case 0n: no_budget({expect_c(s, S.cstart(s, v, 0n), v) == Spec.meets(s, Spec.Holds{}, v) : Bool}, lv)
    case 1n+n: entry_c(s, v, n)

def cstart_live2(+s: S.Schema, +v: J.Json, +l: Nat, lv: {positive(l) == True{} : Bool}) -> {live(S.cstart(s, v, l)) == True{} : Bool}:
  %Equal.sym(Nat, wsize(S.cstart(s, v, l)), l, cstart_size(s, v, l)) : {positive(_) == True{} : Bool}
  lv

# Soundness.

def cmp_eq_sound(+c: Cmp, e: {Cmp.is_eq(c) == True{} : Bool}) -> {c == EQ{} : Cmp}:
  match c:
    case LT{}: UP.absurd({LT{} == EQ{} : Cmp}, UP.false_true(e))
    case EQ{}: {==}
    case GT{}: UP.absurd({GT{} == EQ{} : Cmp}, UP.false_true(e))

def u32_self(+x: U32) -> {U32.cmp(x, x) == EQ{} : Cmp}:
  match x:
    case U32{w}: cmp_eq_sound(Word.cmp(32n, w, w), CC.word_self(32n, w))

def order_self(+s: String) -> {String.order.go(s, s, EQ{}) == EQ{} : Cmp}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{x}, t}:
      %Equal.sym(Cmp, U32.cmp(x, x), EQ{}, u32_self(x)) : {String.order.go(t, t, _) == EQ{} : Cmp}
      order_self(t)

def string_refl(+s: String) -> {String.eq(s, s) == True{} : Bool}:
  %Equal.sym(Cmp, String.order.go(s, s, EQ{}), EQ{}, order_self(s)) : {Cmp.is_eq(_) == True{} : Bool}
  {==}

def nat_refl(+n: Nat) -> {Nat.is_eq(n, n) == True{} : Bool}:
  match n:
    case 0n: {==}
    case 1n+m: nat_refl(m)

def or_left(+a: Bool, -b: Bool, ha: {a == True{} : Bool}) -> {(a || b) == True{} : Bool}:
  %Equal.sym(Bool, a, True{}, ha) : {(_ || b) == True{} : Bool}
  {==}

def or_right(+a: Bool, -b: Bool, hb: {b == True{} : Bool}) -> {(a || b) == True{} : Bool}:
  match a:
    case True{}: {==}
    case False{}: hb

def and_both(+a: Bool, -b: Bool, ha: {a == True{} : Bool}, hb: {b == True{} : Bool}) -> {(a && b) == True{} : Bool}:
  %Equal.sym(Bool, a, True{}, ha) : {(_ && b) == True{} : Bool}
  hb

def revs(o: S.Out) -> List<&2, S.Error>:
  match o:
    case S.Out{r, l}: r

def revs_extend(+o: S.Out, +rev: List<&2, S.Error>) -> {revs(extend(o, rev)) == cat(revs(o), rev) : List<&2, S.Error>}:
  match o:
    case S.Out{r, l}: {==}

# The array item spec, unfolded for an item schema that is a variable.
def from_cons(+i: S.Schema, +h: J.Json, +t: List<&2, J.Json>, +n: Nat, +q: List<&2, S.PathPart>, +k: Nat) -> {Spec.fault(i, J.JArray{h <> t}, S.PathIndex{n} <> q, Spec.From{k}) == ((Nat.is_eq(n, k) && Spec.fault(i, h, q, Spec.Here{})) || Spec.fault(i, J.JArray{t}, S.PathIndex{n} <> q, Spec.From{1n+k})) : Bool}:
  match i:
    case S.StringSchema{a1, a2, a3, a4}: {==}
    case S.NumberSchema{a1, a2}: {==}
    case S.IntegerSchema{a1, a2}: {==}
    case S.BooleanSchema{}: {==}
    case S.LiteralSchema{a1}: {==}
    case S.EnumSchema{a1}: {==}
    case S.ArraySchema{a1, a2, a3}: {==}
    case S.ObjectSchema{Nil{}, a2}: {==}
    case S.ObjectSchema{S.Field{a1, a3, a4} <> a5, a2}: {==}
    case S.NullableSchema{a1}: {==}
    case S.UnionSchema{a1}: {==}

# Where a state's errors may point.
def items_at(path: List<&2, S.PathPart>, i: S.Schema, v: J.Json, k: Nat) -> Bool:
  match path v:
    case S.PathIndex{n} <> q J.JArray{h <> t}: Spec.fault(i, J.JArray{h <> t}, S.PathIndex{n} <> q, Spec.From{k})
    case _ _: False{}

def slot_local(c: S.Schema, p: S.Presence, sl: S.Slot, q: List<&2, S.PathPart>) -> Bool:
  match sl:
    case S.Absent{}: Bool.not(S.may_be_absent(p)) && Spec.ends(q)
    case S.Once{y}: Spec.fault(c, y, q, Spec.Here{})
    case S.Repeated{y}: Spec.ends(q)

def slots_fault(path: List<&2, S.PathPart>, fs: List<&2, S.Field>, ss: List<&2, S.Slot>) -> Bool:
  match path fs ss:
    case S.PathKey{+k} <> +q S.Field{key, c, p} <> t sl <> rest: (String.eq(key, k) && slot_local(c, p, sl, q)) || slots_fault(S.PathKey{k} <> q, t, rest)
    case _ _ _: False{}

def state_fault(w: S.Walk, s: S.Schema, v: J.Json, path: List<&2, S.PathPart>) -> Bool:
  match w s v:
    case S.WHere{l} s2 x: Spec.fault(s2, x, path, Spec.Here{})
    case S.WItems{k, o} S.ArraySchema{i, m, n} x: items_at(path, i, x, k)
    case S.WFields{ss, o} S.ObjectSchema{fs, u} x: slots_fault(path, fs, ss)
    case _ _ _: True{}

def reach(w: S.Walk, s: S.Schema, v: J.Json) -> Bool:
  match w s v:
    case S.WHere{l} S.ArraySchema{i, m, n} J.JArray{xs}: False{}
    case S.WHere{l} S.ObjectSchema{fs, u} J.JObject{input}: False{}
    case _ _ _: True{}

def all_sf(es: List<&2, S.Error>, +w: S.Walk, +s: S.Schema, +v: J.Json) -> Bool:
  match es:
    case Nil{}: True{}
    case e <> t: state_fault(w, s, v, err_path(e)) && all_sf(t, w, s, v)

def all_here(es: List<&2, S.Error>, +s: S.Schema, +v: J.Json) -> Bool:
  match es:
    case Nil{}: True{}
    case e <> t: Spec.fault(s, v, err_path(e), Spec.Here{}) && all_here(t, s, v)

def all_cat(+a: List<&2, S.Error>, +b: List<&2, S.Error>, +w: S.Walk, +s: S.Schema, +v: J.Json) -> {all_sf(cat(a, b), w, s, v) == (all_sf(a, w, s, v) && all_sf(b, w, s, v)) : Bool}:
  match a:
    case Nil{}: {==}
    case e <> t:
      %Equal.sym(Bool, all_sf(cat(t, b), w, s, v), (all_sf(t, w, s, v) && all_sf(b, w, s, v)), all_cat(t, b, w, s, v)) : {(state_fault(w, s, v, err_path(e)) && _) == ((state_fault(w, s, v, err_path(e)) && all_sf(t, w, s, v)) && all_sf(b, w, s, v)) : Bool}
      Equal.sym(Bool, ((state_fault(w, s, v, err_path(e)) && all_sf(t, w, s, v)) && all_sf(b, w, s, v)), (state_fault(w, s, v, err_path(e)) && (all_sf(t, w, s, v) && all_sf(b, w, s, v))), SP.and_assoc(state_fault(w, s, v, err_path(e)), all_sf(t, w, s, v), all_sf(b, w, s, v)))

def here_cat(+a: List<&2, S.Error>, +b: List<&2, S.Error>, +s: S.Schema, +v: J.Json) -> {all_here(cat(a, b), s, v) == (all_here(a, s, v) && all_here(b, s, v)) : Bool}:
  match a:
    case Nil{}: {==}
    case e <> t:
      %Equal.sym(Bool, all_here(cat(t, b), s, v), (all_here(t, s, v) && all_here(b, s, v)), here_cat(t, b, s, v)) : {(Spec.fault(s, v, err_path(e), Spec.Here{}) && _) == ((Spec.fault(s, v, err_path(e), Spec.Here{}) && all_here(t, s, v)) && all_here(b, s, v)) : Bool}
      Equal.sym(Bool, ((Spec.fault(s, v, err_path(e), Spec.Here{}) && all_here(t, s, v)) && all_here(b, s, v)), (Spec.fault(s, v, err_path(e), Spec.Here{}) && (all_here(t, s, v) && all_here(b, s, v))), SP.and_assoc(Spec.fault(s, v, err_path(e), Spec.Here{}), all_here(t, s, v), all_here(b, s, v)))

def here_eq(+es: List<&2, S.Error>, +l: Nat, +s: S.Schema, +v: J.Json) -> {all_sf(es, S.WHere{l}, s, v) == all_here(es, s, v) : Bool}:
  match es:
    case Nil{}: {==}
    case e <> t:
      %here_eq(t, l, s, v) : {(Spec.fault(s, v, err_path(e), Spec.Here{}) && all_sf(t, S.WHere{l}, s, v)) == (Spec.fault(s, v, err_path(e), Spec.Here{}) && _) : Bool}
      {==}

def root_fault(+p: List<&2, S.PathPart>, +s: S.Schema, +x: J.Json, f: {Spec.fault(s, x, [], Spec.Here{}) == True{} : Bool}, he: {Spec.ends(p) == True{} : Bool}) -> {Spec.fault(s, x, p, Spec.Here{}) == True{} : Bool}:
  match p:
    case Nil{}: f
    case h <> t: UP.absurd({Spec.fault(s, x, h <> t, Spec.Here{}) == True{} : Bool}, UP.false_true(he))

def roots_all(+es: List<&2, S.Error>, +s: S.Schema, +x: J.Json, +l: Nat, +f: {Spec.fault(s, x, [], Spec.Here{}) == True{} : Bool}, +hr: {roots(es) == True{} : Bool}) -> {all_sf(es, S.WHere{l}, s, x) == True{} : Bool}:
  match es:
    case Nil{}: {==}
    case e <> t: and_both(Spec.fault(s, x, err_path(e), Spec.Here{}), all_sf(t, S.WHere{l}, s, x), root_fault(err_path(e), s, x, f, UP.and_left(root(e), roots(t), hr)), roots_all(t, s, x, l, f, UP.and_right(root(e), roots(t), hr)))

def emit_roots(+e: S.Error, +o: S.Out, he: {root(e) == True{} : Bool}, ho: {roots(revs(o)) == True{} : Bool}) -> {roots(revs(S.emit(False{}, e, o))) == True{} : Bool}:
  match o:
    case S.Out{r, 0n}: ho
    case S.Out{r, 1n+n}: and_both(root(e), roots(r), he, ho)

def emit_all_roots(+es: List<&2, S.Error>, +o: S.Out, +h1: {roots(es) == True{} : Bool}, h2: {roots(revs(o)) == True{} : Bool}) -> {roots(revs(S.emit_all(es, o))) == True{} : Bool}:
  match es:
    case Nil{}: h2
    case e <> t: emit_all_roots(t, S.emit(False{}, e, o), UP.and_right(root(e), roots(t), h1), emit_roots(e, o, UP.and_left(root(e), roots(t), h1), h2))

def scalar_sound_r(+r: Result<&2, &2, S.Errors(), S.Value>, +s: S.Schema, +x: J.Json, +l: Nat, +hb: {bare(r) == True{} : Bool}, ha: {S.accepted(r) == Spec.accepts(s, x) : Bool}, hf: {Spec.fault(s, x, [], Spec.Here{}) == Bool.not(Spec.accepts(s, x)) : Bool}) -> {all_sf(revs(S.scalar_out(r, l)), S.WHere{l}, s, x) == True{} : Bool}:
  match r:
    case Done{y}: {==}
    case Fail{es}: roots_all(revs(S.emit_all(es, S.Out{[], l})), s, x, l, Equal.trans(Bool, Spec.fault(s, x, [], Spec.Here{}), Bool.not(Spec.accepts(s, x)), True{}, hf, Equal.cong(Bool, Bool, b => Bool.not(b), Spec.accepts(s, x), False{}, Equal.sym(Bool, False{}, Spec.accepts(s, x), ha))), emit_all_roots(es, S.Out{[], l}, UP.and_right(Bool.not(empty(es)), roots(es), hb), {==}))

def scalar_sound(+s: S.Schema, +x: J.Json, +l: Nat, +okv: {S.valid(s) == True{} : Bool}, hf: {Spec.fault(s, x, [], Spec.Here{}) == Bool.not(Spec.accepts(s, x)) : Bool}) -> {all_sf(revs(S.scalar_out(S.decode_scalar(s, x), l)), S.WHere{l}, s, x) == True{} : Bool}:
  scalar_sound_r(S.decode_scalar(s, x), s, x, l, bare_scalar(s, x), SP.accepts_equiv(s, x, okv), hf)

def kind_sound(+s: S.Schema, +x: J.Json, +l: Nat, f: {Spec.fault(s, x, [], Spec.Here{}) == True{} : Bool}) -> {all_sf(revs(S.kind_out(l)), S.WHere{l}, s, x) == True{} : Bool}:
  match l:
    case 0n: {==}
    case 1n+n: and_both(Spec.fault(s, x, [], Spec.Here{}), True{}, f, {==})

def no_reach(-A: Type, rc: {False{} == True{} : Bool}) -> A:
  UP.absurd(A, UP.false_true(rc))

def widen1(+p: List<&2, S.PathPart>, +i: S.Schema, +h: J.Json, +t: List<&2, J.Json>, +k: Nat, hp: {items_at(p, i, J.JArray{t}, 1n+k) == True{} : Bool}) -> {items_at(p, i, J.JArray{h <> t}, k) == True{} : Bool}:
  match p:
    case Nil{}: UP.absurd({False{} == True{} : Bool}, UP.false_true(hp))
    case S.PathKey{a} <> q: UP.absurd({False{} == True{} : Bool}, UP.false_true(hp))
    case S.PathIndex{+n} <> +q:
      match t:
        case Nil{}: UP.absurd({items_at(S.PathIndex{n} <> q, i, J.JArray{[h]}, k) == True{} : Bool}, UP.false_true(hp))
        case +g <> +r:
          %Equal.sym(Bool, Spec.fault(i, J.JArray{h <> g <> r}, S.PathIndex{n} <> q, Spec.From{k}), ((Nat.is_eq(n, k) && Spec.fault(i, h, q, Spec.Here{})) || Spec.fault(i, J.JArray{g <> r}, S.PathIndex{n} <> q, Spec.From{1n+k})), from_cons(i, h, g <> r, n, q, k)) : {_ == True{} : Bool}
          or_right(Nat.is_eq(n, k) && Spec.fault(i, h, q, Spec.Here{}), Spec.fault(i, J.JArray{g <> r}, S.PathIndex{n} <> q, Spec.From{1n+k}), hp)

def widen_items(+es: List<&2, S.Error>, +i: S.Schema, +m: Nat, +n: Maybe<&2, Nat>, +h: J.Json, +t: List<&2, J.Json>, +k: Nat, +o1: S.Out, +o2: S.Out, +he: {all_sf(es, S.WItems{1n+k, o1}, S.ArraySchema{i, m, n}, J.JArray{t}) == True{} : Bool}) -> {all_sf(es, S.WItems{k, o2}, S.ArraySchema{i, m, n}, J.JArray{h <> t}) == True{} : Bool}:
  match es:
    case Nil{}: {==}
    case e <> u: and_both(items_at(err_path(e), i, J.JArray{h <> t}, k), all_sf(u, S.WItems{k, o2}, S.ArraySchema{i, m, n}, J.JArray{h <> t}), widen1(err_path(e), i, h, t, k, UP.and_left(items_at(err_path(e), i, J.JArray{t}, 1n+k), all_sf(u, S.WItems{1n+k, o1}, S.ArraySchema{i, m, n}, J.JArray{t}), he)), widen_items(u, i, m, n, h, t, k, o1, o2, UP.and_right(items_at(err_path(e), i, J.JArray{t}, 1n+k), all_sf(u, S.WItems{1n+k, o1}, S.ArraySchema{i, m, n}, J.JArray{t}), he)))

def prefix_items(+es: List<&2, S.Error>, +i: S.Schema, +m: Nat, +n: Maybe<&2, Nat>, +h: J.Json, +t: List<&2, J.Json>, +k: Nat, +o2: S.Out, +hc: {all_here(es, i, h) == True{} : Bool}) -> {all_sf(S.prefix_onto(S.PathIndex{k}, es, []), S.WItems{k, o2}, S.ArraySchema{i, m, n}, J.JArray{h <> t}) == True{} : Bool}:
  match es:
    case Nil{}: {==}
    case S.Error{c0, m0, p0} <> u:
      %Equal.sym(Bool, Spec.fault(i, J.JArray{h <> t}, S.PathIndex{k} <> p0, Spec.From{k}), ((Nat.is_eq(k, k) && Spec.fault(i, h, p0, Spec.Here{})) || Spec.fault(i, J.JArray{t}, S.PathIndex{k} <> p0, Spec.From{1n+k})), from_cons(i, h, t, k, p0, k)) : {(_ && all_sf(S.prefix_onto(S.PathIndex{k}, u, []), S.WItems{k, o2}, S.ArraySchema{i, m, n}, J.JArray{h <> t})) == True{} : Bool}
      and_both((Nat.is_eq(k, k) && Spec.fault(i, h, p0, Spec.Here{})) || Spec.fault(i, J.JArray{t}, S.PathIndex{k} <> p0, Spec.From{1n+k}), all_sf(S.prefix_onto(S.PathIndex{k}, u, []), S.WItems{k, o2}, S.ArraySchema{i, m, n}, J.JArray{h <> t}), or_left(Nat.is_eq(k, k) && Spec.fault(i, h, p0, Spec.Here{}), Spec.fault(i, J.JArray{t}, S.PathIndex{k} <> p0, Spec.From{1n+k}), and_both(Nat.is_eq(k, k), Spec.fault(i, h, p0, Spec.Here{}), nat_refl(k), UP.and_left(Spec.fault(i, h, p0, Spec.Here{}), all_here(u, i, h), hc))), prefix_items(u, i, m, n, h, t, k, o2, UP.and_right(Spec.fault(i, h, p0, Spec.Here{}), all_here(u, i, h), hc)))

# An object's member slots, read against the specification's counts.

def first_slot(n: Nat, y: J.Json) -> S.Slot:
  match n:
    case 0n: S.Once{y}
    case 1n+m: S.Repeated{y}

def canon(n: Nat, y: J.Json) -> S.Slot:
  match n:
    case 0n: S.Absent{}
    case 1n+m: first_slot(m, y)

def combine(acc: S.Slot, n: Nat, y: J.Json) -> S.Slot:
  match acc:
    case S.Absent{}: canon(n, y)
    case S.Once{z}: first_slot(n, z)
    case S.Repeated{z}: S.Repeated{z}

def find_step(+b: Bool, +acc: S.Slot, +n: Nat, +m: J.Json, +y: J.Json) -> {combine(S.found(b, acc, y), n, m) == combine(acc, Spec.bump(b, n), Bool.pick(J.Json, b, y, m)) : S.Slot}:
  match b acc:
    case False{} a: {==}
    case True{} S.Absent{}: {==}
    case True{} S.Once{z}: {==}
    case True{} S.Repeated{z}: {==}

def find_canon(+input: List<&2, J.Field>, +k: String, +acc: S.Slot) -> {S.find(input, k, acc) == combine(acc, Spec.named(input, k), Spec.member(input, k)) : S.Slot}:
  match input acc:
    case Nil{} S.Absent{}: {==}
    case Nil{} S.Once{z}: {==}
    case Nil{} S.Repeated{z}: {==}
    case J.Field{key, y} <> t S.Repeated{z}: {==}
    case J.Field{+key, +y} <> +t S.Absent{}: Equal.trans(S.Slot, S.find(t, k, S.found(String.eq(key, k), S.Absent{}, y)), combine(S.found(String.eq(key, k), S.Absent{}, y), Spec.named(t, k), Spec.member(t, k)), combine(S.Absent{}, Spec.bump(String.eq(key, k), Spec.named(t, k)), Bool.pick(J.Json, String.eq(key, k), y, Spec.member(t, k))), find_canon(t, k, S.found(String.eq(key, k), S.Absent{}, y)), find_step(String.eq(key, k), S.Absent{}, Spec.named(t, k), Spec.member(t, k), y))
    case J.Field{+key, +y} <> +t S.Once{+z}: Equal.trans(S.Slot, S.find(t, k, S.found(String.eq(key, k), S.Once{z}, y)), combine(S.found(String.eq(key, k), S.Once{z}, y), Spec.named(t, k), Spec.member(t, k)), combine(S.Once{z}, Spec.bump(String.eq(key, k), Spec.named(t, k)), Bool.pick(J.Json, String.eq(key, k), y, Spec.member(t, k))), find_canon(t, k, S.found(String.eq(key, k), S.Once{z}, y)), find_step(String.eq(key, k), S.Once{z}, Spec.named(t, k), Spec.member(t, k), y))

def slot_local_canon(+c: S.Schema, +pr: S.Presence, +n: Nat, +y: J.Json, +q: List<&2, S.PathPart>) -> {slot_local(c, pr, canon(n, y), q) == (Spec.miscount(pr, n, q) || (Nat.is_eq(n, 1n) && Spec.fault(c, y, q, Spec.Here{}))) : Bool}:
  match pr n:
    case S.Required{} 0n: SP.or_false(Spec.ends(q))
    case S.Optional{} 0n: {==}
    case S.Default{d} 0n: {==}
    case S.Required{} 1n+0n: {==}
    case S.Optional{} 1n+0n: {==}
    case S.Default{d} 1n+0n: {==}
    case S.Required{} 1n+(1n+j): SP.or_false(Spec.ends(q))
    case S.Optional{} 1n+(1n+j): SP.or_false(Spec.ends(q))
    case S.Default{d} 1n+(1n+j): SP.or_false(Spec.ends(q))

def slot_local_eq(+c: S.Schema, +pr: S.Presence, +input: List<&2, J.Field>, +key: String, +q: List<&2, S.PathPart>) -> {slot_local(c, pr, S.find(input, key, S.Absent{}), q) == (Spec.miscount(pr, Spec.named(input, key), q) || (Nat.is_eq(Spec.named(input, key), 1n) && Spec.fault(c, Spec.member(input, key), q, Spec.Here{}))) : Bool}:
  %Equal.sym(S.Slot, S.find(input, key, S.Absent{}), canon(Spec.named(input, key), Spec.member(input, key)), find_canon(input, key, S.Absent{})) : {slot_local(c, pr, _, q) == (Spec.miscount(pr, Spec.named(input, key), q) || (Nat.is_eq(Spec.named(input, key), 1n) && Spec.fault(c, Spec.member(input, key), q, Spec.Here{}))) : Bool}
  slot_local_canon(c, pr, Spec.named(input, key), Spec.member(input, key), q)

def or_mono(+a: Bool, -b: Bool, -b2: Bool, h: {(a || b) == True{} : Bool}, f: {b == True{} : Bool} -> {b2 == True{} : Bool}) -> {(a || b2) == True{} : Bool}:
  match a:
    case True{}: {==}
    case False{}: f(h)

def slots_keyed(+fs: List<&2, S.Field>, +u: S.Unknown, +input: List<&2, J.Field>, +k: String, +q: List<&2, S.PathPart>, hs: {slots_fault(S.PathKey{k} <> q, fs, S.slots(fs, input)) == True{} : Bool}) -> {Spec.fault(S.ObjectSchema{fs, u}, J.JObject{input}, S.PathKey{k} <> q, Spec.Keyed{}) == True{} : Bool}:
  match fs:
    case Nil{}: UP.absurd({Spec.fault(S.ObjectSchema{[], u}, J.JObject{input}, S.PathKey{k} <> q, Spec.Keyed{}) == True{} : Bool}, UP.false_true(hs))
    case S.Field{key, c, pr} <> t:
      %slot_local_eq(c, pr, input, key, q) : {((String.eq(key, k) && _) || Spec.fault(S.ObjectSchema{t, u}, J.JObject{input}, S.PathKey{k} <> q, Spec.Keyed{})) == True{} : Bool}
      or_mono(String.eq(key, k) && slot_local(c, pr, S.find(input, key, S.Absent{}), q), slots_fault(S.PathKey{k} <> q, t, S.slots(t, input)), Spec.fault(S.ObjectSchema{t, u}, J.JObject{input}, S.PathKey{k} <> q, Spec.Keyed{}), hs, hb => slots_keyed(t, u, input, k, q, hb))

def keyed_here(+st: Bool, +x: Bool, -y: Bool, h: {(x || y) == True{} : Bool}) -> {((st || x) || y) == True{} : Bool}:
  match x:
    case True{}: or_left(st || True{}, y, or_right(st, True{}, {==}))
    case False{}: or_right(st || False{}, y, h)

def slots_here(+p: List<&2, S.PathPart>, +fs: List<&2, S.Field>, +u: S.Unknown, +input: List<&2, J.Field>, hs: {slots_fault(p, fs, S.slots(fs, input)) == True{} : Bool}) -> {Spec.fault(S.ObjectSchema{fs, u}, J.JObject{input}, p, Spec.Here{}) == True{} : Bool}:
  match p fs:
    case Nil{} f: UP.absurd({Spec.fault(S.ObjectSchema{f, u}, J.JObject{input}, [], Spec.Here{}) == True{} : Bool}, UP.false_true(hs))
    case S.PathIndex{n} <> q f: UP.absurd({Spec.fault(S.ObjectSchema{f, u}, J.JObject{input}, S.PathIndex{n} <> q, Spec.Here{}) == True{} : Bool}, UP.false_true(hs))
    case S.PathKey{k} <> q Nil{}: UP.absurd({Spec.fault(S.ObjectSchema{[], u}, J.JObject{input}, S.PathKey{k} <> q, Spec.Here{}) == True{} : Bool}, UP.false_true(hs))
    case S.PathKey{+k} <> +q S.Field{+key, +c, +pr} <> +t: keyed_here(Spec.stray(u, S.Field{key, c, pr} <> t, input, k, q), String.eq(key, k) && (Spec.miscount(pr, Spec.named(input, key), q) || (Nat.is_eq(Spec.named(input, key), 1n) && Spec.fault(c, Spec.member(input, key), q, Spec.Here{}))), Spec.fault(S.ObjectSchema{t, u}, J.JObject{input}, S.PathKey{k} <> q, Spec.Keyed{}), slots_keyed(S.Field{key, c, pr} <> t, u, input, k, q, hs))

def fields_here(+es: List<&2, S.Error>, +fs: List<&2, S.Field>, +u: S.Unknown, +input: List<&2, J.Field>, +o: S.Out, +hs: {all_sf(es, S.WFields{S.slots(fs, input), o}, S.ObjectSchema{fs, u}, J.JObject{input}) == True{} : Bool}) -> {all_here(es, S.ObjectSchema{fs, u}, J.JObject{input}) == True{} : Bool}:
  match es:
    case Nil{}: {==}
    case e <> t: and_both(Spec.fault(S.ObjectSchema{fs, u}, J.JObject{input}, err_path(e), Spec.Here{}), all_here(t, S.ObjectSchema{fs, u}, J.JObject{input}), slots_here(err_path(e), fs, u, input, UP.and_left(slots_fault(err_path(e), fs, S.slots(fs, input)), all_sf(t, S.WFields{S.slots(fs, input), o}, S.ObjectSchema{fs, u}, J.JObject{input}), hs)), fields_here(t, fs, u, input, o, UP.and_right(slots_fault(err_path(e), fs, S.slots(fs, input)), all_sf(t, S.WFields{S.slots(fs, input), o}, S.ObjectSchema{fs, u}, J.JObject{input}), hs)))

# Undeclared members.

def stray_at(p: List<&2, S.PathPart>, fs: List<&2, S.Field>, input: List<&2, J.Field>) -> Bool:
  match p:
    case S.PathKey{+k} <> q: Bool.not(Spec.declares(fs, k)) && Bool.not(Nat.is_eq(Spec.named(input, k), 0n)) && Spec.ends(q)
    case _: False{}

def all_stray(es: List<&2, S.Error>, +fs: List<&2, S.Field>, +input: List<&2, J.Field>) -> Bool:
  match es:
    case Nil{}: True{}
    case e <> t: stray_at(err_path(e), fs, input) && all_stray(t, fs, input)

def stray_cat(+a: List<&2, S.Error>, +b: List<&2, S.Error>, +fs: List<&2, S.Field>, +input: List<&2, J.Field>) -> {all_stray(cat(a, b), fs, input) == (all_stray(a, fs, input) && all_stray(b, fs, input)) : Bool}:
  match a:
    case Nil{}: {==}
    case e <> t:
      %Equal.sym(Bool, all_stray(cat(t, b), fs, input), (all_stray(t, fs, input) && all_stray(b, fs, input)), stray_cat(t, b, fs, input)) : {(stray_at(err_path(e), fs, input) && _) == ((stray_at(err_path(e), fs, input) && all_stray(t, fs, input)) && all_stray(b, fs, input)) : Bool}
      Equal.sym(Bool, ((stray_at(err_path(e), fs, input) && all_stray(t, fs, input)) && all_stray(b, fs, input)), (stray_at(err_path(e), fs, input) && (all_stray(t, fs, input) && all_stray(b, fs, input))), SP.and_assoc(stray_at(err_path(e), fs, input), all_stray(t, fs, input), all_stray(b, fs, input)))

def nz_bump(+b: Bool, +n: Nat, h: {Bool.not(Nat.is_eq(n, 0n)) == True{} : Bool}) -> {Bool.not(Nat.is_eq(Spec.bump(b, n), 0n)) == True{} : Bool}:
  match b:
    case True{}: {==}
    case False{}: h

def stray_widen1(+p: List<&2, S.PathPart>, +fs: List<&2, S.Field>, +key: String, +y: J.Json, +t: List<&2, J.Field>, +h: {stray_at(p, fs, t) == True{} : Bool}) -> {stray_at(p, fs, J.Field{key, y} <> t) == True{} : Bool}:
  match p:
    case Nil{}: UP.absurd({False{} == True{} : Bool}, UP.false_true(h))
    case S.PathIndex{n} <> q: UP.absurd({False{} == True{} : Bool}, UP.false_true(h))
    case S.PathKey{+k} <> +q: and_both(Bool.not(Spec.declares(fs, k)) && Bool.not(Nat.is_eq(Spec.named(J.Field{key, y} <> t, k), 0n)), Spec.ends(q), and_both(Bool.not(Spec.declares(fs, k)), Bool.not(Nat.is_eq(Spec.named(J.Field{key, y} <> t, k), 0n)), UP.and_left(Bool.not(Spec.declares(fs, k)), Bool.not(Nat.is_eq(Spec.named(t, k), 0n)), UP.and_left(Bool.not(Spec.declares(fs, k)) && Bool.not(Nat.is_eq(Spec.named(t, k), 0n)), Spec.ends(q), h)), nz_bump(String.eq(key, k), Spec.named(t, k), UP.and_right(Bool.not(Spec.declares(fs, k)), Bool.not(Nat.is_eq(Spec.named(t, k), 0n)), UP.and_left(Bool.not(Spec.declares(fs, k)) && Bool.not(Nat.is_eq(Spec.named(t, k), 0n)), Spec.ends(q), h)))), UP.and_right(Bool.not(Spec.declares(fs, k)) && Bool.not(Nat.is_eq(Spec.named(t, k), 0n)), Spec.ends(q), h))

def stray_widen(+es: List<&2, S.Error>, +fs: List<&2, S.Field>, +key: String, +y: J.Json, +t: List<&2, J.Field>, +h: {all_stray(es, fs, t) == True{} : Bool}) -> {all_stray(es, fs, J.Field{key, y} <> t) == True{} : Bool}:
  match es:
    case Nil{}: {==}
    case e <> u: and_both(stray_at(err_path(e), fs, J.Field{key, y} <> t), all_stray(u, fs, J.Field{key, y} <> t), stray_widen1(err_path(e), fs, key, y, t, UP.and_left(stray_at(err_path(e), fs, t), all_stray(u, fs, t), h)), stray_widen(u, fs, key, y, t, UP.and_right(stray_at(err_path(e), fs, t), all_stray(u, fs, t), h)))

def strays_frame_step(+t: List<&2, J.Field>, +fs: List<&2, S.Field>, +e: S.Error, +r: List<&2, S.Error>, +n: Nat, b: Bool, ih_t: {S.strays(t, fs, S.Out{r, 1n+n}) == extend(S.strays(t, fs, S.Out{[], 1n+n}), r) : S.Out}, ih_f1: {S.strays(t, fs, S.Out{[e], n}) == extend(S.strays(t, fs, S.Out{[], n}), [e]) : S.Out}, ih_f2: {S.strays(t, fs, S.Out{e <> r, n}) == extend(S.strays(t, fs, S.Out{[], n}), e <> r) : S.Out}) -> {S.strays(t, fs, S.emit(b, e, S.Out{r, 1n+n})) == extend(S.strays(t, fs, S.emit(b, e, S.Out{[], 1n+n})), r) : S.Out}:
  match b:
    case True{}: ih_t
    case False{}: shift_frame(S.strays(t, fs, S.Out{[], n}), S.strays(t, fs, S.Out{[e], n}), [e], r, e <> r, S.strays(t, fs, S.Out{e <> r, n}), ih_f2, {==}, ih_f1)

def strays_frame(+input: List<&2, J.Field>, +fs: List<&2, S.Field>, +r: List<&2, S.Error>, +l: Nat) -> {S.strays(input, fs, S.Out{r, l}) == extend(S.strays(input, fs, S.Out{[], l}), r) : S.Out}:
  match input l:
    case Nil{} 0n: {==}
    case Nil{} 1n+n: {==}
    case J.Field{k, v} <> t 0n: {==}
    case J.Field{+k, v} <> +t 1n+(+n): strays_frame_step(t, fs, S.Error{S.Constraint{}, "object has an undeclared key", [S.PathKey{k}]}, r, n, S.declared(fs, k), strays_frame(t, fs, r, 1n+n), strays_frame(t, fs, [S.Error{S.Constraint{}, "object has an undeclared key", [S.PathKey{k}]}], n), strays_frame(t, fs, S.Error{S.Constraint{}, "object has an undeclared key", [S.PathKey{k}]} <> r, n))

def strays_sound_step(+t: List<&2, J.Field>, +fs: List<&2, S.Field>, +key: String, +y: J.Json, +n: Nat, b: Bool, hb: {S.declared(fs, key) == b : Bool}, ih_t: {all_stray(revs(S.strays(t, fs, S.Out{[], 1n+n})), fs, t) == True{} : Bool}, ih_f: {all_stray(revs(S.strays(t, fs, S.Out{[], n})), fs, t) == True{} : Bool}, hfr: {S.strays(t, fs, S.Out{[S.Error{S.Constraint{}, "object has an undeclared key", [S.PathKey{key}]}], n}) == extend(S.strays(t, fs, S.Out{[], n}), [S.Error{S.Constraint{}, "object has an undeclared key", [S.PathKey{key}]}]) : S.Out}) -> {all_stray(revs(S.strays(t, fs, S.emit(b, S.Error{S.Constraint{}, "object has an undeclared key", [S.PathKey{key}]}, S.Out{[], 1n+n}))), fs, J.Field{key, y} <> t) == True{} : Bool}:
  match b:
    case True{}: stray_widen(revs(S.strays(t, fs, S.Out{[], 1n+n})), fs, key, y, t, ih_t)
    case False{}:
      %Equal.sym(S.Out, S.strays(t, fs, S.Out{[S.Error{S.Constraint{}, "object has an undeclared key", [S.PathKey{key}]}], n}), extend(S.strays(t, fs, S.Out{[], n}), [S.Error{S.Constraint{}, "object has an undeclared key", [S.PathKey{key}]}]), hfr) : {all_stray(revs(_), fs, J.Field{key, y} <> t) == True{} : Bool}
      %Equal.sym(List<&2, S.Error>, revs(extend(S.strays(t, fs, S.Out{[], n}), [S.Error{S.Constraint{}, "object has an undeclared key", [S.PathKey{key}]}])), cat(revs(S.strays(t, fs, S.Out{[], n})), [S.Error{S.Constraint{}, "object has an undeclared key", [S.PathKey{key}]}]), revs_extend(S.strays(t, fs, S.Out{[], n}), [S.Error{S.Constraint{}, "object has an undeclared key", [S.PathKey{key}]}])) : {all_stray(_, fs, J.Field{key, y} <> t) == True{} : Bool}
      %Equal.sym(Bool, all_stray(cat(revs(S.strays(t, fs, S.Out{[], n})), [S.Error{S.Constraint{}, "object has an undeclared key", [S.PathKey{key}]}]), fs, J.Field{key, y} <> t), (all_stray(revs(S.strays(t, fs, S.Out{[], n})), fs, J.Field{key, y} <> t) && all_stray([S.Error{S.Constraint{}, "object has an undeclared key", [S.PathKey{key}]}], fs, J.Field{key, y} <> t)), stray_cat(revs(S.strays(t, fs, S.Out{[], n})), [S.Error{S.Constraint{}, "object has an undeclared key", [S.PathKey{key}]}], fs, J.Field{key, y} <> t)) : {_ == True{} : Bool}
      %SP.declared_equiv(fs, key) : {(all_stray(revs(S.strays(t, fs, S.Out{[], n})), fs, J.Field{key, y} <> t) && (((Bool.not(_) && Bool.not(Nat.is_eq(Spec.named(J.Field{key, y} <> t, key), 0n))) && True{}) && True{})) == True{} : Bool}
      %Equal.sym(Bool, S.declared(fs, key), False{}, hb) : {(all_stray(revs(S.strays(t, fs, S.Out{[], n})), fs, J.Field{key, y} <> t) && (((Bool.not(_) && Bool.not(Nat.is_eq(Spec.named(J.Field{key, y} <> t, key), 0n))) && True{}) && True{})) == True{} : Bool}
      %Equal.sym(Bool, String.eq(key, key), True{}, string_refl(key)) : {(all_stray(revs(S.strays(t, fs, S.Out{[], n})), fs, J.Field{key, y} <> t) && (((Bool.not(False{}) && Bool.not(Nat.is_eq(Spec.bump(_, Spec.named(t, key)), 0n))) && True{}) && True{})) == True{} : Bool}
      and_both(all_stray(revs(S.strays(t, fs, S.Out{[], n})), fs, J.Field{key, y} <> t), True{}, stray_widen(revs(S.strays(t, fs, S.Out{[], n})), fs, key, y, t, ih_f), {==})

def strays_sound(+input: List<&2, J.Field>, +fs: List<&2, S.Field>, +l: Nat) -> {all_stray(revs(S.strays(input, fs, S.Out{[], l})), fs, input) == True{} : Bool}:
  match input l:
    case Nil{} 0n: {==}
    case Nil{} 1n+n: {==}
    case J.Field{k, v} <> t 0n: {==}
    case J.Field{+key, +y} <> +t 1n+(+n): strays_sound_step(t, fs, key, y, n, S.declared(fs, key), {==}, strays_sound(t, fs, 1n+n), strays_sound(t, fs, n), strays_frame(t, fs, [S.Error{S.Constraint{}, "object has an undeclared key", [S.PathKey{key}]}], n))

def stray_here(+p: List<&2, S.PathPart>, +fs: List<&2, S.Field>, +input: List<&2, J.Field>, h: {stray_at(p, fs, input) == True{} : Bool}) -> {Spec.fault(S.ObjectSchema{fs, S.Strict{}}, J.JObject{input}, p, Spec.Here{}) == True{} : Bool}:
  match p fs:
    case Nil{} f: UP.absurd({Spec.fault(S.ObjectSchema{f, S.Strict{}}, J.JObject{input}, [], Spec.Here{}) == True{} : Bool}, UP.false_true(h))
    case S.PathIndex{n} <> q f: UP.absurd({Spec.fault(S.ObjectSchema{f, S.Strict{}}, J.JObject{input}, S.PathIndex{n} <> q, Spec.Here{}) == True{} : Bool}, UP.false_true(h))
    case S.PathKey{k} <> q Nil{}: h
    case S.PathKey{+k} <> +q S.Field{+key, +c, +pr} <> +t: or_left(Spec.stray(S.Strict{}, S.Field{key, c, pr} <> t, input, k, q) || (String.eq(key, k) && (Spec.miscount(pr, Spec.named(input, key), q) || (Nat.is_eq(Spec.named(input, key), 1n) && Spec.fault(c, Spec.member(input, key), q, Spec.Here{})))), Spec.fault(S.ObjectSchema{t, S.Strict{}}, J.JObject{input}, S.PathKey{k} <> q, Spec.Keyed{}), or_left(Spec.stray(S.Strict{}, S.Field{key, c, pr} <> t, input, k, q), String.eq(key, k) && (Spec.miscount(pr, Spec.named(input, key), q) || (Nat.is_eq(Spec.named(input, key), 1n) && Spec.fault(c, Spec.member(input, key), q, Spec.Here{}))), h))

def strays_here(+es: List<&2, S.Error>, +fs: List<&2, S.Field>, +input: List<&2, J.Field>, +h: {all_stray(es, fs, input) == True{} : Bool}) -> {all_here(es, S.ObjectSchema{fs, S.Strict{}}, J.JObject{input}) == True{} : Bool}:
  match es:
    case Nil{}: {==}
    case e <> t: and_both(Spec.fault(S.ObjectSchema{fs, S.Strict{}}, J.JObject{input}, err_path(e), Spec.Here{}), all_here(t, S.ObjectSchema{fs, S.Strict{}}, J.JObject{input}), stray_here(err_path(e), fs, input, UP.and_left(stray_at(err_path(e), fs, input), all_stray(t, fs, input), h)), strays_here(t, fs, input, UP.and_right(stray_at(err_path(e), fs, input), all_stray(t, fs, input), h)))

def unknown_here(+u: S.Unknown, +fs: List<&2, S.Field>, +input: List<&2, J.Field>, +l: Nat) -> {all_here(revs(S.unknown_out(u, fs, input, S.Out{[], l})), S.ObjectSchema{fs, u}, J.JObject{input}) == True{} : Bool}:
  match u:
    case S.Strict{}: strays_here(revs(S.strays(input, fs, S.Out{[], l})), fs, input, strays_sound(input, fs, l))
    case S.Strip{}: {==}

def item_here1(+p: List<&2, S.PathPart>, +i: S.Schema, +m: Nat, +n: Maybe<&2, Nat>, +xs: List<&2, J.Json>, hok: {(Nat.is_le(m, Spec.size(xs)) && Spec.at_most(n, Spec.size(xs))) == True{} : Bool}, h: {items_at(p, i, J.JArray{xs}, 0n) == True{} : Bool}) -> {Spec.fault(S.ArraySchema{i, m, n}, J.JArray{xs}, p, Spec.Here{}) == True{} : Bool}:
  match p:
    case Nil{}: UP.absurd({Spec.fault(S.ArraySchema{i, m, n}, J.JArray{xs}, [], Spec.Here{}) == True{} : Bool}, UP.false_true(h))
    case S.PathKey{a} <> q: UP.absurd({Spec.fault(S.ArraySchema{i, m, n}, J.JArray{xs}, S.PathKey{a} <> q, Spec.Here{}) == True{} : Bool}, UP.false_true(h))
    case S.PathIndex{+j} <> +q:
      match xs:
        case Nil{}: UP.absurd({Spec.fault(S.ArraySchema{i, m, n}, J.JArray{[]}, S.PathIndex{j} <> q, Spec.Here{}) == True{} : Bool}, UP.false_true(h))
        case +g <> +r: and_both(Nat.is_le(m, Spec.size(g <> r)) && Spec.at_most(n, Spec.size(g <> r)), Spec.fault(i, J.JArray{g <> r}, S.PathIndex{j} <> q, Spec.From{0n}), hok, h)

def items_here(+es: List<&2, S.Error>, +i: S.Schema, +m: Nat, +n: Maybe<&2, Nat>, +xs: List<&2, J.Json>, +o: S.Out, +hok: {(Nat.is_le(m, Spec.size(xs)) && Spec.at_most(n, Spec.size(xs))) == True{} : Bool}, +hs: {all_sf(es, S.WItems{0n, o}, S.ArraySchema{i, m, n}, J.JArray{xs}) == True{} : Bool}) -> {all_here(es, S.ArraySchema{i, m, n}, J.JArray{xs}) == True{} : Bool}:
  match es:
    case Nil{}: {==}
    case e <> t: and_both(Spec.fault(S.ArraySchema{i, m, n}, J.JArray{xs}, err_path(e), Spec.Here{}), all_here(t, S.ArraySchema{i, m, n}, J.JArray{xs}), item_here1(err_path(e), i, m, n, xs, hok, UP.and_left(items_at(err_path(e), i, J.JArray{xs}, 0n), all_sf(t, S.WItems{0n, o}, S.ArraySchema{i, m, n}, J.JArray{xs}), hs)), items_here(t, i, m, n, xs, o, hok, UP.and_right(items_at(err_path(e), i, J.JArray{xs}, 0n), all_sf(t, S.WItems{0n, o}, S.ArraySchema{i, m, n}, J.JArray{xs}), hs)))

def gate_here(+i: S.Schema, +m: Nat, +n: Maybe<&2, Nat>, +xs: List<&2, J.Json>, +l: Nat, hb: {False{} == (Nat.is_le(m, Spec.size(xs)) && Spec.at_most(n, Spec.size(xs))) : Bool}) -> {all_here(revs(S.collect_go(S.ArraySchema{i, m, n}, J.JArray{xs}, S.WDone{S.emit(False{}, S.Error{S.Constraint{}, "array length out of bounds", []}, S.Out{[], l})})), S.ArraySchema{i, m, n}, J.JArray{xs}) == True{} : Bool}:
  match xs l:
    case Nil{} 0n: {==}
    case Nil{} 1n+k:
      %hb : {(Bool.not(_) && True{}) == True{} : Bool}
      {==}
    case g <> r 0n: {==}
    case g <> r 1n+k:
      %hb : {(Bool.not(_) && True{}) == True{} : Bool}
      {==}

def count_ok_eq(+m: Nat, +n: Maybe<&2, Nat>, +xs: List<&2, J.Json>) -> {S.item_count(m, n, S.count(xs, 0n)) == (Nat.is_le(m, Spec.size(xs)) && Spec.at_most(n, Spec.size(xs))) : Bool}:
  %SC.count_equiv(xs) : {S.item_count(m, n, S.count(xs, 0n)) == (Nat.is_le(m, _) && Spec.at_most(n, _)) : Bool}
  %SP.max_equiv(n, S.count(xs, 0n)) : {S.item_count(m, n, S.count(xs, 0n)) == (Nat.is_le(m, S.count(xs, 0n)) && _) : Bool}
  {==}

def arr_entry_s(+i: S.Schema, +m: Nat, +n: Maybe<&2, Nat>, +xs: List<&2, J.Json>, +l: Nat, b: Bool, hb: {b == (Nat.is_le(m, Spec.size(xs)) && Spec.at_most(n, Spec.size(xs))) : Bool}, hs: {all_sf(revs(S.collect_go(S.ArraySchema{i, m, n}, J.JArray{xs}, blank(S.items_walk(b, l)))), S.items_walk(b, l), S.ArraySchema{i, m, n}, J.JArray{xs}) == True{} : Bool}) -> {all_here(revs(S.collect_go(S.ArraySchema{i, m, n}, J.JArray{xs}, S.items_walk(b, l))), S.ArraySchema{i, m, n}, J.JArray{xs}) == True{} : Bool}:
  match b:
    case True{}: items_here(revs(S.collect_go(S.ArraySchema{i, m, n}, J.JArray{xs}, S.WItems{0n, S.Out{[], l}})), i, m, n, xs, S.Out{[], l}, Equal.sym(Bool, True{}, (Nat.is_le(m, Spec.size(xs)) && Spec.at_most(n, Spec.size(xs))), hb), hs)
    case False{}: gate_here(i, m, n, xs, l, hb)

def obj_entry_s(+fs: List<&2, S.Field>, +u: S.Unknown, +input: List<&2, J.Field>, so: S.Out) -> {all_here(revs(so), S.ObjectSchema{fs, u}, J.JObject{input}) == True{} : Bool} -> {S.collect_go(S.ObjectSchema{fs, u}, J.JObject{input}, S.WFields{S.slots(fs, input), so}) == extend(S.collect_go(S.ObjectSchema{fs, u}, J.JObject{input}, blank(S.WFields{S.slots(fs, input), so})), wrev(S.WFields{S.slots(fs, input), so})) : S.Out} -> {all_sf(revs(S.collect_go(S.ObjectSchema{fs, u}, J.JObject{input}, blank(S.WFields{S.slots(fs, input), so}))), S.WFields{S.slots(fs, input), so}, S.ObjectSchema{fs, u}, J.JObject{input}) == True{} : Bool} -> {all_here(revs(S.collect_go(S.ObjectSchema{fs, u}, J.JObject{input}, S.WFields{S.slots(fs, input), so})), S.ObjectSchema{fs, u}, J.JObject{input}) == True{} : Bool}:
  match so:
    case S.Out{+r0, +l0}: hst => hfr => hs =>
      %Equal.sym(S.Out, S.collect_go(S.ObjectSchema{fs, u}, J.JObject{input}, S.WFields{S.slots(fs, input), S.Out{r0, l0}}), extend(S.collect_go(S.ObjectSchema{fs, u}, J.JObject{input}, S.WFields{S.slots(fs, input), S.Out{[], l0}}), r0), hfr) : {all_here(revs(_), S.ObjectSchema{fs, u}, J.JObject{input}) == True{} : Bool}
      %Equal.sym(List<&2, S.Error>, revs(extend(S.collect_go(S.ObjectSchema{fs, u}, J.JObject{input}, S.WFields{S.slots(fs, input), S.Out{[], l0}}), r0)), cat(revs(S.collect_go(S.ObjectSchema{fs, u}, J.JObject{input}, S.WFields{S.slots(fs, input), S.Out{[], l0}})), r0), revs_extend(S.collect_go(S.ObjectSchema{fs, u}, J.JObject{input}, S.WFields{S.slots(fs, input), S.Out{[], l0}}), r0)) : {all_here(_, S.ObjectSchema{fs, u}, J.JObject{input}) == True{} : Bool}
      %Equal.sym(Bool, all_here(cat(revs(S.collect_go(S.ObjectSchema{fs, u}, J.JObject{input}, S.WFields{S.slots(fs, input), S.Out{[], l0}})), r0), S.ObjectSchema{fs, u}, J.JObject{input}), (all_here(revs(S.collect_go(S.ObjectSchema{fs, u}, J.JObject{input}, S.WFields{S.slots(fs, input), S.Out{[], l0}})), S.ObjectSchema{fs, u}, J.JObject{input}) && all_here(r0, S.ObjectSchema{fs, u}, J.JObject{input})), here_cat(revs(S.collect_go(S.ObjectSchema{fs, u}, J.JObject{input}, S.WFields{S.slots(fs, input), S.Out{[], l0}})), r0, S.ObjectSchema{fs, u}, J.JObject{input})) : {_ == True{} : Bool}
      and_both(all_here(revs(S.collect_go(S.ObjectSchema{fs, u}, J.JObject{input}, S.WFields{S.slots(fs, input), S.Out{[], l0}})), S.ObjectSchema{fs, u}, J.JObject{input}), all_here(r0, S.ObjectSchema{fs, u}, J.JObject{input}), fields_here(revs(S.collect_go(S.ObjectSchema{fs, u}, J.JObject{input}, S.WFields{S.slots(fs, input), S.Out{[], l0}})), fs, u, input, S.Out{r0, l0}, hs), hst)

def here_entry(+es: List<&2, S.Error>, +l: Nat, +s: S.Schema, +v: J.Json, hs: {all_sf(es, S.WHere{l}, s, v) == True{} : Bool}) -> {all_here(es, s, v) == True{} : Bool}:
  Equal.trans(Bool, all_here(es, s, v), all_sf(es, S.WHere{l}, s, v), True{}, Equal.sym(Bool, all_sf(es, S.WHere{l}, s, v), all_here(es, s, v), here_eq(es, l, s, v)), hs)

# A child's state, started by cstart, reports locations of the child itself.
def entry_s(+s: S.Schema, +v: J.Json, +l: Nat, hs: {all_sf(revs(S.collect_go(s, v, blank(S.cstart(s, v, l)))), S.cstart(s, v, l), s, v) == True{} : Bool}) -> {all_here(revs(S.collect_go(s, v, S.cstart(s, v, l))), s, v) == True{} : Bool}:
  match s v:
    case S.ArraySchema{i, m, n} J.JArray{xs}: arr_entry_s(i, m, n, xs, l, S.item_count(m, n, S.count(xs, 0n)), count_ok_eq(m, n, xs), hs)
    case S.ArraySchema{i, m, n} J.JNull{}: here_entry(revs(S.collect_go(S.ArraySchema{i, m, n}, J.JNull{}, S.WHere{l})), l, S.ArraySchema{i, m, n}, J.JNull{}, hs)
    case S.ArraySchema{i, m, n} J.JBool{b0}: here_entry(revs(S.collect_go(S.ArraySchema{i, m, n}, J.JBool{b0}, S.WHere{l})), l, S.ArraySchema{i, m, n}, J.JBool{b0}, hs)
    case S.ArraySchema{i, m, n} J.JNumber{b0}: here_entry(revs(S.collect_go(S.ArraySchema{i, m, n}, J.JNumber{b0}, S.WHere{l})), l, S.ArraySchema{i, m, n}, J.JNumber{b0}, hs)
    case S.ArraySchema{i, m, n} J.JString{b0}: here_entry(revs(S.collect_go(S.ArraySchema{i, m, n}, J.JString{b0}, S.WHere{l})), l, S.ArraySchema{i, m, n}, J.JString{b0}, hs)
    case S.ArraySchema{i, m, n} J.JObject{b0}: here_entry(revs(S.collect_go(S.ArraySchema{i, m, n}, J.JObject{b0}, S.WHere{l})), l, S.ArraySchema{i, m, n}, J.JObject{b0}, hs)
    case S.ObjectSchema{+fs, +u} J.JObject{+input}: obj_entry_s(fs, u, input, S.unknown_out(u, fs, input, S.Out{[], l}))(unknown_here(u, fs, input, l))(frame(S.ObjectSchema{fs, u}, J.JObject{input}, S.WFields{S.slots(fs, input), S.unknown_out(u, fs, input, S.Out{[], l})}))(hs)
    case S.ObjectSchema{fs, u} J.JNull{}: here_entry(revs(S.collect_go(S.ObjectSchema{fs, u}, J.JNull{}, S.WHere{l})), l, S.ObjectSchema{fs, u}, J.JNull{}, hs)
    case S.ObjectSchema{fs, u} J.JBool{b0}: here_entry(revs(S.collect_go(S.ObjectSchema{fs, u}, J.JBool{b0}, S.WHere{l})), l, S.ObjectSchema{fs, u}, J.JBool{b0}, hs)
    case S.ObjectSchema{fs, u} J.JNumber{b0}: here_entry(revs(S.collect_go(S.ObjectSchema{fs, u}, J.JNumber{b0}, S.WHere{l})), l, S.ObjectSchema{fs, u}, J.JNumber{b0}, hs)
    case S.ObjectSchema{fs, u} J.JString{b0}: here_entry(revs(S.collect_go(S.ObjectSchema{fs, u}, J.JString{b0}, S.WHere{l})), l, S.ObjectSchema{fs, u}, J.JString{b0}, hs)
    case S.ObjectSchema{fs, u} J.JArray{b0}: here_entry(revs(S.collect_go(S.ObjectSchema{fs, u}, J.JArray{b0}, S.WHere{l})), l, S.ObjectSchema{fs, u}, J.JArray{b0}, hs)
    case S.StringSchema{a1, a2, a3, a4} x: here_entry(revs(S.collect_go(S.StringSchema{a1, a2, a3, a4}, x, S.WHere{l})), l, S.StringSchema{a1, a2, a3, a4}, x, hs)
    case S.NumberSchema{a1, a2} x: here_entry(revs(S.collect_go(S.NumberSchema{a1, a2}, x, S.WHere{l})), l, S.NumberSchema{a1, a2}, x, hs)
    case S.IntegerSchema{a1, a2} x: here_entry(revs(S.collect_go(S.IntegerSchema{a1, a2}, x, S.WHere{l})), l, S.IntegerSchema{a1, a2}, x, hs)
    case S.BooleanSchema{} x: here_entry(revs(S.collect_go(S.BooleanSchema{}, x, S.WHere{l})), l, S.BooleanSchema{}, x, hs)
    case S.LiteralSchema{a1} x: here_entry(revs(S.collect_go(S.LiteralSchema{a1}, x, S.WHere{l})), l, S.LiteralSchema{a1}, x, hs)
    case S.EnumSchema{a1} x: here_entry(revs(S.collect_go(S.EnumSchema{a1}, x, S.WHere{l})), l, S.EnumSchema{a1}, x, hs)
    case S.NullableSchema{i} x: here_entry(revs(S.collect_go(S.NullableSchema{i}, x, S.WHere{l})), l, S.NullableSchema{i}, x, hs)
    case S.UnionSchema{ms} x: here_entry(revs(S.collect_go(S.UnionSchema{ms}, x, S.WHere{l})), l, S.UnionSchema{ms}, x, hs)

def items_reach(+b: Bool, +l: Nat, +i: S.Schema, +m: Nat, +n: Maybe<&2, Nat>, +xs: List<&2, J.Json>) -> {reach(S.items_walk(b, l), S.ArraySchema{i, m, n}, J.JArray{xs}) == True{} : Bool}:
  match b:
    case True{}: {==}
    case False{}: {==}

def cstart_reach(+s: S.Schema, +v: J.Json, +l: Nat) -> {reach(S.cstart(s, v, l), s, v) == True{} : Bool}:
  match s v:
    case S.ArraySchema{i, m, n} J.JArray{xs}: items_reach(S.item_count(m, n, S.count(xs, 0n)), l, i, m, n, xs)
    case S.ArraySchema{i, m, n} J.JNull{}: {==}
    case S.ArraySchema{i, m, n} J.JBool{b0}: {==}
    case S.ArraySchema{i, m, n} J.JNumber{b0}: {==}
    case S.ArraySchema{i, m, n} J.JString{b0}: {==}
    case S.ArraySchema{i, m, n} J.JObject{b0}: {==}
    case S.ObjectSchema{fs, u} J.JObject{input}: {==}
    case S.ObjectSchema{fs, u} J.JNull{}: {==}
    case S.ObjectSchema{fs, u} J.JBool{b0}: {==}
    case S.ObjectSchema{fs, u} J.JNumber{b0}: {==}
    case S.ObjectSchema{fs, u} J.JString{b0}: {==}
    case S.ObjectSchema{fs, u} J.JArray{b0}: {==}
    case S.StringSchema{a1, a2, a3, a4} x: {==}
    case S.NumberSchema{a1, a2} x: {==}
    case S.IntegerSchema{a1, a2} x: {==}
    case S.BooleanSchema{} x: {==}
    case S.LiteralSchema{a1} x: {==}
    case S.EnumSchema{a1} x: {==}
    case S.NullableSchema{i} x: {==}
    case S.UnionSchema{ms} x: {==}

def arr_sound(+i: S.Schema, +m: Nat, +n: Maybe<&2, Nat>, +h: J.Json, +t: List<&2, J.Json>, +k: Nat, +o2: S.Out, cc: S.Out) -> {S.collect_go(S.ArraySchema{i, m, n}, J.JArray{t}, S.WItems{1n+k, S.merge(S.PathIndex{k}, cc, [])}) == extend(S.collect_go(S.ArraySchema{i, m, n}, J.JArray{t}, blank(S.WItems{1n+k, S.merge(S.PathIndex{k}, cc, [])})), wrev(S.WItems{1n+k, S.merge(S.PathIndex{k}, cc, [])})) : S.Out} -> {all_sf(revs(S.collect_go(S.ArraySchema{i, m, n}, J.JArray{t}, blank(S.WItems{1n+k, S.merge(S.PathIndex{k}, cc, [])}))), S.WItems{1n+k, S.merge(S.PathIndex{k}, cc, [])}, S.ArraySchema{i, m, n}, J.JArray{t}) == True{} : Bool} -> {all_here(revs(cc), i, h) == True{} : Bool} -> {all_sf(revs(S.collect_go(S.ArraySchema{i, m, n}, J.JArray{t}, S.WItems{1n+k, S.merge(S.PathIndex{k}, cc, [])})), S.WItems{k, o2}, S.ArraySchema{i, m, n}, J.JArray{h <> t}) == True{} : Bool}:
  match cc:
    case S.Out{+es, +cl}: hfr => ih => hc =>
      %Equal.sym(S.Out, S.collect_go(S.ArraySchema{i, m, n}, J.JArray{t}, S.WItems{1n+k, S.Out{S.prefix_onto(S.PathIndex{k}, es, []), cl}}), extend(S.collect_go(S.ArraySchema{i, m, n}, J.JArray{t}, S.WItems{1n+k, S.Out{[], cl}}), S.prefix_onto(S.PathIndex{k}, es, [])), hfr) : {all_sf(revs(_), S.WItems{k, o2}, S.ArraySchema{i, m, n}, J.JArray{h <> t}) == True{} : Bool}
      %Equal.sym(List<&2, S.Error>, revs(extend(S.collect_go(S.ArraySchema{i, m, n}, J.JArray{t}, S.WItems{1n+k, S.Out{[], cl}}), S.prefix_onto(S.PathIndex{k}, es, []))), cat(revs(S.collect_go(S.ArraySchema{i, m, n}, J.JArray{t}, S.WItems{1n+k, S.Out{[], cl}})), S.prefix_onto(S.PathIndex{k}, es, [])), revs_extend(S.collect_go(S.ArraySchema{i, m, n}, J.JArray{t}, S.WItems{1n+k, S.Out{[], cl}}), S.prefix_onto(S.PathIndex{k}, es, []))) : {all_sf(_, S.WItems{k, o2}, S.ArraySchema{i, m, n}, J.JArray{h <> t}) == True{} : Bool}
      %Equal.sym(Bool, all_sf(cat(revs(S.collect_go(S.ArraySchema{i, m, n}, J.JArray{t}, S.WItems{1n+k, S.Out{[], cl}})), S.prefix_onto(S.PathIndex{k}, es, [])), S.WItems{k, o2}, S.ArraySchema{i, m, n}, J.JArray{h <> t}), (all_sf(revs(S.collect_go(S.ArraySchema{i, m, n}, J.JArray{t}, S.WItems{1n+k, S.Out{[], cl}})), S.WItems{k, o2}, S.ArraySchema{i, m, n}, J.JArray{h <> t}) && all_sf(S.prefix_onto(S.PathIndex{k}, es, []), S.WItems{k, o2}, S.ArraySchema{i, m, n}, J.JArray{h <> t})), all_cat(revs(S.collect_go(S.ArraySchema{i, m, n}, J.JArray{t}, S.WItems{1n+k, S.Out{[], cl}})), S.prefix_onto(S.PathIndex{k}, es, []), S.WItems{k, o2}, S.ArraySchema{i, m, n}, J.JArray{h <> t})) : {_ == True{} : Bool}
      and_both(all_sf(revs(S.collect_go(S.ArraySchema{i, m, n}, J.JArray{t}, S.WItems{1n+k, S.Out{[], cl}})), S.WItems{k, o2}, S.ArraySchema{i, m, n}, J.JArray{h <> t}), all_sf(S.prefix_onto(S.PathIndex{k}, es, []), S.WItems{k, o2}, S.ArraySchema{i, m, n}, J.JArray{h <> t}), widen_items(revs(S.collect_go(S.ArraySchema{i, m, n}, J.JArray{t}, S.WItems{1n+k, S.Out{[], cl}})), i, m, n, h, t, k, S.Out{S.prefix_onto(S.PathIndex{k}, es, []), cl}, o2, ih), prefix_items(es, i, m, n, h, t, k, o2, hc))

def widen_f1(+path: List<&2, S.PathPart>, +k: String, +c: S.Schema, +p: S.Presence, +t: List<&2, S.Field>, +sl: S.Slot, +rest: List<&2, S.Slot>, hp: {slots_fault(path, t, rest) == True{} : Bool}) -> {slots_fault(path, S.Field{k, c, p} <> t, sl <> rest) == True{} : Bool}:
  match path:
    case Nil{}: UP.absurd({False{} == True{} : Bool}, UP.false_true(hp))
    case S.PathIndex{a} <> q: UP.absurd({False{} == True{} : Bool}, UP.false_true(hp))
    case S.PathKey{+k2} <> +q: or_right(String.eq(k, k2) && slot_local(c, p, sl, q), slots_fault(S.PathKey{k2} <> q, t, rest), hp)

def widen_fields(+es: List<&2, S.Error>, +k: String, +c: S.Schema, +p: S.Presence, +t: List<&2, S.Field>, +u: S.Unknown, +x: J.Json, +sl: S.Slot, +rest: List<&2, S.Slot>, +o1: S.Out, +o2: S.Out, +he: {all_sf(es, S.WFields{rest, o1}, S.ObjectSchema{t, u}, x) == True{} : Bool}) -> {all_sf(es, S.WFields{sl <> rest, o2}, S.ObjectSchema{S.Field{k, c, p} <> t, u}, x) == True{} : Bool}:
  match es:
    case Nil{}: {==}
    case e <> v2: and_both(slots_fault(err_path(e), S.Field{k, c, p} <> t, sl <> rest), all_sf(v2, S.WFields{sl <> rest, o2}, S.ObjectSchema{S.Field{k, c, p} <> t, u}, x), widen_f1(err_path(e), k, c, p, t, sl, rest, UP.and_left(slots_fault(err_path(e), t, rest), all_sf(v2, S.WFields{rest, o1}, S.ObjectSchema{t, u}, x), he)), widen_fields(v2, k, c, p, t, u, x, sl, rest, o1, o2, UP.and_right(slots_fault(err_path(e), t, rest), all_sf(v2, S.WFields{rest, o1}, S.ObjectSchema{t, u}, x), he)))

def prefix_fields(+es: List<&2, S.Error>, +k: String, +c: S.Schema, +p: S.Presence, +t: List<&2, S.Field>, +u: S.Unknown, +x: J.Json, +y: J.Json, +rest: List<&2, S.Slot>, +o2: S.Out, +hc: {all_here(es, c, y) == True{} : Bool}) -> {all_sf(S.prefix_onto(S.PathKey{k}, es, []), S.WFields{S.Once{y} <> rest, o2}, S.ObjectSchema{S.Field{k, c, p} <> t, u}, x) == True{} : Bool}:
  match es:
    case Nil{}: {==}
    case S.Error{c0, m0, p0} <> v2: and_both(slots_fault(S.PathKey{k} <> p0, S.Field{k, c, p} <> t, S.Once{y} <> rest), all_sf(S.prefix_onto(S.PathKey{k}, v2, []), S.WFields{S.Once{y} <> rest, o2}, S.ObjectSchema{S.Field{k, c, p} <> t, u}, x), or_left(String.eq(k, k) && Spec.fault(c, y, p0, Spec.Here{}), slots_fault(S.PathKey{k} <> p0, t, rest), and_both(String.eq(k, k), Spec.fault(c, y, p0, Spec.Here{}), string_refl(k), UP.and_left(Spec.fault(c, y, p0, Spec.Here{}), all_here(v2, c, y), hc))), prefix_fields(v2, k, c, p, t, u, x, y, rest, o2, UP.and_right(Spec.fault(c, y, p0, Spec.Here{}), all_here(v2, c, y), hc)))

def obj_sound(+k: String, +c: S.Schema, +p: S.Presence, +t: List<&2, S.Field>, +u: S.Unknown, +x: J.Json, +y: J.Json, +rest: List<&2, S.Slot>, +o2: S.Out, cc: S.Out) -> {S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.merge(S.PathKey{k}, cc, [])}) == extend(S.collect_go(S.ObjectSchema{t, u}, x, blank(S.WFields{rest, S.merge(S.PathKey{k}, cc, [])})), wrev(S.WFields{rest, S.merge(S.PathKey{k}, cc, [])})) : S.Out} -> {all_sf(revs(S.collect_go(S.ObjectSchema{t, u}, x, blank(S.WFields{rest, S.merge(S.PathKey{k}, cc, [])}))), S.WFields{rest, S.merge(S.PathKey{k}, cc, [])}, S.ObjectSchema{t, u}, x) == True{} : Bool} -> {all_here(revs(cc), c, y) == True{} : Bool} -> {all_sf(revs(S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.merge(S.PathKey{k}, cc, [])})), S.WFields{S.Once{y} <> rest, o2}, S.ObjectSchema{S.Field{k, c, p} <> t, u}, x) == True{} : Bool}:
  match cc:
    case S.Out{+es, +cl}: hfr => ih => hc =>
      %Equal.sym(S.Out, S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{S.prefix_onto(S.PathKey{k}, es, []), cl}}), extend(S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{[], cl}}), S.prefix_onto(S.PathKey{k}, es, [])), hfr) : {all_sf(revs(_), S.WFields{S.Once{y} <> rest, o2}, S.ObjectSchema{S.Field{k, c, p} <> t, u}, x) == True{} : Bool}
      %Equal.sym(List<&2, S.Error>, revs(extend(S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{[], cl}}), S.prefix_onto(S.PathKey{k}, es, []))), cat(revs(S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{[], cl}})), S.prefix_onto(S.PathKey{k}, es, [])), revs_extend(S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{[], cl}}), S.prefix_onto(S.PathKey{k}, es, []))) : {all_sf(_, S.WFields{S.Once{y} <> rest, o2}, S.ObjectSchema{S.Field{k, c, p} <> t, u}, x) == True{} : Bool}
      %Equal.sym(Bool, all_sf(cat(revs(S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{[], cl}})), S.prefix_onto(S.PathKey{k}, es, [])), S.WFields{S.Once{y} <> rest, o2}, S.ObjectSchema{S.Field{k, c, p} <> t, u}, x), (all_sf(revs(S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{[], cl}})), S.WFields{S.Once{y} <> rest, o2}, S.ObjectSchema{S.Field{k, c, p} <> t, u}, x) && all_sf(S.prefix_onto(S.PathKey{k}, es, []), S.WFields{S.Once{y} <> rest, o2}, S.ObjectSchema{S.Field{k, c, p} <> t, u}, x)), all_cat(revs(S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{[], cl}})), S.prefix_onto(S.PathKey{k}, es, []), S.WFields{S.Once{y} <> rest, o2}, S.ObjectSchema{S.Field{k, c, p} <> t, u}, x)) : {_ == True{} : Bool}
      and_both(all_sf(revs(S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{[], cl}})), S.WFields{S.Once{y} <> rest, o2}, S.ObjectSchema{S.Field{k, c, p} <> t, u}, x), all_sf(S.prefix_onto(S.PathKey{k}, es, []), S.WFields{S.Once{y} <> rest, o2}, S.ObjectSchema{S.Field{k, c, p} <> t, u}, x), widen_fields(revs(S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{[], cl}})), k, c, p, t, u, x, S.Once{y}, rest, S.Out{S.prefix_onto(S.PathKey{k}, es, []), cl}, o2, ih), prefix_fields(es, k, c, p, t, u, x, y, rest, o2, hc))

# One error at a declared key, after the rest of the walk.
def key_sound(+k: String, +c: S.Schema, +p: S.Presence, +t: List<&2, S.Field>, +u: S.Unknown, +x: J.Json, +sl: S.Slot, +rest: List<&2, S.Slot>, +l: Nat, +o2: S.Out, +e: S.Error, hfr: {S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{[e], l}}) == extend(S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{[], l}}), [e]) : S.Out}, ih: {all_sf(revs(S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{[], l}})), S.WFields{rest, S.Out{[e], l}}, S.ObjectSchema{t, u}, x) == True{} : Bool}, he: {all_sf([e], S.WFields{sl <> rest, o2}, S.ObjectSchema{S.Field{k, c, p} <> t, u}, x) == True{} : Bool}) -> {all_sf(revs(S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{[e], l}})), S.WFields{sl <> rest, o2}, S.ObjectSchema{S.Field{k, c, p} <> t, u}, x) == True{} : Bool}:
  %Equal.sym(S.Out, S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{[e], l}}), extend(S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{[], l}}), [e]), hfr) : {all_sf(revs(_), S.WFields{sl <> rest, o2}, S.ObjectSchema{S.Field{k, c, p} <> t, u}, x) == True{} : Bool}
  %Equal.sym(List<&2, S.Error>, revs(extend(S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{[], l}}), [e])), cat(revs(S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{[], l}})), [e]), revs_extend(S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{[], l}}), [e])) : {all_sf(_, S.WFields{sl <> rest, o2}, S.ObjectSchema{S.Field{k, c, p} <> t, u}, x) == True{} : Bool}
  %Equal.sym(Bool, all_sf(cat(revs(S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{[], l}})), [e]), S.WFields{sl <> rest, o2}, S.ObjectSchema{S.Field{k, c, p} <> t, u}, x), (all_sf(revs(S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{[], l}})), S.WFields{sl <> rest, o2}, S.ObjectSchema{S.Field{k, c, p} <> t, u}, x) && all_sf([e], S.WFields{sl <> rest, o2}, S.ObjectSchema{S.Field{k, c, p} <> t, u}, x)), all_cat(revs(S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{[], l}})), [e], S.WFields{sl <> rest, o2}, S.ObjectSchema{S.Field{k, c, p} <> t, u}, x)) : {_ == True{} : Bool}
  and_both(all_sf(revs(S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{[], l}})), S.WFields{sl <> rest, o2}, S.ObjectSchema{S.Field{k, c, p} <> t, u}, x), all_sf([e], S.WFields{sl <> rest, o2}, S.ObjectSchema{S.Field{k, c, p} <> t, u}, x), widen_fields(revs(S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{[], l}})), k, c, p, t, u, x, sl, rest, S.Out{[e], l}, o2, ih), he)

def absent_one(+k: String, +c: S.Schema, +p: S.Presence, +t: List<&2, S.Field>, +u: S.Unknown, +x: J.Json, +rest: List<&2, S.Slot>, +o2: S.Out, hb: {S.may_be_absent(p) == False{} : Bool}) -> {all_sf([S.Error{S.Constraint{}, "missing required key", [S.PathKey{k}]}], S.WFields{S.Absent{} <> rest, o2}, S.ObjectSchema{S.Field{k, c, p} <> t, u}, x) == True{} : Bool}:
  %Equal.sym(Bool, String.eq(k, k), True{}, string_refl(k)) : {(((_ && (Bool.not(S.may_be_absent(p)) && True{})) || slots_fault([S.PathKey{k}], t, rest)) && True{}) == True{} : Bool}
  %Equal.sym(Bool, S.may_be_absent(p), False{}, hb) : {(((True{} && (Bool.not(_) && True{})) || slots_fault([S.PathKey{k}], t, rest)) && True{}) == True{} : Bool}
  {==}

def absent_sound(+k: String, +c: S.Schema, +p: S.Presence, +t: List<&2, S.Field>, +u: S.Unknown, +x: J.Json, +rest: List<&2, S.Slot>, +l: Nat, +o2: S.Out, b: Bool, hb: {S.may_be_absent(p) == b : Bool}) -> {S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.emit(b, S.Error{S.Constraint{}, "missing required key", [S.PathKey{k}]}, S.Out{[], 1n+l})}) == extend(S.collect_go(S.ObjectSchema{t, u}, x, blank(S.WFields{rest, S.emit(b, S.Error{S.Constraint{}, "missing required key", [S.PathKey{k}]}, S.Out{[], 1n+l})})), wrev(S.WFields{rest, S.emit(b, S.Error{S.Constraint{}, "missing required key", [S.PathKey{k}]}, S.Out{[], 1n+l})})) : S.Out} -> {all_sf(revs(S.collect_go(S.ObjectSchema{t, u}, x, blank(S.WFields{rest, S.emit(b, S.Error{S.Constraint{}, "missing required key", [S.PathKey{k}]}, S.Out{[], 1n+l})}))), S.WFields{rest, S.emit(b, S.Error{S.Constraint{}, "missing required key", [S.PathKey{k}]}, S.Out{[], 1n+l})}, S.ObjectSchema{t, u}, x) == True{} : Bool} -> {all_sf(revs(S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.emit(b, S.Error{S.Constraint{}, "missing required key", [S.PathKey{k}]}, S.Out{[], 1n+l})})), S.WFields{S.Absent{} <> rest, o2}, S.ObjectSchema{S.Field{k, c, p} <> t, u}, x) == True{} : Bool}:
  match b:
    case True{}: hfr => ih => widen_fields(revs(S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{[], 1n+l}})), k, c, p, t, u, x, S.Absent{}, rest, S.Out{[], 1n+l}, o2, ih)
    case False{}: hfr => ih =>
      key_sound(k, c, p, t, u, x, S.Absent{}, rest, l, o2, S.Error{S.Constraint{}, "missing required key", [S.PathKey{k}]}, hfr, ih, absent_one(k, c, p, t, u, x, rest, o2, hb))

def repeated_one(+k: String, +c: S.Schema, +p: S.Presence, +t: List<&2, S.Field>, +u: S.Unknown, +x: J.Json, +y: J.Json, +rest: List<&2, S.Slot>, +o2: S.Out) -> {all_sf([S.Error{S.Constraint{}, "duplicate key", [S.PathKey{k}]}], S.WFields{S.Repeated{y} <> rest, o2}, S.ObjectSchema{S.Field{k, c, p} <> t, u}, x) == True{} : Bool}:
  %Equal.sym(Bool, String.eq(k, k), True{}, string_refl(k)) : {(((_ && True{}) || slots_fault([S.PathKey{k}], t, rest)) && True{}) == True{} : Bool}
  {==}

def is_null(v: J.Json) -> Bool:
  match v:
    case J.JNull{}: True{}
    case _: False{}

def null_fault1(+i: S.Schema, +x: J.Json, +p: List<&2, S.PathPart>, nn: {is_null(x) == False{} : Bool}, h: {Spec.fault(i, x, p, Spec.Here{}) == True{} : Bool}) -> {Spec.fault(S.NullableSchema{i}, x, p, Spec.Here{}) == True{} : Bool}:
  match x:
    case J.JNull{}: UP.absurd({Spec.fault(S.NullableSchema{i}, J.JNull{}, p, Spec.Here{}) == True{} : Bool}, UP.false_true(Equal.sym(Bool, True{}, False{}, nn)))
    case J.JBool{b0}: h
    case J.JNumber{b0}: h
    case J.JString{b0}: h
    case J.JArray{Nil{}}: h
    case J.JArray{g <> r}:
      match p:
        case Nil{}: h
        case S.PathKey{a} <> q: h
        case S.PathIndex{a} <> q: h
    case J.JObject{b0}: h

def null_sound(+es: List<&2, S.Error>, +i: S.Schema, +x: J.Json, +l: Nat, +nn: {is_null(x) == False{} : Bool}, +hc: {all_here(es, i, x) == True{} : Bool}) -> {all_sf(es, S.WHere{l}, S.NullableSchema{i}, x) == True{} : Bool}:
  match es:
    case Nil{}: {==}
    case e <> t: and_both(Spec.fault(S.NullableSchema{i}, x, err_path(e), Spec.Here{}), all_sf(t, S.WHere{l}, S.NullableSchema{i}, x), null_fault1(i, x, err_path(e), nn, UP.and_left(Spec.fault(i, x, err_path(e), Spec.Here{}), all_here(t, i, x), hc)), null_sound(t, i, x, l, nn, UP.and_right(Spec.fault(i, x, err_path(e), Spec.Here{}), all_here(t, i, x), hc)))

def union_sound_b(+ms: List<&2, S.Schema>, +x: J.Json, +l: Nat, +b: Bool, hb: {b == Spec.meets(S.UnionSchema{ms}, Spec.Holds{}, x) : Bool}, hf: {Spec.fault(S.UnionSchema{ms}, x, [], Spec.Here{}) == Bool.not(Spec.meets(S.UnionSchema{ms}, Spec.Holds{}, x)) : Bool}) -> {all_sf(revs(S.emit(b, S.Error{S.Constraint{}, "value matches no union member", []}, S.Out{[], l})), S.WHere{l}, S.UnionSchema{ms}, x) == True{} : Bool}:
  match l b:
    case q True{}: {==}
    case 0n False{}: {==}
    case 1n+n False{}:
      %Equal.sym(Bool, Spec.fault(S.UnionSchema{ms}, x, [], Spec.Here{}), Bool.not(Spec.meets(S.UnionSchema{ms}, Spec.Holds{}, x)), hf) : {(_ && True{}) == True{} : Bool}
      %hb : {(Bool.not(_) && True{}) == True{} : Bool}
      {==}

# Completeness.

def lefts(o: S.Out) -> Nat:
  match o:
    case S.Out{r, l}: l

def found(+o: S.Out, +path: List<&2, S.PathPart>) -> Bool:
  Spec.names(revs(o), path) || Nat.is_eq(lefts(o), 0n)

def state_fault_c(w: S.Walk, s: S.Schema, v: J.Json, path: List<&2, S.PathPart>) -> Bool:
  match w s v:
    case S.WHere{l} s2 x: Spec.fault(s2, x, path, Spec.Here{})
    case S.WItems{k, o} S.ArraySchema{i, m, n} x: items_at(path, i, x, k)
    case S.WFields{ss, o} S.ObjectSchema{fs, u} x: slots_fault(path, fs, ss)
    case _ _ _: False{}

def or_elim(+a: Bool, -b: Bool, -G: Type, h: {(a || b) == True{} : Bool}, fa: {a == True{} : Bool} -> G, fb: {b == True{} : Bool} -> G) -> G:
  match a:
    case True{}: fa({==})
    case False{}: fb(h)

def nat_eq_sym(+a: Nat, +b: Nat) -> {Nat.is_eq(a, b) == Nat.is_eq(b, a) : Bool}:
  match a b:
    case 0n 0n: {==}
    case 0n 1n+y: {==}
    case 1n+x 0n: {==}
    case 1n+x 1n+y: nat_eq_sym(x, y)

def names_cat(+a: List<&2, S.Error>, +b: List<&2, S.Error>, +path: List<&2, S.PathPart>) -> {Spec.names(cat(a, b), path) == (Spec.names(a, path) || Spec.names(b, path)) : Bool}:
  match a:
    case Nil{}: {==}
    case S.Error{c0, m0, p0} <> t:
      %Equal.sym(Bool, Spec.names(cat(t, b), path), (Spec.names(t, path) || Spec.names(b, path)), names_cat(t, b, path)) : {(Spec.same_path(p0, path) || _) == ((Spec.same_path(p0, path) || Spec.names(t, path)) || Spec.names(b, path)) : Bool}
      Equal.sym(Bool, ((Spec.same_path(p0, path) || Spec.names(t, path)) || Spec.names(b, path)), (Spec.same_path(p0, path) || (Spec.names(t, path) || Spec.names(b, path))), SP.or_assoc(Spec.same_path(p0, path), Spec.names(t, path), Spec.names(b, path)))

def or3_left(+a: Bool, +b: Bool, -c: Bool, h: {(a || c) == True{} : Bool}) -> {((a || b) || c) == True{} : Bool}:
  match a:
    case True{}: {==}
    case False{}: or_right(False{} || b, c, h)

def found_left(+x: S.Out, +p: List<&2, S.Error>, +path: List<&2, S.PathPart>, h: {found(x, path) == True{} : Bool}) -> {found(extend(x, p), path) == True{} : Bool}:
  match x:
    case S.Out{r, l}:
      %Equal.sym(Bool, Spec.names(cat(r, p), path), (Spec.names(r, path) || Spec.names(p, path)), names_cat(r, p, path)) : {(_ || Nat.is_eq(l, 0n)) == True{} : Bool}
      or3_left(Spec.names(r, path), Spec.names(p, path), Nat.is_eq(l, 0n), h)

def found_right(+x: S.Out, +p: List<&2, S.Error>, +path: List<&2, S.PathPart>, h: {Spec.names(p, path) == True{} : Bool}) -> {found(extend(x, p), path) == True{} : Bool}:
  match x:
    case S.Out{r, l}:
      %Equal.sym(Bool, Spec.names(cat(r, p), path), (Spec.names(r, path) || Spec.names(p, path)), names_cat(r, p, path)) : {(_ || Nat.is_eq(l, 0n)) == True{} : Bool}
      or_left(Spec.names(r, path) || Spec.names(p, path), Nat.is_eq(l, 0n), or_right(Spec.names(r, path), Spec.names(p, path), h))

def arr_zero(+i: S.Schema, +m: Nat, +n: Maybe<&2, Nat>, +t: List<&2, J.Json>, +k: Nat) -> {S.collect_go(S.ArraySchema{i, m, n}, J.JArray{t}, S.WItems{k, S.Out{[], 0n}}) == S.Out{[], 0n} : S.Out}:
  match t:
    case Nil{}: {==}
    case g <> r: {==}

def obj_zero(+t: List<&2, S.Field>, +u: S.Unknown, +x: J.Json, +rest: List<&2, S.Slot>) -> {S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{[], 0n}}) == S.Out{[], 0n} : S.Out}:
  match t rest:
    case Nil{} ss: {==}
    case S.Field{a, b, c} <> f Nil{}: {==}
    case S.Field{a, b, c} <> f S.Once{y} <> r: {==}
    case S.Field{a, b, c} <> f S.Absent{} <> r: {==}
    case S.Field{a, b, c} <> f S.Repeated{y} <> r: {==}

def arr_zero_found(+i: S.Schema, +m: Nat, +n: Maybe<&2, Nat>, +t: List<&2, J.Json>, +k: Nat, +cl: Nat, +p: List<&2, S.Error>, +path: List<&2, S.PathPart>, hz: {Nat.is_eq(cl, 0n) == True{} : Bool}) -> {found(extend(S.collect_go(S.ArraySchema{i, m, n}, J.JArray{t}, S.WItems{k, S.Out{[], cl}}), p), path) == True{} : Bool}:
  match cl:
    case 0n:
      %Equal.sym(S.Out, S.collect_go(S.ArraySchema{i, m, n}, J.JArray{t}, S.WItems{k, S.Out{[], 0n}}), S.Out{[], 0n}, arr_zero(i, m, n, t, k)) : {found(extend(_, p), path) == True{} : Bool}
      or_right(Spec.names(p, path), True{}, {==})
    case 1n+j: UP.absurd({found(extend(S.collect_go(S.ArraySchema{i, m, n}, J.JArray{t}, S.WItems{k, S.Out{[], 1n+j}}), p), path) == True{} : Bool}, UP.false_true(hz))

def obj_zero_found(+t: List<&2, S.Field>, +u: S.Unknown, +x: J.Json, +rest: List<&2, S.Slot>, +cl: Nat, +p: List<&2, S.Error>, +path: List<&2, S.PathPart>, hz: {Nat.is_eq(cl, 0n) == True{} : Bool}) -> {found(extend(S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{[], cl}}), p), path) == True{} : Bool}:
  match cl:
    case 0n:
      %Equal.sym(S.Out, S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{[], 0n}}), S.Out{[], 0n}, obj_zero(t, u, x, rest)) : {found(extend(_, p), path) == True{} : Bool}
      or_right(Spec.names(p, path), True{}, {==})
    case 1n+j: UP.absurd({found(extend(S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{[], 1n+j}}), p), path) == True{} : Bool}, UP.false_true(hz))

def or_cases(+a: Bool, -b: Bool, +x: Bool, -y: Bool, h: {(a || b) == True{} : Bool}, fa: {a == True{} : Bool} -> {x == True{} : Bool}, fb: {b == True{} : Bool} -> {y == True{} : Bool}) -> {(x || y) == True{} : Bool}:
  match a:
    case True{}: or_left(x, y, fa({==}))
    case False{}: or_right(x, y, fb(h))

def prefix_index_names(+k: Nat, +n: Nat, +es: List<&2, S.Error>, +q: List<&2, S.PathPart>, +hk: {Nat.is_eq(k, n) == True{} : Bool}, h: {Spec.names(es, q) == True{} : Bool}) -> {Spec.names(S.prefix_onto(S.PathIndex{k}, es, []), S.PathIndex{n} <> q) == True{} : Bool}:
  match es:
    case Nil{}: UP.absurd({False{} == True{} : Bool}, UP.false_true(h))
    case S.Error{c0, m0, p0} <> t: or_cases(Spec.same_path(p0, q), Spec.names(t, q), Nat.is_eq(k, n) && Spec.same_path(p0, q), Spec.names(S.prefix_onto(S.PathIndex{k}, t, []), S.PathIndex{n} <> q), h, hs => and_both(Nat.is_eq(k, n), Spec.same_path(p0, q), hk, hs), hn => prefix_index_names(k, n, t, q, hk, hn))

def prefix_key_names(+k: String, +k2: String, +es: List<&2, S.Error>, +q: List<&2, S.PathPart>, +hk: {String.eq(k, k2) == True{} : Bool}, h: {Spec.names(es, q) == True{} : Bool}) -> {Spec.names(S.prefix_onto(S.PathKey{k}, es, []), S.PathKey{k2} <> q) == True{} : Bool}:
  match es:
    case Nil{}: UP.absurd({False{} == True{} : Bool}, UP.false_true(h))
    case S.Error{c0, m0, p0} <> t: or_cases(Spec.same_path(p0, q), Spec.names(t, q), String.eq(k, k2) && Spec.same_path(p0, q), Spec.names(S.prefix_onto(S.PathKey{k}, t, []), S.PathKey{k2} <> q), h, hs => and_both(String.eq(k, k2), Spec.same_path(p0, q), hk, hs), hn => prefix_key_names(k, k2, t, q, hk, hn))

def names_key1(+c0: S.Code, +m0: String, +k: String, +k2: String, +q: List<&2, S.PathPart>, he: {String.eq(k, k2) == True{} : Bool}, hq: {Spec.ends(q) == True{} : Bool}) -> {Spec.names([S.Error{c0, m0, [S.PathKey{k}]}], S.PathKey{k2} <> q) == True{} : Bool}:
  match q:
    case Nil{}:
      %Equal.sym(Bool, String.eq(k, k2), True{}, he) : {((_ && True{}) || False{}) == True{} : Bool}
      {==}
    case g <> r: UP.absurd({Spec.names([S.Error{c0, m0, [S.PathKey{k}]}], S.PathKey{k2} <> g <> r) == True{} : Bool}, UP.false_true(hq))

def from_nil(+i: S.Schema, +n: Nat, +q: List<&2, S.PathPart>, +k: Nat) -> {Spec.fault(i, J.JArray{[]}, S.PathIndex{n} <> q, Spec.From{k}) == False{} : Bool}:
  match i:
    case S.StringSchema{a1, a2, a3, a4}: {==}
    case S.NumberSchema{a1, a2}: {==}
    case S.IntegerSchema{a1, a2}: {==}
    case S.BooleanSchema{}: {==}
    case S.LiteralSchema{a1}: {==}
    case S.EnumSchema{a1}: {==}
    case S.ArraySchema{a1, a2, a3}: {==}
    case S.ObjectSchema{Nil{}, a2}: {==}
    case S.ObjectSchema{S.Field{a1, a3, a4} <> a5, a2}: {==}
    case S.NullableSchema{a1}: {==}
    case S.UnionSchema{a1}: {==}

def arr_tail(+i: S.Schema, +m: Nat, +n: Maybe<&2, Nat>, +k: Nat, +n2: Nat, +q: List<&2, S.PathPart>, +cl: Nat, +p: List<&2, S.Error>, t: List<&2, J.Json>) -> ({state_fault_c(S.WItems{1n+k, S.Out{p, cl}}, S.ArraySchema{i, m, n}, J.JArray{t}, S.PathIndex{n2} <> q) == True{} : Bool} -> {found(S.collect_go(S.ArraySchema{i, m, n}, J.JArray{t}, S.WItems{1n+k, S.Out{[], cl}}), S.PathIndex{n2} <> q) == True{} : Bool}) -> {Spec.fault(i, J.JArray{t}, S.PathIndex{n2} <> q, Spec.From{1n+k}) == True{} : Bool} -> {found(extend(S.collect_go(S.ArraySchema{i, m, n}, J.JArray{t}, S.WItems{1n+k, S.Out{[], cl}}), p), S.PathIndex{n2} <> q) == True{} : Bool}:
  match t:
    case Nil{}: ih => hb => UP.absurd({found(extend(S.collect_go(S.ArraySchema{i, m, n}, J.JArray{[]}, S.WItems{1n+k, S.Out{[], cl}}), p), S.PathIndex{n2} <> q) == True{} : Bool}, UP.false_true(Equal.trans(Bool, False{}, Spec.fault(i, J.JArray{[]}, S.PathIndex{n2} <> q, Spec.From{1n+k}), True{}, Equal.sym(Bool, Spec.fault(i, J.JArray{[]}, S.PathIndex{n2} <> q, Spec.From{1n+k}), False{}, from_nil(i, n2, q, 1n+k)), hb)))
    case +g <> +r: ih => hb => found_left(S.collect_go(S.ArraySchema{i, m, n}, J.JArray{g <> r}, S.WItems{1n+k, S.Out{[], cl}}), p, S.PathIndex{n2} <> q, ih(hb))

def arr_complete(+i: S.Schema, +m: Nat, +n: Maybe<&2, Nat>, +h: J.Json, +k: Nat, +n2: Nat, +q: List<&2, S.PathPart>, cc: S.Out, +t: List<&2, J.Json>) -> {S.collect_go(S.ArraySchema{i, m, n}, J.JArray{t}, S.WItems{1n+k, S.merge(S.PathIndex{k}, cc, [])}) == extend(S.collect_go(S.ArraySchema{i, m, n}, J.JArray{t}, blank(S.WItems{1n+k, S.merge(S.PathIndex{k}, cc, [])})), wrev(S.WItems{1n+k, S.merge(S.PathIndex{k}, cc, [])})) : S.Out} -> ({state_fault_c(S.WItems{1n+k, S.merge(S.PathIndex{k}, cc, [])}, S.ArraySchema{i, m, n}, J.JArray{t}, S.PathIndex{n2} <> q) == True{} : Bool} -> {found(S.collect_go(S.ArraySchema{i, m, n}, J.JArray{t}, blank(S.WItems{1n+k, S.merge(S.PathIndex{k}, cc, [])})), S.PathIndex{n2} <> q) == True{} : Bool}) -> ({Spec.fault(i, h, q, Spec.Here{}) == True{} : Bool} -> {found(cc, q) == True{} : Bool}) -> {Spec.fault(i, J.JArray{h <> t}, S.PathIndex{n2} <> q, Spec.From{k}) == True{} : Bool} -> {found(S.collect_go(S.ArraySchema{i, m, n}, J.JArray{t}, S.WItems{1n+k, S.merge(S.PathIndex{k}, cc, [])}), S.PathIndex{n2} <> q) == True{} : Bool}:
  match cc:
    case S.Out{+es, +cl}: hfr => ih_t => ih_c => hf =>
      %Equal.sym(S.Out, S.collect_go(S.ArraySchema{i, m, n}, J.JArray{t}, S.WItems{1n+k, S.Out{S.prefix_onto(S.PathIndex{k}, es, []), cl}}), extend(S.collect_go(S.ArraySchema{i, m, n}, J.JArray{t}, S.WItems{1n+k, S.Out{[], cl}}), S.prefix_onto(S.PathIndex{k}, es, [])), hfr) : {found(_, S.PathIndex{n2} <> q) == True{} : Bool}
      or_elim(Nat.is_eq(n2, k) && Spec.fault(i, h, q, Spec.Here{}), Spec.fault(i, J.JArray{t}, S.PathIndex{n2} <> q, Spec.From{1n+k}), {found(extend(S.collect_go(S.ArraySchema{i, m, n}, J.JArray{t}, S.WItems{1n+k, S.Out{[], cl}}), S.prefix_onto(S.PathIndex{k}, es, [])), S.PathIndex{n2} <> q) == True{} : Bool}, Equal.trans(Bool, ((Nat.is_eq(n2, k) && Spec.fault(i, h, q, Spec.Here{})) || Spec.fault(i, J.JArray{t}, S.PathIndex{n2} <> q, Spec.From{1n+k})), Spec.fault(i, J.JArray{h <> t}, S.PathIndex{n2} <> q, Spec.From{k}), True{}, Equal.sym(Bool, Spec.fault(i, J.JArray{h <> t}, S.PathIndex{n2} <> q, Spec.From{k}), ((Nat.is_eq(n2, k) && Spec.fault(i, h, q, Spec.Here{})) || Spec.fault(i, J.JArray{t}, S.PathIndex{n2} <> q, Spec.From{1n+k})), from_cons(i, h, t, n2, q, k)), hf), +ha => or_elim(Spec.names(es, q), Nat.is_eq(cl, 0n), {found(extend(S.collect_go(S.ArraySchema{i, m, n}, J.JArray{t}, S.WItems{1n+k, S.Out{[], cl}}), S.prefix_onto(S.PathIndex{k}, es, [])), S.PathIndex{n2} <> q) == True{} : Bool}, ih_c(UP.and_right(Nat.is_eq(n2, k), Spec.fault(i, h, q, Spec.Here{}), ha)), hn => found_right(S.collect_go(S.ArraySchema{i, m, n}, J.JArray{t}, S.WItems{1n+k, S.Out{[], cl}}), S.prefix_onto(S.PathIndex{k}, es, []), S.PathIndex{n2} <> q, prefix_index_names(k, n2, es, q, Equal.trans(Bool, Nat.is_eq(k, n2), Nat.is_eq(n2, k), True{}, nat_eq_sym(k, n2), UP.and_left(Nat.is_eq(n2, k), Spec.fault(i, h, q, Spec.Here{}), ha)), hn)), hz => arr_zero_found(i, m, n, t, 1n+k, cl, S.prefix_onto(S.PathIndex{k}, es, []), S.PathIndex{n2} <> q, hz)), hb => arr_tail(i, m, n, k, n2, q, cl, S.prefix_onto(S.PathIndex{k}, es, []), t)(ih_t)(hb))

def obj_complete(+k: String, +c: S.Schema, +p: S.Presence, +t: List<&2, S.Field>, +u: S.Unknown, +x: J.Json, +y: J.Json, +rest: List<&2, S.Slot>, +k2: String, +q: List<&2, S.PathPart>, cc: S.Out) -> {S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.merge(S.PathKey{k}, cc, [])}) == extend(S.collect_go(S.ObjectSchema{t, u}, x, blank(S.WFields{rest, S.merge(S.PathKey{k}, cc, [])})), wrev(S.WFields{rest, S.merge(S.PathKey{k}, cc, [])})) : S.Out} -> ({state_fault_c(S.WFields{rest, S.merge(S.PathKey{k}, cc, [])}, S.ObjectSchema{t, u}, x, S.PathKey{k2} <> q) == True{} : Bool} -> {found(S.collect_go(S.ObjectSchema{t, u}, x, blank(S.WFields{rest, S.merge(S.PathKey{k}, cc, [])})), S.PathKey{k2} <> q) == True{} : Bool}) -> ({Spec.fault(c, y, q, Spec.Here{}) == True{} : Bool} -> {found(cc, q) == True{} : Bool}) -> {slots_fault(S.PathKey{k2} <> q, S.Field{k, c, p} <> t, S.Once{y} <> rest) == True{} : Bool} -> {found(S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.merge(S.PathKey{k}, cc, [])}), S.PathKey{k2} <> q) == True{} : Bool}:
  match cc:
    case S.Out{+es, +cl}: hfr => ih_t => ih_c => hf =>
      %Equal.sym(S.Out, S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{S.prefix_onto(S.PathKey{k}, es, []), cl}}), extend(S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{[], cl}}), S.prefix_onto(S.PathKey{k}, es, [])), hfr) : {found(_, S.PathKey{k2} <> q) == True{} : Bool}
      or_elim(String.eq(k, k2) && Spec.fault(c, y, q, Spec.Here{}), slots_fault(S.PathKey{k2} <> q, t, rest), {found(extend(S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{[], cl}}), S.prefix_onto(S.PathKey{k}, es, [])), S.PathKey{k2} <> q) == True{} : Bool}, hf, +ha => or_elim(Spec.names(es, q), Nat.is_eq(cl, 0n), {found(extend(S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{[], cl}}), S.prefix_onto(S.PathKey{k}, es, [])), S.PathKey{k2} <> q) == True{} : Bool}, ih_c(UP.and_right(String.eq(k, k2), Spec.fault(c, y, q, Spec.Here{}), ha)), hn => found_right(S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{[], cl}}), S.prefix_onto(S.PathKey{k}, es, []), S.PathKey{k2} <> q, prefix_key_names(k, k2, es, q, UP.and_left(String.eq(k, k2), Spec.fault(c, y, q, Spec.Here{}), ha), hn)), hz => obj_zero_found(t, u, x, rest, cl, S.prefix_onto(S.PathKey{k}, es, []), S.PathKey{k2} <> q, hz)), hb => found_left(S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{[], cl}}), S.prefix_onto(S.PathKey{k}, es, []), S.PathKey{k2} <> q, ih_t(hb)))

# One error at a declared key, then the rest of the walk.
def key_complete(+t: List<&2, S.Field>, +u: S.Unknown, +x: J.Json, +rest: List<&2, S.Slot>, +l: Nat, +e: S.Error, +path: List<&2, S.PathPart>, +a: Bool, -b: Bool, hfr: {S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{[e], l}}) == extend(S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{[], l}}), [e]) : S.Out}, ih_t: {b == True{} : Bool} -> {found(S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{[], l}}), path) == True{} : Bool}, he: {a == True{} : Bool} -> {Spec.names([e], path) == True{} : Bool}, hf: {(a || b) == True{} : Bool}) -> {found(S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{[e], l}}), path) == True{} : Bool}:
  %Equal.sym(S.Out, S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{[e], l}}), extend(S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{[], l}}), [e]), hfr) : {found(_, path) == True{} : Bool}
  or_elim(a, b, {found(extend(S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{[], l}}), [e]), path) == True{} : Bool}, hf, ha => found_right(S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{[], l}}), [e], path, he(ha)), hb => found_left(S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{[], l}}), [e], path, ih_t(hb)))

def absent_complete(+k: String, +c: S.Schema, +p: S.Presence, +t: List<&2, S.Field>, +u: S.Unknown, +x: J.Json, +rest: List<&2, S.Slot>, +l: Nat, +k2: String, +q: List<&2, S.PathPart>, b: Bool, hb: {S.may_be_absent(p) == b : Bool}) -> {S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.emit(b, S.Error{S.Constraint{}, "missing required key", [S.PathKey{k}]}, S.Out{[], 1n+l})}) == extend(S.collect_go(S.ObjectSchema{t, u}, x, blank(S.WFields{rest, S.emit(b, S.Error{S.Constraint{}, "missing required key", [S.PathKey{k}]}, S.Out{[], 1n+l})})), wrev(S.WFields{rest, S.emit(b, S.Error{S.Constraint{}, "missing required key", [S.PathKey{k}]}, S.Out{[], 1n+l})})) : S.Out} -> ({state_fault_c(S.WFields{rest, S.emit(b, S.Error{S.Constraint{}, "missing required key", [S.PathKey{k}]}, S.Out{[], 1n+l})}, S.ObjectSchema{t, u}, x, S.PathKey{k2} <> q) == True{} : Bool} -> {found(S.collect_go(S.ObjectSchema{t, u}, x, blank(S.WFields{rest, S.emit(b, S.Error{S.Constraint{}, "missing required key", [S.PathKey{k}]}, S.Out{[], 1n+l})})), S.PathKey{k2} <> q) == True{} : Bool}) -> {((String.eq(k, k2) && (Bool.not(S.may_be_absent(p)) && Spec.ends(q))) || slots_fault(S.PathKey{k2} <> q, t, rest)) == True{} : Bool} -> {found(S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.emit(b, S.Error{S.Constraint{}, "missing required key", [S.PathKey{k}]}, S.Out{[], 1n+l})}), S.PathKey{k2} <> q) == True{} : Bool}:
  match b:
    case True{}: hfr => ih_t => hf => or_elim(String.eq(k, k2) && (Bool.not(S.may_be_absent(p)) && Spec.ends(q)), slots_fault(S.PathKey{k2} <> q, t, rest), {found(S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{[], 1n+l}}), S.PathKey{k2} <> q) == True{} : Bool}, hf, ha => UP.absurd({found(S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{[], 1n+l}}), S.PathKey{k2} <> q) == True{} : Bool}, UP.false_true(Equal.trans(Bool, False{}, Bool.not(S.may_be_absent(p)), True{}, Equal.cong(Bool, Bool, z => Bool.not(z), True{}, S.may_be_absent(p), Equal.sym(Bool, S.may_be_absent(p), True{}, hb)), UP.and_left(Bool.not(S.may_be_absent(p)), Spec.ends(q), UP.and_right(String.eq(k, k2), Bool.not(S.may_be_absent(p)) && Spec.ends(q), ha))))), hb2 => ih_t(hb2))
    case False{}: hfr => ih_t => hf => key_complete(t, u, x, rest, l, S.Error{S.Constraint{}, "missing required key", [S.PathKey{k}]}, S.PathKey{k2} <> q, String.eq(k, k2) && (Bool.not(S.may_be_absent(p)) && Spec.ends(q)), slots_fault(S.PathKey{k2} <> q, t, rest), hfr, ih_t, +ha => names_key1(S.Constraint{}, "missing required key", k, k2, q, UP.and_left(String.eq(k, k2), Bool.not(S.may_be_absent(p)) && Spec.ends(q), ha), UP.and_right(Bool.not(S.may_be_absent(p)), Spec.ends(q), UP.and_right(String.eq(k, k2), Bool.not(S.may_be_absent(p)) && Spec.ends(q), ha))), hf)

def null_fault_rev(+i: S.Schema, +x: J.Json, +p: List<&2, S.PathPart>, nn: {is_null(x) == False{} : Bool}, h: {Spec.fault(S.NullableSchema{i}, x, p, Spec.Here{}) == True{} : Bool}) -> {Spec.fault(i, x, p, Spec.Here{}) == True{} : Bool}:
  match x:
    case J.JNull{}: UP.absurd({Spec.fault(i, J.JNull{}, p, Spec.Here{}) == True{} : Bool}, UP.false_true(Equal.sym(Bool, True{}, False{}, nn)))
    case J.JBool{b0}: h
    case J.JNumber{b0}: h
    case J.JString{b0}: h
    case J.JArray{Nil{}}: h
    case J.JArray{g <> r}:
      match p:
        case Nil{}: h
        case S.PathKey{a} <> q: h
        case S.PathIndex{a} <> q: h
    case J.JObject{b0}: h

def union_complete(+ms: List<&2, S.Schema>, +x: J.Json, +l: Nat, +b: Bool, hb: {b == Spec.meets(S.UnionSchema{ms}, Spec.Holds{}, x) : Bool}, hn: {Spec.fault(S.UnionSchema{ms}, x, [], Spec.Here{}) == Bool.not(Spec.meets(S.UnionSchema{ms}, Spec.Holds{}, x)) : Bool}, hf: {Spec.fault(S.UnionSchema{ms}, x, [], Spec.Here{}) == True{} : Bool}) -> {found(S.emit(b, S.Error{S.Constraint{}, "value matches no union member", []}, S.Out{[], l}), []) == True{} : Bool}:
  match l b:
    case q True{}: UP.absurd({found(S.emit(True{}, S.Error{S.Constraint{}, "value matches no union member", []}, S.Out{[], q}), []) == True{} : Bool}, UP.false_true(Equal.trans(Bool, False{}, Bool.not(Spec.meets(S.UnionSchema{ms}, Spec.Holds{}, x)), True{}, Equal.cong(Bool, Bool, z => Bool.not(z), True{}, Spec.meets(S.UnionSchema{ms}, Spec.Holds{}, x), hb), Equal.trans(Bool, Bool.not(Spec.meets(S.UnionSchema{ms}, Spec.Holds{}, x)), Spec.fault(S.UnionSchema{ms}, x, [], Spec.Here{}), True{}, Equal.sym(Bool, Spec.fault(S.UnionSchema{ms}, x, [], Spec.Here{}), Bool.not(Spec.meets(S.UnionSchema{ms}, Spec.Holds{}, x)), hn), hf))))
    case 0n False{}: {==}
    case 1n+n False{}: {==}

def kind_complete(+l: Nat) -> {found(S.kind_out(l), []) == True{} : Bool}:
  match l:
    case 0n: {==}
    case 1n+n: {==}

def emit_all_zero(+es: List<&2, S.Error>, +r: List<&2, S.Error>) -> {lefts(S.emit_all(es, S.Out{r, 0n})) == 0n : Nat}:
  match es:
    case Nil{}: {==}
    case e <> t: emit_all_zero(t, r)

def emit_all_keeps(+es: List<&2, S.Error>, +o: S.Out, +path: List<&2, S.PathPart>, h: {Spec.names(revs(o), path) == True{} : Bool}) -> {Spec.names(revs(S.emit_all(es, o)), path) == True{} : Bool}:
  match es o:
    case Nil{} q: h
    case e <> t S.Out{r, 0n}: emit_all_keeps(t, S.Out{r, 0n}, path, h)
    case S.Error{c0, m0, p0} <> t S.Out{r, 1n+n}: emit_all_keeps(t, S.Out{S.Error{c0, m0, p0} <> r, n}, path, or_right(Spec.same_path(p0, path), Spec.names(r, path), h))

def root_names(+e: S.Error, hr: {root(e) == True{} : Bool}) -> {Spec.names([e], []) == True{} : Bool}:
  match e:
    case S.Error{c0, m0, Nil{}}: {==}
    case S.Error{c0, m0, g <> r}: UP.absurd({Spec.names([S.Error{c0, m0, g <> r}], []) == True{} : Bool}, UP.false_true(hr))

def scalar_complete_r(+r: Result<&2, &2, S.Errors(), S.Value>, +s: S.Schema, +x: J.Json, +l: Nat, hb: {bare(r) == True{} : Bool}, ha: {S.accepted(r) == Spec.accepts(s, x) : Bool}, hn: {Spec.fault(s, x, [], Spec.Here{}) == Bool.not(Spec.accepts(s, x)) : Bool}, hf: {Spec.fault(s, x, [], Spec.Here{}) == True{} : Bool}) -> {found(S.scalar_out(r, l), []) == True{} : Bool}:
  match r:
    case Done{y}: UP.absurd({found(S.scalar_out(Done{y}, l), []) == True{} : Bool}, UP.false_true(Equal.trans(Bool, False{}, Bool.not(Spec.accepts(s, x)), True{}, Equal.cong(Bool, Bool, z => Bool.not(z), True{}, Spec.accepts(s, x), ha), Equal.trans(Bool, Bool.not(Spec.accepts(s, x)), Spec.fault(s, x, [], Spec.Here{}), True{}, Equal.sym(Bool, Spec.fault(s, x, [], Spec.Here{}), Bool.not(Spec.accepts(s, x)), hn), hf))))
    case Fail{Nil{}}: UP.absurd({found(S.scalar_out(Fail{[]}, l), []) == True{} : Bool}, UP.false_true(hb))
    case Fail{+e <> +t}:
      match l:
        case 0n:
          %Equal.sym(Nat, lefts(S.emit_all(t, S.Out{[], 0n})), 0n, emit_all_zero(t, [])) : {(Spec.names(revs(S.emit_all(t, S.Out{[], 0n})), []) || Nat.is_eq(_, 0n)) == True{} : Bool}
          or_right(Spec.names(revs(S.emit_all(t, S.Out{[], 0n})), []), True{}, {==})
        case 1n+n: or_left(Spec.names(revs(S.emit_all(t, S.Out{[e], n})), []), Nat.is_eq(lefts(S.emit_all(t, S.Out{[e], n})), 0n), emit_all_keeps(t, S.Out{[e], n}, [], root_names(e, UP.and_left(root(e), roots(t), UP.and_right(Bool.not(False{}), root(e) && roots(t), hb)))))

def scalar_complete(+s: S.Schema, +x: J.Json, +l: Nat, +okv: {S.valid(s) == True{} : Bool}, hn: {Spec.fault(s, x, [], Spec.Here{}) == Bool.not(Spec.accepts(s, x)) : Bool}, hf: {Spec.fault(s, x, [], Spec.Here{}) == True{} : Bool}) -> {found(S.scalar_out(S.decode_scalar(s, x), l), []) == True{} : Bool}:
  scalar_complete_r(S.decode_scalar(s, x), s, x, l, bare_scalar(s, x), SP.accepts_equiv(s, x, okv), hn, hf)

def not_not(+a: Bool) -> {a == Bool.not(Bool.not(a)) : Bool}:
  match a:
    case True{}: {==}
    case False{}: {==}

def arr_here_items(+path: List<&2, S.PathPart>, +i: S.Schema, +m: Nat, +n: Maybe<&2, Nat>, +xs: List<&2, J.Json>, hok: {(Nat.is_le(m, Spec.size(xs)) && Spec.at_most(n, Spec.size(xs))) == True{} : Bool}, hf: {Spec.fault(S.ArraySchema{i, m, n}, J.JArray{xs}, path, Spec.Here{}) == True{} : Bool}) -> {items_at(path, i, J.JArray{xs}, 0n) == True{} : Bool}:
  match path xs:
    case Nil{} Nil{}: UP.absurd({False{} == True{} : Bool}, UP.false_true(Equal.trans(Bool, False{}, Bool.not(Nat.is_le(m, Spec.size([])) && Spec.at_most(n, Spec.size([]))), True{}, Equal.cong(Bool, Bool, z => Bool.not(z), True{}, Nat.is_le(m, Spec.size([])) && Spec.at_most(n, Spec.size([])), Equal.sym(Bool, Nat.is_le(m, Spec.size([])) && Spec.at_most(n, Spec.size([])), True{}, hok)), hf)))
    case Nil{} +g <> +r: UP.absurd({False{} == True{} : Bool}, UP.false_true(Equal.trans(Bool, False{}, Bool.not(Nat.is_le(m, Spec.size(g <> r)) && Spec.at_most(n, Spec.size(g <> r))), True{}, Equal.cong(Bool, Bool, z => Bool.not(z), True{}, Nat.is_le(m, Spec.size(g <> r)) && Spec.at_most(n, Spec.size(g <> r)), Equal.sym(Bool, Nat.is_le(m, Spec.size(g <> r)) && Spec.at_most(n, Spec.size(g <> r)), True{}, hok)), hf)))
    case S.PathKey{a} <> q Nil{}: UP.absurd({False{} == True{} : Bool}, UP.false_true(hf))
    case S.PathKey{a} <> q g <> r: UP.absurd({False{} == True{} : Bool}, UP.false_true(hf))
    case S.PathIndex{+j} <> +q Nil{}: UP.absurd({False{} == True{} : Bool}, UP.false_true(Equal.trans(Bool, False{}, Spec.fault(i, J.JArray{[]}, S.PathIndex{j} <> q, Spec.From{0n}), True{}, Equal.sym(Bool, Spec.fault(i, J.JArray{[]}, S.PathIndex{j} <> q, Spec.From{0n}), False{}, from_nil(i, j, q, 0n)), UP.and_right(Nat.is_le(m, Spec.size([])) && Spec.at_most(n, Spec.size([])), Spec.fault(i, J.JArray{[]}, S.PathIndex{j} <> q, Spec.From{0n}), hf))))
    case S.PathIndex{+j} <> +q +g <> +r: UP.and_right(Nat.is_le(m, Spec.size(g <> r)) && Spec.at_most(n, Spec.size(g <> r)), Spec.fault(i, J.JArray{g <> r}, S.PathIndex{j} <> q, Spec.From{0n}), hf)

def gate_found(+i: S.Schema, +m: Nat, +n: Maybe<&2, Nat>, +xs: List<&2, J.Json>, +l: Nat, +path: List<&2, S.PathPart>, hb: {False{} == (Nat.is_le(m, Spec.size(xs)) && Spec.at_most(n, Spec.size(xs))) : Bool}, hf: {Spec.fault(S.ArraySchema{i, m, n}, J.JArray{xs}, path, Spec.Here{}) == True{} : Bool}) -> {found(S.collect_go(S.ArraySchema{i, m, n}, J.JArray{xs}, S.WDone{S.emit(False{}, S.Error{S.Constraint{}, "array length out of bounds", []}, S.Out{[], l})}), path) == True{} : Bool}:
  match xs l path:
    case Nil{} 0n p: or_right(Spec.names([], p), True{}, {==})
    case Nil{} 1n+k Nil{}: {==}
    case Nil{} 1n+k S.PathKey{a} <> q: UP.absurd({found(S.Out{[S.Error{S.Constraint{}, "array length out of bounds", []}], k}, S.PathKey{a} <> q) == True{} : Bool}, UP.false_true(hf))
    case Nil{} 1n+k S.PathIndex{+a} <> +q: UP.absurd({found(S.Out{[S.Error{S.Constraint{}, "array length out of bounds", []}], k}, S.PathIndex{a} <> q) == True{} : Bool}, UP.false_true(Equal.trans(Bool, False{}, Nat.is_le(m, Spec.size([])) && Spec.at_most(n, Spec.size([])), True{}, hb, UP.and_left(Nat.is_le(m, Spec.size([])) && Spec.at_most(n, Spec.size([])), Spec.fault(i, J.JArray{[]}, S.PathIndex{a} <> q, Spec.From{0n}), hf))))
    case g <> r 0n p: or_right(Spec.names([], p), True{}, {==})
    case g <> r 1n+k Nil{}: {==}
    case g <> r 1n+k S.PathKey{a} <> q: UP.absurd({found(S.Out{[S.Error{S.Constraint{}, "array length out of bounds", []}], k}, S.PathKey{a} <> q) == True{} : Bool}, UP.false_true(hf))
    case +g <> +r 1n+k S.PathIndex{+a} <> +q: UP.absurd({found(S.Out{[S.Error{S.Constraint{}, "array length out of bounds", []}], k}, S.PathIndex{a} <> q) == True{} : Bool}, UP.false_true(Equal.trans(Bool, False{}, Nat.is_le(m, Spec.size(g <> r)) && Spec.at_most(n, Spec.size(g <> r)), True{}, hb, UP.and_left(Nat.is_le(m, Spec.size(g <> r)) && Spec.at_most(n, Spec.size(g <> r)), Spec.fault(i, J.JArray{g <> r}, S.PathIndex{a} <> q, Spec.From{0n}), hf))))

def arr_entry_k(+i: S.Schema, +m: Nat, +n: Maybe<&2, Nat>, +xs: List<&2, J.Json>, +l: Nat, +path: List<&2, S.PathPart>, b: Bool, hb: {b == (Nat.is_le(m, Spec.size(xs)) && Spec.at_most(n, Spec.size(xs))) : Bool}, hf: {Spec.fault(S.ArraySchema{i, m, n}, J.JArray{xs}, path, Spec.Here{}) == True{} : Bool}, ih: {state_fault_c(S.items_walk(b, l), S.ArraySchema{i, m, n}, J.JArray{xs}, path) == True{} : Bool} -> {found(S.collect_go(S.ArraySchema{i, m, n}, J.JArray{xs}, blank(S.items_walk(b, l))), path) == True{} : Bool}) -> {found(S.collect_go(S.ArraySchema{i, m, n}, J.JArray{xs}, S.items_walk(b, l)), path) == True{} : Bool}:
  match b:
    case True{}: ih(arr_here_items(path, i, m, n, xs, Equal.sym(Bool, True{}, (Nat.is_le(m, Spec.size(xs)) && Spec.at_most(n, Spec.size(xs))), hb), hf))
    case False{}: gate_found(i, m, n, xs, l, path, hb, hf)

def emit_keeps(+b: Bool, +e: S.Error, +r: List<&2, S.Error>, +n: Nat, +path: List<&2, S.PathPart>, h: {Spec.names(r, path) == True{} : Bool}) -> {Spec.names(revs(S.emit(b, e, S.Out{r, 1n+n})), path) == True{} : Bool}:
  match b e:
    case True{} f: h
    case False{} S.Error{c0, m0, p0}: or_right(Spec.same_path(p0, path), Spec.names(r, path), h)

def strays_keeps(+input: List<&2, J.Field>, +fs: List<&2, S.Field>, +o: S.Out, +path: List<&2, S.PathPart>, h: {Spec.names(revs(o), path) == True{} : Bool}) -> {found(S.strays(input, fs, o), path) == True{} : Bool}:
  match input o:
    case Nil{} S.Out{r, 0n}: or_left(Spec.names(r, path), True{}, h)
    case Nil{} S.Out{r, 1n+n}: or_left(Spec.names(r, path), Nat.is_eq(1n+n, 0n), h)
    case J.Field{k, v} <> t S.Out{r, 0n}: or_left(Spec.names(r, path), True{}, h)
    case J.Field{+k, v} <> +t S.Out{+r, 1n+(+n)}: strays_keeps(t, fs, S.emit(S.declared(fs, k), S.Error{S.Constraint{}, "object has an undeclared key", [S.PathKey{k}]}, S.Out{r, 1n+n}), path, emit_keeps(S.declared(fs, k), S.Error{S.Constraint{}, "object has an undeclared key", [S.PathKey{k}]}, r, n, path, h))

def strays_hit(+key: String, +y: J.Json, +t: List<&2, J.Field>, +fs: List<&2, S.Field>, +k: String, +r: List<&2, S.Error>, +n: Nat, hnd: {Spec.declares(fs, k) == False{} : Bool}, +he: {String.eq(key, k) == True{} : Bool}) -> {found(S.strays(t, fs, S.emit(S.declared(fs, key), S.Error{S.Constraint{}, "object has an undeclared key", [S.PathKey{key}]}, S.Out{r, 1n+n})), [S.PathKey{k}]) == True{} : Bool}:
  %Equal.sym(Bool, S.declared(fs, key), False{}, Equal.trans(Bool, S.declared(fs, key), S.declared(fs, k), False{}, Equal.cong(String, Bool, z => S.declared(fs, z), key, k, JS.string_sound(key, k, he)), Equal.trans(Bool, S.declared(fs, k), Spec.declares(fs, k), False{}, SP.declared_equiv(fs, k), hnd))) : {found(S.strays(t, fs, S.emit(_, S.Error{S.Constraint{}, "object has an undeclared key", [S.PathKey{key}]}, S.Out{r, 1n+n})), [S.PathKey{k}]) == True{} : Bool}
  strays_keeps(t, fs, S.Out{S.Error{S.Constraint{}, "object has an undeclared key", [S.PathKey{key}]} <> r, n}, [S.PathKey{k}], or_left(Spec.same_path([S.PathKey{key}], [S.PathKey{k}]), Spec.names(r, [S.PathKey{k}]), and_both(String.eq(key, k), True{}, he, {==})))

def strays_step(+key: String, +y: J.Json, +t: List<&2, J.Field>, +fs: List<&2, S.Field>, +k: String, +r: List<&2, S.Error>, +n: Nat, +b: Bool, he: {String.eq(key, k) == b : Bool}, hnd: {Spec.declares(fs, k) == False{} : Bool}, hnz: {Bool.not(Nat.is_eq(Spec.bump(b, Spec.named(t, k)), 0n)) == True{} : Bool}, ih: {Bool.not(Nat.is_eq(Spec.named(t, k), 0n)) == True{} : Bool} -> {found(S.strays(t, fs, S.emit(S.declared(fs, key), S.Error{S.Constraint{}, "object has an undeclared key", [S.PathKey{key}]}, S.Out{r, 1n+n})), [S.PathKey{k}]) == True{} : Bool}) -> {found(S.strays(t, fs, S.emit(S.declared(fs, key), S.Error{S.Constraint{}, "object has an undeclared key", [S.PathKey{key}]}, S.Out{r, 1n+n})), [S.PathKey{k}]) == True{} : Bool}:
  match b:
    case True{}: strays_hit(key, y, t, fs, k, r, n, hnd, he)
    case False{}: ih(hnz)

def strays_complete(+input: List<&2, J.Field>, +fs: List<&2, S.Field>, +k: String, +o: S.Out, hnz: {Bool.not(Nat.is_eq(Spec.named(input, k), 0n)) == True{} : Bool}, +hnd: {Spec.declares(fs, k) == False{} : Bool}) -> {found(S.strays(input, fs, o), [S.PathKey{k}]) == True{} : Bool}:
  match input o:
    case Nil{} S.Out{r, 0n}: or_right(Spec.names(r, [S.PathKey{k}]), True{}, {==})
    case Nil{} S.Out{r, 1n+n}: UP.absurd({found(S.Out{r, 1n+n}, [S.PathKey{k}]) == True{} : Bool}, UP.false_true(hnz))
    case J.Field{key, y} <> t S.Out{r, 0n}: or_right(Spec.names(r, [S.PathKey{k}]), True{}, {==})
    case J.Field{+key, +y} <> +t S.Out{+r, 1n+(+n)}: strays_step(key, y, t, fs, k, r, n, String.eq(key, k), {==}, hnd, hnz, h2 => strays_complete(t, fs, k, S.emit(S.declared(fs, key), S.Error{S.Constraint{}, "object has an undeclared key", [S.PathKey{key}]}, S.Out{r, 1n+n}), h2, hnd))

def stray_hit(u: S.Unknown, fs: List<&2, S.Field>, input: List<&2, J.Field>, path: List<&2, S.PathPart>) -> Bool:
  match path:
    case S.PathKey{k} <> q: Spec.stray(u, fs, input, k, q)
    case _: False{}

def unknown_found(+u: S.Unknown, +fs: List<&2, S.Field>, +input: List<&2, J.Field>, +l: Nat, +path: List<&2, S.PathPart>, +h: {stray_hit(u, fs, input, path) == True{} : Bool}) -> {found(S.unknown_out(u, fs, input, S.Out{[], l}), path) == True{} : Bool}:
  match u path:
    case w Nil{}: UP.absurd({found(S.unknown_out(w, fs, input, S.Out{[], l}), []) == True{} : Bool}, UP.false_true(h))
    case w S.PathIndex{a} <> q: UP.absurd({found(S.unknown_out(w, fs, input, S.Out{[], l}), S.PathIndex{a} <> q) == True{} : Bool}, UP.false_true(h))
    case S.Strip{} S.PathKey{k} <> q: UP.absurd({found(S.unknown_out(S.Strip{}, fs, input, S.Out{[], l}), S.PathKey{k} <> q) == True{} : Bool}, UP.false_true(h))
    case S.Strict{} S.PathKey{+k} <> q:
      match q:
        case Nil{}: strays_complete(input, fs, k, S.Out{[], l}, UP.and_right(Bool.not(Spec.declares(fs, k)), Bool.not(Nat.is_eq(Spec.named(input, k), 0n)), UP.and_left(Bool.not(Spec.declares(fs, k)) && Bool.not(Nat.is_eq(Spec.named(input, k), 0n)), True{}, h)), Equal.trans(Bool, Spec.declares(fs, k), Bool.not(Bool.not(Spec.declares(fs, k))), False{}, not_not(Spec.declares(fs, k)), Equal.cong(Bool, Bool, z => Bool.not(z), Bool.not(Spec.declares(fs, k)), True{}, UP.and_left(Bool.not(Spec.declares(fs, k)), Bool.not(Nat.is_eq(Spec.named(input, k), 0n)), UP.and_left(Bool.not(Spec.declares(fs, k)) && Bool.not(Nat.is_eq(Spec.named(input, k), 0n)), True{}, h)))))
        case g <> r: UP.absurd({found(S.strays(input, fs, S.Out{[], l}), S.PathKey{k} <> g <> r) == True{} : Bool}, UP.false_true(UP.and_right(Bool.not(Spec.declares(fs, k)) && Bool.not(Nat.is_eq(Spec.named(input, k), 0n)), False{}, h)))

def keyed_slots(+fs: List<&2, S.Field>, +u: S.Unknown, +input: List<&2, J.Field>, +k: String, +q: List<&2, S.PathPart>, h: {Spec.fault(S.ObjectSchema{fs, u}, J.JObject{input}, S.PathKey{k} <> q, Spec.Keyed{}) == True{} : Bool}) -> {slots_fault(S.PathKey{k} <> q, fs, S.slots(fs, input)) == True{} : Bool}:
  match fs:
    case Nil{}: UP.absurd({False{} == True{} : Bool}, UP.false_true(h))
    case S.Field{key, c, pr} <> t:
      %Equal.sym(Bool, slot_local(c, pr, S.find(input, key, S.Absent{}), q), (Spec.miscount(pr, Spec.named(input, key), q) || (Nat.is_eq(Spec.named(input, key), 1n) && Spec.fault(c, Spec.member(input, key), q, Spec.Here{}))), slot_local_eq(c, pr, input, key, q)) : {((String.eq(key, k) && _) || slots_fault(S.PathKey{k} <> q, t, S.slots(t, input))) == True{} : Bool}
      or_mono(String.eq(key, k) && (Spec.miscount(pr, Spec.named(input, key), q) || (Nat.is_eq(Spec.named(input, key), 1n) && Spec.fault(c, Spec.member(input, key), q, Spec.Here{}))), Spec.fault(S.ObjectSchema{t, u}, J.JObject{input}, S.PathKey{k} <> q, Spec.Keyed{}), slots_fault(S.PathKey{k} <> q, t, S.slots(t, input)), h, hb => keyed_slots(t, u, input, k, q, hb))

def split3(+st: Bool, -x: Bool, -y: Bool, -G: Type, h: {((st || x) || y) == True{} : Bool}, fs: {st == True{} : Bool} -> G, fk: {(x || y) == True{} : Bool} -> G) -> G:
  match st:
    case True{}: fs({==})
    case False{}: fk(h)

def found_stray(+x: S.Out, +r0: List<&2, S.Error>, +l0: Nat, +path: List<&2, S.PathPart>, hz: {Nat.is_eq(l0, 0n) == True{} : Bool} -> {found(extend(x, r0), path) == True{} : Bool}, h: {found(S.Out{r0, l0}, path) == True{} : Bool}) -> {found(extend(x, r0), path) == True{} : Bool}:
  or_elim(Spec.names(r0, path), Nat.is_eq(l0, 0n), {found(extend(x, r0), path) == True{} : Bool}, h, hn => found_right(x, r0, path, hn), hz)

def obj_entry_k2(+path: List<&2, S.PathPart>, +fs: List<&2, S.Field>, +u: S.Unknown, +input: List<&2, J.Field>, +r0: List<&2, S.Error>, +l0: Nat, hst: {stray_hit(u, fs, input, path) == True{} : Bool} -> {found(S.Out{r0, l0}, path) == True{} : Bool}, hf: {Spec.fault(S.ObjectSchema{fs, u}, J.JObject{input}, path, Spec.Here{}) == True{} : Bool}, ih: {slots_fault(path, fs, S.slots(fs, input)) == True{} : Bool} -> {found(S.collect_go(S.ObjectSchema{fs, u}, J.JObject{input}, S.WFields{S.slots(fs, input), S.Out{[], l0}}), path) == True{} : Bool}) -> {found(extend(S.collect_go(S.ObjectSchema{fs, u}, J.JObject{input}, S.WFields{S.slots(fs, input), S.Out{[], l0}}), r0), path) == True{} : Bool}:
  match path fs:
    case Nil{} Nil{}: UP.absurd({found(extend(S.collect_go(S.ObjectSchema{Nil{}, u}, J.JObject{input}, S.WFields{S.slots(Nil{}, input), S.Out{[], l0}}), r0), []) == True{} : Bool}, UP.false_true(hf))
    case Nil{} S.Field{a1, a2, a3} <> a4: UP.absurd({found(extend(S.collect_go(S.ObjectSchema{S.Field{a1, a2, a3} <> a4, u}, J.JObject{input}, S.WFields{S.slots(S.Field{a1, a2, a3} <> a4, input), S.Out{[], l0}}), r0), []) == True{} : Bool}, UP.false_true(hf))
    case S.PathIndex{a} <> q Nil{}: UP.absurd({found(extend(S.collect_go(S.ObjectSchema{Nil{}, u}, J.JObject{input}, S.WFields{S.slots(Nil{}, input), S.Out{[], l0}}), r0), S.PathIndex{a} <> q) == True{} : Bool}, UP.false_true(hf))
    case S.PathIndex{a} <> q S.Field{a1, a2, a3} <> a4: UP.absurd({found(extend(S.collect_go(S.ObjectSchema{S.Field{a1, a2, a3} <> a4, u}, J.JObject{input}, S.WFields{S.slots(S.Field{a1, a2, a3} <> a4, input), S.Out{[], l0}}), r0), S.PathIndex{a} <> q) == True{} : Bool}, UP.false_true(hf))
    case S.PathKey{+k} <> +q Nil{}: found_stray(S.collect_go(S.ObjectSchema{[], u}, J.JObject{input}, S.WFields{[], S.Out{[], l0}}), r0, l0, S.PathKey{k} <> q, hz => obj_zero_found([], u, J.JObject{input}, [], l0, r0, S.PathKey{k} <> q, hz), hst(hf))
    case S.PathKey{+k} <> +q S.Field{+key, +c, +pr} <> +t: split3(Spec.stray(u, S.Field{key, c, pr} <> t, input, k, q), String.eq(key, k) && (Spec.miscount(pr, Spec.named(input, key), q) || (Nat.is_eq(Spec.named(input, key), 1n) && Spec.fault(c, Spec.member(input, key), q, Spec.Here{}))), Spec.fault(S.ObjectSchema{t, u}, J.JObject{input}, S.PathKey{k} <> q, Spec.Keyed{}), {found(extend(S.collect_go(S.ObjectSchema{S.Field{key, c, pr} <> t, u}, J.JObject{input}, S.WFields{S.slots(S.Field{key, c, pr} <> t, input), S.Out{[], l0}}), r0), S.PathKey{k} <> q) == True{} : Bool}, hf, hs => found_stray(S.collect_go(S.ObjectSchema{S.Field{key, c, pr} <> t, u}, J.JObject{input}, S.WFields{S.slots(S.Field{key, c, pr} <> t, input), S.Out{[], l0}}), r0, l0, S.PathKey{k} <> q, hz => obj_zero_found(S.Field{key, c, pr} <> t, u, J.JObject{input}, S.slots(S.Field{key, c, pr} <> t, input), l0, r0, S.PathKey{k} <> q, hz), hst(hs)), hk => found_left(S.collect_go(S.ObjectSchema{S.Field{key, c, pr} <> t, u}, J.JObject{input}, S.WFields{S.slots(S.Field{key, c, pr} <> t, input), S.Out{[], l0}}), r0, S.PathKey{k} <> q, ih(keyed_slots(S.Field{key, c, pr} <> t, u, input, k, q, hk))))

def obj_entry_k(+fs: List<&2, S.Field>, +u: S.Unknown, +input: List<&2, J.Field>, +path: List<&2, S.PathPart>, so: S.Out) -> ({stray_hit(u, fs, input, path) == True{} : Bool} -> {found(so, path) == True{} : Bool}) -> {S.collect_go(S.ObjectSchema{fs, u}, J.JObject{input}, S.WFields{S.slots(fs, input), so}) == extend(S.collect_go(S.ObjectSchema{fs, u}, J.JObject{input}, blank(S.WFields{S.slots(fs, input), so})), wrev(S.WFields{S.slots(fs, input), so})) : S.Out} -> {Spec.fault(S.ObjectSchema{fs, u}, J.JObject{input}, path, Spec.Here{}) == True{} : Bool} -> ({state_fault_c(S.WFields{S.slots(fs, input), so}, S.ObjectSchema{fs, u}, J.JObject{input}, path) == True{} : Bool} -> {found(S.collect_go(S.ObjectSchema{fs, u}, J.JObject{input}, blank(S.WFields{S.slots(fs, input), so})), path) == True{} : Bool}) -> {found(S.collect_go(S.ObjectSchema{fs, u}, J.JObject{input}, S.WFields{S.slots(fs, input), so}), path) == True{} : Bool}:
  match so:
    case S.Out{+r0, +l0}: hst => hfr => hf => ih =>
      %Equal.sym(S.Out, S.collect_go(S.ObjectSchema{fs, u}, J.JObject{input}, S.WFields{S.slots(fs, input), S.Out{r0, l0}}), extend(S.collect_go(S.ObjectSchema{fs, u}, J.JObject{input}, S.WFields{S.slots(fs, input), S.Out{[], l0}}), r0), hfr) : {found(_, path) == True{} : Bool}
      obj_entry_k2(path, fs, u, input, r0, l0, hst, hf, ih)

# A child's state started by cstart reports every location of the child.
def entry_k(+s: S.Schema, +v: J.Json, +l: Nat, +path: List<&2, S.PathPart>, hf: {Spec.fault(s, v, path, Spec.Here{}) == True{} : Bool}, ih: {state_fault_c(S.cstart(s, v, l), s, v, path) == True{} : Bool} -> {found(S.collect_go(s, v, blank(S.cstart(s, v, l))), path) == True{} : Bool}) -> {found(S.collect_go(s, v, S.cstart(s, v, l)), path) == True{} : Bool}:
  match s v:
    case S.ArraySchema{i, m, n} J.JArray{xs}: arr_entry_k(i, m, n, xs, l, path, S.item_count(m, n, S.count(xs, 0n)), count_ok_eq(m, n, xs), hf, ih)
    case S.ArraySchema{i, m, n} J.JNull{}: ih(hf)
    case S.ArraySchema{i, m, n} J.JBool{b0}: ih(hf)
    case S.ArraySchema{i, m, n} J.JNumber{b0}: ih(hf)
    case S.ArraySchema{i, m, n} J.JString{b0}: ih(hf)
    case S.ArraySchema{i, m, n} J.JObject{b0}: ih(hf)
    case S.ObjectSchema{+fs, +u} J.JObject{+input}: obj_entry_k(fs, u, input, path, S.unknown_out(u, fs, input, S.Out{[], l}))(hs => unknown_found(u, fs, input, l, path, hs))(frame(S.ObjectSchema{fs, u}, J.JObject{input}, S.WFields{S.slots(fs, input), S.unknown_out(u, fs, input, S.Out{[], l})}))(hf)(ih)
    case S.ObjectSchema{fs, u} J.JNull{}: ih(hf)
    case S.ObjectSchema{fs, u} J.JBool{b0}: ih(hf)
    case S.ObjectSchema{fs, u} J.JNumber{b0}: ih(hf)
    case S.ObjectSchema{fs, u} J.JString{b0}: ih(hf)
    case S.ObjectSchema{fs, u} J.JArray{b0}: ih(hf)
    case S.StringSchema{a1, a2, a3, a4} x: ih(hf)
    case S.NumberSchema{a1, a2} x: ih(hf)
    case S.IntegerSchema{a1, a2} x: ih(hf)
    case S.BooleanSchema{} x: ih(hf)
    case S.LiteralSchema{a1} x: ih(hf)
    case S.EnumSchema{a1} x: ih(hf)
    case S.NullableSchema{i} x: ih(hf)
    case S.UnionSchema{ms} x: ih(hf)
