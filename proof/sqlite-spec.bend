# BND-38: the SQLite wire format read back, as src/effects/sqlite.c and
# sqlite.js read it, and the key projection used by the row laws. The
# effect never runs this code; LAWS.bend uses it to state that every encoded
# value reads back as itself, whatever follows it.
import Base
import ../src/data/sqlite.bend as Q
import ../src/data/json.bend as J

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
