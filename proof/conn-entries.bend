# BND-44: Conn.entries meets its independent specification.
import Base
import ../src/net/ip.bend as Ip
import ../src/net/conn_info.bend as Conn
import ../src/http/bytes.bend as Bytes
import ./conn-spec.bend as Spec
import ./bytes-tail.bend as BT
import ./conn-tail.bend as CT

def ascii_text_inner(xs: List<&2, U32>) -> {Bytes.ascii_spec(xs) == Spec.text(xs) : String}:
  match xs:
    case Nil{}: {==}
    case +c <> +t: Equal.cong(String, String, s => SCon{Chr{c}, s}, Bytes.ascii_spec(t), Spec.text(t), ascii_text_inner(t))

def ascii_text(+xs: List<&2, U32>) -> {Bytes.ascii(xs) == Spec.text(xs) : String}:
  Equal.trans(String, Bytes.ascii(xs), Bytes.ascii_spec(xs), Spec.text(xs), BT.ascii_equiv(xs), ascii_text_inner(xs))

def push_same(+c: U32, ps: List<&2, List<&2, U32>>) -> {Ip.split_push(c, ps) == Spec.push(c, ps) : List<&2, List<&2, U32>>}:
  match ps:
    case Nil{}: {==}
    case p <> t: {==}

def split_pick_same(+c: U32, comma: Bool, +ps: List<&2, List<&2, U32>>) -> {Ip.split_pick(c, ps, comma) == Spec.pieces_pick(c, comma, ps) : List<&2, List<&2, U32>>}:
  match comma:
    case True{}: {==}
    case False{}: push_same(c, ps)

def split_pieces_inner(xs: List<&2, U32>) -> {Ip.split_spec(xs, 44) == Spec.pieces(xs) : List<&2, List<&2, U32>>}:
  match xs:
    case Nil{}: {==}
    case +c <> +t:
      Equal.trans(List<&2, List<&2, U32>>, Ip.split_pick(c, Ip.split_spec(t, 44), U32.is_eq(c, 44)), Ip.split_pick(c, Spec.pieces(t), U32.is_eq(c, 44)), Spec.pieces_pick(c, U32.is_eq(c, 44), Spec.pieces(t)), Equal.cong(List<&2, List<&2, U32>>, List<&2, List<&2, U32>>, ps => Ip.split_pick(c, ps, U32.is_eq(c, 44)), Ip.split_spec(t, 44), Spec.pieces(t), split_pieces_inner(t)), split_pick_same(c, U32.is_eq(c, 44), Spec.pieces(t)))

def split_pieces(+xs: List<&2, U32>) -> {Ip.split(xs, 44) == Spec.pieces(xs) : List<&2, List<&2, U32>>}:
  Equal.trans(List<&2, List<&2, U32>>, Ip.split(xs, 44), Ip.split_spec(xs, 44), Spec.pieces(xs), CT.split_equiv(xs, 44), split_pieces_inner(xs))

def lead_same(+c: U32, +t: List<&2, U32>, +r: List<&2, U32>, space: Bool) -> {Conn.lead_pick(c, t, r, space) == Spec.skip_pick(c, t, r, space) : List<&2, U32>}:
  match space:
    case True{}: {==}
    case False{}: {==}

def lead_skip_inner(xs: List<&2, U32>) -> {Conn.strip_lead_spec(xs) == Spec.skip(xs) : List<&2, U32>}:
  match xs:
    case Nil{}: {==}
    case +c <> +t:
      Equal.trans(List<&2, U32>, Conn.lead_pick(c, t, Conn.strip_lead_spec(t), Bytes.ows(c)), Conn.lead_pick(c, t, Spec.skip(t), Bytes.ows(c)), Spec.skip_pick(c, t, Spec.skip(t), Spec.space(c)), Equal.cong(List<&2, U32>, List<&2, U32>, r => Conn.lead_pick(c, t, r, Bytes.ows(c)), Conn.strip_lead_spec(t), Spec.skip(t), lead_skip_inner(t)), lead_same(c, t, Spec.skip(t), Bytes.ows(c)))

def lead_skip(+xs: List<&2, U32>) -> {Conn.strip_lead(xs) == Spec.skip(xs) : List<&2, U32>}:
  Equal.trans(List<&2, U32>, Conn.strip_lead(xs), Conn.strip_lead_spec(xs), Spec.skip(xs), CT.strip_lead_equiv(xs), lead_skip_inner(xs))

# A blank character before a cut point is cut too; before a kept one it stays.
def trail_cut(+c: U32, +d: U32, cut: Bool, +r: List<&2, U32>) -> {Conn.trail_pick(c, True{}, Spec.cut_pick(d, cut, r)) == Spec.cut_pick(c, cut, Spec.cut_pick(d, cut, r)) : List<&2, U32>}:
  match cut:
    case True{}: {==}
    case False{}: {==}

def trail_blank(+c: U32, xs: List<&2, U32>) -> {Conn.trail_pick(c, True{}, Spec.rstrip(xs)) == Spec.cut_pick(c, Spec.blank(xs), Spec.rstrip(xs)) : List<&2, U32>}:
  match xs:
    case Nil{}: {==}
    case +d <> +u: trail_cut(c, d, Spec.space(d) && Spec.blank(u), Spec.rstrip(u))

def trail_same(+c: U32, space: Bool, +t: List<&2, U32>) -> {Conn.trail_pick(c, space, Spec.rstrip(t)) == Spec.cut_pick(c, space && Spec.blank(t), Spec.rstrip(t)) : List<&2, U32>}:
  match space:
    case True{}: trail_blank(c, t)
    case False{}: {==}

def trail_rstrip_inner(xs: List<&2, U32>) -> {Conn.strip_trail_spec(xs) == Spec.rstrip(xs) : List<&2, U32>}:
  match xs:
    case Nil{}: {==}
    case +c <> +t:
      Equal.trans(List<&2, U32>, Conn.trail_pick(c, Bytes.ows(c), Conn.strip_trail_spec(t)), Conn.trail_pick(c, Bytes.ows(c), Spec.rstrip(t)), Spec.cut_pick(c, Spec.space(c) && Spec.blank(t), Spec.rstrip(t)), Equal.cong(List<&2, U32>, List<&2, U32>, r => Conn.trail_pick(c, Bytes.ows(c), r), Conn.strip_trail_spec(t), Spec.rstrip(t), trail_rstrip_inner(t)), trail_same(c, Bytes.ows(c), t))

def trail_rstrip(+xs: List<&2, U32>) -> {Conn.strip_trail(xs) == Spec.rstrip(xs) : List<&2, U32>}:
  Equal.trans(List<&2, U32>, Conn.strip_trail(xs), Conn.strip_trail_spec(xs), Spec.rstrip(xs), CT.strip_trail_equiv(xs), trail_rstrip_inner(xs))

def trim_strip(+xs: List<&2, U32>) -> {Conn.trim(xs) == Spec.strip(xs) : List<&2, U32>}:
  Equal.trans(List<&2, U32>, Conn.strip_trail(Conn.strip_lead(xs)), Conn.strip_trail(Spec.skip(xs)), Spec.rstrip(Spec.skip(xs)), Equal.cong(List<&2, U32>, List<&2, U32>, r => Conn.strip_trail(r), Conn.strip_lead(xs), Spec.skip(xs), lead_skip(xs)), trail_rstrip(Spec.skip(xs)))

def text_same(+p: List<&2, U32>) -> {Bytes.ascii(Conn.trim(p)) == Spec.text(Spec.strip(p)) : String}:
  Equal.trans(String, Bytes.ascii(Conn.trim(p)), Bytes.ascii(Spec.strip(p)), Spec.text(Spec.strip(p)), Equal.cong(List<&2, U32>, String, r => Bytes.ascii(r), Conn.trim(p), Spec.strip(p), trim_strip(p)), ascii_text(Spec.strip(p)))

def cons_same(+h1: String, +h2: String, +t1: List<&2, String>, +t2: List<&2, String>, eh: {h1 == h2 : String}, et: {t1 == t2 : List<&2, String>}) -> {h1 <> t1 == h2 <> t2 : List<&2, String>}:
  Equal.trans(List<&2, String>, h1 <> t1, h2 <> t1, h2 <> t2, Equal.cong(String, List<&2, String>, h => h <> t1, h1, h2, eh), Equal.cong(List<&2, String>, List<&2, String>, t => h2 <> t, t1, t2, et))

def append_same(+a1: List<&2, String>, +a2: List<&2, String>, +b1: List<&2, String>, +b2: List<&2, String>, ea: {a1 == a2 : List<&2, String>}, eb: {b1 == b2 : List<&2, String>}) -> {List.append(&2, String, a1, b1) == List.append(&2, String, a2, b2) : List<&2, String>}:
  Equal.trans(List<&2, String>, List.append(&2, String, a1, b1), List.append(&2, String, a2, b1), List.append(&2, String, a2, b2), Equal.cong(List<&2, String>, List<&2, String>, a => List.append(&2, String, a, b1), a1, a2, ea), Equal.cong(List<&2, String>, List<&2, String>, b => List.append(&2, String, a2, b), b1, b2, eb))

def field_same_inner(ps: List<&2, List<&2, U32>>) -> {Conn.entry_texts_spec(ps) == Spec.field(ps) : List<&2, String>}:
  match ps:
    case Nil{}: {==}
    case +p <> +t: cons_same(Bytes.ascii(Conn.trim(p)), Spec.text(Spec.strip(p)), Conn.entry_texts_spec(t), Spec.field(t), text_same(p), field_same_inner(t))

def field_same(+ps: List<&2, List<&2, U32>>) -> {Conn.entry_texts(ps) == Spec.field(ps) : List<&2, String>}:
  Equal.trans(List<&2, String>, Conn.entry_texts(ps), Conn.entry_texts_spec(ps), Spec.field(ps), CT.entry_texts_equiv(ps), field_same_inner(ps))

def field_pieces(+f: List<&2, U32>) -> {Conn.entry_texts(Ip.split(f, 44)) == Spec.field(Spec.pieces(f)) : List<&2, String>}:
  Equal.trans(List<&2, String>, Conn.entry_texts(Ip.split(f, 44)), Conn.entry_texts(Spec.pieces(f)), Spec.field(Spec.pieces(f)), Equal.cong(List<&2, List<&2, U32>>, List<&2, String>, ps => Conn.entry_texts(ps), Ip.split(f, 44), Spec.pieces(f), split_pieces(f)), field_same(Spec.pieces(f)))

def entries_spec_inner(fields: List<&2, List<&2, U32>>) -> {Conn.entries_spec(fields) == Spec.entries(fields) : List<&2, String>}:
  match fields:
    case Nil{}: {==}
    case +f <> +t: append_same(Conn.entry_texts(Ip.split(f, 44)), Spec.field(Spec.pieces(f)), Conn.entries_spec(t), Spec.entries(t), field_pieces(f), entries_spec_inner(t))
def entries_spec(+fields: List<&2, List<&2, U32>>) -> {Conn.entries(fields) == Spec.entries(fields) : List<&2, String>}:
  Equal.trans(List<&2, String>, Conn.entries(fields), Conn.entries_spec(fields), Spec.entries(fields), CT.entries_equiv(fields), entries_spec_inner(fields))
