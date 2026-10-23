# BND-25: the headers an error response carries, for any accumulated headers,
# and the validity check against the independent admissibility predicate.
import Base
import ../src/app/context.bend as C
import ../src/http/request.bend as Request
import ../src/http/response.bend as Response
import ../src/http/bytes.bend as Bytes
import ./error-spec.bend as Spec

# Header admissibility: the framework's validity check is Spec.admissible.

def token_rest_spec(+s: String) -> {Bytes.token_tail(s) == Spec.token_rest(s) : Bool}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{+c}, t}: Equal.cong(Bool, Bool, x => Bytes.tchar(c) && x, Bytes.token_tail(t), Spec.token_rest(t), token_rest_spec(t))

def token_spec(+s: String) -> {Bytes.token(s) == Spec.token(s) : Bool}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{+c}, t}: Equal.cong(Bool, Bool, x => Bytes.tchar(c) && x, Bytes.token_tail(t), Spec.token_rest(t), token_rest_spec(t))

def octets_value_spec(+xs: List<&2, U32>) -> {Bytes.value(xs) == Spec.field_octets(xs) : Bool}:
  match xs:
    case Nil{}: {==}
    case +c <> t: Equal.cong(Bool, Bool, x => Bytes.value_octet(c) && x, Bytes.value(t), Spec.field_octets(t), octets_value_spec(t))

def first_spec(+xs: List<&2, U32>) -> {Request.value_start(xs) == Spec.first_clear(xs) : Bool}:
  match xs:
    case Nil{}: {==}
    case c <> t: {==}

def last_spec(+xs: List<&2, U32>, +acc: List<&2, U32>) -> {Request.value_start(List.reverse.go(&2, U32, xs, acc)) == Spec.last_clear(xs, Request.value_start(acc)) : Bool}:
  match xs:
    case Nil{}: {==}
    case +c <> t: last_spec(t, c <> acc)

def header_spec(+h: Request.Header) -> {Request.header_valid(h) == Spec.header_ok(h) : Bool}:
  match h:
    case Request.Header{+n, +v}:
      %Equal.sym(Bool, Bytes.token(n), Spec.token(n), token_spec(n)) : {_ && String.eq(n, Bytes.fold(n)) && Bytes.value(v) && Request.value_start(v) && Request.value_start(List.reverse(&2, U32, v)) == Spec.header_ok(Request.Header{n, v}) : Bool}
      %Equal.sym(Bool, Bytes.value(v), Spec.field_octets(v), octets_value_spec(v)) : {Spec.token(n) && String.eq(n, Bytes.fold(n)) && _ && Request.value_start(v) && Request.value_start(List.reverse(&2, U32, v)) == Spec.header_ok(Request.Header{n, v}) : Bool}
      %Equal.sym(Bool, Request.value_start(v), Spec.first_clear(v), first_spec(v)) : {Spec.token(n) && String.eq(n, Bytes.fold(n)) && Spec.field_octets(v) && _ && Request.value_start(List.reverse(&2, U32, v)) == Spec.header_ok(Request.Header{n, v}) : Bool}
      %Equal.sym(Bool, Request.value_start(List.reverse(&2, U32, v)), Spec.last_clear(v, True{}), last_spec(v, [])) : {Spec.token(n) && String.eq(n, Bytes.fold(n)) && Spec.field_octets(v) && Spec.first_clear(v) && _ == Spec.header_ok(Request.Header{n, v}) : Bool}
      {==}

def admissible_spec(+hs: List<&2, Request.Header>) -> {Request.headers_valid(hs) == Spec.admissible(hs) : Bool}:
  match hs:
    case Nil{}: {==}
    case +h <> t:
      %Equal.sym(Bool, Request.header_valid(h), Spec.header_ok(h), header_spec(h)) : {_ && Request.headers_valid(t) == Spec.header_ok(h) && Spec.admissible(t) : Bool}
      Equal.cong(Bool, Bool, x => Spec.header_ok(h) && x, Request.headers_valid(t), Spec.admissible(t), admissible_spec(t))

def octets_go_spec(+xs: List<&2, U32>, ok: Bool) -> {Response.octets_go(xs, ok) == ok && Spec.octets(xs) : Bool}:
  match xs ok:
    case Nil{} False{}: {==}
    case c <> t False{}: {==}
    case Nil{} True{}: {==}
    case +c <> t True{}: octets_go_spec(t, (c <= 255 : U32))

def octets_spec(+xs: List<&2, U32>) -> {Response.octets(xs) == Spec.octets(xs) : Bool}:
  octets_go_spec(xs, True{})

def witness_spec(w: Maybe<&2, List<&2, U32>>) -> {Response.representation_valid(w) == Spec.witness_ok(w) : Bool}:
  match w:
    case None{}: {==}
    case Some{xs}: octets_go_spec(xs, True{})

def valid_spec(+r: Response.Res) -> {Response.valid(r) == Spec.res_ok(r) : Bool}:
  match r:
    case Response.Res{+s, +hs, +b, +w}:
      %Equal.sym(Bool, Request.headers_valid(hs), Spec.admissible(hs), admissible_spec(hs)) : {(s >= 100 : U32) && (s <= 599 : U32) && _ && Response.octets(b) && Response.representation_valid(w) == Spec.res_ok(Response.Res{s, hs, b, w}) : Bool}
      %Equal.sym(Bool, Response.octets(b), Spec.octets(b), octets_spec(b)) : {(s >= 100 : U32) && (s <= 599 : U32) && Spec.admissible(hs) && _ && Response.representation_valid(w) == Spec.res_ok(Response.Res{s, hs, b, w}) : Bool}
      %Equal.sym(Bool, Response.representation_valid(w), Spec.witness_ok(w), witness_spec(w)) : {(s >= 100 : U32) && (s <= 599 : U32) && Spec.admissible(hs) && Spec.octets(b) && _ == Spec.res_ok(Response.Res{s, hs, b, w}) : Bool}
      {==}

def checked_pick(+r: Response.Res, b: Bool) -> {C.checked(r, b) == Spec.deliver_pick(r, b) : Response.Res}:
  match b:
    case True{}: {==}
    case False{}: {==}

# Finalization delivers exactly the responses Spec.res_ok admits.
def deliver_spec(+r: Response.Res) -> {C.finalize(r) == Spec.deliver(r) : Response.Res}:
  %Equal.sym(Bool, Response.valid(r), Spec.res_ok(r), valid_spec(r)) : {C.checked(r, _) == Spec.deliver(r) : Response.Res}
  checked_pick(r, Spec.res_ok(r))

def and_false(a: Bool) -> {a && False{} == False{} : Bool}:
  match a:
    case True{}: {==}
    case False{}: {==}

# An inadmissible header list is never delivered.
def deliver_bad(+s: U32, +hs: List<&2, Request.Header>, +b: List<&2, U32>, bad: {Spec.admissible(hs) == False{} : Bool}) -> {Spec.deliver(Response.Res{s, hs, b, None{}}) == Response.Res{500, [], [], None{}} : Response.Res}:
  %Equal.sym(Bool, Spec.admissible(hs), False{}, bad) : {Spec.deliver_pick(Response.Res{s, hs, b, None{}}, (s >= 100 : U32) && (s <= 599 : U32) && _ && Spec.octets(b) && Spec.witness_ok(None{})) == Response.Res{500, [], [], None{}} : Response.Res}
  %Equal.sym(Bool, (s >= 100 : U32) && (s <= 599 : U32) && False{}, False{}, and_false((s >= 100 : U32) && (s <= 599 : U32))) : {Spec.deliver_pick(Response.Res{s, hs, b, None{}}, _ && Spec.octets(b) && Spec.witness_ok(None{})) == Response.Res{500, [], [], None{}} : Response.Res}
  {==}

# The accumulated header list after the Vary merge and Content-Type replacement.

def keep_append(+h: Request.Header, +a: List<&2, Request.Header>, +b: List<&2, Request.Header>, +c: List<&2, Request.Header>, same: Bool, ih: {a == List.append(&2, Request.Header, b, c) : List<&2, Request.Header>}) -> {C.keep_header(h, a, same) == List.append(&2, Request.Header, C.keep_header(h, b, same), c) : List<&2, Request.Header>}:
  match same:
    case True{}: ih
    case False{}: Equal.cong(List<&2, Request.Header>, List<&2, Request.Header>, x => h <> x, a, List.append(&2, Request.Header, b, c), ih)

def without_append(+xs: List<&2, Request.Header>, +ys: List<&2, Request.Header>, +n: String) -> {C.without(List.append(&2, Request.Header, xs, ys), n) == List.append(&2, Request.Header, C.without(xs, n), C.without(ys, n)) : List<&2, Request.Header>}:
  match xs:
    case Nil{}: {==}
    case Request.Header{+k, +v} <> t:
      keep_append(Request.Header{k, v}, C.without(List.append(&2, Request.Header, t, ys), n), C.without(t, n), C.without(ys, n), String.eq(k, n), without_append(t, ys, n))

def kept_step(+k: String, +v: List<&2, U32>, +w: List<&2, Request.Header>, +kk: List<&2, Request.Header>, a: Bool, b: Bool, eb: {String.eq(k, "content-type") == b : Bool}, ih: {C.without(w, "content-type") == kk : List<&2, Request.Header>}) -> {C.without(C.keep_header(Request.Header{k, v}, w, a), "content-type") == Spec.keep_pick(Request.Header{k, v}, kk, b || a) : List<&2, Request.Header>}:
  match a b:
    case True{} True{}: ih
    case True{} False{}: ih
    case False{} True{}:
      %Equal.sym(Bool, String.eq(k, "content-type"), True{}, eb) : {C.keep_header(Request.Header{k, v}, C.without(w, "content-type"), _) == kk : List<&2, Request.Header>}
      ih
    case False{} False{}:
      %Equal.sym(Bool, String.eq(k, "content-type"), False{}, eb) : {C.keep_header(Request.Header{k, v}, C.without(w, "content-type"), _) == Request.Header{k, v} <> kk : List<&2, Request.Header>}
      Equal.cong(List<&2, Request.Header>, List<&2, Request.Header>, x => Request.Header{k, v} <> x, C.without(w, "content-type"), kk, ih)

def kept_spec(+hs: List<&2, Request.Header>) -> {C.without(C.without(hs, "vary"), "content-type") == Spec.kept(hs) : List<&2, Request.Header>}:
  match hs:
    case Nil{}: {==}
    case Request.Header{+k, +v} <> t:
      kept_step(k, v, C.without(t, "vary"), Spec.kept(t), String.eq(k, "vary"), String.eq(k, "content-type"), {==}, kept_spec(t))

def fields_step(+v: List<&2, U32>, +a: List<&2, List<&2, U32>>, +b: List<&2, List<&2, U32>>, same: Bool, ih: {a == b : List<&2, List<&2, U32>>}) -> {Request.lookup_step(v, a, same) == Spec.vary_pick(v, b, same) : List<&2, List<&2, U32>>}:
  match same:
    case True{}: Equal.cong(List<&2, List<&2, U32>>, List<&2, List<&2, U32>>, x => v <> x, a, b, ih)
    case False{}: ih

def fields_spec(+hs: List<&2, Request.Header>) -> {Request.lookup_folded(hs, "vary") == Spec.vary_fields(hs) : List<&2, List<&2, U32>>}:
  match hs:
    case Nil{}: {==}
    case Request.Header{+n, +v} <> t:
      fields_step(v, Request.lookup_folded(t, "vary"), Spec.vary_fields(t), String.eq(n, "vary"), fields_spec(t))

# The wildcard scan: Blank expects *, Star expects only whitespace, Other fails.
def after(st: C.Wild, ys: List<&2, U32>) -> Bool:
  match st:
    case C.Blank{}: Spec.only_star(ys)
    case C.Star{}: Spec.nil(ys)
    case C.Other{}: False{}

def wild_step(+c: U32, +r: List<&2, U32>, bl: Bool, star: Bool, st: C.Wild, es: {U32.is_eq(c, 42) == star : Bool}) -> {after(C.wild_char(bl, star, st), r) == after(st, Spec.drop_pick(c, r, bl)) : Bool}:
  match bl star st:
    case True{} True{} C.Blank{}: {==}
    case True{} True{} C.Star{}: {==}
    case True{} True{} C.Other{}: {==}
    case True{} False{} C.Blank{}: {==}
    case True{} False{} C.Star{}: {==}
    case True{} False{} C.Other{}: {==}
    case False{} True{} C.Blank{}:
      %Equal.sym(Bool, U32.is_eq(c, 42), True{}, es) : {Spec.nil(r) == _ && Spec.nil(r) : Bool}
      {==}
    case False{} True{} C.Star{}: {==}
    case False{} True{} C.Other{}: {==}
    case False{} False{} C.Blank{}:
      %Equal.sym(Bool, U32.is_eq(c, 42), False{}, es) : {False{} == _ && Spec.nil(r) : Bool}
      {==}
    case False{} False{} C.Star{}: {==}
    case False{} False{} C.Other{}: {==}

def wild_spec(+xs: List<&2, U32>, +st: C.Wild) -> {C.wild_end(C.wild_go(xs, st)) == after(st, Spec.unblank(xs)) : Bool}:
  match xs:
    case Nil{}:
      match st:
        case C.Blank{}: {==}
        case C.Star{}: {==}
        case C.Other{}: {==}
    case +c <> t:
      Equal.trans(Bool, C.wild_end(C.wild_go(t, C.wild_char(Bytes.ows(c), U32.is_eq(c, 42), st))), after(C.wild_char(Bytes.ows(c), U32.is_eq(c, 42), st), Spec.unblank(t)), after(st, Spec.drop_pick(c, Spec.unblank(t), Bytes.ows(c))), wild_spec(t, C.wild_char(Bytes.ows(c), U32.is_eq(c, 42), st)), wild_step(c, Spec.unblank(t), Bytes.ows(c), U32.is_eq(c, 42), st, {==}))

def star_spec(+vs: List<&2, List<&2, U32>>) -> {C.vary_star(vs) == Spec.any_wildcard(vs) : Bool}:
  match vs:
    case Nil{}: {==}
    case +v <> t:
      %Equal.sym(Bool, C.vary_wild(v), Spec.wildcard(v), wild_spec(v, C.Blank{})) : {_ || C.vary_star(t) == Spec.any_wildcard(v <> t) : Bool}
      Equal.cong(Bool, Bool, x => Spec.wildcard(v) || x, C.vary_star(t), Spec.any_wildcard(t), star_spec(t))

def join_cons(+v: List<&2, U32>, +t: List<&2, List<&2, U32>>, ih: {C.vary_join(t) == Spec.separated(List.append(&2, List<&2, U32>, t, [Bytes.encode("Accept")])) : List<&2, U32>}) -> {C.vary_join(v <> t) == Spec.separated(List.append(&2, List<&2, U32>, v <> t, [Bytes.encode("Accept")])) : List<&2, U32>}:
  match t:
    case Nil{}: {==}
    case +w <> u:
      Equal.cong(List<&2, U32>, List<&2, U32>, x => List.append(&2, U32, v, List.append(&2, U32, Bytes.encode(", "), x)), C.vary_join(w <> u), Spec.separated(w <> List.append(&2, List<&2, U32>, u, [Bytes.encode("Accept")])), ih)

def join_spec(+vs: List<&2, List<&2, U32>>) -> {C.vary_join(vs) == Spec.separated(List.append(&2, List<&2, U32>, vs, [Bytes.encode("Accept")])) : List<&2, U32>}:
  match vs:
    case Nil{}: {==}
    case +v <> t: join_cons(v, t, join_spec(t))

def value_pick(+vs: List<&2, List<&2, U32>>, star: Bool) -> {C.vary_value(vs, star) == Spec.merged_pick(vs, star) : List<&2, U32>}:
  match star:
    case True{}: {==}
    case False{}: join_spec(vs)

def merged_spec(+vs: List<&2, List<&2, U32>>) -> {C.vary_value(vs, C.vary_star(vs)) == Spec.merged_vary(vs) : List<&2, U32>}:
  %Equal.sym(Bool, C.vary_star(vs), Spec.any_wildcard(vs), star_spec(vs)) : {C.vary_value(vs, _) == Spec.merged_vary(vs) : List<&2, U32>}
  value_pick(vs, Spec.any_wildcard(vs))

def vary_header(+hs: List<&2, Request.Header>) -> Request.Header:
  Request.Header{"vary", C.vary_value(Request.lookup(hs, "vary"), C.vary_star(Request.lookup(hs, "vary")))}

def vary_spec(+hs: List<&2, Request.Header>) -> {C.vary_value(Request.lookup(hs, "vary"), C.vary_star(Request.lookup(hs, "vary"))) == Spec.merged_vary(Spec.vary_fields(hs)) : List<&2, U32>}:
  Equal.trans(List<&2, U32>, C.vary_value(Request.lookup(hs, "vary"), C.vary_star(Request.lookup(hs, "vary"))), Spec.merged_vary(Request.lookup(hs, "vary")), Spec.merged_vary(Spec.vary_fields(hs)), merged_spec(Request.lookup(hs, "vary")), Equal.cong(List<&2, List<&2, U32>>, List<&2, U32>, x => Spec.merged_vary(x), Request.lookup(hs, "vary"), Spec.vary_fields(hs), fields_spec(hs)))

def tail_spec(+hs: List<&2, Request.Header>) -> {C.without(List.append(&2, Request.Header, C.without(hs, "vary"), [vary_header(hs)]), "content-type") == List.append(&2, Request.Header, Spec.kept(hs), [Request.Header{"vary", Spec.merged_vary(Spec.vary_fields(hs))}]) : List<&2, Request.Header>}:
  %Equal.sym(List<&2, Request.Header>, C.without(List.append(&2, Request.Header, C.without(hs, "vary"), [vary_header(hs)]), "content-type"), List.append(&2, Request.Header, C.without(C.without(hs, "vary"), "content-type"), C.without([vary_header(hs)], "content-type")), without_append(C.without(hs, "vary"), [vary_header(hs)], "content-type")) : {_ == List.append(&2, Request.Header, Spec.kept(hs), [Request.Header{"vary", Spec.merged_vary(Spec.vary_fields(hs))}]) : List<&2, Request.Header>}
  %Equal.sym(List<&2, Request.Header>, C.without(C.without(hs, "vary"), "content-type"), Spec.kept(hs), kept_spec(hs)) : {List.append(&2, Request.Header, _, C.without([vary_header(hs)], "content-type")) == List.append(&2, Request.Header, Spec.kept(hs), [Request.Header{"vary", Spec.merged_vary(Spec.vary_fields(hs))}]) : List<&2, Request.Header>}
  Equal.cong(List<&2, U32>, List<&2, Request.Header>, x => List.append(&2, Request.Header, Spec.kept(hs), [Request.Header{"vary", x}]), C.vary_value(Request.lookup(hs, "vary"), C.vary_star(Request.lookup(hs, "vary"))), Spec.merged_vary(Spec.vary_fields(hs)), vary_spec(hs))

def headers_json(+hs: List<&2, Request.Header>) -> {C.type_headers(List.append(&2, Request.Header, C.without(hs, "vary"), [vary_header(hs)]), Some{"application/json; charset=utf-8"}) == Spec.headers(True{}, hs) : List<&2, Request.Header>}:
  Equal.cong(List<&2, Request.Header>, List<&2, Request.Header>, x => Spec.content_type(True{}) <> x, C.without(List.append(&2, Request.Header, C.without(hs, "vary"), [vary_header(hs)]), "content-type"), List.append(&2, Request.Header, Spec.kept(hs), [Request.Header{"vary", Spec.merged_vary(Spec.vary_fields(hs))}]), tail_spec(hs))

def headers_text(+hs: List<&2, Request.Header>) -> {C.type_headers(List.append(&2, Request.Header, C.without(hs, "vary"), [vary_header(hs)]), Some{"text/plain; charset=utf-8"}) == Spec.headers(False{}, hs) : List<&2, Request.Header>}:
  Equal.cong(List<&2, Request.Header>, List<&2, Request.Header>, x => Spec.content_type(False{}) <> x, C.without(List.append(&2, Request.Header, C.without(hs, "vary"), [vary_header(hs)]), "content-type"), List.append(&2, Request.Header, Spec.kept(hs), [Request.Header{"vary", Spec.merged_vary(Spec.vary_fields(hs))}]), tail_spec(hs))
