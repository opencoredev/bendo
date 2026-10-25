# BND-46: response compression decisions. Every gate of P.decide funnels
# into P.plan, so the laws are lemmas about plan plus one case split on
# whether the status is 304.
import Base
import ../src/mw/compress_policy.bend as P
import ../src/http/request.bend as Request
import ../src/http/response.bend as Response

def distinguish(b: Bool) -> Type:
  match b:
    case False{}: Unit
    case True{}: Empty

def false_true(+e: {False{} == True{} : Bool}) -> Empty:
  %e : distinguish(_)
  Unit{}

def absurd(-A: Type, +e: Empty) -> A:
  match e:

def is_some(m: Maybe<&2, P.Coding>) -> Bool:
  match m:
    case None{}: False{}
    case Some{c}: True{}

def unwrap(m: Maybe<&2, P.Coding>) -> P.Coding:
  match m:
    case None{}: P.Gzip{}
    case Some{c}: c

def is_deflate(c: P.Coding) -> Bool:
  match c:
    case P.Gzip{}: False{}
    case P.Deflate{}: True{}

def coded(p: P.Plan) -> Maybe<&2, P.Coding>:
  match p:
    case P.Encode{c}: Some{c}
    case _: None{}

# None is not Some.
def none_some(+c: P.Coding, +e: {None{} == Some{c} : Maybe<&2, P.Coding>}) -> Empty:
  false_true(Equal.cong(Maybe<&2, P.Coding>, Bool, is_some, None{}, Some{c}, e))

# A plan that is not Encode is not Encode{c}.
def not_encode(p: P.Plan, +c: P.Coding, no: {P.encodes(p) == False{} : Bool}, +e: {p == P.Encode{c} : P.Plan}) -> Empty:
  false_true(Equal.trans(Bool, False{}, P.encodes(p), True{}, Equal.sym(Bool, P.encodes(p), False{}, no), Equal.cong(P.Plan, Bool, P.encodes, p, P.Encode{c}, e)))

def or_left(+a: Bool, +b: Bool, +e: {a == True{} : Bool}) -> {a || b == True{} : Bool}:
  match a:
    case True{}: {==}
    case False{}: absurd({False{} || b == True{} : Bool}, false_true(e))

def or_right(a: Bool, +b: Bool, +e: {b == True{} : Bool}) -> {a || b == True{} : Bool}:
  match a:
    case True{}: {==}
    case False{}: e

def not_false(+b: Bool, +e: {b == False{} : Bool}) -> {Bool.not(b) == True{} : Bool}:
  match b:
    case True{}: absurd({Bool.not(True{}) == True{} : Bool}, false_true(Equal.sym(Bool, True{}, False{}, e)))
    case False{}: {==}

# ------------------------------------------------------------ plan lemmas

def plan_encoded(+e: Bool, +s: Bool, +b: Bool, +mode: P.Mode, +ch: Maybe<&2, P.Coding>, he: {e == True{} : Bool}) -> {P.plan(e, s, b, mode, ch) == P.Keep{} : P.Plan}:
  match e:
    case True{}: {==}
    case False{}: absurd({P.plan(False{}, s, b, mode, ch) == P.Keep{} : P.Plan}, false_true(he))

def plan_small(+e: Bool, +s: Bool, +b: Bool, +mode: P.Mode, +ch: Maybe<&2, P.Coding>, +hs: {s == True{} : Bool}) -> {P.encodes(P.plan(e, s, b, mode, ch)) == False{} : Bool}:
  match e s:
    case True{} _: {==}
    case False{} True{}: {==}
    case False{} False{}: absurd({P.encodes(P.plan(False{}, False{}, b, mode, ch)) == False{} : Bool}, false_true(hs))

def plan_bad(+e: Bool, +s: Bool, +b: Bool, +mode: P.Mode, +ch: Maybe<&2, P.Coding>, hb: {b == True{} : Bool}) -> {P.encodes(P.plan(e, s, b, mode, ch)) == False{} : Bool}:
  match e s b:
    case True{} _ _: {==}
    case False{} True{} _: {==}
    case False{} False{} True{}: {==}
    case False{} False{} False{}: absurd({P.encodes(P.plan(False{}, False{}, False{}, mode, ch)) == False{} : Bool}, false_true(hb))

def gated_headers(+ch: Maybe<&2, P.Coding>) -> {P.encodes(P.gated(P.Headers{}, ch)) == False{} : Bool}:
  match ch:
    case None{}: {==}
    case Some{c}: {==}

def gated_revalidate(+ch: Maybe<&2, P.Coding>) -> {P.encodes(P.gated(P.Revalidate{}, ch)) == False{} : Bool}:
  match ch:
    case None{}: {==}
    case Some{c}: {==}

def plan_headers(+e: Bool, +s: Bool, +b: Bool, +ch: Maybe<&2, P.Coding>) -> {P.encodes(P.plan(e, s, b, P.Headers{}, ch)) == False{} : Bool}:
  match e s b:
    case True{} _ _: {==}
    case False{} True{} _: {==}
    case False{} False{} True{}: {==}
    case False{} False{} False{}: gated_headers(ch)

def plan_revalidate(+e: Bool, +s: Bool, +b: Bool, +ch: Maybe<&2, P.Coding>) -> {P.encodes(P.plan(e, s, b, P.Revalidate{}, ch)) == False{} : Bool}:
  match e s b:
    case True{} _ _: {==}
    case False{} True{} _: {==}
    case False{} False{} True{}: {==}
    case False{} False{} False{}: gated_revalidate(ch)

def gated_choice(+mode: P.Mode, +ch: Maybe<&2, P.Coding>, +c: P.Coding, h: {P.gated(mode, ch) == P.Encode{c} : P.Plan}) -> {ch == Some{c} : Maybe<&2, P.Coding>}:
  match mode ch:
    case P.Headers{} None{}: absurd({None{} == Some{c} : Maybe<&2, P.Coding>}, not_encode(P.Vary{}, c, {==}, h))
    case P.Headers{} Some{x}: absurd({Some{x} == Some{c} : Maybe<&2, P.Coding>}, not_encode(P.Measure{x}, c, {==}, h))
    case P.Full{} None{}: absurd({None{} == Some{c} : Maybe<&2, P.Coding>}, not_encode(P.Vary{}, c, {==}, h))
    case P.Full{} Some{x}: Equal.cong(P.Plan, Maybe<&2, P.Coding>, coded, P.Encode{x}, P.Encode{c}, h)
    case P.Revalidate{} None{}: absurd({None{} == Some{c} : Maybe<&2, P.Coding>}, not_encode(P.Vary{}, c, {==}, h))
    case P.Revalidate{} Some{x}: absurd({Some{x} == Some{c} : Maybe<&2, P.Coding>}, not_encode(P.Revalidated{x}, c, {==}, h))

def plan_choice(+e: Bool, +s: Bool, +b: Bool, +mode: P.Mode, +ch: Maybe<&2, P.Coding>, +c: P.Coding, h: {P.plan(e, s, b, mode, ch) == P.Encode{c} : P.Plan}) -> {ch == Some{c} : Maybe<&2, P.Coding>}:
  match e s b:
    case True{} _ _: absurd({ch == Some{c} : Maybe<&2, P.Coding>}, not_encode(P.Keep{}, c, {==}, h))
    case False{} True{} _: absurd({ch == Some{c} : Maybe<&2, P.Coding>}, not_encode(P.Keep{}, c, {==}, h))
    case False{} False{} True{}: absurd({ch == Some{c} : Maybe<&2, P.Coding>}, not_encode(P.Keep{}, c, {==}, h))
    case False{} False{} False{}: gated_choice(mode, ch, c, h)

# ------------------------------------------------------------ decide lemmas

def revalidated_never(+cfg: P.Config, +hs: List<&2, Request.Header>, +rep: Maybe<&2, List<&2, U32>>, +ch: Maybe<&2, P.Coding>) -> {P.encodes(P.revalidated(cfg, hs, rep, ch)) == False{} : Bool}:
  match rep:
    case None{}: plan_revalidate(P.already(hs), False{}, True{}, ch)
    case Some{+w}: plan_revalidate(P.already(hs), P.small(Response.length(w), P.threshold(cfg)), P.unfit(hs, Response.length(w), P.limit(cfg)), ch)

def revalidated_choice(+cfg: P.Config, +hs: List<&2, Request.Header>, +rep: Maybe<&2, List<&2, U32>>, +ch: Maybe<&2, P.Coding>, +c: P.Coding, h: {P.revalidated(cfg, hs, rep, ch) == P.Encode{c} : P.Plan}) -> {ch == Some{c} : Maybe<&2, P.Coding>}:
  absurd({ch == Some{c} : Maybe<&2, P.Coding>}, not_encode(P.revalidated(cfg, hs, rep, ch), c, revalidated_never(cfg, hs, rep, ch), h))

def revalidated_encoded(+cfg: P.Config, +hs: List<&2, Request.Header>, +rep: Maybe<&2, List<&2, U32>>, +ch: Maybe<&2, P.Coding>, he: {P.already(hs) == True{} : Bool}) -> {P.revalidated(cfg, hs, rep, ch) == P.Keep{} : P.Plan}:
  match rep:
    case None{}: plan_encoded(P.already(hs), False{}, True{}, P.Revalidate{}, ch, he)
    case Some{+w}: plan_encoded(P.already(hs), P.small(Response.length(w), P.threshold(cfg)), P.unfit(hs, Response.length(w), P.limit(cfg)), P.Revalidate{}, ch, he)

def sized_choice(+cfg: P.Config, +m: Request.Method, +ch: Maybe<&2, P.Coding>, +s: U32, +hs: List<&2, Request.Header>, +body: List<&2, U32>, +rep: Maybe<&2, List<&2, U32>>, +nm: Bool, +c: P.Coding, h: {P.sized(cfg, m, ch, s, hs, body, rep, nm) == P.Encode{c} : P.Plan}) -> {ch == Some{c} : Maybe<&2, P.Coding>}:
  match nm:
    case True{}: revalidated_choice(cfg, hs, rep, ch, c, h)
    case False{}: plan_choice(P.already(hs), P.small(Response.length(body), P.threshold(cfg)), P.no_body_status(s) || P.unfit(hs, Response.length(body), P.limit(cfg)), P.body_mode(m), ch, c, h)

def sized_small(+cfg: P.Config, +m: Request.Method, +ch: Maybe<&2, P.Coding>, +s: U32, +hs: List<&2, Request.Header>, +body: List<&2, U32>, +rep: Maybe<&2, List<&2, U32>>, +nm: Bool, h: {Nat.is_lt(Response.length(body), U32.to_nat(P.threshold(cfg))) == True{} : Bool}) -> {P.encodes(P.sized(cfg, m, ch, s, hs, body, rep, nm)) == False{} : Bool}:
  match nm:
    case True{}: revalidated_never(cfg, hs, rep, ch)
    case False{}: plan_small(P.already(hs), P.small(Response.length(body), P.threshold(cfg)), P.no_body_status(s) || P.unfit(hs, Response.length(body), P.limit(cfg)), P.body_mode(m), ch, h)

def sized_large(+cfg: P.Config, +m: Request.Method, +ch: Maybe<&2, P.Coding>, +s: U32, +hs: List<&2, Request.Header>, +body: List<&2, U32>, +rep: Maybe<&2, List<&2, U32>>, +nm: Bool, h: {Nat.is_lt(U32.to_nat(P.limit(cfg)), Response.length(body)) == True{} : Bool}) -> {P.encodes(P.sized(cfg, m, ch, s, hs, body, rep, nm)) == False{} : Bool}:
  match nm:
    case True{}: revalidated_never(cfg, hs, rep, ch)
    case False{}: plan_bad(P.already(hs), P.small(Response.length(body), P.threshold(cfg)), P.no_body_status(s) || P.unfit(hs, Response.length(body), P.limit(cfg)), P.body_mode(m), ch, or_right(P.no_body_status(s), P.unfit(hs, Response.length(body), P.limit(cfg)), or_right((P.present(hs, "content-range") || P.no_transform(hs)) || P.media_skipped(P.media(hs)), Nat.is_lt(U32.to_nat(P.limit(cfg)), Response.length(body)), h)))

def sized_encoded(+cfg: P.Config, +m: Request.Method, +ch: Maybe<&2, P.Coding>, +s: U32, +hs: List<&2, Request.Header>, +body: List<&2, U32>, +rep: Maybe<&2, List<&2, U32>>, +nm: Bool, he: {P.already(hs) == True{} : Bool}) -> {P.sized(cfg, m, ch, s, hs, body, rep, nm) == P.Keep{} : P.Plan}:
  match nm:
    case True{}: revalidated_encoded(cfg, hs, rep, ch, he)
    case False{}: plan_encoded(P.already(hs), P.small(Response.length(body), P.threshold(cfg)), P.no_body_status(s) || P.unfit(hs, Response.length(body), P.limit(cfg)), P.body_mode(m), ch, he)

def sized_head(+cfg: P.Config, +ch: Maybe<&2, P.Coding>, +s: U32, +hs: List<&2, Request.Header>, +body: List<&2, U32>, +rep: Maybe<&2, List<&2, U32>>, +nm: Bool) -> {P.encodes(P.sized(cfg, Request.Head{}, ch, s, hs, body, rep, nm)) == False{} : Bool}:
  match nm:
    case True{}: revalidated_never(cfg, hs, rep, ch)
    case False{}: plan_headers(P.already(hs), P.small(Response.length(body), P.threshold(cfg)), P.no_body_status(s) || P.unfit(hs, Response.length(body), P.limit(cfg)), ch)

# ------------------------------------------------------------ negotiation

def offered_same(+cc: P.Coding, +below: Bool, +c: P.Coding, h: {P.offered(cc, below) == Some{c} : Maybe<&2, P.Coding>}) -> {cc == c : P.Coding}:
  match below:
    case True{}: absurd({cc == c : P.Coding}, none_some(c, h))
    case False{}: Equal.cong(Maybe<&2, P.Coding>, P.Coding, unwrap, Some{cc}, Some{c}, h)

def offered_above(+cc: P.Coding, +below: Bool, +c: P.Coding, h: {P.offered(cc, below) == Some{c} : Maybe<&2, P.Coding>}) -> {below == False{} : Bool}:
  match below:
    case True{}: absurd({True{} == False{} : Bool}, none_some(c, h))
    case False{}: {==}

def offer_same(+cc: P.Coding, +q: Nat, +i: Nat, +c: P.Coding, h: {P.offer(cc, q, i) == Some{c} : Maybe<&2, P.Coding>}) -> {cc == c : P.Coding}:
  match q:
    case 0n: absurd({cc == c : P.Coding}, none_some(c, h))
    case 1n+k: offered_same(cc, Nat.is_lt(1n+k, i), c, h)

def offer_nonzero(+cc: P.Coding, +q: Nat, +i: Nat, +c: P.Coding, h: {P.offer(cc, q, i) == Some{c} : Maybe<&2, P.Coding>}) -> {Nat.is_eq(q, 0n) == False{} : Bool}:
  match q:
    case 0n: absurd({Nat.is_eq(0n, 0n) == False{} : Bool}, none_some(c, h))
    case 1n+k: {==}

def offer_above(+cc: P.Coding, +q: Nat, +i: Nat, +c: P.Coding, h: {P.offer(cc, q, i) == Some{c} : Maybe<&2, P.Coding>}) -> {Nat.is_lt(q, i) == False{} : Bool}:
  match q:
    case 0n: absurd({Nat.is_lt(0n, i) == False{} : Bool}, none_some(c, h))
    case 1n+k: offered_above(cc, Nat.is_lt(1n+k, i), c, h)

# The weight pick read for the coding it chose.
def weight_of(g: Nat, d: Nat, c: P.Coding) -> Nat:
  match c:
    case P.Gzip{}: g
    case P.Deflate{}: d

def pick_nonzero(+g: Nat, +d: Nat, +i: Nat, +bd: Bool, +c: P.Coding, +h: {P.pick(g, d, i, bd) == Some{c} : Maybe<&2, P.Coding>}) -> {Nat.is_eq(weight_of(g, d, c), 0n) == False{} : Bool}:
  match bd:
    case True{}:
      %offer_same(P.Deflate{}, d, i, c, h) : {Nat.is_eq(weight_of(g, d, _), 0n) == False{} : Bool}
      offer_nonzero(P.Deflate{}, d, i, c, h)
    case False{}:
      %offer_same(P.Gzip{}, g, i, c, h) : {Nat.is_eq(weight_of(g, d, _), 0n) == False{} : Bool}
      offer_nonzero(P.Gzip{}, g, i, c, h)

def pick_above(+g: Nat, +d: Nat, +i: Nat, +bd: Bool, +c: P.Coding, +h: {P.pick(g, d, i, bd) == Some{c} : Maybe<&2, P.Coding>}) -> {Nat.is_lt(weight_of(g, d, c), i) == False{} : Bool}:
  match bd:
    case True{}:
      %offer_same(P.Deflate{}, d, i, c, h) : {Nat.is_lt(weight_of(g, d, _), i) == False{} : Bool}
      offer_above(P.Deflate{}, d, i, c, h)
    case False{}:
      %offer_same(P.Gzip{}, g, i, c, h) : {Nat.is_lt(weight_of(g, d, _), i) == False{} : Bool}
      offer_above(P.Gzip{}, g, i, c, h)

def pick_deflate(+g: Nat, +d: Nat, +i: Nat, +bd: Bool, h: {P.pick(g, d, i, bd) == Some{P.Deflate{}} : Maybe<&2, P.Coding>}) -> {bd == True{} : Bool}:
  match bd:
    case True{}: {==}
    case False{}: absurd({False{} == True{} : Bool}, false_true(Equal.cong(P.Coding, Bool, is_deflate, P.Gzip{}, P.Deflate{}, offer_same(P.Gzip{}, g, i, P.Deflate{}, h))))

# ------------------------------------------------------------------- laws

def select_nonzero(+prefs: List<&2, P.Pref>, +c: P.Coding, h: {P.select(prefs) == Some{c} : Maybe<&2, P.Coding>}) -> {Nat.is_eq(P.quality(prefs, c), 0n) == False{} : Bool}:
  match c:
    case P.Gzip{}: pick_nonzero(P.quality(prefs, P.Gzip{}), P.quality(prefs, P.Deflate{}), P.identity_quality(prefs), Nat.is_lt(P.quality(prefs, P.Gzip{}), P.quality(prefs, P.Deflate{})), P.Gzip{}, h)
    case P.Deflate{}: pick_nonzero(P.quality(prefs, P.Gzip{}), P.quality(prefs, P.Deflate{}), P.identity_quality(prefs), Nat.is_lt(P.quality(prefs, P.Gzip{}), P.quality(prefs, P.Deflate{})), P.Deflate{}, h)

def select_not_below_identity(+prefs: List<&2, P.Pref>, +c: P.Coding, h: {P.select(prefs) == Some{c} : Maybe<&2, P.Coding>}) -> {Nat.is_lt(P.quality(prefs, c), P.identity_quality(prefs)) == False{} : Bool}:
  match c:
    case P.Gzip{}: pick_above(P.quality(prefs, P.Gzip{}), P.quality(prefs, P.Deflate{}), P.identity_quality(prefs), Nat.is_lt(P.quality(prefs, P.Gzip{}), P.quality(prefs, P.Deflate{})), P.Gzip{}, h)
    case P.Deflate{}: pick_above(P.quality(prefs, P.Gzip{}), P.quality(prefs, P.Deflate{}), P.identity_quality(prefs), Nat.is_lt(P.quality(prefs, P.Gzip{}), P.quality(prefs, P.Deflate{})), P.Deflate{}, h)

def select_deflate_strict(+prefs: List<&2, P.Pref>, h: {P.select(prefs) == Some{P.Deflate{}} : Maybe<&2, P.Coding>}) -> {Nat.is_lt(P.quality(prefs, P.Gzip{}), P.quality(prefs, P.Deflate{})) == True{} : Bool}:
  pick_deflate(P.quality(prefs, P.Gzip{}), P.quality(prefs, P.Deflate{}), P.identity_quality(prefs), Nat.is_lt(P.quality(prefs, P.Gzip{}), P.quality(prefs, P.Deflate{})), h)

def choice_accepts(+accept: Maybe<&2, List<&2, P.Pref>>, +c: P.Coding, h: {P.choice(accept) == Some{c} : Maybe<&2, P.Coding>}) -> {P.accepts(accept, c) == True{} : Bool}:
  match accept:
    case None{}: absurd({P.accepts(None{}, c) == True{} : Bool}, none_some(c, h))
    case Some{+prefs}:
      %Equal.sym(Bool, Nat.is_eq(P.quality(prefs, c), 0n), False{}, select_nonzero(prefs, c, h)) : {Bool.not(_) == True{} : Bool}
      {==}

def encode_accepted(+cfg: P.Config, +m: Request.Method, +accept: Maybe<&2, List<&2, P.Pref>>, +s: U32, +hs: List<&2, Request.Header>, +body: List<&2, U32>, +rep: Maybe<&2, List<&2, U32>>, +c: P.Coding, h: {P.decide(cfg, m, accept, Response.Res{s, hs, body, rep}) == P.Encode{c} : P.Plan}) -> {P.accepts(accept, c) == True{} : Bool}:
  choice_accepts(accept, c, sized_choice(cfg, m, P.choice(accept), s, hs, body, rep, U32.is_eq(s, 304), c, h))

def small_kept(+cfg: P.Config, +m: Request.Method, +accept: Maybe<&2, List<&2, P.Pref>>, +s: U32, +hs: List<&2, Request.Header>, +body: List<&2, U32>, +rep: Maybe<&2, List<&2, U32>>, h: {Nat.is_lt(Response.length(body), U32.to_nat(P.threshold(cfg))) == True{} : Bool}) -> {P.encodes(P.decide(cfg, m, accept, Response.Res{s, hs, body, rep})) == False{} : Bool}:
  sized_small(cfg, m, P.choice(accept), s, hs, body, rep, U32.is_eq(s, 304), h)

def large_kept(+cfg: P.Config, +m: Request.Method, +accept: Maybe<&2, List<&2, P.Pref>>, +s: U32, +hs: List<&2, Request.Header>, +body: List<&2, U32>, +rep: Maybe<&2, List<&2, U32>>, h: {Nat.is_lt(U32.to_nat(P.limit(cfg)), Response.length(body)) == True{} : Bool}) -> {P.encodes(P.decide(cfg, m, accept, Response.Res{s, hs, body, rep})) == False{} : Bool}:
  sized_large(cfg, m, P.choice(accept), s, hs, body, rep, U32.is_eq(s, 304), h)

def encoded_kept(+cfg: P.Config, +m: Request.Method, +accept: Maybe<&2, List<&2, P.Pref>>, +s: U32, +hs: List<&2, Request.Header>, +body: List<&2, U32>, +rep: Maybe<&2, List<&2, U32>>, h: {List.is_empty(&2, List<&2, U32>, Request.lookup(hs, "content-encoding")) == False{} : Bool}) -> {P.decide(cfg, m, accept, Response.Res{s, hs, body, rep}) == P.Keep{} : P.Plan}:
  sized_encoded(cfg, m, P.choice(accept), s, hs, body, rep, U32.is_eq(s, 304), or_left(P.present(hs, "content-encoding"), P.present(hs, "x-bendo-stream-internal"), not_false(List.is_empty(&2, List<&2, U32>, Request.lookup(hs, "content-encoding")), h)))

def stream_kept(+cfg: P.Config, +m: Request.Method, +accept: Maybe<&2, List<&2, P.Pref>>, +s: U32, +hs: List<&2, Request.Header>, +body: List<&2, U32>, +rep: Maybe<&2, List<&2, U32>>, h: {List.is_empty(&2, List<&2, U32>, Request.lookup(hs, "x-bendo-stream-internal")) == False{} : Bool}) -> {P.decide(cfg, m, accept, Response.Res{s, hs, body, rep}) == P.Keep{} : P.Plan}:
  sized_encoded(cfg, m, P.choice(accept), s, hs, body, rep, U32.is_eq(s, 304), or_right(P.present(hs, "content-encoding"), P.present(hs, "x-bendo-stream-internal"), not_false(List.is_empty(&2, List<&2, U32>, Request.lookup(hs, "x-bendo-stream-internal")), h)))

def head_not_encoded(+cfg: P.Config, +accept: Maybe<&2, List<&2, P.Pref>>, +s: U32, +hs: List<&2, Request.Header>, +body: List<&2, U32>, +rep: Maybe<&2, List<&2, U32>>) -> {P.encodes(P.decide(cfg, Request.Head{}, accept, Response.Res{s, hs, body, rep})) == False{} : Bool}:
  sized_head(cfg, P.choice(accept), s, hs, body, rep, U32.is_eq(s, 304))

def not_modified_not_encoded(+cfg: P.Config, +m: Request.Method, +accept: Maybe<&2, List<&2, P.Pref>>, +hs: List<&2, Request.Header>, +body: List<&2, U32>, +rep: Maybe<&2, List<&2, U32>>) -> {P.encodes(P.decide(cfg, m, accept, Response.Res{304, hs, body, rep})) == False{} : Bool}:
  revalidated_never(cfg, hs, rep, P.choice(accept))

def no_content_not_encoded(+cfg: P.Config, +m: Request.Method, +accept: Maybe<&2, List<&2, P.Pref>>, +hs: List<&2, Request.Header>, +body: List<&2, U32>, +rep: Maybe<&2, List<&2, U32>>) -> {P.encodes(P.decide(cfg, m, accept, Response.Res{204, hs, body, rep})) == False{} : Bool}:
  plan_bad(P.already(hs), P.small(Response.length(body), P.threshold(cfg)), P.no_body_status(204) || P.unfit(hs, Response.length(body), P.limit(cfg)), P.body_mode(m), P.choice(accept), {==})

def partial_not_encoded(+cfg: P.Config, +m: Request.Method, +accept: Maybe<&2, List<&2, P.Pref>>, +hs: List<&2, Request.Header>, +body: List<&2, U32>, +rep: Maybe<&2, List<&2, U32>>) -> {P.encodes(P.decide(cfg, m, accept, Response.Res{206, hs, body, rep})) == False{} : Bool}:
  plan_bad(P.already(hs), P.small(Response.length(body), P.threshold(cfg)), P.no_body_status(206) || P.unfit(hs, Response.length(body), P.limit(cfg)), P.body_mode(m), P.choice(accept), {==})
