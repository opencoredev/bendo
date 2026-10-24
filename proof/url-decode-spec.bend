# BND-87: an independent percent decoder for the signed-cookie wire.
# Nothing here calls urlencoded.bend's decoder; the import is for its
# error type only.
import Base
import ../src/data/urlencoded.bend as Url

def hexdig_of(+c: U32, digit: Bool, upper: Bool, lower: Bool) -> Maybe<&2, U32>:
  match digit upper lower:
    case True{} _ _: Some{(c - 48 : U32)}
    case False{} True{} _: Some{(c - 65 + 10 : U32)}
    case False{} False{} True{}: Some{(c - 97 + 10 : U32)}
    case False{} False{} False{}: None{}

# RFC 3986 section 2.1: HEXDIG is a digit or a letter A-F in either case.
# Its value as a number from 0 to 15, or None for any other octet.
def hexdig(+c: U32) -> Maybe<&2, U32>:
  hexdig_of(c, (c >= 48 : U32) && (c <= 57 : U32), (c >= 65 : U32) && (c <= 70 : U32), (c >= 97 : U32) && (c <= 102 : U32))

def literal(+b: U32, rest: Result<&2, &2, Url.Error, List<&2, U32>>) -> Result<&2, &2, Url.Error, List<&2, U32>>:
  match rest:
    case Fail{e}: Fail{e}
    case Done{xs}: Done{b <> xs}

# "%" followed by two hex digits is the octet 16 * high + low.
def escaped(hi: Maybe<&2, U32>, lo: Maybe<&2, U32>, rest: Result<&2, &2, Url.Error, List<&2, U32>>) -> Result<&2, &2, Url.Error, List<&2, U32>>:
  match hi lo:
    case Some{h} Some{l}: literal((h * 16 + l : U32), rest)
    case Some{h} None{}: Fail{Url.InvalidPercent{}}
    case None{} lo: Fail{Url.InvalidPercent{}}

# RFC 3986 percent decoding over octets: "%HH" with either hex case becomes
# one octet, a "%" without two hex digits fails, and every other octet,
# including "+", stays literal.
def unpercent(xs: List<&2, U32>) -> Result<&2, &2, Url.Error, List<&2, U32>>:
  match xs:
    case Nil{}: Done{[]}
    case 37 <> +a <> +b <> t: escaped(hexdig(a), hexdig(b), unpercent(t))
    case 37 <> t: Fail{Url.InvalidPercent{}}
    case +b <> t: literal(b, unpercent(t))
