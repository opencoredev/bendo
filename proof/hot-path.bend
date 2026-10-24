# BND-68: proofs that the hot-path rewrites equal their retained specs.
import Base
import ./hot-path-laws.bend as Laws
import ../src/data/utf8.bend as Utf8
import ./utf8.bend as UP
import ../src/http/bytes.bend as B
import ../src/http/response.bend as R
import ../src/app/context.bend as C
import ../src/http/connection.bend as Cn
import ../src/http/text.bend as Text
import ../src/http/body.bend as Body
import ../src/http/parse.bend as Parse
import ../src/http/request.bend as Req
import ../src/data/utf8.bend as U
import ../src/mw/cors.bend as Cors
import ../src/mw/cors_request.bend as CR
import ../src/mw/cors_policy.bend as CP
import ../src/app/observability.bend as Obs

def Laws.hot_utf8_encode_char(c):
  Equal.sym(List<&2, U32>, Utf8.encode_char_spec(c), Utf8.encode_char(c), UP.encode_char_equiv(c))

# ---- BND-68: the branching token classifier equals the string search ----

def punct_step_14(+c: U32, hit: Bool) -> {B.tchar_punct_14(c, hit) == String.contains.if("", Char.show(Chr{c}), String.starts_with.go.if(SNil{}, "", hit)) : Bool}:
  match hit:
    case True{}:
      {==}
    case False{}:
      {==}

def punct_step_13(+c: U32, hit: Bool) -> {B.tchar_punct_13(c, hit) == String.contains.if("~", Char.show(Chr{c}), String.starts_with.go.if(SNil{}, "~", hit)) : Bool}:
  match hit:
    case True{}:
      {==}
    case False{}:
      punct_step_14(c, U32.is_eq(126, c))

def punct_step_12(+c: U32, hit: Bool) -> {B.tchar_punct_12(c, hit) == String.contains.if("|~", Char.show(Chr{c}), String.starts_with.go.if(SNil{}, "|~", hit)) : Bool}:
  match hit:
    case True{}:
      {==}
    case False{}:
      punct_step_13(c, U32.is_eq(124, c))

def punct_step_11(+c: U32, hit: Bool) -> {B.tchar_punct_11(c, hit) == String.contains.if("`|~", Char.show(Chr{c}), String.starts_with.go.if(SNil{}, "`|~", hit)) : Bool}:
  match hit:
    case True{}:
      {==}
    case False{}:
      punct_step_12(c, U32.is_eq(96, c))

def punct_step_10(+c: U32, hit: Bool) -> {B.tchar_punct_10(c, hit) == String.contains.if("_`|~", Char.show(Chr{c}), String.starts_with.go.if(SNil{}, "_`|~", hit)) : Bool}:
  match hit:
    case True{}:
      {==}
    case False{}:
      punct_step_11(c, U32.is_eq(95, c))

def punct_step_9(+c: U32, hit: Bool) -> {B.tchar_punct_9(c, hit) == String.contains.if("^_`|~", Char.show(Chr{c}), String.starts_with.go.if(SNil{}, "^_`|~", hit)) : Bool}:
  match hit:
    case True{}:
      {==}
    case False{}:
      punct_step_10(c, U32.is_eq(94, c))

def punct_step_8(+c: U32, hit: Bool) -> {B.tchar_punct_8(c, hit) == String.contains.if(".^_`|~", Char.show(Chr{c}), String.starts_with.go.if(SNil{}, ".^_`|~", hit)) : Bool}:
  match hit:
    case True{}:
      {==}
    case False{}:
      punct_step_9(c, U32.is_eq(46, c))

def punct_step_7(+c: U32, hit: Bool) -> {B.tchar_punct_7(c, hit) == String.contains.if("-.^_`|~", Char.show(Chr{c}), String.starts_with.go.if(SNil{}, "-.^_`|~", hit)) : Bool}:
  match hit:
    case True{}:
      {==}
    case False{}:
      punct_step_8(c, U32.is_eq(45, c))

def punct_step_6(+c: U32, hit: Bool) -> {B.tchar_punct_6(c, hit) == String.contains.if("+-.^_`|~", Char.show(Chr{c}), String.starts_with.go.if(SNil{}, "+-.^_`|~", hit)) : Bool}:
  match hit:
    case True{}:
      {==}
    case False{}:
      punct_step_7(c, U32.is_eq(43, c))

def punct_step_5(+c: U32, hit: Bool) -> {B.tchar_punct_5(c, hit) == String.contains.if("*+-.^_`|~", Char.show(Chr{c}), String.starts_with.go.if(SNil{}, "*+-.^_`|~", hit)) : Bool}:
  match hit:
    case True{}:
      {==}
    case False{}:
      punct_step_6(c, U32.is_eq(42, c))

def punct_step_4(+c: U32, hit: Bool) -> {B.tchar_punct_4(c, hit) == String.contains.if("'*+-.^_`|~", Char.show(Chr{c}), String.starts_with.go.if(SNil{}, "'*+-.^_`|~", hit)) : Bool}:
  match hit:
    case True{}:
      {==}
    case False{}:
      punct_step_5(c, U32.is_eq(39, c))

def punct_step_3(+c: U32, hit: Bool) -> {B.tchar_punct_3(c, hit) == String.contains.if("&'*+-.^_`|~", Char.show(Chr{c}), String.starts_with.go.if(SNil{}, "&'*+-.^_`|~", hit)) : Bool}:
  match hit:
    case True{}:
      {==}
    case False{}:
      punct_step_4(c, U32.is_eq(38, c))

def punct_step_2(+c: U32, hit: Bool) -> {B.tchar_punct_2(c, hit) == String.contains.if("%&'*+-.^_`|~", Char.show(Chr{c}), String.starts_with.go.if(SNil{}, "%&'*+-.^_`|~", hit)) : Bool}:
  match hit:
    case True{}:
      {==}
    case False{}:
      punct_step_3(c, U32.is_eq(37, c))

def punct_step_1(+c: U32, hit: Bool) -> {B.tchar_punct_1(c, hit) == String.contains.if("$%&'*+-.^_`|~", Char.show(Chr{c}), String.starts_with.go.if(SNil{}, "$%&'*+-.^_`|~", hit)) : Bool}:
  match hit:
    case True{}:
      {==}
    case False{}:
      punct_step_2(c, U32.is_eq(36, c))

def punct_step_0(+c: U32, hit: Bool) -> {B.tchar_punct_0(c, hit) == String.contains.if("#$%&'*+-.^_`|~", Char.show(Chr{c}), String.starts_with.go.if(SNil{}, "#$%&'*+-.^_`|~", hit)) : Bool}:
  match hit:
    case True{}:
      {==}
    case False{}:
      punct_step_1(c, U32.is_eq(35, c))

def tchar_pick_spec(+c: U32, alnum: Bool) -> {B.tchar_pick(c, alnum) == alnum || String.contains("!#$%&'*+-.^_`|~", Char.show(Chr{c})) : Bool}:
  match alnum:
    case True{}:
      {==}
    case False{}:
      punct_step_0(c, U32.is_eq(33, c))

def tchar_equiv(+c: U32) -> {B.tchar(c) == B.tchar_spec(c) : Bool}:
  tchar_pick_spec(c, ((c >= 48 : U32) && (c <= 57 : U32)) || ((c >= 65 : U32) && (c <= 90 : U32)) || ((c >= 97 : U32) && (c <= 122 : U32)))

def Laws.hot_bytes_tchar(c): tchar_equiv(c)

# ---- BND-68: the fused response encoder equals scalars then encode ----

def map_scalars(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{c}, t}:
      SCon{Chr{R.scalar(c)}, map_scalars(t)}

def fused(s: String) -> List<&2, U32>:
  match s:
    case SNil{}:
      []
    case SCon{Chr{c}, t}:
      List.append(&2, U32, Utf8.encode_char(R.scalar(c)), fused(t))

def rev_onto(+xs: List<&2, U32>, +acc: List<&2, U32>, +f: List<&2, U32>) -> {List.reverse.go(&2, U32, List.reverse.go(&2, U32, xs, acc), f) == List.reverse.go(&2, U32, acc, List.append(&2, U32, xs, f)) : List<&2, U32>}:
  match xs:
    case Nil{}:
      {==}
    case h <> t:
      rev_onto(t, h <> acc, f)

def octets_ascii(+a: Word(7n), +acc: List<&2, U32>) -> {R.utf8_octets(U32{U.join(7n, 25n, a, Word.zero(25n))}, acc, True{}) == List.reverse.go(&2, U32, Utf8.encode_char(R.scalar(U32{U.join(7n, 25n, a, Word.zero(25n))})), acc) : List<&2, U32>}:
  match a:
    case WCon{b0, WCon{b1, WCon{b2, WCon{b3, WCon{b4, WCon{b5, WCon{b6, WNil{}}}}}}}}:
      {==}

def octets_pick(+w: Word(32n), +acc: List<&2, U32>, z: Bool, e: {U.zero(25n, U.high(7n, 25n, w)) == z : Bool}) -> {R.utf8_octets(U32{w}, acc, z) == List.reverse.go(&2, U32, Utf8.encode_char(R.scalar(U32{w})), acc) : List<&2, U32>}:
  match z:
    case False{}:
      {==}
    case True{}:
      %UP.pad_reconstruct(7n, 25n, w, UP.zero_sound(25n, U.high(7n, 25n, w), e)) : {R.utf8_octets(U32{_}, acc, True{}) == List.reverse.go(&2, U32, Utf8.encode_char(R.scalar(U32{_})), acc) : List<&2, U32>}
      octets_ascii(U.low(7n, 25n, w), acc)

def octets_equiv(+c: U32, +acc: List<&2, U32>) -> {R.utf8_octets(c, acc, (c < 128 : U32)) == List.reverse.go(&2, U32, Utf8.encode_char(R.scalar(c)), acc) : List<&2, U32>}:
  match c:
    case U32{+w}:
      Equal.trans(List<&2, U32>, R.utf8_octets(U32{w}, acc, (U32{w} < 128 : U32)), R.utf8_octets(U32{w}, acc, U.zero(25n, U.high(7n, 25n, w))), List.reverse.go(&2, U32, Utf8.encode_char(R.scalar(U32{w})), acc), Equal.cong(Bool, List<&2, U32>, z => R.utf8_octets(U32{w}, acc, z), (U32{w} < 128 : U32), U.zero(25n, U.high(7n, 25n, w)), UP.ascii_lt(w)), octets_pick(w, acc, U.zero(25n, U.high(7n, 25n, w)), {==}))

def go_equiv(+s: String, +acc: List<&2, U32>) -> {R.utf8_go(s, acc) == List.reverse.go(&2, U32, acc, fused(s)) : List<&2, U32>}:
  match s:
    case SNil{}:
      {==}
    case SCon{Chr{+c}, t}:
      +ec = Utf8.encode_char(R.scalar(c))
      Equal.trans(List<&2, U32>, R.utf8_go(t, R.utf8_octets(c, acc, (c < 128 : U32))), R.utf8_go(t, List.reverse.go(&2, U32, ec, acc)), List.reverse.go(&2, U32, acc, List.append(&2, U32, ec, fused(t))), Equal.cong(List<&2, U32>, List<&2, U32>, x => R.utf8_go(t, x), R.utf8_octets(c, acc, (c < 128 : U32)), List.reverse.go(&2, U32, ec, acc), octets_equiv(c, acc)), Equal.trans(List<&2, U32>, R.utf8_go(t, List.reverse.go(&2, U32, ec, acc)), List.reverse.go(&2, U32, List.reverse.go(&2, U32, ec, acc), fused(t)), List.reverse.go(&2, U32, acc, List.append(&2, U32, ec, fused(t))), go_equiv(t, List.reverse.go(&2, U32, ec, acc)), rev_onto(ec, acc, fused(t))))

def fused_spec(+s: String) -> {fused(s) == Utf8.encode_spec(map_scalars(s)) : List<&2, U32>}:
  match s:
    case SNil{}:
      {==}
    case SCon{Chr{+c}, t}:
      Equal.cong(List<&2, U32>, List<&2, U32>, x => List.append(&2, U32, Utf8.encode_char(R.scalar(c)), x), fused(t), Utf8.encode_spec(map_scalars(t)), fused_spec(t))

def scalars_go_map(+s: String, +acc: String) -> {R.scalars_go(s, acc) == String.reverse.go(acc, map_scalars(s)) : String}:
  match s:
    case SNil{}:
      {==}
    case SCon{Chr{+c}, t}:
      scalars_go_map(t, SCon{Chr{R.scalar(c)}, acc})

def utf8_equiv(+s: String) -> {R.utf8(s) == R.utf8_spec(s) : List<&2, U32>}:
  e1 = go_equiv(s, [])
  e2 = fused_spec(s)
  e3 = Equal.sym(List<&2, U32>, Utf8.encode(map_scalars(s)), Utf8.encode_spec(map_scalars(s)), UP.encode_equiv(map_scalars(s)))
  e4 = Equal.cong(String, List<&2, U32>, x => Utf8.encode(x), map_scalars(s), R.scalars(s), Equal.sym(String, R.scalars(s), map_scalars(s), scalars_go_map(s, "")))
  Equal.trans(List<&2, U32>, R.utf8(s), fused(s), R.utf8_spec(s), e1, Equal.trans(List<&2, U32>, fused(s), Utf8.encode_spec(map_scalars(s)), R.utf8_spec(s), e2, Equal.trans(List<&2, U32>, Utf8.encode_spec(map_scalars(s)), Utf8.encode(map_scalars(s)), R.utf8_spec(s), e3, e4)))

# Spec first, so `%` rewrites the fused encoder into scalars then encode.
def utf8_spec_equiv(+s: String) -> {R.utf8_spec(s) == R.utf8(s) : List<&2, U32>}:
  Equal.sym(List<&2, U32>, R.utf8(s), R.utf8_spec(s), utf8_equiv(s))

def Laws.hot_response_utf8(s): utf8_equiv(s)

# ---- BND-68: fixed Content-Type bytes equal encoding the literal ----

def Laws.hot_context_text(Vars, c, value):
  match c:
    case C.Ctx{r, p, b, q, s, hs, v, o}:
      {==}

def Laws.hot_context_html(Vars, c, value):
  match c:
    case C.Ctx{r, p, b, q, s, hs, v, o}:
      {==}

def Laws.hot_context_json_result(Vars, c, result):
  match c result:
    case _ Fail{e}:
      {==}
    case C.Ctx{r, p, b, q, s, hs, v, o} Done{x}:
      {==}

# ---- BND-68: CORS derives its policy once per request ----

def Laws.hot_cors_actual(config, g, requested, res): {==}

def Laws.hot_cors_policy(config, req): {==}

def Laws.hot_secure_prepared(Vars, config, c, next): {==}

def Laws.hot_secure_prepared_spec(Vars, config, c, next): {==}

def Laws.hot_secure_dispatch(timing, jwt, Vars, config, c, next): {==}

def Laws.hot_secure_dispatch_registration(timing, jwt, Vars, config, c, next): {==}

# The two CORS shells with the grant, requested headers and preflight test
# abstracted, so the proof can split on the preflight Bool.
def cors_new(-Vars: Data, +config: CP.Config, +c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(R.Res), +g: Maybe<&2, CP.Grant>, +requested: Maybe<&2, String>, +p: Bool) -> IO(R.Res):
  +ready = CR.chosen(config, g, requested, p)
  do IO<R.Res>:
    res : R.Res <- Cors.respond_with(Vars, config, c, next, g, ready, p)
    Obs.retain(C.observation(Vars, c), ready)
    return res

def cors_old(-Vars: Data, +config: CP.Config, +c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(R.Res), +g: Maybe<&2, CP.Grant>, +requested: Maybe<&2, String>, +p: Bool) -> IO(R.Res):
  do IO<R.Res>:
    res : R.Res <- Cors.respond(Vars, config, c, next, g, p)
    Obs.retain(C.observation(Vars, c), CR.chosen(config, g, requested, p))
    return res

def cors_shells(-Vars: Data, +config: CP.Config, +c: C.Ctx<Vars>, next: C.Ctx<Vars> -> IO(R.Res), +g: Maybe<&2, CP.Grant>, +requested: Maybe<&2, String>, +p: Bool) -> {cors_new(Vars, config, c, next, g, requested, p) == cors_old(Vars, config, c, next, g, requested, p) : IO(R.Res)}:
  match p:
    case True{}:
      {==}
    case False{}:
      {==}

def Laws.hot_cors_middleware(Vars, config, c, next):
  cors_shells(Vars, config, c, next, CR.grant(config, C.request(Vars, c)), CR.requested(C.request(Vars, c)), CR.preflight(C.request(Vars, c)))

# ---- BND-68: only a Connection field's value is parsed ----

def header_value_and(+v: List<&2, U32>, +wanted: String, named: Bool) -> {Cn.header_value_hit(v, wanted, named) == named && Cn.tokens(Text.split(B.ascii(v), ','), wanted) : Bool}:
  match named:
    case True{}:
      {==}
    case False{}:
      {==}

def Laws.hot_connection_header_hit(n, v, wanted):
  header_value_and(v, wanted, String.eq(B.fold(n), "connection"))

# ---- BND-68: the head loop equals scanning from a Head state ----

# A Bad state ends the scan whatever input is left.
def scan_bad_431(~Policy: Data, ~select: Req.Req -> Policy -> U32, +policy: Policy, +xs: List<&2, U32>, +limit: U32, +headers: U32) -> {Body.head_scan_policy(~Policy, ~select, policy, xs, Body.Bad{431}, limit, headers) == (Body.Bad{431}, False{}) : Body.State & Bool}:
  match xs:
    case Nil{}:
      {==}
    case c <> t:
      {==}

def head_equiv(~Policy: Data, ~select: Req.Req -> Policy -> U32, +policy: Policy, +xs: List<&2, U32>, +s: Parse.State, +bytes: U32, +limit: U32, +headers: U32, over: Bool, e: {(bytes >= headers : U32) == over : Bool}) -> {Body.head_loop(~Policy, ~select, policy, xs, s, bytes, limit, headers, over) == Body.head_scan_policy(~Policy, ~select, policy, xs, Body.Head{s, bytes}, limit, headers) : Body.State & Bool}:
  match xs s over:
    case Nil{} Parse.RequestLine{rv, cr} _:
      {==}
    case Nil{} Parse.Headers{r, rv, cr} _:
      {==}
    case Nil{} Parse.Complete{r} _:
      {==}
    case Nil{} Parse.Bad{x} _:
      {==}
    case c <> t Parse.Complete{r} True{}:
      {==}
    case c <> t Parse.Complete{r} False{}:
      {==}
    case c <> t Parse.Bad{x} True{}:
      {==}
    case c <> t Parse.Bad{x} False{}:
      {==}
    case c <> t Parse.RequestLine{rv, cr} True{}:
      %Equal.sym(Bool, (bytes >= headers : U32), True{}, e) : {Body.head_loop(~Policy, ~select, policy, c <> t, Parse.RequestLine{rv, cr}, bytes, limit, headers, True{}) == Body.head_scan_policy(~Policy, ~select, policy, t, Body.head_step(Parse.RequestLine{rv, cr}, c, bytes, _), limit, headers) : Body.State & Bool}
      Equal.sym(Body.State & Bool, Body.head_scan_policy(~Policy, ~select, policy, t, Body.Bad{431}, limit, headers), (Body.Bad{431}, False{}), scan_bad_431(~Policy, ~select, policy, t, limit, headers))
    case c <> t Parse.Headers{r, rv, cr} True{}:
      %Equal.sym(Bool, (bytes >= headers : U32), True{}, e) : {Body.head_loop(~Policy, ~select, policy, c <> t, Parse.Headers{r, rv, cr}, bytes, limit, headers, True{}) == Body.head_scan_policy(~Policy, ~select, policy, t, Body.head_step(Parse.Headers{r, rv, cr}, c, bytes, _), limit, headers) : Body.State & Bool}
      Equal.sym(Body.State & Bool, Body.head_scan_policy(~Policy, ~select, policy, t, Body.Bad{431}, limit, headers), (Body.Bad{431}, False{}), scan_bad_431(~Policy, ~select, policy, t, limit, headers))
    case c <> t Parse.RequestLine{rv, cr} False{}:
      %Equal.sym(Bool, (bytes >= headers : U32), False{}, e) : {Body.head_loop(~Policy, ~select, policy, c <> t, Parse.RequestLine{rv, cr}, bytes, limit, headers, False{}) == Body.head_scan_policy(~Policy, ~select, policy, t, Body.head_step(Parse.RequestLine{rv, cr}, c, bytes, _), limit, headers) : Body.State & Bool}
      head_equiv(~Policy, ~select, policy, t, Parse.advance(Parse.RequestLine{rv, cr}, c), (bytes + 1 : U32), limit, headers, ((bytes + 1 : U32) >= headers : U32), {==})
    case c <> t Parse.Headers{r, rv, cr} False{}:
      %Equal.sym(Bool, (bytes >= headers : U32), False{}, e) : {Body.head_loop(~Policy, ~select, policy, c <> t, Parse.Headers{r, rv, cr}, bytes, limit, headers, False{}) == Body.head_scan_policy(~Policy, ~select, policy, t, Body.head_step(Parse.Headers{r, rv, cr}, c, bytes, _), limit, headers) : Body.State & Bool}
      head_equiv(~Policy, ~select, policy, t, Parse.advance(Parse.Headers{r, rv, cr}, c), (bytes + 1 : U32), limit, headers, ((bytes + 1 : U32) >= headers : U32), {==})

# The new head feed equals the retained one for every policy template.
def head_feed_equiv(~Policy: Data, ~select: Req.Req -> Policy -> U32, +policy: Policy, +xs: List<&2, U32>, +s: Parse.State, +bytes: U32, +limit: U32, +headers: U32) -> {Body.head_feed_policy(~Policy, ~select, policy, xs, s, bytes, limit, headers) == Body.head_feed_policy_spec(~Policy, ~select, policy, xs, s, bytes, limit, headers) : Body.State & Bool}:
  head_equiv(~Policy, ~select, policy, xs, s, bytes, limit, headers, (bytes >= headers : U32), {==})

def Laws.hot_body_head_feed(xs, s, bytes, limit, headers):
  head_feed_equiv(~U32, ~(req => n => n), limit, xs, s, bytes, limit, headers)

def Laws.hot_body_head_feed_policy(Policy, select, policy, xs, s, bytes, limit, headers):
  head_feed_equiv(~Policy, ~select, policy, xs, s, bytes, limit, headers)
