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

# Request-path strings can be long, so every loop over one is a tail call
# (BND-84). Each keeps its recursive original as `_spec`;
# encoding-proofs.bend proves the two equal.
def scalars_spec(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{n}, t}:
      scalar(n) && scalars_spec(t)

def scalars_go(s: String, ok: Bool) -> Bool:
  match s:
    case SNil{}:
      ok
    case SCon{Chr{+n}, t}:
      scalars_go(t, ok && scalar(n))

def scalars(s: String) -> Bool:
  scalars_go(s, True{})

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

def encode_spec(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{n}, t}:
      encode_char(n) ++ encode_spec(t)

# `out` holds the encoded prefix reversed. Appending to it instead would cost
# quadratic time in native builds, where `++` walks its left side.
def encode_go(s: String, out: String) -> String:
  match s:
    case SNil{}:
      String.reverse(out)
    case SCon{Chr{n}, t}:
      encode_go(t, String.reverse.go(encode_char(n), out))

def encode(s: String) -> String:
  encode_go(s, "")

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

def unescape_spec(s: String) -> Maybe<&2, List<&2, U32>>:
  match s:
    case SNil{}:
      Some{Nil{}}
    case SCon{'%', SCon{Chr{a}, SCon{Chr{b}, t}}}:
      do Maybe<&2, List<&2, U32>>:
        hi : U32 <- hex(a)
        lo : U32 <- hex(b)
        rest : List<&2, U32> <- unescape_spec(t)
        return (hi * 16 + lo : U32) <> rest
    case SCon{'%', t}:
      None{}
    case SCon{Chr{+n}, t}:
      choose(Maybe<&2, List<&2, U32>>, scalar(n), u => (
        do Maybe<&2, List<&2, U32>>:
          rest : List<&2, U32> <- unescape_spec(t)
          return List.append(&2, U32, char_bytes(n), rest)
      ), u => (
        None{}
      ))

# The loop's accumulator holds the bytes read so far, most recent first, or
# None once a character fails. Its patterns repeat unescape_spec's, so the
# equivalence proof splits each character exactly as the spec does.
def push_escape(acc: Maybe<&2, List<&2, U32>>, hi: Maybe<&2, U32>, lo: Maybe<&2, U32>) -> Maybe<&2, List<&2, U32>>:
  match acc hi lo:
    case Some{bs} Some{+h} Some{+l}:
      Some{(h * 16 + l : U32) <> bs}
    case _ _ _:
      None{}

def push_char(acc: Maybe<&2, List<&2, U32>>, +n: U32, ok: Bool) -> Maybe<&2, List<&2, U32>>:
  match acc ok:
    case Some{bs} True{}:
      Some{List.reverse.go(&2, U32, char_bytes(n), bs)}
    case _ _:
      None{}

def unescaped(acc: Maybe<&2, List<&2, U32>>) -> Maybe<&2, List<&2, U32>>:
  match acc:
    case None{}:
      None{}
    case Some{bs}:
      Some{List.reverse(&2, U32, bs)}

def unescape_go(s: String, acc: Maybe<&2, List<&2, U32>>) -> Maybe<&2, List<&2, U32>>:
  match s:
    case SNil{}:
      unescaped(acc)
    case SCon{'%', SCon{Chr{a}, SCon{Chr{b}, t}}}:
      unescape_go(t, push_escape(acc, hex(a), hex(b)))
    case SCon{'%', t}:
      None{}
    case SCon{Chr{+n}, t}:
      unescape_go(t, push_char(acc, n, scalar(n)))

def unescape(s: String) -> Maybe<&2, List<&2, U32>>:
  unescape_go(s, Some{Nil{}})

def decode(s: String) -> Maybe<&2, String>:
  do Maybe<&2, String>:
    bytes : List<&2, U32> <- unescape(s)
    Code.decode(bytes, Code.Start{})

def decode_spec(s: String) -> Maybe<&2, String>:
  do Maybe<&2, String>:
    bytes : List<&2, U32> <- unescape_spec(s)
    Code.decode_spec(bytes, Code.Start{})
