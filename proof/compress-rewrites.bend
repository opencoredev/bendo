# BND-46: the header rewrites the compression shell applies. Every response
# that read Accept-Encoding gets it merged into Vary; a coded response names
# exactly its coding in Content-Encoding and carries no strong ETag; and a
# response that is not coded keeps the Content-Encoding it had.
import Base
import ../LAWS.bend as Laws
import ../src/mw/compress_policy.bend as P
import ../src/mw/vary.bend as Vary
import ../src/mw/response_fields.bend as Fields
import ../src/http/request.bend as Request
import ../src/http/response.bend as Response
import ../src/http/bytes.bend as Bytes
import ./compress-spec.bend as S
import ./compress.bend as CP
import ./response-policy-spec.bend as RS
import ./response-policy.bend as RP
import ./cors-vary.bend as CorsVary

def absurd(-A: Type, +e: Empty) -> A:
  match e:

# The fields drop_framing removes.
def dropped_names() -> List<&2, String>:
  ["content-length", "accept-ranges", "content-encoding"]

def coding_field(c: P.Coding) -> Request.Header:
  Request.Header{"content-encoding", Bytes.encode(P.coding_name(c))}

# ---------------------------------------------------------- field values

def pick_append(+v: List<&2, U32>, +r: List<&2, List<&2, U32>>, +b: List<&2, List<&2, U32>>, +e: Bool) -> {List.append(&2, List<&2, U32>, S.field_pick(v, r, e), b) == S.field_pick(v, List.append(&2, List<&2, U32>, r, b), e) : List<&2, List<&2, U32>>}:
  match e:
    case True{}: {==}
    case False{}: {==}

def values_append(+a: List<&2, Request.Header>, +b: List<&2, Request.Header>, +x: String) -> {S.field_values(List.append(&2, Request.Header, a, b), x) == List.append(&2, List<&2, U32>, S.field_values(a, x), S.field_values(b, x)) : List<&2, List<&2, U32>>}:
  match a:
    case Nil{}: {==}
    case Request.Header{+k, +v} <> +t:
      +e = String.eq(Bytes.fold(k), x)
      %Equal.sym(List<&2, List<&2, U32>>, List.append(&2, List<&2, U32>, S.field_pick(v, S.field_values(t, x), e), S.field_values(b, x)), S.field_pick(v, List.append(&2, List<&2, U32>, S.field_values(t, x), S.field_values(b, x)), e), pick_append(v, S.field_values(t, x), S.field_values(b, x), e)) : {S.field_values(List.append(&2, Request.Header, Request.Header{k, v} <> t, b), x) == _ : List<&2, List<&2, U32>>}
      Equal.cong(List<&2, List<&2, U32>>, List<&2, List<&2, U32>>, l => S.field_pick(v, l, e), S.field_values(List.append(&2, Request.Header, t, b), x), List.append(&2, List<&2, U32>, S.field_values(t, x), S.field_values(b, x)), values_append(t, b, x))

def vary_step(+v: List<&2, U32>, +r1: List<&2, List<&2, U32>>, +r2: List<&2, List<&2, U32>>, e: Bool, ih: {r1 == r2 : List<&2, List<&2, U32>>}) -> {RS.vary_pick(v, r1, e) == S.field_pick(v, r2, e) : List<&2, List<&2, U32>>}:
  match e:
    case True{}: Equal.cong(List<&2, List<&2, U32>>, List<&2, List<&2, U32>>, l => v <> l, r1, r2, ih)
    case False{}: ih

def vary_fields(+hs: List<&2, Request.Header>) -> {RS.vary_values(hs) == S.field_values(hs, "vary") : List<&2, List<&2, U32>>}:
  match hs:
    case Nil{}: {==}
    case Request.Header{+k, +v} <> +t: vary_step(v, RS.vary_values(t), S.field_values(t, "vary"), String.eq(Bytes.fold(k), "vary"), vary_fields(t))

def keep_pick(+k: String, +v: List<&2, U32>, +rest: List<&2, Request.Header>, +ns: List<&2, String>, +x: String, e1: Bool, e2: Bool, +h1: {RS.listed(Bytes.fold(k), ns) == e1 : Bool}, +h2: {String.eq(Bytes.fold(k), x) == e2 : Bool}, +hn: {RS.listed(x, ns) == False{} : Bool}, ih: {S.field_values(RS.unrelated(rest, ns), x) == S.field_values(rest, x) : List<&2, List<&2, U32>>}) -> {S.field_values(RS.kept(Request.Header{k, v}, RS.unrelated(rest, ns), e1), x) == S.field_pick(v, S.field_values(rest, x), e2) : List<&2, List<&2, U32>>}:
  match e1:
    case True{}:
      match e2:
        case True{}:
          same = Equal.cong(String, Bool, y => RS.listed(y, ns), Bytes.fold(k), x, Laws.string_eq_sound(Bytes.fold(k), x, h2))
          clash = Equal.trans(Bool, True{}, RS.listed(Bytes.fold(k), ns), False{}, Equal.sym(Bool, RS.listed(Bytes.fold(k), ns), True{}, h1), Equal.trans(Bool, RS.listed(Bytes.fold(k), ns), RS.listed(x, ns), False{}, same, hn))
          absurd({S.field_values(RS.unrelated(rest, ns), x) == S.field_pick(v, S.field_values(rest, x), True{}) : List<&2, List<&2, U32>>}, CP.false_true(Equal.sym(Bool, True{}, False{}, clash)))
        case False{}: ih
    case False{}:
      %h2 : {S.field_pick(v, S.field_values(RS.unrelated(rest, ns), x), String.eq(Bytes.fold(k), x)) == S.field_pick(v, S.field_values(rest, x), _) : List<&2, List<&2, U32>>}
      Equal.cong(List<&2, List<&2, U32>>, List<&2, List<&2, U32>>, l => S.field_pick(v, l, String.eq(Bytes.fold(k), x)), S.field_values(RS.unrelated(rest, ns), x), S.field_values(rest, x), ih)

# Removing other names keeps every value of x.
def values_kept(+hs: List<&2, Request.Header>, +ns: List<&2, String>, +x: String, +hn: {RS.listed(x, ns) == False{} : Bool}) -> {S.field_values(RS.unrelated(hs, ns), x) == S.field_values(hs, x) : List<&2, List<&2, U32>>}:
  match hs:
    case Nil{}: {==}
    case Request.Header{+k, +v} <> +t: keep_pick(k, v, t, ns, x, RS.listed(Bytes.fold(k), ns), String.eq(Bytes.fold(k), x), {==}, {==}, hn, values_kept(t, ns, x, hn))

def drop_pick(+k: String, +v: List<&2, U32>, +rest: List<&2, Request.Header>, +ns: List<&2, String>, +x: String, e1: Bool, e2: Bool, +h1: {RS.listed(Bytes.fold(k), ns) == e1 : Bool}, +h2: {String.eq(Bytes.fold(k), x) == e2 : Bool}, +hl: {RS.listed(x, ns) == True{} : Bool}, ih: {S.field_values(RS.unrelated(rest, ns), x) == [] : List<&2, List<&2, U32>>}) -> {S.field_values(RS.kept(Request.Header{k, v}, RS.unrelated(rest, ns), e1), x) == [] : List<&2, List<&2, U32>>}:
  match e1:
    case True{}: ih
    case False{}:
      match e2:
        case True{}:
          same = Equal.cong(String, Bool, y => RS.listed(y, ns), Bytes.fold(k), x, Laws.string_eq_sound(Bytes.fold(k), x, h2))
          clash = Equal.trans(Bool, False{}, RS.listed(Bytes.fold(k), ns), True{}, Equal.sym(Bool, RS.listed(Bytes.fold(k), ns), False{}, h1), Equal.trans(Bool, RS.listed(Bytes.fold(k), ns), RS.listed(x, ns), True{}, same, hl))
          absurd({S.field_values(RS.kept(Request.Header{k, v}, RS.unrelated(rest, ns), False{}), x) == [] : List<&2, List<&2, U32>>}, CP.false_true(clash))
        case False{}:
          %Equal.sym(Bool, String.eq(Bytes.fold(k), x), False{}, h2) : {S.field_pick(v, S.field_values(RS.unrelated(rest, ns), x), _) == [] : List<&2, List<&2, U32>>}
          ih

# Removing x leaves no value of x.
def values_dropped(+hs: List<&2, Request.Header>, +ns: List<&2, String>, +x: String, +hl: {RS.listed(x, ns) == True{} : Bool}) -> {S.field_values(RS.unrelated(hs, ns), x) == [] : List<&2, List<&2, U32>>}:
  match hs:
    case Nil{}: {==}
    case Request.Header{+k, +v} <> +t: drop_pick(k, v, t, ns, x, RS.listed(Bytes.fold(k), ns), String.eq(Bytes.fold(k), x), {==}, {==}, hl, values_dropped(t, ns, x, hl))

def weak_step(+n: String, +v: List<&2, U32>, +t: List<&2, Request.Header>, +x: String, e: Bool, +he: {String.eq(Bytes.fold(n), "etag") == e : Bool}, +hx: {String.eq("etag", x) == False{} : Bool}, ih: {S.field_values(P.weaken(t), x) == S.field_values(t, x) : List<&2, List<&2, U32>>}) -> {S.field_values(P.weak_named(n, v, e) <> P.weaken(t), x) == S.field_pick(v, S.field_values(t, x), String.eq(Bytes.fold(n), x)) : List<&2, List<&2, U32>>}:
  match e:
    case True{}:
      nx = Equal.trans(Bool, String.eq(Bytes.fold(n), x), String.eq("etag", x), False{}, Equal.cong(String, Bool, y => String.eq(y, x), Bytes.fold(n), "etag", Laws.string_eq_sound(Bytes.fold(n), "etag", he)), hx)
      %Equal.sym(Bool, String.eq(Bytes.fold(n), x), False{}, nx) : {S.field_pick(P.weak_value(v), S.field_values(P.weaken(t), x), _) == S.field_pick(v, S.field_values(t, x), _) : List<&2, List<&2, U32>>}
      ih
    case False{}: Equal.cong(List<&2, List<&2, U32>>, List<&2, List<&2, U32>>, l => S.field_pick(v, l, String.eq(Bytes.fold(n), x)), S.field_values(P.weaken(t), x), S.field_values(t, x), ih)

# Weakening ETags changes no other field.
def values_weaken(+hs: List<&2, Request.Header>, +x: String, +hx: {String.eq("etag", x) == False{} : Bool}) -> {S.field_values(P.weaken(hs), x) == S.field_values(hs, x) : List<&2, List<&2, U32>>}:
  match hs:
    case Nil{}: {==}
    case Request.Header{+n, +v} <> +t: weak_step(n, v, t, x, String.eq(Bytes.fold(n), "etag"), {==}, hx, values_weaken(t, x, hx))

def drop_unrelated(+hs: List<&2, Request.Header>) -> {P.drop_framing(hs) == RS.unrelated(hs, dropped_names()) : List<&2, Request.Header>}:
  +a = Fields.without(hs, "content-length")
  +b = Fields.without(a, "accept-ranges")
  +d = Fields.without(b, "content-encoding")
  Equal.trans(List<&2, Request.Header>, d, RS.unrelated(d, []), RS.unrelated(hs, dropped_names()), Equal.sym(List<&2, Request.Header>, RS.unrelated(d, []), d, RP.unrelated_nil(d)), Equal.trans(List<&2, Request.Header>, RS.unrelated(d, []), RS.unrelated(b, ["content-encoding"]), RS.unrelated(hs, dropped_names()), RP.without_then(b, "content-encoding", []), Equal.trans(List<&2, Request.Header>, RS.unrelated(b, ["content-encoding"]), RS.unrelated(a, ["accept-ranges", "content-encoding"]), RS.unrelated(hs, dropped_names()), RP.without_then(a, "accept-ranges", ["content-encoding"]), RP.without_then(hs, "content-length", ["accept-ranges", "content-encoding"]))))

def field_ce(+star: Bool, +values: List<&2, List<&2, U32>>, +added: List<&2, String>) -> {S.field_values(RS.vary_field(star, values, added), "content-encoding") == [] : List<&2, List<&2, U32>>}:
  match star:
    case True{}: {==}
    case False{}:
      match values:
        case Nil{}:
          match added:
            case Nil{}: {==}
            case a <> r: {==}
        case v <> r: {==}

def vary_field_of(+hs: List<&2, Request.Header>, +names: List<&2, String>) -> List<&2, Request.Header>:
  RS.vary_field(RS.member("*", RS.members(RS.vary_values(hs))), RS.vary_values(hs), RS.fresh(names, RS.members(RS.vary_values(hs))))

# Merging Vary changes no Content-Encoding.
def ce_vary_add(+hs: List<&2, Request.Header>, +names: List<&2, String>) -> {S.field_values(Vary.add(hs, names), "content-encoding") == S.field_values(hs, "content-encoding") : List<&2, List<&2, U32>>}:
  +u = RS.unrelated(hs, ["vary"])
  +f = vary_field_of(hs, names)
  %Equal.sym(List<&2, Request.Header>, Vary.add(hs, names), RS.vary_add(hs, names), RP.vary_add(hs, names)) : {S.field_values(_, "content-encoding") == S.field_values(hs, "content-encoding") : List<&2, List<&2, U32>>}
  %Equal.sym(List<&2, List<&2, U32>>, S.field_values(List.append(&2, Request.Header, u, f), "content-encoding"), List.append(&2, List<&2, U32>, S.field_values(u, "content-encoding"), S.field_values(f, "content-encoding")), values_append(u, f, "content-encoding")) : {_ == S.field_values(hs, "content-encoding") : List<&2, List<&2, U32>>}
  %Equal.sym(List<&2, List<&2, U32>>, S.field_values(f, "content-encoding"), [], field_ce(RS.member("*", RS.members(RS.vary_values(hs))), RS.vary_values(hs), RS.fresh(names, RS.members(RS.vary_values(hs))))) : {List.append(&2, List<&2, U32>, S.field_values(u, "content-encoding"), _) == S.field_values(hs, "content-encoding") : List<&2, List<&2, U32>>}
  Equal.trans(List<&2, List<&2, U32>>, List.append(&2, List<&2, U32>, S.field_values(u, "content-encoding"), []), S.field_values(u, "content-encoding"), S.field_values(hs, "content-encoding"), CorsVary.values_nil(S.field_values(u, "content-encoding")), values_kept(hs, ["vary"], "content-encoding", {==}))

# ------------------------------------------------------------------ ETags

def or_false_l(+a: Bool, +b: Bool, +h: {a || b == False{} : Bool}) -> {a == False{} : Bool}:
  match a:
    case True{}: absurd({True{} == False{} : Bool}, CP.false_true(Equal.sym(Bool, True{}, False{}, h)))
    case False{}: {==}

def or_false_r(+a: Bool, +b: Bool, +h: {a || b == False{} : Bool}) -> {b == False{} : Bool}:
  match a:
    case True{}: absurd({b == False{} : Bool}, CP.false_true(Equal.sym(Bool, True{}, False{}, h)))
    case False{}: h

def or_both(+a: Bool, +b: Bool, +ha: {a == False{} : Bool}, +hb: {b == False{} : Bool}) -> {a || b == False{} : Bool}:
  %Equal.sym(Bool, a, False{}, ha) : {_ || b == False{} : Bool}
  hb

def pick_rest(+v: List<&2, U32>, +r: Bool, e: Bool, +h: {S.strong_pick(v, r, e) == False{} : Bool}) -> {r == False{} : Bool}:
  match e:
    case True{}: or_false_r(S.strong(v), r, h)
    case False{}: h

def pick_keep(+v: List<&2, U32>, +r1: Bool, +r2: Bool, e: Bool, +h1: {S.strong_pick(v, r1, e) == False{} : Bool}, +h2: {r2 == False{} : Bool}) -> {S.strong_pick(v, r2, e) == False{} : Bool}:
  match e:
    case True{}: or_both(S.strong(v), r2, or_false_l(S.strong(v), r1, h1), h2)
    case False{}: h2

def strong_append(+a: List<&2, Request.Header>, +b: List<&2, Request.Header>, +ha: {S.strong_etag(a) == False{} : Bool}, +hb: {S.strong_etag(b) == False{} : Bool}) -> {S.strong_etag(List.append(&2, Request.Header, a, b)) == False{} : Bool}:
  match a:
    case Nil{}: hb
    case Request.Header{+k, +v} <> +t:
      +e = String.eq(Bytes.fold(k), "etag")
      pick_keep(v, S.strong_etag(t), S.strong_etag(List.append(&2, Request.Header, t, b)), e, ha, strong_append(t, b, pick_rest(v, S.strong_etag(t), e, ha), hb))

def kept_step(+k: String, +v: List<&2, U32>, +t: List<&2, Request.Header>, +u: List<&2, Request.Header>, d: Bool, +h: {S.strong_pick(v, S.strong_etag(t), String.eq(Bytes.fold(k), "etag")) == False{} : Bool}, +ih: {S.strong_etag(u) == False{} : Bool}) -> {S.strong_etag(RS.kept(Request.Header{k, v}, u, d)) == False{} : Bool}:
  match d:
    case True{}: ih
    case False{}: pick_keep(v, S.strong_etag(t), S.strong_etag(u), String.eq(Bytes.fold(k), "etag"), h, ih)

def strong_unrelated(+hs: List<&2, Request.Header>, +ns: List<&2, String>, +h: {S.strong_etag(hs) == False{} : Bool}) -> {S.strong_etag(RS.unrelated(hs, ns)) == False{} : Bool}:
  match hs:
    case Nil{}: {==}
    case Request.Header{+k, +v} <> +t: kept_step(k, v, t, RS.unrelated(t, ns), RS.listed(Bytes.fold(k), ns), h, strong_unrelated(t, ns, pick_rest(v, S.strong_etag(t), String.eq(Bytes.fold(k), "etag"), h)))

def weak_pick_strong(+c: U32, +t: List<&2, U32>, b: Bool, +hb: {U32.is_eq(c, 34) == b : Bool}) -> {S.strong(P.weak_pick(c, t, b)) == False{} : Bool}:
  match b:
    case True{}: {==}
    case False{}: hb

def weak_value_strong(+v: List<&2, U32>) -> {S.strong(P.weak_value(v)) == False{} : Bool}:
  match v:
    case Nil{}: {==}
    case +c <> +t: weak_pick_strong(c, t, U32.is_eq(c, 34), {==})

def weak_strong_step(+n: String, +v: List<&2, U32>, +t: List<&2, Request.Header>, e: Bool, +he: {String.eq(Bytes.fold(n), "etag") == e : Bool}, +ih: {S.strong_etag(P.weaken(t)) == False{} : Bool}) -> {S.strong_etag(P.weak_named(n, v, e) <> P.weaken(t)) == False{} : Bool}:
  match e:
    case True{}:
      %Equal.sym(Bool, String.eq(Bytes.fold(n), "etag"), True{}, he) : {S.strong_pick(P.weak_value(v), S.strong_etag(P.weaken(t)), _) == False{} : Bool}
      or_both(S.strong(P.weak_value(v)), S.strong_etag(P.weaken(t)), weak_value_strong(v), ih)
    case False{}:
      %Equal.sym(Bool, String.eq(Bytes.fold(n), "etag"), False{}, he) : {S.strong_pick(v, S.strong_etag(P.weaken(t)), _) == False{} : Bool}
      ih

# After weakening, no ETag field is strong.
def strong_weaken(+hs: List<&2, Request.Header>) -> {S.strong_etag(P.weaken(hs)) == False{} : Bool}:
  match hs:
    case Nil{}: {==}
    case Request.Header{+n, +v} <> +t: weak_strong_step(n, v, t, String.eq(Bytes.fold(n), "etag"), {==}, strong_weaken(t))

def field_strong(+star: Bool, +values: List<&2, List<&2, U32>>, +added: List<&2, String>) -> {S.strong_etag(RS.vary_field(star, values, added)) == False{} : Bool}:
  match star:
    case True{}: {==}
    case False{}:
      match values:
        case Nil{}:
          match added:
            case Nil{}: {==}
            case a <> r: {==}
        case v <> r: {==}

# Merging Vary adds no strong ETag.
def strong_vary_add(+hs: List<&2, Request.Header>, +names: List<&2, String>, +h: {S.strong_etag(hs) == False{} : Bool}) -> {S.strong_etag(Vary.add(hs, names)) == False{} : Bool}:
  %Equal.sym(List<&2, Request.Header>, Vary.add(hs, names), RS.vary_add(hs, names), RP.vary_add(hs, names)) : {S.strong_etag(_) == False{} : Bool}
  strong_append(RS.unrelated(hs, ["vary"]), vary_field_of(hs, names), strong_unrelated(hs, ["vary"], h), field_strong(RS.member("*", RS.members(RS.vary_values(hs))), RS.vary_values(hs), RS.fresh(names, RS.members(RS.vary_values(hs)))))

# ------------------------------------------------------------------- Vary

def vary_varied(+hs: List<&2, Request.Header>) -> {RS.vary_values(Vary.add(hs, ["Accept-Encoding"])) == RS.vary_result(RS.vary_values(hs), ["Accept-Encoding"]) : List<&2, List<&2, U32>>}:
  %Equal.sym(List<&2, Request.Header>, Vary.add(hs, ["Accept-Encoding"]), RS.vary_add(hs, ["Accept-Encoding"]), RP.vary_add(hs, ["Accept-Encoding"])) : {RS.vary_values(_) == RS.vary_result(RS.vary_values(hs), ["Accept-Encoding"]) : List<&2, List<&2, U32>>}
  CorsVary.result(hs, "Accept-Encoding", [])

def vary_after(+hs: List<&2, Request.Header>, +ws: List<&2, Request.Header>, +e: {RS.vary_values(ws) == RS.vary_values(hs) : List<&2, List<&2, U32>>}) -> {RS.vary_values(Vary.add(ws, ["Accept-Encoding"])) == RS.vary_result(RS.vary_values(hs), ["Accept-Encoding"]) : List<&2, List<&2, U32>>}:
  Equal.trans(List<&2, List<&2, U32>>, RS.vary_values(Vary.add(ws, ["Accept-Encoding"])), RS.vary_result(RS.vary_values(ws), ["Accept-Encoding"]), RS.vary_result(RS.vary_values(hs), ["Accept-Encoding"]), vary_varied(ws), Equal.cong(List<&2, List<&2, U32>>, List<&2, List<&2, U32>>, l => RS.vary_result(l, ["Accept-Encoding"]), RS.vary_values(ws), RS.vary_values(hs), e))

def vary_weaken(+hs: List<&2, Request.Header>) -> {RS.vary_values(P.weaken(hs)) == RS.vary_values(hs) : List<&2, List<&2, U32>>}:
  Equal.trans(List<&2, List<&2, U32>>, RS.vary_values(P.weaken(hs)), S.field_values(P.weaken(hs), "vary"), RS.vary_values(hs), vary_fields(P.weaken(hs)), Equal.trans(List<&2, List<&2, U32>>, S.field_values(P.weaken(hs), "vary"), S.field_values(hs, "vary"), RS.vary_values(hs), values_weaken(hs, "vary", {==}), Equal.sym(List<&2, List<&2, U32>>, RS.vary_values(hs), S.field_values(hs, "vary"), vary_fields(hs))))

def vary_drop(+hs: List<&2, Request.Header>) -> {RS.vary_values(P.drop_framing(hs)) == RS.vary_values(hs) : List<&2, List<&2, U32>>}:
  %Equal.sym(List<&2, Request.Header>, P.drop_framing(hs), RS.unrelated(hs, dropped_names()), drop_unrelated(hs)) : {RS.vary_values(_) == RS.vary_values(hs) : List<&2, List<&2, U32>>}
  CorsVary.kept(hs, dropped_names(), {==})

def vary_encoded(+hs: List<&2, Request.Header>, +c: P.Coding) -> {RS.vary_values(List.append(&2, Request.Header, Vary.add(P.weaken(P.drop_framing(hs)), ["Accept-Encoding"]), [coding_field(c)])) == RS.vary_result(RS.vary_values(hs), ["Accept-Encoding"]) : List<&2, List<&2, U32>>}:
  +w = P.weaken(P.drop_framing(hs))
  +a = Vary.add(w, ["Accept-Encoding"])
  %Equal.sym(List<&2, List<&2, U32>>, RS.vary_values(List.append(&2, Request.Header, a, [coding_field(c)])), List.append(&2, List<&2, U32>, RS.vary_values(a), RS.vary_values([coding_field(c)])), CorsVary.values_append(a, [coding_field(c)])) : {_ == RS.vary_result(RS.vary_values(hs), ["Accept-Encoding"]) : List<&2, List<&2, U32>>}
  %Equal.sym(List<&2, List<&2, U32>>, List.append(&2, List<&2, U32>, RS.vary_values(a), []), RS.vary_values(a), CorsVary.values_nil(RS.vary_values(a))) : {_ == RS.vary_result(RS.vary_values(hs), ["Accept-Encoding"]) : List<&2, List<&2, U32>>}
  vary_after(hs, w, Equal.trans(List<&2, List<&2, U32>>, RS.vary_values(w), RS.vary_values(P.drop_framing(hs)), RS.vary_values(hs), vary_weaken(P.drop_framing(hs)), vary_drop(hs)))

def smaller_vary(+s: U32, +hs: List<&2, Request.Header>, +b: List<&2, U32>, +rep: Maybe<&2, List<&2, U32>>, +c: P.Coding, +z: List<&2, U32>, sh: Bool) -> {RS.vary_values(RS.headers(P.smaller(Response.Res{s, hs, b, rep}, c, z, sh))) == RS.vary_result(RS.vary_values(hs), ["Accept-Encoding"]) : List<&2, List<&2, U32>>}:
  match sh:
    case True{}: vary_encoded(hs, c)
    case False{}: vary_varied(hs)

def coded_vary(+s: U32, +hs: List<&2, Request.Header>, +b: List<&2, U32>, +rep: Maybe<&2, List<&2, U32>>, +c: P.Coding, +out: Maybe<&2, List<&2, U32>>) -> {RS.vary_values(RS.headers(P.coded(Response.Res{s, hs, b, rep}, c, out))) == RS.vary_result(RS.vary_values(hs), ["Accept-Encoding"]) : List<&2, List<&2, U32>>}:
  match out:
    case None{}: vary_varied(hs)
    case Some{+z}: smaller_vary(s, hs, b, rep, c, z, Nat.is_lt(Response.length(z), Response.length(b)))

# Every plan but Keep merges Accept-Encoding into Vary.
def vary_merged(+res: Response.Res, +p: P.Plan, +out: Maybe<&2, List<&2, U32>>, +h: {P.is_keep(p) == False{} : Bool}) -> {RS.vary_values(RS.headers(P.respond(res, p, out))) == RS.vary_result(RS.vary_values(RS.headers(res)), ["Accept-Encoding"]) : List<&2, List<&2, U32>>}:
  match res:
    case Response.Res{+s, +hs, +b, +rep}:
      match p:
        case P.Keep{}: absurd({RS.vary_values(hs) == RS.vary_result(RS.vary_values(hs), ["Accept-Encoding"]) : List<&2, List<&2, U32>>}, CP.false_true(Equal.sym(Bool, True{}, False{}, h)))
        case P.Vary{}: vary_varied(hs)
        case P.Encode{+c}: coded_vary(s, hs, b, rep, c, out)
        case P.Measure{+c}: coded_vary(s, hs, b, rep, c, out)
        case P.Revalidated{c}: vary_after(hs, P.weaken(hs), vary_weaken(hs))

# ------------------------------------------------------- Content-Encoding

def ce_weak(+hs: List<&2, Request.Header>) -> {S.field_values(Vary.add(P.weaken(P.drop_framing(hs)), ["Accept-Encoding"]), "content-encoding") == [] : List<&2, List<&2, U32>>}:
  +d = P.drop_framing(hs)
  Equal.trans(List<&2, List<&2, U32>>, S.field_values(Vary.add(P.weaken(d), ["Accept-Encoding"]), "content-encoding"), S.field_values(P.weaken(d), "content-encoding"), [], ce_vary_add(P.weaken(d), ["Accept-Encoding"]), Equal.trans(List<&2, List<&2, U32>>, S.field_values(P.weaken(d), "content-encoding"), S.field_values(d, "content-encoding"), [], values_weaken(d, "content-encoding", {==}), Equal.trans(List<&2, List<&2, U32>>, S.field_values(d, "content-encoding"), S.field_values(RS.unrelated(hs, dropped_names()), "content-encoding"), [], Equal.cong(List<&2, Request.Header>, List<&2, List<&2, U32>>, l => S.field_values(l, "content-encoding"), d, RS.unrelated(hs, dropped_names()), drop_unrelated(hs)), values_dropped(hs, dropped_names(), "content-encoding", {==}))))

def name_token(+c: P.Coding) -> {[Bytes.encode(P.coding_name(c))] == [Bytes.encode(S.token(c))] : List<&2, List<&2, U32>>}:
  match c:
    case P.Gzip{}: {==}
    case P.Deflate{}: {==}

def ce_encoded(+hs: List<&2, Request.Header>, +c: P.Coding) -> {S.field_values(List.append(&2, Request.Header, Vary.add(P.weaken(P.drop_framing(hs)), ["Accept-Encoding"]), [coding_field(c)]), "content-encoding") == [Bytes.encode(S.token(c))] : List<&2, List<&2, U32>>}:
  +a = Vary.add(P.weaken(P.drop_framing(hs)), ["Accept-Encoding"])
  %Equal.sym(List<&2, List<&2, U32>>, S.field_values(List.append(&2, Request.Header, a, [coding_field(c)]), "content-encoding"), List.append(&2, List<&2, U32>, S.field_values(a, "content-encoding"), S.field_values([coding_field(c)], "content-encoding")), values_append(a, [coding_field(c)], "content-encoding")) : {_ == [Bytes.encode(S.token(c))] : List<&2, List<&2, U32>>}
  %Equal.sym(List<&2, List<&2, U32>>, S.field_values(a, "content-encoding"), [], ce_weak(hs)) : {List.append(&2, List<&2, U32>, _, S.field_values([coding_field(c)], "content-encoding")) == [Bytes.encode(S.token(c))] : List<&2, List<&2, U32>>}
  name_token(c)

def smaller_ce(+s: U32, +hs: List<&2, Request.Header>, +b: List<&2, U32>, +rep: Maybe<&2, List<&2, U32>>, +c: P.Coding, +z: List<&2, U32>, sh: Bool, +h: {sh == True{} : Bool}) -> {S.field_values(RS.headers(P.smaller(Response.Res{s, hs, b, rep}, c, z, sh)), "content-encoding") == [Bytes.encode(S.token(c))] : List<&2, List<&2, U32>>}:
  match sh:
    case True{}: ce_encoded(hs, c)
    case False{}: absurd({S.field_values(Vary.add(hs, ["Accept-Encoding"]), "content-encoding") == [Bytes.encode(S.token(c))] : List<&2, List<&2, U32>>}, CP.false_true(h))

def coded_ce(+s: U32, +hs: List<&2, Request.Header>, +b: List<&2, U32>, +rep: Maybe<&2, List<&2, U32>>, +c: P.Coding, +out: Maybe<&2, List<&2, U32>>, +h: {P.shrinks(Response.Res{s, hs, b, rep}, out) == True{} : Bool}) -> {S.field_values(RS.headers(P.coded(Response.Res{s, hs, b, rep}, c, out)), "content-encoding") == [Bytes.encode(S.token(c))] : List<&2, List<&2, U32>>}:
  match out:
    case None{}: absurd({S.field_values(Vary.add(hs, ["Accept-Encoding"]), "content-encoding") == [Bytes.encode(S.token(c))] : List<&2, List<&2, U32>>}, CP.false_true(h))
    case Some{+z}: smaller_ce(s, hs, b, rep, c, z, Nat.is_lt(Response.length(z), Response.length(b)), h)

def same_coding(+x: P.Coding, +c: P.Coding, +h: {Some{x} == Some{c} : Maybe<&2, P.Coding>}) -> {x == c : P.Coding}:
  Equal.cong(Maybe<&2, P.Coding>, P.Coding, CP.unwrap, Some{x}, Some{c}, h)

# A coded response names exactly its coding in Content-Encoding.
def coded_encoding(+res: Response.Res, +p: P.Plan, +c: P.Coding, +out: Maybe<&2, List<&2, U32>>, +hc: {P.coding(p) == Some{c} : Maybe<&2, P.Coding>}, +h: {P.shrinks(res, out) == True{} : Bool}) -> {S.field_values(RS.headers(P.respond(res, p, out)), "content-encoding") == [Bytes.encode(S.token(c))] : List<&2, List<&2, U32>>}:
  match res:
    case Response.Res{+s, +hs, +b, +rep}:
      match p:
        case P.Keep{}: absurd({S.field_values(hs, "content-encoding") == [Bytes.encode(S.token(c))] : List<&2, List<&2, U32>>}, CP.none_some(c, hc))
        case P.Vary{}: absurd({S.field_values(Vary.add(hs, ["Accept-Encoding"]), "content-encoding") == [Bytes.encode(S.token(c))] : List<&2, List<&2, U32>>}, CP.none_some(c, hc))
        case P.Encode{+x}:
          %Equal.sym(P.Coding, x, c, same_coding(x, c, hc)) : {S.field_values(RS.headers(P.coded(Response.Res{s, hs, b, rep}, _, out)), "content-encoding") == [Bytes.encode(S.token(c))] : List<&2, List<&2, U32>>}
          coded_ce(s, hs, b, rep, c, out, h)
        case P.Measure{+x}:
          %Equal.sym(P.Coding, x, c, same_coding(x, c, hc)) : {S.field_values(RS.headers(P.coded(Response.Res{s, hs, b, rep}, _, out)), "content-encoding") == [Bytes.encode(S.token(c))] : List<&2, List<&2, U32>>}
          coded_ce(s, hs, b, rep, c, out, h)
        case P.Revalidated{x}: absurd({S.field_values(Vary.add(P.weaken(hs), ["Accept-Encoding"]), "content-encoding") == [Bytes.encode(S.token(c))] : List<&2, List<&2, U32>>}, CP.none_some(c, hc))

def smaller_kept(+s: U32, +hs: List<&2, Request.Header>, +b: List<&2, U32>, +rep: Maybe<&2, List<&2, U32>>, +c: P.Coding, +z: List<&2, U32>, sh: Bool, +h: {sh == False{} : Bool}) -> {S.field_values(RS.headers(P.smaller(Response.Res{s, hs, b, rep}, c, z, sh)), "content-encoding") == S.field_values(hs, "content-encoding") : List<&2, List<&2, U32>>}:
  match sh:
    case True{}: absurd({S.field_values(List.append(&2, Request.Header, Vary.add(P.weaken(P.drop_framing(hs)), ["Accept-Encoding"]), [coding_field(c)]), "content-encoding") == S.field_values(hs, "content-encoding") : List<&2, List<&2, U32>>}, CP.false_true(Equal.sym(Bool, True{}, False{}, h)))
    case False{}: ce_vary_add(hs, ["Accept-Encoding"])

def coded_kept(+s: U32, +hs: List<&2, Request.Header>, +b: List<&2, U32>, +rep: Maybe<&2, List<&2, U32>>, +c: P.Coding, +out: Maybe<&2, List<&2, U32>>, +h: {P.shrinks(Response.Res{s, hs, b, rep}, out) == False{} : Bool}) -> {S.field_values(RS.headers(P.coded(Response.Res{s, hs, b, rep}, c, out)), "content-encoding") == S.field_values(hs, "content-encoding") : List<&2, List<&2, U32>>}:
  match out:
    case None{}: ce_vary_add(hs, ["Accept-Encoding"])
    case Some{+z}: smaller_kept(s, hs, b, rep, c, z, Nat.is_lt(Response.length(z), Response.length(b)), h)

# A response sent without a coded body keeps its Content-Encoding.
def identity_encoding(+res: Response.Res, +p: P.Plan, +out: Maybe<&2, List<&2, U32>>, +h: {P.shrinks(res, out) == False{} : Bool}) -> {S.field_values(RS.headers(P.respond(res, p, out)), "content-encoding") == S.field_values(RS.headers(res), "content-encoding") : List<&2, List<&2, U32>>}:
  match res:
    case Response.Res{+s, +hs, +b, +rep}:
      match p:
        case P.Keep{}: {==}
        case P.Vary{}: ce_vary_add(hs, ["Accept-Encoding"])
        case P.Encode{+c}: coded_kept(s, hs, b, rep, c, out, h)
        case P.Measure{+c}: coded_kept(s, hs, b, rep, c, out, h)
        case P.Revalidated{c}: Equal.trans(List<&2, List<&2, U32>>, S.field_values(Vary.add(P.weaken(hs), ["Accept-Encoding"]), "content-encoding"), S.field_values(P.weaken(hs), "content-encoding"), S.field_values(hs, "content-encoding"), ce_vary_add(P.weaken(hs), ["Accept-Encoding"]), values_weaken(hs, "content-encoding", {==}))

# ----------------------------------------------------------- weak ETags

def strong_encoded(+hs: List<&2, Request.Header>, +c: P.Coding) -> {S.strong_etag(List.append(&2, Request.Header, Vary.add(P.weaken(P.drop_framing(hs)), ["Accept-Encoding"]), [coding_field(c)])) == False{} : Bool}:
  strong_append(Vary.add(P.weaken(P.drop_framing(hs)), ["Accept-Encoding"]), [coding_field(c)], strong_vary_add(P.weaken(P.drop_framing(hs)), ["Accept-Encoding"], strong_weaken(P.drop_framing(hs))), {==})

def smaller_strong(+s: U32, +hs: List<&2, Request.Header>, +b: List<&2, U32>, +rep: Maybe<&2, List<&2, U32>>, +c: P.Coding, +z: List<&2, U32>, sh: Bool, +h: {sh == True{} : Bool}) -> {S.strong_etag(RS.headers(P.smaller(Response.Res{s, hs, b, rep}, c, z, sh))) == False{} : Bool}:
  match sh:
    case True{}: strong_encoded(hs, c)
    case False{}: absurd({S.strong_etag(Vary.add(hs, ["Accept-Encoding"])) == False{} : Bool}, CP.false_true(h))

def coded_strong(+s: U32, +hs: List<&2, Request.Header>, +b: List<&2, U32>, +rep: Maybe<&2, List<&2, U32>>, +c: P.Coding, +out: Maybe<&2, List<&2, U32>>, +h: {P.shrinks(Response.Res{s, hs, b, rep}, out) == True{} : Bool}) -> {S.strong_etag(RS.headers(P.coded(Response.Res{s, hs, b, rep}, c, out))) == False{} : Bool}:
  match out:
    case None{}: absurd({S.strong_etag(Vary.add(hs, ["Accept-Encoding"])) == False{} : Bool}, CP.false_true(h))
    case Some{+z}: smaller_strong(s, hs, b, rep, c, z, Nat.is_lt(Response.length(z), Response.length(b)), h)

# No strong ETag remains on a coded response.
def coded_weak(+res: Response.Res, +p: P.Plan, +c: P.Coding, +out: Maybe<&2, List<&2, U32>>, +hc: {P.coding(p) == Some{c} : Maybe<&2, P.Coding>}, +h: {P.shrinks(res, out) == True{} : Bool}) -> {S.strong_etag(RS.headers(P.respond(res, p, out))) == False{} : Bool}:
  match res:
    case Response.Res{+s, +hs, +b, +rep}:
      match p:
        case P.Keep{}: absurd({S.strong_etag(hs) == False{} : Bool}, CP.none_some(c, hc))
        case P.Vary{}: absurd({S.strong_etag(Vary.add(hs, ["Accept-Encoding"])) == False{} : Bool}, CP.none_some(c, hc))
        case P.Encode{+x}: coded_strong(s, hs, b, rep, x, out, h)
        case P.Measure{+x}: coded_strong(s, hs, b, rep, x, out, h)
        case P.Revalidated{x}: absurd({S.strong_etag(Vary.add(P.weaken(hs), ["Accept-Encoding"])) == False{} : Bool}, CP.none_some(c, hc))

# No strong ETag remains on a 304 whose 200 would be coded.
def revalidated_weak(+res: Response.Res, +c: P.Coding, +out: Maybe<&2, List<&2, U32>>) -> {S.strong_etag(RS.headers(P.respond(res, P.Revalidated{c}, out))) == False{} : Bool}:
  match res:
    case Response.Res{+s, +hs, +b, +rep}: strong_vary_add(P.weaken(hs), ["Accept-Encoding"], strong_weaken(hs))
