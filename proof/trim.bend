# BND-85: Bytes.trim and Bytes.trim_text meet proof/trim-spec.bend.
import Base
import ../src/http/bytes.bend as B
import ./trim-spec.bend as Spec
import ./trim-laws.bend as Laws
import ./bytes-tail.bend as BT
import ./text.bend as TP

def lead_skip(xs: List<&2, U32>, +c: U32, space: Bool) -> {B.trim_lead(xs, c, space) == Spec.skip_pick(c, xs, Spec.skip(xs), space) : List<&2, U32>}:
  match xs space:
    case Nil{} False{}: {==}
    case Nil{} True{}: {==}
    case +d <> +t False{}: {==}
    case +d <> +t True{}: lead_skip(t, d, B.ows(d))

def start_skip(+xs: List<&2, U32>) -> {B.trim_start(xs) == Spec.skip(xs) : List<&2, U32>}:
  match xs:
    case Nil{}: {==}
    case +c <> +t: lead_skip(t, c, B.ows(c))

# A blank list has nothing left after the trailing strip.
def rstrip_blank(+xs: List<&2, U32>, e: {Spec.blank(xs) == True{} : Bool}) -> {Spec.rstrip(xs) == [] : List<&2, U32>}:
  match xs:
    case Nil{}: {==}
    case +c <> +t:
      %Equal.sym(Bool, Spec.space(c) && Spec.blank(t), True{}, e) : {Spec.cut_pick(c, _, Spec.rstrip(t)) == [] : List<&2, U32>}
      {==}

def choose(b: Bool, x: List<&2, U32>, y: List<&2, U32>) -> List<&2, U32>:
  match b:
    case True{}: x
    case False{}: y

def reverse_step(+c: U32, +t: List<&2, U32>, +acc: List<&2, U32>, bt: Bool, sc: Bool, e: {Spec.blank(t) == bt : Bool}) -> {choose(bt, Spec.skip_pick(c, acc, Spec.skip(acc), sc), List.reverse.go(&2, U32, Spec.rstrip(t), c <> acc)) == choose(sc && bt, Spec.skip(acc), List.reverse.go(&2, U32, Spec.cut_pick(c, sc && bt, Spec.rstrip(t)), acc)) : List<&2, U32>}:
  match bt sc:
    case True{} True{}: {==}
    case True{} False{}:
      %Equal.sym(List<&2, U32>, Spec.rstrip(t), [], rstrip_blank(t, e)) : {c <> acc == List.reverse.go(&2, U32, _, c <> acc) : List<&2, U32>}
      {==}
    case False{} True{}: {==}
    case False{} False{}: {==}

# Skipping the leading blanks of a reversed list strips the original's
# trailing blanks.
def skip_reverse(+ys: List<&2, U32>, +acc: List<&2, U32>) -> {Spec.skip(List.reverse.go(&2, U32, ys, acc)) == choose(Spec.blank(ys), Spec.skip(acc), List.reverse.go(&2, U32, Spec.rstrip(ys), acc)) : List<&2, U32>}:
  match ys:
    case Nil{}: {==}
    case +c <> +t:
      Equal.trans(List<&2, U32>, Spec.skip(List.reverse.go(&2, U32, t, c <> acc)), choose(Spec.blank(t), Spec.skip(c <> acc), List.reverse.go(&2, U32, Spec.rstrip(t), c <> acc)), choose(Spec.space(c) && Spec.blank(t), Spec.skip(acc), List.reverse.go(&2, U32, Spec.cut_pick(c, Spec.space(c) && Spec.blank(t), Spec.rstrip(t)), acc)), skip_reverse(t, c <> acc), reverse_step(c, t, acc, Spec.blank(t), Spec.space(c), {==}))

def reverse_twice(+xs: List<&2, U32>) -> {List.reverse(&2, U32, List.reverse(&2, U32, xs)) == xs : List<&2, U32>}:
  Equal.trans(List<&2, U32>, List.reverse(&2, U32, List.reverse(&2, U32, xs)), List.append(&2, U32, xs, []), xs, TP.bytes_reverse_onto(xs, [], []), TP.list_append_nil(U32, xs))

def strip_end(+ys: List<&2, U32>, +b: Bool, e: {Spec.blank(ys) == b : Bool}) -> {List.reverse(&2, U32, choose(b, [], List.reverse(&2, U32, Spec.rstrip(ys)))) == Spec.rstrip(ys) : List<&2, U32>}:
  match b:
    case True{}: Equal.sym(List<&2, U32>, Spec.rstrip(ys), [], rstrip_blank(ys, e))
    case False{}: reverse_twice(Spec.rstrip(ys))

def reverse_skip(+ys: List<&2, U32>) -> {List.reverse(&2, U32, Spec.skip(List.reverse(&2, U32, ys))) == Spec.rstrip(ys) : List<&2, U32>}:
  %Equal.sym(List<&2, U32>, Spec.skip(List.reverse(&2, U32, ys)), choose(Spec.blank(ys), [], List.reverse(&2, U32, Spec.rstrip(ys))), skip_reverse(ys, [])) : {List.reverse(&2, U32, _) == Spec.rstrip(ys) : List<&2, U32>}
  strip_end(ys, Spec.blank(ys), {==})

def trim_strip(+xs: List<&2, U32>) -> {B.trim(xs) == Spec.strip(xs) : List<&2, U32>}:
  %Equal.sym(List<&2, U32>, B.trim_start(xs), Spec.skip(xs), start_skip(xs)) : {List.reverse(&2, U32, B.trim_start(List.reverse(&2, U32, _))) == Spec.strip(xs) : List<&2, U32>}
  %Equal.sym(List<&2, U32>, B.trim_start(List.reverse(&2, U32, Spec.skip(xs))), Spec.skip(List.reverse(&2, U32, Spec.skip(xs))), start_skip(List.reverse(&2, U32, Spec.skip(xs)))) : {List.reverse(&2, U32, _) == Spec.strip(xs) : List<&2, U32>}
  reverse_skip(Spec.skip(xs))

def encode_codes_inner(s: String) -> {B.encode_spec(s) == Spec.codes(s) : List<&2, U32>}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{+c}, +t}: Equal.cong(List<&2, U32>, List<&2, U32>, r => c <> r, B.encode_spec(t), Spec.codes(t), encode_codes_inner(t))

def encode_codes(+s: String) -> {B.encode(s) == Spec.codes(s) : List<&2, U32>}:
  Equal.trans(List<&2, U32>, B.encode(s), B.encode_spec(s), Spec.codes(s), BT.encode_equiv(s), encode_codes_inner(s))

def ascii_text_inner(xs: List<&2, U32>) -> {B.ascii_spec(xs) == Spec.text(xs) : String}:
  match xs:
    case Nil{}: {==}
    case +c <> +t: Equal.cong(String, String, s => SCon{Chr{c}, s}, B.ascii_spec(t), Spec.text(t), ascii_text_inner(t))

def ascii_text(+xs: List<&2, U32>) -> {B.ascii(xs) == Spec.text(xs) : String}:
  Equal.trans(String, B.ascii(xs), B.ascii_spec(xs), Spec.text(xs), BT.ascii_equiv(xs), ascii_text_inner(xs))

def trim_text(+s: String) -> {B.trim_text(s) == Spec.trim(s) : String}:
  %Equal.sym(List<&2, U32>, B.encode(s), Spec.codes(s), encode_codes(s)) : {B.ascii(B.trim(_)) == Spec.trim(s) : String}
  %Equal.sym(List<&2, U32>, B.trim(Spec.codes(s)), Spec.strip(Spec.codes(s)), trim_strip(Spec.codes(s))) : {B.ascii(_) == Spec.trim(s) : String}
  ascii_text(Spec.strip(Spec.codes(s)))

def Laws.bytes_trim_spec(xs): trim_strip(xs)
def Laws.bytes_trim_text_spec(s): trim_text(s)
