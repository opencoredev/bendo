# The pure parts of the SQLite effect (BND-38): the wire format that carries
# bound parameters to the effect, the mapping from column values to JSON,
# reading a result's rows as JSON or through a schema, and the transaction
# gate the C and JS twins implement. LAWS.bend states
# what each must do; src/effects/sqlite.md says what the effect does.
import Base
import ./json.bend as J
import ./base64.bend as Base64
import ./schema.bend as S

# ------------------------------------------------------------------ Wire

# A value to bind, or a column value read back. Integers are decimal text in
# the signed 64-bit range, reals JSON number text, and blobs bytes (each
# below 256). The effect checks each when it binds.
type Value is Data:
  SqlNull{}
  SqlInteger{text: String}
  SqlReal{text: String}
  SqlText{value: String}
  SqlBlob{bytes: List<&2, U32>}

# A named parameter, written with its prefix as in the SQL (":id", "@id",
# "$id").
type Binding is Data:
  Binding{name: String, value: Value}

# How the wire treats a character: ';' ends a payload, '\' escapes the next
# character, and every other character stands for itself.
type Mark is Data:
  MarkEnd{}
  MarkEscape{}
  MarkPlain{}

def mark_of(semi: Bool, slash: Bool) -> Mark:
  match semi slash:
    case True{} _: MarkEnd{}
    case False{} True{}: MarkEscape{}
    case False{} False{}: MarkPlain{}

def mark(+c: U32) -> Mark:
  mark_of(U32.is_eq(c, 59), U32.is_eq(c, 92))

# One character of a payload, in front of rest.
def escaped(m: Mark, c: U32, rest: String) -> String:
  match m:
    case MarkEnd{}: SCon{Chr{92}, SCon{Chr{c}, rest}}
    case MarkEscape{}: SCon{Chr{92}, SCon{Chr{c}, rest}}
    case MarkPlain{}: SCon{Chr{c}, rest}

# The characters of s, escaped, then ';', then rest.
def payload(s: String, rest: String) -> String:
  match s:
    case SNil{}: SCon{Chr{59}, rest}
    case SCon{Chr{+c}, t}: escaped(mark(c), c, payload(t, rest))

# A blob's bytes travel as the characters with those codes.
def blob_payload(xs: List<&2, U32>, rest: String) -> String:
  match xs:
    case Nil{}: SCon{Chr{59}, rest}
    case +c <> t: escaped(mark(c), c, blob_payload(t, rest))

# One value: a tag, then its payload. The tag says the type, so a value never
# changes type on the way.
def value(v: Value, rest: String) -> String:
  match v:
    case SqlNull{}: SCon{'n', rest}
    case SqlInteger{t}: SCon{'i', payload(t, rest)}
    case SqlReal{t}: SCon{'r', payload(t, rest)}
    case SqlText{s}: SCon{'t', payload(s, rest)}
    case SqlBlob{xs}: SCon{'b', blob_payload(xs, rest)}

def values(vs: List<&2, Value>, rest: String) -> String:
  match vs:
    case Nil{}: rest
    case v <> t: value(v, values(t, rest))

def binding(b: Binding, rest: String) -> String:
  match b:
    case Binding{name, v}: payload(name, value(v, rest))

def bindings(bs: List<&2, Binding>, rest: String) -> String:
  match bs:
    case Nil{}: rest
    case b <> t: binding(b, bindings(t, rest))

# The encoder that runs. The definitions above recurse once per character,
# which overflows the JS stack on a large blob; these push each character
# onto a reversed accumulator instead, and LAWS.bend equates the two.
def escaped_rev(m: Mark, c: U32, acc: String) -> String:
  match m:
    case MarkEnd{}: SCon{Chr{c}, SCon{Chr{92}, acc}}
    case MarkEscape{}: SCon{Chr{c}, SCon{Chr{92}, acc}}
    case MarkPlain{}: SCon{Chr{c}, acc}

def payload_rev(s: String, acc: String) -> String:
  match s:
    case SNil{}: SCon{Chr{59}, acc}
    case SCon{Chr{+c}, t}: payload_rev(t, escaped_rev(mark(c), c, acc))

def blob_payload_rev(xs: List<&2, U32>, acc: String) -> String:
  match xs:
    case Nil{}: SCon{Chr{59}, acc}
    case +c <> t: blob_payload_rev(t, escaped_rev(mark(c), c, acc))

def value_rev(v: Value, acc: String) -> String:
  match v:
    case SqlNull{}: SCon{'n', acc}
    case SqlInteger{t}: payload_rev(t, SCon{'i', acc})
    case SqlReal{t}: payload_rev(t, SCon{'r', acc})
    case SqlText{s}: payload_rev(s, SCon{'t', acc})
    case SqlBlob{xs}: blob_payload_rev(xs, SCon{'b', acc})

def values_rev(vs: List<&2, Value>, acc: String) -> String:
  match vs:
    case Nil{}: acc
    case v <> t: values_rev(t, value_rev(v, acc))

def bindings_rev(bs: List<&2, Binding>, acc: String) -> String:
  match bs:
    case Nil{}: acc
    case Binding{name, v} <> t: bindings_rev(t, value_rev(v, payload_rev(name, acc)))

# The parameter strings the effect reads: 'P' and values bound by position,
# or 'N' and name/value pairs.
def positional(vs: List<&2, Value>) -> String:
  SCon{'P', String.reverse(values_rev(vs, SNil{}))}

def named(bs: List<&2, Binding>) -> String:
  SCon{'N', String.reverse(bindings_rev(bs, SNil{}))}

# ------------------------------------------------------------------ Rows

# A column value as JSON: NULL is null, an integer or real is a number with
# the effect's decimal text unchanged, text is a string, and a blob is a
# string of its standard, padded base64. None for a real that is not a JSON
# number (SQLite can store an infinity).
def number_json(ok: Bool, t: String) -> Maybe<&2, J.Json>:
  match ok:
    case True{}: Some{J.JNumber{t}}
    case False{}: None{}

def cell_json(v: Value) -> Maybe<&2, J.Json>:
  match v:
    case SqlNull{}: Some{J.JNull{}}
    case SqlInteger{+t}: number_json(J.number_valid(t), t)
    case SqlReal{+t}: number_json(J.number_valid(t), t)
    case SqlText{s}: Some{J.JString{s}}
    case SqlBlob{xs}: Some{J.JString{Base64.encode(xs, False{}, True{})}}

def cons_field(+c: String, m: Maybe<&2, J.Json>, rest: Result<&2, &2, String, List<&2, J.Field>>) -> Result<&2, &2, String, List<&2, J.Field>>:
  match m rest:
    case None{} r: Fail{c}
    case Some{j} Fail{bad}: Fail{bad}
    case Some{j} Done{fs}: Done{J.Field{c, j} <> fs}

# A row's object members, one per column in order. Fails with the first
# column whose value has no JSON form, or with "" when the counts differ.
# Rows have at most a few thousand columns, so direct recursion is safe.
def fields(cols: List<&2, String>, cells: List<&2, Value>) -> Result<&2, &2, String, List<&2, J.Field>>:
  match cols cells:
    case Nil{} Nil{}: Done{[]}
    case Nil{} v <> vt: Fail{""}
    case c <> ct Nil{}: Fail{""}
    case c <> ct v <> vt: cons_field(c, cell_json(v), fields(ct, vt))

def object(r: Result<&2, &2, String, List<&2, J.Field>>) -> Result<&2, &2, String, J.Json>:
  match r:
    case Fail{c}: Fail{c}
    case Done{fs}: Done{J.JObject{fs}}

def row_json(cols: List<&2, String>, cells: List<&2, Value>) -> Result<&2, &2, String, J.Json>:
  object(fields(cols, cells))

def field_keys(fs: List<&2, J.Field>) -> List<&2, String>:
  match fs:
    case Nil{}: []
    case J.Field{k, v} <> t: k <> field_keys(t)

# Why a result's rows could not be read: row (counting from 0) has a column
# with no JSON form, or does not match the schema. src/sqlite.bend turns these
# into Sql.NotJson and Sql.RowError.
type RowFault is Data:
  FaultJson{row: Nat, column: String}
  FaultSchema{row: Nat, errors: List<&2, S.Error>}

def json_at(n: Nat, r: Result<&2, &2, String, J.Json>) -> Result<&2, &2, RowFault, J.Json>:
  match r:
    case Fail{c}: Fail{FaultJson{n, c}}
    case Done{j}: Done{j}

def schema_at(n: Nat, r: Result<&2, &2, List<&2, S.Error>, S.Value>) -> Result<&2, &2, RowFault, S.Value>:
  match r:
    case Fail{es}: Fail{FaultSchema{n, es}}
    case Done{v}: Done{v}

def decode_json_at(+schema: S.Schema, n: Nat, r: Result<&2, &2, RowFault, J.Json>) -> Result<&2, &2, RowFault, S.Value>:
  match r:
    case Fail{e}: Fail{e}
    case Done{j}: schema_at(n, S.decode(schema, j))

# Row n as JSON, and decoded through schema.
def row_json_at(+n: Nat, cols: List<&2, String>, vs: List<&2, Value>) -> Result<&2, &2, RowFault, J.Json>:
  json_at(n, row_json(cols, vs))

def row_decode_at(+schema: S.Schema, +n: Nat, cols: List<&2, String>, vs: List<&2, Value>) -> Result<&2, &2, RowFault, S.Value>:
  decode_json_at(schema, n, json_at(n, row_json(cols, vs)))

# The traversals over a result's rows. Results hold up to max_rows rows, so
# each is a loop over a reversed accumulator; once a row fails, the rest are
# skipped without being converted. LAWS.bend equates each with the plain
# row-by-row definition in proof/sqlite-spec.bend.
def push_json_row(rev: List<&2, J.Json>, r: Result<&2, &2, RowFault, J.Json>) -> Result<&2, &2, RowFault, List<&2, J.Json>>:
  match r:
    case Fail{e}: Fail{e}
    case Done{j}: Done{j <> rev}

def push_json(acc: Result<&2, &2, RowFault, List<&2, J.Json>>, +n: Nat, +cols: List<&2, String>, vs: List<&2, Value>) -> Result<&2, &2, RowFault, List<&2, J.Json>>:
  match acc:
    case Fail{e}: Fail{e}
    case Done{rev}: push_json_row(rev, row_json_at(n, cols, vs))

def flip_json(r: Result<&2, &2, RowFault, List<&2, J.Json>>) -> Result<&2, &2, RowFault, List<&2, J.Json>>:
  match r:
    case Fail{e}: Fail{e}
    case Done{rev}: Done{List.reverse(&2, J.Json, rev)}

def rows_json_go(rs: List<&2, List<&2, Value>>, +cols: List<&2, String>, +n: Nat, acc: Result<&2, &2, RowFault, List<&2, J.Json>>) -> Result<&2, &2, RowFault, List<&2, J.Json>>:
  match rs:
    case Nil{}: flip_json(acc)
    case vs <> t: rows_json_go(t, cols, 1n+n, push_json(acc, n, cols, vs))

# Every row as a JSON object keyed by cols, in order; fails with the first
# row that has a value with no JSON form.
def rows_json(+cols: List<&2, String>, rs: List<&2, List<&2, Value>>) -> Result<&2, &2, RowFault, List<&2, J.Json>>:
  rows_json_go(rs, cols, 0n, Done{[]})

def push_value(rev: List<&2, S.Value>, r: Result<&2, &2, RowFault, S.Value>) -> Result<&2, &2, RowFault, List<&2, S.Value>>:
  match r:
    case Fail{e}: Fail{e}
    case Done{v}: Done{v <> rev}

def push_decoded(acc: Result<&2, &2, RowFault, List<&2, S.Value>>, +schema: S.Schema, +n: Nat, +cols: List<&2, String>, vs: List<&2, Value>) -> Result<&2, &2, RowFault, List<&2, S.Value>>:
  match acc:
    case Fail{e}: Fail{e}
    case Done{rev}: push_value(rev, row_decode_at(schema, n, cols, vs))

def flip_values(r: Result<&2, &2, RowFault, List<&2, S.Value>>) -> Result<&2, &2, RowFault, List<&2, S.Value>>:
  match r:
    case Fail{e}: Fail{e}
    case Done{rev}: Done{List.reverse(&2, S.Value, rev)}

def decode_go(rs: List<&2, List<&2, Value>>, +schema: S.Schema, +cols: List<&2, String>, +n: Nat, acc: Result<&2, &2, RowFault, List<&2, S.Value>>) -> Result<&2, &2, RowFault, List<&2, S.Value>>:
  match rs:
    case Nil{}: flip_values(acc)
    case vs <> t: decode_go(t, schema, cols, 1n+n, push_decoded(acc, schema, n, cols, vs))

# Every row decoded through schema, in order; fails with the first row that
# has no JSON form or does not match.
def decode_rows(+schema: S.Schema, +cols: List<&2, String>, rs: List<&2, List<&2, Value>>) -> Result<&2, &2, RowFault, List<&2, S.Value>>:
  decode_go(rs, schema, cols, 0n, Done{[]})

# ------------------------------------------------------------------ Gate

# What a connection is asked to do: run a statement carrying a transaction
# token (0 for none), begin a transaction, or end the one with this token.
type Ask is Data:
  GateStatement{token: U32}
  GateBegin{}
  GateEnd{token: U32}

type Verdict is Data:
  GateRun{}
  GateWait{}
  GateRefuse{}

def verdict(go: Bool, hold: Bool) -> Verdict:
  match go hold:
    case True{} _: GateRun{}
    case False{} True{}: GateWait{}
    case False{} False{}: GateRefuse{}

def is_run(v: Verdict) -> Bool:
  match v:
    case GateRun{}: True{}
    case GateWait{}: False{}
    case GateRefuse{}: False{}

def is_refuse(v: Verdict) -> Bool:
  match v:
    case GateRun{}: False{}
    case GateWait{}: False{}
    case GateRefuse{}: True{}

# owner is the open transaction's token, 0 when none is open; busy is true
# while any operation on the connection is in flight; waiting is true while
# a begin waits its turn. A statement without a token runs only when no
# transaction is open or waiting; a transaction's statements run only while
# it is open; a begin runs alone; an end waits for in-flight statements and
# is refused for any token but the open one.
def gate(+owner: U32, busy: Bool, waiting: Bool, ask: Ask) -> Verdict:
  match ask:
    case GateStatement{+t}:
      verdict((U32.is_eq(t, 0) && U32.is_eq(owner, 0) && Bool.not(waiting)) || (U32.is_ne(t, 0) && U32.is_eq(t, owner)), U32.is_eq(t, 0))
    case GateBegin{}:
      verdict(U32.is_eq(owner, 0) && Bool.not(busy), True{})
    case GateEnd{+t}:
      verdict(U32.is_ne(t, 0) && U32.is_eq(t, owner) && Bool.not(busy), U32.is_ne(t, 0) && U32.is_eq(t, owner))
