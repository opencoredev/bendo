# Pure supporting lemmas for HTTP field reconstruction.
import Base
import ../LAWS.bend as Laws
import ./support.bend as Support

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

def Laws.and_left(a, b, e):
  match a:
    case False{}:
      e
    case True{}:
      {==}

def Laws.and_right(a, b, e):
  match a:
    case False{}:
      absurd({b == True{} : Bool}, false_true(e))
    case True{}:
      e

def Laws.cmp_fin_tail(a, b, c, e):
  match c:
    case LT{}:
      e
    case EQ{}:
      {==}
    case GT{}:
      e

def Laws.word_cmp_self(n, a):
  match n:
    case 0n:
      {==}
    case 1n+p:
      match a:
        case WCon{False{}, t}:
          %Laws.word_cmp_self(p, t) : {Word.cmp.fin(False{}, False{}, Word.cmp(p, t, t)) == Word.cmp.fin(False{}, False{}, _) : Cmp}
          {==}
        case WCon{True{}, t}:
          %Laws.word_cmp_self(p, t) : {Word.cmp.fin(True{}, True{}, Word.cmp(p, t, t)) == Word.cmp.fin(True{}, True{}, _) : Cmp}
          {==}

def word_head(p: Nat, ah: Bool, bh: Bool, +at: Word(p)) -> {Cmp.is_eq(Bool.cmp(ah, bh)) == True{} : Bool} -> {WCon{ah, at} == WCon{bh, at} : Word(1n+p)}:
  match ah bh:
    case False{} False{}:
      e => {==}
    case False{} True{}:
      e => absurd({WCon{False{}, at} == WCon{True{}, at} : Word(1n+p)}, false_true(e))
    case True{} False{}:
      e => absurd({WCon{True{}, at} == WCon{False{}, at} : Word(1n+p)}, false_true(e))
    case True{} True{}:
      e => {==}

def word_step(+p: Nat, +ah: Bool, +bh: Bool, +at: Word(p), +bt: Word(p), tail: {at == bt : Word(p)}) -> {Cmp.is_eq(Word.cmp.fin(ah, bh, Word.cmp(p, at, bt))) == True{} : Bool} -> {WCon{ah, at} == WCon{bh, bt} : Word(1n+p)}:
  %tail : {Cmp.is_eq(Word.cmp.fin(ah, bh, Word.cmp(p, at, _))) == True{} : Bool} -> {WCon{ah, at} == WCon{bh, _} : Word(1n+p)}
  %Equal.sym(Cmp, Word.cmp(p, at, at), EQ{}, Laws.word_cmp_self(p, at)) : {Cmp.is_eq(Word.cmp.fin(ah, bh, _)) == True{} : Bool} -> {WCon{ah, at} == WCon{bh, at} : Word(1n+p)}
  word_head(p, ah, bh, at)

def Laws.word_eq_sound(n, a, b, e):
  match n:
    case 0n:
      match a b:
        case WNil{} WNil{}:
          {==}
    case 1n+p:
      match a b:
        case WCon{ah, at} WCon{bh, bt}:
          tail = Laws.word_eq_sound(p, at, bt, Laws.cmp_fin_tail(ah, bh, Word.cmp(p, at, bt), e))
          word_step(p, ah, bh, at, bt, tail, e)

def Laws.u32_eq_sound(a, b, e):
  match a b:
    case U32{x} U32{y}:
      Equal.cong(Word(32n), U32, w => U32{w}, x, y, Laws.word_eq_sound(32n, x, y, e))

def Laws.cmp_step_tail(a, b, c, e):
  match a b c:
    case SNil{} SNil{} LT{}:
      e
    case SNil{} SNil{} EQ{}:
      {==}
    case SNil{} SNil{} GT{}:
      e
    case SNil{} SCon{Chr{bh}, bt} LT{}:
      e
    case SNil{} SCon{Chr{bh}, bt} EQ{}:
      {==}
    case SNil{} SCon{Chr{bh}, bt} GT{}:
      e
    case SCon{Chr{ah}, at} SNil{} LT{}:
      e
    case SCon{Chr{ah}, at} SNil{} EQ{}:
      {==}
    case SCon{Chr{ah}, at} SNil{} GT{}:
      e
    case SCon{Chr{ah}, at} SCon{Chr{bh}, bt} LT{}:
      e
    case SCon{Chr{ah}, at} SCon{Chr{bh}, bt} EQ{}:
      {==}
    case SCon{Chr{ah}, at} SCon{Chr{bh}, bt} GT{}:
      e

def cmp_eq_sound(c: Cmp, e: {Cmp.is_eq(c) == True{} : Bool}) -> {c == EQ{} : Cmp}:
  match c:
    case LT{}:
      absurd({LT{} == EQ{} : Cmp}, false_true(e))
    case EQ{}:
      {==}
    case GT{}:
      absurd({GT{} == EQ{} : Cmp}, false_true(e))

# Unlike an equality test, this lemma supplies a rewrite of the strings.
def Laws.string_eq_sound(a, b, e):
  match a b:
    case SNil{} SNil{}:
      {==}
    case SNil{} SCon{h, t}:
      absurd({SNil{} == SCon{h, t} : String}, false_true(e))
    case SCon{h, t} SNil{}:
      absurd({SCon{h, t} == SNil{} : String}, false_true(e))
    case SCon{Chr{x}, at} SCon{Chr{y}, bt}:
      head = Laws.u32_eq_sound(x, y, Laws.cmp_step_tail(at, bt, U32.cmp(x, y), e))
      cmp = cmp_eq_sound(U32.cmp(x, y), Laws.cmp_step_tail(at, bt, U32.cmp(x, y), e))
      tail_e = Equal.trans(Bool, String.eq(at, bt), Cmp.is_eq(String.order.go(at, bt, U32.cmp(x, y))), True{}, Equal.sym(Bool, Cmp.is_eq(String.order.go(at, bt, U32.cmp(x, y))), String.eq(at, bt), Equal.cong(Cmp, Bool, c => Cmp.is_eq(String.order.go(at, bt, c)), U32.cmp(x, y), EQ{}, cmp)), e)
      tail = Laws.string_eq_sound(at, bt, tail_e)
      Equal.trans(String, SCon{Chr{x}, at}, SCon{Chr{y}, at}, SCon{Chr{y}, bt}, Equal.cong(U32, String, c => SCon{Chr{c}, at}, x, y, head), Equal.cong(String, String, t => SCon{Chr{y}, t}, at, bt, tail))
