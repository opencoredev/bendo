# BND-89: the decoder's error list is exactly the specification's.
#
# `SchemaSpec.failures` lists every failure occurrence in traversal order.
# The collector walks the same order with a budget, so it lists a prefix:
# `fill(ps, o)` adds the paths ps to o one by one until the budget runs out.
# One induction over the walk's states (`exact`) shows that each state's
# result is its starting list filled with what the state still has to visit
# (`rem`); `entry` matches a child's starting state with `failures`. The laws
# then reverse the list and cut it to the first error_cap() paths.
import Base
import ../src/data/schema.bend as S
import ../src/data/json.bend as J
import ../src/data/schema-spec.bend as Spec
import ./schema.bend as SP
import ./schema-compound.bend as SC
import ./schema-errors.bend as SE
import ./schema-coerce.bend as SCo
import ./utf8.bend as UP
import ../src/data/decimal.bend as D

# Paths and the budget.

type PO is Data:
  PO{rev: List<&2, List<&2, S.PathPart>>, left: Nat}

def fill(ps: List<&2, List<&2, S.PathPart>>, o: PO) -> PO:
  match ps o:
    case Nil{} q: q
    case p <> t PO{r, 0n}: PO{r, 0n}
    case p <> t PO{r, 1n+n}: fill(t, PO{p <> r, n})

def proj(o: S.Out) -> PO:
  match o:
    case S.Out{r, l}: PO{Spec.paths(r), l}

def shift(+part: S.PathPart, o: PO, r: List<&2, List<&2, S.PathPart>>) -> PO:
  match o:
    case PO{y, n}: PO{Spec.join(Spec.under(part, y), r), n}

def fill_zero(+ps: List<&2, List<&2, S.PathPart>>, +r: List<&2, List<&2, S.PathPart>>) -> {fill(ps, PO{r, 0n}) == PO{r, 0n} : PO}:
  match ps:
    case Nil{}: {==}
    case p <> t: {==}

def fill_join(+a: List<&2, List<&2, S.PathPart>>, +b: List<&2, List<&2, S.PathPart>>, +o: PO) -> {fill(Spec.join(a, b), o) == fill(b, fill(a, o)) : PO}:
  match a o:
    case Nil{} q: {==}
    case p <> t PO{r, 0n}: Equal.sym(PO, fill(b, PO{r, 0n}), PO{r, 0n}, fill_zero(b, r))
    case p <> t PO{r, 1n+n}: fill_join(t, b, PO{p <> r, n})

def fill_under(+part: S.PathPart, +f: List<&2, List<&2, S.PathPart>>, +x: List<&2, List<&2, S.PathPart>>, +r: List<&2, List<&2, S.PathPart>>, +l: Nat) -> {fill(Spec.under(part, f), PO{Spec.join(Spec.under(part, x), r), l}) == shift(part, fill(f, PO{x, l}), r) : PO}:
  match f l:
    case Nil{} n: {==}
    case p <> t 0n: {==}
    case p <> t 1n+n: fill_under(part, t, p <> x, r, n)

# What a state adds after o, then what follows: the whole fill.
def seq(-lhs: PO, +a: List<&2, List<&2, S.PathPart>>, +b: List<&2, List<&2, S.PathPart>>, +o: PO, -o2: PO, ih: {lhs == fill(b, o2) : PO}, ho: {o2 == fill(a, o) : PO}) -> {lhs == fill(Spec.join(a, b), o) : PO}:
  Equal.trans(PO, lhs, fill(b, o2), fill(Spec.join(a, b), o), ih, Equal.trans(PO, fill(b, o2), fill(b, fill(a, o)), fill(Spec.join(a, b), o), Equal.cong(PO, PO, z => fill(b, z), o2, fill(a, o), ho), Equal.sym(PO, fill(Spec.join(a, b), o), fill(b, fill(a, o)), fill_join(a, b, o))))

# The collector's lists, read as paths.

def paths_prefix(+part: S.PathPart, +es: List<&2, S.Error>, +r: List<&2, S.Error>) -> {Spec.paths(S.prefix_onto(part, es, r)) == Spec.join(Spec.under(part, Spec.paths(es)), Spec.paths(r)) : List<&2, List<&2, S.PathPart>>}:
  match es:
    case Nil{}: {==}
    case S.Error{c, m, p} <> t: Equal.cong(List<&2, List<&2, S.PathPart>>, List<&2, List<&2, S.PathPart>>, z => (part <> p) <> z, Spec.paths(S.prefix_onto(part, t, r)), Spec.join(Spec.under(part, Spec.paths(t)), Spec.paths(r)), paths_prefix(part, t, r))

def merge_proj(+part: S.PathPart, +cc: S.Out, +r: List<&2, S.Error>) -> {proj(S.merge(part, cc, r)) == shift(part, proj(cc), Spec.paths(r)) : PO}:
  match cc:
    case S.Out{es, cl}: Equal.cong(List<&2, List<&2, S.PathPart>>, PO, z => PO{z, cl}, Spec.paths(S.prefix_onto(part, es, r)), Spec.join(Spec.under(part, Spec.paths(es)), Spec.paths(r)), paths_prefix(part, es, r))

# A child's errors, prefixed and joined to the parent's.
def merge_step(+part: S.PathPart, +cc: S.Out, +r: List<&2, S.Error>, +f: List<&2, List<&2, S.PathPart>>, +l: Nat, hc: {proj(cc) == fill(f, PO{[], l}) : PO}) -> {proj(S.merge(part, cc, r)) == fill(Spec.under(part, f), PO{Spec.paths(r), l}) : PO}:
  Equal.trans(PO, proj(S.merge(part, cc, r)), shift(part, proj(cc), Spec.paths(r)), fill(Spec.under(part, f), PO{Spec.paths(r), l}), merge_proj(part, cc, r), Equal.trans(PO, shift(part, proj(cc), Spec.paths(r)), shift(part, fill(f, PO{[], l}), Spec.paths(r)), fill(Spec.under(part, f), PO{Spec.paths(r), l}), Equal.cong(PO, PO, z => shift(part, z, Spec.paths(r)), proj(cc), fill(f, PO{[], l}), hc), Equal.sym(PO, fill(Spec.under(part, f), PO{Spec.paths(r), l}), shift(part, fill(f, PO{[], l}), Spec.paths(r)), fill_under(part, f, [], Spec.paths(r), l))))

def emit_fill(+b: Bool, +c: S.Code, +m: String, +p: List<&2, S.PathPart>, +o: S.Out) -> {proj(S.emit(b, S.Error{c, m, p}, o)) == fill(Spec.flag(b, p), proj(o)) : PO}:
  match b o:
    case True{} q: {==}
    case False{} S.Out{r, 0n}: {==}
    case False{} S.Out{r, 1n+n}: {==}

def emit_all_fill(+es: List<&2, S.Error>, +o: S.Out) -> {proj(S.emit_all(es, o)) == fill(Spec.paths(es), proj(o)) : PO}:
  match es o:
    case Nil{} q: {==}
    case S.Error{c, m, p} <> t S.Out{r, 0n}: Equal.trans(PO, proj(S.emit_all(t, S.Out{r, 0n})), fill(Spec.paths(t), PO{Spec.paths(r), 0n}), PO{Spec.paths(r), 0n}, emit_all_fill(t, S.Out{r, 0n}), fill_zero(Spec.paths(t), Spec.paths(r)))
    case S.Error{c, m, p} <> t S.Out{r, 1n+n}: emit_all_fill(t, S.Out{S.Error{c, m, p} <> r, n})

# Scalars, kinds and unions: one failure at the value, or none.

def scalar_fill(+r: Result<&2, &2, S.Errors(), S.Value>, +l: Nat) -> {proj(S.scalar_out(r, l)) == fill(Spec.listed_paths(r), PO{[], l}) : PO}:
  match r:
    case Done{x}: {==}
    case Fail{es}: emit_all_fill(es, S.Out{[], l})

def finish_one(+v: S.Value, +b: Bool) -> {Spec.listed_paths(S.finish(v, b)) == Spec.flag(S.accepted(S.finish(v, b)), []) : List<&2, List<&2, S.PathPart>>}:
  match b:
    case True{}: {==}
    case False{}: {==}

def scalar_one(+s: S.Schema, +v: J.Json) -> {Spec.listed_paths(S.decode_scalar(s, v)) == Spec.flag(S.accepted(S.decode_scalar(s, v)), []) : List<&2, List<&2, S.PathPart>>}:
  match s v:
    case S.StringSchema{a1, a2, a3, a4} J.JString{x}: finish_one(S.VString{x}, S.string_check(a1, a2, a3, a4, x))
    case S.StringSchema{a1, a2, a3, a4} J.JNull{}: {==}
    case S.StringSchema{a1, a2, a3, a4} J.JBool{b0}: {==}
    case S.StringSchema{a1, a2, a3, a4} J.JNumber{b0}: {==}
    case S.StringSchema{a1, a2, a3, a4} J.JArray{b0}: {==}
    case S.StringSchema{a1, a2, a3, a4} J.JObject{b0}: {==}
    case S.NumberSchema{a1, a2} J.JNumber{x}: finish_one(S.VNumber{x}, S.number_check(a1, a2, x))
    case S.NumberSchema{a1, a2} J.JNull{}: {==}
    case S.NumberSchema{a1, a2} J.JBool{b0}: {==}
    case S.NumberSchema{a1, a2} J.JString{b0}: {==}
    case S.NumberSchema{a1, a2} J.JArray{b0}: {==}
    case S.NumberSchema{a1, a2} J.JObject{b0}: {==}
    case S.IntegerSchema{a1, a2} J.JNumber{x}: finish_one(S.VInteger{x}, D.is_integer(x) && S.number_check(a1, a2, x))
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
    case S.LiteralSchema{a1} y: finish_one(S.VLiteral{y}, S.scalar(y) && S.same(a1, y))
    case S.EnumSchema{a1} y: finish_one(S.VLiteral{y}, S.scalar(y) && S.one_of(a1, y, False{}))
    case S.ArraySchema{a1, a2, a3} y: {==}
    case S.ObjectSchema{a1, a2} y: {==}
    case S.NullableSchema{a1} y: {==}
    case S.UnionSchema{a1} y: {==}

def scalar_exact(+s: S.Schema, +x: J.Json, +l: Nat, +okv: {S.valid(s) == True{} : Bool}) -> {proj(S.scalar_out(S.decode_scalar(s, x), l)) == fill(Spec.flag(Spec.accepts(s, x), []), PO{[], l}) : PO}:
  Equal.trans(PO, proj(S.scalar_out(S.decode_scalar(s, x), l)), fill(Spec.listed_paths(S.decode_scalar(s, x)), PO{[], l}), fill(Spec.flag(Spec.accepts(s, x), []), PO{[], l}), scalar_fill(S.decode_scalar(s, x), l), Equal.cong(List<&2, List<&2, S.PathPart>>, PO, z => fill(z, PO{[], l}), Spec.listed_paths(S.decode_scalar(s, x)), Spec.flag(Spec.accepts(s, x), []), Equal.trans(List<&2, List<&2, S.PathPart>>, Spec.listed_paths(S.decode_scalar(s, x)), Spec.flag(S.accepted(S.decode_scalar(s, x)), []), Spec.flag(Spec.accepts(s, x), []), scalar_one(s, x), Equal.cong(Bool, List<&2, List<&2, S.PathPart>>, b => Spec.flag(b, []), S.accepted(S.decode_scalar(s, x)), Spec.accepts(s, x), SP.accepts_equiv(s, x, okv)))))

def kind_exact(+l: Nat) -> {proj(S.kind_out(l)) == fill([[]], PO{[], l}) : PO}:
  emit_fill(False{}, S.TypeMismatch{}, "expected schema kind", [], S.Out{[], l})

def union_exact(+ms: List<&2, S.Schema>, +x: J.Json, +l: Nat, +okv: {S.valid(S.UnionSchema{ms}) == True{} : Bool}) -> {proj(S.emit(S.accepted(S.decode_go(S.UnionSchema{ms}, x, S.start(S.UnionSchema{ms}, x))), S.Error{S.Constraint{}, "value matches no union member", []}, S.Out{[], l})) == fill(Spec.flag(Spec.meets(S.UnionSchema{ms}, Spec.Holds{}, x), []), PO{[], l}) : PO}:
  Equal.trans(PO, proj(S.emit(S.accepted(S.decode_go(S.UnionSchema{ms}, x, S.start(S.UnionSchema{ms}, x))), S.Error{S.Constraint{}, "value matches no union member", []}, S.Out{[], l})), fill(Spec.flag(S.accepted(S.decode_go(S.UnionSchema{ms}, x, S.start(S.UnionSchema{ms}, x))), []), PO{[], l}), fill(Spec.flag(Spec.meets(S.UnionSchema{ms}, Spec.Holds{}, x), []), PO{[], l}), emit_fill(S.accepted(S.decode_go(S.UnionSchema{ms}, x, S.start(S.UnionSchema{ms}, x))), S.Constraint{}, "value matches no union member", [], S.Out{[], l}), Equal.cong(Bool, PO, b => fill(Spec.flag(b, []), PO{[], l}), S.accepted(S.decode_go(S.UnionSchema{ms}, x, S.start(S.UnionSchema{ms}, x))), Spec.meets(S.UnionSchema{ms}, Spec.Holds{}, x), SC.child(S.UnionSchema{ms}, x, SC.agree(S.UnionSchema{ms}, x, S.start(S.UnionSchema{ms}, x), okv))))

# Objects: undeclared members, then the declared fields' slots.

def strays_fill(+input: List<&2, J.Field>, +fs: List<&2, S.Field>, +o: S.Out) -> {proj(S.strays(input, fs, o)) == fill(Spec.undeclared(fs, input), proj(o)) : PO}:
  match input o:
    case Nil{} S.Out{r, 0n}: {==}
    case Nil{} S.Out{r, 1n+n}: {==}
    case J.Field{+k, +v} <> +t S.Out{+r, 0n}: Equal.sym(PO, fill(Spec.undeclared(fs, J.Field{k, v} <> t), PO{Spec.paths(r), 0n}), PO{Spec.paths(r), 0n}, fill_zero(Spec.undeclared(fs, J.Field{k, v} <> t), Spec.paths(r)))
    case J.Field{+k, v} <> +t S.Out{+r, 1n+(+n)}: Equal.trans(PO, proj(S.strays(t, fs, S.emit(S.declared(fs, k), S.Error{S.Constraint{}, "object has an undeclared key", [S.PathKey{k}]}, S.Out{r, 1n+n}))), fill(Spec.join(Spec.flag(S.declared(fs, k), [S.PathKey{k}]), Spec.undeclared(fs, t)), PO{Spec.paths(r), 1n+n}), fill(Spec.join(Spec.flag(Spec.declares(fs, k), [S.PathKey{k}]), Spec.undeclared(fs, t)), PO{Spec.paths(r), 1n+n}), seq(proj(S.strays(t, fs, S.emit(S.declared(fs, k), S.Error{S.Constraint{}, "object has an undeclared key", [S.PathKey{k}]}, S.Out{r, 1n+n}))), Spec.flag(S.declared(fs, k), [S.PathKey{k}]), Spec.undeclared(fs, t), PO{Spec.paths(r), 1n+n}, proj(S.emit(S.declared(fs, k), S.Error{S.Constraint{}, "object has an undeclared key", [S.PathKey{k}]}, S.Out{r, 1n+n})), strays_fill(t, fs, S.emit(S.declared(fs, k), S.Error{S.Constraint{}, "object has an undeclared key", [S.PathKey{k}]}, S.Out{r, 1n+n})), emit_fill(S.declared(fs, k), S.Constraint{}, "object has an undeclared key", [S.PathKey{k}], S.Out{r, 1n+n})), Equal.cong(Bool, PO, z => fill(Spec.join(Spec.flag(z, [S.PathKey{k}]), Spec.undeclared(fs, t)), PO{Spec.paths(r), 1n+n}), S.declared(fs, k), Spec.declares(fs, k), SP.declared_equiv(fs, k)))

def unknown_fill(+u: S.Unknown, +fs: List<&2, S.Field>, +input: List<&2, J.Field>, +l: Nat) -> {proj(S.unknown_out(u, fs, input, S.Out{[], l})) == fill(Spec.strays(u, fs, input), PO{[], l}) : PO}:
  match u:
    case S.Strict{}: strays_fill(input, fs, S.Out{[], l})
    case S.Strip{}: {==}

def absent_rem(p: S.Presence, k: String) -> List<&2, List<&2, S.PathPart>>:
  match p:
    case S.Required{}: [[S.PathKey{k}]]
    case S.Optional{}: []
    case S.Default{d}: []

def slot_rem(k: String, c: S.Schema, p: S.Presence, sl: S.Slot) -> List<&2, List<&2, S.PathPart>>:
  match sl:
    case S.Absent{}: absent_rem(p, k)
    case S.Once{y}: Spec.under(S.PathKey{k}, Spec.failures(c, y, Spec.Node{}))
    case S.Repeated{y}: [[S.PathKey{k}]]

# The declared fields still to visit, against their slots.
def field_rem(fs: List<&2, S.Field>, ss: List<&2, S.Slot>) -> List<&2, List<&2, S.PathPart>>:
  match fs ss:
    case S.Field{k, c, p} <> t sl <> rest: Spec.join(slot_rem(k, c, p, sl), field_rem(t, rest))
    case _ _: []

def absent_fill(+p: S.Presence, +k: String, +r: List<&2, S.Error>, +l: Nat) -> {proj(S.emit(S.may_be_absent(p), S.Error{S.Constraint{}, "missing required key", [S.PathKey{k}]}, S.Out{r, 1n+l})) == fill(absent_rem(p, k), PO{Spec.paths(r), 1n+l}) : PO}:
  match p:
    case S.Required{}: {==}
    case S.Optional{}: {==}
    case S.Default{d}: {==}

def slot_head(+k: String, +c: S.Schema, +n: Nat, +p: S.Presence, +y: J.Json) -> {slot_rem(k, c, p, SE.canon(n, y)) == Spec.field_failures(Nat.is_eq(n, 1n), Spec.presence(p, n), k, Spec.under(S.PathKey{k}, Spec.failures(c, y, Spec.Node{}))) : List<&2, List<&2, S.PathPart>>}:
  match n p:
    case 0n S.Required{}: {==}
    case 0n S.Optional{}: {==}
    case 0n S.Default{d}: {==}
    case 1n+m q:
      match m q:
        case 0n z: {==}
        case 1n+j S.Required{}: {==}
        case 1n+j S.Optional{}: {==}
        case 1n+j S.Default{d}: {==}

def fields_eq(+fs: List<&2, S.Field>, +u: S.Unknown, +input: List<&2, J.Field>) -> {field_rem(fs, S.slots(fs, input)) == Spec.failures(S.ObjectSchema{fs, u}, J.JObject{input}, Spec.Fields{}) : List<&2, List<&2, S.PathPart>>}:
  match fs:
    case Nil{}: {==}
    case S.Field{+k, +c, +p} <> +t: Equal.trans(List<&2, List<&2, S.PathPart>>, Spec.join(slot_rem(k, c, p, S.find(input, k, S.Absent{})), field_rem(t, S.slots(t, input))), Spec.join(Spec.field_failures(Nat.is_eq(Spec.named(input, k), 1n), Spec.presence(p, Spec.named(input, k)), k, Spec.under(S.PathKey{k}, Spec.failures(c, Spec.member(input, k), Spec.Node{}))), field_rem(t, S.slots(t, input))), Spec.join(Spec.field_failures(Nat.is_eq(Spec.named(input, k), 1n), Spec.presence(p, Spec.named(input, k)), k, Spec.under(S.PathKey{k}, Spec.failures(c, Spec.member(input, k), Spec.Node{}))), Spec.failures(S.ObjectSchema{t, u}, J.JObject{input}, Spec.Fields{})), Equal.cong(List<&2, List<&2, S.PathPart>>, List<&2, List<&2, S.PathPart>>, z => Spec.join(z, field_rem(t, S.slots(t, input))), slot_rem(k, c, p, S.find(input, k, S.Absent{})), Spec.field_failures(Nat.is_eq(Spec.named(input, k), 1n), Spec.presence(p, Spec.named(input, k)), k, Spec.under(S.PathKey{k}, Spec.failures(c, Spec.member(input, k), Spec.Node{}))), Equal.trans(List<&2, List<&2, S.PathPart>>, slot_rem(k, c, p, S.find(input, k, S.Absent{})), slot_rem(k, c, p, SE.canon(Spec.named(input, k), Spec.member(input, k))), Spec.field_failures(Nat.is_eq(Spec.named(input, k), 1n), Spec.presence(p, Spec.named(input, k)), k, Spec.under(S.PathKey{k}, Spec.failures(c, Spec.member(input, k), Spec.Node{}))), Equal.cong(S.Slot, List<&2, List<&2, S.PathPart>>, z => slot_rem(k, c, p, z), S.find(input, k, S.Absent{}), SE.canon(Spec.named(input, k), Spec.member(input, k)), SE.find_canon(input, k, S.Absent{})), slot_head(k, c, Spec.named(input, k), p, Spec.member(input, k)))), Equal.cong(List<&2, List<&2, S.PathPart>>, List<&2, List<&2, S.PathPart>>, z => Spec.join(Spec.field_failures(Nat.is_eq(Spec.named(input, k), 1n), Spec.presence(p, Spec.named(input, k)), k, Spec.under(S.PathKey{k}, Spec.failures(c, Spec.member(input, k), Spec.Node{}))), z), field_rem(t, S.slots(t, input)), Spec.failures(S.ObjectSchema{t, u}, J.JObject{input}, Spec.Fields{}), fields_eq(t, u, input)))

# Arrays: the item list, unfolded for an item schema that is a variable.

def items_rem(i: S.Schema, v: J.Json, k: Nat) -> List<&2, List<&2, S.PathPart>>:
  match v:
    case J.JArray{xs}: Spec.failures(i, J.JArray{xs}, Spec.Items{k})
    case J.JNull{}: []
    case J.JBool{b}: []
    case J.JNumber{b}: []
    case J.JString{b}: []
    case J.JObject{b}: []

ITEMS_UNFOLD

# What a state still has to visit.
def rem(s: S.Schema, v: J.Json, w: S.Walk) -> List<&2, List<&2, S.PathPart>>:
  match s w:
    case S.ArraySchema{i, m, n} S.WHere{l}: [[]]
    case S.ObjectSchema{fs, u} S.WHere{l}: [[]]
    case x S.WHere{l}: Spec.failures(x, v, Spec.Node{})
    case S.ArraySchema{i, m, n} S.WItems{k, o}: items_rem(i, v, k)
    case S.ObjectSchema{fs, u} S.WFields{ss, o}: field_rem(fs, ss)
    case _ _: []

# The paths a state starts with.
def wstart(w: S.Walk) -> PO:
  match w:
    case S.WHere{l}: PO{[], l}
    case S.WItems{k, o}: proj(o)
    case S.WFields{ss, o}: proj(o)
    case S.WDone{o}: proj(o)

def arr_gate(+i: S.Schema, +m: Nat, +n: Maybe<&2, Nat>, +xs: List<&2, J.Json>, +b: Bool, +l: Nat) -> {fill(rem(S.ArraySchema{i, m, n}, J.JArray{xs}, S.items_walk(b, l)), wstart(S.items_walk(b, l))) == fill(Spec.below(b, Spec.failures(i, J.JArray{xs}, Spec.Items{0n})), PO{[], l}) : PO}:
  match b l:
    case True{} q: {==}
    case False{} 0n: {==}
    case False{} 1n+j: {==}

def arr_entry(+i: S.Schema, +m: Nat, +n: Maybe<&2, Nat>, +xs: List<&2, J.Json>, +l: Nat) -> {fill(rem(S.ArraySchema{i, m, n}, J.JArray{xs}, S.items_walk(S.item_count(m, n, S.count(xs, 0n)), l)), wstart(S.items_walk(S.item_count(m, n, S.count(xs, 0n)), l))) == fill(Spec.below(Nat.is_le(m, Spec.size(xs)) && Spec.at_most(n, Spec.size(xs)), Spec.failures(i, J.JArray{xs}, Spec.Items{0n})), PO{[], l}) : PO}:
  Equal.trans(PO, fill(rem(S.ArraySchema{i, m, n}, J.JArray{xs}, S.items_walk(S.item_count(m, n, S.count(xs, 0n)), l)), wstart(S.items_walk(S.item_count(m, n, S.count(xs, 0n)), l))), fill(Spec.below(S.item_count(m, n, S.count(xs, 0n)), Spec.failures(i, J.JArray{xs}, Spec.Items{0n})), PO{[], l}), fill(Spec.below(Nat.is_le(m, Spec.size(xs)) && Spec.at_most(n, Spec.size(xs)), Spec.failures(i, J.JArray{xs}, Spec.Items{0n})), PO{[], l}), arr_gate(i, m, n, xs, S.item_count(m, n, S.count(xs, 0n)), l), Equal.cong(Bool, PO, z => fill(Spec.below(z, Spec.failures(i, J.JArray{xs}, Spec.Items{0n})), PO{[], l}), S.item_count(m, n, S.count(xs, 0n)), Nat.is_le(m, Spec.size(xs)) && Spec.at_most(n, Spec.size(xs)), SE.count_ok_eq(m, n, xs)))

def obj_entry(+fs: List<&2, S.Field>, +u: S.Unknown, +input: List<&2, J.Field>, +l: Nat) -> {fill(field_rem(fs, S.slots(fs, input)), proj(S.unknown_out(u, fs, input, S.Out{[], l}))) == fill(Spec.join(Spec.strays(u, fs, input), Spec.failures(S.ObjectSchema{fs, u}, J.JObject{input}, Spec.Fields{})), PO{[], l}) : PO}:
  Equal.trans(PO, fill(field_rem(fs, S.slots(fs, input)), proj(S.unknown_out(u, fs, input, S.Out{[], l}))), fill(Spec.failures(S.ObjectSchema{fs, u}, J.JObject{input}, Spec.Fields{}), fill(Spec.strays(u, fs, input), PO{[], l})), fill(Spec.join(Spec.strays(u, fs, input), Spec.failures(S.ObjectSchema{fs, u}, J.JObject{input}, Spec.Fields{})), PO{[], l}), Equal.trans(PO, fill(field_rem(fs, S.slots(fs, input)), proj(S.unknown_out(u, fs, input, S.Out{[], l}))), fill(Spec.failures(S.ObjectSchema{fs, u}, J.JObject{input}, Spec.Fields{}), proj(S.unknown_out(u, fs, input, S.Out{[], l}))), fill(Spec.failures(S.ObjectSchema{fs, u}, J.JObject{input}, Spec.Fields{}), fill(Spec.strays(u, fs, input), PO{[], l})), Equal.cong(List<&2, List<&2, S.PathPart>>, PO, z => fill(z, proj(S.unknown_out(u, fs, input, S.Out{[], l}))), field_rem(fs, S.slots(fs, input)), Spec.failures(S.ObjectSchema{fs, u}, J.JObject{input}, Spec.Fields{}), fields_eq(fs, u, input)), Equal.cong(PO, PO, z => fill(Spec.failures(S.ObjectSchema{fs, u}, J.JObject{input}, Spec.Fields{}), z), proj(S.unknown_out(u, fs, input, S.Out{[], l})), fill(Spec.strays(u, fs, input), PO{[], l}), unknown_fill(u, fs, input, l))), Equal.sym(PO, fill(Spec.join(Spec.strays(u, fs, input), Spec.failures(S.ObjectSchema{fs, u}, J.JObject{input}, Spec.Fields{})), PO{[], l}), fill(Spec.failures(S.ObjectSchema{fs, u}, J.JObject{input}, Spec.Fields{}), fill(Spec.strays(u, fs, input), PO{[], l})), fill_join(Spec.strays(u, fs, input), Spec.failures(S.ObjectSchema{fs, u}, J.JObject{input}, Spec.Fields{}), PO{[], l})))

ENTRY

# A child's state, started by cstart, from the induction's statement for it.
def child(+s: S.Schema, +v: J.Json, +l: Nat, ih: {proj(S.collect_go(s, v, S.cstart(s, v, l))) == fill(rem(s, v, S.cstart(s, v, l)), wstart(S.cstart(s, v, l))) : PO}) -> {proj(S.collect_go(s, v, S.cstart(s, v, l))) == fill(Spec.failures(s, v, Spec.Node{}), PO{[], l}) : PO}:
  Equal.trans(PO, proj(S.collect_go(s, v, S.cstart(s, v, l))), fill(rem(s, v, S.cstart(s, v, l)), wstart(S.cstart(s, v, l))), fill(Spec.failures(s, v, Spec.Node{}), PO{[], l}), ih, entry(s, v, l))
