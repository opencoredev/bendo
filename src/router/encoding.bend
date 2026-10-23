# Strict URI component encoding. No form-style '+' conversion.
import Base

def choose(-A: Type, test: Bool, yes: Unit -> A, no: Unit -> A) -> A:
  match test:
    case True{}:
      yes(Unit{})
    case False{}:
      no(Unit{})

def scalar(+n: U32) -> Bool:
  (n <= 1114111 : U32) && Bool.not((n >= 55296 : U32) && (n <= 57343 : U32))

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

def encode_char(+n: U32) -> String:
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
def encode(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{n}, t}:
      encode_char(n) ++ encode(t)

# UTF-8 state: continuation bytes remaining, accumulated scalar, minimum scalar.
def utf8(bs: List<&2, U32>, left: Nat, +acc: U32, +minimum: U32) -> Maybe<&2, String>:
  match bs left:
    case Nil{} 0n:
      Some{SNil{}}
    case Nil{} 1n+n:
      None{}
    case +b <> +t 0n:
      choose(Maybe<&2, String>, (b < 128 : U32), u => (
        do Maybe<&2, String>:
          rest : String <- utf8(t, 0n, 0, 0)
          return SCon{Chr{b}, rest}
      ), u => (
        choose(Maybe<&2, String>, (b >= 194 : U32) && (b <= 223 : U32), u => (
          utf8(t, 1n, (b - 192 : U32), 128)
        ), u => (
          choose(Maybe<&2, String>, (b >= 224 : U32) && (b <= 239 : U32), u => (
            utf8(t, 2n, (b - 224 : U32), 2048)
          ), u => (
            choose(Maybe<&2, String>, (b >= 240 : U32) && (b <= 244 : U32), u => (
              utf8(t, 3n, (b - 240 : U32), 65536)
            ), u => (
              None{}
            ))
          ))
        ))
      ))
    case +b <> +t 1n+0n:
      +value = (acc * 64 + b - 128 : U32)
      choose(Maybe<&2, String>, (b >= 128 : U32) && (b <= 191 : U32) && (value >= minimum : U32) && scalar(value), u => (
        do Maybe<&2, String>:
          rest : String <- utf8(t, 0n, 0, 0)
          return SCon{Chr{value}, rest}
      ), u => (None{}))
    case +b <> +t 1n+1n+k:
      choose(Maybe<&2, String>, (b >= 128 : U32) && (b <= 191 : U32), u => (
        utf8(t, 1n+k, (acc * 64 + b - 128 : U32), minimum)
      ), u => (None{}))

# Convert raw Unicode to UTF-8 bytes as well, so mixed literal/escaped input
# obeys the same UTF-8 validity rules.
def char_bytes(+n: U32) -> List<&2, U32>:
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
    utf8(bytes, 0n, 0, 0)
