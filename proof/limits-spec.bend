# RFC 9110 section 13.1.2 reference evaluator. No call to the production
# parser or conditional decision; only octet classes and OWS trimming shared.
import Base
import ../src/http/conditional.bend as Conditional
import ../src/mw/common.bend as Common
import ../src/http/conditional-lex.bend as Lex
import ../src/http/bytes.bend as Bytes
import ../src/http/request.bend as Request
import ../src/http/response.bend as Response


# Grammar builds the denoted text from the tail, without a scanning accumulator.
def character(c: Char, parsed: Maybe<&2, String>, valid: Bool) -> Maybe<&2, String>:
  match parsed valid:
    case Some{s} True{}: Some{SCon{c, s}}
    case _ _: None{}

def grammar_end(c: Char, parsed: Maybe<&2, String>, end: Bool, valid: Bool) -> Maybe<&2, String>:
  match end:
    case True{}: Some{""}
    case False{}: character(c, parsed, valid)

def tag_tail(s: String) -> Maybe<&2, String>:
  match s:
    case SNil{}: None{}
    case SCon{Chr{+c}, +t}:
      grammar_end(Chr{c}, tag_tail(t), U32.is_eq(c, 34) && String.is_empty(t), Lex.etagc(c))

# Prefix is used only to state the accumulator invariant in the proof.
def prefix(acc: String, parsed: Maybe<&2, String>) -> Maybe<&2, String>:
  match parsed:
    case None{}: None{}
    case Some{s}: Some{String.reverse.go(acc, s)}

def opaque(s: String, acc: String) -> Maybe<&2, String>:
  prefix(acc, tag_tail(s))

def unweak(+s: String, weak: Bool) -> String:
  match weak:
    case True{}: String.drop(s, 2n)
    case False{}: s

def quoted(parsed: Maybe<&2, String>, quote: Bool) -> Maybe<&2, String>:
  match quote:
    case True{}: parsed
    case False{}: None{}

def entity_strong(+s: String) -> Maybe<&2, String>:
  quoted(opaque(String.drop(s, 1n), ""), String.starts_with(s, "\""))

def entity(+s: String) -> Maybe<&2, String>:
  entity_strong(unweak(s, String.starts_with(s, "W/")))

def equal(a: Maybe<&2, String>, b: Maybe<&2, String>) -> Bool:
  match a b:
    case Some{x} Some{y}: String.eq(x, y)
    case _ _: False{}

# A list's grammar is a right fold: a separator starts a new element;
# every other octet prefixes the first element of the suffix's list.
def toggled(q: Bool, quote: Bool) -> Bool:
  match quote:
    case True{}: Bool.not(q)
    case False{}: q

type Elements is Data:
  Elements{first: String, rest: List<&2, String>}

def list_char(c: Char, parts: Elements, separator: Bool) -> Elements:
  match parts separator:
    case Elements{h, t} True{}: Elements{"", h <> t}
    case Elements{h, t} False{}: Elements{SCon{c, h}, t}

def parts(s: String, +quoted: Bool) -> Elements:
  match s:
    case SNil{}: Elements{"", []}
    case SCon{Chr{+c}, t}:
      list_char(Chr{c}, parts(t, toggled(quoted, U32.is_eq(c, 34))), U32.is_eq(c, 44) && Bool.not(quoted))

def prefix_parts(acc: String, parts: Elements) -> List<&2, String>:
  Elements{h, tail} = parts
  String.reverse.go(acc, h) <> tail

def segments(s: String, quoted: Bool, acc: String) -> List<&2, String>:
  prefix_parts(acc, parts(s, quoted))

def trim(s: String) -> String: Bytes.ascii(Bytes.trim(Bytes.encode(s)))

# Denotation is a conjunction over the grammar and an existential weak match.
# These are separate traversals, unlike the implementation's combined fold.
def valid_token(+s: String) -> Bool:
  String.is_empty(s) || Maybe.is_some(&2, String, entity(s))

def all_valid(xs: List<&2, String>) -> Bool:
  match xs:
    case Nil{}: True{}
    case +h <> t: valid_token(trim(h)) && all_valid(t)

def any_match(xs: List<&2, String>, +tag: Maybe<&2, String>) -> Bool:
  match xs:
    case Nil{}: False{}
    case h <> t: equal(entity(trim(h)), tag) || any_match(t, tag)

def members(+xs: List<&2, String>, tag: Maybe<&2, String>) -> Sigma<&2, &2, Bool, _ => Bool>:
  (all_valid(xs), any_match(xs, tag))

def decision(pair: Sigma<&2, &2, Bool, _ => Bool>) -> Bool:
  (valid, hit) = pair
  valid && hit

def evaluate(+field: String, tag: Maybe<&2, String>, star: Bool) -> Bool:
  match star:
    case True{}: Maybe.is_some(&2, String, tag)
    case False{}: decision(members(segments(field, False{}, ""), tag))

def matches(field: Maybe<&2, String>, tag: String) -> Bool:
  match field:
    case None{}: False{}
    case Some{+s}: evaluate(s, entity(tag), String.eq(trim(s), "*"))

# RFC 9110 15.4.5 cache metadata, in original order including duplicates.
def allowed(+name: String) -> Bool:
  String.eq(name, "etag") || String.eq(name, "cache-control") || String.eq(name, "vary") || String.eq(name, "date") || String.eq(name, "content-location") || String.eq(name, "expires")

def selected(h: Request.Header, rest: List<&2, Request.Header>, keep: Bool) -> List<&2, Request.Header>:
  match keep:
    case True{}: h <> rest
    case False{}: rest

def metadata(hs: List<&2, Request.Header>) -> List<&2, Request.Header>:
  match hs:
    case Nil{}: []
    case Request.Header{+n, v} <> t:
      selected(Request.Header{n, v}, metadata(t), allowed(n))

def response(res: Response.Res) -> Response.Res:
  Response.Res{code, hs, body, rep} = res
  Response.Res{304, metadata(hs), [], None{}}

# Arithmetic reference is a structural relation on Peano naturals.
def within(length: Nat, limit: Nat) -> Bool:
  match length limit:
    case 0n _: True{}
    case 1n+l 0n: False{}
    case 1n+l 1n+n: within(l, n)

# Middleware decision specification. Hashing, header replacement and the
# separately specified 304 constructor are shared primitives; eligibility and
# If-None-Match evaluation do not call middleware.
def retrieval(m: Request.Method) -> Bool:
  match m:
    case Request.Get{}: True{}
    case Request.Head{}: True{}
    case _: False{}

def etag_result(res: Response.Res, hit: Bool) -> Response.Res:
  match hit:
    case True{}: Conditional.not_modified(res)
    case False{}: res

def etag_eligible(field: Maybe<&2, String>, res: Response.Res, eligible: Bool) -> Response.Res:
  match res eligible:
    case res False{}: res
    case Response.Res{status, hs, +body, rep} True{}:
      +tag = Conditional.strong(body)
      etag_result(Common.header(Response.Res{status, hs, body, rep}, "etag", tag), matches(field, tag))

def etag(m: Request.Method, field: Maybe<&2, String>, +res: Response.Res) -> Response.Res:
  Response.Res{status, hs, body, rep} = res
  etag_eligible(field, res, retrieval(m) && U32.is_eq(status, 200) && List.is_empty(&2, List<&2, U32>, Request.lookup(hs, "x-bendo-stream-internal")))
