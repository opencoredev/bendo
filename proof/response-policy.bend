# BND-40: retained response policies equal the independent specification.
import Base
import ../src/http/request.bend as Request
import ../src/http/response.bend as Response
import ../src/http/bytes.bend as Bytes
import ../src/mw/response_fields.bend as Fields
import ../src/mw/response_policy.bend as Policy
import ../src/mw/vary.bend as Vary
import ./response-policy-spec.bend as RS

# ---- Field filtering ----

def unrelated_nil(+hs: List<&2, Request.Header>) -> {RS.unrelated(hs, []) == hs : List<&2, Request.Header>}:
  match hs:
    case Nil{}: {==}
    case Request.Header{+k, +v} <> +t:
      Equal.cong(List<&2, Request.Header>, List<&2, Request.Header>, l => Request.Header{k, v} <> l, RS.unrelated(t, []), t, unrelated_nil(t))

def without_step(+k: String, +v: List<&2, U32>, +rest: List<&2, Request.Header>, +n: String, +t: List<&2, String>, +e: Bool, ih: {RS.unrelated(Fields.without(rest, n), t) == RS.unrelated(rest, n <> t) : List<&2, Request.Header>}) -> {RS.unrelated(Fields.keep(Request.Header{k, v}, Fields.without(rest, n), e), t) == RS.kept(Request.Header{k, v}, RS.unrelated(rest, n <> t), e || RS.listed(Bytes.fold(k), t)) : List<&2, Request.Header>}:
  match e:
    case True{}: ih
    case False{}:
      %ih : {RS.kept(Request.Header{k, v}, RS.unrelated(Fields.without(rest, n), t), RS.listed(Bytes.fold(k), t)) == RS.kept(Request.Header{k, v}, _, RS.listed(Bytes.fold(k), t)) : List<&2, Request.Header>}
      {==}

# Removing one name, then the rest, removes them all.
def without_then(+hs: List<&2, Request.Header>, +n: String, +t: List<&2, String>) -> {RS.unrelated(Fields.without(hs, n), t) == RS.unrelated(hs, n <> t) : List<&2, Request.Header>}:
  match hs:
    case Nil{}: {==}
    case Request.Header{+k, +v} <> +rest: without_step(k, v, rest, n, t, String.eq(Bytes.fold(k), n), without_then(rest, n, t))

# Stripping names one at a time is the single filter of the specification.
def stripped(+names: List<&2, String>, +hs: List<&2, Request.Header>) -> {Policy.stripped(names, hs) == RS.unrelated(hs, names) : List<&2, Request.Header>}:
  match names:
    case Nil{}: Equal.sym(List<&2, Request.Header>, RS.unrelated(hs, []), hs, unrelated_nil(hs))
    case +n <> +t: Equal.trans(List<&2, Request.Header>, Policy.stripped(t, Fields.without(hs, n)), RS.unrelated(Fields.without(hs, n), t), RS.unrelated(hs, n <> t), stripped(t, Fields.without(hs, n)), without_then(hs, n, t))

# ---- Vary ----

def values_pick(+v: List<&2, U32>, +r1: List<&2, List<&2, U32>>, +r2: List<&2, List<&2, U32>>, +e: Bool, ih: {r1 == r2 : List<&2, List<&2, U32>>}) -> {Fields.value(v, r1, e) == RS.vary_pick(v, r2, e) : List<&2, List<&2, U32>>}:
  match e:
    case True{}: Equal.cong(List<&2, List<&2, U32>>, List<&2, List<&2, U32>>, l => v <> l, r1, r2, ih)
    case False{}: ih

# The runtime's Vary values are the specification's, for any field case.
def values(+hs: List<&2, Request.Header>) -> {Fields.values(hs, "vary") == RS.vary_values(hs) : List<&2, List<&2, U32>>}:
  match hs:
    case Nil{}: {==}
    case Request.Header{+k, +v} <> +t: values_pick(v, Fields.values(t, "vary"), RS.vary_values(t), String.eq(Bytes.fold(k), "vary"), values(t))

def has(+x: String, +xs: List<&2, String>) -> {Vary.has(x, xs) == RS.member(x, xs) : Bool}:
  match xs:
    case Nil{}: {==}
    case +y <> +t: Equal.cong(Bool, Bool, b => String.eq(y, x) || b, Vary.has(x, t), RS.member(x, t), has(x, t))

def or_false(+b: Bool) -> {b || False{} == b : Bool}:
  match b:
    case True{}: {==}
    case False{}: {==}

def swap(+a: Bool, +b: Bool, +c: Bool) -> {a || (b || c) == b || (a || c) : Bool}:
  match a b:
    case True{} True{}: {==}
    case True{} False{}: {==}
    case False{} True{}: {==}
    case False{} False{}: {==}

def has_append(+x: String, +e: List<&2, String>, +m: List<&2, String>) -> {Vary.has(x, List.append(&2, String, e, m)) == RS.member(x, m) || RS.member(x, e) : Bool}:
  match e:
    case Nil{}: Equal.trans(Bool, Vary.has(x, m), RS.member(x, m), RS.member(x, m) || False{}, has(x, m), Equal.sym(Bool, RS.member(x, m) || False{}, RS.member(x, m), or_false(RS.member(x, m))))
    case +y <> +t:
      step = Equal.cong(Bool, Bool, b => String.eq(y, x) || b, Vary.has(x, List.append(&2, String, t, m)), RS.member(x, m) || RS.member(x, t), has_append(x, t, m))
      Equal.trans(Bool, String.eq(y, x) || Vary.has(x, List.append(&2, String, t, m)), String.eq(y, x) || (RS.member(x, m) || RS.member(x, t)), RS.member(x, m) || (String.eq(y, x) || RS.member(x, t)), step, swap(String.eq(y, x), RS.member(x, m), RS.member(x, t)))

# ---- The Vary tokenizer lists exactly the specification's members ----

# The pieces Vary.items has yet to finish: the reversed current piece glued
# to the first piece still to come.
def glue(cur: List<&2, U32>, s: RS.Pieces) -> List<&2, List<&2, U32>>:
  match s:
    case RS.Pieces{f, r}: List.reverse.go(&2, U32, cur, f) <> r

# Vary.items emits finished pieces onto its done list, last piece first.
def emitted(pieces: List<&2, List<&2, U32>>, acc: List<&2, String>) -> List<&2, String>:
  match pieces:
    case Nil{}: acc
    case p <> t: emitted(t, RS.member_name(p) <> acc)

def split_step(+x: U32, +t: List<&2, U32>, +cur: List<&2, U32>, +done: List<&2, String>, +c: Bool, +sg: RS.Pieces, ih_cut: {Vary.items_end(Vary.items_go(t, Vary.Items{[], Vary.item(cur) <> done})) == emitted(glue([], sg), Vary.item(cur) <> done) : List<&2, String>}, ih_push: {Vary.items_end(Vary.items_go(t, Vary.Items{x <> cur, done})) == emitted(glue(x <> cur, sg), done) : List<&2, String>}) -> {Vary.items_end(Vary.items_go(t, Vary.items_step(x, Vary.Items{cur, done}, c))) == emitted(glue(cur, RS.split_step(x, sg, c)), done) : List<&2, String>}:
  match c:
    case True{}:
      match sg:
        case RS.Pieces{f, r}: ih_cut
    case False{}:
      match sg:
        case RS.Pieces{f, r}: ih_push

def tokens(+xs: List<&2, U32>, +cur: List<&2, U32>, +done: List<&2, String>) -> {Vary.items_end(Vary.items_go(xs, Vary.Items{cur, done})) == emitted(glue(cur, RS.split(xs)), done) : List<&2, String>}:
  match xs:
    case Nil{}: {==}
    case +x <> +t: split_step(x, t, cur, done, U32.is_eq(x, 44), RS.split(t), tokens(t, [], Vary.item(cur) <> done), tokens(t, x <> cur, done))

def rotate(+a: Bool, +b: Bool, +c: Bool) -> {a || (b || c) == (b || a) || c : Bool}:
  match a b:
    case True{} True{}: {==}
    case True{} False{}: {==}
    case False{} True{}: {==}
    case False{} False{}: {==}

def emitted_has(+y: String, +pieces: List<&2, List<&2, U32>>, +acc: List<&2, String>) -> {Vary.has(y, emitted(pieces, acc)) == RS.member(y, RS.member_names(pieces)) || Vary.has(y, acc) : Bool}:
  match pieces:
    case Nil{}: {==}
    case +p <> +t: Equal.trans(Bool, Vary.has(y, emitted(t, RS.member_name(p) <> acc)), RS.member(y, RS.member_names(t)) || (String.eq(RS.member_name(p), y) || Vary.has(y, acc)), (String.eq(RS.member_name(p), y) || RS.member(y, RS.member_names(t))) || Vary.has(y, acc), emitted_has(y, t, RS.member_name(p) <> acc), rotate(RS.member(y, RS.member_names(t)), String.eq(RS.member_name(p), y), Vary.has(y, acc)))

def pieces_has(+y: String, +sg: RS.Pieces) -> {Vary.has(y, emitted(glue([], sg), [])) == RS.member(y, RS.piece_names(sg)) : Bool}:
  match sg:
    case RS.Pieces{+f, +r}: Equal.trans(Bool, Vary.has(y, emitted(f <> r, [])), RS.member(y, RS.member_names(f <> r)) || False{}, RS.member(y, RS.member_names(f <> r)), emitted_has(y, f <> r, []), or_false(RS.member(y, RS.member_names(f <> r))))

# A name is among the members Vary.items lists exactly when the
# specification lists it.
def item_has(+y: String, +v: List<&2, U32>) -> {Vary.has(y, Vary.items(v)) == RS.member(y, RS.value_members(v)) : Bool}:
  Equal.trans(Bool, Vary.has(y, Vary.items(v)), Vary.has(y, emitted(glue([], RS.split(v)), [])), RS.member(y, RS.value_members(v)), Equal.cong(List<&2, String>, Bool, l => Vary.has(y, l), Vary.items(v), emitted(glue([], RS.split(v)), []), tokens(v, [], [])), pieces_has(y, RS.split(v)))

def assoc(+a: Bool, +b: Bool, +c: Bool) -> {a || (b || c) == (a || b) || c : Bool}:
  match a:
    case True{}: {==}
    case False{}: {==}

def has_both(+y: String, +a: List<&2, String>, +b: List<&2, String>) -> {Vary.has(y, List.append(&2, String, a, b)) == Vary.has(y, a) || Vary.has(y, b) : Bool}:
  match a:
    case Nil{}: {==}
    case +x <> +t: Equal.trans(Bool, String.eq(x, y) || Vary.has(y, List.append(&2, String, t, b)), String.eq(x, y) || (Vary.has(y, t) || Vary.has(y, b)), (String.eq(x, y) || Vary.has(y, t)) || Vary.has(y, b), Equal.cong(Bool, Bool, z => String.eq(x, y) || z, Vary.has(y, List.append(&2, String, t, b)), Vary.has(y, t) || Vary.has(y, b), has_both(y, t, b)), assoc(String.eq(x, y), Vary.has(y, t), Vary.has(y, b)))

def member_both(+y: String, +a: List<&2, String>, +b: List<&2, String>) -> {RS.member(y, List.append(&2, String, a, b)) == RS.member(y, a) || RS.member(y, b) : Bool}:
  match a:
    case Nil{}: {==}
    case +x <> +t: Equal.trans(Bool, String.eq(x, y) || RS.member(y, List.append(&2, String, t, b)), String.eq(x, y) || (RS.member(y, t) || RS.member(y, b)), (String.eq(x, y) || RS.member(y, t)) || RS.member(y, b), Equal.cong(Bool, Bool, z => String.eq(x, y) || z, RS.member(y, List.append(&2, String, t, b)), RS.member(y, t) || RS.member(y, b), member_both(y, t, b)), assoc(String.eq(x, y), RS.member(y, t), RS.member(y, b)))

def or_both(+a1: Bool, +a2: Bool, +b1: Bool, +b2: Bool, ea: {a1 == a2 : Bool}, eb: {b1 == b2 : Bool}) -> {a1 || b1 == a2 || b2 : Bool}:
  %ea : {a1 || b1 == _ || b2 : Bool}
  %eb : {a1 || b1 == a1 || _ : Bool}
  {==}

# Every Vary value's members, as Vary.add sees them, are the specification's.
def all_has(+y: String, +values: List<&2, List<&2, U32>>) -> {Vary.has(y, Vary.all_items(values)) == RS.member(y, RS.members(values)) : Bool}:
  match values:
    case Nil{}: {==}
    case +v <> +t:
      +a = Vary.has(y, List.append(&2, String, Vary.items(v), Vary.all_items(t)))
      Equal.trans(Bool, a, Vary.has(y, Vary.items(v)) || Vary.has(y, Vary.all_items(t)), RS.member(y, RS.members(v <> t)), has_both(y, Vary.items(v), Vary.all_items(t)), Equal.trans(Bool, Vary.has(y, Vary.items(v)) || Vary.has(y, Vary.all_items(t)), RS.member(y, RS.value_members(v)) || RS.member(y, RS.members(t)), RS.member(y, RS.members(v <> t)), or_both(Vary.has(y, Vary.items(v)), RS.member(y, RS.value_members(v)), Vary.has(y, Vary.all_items(t)), RS.member(y, RS.members(t)), item_has(y, v), all_has(y, t)), Equal.sym(Bool, RS.member(y, RS.members(v <> t)), RS.member(y, RS.value_members(v)) || RS.member(y, RS.members(t)), member_both(y, RS.value_members(v), RS.members(t)))))

def or_comm(+a: Bool, +b: Bool) -> {a || b == b || a : Bool}:
  match a b:
    case True{} True{}: {==}
    case True{} False{}: {==}
    case False{} True{}: {==}
    case False{} False{}: {==}

def seen_has(+y: String, +e: List<&2, String>, +values: List<&2, List<&2, U32>>) -> {Vary.has(y, List.append(&2, String, e, Vary.all_items(values))) == RS.member(y, RS.members(values)) || RS.member(y, e) : Bool}:
  Equal.trans(Bool, Vary.has(y, List.append(&2, String, e, Vary.all_items(values))), Vary.has(y, e) || Vary.has(y, Vary.all_items(values)), RS.member(y, RS.members(values)) || RS.member(y, e), has_both(y, e, Vary.all_items(values)), Equal.trans(Bool, Vary.has(y, e) || Vary.has(y, Vary.all_items(values)), RS.member(y, e) || RS.member(y, RS.members(values)), RS.member(y, RS.members(values)) || RS.member(y, e), or_both(Vary.has(y, e), RS.member(y, e), Vary.has(y, Vary.all_items(values)), RS.member(y, RS.members(values)), has(y, e), all_has(y, values)), or_comm(RS.member(y, e), RS.member(y, RS.members(values)))))

def pick_same(+n: String, +r1: List<&2, String>, +r2: List<&2, String>, +b: Bool, er: {r1 == r2 : List<&2, String>}) -> {Vary.missing_pick(n, r1, b) == RS.fresh_pick(n, r2, b) : List<&2, String>}:
  match b:
    case True{}: er
    case False{}: Equal.cong(List<&2, String>, List<&2, String>, l => n <> l, r1, r2, er)

def pick(+n: String, +r1: List<&2, String>, +r2: List<&2, String>, +b1: Bool, +b2: Bool, er: {r1 == r2 : List<&2, String>}, eb: {b1 == b2 : Bool}) -> {Vary.missing_pick(n, r1, b1) == RS.fresh_pick(n, r2, b2) : List<&2, String>}:
  %eb : {Vary.missing_pick(n, r1, b1) == RS.fresh_pick(n, r2, _) : List<&2, String>}
  pick_same(n, r1, r2, b1, er)

# The names Vary.add appends are the specification's fresh names.
def missing(+names: List<&2, String>, +e: List<&2, String>, +values: List<&2, List<&2, U32>>) -> {Vary.missing(names, List.append(&2, String, e, Vary.all_items(values))) == RS.fresh_go(names, RS.members(values), e) : List<&2, String>}:
  match names:
    case Nil{}: {==}
    case +n <> +t: pick(n, Vary.missing(t, Bytes.fold(n) <> List.append(&2, String, e, Vary.all_items(values))), RS.fresh_go(t, RS.members(values), Bytes.fold(n) <> e), Vary.has(Bytes.fold(n), List.append(&2, String, e, Vary.all_items(values))), RS.member(Bytes.fold(n), RS.members(values)) || RS.member(Bytes.fold(n), e), missing(t, Bytes.fold(n) <> e, values), seen_has(Bytes.fold(n), e, values))

def encode_append(+a: String, +b: String) -> {Bytes.encode(String.append(a, b)) == List.append(&2, U32, Bytes.encode(a), Bytes.encode(b)) : List<&2, U32>}:
  match a:
    case SNil{}: {==}
    case SCon{Chr{+c}, +t}: Equal.cong(List<&2, U32>, List<&2, U32>, l => c <> l, Bytes.encode(String.append(t, b)), List.append(&2, U32, Bytes.encode(t), Bytes.encode(b)), encode_append(t, b))

def join_go(+t: List<&2, String>, +x: String) -> {Bytes.encode(String.join.go(t, x, ", ")) == RS.separated(Bytes.encode(x) <> RS.encoded(t)) : List<&2, U32>}:
  match t:
    case Nil{}: {==}
    case +y <> +r:
      tail = Equal.cong(List<&2, U32>, List<&2, U32>, l => List.append(&2, U32, Bytes.encode(x), 44 <> 32 <> l), Bytes.encode(String.join.go(r, y, ", ")), RS.separated(Bytes.encode(y) <> RS.encoded(r)), join_go(r, y))
      Equal.trans(List<&2, U32>, Bytes.encode(String.append(x, String.append(", ", String.join.go(r, y, ", ")))), List.append(&2, U32, Bytes.encode(x), Bytes.encode(String.append(", ", String.join.go(r, y, ", ")))), RS.separated(Bytes.encode(x) <> RS.encoded(y <> r)), encode_append(x, String.append(", ", String.join.go(r, y, ", "))), tail)

def join(+xs: List<&2, String>) -> {Bytes.encode(String.join(xs, ", ")) == RS.separated(RS.encoded(xs)) : List<&2, U32>}:
  match xs:
    case Nil{}: {==}
    case +x <> +t: join_go(t, x)

def joined(+t: List<&2, List<&2, U32>>, +v: List<&2, U32>, +added: List<&2, String>) -> {Vary.joined(v <> t, added) == RS.separated(List.append(&2, List<&2, U32>, v <> t, RS.encoded(added))) : List<&2, U32>}:
  match t:
    case Nil{}:
      match added:
        case Nil{}: {==}
        case +a <> +r: Equal.cong(List<&2, U32>, List<&2, U32>, l => List.append(&2, U32, v, 44 <> 32 <> l), Bytes.encode(String.join(a <> r, ", ")), RS.separated(RS.encoded(a <> r)), join(a <> r))
    case +w <> +r: Equal.cong(List<&2, U32>, List<&2, U32>, l => List.append(&2, U32, v, 44 <> 32 <> l), Vary.joined(w <> r, added), RS.separated(List.append(&2, List<&2, U32>, w <> r, RS.encoded(added))), joined(r, w, added))

def append_nil(+hs: List<&2, Request.Header>) -> {List.append(&2, Request.Header, hs, []) == hs : List<&2, Request.Header>}:
  match hs:
    case Nil{}: {==}
    case +h <> +t: Equal.cong(List<&2, Request.Header>, List<&2, Request.Header>, l => h <> l, List.append(&2, Request.Header, t, []), t, append_nil(t))

def merged(+star: Bool, +values: List<&2, List<&2, U32>>, +added: List<&2, String>, +hs: List<&2, Request.Header>) -> {Vary.merged(hs, values, added, star) == List.append(&2, Request.Header, hs, RS.vary_field(star, values, added)) : List<&2, Request.Header>}:
  match star:
    case True{}: {==}
    case False{}:
      match values:
        case Nil{}:
          match added:
            case Nil{}: Equal.sym(List<&2, Request.Header>, List.append(&2, Request.Header, hs, []), hs, append_nil(hs))
            case +a <> +r: Equal.cong(List<&2, U32>, List<&2, Request.Header>, l => List.append(&2, Request.Header, hs, [Request.Header{"vary", l}]), Bytes.encode(String.join(a <> r, ", ")), RS.separated(RS.encoded(a <> r)), join(a <> r))
        case +v <> +t: Equal.cong(List<&2, U32>, List<&2, Request.Header>, l => List.append(&2, Request.Header, hs, [Request.Header{"vary", l}]), Vary.joined(v <> t, added), RS.separated(List.append(&2, List<&2, U32>, v <> t, RS.encoded(added))), joined(t, v, added))

def merged_values(+hs: List<&2, Request.Header>, +values: List<&2, List<&2, U32>>, +names: List<&2, String>) -> {Vary.merged(hs, values, Vary.missing(names, Vary.all_items(values)), Vary.has("*", Vary.all_items(values))) == List.append(&2, Request.Header, hs, RS.vary_field(RS.member("*", RS.members(values)), values, RS.fresh_go(names, RS.members(values), []))) : List<&2, Request.Header>}:
  %all_has("*", values) : {Vary.merged(hs, values, Vary.missing(names, Vary.all_items(values)), Vary.has("*", Vary.all_items(values))) == List.append(&2, Request.Header, hs, RS.vary_field(_, values, RS.fresh_go(names, RS.members(values), []))) : List<&2, Request.Header>}
  %missing(names, [], values) : {Vary.merged(hs, values, Vary.missing(names, Vary.all_items(values)), Vary.has("*", Vary.all_items(values))) == List.append(&2, Request.Header, hs, RS.vary_field(Vary.has("*", Vary.all_items(values)), values, _)) : List<&2, Request.Header>}
  merged(Vary.has("*", Vary.all_items(values)), values, Vary.missing(names, Vary.all_items(values)), hs)

# Vary.add equals the specification for every field list and name list.
def vary_add(+hs: List<&2, Request.Header>, +names: List<&2, String>) -> {Vary.add(hs, names) == RS.vary_add(hs, names) : List<&2, Request.Header>}:
  %values(hs) : {Vary.add(hs, names) == List.append(&2, Request.Header, RS.unrelated(hs, ["vary"]), RS.vary_field(RS.member("*", RS.members(_)), _, RS.fresh_go(names, RS.members(_), []))) : List<&2, Request.Header>}
  %stripped(["vary"], hs) : {Vary.add(hs, names) == List.append(&2, Request.Header, _, RS.vary_field(RS.member("*", RS.members(Fields.values(hs, "vary"))), Fields.values(hs, "vary"), RS.fresh_go(names, RS.members(Fields.values(hs, "vary")), []))) : List<&2, Request.Header>}
  merged_values(Fields.without(hs, "vary"), Fields.values(hs, "vary"), names)

def varied(+hs: List<&2, Request.Header>, +names: List<&2, String>) -> {Policy.varied(hs, names) == RS.varied(hs, names) : List<&2, Request.Header>}:
  match names:
    case Nil{}: {==}
    case +n <> +t: vary_add(hs, n <> t)

# Applying any policy: unrelated fields kept, the policy's fields appended,
# then the Vary merge.
def apply(+remove: List<&2, String>, +fields: List<&2, Request.Header>, +vary: List<&2, String>, +s: U32, +hs: List<&2, Request.Header>, +b: List<&2, U32>, +rep: Maybe<&2, List<&2, U32>>) -> {Policy.apply(Policy.Policy{remove, fields, vary}, Response.Res{s, hs, b, rep}) == Response.Res{s, RS.varied(List.append(&2, Request.Header, RS.unrelated(hs, remove), fields), vary), b, rep} : Response.Res}:
  %stripped(remove, hs) : {Policy.apply(Policy.Policy{remove, fields, vary}, Response.Res{s, hs, b, rep}) == Response.Res{s, RS.varied(List.append(&2, Request.Header, _, fields), vary), b, rep} : Response.Res}
  Equal.cong(List<&2, Request.Header>, Response.Res, l => Response.Res{s, l, b, rep}, Policy.varied(List.append(&2, Request.Header, Policy.stripped(remove, hs), fields), vary), RS.varied(List.append(&2, Request.Header, Policy.stripped(remove, hs), fields), vary), varied(List.append(&2, Request.Header, Policy.stripped(remove, hs), fields), vary))
