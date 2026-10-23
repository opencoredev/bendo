# The ASCII fast path is extensionally equal to the shared strict codec.
import Base
import ../src/data/json.bend as J
import ../src/data/utf8.bend as U
import ./utf8.bend as P

def lt_le(c: Cmp, e: {Cmp.is_lt(c) == True{} : Bool}) -> {Cmp.is_le(c) == True{} : Bool}:
  match c:
    case LT{}: {==}
    case EQ{}: {==}
    case GT{}: e

# Comparing against zero low bits cannot introduce LT at a lower bit.
def lt_zero_tail(a: Bool, c: Cmp, e: {Cmp.is_lt(Word.cmp.fin(a, False{}, c)) == True{} : Bool}) -> {Cmp.is_lt(c) == True{} : Bool}:
  match a c:
    case _ LT{}: {==}
    case False{} EQ{}: e
    case True{} EQ{}: e
    case _ GT{}: e

def high_lt_zero(+n: Nat, +m: Nat, +a: Word(Nat.add(n, m)), +b: Word(m), e: {Cmp.is_lt(Word.cmp(Nat.add(n, m), a, U.join(n, m, Word.zero(n), b))) == True{} : Bool}) -> {Cmp.is_lt(Word.cmp(m, U.high(n, m, a), b)) == True{} : Bool}:
  match n:
    case 0n: e
    case 1n+p:
      match a:
        case WCon{h, t}:
          high_lt_zero(p, m, t, b, lt_zero_tail(h, Word.cmp(Nat.add(p, m), t, U.join(p, m, Word.zero(p), b)), e))

def one_head(+n: Nat, h: Bool) -> {Cmp.is_lt(Bool.cmp(h, True{})) == True{} : Bool} -> {WCon{h, Word.zero(n)} == Word.zero(1n+n) : Word(1n+n)}:
  match h:
    case False{}: e => {==}
    case True{}: e => P.absurd({WCon{True{}, Word.zero(n)} == Word.zero(1n+n) : Word(1n+n)}, P.false_true(e))

def one_tail(+n: Nat, +h: Bool, +t: Word(n), tail: {t == Word.zero(n) : Word(n)}) -> {Cmp.is_lt(Word.cmp.fin(h, True{}, Word.cmp(n, t, Word.zero(n)))) == True{} : Bool} -> {WCon{h, t} == Word.zero(1n+n) : Word(1n+n)}:
  %Equal.sym(Word(n), t, Word.zero(n), tail) : {Cmp.is_lt(Word.cmp.fin(h, True{}, Word.cmp(n, _, Word.zero(n)))) == True{} : Bool} -> {WCon{h, _} == Word.zero(1n+n) : Word(1n+n)}
  %Equal.sym(Cmp, Word.cmp(n, Word.zero(n), Word.zero(n)), EQ{}, P.cmp_zero_self(n)) : {Cmp.is_lt(Word.cmp.fin(h, True{}, _)) == True{} : Bool} -> {WCon{h, Word.zero(n)} == Word.zero(1n+n) : Word(1n+n)}
  one_head(n, h)

def lt_one_zero(+n: Nat, +w: Word(1n+n), +e: {Cmp.is_lt(Word.cmp(1n+n, w, WCon{True{}, Word.zero(n)})) == True{} : Bool}) -> {w == Word.zero(1n+n) : Word(1n+n)}:
  match w:
    case WCon{h, t}:
      tail = P.cmp_le_zero(n, t, P.cmp_le_tail(h, True{}, Word.cmp(n, t, Word.zero(n)), lt_le(Word.cmp.fin(h, True{}, Word.cmp(n, t, Word.zero(n))), e)))
      one_tail(n, h, t, tail, e)

def ascii_upper(+w: Word(32n), e: {(U32{w} < 128 : U32) == True{} : Bool}) -> {U.high(7n, 25n, w) == Word.zero(25n) : Word(25n)}:
  lt_one_zero(24n, U.high(7n, 25n, w), high_lt_zero(7n, 25n, w, WCon{True{}, Word.zero(24n)}, e))

def advance_padded(+w: Word(7n), +rev: String) -> {J.advance_ascii(U.UtfReady{rev}, U.code7(w), True{}) == U.advance(U.UtfReady{rev}, U.byte_view(U.code7(w))) : U.State}:
  match w:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WNil{}}}}}}}}:
      {==}

def advance_small(+w: Word(32n), +rev: String, e: {(U32{w} < 128 : U32) == True{} : Bool}) -> {J.advance_ascii(U.UtfReady{rev}, U32{w}, True{}) == U.advance(U.UtfReady{rev}, U.byte_view(U32{w})) : U.State}:
  reconstructed = P.pad_reconstruct(7n, 25n, w, ascii_upper(w, e))
  %reconstructed : {J.advance_ascii(U.UtfReady{rev}, U32{_}, True{}) == U.advance(U.UtfReady{rev}, U.byte_view(U32{_})) : U.State}
  advance_padded(U.low(7n, 25n, w), rev)

def advance_ready(+w: Word(32n), +rev: String, small: Bool) -> {(U32{w} < 128 : U32) == small : Bool} -> {J.advance_ascii(U.UtfReady{rev}, U32{w}, small) == U.advance(U.UtfReady{rev}, U.byte_view(U32{w})) : U.State}:
  match small:
    case False{}: e => {==}
    case True{}: e => advance_small(w, rev, e)

def advance_equiv(+state: U.State, +b: U32) -> {J.advance_ascii(state, b, (b < 128 : U32)) == U.advance(state, U.byte_view(b)) : U.State}:
  match state b:
    case U.UtfReady{rev} U32{w}: advance_ready(w, rev, (U32{w} < 128 : U32), {==})
    case U.Need2{a, rev} _: {==}
    case U.Need3{a, rev} _: {==}
    case U.Need3Tail{a, c, rev} _: {==}
    case U.Need4{a, rev} _: {==}
    case U.Need4Mid{a, c, rev} _: {==}
    case U.Need4Tail{a, c, d, rev} _: {==}
    case U.Bad{} _: {==}

def decode_next(+xs: List<&2, U32>, +state: U.State, +b: U32, tail: {J.decode_go(xs, U.advance(state, U.byte_view(b))) == U.decode_go(xs, U.advance(state, U.byte_view(b))) : Maybe<&2, String>}) -> {J.decode_go(xs, J.advance_ascii(state, b, (b < 128 : U32))) == U.decode_go(xs, U.advance(state, U.byte_view(b))) : Maybe<&2, String>}:
  %Equal.sym(U.State, J.advance_ascii(state, b, (b < 128 : U32)), U.advance(state, U.byte_view(b)), advance_equiv(state, b)) : {J.decode_go(xs, _) == U.decode_go(xs, U.advance(state, U.byte_view(b))) : Maybe<&2, String>}
  tail

def decode_cons(+xs: List<&2, U32>, +state: U.State, +b: U32, tail: {J.decode_go(xs, J.advance_ascii(state, b, (b < 128 : U32))) == U.decode_go(xs, U.advance(state, U.byte_view(b))) : Maybe<&2, String>}) -> {J.decode_go(b <> xs, state) == U.decode_go(b <> xs, state) : Maybe<&2, String>}:
  match state:
    case U.Bad{}: {==}
    case U.UtfReady{rev}: tail
    case U.Need2{a, rev}: tail
    case U.Need3{a, rev}: tail
    case U.Need3Tail{a, c, rev}: tail
    case U.Need4{a, rev}: tail
    case U.Need4Mid{a, c, rev}: tail
    case U.Need4Tail{a, c, d, rev}: tail

def decode_go_equiv(+xs: List<&2, U32>, +state: U.State) -> {J.decode_go(xs, state) == U.decode_go(xs, state) : Maybe<&2, String>}:
  match xs:
    case Nil{}:
      match state:
        case U.Bad{}: {==}
        case U.UtfReady{rev}: {==}
        case U.Need2{a, rev}: {==}
        case U.Need3{a, rev}: {==}
        case U.Need3Tail{a, b, rev}: {==}
        case U.Need4{a, rev}: {==}
        case U.Need4Mid{a, b, rev}: {==}
        case U.Need4Tail{a, b, c, rev}: {==}
    case b <> t:
      decode_cons(t, state, b, decode_next(t, state, b, decode_go_equiv(t, U.advance(state, U.byte_view(b)))))

def decode_equiv(+xs: List<&2, U32>) -> {J.decode(xs) == U.decode(xs) : Maybe<&2, String>}:
  decode_go_equiv(xs, U.UtfReady{""})

def roundtrip(+s: String, valid: {U.valid(s) == True{} : Bool}) -> {J.decode(U.encode(s)) == Some{s} : Maybe<&2, String>}:
  %Equal.sym(Maybe<&2, String>, J.decode(U.encode(s)), U.decode(U.encode(s)), decode_equiv(U.encode(s))) : {_ == Some{s} : Maybe<&2, String>}
  P.roundtrip(s, valid)
