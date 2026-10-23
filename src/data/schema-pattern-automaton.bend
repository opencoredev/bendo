# A position automaton for structured string patterns (docs/data/schema.md).
# The pattern is compiled once into nodes: each node is an arc, one atom read
# from the text and the residual pattern left to match after it. A scan keeps
# the set of live nodes as bit words, so each scalar costs work proportional to
# the node count, never to the size of the residual patterns.
#
# The table is built by an unproven closure, then checked: every residual's
# arcs must be found among the nodes. A table that fails the check is never
# used; the proven derivative matcher runs instead.
import Base
import ./schema-pattern.bend as P

# What one scalar must be to take an arc.
type Atom is Data:
  AChar{code: U32}
  AClass{ranges: List<&2, P.Range>}

# Read one scalar matching `atom`, then match `target` against the rest.
type Arc is Data:
  Arc{atom: Atom, target: P.Pattern}

def hit(a: Atom, +c: U32) -> Bool:
  match a:
    case AChar{d}: U32.is_eq(c, d)
    case AClass{rs}: P.in_ranges(rs, c, False{})

# Linear forms: the arcs of a pattern, built the way `P.derive` builds its
# derivatives, so firing them by a scalar gives exactly the derivatives.

def behind(xs: List<&2, Arc>, +rest: P.Pattern) -> List<&2, Arc>:
  match xs:
    case Nil{}: []
    case Arc{a, d} <> t: Arc{a, P.Cat{d, rest}} <> behind(t, rest)

def cat_arcs(left: List<&2, Arc>, empty_first: Bool, right: List<&2, Arc>) -> List<&2, Arc>:
  match empty_first:
    case True{}: List.append(&2, Arc, left, right)
    case False{}: left

def repeat_once(go: Bool, xs: List<&2, Arc>, r: P.Pattern, m: Nat, n: Maybe<&2, Nat>) -> List<&2, Arc>:
  match go:
    case True{}: behind(xs, P.Repeat{r, P.pred(m), P.less(n)})
    case False{}: []

def repeat_empty(+xs: List<&2, Arc>, +r: P.Pattern, m: Nat, +n: Maybe<&2, Nat>) -> List<&2, Arc>:
  match m:
    case 0n: repeat_once(P.open(n), xs, r, 0n, n)
    case 1n+(+k): List.append(&2, Arc, repeat_once(P.open(n), xs, r, 1n+k, n), repeat_empty(xs, r, k, P.less(n)))

def repeat_arcs(empty: Bool, +xs: List<&2, Arc>, +r: P.Pattern, +m: Nat, +n: Maybe<&2, Nat>) -> List<&2, Arc>:
  match empty:
    case True{}: repeat_empty(xs, r, m, n)
    case False{}: repeat_once(P.open(n), xs, r, m, n)

def linear(p: P.Pattern) -> List<&2, Arc>:
  match p:
    case P.Literal{SNil{}}: []
    case P.Literal{SCon{Chr{d}, t}}: [Arc{AChar{d}, P.Literal{t}}]
    case P.Class{rs}: [Arc{AClass{rs}, P.Literal{""}}]
    case P.Cat{+a, +b}: cat_arcs(behind(linear(a), b), P.nullable(a), linear(b))
    case P.Repeat{+r, m, n}: repeat_arcs(P.nullable(r), linear(r), r, m, n)

# Arc identity: a hash first, then structural equality.

def atom_hash(a: Atom) -> U32:
  match a:
    case AChar{d}: P.mix(5, d)
    case AClass{rs}: P.ranges_hash(rs, 6)

def arc_hash(x: Arc) -> U32:
  match x:
    case Arc{a, d}: P.mix(atom_hash(a), P.hash(d))

def same_atom(a: Atom, b: Atom) -> Bool:
  match a b:
    case AChar{x} AChar{y}: U32.is_eq(x, y)
    case AClass{x} AClass{y}: P.ranges_same(x, y)
    case _ _: False{}

def same_arc(x: Arc, y: Arc) -> Bool:
  match x y:
    case Arc{a, d} Arc{b, e}: same_atom(a, b) && P.same(d, e)

def same_keyed(hit: Bool, x: Arc, y: Arc) -> Bool:
  match hit:
    case False{}: False{}
    case True{}: same_arc(x, y)

# Four bit words: one per block of a table of at most 128 nodes.
type W4 is Data:
  W4{w0: U32, w1: U32, w2: U32, w3: U32}

def w4_or(x: W4, y: W4) -> W4:
  match x y:
    case W4{a, b, c, d} W4{e, f, g, h}: W4{(a .|. e : U32), (b .|. f : U32), (c .|. g : U32), (d .|. h : U32)}

def w4_list(x: W4) -> List<&2, U32>:
  match x:
    case W4{a, b, c, d}: [a, b, c, d]

def w4_of(ws: List<&2, U32>) -> W4:
  match ws:
    case Nil{}: W4{0, 0, 0, 0}
    case a <> Nil{}: W4{a, 0, 0, 0}
    case a <> b <> Nil{}: W4{a, b, 0, 0}
    case a <> b <> c <> Nil{}: W4{a, b, c, 0}
    case a <> b <> c <> d <> t: W4{a, b, c, d}

# A node of the table: its key, its arc, and the bit words of the nodes that
# can follow it (zero until the table is finished).
type Node is Data:
  Node{key: U32, arc: Arc, follow: W4}

# The closure. Unproven: its output is checked before use.

# An arc is new unless a node has its key and the same arc, so arcs whose keys
# collide are both kept.
def known(ns: List<&2, Node>, +k: U32, +x: Arc, found: Bool) -> Bool:
  match ns:
    case Nil{}: found
    case Node{h, y, f} <> t:
      match found:
        case True{}: True{}
        case False{}: known(t, k, x, same_keyed(U32.is_eq(h, k), y, x))

def admit(seen: Bool, +k: U32, +x: Arc, all: List<&2, Node>, fresh: List<&2, Node>) -> List<&2, Node> & List<&2, Node>:
  match seen:
    case True{}: (all, fresh)
    case False{}: (Node{k, x, W4{0, 0, 0, 0}} <> all, Node{k, x, W4{0, 0, 0, 0}} <> fresh)

def admit_one(+k: U32, +x: Arc, +all: List<&2, Node>, fresh: List<&2, Node>) -> List<&2, Node> & List<&2, Node>:
  admit(known(all, k, x, False{}), k, x, all, fresh)

def admit_pair(+k: U32, +x: Arc, acc: List<&2, Node> & List<&2, Node>) -> List<&2, Node> & List<&2, Node>:
  (all, fresh) = acc
  admit_one(k, x, all, fresh)

def admit_all(xs: List<&2, Arc>, acc: List<&2, Node> & List<&2, Node>) -> List<&2, Node> & List<&2, Node>:
  match xs:
    case Nil{}: acc
    case +x <> t: admit_all(t, admit_pair(arc_hash(x), x, acc))

def expand(frontier: List<&2, Node>, acc: List<&2, Node> & List<&2, Node>) -> List<&2, Node> & List<&2, Node>:
  match frontier:
    case Nil{}: acc
    case Node{h, Arc{a, d}, f} <> t: expand(t, admit_all(linear(d), acc))

# Nodes, newest first. Stops early past `most()` nodes; the check then fails.
def most() -> Nat:
  1024n

def closure(fuel: Nat, state: List<&2, Node> & List<&2, Node>) -> List<&2, Node>:
  match fuel:
    case 0n:
      (all, frontier) = state
      all
    case 1n+f:
      (all, frontier) = state
      match frontier:
        case Nil{}: all
        case x <> t: closure(f, expand(x <> t, (all, [])))

# 32 nodes per block, one bit word per block.
def chunk(n: Nat, xs: List<&2, Node>, acc: List<&2, Node>) -> List<&2, Node> & List<&2, Node>:
  match n:
    case 0n: (List.reverse(&2, Node, acc), xs)
    case 1n+k:
      match xs:
        case Nil{}: (List.reverse(&2, Node, acc), [])
        case x <> t: chunk(k, t, x <> acc)

# `cut` is the next block and the nodes after it.
def blocks_go(fuel: Nat, cut: List<&2, Node> & List<&2, Node>) -> List<&2, List<&2, Node>>:
  match fuel:
    case 0n: []
    case 1n+f:
      (b, rest) = cut
      match b:
        case Nil{}: []
        case x <> t: (x <> t) <> blocks_go(f, chunk(32n, rest, []))

# Bit words.

def or_words(a: List<&2, U32>, b: List<&2, U32>) -> List<&2, U32>:
  match a b:
    case Nil{} _: b
    case x <> s Nil{}: x <> s
    case x <> s y <> t: (x .|. y : U32) <> or_words(s, t)

def find_word(n: Nat, ns: List<&2, Node>, +k: U32, +x: Arc) -> Word(n):
  match n:
    case 0n: WNil{}
    case 1n+p:
      match ns:
        case Nil{}: Word.zero(1n+p)
        case Node{h, y, f} <> t: WCon{same_keyed(U32.is_eq(h, k), y, x), find_word(p, t, k, x)}

# The bit words of the nodes whose arc is x.
def find(bs: List<&2, List<&2, Node>>, +k: U32, +x: Arc) -> List<&2, U32>:
  match bs:
    case Nil{}: []
    case b <> t: U32{find_word(32n, b, k, x)} <> find(t, k, x)

# Whether `find` sets any bit, read the same way.
def found_word(n: Nat, ns: List<&2, Node>, +k: U32, +x: Arc) -> Bool:
  match n:
    case 0n: False{}
    case 1n+p:
      match ns:
        case Nil{}: False{}
        case Node{h, y, f} <> t: same_keyed(U32.is_eq(h, k), y, x) || found_word(p, t, k, x)

def found(bs: List<&2, List<&2, Node>>, +k: U32, +x: Arc) -> Bool:
  match bs:
    case Nil{}: False{}
    case b <> t: found_word(32n, b, k, x) || found(t, k, x)

def follow_of(+bs: List<&2, List<&2, Node>>, xs: List<&2, Arc>) -> List<&2, U32>:
  match xs:
    case Nil{}: []
    case +x <> t: or_words(find(bs, arc_hash(x), x), follow_of(bs, t))

def all_found(+bs: List<&2, List<&2, Node>>, xs: List<&2, Arc>) -> Bool:
  match xs:
    case Nil{}: True{}
    case +x <> t: found(bs, arc_hash(x), x) && all_found(bs, t)

def attach_block(+bs: List<&2, List<&2, Node>>, ns: List<&2, Node>) -> List<&2, Node>:
  match ns:
    case Nil{}: []
    case Node{h, Arc{a, +d}, f} <> t: Node{h, Arc{a, d}, w4_of(follow_of(bs, linear(d)))} <> attach_block(bs, t)

def attach(+all: List<&2, List<&2, Node>>, bs: List<&2, List<&2, Node>>) -> List<&2, List<&2, Node>>:
  match bs:
    case Nil{}: []
    case b <> t: attach_block(all, b) <> attach(all, t)

def check_block(+bs: List<&2, List<&2, Node>>, ns: List<&2, Node>) -> Bool:
  match ns:
    case Nil{}: True{}
    case Node{h, Arc{a, d}, f} <> t: all_found(bs, linear(d)) && check_block(bs, t)

# At most four blocks, so four words hold every follow set.
def fits4(bs: List<&2, List<&2, Node>>) -> Bool:
  match bs:
    case a <> b <> c <> d <> e <> t: False{}
    case _: True{}

def check(+all: List<&2, List<&2, Node>>, bs: List<&2, List<&2, Node>>) -> Bool:
  match bs:
    case Nil{}: True{}
    case b <> t: check_block(all, b) && check(all, t)

# The scan. After each scalar it holds the words and the scalar just read,
# the follow set of the nodes that read it, and whether that follow set is
# empty. Once it is empty no longer text can match, so the scan stops instead
# of reading the rest. Acceptance is decided once, at the end.

type Scan is Data:
  Scan{from: List<&2, U32>, last: U32, next: W4, dead: Bool}

def low(+w: U32) -> Bool:
  U32.is_ne((w .&. 1 : U32), 0)

def pick(b: Bool, f: W4, acc: W4) -> W4:
  match b:
    case True{}: w4_or(acc, f)
    case False{}: acc

def keep_block(ns: List<&2, Node>, +w: U32, +c: U32) -> List<&2, Bool>:
  match ns:
    case Nil{}: []
    case Node{h, Arc{a, d}, f} <> t: (low(w) && hit(a, c)) <> keep_block(t, (w >> 1n : U32), c)

# The nodes set in `ws` whose atom reads c.
def keep(bs: List<&2, List<&2, Node>>, ws: List<&2, U32>, +c: U32) -> List<&2, List<&2, Bool>>:
  match bs ws:
    case Nil{} _: []
    case b <> t Nil{}: []
    case b <> t w <> u: keep_block(b, w, c) <> keep(t, u, c)

def accept_block(ns: List<&2, Node>, live: List<&2, Bool>) -> Bool:
  match ns live:
    case Nil{} _: False{}
    case n <> t Nil{}: False{}
    case Node{h, Arc{a, d}, f} <> t b <> u: (b && P.nullable(d)) || accept_block(t, u)

def accept(bs: List<&2, List<&2, Node>>, live: List<&2, List<&2, Bool>>) -> Bool:
  match bs live:
    case Nil{} _: False{}
    case b <> t Nil{}: False{}
    case b <> t l <> u: accept_block(b, l) || accept(t, u)

def advance_block(ns: List<&2, Node>, +w: U32, +c: U32, acc: W4) -> W4:
  match ns:
    case Nil{}: acc
    case Node{h, Arc{a, d}, f} <> t: advance_block(t, (w >> 1n : U32), c, pick(low(w) && hit(a, c), f, acc))

# The union of the follow sets of the nodes set in `ws` whose atom reads c.
def advance(bs: List<&2, List<&2, Node>>, ws: List<&2, U32>, +c: U32, acc: W4) -> W4:
  match bs ws:
    case Nil{} _: acc
    case b <> t Nil{}: acc
    case b <> t w <> u: advance(t, u, c, advance_block(b, w, c, acc))

# Whether a follow set is empty.
def w4_dead(x: W4) -> Bool:
  match x:
    case W4{a, b, c, d}: U32.is_eq(a, 0) && U32.is_eq(b, 0) && U32.is_eq(c, 0) && U32.is_eq(d, 0)

def settle(+ws: List<&2, U32>, +c: U32, +g: W4) -> Scan:
  Scan{ws, c, g, w4_dead(g)}

def read(+bs: List<&2, List<&2, Node>>, +ws: List<&2, U32>, +c: U32) -> Scan:
  settle(ws, c, advance(bs, ws, c, W4{0, 0, 0, 0}))

def run(s: String, +bs: List<&2, List<&2, Node>>, st: Scan) -> Bool:
  match s st:
    case SNil{} Scan{ws, c, g, d}: accept(bs, keep(bs, ws, c))
    case SCon{Chr{c}, t} Scan{ws, e, g, True{}}: False{}
    case SCon{Chr{c}, t} Scan{ws, e, g, False{}}: run(t, bs, read(bs, w4_list(g), c))

# The table's nodes, 32 to a block.
def table_blocks(+p: P.Pattern) -> List<&2, List<&2, Node>>:
  blocks_go(most(), chunk(32n, List.reverse(&2, Node, closure(P.limit(), admit_all(linear(p), ([], [])))), []))

def scan(ok: Bool, +p: P.Pattern, +bs: List<&2, List<&2, Node>>, start: List<&2, U32>, s: String) -> Bool:
  match ok s:
    case False{} _: P.matches(p, s)
    case True{} SNil{}: P.nullable(p)
    case True{} SCon{Chr{c}, t}: run(t, bs, read(bs, start, c))

# Whole-string match. Callers check `valid` first; invalid counts match nothing.
def matches(+p: P.Pattern, s: String) -> Bool:
  +bs = table_blocks(p)
  +first = linear(p)
  scan(fits4(bs) && check(bs, bs) && all_found(bs, first), p, attach(bs, bs), follow_of(bs, first), s)
