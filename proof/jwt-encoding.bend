# BND-43: a correctly signed token whose header or payload segment is not
# strict unpadded base64url fails with BadEncoding.
import Base
import ../src/crypto/jwt.bend as J
import ../src/crypto/compare.bend as Compare
import ../src/crypto/hmac.bend as HMAC
import ../src/data/base64.bend as B
import ../src/data/utf8.bend as U
import ./jwt.bend as JwtProof
import ./jwt-spec.bend as Spec
import ./jwt-structure.bend as Structure
import ./base64url-chars.bend as Chars

def absent_of(+c: Char, f: Chars.Facts(c), e: {Spec.url_char(c) == False{} : Bool}) -> {B.value(c, True{}) == None{} : Maybe<&2, Word(6n)>}:
  match f:
    case (x, r):
      x(e)

def spare4_of(+c: Char, f: Chars.Facts(c), e: {Spec.last4(c) == False{} : Bool}) -> {Chars.bad4(B.value(c, True{})) == True{} : Bool}:
  match f:
    case (x, (y, z)):
      y(e)

def spare2_of(+c: Char, f: Chars.Facts(c), e: {Spec.last2(c) == False{} : Bool}) -> {Chars.bad2(B.value(c, True{})) == True{} : Bool}:
  match f:
    case (x, (y, z)):
      z(e)

# A character outside the alphabet has no value.
def absent(+c: Char, e: {Spec.url_char(c) == False{} : Bool}) -> {B.value(c, True{}) == None{} : Maybe<&2, Word(6n)>}:
  absent_of(c, Chars.chars(c), e)

def spare4(+c: Char, e: {Spec.last4(c) == False{} : Bool}) -> {Chars.bad4(B.value(c, True{})) == True{} : Bool}:
  spare4_of(c, Chars.chars(c), e)

def spare2(+c: Char, e: {Spec.last2(c) == False{} : Bool}) -> {Chars.bad2(B.value(c, True{})) == True{} : Bool}:
  spare2_of(c, Chars.chars(c), e)

# ---- Group decoders with a failed group ----

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

def qv_a(+c: Maybe<&2, Word(6n)>, +d: Maybe<&2, Word(6n)>, +b: Maybe<&2, Word(6n)>, +acc: Maybe<&2, List<&2, U32>>) -> {B.quartet_values(c, d, None{}, b, False{}, False{}, acc) == None{} : Maybe<&2, List<&2, U32>>}:
  match c d:
    case Some{x} Some{y}: {==}
    case Some{x} None{}: {==}
    case None{} None{}: {==}
    case None{} Some{y}: {==}

def qv_b(+c: Maybe<&2, Word(6n)>, +d: Maybe<&2, Word(6n)>, +a: Maybe<&2, Word(6n)>, +acc: Maybe<&2, List<&2, U32>>) -> {B.quartet_values(c, d, a, None{}, False{}, False{}, acc) == None{} : Maybe<&2, List<&2, U32>>}:
  match c d a:
    case Some{x} Some{y} Some{z}: {==}
    case Some{x} Some{y} None{}: {==}
    case Some{x} None{} a: d2_false(a, None{}, Some{x}, acc)
    case None{} None{} a: d1_false(a, None{}, acc)
    case None{} Some{y} a: {==}

def qv_c(+d: Maybe<&2, Word(6n)>, +a: Maybe<&2, Word(6n)>, +b: Maybe<&2, Word(6n)>, +acc: Maybe<&2, List<&2, U32>>) -> {B.quartet_values(None{}, d, a, b, False{}, False{}, acc) == None{} : Maybe<&2, List<&2, U32>>}:
  match d:
    case None{}: d1_false(a, b, acc)
    case Some{y}: {==}

def qv_d(+c: Maybe<&2, Word(6n)>, +a: Maybe<&2, Word(6n)>, +b: Maybe<&2, Word(6n)>, +acc: Maybe<&2, List<&2, U32>>) -> {B.quartet_values(c, None{}, a, b, False{}, False{}, acc) == None{} : Maybe<&2, List<&2, U32>>}:
  match c:
    case Some{x}: d2_false(a, b, Some{x}, acc)
    case None{}: d1_false(a, b, acc)

# ---- One bad character fails its group of four ----

def quartet_a(+a: Char, +b: Char, +c: Char, +d: Char, +term: Bool, +acc: Maybe<&2, List<&2, U32>>, e: {Spec.url_char(a) == False{} : Bool}) -> {B.quartet(a, b, c, d, True{}, False{}, term, acc) == None{} : Maybe<&2, List<&2, U32>>}:
  %Equal.sym(Maybe<&2, Word(6n)>, B.value(a, True{}), None{}, absent(a, e)) : {B.quartet_values(B.value(c, True{}), B.value(d, True{}), _, B.value(b, True{}), False{}, False{}, acc) == None{} : Maybe<&2, List<&2, U32>>}
  qv_a(B.value(c, True{}), B.value(d, True{}), B.value(b, True{}), acc)

def quartet_b(+a: Char, +b: Char, +c: Char, +d: Char, +term: Bool, +acc: Maybe<&2, List<&2, U32>>, e: {Spec.url_char(b) == False{} : Bool}) -> {B.quartet(a, b, c, d, True{}, False{}, term, acc) == None{} : Maybe<&2, List<&2, U32>>}:
  %Equal.sym(Maybe<&2, Word(6n)>, B.value(b, True{}), None{}, absent(b, e)) : {B.quartet_values(B.value(c, True{}), B.value(d, True{}), B.value(a, True{}), _, False{}, False{}, acc) == None{} : Maybe<&2, List<&2, U32>>}
  qv_b(B.value(c, True{}), B.value(d, True{}), B.value(a, True{}), acc)

def quartet_c(+a: Char, +b: Char, +c: Char, +d: Char, +term: Bool, +acc: Maybe<&2, List<&2, U32>>, e: {Spec.url_char(c) == False{} : Bool}) -> {B.quartet(a, b, c, d, True{}, False{}, term, acc) == None{} : Maybe<&2, List<&2, U32>>}:
  %Equal.sym(Maybe<&2, Word(6n)>, B.value(c, True{}), None{}, absent(c, e)) : {B.quartet_values(_, B.value(d, True{}), B.value(a, True{}), B.value(b, True{}), False{}, False{}, acc) == None{} : Maybe<&2, List<&2, U32>>}
  qv_c(B.value(d, True{}), B.value(a, True{}), B.value(b, True{}), acc)

def quartet_d(+a: Char, +b: Char, +c: Char, +d: Char, +term: Bool, +acc: Maybe<&2, List<&2, U32>>, e: {Spec.url_char(d) == False{} : Bool}) -> {B.quartet(a, b, c, d, True{}, False{}, term, acc) == None{} : Maybe<&2, List<&2, U32>>}:
  %Equal.sym(Maybe<&2, Word(6n)>, B.value(d, True{}), None{}, absent(d, e)) : {B.quartet_values(B.value(c, True{}), _, B.value(a, True{}), B.value(b, True{}), False{}, False{}, acc) == None{} : Maybe<&2, List<&2, U32>>}
  qv_d(B.value(c, True{}), B.value(a, True{}), B.value(b, True{}), acc)

# ---- A failed accumulator stays failed ----

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

def none_acc(+s: String) -> {B.decode_go(s, True{}, False{}, None{}) == None{} : Maybe<&2, List<&2, U32>>}:
  match s:
    case SNil{}:
      {==}
    case SCon{a, SNil{}}:
      {==}
    case SCon{a, SCon{b, SNil{}}}:
      %Equal.sym(Maybe<&2, List<&2, U32>>, B.decode1(B.value(a, True{}), B.value(b, True{}), None{}, True{}), None{}, d1_none(B.value(a, True{}), B.value(b, True{}), True{})) : {B.finish(_) == None{} : Maybe<&2, List<&2, U32>>}
      {==}
    case SCon{a, SCon{b, SCon{c, SNil{}}}}:
      %Equal.sym(Maybe<&2, List<&2, U32>>, B.decode2(B.value(a, True{}), B.value(b, True{}), B.value(c, True{}), None{}, True{}), None{}, d2_none(B.value(a, True{}), B.value(b, True{}), B.value(c, True{}), True{})) : {B.finish(_) == None{} : Maybe<&2, List<&2, U32>>}
      {==}
    case SCon{+a, SCon{+b, SCon{+c, SCon{+d, +t}}}}:
      %Equal.sym(Maybe<&2, List<&2, U32>>, B.quartet(a, b, c, d, True{}, False{}, B.empty(t), None{}), None{}, qv_none(B.value(c, True{}), B.value(d, True{}), B.value(a, True{}), B.value(b, True{}), False{}, False{})) : {B.decode_go(t, True{}, False{}, _) == None{} : Maybe<&2, List<&2, U32>>}
      none_acc(t)

# ---- Short tails ----

def d1_absent(+x: Maybe<&2, Word(6n)>, +acc: Maybe<&2, List<&2, U32>>, +ok: Bool) -> {B.decode1(x, None{}, acc, ok) == None{} : Maybe<&2, List<&2, U32>>}:
  match x:
    case Some{a}: {==}
    case None{}: {==}

def d2_absent(+x: Maybe<&2, Word(6n)>, +y: Maybe<&2, Word(6n)>, +acc: Maybe<&2, List<&2, U32>>, +ok: Bool) -> {B.decode2(x, y, None{}, acc, ok) == None{} : Maybe<&2, List<&2, U32>>}:
  match x y:
    case Some{a} Some{b}: {==}
    case Some{a} None{}: {==}
    case None{} y: {==}

def tail2(+y: Maybe<&2, Word(6n)>, +x: Maybe<&2, Word(6n)>, +acc: Maybe<&2, List<&2, U32>>, bad: {Chars.bad4(y) == True{} : Bool}) -> {B.decode1(x, y, acc, True{}) == None{} : Maybe<&2, List<&2, U32>>}:
  match y x acc:
    case None{} x acc:
      d1_absent(x, acc, True{})
    case Some{w} None{} acc:
      {==}
    case Some{w} Some{a} None{}:
      {==}
    case Some{+w} Some{+a} Some{+rev}:
      %Equal.sym(Bool, U.zero(4n, U.low(4n, 2n, w)), False{}, Structure.not_true(U.zero(4n, U.low(4n, 2n, w)), bad)) : {B.accept(B.restore1(a, w) <> rev, True{} && _) == None{} : Maybe<&2, List<&2, U32>>}
      {==}

def d2_middle(+x: Maybe<&2, Word(6n)>, +z: Maybe<&2, Word(6n)>, +acc: Maybe<&2, List<&2, U32>>) -> {B.decode2(x, None{}, z, acc, True{}) == None{} : Maybe<&2, List<&2, U32>>}:
  match x:
    case Some{a}: {==}
    case None{}: {==}

def tail3(+z: Maybe<&2, Word(6n)>, +x: Maybe<&2, Word(6n)>, +y: Maybe<&2, Word(6n)>, +acc: Maybe<&2, List<&2, U32>>, bad: {Chars.bad2(z) == True{} : Bool}) -> {B.decode2(x, y, z, acc, True{}) == None{} : Maybe<&2, List<&2, U32>>}:
  match z x y acc:
    case None{} x y acc:
      d2_absent(x, y, acc, True{})
    case Some{w} None{} y acc:
      {==}
    case Some{w} Some{a} None{} acc:
      {==}
    case Some{w} Some{a} Some{b} None{}:
      {==}
    case Some{+w} Some{+a} Some{+b} Some{+rev}:
      %Equal.sym(Bool, U.zero(2n, U.low(2n, 4n, w)), False{}, Structure.not_true(U.zero(2n, U.low(2n, 4n, w)), bad)) : {B.accept(B.restore2(b, w) <> B.restore1(a, b) <> rev, True{} && _) == None{} : Maybe<&2, List<&2, U32>>}
      {==}

def two_a(+a: Char, +b: Char, +acc: Maybe<&2, List<&2, U32>>, +x: Bool, ex: {Spec.url_char(a) == x : Bool}, h: {x && Spec.last4(b) == False{} : Bool}) -> {B.finish(B.decode1(B.value(a, True{}), B.value(b, True{}), acc, True{})) == None{} : Maybe<&2, List<&2, U32>>}:
  match x:
    case False{}:
      %Equal.sym(Maybe<&2, Word(6n)>, B.value(a, True{}), None{}, absent(a, ex)) : {B.finish(B.decode1(_, B.value(b, True{}), acc, True{})) == None{} : Maybe<&2, List<&2, U32>>}
      {==}
    case True{}:
      %Equal.sym(Maybe<&2, List<&2, U32>>, B.decode1(B.value(a, True{}), B.value(b, True{}), acc, True{}), None{}, tail2(B.value(b, True{}), B.value(a, True{}), acc, spare4(b, h))) : {B.finish(_) == None{} : Maybe<&2, List<&2, U32>>}
      {==}

def three_b(+a: Char, +b: Char, +c: Char, +acc: Maybe<&2, List<&2, U32>>, +x: Bool, ex: {Spec.url_char(b) == x : Bool}, h: {x && Spec.last2(c) == False{} : Bool}) -> {B.finish(B.decode2(B.value(a, True{}), B.value(b, True{}), B.value(c, True{}), acc, True{})) == None{} : Maybe<&2, List<&2, U32>>}:
  match x:
    case False{}:
      %Equal.sym(Maybe<&2, Word(6n)>, B.value(b, True{}), None{}, absent(b, ex)) : {B.finish(B.decode2(B.value(a, True{}), _, B.value(c, True{}), acc, True{})) == None{} : Maybe<&2, List<&2, U32>>}
      %Equal.sym(Maybe<&2, List<&2, U32>>, B.decode2(B.value(a, True{}), None{}, B.value(c, True{}), acc, True{}), None{}, d2_middle(B.value(a, True{}), B.value(c, True{}), acc)) : {B.finish(_) == None{} : Maybe<&2, List<&2, U32>>}
      {==}
    case True{}:
      %Equal.sym(Maybe<&2, List<&2, U32>>, B.decode2(B.value(a, True{}), B.value(b, True{}), B.value(c, True{}), acc, True{}), None{}, tail3(B.value(c, True{}), B.value(a, True{}), B.value(b, True{}), acc, spare2(c, h))) : {B.finish(_) == None{} : Maybe<&2, List<&2, U32>>}
      {==}

def three_a(+a: Char, +b: Char, +c: Char, +acc: Maybe<&2, List<&2, U32>>, +x: Bool, ex: {Spec.url_char(a) == x : Bool}, h: {x && Spec.url_char(b) && Spec.last2(c) == False{} : Bool}) -> {B.finish(B.decode2(B.value(a, True{}), B.value(b, True{}), B.value(c, True{}), acc, True{})) == None{} : Maybe<&2, List<&2, U32>>}:
  match x:
    case False{}:
      %Equal.sym(Maybe<&2, Word(6n)>, B.value(a, True{}), None{}, absent(a, ex)) : {B.finish(B.decode2(_, B.value(b, True{}), B.value(c, True{}), acc, True{})) == None{} : Maybe<&2, List<&2, U32>>}
      {==}
    case True{}:
      three_b(a, b, c, acc, Spec.url_char(b), {==}, h)

def four_d(+a: Char, +b: Char, +c: Char, +d: Char, +t: String, +acc: Maybe<&2, List<&2, U32>>, +x: Bool, ex: {Spec.url_char(d) == x : Bool}, h: {x && Spec.base64url(t) == False{} : Bool}, ih: @m:Maybe<&2, List<&2, U32>> -> {Spec.base64url(t) == False{} : Bool} -> {B.decode_go(t, True{}, False{}, m) == None{} : Maybe<&2, List<&2, U32>>}) -> {B.decode_go(t, True{}, False{}, B.quartet(a, b, c, d, True{}, False{}, B.empty(t), acc)) == None{} : Maybe<&2, List<&2, U32>>}:
  match x:
    case False{}:
      %Equal.sym(Maybe<&2, List<&2, U32>>, B.quartet(a, b, c, d, True{}, False{}, B.empty(t), acc), None{}, quartet_d(a, b, c, d, B.empty(t), acc, ex)) : {B.decode_go(t, True{}, False{}, _) == None{} : Maybe<&2, List<&2, U32>>}
      none_acc(t)
    case True{}:
      ih(B.quartet(a, b, c, d, True{}, False{}, B.empty(t), acc), h)

def four_c(+a: Char, +b: Char, +c: Char, +d: Char, +t: String, +acc: Maybe<&2, List<&2, U32>>, +x: Bool, ex: {Spec.url_char(c) == x : Bool}, h: {x && Spec.url_char(d) && Spec.base64url(t) == False{} : Bool}, ih: @m:Maybe<&2, List<&2, U32>> -> {Spec.base64url(t) == False{} : Bool} -> {B.decode_go(t, True{}, False{}, m) == None{} : Maybe<&2, List<&2, U32>>}) -> {B.decode_go(t, True{}, False{}, B.quartet(a, b, c, d, True{}, False{}, B.empty(t), acc)) == None{} : Maybe<&2, List<&2, U32>>}:
  match x:
    case False{}:
      %Equal.sym(Maybe<&2, List<&2, U32>>, B.quartet(a, b, c, d, True{}, False{}, B.empty(t), acc), None{}, quartet_c(a, b, c, d, B.empty(t), acc, ex)) : {B.decode_go(t, True{}, False{}, _) == None{} : Maybe<&2, List<&2, U32>>}
      none_acc(t)
    case True{}:
      four_d(a, b, c, d, t, acc, Spec.url_char(d), {==}, h, ih)

def four_b(+a: Char, +b: Char, +c: Char, +d: Char, +t: String, +acc: Maybe<&2, List<&2, U32>>, +x: Bool, ex: {Spec.url_char(b) == x : Bool}, h: {x && Spec.url_char(c) && Spec.url_char(d) && Spec.base64url(t) == False{} : Bool}, ih: @m:Maybe<&2, List<&2, U32>> -> {Spec.base64url(t) == False{} : Bool} -> {B.decode_go(t, True{}, False{}, m) == None{} : Maybe<&2, List<&2, U32>>}) -> {B.decode_go(t, True{}, False{}, B.quartet(a, b, c, d, True{}, False{}, B.empty(t), acc)) == None{} : Maybe<&2, List<&2, U32>>}:
  match x:
    case False{}:
      %Equal.sym(Maybe<&2, List<&2, U32>>, B.quartet(a, b, c, d, True{}, False{}, B.empty(t), acc), None{}, quartet_b(a, b, c, d, B.empty(t), acc, ex)) : {B.decode_go(t, True{}, False{}, _) == None{} : Maybe<&2, List<&2, U32>>}
      none_acc(t)
    case True{}:
      four_c(a, b, c, d, t, acc, Spec.url_char(c), {==}, h, ih)

def four_a(+a: Char, +b: Char, +c: Char, +d: Char, +t: String, +acc: Maybe<&2, List<&2, U32>>, +x: Bool, ex: {Spec.url_char(a) == x : Bool}, h: {x && Spec.url_char(b) && Spec.url_char(c) && Spec.url_char(d) && Spec.base64url(t) == False{} : Bool}, ih: @m:Maybe<&2, List<&2, U32>> -> {Spec.base64url(t) == False{} : Bool} -> {B.decode_go(t, True{}, False{}, m) == None{} : Maybe<&2, List<&2, U32>>}) -> {B.decode_go(t, True{}, False{}, B.quartet(a, b, c, d, True{}, False{}, B.empty(t), acc)) == None{} : Maybe<&2, List<&2, U32>>}:
  match x:
    case False{}:
      %Equal.sym(Maybe<&2, List<&2, U32>>, B.quartet(a, b, c, d, True{}, False{}, B.empty(t), acc), None{}, quartet_a(a, b, c, d, B.empty(t), acc, ex)) : {B.decode_go(t, True{}, False{}, _) == None{} : Maybe<&2, List<&2, U32>>}
      none_acc(t)
    case True{}:
      four_b(a, b, c, d, t, acc, Spec.url_char(b), {==}, h, ih)

# Strict unpadded base64url decoding fails on every string the independent
# predicate rejects, whatever was decoded before it.
def rejects(+s: String, +acc: Maybe<&2, List<&2, U32>>, h: {Spec.base64url(s) == False{} : Bool}) -> {B.decode_go(s, True{}, False{}, acc) == None{} : Maybe<&2, List<&2, U32>>}:
  match s:
    case SNil{}:
      JwtProof.absurd({B.decode_go("", True{}, False{}, acc) == None{} : Maybe<&2, List<&2, U32>>}, JwtProof.false_true(Equal.sym(Bool, True{}, False{}, h)))
    case SCon{a, SNil{}}:
      {==}
    case SCon{+a, SCon{+b, SNil{}}}:
      two_a(a, b, acc, Spec.url_char(a), {==}, h)
    case SCon{+a, SCon{+b, SCon{+c, SNil{}}}}:
      three_a(a, b, c, acc, Spec.url_char(a), {==}, h)
    case SCon{+a, SCon{+b, SCon{+c, SCon{+d, +t}}}}:
      four_a(a, b, c, d, t, acc, Spec.url_char(a), {==}, h, m => g => rejects(t, m, g))

def decoded_none(+m: Maybe<&2, List<&2, U32>>) -> {J.decoded(m, None{}) == Fail{J.BadEncoding{}} : Result<&2, &2, J.Error, J.Parts>}:
  match m:
    case None{}: {==}
    case Some{h}: {==}

def segments(+a: String, +b: String, +x: Bool, ex: {Spec.base64url(a) == x : Bool}, bad: {x && Spec.base64url(b) == False{} : Bool}) -> {J.decoded(J.decode(a), J.decode(b)) == Fail{J.BadEncoding{}} : Result<&2, &2, J.Error, J.Parts>}:
  match x:
    case False{}:
      %Equal.sym(Maybe<&2, List<&2, U32>>, J.decode(a), None{}, rejects(a, Some{[]}, ex)) : {J.decoded(_, J.decode(b)) == Fail{J.BadEncoding{}} : Result<&2, &2, J.Error, J.Parts>}
      {==}
    case True{}:
      %Equal.sym(Maybe<&2, List<&2, U32>>, J.decode(b), None{}, rejects(b, Some{[]}, bad)) : {J.decoded(J.decode(a), _) == Fail{J.BadEncoding{}} : Result<&2, &2, J.Error, J.Parts>}
      decoded_none(J.decode(a))

# A correctly signed token with a segment that is not strict base64url fails
# with BadEncoding. The signature is checked first, so it must be correct.
def bad_encoding(+secret: List<&2, U32>, +a: String, +b: String, za: {Spec.dots(a) == 0n : Nat}, zb: {Spec.dots(b) == 0n : Nat}, bad: {Spec.base64url(a) && Spec.base64url(b) == False{} : Bool}) -> {J.open(secret, J.token(a, b, J.signature(secret, J.signing_input(a, b)))) == Fail{J.BadEncoding{}} : Result<&2, &2, J.Error, J.Parts>}:
  +s = J.signature(secret, J.signing_input(a, b))
  +rest = b ++ ("." ++ s)
  %Equal.sym(Maybe<&2, J.Cut>, J.split(a ++ ("." ++ rest)), Some{J.Cut{a, rest}}, JwtProof.split_free(a, rest, Structure.dotfree_of(a, za))) : {J.first(secret, _) == Fail{J.BadEncoding{}} : Result<&2, &2, J.Error, J.Parts>}
  %Equal.sym(Maybe<&2, J.Cut>, J.split(rest), Some{J.Cut{b, s}}, JwtProof.split_free(b, s, Structure.dotfree_of(b, zb))) : {J.second(secret, a, _) == Fail{J.BadEncoding{}} : Result<&2, &2, J.Error, J.Parts>}
  %Equal.sym(Bool, J.dotfree(s), True{}, JwtProof.encode_free(HMAC.sha256(secret, U.encode(J.signing_input(a, b))))) : {J.third(secret, a, b, s, _) == Fail{J.BadEncoding{}} : Result<&2, &2, J.Error, J.Parts>}
  %Equal.sym(Bool, Compare.ct_equal(J.codes(s), J.codes(s)), True{}, JwtProof.codes_self(s)) : {J.signed(a, b, _) == Fail{J.BadEncoding{}} : Result<&2, &2, J.Error, J.Parts>}
  segments(a, b, Spec.base64url(a), {==}, bad)
