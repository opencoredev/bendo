# BND-85: Media.essence meets proof/media-spec.bend.
import Base
import ../src/http/media.bend as Media
import ../src/http/bytes.bend as B
import ./media-spec.bend as Spec
import ./trim-spec.bend as Trim
import ./media-laws.bend as Laws
import ./trim.bend as TrimProof
import ./misc-tail.bend as MT
import ./bytes-tail.bend as BT
import ../LAWS.bend as L
import ./hot-path.bend as HP
import ./equality.bend as E

def pick_same(+c: Char, +r: String, b: Bool) -> {Media.before_pick(c, r, b) == Spec.stop_pick(c, r, b) : String}:
  match b:
    case True{}: {==}
    case False{}: {==}

def before_inner(s: String) -> {Media.before_params_spec(s) == Spec.before(s) : String}:
  match s:
    case SNil{}: {==}
    case SCon{+c, +t}:
      Equal.trans(String, Media.before_pick(c, Media.before_params_spec(t), Char.is_eq(c, ';')), Media.before_pick(c, Spec.before(t), Char.is_eq(c, ';')), Spec.stop_pick(c, Spec.before(t), Char.is_eq(c, ';')), Equal.cong(String, String, r => Media.before_pick(c, r, Char.is_eq(c, ';')), Media.before_params_spec(t), Spec.before(t), before_inner(t)), pick_same(c, Spec.before(t), Char.is_eq(c, ';')))

def before_same(+s: String) -> {Media.before_params(s) == Spec.before(s) : String}:
  Equal.trans(String, Media.before_params(s), Media.before_params_spec(s), Spec.before(s), MT.before_params_equiv(s), before_inner(s))

def essence(+value: String) -> {Media.essence(value) == Spec.essence(value) : String}:
  %Equal.sym(String, Media.before_params(value), Spec.before(value), before_same(value)) : {B.fold(B.trim_text(_)) == Spec.essence(value) : String}
  Equal.trans(String, B.fold(B.trim_text(Spec.before(value))), String.to_lower(B.trim_text(Spec.before(value))), Spec.essence(value), BT.fold_equiv(B.trim_text(Spec.before(value))), Equal.cong(String, String, x => String.to_lower(x), B.trim_text(Spec.before(value)), Trim.trim(Spec.before(value)), TrimProof.trim_text(Spec.before(value))))


# ---- Well-formed media types ----

def tchar_same(+c: U32) -> {B.tchar(c) == Spec.tchar(c) : Bool}:
  HP.tchar_equiv(c)

def slash_case(+c: U32, d: Bool, e: {U32.is_eq(c, 47) == d : Bool}) -> {d && B.tchar(c) == False{} : Bool}:
  match d:
    case False{}: {==}
    case True{}: Equal.cong(U32, Bool, x => B.tchar(x), c, 47, L.u32_eq_sound(c, 47, e))

# '/' is not a token character.
def slash_not_tchar(+c: U32) -> {U32.is_eq(c, 47) && B.tchar(c) == False{} : Bool}:
  slash_case(c, U32.is_eq(c, 47), {==})

def sub_drop(+t: String, d: Bool, some: Bool) -> {((d && some) && False{}) && Spec.subtype(t, False{}) == False{} : Bool}:
  match d some:
    case False{} _: {==}
    case True{} False{}: {==}
    case True{} True{}: {==}

def sub_tail(+t: String, ok: Bool, tc: Bool, d: Bool, some: Bool) -> {(ok && (tc || ((d && some) && False{}))) && Spec.subtype(t, tc) == ok && (tc && Spec.subtype(t, True{})) : Bool}:
  match ok tc:
    case False{} _: {==}
    case True{} True{}: {==}
    case True{} False{}: sub_drop(t, d, some)

# After the '/', the loop checks a subtype.
def sub_go(s: String, +some: Bool, +ok: Bool) -> {Media.shape_go(s, True{}, some, ok) == ok && Spec.subtype(s, some) : Bool}:
  match s:
    case SNil{}:
      match ok:
        case False{}: {==}
        case True{}: {==}
    case SCon{Chr{+c}, +t}:
      Equal.trans(Bool, Media.shape_go(t, True{}, B.tchar(c), ok && (B.tchar(c) || ((U32.is_eq(c, 47) && some) && False{}))), (ok && (B.tchar(c) || ((U32.is_eq(c, 47) && some) && False{}))) && Spec.subtype(t, B.tchar(c)), ok && (Spec.tchar(c) && Spec.subtype(t, True{})), sub_go(t, B.tchar(c), ok && (B.tchar(c) || ((U32.is_eq(c, 47) && some) && False{}))), Equal.trans(Bool, (ok && (B.tchar(c) || ((U32.is_eq(c, 47) && some) && False{}))) && Spec.subtype(t, B.tchar(c)), ok && (B.tchar(c) && Spec.subtype(t, True{})), ok && (Spec.tchar(c) && Spec.subtype(t, True{})), sub_tail(t, ok, B.tchar(c), U32.is_eq(c, 47), some), Equal.cong(Bool, Bool, x => ok && (x && Spec.subtype(t, True{})), B.tchar(c), Spec.tchar(c), tchar_same(c))))

def or_false(+a: Bool) -> {a == (a || False{}) : Bool}:
  match a:
    case True{}: {==}
    case False{}: {==}

def type_plain(+t: String, ok: Bool, tc: Bool) -> {(ok && (tc || False{})) && Spec.main_type(t, tc) == ok && ((tc && Spec.main_type(t, True{})) || False{}) : Bool}:
  match ok tc:
    case False{} _: {==}
    case True{} True{}: or_false(Spec.main_type(t, True{}))
    case True{} False{}: {==}

def type_slash(+t: String, ok: Bool, some: Bool) -> {(ok && (some && True{})) && Spec.subtype(t, False{}) == ok && (some && Spec.subtype(t, False{})) : Bool}:
  match ok some:
    case False{} _: {==}
    case True{} True{}: {==}
    case True{} False{}: {==}

def type_slash_char(+t: String, tc: Bool, +ok: Bool, +some: Bool, ex: {tc == False{} : Bool}, ih: {Media.shape_go(t, True{}, tc, ok && (tc || (some && True{}))) == (ok && (tc || (some && True{}))) && Spec.subtype(t, tc) : Bool}) -> {Media.shape_go(t, True{}, tc, ok && (tc || (some && True{}))) == ok && ((tc && Spec.main_type(t, True{})) || (some && Spec.subtype(t, False{}))) : Bool}:
  match tc:
    case True{}: E.absurd({Media.shape_go(t, True{}, True{}, ok && (True{} || (some && True{}))) == ok && ((True{} && Spec.main_type(t, True{})) || (some && Spec.subtype(t, False{}))) : Bool}, E.false_true(Equal.sym(Bool, True{}, False{}, ex)))
    case False{}: Equal.trans(Bool, Media.shape_go(t, True{}, False{}, ok && (False{} || (some && True{}))), (ok && (some && True{})) && Spec.subtype(t, False{}), ok && (some && Spec.subtype(t, False{})), ih, type_slash(t, ok, some))

def type_step(+t: String, d: Bool, +tc: Bool, +ok: Bool, +some: Bool, ex: {d && tc == False{} : Bool}, ihf: {Media.shape_go(t, False{}, tc, ok && (tc || ((d && some) && True{}))) == (ok && (tc || ((d && some) && True{}))) && Spec.main_type(t, tc) : Bool}, iht: {Media.shape_go(t, True{}, tc, ok && (tc || ((d && some) && True{}))) == (ok && (tc || ((d && some) && True{}))) && Spec.subtype(t, tc) : Bool}) -> {Media.shape_go(t, d, tc, ok && (tc || ((d && some) && True{}))) == ok && ((tc && Spec.main_type(t, True{})) || ((d && some) && Spec.subtype(t, False{}))) : Bool}:
  match d:
    case False{}: Equal.trans(Bool, Media.shape_go(t, False{}, tc, ok && (tc || False{})), (ok && (tc || False{})) && Spec.main_type(t, tc), ok && ((tc && Spec.main_type(t, True{})) || False{}), ihf, type_plain(t, ok, tc))
    case True{}: type_slash_char(t, tc, ok, some, ex, iht)

# Before the '/', the loop checks a type and then a subtype.
def type_go(s: String, +some: Bool, +ok: Bool) -> {Media.shape_go(s, False{}, some, ok) == ok && Spec.main_type(s, some) : Bool}:
  match s:
    case SNil{}:
      match ok:
        case False{}: {==}
        case True{}: {==}
    case SCon{Chr{+c}, +t}:
      Equal.trans(Bool, Media.shape_go(t, U32.is_eq(c, 47), B.tchar(c), ok && (B.tchar(c) || ((U32.is_eq(c, 47) && some) && True{}))), ok && ((B.tchar(c) && Spec.main_type(t, True{})) || ((U32.is_eq(c, 47) && some) && Spec.subtype(t, False{}))), ok && ((Spec.tchar(c) && Spec.main_type(t, True{})) || ((U32.is_eq(c, 47) && some) && Spec.subtype(t, False{}))), type_step(t, U32.is_eq(c, 47), B.tchar(c), ok, some, slash_not_tchar(c), type_go(t, B.tchar(c), ok && (B.tchar(c) || ((U32.is_eq(c, 47) && some) && True{}))), sub_go(t, B.tchar(c), ok && (B.tchar(c) || ((U32.is_eq(c, 47) && some) && True{})))), Equal.cong(Bool, Bool, x => ok && ((x && Spec.main_type(t, True{})) || ((U32.is_eq(c, 47) && some) && Spec.subtype(t, False{}))), B.tchar(c), Spec.tchar(c), tchar_same(c)))

def trimmed_same(+value: String) -> {B.trim_text(Media.before_params(value)) == Trim.trim(Spec.before(value)) : String}:
  Equal.trans(String, B.trim_text(Media.before_params(value)), B.trim_text(Spec.before(value)), Trim.trim(Spec.before(value)), Equal.cong(String, String, x => B.trim_text(x), Media.before_params(value), Spec.before(value), before_same(value)), TrimProof.trim_text(Spec.before(value)))

def well_formed(+value: String) -> {Media.well_formed(value) == Spec.well_formed(value) : Bool}:
  Equal.trans(Bool, Media.shape_go(B.trim_text(Media.before_params(value)), False{}, False{}, True{}), Media.shape_go(Trim.trim(Spec.before(value)), False{}, False{}, True{}), Spec.well_formed(value), Equal.cong(String, Bool, x => Media.shape_go(x, False{}, False{}, True{}), B.trim_text(Media.before_params(value)), Trim.trim(Spec.before(value)), trimmed_same(value)), type_go(Trim.trim(Spec.before(value)), False{}, True{}))

def Laws.media_essence_spec(value): essence(value)
def Laws.media_well_formed_spec(value): well_formed(value)
