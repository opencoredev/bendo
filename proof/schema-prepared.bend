# The prepared decoder (src/data/schema-prepared.bend) is the schema decoder:
# each step follows S.decode_go / S.collect_go case for case, and a prepared
# pattern scans with the table A.prepare built and checked, which is
# A.matches term for term.
import Base
import ../src/data/schema.bend as S
import ../src/data/schema-prepared.bend as SP
import ../src/data/schema-pattern-automaton.bend as A
import ../src/data/schema-pattern.bend as P
import ../src/data/json.bend as J
import ../src/data/decimal.bend as D

def Res() -> Data:
  Result<&2, &2, S.Errors(), S.Value>

def whole_prepare(+s: S.Schema) -> {SP.whole(SP.prepare(s)) == s : S.Schema}:
  match s:
    case S.StringSchema{a, b, c, d}: {==}
    case S.NumberSchema{a, b}: {==}
    case S.IntegerSchema{a, b}: {==}
    case S.BooleanSchema{}: {==}
    case S.LiteralSchema{a}: {==}
    case S.EnumSchema{a}: {==}
    case S.ArraySchema{i, m, n}: {==}
    case S.ObjectSchema{Nil{}, u}: {==}
    case S.ObjectSchema{S.Field{k, c, p} <> t, u}: {==}
    case S.NullableSchema{i}: {==}
    case S.UnionSchema{Nil{}}: {==}
    case S.UnionSchema{m <> t}: {==}

def start_prepare(+s: S.Schema, +v: J.Json) -> {SP.start(SP.prepare(s), v) == S.start(s, v) : S.Acc}:
  Equal.cong(S.Schema, S.Acc, z => S.start(z, v), SP.whole(SP.prepare(s)), s, whole_prepare(s))

def cstart_prepare(+s: S.Schema, +v: J.Json, +l: Nat) -> {SP.cstart(SP.prepare(s), v, l) == S.cstart(s, v, l) : S.Walk}:
  Equal.cong(S.Schema, S.Walk, z => S.cstart(z, v, l), SP.whole(SP.prepare(s)), s, whole_prepare(s))

# A prepared pattern answers what the pattern answers.
def after_eq(ok: Bool, +c: Maybe<&2, P.Pattern>, +f: S.Format, +x: String) -> {SP.pattern_after(ok, SP.prepare_pattern(c), f, x) == S.pattern_after(ok, c, f, x) : Bool}:
  match ok:
    case False{}: {==}
    case True{}:
      match c:
        case None{}: {==}
        case Some{q}: {==}

def string_value_eq(+a: Nat, +b: Maybe<&2, Nat>, +c: Maybe<&2, P.Pattern>, +d: S.Format, +v: J.Json) -> {SP.string_value(a, b, SP.prepare_pattern(c), d, v) == S.decode_scalar(S.StringSchema{a, b, c, d}, v) : Res()}:
  match v:
    case J.JNull{}: {==}
    case J.JBool{x}: {==}
    case J.JNumber{x}: {==}
    case J.JArray{x}: {==}
    case J.JObject{x}: {==}
    case J.JString{x}:
      +ok = J.scalars(x) && Nat.is_le(a, D.length(x)) && S.max_length(b, D.length(x))
      Equal.cong(Bool, Res(), z => S.finish(S.VString{x}, z), SP.pattern_after(ok, SP.prepare_pattern(c), d, x), S.pattern_after(ok, c, d, x), after_eq(ok, c, d, x))
def decode_eq(+s: S.Schema, +v: J.Json, +acc: S.Acc) -> {SP.decode_go(SP.prepare(s), v, acc) == S.decode_go(s, v, acc) : Res()}:
  match s:
    case S.StringSchema{a, b, c, d}: string_value_eq(a, b, c, d, v)
    case S.NumberSchema{a, b}: {==}
    case S.IntegerSchema{a, b}: {==}
    case S.BooleanSchema{}: {==}
    case S.LiteralSchema{a}: {==}
    case S.EnumSchema{a}: {==}
    case S.ArraySchema{i, m, n}:
      match v:
        case J.JNull{}:
          match acc:
            case S.AItems{k, Fail{e}}: {==}
            case S.AItems{k, Done{rev}}: {==}
            case S.AScalar{}: {==}
            case S.AFields{st, ss}: {==}
            case S.AMembers{n2, i2, st}: {==}
        case J.JBool{x}:
          match acc:
            case S.AItems{k, Fail{e}}: {==}
            case S.AItems{k, Done{rev}}: {==}
            case S.AScalar{}: {==}
            case S.AFields{st, ss}: {==}
            case S.AMembers{n2, i2, st}: {==}
        case J.JNumber{x}:
          match acc:
            case S.AItems{k, Fail{e}}: {==}
            case S.AItems{k, Done{rev}}: {==}
            case S.AScalar{}: {==}
            case S.AFields{st, ss}: {==}
            case S.AMembers{n2, i2, st}: {==}
        case J.JString{x}:
          match acc:
            case S.AItems{k, Fail{e}}: {==}
            case S.AItems{k, Done{rev}}: {==}
            case S.AScalar{}: {==}
            case S.AFields{st, ss}: {==}
            case S.AMembers{n2, i2, st}: {==}
        case J.JArray{Nil{}}:
          match acc:
            case S.AItems{k, Fail{e}}: {==}
            case S.AItems{k, Done{rev}}: {==}
            case S.AScalar{}: {==}
            case S.AFields{st, ss}: {==}
            case S.AMembers{n2, i2, st}: {==}
        case J.JArray{h <> t}:
          match acc:
            case S.AItems{k, Fail{e}}: {==}
            case S.AItems{k, Done{rev}}:
              e = Equal.trans(Res(), SP.decode_go(SP.prepare(i), h, SP.start(SP.prepare(i), h)), SP.decode_go(SP.prepare(i), h, S.start(i, h)), S.decode_go(i, h, S.start(i, h)), Equal.cong(S.Acc, Res(), z => SP.decode_go(SP.prepare(i), h, z), SP.start(SP.prepare(i), h), S.start(i, h), start_prepare(i, h)), decode_eq(i, h, S.start(i, h)))
              %e : {SP.decode_go(SP.prepare(S.ArraySchema{i, m, n}), J.JArray{t}, S.AItems{1n+k, S.push(rev, S.at(S.PathIndex{k}, SP.decode_go(SP.prepare(i), h, SP.start(SP.prepare(i), h))))}) == S.decode_go(S.ArraySchema{i, m, n}, J.JArray{t}, S.AItems{1n+k, S.push(rev, S.at(S.PathIndex{k}, _))}) : Res()}
              decode_eq(S.ArraySchema{i, m, n}, J.JArray{t}, S.AItems{1n+k, S.push(rev, S.at(S.PathIndex{k}, SP.decode_go(SP.prepare(i), h, SP.start(SP.prepare(i), h))))})
            case S.AScalar{}: {==}
            case S.AFields{st, ss}: {==}
            case S.AMembers{n2, i2, st}: {==}
        case J.JObject{fs}:
          match acc:
            case S.AItems{k, Fail{e}}: {==}
            case S.AItems{k, Done{rev}}: {==}
            case S.AScalar{}: {==}
            case S.AFields{st, ss}: {==}
            case S.AMembers{n2, i2, st}: {==}
    case S.ObjectSchema{Nil{}, u}:
      match acc:
        case S.AFields{Fail{e}, ss}: {==}
        case S.AFields{Done{rev}, ss}: {==}
        case S.AScalar{}: {==}
        case S.AItems{k2, st}: {==}
        case S.AMembers{n2, i2, st}: {==}
    case S.ObjectSchema{S.Field{k, c, p} <> t, u}:
      match acc:
        case S.AFields{Fail{e}, ss}: {==}
        case S.AFields{Done{rev}, Nil{}}: {==}
        case S.AFields{Done{rev}, S.Once{y} <> rest}:
          e = Equal.trans(Res(), SP.decode_go(SP.prepare(c), y, SP.start(SP.prepare(c), y)), SP.decode_go(SP.prepare(c), y, S.start(c, y)), S.decode_go(c, y, S.start(c, y)), Equal.cong(S.Acc, Res(), z => SP.decode_go(SP.prepare(c), y, z), SP.start(SP.prepare(c), y), S.start(c, y), start_prepare(c, y)), decode_eq(c, y, S.start(c, y)))
          %e : {SP.decode_go(SP.prepare(S.ObjectSchema{t, u}), v, S.AFields{S.push_field(rev, k, S.at(S.PathKey{k}, SP.decode_go(SP.prepare(c), y, SP.start(SP.prepare(c), y)))), rest}) == S.decode_go(S.ObjectSchema{t, u}, v, S.AFields{S.push_field(rev, k, S.at(S.PathKey{k}, _)), rest}) : Res()}
          decode_eq(S.ObjectSchema{t, u}, v, S.AFields{S.push_field(rev, k, S.at(S.PathKey{k}, SP.decode_go(SP.prepare(c), y, SP.start(SP.prepare(c), y)))), rest})
        case S.AFields{Done{rev}, S.Absent{} <> rest}:
          e = Equal.trans(Res(), SP.decode_go(SP.prepare(c), S.default_of(p), SP.start(SP.prepare(c), S.default_of(p))), SP.decode_go(SP.prepare(c), S.default_of(p), S.start(c, S.default_of(p))), S.decode_go(c, S.default_of(p), S.start(c, S.default_of(p))), Equal.cong(S.Acc, Res(), z => SP.decode_go(SP.prepare(c), S.default_of(p), z), SP.start(SP.prepare(c), S.default_of(p)), S.start(c, S.default_of(p)), start_prepare(c, S.default_of(p))), decode_eq(c, S.default_of(p), S.start(c, S.default_of(p))))
          %e : {SP.decode_go(SP.prepare(S.ObjectSchema{t, u}), v, S.AFields{S.absent(rev, k, p, S.at(S.PathKey{k}, SP.decode_go(SP.prepare(c), S.default_of(p), SP.start(SP.prepare(c), S.default_of(p))))), rest}) == S.decode_go(S.ObjectSchema{t, u}, v, S.AFields{S.absent(rev, k, p, S.at(S.PathKey{k}, _)), rest}) : Res()}
          decode_eq(S.ObjectSchema{t, u}, v, S.AFields{S.absent(rev, k, p, S.at(S.PathKey{k}, SP.decode_go(SP.prepare(c), S.default_of(p), SP.start(SP.prepare(c), S.default_of(p))))), rest})
        case S.AFields{Done{rev}, S.Repeated{y} <> rest}: {==}
        case S.AScalar{}: {==}
        case S.AItems{k2, st}: {==}
        case S.AMembers{n2, i2, st}: {==}
    case S.NullableSchema{i}:
      match v:
        case J.JNull{}: {==}
        case J.JBool{x}: Equal.trans(Res(), SP.decode_go(SP.prepare(i), J.JBool{x}, SP.start(SP.prepare(i), J.JBool{x})), SP.decode_go(SP.prepare(i), J.JBool{x}, S.start(i, J.JBool{x})), S.decode_go(i, J.JBool{x}, S.start(i, J.JBool{x})), Equal.cong(S.Acc, Res(), z => SP.decode_go(SP.prepare(i), J.JBool{x}, z), SP.start(SP.prepare(i), J.JBool{x}), S.start(i, J.JBool{x}), start_prepare(i, J.JBool{x})), decode_eq(i, J.JBool{x}, S.start(i, J.JBool{x})))
        case J.JNumber{x}: Equal.trans(Res(), SP.decode_go(SP.prepare(i), J.JNumber{x}, SP.start(SP.prepare(i), J.JNumber{x})), SP.decode_go(SP.prepare(i), J.JNumber{x}, S.start(i, J.JNumber{x})), S.decode_go(i, J.JNumber{x}, S.start(i, J.JNumber{x})), Equal.cong(S.Acc, Res(), z => SP.decode_go(SP.prepare(i), J.JNumber{x}, z), SP.start(SP.prepare(i), J.JNumber{x}), S.start(i, J.JNumber{x}), start_prepare(i, J.JNumber{x})), decode_eq(i, J.JNumber{x}, S.start(i, J.JNumber{x})))
        case J.JString{x}: Equal.trans(Res(), SP.decode_go(SP.prepare(i), J.JString{x}, SP.start(SP.prepare(i), J.JString{x})), SP.decode_go(SP.prepare(i), J.JString{x}, S.start(i, J.JString{x})), S.decode_go(i, J.JString{x}, S.start(i, J.JString{x})), Equal.cong(S.Acc, Res(), z => SP.decode_go(SP.prepare(i), J.JString{x}, z), SP.start(SP.prepare(i), J.JString{x}), S.start(i, J.JString{x}), start_prepare(i, J.JString{x})), decode_eq(i, J.JString{x}, S.start(i, J.JString{x})))
        case J.JArray{xs}: Equal.trans(Res(), SP.decode_go(SP.prepare(i), J.JArray{xs}, SP.start(SP.prepare(i), J.JArray{xs})), SP.decode_go(SP.prepare(i), J.JArray{xs}, S.start(i, J.JArray{xs})), S.decode_go(i, J.JArray{xs}, S.start(i, J.JArray{xs})), Equal.cong(S.Acc, Res(), z => SP.decode_go(SP.prepare(i), J.JArray{xs}, z), SP.start(SP.prepare(i), J.JArray{xs}), S.start(i, J.JArray{xs}), start_prepare(i, J.JArray{xs})), decode_eq(i, J.JArray{xs}, S.start(i, J.JArray{xs})))
        case J.JObject{fs}: Equal.trans(Res(), SP.decode_go(SP.prepare(i), J.JObject{fs}, SP.start(SP.prepare(i), J.JObject{fs})), SP.decode_go(SP.prepare(i), J.JObject{fs}, S.start(i, J.JObject{fs})), S.decode_go(i, J.JObject{fs}, S.start(i, J.JObject{fs})), Equal.cong(S.Acc, Res(), z => SP.decode_go(SP.prepare(i), J.JObject{fs}, z), SP.start(SP.prepare(i), J.JObject{fs}), S.start(i, J.JObject{fs}), start_prepare(i, J.JObject{fs})), decode_eq(i, J.JObject{fs}, S.start(i, J.JObject{fs})))
    case S.UnionSchema{Nil{}}:
      match acc:
        case S.AMembers{n, i, Done{y}}: {==}
        case S.AMembers{n, i, Fail{e}}: {==}
        case S.AScalar{}: {==}
        case S.AItems{k2, st}: {==}
        case S.AFields{st, ss}: {==}
    case S.UnionSchema{m <> t}:
      match acc:
        case S.AMembers{n, i, Done{y}}: {==}
        case S.AMembers{n, i, Fail{e}}:
          e2 = Equal.trans(Res(), SP.decode_go(SP.prepare(m), v, SP.start(SP.prepare(m), v)), SP.decode_go(SP.prepare(m), v, S.start(m, v)), S.decode_go(m, v, S.start(m, v)), Equal.cong(S.Acc, Res(), z => SP.decode_go(SP.prepare(m), v, z), SP.start(SP.prepare(m), v), S.start(m, v), start_prepare(m, v)), decode_eq(m, v, S.start(m, v)))
          %e2 : {SP.decode_go(SP.prepare(S.UnionSchema{t}), v, S.AMembers{1n+n, n, SP.decode_go(SP.prepare(m), v, SP.start(SP.prepare(m), v))}) == S.decode_go(S.UnionSchema{t}, v, S.AMembers{1n+n, n, _}) : Res()}
          decode_eq(S.UnionSchema{t}, v, S.AMembers{1n+n, n, SP.decode_go(SP.prepare(m), v, SP.start(SP.prepare(m), v))})
        case S.AScalar{}: {==}
        case S.AItems{k2, st}: {==}
        case S.AFields{st, ss}: {==}

def collect_eq(+s: S.Schema, +v: J.Json, +w: S.Walk) -> {SP.collect_go(SP.prepare(s), v, w) == S.collect_go(s, v, w) : S.Out}:
  match s:
    case S.StringSchema{a, b, c, d}:
      match w:
        case S.WHere{l}: Equal.cong(Res(), S.Out, z => S.scalar_out(z, l), SP.string_value(a, b, SP.prepare_pattern(c), d, v), S.decode_scalar(S.StringSchema{a, b, c, d}, v), string_value_eq(a, b, c, d, v))
        case S.WItems{k2, o}: {==}
        case S.WFields{ss, o}: {==}
        case S.WDone{o}: {==}
    case S.NumberSchema{a, b}:
      match w:
        case S.WHere{l}: {==}
        case S.WItems{k2, o}: {==}
        case S.WFields{ss, o}: {==}
        case S.WDone{o}: {==}
    case S.IntegerSchema{a, b}:
      match w:
        case S.WHere{l}: {==}
        case S.WItems{k2, o}: {==}
        case S.WFields{ss, o}: {==}
        case S.WDone{o}: {==}
    case S.BooleanSchema{}:
      match w:
        case S.WHere{l}: {==}
        case S.WItems{k2, o}: {==}
        case S.WFields{ss, o}: {==}
        case S.WDone{o}: {==}
    case S.LiteralSchema{a}:
      match w:
        case S.WHere{l}: {==}
        case S.WItems{k2, o}: {==}
        case S.WFields{ss, o}: {==}
        case S.WDone{o}: {==}
    case S.EnumSchema{a}:
      match w:
        case S.WHere{l}: {==}
        case S.WItems{k2, o}: {==}
        case S.WFields{ss, o}: {==}
        case S.WDone{o}: {==}
    case S.ArraySchema{i, m, n}:
      match v:
        case J.JNull{}:
          match w:
            case S.WItems{k, S.Out{rev, 0n}}: {==}
            case S.WItems{k, S.Out{rev, 1n+l}}: {==}
            case S.WHere{l}: {==}
            case S.WFields{ss, o}: {==}
            case S.WDone{o}: {==}
        case J.JBool{x}:
          match w:
            case S.WItems{k, S.Out{rev, 0n}}: {==}
            case S.WItems{k, S.Out{rev, 1n+l}}: {==}
            case S.WHere{l}: {==}
            case S.WFields{ss, o}: {==}
            case S.WDone{o}: {==}
        case J.JNumber{x}:
          match w:
            case S.WItems{k, S.Out{rev, 0n}}: {==}
            case S.WItems{k, S.Out{rev, 1n+l}}: {==}
            case S.WHere{l}: {==}
            case S.WFields{ss, o}: {==}
            case S.WDone{o}: {==}
        case J.JString{x}:
          match w:
            case S.WItems{k, S.Out{rev, 0n}}: {==}
            case S.WItems{k, S.Out{rev, 1n+l}}: {==}
            case S.WHere{l}: {==}
            case S.WFields{ss, o}: {==}
            case S.WDone{o}: {==}
        case J.JArray{Nil{}}:
          match w:
            case S.WItems{k, S.Out{rev, 0n}}: {==}
            case S.WItems{k, S.Out{rev, 1n+l}}: {==}
            case S.WHere{l}: {==}
            case S.WFields{ss, o}: {==}
            case S.WDone{o}: {==}
        case J.JArray{h <> t}:
          match w:
            case S.WItems{k, S.Out{rev, 0n}}: {==}
            case S.WItems{k, S.Out{rev, 1n+l}}:
              e = Equal.trans(S.Out, SP.collect_go(SP.prepare(i), h, SP.cstart(SP.prepare(i), h, 1n+l)), SP.collect_go(SP.prepare(i), h, S.cstart(i, h, 1n+l)), S.collect_go(i, h, S.cstart(i, h, 1n+l)), Equal.cong(S.Walk, S.Out, z => SP.collect_go(SP.prepare(i), h, z), SP.cstart(SP.prepare(i), h, 1n+l), S.cstart(i, h, 1n+l), cstart_prepare(i, h, 1n+l)), collect_eq(i, h, S.cstart(i, h, 1n+l)))
              %e : {SP.collect_go(SP.prepare(S.ArraySchema{i, m, n}), J.JArray{t}, S.WItems{1n+k, S.merge(S.PathIndex{k}, SP.collect_go(SP.prepare(i), h, SP.cstart(SP.prepare(i), h, 1n+l)), rev)}) == S.collect_go(S.ArraySchema{i, m, n}, J.JArray{t}, S.WItems{1n+k, S.merge(S.PathIndex{k}, _, rev)}) : S.Out}
              collect_eq(S.ArraySchema{i, m, n}, J.JArray{t}, S.WItems{1n+k, S.merge(S.PathIndex{k}, SP.collect_go(SP.prepare(i), h, SP.cstart(SP.prepare(i), h, 1n+l)), rev)})
            case S.WHere{l}: {==}
            case S.WFields{ss, o}: {==}
            case S.WDone{o}: {==}
        case J.JObject{fs}:
          match w:
            case S.WItems{k, S.Out{rev, 0n}}: {==}
            case S.WItems{k, S.Out{rev, 1n+l}}: {==}
            case S.WHere{l}: {==}
            case S.WFields{ss, o}: {==}
            case S.WDone{o}: {==}
    case S.ObjectSchema{Nil{}, u}:
      match w:
        case S.WFields{ss, S.Out{rev, 0n}}: {==}
        case S.WFields{ss, S.Out{rev, 1n+l}}: {==}
        case S.WHere{l}: {==}
        case S.WItems{k2, o}: {==}
        case S.WDone{o}: {==}
    case S.ObjectSchema{S.Field{k, c, p} <> t, u}:
      match w:
        case S.WFields{ss, S.Out{rev, 0n}}: {==}
        case S.WFields{Nil{}, S.Out{rev, 1n+l}}: {==}
        case S.WFields{S.Once{y} <> rest, S.Out{rev, 1n+l}}:
          e = Equal.trans(S.Out, SP.collect_go(SP.prepare(c), y, SP.cstart(SP.prepare(c), y, 1n+l)), SP.collect_go(SP.prepare(c), y, S.cstart(c, y, 1n+l)), S.collect_go(c, y, S.cstart(c, y, 1n+l)), Equal.cong(S.Walk, S.Out, z => SP.collect_go(SP.prepare(c), y, z), SP.cstart(SP.prepare(c), y, 1n+l), S.cstart(c, y, 1n+l), cstart_prepare(c, y, 1n+l)), collect_eq(c, y, S.cstart(c, y, 1n+l)))
          %e : {SP.collect_go(SP.prepare(S.ObjectSchema{t, u}), v, S.WFields{rest, S.merge(S.PathKey{k}, SP.collect_go(SP.prepare(c), y, SP.cstart(SP.prepare(c), y, 1n+l)), rev)}) == S.collect_go(S.ObjectSchema{t, u}, v, S.WFields{rest, S.merge(S.PathKey{k}, _, rev)}) : S.Out}
          collect_eq(S.ObjectSchema{t, u}, v, S.WFields{rest, S.merge(S.PathKey{k}, SP.collect_go(SP.prepare(c), y, SP.cstart(SP.prepare(c), y, 1n+l)), rev)})
        case S.WFields{S.Absent{} <> rest, S.Out{rev, 1n+l}}:
          collect_eq(S.ObjectSchema{t, u}, v, S.WFields{rest, S.emit(S.may_be_absent(p), S.Error{S.Constraint{}, "missing required key", [S.PathKey{k}]}, S.Out{rev, 1n+l})})
        case S.WFields{S.Repeated{y} <> rest, S.Out{rev, 1n+l}}:
          collect_eq(S.ObjectSchema{t, u}, v, S.WFields{rest, S.Out{S.Error{S.Constraint{}, "duplicate key", [S.PathKey{k}]} <> rev, l}})
        case S.WHere{l}: {==}
        case S.WItems{k2, o}: {==}
        case S.WDone{o}: {==}
    case S.NullableSchema{i}:
      match v:
        case J.JNull{}:
          match w:
            case S.WHere{l}: {==}
            case S.WItems{k2, o}: {==}
            case S.WFields{ss, o}: {==}
            case S.WDone{o}: {==}
        case J.JBool{x}:
          match w:
            case S.WHere{l}: Equal.trans(S.Out, SP.collect_go(SP.prepare(i), J.JBool{x}, SP.cstart(SP.prepare(i), J.JBool{x}, l)), SP.collect_go(SP.prepare(i), J.JBool{x}, S.cstart(i, J.JBool{x}, l)), S.collect_go(i, J.JBool{x}, S.cstart(i, J.JBool{x}, l)), Equal.cong(S.Walk, S.Out, z => SP.collect_go(SP.prepare(i), J.JBool{x}, z), SP.cstart(SP.prepare(i), J.JBool{x}, l), S.cstart(i, J.JBool{x}, l), cstart_prepare(i, J.JBool{x}, l)), collect_eq(i, J.JBool{x}, S.cstart(i, J.JBool{x}, l)))
            case S.WItems{k2, o}: {==}
            case S.WFields{ss, o}: {==}
            case S.WDone{o}: {==}
        case J.JNumber{x}:
          match w:
            case S.WHere{l}: Equal.trans(S.Out, SP.collect_go(SP.prepare(i), J.JNumber{x}, SP.cstart(SP.prepare(i), J.JNumber{x}, l)), SP.collect_go(SP.prepare(i), J.JNumber{x}, S.cstart(i, J.JNumber{x}, l)), S.collect_go(i, J.JNumber{x}, S.cstart(i, J.JNumber{x}, l)), Equal.cong(S.Walk, S.Out, z => SP.collect_go(SP.prepare(i), J.JNumber{x}, z), SP.cstart(SP.prepare(i), J.JNumber{x}, l), S.cstart(i, J.JNumber{x}, l), cstart_prepare(i, J.JNumber{x}, l)), collect_eq(i, J.JNumber{x}, S.cstart(i, J.JNumber{x}, l)))
            case S.WItems{k2, o}: {==}
            case S.WFields{ss, o}: {==}
            case S.WDone{o}: {==}
        case J.JString{x}:
          match w:
            case S.WHere{l}: Equal.trans(S.Out, SP.collect_go(SP.prepare(i), J.JString{x}, SP.cstart(SP.prepare(i), J.JString{x}, l)), SP.collect_go(SP.prepare(i), J.JString{x}, S.cstart(i, J.JString{x}, l)), S.collect_go(i, J.JString{x}, S.cstart(i, J.JString{x}, l)), Equal.cong(S.Walk, S.Out, z => SP.collect_go(SP.prepare(i), J.JString{x}, z), SP.cstart(SP.prepare(i), J.JString{x}, l), S.cstart(i, J.JString{x}, l), cstart_prepare(i, J.JString{x}, l)), collect_eq(i, J.JString{x}, S.cstart(i, J.JString{x}, l)))
            case S.WItems{k2, o}: {==}
            case S.WFields{ss, o}: {==}
            case S.WDone{o}: {==}
        case J.JArray{xs}:
          match w:
            case S.WHere{l}: Equal.trans(S.Out, SP.collect_go(SP.prepare(i), J.JArray{xs}, SP.cstart(SP.prepare(i), J.JArray{xs}, l)), SP.collect_go(SP.prepare(i), J.JArray{xs}, S.cstart(i, J.JArray{xs}, l)), S.collect_go(i, J.JArray{xs}, S.cstart(i, J.JArray{xs}, l)), Equal.cong(S.Walk, S.Out, z => SP.collect_go(SP.prepare(i), J.JArray{xs}, z), SP.cstart(SP.prepare(i), J.JArray{xs}, l), S.cstart(i, J.JArray{xs}, l), cstart_prepare(i, J.JArray{xs}, l)), collect_eq(i, J.JArray{xs}, S.cstart(i, J.JArray{xs}, l)))
            case S.WItems{k2, o}: {==}
            case S.WFields{ss, o}: {==}
            case S.WDone{o}: {==}
        case J.JObject{fs}:
          match w:
            case S.WHere{l}: Equal.trans(S.Out, SP.collect_go(SP.prepare(i), J.JObject{fs}, SP.cstart(SP.prepare(i), J.JObject{fs}, l)), SP.collect_go(SP.prepare(i), J.JObject{fs}, S.cstart(i, J.JObject{fs}, l)), S.collect_go(i, J.JObject{fs}, S.cstart(i, J.JObject{fs}, l)), Equal.cong(S.Walk, S.Out, z => SP.collect_go(SP.prepare(i), J.JObject{fs}, z), SP.cstart(SP.prepare(i), J.JObject{fs}, l), S.cstart(i, J.JObject{fs}, l), cstart_prepare(i, J.JObject{fs}, l)), collect_eq(i, J.JObject{fs}, S.cstart(i, J.JObject{fs}, l)))
            case S.WItems{k2, o}: {==}
            case S.WFields{ss, o}: {==}
            case S.WDone{o}: {==}
    case S.UnionSchema{Nil{}}:
      match w:
        case S.WHere{l}:
          e = Equal.trans(Res(), SP.decode_go(SP.prepare(S.UnionSchema{[]}), v, SP.start(SP.prepare(S.UnionSchema{[]}), v)), SP.decode_go(SP.prepare(S.UnionSchema{[]}), v, S.start(S.UnionSchema{[]}, v)), S.decode_go(S.UnionSchema{[]}, v, S.start(S.UnionSchema{[]}, v)), Equal.cong(S.Acc, Res(), z => SP.decode_go(SP.prepare(S.UnionSchema{[]}), v, z), SP.start(SP.prepare(S.UnionSchema{[]}), v), S.start(S.UnionSchema{[]}, v), start_prepare(S.UnionSchema{[]}, v)), decode_eq(S.UnionSchema{[]}, v, S.start(S.UnionSchema{[]}, v)))
          Equal.cong(Res(), S.Out, z => S.emit(S.accepted(z), S.Error{S.Constraint{}, "value matches no union member", []}, S.Out{[], l}), SP.decode_go(SP.prepare(S.UnionSchema{[]}), v, SP.start(SP.prepare(S.UnionSchema{[]}), v)), S.decode_go(S.UnionSchema{[]}, v, S.start(S.UnionSchema{[]}, v)), e)
        case S.WItems{k2, o}: {==}
        case S.WFields{ss, o}: {==}
        case S.WDone{o}: {==}
    case S.UnionSchema{m <> t}:
      match w:
        case S.WHere{l}:
          e = Equal.trans(Res(), SP.decode_go(SP.prepare(S.UnionSchema{m <> t}), v, SP.start(SP.prepare(S.UnionSchema{m <> t}), v)), SP.decode_go(SP.prepare(S.UnionSchema{m <> t}), v, S.start(S.UnionSchema{m <> t}, v)), S.decode_go(S.UnionSchema{m <> t}, v, S.start(S.UnionSchema{m <> t}, v)), Equal.cong(S.Acc, Res(), z => SP.decode_go(SP.prepare(S.UnionSchema{m <> t}), v, z), SP.start(SP.prepare(S.UnionSchema{m <> t}), v), S.start(S.UnionSchema{m <> t}, v), start_prepare(S.UnionSchema{m <> t}, v)), decode_eq(S.UnionSchema{m <> t}, v, S.start(S.UnionSchema{m <> t}, v)))
          Equal.cong(Res(), S.Out, z => S.emit(S.accepted(z), S.Error{S.Constraint{}, "value matches no union member", []}, S.Out{[], l}), SP.decode_go(SP.prepare(S.UnionSchema{m <> t}), v, SP.start(SP.prepare(S.UnionSchema{m <> t}), v)), S.decode_go(S.UnionSchema{m <> t}, v, S.start(S.UnionSchema{m <> t}, v)), e)
        case S.WItems{k2, o}: {==}
        case S.WFields{ss, o}: {==}
        case S.WDone{o}: {==}

# A failure reports the same error list.
def errors_eq(+s: S.Schema, +v: J.Json, ok: Bool) -> {SP.errors(SP.prepare(s), v, ok) == S.errors(s, v, ok) : List<&2, S.Error>}:
  match ok:
    case False{}: {==}
    case True{}:
      e = Equal.trans(S.Out, SP.collect_go(SP.prepare(s), v, SP.cstart(SP.prepare(s), v, S.error_cap())), SP.collect_go(SP.prepare(s), v, S.cstart(s, v, S.error_cap())), S.collect_go(s, v, S.cstart(s, v, S.error_cap())), Equal.cong(S.Walk, S.Out, z => SP.collect_go(SP.prepare(s), v, z), SP.cstart(SP.prepare(s), v, S.error_cap()), S.cstart(s, v, S.error_cap()), cstart_prepare(s, v, S.error_cap())), collect_eq(s, v, S.cstart(s, v, S.error_cap())))
      Equal.cong(S.Out, List<&2, S.Error>, z => S.listed(z), SP.collect_go(SP.prepare(s), v, SP.cstart(SP.prepare(s), v, S.error_cap())), S.collect_go(s, v, S.cstart(s, v, S.error_cap())), e)

def report_eq(+r: Res(), +s: S.Schema, +v: J.Json, +ok: Bool, e: {S.valid(s) == ok : Bool}) -> {SP.report(r, SP.prepare(s), v, ok) == S.report(r, s, v) : Res()}:
  match r:
    case Done{x}: {==}
    case Fail{es}:
      %Equal.sym(Bool, S.valid(s), ok, e) : {Fail{SP.errors(SP.prepare(s), v, ok)} == Fail{S.errors(s, v, _)} : Res()}
      Equal.cong(List<&2, S.Error>, Res(), z => Fail{z}, SP.errors(SP.prepare(s), v, ok), S.errors(s, v, ok), errors_eq(s, v, ok))

def valid_eq(+s: S.Schema, +v: J.Json, ok: Bool) -> {SP.decode_valid(SP.prepare(s), v, ok) == S.decode_valid(s, v, ok) : Res()}:
  match ok:
    case False{}: {==}
    case True{}:
      Equal.trans(Res(), SP.decode_go(SP.prepare(s), v, SP.start(SP.prepare(s), v)), SP.decode_go(SP.prepare(s), v, S.start(s, v)), S.decode_go(s, v, S.start(s, v)), Equal.cong(S.Acc, Res(), z => SP.decode_go(SP.prepare(s), v, z), SP.start(SP.prepare(s), v), S.start(s, v), start_prepare(s, v)), decode_eq(s, v, S.start(s, v)))

# The prepared decoder is the decoder, for every schema and value.
def decode_check(+s: S.Schema, +v: J.Json) -> {SP.decode(SP.check(s), v) == S.decode(s, v) : Res()}:
  %Equal.sym(Res(), SP.decode_valid(SP.prepare(s), v, S.valid(s)), S.decode_valid(s, v, S.valid(s)), valid_eq(s, v, S.valid(s))) : {SP.report(_, SP.prepare(s), v, S.valid(s)) == S.report(S.decode_valid(s, v, S.valid(s)), s, v) : Res()}
  report_eq(S.decode_valid(s, v, S.valid(s)), s, v, S.valid(s), {==})

def decode_from_check(src: S.Source, +s: S.Schema, +v: J.Json) -> {SP.decode_from(src, SP.check(s), v) == S.decode_from(src, s, v) : Res()}:
  match src:
    case S.JsonBody{}: decode_check(s, v)
    case S.TextSource{}: decode_check(s, S.coerce(s, v))
