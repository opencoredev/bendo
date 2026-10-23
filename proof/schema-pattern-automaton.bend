# The automaton matcher agrees with the specification. The closure that builds
# the table is not trusted: only a table whose check passes is used, and the
# check alone makes every node's follow set mean what the node's residual
# accepts after one more scalar.
import Base
import ../LAWS.bend as Laws
import ./equality.bend as E
import ../src/data/schema-pattern.bend as P
import ../src/data/schema-pattern-automaton.bend as A
import ../src/data/schema-spec.bend as Spec
import ./schema-pattern.bend as PP
import ./schema-pattern-core.bend as Core
import ./schema-pattern-linear.bend as L
import ./schema-pattern-bits.bend as B

# Boolean bookkeeping.

def or_false(+a: Bool) -> {a == (a || False{}) : Bool}:
  match a:
    case True{}: {==}
    case False{}: {==}

def and_false(+a: Bool) -> {(a && False{}) == False{} : Bool}:
  match a:
    case True{}: {==}
    case False{}: {==}

def or_assoc(+a: Bool, -b: Bool, -c: Bool) -> {((a || b) || c) == (a || (b || c)) : Bool}:
  match a:
    case True{}: {==}
    case False{}: {==}

# (a || b) || (c || d) regrouped as (a || c) || (b || d).
def or_swap(+a: Bool, +b: Bool, +c: Bool, -d: Bool) -> {((a || b) || (c || d)) == ((a || c) || (b || d)) : Bool}:
  match a b c:
    case True{} _ _: {==}
    case False{} False{} _: {==}
    case False{} True{} True{}: {==}
    case False{} True{} False{}: {==}

def dist(+x: Bool, +y: Bool, +h: Bool, +m: Bool) -> {(((x || y) && h) && m) == (((x && h) && m) || ((y && h) && m)) : Bool}:
  match x y h m:
    case True{} True{} True{} True{}: {==}
    case True{} True{} True{} False{}: {==}
    case True{} True{} False{} _: {==}
    case True{} False{} True{} True{}: {==}
    case True{} False{} True{} False{}: {==}
    case True{} False{} False{} _: {==}
    case False{} True{} True{} True{}: {==}
    case False{} True{} True{} False{}: {==}
    case False{} True{} False{} _: {==}
    case False{} False{} _ _: {==}

# v || (q && v) is v.
def absorb(+v: Bool, +q: Bool) -> {(v || (q && v)) == v : Bool}:
  match v:
    case True{}: {==}
    case False{}: and_false(q)

def or_and(+p: Bool, +q: Bool, +v: Bool) -> {((p && v) || (q && v)) == ((p || q) && v) : Bool}:
  match p:
    case True{}: absorb(v, q)
    case False{}: {==}

def and_assoc(+b: Bool, -h: Bool, -m: Bool) -> {((b && h) && m) == (b && (h && m)) : Bool}:
  match b:
    case True{}: {==}
    case False{}: {==}

# What `A.advance` computes in one pass: the union of the follow sets of a
# live set's nodes.

def gather_block(ns: List<&2, A.Node>, live: List<&2, Bool>, acc: A.W4) -> A.W4:
  match ns live:
    case Nil{} _: acc
    case n <> t Nil{}: acc
    case A.Node{h, x, f} <> t b <> u: gather_block(t, u, A.pick(b, f, acc))

def gather(bs: List<&2, List<&2, A.Node>>, live: List<&2, List<&2, Bool>>, acc: A.W4) -> A.W4:
  match bs live:
    case Nil{} _: acc
    case b <> t Nil{}: acc
    case b <> t l <> u: gather(t, u, gather_block(b, l, acc))

# Meaning. A follow set reads c then t; a live set reads a whole word.

def arc_lang(x: A.Arc, +c: U32, +t: String) -> Bool:
  match x:
    case A.Arc{a, d}: A.hit(a, c) && Spec.matches(d, t)

def walk(ns: List<&2, A.Node>, bs: List<&2, Bool>, +c: U32, +t: String) -> Bool:
  match ns bs:
    case Nil{} _: False{}
    case n <> r Nil{}: False{}
    case A.Node{h, A.Arc{a, d}, f} <> r b <> u: ((b && A.hit(a, c)) && Spec.matches(d, t)) || walk(r, u, c, t)

def flang(bs: List<&2, List<&2, A.Node>>, ws: List<&2, U32>, +c: U32, +t: String) -> Bool:
  match bs ws:
    case Nil{} _: False{}
    case b <> r Nil{}: False{}
    case b <> r w <> u: walk(b, B.bits32(w), c, t) || flang(r, u, c, t)

def lang_block(ns: List<&2, A.Node>, live: List<&2, Bool>, +s: String) -> Bool:
  match ns live:
    case Nil{} _: False{}
    case n <> r Nil{}: False{}
    case A.Node{h, A.Arc{a, d}, f} <> r b <> u: (b && Spec.matches(d, s)) || lang_block(r, u, s)

def lang(bs: List<&2, List<&2, A.Node>>, live: List<&2, List<&2, Bool>>, +s: String) -> Bool:
  match bs live:
    case Nil{} _: False{}
    case b <> r Nil{}: False{}
    case b <> r l <> u: lang_block(b, l, s) || lang(r, u, s)

def walk_nil(+ns: List<&2, A.Node>, +c: U32, +t: String) -> {walk(ns, [], c, t) == False{} : Bool}:
  match ns:
    case Nil{}: {==}
    case A.Node{h, A.Arc{a, d}, f} <> r: {==}

def flang_nil(+bs: List<&2, List<&2, A.Node>>, +c: U32, +t: String) -> {flang(bs, [], c, t) == False{} : Bool}:
  match bs:
    case Nil{}: {==}
    case b <> r: {==}

# Words.

def walk_pad(+ns: List<&2, A.Node>, +xs: List<&2, Bool>, +c: U32, +t: String) -> {walk(ns, List.append(&2, Bool, xs, [False{}]), c, t) == walk(ns, xs, c, t) : Bool}:
  match ns xs:
    case Nil{} _: {==}
    case A.Node{h, A.Arc{a, d}, f} <> r Nil{}: walk_nil(r, c, t)
    case A.Node{h, A.Arc{a, d}, f} <> r b <> u:
      %walk_pad(r, u, c, t) : {walk(A.Node{h, A.Arc{a, d}, f} <> r, List.append(&2, Bool, b <> u, [False{}]), c, t) == (((b && A.hit(a, c)) && Spec.matches(d, t)) || _) : Bool}
      {==}

def walk_or(+ns: List<&2, A.Node>, +xs: List<&2, Bool>, +ys: List<&2, Bool>, +c: U32, +t: String) -> {walk(ns, B.zip_or(xs, ys), c, t) == (walk(ns, xs, c, t) || walk(ns, ys, c, t)) : Bool}:
  match ns xs ys:
    case Nil{} _ _: {==}
    case A.Node{h, A.Arc{k, d}, f} <> r Nil{} _: {==}
    case A.Node{h, A.Arc{k, d}, f} <> r a <> s Nil{}: or_false(walk(A.Node{h, A.Arc{k, d}, f} <> r, a <> s, c, t))
    case A.Node{h, A.Arc{k, d}, f} <> r a <> s b <> u:
      %or_swap(((a && A.hit(k, c)) && Spec.matches(d, t)), ((b && A.hit(k, c)) && Spec.matches(d, t)), walk(r, s, c, t), walk(r, u, c, t)) : {walk(A.Node{h, A.Arc{k, d}, f} <> r, B.zip_or(a <> s, b <> u), c, t) == _ : Bool}
      %dist(a, b, A.hit(k, c), Spec.matches(d, t)) : {walk(A.Node{h, A.Arc{k, d}, f} <> r, B.zip_or(a <> s, b <> u), c, t) == (_ || (walk(r, s, c, t) || walk(r, u, c, t))) : Bool}
      %walk_or(r, s, u, c, t) : {walk(A.Node{h, A.Arc{k, d}, f} <> r, B.zip_or(a <> s, b <> u), c, t) == ((((a || b) && A.hit(k, c)) && Spec.matches(d, t)) || _) : Bool}
      {==}

# A union of follow sets means the union of their meanings.
def flang_or(+bs: List<&2, List<&2, A.Node>>, +x: List<&2, U32>, +y: List<&2, U32>, +c: U32, +t: String) -> {flang(bs, A.or_words(x, y), c, t) == (flang(bs, x, c, t) || flang(bs, y, c, t)) : Bool}:
  match bs x y:
    case Nil{} Nil{} _: {==}
    case Nil{} a <> s Nil{}: {==}
    case Nil{} a <> s b <> u: {==}
    case n <> r Nil{} _: {==}
    case n <> r a <> s Nil{}: or_false(flang(n <> r, a <> s, c, t))
    case n <> r a <> s b <> u:
      %or_swap(walk(n, B.bits32(a), c, t), walk(n, B.bits32(b), c, t), flang(r, s, c, t), flang(r, u, c, t)) : {flang(n <> r, A.or_words(a <> s, b <> u), c, t) == _ : Bool}
      %walk_or(n, B.bits32(a), B.bits32(b), c, t) : {flang(n <> r, A.or_words(a <> s, b <> u), c, t) == (_ || (flang(r, s, c, t) || flang(r, u, c, t))) : Bool}
      %B.or32(a, b) : {flang(n <> r, A.or_words(a <> s, b <> u), c, t) == (walk(n, _, c, t) || (flang(r, s, c, t) || flang(r, u, c, t))) : Bool}
      %flang_or(r, s, u, c, t) : {flang(n <> r, A.or_words(a <> s, b <> u), c, t) == (walk(n, B.bits32((a .|. b : U32)), c, t) || _) : Bool}
      {==}

# Four-word follow sets mean the list of their words.

def flang4(bs: List<&2, List<&2, A.Node>>, x: A.W4, +c: U32, +t: String) -> Bool:
  flang(bs, A.w4_list(x), c, t)

def flang4_or(+bs: List<&2, List<&2, A.Node>>, +x: A.W4, +y: A.W4, +c: U32, +t: String) -> {flang4(bs, A.w4_or(x, y), c, t) == (flang4(bs, x, c, t) || flang4(bs, y, c, t)) : Bool}:
  match x y:
    case A.W4{a, b, g, d} A.W4{e, f, h, i}: flang_or(bs, [a, b, g, d], [e, f, h, i], c, t)

def walk_zero(+n: Nat, +ns: List<&2, A.Node>, +c: U32, +t: String) -> {walk(ns, B.bits(n, Word.zero(n)), c, t) == False{} : Bool}:
  match n:
    case 0n: walk_nil(ns, c, t)
    case 1n+p:
      match ns:
        case Nil{}: {==}
        case A.Node{h, A.Arc{a, d}, f} <> r: walk_zero(p, r, c, t)

def zeros(k: Nat) -> List<&2, U32>:
  match k:
    case 0n: []
    case 1n+j: 0 <> zeros(j)

def flang_zeros(+bs: List<&2, List<&2, A.Node>>, +k: Nat, +c: U32, +t: String) -> {flang(bs, zeros(k), c, t) == False{} : Bool}:
  match bs k:
    case Nil{} _: {==}
    case b <> r 0n: {==}
    case b <> r 1n+j:
      %walk_zero(32n, b, c, t) : {flang(b <> r, zeros(1n+j), c, t) == (_ || False{}) : Bool}
      %flang_zeros(r, j, c, t) : {flang(b <> r, zeros(1n+j), c, t) == (walk(b, B.bits(32n, Word.zero(32n)), c, t) || _) : Bool}
      {==}

# Zero words past the end add nothing.
def pad_zero(+bs: List<&2, List<&2, A.Node>>, +k: Nat, +c: U32, +t: String) -> {flang(bs, zeros(k), c, t) == flang(bs, [], c, t) : Bool}:
  Equal.trans(Bool, flang(bs, zeros(k), c, t), False{}, flang(bs, [], c, t), flang_zeros(bs, k, c, t), Equal.sym(Bool, flang(bs, [], c, t), False{}, flang_nil(bs, c, t)))

def fits_attach(+all: List<&2, List<&2, A.Node>>, +bs: List<&2, List<&2, A.Node>>) -> {A.fits4(A.attach(all, bs)) == A.fits4(bs) : Bool}:
  match bs:
    case a <> b <> g <> d <> e <> r: {==}
    case a <> b <> g <> d <> Nil{}: {==}
    case a <> b <> g <> Nil{}: {==}
    case a <> b <> Nil{}: {==}
    case a <> Nil{}: {==}
    case Nil{}: {==}

# Packing a follow set into four words keeps it, in a table of four blocks.
def w4_of_lang(+ws: List<&2, U32>, +bs: List<&2, List<&2, A.Node>>, +c: U32, +t: String, +e: {A.fits4(bs) == True{} : Bool}) -> {flang4(bs, A.w4_of(ws), c, t) == flang(bs, ws, c, t) : Bool}:
  match ws:
    case Nil{}: pad_zero(bs, 4n, c, t)
    case a <> Nil{}:
      match bs:
        case Nil{}: {==}
        case b0 <> r:
          %pad_zero(r, 3n, c, t) : {flang(b0 <> r, [a, 0, 0, 0], c, t) == (walk(b0, B.bits32(a), c, t) || _) : Bool}
          {==}
    case a <> b <> Nil{}:
      match bs:
        case Nil{}: {==}
        case b0 <> Nil{}: {==}
        case b0 <> b1 <> r:
          %pad_zero(r, 2n, c, t) : {flang(b0 <> b1 <> r, [a, b, 0, 0], c, t) == (walk(b0, B.bits32(a), c, t) || (walk(b1, B.bits32(b), c, t) || _)) : Bool}
          {==}
    case a <> b <> g <> Nil{}:
      match bs:
        case Nil{}: {==}
        case b0 <> Nil{}: {==}
        case b0 <> b1 <> Nil{}: {==}
        case b0 <> b1 <> b2 <> r:
          %pad_zero(r, 1n, c, t) : {flang(b0 <> b1 <> b2 <> r, [a, b, g, 0], c, t) == (walk(b0, B.bits32(a), c, t) || (walk(b1, B.bits32(b), c, t) || (walk(b2, B.bits32(g), c, t) || _))) : Bool}
          {==}
    case a <> b <> g <> d <> u:
      match bs:
        case Nil{}: {==}
        case b0 <> Nil{}: {==}
        case b0 <> b1 <> Nil{}: {==}
        case b0 <> b1 <> b2 <> Nil{}: {==}
        case b0 <> b1 <> b2 <> b3 <> Nil{}: {==}
        case b0 <> b1 <> b2 <> b3 <> b4 <> r: E.absurd({flang4(b0 <> b1 <> b2 <> b3 <> b4 <> r, A.w4_of(a <> b <> g <> d <> u), c, t) == flang(b0 <> b1 <> b2 <> b3 <> b4 <> r, a <> b <> g <> d <> u, c, t) : Bool}, E.false_true(e))

# Lookups. A set bit is a node whose arc is x, so it means what x means.

def atom_sound(+a: A.Atom, +b: A.Atom, +e: {A.same_atom(a, b) == True{} : Bool}) -> {a == b : A.Atom}:
  match a b:
    case A.AChar{x} A.AChar{y}: Equal.cong(U32, A.Atom, z => A.AChar{z}, x, y, Laws.u32_eq_sound(x, y, e))
    case A.AClass{x} A.AClass{y}: Equal.cong(List<&2, P.Range>, A.Atom, z => A.AClass{z}, x, y, PP.ranges_sound(x, y, e))
    case A.AChar{x} A.AClass{y}: E.absurd({A.AChar{x} == A.AClass{y} : A.Atom}, E.false_true(e))
    case A.AClass{x} A.AChar{y}: E.absurd({A.AClass{x} == A.AChar{y} : A.Atom}, E.false_true(e))

def arc_sound(+x: A.Arc, +y: A.Arc, +e: {A.same_arc(x, y) == True{} : Bool}) -> {x == y : A.Arc}:
  match x y:
    case A.Arc{a, d} A.Arc{b, f}:
      %atom_sound(a, b, PP.and_l(A.same_atom(a, b), P.same(d, f), e)) : {A.Arc{a, d} == A.Arc{_, f} : A.Arc}
      %PP.same_sound(d, f, PP.and_r(A.same_atom(a, b), P.same(d, f), e)) : {A.Arc{a, d} == A.Arc{a, _} : A.Arc}
      {==}

def keyed_sound(+g: Bool, +y: A.Arc, +x: A.Arc, +e: {A.same_keyed(g, y, x) == True{} : Bool}) -> {y == x : A.Arc}:
  match g:
    case True{}: arc_sound(y, x, e)
    case False{}: E.absurd({y == x : A.Arc}, E.false_true(e))

# One node's term, then the rest found or not.
def find_head(g: Bool, +hk: Bool, +y: A.Arc, +x: A.Arc, +q: Bool, +c: U32, +t: String) -> {A.same_keyed(hk, y, x) == g : Bool} -> {((g && arc_lang(y, c, t)) || (q && arc_lang(x, c, t))) == ((g || q) && arc_lang(x, c, t)) : Bool}:
  match g:
    case False{}: e => {==}
    case True{}: e =>
      %keyed_sound(hk, y, x, e) : {(arc_lang(y, c, t) || (q && arc_lang(_, c, t))) == arc_lang(_, c, t) : Bool}
      absorb(arc_lang(y, c, t), q)

def find_word_lang(+n: Nat, +ns: List<&2, A.Node>, +k: U32, +x: A.Arc, +c: U32, +t: String) -> {walk(ns, B.bits(n, A.find_word(n, ns, k, x)), c, t) == (A.found_word(n, ns, k, x) && arc_lang(x, c, t)) : Bool}:
  match n:
    case 0n: walk_nil(ns, c, t)
    case 1n+p:
      match ns:
        case Nil{}: {==}
        case A.Node{h, A.Arc{a, d}, f} <> r:
          %find_head(A.same_keyed(U32.is_eq(h, k), A.Arc{a, d}, x), U32.is_eq(h, k), A.Arc{a, d}, x, A.found_word(p, r, k, x), c, t)({==}) : {walk(A.Node{h, A.Arc{a, d}, f} <> r, B.bits(1n+p, A.find_word(1n+p, A.Node{h, A.Arc{a, d}, f} <> r, k, x)), c, t) == _ : Bool}
          %find_word_lang(p, r, k, x, c, t) : {walk(A.Node{h, A.Arc{a, d}, f} <> r, B.bits(1n+p, A.find_word(1n+p, A.Node{h, A.Arc{a, d}, f} <> r, k, x)), c, t) == ((A.same_keyed(U32.is_eq(h, k), A.Arc{a, d}, x) && arc_lang(A.Arc{a, d}, c, t)) || _) : Bool}
          %and_assoc(A.same_keyed(U32.is_eq(h, k), A.Arc{a, d}, x), A.hit(a, c), Spec.matches(d, t)) : {walk(A.Node{h, A.Arc{a, d}, f} <> r, B.bits(1n+p, A.find_word(1n+p, A.Node{h, A.Arc{a, d}, f} <> r, k, x)), c, t) == (_ || walk(r, B.bits(p, A.find_word(p, r, k, x)), c, t)) : Bool}
          {==}

def find_lang(+bs: List<&2, List<&2, A.Node>>, +k: U32, +x: A.Arc, +c: U32, +t: String) -> {flang(bs, A.find(bs, k, x), c, t) == (A.found(bs, k, x) && arc_lang(x, c, t)) : Bool}:
  match bs:
    case Nil{}: {==}
    case b <> r:
      %or_and(A.found_word(32n, b, k, x), A.found(r, k, x), arc_lang(x, c, t)) : {flang(b <> r, A.find(b <> r, k, x), c, t) == _ : Bool}
      %find_word_lang(32n, b, k, x, c, t) : {flang(b <> r, A.find(b <> r, k, x), c, t) == (_ || (A.found(r, k, x) && arc_lang(x, c, t))) : Bool}
      %find_lang(r, k, x, c, t) : {flang(b <> r, A.find(b <> r, k, x), c, t) == (walk(b, B.bits(32n, A.find_word(32n, b, k, x)), c, t) || _) : Bool}
      {==}

# A checked follow set means its arcs.
def follow_lang(+bs: List<&2, List<&2, A.Node>>, +xs: List<&2, A.Arc>, +c: U32, +t: String, +e: {A.all_found(bs, xs) == True{} : Bool}) -> {flang(bs, A.follow_of(bs, xs), c, t) == L.arcs_lang(xs, c, t) : Bool}:
  match xs:
    case Nil{}: flang_nil(bs, c, t)
    case A.Arc{a, d} <> r:
      %follow_lang(bs, r, c, t, PP.and_r(A.found(bs, A.arc_hash(A.Arc{a, d}), A.Arc{a, d}), A.all_found(bs, r), e)) : {flang(bs, A.follow_of(bs, A.Arc{a, d} <> r), c, t) == (arc_lang(A.Arc{a, d}, c, t) || _) : Bool}
      %PP.and_l(A.found(bs, A.arc_hash(A.Arc{a, d}), A.Arc{a, d}), A.all_found(bs, r), e) : {flang(bs, A.follow_of(bs, A.Arc{a, d} <> r), c, t) == ((_ && arc_lang(A.Arc{a, d}, c, t)) || flang(bs, A.follow_of(bs, r), c, t)) : Bool}
      %find_lang(bs, A.arc_hash(A.Arc{a, d}), A.Arc{a, d}, c, t) : {flang(bs, A.follow_of(bs, A.Arc{a, d} <> r), c, t) == (_ || flang(bs, A.follow_of(bs, r), c, t)) : Bool}
      %flang_or(bs, A.find(bs, A.arc_hash(A.Arc{a, d}), A.Arc{a, d}), A.follow_of(bs, r), c, t) : {flang(bs, A.follow_of(bs, A.Arc{a, d} <> r), c, t) == _ : Bool}
      {==}

# Attaching follow sets keeps every node's arc.

def walk_attach(+all: List<&2, List<&2, A.Node>>, +ns: List<&2, A.Node>, +xs: List<&2, Bool>, +c: U32, +t: String) -> {walk(A.attach_block(all, ns), xs, c, t) == walk(ns, xs, c, t) : Bool}:
  match ns xs:
    case Nil{} _: {==}
    case A.Node{h, A.Arc{a, d}, f} <> r Nil{}: {==}
    case A.Node{h, A.Arc{a, d}, f} <> r b <> u:
      %walk_attach(all, r, u, c, t) : {walk(A.attach_block(all, A.Node{h, A.Arc{a, d}, f} <> r), b <> u, c, t) == (((b && A.hit(a, c)) && Spec.matches(d, t)) || _) : Bool}
      {==}

def flang_attach(+all: List<&2, List<&2, A.Node>>, +bs: List<&2, List<&2, A.Node>>, +ws: List<&2, U32>, +c: U32, +t: String) -> {flang(A.attach(all, bs), ws, c, t) == flang(bs, ws, c, t) : Bool}:
  match bs ws:
    case Nil{} _: {==}
    case b <> r Nil{}: {==}
    case b <> r w <> u:
      %walk_attach(all, b, B.bits32(w), c, t) : {flang(A.attach(all, b <> r), w <> u, c, t) == (_ || flang(r, u, c, t)) : Bool}
      %flang_attach(all, r, u, c, t) : {flang(A.attach(all, b <> r), w <> u, c, t) == (walk(A.attach_block(all, b), B.bits32(w), c, t) || _) : Bool}
      {==}

# A good table: every node's follow set, read over the whole table, means what
# the node's residual accepts after c.

def GoodB(+all: List<&2, List<&2, A.Node>>, ns: List<&2, A.Node>, +c: U32, +t: String) -> Type:
  match ns:
    case Nil{}: Unit
    case A.Node{h, A.Arc{a, d}, f} <> r: {flang4(all, f, c, t) == Spec.matches(d, SCon{Chr{c}, t}) : Bool} & GoodB(all, r, c, t)

def Good(+all: List<&2, List<&2, A.Node>>, bs: List<&2, List<&2, A.Node>>, +c: U32, +t: String) -> Type:
  match bs:
    case Nil{}: Unit
    case b <> r: GoodB(all, b, c, t) & Good(all, r, c, t)

def good_node(+all: List<&2, List<&2, A.Node>>, +d: P.Pattern, +c: U32, +t: String, +ef: {A.fits4(all) == True{} : Bool}, +e: {A.all_found(all, A.linear(d)) == True{} : Bool}) -> {flang4(A.attach(all, all), A.w4_of(A.follow_of(all, A.linear(d))), c, t) == Spec.matches(d, SCon{Chr{c}, t}) : Bool}:
  %Equal.sym(Bool, Spec.matches(d, SCon{Chr{c}, t}), L.arcs_lang(A.linear(d), c, t), L.arcs_equiv(d, c, t)) : {flang4(A.attach(all, all), A.w4_of(A.follow_of(all, A.linear(d))), c, t) == _ : Bool}
  %follow_lang(all, A.linear(d), c, t, e) : {flang4(A.attach(all, all), A.w4_of(A.follow_of(all, A.linear(d))), c, t) == _ : Bool}
  %flang_attach(all, all, A.follow_of(all, A.linear(d)), c, t) : {flang4(A.attach(all, all), A.w4_of(A.follow_of(all, A.linear(d))), c, t) == _ : Bool}
  w4_of_lang(A.follow_of(all, A.linear(d)), A.attach(all, all), c, t, Equal.trans(Bool, A.fits4(A.attach(all, all)), A.fits4(all), True{}, fits_attach(all, all), ef))

def good_block(+all: List<&2, List<&2, A.Node>>, ns: List<&2, A.Node>, +c: U32, +t: String, +ef: {A.fits4(all) == True{} : Bool}, +e: {A.check_block(all, ns) == True{} : Bool}) -> GoodB(A.attach(all, all), A.attach_block(all, ns), c, t):
  match ns:
    case Nil{}: Unit{}
    case A.Node{h, A.Arc{a, +d}, f} <> +r: (good_node(all, d, c, t, ef, PP.and_l(A.all_found(all, A.linear(d)), A.check_block(all, r), e)), good_block(all, r, c, t, ef, PP.and_r(A.all_found(all, A.linear(d)), A.check_block(all, r), e)))

def good(+all: List<&2, List<&2, A.Node>>, bs: List<&2, List<&2, A.Node>>, +c: U32, +t: String, +ef: {A.fits4(all) == True{} : Bool}, +e: {A.check(all, bs) == True{} : Bool}) -> Good(A.attach(all, all), A.attach(all, bs), c, t):
  match bs:
    case Nil{}: Unit{}
    case +b <> +r: (good_block(all, b, c, t, ef, PP.and_l(A.check_block(all, b), A.check(all, r), e)), good(all, r, c, t, ef, PP.and_r(A.check_block(all, b), A.check(all, r), e)))

# Gathering: the union of the live nodes' follow sets.

def gl_block(+all: List<&2, List<&2, A.Node>>, ns: List<&2, A.Node>, live: List<&2, Bool>, +c: U32, +t: String) -> Bool:
  match ns live:
    case Nil{} _: False{}
    case n <> r Nil{}: False{}
    case A.Node{h, x, f} <> r b <> u: (b && flang4(all, f, c, t)) || gl_block(all, r, u, c, t)

def gl(+all: List<&2, List<&2, A.Node>>, bs: List<&2, List<&2, A.Node>>, live: List<&2, List<&2, Bool>>, +c: U32, +t: String) -> Bool:
  match bs live:
    case Nil{} _: False{}
    case b <> r Nil{}: False{}
    case b <> r l <> u: gl_block(all, b, l, c, t) || gl(all, r, u, c, t)

def pick_lang(+all: List<&2, List<&2, A.Node>>, +b: Bool, +f: A.W4, +acc: A.W4, +c: U32, +t: String) -> {flang4(all, A.pick(b, f, acc), c, t) == (flang4(all, acc, c, t) || (b && flang4(all, f, c, t))) : Bool}:
  match b:
    case True{}: flang4_or(all, acc, f, c, t)
    case False{}: or_false(flang4(all, acc, c, t))

def gather_block_lang(+all: List<&2, List<&2, A.Node>>, +ns: List<&2, A.Node>, +live: List<&2, Bool>, +acc: A.W4, +c: U32, +t: String) -> {flang4(all, gather_block(ns, live, acc), c, t) == (flang4(all, acc, c, t) || gl_block(all, ns, live, c, t)) : Bool}:
  match ns live:
    case Nil{} _: or_false(flang4(all, acc, c, t))
    case A.Node{h, x, f} <> r Nil{}: or_false(flang4(all, acc, c, t))
    case A.Node{h, x, f} <> r b <> u:
      %or_assoc(flang4(all, acc, c, t), (b && flang4(all, f, c, t)), gl_block(all, r, u, c, t)) : {flang4(all, gather_block(A.Node{h, x, f} <> r, b <> u, acc), c, t) == _ : Bool}
      %pick_lang(all, b, f, acc, c, t) : {flang4(all, gather_block(A.Node{h, x, f} <> r, b <> u, acc), c, t) == (_ || gl_block(all, r, u, c, t)) : Bool}
      gather_block_lang(all, r, u, A.pick(b, f, acc), c, t)

def gather_lang(+all: List<&2, List<&2, A.Node>>, +bs: List<&2, List<&2, A.Node>>, +live: List<&2, List<&2, Bool>>, +acc: A.W4, +c: U32, +t: String) -> {flang4(all, gather(bs, live, acc), c, t) == (flang4(all, acc, c, t) || gl(all, bs, live, c, t)) : Bool}:
  match bs live:
    case Nil{} _: or_false(flang4(all, acc, c, t))
    case b <> r Nil{}: or_false(flang4(all, acc, c, t))
    case b <> r l <> u:
      %or_assoc(flang4(all, acc, c, t), gl_block(all, b, l, c, t), gl(all, r, u, c, t)) : {flang4(all, gather(b <> r, l <> u, acc), c, t) == _ : Bool}
      %gather_block_lang(all, b, l, acc, c, t) : {flang4(all, gather(b <> r, l <> u, acc), c, t) == (_ || gl(all, r, u, c, t)) : Bool}
      gather_lang(all, r, u, gather_block(b, l, acc), c, t)

def gl_good_block(+all: List<&2, List<&2, A.Node>>, +ns: List<&2, A.Node>, +live: List<&2, Bool>, +c: U32, +t: String, g: GoodB(all, ns, c, t)) -> {gl_block(all, ns, live, c, t) == lang_block(ns, live, SCon{Chr{c}, t}) : Bool}:
  match ns live:
    case Nil{} _: {==}
    case A.Node{h, A.Arc{a, d}, f} <> r Nil{}: {==}
    case A.Node{h, A.Arc{a, d}, f} <> r b <> u:
      (g1, g2) = g
      %g1 : {gl_block(all, A.Node{h, A.Arc{a, d}, f} <> r, b <> u, c, t) == ((b && _) || lang_block(r, u, SCon{Chr{c}, t})) : Bool}
      %gl_good_block(all, r, u, c, t, g2) : {gl_block(all, A.Node{h, A.Arc{a, d}, f} <> r, b <> u, c, t) == ((b && flang4(all, f, c, t)) || _) : Bool}
      {==}

def gl_good(+all: List<&2, List<&2, A.Node>>, +bs: List<&2, List<&2, A.Node>>, +live: List<&2, List<&2, Bool>>, +c: U32, +t: String, g: Good(all, bs, c, t)) -> {gl(all, bs, live, c, t) == lang(bs, live, SCon{Chr{c}, t}) : Bool}:
  match bs live:
    case Nil{} _: {==}
    case b <> r Nil{}: {==}
    case b <> r l <> u:
      (g1, g2) = g
      %gl_good_block(all, b, l, c, t, g1) : {gl(all, b <> r, l <> u, c, t) == (_ || lang(r, u, SCon{Chr{c}, t})) : Bool}
      %gl_good(all, r, u, c, t, g2) : {gl(all, b <> r, l <> u, c, t) == (gl_block(all, b, l, c, t) || _) : Bool}
      {==}

# Keeping the nodes that read c.

def keep_block_lang(+ns: List<&2, A.Node>, +w: U32, +c: U32, +t: String) -> {lang_block(ns, A.keep_block(ns, w, c), t) == walk(ns, B.bits32(w), c, t) : Bool}:
  match ns:
    case Nil{}: {==}
    case A.Node{h, A.Arc{a, d}, f} <> r:
      match w:
        case U32{x}:
          match x:
            case WCon{b, u}:
              %walk_pad(r, B.bits(31n, u), c, t) : {lang_block(A.Node{h, A.Arc{a, d}, f} <> r, A.keep_block(A.Node{h, A.Arc{a, d}, f} <> r, U32{WCon{b, u}}, c), t) == (((b && A.hit(a, c)) && Spec.matches(d, t)) || _) : Bool}
              %B.shift32(U32{WCon{b, u}}) : {lang_block(A.Node{h, A.Arc{a, d}, f} <> r, A.keep_block(A.Node{h, A.Arc{a, d}, f} <> r, U32{WCon{b, u}}, c), t) == (((b && A.hit(a, c)) && Spec.matches(d, t)) || walk(r, _, c, t)) : Bool}
              %keep_block_lang(r, (U32{WCon{b, u}} >> 1n : U32), c, t) : {lang_block(A.Node{h, A.Arc{a, d}, f} <> r, A.keep_block(A.Node{h, A.Arc{a, d}, f} <> r, U32{WCon{b, u}}, c), t) == (((b && A.hit(a, c)) && Spec.matches(d, t)) || _) : Bool}
              %B.low32(U32{WCon{b, u}}) : {lang_block(A.Node{h, A.Arc{a, d}, f} <> r, A.keep_block(A.Node{h, A.Arc{a, d}, f} <> r, U32{WCon{b, u}}, c), t) == (((_ && A.hit(a, c)) && Spec.matches(d, t)) || lang_block(r, A.keep_block(r, (U32{WCon{b, u}} >> 1n : U32), c), t)) : Bool}
              {==}

def keep_lang(+bs: List<&2, List<&2, A.Node>>, +ws: List<&2, U32>, +c: U32, +t: String) -> {lang(bs, A.keep(bs, ws, c), t) == flang(bs, ws, c, t) : Bool}:
  match bs ws:
    case Nil{} _: {==}
    case b <> r Nil{}: {==}
    case b <> r w <> u:
      %keep_block_lang(b, w, c, t) : {lang(b <> r, A.keep(b <> r, w <> u, c), t) == (_ || flang(r, u, c, t)) : Bool}
      %keep_lang(r, u, c, t) : {lang(b <> r, A.keep(b <> r, w <> u, c), t) == (lang_block(b, A.keep_block(b, w, c), t) || _) : Bool}
      {==}

# Accepting at the end of the text.

def accept_block_lang(+ns: List<&2, A.Node>, +live: List<&2, Bool>) -> {A.accept_block(ns, live) == lang_block(ns, live, "") : Bool}:
  match ns live:
    case Nil{} _: {==}
    case A.Node{h, A.Arc{a, d}, f} <> r Nil{}: {==}
    case A.Node{h, A.Arc{a, d}, f} <> r b <> u:
      %Core.nullable_equiv(d) : {A.accept_block(A.Node{h, A.Arc{a, d}, f} <> r, b <> u) == ((b && _) || lang_block(r, u, "")) : Bool}
      %accept_block_lang(r, u) : {A.accept_block(A.Node{h, A.Arc{a, d}, f} <> r, b <> u) == ((b && P.nullable(d)) || _) : Bool}
      {==}

def accept_lang(+bs: List<&2, List<&2, A.Node>>, +live: List<&2, List<&2, Bool>>) -> {A.accept(bs, live) == lang(bs, live, "") : Bool}:
  match bs live:
    case Nil{} _: {==}
    case b <> r Nil{}: {==}
    case b <> r l <> u:
      %accept_block_lang(b, l) : {A.accept(b <> r, l <> u) == (_ || lang(r, u, "")) : Bool}
      %accept_lang(r, u) : {A.accept(b <> r, l <> u) == (A.accept_block(b, l) || _) : Bool}
      {==}

# One pass computes the follow set of the nodes that read a scalar.

def advance_block_eq(+ns: List<&2, A.Node>, +w: U32, +c: U32, +g: A.W4) -> {A.advance_block(ns, w, c, g) == gather_block(ns, A.keep_block(ns, w, c), g) : A.W4}:
  match ns:
    case Nil{}: {==}
    case A.Node{h, A.Arc{a, d}, f} <> t: advance_block_eq(t, (w >> 1n : U32), c, A.pick(A.low(w) && A.hit(a, c), f, g))

def advance_eq(+bs: List<&2, List<&2, A.Node>>, +ws: List<&2, U32>, +c: U32, +g: A.W4) -> {A.advance(bs, ws, c, g) == gather(bs, A.keep(bs, ws, c), g) : A.W4}:
  match bs ws:
    case Nil{} _: {==}
    case b <> t Nil{}: {==}
    case b <> t w <> u:
      %advance_block_eq(b, w, c, g) : {A.advance(t, u, c, A.advance_block(b, w, c, g)) == gather(t, A.keep(t, u, c), _) : A.W4}
      advance_eq(t, u, c, A.advance_block(b, w, c, g))

# An empty follow set means nothing.
def dead_lang(+bs: List<&2, List<&2, A.Node>>, +x: A.W4, +c: U32, +t: String, +e: {A.w4_dead(x) == True{} : Bool}) -> {flang4(bs, x, c, t) == False{} : Bool}:
  match x:
    case A.W4{a, b, g, d}:
      +abg = PP.and_l((U32.is_eq(a, 0) && U32.is_eq(b, 0)) && U32.is_eq(g, 0), U32.is_eq(d, 0), e)
      +ab = PP.and_l(U32.is_eq(a, 0) && U32.is_eq(b, 0), U32.is_eq(g, 0), abg)
      %Equal.sym(U32, a, 0, Laws.u32_eq_sound(a, 0, PP.and_l(U32.is_eq(a, 0), U32.is_eq(b, 0), ab))) : {flang4(bs, A.W4{_, b, g, d}, c, t) == False{} : Bool}
      %Equal.sym(U32, b, 0, Laws.u32_eq_sound(b, 0, PP.and_r(U32.is_eq(a, 0), U32.is_eq(b, 0), ab))) : {flang4(bs, A.W4{0, _, g, d}, c, t) == False{} : Bool}
      %Equal.sym(U32, g, 0, Laws.u32_eq_sound(g, 0, PP.and_r(U32.is_eq(a, 0) && U32.is_eq(b, 0), U32.is_eq(g, 0), abg))) : {flang4(bs, A.W4{0, 0, _, d}, c, t) == False{} : Bool}
      %Equal.sym(U32, d, 0, Laws.u32_eq_sound(d, 0, PP.and_r((U32.is_eq(a, 0) && U32.is_eq(b, 0)) && U32.is_eq(g, 0), U32.is_eq(d, 0), e))) : {flang4(bs, A.W4{0, 0, 0, _}, c, t) == False{} : Bool}
      flang_zeros(bs, 4n, c, t)

# The live set's meaning after one more scalar is its follow set's meaning.
def next_lang(+all: List<&2, List<&2, A.Node>>, +live: List<&2, List<&2, Bool>>, +c: U32, +t: String, +ef: {A.fits4(all) == True{} : Bool}, +e: {A.check(all, all) == True{} : Bool}) -> {flang4(A.attach(all, all), gather(A.attach(all, all), live, A.W4{0, 0, 0, 0}), c, t) == lang(A.attach(all, all), live, SCon{Chr{c}, t}) : Bool}:
  %gl_good(A.attach(all, all), A.attach(all, all), live, c, t, good(all, all, c, t, ef, e)) : {flang4(A.attach(all, all), gather(A.attach(all, all), live, A.W4{0, 0, 0, 0}), c, t) == _ : Bool}
  %flang_zeros(A.attach(all, all), 4n, c, t) : {flang4(A.attach(all, all), gather(A.attach(all, all), live, A.W4{0, 0, 0, 0}), c, t) == (_ || gl(A.attach(all, all), A.attach(all, all), live, c, t)) : Bool}
  gather_lang(A.attach(all, all), A.attach(all, all), live, A.W4{0, 0, 0, 0}, c, t)

# The scan keeps the meaning of the nodes that read the last scalar: what
# they accept of the rest.
def run_lang(+s: String, +all: List<&2, List<&2, A.Node>>, +ws: List<&2, U32>, +c: U32, dead: Bool, +ef: {A.fits4(all) == True{} : Bool}, +e: {A.check(all, all) == True{} : Bool}) -> {A.w4_dead(A.advance(A.attach(all, all), ws, c, A.W4{0, 0, 0, 0})) == dead : Bool} -> {A.run(s, A.attach(all, all), A.Scan{ws, c, A.advance(A.attach(all, all), ws, c, A.W4{0, 0, 0, 0}), dead}) == lang(A.attach(all, all), A.keep(A.attach(all, all), ws, c), s) : Bool}:
  match s:
    case SNil{}: ed => accept_lang(A.attach(all, all), A.keep(A.attach(all, all), ws, c))
    case SCon{Chr{k}, t}:
      match dead:
        case True{}: +ed =>
          %next_lang(all, A.keep(A.attach(all, all), ws, c), k, t, ef, e) : {A.run(SCon{Chr{k}, t}, A.attach(all, all), A.Scan{ws, c, A.advance(A.attach(all, all), ws, c, A.W4{0, 0, 0, 0}), True{}}) == _ : Bool}
          %advance_eq(A.attach(all, all), ws, c, A.W4{0, 0, 0, 0}) : {A.run(SCon{Chr{k}, t}, A.attach(all, all), A.Scan{ws, c, A.advance(A.attach(all, all), ws, c, A.W4{0, 0, 0, 0}), True{}}) == flang4(A.attach(all, all), _, k, t) : Bool}
          Equal.sym(Bool, flang4(A.attach(all, all), A.advance(A.attach(all, all), ws, c, A.W4{0, 0, 0, 0}), k, t), False{}, dead_lang(A.attach(all, all), A.advance(A.attach(all, all), ws, c, A.W4{0, 0, 0, 0}), k, t, ed))
        case False{}: ed =>
          %next_lang(all, A.keep(A.attach(all, all), ws, c), k, t, ef, e) : {A.run(SCon{Chr{k}, t}, A.attach(all, all), A.Scan{ws, c, A.advance(A.attach(all, all), ws, c, A.W4{0, 0, 0, 0}), False{}}) == _ : Bool}
          %advance_eq(A.attach(all, all), ws, c, A.W4{0, 0, 0, 0}) : {A.run(SCon{Chr{k}, t}, A.attach(all, all), A.Scan{ws, c, A.advance(A.attach(all, all), ws, c, A.W4{0, 0, 0, 0}), False{}}) == flang4(A.attach(all, all), _, k, t) : Bool}
          %keep_lang(A.attach(all, all), A.w4_list(A.advance(A.attach(all, all), ws, c, A.W4{0, 0, 0, 0})), k, t) : {A.run(SCon{Chr{k}, t}, A.attach(all, all), A.Scan{ws, c, A.advance(A.attach(all, all), ws, c, A.W4{0, 0, 0, 0}), False{}}) == _ : Bool}
          run_lang(t, all, A.w4_list(A.advance(A.attach(all, all), ws, c, A.W4{0, 0, 0, 0})), k, A.w4_dead(A.advance(A.attach(all, all), A.w4_list(A.advance(A.attach(all, all), ws, c, A.W4{0, 0, 0, 0})), k, A.W4{0, 0, 0, 0})), ef, e)({==})

# Reading one scalar from a follow set, then the rest.
def read_lang(+t: String, +all: List<&2, List<&2, A.Node>>, +ws: List<&2, U32>, +c: U32, +ef: {A.fits4(all) == True{} : Bool}, +e: {A.check(all, all) == True{} : Bool}) -> {A.run(t, A.attach(all, all), A.read(A.attach(all, all), ws, c)) == flang(A.attach(all, all), ws, c, t) : Bool}:
  %keep_lang(A.attach(all, all), ws, c, t) : {A.run(t, A.attach(all, all), A.read(A.attach(all, all), ws, c)) == _ : Bool}
  run_lang(t, all, ws, c, A.w4_dead(A.advance(A.attach(all, all), ws, c, A.W4{0, 0, 0, 0})), ef, e)({==})

def scan_equiv(ok: Bool, +p: P.Pattern, +all: List<&2, List<&2, A.Node>>, +s: String) -> {((A.fits4(all) && A.check(all, all)) && A.all_found(all, A.linear(p))) == ok : Bool} -> {A.scan(ok, p, A.attach(all, all), A.follow_of(all, A.linear(p)), s) == Spec.matches(p, s) : Bool}:
  match ok s:
    case False{} _: e => PP.matches_equiv(p, s)
    case True{} SNil{}: e => Core.nullable_equiv(p)
    case True{} SCon{Chr{c}, t}: +e =>
      +table = PP.and_l(A.fits4(all) && A.check(all, all), A.all_found(all, A.linear(p)), e)
      %Equal.sym(Bool, Spec.matches(p, SCon{Chr{c}, t}), L.arcs_lang(A.linear(p), c, t), L.arcs_equiv(p, c, t)) : {A.scan(True{}, p, A.attach(all, all), A.follow_of(all, A.linear(p)), SCon{Chr{c}, t}) == _ : Bool}
      %follow_lang(all, A.linear(p), c, t, PP.and_r(A.fits4(all) && A.check(all, all), A.all_found(all, A.linear(p)), e)) : {A.scan(True{}, p, A.attach(all, all), A.follow_of(all, A.linear(p)), SCon{Chr{c}, t}) == _ : Bool}
      %flang_attach(all, all, A.follow_of(all, A.linear(p)), c, t) : {A.scan(True{}, p, A.attach(all, all), A.follow_of(all, A.linear(p)), SCon{Chr{c}, t}) == _ : Bool}
      read_lang(t, all, A.follow_of(all, A.linear(p)), c, PP.and_l(A.fits4(all), A.check(all, all), table), PP.and_r(A.fits4(all), A.check(all, all), table))

# The automaton matcher accepts exactly what the specification accepts.
def matches_equiv(+p: P.Pattern, +s: String) -> {A.matches(p, s) == Spec.matches(p, s) : Bool}:
  scan_equiv(A.fits4(A.table_blocks(p)) && A.check(A.table_blocks(p), A.table_blocks(p)) && A.all_found(A.table_blocks(p), A.linear(p)), p, A.table_blocks(p), s)({==})
