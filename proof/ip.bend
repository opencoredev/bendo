# BND-44: proofs of the CIDR, precedence and client-address laws.
import Base
import ../src/net/ip.bend as Ip
import ../src/net/conn_info.bend as Conn
import ./ip-spec.bend as Spec
import ./ip-laws.bend as Laws
import ./conn-entries.bend as Entries

def absurd(-A: Type, e: Empty) -> A:
  match e:

def false_true(e: {False{} == True{} : Bool}) -> Empty:
  %e : Bool.pick(Type, _, Empty, Unit)
  Unit{}

def and_left(+a: Bool, -b: Bool, e: {(a && b) == True{} : Bool}) -> {a == True{} : Bool}:
  match a:
    case True{}: {==}
    case False{}: e

def and_right(+a: Bool, -b: Bool, e: {(a && b) == True{} : Bool}) -> {b == True{} : Bool}:
  match a:
    case True{}: e
    case False{}: absurd({b == True{} : Bool}, false_true(e))

def and_intro(+a: Bool, +b: Bool, ea: {a == True{} : Bool}, eb: {b == True{} : Bool}) -> {(a && b) == True{} : Bool}:
  match a:
    case True{}: eb
    case False{}: ea

def bit_same(+x: Bool, +y: Bool, e: {Ip.bit_eq(x, y) == True{} : Bool}) -> {x == y : Bool}:
  match x y:
    case True{} True{}: {==}
    case False{} False{}: {==}
    case True{} False{}: absurd({True{} == False{} : Bool}, false_true(e))
    case False{} True{}: absurd({False{} == True{} : Bool}, false_true(e))

def bit_refl(+x: Bool) -> {Ip.bit_eq(x, x) == True{} : Bool}:
  match x:
    case True{}: {==}
    case False{}: {==}

def is_eq_refl(+n: Nat) -> {Nat.is_eq(n, n) == True{} : Bool}:
  match n:
    case 0n: {==}
    case 1n+k: is_eq_refl(k)

def from_some(m: Maybe<&2, Bool>, d: Bool) -> Bool:
  match m:
    case Some{x}: x
    case None{}: d

def some_inj(+x: Bool, +y: Bool, e: {Some{x} == Some{y} : Maybe<&2, Bool>}) -> {x == y : Bool}:
  Equal.cong(Maybe<&2, Bool>, Bool, m => from_some(m, x), Some{x}, Some{y}, e)

def width_same(+f: Ip.Family, +g: Ip.Family, e: {Ip.same_family(f, g) == True{} : Bool}) -> {Ip.width(f) == Ip.width(g) : Nat}:
  match f g:
    case Ip.V4{} Ip.V4{}: {==}
    case Ip.V6{} Ip.V6{}: {==}
    case Ip.V4{} Ip.V6{}: absurd({32n == 128n : Nat}, false_true(e))
    case Ip.V6{} Ip.V4{}: absurd({128n == 32n : Nat}, false_true(e))

# prefix(n, xs, ys) makes every index below n read the same element.
def prefix_bits(+n: Nat, +xs: List<&2, Bool>, +ys: List<&2, Bool>, e: {Ip.prefix(n, xs, ys) == True{} : Bool}, +i: Nat, lt: {Nat.is_lt(i, n) == True{} : Bool}) -> {List.get(&2, Bool, xs, i) == List.get(&2, Bool, ys, i) : Maybe<&2, Bool>}:
  match n xs ys:
    case 0n _ _:
      match i:
        case 0n: absurd({List.get(&2, Bool, xs, 0n) == List.get(&2, Bool, ys, 0n) : Maybe<&2, Bool>}, false_true(lt))
        case 1n+p: absurd({List.get(&2, Bool, xs, 1n+p) == List.get(&2, Bool, ys, 1n+p) : Maybe<&2, Bool>}, false_true(lt))
    case 1n+k Nil{} _:
      absurd({List.get(&2, Bool, Nil{}, i) == List.get(&2, Bool, ys, i) : Maybe<&2, Bool>}, false_true(e))
    case 1n+k +x <> +xt Nil{}:
      absurd({List.get(&2, Bool, x <> xt, i) == List.get(&2, Bool, Nil{}, i) : Maybe<&2, Bool>}, false_true(e))
    case 1n+k +x <> +xt +y <> +yt:
      match i:
        case 0n:
          %bit_same(x, y, and_left(Ip.bit_eq(x, y), Ip.prefix(k, xt, yt), e)) : {Some{x} == Some{_} : Maybe<&2, Bool>}
          {==}
        case 1n+p:
          prefix_bits(k, xt, yt, and_right(Ip.bit_eq(x, y), Ip.prefix(k, xt, yt), e), p, lt)

def bit_from(+x: Bool, +y: Bool, e: {x == y : Bool}) -> {Ip.bit_eq(x, y) == True{} : Bool}:
  %e : {Ip.bit_eq(x, _) == True{} : Bool}
  bit_refl(x)

# Agreement below n, with both lists at least n long, makes prefix true.
def prefix_complete(+n: Nat, +xs: List<&2, Bool>, +ys: List<&2, Bool>, lx: {Nat.is_le(n, List.length(&2, Bool, xs)) == True{} : Bool}, ly: {Nat.is_le(n, List.length(&2, Bool, ys)) == True{} : Bool}, agree: @i:Nat -> {Nat.is_lt(i, n) == True{} : Bool} -> {List.get(&2, Bool, xs, i) == List.get(&2, Bool, ys, i) : Maybe<&2, Bool>}) -> {Ip.prefix(n, xs, ys) == True{} : Bool}:
  match n xs ys:
    case 0n _ _: {==}
    case 1n+k Nil{} _: absurd({Ip.prefix(1n+k, Nil{}, ys) == True{} : Bool}, false_true(lx))
    case 1n+k +x <> +xt Nil{}: absurd({Ip.prefix(1n+k, x <> xt, Nil{}) == True{} : Bool}, false_true(ly))
    case 1n+k True{} <> +xt True{} <> +yt: prefix_complete(k, xt, yt, lx, ly, i => lt => agree(1n+i, lt))
    case 1n+k False{} <> +xt False{} <> +yt: prefix_complete(k, xt, yt, lx, ly, i => lt => agree(1n+i, lt))
    case 1n+k True{} <> +xt False{} <> +yt: absurd({Ip.prefix(1n+k, True{} <> xt, False{} <> yt) == True{} : Bool}, false_true(Equal.sym(Bool, True{}, False{}, some_inj(True{}, False{}, agree(0n, {==})))))
    case 1n+k False{} <> +xt True{} <> +yt: absurd({Ip.prefix(1n+k, False{} <> xt, True{} <> yt) == True{} : Bool}, false_true(some_inj(False{}, True{}, agree(0n, {==}))))

def member_bits(+a: Ip.Addr, +c: Ip.Cidr, hit: {Ip.member(a, c) == True{} : Bool}, +i: Nat, below: {Nat.is_lt(i, Ip.cidr_len(c)) == True{} : Bool}) -> {List.get(&2, Bool, Ip.bits(a), i) == List.get(&2, Bool, Ip.cidr_bits(c), i) : Maybe<&2, Bool>}:
  match a c:
    case Ip.Addr{+fa, +xs} Ip.Cidr{+fc, +ys, +n}:
      prefix_bits(n, xs, ys, and_right(Ip.same_family(fa, fc) && Ip.wide(fa, xs) && Ip.wide(fc, ys) && Nat.is_le(n, Ip.width(fc)), Ip.prefix(n, xs, ys), hit), i, below)

def member_family(+a: Ip.Addr, +c: Ip.Cidr, hit: {Ip.member(a, c) == True{} : Bool}) -> {Ip.same_family(Ip.family(a), Ip.cidr_family(c)) == True{} : Bool}:
  match a c:
    case Ip.Addr{+fa, +xs} Ip.Cidr{+fc, +ys, +n}:
      +h4 = and_left(Ip.same_family(fa, fc) && Ip.wide(fa, xs) && Ip.wide(fc, ys) && Nat.is_le(n, Ip.width(fc)), Ip.prefix(n, xs, ys), hit)
      +h3 = and_left(Ip.same_family(fa, fc) && Ip.wide(fa, xs) && Ip.wide(fc, ys), Nat.is_le(n, Ip.width(fc)), h4)
      +h2 = and_left(Ip.same_family(fa, fc) && Ip.wide(fa, xs), Ip.wide(fc, ys), h3)
      and_left(Ip.same_family(fa, fc), Ip.wide(fa, xs), h2)

def member_width(+a: Ip.Addr, +c: Ip.Cidr, hit: {Ip.member(a, c) == True{} : Bool}) -> {Nat.is_eq(List.length(&2, Bool, Ip.bits(a)), Ip.width(Ip.family(a))) && Nat.is_eq(List.length(&2, Bool, Ip.cidr_bits(c)), Ip.width(Ip.cidr_family(c))) && Nat.is_le(Ip.cidr_len(c), Ip.width(Ip.cidr_family(c))) == True{} : Bool}:
  match a c:
    case Ip.Addr{+fa, +xs} Ip.Cidr{+fc, +ys, +n}:
      +h4 = and_left(Ip.same_family(fa, fc) && Ip.wide(fa, xs) && Ip.wide(fc, ys) && Nat.is_le(n, Ip.width(fc)), Ip.prefix(n, xs, ys), hit)
      +h3 = and_left(Ip.same_family(fa, fc) && Ip.wide(fa, xs) && Ip.wide(fc, ys), Nat.is_le(n, Ip.width(fc)), h4)
      +h2 = and_left(Ip.same_family(fa, fc) && Ip.wide(fa, xs), Ip.wide(fc, ys), h3)
      and_intro(Ip.wide(fa, xs) && Ip.wide(fc, ys), Nat.is_le(n, Ip.width(fc)), and_intro(Ip.wide(fa, xs), Ip.wide(fc, ys), and_right(Ip.same_family(fa, fc), Ip.wide(fa, xs), h2), and_right(Ip.same_family(fa, fc) && Ip.wide(fa, xs), Ip.wide(fc, ys), h3)), and_right(Ip.same_family(fa, fc) && Ip.wide(fa, xs) && Ip.wide(fc, ys), Nat.is_le(n, Ip.width(fc)), h4))

def le_len(+n: Nat, +l: Nat, +w: Nat, e: {l == w : Nat}, f: {Nat.is_le(n, w) == True{} : Bool}) -> {Nat.is_le(n, l) == True{} : Bool}:
  %Equal.sym(Nat, l, w, e) : {Nat.is_le(n, _) == True{} : Bool}
  f

def eq_len(+l: Nat, +w: Nat, e: {l == w : Nat}) -> {Nat.is_eq(l, w) == True{} : Bool}:
  %Equal.sym(Nat, l, w, e) : {Nat.is_eq(_, w) == True{} : Bool}
  is_eq_refl(w)

def member_complete(+a: Ip.Addr, +c: Ip.Cidr, family: {Ip.same_family(Ip.family(a), Ip.cidr_family(c)) == True{} : Bool}, wa: {List.length(&2, Bool, Ip.bits(a)) == Ip.width(Ip.family(a)) : Nat}, wc: {List.length(&2, Bool, Ip.cidr_bits(c)) == Ip.width(Ip.cidr_family(c)) : Nat}, fits: {Nat.is_le(Ip.cidr_len(c), Ip.width(Ip.cidr_family(c))) == True{} : Bool}, agree: @i:Nat -> {Nat.is_lt(i, Ip.cidr_len(c)) == True{} : Bool} -> {List.get(&2, Bool, Ip.bits(a), i) == List.get(&2, Bool, Ip.cidr_bits(c), i) : Maybe<&2, Bool>}) -> {Ip.member(a, c) == True{} : Bool}:
  match a c:
    case Ip.Addr{+fa, +xs} Ip.Cidr{+fc, +ys, +n}:
      +fam = family
      +lim = fits
      +wy = wc
      +wx = wa
      +lx = le_len(n, List.length(&2, Bool, xs), Ip.width(fc), Equal.trans(Nat, List.length(&2, Bool, xs), Ip.width(fa), Ip.width(fc), wx, width_same(fa, fc, fam)), lim)
      +ly = le_len(n, List.length(&2, Bool, ys), Ip.width(fc), wy, lim)
      +s1 = and_intro(Ip.same_family(fa, fc), Ip.wide(fa, xs), fam, eq_len(List.length(&2, Bool, xs), Ip.width(fa), wx))
      +s2 = and_intro(Ip.same_family(fa, fc) && Ip.wide(fa, xs), Ip.wide(fc, ys), s1, eq_len(List.length(&2, Bool, ys), Ip.width(fc), wy))
      +s3 = and_intro(Ip.same_family(fa, fc) && Ip.wide(fa, xs) && Ip.wide(fc, ys), Nat.is_le(n, Ip.width(fc)), s2, lim)
      and_intro(Ip.same_family(fa, fc) && Ip.wide(fa, xs) && Ip.wide(fc, ys) && Nat.is_le(n, Ip.width(fc)), Ip.prefix(n, xs, ys), s3, prefix_complete(n, xs, ys, lx, ly, agree))

def any_cons(+a: Ip.Addr, +c: Ip.Cidr, +t: List<&2, Ip.Cidr>, +b: Bool, eb: {Ip.member(a, c) == b : Bool}, ih: {Ip.any(a, t) == Spec.exists(a, t) : Bool}) -> {Ip.any(a, c <> t) == Spec.exists(a, c <> t) : Bool}:
  match b:
    case True{}:
      %Equal.sym(Bool, Ip.member(a, c), True{}, eb) : {(_ || Ip.any(a, t)) == Nat.is_lt(0n, Nat.add(Spec.one_if(_), Spec.hits(a, t))) : Bool}
      {==}
    case False{}:
      %Equal.sym(Bool, Ip.member(a, c), False{}, eb) : {(_ || Ip.any(a, t)) == Nat.is_lt(0n, Nat.add(Spec.one_if(_), Spec.hits(a, t))) : Bool}
      ih

def any_exists(+a: Ip.Addr, +cs: List<&2, Ip.Cidr>) -> {Ip.any(a, cs) == Spec.exists(a, cs) : Bool}:
  match cs:
    case Nil{}: {==}
    case +c <> +t: any_cons(a, c, t, Ip.member(a, c), {==}, any_exists(a, t))

def screened_spec(+d: Bool, +allow: List<&2, Ip.Cidr>, +a: Ip.Addr) -> {Ip.screened(d, allow, a) == Bool.not(d) && (List.is_empty(&2, Ip.Cidr, allow) || Spec.exists(a, allow)) : Bool}:
  match d:
    case True{}: {==}
    case False{}:
      match allow:
        case Nil{}: {==}
        case +c <> +t: any_exists(a, c <> t)

def permitted_spec(+rules: Ip.Rules, +a: Ip.Addr) -> {Ip.permitted(rules, a) == Spec.permitted(rules, a) : Bool}:
  match rules:
    case Ip.Rules{+deny, +allow}:
      %Equal.sym(Bool, Ip.any(a, deny), Spec.exists(a, deny), any_exists(a, deny)) : {Ip.screened(_, allow, a) == Bool.not(Spec.exists(a, deny)) && (List.is_empty(&2, Ip.Cidr, allow) || Spec.exists(a, allow)) : Bool}
      screened_spec(Spec.exists(a, deny), allow, a)

def none_disc(m: Maybe<&2, Ip.Cidr>) -> Type:
  match m:
    case None{}: Unit
    case Some{x}: Empty

def none_some(+c: Ip.Cidr, e: {None{} == Some{c} : Maybe<&2, Ip.Cidr>}) -> Empty:
  %e : none_disc(_)
  Unit{}

def from_cidr(m: Maybe<&2, Ip.Cidr>, d: Ip.Cidr) -> Ip.Cidr:
  match m:
    case Some{x}: x
    case None{}: d

def or_right(+x: Bool, -b: Bool, e: {b == True{} : Bool}) -> {(x || b) == True{} : Bool}:
  match x:
    case True{}: {==}
    case False{}: e

# Some listed range at index i contains a, so any finds a hit.
def any_hit(+a: Ip.Addr, +cs: List<&2, Ip.Cidr>, +i: Nat, +c: Ip.Cidr, at: {List.get(&2, Ip.Cidr, cs, i) == Some{c} : Maybe<&2, Ip.Cidr>}, hit: {Ip.member(a, c) == True{} : Bool}) -> {Ip.any(a, cs) == True{} : Bool}:
  match cs i:
    case Nil{} _: absurd({Ip.any(a, Nil{}) == True{} : Bool}, none_some(c, at))
    case +d <> +t 0n:
      +same = Equal.cong(Maybe<&2, Ip.Cidr>, Ip.Cidr, m => from_cidr(m, d), Some{d}, Some{c}, at)
      %Equal.sym(Ip.Cidr, d, c, same) : {(Ip.member(a, _) || Ip.any(a, t)) == True{} : Bool}
      %Equal.sym(Bool, Ip.member(a, c), True{}, hit) : {(_ || Ip.any(a, t)) == True{} : Bool}
      {==}
    case +d <> +t 1n+p: or_right(Ip.member(a, d), Ip.any(a, t), any_hit(a, t, p, c, at, hit))

def deny_wins(+deny: List<&2, Ip.Cidr>, +allow: List<&2, Ip.Cidr>, +a: Ip.Addr, +i: Nat, +c: Ip.Cidr, at: {List.get(&2, Ip.Cidr, deny, i) == Some{c} : Maybe<&2, Ip.Cidr>}, hit: {Ip.member(a, c) == True{} : Bool}) -> {Ip.permitted(Ip.Rules{deny, allow}, a) == False{} : Bool}:
  %Equal.sym(Bool, Ip.any(a, deny), True{}, any_hit(a, deny, i, c, at, hit)) : {Ip.screened(_, allow, a) == False{} : Bool}
  {==}

def allow_listed(+deny: List<&2, Ip.Cidr>, +allow: List<&2, Ip.Cidr>, +a: Ip.Addr, +i: Nat, +c: Ip.Cidr, clear: {Spec.exists(a, deny) == False{} : Bool}, at: {List.get(&2, Ip.Cidr, allow, i) == Some{c} : Maybe<&2, Ip.Cidr>}, hit: {Ip.member(a, c) == True{} : Bool}) -> {Ip.permitted(Ip.Rules{deny, allow}, a) == True{} : Bool}:
  match allow:
    case Nil{}: absurd({Ip.permitted(Ip.Rules{deny, Nil{}}, a) == True{} : Bool}, none_some(c, at))
    case +d <> +t:
      %Equal.sym(Bool, Ip.any(a, deny), False{}, Equal.trans(Bool, Ip.any(a, deny), Spec.exists(a, deny), False{}, any_exists(a, deny), clear)) : {Ip.screened(_, d <> t, a) == True{} : Bool}
      any_hit(a, d <> t, i, c, at, hit)

def unknown_denied(+d: Ip.Cidr, +deny: List<&2, Ip.Cidr>, +allow: List<&2, Ip.Cidr>) -> {Ip.permitted_peer(Ip.Rules{d <> deny, allow}, None{}) == False{} : Bool}:
  {==}

def unknown_not_allowed(+deny: List<&2, Ip.Cidr>, +c: Ip.Cidr, +allow: List<&2, Ip.Cidr>) -> {Ip.permitted_peer(Ip.Rules{deny, c <> allow}, None{}) == False{} : Bool}:
  match deny:
    case Nil{}: {==}
    case +x <> +t: {==}

def client_default(+peer: Maybe<&2, Ip.Addr>, +fields: List<&2, List<&2, U32>>) -> {Conn.client(peer, fields, []) == peer : Maybe<&2, Ip.Addr>}:
  match peer:
    case None{}: {==}
    case Some{p}: {==}

def client_untrusted(+peer: Ip.Addr, +fields: List<&2, List<&2, U32>>, +trusted: List<&2, Ip.Cidr>, outside: {Ip.any(peer, trusted) == False{} : Bool}) -> {Conn.client(Some{peer}, fields, trusted) == Some{peer} : Maybe<&2, Ip.Addr>}:
  %Equal.sym(Bool, Ip.any(peer, trusted), False{}, outside) : {Some{Conn.forwarded(peer, fields, trusted, _)} == Some{peer} : Maybe<&2, Ip.Addr>}
  {==}

def client_chain(+peer: Ip.Addr, +fields: List<&2, List<&2, U32>>, +trusted: List<&2, Ip.Cidr>, inside: {Ip.any(peer, trusted) == True{} : Bool}) -> {Conn.client(Some{peer}, fields, trusted) == Some{Conn.walk(Conn.hops(List.reverse(&2, String, Conn.entries(fields)), trusted), peer)} : Maybe<&2, Ip.Addr>}:
  %Equal.sym(Bool, Ip.any(peer, trusted), True{}, inside) : {Some{Conn.forwarded(peer, fields, trusted, _)} == Some{Conn.walk(Conn.hops(List.reverse(&2, String, Conn.entries(fields)), trusted), peer)} : Maybe<&2, Ip.Addr>}
  {==}

def chain_skip(+x: String, +rest: List<&2, String>, +trusted: List<&2, Ip.Cidr>, +current: Ip.Addr, +a: Ip.Addr, parsed: {Ip.parse(x) == Some{a} : Maybe<&2, Ip.Addr>}, proxy: {Ip.any(a, trusted) == True{} : Bool}) -> {Conn.walk(Conn.hops(x <> rest, trusted), current) == Conn.walk(Conn.hops(rest, trusted), a) : Ip.Addr}:
  %Equal.sym(Maybe<&2, Ip.Addr>, Ip.parse(x), Some{a}, parsed) : {Conn.walk(Conn.hop(_, trusted) <> Conn.hops(rest, trusted), current) == Conn.walk(Conn.hops(rest, trusted), a) : Ip.Addr}
  %Equal.sym(Bool, Ip.any(a, trusted), True{}, proxy) : {Conn.walk(Conn.hop_kind(a, _) <> Conn.hops(rest, trusted), current) == Conn.walk(Conn.hops(rest, trusted), a) : Ip.Addr}
  {==}

def chain_untrusted(+x: String, +rest: List<&2, String>, +trusted: List<&2, Ip.Cidr>, +current: Ip.Addr, +a: Ip.Addr, parsed: {Ip.parse(x) == Some{a} : Maybe<&2, Ip.Addr>}, client: {Ip.any(a, trusted) == False{} : Bool}) -> {Conn.walk(Conn.hops(x <> rest, trusted), current) == a : Ip.Addr}:
  %Equal.sym(Maybe<&2, Ip.Addr>, Ip.parse(x), Some{a}, parsed) : {Conn.walk(Conn.hop(_, trusted) <> Conn.hops(rest, trusted), current) == a : Ip.Addr}
  %Equal.sym(Bool, Ip.any(a, trusted), False{}, client) : {Conn.walk(Conn.hop_kind(a, _) <> Conn.hops(rest, trusted), current) == a : Ip.Addr}
  {==}

def chain_malformed(+x: String, +rest: List<&2, String>, +trusted: List<&2, Ip.Cidr>, +current: Ip.Addr, bad: {Ip.parse(x) == None{} : Maybe<&2, Ip.Addr>}) -> {Conn.walk(Conn.hops(x <> rest, trusted), current) == current : Ip.Addr}:
  %Equal.sym(Maybe<&2, Ip.Addr>, Ip.parse(x), None{}, bad) : {Conn.walk(Conn.hop(_, trusted) <> Conn.hops(rest, trusted), current) == current : Ip.Addr}
  {==}

def Laws.ip_member_bits(a, c, hit, i, below): member_bits(a, c, hit, i, below)
def Laws.ip_member_family(a, c, hit): member_family(a, c, hit)
def Laws.ip_member_width(a, c, hit): member_width(a, c, hit)
def Laws.ip_member_complete(a, c, family, wa, wc, fits, agree): member_complete(a, c, family, wa, wc, fits, agree)
def Laws.ip_permitted_spec(rules, a): permitted_spec(rules, a)
def Laws.ip_deny_wins(deny, allow, a, i, c, at, hit): deny_wins(deny, allow, a, i, c, at, hit)
def Laws.ip_allow_listed(deny, allow, a, i, c, clear, at, hit): allow_listed(deny, allow, a, i, c, clear, at, hit)
def Laws.ip_unknown_denied(d, deny, allow): unknown_denied(d, deny, allow)
def Laws.ip_unknown_not_allowed(deny, c, allow): unknown_not_allowed(deny, c, allow)
def Laws.client_default_peer(peer, fields): client_default(peer, fields)
def Laws.client_untrusted_peer(peer, fields, trusted, outside): client_untrusted(peer, fields, trusted, outside)
def Laws.client_trusted_chain(peer, fields, trusted, inside): client_chain(peer, fields, trusted, inside)
def Laws.conn_entries_spec(fields): Entries.entries_spec(fields)
def Laws.chain_skips_trusted(x, rest, trusted, current, a, parsed, proxy): chain_skip(x, rest, trusted, current, a, parsed, proxy)
def Laws.chain_first_untrusted(x, rest, trusted, current, a, parsed, client): chain_untrusted(x, rest, trusted, current, a, parsed, client)
def Laws.chain_malformed_stops(x, rest, trusted, current, bad): chain_malformed(x, rest, trusted, current, bad)
def Laws.chain_exhausted(trusted, current): {==}
