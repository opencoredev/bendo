# BND-38: proofs of the SQLite laws in proof/sqlite-laws.bend.
import Base
import ../src/data/sqlite.bend as Q
import ../src/data/json.bend as J
import ../src/data/schema.bend as S
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

def and_false(+a: Bool) -> {(a && False{}) == False{} : Bool}:
  match a:
    case True{}: {==}
    case False{}: {==}

def Fields() -> Type:
  Result<&2, &2, String, List<&2, J.Field>>

def value_ok(v: Q.Value, e: {W.admissible(v) == True{} : Bool}) -> {Q.cell_json(v) == Some{W.cell_value(v)} : Maybe<&2, J.Json>}:
  match v:
    case Q.SqlNull{}: {==}
    case Q.SqlInteger{+t}:
      %Equal.sym(Bool, J.number_valid(t), True{}, e) : {Q.number_json(_, t) == Some{J.JNumber{t}} : Maybe<&2, J.Json>}
      {==}
    case Q.SqlReal{+t}:
      %Equal.sym(Bool, J.number_valid(t), True{}, e) : {Q.number_json(_, t) == Some{J.JNumber{t}} : Maybe<&2, J.Json>}
      {==}
    case Q.SqlText{s}: {==}
    case Q.SqlBlob{xs}: {==}

def converts(cols: List<&2, String>, cells: List<&2, Q.Value>, +ok: {W.row_ok(cols, cells) == True{} : Bool}) -> {Q.fields(cols, cells) == Done{W.row_fields(cols, cells)} : Fields()}:
  match cols cells:
    case Nil{} Nil{}: {==}
    case Nil{} +v <> +vt: absurd({Q.fields([], v <> vt) == Done{W.row_fields([], v <> vt)} : Fields()}, false_true(ok))
    case +c <> +ct Nil{}: absurd({Q.fields(c <> ct, []) == Done{W.row_fields(c <> ct, [])} : Fields()}, false_true(ok))
    case +c <> +ct +v <> +vt:
      %Equal.sym(Maybe<&2, J.Json>, Q.cell_json(v), Some{W.cell_value(v)}, value_ok(v, and_left(W.admissible(v), W.row_ok(ct, vt), ok))) : {Q.cons_field(c, _, Q.fields(ct, vt)) == Done{J.Field{c, W.cell_value(v)} <> W.row_fields(ct, vt)} : Fields()}
      %Equal.sym(Fields(), Q.fields(ct, vt), Done{W.row_fields(ct, vt)}, converts(ct, vt, and_right(W.admissible(v), W.row_ok(ct, vt), ok))) : {Q.cons_field(c, Some{W.cell_value(v)}, _) == Done{J.Field{c, W.cell_value(v)} <> W.row_fields(ct, vt)} : Fields()}
      {==}

def Laws.sqlite_row_converts(cols, cells, ok):
  Equal.cong(Fields(), Result<&2, &2, String, J.Json>, r => Q.object(r), Q.fields(cols, cells), Done{W.row_fields(cols, cells)}, converts(cols, cells, ok))

def some_number(+b: Bool, +t: String) -> {W.is_some(Q.number_json(b, t)) == b : Bool}:
  match b:
    case True{}: {==}
    case False{}: {==}

def value_some(v: Q.Value) -> {W.is_some(Q.cell_json(v)) == W.admissible(v) : Bool}:
  match v:
    case Q.SqlNull{}: {==}
    case Q.SqlInteger{+t}: some_number(J.number_valid(t), t)
    case Q.SqlReal{+t}: some_number(J.number_valid(t), t)
    case Q.SqlText{s}: {==}
    case Q.SqlBlob{xs}: {==}

def fails_step(+c: String, m: Maybe<&2, J.Json>, r: Fields(), a: Bool, b: Bool, em: {W.is_some(m) == a : Bool}, er: {W.is_fail(String, List<&2, J.Field>, r) == Bool.not(b) : Bool}) -> {W.is_fail(String, List<&2, J.Field>, Q.cons_field(c, m, r)) == Bool.not(a && b) : Bool}:
  match m r:
    case None{} x:
      %em : {True{} == Bool.not(_ && b) : Bool}
      {==}
    case Some{j} Fail{bad}:
      %em : {True{} == Bool.not(_ && b) : Bool}
      er
    case Some{j} Done{fs}:
      %em : {False{} == Bool.not(_ && b) : Bool}
      er

def fails_go(cols: List<&2, String>, cells: List<&2, Q.Value>) -> {W.is_fail(String, List<&2, J.Field>, Q.fields(cols, cells)) == Bool.not(W.row_ok(cols, cells)) : Bool}:
  match cols cells:
    case Nil{} Nil{}: {==}
    case Nil{} v <> vt: {==}
    case c <> ct Nil{}: {==}
    case +c <> +ct +v <> +vt: fails_step(c, Q.cell_json(v), Q.fields(ct, vt), W.admissible(v), W.row_ok(ct, vt), value_some(v), fails_go(ct, vt))

def object_fail(r: Fields()) -> {W.is_fail(String, J.Json, Q.object(r)) == W.is_fail(String, List<&2, J.Field>, r) : Bool}:
  match r:
    case Fail{c}: {==}
    case Done{fs}: {==}

def row_fails(+cols: List<&2, String>, +cells: List<&2, Q.Value>) -> {W.is_fail(String, J.Json, Q.row_json(cols, cells)) == Bool.not(W.row_ok(cols, cells)) : Bool}:
  Equal.trans(Bool, W.is_fail(String, J.Json, Q.object(Q.fields(cols, cells))), W.is_fail(String, List<&2, J.Field>, Q.fields(cols, cells)), Bool.not(W.row_ok(cols, cells)), object_fail(Q.fields(cols, cells)), fails_go(cols, cells))

def Laws.sqlite_row_fails(cols, cells): row_fails(cols, cells)

def not_ok(cols: List<&2, String>, before: List<&2, Q.Value>, +t: String, +after: List<&2, Q.Value>, +invalid: {J.number_valid(t) == False{} : Bool}) -> {W.row_ok(cols, List.append(&2, Q.Value, before, Q.SqlReal{t} <> after)) == False{} : Bool}:
  match cols before:
    case Nil{} Nil{}: {==}
    case Nil{} p <> pt: {==}
    case +c <> +ct Nil{}:
      %Equal.sym(Bool, J.number_valid(t), False{}, invalid) : {(_ && W.row_ok(ct, after)) == False{} : Bool}
      {==}
    case +c <> +ct +p <> +pt:
      %Equal.sym(Bool, W.row_ok(ct, List.append(&2, Q.Value, pt, Q.SqlReal{t} <> after)), False{}, not_ok(ct, pt, t, after, invalid)) : {(W.admissible(p) && _) == False{} : Bool}
      and_false(W.admissible(p))

def Laws.sqlite_row_invalid_real(cols, before, t, after, invalid):
  Equal.trans(Bool, W.is_fail(String, J.Json, Q.row_json(cols, List.append(&2, Q.Value, before, Q.SqlReal{t} <> after))), Bool.not(W.row_ok(cols, List.append(&2, Q.Value, before, Q.SqlReal{t} <> after))), True{}, row_fails(cols, List.append(&2, Q.Value, before, Q.SqlReal{t} <> after)), Equal.cong(Bool, Bool, x => Bool.not(x), W.row_ok(cols, List.append(&2, Q.Value, before, Q.SqlReal{t} <> after)), False{}, not_ok(cols, before, t, after, invalid)))

# ---------------------------------------------------------------- Results

# The loops' reversed accumulator in front of the plain definition's result.
def finish(-A: Data, rev: List<&2, A>, s: Result<&2, &2, Q.RowFault, List<&2, A>>) -> Result<&2, &2, Q.RowFault, List<&2, A>>:
  match s:
    case Fail{e}: Fail{e}
    case Done{xs}: Done{List.reverse.go(&2, A, rev, xs)}

def finish_nil(-A: Data, s: Result<&2, &2, Q.RowFault, List<&2, A>>) -> {finish(A, [], s) == s : Result<&2, &2, Q.RowFault, List<&2, A>>}:
  match s:
    case Fail{e}: {==}
    case Done{xs}: {==}

def finish_shift(-A: Data, v: A, rev: List<&2, A>, s: Result<&2, &2, Q.RowFault, List<&2, A>>) -> {finish(A, v <> rev, s) == finish(A, rev, W.cons_ok(A, Done{v}, s)) : Result<&2, &2, Q.RowFault, List<&2, A>>}:
  match s:
    case Fail{e}: {==}
    case Done{xs}: {==}

def JRows() -> Type:
  Result<&2, &2, Q.RowFault, List<&2, J.Json>>

def json_same(+n: Nat, r: Result<&2, &2, String, J.Json>) -> {Q.json_at(n, r) == W.json_row(n, r) : Result<&2, &2, Q.RowFault, J.Json>}:
  match r:
    case Fail{c}: {==}
    case Done{j}: {==}

def json_go_fail(rs: List<&2, List<&2, Q.Value>>, +cols: List<&2, String>, +n: Nat, +e: Q.RowFault) -> {Q.rows_json_go(rs, cols, n, Fail{e}) == Fail{e} : JRows()}:
  match rs:
    case Nil{}: {==}
    case vs <> t: json_go_fail(t, cols, 1n+n, e)

def json_step(d: Result<&2, &2, Q.RowFault, J.Json>, t: List<&2, List<&2, Q.Value>>, +cols: List<&2, String>, +n: Nat, +rev: List<&2, J.Json>, ih: @r: List<&2, J.Json> -> {Q.rows_json_go(t, cols, 1n+n, Done{r}) == finish(J.Json, r, W.rows_json(cols, t, 1n+n)) : JRows()}) -> {Q.rows_json_go(t, cols, 1n+n, Q.push_json_row(rev, d)) == finish(J.Json, rev, W.cons_ok(J.Json, d, W.rows_json(cols, t, 1n+n))) : JRows()}:
  match d:
    case Fail{e}: json_go_fail(t, cols, 1n+n, e)
    case Done{+j}: Equal.trans(JRows(), Q.rows_json_go(t, cols, 1n+n, Done{j <> rev}), finish(J.Json, j <> rev, W.rows_json(cols, t, 1n+n)), finish(J.Json, rev, W.cons_ok(J.Json, Done{j}, W.rows_json(cols, t, 1n+n))), ih(j <> rev), finish_shift(J.Json, j, rev, W.rows_json(cols, t, 1n+n)))

def json_go(rs: List<&2, List<&2, Q.Value>>, +cols: List<&2, String>, +n: Nat, +rev: List<&2, J.Json>) -> {Q.rows_json_go(rs, cols, n, Done{rev}) == finish(J.Json, rev, W.rows_json(cols, rs, n)) : JRows()}:
  match rs:
    case Nil{}: {==}
    case +vs <> +t:
      %json_same(n, Q.row_json(cols, vs)) : {Q.rows_json_go(t, cols, 1n+n, Q.push_json_row(rev, Q.json_at(n, Q.row_json(cols, vs)))) == finish(J.Json, rev, W.cons_ok(J.Json, _, W.rows_json(cols, t, 1n+n))) : JRows()}
      json_step(Q.json_at(n, Q.row_json(cols, vs)), t, cols, n, rev, r => json_go(t, cols, 1n+n, r))

def Laws.sqlite_rows_json(cols, rs):
  Equal.trans(JRows(), Q.rows_json_go(rs, cols, 0n, Done{[]}), finish(J.Json, [], W.rows_json(cols, rs, 0n)), W.rows_json(cols, rs, 0n), json_go(rs, cols, 0n, []), finish_nil(J.Json, W.rows_json(cols, rs, 0n)))

def SRows() -> Type:
  Result<&2, &2, Q.RowFault, List<&2, S.Value>>

def schema_same(+n: Nat, d: Result<&2, &2, List<&2, S.Error>, S.Value>) -> {Q.schema_at(n, d) == W.schema_row(n, d) : Result<&2, &2, Q.RowFault, S.Value>}:
  match d:
    case Fail{es}: {==}
    case Done{v}: {==}

def decode_same(+schema: S.Schema, +n: Nat, r: Result<&2, &2, String, J.Json>) -> {Q.decode_json_at(schema, n, Q.json_at(n, r)) == W.decode_row(schema, n, r) : Result<&2, &2, Q.RowFault, S.Value>}:
  match r:
    case Fail{c}: {==}
    case Done{j}: schema_same(n, S.decode(schema, j))

def decode_go_fail(rs: List<&2, List<&2, Q.Value>>, +schema: S.Schema, +cols: List<&2, String>, +n: Nat, +e: Q.RowFault) -> {Q.decode_go(rs, schema, cols, n, Fail{e}) == Fail{e} : SRows()}:
  match rs:
    case Nil{}: {==}
    case vs <> t: decode_go_fail(t, schema, cols, 1n+n, e)

def decode_step(d: Result<&2, &2, Q.RowFault, S.Value>, t: List<&2, List<&2, Q.Value>>, +schema: S.Schema, +cols: List<&2, String>, +n: Nat, +rev: List<&2, S.Value>, ih: @r: List<&2, S.Value> -> {Q.decode_go(t, schema, cols, 1n+n, Done{r}) == finish(S.Value, r, W.decode_rows(schema, cols, t, 1n+n)) : SRows()}) -> {Q.decode_go(t, schema, cols, 1n+n, Q.push_value(rev, d)) == finish(S.Value, rev, W.cons_ok(S.Value, d, W.decode_rows(schema, cols, t, 1n+n))) : SRows()}:
  match d:
    case Fail{e}: decode_go_fail(t, schema, cols, 1n+n, e)
    case Done{+v}: Equal.trans(SRows(), Q.decode_go(t, schema, cols, 1n+n, Done{v <> rev}), finish(S.Value, v <> rev, W.decode_rows(schema, cols, t, 1n+n)), finish(S.Value, rev, W.cons_ok(S.Value, Done{v}, W.decode_rows(schema, cols, t, 1n+n))), ih(v <> rev), finish_shift(S.Value, v, rev, W.decode_rows(schema, cols, t, 1n+n)))

def decode_go(rs: List<&2, List<&2, Q.Value>>, +schema: S.Schema, +cols: List<&2, String>, +n: Nat, +rev: List<&2, S.Value>) -> {Q.decode_go(rs, schema, cols, n, Done{rev}) == finish(S.Value, rev, W.decode_rows(schema, cols, rs, n)) : SRows()}:
  match rs:
    case Nil{}: {==}
    case +vs <> +t:
      %decode_same(schema, n, Q.row_json(cols, vs)) : {Q.decode_go(t, schema, cols, 1n+n, Q.push_value(rev, Q.decode_json_at(schema, n, Q.json_at(n, Q.row_json(cols, vs))))) == finish(S.Value, rev, W.cons_ok(S.Value, _, W.decode_rows(schema, cols, t, 1n+n))) : SRows()}
      decode_step(Q.decode_json_at(schema, n, Q.json_at(n, Q.row_json(cols, vs))), t, schema, cols, n, rev, r => decode_go(t, schema, cols, 1n+n, r))

def Laws.sqlite_decode_rows(schema, cols, rs):
  Equal.trans(SRows(), Q.decode_go(rs, schema, cols, 0n, Done{[]}), finish(S.Value, [], W.decode_rows(schema, cols, rs, 0n)), W.decode_rows(schema, cols, rs, 0n), decode_go(rs, schema, cols, 0n, []), finish_nil(S.Value, W.decode_rows(schema, cols, rs, 0n)))

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
