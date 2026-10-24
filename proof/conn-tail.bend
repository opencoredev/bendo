# ConnInfo and Ip tail loops equal their recursive specs (BND-84). Each right
# fold is proven by two inductions: the loop over a reversed list reads the
# spec's fold onto its accumulator, and the fold onto the base is the spec.
# This module deliberately does not import LAWS.
import Base
import ../src/net/ip.bend as Ip
import ../src/net/conn_info.bend as Conn
import ../src/http/bytes.bend as Bytes
import ../src/http/text.bend as T
import ./text.bend as TP

def u32_append_nil(+xs: List<&2, U32>) -> {List.append(&2, U32, xs, []) == xs : List<&2, U32>}:
  TP.list_append_nil(U32, xs)

# ---- Ip.split ----

def split_onto(xs: List<&2, U32>, +sep: U32, acc: List<&2, List<&2, U32>>) -> List<&2, List<&2, U32>>:
  match xs:
    case Nil{}: acc
    case +c <> t: Ip.split_pick(c, split_onto(t, sep, acc), U32.is_eq(c, sep))

def split_onto_base(+xs: List<&2, U32>, +sep: U32) -> {split_onto(xs, sep, [[]]) == Ip.split_spec(xs, sep) : List<&2, List<&2, U32>>}:
  match xs:
    case Nil{}: {==}
    case +c <> t: Equal.cong(List<&2, List<&2, U32>>, List<&2, List<&2, U32>>, x => Ip.split_pick(c, x, U32.is_eq(c, sep)), split_onto(t, sep, [[]]), Ip.split_spec(t, sep), split_onto_base(t, sep))

def split_reverse(+xs: List<&2, U32>, +r: List<&2, U32>, +sep: U32, +acc: List<&2, List<&2, U32>>) -> {Ip.split_go(List.reverse.go(&2, U32, xs, r), sep, acc) == Ip.split_go(r, sep, split_onto(xs, sep, acc)) : List<&2, List<&2, U32>>}:
  match xs:
    case Nil{}: {==}
    case +c <> t: split_reverse(t, c <> r, sep, acc)

def split_equiv(+xs: List<&2, U32>, +sep: U32) -> {Ip.split(xs, sep) == Ip.split_spec(xs, sep) : List<&2, List<&2, U32>>}:
  Equal.trans(List<&2, List<&2, U32>>, Ip.split(xs, sep), split_onto(xs, sep, [[]]), Ip.split_spec(xs, sep), split_reverse(xs, [], sep, [[]]), split_onto_base(xs, sep))

# ---- Conn.strip_lead (the step reads the suffix too) ----

def lead_reverse(+xs: List<&2, U32>, +r: List<&2, U32>, +ys: List<&2, U32>) -> {Conn.strip_lead_go(List.reverse.go(&2, U32, xs, r), Conn.Lead{ys, Conn.strip_lead_spec(ys)}) == Conn.strip_lead_go(r, Conn.Lead{List.append(&2, U32, xs, ys), Conn.strip_lead_spec(List.append(&2, U32, xs, ys))}) : List<&2, U32>}:
  match xs:
    case Nil{}: {==}
    case +c <> t: lead_reverse(t, c <> r, ys)

def strip_lead_equiv(+xs: List<&2, U32>) -> {Conn.strip_lead(xs) == Conn.strip_lead_spec(xs) : List<&2, U32>}:
  Equal.trans(List<&2, U32>, Conn.strip_lead(xs), Conn.strip_lead_spec(List.append(&2, U32, xs, [])), Conn.strip_lead_spec(xs), lead_reverse(xs, [], []), Equal.cong(List<&2, U32>, List<&2, U32>, x => Conn.strip_lead_spec(x), List.append(&2, U32, xs, []), xs, u32_append_nil(xs)))

# ---- Conn.strip_trail ----

def trail_onto(xs: List<&2, U32>, acc: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}: acc
    case +c <> t: Conn.trail_pick(c, Bytes.ows(c), trail_onto(t, acc))

def trail_onto_base(+xs: List<&2, U32>) -> {trail_onto(xs, []) == Conn.strip_trail_spec(xs) : List<&2, U32>}:
  match xs:
    case Nil{}: {==}
    case +c <> t: Equal.cong(List<&2, U32>, List<&2, U32>, x => Conn.trail_pick(c, Bytes.ows(c), x), trail_onto(t, []), Conn.strip_trail_spec(t), trail_onto_base(t))

def trail_reverse(+xs: List<&2, U32>, +r: List<&2, U32>, +acc: List<&2, U32>) -> {Conn.strip_trail_go(List.reverse.go(&2, U32, xs, r), acc) == Conn.strip_trail_go(r, trail_onto(xs, acc)) : List<&2, U32>}:
  match xs:
    case Nil{}: {==}
    case +c <> t: trail_reverse(t, c <> r, acc)

def strip_trail_equiv(+xs: List<&2, U32>) -> {Conn.strip_trail(xs) == Conn.strip_trail_spec(xs) : List<&2, U32>}:
  Equal.trans(List<&2, U32>, Conn.strip_trail(xs), trail_onto(xs, []), Conn.strip_trail_spec(xs), trail_reverse(xs, [], []), trail_onto_base(xs))

# ---- Conn.entry_texts ----

def texts_onto(ps: List<&2, List<&2, U32>>, acc: List<&2, String>) -> List<&2, String>:
  match ps:
    case Nil{}: acc
    case p <> t: Bytes.ascii(Conn.trim(p)) <> texts_onto(t, acc)

def texts_onto_base(+ps: List<&2, List<&2, U32>>) -> {texts_onto(ps, []) == Conn.entry_texts_spec(ps) : List<&2, String>}:
  match ps:
    case Nil{}: {==}
    case p <> t: Equal.cong(List<&2, String>, List<&2, String>, x => Bytes.ascii(Conn.trim(p)) <> x, texts_onto(t, []), Conn.entry_texts_spec(t), texts_onto_base(t))

def texts_reverse(+ps: List<&2, List<&2, U32>>, +r: List<&2, List<&2, U32>>, +acc: List<&2, String>) -> {Conn.entry_texts_go(List.reverse.go(&2, List<&2, U32>, ps, r), acc) == Conn.entry_texts_go(r, texts_onto(ps, acc)) : List<&2, String>}:
  match ps:
    case Nil{}: {==}
    case p <> t: texts_reverse(t, p <> r, acc)

def entry_texts_equiv(+ps: List<&2, List<&2, U32>>) -> {Conn.entry_texts(ps) == Conn.entry_texts_spec(ps) : List<&2, String>}:
  Equal.trans(List<&2, String>, Conn.entry_texts(ps), texts_onto(ps, []), Conn.entry_texts_spec(ps), texts_reverse(ps, [], []), texts_onto_base(ps))

# ---- Conn.entries ----

def list_reverse_onto(-A: Data, +xs: List<&2, A>, +r: List<&2, A>, +ys: List<&2, A>) -> {List.reverse.go(&2, A, List.reverse.go(&2, A, xs, r), ys) == List.reverse.go(&2, A, r, List.append(&2, A, xs, ys)) : List<&2, A>}:
  match xs:
    case Nil{}: {==}
    case h <> t: list_reverse_onto(A, t, h <> r, ys)

def list_append_equiv(-A: Data, +xs: List<&2, A>, +ys: List<&2, A>) -> {T.list_append(A, xs, ys) == List.append(&2, A, xs, ys) : List<&2, A>}:
  list_reverse_onto(A, xs, [], ys)

def entries_onto(fs: List<&2, List<&2, U32>>, acc: List<&2, String>) -> List<&2, String>:
  match fs:
    case Nil{}: acc
    case f <> t: List.append(&2, String, Conn.entry_texts(Ip.split(f, 44)), entries_onto(t, acc))

def entries_onto_base(+fs: List<&2, List<&2, U32>>) -> {entries_onto(fs, []) == Conn.entries_spec(fs) : List<&2, String>}:
  match fs:
    case Nil{}: {==}
    case f <> t: Equal.cong(List<&2, String>, List<&2, String>, x => List.append(&2, String, Conn.entry_texts(Ip.split(f, 44)), x), entries_onto(t, []), Conn.entries_spec(t), entries_onto_base(t))

def entries_reverse(+fs: List<&2, List<&2, U32>>, +r: List<&2, List<&2, U32>>, +acc: List<&2, String>) -> {Conn.entries_go(List.reverse.go(&2, List<&2, U32>, fs, r), acc) == Conn.entries_go(r, entries_onto(fs, acc)) : List<&2, String>}:
  match fs:
    case Nil{}: {==}
    case f <> t:
      %list_append_equiv(String, Conn.entry_texts(Ip.split(f, 44)), entries_onto(t, acc)) : {Conn.entries_go(List.reverse.go(&2, List<&2, U32>, t, f <> r), acc) == Conn.entries_go(r, _) : List<&2, String>}
      entries_reverse(t, f <> r, acc)

def entries_equiv(+fs: List<&2, List<&2, U32>>) -> {Conn.entries(fs) == Conn.entries_spec(fs) : List<&2, String>}:
  Equal.trans(List<&2, String>, Conn.entries(fs), entries_onto(fs, []), Conn.entries_spec(fs), entries_reverse(fs, [], []), entries_onto_base(fs))

# ---- Conn.walk_entries ----

def walk_stopped(+xs: List<&2, String>, +trusted: List<&2, Ip.Cidr>, +a: Ip.Addr) -> {Conn.walk_entries(xs, trusted, Conn.Stopped{a}) == a : Ip.Addr}:
  match xs:
    case Nil{}: {==}
    case x <> t: walk_stopped(t, trusted, a)

def walk_hop(+t: List<&2, String>, +trusted: List<&2, Ip.Cidr>, +c: Ip.Addr, h: Conn.Hop, ih: @d:Ip.Addr -> {Conn.walk_entries(t, trusted, Conn.Going{d}) == Conn.walk(Conn.hops(t, trusted), d) : Ip.Addr}) -> {Conn.walk_entries(t, trusted, Conn.walk_step(Conn.Going{c}, h)) == Conn.walk(h <> Conn.hops(t, trusted), c) : Ip.Addr}:
  match h:
    case Conn.Bad{}: walk_stopped(t, trusted, c)
    case Conn.Client{a}: walk_stopped(t, trusted, a)
    case Conn.Proxy{a}: ih(a)

def walk_equiv(+xs: List<&2, String>, +trusted: List<&2, Ip.Cidr>, +c: Ip.Addr) -> {Conn.walk_entries(xs, trusted, Conn.Going{c}) == Conn.walk(Conn.hops(xs, trusted), c) : Ip.Addr}:
  match xs:
    case Nil{}: {==}
    case x <> t: walk_hop(t, trusted, c, Conn.hop(Ip.parse(x), trusted), d => walk_equiv(t, trusted, d))
