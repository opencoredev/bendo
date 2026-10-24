# Quoted JSON text parses back through every escape the writer can choose,
# in credit form: the continuation after the text is arbitrary.
import Base
import ../src/data/json.bend as J
import ../src/data/utf8.bend as U
import ./utf8.bend as P
import ./json-support.bend as Sup
import ./json-escape.bend as E
import ./json-surrogate.bend as S
import ./json-credit.bend as C
import ./json-classes.bend as K

def lt_false_ge(o: Cmp, e: {Cmp.is_lt(o) == False{} : Bool}) -> {Cmp.is_ge(o) == True{} : Bool}:
  match o:
    case LT{}: P.absurd({Cmp.is_ge(LT{}) == True{} : Bool}, P.false_true(Equal.sym(Bool, True{}, False{}, e)))
    case EQ{}: {==}
    case GT{}: {==}

def or_false_left(a: Bool, b: Bool, e: {a || b == False{} : Bool}) -> {a == False{} : Bool}:
  match a:
    case False{}: {==}
    case True{}: P.absurd({True{} == False{} : Bool}, P.false_true(Equal.sym(Bool, True{}, False{}, e)))

def printable_of(+c: U32, ascii: Bool, e: {(c < 32 : U32) || (ascii && (c > 127 : U32)) == False{} : Bool}) -> {(c >= 32 : U32) == True{} : Bool}:
  lt_false_ge(U32.cmp(c, 32), or_false_left((c < 32 : U32), ascii && (c > 127 : U32), e))

# Seven short escapes, two characters and two transitions each.
def short_cps(kind: E.Short, +ascii: Bool, +rev: String, +key: Bool, +suffix: String, +stack: List<&2, J.Frame>, +depth: Nat, +a: Nat, +v: J.Json, h: {J.parse_go(J.fuel_go(suffix, a), J.Machine{J.MText{SCon{Chr{E.short_code(kind)}, rev}, key}, suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>}) -> {J.parse_go(J.fuel_go(J.escape_char(E.short_code(kind), ascii) ++ suffix, a), J.Machine{J.MText{rev, key}, J.escape_char(E.short_code(kind), ascii) ++ suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>}:
  match kind:
    case E.Quote{}: C.credit(2n, 6n, suffix, a, J.Machine{J.MText{rev, key}, J.escape_char(34, ascii) ++ suffix, stack, depth}, J.Machine{J.MText{SCon{Chr{34}, rev}, key}, suffix, stack, depth}, v, E.short_escape(E.Quote{}, ascii, rev, key, suffix, stack, depth, J.fuel_go(suffix, Nat.add(6n, a))), h)
    case E.Backslash{}: C.credit(2n, 6n, suffix, a, J.Machine{J.MText{rev, key}, J.escape_char(92, ascii) ++ suffix, stack, depth}, J.Machine{J.MText{SCon{Chr{92}, rev}, key}, suffix, stack, depth}, v, E.short_escape(E.Backslash{}, ascii, rev, key, suffix, stack, depth, J.fuel_go(suffix, Nat.add(6n, a))), h)
    case E.Backspace{}: C.credit(2n, 6n, suffix, a, J.Machine{J.MText{rev, key}, J.escape_char(8, ascii) ++ suffix, stack, depth}, J.Machine{J.MText{SCon{Chr{8}, rev}, key}, suffix, stack, depth}, v, E.short_escape(E.Backspace{}, ascii, rev, key, suffix, stack, depth, J.fuel_go(suffix, Nat.add(6n, a))), h)
    case E.FormFeed{}: C.credit(2n, 6n, suffix, a, J.Machine{J.MText{rev, key}, J.escape_char(12, ascii) ++ suffix, stack, depth}, J.Machine{J.MText{SCon{Chr{12}, rev}, key}, suffix, stack, depth}, v, E.short_escape(E.FormFeed{}, ascii, rev, key, suffix, stack, depth, J.fuel_go(suffix, Nat.add(6n, a))), h)
    case E.Newline{}: C.credit(2n, 6n, suffix, a, J.Machine{J.MText{rev, key}, J.escape_char(10, ascii) ++ suffix, stack, depth}, J.Machine{J.MText{SCon{Chr{10}, rev}, key}, suffix, stack, depth}, v, E.short_escape(E.Newline{}, ascii, rev, key, suffix, stack, depth, J.fuel_go(suffix, Nat.add(6n, a))), h)
    case E.Return{}: C.credit(2n, 6n, suffix, a, J.Machine{J.MText{rev, key}, J.escape_char(13, ascii) ++ suffix, stack, depth}, J.Machine{J.MText{SCon{Chr{13}, rev}, key}, suffix, stack, depth}, v, E.short_escape(E.Return{}, ascii, rev, key, suffix, stack, depth, J.fuel_go(suffix, Nat.add(6n, a))), h)
    case E.Tab{}: C.credit(2n, 6n, suffix, a, J.Machine{J.MText{rev, key}, J.escape_char(9, ascii) ++ suffix, stack, depth}, J.Machine{J.MText{SCon{Chr{9}, rev}, key}, suffix, stack, depth}, v, E.short_escape(E.Tab{}, ascii, rev, key, suffix, stack, depth, J.fuel_go(suffix, Nat.add(6n, a))), h)
def at_short(+c: U32, +kind: E.Short, +ascii: Bool, +rev: String, +key: Bool, +suffix: String, +stack: List<&2, J.Frame>, +depth: Nat, +a: Nat, +v: J.Json, e: {c == E.short_code(kind) : U32}) -> {J.parse_go(J.fuel_go(suffix, a), J.Machine{J.MText{SCon{Chr{c}, rev}, key}, suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>} -> {J.parse_go(J.fuel_go(J.escape_char(c, ascii) ++ suffix, a), J.Machine{J.MText{rev, key}, J.escape_char(c, ascii) ++ suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>}:
  %Equal.sym(U32, c, E.short_code(kind), e) : {J.parse_go(J.fuel_go(suffix, a), J.Machine{J.MText{SCon{Chr{_}, rev}, key}, suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>} -> {J.parse_go(J.fuel_go(J.escape_char(_, ascii) ++ suffix, a), J.Machine{J.MText{rev, key}, J.escape_char(_, ascii) ++ suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>}
  h => short_cps(kind, ascii, rev, key, suffix, stack, depth, a, v, h)

# Six characters, seven transitions.
def bmp_cps(+c: U32, +rev: String, +key: Bool, +suffix: String, +stack: List<&2, J.Frame>, +depth: Nat, +a: Nat, +v: J.Json, +bounded: {(c <= 65535 : U32) == True{} : Bool}, +scalar: {U.scalar(c) == True{} : Bool}, h: {J.parse_go(J.fuel_go(suffix, a), J.Machine{J.MText{SCon{Chr{c}, rev}, key}, suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>}) -> {J.parse_go(J.fuel_go(J.hex4(c) ++ suffix, a), J.Machine{J.MText{rev, key}, J.hex4(c) ++ suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>}:
  C.credit(7n, 17n, suffix, a, J.Machine{J.MText{rev, key}, J.hex4(c) ++ suffix, stack, depth}, J.Machine{J.MText{SCon{Chr{c}, rev}, key}, suffix, stack, depth}, v, E.bmp_escape_u32(c, rev, key, suffix, stack, depth, J.fuel_go(suffix, Nat.add(17n, a)), bounded, scalar), h)

# Twelve characters, fourteen transitions.
def pair_cps(+c: U32, +rev: String, +key: Bool, +suffix: String, +stack: List<&2, J.Frame>, +depth: Nat, +a: Nat, +v: J.Json, +scalar: {U.scalar(c) == True{} : Bool}, +large: {(c <= 65535 : U32) == False{} : Bool}, h: {J.parse_go(J.fuel_go(suffix, a), J.Machine{J.MText{SCon{Chr{c}, rev}, key}, suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>}) -> {J.parse_go(J.fuel_go(J.unicode_escape(c, False{}) ++ suffix, a), J.Machine{J.MText{rev, key}, J.unicode_escape(c, False{}) ++ suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>}:
  C.credit(14n, 34n, suffix, a, J.Machine{J.MText{rev, key}, J.unicode_escape(c, False{}) ++ suffix, stack, depth}, J.Machine{J.MText{SCon{Chr{c}, rev}, key}, suffix, stack, depth}, v, S.pair_parse(c, rev, key, suffix, stack, depth, J.fuel_go(suffix, Nat.add(34n, a)), scalar, large), h)

def ordinary_cps(+c: U32, +rev: String, +key: Bool, +suffix: String, +stack: List<&2, J.Frame>, +depth: Nat, +a: Nat, +v: J.Json, +quote: {U32.is_eq(c, 34) == False{} : Bool}, +slash: {U32.is_eq(c, 92) == False{} : Bool}, +printable: {(c >= 32 : U32) == True{} : Bool}, +scalar: {U.scalar(c) == True{} : Bool}, h: {J.parse_go(J.fuel_go(suffix, a), J.Machine{J.MText{SCon{Chr{c}, rev}, key}, suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>}) -> {J.parse_go(J.fuel_go(SCon{Chr{c}, suffix}, a), J.Machine{J.MText{rev, key}, SCon{Chr{c}, suffix}, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>}:
  C.credit(1n, 3n, suffix, a, J.Machine{J.MText{rev, key}, SCon{Chr{c}, suffix}, stack, depth}, J.Machine{J.MText{SCon{Chr{c}, rev}, key}, suffix, stack, depth}, v, E.ordinary_text(c, rev, key, suffix, stack, depth, J.fuel_go(suffix, Nat.add(3n, a)), quote, slash, printable, scalar), h)

def unicode_cps(+c: U32, +rev: String, +key: Bool, +suffix: String, +stack: List<&2, J.Frame>, +depth: Nat, +a: Nat, +v: J.Json, +scalar: {U.scalar(c) == True{} : Bool}, bmp: Bool, +e: {(c <= 65535 : U32) == bmp : Bool}) -> {J.parse_go(J.fuel_go(suffix, a), J.Machine{J.MText{SCon{Chr{c}, rev}, key}, suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>} -> {J.parse_go(J.fuel_go(J.unicode_escape(c, bmp) ++ suffix, a), J.Machine{J.MText{rev, key}, J.unicode_escape(c, bmp) ++ suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>}:
  match bmp:
    case True{}: h => bmp_cps(c, rev, key, suffix, stack, depth, a, v, e, scalar, h)
    case False{}: h => pair_cps(c, rev, key, suffix, stack, depth, a, v, scalar, e, h)

def other_cps(+c: U32, +ascii: Bool, +rev: String, +key: Bool, +suffix: String, +stack: List<&2, J.Frame>, +depth: Nat, +a: Nat, +v: J.Json, +quote: {U32.is_eq(c, 34) == False{} : Bool}, +slash: {U32.is_eq(c, 92) == False{} : Bool}, +scalar: {U.scalar(c) == True{} : Bool}, flag: Bool, +e: {(c < 32 : U32) || (ascii && (c > 127 : U32)) == flag : Bool}) -> {J.parse_go(J.fuel_go(suffix, a), J.Machine{J.MText{SCon{Chr{c}, rev}, key}, suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>} -> {J.parse_go(J.fuel_go(J.escaped_other(c, flag) ++ suffix, a), J.Machine{J.MText{rev, key}, J.escaped_other(c, flag) ++ suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>}:
  match flag:
    case True{}: unicode_cps(c, rev, key, suffix, stack, depth, a, v, scalar, (c <= 65535 : U32), {==})
    case False{}: h => ordinary_cps(c, rev, key, suffix, stack, depth, a, v, quote, slash, printable_of(c, ascii, e), scalar, h)

def class_cps(+c: U32, +ascii: Bool, +rev: String, +key: Bool, +suffix: String, +stack: List<&2, J.Frame>, +depth: Nat, +a: Nat, +v: J.Json, +q: {U32.is_eq(c, 34) == False{} : Bool}, +s: {U32.is_eq(c, 92) == False{} : Bool}, +bs: {U32.is_eq(c, 8) == False{} : Bool}, +ff: {U32.is_eq(c, 12) == False{} : Bool}, +nl: {U32.is_eq(c, 10) == False{} : Bool}, +cr: {U32.is_eq(c, 13) == False{} : Bool}, +tab: {U32.is_eq(c, 9) == False{} : Bool}, +scalar: {U.scalar(c) == True{} : Bool}) -> {J.parse_go(J.fuel_go(suffix, a), J.Machine{J.MText{SCon{Chr{c}, rev}, key}, suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>} -> {J.parse_go(J.fuel_go(J.escape_char(c, ascii) ++ suffix, a), J.Machine{J.MText{rev, key}, J.escape_char(c, ascii) ++ suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>}:
  %Equal.sym(String, J.escape_char(c, ascii), J.escaped_other(c, (c < 32 : U32) || (ascii && (c > 127 : U32))), K.escape_class(c, ascii, q, s, bs, ff, nl, cr, tab)) : {J.parse_go(J.fuel_go(suffix, a), J.Machine{J.MText{SCon{Chr{c}, rev}, key}, suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>} -> {J.parse_go(J.fuel_go(_ ++ suffix, a), J.Machine{J.MText{rev, key}, _ ++ suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>}
  other_cps(c, ascii, rev, key, suffix, stack, depth, a, v, q, s, scalar, (c < 32 : U32) || (ascii && (c > 127 : U32)), {==})

def decide_tab(+c: U32, +ascii: Bool, +rev: String, +key: Bool, +suffix: String, +stack: List<&2, J.Frame>, +depth: Nat, +a: Nat, +v: J.Json, +q: {U32.is_eq(c, 34) == False{} : Bool}, +s: {U32.is_eq(c, 92) == False{} : Bool}, +bs: {U32.is_eq(c, 8) == False{} : Bool}, +ff: {U32.is_eq(c, 12) == False{} : Bool}, +nl: {U32.is_eq(c, 10) == False{} : Bool}, +cr: {U32.is_eq(c, 13) == False{} : Bool}, +scalar: {U.scalar(c) == True{} : Bool}, b: Bool, e: {U32.is_eq(c, 9) == b : Bool}) -> {J.parse_go(J.fuel_go(suffix, a), J.Machine{J.MText{SCon{Chr{c}, rev}, key}, suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>} -> {J.parse_go(J.fuel_go(J.escape_char(c, ascii) ++ suffix, a), J.Machine{J.MText{rev, key}, J.escape_char(c, ascii) ++ suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>}:
  match b:
    case True{}: at_short(c, E.Tab{}, ascii, rev, key, suffix, stack, depth, a, v, C.u32_eq_sound(c, 9, e))
    case False{}: class_cps(c, ascii, rev, key, suffix, stack, depth, a, v, q, s, bs, ff, nl, cr, e, scalar)

def decide_cr(+c: U32, +ascii: Bool, +rev: String, +key: Bool, +suffix: String, +stack: List<&2, J.Frame>, +depth: Nat, +a: Nat, +v: J.Json, +q: {U32.is_eq(c, 34) == False{} : Bool}, +s: {U32.is_eq(c, 92) == False{} : Bool}, +bs: {U32.is_eq(c, 8) == False{} : Bool}, +ff: {U32.is_eq(c, 12) == False{} : Bool}, +nl: {U32.is_eq(c, 10) == False{} : Bool}, +scalar: {U.scalar(c) == True{} : Bool}, b: Bool, e: {U32.is_eq(c, 13) == b : Bool}) -> {J.parse_go(J.fuel_go(suffix, a), J.Machine{J.MText{SCon{Chr{c}, rev}, key}, suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>} -> {J.parse_go(J.fuel_go(J.escape_char(c, ascii) ++ suffix, a), J.Machine{J.MText{rev, key}, J.escape_char(c, ascii) ++ suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>}:
  match b:
    case True{}: at_short(c, E.Return{}, ascii, rev, key, suffix, stack, depth, a, v, C.u32_eq_sound(c, 13, e))
    case False{}: decide_tab(c, ascii, rev, key, suffix, stack, depth, a, v, q, s, bs, ff, nl, e, scalar, U32.is_eq(c, 9), {==})

def decide_nl(+c: U32, +ascii: Bool, +rev: String, +key: Bool, +suffix: String, +stack: List<&2, J.Frame>, +depth: Nat, +a: Nat, +v: J.Json, +q: {U32.is_eq(c, 34) == False{} : Bool}, +s: {U32.is_eq(c, 92) == False{} : Bool}, +bs: {U32.is_eq(c, 8) == False{} : Bool}, +ff: {U32.is_eq(c, 12) == False{} : Bool}, +scalar: {U.scalar(c) == True{} : Bool}, b: Bool, e: {U32.is_eq(c, 10) == b : Bool}) -> {J.parse_go(J.fuel_go(suffix, a), J.Machine{J.MText{SCon{Chr{c}, rev}, key}, suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>} -> {J.parse_go(J.fuel_go(J.escape_char(c, ascii) ++ suffix, a), J.Machine{J.MText{rev, key}, J.escape_char(c, ascii) ++ suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>}:
  match b:
    case True{}: at_short(c, E.Newline{}, ascii, rev, key, suffix, stack, depth, a, v, C.u32_eq_sound(c, 10, e))
    case False{}: decide_cr(c, ascii, rev, key, suffix, stack, depth, a, v, q, s, bs, ff, e, scalar, U32.is_eq(c, 13), {==})

def decide_ff(+c: U32, +ascii: Bool, +rev: String, +key: Bool, +suffix: String, +stack: List<&2, J.Frame>, +depth: Nat, +a: Nat, +v: J.Json, +q: {U32.is_eq(c, 34) == False{} : Bool}, +s: {U32.is_eq(c, 92) == False{} : Bool}, +bs: {U32.is_eq(c, 8) == False{} : Bool}, +scalar: {U.scalar(c) == True{} : Bool}, b: Bool, e: {U32.is_eq(c, 12) == b : Bool}) -> {J.parse_go(J.fuel_go(suffix, a), J.Machine{J.MText{SCon{Chr{c}, rev}, key}, suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>} -> {J.parse_go(J.fuel_go(J.escape_char(c, ascii) ++ suffix, a), J.Machine{J.MText{rev, key}, J.escape_char(c, ascii) ++ suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>}:
  match b:
    case True{}: at_short(c, E.FormFeed{}, ascii, rev, key, suffix, stack, depth, a, v, C.u32_eq_sound(c, 12, e))
    case False{}: decide_nl(c, ascii, rev, key, suffix, stack, depth, a, v, q, s, bs, e, scalar, U32.is_eq(c, 10), {==})

def decide_bs(+c: U32, +ascii: Bool, +rev: String, +key: Bool, +suffix: String, +stack: List<&2, J.Frame>, +depth: Nat, +a: Nat, +v: J.Json, +q: {U32.is_eq(c, 34) == False{} : Bool}, +s: {U32.is_eq(c, 92) == False{} : Bool}, +scalar: {U.scalar(c) == True{} : Bool}, b: Bool, e: {U32.is_eq(c, 8) == b : Bool}) -> {J.parse_go(J.fuel_go(suffix, a), J.Machine{J.MText{SCon{Chr{c}, rev}, key}, suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>} -> {J.parse_go(J.fuel_go(J.escape_char(c, ascii) ++ suffix, a), J.Machine{J.MText{rev, key}, J.escape_char(c, ascii) ++ suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>}:
  match b:
    case True{}: at_short(c, E.Backspace{}, ascii, rev, key, suffix, stack, depth, a, v, C.u32_eq_sound(c, 8, e))
    case False{}: decide_ff(c, ascii, rev, key, suffix, stack, depth, a, v, q, s, e, scalar, U32.is_eq(c, 12), {==})

def decide_s(+c: U32, +ascii: Bool, +rev: String, +key: Bool, +suffix: String, +stack: List<&2, J.Frame>, +depth: Nat, +a: Nat, +v: J.Json, +q: {U32.is_eq(c, 34) == False{} : Bool}, +scalar: {U.scalar(c) == True{} : Bool}, b: Bool, e: {U32.is_eq(c, 92) == b : Bool}) -> {J.parse_go(J.fuel_go(suffix, a), J.Machine{J.MText{SCon{Chr{c}, rev}, key}, suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>} -> {J.parse_go(J.fuel_go(J.escape_char(c, ascii) ++ suffix, a), J.Machine{J.MText{rev, key}, J.escape_char(c, ascii) ++ suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>}:
  match b:
    case True{}: at_short(c, E.Backslash{}, ascii, rev, key, suffix, stack, depth, a, v, C.u32_eq_sound(c, 92, e))
    case False{}: decide_bs(c, ascii, rev, key, suffix, stack, depth, a, v, q, e, scalar, U32.is_eq(c, 8), {==})

def decide_q(+c: U32, +ascii: Bool, +rev: String, +key: Bool, +suffix: String, +stack: List<&2, J.Frame>, +depth: Nat, +a: Nat, +v: J.Json, +scalar: {U.scalar(c) == True{} : Bool}, b: Bool, e: {U32.is_eq(c, 34) == b : Bool}) -> {J.parse_go(J.fuel_go(suffix, a), J.Machine{J.MText{SCon{Chr{c}, rev}, key}, suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>} -> {J.parse_go(J.fuel_go(J.escape_char(c, ascii) ++ suffix, a), J.Machine{J.MText{rev, key}, J.escape_char(c, ascii) ++ suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>}:
  match b:
    case True{}: at_short(c, E.Quote{}, ascii, rev, key, suffix, stack, depth, a, v, C.u32_eq_sound(c, 34, e))
    case False{}: decide_s(c, ascii, rev, key, suffix, stack, depth, a, v, e, scalar, U32.is_eq(c, 92), {==})

def escape_cps(+c: U32, +ascii: Bool, +rev: String, +key: Bool, +suffix: String, +stack: List<&2, J.Frame>, +depth: Nat, +a: Nat, +v: J.Json, +scalar: {U.scalar(c) == True{} : Bool}) -> {J.parse_go(J.fuel_go(suffix, a), J.Machine{J.MText{SCon{Chr{c}, rev}, key}, suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>} -> {J.parse_go(J.fuel_go(J.escape_char(c, ascii) ++ suffix, a), J.Machine{J.MText{rev, key}, J.escape_char(c, ascii) ++ suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>}:
  decide_q(c, ascii, rev, key, suffix, stack, depth, a, v, scalar, U32.is_eq(c, 34), {==})
# The writer's escaped body, in forward order.
def escs(s: String, +ascii: Bool) -> String:
  match s:
    case SNil{}: ""
    case SCon{Chr{c}, t}: J.escape_char(c, ascii) ++ escs(t, ascii)

def quote_spec(+s: String, +ascii: Bool, +rev: String) -> {J.quote_go(s, ascii, rev) == String.reverse.go(rev, escs(s, ascii) ++ "\"") : String}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{c}, t}:
      Equal.trans(String, J.quote_go(t, ascii, String.reverse.go(J.escape_char(c, ascii), rev)), String.reverse.go(String.reverse.go(J.escape_char(c, ascii), rev), escs(t, ascii) ++ "\""), String.reverse.go(rev, (J.escape_char(c, ascii) ++ escs(t, ascii)) ++ "\""), quote_spec(t, ascii, String.reverse.go(J.escape_char(c, ascii), rev)), Equal.trans(String, String.reverse.go(String.reverse.go(J.escape_char(c, ascii), rev), escs(t, ascii) ++ "\""), String.reverse.go(rev, J.escape_char(c, ascii) ++ (escs(t, ascii) ++ "\"")), String.reverse.go(rev, (J.escape_char(c, ascii) ++ escs(t, ascii)) ++ "\""), Sup.reverse_go_twice(J.escape_char(c, ascii), rev, escs(t, ascii) ++ "\""), Equal.cong(String, String, x => String.reverse.go(rev, x), J.escape_char(c, ascii) ++ (escs(t, ascii) ++ "\""), (J.escape_char(c, ascii) ++ escs(t, ascii)) ++ "\"", Equal.sym(String, (J.escape_char(c, ascii) ++ escs(t, ascii)) ++ "\"", J.escape_char(c, ascii) ++ (escs(t, ascii) ++ "\""), Sup.append_assoc(J.escape_char(c, ascii), escs(t, ascii), "\"")))))

def quote_shape(+s: String, +ascii: Bool) -> {J.quote(s, ascii) == SCon{'"', escs(s, ascii) ++ "\""} : String}:
  quote_spec(s, ascii, "\"")

def body_cps(+s: String, +ascii: Bool, +rev: String, +key: Bool, +suffix: String, +stack: List<&2, J.Frame>, +depth: Nat, +a: Nat, +v: J.Json, +valid: {U.valid(s) == True{} : Bool}, h: {J.parse_go(J.fuel_go(suffix, a), J.Machine{J.MText{String.reverse.go(s, rev), key}, suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>}) -> {J.parse_go(J.fuel_go(escs(s, ascii) ++ suffix, a), J.Machine{J.MText{rev, key}, escs(s, ascii) ++ suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>}:
  match s:
    case SNil{}: h
    case SCon{Chr{c}, t}:
      %Equal.sym(String, (J.escape_char(c, ascii) ++ escs(t, ascii)) ++ suffix, J.escape_char(c, ascii) ++ (escs(t, ascii) ++ suffix), Sup.append_assoc(J.escape_char(c, ascii), escs(t, ascii), suffix)) : {J.parse_go(J.fuel_go(_, a), J.Machine{J.MText{rev, key}, _, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>}
      go = escape_cps(c, ascii, rev, key, escs(t, ascii) ++ suffix, stack, depth, a, v, P.and_left(U.scalar(c), U.valid(t), valid))
      go(body_cps(t, ascii, SCon{Chr{c}, rev}, key, suffix, stack, depth, a, v, P.and_right(U.scalar(c), U.valid(t), valid), h))

def text_done(+s: String, +suffix: String, +stack: List<&2, J.Frame>, +depth: Nat, +a: Nat, +v: J.Json, h: {J.parse_go(J.fuel_go(suffix, a), J.Machine{J.MEmit{J.JString{s}}, suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>}) -> {J.parse_go(J.fuel_go(suffix, a), J.Machine{J.MEmit{J.JString{String.reverse(String.reverse.go(s, ""))}}, suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>}:
  %Equal.sym(String, String.reverse(String.reverse.go(s, "")), s, Sup.reverse_go_inverse(s, "")) : {J.parse_go(J.fuel_go(suffix, a), J.Machine{J.MEmit{J.JString{_}}, suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>}
  h

def key_done(+s: String, +suffix: String, +stack: List<&2, J.Frame>, +depth: Nat, +a: Nat, +v: J.Json, h: {J.parse_go(J.fuel_go(suffix, a), J.Machine{J.MColon{s}, suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>}) -> {J.parse_go(J.fuel_go(suffix, a), J.Machine{J.MColon{String.reverse(String.reverse.go(s, ""))}, suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>}:
  %Equal.sym(String, String.reverse(String.reverse.go(s, "")), s, Sup.reverse_go_inverse(s, "")) : {J.parse_go(J.fuel_go(suffix, a), J.Machine{J.MColon{_}, suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>}
  h

# The closing quote follows the body directly.
def quoted_input(+s: String, +ascii: Bool, +suffix: String) -> {J.quote(s, ascii) ++ suffix == SCon{'"', escs(s, ascii) ++ SCon{'"', suffix}} : String}:
  %Equal.sym(String, J.quote(s, ascii), SCon{'"', escs(s, ascii) ++ "\""}, quote_shape(s, ascii)) : {_ ++ suffix == SCon{'"', escs(s, ascii) ++ SCon{'"', suffix}} : String}
  %Equal.sym(String, (escs(s, ascii) ++ "\"") ++ suffix, escs(s, ascii) ++ ("\"" ++ suffix), Sup.append_assoc(escs(s, ascii), "\"", suffix)) : {SCon{'"', _} == SCon{'"', escs(s, ascii) ++ SCon{'"', suffix}} : String}
  {==}

def string_cps(+s: String, +ascii: Bool, +suffix: String, +stack: List<&2, J.Frame>, +depth: Nat, +a: Nat, +v: J.Json, +valid: {U.valid(s) == True{} : Bool}, h: {J.parse_go(J.fuel_go(suffix, a), J.Machine{J.MEmit{J.JString{s}}, suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>}) -> {J.parse_go(J.fuel_go(J.quote(s, ascii) ++ suffix, a), J.Machine{J.MValue{}, J.quote(s, ascii) ++ suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>}:
  %Equal.sym(String, J.quote(s, ascii) ++ suffix, SCon{'"', escs(s, ascii) ++ SCon{'"', suffix}}, quoted_input(s, ascii, suffix)) : {J.parse_go(J.fuel_go(_, a), J.Machine{J.MValue{}, _, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>}
  C.consume('"', escs(s, ascii) ++ SCon{'"', suffix}, a, J.Machine{J.MValue{}, SCon{'"', escs(s, ascii) ++ SCon{'"', suffix}}, stack, depth}, v, body_cps(s, ascii, "", False{}, SCon{'"', suffix}, stack, depth, a, v, valid, C.consume('"', suffix, a, J.Machine{J.MText{String.reverse.go(s, ""), False{}}, SCon{'"', suffix}, stack, depth}, v, text_done(s, suffix, stack, depth, a, v, h), {==})), {==})

def key_cps(+s: String, +ascii: Bool, +k: Bool, +suffix: String, +stack: List<&2, J.Frame>, +depth: Nat, +a: Nat, +v: J.Json, +valid: {U.valid(s) == True{} : Bool}, h: {J.parse_go(J.fuel_go(suffix, a), J.Machine{J.MColon{s}, suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>}) -> {J.parse_go(J.fuel_go(J.quote(s, ascii) ++ suffix, a), J.Machine{J.MReadKey{k}, J.quote(s, ascii) ++ suffix, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>}:
  match k:
    case True{}:
      %Equal.sym(String, J.quote(s, ascii) ++ suffix, SCon{'"', escs(s, ascii) ++ SCon{'"', suffix}}, quoted_input(s, ascii, suffix)) : {J.parse_go(J.fuel_go(_, a), J.Machine{J.MReadKey{True{}}, _, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>}
      C.consume('"', escs(s, ascii) ++ SCon{'"', suffix}, a, J.Machine{J.MReadKey{True{}}, SCon{'"', escs(s, ascii) ++ SCon{'"', suffix}}, stack, depth}, v, body_cps(s, ascii, "", True{}, SCon{'"', suffix}, stack, depth, a, v, valid, C.consume('"', suffix, a, J.Machine{J.MText{String.reverse.go(s, ""), True{}}, SCon{'"', suffix}, stack, depth}, v, key_done(s, suffix, stack, depth, a, v, h), {==})), {==})
    case False{}:
      %Equal.sym(String, J.quote(s, ascii) ++ suffix, SCon{'"', escs(s, ascii) ++ SCon{'"', suffix}}, quoted_input(s, ascii, suffix)) : {J.parse_go(J.fuel_go(_, a), J.Machine{J.MReadKey{False{}}, _, stack, depth}) == Done{v} : Result<&2, &2, J.Error, J.Json>}
      C.consume('"', escs(s, ascii) ++ SCon{'"', suffix}, a, J.Machine{J.MReadKey{False{}}, SCon{'"', escs(s, ascii) ++ SCon{'"', suffix}}, stack, depth}, v, body_cps(s, ascii, "", True{}, SCon{'"', suffix}, stack, depth, a, v, valid, C.consume('"', suffix, a, J.Machine{J.MText{String.reverse.go(s, ""), True{}}, SCon{'"', suffix}, stack, depth}, v, key_done(s, suffix, stack, depth, a, v, h), {==})), {==})
