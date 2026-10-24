# BND-87: strict UTF-8 decoding is sound. Whenever Utf8.decode returns
# Some{s}, s is a string of Unicode scalars and its UTF-8 encoding is
# exactly the input. Together with the roundtrip proof in utf8.bend this
# makes Utf8.decode the inverse of Utf8.encode on scalar strings.
import Base
import ../src/data/utf8.bend as U
import ./utf8.bend as UP

def found_tag(m: Maybe<&2, String>) -> Type:
  match m:
    case None{}: Unit
    case Some{x}: Empty

def none_some(+x: String, e: {None{} == Some{x} : Maybe<&2, String>}) -> Empty:
  %e : found_tag(_)
  Unit{}

def get(m: Maybe<&2, String>, d: String) -> String:
  match m:
    case None{}: d
    case Some{x}: x

def some_inj(+a: String, +b: String, e: {Some{a} == Some{b} : Maybe<&2, String>}) -> {a == b : String}:
  Equal.cong(Maybe<&2, String>, String, m => get(m, a), Some{a}, Some{b}, e)

def bad_end(-A: Type, +t: List<&2, U32>, +out: String, h: {U.decode_go(t, U.Bad{}) == Some{out} : Maybe<&2, String>}) -> A:
  UP.absurd(A, none_some(out, Equal.trans(Maybe<&2, String>, None{}, U.decode_go(t, U.Bad{}), Some{out}, Equal.sym(Maybe<&2, String>, U.decode_go(t, U.Bad{}), None{}, UP.decode_bad(t)), h)))

def not_true(+a: Bool, e: {Bool.not(a) == True{} : Bool}) -> {a == False{} : Bool}:
  match a:
    case False{}: {==}
    case True{}: UP.absurd({True{} == False{} : Bool}, UP.false_true(e))

def both(+a: Bool, +b: Bool, ea: {a == True{} : Bool}, eb: {b == True{} : Bool}) -> {a && b == True{} : Bool}:
  %Equal.sym(Bool, a, True{}, ea) : {_ && b == True{} : Bool}
  eb

def and_left(+a: Bool, +b: Bool, e: {a && b == True{} : Bool}) -> {a == True{} : Bool}:
  match a:
    case True{}: {==}
    case False{}: UP.absurd({False{} == True{} : Bool}, UP.false_true(e))

def and_right(+a: Bool, +b: Bool, e: {a && b == True{} : Bool}) -> {b == True{} : Bool}:
  match a:
    case True{}: e
    case False{}: UP.absurd({b == True{} : Bool}, UP.false_true(e))

# The octets a decoder state has read but not yet turned into a character.
def pending(s: U.State) -> List<&2, U32>:
  match s:
    case U.UtfReady{r}: []
    case U.Need2{a, r}: [U.byte5(a)]
    case U.Need3{a, r}: [U.byte4(a)]
    case U.Need3Tail{a, b, r}: [U.byte4(a), U.byte6(b)]
    case U.Need4{a, r}: [U.byte3(a)]
    case U.Need4Mid{a, b, r}: [U.byte3(a), U.byte6(b)]
    case U.Need4Tail{a, b, c, r}: [U.byte3(a), U.byte6(b), U.byte6(c)]
    case U.Bad{}: []

# The characters a decoder state has produced, most recent first.
def produced(s: U.State) -> String:
  match s:
    case U.UtfReady{r}: r
    case U.Need2{a, r}: r
    case U.Need3{a, r}: r
    case U.Need3Tail{a, b, r}: r
    case U.Need4{a, r}: r
    case U.Need4Mid{a, b, r}: r
    case U.Need4Tail{a, b, c, r}: r
    case U.Bad{}: ""

# A successful decode from state s: the output is what s produced so far,
# followed by a scalar string w whose encoding is the pending octets and
# the rest of the input.
def Sound(xs: List<&2, U32>, s: U.State, out: String) -> Type:
  &w:String -> ({out == String.reverse.go(produced(s), w) : String} & ({U.encode_spec(w) == List.append(&2, U32, pending(s), xs) : List<&2, U32>} & {U.valid_spec(w) == True{} : Bool}))

# What a byte's class says about the byte itself.
def Inv(b: U32, v: U.Byte) -> Type:
  match v:
    case U.Ascii{w}: {U.code7(w) == b : U32}
    case U.Continuation{w}: {U.byte6(w) == b : U32}
    case U.Lead2{w}: {U.byte5(w) == b : U32}
    case U.Lead3{w}: {U.byte4(w) == b : U32}
    case U.Lead4{w}: {U.byte3(w) == b : U32}
    case U.Invalid{}: Unit

def view8_bits(+l7: Bool, +l6: Bool, +l5: Bool, +l4: Bool, +l3: Bool, +l2: Bool, +l1: Bool, +l0: Bool) -> Inv(U32{U.join(8n, 24n, WCon{l0, WCon{l1, WCon{l2, WCon{l3, WCon{l4, WCon{l5, WCon{l6, WCon{l7, WNil{}}}}}}}}}, Word.zero(24n))}, U.view8(WCon{l0, WCon{l1, WCon{l2, WCon{l3, WCon{l4, WCon{l5, WCon{l6, WCon{l7, WNil{}}}}}}}}})):
  match l7:
    case False{}: {==}
    case True{}:
      match l6:
        case False{}: {==}
        case True{}:
          match l5:
            case False{}: {==}
            case True{}:
              match l4:
                case False{}: {==}
                case True{}:
                  match l3:
                    case False{}: {==}
                    case True{}: Unit{}

def view8_inv(+l: Word(8n)) -> Inv(U32{U.join(8n, 24n, l, Word.zero(24n))}, U.view8(l)):
  match l:
    case WCon{+l0, WCon{+l1, WCon{+l2, WCon{+l3, WCon{+l4, WCon{+l5, WCon{+l6, WCon{+l7, WNil{}}}}}}}}}:
      view8_bits(l7, l6, l5, l4, l3, l2, l1, l0)

def view_high(+w: Word(32n), +l: Word(8n), el: {U.low(8n, 24n, w) == l : Word(8n)}, hz: {U.high(8n, 24n, w) == Word.zero(24n) : Word(24n)}) -> Inv(U32{w}, U.view8(l)):
  +rec = Equal.trans(Word(32n), U.join(8n, 24n, l, Word.zero(24n)), U.join(8n, 24n, U.low(8n, 24n, w), Word.zero(24n)), w, Equal.cong(Word(8n), Word(32n), x => U.join(8n, 24n, x, Word.zero(24n)), l, U.low(8n, 24n, w), Equal.sym(Word(8n), U.low(8n, 24n, w), l, el)), UP.pad_reconstruct(8n, 24n, w, hz))
  %rec : Inv(U32{_}, U.view8(l))
  view8_inv(l)

def view_go(+w: Word(32n), +l: Word(8n), z: Bool, el: {U.low(8n, 24n, w) == l : Word(8n)}, ez: {U.zero(24n, U.high(8n, 24n, w)) == z : Bool}) -> Inv(U32{w}, U.byte_view_go(l, z)):
  match z:
    case False{}: Unit{}
    case True{}: view_high(w, l, el, UP.zero_sound(24n, U.high(8n, 24n, w), ez))

def view_inv(+b: U32) -> Inv(b, U.byte_view(b)):
  match b:
    case U32{+w}: view_go(w, U.low(8n, 24n, w), U.zero(24n, U.high(8n, 24n, w)), {==}, {==})

# ---- generated steps ----
# The encoder's choices for a decoded two-, three- and four-octet character.
def enc11(+c0: Bool, +c1: Bool, +c2: Bool, +c3: Bool, +c4: Bool, +c5: Bool, +a0: Bool, +a1: Bool, +a2: Bool, +a3: Bool, +a4: Bool, z: {U.zero(4n, U.high(7n, 4n, U.join(6n, 5n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WCon{a3, WCon{a4, WNil{}}}}}}))) == False{} : Bool}, sc: {U.scalar(U32{U.join(11n, 21n, U.join(6n, 5n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WCon{a3, WCon{a4, WNil{}}}}}}), Word.zero(21n))}) == True{} : Bool}) -> {U.encode_char(U32{U.join(11n, 21n, U.join(6n, 5n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WCon{a3, WCon{a4, WNil{}}}}}}), Word.zero(21n))}) == [U.byte5(WCon{a0, WCon{a1, WCon{a2, WCon{a3, WCon{a4, WNil{}}}}}}), U.byte6(WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}})] : List<&2, U32>}:
  %UP.char_bits(U32{U.join(11n, 21n, U.join(6n, 5n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WCon{a3, WCon{a4, WNil{}}}}}}), Word.zero(21n))}, sc) : {_ == [U.byte5(WCon{a0, WCon{a1, WCon{a2, WCon{a3, WCon{a4, WNil{}}}}}}), U.byte6(WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}})] : List<&2, U32>}
  %Equal.sym(Bool, U.zero(4n, U.high(7n, 4n, U.join(6n, 5n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WCon{a3, WCon{a4, WNil{}}}}}}))), False{}, z) : {U.encode11_go(U.join(6n, 5n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WCon{a3, WCon{a4, WNil{}}}}}}), _) == [U.byte5(WCon{a0, WCon{a1, WCon{a2, WCon{a3, WCon{a4, WNil{}}}}}}), U.byte6(WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}})] : List<&2, U32>}
  {==}

def enc16(+c0: Bool, +c1: Bool, +c2: Bool, +c3: Bool, +c4: Bool, +c5: Bool, +b0: Bool, +b1: Bool, +b2: Bool, +b3: Bool, +b4: Bool, +b5: Bool, +a0: Bool, +a1: Bool, +a2: Bool, +a3: Bool, z: {U.zero(5n, U.high(11n, 5n, U.join(6n, 10n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, U.join(6n, 4n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}})))) == False{} : Bool}, sc: {U.scalar(U32{U.join(16n, 16n, U.join(6n, 10n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, U.join(6n, 4n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}})), Word.zero(16n))}) == True{} : Bool}) -> {U.encode_char(U32{U.join(16n, 16n, U.join(6n, 10n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, U.join(6n, 4n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}})), Word.zero(16n))}) == [U.byte4(WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}}), U.byte6(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}), U.byte6(WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}})] : List<&2, U32>}:
  %UP.char_bits(U32{U.join(16n, 16n, U.join(6n, 10n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, U.join(6n, 4n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}})), Word.zero(16n))}, sc) : {_ == [U.byte4(WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}}), U.byte6(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}), U.byte6(WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}})] : List<&2, U32>}
  %Equal.sym(Bool, U.zero(5n, U.high(11n, 5n, U.join(6n, 10n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, U.join(6n, 4n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}})))), False{}, z) : {U.encode16_go(U.join(6n, 10n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, U.join(6n, 4n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}})), _) == [U.byte4(WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}}), U.byte6(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}), U.byte6(WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}})] : List<&2, U32>}
  {==}

def enc21(+d0: Bool, +d1: Bool, +d2: Bool, +d3: Bool, +d4: Bool, +d5: Bool, +c0: Bool, +c1: Bool, +c2: Bool, +c3: Bool, +c4: Bool, +c5: Bool, +b0: Bool, +b1: Bool, +b2: Bool, +b3: Bool, +b4: Bool, +b5: Bool, +a0: Bool, +a1: Bool, +a2: Bool, z: {U.zero(5n, U.high(16n, 5n, U.join(6n, 15n, WCon{d0, WCon{d1, WCon{d2, WCon{d3, WCon{d4, WCon{d5, WNil{}}}}}}}, U.join(6n, 9n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, U.join(6n, 3n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WNil{}}}}))))) == False{} : Bool}, sc: {U.scalar(U32{U.join(21n, 11n, U.join(6n, 15n, WCon{d0, WCon{d1, WCon{d2, WCon{d3, WCon{d4, WCon{d5, WNil{}}}}}}}, U.join(6n, 9n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, U.join(6n, 3n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WNil{}}}}))), Word.zero(11n))}) == True{} : Bool}) -> {U.encode_char(U32{U.join(21n, 11n, U.join(6n, 15n, WCon{d0, WCon{d1, WCon{d2, WCon{d3, WCon{d4, WCon{d5, WNil{}}}}}}}, U.join(6n, 9n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, U.join(6n, 3n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WNil{}}}}))), Word.zero(11n))}) == [U.byte3(WCon{a0, WCon{a1, WCon{a2, WNil{}}}}), U.byte6(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}), U.byte6(WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}), U.byte6(WCon{d0, WCon{d1, WCon{d2, WCon{d3, WCon{d4, WCon{d5, WNil{}}}}}}})] : List<&2, U32>}:
  %UP.char_bits(U32{U.join(21n, 11n, U.join(6n, 15n, WCon{d0, WCon{d1, WCon{d2, WCon{d3, WCon{d4, WCon{d5, WNil{}}}}}}}, U.join(6n, 9n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, U.join(6n, 3n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WNil{}}}}))), Word.zero(11n))}, sc) : {_ == [U.byte3(WCon{a0, WCon{a1, WCon{a2, WNil{}}}}), U.byte6(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}), U.byte6(WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}), U.byte6(WCon{d0, WCon{d1, WCon{d2, WCon{d3, WCon{d4, WCon{d5, WNil{}}}}}}})] : List<&2, U32>}
  %Equal.sym(Bool, U.zero(5n, U.high(16n, 5n, U.join(6n, 15n, WCon{d0, WCon{d1, WCon{d2, WCon{d3, WCon{d4, WCon{d5, WNil{}}}}}}}, U.join(6n, 9n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, U.join(6n, 3n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WNil{}}}}))))), False{}, z) : {U.encode21_go(U.join(6n, 15n, WCon{d0, WCon{d1, WCon{d2, WCon{d3, WCon{d4, WCon{d5, WNil{}}}}}}}, U.join(6n, 9n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, U.join(6n, 3n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WNil{}}}}))), _) == [U.byte3(WCon{a0, WCon{a1, WCon{a2, WNil{}}}}), U.byte6(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}), U.byte6(WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}), U.byte6(WCon{d0, WCon{d1, WCon{d2, WCon{d3, WCon{d4, WCon{d5, WNil{}}}}}}})] : List<&2, U32>}
  {==}

# A completed character c whose encoding is the pending octets plus b
# extends the output by c.
def emitted(+c: U32, +rev: String, +pre: List<&2, U32>, +b: U32, +t: List<&2, U32>, +out: String, ec: {U.encode_char(c) == List.append(&2, U32, pre, [b]) : List<&2, U32>}, sc: {U.scalar(c) == True{} : Bool}, rest: Sound(t, U.UtfReady{SCon{Chr{c}, rev}}, out)) -> &w:String -> ({out == String.reverse.go(rev, w) : String} & ({U.encode_spec(w) == List.append(&2, U32, pre, b <> t) : List<&2, U32>} & {U.valid_spec(w) == True{} : Bool})):
  match rest:
    case (+w, (e1, (+e2, e3))):
      +x = Equal.cong(List<&2, U32>, List<&2, U32>, y => List.append(&2, U32, U.encode_char(c), y), U.encode_spec(w), t, e2)
      +y = Equal.cong(List<&2, U32>, List<&2, U32>, y => List.append(&2, U32, y, t), U.encode_char(c), List.append(&2, U32, pre, [b]), ec)
      +z = Equal.trans(List<&2, U32>, List.append(&2, U32, U.encode_char(c), t), List.append(&2, U32, List.append(&2, U32, pre, [b]), t), List.append(&2, U32, pre, b <> t), y, UP.append_assoc(U32, pre, [b], t))
      (SCon{Chr{c}, w}, (e1, (Equal.trans(List<&2, U32>, List.append(&2, U32, U.encode_char(c), U.encode_spec(w)), List.append(&2, U32, U.encode_char(c), t), List.append(&2, U32, pre, b <> t), x, z), both(U.scalar(c), U.valid_spec(w), sc, e3))))

# A state change that only collects the byte b as pending.
def collected(+rev: String, +pre: List<&2, U32>, +more: List<&2, U32>, +b: U32, +t: List<&2, U32>, +out: String, eb: {more == List.append(&2, U32, pre, [b]) : List<&2, U32>}, rest: &w:String -> ({out == String.reverse.go(rev, w) : String} & ({U.encode_spec(w) == List.append(&2, U32, more, t) : List<&2, U32>} & {U.valid_spec(w) == True{} : Bool}))) -> &w:String -> ({out == String.reverse.go(rev, w) : String} & ({U.encode_spec(w) == List.append(&2, U32, pre, b <> t) : List<&2, U32>} & {U.valid_spec(w) == True{} : Bool})):
  match rest:
    case (+w, (e1, (e2, e3))):
      +y = Equal.cong(List<&2, U32>, List<&2, U32>, y => List.append(&2, U32, y, t), more, List.append(&2, U32, pre, [b]), eb)
      +z = Equal.trans(List<&2, U32>, List.append(&2, U32, more, t), List.append(&2, U32, List.append(&2, U32, pre, [b]), t), List.append(&2, U32, pre, b <> t), y, UP.append_assoc(U32, pre, [b], t))
      (w, (e1, (Equal.trans(List<&2, U32>, U.encode_spec(w), List.append(&2, U32, more, t), List.append(&2, U32, pre, b <> t), e2, z), e3)))

def fin11(+rev: String, +b: U32, +t: List<&2, U32>, +out: String, +c0: Bool, +c1: Bool, +c2: Bool, +c3: Bool, +c4: Bool, +c5: Bool, +a0: Bool, +a1: Bool, +a2: Bool, +a3: Bool, +a4: Bool, ok: Bool, +eok: {Bool.not(U.zero(4n, U.high(7n, 4n, U.join(6n, 5n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WCon{a3, WCon{a4, WNil{}}}}}})))) && U.scalar(U32{U.join(11n, 21n, U.join(6n, 5n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WCon{a3, WCon{a4, WNil{}}}}}}), Word.zero(21n))}) == ok : Bool}, inv: {U.byte6(WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}) == b : U32}, h: {U.decode_go(t, U.finish(U32{U.join(11n, 21n, U.join(6n, 5n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WCon{a3, WCon{a4, WNil{}}}}}}), Word.zero(21n))}, rev, ok)) == Some{out} : Maybe<&2, String>}, ih: @st:U.State -> @o:String -> {U.decode_go(t, st) == Some{o} : Maybe<&2, String>} -> Sound(t, st, o)) -> Sound(b <> t, U.Need2{WCon{a0, WCon{a1, WCon{a2, WCon{a3, WCon{a4, WNil{}}}}}}, rev}, out):
  match ok:
    case False{}:
      bad_end(Sound(b <> t, U.Need2{WCon{a0, WCon{a1, WCon{a2, WCon{a3, WCon{a4, WNil{}}}}}}, rev}, out), t, out, h)
    case True{}:
      +big = not_true(U.zero(4n, U.high(7n, 4n, U.join(6n, 5n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WCon{a3, WCon{a4, WNil{}}}}}}))), and_left(Bool.not(U.zero(4n, U.high(7n, 4n, U.join(6n, 5n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WCon{a3, WCon{a4, WNil{}}}}}})))), U.scalar(U32{U.join(11n, 21n, U.join(6n, 5n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WCon{a3, WCon{a4, WNil{}}}}}}), Word.zero(21n))}), eok))
      +sc = and_right(Bool.not(U.zero(4n, U.high(7n, 4n, U.join(6n, 5n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WCon{a3, WCon{a4, WNil{}}}}}})))), U.scalar(U32{U.join(11n, 21n, U.join(6n, 5n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WCon{a3, WCon{a4, WNil{}}}}}}), Word.zero(21n))}), eok)
      +ec = Equal.trans(List<&2, U32>, U.encode_char(U32{U.join(11n, 21n, U.join(6n, 5n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WCon{a3, WCon{a4, WNil{}}}}}}), Word.zero(21n))}), List.append(&2, U32, [U.byte5(WCon{a0, WCon{a1, WCon{a2, WCon{a3, WCon{a4, WNil{}}}}}})], [U.byte6(WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}})]), List.append(&2, U32, [U.byte5(WCon{a0, WCon{a1, WCon{a2, WCon{a3, WCon{a4, WNil{}}}}}})], [b]), enc11(c0, c1, c2, c3, c4, c5, a0, a1, a2, a3, a4, big, sc), Equal.cong(U32, List<&2, U32>, x => List.append(&2, U32, [U.byte5(WCon{a0, WCon{a1, WCon{a2, WCon{a3, WCon{a4, WNil{}}}}}})], [x]), U.byte6(WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}), b, inv))
      emitted(U32{U.join(11n, 21n, U.join(6n, 5n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WCon{a3, WCon{a4, WNil{}}}}}}), Word.zero(21n))}, rev, [U.byte5(WCon{a0, WCon{a1, WCon{a2, WCon{a3, WCon{a4, WNil{}}}}}})], b, t, out, ec, sc, ih(U.UtfReady{SCon{Chr{U32{U.join(11n, 21n, U.join(6n, 5n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WCon{a3, WCon{a4, WNil{}}}}}}), Word.zero(21n))}}, rev}}, out, h))

def fin16(+rev: String, +b: U32, +t: List<&2, U32>, +out: String, +c0: Bool, +c1: Bool, +c2: Bool, +c3: Bool, +c4: Bool, +c5: Bool, +b0: Bool, +b1: Bool, +b2: Bool, +b3: Bool, +b4: Bool, +b5: Bool, +a0: Bool, +a1: Bool, +a2: Bool, +a3: Bool, ok: Bool, +eok: {Bool.not(U.zero(5n, U.high(11n, 5n, U.join(6n, 10n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, U.join(6n, 4n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}}))))) && U.scalar(U32{U.join(16n, 16n, U.join(6n, 10n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, U.join(6n, 4n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}})), Word.zero(16n))}) == ok : Bool}, inv: {U.byte6(WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}) == b : U32}, h: {U.decode_go(t, U.finish(U32{U.join(16n, 16n, U.join(6n, 10n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, U.join(6n, 4n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}})), Word.zero(16n))}, rev, ok)) == Some{out} : Maybe<&2, String>}, ih: @st:U.State -> @o:String -> {U.decode_go(t, st) == Some{o} : Maybe<&2, String>} -> Sound(t, st, o)) -> Sound(b <> t, U.Need3Tail{WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}}, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, rev}, out):
  match ok:
    case False{}:
      bad_end(Sound(b <> t, U.Need3Tail{WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}}, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, rev}, out), t, out, h)
    case True{}:
      +big = not_true(U.zero(5n, U.high(11n, 5n, U.join(6n, 10n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, U.join(6n, 4n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}})))), and_left(Bool.not(U.zero(5n, U.high(11n, 5n, U.join(6n, 10n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, U.join(6n, 4n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}}))))), U.scalar(U32{U.join(16n, 16n, U.join(6n, 10n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, U.join(6n, 4n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}})), Word.zero(16n))}), eok))
      +sc = and_right(Bool.not(U.zero(5n, U.high(11n, 5n, U.join(6n, 10n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, U.join(6n, 4n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}}))))), U.scalar(U32{U.join(16n, 16n, U.join(6n, 10n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, U.join(6n, 4n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}})), Word.zero(16n))}), eok)
      +ec = Equal.trans(List<&2, U32>, U.encode_char(U32{U.join(16n, 16n, U.join(6n, 10n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, U.join(6n, 4n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}})), Word.zero(16n))}), List.append(&2, U32, [U.byte4(WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}}), U.byte6(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}})], [U.byte6(WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}})]), List.append(&2, U32, [U.byte4(WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}}), U.byte6(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}})], [b]), enc16(c0, c1, c2, c3, c4, c5, b0, b1, b2, b3, b4, b5, a0, a1, a2, a3, big, sc), Equal.cong(U32, List<&2, U32>, x => List.append(&2, U32, [U.byte4(WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}}), U.byte6(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}})], [x]), U.byte6(WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}), b, inv))
      emitted(U32{U.join(16n, 16n, U.join(6n, 10n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, U.join(6n, 4n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}})), Word.zero(16n))}, rev, [U.byte4(WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}}), U.byte6(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}})], b, t, out, ec, sc, ih(U.UtfReady{SCon{Chr{U32{U.join(16n, 16n, U.join(6n, 10n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, U.join(6n, 4n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}})), Word.zero(16n))}}, rev}}, out, h))

def fin21(+rev: String, +b: U32, +t: List<&2, U32>, +out: String, +d0: Bool, +d1: Bool, +d2: Bool, +d3: Bool, +d4: Bool, +d5: Bool, +c0: Bool, +c1: Bool, +c2: Bool, +c3: Bool, +c4: Bool, +c5: Bool, +b0: Bool, +b1: Bool, +b2: Bool, +b3: Bool, +b4: Bool, +b5: Bool, +a0: Bool, +a1: Bool, +a2: Bool, ok: Bool, +eok: {Bool.not(U.zero(5n, U.high(16n, 5n, U.join(6n, 15n, WCon{d0, WCon{d1, WCon{d2, WCon{d3, WCon{d4, WCon{d5, WNil{}}}}}}}, U.join(6n, 9n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, U.join(6n, 3n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WNil{}}}})))))) && U.scalar(U32{U.join(21n, 11n, U.join(6n, 15n, WCon{d0, WCon{d1, WCon{d2, WCon{d3, WCon{d4, WCon{d5, WNil{}}}}}}}, U.join(6n, 9n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, U.join(6n, 3n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WNil{}}}}))), Word.zero(11n))}) == ok : Bool}, inv: {U.byte6(WCon{d0, WCon{d1, WCon{d2, WCon{d3, WCon{d4, WCon{d5, WNil{}}}}}}}) == b : U32}, h: {U.decode_go(t, U.finish(U32{U.join(21n, 11n, U.join(6n, 15n, WCon{d0, WCon{d1, WCon{d2, WCon{d3, WCon{d4, WCon{d5, WNil{}}}}}}}, U.join(6n, 9n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, U.join(6n, 3n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WNil{}}}}))), Word.zero(11n))}, rev, ok)) == Some{out} : Maybe<&2, String>}, ih: @st:U.State -> @o:String -> {U.decode_go(t, st) == Some{o} : Maybe<&2, String>} -> Sound(t, st, o)) -> Sound(b <> t, U.Need4Tail{WCon{a0, WCon{a1, WCon{a2, WNil{}}}}, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, rev}, out):
  match ok:
    case False{}:
      bad_end(Sound(b <> t, U.Need4Tail{WCon{a0, WCon{a1, WCon{a2, WNil{}}}}, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, rev}, out), t, out, h)
    case True{}:
      +big = not_true(U.zero(5n, U.high(16n, 5n, U.join(6n, 15n, WCon{d0, WCon{d1, WCon{d2, WCon{d3, WCon{d4, WCon{d5, WNil{}}}}}}}, U.join(6n, 9n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, U.join(6n, 3n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WNil{}}}}))))), and_left(Bool.not(U.zero(5n, U.high(16n, 5n, U.join(6n, 15n, WCon{d0, WCon{d1, WCon{d2, WCon{d3, WCon{d4, WCon{d5, WNil{}}}}}}}, U.join(6n, 9n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, U.join(6n, 3n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WNil{}}}})))))), U.scalar(U32{U.join(21n, 11n, U.join(6n, 15n, WCon{d0, WCon{d1, WCon{d2, WCon{d3, WCon{d4, WCon{d5, WNil{}}}}}}}, U.join(6n, 9n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, U.join(6n, 3n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WNil{}}}}))), Word.zero(11n))}), eok))
      +sc = and_right(Bool.not(U.zero(5n, U.high(16n, 5n, U.join(6n, 15n, WCon{d0, WCon{d1, WCon{d2, WCon{d3, WCon{d4, WCon{d5, WNil{}}}}}}}, U.join(6n, 9n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, U.join(6n, 3n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WNil{}}}})))))), U.scalar(U32{U.join(21n, 11n, U.join(6n, 15n, WCon{d0, WCon{d1, WCon{d2, WCon{d3, WCon{d4, WCon{d5, WNil{}}}}}}}, U.join(6n, 9n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, U.join(6n, 3n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WNil{}}}}))), Word.zero(11n))}), eok)
      +ec = Equal.trans(List<&2, U32>, U.encode_char(U32{U.join(21n, 11n, U.join(6n, 15n, WCon{d0, WCon{d1, WCon{d2, WCon{d3, WCon{d4, WCon{d5, WNil{}}}}}}}, U.join(6n, 9n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, U.join(6n, 3n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WNil{}}}}))), Word.zero(11n))}), List.append(&2, U32, [U.byte3(WCon{a0, WCon{a1, WCon{a2, WNil{}}}}), U.byte6(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}), U.byte6(WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}})], [U.byte6(WCon{d0, WCon{d1, WCon{d2, WCon{d3, WCon{d4, WCon{d5, WNil{}}}}}}})]), List.append(&2, U32, [U.byte3(WCon{a0, WCon{a1, WCon{a2, WNil{}}}}), U.byte6(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}), U.byte6(WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}})], [b]), enc21(d0, d1, d2, d3, d4, d5, c0, c1, c2, c3, c4, c5, b0, b1, b2, b3, b4, b5, a0, a1, a2, big, sc), Equal.cong(U32, List<&2, U32>, x => List.append(&2, U32, [U.byte3(WCon{a0, WCon{a1, WCon{a2, WNil{}}}}), U.byte6(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}), U.byte6(WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}})], [x]), U.byte6(WCon{d0, WCon{d1, WCon{d2, WCon{d3, WCon{d4, WCon{d5, WNil{}}}}}}}), b, inv))
      emitted(U32{U.join(21n, 11n, U.join(6n, 15n, WCon{d0, WCon{d1, WCon{d2, WCon{d3, WCon{d4, WCon{d5, WNil{}}}}}}}, U.join(6n, 9n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, U.join(6n, 3n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WNil{}}}}))), Word.zero(11n))}, rev, [U.byte3(WCon{a0, WCon{a1, WCon{a2, WNil{}}}}), U.byte6(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}), U.byte6(WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}})], b, t, out, ec, sc, ih(U.UtfReady{SCon{Chr{U32{U.join(21n, 11n, U.join(6n, 15n, WCon{d0, WCon{d1, WCon{d2, WCon{d3, WCon{d4, WCon{d5, WNil{}}}}}}}, U.join(6n, 9n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, U.join(6n, 3n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WNil{}}}}))), Word.zero(11n))}}, rev}}, out, h))

def step_ready(+rev: String, +b: U32, +t: List<&2, U32>, +out: String, +v: U.Byte, inv: Inv(b, v), h: {U.decode_go(t, U.advance(U.UtfReady{rev}, v)) == Some{out} : Maybe<&2, String>}, ih: @st:U.State -> @o:String -> {U.decode_go(t, st) == Some{o} : Maybe<&2, String>} -> Sound(t, st, o)) -> Sound(b <> t, U.UtfReady{rev}, out):
  match v:
    case U.Ascii{WCon{+w0, WCon{+w1, WCon{+w2, WCon{+w3, WCon{+w4, WCon{+w5, WCon{+w6, WNil{}}}}}}}}}:
      emitted(U.code7(WCon{w0, WCon{w1, WCon{w2, WCon{w3, WCon{w4, WCon{w5, WCon{w6, WNil{}}}}}}}}), rev, [], b, t, out, Equal.cong(U32, List<&2, U32>, x => [x], U.code7(WCon{w0, WCon{w1, WCon{w2, WCon{w3, WCon{w4, WCon{w5, WCon{w6, WNil{}}}}}}}}), b, inv), {==}, ih(U.UtfReady{SCon{Chr{U.code7(WCon{w0, WCon{w1, WCon{w2, WCon{w3, WCon{w4, WCon{w5, WCon{w6, WNil{}}}}}}}})}, rev}}, out, h))
    case U.Continuation{w}:
      bad_end(Sound(b <> t, U.UtfReady{rev}, out), t, out, h)
    case U.Lead2{+a}:
      collected(rev, [], [U.byte5(a)], b, t, out, Equal.cong(U32, List<&2, U32>, x => [x], U.byte5(a), b, inv), ih(U.Need2{a, rev}, out, h))
    case U.Lead3{+a}:
      collected(rev, [], [U.byte4(a)], b, t, out, Equal.cong(U32, List<&2, U32>, x => [x], U.byte4(a), b, inv), ih(U.Need3{a, rev}, out, h))
    case U.Lead4{+a}:
      collected(rev, [], [U.byte3(a)], b, t, out, Equal.cong(U32, List<&2, U32>, x => [x], U.byte3(a), b, inv), ih(U.Need4{a, rev}, out, h))
    case U.Invalid{}:
      bad_end(Sound(b <> t, U.UtfReady{rev}, out), t, out, h)

def step_need2(+a0: Bool, +a1: Bool, +a2: Bool, +a3: Bool, +a4: Bool, +rev: String, +b: U32, +t: List<&2, U32>, +out: String, +v: U.Byte, inv: Inv(b, v), h: {U.decode_go(t, U.advance(U.Need2{WCon{a0, WCon{a1, WCon{a2, WCon{a3, WCon{a4, WNil{}}}}}}, rev}, v)) == Some{out} : Maybe<&2, String>}, ih: @st:U.State -> @o:String -> {U.decode_go(t, st) == Some{o} : Maybe<&2, String>} -> Sound(t, st, o)) -> Sound(b <> t, U.Need2{WCon{a0, WCon{a1, WCon{a2, WCon{a3, WCon{a4, WNil{}}}}}}, rev}, out):
  match v:
    case U.Ascii{w}:
      bad_end(Sound(b <> t, U.Need2{WCon{a0, WCon{a1, WCon{a2, WCon{a3, WCon{a4, WNil{}}}}}}, rev}, out), t, out, h)
    case U.Continuation{WCon{+c0, WCon{+c1, WCon{+c2, WCon{+c3, WCon{+c4, WCon{+c5, WNil{}}}}}}}}:
      fin11(rev, b, t, out, c0, c1, c2, c3, c4, c5, a0, a1, a2, a3, a4, Bool.not(U.zero(4n, U.high(7n, 4n, U.join(6n, 5n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WCon{a3, WCon{a4, WNil{}}}}}})))) && U.scalar(U32{U.join(11n, 21n, U.join(6n, 5n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WCon{a3, WCon{a4, WNil{}}}}}}), Word.zero(21n))}), {==}, inv, h, ih)
    case U.Lead2{w}:
      bad_end(Sound(b <> t, U.Need2{WCon{a0, WCon{a1, WCon{a2, WCon{a3, WCon{a4, WNil{}}}}}}, rev}, out), t, out, h)
    case U.Lead3{w}:
      bad_end(Sound(b <> t, U.Need2{WCon{a0, WCon{a1, WCon{a2, WCon{a3, WCon{a4, WNil{}}}}}}, rev}, out), t, out, h)
    case U.Lead4{w}:
      bad_end(Sound(b <> t, U.Need2{WCon{a0, WCon{a1, WCon{a2, WCon{a3, WCon{a4, WNil{}}}}}}, rev}, out), t, out, h)
    case U.Invalid{}:
      bad_end(Sound(b <> t, U.Need2{WCon{a0, WCon{a1, WCon{a2, WCon{a3, WCon{a4, WNil{}}}}}}, rev}, out), t, out, h)

def step_need3(+a0: Bool, +a1: Bool, +a2: Bool, +a3: Bool, +rev: String, +b: U32, +t: List<&2, U32>, +out: String, +v: U.Byte, inv: Inv(b, v), h: {U.decode_go(t, U.advance(U.Need3{WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}}, rev}, v)) == Some{out} : Maybe<&2, String>}, ih: @st:U.State -> @o:String -> {U.decode_go(t, st) == Some{o} : Maybe<&2, String>} -> Sound(t, st, o)) -> Sound(b <> t, U.Need3{WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}}, rev}, out):
  match v:
    case U.Ascii{w}:
      bad_end(Sound(b <> t, U.Need3{WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}}, rev}, out), t, out, h)
    case U.Continuation{+c}:
      collected(rev, [U.byte4(WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}})], [U.byte4(WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}}), U.byte6(c)], b, t, out, Equal.cong(U32, List<&2, U32>, x => [U.byte4(WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}}), x], U.byte6(c), b, inv), ih(U.Need3Tail{WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}}, c, rev}, out, h))
    case U.Lead2{w}:
      bad_end(Sound(b <> t, U.Need3{WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}}, rev}, out), t, out, h)
    case U.Lead3{w}:
      bad_end(Sound(b <> t, U.Need3{WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}}, rev}, out), t, out, h)
    case U.Lead4{w}:
      bad_end(Sound(b <> t, U.Need3{WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}}, rev}, out), t, out, h)
    case U.Invalid{}:
      bad_end(Sound(b <> t, U.Need3{WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}}, rev}, out), t, out, h)

def step_need3tail(+a0: Bool, +a1: Bool, +a2: Bool, +a3: Bool, +b0: Bool, +b1: Bool, +b2: Bool, +b3: Bool, +b4: Bool, +b5: Bool, +rev: String, +b: U32, +t: List<&2, U32>, +out: String, +v: U.Byte, inv: Inv(b, v), h: {U.decode_go(t, U.advance(U.Need3Tail{WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}}, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, rev}, v)) == Some{out} : Maybe<&2, String>}, ih: @st:U.State -> @o:String -> {U.decode_go(t, st) == Some{o} : Maybe<&2, String>} -> Sound(t, st, o)) -> Sound(b <> t, U.Need3Tail{WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}}, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, rev}, out):
  match v:
    case U.Ascii{w}:
      bad_end(Sound(b <> t, U.Need3Tail{WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}}, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, rev}, out), t, out, h)
    case U.Continuation{WCon{+c0, WCon{+c1, WCon{+c2, WCon{+c3, WCon{+c4, WCon{+c5, WNil{}}}}}}}}:
      fin16(rev, b, t, out, c0, c1, c2, c3, c4, c5, b0, b1, b2, b3, b4, b5, a0, a1, a2, a3, Bool.not(U.zero(5n, U.high(11n, 5n, U.join(6n, 10n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, U.join(6n, 4n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}}))))) && U.scalar(U32{U.join(16n, 16n, U.join(6n, 10n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, U.join(6n, 4n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}})), Word.zero(16n))}), {==}, inv, h, ih)
    case U.Lead2{w}:
      bad_end(Sound(b <> t, U.Need3Tail{WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}}, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, rev}, out), t, out, h)
    case U.Lead3{w}:
      bad_end(Sound(b <> t, U.Need3Tail{WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}}, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, rev}, out), t, out, h)
    case U.Lead4{w}:
      bad_end(Sound(b <> t, U.Need3Tail{WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}}, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, rev}, out), t, out, h)
    case U.Invalid{}:
      bad_end(Sound(b <> t, U.Need3Tail{WCon{a0, WCon{a1, WCon{a2, WCon{a3, WNil{}}}}}, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, rev}, out), t, out, h)

def step_need4(+a0: Bool, +a1: Bool, +a2: Bool, +rev: String, +b: U32, +t: List<&2, U32>, +out: String, +v: U.Byte, inv: Inv(b, v), h: {U.decode_go(t, U.advance(U.Need4{WCon{a0, WCon{a1, WCon{a2, WNil{}}}}, rev}, v)) == Some{out} : Maybe<&2, String>}, ih: @st:U.State -> @o:String -> {U.decode_go(t, st) == Some{o} : Maybe<&2, String>} -> Sound(t, st, o)) -> Sound(b <> t, U.Need4{WCon{a0, WCon{a1, WCon{a2, WNil{}}}}, rev}, out):
  match v:
    case U.Ascii{w}:
      bad_end(Sound(b <> t, U.Need4{WCon{a0, WCon{a1, WCon{a2, WNil{}}}}, rev}, out), t, out, h)
    case U.Continuation{+c}:
      collected(rev, [U.byte3(WCon{a0, WCon{a1, WCon{a2, WNil{}}}})], [U.byte3(WCon{a0, WCon{a1, WCon{a2, WNil{}}}}), U.byte6(c)], b, t, out, Equal.cong(U32, List<&2, U32>, x => [U.byte3(WCon{a0, WCon{a1, WCon{a2, WNil{}}}}), x], U.byte6(c), b, inv), ih(U.Need4Mid{WCon{a0, WCon{a1, WCon{a2, WNil{}}}}, c, rev}, out, h))
    case U.Lead2{w}:
      bad_end(Sound(b <> t, U.Need4{WCon{a0, WCon{a1, WCon{a2, WNil{}}}}, rev}, out), t, out, h)
    case U.Lead3{w}:
      bad_end(Sound(b <> t, U.Need4{WCon{a0, WCon{a1, WCon{a2, WNil{}}}}, rev}, out), t, out, h)
    case U.Lead4{w}:
      bad_end(Sound(b <> t, U.Need4{WCon{a0, WCon{a1, WCon{a2, WNil{}}}}, rev}, out), t, out, h)
    case U.Invalid{}:
      bad_end(Sound(b <> t, U.Need4{WCon{a0, WCon{a1, WCon{a2, WNil{}}}}, rev}, out), t, out, h)

def step_need4mid(+a0: Bool, +a1: Bool, +a2: Bool, +b0: Bool, +b1: Bool, +b2: Bool, +b3: Bool, +b4: Bool, +b5: Bool, +rev: String, +b: U32, +t: List<&2, U32>, +out: String, +v: U.Byte, inv: Inv(b, v), h: {U.decode_go(t, U.advance(U.Need4Mid{WCon{a0, WCon{a1, WCon{a2, WNil{}}}}, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, rev}, v)) == Some{out} : Maybe<&2, String>}, ih: @st:U.State -> @o:String -> {U.decode_go(t, st) == Some{o} : Maybe<&2, String>} -> Sound(t, st, o)) -> Sound(b <> t, U.Need4Mid{WCon{a0, WCon{a1, WCon{a2, WNil{}}}}, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, rev}, out):
  match v:
    case U.Ascii{w}:
      bad_end(Sound(b <> t, U.Need4Mid{WCon{a0, WCon{a1, WCon{a2, WNil{}}}}, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, rev}, out), t, out, h)
    case U.Continuation{+c}:
      collected(rev, [U.byte3(WCon{a0, WCon{a1, WCon{a2, WNil{}}}}), U.byte6(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}})], [U.byte3(WCon{a0, WCon{a1, WCon{a2, WNil{}}}}), U.byte6(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}), U.byte6(c)], b, t, out, Equal.cong(U32, List<&2, U32>, x => [U.byte3(WCon{a0, WCon{a1, WCon{a2, WNil{}}}}), U.byte6(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}), x], U.byte6(c), b, inv), ih(U.Need4Tail{WCon{a0, WCon{a1, WCon{a2, WNil{}}}}, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, c, rev}, out, h))
    case U.Lead2{w}:
      bad_end(Sound(b <> t, U.Need4Mid{WCon{a0, WCon{a1, WCon{a2, WNil{}}}}, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, rev}, out), t, out, h)
    case U.Lead3{w}:
      bad_end(Sound(b <> t, U.Need4Mid{WCon{a0, WCon{a1, WCon{a2, WNil{}}}}, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, rev}, out), t, out, h)
    case U.Lead4{w}:
      bad_end(Sound(b <> t, U.Need4Mid{WCon{a0, WCon{a1, WCon{a2, WNil{}}}}, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, rev}, out), t, out, h)
    case U.Invalid{}:
      bad_end(Sound(b <> t, U.Need4Mid{WCon{a0, WCon{a1, WCon{a2, WNil{}}}}, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, rev}, out), t, out, h)

def step_need4tail(+a0: Bool, +a1: Bool, +a2: Bool, +b0: Bool, +b1: Bool, +b2: Bool, +b3: Bool, +b4: Bool, +b5: Bool, +c0: Bool, +c1: Bool, +c2: Bool, +c3: Bool, +c4: Bool, +c5: Bool, +rev: String, +b: U32, +t: List<&2, U32>, +out: String, +v: U.Byte, inv: Inv(b, v), h: {U.decode_go(t, U.advance(U.Need4Tail{WCon{a0, WCon{a1, WCon{a2, WNil{}}}}, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, rev}, v)) == Some{out} : Maybe<&2, String>}, ih: @st:U.State -> @o:String -> {U.decode_go(t, st) == Some{o} : Maybe<&2, String>} -> Sound(t, st, o)) -> Sound(b <> t, U.Need4Tail{WCon{a0, WCon{a1, WCon{a2, WNil{}}}}, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, rev}, out):
  match v:
    case U.Ascii{w}:
      bad_end(Sound(b <> t, U.Need4Tail{WCon{a0, WCon{a1, WCon{a2, WNil{}}}}, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, rev}, out), t, out, h)
    case U.Continuation{WCon{+d0, WCon{+d1, WCon{+d2, WCon{+d3, WCon{+d4, WCon{+d5, WNil{}}}}}}}}:
      fin21(rev, b, t, out, d0, d1, d2, d3, d4, d5, c0, c1, c2, c3, c4, c5, b0, b1, b2, b3, b4, b5, a0, a1, a2, Bool.not(U.zero(5n, U.high(16n, 5n, U.join(6n, 15n, WCon{d0, WCon{d1, WCon{d2, WCon{d3, WCon{d4, WCon{d5, WNil{}}}}}}}, U.join(6n, 9n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, U.join(6n, 3n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WNil{}}}})))))) && U.scalar(U32{U.join(21n, 11n, U.join(6n, 15n, WCon{d0, WCon{d1, WCon{d2, WCon{d3, WCon{d4, WCon{d5, WNil{}}}}}}}, U.join(6n, 9n, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, U.join(6n, 3n, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, WCon{a0, WCon{a1, WCon{a2, WNil{}}}}))), Word.zero(11n))}), {==}, inv, h, ih)
    case U.Lead2{w}:
      bad_end(Sound(b <> t, U.Need4Tail{WCon{a0, WCon{a1, WCon{a2, WNil{}}}}, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, rev}, out), t, out, h)
    case U.Lead3{w}:
      bad_end(Sound(b <> t, U.Need4Tail{WCon{a0, WCon{a1, WCon{a2, WNil{}}}}, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, rev}, out), t, out, h)
    case U.Lead4{w}:
      bad_end(Sound(b <> t, U.Need4Tail{WCon{a0, WCon{a1, WCon{a2, WNil{}}}}, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, rev}, out), t, out, h)
    case U.Invalid{}:
      bad_end(Sound(b <> t, U.Need4Tail{WCon{a0, WCon{a1, WCon{a2, WNil{}}}}, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}, WCon{c0, WCon{c1, WCon{c2, WCon{c3, WCon{c4, WCon{c5, WNil{}}}}}}}, rev}, out), t, out, h)

def at_byte(+s: U.State, +b: U32, +t: List<&2, U32>, +out: String, h: {U.decode_go(b <> t, s) == Some{out} : Maybe<&2, String>}, ih: @st:U.State -> @o:String -> {U.decode_go(t, st) == Some{o} : Maybe<&2, String>} -> Sound(t, st, o)) -> Sound(b <> t, s, out):
  match s:
    case U.UtfReady{+rev}: step_ready(rev, b, t, out, U.byte_view(b), view_inv(b), h, ih)
    case U.Need2{WCon{+a0, WCon{+a1, WCon{+a2, WCon{+a3, WCon{+a4, WNil{}}}}}}, +rev}: step_need2(a0, a1, a2, a3, a4, rev, b, t, out, U.byte_view(b), view_inv(b), h, ih)
    case U.Need3{WCon{+a0, WCon{+a1, WCon{+a2, WCon{+a3, WNil{}}}}}, +rev}: step_need3(a0, a1, a2, a3, rev, b, t, out, U.byte_view(b), view_inv(b), h, ih)
    case U.Need3Tail{WCon{+a0, WCon{+a1, WCon{+a2, WCon{+a3, WNil{}}}}}, WCon{+b0, WCon{+b1, WCon{+b2, WCon{+b3, WCon{+b4, WCon{+b5, WNil{}}}}}}}, +rev}: step_need3tail(a0, a1, a2, a3, b0, b1, b2, b3, b4, b5, rev, b, t, out, U.byte_view(b), view_inv(b), h, ih)
    case U.Need4{WCon{+a0, WCon{+a1, WCon{+a2, WNil{}}}}, +rev}: step_need4(a0, a1, a2, rev, b, t, out, U.byte_view(b), view_inv(b), h, ih)
    case U.Need4Mid{WCon{+a0, WCon{+a1, WCon{+a2, WNil{}}}}, WCon{+b0, WCon{+b1, WCon{+b2, WCon{+b3, WCon{+b4, WCon{+b5, WNil{}}}}}}}, +rev}: step_need4mid(a0, a1, a2, b0, b1, b2, b3, b4, b5, rev, b, t, out, U.byte_view(b), view_inv(b), h, ih)
    case U.Need4Tail{WCon{+a0, WCon{+a1, WCon{+a2, WNil{}}}}, WCon{+b0, WCon{+b1, WCon{+b2, WCon{+b3, WCon{+b4, WCon{+b5, WNil{}}}}}}}, WCon{+c0, WCon{+c1, WCon{+c2, WCon{+c3, WCon{+c4, WCon{+c5, WNil{}}}}}}}, +rev}: step_need4tail(a0, a1, a2, b0, b1, b2, b3, b4, b5, c0, c1, c2, c3, c4, c5, rev, b, t, out, U.byte_view(b), view_inv(b), h, ih)
    case U.Bad{}: UP.absurd(Sound(b <> t, U.Bad{}, out), none_some(out, h))

def at_end(+s: U.State, +out: String, h: {U.decode_go([], s) == Some{out} : Maybe<&2, String>}) -> Sound([], s, out):
  match s:
    case U.UtfReady{+rev}: ("", (Equal.sym(String, String.reverse.go(rev, ""), out, some_inj(String.reverse.go(rev, ""), out, h)), ({==}, {==})))
    case U.Need2{a, rev}: UP.absurd(Sound([], U.Need2{a, rev}, out), none_some(out, h))
    case U.Need3{a, rev}: UP.absurd(Sound([], U.Need3{a, rev}, out), none_some(out, h))
    case U.Need3Tail{a, x, rev}: UP.absurd(Sound([], U.Need3Tail{a, x, rev}, out), none_some(out, h))
    case U.Need4{a, rev}: UP.absurd(Sound([], U.Need4{a, rev}, out), none_some(out, h))
    case U.Need4Mid{a, x, rev}: UP.absurd(Sound([], U.Need4Mid{a, x, rev}, out), none_some(out, h))
    case U.Need4Tail{a, x, y, rev}: UP.absurd(Sound([], U.Need4Tail{a, x, y, rev}, out), none_some(out, h))
    case U.Bad{}: UP.absurd(Sound([], U.Bad{}, out), none_some(out, h))

def sound(+xs: List<&2, U32>, +s: U.State, +out: String, h: {U.decode_go(xs, s) == Some{out} : Maybe<&2, String>}) -> Sound(xs, s, out):
  match xs:
    case Nil{}: at_end(s, out, h)
    case +b <> +t: at_byte(s, b, t, out, h, st => o => e => sound(t, st, o, e))

def decoded_of(+xs: List<&2, U32>, +v: String, r: Sound(xs, U.UtfReady{""}, v)) -> {U.valid(v) == True{} : Bool} & {U.encode(v) == xs : List<&2, U32>}:
  match r:
    case (+w, (e1, (e2, e3))):
      %Equal.sym(String, v, w, e1) : {U.valid(_) == True{} : Bool} & {U.encode(_) == xs : List<&2, U32>}
      (Equal.trans(Bool, U.valid(w), U.valid_spec(w), True{}, UP.valid_equiv(w), e3), Equal.trans(List<&2, U32>, U.encode(w), U.encode_spec(w), xs, UP.encode_equiv(w), e2))

# Strict UTF-8 decoding returns only scalar strings, and the string it
# returns encodes back to exactly the input octets.
def decoded(+xs: List<&2, U32>, +v: String, h: {U.decode(xs) == Some{v} : Maybe<&2, String>}) -> {U.valid(v) == True{} : Bool} & {U.encode(v) == xs : List<&2, U32>}:
  decoded_of(xs, v, sound(xs, U.UtfReady{""}, v, h))

