# Query components use RFC 3986 unreserved characters. Form components use
# the WHATWG form encode set and '+' for space. Only '&' separates pairs.
import Base
import ./utf8.bend as Utf8
import ../http/bytes.bend as Bytes

type Error is Data:
  InvalidPercent{}
  InvalidUtf8{}
  UnsupportedMediaType{}
  UnsupportedCharset{}

type Entry is Data:
  Entry{key: String, value: String}

def hex_digit(+n: U32, decimal: Bool) -> Char:
  match decimal:
    case True{}:
      Chr{(48 + n : U32)}
    case False{}:
      Chr{(55 + n : U32)}

def escaped(+b: U32) -> String:
  +hi = (b >> 4n : U32)
  +lo = (b .&. 15 : U32)
  SCon{'%', SCon{hex_digit(hi, (hi < 10 : U32)), SCon{hex_digit(lo, (lo < 10 : U32)), ""}}}

def safe(+b: U32, +form: Bool) -> Bool:
  ((b >= 48 : U32) && (b <= 57 : U32)) || ((b >= 65 : U32) && (b <= 90 : U32)) || ((b >= 97 : U32) && (b <= 122 : U32)) || U32.is_eq(b, 45) || U32.is_eq(b, 46) || U32.is_eq(b, 95) || (U32.is_eq(b, 42) && form) || (U32.is_eq(b, 126) && Bool.not(form))

def encode_space(+b: U32, space: Bool) -> String:
  match space:
    case True{}:
      "+"
    case False{}:
      escaped(b)

def encode_byte(+b: U32, +form: Bool, keep: Bool) -> String:
  match keep:
    case True{}:
      Char.show(Chr{b})
    case False{}:
      encode_space(b, U32.is_eq(b, 32) && form)

def encode_bytes_spec(xs: List<&2, U32>, +form: Bool) -> String:
  match xs:
    case Nil{}:
      ""
    case +b <> t:
      encode_byte(b, form, safe(b, form)) ++ encode_bytes_spec(t, form)

def encode_bytes_go(xs: List<&2, U32>, +form: Bool, acc: String) -> String:
  match xs:
    case Nil{}:
      acc
    case +b <> t:
      encode_bytes_go(t, form, encode_byte(b, form, safe(b, form)) ++ acc)

def encode_bytes(xs: List<&2, U32>, form: Bool) -> String:
  encode_bytes_go(List.reverse(&2, U32, xs), form, "")

# These encoders accept Strings of Unicode scalar values (Utf8.valid).
def encode(s: String) -> String:
  encode_bytes(Utf8.encode(s), False{})

def encode_form(s: String) -> String:
  encode_bytes(Utf8.encode(s), True{})

def hex_lower(+b: U32, lower: Bool) -> U32:
  match lower:
    case True{}:
      (b - 87 : U32)
    case False{}:
      (b - 55 : U32)

def hex_value(+b: U32, decimal: Bool) -> U32:
  match decimal:
    case True{}:
      (b - 48 : U32)
    case False{}:
      hex_lower(b, (b >= 97 : U32))

def unhex(+b: U32) -> U32:
  hex_value(b, (b <= 57 : U32))

def plus_byte(b: U32, space: Bool) -> U32:
  match space:
    case True{}:
      32
    case False{}:
      b

# The state carries reversed decoded octets or the first percent error.
def percent_step(+a: U32, +b: U32, rev: List<&2, U32>, valid: Bool) -> Result<&2, &2, Error, List<&2, U32>>:
  match valid:
    case False{}:
      Fail{InvalidPercent{}}
    case True{}:
      Done{((unhex(a) << 4n : U32) + unhex(b) : U32) <> rev}

def percent_decode_go(xs: List<&2, U32>, +form: Bool, state: Result<&2, &2, Error, List<&2, U32>>) -> Result<&2, &2, Error, List<&2, U32>>:
  match xs state:
    case _ Fail{e}:
      Fail{e}
    case Nil{} Done{rev}:
      Done{List.reverse(&2, U32, rev)}
    case 37 <> +a <> +b <> t Done{rev}:
      percent_decode_go(t, form, percent_step(a, b, rev, Bytes.hex(a) && Bytes.hex(b)))
    case 37 <> t Done{rev}:
      Fail{InvalidPercent{}}
    case +b <> t Done{rev}:
      percent_decode_go(t, form, Done{plus_byte(b, U32.is_eq(b, 43) && form) <> rev})

def percent_decode(xs: List<&2, U32>, form: Bool) -> Result<&2, &2, Error, List<&2, U32>>:
  percent_decode_go(xs, form, Done{[]})

def utf8_result(s: Maybe<&2, String>) -> Result<&2, &2, Error, String>:
  match s:
    case None{}:
      Fail{InvalidUtf8{}}
    case Some{s}:
      Done{s}

def decode_result(r: Result<&2, &2, Error, List<&2, U32>>) -> Result<&2, &2, Error, String>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{xs}:
      utf8_result(Utf8.decode(xs))

def decode_bytes(xs: List<&2, U32>, form: Bool) -> Result<&2, &2, Error, String>:
  decode_result(percent_decode(xs, form))

def decode(s: String) -> Result<&2, &2, Error, String>:
  decode_bytes(Utf8.encode(s), False{})

def decode_form(s: String) -> Result<&2, &2, Error, String>:
  decode_bytes(Utf8.encode(s), True{})

# Split at the first '=' only, without interpreting percent escapes.
def field_go(xs: List<&2, U32>, rev: List<&2, U32>) -> List<&2, U32> & List<&2, U32>:
  match xs:
    case Nil{}:
      (List.reverse(&2, U32, rev), [])
    case 61 <> t:
      (List.reverse(&2, U32, rev), t)
    case b <> t:
      field_go(t, b <> rev)

def field(xs: List<&2, U32>) -> List<&2, U32> & List<&2, U32>:
  field_go(xs, [])

def split_go(xs: List<&2, U32>, current: List<&2, U32>, parts: List<&2, List<&2, U32>>) -> List<&2, List<&2, U32>>:
  match xs:
    case Nil{}:
      List.reverse(&2, List<&2, U32>, List.reverse(&2, U32, current) <> parts)
    case 38 <> t:
      split_go(t, [], List.reverse(&2, U32, current) <> parts)
    case b <> t:
      split_go(t, b <> current, parts)

def split(xs: List<&2, U32>) -> List<&2, List<&2, U32>>:
  split_go(xs, [], [])

def pair_result(k: Result<&2, &2, Error, String>, v: Result<&2, &2, Error, String>, rest: Result<&2, &2, Error, List<&2, Entry>>) -> Result<&2, &2, Error, List<&2, Entry>>:
  match k v rest:
    case Fail{e} _ _:
      Fail{e}
    case _ Fail{e} _:
      Fail{e}
    case _ _ Fail{e}:
      Fail{e}
    case Done{k} Done{v} Done{ps}:
      Done{Entry{k, v} <> ps}

def parse_field(parts: List<&2, U32> & List<&2, U32>, rest: Result<&2, &2, Error, List<&2, Entry>>) -> Result<&2, &2, Error, List<&2, Entry>>:
  (k, v) = parts
  pair_result(decode_bytes(k, True{}), decode_bytes(v, True{}), rest)

# WHATWG ignores empty pieces: '' and '&&' both parse to no pairs.
def parse_parts_go(parts: List<&2, List<&2, U32>>, state: Result<&2, &2, Error, List<&2, Entry>>) -> Result<&2, &2, Error, List<&2, Entry>>:
  match parts state:
    case _ Fail{e}:
      Fail{e}
    case Nil{} Done{rev}:
      Done{List.reverse(&2, Entry, rev)}
    case Nil{} <> t Done{rev}:
      parse_parts_go(t, Done{rev})
    case (b <> bs) <> t Done{rev}:
      parse_parts_go(t, parse_field(field(b <> bs), Done{rev}))

def parse_parts(parts: List<&2, List<&2, U32>>) -> Result<&2, &2, Error, List<&2, Entry>>:
  parse_parts_go(parts, Done{[]})

def parse_pairs_bytes(body: List<&2, U32>) -> Result<&2, &2, Error, List<&2, Entry>>:
  parse_parts(split(body))

def parse_pairs(s: String) -> Result<&2, &2, Error, List<&2, Entry>>:
  parse_pairs_bytes(Utf8.encode(s))

def select_value(v: String, rest: List<&2, String>, same: Bool) -> List<&2, String>:
  match same:
    case True{}:
      v <> rest
    case False{}:
      rest

# Pure accessors for BND-21. Keys are case-sensitive and already decoded.
def queries_spec(pairs: List<&2, Entry>, +key: String) -> List<&2, String>:
  match pairs:
    case Nil{}:
      []
    case Entry{k, v} <> t:
      select_value(v, queries_spec(t, key), String.eq(k, key))

def queries_go(pairs: List<&2, Entry>, +key: String, acc: List<&2, String>) -> List<&2, String>:
  match pairs:
    case Nil{}:
      acc
    case Entry{k, v} <> t:
      queries_go(t, key, select_value(v, acc, String.eq(k, key)))

def queries(pairs: List<&2, Entry>, key: String) -> List<&2, String>:
  queries_go(List.reverse(&2, Entry, pairs), key, [])

def first(xs: List<&2, String>) -> Maybe<&2, String>:
  match xs:
    case Nil{}:
      None{}
    case v <> t:
      Some{v}

def query(pairs: List<&2, Entry>, key: String) -> Maybe<&2, String>:
  first(queries(pairs, key))

# Append strings through a reversed buffer, without Base's recursive append.
def serialize_go(pairs: List<&2, Entry>, acc: String) -> String:
  match pairs:
    case Nil{}:
      String.reverse(acc)
    case Entry{k, v} <> Nil{}:
      String.reverse(String.reverse.go(encode_form(v), SCon{'=', String.reverse.go(encode_form(k), acc)}))
    case Entry{k, v} <> next <> t:
      serialize_go(next <> t, SCon{'&', String.reverse.go(encode_form(v), SCon{'=', String.reverse.go(encode_form(k), acc)})})

def serialize(pairs: List<&2, Entry>) -> String:
  serialize_go(pairs, "")

# Content-Type uses ASCII case-insensitive tokens; charset is UTF-8 only.
# Parameters other than charset are ignored. All charset declarations must
# agree; quoted UTF-8 is accepted, unknown/malformed charset is rejected.
def unquote(s: String, rev: String, escaped: Bool) -> Maybe<&2, String>:
  match s escaped:
    case SNil{} _:
      None{}
    case SCon{c, t} True{}:
      unquote(t, SCon{c, rev}, False{})
    case SCon{Chr{92}, t} False{}:
      unquote(t, rev, True{})
    case SCon{Chr{34}, SNil{}} False{}:
      Some{String.reverse(rev)}
    case SCon{Chr{34}, t} False{}:
      None{}
    case SCon{c, t} False{}:
      unquote(t, SCon{c, rev}, False{})

def charset_quoted(value: Maybe<&2, String>) -> Bool:
  match value:
    case None{}:
      False{}
    case Some{s}:
      String.eq(s, "utf-8")

def charset_text(s: String) -> Bool:
  match s:
    case SCon{Chr{34}, t}:
      charset_quoted(unquote(t, "", False{}))
    case s:
      String.eq(s, "utf-8")

# Base's to_lower builds after recursion; use an accumulator for .mjs.
def lower_go(s: String, rev: String) -> String:
  match s:
    case SNil{}:
      String.reverse(rev)
    case SCon{c, t}:
      lower_go(t, SCon{Char.to_lower(c), rev})

def lower(s: String) -> String:
  lower_go(s, "")

def charset_value(v: String) -> Bool:
  charset_text(lower(String.trim(v)))

def parameter_value(k: String, v: String) -> Bool:
  Bool.not(String.eq(lower(String.trim(k)), "charset")) || charset_value(v)

# Split the first '=' directly on Strings. Avoid the recursive byte/string
# conversions in the HTTP module, since these decoders also run as .mjs.
def parameter_go(s: String, rev: String) -> Bool:
  match s:
    case SNil{}:
      parameter_value(String.reverse(rev), "")
    case SCon{Chr{61}, t}:
      parameter_value(String.reverse(rev), t)
    case SCon{c, t}:
      parameter_go(t, SCon{c, rev})

def parameters_go(xs: List<&2, String>, ok: Bool) -> Bool:
  match xs ok:
    case _ False{}:
      False{}
    case Nil{} True{}:
      True{}
    case h <> t True{}:
      parameters_go(t, parameter_go(h, ""))

def parameters(xs: List<&2, String>) -> Bool:
  parameters_go(xs, True{})

def body_charset(body: List<&2, U32>, ok: Bool) -> Result<&2, &2, Error, List<&2, Entry>>:
  match ok:
    case False{}:
      Fail{UnsupportedCharset{}}
    case True{}:
      parse_pairs_bytes(body)

def body_media(params: List<&2, String>, body: List<&2, U32>, ok: Bool) -> Result<&2, &2, Error, List<&2, Entry>>:
  match ok:
    case False{}:
      Fail{UnsupportedMediaType{}}
    case True{}:
      body_charset(body, parameters(params))

def body_type(parts: List<&2, String>, body: List<&2, U32>) -> Result<&2, &2, Error, List<&2, Entry>>:
  match parts:
    case Nil{}:
      Fail{UnsupportedMediaType{}}
    case media <> params:
      body_media(params, body, String.eq(lower(String.trim(media)), "application/x-www-form-urlencoded"))

# Semicolons inside quoted values are data, and quoted-pair escapes do not
# toggle quote state. Preserve the original text for parameter validation.
type MediaScan is Data:
  MediaScan{quoted: Bool, escaped: Bool, current: String, parts: List<&2, String>}

def media_char(state: MediaScan, c: Char) -> MediaScan:
  match state c:
    case MediaScan{q, True{}, rev, parts} c:
      MediaScan{q, False{}, SCon{c, rev}, parts}
    case MediaScan{True{}, False{}, rev, parts} Chr{92}:
      MediaScan{True{}, True{}, SCon{Chr{92}, rev}, parts}
    case MediaScan{q, False{}, rev, parts} Chr{34}:
      MediaScan{Bool.not(q), False{}, SCon{Chr{34}, rev}, parts}
    case MediaScan{False{}, False{}, rev, parts} Chr{59}:
      MediaScan{False{}, False{}, "", String.reverse(rev) <> parts}
    case MediaScan{q, False{}, rev, parts} c:
      MediaScan{q, False{}, SCon{c, rev}, parts}

def media_finish(state: MediaScan) -> List<&2, String>:
  match state:
    case MediaScan{q, e, rev, parts}:
      List.reverse(&2, String, String.reverse(rev) <> parts)

def media_scan(s: String, state: MediaScan) -> List<&2, String>:
  match s:
    case SNil{}:
      media_finish(state)
    case SCon{c, t}:
      media_scan(t, media_char(state, c))

def parse_body(content_type: String, body: List<&2, U32>) -> Result<&2, &2, Error, List<&2, Entry>>:
  body_type(media_scan(content_type, MediaScan{False{}, False{}, "", []}), body)
