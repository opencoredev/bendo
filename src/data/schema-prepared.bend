# Schemas prepared once for repeated decoding (BND-36). `check(s)` runs the
# schema validity check and builds every pattern's automaton table up front, so
# a route pays for them when its table is built rather than on every request.
# The decoder below walks the prepared tree exactly the way `S.decode_go` and
# `S.collect_go` walk the schema; each node keeps the schema it was prepared
# from, so every non-pattern step calls the original helper on it.
# `decode_from(src, check(s), v)` equals `S.decode_from(src, s, v)` (law
# schema_prepared_decode), so every BND-33/34/35 law carries over.
import Base
import ./schema.bend as S
import ./schema-pattern-automaton.bend as A
import ./schema-pattern.bend as P
import ./json.bend as J
import ./decimal.bend as D

type PSchema is Data:
  PString{whole: S.Schema, min_len: Nat, max_len: Maybe<&2, Nat>, pattern: Maybe<&2, A.Prepared>, format: S.Format}
  PPlain{whole: S.Schema}
  PArray{whole: S.Schema, items: PSchema, min_items: Nat, max_items: Maybe<&2, Nat>}
  PObjNil{whole: S.Schema}
  PObjCons{whole: S.Schema, key: String, child: PSchema, presence: S.Presence, rest: PSchema}
  PNullable{whole: S.Schema, inner: PSchema}
  PUnionNil{whole: S.Schema}
  PUnionCons{whole: S.Schema, member: PSchema, rest: PSchema}

def prepare_pattern(p: Maybe<&2, P.Pattern>) -> Maybe<&2, A.Prepared>:
  match p:
    case None{}: None{}
    case Some{+q}: Some{A.prepare(q)}

# An object or union is a chain whose tail is the prepared schema with one
# field or member fewer, the schema the decoder continues on.
def prepare(+s: S.Schema) -> PSchema:
  match s:
    case S.StringSchema{+a, +b, +c, +d}: PString{S.StringSchema{a, b, c, d}, a, b, prepare_pattern(c), d}
    case S.NumberSchema{a, b}: PPlain{S.NumberSchema{a, b}}
    case S.IntegerSchema{a, b}: PPlain{S.IntegerSchema{a, b}}
    case S.BooleanSchema{}: PPlain{S.BooleanSchema{}}
    case S.LiteralSchema{a}: PPlain{S.LiteralSchema{a}}
    case S.EnumSchema{a}: PPlain{S.EnumSchema{a}}
    case S.ArraySchema{+i, +m, +n}: PArray{S.ArraySchema{i, m, n}, prepare(i), m, n}
    case S.ObjectSchema{Nil{}, u}: PObjNil{S.ObjectSchema{[], u}}
    case S.ObjectSchema{S.Field{+k, +c, +p} <> +t, +u}: PObjCons{S.ObjectSchema{S.Field{k, c, p} <> t, u}, k, prepare(c), p, prepare(S.ObjectSchema{t, u})}
    case S.NullableSchema{+i}: PNullable{S.NullableSchema{i}, prepare(i)}
    case S.UnionSchema{Nil{}}: PUnionNil{S.UnionSchema{[]}}
    case S.UnionSchema{+m <> +t}: PUnionCons{S.UnionSchema{m <> t}, prepare(m), prepare(S.UnionSchema{t})}

def whole(ps: PSchema) -> S.Schema:
  match ps:
    case PString{w, a, b, c, d}: w
    case PPlain{w}: w
    case PArray{w, i, m, n}: w
    case PObjNil{w}: w
    case PObjCons{w, k, c, p, t}: w
    case PNullable{w, i}: w
    case PUnionNil{w}: w
    case PUnionCons{w, m, t}: w

def start(ps: PSchema, v: J.Json) -> S.Acc:
  S.start(whole(ps), v)

def cstart(ps: PSchema, v: J.Json, left: Nat) -> S.Walk:
  S.cstart(whole(ps), v, left)

# The string checks of S.string_check, in the same order, with the table.
def pattern_check(p: Maybe<&2, A.Prepared>, s: String) -> Bool:
  match p:
    case None{}: True{}
    case Some{t}: A.run_prepared(t, s)

def pattern_after(ok: Bool, p: Maybe<&2, A.Prepared>, f: S.Format, +s: String) -> Bool:
  match ok:
    case False{}: False{}
    case True{}: S.format_after(pattern_check(p, s), f, s)

def string_check(min: Nat, max: Maybe<&2, Nat>, p: Maybe<&2, A.Prepared>, f: S.Format, +s: String) -> Bool:
  pattern_after(J.scalars(s) && Nat.is_le(min, D.length(s)) && S.max_length(max, D.length(s)), p, f, s)

def string_value(min: Nat, max: Maybe<&2, Nat>, p: Maybe<&2, A.Prepared>, f: S.Format, v: J.Json) -> Result<&2, &2, S.Errors(), S.Value>:
  match v:
    case J.JString{+x}: S.finish(S.VString{x}, string_check(min, max, p, f, x))
    case _: S.failure(S.TypeMismatch{}, "expected schema scalar kind")

def decode_go(ps: PSchema, v: J.Json, acc: S.Acc) -> Result<&2, &2, S.Errors(), S.Value>:
  match ps v acc:
    case PString{w, a, b, c, d} x y: string_value(a, b, c, d, x)
    case PPlain{w} x y: S.decode_scalar(w, x)
    case PArray{w, i, m, n} _ S.AItems{k, Fail{e}}: Fail{e}
    case PArray{w, i, m, n} J.JArray{Nil{}} S.AItems{k, Done{rev}}: Done{S.VArray{List.reverse(&2, S.Value, rev)}}
    case PArray{+w, +i, +m, +n} J.JArray{+h <> t} S.AItems{+k, Done{rev}}: decode_go(PArray{w, i, m, n}, J.JArray{t}, S.AItems{1n+k, S.push(rev, S.at(S.PathIndex{k}, decode_go(i, h, start(i, h))))})
    case PObjNil{w} _ S.AFields{Fail{e}, ss}: Fail{e}
    case PObjCons{w, k, c, p, t} _ S.AFields{Fail{e}, ss}: Fail{e}
    case PObjNil{w} _ S.AFields{Done{rev}, ss}: Done{S.VObject{List.reverse(&2, S.VField, rev)}}
    case PObjCons{w, +k, +c, p, t} x S.AFields{Done{rev}, S.Once{+y} <> rest}: decode_go(t, x, S.AFields{S.push_field(rev, k, S.at(S.PathKey{k}, decode_go(c, y, start(c, y)))), rest})
    case PObjCons{w, +k, +c, +p, t} x S.AFields{Done{rev}, S.Absent{} <> rest}: decode_go(t, x, S.AFields{S.absent(rev, k, p, S.at(S.PathKey{k}, decode_go(c, S.default_of(p), start(c, S.default_of(p))))), rest})
    case PObjCons{w, k, c, p, t} x S.AFields{Done{rev}, S.Repeated{y} <> rest}: Fail{[S.Error{S.Constraint{}, "duplicate key", [S.PathKey{k}]}]}
    case PObjCons{w, k, c, p, t} x S.AFields{Done{rev}, Nil{}}: S.failure(S.InvalidSchema{}, "object fields out of step")
    case PNullable{w, +i} J.JNull{} y: Done{S.VNull{}}
    case PNullable{w, +i} +x y: decode_go(i, x, start(i, x))
    case PUnionNil{w} x S.AMembers{n, i, Done{y}}: Done{S.VUnion{i, y}}
    case PUnionCons{w, m, t} x S.AMembers{n, i, Done{y}}: Done{S.VUnion{i, y}}
    case PUnionNil{w} x S.AMembers{n, i, Fail{e}}: S.failure(S.Constraint{}, "value matches no union member")
    case PUnionCons{w, +m, t} +x S.AMembers{+n, i, Fail{e}}: decode_go(t, x, S.AMembers{1n+n, n, decode_go(m, x, start(m, x))})
    case _ _ _: S.failure(S.TypeMismatch{}, "expected schema kind")

def collect_go(ps: PSchema, v: J.Json, w: S.Walk) -> S.Out:
  match ps v w:
    case PString{z, a, b, c, d} x S.WHere{l}: S.scalar_out(string_value(a, b, c, d, x), l)
    case PPlain{z} x S.WHere{l}: S.scalar_out(S.decode_scalar(z, x), l)
    case PArray{z, i, m, n} x S.WItems{k, S.Out{rev, 0n}}: S.Out{rev, 0n}
    case PArray{+z, +i, +m, +n} J.JArray{+h <> t} S.WItems{+k, S.Out{rev, 1n+l}}: collect_go(PArray{z, i, m, n}, J.JArray{t}, S.WItems{1n+k, S.merge(S.PathIndex{k}, collect_go(i, h, cstart(i, h, 1n+l)), rev)})
    case PObjNil{z} x S.WFields{ss, S.Out{rev, 0n}}: S.Out{rev, 0n}
    case PObjCons{z, k, c, p, t} x S.WFields{ss, S.Out{rev, 0n}}: S.Out{rev, 0n}
    case PObjCons{z, +k, +c, p, t} x S.WFields{S.Once{+y} <> rest, S.Out{rev, 1n+l}}: collect_go(t, x, S.WFields{rest, S.merge(S.PathKey{k}, collect_go(c, y, cstart(c, y, 1n+l)), rev)})
    case PObjCons{z, +k, c, p, t} x S.WFields{S.Absent{} <> rest, S.Out{rev, 1n+l}}: collect_go(t, x, S.WFields{rest, S.emit(S.may_be_absent(p), S.Error{S.Constraint{}, "missing required key", [S.PathKey{k}]}, S.Out{rev, 1n+l})})
    case PObjCons{z, k, c, p, t} x S.WFields{S.Repeated{y} <> rest, S.Out{rev, 1n+l}}: collect_go(t, x, S.WFields{rest, S.Out{S.Error{S.Constraint{}, "duplicate key", [S.PathKey{k}]} <> rev, l}})
    case PNullable{z, i} J.JNull{} S.WHere{l}: S.Out{[], l}
    case PNullable{z, +i} +x S.WHere{l}: collect_go(i, x, cstart(i, x, l))
    case PUnionNil{+z} +x S.WHere{l}: S.emit(S.accepted(decode_go(PUnionNil{z}, x, start(PUnionNil{z}, x))), S.Error{S.Constraint{}, "value matches no union member", []}, S.Out{[], l})
    case PUnionCons{+z, +m, +t} +x S.WHere{l}: S.emit(S.accepted(decode_go(PUnionCons{z, m, t}, x, start(PUnionCons{z, m, t}, x))), S.Error{S.Constraint{}, "value matches no union member", []}, S.Out{[], l})
    case _ _ w: S.walk_out(w)

# A schema with its validity and its prepared tree, computed once.
type Checked is Data:
  Checked{schema: S.Schema, ok: Bool, tree: PSchema}

def check(+s: S.Schema) -> Checked:
  Checked{s, S.valid(s), prepare(s)}

def schema(c: Checked) -> S.Schema:
  match c:
    case Checked{s, ok, t}: s

def decode_valid(+t: PSchema, +v: J.Json, ok: Bool) -> Result<&2, &2, S.Errors(), S.Value>:
  match ok:
    case True{}: decode_go(t, v, start(t, v))
    case False{}: S.failure(S.InvalidSchema{}, "invalid schema")

def errors(+t: PSchema, +v: J.Json, ok: Bool) -> List<&2, S.Error>:
  match ok:
    case True{}: S.listed(collect_go(t, v, cstart(t, v, S.error_cap())))
    case False{}: [S.Error{S.InvalidSchema{}, "invalid schema", []}]

def report(r: Result<&2, &2, S.Errors(), S.Value>, +t: PSchema, +v: J.Json, ok: Bool) -> Result<&2, &2, S.Errors(), S.Value>:
  match r:
    case Done{x}: Done{x}
    case Fail{e}: Fail{errors(t, v, ok)}

def decoded(+t: PSchema, +v: J.Json, +ok: Bool) -> Result<&2, &2, S.Errors(), S.Value>:
  report(decode_valid(t, v, ok), t, v, ok)

# S.decode with the prepared tree: every failure, at most error_cap(), with paths.
def decode(c: Checked, +v: J.Json) -> Result<&2, &2, S.Errors(), S.Value>:
  match c:
    case Checked{s, ok, t}: decoded(t, v, ok)

def decode_from(src: S.Source, c: Checked, v: J.Json) -> Result<&2, &2, S.Errors(), S.Value>:
  match src c:
    case S.JsonBody{} Checked{s, ok, t}: decoded(t, v, ok)
    case S.TextSource{} Checked{+s, ok, t}: decoded(t, S.coerce(s, v), ok)
