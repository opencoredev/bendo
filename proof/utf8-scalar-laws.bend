# BND-100: Utf8.encode is total. A Char that is not a Unicode scalar value
# (a surrogate, or a value above U+10FFFF) encodes as U+FFFD, as WHATWG
# TextEncoder does, so no Char is dropped and the output is always valid
# UTF-8. Decoders that read a String as its UTF-8 octets refuse such a
# String instead of decoding the replacement character.
import Base
import ../src/data/utf8.bend as Utf8
import ../src/data/urlencoded.bend as Url
import ../src/http/response.bend as Response
import ./utf8-scalar-spec.bend as Spec

# A non-scalar Char encodes as the three octets of U+FFFD.
law utf8_encode_char_non_scalar:
  for +c: U32
  for refused: {Utf8.scalar(c) == False{} : Bool}
  {Utf8.encode_char(c) == [239, 191, 189] : List<&2, U32>}

# Every String encodes to valid UTF-8 that decodes back to the same String
# with each non-scalar Char replaced by U+FFFD. Nothing is dropped.
law utf8_encode_total:
  for +s: String
  {Utf8.decode(Utf8.encode(s)) == Some{Spec.replaced(s)} : Maybe<&2, String>}

# Utf8.encode and Response.utf8, the encoder behind text responses, agree
# on every String.
law utf8_encode_response:
  for +s: String
  {Utf8.encode(s) == Response.utf8(s) : List<&2, U32>}

# A wire holding a non-scalar Char never decodes. With the BND-87 laws, the
# error is the percent error if the percent stage fails, else InvalidUtf8.
law url_decode_non_scalar:
  for +wire: String
  for refused: {Utf8.valid(wire) == False{} : Bool}
  exs error: Url.Error
  {Url.decode(wire) == Fail{error} : Result<&2, &2, Url.Error, String>}

law url_decode_form_non_scalar:
  for +wire: String
  for refused: {Utf8.valid(wire) == False{} : Bool}
  exs error: Url.Error
  {Url.decode_form(wire) == Fail{error} : Result<&2, &2, Url.Error, String>}

law url_parse_pairs_non_scalar:
  for +text: String
  for refused: {Utf8.valid(text) == False{} : Bool}
  exs error: Url.Error
  {Url.parse_pairs(text) == Fail{error} : Result<&2, &2, Url.Error, List<&2, Url.Entry>>}
