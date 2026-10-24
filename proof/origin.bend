# BND-85: src/http/origin.bend meets proof/origin-spec.bend, and a
# serialized origin reads back as the scheme, host and port it came from.
# Each lemma states impl == spec for one parser stage; helpers that match on
# an abstract value get a small case split, since equal bodies under
# different names do not convert while stuck.
import Base
import ../src/http/origin.bend as O
import ../src/http/bytes.bend as B
import ./origin-spec.bend as S
import ./trim-spec.bend as Trim
import ./trim.bend as TrimProof
import ./cut-tail.bend as CutTail
import ./fold-tail.bend as FT
import ./misc-tail.bend as MT
import ./bytes-tail.bend as BT
import ./text.bend as TP
import ./origin-laws.bend as Laws

# ---- Conversions between the two modules' types ----

def to_split(m: Maybe<&2, O.Cut>) -> Maybe<&2, S.Split>:
  match m:
    case None{}: None{}
    case Some{O.Cut{a, b}}: Some{S.Split{a, b}}

def to_part(c: O.Cut) -> S.Split:
  match c:
    case O.Cut{a, b}: S.Split{a, b}

def suffix_of(m: Maybe<&2, Maybe<&2, String>>) -> Maybe<&2, String>:
  match m:
    case None{}: None{}
    case Some{p}: Some{S.suffix(p)}

def and_same(+a: Bool, +b: Bool, +c: Bool, +d: Bool, e1: {a == b : Bool}, e2: {c == d : Bool}) -> {a && c == b && d : Bool}:
  Equal.trans(Bool, a && c, b && c, b && d, Equal.cong(Bool, Bool, z => z && c, a, b, e1), Equal.cong(Bool, Bool, z => b && z, c, d, e2))

# ---- Splitting ----

def cut_pick_same(+c: Char, +t: String, m: Maybe<&2, O.Cut>, here: Bool) -> {to_split(O.cut_pick(c, t, m, here)) == S.split_pick(c, t, to_split(m), here) : Maybe<&2, S.Split>}:
  match m here:
    case None{} True{}: {==}
    case None{} False{}: {==}
    case Some{O.Cut{a, b}} True{}: {==}
    case Some{O.Cut{a, b}} False{}: {==}

def cut_spec_same(s: String, +sep: Char) -> {to_split(O.cut_spec(s, sep)) == S.split_at(s, sep) : Maybe<&2, S.Split>}:
  match s:
    case SNil{}: {==}
    case SCon{+c, +t}:
      Equal.trans(Maybe<&2, S.Split>, to_split(O.cut_pick(c, t, O.cut_spec(t, sep), Char.is_eq(c, sep))), S.split_pick(c, t, to_split(O.cut_spec(t, sep)), Char.is_eq(c, sep)), S.split_pick(c, t, S.split_at(t, sep), Char.is_eq(c, sep)), cut_pick_same(c, t, O.cut_spec(t, sep), Char.is_eq(c, sep)), Equal.cong(Maybe<&2, S.Split>, Maybe<&2, S.Split>, m => S.split_pick(c, t, m, Char.is_eq(c, sep)), to_split(O.cut_spec(t, sep)), S.split_at(t, sep), cut_spec_same(t, sep)))

def cut_same(+s: String, +sep: Char) -> {to_split(O.cut(s, sep)) == S.split_at(s, sep) : Maybe<&2, S.Split>}:
  Equal.trans(Maybe<&2, S.Split>, to_split(O.cut(s, sep)), to_split(O.cut_spec(s, sep)), S.split_at(s, sep), Equal.cong(Maybe<&2, O.Cut>, Maybe<&2, S.Split>, m => to_split(m), O.cut(s, sep), O.cut_spec(s, sep), CutTail.O_equiv(s, sep)), cut_spec_same(s, sep))

def authority_pick_same(+c: Char, +t: String, r: O.Cut, end: Bool) -> {to_part(O.authority_pick(c, t, r, end)) == S.authority_pick(c, t, to_part(r), end) : S.Split}:
  match r end:
    case O.Cut{a, b} True{}: {==}
    case O.Cut{a, b} False{}: {==}

def authority_spec_same(s: String) -> {to_part(O.authority_spec(s)) == S.authority(s) : S.Split}:
  match s:
    case SNil{}: {==}
    case SCon{+c, +t}:
      Equal.trans(S.Split, to_part(O.authority_pick(c, t, O.authority_spec(t), O.ends_authority(c))), S.authority_pick(c, t, to_part(O.authority_spec(t)), O.ends_authority(c)), S.authority_pick(c, t, S.authority(t), S.ends(c)), authority_pick_same(c, t, O.authority_spec(t), O.ends_authority(c)), Equal.cong(S.Split, S.Split, p => S.authority_pick(c, t, p, O.ends_authority(c)), to_part(O.authority_spec(t)), S.authority(t), authority_spec_same(t)))

def authority_same(+s: String) -> {to_part(O.authority(s)) == S.authority(s) : S.Split}:
  Equal.trans(S.Split, to_part(O.authority(s)), to_part(O.authority_spec(s)), S.authority(s), Equal.cong(O.Cut, S.Split, c => to_part(c), O.authority(s), O.authority_spec(s), MT.authority_equiv(s)), authority_spec_same(s))

# ---- Character classes ----

def digits_spec_same(s: String) -> {O.digits_spec(s) == S.decimals(s) : Bool}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{+x}, +t}: Equal.cong(Bool, Bool, z => O.digit(Chr{x}) && z, O.digits_spec(t), S.decimals(t), digits_spec_same(t))

def digits_same(+s: String) -> {O.digits(s) == S.decimals(s) : Bool}:
  Equal.trans(Bool, O.digits(s), O.digits_spec(s), S.decimals(s), FT.o_digits_equiv(s), digits_spec_same(s))

def names_spec_same(s: String) -> {O.name_chars_spec(s) == S.host_chars(s) : Bool}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{+x}, +t}: Equal.cong(Bool, Bool, z => O.name_char(Chr{x}) && z, O.name_chars_spec(t), S.host_chars(t), names_spec_same(t))

def names_same(+s: String) -> {O.name_chars(s) == S.host_chars(s) : Bool}:
  Equal.trans(Bool, O.name_chars(s), O.name_chars_spec(s), S.host_chars(s), FT.o_name_chars_equiv(s), names_spec_same(s))

def hex_same(s: String) -> {O.hex_digits(s) == S.hexes(s) : Bool}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{+x}, +t}: Equal.cong(Bool, Bool, z => O.hex_digit(Chr{x}) && z, O.hex_digits(t), S.hexes(t), hex_same(t))

# ---- IPv6 ----

def drop_same(t: String) -> {O.after_first(t) == S.drop_one(t) : String}:
  match t:
    case SNil{}: {==}
    case SCon{c, u}: {==}

def colon_same(t: String) -> {O.colon_first(t) == S.next_colon(t) : Bool}:
  match t:
    case SNil{}: {==}
    case SCon{c, u}: {==}

def pair_pick_same(+c: Char, +t: String, m: Maybe<&2, O.Cut>, here: Bool) -> {to_split(O.pair_pick(c, t, m, here)) == S.double_pick(c, t, to_split(m), here) : Maybe<&2, S.Split>}:
  match m here:
    case None{} True{}: Equal.cong(String, Maybe<&2, S.Split>, r => Some{S.Split{"", r}}, O.after_first(t), S.drop_one(t), drop_same(t))
    case None{} False{}: {==}
    case Some{O.Cut{a, b}} True{}: Equal.cong(String, Maybe<&2, S.Split>, r => Some{S.Split{"", r}}, O.after_first(t), S.drop_one(t), drop_same(t))
    case Some{O.Cut{a, b}} False{}: {==}

def pair_same(s: String) -> {to_split(O.cut_pair(s)) == S.split_double(s) : Maybe<&2, S.Split>}:
  match s:
    case SNil{}: {==}
    case SCon{+c, +t}:
      Equal.trans(Maybe<&2, S.Split>, to_split(O.pair_pick(c, t, O.cut_pair(t), Char.is_eq(c, ':') && O.colon_first(t))), S.double_pick(c, t, to_split(O.cut_pair(t)), Char.is_eq(c, ':') && O.colon_first(t)), S.double_pick(c, t, S.split_double(t), Char.is_eq(c, ':') && S.next_colon(t)), pair_pick_same(c, t, O.cut_pair(t), Char.is_eq(c, ':') && O.colon_first(t)),
        Equal.trans(Maybe<&2, S.Split>, S.double_pick(c, t, to_split(O.cut_pair(t)), Char.is_eq(c, ':') && O.colon_first(t)), S.double_pick(c, t, S.split_double(t), Char.is_eq(c, ':') && O.colon_first(t)), S.double_pick(c, t, S.split_double(t), Char.is_eq(c, ':') && S.next_colon(t)), Equal.cong(Maybe<&2, S.Split>, Maybe<&2, S.Split>, m => S.double_pick(c, t, m, Char.is_eq(c, ':') && O.colon_first(t)), to_split(O.cut_pair(t)), S.split_double(t), pair_same(t)), Equal.cong(Bool, Maybe<&2, S.Split>, b => S.double_pick(c, t, S.split_double(t), Char.is_eq(c, ':') && b), O.colon_first(t), S.next_colon(t), colon_same(t))))

def group_same(g: String) -> {O.group(g) == S.hex_group(g) : Bool}:
  match g:
    case SNil{}: {==}
    case SCon{Chr{+x}, +t}: Equal.cong(Bool, Bool, z => ((O.hex_digit(Chr{x}) && z) && Nat.is_le(String.length(t), 3n)) && (String.is_empty(t) || Bool.not(O.zero(Chr{x}))), O.hex_digits(t), S.hexes(t), hex_same(t))

def groups_same(gs: List<&2, String>) -> {O.groups(gs) == S.hex_groups(gs) : Bool}:
  match gs:
    case Nil{}: {==}
    case +g <> +t: and_same(O.group(g), S.hex_group(g), O.groups(t), S.hex_groups(t), group_same(g), groups_same(t))

def run_same(+cur: Nat, hit: Bool) -> {O.run_next(cur, hit) == S.run_after(cur, hit) : Nat}:
  match hit:
    case True{}: {==}
    case False{}: {==}

def zero_run_same(gs: List<&2, String>, +cur: Nat, +best: Nat) -> {O.zero_run(gs, cur, best) == S.zeros(gs, cur, best) : Nat}:
  match gs:
    case Nil{}: {==}
    case +g <> +t:
      Equal.trans(Nat, O.zero_run(t, O.run_next(cur, O.zero_group(g)), Nat.max(cur, best)), S.zeros(t, O.run_next(cur, O.zero_group(g)), Nat.max(cur, best)), S.zeros(t, S.run_after(cur, S.is_zero_group(g)), Nat.max(cur, best)), zero_run_same(t, O.run_next(cur, O.zero_group(g)), Nat.max(cur, best)), Equal.cong(Nat, Nat, n => S.zeros(t, n, Nat.max(cur, best)), O.run_next(cur, O.zero_group(g)), S.run_after(cur, S.is_zero_group(g)), run_same(cur, O.zero_group(g))))

def longest_same(+gs: List<&2, String>) -> {O.longest(gs) == S.longest_zeros(gs) : Nat}:
  zero_run_same(gs, 0n, 0n)

def first_same(gs: List<&2, String>) -> {O.first_zero(gs) == S.starts_zero(gs) : Bool}:
  match gs:
    case Nil{}: {==}
    case g <> t: {==}

def pieces_same(+s: String) -> {O.pieces(s) == S.group_list(s) : List<&2, String>}:
  match s:
    case SNil{}: {==}
    case SCon{c, t}: {==}

def full_same(+gs: List<&2, String>) -> {O.full(gs) == S.uncompressed(gs) : Bool}:
  and_same(Nat.is_eq(List.length(&2, String, gs), 8n) && O.groups(gs), Nat.is_eq(List.length(&2, String, gs), 8n) && S.hex_groups(gs), Nat.is_lt(O.longest(gs), 2n), Nat.is_lt(S.longest_zeros(gs), 2n), Equal.cong(Bool, Bool, z => Nat.is_eq(List.length(&2, String, gs), 8n) && z, O.groups(gs), S.hex_groups(gs), groups_same(gs)), Equal.cong(Nat, Bool, n => Nat.is_lt(n, 2n), O.longest(gs), S.longest_zeros(gs), longest_same(gs)))

def gapped_same(+l: List<&2, String>, +r: List<&2, String>, +gap: Nat) -> {O.gapped(l, r, gap) == S.compression(l, r, gap) : Bool}:
  and_same(
    (Nat.is_lt(O.longest(l), gap) && Nat.is_le(O.longest(r), gap)) && Bool.not(O.first_zero(List.reverse(&2, String, l))),
    (Nat.is_lt(S.longest_zeros(l), gap) && Nat.is_le(S.longest_zeros(r), gap)) && Bool.not(S.starts_zero(List.reverse(&2, String, l))),
    Bool.not(O.first_zero(r)), Bool.not(S.starts_zero(r)),
    and_same(
      Nat.is_lt(O.longest(l), gap) && Nat.is_le(O.longest(r), gap),
      Nat.is_lt(S.longest_zeros(l), gap) && Nat.is_le(S.longest_zeros(r), gap),
      Bool.not(O.first_zero(List.reverse(&2, String, l))), Bool.not(S.starts_zero(List.reverse(&2, String, l))),
      and_same(Nat.is_lt(O.longest(l), gap), Nat.is_lt(S.longest_zeros(l), gap), Nat.is_le(O.longest(r), gap), Nat.is_le(S.longest_zeros(r), gap), Equal.cong(Nat, Bool, n => Nat.is_lt(n, gap), O.longest(l), S.longest_zeros(l), longest_same(l)), Equal.cong(Nat, Bool, n => Nat.is_le(n, gap), O.longest(r), S.longest_zeros(r), longest_same(r))),
      Equal.cong(Bool, Bool, z => Bool.not(z), O.first_zero(List.reverse(&2, String, l)), S.starts_zero(List.reverse(&2, String, l)), first_same(List.reverse(&2, String, l)))),
    Equal.cong(Bool, Bool, z => Bool.not(z), O.first_zero(r), S.starts_zero(r), first_same(r)))

def compressed_same(+l: List<&2, String>, +r: List<&2, String>) -> {O.compressed(l, r) == S.compressed(l, r) : Bool}:
  and_same(
    (O.groups(l) && O.groups(r)) && Nat.is_le(Nat.add(List.length(&2, String, l), List.length(&2, String, r)), 6n),
    (S.hex_groups(l) && S.hex_groups(r)) && Nat.is_le(Nat.add(List.length(&2, String, l), List.length(&2, String, r)), 6n),
    O.gapped(l, r, Nat.sub(8n, Nat.add(List.length(&2, String, l), List.length(&2, String, r)))),
    S.compression(l, r, Nat.sub(8n, Nat.add(List.length(&2, String, l), List.length(&2, String, r)))),
    Equal.cong(Bool, Bool, z => z && Nat.is_le(Nat.add(List.length(&2, String, l), List.length(&2, String, r)), 6n), O.groups(l) && O.groups(r), S.hex_groups(l) && S.hex_groups(r), and_same(O.groups(l), S.hex_groups(l), O.groups(r), S.hex_groups(r), groups_same(l), groups_same(r))),
    gapped_same(l, r, Nat.sub(8n, Nat.add(List.length(&2, String, l), List.length(&2, String, r)))))

def parts_same(+text: String, m: Maybe<&2, O.Cut>) -> {O.ipv6_parts(text, m) == S.v6_parts(text, to_split(m)) : Bool}:
  match m:
    case None{}: full_same(String.split(text, ':'))
    case Some{O.Cut{+a, +b}}:
      Equal.trans(Bool, O.compressed(O.pieces(a), O.pieces(b)), O.compressed(S.group_list(a), S.group_list(b)), S.compressed(S.group_list(a), S.group_list(b)),
        Equal.trans(Bool, O.compressed(O.pieces(a), O.pieces(b)), O.compressed(S.group_list(a), O.pieces(b)), O.compressed(S.group_list(a), S.group_list(b)), Equal.cong(List<&2, String>, Bool, x => O.compressed(x, O.pieces(b)), O.pieces(a), S.group_list(a), pieces_same(a)), Equal.cong(List<&2, String>, Bool, y => O.compressed(S.group_list(a), y), O.pieces(b), S.group_list(b), pieces_same(b))),
        compressed_same(S.group_list(a), S.group_list(b)))

def v6_short_same(+text: String, short: Bool) -> {O.ipv6_bounded(text, short) == S.v6_short(text, short) : Bool}:
  match short:
    case True{}: Equal.trans(Bool, O.ipv6_parts(text, O.cut_pair(text)), S.v6_parts(text, to_split(O.cut_pair(text))), S.v6_parts(text, S.split_double(text)), parts_same(text, O.cut_pair(text)), Equal.cong(Maybe<&2, S.Split>, Bool, m => S.v6_parts(text, m), to_split(O.cut_pair(text)), S.split_double(text), pair_same(text)))
    case False{}: {==}

def ipv6_same(+text: String) -> {O.ipv6(text) == S.ipv6(text) : Bool}:
  v6_short_same(text, Nat.is_le(String.length(text), 39n))

# ---- IPv4 and DNS names ----

def octet_same(s: String) -> {O.octet(s) == S.dec_octet(s) : Bool}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{a}, SNil{}}: {==}
    case SCon{Chr{a}, SCon{Chr{b}, SNil{}}}: {==}
    case SCon{Chr{a}, SCon{Chr{b}, SCon{Chr{c}, SNil{}}}}: {==}
    case SCon{a, SCon{b, SCon{c, SCon{d, e}}}}: {==}

def quad_same(parts: List<&2, String>) -> {O.quad(parts) == S.four_octets(parts) : Bool}:
  match parts:
    case Nil{}: {==}
    case a <> Nil{}: {==}
    case a <> (b <> Nil{}): {==}
    case a <> (b <> (c <> Nil{})): {==}
    case +a <> (+b <> (+c <> (+d <> Nil{}))):
      and_same(O.octet(a) && O.octet(b) && O.octet(c), S.dec_octet(a) && S.dec_octet(b) && S.dec_octet(c), O.octet(d), S.dec_octet(d),
        and_same(O.octet(a) && O.octet(b), S.dec_octet(a) && S.dec_octet(b), O.octet(c), S.dec_octet(c), and_same(O.octet(a), S.dec_octet(a), O.octet(b), S.dec_octet(b), octet_same(a), octet_same(b)), octet_same(c)),
        octet_same(d))
    case a <> (b <> (c <> (d <> (e <> f)))): {==}

def ipv4_same(+h: String) -> {O.ipv4(h) == S.ipv4(h) : Bool}:
  quad_same(String.split(h, '.'))

def hex_prefixed_same(s: String) -> {O.hex_prefixed(s) == S.hex_number(s) : Bool}:
  match s:
    case SNil{}: {==}
    case SCon{a, SNil{}}: {==}
    case SCon{+a, SCon{+b, +t}}: Equal.cong(Bool, Bool, z => (O.zero(a) && Char.is_eq(b, 'x')) && z, O.hex_digits(t), S.hexes(t), hex_same(t))

def number_same(+p: String) -> {O.number(p) == S.numeric(p) : Bool}:
  Equal.trans(Bool, (Bool.not(String.is_empty(p)) && O.digits_spec(p)) || O.hex_prefixed(p), (Bool.not(String.is_empty(p)) && S.decimals(p)) || O.hex_prefixed(p), (Bool.not(String.is_empty(p)) && S.decimals(p)) || S.hex_number(p), Equal.cong(Bool, Bool, z => (Bool.not(String.is_empty(p)) && z) || O.hex_prefixed(p), O.digits_spec(p), S.decimals(p), digits_spec_same(p)), Equal.cong(Bool, Bool, z => (Bool.not(String.is_empty(p)) && S.decimals(p)) || z, O.hex_prefixed(p), S.hex_number(p), hex_prefixed_same(p)))

def last_pick_same(+p: String, rest: List<&2, String>) -> {O.last_pick(p, rest) == S.last_nonempty(p, rest) : String}:
  match p rest:
    case SNil{} Nil{}: {==}
    case SNil{} q <> u: {==}
    case SCon{c, t} _: {==}

def last_same(rev: List<&2, String>) -> {O.last_label(rev) == S.final_label(rev) : String}:
  match rev:
    case Nil{}: {==}
    case +p <> +t: last_pick_same(p, t)

def ends_same(+h: String) -> {O.ends_in_number(h) == S.ends_in_number(h) : Bool}:
  Equal.trans(Bool, O.number(O.last_label(List.reverse(&2, String, String.split(h, '.')))), S.numeric(O.last_label(List.reverse(&2, String, String.split(h, '.')))), S.numeric(S.final_label(List.reverse(&2, String, String.split(h, '.')))), number_same(O.last_label(List.reverse(&2, String, String.split(h, '.')))), Equal.cong(String, Bool, z => S.numeric(z), O.last_label(List.reverse(&2, String, String.split(h, '.'))), S.final_label(List.reverse(&2, String, String.split(h, '.'))), last_same(List.reverse(&2, String, String.split(h, '.')))))

def kind_same(+h: String, number: Bool) -> {O.name_kind(h, number) == S.host_kind(h, number) : Bool}:
  match number:
    case True{}: ipv4_same(h)
    case False{}: Equal.cong(Bool, Bool, z => Bool.not(String.is_empty(h)) && z, O.name_chars(h), S.host_chars(h), names_same(h))

def name_short_same(+h: String, short: Bool) -> {O.name_bounded(h, short) == S.host_short(h, short) : Bool}:
  match short:
    case True{}: Equal.trans(Bool, O.name_kind(h, O.ends_in_number(h)), S.host_kind(h, O.ends_in_number(h)), S.host_kind(h, S.ends_in_number(h)), kind_same(h, O.ends_in_number(h)), Equal.cong(Bool, Bool, b => S.host_kind(h, b), O.ends_in_number(h), S.ends_in_number(h), ends_same(h)))
    case False{}: {==}

def name_host_same(+h: String) -> {O.name_host(h) == S.name_host(h) : Bool}:
  name_short_same(h, Nat.is_le(String.length(h), 253n) || (String.ends_with(h, ".") && Nat.is_le(String.length(h), 254n)))

# ---- Ports ----

def kept_same(+n: Nat, default: Bool) -> {O.port_kept(n, default) == suffix_of(S.port_default(n, default)) : Maybe<&2, String>}:
  match default:
    case True{}: {==}
    case False{}: {==}

def bounded_same(+n: Nat, +default: Nat, valid: Bool) -> {O.port_bounded(n, default, valid) == suffix_of(S.port_range(n, default, valid)) : Maybe<&2, String>}:
  match valid:
    case True{}: kept_same(n, Nat.is_eq(n, default))
    case False{}: {==}

def read_same(n: Maybe<&2, Nat>, +default: Nat) -> {O.port_number(n, default) == suffix_of(S.port_read(n, default)) : Maybe<&2, String>}:
  match n:
    case None{}: {==}
    case Some{+v}: bounded_same(v, default, Nat.is_le(v, 65535n))

def port_text_same(+text: String, +default: Nat, empty: Bool, valid: Bool) -> {O.port_digits(text, default, empty, valid) == suffix_of(S.port_text(text, default, empty, valid)) : Maybe<&2, String>}:
  match empty valid:
    case True{} _: {==}
    case False{} True{}: read_same(Nat.read(text), default)
    case False{} False{}: {==}

def port_same(+text: String, +default: Nat) -> {O.port(text, default) == suffix_of(S.port(text, default)) : Maybe<&2, String>}:
  Equal.trans(Maybe<&2, String>, O.port_digits(text, default, String.is_empty(text), O.digits(text) && Nat.is_le(String.length(text), 5n)), O.port_digits(text, default, String.is_empty(text), S.decimals(text) && Nat.is_le(String.length(text), 5n)), suffix_of(S.port(text, default)), Equal.cong(Bool, Maybe<&2, String>, b => O.port_digits(text, default, String.is_empty(text), b && Nat.is_le(String.length(text), 5n)), O.digits(text), S.decimals(text), digits_same(text)), port_text_same(text, default, String.is_empty(text), S.decimals(text) && Nat.is_le(String.length(text), 5n)))

# ---- Hosts ----

def assemble_same(+scheme: String, host: Maybe<&2, String>, p: Maybe<&2, Maybe<&2, String>>) -> {O.assemble(scheme, host, suffix_of(p)) == S.serialized(S.origin(scheme, host, p)) : Maybe<&2, String>}:
  match host p:
    case Some{h} Some{q}: {==}
    case Some{h} None{}: {==}
    case None{} Some{q}: {==}
    case None{} None{}: {==}

def host_ok_same(+host: String, valid: Bool) -> {O.host_ok(host, valid) == S.valid_host(host, valid) : Maybe<&2, String>}:
  match valid:
    case True{}: {==}
    case False{}: {==}

# The leaf every host shape reaches: a validity Bool and a port.
def leaf(+scheme: String, +host: String, +vo: Bool, +vs: Bool, ev: {vo == vs : Bool}, +po: Maybe<&2, String>, +ps: Maybe<&2, Maybe<&2, String>>, ep: {po == suffix_of(ps) : Maybe<&2, String>}) -> {O.assemble(scheme, O.host_ok(host, vo), po) == S.serialized(S.origin(scheme, S.valid_host(host, vs), ps)) : Maybe<&2, String>}:
  %Equal.sym(Bool, vo, vs, ev) : {O.assemble(scheme, O.host_ok(host, _), po) == S.serialized(S.origin(scheme, S.valid_host(host, vs), ps)) : Maybe<&2, String>}
  %Equal.sym(Maybe<&2, String>, po, suffix_of(ps), ep) : {O.assemble(scheme, O.host_ok(host, vs), _) == S.serialized(S.origin(scheme, S.valid_host(host, vs), ps)) : Maybe<&2, String>}
  %Equal.sym(Maybe<&2, String>, O.host_ok(host, vs), S.valid_host(host, vs), host_ok_same(host, vs)) : {O.assemble(scheme, _, suffix_of(ps)) == S.serialized(S.origin(scheme, S.valid_host(host, vs), ps)) : Maybe<&2, String>}
  assemble_same(scheme, S.valid_host(host, vs), ps)

def bracket_port_same(+scheme: String, +default: Nat, +inside: String, +p: String, colon: Bool) -> {O.bracketed_port(scheme, default, inside, p, colon) == S.serialized(S.bracket_port(scheme, default, inside, p, colon)) : Maybe<&2, String>}:
  match colon:
    case True{}: leaf(scheme, "[" ++ inside ++ "]", O.ipv6(inside), S.ipv6(inside), ipv6_same(inside), O.port(p, default), S.port(p, default), port_same(p, default))
    case False{}: {==}

def bracket_rest_same(+scheme: String, +default: Nat, +inside: String, rest: String) -> {O.bracketed_rest(scheme, default, inside, rest) == S.serialized(S.bracket_rest(scheme, default, inside, rest)) : Maybe<&2, String>}:
  match rest:
    case SNil{}: leaf(scheme, "[" ++ inside ++ "]", O.ipv6(inside), S.ipv6(inside), ipv6_same(inside), Some{""}, Some{None{}}, {==})
    case SCon{+c, +p}: bracket_port_same(scheme, default, inside, p, Char.is_eq(c, ':'))

def bracketed_same(+scheme: String, +default: Nat, m: Maybe<&2, O.Cut>) -> {O.bracketed(scheme, default, m) == S.serialized(S.bracketed(scheme, default, to_split(m))) : Maybe<&2, String>}:
  match m:
    case None{}: {==}
    case Some{O.Cut{+inside, +rest}}: bracket_rest_same(scheme, default, inside, rest)

def named_same(+scheme: String, +default: Nat, +whole: String, m: Maybe<&2, O.Cut>) -> {O.named(scheme, default, whole, m) == S.serialized(S.named(scheme, default, whole, to_split(m))) : Maybe<&2, String>}:
  match m:
    case None{}: leaf(scheme, whole, O.name_host(whole), S.name_host(whole), name_host_same(whole), Some{""}, Some{None{}}, {==})
    case Some{O.Cut{+host, +p}}: leaf(scheme, host, O.name_host(host), S.name_host(host), name_host_same(host), O.port(p, default), S.port(p, default), port_same(p, default))

def at_same(+scheme: String, +default: Nat, +c: Char, +t: String, bracket: Bool) -> {O.hostport_at(scheme, default, c, t, bracket) == S.serialized(S.host_at(scheme, default, c, t, bracket)) : Maybe<&2, String>}:
  match bracket:
    case True{}: Equal.trans(Maybe<&2, String>, O.bracketed(scheme, default, O.cut(t, ']')), S.serialized(S.bracketed(scheme, default, to_split(O.cut(t, ']')))), S.serialized(S.bracketed(scheme, default, S.split_at(t, ']'))), bracketed_same(scheme, default, O.cut(t, ']')), Equal.cong(Maybe<&2, S.Split>, Maybe<&2, String>, m => S.serialized(S.bracketed(scheme, default, m)), to_split(O.cut(t, ']')), S.split_at(t, ']'), cut_same(t, ']')))
    case False{}: Equal.trans(Maybe<&2, String>, O.named(scheme, default, SCon{c, t}, O.cut(SCon{c, t}, ':')), S.serialized(S.named(scheme, default, SCon{c, t}, to_split(O.cut(SCon{c, t}, ':')))), S.serialized(S.named(scheme, default, SCon{c, t}, S.split_at(SCon{c, t}, ':'))), named_same(scheme, default, SCon{c, t}, O.cut(SCon{c, t}, ':')), Equal.cong(Maybe<&2, S.Split>, Maybe<&2, String>, m => S.serialized(S.named(scheme, default, SCon{c, t}, m)), to_split(O.cut(SCon{c, t}, ':')), S.split_at(SCon{c, t}, ':'), cut_same(SCon{c, t}, ':')))

def hostport_same(+scheme: String, +default: Nat, auth: String) -> {O.hostport(scheme, default, auth) == S.serialized(S.host_port(scheme, default, auth)) : Maybe<&2, String>}:
  match auth:
    case SNil{}: {==}
    case SCon{+c, +t}: at_same(scheme, default, c, t, Char.is_eq(c, '['))

# ---- The authority and the scheme ----

def checked_same(+scheme: String, +default: Nat, +auth: String, ok: Bool) -> {O.checked_tail(scheme, default, auth, ok) == S.serialized(S.checked(scheme, default, auth, ok)) : Maybe<&2, String>}:
  match ok:
    case True{}: Equal.trans(Maybe<&2, String>, O.hostport(scheme, default, B.fold(auth)), O.hostport(scheme, default, String.to_lower(auth)), S.serialized(S.host_port(scheme, default, String.to_lower(auth))), Equal.cong(String, Maybe<&2, String>, a => O.hostport(scheme, default, a), B.fold(auth), String.to_lower(auth), BT.fold_equiv(auth)), hostport_same(scheme, default, String.to_lower(auth)))
    case False{}: {==}

def tail_same(url: Bool, rest: String) -> {O.tail_ok(url, rest) == S.path_ok(url, rest) : Bool}:
  match url rest:
    case True{} _: {==}
    case False{} SNil{}: {==}
    case False{} SCon{c, t}: {==}

def split_auth_same(+scheme: String, +default: Nat, c: O.Cut, +url: Bool) -> {O.split_authority(scheme, default, c, url) == S.serialized(S.after_authority(scheme, default, to_part(c), url)) : Maybe<&2, String>}:
  match c:
    case O.Cut{+auth, +rest}: Equal.trans(Maybe<&2, String>, O.checked_tail(scheme, default, auth, O.tail_ok(url, rest)), O.checked_tail(scheme, default, auth, S.path_ok(url, rest)), S.serialized(S.checked(scheme, default, auth, S.path_ok(url, rest))), Equal.cong(Bool, Maybe<&2, String>, b => O.checked_tail(scheme, default, auth, b), O.tail_ok(url, rest), S.path_ok(url, rest), tail_same(url, rest)), checked_same(scheme, default, auth, S.path_ok(url, rest)))

def slashed_same(+scheme: String, +default: Nat, +r: String, +url: Bool, ok: Bool) -> {O.slashed(scheme, default, r, url, ok) == S.serialized(S.slashed(scheme, default, r, url, ok)) : Maybe<&2, String>}:
  match ok:
    case True{}: Equal.trans(Maybe<&2, String>, O.split_authority(scheme, default, O.authority(r), url), S.serialized(S.after_authority(scheme, default, to_part(O.authority(r)), url)), S.serialized(S.after_authority(scheme, default, S.authority(r), url)), split_auth_same(scheme, default, O.authority(r), url), Equal.cong(S.Split, Maybe<&2, String>, p => S.serialized(S.after_authority(scheme, default, p, url)), to_part(O.authority(r)), S.authority(r), authority_same(r)))
    case False{}: {==}

def slashes_same(+scheme: String, +default: Nat, rest: String, +url: Bool) -> {O.slashes(scheme, default, rest, url) == S.serialized(S.slashes(scheme, default, rest, url)) : Maybe<&2, String>}:
  match rest:
    case SNil{}: {==}
    case SCon{a, SNil{}}: {==}
    case SCon{+a, SCon{+b, +r}}: slashed_same(scheme, default, r, url, Char.is_eq(a, '/') && Char.is_eq(b, '/'))

def http_same(+rest: String, +url: Bool, is_http: Bool) -> {O.defaulted(O.web_http(is_http), rest, url) == S.serialized(S.known(S.http(is_http), rest, url)) : Maybe<&2, String>}:
  match is_http:
    case True{}: slashes_same("http", 80n, rest, url)
    case False{}: {==}

def web_same(+f: String, +rest: String, +url: Bool, is_https: Bool) -> {O.defaulted(O.web_https(f, is_https), rest, url) == S.serialized(S.known(S.https(f, is_https), rest, url)) : Maybe<&2, String>}:
  match is_https:
    case True{}: slashes_same("https", 443n, rest, url)
    case False{}: http_same(rest, url, String.eq(f, "http"))

def parse_cut_same(m: Maybe<&2, O.Cut>, +url: Bool) -> {O.parse_cut(m, url) == S.serialized(S.parse_split(to_split(m), url)) : Maybe<&2, String>}:
  match m:
    case None{}: {==}
    case Some{O.Cut{+s, +rest}}: Equal.trans(Maybe<&2, String>, O.defaulted(O.web(B.fold(s)), rest, url), O.defaulted(O.web(String.to_lower(s)), rest, url), S.serialized(S.known(S.scheme(String.to_lower(s)), rest, url)), Equal.cong(String, Maybe<&2, String>, f => O.defaulted(O.web(f), rest, url), B.fold(s), String.to_lower(s), BT.fold_equiv(s)), web_same(String.to_lower(s), rest, url, String.eq(String.to_lower(s), "https")))

def parse_same(+s: String, +url: Bool) -> {O.parse(s, url) == S.serialized(S.parse(s, url)) : Maybe<&2, String>}:
  Equal.trans(Maybe<&2, String>, O.parse_cut(O.cut(B.trim_text(s), ':'), url), O.parse_cut(O.cut(Trim.trim(s), ':'), url), S.serialized(S.parse(s, url)), Equal.cong(String, Maybe<&2, String>, x => O.parse_cut(O.cut(x, ':'), url), B.trim_text(s), Trim.trim(s), TrimProof.trim_text(s)),
    Equal.trans(Maybe<&2, String>, O.parse_cut(O.cut(Trim.trim(s), ':'), url), S.serialized(S.parse_split(to_split(O.cut(Trim.trim(s), ':')), url)), S.serialized(S.parse(s, url)), parse_cut_same(O.cut(Trim.trim(s), ':'), url), Equal.cong(Maybe<&2, S.Split>, Maybe<&2, String>, m => S.serialized(S.parse_split(m, url)), to_split(O.cut(Trim.trim(s), ':')), S.split_at(Trim.trim(s), ':'), cut_same(Trim.trim(s), ':'))))

def canonical_same(+s: String) -> {O.canonical(s) == S.canonical(s) : Maybe<&2, String>}:
  parse_same(s, False{})

def of_url_same(+s: String) -> {O.of_url(s) == S.of_url(s) : Maybe<&2, String>}:
  parse_same(s, True{})

def of_host_same(+scheme: String, +host: String) -> {O.of_host(scheme, host) == S.of_host(scheme, host) : Maybe<&2, String>}:
  Equal.trans(Maybe<&2, String>, O.parse(scheme ++ "://" ++ B.trim_text(host), False{}), O.parse(scheme ++ "://" ++ Trim.trim(host), False{}), S.of_host(scheme, host), Equal.cong(String, Maybe<&2, String>, x => O.parse(scheme ++ "://" ++ x, False{}), B.trim_text(host), Trim.trim(host), TrimProof.trim_text(host)), parse_same(scheme ++ "://" ++ Trim.trim(host), False{}))

# ---- Reading back: serialization keeps scheme, host and port apart ----

def shift(+a: String, m: Maybe<&2, S.Split>) -> Maybe<&2, S.Split>:
  match m:
    case None{}: None{}
    case Some{S.Split{x, z}}: Some{S.Split{a ++ x, z}}

# The text before a separator holds no separator: splitting it extended by
# any y finds y's first separator.
def Free(m: Maybe<&2, S.Split>, +sep: Char) -> Type:
  match m:
    case None{}: Unit
    case Some{S.Split{a, b}}: @y:String -> {S.split_at(a ++ y, sep) == shift(a, S.split_at(y, sep)) : Maybe<&2, S.Split>}

def shift_nil(m: Maybe<&2, S.Split>) -> {shift("", m) == m : Maybe<&2, S.Split>}:
  match m:
    case None{}: {==}
    case Some{S.Split{x, z}}: {==}

def shift_cons(+c: Char, +a: String, m: Maybe<&2, S.Split>) -> {S.split_prepend(c, shift(a, m)) == shift(SCon{c, a}, m) : Maybe<&2, S.Split>}:
  match m:
    case None{}: {==}
    case Some{S.Split{x, z}}: {==}

def free_step(+c: Char, +sep: Char, m: Maybe<&2, S.Split>, fr: Free(m, sep), +e: {Char.is_eq(c, sep) == False{} : Bool}) -> Free(S.split_prepend(c, m), sep):
  match m:
    case None{}: Unit{}
    case Some{S.Split{+a, +b}}:
      +y => Equal.trans(Maybe<&2, S.Split>, S.split_pick(c, a ++ y, S.split_at(a ++ y, sep), Char.is_eq(c, sep)), S.split_prepend(c, shift(a, S.split_at(y, sep))), shift(SCon{c, a}, S.split_at(y, sep)),
        Equal.trans(Maybe<&2, S.Split>, S.split_pick(c, a ++ y, S.split_at(a ++ y, sep), Char.is_eq(c, sep)), S.split_prepend(c, S.split_at(a ++ y, sep)), S.split_prepend(c, shift(a, S.split_at(y, sep))), Equal.cong(Bool, Maybe<&2, S.Split>, h => S.split_pick(c, a ++ y, S.split_at(a ++ y, sep), h), Char.is_eq(c, sep), False{}, e), Equal.cong(Maybe<&2, S.Split>, Maybe<&2, S.Split>, r => S.split_prepend(c, r), S.split_at(a ++ y, sep), shift(a, S.split_at(y, sep)), fr(y))),
        shift_cons(c, a, S.split_at(y, sep)))

def free_at(+c: Char, +t: String, +sep: Char, m: Maybe<&2, S.Split>, fr: Free(m, sep), h: Bool, e: {Char.is_eq(c, sep) == h : Bool}) -> Free(S.split_pick(c, t, m, h), sep):
  match h:
    case True{}: +y => Equal.sym(Maybe<&2, S.Split>, shift("", S.split_at(y, sep)), S.split_at(y, sep), shift_nil(S.split_at(y, sep)))
    case False{}: free_step(c, sep, m, fr, e)

def free(t: String, +sep: Char) -> Free(S.split_at(t, sep), sep):
  match t:
    case SNil{}: Unit{}
    case SCon{+c, +u}: free_at(c, u, sep, S.split_at(u, sep), free(u, sep), Char.is_eq(c, sep), {==})

def port_back(q: Maybe<&2, String>) -> {S.read_port(S.suffix(q)) == Some{q} : Maybe<&2, Maybe<&2, String>>}:
  match q:
    case None{}: {==}
    case Some{p}: {==}

def bracket_read(+name: String, +inside: String, +q: Maybe<&2, String>, fr: @y:String -> {S.split_at(inside ++ y, ']') == shift(inside, S.split_at(y, ']')) : Maybe<&2, S.Split>}, sch: @y:String -> {S.read(name ++ "://" ++ y) == S.read_authority(name, y) : Maybe<&2, S.Origin>}) -> {S.read(S.serialize(S.Origin{name, "[" ++ inside ++ "]", q})) == Some{S.Origin{name, "[" ++ inside ++ "]", q}} : Maybe<&2, S.Origin>}:
  Equal.trans(Maybe<&2, S.Origin>, S.read(name ++ "://" ++ (("[" ++ inside ++ "]") ++ S.suffix(q))), S.read_authority(name, ("[" ++ inside ++ "]") ++ S.suffix(q)), Some{S.Origin{name, "[" ++ inside ++ "]", q}}, sch(("[" ++ inside ++ "]") ++ S.suffix(q)),
    Equal.trans(Maybe<&2, S.Origin>, S.read_bracket(name, S.split_at((inside ++ "]") ++ S.suffix(q), ']')), S.read_bracket(name, S.split_at(inside ++ ("]" ++ S.suffix(q)), ']')), Some{S.Origin{name, "[" ++ inside ++ "]", q}}, Equal.cong(String, Maybe<&2, S.Origin>, x => S.read_bracket(name, S.split_at(x, ']')), (inside ++ "]") ++ S.suffix(q), inside ++ ("]" ++ S.suffix(q)), TP.string_append_assoc(inside, "]", S.suffix(q))),
      Equal.trans(Maybe<&2, S.Origin>, S.read_bracket(name, S.split_at(inside ++ ("]" ++ S.suffix(q)), ']')), S.read_bracket(name, shift(inside, S.split_at("]" ++ S.suffix(q), ']'))), Some{S.Origin{name, "[" ++ inside ++ "]", q}}, Equal.cong(Maybe<&2, S.Split>, Maybe<&2, S.Origin>, m => S.read_bracket(name, m), S.split_at(inside ++ ("]" ++ S.suffix(q)), ']'), shift(inside, S.split_at("]" ++ S.suffix(q), ']')), fr("]" ++ S.suffix(q))),
        Equal.trans(Maybe<&2, S.Origin>, S.read_with(name, "[" ++ ((inside ++ "") ++ "]"), S.read_port(S.suffix(q))), S.read_with(name, "[" ++ ((inside ++ "") ++ "]"), Some{q}), Some{S.Origin{name, "[" ++ inside ++ "]", q}}, Equal.cong(Maybe<&2, Maybe<&2, String>>, Maybe<&2, S.Origin>, p => S.read_with(name, "[" ++ ((inside ++ "") ++ "]"), p), S.read_port(S.suffix(q)), Some{q}, port_back(q)), Equal.cong(String, Maybe<&2, S.Origin>, x => Some{S.Origin{name, "[" ++ (x ++ "]"), q}}, inside ++ "", inside, TP.string_append_nil(inside))))))

def bracket_leaf(+name: String, +inside: String, v: Bool, p: Maybe<&2, Maybe<&2, String>>, fr: @y:String -> {S.split_at(inside ++ y, ']') == shift(inside, S.split_at(y, ']')) : Maybe<&2, S.Split>}, sch: @y:String -> {S.read(name ++ "://" ++ y) == S.read_authority(name, y) : Maybe<&2, S.Origin>}) -> {S.read_back(S.serialized(S.origin(name, S.valid_host("[" ++ inside ++ "]", v), p))) == S.origin(name, S.valid_host("[" ++ inside ++ "]", v), p) : Maybe<&2, S.Origin>}:
  match v p:
    case False{} _: {==}
    case True{} None{}: {==}
    case True{} Some{+q}: bracket_read(name, inside, q, fr, sch)

def back_bracket_port(+name: String, +default: Nat, +inside: String, +p: String, colon: Bool, fr: @y:String -> {S.split_at(inside ++ y, ']') == shift(inside, S.split_at(y, ']')) : Maybe<&2, S.Split>}, sch: @y:String -> {S.read(name ++ "://" ++ y) == S.read_authority(name, y) : Maybe<&2, S.Origin>}) -> {S.read_back(S.serialized(S.bracket_port(name, default, inside, p, colon))) == S.bracket_port(name, default, inside, p, colon) : Maybe<&2, S.Origin>}:
  match colon:
    case True{}: bracket_leaf(name, inside, S.ipv6(inside), S.port(p, default), fr, sch)
    case False{}: {==}

def back_bracket_rest(+name: String, +default: Nat, +inside: String, rest: String, fr: @y:String -> {S.split_at(inside ++ y, ']') == shift(inside, S.split_at(y, ']')) : Maybe<&2, S.Split>}, sch: @y:String -> {S.read(name ++ "://" ++ y) == S.read_authority(name, y) : Maybe<&2, S.Origin>}) -> {S.read_back(S.serialized(S.bracket_rest(name, default, inside, rest))) == S.bracket_rest(name, default, inside, rest) : Maybe<&2, S.Origin>}:
  match rest:
    case SNil{}: bracket_leaf(name, inside, S.ipv6(inside), Some{None{}}, fr, sch)
    case SCon{+c, +p}: back_bracket_port(name, default, inside, p, Char.is_eq(c, ':'), fr, sch)

def back_bracketed(+name: String, +default: Nat, m: Maybe<&2, S.Split>, fr: Free(m, ']'), sch: @y:String -> {S.read(name ++ "://" ++ y) == S.read_authority(name, y) : Maybe<&2, S.Origin>}) -> {S.read_back(S.serialized(S.bracketed(name, default, m))) == S.bracketed(name, default, m) : Maybe<&2, S.Origin>}:
  match m:
    case None{}: {==}
    case Some{S.Split{+inside, +rest}}: back_bracket_rest(name, default, inside, rest, fr, sch)

# Reading a host that starts with c, neither '[' nor ':'.
def name_read(+name: String, +c: Char, +rest: String, +eb: {Char.is_eq(c, '[') == False{} : Bool}, +ec: {Char.is_eq(c, ':') == False{} : Bool}) -> {S.read_authority(name, SCon{c, rest}) == S.read_name(name, SCon{c, rest}, S.split_prepend(c, S.split_at(rest, ':'))) : Maybe<&2, S.Origin>}:
  %Equal.sym(Bool, Char.is_eq(c, '['), False{}, eb) : {S.read_at(name, c, rest, _) == S.read_name(name, SCon{c, rest}, S.split_prepend(c, S.split_at(rest, ':'))) : Maybe<&2, S.Origin>}
  %Equal.sym(Bool, Char.is_eq(c, ':'), False{}, ec) : {S.read_name(name, SCon{c, rest}, S.split_pick(c, rest, S.split_at(rest, ':'), _)) == S.read_name(name, SCon{c, rest}, S.split_prepend(c, S.split_at(rest, ':'))) : Maybe<&2, S.Origin>}
  {==}

def name_none_leaf(+name: String, +c: Char, +t: String, v: Bool, em: {S.split_at(t, ':') == None{} : Maybe<&2, S.Split>}, +eb: {Char.is_eq(c, '[') == False{} : Bool}, +ec: {Char.is_eq(c, ':') == False{} : Bool}, sch: @y:String -> {S.read(name ++ "://" ++ y) == S.read_authority(name, y) : Maybe<&2, S.Origin>}) -> {S.read_back(S.serialized(S.origin(name, S.valid_host(SCon{c, t}, v), Some{None{}}))) == S.origin(name, S.valid_host(SCon{c, t}, v), Some{None{}}) : Maybe<&2, S.Origin>}:
  match v:
    case False{}: {==}
    case True{}:
      Equal.trans(Maybe<&2, S.Origin>, S.read(name ++ "://" ++ (SCon{c, t} ++ "")), S.read_authority(name, SCon{c, t} ++ ""), Some{S.Origin{name, SCon{c, t}, None{}}}, sch(SCon{c, t} ++ ""),
        Equal.trans(Maybe<&2, S.Origin>, S.read_authority(name, SCon{c, t ++ ""}), S.read_authority(name, SCon{c, t}), Some{S.Origin{name, SCon{c, t}, None{}}}, Equal.cong(String, Maybe<&2, S.Origin>, x => S.read_authority(name, SCon{c, x}), t ++ "", t, TP.string_append_nil(t)),
          Equal.trans(Maybe<&2, S.Origin>, S.read_authority(name, SCon{c, t}), S.read_name(name, SCon{c, t}, S.split_prepend(c, S.split_at(t, ':'))), Some{S.Origin{name, SCon{c, t}, None{}}}, name_read(name, c, t, eb, ec), Equal.cong(Maybe<&2, S.Split>, Maybe<&2, S.Origin>, m => S.read_name(name, SCon{c, t}, S.split_prepend(c, m)), S.split_at(t, ':'), None{}, em))))

def name_port_read(+name: String, +c: Char, +a: String, q: Maybe<&2, String>) -> {S.read_name(name, SCon{c, a ++ S.suffix(q)}, S.split_prepend(c, shift(a, S.split_at(S.suffix(q), ':')))) == Some{S.Origin{name, SCon{c, a}, q}} : Maybe<&2, S.Origin>}:
  match q:
    case None{}: Equal.cong(String, Maybe<&2, S.Origin>, x => Some{S.Origin{name, SCon{c, x}, None{}}}, a ++ "", a, TP.string_append_nil(a))
    case Some{+d}: Equal.cong(String, Maybe<&2, S.Origin>, x => Some{S.Origin{name, SCon{c, x}, Some{d}}}, a ++ "", a, TP.string_append_nil(a))

def name_some_leaf(+name: String, +c: Char, +a: String, v: Bool, p: Maybe<&2, Maybe<&2, String>>, fr: @y:String -> {S.split_at(a ++ y, ':') == shift(a, S.split_at(y, ':')) : Maybe<&2, S.Split>}, +eb: {Char.is_eq(c, '[') == False{} : Bool}, +ec: {Char.is_eq(c, ':') == False{} : Bool}, sch: @y:String -> {S.read(name ++ "://" ++ y) == S.read_authority(name, y) : Maybe<&2, S.Origin>}) -> {S.read_back(S.serialized(S.origin(name, S.valid_host(SCon{c, a}, v), p))) == S.origin(name, S.valid_host(SCon{c, a}, v), p) : Maybe<&2, S.Origin>}:
  match v p:
    case False{} _: {==}
    case True{} None{}: {==}
    case True{} Some{+q}:
      Equal.trans(Maybe<&2, S.Origin>, S.read(name ++ "://" ++ (SCon{c, a} ++ S.suffix(q))), S.read_authority(name, SCon{c, a} ++ S.suffix(q)), Some{S.Origin{name, SCon{c, a}, q}}, sch(SCon{c, a} ++ S.suffix(q)),
        Equal.trans(Maybe<&2, S.Origin>, S.read_authority(name, SCon{c, a ++ S.suffix(q)}), S.read_name(name, SCon{c, a ++ S.suffix(q)}, S.split_prepend(c, S.split_at(a ++ S.suffix(q), ':'))), Some{S.Origin{name, SCon{c, a}, q}}, name_read(name, c, a ++ S.suffix(q), eb, ec),
          Equal.trans(Maybe<&2, S.Origin>, S.read_name(name, SCon{c, a ++ S.suffix(q)}, S.split_prepend(c, S.split_at(a ++ S.suffix(q), ':'))), S.read_name(name, SCon{c, a ++ S.suffix(q)}, S.split_prepend(c, shift(a, S.split_at(S.suffix(q), ':')))), Some{S.Origin{name, SCon{c, a}, q}}, Equal.cong(Maybe<&2, S.Split>, Maybe<&2, S.Origin>, m => S.read_name(name, SCon{c, a ++ S.suffix(q)}, S.split_prepend(c, m)), S.split_at(a ++ S.suffix(q), ':'), shift(a, S.split_at(S.suffix(q), ':')), fr(S.suffix(q))), name_port_read(name, c, a, q))))

def back_named(+name: String, +default: Nat, +c: Char, +t: String, m: Maybe<&2, S.Split>, em: {S.split_at(t, ':') == m : Maybe<&2, S.Split>}, fr: Free(m, ':'), colon: Bool, +ec: {Char.is_eq(c, ':') == colon : Bool}, +eb: {Char.is_eq(c, '[') == False{} : Bool}, sch: @y:String -> {S.read(name ++ "://" ++ y) == S.read_authority(name, y) : Maybe<&2, S.Origin>}) -> {S.read_back(S.serialized(S.named(name, default, SCon{c, t}, S.split_pick(c, t, m, colon)))) == S.named(name, default, SCon{c, t}, S.split_pick(c, t, m, colon)) : Maybe<&2, S.Origin>}:
  match m colon:
    case None{} True{}: {==}
    case Some{S.Split{a, p}} True{}: {==}
    case None{} False{}: name_none_leaf(name, c, t, S.name_host(SCon{c, t}), em, eb, ec, sch)
    case Some{S.Split{+a, +p}} False{}: name_some_leaf(name, c, a, S.name_host(SCon{c, a}), S.port(p, default), fr, eb, ec, sch)

def back_at(+name: String, +default: Nat, +c: Char, +t: String, bracket: Bool, +eb: {Char.is_eq(c, '[') == bracket : Bool}, sch: @y:String -> {S.read(name ++ "://" ++ y) == S.read_authority(name, y) : Maybe<&2, S.Origin>}) -> {S.read_back(S.serialized(S.host_at(name, default, c, t, bracket))) == S.host_at(name, default, c, t, bracket) : Maybe<&2, S.Origin>}:
  match bracket:
    case True{}: back_bracketed(name, default, S.split_at(t, ']'), free(t, ']'), sch)
    case False{}: back_named(name, default, c, t, S.split_at(t, ':'), {==}, free(t, ':'), Char.is_eq(c, ':'), {==}, eb, sch)

def back_host_port(+name: String, +default: Nat, auth: String, sch: @y:String -> {S.read(name ++ "://" ++ y) == S.read_authority(name, y) : Maybe<&2, S.Origin>}) -> {S.read_back(S.serialized(S.host_port(name, default, auth))) == S.host_port(name, default, auth) : Maybe<&2, S.Origin>}:
  match auth:
    case SNil{}: {==}
    case SCon{+c, +t}: back_at(name, default, c, t, Char.is_eq(c, '['), {==}, sch)

def back_checked(+name: String, +default: Nat, +auth: String, ok: Bool, sch: @y:String -> {S.read(name ++ "://" ++ y) == S.read_authority(name, y) : Maybe<&2, S.Origin>}) -> {S.read_back(S.serialized(S.checked(name, default, auth, ok))) == S.checked(name, default, auth, ok) : Maybe<&2, S.Origin>}:
  match ok:
    case True{}: back_host_port(name, default, String.to_lower(auth), sch)
    case False{}: {==}

def back_after(+name: String, +default: Nat, parts: S.Split, +url: Bool, sch: @y:String -> {S.read(name ++ "://" ++ y) == S.read_authority(name, y) : Maybe<&2, S.Origin>}) -> {S.read_back(S.serialized(S.after_authority(name, default, parts, url))) == S.after_authority(name, default, parts, url) : Maybe<&2, S.Origin>}:
  match parts:
    case S.Split{+auth, +rest}: back_checked(name, default, auth, S.path_ok(url, rest), sch)

def back_slashed(+name: String, +default: Nat, +r: String, +url: Bool, ok: Bool, sch: @y:String -> {S.read(name ++ "://" ++ y) == S.read_authority(name, y) : Maybe<&2, S.Origin>}) -> {S.read_back(S.serialized(S.slashed(name, default, r, url, ok))) == S.slashed(name, default, r, url, ok) : Maybe<&2, S.Origin>}:
  match ok:
    case True{}: back_after(name, default, S.authority(r), url, sch)
    case False{}: {==}

def back_slashes(+name: String, +default: Nat, rest: String, +url: Bool, sch: @y:String -> {S.read(name ++ "://" ++ y) == S.read_authority(name, y) : Maybe<&2, S.Origin>}) -> {S.read_back(S.serialized(S.slashes(name, default, rest, url))) == S.slashes(name, default, rest, url) : Maybe<&2, S.Origin>}:
  match rest:
    case SNil{}: {==}
    case SCon{a, SNil{}}: {==}
    case SCon{+a, SCon{+b, +r}}: back_slashed(name, default, r, url, Char.is_eq(a, '/') && Char.is_eq(b, '/'), sch)

def back_http(+rest: String, +url: Bool, is_http: Bool) -> {S.read_back(S.serialized(S.known(S.http(is_http), rest, url))) == S.known(S.http(is_http), rest, url) : Maybe<&2, S.Origin>}:
  match is_http:
    case True{}: back_slashes("http", 80n, rest, url, y => {==})
    case False{}: {==}

def back_scheme(+f: String, +rest: String, +url: Bool, is_https: Bool) -> {S.read_back(S.serialized(S.known(S.https(f, is_https), rest, url))) == S.known(S.https(f, is_https), rest, url) : Maybe<&2, S.Origin>}:
  match is_https:
    case True{}: back_slashes("https", 443n, rest, url, y => {==})
    case False{}: back_http(rest, url, String.eq(f, "http"))

def back_parse_split(m: Maybe<&2, S.Split>, +url: Bool) -> {S.read_back(S.serialized(S.parse_split(m, url))) == S.parse_split(m, url) : Maybe<&2, S.Origin>}:
  match m:
    case None{}: {==}
    case Some{S.Split{+s, +rest}}: back_scheme(String.to_lower(s), rest, url, String.eq(String.to_lower(s), "https"))

def read_back(+s: String, +url: Bool) -> {S.read_back(S.serialized(S.parse(s, url))) == S.parse(s, url) : Maybe<&2, S.Origin>}:
  back_parse_split(S.split_at(Trim.trim(s), ':'), url)

# ---- Laws ----

def Laws.origin_canonical_spec(s): canonical_same(s)
def Laws.origin_of_url_spec(s): of_url_same(s)
def Laws.origin_of_host_spec(scheme, host): of_host_same(scheme, host)
def Laws.origin_read_back(s, url): read_back(s, url)
def Laws.origin_rejects_invalid_ipv6(): {==}
def Laws.origin_rejects_ipv6_word(): {==}
def Laws.origin_rejects_ipv4_shorthand(): {==}
def Laws.origin_keeps_ipv4_quad(): {==}
def Laws.origin_rejects_uncompressed_ipv6(): {==}
def Laws.origin_keeps_compressed_ipv6(): {==}
def Laws.origin_rejects_invalid_ipv6_port(): {==}
def Laws.origin_default_port(): {==}
def Laws.origin_keeps_other_port(): {==}
def Laws.origin_keeps_scheme(): {==}
