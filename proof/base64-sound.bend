# BND-87: strict padded standard Base64 decoding accepts only canonical
# text. Whenever decode returns Some{bytes}, the input is exactly the
# independent RFC 4648 encoding Spec.base64(bytes), and every byte is an
# octet. The character facts come from the generated base64-chars.bend.
import Base
import ../src/data/base64.bend as B
import ../src/data/utf8.bend as U
import ../src/crypto/octets.bend as O
import ./crypto-octets.bend as OctetsProof
import ./signed-cookie-spec.bend as Spec
import ./signed-cookie-format.bend as Format
import ./base64-chars.bend as Chars
import ./json-credit.bend as Credit
import ./utf8.bend as UP

# ---- Small logic ----

def found_tag(m: Maybe<&2, List<&2, U32>>) -> Type:
  match m:
    case None{}: Unit
    case Some{x}: Empty

def none_some(+x: List<&2, U32>, e: {None{} == Some{x} : Maybe<&2, List<&2, U32>>}) -> Empty:
  %e : found_tag(_)
  Unit{}

def get(m: Maybe<&2, List<&2, U32>>, d: List<&2, U32>) -> List<&2, U32>:
  match m:
    case None{}: d
    case Some{x}: x

def some_inj(+a: List<&2, U32>, +b: List<&2, U32>, e: {Some{a} == Some{b} : Maybe<&2, List<&2, U32>>}) -> {a == b : List<&2, U32>}:
  Equal.cong(Maybe<&2, List<&2, U32>>, List<&2, U32>, m => get(m, a), Some{a}, Some{b}, e)

# A computation equal to None cannot also equal Some{out}.
def clash(+m: Maybe<&2, List<&2, U32>>, +out: List<&2, U32>, none: {m == None{} : Maybe<&2, List<&2, U32>>}, h: {m == Some{out} : Maybe<&2, List<&2, U32>>}) -> Empty:
  none_some(out, Equal.trans(Maybe<&2, List<&2, U32>>, None{}, m, Some{out}, Equal.sym(Maybe<&2, List<&2, U32>>, m, None{}, none), h))

def char_of(+c: Char, e: {Char.is_eq(c, '=') == True{} : Bool}) -> {c == '=' : Char}:
  match c:
    case Chr{+x}:
      Equal.cong(U32, Char, y => Chr{y}, x, 61, Credit.u32_eq_sound(x, 61, e))

# ---- Failed groups and failed accumulators ----

def d1_false(+x: Maybe<&2, Word(6n)>, +y: Maybe<&2, Word(6n)>, +acc: Maybe<&2, List<&2, U32>>) -> {B.decode1(x, y, acc, False{}) == None{} : Maybe<&2, List<&2, U32>>}:
  match x y acc:
    case Some{a} Some{b} Some{rev}: {==}
    case Some{a} Some{b} None{}: {==}
    case Some{a} None{} acc: {==}
    case None{} y acc: {==}

def d2_false(+x: Maybe<&2, Word(6n)>, +y: Maybe<&2, Word(6n)>, +z: Maybe<&2, Word(6n)>, +acc: Maybe<&2, List<&2, U32>>) -> {B.decode2(x, y, z, acc, False{}) == None{} : Maybe<&2, List<&2, U32>>}:
  match x y z acc:
    case Some{a} Some{b} Some{c} Some{rev}: {==}
    case Some{a} Some{b} Some{c} None{}: {==}
    case Some{a} Some{b} None{} acc: {==}
    case Some{a} None{} z acc: {==}
    case None{} y z acc: {==}

def d1_none(+x: Maybe<&2, Word(6n)>, +y: Maybe<&2, Word(6n)>, +ok: Bool) -> {B.decode1(x, y, None{}, ok) == None{} : Maybe<&2, List<&2, U32>>}:
  match x y:
    case Some{a} Some{b}: {==}
    case Some{a} None{}: {==}
    case None{} y: {==}

def d2_none(+x: Maybe<&2, Word(6n)>, +y: Maybe<&2, Word(6n)>, +z: Maybe<&2, Word(6n)>, +ok: Bool) -> {B.decode2(x, y, z, None{}, ok) == None{} : Maybe<&2, List<&2, U32>>}:
  match x y z:
    case Some{a} Some{b} Some{c}: {==}
    case Some{a} Some{b} None{}: {==}
    case Some{a} None{} z: {==}
    case None{} y z: {==}

def qv_none(+c: Maybe<&2, Word(6n)>, +d: Maybe<&2, Word(6n)>, +a: Maybe<&2, Word(6n)>, +b: Maybe<&2, Word(6n)>, +pc: Bool, +pd: Bool) -> {B.quartet_values(c, d, a, b, pc, pd, None{}) == None{} : Maybe<&2, List<&2, U32>>}:
  match c d a b:
    case Some{x} Some{y} Some{z} Some{w}: {==}
    case Some{x} Some{y} Some{z} None{}: {==}
    case Some{x} Some{y} None{} b: {==}
    case Some{x} None{} a b: d2_none(a, b, Some{x}, pd)
    case None{} None{} a b: d1_none(a, b, pc && pd)
    case None{} Some{y} a b: {==}

# Strict padded standard decoding stays failed once a group failed.
def none_acc(+s: String) -> {B.decode_go(s, False{}, True{}, None{}) == None{} : Maybe<&2, List<&2, U32>>}:
  match s:
    case SNil{}:
      {==}
    case SCon{a, SNil{}}:
      {==}
    case SCon{a, SCon{b, SNil{}}}:
      %Equal.sym(Maybe<&2, List<&2, U32>>, B.decode1(B.value(a, False{}), B.value(b, False{}), None{}, False{}), None{}, d1_none(B.value(a, False{}), B.value(b, False{}), False{})) : {B.finish(_) == None{} : Maybe<&2, List<&2, U32>>}
      {==}
    case SCon{a, SCon{b, SCon{c, SNil{}}}}:
      %Equal.sym(Maybe<&2, List<&2, U32>>, B.decode2(B.value(a, False{}), B.value(b, False{}), B.value(c, False{}), None{}, False{}), None{}, d2_none(B.value(a, False{}), B.value(b, False{}), B.value(c, False{}), False{})) : {B.finish(_) == None{} : Maybe<&2, List<&2, U32>>}
      {==}
    case SCon{+a, SCon{+b, SCon{+c, SCon{+d, +t}}}}:
      %Equal.sym(Maybe<&2, List<&2, U32>>, B.quartet(a, b, c, d, False{}, True{}, B.empty(t), None{}), None{}, qv_none(B.value(c, False{}), B.value(d, False{}), B.value(a, False{}), B.value(b, False{}), B.empty(t) && Char.is_eq(c, '='), B.empty(t) && Char.is_eq(d, '='))) : {B.decode_go(t, False{}, True{}, _) == None{} : Maybe<&2, List<&2, U32>>}
      none_acc(t)

def dead(-A: Type, +t: String, +out: List<&2, U32>, h: {B.decode_go(t, False{}, True{}, None{}) == Some{out} : Maybe<&2, List<&2, U32>>}) -> A:
  UP.absurd(A, clash(B.decode_go(t, False{}, True{}, None{}), out, none_acc(t), h))

# ---- What a successful decode establishes ----

# The reversed accumulator rev, followed by bytes bs whose canonical
# encoding is the remaining input.
def Sound(s: String, rev: List<&2, U32>, out: List<&2, U32>) -> Type:
  &bs:List<&2, U32> -> ({out == List.reverse.go(&2, U32, rev, bs) : List<&2, U32>} & ({s == Spec.base64(bs) : String} & {OctetsProof.spec(bs) == True{} : Bool}))

# Every decoded group byte is an octet. Word.cmp decides from the top bit.
def octet_le(+w7: Bool, +w6: Bool, +w5: Bool, +w4: Bool, +w3: Bool, +w2: Bool, +w1: Bool, +w0: Bool) -> {(B.octet(WCon{w0, WCon{w1, WCon{w2, WCon{w3, WCon{w4, WCon{w5, WCon{w6, WCon{w7, WNil{}}}}}}}}}) <= 255 : U32) == True{} : Bool}:
  match w7:
    case False{}: {==}
    case True{}:
      match w6:
        case False{}: {==}
        case True{}:
          match w5:
            case False{}: {==}
            case True{}:
              match w4:
                case False{}: {==}
                case True{}:
                  match w3:
                    case False{}: {==}
                    case True{}:
                      match w2:
                        case False{}: {==}
                        case True{}:
                          match w1:
                            case False{}: {==}
                            case True{}:
                              match w0:
                                case False{}: {==}
                                case True{}: {==}

def both(+a: Bool, +b: Bool, ea: {a == True{} : Bool}, eb: {b == True{} : Bool}) -> {a && b == True{} : Bool}:
  %Equal.sym(Bool, a, True{}, ea) : {_ && b == True{} : Bool}
  eb

# A character with a standard value is the RFC 4648 symbol of its bits.
def char_eq(+w0: Bool, +w1: Bool, +w2: Bool, +w3: Bool, +w4: Bool, +w5: Bool, +x: Char, f: {B.symbol(WCon{w0, WCon{w1, WCon{w2, WCon{w3, WCon{w4, WCon{w5, WNil{}}}}}}}, False{}) == x : Char}) -> {x == Spec.sextet(w5, w4, w3, w2, w1, w0) : Char}:
  Equal.trans(Char, x, B.symbol(WCon{w0, WCon{w1, WCon{w2, WCon{w3, WCon{w4, WCon{w5, WNil{}}}}}}}, False{}), Spec.sextet(w5, w4, w3, w2, w1, w0), Equal.sym(Char, B.symbol(WCon{w0, WCon{w1, WCon{w2, WCon{w3, WCon{w4, WCon{w5, WNil{}}}}}}}, False{}), x, f), Format.symbol_spec(w0, w1, w2, w3, w4, w5))

def con4(+a: Char, +b: Char, +c: Char, +d: Char, +t: String, +x: Char, +y: Char, +z: Char, +w: Char, +u: String, ea: {a == x : Char}, eb: {b == y : Char}, ec: {c == z : Char}, ed: {d == w : Char}, et: {t == u : String}) -> {SCon{a, SCon{b, SCon{c, SCon{d, t}}}} == SCon{x, SCon{y, SCon{z, SCon{w, u}}}} : String}:
  Format.con(a, x, SCon{b, SCon{c, SCon{d, t}}}, SCon{y, SCon{z, SCon{w, u}}}, ea, Format.con(b, y, SCon{c, SCon{d, t}}, SCon{z, SCon{w, u}}, eb, Format.con(c, z, SCon{d, t}, SCon{w, u}, ec, Format.con(d, w, t, u, ed, et))))

# Four alphabet characters followed by more input.
def full(+a: Char, +b: Char, +c: Char, +d: Char, +t: String, +rev: List<&2, U32>, +out: List<&2, U32>, +a0: Bool, +a1: Bool, +a2: Bool, +a3: Bool, +a4: Bool, +a5: Bool, +b0: Bool, +b1: Bool, +b2: Bool, +b3: Bool, +b4: Bool, +b5: Bool, +c0: Bool, +c1: Bool, +c2: Bool, +c3: Bool, +c4: Bool, +c5: Bool, +d0: Bool, +d1: Bool, +d2: Bool, +d3: Bool, +d4: Bool, +d5: Bool, fa: {B.symbol(WCon{a0, WCon{a1, WCon{a2, WCon{a3, WCon{a4, WCon{a5, WNil{}}}}}}}, False{}) == a : Char}, fb: {B.symbol(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, False{}) == b : Char}, fc: {B.symbol(WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, False{}) == c : Char}, fd: {B.symbol(WCon{d0, WCon{d1, WCon{d2, WCon{d3, WCon{d4, WCon{d5, WNil{}}}}}}}, False{}) == d : Char}, rest: Sound(t, B.restore3(WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, WCon{d0, WCon{d1, WCon{d2, WCon{d3, WCon{d4, WCon{d5, WNil{}}}}}}}) <> B.restore2(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}) <> B.restore1(WCon{a0, WCon{a1, WCon{a2, WCon{a3, WCon{a4, WCon{a5, WNil{}}}}}}}, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}) <> rev, out)) -> Sound(SCon{a, SCon{b, SCon{c, SCon{d, t}}}}, rev, out):
  match rest:
    case (+bs, (e1, (+e2, e3))):
      +r1 = B.restore1(WCon{a0, WCon{a1, WCon{a2, WCon{a3, WCon{a4, WCon{a5, WNil{}}}}}}}, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}})
      +r2 = B.restore2(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}})
      +r3 = B.restore3(WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, WCon{d0, WCon{d1, WCon{d2, WCon{d3, WCon{d4, WCon{d5, WNil{}}}}}}})
      +enc = con4(a, b, c, d, t, Spec.sextet(a5, a4, a3, a2, a1, a0), Spec.sextet(b5, b4, b3, b2, b1, b0), Spec.sextet(c5, c4, c3, c2, c1, c0), Spec.sextet(d5, d4, d3, d2, d1, d0), Spec.base64(bs), char_eq(a0, a1, a2, a3, a4, a5, a, fa), char_eq(b0, b1, b2, b3, b4, b5, b, fb), char_eq(c0, c1, c2, c3, c4, c5, c, fc), char_eq(d0, d1, d2, d3, d4, d5, d, fd), e2)
      +o1 = octet_le(a5, a4, a3, a2, a1, a0, b5, b4)
      +o2 = octet_le(b3, b2, b1, b0, c5, c4, c3, c2)
      +o3 = octet_le(c1, c0, d5, d4, d3, d2, d1, d0)
      (r1 <> r2 <> r3 <> bs, (e1, (enc, both((r1 <= 255 : U32), OctetsProof.spec(r2 <> r3 <> bs), o1, both((r2 <= 255 : U32), OctetsProof.spec(r3 <> bs), o2, both((r3 <= 255 : U32), OctetsProof.spec(bs), o3, e3))))))

# ---- Padding: two characters and "==", three characters and "=" ----

def pad2e(+a: Char, +b: Char, +c: Char, +d: Char, +rev: List<&2, U32>, +out: List<&2, U32>, e: Bool, ed: {Char.is_eq(d, '=') == e : Bool}, +c0: Bool, +c1: Bool, +a0: Bool, +a1: Bool, +a2: Bool, +a3: Bool, +a4: Bool, +a5: Bool, +b0: Bool, +b1: Bool, +b2: Bool, +b3: Bool, +b4: Bool, +b5: Bool, +c2: Bool, +c3: Bool, +c4: Bool, +c5: Bool, fa: {B.symbol(WCon{a0, WCon{a1, WCon{a2, WCon{a3, WCon{a4, WCon{a5, WNil{}}}}}}}, False{}) == a : Char}, fb: {B.symbol(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, False{}) == b : Char}, fc: {B.symbol(WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, False{}) == c : Char}, h: {B.decode_go("", False{}, True{}, B.accept(B.restore2(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}) <> B.restore1(WCon{a0, WCon{a1, WCon{a2, WCon{a3, WCon{a4, WCon{a5, WNil{}}}}}}}, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}) <> rev, e && U.zero(2n, U.low(2n, 4n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}})))) == Some{out} : Maybe<&2, List<&2, U32>>}) -> Sound(SCon{a, SCon{b, SCon{c, SCon{d, ""}}}}, rev, out):
  match e:
    case False{}:
      UP.absurd(Sound(SCon{a, SCon{b, SCon{c, SCon{d, ""}}}}, rev, out), none_some(out, h))
    case True{}:
      match c0:
        case True{}:
          UP.absurd(Sound(SCon{a, SCon{b, SCon{c, SCon{d, ""}}}}, rev, out), none_some(out, h))
        case False{}:
          match c1:
            case True{}:
              UP.absurd(Sound(SCon{a, SCon{b, SCon{c, SCon{d, ""}}}}, rev, out), none_some(out, h))
            case False{}:
              +r1 = B.restore1(WCon{a0, WCon{a1, WCon{a2, WCon{a3, WCon{a4, WCon{a5, WNil{}}}}}}}, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}})
              +r2 = B.restore2(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, WCon{False{}, WCon{False{}, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}})
              +enc = con4(a, b, c, d, "", Spec.sextet(a5, a4, a3, a2, a1, a0), Spec.sextet(b5, b4, b3, b2, b1, b0), Spec.sextet(c5, c4, c3, c2, False{}, False{}), '=', "", char_eq(a0, a1, a2, a3, a4, a5, a, fa), char_eq(b0, b1, b2, b3, b4, b5, b, fb), char_eq(False{}, False{}, c2, c3, c4, c5, c, fc), char_of(d, ed), {==})
              +o1 = octet_le(a5, a4, a3, a2, a1, a0, b5, b4)
              +o2 = octet_le(b3, b2, b1, b0, c5, c4, c3, c2)
              ([r1, r2], (Equal.sym(List<&2, U32>, List.reverse.go(&2, U32, r2 <> r1 <> rev, []), out, some_inj(List.reverse.go(&2, U32, r2 <> r1 <> rev, []), out, h)), (enc, both((r1 <= 255 : U32), OctetsProof.spec([r2]), o1, both((r2 <= 255 : U32), OctetsProof.spec([]), o2, {==})))))

def pad2(+t: String, +a: Char, +b: Char, +c: Char, +d: Char, +rev: List<&2, U32>, +out: List<&2, U32>, +a0: Bool, +a1: Bool, +a2: Bool, +a3: Bool, +a4: Bool, +a5: Bool, +b0: Bool, +b1: Bool, +b2: Bool, +b3: Bool, +b4: Bool, +b5: Bool, +c0: Bool, +c1: Bool, +c2: Bool, +c3: Bool, +c4: Bool, +c5: Bool, fa: {B.symbol(WCon{a0, WCon{a1, WCon{a2, WCon{a3, WCon{a4, WCon{a5, WNil{}}}}}}}, False{}) == a : Char}, fb: {B.symbol(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, False{}) == b : Char}, fc: {B.symbol(WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, False{}) == c : Char}, h: {B.decode_go(t, False{}, True{}, B.accept(B.restore2(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}) <> B.restore1(WCon{a0, WCon{a1, WCon{a2, WCon{a3, WCon{a4, WCon{a5, WNil{}}}}}}}, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}) <> rev, (B.empty(t) && Char.is_eq(d, '=')) && U.zero(2n, U.low(2n, 4n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}})))) == Some{out} : Maybe<&2, List<&2, U32>>}) -> Sound(SCon{a, SCon{b, SCon{c, SCon{d, t}}}}, rev, out):
  match t:
    case SNil{}:
      pad2e(a, b, c, d, rev, out, Char.is_eq(d, '='), {==}, c0, c1, a0, a1, a2, a3, a4, a5, b0, b1, b2, b3, b4, b5, c2, c3, c4, c5, fa, fb, fc, h)
    case SCon{+x, +y}:
      dead(Sound(SCon{a, SCon{b, SCon{c, SCon{d, SCon{x, y}}}}}, rev, out), SCon{x, y}, out, h)

def pad1e(+a: Char, +b: Char, +c: Char, +d: Char, +rev: List<&2, U32>, +out: List<&2, U32>, e1: Bool, ec: {Char.is_eq(c, '=') == e1 : Bool}, e2: Bool, ed: {Char.is_eq(d, '=') == e2 : Bool}, +b0: Bool, +b1: Bool, +b2: Bool, +b3: Bool, +a0: Bool, +a1: Bool, +a2: Bool, +a3: Bool, +a4: Bool, +a5: Bool, +b4: Bool, +b5: Bool, fa: {B.symbol(WCon{a0, WCon{a1, WCon{a2, WCon{a3, WCon{a4, WCon{a5, WNil{}}}}}}}, False{}) == a : Char}, fb: {B.symbol(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, False{}) == b : Char}, h: {B.decode_go("", False{}, True{}, B.accept(B.restore1(WCon{a0, WCon{a1, WCon{a2, WCon{a3, WCon{a4, WCon{a5, WNil{}}}}}}}, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}) <> rev, (e1 && e2) && U.zero(4n, U.low(4n, 2n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}})))) == Some{out} : Maybe<&2, List<&2, U32>>}) -> Sound(SCon{a, SCon{b, SCon{c, SCon{d, ""}}}}, rev, out):
  match e1:
    case False{}: UP.absurd(Sound(SCon{a, SCon{b, SCon{c, SCon{d, ""}}}}, rev, out), none_some(out, h))
    case True{}:
      match e2:
        case False{}: UP.absurd(Sound(SCon{a, SCon{b, SCon{c, SCon{d, ""}}}}, rev, out), none_some(out, h))
        case True{}:
          match b0:
           case True{}: UP.absurd(Sound(SCon{a, SCon{b, SCon{c, SCon{d, ""}}}}, rev, out), none_some(out, h))
           case False{}:
            match b1:
             case True{}: UP.absurd(Sound(SCon{a, SCon{b, SCon{c, SCon{d, ""}}}}, rev, out), none_some(out, h))
             case False{}:
              match b2:
               case True{}: UP.absurd(Sound(SCon{a, SCon{b, SCon{c, SCon{d, ""}}}}, rev, out), none_some(out, h))
               case False{}:
                match b3:
                 case True{}: UP.absurd(Sound(SCon{a, SCon{b, SCon{c, SCon{d, ""}}}}, rev, out), none_some(out, h))
                 case False{}:
                  +r1 = B.restore1(WCon{a0, WCon{a1, WCon{a2, WCon{a3, WCon{a4, WCon{a5, WNil{}}}}}}}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{b4, WCon{b5, WNil{}}}}}}})
                  +enc = con4(a, b, c, d, "", Spec.sextet(a5, a4, a3, a2, a1, a0), Spec.sextet(b5, b4, False{}, False{}, False{}, False{}), '=', '=', "", char_eq(a0, a1, a2, a3, a4, a5, a, fa), char_eq(False{}, False{}, False{}, False{}, b4, b5, b, fb), char_of(c, ec), char_of(d, ed), {==})
                  +o1 = octet_le(a5, a4, a3, a2, a1, a0, b5, b4)
                  ([r1], (Equal.sym(List<&2, U32>, List.reverse.go(&2, U32, r1 <> rev, []), out, some_inj(List.reverse.go(&2, U32, r1 <> rev, []), out, h)), (enc, both((r1 <= 255 : U32), OctetsProof.spec([]), o1, {==}))))

def pad1(+t: String, +a: Char, +b: Char, +c: Char, +d: Char, +rev: List<&2, U32>, +out: List<&2, U32>, +a0: Bool, +a1: Bool, +a2: Bool, +a3: Bool, +a4: Bool, +a5: Bool, +b0: Bool, +b1: Bool, +b2: Bool, +b3: Bool, +b4: Bool, +b5: Bool, fa: {B.symbol(WCon{a0, WCon{a1, WCon{a2, WCon{a3, WCon{a4, WCon{a5, WNil{}}}}}}}, False{}) == a : Char}, fb: {B.symbol(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, False{}) == b : Char}, h: {B.decode_go(t, False{}, True{}, B.accept(B.restore1(WCon{a0, WCon{a1, WCon{a2, WCon{a3, WCon{a4, WCon{a5, WNil{}}}}}}}, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}) <> rev, ((B.empty(t) && Char.is_eq(c, '=')) && (B.empty(t) && Char.is_eq(d, '='))) && U.zero(4n, U.low(4n, 2n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}})))) == Some{out} : Maybe<&2, List<&2, U32>>}) -> Sound(SCon{a, SCon{b, SCon{c, SCon{d, t}}}}, rev, out):
  match t:
    case SNil{}:
      pad1e(a, b, c, d, rev, out, Char.is_eq(c, '='), {==}, Char.is_eq(d, '='), {==}, b0, b1, b2, b3, a0, a1, a2, a3, a4, a5, b4, b5, fa, fb, h)
    case SCon{+x, +y}:
      dead(Sound(SCon{a, SCon{b, SCon{c, SCon{d, SCon{x, y}}}}}, rev, out), SCon{x, y}, out, h)

# One group of four characters, split on the four character values.
def quad(+a: Char, +b: Char, +c: Char, +d: Char, +t: String, +rev: List<&2, U32>, +out: List<&2, U32>, +mc: Maybe<&2, Word(6n)>, +md: Maybe<&2, Word(6n)>, +ma: Maybe<&2, Word(6n)>, +mb: Maybe<&2, Word(6n)>, fa: Chars.Back(a, ma), fb: Chars.Back(b, mb), fc: Chars.Back(c, mc), fd: Chars.Back(d, md), h: {B.decode_go(t, False{}, True{}, B.quartet_values(mc, md, ma, mb, B.empty(t) && Char.is_eq(c, '='), B.empty(t) && Char.is_eq(d, '='), Some{rev})) == Some{out} : Maybe<&2, List<&2, U32>>}, ih: @r:List<&2, U32> -> @o:List<&2, U32> -> {B.decode_go(t, False{}, True{}, Some{r}) == Some{o} : Maybe<&2, List<&2, U32>>} -> Sound(t, r, o)) -> Sound(SCon{a, SCon{b, SCon{c, SCon{d, t}}}}, rev, out):
  match mc md ma mb:
    case Some{WCon{+c0, WCon{+c1, WCon{+c2, WCon{+c3, WCon{+c4, WCon{+c5, WNil{}}}}}}}} Some{WCon{+d0, WCon{+d1, WCon{+d2, WCon{+d3, WCon{+d4, WCon{+d5, WNil{}}}}}}}} Some{WCon{+a0, WCon{+a1, WCon{+a2, WCon{+a3, WCon{+a4, WCon{+a5, WNil{}}}}}}}} Some{WCon{+b0, WCon{+b1, WCon{+b2, WCon{+b3, WCon{+b4, WCon{+b5, WNil{}}}}}}}}:
      full(a, b, c, d, t, rev, out, a0, a1, a2, a3, a4, a5, b0, b1, b2, b3, b4, b5, c0, c1, c2, c3, c4, c5, d0, d1, d2, d3, d4, d5, fa, fb, fc, fd, ih(B.restore3(WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, WCon{d0, WCon{d1, WCon{d2, WCon{d3, WCon{d4, WCon{d5, WNil{}}}}}}}) <> B.restore2(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}) <> B.restore1(WCon{a0, WCon{a1, WCon{a2, WCon{a3, WCon{a4, WCon{a5, WNil{}}}}}}}, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}) <> rev, out, h))
    case Some{WCon{+c0, WCon{+c1, WCon{+c2, WCon{+c3, WCon{+c4, WCon{+c5, WNil{}}}}}}}} Some{WCon{+d0, WCon{+d1, WCon{+d2, WCon{+d3, WCon{+d4, WCon{+d5, WNil{}}}}}}}} Some{WCon{+a0, WCon{+a1, WCon{+a2, WCon{+a3, WCon{+a4, WCon{+a5, WNil{}}}}}}}} None{}:
      dead(Sound(SCon{a, SCon{b, SCon{c, SCon{d, t}}}}, rev, out), t, out, h)
    case Some{WCon{+c0, WCon{+c1, WCon{+c2, WCon{+c3, WCon{+c4, WCon{+c5, WNil{}}}}}}}} Some{WCon{+d0, WCon{+d1, WCon{+d2, WCon{+d3, WCon{+d4, WCon{+d5, WNil{}}}}}}}} None{} Some{WCon{+b0, WCon{+b1, WCon{+b2, WCon{+b3, WCon{+b4, WCon{+b5, WNil{}}}}}}}}:
      dead(Sound(SCon{a, SCon{b, SCon{c, SCon{d, t}}}}, rev, out), t, out, h)
    case Some{WCon{+c0, WCon{+c1, WCon{+c2, WCon{+c3, WCon{+c4, WCon{+c5, WNil{}}}}}}}} Some{WCon{+d0, WCon{+d1, WCon{+d2, WCon{+d3, WCon{+d4, WCon{+d5, WNil{}}}}}}}} None{} None{}:
      dead(Sound(SCon{a, SCon{b, SCon{c, SCon{d, t}}}}, rev, out), t, out, h)
    case Some{WCon{+c0, WCon{+c1, WCon{+c2, WCon{+c3, WCon{+c4, WCon{+c5, WNil{}}}}}}}} None{} Some{WCon{+a0, WCon{+a1, WCon{+a2, WCon{+a3, WCon{+a4, WCon{+a5, WNil{}}}}}}}} Some{WCon{+b0, WCon{+b1, WCon{+b2, WCon{+b3, WCon{+b4, WCon{+b5, WNil{}}}}}}}}:
      pad2(t, a, b, c, d, rev, out, a0, a1, a2, a3, a4, a5, b0, b1, b2, b3, b4, b5, c0, c1, c2, c3, c4, c5, fa, fb, fc, h)
    case Some{WCon{+c0, WCon{+c1, WCon{+c2, WCon{+c3, WCon{+c4, WCon{+c5, WNil{}}}}}}}} None{} Some{WCon{+a0, WCon{+a1, WCon{+a2, WCon{+a3, WCon{+a4, WCon{+a5, WNil{}}}}}}}} None{}:
      dead(Sound(SCon{a, SCon{b, SCon{c, SCon{d, t}}}}, rev, out), t, out, h)
    case Some{WCon{+c0, WCon{+c1, WCon{+c2, WCon{+c3, WCon{+c4, WCon{+c5, WNil{}}}}}}}} None{} None{} Some{WCon{+b0, WCon{+b1, WCon{+b2, WCon{+b3, WCon{+b4, WCon{+b5, WNil{}}}}}}}}:
      dead(Sound(SCon{a, SCon{b, SCon{c, SCon{d, t}}}}, rev, out), t, out, h)
    case Some{WCon{+c0, WCon{+c1, WCon{+c2, WCon{+c3, WCon{+c4, WCon{+c5, WNil{}}}}}}}} None{} None{} None{}:
      dead(Sound(SCon{a, SCon{b, SCon{c, SCon{d, t}}}}, rev, out), t, out, h)
    case None{} Some{WCon{+d0, WCon{+d1, WCon{+d2, WCon{+d3, WCon{+d4, WCon{+d5, WNil{}}}}}}}} Some{WCon{+a0, WCon{+a1, WCon{+a2, WCon{+a3, WCon{+a4, WCon{+a5, WNil{}}}}}}}} Some{WCon{+b0, WCon{+b1, WCon{+b2, WCon{+b3, WCon{+b4, WCon{+b5, WNil{}}}}}}}}:
      dead(Sound(SCon{a, SCon{b, SCon{c, SCon{d, t}}}}, rev, out), t, out, h)
    case None{} Some{WCon{+d0, WCon{+d1, WCon{+d2, WCon{+d3, WCon{+d4, WCon{+d5, WNil{}}}}}}}} Some{WCon{+a0, WCon{+a1, WCon{+a2, WCon{+a3, WCon{+a4, WCon{+a5, WNil{}}}}}}}} None{}:
      dead(Sound(SCon{a, SCon{b, SCon{c, SCon{d, t}}}}, rev, out), t, out, h)
    case None{} Some{WCon{+d0, WCon{+d1, WCon{+d2, WCon{+d3, WCon{+d4, WCon{+d5, WNil{}}}}}}}} None{} Some{WCon{+b0, WCon{+b1, WCon{+b2, WCon{+b3, WCon{+b4, WCon{+b5, WNil{}}}}}}}}:
      dead(Sound(SCon{a, SCon{b, SCon{c, SCon{d, t}}}}, rev, out), t, out, h)
    case None{} Some{WCon{+d0, WCon{+d1, WCon{+d2, WCon{+d3, WCon{+d4, WCon{+d5, WNil{}}}}}}}} None{} None{}:
      dead(Sound(SCon{a, SCon{b, SCon{c, SCon{d, t}}}}, rev, out), t, out, h)
    case None{} None{} Some{WCon{+a0, WCon{+a1, WCon{+a2, WCon{+a3, WCon{+a4, WCon{+a5, WNil{}}}}}}}} Some{WCon{+b0, WCon{+b1, WCon{+b2, WCon{+b3, WCon{+b4, WCon{+b5, WNil{}}}}}}}}:
      pad1(t, a, b, c, d, rev, out, a0, a1, a2, a3, a4, a5, b0, b1, b2, b3, b4, b5, fa, fb, h)
    case None{} None{} Some{WCon{+a0, WCon{+a1, WCon{+a2, WCon{+a3, WCon{+a4, WCon{+a5, WNil{}}}}}}}} None{}:
      dead(Sound(SCon{a, SCon{b, SCon{c, SCon{d, t}}}}, rev, out), t, out, h)
    case None{} None{} None{} Some{WCon{+b0, WCon{+b1, WCon{+b2, WCon{+b3, WCon{+b4, WCon{+b5, WNil{}}}}}}}}:
      dead(Sound(SCon{a, SCon{b, SCon{c, SCon{d, t}}}}, rev, out), t, out, h)
    case None{} None{} None{} None{}:
      dead(Sound(SCon{a, SCon{b, SCon{c, SCon{d, t}}}}, rev, out), t, out, h)

def sound(+s: String, +rev: List<&2, U32>, +out: List<&2, U32>, h: {B.decode_go(s, False{}, True{}, Some{rev}) == Some{out} : Maybe<&2, List<&2, U32>>}) -> Sound(s, rev, out):
  match s:
    case SNil{}:
      ([], (Equal.sym(List<&2, U32>, List.reverse.go(&2, U32, rev, []), out, some_inj(List.reverse.go(&2, U32, rev, []), out, h)), ({==}, {==})))
    case SCon{a, SNil{}}:
      UP.absurd(Sound(SCon{a, SNil{}}, rev, out), none_some(out, h))
    case SCon{+a, SCon{+b, SNil{}}}:
      UP.absurd(Sound(SCon{a, SCon{b, SNil{}}}, rev, out), clash(B.finish(B.decode1(B.value(a, False{}), B.value(b, False{}), Some{rev}, False{})), out, Equal.cong(Maybe<&2, List<&2, U32>>, Maybe<&2, List<&2, U32>>, m => B.finish(m), B.decode1(B.value(a, False{}), B.value(b, False{}), Some{rev}, False{}), None{}, d1_false(B.value(a, False{}), B.value(b, False{}), Some{rev})), h))
    case SCon{+a, SCon{+b, SCon{+c, SNil{}}}}:
      UP.absurd(Sound(SCon{a, SCon{b, SCon{c, SNil{}}}}, rev, out), clash(B.finish(B.decode2(B.value(a, False{}), B.value(b, False{}), B.value(c, False{}), Some{rev}, False{})), out, Equal.cong(Maybe<&2, List<&2, U32>>, Maybe<&2, List<&2, U32>>, m => B.finish(m), B.decode2(B.value(a, False{}), B.value(b, False{}), B.value(c, False{}), Some{rev}, False{}), None{}, d2_false(B.value(a, False{}), B.value(b, False{}), B.value(c, False{}), Some{rev})), h))
    case SCon{+a, SCon{+b, SCon{+c, SCon{+d, +t}}}}:
      quad(a, b, c, d, t, rev, out, B.value(c, False{}), B.value(d, False{}), B.value(a, False{}), B.value(b, False{}), Chars.chars(a), Chars.chars(b), Chars.chars(c), Chars.chars(d), h, r => o => e => sound(t, r, o, e))

def canonical_of(+s: String, +bytes: List<&2, U32>, r: Sound(s, [], bytes)) -> {s == Spec.base64(bytes) : String} & {O.valid(bytes) == True{} : Bool}:
  match r:
    case (+bs, (e1, (e2, e3))):
      %Equal.sym(List<&2, U32>, bytes, bs, e1) : {s == Spec.base64(_) : String} & {O.valid(_) == True{} : Bool}
      (e2, Equal.trans(Bool, O.valid(bs), True{} && OctetsProof.spec(bs), True{}, OctetsProof.valid_acc(bs, True{}), e3))

# Strict padded standard Base64: a successful decode is the canonical
# encoding of its bytes, and every byte is an octet.
def canonical(+s: String, +bytes: List<&2, U32>, h: {B.decode(s, False{}, True{}) == Some{bytes} : Maybe<&2, List<&2, U32>>}) -> {s == Spec.base64(bytes) : String} & {O.valid(bytes) == True{} : Bool}:
  canonical_of(s, bytes, sound(s, [], bytes, h))
