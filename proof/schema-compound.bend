# BND-34: compound decoding agrees with the independent specification.
import Base
import ../src/data/schema.bend as S
import ../src/data/json.bend as J
import ../src/data/schema-spec.bend as Spec
import ./schema.bend as SP
import ./chunked-arith.bend as A
import ./utf8.bend as UP
import ./schema-text.bend as TP

# Boolean and list steps.

def and_head(-lhs: Bool, -p: Bool, -q: Bool, -r: Bool, ih: {lhs == (p && r) : Bool}, pq: {p == q : Bool}) -> {lhs == (q && r) : Bool}:
  %pq : {lhs == (_ && r) : Bool}
  ih

def or_head(-lhs: Bool, -p: Bool, -q: Bool, -r: Bool, ih: {lhs == (p || r) : Bool}, pq: {p == q : Bool}) -> {lhs == (q || r) : Bool}:
  %pq : {lhs == (_ || r) : Bool}
  ih

def le_zero(+n: Nat) -> {Nat.is_le(n, 0n) == Nat.is_eq(n, 0n) : Bool}:
  match n:
    case 0n: {==}
    case 1n+m: {==}

def count_go(+xs: List<&2, J.Json>, +n: Nat) -> {S.count(xs, n) == Nat.add(Spec.size(xs), n) : Nat}:
  match xs:
    case Nil{}: {==}
    case h <> t:
      %A.add_succ_r(Spec.size(t), n) : {S.count(t, 1n+n) == _ : Nat}
      count_go(t, 1n+n)

def count_equiv(+xs: List<&2, J.Json>) -> {S.count(xs, 0n) == Spec.size(xs) : Nat}:
  %A.add_zero_r(Spec.size(xs)) : {S.count(xs, 0n) == _ : Nat}
  count_go(xs, 0n)

# The specification's list modes, unfolded for a schema that is a variable.
def each_nil(+i: S.Schema, +a: Spec.Ask) -> {True{} == Spec.meets(i, Spec.EveryItem{a}, J.JArray{[]}) : Bool}:
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
    case S.UnionSchema{Nil{}}: {==}
    case S.UnionSchema{a1 <> a2}: {==}
def each_cons(+i: S.Schema, +a: Spec.Ask, +h: J.Json, +t: List<&2, J.Json>) -> {(Spec.meets(i, a, h) && Spec.meets(i, Spec.EveryItem{a}, J.JArray{t})) == Spec.meets(i, Spec.EveryItem{a}, J.JArray{h <> t}) : Bool}:
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
    case S.UnionSchema{Nil{}}: {==}
    case S.UnionSchema{a1 <> a2}: {==}
def named_nil(+c: S.Schema, +k: String, +a: Spec.Ask) -> {True{} == Spec.meets(c, Spec.EveryNamed{k, a}, J.JObject{[]}) : Bool}:
  match c:
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
    case S.UnionSchema{Nil{}}: {==}
    case S.UnionSchema{a1 <> a2}: {==}
def named_cons(+c: S.Schema, +k: String, +a: Spec.Ask, +key: String, +x: J.Json, +t: List<&2, J.Field>) -> {((Bool.not(String.eq(key, k)) || Spec.meets(c, a, x)) && Spec.meets(c, Spec.EveryNamed{k, a}, J.JObject{t})) == Spec.meets(c, Spec.EveryNamed{k, a}, J.JObject{J.Field{key, x} <> t}) : Bool}:
  match c:
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
    case S.UnionSchema{Nil{}}: {==}
    case S.UnionSchema{a1 <> a2}: {==}
# Results and gates.

def ok(-X: Data, r: Result<&2, &2, List<&2, S.Error>, X>) -> Bool:
  match r:
    case Fail{e}: False{}
    case Done{x}: True{}

def push_ok(+rev: List<&2, S.Value>, +part: S.PathPart, +r: Result<&2, &2, S.Errors(), S.Value>) -> {ok(List<&2, S.Value>, S.push(rev, S.at(part, r))) == S.accepted(r) : Bool}:
  match r:
    case Fail{e}: {==}
    case Done{x}: {==}

def push_field_ok(+rev: List<&2, S.VField>, +k: String, +part: S.PathPart, +r: Result<&2, &2, S.Errors(), S.Value>) -> {ok(List<&2, S.VField>, S.push_field(rev, k, S.at(part, r))) == S.accepted(r) : Bool}:
  match r:
    case Fail{e}: {==}
    case Done{x}: {==}

def items_gate_ok(+b: Bool) -> {ok(List<&2, S.Value>, S.items_gate(b)) == b : Bool}:
  match b:
    case True{}: {==}
    case False{}: {==}

def fields_gate_ok(+b: Bool) -> {ok(List<&2, S.VField>, S.fields_gate(b)) == b : Bool}:
  match b:
    case True{}: {==}
    case False{}: {==}

def absent_ok(p: S.Presence) -> Bool:
  match p:
    case S.Required{}: False{}
    case S.Optional{}: True{}
    case S.Default{d}: True{}

def absent_eq(+rev: List<&2, S.VField>, +k: String, +c: S.Schema, +p: S.Presence, okd: {S.default_ok(c, p) == True{} : Bool}) -> {ok(List<&2, S.VField>, S.absent(rev, k, p, S.at(S.PathKey{k}, S.decode_go(c, S.default_of(p), S.start(c, S.default_of(p)))))) == absent_ok(p) : Bool}:
  match p:
    case S.Required{}: {==}
    case S.Optional{}: {==}
    case S.Default{d}: Equal.trans(Bool, ok(List<&2, S.VField>, S.push_field(rev, k, S.at(S.PathKey{k}, S.decode_go(c, d, S.start(c, d))))), S.accepted(S.decode_go(c, d, S.start(c, d))), True{}, push_field_ok(rev, k, S.PathKey{k}, S.decode_go(c, d, S.start(c, d))), okd)

# What an object's precomputed member slots promise about its declared fields.

def slot_meets(c: S.Schema, p: S.Presence, slot: S.Slot) -> Bool:
  match slot:
    case S.Absent{}: absent_ok(p)
    case S.Once{y}: Spec.meets(c, Spec.Holds{}, y)
    case S.Repeated{y}: False{}

def slots_meet(fs: List<&2, S.Field>, ss: List<&2, S.Slot>) -> Bool:
  match fs ss:
    case Nil{} _: True{}
    case S.Field{k, c, p} <> t x <> rest: slot_meets(c, p, x) && slots_meet(t, rest)
    case S.Field{k, c, p} <> t Nil{}: False{}

def every(c: S.Schema, k: String, input: List<&2, J.Field>) -> Bool:
  Spec.meets(c, Spec.EveryNamed{k, Spec.Holds{}}, J.JObject{input})

def find_claim(+c: S.Schema, +p: S.Presence, +k: String, +input: List<&2, J.Field>, acc: S.Slot) -> Bool:
  match acc:
    case S.Absent{}: Spec.presence(p, Spec.named(input, k)) && every(c, k, input)
    case S.Once{y}: (Nat.is_eq(Spec.named(input, k), 0n) && Spec.meets(c, Spec.Holds{}, y)) && every(c, k, input)
    case S.Repeated{y}: False{}

def absent_nil(+p: S.Presence) -> {absent_ok(p) == (Spec.presence(p, 0n) && True{}) : Bool}:
  match p:
    case S.Required{}: {==}
    case S.Optional{}: {==}
    case S.Default{d}: {==}

def step_absent(+c: S.Schema, +k: String, +key: String, +y: J.Json, +t: List<&2, J.Field>, b: Bool, +p: S.Presence) -> {slot_meets(c, p, S.find(t, k, S.found(b, S.Absent{}, y))) == find_claim(c, p, k, t, S.found(b, S.Absent{}, y)) : Bool} -> {slot_meets(c, p, S.find(t, k, S.found(b, S.Absent{}, y))) == (Spec.presence(p, Spec.bump(b, Spec.named(t, k))) && ((Bool.not(b) || Spec.meets(c, Spec.Holds{}, y)) && every(c, k, t))) : Bool}:
  match b p:
    case False{} q: ih => ih
    case True{} S.Required{}: ih => Equal.trans(Bool, slot_meets(c, S.Required{}, S.find(t, k, S.Once{y})), ((Nat.is_eq(Spec.named(t, k), 0n) && Spec.meets(c, Spec.Holds{}, y)) && every(c, k, t)), (Nat.is_eq(Spec.named(t, k), 0n) && (Spec.meets(c, Spec.Holds{}, y) && every(c, k, t))), ih, SP.and_assoc(Nat.is_eq(Spec.named(t, k), 0n), Spec.meets(c, Spec.Holds{}, y), every(c, k, t)))
    case True{} S.Optional{}: ih =>
      %Equal.sym(Bool, Nat.is_le(Spec.named(t, k), 0n), Nat.is_eq(Spec.named(t, k), 0n), le_zero(Spec.named(t, k))) : {slot_meets(c, S.Optional{}, S.find(t, k, S.Once{y})) == (_ && (Spec.meets(c, Spec.Holds{}, y) && every(c, k, t))) : Bool}
      Equal.trans(Bool, slot_meets(c, S.Optional{}, S.find(t, k, S.Once{y})), ((Nat.is_eq(Spec.named(t, k), 0n) && Spec.meets(c, Spec.Holds{}, y)) && every(c, k, t)), (Nat.is_eq(Spec.named(t, k), 0n) && (Spec.meets(c, Spec.Holds{}, y) && every(c, k, t))), ih, SP.and_assoc(Nat.is_eq(Spec.named(t, k), 0n), Spec.meets(c, Spec.Holds{}, y), every(c, k, t)))
    case True{} S.Default{d}: ih =>
      %Equal.sym(Bool, Nat.is_le(Spec.named(t, k), 0n), Nat.is_eq(Spec.named(t, k), 0n), le_zero(Spec.named(t, k))) : {slot_meets(c, S.Default{d}, S.find(t, k, S.Once{y})) == (_ && (Spec.meets(c, Spec.Holds{}, y) && every(c, k, t))) : Bool}
      Equal.trans(Bool, slot_meets(c, S.Default{d}, S.find(t, k, S.Once{y})), ((Nat.is_eq(Spec.named(t, k), 0n) && Spec.meets(c, Spec.Holds{}, y)) && every(c, k, t)), (Nat.is_eq(Spec.named(t, k), 0n) && (Spec.meets(c, Spec.Holds{}, y) && every(c, k, t))), ih, SP.and_assoc(Nat.is_eq(Spec.named(t, k), 0n), Spec.meets(c, Spec.Holds{}, y), every(c, k, t)))

def step_once(+c: S.Schema, +p: S.Presence, +k: String, +key: String, +y: J.Json, +z: J.Json, +t: List<&2, J.Field>, b: Bool) -> {slot_meets(c, p, S.find(t, k, S.found(b, S.Once{z}, y))) == find_claim(c, p, k, t, S.found(b, S.Once{z}, y)) : Bool} -> {slot_meets(c, p, S.find(t, k, S.found(b, S.Once{z}, y))) == ((Nat.is_eq(Spec.bump(b, Spec.named(t, k)), 0n) && Spec.meets(c, Spec.Holds{}, z)) && ((Bool.not(b) || Spec.meets(c, Spec.Holds{}, y)) && every(c, k, t))) : Bool}:
  match b:
    case False{}: ih => ih
    case True{}: ih => ih

def find_go(+c: S.Schema, +p: S.Presence, +k: String, +input: List<&2, J.Field>, +acc: S.Slot) -> {slot_meets(c, p, S.find(input, k, acc)) == find_claim(c, p, k, input, acc) : Bool}:
  match input acc:
    case x S.Repeated{y}: {==}
    case Nil{} S.Absent{}:
      %named_nil(c, k, Spec.Holds{}) : {slot_meets(c, p, S.Absent{}) == (Spec.presence(p, 0n) && _) : Bool}
      absent_nil(p)
    case Nil{} S.Once{y}:
      %named_nil(c, k, Spec.Holds{}) : {slot_meets(c, p, S.Once{y}) == (Spec.meets(c, Spec.Holds{}, y) && _) : Bool}
      SP.and_true(Spec.meets(c, Spec.Holds{}, y))
    case J.Field{key, y} <> t S.Absent{}:
      %named_cons(c, k, Spec.Holds{}, key, y, t) : {slot_meets(c, p, S.find(J.Field{key, y} <> t, k, S.Absent{})) == (Spec.presence(p, Spec.named(J.Field{key, y} <> t, k)) && _) : Bool}
      step_absent(c, k, key, y, t, String.eq(key, k), p)(find_go(c, p, k, t, S.found(String.eq(key, k), S.Absent{}, y)))
    case J.Field{key, y} <> t S.Once{z}:
      %named_cons(c, k, Spec.Holds{}, key, y, t) : {slot_meets(c, p, S.find(J.Field{key, y} <> t, k, S.Once{z})) == ((Nat.is_eq(Spec.named(J.Field{key, y} <> t, k), 0n) && Spec.meets(c, Spec.Holds{}, z)) && _) : Bool}
      step_once(c, p, k, key, y, z, t, String.eq(key, k))(find_go(c, p, k, t, S.found(String.eq(key, k), S.Once{z}, y)))

def find_meets(+c: S.Schema, +p: S.Presence, +k: String, +input: List<&2, J.Field>) -> {slot_meets(c, p, S.find(input, k, S.Absent{})) == (Spec.presence(p, Spec.named(input, k)) && every(c, k, input)) : Bool}:
  find_go(c, p, k, input, S.Absent{})

def fields_meet(+fs: List<&2, S.Field>, +u: S.Unknown, +input: List<&2, J.Field>) -> {slots_meet(fs, S.slots(fs, input)) == Spec.meets(S.ObjectSchema{fs, u}, Spec.EveryField{}, J.JObject{input}) : Bool}:
  match fs:
    case Nil{}: {==}
    case S.Field{k, c, p} <> t:
      %find_meets(c, p, k, input) : {slots_meet(S.Field{k, c, p} <> t, S.slots(S.Field{k, c, p} <> t, input)) == (_ && Spec.meets(S.ObjectSchema{t, u}, Spec.EveryField{}, J.JObject{input})) : Bool}
      %fields_meet(t, u, input) : {slots_meet(S.Field{k, c, p} <> t, S.slots(S.Field{k, c, p} <> t, input)) == (slot_meets(c, p, S.find(input, k, S.Absent{})) && _) : Bool}
      {==}

def known_go_eq(+input: List<&2, J.Field>, +fs: List<&2, S.Field>, +b: Bool) -> {S.known_go(input, fs, b) == (b && Spec.all_declared(input, fs)) : Bool}:
  match input b:
    case Nil{} False{}: {==}
    case Nil{} True{}: {==}
    case J.Field{k, v} <> t False{}: {==}
    case J.Field{k, v} <> t True{}:
      %SP.declared_equiv(fs, k) : {S.known_go(J.Field{k, v} <> t, fs, True{}) == (_ && Spec.all_declared(t, fs)) : Bool}
      known_go_eq(t, fs, S.declared(fs, k))

def known_equiv(+u: S.Unknown, +fs: List<&2, S.Field>, +input: List<&2, J.Field>) -> {S.known(u, fs, input) == Spec.allowed(u, fs, input) : Bool}:
  match u:
    case S.Strict{}: known_go_eq(input, fs, True{})
    case S.Strip{}: {==}

# What a decoding state still promises: its result so far, then the rest.
def expect(s: S.Schema, acc: S.Acc, v: J.Json) -> Bool:
  match s acc v:
    case S.StringSchema{a, b, c, d} _ x: Spec.accepts(S.StringSchema{a, b, c, d}, x)
    case S.NumberSchema{a, b} _ x: Spec.accepts(S.NumberSchema{a, b}, x)
    case S.IntegerSchema{a, b} _ x: Spec.accepts(S.IntegerSchema{a, b}, x)
    case S.BooleanSchema{} _ x: Spec.accepts(S.BooleanSchema{}, x)
    case S.LiteralSchema{a} _ x: Spec.accepts(S.LiteralSchema{a}, x)
    case S.EnumSchema{a} _ x: Spec.accepts(S.EnumSchema{a}, x)
    case S.ArraySchema{i, m, n} S.AItems{k, st} J.JArray{xs}: ok(List<&2, S.Value>, st) && Spec.meets(i, Spec.EveryItem{Spec.Holds{}}, J.JArray{xs})
    case S.ObjectSchema{fs, u} S.AFields{st, ss} x: ok(List<&2, S.VField>, st) && slots_meet(fs, ss)
    case S.NullableSchema{i} _ x: Spec.meets(S.NullableSchema{i}, Spec.Holds{}, x)
    case S.UnionSchema{ms} S.AMembers{n, i, st} x: S.accepted(st) || Spec.meets(S.UnionSchema{ms}, Spec.Holds{}, x)
    case _ _ _: False{}

def entry(+s: S.Schema, +v: J.Json) -> {expect(s, S.start(s, v), v) == Spec.meets(s, Spec.Holds{}, v) : Bool}:
  match s v:
    case S.StringSchema{a, b, c, d} x: {==}
    case S.NumberSchema{a, b} x: {==}
    case S.IntegerSchema{a, b} x: {==}
    case S.BooleanSchema{} x: {==}
    case S.LiteralSchema{a} x: {==}
    case S.EnumSchema{a} x: {==}
    case S.ArraySchema{i, m, n} J.JArray{xs}:
      %count_equiv(xs) : {expect(S.ArraySchema{i, m, n}, S.start(S.ArraySchema{i, m, n}, J.JArray{xs}), J.JArray{xs}) == (Nat.is_le(m, _) && Spec.at_most(n, _) && Spec.meets(i, Spec.EveryItem{Spec.Holds{}}, J.JArray{xs})) : Bool}
      %SP.max_equiv(n, S.count(xs, 0n)) : {expect(S.ArraySchema{i, m, n}, S.start(S.ArraySchema{i, m, n}, J.JArray{xs}), J.JArray{xs}) == (Nat.is_le(m, S.count(xs, 0n)) && _ && Spec.meets(i, Spec.EveryItem{Spec.Holds{}}, J.JArray{xs})) : Bool}
      %items_gate_ok(S.item_count(m, n, S.count(xs, 0n))) : {expect(S.ArraySchema{i, m, n}, S.start(S.ArraySchema{i, m, n}, J.JArray{xs}), J.JArray{xs}) == (_ && Spec.meets(i, Spec.EveryItem{Spec.Holds{}}, J.JArray{xs})) : Bool}
      {==}
    case S.ArraySchema{i, m, n} J.JNull{}: {==}
    case S.ArraySchema{i, m, n} J.JBool{b}: {==}
    case S.ArraySchema{i, m, n} J.JNumber{b}: {==}
    case S.ArraySchema{i, m, n} J.JString{b}: {==}
    case S.ArraySchema{i, m, n} J.JObject{b}: {==}
    case S.ObjectSchema{Nil{}, u} J.JObject{input}:
      %known_equiv(u, [], input) : {expect(S.ObjectSchema{[], u}, S.start(S.ObjectSchema{[], u}, J.JObject{input}), J.JObject{input}) == _ : Bool}
      %fields_gate_ok(S.known(u, [], input)) : {expect(S.ObjectSchema{[], u}, S.start(S.ObjectSchema{[], u}, J.JObject{input}), J.JObject{input}) == _ : Bool}
      Equal.sym(Bool, ok(List<&2, S.VField>, S.fields_gate(S.known(u, [], input))), (ok(List<&2, S.VField>, S.fields_gate(S.known(u, [], input))) && True{}), SP.and_true(ok(List<&2, S.VField>, S.fields_gate(S.known(u, [], input)))))
    case S.ObjectSchema{S.Field{k, c, p} <> t, u} J.JObject{input}:
      %known_equiv(u, S.Field{k, c, p} <> t, input) : {expect(S.ObjectSchema{S.Field{k, c, p} <> t, u}, S.start(S.ObjectSchema{S.Field{k, c, p} <> t, u}, J.JObject{input}), J.JObject{input}) == (_ && (Spec.presence(p, Spec.named(input, k)) && every(c, k, input) && Spec.meets(S.ObjectSchema{t, u}, Spec.EveryField{}, J.JObject{input}))) : Bool}
      %fields_gate_ok(S.known(u, S.Field{k, c, p} <> t, input)) : {expect(S.ObjectSchema{S.Field{k, c, p} <> t, u}, S.start(S.ObjectSchema{S.Field{k, c, p} <> t, u}, J.JObject{input}), J.JObject{input}) == (_ && (Spec.presence(p, Spec.named(input, k)) && every(c, k, input) && Spec.meets(S.ObjectSchema{t, u}, Spec.EveryField{}, J.JObject{input}))) : Bool}
      %find_meets(c, p, k, input) : {expect(S.ObjectSchema{S.Field{k, c, p} <> t, u}, S.start(S.ObjectSchema{S.Field{k, c, p} <> t, u}, J.JObject{input}), J.JObject{input}) == (ok(List<&2, S.VField>, S.fields_gate(S.known(u, S.Field{k, c, p} <> t, input))) && (_ && Spec.meets(S.ObjectSchema{t, u}, Spec.EveryField{}, J.JObject{input}))) : Bool}
      %fields_meet(t, u, input) : {expect(S.ObjectSchema{S.Field{k, c, p} <> t, u}, S.start(S.ObjectSchema{S.Field{k, c, p} <> t, u}, J.JObject{input}), J.JObject{input}) == (ok(List<&2, S.VField>, S.fields_gate(S.known(u, S.Field{k, c, p} <> t, input))) && (slot_meets(c, p, S.find(input, k, S.Absent{})) && _)) : Bool}
      {==}
    case S.ObjectSchema{fs, u} J.JNull{}: {==}
    case S.ObjectSchema{fs, u} J.JBool{b}: {==}
    case S.ObjectSchema{fs, u} J.JNumber{b}: {==}
    case S.ObjectSchema{fs, u} J.JString{b}: {==}
    case S.ObjectSchema{fs, u} J.JArray{b}: {==}
    case S.NullableSchema{i} x: {==}
    case S.UnionSchema{ms} x: {==}

# Validity of a parent gives validity of each child.

def item_valid(+i: S.Schema, +m: Nat, +n: Maybe<&2, Nat>, okv: {S.valid(S.ArraySchema{i, m, n}) == True{} : Bool}) -> {S.valid(i) == True{} : Bool}:
  UP.and_right(S.max_length(n, m), S.valid(i), okv)

def field_valid(+k: String, +c: S.Schema, +p: S.Presence, +t: List<&2, S.Field>, +u: S.Unknown, okv: {S.valid(S.ObjectSchema{S.Field{k, c, p} <> t, u}) == True{} : Bool}) -> {S.valid(c) == True{} : Bool}:
  UP.and_right(J.scalars(k) && Bool.not(S.declared(t, k)), S.valid(c), UP.and_left(J.scalars(k) && Bool.not(S.declared(t, k)) && S.valid(c), S.default_ok(c, p), UP.and_left(J.scalars(k) && Bool.not(S.declared(t, k)) && S.valid(c) && S.default_ok(c, p), S.valid(S.ObjectSchema{t, u}), okv)))

def default_valid(+k: String, +c: S.Schema, +p: S.Presence, +t: List<&2, S.Field>, +u: S.Unknown, okv: {S.valid(S.ObjectSchema{S.Field{k, c, p} <> t, u}) == True{} : Bool}) -> {S.default_ok(c, p) == True{} : Bool}:
  UP.and_right(J.scalars(k) && Bool.not(S.declared(t, k)) && S.valid(c), S.default_ok(c, p), UP.and_left(J.scalars(k) && Bool.not(S.declared(t, k)) && S.valid(c) && S.default_ok(c, p), S.valid(S.ObjectSchema{t, u}), okv))

def rest_valid(+k: String, +c: S.Schema, +p: S.Presence, +t: List<&2, S.Field>, +u: S.Unknown, okv: {S.valid(S.ObjectSchema{S.Field{k, c, p} <> t, u}) == True{} : Bool}) -> {S.valid(S.ObjectSchema{t, u}) == True{} : Bool}:
  UP.and_right(J.scalars(k) && Bool.not(S.declared(t, k)) && S.valid(c) && S.default_ok(c, p), S.valid(S.ObjectSchema{t, u}), okv)

def member_valid(+m: S.Schema, +t: List<&2, S.Schema>, okv: {S.valid(S.UnionSchema{m <> t}) == True{} : Bool}) -> {S.valid(m) == True{} : Bool}:
  UP.and_left(S.valid(m), S.valid(S.UnionSchema{t}), okv)

def members_valid(+m: S.Schema, +t: List<&2, S.Schema>, okv: {S.valid(S.UnionSchema{m <> t}) == True{} : Bool}) -> {S.valid(S.UnionSchema{t}) == True{} : Bool}:
  UP.and_right(S.valid(m), S.valid(S.UnionSchema{t}), okv)

def child(+s: S.Schema, +v: J.Json, ih: {S.accepted(S.decode_go(s, v, S.start(s, v))) == expect(s, S.start(s, v), v) : Bool}) -> {S.accepted(S.decode_go(s, v, S.start(s, v))) == Spec.meets(s, Spec.Holds{}, v) : Bool}:
  Equal.trans(Bool, S.accepted(S.decode_go(s, v, S.start(s, v))), expect(s, S.start(s, v), v), Spec.meets(s, Spec.Holds{}, v), ih, entry(s, v))

# Every decoding state reaches acceptance exactly when its promise holds.
def agree(+s: S.Schema, +v: J.Json, +acc: S.Acc, +okv: {S.valid(s) == True{} : Bool}) -> {S.accepted(S.decode_go(s, v, acc)) == expect(s, acc, v) : Bool}:
  match s v acc:
    case S.StringSchema{a, b, c, d} x y: SP.accepts_equiv(S.StringSchema{a, b, c, d}, x, okv)
    case S.NumberSchema{a, b} x y: SP.accepts_equiv(S.NumberSchema{a, b}, x, okv)
    case S.IntegerSchema{a, b} x y: SP.accepts_equiv(S.IntegerSchema{a, b}, x, okv)
    case S.BooleanSchema{} x y: SP.accepts_equiv(S.BooleanSchema{}, x, okv)
    case S.LiteralSchema{a} x y: SP.accepts_equiv(S.LiteralSchema{a}, x, okv)
    case S.EnumSchema{a} x y: SP.accepts_equiv(S.EnumSchema{a}, x, okv)
    case S.ArraySchema{i, m, n} J.JNull{} S.AItems{k, Fail{e}}: {==}
    case S.ArraySchema{i, m, n} J.JBool{b0} S.AItems{k, Fail{e}}: {==}
    case S.ArraySchema{i, m, n} J.JNumber{b0} S.AItems{k, Fail{e}}: {==}
    case S.ArraySchema{i, m, n} J.JString{b0} S.AItems{k, Fail{e}}: {==}
    case S.ArraySchema{i, m, n} J.JObject{b0} S.AItems{k, Fail{e}}: {==}
    case S.ArraySchema{i, m, n} J.JArray{Nil{}} S.AItems{k, Fail{e}}: {==}
    case S.ArraySchema{i, m, n} J.JArray{h0 <> t0} S.AItems{k, Fail{e}}: {==}
    case S.ArraySchema{i, m, n} J.JArray{Nil{}} S.AItems{k, Done{rev}}: each_nil(i, Spec.Holds{})
    case S.ArraySchema{i, m, n} J.JArray{h <> t} S.AItems{k, Done{rev}}:
      %each_cons(i, Spec.Holds{}, h, t) : {S.accepted(S.decode_go(S.ArraySchema{i, m, n}, J.JArray{h <> t}, S.AItems{k, Done{rev}})) == _ : Bool}
      and_head(S.accepted(S.decode_go(S.ArraySchema{i, m, n}, J.JArray{h <> t}, S.AItems{k, Done{rev}})), ok(List<&2, S.Value>, S.push(rev, S.at(S.PathIndex{k}, S.decode_go(i, h, S.start(i, h))))), Spec.meets(i, Spec.Holds{}, h), Spec.meets(i, Spec.EveryItem{Spec.Holds{}}, J.JArray{t}), agree(S.ArraySchema{i, m, n}, J.JArray{t}, S.AItems{1n+k, S.push(rev, S.at(S.PathIndex{k}, S.decode_go(i, h, S.start(i, h))))}, okv), Equal.trans(Bool, ok(List<&2, S.Value>, S.push(rev, S.at(S.PathIndex{k}, S.decode_go(i, h, S.start(i, h))))), S.accepted(S.decode_go(i, h, S.start(i, h))), Spec.meets(i, Spec.Holds{}, h), push_ok(rev, S.PathIndex{k}, S.decode_go(i, h, S.start(i, h))), child(i, h, agree(i, h, S.start(i, h), item_valid(i, m, n, okv)))))
    case S.ArraySchema{i, m, n} J.JNull{} S.AItems{k, Done{rev}}: {==}
    case S.ArraySchema{i, m, n} J.JBool{b0} S.AItems{k, Done{rev}}: {==}
    case S.ArraySchema{i, m, n} J.JNumber{b0} S.AItems{k, Done{rev}}: {==}
    case S.ArraySchema{i, m, n} J.JString{b0} S.AItems{k, Done{rev}}: {==}
    case S.ArraySchema{i, m, n} J.JObject{b0} S.AItems{k, Done{rev}}: {==}
    case S.ArraySchema{i, m, n} J.JNull{} S.AScalar{}: {==}
    case S.ArraySchema{i, m, n} J.JBool{b0} S.AScalar{}: {==}
    case S.ArraySchema{i, m, n} J.JNumber{b0} S.AScalar{}: {==}
    case S.ArraySchema{i, m, n} J.JString{b0} S.AScalar{}: {==}
    case S.ArraySchema{i, m, n} J.JObject{b0} S.AScalar{}: {==}
    case S.ArraySchema{i, m, n} J.JArray{Nil{}} S.AScalar{}: {==}
    case S.ArraySchema{i, m, n} J.JArray{h0 <> t0} S.AScalar{}: {==}
    case S.ArraySchema{i, m, n} J.JNull{} S.AFields{st, ss}: {==}
    case S.ArraySchema{i, m, n} J.JBool{b0} S.AFields{st, ss}: {==}
    case S.ArraySchema{i, m, n} J.JNumber{b0} S.AFields{st, ss}: {==}
    case S.ArraySchema{i, m, n} J.JString{b0} S.AFields{st, ss}: {==}
    case S.ArraySchema{i, m, n} J.JObject{b0} S.AFields{st, ss}: {==}
    case S.ArraySchema{i, m, n} J.JArray{Nil{}} S.AFields{st, ss}: {==}
    case S.ArraySchema{i, m, n} J.JArray{h0 <> t0} S.AFields{st, ss}: {==}
    case S.ArraySchema{i, m, n} J.JNull{} S.AMembers{a, b, st}: {==}
    case S.ArraySchema{i, m, n} J.JBool{b0} S.AMembers{a, b, st}: {==}
    case S.ArraySchema{i, m, n} J.JNumber{b0} S.AMembers{a, b, st}: {==}
    case S.ArraySchema{i, m, n} J.JString{b0} S.AMembers{a, b, st}: {==}
    case S.ArraySchema{i, m, n} J.JObject{b0} S.AMembers{a, b, st}: {==}
    case S.ArraySchema{i, m, n} J.JArray{Nil{}} S.AMembers{a, b, st}: {==}
    case S.ArraySchema{i, m, n} J.JArray{h0 <> t0} S.AMembers{a, b, st}: {==}
    case S.ObjectSchema{fs, u} x S.AFields{Fail{e}, ss}: {==}
    case S.ObjectSchema{Nil{}, u} x S.AFields{Done{rev}, ss}: {==}
    case S.ObjectSchema{S.Field{k, c, p} <> t, u} x S.AFields{Done{rev}, S.Once{y} <> rest}: and_head(S.accepted(S.decode_go(S.ObjectSchema{S.Field{k, c, p} <> t, u}, x, S.AFields{Done{rev}, S.Once{y} <> rest})), ok(List<&2, S.VField>, S.push_field(rev, k, S.at(S.PathKey{k}, S.decode_go(c, y, S.start(c, y))))), Spec.meets(c, Spec.Holds{}, y), slots_meet(t, rest), agree(S.ObjectSchema{t, u}, x, S.AFields{S.push_field(rev, k, S.at(S.PathKey{k}, S.decode_go(c, y, S.start(c, y)))), rest}, rest_valid(k, c, p, t, u, okv)), Equal.trans(Bool, ok(List<&2, S.VField>, S.push_field(rev, k, S.at(S.PathKey{k}, S.decode_go(c, y, S.start(c, y))))), S.accepted(S.decode_go(c, y, S.start(c, y))), Spec.meets(c, Spec.Holds{}, y), push_field_ok(rev, k, S.PathKey{k}, S.decode_go(c, y, S.start(c, y))), child(c, y, agree(c, y, S.start(c, y), field_valid(k, c, p, t, u, okv)))))
    case S.ObjectSchema{S.Field{k, c, p} <> t, u} x S.AFields{Done{rev}, S.Absent{} <> rest}: and_head(S.accepted(S.decode_go(S.ObjectSchema{S.Field{k, c, p} <> t, u}, x, S.AFields{Done{rev}, S.Absent{} <> rest})), ok(List<&2, S.VField>, S.absent(rev, k, p, S.at(S.PathKey{k}, S.decode_go(c, S.default_of(p), S.start(c, S.default_of(p)))))), absent_ok(p), slots_meet(t, rest), agree(S.ObjectSchema{t, u}, x, S.AFields{S.absent(rev, k, p, S.at(S.PathKey{k}, S.decode_go(c, S.default_of(p), S.start(c, S.default_of(p))))), rest}, rest_valid(k, c, p, t, u, okv)), absent_eq(rev, k, c, p, default_valid(k, c, p, t, u, okv)))
    case S.ObjectSchema{S.Field{k, c, p} <> t, u} x S.AFields{Done{rev}, S.Repeated{y} <> rest}: {==}
    case S.ObjectSchema{S.Field{k, c, p} <> t, u} x S.AFields{Done{rev}, Nil{}}: {==}
    case S.ObjectSchema{fs, u} x S.AScalar{}: {==}
    case S.ObjectSchema{fs, u} x S.AItems{a, st}: {==}
    case S.ObjectSchema{fs, u} x S.AMembers{a, b, st}: {==}
    case S.NullableSchema{i} J.JNull{} y: {==}
    case S.NullableSchema{i} J.JBool{b0} y: child(i, J.JBool{b0}, agree(i, J.JBool{b0}, S.start(i, J.JBool{b0}), okv))
    case S.NullableSchema{i} J.JNumber{b0} y: child(i, J.JNumber{b0}, agree(i, J.JNumber{b0}, S.start(i, J.JNumber{b0}), okv))
    case S.NullableSchema{i} J.JString{b0} y: child(i, J.JString{b0}, agree(i, J.JString{b0}, S.start(i, J.JString{b0}), okv))
    case S.NullableSchema{i} J.JObject{b0} y: child(i, J.JObject{b0}, agree(i, J.JObject{b0}, S.start(i, J.JObject{b0}), okv))
    case S.NullableSchema{i} J.JArray{b0} y: child(i, J.JArray{b0}, agree(i, J.JArray{b0}, S.start(i, J.JArray{b0}), okv))
    case S.UnionSchema{ms} x S.AMembers{n, i, Done{y}}: {==}
    case S.UnionSchema{Nil{}} x S.AMembers{n, i, Fail{e}}: {==}
    case S.UnionSchema{m <> t} x S.AMembers{n, i, Fail{e}}: or_head(S.accepted(S.decode_go(S.UnionSchema{m <> t}, x, S.AMembers{n, i, Fail{e}})), S.accepted(S.decode_go(m, x, S.start(m, x))), Spec.meets(m, Spec.Holds{}, x), Spec.meets(S.UnionSchema{t}, Spec.Holds{}, x), agree(S.UnionSchema{t}, x, S.AMembers{1n+n, n, S.decode_go(m, x, S.start(m, x))}, members_valid(m, t, okv)), child(m, x, agree(m, x, S.start(m, x), member_valid(m, t, okv))))
    case S.UnionSchema{ms} x S.AScalar{}: {==}
    case S.UnionSchema{ms} x S.AItems{a, st}: {==}
    case S.UnionSchema{ms} x S.AFields{st, a}: {==}

def spec_go(+s: S.Schema, +v: J.Json, c: Bool) -> {S.valid(s) == c : Bool} -> {S.accepted(S.decode_valid(s, v, c)) == (c && Spec.meets(s, Spec.Holds{}, v)) : Bool}:
  match c:
    case False{}: e => {==}
    case True{}: e => child(s, v, agree(s, v, S.start(s, v), e))

def guarded(+x: Bool, +v: Bool, -d: Bool, -e: Bool, h: {v == True{} : Bool} -> {d == e : Bool}) -> {((x && v) && d) == ((x && v) && e) : Bool}:
  match x v:
    case True{} True{}: h({==})
    case True{} False{}: {==}
    case False{} y: {==}

def default_eq(+c: S.Schema, +p: S.Presence, okc: {S.valid(c) == True{} : Bool}) -> {S.default_ok(c, p) == Spec.default_fits(c, p) : Bool}:
  match p:
    case S.Required{}: {==}
    case S.Optional{}: {==}
    case S.Default{d}: child(c, d, agree(c, d, S.start(c, d), okc))

# Validity agrees with the specification's well-formedness, defaults included.
def valid_equiv(+s: S.Schema) -> {S.valid(s) == Spec.schema_ok(s) : Bool}:
  match s:
    case S.StringSchema{min, max, p, f}: SP.and_eq(S.max_length(max, min), Spec.at_most(max, min), S.optional_pattern_valid(p), Spec.optional_pattern_ok(p), SP.max_equiv(max, min), SP.optional_pattern_equiv(p))
    case S.NumberSchema{min, max}: SP.bounds_equiv(min, max)
    case S.IntegerSchema{min, max}: SP.bounds_equiv(min, max)
    case S.BooleanSchema{}: {==}
    case S.LiteralSchema{v}: SP.scalar_equiv(v)
    case S.EnumSchema{xs}: SP.literals_go(xs, True{})
    case S.ArraySchema{i, min, max}: SP.and_eq(S.max_length(max, min), Spec.at_most(max, min), S.valid(i), Spec.schema_ok(i), SP.max_equiv(max, min), valid_equiv(i))
    case S.ObjectSchema{Nil{}, u}: {==}
    case S.ObjectSchema{S.Field{k, c, p} <> t, u}:
      %TP.scalars_equiv(k) : {S.valid(S.ObjectSchema{S.Field{k, c, p} <> t, u}) == (_ && Bool.not(Spec.declares(t, k)) && Spec.schema_ok(c) && Spec.default_fits(c, p) && Spec.schema_ok(S.ObjectSchema{t, u})) : Bool}
      %SP.declared_equiv(t, k) : {S.valid(S.ObjectSchema{S.Field{k, c, p} <> t, u}) == (J.scalars(k) && Bool.not(_) && Spec.schema_ok(c) && Spec.default_fits(c, p) && Spec.schema_ok(S.ObjectSchema{t, u})) : Bool}
      %valid_equiv(c) : {S.valid(S.ObjectSchema{S.Field{k, c, p} <> t, u}) == (J.scalars(k) && Bool.not(S.declared(t, k)) && _ && Spec.default_fits(c, p) && Spec.schema_ok(S.ObjectSchema{t, u})) : Bool}
      %valid_equiv(S.ObjectSchema{t, u}) : {S.valid(S.ObjectSchema{S.Field{k, c, p} <> t, u}) == (J.scalars(k) && Bool.not(S.declared(t, k)) && S.valid(c) && Spec.default_fits(c, p) && _) : Bool}
      %guarded(J.scalars(k) && Bool.not(S.declared(t, k)), S.valid(c), S.default_ok(c, p), Spec.default_fits(c, p), okc => default_eq(c, p, okc)) : {S.valid(S.ObjectSchema{S.Field{k, c, p} <> t, u}) == (_ && S.valid(S.ObjectSchema{t, u})) : Bool}
      {==}
    case S.NullableSchema{i}: valid_equiv(i)
    case S.UnionSchema{Nil{}}: {==}
    case S.UnionSchema{m <> t}: SP.and_eq(S.valid(m), Spec.schema_ok(m), S.valid(S.UnionSchema{t}), Spec.schema_ok(S.UnionSchema{t}), valid_equiv(m), valid_equiv(S.UnionSchema{t}))

def report_accepted(r: Result<&2, &2, S.Errors(), S.Value>, +s: S.Schema, +v: J.Json) -> {S.accepted(S.report(r, s, v)) == S.accepted(r) : Bool}:
  match r:
    case Done{x}: {==}
    case Fail{e}: {==}

def first_spec(+s: S.Schema, +v: J.Json) -> {S.accepted(S.decode_first(s, v)) == Spec.satisfies(s, v) : Bool}:
  %valid_equiv(s) : {S.accepted(S.decode_first(s, v)) == (_ && Spec.meets(s, Spec.Holds{}, v)) : Bool}
  spec_go(s, v, S.valid(s))({==})

# The BND-33 law over the whole schema language.
def acceptance_spec(+s: S.Schema, +v: J.Json) -> {S.accepted(S.decode(s, v)) == Spec.satisfies(s, v) : Bool}:
  Equal.trans(Bool, S.accepted(S.decode(s, v)), S.accepted(S.decode_first(s, v)), Spec.satisfies(s, v), report_accepted(S.decode_first(s, v), s, v), first_spec(s, v))

# BND-34 preservation: every success carries exactly `value_for`.

def items_after(rev: List<&2, S.Value>, m: Maybe<&2, S.Value>) -> Maybe<&2, S.Value>:
  match m:
    case Some{S.VArray{ys}}: Some{S.VArray{List.reverse.go(&2, S.Value, rev, ys)}}
    case _: None{}

def fields_after(rev: List<&2, S.VField>, m: Maybe<&2, S.Value>) -> Maybe<&2, S.Value>:
  match m:
    case Some{S.VObject{ys}}: Some{S.VObject{List.reverse.go(&2, S.VField, rev, ys)}}
    case _: None{}

def shift_by(n: Nat, m: Maybe<&2, S.Value>) -> Maybe<&2, S.Value>:
  match m:
    case Some{S.VUnion{j, x}}: Some{S.VUnion{Nat.add(j, n), x}}
    case _: None{}

def absent_value(+k: String, +c: S.Schema, p: S.Presence) -> Maybe<&2, S.VField>:
  match p:
    case S.Default{+d}: S.field_value(k, Some{d}, S.value_for(c, d))
    case S.Required{}: Some{S.VField{k, None{}}}
    case S.Optional{}: Some{S.VField{k, None{}}}

def slot_value(+k: String, +c: S.Schema, p: S.Presence, slot: S.Slot) -> Maybe<&2, S.VField>:
  match slot:
    case S.Absent{}: absent_value(k, c, p)
    case S.Once{+y}: S.field_value(k, Some{y}, S.value_for(c, y))
    case S.Repeated{+y}: S.field_value(k, Some{y}, S.value_for(c, y))

def slot_values(fs: List<&2, S.Field>, ss: List<&2, S.Slot>) -> Maybe<&2, S.Value>:
  match fs ss:
    case Nil{} _: Some{S.VObject{[]}}
    case S.Field{k, c, p} <> t x <> rest: S.cons_field(slot_value(k, c, p, x), slot_values(t, rest))
    case S.Field{k, c, p} <> t Nil{}: None{}

def want(s: S.Schema, acc: S.Acc, +v: J.Json) -> Maybe<&2, S.Value>:
  match s acc:
    case S.ArraySchema{i, m, n} S.AItems{k, Done{rev}}: items_after(rev, S.value_for(S.ArraySchema{i, m, n}, v))
    case S.ObjectSchema{fs, u} S.AFields{Done{rev}, ss}: fields_after(rev, slot_values(fs, ss))
    case S.UnionSchema{ms} S.AMembers{n, i, Done{x}}: Some{S.VUnion{i, x}}
    case S.UnionSchema{ms} S.AMembers{n, i, Fail{e}}: shift_by(n, S.value_for(S.UnionSchema{ms}, v))
    case x a: S.value_for(x, v)

def after_item(+rev: List<&2, S.Value>, +x: S.Value, +m: Maybe<&2, S.Value>) -> {items_after(x <> rev, m) == items_after(rev, S.cons_item(Some{x}, m)) : Maybe<&2, S.Value>}:
  match m:
    case None{}: {==}
    case Some{S.VString{a0}}: {==}
    case Some{S.VNumber{a0}}: {==}
    case Some{S.VInteger{a0}}: {==}
    case Some{S.VBool{a0}}: {==}
    case Some{S.VLiteral{a0}}: {==}
    case Some{S.VNull{}}: {==}
    case Some{S.VObject{a0}}: {==}
    case Some{S.VUnion{a0, b0}}: {==}
    case Some{S.VArray{ys}}: {==}

def after_field(+rev: List<&2, S.VField>, +f: S.VField, +m: Maybe<&2, S.Value>) -> {fields_after(f <> rev, m) == fields_after(rev, S.cons_field(Some{f}, m)) : Maybe<&2, S.Value>}:
  match m:
    case None{}: {==}
    case Some{S.VString{a0}}: {==}
    case Some{S.VNumber{a0}}: {==}
    case Some{S.VInteger{a0}}: {==}
    case Some{S.VBool{a0}}: {==}
    case Some{S.VLiteral{a0}}: {==}
    case Some{S.VNull{}}: {==}
    case Some{S.VArray{a0}}: {==}
    case Some{S.VUnion{a0, b0}}: {==}
    case Some{S.VObject{ys}}: {==}

def after_cons_item(+a: Maybe<&2, S.Value>, +b: Maybe<&2, S.Value>) -> {items_after([], S.cons_item(a, b)) == S.cons_item(a, b) : Maybe<&2, S.Value>}:
  match a b:
    case None{} y: {==}
    case Some{x} None{}: {==}
    case Some{x} Some{S.VString{a0}}: {==}
    case Some{x} Some{S.VNumber{a0}}: {==}
    case Some{x} Some{S.VInteger{a0}}: {==}
    case Some{x} Some{S.VBool{a0}}: {==}
    case Some{x} Some{S.VLiteral{a0}}: {==}
    case Some{x} Some{S.VNull{}}: {==}
    case Some{x} Some{S.VObject{a0}}: {==}
    case Some{x} Some{S.VUnion{a0, b0}}: {==}
    case Some{x} Some{S.VArray{ys}}: {==}

def after_cons_field(+a: Maybe<&2, S.VField>, +b: Maybe<&2, S.Value>) -> {fields_after([], S.cons_field(a, b)) == S.cons_field(a, b) : Maybe<&2, S.Value>}:
  match a b:
    case None{} y: {==}
    case Some{x} None{}: {==}
    case Some{x} Some{S.VString{a0}}: {==}
    case Some{x} Some{S.VNumber{a0}}: {==}
    case Some{x} Some{S.VInteger{a0}}: {==}
    case Some{x} Some{S.VBool{a0}}: {==}
    case Some{x} Some{S.VLiteral{a0}}: {==}
    case Some{x} Some{S.VNull{}}: {==}
    case Some{x} Some{S.VArray{a0}}: {==}
    case Some{x} Some{S.VUnion{a0, b0}}: {==}
    case Some{x} Some{S.VObject{ys}}: {==}

def shift_fail(+n: Nat, +a: Maybe<&2, S.Value>, +m: Maybe<&2, S.Value>) -> {shift_by(1n+n, m) == shift_by(n, S.first_member(False{}, a, m)) : Maybe<&2, S.Value>}:
  match m:
    case None{}: {==}
    case Some{S.VString{a0}}: {==}
    case Some{S.VNumber{a0}}: {==}
    case Some{S.VInteger{a0}}: {==}
    case Some{S.VBool{a0}}: {==}
    case Some{S.VLiteral{a0}}: {==}
    case Some{S.VNull{}}: {==}
    case Some{S.VArray{a0}}: {==}
    case Some{S.VObject{a0}}: {==}
    case Some{S.VUnion{j, x}}:
      %A.add_succ_r(j, n) : {Some{S.VUnion{Nat.add(j, 1n+n), x}} == Some{S.VUnion{_, x}} : Maybe<&2, S.Value>}
      {==}

def shift_zero(+h: Bool, +a: Maybe<&2, S.Value>, +m: Maybe<&2, S.Value>) -> {shift_by(0n, S.first_member(h, a, m)) == S.first_member(h, a, m) : Maybe<&2, S.Value>}:
  match h a m:
    case True{} Some{x} y: {==}
    case True{} None{} y: {==}
    case False{} y None{}: {==}
    case False{} y Some{S.VString{a0}}: {==}
    case False{} y Some{S.VNumber{a0}}: {==}
    case False{} y Some{S.VInteger{a0}}: {==}
    case False{} y Some{S.VBool{a0}}: {==}
    case False{} y Some{S.VLiteral{a0}}: {==}
    case False{} y Some{S.VNull{}}: {==}
    case False{} y Some{S.VArray{a0}}: {==}
    case False{} y Some{S.VObject{a0}}: {==}
    case False{} y Some{S.VUnion{j, x}}:
      %A.add_zero_r(j) : {Some{S.VUnion{1n+Nat.add(j, 0n), x}} == Some{S.VUnion{1n+_, x}} : Maybe<&2, S.Value>}
      {==}

def first_of(slot: S.Slot) -> Maybe<&2, J.Json>:
  match slot:
    case S.Absent{}: None{}
    case S.Once{y}: Some{y}
    case S.Repeated{y}: Some{y}

def first_or(acc: S.Slot, input: List<&2, J.Field>, k: String) -> Maybe<&2, J.Json>:
  match acc:
    case S.Absent{}: S.first(input, k)
    case S.Once{y}: Some{y}
    case S.Repeated{y}: Some{y}

def first_absent(+k: String, +y: J.Json, +t: List<&2, J.Field>, b: Bool) -> {first_of(S.find(t, k, S.found(b, S.Absent{}, y))) == first_or(S.found(b, S.Absent{}, y), t, k) : Maybe<&2, J.Json>} -> {first_of(S.find(t, k, S.found(b, S.Absent{}, y))) == Bool.pick(Maybe<&2, J.Json>, b, Some{y}, S.first(t, k)) : Maybe<&2, J.Json>}:
  match b:
    case True{}: ih => ih
    case False{}: ih => ih

def first_once(+k: String, +y: J.Json, +z: J.Json, +t: List<&2, J.Field>, b: Bool) -> {first_of(S.find(t, k, S.found(b, S.Once{z}, y))) == first_or(S.found(b, S.Once{z}, y), t, k) : Maybe<&2, J.Json>} -> {first_of(S.find(t, k, S.found(b, S.Once{z}, y))) == Some{z} : Maybe<&2, J.Json>}:
  match b:
    case True{}: ih => ih
    case False{}: ih => ih

def first_go(+input: List<&2, J.Field>, +k: String, +acc: S.Slot) -> {first_of(S.find(input, k, acc)) == first_or(acc, input, k) : Maybe<&2, J.Json>}:
  match input acc:
    case x S.Repeated{y}: {==}
    case Nil{} S.Absent{}: {==}
    case Nil{} S.Once{y}: {==}
    case J.Field{key, y} <> t S.Absent{}: first_absent(k, y, t, String.eq(key, k))(first_go(t, k, S.found(String.eq(key, k), S.Absent{}, y)))
    case J.Field{key, y} <> t S.Once{z}: first_once(k, y, z, t, String.eq(key, k))(first_go(t, k, S.found(String.eq(key, k), S.Once{z}, y)))

def slot_shape(+k: String, +c: S.Schema, +p: S.Presence, +slot: S.Slot) -> {slot_value(k, c, p, slot) == S.field_value(k, S.fill(p, first_of(slot)), S.value_for(c, S.or_null(S.fill(p, first_of(slot))))) : Maybe<&2, S.VField>}:
  match p slot:
    case S.Required{} S.Absent{}: {==}
    case S.Required{} S.Once{y}: {==}
    case S.Required{} S.Repeated{y}: {==}
    case S.Optional{} S.Absent{}: {==}
    case S.Optional{} S.Once{y}: {==}
    case S.Optional{} S.Repeated{y}: {==}
    case S.Default{d} S.Absent{}: {==}
    case S.Default{d} S.Once{y}: {==}
    case S.Default{d} S.Repeated{y}: {==}

def slot_value_eq(+k: String, +c: S.Schema, +p: S.Presence, +input: List<&2, J.Field>) -> {slot_value(k, c, p, S.find(input, k, S.Absent{})) == S.field_value(k, S.fill(p, S.first(input, k)), S.value_for(c, S.or_null(S.fill(p, S.first(input, k))))) : Maybe<&2, S.VField>}:
  %first_go(input, k, S.Absent{}) : {slot_value(k, c, p, S.find(input, k, S.Absent{})) == S.field_value(k, S.fill(p, _), S.value_for(c, S.or_null(S.fill(p, _)))) : Maybe<&2, S.VField>}
  slot_shape(k, c, p, S.find(input, k, S.Absent{}))

def slot_values_eq(+fs: List<&2, S.Field>, +u: S.Unknown, +input: List<&2, J.Field>) -> {slot_values(fs, S.slots(fs, input)) == S.value_for(S.ObjectSchema{fs, u}, J.JObject{input}) : Maybe<&2, S.Value>}:
  match fs:
    case Nil{}: {==}
    case S.Field{k, c, p} <> t:
      %slot_value_eq(k, c, p, input) : {slot_values(S.Field{k, c, p} <> t, S.slots(S.Field{k, c, p} <> t, input)) == S.cons_field(_, S.value_for(S.ObjectSchema{t, u}, J.JObject{input})) : Maybe<&2, S.Value>}
      %slot_values_eq(t, u, input) : {slot_values(S.Field{k, c, p} <> t, S.slots(S.Field{k, c, p} <> t, input)) == S.cons_field(slot_value(k, c, p, S.find(input, k, S.Absent{})), _) : Maybe<&2, S.Value>}
      {==}

def after_slot_values(+fs: List<&2, S.Field>, +ss: List<&2, S.Slot>) -> {fields_after([], slot_values(fs, ss)) == slot_values(fs, ss) : Maybe<&2, S.Value>}:
  match fs ss:
    case Nil{} x: {==}
    case S.Field{k, c, p} <> t x <> rest: after_cons_field(slot_value(k, c, p, x), slot_values(t, rest))
    case S.Field{k, c, p} <> t Nil{}: {==}

def obj_entry(+fs: List<&2, S.Field>, +u: S.Unknown, +input: List<&2, J.Field>, b: Bool) -> {want(S.ObjectSchema{fs, u}, S.AFields{S.fields_gate(b), S.slots(fs, input)}, J.JObject{input}) == S.value_for(S.ObjectSchema{fs, u}, J.JObject{input}) : Maybe<&2, S.Value>}:
  match b:
    case False{}: {==}
    case True{}:
      %slot_values_eq(fs, u, input) : {fields_after([], slot_values(fs, S.slots(fs, input))) == _ : Maybe<&2, S.Value>}
      after_slot_values(fs, S.slots(fs, input))

def arr_entry(+i: S.Schema, +m: Nat, +n: Maybe<&2, Nat>, b: Bool, +xs: List<&2, J.Json>) -> {want(S.ArraySchema{i, m, n}, S.AItems{0n, S.items_gate(b)}, J.JArray{xs}) == S.value_for(S.ArraySchema{i, m, n}, J.JArray{xs}) : Maybe<&2, S.Value>}:
  match b xs:
    case False{} ys: {==}
    case True{} Nil{}: {==}
    case True{} h <> t: after_cons_item(S.value_for(i, h), S.value_for(S.ArraySchema{i, m, n}, J.JArray{t}))

def entry2(+s: S.Schema, +v: J.Json) -> {want(s, S.start(s, v), v) == S.value_for(s, v) : Maybe<&2, S.Value>}:
  match s v:
    case S.StringSchema{a, b, c, d} x: {==}
    case S.NumberSchema{a, b} x: {==}
    case S.IntegerSchema{a, b} x: {==}
    case S.BooleanSchema{} x: {==}
    case S.LiteralSchema{a} x: {==}
    case S.EnumSchema{a} x: {==}
    case S.ArraySchema{i, m, n} J.JArray{xs}: arr_entry(i, m, n, S.item_count(m, n, S.count(xs, 0n)), xs)
    case S.ArraySchema{i, m, n} J.JNull{}: {==}
    case S.ArraySchema{i, m, n} J.JBool{b0}: {==}
    case S.ArraySchema{i, m, n} J.JNumber{b0}: {==}
    case S.ArraySchema{i, m, n} J.JString{b0}: {==}
    case S.ArraySchema{i, m, n} J.JObject{b0}: {==}
    case S.ObjectSchema{fs, u} J.JObject{input}: obj_entry(fs, u, input, S.known(u, fs, input))
    case S.ObjectSchema{fs, u} J.JNull{}: {==}
    case S.ObjectSchema{fs, u} J.JBool{b0}: {==}
    case S.ObjectSchema{fs, u} J.JNumber{b0}: {==}
    case S.ObjectSchema{fs, u} J.JString{b0}: {==}
    case S.ObjectSchema{fs, u} J.JArray{b0}: {==}
    case S.NullableSchema{i} x: {==}
    case S.UnionSchema{Nil{}} x: {==}
    case S.UnionSchema{m <> t} x: shift_zero(S.accepted(S.decode_first(m, x)), S.value_for(m, x), S.value_for(S.UnionSchema{t}, x))

def child2(+s: S.Schema, +v: J.Json, ih: S.Preserves(want(s, S.start(s, v), v), S.decode_go(s, v, S.start(s, v)))) -> S.Preserves(S.value_for(s, v), S.decode_go(s, v, S.start(s, v))):
  %entry2(s, v) : S.Preserves(_, S.decode_go(s, v, S.start(s, v)))
  ih

def decode_eq(+m: S.Schema, +x: J.Json, okm: {S.valid(m) == True{} : Bool}) -> {S.decode_first(m, x) == S.decode_go(m, x, S.start(m, x)) : Result<&2, &2, S.Errors(), S.Value>}:
  %Equal.sym(Bool, S.valid(m), True{}, okm) : {S.decode_valid(m, x, _) == S.decode_go(m, x, S.start(m, x)) : Result<&2, &2, S.Errors(), S.Value>}
  {==}

def arr_step(+i: S.Schema, +m: Nat, +n: Maybe<&2, Nat>, +h: J.Json, +k: Nat, +rev: List<&2, S.Value>, r: Result<&2, &2, S.Errors(), S.Value>, t: List<&2, J.Json>) -> S.Preserves(S.value_for(i, h), r) -> S.Preserves(want(S.ArraySchema{i, m, n}, S.AItems{1n+k, S.push(rev, S.at(S.PathIndex{k}, r))}, J.JArray{t}), S.decode_go(S.ArraySchema{i, m, n}, J.JArray{t}, S.AItems{1n+k, S.push(rev, S.at(S.PathIndex{k}, r))})) -> S.Preserves(items_after(rev, S.cons_item(S.value_for(i, h), S.value_for(S.ArraySchema{i, m, n}, J.JArray{t}))), S.decode_go(S.ArraySchema{i, m, n}, J.JArray{t}, S.AItems{1n+k, S.push(rev, S.at(S.PathIndex{k}, r))})):
  match r t:
    case Fail{e} Nil{}: ih1 => ih2 => Unit{}
    case Fail{e} g <> u: ih1 => ih2 => Unit{}
    case Done{x} +u: ih1 => ih2 =>
      %ih1 : S.Preserves(items_after(rev, S.cons_item(_, S.value_for(S.ArraySchema{i, m, n}, J.JArray{u}))), S.decode_go(S.ArraySchema{i, m, n}, J.JArray{u}, S.AItems{1n+k, Done{x <> rev}}))
      %after_item(rev, x, S.value_for(S.ArraySchema{i, m, n}, J.JArray{u})) : S.Preserves(_, S.decode_go(S.ArraySchema{i, m, n}, J.JArray{u}, S.AItems{1n+k, Done{x <> rev}}))
      ih2

def obj_step(+k: String, +c: S.Schema, +u: S.Unknown, +x: J.Json, +y: J.Json, +rest: List<&2, S.Slot>, +rev: List<&2, S.VField>, r: Result<&2, &2, S.Errors(), S.Value>, t: List<&2, S.Field>) -> S.Preserves(S.value_for(c, y), r) -> S.Preserves(want(S.ObjectSchema{t, u}, S.AFields{S.push_field(rev, k, S.at(S.PathKey{k}, r)), rest}, x), S.decode_go(S.ObjectSchema{t, u}, x, S.AFields{S.push_field(rev, k, S.at(S.PathKey{k}, r)), rest})) -> S.Preserves(fields_after(rev, S.cons_field(S.field_value(k, Some{y}, S.value_for(c, y)), slot_values(t, rest))), S.decode_go(S.ObjectSchema{t, u}, x, S.AFields{S.push_field(rev, k, S.at(S.PathKey{k}, r)), rest})):
  match r t:
    case Fail{e} Nil{}: ih1 => ih2 => Unit{}
    case Fail{e} S.Field{k2, c2, p2} <> t2: ih1 => ih2 => Unit{}
    case Done{z} +g: ih1 => ih2 =>
      %ih1 : S.Preserves(fields_after(rev, S.cons_field(S.field_value(k, Some{y}, _), slot_values(g, rest))), S.decode_go(S.ObjectSchema{g, u}, x, S.AFields{Done{S.VField{k, Some{z}} <> rev}, rest}))
      %after_field(rev, S.VField{k, Some{z}}, slot_values(g, rest)) : S.Preserves(_, S.decode_go(S.ObjectSchema{g, u}, x, S.AFields{Done{S.VField{k, Some{z}} <> rev}, rest}))
      ih2

def absent_step(+k: String, +c: S.Schema, +u: S.Unknown, +x: J.Json, +rest: List<&2, S.Slot>, +rev: List<&2, S.VField>, p: S.Presence, t: List<&2, S.Field>) -> S.Preserves(S.value_for(c, S.default_of(p)), S.decode_go(c, S.default_of(p), S.start(c, S.default_of(p)))) -> S.Preserves(want(S.ObjectSchema{t, u}, S.AFields{S.absent(rev, k, p, S.at(S.PathKey{k}, S.decode_go(c, S.default_of(p), S.start(c, S.default_of(p))))), rest}, x), S.decode_go(S.ObjectSchema{t, u}, x, S.AFields{S.absent(rev, k, p, S.at(S.PathKey{k}, S.decode_go(c, S.default_of(p), S.start(c, S.default_of(p))))), rest})) -> S.Preserves(fields_after(rev, S.cons_field(absent_value(k, c, p), slot_values(t, rest))), S.decode_go(S.ObjectSchema{t, u}, x, S.AFields{S.absent(rev, k, p, S.at(S.PathKey{k}, S.decode_go(c, S.default_of(p), S.start(c, S.default_of(p))))), rest})):
  match p t:
    case S.Required{} Nil{}: ih1 => ih2 => Unit{}
    case S.Required{} S.Field{k2, c2, p2} <> t2: ih1 => ih2 => Unit{}
    case S.Optional{} +g: ih1 => ih2 =>
      %after_field(rev, S.VField{k, None{}}, slot_values(g, rest)) : S.Preserves(_, S.decode_go(S.ObjectSchema{g, u}, x, S.AFields{Done{S.VField{k, None{}} <> rev}, rest}))
      ih2
    case S.Default{+d} g: ih1 => ih2 => obj_step(k, c, u, x, d, rest, rev, S.decode_go(c, d, S.start(c, d)), g)(ih1)(ih2)

def uni_done(+m: S.Schema, +x: J.Json, +n: Nat, +z: S.Value, +later: Maybe<&2, S.Value>, hr: {S.decode_first(m, x) == Done{z} : Result<&2, &2, S.Errors(), S.Value>}, ih1: {Some{z} == S.value_for(m, x) : Maybe<&2, S.Value>}) -> {Some{S.VUnion{n, z}} == shift_by(n, S.first_member(S.accepted(S.decode_first(m, x)), S.value_for(m, x), later)) : Maybe<&2, S.Value>}:
  %Equal.sym(Result<&2, &2, S.Errors(), S.Value>, S.decode_first(m, x), Done{z}, hr) : {Some{S.VUnion{n, z}} == shift_by(n, S.first_member(S.accepted(_), S.value_for(m, x), later)) : Maybe<&2, S.Value>}
  %ih1 : {Some{S.VUnion{n, z}} == shift_by(n, S.first_member(True{}, _, later)) : Maybe<&2, S.Value>}
  {==}

def uni_step(+m: S.Schema, +x: J.Json, +n: Nat, r: Result<&2, &2, S.Errors(), S.Value>, t: List<&2, S.Schema>) -> {S.decode_first(m, x) == r : Result<&2, &2, S.Errors(), S.Value>} -> S.Preserves(S.value_for(m, x), r) -> S.Preserves(want(S.UnionSchema{t}, S.AMembers{1n+n, n, r}, x), S.decode_go(S.UnionSchema{t}, x, S.AMembers{1n+n, n, r})) -> S.Preserves(shift_by(n, S.first_member(S.accepted(S.decode_first(m, x)), S.value_for(m, x), S.value_for(S.UnionSchema{t}, x))), S.decode_go(S.UnionSchema{t}, x, S.AMembers{1n+n, n, r})):
  match r t:
    case Done{z} Nil{}: hr => ih1 => ih2 => uni_done(m, x, n, z, S.value_for(S.UnionSchema{[]}, x), hr, ih1)
    case Done{z} g <> h: hr => ih1 => ih2 => uni_done(m, x, n, z, S.value_for(S.UnionSchema{g <> h}, x), hr, ih1)
    case Fail{e} +g: hr => ih1 => ih2 =>
      %Equal.sym(Result<&2, &2, S.Errors(), S.Value>, S.decode_first(m, x), Fail{e}, hr) : S.Preserves(shift_by(n, S.first_member(S.accepted(_), S.value_for(m, x), S.value_for(S.UnionSchema{g}, x))), S.decode_go(S.UnionSchema{g}, x, S.AMembers{1n+n, n, Fail{e}}))
      %shift_fail(n, S.value_for(m, x), S.value_for(S.UnionSchema{g}, x)) : S.Preserves(_, S.decode_go(S.UnionSchema{g}, x, S.AMembers{1n+n, n, Fail{e}}))
      ih2

# Every decoding state's success carries exactly what its promise says.
def keep(+s: S.Schema, +v: J.Json, +acc: S.Acc, +okv: {S.valid(s) == True{} : Bool}) -> S.Preserves(want(s, acc, v), S.decode_go(s, v, acc)):
  match s v acc:
    case S.StringSchema{a, b, c, d} x y: SP.scalar_preserves(S.StringSchema{a, b, c, d}, x)
    case S.NumberSchema{a, b} x y: SP.scalar_preserves(S.NumberSchema{a, b}, x)
    case S.IntegerSchema{a, b} x y: SP.scalar_preserves(S.IntegerSchema{a, b}, x)
    case S.BooleanSchema{} x y: SP.scalar_preserves(S.BooleanSchema{}, x)
    case S.LiteralSchema{a} x y: SP.scalar_preserves(S.LiteralSchema{a}, x)
    case S.EnumSchema{a} x y: SP.scalar_preserves(S.EnumSchema{a}, x)
    case S.ArraySchema{i, m, n} J.JNull{} S.AItems{k, Fail{e}}: Unit{}
    case S.ArraySchema{i, m, n} J.JBool{b0} S.AItems{k, Fail{e}}: Unit{}
    case S.ArraySchema{i, m, n} J.JNumber{b0} S.AItems{k, Fail{e}}: Unit{}
    case S.ArraySchema{i, m, n} J.JString{b0} S.AItems{k, Fail{e}}: Unit{}
    case S.ArraySchema{i, m, n} J.JObject{b0} S.AItems{k, Fail{e}}: Unit{}
    case S.ArraySchema{i, m, n} J.JArray{Nil{}} S.AItems{k, Fail{e}}: Unit{}
    case S.ArraySchema{i, m, n} J.JArray{h0 <> t0} S.AItems{k, Fail{e}}: Unit{}
    case S.ArraySchema{i, m, n} J.JArray{Nil{}} S.AItems{k, Done{rev}}: {==}
    case S.ArraySchema{i, m, n} J.JArray{h <> t} S.AItems{k, Done{rev}}: arr_step(i, m, n, h, k, rev, S.decode_go(i, h, S.start(i, h)), t)(child2(i, h, keep(i, h, S.start(i, h), item_valid(i, m, n, okv))))(keep(S.ArraySchema{i, m, n}, J.JArray{t}, S.AItems{1n+k, S.push(rev, S.at(S.PathIndex{k}, S.decode_go(i, h, S.start(i, h))))}, okv))
    case S.ArraySchema{i, m, n} J.JNull{} S.AItems{k, Done{rev}}: Unit{}
    case S.ArraySchema{i, m, n} J.JBool{b0} S.AItems{k, Done{rev}}: Unit{}
    case S.ArraySchema{i, m, n} J.JNumber{b0} S.AItems{k, Done{rev}}: Unit{}
    case S.ArraySchema{i, m, n} J.JString{b0} S.AItems{k, Done{rev}}: Unit{}
    case S.ArraySchema{i, m, n} J.JObject{b0} S.AItems{k, Done{rev}}: Unit{}
    case S.ArraySchema{i, m, n} J.JNull{} S.AScalar{}: Unit{}
    case S.ArraySchema{i, m, n} J.JNull{} S.AFields{st, ss}: Unit{}
    case S.ArraySchema{i, m, n} J.JNull{} S.AMembers{a1, a2, st}: Unit{}
    case S.ArraySchema{i, m, n} J.JBool{b0} S.AScalar{}: Unit{}
    case S.ArraySchema{i, m, n} J.JBool{b0} S.AFields{st, ss}: Unit{}
    case S.ArraySchema{i, m, n} J.JBool{b0} S.AMembers{a1, a2, st}: Unit{}
    case S.ArraySchema{i, m, n} J.JNumber{b0} S.AScalar{}: Unit{}
    case S.ArraySchema{i, m, n} J.JNumber{b0} S.AFields{st, ss}: Unit{}
    case S.ArraySchema{i, m, n} J.JNumber{b0} S.AMembers{a1, a2, st}: Unit{}
    case S.ArraySchema{i, m, n} J.JString{b0} S.AScalar{}: Unit{}
    case S.ArraySchema{i, m, n} J.JString{b0} S.AFields{st, ss}: Unit{}
    case S.ArraySchema{i, m, n} J.JString{b0} S.AMembers{a1, a2, st}: Unit{}
    case S.ArraySchema{i, m, n} J.JObject{b0} S.AScalar{}: Unit{}
    case S.ArraySchema{i, m, n} J.JObject{b0} S.AFields{st, ss}: Unit{}
    case S.ArraySchema{i, m, n} J.JObject{b0} S.AMembers{a1, a2, st}: Unit{}
    case S.ArraySchema{i, m, n} J.JArray{Nil{}} S.AScalar{}: Unit{}
    case S.ArraySchema{i, m, n} J.JArray{Nil{}} S.AFields{st, ss}: Unit{}
    case S.ArraySchema{i, m, n} J.JArray{Nil{}} S.AMembers{a1, a2, st}: Unit{}
    case S.ArraySchema{i, m, n} J.JArray{h0 <> t0} S.AScalar{}: Unit{}
    case S.ArraySchema{i, m, n} J.JArray{h0 <> t0} S.AFields{st, ss}: Unit{}
    case S.ArraySchema{i, m, n} J.JArray{h0 <> t0} S.AMembers{a1, a2, st}: Unit{}
    case S.ObjectSchema{fs, u} x S.AFields{Fail{e}, ss}: Unit{}
    case S.ObjectSchema{Nil{}, u} x S.AFields{Done{rev}, ss}: {==}
    case S.ObjectSchema{S.Field{k, c, p} <> t, u} x S.AFields{Done{rev}, S.Once{y} <> rest}: obj_step(k, c, u, x, y, rest, rev, S.decode_go(c, y, S.start(c, y)), t)(child2(c, y, keep(c, y, S.start(c, y), field_valid(k, c, p, t, u, okv))))(keep(S.ObjectSchema{t, u}, x, S.AFields{S.push_field(rev, k, S.at(S.PathKey{k}, S.decode_go(c, y, S.start(c, y)))), rest}, rest_valid(k, c, p, t, u, okv)))
    case S.ObjectSchema{S.Field{k, c, p} <> t, u} x S.AFields{Done{rev}, S.Absent{} <> rest}: absent_step(k, c, u, x, rest, rev, p, t)(child2(c, S.default_of(p), keep(c, S.default_of(p), S.start(c, S.default_of(p)), field_valid(k, c, p, t, u, okv))))(keep(S.ObjectSchema{t, u}, x, S.AFields{S.absent(rev, k, p, S.at(S.PathKey{k}, S.decode_go(c, S.default_of(p), S.start(c, S.default_of(p))))), rest}, rest_valid(k, c, p, t, u, okv)))
    case S.ObjectSchema{S.Field{k, c, p} <> t, u} x S.AFields{Done{rev}, S.Repeated{y} <> rest}: Unit{}
    case S.ObjectSchema{S.Field{k, c, p} <> t, u} x S.AFields{Done{rev}, Nil{}}: Unit{}
    case S.ObjectSchema{fs, u} x S.AScalar{}: Unit{}
    case S.ObjectSchema{fs, u} x S.AItems{a1, st}: Unit{}
    case S.ObjectSchema{fs, u} x S.AMembers{a1, a2, st}: Unit{}
    case S.NullableSchema{i} J.JNull{} y: {==}
    case S.NullableSchema{i} J.JBool{b0} y: child2(i, J.JBool{b0}, keep(i, J.JBool{b0}, S.start(i, J.JBool{b0}), okv))
    case S.NullableSchema{i} J.JNumber{b0} y: child2(i, J.JNumber{b0}, keep(i, J.JNumber{b0}, S.start(i, J.JNumber{b0}), okv))
    case S.NullableSchema{i} J.JString{b0} y: child2(i, J.JString{b0}, keep(i, J.JString{b0}, S.start(i, J.JString{b0}), okv))
    case S.NullableSchema{i} J.JArray{b0} y: child2(i, J.JArray{b0}, keep(i, J.JArray{b0}, S.start(i, J.JArray{b0}), okv))
    case S.NullableSchema{i} J.JObject{b0} y: child2(i, J.JObject{b0}, keep(i, J.JObject{b0}, S.start(i, J.JObject{b0}), okv))
    case S.UnionSchema{ms} x S.AMembers{n, i, Done{y}}: {==}
    case S.UnionSchema{Nil{}} x S.AMembers{n, i, Fail{e}}: Unit{}
    case S.UnionSchema{m <> t} x S.AMembers{n, i, Fail{e}}: uni_step(m, x, n, S.decode_go(m, x, S.start(m, x)), t)(decode_eq(m, x, member_valid(m, t, okv)))(child2(m, x, keep(m, x, S.start(m, x), member_valid(m, t, okv))))(keep(S.UnionSchema{t}, x, S.AMembers{1n+n, n, S.decode_go(m, x, S.start(m, x))}, members_valid(m, t, okv)))
    case S.UnionSchema{ms} x S.AScalar{}: Unit{}
    case S.UnionSchema{ms} x S.AItems{a1, st}: Unit{}
    case S.UnionSchema{ms} x S.AFields{st, ss}: Unit{}

def pres_go(+s: S.Schema, +v: J.Json, c: Bool) -> {S.valid(s) == c : Bool} -> S.Preserves(S.value_for(s, v), S.decode_valid(s, v, c)):
  match c:
    case False{}: e => Unit{}
    case True{}: e => child2(s, v, keep(s, v, S.start(s, v), e))

def first_preservation(+s: S.Schema, +v: J.Json) -> S.Preserves(S.value_for(s, v), S.decode_first(s, v)):
  pres_go(s, v, S.valid(s))({==})

def report_preserves(-m: Maybe<&2, S.Value>, r: Result<&2, &2, S.Errors(), S.Value>, +s: S.Schema, +v: J.Json) -> S.Preserves(m, r) -> S.Preserves(m, S.report(r, s, v)):
  match r:
    case Done{x}: h => h
    case Fail{e}: h => Unit{}

# The BND-33 preservation law over the whole schema language.
def preservation(+s: S.Schema, +v: J.Json) -> S.Preserves(S.value_for(s, v), S.decode(s, v)):
  report_preserves(S.value_for(s, v), S.decode_first(s, v), s, v)(first_preservation(s, v))

# BND-34 ticket law: the children of an accepted value satisfy their schemas.

def items_eq(+i: S.Schema, +xs: List<&2, J.Json>, +oki: {Spec.schema_ok(i) == True{} : Bool}) -> {Spec.all_items(i, xs) == Spec.meets(i, Spec.EveryItem{Spec.Holds{}}, J.JArray{xs}) : Bool}:
  match xs:
    case Nil{}: each_nil(i, Spec.Holds{})
    case h <> t:
      %Equal.sym(Bool, Spec.schema_ok(i), True{}, oki) : {((_ && Spec.meets(i, Spec.Holds{}, h)) && Spec.all_items(i, t)) == Spec.meets(i, Spec.EveryItem{Spec.Holds{}}, J.JArray{h <> t}) : Bool}
      %each_cons(i, Spec.Holds{}, h, t) : {(Spec.meets(i, Spec.Holds{}, h) && Spec.all_items(i, t)) == _ : Bool}
      %items_eq(i, t, oki) : {(Spec.meets(i, Spec.Holds{}, h) && Spec.all_items(i, t)) == (Spec.meets(i, Spec.Holds{}, h) && _) : Bool}
      {==}

def named_eq(+c: S.Schema, +k: String, +input: List<&2, J.Field>, +okc: {Spec.schema_ok(c) == True{} : Bool}) -> {Spec.all_named(c, k, input) == every(c, k, input) : Bool}:
  match input:
    case Nil{}: named_nil(c, k, Spec.Holds{})
    case J.Field{key, x} <> t:
      %Equal.sym(Bool, Spec.schema_ok(c), True{}, okc) : {((Bool.not(String.eq(key, k)) || (_ && Spec.meets(c, Spec.Holds{}, x))) && Spec.all_named(c, k, t)) == every(c, k, J.Field{key, x} <> t) : Bool}
      %named_cons(c, k, Spec.Holds{}, key, x, t) : {((Bool.not(String.eq(key, k)) || Spec.meets(c, Spec.Holds{}, x)) && Spec.all_named(c, k, t)) == _ : Bool}
      %named_eq(c, k, t, okc) : {((Bool.not(String.eq(key, k)) || Spec.meets(c, Spec.Holds{}, x)) && Spec.all_named(c, k, t)) == ((Bool.not(String.eq(key, k)) || Spec.meets(c, Spec.Holds{}, x)) && _) : Bool}
      {==}

def some_eq(+ms: List<&2, S.Schema>, +v: J.Json, +ok: {Spec.schema_ok(S.UnionSchema{ms}) == True{} : Bool}) -> {Spec.some_member(ms, v) == Spec.meets(S.UnionSchema{ms}, Spec.Holds{}, v) : Bool}:
  match ms:
    case Nil{}: {==}
    case m <> t:
      %Equal.sym(Bool, Spec.schema_ok(m), True{}, UP.and_left(Spec.schema_ok(m), Spec.schema_ok(S.UnionSchema{t}), ok)) : {((_ && Spec.meets(m, Spec.Holds{}, v)) || Spec.some_member(t, v)) == (Spec.meets(m, Spec.Holds{}, v) || Spec.meets(S.UnionSchema{t}, Spec.Holds{}, v)) : Bool}
      %some_eq(t, v, UP.and_right(Spec.schema_ok(m), Spec.schema_ok(S.UnionSchema{t}), ok)) : {(Spec.meets(m, Spec.Holds{}, v) || Spec.some_member(t, v)) == (Spec.meets(m, Spec.Holds{}, v) || _) : Bool}
      {==}

def spec_field_ok(+k: String, +c: S.Schema, +p: S.Presence, +t: List<&2, S.Field>, +u: S.Unknown, ok: {Spec.schema_ok(S.ObjectSchema{S.Field{k, c, p} <> t, u}) == True{} : Bool}) -> {Spec.schema_ok(c) == True{} : Bool}:
  UP.and_right(Spec.scalars(k) && Bool.not(Spec.declares(t, k)), Spec.schema_ok(c), UP.and_left(Spec.scalars(k) && Bool.not(Spec.declares(t, k)) && Spec.schema_ok(c), Spec.default_fits(c, p), UP.and_left(Spec.scalars(k) && Bool.not(Spec.declares(t, k)) && Spec.schema_ok(c) && Spec.default_fits(c, p), Spec.schema_ok(S.ObjectSchema{t, u}), ok)))

def spec_rest_ok(+k: String, +c: S.Schema, +p: S.Presence, +t: List<&2, S.Field>, +u: S.Unknown, ok: {Spec.schema_ok(S.ObjectSchema{S.Field{k, c, p} <> t, u}) == True{} : Bool}) -> {Spec.schema_ok(S.ObjectSchema{t, u}) == True{} : Bool}:
  UP.and_right(Spec.scalars(k) && Bool.not(Spec.declares(t, k)) && Spec.schema_ok(c) && Spec.default_fits(c, p), Spec.schema_ok(S.ObjectSchema{t, u}), ok)

def fields_all(+fs: List<&2, S.Field>, +u: S.Unknown, +input: List<&2, J.Field>, +ok: {Spec.schema_ok(S.ObjectSchema{fs, u}) == True{} : Bool}, +e: {Spec.meets(S.ObjectSchema{fs, u}, Spec.EveryField{}, J.JObject{input}) == True{} : Bool}) -> {Spec.all_fields(fs, input) == True{} : Bool}:
  match fs:
    case Nil{}: {==}
    case S.Field{k, c, p} <> t:
      %Equal.sym(Bool, Spec.all_named(c, k, input), True{}, Equal.trans(Bool, Spec.all_named(c, k, input), every(c, k, input), True{}, named_eq(c, k, input, spec_field_ok(k, c, p, t, u, ok)), UP.and_right(Spec.presence(p, Spec.named(input, k)), every(c, k, input), UP.and_left(Spec.presence(p, Spec.named(input, k)) && every(c, k, input), Spec.meets(S.ObjectSchema{t, u}, Spec.EveryField{}, J.JObject{input}), e)))) : {(_ && Spec.all_fields(t, input)) == True{} : Bool}
      fields_all(t, u, input, spec_rest_ok(k, c, p, t, u, ok), UP.and_right(Spec.presence(p, Spec.named(input, k)) && every(c, k, input), Spec.meets(S.ObjectSchema{t, u}, Spec.EveryField{}, J.JObject{input}), e))

def children_go(+s: S.Schema, +v: J.Json, +ok: {Spec.schema_ok(s) == True{} : Bool}, +e: {Spec.meets(s, Spec.Holds{}, v) == True{} : Bool}) -> {Spec.children(s, v) == True{} : Bool}:
  match s v:
    case S.StringSchema{a, b, c, d} x: {==}
    case S.NumberSchema{a, b} x: {==}
    case S.IntegerSchema{a, b} x: {==}
    case S.BooleanSchema{} x: {==}
    case S.LiteralSchema{a} x: {==}
    case S.EnumSchema{a} x: {==}
    case S.ArraySchema{i, m, n} J.JArray{xs}: Equal.trans(Bool, Spec.all_items(i, xs), Spec.meets(i, Spec.EveryItem{Spec.Holds{}}, J.JArray{xs}), True{}, items_eq(i, xs, UP.and_right(Spec.at_most(n, m), Spec.schema_ok(i), ok)), UP.and_right(Nat.is_le(m, Spec.size(xs)) && Spec.at_most(n, Spec.size(xs)), Spec.meets(i, Spec.EveryItem{Spec.Holds{}}, J.JArray{xs}), e))
    case S.ArraySchema{i, m, n} J.JNull{}: {==}
    case S.ArraySchema{i, m, n} J.JBool{b0}: {==}
    case S.ArraySchema{i, m, n} J.JNumber{b0}: {==}
    case S.ArraySchema{i, m, n} J.JString{b0}: {==}
    case S.ArraySchema{i, m, n} J.JObject{b0}: {==}
    case S.ObjectSchema{Nil{}, u} J.JObject{input}: {==}
    case S.ObjectSchema{S.Field{k, c, p} <> t, u} J.JObject{input}: fields_all(S.Field{k, c, p} <> t, u, input, ok, UP.and_right(Spec.allowed(u, S.Field{k, c, p} <> t, input), Spec.meets(S.ObjectSchema{S.Field{k, c, p} <> t, u}, Spec.EveryField{}, J.JObject{input}), e))
    case S.ObjectSchema{fs, u} J.JNull{}: {==}
    case S.ObjectSchema{fs, u} J.JBool{b0}: {==}
    case S.ObjectSchema{fs, u} J.JNumber{b0}: {==}
    case S.ObjectSchema{fs, u} J.JString{b0}: {==}
    case S.ObjectSchema{fs, u} J.JArray{b0}: {==}
    case S.NullableSchema{i} J.JNull{}: {==}
    case S.NullableSchema{i} J.JBool{b0}:
      %Equal.sym(Bool, Spec.schema_ok(i), True{}, ok) : {(_ && Spec.meets(i, Spec.Holds{}, J.JBool{b0})) == True{} : Bool}
      e
    case S.NullableSchema{i} J.JNumber{b0}:
      %Equal.sym(Bool, Spec.schema_ok(i), True{}, ok) : {(_ && Spec.meets(i, Spec.Holds{}, J.JNumber{b0})) == True{} : Bool}
      e
    case S.NullableSchema{i} J.JString{b0}:
      %Equal.sym(Bool, Spec.schema_ok(i), True{}, ok) : {(_ && Spec.meets(i, Spec.Holds{}, J.JString{b0})) == True{} : Bool}
      e
    case S.NullableSchema{i} J.JArray{b0}:
      %Equal.sym(Bool, Spec.schema_ok(i), True{}, ok) : {(_ && Spec.meets(i, Spec.Holds{}, J.JArray{b0})) == True{} : Bool}
      e
    case S.NullableSchema{i} J.JObject{b0}:
      %Equal.sym(Bool, Spec.schema_ok(i), True{}, ok) : {(_ && Spec.meets(i, Spec.Holds{}, J.JObject{b0})) == True{} : Bool}
      e
    case S.UnionSchema{ms} x: Equal.trans(Bool, Spec.some_member(ms, x), Spec.meets(S.UnionSchema{ms}, Spec.Holds{}, x), True{}, some_eq(ms, x, ok), e)

def satisfied(+s: S.Schema, +v: J.Json, +sat: {Spec.satisfies(s, v) == True{} : Bool}) -> {Spec.children(s, v) == True{} : Bool}:
  children_go(s, v, UP.and_left(Spec.schema_ok(s), Spec.meets(s, Spec.Holds{}, v), sat), UP.and_right(Spec.schema_ok(s), Spec.meets(s, Spec.Holds{}, v), sat))

def children_law(+s: S.Schema, +v: J.Json, acc: {S.accepted(S.decode(s, v)) == True{} : Bool}) -> {Spec.children(s, v) == True{} : Bool}:
  satisfied(s, v, Equal.trans(Bool, Spec.satisfies(s, v), S.accepted(S.decode(s, v)), True{}, Equal.sym(Bool, S.accepted(S.decode(s, v)), Spec.satisfies(s, v), acceptance_spec(s, v)), acc))
