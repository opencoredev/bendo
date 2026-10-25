# BND-38: the pure parts of the SQLite effect. Bound parameters cross to the
# effect as one string; every value in it reads back as itself, with its
# type, whatever follows it, so no parameter can run into the next one or
# into the SQL. Column values map to JSON without losing digits. The
# transaction gate keeps other statements out of an open transaction. The C
# and JS effects implement the reader and the gate; tests/sqlite.test.ts
# checks them against these definitions.
import Base
import ../src/data/sqlite.bend as Q
import ../src/data/json.bend as J
import ../src/data/base64.bend as Base64
import ../src/data/schema.bend as S
import ./sqlite-spec.bend as W

# ---------------------------------------------------------------- Wire

# A payload reads back as exactly its text, and the reader stops at its
# end, leaving whatever follows.
law sqlite_payload_roundtrip:
  for +s: String
  for +rest: String
  {W.read_payload(Q.payload(s, rest)) == Some{W.Cut{s, rest}} : Maybe<&2, W.Cut>}

# Every value, of every type, reads back as itself.
law sqlite_value_roundtrip:
  for +v: Q.Value
  for +rest: String
  {W.read_value(Q.value(v, rest)) == Some{W.ValueCut{v, rest}} : Maybe<&2, W.ValueCut>}

# A named binding reads back as its name and its value.
law sqlite_binding_roundtrip:
  for +b: Q.Binding
  for +rest: String
  {W.read_binding(Q.binding(b, rest)) == Some{W.BindingCut{b, rest}} : Maybe<&2, W.BindingCut>}

# The encoders that run, which build the string reversed for stack safety,
# write exactly the values and bindings above.
law sqlite_positional_wire:
  for +vs: List<&2, Q.Value>
  {Q.positional(vs) == SCon{'P', Q.values(vs, "")} : String}

law sqlite_named_wire:
  for +bs: List<&2, Q.Binding>
  {Q.named(bs) == SCon{'N', Q.bindings(bs, "")} : String}

# ---------------------------------------------------------------- Rows

# An integer or real column becomes a JSON number with the same decimal
# text, so a 64-bit integer keeps every digit.
law sqlite_integer_json:
  for +t: String
  for valid: {J.number_valid(t) == True{} : Bool}
  {Q.cell_json(Q.SqlInteger{t}) == Some{J.JNumber{t}} : Maybe<&2, J.Json>}

law sqlite_real_json:
  for +t: String
  for valid: {J.number_valid(t) == True{} : Bool}
  {Q.cell_json(Q.SqlReal{t}) == Some{J.JNumber{t}} : Maybe<&2, J.Json>}

# A real that is not a JSON number (an infinity) has no JSON form; the row
# fails instead of turning it into something else.
law sqlite_real_not_json:
  for +t: String
  for invalid: {J.number_valid(t) == False{} : Bool}
  {Q.cell_json(Q.SqlReal{t}) == None{} : Maybe<&2, J.Json>}

law sqlite_null_json:
  {Q.cell_json(Q.SqlNull{}) == Some{J.JNull{}} : Maybe<&2, J.Json>}

law sqlite_text_json:
  for +s: String
  {Q.cell_json(Q.SqlText{s}) == Some{J.JString{s}} : Maybe<&2, J.Json>}

# A blob becomes its standard, padded base64, which base64_roundtrip
# decodes back to the same bytes.
law sqlite_blob_json:
  for +xs: List<&2, U32>
  {Q.cell_json(Q.SqlBlob{xs}) == Some{J.JString{Base64.encode(xs, False{}, True{})}} : Maybe<&2, J.Json>}

# When a row converts, its object's keys are its columns, in order.
law sqlite_row_keys:
  for +cols: List<&2, String>
  for +cells: List<&2, Q.Value>
  {W.keys_or(Q.fields(cols, cells), cols) == cols : List<&2, String>}

# A row with one admissible value per column converts to the object of
# exactly those values' JSON forms, keyed by the columns in order.
law sqlite_row_converts:
  for +cols: List<&2, String>
  for +cells: List<&2, Q.Value>
  for ok: {W.row_ok(cols, cells) == True{} : Bool}
  {Q.row_json(cols, cells) == Done{J.JObject{W.row_fields(cols, cells)}} : Result<&2, &2, String, J.Json>}

# A row fails exactly when it is not admissible: a count mismatch, or a
# number that is not a JSON number.
law sqlite_row_fails:
  for +cols: List<&2, String>
  for +cells: List<&2, Q.Value>
  {W.is_fail(String, J.Json, Q.row_json(cols, cells)) == Bool.not(W.row_ok(cols, cells)) : Bool}

# A real with no JSON form anywhere in a row makes the whole row fail.
law sqlite_row_invalid_real:
  for +cols: List<&2, String>
  for +before: List<&2, Q.Value>
  for +t: String
  for +after: List<&2, Q.Value>
  for invalid: {J.number_valid(t) == False{} : Bool}
  {W.is_fail(String, J.Json, Q.row_json(cols, List.append(&2, Q.Value, before, Q.SqlReal{t} <> after))) == True{} : Bool}

# A result's rows convert one by one, in order; the first row that fails
# fails the result, with its number (from 0) and column.
law sqlite_rows_json:
  for +cols: List<&2, String>
  for +rs: List<&2, List<&2, Q.Value>>
  {Q.rows_json(cols, rs) == W.rows_json(cols, rs, 0n) : Result<&2, &2, Q.RowFault, List<&2, J.Json>>}

# Decoding a result through a schema converts each row to JSON and decodes
# it, one by one, in order; the first row with no JSON form or that does not
# match fails the result, with its number and the schema's errors.
law sqlite_decode_rows:
  for +schema: S.Schema
  for +cols: List<&2, String>
  for +rs: List<&2, List<&2, Q.Value>>
  {Q.decode_rows(schema, cols, rs) == W.decode_rows(schema, cols, rs, 0n) : Result<&2, &2, Q.RowFault, List<&2, S.Value>>}

# ---------------------------------------------------------------- Gate

# While a transaction is open (owner is not 0), no statement carrying any
# other token, including the 0 of a statement outside any transaction, runs.
law sqlite_gate_isolation:
  for +owner: U32
  for +busy: Bool
  for +waiting: Bool
  for +t: U32
  for open: {U32.is_eq(owner, 0) == False{} : Bool}
  for other: {U32.is_eq(t, owner) == False{} : Bool}
  {Q.is_run(Q.gate(owner, busy, waiting, Q.GateStatement{t})) == False{} : Bool}

# The open transaction's own statements run.
law sqlite_gate_member:
  for +owner: U32
  for +busy: Bool
  for +waiting: Bool
  for +t: U32
  for token: {U32.is_eq(t, 0) == False{} : Bool}
  for same: {U32.is_eq(t, owner) == True{} : Bool}
  {Q.gate(owner, busy, waiting, Q.GateStatement{t}) == Q.GateRun{} : Q.Verdict}

# A statement carrying a token that is not the open transaction's is
# refused, not delayed: its transaction is over.
law sqlite_gate_stale:
  for +owner: U32
  for +busy: Bool
  for +waiting: Bool
  for +t: U32
  for token: {U32.is_eq(t, 0) == False{} : Bool}
  for other: {U32.is_eq(t, owner) == False{} : Bool}
  {Q.gate(owner, busy, waiting, Q.GateStatement{t}) == Q.GateRefuse{} : Q.Verdict}

# A statement outside any transaction runs exactly when no transaction is
# open and none is waiting to begin; otherwise it waits.
law sqlite_gate_autocommit:
  for +owner: U32
  for +busy: Bool
  for +waiting: Bool
  {Q.is_run(Q.gate(owner, busy, waiting, Q.GateStatement{0})) == (U32.is_eq(owner, 0) && Bool.not(waiting)) : Bool}

law sqlite_gate_autocommit_waits:
  for +owner: U32
  for +busy: Bool
  for +waiting: Bool
  {Q.is_refuse(Q.gate(owner, busy, waiting, Q.GateStatement{0})) == False{} : Bool}

# A transaction begins only when none is open and nothing is in flight;
# otherwise it waits.
law sqlite_gate_begin:
  for +owner: U32
  for +busy: Bool
  for +waiting: Bool
  {Q.is_run(Q.gate(owner, busy, waiting, Q.GateBegin{})) == (U32.is_eq(owner, 0) && Bool.not(busy)) : Bool}

law sqlite_gate_begin_waits:
  for +owner: U32
  for +busy: Bool
  for +waiting: Bool
  {Q.is_refuse(Q.gate(owner, busy, waiting, Q.GateBegin{})) == False{} : Bool}

# Only the open transaction's token ends it, once nothing is in flight; any
# other token is refused.
law sqlite_gate_end:
  for +owner: U32
  for +busy: Bool
  for +waiting: Bool
  for +t: U32
  {Q.is_run(Q.gate(owner, busy, waiting, Q.GateEnd{t})) == (U32.is_ne(t, 0) && U32.is_eq(t, owner) && Bool.not(busy)) : Bool}

law sqlite_gate_end_refused:
  for +owner: U32
  for +busy: Bool
  for +waiting: Bool
  for +t: U32
  {Q.is_refuse(Q.gate(owner, busy, waiting, Q.GateEnd{t})) == Bool.not(U32.is_ne(t, 0) && U32.is_eq(t, owner)) : Bool}
