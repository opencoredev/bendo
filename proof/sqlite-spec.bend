# BND-38: the SQLite wire format read back, as src/effects/sqlite.c and
# sqlite.js read it, and the plain definitions the row laws compare against. The
# effect never runs this code; LAWS.bend uses it to state that every encoded
# value reads back as itself, whatever follows it.
import Base
import ../src/data/sqlite.bend as Q
import ../src/data/json.bend as J
import ../src/data/base64.bend as Base64
import ../src/data/schema.bend as S

type Cut is Data:
  Cut{text: String, rest: String}

type ValueCut is Data:
  ValueCut{value: Q.Value, rest: String}

type BindingCut is Data:
  BindingCut{binding: Q.Binding, rest: String}

def cons_cut(c: U32, r: Maybe<&2, Cut>) -> Maybe<&2, Cut>:
  match r:
    case None{}: None{}
    case Some{Cut{t, rest}}: Some{Cut{SCon{Chr{c}, t}, rest}}

def mark_head(s: String) -> Q.Mark:
  match s:
    case SNil{}: Q.MarkPlain{}
    case SCon{Chr{+c}, t}: Q.mark(c)

# A payload: characters up to an unescaped ';', '\' escaping the next one.
# m is the mark of s's first character.
def unescape(s: String, escaped: Bool, m: Q.Mark) -> Maybe<&2, Cut>:
  match s escaped m:
    case SNil{} e k: None{}
    case SCon{Chr{+c}, +t} True{} k: cons_cut(c, unescape(t, False{}, mark_head(t)))
    case SCon{Chr{+c}, +t} False{} Q.MarkEnd{}: Some{Cut{SNil{}, t}}
    case SCon{Chr{+c}, +t} False{} Q.MarkEscape{}: unescape(t, True{}, mark_head(t))
    case SCon{Chr{+c}, +t} False{} Q.MarkPlain{}: cons_cut(c, unescape(t, False{}, mark_head(t)))

def read_payload(+s: String) -> Maybe<&2, Cut>:
  unescape(s, False{}, mark_head(s))

def bytes_of(s: String) -> List<&2, U32>:
  match s:
    case SNil{}: []
    case SCon{Chr{c}, t}: c <> bytes_of(t)

type Tag is Data:
  KInteger{}
  KReal{}
  KText{}
  KBlob{}

def kind_value(k: Tag, t: String) -> Q.Value:
  match k:
    case KInteger{}: Q.SqlInteger{t}
    case KReal{}: Q.SqlReal{t}
    case KText{}: Q.SqlText{t}
    case KBlob{}: Q.SqlBlob{bytes_of(t)}

def as_value(k: Tag, r: Maybe<&2, Cut>) -> Maybe<&2, ValueCut>:
  match r:
    case None{}: None{}
    case Some{Cut{t, rest}}: Some{ValueCut{kind_value(k, t), rest}}

# One value: its tag, then its payload.
def read_value(s: String) -> Maybe<&2, ValueCut>:
  match s:
    case SCon{'n', t}: Some{ValueCut{Q.SqlNull{}, t}}
    case SCon{'i', t}: as_value(KInteger{}, read_payload(t))
    case SCon{'r', t}: as_value(KReal{}, read_payload(t))
    case SCon{'t', t}: as_value(KText{}, read_payload(t))
    case SCon{'b', t}: as_value(KBlob{}, read_payload(t))
    case _: None{}

def with_value(name: String, r: Maybe<&2, ValueCut>) -> Maybe<&2, BindingCut>:
  match r:
    case None{}: None{}
    case Some{ValueCut{v, rest}}: Some{BindingCut{Q.Binding{name, v}, rest}}

def binding_of(r: Maybe<&2, Cut>) -> Maybe<&2, BindingCut>:
  match r:
    case None{}: None{}
    case Some{Cut{name, rest}}: with_value(name, read_value(rest))

# A named binding: its name as a payload, then its value.
def read_binding(+s: String) -> Maybe<&2, BindingCut>:
  binding_of(read_payload(s))

# A row's keys when Sqlite.fields succeeds, else d.
def keys_or(r: Result<&2, &2, String, List<&2, J.Field>>, d: List<&2, String>) -> List<&2, String>:
  match r:
    case Fail{c}: d
    case Done{fs}: Q.field_keys(fs)

# ---------------------------------------------------------------- Rows

# A column value that has a JSON form: a number's text must be a JSON number.
def admissible(v: Q.Value) -> Bool:
  match v:
    case Q.SqlNull{}: True{}
    case Q.SqlInteger{t}: J.number_valid(t)
    case Q.SqlReal{t}: J.number_valid(t)
    case Q.SqlText{s}: True{}
    case Q.SqlBlob{xs}: True{}

# The JSON form of an admissible value.
def cell_value(v: Q.Value) -> J.Json:
  match v:
    case Q.SqlNull{}: J.JNull{}
    case Q.SqlInteger{t}: J.JNumber{t}
    case Q.SqlReal{t}: J.JNumber{t}
    case Q.SqlText{s}: J.JString{s}
    case Q.SqlBlob{xs}: J.JString{Base64.encode(xs, False{}, True{})}

# A row converts when it has one value per column and every value is
# admissible.
def row_ok(cols: List<&2, String>, cells: List<&2, Q.Value>) -> Bool:
  match cols cells:
    case Nil{} Nil{}: True{}
    case Nil{} v <> vt: False{}
    case c <> ct Nil{}: False{}
    case c <> ct v <> vt: admissible(v) && row_ok(ct, vt)

# Each column paired with its value's JSON form, in order.
def row_fields(cols: List<&2, String>, cells: List<&2, Q.Value>) -> List<&2, J.Field>:
  match cols cells:
    case Nil{} Nil{}: []
    case Nil{} v <> vt: []
    case c <> ct Nil{}: []
    case c <> ct v <> vt: J.Field{c, cell_value(v)} <> row_fields(ct, vt)

def is_fail(-E: Data, -A: Data, r: Result<&2, &2, E, A>) -> Bool:
  match r:
    case Fail{e}: True{}
    case Done{x}: False{}

def is_some(m: Maybe<&2, J.Json>) -> Bool:
  match m:
    case None{}: False{}
    case Some{j}: True{}

# ---------------------------------------------------------------- Results

# A row's outcome in front of the outcome of the rows after it: the first
# failure wins.
def cons_ok(-A: Data, r: Result<&2, &2, Q.RowFault, A>, rest: Result<&2, &2, Q.RowFault, List<&2, A>>) -> Result<&2, &2, Q.RowFault, List<&2, A>>:
  match r rest:
    case Fail{e} x: Fail{e}
    case Done{v} Fail{e}: Fail{e}
    case Done{v} Done{vs}: Done{v <> vs}

# Row n as JSON: a column with no JSON form fails as that row's.
def json_row(n: Nat, r: Result<&2, &2, String, J.Json>) -> Result<&2, &2, Q.RowFault, J.Json>:
  match r:
    case Fail{c}: Fail{Q.FaultJson{n, c}}
    case Done{j}: Done{j}

# Row n through the schema decoder.
def schema_row(n: Nat, r: Result<&2, &2, List<&2, S.Error>, S.Value>) -> Result<&2, &2, Q.RowFault, S.Value>:
  match r:
    case Fail{es}: Fail{Q.FaultSchema{n, es}}
    case Done{v}: Done{v}

# Row n converted to JSON and then decoded through the schema.
def decode_row(+schema: S.Schema, n: Nat, r: Result<&2, &2, String, J.Json>) -> Result<&2, &2, Q.RowFault, S.Value>:
  match r:
    case Fail{c}: Fail{Q.FaultJson{n, c}}
    case Done{j}: schema_row(n, S.decode(schema, j))

# Rows numbered from n converted one by one, in order.
def rows_json(+cols: List<&2, String>, rs: List<&2, List<&2, Q.Value>>, +n: Nat) -> Result<&2, &2, Q.RowFault, List<&2, J.Json>>:
  match rs:
    case Nil{}: Done{[]}
    case vs <> t: cons_ok(J.Json, json_row(n, Q.row_json(cols, vs)), rows_json(cols, t, 1n+n))

# Rows numbered from n converted and decoded one by one, in order.
def decode_rows(+schema: S.Schema, +cols: List<&2, String>, rs: List<&2, List<&2, Q.Value>>, +n: Nat) -> Result<&2, &2, Q.RowFault, List<&2, S.Value>>:
  match rs:
    case Nil{}: Done{[]}
    case vs <> t: cons_ok(S.Value, decode_row(schema, n, Q.row_json(cols, vs)), decode_rows(schema, cols, t, 1n+n))
