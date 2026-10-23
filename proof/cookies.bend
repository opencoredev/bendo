# BND-31: cookie roundtrip lemmas over independently validated characters.
import Base
import ../LAWS.bend as Laws
import ../src/data/cookie.bend as C
import ../src/http/bytes.bend as B
import ./equality.bend as E
import ./crypto-support.bend as S
import ./cookie-spec.bend as Spec
import ./cookie-serialization-spec.bend as Independent
import ./cookie-serialization.bend as SerializationProof

def head_valid(+name: String, +value: String, +tail: Bool, ok: {Independent.name_valid(name) && Independent.value_valid(value) && tail == True{} : Bool}) -> {C.name_valid(name) && C.value_valid(value) && tail == True{} : Bool}:
  %Equal.sym(Bool, C.name_valid(name), Independent.name_valid(name), SerializationProof.name_equiv(name)) : {_ && C.value_valid(value) && tail == True{} : Bool}
  %Equal.sym(Bool, C.value_valid(value), Independent.value_valid(value), SerializationProof.value_equiv(value)) : {Independent.name_valid(name) && _ && tail == True{} : Bool}
  ok

def and_true(a: Bool, b: Bool, x: {a == True{} : Bool}, y: {b == True{} : Bool}) -> {a && b == True{} : Bool}:
  %Equal.sym(Bool, a, True{}, x) : {_ && b == True{} : Bool}
  y

def token_not_case(+c: U32, +k: U32, ok: {B.tchar(c) == True{} : Bool}, bad: {B.tchar(k) == False{} : Bool}, same: Bool, eq: {U32.is_eq(c, k) == same : Bool}) -> {same == False{} : Bool}:
  match same:
    case False{}: {==}
    case True{}:
      clash = Equal.trans(Bool, False{}, B.tchar(k), True{}, Equal.sym(Bool, B.tchar(k), False{}, bad), Equal.trans(Bool, B.tchar(k), B.tchar(c), True{}, Equal.cong(U32, Bool, x => B.tchar(x), k, c, Equal.sym(U32, c, k, Laws.u32_eq_sound(c, k, eq))), ok))
      E.absurd({True{} == False{} : Bool}, E.false_true(clash))

def token_not(+c: U32, +k: U32, ok: {B.tchar(c) == True{} : Bool}, bad: {B.tchar(k) == False{} : Bool}) -> {U32.is_eq(c, k) == False{} : Bool}:
  token_not_case(c, k, ok, bad, U32.is_eq(c, k), {==})

def octet_not_case(+c: U32, +k: U32, ok: {C.octet(c) == True{} : Bool}, bad: {C.octet(k) == False{} : Bool}, same: Bool, eq: {U32.is_eq(c, k) == same : Bool}) -> {same == False{} : Bool}:
  match same:
    case False{}: {==}
    case True{}:
      clash = Equal.trans(Bool, False{}, C.octet(k), True{}, Equal.sym(Bool, C.octet(k), False{}, bad), Equal.trans(Bool, C.octet(k), C.octet(c), True{}, Equal.cong(U32, Bool, x => C.octet(x), k, c, Equal.sym(U32, c, k, Laws.u32_eq_sound(c, k, eq))), ok))
      E.absurd({True{} == False{} : Bool}, E.false_true(clash))

def octet_not(+c: U32, +k: U32, ok: {C.octet(c) == True{} : Bool}, bad: {C.octet(k) == False{} : Bool}) -> {U32.is_eq(c, k) == False{} : Bool}:
  octet_not_case(c, k, ok, bad, U32.is_eq(c, k), {==})

# This auxiliary predicate only excludes syntax characters. The public law
# assumes the runtime token/octet predicates, never parser success.
def clean_char(+c: U32) -> Bool:
  Bool.not(U32.is_eq(c, 9)) && Bool.not(U32.is_eq(c, 32)) && Bool.not(U32.is_eq(c, 34)) && Bool.not(U32.is_eq(c, 59))

def clean(s: String) -> Bool:
  match s:
    case SNil{}: True{}
    case SCon{Chr{c}, t}: clean_char(c) && clean(t)

def token_clean(+c: U32, +ok: {B.tchar(c) == True{} : Bool}) -> {clean_char(c) == True{} : Bool}:
  %Equal.sym(Bool, U32.is_eq(c, 9), False{}, token_not(c, 9, ok, {==})) : {Bool.not(_) && Bool.not(U32.is_eq(c, 32)) && Bool.not(U32.is_eq(c, 34)) && Bool.not(U32.is_eq(c, 59)) == True{} : Bool}
  %Equal.sym(Bool, U32.is_eq(c, 32), False{}, token_not(c, 32, ok, {==})) : {Bool.not(False{}) && Bool.not(_) && Bool.not(U32.is_eq(c, 34)) && Bool.not(U32.is_eq(c, 59)) == True{} : Bool}
  %Equal.sym(Bool, U32.is_eq(c, 34), False{}, token_not(c, 34, ok, {==})) : {Bool.not(False{}) && Bool.not(False{}) && Bool.not(_) && Bool.not(U32.is_eq(c, 59)) == True{} : Bool}
  %Equal.sym(Bool, U32.is_eq(c, 59), False{}, token_not(c, 59, ok, {==})) : {Bool.not(False{}) && Bool.not(False{}) && Bool.not(False{}) && Bool.not(_) == True{} : Bool}
  {==}

def octet_clean(+c: U32, +ok: {C.octet(c) == True{} : Bool}) -> {clean_char(c) == True{} : Bool}:
  %Equal.sym(Bool, U32.is_eq(c, 9), False{}, octet_not(c, 9, ok, {==})) : {Bool.not(_) && Bool.not(U32.is_eq(c, 32)) && Bool.not(U32.is_eq(c, 34)) && Bool.not(U32.is_eq(c, 59)) == True{} : Bool}
  %Equal.sym(Bool, U32.is_eq(c, 32), False{}, octet_not(c, 32, ok, {==})) : {Bool.not(False{}) && Bool.not(_) && Bool.not(U32.is_eq(c, 34)) && Bool.not(U32.is_eq(c, 59)) == True{} : Bool}
  %Equal.sym(Bool, U32.is_eq(c, 34), False{}, octet_not(c, 34, ok, {==})) : {Bool.not(False{}) && Bool.not(False{}) && Bool.not(_) && Bool.not(U32.is_eq(c, 59)) == True{} : Bool}
  %Equal.sym(Bool, U32.is_eq(c, 59), False{}, octet_not(c, 59, ok, {==})) : {Bool.not(False{}) && Bool.not(False{}) && Bool.not(False{}) && Bool.not(_) == True{} : Bool}
  {==}

def token_clean_string(+s: String, +ok: {B.token_tail(s) == True{} : Bool}) -> {clean(s) == True{} : Bool}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{+c}, +t}:
      and_true(clean_char(c), clean(t), token_clean(c, Laws.and_left(B.tchar(c), B.token_tail(t), ok)), token_clean_string(t, Laws.and_right(B.tchar(c), B.token_tail(t), ok)))

def value_clean_string(+s: String, +ok: {C.value_valid(s) == True{} : Bool}) -> {clean(s) == True{} : Bool}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{+c}, +t}:
      and_true(clean_char(c), clean(t), octet_clean(c, Laws.and_left(C.octet(c), C.value_valid(t), ok)), value_clean_string(t, Laws.and_right(C.octet(c), C.value_valid(t), ok)))

def clean_append(+a: String, +b: String, +oka: {clean(a) == True{} : Bool}, +okb: {clean(b) == True{} : Bool}) -> {clean(a ++ b) == True{} : Bool}:
  match a:
    case SNil{}: okb
    case SCon{Chr{+c}, +t}:
      and_true(clean_char(c), clean(t ++ b), Laws.and_left(clean_char(c), clean(t), oka), clean_append(t, b, Laws.and_right(clean_char(c), clean(t), oka), okb))

# Case analysis mirrors the runtime's literal patterns. Each wildcard suffix
# covers every remaining U32 bit, including non-ASCII characters.
def clean_head(+c: U32, +t: String, ok: {clean_char(c) == True{} : Bool}) -> {C.trim_start(SCon{Chr{c}, t}) == SCon{Chr{c}, t} : String} & {C.unquote(SCon{Chr{c}, t}) == Some{SCon{Chr{c}, t}} : Maybe<&2, String>}:
  match c:
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, rest}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      E.absurd({C.trim_start(SCon{Chr{32}, t}) == SCon{Chr{32}, t} : String} & {C.unquote(SCon{Chr{32}, t}) == Some{SCon{Chr{32}, t}} : Maybe<&2, String>}, E.false_true(ok))
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, rest}}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, rest}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      E.absurd({C.trim_start(SCon{Chr{34}, t}) == SCon{Chr{34}, t} : String} & {C.unquote(SCon{Chr{34}, t}) == Some{SCon{Chr{34}, t}} : Maybe<&2, String>}, E.false_true(ok))
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, rest}}}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, rest}}}}}:
      ({==}, {==})
    case U32{WCon{False{}, WCon{True{}, WCon{True{}, rest}}}}:
      ({==}, {==})
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, rest}}}}}:
      ({==}, {==})
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      E.absurd({C.trim_start(SCon{Chr{9}, t}) == SCon{Chr{9}, t} : String} & {C.unquote(SCon{Chr{9}, t}) == Some{SCon{Chr{9}, t}} : Maybe<&2, String>}, E.false_true(ok))
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}}:
      ({==}, {==})
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, rest}}}}}}}}:
      ({==}, {==})
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, rest}}}}}}}:
      ({==}, {==})
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, rest}}}}}}:
      ({==}, {==})
    case U32{WCon{True{}, WCon{False{}, WCon{True{}, rest}}}}:
      ({==}, {==})
    case U32{WCon{True{}, WCon{True{}, rest}}}:
      ({==}, {==})

def head_trim(c: U32, t: String, facts: {C.trim_start(SCon{Chr{c}, t}) == SCon{Chr{c}, t} : String} & {C.unquote(SCon{Chr{c}, t}) == Some{SCon{Chr{c}, t}} : Maybe<&2, String>}) -> {C.trim_start(SCon{Chr{c}, t}) == SCon{Chr{c}, t} : String}:
  (trimmed, unquoted) = facts
  trimmed

def head_unquote(c: U32, t: String, facts: {C.trim_start(SCon{Chr{c}, t}) == SCon{Chr{c}, t} : String} & {C.unquote(SCon{Chr{c}, t}) == Some{SCon{Chr{c}, t}} : Maybe<&2, String>}) -> {C.unquote(SCon{Chr{c}, t}) == Some{SCon{Chr{c}, t}} : Maybe<&2, String>}:
  (trimmed, unquoted) = facts
  unquoted

def trim_start_identity(+s: String, +ok: {clean(s) == True{} : Bool}) -> {C.trim_start(s) == s : String}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{c}, t}:
      head_trim(c, t, clean_head(c, t, Laws.and_left(clean_char(c), clean(t), ok)))

def unquote_identity(+s: String, +ok: {clean(s) == True{} : Bool}) -> {C.unquote(s) == Some{s} : Maybe<&2, String>}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{c}, t}:
      head_unquote(c, t, clean_head(c, t, Laws.and_left(clean_char(c), clean(t), ok)))

def clean_reverse(+s: String, +acc: String, +oks: {clean(s) == True{} : Bool}, +oka: {clean(acc) == True{} : Bool}) -> {clean(String.reverse.go(s, acc)) == True{} : Bool}:
  match s:
    case SNil{}: oka
    case SCon{Chr{+c}, +t}:
      clean_reverse(t, SCon{Chr{c}, acc}, Laws.and_right(clean_char(c), clean(t), oks), and_true(clean_char(c), clean(acc), Laws.and_left(clean_char(c), clean(t), oks), oka))

def trim_identity(+s: String, +ok: {clean(s) == True{} : Bool}) -> {C.trim(s) == s : String}:
  %Equal.sym(String, C.trim_start(s), s, trim_start_identity(s, ok)) : {String.reverse(C.trim_start(String.reverse(_))) == s : String}
  %Equal.sym(String, C.trim_start(String.reverse(s)), String.reverse(s), trim_start_identity(String.reverse(s), clean_reverse(s, "", ok, {==}))) : {String.reverse(_) == s : String}
  %Equal.sym(String, String.reverse(String.reverse(s)), s ++ "", S.reverse_twice(s, "", "")) : {_ == s : String}
  S.string_nil(s)

def not_false(b: Bool, ok: {Bool.not(b) == True{} : Bool}) -> {b == False{} : Bool}:
  match b:
    case False{}: {==}
    case True{}: E.absurd({True{} == False{} : Bool}, E.false_true(ok))

def clean_semicolon(+c: U32, ok: {clean_char(c) == True{} : Bool}) -> {U32.is_eq(c, 59) == False{} : Bool}:
  not_false(U32.is_eq(c, 59), Laws.and_right(Bool.not(U32.is_eq(c, 9)) && Bool.not(U32.is_eq(c, 32)) && Bool.not(U32.is_eq(c, 34)), Bool.not(U32.is_eq(c, 59)), ok))

def split_single(+s: String, +ok: {clean(s) == True{} : Bool}) -> {String.split(s, ';') == [s] : List<&2, String>}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{+c}, +t}:
      %Equal.sym(Bool, U32.is_eq(c, 59), False{}, clean_semicolon(c, Laws.and_left(clean_char(c), clean(t), ok))) : {String.split.fin(Chr{c}, String.split(t, ';'), _) == [SCon{Chr{c}, t}] : List<&2, String>}
      %Equal.sym(List<&2, String>, String.split(t, ';'), [t], split_single(t, Laws.and_right(clean_char(c), clean(t), ok))) : {String.split.push(Chr{c}, _) == [SCon{Chr{c}, t}] : List<&2, String>}
      {==}

def name_tail(+name: String, ok: {C.name_valid(name) == True{} : Bool}) -> {B.token_tail(name) == True{} : Bool}:
  match name:
    case SNil{}: {==}
    case SCon{Chr{c}, t}: ok

def split_stopped(+s: String, +rev: String) -> {C.split_go(s, True{}, '=', rev) == (String.reverse(rev), Some{s}) : String & Maybe<&2, String>}:
  match s:
    case SNil{}: {==}
    case SCon{h, t}: {==}

def split_name_acc(+name: String, +value: String, +rev: String, +ok: {B.token_tail(name) == True{} : Bool}) -> {C.split_go(name ++ "=" ++ value, False{}, '=', rev) == (String.reverse.go(rev, name), Some{value}) : String & Maybe<&2, String>}:
  match name:
    case SNil{}:
      split_stopped(value, rev)
    case SCon{Chr{+c}, +t}:
      %Equal.sym(Bool, U32.is_eq(c, 61), False{}, token_not(c, 61, Laws.and_left(B.tchar(c), B.token_tail(t), ok), {==})) : {C.split_go(t ++ "=" ++ value, _, '=', C.split_prefix(Chr{c}, rev, _)) == (String.reverse.go(rev, SCon{Chr{c}, t}), Some{value}) : String & Maybe<&2, String>}
      split_name_acc(t, value, SCon{Chr{c}, rev}, Laws.and_right(B.tchar(c), B.token_tail(t), ok))

def split_name(+name: String, +value: String, +ok: {B.token_tail(name) == True{} : Bool}) -> {C.split(name ++ "=" ++ value, '=') == (name, Some{value}) : String & Maybe<&2, String>}:
  split_name_acc(name, value, "", ok)

def and_assoc(+a: Bool, +b: Bool, +c: Bool) -> {(a && b) && c == a && (b && c) : Bool}:
  match a:
    case True{}: {==}
    case False{}: {==}

def valid_acc(+s: String, +acc: Bool) -> {C.value_valid_go(s, acc) == acc && C.value_valid(s) : Bool}:
  match s:
    case SNil{}:
      match acc:
        case True{}: {==}
        case False{}: {==}
    case SCon{Chr{+c}, +t}:
      %Equal.sym(Bool, C.value_valid_go(t, acc && C.octet(c)), (acc && C.octet(c)) && C.value_valid(t), valid_acc(t, acc && C.octet(c))) : {_ == acc && (C.octet(c) && C.value_valid(t)) : Bool}
      and_assoc(acc, C.octet(c), C.value_valid(t))

def valid_fast(+s: String) -> {C.value_valid_fast(s) == C.value_valid(s) : Bool}:
  valid_acc(s, True{})

def name_acc(+s: String, +acc: Bool) -> {C.name_valid_go(s, acc) == acc && B.token_tail(s) : Bool}:
  match s:
    case SNil{}:
      match acc:
        case True{}: {==}
        case False{}: {==}
    case SCon{Chr{+c}, +t}:
      %Equal.sym(Bool, C.name_valid_go(t, acc && B.tchar(c)), (acc && B.tchar(c)) && B.token_tail(t), name_acc(t, acc && B.tchar(c))) : {_ == acc && (B.tchar(c) && B.token_tail(t)) : Bool}
      and_assoc(acc, B.tchar(c), B.token_tail(t))

def name_fast(+s: String) -> {C.name_valid_fast(s) == C.name_valid(s) : Bool}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{+c}, +t}: name_acc(t, B.tchar(c))

def pair_clean(+name: String, +value: String, +nv: {C.name_valid(name) == True{} : Bool}, +vv: {C.value_valid(value) == True{} : Bool}) -> {clean(C.serialize_pair(name, value)) == True{} : Bool}:
  clean_append(name, "=" ++ value, token_clean_string(name, name_tail(name, nv)), clean_append("=", value, {==}, value_clean_string(value, vv)))

def parse_pair(+name: String, +value: String, +nv: {C.name_valid(name) == True{} : Bool}, +vv: {C.value_valid(value) == True{} : Bool}) -> {C.parse_pair(C.serialize_pair(name, value)) == Some{C.Entry{name, value}} : Maybe<&2, C.Entry>}:
  %Equal.sym(String, C.trim(C.serialize_pair(name, value)), C.serialize_pair(name, value), trim_identity(C.serialize_pair(name, value), pair_clean(name, value, nv, vv))) : {C.pair_parts(C.split(_, '=')) == Some{C.Entry{name, value}} : Maybe<&2, C.Entry>}
  %Equal.sym(String & Maybe<&2, String>, C.split(C.serialize_pair(name, value), '='), (name, Some{value}), split_name(name, value, name_tail(name, nv))) : {C.pair_parts(_) == Some{C.Entry{name, value}} : Maybe<&2, C.Entry>}
  %Equal.sym(Maybe<&2, String>, C.unquote(value), Some{value}, unquote_identity(value, value_clean_string(value, vv))) : {C.pair_value(name, _) == Some{C.Entry{name, value}} : Maybe<&2, C.Entry>}
  %Equal.sym(Bool, C.name_valid_fast(name), C.name_valid(name), name_fast(name)) : {C.accepted(name, value, _ && C.value_valid_fast(value)) == Some{C.Entry{name, value}} : Maybe<&2, C.Entry>}
  %Equal.sym(Bool, C.value_valid_fast(value), C.value_valid(value), valid_fast(value)) : {C.accepted(name, value, C.name_valid(name) && _) == Some{C.Entry{name, value}} : Maybe<&2, C.Entry>}
  %Equal.sym(Bool, C.name_valid(name), True{}, nv) : {C.accepted(name, value, _ && C.value_valid(value)) == Some{C.Entry{name, value}} : Maybe<&2, C.Entry>}
  %Equal.sym(Bool, C.value_valid(value), True{}, vv) : {C.accepted(name, value, _) == Some{C.Entry{name, value}} : Maybe<&2, C.Entry>}
  {==}

# Reference folds retain the simple recursive equations used by the laws.
def segments_onto(s: String, acc: List<&2, String>) -> List<&2, String>:
  match s:
    case SNil{}: acc
    case SCon{+h, t}: String.split.fin(h, segments_onto(t, acc), Char.is_eq(h, ';'))

def segments_reverse(+s: String, +rev: String, +acc: List<&2, String>) -> {C.segments_go(String.reverse.go(s, rev), acc) == C.segments_go(rev, segments_onto(s, acc)) : List<&2, String>}:
  match s:
    case SNil{}: {==}
    case SCon{+h, +t}: segments_reverse(t, SCon{h, rev}, acc)

def segments_base(+s: String) -> {segments_onto(s, [""]) == String.split(s, ';') : List<&2, String>}:
  match s:
    case SNil{}: {==}
    case SCon{+h, +t}:
      Equal.cong(List<&2, String>, List<&2, String>, xs => String.split.fin(h, xs, Char.is_eq(h, ';')), segments_onto(t, [""]), String.split(t, ';'), segments_base(t))

def segments_equal(+s: String) -> {C.segments(s) == String.split(s, ';') : List<&2, String>}:
  Equal.trans(List<&2, String>, C.segments(s), segments_onto(s, [""]), String.split(s, ';'), segments_reverse(s, "", [""]), segments_base(s))

def parts_onto(parts: List<&2, String>, acc: List<&2, C.Entry>) -> List<&2, C.Entry>:
  match parts:
    case Nil{}: acc
    case s <> t: C.keep(C.parse_pair(s), parts_onto(t, acc))

def parts_reverse(+parts: List<&2, String>, +rev: List<&2, String>, +acc: List<&2, C.Entry>) -> {C.parse_parts_go(List.reverse.go(&2, String, parts, rev), acc) == C.parse_parts_go(rev, parts_onto(parts, acc)) : List<&2, C.Entry>}:
  match parts:
    case Nil{}: {==}
    case +h <> +t: parts_reverse(t, h <> rev, acc)

def parts_reference(parts: List<&2, String>) -> List<&2, C.Entry>:
  parts_onto(parts, [])

def parse_reference(+s: String) -> {C.parse(s) == parts_reference(String.split(s, ';')) : List<&2, C.Entry>}:
  %Equal.sym(List<&2, String>, C.segments(s), String.split(s, ';'), segments_equal(s)) : {C.parse_parts(_) == parts_reference(String.split(s, ';')) : List<&2, C.Entry>}
  parts_reverse(String.split(s, ';'), [], [])

def roundtrip(+name: String, +value: String, +nv: {C.name_valid(name) == True{} : Bool}, +vv: {C.value_valid(value) == True{} : Bool}) -> {C.parse(C.serialize_pair(name, value)) == [C.Entry{name, value}] : List<&2, C.Entry>}:
  %Equal.sym(List<&2, C.Entry>, C.parse(C.serialize_pair(name, value)), parts_reference(String.split(C.serialize_pair(name, value), ';')), parse_reference(C.serialize_pair(name, value))) : {_ == [C.Entry{name, value}] : List<&2, C.Entry>}
  %Equal.sym(List<&2, String>, String.split(C.serialize_pair(name, value), ';'), [C.serialize_pair(name, value)], split_single(C.serialize_pair(name, value), pair_clean(name, value, nv, vv))) : {parts_reference(_) == [C.Entry{name, value}] : List<&2, C.Entry>}
  %Equal.sym(Maybe<&2, C.Entry>, C.parse_pair(C.serialize_pair(name, value)), Some{C.Entry{name, value}}, parse_pair(name, value, nv, vv)) : {C.keep(_, []) == [C.Entry{name, value}] : List<&2, C.Entry>}
  {==}

def defaults_checked(+name: String, +value: String, +nv: {C.name_valid(name) == True{} : Bool}, +vv: {C.value_valid(value) == True{} : Bool}) -> {C.serialize(name, value, C.defaults()) == Done{C.serialize_pair(name, value)} : Result<&2, &2, C.Error, String>}:
  %Equal.sym(Bool, C.name_valid(name), True{}, nv) : {C.serialize_checked(name, value, C.defaults(), C.require(_, C.InvalidName{}, C.require(C.value_valid(value), C.InvalidValue{}, Done{Unit{}}))) == Done{C.serialize_pair(name, value)} : Result<&2, &2, C.Error, String>}
  %Equal.sym(Bool, C.value_valid(value), True{}, vv) : {C.serialize_checked(name, value, C.defaults(), C.require(_, C.InvalidValue{}, Done{Unit{}})) == Done{C.serialize_pair(name, value)} : Result<&2, &2, C.Error, String>}
  Equal.cong(String, Result<&2, &2, C.Error, String>, x => Done{x}, C.serialize_pair(name, value) ++ "", C.serialize_pair(name, value), S.string_nil(C.serialize_pair(name, value)))

def split_delimited(+s: String, +tail: String, +ok: {clean(s) == True{} : Bool}) -> {String.split(s ++ ";" ++ tail, ';') == s <> String.split(tail, ';') : List<&2, String>}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{+c}, +t}:
      %Equal.sym(Bool, U32.is_eq(c, 59), False{}, clean_semicolon(c, Laws.and_left(clean_char(c), clean(t), ok))) : {String.split.fin(Chr{c}, String.split(t ++ ";" ++ tail, ';'), _) == SCon{Chr{c}, t} <> String.split(tail, ';') : List<&2, String>}
      %Equal.sym(List<&2, String>, String.split(t ++ ";" ++ tail, ';'), t <> String.split(tail, ';'), split_delimited(t, tail, Laws.and_right(clean_char(c), clean(t), ok))) : {String.split.push(Chr{c}, _) == SCon{Chr{c}, t} <> String.split(tail, ';') : List<&2, String>}
      {==}

def parse_cons(+name: String, +value: String, +tail: String, +nv: {C.name_valid(name) == True{} : Bool}, +vv: {C.value_valid(value) == True{} : Bool}) -> {C.parse(C.serialize_pair(name, value) ++ ";" ++ tail) == C.Entry{name, value} <> C.parse(tail) : List<&2, C.Entry>}:
  %Equal.sym(List<&2, C.Entry>, C.parse(C.serialize_pair(name, value) ++ ";" ++ tail), parts_reference(String.split(C.serialize_pair(name, value) ++ ";" ++ tail, ';')), parse_reference(C.serialize_pair(name, value) ++ ";" ++ tail)) : {_ == C.Entry{name, value} <> C.parse(tail) : List<&2, C.Entry>}
  %Equal.sym(List<&2, C.Entry>, C.parse(tail), parts_reference(String.split(tail, ';')), parse_reference(tail)) : {parts_reference(String.split(C.serialize_pair(name, value) ++ ";" ++ tail, ';')) == C.Entry{name, value} <> _ : List<&2, C.Entry>}
  %Equal.sym(List<&2, String>, String.split(C.serialize_pair(name, value) ++ ";" ++ tail, ';'), C.serialize_pair(name, value) <> String.split(tail, ';'), split_delimited(C.serialize_pair(name, value), tail, pair_clean(name, value, nv, vv))) : {parts_reference(_) == C.Entry{name, value} <> parts_reference(String.split(tail, ';')) : List<&2, C.Entry>}
  %Equal.sym(Maybe<&2, C.Entry>, C.parse_pair(C.serialize_pair(name, value)), Some{C.Entry{name, value}}, parse_pair(name, value, nv, vv)) : {C.keep(_, parts_reference(String.split(tail, ';'))) == C.Entry{name, value} <> parts_reference(String.split(tail, ';')) : List<&2, C.Entry>}
  {==}

def joined_roundtrip(+xs: List<&2, C.Entry>, +name: String, +value: String, +nv: {C.name_valid(name) == True{} : Bool}, +vv: {C.value_valid(value) == True{} : Bool}, +ok: {Spec.entries_valid(xs) == True{} : Bool}) -> {C.parse(String.join.go(Spec.pairs(xs), C.serialize_pair(name, value), ";")) == C.Entry{name, value} <> xs : List<&2, C.Entry>}:
  match xs:
    case Nil{}: roundtrip(name, value, nv, vv)
    case C.Entry{+k, +v} <> +t:
      +ok = head_valid(k, v, Spec.entries_valid(t), ok)
      %Equal.sym(List<&2, C.Entry>, C.parse(C.serialize_pair(name, value) ++ ";" ++ String.join.go(Spec.pairs(t), C.serialize_pair(k, v), ";")), C.Entry{name, value} <> C.parse(String.join.go(Spec.pairs(t), C.serialize_pair(k, v), ";")), parse_cons(name, value, String.join.go(Spec.pairs(t), C.serialize_pair(k, v), ";"), nv, vv)) : {_ == C.Entry{name, value} <> C.Entry{k, v} <> t : List<&2, C.Entry>}
      Equal.cong(List<&2, C.Entry>, List<&2, C.Entry>, rest => C.Entry{name, value} <> rest, C.parse(String.join.go(Spec.pairs(t), C.serialize_pair(k, v), ";")), C.Entry{k, v} <> t, joined_roundtrip(t, k, v, Laws.and_left(C.name_valid(k), C.value_valid(v), Laws.and_left(C.name_valid(k) && C.value_valid(v), Spec.entries_valid(t), ok)), Laws.and_right(C.name_valid(k), C.value_valid(v), Laws.and_left(C.name_valid(k) && C.value_valid(v), Spec.entries_valid(t), ok)), Laws.and_right(C.name_valid(k) && C.value_valid(v), Spec.entries_valid(t), ok)))

def list_roundtrip(+xs: List<&2, C.Entry>, +ok: {Spec.entries_valid(xs) == True{} : Bool}) -> {C.parse(String.join(Spec.pairs(xs), ";")) == xs : List<&2, C.Entry>}:
  match xs:
    case Nil{}: {==}
    case C.Entry{+name, +value} <> +t:
      +ok = head_valid(name, value, Spec.entries_valid(t), ok)
      joined_roundtrip(t, name, value, Laws.and_left(C.name_valid(name), C.value_valid(value), Laws.and_left(C.name_valid(name) && C.value_valid(value), Spec.entries_valid(t), ok)), Laws.and_right(C.name_valid(name), C.value_valid(value), Laws.and_left(C.name_valid(name) && C.value_valid(value), Spec.entries_valid(t), ok)), Laws.and_right(C.name_valid(name) && C.value_valid(value), Spec.entries_valid(t), ok))
