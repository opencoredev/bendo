# Generates proof/schema-errors-exact.bend (BND-89). Run from the repo root:
#   python3 scripts/schema-proofs/exact.py proof/schema-errors-exact.bend
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))

SCALARS = ["S.StringSchema{a1, a2, a3, a4}", "S.NumberSchema{a1, a2}", "S.IntegerSchema{a1, a2}", "S.BooleanSchema{}", "S.LiteralSchema{a1}", "S.EnumSchema{a1}"]
# Every Schema shape `Spec.failures` can split on.
SCHEMAS = SCALARS + ["S.ArraySchema{a1, a2, a3}", "S.ObjectSchema{Nil{}, a2}", "S.ObjectSchema{S.Field{a1, a3, a4} <> a5, a2}", "S.NullableSchema{a1}", "S.UnionSchema{a1}"]
V7 = ["J.JNull{}", "J.JBool{b0}", "J.JNumber{b0}", "J.JString{b0}", "J.JObject{b0}", "J.JArray{Nil{}}", "J.JArray{h <> t}"]
XS = ["J.JNull{}", "J.JBool{b1}", "J.JNumber{b1}", "J.JString{b1}", "J.JObject{b1}", "J.JArray{Nil{}}", "J.JArray{g1 <> r1}"]
W_ITEMS = "S.WItems{kk, S.Out{r, ll}}"
W_FIELDS = "S.WFields{ss, S.Out{r, ll}}"
W_DONE = "S.WDone{S.Out{r, ll}}"
W_HERE = "S.WHere{l}"
ARR = "S.ArraySchema{i, m, n}"
OBJ = "S.ObjectSchema{t, u}"
PS = "List<&2, List<&2, S.PathPart>>"
ERR_MISSING = 'S.Error{S.Constraint{}, "missing required key", [S.PathKey{k}]}'
ERR_DUP = 'S.Error{S.Constraint{}, "duplicate key", [S.PathKey{k}]}'


def skeleton():
    """Yields (s, v, w, kind) for every state of the collector."""
    for s in SCALARS:
        for v in XS:
            yield (s, v, W_HERE, "SCALAR")
        for w in [W_ITEMS, W_FIELDS, W_DONE]:
            yield (s, "x", w, "FB")
    for v in V7:
        yield (ARR, v, W_HERE, "FB_HERE")
        yield (ARR, v, "S.WItems{k, S.Out{r, 0n}}", "ZERO")
        yield (ARR, v, "S.WItems{k, S.Out{r, 1n+l}}", "ARR_CONS" if v == "J.JArray{h <> t}" else ("ARR_NIL" if v == "J.JArray{Nil{}}" else "FB"))
        yield (ARR, v, W_FIELDS, "FB")
        yield (ARR, v, W_DONE, "FB")
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
    for v in XS:
        yield (N, v, W_HERE, "NULL_NULL" if v == "J.JNull{}" else "NULL_X")
        for w in [W_ITEMS, W_FIELDS, W_DONE]:
            yield (N, v, w, "FB")
    U = "S.UnionSchema{ms}"
    for v in XS:
        yield (U, v, W_HERE, "UNION")
    for w in [W_ITEMS, W_FIELDS, W_DONE]:
        yield (U, "x", w, "FB")


def plus(p):
    p = p.replace("1n+l", "1n+@L")
    p = re.sub(r"(?<![.\w+])([a-z][a-z0-9_]*)\b(?![{\w])", r"+\1", p)
    return p.replace("1n+@L", "1n+(+l)")


def child(s, v, l, okv):
    return "child(%s, %s, %s, exact(%s, %s, S.cstart(%s, %s, %s), %s))" % (s, v, l, s, v, s, v, l, okv)


def exact_body(s, v, w, kind):
    if kind == "SCALAR":
        return "scalar_exact(%s, %s, l, okv)" % (s, v)
    if kind in ("FB", "OBJ_NIL", "OBJ_SLOTNIL", "NULL_NULL"):
        return "{==}"
    if kind == "FB_HERE":
        return "kind_exact(l)"
    if kind == "ZERO":
        rem = "rem(%s, %s, %s)" % (s, v, w)
        return "Equal.sym(PO, fill(%s, PO{Spec.paths(r), 0n}), PO{Spec.paths(r), 0n}, fill_zero(%s, Spec.paths(r)))" % (rem, rem)
    if kind == "ARR_NIL":
        f = "Spec.failures(i, J.JArray{[]}, Spec.Items{k})"
        return "Equal.cong(%s, PO, z => fill(z, PO{Spec.paths(r), 1n+l}), [], %s, Equal.sym(%s, %s, [], items_nil(i, k)))" % (PS, f, PS, f)
    if kind == "ARR_CONS":
        C = "S.collect_go(i, h, S.cstart(i, h, 1n+l))"
        M = "S.merge(S.PathIndex{k}, %s, r)" % C
        W = "S.WItems{1n+k, %s}" % M
        lhs = "proj(S.collect_go(%s, J.JArray{t}, %s))" % (ARR, W)
        fh = "Spec.failures(i, h, Spec.Node{})"
        a = "Spec.under(S.PathIndex{k}, %s)" % fh
        b = "Spec.failures(i, J.JArray{t}, Spec.Items{1n+k})"
        j = "Spec.join(%s, %s)" % (a, b)
        f = "Spec.failures(i, J.JArray{h <> t}, Spec.Items{k})"
        o = "PO{Spec.paths(r), 1n+l}"
        step = "seq(%s, %s, %s, %s, proj(%s), exact(%s, J.JArray{t}, %s, okv), merge_step(S.PathIndex{k}, %s, r, %s, 1n+l, %s))" % (lhs, a, b, o, M, ARR, W, C, fh, child("i", "h", "1n+l", "SC.item_valid(i, m, n, okv)"))
        return "Equal.trans(PO, %s, fill(%s, %s), fill(%s, %s), %s, Equal.cong(%s, PO, z => fill(z, %s), %s, %s, Equal.sym(%s, %s, %s, items_cons(i, h, t, k))))" % (lhs, j, o, f, o, step, PS, o, j, f, PS, f, j)
    rv = "SC.rest_valid(k, c, p, t, u, okv)"
    o = "PO{Spec.paths(r), 1n+l}"
    if kind == "ONCE":
        C = "S.collect_go(c, y, S.cstart(c, y, 1n+l))"
        M = "S.merge(S.PathKey{k}, %s, r)" % C
        W = "S.WFields{rest, %s}" % M
        lhs = "proj(S.collect_go(%s, x, %s))" % (OBJ, W)
        fc = "Spec.failures(c, y, Spec.Node{})"
        return "seq(%s, Spec.under(S.PathKey{k}, %s), field_rem(t, rest), %s, proj(%s), exact(%s, x, %s, %s), merge_step(S.PathKey{k}, %s, r, %s, 1n+l, %s))" % (lhs, fc, o, M, OBJ, W, rv, C, fc, child("c", "y", "1n+l", "SC.field_valid(k, c, p, t, u, okv)"))
    if kind == "ABSENT":
        E = "S.emit(S.may_be_absent(p), %s, S.Out{r, 1n+l})" % ERR_MISSING
        W = "S.WFields{rest, %s}" % E
        lhs = "proj(S.collect_go(%s, x, %s))" % (OBJ, W)
        return "seq(%s, absent_rem(p, k), field_rem(t, rest), %s, proj(%s), exact(%s, x, %s, %s), absent_fill(p, k, r, l))" % (lhs, o, E, OBJ, W, rv)
    if kind == "REPEATED":
        W = "S.WFields{rest, S.Out{%s <> r, l}}" % ERR_DUP
        lhs = "proj(S.collect_go(%s, x, %s))" % (OBJ, W)
        return "seq(%s, [[S.PathKey{k}]], field_rem(t, rest), %s, PO{[S.PathKey{k}] <> Spec.paths(r), l}, exact(%s, x, %s, %s), {==})" % (lhs, o, OBJ, W, rv)
    if kind == "NULL_X":
        return child("i", v, "l", "okv")
    if kind == "UNION":
        return "union_exact(ms, %s, l, okv)" % v
    raise Exception(kind)


def exact_lemma():
    out = ["# Every state lists what it starts with, filled with what it still has to visit.",
           "def exact(+s: S.Schema, +v: J.Json, +w: S.Walk, +okv: {S.valid(s) == True{} : Bool}) -> {proj(S.collect_go(s, v, w)) == fill(rem(s, v, w), wstart(w)) : PO}:",
           "  match s v w:"]
    for (s, v, w, kind) in skeleton():
        out.append("    case %s %s %s: %s" % (plus(s), plus(v), plus(w), exact_body(s, v, w, kind)))
    return "\n".join(out) + "\n"


def items_unfold():
    cons = "def items_cons(+i: S.Schema, +h: J.Json, +t: List<&2, J.Json>, +k: Nat) -> {Spec.failures(i, J.JArray{h <> t}, Spec.Items{k}) == Spec.join(Spec.under(S.PathIndex{k}, Spec.failures(i, h, Spec.Node{})), Spec.failures(i, J.JArray{t}, Spec.Items{1n+k})) : %s}:\n  match i:\n" % PS
    cons += "".join("    case %s: {==}\n" % s for s in SCHEMAS)
    nil = "def items_nil(+i: S.Schema, +k: Nat) -> {Spec.failures(i, J.JArray{[]}, Spec.Items{k}) == [] : %s}:\n  match i:\n" % PS
    nil += "".join("    case %s: {==}\n" % s for s in SCHEMAS)
    return cons + "\n" + nil


def entry():
    out = ["# A child's starting state: an array's length gate, an object's undeclared",
           "# members and slots, or the value itself.",
           "def entry(+s: S.Schema, +v: J.Json, +l: Nat) -> {fill(rem(s, v, S.cstart(s, v, l)), wstart(S.cstart(s, v, l))) == fill(Spec.failures(s, v, Spec.Node{}), PO{[], l}) : PO}:",
           "  match s v:"]
    others = ["J.JNull{}", "J.JBool{b0}", "J.JNumber{b0}", "J.JString{b0}"]
    out.append("    case S.ArraySchema{+i, +m, +n} J.JArray{Nil{}}: arr_entry(i, m, n, [], l)")
    out.append("    case S.ArraySchema{+i, +m, +n} J.JArray{+g <> +r}: arr_entry(i, m, n, g <> r, l)")
    for v in others + ["J.JObject{b0}"]:
        out.append("    case S.ArraySchema{i, m, n} %s: {==}" % v)
    out.append("    case S.ObjectSchema{Nil{}, +u} J.JObject{+input}: unknown_fill(u, [], input, l)")
    out.append("    case S.ObjectSchema{S.Field{+k, +c, +p} <> +t, +u} J.JObject{+input}: obj_entry(S.Field{k, c, p} <> t, u, input, l)")
    for o in ["S.ObjectSchema{Nil{}, u}", "S.ObjectSchema{S.Field{k, c, p} <> t, u}"]:
        for v in others + ["J.JArray{Nil{}}", "J.JArray{g <> r}"]:
            out.append("    case %s %s: {==}" % (o, v))
    for s in SCALARS + ["S.NullableSchema{i}", "S.UnionSchema{ms}"]:
        out.append("    case %s y: {==}" % s)
    return "\n".join(out) + "\n"


def render():
    head = open(os.path.join(HERE, "exact-head.bend")).read()
    tail = open(os.path.join(HERE, "exact-tail.bend")).read()
    head = head.replace("ITEMS_UNFOLD\n", items_unfold()).replace("ENTRY\n", entry())
    return head + "\n" + exact_lemma() + "\n" + tail


if __name__ == "__main__":
    open(sys.argv[1], "w").write(render())
