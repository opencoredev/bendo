# The collector's case tree, shared by every induction in proof/schema-errors.bend.
# Usage: python3 errors-skeleton.py errors.py ../../proof/schema-errors.bend
SCALARS = ["S.StringSchema{a1, a2, a3, a4}", "S.NumberSchema{a1, a2}", "S.IntegerSchema{a1, a2}", "S.BooleanSchema{}", "S.LiteralSchema{a1}", "S.EnumSchema{a1}"]
V7 = ["J.JNull{}", "J.JBool{b0}", "J.JNumber{b0}", "J.JString{b0}", "J.JObject{b0}", "J.JArray{Nil{}}", "J.JArray{h <> t}"]
V6 = ["J.JNull{}", "J.JBool{b0}", "J.JNumber{b0}", "J.JString{b0}", "J.JArray{b0}", "J.JObject{b0}"]
XS = ["J.JNull{}", "J.JBool{b1}", "J.JNumber{b1}", "J.JString{b1}", "J.JObject{b1}", "J.JArray{Nil{}}", "J.JArray{g1 <> r1}"]
W_ITEMS = "S.WItems{kk, S.Out{r, ll}}"
W_FIELDS = "S.WFields{ss, S.Out{r, ll}}"
W_DONE = "S.WDone{S.Out{r, ll}}"
W_HERE = "S.WHere{l}"

def skeleton():
    """Yields (s, v, w, kind)."""
    for s in SCALARS:
        for v in XS:
            yield (s, v, W_HERE, "SCALAR")
        for w in [W_ITEMS, W_FIELDS, W_DONE]:
            yield (s, "x", w, "FB")
    A = "S.ArraySchema{i, m, n}"
    for v in V7:
        yield (A, v, W_HERE, "FB_HERE")
        yield (A, v, "S.WItems{k, S.Out{r, 0n}}", "ZERO")
        yield (A, v, "S.WItems{k, S.Out{r, 1n+l}}", "ARR_CONS" if v == "J.JArray{h <> t}" else ("ARR_NIL" if v == "J.JArray{Nil{}}" else "FB"))
        yield (A, v, W_FIELDS, "FB")
        yield (A, v, W_DONE, "FB")
    O0 = "S.ObjectSchema{Nil{}, u}"
    for v in XS:
        yield (O0, v, W_HERE, "FB_HERE")
    yield (O0, "x", W_ITEMS, "FB")
    yield (O0, "x", W_DONE, "FB")
    yield (O0, "x", "S.WFields{ss, S.Out{r, 0n}}", "ZERO")
    yield (O0, "x", "S.WFields{ss, S.Out{r, 1n+l}}", "OBJ_NIL")
    O1 = "S.ObjectSchema{S.Field{k, c, p} <> t, u}"
    for v in XS:
        yield (O1, v, W_HERE, "FB_HERE")
    yield (O1, "x", W_ITEMS, "FB")
    yield (O1, "x", W_DONE, "FB")
    for ssp in ["Nil{}", "S.Once{y} <> rest", "S.Absent{} <> rest", "S.Repeated{y} <> rest"]:
        yield (O1, "x", "S.WFields{%s, S.Out{r, 0n}}" % ssp, "ZERO")
    yield (O1, "x", "S.WFields{Nil{}, S.Out{r, 1n+l}}", "OBJ_SLOTNIL")
    yield (O1, "x", "S.WFields{S.Once{y} <> rest, S.Out{r, 1n+l}}", "ONCE")
    yield (O1, "x", "S.WFields{S.Absent{} <> rest, S.Out{r, 1n+l}}", "ABSENT")
    yield (O1, "x", "S.WFields{S.Repeated{y} <> rest, S.Out{r, 1n+l}}", "REPEATED")
    N = "S.NullableSchema{i}"
    for v in V6:
        yield (N, v, W_HERE, "NULL_NULL" if v == "J.JNull{}" else "NULL_X")
        for w in [W_ITEMS, W_FIELDS, W_DONE]:
            yield (N, v, w, "FB")
    U = "S.UnionSchema{ms}"
    for v in XS:
        yield (U, v, W_HERE, "UNION")
    for w in [W_ITEMS, W_FIELDS, W_DONE]:
        yield (U, "x", w, "FB")

import re
def plus(p):
    p = p.replace("1n+l", "1n+@L")
    p = re.sub(r"(?<![.\w+])([a-z][a-z0-9_]*)\b(?![{\w])", r"+\1", p)
    return p.replace("1n+@L", "1n+(+l)")

def lemma(header, body_fn):
    out = [header, "  match s v w:"]
    for (s, v, w, kind) in skeleton():
        b = body_fn(s, v, w, kind)
        s, v, w = plus(s), plus(v), plus(w)
        if "\n" in b:
            out.append("    case %s %s %s:\n%s" % (s, v, w, b))
        else:
            out.append("    case %s %s %s: %s" % (s, v, w, b))
    return "\n".join(out) + "\n"

if __name__ == "__main__":
    import sys, importlib.util
    spec = importlib.util.spec_from_file_location("lemmas", sys.argv[1])
    mod = importlib.util.module_from_spec(spec)
    mod.__dict__.update(dict(lemma=lemma, skeleton=skeleton))
    spec.loader.exec_module(mod)
    open(sys.argv[2], "w").write(mod.render())
