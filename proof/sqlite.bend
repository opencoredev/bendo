# BND-38: proofs of the SQLite laws in proof/sqlite-laws.bend.
import Base
import ../src/data/sqlite.bend as Q
import ../src/data/json.bend as J
import ./sqlite-spec.bend as W
import ./sqlite-laws.bend as Laws

# ---------------------------------------------------------------- Payloads

def payload_step(+c: U32, +t: String, +rest: String, m: Q.Mark, +e: {Q.mark(c) == m : Q.Mark}, ih: {W.read_payload(Q.payload(t, rest)) == Some{W.Cut{t, rest}} : Maybe<&2, W.Cut>}) -> {W.read_payload(Q.escaped(m, c, Q.payload(t, rest))) == Some{W.Cut{SCon{Chr{c}, t}, rest}} : Maybe<&2, W.Cut>}:
  match m:
    case Q.MarkPlain{}:
      %Equal.sym(Q.Mark, Q.mark(c), Q.MarkPlain{}, e) : {W.unescape(SCon{Chr{c}, Q.payload(t, rest)}, False{}, _) == Some{W.Cut{SCon{Chr{c}, t}, rest}} : Maybe<&2, W.Cut>}
      %Equal.sym(Maybe<&2, W.Cut>, W.read_payload(Q.payload(t, rest)), Some{W.Cut{t, rest}}, ih) : {W.cons_cut(c, _) == Some{W.Cut{SCon{Chr{c}, t}, rest}} : Maybe<&2, W.Cut>}
      {==}
    case Q.MarkEnd{}:
      %Equal.sym(Maybe<&2, W.Cut>, W.read_payload(Q.payload(t, rest)), Some{W.Cut{t, rest}}, ih) : {W.cons_cut(c, _) == Some{W.Cut{SCon{Chr{c}, t}, rest}} : Maybe<&2, W.Cut>}
      {==}
    case Q.MarkEscape{}:
      %Equal.sym(Maybe<&2, W.Cut>, W.read_payload(Q.payload(t, rest)), Some{W.Cut{t, rest}}, ih) : {W.cons_cut(c, _) == Some{W.Cut{SCon{Chr{c}, t}, rest}} : Maybe<&2, W.Cut>}
      {==}

def payload_read(s: String, +rest: String) -> {W.read_payload(Q.payload(s, rest)) == Some{W.Cut{s, rest}} : Maybe<&2, W.Cut>}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{+c}, +t}: payload_step(c, t, rest, Q.mark(c), {==}, payload_read(t, rest))

def chars(xs: List<&2, U32>) -> String:
  match xs:
    case Nil{}: SNil{}
    case c <> t: SCon{Chr{c}, chars(t)}

def blob_step(+c: U32, +t: List<&2, U32>, +rest: String, m: Q.Mark, +e: {Q.mark(c) == m : Q.Mark}, ih: {W.read_payload(Q.blob_payload(t, rest)) == Some{W.Cut{chars(t), rest}} : Maybe<&2, W.Cut>}) -> {W.read_payload(Q.escaped(m, c, Q.blob_payload(t, rest))) == Some{W.Cut{SCon{Chr{c}, chars(t)}, rest}} : Maybe<&2, W.Cut>}:
  match m:
    case Q.MarkPlain{}:
      %Equal.sym(Q.Mark, Q.mark(c), Q.MarkPlain{}, e) : {W.unescape(SCon{Chr{c}, Q.blob_payload(t, rest)}, False{}, _) == Some{W.Cut{SCon{Chr{c}, chars(t)}, rest}} : Maybe<&2, W.Cut>}
      %Equal.sym(Maybe<&2, W.Cut>, W.read_payload(Q.blob_payload(t, rest)), Some{W.Cut{chars(t), rest}}, ih) : {W.cons_cut(c, _) == Some{W.Cut{SCon{Chr{c}, chars(t)}, rest}} : Maybe<&2, W.Cut>}
      {==}
    case Q.MarkEnd{}:
      %Equal.sym(Maybe<&2, W.Cut>, W.read_payload(Q.blob_payload(t, rest)), Some{W.Cut{chars(t), rest}}, ih) : {W.cons_cut(c, _) == Some{W.Cut{SCon{Chr{c}, chars(t)}, rest}} : Maybe<&2, W.Cut>}
      {==}
    case Q.MarkEscape{}:
      %Equal.sym(Maybe<&2, W.Cut>, W.read_payload(Q.blob_payload(t, rest)), Some{W.Cut{chars(t), rest}}, ih) : {W.cons_cut(c, _) == Some{W.Cut{SCon{Chr{c}, chars(t)}, rest}} : Maybe<&2, W.Cut>}
      {==}

def blob_read(xs: List<&2, U32>, +rest: String) -> {W.read_payload(Q.blob_payload(xs, rest)) == Some{W.Cut{chars(xs), rest}} : Maybe<&2, W.Cut>}:
  match xs:
    case Nil{}: {==}
    case +c <> +t: blob_step(c, t, rest, Q.mark(c), {==}, blob_read(t, rest))

def bytes_chars(xs: List<&2, U32>) -> {W.bytes_of(chars(xs)) == xs : List<&2, U32>}:
  match xs:
    case Nil{}: {==}
    case +c <> +t: Equal.cong(List<&2, U32>, List<&2, U32>, k => c <> k, W.bytes_of(chars(t)), t, bytes_chars(t))

# ---------------------------------------------------------------- Values

def value_read(v: Q.Value, +rest: String) -> {W.read_value(Q.value(v, rest)) == Some{W.ValueCut{v, rest}} : Maybe<&2, W.ValueCut>}:
  match v:
    case Q.SqlNull{}: {==}
    case Q.SqlInteger{+t}:
      %Equal.sym(Maybe<&2, W.Cut>, W.read_payload(Q.payload(t, rest)), Some{W.Cut{t, rest}}, payload_read(t, rest)) : {W.as_value(W.KInteger{}, _) == Some{W.ValueCut{Q.SqlInteger{t}, rest}} : Maybe<&2, W.ValueCut>}
      {==}
    case Q.SqlReal{+t}:
      %Equal.sym(Maybe<&2, W.Cut>, W.read_payload(Q.payload(t, rest)), Some{W.Cut{t, rest}}, payload_read(t, rest)) : {W.as_value(W.KReal{}, _) == Some{W.ValueCut{Q.SqlReal{t}, rest}} : Maybe<&2, W.ValueCut>}
      {==}
    case Q.SqlText{+s}:
      %Equal.sym(Maybe<&2, W.Cut>, W.read_payload(Q.payload(s, rest)), Some{W.Cut{s, rest}}, payload_read(s, rest)) : {W.as_value(W.KText{}, _) == Some{W.ValueCut{Q.SqlText{s}, rest}} : Maybe<&2, W.ValueCut>}
      {==}
    case Q.SqlBlob{+xs}:
      %Equal.sym(Maybe<&2, W.Cut>, W.read_payload(Q.blob_payload(xs, rest)), Some{W.Cut{chars(xs), rest}}, blob_read(xs, rest)) : {W.as_value(W.KBlob{}, _) == Some{W.ValueCut{Q.SqlBlob{xs}, rest}} : Maybe<&2, W.ValueCut>}
      %Equal.sym(List<&2, U32>, W.bytes_of(chars(xs)), xs, bytes_chars(xs)) : {Some{W.ValueCut{Q.SqlBlob{_}, rest}} == Some{W.ValueCut{Q.SqlBlob{xs}, rest}} : Maybe<&2, W.ValueCut>}
      {==}

def binding_read(b: Q.Binding, +rest: String) -> {W.read_binding(Q.binding(b, rest)) == Some{W.BindingCut{b, rest}} : Maybe<&2, W.BindingCut>}:
  match b:
    case Q.Binding{+name, +v}:
      %Equal.sym(Maybe<&2, W.Cut>, W.read_payload(Q.payload(name, Q.value(v, rest))), Some{W.Cut{name, Q.value(v, rest)}}, payload_read(name, Q.value(v, rest))) : {W.binding_of(_) == Some{W.BindingCut{Q.Binding{name, v}, rest}} : Maybe<&2, W.BindingCut>}
      %Equal.sym(Maybe<&2, W.ValueCut>, W.read_value(Q.value(v, rest)), Some{W.ValueCut{v, rest}}, value_read(v, rest)) : {W.with_value(name, _) == Some{W.BindingCut{Q.Binding{name, v}, rest}} : Maybe<&2, W.BindingCut>}
      {==}

def Laws.sqlite_payload_roundtrip(s, rest): payload_read(s, rest)
def Laws.sqlite_value_roundtrip(v, rest): value_read(v, rest)
def Laws.sqlite_binding_roundtrip(b, rest): binding_read(b, rest)

# ---------------------------------------------------------------- Encoders

def escaped_rev_go(m: Q.Mark, +c: U32, +acc: String, +x: String) -> {String.reverse.go(Q.escaped_rev(m, c, acc), x) == String.reverse.go(acc, Q.escaped(m, c, x)) : String}:
  match m:
    case Q.MarkEnd{}: {==}
    case Q.MarkEscape{}: {==}
    case Q.MarkPlain{}: {==}

def payload_rev_go(s: String, +acc: String, +r: String) -> {String.reverse.go(Q.payload_rev(s, acc), r) == String.reverse.go(acc, Q.payload(s, r)) : String}:
  match s:
    case SNil{}: {==}
    case SCon{Chr{+c}, +t}:
      Equal.trans(String, String.reverse.go(Q.payload_rev(t, Q.escaped_rev(Q.mark(c), c, acc)), r), String.reverse.go(Q.escaped_rev(Q.mark(c), c, acc), Q.payload(t, r)), String.reverse.go(acc, Q.escaped(Q.mark(c), c, Q.payload(t, r))), payload_rev_go(t, Q.escaped_rev(Q.mark(c), c, acc), r), escaped_rev_go(Q.mark(c), c, acc, Q.payload(t, r)))

def blob_rev_go(xs: List<&2, U32>, +acc: String, +r: String) -> {String.reverse.go(Q.blob_payload_rev(xs, acc), r) == String.reverse.go(acc, Q.blob_payload(xs, r)) : String}:
  match xs:
    case Nil{}: {==}
    case +c <> +t:
      Equal.trans(String, String.reverse.go(Q.blob_payload_rev(t, Q.escaped_rev(Q.mark(c), c, acc)), r), String.reverse.go(Q.escaped_rev(Q.mark(c), c, acc), Q.blob_payload(t, r)), String.reverse.go(acc, Q.escaped(Q.mark(c), c, Q.blob_payload(t, r))), blob_rev_go(t, Q.escaped_rev(Q.mark(c), c, acc), r), escaped_rev_go(Q.mark(c), c, acc, Q.blob_payload(t, r)))

def value_rev_go(v: Q.Value, +acc: String, +r: String) -> {String.reverse.go(Q.value_rev(v, acc), r) == String.reverse.go(acc, Q.value(v, r)) : String}:
  match v:
    case Q.SqlNull{}: {==}
    case Q.SqlInteger{t}: payload_rev_go(t, SCon{'i', acc}, r)
    case Q.SqlReal{t}: payload_rev_go(t, SCon{'r', acc}, r)
    case Q.SqlText{s}: payload_rev_go(s, SCon{'t', acc}, r)
    case Q.SqlBlob{xs}: blob_rev_go(xs, SCon{'b', acc}, r)

def values_rev_go(vs: List<&2, Q.Value>, +acc: String, +r: String) -> {String.reverse.go(Q.values_rev(vs, acc), r) == String.reverse.go(acc, Q.values(vs, r)) : String}:
  match vs:
    case Nil{}: {==}
    case +v <> +t:
      Equal.trans(String, String.reverse.go(Q.values_rev(t, Q.value_rev(v, acc)), r), String.reverse.go(Q.value_rev(v, acc), Q.values(t, r)), String.reverse.go(acc, Q.value(v, Q.values(t, r))), values_rev_go(t, Q.value_rev(v, acc), r), value_rev_go(v, acc, Q.values(t, r)))

def bindings_rev_go(bs: List<&2, Q.Binding>, +acc: String, +r: String) -> {String.reverse.go(Q.bindings_rev(bs, acc), r) == String.reverse.go(acc, Q.bindings(bs, r)) : String}:
  match bs:
    case Nil{}: {==}
    case Q.Binding{+name, +v} <> +t:
      Equal.trans(String, String.reverse.go(Q.bindings_rev(t, Q.value_rev(v, Q.payload_rev(name, acc))), r), String.reverse.go(Q.payload_rev(name, acc), Q.value(v, Q.bindings(t, r))), String.reverse.go(acc, Q.payload(name, Q.value(v, Q.bindings(t, r)))), Equal.trans(String, String.reverse.go(Q.bindings_rev(t, Q.value_rev(v, Q.payload_rev(name, acc))), r), String.reverse.go(Q.value_rev(v, Q.payload_rev(name, acc)), Q.bindings(t, r)), String.reverse.go(Q.payload_rev(name, acc), Q.value(v, Q.bindings(t, r))), bindings_rev_go(t, Q.value_rev(v, Q.payload_rev(name, acc)), r), value_rev_go(v, Q.payload_rev(name, acc), Q.bindings(t, r))), payload_rev_go(name, acc, Q.value(v, Q.bindings(t, r))))

def Laws.sqlite_positional_wire(vs):
  Equal.cong(String, String, x => SCon{'P', x}, String.reverse.go(Q.values_rev(vs, SNil{}), SNil{}), Q.values(vs, SNil{}), values_rev_go(vs, SNil{}, SNil{}))

def Laws.sqlite_named_wire(bs):
  Equal.cong(String, String, x => SCon{'N', x}, String.reverse.go(Q.bindings_rev(bs, SNil{}), SNil{}), Q.bindings(bs, SNil{}), bindings_rev_go(bs, SNil{}, SNil{}))

# ---------------------------------------------------------------- Rows

def Laws.sqlite_integer_json(t, valid):
  %Equal.sym(Bool, J.number_valid(t), True{}, valid) : {Q.number_json(_, t) == Some{J.JNumber{t}} : Maybe<&2, J.Json>}
  {==}

def Laws.sqlite_real_json(t, valid):
  %Equal.sym(Bool, J.number_valid(t), True{}, valid) : {Q.number_json(_, t) == Some{J.JNumber{t}} : Maybe<&2, J.Json>}
  {==}

def Laws.sqlite_real_not_json(t, invalid):
  %Equal.sym(Bool, J.number_valid(t), False{}, invalid) : {Q.number_json(_, t) == None{} : Maybe<&2, J.Json>}
  {==}

def Laws.sqlite_null_json(): {==}
def Laws.sqlite_text_json(s): {==}
def Laws.sqlite_blob_json(xs): {==}

def keys_step(+c: String, m: Maybe<&2, J.Json>, r: Result<&2, &2, String, List<&2, J.Field>>, +ct: List<&2, String>, ih: {W.keys_or(r, ct) == ct : List<&2, String>}) -> {W.keys_or(Q.cons_field(c, m, r), c <> ct) == c <> ct : List<&2, String>}:
  match m r:
    case None{} x: {==}
    case Some{j} Fail{bad}: {==}
    case Some{j} Done{fs}: Equal.cong(List<&2, String>, List<&2, String>, k => c <> k, Q.field_keys(fs), ct, ih)

def row_keys(cols: List<&2, String>, cells: List<&2, Q.Value>) -> {W.keys_or(Q.fields(cols, cells), cols) == cols : List<&2, String>}:
  match cols cells:
    case Nil{} Nil{}: {==}
    case Nil{} v <> vt: {==}
    case c <> ct Nil{}: {==}
    case +c <> +ct v <> +vt: keys_step(c, Q.cell_json(v), Q.fields(ct, vt), ct, row_keys(ct, vt))

def Laws.sqlite_row_keys(cols, cells): row_keys(cols, cells)

# ---------------------------------------------------------------- Gate

def run_of(+g: Bool, +h: Bool) -> {Q.is_run(Q.verdict(g, h)) == g : Bool}:
  match g h:
    case True{} x: {==}
    case False{} True{}: {==}
    case False{} False{}: {==}

def run_or_false(+g: Bool) -> {Q.is_run(Q.verdict(g || False{}, True{})) == g : Bool}:
  match g:
    case True{}: {==}
    case False{}: {==}

def waits(+g: Bool) -> {Q.is_refuse(Q.verdict(g, True{})) == False{} : Bool}:
  match g:
    case True{}: {==}
    case False{}: {==}

def refused_of(+h: Bool, +b: Bool) -> {Q.is_refuse(Q.verdict(h && b, h)) == Bool.not(h) : Bool}:
  match h b:
    case True{} True{}: {==}
    case True{} False{}: {==}
    case False{} x: {==}

def isolated(+a: Bool, +w: Bool) -> {Q.is_run(Q.verdict((a && False{} && Bool.not(w)) || (Bool.not(a) && False{}), a)) == False{} : Bool}:
  match a:
    case True{}: {==}
    case False{}: {==}

def Laws.sqlite_gate_isolation(owner, busy, waiting, t, open, other):
  %Equal.sym(Bool, U32.is_eq(owner, 0), False{}, open) : {Q.is_run(Q.verdict((U32.is_eq(t, 0) && _ && Bool.not(waiting)) || (U32.is_ne(t, 0) && U32.is_eq(t, owner)), U32.is_eq(t, 0))) == False{} : Bool}
  %Equal.sym(Bool, U32.is_eq(t, owner), False{}, other) : {Q.is_run(Q.verdict((U32.is_eq(t, 0) && False{} && Bool.not(waiting)) || (U32.is_ne(t, 0) && _), U32.is_eq(t, 0))) == False{} : Bool}
  isolated(U32.is_eq(t, 0), waiting)

def Laws.sqlite_gate_member(owner, busy, waiting, t, token, same):
  %Equal.sym(Bool, U32.is_eq(t, 0), False{}, token) : {Q.verdict((_ && U32.is_eq(owner, 0) && Bool.not(waiting)) || (Bool.not(_) && U32.is_eq(t, owner)), _) == Q.GateRun{} : Q.Verdict}
  %Equal.sym(Bool, U32.is_eq(t, owner), True{}, same) : {Q.verdict((False{} && U32.is_eq(owner, 0) && Bool.not(waiting)) || (Bool.not(False{}) && _), False{}) == Q.GateRun{} : Q.Verdict}
  {==}

def Laws.sqlite_gate_stale(owner, busy, waiting, t, token, other):
  %Equal.sym(Bool, U32.is_eq(t, 0), False{}, token) : {Q.verdict((_ && U32.is_eq(owner, 0) && Bool.not(waiting)) || (Bool.not(_) && U32.is_eq(t, owner)), _) == Q.GateRefuse{} : Q.Verdict}
  %Equal.sym(Bool, U32.is_eq(t, owner), False{}, other) : {Q.verdict((False{} && U32.is_eq(owner, 0) && Bool.not(waiting)) || (Bool.not(False{}) && _), False{}) == Q.GateRefuse{} : Q.Verdict}
  {==}

def Laws.sqlite_gate_autocommit(owner, busy, waiting):
  run_or_false(U32.is_eq(owner, 0) && Bool.not(waiting))

def Laws.sqlite_gate_autocommit_waits(owner, busy, waiting):
  waits((U32.is_eq(owner, 0) && Bool.not(waiting)) || False{})

def Laws.sqlite_gate_begin(owner, busy, waiting):
  run_of(U32.is_eq(owner, 0) && Bool.not(busy), True{})

def Laws.sqlite_gate_begin_waits(owner, busy, waiting):
  waits(U32.is_eq(owner, 0) && Bool.not(busy))

def Laws.sqlite_gate_end(owner, busy, waiting, t):
  run_of(U32.is_ne(t, 0) && U32.is_eq(t, owner) && Bool.not(busy), U32.is_ne(t, 0) && U32.is_eq(t, owner))

def Laws.sqlite_gate_end_refused(owner, busy, waiting, t):
  refused_of(U32.is_ne(t, 0) && U32.is_eq(t, owner), Bool.not(busy))
