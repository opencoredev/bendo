# BND-25: rendered error responses.
import Base
import ./hot-path.bend as HP
import ../src/app/errors.bend as Errors
import ../src/app/context.bend as C
import ../src/http/response.bend as Response
import ../src/data/utf8.bend as U
import ../src/http/request.bend as Request
import ./error-laws.bend as Laws
import ./error-spec.bend as Spec
import ../src/data/json.bend as Json
import ../src/http/bytes.bend as Bytes
import ../src/http/write_response.bend as WriteResponse
import ./response-runtime.bend as ResponseRuntime
import ./utf8.bend as Utf8Proof
import ../src/router/pattern.bend as Pattern
import ../src/data/urlencoded.bend as Query
import ../src/app/observability.bend as Obs
import ./chunked-arith.bend as Arith
import ./error-headers.bend as Hd
import ./accept.bend as AcceptProof
import ./accept-spec.bend as AcceptSpec

def distinguish(b: Bool) -> Type:
  match b:
    case False{}: Unit
    case True{}: Empty

def false_true(e: {False{} == True{} : Bool}) -> Empty:
  %e : distinguish(_)
  Unit{}

def absurd(-A: Type, e: Empty) -> A:
  match e:

def left(a: Bool, b: Bool, ok: {a && b == True{} : Bool}) -> {a == True{} : Bool}:
  match a:
    case True{}: {==}
    case False{}: ok

def right(a: Bool, b: Bool, ok: {a && b == True{} : Bool}) -> {b == True{} : Bool}:
  match a:
    case True{}: ok
    case False{}: absurd({b == True{} : Bool}, false_true(ok))

# x >= 1 + b implies x >= b.
def ge_pred(+x: Nat, +b: Nat, ok: {Cmp.is_ge(Nat.cmp(x, 1n+b)) == True{} : Bool}) -> {Cmp.is_ge(Nat.cmp(x, b)) == True{} : Bool}:
  match x b:
    case 0n _: absurd({Cmp.is_ge(Nat.cmp(0n, b)) == True{} : Bool}, false_true(ok))
    case 1n+p 0n: {==}
    case 1n+p 1n+q: ge_pred(p, q, ok)

def ge_down(+k: Nat, +x: Nat, +b: Nat, ok: {Cmp.is_ge(Nat.cmp(x, Nat.add(k, b))) == True{} : Bool}) -> {Cmp.is_ge(Nat.cmp(x, b)) == True{} : Bool}:
  match k:
    case 0n: ok
    case 1n+p: ge_down(p, x, b, ge_pred(x, Nat.add(p, b), ok))

def ge_100(+code: U32, ok: {(code >= 400 : U32) == True{} : Bool}) -> {(code >= 100 : U32) == True{} : Bool}:
  +x = U32.to_nat(code)
  nat400 = Equal.trans(Bool, Cmp.is_ge(Nat.cmp(x, Nat.add(300n, 100n))), Cmp.is_ge(U32.cmp(code, 400)), True{}, Equal.cong(Cmp, Bool, c => Cmp.is_ge(c), Nat.cmp(x, Nat.add(300n, 100n)), U32.cmp(code, 400), Equal.sym(Cmp, U32.cmp(code, 400), Nat.cmp(x, U32.to_nat(400)), Arith.u32_nat_cmp(code, 400))), ok)
  Equal.trans(Bool, Cmp.is_ge(U32.cmp(code, 100)), Cmp.is_ge(Nat.cmp(x, 100n)), True{}, Equal.cong(Cmp, Bool, c => Cmp.is_ge(c), U32.cmp(code, 100), Nat.cmp(x, U32.to_nat(100)), Arith.u32_nat_cmp(code, 100)), ge_down(300n, x, 100n, nat400))

def status_in(+code: U32, in_range: Bool, +e: {(code >= 400 : U32) && (code <= 599 : U32) == in_range : Bool}) -> {(Errors.status_valid(code, in_range) >= 100 : U32) && (Errors.status_valid(code, in_range) <= 599 : U32) == True{} : Bool}:
  match in_range:
    case False{}: {==}
    case True{}:
      +ge = left((code >= 400 : U32), (code <= 599 : U32), e)
      +le = right((code >= 400 : U32), (code <= 599 : U32), e)
      %Equal.sym(Bool, (code >= 100 : U32), True{}, ge_100(code, ge)) : {_ && (code <= 599 : U32) == True{} : Bool}
      le

def status_range(+code: U32) -> {(Errors.status(code) >= 100 : U32) && (Errors.status(code) <= 599 : U32) == True{} : Bool}:
  status_in(code, (code >= 400 : U32) && (code <= 599 : U32), {==})

# Nat.show emits only ASCII digits. The state records m + r = 9, as in
# response-decimal.bend; each step advances the remainder modulo ten.
type Rem is Data:
  R0{}
  R1{}
  R2{}
  R3{}
  R4{}
  R5{}
  R6{}
  R7{}
  R8{}
  R9{}

def remaining(s: Rem) -> Nat:
  match s:
    case R0{}: 9n
    case R1{}: 8n
    case R2{}: 7n
    case R3{}: 6n
    case R4{}: 5n
    case R5{}: 4n
    case R6{}: 3n
    case R7{}: 2n
    case R8{}: 1n
    case R9{}: 0n

def remainder(s: Rem) -> Nat:
  match s:
    case R0{}: 0n
    case R1{}: 1n
    case R2{}: 2n
    case R3{}: 3n
    case R4{}: 4n
    case R5{}: 5n
    case R6{}: 6n
    case R7{}: 7n
    case R8{}: 8n
    case R9{}: 9n

# A Char that is a Unicode scalar and encodes to octets.
def plain(c: Char) -> Bool:
  match c:
    case Chr{+x}: U.scalar(x) && Response.octets(U.encode_char(x))

def pair_plain(dq: Char & Nat) -> Bool:
  (d, q) = dq
  plain(d)

def divmod_plain(+n: Nat, +s: Rem, +d: Nat) -> {pair_plain(Nat.show.put(Nat.divmod.go(n, remaining(s), d, remainder(s)))) == True{} : Bool}:
  match n:
    case 0n:
      match s:
        case R0{}: {==}
        case R1{}: {==}
        case R2{}: {==}
        case R3{}: {==}
        case R4{}: {==}
        case R5{}: {==}
        case R6{}: {==}
        case R7{}: {==}
        case R8{}: {==}
        case R9{}: {==}
    case 1n+p:
      match s:
        case R0{}: divmod_plain(p, R1{}, d)
        case R1{}: divmod_plain(p, R2{}, d)
        case R2{}: divmod_plain(p, R3{}, d)
        case R3{}: divmod_plain(p, R4{}, d)
        case R4{}: divmod_plain(p, R5{}, d)
        case R5{}: divmod_plain(p, R6{}, d)
        case R6{}: divmod_plain(p, R7{}, d)
        case R7{}: divmod_plain(p, R8{}, d)
        case R8{}: divmod_plain(p, R9{}, d)
        case R9{}: divmod_plain(p, R0{}, 1n+d)

def and_intro(a: Bool, b: Bool, ea: {a == True{} : Bool}, eb: {b == True{} : Bool}) -> {a && b == True{} : Bool}:
  %Equal.sym(Bool, a, True{}, ea) : {_ && b == True{} : Bool}
  eb

def octets_flag(ok: Bool, +xs: List<&2, U32>, e: {Response.octets_go(xs, ok) == True{} : Bool}) -> {ok == True{} : Bool}:
  match ok xs:
    case True{} _: {==}
    case False{} Nil{}: absurd({False{} == True{} : Bool}, false_true(e))
    case False{} c <> t: absurd({False{} == True{} : Bool}, false_true(e))

def octets_app(+xs: List<&2, U32>, +ys: List<&2, U32>, +ox: {Response.octets(xs) == True{} : Bool}, +oy: {Response.octets(ys) == True{} : Bool}) -> {Response.octets(List.append(&2, U32, xs, ys)) == True{} : Bool}:
  match xs:
    case Nil{}: oy
    case c <> t:
      +flag = octets_flag((c <= 255 : U32), t, ox)
      +ot = Equal.trans(Bool, Response.octets_go(t, True{}), Response.octets_go(t, (c <= 255 : U32)), True{}, Equal.cong(Bool, Bool, b => Response.octets_go(t, b), True{}, (c <= 255 : U32), Equal.sym(Bool, (c <= 255 : U32), True{}, flag)), ox)
      %Equal.sym(Bool, (c <= 255 : U32), True{}, flag) : {Response.octets_go(List.append(&2, U32, t, ys), _) == True{} : Bool}
      octets_app(t, ys, ot, oy)

# A string that is valid UTF-8 text and whose encoding is octets.
def good(s: String) -> Bool:
  +x = s
  U.valid_spec(x) && Response.octets(U.encode_spec(x))

def plain_cons(+x: U32, +rest: String, +px: {plain(Chr{x}) == True{} : Bool}, +pr: {good(rest) == True{} : Bool}) -> {good(SCon{Chr{x}, rest}) == True{} : Bool}:
  +vx = left(U.scalar(x), Response.octets(U.encode_char(x)), px)
  +ox = right(U.scalar(x), Response.octets(U.encode_char(x)), px)
  +vr = left(U.valid_spec(rest), Response.octets(U.encode_spec(rest)), pr)
  +orr = right(U.valid_spec(rest), Response.octets(U.encode_spec(rest)), pr)
  and_intro(U.scalar(x) && U.valid_spec(rest), Response.octets(List.append(&2, U32, U.encode_char(x), U.encode_spec(rest))), and_intro(U.scalar(x), U.valid_spec(rest), vx, vr), octets_app(U.encode_char(x), U.encode_spec(rest), ox, orr))

def char_cons(+d: Char, +acc: String, +t: String, +de: {plain(d) == True{} : Bool}, +ae: {good(acc ++ t) == True{} : Bool}) -> {good(SCon{d, acc} ++ t) == True{} : Bool}:
  match d:
    case Chr{+x}: plain_cons(x, acc ++ t, de, ae)

def fin_good(+g: Nat, +acc: String, +t: String, dq: Char & Nat, +de: {pair_plain(dq) == True{} : Bool}, +ae: {good(acc ++ t) == True{} : Bool}, step: @n:Nat -> @s:String -> {good(s ++ t) == True{} : Bool} -> {good(Nat.show.go(g, n, s) ++ t) == True{} : Bool}) -> {good(Nat.show.fin(g, acc, dq) ++ t) == True{} : Bool}:
  match dq:
    case (+d, q):
      match q:
        case 0n: char_cons(d, acc, t, de, ae)
        case 1n+p: step(1n+p, SCon{d, acc}, char_cons(d, acc, t, de, ae))

def go_good(+f: Nat, +n: Nat, +acc: String, +t: String, +ae: {good(acc ++ t) == True{} : Bool}) -> {good(Nat.show.go(f, n, acc) ++ t) == True{} : Bool}:
  match f:
    case 0n: ae
    case 1n+g:
      fin_good(g, acc, t, Nat.show.put(Nat.divmod(n, 10n)), divmod_plain(n, R0{}, 0n), ae, +k => +s => e => go_good(g, k, s, t, e))

def show_good(+n: Nat, +t: String, +te: {good(t) == True{} : Bool}) -> {good(Nat.show(n) ++ t) == True{} : Bool}:
  fin_good(n, SNil{}, t, Nat.show.put(Nat.divmod(n, 10n)), divmod_plain(n, R0{}, 0n), te, +k => +s => e => go_good(n, k, s, t, e))

def valid_res(+s: U32, +hs: List<&2, Request.Header>, +b: List<&2, U32>, range: {(s >= 100 : U32) && (s <= 599 : U32) == True{} : Bool}, hv: {Request.headers_valid(hs) == True{} : Bool}, ob: {Response.octets(b) == True{} : Bool}) -> {Response.valid(Response.Res{s, hs, b, None{}}) == True{} : Bool}:
  and_intro((s >= 100 : U32) && (s <= 599 : U32) && Request.headers_valid(hs) && Response.octets(b), True{}, and_intro((s >= 100 : U32) && (s <= 599 : U32) && Request.headers_valid(hs), Response.octets(b), and_intro((s >= 100 : U32) && (s <= 599 : U32), Request.headers_valid(hs), range, hv), ob), {==})

def checked_true(+r: Response.Res, v: Bool, e: {v == True{} : Bool}) -> {C.checked(r, v) == r : Response.Res}:
  %Equal.sym(Bool, v, True{}, e) : {C.checked(r, _) == r : Response.Res}
  {==}

def status_spec_in(+code: U32, in_range: Bool) -> {Errors.status_valid(code, in_range) == Spec.status_pick(code, in_range) : U32}:
  match in_range:
    case True{}: {==}
    case False{}: {==}

def status_spec(+code: U32) -> {Errors.status(code) == Spec.status(code) : U32}:
  status_spec_in(code, (code >= 400 : U32) && (code <= 599 : U32))

def utf8_octets(+s: String, +g: {good(s) == True{} : Bool}) -> {Response.octets(Response.utf8(s)) == True{} : Bool}:
  +v = Equal.trans(Bool, U.valid(s), U.valid_spec(s), True{}, Utf8Proof.valid_equiv(s), left(U.valid_spec(s), Response.octets(U.encode_spec(s)), g))
  %HP.utf8_spec_equiv(s) : {Response.octets(_) == True{} : Bool}
  %Equal.sym(String, Response.scalars(s), s, ResponseRuntime.scalars(s, v)) : {Response.octets(U.encode(_)) == True{} : Bool}
  %Equal.sym(List<&2, U32>, U.encode(s), U.encode_spec(s), Utf8Proof.encode_equiv(s)) : {Response.octets(_) == True{} : Bool}
  right(U.valid_spec(s), Response.octets(U.encode_spec(s)), g)

def private_json_text(+code: U32) -> String:
  "{\"error\":\"Internal Server Error\",\"status\":" ++ Nat.show(U32.to_nat(Errors.status(code))) ++ "}"

def private_json_octets(+code: U32) -> {Response.octets(Response.utf8(private_json_text(code))) == True{} : Bool}:
  utf8_octets(private_json_text(code), show_good(U32.to_nat(Errors.status(code)), "}", {==}))

def private_res(+json: Bool, +s: U32) -> Response.Res:
  Response.Res{s, [Spec.content_type(json), Spec.vary()], Spec.private_body(json, s), None{}}

def private_spec(+json: Bool, +code: U32) -> {private_res(json, Errors.status(code)) == Spec.private(json, code) : Response.Res}:
  %status_spec(code) : {private_res(json, Errors.status(code)) == private_res(json, _) : Response.Res}
  {==}

def private_ok(+json: Bool, +code: U32) -> {Request.headers_valid([Spec.vary()]) && Response.valid(private_res(json, Errors.status(code))) == True{} : Bool}:
  match json:
    case True{}:
      and_intro(True{}, Response.valid(private_res(True{}, Errors.status(code))), {==}, valid_res(Errors.status(code), [Spec.content_type(True{}), Spec.vary()], Spec.private_body(True{}, Errors.status(code)), status_range(code), {==}, private_json_octets(code)))
    case False{}:
      and_intro(True{}, Response.valid(private_res(False{}, Errors.status(code))), {==}, valid_res(Errors.status(code), [Spec.content_type(False{}), Spec.vary()], Spec.private_body(False{}, Errors.status(code)), status_range(code), {==}, {==}))

def private_body(-Vars: Data, +req: Request.Req, +params: List<&2, Pattern.Param>, +body: List<&2, U32>, +pairs: List<&2, Query.Entry>, +st: U32, +vars: Maybe<&2, Vars>, +obs: Obs.State, +code: U32, +json: Bool) -> {C.error_body(Vars, C.vary_accept(Vars, C.Ctx{req, params, body, pairs, st, [], vars, obs}), Errors.status(code), "Internal Server Error", json) == Spec.private(json, code) : Response.Res}:
  match json:
    case True{}:
      Equal.trans(Response.Res, C.checked(private_res(True{}, Errors.status(code)), Request.headers_valid([Spec.vary()]) && Response.valid(private_res(True{}, Errors.status(code)))), private_res(True{}, Errors.status(code)), Spec.private(True{}, code), checked_true(private_res(True{}, Errors.status(code)), Request.headers_valid([Spec.vary()]) && Response.valid(private_res(True{}, Errors.status(code))), private_ok(True{}, code)), private_spec(True{}, code))
    case False{}:
      Equal.trans(Response.Res, C.checked(private_res(False{}, Errors.status(code)), Request.headers_valid([Spec.vary()]) && Response.valid(private_res(False{}, Errors.status(code)))), private_res(False{}, Errors.status(code)), Spec.private(False{}, code), checked_true(private_res(False{}, Errors.status(code)), Request.headers_valid([Spec.vary()]) && Response.valid(private_res(False{}, Errors.status(code))), private_ok(False{}, code)), private_spec(False{}, code))

# Laws.

def Laws.http_error_private_independent(Vars, c, code, m1, m2):
  {==}

def Laws.http_error_private_wire_independent(Vars, c, method, code, m1, m2):
  {==}

def Laws.http_error_private_rendered(Vars, req, params, body, pairs, st, vars, obs, code, message, json, negotiated):
  %Equal.sym(Bool, Errors.accepts_json(C.request_header(Vars, C.Ctx{req, params, body, pairs, st, [], vars, obs}, "accept")), json, negotiated) : {C.error_body(Vars, C.vary_accept(Vars, C.Ctx{req, params, body, pairs, st, [], vars, obs}), Errors.status(code), "Internal Server Error", _) == Spec.private(json, code) : Response.Res}
  private_body(Vars, req, params, body, pairs, st, vars, obs, code, json)

def private_sample(-Vars: Data, +req: Request.Req, +params: List<&2, Pattern.Param>, +body: List<&2, U32>, +pairs: List<&2, Query.Entry>, +st: U32, +vars: Maybe<&2, Vars>, +obs: Obs.State, +code: U32, +sample: Spec.Sample) -> {C.error_body(Vars, C.vary_accept(Vars, C.Ctx{req, params, body, pairs, st, [], vars, obs}), Errors.status(code), "Internal Server Error", Errors.accepts_json(Spec.sample_field(sample))) == Spec.private(Spec.sample_json(sample), code) : Response.Res}:
  match sample:
    case Spec.Absent{}: private_body(Vars, req, params, body, pairs, st, vars, obs, code, False{})
    case Spec.JsonRange{}: private_body(Vars, req, params, body, pairs, st, vars, obs, code, True{})
    case Spec.JsonParameters{}: private_body(Vars, req, params, body, pairs, st, vars, obs, code, True{})
    case Spec.JsonZero{}: private_body(Vars, req, params, body, pairs, st, vars, obs, code, False{})
    case Spec.JsonQuotedZero{}: private_body(Vars, req, params, body, pairs, st, vars, obs, code, False{})
    case Spec.Wildcard{}: private_body(Vars, req, params, body, pairs, st, vars, obs, code, False{})
    case Spec.TextRange{}: private_body(Vars, req, params, body, pairs, st, vars, obs, code, False{})

def Laws.http_error_private_accept_samples(Vars, req, params, body, pairs, st, vars, obs, code, message, sample, accept):
  %Equal.sym(Maybe<&2, String>, C.request_header(Vars, C.Ctx{req, params, body, pairs, st, [], vars, obs}, "accept"), Spec.sample_field(sample), accept) : {C.error_body(Vars, C.vary_accept(Vars, C.Ctx{req, params, body, pairs, st, [], vars, obs}), Errors.status(code), "Internal Server Error", Errors.accepts_json(_)) == Spec.private(Spec.sample_json(sample), code) : Response.Res}
  private_sample(Vars, req, params, body, pairs, st, vars, obs, code, sample)

def checked_guard(+r: Response.Res, v: Bool) -> {C.checked(r, v) == Spec.guard_pick(r, v) : Response.Res}:
  match v:
    case True{}: {==}
    case False{}: {==}

def scalar_go_valid_inner(+t: String, b: Bool) -> {Json.scalar_go(t, b) == b && U.valid_spec(t) : Bool}:
  match t b:
    case SNil{} True{}: {==}
    case SNil{} False{}: {==}
    case SCon{Chr{+c}, rest} True{}: scalar_go_valid_inner(rest, U.scalar(c))
    case SCon{Chr{+c}, rest} False{}: {==}

def scalar_go_valid(+t: String, +b: Bool) -> {Json.scalar_go(t, b) == b && U.valid(t) : Bool}:
  Equal.trans(Bool, Json.scalar_go(t, b), b && U.valid_spec(t), b && U.valid(t), scalar_go_valid_inner(t, b), Equal.cong(Bool, Bool, x => b && x, U.valid_spec(t), U.valid(t), Equal.sym(Bool, U.valid(t), U.valid_spec(t), Utf8Proof.valid_equiv(t))))

def default_text(m: String, +code: U32) -> {Errors.message_default(m, Response.reason(code), String.is_empty(m)) == Spec.public_text(m, code) : String}:
  match m:
    case SNil{}: {==}
    case SCon{h, t}: {==}

def exposed_json_res(+code: U32, +text: String) -> Response.Res:
  Response.Res{code, [Spec.content_type(True{}), Spec.vary()], Response.utf8(Spec.json_text(text, code)), None{}}

def exposed_text_res(+code: U32, +text: String) -> Response.Res:
  Response.Res{code, [Spec.content_type(False{}), Spec.vary()], Response.utf8(text), None{}}

def exposed_json_pick(-Vars: Data, +req: Request.Req, +params: List<&2, Pattern.Param>, +body: List<&2, U32>, +pairs: List<&2, Query.Entry>, +st: U32, +vars: Maybe<&2, Vars>, +obs: Obs.State, +code: U32, +text: String, b: Bool) -> {C.error_json_body(Vars, C.vary_accept(Vars, C.Ctx{req, params, body, pairs, st, [], vars, obs}), code, text, b) == Spec.json_pick(b, exposed_json_res(code, text)) : Response.Res}:
  match b:
    case True{}: checked_guard(exposed_json_res(code, text), Response.valid(exposed_json_res(code, text)))
    case False{}: {==}

def exposed_body(-Vars: Data, +req: Request.Req, +params: List<&2, Pattern.Param>, +body: List<&2, U32>, +pairs: List<&2, Query.Entry>, +st: U32, +vars: Maybe<&2, Vars>, +obs: Obs.State, +code: U32, +text: String, json: Bool) -> {C.error_body(Vars, C.vary_accept(Vars, C.Ctx{req, params, body, pairs, st, [], vars, obs}), code, text, json) == Spec.exposed_text(json, code, text) : Response.Res}:
  match json:
    case True{}:
      %Equal.sym(Bool, Json.scalars(text), U.valid(text), scalar_go_valid(text, True{})) : {C.error_json_body(Vars, C.vary_accept(Vars, C.Ctx{req, params, body, pairs, st, [], vars, obs}), code, text, _) == Spec.exposed_text(True{}, code, text) : Response.Res}
      exposed_json_pick(Vars, req, params, body, pairs, st, vars, obs, code, text, U.valid(text))
    case False{}:
      checked_guard(exposed_text_res(code, text), Response.valid(exposed_text_res(code, text)))

def Laws.http_error_exposed_rendered(Vars, req, params, body, pairs, st, vars, obs, code, message, json, in_range, negotiated):
  %Equal.sym(Bool, (code >= 400 : U32) && (code <= 599 : U32), True{}, in_range) : {C.error_body(Vars, C.vary_accept(Vars, C.Ctx{req, params, body, pairs, st, [], vars, obs}), Errors.status_valid(code, _), Errors.public_message(Errors.message_default(message, Response.reason(code), String.is_empty(message)), _), Errors.accepts_json(C.request_header(Vars, C.Ctx{req, params, body, pairs, st, [], vars, obs}, "accept"))) == Spec.exposed(json, code, message) : Response.Res}
  %Equal.sym(Bool, Errors.accepts_json(C.request_header(Vars, C.Ctx{req, params, body, pairs, st, [], vars, obs}, "accept")), json, negotiated) : {C.error_body(Vars, C.vary_accept(Vars, C.Ctx{req, params, body, pairs, st, [], vars, obs}), code, Errors.message_default(message, Response.reason(code), String.is_empty(message)), _) == Spec.exposed(json, code, message) : Response.Res}
  %Equal.sym(String, Errors.message_default(message, Response.reason(code), String.is_empty(message)), Spec.public_text(message, code), default_text(message, code)) : {C.error_body(Vars, C.vary_accept(Vars, C.Ctx{req, params, body, pairs, st, [], vars, obs}), code, _, json) == Spec.exposed(json, code, message) : Response.Res}
  exposed_body(Vars, req, params, body, pairs, st, vars, obs, code, Spec.public_text(message, code), json)

def tea_only(-Vars: Data, +req: Request.Req, +params: List<&2, Pattern.Param>, +body: List<&2, U32>, +pairs: List<&2, Query.Entry>, +st: U32, +vars: Maybe<&2, Vars>, +obs: Obs.State, json: Bool) -> {C.error_body(Vars, C.vary_accept(Vars, C.Ctx{req, params, body, pairs, st, [], vars, obs}), 418, "Tea only", json) == Spec.tea_only(json) : Response.Res}:
  match json:
    case True{}: {==}
    case False{}: {==}

def Laws.http_error_tea_only_rendered(Vars, req, params, body, pairs, st, vars, obs, json, negotiated):
  %Equal.sym(Bool, Errors.accepts_json(C.request_header(Vars, C.Ctx{req, params, body, pairs, st, [], vars, obs}, "accept")), json, negotiated) : {C.error_body(Vars, C.vary_accept(Vars, C.Ctx{req, params, body, pairs, st, [], vars, obs}), 418, "Tea only", _) == Spec.tea_only(json) : Response.Res}
  tea_only(Vars, req, params, body, pairs, st, vars, obs, json)

# Any accumulated headers: rendering equals Spec.render.

def render_text(-Vars: Data, +req: Request.Req, +params: List<&2, Pattern.Param>, +body: List<&2, U32>, +pairs: List<&2, Query.Entry>, +st: U32, +hs: List<&2, Request.Header>, +vars: Maybe<&2, Vars>, +obs: Obs.State, +code: U32, +text: String) -> {C.error_body(Vars, C.vary_accept(Vars, C.Ctx{req, params, body, pairs, st, hs, vars, obs}), code, text, False{}) == Spec.render(False{}, code, text, hs) : Response.Res}:
  %Equal.sym(List<&2, Request.Header>, C.type_headers(List.append(&2, Request.Header, C.without(hs, "vary"), [Hd.vary_header(hs)]), Some{"text/plain; charset=utf-8"}), Spec.headers(False{}, hs), Hd.headers_text(hs)) : {C.finalize(Response.Res{code, _, Response.utf8(text), None{}}) == Spec.render(False{}, code, text, hs) : Response.Res}
  Hd.deliver_spec(Response.Res{code, Spec.headers(False{}, hs), Response.utf8(text), None{}})

def render_json_pick(-Vars: Data, +req: Request.Req, +params: List<&2, Pattern.Param>, +body: List<&2, U32>, +pairs: List<&2, Query.Entry>, +st: U32, +hs: List<&2, Request.Header>, +vars: Maybe<&2, Vars>, +obs: Obs.State, +code: U32, +text: String, b: Bool) -> {C.error_json_body(Vars, C.vary_accept(Vars, C.Ctx{req, params, body, pairs, st, hs, vars, obs}), code, text, b) == Spec.scalar_pick(b, Spec.deliver(Response.Res{code, Spec.headers(True{}, hs), Response.utf8(Spec.json_text(text, code)), None{}})) : Response.Res}:
  match b:
    case True{}:
      %Equal.sym(List<&2, Request.Header>, C.type_headers(List.append(&2, Request.Header, C.without(hs, "vary"), [Hd.vary_header(hs)]), Some{"application/json; charset=utf-8"}), Spec.headers(True{}, hs), Hd.headers_json(hs)) : {C.finalize(Response.Res{code, _, Response.utf8(Spec.json_text(text, code)), None{}}) == Spec.deliver(Response.Res{code, Spec.headers(True{}, hs), Response.utf8(Spec.json_text(text, code)), None{}}) : Response.Res}
      Hd.deliver_spec(Response.Res{code, Spec.headers(True{}, hs), Response.utf8(Spec.json_text(text, code)), None{}})
    case False{}: {==}

def render_json(-Vars: Data, +req: Request.Req, +params: List<&2, Pattern.Param>, +body: List<&2, U32>, +pairs: List<&2, Query.Entry>, +st: U32, +hs: List<&2, Request.Header>, +vars: Maybe<&2, Vars>, +obs: Obs.State, +code: U32, +text: String) -> {C.error_body(Vars, C.vary_accept(Vars, C.Ctx{req, params, body, pairs, st, hs, vars, obs}), code, text, True{}) == Spec.render(True{}, code, text, hs) : Response.Res}:
  %Equal.sym(Bool, Json.scalars(text), U.valid(text), scalar_go_valid(text, True{})) : {C.error_json_body(Vars, C.vary_accept(Vars, C.Ctx{req, params, body, pairs, st, hs, vars, obs}), code, text, _) == Spec.render(True{}, code, text, hs) : Response.Res}
  render_json_pick(Vars, req, params, body, pairs, st, hs, vars, obs, code, text, U.valid(text))

def render_body(-Vars: Data, +req: Request.Req, +params: List<&2, Pattern.Param>, +body: List<&2, U32>, +pairs: List<&2, Query.Entry>, +st: U32, +hs: List<&2, Request.Header>, +vars: Maybe<&2, Vars>, +obs: Obs.State, +code: U32, +text: String, json: Bool) -> {C.error_body(Vars, C.vary_accept(Vars, C.Ctx{req, params, body, pairs, st, hs, vars, obs}), code, text, json) == Spec.render(json, code, text, hs) : Response.Res}:
  match json:
    case True{}: render_json(Vars, req, params, body, pairs, st, hs, vars, obs, code, text)
    case False{}: render_text(Vars, req, params, body, pairs, st, hs, vars, obs, code, text)

def private_render(json: Bool, +code: U32, +hs: List<&2, Request.Header>) -> {Spec.render(json, Errors.status(code), "Internal Server Error", hs) == Spec.private_with(json, code, hs) : Response.Res}:
  match json:
    case True{}:
      %Equal.sym(U32, Errors.status(code), Spec.status(code), status_spec(code)) : {Spec.render(True{}, _, "Internal Server Error", hs) == Spec.private_with(True{}, code, hs) : Response.Res}
      {==}
    case False{}:
      %Equal.sym(U32, Errors.status(code), Spec.status(code), status_spec(code)) : {Spec.render(False{}, _, "Internal Server Error", hs) == Spec.private_with(False{}, code, hs) : Response.Res}
      {==}

def Laws.http_error_private_with_headers(Vars, req, params, body, pairs, st, hs, vars, obs, code, message, json, negotiated):
  %Equal.sym(Bool, Errors.accepts_json(C.request_header(Vars, C.Ctx{req, params, body, pairs, st, hs, vars, obs}, "accept")), json, negotiated) : {C.error_body(Vars, C.vary_accept(Vars, C.Ctx{req, params, body, pairs, st, hs, vars, obs}), Errors.status(code), "Internal Server Error", _) == Spec.private_with(json, code, hs) : Response.Res}
  Equal.trans(Response.Res, C.error_body(Vars, C.vary_accept(Vars, C.Ctx{req, params, body, pairs, st, hs, vars, obs}), Errors.status(code), "Internal Server Error", json), Spec.render(json, Errors.status(code), "Internal Server Error", hs), Spec.private_with(json, code, hs), render_body(Vars, req, params, body, pairs, st, hs, vars, obs, Errors.status(code), "Internal Server Error", json), private_render(json, code, hs))

def Laws.http_error_exposed_with_headers(Vars, req, params, body, pairs, st, hs, vars, obs, code, message, json, in_range, negotiated):
  %Equal.sym(Bool, (code >= 400 : U32) && (code <= 599 : U32), True{}, in_range) : {C.error_body(Vars, C.vary_accept(Vars, C.Ctx{req, params, body, pairs, st, hs, vars, obs}), Errors.status_valid(code, _), Errors.public_message(Errors.message_default(message, Response.reason(code), String.is_empty(message)), _), Errors.accepts_json(C.request_header(Vars, C.Ctx{req, params, body, pairs, st, hs, vars, obs}, "accept"))) == Spec.exposed_with(json, code, message, hs) : Response.Res}
  %Equal.sym(Bool, Errors.accepts_json(C.request_header(Vars, C.Ctx{req, params, body, pairs, st, hs, vars, obs}, "accept")), json, negotiated) : {C.error_body(Vars, C.vary_accept(Vars, C.Ctx{req, params, body, pairs, st, hs, vars, obs}), code, Errors.message_default(message, Response.reason(code), String.is_empty(message)), _) == Spec.exposed_with(json, code, message, hs) : Response.Res}
  %Equal.sym(String, Errors.message_default(message, Response.reason(code), String.is_empty(message)), Spec.public_text(message, code), default_text(message, code)) : {C.error_body(Vars, C.vary_accept(Vars, C.Ctx{req, params, body, pairs, st, hs, vars, obs}), code, _, json) == Spec.exposed_with(json, code, message, hs) : Response.Res}
  render_body(Vars, req, params, body, pairs, st, hs, vars, obs, code, Spec.public_text(message, code), json)

def scalar_bad(b: Bool, +r: Response.Res, e: {Spec.deliver(r) == Response.Res{500, [], [], None{}} : Response.Res}) -> {Spec.scalar_pick(b, Spec.deliver(r)) == Response.Res{500, [], [], None{}} : Response.Res}:
  match b:
    case True{}: e
    case False{}: {==}

def render_bad(json: Bool, +code: U32, +text: String, +hs: List<&2, Request.Header>, bad: {Spec.admissible(Spec.headers(json, hs)) == False{} : Bool}) -> {Spec.render(json, code, text, hs) == Response.Res{500, [], [], None{}} : Response.Res}:
  match json:
    case True{}: scalar_bad(U.valid(text), Response.Res{code, Spec.headers(True{}, hs), Response.utf8(Spec.json_text(text, code)), None{}}, Hd.deliver_bad(code, Spec.headers(True{}, hs), Response.utf8(Spec.json_text(text, code)), bad))
    case False{}: Hd.deliver_bad(code, Spec.headers(False{}, hs), Response.utf8(text), bad)

def Laws.http_error_inadmissible_fallback(Vars, req, params, body, pairs, st, hs, vars, obs, failure, json, negotiated, bad):
  match failure:
    case Errors.HttpError{+code, +message, +expose}:
      %Equal.sym(Bool, Errors.accepts_json(C.request_header(Vars, C.Ctx{req, params, body, pairs, st, hs, vars, obs}, "accept")), json, negotiated) : {C.error_body(Vars, C.vary_accept(Vars, C.Ctx{req, params, body, pairs, st, hs, vars, obs}), Errors.status(code), Errors.message(Errors.HttpError{code, message, expose}), _) == Response.Res{500, [], [], None{}} : Response.Res}
      Equal.trans(Response.Res, C.error_body(Vars, C.vary_accept(Vars, C.Ctx{req, params, body, pairs, st, hs, vars, obs}), Errors.status(code), Errors.message(Errors.HttpError{code, message, expose}), json), Spec.render(json, Errors.status(code), Errors.message(Errors.HttpError{code, message, expose}), hs), Response.Res{500, [], [], None{}}, render_body(Vars, req, params, body, pairs, st, hs, vars, obs, Errors.status(code), Errors.message(Errors.HttpError{code, message, expose}), json), render_bad(json, Errors.status(code), Errors.message(Errors.HttpError{code, message, expose}), hs, bad))

def Laws.http_error_validity_spec(r):
  Hd.valid_spec(r)

# The x-note example is one instance of the universal fallback.
def note_bad(j: Bool) -> {Spec.admissible(Spec.headers(j, [Request.Header{"x-note", Bytes.encode("a\nb")}])) == False{} : Bool}:
  match j:
    case True{}: {==}
    case False{}: {==}

def Laws.http_error_invalid_header_fallback(Vars, req, params, body, pairs, st, vars, obs, failure):
  Laws.http_error_inadmissible_fallback(Vars, req, params, body, pairs, st, [Request.Header{"x-note", Bytes.encode("a\nb")}], vars, obs, failure, Errors.accepts_json(C.request_header(Vars, C.Ctx{req, params, body, pairs, st, [Request.Header{"x-note", Bytes.encode("a\nb")}], vars, obs}, "accept")), {==}, note_bad(Errors.accepts_json(C.request_header(Vars, C.Ctx{req, params, body, pairs, st, [Request.Header{"x-note", Bytes.encode("a\nb")}], vars, obs}, "accept"))))

def Laws.http_error_accept_policy(field):
  AcceptProof.accepts_spec(field)

def Laws.http_error_accept_field(Vars, c):
  AcceptProof.field_spec(Vars, c)

def Laws.http_error_private_negotiated(Vars, req, params, body, pairs, st, hs, vars, obs, code, message):
  Laws.http_error_private_with_headers(Vars, req, params, body, pairs, st, hs, vars, obs, code, message, AcceptSpec.accepts_json(AcceptSpec.accept_field(req)), Equal.trans(Bool, Errors.accepts_json(C.request_header(Vars, C.Ctx{req, params, body, pairs, st, hs, vars, obs}, "accept")), AcceptSpec.accepts_json(C.request_header(Vars, C.Ctx{req, params, body, pairs, st, hs, vars, obs}, "accept")), AcceptSpec.accepts_json(AcceptSpec.accept_field(req)), AcceptProof.accepts_spec(C.request_header(Vars, C.Ctx{req, params, body, pairs, st, hs, vars, obs}, "accept")), Equal.cong(Maybe<&2, String>, Bool, f => AcceptSpec.accepts_json(f), C.request_header(Vars, C.Ctx{req, params, body, pairs, st, hs, vars, obs}, "accept"), AcceptSpec.accept_field(req), AcceptProof.field_spec(Vars, C.Ctx{req, params, body, pairs, st, hs, vars, obs}))))

def Laws.http_error_exposed_negotiated(Vars, req, params, body, pairs, st, hs, vars, obs, code, message, in_range):
  Laws.http_error_exposed_with_headers(Vars, req, params, body, pairs, st, hs, vars, obs, code, message, AcceptSpec.accepts_json(AcceptSpec.accept_field(req)), in_range, Equal.trans(Bool, Errors.accepts_json(C.request_header(Vars, C.Ctx{req, params, body, pairs, st, hs, vars, obs}, "accept")), AcceptSpec.accepts_json(C.request_header(Vars, C.Ctx{req, params, body, pairs, st, hs, vars, obs}, "accept")), AcceptSpec.accepts_json(AcceptSpec.accept_field(req)), AcceptProof.accepts_spec(C.request_header(Vars, C.Ctx{req, params, body, pairs, st, hs, vars, obs}, "accept")), Equal.cong(Maybe<&2, String>, Bool, f => AcceptSpec.accepts_json(f), C.request_header(Vars, C.Ctx{req, params, body, pairs, st, hs, vars, obs}, "accept"), AcceptSpec.accept_field(req), AcceptProof.field_spec(Vars, C.Ctx{req, params, body, pairs, st, hs, vars, obs}))))

def head_payload(+r: Response.Res) -> {WriteResponse.payload(Request.Head{}, r) == [] : List<&2, U32>}:
  match r:
    case Response.Res{s, hs, b, rep}: {==}

def Laws.http_error_head_no_payload(Vars, c, failure):
  head_payload(C.error(Vars, c, failure))
