# Pure decisions for response compression (BND-46); docs/compression.md.
# Negotiation reads Accept-Encoding into preferences with q-values in
# thousandths, and decide() says what the shell in src/compress.bend does
# with one buffered response. Free of IO so LAWS.bend can import it.
import Base
import ../http/request.bend as Request
import ../http/response.bend as Response
import ../http/media.bend as Media
import ../http/bytes.bend as Bytes
import ./vary.bend as Vary
import ./response_fields.bend as Fields

type Coding is Data:
  Gzip{}
  Deflate{}

# One Accept-Encoding member: the lowercase coding name ("*" included) and
# its weight from 0 to 1000.
type Pref is Data:
  Pref{name: String, q: Nat}

# threshold: bodies shorter than this many octets are sent as they are.
# limit: bodies longer than this are sent as they are, which bounds the
# memory a compression takes. level: the zlib level, 1 to 9.
type Config is Data:
  Config{threshold: U32, limit: U32, level: U32}

# What the shell does with a response.
type Plan is Data:
  # Leave it alone. The decision did not depend on Accept-Encoding.
  Keep{}
  # Send it as it is, with Accept-Encoding added to Vary.
  Vary{}
  # Compress the body with the coding.
  Encode{coding: Coding}
  # A HEAD answer whose GET would be compressed: compress the body to send
  # the fields GET would send, Content-Length included. The writer sends no
  # body for HEAD.
  Measure{coding: Coding}
  # A 304 whose 200 would be compressed: add Vary, weaken a strong ETag and
  # drop the identity length witness.
  Revalidated{coding: Coding}

# How a response carries its representation.
type Mode is Data:
  # A body the client receives.
  Full{}
  # A HEAD answer. It has no body to send, so it is measured instead.
  Headers{}
  # A 304 with the representation a matching GET would send.
  Revalidate{}

def defaults() -> Config:
  Config{1024, 8388608, 6}

def threshold(c: Config) -> U32:
  Config{t, l, v} = c
  t

def limit(c: Config) -> U32:
  Config{t, l, v} = c
  l

def level(c: Config) -> U32:
  Config{t, l, v} = c
  v

def with_threshold(c: Config, n: U32) -> Config:
  Config{t, l, v} = c
  Config{n, l, v}

def with_limit(c: Config, n: U32) -> Config:
  Config{t, l, v} = c
  Config{t, n, v}

def clamp_level(+n: U32, low: Bool, high: Bool) -> U32:
  match low high:
    case True{} _: 1
    case False{} True{}: 9
    case False{} False{}: n

def with_level(c: Config, +n: U32) -> Config:
  Config{t, l, v} = c
  Config{t, l, clamp_level(n, (n < 1 : U32), (n > 9 : U32))}

# ------------------------------------------------------------ Accept-Encoding

def frac_digit(+c: U32) -> Bool:
  (c >= 48 : U32) && (c <= 57 : U32)

def frac_add(acc: Maybe<&2, Nat>, +c: U32, scale: Nat, ok: Bool) -> Maybe<&2, Nat>:
  match acc ok:
    case None{} _: None{}
    case Some{n} True{}: Some{Nat.add(n, Nat.mul(U32.to_nat((c - 48 : U32)), scale))}
    case Some{n} False{}: None{}

# The digits after the dot, at most three, scaled to thousandths.
def frac_go(s: String, +scale: Nat, acc: Maybe<&2, Nat>) -> Maybe<&2, Nat>:
  match s:
    case SNil{}: acc
    case SCon{Chr{+c}, t}: frac_go(t, Nat.div(scale, 10n), frac_add(acc, c, scale, frac_digit(c) && Nat.is_gt(scale, 0n)))

def capped_pick(lead: Nat, x: Nat, zero_lead: Bool, zero_frac: Bool) -> Maybe<&2, Nat>:
  match zero_lead zero_frac:
    case True{} _: Some{x}
    case False{} True{}: Some{lead}
    case False{} False{}: None{}

# "1" allows only zero digits after its dot.
def capped(+lead: Nat, f: Maybe<&2, Nat>) -> Maybe<&2, Nat>:
  match f:
    case None{}: None{}
    case Some{+x}: capped_pick(lead, x, Nat.is_eq(lead, 0n), Nat.is_eq(x, 0n))

def dotted(+lead: Nat, rest: String, dot: Bool) -> Maybe<&2, Nat>:
  match dot:
    case True{}: capped(lead, frac_go(rest, 100n, Some{0n}))
    case False{}: None{}

def after_lead(+lead: Nat, t: String) -> Maybe<&2, Nat>:
  match t:
    case SNil{}: Some{lead}
    case SCon{Chr{+c}, rest}: dotted(lead, rest, U32.is_eq(c, 46))

def lead_pick(t: String, zero: Bool, one: Bool) -> Maybe<&2, Nat>:
  match zero one:
    case True{} _: after_lead(0n, t)
    case False{} True{}: after_lead(1000n, t)
    case False{} False{}: None{}

# RFC 9110 qvalue: "0" [ "." 0*3DIGIT ] or "1" [ "." 0*3("0") ], in
# thousandths. Anything else is None.
def qvalue(s: String) -> Maybe<&2, Nat>:
  match s:
    case SNil{}: None{}
    case SCon{Chr{+c}, t}: lead_pick(t, U32.is_eq(c, 48), U32.is_eq(c, 49))

# A malformed weight refuses the coding: compression only happens when the
# client clearly asked for it.
def weight(q: Maybe<&2, Nat>) -> Nat:
  match q:
    case None{}: 0n
    case Some{n}: n

def param_pick(+p: String, rest: Nat, is_q: Bool) -> Nat:
  match is_q:
    case True{}: weight(qvalue(String.trim(String.drop(p, 2n))))
    case False{}: rest

def params_q_step(+p: String, rest: Nat) -> Nat:
  param_pick(p, rest, String.starts_with(p, "q="))

# The first "q=" parameter decides; without one the weight is 1000.
def params_q(params: List<&2, String>) -> Nat:
  match params:
    case Nil{}: 1000n
    case p <> t: params_q_step(Bytes.fold(String.trim(p)), params_q(t))

def named_pref(+name: String, q: Nat, empty: Bool) -> List<&2, Pref>:
  match empty:
    case True{}: []
    case False{}: [Pref{name, q}]

def member_named(+name: String, q: Nat) -> List<&2, Pref>:
  named_pref(name, q, String.is_empty(name))

def member_parts(parts: List<&2, String>) -> List<&2, Pref>:
  match parts:
    case Nil{}: []
    case first <> params: member_named(Media.essence(first), params_q(params))

# One comma-separated member, already trimmed and lowercased; an empty
# member is skipped.
def member(item: String) -> List<&2, Pref>:
  member_parts(String.split(item, ';'))

def members(items: List<&2, String>) -> List<&2, Pref>:
  match items:
    case Nil{}: []
    case i <> t: List.append(&2, Pref, member(i), members(t))

def fields(values: List<&2, List<&2, U32>>) -> List<&2, Pref>:
  match values:
    case Nil{}: []
    case v <> t: List.append(&2, Pref, members(List.reverse(&2, String, Vary.items(v))), fields(t))

# Every Accept-Encoding field, in order. None means the request has none.
def accept(values: List<&2, List<&2, U32>>) -> Maybe<&2, List<&2, Pref>>:
  match values:
    case Nil{}: None{}
    case vs: Some{fields(vs)}

def lookup_pick(q: Nat, rest: Maybe<&2, Nat>, hit: Bool) -> Maybe<&2, Nat>:
  match hit:
    case True{}: Some{q}
    case False{}: rest

# The weight of the first member named a or b.
def lookup(prefs: List<&2, Pref>, +a: String, +b: String) -> Maybe<&2, Nat>:
  match prefs:
    case Nil{}: None{}
    case Pref{+n, q} <> t: lookup_pick(q, lookup(t, a, b), String.eq(n, a) || String.eq(n, b))

# An explicit member wins, then "*", then the coding is not acceptable.
def or_star(found: Maybe<&2, Nat>, star: Maybe<&2, Nat>) -> Nat:
  match found star:
    case Some{q} _: q
    case None{} Some{q}: q
    case None{} None{}: 0n

# RFC 9110 12.5.3: x-gzip is an alias of gzip.
def quality(+prefs: List<&2, Pref>, c: Coding) -> Nat:
  match c:
    case Gzip{}: or_star(lookup(prefs, "gzip", "x-gzip"), lookup(prefs, "*", "*"))
    case Deflate{}: or_star(lookup(prefs, "deflate", "deflate"), lookup(prefs, "*", "*"))

# identity is never refused here: the server sends it when nothing else is
# acceptable. Its weight only stops a coding the client likes less.
def identity_quality(+prefs: List<&2, Pref>) -> Nat:
  or_star(lookup(prefs, "identity", "identity"), lookup(prefs, "*", "*"))

def offered(c: Coding, below: Bool) -> Maybe<&2, Coding>:
  match below:
    case True{}: None{}
    case False{}: Some{c}

def offer(c: Coding, q: Nat, i: Nat) -> Maybe<&2, Coding>:
  match q:
    case 0n: None{}
    case 1n+k: offered(c, Nat.is_lt(1n+k, i))

def pick(g: Nat, d: Nat, i: Nat, deflate: Bool) -> Maybe<&2, Coding>:
  match deflate:
    case True{}: offer(Deflate{}, d, i)
    case False{}: offer(Gzip{}, g, i)

# The coding with the higher weight, gzip on a tie, unless its weight is 0
# or below identity's.
def select(+prefs: List<&2, Pref>) -> Maybe<&2, Coding>:
  pick(quality(prefs, Gzip{}), quality(prefs, Deflate{}), identity_quality(prefs), Nat.is_lt(quality(prefs, Gzip{}), quality(prefs, Deflate{})))

def choice(accept: Maybe<&2, List<&2, Pref>>) -> Maybe<&2, Coding>:
  match accept:
    case None{}: None{}
    case Some{prefs}: select(prefs)

# Whether the client accepts c at a nonzero weight. With no Accept-Encoding
# field it accepts nothing: such clients get identity.
def accepts(accept: Maybe<&2, List<&2, Pref>>, c: Coding) -> Bool:
  match accept:
    case None{}: False{}
    case Some{prefs}: Bool.not(Nat.is_eq(quality(prefs, c), 0n))

# ------------------------------------------------------------- eligibility

def present(hs: List<&2, Request.Header>, name: String) -> Bool:
  Bool.not(List.is_empty(&2, List<&2, U32>, Request.lookup(hs, name)))

# Content-Encoding already set, or a streamed body (B.stream, SSE, the
# proxy): the body is not this middleware's to rewrite.
def already(+hs: List<&2, Request.Header>) -> Bool:
  present(hs, "content-encoding") || present(hs, "x-bendo-stream-internal")

def no_body_status(+s: U32) -> Bool:
  (s < 200 : U32) || U32.is_eq(s, 204) || U32.is_eq(s, 205) || U32.is_eq(s, 206)

def no_transform(+hs: List<&2, Request.Header>) -> Bool:
  Vary.has("no-transform", Vary.all_items(Fields.values(hs, "cache-control")))

def starts(+m: String, p: String) -> Bool:
  String.starts_with(m, p)

def packed(+m: String) -> Bool:
  Vary.has(m, ["application/zip", "application/gzip", "application/x-gzip", "application/x-bzip2", "application/x-xz", "application/zstd", "application/x-zstd", "application/x-brotli", "application/x-7z-compressed", "application/x-rar-compressed", "application/vnd.rar", "application/octet-stream", "application/font-woff", "application/font-woff2", "font/woff", "font/woff2", "text/event-stream", "multipart/byteranges"])

# Already-compressed or unknown media: images other than SVG, video, audio,
# archives, WOFF fonts, octet streams. A response with no Content-Type is
# not compressed either.
def media_skipped(+m: String) -> Bool:
  String.is_empty(m) || (starts(m, "image/") && Bool.not(String.eq(m, "image/svg+xml"))) || starts(m, "video/") || starts(m, "audio/") || packed(m)

def content_type(values: List<&2, List<&2, U32>>) -> String:
  match values:
    case Nil{}: ""
    case v <> t: Media.essence(Bytes.ascii(v))

def media(hs: List<&2, Request.Header>) -> String:
  content_type(Request.lookup(hs, "content-type"))

# Range responses and no-transform are left alone, and so is a body over
# the memory limit.
def unfit(+hs: List<&2, Request.Header>, +n: Nat, l: U32) -> Bool:
  present(hs, "content-range") || no_transform(hs) || media_skipped(media(hs)) || Nat.is_lt(U32.to_nat(l), n)

def gated(mode: Mode, choice: Maybe<&2, Coding>) -> Plan:
  match mode choice:
    case Headers{} None{}: Vary{}
    case Headers{} Some{c}: Measure{c}
    case Full{} None{}: Vary{}
    case Full{} Some{c}: Encode{c}
    case Revalidate{} None{}: Vary{}
    case Revalidate{} Some{c}: Revalidated{c}

# Every gate is a Bool, checked in this order; the laws in LAWS.bend are
# lemmas about this function.
def plan(encoded: Bool, small: Bool, bad: Bool, mode: Mode, choice: Maybe<&2, Coding>) -> Plan:
  match encoded small bad:
    case True{} _ _: Keep{}
    case False{} True{} _: Keep{}
    case False{} False{} True{}: Keep{}
    case False{} False{} False{}: gated(mode, choice)

def small(n: Nat, t: U32) -> Bool:
  Nat.is_lt(n, U32.to_nat(t))

def body_mode(m: Request.Method) -> Mode:
  match m:
    case Request.Head{}: Headers{}
    case _: Full{}

# A 304 is judged by its length witness; without one nothing is known.
def revalidated(+cfg: Config, +hs: List<&2, Request.Header>, rep: Maybe<&2, List<&2, U32>>, choice: Maybe<&2, Coding>) -> Plan:
  match rep:
    case None{}: plan(already(hs), False{}, True{}, Revalidate{}, choice)
    case Some{+w}: plan(already(hs), small(Response.length(w), threshold(cfg)), unfit(hs, Response.length(w), limit(cfg)), Revalidate{}, choice)

def full(+cfg: Config, m: Request.Method, choice: Maybe<&2, Coding>, +s: U32, +hs: List<&2, Request.Header>, +n: Nat) -> Plan:
  plan(already(hs), small(n, threshold(cfg)), no_body_status(s) || unfit(hs, n, limit(cfg)), body_mode(m), choice)

def sized(cfg: Config, m: Request.Method, choice: Maybe<&2, Coding>, +s: U32, +hs: List<&2, Request.Header>, body: List<&2, U32>, rep: Maybe<&2, List<&2, U32>>, not_modified: Bool) -> Plan:
  match not_modified:
    case True{}: revalidated(cfg, hs, rep, choice)
    case False{}: full(cfg, m, choice, s, hs, Response.length(body))

# What to do with res for a request with method m and Accept-Encoding
# preferences accept.
def decide(cfg: Config, m: Request.Method, accept: Maybe<&2, List<&2, Pref>>, res: Response.Res) -> Plan:
  Response.Res{+s, hs, body, rep} = res
  sized(cfg, m, choice(accept), s, hs, body, rep, U32.is_eq(s, 304))

def encodes(p: Plan) -> Bool:
  match p:
    case Encode{c}: True{}
    case _: False{}

# Keep is the one plan made without reading Accept-Encoding.
def is_keep(p: Plan) -> Bool:
  match p:
    case Keep{}: True{}
    case _: False{}

# The coding an Encode or Measure plan compresses with.
def coding(p: Plan) -> Maybe<&2, Coding>:
  match p:
    case Encode{c}: Some{c}
    case Measure{c}: Some{c}
    case _: None{}

# The plan a HEAD request gets where its GET would get p.
def headed(p: Plan) -> Plan:
  match p:
    case Encode{c}: Measure{c}
    case _: p

# ---------------------------------------------------------------- rewrites

def coding_name(c: Coding) -> String:
  match c:
    case Gzip{}: "gzip"
    case Deflate{}: "deflate"

# The effect's format word: 1 gzip (RFC 1952), 2 zlib (RFC 1950).
def format(c: Coding) -> U32:
  match c:
    case Gzip{}: 1
    case Deflate{}: 2

def weak_pick(c: U32, t: List<&2, U32>, quote: Bool) -> List<&2, U32>:
  match quote:
    case True{}: 87 <> (47 <> (c <> t))
    case False{}: c <> t

def weak_value(v: List<&2, U32>) -> List<&2, U32>:
  match v:
    case Nil{}: []
    case +c <> t: weak_pick(c, t, U32.is_eq(c, 34))

def weak_named(n: String, v: List<&2, U32>, etag: Bool) -> Request.Header:
  match etag:
    case True{}: Request.Header{n, weak_value(v)}
    case False{}: Request.Header{n, v}

def weak_header(h: Request.Header) -> Request.Header:
  match h:
    case Request.Header{+n, v}: weak_named(n, v, String.eq(Bytes.fold(n), "etag"))

# A strong ETag "x" becomes W/"x": the coded bytes differ from the identity
# bytes the tag was computed over, so they are only weakly equivalent.
def weaken(hs: List<&2, Request.Header>) -> List<&2, Request.Header>:
  match hs:
    case Nil{}: []
    case h <> t: weak_header(h) <> weaken(t)

def varied_headers(+hs: List<&2, Request.Header>) -> List<&2, Request.Header>:
  Vary.add(hs, ["Accept-Encoding"])

def varied(res: Response.Res) -> Response.Res:
  Response.Res{s, hs, b, rep} = res
  Response.Res{s, varied_headers(hs), b, rep}

def revalidated_res(res: Response.Res) -> Response.Res:
  Response.Res{s, hs, b, rep} = res
  Response.Res{s, varied_headers(weaken(hs)), b, None{}}

# Content-Encoding is only ever set by this rewrite, so the coded response
# names exactly one coding.
def drop_framing(+hs: List<&2, Request.Header>) -> List<&2, Request.Header>:
  Fields.without(Fields.without(Fields.without(hs, "content-length"), "accept-ranges"), "content-encoding")

# The coded response: the coded body, Content-Encoding, Vary and a weak
# ETag. Accept-Ranges goes, because ranges would count identity octets.
# The writer derives Content-Length from the new body.
def encoded(res: Response.Res, c: Coding, z: List<&2, U32>) -> Response.Res:
  Response.Res{s, hs, b, rep} = res
  Response.Res{s, List.append(&2, Request.Header, varied_headers(weaken(drop_framing(hs))), [Request.Header{"content-encoding", Bytes.encode(coding_name(c))}]), z, None{}}

def body_length(res: Response.Res) -> Nat:
  Response.Res{s, hs, b, rep} = res
  Response.length(b)

def smaller(res: Response.Res, c: Coding, z: List<&2, U32>, shorter: Bool) -> Response.Res:
  match shorter:
    case True{}: encoded(res, c, z)
    case False{}: varied(res)

# Whether out is a coded body shorter than res's, which coded() sends.
def shrinks(res: Response.Res, out: Maybe<&2, List<&2, U32>>) -> Bool:
  match out:
    case None{}: False{}
    case Some{z}: Nat.is_lt(Response.length(z), body_length(res))

# The response for an Encode or Measure plan once zlib has run: the coded
# octets, or None when compression failed. A coded body no shorter than the
# original is not worth sending.
def coded(+res: Response.Res, c: Coding, out: Maybe<&2, List<&2, U32>>) -> Response.Res:
  match out:
    case None{}: varied(res)
    case Some{+z}: smaller(res, c, z, Nat.is_lt(Response.length(z), body_length(res)))

# The response the shell sends for a plan; out is the zlib result, read
# only by Encode and Measure. The laws about header rewrites are about this.
def respond(+res: Response.Res, p: Plan, out: Maybe<&2, List<&2, U32>>) -> Response.Res:
  match p:
    case Keep{}: res
    case Vary{}: varied(res)
    case Encode{c}: coded(res, c, out)
    case Measure{c}: coded(res, c, out)
    case Revalidated{c}: revalidated_res(res)
