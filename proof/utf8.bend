# Structural UTF-8 inversion. This helper deliberately does not import LAWS.
import Base
import ../src/data/utf8.bend as U

def append_nil(-A: Data, +xs: List<&2, A>) -> {List.append(&2, A, xs, []) == xs : List<&2, A>}:
  match xs:
    case Nil{}:
      {==}
    case h <> t:
      Equal.cong(List<&2, A>, List<&2, A>, x => h <> x, List.append(&2, A, t, []), t, append_nil(A, t))

def append_assoc(-A: Data, +xs: List<&2, A>, +ys: List<&2, A>, +zs: List<&2, A>) -> {List.append(&2, A, List.append(&2, A, xs, ys), zs) == List.append(&2, A, xs, List.append(&2, A, ys, zs)) : List<&2, A>}:
  match xs:
    case Nil{}:
      {==}
    case h <> t:
      Equal.cong(List<&2, A>, List<&2, A>, x => h <> x, List.append(&2, A, List.append(&2, A, t, ys), zs), List.append(&2, A, t, List.append(&2, A, ys, zs)), append_assoc(A, t, ys, zs))

def encode_reverse(+s: String, +rev: String, +acc: List<&2, U32>) -> {U.encode_go(String.reverse.go(s, rev), acc) == U.encode_go(rev, List.append(&2, U32, U.encode_spec(s), acc)) : List<&2, U32>}:
  match s:
    case SNil{}:
      {==}
    case SCon{Chr{c}, t}:
      %Equal.sym(List<&2, U32>, List.append(&2, U32, List.append(&2, U32, U.encode_char(c), U.encode_spec(t)), acc), List.append(&2, U32, U.encode_char(c), List.append(&2, U32, U.encode_spec(t), acc)), append_assoc(U32, U.encode_char(c), U.encode_spec(t), acc)) : {U.encode_go(String.reverse.go(t, SCon{Chr{c}, rev}), acc) == U.encode_go(rev, _) : List<&2, U32>}
      encode_reverse(t, SCon{Chr{c}, rev}, acc)

def encode_equiv(+s: String) -> {U.encode(s) == U.encode_spec(s) : List<&2, U32>}:
  Equal.trans(List<&2, U32>, U.encode(s), List.append(&2, U32, U.encode_spec(s), []), U.encode_spec(s), encode_reverse(s, "", []), append_nil(U32, U.encode_spec(s)))

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

def and_left(a: Bool, b: Bool, e: {Bool.and(a, b) == True{} : Bool}) -> {a == True{} : Bool}:
  match a:
    case False{}:
      e
    case True{}:
      {==}

def and_right(a: Bool, b: Bool, e: {Bool.and(a, b) == True{} : Bool}) -> {b == True{} : Bool}:
  match a:
    case False{}:
      absurd({b == True{} : Bool}, false_true(e))
    case True{}:
      e

def join_split(+n: Nat, +m: Nat, +w: Word(Nat.add(n, m))) -> {U.join(n, m, U.low(n, m, w), U.high(n, m, w)) == w : Word(Nat.add(n, m))}:
  match n:
    case 0n:
      {==}
    case 1n+p:
      match w:
        case WCon{h, t}:
          Equal.cong(Word(Nat.add(p, m)), Word(Nat.add(1n+p, m)), x => WCon{h, x}, U.join(p, m, U.low(p, m, t), U.high(p, m, t)), t, join_split(p, m, t))

def low_join(+n: Nat, +m: Nat, +a: Word(n), +b: Word(m)) -> {U.low(n, m, U.join(n, m, a, b)) == a : Word(n)}:
  match n:
    case 0n:
      match a:
        case WNil{}:
          {==}
    case 1n+p:
      match a:
        case WCon{h, t}:
          Equal.cong(Word(p), Word(1n+p), x => WCon{h, x}, U.low(p, m, U.join(p, m, t, b)), t, low_join(p, m, t, b))

def high_join(+n: Nat, +m: Nat, +a: Word(n), +b: Word(m)) -> {U.high(n, m, U.join(n, m, a, b)) == b : Word(m)}:
  match n:
    case 0n:
      {==}
    case 1n+p:
      match a:
        case WCon{h, t}:
          high_join(p, m, t, b)

def zero_sound(+n: Nat, +w: Word(n), e: {U.zero(n, w) == True{} : Bool}) -> {w == Word.zero(n) : Word(n)}:
  match n:
    case 0n:
      match w:
        case WNil{}:
          {==}
    case 1n+p:
      match w:
        case WCon{False{}, t}:
          Equal.cong(Word(p), Word(1n+p), x => WCon{False{}, x}, t, Word.zero(p), zero_sound(p, t, e))
        case WCon{True{}, t}:
          absurd({WCon{True{}, t} == Word.zero(1n+p) : Word(1n+p)}, false_true(e))

def zero_self(n: Nat) -> {U.zero(n, Word.zero(n)) == True{} : Bool}:
  match n:
    case 0n:
      {==}
    case 1n+p:
      zero_self(p)

# An upper comparison cannot become non-GT by adding lower bits.
def cmp_le_tail(a: Bool, b: Bool, c: Cmp, e: {Cmp.is_le(Word.cmp.fin(a, b, c)) == True{} : Bool}) -> {Cmp.is_le(c) == True{} : Bool}:
  match c:
    case LT{}:
      {==}
    case EQ{}:
      {==}
    case GT{}:
      e

def high_le(+n: Nat, +m: Nat, +a: Word(Nat.add(n, m)), +b: Word(Nat.add(n, m)), e: {Cmp.is_le(Word.cmp(Nat.add(n, m), a, b)) == True{} : Bool}) -> {Cmp.is_le(Word.cmp(m, U.high(n, m, a), U.high(n, m, b))) == True{} : Bool}:
  match n:
    case 0n:
      e
    case 1n+p:
      match a b:
        case WCon{ah, at} WCon{bh, bt}:
          high_le(p, m, at, bt, cmp_le_tail(ah, bh, Word.cmp(Nat.add(p, m), at, bt), e))

def cmp_zero_self(n: Nat) -> {Word.cmp(n, Word.zero(n), Word.zero(n)) == EQ{} : Cmp}:
  match n:
    case 0n:
      {==}
    case 1n+p:
      %Equal.sym(Cmp, Word.cmp(p, Word.zero(p), Word.zero(p)), EQ{}, cmp_zero_self(p)) : {Word.cmp.fin(False{}, False{}, _) == EQ{} : Cmp}
      {==}

def cmp_zero_head_done(+p: Nat, h: Bool) -> {Cmp.is_le(Bool.cmp(h, False{})) == True{} : Bool} -> {WCon{h, Word.zero(p)} == Word.zero(1n+p) : Word(1n+p)}:
  match h:
    case False{}:
      e => {==}
    case True{}:
      e => absurd({WCon{True{}, Word.zero(p)} == Word.zero(1n+p) : Word(1n+p)}, false_true(e))

def cmp_zero_head(+p: Nat, +h: Bool, +t: Word(p), tail: {t == Word.zero(p) : Word(p)}) -> {Cmp.is_le(Word.cmp.fin(h, False{}, Word.cmp(p, t, Word.zero(p)))) == True{} : Bool} -> {WCon{h, t} == Word.zero(1n+p) : Word(1n+p)}:
  %Equal.sym(Word(p), t, Word.zero(p), tail) : {Cmp.is_le(Word.cmp.fin(h, False{}, Word.cmp(p, _, Word.zero(p)))) == True{} : Bool} -> {WCon{h, _} == Word.zero(1n+p) : Word(1n+p)}
  %Equal.sym(Cmp, Word.cmp(p, Word.zero(p), Word.zero(p)), EQ{}, cmp_zero_self(p)) : {Cmp.is_le(Word.cmp.fin(h, False{}, _)) == True{} : Bool} -> {WCon{h, Word.zero(p)} == Word.zero(1n+p) : Word(1n+p)}
  cmp_zero_head_done(p, h)

def cmp_le_zero(+n: Nat, +w: Word(n), +e: {Cmp.is_le(Word.cmp(n, w, Word.zero(n))) == True{} : Bool}) -> {w == Word.zero(n) : Word(n)}:
  match n:
    case 0n:
      match w:
        case WNil{}:
          {==}
    case 1n+p:
      match w:
        case WCon{h, t}:
          tail = cmp_le_zero(p, t, cmp_le_tail(h, False{}, Word.cmp(p, t, Word.zero(p)), e))
          cmp_zero_head(p, h, t, tail, e)

def walk(xs: List<&2, U32>, s: U.State) -> U.State:
  match xs:
    case Nil{}:
      s
    case h <> t:
      walk(t, U.advance(s, U.byte_view(h)))

def walk_bad(+xs: List<&2, U32>) -> {walk(xs, U.Bad{}) == U.Bad{} : U.State}:
  match xs:
    case Nil{}:
      {==}
    case h <> t:
      walk_bad(t)

def decode_bad(+xs: List<&2, U32>) -> {U.decode_go(xs, U.Bad{}) == None{} : Maybe<&2, String>}:
  match xs:
    case Nil{}:
      {==}
    case h <> t:
      {==}

def decode_append(+a: List<&2, U32>, +b: List<&2, U32>, +s: U.State) -> {U.decode_go(List.append(&2, U32, a, b), s) == U.decode_go(b, walk(a, s)) : Maybe<&2, String>}:
  match a s:
    case Nil{} st:
      {==}
    case h <> t U.Bad{}:
      %Equal.sym(U.State, walk(h <> t, U.Bad{}), U.Bad{}, walk_bad(h <> t)) : {None{} == U.decode_go(b, _) : Maybe<&2, String>}
      Equal.sym(Maybe<&2, String>, U.decode_go(b, U.Bad{}), None{}, decode_bad(b))
    case h <> t U.UtfReady{rev}:
      decode_append(t, b, U.advance(U.UtfReady{rev}, U.byte_view(h)))
    case h <> t U.Need2{a, rev}:
      decode_append(t, b, U.advance(U.Need2{a, rev}, U.byte_view(h)))
    case h <> t U.Need3{a, rev}:
      decode_append(t, b, U.advance(U.Need3{a, rev}, U.byte_view(h)))
    case h <> t U.Need3Tail{a, c, rev}:
      decode_append(t, b, U.advance(U.Need3Tail{a, c, rev}, U.byte_view(h)))
    case h <> t U.Need4{a, rev}:
      decode_append(t, b, U.advance(U.Need4{a, rev}, U.byte_view(h)))
    case h <> t U.Need4Mid{a, c, rev}:
      decode_append(t, b, U.advance(U.Need4Mid{a, c, rev}, U.byte_view(h)))
    case h <> t U.Need4Tail{a, c, d, rev}:
      decode_append(t, b, U.advance(U.Need4Tail{a, c, d, rev}, U.byte_view(h)))

def bits(c: U32) -> Word(32n):
  match c:
    case U32{w}:
      w

def fits(+w: Word(32n), ok: {U.scalar(U32{w}) == True{} : Bool}) -> {U.zero(11n, U.high(21n, 11n, w)) == True{} : Bool}:
  bound = and_left((U32{w} <= 1114111 : U32), Bool.not((U32{w} >= 55296 : U32) && (U32{w} <= 57343 : U32)), ok)
  upper = cmp_le_zero(11n, U.high(21n, 11n, w), high_le(21n, 11n, w, bits(1114111), bound))
  Equal.trans(Bool, U.zero(11n, U.high(21n, 11n, w)), U.zero(11n, Word.zero(11n)), True{}, Equal.cong(Word(11n), Bool, x => U.zero(11n, x), U.high(21n, 11n, w), Word.zero(11n), upper), zero_self(11n))

def pad_reconstruct(+n: Nat, +m: Nat, +w: Word(Nat.add(n, m)), e: {U.high(n, m, w) == Word.zero(m) : Word(m)}) -> {U.join(n, m, U.low(n, m, w), Word.zero(m)) == w : Word(Nat.add(n, m))}:
  %e : {U.join(n, m, U.low(n, m, w), _) == w : Word(Nat.add(n, m))}
  join_split(n, m, w)

def step7(+w: Word(7n), +rev: String, ok: {U.scalar(U32{U.join(7n, 25n, w, Word.zero(25n))}) == True{} : Bool}) -> {walk(U.encode7(w), U.UtfReady{rev}) == U.UtfReady{SCon{Chr{U32{U.join(7n, 25n, w, Word.zero(25n))}}, rev}} : U.State}:
  match w:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WNil{}}}}}}}}:
      %Equal.sym(Bool, U.scalar(U32{U.join(7n, 25n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WNil{}}}}}}}}, Word.zero(25n))}), True{}, ok) : {U.finish(U32{U.join(7n, 25n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WNil{}}}}}}}}, Word.zero(25n))}, rev, _) == U.UtfReady{SCon{Chr{U32{U.join(7n, 25n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WNil{}}}}}}}}, Word.zero(25n))}}, rev}} : U.State}
      {==}

def complete11_ok(+w: Word(11n), +rev: String, small: {U.zero(4n, U.high(7n, 4n, w)) == False{} : Bool}) -> {U.scalar(U32{U.join(11n, 21n, w, Word.zero(21n))}) == True{} : Bool} -> {U.complete11(w, rev) == U.UtfReady{SCon{Chr{U32{U.join(11n, 21n, w, Word.zero(21n))}}, rev}} : U.State}:
  %Equal.sym(Bool, U.zero(4n, U.high(7n, 4n, w)), False{}, small) : {U.scalar(U32{U.join(11n, 21n, w, Word.zero(21n))}) == True{} : Bool} -> {U.finish(U32{U.join(11n, 21n, w, Word.zero(21n))}, rev, Bool.not(_) && U.scalar(U32{U.join(11n, 21n, w, Word.zero(21n))})) == U.UtfReady{SCon{Chr{U32{U.join(11n, 21n, w, Word.zero(21n))}}, rev}} : U.State}
  ok => Equal.cong(Bool, U.State, b => U.finish(U32{U.join(11n, 21n, w, Word.zero(21n))}, rev, b), U.scalar(U32{U.join(11n, 21n, w, Word.zero(21n))}), True{}, ok)

def step11_large(+w: Word(11n), +rev: String, small: {U.zero(4n, U.high(7n, 4n, w)) == False{} : Bool}, ok: {U.scalar(U32{U.join(11n, 21n, w, Word.zero(21n))}) == True{} : Bool}) -> {walk(U.encode11_go(w, False{}), U.UtfReady{rev}) == U.UtfReady{SCon{Chr{U32{U.join(11n, 21n, w, Word.zero(21n))}}, rev}} : U.State}:
  match w:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WNil{}}}}}}}}}}}}:
      complete11_ok(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WNil{}}}}}}}}}}}}, rev, small, ok)

def step11_padded(+a: Word(7n), +rev: String, ok: {U.scalar(U32{U.join(11n, 21n, U.join(7n, 4n, a, Word.zero(4n)), Word.zero(21n))}) == True{} : Bool}) -> {walk(U.encode11_go(U.join(7n, 4n, a, Word.zero(4n)), True{}), U.UtfReady{rev}) == U.UtfReady{SCon{Chr{U32{U.join(11n, 21n, U.join(7n, 4n, a, Word.zero(4n)), Word.zero(21n))}}, rev}} : U.State}:
  match a:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WNil{}}}}}}}}:
      step7(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WNil{}}}}}}}}, rev, ok)

def step11_small(+w: Word(11n), +rev: String, small: {U.high(7n, 4n, w) == Word.zero(4n) : Word(4n)}) -> {U.scalar(U32{U.join(11n, 21n, w, Word.zero(21n))}) == True{} : Bool} -> {walk(U.encode11_go(w, True{}), U.UtfReady{rev}) == U.UtfReady{SCon{Chr{U32{U.join(11n, 21n, w, Word.zero(21n))}}, rev}} : U.State}:
  %pad_reconstruct(7n, 4n, w, small) : {U.scalar(U32{U.join(11n, 21n, _, Word.zero(21n))}) == True{} : Bool} -> {walk(U.encode11_go(_, True{}), U.UtfReady{rev}) == U.UtfReady{SCon{Chr{U32{U.join(11n, 21n, _, Word.zero(21n))}}, rev}} : U.State}
  ok => step11_padded(U.low(7n, 4n, w), rev, ok)

def step11_go(+w: Word(11n), +rev: String, small: Bool) -> {U.zero(4n, U.high(7n, 4n, w)) == small : Bool} -> {U.scalar(U32{U.join(11n, 21n, w, Word.zero(21n))}) == True{} : Bool} -> {walk(U.encode11_go(w, small), U.UtfReady{rev}) == U.UtfReady{SCon{Chr{U32{U.join(11n, 21n, w, Word.zero(21n))}}, rev}} : U.State}:
  match small:
    case False{}:
      e => ok => step11_large(w, rev, e, ok)
    case True{}:
      e => step11_small(w, rev, zero_sound(4n, U.high(7n, 4n, w), e))

def step11(+w: Word(11n), +rev: String, ok: {U.scalar(U32{U.join(11n, 21n, w, Word.zero(21n))}) == True{} : Bool}) -> {walk(U.encode11(w), U.UtfReady{rev}) == U.UtfReady{SCon{Chr{U32{U.join(11n, 21n, w, Word.zero(21n))}}, rev}} : U.State}:
  step11_go(w, rev, U.zero(4n, U.high(7n, 4n, w)), {==}, ok)

def complete16_ok(+w: Word(16n), +rev: String, small: {U.zero(5n, U.high(11n, 5n, w)) == False{} : Bool}) -> {U.scalar(U32{U.join(16n, 16n, w, Word.zero(16n))}) == True{} : Bool} -> {U.complete16(w, rev) == U.UtfReady{SCon{Chr{U32{U.join(16n, 16n, w, Word.zero(16n))}}, rev}} : U.State}:
  %Equal.sym(Bool, U.zero(5n, U.high(11n, 5n, w)), False{}, small) : {U.scalar(U32{U.join(16n, 16n, w, Word.zero(16n))}) == True{} : Bool} -> {U.finish(U32{U.join(16n, 16n, w, Word.zero(16n))}, rev, Bool.not(_) && U.scalar(U32{U.join(16n, 16n, w, Word.zero(16n))})) == U.UtfReady{SCon{Chr{U32{U.join(16n, 16n, w, Word.zero(16n))}}, rev}} : U.State}
  ok => Equal.cong(Bool, U.State, b => U.finish(U32{U.join(16n, 16n, w, Word.zero(16n))}, rev, b), U.scalar(U32{U.join(16n, 16n, w, Word.zero(16n))}), True{}, ok)

def step16_large(+w: Word(16n), +rev: String, small: {U.zero(5n, U.high(11n, 5n, w)) == False{} : Bool}, ok: {U.scalar(U32{U.join(16n, 16n, w, Word.zero(16n))}) == True{} : Bool}) -> {walk(U.encode16_go(w, False{}), U.UtfReady{rev}) == U.UtfReady{SCon{Chr{U32{U.join(16n, 16n, w, Word.zero(16n))}}, rev}} : U.State}:
  match w:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WNil{}}}}}}}}}}}}}}}}}:
      complete16_ok(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WNil{}}}}}}}}}}}}}}}}}, rev, small, ok)

def step16_padded(+a: Word(11n), +rev: String, ok: {U.scalar(U32{U.join(16n, 16n, U.join(11n, 5n, a, Word.zero(5n)), Word.zero(16n))}) == True{} : Bool}) -> {walk(U.encode16_go(U.join(11n, 5n, a, Word.zero(5n)), True{}), U.UtfReady{rev}) == U.UtfReady{SCon{Chr{U32{U.join(16n, 16n, U.join(11n, 5n, a, Word.zero(5n)), Word.zero(16n))}}, rev}} : U.State}:
  match a:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WNil{}}}}}}}}}}}}:
      step11(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WNil{}}}}}}}}}}}}, rev, ok)

def step16_small(+w: Word(16n), +rev: String, small: {U.high(11n, 5n, w) == Word.zero(5n) : Word(5n)}) -> {U.scalar(U32{U.join(16n, 16n, w, Word.zero(16n))}) == True{} : Bool} -> {walk(U.encode16_go(w, True{}), U.UtfReady{rev}) == U.UtfReady{SCon{Chr{U32{U.join(16n, 16n, w, Word.zero(16n))}}, rev}} : U.State}:
  %pad_reconstruct(11n, 5n, w, small) : {U.scalar(U32{U.join(16n, 16n, _, Word.zero(16n))}) == True{} : Bool} -> {walk(U.encode16_go(_, True{}), U.UtfReady{rev}) == U.UtfReady{SCon{Chr{U32{U.join(16n, 16n, _, Word.zero(16n))}}, rev}} : U.State}
  ok => step16_padded(U.low(11n, 5n, w), rev, ok)

def step16_go(+w: Word(16n), +rev: String, small: Bool) -> {U.zero(5n, U.high(11n, 5n, w)) == small : Bool} -> {U.scalar(U32{U.join(16n, 16n, w, Word.zero(16n))}) == True{} : Bool} -> {walk(U.encode16_go(w, small), U.UtfReady{rev}) == U.UtfReady{SCon{Chr{U32{U.join(16n, 16n, w, Word.zero(16n))}}, rev}} : U.State}:
  match small:
    case False{}:
      e => ok => step16_large(w, rev, e, ok)
    case True{}:
      e => step16_small(w, rev, zero_sound(5n, U.high(11n, 5n, w), e))

def step16(+w: Word(16n), +rev: String, ok: {U.scalar(U32{U.join(16n, 16n, w, Word.zero(16n))}) == True{} : Bool}) -> {walk(U.encode16(w), U.UtfReady{rev}) == U.UtfReady{SCon{Chr{U32{U.join(16n, 16n, w, Word.zero(16n))}}, rev}} : U.State}:
  step16_go(w, rev, U.zero(5n, U.high(11n, 5n, w)), {==}, ok)

def complete21_ok(+w: Word(21n), +rev: String, small: {U.zero(5n, U.high(16n, 5n, w)) == False{} : Bool}) -> {U.scalar(U32{U.join(21n, 11n, w, Word.zero(11n))}) == True{} : Bool} -> {U.complete21(w, rev) == U.UtfReady{SCon{Chr{U32{U.join(21n, 11n, w, Word.zero(11n))}}, rev}} : U.State}:
  %Equal.sym(Bool, U.zero(5n, U.high(16n, 5n, w)), False{}, small) : {U.scalar(U32{U.join(21n, 11n, w, Word.zero(11n))}) == True{} : Bool} -> {U.finish(U32{U.join(21n, 11n, w, Word.zero(11n))}, rev, Bool.not(_) && U.scalar(U32{U.join(21n, 11n, w, Word.zero(11n))})) == U.UtfReady{SCon{Chr{U32{U.join(21n, 11n, w, Word.zero(11n))}}, rev}} : U.State}
  ok => Equal.cong(Bool, U.State, b => U.finish(U32{U.join(21n, 11n, w, Word.zero(11n))}, rev, b), U.scalar(U32{U.join(21n, 11n, w, Word.zero(11n))}), True{}, ok)

def step21_large(+w: Word(21n), +rev: String, small: {U.zero(5n, U.high(16n, 5n, w)) == False{} : Bool}, ok: {U.scalar(U32{U.join(21n, 11n, w, Word.zero(11n))}) == True{} : Bool}) -> {walk(U.encode21_go(w, False{}), U.UtfReady{rev}) == U.UtfReady{SCon{Chr{U32{U.join(21n, 11n, w, Word.zero(11n))}}, rev}} : U.State}:
  match w:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WNil{}}}}}}}}}}}}}}}}}}}}}}:
      complete21_ok(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WNil{}}}}}}}}}}}}}}}}}}}}}}, rev, small, ok)

def step21_padded(+a: Word(16n), +rev: String, ok: {U.scalar(U32{U.join(21n, 11n, U.join(16n, 5n, a, Word.zero(5n)), Word.zero(11n))}) == True{} : Bool}) -> {walk(U.encode21_go(U.join(16n, 5n, a, Word.zero(5n)), True{}), U.UtfReady{rev}) == U.UtfReady{SCon{Chr{U32{U.join(21n, 11n, U.join(16n, 5n, a, Word.zero(5n)), Word.zero(11n))}}, rev}} : U.State}:
  match a:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WNil{}}}}}}}}}}}}}}}}}:
      step16(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WNil{}}}}}}}}}}}}}}}}}, rev, ok)

def step21_small(+w: Word(21n), +rev: String, small: {U.high(16n, 5n, w) == Word.zero(5n) : Word(5n)}) -> {U.scalar(U32{U.join(21n, 11n, w, Word.zero(11n))}) == True{} : Bool} -> {walk(U.encode21_go(w, True{}), U.UtfReady{rev}) == U.UtfReady{SCon{Chr{U32{U.join(21n, 11n, w, Word.zero(11n))}}, rev}} : U.State}:
  %pad_reconstruct(16n, 5n, w, small) : {U.scalar(U32{U.join(21n, 11n, _, Word.zero(11n))}) == True{} : Bool} -> {walk(U.encode21_go(_, True{}), U.UtfReady{rev}) == U.UtfReady{SCon{Chr{U32{U.join(21n, 11n, _, Word.zero(11n))}}, rev}} : U.State}
  ok => step21_padded(U.low(16n, 5n, w), rev, ok)

def step21_go(+w: Word(21n), +rev: String, small: Bool) -> {U.zero(5n, U.high(16n, 5n, w)) == small : Bool} -> {U.scalar(U32{U.join(21n, 11n, w, Word.zero(11n))}) == True{} : Bool} -> {walk(U.encode21_go(w, small), U.UtfReady{rev}) == U.UtfReady{SCon{Chr{U32{U.join(21n, 11n, w, Word.zero(11n))}}, rev}} : U.State}:
  match small:
    case False{}:
      e => ok => step21_large(w, rev, e, ok)
    case True{}:
      e => step21_small(w, rev, zero_sound(5n, U.high(16n, 5n, w), e))

def step21(+w: Word(21n), +rev: String, ok: {U.scalar(U32{U.join(21n, 11n, w, Word.zero(11n))}) == True{} : Bool}) -> {walk(U.encode21(w), U.UtfReady{rev}) == U.UtfReady{SCon{Chr{U32{U.join(21n, 11n, w, Word.zero(11n))}}, rev}} : U.State}:
  step21_go(w, rev, U.zero(5n, U.high(16n, 5n, w)), {==}, ok)

# ---- BND-68: the ASCII fast path equals the bit-level encoder ----

def zcmp(z: Bool) -> Cmp:
  match z:
    case True{}:
      EQ{}
    case False{}:
      GT{}

def fin_low_zcmp(+z: Bool) -> {Word.cmp.fin(False{}, False{}, zcmp(z)) == zcmp(z) : Cmp}:
  match z:
    case True{}:
      {==}
    case False{}:
      {==}

def fin_high_zcmp(+z: Bool) -> {Word.cmp.fin(True{}, False{}, zcmp(z)) == GT{} : Cmp}:
  match z:
    case True{}:
      {==}
    case False{}:
      {==}

# Comparing with zero is EQ exactly for the zero word, and GT otherwise.
def cmp_zero(+n: Nat, +w: Word(n)) -> {Word.cmp(n, w, Word.zero(n)) == zcmp(U.zero(n, w)) : Cmp}:
  match n:
    case 0n:
      match w:
        case WNil{}:
          {==}
    case 1n+p:
      match w:
        case WCon{False{}, t}:
          Equal.trans(Cmp, Word.cmp.fin(False{}, False{}, Word.cmp(p, t, Word.zero(p))), Word.cmp.fin(False{}, False{}, zcmp(U.zero(p, t))), zcmp(U.zero(p, t)), Equal.cong(Cmp, Cmp, x => Word.cmp.fin(False{}, False{}, x), Word.cmp(p, t, Word.zero(p)), zcmp(U.zero(p, t)), cmp_zero(p, t)), fin_low_zcmp(U.zero(p, t)))
        case WCon{True{}, t}:
          Equal.trans(Cmp, Word.cmp.fin(True{}, False{}, Word.cmp(p, t, Word.zero(p))), Word.cmp.fin(True{}, False{}, zcmp(U.zero(p, t))), GT{}, Equal.cong(Cmp, Cmp, x => Word.cmp.fin(True{}, False{}, x), Word.cmp(p, t, Word.zero(p)), zcmp(U.zero(p, t)), cmp_zero(p, t)), fin_high_zcmp(U.zero(p, t)))

# A clear low bit of the bound leaves the less-than verdict to the higher bits.
def lt_fin_low(+b: Bool, +t: Cmp) -> {Cmp.is_lt(Word.cmp.fin(b, False{}, t)) == Cmp.is_lt(t) : Bool}:
  match b t:
    case _ LT{}:
      {==}
    case True{} EQ{}:
      {==}
    case False{} EQ{}:
      {==}
    case _ GT{}:
      {==}

def lt_bit7_false(+z: Bool) -> {Cmp.is_lt(Word.cmp.fin(False{}, True{}, zcmp(z))) == z : Bool}:
  match z:
    case True{}:
      {==}
    case False{}:
      {==}

def lt_bit7_true(+z: Bool) -> {Cmp.is_lt(Word.cmp.fin(True{}, True{}, zcmp(z))) == False{} : Bool}:
  match z:
    case True{}:
      {==}
    case False{}:
      {==}

# Below 128 exactly when bits 7 to 31 are zero, for the 25 high bits r.
def lt_bit7(+r: Word(25n)) -> {Cmp.is_lt(Word.cmp(25n, r, WCon{True{}, Word.zero(24n)})) == U.zero(25n, r) : Bool}:
  match r:
    case WCon{False{}, t}:
      Equal.trans(Bool, Cmp.is_lt(Word.cmp.fin(False{}, True{}, Word.cmp(24n, t, Word.zero(24n)))), Cmp.is_lt(Word.cmp.fin(False{}, True{}, zcmp(U.zero(24n, t)))), U.zero(24n, t), Equal.cong(Cmp, Bool, x => Cmp.is_lt(Word.cmp.fin(False{}, True{}, x)), Word.cmp(24n, t, Word.zero(24n)), zcmp(U.zero(24n, t)), cmp_zero(24n, t)), lt_bit7_false(U.zero(24n, t)))
    case WCon{True{}, t}:
      Equal.trans(Bool, Cmp.is_lt(Word.cmp.fin(True{}, True{}, Word.cmp(24n, t, Word.zero(24n)))), Cmp.is_lt(Word.cmp.fin(True{}, True{}, zcmp(U.zero(24n, t)))), False{}, Equal.cong(Cmp, Bool, x => Cmp.is_lt(Word.cmp.fin(True{}, True{}, x)), Word.cmp(24n, t, Word.zero(24n)), zcmp(U.zero(24n, t)), cmp_zero(24n, t)), lt_bit7_true(U.zero(24n, t)))

def lt_low(+k: Nat, +a: Word(k), +r: Word(25n)) -> {Cmp.is_lt(Word.cmp(Nat.add(k, 25n), U.join(k, 25n, a, r), U.join(k, 25n, Word.zero(k), WCon{True{}, Word.zero(24n)}))) == U.zero(25n, r) : Bool}:
  match k:
    case 0n:
      lt_bit7(r)
    case 1n+p:
      match a:
        case WCon{h, t}:
          Equal.trans(Bool, Cmp.is_lt(Word.cmp.fin(h, False{}, Word.cmp(Nat.add(p, 25n), U.join(p, 25n, t, r), U.join(p, 25n, Word.zero(p), WCon{True{}, Word.zero(24n)})))), Cmp.is_lt(Word.cmp(Nat.add(p, 25n), U.join(p, 25n, t, r), U.join(p, 25n, Word.zero(p), WCon{True{}, Word.zero(24n)}))), U.zero(25n, r), lt_fin_low(h, Word.cmp(Nat.add(p, 25n), U.join(p, 25n, t, r), U.join(p, 25n, Word.zero(p), WCon{True{}, Word.zero(24n)}))), lt_low(p, t, r))

def ascii_lt(+w: Word(32n)) -> {(U32{w} < 128 : U32) == U.zero(25n, U.high(7n, 25n, w)) : Bool}:
  match w:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, r}}}}}}}:
      lt_low(7n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WNil{}}}}}}}}, r)

def ascii_spec(+a: Word(7n)) -> {[U32{U.join(7n, 25n, a, Word.zero(25n))}] == U.encode_char_spec(U32{U.join(7n, 25n, a, Word.zero(25n))}) : List<&2, U32>}:
  match a:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WNil{}}}}}}}}:
      {==}

def ascii_pick(+w: Word(32n), z: Bool, e: {U.zero(25n, U.high(7n, 25n, w)) == z : Bool}) -> {U.encode_char_pick(U32{w}, z) == U.encode_char_spec(U32{w}) : List<&2, U32>}:
  match z:
    case False{}:
      {==}
    case True{}:
      %pad_reconstruct(7n, 25n, w, zero_sound(25n, U.high(7n, 25n, w), e)) : {[U32{_}] == U.encode_char_spec(U32{_}) : List<&2, U32>}
      ascii_spec(U.low(7n, 25n, w))

# The ASCII branch of encode_char equals the general encoder for every U32.
def encode_char_equiv(+c: U32) -> {U.encode_char_spec(c) == U.encode_char(c) : List<&2, U32>}:
  match c:
    case U32{+w}:
      Equal.trans(List<&2, U32>, U.encode_char_spec(U32{w}), U.encode_char_pick(U32{w}, U.zero(25n, U.high(7n, 25n, w))), U.encode_char_pick(U32{w}, (U32{w} < 128 : U32)), Equal.sym(List<&2, U32>, U.encode_char_pick(U32{w}, U.zero(25n, U.high(7n, 25n, w))), U.encode_char_spec(U32{w}), ascii_pick(w, U.zero(25n, U.high(7n, 25n, w)), {==})), Equal.cong(Bool, List<&2, U32>, z => U.encode_char_pick(U32{w}, z), U.zero(25n, U.high(7n, 25n, w)), (U32{w} < 128 : U32), Equal.sym(Bool, (U32{w} < 128 : U32), U.zero(25n, U.high(7n, 25n, w)), ascii_lt(w))))

def step_bits_padded(+w: Word(21n), +rev: String, ok: {U.scalar(U32{U.join(21n, 11n, w, Word.zero(11n))}) == True{} : Bool}) -> {walk(U.encode_bits(U32{U.join(21n, 11n, w, Word.zero(11n))}), U.UtfReady{rev}) == U.UtfReady{SCon{Chr{U32{U.join(21n, 11n, w, Word.zero(11n))}}, rev}} : U.State}:
  match w:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WNil{}}}}}}}}}}}}}}}}}}}}}}:
      step21(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WNil{}}}}}}}}}}}}}}}}}}}}}}, rev, ok)

def step_bits32(+w: Word(32n), +rev: String, upper: {U.high(21n, 11n, w) == Word.zero(11n) : Word(11n)}) -> {U.scalar(U32{w}) == True{} : Bool} -> {walk(U.encode_bits(U32{w}), U.UtfReady{rev}) == U.UtfReady{SCon{Chr{U32{w}}, rev}} : U.State}:
  %pad_reconstruct(21n, 11n, w, upper) : {U.scalar(U32{_}) == True{} : Bool} -> {walk(U.encode_bits(U32{_}), U.UtfReady{rev}) == U.UtfReady{SCon{Chr{U32{_}}, rev}} : U.State}
  ok => step_bits_padded(U.low(21n, 11n, w), rev, ok)

def step_bits(+c: U32, +rev: String, +ok: {U.scalar(c) == True{} : Bool}) -> {walk(U.encode_bits(c), U.UtfReady{rev}) == U.UtfReady{SCon{Chr{c}, rev}} : U.State}:
  match c:
    case U32{w}:
      step_bits32(w, rev, zero_sound(11n, U.high(21n, 11n, w), fits(w, ok)), ok)

# BND-100: on a scalar the general encoder is the bit-level one.
def spec_bits(+c: U32, ok: {U.scalar(c) == True{} : Bool}) -> {U.encode_bits(c) == U.encode_char_spec(c) : List<&2, U32>}:
  %Equal.sym(Bool, U.scalar(c), True{}, ok) : {U.encode_bits(c) == U.encode_scalar(c, _) : List<&2, U32>}
  {==}

# encode_char of a scalar is the bit-level encoding.
def char_bits(+c: U32, ok: {U.scalar(c) == True{} : Bool}) -> {U.encode_bits(c) == U.encode_char(c) : List<&2, U32>}:
  Equal.trans(List<&2, U32>, U.encode_bits(c), U.encode_char_spec(c), U.encode_char(c), spec_bits(c, ok), encode_char_equiv(c))

def step_char_spec(+c: U32, +rev: String, +ok: {U.scalar(c) == True{} : Bool}) -> {walk(U.encode_char_spec(c), U.UtfReady{rev}) == U.UtfReady{SCon{Chr{c}, rev}} : U.State}:
  %spec_bits(c, ok) : {walk(_, U.UtfReady{rev}) == U.UtfReady{SCon{Chr{c}, rev}} : U.State}
  step_bits(c, rev, ok)

def step_char(+c: U32, +rev: String, +ok: {U.scalar(c) == True{} : Bool}) -> {walk(U.encode_char(c), U.UtfReady{rev}) == U.UtfReady{SCon{Chr{c}, rev}} : U.State}:
  %encode_char_equiv(c) : {walk(_, U.UtfReady{rev}) == U.UtfReady{SCon{Chr{c}, rev}} : U.State}
  step_char_spec(c, rev, ok)

# The pre-BND-68 statements over encode_char, through hot_utf8_encode_char.
def step_char_padded(+w: Word(21n), +rev: String, ok: {U.scalar(U32{U.join(21n, 11n, w, Word.zero(11n))}) == True{} : Bool}) -> {walk(U.encode_char(U32{U.join(21n, 11n, w, Word.zero(11n))}), U.UtfReady{rev}) == U.UtfReady{SCon{Chr{U32{U.join(21n, 11n, w, Word.zero(11n))}}, rev}} : U.State}:
  step_char(U32{U.join(21n, 11n, w, Word.zero(11n))}, rev, ok)

def step_char32(+w: Word(32n), +rev: String, upper: {U.high(21n, 11n, w) == Word.zero(11n) : Word(11n)}) -> {U.scalar(U32{w}) == True{} : Bool} -> {walk(U.encode_char(U32{w}), U.UtfReady{rev}) == U.UtfReady{SCon{Chr{U32{w}}, rev}} : U.State}:
  ok => step_char(U32{w}, rev, ok)

# ---- valid: a tail loop over the reversed string equals the spec ----

# The spec's right fold, onto the verdict acc for the text after it.
def valid_onto(s: String, +acc: Bool) -> Bool:
  match s:
    case SNil{}:
      acc
    case SCon{Chr{c}, t}:
      U.scalar(c) && valid_onto(t, acc)

def valid_onto_true(+s: String) -> {valid_onto(s, True{}) == U.valid_spec(s) : Bool}:
  match s:
    case SNil{}:
      {==}
    case SCon{Chr{c}, t}:
      Equal.cong(Bool, Bool, x => U.scalar(c) && x, valid_onto(t, True{}), U.valid_spec(t), valid_onto_true(t))

def valid_reverse(+s: String, +r: String, +acc: Bool) -> {U.valid_go(String.reverse.go(s, r), acc) == U.valid_go(r, valid_onto(s, acc)) : Bool}:
  match s:
    case SNil{}:
      {==}
    case SCon{Chr{c}, t}:
      valid_reverse(t, SCon{Chr{c}, r}, acc)

def valid_equiv(+s: String) -> {U.valid(s) == U.valid_spec(s) : Bool}:
  Equal.trans(Bool, U.valid(s), valid_onto(s, True{}), U.valid_spec(s), valid_reverse(s, "", True{}), valid_onto_true(s))

def valid_spec_of(+s: String, ok: {U.valid(s) == True{} : Bool}) -> {U.valid_spec(s) == True{} : Bool}:
  Equal.trans(Bool, U.valid_spec(s), U.valid(s), True{}, Equal.sym(Bool, U.valid(s), U.valid_spec(s), valid_equiv(s)), ok)

def roundtrip_go(+s: String, +rev: String, +ok: {U.valid_spec(s) == True{} : Bool}) -> {U.decode_go(U.encode_spec(s), U.UtfReady{rev}) == Some{String.reverse.go(rev, s)} : Maybe<&2, String>}:
  match s:
    case SNil{}:
      {==}
    case SCon{Chr{c}, t}:
      head = and_left(U.scalar(c), U.valid_spec(t), ok)
      tail = and_right(U.scalar(c), U.valid_spec(t), ok)
      a = decode_append(U.encode_char(c), U.encode_spec(t), U.UtfReady{rev})
      b = Equal.cong(U.State, Maybe<&2, String>, st => U.decode_go(U.encode_spec(t), st), walk(U.encode_char(c), U.UtfReady{rev}), U.UtfReady{SCon{Chr{c}, rev}}, step_char(c, rev, head))
      Equal.trans(Maybe<&2, String>, U.decode_go(List.append(&2, U32, U.encode_char(c), U.encode_spec(t)), U.UtfReady{rev}), U.decode_go(U.encode_spec(t), U.UtfReady{SCon{Chr{c}, rev}}), Some{String.reverse.go(rev, SCon{Chr{c}, t})}, Equal.trans(Maybe<&2, String>, U.decode_go(List.append(&2, U32, U.encode_char(c), U.encode_spec(t)), U.UtfReady{rev}), U.decode_go(U.encode_spec(t), walk(U.encode_char(c), U.UtfReady{rev})), U.decode_go(U.encode_spec(t), U.UtfReady{SCon{Chr{c}, rev}}), a, b), roundtrip_go(t, SCon{Chr{c}, rev}, tail))

# Universal, with an independently defined Unicode-scalar premise.
def roundtrip_spec(+s: String, ok: {U.valid(s) == True{} : Bool}) -> {U.decode(U.encode_spec(s)) == Some{s} : Maybe<&2, String>}:
  roundtrip_go(s, "", valid_spec_of(s, ok))

# The public stack-safe encoder has the same universal inverse.
def roundtrip(+s: String, ok: {U.valid(s) == True{} : Bool}) -> {U.decode(U.encode(s)) == Some{s} : Maybe<&2, String>}:
  %Equal.sym(List<&2, U32>, U.encode(s), U.encode_spec(s), encode_equiv(s)) : {U.decode(_) == Some{s} : Maybe<&2, String>}
  roundtrip_spec(s, ok)
