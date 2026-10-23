# Strict URI component encoding. No form-style '+' conversion.
import Base
import ./utf8-code.bend as Code

def choose(-A: Type, test: Bool, yes: Unit -> A, no: Unit -> A) -> A:
  match test:
    case True{}:
      yes(Unit{})
    case False{}:
      no(Unit{})

def scalar(+n: U32) -> Bool:
  Code.scalar(n)

def scalars(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{n}, t}:
      scalar(n) && scalars(t)

def hex(+c: U32) -> Maybe<&2, U32>:
  choose(Maybe<&2, U32>, (c >= 48 : U32) && (c <= 57 : U32), u => (
    Some{(c - 48 : U32)}
  ), u => (
    choose(Maybe<&2, U32>, (c >= 65 : U32) && (c <= 70 : U32), u => (
      Some{(c - 55 : U32)}
    ), u => (
      choose(Maybe<&2, U32>, (c >= 97 : U32) && (c <= 102 : U32), u => (
        Some{(c - 87 : U32)}
      ), u => (
        None{}
      ))
    ))
  ))
def digit(+n: U32) -> Char:
  choose(Char, (n < 10 : U32), u => (
    Chr{(n + 48 : U32)}
  ), u => (
    Chr{(n + 55 : U32)}
  ))
def byte(+n: U32) -> String:
  SCon{'%', SCon{digit((n / 16 : U32)), SCon{digit((n % 16 : U32)), SNil{}}}}

def encode_char_outside(+n: U32) -> String:
  choose(String, (n < 128 : U32), u => (
    byte(n)
  ), u => (
    choose(String, (n < 2048 : U32), u => (
      byte((192 + n / 64 : U32)) ++ byte((128 + n % 64 : U32))
    ), u => (
      choose(String, (n < 65536 : U32), u => (
        byte((224 + n / 4096 : U32)) ++ byte((128 + n / 64 % 64 : U32)) ++ byte((128 + n % 64 : U32))
      ), u => (
        byte((240 + n / 262144 : U32)) ++ byte((128 + n / 4096 % 64 : U32)) ++ byte((128 + n / 64 % 64 : U32)) ++ byte((128 + n % 64 : U32))
      ))
    ))
  ))
def encode_octets(xs: List<&2, Word(8n)>) -> String:
  match xs:
    case Nil{}:
      SNil{}
    case h <> t:
      byte(Code.octet(h)) ++ encode_octets(t)

def encode_rep(r: Code.Representation) -> String:
  match r:
    case Code.Packed{code}:
      encode_octets(Code.octets(code))
    case Code.Outside{raw}:
      encode_char_outside(raw)

def encode_char(n: U32) -> String:
  encode_rep(Code.represent(n))

def encode(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{n}, t}:
      encode_char(n) ++ encode(t)

# Convert raw Unicode to UTF-8 bytes as well, so mixed literal/escaped input
# obeys the same UTF-8 validity rules.
def char_bytes_outside(+n: U32) -> List<&2, U32>:
  choose(List<&2, U32>, (n < 128 : U32), u => (
    [n]
  ), u => (
    choose(List<&2, U32>, (n < 2048 : U32), u => (
      [(192 + n / 64 : U32), (128 + n % 64 : U32)]
    ), u => (
      choose(List<&2, U32>, (n < 65536 : U32), u => (
        [(224 + n / 4096 : U32), (128 + n / 64 % 64 : U32), (128 + n % 64 : U32)]
      ), u => (
        [(240 + n / 262144 : U32), (128 + n / 4096 % 64 : U32), (128 + n / 64 % 64 : U32), (128 + n % 64 : U32)]
      ))
    ))
  ))
def bytes_rep(r: Code.Representation) -> List<&2, U32>:
  match r:
    case Code.Packed{code}:
      Code.bytes(code)
    case Code.Outside{raw}:
      char_bytes_outside(raw)

def char_bytes(n: U32) -> List<&2, U32>:
  bytes_rep(Code.represent(n))

def unescape(s: String) -> Maybe<&2, List<&2, U32>>:
  match s:
    case SNil{}:
      Some{Nil{}}
    case SCon{'%', SCon{Chr{a}, SCon{Chr{b}, t}}}:
      do Maybe<&2, List<&2, U32>>:
        hi : U32 <- hex(a)
        lo : U32 <- hex(b)
        rest : List<&2, U32> <- unescape(t)
        return (hi * 16 + lo : U32) <> rest
    case SCon{'%', t}:
      None{}
    case SCon{Chr{+n}, t}:
      choose(Maybe<&2, List<&2, U32>>, scalar(n), u => (
        do Maybe<&2, List<&2, U32>>:
          rest : List<&2, U32> <- unescape(t)
          return List.append(&2, U32, char_bytes(n), rest)
      ), u => (
        None{}
      ))
def decode(s: String) -> Maybe<&2, String>:
  do Maybe<&2, String>:
    bytes : List<&2, U32> <- unescape(s)
    Code.decode(bytes, Code.Start{})
