# Boolean comparison evidence reflects structural equality of route names.
import Base
import ./codec-bits.bend as Bits

def bool_cmp_refl(+b: Bool) -> {Bool.cmp(b, b) == EQ{} : Cmp}:
  match b:
    case False{}:
      {==}
    case True{}:
      {==}

def bool_cmp_sound(+a: Bool, +b: Bool, yes: {Cmp.is_eq(Bool.cmp(a, b)) == True{} : Bool}) -> {a == b : Bool}:
  match a b:
    case False{} False{}:
      {==}
    case True{} True{}:
      {==}
    case False{} True{}:
      Bits.absurd({False{} == True{} : Bool}, Bits.false_true(yes))
    case True{} False{}:
      Bits.absurd({True{} == False{} : Bool}, Bits.false_true(yes))

def fin_head(+c: Cmp, +a: Bool, +b: Bool,
    yes: {Cmp.is_eq(Word.cmp.fin(a, b, c)) == True{} : Bool}) -> {a == b : Bool}:
  match c:
    case EQ{}:
      bool_cmp_sound(a, b, yes)
    case LT{}:
      Bits.absurd({a == b : Bool}, Bits.false_true(yes))
    case GT{}:
      Bits.absurd({a == b : Bool}, Bits.false_true(yes))

def fin_tail(+c: Cmp, +a: Bool, +b: Bool,
    yes: {Cmp.is_eq(Word.cmp.fin(a, b, c)) == True{} : Bool}) -> {Cmp.is_eq(c) == True{} : Bool}:
  match c:
    case EQ{}:
      {==}
    case LT{}:
      Bits.absurd({False{} == True{} : Bool}, Bits.false_true(yes))
    case GT{}:
      Bits.absurd({False{} == True{} : Bool}, Bits.false_true(yes))

law word_cmp_refl:
  for +n: Nat
  for +w: Word(n)
  {Word.cmp(n, w, w) == EQ{} : Cmp}

def word_cmp_refl(n, w):
  match n w:
    case 0n WNil{}:
      {==}
    case 1n+k WCon{+h, +t}:
      %Equal.sym(Cmp, Word.cmp(k, t, t), EQ{}, word_cmp_refl(k, t)) : {Word.cmp.fin(h, h, _) == EQ{} : Cmp}
      bool_cmp_refl(h)

law word_cmp_sound:
  for +n: Nat
  for +a: Word(n)
  for +b: Word(n)
  for yes: {Cmp.is_eq(Word.cmp(n, a, b)) == True{} : Bool}
  {a == b : Word(n)}

def word_cmp_sound(n, a, b, yes):
  match n a b:
    case 0n WNil{} WNil{}:
      {==}
    case 1n+k WCon{+ah, +at} WCon{+bh, +bt}:
      +e = yes
      %Equal.sym(Bool, ah, bh, fin_head(Word.cmp(k, at, bt), ah, bh, e)) : {WCon{_, at} == WCon{bh, bt} : Word(1n+k)}
      Equal.cong(Word(k), Word(1n+k), t => WCon{bh, t}, at, bt, word_cmp_sound(k, at, bt, fin_tail(Word.cmp(k, at, bt), ah, bh, e)))

def u32_cmp_refl(+n: U32) -> {U32.cmp(n, n) == EQ{} : Cmp}:
  match n:
    case U32{+w}:
      word_cmp_refl(32n, w)

def u32_cmp_sound(+a: U32, +b: U32, yes: {Cmp.is_eq(U32.cmp(a, b)) == True{} : Bool}) -> {a == b : U32}:
  match a b:
    case U32{+aw} U32{+bw}:
      Equal.cong(Word(32n), U32, w => U32{w}, aw, bw, word_cmp_sound(32n, aw, bw, yes))

law string_eq_refl:
  for +s: String
  {String.eq(s, s) == True{} : Bool}

def string_eq_refl(s):
  match s:
    case SNil{}:
      {==}
    case SCon{Chr{+n}, +t}:
      %Equal.sym(Cmp, U32.cmp(n, n), EQ{}, u32_cmp_refl(n)) : {Cmp.is_eq(String.order.go(t, t, _)) == True{} : Bool}
      string_eq_refl(t)

def order_cons(+n: U32, +m: U32, +t: String, +u: String,
    evidence: {t == u : String} & {Cmp.is_eq(U32.cmp(n, m)) == True{} : Bool}) ->
    {SCon{Chr{n}, t} == SCon{Chr{m}, u} : String} & {True{} == True{} : Bool}:
  (tail, head) = evidence
  ((
    %Equal.sym(U32, n, m, u32_cmp_sound(n, m, head)) : {SCon{Chr{_}, t} == SCon{Chr{m}, u} : String}
    Equal.cong(String, String, xs => SCon{Chr{m}, xs}, t, u, tail)
  ), {==})

# This helper retains the running-comparison premise needed by String.order.go.
def order_sound(+a: String, +b: String, +c: Cmp,
    yes: {Cmp.is_eq(String.order.go(a, b, c)) == True{} : Bool}) ->
    {a == b : String} & {Cmp.is_eq(c) == True{} : Bool}:
  match a b c:
    case SNil{} SNil{} +o:
      ({==}, yes)
    case SNil{} SCon{h, t} EQ{}:
      Bits.absurd({SNil{} == SCon{h, t} : String} & {True{} == True{} : Bool}, Bits.false_true(yes))
    case SCon{h, t} SNil{} EQ{}:
      Bits.absurd({SCon{h, t} == SNil{} : String} & {True{} == True{} : Bool}, Bits.false_true(yes))
    case SCon{Chr{+n}, +t} SCon{Chr{+m}, +u} EQ{}:
      order_cons(n, m, t, u, order_sound(t, u, U32.cmp(n, m), yes))
    case +left +right LT{}:
      Bits.absurd({left == right : String} & {False{} == True{} : Bool}, Bits.false_true(yes))
    case +left +right GT{}:
      Bits.absurd({left == right : String} & {False{} == True{} : Bool}, Bits.false_true(yes))

law string_eq_sound:
  for +a: String
  for +b: String
  for yes: {String.eq(a, b) == True{} : Bool}
  {a == b : String}

def same_first(+a: String, +b: String, evidence: {a == b : String} & {True{} == True{} : Bool}) -> {a == b : String}:
  (same, comparison) = evidence
  same

def string_eq_sound(a, b, yes):
  same_first(a, b, order_sound(a, b, EQ{}, yes))
