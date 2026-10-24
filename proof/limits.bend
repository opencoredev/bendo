import Base
import ../src/mw/etag.bend as ETag
import ../src/mw/common.bend as Common
import ../src/http/conditional-lex.bend as Lex
import ../src/http/conditional.bend as P
import ../src/http/request.bend as Request
import ../src/http/response.bend as Response
import ../src/mw/body_limit.bend as Limit
import ./limits-spec.bend as Spec
import ./misc-tail.bend as MiscTail
import ./fold-tail.bend as FoldTail

# Byte length is accepted exactly when it is at most the limit.
def within(+length: Nat, +limit: Nat) -> {Limit.accepts(length, limit) == Spec.within(length, limit) : Bool}:
  match length limit:
    case 0n 0n: {==}
    case 0n 1n+n: {==}
    case 1n+l 0n: {==}
    case 1n+l 1n+n: within(l, n)

def allowed(+n: String) -> {P.retained(n) == Spec.allowed(n) : Bool}: {==}

def selected(+h: Request.Header, +t: List<&2, Request.Header>, +yes: Bool) -> {P.keep(h, t, yes) == Spec.selected(h, t, yes) : List<&2, Request.Header>}:
  match yes:
    case True{}: {==}
    case False{}: {==}

def metadata(+hs: List<&2, Request.Header>) -> {P.headers(hs) == Spec.metadata(hs) : List<&2, Request.Header>}:
  match hs:
    case Nil{}: {==}
    case Request.Header{+n, +v} <> +t:
      %metadata(t) : {P.keep(Request.Header{n, v}, P.headers(t), P.retained(n)) == Spec.selected(Request.Header{n, v}, _, Spec.allowed(n)) : List<&2, Request.Header>}
      %allowed(n) : {P.keep(Request.Header{n, v}, P.headers(t), P.retained(n)) == Spec.selected(Request.Header{n, v}, P.headers(t), _) : List<&2, Request.Header>}
      selected(Request.Header{n, v}, P.headers(t), P.retained(n))

def response(+res: Response.Res) -> {P.not_modified(res) == Spec.response(res) : Response.Res}:
  Response.Res{code, hs, body, rep} = res
  %metadata(hs) : {Response.Res{304, P.headers(hs), [], None{}} == Response.Res{304, _, [], None{}} : Response.Res}
  {==}

# The parser lemmas cover arbitrary fields and arbitrary validator strings.
def prefix_empty(+acc: String) -> {Spec.prefix(acc, Some{""}) == Some{String.reverse(acc)} : Maybe<&2, String>}: {==}

def opaque_step(+acc: String, +c: Char, +parsed: Maybe<&2, String>, +end: Bool, +valid: Bool) -> {P.opaque_step(Spec.prefix(SCon{c, acc}, parsed), acc, end, valid) == Spec.prefix(acc, Spec.grammar_end(c, parsed, end, valid)) : Maybe<&2, String>}:
  match parsed end valid:
    case None{} True{} _: {==}
    case Some{s} True{} _: {==}
    case None{} False{} True{}: {==}
    case None{} False{} False{}: {==}
    case Some{s} False{} True{}: {==}
    case Some{s} False{} False{}: {==}

def opaque_inner(+s: String, +acc: String) -> {P.opaque_spec(s, acc) == Spec.opaque(s, acc) : Maybe<&2, String>}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{+c}, +t}:
      %Equal.sym(Maybe<&2, String>, P.opaque_spec(t, SCon{Chr{c}, acc}), Spec.opaque(t, SCon{Chr{c}, acc}), opaque_inner(t, SCon{Chr{c}, acc})) : {P.opaque_step(_, acc, U32.is_eq(c, 34) && String.is_empty(t), Lex.etagc(c)) == Spec.opaque(SCon{Chr{c}, t}, acc) : Maybe<&2, String>}
      opaque_step(acc, Chr{c}, Spec.tag_tail(t), U32.is_eq(c, 34) && String.is_empty(t), Lex.etagc(c))

def opaque(+s: String, +acc: String) -> {P.opaque(s, acc) == Spec.opaque(s, acc) : Maybe<&2, String>}:
  Equal.trans(Maybe<&2, String>, P.opaque(s, acc), P.opaque_spec(s, acc), Spec.opaque(s, acc), MiscTail.opaque_equiv(s, acc), opaque_inner(s, acc))

def quoted(+p: Maybe<&2, String>, +q: Bool) -> {P.quoted(p, q) == Spec.quoted(p, q) : Maybe<&2, String>}:
  match q:
    case True{}: {==}
    case False{}: {==}

def strong(+s: String) -> {P.entity_strong(s) == Spec.entity_strong(s) : Maybe<&2, String>}:
  %opaque(String.drop(s, 1n), "") : {P.quoted(P.opaque(String.drop(s, 1n), ""), String.starts_with(s, "\"")) == Spec.quoted(_, String.starts_with(s, "\"")) : Maybe<&2, String>}
  quoted(P.opaque(String.drop(s, 1n), ""), String.starts_with(s, "\""))

def unweak(+s: String, +b: Bool) -> {P.unweak(s, b) == Spec.unweak(s, b) : String}:
  match b:
    case True{}: {==}
    case False{}: {==}

def entity(+s: String) -> {P.entity(s) == Spec.entity(s) : Maybe<&2, String>}:
  %unweak(s, String.starts_with(s, "W/")) : {P.entity_strong(P.unweak(s, String.starts_with(s, "W/"))) == Spec.entity_strong(_) : Maybe<&2, String>}
  strong(P.unweak(s, String.starts_with(s, "W/")))

def toggled(+q: Bool, +quote: Bool) -> {P.toggled(q, quote) == Spec.toggled(q, quote) : Bool}:
  match quote:
    case True{}: {==}
    case False{}: {==}

def split_step(+c: Char, +acc: String, +parts: Spec.Elements, +cut: Bool) -> {P.prepended(Spec.prefix_parts(P.accumulated(c, acc, cut), parts), acc, cut) == Spec.prefix_parts(acc, Spec.list_char(c, parts, cut)) : List<&2, String>}:
  match parts cut:
    case Spec.Elements{h, t} True{}: {==}
    case Spec.Elements{h, t} False{}: {==}

def segments_inner(+s: String, +q: Bool, +acc: String) -> {P.segments_spec(s, q, acc) == Spec.segments(s, q, acc) : List<&2, String>}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{+c}, +t}:
      +cut = U32.is_eq(c, 44) && Bool.not(q)
      %Equal.sym(List<&2, String>, P.segments_spec(t, P.toggled(q, U32.is_eq(c, 34)), P.accumulated(Chr{c}, acc, cut)), Spec.segments(t, P.toggled(q, U32.is_eq(c, 34)), P.accumulated(Chr{c}, acc, cut)), segments_inner(t, P.toggled(q, U32.is_eq(c, 34)), P.accumulated(Chr{c}, acc, cut))) : {P.prepended(_, acc, cut) == Spec.segments(SCon{Chr{c}, t}, q, acc) : List<&2, String>}
      %toggled(q, U32.is_eq(c, 34)) : {P.prepended(Spec.segments(t, P.toggled(q, U32.is_eq(c, 34)), P.accumulated(Chr{c}, acc, cut)), acc, cut) == Spec.prefix_parts(acc, Spec.list_char(Chr{c}, Spec.parts(t, _), cut)) : List<&2, String>}
      split_step(Chr{c}, acc, Spec.parts(t, P.toggled(q, U32.is_eq(c, 34))), cut)

def segments(+s: String, +q: Bool, +acc: String) -> {P.segments(s, q, acc) == Spec.segments(s, q, acc) : List<&2, String>}:
  Equal.trans(List<&2, String>, P.segments(s, q, acc), P.segments_spec(s, q, acc), Spec.segments(s, q, acc), MiscTail.segments_equiv(s, q, acc), segments_inner(s, q, acc))

def equal(+a: Maybe<&2, String>, +b: Maybe<&2, String>) -> {P.equal(a, b) == Spec.equal(a, b) : Bool}:
  match a b:
    case None{} None{}: {==}
    case None{} Some{y}: {==}
    case Some{x} None{}: {==}
    case Some{x} Some{y}: {==}

def and_commutes(+a: Bool, +b: Bool) -> {a && b == b && a : Bool}:
  match a b:
    case True{} True{}: {==}
    case True{} False{}: {==}
    case False{} True{}: {==}
    case False{} False{}: {==}

def some_or_false(+p: Maybe<&2, String>) -> {Maybe.is_some(&2, String, p) == False{} || Maybe.is_some(&2, String, p) : Bool}:
  match p:
    case None{}: {==}
    case Some{x}: {==}

def member(+s: String, +tag: Maybe<&2, String>, +rest: Bool) -> {P.member(s, tag, rest) == (Spec.valid_token(s), Spec.equal(Spec.entity(s), tag) || rest) : Sigma<&2, &2, Bool, _ => Bool>}:
  match s:
    case SNil{}: {==}
    case SCon{+c, +t}:
      %entity(SCon{c, t}) : {(Maybe.is_some(&2, String, P.entity(SCon{c, t})), P.equal(P.entity(SCon{c, t}), tag) || rest) == (False{} || Maybe.is_some(&2, String, _), Spec.equal(Spec.entity(SCon{c, t}), tag) || rest) : Sigma<&2, &2, Bool, _ => Bool>}
      %entity(SCon{c, t}) : {(Maybe.is_some(&2, String, P.entity(SCon{c, t})), P.equal(P.entity(SCon{c, t}), tag) || rest) == (False{} || Maybe.is_some(&2, String, P.entity(SCon{c, t})), Spec.equal(_, tag) || rest) : Sigma<&2, &2, Bool, _ => Bool>}
      %equal(P.entity(SCon{c, t}), tag) : {(Maybe.is_some(&2, String, P.entity(SCon{c, t})), P.equal(P.entity(SCon{c, t}), tag) || rest) == (False{} || Maybe.is_some(&2, String, P.entity(SCon{c, t})), _ || rest) : Sigma<&2, &2, Bool, _ => Bool>}
      %some_or_false(P.entity(SCon{c, t})) : {(Maybe.is_some(&2, String, P.entity(SCon{c, t})), P.equal(P.entity(SCon{c, t}), tag) || rest) == (_, P.equal(P.entity(SCon{c, t}), tag) || rest) : Sigma<&2, &2, Bool, _ => Bool>}
      {==}

def combined(+s: String, +tag: Maybe<&2, String>, +valid: Bool, +hit: Bool) -> {P.combine_member(s, tag, (valid, hit)) == (Spec.valid_token(s) && valid, Spec.equal(Spec.entity(s), tag) || hit) : Sigma<&2, &2, Bool, _ => Bool>}:
  %Equal.sym(Sigma<&2, &2, Bool, _ => Bool>, P.member(s, tag, hit), (Spec.valid_token(s), Spec.equal(Spec.entity(s), tag) || hit), member(s, tag, hit)) : {P.combine_valid(_, valid) == (Spec.valid_token(s) && valid, Spec.equal(Spec.entity(s), tag) || hit) : Sigma<&2, &2, Bool, _ => Bool>}
  %and_commutes(valid, Spec.valid_token(s)) : {(valid && Spec.valid_token(s), Spec.equal(Spec.entity(s), tag) || hit) == (_, Spec.equal(Spec.entity(s), tag) || hit) : Sigma<&2, &2, Bool, _ => Bool>}
  {==}

def members_inner(+xs: List<&2, String>, +tag: Maybe<&2, String>) -> {P.members_spec(xs, tag) == Spec.members(xs, tag) : Sigma<&2, &2, Bool, _ => Bool>}:
  match xs:
    case Nil{}: {==}
    case +h <> +t:
      %Equal.sym(Sigma<&2, &2, Bool, _ => Bool>, P.members_spec(t, tag), Spec.members(t, tag), members_inner(t, tag)) : {P.combine_member(P.trim(h), tag, _) == Spec.members(h <> t, tag) : Sigma<&2, &2, Bool, _ => Bool>}
      combined(P.trim(h), tag, Spec.all_valid(t), Spec.any_match(t, tag))

def members(+xs: List<&2, String>, +tag: Maybe<&2, String>) -> {P.members(xs, tag) == Spec.members(xs, tag) : Sigma<&2, &2, Bool, _ => Bool>}:
  Equal.trans(Sigma<&2, &2, Bool, _ => Bool>, P.members(xs, tag), P.members_spec(xs, tag), Spec.members(xs, tag), FoldTail.cond_members_equiv(xs, tag), members_inner(xs, tag))

def decision(+pair: Sigma<&2, &2, Bool, _ => Bool>) -> {P.decision(pair) == Spec.decision(pair) : Bool}:
  (valid, hit) = pair
  {==}

def evaluate(+s: String, +tag: Maybe<&2, String>, +star: Bool) -> {P.evaluate(s, tag, star) == Spec.evaluate(s, tag, star) : Bool}:
  match star:
    case True{}: {==}
    case False{}:
      %segments(s, False{}, "") : {P.decision(P.members(P.segments(s, False{}, ""), tag)) == Spec.decision(Spec.members(_, tag)) : Bool}
      %members(P.segments(s, False{}, ""), tag) : {P.decision(P.members(P.segments(s, False{}, ""), tag)) == Spec.decision(_) : Bool}
      decision(P.members(P.segments(s, False{}, ""), tag))

def matches(+field: Maybe<&2, String>, +tag: String) -> {P.matches(field, tag) == Spec.matches(field, tag) : Bool}:
  match field:
    case None{}: {==}
    case Some{+s}:
      %entity(tag) : {P.evaluate(s, P.entity(tag), String.eq(P.trim(s), "*")) == Spec.evaluate(s, _, String.eq(Spec.trim(s), "*")) : Bool}
      evaluate(s, P.entity(tag), String.eq(P.trim(s), "*"))

def etag_result(+res: Response.Res, +hit: Bool) -> {ETag.conditional(res, hit) == Spec.etag_result(res, hit) : Response.Res}:
  match hit:
    case True{}: {==}
    case False{}: {==}

def etag_apply(+field: Maybe<&2, String>, +res: Response.Res, +eligible: Bool) -> {ETag.apply(field, res, eligible) == Spec.etag_eligible(field, res, eligible) : Response.Res}:
  match res eligible:
    case res False{}: {==}
    case Response.Res{status, hs, +body, rep} True{}:
      +tag = P.strong(body)
      %matches(field, tag) : {ETag.conditional(Common.header(Response.Res{status, hs, body, rep}, "etag", tag), P.matches(field, tag)) == Spec.etag_result(Common.header(Response.Res{status, hs, body, rep}, "etag", tag), _) : Response.Res}
      etag_result(Common.header(Response.Res{status, hs, body, rep}, "etag", tag), P.matches(field, tag))

def etag_method(+m: Request.Method) -> {ETag.method(m) == Spec.retrieval(m) : Bool}:
  match m:
    case Request.Get{}: {==}
    case Request.Head{}: {==}
    case Request.Post{}: {==}
    case Request.Put{}: {==}
    case Request.Delete{}: {==}
    case Request.Patch{}: {==}
    case Request.Options{}: {==}
    case Request.Connect{}: {==}
    case Request.Trace{}: {==}
    case Request.Extension{x}: {==}

def etag(+m: Request.Method, +field: Maybe<&2, String>, +res: Response.Res) -> {ETag.decide(m, field, res) == Spec.etag(m, field, res) : Response.Res}:
  Response.Res{+status, +hs, body, rep} = res
  %etag_method(m) : {ETag.apply(field, res, ETag.method(m) && U32.is_eq(status, 200) && List.is_empty(&2, List<&2, U32>, Request.lookup(hs, "x-bendo-stream-internal"))) == Spec.etag_eligible(field, res, _ && U32.is_eq(status, 200) && List.is_empty(&2, List<&2, U32>, Request.lookup(hs, "x-bendo-stream-internal"))) : Response.Res}
  etag_apply(field, res, ETag.method(m) && U32.is_eq(status, 200) && List.is_empty(&2, List<&2, U32>, Request.lookup(hs, "x-bendo-stream-internal")))
