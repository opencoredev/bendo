# BND-93: the upstream authority parser (src/http/upstream.bend) meets
# proof/upstream-host-spec.bend, and the Host value sent upstream reads back
# as the endpoint it came from. The stage lemmas reuse BND-85's origin
# lemmas (proof/origin.bend) for splitting, IPv6, names and digits.
import Base
import ../src/http/origin.bend as O
import ../src/http/upstream.bend as U
import ./origin-spec.bend as S
import ./origin.bend as OP
import ./text.bend as TP
import ./upstream-host-spec.bend as US

# ---- The parser equals the specification ----

def labels_same(ls: List<&2, String>) -> {U.labels_ok(ls) == US.labels(ls) : Bool}:
  match ls:
    case Nil{}: {==}
    case +l <> +t: Equal.cong(Bool, Bool, x => U.label_ok(l) && x, U.labels_ok(t), US.labels(t), labels_same(t))

def name_same(+h: String) -> {U.name_ok(h) == US.name(h) : Bool}:
  OP.and_same(O.name_host(h), S.name_host(h), U.labels_ok(String.split(h, '.')), US.labels(String.split(h, '.')), OP.name_host_same(h), labels_same(String.split(h, '.')))

def range_same(n: Maybe<&2, Nat>) -> {U.port_range(n) == US.in_range(n) : Bool}:
  match n:
    case None{}: {==}
    case Some{v}: {==}

def read_same(+p: String, short: Bool) -> {U.port_read(p, short) == US.port_digits(p, short) : Bool}:
  match short:
    case True{}: range_same(Nat.read(p))
    case False{}: {==}

def port_same(+p: String) -> {U.port_ok(p) == US.port(p) : Bool}:
  Equal.trans(Bool, U.port_read(p, O.digits(p) && Nat.is_lt(0n, String.length(p)) && Nat.is_le(String.length(p), 5n)), U.port_read(p, S.decimals(p) && Nat.is_lt(0n, String.length(p)) && Nat.is_le(String.length(p), 5n)), US.port(p),
    Equal.cong(Bool, Bool, x => U.port_read(p, x && Nat.is_lt(0n, String.length(p)) && Nat.is_le(String.length(p), 5n)), O.digits(p), S.decimals(p), OP.digits_same(p)),
    read_same(p, S.decimals(p) && Nat.is_lt(0n, String.length(p)) && Nat.is_le(String.length(p), 5n)))

def made_eq(+h: U.Host, +p: Maybe<&2, String>, a: Bool) -> {U.endpoint(h, p, a) == US.made(h, p, a) : Maybe<&2, U.Endpoint>}:
  match a:
    case True{}: {==}
    case False{}: {==}

def leaf(+h: U.Host, +p: Maybe<&2, String>, +a: Bool, +b: Bool, e: {a == b : Bool}) -> {U.endpoint(h, p, a) == US.made(h, p, b) : Maybe<&2, U.Endpoint>}:
  Equal.trans(Maybe<&2, U.Endpoint>, U.endpoint(h, p, a), US.made(h, p, a), US.made(h, p, b), made_eq(h, p, a), Equal.cong(Bool, Maybe<&2, U.Endpoint>, x => US.made(h, p, x), a, b, e))

def bracket_port_same(+inside: String, +p: String, colon: Bool) -> {U.bracket_port(inside, p, colon) == US.v6_port(inside, p, colon) : Maybe<&2, U.Endpoint>}:
  match colon:
    case True{}: leaf(U.HostV6{inside}, Some{p}, O.ipv6(inside) && U.port_ok(p), S.ipv6(inside) && US.port(p), OP.and_same(O.ipv6(inside), S.ipv6(inside), U.port_ok(p), US.port(p), OP.ipv6_same(inside), port_same(p)))
    case False{}: {==}

def bracket_rest_same(+inside: String, rest: String) -> {U.bracket_rest(inside, rest) == US.v6_rest(inside, rest) : Maybe<&2, U.Endpoint>}:
  match rest:
    case SNil{}: leaf(U.HostV6{inside}, None{}, O.ipv6(inside), S.ipv6(inside), OP.ipv6_same(inside))
    case SCon{+c, +p}: bracket_port_same(inside, p, Char.is_eq(c, ':'))

def bracketed_same(m: Maybe<&2, O.Cut>) -> {U.bracketed(m) == US.v6(OP.to_split(m)) : Maybe<&2, U.Endpoint>}:
  match m:
    case None{}: {==}
    case Some{O.Cut{+inside, +rest}}: bracket_rest_same(inside, rest)

def named_same(+whole: String, m: Maybe<&2, O.Cut>) -> {U.named_parts(whole, m) == US.named(whole, OP.to_split(m)) : Maybe<&2, U.Endpoint>}:
  match m:
    case None{}: leaf(U.HostName{whole}, None{}, U.name_ok(whole), US.name(whole), name_same(whole))
    case Some{O.Cut{+h, +p}}: leaf(U.HostName{h}, Some{p}, U.name_ok(h) && U.port_ok(p), US.name(h) && US.port(p), OP.and_same(U.name_ok(h), US.name(h), U.port_ok(p), US.port(p), name_same(h), port_same(p)))

def at_same(+c: Char, +t: String, bracket: Bool) -> {U.endpoint_at(c, t, bracket) == US.at(c, t, bracket) : Maybe<&2, U.Endpoint>}:
  match bracket:
    case True{}:
      Equal.trans(Maybe<&2, U.Endpoint>, U.bracketed(O.cut(t, ']')), US.v6(OP.to_split(O.cut(t, ']'))), US.v6(S.split_at(t, ']')), bracketed_same(O.cut(t, ']')),
        Equal.cong(Maybe<&2, S.Split>, Maybe<&2, U.Endpoint>, m => US.v6(m), OP.to_split(O.cut(t, ']')), S.split_at(t, ']'), OP.cut_same(t, ']')))
    case False{}:
      Equal.trans(Maybe<&2, U.Endpoint>, U.named_parts(SCon{c, t}, O.cut(SCon{c, t}, ':')), US.named(SCon{c, t}, OP.to_split(O.cut(SCon{c, t}, ':'))), US.named(SCon{c, t}, S.split_at(SCon{c, t}, ':')), named_same(SCon{c, t}, O.cut(SCon{c, t}, ':')),
        Equal.cong(Maybe<&2, S.Split>, Maybe<&2, U.Endpoint>, m => US.named(SCon{c, t}, m), OP.to_split(O.cut(SCon{c, t}, ':')), S.split_at(SCon{c, t}, ':'), OP.cut_same(SCon{c, t}, ':')))

def authority_same(s: String) -> {U.read_authority(s) == US.authority(s) : Maybe<&2, U.Endpoint>}:
  match s:
    case SNil{}: {==}
    case SCon{+c, +t}: at_same(c, t, Char.is_eq(c, '['))

# ---- The Host value reads back as its endpoint ----

def reread_spec(m: Maybe<&2, U.Endpoint>) -> Maybe<&2, U.Endpoint>:
  match m:
    case None{}: None{}
    case Some{e}: US.authority(U.host_header(e))

def v6_none(+inside: String, v: Bool, ev: {S.ipv6(inside) == v : Bool}, fr: @y:String -> {S.split_at(inside ++ y, ']') == OP.shift(inside, S.split_at(y, ']')) : Maybe<&2, S.Split>}) -> {reread_spec(US.made(U.HostV6{inside}, None{}, v)) == US.made(U.HostV6{inside}, None{}, v) : Maybe<&2, U.Endpoint>}:
  match v:
    case False{}: {==}
    case True{}:
      Equal.trans(Maybe<&2, U.Endpoint>, US.v6(S.split_at((inside ++ "]") ++ "", ']')), US.v6(S.split_at(inside ++ "]", ']')), Some{U.Endpoint{U.HostV6{inside}, None{}}},
        Equal.cong(String, Maybe<&2, U.Endpoint>, x => US.v6(S.split_at(x, ']')), (inside ++ "]") ++ "", inside ++ "]", TP.string_append_assoc(inside, "]", "")),
        Equal.trans(Maybe<&2, U.Endpoint>, US.v6(S.split_at(inside ++ "]", ']')), US.v6(OP.shift(inside, S.split_at("]", ']'))), Some{U.Endpoint{U.HostV6{inside}, None{}}},
          Equal.cong(Maybe<&2, S.Split>, Maybe<&2, U.Endpoint>, m => US.v6(m), S.split_at(inside ++ "]", ']'), OP.shift(inside, S.split_at("]", ']')), fr("]")),
          Equal.trans(Maybe<&2, U.Endpoint>, US.made(U.HostV6{inside ++ ""}, None{}, S.ipv6(inside ++ "")), US.made(U.HostV6{inside}, None{}, S.ipv6(inside)), Some{U.Endpoint{U.HostV6{inside}, None{}}},
            Equal.cong(String, Maybe<&2, U.Endpoint>, x => US.made(U.HostV6{x}, None{}, S.ipv6(x)), inside ++ "", inside, TP.string_append_nil(inside)),
            Equal.cong(Bool, Maybe<&2, U.Endpoint>, b => US.made(U.HostV6{inside}, None{}, b), S.ipv6(inside), True{}, ev))))

def v6_some(+inside: String, +p: String, v: Bool, ev: {S.ipv6(inside) && US.port(p) == v : Bool}, fr: @y:String -> {S.split_at(inside ++ y, ']') == OP.shift(inside, S.split_at(y, ']')) : Maybe<&2, S.Split>}) -> {reread_spec(US.made(U.HostV6{inside}, Some{p}, v)) == US.made(U.HostV6{inside}, Some{p}, v) : Maybe<&2, U.Endpoint>}:
  match v:
    case False{}: {==}
    case True{}:
      Equal.trans(Maybe<&2, U.Endpoint>, US.v6(S.split_at((inside ++ "]") ++ (":" ++ p), ']')), US.v6(S.split_at(inside ++ ("]" ++ (":" ++ p)), ']')), Some{U.Endpoint{U.HostV6{inside}, Some{p}}},
        Equal.cong(String, Maybe<&2, U.Endpoint>, x => US.v6(S.split_at(x, ']')), (inside ++ "]") ++ (":" ++ p), inside ++ ("]" ++ (":" ++ p)), TP.string_append_assoc(inside, "]", ":" ++ p)),
        Equal.trans(Maybe<&2, U.Endpoint>, US.v6(S.split_at(inside ++ ("]" ++ (":" ++ p)), ']')), US.v6(OP.shift(inside, S.split_at("]" ++ (":" ++ p), ']'))), Some{U.Endpoint{U.HostV6{inside}, Some{p}}},
          Equal.cong(Maybe<&2, S.Split>, Maybe<&2, U.Endpoint>, m => US.v6(m), S.split_at(inside ++ ("]" ++ (":" ++ p)), ']'), OP.shift(inside, S.split_at("]" ++ (":" ++ p), ']')), fr("]" ++ (":" ++ p))),
          Equal.trans(Maybe<&2, U.Endpoint>, US.made(U.HostV6{inside ++ ""}, Some{p}, S.ipv6(inside ++ "") && US.port(p)), US.made(U.HostV6{inside}, Some{p}, S.ipv6(inside) && US.port(p)), Some{U.Endpoint{U.HostV6{inside}, Some{p}}},
            Equal.cong(String, Maybe<&2, U.Endpoint>, x => US.made(U.HostV6{x}, Some{p}, S.ipv6(x) && US.port(p)), inside ++ "", inside, TP.string_append_nil(inside)),
            Equal.cong(Bool, Maybe<&2, U.Endpoint>, b => US.made(U.HostV6{inside}, Some{p}, b), S.ipv6(inside) && US.port(p), True{}, ev))))

def back_v6_port(+inside: String, +p: String, colon: Bool, fr: @y:String -> {S.split_at(inside ++ y, ']') == OP.shift(inside, S.split_at(y, ']')) : Maybe<&2, S.Split>}) -> {reread_spec(US.v6_port(inside, p, colon)) == US.v6_port(inside, p, colon) : Maybe<&2, U.Endpoint>}:
  match colon:
    case True{}: v6_some(inside, p, S.ipv6(inside) && US.port(p), {==}, fr)
    case False{}: {==}

def back_v6_rest(+inside: String, rest: String, fr: @y:String -> {S.split_at(inside ++ y, ']') == OP.shift(inside, S.split_at(y, ']')) : Maybe<&2, S.Split>}) -> {reread_spec(US.v6_rest(inside, rest)) == US.v6_rest(inside, rest) : Maybe<&2, U.Endpoint>}:
  match rest:
    case SNil{}: v6_none(inside, S.ipv6(inside), {==}, fr)
    case SCon{+c, +p}: back_v6_port(inside, p, Char.is_eq(c, ':'), fr)

def back_v6(m: Maybe<&2, S.Split>, fr: OP.Free(m, ']')) -> {reread_spec(US.v6(m)) == US.v6(m) : Maybe<&2, U.Endpoint>}:
  match m:
    case None{}: {==}
    case Some{S.Split{+inside, +rest}}: back_v6_rest(inside, rest, fr)

def name_none(+c: Char, +t: String, v: Bool, ev: {US.name(SCon{c, t}) == v : Bool}, em: {S.split_at(t, ':') == None{} : Maybe<&2, S.Split>}, eb: {Char.is_eq(c, '[') == False{} : Bool}, ec: {Char.is_eq(c, ':') == False{} : Bool}) -> {reread_spec(US.made(U.HostName{SCon{c, t}}, None{}, v)) == US.made(U.HostName{SCon{c, t}}, None{}, v) : Maybe<&2, U.Endpoint>}:
  match v:
    case False{}: {==}
    case True{}:
      Equal.trans(Maybe<&2, U.Endpoint>, US.authority(SCon{c, t ++ ""}), US.authority(SCon{c, t}), Some{U.Endpoint{U.HostName{SCon{c, t}}, None{}}},
        Equal.cong(String, Maybe<&2, U.Endpoint>, x => US.authority(SCon{c, x}), t ++ "", t, TP.string_append_nil(t)),
        Equal.trans(Maybe<&2, U.Endpoint>, US.at(c, t, Char.is_eq(c, '[')), US.at(c, t, False{}), Some{U.Endpoint{U.HostName{SCon{c, t}}, None{}}},
          Equal.cong(Bool, Maybe<&2, U.Endpoint>, b => US.at(c, t, b), Char.is_eq(c, '['), False{}, eb),
          Equal.trans(Maybe<&2, U.Endpoint>, US.named(SCon{c, t}, S.split_pick(c, t, S.split_at(t, ':'), Char.is_eq(c, ':'))), US.named(SCon{c, t}, S.split_pick(c, t, S.split_at(t, ':'), False{})), Some{U.Endpoint{U.HostName{SCon{c, t}}, None{}}},
            Equal.cong(Bool, Maybe<&2, U.Endpoint>, b => US.named(SCon{c, t}, S.split_pick(c, t, S.split_at(t, ':'), b)), Char.is_eq(c, ':'), False{}, ec),
            Equal.trans(Maybe<&2, U.Endpoint>, US.named(SCon{c, t}, S.split_prepend(c, S.split_at(t, ':'))), US.named(SCon{c, t}, S.split_prepend(c, None{})), Some{U.Endpoint{U.HostName{SCon{c, t}}, None{}}},
              Equal.cong(Maybe<&2, S.Split>, Maybe<&2, U.Endpoint>, m => US.named(SCon{c, t}, S.split_prepend(c, m)), S.split_at(t, ':'), None{}, em),
              Equal.cong(Bool, Maybe<&2, U.Endpoint>, b => US.made(U.HostName{SCon{c, t}}, None{}, b), US.name(SCon{c, t}), True{}, ev)))))

def name_some(+c: Char, +a: String, +p: String, v: Bool, ev: {US.name(SCon{c, a}) && US.port(p) == v : Bool}, fr: @y:String -> {S.split_at(a ++ y, ':') == OP.shift(a, S.split_at(y, ':')) : Maybe<&2, S.Split>}, eb: {Char.is_eq(c, '[') == False{} : Bool}, ec: {Char.is_eq(c, ':') == False{} : Bool}) -> {reread_spec(US.made(U.HostName{SCon{c, a}}, Some{p}, v)) == US.made(U.HostName{SCon{c, a}}, Some{p}, v) : Maybe<&2, U.Endpoint>}:
  match v:
    case False{}: {==}
    case True{}:
      Equal.trans(Maybe<&2, U.Endpoint>, US.at(c, a ++ (":" ++ p), Char.is_eq(c, '[')), US.at(c, a ++ (":" ++ p), False{}), Some{U.Endpoint{U.HostName{SCon{c, a}}, Some{p}}},
        Equal.cong(Bool, Maybe<&2, U.Endpoint>, b => US.at(c, a ++ (":" ++ p), b), Char.is_eq(c, '['), False{}, eb),
        Equal.trans(Maybe<&2, U.Endpoint>, US.named(SCon{c, a ++ (":" ++ p)}, S.split_pick(c, a ++ (":" ++ p), S.split_at(a ++ (":" ++ p), ':'), Char.is_eq(c, ':'))), US.named(SCon{c, a ++ (":" ++ p)}, S.split_pick(c, a ++ (":" ++ p), S.split_at(a ++ (":" ++ p), ':'), False{})), Some{U.Endpoint{U.HostName{SCon{c, a}}, Some{p}}},
          Equal.cong(Bool, Maybe<&2, U.Endpoint>, b => US.named(SCon{c, a ++ (":" ++ p)}, S.split_pick(c, a ++ (":" ++ p), S.split_at(a ++ (":" ++ p), ':'), b)), Char.is_eq(c, ':'), False{}, ec),
          Equal.trans(Maybe<&2, U.Endpoint>, US.named(SCon{c, a ++ (":" ++ p)}, S.split_prepend(c, S.split_at(a ++ (":" ++ p), ':'))), US.named(SCon{c, a ++ (":" ++ p)}, S.split_prepend(c, OP.shift(a, S.split_at(":" ++ p, ':')))), Some{U.Endpoint{U.HostName{SCon{c, a}}, Some{p}}},
            Equal.cong(Maybe<&2, S.Split>, Maybe<&2, U.Endpoint>, m => US.named(SCon{c, a ++ (":" ++ p)}, S.split_prepend(c, m)), S.split_at(a ++ (":" ++ p), ':'), OP.shift(a, S.split_at(":" ++ p, ':')), fr(":" ++ p)),
            Equal.trans(Maybe<&2, U.Endpoint>, US.made(U.HostName{SCon{c, a ++ ""}}, Some{p}, US.name(SCon{c, a ++ ""}) && US.port(p)), US.made(U.HostName{SCon{c, a}}, Some{p}, US.name(SCon{c, a}) && US.port(p)), Some{U.Endpoint{U.HostName{SCon{c, a}}, Some{p}}},
              Equal.cong(String, Maybe<&2, U.Endpoint>, x => US.made(U.HostName{SCon{c, x}}, Some{p}, US.name(SCon{c, x}) && US.port(p)), a ++ "", a, TP.string_append_nil(a)),
              Equal.cong(Bool, Maybe<&2, U.Endpoint>, b => US.made(U.HostName{SCon{c, a}}, Some{p}, b), US.name(SCon{c, a}) && US.port(p), True{}, ev)))))

def back_named(+c: Char, +t: String, m: Maybe<&2, S.Split>, em: {S.split_at(t, ':') == m : Maybe<&2, S.Split>}, fr: OP.Free(m, ':'), colon: Bool, ec: {Char.is_eq(c, ':') == colon : Bool}, eb: {Char.is_eq(c, '[') == False{} : Bool}) -> {reread_spec(US.named(SCon{c, t}, S.split_pick(c, t, m, colon))) == US.named(SCon{c, t}, S.split_pick(c, t, m, colon)) : Maybe<&2, U.Endpoint>}:
  match m colon:
    case None{} True{}: {==}
    case Some{S.Split{a, p}} True{}: {==}
    case None{} False{}: name_none(c, t, US.name(SCon{c, t}), {==}, em, eb, ec)
    case Some{S.Split{+a, +p}} False{}: name_some(c, a, p, US.name(SCon{c, a}) && US.port(p), {==}, fr, eb, ec)

def back_at(+c: Char, +t: String, bracket: Bool, eb: {Char.is_eq(c, '[') == bracket : Bool}) -> {reread_spec(US.at(c, t, bracket)) == US.at(c, t, bracket) : Maybe<&2, U.Endpoint>}:
  match bracket:
    case True{}: back_v6(S.split_at(t, ']'), OP.free(t, ']'))
    case False{}: back_named(c, t, S.split_at(t, ':'), {==}, OP.free(t, ':'), Char.is_eq(c, ':'), {==}, eb)

def back_spec(s: String) -> {reread_spec(US.authority(s)) == US.authority(s) : Maybe<&2, U.Endpoint>}:
  match s:
    case SNil{}: {==}
    case SCon{+c, +t}: back_at(c, t, Char.is_eq(c, '['), {==})

def reread_same(m: Maybe<&2, U.Endpoint>) -> {US.reread(m) == reread_spec(m) : Maybe<&2, U.Endpoint>}:
  match m:
    case None{}: {==}
    case Some{e}: authority_same(U.host_header(e))

def round_trip(+s: String) -> {US.reread(U.read_authority(s)) == U.read_authority(s) : Maybe<&2, U.Endpoint>}:
  Equal.trans(Maybe<&2, U.Endpoint>, US.reread(U.read_authority(s)), US.reread(US.authority(s)), U.read_authority(s),
    Equal.cong(Maybe<&2, U.Endpoint>, Maybe<&2, U.Endpoint>, m => US.reread(m), U.read_authority(s), US.authority(s), authority_same(s)),
    Equal.trans(Maybe<&2, U.Endpoint>, US.reread(US.authority(s)), reread_spec(US.authority(s)), U.read_authority(s), reread_same(US.authority(s)),
      Equal.trans(Maybe<&2, U.Endpoint>, reread_spec(US.authority(s)), US.authority(s), U.read_authority(s), back_spec(s), Equal.sym(Maybe<&2, U.Endpoint>, U.read_authority(s), US.authority(s), authority_same(s)))))
