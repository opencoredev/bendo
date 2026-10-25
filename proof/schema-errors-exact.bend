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

def items_cons(+i: S.Schema, +h: J.Json, +t: List<&2, J.Json>, +k: Nat) -> {Spec.failures(i, J.JArray{h <> t}, Spec.Items{k}) == Spec.join(Spec.under(S.PathIndex{k}, Spec.failures(i, h, Spec.Node{})), Spec.failures(i, J.JArray{t}, Spec.Items{1n+k})) : List<&2, List<&2, S.PathPart>>}:
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

def items_nil(+i: S.Schema, +k: Nat) -> {Spec.failures(i, J.JArray{[]}, Spec.Items{k}) == [] : List<&2, List<&2, S.PathPart>>}:
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

# A child's starting state: an array's length gate, an object's undeclared
# members and slots, or the value itself.
def entry(+s: S.Schema, +v: J.Json, +l: Nat) -> {fill(rem(s, v, S.cstart(s, v, l)), wstart(S.cstart(s, v, l))) == fill(Spec.failures(s, v, Spec.Node{}), PO{[], l}) : PO}:
  match s v:
    case S.ArraySchema{+i, +m, +n} J.JArray{Nil{}}: arr_entry(i, m, n, [], l)
    case S.ArraySchema{+i, +m, +n} J.JArray{+g <> +r}: arr_entry(i, m, n, g <> r, l)
    case S.ArraySchema{i, m, n} J.JNull{}: {==}
    case S.ArraySchema{i, m, n} J.JBool{b0}: {==}
    case S.ArraySchema{i, m, n} J.JNumber{b0}: {==}
    case S.ArraySchema{i, m, n} J.JString{b0}: {==}
    case S.ArraySchema{i, m, n} J.JObject{b0}: {==}
    case S.ObjectSchema{Nil{}, +u} J.JObject{+input}: unknown_fill(u, [], input, l)
    case S.ObjectSchema{S.Field{+k, +c, +p} <> +t, +u} J.JObject{+input}: obj_entry(S.Field{k, c, p} <> t, u, input, l)
    case S.ObjectSchema{Nil{}, u} J.JNull{}: {==}
    case S.ObjectSchema{Nil{}, u} J.JBool{b0}: {==}
    case S.ObjectSchema{Nil{}, u} J.JNumber{b0}: {==}
    case S.ObjectSchema{Nil{}, u} J.JString{b0}: {==}
    case S.ObjectSchema{Nil{}, u} J.JArray{Nil{}}: {==}
    case S.ObjectSchema{Nil{}, u} J.JArray{g <> r}: {==}
    case S.ObjectSchema{S.Field{k, c, p} <> t, u} J.JNull{}: {==}
    case S.ObjectSchema{S.Field{k, c, p} <> t, u} J.JBool{b0}: {==}
    case S.ObjectSchema{S.Field{k, c, p} <> t, u} J.JNumber{b0}: {==}
    case S.ObjectSchema{S.Field{k, c, p} <> t, u} J.JString{b0}: {==}
    case S.ObjectSchema{S.Field{k, c, p} <> t, u} J.JArray{Nil{}}: {==}
    case S.ObjectSchema{S.Field{k, c, p} <> t, u} J.JArray{g <> r}: {==}
    case S.StringSchema{a1, a2, a3, a4} y: {==}
    case S.NumberSchema{a1, a2} y: {==}
    case S.IntegerSchema{a1, a2} y: {==}
    case S.BooleanSchema{} y: {==}
    case S.LiteralSchema{a1} y: {==}
    case S.EnumSchema{a1} y: {==}
    case S.NullableSchema{i} y: {==}
    case S.UnionSchema{ms} y: {==}

# A child's state, started by cstart, from the induction's statement for it.
def child(+s: S.Schema, +v: J.Json, +l: Nat, ih: {proj(S.collect_go(s, v, S.cstart(s, v, l))) == fill(rem(s, v, S.cstart(s, v, l)), wstart(S.cstart(s, v, l))) : PO}) -> {proj(S.collect_go(s, v, S.cstart(s, v, l))) == fill(Spec.failures(s, v, Spec.Node{}), PO{[], l}) : PO}:
  Equal.trans(PO, proj(S.collect_go(s, v, S.cstart(s, v, l))), fill(rem(s, v, S.cstart(s, v, l)), wstart(S.cstart(s, v, l))), fill(Spec.failures(s, v, Spec.Node{}), PO{[], l}), ih, entry(s, v, l))

# Every state lists what it starts with, filled with what it still has to visit.
def exact(+s: S.Schema, +v: J.Json, +w: S.Walk, +okv: {S.valid(s) == True{} : Bool}) -> {proj(S.collect_go(s, v, w)) == fill(rem(s, v, w), wstart(w)) : PO}:
  match s v w:
    case S.StringSchema{+a1, +a2, +a3, +a4} J.JNull{} S.WHere{+l}: scalar_exact(S.StringSchema{a1, a2, a3, a4}, J.JNull{}, l, okv)
    case S.StringSchema{+a1, +a2, +a3, +a4} J.JBool{+b1} S.WHere{+l}: scalar_exact(S.StringSchema{a1, a2, a3, a4}, J.JBool{b1}, l, okv)
    case S.StringSchema{+a1, +a2, +a3, +a4} J.JNumber{+b1} S.WHere{+l}: scalar_exact(S.StringSchema{a1, a2, a3, a4}, J.JNumber{b1}, l, okv)
    case S.StringSchema{+a1, +a2, +a3, +a4} J.JString{+b1} S.WHere{+l}: scalar_exact(S.StringSchema{a1, a2, a3, a4}, J.JString{b1}, l, okv)
    case S.StringSchema{+a1, +a2, +a3, +a4} J.JObject{+b1} S.WHere{+l}: scalar_exact(S.StringSchema{a1, a2, a3, a4}, J.JObject{b1}, l, okv)
    case S.StringSchema{+a1, +a2, +a3, +a4} J.JArray{Nil{}} S.WHere{+l}: scalar_exact(S.StringSchema{a1, a2, a3, a4}, J.JArray{Nil{}}, l, okv)
    case S.StringSchema{+a1, +a2, +a3, +a4} J.JArray{+g1 <> +r1} S.WHere{+l}: scalar_exact(S.StringSchema{a1, a2, a3, a4}, J.JArray{g1 <> r1}, l, okv)
    case S.StringSchema{+a1, +a2, +a3, +a4} +x S.WItems{+kk, S.Out{+r, +ll}}: {==}
    case S.StringSchema{+a1, +a2, +a3, +a4} +x S.WFields{+ss, S.Out{+r, +ll}}: {==}
    case S.StringSchema{+a1, +a2, +a3, +a4} +x S.WDone{S.Out{+r, +ll}}: {==}
    case S.NumberSchema{+a1, +a2} J.JNull{} S.WHere{+l}: scalar_exact(S.NumberSchema{a1, a2}, J.JNull{}, l, okv)
    case S.NumberSchema{+a1, +a2} J.JBool{+b1} S.WHere{+l}: scalar_exact(S.NumberSchema{a1, a2}, J.JBool{b1}, l, okv)
    case S.NumberSchema{+a1, +a2} J.JNumber{+b1} S.WHere{+l}: scalar_exact(S.NumberSchema{a1, a2}, J.JNumber{b1}, l, okv)
    case S.NumberSchema{+a1, +a2} J.JString{+b1} S.WHere{+l}: scalar_exact(S.NumberSchema{a1, a2}, J.JString{b1}, l, okv)
    case S.NumberSchema{+a1, +a2} J.JObject{+b1} S.WHere{+l}: scalar_exact(S.NumberSchema{a1, a2}, J.JObject{b1}, l, okv)
    case S.NumberSchema{+a1, +a2} J.JArray{Nil{}} S.WHere{+l}: scalar_exact(S.NumberSchema{a1, a2}, J.JArray{Nil{}}, l, okv)
    case S.NumberSchema{+a1, +a2} J.JArray{+g1 <> +r1} S.WHere{+l}: scalar_exact(S.NumberSchema{a1, a2}, J.JArray{g1 <> r1}, l, okv)
    case S.NumberSchema{+a1, +a2} +x S.WItems{+kk, S.Out{+r, +ll}}: {==}
    case S.NumberSchema{+a1, +a2} +x S.WFields{+ss, S.Out{+r, +ll}}: {==}
    case S.NumberSchema{+a1, +a2} +x S.WDone{S.Out{+r, +ll}}: {==}
    case S.IntegerSchema{+a1, +a2} J.JNull{} S.WHere{+l}: scalar_exact(S.IntegerSchema{a1, a2}, J.JNull{}, l, okv)
    case S.IntegerSchema{+a1, +a2} J.JBool{+b1} S.WHere{+l}: scalar_exact(S.IntegerSchema{a1, a2}, J.JBool{b1}, l, okv)
    case S.IntegerSchema{+a1, +a2} J.JNumber{+b1} S.WHere{+l}: scalar_exact(S.IntegerSchema{a1, a2}, J.JNumber{b1}, l, okv)
    case S.IntegerSchema{+a1, +a2} J.JString{+b1} S.WHere{+l}: scalar_exact(S.IntegerSchema{a1, a2}, J.JString{b1}, l, okv)
    case S.IntegerSchema{+a1, +a2} J.JObject{+b1} S.WHere{+l}: scalar_exact(S.IntegerSchema{a1, a2}, J.JObject{b1}, l, okv)
    case S.IntegerSchema{+a1, +a2} J.JArray{Nil{}} S.WHere{+l}: scalar_exact(S.IntegerSchema{a1, a2}, J.JArray{Nil{}}, l, okv)
    case S.IntegerSchema{+a1, +a2} J.JArray{+g1 <> +r1} S.WHere{+l}: scalar_exact(S.IntegerSchema{a1, a2}, J.JArray{g1 <> r1}, l, okv)
    case S.IntegerSchema{+a1, +a2} +x S.WItems{+kk, S.Out{+r, +ll}}: {==}
    case S.IntegerSchema{+a1, +a2} +x S.WFields{+ss, S.Out{+r, +ll}}: {==}
    case S.IntegerSchema{+a1, +a2} +x S.WDone{S.Out{+r, +ll}}: {==}
    case S.BooleanSchema{} J.JNull{} S.WHere{+l}: scalar_exact(S.BooleanSchema{}, J.JNull{}, l, okv)
    case S.BooleanSchema{} J.JBool{+b1} S.WHere{+l}: scalar_exact(S.BooleanSchema{}, J.JBool{b1}, l, okv)
    case S.BooleanSchema{} J.JNumber{+b1} S.WHere{+l}: scalar_exact(S.BooleanSchema{}, J.JNumber{b1}, l, okv)
    case S.BooleanSchema{} J.JString{+b1} S.WHere{+l}: scalar_exact(S.BooleanSchema{}, J.JString{b1}, l, okv)
    case S.BooleanSchema{} J.JObject{+b1} S.WHere{+l}: scalar_exact(S.BooleanSchema{}, J.JObject{b1}, l, okv)
    case S.BooleanSchema{} J.JArray{Nil{}} S.WHere{+l}: scalar_exact(S.BooleanSchema{}, J.JArray{Nil{}}, l, okv)
    case S.BooleanSchema{} J.JArray{+g1 <> +r1} S.WHere{+l}: scalar_exact(S.BooleanSchema{}, J.JArray{g1 <> r1}, l, okv)
    case S.BooleanSchema{} +x S.WItems{+kk, S.Out{+r, +ll}}: {==}
    case S.BooleanSchema{} +x S.WFields{+ss, S.Out{+r, +ll}}: {==}
    case S.BooleanSchema{} +x S.WDone{S.Out{+r, +ll}}: {==}
    case S.LiteralSchema{+a1} J.JNull{} S.WHere{+l}: scalar_exact(S.LiteralSchema{a1}, J.JNull{}, l, okv)
    case S.LiteralSchema{+a1} J.JBool{+b1} S.WHere{+l}: scalar_exact(S.LiteralSchema{a1}, J.JBool{b1}, l, okv)
    case S.LiteralSchema{+a1} J.JNumber{+b1} S.WHere{+l}: scalar_exact(S.LiteralSchema{a1}, J.JNumber{b1}, l, okv)
    case S.LiteralSchema{+a1} J.JString{+b1} S.WHere{+l}: scalar_exact(S.LiteralSchema{a1}, J.JString{b1}, l, okv)
    case S.LiteralSchema{+a1} J.JObject{+b1} S.WHere{+l}: scalar_exact(S.LiteralSchema{a1}, J.JObject{b1}, l, okv)
    case S.LiteralSchema{+a1} J.JArray{Nil{}} S.WHere{+l}: scalar_exact(S.LiteralSchema{a1}, J.JArray{Nil{}}, l, okv)
    case S.LiteralSchema{+a1} J.JArray{+g1 <> +r1} S.WHere{+l}: scalar_exact(S.LiteralSchema{a1}, J.JArray{g1 <> r1}, l, okv)
    case S.LiteralSchema{+a1} +x S.WItems{+kk, S.Out{+r, +ll}}: {==}
    case S.LiteralSchema{+a1} +x S.WFields{+ss, S.Out{+r, +ll}}: {==}
    case S.LiteralSchema{+a1} +x S.WDone{S.Out{+r, +ll}}: {==}
    case S.EnumSchema{+a1} J.JNull{} S.WHere{+l}: scalar_exact(S.EnumSchema{a1}, J.JNull{}, l, okv)
    case S.EnumSchema{+a1} J.JBool{+b1} S.WHere{+l}: scalar_exact(S.EnumSchema{a1}, J.JBool{b1}, l, okv)
    case S.EnumSchema{+a1} J.JNumber{+b1} S.WHere{+l}: scalar_exact(S.EnumSchema{a1}, J.JNumber{b1}, l, okv)
    case S.EnumSchema{+a1} J.JString{+b1} S.WHere{+l}: scalar_exact(S.EnumSchema{a1}, J.JString{b1}, l, okv)
    case S.EnumSchema{+a1} J.JObject{+b1} S.WHere{+l}: scalar_exact(S.EnumSchema{a1}, J.JObject{b1}, l, okv)
    case S.EnumSchema{+a1} J.JArray{Nil{}} S.WHere{+l}: scalar_exact(S.EnumSchema{a1}, J.JArray{Nil{}}, l, okv)
    case S.EnumSchema{+a1} J.JArray{+g1 <> +r1} S.WHere{+l}: scalar_exact(S.EnumSchema{a1}, J.JArray{g1 <> r1}, l, okv)
    case S.EnumSchema{+a1} +x S.WItems{+kk, S.Out{+r, +ll}}: {==}
    case S.EnumSchema{+a1} +x S.WFields{+ss, S.Out{+r, +ll}}: {==}
    case S.EnumSchema{+a1} +x S.WDone{S.Out{+r, +ll}}: {==}
    case S.ArraySchema{+i, +m, +n} J.JNull{} S.WHere{+l}: kind_exact(l)
    case S.ArraySchema{+i, +m, +n} J.JNull{} S.WItems{+k, S.Out{+r, 0n}}: Equal.sym(PO, fill(rem(S.ArraySchema{i, m, n}, J.JNull{}, S.WItems{k, S.Out{r, 0n}}), PO{Spec.paths(r), 0n}), PO{Spec.paths(r), 0n}, fill_zero(rem(S.ArraySchema{i, m, n}, J.JNull{}, S.WItems{k, S.Out{r, 0n}}), Spec.paths(r)))
    case S.ArraySchema{+i, +m, +n} J.JNull{} S.WItems{+k, S.Out{+r, 1n+(+l)}}: {==}
    case S.ArraySchema{+i, +m, +n} J.JNull{} S.WFields{+ss, S.Out{+r, +ll}}: {==}
    case S.ArraySchema{+i, +m, +n} J.JNull{} S.WDone{S.Out{+r, +ll}}: {==}
    case S.ArraySchema{+i, +m, +n} J.JBool{+b0} S.WHere{+l}: kind_exact(l)
    case S.ArraySchema{+i, +m, +n} J.JBool{+b0} S.WItems{+k, S.Out{+r, 0n}}: Equal.sym(PO, fill(rem(S.ArraySchema{i, m, n}, J.JBool{b0}, S.WItems{k, S.Out{r, 0n}}), PO{Spec.paths(r), 0n}), PO{Spec.paths(r), 0n}, fill_zero(rem(S.ArraySchema{i, m, n}, J.JBool{b0}, S.WItems{k, S.Out{r, 0n}}), Spec.paths(r)))
    case S.ArraySchema{+i, +m, +n} J.JBool{+b0} S.WItems{+k, S.Out{+r, 1n+(+l)}}: {==}
    case S.ArraySchema{+i, +m, +n} J.JBool{+b0} S.WFields{+ss, S.Out{+r, +ll}}: {==}
    case S.ArraySchema{+i, +m, +n} J.JBool{+b0} S.WDone{S.Out{+r, +ll}}: {==}
    case S.ArraySchema{+i, +m, +n} J.JNumber{+b0} S.WHere{+l}: kind_exact(l)
    case S.ArraySchema{+i, +m, +n} J.JNumber{+b0} S.WItems{+k, S.Out{+r, 0n}}: Equal.sym(PO, fill(rem(S.ArraySchema{i, m, n}, J.JNumber{b0}, S.WItems{k, S.Out{r, 0n}}), PO{Spec.paths(r), 0n}), PO{Spec.paths(r), 0n}, fill_zero(rem(S.ArraySchema{i, m, n}, J.JNumber{b0}, S.WItems{k, S.Out{r, 0n}}), Spec.paths(r)))
    case S.ArraySchema{+i, +m, +n} J.JNumber{+b0} S.WItems{+k, S.Out{+r, 1n+(+l)}}: {==}
    case S.ArraySchema{+i, +m, +n} J.JNumber{+b0} S.WFields{+ss, S.Out{+r, +ll}}: {==}
    case S.ArraySchema{+i, +m, +n} J.JNumber{+b0} S.WDone{S.Out{+r, +ll}}: {==}
    case S.ArraySchema{+i, +m, +n} J.JString{+b0} S.WHere{+l}: kind_exact(l)
    case S.ArraySchema{+i, +m, +n} J.JString{+b0} S.WItems{+k, S.Out{+r, 0n}}: Equal.sym(PO, fill(rem(S.ArraySchema{i, m, n}, J.JString{b0}, S.WItems{k, S.Out{r, 0n}}), PO{Spec.paths(r), 0n}), PO{Spec.paths(r), 0n}, fill_zero(rem(S.ArraySchema{i, m, n}, J.JString{b0}, S.WItems{k, S.Out{r, 0n}}), Spec.paths(r)))
    case S.ArraySchema{+i, +m, +n} J.JString{+b0} S.WItems{+k, S.Out{+r, 1n+(+l)}}: {==}
    case S.ArraySchema{+i, +m, +n} J.JString{+b0} S.WFields{+ss, S.Out{+r, +ll}}: {==}
    case S.ArraySchema{+i, +m, +n} J.JString{+b0} S.WDone{S.Out{+r, +ll}}: {==}
    case S.ArraySchema{+i, +m, +n} J.JObject{+b0} S.WHere{+l}: kind_exact(l)
    case S.ArraySchema{+i, +m, +n} J.JObject{+b0} S.WItems{+k, S.Out{+r, 0n}}: Equal.sym(PO, fill(rem(S.ArraySchema{i, m, n}, J.JObject{b0}, S.WItems{k, S.Out{r, 0n}}), PO{Spec.paths(r), 0n}), PO{Spec.paths(r), 0n}, fill_zero(rem(S.ArraySchema{i, m, n}, J.JObject{b0}, S.WItems{k, S.Out{r, 0n}}), Spec.paths(r)))
    case S.ArraySchema{+i, +m, +n} J.JObject{+b0} S.WItems{+k, S.Out{+r, 1n+(+l)}}: {==}
    case S.ArraySchema{+i, +m, +n} J.JObject{+b0} S.WFields{+ss, S.Out{+r, +ll}}: {==}
    case S.ArraySchema{+i, +m, +n} J.JObject{+b0} S.WDone{S.Out{+r, +ll}}: {==}
    case S.ArraySchema{+i, +m, +n} J.JArray{Nil{}} S.WHere{+l}: kind_exact(l)
    case S.ArraySchema{+i, +m, +n} J.JArray{Nil{}} S.WItems{+k, S.Out{+r, 0n}}: Equal.sym(PO, fill(rem(S.ArraySchema{i, m, n}, J.JArray{Nil{}}, S.WItems{k, S.Out{r, 0n}}), PO{Spec.paths(r), 0n}), PO{Spec.paths(r), 0n}, fill_zero(rem(S.ArraySchema{i, m, n}, J.JArray{Nil{}}, S.WItems{k, S.Out{r, 0n}}), Spec.paths(r)))
    case S.ArraySchema{+i, +m, +n} J.JArray{Nil{}} S.WItems{+k, S.Out{+r, 1n+(+l)}}: Equal.cong(List<&2, List<&2, S.PathPart>>, PO, z => fill(z, PO{Spec.paths(r), 1n+l}), [], Spec.failures(i, J.JArray{[]}, Spec.Items{k}), Equal.sym(List<&2, List<&2, S.PathPart>>, Spec.failures(i, J.JArray{[]}, Spec.Items{k}), [], items_nil(i, k)))
    case S.ArraySchema{+i, +m, +n} J.JArray{Nil{}} S.WFields{+ss, S.Out{+r, +ll}}: {==}
    case S.ArraySchema{+i, +m, +n} J.JArray{Nil{}} S.WDone{S.Out{+r, +ll}}: {==}
    case S.ArraySchema{+i, +m, +n} J.JArray{+h <> +t} S.WHere{+l}: kind_exact(l)
    case S.ArraySchema{+i, +m, +n} J.JArray{+h <> +t} S.WItems{+k, S.Out{+r, 0n}}: Equal.sym(PO, fill(rem(S.ArraySchema{i, m, n}, J.JArray{h <> t}, S.WItems{k, S.Out{r, 0n}}), PO{Spec.paths(r), 0n}), PO{Spec.paths(r), 0n}, fill_zero(rem(S.ArraySchema{i, m, n}, J.JArray{h <> t}, S.WItems{k, S.Out{r, 0n}}), Spec.paths(r)))
    case S.ArraySchema{+i, +m, +n} J.JArray{+h <> +t} S.WItems{+k, S.Out{+r, 1n+(+l)}}: Equal.trans(PO, proj(S.collect_go(S.ArraySchema{i, m, n}, J.JArray{t}, S.WItems{1n+k, S.merge(S.PathIndex{k}, S.collect_go(i, h, S.cstart(i, h, 1n+l)), r)})), fill(Spec.join(Spec.under(S.PathIndex{k}, Spec.failures(i, h, Spec.Node{})), Spec.failures(i, J.JArray{t}, Spec.Items{1n+k})), PO{Spec.paths(r), 1n+l}), fill(Spec.failures(i, J.JArray{h <> t}, Spec.Items{k}), PO{Spec.paths(r), 1n+l}), seq(proj(S.collect_go(S.ArraySchema{i, m, n}, J.JArray{t}, S.WItems{1n+k, S.merge(S.PathIndex{k}, S.collect_go(i, h, S.cstart(i, h, 1n+l)), r)})), Spec.under(S.PathIndex{k}, Spec.failures(i, h, Spec.Node{})), Spec.failures(i, J.JArray{t}, Spec.Items{1n+k}), PO{Spec.paths(r), 1n+l}, proj(S.merge(S.PathIndex{k}, S.collect_go(i, h, S.cstart(i, h, 1n+l)), r)), exact(S.ArraySchema{i, m, n}, J.JArray{t}, S.WItems{1n+k, S.merge(S.PathIndex{k}, S.collect_go(i, h, S.cstart(i, h, 1n+l)), r)}, okv), merge_step(S.PathIndex{k}, S.collect_go(i, h, S.cstart(i, h, 1n+l)), r, Spec.failures(i, h, Spec.Node{}), 1n+l, child(i, h, 1n+l, exact(i, h, S.cstart(i, h, 1n+l), SC.item_valid(i, m, n, okv))))), Equal.cong(List<&2, List<&2, S.PathPart>>, PO, z => fill(z, PO{Spec.paths(r), 1n+l}), Spec.join(Spec.under(S.PathIndex{k}, Spec.failures(i, h, Spec.Node{})), Spec.failures(i, J.JArray{t}, Spec.Items{1n+k})), Spec.failures(i, J.JArray{h <> t}, Spec.Items{k}), Equal.sym(List<&2, List<&2, S.PathPart>>, Spec.failures(i, J.JArray{h <> t}, Spec.Items{k}), Spec.join(Spec.under(S.PathIndex{k}, Spec.failures(i, h, Spec.Node{})), Spec.failures(i, J.JArray{t}, Spec.Items{1n+k})), items_cons(i, h, t, k))))
    case S.ArraySchema{+i, +m, +n} J.JArray{+h <> +t} S.WFields{+ss, S.Out{+r, +ll}}: {==}
    case S.ArraySchema{+i, +m, +n} J.JArray{+h <> +t} S.WDone{S.Out{+r, +ll}}: {==}
    case S.ObjectSchema{Nil{}, +u} J.JNull{} S.WHere{+l}: kind_exact(l)
    case S.ObjectSchema{Nil{}, +u} J.JBool{+b1} S.WHere{+l}: kind_exact(l)
    case S.ObjectSchema{Nil{}, +u} J.JNumber{+b1} S.WHere{+l}: kind_exact(l)
    case S.ObjectSchema{Nil{}, +u} J.JString{+b1} S.WHere{+l}: kind_exact(l)
    case S.ObjectSchema{Nil{}, +u} J.JObject{+b1} S.WHere{+l}: kind_exact(l)
    case S.ObjectSchema{Nil{}, +u} J.JArray{Nil{}} S.WHere{+l}: kind_exact(l)
    case S.ObjectSchema{Nil{}, +u} J.JArray{+g1 <> +r1} S.WHere{+l}: kind_exact(l)
    case S.ObjectSchema{Nil{}, +u} +x S.WItems{+kk, S.Out{+r, +ll}}: {==}
    case S.ObjectSchema{Nil{}, +u} +x S.WDone{S.Out{+r, +ll}}: {==}
    case S.ObjectSchema{Nil{}, +u} +x S.WFields{+ss, S.Out{+r, 0n}}: Equal.sym(PO, fill(rem(S.ObjectSchema{Nil{}, u}, x, S.WFields{ss, S.Out{r, 0n}}), PO{Spec.paths(r), 0n}), PO{Spec.paths(r), 0n}, fill_zero(rem(S.ObjectSchema{Nil{}, u}, x, S.WFields{ss, S.Out{r, 0n}}), Spec.paths(r)))
    case S.ObjectSchema{Nil{}, +u} +x S.WFields{+ss, S.Out{+r, 1n+(+l)}}: {==}
    case S.ObjectSchema{S.Field{+k, +c, +p} <> +t, +u} J.JNull{} S.WHere{+l}: kind_exact(l)
    case S.ObjectSchema{S.Field{+k, +c, +p} <> +t, +u} J.JBool{+b1} S.WHere{+l}: kind_exact(l)
    case S.ObjectSchema{S.Field{+k, +c, +p} <> +t, +u} J.JNumber{+b1} S.WHere{+l}: kind_exact(l)
    case S.ObjectSchema{S.Field{+k, +c, +p} <> +t, +u} J.JString{+b1} S.WHere{+l}: kind_exact(l)
    case S.ObjectSchema{S.Field{+k, +c, +p} <> +t, +u} J.JObject{+b1} S.WHere{+l}: kind_exact(l)
    case S.ObjectSchema{S.Field{+k, +c, +p} <> +t, +u} J.JArray{Nil{}} S.WHere{+l}: kind_exact(l)
    case S.ObjectSchema{S.Field{+k, +c, +p} <> +t, +u} J.JArray{+g1 <> +r1} S.WHere{+l}: kind_exact(l)
    case S.ObjectSchema{S.Field{+k, +c, +p} <> +t, +u} +x S.WItems{+kk, S.Out{+r, +ll}}: {==}
    case S.ObjectSchema{S.Field{+k, +c, +p} <> +t, +u} +x S.WDone{S.Out{+r, +ll}}: {==}
    case S.ObjectSchema{S.Field{+k, +c, +p} <> +t, +u} +x S.WFields{Nil{}, S.Out{+r, 0n}}: Equal.sym(PO, fill(rem(S.ObjectSchema{S.Field{k, c, p} <> t, u}, x, S.WFields{Nil{}, S.Out{r, 0n}}), PO{Spec.paths(r), 0n}), PO{Spec.paths(r), 0n}, fill_zero(rem(S.ObjectSchema{S.Field{k, c, p} <> t, u}, x, S.WFields{Nil{}, S.Out{r, 0n}}), Spec.paths(r)))
    case S.ObjectSchema{S.Field{+k, +c, +p} <> +t, +u} +x S.WFields{S.Once{+y} <> +rest, S.Out{+r, 0n}}: Equal.sym(PO, fill(rem(S.ObjectSchema{S.Field{k, c, p} <> t, u}, x, S.WFields{S.Once{y} <> rest, S.Out{r, 0n}}), PO{Spec.paths(r), 0n}), PO{Spec.paths(r), 0n}, fill_zero(rem(S.ObjectSchema{S.Field{k, c, p} <> t, u}, x, S.WFields{S.Once{y} <> rest, S.Out{r, 0n}}), Spec.paths(r)))
    case S.ObjectSchema{S.Field{+k, +c, +p} <> +t, +u} +x S.WFields{S.Absent{} <> +rest, S.Out{+r, 0n}}: Equal.sym(PO, fill(rem(S.ObjectSchema{S.Field{k, c, p} <> t, u}, x, S.WFields{S.Absent{} <> rest, S.Out{r, 0n}}), PO{Spec.paths(r), 0n}), PO{Spec.paths(r), 0n}, fill_zero(rem(S.ObjectSchema{S.Field{k, c, p} <> t, u}, x, S.WFields{S.Absent{} <> rest, S.Out{r, 0n}}), Spec.paths(r)))
    case S.ObjectSchema{S.Field{+k, +c, +p} <> +t, +u} +x S.WFields{S.Repeated{+y} <> +rest, S.Out{+r, 0n}}: Equal.sym(PO, fill(rem(S.ObjectSchema{S.Field{k, c, p} <> t, u}, x, S.WFields{S.Repeated{y} <> rest, S.Out{r, 0n}}), PO{Spec.paths(r), 0n}), PO{Spec.paths(r), 0n}, fill_zero(rem(S.ObjectSchema{S.Field{k, c, p} <> t, u}, x, S.WFields{S.Repeated{y} <> rest, S.Out{r, 0n}}), Spec.paths(r)))
    case S.ObjectSchema{S.Field{+k, +c, +p} <> +t, +u} +x S.WFields{Nil{}, S.Out{+r, 1n+(+l)}}: {==}
    case S.ObjectSchema{S.Field{+k, +c, +p} <> +t, +u} +x S.WFields{S.Once{+y} <> +rest, S.Out{+r, 1n+(+l)}}: seq(proj(S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.merge(S.PathKey{k}, S.collect_go(c, y, S.cstart(c, y, 1n+l)), r)})), Spec.under(S.PathKey{k}, Spec.failures(c, y, Spec.Node{})), field_rem(t, rest), PO{Spec.paths(r), 1n+l}, proj(S.merge(S.PathKey{k}, S.collect_go(c, y, S.cstart(c, y, 1n+l)), r)), exact(S.ObjectSchema{t, u}, x, S.WFields{rest, S.merge(S.PathKey{k}, S.collect_go(c, y, S.cstart(c, y, 1n+l)), r)}, SC.rest_valid(k, c, p, t, u, okv)), merge_step(S.PathKey{k}, S.collect_go(c, y, S.cstart(c, y, 1n+l)), r, Spec.failures(c, y, Spec.Node{}), 1n+l, child(c, y, 1n+l, exact(c, y, S.cstart(c, y, 1n+l), SC.field_valid(k, c, p, t, u, okv)))))
    case S.ObjectSchema{S.Field{+k, +c, +p} <> +t, +u} +x S.WFields{S.Absent{} <> +rest, S.Out{+r, 1n+(+l)}}: seq(proj(S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.emit(S.may_be_absent(p), S.Error{S.Constraint{}, "missing required key", [S.PathKey{k}]}, S.Out{r, 1n+l})})), absent_rem(p, k), field_rem(t, rest), PO{Spec.paths(r), 1n+l}, proj(S.emit(S.may_be_absent(p), S.Error{S.Constraint{}, "missing required key", [S.PathKey{k}]}, S.Out{r, 1n+l})), exact(S.ObjectSchema{t, u}, x, S.WFields{rest, S.emit(S.may_be_absent(p), S.Error{S.Constraint{}, "missing required key", [S.PathKey{k}]}, S.Out{r, 1n+l})}, SC.rest_valid(k, c, p, t, u, okv)), absent_fill(p, k, r, l))
    case S.ObjectSchema{S.Field{+k, +c, +p} <> +t, +u} +x S.WFields{S.Repeated{+y} <> +rest, S.Out{+r, 1n+(+l)}}: seq(proj(S.collect_go(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{S.Error{S.Constraint{}, "duplicate key", [S.PathKey{k}]} <> r, l}})), [[S.PathKey{k}]], field_rem(t, rest), PO{Spec.paths(r), 1n+l}, PO{[S.PathKey{k}] <> Spec.paths(r), l}, exact(S.ObjectSchema{t, u}, x, S.WFields{rest, S.Out{S.Error{S.Constraint{}, "duplicate key", [S.PathKey{k}]} <> r, l}}, SC.rest_valid(k, c, p, t, u, okv)), {==})
    case S.NullableSchema{+i} J.JNull{} S.WHere{+l}: {==}
    case S.NullableSchema{+i} J.JNull{} S.WItems{+kk, S.Out{+r, +ll}}: {==}
    case S.NullableSchema{+i} J.JNull{} S.WFields{+ss, S.Out{+r, +ll}}: {==}
    case S.NullableSchema{+i} J.JNull{} S.WDone{S.Out{+r, +ll}}: {==}
    case S.NullableSchema{+i} J.JBool{+b1} S.WHere{+l}: child(i, J.JBool{b1}, l, exact(i, J.JBool{b1}, S.cstart(i, J.JBool{b1}, l), okv))
    case S.NullableSchema{+i} J.JBool{+b1} S.WItems{+kk, S.Out{+r, +ll}}: {==}
    case S.NullableSchema{+i} J.JBool{+b1} S.WFields{+ss, S.Out{+r, +ll}}: {==}
    case S.NullableSchema{+i} J.JBool{+b1} S.WDone{S.Out{+r, +ll}}: {==}
    case S.NullableSchema{+i} J.JNumber{+b1} S.WHere{+l}: child(i, J.JNumber{b1}, l, exact(i, J.JNumber{b1}, S.cstart(i, J.JNumber{b1}, l), okv))
    case S.NullableSchema{+i} J.JNumber{+b1} S.WItems{+kk, S.Out{+r, +ll}}: {==}
    case S.NullableSchema{+i} J.JNumber{+b1} S.WFields{+ss, S.Out{+r, +ll}}: {==}
    case S.NullableSchema{+i} J.JNumber{+b1} S.WDone{S.Out{+r, +ll}}: {==}
    case S.NullableSchema{+i} J.JString{+b1} S.WHere{+l}: child(i, J.JString{b1}, l, exact(i, J.JString{b1}, S.cstart(i, J.JString{b1}, l), okv))
    case S.NullableSchema{+i} J.JString{+b1} S.WItems{+kk, S.Out{+r, +ll}}: {==}
    case S.NullableSchema{+i} J.JString{+b1} S.WFields{+ss, S.Out{+r, +ll}}: {==}
    case S.NullableSchema{+i} J.JString{+b1} S.WDone{S.Out{+r, +ll}}: {==}
    case S.NullableSchema{+i} J.JObject{+b1} S.WHere{+l}: child(i, J.JObject{b1}, l, exact(i, J.JObject{b1}, S.cstart(i, J.JObject{b1}, l), okv))
    case S.NullableSchema{+i} J.JObject{+b1} S.WItems{+kk, S.Out{+r, +ll}}: {==}
    case S.NullableSchema{+i} J.JObject{+b1} S.WFields{+ss, S.Out{+r, +ll}}: {==}
    case S.NullableSchema{+i} J.JObject{+b1} S.WDone{S.Out{+r, +ll}}: {==}
    case S.NullableSchema{+i} J.JArray{Nil{}} S.WHere{+l}: child(i, J.JArray{Nil{}}, l, exact(i, J.JArray{Nil{}}, S.cstart(i, J.JArray{Nil{}}, l), okv))
    case S.NullableSchema{+i} J.JArray{Nil{}} S.WItems{+kk, S.Out{+r, +ll}}: {==}
    case S.NullableSchema{+i} J.JArray{Nil{}} S.WFields{+ss, S.Out{+r, +ll}}: {==}
    case S.NullableSchema{+i} J.JArray{Nil{}} S.WDone{S.Out{+r, +ll}}: {==}
    case S.NullableSchema{+i} J.JArray{+g1 <> +r1} S.WHere{+l}: child(i, J.JArray{g1 <> r1}, l, exact(i, J.JArray{g1 <> r1}, S.cstart(i, J.JArray{g1 <> r1}, l), okv))
    case S.NullableSchema{+i} J.JArray{+g1 <> +r1} S.WItems{+kk, S.Out{+r, +ll}}: {==}
    case S.NullableSchema{+i} J.JArray{+g1 <> +r1} S.WFields{+ss, S.Out{+r, +ll}}: {==}
    case S.NullableSchema{+i} J.JArray{+g1 <> +r1} S.WDone{S.Out{+r, +ll}}: {==}
    case S.UnionSchema{+ms} J.JNull{} S.WHere{+l}: union_exact(ms, J.JNull{}, l, okv)
    case S.UnionSchema{+ms} J.JBool{+b1} S.WHere{+l}: union_exact(ms, J.JBool{b1}, l, okv)
    case S.UnionSchema{+ms} J.JNumber{+b1} S.WHere{+l}: union_exact(ms, J.JNumber{b1}, l, okv)
    case S.UnionSchema{+ms} J.JString{+b1} S.WHere{+l}: union_exact(ms, J.JString{b1}, l, okv)
    case S.UnionSchema{+ms} J.JObject{+b1} S.WHere{+l}: union_exact(ms, J.JObject{b1}, l, okv)
    case S.UnionSchema{+ms} J.JArray{Nil{}} S.WHere{+l}: union_exact(ms, J.JArray{Nil{}}, l, okv)
    case S.UnionSchema{+ms} J.JArray{+g1 <> +r1} S.WHere{+l}: union_exact(ms, J.JArray{g1 <> r1}, l, okv)
    case S.UnionSchema{+ms} +x S.WItems{+kk, S.Out{+r, +ll}}: {==}
    case S.UnionSchema{+ms} +x S.WFields{+ss, S.Out{+r, +ll}}: {==}
    case S.UnionSchema{+ms} +x S.WDone{S.Out{+r, +ll}}: {==}

# The top-level walk fills the whole enumeration into an empty list.
def exact_top(+s: S.Schema, +v: J.Json, +okv: {S.valid(s) == True{} : Bool}) -> {proj(S.collect_go(s, v, S.cstart(s, v, Spec.error_cap()))) == fill(Spec.failures(s, v, Spec.Node{}), PO{[], Spec.error_cap()}) : PO}:
  child(s, v, Spec.error_cap(), exact(s, v, S.cstart(s, v, Spec.error_cap()), okv))

# Reading the list back in order.

def po_rev(o: PO) -> List<&2, List<&2, S.PathPart>>:
  match o:
    case PO{r, l}: r

def fill_first(+f: List<&2, List<&2, S.PathPart>>, +x: List<&2, List<&2, S.PathPart>>, +l: Nat) -> {po_rev(fill(f, PO{x, l})) == List.reverse.go(&2, List<&2, S.PathPart>, Spec.first_paths(f, l), x) : List<&2, List<&2, S.PathPart>>}:
  match f l:
    case Nil{} n: {==}
    case p <> t 0n: {==}
    case p <> t 1n+n: fill_first(t, p <> x, n)

def paths_rev(+es: List<&2, S.Error>, +acc: List<&2, S.Error>) -> {Spec.paths(List.reverse.go(&2, S.Error, es, acc)) == List.reverse.go(&2, List<&2, S.PathPart>, Spec.paths(es), Spec.paths(acc)) : List<&2, List<&2, S.PathPart>>}:
  match es:
    case Nil{}: {==}
    case S.Error{c, m, p} <> t: paths_rev(t, S.Error{c, m, p} <> acc)

def rev_rev(+xs: List<&2, List<&2, S.PathPart>>, +acc: List<&2, List<&2, S.PathPart>>, +ys: List<&2, List<&2, S.PathPart>>) -> {List.reverse.go(&2, List<&2, S.PathPart>, List.reverse.go(&2, List<&2, S.PathPart>, xs, acc), ys) == List.reverse.go(&2, List<&2, S.PathPart>, acc, Spec.join(xs, ys)) : List<&2, List<&2, S.PathPart>>}:
  match xs:
    case Nil{}: {==}
    case p <> t: rev_rev(t, p <> acc, ys)

def join_nil(+xs: List<&2, List<&2, S.PathPart>>) -> {Spec.join(xs, []) == xs : List<&2, List<&2, S.PathPart>>}:
  match xs:
    case Nil{}: {==}
    case p <> t: Equal.cong(List<&2, List<&2, S.PathPart>>, List<&2, List<&2, S.PathPart>>, z => p <> z, Spec.join(t, []), t, join_nil(t))

# The errors a filled walk lists, in order, are the first l of f.
def listed_first(+o: S.Out, +f: List<&2, List<&2, S.PathPart>>, +l: Nat, h: {proj(o) == fill(f, PO{[], l}) : PO}) -> {Spec.paths(S.listed(o)) == Spec.first_paths(f, l) : List<&2, List<&2, S.PathPart>>}:
  match o:
    case S.Out{+r, +n}:
      Equal.trans(List<&2, List<&2, S.PathPart>>, Spec.paths(List.reverse.go(&2, S.Error, r, [])), List.reverse.go(&2, List<&2, S.PathPart>, List.reverse.go(&2, List<&2, S.PathPart>, Spec.first_paths(f, l), []), []), Spec.first_paths(f, l), Equal.trans(List<&2, List<&2, S.PathPart>>, Spec.paths(List.reverse.go(&2, S.Error, r, [])), List.reverse.go(&2, List<&2, S.PathPart>, Spec.paths(r), []), List.reverse.go(&2, List<&2, S.PathPart>, List.reverse.go(&2, List<&2, S.PathPart>, Spec.first_paths(f, l), []), []), paths_rev(r, []), Equal.cong(List<&2, List<&2, S.PathPart>>, List<&2, List<&2, S.PathPart>>, z => List.reverse.go(&2, List<&2, S.PathPart>, z, []), Spec.paths(r), List.reverse.go(&2, List<&2, S.PathPart>, Spec.first_paths(f, l), []), Equal.trans(List<&2, List<&2, S.PathPart>>, Spec.paths(r), po_rev(fill(f, PO{[], l})), List.reverse.go(&2, List<&2, S.PathPart>, Spec.first_paths(f, l), []), Equal.cong(PO, List<&2, List<&2, S.PathPart>>, z => po_rev(z), PO{Spec.paths(r), n}, fill(f, PO{[], l}), h), fill_first(f, [], l)))), Equal.trans(List<&2, List<&2, S.PathPart>>, List.reverse.go(&2, List<&2, S.PathPart>, List.reverse.go(&2, List<&2, S.PathPart>, Spec.first_paths(f, l), []), []), Spec.join(Spec.first_paths(f, l), []), Spec.first_paths(f, l), rev_rev(Spec.first_paths(f, l), [], []), join_nil(Spec.first_paths(f, l))))

# A walk that lists nothing with budget left had nothing to visit.

def po_empty(o: PO) -> Bool:
  match o:
    case PO{Nil{}, l}: True{}
    case PO{p <> r, l}: False{}

def fill_dirty(+f: List<&2, List<&2, S.PathPart>>, +q: List<&2, S.PathPart>, +x: List<&2, List<&2, S.PathPart>>, +l: Nat) -> {po_empty(fill(f, PO{q <> x, l})) == False{} : Bool}:
  match f l:
    case Nil{} n: {==}
    case p <> t 0n: {==}
    case p <> t 1n+n: fill_dirty(t, p, q <> x, n)

def nothing_left(+o: S.Out, +f: List<&2, List<&2, S.PathPart>>, +n: Nat, h: {proj(o) == fill(f, PO{[], 1n+n}) : PO}, hc: {SE.clean(o) == True{} : Bool}) -> {f == [] : List<&2, List<&2, S.PathPart>>}:
  match o f:
    case S.Out{r, l} Nil{}: {==}
    case S.Out{Nil{}, +l} +p <> +t: UP.absurd({p <> t == [] : List<&2, List<&2, S.PathPart>>}, UP.false_true(Equal.sym(Bool, True{}, False{}, Equal.trans(Bool, True{}, po_empty(fill(t, PO{[p], n})), False{}, Equal.cong(PO, Bool, z => po_empty(z), PO{[], l}, fill(t, PO{[p], n}), h), fill_dirty(t, p, [], n)))))
    case S.Out{e <> r, l} +p <> +t: UP.absurd({p <> t == [] : List<&2, List<&2, S.PathPart>>}, UP.false_true(hc))

# The laws.

def schema_true(+s: S.Schema, hb: {S.valid(s) == True{} : Bool}) -> {Spec.schema_ok(s) == True{} : Bool}:
  Equal.trans(Bool, Spec.schema_ok(s), S.valid(s), True{}, Equal.sym(Bool, S.valid(s), Spec.schema_ok(s), SC.valid_equiv(s)), hb)

def schema_false(+s: S.Schema, hb: {S.valid(s) == False{} : Bool}) -> {Spec.schema_ok(s) == False{} : Bool}:
  Equal.trans(Bool, Spec.schema_ok(s), S.valid(s), False{}, Equal.sym(Bool, S.valid(s), Spec.schema_ok(s), SC.valid_equiv(s)), hb)

def ok_paths(+s: S.Schema, +v: J.Json, -a: List<&2, List<&2, S.PathPart>>, hok: {Spec.schema_ok(s) == True{} : Bool}, h: {a == Spec.first_paths(Spec.failures(s, v, Spec.Node{}), Spec.error_cap()) : List<&2, List<&2, S.PathPart>>}) -> {a == Spec.error_paths(s, v) : List<&2, List<&2, S.PathPart>>}:
  Equal.trans(List<&2, List<&2, S.PathPart>>, a, Spec.located_paths(True{}, s, v), Spec.located_paths(Spec.schema_ok(s), s, v), h, Equal.cong(Bool, List<&2, List<&2, S.PathPart>>, z => Spec.located_paths(z, s, v), True{}, Spec.schema_ok(s), Equal.sym(Bool, Spec.schema_ok(s), True{}, hok)))

def fail_exact(+s: S.Schema, +v: J.Json, b: Bool, +hb: {S.valid(s) == b : Bool}) -> {Spec.paths(S.errors(s, v, b)) == Spec.error_paths(s, v) : List<&2, List<&2, S.PathPart>>}:
  match b:
    case False{}: Equal.cong(Bool, List<&2, List<&2, S.PathPart>>, z => Spec.located_paths(z, s, v), False{}, Spec.schema_ok(s), Equal.sym(Bool, Spec.schema_ok(s), False{}, schema_false(s, hb)))
    case True{}: ok_paths(s, v, Spec.paths(S.collect(s, v)), schema_true(s, hb), listed_first(S.collect_go(s, v, S.cstart(s, v, Spec.error_cap())), Spec.failures(s, v, Spec.Node{}), Spec.error_cap(), exact_top(s, v, hb)))

def accepted_exact(+s: S.Schema, +v: J.Json, +hs: {Spec.satisfies(s, v) == True{} : Bool}) -> {[] == Spec.error_paths(s, v) : List<&2, List<&2, S.PathPart>>}:
  ok_paths(s, v, [], UP.and_left(Spec.schema_ok(s), Spec.meets(s, Spec.Holds{}, v), hs), Equal.cong(List<&2, List<&2, S.PathPart>>, List<&2, List<&2, S.PathPart>>, z => Spec.first_paths(z, Spec.error_cap()), [], Spec.failures(s, v, Spec.Node{}), Equal.sym(List<&2, List<&2, S.PathPart>>, Spec.failures(s, v, Spec.Node{}), [], nothing_left(S.collect_go(s, v, S.cstart(s, v, Spec.error_cap())), Spec.failures(s, v, Spec.Node{}), 99n, exact_top(s, v, Equal.trans(Bool, S.valid(s), Spec.schema_ok(s), True{}, SC.valid_equiv(s), UP.and_left(Spec.schema_ok(s), Spec.meets(s, Spec.Holds{}, v), hs))), Equal.trans(Bool, SE.clean(S.collect_go(s, v, S.cstart(s, v, Spec.error_cap()))), Spec.meets(s, Spec.Holds{}, v), True{}, SE.top_clean(s, v, Equal.trans(Bool, S.valid(s), Spec.schema_ok(s), True{}, SC.valid_equiv(s), UP.and_left(Spec.schema_ok(s), Spec.meets(s, Spec.Holds{}, v), hs))), UP.and_right(Spec.schema_ok(s), Spec.meets(s, Spec.Holds{}, v), hs))))))

def exact_go(+s: S.Schema, +v: J.Json, r: Result<&2, &2, S.Errors(), S.Value>, ha: {S.accepted(r) == Spec.satisfies(s, v) : Bool}) -> {Spec.listed_paths(S.report(r, s, v)) == Spec.error_paths(s, v) : List<&2, List<&2, S.PathPart>>}:
  match r:
    case Done{x}: accepted_exact(s, v, Equal.sym(Bool, True{}, Spec.satisfies(s, v), ha))
    case Fail{e}: fail_exact(s, v, S.valid(s), {==})

# BND-89 law: the decoder lists exactly the specification's paths.
def errors_exact(+s: S.Schema, +v: J.Json) -> {Spec.listed_paths(S.decode(s, v)) == Spec.error_paths(s, v) : List<&2, List<&2, S.PathPart>>}:
  exact_go(s, v, S.decode_first(s, v), SC.first_spec(s, v))

def coerced_exact(+s: S.Schema, +v: J.Json) -> {Spec.listed_paths(S.decode_from(S.TextSource{}, s, v)) == Spec.error_paths(s, Spec.coerce_text(s, v)) : List<&2, List<&2, S.PathPart>>}:
  Equal.trans(List<&2, List<&2, S.PathPart>>, Spec.listed_paths(S.decode_from(S.TextSource{}, s, v)), Spec.listed_paths(S.decode(s, Spec.coerce_text(s, v))), Spec.error_paths(s, Spec.coerce_text(s, v)), Equal.cong(Result<&2, &2, S.Errors(), S.Value>, List<&2, List<&2, S.PathPart>>, z => Spec.listed_paths(z), S.decode_from(S.TextSource{}, s, v), S.decode(s, Spec.coerce_text(s, v)), SCo.text_spec(s, v)), errors_exact(s, Spec.coerce_text(s, v)))

def invalid_go(+s: S.Schema, +v: J.Json, b: Bool, +hb: {S.valid(s) == b : Bool}, hf: {b == False{} : Bool}) -> {S.report(S.decode_valid(s, v, b), s, v) == Fail{[S.Error{S.InvalidSchema{}, "invalid schema", []}]} : Result<&2, &2, S.Errors(), S.Value>}:
  match b:
    case True{}: UP.absurd({S.report(S.decode_valid(s, v, True{}), s, v) == Fail{[S.Error{S.InvalidSchema{}, "invalid schema", []}]} : Result<&2, &2, S.Errors(), S.Value>}, UP.false_true(Equal.sym(Bool, True{}, False{}, hf)))
    case False{}: Equal.cong(Bool, Result<&2, &2, S.Errors(), S.Value>, z => Fail{S.errors(s, v, z)}, S.valid(s), False{}, hb)

# BND-89 law: an invalid schema is one error at the root, whatever the value.
def invalid_root(+s: S.Schema, +v: J.Json, h: {Spec.schema_ok(s) == False{} : Bool}) -> {S.decode(s, v) == Fail{[S.Error{S.InvalidSchema{}, "invalid schema", []}]} : Result<&2, &2, S.Errors(), S.Value>}:
  invalid_go(s, v, S.valid(s), {==}, Equal.trans(Bool, S.valid(s), Spec.schema_ok(s), False{}, SC.valid_equiv(s), h))

def coerced_invalid_root(+s: S.Schema, +v: J.Json, h: {Spec.schema_ok(s) == False{} : Bool}) -> {S.decode_from(S.TextSource{}, s, v) == Fail{[S.Error{S.InvalidSchema{}, "invalid schema", []}]} : Result<&2, &2, S.Errors(), S.Value>}:
  invalid_root(s, S.coerce(s, v), h)
