# Small strict codec, reusable by data parsers and future router decoding.
import Base

def scalar(+c: U32) -> Bool:
  (c <= 1114111 : U32) && Bool.not((c >= 55296 : U32) && (c <= 57343 : U32))

def valid(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{c}, t}:
      scalar(c) && valid(t)

# Words are little endian. Keep payload chunks structural so the inverse
# does not depend on arithmetic identities for shifts, masks and carries.
def join(+n: Nat, +m: Nat, a: Word(n), b: Word(m)) -> Word(Nat.add(n, m)):
  match n:
    case 0n:
      b
    case 1n+p:
      match a:
        case WCon{h, t}:
          WCon{h, join(p, m, t, b)}

def low(+n: Nat, +m: Nat, w: Word(Nat.add(n, m))) -> Word(n):
  match n:
    case 0n:
      WNil{}
    case 1n+p:
      match w:
        case WCon{h, t}:
          WCon{h, low(p, m, t)}

def high(+n: Nat, +m: Nat, w: Word(Nat.add(n, m))) -> Word(m):
  match n:
    case 0n:
      w
    case 1n+p:
      match w:
        case WCon{h, t}:
          high(p, m, t)

def zero(n: Nat, w: Word(n)) -> Bool:
  match n:
    case 0n:
      True{}
    case 1n+p:
      match w:
        case WCon{False{}, t}:
          zero(p, t)
        case WCon{True{}, t}:
          False{}

def code7(w: Word(7n)) -> U32:
  U32{join(7n, 25n, w, Word.zero(25n))}

def byte6(w: Word(6n)) -> U32:
  U32{join(6n, 26n, w, WCon{False{}, WCon{True{}, Word.zero(24n)}})}

def byte5(w: Word(5n)) -> U32:
  U32{join(5n, 27n, w, WCon{False{}, WCon{True{}, WCon{True{}, Word.zero(24n)}}})}

def byte4(w: Word(4n)) -> U32:
  U32{join(4n, 28n, w, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, Word.zero(24n)}}}})}

def byte3(w: Word(3n)) -> U32:
  U32{join(3n, 29n, w, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, Word.zero(24n)}}}}})}

def encode7(w: Word(7n)) -> List<&2, U32>:
  [code7(w)]

def encode11_go(+w: Word(11n), small: Bool) -> List<&2, U32>:
  match small:
    case True{}:
      encode7(low(7n, 4n, w))
    case False{}:
      [byte5(high(6n, 5n, w)), byte6(low(6n, 5n, w))]

def encode11(+w: Word(11n)) -> List<&2, U32>:
  encode11_go(w, zero(4n, high(7n, 4n, w)))

def encode16_go(+w: Word(16n), small: Bool) -> List<&2, U32>:
  match small:
    case True{}:
      encode11(low(11n, 5n, w))
    case False{}:
      [byte4(high(12n, 4n, w)), byte6(low(6n, 4n, high(6n, 10n, w))), byte6(low(6n, 10n, w))]

def encode16(+w: Word(16n)) -> List<&2, U32>:
  encode16_go(w, zero(5n, high(11n, 5n, w)))

def encode21_go(+w: Word(21n), small: Bool) -> List<&2, U32>:
  match small:
    case True{}:
      encode16(low(16n, 5n, w))
    case False{}:
      [byte3(high(18n, 3n, w)), byte6(low(6n, 3n, high(12n, 9n, w))), byte6(low(6n, 9n, high(6n, 15n, w))), byte6(low(6n, 15n, w))]

def encode21(+w: Word(21n)) -> List<&2, U32>:
  encode21_go(w, zero(5n, high(16n, 5n, w)))

def encode_fit(w: Word(21n), fits: Bool) -> List<&2, U32>:
  match fits:
    case True{}:
      encode21(w)
    case False{}:
      []

def encode_char(c: U32) -> List<&2, U32>:
  match c:
    case U32{+w}:
      encode_fit(low(21n, 11n, w), zero(11n, high(21n, 11n, w)))

# Recursive reference equation used by the codec proofs.
def encode_spec(s: String) -> List<&2, U32>:
  match s:
    case SNil{}:
      []
    case SCon{Chr{c}, t}:
      List.append(&2, U32, encode_char(c), encode_spec(t))

# Reverse the input, then prepend at most four bytes per scalar. Each
# recursive call is a tail call, including in the JavaScript target.
def encode_go(s: String, acc: List<&2, U32>) -> List<&2, U32>:
  match s:
    case SNil{}:
      acc
    case SCon{Chr{c}, t}:
      encode_go(t, List.append(&2, U32, encode_char(c), acc))

# Callers encoding a String must supply Unicode scalar values (valid).
def encode(s: String) -> List<&2, U32>:
  encode_go(String.reverse(s), [])

type Byte is Data:
  Ascii{w: Word(7n)}
  Continuation{w: Word(6n)}
  Lead2{w: Word(5n)}
  Lead3{w: Word(4n)}
  Lead4{w: Word(3n)}
  Invalid{}

def tag3(tag: Bool, w: Word(3n)) -> Byte:
  match tag:
    case False{}:
      Lead4{w}
    case True{}:
      Invalid{}

def tag4(tag: Bool, w: Word(4n)) -> Byte:
  match tag:
    case False{}:
      Lead3{w}
    case True{}:
      match w:
        case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WNil{}}}}}:
          tag3(b3, WCon{b0, WCon{b1, WCon{b2, WNil{}}}})

def tag5(tag: Bool, w: Word(5n)) -> Byte:
  match tag:
    case False{}:
      Lead2{w}
    case True{}:
      match w:
        case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WNil{}}}}}}:
          tag4(b4, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WNil{}}}}})

def tag6(tag: Bool, w: Word(6n)) -> Byte:
  match tag:
    case False{}:
      Continuation{w}
    case True{}:
      match w:
        case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}:
          tag5(b5, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WNil{}}}}}})

def tag7(tag: Bool, w: Word(7n)) -> Byte:
  match tag:
    case False{}:
      Ascii{w}
    case True{}:
      match w:
        case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WNil{}}}}}}}}:
          tag6(b6, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}})

def view8(w: Word(8n)) -> Byte:
  match w:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WNil{}}}}}}}}}:
      tag7(b7, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WNil{}}}}}}}})

def byte_view_go(w: Word(8n), octet: Bool) -> Byte:
  match octet:
    case True{}:
      view8(w)
    case False{}:
      Invalid{}

def byte_view(b: U32) -> Byte:
  match b:
    case U32{+w}:
      byte_view_go(low(8n, 24n, w), zero(24n, high(8n, 24n, w)))

type State is Data:
  UtfReady{reversed: String}
  Need2{a: Word(5n), reversed: String}
  Need3{a: Word(4n), reversed: String}
  Need3Tail{a: Word(4n), b: Word(6n), reversed: String}
  Need4{a: Word(3n), reversed: String}
  Need4Mid{a: Word(3n), b: Word(6n), reversed: String}
  Need4Tail{a: Word(3n), b: Word(6n), c: Word(6n), reversed: String}
  Bad{}

def finish(+c: U32, rev: String, ok: Bool) -> State:
  match ok:
    case True{}:
      UtfReady{SCon{Chr{c}, rev}}
    case False{}:
      Bad{}

def complete7(+w: Word(7n), rev: String) -> State:
  +c = code7(w)
  finish(c, rev, scalar(c))

def complete11(+w: Word(11n), rev: String) -> State:
  +c = {U32{join(11n, 21n, w, Word.zero(21n))} : U32}
  finish(c, rev, Bool.not(zero(4n, high(7n, 4n, w))) && scalar(c))

def complete16(+w: Word(16n), rev: String) -> State:
  +c = {U32{join(16n, 16n, w, Word.zero(16n))} : U32}
  finish(c, rev, Bool.not(zero(5n, high(11n, 5n, w))) && scalar(c))

def complete21(+w: Word(21n), rev: String) -> State:
  +c = {U32{join(21n, 11n, w, Word.zero(11n))} : U32}
  finish(c, rev, Bool.not(zero(5n, high(16n, 5n, w))) && scalar(c))

def advance(s: State, b: Byte) -> State:
  match s b:
    case UtfReady{rev} Ascii{w}:
      complete7(w, rev)
    case UtfReady{rev} Lead2{w}:
      Need2{w, rev}
    case UtfReady{rev} Lead3{w}:
      Need3{w, rev}
    case UtfReady{rev} Lead4{w}:
      Need4{w, rev}
    case Need2{a, rev} Continuation{b}:
      complete11(join(6n, 5n, b, a), rev)
    case Need3{a, rev} Continuation{b}:
      Need3Tail{a, b, rev}
    case Need3Tail{a, b, rev} Continuation{c}:
      complete16(join(6n, 10n, c, join(6n, 4n, b, a)), rev)
    case Need4{a, rev} Continuation{b}:
      Need4Mid{a, b, rev}
    case Need4Mid{a, b, rev} Continuation{c}:
      Need4Tail{a, b, c, rev}
    case Need4Tail{a, b, c, rev} Continuation{d}:
      complete21(join(6n, 15n, d, join(6n, 9n, c, join(6n, 3n, b, a))), rev)
    case _ _:
      Bad{}

def decode_go(xs: List<&2, U32>, s: State) -> Maybe<&2, String>:
  match xs s:
    case _ Bad{}:
      None{}
    case Nil{} UtfReady{rev}:
      Some{String.reverse(rev)}
    case Nil{} _:
      None{}
    case b <> t st:
      decode_go(t, advance(st, byte_view(b)))

# Reject non-octets, overlong encodings, surrogates, out-of-range scalars,
# stray continuation bytes and incomplete sequences. No replacement decoding.
def decode(xs: List<&2, U32>) -> Maybe<&2, String>:
  decode_go(xs, UtfReady{""})
