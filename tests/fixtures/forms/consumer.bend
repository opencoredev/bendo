import Base
import ../../../src/data/urlencoded.bend as F
import ../../../src/data/utf8.bend as U

def encode(s: String) -> String:
  F.encode(s)

def encode_form(s: String) -> String:
  F.encode_form(s)

def decode(s: String) -> Result<&2, &2, F.Error, String>:
  F.decode(s)

def decode_form(s: String) -> Result<&2, &2, F.Error, String>:
  F.decode_form(s)

def parse_pairs(s: String) -> Result<&2, &2, F.Error, List<&2, F.Entry>>:
  F.parse_pairs(s)

def parse_body(ct: String, body: List<&2, U32>) -> Result<&2, &2, F.Error, List<&2, F.Entry>>:
  F.parse_body(ct, body)

def queries(pairs: List<&2, F.Entry>, key: String) -> List<&2, String>:
  F.queries(pairs, key)

def query(pairs: List<&2, F.Entry>, key: String) -> Maybe<&2, String>:
  F.query(pairs, key)

def serialize(pairs: List<&2, F.Entry>) -> String:
  F.serialize(pairs)

def utf8_encode(s: String) -> List<&2, U32>:
  U.encode(s)

def utf8_decode(xs: List<&2, U32>) -> Maybe<&2, String>:
  U.decode(xs)

# BND-100: JavaScript strings reach Bend with lone surrogates already
# replaced, so build strings holding a non-scalar Char inside Bend.
def nonscalar_text(k: U32) -> String:
  {SCon{'a', SCon{Chr{k}, "b"}} : String}

def nonscalar_decode(k: U32) -> Result<&2, &2, F.Error, String>:
  F.decode(nonscalar_text(k))

def nonscalar_decode_form(k: U32) -> Result<&2, &2, F.Error, String>:
  F.decode_form(nonscalar_text(k))

def nonscalar_parse_pairs(k: U32) -> Result<&2, &2, F.Error, List<&2, F.Entry>>:
  F.parse_pairs(nonscalar_text(k))

def nonscalar_encode(k: U32) -> String:
  F.encode(nonscalar_text(k))

def nonscalar_utf8(k: U32) -> List<&2, U32>:
  U.encode(nonscalar_text(k))
