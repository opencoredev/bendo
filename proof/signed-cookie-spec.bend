# Independent authentication relation: compare HMAC bytes structurally.
import Base
import ../src/data/utf8.bend as Utf8
import ../src/crypto/hmac.bend as Hmac

def bit_equal(a: Bool, b: Bool) -> Bool:
  match a b:
    case False{} False{}: True{}
    case True{} True{}: True{}
    case _ _: False{}

def word_equal(n: Nat, a: Word(n), b: Word(n)) -> Bool:
  match n a b:
    case 0n WNil{} WNil{}: True{}
    case 1n+p WCon{a, at} WCon{b, bt}:
      bit_equal(a, b) && word_equal(p, at, bt)

def u32_equal(a: U32, b: U32) -> Bool:
  match a b:
    case U32{aw} U32{bw}: word_equal(32n, aw, bw)

def bytes_equal(xs: List<&2, U32>, ys: List<&2, U32>) -> Bool:
  match xs ys:
    case Nil{} Nil{}: True{}
    case U32{a} <> at U32{b} <> bt:
      word_equal(32n, a, b) && bytes_equal(at, bt)
    case _ _: False{}

def authentic(keys: List<&2, String>, +value: String, +signature: List<&2, U32>) -> Bool:
  match keys:
    case Nil{}: False{}
    case key <> rest:
      bytes_equal(Hmac.sha256(Utf8.encode(key), Utf8.encode(value)), signature) || authentic(rest, value, signature)

# Membership is structural string equality expressed as propositional evidence.
def contains(+key: String, keys: List<&2, String>) -> Type:
  match keys:
    case Nil{}: Empty
    case first <> rest: {key == first : String} | contains(key, rest)

def different(keys: List<&2, String>, +value: String, +signature: List<&2, U32>) -> Type:
  match keys:
    case Nil{}: Unit
    case key <> rest:
      {Hmac.sha256(Utf8.encode(key), Utf8.encode(value)) != signature : List<&2, U32>} & different(rest, value, signature)
