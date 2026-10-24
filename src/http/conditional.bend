# Pure buffered validators, shared by middleware and static-file consumers.
import Base
import ./conditional-lex.bend as Lex
import ./bytes.bend as Bytes
import ./request.bend as Request
import ./response.bend as Response
import ../crypto/sha256.bend as Sha256
import ../data/base64.bend as Base64

def strong(body: List<&2, U32>) -> String:
  "\"" ++ Base64.encode(Sha256.hash(body), True{}, False{}) ++ "\""

# entity-tag uses etagc, not quoted-string: backslash is literal, comma is data.

def opaque_end(acc: String, valid: Bool) -> Maybe<&2, String>:
  match valid:
    case True{}: Some{String.reverse(acc)}
    case False{}: None{}

def opaque_checked(parsed: Maybe<&2, String>, valid: Bool) -> Maybe<&2, String>:
  match valid:
    case True{}: parsed
    case False{}: None{}

def opaque_step(parsed: Maybe<&2, String>, acc: String, final_quote: Bool, valid: Bool) -> Maybe<&2, String>:
  match final_quote:
    case True{}: Some{String.reverse(acc)}
    case False{}: opaque_checked(parsed, valid)

def opaque(s: String, +acc: String) -> Maybe<&2, String>:
  match s:
    case SNil{}: None{}
    case SCon{Chr{+c}, +t}:
      opaque_step(opaque(t, SCon{Chr{c}, acc}), acc, U32.is_eq(c, 34) && String.is_empty(t), Lex.etagc(c))

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

# Split only outside entity-tag quotes. RFC list empty elements are ignored.
def toggled(q: Bool, quote: Bool) -> Bool:
  match quote:
    case True{}: Bool.not(q)
    case False{}: q

def accumulated(c: Char, acc: String, cut: Bool) -> String:
  match cut:
    case True{}: ""
    case False{}: SCon{c, acc}

def prepended(rest: List<&2, String>, acc: String, cut: Bool) -> List<&2, String>:
  match cut:
    case True{}: String.reverse(acc) <> rest
    case False{}: rest

def segments(s: String, +quoted: Bool, +acc: String) -> List<&2, String>:
  match s:
    case SNil{}: [String.reverse(acc)]
    case SCon{Chr{+c}, t}:
      +cut = U32.is_eq(c, 44) && Bool.not(quoted)
      prepended(segments(t, toggled(quoted, U32.is_eq(c, 34)), accumulated(Chr{c}, acc, cut)), acc, cut)

def trim(s: String) -> String: Bytes.ascii(Bytes.trim(Bytes.encode(s)))

def member_checked(parsed: Maybe<&2, String>, tag: Maybe<&2, String>, rest: Bool, empty: Bool) -> Sigma<&2, &2, Bool, _ => Bool>:
  match empty:
    case True{}: (True{}, rest)
    case False{}:
      +value = parsed
      (Maybe.is_some(&2, String, value), equal(value, tag) || rest)

def member(+s: String, tag: Maybe<&2, String>, rest: Bool) -> Sigma<&2, &2, Bool, _ => Bool>:
  member_checked(entity(s), tag, rest, String.is_empty(s))

def combine_valid(result: Sigma<&2, &2, Bool, _ => Bool>, valid: Bool) -> Sigma<&2, &2, Bool, _ => Bool>:
  (ok, found) = result
  (valid && ok, found)

def combine_member(s: String, tag: Maybe<&2, String>, result: Sigma<&2, &2, Bool, _ => Bool>) -> Sigma<&2, &2, Bool, _ => Bool>:
  (valid, hit) = result
  combine_valid(member(s, tag, hit), valid)

def members(xs: List<&2, String>, +tag: Maybe<&2, String>) -> Sigma<&2, &2, Bool, _ => Bool>:
  match xs:
    case Nil{}: (True{}, False{})
    case h <> t:
      combine_member(trim(h), tag, members(t, tag))

def decision(result: Sigma<&2, &2, Bool, _ => Bool>) -> Bool:
  (valid, hit) = result
  valid && hit

def evaluate(+field: String, tag: Maybe<&2, String>, star: Bool) -> Bool:
  match star:
    case True{}: Maybe.is_some(&2, String, tag)
    case False{}:
      decision(members(segments(field, False{}, ""), tag))

# False for absent or malformed fields/tags; weak comparison for GET and HEAD.
def matches(field: Maybe<&2, String>, tag: String) -> Bool:
  match field:
    case None{}: False{}
    case Some{+s}: evaluate(s, entity(tag), String.eq(trim(s), "*"))

def retained(+name: String) -> Bool:
  String.eq(name, "etag") || String.eq(name, "cache-control") || String.eq(name, "vary") || String.eq(name, "date") || String.eq(name, "content-location") || String.eq(name, "expires")

def keep(h: Request.Header, tail: List<&2, Request.Header>, yes: Bool) -> List<&2, Request.Header>:
  match yes:
    case True{}: h <> tail
    case False{}: tail

def headers(hs: List<&2, Request.Header>) -> List<&2, Request.Header>:
  match hs:
    case Nil{}: []
    case Request.Header{+name, value} <> tail:
      keep(Request.Header{name, value}, headers(tail), retained(name))

def not_modified(res: Response.Res) -> Response.Res:
  Response.Res{code, hs, body, rep} = res
  Response.Res{304, headers(hs), [], None{}}
