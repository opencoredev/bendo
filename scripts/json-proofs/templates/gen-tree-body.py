R = "@R"
def txt(cap, val, inc, d, first=None):
    first = first or inc
    return f"X.text({cap}, {val}, {inc}, pretty, ascii, {d}, {first})"
def GO(s, a, m): return f"@GO({s}; {a}; {m})"
def MM(mode, inp, fs, d): return f"@MM({mode}; {inp}; {fs}; {d})"

params = "capacity: Nat, value: J.Json, +inc: Bool, +pretty: Bool, +ascii: Bool, +dp: Nat, +ra: List<&2, J.Json>, +ro: List<&2, J.Field>, +suffix: String, +fs: List<&2, J.Frame>, +a: Nat, +v: J.Json, +good: {ok(inc, capacity, value) == True{} : Bool}, +lim: {Nat.add(dp, capacity) == 512n : Nat}, +stop: {N.ends(suffix) == True{} : Bool}"
def goal(cap, val, inc):
    t = txt(cap, val, inc, f"start_depth({inc}, dp)", inc)
    return GO(f"{t} ++ suffix", "a", MM(f"start_mode({inc}, {val}, ra, ro)", f"{t} ++ suffix", "fs", f"start_depth({inc}, dp)"))
hyp = "done: " + GO("suffix", "a", MM("J.MEmit{end_value(inc, value, ra, ro)}", "suffix", "fs", "dp"))
o = []
o.append(f"def tree_cps({params}, {hyp}) -> {goal('capacity', 'value', 'inc')}:")
o.append("  match capacity value:")
def absurd(cap, val, inc):
    return f"P.absurd({goal(cap, val, inc)}, P.false_true(good))"
def scalar(pat, val, body):
    o.append(f"    case cap {pat}:")
    o.append("      match inc:")
    o.append(f"        case True{{}}: {body}")
    o.append(f"        case False{{}}: {absurd('cap', val, 'False{}')}")
scalar("J.JNull{}", "J.JNull{}", "null_cps(suffix, fs, dp, a, v, done)")
scalar("J.JBool{True{}}", "J.JBool{True{}}", "true_cps(suffix, fs, dp, a, v, done)")
scalar("J.JBool{False{}}", "J.JBool{False{}}", "false_cps(suffix, fs, dp, a, v, done)")
scalar("J.JNumber{+s}", "J.JNumber{s}", "N.number_cps(s, suffix, fs, dp, a, v, good, stop, done)")
scalar("J.JString{+s}", "J.JString{s}", "Q.string_cps(s, ascii, suffix, fs, dp, a, v, string_ok(s, good), done)")
for kind in ("J.JArray{xs}", "J.JObject{xs}"):
    o.append(f"    case 0n {kind}:")
    o.append("      match inc:")
    o.append(f"        case True{{}}: {absurd('0n', kind, 'True{}')}")
    o.append(f"        case False{{}}: {absurd('0n', kind, 'False{}')}")

# ---------- arrays ----------
o.append("    case 1n++r J.JArray{Nil{}}:")
o.append("      match inc:")
o.append("        case True{}:")
o.append("          C.consume_full('[', SCon{']', suffix}, a, " + MM("J.MValue{}", "SCon{'[', SCon{']', suffix}}", "fs", "dp") + ", v, open_arr(SCon{']', suffix}, fs, dp, 3n+a, v, ge_false(dp, r, lim), C.consume(']', suffix, 3n+a, " + MM("J.MArrayFirst{}", "SCon{']', suffix}", "fs", "1n+dp") + ", v, C.raise_add(3n, suffix, a, " + MM("J.MEmit{J.JArray{[]}}", "suffix", "fs", "dp") + ", v, done), {==})), {==})")
o.append("        case False{}:")
L0 = "J.line(pretty, dp)"
o.append(f"          %Equal.sym(String, ({L0} ++ \"]\") ++ suffix, {L0} ++ (\"]\" ++ suffix), Sup.append_assoc({L0}, \"]\", suffix)) : " + GO("_", "a", MM("J.MArrayAfter{ra}", "_", "fs", "1n+dp")))
o.append(f"          ws_cps({L0}, J.MArrayAfter{{ra}}, SCon{{']', suffix}}, fs, 1n+dp, a, v, {{==}}, JS.line_spaces(pretty, dp), C.consume(']', suffix, a, " + MM("J.MArrayAfter{ra}", "SCon{']', suffix}", "fs", "1n+dp") + ", v, done, {==}))")

L = "J.line(pretty, 1n+dp)"
TH = txt("r", "h", "True{}", "1n+dp")
TTa = txt("1n+r", "J.JArray{t}", "False{}", "1n+dp")
S1 = f"{TTa} ++ suffix"
S2 = f"{TH} ++ ({S1})"
S3 = f"{L} ++ ({S2})"
good_h_a = "P.and_left(T.valid_at(r, h), T.valid_at(1n+r, J.JArray{t}), good)"
good_t_a = "P.and_right(T.valid_at(r, h), T.valid_at(1n+r, J.JArray{t}), good)"
o.append("    case 1n++r J.JArray{+h <> +t}:")
o.append("      match inc:")
o.append("        case True{}:")
o.append(f"          %Equal.sym(String, ({L} ++ ({TH} ++ {TTa})) ++ suffix, {S3}, assoc3({L}, {TH}, {TTa}, suffix)) : " + GO("SCon{'[', _}", "a", MM("J.MValue{}", "SCon{'[', _}", "fs", "dp")))
ih_t = f"tree_cps(1n+r, J.JArray{{t}}, False{{}}, pretty, ascii, dp, h <> [], ro, suffix, fs, a, v, {good_t_a}, lim, stop, arr_end(h, t, suffix, fs, dp, a, v, done))"
e_h = f"emit_arr({S1}, a, h, [], fs, 1n+dp, v, {ih_t})"
ih_h = f"tree_cps(r, h, True{{}}, pretty, ascii, 1n+dp, ra, ro, {S1}, J.ArrayFrame{{[]}} <> fs, 1n+a, v, {good_h_a}, child_lim(dp, r, lim), tail_ends_arr(r, t, pretty, ascii, dp, suffix), {e_h})"
F = f"C.raise_add(1n, {S2}, 1n+a, " + MM("J.MValue{}", S2, "J.ArrayFrame{[]} <> fs", "1n+dp") + f", v, {ih_h})"
G = f"first_cps(r, h, pretty, ascii, 1n+dp, {S1}, fs, 1n+dp, 2n+a, v, {good_h_a}, {F})"
Wsp = f"ws_cps({L}, J.MArrayFirst{{}}, {S2}, fs, 1n+dp, 3n+a, v, {{==}}, JS.line_spaces(pretty, 1n+dp), {G})"
O = f"open_arr({S3}, fs, dp, 3n+a, v, ge_false(dp, r, lim), {Wsp})"
o.append(f"          C.consume_full('[', {S3}, a, " + MM("J.MValue{}", f"SCon{{'[', {S3}}}", "fs", "dp") + f", v, {O}, {{==}})")
o.append("        case False{}:")
o.append(f"          %Equal.sym(String, ({L} ++ ({TH} ++ {TTa})) ++ suffix, {S3}, assoc3({L}, {TH}, {TTa}, suffix)) : " + GO("SCon{',', _}", "a", MM("J.MArrayAfter{ra}", "SCon{',', _}", "fs", "1n+dp")))
ih_t = f"tree_cps(1n+r, J.JArray{{t}}, False{{}}, pretty, ascii, dp, h <> ra, ro, suffix, fs, a, v, {good_t_a}, lim, stop, done)"
e_h = f"emit_arr({S1}, a, h, ra, fs, 1n+dp, v, {ih_t})"
ih_h = f"tree_cps(r, h, True{{}}, pretty, ascii, 1n+dp, ra, ro, {S1}, J.ArrayFrame{{ra}} <> fs, 1n+a, v, {good_h_a}, child_lim(dp, r, lim), tail_ends_arr(r, t, pretty, ascii, dp, suffix), {e_h})"
Wsp = f"ws_cps({L}, J.MValue{{}}, {S2}, J.ArrayFrame{{ra}} <> fs, 1n+dp, 1n+a, v, {{==}}, JS.line_spaces(pretty, 1n+dp), {ih_h})"
o.append(f"          C.consume_full(',', {S3}, a, " + MM("J.MArrayAfter{ra}", f"SCon{{',', {S3}}}", "fs", "1n+dp") + f", v, C.raise_add(2n, {S3}, 1n+a, " + MM("J.MValue{}", S3, "J.ArrayFrame{ra} <> fs", "1n+dp") + f", v, {Wsp}), {{==}})")

# ---------- objects ----------
o.append("    case 1n++r J.JObject{Nil{}}:")
o.append("      match inc:")
o.append("        case True{}:")
o.append("          C.consume_full('{', SCon{'}', suffix}, a, " + MM("J.MValue{}", "SCon{'{', SCon{'}', suffix}}", "fs", "dp") + ", v, open_obj(SCon{'}', suffix}, fs, dp, 3n+a, v, ge_false(dp, r, lim), C.consume('}', suffix, 3n+a, " + MM("J.MReadKey{True{}}", "SCon{'}', suffix}", "J.ObjectFrame{[]} <> fs", "1n+dp") + ", v, C.raise_add(3n, suffix, a, " + MM("J.MEmit{J.JObject{[]}}", "suffix", "fs", "dp") + ", v, done), {==})), {==})")
o.append("        case False{}:")
o.append(f"          %Equal.sym(String, ({L0} ++ \"}}\") ++ suffix, {L0} ++ (\"}}\" ++ suffix), Sup.append_assoc({L0}, \"}}\", suffix)) : " + GO("_", "a", MM("J.MObjectAfter{ro}", "_", "fs", "1n+dp")))
o.append(f"          ws_cps({L0}, J.MObjectAfter{{ro}}, SCon{{'}}', suffix}}, fs, 1n+dp, a, v, {{==}}, JS.line_spaces(pretty, dp), C.consume('}}', suffix, a, " + MM("J.MObjectAfter{ro}", "SCon{'}', suffix}", "fs", "1n+dp") + ", v, done, {==}))")

QK = "J.quote(k, ascii)"
CO = "J.colon(pretty)"
TTo = txt("1n+r", "J.JObject{t}", "False{}", "1n+dp")
S1 = f"{TTo} ++ suffix"
S2 = f"{TH} ++ ({S1})"
S3 = f"{CO} ++ ({S2})"
S4 = f"{QK} ++ ({S3})"
S5 = f"{L} ++ ({S4})"
rest = "P.and_right(J.scalars(k), T.valid_at(r, h) && T.valid_at(1n+r, J.JObject{t}), good)"
good_h_o = f"P.and_left(T.valid_at(r, h), T.valid_at(1n+r, J.JObject{{t}}), {rest})"
good_t_o = f"P.and_right(T.valid_at(r, h), T.valid_at(1n+r, J.JObject{{t}}), {rest})"
kv = "string_ok(k, P.and_left(J.scalars(k), T.valid_at(r, h) && T.valid_at(1n+r, J.JObject{t}), good))"
o.append("    case 1n++r J.JObject{J.Field{+k, +h} <> +t}:")
o.append("      match inc:")
o.append("        case True{}:")
o.append(f"          %Equal.sym(String, ({L} ++ ({QK} ++ ({CO} ++ ({TH} ++ {TTo})))) ++ suffix, {S5}, assoc5({L}, {QK}, {CO}, {TH}, {TTo}, suffix)) : " + GO("SCon{'{', _}", "a", MM("J.MValue{}", "SCon{'{', _}", "fs", "dp")))
ih_t = f"tree_cps(1n+r, J.JObject{{t}}, False{{}}, pretty, ascii, dp, ra, J.Field{{k, h}} <> [], suffix, fs, a, v, {good_t_o}, lim, stop, obj_end(J.Field{{k, h}}, t, suffix, fs, dp, a, v, done))"
e_h = f"emit_mem({S1}, a, h, k, [], fs, 1n+dp, v, {ih_t})"
ih_h = f"tree_cps(r, h, True{{}}, pretty, ascii, 1n+dp, ra, ro, {S1}, J.MemberFrame{{k, []}} <> fs, 1n+a, v, {good_h_o}, child_lim(dp, r, lim), tail_ends_obj(r, t, pretty, ascii, dp, suffix), {e_h})"
CC = f"colon_cps(pretty, k, [], {S2}, fs, 1n+dp, 1n+a, v, {ih_h})"
KK = f"Q.key_cps(k, ascii, True{{}}, {S3}, J.ObjectFrame{{[]}} <> fs, 1n+dp, 1n+a, v, {kv}, {CC})"
Wsp = f"ws_cps({L}, J.MReadKey{{True{{}}}}, {S4}, J.ObjectFrame{{[]}} <> fs, 1n+dp, 1n+a, v, {{==}}, JS.line_spaces(pretty, 1n+dp), {KK})"
O = f"open_obj({S5}, fs, dp, 3n+a, v, ge_false(dp, r, lim), C.raise_add(2n, {S5}, 1n+a, " + MM("J.MReadKey{True{}}", S5, "J.ObjectFrame{[]} <> fs", "1n+dp") + f", v, {Wsp}))"
o.append(f"          C.consume_full('{{', {S5}, a, " + MM("J.MValue{}", f"SCon{{'{{', {S5}}}", "fs", "dp") + f", v, {O}, {{==}})")
o.append("        case False{}:")
o.append(f"          %Equal.sym(String, ({L} ++ ({QK} ++ ({CO} ++ ({TH} ++ {TTo})))) ++ suffix, {S5}, assoc5({L}, {QK}, {CO}, {TH}, {TTo}, suffix)) : " + GO("SCon{',', _}", "a", MM("J.MObjectAfter{ro}", "SCon{',', _}", "fs", "1n+dp")))
ih_t = f"tree_cps(1n+r, J.JObject{{t}}, False{{}}, pretty, ascii, dp, ra, J.Field{{k, h}} <> ro, suffix, fs, a, v, {good_t_o}, lim, stop, done)"
e_h = f"emit_mem({S1}, a, h, k, ro, fs, 1n+dp, v, {ih_t})"
ih_h = f"tree_cps(r, h, True{{}}, pretty, ascii, 1n+dp, ra, ro, {S1}, J.MemberFrame{{k, ro}} <> fs, 1n+a, v, {good_h_o}, child_lim(dp, r, lim), tail_ends_obj(r, t, pretty, ascii, dp, suffix), {e_h})"
CC = f"colon_cps(pretty, k, ro, {S2}, fs, 1n+dp, 1n+a, v, {ih_h})"
KK = f"Q.key_cps(k, ascii, False{{}}, {S3}, J.ObjectFrame{{ro}} <> fs, 1n+dp, 1n+a, v, {kv}, {CC})"
Wsp = f"ws_cps({L}, J.MReadKey{{False{{}}}}, {S4}, J.ObjectFrame{{ro}} <> fs, 1n+dp, 1n+a, v, {{==}}, JS.line_spaces(pretty, 1n+dp), {KK})"
o.append(f"          C.consume_full(',', {S5}, a, " + MM("J.MObjectAfter{ro}", f"SCon{{',', {S5}}}", "fs", "1n+dp") + f", v, C.raise_add(2n, {S5}, 1n+a, " + MM("J.MReadKey{False{}}", S5, "J.ObjectFrame{ro} <> fs", "1n+dp") + f", v, {Wsp}), {{==}})")
o.append("")
open("/tmp/bnd79/tree-body.src", "w").write("\n".join(o))
