# Generates proof/schema-coerce.bend. Run from anywhere:
#   python3 scripts/schema-proofs/coerce.py
import os
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', '..', 'proof', 'schema-coerce.bend')
import re
SCALARS = ["S.StringSchema{a1, a2, a3, a4}", "S.NumberSchema{a1, a2}", "S.IntegerSchema{a1, a2}", "S.BooleanSchema{}", "S.LiteralSchema{a1}", "S.EnumSchema{a1}"]
CS = ["S.StringSchema{c1, c2, c3, c4}", "S.NumberSchema{c1, c2}", "S.IntegerSchema{c1, c2}", "S.BooleanSchema{}", "S.LiteralSchema{c1}", "S.EnumSchema{c1}", "S.ArraySchema{i, m, n}", "S.ObjectSchema{c1, c2}", "S.NullableSchema{c1}", "S.UnionSchema{c1}"]
SS = SCALARS + ["S.ArraySchema{i, m, n}", "S.ObjectSchema{Nil{}, u}"] + ["S.ObjectSchema{S.Field{k, %s, p} <> t, u}" % c for c in CS] + ["S.NullableSchema{i}", "S.UnionSchema{ms}"]
VS = ["J.JNull{}", "J.JBool{b0}", "J.JNumber{b0}", "J.JString{x}", "J.JArray{Nil{}}", "J.JArray{h <> hs}", "J.JObject{Nil{}}", "J.JObject{J.Field{key, y} <> ft}"]
WS = ["S.PValue{}", "S.PMap{rev}", "S.PEach{kk, rev}", "S.PGather{kk, g, f, rev}"]

def plus(p):
    return re.sub(r"(?<![.\w+])([a-z][a-z0-9_]*)\b(?![{\w])", r"+\1", p)

def body(s, v, w):
    if w == "S.PValue{}":
        if s in ("S.NumberSchema{a1, a2}", "S.IntegerSchema{a1, a2}") and v == "J.JString{x}":
            return "number_eq(x)"
        if s == "S.BooleanSchema{}" and v == "J.JString{x}":
            return 'flag_eq(String.eq(x, "true"), String.eq(x, "false"), x)'
        if s == "S.NullableSchema{i}":
            return "ceq(i, %s, S.PValue{})" % v
        if s == "S.ArraySchema{i, m, n}" and v.startswith("J.JArray"):
            return "Equal.trans(J.Json, S.coerce_go(i, %s, S.PMap{[]}), onto_items([], Spec.coerced(i, %s, Spec.Each{})), Spec.coerced(i, %s, Spec.Each{}), ceq(i, %s, S.PMap{[]}), onto_nil_items(Spec.coerced(i, %s, Spec.Each{})))" % ((v,)*5)
        if s.startswith("S.ObjectSchema{S.Field{k, S.ArraySchema") and v.startswith("J.JObject"):
            G_impl = "S.coerce_go(i, J.JArray{S.named_values(INPUT, k, [])}, S.PMap{[]})"
            G_spec = "Spec.coerced(i, J.JArray{Spec.values_named(INPUT, k)}, Spec.Each{})"
            X_impl = "S.coerce_go(i, J.JObject{INPUT}, S.PGather{k, %s, True{}, []})" % G_impl
            X_spec = "Spec.coerced(i, J.JObject{INPUT}, Spec.Merged{k, %s, True{}})" % G_spec
            hg = "Equal.trans(J.Json, %s, onto_items([], Spec.coerced(i, J.JArray{S.named_values(INPUT, k, [])}, Spec.Each{})), %s, ceq(i, J.JArray{S.named_values(INPUT, k, [])}, S.PMap{[]}), Equal.trans(J.Json, onto_items([], Spec.coerced(i, J.JArray{S.named_values(INPUT, k, [])}, Spec.Each{})), Spec.coerced(i, J.JArray{S.named_values(INPUT, k, [])}, Spec.Each{}), %s, onto_nil_items(Spec.coerced(i, J.JArray{S.named_values(INPUT, k, [])}, Spec.Each{})), Equal.cong(List<&2, J.Json>, J.Json, z => Spec.coerced(i, J.JArray{z}, Spec.Each{}), S.named_values(INPUT, k, []), Spec.values_named(INPUT, k), values_eq(INPUT, k))))" % (G_impl, G_spec, G_spec)
            hx = "Equal.trans(J.Json, %s, onto_members([], Spec.coerced(i, J.JObject{INPUT}, Spec.Merged{k, %s, True{}})), %s, ceq(i, J.JObject{INPUT}, S.PGather{k, %s, True{}, []}), Equal.trans(J.Json, onto_members([], Spec.coerced(i, J.JObject{INPUT}, Spec.Merged{k, %s, True{}})), Spec.coerced(i, J.JObject{INPUT}, Spec.Merged{k, %s, True{}}), %s, onto_nil_members(Spec.coerced(i, J.JObject{INPUT}, Spec.Merged{k, %s, True{}})), Equal.cong(J.Json, J.Json, z => Spec.coerced(i, J.JObject{INPUT}, Spec.Merged{k, z, True{}}), %s, %s, %s)))" % (X_impl, G_impl, X_spec, G_impl, G_impl, G_impl, X_spec, G_impl, G_impl, G_spec, hg)
            inp = "[]" if v == "J.JObject{Nil{}}" else "J.Field{key, y} <> ft"
            code = "      %%Equal.sym(J.Json, %s, %s, %s) : {S.coerce_go(S.ObjectSchema{t, u}, _, S.PValue{}) == Spec.coerced(S.ObjectSchema{t, u}, %s, Spec.Whole{}) : J.Json}\n      ceq(S.ObjectSchema{t, u}, %s, S.PValue{})" % (X_impl, X_spec, hx, X_spec, X_spec)
            return code.replace("INPUT", inp)
        if s.startswith("S.ObjectSchema{S.Field{k, ") and v.startswith("J.JObject"):
            c = s[len("S.ObjectSchema{S.Field{k, "):s.index(", p} <> t, u}")]
            inp = "[]" if v == "J.JObject{Nil{}}" else "J.Field{key, y} <> ft"
            X_impl = "S.coerce_go(%s, J.JObject{%s}, S.PEach{k, []})" % (c, inp)
            X_spec = "Spec.coerced(%s, J.JObject{%s}, Spec.Members{k})" % (c, inp)
            hx = "Equal.trans(J.Json, %s, onto_members([], %s), %s, ceq(%s, J.JObject{%s}, S.PEach{k, []}), onto_nil_members(%s))" % (X_impl, X_spec, X_spec, c, inp, X_spec)
            return "      %%Equal.sym(J.Json, %s, %s, %s) : {S.coerce_go(S.ObjectSchema{t, u}, _, S.PValue{}) == Spec.coerced(S.ObjectSchema{t, u}, %s, Spec.Whole{}) : J.Json}\n      ceq(S.ObjectSchema{t, u}, %s, S.PValue{})" % (X_impl, X_spec, hx, X_spec, X_spec)
        return "{=="+"}"
    if w == "S.PMap{rev}":
        if v == "J.JArray{h <> hs}":
            c_impl = "S.coerce_go(%s, h, S.PValue{})" % s
            c_spec = "Spec.coerced(%s, h, Spec.Whole{})" % s
            R = "Spec.coerced(%s, J.JArray{hs}, Spec.Each{})" % s
            impl = "S.coerce_go(%s, J.JArray{hs}, S.PMap{%s <> rev})" % (s, c_impl)
            return ("      %%Equal.sym(J.Json, onto_items(rev, Spec.cons_item(%s, %s)), onto_items(%s <> rev, %s), onto_cons_items(%s, rev, %s)) : {%s == _ : J.Json}\n" % (c_spec, R, c_spec, R, c_spec, R, impl)
                  + "      %%ceq(%s, h, S.PValue{}) : {%s == onto_items(_ <> rev, %s) : J.Json}\n" % (s, impl, R)
                  + "      ceq(%s, J.JArray{hs}, S.PMap{%s <> rev})" % (s, c_impl))
        return "{=="+"}"
    if w == "S.PEach{kk, rev}":
        if v == "J.JObject{J.Field{key, y} <> ft}":
            c_impl = "S.coerce_go(%s, y, S.PValue{})" % s
            c_spec = "Spec.coerced(%s, y, Spec.Whole{})" % s
            R = "Spec.coerced(%s, J.JObject{ft}, Spec.Members{kk})" % s
            pick_s = "Bool.pick(J.Field, String.eq(key, kk), J.Field{key, %s}, J.Field{key, y})" % c_spec
            pick_i = "Bool.pick(J.Field, String.eq(key, kk), J.Field{key, %s}, J.Field{key, y})" % c_impl
            mp = "S.member_pick(String.eq(key, kk), key, y, %s)" % c_impl
            impl = "S.coerce_go(%s, J.JObject{ft}, S.PEach{kk, %s <> rev})" % (s, mp)
            return ("      %%Equal.sym(J.Json, onto_members(rev, Spec.cons_member(%s, %s)), onto_members(%s <> rev, %s), onto_cons_members(%s, rev, %s)) : {%s == _ : J.Json}\n" % (pick_s, R, pick_s, R, pick_s, R, impl)
                  + "      %%ceq(%s, y, S.PValue{}) : {%s == onto_members(Bool.pick(J.Field, String.eq(key, kk), J.Field{key, _}, J.Field{key, y}) <> rev, %s) : J.Json}\n" % (s, impl, R)
                  + "      %%Equal.sym(J.Field, %s, %s, pick_eq(String.eq(key, kk), key, y, %s)) : {%s == onto_members(_ <> rev, %s) : J.Json}\n" % (pick_i, mp, c_impl, impl, R)
                  + "      ceq(%s, J.JObject{ft}, S.PEach{kk, %s <> rev})" % (s, mp))
        return "{=="+"}"
    if w == "S.PGather{kk, g, f, rev}":
        if v == "J.JObject{J.Field{key, y} <> ft}":
            return "gather_eq(%s, ft, key, y, kk, g, rev, String.eq(key, kk), f)(ceq(%s, J.JObject{ft}, S.gather_step(String.eq(key, kk), f, key, y, kk, g, rev)))" % (s, s)
        return "{=="+"}"
    raise Exception(w)

out = [open(os.path.join(HERE, 'coerce-head.bend')).read(), "\n# Each state of `coerce_go` returns what `want` says.\ndef ceq(+s: S.Schema, +v: J.Json, +w: S.Pass) -> {S.coerce_go(s, v, w) == want(s, v, w) : J.Json}:", "  match s v w:"]
for s in SS:
    for v in VS:
        for w in WS:
            b = body(s, v, w)
            pat = "    case %s %s %s:" % (plus(s), plus(v), plus(w))
            out.append(pat + ("\n" + b if "\n" in b else " " + b))
out.append('''
# BND-35 law: text coercion is the specification's coercion.
def coerce_spec(+s: S.Schema, +v: J.Json) -> {S.coerce(s, v) == Spec.coerce_text(s, v) : J.Json}:
  ceq(s, v, S.PValue{})
''')
open(OUT,'w').write("\n".join(out))

extra = '''
# Decoding a text source is decoding its specified coercion.
def text_spec(+s: S.Schema, +v: J.Json) -> {S.decode_from(S.TextSource{}, s, v) == S.decode(s, Spec.coerce_text(s, v)) : Result<&2, &2, S.Errors(), S.Value>}:
  %Equal.sym(J.Json, S.coerce(s, v), Spec.coerce_text(s, v), coerce_spec(s, v)) : {S.decode(s, _) == S.decode(s, Spec.coerce_text(s, v)) : Result<&2, &2, S.Errors(), S.Value>}
  {==}

def text_acceptance(+s: S.Schema, +v: J.Json) -> {S.accepted(S.decode_from(S.TextSource{}, s, v)) == Spec.satisfies(s, Spec.coerce_text(s, v)) : Bool}:
  %Equal.sym(Result<&2, &2, S.Errors(), S.Value>, S.decode_from(S.TextSource{}, s, v), S.decode(s, Spec.coerce_text(s, v)), text_spec(s, v)) : {S.accepted(_) == Spec.satisfies(s, Spec.coerce_text(s, v)) : Bool}
  SC.acceptance_spec(s, Spec.coerce_text(s, v))

def text_preservation(+s: S.Schema, +v: J.Json) -> S.Preserves(S.value_for(s, Spec.coerce_text(s, v)), S.decode_from(S.TextSource{}, s, v)):
  %Equal.sym(Result<&2, &2, S.Errors(), S.Value>, S.decode_from(S.TextSource{}, s, v), S.decode(s, Spec.coerce_text(s, v)), text_spec(s, v)) : S.Preserves(S.value_for(s, Spec.coerce_text(s, v)), _)
  SC.preservation(s, Spec.coerce_text(s, v))

def text_located(+s: S.Schema, +v: J.Json) -> {Spec.located_errors(s, Spec.coerce_text(s, v), S.decode_from(S.TextSource{}, s, v)) == True{} : Bool}:
  %Equal.sym(Result<&2, &2, S.Errors(), S.Value>, S.decode_from(S.TextSource{}, s, v), S.decode(s, Spec.coerce_text(s, v)), text_spec(s, v)) : {Spec.located_errors(s, Spec.coerce_text(s, v), _) == True{} : Bool}
  SE.errors_located(s, Spec.coerce_text(s, v))

def text_complete(+s: S.Schema, +v: J.Json, +path: List<&2, S.PathPart>, he: {Spec.error_at(s, Spec.coerce_text(s, v), path) == True{} : Bool}) -> {Spec.reported(S.decode_from(S.TextSource{}, s, v), path) == True{} : Bool}:
  %Equal.sym(Result<&2, &2, S.Errors(), S.Value>, S.decode_from(S.TextSource{}, s, v), S.decode(s, Spec.coerce_text(s, v)), text_spec(s, v)) : {Spec.reported(_, path) == True{} : Bool}
  SE.errors_complete(s, Spec.coerce_text(s, v), path, he)
'''
src = open(OUT).read()
src = src.replace("import ./schema-number.bend as NP\n", "import ./schema-number.bend as NP\nimport ./schema-compound.bend as SC\nimport ./schema-errors.bend as SE\n")
open(OUT,'w').write(src + extra)
