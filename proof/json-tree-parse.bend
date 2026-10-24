# Containers: the parser follows the writer's text through arrays and
# objects, compact or pretty, down to the depth the writer's capacity allows.
import Base
import ../src/data/json.bend as J
import ../src/data/utf8.bend as U
import ./utf8.bend as P
import ./json-tree.bend as T
import ./json-writer.bend as W
import ./json-support.bend as Sup
import ./json-credit.bend as C
import ./json-space.bend as JS
import ./json.bend as JP
import ./json-codec.bend as JC
import ./json-number-parse.bend as N
import ./json-quote.bend as Q
import ./json-text.bend as X

# What the continuation starts from and returns to. A value (include)
# starts at MValue; a container's remaining items start after the previous
# item, one level deeper, with the items read so far.
def ok(inc: Bool, capacity: Nat, value: J.Json) -> Bool:
  match inc value:
    case True{} v: T.valid_at(capacity, v)
    case False{} J.JArray{xs}: T.valid_at(capacity, J.JArray{xs})
    case False{} J.JObject{xs}: T.valid_at(capacity, J.JObject{xs})
    case False{} v: False{}

def start_mode(inc: Bool, value: J.Json, ra: List<&2, J.Json>, ro: List<&2, J.Field>) -> J.Mode:
  match inc value:
    case True{} v: J.MValue{}
    case False{} J.JArray{xs}: J.MArrayAfter{ra}
    case False{} J.JObject{xs}: J.MObjectAfter{ro}
    case False{} v: J.MValue{}

def end_value(inc: Bool, value: J.Json, ra: List<&2, J.Json>, ro: List<&2, J.Field>) -> J.Json:
  match inc value:
    case True{} v: v
    case False{} J.JArray{xs}: J.JArray{List.reverse(&2, J.Json, List.reverse.go(&2, J.Json, xs, ra))}
    case False{} J.JObject{xs}: J.JObject{List.reverse(&2, J.Field, List.reverse.go(&2, J.Field, xs, ro))}
    case False{} v: v

def start_depth(inc: Bool, dp: Nat) -> Nat:
  match inc:
    case True{}: dp
    case False{}: 1n+dp

# The parser's depth check passes while capacity remains.
def ge_add(+dp: Nat, +r: Nat) -> {Nat.is_ge(dp, Nat.add(dp, 1n+r)) == False{} : Bool}:
  match dp:
    case 0n: {==}
    case 1n+p: ge_add(p, r)

def ge_false(+dp: Nat, +r: Nat, lim: {Nat.add(dp, 1n+r) == 512n : Nat}) -> {Nat.is_ge(dp, 512n) == False{} : Bool}:
  %lim : {Nat.is_ge(dp, _) == False{} : Bool}
  ge_add(dp, r)

def child_lim(+dp: Nat, +r: Nat, lim: {Nat.add(dp, 1n+r) == 512n : Nat}) -> {Nat.add(1n+dp, r) == 512n : Nat}:
  Equal.trans(Nat, Nat.add(1n+dp, r), Nat.add(dp, 1n+r), 512n, Equal.sym(Nat, Nat.add(dp, 1n+r), 1n+Nat.add(dp, r), T.add_succ(dp, r)), lim)

def rr(-A: Data, +xs: List<&2, A>, +acc: List<&2, A>, +ys: List<&2, A>) -> {List.reverse.go(&2, A, List.reverse.go(&2, A, xs, acc), ys) == List.reverse.go(&2, A, acc, List.append(&2, A, xs, ys)) : List<&2, A>}:
  match xs:
    case Nil{}: {==}
    case h <> t: rr(A, t, h <> acc, ys)

def rev_rev(-A: Data, +xs: List<&2, A>) -> {List.reverse(&2, A, List.reverse(&2, A, xs)) == xs : List<&2, A>}:
  Equal.trans(List<&2, A>, List.reverse(&2, A, List.reverse(&2, A, xs)), List.append(&2, A, xs, []), xs, rr(A, xs, [], []), P.append_nil(A, xs))

def arr_end(+h: J.Json, +t: List<&2, J.Json>, +suffix: String, +fs: List<&2, J.Frame>, +dp: Nat, +b: Nat, +v: J.Json, hyp: {J.parse_go(J.fuel_go(suffix, b), J.Machine{J.MEmit{J.JArray{h <> t}}, suffix, fs, dp}) == Done{v} : Result<&2, &2, J.Error, J.Json>}) -> {J.parse_go(J.fuel_go(suffix, b), J.Machine{J.MEmit{J.JArray{List.reverse(&2, J.Json, List.reverse.go(&2, J.Json, t, h <> []))}}, suffix, fs, dp}) == Done{v} : Result<&2, &2, J.Error, J.Json>}:
  %Equal.sym(List<&2, J.Json>, List.reverse(&2, J.Json, List.reverse.go(&2, J.Json, t, h <> [])), h <> t, rev_rev(J.Json, h <> t)) : {J.parse_go(J.fuel_go(suffix, b), J.Machine{J.MEmit{J.JArray{_}}, suffix, fs, dp}) == Done{v} : Result<&2, &2, J.Error, J.Json>}
  hyp

def obj_end(+f: J.Field, +t: List<&2, J.Field>, +suffix: String, +fs: List<&2, J.Frame>, +dp: Nat, +b: Nat, +v: J.Json, hyp: {J.parse_go(J.fuel_go(suffix, b), J.Machine{J.MEmit{J.JObject{f <> t}}, suffix, fs, dp}) == Done{v} : Result<&2, &2, J.Error, J.Json>}) -> {J.parse_go(J.fuel_go(suffix, b), J.Machine{J.MEmit{J.JObject{List.reverse(&2, J.Field, List.reverse.go(&2, J.Field, t, f <> []))}}, suffix, fs, dp}) == Done{v} : Result<&2, &2, J.Error, J.Json>}:
  %Equal.sym(List<&2, J.Field>, List.reverse(&2, J.Field, List.reverse.go(&2, J.Field, t, f <> [])), f <> t, rev_rev(J.Field, f <> t)) : {J.parse_go(J.fuel_go(suffix, b), J.Machine{J.MEmit{J.JObject{_}}, suffix, fs, dp}) == Done{v} : Result<&2, &2, J.Error, J.Json>}
  hyp

# A finished item returns to its container, paying one transition.
def emit_arr(+S: String, +b: Nat, +x: J.Json, +ra: List<&2, J.Json>, +fs: List<&2, J.Frame>, +D: Nat, +v: J.Json, h: {J.parse_go(J.fuel_go(S, b), J.Machine{J.MArrayAfter{x <> ra}, S, fs, D}) == Done{v} : Result<&2, &2, J.Error, J.Json>}) -> {J.parse_go(J.fuel_go(S, 1n+b), J.Machine{J.MEmit{x}, S, J.ArrayFrame{ra} <> fs, D}) == Done{v} : Result<&2, &2, J.Error, J.Json>}:
  %Equal.sym(Nat, J.fuel_go(S, 1n+b), 1n+J.fuel_go(S, b), C.fuel_succ(S, b)) : {J.parse_go(_, J.Machine{J.MEmit{x}, S, J.ArrayFrame{ra} <> fs, D}) == Done{v} : Result<&2, &2, J.Error, J.Json>}
  %Equal.sym(Result<&2, &2, J.Error, J.Json>, J.parse_go(1n+J.fuel_go(S, b), J.Machine{J.MEmit{x}, S, J.ArrayFrame{ra} <> fs, D}), J.parse_go(J.fuel_go(S, b), J.Machine{J.MArrayAfter{x <> ra}, S, fs, D}), JP.parse_array_return(J.fuel_go(S, b), x, ra, S, fs, D)) : {_ == Done{v} : Result<&2, &2, J.Error, J.Json>}
  h

def emit_mem(+S: String, +b: Nat, +x: J.Json, +k: String, +ro: List<&2, J.Field>, +fs: List<&2, J.Frame>, +D: Nat, +v: J.Json, h: {J.parse_go(J.fuel_go(S, b), J.Machine{J.MObjectAfter{J.Field{k, x} <> ro}, S, fs, D}) == Done{v} : Result<&2, &2, J.Error, J.Json>}) -> {J.parse_go(J.fuel_go(S, 1n+b), J.Machine{J.MEmit{x}, S, J.MemberFrame{k, ro} <> fs, D}) == Done{v} : Result<&2, &2, J.Error, J.Json>}:
  %Equal.sym(Nat, J.fuel_go(S, 1n+b), 1n+J.fuel_go(S, b), C.fuel_succ(S, b)) : {J.parse_go(_, J.Machine{J.MEmit{x}, S, J.MemberFrame{k, ro} <> fs, D}) == Done{v} : Result<&2, &2, J.Error, J.Json>}
  %Equal.sym(Result<&2, &2, J.Error, J.Json>, J.parse_go(1n+J.fuel_go(S, b), J.Machine{J.MEmit{x}, S, J.MemberFrame{k, ro} <> fs, D}), J.parse_go(J.fuel_go(S, b), J.Machine{J.MObjectAfter{J.Field{k, x} <> ro}, S, fs, D}), JP.parse_member_return(J.fuel_go(S, b), x, k, ro, S, fs, D)) : {_ == Done{v} : Result<&2, &2, J.Error, J.Json>}
  h

# Layout whitespace, one transition per character in gap modes.
def ws_cps(+txt: String, +mode: J.Mode, +S: String, +fs: List<&2, J.Frame>, +D: Nat, +b: Nat, +v: J.Json, +allowed: {J.allows_space(mode) == True{} : Bool}, +valid: {JS.spaces(txt) == True{} : Bool}, h: {J.parse_go(J.fuel_go(S, b), J.Machine{mode, S, fs, D}) == Done{v} : Result<&2, &2, J.Error, J.Json>}) -> {J.parse_go(J.fuel_go(txt ++ S, b), J.Machine{mode, txt ++ S, fs, D}) == Done{v} : Result<&2, &2, J.Error, J.Json>}:
  match txt:
    case SNil{}: h
    case SCon{Chr{c}, t}:
      C.consume_to(Chr{c}, t ++ S, b, J.Machine{mode, SCon{Chr{c}, t ++ S}, fs, D}, J.Machine{mode, t ++ S, fs, D}, v, ws_cps(t, mode, S, fs, D, b, v, allowed, P.and_right(J.whitespace(c), JS.spaces(t), valid), h), JS.parse_space(J.fuel_go(t ++ S, 3n+b), mode, c, t ++ S, fs, D, allowed, P.and_left(J.whitespace(c), JS.spaces(t), valid)))

def colon_cps(+pretty: Bool, +k: String, +ro: List<&2, J.Field>, +S: String, +fs: List<&2, J.Frame>, +D: Nat, +b: Nat, +v: J.Json, h: {J.parse_go(J.fuel_go(S, b), J.Machine{J.MValue{}, S, J.MemberFrame{k, ro} <> fs, D}) == Done{v} : Result<&2, &2, J.Error, J.Json>}) -> {J.parse_go(J.fuel_go(J.colon(pretty) ++ S, b), J.Machine{J.MColon{k}, J.colon(pretty) ++ S, J.ObjectFrame{ro} <> fs, D}) == Done{v} : Result<&2, &2, J.Error, J.Json>}:
  match pretty:
    case False{}: C.consume(':', S, b, J.Machine{J.MColon{k}, SCon{':', S}, J.ObjectFrame{ro} <> fs, D}, v, h, {==})
    case True{}: C.consume(':', SCon{' ', S}, b, J.Machine{J.MColon{k}, SCon{':', SCon{' ', S}}, J.ObjectFrame{ro} <> fs, D}, v, C.consume(' ', S, b, J.Machine{J.MValue{}, SCon{' ', S}, J.MemberFrame{k, ro} <> fs, D}, v, h, {==}), {==})

# Opening a container passes the depth check.
def open_arr(+S: String, +fs: List<&2, J.Frame>, +dp: Nat, +b: Nat, +v: J.Json, ge: {Nat.is_ge(dp, 512n) == False{} : Bool}, h: {J.parse_go(J.fuel_go(S, b), J.Machine{J.MArrayFirst{}, S, fs, 1n+dp}) == Done{v} : Result<&2, &2, J.Error, J.Json>}) -> {J.parse_go(J.fuel_go(S, b), J.open_container(J.MArrayFirst{}, S, fs, dp, Nat.is_ge(dp, 512n))) == Done{v} : Result<&2, &2, J.Error, J.Json>}:
  %Equal.sym(Bool, Nat.is_ge(dp, 512n), False{}, ge) : {J.parse_go(J.fuel_go(S, b), J.open_container(J.MArrayFirst{}, S, fs, dp, _)) == Done{v} : Result<&2, &2, J.Error, J.Json>}
  h

def open_obj(+S: String, +fs: List<&2, J.Frame>, +dp: Nat, +b: Nat, +v: J.Json, ge: {Nat.is_ge(dp, 512n) == False{} : Bool}, h: {J.parse_go(J.fuel_go(S, b), J.Machine{J.MReadKey{True{}}, S, J.ObjectFrame{[]} <> fs, 1n+dp}) == Done{v} : Result<&2, &2, J.Error, J.Json>}) -> {J.parse_go(J.fuel_go(S, b), J.open_container(J.MReadKey{True{}}, S, J.ObjectFrame{[]} <> fs, dp, Nat.is_ge(dp, 512n))) == Done{v} : Result<&2, &2, J.Error, J.Json>}:
  %Equal.sym(Bool, Nat.is_ge(dp, 512n), False{}, ge) : {J.parse_go(J.fuel_go(S, b), J.open_container(J.MReadKey{True{}}, S, J.ObjectFrame{[]} <> fs, dp, _)) == Done{v} : Result<&2, &2, J.Error, J.Json>}
  h

def assoc3(+l: String, +x: String, +y: String, +s: String) -> {(l ++ (x ++ y)) ++ s == l ++ (x ++ (y ++ s)) : String}:
  Equal.trans(String, (l ++ (x ++ y)) ++ s, l ++ ((x ++ y) ++ s), l ++ (x ++ (y ++ s)), Sup.append_assoc(l, x ++ y, s), Equal.cong(String, String, z => l ++ z, (x ++ y) ++ s, x ++ (y ++ s), Sup.append_assoc(x, y, s)))

def assoc5(+l: String, +k: String, +c: String, +x: String, +y: String, +s: String) -> {(l ++ (k ++ (c ++ (x ++ y)))) ++ s == l ++ (k ++ (c ++ (x ++ (y ++ s)))) : String}:
  +inner = Equal.trans(String, (k ++ (c ++ (x ++ y))) ++ s, k ++ ((c ++ (x ++ y)) ++ s), k ++ (c ++ (x ++ (y ++ s))), Sup.append_assoc(k, c ++ (x ++ y), s), Equal.cong(String, String, z => k ++ z, (c ++ (x ++ y)) ++ s, c ++ (x ++ (y ++ s)), assoc3(c, x, y, s)))
  Equal.trans(String, (l ++ (k ++ (c ++ (x ++ y)))) ++ s, l ++ ((k ++ (c ++ (x ++ y))) ++ s), l ++ (k ++ (c ++ (x ++ (y ++ s)))), Sup.append_assoc(l, k ++ (c ++ (x ++ y)), s), Equal.cong(String, String, z => l ++ z, (k ++ (c ++ (x ++ y))) ++ s, k ++ (c ++ (x ++ (y ++ s))), inner))

# After an item, the rest of its container begins with a character that
# ends a number.
def tail_ends_arr(+r: Nat, +t: List<&2, J.Json>, +pretty: Bool, +ascii: Bool, +dp: Nat, +suffix: String) -> {N.ends(X.text(1n+r, J.JArray{t}, False{}, pretty, ascii, 1n+dp, False{}) ++ suffix) == True{} : Bool}:
  match t pretty:
    case Nil{} True{}: {==}
    case Nil{} False{}: {==}
    case (x <> u) True{}: {==}
    case (x <> u) False{}: {==}

def tail_ends_obj(+r: Nat, +t: List<&2, J.Field>, +pretty: Bool, +ascii: Bool, +dp: Nat, +suffix: String) -> {N.ends(X.text(1n+r, J.JObject{t}, False{}, pretty, ascii, 1n+dp, False{}) ++ suffix) == True{} : Bool}:
  match t pretty:
    case Nil{} True{}: {==}
    case Nil{} False{}: {==}
    case (J.Field{k, w} <> u) True{}: {==}
    case (J.Field{k, w} <> u) False{}: {==}

# The first array item: MArrayFirst hands over to MValue without consuming.
def first_eq(capacity: Nat, value: J.Json, +pretty: Bool, +ascii: Bool, +D: Nat, +suffix: String, +fs: List<&2, J.Frame>, +PD: Nat, +good: {T.valid_at(capacity, value) == True{} : Bool}) -> {J.step(J.Machine{J.MArrayFirst{}, X.text(capacity, value, True{}, pretty, ascii, D, True{}) ++ suffix, fs, PD}) == J.Machine{J.MValue{}, X.text(capacity, value, True{}, pretty, ascii, D, True{}) ++ suffix, J.ArrayFrame{[]} <> fs, PD} : J.Machine}:
  match capacity value:
    case _ J.JNull{}: {==}
    case _ J.JBool{True{}}: {==}
    case _ J.JBool{False{}}: {==}
    case _ J.JNumber{s}:
      match s:
        case SNil{}: P.absurd({J.step(J.Machine{J.MArrayFirst{}, SNil{} ++ suffix, fs, PD}) == J.Machine{J.MValue{}, SNil{} ++ suffix, J.ArrayFrame{[]} <> fs, PD} : J.Machine}, P.false_true(good))
        case SCon{Chr{c}, +t}: N.first_step(c, t ++ suffix, fs, PD, t, good)
    case _ J.JString{s}:
      %Equal.sym(String, J.quote(s, ascii) ++ suffix, SCon{'"', Q.escs(s, ascii) ++ SCon{'"', suffix}}, Q.quoted_input(s, ascii, suffix)) : {J.step(J.Machine{J.MArrayFirst{}, _, fs, PD}) == J.Machine{J.MValue{}, _, J.ArrayFrame{[]} <> fs, PD} : J.Machine}
      {==}
    case 0n J.JArray{xs}: P.absurd({J.step(J.Machine{J.MArrayFirst{}, SNil{} ++ suffix, fs, PD}) == J.Machine{J.MValue{}, SNil{} ++ suffix, J.ArrayFrame{[]} <> fs, PD} : J.Machine}, P.false_true(good))
    case 0n J.JObject{xs}: P.absurd({J.step(J.Machine{J.MArrayFirst{}, SNil{} ++ suffix, fs, PD}) == J.Machine{J.MValue{}, SNil{} ++ suffix, J.ArrayFrame{[]} <> fs, PD} : J.Machine}, P.false_true(good))
    case 1n++r J.JArray{Nil{}}: {==}
    case 1n++r J.JArray{x <> u}: {==}
    case 1n++r J.JObject{Nil{}}: {==}
    case 1n++r J.JObject{J.Field{k, w} <> u}: {==}

def first_cps(+capacity: Nat, +value: J.Json, +pretty: Bool, +ascii: Bool, +D: Nat, +suffix: String, +fs: List<&2, J.Frame>, +PD: Nat, +b: Nat, +v: J.Json, +good: {T.valid_at(capacity, value) == True{} : Bool}, h: {J.parse_go(J.fuel_go(X.text(capacity, value, True{}, pretty, ascii, D, True{}) ++ suffix, b), J.Machine{J.MValue{}, X.text(capacity, value, True{}, pretty, ascii, D, True{}) ++ suffix, J.ArrayFrame{[]} <> fs, PD}) == Done{v} : Result<&2, &2, J.Error, J.Json>}) -> {J.parse_go(J.fuel_go(X.text(capacity, value, True{}, pretty, ascii, D, True{}) ++ suffix, 1n+b), J.Machine{J.MArrayFirst{}, X.text(capacity, value, True{}, pretty, ascii, D, True{}) ++ suffix, fs, PD}) == Done{v} : Result<&2, &2, J.Error, J.Json>}:
  %Equal.sym(Nat, J.fuel_go(X.text(capacity, value, True{}, pretty, ascii, D, True{}) ++ suffix, 1n+b), 1n+J.fuel_go(X.text(capacity, value, True{}, pretty, ascii, D, True{}) ++ suffix, b), C.fuel_succ(X.text(capacity, value, True{}, pretty, ascii, D, True{}) ++ suffix, b)) : {J.parse_go(_, J.Machine{J.MArrayFirst{}, X.text(capacity, value, True{}, pretty, ascii, D, True{}) ++ suffix, fs, PD}) == Done{v} : Result<&2, &2, J.Error, J.Json>}
  %Equal.sym(J.Machine, J.step(J.Machine{J.MArrayFirst{}, X.text(capacity, value, True{}, pretty, ascii, D, True{}) ++ suffix, fs, PD}), J.Machine{J.MValue{}, X.text(capacity, value, True{}, pretty, ascii, D, True{}) ++ suffix, J.ArrayFrame{[]} <> fs, PD}, first_eq(capacity, value, pretty, ascii, D, suffix, fs, PD, good)) : {J.parse_go(J.fuel_go(X.text(capacity, value, True{}, pretty, ascii, D, True{}) ++ suffix, b), _) == Done{v} : Result<&2, &2, J.Error, J.Json>}
  h

# Literals, exact continuations turned into credit.
def null_cps(+suffix: String, +fs: List<&2, J.Frame>, +dp: Nat, +a: Nat, +v: J.Json, h: {J.parse_go(J.fuel_go(suffix, a), J.Machine{J.MEmit{J.JNull{}}, suffix, fs, dp}) == Done{v} : Result<&2, &2, J.Error, J.Json>}) -> {J.parse_go(J.fuel_go("null" ++ suffix, a), J.Machine{J.MValue{}, "null" ++ suffix, fs, dp}) == Done{v} : Result<&2, &2, J.Error, J.Json>}:
  C.credit(5n, 11n, suffix, a, J.Machine{J.MValue{}, "null" ++ suffix, fs, dp}, J.Machine{J.MEmit{J.JNull{}}, suffix, fs, dp}, v, JP.parse_null_continuation(J.fuel_go(suffix, Nat.add(11n, a)), suffix, fs, dp), h)

def true_cps(+suffix: String, +fs: List<&2, J.Frame>, +dp: Nat, +a: Nat, +v: J.Json, h: {J.parse_go(J.fuel_go(suffix, a), J.Machine{J.MEmit{J.JBool{True{}}}, suffix, fs, dp}) == Done{v} : Result<&2, &2, J.Error, J.Json>}) -> {J.parse_go(J.fuel_go("true" ++ suffix, a), J.Machine{J.MValue{}, "true" ++ suffix, fs, dp}) == Done{v} : Result<&2, &2, J.Error, J.Json>}:
  C.credit(5n, 11n, suffix, a, J.Machine{J.MValue{}, "true" ++ suffix, fs, dp}, J.Machine{J.MEmit{J.JBool{True{}}}, suffix, fs, dp}, v, JP.parse_true_continuation(J.fuel_go(suffix, Nat.add(11n, a)), suffix, fs, dp), h)

def false_cps(+suffix: String, +fs: List<&2, J.Frame>, +dp: Nat, +a: Nat, +v: J.Json, h: {J.parse_go(J.fuel_go(suffix, a), J.Machine{J.MEmit{J.JBool{False{}}}, suffix, fs, dp}) == Done{v} : Result<&2, &2, J.Error, J.Json>}) -> {J.parse_go(J.fuel_go("false" ++ suffix, a), J.Machine{J.MValue{}, "false" ++ suffix, fs, dp}) == Done{v} : Result<&2, &2, J.Error, J.Json>}:
  C.credit(6n, 14n, suffix, a, J.Machine{J.MValue{}, "false" ++ suffix, fs, dp}, J.Machine{J.MEmit{J.JBool{False{}}}, suffix, fs, dp}, v, JP.parse_false_continuation(J.fuel_go(suffix, Nat.add(14n, a)), suffix, fs, dp), h)

def string_ok(+s: String, good: {J.scalars(s) == True{} : Bool}) -> {U.valid(s) == True{} : Bool}:
  Equal.trans(Bool, U.valid(s), J.scalars(s), True{}, Equal.sym(Bool, J.scalars(s), U.valid(s), JP.scalars_equiv(s)), good)
def tree_cps(capacity: Nat, value: J.Json, +inc: Bool, +pretty: Bool, +ascii: Bool, +dp: Nat, +ra: List<&2, J.Json>, +ro: List<&2, J.Field>, +suffix: String, +fs: List<&2, J.Frame>, +a: Nat, +v: J.Json, +good: {ok(inc, capacity, value) == True{} : Bool}, +lim: {Nat.add(dp, capacity) == 512n : Nat}, +stop: {N.ends(suffix) == True{} : Bool}, done: {J.parse_go(J.fuel_go(suffix, a), J.Machine{J.MEmit{end_value(inc, value, ra, ro)}, suffix, fs, dp}) == Done{v} : Result<&2, &2, J.Error, J.Json>}) -> {J.parse_go(J.fuel_go(X.text(capacity, value, inc, pretty, ascii, start_depth(inc, dp), inc) ++ suffix, a), J.Machine{start_mode(inc, value, ra, ro), X.text(capacity, value, inc, pretty, ascii, start_depth(inc, dp), inc) ++ suffix, fs, start_depth(inc, dp)}) == Done{v} : Result<&2, &2, J.Error, J.Json>}:
  match capacity value:
    case cap J.JNull{}:
      match inc:
        case True{}: null_cps(suffix, fs, dp, a, v, done)
        case False{}: P.absurd({J.parse_go(J.fuel_go(X.text(cap, J.JNull{}, False{}, pretty, ascii, start_depth(False{}, dp), False{}) ++ suffix, a), J.Machine{start_mode(False{}, J.JNull{}, ra, ro), X.text(cap, J.JNull{}, False{}, pretty, ascii, start_depth(False{}, dp), False{}) ++ suffix, fs, start_depth(False{}, dp)}) == Done{v} : Result<&2, &2, J.Error, J.Json>}, P.false_true(good))
    case cap J.JBool{True{}}:
      match inc:
        case True{}: true_cps(suffix, fs, dp, a, v, done)
        case False{}: P.absurd({J.parse_go(J.fuel_go(X.text(cap, J.JBool{True{}}, False{}, pretty, ascii, start_depth(False{}, dp), False{}) ++ suffix, a), J.Machine{start_mode(False{}, J.JBool{True{}}, ra, ro), X.text(cap, J.JBool{True{}}, False{}, pretty, ascii, start_depth(False{}, dp), False{}) ++ suffix, fs, start_depth(False{}, dp)}) == Done{v} : Result<&2, &2, J.Error, J.Json>}, P.false_true(good))
    case cap J.JBool{False{}}:
      match inc:
        case True{}: false_cps(suffix, fs, dp, a, v, done)
        case False{}: P.absurd({J.parse_go(J.fuel_go(X.text(cap, J.JBool{False{}}, False{}, pretty, ascii, start_depth(False{}, dp), False{}) ++ suffix, a), J.Machine{start_mode(False{}, J.JBool{False{}}, ra, ro), X.text(cap, J.JBool{False{}}, False{}, pretty, ascii, start_depth(False{}, dp), False{}) ++ suffix, fs, start_depth(False{}, dp)}) == Done{v} : Result<&2, &2, J.Error, J.Json>}, P.false_true(good))
    case cap J.JNumber{+s}:
      match inc:
        case True{}: N.number_cps(s, suffix, fs, dp, a, v, good, stop, done)
        case False{}: P.absurd({J.parse_go(J.fuel_go(X.text(cap, J.JNumber{s}, False{}, pretty, ascii, start_depth(False{}, dp), False{}) ++ suffix, a), J.Machine{start_mode(False{}, J.JNumber{s}, ra, ro), X.text(cap, J.JNumber{s}, False{}, pretty, ascii, start_depth(False{}, dp), False{}) ++ suffix, fs, start_depth(False{}, dp)}) == Done{v} : Result<&2, &2, J.Error, J.Json>}, P.false_true(good))
    case cap J.JString{+s}:
      match inc:
        case True{}: Q.string_cps(s, ascii, suffix, fs, dp, a, v, string_ok(s, good), done)
        case False{}: P.absurd({J.parse_go(J.fuel_go(X.text(cap, J.JString{s}, False{}, pretty, ascii, start_depth(False{}, dp), False{}) ++ suffix, a), J.Machine{start_mode(False{}, J.JString{s}, ra, ro), X.text(cap, J.JString{s}, False{}, pretty, ascii, start_depth(False{}, dp), False{}) ++ suffix, fs, start_depth(False{}, dp)}) == Done{v} : Result<&2, &2, J.Error, J.Json>}, P.false_true(good))
    case 0n J.JArray{xs}:
      match inc:
        case True{}: P.absurd({J.parse_go(J.fuel_go(X.text(0n, J.JArray{xs}, True{}, pretty, ascii, start_depth(True{}, dp), True{}) ++ suffix, a), J.Machine{start_mode(True{}, J.JArray{xs}, ra, ro), X.text(0n, J.JArray{xs}, True{}, pretty, ascii, start_depth(True{}, dp), True{}) ++ suffix, fs, start_depth(True{}, dp)}) == Done{v} : Result<&2, &2, J.Error, J.Json>}, P.false_true(good))
        case False{}: P.absurd({J.parse_go(J.fuel_go(X.text(0n, J.JArray{xs}, False{}, pretty, ascii, start_depth(False{}, dp), False{}) ++ suffix, a), J.Machine{start_mode(False{}, J.JArray{xs}, ra, ro), X.text(0n, J.JArray{xs}, False{}, pretty, ascii, start_depth(False{}, dp), False{}) ++ suffix, fs, start_depth(False{}, dp)}) == Done{v} : Result<&2, &2, J.Error, J.Json>}, P.false_true(good))
    case 0n J.JObject{xs}:
      match inc:
        case True{}: P.absurd({J.parse_go(J.fuel_go(X.text(0n, J.JObject{xs}, True{}, pretty, ascii, start_depth(True{}, dp), True{}) ++ suffix, a), J.Machine{start_mode(True{}, J.JObject{xs}, ra, ro), X.text(0n, J.JObject{xs}, True{}, pretty, ascii, start_depth(True{}, dp), True{}) ++ suffix, fs, start_depth(True{}, dp)}) == Done{v} : Result<&2, &2, J.Error, J.Json>}, P.false_true(good))
        case False{}: P.absurd({J.parse_go(J.fuel_go(X.text(0n, J.JObject{xs}, False{}, pretty, ascii, start_depth(False{}, dp), False{}) ++ suffix, a), J.Machine{start_mode(False{}, J.JObject{xs}, ra, ro), X.text(0n, J.JObject{xs}, False{}, pretty, ascii, start_depth(False{}, dp), False{}) ++ suffix, fs, start_depth(False{}, dp)}) == Done{v} : Result<&2, &2, J.Error, J.Json>}, P.false_true(good))
    case 1n++r J.JArray{Nil{}}:
      match inc:
        case True{}:
          C.consume_full('[', SCon{']', suffix}, a, J.Machine{J.MValue{}, SCon{'[', SCon{']', suffix}}, fs, dp}, v, open_arr(SCon{']', suffix}, fs, dp, 3n+a, v, ge_false(dp, r, lim), C.consume(']', suffix, 3n+a, J.Machine{J.MArrayFirst{}, SCon{']', suffix}, fs, 1n+dp}, v, C.raise_add(3n, suffix, a, J.Machine{J.MEmit{J.JArray{[]}}, suffix, fs, dp}, v, done), {==})), {==})
        case False{}:
          %Equal.sym(String, (J.line(pretty, dp) ++ "]") ++ suffix, J.line(pretty, dp) ++ ("]" ++ suffix), Sup.append_assoc(J.line(pretty, dp), "]", suffix)) : {J.parse_go(J.fuel_go(_, a), J.Machine{J.MArrayAfter{ra}, _, fs, 1n+dp}) == Done{v} : Result<&2, &2, J.Error, J.Json>}
          ws_cps(J.line(pretty, dp), J.MArrayAfter{ra}, SCon{']', suffix}, fs, 1n+dp, a, v, {==}, JS.line_spaces(pretty, dp), C.consume(']', suffix, a, J.Machine{J.MArrayAfter{ra}, SCon{']', suffix}, fs, 1n+dp}, v, done, {==}))
    case 1n++r J.JArray{+h <> +t}:
      match inc:
        case True{}:
          %Equal.sym(String, (J.line(pretty, 1n+dp) ++ (X.text(r, h, True{}, pretty, ascii, 1n+dp, True{}) ++ X.text(1n+r, J.JArray{t}, False{}, pretty, ascii, 1n+dp, False{}))) ++ suffix, J.line(pretty, 1n+dp) ++ (X.text(r, h, True{}, pretty, ascii, 1n+dp, True{}) ++ (X.text(1n+r, J.JArray{t}, False{}, pretty, ascii, 1n+dp, False{}) ++ suffix)), assoc3(J.line(pretty, 1n+dp), X.text(r, h, True{}, pretty, ascii, 1n+dp, True{}), X.text(1n+r, J.JArray{t}, False{}, pretty, ascii, 1n+dp, False{}), suffix)) : {J.parse_go(J.fuel_go(SCon{'[', _}, a), J.Machine{J.MValue{}, SCon{'[', _}, fs, dp}) == Done{v} : Result<&2, &2, J.Error, J.Json>}
          C.consume_full('[', J.line(pretty, 1n+dp) ++ (X.text(r, h, True{}, pretty, ascii, 1n+dp, True{}) ++ (X.text(1n+r, J.JArray{t}, False{}, pretty, ascii, 1n+dp, False{}) ++ suffix)), a, J.Machine{J.MValue{}, SCon{'[', J.line(pretty, 1n+dp) ++ (X.text(r, h, True{}, pretty, ascii, 1n+dp, True{}) ++ (X.text(1n+r, J.JArray{t}, False{}, pretty, ascii, 1n+dp, False{}) ++ suffix))}, fs, dp}, v, open_arr(J.line(pretty, 1n+dp) ++ (X.text(r, h, True{}, pretty, ascii, 1n+dp, True{}) ++ (X.text(1n+r, J.JArray{t}, False{}, pretty, ascii, 1n+dp, False{}) ++ suffix)), fs, dp, 3n+a, v, ge_false(dp, r, lim), ws_cps(J.line(pretty, 1n+dp), J.MArrayFirst{}, X.text(r, h, True{}, pretty, ascii, 1n+dp, True{}) ++ (X.text(1n+r, J.JArray{t}, False{}, pretty, ascii, 1n+dp, False{}) ++ suffix), fs, 1n+dp, 3n+a, v, {==}, JS.line_spaces(pretty, 1n+dp), first_cps(r, h, pretty, ascii, 1n+dp, X.text(1n+r, J.JArray{t}, False{}, pretty, ascii, 1n+dp, False{}) ++ suffix, fs, 1n+dp, 2n+a, v, P.and_left(T.valid_at(r, h), T.valid_at(1n+r, J.JArray{t}), good), C.raise_add(1n, X.text(r, h, True{}, pretty, ascii, 1n+dp, True{}) ++ (X.text(1n+r, J.JArray{t}, False{}, pretty, ascii, 1n+dp, False{}) ++ suffix), 1n+a, J.Machine{J.MValue{}, X.text(r, h, True{}, pretty, ascii, 1n+dp, True{}) ++ (X.text(1n+r, J.JArray{t}, False{}, pretty, ascii, 1n+dp, False{}) ++ suffix), J.ArrayFrame{[]} <> fs, 1n+dp}, v, tree_cps(r, h, True{}, pretty, ascii, 1n+dp, ra, ro, X.text(1n+r, J.JArray{t}, False{}, pretty, ascii, 1n+dp, False{}) ++ suffix, J.ArrayFrame{[]} <> fs, 1n+a, v, P.and_left(T.valid_at(r, h), T.valid_at(1n+r, J.JArray{t}), good), child_lim(dp, r, lim), tail_ends_arr(r, t, pretty, ascii, dp, suffix), emit_arr(X.text(1n+r, J.JArray{t}, False{}, pretty, ascii, 1n+dp, False{}) ++ suffix, a, h, [], fs, 1n+dp, v, tree_cps(1n+r, J.JArray{t}, False{}, pretty, ascii, dp, h <> [], ro, suffix, fs, a, v, P.and_right(T.valid_at(r, h), T.valid_at(1n+r, J.JArray{t}), good), lim, stop, arr_end(h, t, suffix, fs, dp, a, v, done)))))))), {==})
        case False{}:
          %Equal.sym(String, (J.line(pretty, 1n+dp) ++ (X.text(r, h, True{}, pretty, ascii, 1n+dp, True{}) ++ X.text(1n+r, J.JArray{t}, False{}, pretty, ascii, 1n+dp, False{}))) ++ suffix, J.line(pretty, 1n+dp) ++ (X.text(r, h, True{}, pretty, ascii, 1n+dp, True{}) ++ (X.text(1n+r, J.JArray{t}, False{}, pretty, ascii, 1n+dp, False{}) ++ suffix)), assoc3(J.line(pretty, 1n+dp), X.text(r, h, True{}, pretty, ascii, 1n+dp, True{}), X.text(1n+r, J.JArray{t}, False{}, pretty, ascii, 1n+dp, False{}), suffix)) : {J.parse_go(J.fuel_go(SCon{',', _}, a), J.Machine{J.MArrayAfter{ra}, SCon{',', _}, fs, 1n+dp}) == Done{v} : Result<&2, &2, J.Error, J.Json>}
          C.consume_full(',', J.line(pretty, 1n+dp) ++ (X.text(r, h, True{}, pretty, ascii, 1n+dp, True{}) ++ (X.text(1n+r, J.JArray{t}, False{}, pretty, ascii, 1n+dp, False{}) ++ suffix)), a, J.Machine{J.MArrayAfter{ra}, SCon{',', J.line(pretty, 1n+dp) ++ (X.text(r, h, True{}, pretty, ascii, 1n+dp, True{}) ++ (X.text(1n+r, J.JArray{t}, False{}, pretty, ascii, 1n+dp, False{}) ++ suffix))}, fs, 1n+dp}, v, C.raise_add(2n, J.line(pretty, 1n+dp) ++ (X.text(r, h, True{}, pretty, ascii, 1n+dp, True{}) ++ (X.text(1n+r, J.JArray{t}, False{}, pretty, ascii, 1n+dp, False{}) ++ suffix)), 1n+a, J.Machine{J.MValue{}, J.line(pretty, 1n+dp) ++ (X.text(r, h, True{}, pretty, ascii, 1n+dp, True{}) ++ (X.text(1n+r, J.JArray{t}, False{}, pretty, ascii, 1n+dp, False{}) ++ suffix)), J.ArrayFrame{ra} <> fs, 1n+dp}, v, ws_cps(J.line(pretty, 1n+dp), J.MValue{}, X.text(r, h, True{}, pretty, ascii, 1n+dp, True{}) ++ (X.text(1n+r, J.JArray{t}, False{}, pretty, ascii, 1n+dp, False{}) ++ suffix), J.ArrayFrame{ra} <> fs, 1n+dp, 1n+a, v, {==}, JS.line_spaces(pretty, 1n+dp), tree_cps(r, h, True{}, pretty, ascii, 1n+dp, ra, ro, X.text(1n+r, J.JArray{t}, False{}, pretty, ascii, 1n+dp, False{}) ++ suffix, J.ArrayFrame{ra} <> fs, 1n+a, v, P.and_left(T.valid_at(r, h), T.valid_at(1n+r, J.JArray{t}), good), child_lim(dp, r, lim), tail_ends_arr(r, t, pretty, ascii, dp, suffix), emit_arr(X.text(1n+r, J.JArray{t}, False{}, pretty, ascii, 1n+dp, False{}) ++ suffix, a, h, ra, fs, 1n+dp, v, tree_cps(1n+r, J.JArray{t}, False{}, pretty, ascii, dp, h <> ra, ro, suffix, fs, a, v, P.and_right(T.valid_at(r, h), T.valid_at(1n+r, J.JArray{t}), good), lim, stop, done))))), {==})
    case 1n++r J.JObject{Nil{}}:
      match inc:
        case True{}:
          C.consume_full('{', SCon{'}', suffix}, a, J.Machine{J.MValue{}, SCon{'{', SCon{'}', suffix}}, fs, dp}, v, open_obj(SCon{'}', suffix}, fs, dp, 3n+a, v, ge_false(dp, r, lim), C.consume('}', suffix, 3n+a, J.Machine{J.MReadKey{True{}}, SCon{'}', suffix}, J.ObjectFrame{[]} <> fs, 1n+dp}, v, C.raise_add(3n, suffix, a, J.Machine{J.MEmit{J.JObject{[]}}, suffix, fs, dp}, v, done), {==})), {==})
        case False{}:
          %Equal.sym(String, (J.line(pretty, dp) ++ "}") ++ suffix, J.line(pretty, dp) ++ ("}" ++ suffix), Sup.append_assoc(J.line(pretty, dp), "}", suffix)) : {J.parse_go(J.fuel_go(_, a), J.Machine{J.MObjectAfter{ro}, _, fs, 1n+dp}) == Done{v} : Result<&2, &2, J.Error, J.Json>}
          ws_cps(J.line(pretty, dp), J.MObjectAfter{ro}, SCon{'}', suffix}, fs, 1n+dp, a, v, {==}, JS.line_spaces(pretty, dp), C.consume('}', suffix, a, J.Machine{J.MObjectAfter{ro}, SCon{'}', suffix}, fs, 1n+dp}, v, done, {==}))
    case 1n++r J.JObject{J.Field{+k, +h} <> +t}:
      match inc:
        case True{}:
          %Equal.sym(String, (J.line(pretty, 1n+dp) ++ (J.quote(k, ascii) ++ (J.colon(pretty) ++ (X.text(r, h, True{}, pretty, ascii, 1n+dp, True{}) ++ X.text(1n+r, J.JObject{t}, False{}, pretty, ascii, 1n+dp, False{}))))) ++ suffix, J.line(pretty, 1n+dp) ++ (J.quote(k, ascii) ++ (J.colon(pretty) ++ (X.text(r, h, True{}, pretty, ascii, 1n+dp, True{}) ++ (X.text(1n+r, J.JObject{t}, False{}, pretty, ascii, 1n+dp, False{}) ++ suffix)))), assoc5(J.line(pretty, 1n+dp), J.quote(k, ascii), J.colon(pretty), X.text(r, h, True{}, pretty, ascii, 1n+dp, True{}), X.text(1n+r, J.JObject{t}, False{}, pretty, ascii, 1n+dp, False{}), suffix)) : {J.parse_go(J.fuel_go(SCon{'{', _}, a), J.Machine{J.MValue{}, SCon{'{', _}, fs, dp}) == Done{v} : Result<&2, &2, J.Error, J.Json>}
          C.consume_full('{', J.line(pretty, 1n+dp) ++ (J.quote(k, ascii) ++ (J.colon(pretty) ++ (X.text(r, h, True{}, pretty, ascii, 1n+dp, True{}) ++ (X.text(1n+r, J.JObject{t}, False{}, pretty, ascii, 1n+dp, False{}) ++ suffix)))), a, J.Machine{J.MValue{}, SCon{'{', J.line(pretty, 1n+dp) ++ (J.quote(k, ascii) ++ (J.colon(pretty) ++ (X.text(r, h, True{}, pretty, ascii, 1n+dp, True{}) ++ (X.text(1n+r, J.JObject{t}, False{}, pretty, ascii, 1n+dp, False{}) ++ suffix))))}, fs, dp}, v, open_obj(J.line(pretty, 1n+dp) ++ (J.quote(k, ascii) ++ (J.colon(pretty) ++ (X.text(r, h, True{}, pretty, ascii, 1n+dp, True{}) ++ (X.text(1n+r, J.JObject{t}, False{}, pretty, ascii, 1n+dp, False{}) ++ suffix)))), fs, dp, 3n+a, v, ge_false(dp, r, lim), C.raise_add(2n, J.line(pretty, 1n+dp) ++ (J.quote(k, ascii) ++ (J.colon(pretty) ++ (X.text(r, h, True{}, pretty, ascii, 1n+dp, True{}) ++ (X.text(1n+r, J.JObject{t}, False{}, pretty, ascii, 1n+dp, False{}) ++ suffix)))), 1n+a, J.Machine{J.MReadKey{True{}}, J.line(pretty, 1n+dp) ++ (J.quote(k, ascii) ++ (J.colon(pretty) ++ (X.text(r, h, True{}, pretty, ascii, 1n+dp, True{}) ++ (X.text(1n+r, J.JObject{t}, False{}, pretty, ascii, 1n+dp, False{}) ++ suffix)))), J.ObjectFrame{[]} <> fs, 1n+dp}, v, ws_cps(J.line(pretty, 1n+dp), J.MReadKey{True{}}, J.quote(k, ascii) ++ (J.colon(pretty) ++ (X.text(r, h, True{}, pretty, ascii, 1n+dp, True{}) ++ (X.text(1n+r, J.JObject{t}, False{}, pretty, ascii, 1n+dp, False{}) ++ suffix))), J.ObjectFrame{[]} <> fs, 1n+dp, 1n+a, v, {==}, JS.line_spaces(pretty, 1n+dp), Q.key_cps(k, ascii, True{}, J.colon(pretty) ++ (X.text(r, h, True{}, pretty, ascii, 1n+dp, True{}) ++ (X.text(1n+r, J.JObject{t}, False{}, pretty, ascii, 1n+dp, False{}) ++ suffix)), J.ObjectFrame{[]} <> fs, 1n+dp, 1n+a, v, string_ok(k, P.and_left(J.scalars(k), T.valid_at(r, h) && T.valid_at(1n+r, J.JObject{t}), good)), colon_cps(pretty, k, [], X.text(r, h, True{}, pretty, ascii, 1n+dp, True{}) ++ (X.text(1n+r, J.JObject{t}, False{}, pretty, ascii, 1n+dp, False{}) ++ suffix), fs, 1n+dp, 1n+a, v, tree_cps(r, h, True{}, pretty, ascii, 1n+dp, ra, ro, X.text(1n+r, J.JObject{t}, False{}, pretty, ascii, 1n+dp, False{}) ++ suffix, J.MemberFrame{k, []} <> fs, 1n+a, v, P.and_left(T.valid_at(r, h), T.valid_at(1n+r, J.JObject{t}), P.and_right(J.scalars(k), T.valid_at(r, h) && T.valid_at(1n+r, J.JObject{t}), good)), child_lim(dp, r, lim), tail_ends_obj(r, t, pretty, ascii, dp, suffix), emit_mem(X.text(1n+r, J.JObject{t}, False{}, pretty, ascii, 1n+dp, False{}) ++ suffix, a, h, k, [], fs, 1n+dp, v, tree_cps(1n+r, J.JObject{t}, False{}, pretty, ascii, dp, ra, J.Field{k, h} <> [], suffix, fs, a, v, P.and_right(T.valid_at(r, h), T.valid_at(1n+r, J.JObject{t}), P.and_right(J.scalars(k), T.valid_at(r, h) && T.valid_at(1n+r, J.JObject{t}), good)), lim, stop, obj_end(J.Field{k, h}, t, suffix, fs, dp, a, v, done))))))))), {==})
        case False{}:
          %Equal.sym(String, (J.line(pretty, 1n+dp) ++ (J.quote(k, ascii) ++ (J.colon(pretty) ++ (X.text(r, h, True{}, pretty, ascii, 1n+dp, True{}) ++ X.text(1n+r, J.JObject{t}, False{}, pretty, ascii, 1n+dp, False{}))))) ++ suffix, J.line(pretty, 1n+dp) ++ (J.quote(k, ascii) ++ (J.colon(pretty) ++ (X.text(r, h, True{}, pretty, ascii, 1n+dp, True{}) ++ (X.text(1n+r, J.JObject{t}, False{}, pretty, ascii, 1n+dp, False{}) ++ suffix)))), assoc5(J.line(pretty, 1n+dp), J.quote(k, ascii), J.colon(pretty), X.text(r, h, True{}, pretty, ascii, 1n+dp, True{}), X.text(1n+r, J.JObject{t}, False{}, pretty, ascii, 1n+dp, False{}), suffix)) : {J.parse_go(J.fuel_go(SCon{',', _}, a), J.Machine{J.MObjectAfter{ro}, SCon{',', _}, fs, 1n+dp}) == Done{v} : Result<&2, &2, J.Error, J.Json>}
          C.consume_full(',', J.line(pretty, 1n+dp) ++ (J.quote(k, ascii) ++ (J.colon(pretty) ++ (X.text(r, h, True{}, pretty, ascii, 1n+dp, True{}) ++ (X.text(1n+r, J.JObject{t}, False{}, pretty, ascii, 1n+dp, False{}) ++ suffix)))), a, J.Machine{J.MObjectAfter{ro}, SCon{',', J.line(pretty, 1n+dp) ++ (J.quote(k, ascii) ++ (J.colon(pretty) ++ (X.text(r, h, True{}, pretty, ascii, 1n+dp, True{}) ++ (X.text(1n+r, J.JObject{t}, False{}, pretty, ascii, 1n+dp, False{}) ++ suffix))))}, fs, 1n+dp}, v, C.raise_add(2n, J.line(pretty, 1n+dp) ++ (J.quote(k, ascii) ++ (J.colon(pretty) ++ (X.text(r, h, True{}, pretty, ascii, 1n+dp, True{}) ++ (X.text(1n+r, J.JObject{t}, False{}, pretty, ascii, 1n+dp, False{}) ++ suffix)))), 1n+a, J.Machine{J.MReadKey{False{}}, J.line(pretty, 1n+dp) ++ (J.quote(k, ascii) ++ (J.colon(pretty) ++ (X.text(r, h, True{}, pretty, ascii, 1n+dp, True{}) ++ (X.text(1n+r, J.JObject{t}, False{}, pretty, ascii, 1n+dp, False{}) ++ suffix)))), J.ObjectFrame{ro} <> fs, 1n+dp}, v, ws_cps(J.line(pretty, 1n+dp), J.MReadKey{False{}}, J.quote(k, ascii) ++ (J.colon(pretty) ++ (X.text(r, h, True{}, pretty, ascii, 1n+dp, True{}) ++ (X.text(1n+r, J.JObject{t}, False{}, pretty, ascii, 1n+dp, False{}) ++ suffix))), J.ObjectFrame{ro} <> fs, 1n+dp, 1n+a, v, {==}, JS.line_spaces(pretty, 1n+dp), Q.key_cps(k, ascii, False{}, J.colon(pretty) ++ (X.text(r, h, True{}, pretty, ascii, 1n+dp, True{}) ++ (X.text(1n+r, J.JObject{t}, False{}, pretty, ascii, 1n+dp, False{}) ++ suffix)), J.ObjectFrame{ro} <> fs, 1n+dp, 1n+a, v, string_ok(k, P.and_left(J.scalars(k), T.valid_at(r, h) && T.valid_at(1n+r, J.JObject{t}), good)), colon_cps(pretty, k, ro, X.text(r, h, True{}, pretty, ascii, 1n+dp, True{}) ++ (X.text(1n+r, J.JObject{t}, False{}, pretty, ascii, 1n+dp, False{}) ++ suffix), fs, 1n+dp, 1n+a, v, tree_cps(r, h, True{}, pretty, ascii, 1n+dp, ra, ro, X.text(1n+r, J.JObject{t}, False{}, pretty, ascii, 1n+dp, False{}) ++ suffix, J.MemberFrame{k, ro} <> fs, 1n+a, v, P.and_left(T.valid_at(r, h), T.valid_at(1n+r, J.JObject{t}), P.and_right(J.scalars(k), T.valid_at(r, h) && T.valid_at(1n+r, J.JObject{t}), good)), child_lim(dp, r, lim), tail_ends_obj(r, t, pretty, ascii, dp, suffix), emit_mem(X.text(1n+r, J.JObject{t}, False{}, pretty, ascii, 1n+dp, False{}) ++ suffix, a, h, k, ro, fs, 1n+dp, v, tree_cps(1n+r, J.JObject{t}, False{}, pretty, ascii, dp, ra, J.Field{k, h} <> ro, suffix, fs, a, v, P.and_right(T.valid_at(r, h), T.valid_at(1n+r, J.JObject{t}), P.and_right(J.scalars(k), T.valid_at(r, h) && T.valid_at(1n+r, J.JObject{t}), good)), lim, stop, done))))))), {==})

# BND-28: the writer's exact output decodes and parses back to the value.
def output_text(+value: J.Json, +pretty: Bool, +ascii: Bool) -> {String.reverse(W.render_acc(512n, value, True{}, pretty, ascii, 0n, True{}, "")) == X.text(512n, value, True{}, pretty, ascii, 0n, True{}) : String}:
  Equal.trans(String, String.reverse(W.render_acc(512n, value, True{}, pretty, ascii, 0n, True{}, "")), String.reverse(String.reverse.go(X.text(512n, value, True{}, pretty, ascii, 0n, True{}), "")), X.text(512n, value, True{}, pretty, ascii, 0n, True{}), Equal.cong(String, String, s => String.reverse(s), W.render_acc(512n, value, True{}, pretty, ascii, 0n, True{}, ""), String.reverse.go(X.text(512n, value, True{}, pretty, ascii, 0n, True{}), ""), X.render_eq(512n, value, True{}, pretty, ascii, 0n, True{}, "")), Sup.reverse_go_inverse(X.text(512n, value, True{}, pretty, ascii, 0n, True{}), ""))

def parse_text(+value: J.Json, +pretty: Bool, +ascii: Bool, +tree: {T.valid_at(512n, value) == True{} : Bool}) -> {J.parse_string(X.text(512n, value, True{}, pretty, ascii, 0n, True{})) == Done{value} : Result<&2, &2, J.Error, J.Json>}:
  %Sup.append_nil(X.text(512n, value, True{}, pretty, ascii, 0n, True{})) : {J.parse_go(J.fuel_go(_, 16n), J.Machine{J.MValue{}, _, [], 0n}) == Done{value} : Result<&2, &2, J.Error, J.Json>}
  tree_cps(512n, value, True{}, pretty, ascii, 0n, [], [], "", [], 16n, value, tree, {==}, {==}, JP.parse_root_return(15n, value))

def parse_output(+value: J.Json, +pretty: Bool, +ascii: Bool, +valid: {J.admissible(value) == True{} : Bool}) -> {J.parse(U.encode(String.reverse(W.render_acc(512n, value, True{}, pretty, ascii, 0n, True{}, "")))) == Done{value} : Result<&2, &2, J.Error, J.Json>}:
  +tree = Equal.trans(Bool, T.valid_at(512n, value), J.admissible(value), True{}, Equal.sym(Bool, J.admissible(value), T.valid_at(512n, value), T.admissible_equiv(value)), valid)
  %Equal.sym(String, String.reverse(W.render_acc(512n, value, True{}, pretty, ascii, 0n, True{}, "")), X.text(512n, value, True{}, pretty, ascii, 0n, True{}), output_text(value, pretty, ascii)) : {J.parse(U.encode(_)) == Done{value} : Result<&2, &2, J.Error, J.Json>}
  %Equal.sym(Maybe<&2, String>, J.decode(U.encode(X.text(512n, value, True{}, pretty, ascii, 0n, True{}))), Some{X.text(512n, value, True{}, pretty, ascii, 0n, True{})}, JC.roundtrip(X.text(512n, value, True{}, pretty, ascii, 0n, True{}), X.text_valid(512n, value, True{}, pretty, ascii, 0n, True{}, tree))) : {J.parse_decoded(_) == Done{value} : Result<&2, &2, J.Error, J.Json>}
  parse_text(value, pretty, ascii, tree)
