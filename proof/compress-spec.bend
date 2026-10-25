# BND-46: what response compression must do, stated without
# src/mw/compress_policy.bend's parsing and selection helpers. Only its data
# types (Coding, Pref) are shared.
#
# Accept-Encoding (RFC 9110 section 12.5.3). Every field is a comma list. A
# member is the text before its first ';', compared without surrounding SP
# and HTAB and in ASCII lowercase (the media-type essence of
# proof/media-spec.bend), and a member with an empty name is skipped. Its
# weight comes from the first parameter that, trimmed and lowercased, starts
# with the two characters "q="; the rest, trimmed, must be an RFC 9110 qvalue
# (section 12.4.2): "0" [ "." 0*3DIGIT ] or "1" [ "." 0*3("0") ]. A
# malformed qvalue weighs 0, and a member without a q parameter weighs 1000
# (weights are in thousandths). Splitting a field at commas, trimming and
# lowercasing are shared primitives (proof/response-policy-spec.bend);
# everything after them is restated here.
#
# A coding's weight is the weight of the first member naming it (x-gzip
# names gzip), else that of the first "*" member, else 0. identity weighs
# the same way. Gzip is chosen when its weight is positive, at least
# deflate's and at least identity's; deflate when its weight is positive,
# strictly above gzip's and at least identity's; otherwise nothing is.
import Base
import ../src/http/request.bend as Request
import ../src/http/bytes.bend as Bytes
import ../src/mw/compress_policy.bend as Compress
import ./response-policy-spec.bend as RS
import ./media-spec.bend as MediaSpec

# ---------------------------------------------------------------- qvalues

def digit(+c: U32) -> Bool:
  (c >= 48 : U32) && (c <= 57 : U32)

def value(+c: U32) -> Nat:
  U32.to_nat((c - 48 : U32))

def frac3_end(n: Nat, t: String) -> Maybe<&2, Nat>:
  match t:
    case SNil{}: Some{n}
    case SCon{c, u}: None{}

def frac3_digit(n: Nat, t: String, ok: Bool) -> Maybe<&2, Nat>:
  match ok:
    case False{}: None{}
    case True{}: frac3_end(n, t)

def frac2_end(n: Nat, t: String) -> Maybe<&2, Nat>:
  match t:
    case SNil{}: Some{n}
    case SCon{Chr{+c}, u}: frac3_digit(Nat.add(n, Nat.mul(value(c), 1n)), u, digit(c))

def frac2_digit(n: Nat, t: String, ok: Bool) -> Maybe<&2, Nat>:
  match ok:
    case False{}: None{}
    case True{}: frac2_end(n, t)

def frac1_end(n: Nat, t: String) -> Maybe<&2, Nat>:
  match t:
    case SNil{}: Some{n}
    case SCon{Chr{+c}, u}: frac2_digit(Nat.add(n, Nat.mul(value(c), 10n)), u, digit(c))

def frac1_digit(n: Nat, t: String, ok: Bool) -> Maybe<&2, Nat>:
  match ok:
    case False{}: None{}
    case True{}: frac1_end(n, t)

# At most three digits after the dot, in thousandths: "5" is 500, "05" is 50,
# "" is 0. Anything longer or not a digit is None.
def fraction(s: String) -> Maybe<&2, Nat>:
  match s:
    case SNil{}: Some{0n}
    case SCon{Chr{+c}, t}: frac1_digit(Nat.mul(value(c), 100n), t, digit(c))

def dot_fraction(rest: String, dot: Bool) -> Maybe<&2, Nat>:
  match dot:
    case True{}: fraction(rest)
    case False{}: None{}

# After a leading "0": nothing, or "." and a fraction.
def after_zero(t: String) -> Maybe<&2, Nat>:
  match t:
    case SNil{}: Some{0n}
    case SCon{Chr{+c}, rest}: dot_fraction(rest, U32.is_eq(c, 46))

def zero_fraction(z: Bool) -> Maybe<&2, Nat>:
  match z:
    case True{}: Some{1000n}
    case False{}: None{}

# "1." allows only a fraction worth 0, that is up to three zeros.
def one_fraction(f: Maybe<&2, Nat>) -> Maybe<&2, Nat>:
  match f:
    case None{}: None{}
    case Some{x}: zero_fraction(Nat.is_eq(x, 0n))

def one_dot(rest: String, dot: Bool) -> Maybe<&2, Nat>:
  match dot:
    case True{}: one_fraction(fraction(rest))
    case False{}: None{}

# After a leading "1": nothing, or "." and zeros.
def after_one(t: String) -> Maybe<&2, Nat>:
  match t:
    case SNil{}: Some{1000n}
    case SCon{Chr{+c}, rest}: one_dot(rest, U32.is_eq(c, 46))

def leading(t: String, zero: Bool, one: Bool) -> Maybe<&2, Nat>:
  match zero one:
    case True{} _: after_zero(t)
    case False{} True{}: after_one(t)
    case False{} False{}: None{}

# An RFC 9110 qvalue in thousandths, or None when s is not one.
def qvalue(s: String) -> Maybe<&2, Nat>:
  match s:
    case SNil{}: None{}
    case SCon{Chr{+c}, t}: leading(t, U32.is_eq(c, 48), U32.is_eq(c, 49))

# A malformed qvalue weighs 0.
def qweight(q: Maybe<&2, Nat>) -> Nat:
  match q:
    case None{}: 0n
    case Some{n}: n

# ------------------------------------------------------------- parameters

def q_pick(rest: String, q: Bool, eq: Bool) -> Maybe<&2, String>:
  match q eq:
    case True{} True{}: Some{rest}
    case True{} False{}: None{}
    case False{} _: None{}

def q_second(+a: Char, t: String) -> Maybe<&2, String>:
  match t:
    case SNil{}: None{}
    case SCon{+b, rest}: q_pick(rest, Char.is_eq(a, 'q'), Char.is_eq(b, '='))

# The text after a leading "q=", when p starts with it.
def q_text(p: String) -> Maybe<&2, String>:
  match p:
    case SNil{}: None{}
    case SCon{+a, t}: q_second(a, t)

def param_weight(q: Maybe<&2, String>, rest: Nat) -> Nat:
  match q:
    case None{}: rest
    case Some{v}: qweight(qvalue(String.trim(v)))

# The weight the parameters give: the first q parameter's, else 1000.
def weight(params: List<&2, String>) -> Nat:
  match params:
    case Nil{}: 1000n
    case p <> t: param_weight(q_text(Bytes.fold(String.trim(p))), weight(t))

# ---------------------------------------------------------------- members

def entry(+name: String, w: Nat, empty: Bool) -> List<&2, Compress.Pref>:
  match empty:
    case True{}: []
    case False{}: [Compress.Pref{name, w}]

def entry_named(+name: String, w: Nat) -> List<&2, Compress.Pref>:
  entry(name, w, String.is_empty(name))

def entry_parts(parts: List<&2, String>) -> List<&2, Compress.Pref>:
  match parts:
    case Nil{}: []
    case first <> params: entry_named(MediaSpec.essence(first), weight(params))

# One list member, already trimmed and lowercased.
def member(m: String) -> List<&2, Compress.Pref>:
  entry_parts(String.split(m, ';'))

def members(ms: List<&2, String>) -> List<&2, Compress.Pref>:
  match ms:
    case Nil{}: []
    case m <> t: List.append(&2, Compress.Pref, member(m), members(t))

# Every member of every Accept-Encoding field value, in order.
def prefs(values: List<&2, List<&2, U32>>) -> List<&2, Compress.Pref>:
  match values:
    case Nil{}: []
    case v <> t: List.append(&2, Compress.Pref, members(RS.value_members(v)), prefs(t))

# ------------------------------------------------------------- precedence

def first_pick(w: Nat, rest: Maybe<&2, Nat>, hit: Bool) -> Maybe<&2, Nat>:
  match hit:
    case True{}: Some{w}
    case False{}: rest

# The weight of the first member named name.
def first_named(ps: List<&2, Compress.Pref>, +name: String) -> Maybe<&2, Nat>:
  match ps:
    case Nil{}: None{}
    case Compress.Pref{+n, w} <> t: first_pick(w, first_named(t, name), String.eq(n, name))

def gzip_name(+n: String) -> Bool:
  String.eq(n, "gzip") || String.eq(n, "x-gzip")

# The weight of the first member naming gzip, as gzip or x-gzip.
def first_gzip(ps: List<&2, Compress.Pref>) -> Maybe<&2, Nat>:
  match ps:
    case Nil{}: None{}
    case Compress.Pref{+n, w} <> t: first_pick(w, first_gzip(t), gzip_name(n))

def explicit(+ps: List<&2, Compress.Pref>, c: Compress.Coding) -> Maybe<&2, Nat>:
  match c:
    case Compress.Gzip{}: first_gzip(ps)
    case Compress.Deflate{}: first_named(ps, "deflate")

# A coding named explicitly takes that weight, otherwise "*" gives one,
# otherwise it weighs 0.
def resolve(named: Maybe<&2, Nat>, star: Maybe<&2, Nat>) -> Nat:
  match named star:
    case Some{w} _: w
    case None{} Some{w}: w
    case None{} None{}: 0n

def pref_quality(+ps: List<&2, Compress.Pref>, c: Compress.Coding) -> Nat:
  resolve(explicit(ps, c), first_named(ps, "*"))

def pref_identity(+ps: List<&2, Compress.Pref>) -> Nat:
  resolve(first_named(ps, "identity"), first_named(ps, "*"))

# The weight the raw Accept-Encoding values give coding c.
def quality(values: List<&2, List<&2, U32>>, c: Compress.Coding) -> Nat:
  pref_quality(prefs(values), c)

def identity(values: List<&2, List<&2, U32>>) -> Nat:
  pref_identity(prefs(values))

# Whether a request with these values accepts c at all: it has a field, and
# c weighs more than 0.
def accepted(values: List<&2, List<&2, U32>>, c: Compress.Coding) -> Bool:
  match values:
    case Nil{}: False{}
    case v <> t: Bool.not(Nat.is_eq(quality(v <> t, c), 0n))

# ------------------------------------------------------------------ choice

def take(c: Compress.Coding, refused: Bool, below: Bool) -> Maybe<&2, Compress.Coding>:
  match refused below:
    case True{} _: None{}
    case False{} True{}: None{}
    case False{} False{}: Some{c}

# c at weight w, unless w is 0 or below identity's weight i.
def offer(c: Compress.Coding, +w: Nat, +i: Nat) -> Maybe<&2, Compress.Coding>:
  take(c, Nat.is_eq(w, 0n), Nat.is_lt(w, i))

def prefer(+g: Nat, +d: Nat, +i: Nat, deflate_higher: Bool) -> Maybe<&2, Compress.Coding>:
  match deflate_higher:
    case True{}: offer(Compress.Deflate{}, d, i)
    case False{}: offer(Compress.Gzip{}, g, i)

def pref_select(+ps: List<&2, Compress.Pref>) -> Maybe<&2, Compress.Coding>:
  prefer(pref_quality(ps, Compress.Gzip{}), pref_quality(ps, Compress.Deflate{}), pref_identity(ps), Nat.is_lt(pref_quality(ps, Compress.Gzip{}), pref_quality(ps, Compress.Deflate{})))

# The coding a request with these Accept-Encoding values gets. Without a
# field it gets none.
def choice(values: List<&2, List<&2, U32>>) -> Maybe<&2, Compress.Coding>:
  match values:
    case Nil{}: None{}
    case v <> t: pref_select(prefs(v <> t))

# ------------------------------------------------------------ media types

# Archives and compressed streams.
def archives() -> List<&2, String>:
  ["application/zip", "application/gzip", "application/x-gzip", "application/x-bzip2", "application/x-xz", "application/zstd", "application/x-zstd", "application/x-brotli", "application/x-7z-compressed", "application/x-rar-compressed", "application/vnd.rar"]

# WOFF and WOFF2 fonts, which are compressed inside.
def fonts() -> List<&2, String>:
  ["font/woff", "font/woff2", "application/font-woff", "application/font-woff2"]

def listed(+m: String, xs: List<&2, String>) -> Bool:
  match xs:
    case Nil{}: False{}
    case x <> t: String.eq(m, x) || listed(m, t)

# Raster images: every image type except SVG, which is text.
def raster(+m: String) -> Bool:
  String.starts_with(m, "image/") && Bool.not(String.eq(m, "image/svg+xml"))

# Whether the media type essence m names media that is already compressed:
# raster images, video, audio, archives and WOFF fonts.
def precompressed(+m: String) -> Bool:
  raster(m) || String.starts_with(m, "video/") || String.starts_with(m, "audio/") || listed(m, archives()) || listed(m, fonts())

# The essence of a response's first Content-Type field ("" without one):
# parameters dropped, trimmed and lowercased.
def content_type(values: List<&2, List<&2, U32>>) -> String:
  match values:
    case Nil{}: ""
    case v <> t: MediaSpec.essence(Bytes.ascii(v))

# ------------------------------------------------------------ field values

def field_pick(v: List<&2, U32>, rest: List<&2, List<&2, U32>>, hit: Bool) -> List<&2, List<&2, U32>>:
  match hit:
    case True{}: v <> rest
    case False{}: rest

# The value of every field named name (given in lowercase), any case, in
# order.
def field_values(hs: List<&2, Request.Header>, +name: String) -> List<&2, List<&2, U32>>:
  match hs:
    case Nil{}: []
    case Request.Header{+k, v} <> t: field_pick(v, field_values(t, name), String.eq(Bytes.fold(k), name))

# A strong entity tag starts with a double quote; a weak one with W/.
def strong(v: List<&2, U32>) -> Bool:
  match v:
    case Nil{}: False{}
    case c <> t: U32.is_eq(c, 34)

def strong_pick(v: List<&2, U32>, rest: Bool, etag: Bool) -> Bool:
  match etag:
    case True{}: strong(v) || rest
    case False{}: rest

# Whether any ETag field, any case, holds a strong tag.
def strong_etag(hs: List<&2, Request.Header>) -> Bool:
  match hs:
    case Nil{}: False{}
    case Request.Header{+k, v} <> t: strong_pick(v, strong_etag(t), String.eq(Bytes.fold(k), "etag"))

# The content-coding token RFC 9110 registers for each coding.
def token(c: Compress.Coding) -> String:
  match c:
    case Compress.Gzip{}: "gzip"
    case Compress.Deflate{}: "deflate"

# ---------------------------------------------------------------- examples

def raw(s: String) -> List<&2, List<&2, U32>>:
  [Bytes.encode(s)]

def example_q0() -> {quality(raw("gzip;q=0"), Compress.Gzip{}) == 0n : Nat}: {==}
def example_q0_dot() -> {quality(raw("gzip;q=0.000"), Compress.Gzip{}) == 0n : Nat}: {==}
def example_q_half() -> {quality(raw("GZip ; Q=0.5"), Compress.Gzip{}) == 500n : Nat}: {==}
def example_q_digits() -> {quality(raw("gzip;q=0.125"), Compress.Gzip{}) == 125n : Nat}: {==}
def example_q_one() -> {quality(raw("gzip;q=1.000"), Compress.Gzip{}) == 1000n : Nat}: {==}
def example_no_q() -> {quality(raw("gzip"), Compress.Gzip{}) == 1000n : Nat}: {==}
def example_bad_one() -> {quality(raw("gzip;q=1.5"), Compress.Gzip{}) == 0n : Nat}: {==}
def example_long() -> {quality(raw("gzip;q=0.1234"), Compress.Gzip{}) == 0n : Nat}: {==}
def example_text() -> {quality(raw("gzip;q=high"), Compress.Gzip{}) == 0n : Nat}: {==}
def example_empty_q() -> {quality(raw("gzip;q="), Compress.Gzip{}) == 0n : Nat}: {==}
def example_spaced_eq() -> {quality(raw("gzip;q =0"), Compress.Gzip{}) == 1000n : Nat}: {==}
def example_first_q() -> {quality(raw("gzip;q=0;q=1"), Compress.Gzip{}) == 0n : Nat}: {==}
def example_alias() -> {quality(raw("x-gzip;q=0.3"), Compress.Gzip{}) == 300n : Nat}: {==}
def example_star() -> {quality(raw("*;q=0.2"), Compress.Deflate{}) == 200n : Nat}: {==}
def example_named_beats_star() -> {quality(raw("*, gzip;q=0"), Compress.Gzip{}) == 0n : Nat}: {==}
def example_star_after() -> {quality(raw("gzip;q=0, *"), Compress.Gzip{}) == 0n : Nat}: {==}
def example_unnamed() -> {quality(raw("br"), Compress.Gzip{}) == 0n : Nat}: {==}
def example_fields() -> {quality([Bytes.encode("br"), Bytes.encode("deflate;q=0.4")], Compress.Deflate{}) == 400n : Nat}: {==}
def example_identity() -> {identity(raw("identity;q=0.5")) == 500n : Nat}: {==}
def example_no_field() -> {choice([]) == None{} : Maybe<&2, Compress.Coding>}: {==}
def example_refused() -> {choice(raw("gzip;q=0, deflate;q=0")) == None{} : Maybe<&2, Compress.Coding>}: {==}
def example_star_refused() -> {choice(raw("*;q=0")) == None{} : Maybe<&2, Compress.Coding>}: {==}
def example_tie() -> {choice(raw("deflate, gzip")) == Some{Compress.Gzip{}} : Maybe<&2, Compress.Coding>}: {==}
def example_deflate() -> {choice(raw("gzip;q=0.5, deflate")) == Some{Compress.Deflate{}} : Maybe<&2, Compress.Coding>}: {==}
def example_below_identity() -> {choice(raw("gzip;q=0.5, identity")) == None{} : Maybe<&2, Compress.Coding>}: {==}
def example_identity_refused() -> {choice(raw("gzip, identity;q=0")) == Some{Compress.Gzip{}} : Maybe<&2, Compress.Coding>}: {==}
def example_png() -> {precompressed(content_type(raw("Image/PNG; foo=bar"))) == True{} : Bool}: {==}
def example_svg() -> {precompressed(content_type(raw("image/svg+xml"))) == False{} : Bool}: {==}
def example_zip() -> {precompressed(content_type(raw(" application/ZIP"))) == True{} : Bool}: {==}
def example_html() -> {precompressed(content_type(raw("text/html; charset=utf-8"))) == False{} : Bool}: {==}
