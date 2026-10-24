# BND-93: the upstream authority parser (src/http/upstream.bend) meets
# proof/upstream-host-spec.bend, and the Host value sent upstream reads back
# as the endpoint it came from.
#
# The parser and the specification differ in two ways: their predicates for
# labels, ports and embedded IPv4 are written differently, and the parser
# cuts at the first ']' or ':' where the specification splits at every one.
# A mirror below keeps the parser's cuts over the specification's
# predicates, so the proof goes parser == mirror (predicate lemmas) and
# mirror == specification (cut against split). The read-back law is proved
# over the mirror.
import Base
import ../src/http/origin.bend as O
import ../src/http/upstream.bend as U
import ./origin-spec.bend as S
import ./origin.bend as OP
import ./text.bend as TP
import ./utf8.bend as UP
import ./json-credit.bend as JC
import ./upstream-host-spec.bend as US

# ---- Small facts ----

def and_false(x: Bool) -> {x && False{} == False{} : Bool}:
  match x:
    case True{}: {==}
    case False{}: {==}

def or_false(x: Bool) -> {x || False{} == x : Bool}:
  match x:
    case True{}: {==}
    case False{}: {==}

def not_same(+a: Bool, +b: Bool, e: {a == b : Bool}) -> {Bool.not(a) == Bool.not(b) : Bool}:
  Equal.cong(Bool, Bool, x => Bool.not(x), a, b, e)

def char_sound(+c: Char, +d: Char, +e: {Char.is_eq(c, d) == True{} : Bool}) -> {c == d : Char}:
  match c d:
    case Chr{+x} Chr{+y}: Equal.cong(U32, Char, z => Chr{z}, x, y, JC.u32_eq_sound(x, y, e))

# ---- Labels ----

def if_head(+t: String, b: Bool) -> {String.starts_with.go.if("", t, b) == b : Bool}:
  match b:
    case True{}: {==}
    case False{}: {==}

def last_hyphen(t: String, +c: Char, +acc: String) -> {String.starts_with.go("-", String.reverse.go(t, SCon{c, acc})) == Char.is_eq(US.last_of(t, c), '-') : Bool}:
  match t:
    case SNil{}: if_head(acc, Char.is_eq(c, '-'))
    case SCon{+d, +u}: last_hyphen(u, d, SCon{c, acc})

def label_same(l: String) -> {U.label_ok(l) == US.label(l) : Bool}:
  match l:
    case SNil{}: {==}
    case SCon{+c, +t}:
      OP.and_same(Nat.is_le(String.length(t), 62n) && Bool.not(String.starts_with(SCon{c, t}, "-")), Nat.is_le(String.length(t), 62n) && US.not_hyphen(c), Bool.not(String.ends_with(SCon{c, t}, "-")), US.not_hyphen(US.last_of(t, c)),
        OP.and_same(Nat.is_le(String.length(t), 62n), Nat.is_le(String.length(t), 62n), Bool.not(String.starts_with(SCon{c, t}, "-")), US.not_hyphen(c), {==}, not_same(String.starts_with(SCon{c, t}, "-"), Char.is_eq(c, '-'), if_head(t, Char.is_eq(c, '-')))),
        not_same(String.ends_with(SCon{c, t}, "-"), Char.is_eq(US.last_of(t, c), '-'), last_hyphen(t, c, "")))

def labels_same(ls: List<&2, String>) -> {U.labels_ok(ls) == US.every_label(ls) : Bool}:
  match ls:
    case Nil{}: {==}
    case +l <> +t: OP.and_same(U.label_ok(l), US.label(l), U.labels_ok(t), US.every_label(t), label_same(l), labels_same(t))

def name_same(+h: String) -> {U.name_ok(h) == US.name(h) : Bool}:
  OP.and_same(O.name_host(h), S.name_host(h), U.labels_ok(String.split(h, '.')), US.every_label(String.split(h, '.')), OP.name_host_same(h), labels_same(String.split(h, '.')))

# ---- Ports ----

def nonempty_same(p: String) -> {Nat.is_lt(0n, String.length(p)) == Bool.not(String.is_empty(p)) : Bool}:
  match p:
    case SNil{}: {==}
    case SCon{c, t}: {==}

def range_same(n: Maybe<&2, Nat>) -> {U.port_range(n) == US.in_range(n) : Bool}:
  match n:
    case None{}: {==}
    case Some{v}:
      match v:
        case 0n: {==}
        case 1n+k:
          match k:
            case 0n: {==}
            case 1n+j: {==}

def read_same(+p: String, short: Bool) -> {U.port_read(p, short) == short && US.in_range(Nat.read(p)) : Bool}:
  match short:
    case True{}: range_same(Nat.read(p))
    case False{}: {==}

def port_same(+p: String) -> {U.port_ok(p) == US.port(p) : Bool}:
  +short = (S.decimals(p) && Bool.not(String.is_empty(p))) && Nat.is_le(String.length(p), 5n)
  Equal.trans(Bool, U.port_read(p, (O.digits(p) && Nat.is_lt(0n, String.length(p))) && Nat.is_le(String.length(p), 5n)), U.port_read(p, short), US.port(p),
    Equal.cong(Bool, Bool, x => U.port_read(p, x), (O.digits(p) && Nat.is_lt(0n, String.length(p))) && Nat.is_le(String.length(p), 5n), short,
      OP.and_same(O.digits(p) && Nat.is_lt(0n, String.length(p)), S.decimals(p) && Bool.not(String.is_empty(p)), Nat.is_le(String.length(p), 5n), Nat.is_le(String.length(p), 5n),
        OP.and_same(O.digits(p), S.decimals(p), Nat.is_lt(0n, String.length(p)), Bool.not(String.is_empty(p)), OP.digits_same(p), nonempty_same(p)), {==})),
    read_same(p, short))

# ---- IPv4 inside IPv6 ----

def groups_same(gs: List<&2, String>) -> {U.v4_groups(gs) == US.mapped_or_compatible(gs) : Bool}:
  match gs:
    case Nil{}: {==}
    case g <> Nil{}: {==}
    case g <> (h <> Nil{}): {==}
    case f <> (g <> (h <> Nil{})): Equal.sym(Bool, String.eq(f, "ffff") || False{}, String.eq(f, "ffff"), or_false(String.eq(f, "ffff")))
    case f <> (g <> (h <> (i <> rest))): {==}

def push_none(+c: Char, l: List<&2, String>) -> {U.v4_pieces(String.split.push(c, l)) == False{} : Bool}:
  match l:
    case Nil{}: {==}
    case x <> r: {==}

def second_none(+c: Char, l: List<&2, String>) -> {U.v4_pieces(SNil{} <> String.split.push(c, l)) == False{} : Bool}:
  match l:
    case Nil{}: {==}
    case x <> r: {==}

def prepend_none(+c: Char, m: Maybe<&2, S.Split>) -> {US.embedding(S.split_prepend(c, m)) == False{} : Bool}:
  match m:
    case None{}: {==}
    case Some{S.Split{a, b}}: {==}

def after_double(w: String) -> {U.v4_groups(String.split(w, ':')) == US.mapped_or_compatible(S.group_list(w)) : Bool}:
  match w:
    case SNil{}: {==}
    case SCon{+x, +y}: groups_same(String.split(SCon{x, y}, ':'))

def second_colon(+c: Char, +d: Char, +w: String, k: Bool) -> {U.v4_pieces(SNil{} <> String.split.fin(d, String.split(w, ':'), k)) == US.embedding(S.double_pick(c, SCon{d, w}, S.split_double(SCon{d, w}), k)) : Bool}:
  match k:
    case True{}: after_double(w)
    case False{}: Equal.trans(Bool, U.v4_pieces(SNil{} <> String.split.push(d, String.split(w, ':'))), False{}, US.embedding(S.split_prepend(c, S.split_double(SCon{d, w}))), second_none(d, String.split(w, ':')), Equal.sym(Bool, US.embedding(S.split_prepend(c, S.split_double(SCon{d, w}))), False{}, prepend_none(c, S.split_double(SCon{d, w}))))

def first_colon(+c: Char, u: String) -> {U.v4_pieces(SNil{} <> String.split(u, ':')) == US.embedding(S.double_pick(c, u, S.split_double(u), S.next_colon(u))) : Bool}:
  match u:
    case SNil{}: {==}
    case SCon{+d, +w}: second_colon(c, d, w, Char.is_eq(d, ':'))

def embeds_at(+c: Char, +u: String, k: Bool) -> {U.v4_pieces(String.split.fin(c, String.split(u, ':'), k)) == US.embedding(S.double_pick(c, u, S.split_double(u), k && S.next_colon(u))) : Bool}:
  match k:
    case True{}: first_colon(c, u)
    case False{}: Equal.trans(Bool, U.v4_pieces(String.split.push(c, String.split(u, ':'))), False{}, US.embedding(S.split_prepend(c, S.split_double(u))), push_none(c, String.split(u, ':')), Equal.sym(Bool, US.embedding(S.split_prepend(c, S.split_double(u))), False{}, prepend_none(c, S.split_double(u))))

def embeds_same(t: String) -> {U.embeds_v4(t) == US.embeds_v4(t) : Bool}:
  match t:
    case SNil{}: {==}
    case SCon{+c, +u}: embeds_at(c, u, Char.is_eq(c, ':'))

def v6_same(+t: String) -> {U.v6_ok(t) == US.v6(t) : Bool}:
  OP.and_same(O.ipv6(t), S.ipv6(t), Bool.not(U.embeds_v4(t)), Bool.not(US.embeds_v4(t)), OP.ipv6_same(t), not_same(U.embeds_v4(t), US.embeds_v4(t), embeds_same(t)))

# ---- The mirror: the parser's cuts over the specification's predicates ----

def m_v6(parts: Maybe<&2, S.Split>) -> Maybe<&2, U.Endpoint>:
  match parts:
    case None{}: None{}
    case Some{S.Split{inside, rest}}: US.v6_rest(inside, rest)

def m_named(+whole: String, parts: Maybe<&2, S.Split>) -> Maybe<&2, U.Endpoint>:
  match parts:
    case None{}: US.made(U.HostName{whole}, None{}, US.name(whole))
    case Some{S.Split{+h, +p}}: US.made(U.HostName{h}, Some{p}, US.name(h) && US.port(p))

def m_at(+c: Char, +t: String, bracket: Bool) -> Maybe<&2, U.Endpoint>:
  match bracket:
    case True{}: m_v6(S.split_at(t, ']'))
    case False{}: m_named(SCon{c, t}, S.split_at(SCon{c, t}, ':'))

def m_authority(s: String) -> Maybe<&2, U.Endpoint>:
  match s:
    case SNil{}: None{}
    case SCon{+c, +t}: m_at(c, t, Char.is_eq(c, '['))

# ---- The parser equals the mirror ----

def made_eq(+h: U.Host, +p: Maybe<&2, String>, a: Bool) -> {U.endpoint(h, p, a) == US.made(h, p, a) : Maybe<&2, U.Endpoint>}:
  match a:
    case True{}: {==}
    case False{}: {==}

def leaf(+h: U.Host, +p: Maybe<&2, String>, +a: Bool, +b: Bool, e: {a == b : Bool}) -> {U.endpoint(h, p, a) == US.made(h, p, b) : Maybe<&2, U.Endpoint>}:
  Equal.trans(Maybe<&2, U.Endpoint>, U.endpoint(h, p, a), US.made(h, p, a), US.made(h, p, b), made_eq(h, p, a), Equal.cong(Bool, Maybe<&2, U.Endpoint>, x => US.made(h, p, x), a, b, e))

def bracket_port_same(+inside: String, +p: String, colon: Bool) -> {U.bracket_port(inside, p, colon) == US.v6_port(inside, p, colon) : Maybe<&2, U.Endpoint>}:
  match colon:
    case True{}: leaf(U.HostV6{inside}, Some{p}, U.v6_ok(inside) && U.port_ok(p), US.v6(inside) && US.port(p), OP.and_same(U.v6_ok(inside), US.v6(inside), U.port_ok(p), US.port(p), v6_same(inside), port_same(p)))
    case False{}: {==}

def bracket_rest_same(+inside: String, rest: String) -> {U.bracket_rest(inside, rest) == US.v6_rest(inside, rest) : Maybe<&2, U.Endpoint>}:
  match rest:
    case SNil{}: leaf(U.HostV6{inside}, None{}, U.v6_ok(inside), US.v6(inside), v6_same(inside))
    case SCon{+c, +p}: bracket_port_same(inside, p, Char.is_eq(c, ':'))

def bracketed_same(m: Maybe<&2, O.Cut>) -> {U.bracketed(m) == m_v6(OP.to_split(m)) : Maybe<&2, U.Endpoint>}:
  match m:
    case None{}: {==}
    case Some{O.Cut{+inside, +rest}}: bracket_rest_same(inside, rest)

def named_same(+whole: String, m: Maybe<&2, O.Cut>) -> {U.named_parts(whole, m) == m_named(whole, OP.to_split(m)) : Maybe<&2, U.Endpoint>}:
  match m:
    case None{}: leaf(U.HostName{whole}, None{}, U.name_ok(whole), US.name(whole), name_same(whole))
    case Some{O.Cut{+h, +p}}: leaf(U.HostName{h}, Some{p}, U.name_ok(h) && U.port_ok(p), US.name(h) && US.port(p), OP.and_same(U.name_ok(h), US.name(h), U.port_ok(p), US.port(p), name_same(h), port_same(p)))

def at_mirror(+c: Char, +t: String, bracket: Bool) -> {U.endpoint_at(c, t, bracket) == m_at(c, t, bracket) : Maybe<&2, U.Endpoint>}:
  match bracket:
    case True{}:
      Equal.trans(Maybe<&2, U.Endpoint>, U.bracketed(O.cut(t, ']')), m_v6(OP.to_split(O.cut(t, ']'))), m_v6(S.split_at(t, ']')), bracketed_same(O.cut(t, ']')),
        Equal.cong(Maybe<&2, S.Split>, Maybe<&2, U.Endpoint>, m => m_v6(m), OP.to_split(O.cut(t, ']')), S.split_at(t, ']'), OP.cut_same(t, ']')))
    case False{}:
      Equal.trans(Maybe<&2, U.Endpoint>, U.named_parts(SCon{c, t}, O.cut(SCon{c, t}, ':')), m_named(SCon{c, t}, OP.to_split(O.cut(SCon{c, t}, ':'))), m_named(SCon{c, t}, S.split_at(SCon{c, t}, ':')), named_same(SCon{c, t}, O.cut(SCon{c, t}, ':')),
        Equal.cong(Maybe<&2, S.Split>, Maybe<&2, U.Endpoint>, m => m_named(SCon{c, t}, m), OP.to_split(O.cut(SCon{c, t}, ':')), S.split_at(SCon{c, t}, ':'), OP.cut_same(SCon{c, t}, ':')))

def mirror_same(s: String) -> {U.read_authority(s) == m_authority(s) : Maybe<&2, U.Endpoint>}:
  match s:
    case SNil{}: {==}
    case SCon{+c, +t}: at_mirror(c, t, Char.is_eq(c, '['))

# ---- Splitting at every separator, seen through the first cut ----

# The pieces of s at every sep, given the cut of s at its first sep.
def pieces(m: Maybe<&2, S.Split>, +s: String, +sep: Char) -> List<&2, String>:
  match m:
    case None{}: [s]
    case Some{S.Split{a, b}}: a <> String.split(b, sep)

def push_pieces(+c: Char, m: Maybe<&2, S.Split>, +t: String, +sep: Char) -> {String.split.push(c, pieces(m, t, sep)) == pieces(S.split_prepend(c, m), SCon{c, t}, sep) : List<&2, String>}:
  match m:
    case None{}: {==}
    case Some{S.Split{a, b}}: {==}

def view_at(+c: Char, +t: String, +sep: Char, k: Bool, ih: {String.split(t, sep) == pieces(S.split_at(t, sep), t, sep) : List<&2, String>}) -> {String.split.fin(c, String.split(t, sep), k) == pieces(S.split_pick(c, t, S.split_at(t, sep), k), SCon{c, t}, sep) : List<&2, String>}:
  match k:
    case True{}: {==}
    case False{}:
      Equal.trans(List<&2, String>, String.split.push(c, String.split(t, sep)), String.split.push(c, pieces(S.split_at(t, sep), t, sep)), pieces(S.split_prepend(c, S.split_at(t, sep)), SCon{c, t}, sep),
        Equal.cong(List<&2, String>, List<&2, String>, l => String.split.push(c, l), String.split(t, sep), pieces(S.split_at(t, sep), t, sep), ih),
        push_pieces(c, S.split_at(t, sep), t, sep))

def split_view(s: String, +sep: Char) -> {String.split(s, sep) == pieces(S.split_at(s, sep), s, sep) : List<&2, String>}:
  match s:
    case SNil{}: {==}
    case SCon{+c, +t}: view_at(c, t, sep, Char.is_eq(c, sep), split_view(t, sep))

def found(m: Maybe<&2, S.Split>) -> Bool:
  match m:
    case None{}: False{}
    case Some{x}: True{}

def found_prepend(+c: Char, m: Maybe<&2, S.Split>) -> {found(S.split_prepend(c, m)) == found(m) : Bool}:
  match m:
    case None{}: {==}
    case Some{S.Split{a, b}}: {==}

def digits_tail(+c: Char, +t: String, +sep: Char, f: Bool, ef: {found(S.split_at(t, sep)) == f : Bool}, ih: {found(S.split_at(t, sep)) && S.decimals(t) == False{} : Bool}) -> {f && (S.decimal(c) && S.decimals(t)) == False{} : Bool}:
  match f:
    case False{}: {==}
    case True{}:
      +rest = Equal.trans(Bool, True{} && S.decimals(t), found(S.split_at(t, sep)) && S.decimals(t), False{}, Equal.cong(Bool, Bool, x => x && S.decimals(t), True{}, found(S.split_at(t, sep)), Equal.sym(Bool, found(S.split_at(t, sep)), True{}, ef)), ih)
      Equal.trans(Bool, S.decimal(c) && S.decimals(t), S.decimal(c) && False{}, False{}, Equal.cong(Bool, Bool, x => S.decimal(c) && x, S.decimals(t), False{}, rest), and_false(S.decimal(c)))

def cut_digits_at(+c: Char, +t: String, +sep: Char, nd: {S.decimal(sep) == False{} : Bool}, k: Bool, ek: {Char.is_eq(c, sep) == k : Bool}, ih: {found(S.split_at(t, sep)) && S.decimals(t) == False{} : Bool}) -> {found(S.split_pick(c, t, S.split_at(t, sep), k)) && (S.decimal(c) && S.decimals(t)) == False{} : Bool}:
  match k:
    case True{}:
      +dc = Equal.trans(Bool, S.decimal(c), S.decimal(sep), False{}, Equal.cong(Char, Bool, x => S.decimal(x), c, sep, char_sound(c, sep, ek)), nd)
      Equal.cong(Bool, Bool, x => x && S.decimals(t), S.decimal(c), False{}, dc)
    case False{}:
      Equal.trans(Bool, found(S.split_prepend(c, S.split_at(t, sep))) && (S.decimal(c) && S.decimals(t)), found(S.split_at(t, sep)) && (S.decimal(c) && S.decimals(t)), False{},
        Equal.cong(Bool, Bool, x => x && (S.decimal(c) && S.decimals(t)), found(S.split_prepend(c, S.split_at(t, sep))), found(S.split_at(t, sep)), found_prepend(c, S.split_at(t, sep))),
        digits_tail(c, t, sep, found(S.split_at(t, sep)), {==}, ih))

# Text with a separator that is not a digit is not all digits.
def cut_digits(p: String, +sep: Char, +nd: {S.decimal(sep) == False{} : Bool}) -> {found(S.split_at(p, sep)) && S.decimals(p) == False{} : Bool}:
  match p:
    case SNil{}: {==}
    case SCon{+c, +t}: cut_digits_at(c, t, sep, nd, Char.is_eq(c, sep), {==}, cut_digits(t, sep, nd))

def port_off(+r: String, d: {S.decimals(r) == False{} : Bool}) -> {US.port(r) == False{} : Bool}:
  Equal.cong(Bool, Bool, x => ((x && Bool.not(String.is_empty(r))) && Nat.is_le(String.length(r), 5n)) && US.in_range(Nat.read(r)), S.decimals(r), False{}, d)

# A port cut at a later separator is no port.
def cut_port(+r: String, +sep: Char, +x: String, +y: String, nd: {S.decimal(sep) == False{} : Bool}, em: {S.split_at(r, sep) == Some{S.Split{x, y}} : Maybe<&2, S.Split>}) -> {US.port(r) == False{} : Bool}:
  port_off(r, Equal.trans(Bool, True{} && S.decimals(r), found(S.split_at(r, sep)) && S.decimals(r), False{},
    Equal.cong(Maybe<&2, S.Split>, Bool, m => found(m) && S.decimals(r), Some{S.Split{x, y}}, S.split_at(r, sep), Equal.sym(Maybe<&2, S.Split>, S.split_at(r, sep), Some{S.Split{x, y}}, em)),
    cut_digits(r, sep, nd)))

def without_port(+host: U.Host, +r: String, +a: Bool, po: {US.port(r) == False{} : Bool}) -> {US.made(host, Some{r}, a && US.port(r)) == None{} : Maybe<&2, U.Endpoint>}:
  Equal.cong(Bool, Maybe<&2, U.Endpoint>, b => US.made(host, Some{r}, b), a && US.port(r), False{}, Equal.trans(Bool, a && US.port(r), a && False{}, False{}, Equal.cong(Bool, Bool, x => a && x, US.port(r), False{}, po), and_false(a)))

# A third piece ends both readings.
def bracket_push(+inside: String, +rest: String, +c: Char, l: List<&2, String>) -> {US.bracket_end(inside, rest, String.split.push(c, l)) == None{} : Maybe<&2, U.Endpoint>}:
  match l:
    case Nil{}: {==}
    case x <> r: {==}

def bracket_fin(+inside: String, +rest: String, +c: Char, +t: String, +sep: Char, k: Bool) -> {US.bracket_end(inside, rest, String.split.fin(c, String.split(t, sep), k)) == None{} : Maybe<&2, U.Endpoint>}:
  match k:
    case True{}: {==}
    case False{}: bracket_push(inside, rest, c, String.split(t, sep))

def bracket_end_none(+inside: String, +rest: String, p: String, +sep: Char) -> {US.bracket_end(inside, rest, String.split(p, sep)) == None{} : Maybe<&2, U.Endpoint>}:
  match p:
    case SNil{}: {==}
    case SCon{+c, +t}: bracket_fin(inside, rest, c, t, sep, Char.is_eq(c, sep))

def named_push(+h: String, +q: String, +c: Char, l: List<&2, String>) -> {US.named_end(h, q, String.split.push(c, l)) == None{} : Maybe<&2, U.Endpoint>}:
  match l:
    case Nil{}: {==}
    case x <> r: {==}

def named_fin(+h: String, +q: String, +c: Char, +t: String, +sep: Char, k: Bool) -> {US.named_end(h, q, String.split.fin(c, String.split(t, sep), k)) == None{} : Maybe<&2, U.Endpoint>}:
  match k:
    case True{}: {==}
    case False{}: named_push(h, q, c, String.split(t, sep))

def named_end_none(+h: String, +q: String, p: String, +sep: Char) -> {US.named_end(h, q, String.split(p, sep)) == None{} : Maybe<&2, U.Endpoint>}:
  match p:
    case SNil{}: {==}
    case SCon{+c, +t}: named_fin(h, q, c, t, sep, Char.is_eq(c, sep))

# ---- The mirror equals the specification ----

def no_colon_tail(+inside: String, +c: Char, e1: {Char.is_eq(c, ':') == False{} : Bool}, l: List<&2, String>) -> {US.bracket_tail(inside, String.split.push(c, l)) == None{} : Maybe<&2, U.Endpoint>}:
  match l:
    case Nil{}: Equal.cong(Bool, Maybe<&2, U.Endpoint>, b => US.v6_port(inside, "", b), Char.is_eq(c, ':'), False{}, e1)
    case +x <> r:
      match r:
        case Nil{}: Equal.cong(Bool, Maybe<&2, U.Endpoint>, b => US.v6_port(inside, x, b), Char.is_eq(c, ':'), False{}, e1)
        case y <> z: {==}

def colon_cut(+inside: String, +c: Char, +p: String, e1: {Char.is_eq(c, ':') == True{} : Bool}, m: Maybe<&2, S.Split>, em: {S.split_at(p, ']') == m : Maybe<&2, S.Split>}) -> {US.bracket_tail(inside, String.split.push(c, pieces(m, p, ']'))) == US.made(U.HostV6{inside}, Some{p}, US.v6(inside) && US.port(p)) : Maybe<&2, U.Endpoint>}:
  match m:
    case None{}: Equal.cong(Bool, Maybe<&2, U.Endpoint>, b => US.v6_port(inside, p, b), Char.is_eq(c, ':'), True{}, e1)
    case Some{S.Split{+x, +y}}:
      Equal.trans(Maybe<&2, U.Endpoint>, US.bracket_end(inside, SCon{c, x}, String.split(y, ']')), None{}, US.made(U.HostV6{inside}, Some{p}, US.v6(inside) && US.port(p)),
        bracket_end_none(inside, SCon{c, x}, y, ']'),
        Equal.sym(Maybe<&2, U.Endpoint>, US.made(U.HostV6{inside}, Some{p}, US.v6(inside) && US.port(p)), None{}, without_port(U.HostV6{inside}, p, US.v6(inside), cut_port(p, ']', x, y, {==}, em))))

def rest_at(+inside: String, +c: Char, +p: String, k2: Bool, e2: {Char.is_eq(c, ']') == k2 : Bool}, k1: Bool, e1: {Char.is_eq(c, ':') == k1 : Bool}) -> {US.bracket_tail(inside, String.split.fin(c, String.split(p, ']'), k2)) == US.v6_port(inside, p, k1) : Maybe<&2, U.Endpoint>}:
  match k2 k1:
    case True{} True{}:
      +bad = Equal.trans(Bool, Char.is_eq(']', ':'), Char.is_eq(c, ':'), True{}, Equal.cong(Char, Bool, x => Char.is_eq(x, ':'), ']', c, Equal.sym(Char, c, ']', char_sound(c, ']', e2))), e1)
      UP.absurd({US.bracket_tail(inside, String.split.fin(c, String.split(p, ']'), True{})) == US.v6_port(inside, p, True{}) : Maybe<&2, U.Endpoint>}, UP.false_true(bad))
    case True{} False{}: bracket_end_none(inside, "", p, ']')
    case False{} False{}: no_colon_tail(inside, c, e1, String.split(p, ']'))
    case False{} True{}:
      Equal.trans(Maybe<&2, U.Endpoint>, US.bracket_tail(inside, String.split.push(c, String.split(p, ']'))), US.bracket_tail(inside, String.split.push(c, pieces(S.split_at(p, ']'), p, ']'))), US.v6_port(inside, p, True{}),
        Equal.cong(List<&2, String>, Maybe<&2, U.Endpoint>, l => US.bracket_tail(inside, String.split.push(c, l)), String.split(p, ']'), pieces(S.split_at(p, ']'), p, ']'), split_view(p, ']')),
        colon_cut(inside, c, p, e1, S.split_at(p, ']'), {==}))

def after_bracket(+inside: String, rest: String) -> {US.bracket_tail(inside, String.split(rest, ']')) == US.v6_rest(inside, rest) : Maybe<&2, U.Endpoint>}:
  match rest:
    case SNil{}: {==}
    case SCon{+c, +p}: rest_at(inside, c, p, Char.is_eq(c, ']'), {==}, Char.is_eq(c, ':'), {==})

def bracket_view(m: Maybe<&2, S.Split>, +t: String) -> {m_v6(m) == US.bracketed(pieces(m, t, ']')) : Maybe<&2, U.Endpoint>}:
  match m:
    case None{}: {==}
    case Some{S.Split{+inside, +rest}}: Equal.sym(Maybe<&2, U.Endpoint>, US.bracket_tail(inside, String.split(rest, ']')), US.v6_rest(inside, rest), after_bracket(inside, rest))

def named_cut(+h: String, +r: String, m: Maybe<&2, S.Split>, em: {S.split_at(r, ':') == m : Maybe<&2, S.Split>}) -> {US.named_tail(h, pieces(m, r, ':')) == US.made(U.HostName{h}, Some{r}, US.name(h) && US.port(r)) : Maybe<&2, U.Endpoint>}:
  match m:
    case None{}: {==}
    case Some{S.Split{+x, +y}}:
      Equal.trans(Maybe<&2, U.Endpoint>, US.named_end(h, x, String.split(y, ':')), None{}, US.made(U.HostName{h}, Some{r}, US.name(h) && US.port(r)),
        named_end_none(h, x, y, ':'),
        Equal.sym(Maybe<&2, U.Endpoint>, US.made(U.HostName{h}, Some{r}, US.name(h) && US.port(r)), None{}, without_port(U.HostName{h}, r, US.name(h), cut_port(r, ':', x, y, {==}, em))))

def named_view(m: Maybe<&2, S.Split>, +s: String) -> {m_named(s, m) == US.named(pieces(m, s, ':')) : Maybe<&2, U.Endpoint>}:
  match m:
    case None{}: {==}
    case Some{S.Split{+h, +r}}:
      Equal.sym(Maybe<&2, U.Endpoint>, US.named_tail(h, String.split(r, ':')), US.made(U.HostName{h}, Some{r}, US.name(h) && US.port(r)),
        Equal.trans(Maybe<&2, U.Endpoint>, US.named_tail(h, String.split(r, ':')), US.named_tail(h, pieces(S.split_at(r, ':'), r, ':')), US.made(U.HostName{h}, Some{r}, US.name(h) && US.port(r)),
          Equal.cong(List<&2, String>, Maybe<&2, U.Endpoint>, l => US.named_tail(h, l), String.split(r, ':'), pieces(S.split_at(r, ':'), r, ':'), split_view(r, ':')),
          named_cut(h, r, S.split_at(r, ':'), {==})))

def at_spec(+c: Char, +t: String, bracket: Bool) -> {m_at(c, t, bracket) == US.at(c, t, bracket) : Maybe<&2, U.Endpoint>}:
  match bracket:
    case True{}:
      Equal.trans(Maybe<&2, U.Endpoint>, m_v6(S.split_at(t, ']')), US.bracketed(pieces(S.split_at(t, ']'), t, ']')), US.bracketed(String.split(t, ']')),
        bracket_view(S.split_at(t, ']'), t),
        Equal.cong(List<&2, String>, Maybe<&2, U.Endpoint>, l => US.bracketed(l), pieces(S.split_at(t, ']'), t, ']'), String.split(t, ']'), Equal.sym(List<&2, String>, String.split(t, ']'), pieces(S.split_at(t, ']'), t, ']'), split_view(t, ']'))))
    case False{}:
      Equal.trans(Maybe<&2, U.Endpoint>, m_named(SCon{c, t}, S.split_at(SCon{c, t}, ':')), US.named(pieces(S.split_at(SCon{c, t}, ':'), SCon{c, t}, ':')), US.named(String.split(SCon{c, t}, ':')),
        named_view(S.split_at(SCon{c, t}, ':'), SCon{c, t}),
        Equal.cong(List<&2, String>, Maybe<&2, U.Endpoint>, l => US.named(l), pieces(S.split_at(SCon{c, t}, ':'), SCon{c, t}, ':'), String.split(SCon{c, t}, ':'), Equal.sym(List<&2, String>, String.split(SCon{c, t}, ':'), pieces(S.split_at(SCon{c, t}, ':'), SCon{c, t}, ':'), split_view(SCon{c, t}, ':'))))

def spec_same(s: String) -> {m_authority(s) == US.authority(s) : Maybe<&2, U.Endpoint>}:
  match s:
    case SNil{}: {==}
    case SCon{+c, +t}: at_spec(c, t, Char.is_eq(c, '['))

def authority_same(+s: String) -> {U.read_authority(s) == US.authority(s) : Maybe<&2, U.Endpoint>}:
  Equal.trans(Maybe<&2, U.Endpoint>, U.read_authority(s), m_authority(s), US.authority(s), mirror_same(s), spec_same(s))

# ---- The Host value reads back as its endpoint ----

# Over the mirror: re-reading cuts the Host value at the same first ']' or
# ':' the endpoint came from.

def reread_spec(m: Maybe<&2, U.Endpoint>) -> Maybe<&2, U.Endpoint>:
  match m:
    case None{}: None{}
    case Some{e}: m_authority(U.host_header(e))

def v6_none(+inside: String, v: Bool, ev: {US.v6(inside) == v : Bool}, fr: @y:String -> {S.split_at(inside ++ y, ']') == OP.shift(inside, S.split_at(y, ']')) : Maybe<&2, S.Split>}) -> {reread_spec(US.made(U.HostV6{inside}, None{}, v)) == US.made(U.HostV6{inside}, None{}, v) : Maybe<&2, U.Endpoint>}:
  match v:
    case False{}: {==}
    case True{}:
      Equal.trans(Maybe<&2, U.Endpoint>, m_v6(S.split_at((inside ++ "]") ++ "", ']')), m_v6(S.split_at(inside ++ "]", ']')), Some{U.Endpoint{U.HostV6{inside}, None{}}},
        Equal.cong(String, Maybe<&2, U.Endpoint>, x => m_v6(S.split_at(x, ']')), (inside ++ "]") ++ "", inside ++ "]", TP.string_append_assoc(inside, "]", "")),
        Equal.trans(Maybe<&2, U.Endpoint>, m_v6(S.split_at(inside ++ "]", ']')), m_v6(OP.shift(inside, S.split_at("]", ']'))), Some{U.Endpoint{U.HostV6{inside}, None{}}},
          Equal.cong(Maybe<&2, S.Split>, Maybe<&2, U.Endpoint>, m => m_v6(m), S.split_at(inside ++ "]", ']'), OP.shift(inside, S.split_at("]", ']')), fr("]")),
          Equal.trans(Maybe<&2, U.Endpoint>, US.made(U.HostV6{inside ++ ""}, None{}, US.v6(inside ++ "")), US.made(U.HostV6{inside}, None{}, US.v6(inside)), Some{U.Endpoint{U.HostV6{inside}, None{}}},
            Equal.cong(String, Maybe<&2, U.Endpoint>, x => US.made(U.HostV6{x}, None{}, US.v6(x)), inside ++ "", inside, TP.string_append_nil(inside)),
            Equal.cong(Bool, Maybe<&2, U.Endpoint>, b => US.made(U.HostV6{inside}, None{}, b), US.v6(inside), True{}, ev))))

def v6_some(+inside: String, +p: String, v: Bool, ev: {US.v6(inside) && US.port(p) == v : Bool}, fr: @y:String -> {S.split_at(inside ++ y, ']') == OP.shift(inside, S.split_at(y, ']')) : Maybe<&2, S.Split>}) -> {reread_spec(US.made(U.HostV6{inside}, Some{p}, v)) == US.made(U.HostV6{inside}, Some{p}, v) : Maybe<&2, U.Endpoint>}:
  match v:
    case False{}: {==}
    case True{}:
      Equal.trans(Maybe<&2, U.Endpoint>, m_v6(S.split_at((inside ++ "]") ++ (":" ++ p), ']')), m_v6(S.split_at(inside ++ ("]" ++ (":" ++ p)), ']')), Some{U.Endpoint{U.HostV6{inside}, Some{p}}},
        Equal.cong(String, Maybe<&2, U.Endpoint>, x => m_v6(S.split_at(x, ']')), (inside ++ "]") ++ (":" ++ p), inside ++ ("]" ++ (":" ++ p)), TP.string_append_assoc(inside, "]", ":" ++ p)),
        Equal.trans(Maybe<&2, U.Endpoint>, m_v6(S.split_at(inside ++ ("]" ++ (":" ++ p)), ']')), m_v6(OP.shift(inside, S.split_at("]" ++ (":" ++ p), ']'))), Some{U.Endpoint{U.HostV6{inside}, Some{p}}},
          Equal.cong(Maybe<&2, S.Split>, Maybe<&2, U.Endpoint>, m => m_v6(m), S.split_at(inside ++ ("]" ++ (":" ++ p)), ']'), OP.shift(inside, S.split_at("]" ++ (":" ++ p), ']')), fr("]" ++ (":" ++ p))),
          Equal.trans(Maybe<&2, U.Endpoint>, US.made(U.HostV6{inside ++ ""}, Some{p}, US.v6(inside ++ "") && US.port(p)), US.made(U.HostV6{inside}, Some{p}, US.v6(inside) && US.port(p)), Some{U.Endpoint{U.HostV6{inside}, Some{p}}},
            Equal.cong(String, Maybe<&2, U.Endpoint>, x => US.made(U.HostV6{x}, Some{p}, US.v6(x) && US.port(p)), inside ++ "", inside, TP.string_append_nil(inside)),
            Equal.cong(Bool, Maybe<&2, U.Endpoint>, b => US.made(U.HostV6{inside}, Some{p}, b), US.v6(inside) && US.port(p), True{}, ev))))

def back_v6_port(+inside: String, +p: String, colon: Bool, fr: @y:String -> {S.split_at(inside ++ y, ']') == OP.shift(inside, S.split_at(y, ']')) : Maybe<&2, S.Split>}) -> {reread_spec(US.v6_port(inside, p, colon)) == US.v6_port(inside, p, colon) : Maybe<&2, U.Endpoint>}:
  match colon:
    case True{}: v6_some(inside, p, US.v6(inside) && US.port(p), {==}, fr)
    case False{}: {==}

def back_v6_rest(+inside: String, rest: String, fr: @y:String -> {S.split_at(inside ++ y, ']') == OP.shift(inside, S.split_at(y, ']')) : Maybe<&2, S.Split>}) -> {reread_spec(US.v6_rest(inside, rest)) == US.v6_rest(inside, rest) : Maybe<&2, U.Endpoint>}:
  match rest:
    case SNil{}: v6_none(inside, US.v6(inside), {==}, fr)
    case SCon{+c, +p}: back_v6_port(inside, p, Char.is_eq(c, ':'), fr)

def back_v6(m: Maybe<&2, S.Split>, fr: OP.Free(m, ']')) -> {reread_spec(m_v6(m)) == m_v6(m) : Maybe<&2, U.Endpoint>}:
  match m:
    case None{}: {==}
    case Some{S.Split{+inside, +rest}}: back_v6_rest(inside, rest, fr)

def name_none(+c: Char, +t: String, v: Bool, ev: {US.name(SCon{c, t}) == v : Bool}, em: {S.split_at(t, ':') == None{} : Maybe<&2, S.Split>}, eb: {Char.is_eq(c, '[') == False{} : Bool}, ec: {Char.is_eq(c, ':') == False{} : Bool}) -> {reread_spec(US.made(U.HostName{SCon{c, t}}, None{}, v)) == US.made(U.HostName{SCon{c, t}}, None{}, v) : Maybe<&2, U.Endpoint>}:
  match v:
    case False{}: {==}
    case True{}:
      Equal.trans(Maybe<&2, U.Endpoint>, m_authority(SCon{c, t ++ ""}), m_authority(SCon{c, t}), Some{U.Endpoint{U.HostName{SCon{c, t}}, None{}}},
        Equal.cong(String, Maybe<&2, U.Endpoint>, x => m_authority(SCon{c, x}), t ++ "", t, TP.string_append_nil(t)),
        Equal.trans(Maybe<&2, U.Endpoint>, m_at(c, t, Char.is_eq(c, '[')), m_at(c, t, False{}), Some{U.Endpoint{U.HostName{SCon{c, t}}, None{}}},
          Equal.cong(Bool, Maybe<&2, U.Endpoint>, b => m_at(c, t, b), Char.is_eq(c, '['), False{}, eb),
          Equal.trans(Maybe<&2, U.Endpoint>, m_named(SCon{c, t}, S.split_pick(c, t, S.split_at(t, ':'), Char.is_eq(c, ':'))), m_named(SCon{c, t}, S.split_pick(c, t, S.split_at(t, ':'), False{})), Some{U.Endpoint{U.HostName{SCon{c, t}}, None{}}},
            Equal.cong(Bool, Maybe<&2, U.Endpoint>, b => m_named(SCon{c, t}, S.split_pick(c, t, S.split_at(t, ':'), b)), Char.is_eq(c, ':'), False{}, ec),
            Equal.trans(Maybe<&2, U.Endpoint>, m_named(SCon{c, t}, S.split_prepend(c, S.split_at(t, ':'))), m_named(SCon{c, t}, S.split_prepend(c, None{})), Some{U.Endpoint{U.HostName{SCon{c, t}}, None{}}},
              Equal.cong(Maybe<&2, S.Split>, Maybe<&2, U.Endpoint>, m => m_named(SCon{c, t}, S.split_prepend(c, m)), S.split_at(t, ':'), None{}, em),
              Equal.cong(Bool, Maybe<&2, U.Endpoint>, b => US.made(U.HostName{SCon{c, t}}, None{}, b), US.name(SCon{c, t}), True{}, ev)))))

def name_some(+c: Char, +a: String, +p: String, v: Bool, ev: {US.name(SCon{c, a}) && US.port(p) == v : Bool}, fr: @y:String -> {S.split_at(a ++ y, ':') == OP.shift(a, S.split_at(y, ':')) : Maybe<&2, S.Split>}, eb: {Char.is_eq(c, '[') == False{} : Bool}, ec: {Char.is_eq(c, ':') == False{} : Bool}) -> {reread_spec(US.made(U.HostName{SCon{c, a}}, Some{p}, v)) == US.made(U.HostName{SCon{c, a}}, Some{p}, v) : Maybe<&2, U.Endpoint>}:
  match v:
    case False{}: {==}
    case True{}:
      Equal.trans(Maybe<&2, U.Endpoint>, m_at(c, a ++ (":" ++ p), Char.is_eq(c, '[')), m_at(c, a ++ (":" ++ p), False{}), Some{U.Endpoint{U.HostName{SCon{c, a}}, Some{p}}},
        Equal.cong(Bool, Maybe<&2, U.Endpoint>, b => m_at(c, a ++ (":" ++ p), b), Char.is_eq(c, '['), False{}, eb),
        Equal.trans(Maybe<&2, U.Endpoint>, m_named(SCon{c, a ++ (":" ++ p)}, S.split_pick(c, a ++ (":" ++ p), S.split_at(a ++ (":" ++ p), ':'), Char.is_eq(c, ':'))), m_named(SCon{c, a ++ (":" ++ p)}, S.split_pick(c, a ++ (":" ++ p), S.split_at(a ++ (":" ++ p), ':'), False{})), Some{U.Endpoint{U.HostName{SCon{c, a}}, Some{p}}},
          Equal.cong(Bool, Maybe<&2, U.Endpoint>, b => m_named(SCon{c, a ++ (":" ++ p)}, S.split_pick(c, a ++ (":" ++ p), S.split_at(a ++ (":" ++ p), ':'), b)), Char.is_eq(c, ':'), False{}, ec),
          Equal.trans(Maybe<&2, U.Endpoint>, m_named(SCon{c, a ++ (":" ++ p)}, S.split_prepend(c, S.split_at(a ++ (":" ++ p), ':'))), m_named(SCon{c, a ++ (":" ++ p)}, S.split_prepend(c, OP.shift(a, S.split_at(":" ++ p, ':')))), Some{U.Endpoint{U.HostName{SCon{c, a}}, Some{p}}},
            Equal.cong(Maybe<&2, S.Split>, Maybe<&2, U.Endpoint>, m => m_named(SCon{c, a ++ (":" ++ p)}, S.split_prepend(c, m)), S.split_at(a ++ (":" ++ p), ':'), OP.shift(a, S.split_at(":" ++ p, ':')), fr(":" ++ p)),
            Equal.trans(Maybe<&2, U.Endpoint>, US.made(U.HostName{SCon{c, a ++ ""}}, Some{p}, US.name(SCon{c, a ++ ""}) && US.port(p)), US.made(U.HostName{SCon{c, a}}, Some{p}, US.name(SCon{c, a}) && US.port(p)), Some{U.Endpoint{U.HostName{SCon{c, a}}, Some{p}}},
              Equal.cong(String, Maybe<&2, U.Endpoint>, x => US.made(U.HostName{SCon{c, x}}, Some{p}, US.name(SCon{c, x}) && US.port(p)), a ++ "", a, TP.string_append_nil(a)),
              Equal.cong(Bool, Maybe<&2, U.Endpoint>, b => US.made(U.HostName{SCon{c, a}}, Some{p}, b), US.name(SCon{c, a}) && US.port(p), True{}, ev)))))

def back_named(+c: Char, +t: String, m: Maybe<&2, S.Split>, em: {S.split_at(t, ':') == m : Maybe<&2, S.Split>}, fr: OP.Free(m, ':'), colon: Bool, ec: {Char.is_eq(c, ':') == colon : Bool}, eb: {Char.is_eq(c, '[') == False{} : Bool}) -> {reread_spec(m_named(SCon{c, t}, S.split_pick(c, t, m, colon))) == m_named(SCon{c, t}, S.split_pick(c, t, m, colon)) : Maybe<&2, U.Endpoint>}:
  match m colon:
    case None{} True{}: {==}
    case Some{S.Split{a, p}} True{}: {==}
    case None{} False{}: name_none(c, t, US.name(SCon{c, t}), {==}, em, eb, ec)
    case Some{S.Split{+a, +p}} False{}: name_some(c, a, p, US.name(SCon{c, a}) && US.port(p), {==}, fr, eb, ec)

def back_at(+c: Char, +t: String, bracket: Bool, eb: {Char.is_eq(c, '[') == bracket : Bool}) -> {reread_spec(m_at(c, t, bracket)) == m_at(c, t, bracket) : Maybe<&2, U.Endpoint>}:
  match bracket:
    case True{}: back_v6(S.split_at(t, ']'), OP.free(t, ']'))
    case False{}: back_named(c, t, S.split_at(t, ':'), {==}, OP.free(t, ':'), Char.is_eq(c, ':'), {==}, eb)

def back_spec(s: String) -> {reread_spec(m_authority(s)) == m_authority(s) : Maybe<&2, U.Endpoint>}:
  match s:
    case SNil{}: {==}
    case SCon{+c, +t}: back_at(c, t, Char.is_eq(c, '['), {==})

def reread_same(m: Maybe<&2, U.Endpoint>) -> {US.reread(m) == reread_spec(m) : Maybe<&2, U.Endpoint>}:
  match m:
    case None{}: {==}
    case Some{e}: mirror_same(U.host_header(e))

def round_trip(+s: String) -> {US.reread(U.read_authority(s)) == U.read_authority(s) : Maybe<&2, U.Endpoint>}:
  Equal.trans(Maybe<&2, U.Endpoint>, US.reread(U.read_authority(s)), US.reread(m_authority(s)), U.read_authority(s),
    Equal.cong(Maybe<&2, U.Endpoint>, Maybe<&2, U.Endpoint>, m => US.reread(m), U.read_authority(s), m_authority(s), mirror_same(s)),
    Equal.trans(Maybe<&2, U.Endpoint>, US.reread(m_authority(s)), reread_spec(m_authority(s)), U.read_authority(s), reread_same(m_authority(s)),
      Equal.trans(Maybe<&2, U.Endpoint>, reread_spec(m_authority(s)), m_authority(s), U.read_authority(s), back_spec(s), Equal.sym(Maybe<&2, U.Endpoint>, U.read_authority(s), m_authority(s), mirror_same(s)))))
