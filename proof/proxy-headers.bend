# BND-47: the proxy's hop-by-hop filter meets its independent specification.
import Base
import ../src/http/request.bend as Request
import ../src/http/bytes.bend as Bytes
import ../src/http/proxy_headers.bend as Hop
import ./proxy-headers-spec.bend as Spec

def named_member(+s: String, xs: List<&2, String>) -> {Hop.named(s, xs) == Spec.member(s, xs) : Bool}:
  match xs:
    case Nil{}: {==}
    case +x <> +rest: Equal.cong(Bool, Bool, r => String.eq(s, x) || r, Hop.named(s, rest), Spec.member(s, rest), named_member(s, rest))

def ascii_text(xs: List<&2, U32>) -> {Bytes.ascii(xs) == Spec.text(xs) : String}:
  match xs:
    case Nil{}: {==}
    case +c <> +t: Equal.cong(String, String, s => SCon{Chr{c}, s}, Bytes.ascii(t), Spec.text(t), ascii_text(t))

def push_same(+c: U32, ps: List<&2, List<&2, U32>>) -> {Hop.comma_push(c, ps) == Spec.onto_first(c, ps) : List<&2, List<&2, U32>>}:
  match ps:
    case Nil{}: {==}
    case p <> t: {==}

def pick_same(+c: U32, comma: Bool, +ps: List<&2, List<&2, U32>>) -> {Hop.comma_pick(c, ps, comma) == Spec.at_comma(c, ps, comma) : List<&2, List<&2, U32>>}:
  match comma:
    case True{}: {==}
    case False{}: push_same(c, ps)

def commas_pieces(xs: List<&2, U32>) -> {Hop.commas(xs) == Spec.pieces(xs) : List<&2, List<&2, U32>>}:
  match xs:
    case Nil{}: {==}
    case +c <> +t:
      Equal.trans(List<&2, List<&2, U32>>, Hop.comma_pick(c, Hop.commas(t), U32.is_eq(c, 44)), Hop.comma_pick(c, Spec.pieces(t), U32.is_eq(c, 44)), Spec.at_comma(c, Spec.pieces(t), U32.is_eq(c, 44)), Equal.cong(List<&2, List<&2, U32>>, List<&2, List<&2, U32>>, ps => Hop.comma_pick(c, ps, U32.is_eq(c, 44)), Hop.commas(t), Spec.pieces(t), commas_pieces(t)), pick_same(c, U32.is_eq(c, 44), Spec.pieces(t)))

def lead_same(+c: U32, +t: List<&2, U32>, +r: List<&2, U32>, space: Bool) -> {Hop.lead_pick(c, t, r, space) == Spec.after_space(c, t, r, space) : List<&2, U32>}:
  match space:
    case True{}: {==}
    case False{}: {==}

def lead_drop(xs: List<&2, U32>) -> {Hop.strip_lead(xs) == Spec.drop_leading(xs) : List<&2, U32>}:
  match xs:
    case Nil{}: {==}
    case +c <> +t:
      Equal.trans(List<&2, U32>, Hop.lead_pick(c, t, Hop.strip_lead(t), Hop.blank(c)), Hop.lead_pick(c, t, Spec.drop_leading(t), Hop.blank(c)), Spec.after_space(c, t, Spec.drop_leading(t), Spec.space(c)), Equal.cong(List<&2, U32>, List<&2, U32>, r => Hop.lead_pick(c, t, r, Hop.blank(c)), Hop.strip_lead(t), Spec.drop_leading(t), lead_drop(t)), lead_same(c, t, Spec.drop_leading(t), Hop.blank(c)))

# A blank octet before a cut point is cut too; before a kept one it stays.
def trail_cut(+c: U32, +d: U32, cut: Bool, +r: List<&2, U32>) -> {Hop.trail_pick(c, True{}, Spec.cut_if(d, cut, r)) == Spec.cut_if(c, cut, Spec.cut_if(d, cut, r)) : List<&2, U32>}:
  match cut:
    case True{}: {==}
    case False{}: {==}

def trail_blank(+c: U32, xs: List<&2, U32>) -> {Hop.trail_pick(c, True{}, Spec.drop_trailing(xs)) == Spec.cut_if(c, Spec.blank(xs), Spec.drop_trailing(xs)) : List<&2, U32>}:
  match xs:
    case Nil{}: {==}
    case +d <> +u: trail_cut(c, d, Spec.space(d) && Spec.blank(u), Spec.drop_trailing(u))

def trail_same(+c: U32, space: Bool, +t: List<&2, U32>) -> {Hop.trail_pick(c, space, Spec.drop_trailing(t)) == Spec.cut_if(c, space && Spec.blank(t), Spec.drop_trailing(t)) : List<&2, U32>}:
  match space:
    case True{}: trail_blank(c, t)
    case False{}: {==}

def trail_drop(xs: List<&2, U32>) -> {Hop.strip_trail(xs) == Spec.drop_trailing(xs) : List<&2, U32>}:
  match xs:
    case Nil{}: {==}
    case +c <> +t:
      Equal.trans(List<&2, U32>, Hop.trail_pick(c, Hop.blank(c), Hop.strip_trail(t)), Hop.trail_pick(c, Hop.blank(c), Spec.drop_trailing(t)), Spec.cut_if(c, Spec.space(c) && Spec.blank(t), Spec.drop_trailing(t)), Equal.cong(List<&2, U32>, List<&2, U32>, r => Hop.trail_pick(c, Hop.blank(c), r), Hop.strip_trail(t), Spec.drop_trailing(t), trail_drop(t)), trail_same(c, Hop.blank(c), t))

def trim_same(+p: List<&2, U32>) -> {Hop.strip_trail(Hop.strip_lead(p)) == Spec.drop_trailing(Spec.drop_leading(p)) : List<&2, U32>}:
  Equal.trans(List<&2, U32>, Hop.strip_trail(Hop.strip_lead(p)), Hop.strip_trail(Spec.drop_leading(p)), Spec.drop_trailing(Spec.drop_leading(p)), Equal.cong(List<&2, U32>, List<&2, U32>, r => Hop.strip_trail(r), Hop.strip_lead(p), Spec.drop_leading(p), lead_drop(p)), trail_drop(Spec.drop_leading(p)))

def name_same(+p: List<&2, U32>) -> {Bytes.fold(Bytes.ascii(Hop.strip_trail(Hop.strip_lead(p)))) == Spec.lower(Spec.text(Spec.drop_trailing(Spec.drop_leading(p)))) : String}:
  Equal.trans(String, Bytes.fold(Bytes.ascii(Hop.strip_trail(Hop.strip_lead(p)))), Bytes.fold(Bytes.ascii(Spec.drop_trailing(Spec.drop_leading(p)))), Spec.lower(Spec.text(Spec.drop_trailing(Spec.drop_leading(p)))), Equal.cong(List<&2, U32>, String, r => Bytes.fold(Bytes.ascii(r)), Hop.strip_trail(Hop.strip_lead(p)), Spec.drop_trailing(Spec.drop_leading(p)), trim_same(p)), Equal.cong(String, String, s => String.to_lower(s), Bytes.ascii(Spec.drop_trailing(Spec.drop_leading(p))), Spec.text(Spec.drop_trailing(Spec.drop_leading(p))), ascii_text(Spec.drop_trailing(Spec.drop_leading(p)))))

def cons_same(+h1: String, +h2: String, +t1: List<&2, String>, +t2: List<&2, String>, eh: {h1 == h2 : String}, et: {t1 == t2 : List<&2, String>}) -> {h1 <> t1 == h2 <> t2 : List<&2, String>}:
  Equal.trans(List<&2, String>, h1 <> t1, h2 <> t1, h2 <> t2, Equal.cong(String, List<&2, String>, h => h <> t1, h1, h2, eh), Equal.cong(List<&2, String>, List<&2, String>, t => h2 <> t, t1, t2, et))

def append_same(+a1: List<&2, String>, +a2: List<&2, String>, +b1: List<&2, String>, +b2: List<&2, String>, ea: {a1 == a2 : List<&2, String>}, eb: {b1 == b2 : List<&2, String>}) -> {List.append(&2, String, a1, b1) == List.append(&2, String, a2, b2) : List<&2, String>}:
  Equal.trans(List<&2, String>, List.append(&2, String, a1, b1), List.append(&2, String, a2, b1), List.append(&2, String, a2, b2), Equal.cong(List<&2, String>, List<&2, String>, a => List.append(&2, String, a, b1), a1, a2, ea), Equal.cong(List<&2, String>, List<&2, String>, b => List.append(&2, String, a2, b), b1, b2, eb))

def pick_option(+n: String, +r: List<&2, String>, empty: Bool) -> {Hop.name_pick(n, r, empty) == Spec.option_if(n, r, empty) : List<&2, String>}:
  match empty:
    case True{}: {==}
    case False{}: {==}

def names_options(ps: List<&2, List<&2, U32>>) -> {Hop.token_names(ps) == Spec.options(ps) : List<&2, String>}:
  match ps:
    case Nil{}: {==}
    case +p <> +t:
      +n1 = Bytes.fold(Bytes.ascii(Hop.strip_trail(Hop.strip_lead(p))))
      +n2 = Spec.lower(Spec.text(Spec.drop_trailing(Spec.drop_leading(p))))
      Equal.trans(List<&2, String>, Hop.name_pick(n1, Hop.token_names(t), String.is_empty(n1)), Hop.name_pick(n2, Hop.token_names(t), String.is_empty(n2)), Spec.option_if(n2, Spec.options(t), String.is_empty(n2)), Equal.cong(String, List<&2, String>, n => Hop.name_pick(n, Hop.token_names(t), String.is_empty(n)), n1, n2, name_same(p)), Equal.trans(List<&2, String>, Hop.name_pick(n2, Hop.token_names(t), String.is_empty(n2)), Hop.name_pick(n2, Spec.options(t), String.is_empty(n2)), Spec.option_if(n2, Spec.options(t), String.is_empty(n2)), Equal.cong(List<&2, String>, List<&2, String>, r => Hop.name_pick(n2, r, String.is_empty(n2)), Hop.token_names(t), Spec.options(t), names_options(t)), pick_option(n2, Spec.options(t), String.is_empty(n2))))

def value_options(+v: List<&2, U32>) -> {Hop.token_names(Hop.commas(v)) == Spec.options(Spec.pieces(v)) : List<&2, String>}:
  Equal.trans(List<&2, String>, Hop.token_names(Hop.commas(v)), Hop.token_names(Spec.pieces(v)), Spec.options(Spec.pieces(v)), Equal.cong(List<&2, List<&2, U32>>, List<&2, String>, ps => Hop.token_names(ps), Hop.commas(v), Spec.pieces(v), commas_pieces(v)), names_options(Spec.pieces(v)))

def field_same(+v: List<&2, U32>, +r1: List<&2, String>, +r2: List<&2, String>, er: {r1 == r2 : List<&2, String>}, connection: Bool) -> {Hop.listed_pick(v, r1, connection) == Spec.field_options(v, r2, connection) : List<&2, String>}:
  match connection:
    case True{}: append_same(Hop.token_names(Hop.commas(v)), Spec.options(Spec.pieces(v)), r1, r2, value_options(v), er)
    case False{}: er

def listed_same(hs: List<&2, Request.Header>) -> {Hop.listed(hs) == Spec.listed(hs) : List<&2, String>}:
  match hs:
    case Nil{}: {==}
    case Request.Header{+name, +value} <> +t: field_same(value, Hop.listed(t), Spec.listed(t), listed_same(t), String.eq(Bytes.fold(name), "connection"))

def and_same(+a1: Bool, +a2: Bool, +b1: Bool, +b2: Bool, ea: {a1 == a2 : Bool}, eb: {b1 == b2 : Bool}) -> {(Bool.not(a1) && Bool.not(b1)) == (Bool.not(a2) && Bool.not(b2)) : Bool}:
  Equal.trans(Bool, Bool.not(a1) && Bool.not(b1), Bool.not(a2) && Bool.not(b1), Bool.not(a2) && Bool.not(b2), Equal.cong(Bool, Bool, a => Bool.not(a) && Bool.not(b1), a1, a2, ea), Equal.cong(Bool, Bool, b => Bool.not(a2) && Bool.not(b), b1, b2, eb))

def keep_clean(+tokens: List<&2, String>, h: Request.Header) -> {Hop.keep(tokens, h) == Spec.clean(tokens, h) : Bool}:
  match h:
    case Request.Header{+name, value}:
      and_same(Hop.named(Bytes.fold(name), Hop.hop_names()), Spec.member(Spec.lower(name), Spec.hop_by_hop()), Hop.named(Bytes.fold(name), tokens), Spec.member(Spec.lower(name), tokens), named_member(Bytes.fold(name), Hop.hop_names()), named_member(Bytes.fold(name), tokens))

def header_cons(+h: Request.Header, +r1: List<&2, Request.Header>, +r2: List<&2, Request.Header>, er: {r1 == r2 : List<&2, Request.Header>}, kept: Bool) -> {Hop.keep_pick(h, r1, kept) == Spec.keep_if(h, r2, kept) : List<&2, Request.Header>}:
  match kept:
    case True{}: Equal.cong(List<&2, Request.Header>, List<&2, Request.Header>, r => h <> r, r1, r2, er)
    case False{}: er

def keep_all_same(+tokens: List<&2, String>, hs: List<&2, Request.Header>) -> {Hop.keep_all(tokens, hs) == Spec.keep_clean(tokens, hs) : List<&2, Request.Header>}:
  match hs:
    case Nil{}: {==}
    case +h <> +t:
      Equal.trans(List<&2, Request.Header>, Hop.keep_pick(h, Hop.keep_all(tokens, t), Hop.keep(tokens, h)), Hop.keep_pick(h, Hop.keep_all(tokens, t), Spec.clean(tokens, h)), Spec.keep_if(h, Spec.keep_clean(tokens, t), Spec.clean(tokens, h)), Equal.cong(Bool, List<&2, Request.Header>, b => Hop.keep_pick(h, Hop.keep_all(tokens, t), b), Hop.keep(tokens, h), Spec.clean(tokens, h), keep_clean(tokens, h)), header_cons(h, Hop.keep_all(tokens, t), Spec.keep_clean(tokens, t), keep_all_same(tokens, t), Spec.clean(tokens, h)))

def forward_spec(+hs: List<&2, Request.Header>) -> {Hop.forward(hs) == Spec.forward(hs) : List<&2, Request.Header>}:
  Equal.trans(List<&2, Request.Header>, Hop.keep_all(Hop.listed(hs), hs), Hop.keep_all(Spec.listed(hs), hs), Spec.keep_clean(Spec.listed(hs), hs), Equal.cong(List<&2, String>, List<&2, Request.Header>, t => Hop.keep_all(t, hs), Hop.listed(hs), Spec.listed(hs), listed_same(hs)), keep_all_same(Spec.listed(hs), hs))

def kept_clean(+tokens: List<&2, String>, +h: Request.Header, +r: List<&2, Request.Header>, ok: Bool, e: {Spec.clean(tokens, h) == ok : Bool}, ih: {Spec.all_clean(tokens, r) == True{} : Bool}) -> {Spec.all_clean(tokens, Spec.keep_if(h, r, ok)) == True{} : Bool}:
  match ok:
    case True{}:
      %Equal.sym(Bool, Spec.clean(tokens, h), True{}, e) : {_ && Spec.all_clean(tokens, r) == True{} : Bool}
      ih
    case False{}: ih

def clean_all(+tokens: List<&2, String>, hs: List<&2, Request.Header>) -> {Spec.all_clean(tokens, Spec.keep_clean(tokens, hs)) == True{} : Bool}:
  match hs:
    case Nil{}: {==}
    case +h <> +t: kept_clean(tokens, h, Spec.keep_clean(tokens, t), Spec.clean(tokens, h), {==}, clean_all(tokens, t))

def forward_clean(+hs: List<&2, Request.Header>) -> {Spec.all_clean(Spec.listed(hs), Hop.forward(hs)) == True{} : Bool}:
  %Equal.sym(List<&2, Request.Header>, Hop.forward(hs), Spec.forward(hs), forward_spec(hs)) : {Spec.all_clean(Spec.listed(hs), _) == True{} : Bool}
  clean_all(Spec.listed(hs), hs)
