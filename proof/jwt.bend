# BND-43: the JWT signature layer. Sealed tokens open to their octets, and
# any other signature segment is rejected.
import Base
import ../src/crypto/jwt.bend as J
import ../src/crypto/compare.bend as Compare
import ../src/crypto/hmac.bend as HMAC
import ../src/data/base64.bend as B
import ../src/data/utf8.bend as U
import ../src/crypto/octets.bend as O
import ./crypto-base64.bend as Base64Proof
import ./crypto-compare.bend as CompareProof
import ./crypto-compare-spec.bend as Spec
import ./cut-tail.bend as CutTail
import ./text.bend as TextProof

def symbol_dot(+w: Word(6n), +url: Bool) -> {Char.is_eq(B.symbol(w, url), '.') == False{} : Bool}:
  match w:
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      {==}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      match url:
        case False{}:
          {==}
        case True{}:
          {==}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      match url:
        case False{}:
          {==}
        case True{}:
          {==}

def distinguish(b: Bool) -> Type:
  match b:
    case False{}:
      Unit
    case True{}:
      Empty

def false_true(e: {False{} == True{} : Bool}) -> Empty:
  %e : distinguish(_)
  Unit{}

def absurd(-A: Type, e: Empty) -> A:
  match e:

def and_true(+b: Bool) -> {b && True{} == b : Bool}:
  match b:
    case False{}:
      {==}
    case True{}:
      {==}

def and_assoc(+a: Bool, +b: Bool, +c: Bool) -> {(a && b) && c == a && (b && c) : Bool}:
  match a:
    case False{}:
      {==}
    case True{}:
      {==}

def symbol_cons(+w: Word(6n), +url: Bool, +rest: String) -> {J.dotfree_spec(SCon{B.symbol(w, url), rest}) == J.dotfree_spec(rest) : Bool}:
  %Equal.sym(Bool, Char.is_eq(B.symbol(w, url), '.'), False{}, symbol_dot(w, url)) : {Bool.not(_) && J.dotfree_spec(rest) == J.dotfree_spec(rest) : Bool}
  {==}

def append_free(+a: String, +b: String) -> {J.dotfree_spec(a ++ b) == J.dotfree_spec(a) && J.dotfree_spec(b) : Bool}:
  match a:
    case SNil{}:
      {==}
    case SCon{+c, +t}:
      +n = Bool.not(Char.is_eq(c, '.'))
      Equal.trans(Bool, n && J.dotfree_spec(t ++ b), n && (J.dotfree_spec(t) && J.dotfree_spec(b)), (n && J.dotfree_spec(t)) && J.dotfree_spec(b),
        Equal.cong(Bool, Bool, v => n && v, J.dotfree_spec(t ++ b), J.dotfree_spec(t) && J.dotfree_spec(b), append_free(t, b)),
        Equal.sym(Bool, (n && J.dotfree_spec(t)) && J.dotfree_spec(b), n && (J.dotfree_spec(t) && J.dotfree_spec(b)), and_assoc(n, J.dotfree_spec(t), J.dotfree_spec(b))))

def one_free(+a: Word(8n), +url: Bool, +padded: Bool) -> {J.dotfree_spec(B.one(a, url, padded)) == True{} : Bool}:
  match padded:
    case True{}:
      +w1 = U.high(2n, 6n, a)
      +w2 = U.join(4n, 2n, Word.zero(4n), U.low(2n, 6n, a))
      %Equal.sym(Bool, J.dotfree_spec(SCon{B.symbol(w1, url), SCon{B.symbol(w2, url), "=="}}), J.dotfree_spec(SCon{B.symbol(w2, url), "=="}), symbol_cons(w1, url, SCon{B.symbol(w2, url), "=="})) : {_ == True{} : Bool}
      %Equal.sym(Bool, J.dotfree_spec(SCon{B.symbol(w2, url), "=="}), J.dotfree_spec("=="), symbol_cons(w2, url, "==")) : {_ == True{} : Bool}
      {==}
    case False{}:
      +w1 = U.high(2n, 6n, a)
      +w2 = U.join(4n, 2n, Word.zero(4n), U.low(2n, 6n, a))
      %Equal.sym(Bool, J.dotfree_spec(SCon{B.symbol(w1, url), SCon{B.symbol(w2, url), ""}}), J.dotfree_spec(SCon{B.symbol(w2, url), ""}), symbol_cons(w1, url, SCon{B.symbol(w2, url), ""})) : {_ == True{} : Bool}
      %Equal.sym(Bool, J.dotfree_spec(SCon{B.symbol(w2, url), ""}), J.dotfree_spec(""), symbol_cons(w2, url, "")) : {_ == True{} : Bool}
      {==}

def three_free(+w1: Word(6n), +w2: Word(6n), +w3: Word(6n), +url: Bool, +tail: String) -> {J.dotfree_spec(SCon{B.symbol(w1, url), SCon{B.symbol(w2, url), SCon{B.symbol(w3, url), tail}}}) == J.dotfree_spec(tail) : Bool}:
  %Equal.sym(Bool, J.dotfree_spec(SCon{B.symbol(w1, url), SCon{B.symbol(w2, url), SCon{B.symbol(w3, url), tail}}}), J.dotfree_spec(SCon{B.symbol(w2, url), SCon{B.symbol(w3, url), tail}}), symbol_cons(w1, url, SCon{B.symbol(w2, url), SCon{B.symbol(w3, url), tail}})) : {_ == J.dotfree_spec(tail) : Bool}
  %Equal.sym(Bool, J.dotfree_spec(SCon{B.symbol(w2, url), SCon{B.symbol(w3, url), tail}}), J.dotfree_spec(SCon{B.symbol(w3, url), tail}), symbol_cons(w2, url, SCon{B.symbol(w3, url), tail})) : {_ == J.dotfree_spec(tail) : Bool}
  symbol_cons(w3, url, tail)

def two_free(+a: Word(8n), +b: Word(8n), +url: Bool, +padded: Bool) -> {J.dotfree_spec(B.two(a, b, url, padded)) == True{} : Bool}:
  match padded:
    case True{}:
      +w1 = U.high(2n, 6n, a)
      +w2 = U.join(4n, 2n, U.high(4n, 4n, b), U.low(2n, 6n, a))
      +w3 = U.join(2n, 4n, Word.zero(2n), U.low(4n, 4n, b))
      three_free(w1, w2, w3, url, "=")
    case False{}:
      +w1 = U.high(2n, 6n, a)
      +w2 = U.join(4n, 2n, U.high(4n, 4n, b), U.low(2n, 6n, a))
      +w3 = U.join(2n, 4n, Word.zero(2n), U.low(4n, 4n, b))
      three_free(w1, w2, w3, url, "")

def four_free(+a: Word(8n), +b: Word(8n), +c: Word(8n), +url: Bool) -> {J.dotfree_spec(B.three(a, b, c, url)) == True{} : Bool}:
  +w1 = U.high(2n, 6n, a)
  +w2 = U.join(4n, 2n, U.high(4n, 4n, b), U.low(2n, 6n, a))
  +w3 = U.join(2n, 4n, U.high(6n, 2n, c), U.low(4n, 4n, b))
  +w4 = U.low(6n, 2n, c)
  %Equal.sym(Bool, J.dotfree_spec(SCon{B.symbol(w1, url), SCon{B.symbol(w2, url), SCon{B.symbol(w3, url), SCon{B.symbol(w4, url), ""}}}}), J.dotfree_spec(SCon{B.symbol(w4, url), ""}), three_free(w1, w2, w3, url, SCon{B.symbol(w4, url), ""})) : {_ == True{} : Bool}
  symbol_cons(w4, url, "")

def spec_free(+xs: List<&2, U32>, +url: Bool, +padded: Bool) -> {J.dotfree_spec(B.encode_spec(xs, url, padded)) == True{} : Bool}:
  match xs:
    case Nil{}:
      {==}
    case U32{+a} <> Nil{}:
      one_free(U.low(8n, 24n, a), url, padded)
    case U32{+a} <> U32{+b} <> Nil{}:
      two_free(U.low(8n, 24n, a), U.low(8n, 24n, b), url, padded)
    case U32{+a} <> U32{+b} <> U32{+c} <> +t:
      +block = B.three(U.low(8n, 24n, a), U.low(8n, 24n, b), U.low(8n, 24n, c), url)
      %Equal.sym(Bool, J.dotfree_spec(block ++ B.encode_spec(t, url, padded)), J.dotfree_spec(block) && J.dotfree_spec(B.encode_spec(t, url, padded)), append_free(block, B.encode_spec(t, url, padded))) : {_ == True{} : Bool}
      %Equal.sym(Bool, J.dotfree_spec(block), True{}, four_free(U.low(8n, 24n, a), U.low(8n, 24n, b), U.low(8n, 24n, c), url)) : {_ && J.dotfree_spec(B.encode_spec(t, url, padded)) == True{} : Bool}
      spec_free(t, url, padded)

# Every unpadded base64url encoding is free of '.'.
def encode_free_spec(+xs: List<&2, U32>) -> {J.dotfree_spec(J.encode(xs)) == True{} : Bool}:
  %Equal.sym(String, B.encode(xs, True{}, False{}), B.encode_spec(xs, True{}, False{}), Base64Proof.encode_acc(xs, True{}, False{}, "")) : {J.dotfree_spec(_) == True{} : Bool}
  spec_free(xs, True{}, False{})

# J.dotfree folds its verdict into an accumulator (BND-84).
def dotfree_go_equiv(+s: String, +acc: Bool) -> {J.dotfree_go(s, acc) == acc && J.dotfree_spec(s) : Bool}:
  match s:
    case SNil{}:
      match acc:
        case True{}:
          {==}
        case False{}:
          {==}
    case SCon{+c, t}:
      +n = Bool.not(Char.is_eq(c, '.'))
      Equal.trans(Bool, J.dotfree_go(t, acc && n), (acc && n) && J.dotfree_spec(t), acc && (n && J.dotfree_spec(t)), dotfree_go_equiv(t, acc && n), and_assoc(acc, n, J.dotfree_spec(t)))

def dotfree_equiv(+s: String) -> {J.dotfree(s) == J.dotfree_spec(s) : Bool}:
  dotfree_go_equiv(s, True{})

def dotfree_spec_of(+s: String, e: {J.dotfree(s) == True{} : Bool}) -> {J.dotfree_spec(s) == True{} : Bool}:
  Equal.trans(Bool, J.dotfree_spec(s), J.dotfree(s), True{}, Equal.sym(Bool, J.dotfree(s), J.dotfree_spec(s), dotfree_equiv(s)), e)

def encode_free(+xs: List<&2, U32>) -> {J.dotfree(J.encode(xs)) == True{} : Bool}:
  Equal.trans(Bool, J.dotfree(J.encode(xs)), J.dotfree_spec(J.encode(xs)), True{}, dotfree_equiv(J.encode(xs)), encode_free_spec(xs))

def dot_head(+x: Bool, +y: Bool, e: {Bool.not(x) && y == True{} : Bool}) -> {x == False{} : Bool}:
  match x:
    case False{}:
      {==}
    case True{}:
      absurd({True{} == False{} : Bool}, false_true(e))

def dot_tail(+x: Bool, +y: Bool, e: {Bool.not(x) && y == True{} : Bool}) -> {y == True{} : Bool}:
  match x:
    case False{}:
      e
    case True{}:
      absurd({y == True{} : Bool}, false_true(e))

# Splitting a.R at the first '.' recovers a when a has no '.'.
def split_free_spec(+a: String, +r: String, +free: {J.dotfree_spec(a) == True{} : Bool}) -> {J.split_spec(a ++ ("." ++ r)) == Some{J.Cut{a, r}} : Maybe<&2, J.Cut>}:
  match a:
    case SNil{}:
      {==}
    case SCon{+c, +t}:
      +rest = t ++ ("." ++ r)
      %Equal.sym(Bool, Char.is_eq(c, '.'), False{}, dot_head(Char.is_eq(c, '.'), J.dotfree_spec(t), free)) : {J.split_pick(c, rest, J.split_spec(rest), _) == Some{J.Cut{SCon{c, t}, r}} : Maybe<&2, J.Cut>}
      %Equal.sym(Maybe<&2, J.Cut>, J.split_spec(rest), Some{J.Cut{t, r}}, split_free_spec(t, r, dot_tail(Char.is_eq(c, '.'), J.dotfree_spec(t), free))) : {J.prepend(c, _) == Some{J.Cut{SCon{c, t}, r}} : Maybe<&2, J.Cut>}
      {==}

def split_free(+a: String, +r: String, free: {J.dotfree(a) == True{} : Bool}) -> {J.split(a ++ ("." ++ r)) == Some{J.Cut{a, r}} : Maybe<&2, J.Cut>}:
  Equal.trans(Maybe<&2, J.Cut>, J.split(a ++ ("." ++ r)), J.split_spec(a ++ ("." ++ r)), Some{J.Cut{a, r}}, CutTail.J_equiv(a ++ ("." ++ r)), split_free_spec(a, r, dotfree_spec_of(a, free)))

def codes_self(+s: String) -> {Compare.ct_equal(J.codes(s), J.codes(s)) == True{} : Bool}:
  Equal.trans(Bool, Compare.ct_equal(J.codes(s), J.codes(s)), Spec.equal(J.codes(s), J.codes(s)), True{}, CompareProof.ct_equal(J.codes(s), J.codes(s)), CompareProof.equal_self(J.codes(s)))

# Opening a sealed token returns the sealed octets.
def roundtrip(+secret: List<&2, U32>, +h: List<&2, U32>, +p: List<&2, U32>, vh: {O.valid(h) == True{} : Bool}, vp: {O.valid(p) == True{} : Bool}) -> {J.open(secret, J.seal(secret, h, p)) == Done{J.Parts{h, p}} : Result<&2, &2, J.Error, J.Parts>}:
  +a = J.encode(h)
  +b = J.encode(p)
  +s = J.signature(secret, J.signing_input(a, b))
  +rest = b ++ ("." ++ s)
  %Equal.sym(Maybe<&2, J.Cut>, J.split(a ++ ("." ++ rest)), Some{J.Cut{a, rest}}, split_free(a, rest, encode_free(h))) : {J.first(secret, _) == Done{J.Parts{h, p}} : Result<&2, &2, J.Error, J.Parts>}
  %Equal.sym(Maybe<&2, J.Cut>, J.split(rest), Some{J.Cut{b, s}}, split_free(b, s, encode_free(p))) : {J.second(secret, a, _) == Done{J.Parts{h, p}} : Result<&2, &2, J.Error, J.Parts>}
  %Equal.sym(Bool, J.dotfree(s), True{}, encode_free(HMAC.sha256(secret, U.encode(J.signing_input(a, b))))) : {J.third(secret, a, b, s, _) == Done{J.Parts{h, p}} : Result<&2, &2, J.Error, J.Parts>}
  %Equal.sym(Bool, Compare.ct_equal(J.codes(s), J.codes(s)), True{}, codes_self(s)) : {J.signed(a, b, _) == Done{J.Parts{h, p}} : Result<&2, &2, J.Error, J.Parts>}
  %Equal.sym(Maybe<&2, List<&2, U32>>, J.decode(a), Some{h}, Base64Proof.roundtrip(h, True{}, False{}, vh)) : {J.decoded(_, J.decode(b)) == Done{J.Parts{h, p}} : Result<&2, &2, J.Error, J.Parts>}
  %Equal.sym(Maybe<&2, List<&2, U32>>, J.decode(b), Some{p}, Base64Proof.roundtrip(p, True{}, False{}, vp)) : {J.decoded(Some{h}, _) == Done{J.Parts{h, p}} : Result<&2, &2, J.Error, J.Parts>}
  {==}

def and_left(+x: Bool, +y: Bool, e: {x && y == True{} : Bool}) -> {x == True{} : Bool}:
  match x:
    case False{}:
      e
    case True{}:
      {==}

def and_right(+x: Bool, +y: Bool, e: {x && y == True{} : Bool}) -> {y == True{} : Bool}:
  match x:
    case False{}:
      absurd({y == True{} : Bool}, false_true(e))
    case True{}:
      e

def bits_sound(+a: Bool, +b: Bool, e: {Cmp.is_eq(Bool.cmp(a, b)) == True{} : Bool}) -> {a == b : Bool}:
  match a b:
    case False{} False{}:
      {==}
    case False{} True{}:
      absurd({False{} == True{} : Bool}, false_true(e))
    case True{} False{}:
      absurd({True{} == False{} : Bool}, false_true(e))
    case True{} True{}:
      {==}

def word_sound(+n: Nat, +a: Word(n), +b: Word(n), e: {Cmp.is_eq(Word.cmp(n, a, b)) == True{} : Bool}) -> {a == b : Word(n)}:
  match n:
    case 0n:
      match a b:
        case WNil{} WNil{}:
          {==}
    case 1n+p:
      match a b:
        case WCon{+ah, +at} WCon{+bh, +bt}:
          +t = Cmp.is_eq(Word.cmp(p, at, bt))
          +h = Cmp.is_eq(Bool.cmp(ah, bh))
          +both = Equal.trans(Bool, t && h, Cmp.is_eq(Word.cmp.fin(ah, bh, Word.cmp(p, at, bt))), True{}, Equal.sym(Bool, Cmp.is_eq(Word.cmp.fin(ah, bh, Word.cmp(p, at, bt))), t && h, CompareProof.fin_eq(ah, bh, Word.cmp(p, at, bt))), e)
          %bits_sound(ah, bh, and_right(t, h, both)) : {WCon{ah, at} == WCon{_, bt} : Word(1n+p)}
          %word_sound(p, at, bt, and_left(t, h, both)) : {WCon{ah, at} == WCon{ah, _} : Word(1n+p)}
          {==}

def u32_sound(+a: U32, +b: U32, e: {U32.is_eq(a, b) == True{} : Bool}) -> {a == b : U32}:
  match a b:
    case U32{+x} U32{+y}:
      %word_sound(32n, x, y, e) : {U32{x} == U32{_} : U32}
      {==}

# J.codes reverses, then prepends each code point (BND-84).
def codes_reverse(+s: String, +r: String, +acc: List<&2, U32>) -> {J.codes_go(String.reverse.go(s, r), acc) == J.codes_go(r, List.append(&2, U32, J.codes_spec(s), acc)) : List<&2, U32>}:
  match s:
    case SNil{}:
      {==}
    case SCon{Chr{c}, t}:
      codes_reverse(t, SCon{Chr{c}, r}, acc)

def codes_equiv(+s: String) -> {J.codes(s) == J.codes_spec(s) : List<&2, U32>}:
  Equal.trans(List<&2, U32>, J.codes(s), List.append(&2, U32, J.codes_spec(s), []), J.codes_spec(s), codes_reverse(s, "", []), TextProof.list_append_nil(U32, J.codes_spec(s)))

# Equal code-point lists come from equal strings.
def codes_sound_spec(+c: String, +s: String, +e: {Spec.equal(J.codes_spec(c), J.codes_spec(s)) == True{} : Bool}) -> {c == s : String}:
  match c s:
    case SNil{} SNil{}:
      {==}
    case SCon{Chr{+x}, +ct} SCon{Chr{+y}, +st}:
      %u32_sound(x, y, and_left(U32.is_eq(x, y), Spec.equal(J.codes_spec(ct), J.codes_spec(st)), e)) : {SCon{Chr{x}, ct} == SCon{Chr{_}, st} : String}
      %codes_sound_spec(ct, st, and_right(U32.is_eq(x, y), Spec.equal(J.codes_spec(ct), J.codes_spec(st)), e)) : {SCon{Chr{x}, ct} == SCon{Chr{x}, _} : String}
      {==}
    case SCon{Chr{+x}, +ct} SNil{}:
      absurd({SCon{Chr{x}, ct} == SNil{} : String}, false_true(e))
    case SNil{} SCon{Chr{+y}, +st}:
      absurd({SNil{} == SCon{Chr{y}, st} : String}, false_true(e))

def codes_sound(+c: String, +s: String, e: {Spec.equal(J.codes(c), J.codes(s)) == True{} : Bool}) -> {c == s : String}:
  x = Equal.cong(List<&2, U32>, Bool, l => Spec.equal(l, J.codes_spec(s)), J.codes_spec(c), J.codes(c), Equal.sym(List<&2, U32>, J.codes(c), J.codes_spec(c), codes_equiv(c)))
  y = Equal.cong(List<&2, U32>, Bool, l => Spec.equal(J.codes(c), l), J.codes_spec(s), J.codes(s), Equal.sym(List<&2, U32>, J.codes(s), J.codes_spec(s), codes_equiv(s)))
  xy = Equal.trans(Bool, Spec.equal(J.codes_spec(c), J.codes_spec(s)), Spec.equal(J.codes(c), J.codes_spec(s)), Spec.equal(J.codes(c), J.codes(s)), x, y)
  codes_sound_spec(c, s, Equal.trans(Bool, Spec.equal(J.codes_spec(c), J.codes_spec(s)), Spec.equal(J.codes(c), J.codes(s)), True{}, xy, e))

def decide(+c: String, +s: String, +x: Bool, e: {Spec.equal(J.codes(c), J.codes(s)) == x : Bool}, differs: {c != s : String}) -> {Spec.equal(J.codes(c), J.codes(s)) == False{} : Bool}:
  match x:
    case False{}:
      e
    case True{}:
      absurd({Spec.equal(J.codes(c), J.codes(s)) == False{} : Bool}, differs(codes_sound(c, s, e)))

# Any dot-free signature segment other than the HMAC tag's encoding fails.
def rejects(+secret: List<&2, U32>, +a: String, +b: String, +c: String, fa: {J.dotfree(a) == True{} : Bool}, fb: {J.dotfree(b) == True{} : Bool}, fc: {J.dotfree(c) == True{} : Bool}, differs: {c != J.signature(secret, J.signing_input(a, b)) : String}) -> {J.open(secret, J.token(a, b, c)) == Fail{J.BadSignature{}} : Result<&2, &2, J.Error, J.Parts>}:
  +s = J.signature(secret, J.signing_input(a, b))
  +rest = b ++ ("." ++ c)
  %Equal.sym(Maybe<&2, J.Cut>, J.split(a ++ ("." ++ rest)), Some{J.Cut{a, rest}}, split_free(a, rest, fa)) : {J.first(secret, _) == Fail{J.BadSignature{}} : Result<&2, &2, J.Error, J.Parts>}
  %Equal.sym(Maybe<&2, J.Cut>, J.split(rest), Some{J.Cut{b, c}}, split_free(b, c, fb)) : {J.second(secret, a, _) == Fail{J.BadSignature{}} : Result<&2, &2, J.Error, J.Parts>}
  %Equal.sym(Bool, J.dotfree(c), True{}, fc) : {J.third(secret, a, b, c, _) == Fail{J.BadSignature{}} : Result<&2, &2, J.Error, J.Parts>}
  %Equal.sym(Bool, Compare.ct_equal(J.codes(c), J.codes(s)), Spec.equal(J.codes(c), J.codes(s)), CompareProof.ct_equal(J.codes(c), J.codes(s))) : {J.signed(a, b, _) == Fail{J.BadSignature{}} : Result<&2, &2, J.Error, J.Parts>}
  %Equal.sym(Bool, Spec.equal(J.codes(c), J.codes(s)), False{}, decide(c, s, Spec.equal(J.codes(c), J.codes(s)), {==}, differs)) : {J.signed(a, b, _) == Fail{J.BadSignature{}} : Result<&2, &2, J.Error, J.Parts>}
  {==}
