# BND-40: the finalized CORS response equals the specification read from the
# request.
import Base
import ../src/http/request.bend as Request
import ../src/http/response.bend as Response
import ../src/http/bytes.bend as Bytes
import ../src/data/utf8.bend as Utf8
import ../src/mw/cors_policy.bend as P
import ../src/mw/cors_request.bend as CR
import ../src/mw/response_policy.bend as Policy
import ./cors-spec.bend as CorsSpec
import ./cors.bend as CorsProof
import ./response-policy-spec.bend as RS
import ./response-policy.bend as RP
import ./cors-response-spec.bend as Spec

# ---- Reading the request ----

def text(+m: Maybe<&2, String>) -> {CR.text(m) == Spec.decoded(m) : String}:
  match m:
    case None{}: {==}
    case Some{s}: {==}

def sent(+values: List<&2, List<&2, U32>>) -> {CR.sent(values) == Spec.origin_field(values) : P.Sent}:
  match values:
    case Nil{}: {==}
    case +v <> +t:
      match t:
        case Nil{}: Equal.cong(String, P.Sent, s => P.Sent{s}, CR.text(Utf8.decode(v)), Spec.decoded(Utf8.decode(v)), text(Utf8.decode(v)))
        case w <> r: {==}

def texts(+values: List<&2, List<&2, U32>>) -> {CR.texts(values) == Spec.decoded_all(values) : List<&2, String>}:
  match values:
    case Nil{}: {==}
    case +v <> +t:
      %text(Utf8.decode(v)) : {CR.texts(v <> t) == _ <> Spec.decoded_all(t) : List<&2, String>}
      Equal.cong(List<&2, String>, List<&2, String>, l => CR.text(Utf8.decode(v)) <> l, CR.texts(t), Spec.decoded_all(t), texts(t))

def combined(+values: List<&2, List<&2, U32>>) -> {CR.combined(values) == Spec.requested_list(values) : Maybe<&2, String>}:
  match values:
    case Nil{}: {==}
    case +v <> +t: Equal.cong(List<&2, String>, Maybe<&2, String>, l => Some{String.join(l, ",")}, CR.texts(v <> t), Spec.decoded_all(v <> t), texts(v <> t))

def some(+values: List<&2, List<&2, U32>>) -> {CR.some(values) == Spec.any_field(values) : Bool}:
  match values:
    case Nil{}: {==}
    case v <> t: {==}

def grant(+config: P.Config, +req: Request.Req) -> {CR.grant(config, req) == Spec.grant(config, req) : Maybe<&2, P.Grant>}:
  match config:
    case P.Config{+o, +m, +h, +e, +a}:
      match req:
        case Request.Req{+rm, +p, +q, +v, +hs}:
          +values = Request.lookup(hs, "origin")
          Equal.trans(Maybe<&2, P.Grant>, P.grant(o, CR.sent(values)), P.grant(o, Spec.origin_field(values)), CorsSpec.grant(o, Spec.origin_field(values)), Equal.cong(P.Sent, Maybe<&2, P.Grant>, s => P.grant(o, s), CR.sent(values), Spec.origin_field(values), sent(values)), CorsProof.grant(o, Spec.origin_field(values)))

def requested(+req: Request.Req) -> {CR.requested(req) == Spec.requested(req) : Maybe<&2, String>}:
  match req:
    case Request.Req{+rm, +p, +q, +v, +hs}: combined(Request.lookup(hs, "access-control-request-headers"))

def preflight(+req: Request.Req) -> {CR.preflight(req) == Spec.preflight(req) : Bool}:
  match req:
    case Request.Req{+rm, +p, +q, +v, +hs}:
      +origin = Request.lookup(hs, "origin")
      +method = Request.lookup(hs, "access-control-request-method")
      %sent(origin) : {P.preflight(rm, CR.sent(origin), CR.some(method)) == CorsSpec.preflight(rm, _, Spec.any_field(method)) : Bool}
      %some(method) : {P.preflight(rm, CR.sent(origin), CR.some(method)) == CorsSpec.preflight(rm, CR.sent(origin), _) : Bool}
      CorsProof.preflight(rm, CR.sent(origin), CR.some(method))

# ---- Reflected request headers ----

def kept_name(+name: String, +r1: List<&2, String>, +r2: List<&2, String>, +ok: Bool, ih: {r1 == r2 : List<&2, String>}) -> {P.kept_token(name, r1, ok) == Spec.named(name, r2, ok) : List<&2, String>}:
  match ok:
    case True{}: Equal.cong(List<&2, String>, List<&2, String>, l => name <> l, r1, r2, ih)
    case False{}: ih

def names(+xs: List<&2, String>) -> {P.tokens(xs) == Spec.requested_names(xs) : List<&2, String>}:
  match xs:
    case Nil{}: {==}
    case +x <> +t: kept_name(Bytes.fold(String.trim(x)), P.tokens(t), Spec.requested_names(t), Bytes.token(Bytes.fold(String.trim(x))), names(t))

def comma(+xs: List<&2, String>) -> {P.joined(xs) == Spec.comma_list(xs) : Maybe<&2, String>}:
  match xs:
    case Nil{}: {==}
    case x <> t: {==}

def reflected(+r: Maybe<&2, String>) -> {P.reflect(r) == Spec.reflected(r) : Maybe<&2, String>}:
  match r:
    case None{}: {==}
    case Some{+v}:
      +parts = String.split(v, ',')
      Equal.trans(Maybe<&2, String>, P.joined(P.tokens(parts)), P.joined(Spec.requested_names(parts)), Spec.comma_list(Spec.requested_names(parts)), Equal.cong(List<&2, String>, Maybe<&2, String>, l => P.joined(l), P.tokens(parts), Spec.requested_names(parts), names(parts)), comma(Spec.requested_names(parts)))

# ---- The policy's parts ----

def fields(+xs: List<&2, P.Field>) -> {CR.fields(xs) == Spec.as_headers(xs) : List<&2, Request.Header>}:
  match xs:
    case Nil{}: {==}
    case P.Field{+n, +v} <> +t: Equal.cong(List<&2, Request.Header>, List<&2, Request.Header>, l => Request.Header{n, Response.utf8(v)} <> l, CR.fields(t), Spec.as_headers(t), fields(t))

def origin_vary(+o: P.Origins) -> {P.origin_vary(o) == Spec.origin_names(o) : List<&2, String>}:
  match o:
    case P.Any{}: {==}
    case P.Listed{es}: {==}

def headers_vary(+pf: Bool, +h: List<&2, String>) -> {P.headers_vary(pf, h) == Spec.request_header_names(pf, h) : List<&2, String>}:
  match pf:
    case True{}:
      match h:
        case Nil{}: {==}
        case x <> t: {==}
    case False{}:
      match h:
        case Nil{}: {==}
        case x <> t: {==}

def vary(+config: P.Config, +pf: Bool) -> {P.vary(config, pf) == Spec.vary_names(config, pf) : List<&2, String>}:
  match config:
    case P.Config{+o, +m, +h, +e, +a}:
      %origin_vary(o) : {P.vary(P.Config{o, m, h, e, a}, pf) == List.append(&2, String, _, Spec.request_header_names(pf, h)) : List<&2, String>}
      %headers_vary(pf, h) : {P.vary(P.Config{o, m, h, e, a}, pf) == List.append(&2, String, P.origin_vary(o), _) : List<&2, String>}
      {==}

def finish(+s: U32, +l: List<&2, Request.Header>, +b: List<&2, U32>, +rep: Maybe<&2, List<&2, U32>>, +names: List<&2, String>) -> {Response.Res{s, Policy.varied(l, names), b, rep} == Response.Res{s, RS.varied(l, names), b, rep} : Response.Res}:
  Equal.cong(List<&2, Request.Header>, Response.Res, x => Response.Res{s, x, b, rep}, Policy.varied(l, names), RS.varied(l, names), RP.varied(l, names))

# The chosen policy, applied, equals the specification for any grant,
# requested headers and preflight classification.
def chosen(+config: P.Config, +g: Maybe<&2, P.Grant>, +r: Maybe<&2, String>, +pf: Bool, +res: Response.Res) -> {Policy.apply(CR.chosen(config, g, r, pf), res) == Spec.built(config, g, r, pf, res) : Response.Res}:
  match pf:
    case True{}:
      match res:
        case Response.Res{+s, +hs, +b, +rep}:
          +fs = P.preflight_fields(config, g, P.reflect(r))
          %reflected(r) : {Policy.apply(CR.chosen(config, g, r, True{}), Response.Res{s, hs, b, rep}) == Response.Res{s, RS.varied(List.append(&2, Request.Header, RS.unrelated(hs, Spec.cors_names()), Spec.as_headers(CorsSpec.preflight_fields(config, g, _))), Spec.vary_names(config, True{})), b, rep} : Response.Res}
          %CorsProof.preflight_fields(config, g, P.reflect(r)) : {Policy.apply(CR.chosen(config, g, r, True{}), Response.Res{s, hs, b, rep}) == Response.Res{s, RS.varied(List.append(&2, Request.Header, RS.unrelated(hs, Spec.cors_names()), Spec.as_headers(_)), Spec.vary_names(config, True{})), b, rep} : Response.Res}
          %fields(fs) : {Policy.apply(CR.chosen(config, g, r, True{}), Response.Res{s, hs, b, rep}) == Response.Res{s, RS.varied(List.append(&2, Request.Header, RS.unrelated(hs, Spec.cors_names()), _), Spec.vary_names(config, True{})), b, rep} : Response.Res}
          %RP.stripped(P.owned(), hs) : {Policy.apply(CR.chosen(config, g, r, True{}), Response.Res{s, hs, b, rep}) == Response.Res{s, RS.varied(List.append(&2, Request.Header, _, CR.fields(fs)), Spec.vary_names(config, True{})), b, rep} : Response.Res}
          %vary(config, True{}) : {Policy.apply(CR.chosen(config, g, r, True{}), Response.Res{s, hs, b, rep}) == Response.Res{s, RS.varied(List.append(&2, Request.Header, Policy.stripped(P.owned(), hs), CR.fields(fs)), _), b, rep} : Response.Res}
          finish(s, List.append(&2, Request.Header, Policy.stripped(P.owned(), hs), CR.fields(fs)), b, rep, P.vary(config, True{}))
    case False{}:
      match res:
        case Response.Res{+s, +hs, +b, +rep}:
          +fs = P.actual_fields(config, g)
          %CorsProof.actual_fields(config, g) : {Policy.apply(CR.chosen(config, g, r, False{}), Response.Res{s, hs, b, rep}) == Response.Res{s, RS.varied(List.append(&2, Request.Header, RS.unrelated(hs, Spec.cors_names()), Spec.as_headers(_)), Spec.vary_names(config, False{})), b, rep} : Response.Res}
          %fields(fs) : {Policy.apply(CR.chosen(config, g, r, False{}), Response.Res{s, hs, b, rep}) == Response.Res{s, RS.varied(List.append(&2, Request.Header, RS.unrelated(hs, Spec.cors_names()), _), Spec.vary_names(config, False{})), b, rep} : Response.Res}
          %RP.stripped(P.owned(), hs) : {Policy.apply(CR.chosen(config, g, r, False{}), Response.Res{s, hs, b, rep}) == Response.Res{s, RS.varied(List.append(&2, Request.Header, _, CR.fields(fs)), Spec.vary_names(config, False{})), b, rep} : Response.Res}
          %vary(config, False{}) : {Policy.apply(CR.chosen(config, g, r, False{}), Response.Res{s, hs, b, rep}) == Response.Res{s, RS.varied(List.append(&2, Request.Header, Policy.stripped(P.owned(), hs), CR.fields(fs)), _), b, rep} : Response.Res}
          finish(s, List.append(&2, Request.Header, Policy.stripped(P.owned(), hs), CR.fields(fs)), b, rep, P.vary(config, False{}))

# The retained policy, applied to any downstream response, equals the
# specification read from the request.
def response(+config: P.Config, +req: Request.Req, +res: Response.Res) -> {Policy.apply(CR.policy(config, req), res) == Spec.response(config, req, res) : Response.Res}:
  %grant(config, req) : {Policy.apply(CR.policy(config, req), res) == Spec.built(config, _, Spec.requested(req), Spec.preflight(req), res) : Response.Res}
  %requested(req) : {Policy.apply(CR.policy(config, req), res) == Spec.built(config, CR.grant(config, req), _, Spec.preflight(req), res) : Response.Res}
  %preflight(req) : {Policy.apply(CR.policy(config, req), res) == Spec.built(config, CR.grant(config, req), CR.requested(req), _, res) : Response.Res}
  chosen(config, CR.grant(config, req), CR.requested(req), CR.preflight(req), res)
