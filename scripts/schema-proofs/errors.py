# Lemma bodies for proof/schema-errors.bend. Regenerate from the repo root with
#   python3 scripts/schema-proofs/errors-skeleton.py scripts/schema-proofs/errors.py proof/schema-errors.bend
import os
HERE = os.path.dirname(os.path.abspath(__file__))


def frame_body(s, v, w, kind):
    if w == "S.WHere{l}":
        return "extend_nil(S.collect_go(%s, %s, S.WHere{l}))" % (s, v)
    if kind in ("FB", "ZERO", "ARR_NIL", "OBJ_NIL", "OBJ_SLOTNIL"):
        return "{=="+"}"
    A = "S.ArraySchema{i, m, n}"
    if kind == "ARR_CONS":
        C = "S.collect_go(i, h, S.cstart(i, h, 1n+l))"
        return "arr_frame(i, m, n, t, k, r, %s)(frame(%s, J.JArray{t}, S.WItems{1n+k, S.merge(S.PathIndex{k}, %s, r)}))(frame(%s, J.JArray{t}, S.WItems{1n+k, S.merge(S.PathIndex{k}, %s, [])}))" % (C, A, C, A, C)
    O = "S.ObjectSchema{t, u}"
    if kind == "ONCE":
        C = "S.collect_go(c, y, S.cstart(c, y, 1n+l))"
        return "obj_frame(k, t, u, x, rest, r, %s)(frame(%s, x, S.WFields{rest, S.merge(S.PathKey{k}, %s, r)}))(frame(%s, x, S.WFields{rest, S.merge(S.PathKey{k}, %s, [])}))" % (C, O, C, O, C)
    E = 'S.Error{S.Constraint{}, "missing required key", [S.PathKey{k}]}'
    if kind == "ABSENT":
        return "emit_frame(t, u, x, rest, %s, r, l, S.may_be_absent(p))(frame(%s, x, S.WFields{rest, S.emit(S.may_be_absent(p), %s, S.Out{r, 1n+l})}))(frame(%s, x, S.WFields{rest, S.Out{[%s], l}}))" % (E, O, E, O, E)
    D = 'S.Error{S.Constraint{}, "duplicate key", [S.PathKey{k}]}'
    if kind == "REPEATED":
        return "shift_frame(S.collect_go(%s, x, S.WFields{rest, S.Out{[], l}}), S.collect_go(%s, x, S.WFields{rest, S.Out{[%s], l}}), [%s], r, %s <> r, S.collect_go(%s, x, S.WFields{rest, S.Out{%s <> r, l}}), frame(%s, x, S.WFields{rest, S.Out{%s <> r, l}}), {==}, frame(%s, x, S.WFields{rest, S.Out{[%s], l}}))" % (O, O, D, D, D, O, D, O, D, O, D)
    raise Exception(kind)


ERR_MISSING = 'S.Error{S.Constraint{}, "missing required key", [S.PathKey{k}]}'
ERR_DUP = 'S.Error{S.Constraint{}, "duplicate key", [S.PathKey{k}]}'
ERR_UNION = 'S.Error{S.Constraint{}, "value matches no union member", []}'
ARR = "S.ArraySchema{i, m, n}"
OBJ = "S.ObjectSchema{t, u}"
CH_A = "S.collect_go(i, h, S.cstart(i, h, 1n+l))"
CH_O = "S.collect_go(c, y, S.cstart(c, y, 1n+l))"
UNI_OK = "S.accepted(S.decode_go(S.UnionSchema{ms}, x, S.start(S.UnionSchema{ms}, x)))"

def size_body(s, v, w, kind):
    if kind == "SCALAR":
        return "scalar_size(S.decode_scalar(%s, %s), l)" % (s, v)
    if kind == "FB_HERE":
        return "kind_size(l)"
    if kind in ("FB", "ZERO", "NULL_NULL", "ARR_NIL", "OBJ_NIL", "OBJ_SLOTNIL"):
        return "{=="+"}"
    if kind == "ARR_CONS":
        lhs = "size(S.collect_go(%s, J.JArray{t}, S.WItems{1n+k, S.merge(S.PathIndex{k}, %s, r)}))" % (ARR, CH_A)
        return "step_size(S.PathIndex{k}, r, %s, 1n+l, %s, sized(%s, J.JArray{t}, S.WItems{1n+k, S.merge(S.PathIndex{k}, %s, r)}), Equal.trans(Nat, size(%s), wsize(S.cstart(i, h, 1n+l)), 1n+l, sized(i, h, S.cstart(i, h, 1n+l)), cstart_size(i, h, 1n+l)))" % (CH_A, lhs, ARR, CH_A, CH_A)
    if kind == "ONCE":
        lhs = "size(S.collect_go(%s, x, S.WFields{rest, S.merge(S.PathKey{k}, %s, r)}))" % (OBJ, CH_O)
        return "step_size(S.PathKey{k}, r, %s, 1n+l, %s, sized(%s, x, S.WFields{rest, S.merge(S.PathKey{k}, %s, r)}), Equal.trans(Nat, size(%s), wsize(S.cstart(c, y, 1n+l)), 1n+l, sized(c, y, S.cstart(c, y, 1n+l)), cstart_size(c, y, 1n+l)))" % (CH_O, lhs, OBJ, CH_O, CH_O)
    if kind == "ABSENT":
        em = "S.emit(S.may_be_absent(p), %s, S.Out{r, 1n+l})" % ERR_MISSING
        return "Equal.trans(Nat, size(S.collect_go(%s, x, S.WFields{rest, %s})), size(%s), size(S.Out{r, 1n+l}), sized(%s, x, S.WFields{rest, %s}), emit_size(S.may_be_absent(p), %s, S.Out{r, 1n+l}))" % (OBJ, em, em, OBJ, em, ERR_MISSING)
    if kind == "REPEATED":
        st = "S.WFields{rest, S.Out{%s <> r, l}}" % ERR_DUP
        return "Equal.trans(Nat, size(S.collect_go(%s, x, %s)), 1n+Nat.add(Spec.error_count(r), l), Nat.add(Spec.error_count(r), 1n+l), sized(%s, x, %s), Equal.sym(Nat, Nat.add(Spec.error_count(r), 1n+l), 1n+Nat.add(Spec.error_count(r), l), A.add_succ_r(Spec.error_count(r), l)))" % (OBJ, st, OBJ, st)
    if kind == "NULL_X":
        return "Equal.trans(Nat, size(S.collect_go(i, %s, S.cstart(i, %s, l))), wsize(S.cstart(i, %s, l)), l, sized(i, %s, S.cstart(i, %s, l)), cstart_size(i, %s, l))" % ((v,)*6)
    if kind == "UNION":
        return "emit_size(S.accepted(S.decode_go(S.UnionSchema{ms}, %s, S.start(S.UnionSchema{ms}, %s))), %s, S.Out{[], l})" % (v, v, ERR_UNION)
    raise Exception(kind)


def child_q(i, h, l, oki):
    return "Equal.trans(Bool, clean(S.collect_go(%s, %s, S.cstart(%s, %s, 1n+%s))), expect_c(%s, S.cstart(%s, %s, 1n+%s), %s), Spec.meets(%s, Spec.Holds{}, %s), quiet(%s, %s, S.cstart(%s, %s, 1n+%s), %s, cstart_live(%s, %s, %s)), entry_c(%s, %s, %s))" % (i, h, i, h, l, i, i, h, l, h, i, h, i, h, i, h, l, oki, i, h, l, i, h, l)

def size_child(i, h, l):
    return "Equal.trans(Nat, size(S.collect_go(%s, %s, S.cstart(%s, %s, 1n+%s))), wsize(S.cstart(%s, %s, 1n+%s)), 1n+%s, sized(%s, %s, S.cstart(%s, %s, 1n+%s)), cstart_size(%s, %s, 1n+%s))" % (i, h, i, h, l, i, h, l, l, i, h, i, h, l, i, h, l)

def fs_of(s):
    return "[]" if "Nil{}" in s else "S.Field{k, c, p} <> t"

def ss_of(w):
    inner = w[len("S.WFields{"):]
    return inner[:inner.index(", S.Out{")]

def quiet_body(s, v, w, kind):
    if kind == "SCALAR":
        return "scalar_quiet(%s, %s, l, okv, lv)" % (s, v)
    if kind == "FB_HERE":
        return "kind_quiet(l, lv)"
    if kind in ("FB", "NULL_NULL"):
        return "{=="+"}"
    if kind == "ZERO":
        if s.startswith("S.ArraySchema"):
            if not v.startswith("J.JArray"):
                return "{=="+"}"
            rest = "Spec.meets(i, Spec.EveryItem{Spec.Holds{}}, %s)" % v
        else:
            rest = "slots_ok(%s, %s)" % (fs_of(s), ss_of(w))
        return "      %%Equal.sym(Bool, empty(r), False{}, zero_quiet(r, lv)) : {_ == (_ && %s) : Bool}\n      {==}" % rest
    if kind == "ARR_NIL":
        return "      %SC.each_nil(i, Spec.Holds{}) : {empty(r) == (empty(r) && _) : Bool}\n      SP.and_true(empty(r))"
    if kind in ("OBJ_NIL", "OBJ_SLOTNIL"):
        return "SP.and_true(empty(r))"
    if kind == "ARR_CONS":
        W = "S.WItems{1n+k, S.merge(S.PathIndex{k}, %s, r)}" % CH_A
        R = "S.collect_go(%s, J.JArray{t}, %s)" % (ARR, W)
        comb = "combine3(clean(%s), clean(S.merge(S.PathIndex{k}, %s, r)), clean(%s), empty(r), Spec.meets(i, Spec.Holds{}, h), Spec.meets(i, Spec.EveryItem{Spec.Holds{}}, J.JArray{t}), quiet(%s, J.JArray{t}, %s, okv, merge_live(S.PathIndex{k}, %s, r, l, %s)), merge_clean(S.PathIndex{k}, %s, r), %s)" % (R, CH_A, CH_A, ARR, W, CH_A, size_child("i", "h", "l"), CH_A, child_q("i", "h", "l", "SC.item_valid(i, m, n, okv)"))
        return "      %%SC.each_cons(i, Spec.Holds{}, h, t) : {clean(%s) == (empty(r) && _) : Bool}\n      %s" % (R, comb)
    if kind == "ONCE":
        W = "S.WFields{rest, S.merge(S.PathKey{k}, %s, r)}" % CH_O
        R = "S.collect_go(%s, x, %s)" % (OBJ, W)
        return "combine3(clean(%s), clean(S.merge(S.PathKey{k}, %s, r)), clean(%s), empty(r), Spec.meets(c, Spec.Holds{}, y), slots_ok(t, rest), quiet(%s, x, %s, SC.rest_valid(k, c, p, t, u, okv), merge_live(S.PathKey{k}, %s, r, l, %s)), merge_clean(S.PathKey{k}, %s, r), %s)" % (R, CH_O, CH_O, OBJ, W, CH_O, size_child("c", "y", "l"), CH_O, child_q("c", "y", "l", "SC.field_valid(k, c, p, t, u, okv)"))
    if kind == "ABSENT":
        b = "S.may_be_absent(p)"
        em = "S.emit(%s, %s, S.Out{r, 1n+l})" % (b, ERR_MISSING)
        W = "S.WFields{rest, %s}" % em
        R = "S.collect_go(%s, x, %s)" % (OBJ, W)
        return "combine3(clean(%s), clean(%s), %s, empty(r), SC.absent_ok(p), slots_ok(t, rest), quiet(%s, x, %s, SC.rest_valid(k, c, p, t, u, okv), emit_live(%s, %s, r, l)), emit_clean(%s, %s, r, l), may_absent(p))" % (R, em, b, OBJ, W, b, ERR_MISSING, b, ERR_MISSING)
    if kind == "REPEATED":
        W = "S.WFields{rest, S.Out{%s <> r, l}}" % ERR_DUP
        R = "S.collect_go(%s, x, %s)" % (OBJ, W)
        return "      %%Equal.sym(Bool, (empty(r) && False{}), False{}, and_false(empty(r))) : {clean(%s) == _ : Bool}\n      quiet(%s, x, %s, SC.rest_valid(k, c, p, t, u, okv), {==})" % (R, OBJ, W)
    if kind == "NULL_X":
        return "Equal.trans(Bool, clean(S.collect_go(i, %s, S.cstart(i, %s, l))), expect_c(i, S.cstart(i, %s, l), %s), Spec.meets(i, Spec.Holds{}, %s), quiet(i, %s, S.cstart(i, %s, l), okv, cstart_live2(i, %s, l, lv)), entry_c2(i, %s, l, lv))" % ((v,)*9)
    if kind == "UNION":
        return "union_quiet(ms, %s, l, okv, lv)" % v
    raise Exception(kind)


def sections():
    h = open(os.path.join(HERE, 'errors-head.bend')).read()
    marks = ["# The budget: errors plus budget left.", "# Booleans.", "# Soundness."]
    parts = []
    rest = h
    for m in marks:
        i = rest.index(m)
        parts.append(rest[:i])
        rest = rest[i:]
    parts.append(rest)
    return parts

EXTRA = []

def render():
    h0, h1, h2, h3 = sections()
    out = h0
    out += "\n# The frame: a state's starting errors end its result unchanged.\n"
    out += lemma("def frame(+s: S.Schema, +v: J.Json, +w: S.Walk) -> {S.collect_go(s, v, w) == extend(S.collect_go(s, v, blank(w)), wrev(w)) : S.Out}:", frame_body)
    out += "\n" + h1
    out += "\n# Every state keeps errors plus budget left.\n"
    out += lemma("def sized(+s: S.Schema, +v: J.Json, +w: S.Walk) -> {size(S.collect_go(s, v, w)) == wsize(w) : Nat}:", size_body)
    out += "\n" + h2
    out += "\n# A state reports nothing exactly when the specification accepts what it still checks.\n"
    out += lemma("def quiet(+s: S.Schema, +v: J.Json, +w: S.Walk, +okv: {S.valid(s) == True{} : Bool}, +lv: {live(w) == True{} : Bool}) -> {clean(S.collect_go(s, v, w)) == expect_c(s, w, v) : Bool}:", quiet_body)
    out += "\n" + h3
    for e in EXTRA:
        out += "\n" + e()
    out += open(os.path.join(HERE, 'errors-tail.bend')).read()
    return out

XS = ["J.JNull{}", "J.JBool{b1}", "J.JNumber{b1}", "J.JString{b1}", "J.JObject{b1}", "J.JArray{Nil{}}", "J.JArray{g1 <> r1}"]

def split_x(fn):
    lines = ["      match x:"]
    for X in XS:
        lines.append("        case %s: %s" % (X, fn(X)))
    return "\n".join(lines)

def sound_goal(s, v):
    return "{all_sf(revs(S.collect_go(%s, %s, blank(S.WHere{l}))), S.WHere{l}, %s, %s) == True{} : Bool}" % (s, v, s, v)

def sound_body(s, v, w, kind):
    if kind == "SCALAR":
        return "scalar_sound(%s, %s, l, okv, {==})" % (s, v)
    if kind == "FB_HERE":
        if s.startswith("S.ArraySchema"):
            if v.startswith("J.JArray"):
                return "no_reach(%s, rc)" % sound_goal(s, v)
            return "kind_sound(%s, %s, l, {==})" % (s, v)
        return ("no_reach(%s, rc)" % sound_goal(s, v)) if v.startswith("J.JObject") else ("kind_sound(%s, %s, l, {==})" % (s, v))
    if kind in ("FB", "ZERO", "ARR_NIL", "OBJ_NIL", "OBJ_SLOTNIL", "NULL_NULL"):
        return "{=="+"}"
    if kind == "ARR_CONS":
        W = "S.WItems{1n+k, S.merge(S.PathIndex{k}, %s, [])}" % CH_A
        return "arr_sound(i, m, n, h, t, k, S.Out{r, 1n+l}, %s)(frame(%s, J.JArray{t}, %s))(sound(%s, J.JArray{t}, %s, okv, {==}))(entry_s(i, h, 1n+l, sound(i, h, S.cstart(i, h, 1n+l), SC.item_valid(i, m, n, okv), cstart_reach(i, h, 1n+l))))" % (CH_A, ARR, W, ARR, W)
    if kind == "ONCE":
        W = "S.WFields{rest, S.merge(S.PathKey{k}, %s, [])}" % CH_O
        return "obj_sound(k, c, p, t, u, x, y, rest, S.Out{r, 1n+l}, %s)(frame(%s, x, %s))(sound(%s, x, %s, SC.rest_valid(k, c, p, t, u, okv), {==}))(entry_s(c, y, 1n+l, sound(c, y, S.cstart(c, y, 1n+l), SC.field_valid(k, c, p, t, u, okv), cstart_reach(c, y, 1n+l))))" % (CH_O, OBJ, W, OBJ, W)
    if kind == "ABSENT":
        W = "S.WFields{rest, S.emit(S.may_be_absent(p), %s, S.Out{[], 1n+l})}" % ERR_MISSING
        return "absent_sound(k, c, p, t, u, x, rest, l, S.Out{r, 1n+l}, S.may_be_absent(p), {==})(frame(%s, x, %s))(sound(%s, x, %s, SC.rest_valid(k, c, p, t, u, okv), {==}))" % (OBJ, W, OBJ, W)
    if kind == "REPEATED":
        W = "S.WFields{rest, S.Out{[%s], l}}" % ERR_DUP
        return "key_sound(k, c, p, t, u, x, S.Repeated{y}, rest, l, S.Out{r, 1n+l}, %s, frame(%s, x, %s), sound(%s, x, %s, SC.rest_valid(k, c, p, t, u, okv), {==}), repeated_one(k, c, p, t, u, x, y, rest, S.Out{r, 1n+l}))" % (ERR_DUP, OBJ, W, OBJ, W)
    if kind == "NULL_X":
        return "null_sound(revs(S.collect_go(i, %s, S.cstart(i, %s, l))), i, %s, l, {==}, entry_s(i, %s, l, sound(i, %s, S.cstart(i, %s, l), okv, cstart_reach(i, %s, l))))" % ((v,)*7)
    if kind == "UNION":
        U = "S.UnionSchema{ms}"
        X = v
        return "union_sound_b(ms, %s, l, S.accepted(S.decode_go(%s, %s, S.start(%s, %s))), SC.child(%s, %s, SC.agree(%s, %s, S.start(%s, %s), okv)), {==})" % (X, U, X, U, X, U, X, U, X, U, X)
    raise Exception(kind)

EXTRA.append(lambda: "# Every error a state adds names a location the specification finds failing.\n" + lemma("def sound(+s: S.Schema, +v: J.Json, +w: S.Walk, +okv: {S.valid(s) == True{} : Bool}, rc: {reach(w, s, v) == True{} : Bool}) -> {all_sf(revs(S.collect_go(s, v, blank(w))), w, s, v) == True{} : Bool}:", sound_body))

def goal_c(s, v, w, path):
    return "{found(S.collect_go(%s, %s, blank(%s)), %s) == True{} : Bool}" % (s, v, w, path)

def wpat(w):
    return w

def path_split(s, v, w, nil, key, idx):
    # each of nil/key/idx: None means absurd
    def body(code, path):
        return code if code is not None else "UP.absurd(%s, UP.false_true(hf))" % goal_c(s, v, w, path)
    return "\n".join([
        "      match path:",
        "        case Nil{}: " + body(nil, "[]"),
        "        case S.PathKey{+pk} <> +pq: " + body(key, "S.PathKey{pk} <> pq"),
        "        case S.PathIndex{+pk} <> +pq: " + body(idx, "S.PathIndex{pk} <> pq"),
    ])

def complete_body(s, v, w, kind):
    if kind == "SCALAR":
        return path_split(s, v, w, "scalar_complete(%s, %s, l, okv, {==}, hf)" % (s, v), None, None)
    if kind == "FB_HERE":
        if (s.startswith("S.ArraySchema") and v.startswith("J.JArray")) or (s.startswith("S.ObjectSchema") and v.startswith("J.JObject")):
            return "no_reach(%s, rc)" % goal_c(s, v, w, "path")
        return path_split(s, v, w, "kind_complete(l)", None, None)
    if kind == "FB":
        if s.startswith("S.ArraySchema") and w.startswith("S.WItems"):
            return path_split(s, v, w, None, None, None)
        return "UP.absurd(%s, UP.false_true(hf))" % goal_c(s, v, w, "path")
    if kind == "ZERO":
        return "{=="+"}"
    if kind in ("ARR_NIL", "OBJ_NIL", "OBJ_SLOTNIL"):
        return path_split(s, v, w, None, None, None)
    if kind == "NULL_NULL":
        return "UP.absurd(%s, UP.false_true(hf))" % goal_c(s, v, w, "path")
    if kind == "NULL_X":
        return "entry_k(i, %s, l, path, null_fault_rev(i, %s, path, {==}, hf), hs => complete(i, %s, S.cstart(i, %s, l), okv, cstart_reach(i, %s, l), path, hs))" % ((v,)*5)
    if kind == "UNION":
        U = "S.UnionSchema{ms}"
        X = v
        return path_split(s, v, w, "union_complete(ms, %s, l, S.accepted(S.decode_go(%s, %s, S.start(%s, %s))), SC.child(%s, %s, SC.agree(%s, %s, S.start(%s, %s), okv)), {==}, hf)" % (X, U, X, U, X, U, X, U, X, U, X), None, None)
    if kind == "ARR_CONS":
        W = "S.WItems{1n+k, S.merge(S.PathIndex{k}, %s, [])}" % CH_A
        code = "arr_complete(i, m, n, h, k, pk, pq, %s, t)(frame(%s, J.JArray{t}, %s))(hs => complete(%s, J.JArray{t}, %s, okv, {==}, S.PathIndex{pk} <> pq, hs))(hc => entry_k(i, h, 1n+l, pq, hc, hs2 => complete(i, h, S.cstart(i, h, 1n+l), SC.item_valid(i, m, n, okv), cstart_reach(i, h, 1n+l), pq, hs2)))(hf)" % (CH_A, ARR, W, ARR, W)
        return path_split(s, v, w, None, None, code)
    if kind == "ONCE":
        W = "S.WFields{rest, S.merge(S.PathKey{k}, %s, [])}" % CH_O
        code = "obj_complete(k, c, p, t, u, x, y, rest, pk, pq, %s)(frame(%s, x, %s))(hs => complete(%s, x, %s, SC.rest_valid(k, c, p, t, u, okv), {==}, S.PathKey{pk} <> pq, hs))(hc => entry_k(c, y, 1n+l, pq, hc, hs2 => complete(c, y, S.cstart(c, y, 1n+l), SC.field_valid(k, c, p, t, u, okv), cstart_reach(c, y, 1n+l), pq, hs2)))(hf)" % (CH_O, OBJ, W, OBJ, W)
        return path_split(s, v, w, None, code, None)
    if kind == "ABSENT":
        W = "S.WFields{rest, S.emit(S.may_be_absent(p), %s, S.Out{[], 1n+l})}" % ERR_MISSING
        code = "absent_complete(k, c, p, t, u, x, rest, l, pk, pq, S.may_be_absent(p), {==})(frame(%s, x, %s))(hs => complete(%s, x, %s, SC.rest_valid(k, c, p, t, u, okv), {==}, S.PathKey{pk} <> pq, hs))(hf)" % (OBJ, W, OBJ, W)
        return path_split(s, v, w, None, code, None)
    if kind == "REPEATED":
        W = "S.WFields{rest, S.Out{[%s], l}}" % ERR_DUP
        code = 'key_complete(t, u, x, rest, l, %s, S.PathKey{pk} <> pq, String.eq(k, pk) && Spec.ends(pq), slots_fault(S.PathKey{pk} <> pq, t, rest), frame(%s, x, %s), hs => complete(%s, x, %s, SC.rest_valid(k, c, p, t, u, okv), {==}, S.PathKey{pk} <> pq, hs), +ha => names_key1(S.Constraint{}, "duplicate key", k, pk, pq, UP.and_left(String.eq(k, pk), Spec.ends(pq), ha), UP.and_right(String.eq(k, pk), Spec.ends(pq), ha)), hf)' % (ERR_DUP, OBJ, W, OBJ, W)
        return path_split(s, v, w, None, code, None)
    raise Exception(kind)

EXTRA.append(lambda: "# Every location the specification finds failing is named, unless the budget ran out.\n" + lemma("def complete(+s: S.Schema, +v: J.Json, +w: S.Walk, +okv: {S.valid(s) == True{} : Bool}, rc: {reach(w, s, v) == True{} : Bool}, +path: List<&2, S.PathPart>, hf: {state_fault_c(w, s, v, path) == True{} : Bool}) -> {found(S.collect_go(s, v, blank(w)), path) == True{} : Bool}:", complete_body))
