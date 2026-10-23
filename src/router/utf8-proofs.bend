# The structural representation covers every scalar admitted by the existing
# codec boundary. Its scalar predicate is not changed by these proofs.
import Base
import ./encoding.bend as E
import ./codec-bits.bend as Bits
import ./utf8-code.bend as Code
import ./octet-proofs.bend as Octet

law high_scalar_impossible:
  for +lo: Word(21n)
  for +hi: Word(11n)
  for nonzero: {Bits.zeros(11n, hi) == False{} : Bool}
  {E.scalar(U32{Bits.cat(21n, 11n, lo, hi)}) == False{} : Bool}

def high_scalar_impossible(lo, hi, nonzero):
  %Equal.sym(Cmp, Word.cmp(32n, Bits.cat(21n, 11n, lo, hi), Bits.cat(21n, 11n, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}}}}}}}}}}}}}}}, Word.zero(11n))), GT{}, Bits.cmp_high_gt(21n, 11n, lo, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}}}}}}}}}}}}}}}, hi, Bits.cmp_nonzero(11n, hi, nonzero))) : {Cmp.is_le(_) && Bool.not((U32{Bits.cat(21n, 11n, lo, hi)} >= 55296 : U32) && (U32{Bits.cat(21n, 11n, lo, hi)} <= 57343 : U32)) == False{} : Bool}
  {==}

def select32_packed(+lo: Word(21n), +hi: Word(11n), +zero: Bool,
    decision: {Bits.zeros(11n, hi) == zero : Bool},
    valid: {E.scalar(U32{Bits.cat(21n, 11n, lo, hi)}) == True{} : Bool}) ->
    {Code.is_packed(Code.select32(lo, hi, zero)) == True{} : Bool}:
  match zero:
    case True{}:
      Code.from21_packed(lo)
    case False{}:
      Bits.absurd({False{} == True{} : Bool}, Bits.false_true(Equal.trans(Bool, False{}, E.scalar(U32{Bits.cat(21n, 11n, lo, hi)}), True{}, Equal.sym(Bool, E.scalar(U32{Bits.cat(21n, 11n, lo, hi)}), False{}, high_scalar_impossible(lo, hi, decision)), valid)))

def parts32_packed(p: Word(21n) & Word(11n),
    valid: {E.scalar(U32{Bits.rejoin(21n, 11n, p)}) == True{} : Bool}) ->
    {Code.is_packed(Code.parts32(p)) == True{} : Bool}:
  match p:
    case (+lo, +hi):
      select32_packed(lo, hi, Bits.zeros(11n, hi), {==}, valid)

law scalar_is_packed:
  for +n: U32
  for valid: {E.scalar(n) == True{} : Bool}
  {Code.is_packed(Code.represent(n)) == True{} : Bool}

def scalar_is_packed(n, valid):
  match n:
    case U32{+w}:
      parts32_packed(Bits.split(21n, 11n, w), (
        %Equal.sym(Word(32n), Bits.rejoin(21n, 11n, Bits.split(21n, 11n, w)), w, Bits.cat_split(21n, 11n, w)) : {E.scalar(U32{_}) == True{} : Bool}
        valid
      ))

def width_refl(+code: Code.Code) -> {U32.is_eq(Code.code_width(code), Code.code_width(code)) == True{} : Bool}:
  match code:
    case Code.One{bits}:
      {==}
    case Code.Two{bits}:
      {==}
    case Code.Three{bits}:
      {==}
    case Code.Four{bits}:
      {==}

def canonical_selected(+n: U32, +code: Code.Code,
    selected: {Code.represent(n) == Code.Packed{code} : Code.Representation},
    same: {Code.value(code) == n : U32}) -> {Code.canonical(code) == True{} : Bool}:
  %Equal.sym(U32, Code.value(code), n, same) : {U32.is_eq(Code.width(Code.represent(_)), Code.code_width(code)) == True{} : Bool}
  %Equal.sym(Code.Representation, Code.represent(n), Code.Packed{code}, selected) : {U32.is_eq(Code.width(_), Code.code_width(code)) == True{} : Bool}
  width_refl(code)

def and_true(+a: Bool, +b: Bool, left: {a == True{} : Bool}, right: {b == True{} : Bool}) -> {a && b == True{} : Bool}:
  %Equal.sym(Bool, a, True{}, left) : {_ && b == True{} : Bool}
  right

def packed_suffix(+n: U32, +code: Code.Code, +tail: List<&2, U32>,
    selected: {Code.represent(n) == Code.Packed{code} : Code.Representation},
    same: {Code.value(code) == n : U32},
    valid: {E.scalar(n) == True{} : Bool}) ->
    {Code.decode(List.append(&2, U32, Code.bytes(code), tail), Code.Start{}) == Maybe.bind(&2, String, String, Code.decode(tail, Code.Start{}), rest => Some{SCon{Chr{n}, rest}}) : Maybe<&2, String>}:
  +eq = same
  ok = and_true(Code.scalar(Code.value(code)), Code.canonical(code), Equal.trans(Bool, Code.scalar(Code.value(code)), Code.scalar(n), True{}, Equal.cong(U32, Bool, x => Code.scalar(x), Code.value(code), n, eq), valid), canonical_selected(n, code, selected, eq))
  %Equal.sym(Maybe<&2, String>, Code.decode(List.append(&2, U32, Code.bytes(code), tail), Code.Start{}), Code.finish(Code.EmitCode{code}, Code.decode(tail, Code.Start{})), Code.decode_code_suffix(code, tail)) : {_ == Maybe.bind(&2, String, String, Code.decode(tail, Code.Start{}), rest => Some{SCon{Chr{n}, rest}}) : Maybe<&2, String>}
  %Equal.sym(Bool, Code.scalar(Code.value(code)) && Code.canonical(code), True{}, ok) : {Code.emit_valid(code, Code.decode(tail, Code.Start{}), _) == Maybe.bind(&2, String, String, Code.decode(tail, Code.Start{}), rest => Some{SCon{Chr{n}, rest}}) : Maybe<&2, String>}
  Equal.cong(U32, Maybe<&2, String>, x => Maybe.bind(&2, String, String, Code.decode(tail, Code.Start{}), rest => Some{SCon{Chr{x}, rest}}), Code.value(code), n, eq)

def rep_suffix(+n: U32, +r: Code.Representation, +tail: List<&2, U32>,
    selected: {Code.represent(n) == r : Code.Representation},
    same: {Code.represented(r) == n : U32},
    valid: {E.scalar(n) == True{} : Bool},
    packed: {Code.is_packed(r) == True{} : Bool}) ->
    {Code.decode(List.append(&2, U32, E.bytes_rep(r), tail), Code.Start{}) == Maybe.bind(&2, String, String, Code.decode(tail, Code.Start{}), rest => Some{SCon{Chr{n}, rest}}) : Maybe<&2, String>}:
  match r:
    case Code.Packed{+code}:
      packed_suffix(n, code, tail, selected, same, valid)
    case Code.Outside{raw}:
      Bits.absurd({Code.decode(List.append(&2, U32, E.bytes_rep(Code.Outside{raw}), tail), Code.Start{}) == Maybe.bind(&2, String, String, Code.decode(tail, Code.Start{}), rest => Some{SCon{Chr{n}, rest}}) : Maybe<&2, String>}, Bits.false_true(packed))

# Every admitted scalar is decoded before an arbitrary suffix, even when that
# suffix itself is malformed. No codec-roundtrip assumption is required.
law utf8_char_suffix:
  for +n: U32
  for +tail: List<&2, U32>
  for valid: {E.scalar(n) == True{} : Bool}
  {Code.decode(List.append(&2, U32, E.char_bytes(n), tail), Code.Start{}) == Maybe.bind(&2, String, String, Code.decode(tail, Code.Start{}), rest => Some{SCon{Chr{n}, rest}}) : Maybe<&2, String>}

def utf8_char_suffix(n, tail, valid):
  +yes = valid
  rep_suffix(n, Code.represent(n), tail, {==}, Code.representation_value(n), yes, scalar_is_packed(n, yes))

def and_left(+a: Bool, +b: Bool, yes: {a && b == True{} : Bool}) -> {a == True{} : Bool}:
  match a:
    case True{}:
      {==}
    case False{}:
      Bits.absurd({False{} == True{} : Bool}, Bits.false_true(yes))

def and_right(+a: Bool, +b: Bool, yes: {a && b == True{} : Bool}) -> {b == True{} : Bool}:
  match a:
    case True{}:
      yes
    case False{}:
      Bits.absurd({b == True{} : Bool}, Bits.false_true(yes))

def rep_unescape_suffix(+r: Code.Representation, +tail: String,
    packed: {Code.is_packed(r) == True{} : Bool}) ->
    {E.unescape(E.encode_rep(r) ++ tail) == Maybe.bind(&2, List<&2, U32>, List<&2, U32>, E.unescape(tail), bs => Some{List.append(&2, U32, E.bytes_rep(r), bs)}) : Maybe<&2, List<&2, U32>>}:
  match r:
    case Code.Packed{+code}:
      Octet.unescape_structural_suffix(Code.octets(code), tail)
    case Code.Outside{raw}:
      Bits.absurd({E.unescape(E.encode_rep(Code.Outside{raw}) ++ tail) == Maybe.bind(&2, List<&2, U32>, List<&2, U32>, E.unescape(tail), bs => Some{List.append(&2, U32, E.bytes_rep(Code.Outside{raw}), bs)}) : Maybe<&2, List<&2, U32>>}, Bits.false_true(packed))

law unescape_char_suffix:
  for +n: U32
  for +tail: String
  for valid: {E.scalar(n) == True{} : Bool}
  {E.unescape(E.encode_char(n) ++ tail) == Maybe.bind(&2, List<&2, U32>, List<&2, U32>, E.unescape(tail), bs => Some{List.append(&2, U32, E.char_bytes(n), bs)}) : Maybe<&2, List<&2, U32>>}

def unescape_char_suffix(n, tail, valid):
  rep_unescape_suffix(Code.represent(n), tail, scalar_is_packed(n, valid))

def string_bytes(s: String) -> List<&2, U32>:
  match s:
    case SNil{}:
      Nil{}
    case SCon{Chr{n}, t}:
      List.append(&2, U32, E.char_bytes(n), string_bytes(t))

law unescape_string:
  for +s: String
  for valid: {E.scalars(s) == True{} : Bool}
  {E.unescape(E.encode(s)) == Some{string_bytes(s)} : Maybe<&2, List<&2, U32>>}

def unescape_string(s, valid):
  match s:
    case SNil{}:
      {==}
    case SCon{Chr{+n}, +t}:
      +yes = valid
      first = and_left(E.scalar(n), E.scalars(t), yes)
      rest = and_right(E.scalar(n), E.scalars(t), yes)
      %Equal.sym(Maybe<&2, List<&2, U32>>, E.unescape(E.encode_char(n) ++ E.encode(t)), Maybe.bind(&2, List<&2, U32>, List<&2, U32>, E.unescape(E.encode(t)), bs => Some{List.append(&2, U32, E.char_bytes(n), bs)}), unescape_char_suffix(n, E.encode(t), first)) : {_ == Some{string_bytes(SCon{Chr{n}, t})} : Maybe<&2, List<&2, U32>>}
      %Equal.sym(Maybe<&2, List<&2, U32>>, E.unescape(E.encode(t)), Some{string_bytes(t)}, unescape_string(t, rest)) : {Maybe.bind(&2, List<&2, U32>, List<&2, U32>, _, bs => Some{List.append(&2, U32, E.char_bytes(n), bs)}) == Some{string_bytes(SCon{Chr{n}, t})} : Maybe<&2, List<&2, U32>>}
      {==}

law utf8_string:
  for +s: String
  for valid: {E.scalars(s) == True{} : Bool}
  {Code.decode(string_bytes(s), Code.Start{}) == Some{s} : Maybe<&2, String>}

def utf8_string(s, valid):
  match s:
    case SNil{}:
      {==}
    case SCon{Chr{+n}, +t}:
      +yes = valid
      first = and_left(E.scalar(n), E.scalars(t), yes)
      rest = and_right(E.scalar(n), E.scalars(t), yes)
      %Equal.sym(Maybe<&2, String>, Code.decode(List.append(&2, U32, E.char_bytes(n), string_bytes(t)), Code.Start{}), Maybe.bind(&2, String, String, Code.decode(string_bytes(t), Code.Start{}), xs => Some{SCon{Chr{n}, xs}}), utf8_char_suffix(n, string_bytes(t), first)) : {_ == Some{SCon{Chr{n}, t}} : Maybe<&2, String>}
      %Equal.sym(Maybe<&2, String>, Code.decode(string_bytes(t), Code.Start{}), Some{t}, utf8_string(t, rest)) : {Maybe.bind(&2, String, String, _, xs => Some{SCon{Chr{n}, xs}}) == Some{SCon{Chr{n}, t}} : Maybe<&2, String>}
      {==}

# The public percent codec roundtrips every string admitted independently by
# the Unicode-scalar predicate, including empty strings and path separators.
law codec_roundtrip:
  for +s: String
  for valid: {E.scalars(s) == True{} : Bool}
  {E.decode(E.encode(s)) == Some{s} : Maybe<&2, String>}

def codec_roundtrip(s, valid):
  +yes = valid
  %Equal.sym(Maybe<&2, List<&2, U32>>, E.unescape(E.encode(s)), Some{string_bytes(s)}, unescape_string(s, yes)) : {Maybe.bind(&2, List<&2, U32>, String, _, bs => Code.decode(bs, Code.Start{})) == Some{s} : Maybe<&2, String>}
  utf8_string(s, yes)
