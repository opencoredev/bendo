# BND-85: proves proof/csrf-v1-laws.bend. Main trimmed a Content-Type essence
# with Base's String.trim (SP and HTAB, plus LF, VT, FF and CR); the current
# spec trims only SP and HTAB. The two trims agree on every value whose media
# type is well formed, because no token character or '/' is whitespace to
# Char.is_space (proof/media-chars.bend). Every other value is now inspected.
import Base
import ../LAWS.bend as L
import ../src/http/request.bend as Request
import ../src/http/media.bend as Media
import ../src/http/bytes.bend as B
import ./equality.bend as E
import ./text.bend as TP
import ./bytes-tail.bend as BT
import ./trim-spec.bend as Trim
import ./media-spec.bend as MediaSpec
import ./media.bend as MediaProof
import ./media-chars.bend as Chars
import ./csrf-spec.bend as Spec
import ./csrf-spec-v1.bend as V1
import ./csrf-v1-laws.bend as Laws

def and_true(a: Bool, b: Bool, x: {a == True{} : Bool}, y: {b == True{} : Bool}) -> {a && b == True{} : Bool}:
  %Equal.sym(Bool, a, True{}, x) : {_ && b == True{} : Bool}
  y

def or_left(a: Bool, b: Bool, x: {a == True{} : Bool}) -> {a || b == True{} : Bool}:
  %Equal.sym(Bool, a, True{}, x) : {_ || b == True{} : Bool}
  {==}

def or_after_false(a: Bool, b: Bool, x: {a == False{} : Bool}, y: {b == True{} : Bool}) -> {a || b == True{} : Bool}:
  %Equal.sym(Bool, a, False{}, x) : {_ || b == True{} : Bool}
  y

def or_true(a: Bool) -> {a || True{} == True{} : Bool}:
  match a:
    case True{}: {==}
    case False{}: {==}

def not_true(k: Bool, e: {Bool.not(k) == True{} : Bool}) -> {k == False{} : Bool}:
  match k:
    case True{}: E.absurd({True{} == False{} : Bool}, E.false_true(e))
    case False{}: {==}

# ---- SP and HTAB are whitespace to Char.is_space ----

def ows_case(+x: U32, k: Bool, ek: {U32.is_eq(x, 32) == k : Bool}, e: {k || U32.is_eq(x, 9) == True{} : Bool}) -> {Char.is_space(Chr{x}) == True{} : Bool}:
  match k:
    case True{}:
      %Equal.sym(Bool, U32.is_eq(x, 32), True{}, ek) : {Bool.or(_, Bool.and(U32.is_ge(x, 9), U32.is_le(x, 13))) == True{} : Bool}
      {==}
    case False{}: Equal.cong(U32, Bool, y => Char.is_space(Chr{y}), x, 9, L.u32_eq_sound(x, 9, e))

def ows_space(+x: U32, e: {Trim.space(x) == True{} : Bool}) -> {Char.is_space(Chr{x}) == True{} : Bool}:
  ows_case(x, U32.is_eq(x, 32), {==}, e)

# ---- The SP and HTAB trim over text ----

def sk_pick(+x: U32, t: String, rest: String, drop: Bool) -> String:
  match drop:
    case True{}: rest
    case False{}: SCon{Chr{x}, t}

def sk(s: String) -> String:
  match s:
    case SNil{}: ""
    case SCon{Chr{+x}, +t}: sk_pick(x, t, sk(t), Trim.space(x))

def blank(s: String) -> Bool:
  match s:
    case SNil{}: True{}
    case SCon{Chr{+x}, t}: Trim.space(x) && blank(t)

def cut(+x: U32, k: Bool, rest: String) -> String:
  match k:
    case True{}: ""
    case False{}: SCon{Chr{x}, rest}

def rs(s: String) -> String:
  match s:
    case SNil{}: ""
    case SCon{Chr{+x}, +t}: cut(x, Trim.space(x) && blank(t), rs(t))

def skip_pick_codes(+x: U32, +t: String, d: Bool, ih: {Trim.skip(Trim.codes(t)) == Trim.codes(sk(t)) : List<&2, U32>}) -> {Trim.skip_pick(x, Trim.codes(t), Trim.skip(Trim.codes(t)), d) == Trim.codes(sk_pick(x, t, sk(t), d)) : List<&2, U32>}:
  match d:
    case True{}: ih
    case False{}: {==}

def skip_codes(s: String) -> {Trim.skip(Trim.codes(s)) == Trim.codes(sk(s)) : List<&2, U32>}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{+x}, +t}: skip_pick_codes(x, t, Trim.space(x), skip_codes(t))

def blank_codes(s: String) -> {Trim.blank(Trim.codes(s)) == blank(s) : Bool}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{+x}, +t}: Equal.cong(Bool, Bool, z => Trim.space(x) && z, Trim.blank(Trim.codes(t)), blank(t), blank_codes(t))

def cut_codes(+x: U32, k: Bool, +r: String) -> {Trim.cut_pick(x, k, Trim.codes(r)) == Trim.codes(cut(x, k, r)) : List<&2, U32>}:
  match k:
    case True{}: {==}
    case False{}: {==}

def rstrip_codes(s: String) -> {Trim.rstrip(Trim.codes(s)) == Trim.codes(rs(s)) : List<&2, U32>}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{+x}, +t}:
      Equal.trans(List<&2, U32>, Trim.cut_pick(x, Trim.space(x) && Trim.blank(Trim.codes(t)), Trim.rstrip(Trim.codes(t))), Trim.cut_pick(x, Trim.space(x) && blank(t), Trim.codes(rs(t))), Trim.codes(rs(SCon{Chr{x}, t})), Equal.trans(List<&2, U32>, Trim.cut_pick(x, Trim.space(x) && Trim.blank(Trim.codes(t)), Trim.rstrip(Trim.codes(t))), Trim.cut_pick(x, Trim.space(x) && blank(t), Trim.rstrip(Trim.codes(t))), Trim.cut_pick(x, Trim.space(x) && blank(t), Trim.codes(rs(t))), Equal.cong(Bool, List<&2, U32>, z => Trim.cut_pick(x, Trim.space(x) && z, Trim.rstrip(Trim.codes(t))), Trim.blank(Trim.codes(t)), blank(t), blank_codes(t)), Equal.cong(List<&2, U32>, List<&2, U32>, r => Trim.cut_pick(x, Trim.space(x) && blank(t), r), Trim.rstrip(Trim.codes(t)), Trim.codes(rs(t)), rstrip_codes(t))), cut_codes(x, Trim.space(x) && blank(t), rs(t)))

def text_codes(w: String) -> {Trim.text(Trim.codes(w)) == w : String}:
  match w:
    case SNil{}: {==}
    case SCon{Chr{+x}, +t}: Equal.cong(String, String, r => SCon{Chr{x}, r}, Trim.text(Trim.codes(t)), t, text_codes(t))

def trim_rs(+b: String) -> {Trim.trim(b) == rs(sk(b)) : String}:
  Equal.trans(String, Trim.text(Trim.rstrip(Trim.skip(Trim.codes(b)))), Trim.text(Trim.rstrip(Trim.codes(sk(b)))), rs(sk(b)), Equal.cong(List<&2, U32>, String, z => Trim.text(Trim.rstrip(z)), Trim.skip(Trim.codes(b)), Trim.codes(sk(b)), skip_codes(b)), Equal.trans(String, Trim.text(Trim.rstrip(Trim.codes(sk(b)))), Trim.text(Trim.codes(rs(sk(b)))), rs(sk(b)), Equal.cong(List<&2, U32>, String, z => Trim.text(z), Trim.rstrip(Trim.codes(sk(b))), Trim.codes(rs(sk(b))), rstrip_codes(sk(b))), text_codes(rs(sk(b)))))

# ---- A well-formed media type has no Char.is_space whitespace ----

def clean(s: String) -> Bool:
  match s:
    case SNil{}: True{}
    case SCon{+h, t}: Bool.not(Char.is_space(h)) && clean(t)

def space_case(+c: U32, k: Bool, ek: {Char.is_space(Chr{c}) == k : Bool}, m: {MediaSpec.tchar(c) || MediaSpec.slash(c) == True{} : Bool}) -> {k == False{} : Bool}:
  match k:
    case False{}: {==}
    case True{}: E.absurd({True{} == False{} : Bool}, E.false_true(Equal.trans(Bool, False{}, Chars.clash(c), True{}, Equal.sym(Bool, Chars.clash(c), False{}, Chars.no_clash(c)), and_true(Char.is_space(Chr{c}), MediaSpec.tchar(c) || MediaSpec.slash(c), ek, m))))

def char_clean(+c: U32, m: {MediaSpec.tchar(c) || MediaSpec.slash(c) == True{} : Bool}) -> {Char.is_space(Chr{c}) == False{} : Bool}:
  space_case(c, Char.is_space(Chr{c}), {==}, m)

def keep_clean(+c: U32, +r: String, ns: {Char.is_space(Chr{c}) == False{} : Bool}, cr: {clean(r) == True{} : Bool}) -> {clean(SCon{Chr{c}, r}) == True{} : Bool}:
  %Equal.sym(Bool, Char.is_space(Chr{c}), False{}, ns) : {Bool.not(_) && clean(r) == True{} : Bool}
  cr

def sub_clean(s: String, some: Bool, +h: {MediaSpec.subtype(s, some) == True{} : Bool}) -> {clean(s) == True{} : Bool}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{+c}, +t}: keep_clean(c, t, char_clean(c, or_left(MediaSpec.tchar(c), MediaSpec.slash(c), L.and_left(MediaSpec.tchar(c), MediaSpec.subtype(t, True{}), h))), sub_clean(t, True{}, L.and_right(MediaSpec.tchar(c), MediaSpec.subtype(t, True{}), h)))

def tc_tail(+t: String, p: Bool, +b: Bool, +some: Bool, +q: Bool, +h: {p || ((b && some) && q) == True{} : Bool}, ihp: {p == True{} : Bool} -> {clean(t) == True{} : Bool}, ihq: {q == True{} : Bool} -> {clean(t) == True{} : Bool}) -> {clean(t) == True{} : Bool}:
  match p:
    case True{}: ihp({==})
    case False{}: ihq(L.and_right(b && some, q, h))

def type_clean_step(+c: U32, +t: String, a: Bool, +p: Bool, +b: Bool, +some: Bool, +q: Bool, ea: {MediaSpec.tchar(c) == a : Bool}, eb: {MediaSpec.slash(c) == b : Bool}, +h: {(a && p) || ((b && some) && q) == True{} : Bool}, ihp: {p == True{} : Bool} -> {clean(t) == True{} : Bool}, ihq: {q == True{} : Bool} -> {clean(t) == True{} : Bool}) -> {clean(SCon{Chr{c}, t}) == True{} : Bool}:
  match a:
    case True{}: keep_clean(c, t, char_clean(c, or_left(MediaSpec.tchar(c), MediaSpec.slash(c), ea)), tc_tail(t, p, b, some, q, h, ihp, ihq))
    case False{}: keep_clean(c, t, char_clean(c, or_after_false(MediaSpec.tchar(c), MediaSpec.slash(c), ea, Equal.trans(Bool, MediaSpec.slash(c), b, True{}, eb, L.and_left(b, some, L.and_left(b && some, q, h))))), ihq(L.and_right(b && some, q, h)))

def type_clean(s: String, +some: Bool, h: {MediaSpec.main_type(s, some) == True{} : Bool}) -> {clean(s) == True{} : Bool}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{+c}, +t}: type_clean_step(c, t, MediaSpec.tchar(c), MediaSpec.main_type(t, True{}), MediaSpec.slash(c), some, MediaSpec.subtype(t, False{}), {==}, {==}, h, e => type_clean(t, True{}, e), e => sub_clean(t, False{}, e))

# ---- Base's trim at the start ----

def head_free(+x: U32, +t: String, ed: {Trim.space(x) == False{} : Bool}, h: {clean(rs(SCon{Chr{x}, t})) == True{} : Bool}) -> {Char.is_space(Chr{x}) == False{} : Bool}:
  not_true(Char.is_space(Chr{x}), L.and_left(Bool.not(Char.is_space(Chr{x})), clean(rs(t)), Equal.trans(Bool, clean(cut(x, False{} && blank(t), rs(t))), clean(cut(x, Trim.space(x) && blank(t), rs(t))), True{}, Equal.cong(Bool, Bool, z => clean(cut(x, z && blank(t), rs(t))), False{}, Trim.space(x), Equal.sym(Bool, Trim.space(x), False{}, ed)), h)))

def lead_case(+x: U32, +t: String, d: Bool, ed: {Trim.space(x) == d : Bool}, h: {clean(rs(sk_pick(x, t, sk(t), d))) == True{} : Bool}, ih: {clean(rs(sk(t))) == True{} : Bool} -> {String.trim_start(t) == sk(t) : String}) -> {String.trim_start.if(t, Chr{x}, Char.is_space(Chr{x})) == sk_pick(x, t, sk(t), d) : String}:
  match d:
    case True{}:
      %Equal.sym(Bool, Char.is_space(Chr{x}), True{}, ows_space(x, ed)) : {String.trim_start.if(t, Chr{x}, _) == sk(t) : String}
      ih(h)
    case False{}:
      %Equal.sym(Bool, Char.is_space(Chr{x}), False{}, head_free(x, t, ed, h)) : {String.trim_start.if(t, Chr{x}, _) == SCon{Chr{x}, t} : String}
      {==}

# With no whitespace left after the SP and HTAB trim, Base's trim_start drops
# exactly the leading SP and HTAB.
def lead(b: String, h: {clean(rs(sk(b))) == True{} : Bool}) -> {String.trim_start(b) == sk(b) : String}:
  match b:
    case SNil{}: {==}
    case SCon{Chr{+x}, +t}: lead_case(x, t, Trim.space(x), {==}, h, e => lead(t, e))

# ---- Base's trim at the end, as a structural strip (after proof/trim.bend) ----

def blank_ws(s: String) -> Bool:
  match s:
    case SNil{}: True{}
    case SCon{+h, t}: Char.is_space(h) && blank_ws(t)

def cut_ws(+h: Char, k: Bool, rest: String) -> String:
  match k:
    case True{}: ""
    case False{}: SCon{h, rest}

def rs_ws(s: String) -> String:
  match s:
    case SNil{}: ""
    case SCon{+h, +t}: cut_ws(h, Char.is_space(h) && blank_ws(t), rs_ws(t))

def rs_ws_blank(+xs: String, e: {blank_ws(xs) == True{} : Bool}) -> {rs_ws(xs) == "" : String}:
  match xs:
    case SNil{}: {==}
    case SCon{+h, +t}:
      %Equal.sym(Bool, Char.is_space(h) && blank_ws(t), True{}, e) : {cut_ws(h, _, rs_ws(t)) == "" : String}
      {==}

def choose(b: Bool, x: String, y: String) -> String:
  match b:
    case True{}: x
    case False{}: y

def reverse_step(+h: Char, +t: String, +acc: String, bt: Bool, sc: Bool, e: {blank_ws(t) == bt : Bool}) -> {choose(bt, String.trim_start.if(acc, h, sc), String.reverse.go(rs_ws(t), SCon{h, acc})) == choose(sc && bt, String.trim_start(acc), String.reverse.go(cut_ws(h, sc && bt, rs_ws(t)), acc)) : String}:
  match bt sc:
    case True{} True{}: {==}
    case True{} False{}:
      %Equal.sym(String, rs_ws(t), "", rs_ws_blank(t, e)) : {SCon{h, acc} == String.reverse.go(_, SCon{h, acc}) : String}
      {==}
    case False{} True{}: {==}
    case False{} False{}: {==}

def skip_reverse(+ys: String, +acc: String) -> {String.trim_start(String.reverse.go(ys, acc)) == choose(blank_ws(ys), String.trim_start(acc), String.reverse.go(rs_ws(ys), acc)) : String}:
  match ys:
    case SNil{}: {==}
    case SCon{+h, +t}:
      Equal.trans(String, String.trim_start(String.reverse.go(t, SCon{h, acc})), choose(blank_ws(t), String.trim_start(SCon{h, acc}), String.reverse.go(rs_ws(t), SCon{h, acc})), choose(Char.is_space(h) && blank_ws(t), String.trim_start(acc), String.reverse.go(cut_ws(h, Char.is_space(h) && blank_ws(t), rs_ws(t)), acc)), skip_reverse(t, SCon{h, acc}), reverse_step(h, t, acc, blank_ws(t), Char.is_space(h), {==}))

def reverse_twice(+x: String) -> {String.reverse(String.reverse(x)) == x : String}:
  Equal.trans(String, String.reverse(String.reverse(x)), String.append(x, ""), x, TP.reverse_onto(x, "", ""), TP.string_append_nil(x))

def strip_end(+ys: String, +b: Bool, e: {blank_ws(ys) == b : Bool}) -> {String.reverse(choose(b, "", String.reverse(rs_ws(ys)))) == rs_ws(ys) : String}:
  match b:
    case True{}: Equal.sym(String, rs_ws(ys), "", rs_ws_blank(ys, e))
    case False{}: reverse_twice(rs_ws(ys))

def trim_end(+ys: String) -> {String.trim_end(ys) == rs_ws(ys) : String}:
  %Equal.sym(String, String.trim_start(String.reverse(ys)), choose(blank_ws(ys), "", String.reverse(rs_ws(ys))), skip_reverse(ys, "")) : {String.reverse(_) == rs_ws(ys) : String}
  strip_end(ys, blank_ws(ys), {==})

def blank_ws_of(+s: String, +e: {blank(s) == True{} : Bool}) -> {blank_ws(s) == True{} : Bool}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{+x}, +t}: and_true(Char.is_space(Chr{x}), blank_ws(t), ows_space(x, L.and_left(Trim.space(x), blank(t), e)), blank_ws_of(t, L.and_right(Trim.space(x), blank(t), e)))

def tail_case(+x: U32, +t: String, k: Bool, +ek: {Trim.space(x) && blank(t) == k : Bool}, +h: {clean(cut(x, k, rs(t))) == True{} : Bool}, ih: {clean(rs(t)) == True{} : Bool} -> {rs_ws(t) == rs(t) : String}) -> {cut_ws(Chr{x}, Char.is_space(Chr{x}) && blank_ws(t), rs_ws(t)) == cut(x, k, rs(t)) : String}:
  match k:
    case True{}:
      %Equal.sym(Bool, Char.is_space(Chr{x}) && blank_ws(t), True{}, and_true(Char.is_space(Chr{x}), blank_ws(t), ows_space(x, L.and_left(Trim.space(x), blank(t), ek)), blank_ws_of(t, L.and_right(Trim.space(x), blank(t), ek)))) : {cut_ws(Chr{x}, _, rs_ws(t)) == "" : String}
      {==}
    case False{}:
      %Equal.sym(Bool, Char.is_space(Chr{x}), False{}, not_true(Char.is_space(Chr{x}), L.and_left(Bool.not(Char.is_space(Chr{x})), clean(rs(t)), h))) : {cut_ws(Chr{x}, _ && blank_ws(t), rs_ws(t)) == SCon{Chr{x}, rs(t)} : String}
      Equal.cong(String, String, r => SCon{Chr{x}, r}, rs_ws(t), rs(t), ih(L.and_right(Bool.not(Char.is_space(Chr{x})), clean(rs(t)), h)))

# With no whitespace left after the SP and HTAB strip, Base's trailing strip
# drops exactly the trailing SP and HTAB.
def tail(y: String, h: {clean(rs(y)) == True{} : Bool}) -> {rs_ws(y) == rs(y) : String}:
  match y:
    case SNil{}: {==}
    case SCon{Chr{+x}, +t}: tail_case(x, t, Trim.space(x) && blank(t), {==}, h, e => tail(t, e))

# ---- The two essences agree on well-formed media types ----

def trims_agree(+b: String, w: {MediaSpec.main_type(Trim.trim(b), False{}) == True{} : Bool}) -> {String.trim(b) == Trim.trim(b) : String}:
  +cl = type_clean(rs(sk(b)), False{}, Equal.trans(Bool, MediaSpec.main_type(rs(sk(b)), False{}), MediaSpec.main_type(Trim.trim(b), False{}), True{}, Equal.cong(String, Bool, z => MediaSpec.main_type(z, False{}), rs(sk(b)), Trim.trim(b), Equal.sym(String, Trim.trim(b), rs(sk(b)), trim_rs(b))), w))
  Equal.trans(String, String.trim_end(String.trim_start(b)), String.trim_end(sk(b)), Trim.trim(b), Equal.cong(String, String, z => String.trim_end(z), String.trim_start(b), sk(b), lead(b, cl)), Equal.trans(String, String.trim_end(sk(b)), rs_ws(sk(b)), Trim.trim(b), trim_end(sk(b)), Equal.trans(String, rs_ws(sk(b)), rs(sk(b)), Trim.trim(b), tail(sk(b), cl), Equal.sym(String, Trim.trim(b), rs(sk(b)), trim_rs(b)))))

def essence_agrees(+v: String, w: {MediaSpec.well_formed(v) == True{} : Bool}) -> {V1.essence(v) == MediaSpec.essence(v) : String}:
  Equal.trans(String, B.fold(String.trim(Media.before_params(v))), String.to_lower(String.trim(MediaSpec.before(v))), MediaSpec.essence(v), Equal.trans(String, B.fold(String.trim(Media.before_params(v))), B.fold(String.trim(MediaSpec.before(v))), String.to_lower(String.trim(MediaSpec.before(v))), Equal.cong(String, String, z => B.fold(String.trim(z)), Media.before_params(v), MediaSpec.before(v), MediaProof.before_same(v)), BT.fold_equiv(String.trim(MediaSpec.before(v)))), Equal.cong(String, String, z => String.to_lower(z), String.trim(MediaSpec.before(v)), Trim.trim(MediaSpec.before(v)), trims_agree(MediaSpec.before(v), w)))

# ---- The laws ----

def body_some(+v: String, wf: Bool, ewf: {MediaSpec.well_formed(v) == wf : Bool}, e: {Spec.form_essence(V1.essence(v)) == True{} : Bool}) -> {Spec.form_essence(MediaSpec.essence(v)) || Bool.not(wf) == True{} : Bool}:
  match wf:
    case True{}:
      %Equal.sym(Bool, Spec.form_essence(MediaSpec.essence(v)), True{}, Equal.trans(Bool, Spec.form_essence(MediaSpec.essence(v)), Spec.form_essence(V1.essence(v)), True{}, Equal.cong(String, Bool, z => Spec.form_essence(z), MediaSpec.essence(v), V1.essence(v), Equal.sym(String, V1.essence(v), MediaSpec.essence(v), essence_agrees(v, ewf))), e)) : {_ || False{} == True{} : Bool}
      {==}
    case False{}: or_true(Spec.form_essence(MediaSpec.essence(v)))

def simple(+ct: Maybe<&2, String>, e: {V1.simple_body(ct) == True{} : Bool}) -> {Spec.simple_body(ct) == True{} : Bool}:
  match ct:
    case None{}: {==}
    case Some{+v}: body_some(v, MediaSpec.well_formed(v), {==}, e)

def inspected_case(r: Bool, +ct: Maybe<&2, String>, e: {Bool.not(r) && V1.simple_body(ct) == True{} : Bool}) -> {Bool.not(r) && Spec.simple_body(ct) == True{} : Bool}:
  match r:
    case True{}: e
    case False{}: simple(ct, e)

def deny_case(i1: Bool, +i2: Bool, s: Bool, t: Bool, imp: {i1 == True{} : Bool} -> {i2 == True{} : Bool}, no: {Bool.not(i1) || s || t == False{} : Bool}) -> {Bool.not(i2) || s || t == False{} : Bool}:
  match i1:
    case False{}: E.absurd({Bool.not(i2) || s || t == False{} : Bool}, E.false_true(Equal.sym(Bool, True{}, False{}, no)))
    case True{}:
      %Equal.sym(Bool, i2, True{}, imp({==})) : {Bool.not(_) || s || t == False{} : Bool}
      no

def Laws.csrf_spec_v1_inspected(method, content_type, e):
  inspected_case(Spec.reads_only(method), content_type, e)

def Laws.csrf_spec_v1_denies(origins, scheme, method, content_type, site, origin, referer, host, e):
  deny_case(V1.inspected(method, content_type), Spec.inspected(method, content_type), Spec.site_is(site, "same-origin"), Spec.trusted(origins, scheme, site, Spec.source(origin, referer), host), x => inspected_case(Spec.reads_only(method), content_type, x), e)
