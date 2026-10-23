# Structural UTF-8 payloads. Raw reading is separate from scalar and
# canonical-length validation: an overlong form can be read but must not pass
# the validated decoder.
import Base
import ./codec-bits.bend as Bits


type Code is Data:
  One{bits: Word(7n)}
  Two{bits: Word(11n)}
  Three{bits: Word(16n)}
  Four{bits: Word(21n)}

type Read is Data:
  Read{code: Code, tail: List<&2, U32>}

def value(code: Code) -> U32:
  match code:
    case One{bits}:
      U32{Bits.pad(7n, 25n, bits)}
    case Two{bits}:
      U32{Bits.pad(11n, 21n, bits)}
    case Three{bits}:
      U32{Bits.pad(16n, 16n, bits)}
    case Four{bits}:
      U32{Bits.pad(21n, 11n, bits)}

def octets(code: Code) -> List<&2, Word(8n)>:
  match code:
    case One{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WNil{}}}}}}}}}:
      [WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{False{}, WNil{}}}}}}}}}]
    case Two{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WNil{}}}}}}}}}}}}}:
      [WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}}, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{False{}, WCon{True{}, WNil{}}}}}}}}}]
    case Three{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WNil{}}}}}}}}}}}}}}}}}}:
      [WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}}, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{False{}, WCon{True{}, WNil{}}}}}}}}}, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{False{}, WCon{True{}, WNil{}}}}}}}}}]
    case Four{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WNil{}}}}}}}}}}}}}}}}}}}}}}}:
      [WCon{b18, WCon{b19, WCon{b20, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}}, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{False{}, WCon{True{}, WNil{}}}}}}}}}, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{False{}, WCon{True{}, WNil{}}}}}}}}}, WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{False{}, WCon{True{}, WNil{}}}}}}}}}]

def octet(w: Word(8n)) -> U32:
  U32{Bits.pad(8n, 24n, w)}

def bytes_of(xs: List<&2, Word(8n)>) -> List<&2, U32>:
  match xs:
    case Nil{}:
      Nil{}
    case h <> t:
      octet(h) <> bytes_of(t)

def bytes(code: Code) -> List<&2, U32>:
  bytes_of(octets(code))

def read_two(hi: Word(5n), bs: List<&2, U32>) -> Maybe<&2, Read>:
  match bs:
    case U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}} <> tail:
      Some{Read{Two{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, hi}}}}}}}, tail}}
    case _:
      None{}

def read_three(hi: Word(4n), bs: List<&2, U32>) -> Maybe<&2, Read>:
  match bs:
    case U32{WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}} <> U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}} <> tail:
      Some{Read{Three{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, hi}}}}}}}}}}}}}, tail}}
    case _:
      None{}

def read_four(hi: Word(3n), bs: List<&2, U32>) -> Maybe<&2, Read>:
  match bs:
    case U32{WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}} <> U32{WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}} <> U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}} <> tail:
      Some{Read{Four{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, hi}}}}}}}}}}}}}}}}}}}, tail}}
    case _:
      None{}

def flip(n: U32) -> Word(32n):
  match n:
    case U32{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WCon{b21, WCon{b22, WCon{b23, WCon{b24, WCon{b25, WCon{b26, WCon{b27, WCon{b28, WCon{b29, WCon{b30, WCon{b31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      WCon{b31, WCon{b30, WCon{b29, WCon{b28, WCon{b27, WCon{b26, WCon{b25, WCon{b24, WCon{b23, WCon{b22, WCon{b21, WCon{b20, WCon{b19, WCon{b18, WCon{b17, WCon{b16, WCon{b15, WCon{b14, WCon{b13, WCon{b12, WCon{b11, WCon{b10, WCon{b9, WCon{b8, WCon{b7, WCon{b6, WCon{b5, WCon{b4, WCon{b3, WCon{b2, WCon{b1, WCon{b0, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}

def read_head_bits(h: Word(32n), tail: List<&2, U32>) -> Maybe<&2, Read>:
  match h:
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{b6, WCon{b5, WCon{b4, WCon{b3, WCon{b2, WCon{b1, WCon{b0, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      Some{Read{One{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WNil{}}}}}}}}}, tail}}
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{b4, WCon{b3, WCon{b2, WCon{b1, WCon{b0, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      read_two(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WNil{}}}}}}, tail)
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{b3, WCon{b2, WCon{b1, WCon{b0, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      read_three(WCon{b0, WCon{b1, WCon{b2, WCon{b3, WNil{}}}}}, tail)
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{b2, WCon{b1, WCon{b0, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      read_four(WCon{b0, WCon{b1, WCon{b2, WNil{}}}}, tail)
    case _:
      None{}

def read_head(h: U32, tail: List<&2, U32>) -> Maybe<&2, Read>:
  read_head_bits(flip(h), tail)

def read(bs: List<&2, U32>) -> Maybe<&2, Read>:
  match bs:
    case Nil{}:
      None{}
    case h <> t:
      read_head(h, t)

# Prefix stripping and payload reconstruction work for every bit assignment,
# independently of whether the resulting form is canonical or a valid scalar.
law read_bytes_suffix:
  for +code: Code
  for +tail: List<&2, U32>
  {read(List.append(&2, U32, bytes(code), tail)) == Some{Read{code, tail}} : Maybe<&2, Read>}

def read_bytes_suffix(code, tail):
  match code:
    case One{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WNil{}}}}}}}}}:
      {==}
    case Two{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WNil{}}}}}}}}}}}}}:
      {==}
    case Three{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WNil{}}}}}}}}}}}}}}}}}}:
      {==}
    case Four{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WNil{}}}}}}}}}}}}}}}}}}}}}}}:
      {==}

# A total representation keeps out-of-range input explicit.
type Representation is Data:
  Packed{code: Code}
  Outside{raw: U32}

def represented(r: Representation) -> U32:
  match r:
    case Packed{code}:
      value(code)
    case Outside{raw}:
      raw

def select11(+lo: Word(7n), +hi: Word(4n), zero: Bool) -> Representation:
  match zero:
    case True{}:
      Packed{One{lo}}
    case False{}:
      Packed{Two{Bits.cat(7n, 4n, lo, hi)}}

def parts11(p: Word(7n) & Word(4n)) -> Representation:
  (lo, +hi) = p
  select11(lo, hi, Bits.zeros(4n, hi))

def from11(w: Word(11n)) -> Representation:
  parts11(Bits.split(7n, 4n, w))

def select11_value(+lo: Word(7n), +hi: Word(4n), +zero: Bool,
    decision: {Bits.zeros(4n, hi) == zero : Bool}) ->
    {represented(select11(lo, hi, zero)) == U32{Bits.pad(11n, 21n, Bits.cat(7n, 4n, lo, hi))} : U32}:
  match lo:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WNil{}}}}}}}}:
      match zero:
        case True{}:
          %Equal.sym(Word(4n), hi, Word.zero(4n), Bits.zeros_sound(4n, hi, decision)) : {represented(Packed{One{lo}}) == U32{Bits.pad(11n, 21n, Bits.cat(7n, 4n, lo, _))} : U32}
          {==}
        case False{}:
          {==}

def parts11_value(p: Word(7n) & Word(4n)) ->
    {represented(parts11(p)) == U32{Bits.pad(11n, 21n, Bits.rejoin(7n, 4n, p))} : U32}:
  match p:
    case (+lo, +hi):
      select11_value(lo, hi, Bits.zeros(4n, hi), {==})

def from11_value(+w: Word(11n)) -> {represented(from11(w)) == U32{Bits.pad(11n, 21n, w)} : U32}:
  Equal.trans(U32, represented(from11(w)), U32{Bits.pad(11n, 21n, Bits.rejoin(7n, 4n, Bits.split(7n, 4n, w)))}, U32{Bits.pad(11n, 21n, w)}, parts11_value(Bits.split(7n, 4n, w)), Equal.cong(Word(11n), U32, x => U32{Bits.pad(11n, 21n, x)}, Bits.rejoin(7n, 4n, Bits.split(7n, 4n, w)), w, Bits.cat_split(7n, 4n, w)))

def select16(+lo: Word(11n), +hi: Word(5n), zero: Bool) -> Representation:
  match zero:
    case True{}:
      from11(lo)
    case False{}:
      Packed{Three{Bits.cat(11n, 5n, lo, hi)}}

def parts16(p: Word(11n) & Word(5n)) -> Representation:
  (lo, +hi) = p
  select16(lo, hi, Bits.zeros(5n, hi))

def from16(w: Word(16n)) -> Representation:
  parts16(Bits.split(11n, 5n, w))

def select16_value(+lo: Word(11n), +hi: Word(5n), +zero: Bool,
    decision: {Bits.zeros(5n, hi) == zero : Bool}) ->
    {represented(select16(lo, hi, zero)) == U32{Bits.pad(16n, 16n, Bits.cat(11n, 5n, lo, hi))} : U32}:
  match lo:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WNil{}}}}}}}}}}}}:
      match zero:
        case True{}:
          %Equal.sym(Word(5n), hi, Word.zero(5n), Bits.zeros_sound(5n, hi, decision)) : {represented(from11(lo)) == U32{Bits.pad(16n, 16n, Bits.cat(11n, 5n, lo, _))} : U32}
          %Equal.sym(U32, represented(from11(lo)), U32{Bits.pad(11n, 21n, lo)}, from11_value(lo)) : {_ == U32{Bits.pad(16n, 16n, Bits.cat(11n, 5n, lo, Word.zero(5n)))} : U32}
          {==}
        case False{}:
          {==}

def parts16_value(p: Word(11n) & Word(5n)) ->
    {represented(parts16(p)) == U32{Bits.pad(16n, 16n, Bits.rejoin(11n, 5n, p))} : U32}:
  match p:
    case (+lo, +hi):
      select16_value(lo, hi, Bits.zeros(5n, hi), {==})

def from16_value(+w: Word(16n)) -> {represented(from16(w)) == U32{Bits.pad(16n, 16n, w)} : U32}:
  Equal.trans(U32, represented(from16(w)), U32{Bits.pad(16n, 16n, Bits.rejoin(11n, 5n, Bits.split(11n, 5n, w)))}, U32{Bits.pad(16n, 16n, w)}, parts16_value(Bits.split(11n, 5n, w)), Equal.cong(Word(16n), U32, x => U32{Bits.pad(16n, 16n, x)}, Bits.rejoin(11n, 5n, Bits.split(11n, 5n, w)), w, Bits.cat_split(11n, 5n, w)))

def select21(+lo: Word(16n), +hi: Word(5n), zero: Bool) -> Representation:
  match zero:
    case True{}:
      from16(lo)
    case False{}:
      Packed{Four{Bits.cat(16n, 5n, lo, hi)}}

def parts21(p: Word(16n) & Word(5n)) -> Representation:
  (lo, +hi) = p
  select21(lo, hi, Bits.zeros(5n, hi))

def from21(w: Word(21n)) -> Representation:
  parts21(Bits.split(16n, 5n, w))

def select21_value(+lo: Word(16n), +hi: Word(5n), +zero: Bool,
    decision: {Bits.zeros(5n, hi) == zero : Bool}) ->
    {represented(select21(lo, hi, zero)) == U32{Bits.pad(21n, 11n, Bits.cat(16n, 5n, lo, hi))} : U32}:
  match lo:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WNil{}}}}}}}}}}}}}}}}}:
      match zero:
        case True{}:
          %Equal.sym(Word(5n), hi, Word.zero(5n), Bits.zeros_sound(5n, hi, decision)) : {represented(from16(lo)) == U32{Bits.pad(21n, 11n, Bits.cat(16n, 5n, lo, _))} : U32}
          %Equal.sym(U32, represented(from16(lo)), U32{Bits.pad(16n, 16n, lo)}, from16_value(lo)) : {_ == U32{Bits.pad(21n, 11n, Bits.cat(16n, 5n, lo, Word.zero(5n)))} : U32}
          {==}
        case False{}:
          {==}

def parts21_value(p: Word(16n) & Word(5n)) ->
    {represented(parts21(p)) == U32{Bits.pad(21n, 11n, Bits.rejoin(16n, 5n, p))} : U32}:
  match p:
    case (+lo, +hi):
      select21_value(lo, hi, Bits.zeros(5n, hi), {==})

def from21_value(+w: Word(21n)) -> {represented(from21(w)) == U32{Bits.pad(21n, 11n, w)} : U32}:
  Equal.trans(U32, represented(from21(w)), U32{Bits.pad(21n, 11n, Bits.rejoin(16n, 5n, Bits.split(16n, 5n, w)))}, U32{Bits.pad(21n, 11n, w)}, parts21_value(Bits.split(16n, 5n, w)), Equal.cong(Word(21n), U32, x => U32{Bits.pad(21n, 11n, x)}, Bits.rejoin(16n, 5n, Bits.split(16n, 5n, w)), w, Bits.cat_split(16n, 5n, w)))

def select32(+lo: Word(21n), +hi: Word(11n), zero: Bool) -> Representation:
  match zero:
    case True{}:
      from21(lo)
    case False{}:
      Outside{U32{Bits.cat(21n, 11n, lo, hi)}}

def parts32(p: Word(21n) & Word(11n)) -> Representation:
  (lo, +hi) = p
  select32(lo, hi, Bits.zeros(11n, hi))

def from32(w: Word(32n)) -> Representation:
  parts32(Bits.split(21n, 11n, w))

def select32_value(+lo: Word(21n), +hi: Word(11n), +zero: Bool,
    decision: {Bits.zeros(11n, hi) == zero : Bool}) ->
    {represented(select32(lo, hi, zero)) == U32{Bits.cat(21n, 11n, lo, hi)} : U32}:
  match lo:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WNil{}}}}}}}}}}}}}}}}}}}}}}:
      match zero:
        case True{}:
          %Equal.sym(Word(11n), hi, Word.zero(11n), Bits.zeros_sound(11n, hi, decision)) : {represented(from21(lo)) == U32{Bits.cat(21n, 11n, lo, _)} : U32}
          %Equal.sym(U32, represented(from21(lo)), U32{Bits.pad(21n, 11n, lo)}, from21_value(lo)) : {_ == U32{Bits.cat(21n, 11n, lo, Word.zero(11n))} : U32}
          {==}
        case False{}:
          {==}

def parts32_value(p: Word(21n) & Word(11n)) ->
    {represented(parts32(p)) == U32{Bits.rejoin(21n, 11n, p)} : U32}:
  match p:
    case (+lo, +hi):
      select32_value(lo, hi, Bits.zeros(11n, hi), {==})

def from32_value(+w: Word(32n)) -> {represented(from32(w)) == U32{w} : U32}:
  Equal.trans(U32, represented(from32(w)), U32{Bits.rejoin(21n, 11n, Bits.split(21n, 11n, w))}, U32{w}, parts32_value(Bits.split(21n, 11n, w)), Equal.cong(Word(32n), U32, x => U32{x}, Bits.rejoin(21n, 11n, Bits.split(21n, 11n, w)), w, Bits.cat_split(21n, 11n, w)))

def represent(n: U32) -> Representation:
  match n:
    case U32{w}:
      from32(w)

law representation_value:
  for +n: U32
  {represented(represent(n)) == n : U32}

def representation_value(n):
  match n:
    case U32{+w}:
      from32_value(w)

def is_packed(r: Representation) -> Bool:
  match r:
    case Packed{code}:
      True{}
    case Outside{raw}:
      False{}

def select11_packed(+lo: Word(7n), +hi: Word(4n), zero: Bool) ->
    {is_packed(select11(lo, hi, zero)) == True{} : Bool}:
  match zero:
    case True{}:
      {==}
    case False{}:
      {==}

def parts11_packed(p: Word(7n) & Word(4n)) -> {is_packed(parts11(p)) == True{} : Bool}:
  match p:
    case (+lo, +hi):
      select11_packed(lo, hi, Bits.zeros(4n, hi))

def from11_packed(+w: Word(11n)) -> {is_packed(from11(w)) == True{} : Bool}:
  parts11_packed(Bits.split(7n, 4n, w))

def select16_packed(+lo: Word(11n), +hi: Word(5n), zero: Bool) ->
    {is_packed(select16(lo, hi, zero)) == True{} : Bool}:
  match zero:
    case True{}:
      from11_packed(lo)
    case False{}:
      {==}

def parts16_packed(p: Word(11n) & Word(5n)) -> {is_packed(parts16(p)) == True{} : Bool}:
  match p:
    case (+lo, +hi):
      select16_packed(lo, hi, Bits.zeros(5n, hi))

def from16_packed(+w: Word(16n)) -> {is_packed(from16(w)) == True{} : Bool}:
  parts16_packed(Bits.split(11n, 5n, w))

def select21_packed(+lo: Word(16n), +hi: Word(5n), zero: Bool) ->
    {is_packed(select21(lo, hi, zero)) == True{} : Bool}:
  match zero:
    case True{}:
      from16_packed(lo)
    case False{}:
      {==}

def parts21_packed(p: Word(16n) & Word(5n)) -> {is_packed(parts21(p)) == True{} : Bool}:
  match p:
    case (+lo, +hi):
      select21_packed(lo, hi, Bits.zeros(5n, hi))

def from21_packed(+w: Word(21n)) -> {is_packed(from21(w)) == True{} : Bool}:
  parts21_packed(Bits.split(16n, 5n, w))


def scalar(+n: U32) -> Bool:
  (n <= 1114111 : U32) && Bool.not((n >= 55296 : U32) && (n <= 57343 : U32))

def code_width(code: Code) -> U32:
  match code:
    case One{bits}:
      1
    case Two{bits}:
      2
    case Three{bits}:
      3
    case Four{bits}:
      4

def width(r: Representation) -> U32:
  match r:
    case Packed{code}:
      code_width(code)
    case Outside{raw}:
      0

def canonical(+code: Code) -> Bool:
  U32.is_eq(width(represent(value(code))), code_width(code))

type State is Data:
  Start{}
  NeedTwo{hi: Word(5n)}
  NeedThree{hi: Word(4n)}
  EndThree{hi: Word(4n), mid: Word(6n)}
  NeedFour{hi: Word(3n)}
  MidFour{hi: Word(3n), upper: Word(6n)}
  EndFour{hi: Word(3n), upper: Word(6n), mid: Word(6n)}

type Step is Data:
  Next{state: State}
  EmitCode{code: Code}

def start_bits(h: Word(32n)) -> Maybe<&2, Step>:
  match h:
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{b6, WCon{b5, WCon{b4, WCon{b3, WCon{b2, WCon{b1, WCon{b0, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      Some{EmitCode{One{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WNil{}}}}}}}}}}}
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{b4, WCon{b3, WCon{b2, WCon{b1, WCon{b0, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      Some{Next{NeedTwo{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WNil{}}}}}}}}}
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{b3, WCon{b2, WCon{b1, WCon{b0, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      Some{Next{NeedThree{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WNil{}}}}}}}}
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{b2, WCon{b1, WCon{b0, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      Some{Next{NeedFour{WCon{b0, WCon{b1, WCon{b2, WNil{}}}}}}}
    case _:
      None{}

def continuation_bits(h: Word(32n)) -> Maybe<&2, Word(6n)>:
  match h:
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{b5, WCon{b4, WCon{b3, WCon{b2, WCon{b1, WCon{b0, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      Some{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WNil{}}}}}}}}
    case _:
      None{}

def continuation(h: U32) -> Maybe<&2, Word(6n)>:
  continuation_bits(flip(h))

def step(state: State, h: U32) -> Maybe<&2, Step>:
  match state:
    case Start{}:
      start_bits(flip(h))
    case NeedTwo{hi}:
      do Maybe<&2, Step>:
        lo : Word(6n) <- continuation(h)
        return EmitCode{Two{Bits.cat(6n, 5n, lo, hi)}}
    case NeedThree{hi}:
      do Maybe<&2, Step>:
        mid : Word(6n) <- continuation(h)
        return Next{EndThree{hi, mid}}
    case EndThree{hi, mid}:
      do Maybe<&2, Step>:
        lo : Word(6n) <- continuation(h)
        return EmitCode{Three{Bits.cat(6n, 10n, lo, Bits.cat(6n, 4n, mid, hi))}}
    case NeedFour{hi}:
      do Maybe<&2, Step>:
        upper : Word(6n) <- continuation(h)
        return Next{MidFour{hi, upper}}
    case MidFour{hi, upper}:
      do Maybe<&2, Step>:
        mid : Word(6n) <- continuation(h)
        return Next{EndFour{hi, upper, mid}}
    case EndFour{hi, upper, mid}:
      do Maybe<&2, Step>:
        lo : Word(6n) <- continuation(h)
        return EmitCode{Four{Bits.cat(6n, 15n, lo, Bits.cat(6n, 9n, mid, Bits.cat(6n, 3n, upper, hi)))}}

def next_state(action: Step) -> State:
  match action:
    case Next{state}:
      state
    case EmitCode{code}:
      Start{}

def emit_valid(+code: Code, tail: Maybe<&2, String>, valid: Bool) -> Maybe<&2, String>:
  match valid:
    case True{}:
      do Maybe<&2, String>:
        rest : String <- tail
        return SCon{Chr{value(code)}, rest}
    case False{}:
      None{}

def finish(action: Step, tail: Maybe<&2, String>) -> Maybe<&2, String>:
  match action:
    case Next{state}:
      tail
    case EmitCode{+code}:
      emit_valid(code, tail, scalar(value(code)) && canonical(code))

def empty(state: State) -> Maybe<&2, String>:
  match state:
    case Start{}:
      Some{SNil{}}
    case _:
      None{}

def decode(bs: List<&2, U32>, state: State) -> Maybe<&2, String>:
  match bs:
    case Nil{}:
      empty(state)
    case h <> t:
      do Maybe<&2, String>:
        +action : Step <- step(state, h)
        finish(action, decode(t, next_state(action)))

# This includes arbitrary malformed suffixes: no assumption about tail is made.
law decode_code_suffix:
  for +code: Code
  for +tail: List<&2, U32>
  {decode(List.append(&2, U32, bytes(code), tail), Start{}) == finish(EmitCode{code}, decode(tail, Start{})) : Maybe<&2, String>}

def decode_code_suffix(code, tail):
  match code:
    case One{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WNil{}}}}}}}}}:
      {==}
    case Two{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WNil{}}}}}}}}}}}}}:
      {==}
    case Three{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WNil{}}}}}}}}}}}}}}}}}}:
      {==}
    case Four{WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WCon{b7, WCon{b8, WCon{b9, WCon{b10, WCon{b11, WCon{b12, WCon{b13, WCon{b14, WCon{b15, WCon{b16, WCon{b17, WCon{b18, WCon{b19, WCon{b20, WNil{}}}}}}}}}}}}}}}}}}}}}}}:
      {==}
