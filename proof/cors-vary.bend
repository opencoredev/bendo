# BND-40: an origin-specific CORS policy always leaves Vary covering Origin,
# keeping every value downstream sent, "*" included.
import Base
import ../LAWS.bend as Laws
import ./equality.bend as Equality
import ../src/http/request.bend as Request
import ../src/http/response.bend as Response
import ../src/http/bytes.bend as Bytes
import ../src/mw/cors_policy.bend as P
import ../src/mw/cors_request.bend as CR
import ../src/mw/response_policy.bend as Policy
import ./cors-spec.bend as CorsSpec
import ./response-policy-spec.bend as RS
import ./cors-response-spec.bend as Spec
import ./cors-response.bend as CorsResponse

def truth(b: Bool) -> Type:
  match b:
    case True{}: Unit
    case False{}: Empty

def true_not_false(e: {True{} == False{} : Bool}) -> Empty:
  %e : truth(_)
  Unit{}

def absurd(-A: Type, e: Empty) -> A:
  match e:

# ---- Vary values of field lists ----

def values_nil(+xs: List<&2, List<&2, U32>>) -> {List.append(&2, List<&2, U32>, xs, []) == xs : List<&2, List<&2, U32>>}:
  match xs:
    case Nil{}: {==}
    case +x <> +t: Equal.cong(List<&2, List<&2, U32>>, List<&2, List<&2, U32>>, l => x <> l, List.append(&2, List<&2, U32>, t, []), t, values_nil(t))

def append_pick(+v: List<&2, U32>, +r: List<&2, List<&2, U32>>, +b: List<&2, List<&2, U32>>, +e: Bool) -> {List.append(&2, List<&2, U32>, RS.vary_pick(v, r, e), b) == RS.vary_pick(v, List.append(&2, List<&2, U32>, r, b), e) : List<&2, List<&2, U32>>}:
  match e:
    case True{}: {==}
    case False{}: {==}

def values_append(+a: List<&2, Request.Header>, +b: List<&2, Request.Header>) -> {RS.vary_values(List.append(&2, Request.Header, a, b)) == List.append(&2, List<&2, U32>, RS.vary_values(a), RS.vary_values(b)) : List<&2, List<&2, U32>>}:
  match a:
    case Nil{}: {==}
    case Request.Header{+k, +v} <> +t:
      +e = String.eq(Bytes.fold(k), "vary")
      %Equal.sym(List<&2, List<&2, U32>>, List.append(&2, List<&2, U32>, RS.vary_pick(v, RS.vary_values(t), e), RS.vary_values(b)), RS.vary_pick(v, List.append(&2, List<&2, U32>, RS.vary_values(t), RS.vary_values(b)), e), append_pick(v, RS.vary_values(t), RS.vary_values(b), e)) : {RS.vary_values(List.append(&2, Request.Header, Request.Header{k, v} <> t, b)) == _ : List<&2, List<&2, U32>>}
      Equal.cong(List<&2, List<&2, U32>>, List<&2, List<&2, U32>>, l => RS.vary_pick(v, l, e), RS.vary_values(List.append(&2, Request.Header, t, b)), List.append(&2, List<&2, U32>, RS.vary_values(t), RS.vary_values(b)), values_append(t, b))

def drop_pick(+k: String, +v: List<&2, U32>, +rest: List<&2, Request.Header>, +e: Bool, h: {String.eq(Bytes.fold(k), "vary") == e : Bool}, ih: {RS.vary_values(RS.unrelated(rest, ["vary"])) == [] : List<&2, List<&2, U32>>}) -> {RS.vary_values(RS.kept(Request.Header{k, v}, RS.unrelated(rest, ["vary"]), e || False{})) == [] : List<&2, List<&2, U32>>}:
  match e:
    case True{}: ih
    case False{}:
      %Equal.sym(Bool, String.eq(Bytes.fold(k), "vary"), False{}, h) : {RS.vary_pick(v, RS.vary_values(RS.unrelated(rest, ["vary"])), _) == [] : List<&2, List<&2, U32>>}
      ih

# Removing every Vary field leaves no Vary value.
def dropped(+hs: List<&2, Request.Header>) -> {RS.vary_values(RS.unrelated(hs, ["vary"])) == [] : List<&2, List<&2, U32>>}:
  match hs:
    case Nil{}: {==}
    case Request.Header{+k, +v} <> +t: drop_pick(k, v, t, String.eq(Bytes.fold(k), "vary"), {==}, dropped(t))

def keep_pick(+k: String, +v: List<&2, U32>, +rest: List<&2, Request.Header>, +ns: List<&2, String>, +e1: Bool, +e2: Bool, h1: {RS.listed(Bytes.fold(k), ns) == e1 : Bool}, +h2: {String.eq(Bytes.fold(k), "vary") == e2 : Bool}, +hn: {RS.listed("vary", ns) == False{} : Bool}, ih: {RS.vary_values(RS.unrelated(rest, ns)) == RS.vary_values(rest) : List<&2, List<&2, U32>>}) -> {RS.vary_values(RS.kept(Request.Header{k, v}, RS.unrelated(rest, ns), e1)) == RS.vary_pick(v, RS.vary_values(rest), e2) : List<&2, List<&2, U32>>}:
  match e1:
    case True{}:
      match e2:
        case True{}:
          same = Equal.cong(String, Bool, x => RS.listed(x, ns), Bytes.fold(k), "vary", Laws.string_eq_sound(Bytes.fold(k), "vary", h2))
          clash = Equal.trans(Bool, True{}, RS.listed(Bytes.fold(k), ns), False{}, Equal.sym(Bool, RS.listed(Bytes.fold(k), ns), True{}, h1), Equal.trans(Bool, RS.listed(Bytes.fold(k), ns), RS.listed("vary", ns), False{}, same, hn))
          absurd({RS.vary_values(RS.unrelated(rest, ns)) == RS.vary_pick(v, RS.vary_values(rest), True{}) : List<&2, List<&2, U32>>}, true_not_false(clash))
        case False{}: ih
    case False{}:
      %h2 : {RS.vary_pick(v, RS.vary_values(RS.unrelated(rest, ns)), String.eq(Bytes.fold(k), "vary")) == RS.vary_pick(v, RS.vary_values(rest), _) : List<&2, List<&2, U32>>}
      Equal.cong(List<&2, List<&2, U32>>, List<&2, List<&2, U32>>, l => RS.vary_pick(v, l, String.eq(Bytes.fold(k), "vary")), RS.vary_values(RS.unrelated(rest, ns)), RS.vary_values(rest), ih)

# Removing names other than Vary keeps every Vary value.
def kept(+hs: List<&2, Request.Header>, +ns: List<&2, String>, +hn: {RS.listed("vary", ns) == False{} : Bool}) -> {RS.vary_values(RS.unrelated(hs, ns)) == RS.vary_values(hs) : List<&2, List<&2, U32>>}:
  match hs:
    case Nil{}: {==}
    case Request.Header{+k, +v} <> +t: keep_pick(k, v, t, ns, RS.listed(Bytes.fold(k), ns), String.eq(Bytes.fold(k), "vary"), {==}, {==}, hn, kept(t, ns, hn))

# ---- CORS fields never name Vary ----

def as_append(+a: List<&2, P.Field>, +b: List<&2, P.Field>) -> {Spec.as_headers(List.append(&2, P.Field, a, b)) == List.append(&2, Request.Header, Spec.as_headers(a), Spec.as_headers(b)) : List<&2, Request.Header>}:
  match a:
    case Nil{}: {==}
    case P.Field{+n, +v} <> +t: Equal.cong(List<&2, Request.Header>, List<&2, Request.Header>, l => Request.Header{n, Response.utf8(v)} <> l, Spec.as_headers(List.append(&2, P.Field, t, b)), List.append(&2, Request.Header, Spec.as_headers(t), Spec.as_headers(b)), as_append(t, b))

def none(+a: List<&2, P.Field>, +b: List<&2, P.Field>, ea: {RS.vary_values(Spec.as_headers(a)) == [] : List<&2, List<&2, U32>>}, eb: {RS.vary_values(Spec.as_headers(b)) == [] : List<&2, List<&2, U32>>}) -> {RS.vary_values(Spec.as_headers(List.append(&2, P.Field, a, b))) == [] : List<&2, List<&2, U32>>}:
  %Equal.sym(List<&2, Request.Header>, Spec.as_headers(List.append(&2, P.Field, a, b)), List.append(&2, Request.Header, Spec.as_headers(a), Spec.as_headers(b)), as_append(a, b)) : {RS.vary_values(_) == [] : List<&2, List<&2, U32>>}
  %Equal.sym(List<&2, List<&2, U32>>, RS.vary_values(List.append(&2, Request.Header, Spec.as_headers(a), Spec.as_headers(b))), List.append(&2, List<&2, U32>, RS.vary_values(Spec.as_headers(a)), RS.vary_values(Spec.as_headers(b))), values_append(Spec.as_headers(a), Spec.as_headers(b))) : {_ == [] : List<&2, List<&2, U32>>}
  %Equal.sym(List<&2, List<&2, U32>>, RS.vary_values(Spec.as_headers(a)), [], ea) : {List.append(&2, List<&2, U32>, _, RS.vary_values(Spec.as_headers(b))) == [] : List<&2, List<&2, U32>>}
  eb

def flag(+c: Bool) -> {RS.vary_values(Spec.as_headers(CorsSpec.flag(c))) == [] : List<&2, List<&2, U32>>}:
  match c:
    case True{}: {==}
    case False{}: {==}

def methods(+xs: List<&2, String>) -> {RS.vary_values(Spec.as_headers(CorsSpec.csv("access-control-allow-methods", xs))) == [] : List<&2, List<&2, U32>>}:
  match xs:
    case Nil{}: {==}
    case x <> t: {==}

def expose(+xs: List<&2, String>) -> {RS.vary_values(Spec.as_headers(CorsSpec.csv("access-control-expose-headers", xs))) == [] : List<&2, List<&2, U32>>}:
  match xs:
    case Nil{}: {==}
    case x <> t: {==}

def allowed(+h: List<&2, String>, +r: Maybe<&2, String>) -> {RS.vary_values(Spec.as_headers(CorsSpec.headers_answer(h, r))) == [] : List<&2, List<&2, U32>>}:
  match h:
    case Nil{}:
      match r:
        case None{}: {==}
        case Some{x}: {==}
    case x <> t: {==}

def age(+m: Maybe<&2, Nat>) -> {RS.vary_values(Spec.as_headers(CorsSpec.age(m))) == [] : List<&2, List<&2, U32>>}:
  match m:
    case None{}: {==}
    case Some{n}: {==}

def preflight_fields(+config: P.Config, +g: Maybe<&2, P.Grant>, +r: Maybe<&2, String>) -> {RS.vary_values(Spec.as_headers(CorsSpec.preflight_fields(config, g, r))) == [] : List<&2, List<&2, U32>>}:
  match config:
    case P.Config{+o, +m, +h, +e, +a}:
      match g:
        case None{}: {==}
        case Some{P.Grant{+x, +c}}:
          tail = none(CorsSpec.headers_answer(h, r), CorsSpec.age(a), allowed(h, r), age(a))
          none(CorsSpec.flag(c), List.append(&2, P.Field, CorsSpec.csv("access-control-allow-methods", m), List.append(&2, P.Field, CorsSpec.headers_answer(h, r), CorsSpec.age(a))), flag(c), none(CorsSpec.csv("access-control-allow-methods", m), List.append(&2, P.Field, CorsSpec.headers_answer(h, r), CorsSpec.age(a)), methods(m), tail))

def actual_fields(+config: P.Config, +g: Maybe<&2, P.Grant>) -> {RS.vary_values(Spec.as_headers(CorsSpec.actual_fields(config, g))) == [] : List<&2, List<&2, U32>>}:
  match config:
    case P.Config{+o, +m, +h, +e, +a}:
      match g:
        case None{}: {==}
        case Some{P.Grant{+x, +c}}: none(CorsSpec.flag(c), CorsSpec.csv("access-control-expose-headers", e), flag(c), expose(e))

def added(+config: P.Config, +g: Maybe<&2, P.Grant>, +r: Maybe<&2, String>, +pf: Bool) -> {RS.vary_values(Spec.added(config, g, r, pf)) == [] : List<&2, List<&2, U32>>}:
  match pf:
    case True{}: preflight_fields(config, g, Spec.reflected(r))
    case False{}: actual_fields(config, g)

# ---- The merged Vary value ----

def single(+star: Bool, +values: List<&2, List<&2, U32>>, +n: String, +t: List<&2, String>) -> {RS.vary_values(RS.vary_field(star, values, RS.fresh(n <> t, RS.members(values)))) == RS.vary_single(star, values, RS.fresh(n <> t, RS.members(values))) : List<&2, List<&2, U32>>}:
  match star:
    case True{}: {==}
    case False{}:
      match values:
        case Nil{}: {==}
        case v <> r: {==}

# Adding at least one name leaves exactly the Vary values vary_result names.
def result(+l: List<&2, Request.Header>, +n: String, +t: List<&2, String>) -> {RS.vary_values(RS.vary_add(l, n <> t)) == RS.vary_result(RS.vary_values(l), n <> t) : List<&2, List<&2, U32>>}:
  +values = RS.vary_values(l)
  +ms = RS.members(values)
  +field = RS.vary_field(RS.member("*", ms), values, RS.fresh(n <> t, ms))
  %Equal.sym(List<&2, List<&2, U32>>, RS.vary_values(List.append(&2, Request.Header, RS.unrelated(l, ["vary"]), field)), List.append(&2, List<&2, U32>, RS.vary_values(RS.unrelated(l, ["vary"])), RS.vary_values(field)), values_append(RS.unrelated(l, ["vary"]), field)) : {_ == RS.vary_result(values, n <> t) : List<&2, List<&2, U32>>}
  %Equal.sym(List<&2, List<&2, U32>>, RS.vary_values(RS.unrelated(l, ["vary"])), [], dropped(l)) : {List.append(&2, List<&2, U32>, _, RS.vary_values(field)) == RS.vary_result(values, n <> t) : List<&2, List<&2, U32>>}
  single(RS.member("*", ms), values, n, t)

# The Vary values a finalized listed-origin CORS response carries.
def vary_origin(+es: List<&2, P.Entry>, +m: List<&2, String>, +h: List<&2, String>, +e: List<&2, String>, +a: Maybe<&2, Nat>, +req: Request.Req, +res: Response.Res) -> {RS.vary_values(RS.headers(Policy.apply(CR.policy(P.Config{P.Listed{es}, m, h, e, a}, req), res))) == RS.vary_result(RS.vary_values(RS.headers(res)), "Origin" <> Spec.request_header_names(Spec.preflight(req), h)) : List<&2, List<&2, U32>>}:
  match res:
    case Response.Res{+s, +hs, +b, +rep}:
      +config : P.Config = P.Config{P.Listed{es}, m, h, e, a}
      +pf = Spec.preflight(req)
      +x = Spec.request_header_names(pf, h)
      +l = List.append(&2, Request.Header, RS.unrelated(hs, Spec.cors_names()), Spec.added(config, Spec.grant(config, req), Spec.requested(req), pf))
      %Equal.sym(Response.Res, Policy.apply(CR.policy(config, req), Response.Res{s, hs, b, rep}), Spec.response(config, req, Response.Res{s, hs, b, rep}), CorsResponse.response(config, req, Response.Res{s, hs, b, rep})) : {RS.vary_values(RS.headers(_)) == RS.vary_result(RS.vary_values(hs), "Origin" <> x) : List<&2, List<&2, U32>>}
      %Equal.sym(List<&2, List<&2, U32>>, RS.vary_values(RS.vary_add(l, "Origin" <> x)), RS.vary_result(RS.vary_values(l), "Origin" <> x), result(l, "Origin", x)) : {_ == RS.vary_result(RS.vary_values(hs), "Origin" <> x) : List<&2, List<&2, U32>>}
      +u = RS.vary_values(RS.unrelated(hs, Spec.cors_names()))
      +more = RS.vary_values(Spec.added(config, Spec.grant(config, req), Spec.requested(req), pf))
      parts = values_append(RS.unrelated(hs, Spec.cors_names()), Spec.added(config, Spec.grant(config, req), Spec.requested(req), pf))
      nothing = Equal.cong(List<&2, List<&2, U32>>, List<&2, List<&2, U32>>, w => List.append(&2, List<&2, U32>, u, w), more, [], added(config, Spec.grant(config, req), Spec.requested(req), pf))
      same = Equal.trans(List<&2, List<&2, U32>>, RS.vary_values(l), List.append(&2, List<&2, U32>, u, more), u, parts, Equal.trans(List<&2, List<&2, U32>>, List.append(&2, List<&2, U32>, u, more), List.append(&2, List<&2, U32>, u, []), u, nothing, values_nil(u)))
      %kept(hs, Spec.cors_names(), {==}) : {RS.vary_result(RS.vary_values(l), "Origin" <> x) == RS.vary_result(_, "Origin" <> x) : List<&2, List<&2, U32>>}
      Equal.cong(List<&2, List<&2, U32>>, List<&2, List<&2, U32>>, w => RS.vary_result(w, "Origin" <> x), RS.vary_values(l), u, same)
