import Base
import ./utf8.bend as U

def symbol(w: Word(6n), url: Bool) -> Char:
  match w:
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      'A'
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      'B'
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      'C'
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      'D'
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      'E'
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      'F'
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      'G'
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      'H'
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      'I'
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      'J'
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      'K'
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      'L'
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      'M'
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      'N'
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      'O'
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}:
      'P'
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      'Q'
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      'R'
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      'S'
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      'T'
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      'U'
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      'V'
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      'W'
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      'X'
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      'Y'
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      'Z'
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      'a'
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      'b'
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      'c'
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      'd'
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      'e'
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}:
      'f'
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      'g'
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      'h'
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      'i'
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      'j'
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      'k'
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      'l'
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      'm'
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      'n'
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      'o'
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      'p'
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      'q'
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      'r'
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      's'
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      't'
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      'u'
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}:
      'v'
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      'w'
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      'x'
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      'y'
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      'z'
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      '0'
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      '1'
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      '2'
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      '3'
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      '4'
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      '5'
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      '6'
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      '7'
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      '8'
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      '9'
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      match url:
        case False{}:
          '+'
        case True{}:
          '-'
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}:
      match url:
        case False{}:
          '/'
        case True{}:
          '_'

def value(c: Char, url: Bool) -> Maybe<&2, Word(6n)>:
  match c:
    case 'A':
      Some{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}
    case 'B':
      Some{WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}
    case 'C':
      Some{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}
    case 'D':
      Some{WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}
    case 'E':
      Some{WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}
    case 'F':
      Some{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}
    case 'G':
      Some{WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}
    case 'H':
      Some{WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}
    case 'I':
      Some{WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}
    case 'J':
      Some{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}
    case 'K':
      Some{WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}
    case 'L':
      Some{WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}
    case 'M':
      Some{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}
    case 'N':
      Some{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}
    case 'O':
      Some{WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}
    case 'P':
      Some{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}}}}
    case 'Q':
      Some{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}
    case 'R':
      Some{WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}
    case 'S':
      Some{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}
    case 'T':
      Some{WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}
    case 'U':
      Some{WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}
    case 'V':
      Some{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}
    case 'W':
      Some{WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}
    case 'X':
      Some{WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}
    case 'Y':
      Some{WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}
    case 'Z':
      Some{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}
    case 'a':
      Some{WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}
    case 'b':
      Some{WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}
    case 'c':
      Some{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}
    case 'd':
      Some{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}
    case 'e':
      Some{WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}
    case 'f':
      Some{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}}}}
    case 'g':
      Some{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}
    case 'h':
      Some{WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}
    case 'i':
      Some{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}
    case 'j':
      Some{WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}
    case 'k':
      Some{WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}
    case 'l':
      Some{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}
    case 'm':
      Some{WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}
    case 'n':
      Some{WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}
    case 'o':
      Some{WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}
    case 'p':
      Some{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}
    case 'q':
      Some{WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}
    case 'r':
      Some{WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}
    case 's':
      Some{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}
    case 't':
      Some{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}
    case 'u':
      Some{WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}
    case 'v':
      Some{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}}}}
    case 'w':
      Some{WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}
    case 'x':
      Some{WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}
    case 'y':
      Some{WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}
    case 'z':
      Some{WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}
    case '0':
      Some{WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}
    case '1':
      Some{WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}
    case '2':
      Some{WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}
    case '3':
      Some{WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}
    case '4':
      Some{WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}
    case '5':
      Some{WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}
    case '6':
      Some{WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}
    case '7':
      Some{WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}
    case '8':
      Some{WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}
    case '9':
      Some{WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}
    case '+':
      match url:
        case False{}:
          Some{WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}
        case True{}:
          None{}
    case '/':
      match url:
        case False{}:
          Some{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}
        case True{}:
          None{}
    case '-':
      match url:
        case True{}:
          Some{WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}
        case False{}:
          None{}
    case '_':
      match url:
        case True{}:
          Some{WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}}}}
        case False{}:
          None{}
    case _:
      None{}

def octet(w: Word(8n)) -> U32:
  U32{U.join(8n, 24n, w, Word.zero(24n))}

def one(+a: Word(8n), +url: Bool, padded: Bool) -> String:
  match padded:
    case True{}:
      SCon{symbol(U.high(2n, 6n, a), url), SCon{symbol(U.join(4n, 2n, Word.zero(4n), U.low(2n, 6n, a)), url), "=="}}
    case False{}:
      SCon{symbol(U.high(2n, 6n, a), url), SCon{symbol(U.join(4n, 2n, Word.zero(4n), U.low(2n, 6n, a)), url), ""}}

def two(+a: Word(8n), +b: Word(8n), +url: Bool, padded: Bool) -> String:
  tail = Bool.pick(String, padded, "=", "")
  SCon{symbol(U.high(2n, 6n, a), url), SCon{symbol(U.join(4n, 2n, U.high(4n, 4n, b), U.low(2n, 6n, a)), url), SCon{symbol(U.join(2n, 4n, Word.zero(2n), U.low(4n, 4n, b)), url), tail}}}

def three(+a: Word(8n), +b: Word(8n), +c: Word(8n), +url: Bool) -> String:
  SCon{symbol(U.high(2n, 6n, a), url), SCon{symbol(U.join(4n, 2n, U.high(4n, 4n, b), U.low(2n, 6n, a)), url), SCon{symbol(U.join(2n, 4n, U.high(6n, 2n, c), U.low(4n, 4n, b)), url), SCon{symbol(U.low(6n, 2n, c), url), ""}}}}

# Recursive equation retained for the roundtrip proof; public encoding below
# uses a tail-recursive accumulator for the JavaScript target.
def encode_spec(xs: List<&2, U32>, +url: Bool, +padded: Bool) -> String:
  match xs:
    case Nil{}:
      ""
    case U32{a} <> Nil{}:
      one(U.low(8n, 24n, a), url, padded)
    case U32{a} <> U32{b} <> Nil{}:
      two(U.low(8n, 24n, a), U.low(8n, 24n, b), url, padded)
    case U32{a} <> U32{b} <> U32{c} <> t:
      three(U.low(8n, 24n, a), U.low(8n, 24n, b), U.low(8n, 24n, c), url) ++ encode_spec(t, url, padded)

def encode_go(xs: List<&2, U32>, +url: Bool, +padded: Bool, rev: String) -> String:
  match xs:
    case Nil{}:
      String.reverse(rev)
    case U32{a} <> Nil{}:
      String.reverse(String.reverse(one(U.low(8n, 24n, a), url, padded)) ++ rev)
    case U32{a} <> U32{b} <> Nil{}:
      String.reverse(String.reverse(two(U.low(8n, 24n, a), U.low(8n, 24n, b), url, padded)) ++ rev)
    case U32{a} <> U32{b} <> U32{c} <> t:
      encode_go(t, url, padded, String.reverse(three(U.low(8n, 24n, a), U.low(8n, 24n, b), U.low(8n, 24n, c), url)) ++ rev)

# RFC 4648; url chooses the URL alphabet, padded chooses required padding.
# Precondition: every input element <= 255.
def encode(xs: List<&2, U32>, url: Bool, padded: Bool) -> String:
  encode_go(xs, url, padded, "")

def restore1(+a: Word(6n), +b: Word(6n)) -> U32:
  octet(U.join(2n, 6n, U.high(4n, 2n, b), a))

def restore2(+b: Word(6n), +c: Word(6n)) -> U32:
  octet(U.join(4n, 4n, U.high(2n, 4n, c), U.low(4n, 2n, b)))

def restore3(+c: Word(6n), d: Word(6n)) -> U32:
  octet(U.join(6n, 2n, d, U.low(2n, 4n, c)))

def accept(rev: List<&2, U32>, ok: Bool) -> Maybe<&2, List<&2, U32>>:
  match ok:
    case True{}:
      Some{rev}
    case False{}:
      None{}

def decode1(a: Maybe<&2, Word(6n)>, b: Maybe<&2, Word(6n)>, acc: Maybe<&2, List<&2, U32>>, ok: Bool) -> Maybe<&2, List<&2, U32>>:
  match a b acc:
    case Some{a} Some{+b} Some{rev}:
      accept(restore1(a, b) <> rev, ok && U.zero(4n, U.low(4n, 2n, b)))
    case _ _ _:
      None{}

def decode2(a: Maybe<&2, Word(6n)>, b: Maybe<&2, Word(6n)>, c: Maybe<&2, Word(6n)>, acc: Maybe<&2, List<&2, U32>>, ok: Bool) -> Maybe<&2, List<&2, U32>>:
  match a b c acc:
    case Some{a} Some{+b} Some{+c} Some{rev}:
      accept(restore2(b, c) <> restore1(a, b) <> rev, ok && U.zero(2n, U.low(2n, 4n, c)))
    case _ _ _ _:
      None{}

def decode3(a: Maybe<&2, Word(6n)>, b: Maybe<&2, Word(6n)>, c: Maybe<&2, Word(6n)>, d: Maybe<&2, Word(6n)>, acc: Maybe<&2, List<&2, U32>>) -> Maybe<&2, List<&2, U32>>:
  match a b c d acc:
    case Some{a} Some{+b} Some{+c} Some{d} Some{rev}:
      Some{restore3(c, d) <> restore2(b, c) <> restore1(a, b) <> rev}
    case _ _ _ _ _:
      None{}

def empty(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case _:
      False{}

def quartet_values(c: Maybe<&2, Word(6n)>, d: Maybe<&2, Word(6n)>, a: Maybe<&2, Word(6n)>, b: Maybe<&2, Word(6n)>, pad_c: Bool, pad_d: Bool, acc: Maybe<&2, List<&2, U32>>) -> Maybe<&2, List<&2, U32>>:
  match c d:
    case Some{c} Some{d}:
      decode3(a, b, Some{c}, Some{d}, acc)
    case Some{c} None{}:
      decode2(a, b, Some{c}, acc, pad_d)
    case None{} None{}:
      decode1(a, b, acc, pad_c && pad_d)
    case None{} Some{d}:
      None{}

def quartet(a: Char, b: Char, +c: Char, +d: Char, +url: Bool, +padded: Bool, +terminal: Bool, acc: Maybe<&2, List<&2, U32>>) -> Maybe<&2, List<&2, U32>>:
  quartet_values(value(c, url), value(d, url), value(a, url), value(b, url), padded && terminal && Char.is_eq(c, '='), padded && terminal && Char.is_eq(d, '='), acc)

def finish(acc: Maybe<&2, List<&2, U32>>) -> Maybe<&2, List<&2, U32>>:
  Maybe.map(&2, List<&2, U32>, List<&2, U32>, xs => List.reverse(&2, U32, xs), acc)

def decode_go(s: String, +url: Bool, +padded: Bool, acc: Maybe<&2, List<&2, U32>>) -> Maybe<&2, List<&2, U32>>:
  match s:
    case SNil{}:
      finish(acc)
    case SCon{a, SCon{b, SNil{}}}:
      finish(decode1(value(a, url), value(b, url), acc, Bool.not(padded)))
    case SCon{a, SCon{b, SCon{c, SNil{}}}}:
      finish(decode2(value(a, url), value(b, url), value(c, url), acc, Bool.not(padded)))
    case SCon{a, SCon{b, SCon{c, SCon{d, +t}}}}:
      decode_go(t, url, padded, quartet(a, b, c, d, url, padded, empty(t), acc))
    case _:
      None{}

# Strict policy: reject wrong alphabet, whitespace, nonzero unused bits,
# misplaced/excess padding, and padding contrary to the selected mode.
def decode(s: String, url: Bool, padded: Bool) -> Maybe<&2, List<&2, U32>>:
  decode_go(s, url, padded, Some{[]})
