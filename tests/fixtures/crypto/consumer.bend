import Base
import ../../../src/crypto/sha1.bend as S1
import ../../../src/crypto/sha256.bend as S256
import ../../../src/crypto/hmac.bend as H
import ../../../src/crypto/compare.bend as C
import ../../../src/data/hex.bend as Hex
import ../../../src/data/base64.bend as B64
import ../../../src/data/utf8.bend as Utf8

def sha1(xs: List<&2, U32>) -> String:
  Hex.encode(S1.hash(xs))

def sha256(xs: List<&2, U32>) -> String:
  Hex.encode(S256.hash(xs))

def hmac(key: List<&2, U32>, message: List<&2, U32>) -> String:
  Hex.encode(H.sha256(key, message))

def hex(xs: List<&2, U32>) -> String:
  Hex.encode(xs)

def unhex(s: String) -> Maybe<&2, List<&2, U32>>:
  Hex.decode(s)

def base64(xs: List<&2, U32>, url: Bool, padded: Bool) -> String:
  B64.encode(xs, url, padded)

def unbase64(s: String, url: Bool, padded: Bool) -> Maybe<&2, List<&2, U32>>:
  B64.decode(s, url, padded)

def ct_equal(a: List<&2, U32>, b: List<&2, U32>) -> Bool:
  C.ct_equal(a, b)

def utf8(s: String) -> List<&2, U32>:
  Utf8.encode(s)
