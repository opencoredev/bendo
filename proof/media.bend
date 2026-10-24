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

def Laws.media_essence_spec(value): essence(value)
