# BND-92: an independent specification of the raw query parser,
# Url.parse_pairs, following the WHATWG URL Standard's
# application/x-www-form-urlencoded parser (section 5.1) with Bendo's strict
# policy in place of the standard's lenient fallbacks.
#
# The standard splits the input's UTF-8 octets on "&", skips empty pieces,
# splits each piece at its first "=" (a piece without one is a name with an
# empty value), turns "+" into a space, percent-decodes, and decodes UTF-8.
# Where the standard would keep a malformed "%" literally or substitute
# U+FFFD, Bendo refuses: a bad escape fails with InvalidPercent and octets
# that are not UTF-8 fail with InvalidUtf8, the first failure in input order
# winning, name before value. After that, a String holding a non-scalar
# character is refused with InvalidUtf8 (BND-100).
#
# Nothing here calls urlencoded.bend's parser; the import is for its Entry
# and Error types only. The hex digits and escapes come from the
# independent RFC 3986 decoder in url-decode-spec.bend, and UTF-8 from
# utf8.bend, which has its own laws.
import Base
import ../src/data/urlencoded.bend as Url
import ../src/data/utf8.bend as Utf8
import ./url-decode-spec.bend as DSpec

# The octets between "&"s, in order. The empty input is one empty piece.
def grow(+b: U32, ps: List<&2, List<&2, U32>>) -> List<&2, List<&2, U32>>:
  match ps:
    case Nil{}: [[b]]
    case p <> rest: (b <> p) <> rest

def pieces(xs: List<&2, U32>) -> List<&2, List<&2, U32>>:
  match xs:
    case Nil{}: [[]]
    case 38 <> t: [] <> pieces(t)
    case +b <> t: grow(b, pieces(t))

# A piece's name: the octets before its first "=", or all of them.
def name(xs: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}: []
    case 61 <> t: []
    case +b <> t: b <> name(t)

# A piece's value: the octets after its first "=", or none.
def value(xs: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}: []
    case 61 <> t: t
    case +b <> t: value(t)

# A literal "+" is a space.
def space(+b: U32, plus: Bool) -> U32:
  match plus:
    case True{}: 32
    case False{}: b

# Percent decoding for form text: "%HH" in either hex case is one octet, an
# escaped "%2B" stays "+", a "%" without two hex digits fails, and a literal
# "+" becomes a space.
def unpercent(xs: List<&2, U32>) -> Result<&2, &2, Url.Error, List<&2, U32>>:
  match xs:
    case Nil{}: Done{[]}
    case 37 <> +a <> +b <> t: DSpec.escaped(DSpec.hexdig(a), DSpec.hexdig(b), unpercent(t))
    case 37 <> t: Fail{Url.InvalidPercent{}}
    case +b <> t: DSpec.literal(space(b, U32.is_eq(b, 43)), unpercent(t))

def utf8(s: Maybe<&2, String>) -> Result<&2, &2, Url.Error, String>:
  match s:
    case None{}: Fail{Url.InvalidUtf8{}}
    case Some{s}: Done{s}

# One name or value: percent-decoded octets that must be UTF-8.
def text(r: Result<&2, &2, Url.Error, List<&2, U32>>) -> Result<&2, &2, Url.Error, String>:
  match r:
    case Fail{e}: Fail{e}
    case Done{os}: utf8(Utf8.decode(os))

def pair(k: Result<&2, &2, Url.Error, String>, v: Result<&2, &2, Url.Error, String>) -> Result<&2, &2, Url.Error, Url.Entry>:
  match k v:
    case Fail{e} _: Fail{e}
    case Done{k} Fail{e}: Fail{e}
    case Done{k} Done{v}: Done{Url.Entry{k, v}}

def entry(+p: List<&2, U32>) -> Result<&2, &2, Url.Error, Url.Entry>:
  pair(text(unpercent(name(p))), text(unpercent(value(p))))

def cons(e: Result<&2, &2, Url.Error, Url.Entry>, rest: Result<&2, &2, Url.Error, List<&2, Url.Entry>>) -> Result<&2, &2, Url.Error, List<&2, Url.Entry>>:
  match e rest:
    case Fail{x} _: Fail{x}
    case Done{e} Fail{x}: Fail{x}
    case Done{e} Done{es}: Done{e <> es}

# One entry per non-empty piece, in order; the first failure wins.
def entries(ps: List<&2, List<&2, U32>>) -> Result<&2, &2, Url.Error, List<&2, Url.Entry>>:
  match ps:
    case Nil{}: Done{[]}
    case Nil{} <> t: entries(t)
    case p <> t: cons(entry(p), entries(t))

def refuse(r: Result<&2, &2, Url.Error, List<&2, Url.Entry>>, scalars: Bool) -> Result<&2, &2, Url.Error, List<&2, Url.Entry>>:
  match r scalars:
    case Fail{e} _: Fail{e}
    case Done{es} True{}: Done{es}
    case Done{es} False{}: Fail{Url.InvalidUtf8{}}

# The query string's entries, read from its UTF-8 octets.
def parse(+s: String) -> Result<&2, &2, Url.Error, List<&2, Url.Entry>>:
  refuse(entries(pieces(Utf8.encode(s))), Utf8.valid(s))
