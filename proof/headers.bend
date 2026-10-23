# Header field and whitespace reconstruction lemmas.
import Base
import ./equality.bend as E
import ../src/http/bytes.bend as B
import ../src/http/request.bend as R
import ../src/http/parse.bend as P

# The complement patterns exhaust all 32-bit octets, not just ASCII.
law field_token_char:
  for +c: U32
  for +rest: List<&2, U32>
  for ok: {B.tchar(c) == True{} : Bool}
  {P.field(c <> rest) == P.field_push(c, P.field(rest)) : P.Field}
def field_token_char(c, rest, ok):
  match c:
    case 58:
      E.absurd({P.field(58 <> rest) == P.field_push(58, P.field(rest)) : P.Field}, E.false_true(ok))
    case U32{WCon{False{}, WCon{False{}, rest_bits}}}:
      {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, rest_bits}}}}}:
      {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, rest_bits}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, rest_bits}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, rest_bits}}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{True{}, WCon{True{}, rest_bits}}}}:
      {==}
    case U32{WCon{True{}, rest_bits}}:
      {==}

law header_token_char:
  for +r: R.Req
  for +c: U32
  for +rest: List<&2, U32>
  for ok: {B.tchar(c) == True{} : Bool}
  {P.header_line(r, c <> rest) == P.header_field(r, P.field(c <> rest)) : P.State}
def header_token_char(r, c, rest, ok):
  match c:
    case 9:
      E.absurd({P.header_line(r, 9 <> rest) == P.header_field(r, P.field(9 <> rest)) : P.State}, E.false_true(ok))
    case 32:
      E.absurd({P.header_line(r, 32 <> rest) == P.header_field(r, P.field(32 <> rest)) : P.State}, E.false_true(ok))
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, rest_bits}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, rest_bits}}}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}:
      {==}
    case U32{WCon{False{}, WCon{True{}, rest_bits}}}:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, rest_bits}}}}}:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, rest_bits}}}}}}:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{True{}, rest_bits}}}}:
      {==}
    case U32{WCon{True{}, WCon{True{}, rest_bits}}}:
      {==}

law field_token_tail:
  for +name: String
  for +value: List<&2, U32>
  for +ok: {B.token_tail(name) == True{} : Bool}
  {P.field(B.append(B.encode(name), 58 <> value)) == P.Field{name, value} : P.Field}
def field_token_tail(name, value, ok):
  match name:
    case SNil{}:
      {==}
    case SCon{Chr{c}, t}:
      e1 = field_token_char(c, B.append(B.encode(t), 58 <> value), E.and_left(B.tchar(c), B.token_tail(t), ok))
      e2 = field_token_tail(t, value, E.and_right(B.tchar(c), B.token_tail(t), ok))
      Equal.trans(P.Field, P.field(c <> B.append(B.encode(t), 58 <> value)), P.field_push(c, P.field(B.append(B.encode(t), 58 <> value))), P.Field{SCon{Chr{c}, t}, value}, e1, Equal.cong(P.Field, P.Field, f => P.field_push(c, f), P.field(B.append(B.encode(t), 58 <> value)), P.Field{t, value}, e2))

law trim_start_identity:
  for +xs: List<&2, U32>
  for ok: {R.value_start(xs) == True{} : Bool}
  {B.trim_start(xs) == xs : List<&2, U32>}
def trim_start_identity(xs, ok):
  match xs:
    case Nil{}:
      {==}
    case 9 <> t:
      E.absurd({B.trim_start(9 <> t) == 9 <> t : List<&2, U32>}, E.false_true(ok))
    case 32 <> t:
      E.absurd({B.trim_start(32 <> t) == 32 <> t : List<&2, U32>}, E.false_true(ok))
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, rest_bits}}}}}}} <> t:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}} <> t:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}} <> t:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}} <> t:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}}}}}}}}} <> t:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}}}}}}}} <> t:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}}}}}}} <> t:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}}}}}} <> t:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}}}}} <> t:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}}}} <> t:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}}} <> t:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}} <> t:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}} <> t:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}} <> t:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}} <> t:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}} <> t:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}} <> t:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}} <> t:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}} <> t:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}} <> t:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}} <> t:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}} <> t:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}} <> t:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}} <> t:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}} <> t:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}} <> t:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, rest_bits}}}}}}}} <> t:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}} <> t:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}} <> t:
      {==}
    case U32{WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}} <> t:
      {==}
    case U32{WCon{False{}, WCon{True{}, rest_bits}}} <> t:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, rest_bits}}}}} <> t:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}} <> t:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}} <> t:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}} <> t:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}}}}}}}}} <> t:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}}}}}}}} <> t:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}}}}}}} <> t:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}}}}}} <> t:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}}}}} <> t:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}}}} <> t:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}}} <> t:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}}} <> t:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}}} <> t:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}}} <> t:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}}} <> t:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}}} <> t:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}}} <> t:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}}} <> t:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}}} <> t:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}}} <> t:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}}} <> t:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}}} <> t:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}}} <> t:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}}} <> t:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}}} <> t:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}}} <> t:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}}} <> t:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, rest_bits}}}}}}} <> t:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, rest_bits}}}}}} <> t:
      {==}
    case U32{WCon{True{}, WCon{False{}, WCon{True{}, rest_bits}}}} <> t:
      {==}
    case U32{WCon{True{}, WCon{True{}, rest_bits}}} <> t:
      {==}

law reverse_go_twice:
  for -A: Data
  for xs: List<&2, A>
  for ys: List<&2, A>
  for zs: List<&2, A>
  {List.reverse.go(&2, A, List.reverse.go(&2, A, xs, ys), zs) == List.reverse.go(&2, A, ys, List.append(&2, A, xs, zs)) : List<&2, A>}
def reverse_go_twice(A, xs, ys, zs):
  match xs:
    case Nil{}:
      {==}
    case h <> t:
      reverse_go_twice(A, t, h <> ys, zs)

law append_nil:
  for -A: Data
  for xs: List<&2, A>
  {List.append(&2, A, xs, []) == xs : List<&2, A>}
def append_nil(A, xs):
  match xs:
    case Nil{}:
      {==}
    case h <> t:
      %append_nil(A, t) : {h <> List.append(&2, A, t, []) == h <> _ : List<&2, A>}
      {==}

law reverse_twice:
  for -A: Data
  for +xs: List<&2, A>
  {List.reverse(&2, A, List.reverse(&2, A, xs)) == xs : List<&2, A>}
def reverse_twice(A, xs):
  %append_nil(A, xs) : {List.reverse(&2, A, List.reverse(&2, A, xs)) == _ : List<&2, A>}
  reverse_go_twice(A, xs, [], [])

law trim_identity:
  for +xs: List<&2, U32>
  for start: {R.value_start(xs) == True{} : Bool}
  for end: {R.value_start(List.reverse(&2, U32, xs)) == True{} : Bool}
  {B.trim(xs) == xs : List<&2, U32>}
def trim_identity(xs, start, end):
  e1 = trim_start_identity(xs, start)
  e2 = trim_start_identity(List.reverse(&2, U32, xs), end)
  Equal.trans(List<&2, U32>, B.trim(xs), List.reverse(&2, U32, B.trim_start(List.reverse(&2, U32, xs))), xs,
    Equal.cong(List<&2, U32>, List<&2, U32>, ys => List.reverse(&2, U32, B.trim_start(List.reverse(&2, U32, ys))), B.trim_start(xs), xs, e1),
    Equal.trans(List<&2, U32>, List.reverse(&2, U32, B.trim_start(List.reverse(&2, U32, xs))), List.reverse(&2, U32, List.reverse(&2, U32, xs)), xs,
      Equal.cong(List<&2, U32>, List<&2, U32>, ys => List.reverse(&2, U32, ys), B.trim_start(List.reverse(&2, U32, xs)), List.reverse(&2, U32, xs), e2), reverse_twice(U32, xs)))

law header_field_valid:
  for +r: R.Req
  for +name: String
  for +raw: List<&2, U32>
  for token: {B.token(name) == True{} : Bool}
  for value: {B.value(raw) == True{} : Bool}
  {P.header_field(r, P.Field{name, raw}) == P.push_header(r, R.Header{B.fold(name), B.trim(raw)}) : P.State}
def header_field_valid(r, name, raw, token, value):
  %Equal.sym(Bool, B.token(name), True{}, token) : {P.header_name(r, name, raw, _) == P.push_header(r, R.Header{B.fold(name), B.trim(raw)}) : P.State}
  %Equal.sym(Bool, B.value(raw), True{}, value) : {P.header_value(r, name, raw, _) == P.push_header(r, R.Header{B.fold(name), B.trim(raw)}) : P.State}
  {==}

law header_name_split:
  for +r: R.Req
  for +name: String
  for +raw: List<&2, U32>
  for +token: {B.token(name) == True{} : Bool}
  {P.header_line(r, B.append(B.encode(name), 58 <> raw)) == P.header_field(r, P.Field{name, raw}) : P.State}
def header_name_split(r, name, raw, token):
  match name:
    case SNil{}:
      E.absurd({P.header_line(r, 58 <> raw) == P.header_field(r, P.Field{SNil{}, raw}) : P.State}, E.false_true(token))
    case SCon{Chr{c}, t}:
      e1 = header_token_char(r, c, B.append(B.encode(t), 58 <> raw), E.and_left(B.tchar(c), B.token_tail(t), token))
      e2 = field_token_tail(SCon{Chr{c}, t}, raw, token)
      Equal.trans(P.State, P.header_line(r, c <> B.append(B.encode(t), 58 <> raw)), P.header_field(r, P.field(c <> B.append(B.encode(t), 58 <> raw))), P.header_field(r, P.Field{SCon{Chr{c}, t}, raw}), e1, Equal.cong(P.Field, P.State, f => P.header_field(r, f), P.field(c <> B.append(B.encode(t), 58 <> raw)), P.Field{SCon{Chr{c}, t}, raw}, e2))

law header_fields:
  for +r: R.Req
  for +name: String
  for +value: List<&2, U32>
  for +ok: {R.header_valid(R.Header{name, value}) == True{} : Bool}
  {P.header_line(r, B.append(B.encode(name), 58 <> 32 <> value)) == P.push_header(r, R.Header{name, value}) : P.State}
def header_fields(r, name, value, ok):
  +e4 = E.and_left(B.token(name) && String.eq(name, B.fold(name)) && B.value(value) && R.value_start(value), R.value_start(List.reverse(&2, U32, value)), ok)
  end = E.and_right(B.token(name) && String.eq(name, B.fold(name)) && B.value(value) && R.value_start(value), R.value_start(List.reverse(&2, U32, value)), ok)
  +e3 = E.and_left(B.token(name) && String.eq(name, B.fold(name)) && B.value(value), R.value_start(value), e4)
  start = E.and_right(B.token(name) && String.eq(name, B.fold(name)) && B.value(value), R.value_start(value), e4)
  +e2 = E.and_left(B.token(name) && String.eq(name, B.fold(name)), B.value(value), e3)
  value_ok = E.and_right(B.token(name) && String.eq(name, B.fold(name)), B.value(value), e3)
  +token = E.and_left(B.token(name), String.eq(name, B.fold(name)), e2)
  folded = E.string_eq_sound(name, B.fold(name), E.and_right(B.token(name), String.eq(name, B.fold(name)), e2))
  trimmed = trim_identity(value, start, end)
  +raw = {32 <> value : List<&2, U32>}
  +normalized = {R.Header{B.fold(name), B.trim(raw)} : R.Header}
  +expected = {R.Header{name, value} : R.Header}
  fields = Equal.trans(P.State, P.header_line(r, B.append(B.encode(name), 58 <> raw)), P.header_field(r, P.Field{name, raw}), P.push_header(r, normalized), header_name_split(r, name, raw, token), header_field_valid(r, name, raw, token, value_ok))
  header = Equal.trans(R.Header, normalized, R.Header{name, B.trim(raw)}, expected, Equal.cong(String, R.Header, n => R.Header{n, B.trim(raw)}, B.fold(name), name, Equal.sym(String, name, B.fold(name), folded)), Equal.cong(List<&2, U32>, R.Header, xs => R.Header{name, xs}, B.trim(raw), value, trimmed))
  Equal.trans(P.State, P.header_line(r, B.append(B.encode(name), 58 <> raw)), P.push_header(r, normalized), P.push_header(r, expected), fields, Equal.cong(R.Header, P.State, h => P.push_header(r, h), normalized, expected, header))
