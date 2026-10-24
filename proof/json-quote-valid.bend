# Every escape the writer chooses spells valid Unicode scalars, so quoted
# text stays valid whatever the input string held.
import Base
import ../src/data/json.bend as J
import ../src/data/utf8.bend as U
import ./utf8.bend as P
import ./json-escape.bend as E
import ./json-surrogate.bend as S
import ./json-credit.bend as C
import ./json-classes.bend as K
import ./json-valid.bend as V
import ./json-quote.bend as Q

def short_valid(kind: E.Short, +ascii: Bool, +tail: String, +ok: {U.valid_spec(tail) == True{} : Bool}) -> {U.valid_spec(J.escape_char(E.short_code(kind), ascii) ++ tail) == True{} : Bool}:
  match kind:
    case E.Quote{}: V.valid_cat(J.escape_char(34, ascii), tail, {==}, ok)
    case E.Backslash{}: V.valid_cat(J.escape_char(92, ascii), tail, {==}, ok)
    case E.Backspace{}: V.valid_cat(J.escape_char(8, ascii), tail, {==}, ok)
    case E.FormFeed{}: V.valid_cat(J.escape_char(12, ascii), tail, {==}, ok)
    case E.Newline{}: V.valid_cat(J.escape_char(10, ascii), tail, {==}, ok)
    case E.Return{}: V.valid_cat(J.escape_char(13, ascii), tail, {==}, ok)
    case E.Tab{}: V.valid_cat(J.escape_char(9, ascii), tail, {==}, ok)

def at_short(+c: U32, +kind: E.Short, +ascii: Bool, +tail: String, +ok: {U.valid_spec(tail) == True{} : Bool}, e: {c == E.short_code(kind) : U32}) -> {U.valid_spec(J.escape_char(c, ascii) ++ tail) == True{} : Bool}:
  %Equal.sym(U32, c, E.short_code(kind), e) : {U.valid_spec(J.escape_char(_, ascii) ++ tail) == True{} : Bool}
  short_valid(kind, ascii, tail, ok)

def hex4_valid_u32(+c: U32, bounded: {(c <= 65535 : U32) == True{} : Bool}) -> {U.valid_spec(J.hex4(c)) == True{} : Bool}:
  match c:
    case U32{w}:
      %E.bmp_reconstruct(w, bounded) : {U.valid_spec(J.hex4(_)) == True{} : Bool}
      E.hex4_valid(U.low(16n, 16n, w))

def unicode_valid(+c: U32, +tail: String, +ok: {U.valid_spec(tail) == True{} : Bool}, +scalar: {U.scalar(c) == True{} : Bool}, bmp: Bool, +e: {(c <= 65535 : U32) == bmp : Bool}) -> {U.valid_spec(J.unicode_escape(c, bmp) ++ tail) == True{} : Bool}:
  match bmp:
    case True{}: V.valid_cat(J.hex4(c), tail, hex4_valid_u32(c, e), ok)
    case False{}: S.pair_valid(c, tail, ok, scalar, e)

def other_valid(+c: U32, +ascii: Bool, +tail: String, +ok: {U.valid_spec(tail) == True{} : Bool}, +scalar: {U.scalar(c) == True{} : Bool}, flag: Bool, +e: {(c < 32 : U32) || (ascii && (c > 127 : U32)) == flag : Bool}) -> {U.valid_spec(J.escaped_other(c, flag) ++ tail) == True{} : Bool}:
  match flag:
    case True{}: unicode_valid(c, tail, ok, scalar, (c <= 65535 : U32), {==})
    case False{}: V.valid_cat(SCon{Chr{c}, ""}, tail, E.valid_cons(Chr{c}, "", scalar, {==}), ok)

def class_valid(+c: U32, +ascii: Bool, +tail: String, +ok: {U.valid_spec(tail) == True{} : Bool}, +q: {U32.is_eq(c, 34) == False{} : Bool}, +s: {U32.is_eq(c, 92) == False{} : Bool}, +bs: {U32.is_eq(c, 8) == False{} : Bool}, +ff: {U32.is_eq(c, 12) == False{} : Bool}, +nl: {U32.is_eq(c, 10) == False{} : Bool}, +cr: {U32.is_eq(c, 13) == False{} : Bool}, +tab: {U32.is_eq(c, 9) == False{} : Bool}, +scalar: {U.scalar(c) == True{} : Bool}) -> {U.valid_spec(J.escape_char(c, ascii) ++ tail) == True{} : Bool}:
  %Equal.sym(String, J.escape_char(c, ascii), J.escaped_other(c, (c < 32 : U32) || (ascii && (c > 127 : U32))), K.escape_class(c, ascii, q, s, bs, ff, nl, cr, tab)) : {U.valid_spec(_ ++ tail) == True{} : Bool}
  other_valid(c, ascii, tail, ok, scalar, (c < 32 : U32) || (ascii && (c > 127 : U32)), {==})

def decide_tab(+c: U32, +ascii: Bool, +tail: String, +ok: {U.valid_spec(tail) == True{} : Bool}, +q: {U32.is_eq(c, 34) == False{} : Bool}, +s: {U32.is_eq(c, 92) == False{} : Bool}, +bs: {U32.is_eq(c, 8) == False{} : Bool}, +ff: {U32.is_eq(c, 12) == False{} : Bool}, +nl: {U32.is_eq(c, 10) == False{} : Bool}, +cr: {U32.is_eq(c, 13) == False{} : Bool}, +scalar: {U.scalar(c) == True{} : Bool}, b: Bool, e: {U32.is_eq(c, 9) == b : Bool}) -> {U.valid_spec(J.escape_char(c, ascii) ++ tail) == True{} : Bool}:
  match b:
    case True{}: at_short(c, E.Tab{}, ascii, tail, ok, C.u32_eq_sound(c, 9, e))
    case False{}: class_valid(c, ascii, tail, ok, q, s, bs, ff, nl, cr, e, scalar)

def decide_cr(+c: U32, +ascii: Bool, +tail: String, +ok: {U.valid_spec(tail) == True{} : Bool}, +q: {U32.is_eq(c, 34) == False{} : Bool}, +s: {U32.is_eq(c, 92) == False{} : Bool}, +bs: {U32.is_eq(c, 8) == False{} : Bool}, +ff: {U32.is_eq(c, 12) == False{} : Bool}, +nl: {U32.is_eq(c, 10) == False{} : Bool}, +scalar: {U.scalar(c) == True{} : Bool}, b: Bool, e: {U32.is_eq(c, 13) == b : Bool}) -> {U.valid_spec(J.escape_char(c, ascii) ++ tail) == True{} : Bool}:
  match b:
    case True{}: at_short(c, E.Return{}, ascii, tail, ok, C.u32_eq_sound(c, 13, e))
    case False{}: decide_tab(c, ascii, tail, ok, q, s, bs, ff, nl, e, scalar, U32.is_eq(c, 9), {==})

def decide_nl(+c: U32, +ascii: Bool, +tail: String, +ok: {U.valid_spec(tail) == True{} : Bool}, +q: {U32.is_eq(c, 34) == False{} : Bool}, +s: {U32.is_eq(c, 92) == False{} : Bool}, +bs: {U32.is_eq(c, 8) == False{} : Bool}, +ff: {U32.is_eq(c, 12) == False{} : Bool}, +scalar: {U.scalar(c) == True{} : Bool}, b: Bool, e: {U32.is_eq(c, 10) == b : Bool}) -> {U.valid_spec(J.escape_char(c, ascii) ++ tail) == True{} : Bool}:
  match b:
    case True{}: at_short(c, E.Newline{}, ascii, tail, ok, C.u32_eq_sound(c, 10, e))
    case False{}: decide_cr(c, ascii, tail, ok, q, s, bs, ff, e, scalar, U32.is_eq(c, 13), {==})

def decide_ff(+c: U32, +ascii: Bool, +tail: String, +ok: {U.valid_spec(tail) == True{} : Bool}, +q: {U32.is_eq(c, 34) == False{} : Bool}, +s: {U32.is_eq(c, 92) == False{} : Bool}, +bs: {U32.is_eq(c, 8) == False{} : Bool}, +scalar: {U.scalar(c) == True{} : Bool}, b: Bool, e: {U32.is_eq(c, 12) == b : Bool}) -> {U.valid_spec(J.escape_char(c, ascii) ++ tail) == True{} : Bool}:
  match b:
    case True{}: at_short(c, E.FormFeed{}, ascii, tail, ok, C.u32_eq_sound(c, 12, e))
    case False{}: decide_nl(c, ascii, tail, ok, q, s, bs, e, scalar, U32.is_eq(c, 10), {==})

def decide_bs(+c: U32, +ascii: Bool, +tail: String, +ok: {U.valid_spec(tail) == True{} : Bool}, +q: {U32.is_eq(c, 34) == False{} : Bool}, +s: {U32.is_eq(c, 92) == False{} : Bool}, +scalar: {U.scalar(c) == True{} : Bool}, b: Bool, e: {U32.is_eq(c, 8) == b : Bool}) -> {U.valid_spec(J.escape_char(c, ascii) ++ tail) == True{} : Bool}:
  match b:
    case True{}: at_short(c, E.Backspace{}, ascii, tail, ok, C.u32_eq_sound(c, 8, e))
    case False{}: decide_ff(c, ascii, tail, ok, q, s, e, scalar, U32.is_eq(c, 12), {==})

def decide_s(+c: U32, +ascii: Bool, +tail: String, +ok: {U.valid_spec(tail) == True{} : Bool}, +q: {U32.is_eq(c, 34) == False{} : Bool}, +scalar: {U.scalar(c) == True{} : Bool}, b: Bool, e: {U32.is_eq(c, 92) == b : Bool}) -> {U.valid_spec(J.escape_char(c, ascii) ++ tail) == True{} : Bool}:
  match b:
    case True{}: at_short(c, E.Backslash{}, ascii, tail, ok, C.u32_eq_sound(c, 92, e))
    case False{}: decide_bs(c, ascii, tail, ok, q, e, scalar, U32.is_eq(c, 8), {==})

def decide_q(+c: U32, +ascii: Bool, +tail: String, +ok: {U.valid_spec(tail) == True{} : Bool}, +scalar: {U.scalar(c) == True{} : Bool}, b: Bool, e: {U32.is_eq(c, 34) == b : Bool}) -> {U.valid_spec(J.escape_char(c, ascii) ++ tail) == True{} : Bool}:
  match b:
    case True{}: at_short(c, E.Quote{}, ascii, tail, ok, C.u32_eq_sound(c, 34, e))
    case False{}: decide_s(c, ascii, tail, ok, e, scalar, U32.is_eq(c, 92), {==})

def escape_valid(+c: U32, +ascii: Bool, +tail: String, +ok: {U.valid_spec(tail) == True{} : Bool}, +scalar: {U.scalar(c) == True{} : Bool}) -> {U.valid_spec(J.escape_char(c, ascii) ++ tail) == True{} : Bool}:
  decide_q(c, ascii, tail, ok, scalar, U32.is_eq(c, 34), {==})

def escs_valid(+s: String, +ascii: Bool, +valid: {U.valid_spec(s) == True{} : Bool}) -> {U.valid_spec(Q.escs(s, ascii)) == True{} : Bool}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{c}, t}: escape_valid(c, ascii, Q.escs(t, ascii), escs_valid(t, ascii, P.and_right(U.scalar(c), U.valid_spec(t), valid)), P.and_left(U.scalar(c), U.valid_spec(t), valid))

def quote_valid(+s: String, +ascii: Bool, +valid: {U.valid_spec(s) == True{} : Bool}) -> {U.valid_spec(J.quote(s, ascii)) == True{} : Bool}:
  %Equal.sym(String, J.quote(s, ascii), SCon{'"', Q.escs(s, ascii) ++ "\""}, Q.quote_shape(s, ascii)) : {U.valid_spec(_) == True{} : Bool}
  E.valid_cons('"', Q.escs(s, ascii) ++ "\"", {==}, V.valid_cat(Q.escs(s, ascii), "\"", escs_valid(s, ascii, valid), {==}))
