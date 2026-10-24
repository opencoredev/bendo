# IP addresses, CIDR ranges and allow/deny rules. Pure; the laws import it.
# An address is its bits, most significant first: 32 for IPv4, 128 for IPv6.
# IPv4-mapped IPv6 (::ffff:a.b.c.d) is parsed as the IPv4 address it carries.
import Base
import ../http/bytes.bend as Bytes

type Family is Data:
  V4{}
  V6{}

type Addr is Data:
  Addr{family: Family, bits: List<&2, Bool>}

type Cidr is Data:
  Cidr{family: Family, bits: List<&2, Bool>, len: Nat}

# Deny wins over allow. An empty allow list admits every address not denied.
type Rules is Data:
  Rules{deny: List<&2, Cidr>, allow: List<&2, Cidr>}

def width(f: Family) -> Nat:
  match f:
    case V4{}: 32n
    case V6{}: 128n

def family(a: Addr) -> Family:
  Addr{f, xs} = a
  f

def bits(a: Addr) -> List<&2, Bool>:
  Addr{f, xs} = a
  xs

def cidr_family(c: Cidr) -> Family:
  Cidr{f, xs, n} = c
  f

def cidr_bits(c: Cidr) -> List<&2, Bool>:
  Cidr{f, xs, n} = c
  xs

def cidr_len(c: Cidr) -> Nat:
  Cidr{f, xs, n} = c
  n

def same_family(a: Family, b: Family) -> Bool:
  match a b:
    case V4{} V4{}: True{}
    case V6{} V6{}: True{}
    case _ _: False{}

def bit_eq(x: Bool, y: Bool) -> Bool:
  match x y:
    case True{} True{}: True{}
    case False{} False{}: True{}
    case _ _: False{}

# The first n bits of both lists exist and agree.
def prefix(n: Nat, xs: List<&2, Bool>, ys: List<&2, Bool>) -> Bool:
  match n xs ys:
    case 0n _ _: True{}
    case 1n+k x <> xt y <> yt: bit_eq(x, y) && prefix(k, xt, yt)
    case _ _ _: False{}

def wide(+f: Family, xs: List<&2, Bool>) -> Bool:
  Nat.is_eq(List.length(&2, Bool, xs), width(f))

# Both values are well formed for their family and the address's first len
# bits equal the network's.
def member(a: Addr, c: Cidr) -> Bool:
  Addr{+fa, +xs} = a
  Cidr{+fc, +ys, +n} = c
  same_family(fa, fc) && wide(fa, xs) && wide(fc, ys) && Nat.is_le(n, width(fc)) && prefix(n, xs, ys)

def any(+a: Addr, cs: List<&2, Cidr>) -> Bool:
  match cs:
    case Nil{}: False{}
    case c <> t: member(a, c) || any(a, t)

def listed(allow: List<&2, Cidr>, +a: Addr) -> Bool:
  match allow:
    case Nil{}: True{}
    case c <> t: any(a, c <> t)

def screened(denied: Bool, allow: List<&2, Cidr>, a: Addr) -> Bool:
  match denied:
    case True{}: False{}
    case False{}: listed(allow, a)

def permitted(rules: Rules, +a: Addr) -> Bool:
  Rules{deny, allow} = rules
  screened(any(a, deny), allow, a)

# Without a known address only an empty rule set admits the request.
def empty_rules(rules: Rules) -> Bool:
  Rules{deny, allow} = rules
  List.is_empty(&2, Cidr, deny) && List.is_empty(&2, Cidr, allow)

def permitted_peer(rules: Rules, peer: Maybe<&2, Addr>) -> Bool:
  match peer:
    case Some{a}: permitted(rules, a)
    case None{}: empty_rules(rules)

# Text to numbers. Every parser here is strict: no shorthand, no octal or hex
# IPv4 parts, no leading zeros in IPv4 octets or prefix lengths, no zone ids.
def split_push(c: U32, parts: List<&2, List<&2, U32>>) -> List<&2, List<&2, U32>>:
  match parts:
    case Nil{}: [[c]]
    case p <> t: (c <> p) <> t

def split_pick(+c: U32, parts: List<&2, List<&2, U32>>, here: Bool) -> List<&2, List<&2, U32>>:
  match here:
    case True{}: [] <> parts
    case False{}: split_push(c, parts)

# Every part, empty ones included: "a..b" splits on '.' into a, "" and b.
def split(xs: List<&2, U32>, +sep: U32) -> List<&2, List<&2, U32>>:
  match xs:
    case Nil{}: [[]]
    case +c <> t: split_pick(c, split(t, sep), U32.is_eq(c, sep))

def digit(+c: U32) -> Bool:
  (c >= 48 : U32) && (c <= 57 : U32)

def all_digits(xs: List<&2, U32>) -> Bool:
  match xs:
    case Nil{}: True{}
    case +c <> t: digit(c) && all_digits(t)

def decimal_value(xs: List<&2, U32>, acc: Nat) -> Nat:
  match xs:
    case Nil{}: acc
    case c <> t: decimal_value(t, Nat.add(Nat.mul(acc, 10n), U32.to_nat(U32.sub(c, 48))))

# One to three digits, no leading zero unless the number is 0 itself.
def canonical_digits(xs: List<&2, U32>) -> Bool:
  match xs:
    case Nil{}: False{}
    case +a <> Nil{}: digit(a)
    case +a <> +b <> Nil{}: U32.is_ne(a, 48) && digit(a) && digit(b)
    case +a <> +b <> +c <> Nil{}: U32.is_ne(a, 48) && digit(a) && digit(b) && digit(c)
    case _: False{}

def gate(-A: Data, value: A, ok: Bool) -> Maybe<&2, A>:
  match ok:
    case True{}: Some{value}
    case False{}: None{}

def bounded(value: Nat, +max: Nat) -> Maybe<&2, Nat>:
  +v = value
  gate(Nat, v, Nat.is_le(v, max))

def decimal_pick(xs: List<&2, U32>, +max: Nat, ok: Bool) -> Maybe<&2, Nat>:
  match ok:
    case True{}: bounded(decimal_value(xs, 0n), max)
    case False{}: None{}

def small_decimal(+xs: List<&2, U32>, +max: Nat) -> Maybe<&2, Nat>:
  decimal_pick(xs, max, canonical_digits(xs))

# Bits of the low k bits of x, most significant first.
def u32_bits(+x: U32, k: Nat) -> List<&2, Bool>:
  match k:
    case 0n: []
    case 1n+(+j): U32.is_ne(U32.and(U32.shrn(x, j), 1), 0) <> u32_bits(x, j)

def octet_bits(os: List<&2, Nat>) -> List<&2, Bool>:
  match os:
    case Nil{}: []
    case o <> t: List.append(&2, Bool, u32_bits(U32.from_nat(o), 8n), octet_bits(t))

def group_bits(gs: List<&2, U32>) -> List<&2, Bool>:
  match gs:
    case Nil{}: []
    case g <> t: List.append(&2, Bool, u32_bits(g, 16n), group_bits(t))

def octet(+part: List<&2, U32>) -> Maybe<&2, Nat>:
  small_decimal(part, 255n)

def quad(parts: List<&2, List<&2, U32>>) -> Maybe<&2, List<&2, Nat>>:
  match parts:
    case a <> b <> c <> d <> Nil{}:
      do Maybe<&2, List<&2, Nat>>:
        x : Nat <- octet(a)
        y : Nat <- octet(b)
        z : Nat <- octet(c)
        w : Nat <- octet(d)
        return [x, y, z, w]
    case _: None{}

# Exactly four dot-separated decimal octets.
def v4_octets(xs: List<&2, U32>) -> Maybe<&2, List<&2, Nat>>:
  quad(split(xs, 46))

def hex(+c: U32) -> Bool:
  digit(c) || ((c >= 97 : U32) && (c <= 102 : U32)) || ((c >= 65 : U32) && (c <= 70 : U32))

def all_hex(xs: List<&2, U32>) -> Bool:
  match xs:
    case Nil{}: True{}
    case +c <> t: hex(c) && all_hex(t)

def hex_digit_pick(c: U32, decimal: Bool) -> U32:
  match decimal:
    case True{}: U32.sub(c, 48)
    case False{}: U32.add(U32.and(c, 7), 9)

def hex_digit(+c: U32) -> U32:
  hex_digit_pick(c, digit(c))

def hex_value(xs: List<&2, U32>, acc: U32) -> U32:
  match xs:
    case Nil{}: acc
    case +c <> t: hex_value(t, U32.add(U32.shln(acc, 4n), hex_digit(c)))

def hex_pick(xs: List<&2, U32>, ok: Bool) -> Maybe<&2, U32>:
  match ok:
    case True{}: Some{hex_value(xs, 0)}
    case False{}: None{}

# One to four hex digits.
def hex_group(+xs: List<&2, U32>) -> Maybe<&2, U32>:
  +n = List.length(&2, U32, xs)
  hex_pick(xs, Nat.is_lt(0n, n) && Nat.is_le(n, 4n) && all_hex(xs))

def has(xs: List<&2, U32>, +c: U32) -> Bool:
  match xs:
    case Nil{}: False{}
    case x <> t: U32.is_eq(x, c) || has(t, c)

def nat_u32(n: Nat) -> U32:
  U32.from_nat(n)

def embedded(os: Maybe<&2, List<&2, Nat>>) -> Maybe<&2, List<&2, U32>>:
  match os:
    case Some{a <> b <> c <> d <> Nil{}}: Some{[U32.add(U32.shln(nat_u32(a), 8n), nat_u32(b)), U32.add(U32.shln(nat_u32(c), 8n), nat_u32(d))]}
    case _: None{}

def last_group(+part: List<&2, U32>, dotted: Bool) -> Maybe<&2, List<&2, U32>>:
  match dotted:
    case True{}: embedded(v4_octets(part))
    case False{}:
      do Maybe<&2, List<&2, U32>>:
        g : U32 <- hex_group(part)
        return [g]

def cons_group(g: Maybe<&2, U32>, rest: Maybe<&2, List<&2, U32>>) -> Maybe<&2, List<&2, U32>>:
  match g rest:
    case Some{x} Some{xs}: Some{x <> xs}
    case _ _: None{}

# Hex groups; only the final part (with tail on) may be a dotted IPv4 address.
def groups(parts: List<&2, List<&2, U32>>, +tail: Bool) -> Maybe<&2, List<&2, U32>>:
  match parts:
    case Nil{}: Some{[]}
    case +p <> Nil{}: last_group(p, tail && has(p, 46))
    case p <> t: cons_group(hex_group(p), groups(t, tail))

def side(xs: List<&2, U32>) -> List<&2, List<&2, U32>>:
  match xs:
    case Nil{}: []
    case c <> t: split(c <> t, 58)

def double_push(c: U32, parts: List<&2, List<&2, U32>>) -> List<&2, List<&2, U32>>:
  match parts:
    case Nil{}: [[c]]
    case p <> t: (c <> p) <> t

# Split on every "::", scanning left to right.
def doubles(xs: List<&2, U32>) -> List<&2, List<&2, U32>>:
  match xs:
    case Nil{}: [[]]
    case 58 <> 58 <> t: [] <> doubles(t)
    case c <> t: double_push(c, doubles(t))

def zeros(n: Nat) -> List<&2, U32>:
  match n:
    case 0n: []
    case 1n+k: 0 <> zeros(k)

def full(gs: Maybe<&2, List<&2, U32>>) -> Maybe<&2, List<&2, U32>>:
  match gs:
    case Some{+xs}: gate(List<&2, U32>, xs, Nat.is_eq(List.length(&2, U32, xs), 8n))
    case None{}: None{}

# "::" stands for one or more zero groups.
def compressed(l: Maybe<&2, List<&2, U32>>, r: Maybe<&2, List<&2, U32>>) -> Maybe<&2, List<&2, U32>>:
  match l r:
    case Some{+a} Some{+b}:
      +used = Nat.add(List.length(&2, U32, a), List.length(&2, U32, b))
      gate(List<&2, U32>, List.append(&2, U32, a, List.append(&2, U32, zeros(Nat.sub(8n, used)), b)), Nat.is_le(used, 7n))
    case _ _: None{}

def v6_halves(halves: List<&2, List<&2, U32>>) -> Maybe<&2, List<&2, U32>>:
  match halves:
    case whole <> Nil{}: full(groups(split(whole, 58), True{}))
    case left <> right <> Nil{}: compressed(groups(side(left), False{}), groups(side(right), True{}))
    case _: None{}

# Eight 16-bit groups, after expanding "::" and a trailing dotted IPv4 part.
def v6_groups(xs: List<&2, U32>) -> Maybe<&2, List<&2, U32>>:
  v6_halves(doubles(xs))

def replicate(n: Nat, +b: Bool) -> List<&2, Bool>:
  match n:
    case 0n: []
    case 1n+k: b <> replicate(k, b)

# ::ffff:0:0/96, the IPv4-mapped block.
def mapped_prefix() -> List<&2, Bool>:
  List.append(&2, Bool, replicate(80n, False{}), replicate(16n, True{}))

def mapped(xs: List<&2, Bool>) -> Bool:
  prefix(96n, xs, mapped_prefix())

def unmap(+xs: List<&2, Bool>, is_mapped: Bool) -> Addr:
  match is_mapped:
    case True{}: Addr{V4{}, List.drop(&2, Bool, xs, 96n)}
    case False{}: Addr{V6{}, xs}

def v6_addr(gs: Maybe<&2, List<&2, U32>>) -> Maybe<&2, Addr>:
  match gs:
    case None{}: None{}
    case Some{g}:
      +xs = group_bits(g)
      Some{unmap(xs, mapped(xs))}

def v4_addr(os: Maybe<&2, List<&2, Nat>>) -> Maybe<&2, Addr>:
  match os:
    case None{}: None{}
    case Some{o}: Some{Addr{V4{}, octet_bits(o)}}

def parse_codes(xs: List<&2, U32>, colon: Bool) -> Maybe<&2, Addr>:
  match colon:
    case True{}: v6_addr(v6_groups(xs))
    case False{}: v4_addr(v4_octets(xs))

# A literal address: dotted IPv4, or IPv6 text (RFC 4291 section 2.2).
def parse(s: String) -> Maybe<&2, Addr>:
  +xs = Bytes.encode(s)
  parse_codes(xs, has(xs, 58))

# Raw bits before mapping, so a CIDR range can be mapped only when its
# prefix covers the whole IPv4-mapped block.
def raw_codes(xs: List<&2, U32>, colon: Bool) -> Maybe<&2, Addr>:
  match colon:
    case True{}:
      do Maybe<&2, Addr>:
        g : List<&2, U32> <- v6_groups(xs)
        return Addr{V6{}, group_bits(g)}
    case False{}: v4_addr(v4_octets(xs))

def all_zero(xs: List<&2, Bool>) -> Bool:
  match xs:
    case Nil{}: True{}
    case True{} <> t: False{}
    case False{} <> t: all_zero(t)

# Strict: host bits after the prefix must be zero ("10.0.0.1/8" is refused).
def range_check(c: Cidr) -> Maybe<&2, Cidr>:
  Cidr{+f, +xs, +n} = c
  gate(Cidr, Cidr{f, xs, n}, Nat.is_le(n, width(f)) && all_zero(List.drop(&2, Bool, xs, n)))

def range_map(f: Family, +xs: List<&2, Bool>, +n: Nat, folded: Bool) -> Cidr:
  match folded:
    case True{}: Cidr{V4{}, List.drop(&2, Bool, xs, 96n), Nat.sub(n, 96n)}
    case False{}: Cidr{f, xs, n}

def ranged(a: Addr, len: Maybe<&2, Nat>) -> Maybe<&2, Cidr>:
  Addr{+f, +xs} = a
  match len:
    case None{}: None{}
    case Some{+n}:
      +v6 = same_family(f, V6{})
      range_check(range_map(f, xs, n, v6 && mapped(xs) && Nat.is_le(96n, n)))

def host_range(+x: Addr) -> Maybe<&2, Cidr>:
  ranged(x, Some{width(family(x))})

def prefix_len(+raw: Maybe<&2, Addr>, part: List<&2, U32>) -> Maybe<&2, Nat>:
  match raw:
    case None{}: None{}
    case Some{a}: small_decimal(part, width(family(a)))

def cidr_parts(parts: List<&2, List<&2, U32>>) -> Maybe<&2, Cidr>:
  match parts:
    case +a <> Nil{}:
      do Maybe<&2, Cidr>:
        x : Addr <- raw_codes(a, has(a, 58))
        host_range(x)
    case +a <> l <> Nil{}:
      +raw = raw_codes(a, has(a, 58))
      do Maybe<&2, Cidr>:
        x : Addr <- raw
        ranged(x, prefix_len(raw, l))
    case _: None{}

# "addr/len", or a bare address for a single host (/32 or /128).
def parse_cidr(s: String) -> Maybe<&2, Cidr>:
  cidr_parts(split(Bytes.encode(s), 47))

# Every entry must parse; one bad entry rejects the whole list.
def parse_cidrs(xs: List<&2, String>) -> Maybe<&2, List<&2, Cidr>>:
  match xs:
    case Nil{}: Some{[]}
    case s <> t:
      do Maybe<&2, List<&2, Cidr>>:
        c : Cidr <- parse_cidr(s)
        cs : List<&2, Cidr> <- parse_cidrs(t)
        return c <> cs

def rules(deny: List<&2, String>, allow: List<&2, String>) -> Maybe<&2, Rules>:
  do Maybe<&2, Rules>:
    d : List<&2, Cidr> <- parse_cidrs(deny)
    a : List<&2, Cidr> <- parse_cidrs(allow)
    return Rules{d, a}

# Numbers back to text: dotted IPv4, RFC 5952 IPv6.
def bits_value(xs: List<&2, Bool>, acc: U32) -> U32:
  match xs:
    case Nil{}: acc
    case b <> t: bits_value(t, U32.add(U32.shln(acc, 1n), Bool.to_u32(b)))

def chunks(n: Nat, +k: Nat, +xs: List<&2, Bool>) -> List<&2, U32>:
  match n:
    case 0n: []
    case 1n+m: bits_value(List.take(&2, Bool, xs, k), 0) <> chunks(m, k, List.drop(&2, Bool, xs, k))

def hex_char_pick(d: U32, decimal: Bool) -> Char:
  match decimal:
    case True{}: Chr{U32.add(d, 48)}
    case False{}: Chr{U32.add(d, 87)}

def hex_char(+d: U32) -> Char:
  hex_char_pick(d, (d < 10 : U32))

def hex_width_pick(a: Bool, b: Bool, c: Bool) -> Nat:
  match a b c:
    case True{} _ _: 1n
    case False{} True{} _: 2n
    case False{} False{} True{}: 3n
    case False{} False{} False{}: 4n

def hex_width(+x: U32) -> Nat:
  hex_width_pick((x < 16 : U32), (x < 256 : U32), (x < 4096 : U32))

def hex_digits(n: Nat, +x: U32, acc: String) -> String:
  match n:
    case 0n: acc
    case 1n+k: hex_digits(k, U32.shrn(x, 4n), SCon{hex_char(U32.and(x, 15)), acc})

# Lowercase, without leading zeros (RFC 5952 section 4.1 and 4.3).
def group_text(+g: U32) -> String:
  hex_digits(hex_width(g), g, "")

def group_texts(gs: List<&2, U32>) -> List<&2, String>:
  match gs:
    case Nil{}: []
    case g <> t: group_text(g) <> group_texts(t)

def run_length(gs: List<&2, U32>) -> Nat:
  match gs:
    case Nil{}: 0n
    case 0 <> t: 1n+run_length(t)
    case _ <> t: 0n

type Run is Data:
  Run{start: Nat, len: Nat}

def better(best: Run, here: Run, longer: Bool) -> Run:
  match longer:
    case True{}: here
    case False{}: best

def longest(gs: List<&2, U32>, +i: Nat, best: Run) -> Run:
  match gs:
    case Nil{}: best
    case +g <> +t:
      Run{+s, +n} = best
      +here = run_length(g <> t)
      longest(t, 1n+i, better(Run{s, n}, Run{i, here}, Nat.is_lt(n, here)))

def joined(gs: List<&2, U32>) -> String:
  String.join(group_texts(gs), ":")

def v6_compress(+gs: List<&2, U32>, +s: Nat, +n: Nat, shorten: Bool) -> String:
  match shorten:
    case True{}: joined(List.take(&2, U32, gs, s)) ++ "::" ++ joined(List.drop(&2, U32, gs, Nat.add(s, n)))
    case False{}: joined(gs)

# The first longest run of two or more zero groups becomes "::".
def v6_run(gs: List<&2, U32>, run: Run) -> String:
  Run{+s, +n} = run
  v6_compress(gs, s, n, Nat.is_le(2n, n))

def v6_text(+gs: List<&2, U32>) -> String:
  v6_run(gs, longest(gs, 0n, Run{0n, 0n}))

def octet_texts(os: List<&2, U32>) -> List<&2, String>:
  match os:
    case Nil{}: []
    case o <> t: U32.show(o) <> octet_texts(t)

def format(a: Addr) -> String:
  Addr{f, +xs} = a
  match f:
    case V4{}: String.join(octet_texts(chunks(4n, 8n, xs)), ".")
    case V6{}: v6_text(chunks(8n, 16n, xs))

def family_text(f: Family) -> String:
  match f:
    case V4{}: "IPv4"
    case V6{}: "IPv6"

def address_type(a: Addr) -> String:
  family_text(family(a))
