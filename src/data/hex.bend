import Base
import ./utf8.bend as U

def symbol(w: Word(4n)) -> Char:
  match w:
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}:
      '0'
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}:
      '1'
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}:
      '2'
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}:
      '3'
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}:
      '4'
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}:
      '5'
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}:
      '6'
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}:
      '7'
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}:
      '8'
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}:
      '9'
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}:
      'a'
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}:
      'b'
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}:
      'c'
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}:
      'd'
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}:
      'e'
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}:
      'f'

def value(c: Char) -> Maybe<&2, Word(4n)>:
  match c:
    case '0':
      Some{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}
    case '1':
      Some{WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}
    case '2':
      Some{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}
    case '3':
      Some{WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}
    case '4':
      Some{WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}
    case '5':
      Some{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}
    case '6':
      Some{WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}
    case '7':
      Some{WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}
    case '8':
      Some{WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}
    case '9':
      Some{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}
    case 'a':
      Some{WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}
    case 'b':
      Some{WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}
    case 'c':
      Some{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}
    case 'd':
      Some{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}
    case 'e':
      Some{WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}
    case 'f':
      Some{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}
    case 'A':
      Some{WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}
    case 'B':
      Some{WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}
    case 'C':
      Some{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}
    case 'D':
      Some{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}
    case 'E':
      Some{WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}
    case 'F':
      Some{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}
    case _:
      None{}

def byte(+w: Word(8n)) -> String:
  SCon{symbol(U.high(4n, 4n, w)), SCon{symbol(U.low(4n, 4n, w)), ""}}

# Recursive equation retained for the roundtrip proof; public encoding below
# uses a tail-recursive accumulator for the JavaScript target.
def encode_spec(xs: List<&2, U32>) -> String:
  match xs:
    case Nil{}:
      ""
    case U32{w} <> t:
      byte(U.low(8n, 24n, w)) ++ encode_spec(t)

def encode_go(xs: List<&2, U32>, rev: String) -> String:
  match xs:
    case Nil{}:
      String.reverse(rev)
    case U32{w} <> t:
      encode_go(t, String.reverse(byte(U.low(8n, 24n, w))) ++ rev)

# Precondition: every input element <= 255. Emits lowercase hexadecimal.
def encode(xs: List<&2, U32>) -> String:
  encode_go(xs, "")

def pair(a: Maybe<&2, Word(4n)>, b: Maybe<&2, Word(4n)>, acc: Maybe<&2, List<&2, U32>>) -> Maybe<&2, List<&2, U32>>:
  match a b acc:
    case Some{hi} Some{lo} Some{rev}:
      Some{U32{U.join(8n, 24n, U.join(4n, 4n, lo, hi), Word.zero(24n))} <> rev}
    case _ _ _:
      None{}

def decode_go(s: String, acc: Maybe<&2, List<&2, U32>>) -> Maybe<&2, List<&2, U32>>:
  match s:
    case SNil{}:
      Maybe.map(&2, List<&2, U32>, List<&2, U32>, xs => List.reverse(&2, U32, xs), acc)
    case SCon{a, SCon{b, t}}:
      decode_go(t, pair(value(a), value(b), acc))
    case _:
      None{}

# Accept upper/lowercase digits; reject odd lengths and all other input.
def decode(s: String) -> Maybe<&2, List<&2, U32>>:
  decode_go(s, Some{[]})
